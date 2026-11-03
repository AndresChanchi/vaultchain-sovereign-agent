"use client";

import { useCallback, useState } from "react";
import { WebIrys } from "@irys/sdk";
import { Buffer } from "buffer";
import { BrowserProvider, type Eip1193Provider as EthersEip1193 } from "ethers";
import { useWallet } from "@context/WalletContext";
import { CHAIN_CONFIG, IRYS_CONFIG } from "@config/contracts";
import type { IrysSession } from "@interfaces/vault";

/**
 * Irys SDK bridge — initialise, price, upload, fund.
 *
 * Signer source — `WalletContext`, not wagmi
 *   The legacy hook used `useEthersSigner` (wagmi bridge). The new
 *   login flow never touches wagmi, so this hook reads the session
 *   from `WalletContext` and builds a `BrowserProvider` from the
 *   raw EIP-1193 provider exposed by `getEip1193Provider()`. The
 *   `@irys/sdk` `ethersv6` adapter accepts a `BrowserProvider` the
 *   same way it accepted the wagmi-derived one before — no SDK
 *   change, no ABI change.
 *
 * Chain gate
 *   The MVP contract and the Irys devnet node are both on Arbitrum
 *   Sepolia. A session on a different chain would sign on the wrong
 *   network — the register tx would revert, and the Irys balance
 *   would be on a different chain than the contract reads from.
 *   `initIrys` returns `null` when `session.chainId !==
 *   CHAIN_CONFIG.id`. The upload flow surfaces that as
 *   `WRONG_CHAIN`, which is honest.
 *
 * Wallet-only
 *   OAuth sessions (ephemeral wallet) do not have a real signer with
 *   funds. `getEip1193Provider()` returns `null` for them; `initIrys`
 *   returns `null`. The UI (`upload-dialog`) gates OAuth before this
 *   hook is ever called.
 *
 * Signer acquisition timing
 *   `webIrys.ready()` does NOT require user signing — it only calls
 *   `eth_requestAccounts` (already done at login) and reads state.
 *   So `initIrys()` is safe to call proactively (on file selection)
 *   to warm up the balance display. `uploadFile` and `fundNode`
 *   trigger wallet popups, one per call.
 *
 * Retry strategy
 *   Removed from `uploadFile` — retries now live in
 *   `useUploadFlow` (10.2) because they need to coordinate with the
 *   full pipeline (hash → compress → encrypt → fund → upload →
 *   register). A retry at this layer alone would re-upload the same
 *   ciphertext without knowing whether the fund or register step
 *   already succeeded. Single-shot here, retry orchestration above.
 */
export function useIrys() {
  const { session, getEip1193Provider } = useWallet();
  const [irysSession, setIrysSession] = useState<
    IrysSession & { balanceAtomic: string }
  >({
    instance: null,
    balance: "0",
    balanceAtomic: "0",
    address: null,
    isLoading: false,
  });

  /**
   * Handshake with the Irys node and read the loaded balance.
   * Returns `null` when the session is missing, on a different
   * chain than the contract, or when the wallet provider is not
   * available.
   */
  const initIrys = useCallback(async (): Promise<WebIrys | null> => {
    if (!session || session.kind !== "wallet") return null;
    if (session.chainId !== CHAIN_CONFIG.id) return null;
    if (!IRYS_CONFIG.node) return null;

    const provider = getEip1193Provider();
    if (!provider) return null;

    try {
      setIrysSession((s) => ({ ...s, isLoading: true }));

      // Ethers v6's `BrowserProvider` is structurally compatible with
      // viem's `EIP1193Provider` — both expose `request`. The two
      // type definitions diverge in shape only (ethers uses `any`
      // for the return, viem uses typed generics), so the cast at
      // the boundary is unavoidable but safe. The `on` and
      // `removeListener` methods, if present, let ethers invalidate
      // its internal cache on chain/account changes; if absent,
      // ethers works without the cache.
      const ethersProvider = provider as unknown as EthersEip1193;
      const browserProvider = new BrowserProvider(ethersProvider, {
        chainId: session.chainId,
        name: String(session.chainId),
      });

      const webIrys = new WebIrys({
        url: IRYS_CONFIG.node,
        token: "arbitrum",
        wallet: { name: "ethersv6", provider: browserProvider },
      });

      await webIrys.ready();

      const loadedBalance = await webIrys.getLoadedBalance();

      setIrysSession({
        instance: webIrys,
        balance: webIrys.utils.fromAtomic(loadedBalance).toString(),
        balanceAtomic: loadedBalance.toString(),
        address: session.address,
        isLoading: false,
      });

      return webIrys;
    } catch {
      setIrysSession((s) => ({ ...s, isLoading: false }));
      return null;
    }
  }, [session, getEip1193Provider]);

  /**
   * Fetch the storage price for a byte count (wei string).
   * Delegates to `initIrys` if the instance is not warm.
   */
  const getUploadPrice = useCallback(
    async (bytes: number): Promise<string> => {
      const irys = irysSession.instance ?? (await initIrys());
      if (!irys) return "0";
      const price = await irys.getPrice(bytes);
      return price.toString();
    },
    [irysSession.instance, initIrys],
  );

  /**
   * Upload ciphertext to Irys. Single-shot — retries live in
   * `useUploadFlow`. Wraps the "402 insufficient balance" case in a
   * known error code so the caller can react (`fundNode` then retry).
   */
  const uploadFile = useCallback(
    async (data: Buffer, tags: { name: string; value: string }[]) => {
      const irys = irysSession.instance ?? (await initIrys());
      if (!irys) throw new Error("IRYS_AUTH_FAILED");

      try {
        const receipt = await irys.upload(data as any, { tags });
        return receipt;
      } catch (error: any) {
        if (error?.message?.includes("402")) {
          throw new Error("INSUFFICIENT_NODE_BALANCE");
        }
        throw error;
      }
    },
    [irysSession.instance, initIrys],
  );

  /**
   * Top-up the Irys node balance. Uses a 5% buffer over the price to
   * absorb minor volatility between the estimate and the broadcast.
   *
   * The mobile floating-point precision bug (price arrives as
   * "1.234e15" instead of an integer) is handled the same way the
   * legacy hook did — extract the integer part before `BigInt`.
   */
  const fundNode = useCallback(
    async (priceAtomic: string) => {
      const irys = irysSession.instance ?? (await initIrys());
      if (!irys) throw new Error("IRYS_NOT_INITIALIZED");

      try {
        const integerPart = priceAtomic.split(".")[0] ?? "0";
        const basePrice = BigInt(integerPart);
        if (basePrice === 0n) return;

        const bufferedAmount = (basePrice * 105n) / 100n;
        await irys.fund(bufferedAmount.toString());

        const bal = await irys.getLoadedBalance();
        setIrysSession((s) => ({
          ...s,
          balanceAtomic: bal.toString(),
          balance: irys.utils.fromAtomic(bal).toString(),
        }));
      } catch (error: any) {
        const isRejected =
          error?.message?.includes("rejected") || error?.code === 4001;
        throw isRejected
          ? new Error("ACTION_REJECTED")
          : new Error("FUNDING_FAILED");
      }
    },
    [irysSession.instance, initIrys],
  );

  return { ...irysSession, initIrys, uploadFile, fundNode, getUploadPrice };
}

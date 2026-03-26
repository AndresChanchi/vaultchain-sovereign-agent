import { useState, useCallback } from "react";
import { WebIrys } from "@irys/sdk";
import { Buffer } from "buffer"; 
import { useEthersSigner } from "./useEthersSigner";
import { IRYS_CONFIG } from "@config/contracts";
import type { IrysSession } from "@interfaces/vault";

/**
 * Enhanced Irys Hook for 2026 Programmable Datachain.
 * Includes proactive cost estimation and atomic balance management.
 */
export function useIrys() {
  const [session, setSession] = useState<IrysSession & { balanceAtomic: string }>({
    instance: null,
    balance: "0",
    balanceAtomic: "0",
    address: null,
    isLoading: false,
  });

  const signer = useEthersSigner();

  /**
   * Handshakes with the Irys node and retrieves account state.
   */
  const initIrys = useCallback(async (): Promise<WebIrys | null> => {
    if (!signer || !IRYS_CONFIG.node) return null;

    try {
      setSession((s) => ({ ...s, isLoading: true }));
      
      const webIrys = new WebIrys({ 
        url: IRYS_CONFIG.node, 
        token: "arbitrum", 
        wallet: { name: "ethersv6", provider: signer.provider } 
      });

      await webIrys.ready();
      
      const loadedBalance = await webIrys.getLoadedBalance();
      const address = await signer.getAddress();

      const newSession = {
        instance: webIrys,
        balance: webIrys.utils.fromAtomic(loadedBalance).toString(),
        balanceAtomic: loadedBalance.toString(),
        address: address as `0x${string}`,
        isLoading: false,
      };

      setSession(newSession);
      return webIrys;
    } catch (error) {
      setSession((s) => ({ ...s, isLoading: false }));
      return null;
    }
  }, [signer]);

  /**
   * Fetches the storage price for a specific file size.
   * Essential for UI cost estimation before upload.
   * @param bytes Number of bytes to upload.
   */
  const getUploadPrice = useCallback(async (bytes: number): Promise<string> => {
    const irys = session.instance || await initIrys();
    if (!irys) return "0";
    const price = await irys.getPrice(bytes);
    return price.toString();
  }, [session.instance, initIrys]);

  /**
   * Executes the permanent storage upload.
   */
  const uploadFile = useCallback(async (data: Buffer, tags: { name: string, value: string }[]) => {
    const irys = session.instance || await initIrys();
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
  }, [session.instance, initIrys]);

  /**
   * Top-up logic for the Irys Node balance.
   * @param priceAtomic The base price fetched from the node.
   */
  const fundNode = useCallback(async (priceAtomic: string) => {
    const irys = session.instance || await initIrys();
    if (!irys) throw new Error("IRYS_NOT_INITIALIZED");

    try {
      /**
       * BUGFIX: Mobile floating point precision generates decimals in atomic strings.
       * We extract the integer part of the string. 
       * The '|| "0"' fallback satisfies TypeScript strict null checks.
       */
      const integerPart = priceAtomic.split('.')[0] || "0";
      const basePrice = BigInt(integerPart);
      
      /**
       * Safety Check: Ensure we never attempt to fund 0 or a malformed non-canonical value.
       */
      if (basePrice === 0n) return;

      const bufferedAmount = (basePrice * 105n) / 100n;
      
      await irys.fund(bufferedAmount.toString());
      
      const bal = await irys.getLoadedBalance();
      setSession(s => ({ 
        ...s, 
        balanceAtomic: bal.toString(),
        balance: irys.utils.fromAtomic(bal).toString() 
      }));
    } catch (error: any) {
      const isRejected = error?.message?.includes("rejected") || error?.code === 4001;
      throw isRejected ? new Error("ACTION_REJECTED") : new Error("FUNDING_FAILED");
    }
  }, [session.instance, initIrys]);

  return { ...session, initIrys, uploadFile, fundNode, getUploadPrice };
}

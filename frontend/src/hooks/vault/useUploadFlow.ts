"use client";

import { useCallback, useRef, useState } from "react";
import { sha256, type Hex } from "viem";
import { Buffer } from "buffer";
import { useWallet } from "@context/WalletContext";
import { useKipioCrypto } from "@hooks/useKipioCrypto";
import { useImageWorker } from "@hooks/useImageWorker";
import { useIrys } from "@hooks/useIrys";
import { useVault } from "@hooks/useVault";

/**
 * Upload flow — the end-to-end pipeline for adding photos to the
 * space.
 *
 * Stages per file (sequential):
 *
 *   hashing     sha256 of the original file → contentHash
 *   compressing browser-image-compression (worker + main-thread
 *               fallback handled inside `useImageWorker`)
 *   encrypting  AES-GCM-256 via `KipioContext.encryptFile` (worker)
 *   funding     Irys node balance top-up IF the current balance is
 *               below the price of this file's ciphertext
 *   uploading   Irys L1 upload (returns `receipt.id`)
 *   registering on-chain `registerUpload(contentHash, receipt.id)`
 *               — this call already triggers `bump()` on the
 *               `SpaceRefreshContext`, so `useSpaceStats` and
 *               `useSpaceGallery` refetch when it succeeds.
 *
 * Plus two outer stages:
 *
 *   preparing   unlock vault (if locked) + init Irys SDK
 *   kept        every file registered; state stays here until
 *               `reset()` is called
 *   error       any unrecoverable failure; UI offers retry
 *
 * Why sequential
 *   Two concurrent `registerUpload` calls race the account nonce and
 *   the Irys node balance. Sequentially processing files lets each
 *   stage observe the state produced by the previous file: after
 *   file 1 registers, the gallery (via `bump`) shows 1 photo; after
 *   file 2, 2 photos; etc.
 *
 * Wallet-only
 *   OAuth sessions use an ephemeral wallet with no funds. The flow
 *   refuses them upfront with `OAUTH_CANNOT_UPLOAD`. The dialog gate
 *   (10.4) prevents the flow from ever being called for OAuth; this
 *   check is belt-and-braces in case a future surface forgets.
 *
 * Popup count — honest about the current contract
 *   Fresh session, 1 file: unlock (personal_sign) + fund
 *   (eth_sendTransaction, only if balance low) + upload
 *   (eth_signTypedData_v4) + register (eth_sendTransaction).
 *   3 or 4 popups. The old contract cannot do better. New contracts
 *   reduce to 1. Copy says "Sign when your wallet asks" — no false
 *   promise.
 *
 * Fresh balance read
 *   `useIrys.balanceAtomic` is the balance at `start()` invocation
 *   time. The closure keeps that value; the `await initIrys()`
 *   updates the hook state but not the closure. Reading the balance
 *   fresh right before the funding check avoids an unnecessary
 *   funding tx on the first file of a warm session.
 *
 * Error wrapping — register stage
 *   `registerUpload` can fail for three reasons: user rejection
 *   (`ACTION_REJECTED`, silent), a network/revert error from the
 *   receipt, or an unknown. Wrapping it here distinguishes "the user
 *   said no" from "the transaction was rejected by the chain" so the
 *   UI can show the right message. `errorToDictKey` maps
 *   `REGISTER_FAILED` to `space.upload.error.register`.
 *
 * Cancellation vs. error
 *   Rejection returns to `idle` with no error — the user chose to
 *   abort. Any other failure lands in `stage: "error"` with a
 *   message the UI can translate. `runningRef` prevents re-entry.
 *
 * No cache invalidation here
 *   `registerUpload` already calls `bump()`. `useUploadFlow` does
 *   not duplicate that — the reactive hooks refetch on their own.
 *
 * Memory hygiene
 *   `previewUrl` for each file uses `URL.createObjectURL()`.
 *   `reset()` revokes every URL to prevent leaks across modal
 *   open/close cycles.
 */

/* ──────────────────────────────────────────────────────────────────
 * Types
 * ────────────────────────────────────────────────────────────────── */

export type UploadStage =
  | "idle"
  | "preparing"
  | "hashing"
  | "compressing"
  | "encrypting"
  | "funding"
  | "uploading"
  | "registering"
  | "kept"
  | "error";

export type UploadFile = {
  id: string;
  file: File;
  previewUrl: string;
};

export type UploadResult = {
  hash: Hex;
  irysId: string;
  txHash: Hex;
};

export type UploadState = {
  stage: UploadStage;
  files: UploadFile[];
  totalFiles: number;
  currentIndex: number;
  currentFileName: string | null;
  error: string | null;
  results: UploadResult[];
};

const INITIAL_STATE: UploadState = {
  stage: "idle",
  files: [],
  totalFiles: 0,
  currentIndex: 0,
  currentFileName: null,
  error: null,
  results: [],
};

/* ──────────────────────────────────────────────────────────────────
 * Helpers
 * ────────────────────────────────────────────────────────────────── */

function isCancellation(err: unknown): boolean {
  if (!err || typeof err !== "object") return false;
  const e = err as { code?: unknown; name?: unknown; message?: unknown };
  if (e.code === 4001 || e.code === "ACTION_REJECTED") return true;
  if (e.name === "UserRejectedRequestError") return true;
  if (typeof e.message === "string" && /rejected|denied/i.test(e.message)) {
    return true;
  }
  return false;
}

/* ──────────────────────────────────────────────────────────────────
 * Hook
 * ────────────────────────────────────────────────────────────────── */

export function useUploadFlow() {
  const { session } = useWallet();
  const { isLocked, unlockVault, encryptFile } = useKipioCrypto();
  const { compress } = useImageWorker();
  const {
    initIrys,
    uploadFile,
    fundNode,
    getUploadPrice,
  } = useIrys();
  const { registerUpload } = useVault();

  const [state, setState] = useState<UploadState>(INITIAL_STATE);
  const runningRef = useRef(false);

  const reset = useCallback(() => {
    setState((prev) => {
      for (const f of prev.files) {
        URL.revokeObjectURL(f.previewUrl);
      }
      return INITIAL_STATE;
    });
  }, []);

  const start = useCallback(
    async (files: File[]) => {
      if (runningRef.current) return;
      if (files.length === 0) return;

      if (!session) {
        setState({
          ...INITIAL_STATE,
          stage: "error",
          error: "WALLET_NOT_CONNECTED",
        });
        return;
      }

      if (session.kind !== "wallet") {
        setState({
          ...INITIAL_STATE,
          stage: "error",
          error: "OAUTH_CANNOT_UPLOAD",
        });
        return;
      }

      runningRef.current = true;

      const uploadFiles: UploadFile[] = files.map((file) => ({
        id: crypto.randomUUID(),
        file,
        previewUrl: URL.createObjectURL(file),
      }));

      setState({
        ...INITIAL_STATE,
        stage: "preparing",
        files: uploadFiles,
        totalFiles: uploadFiles.length,
      });

      try {
        // ── Prepare: unlock + init Irys ───────────────────────────
        if (isLocked) {
          try {
            await unlockVault();
          } catch (err) {
            throw new Error(
              isCancellation(err) ? "ACTION_REJECTED" : "UNLOCK_FAILED",
            );
          }
        }

        const irys = await initIrys();
        if (!irys) throw new Error("IRYS_INIT_FAILED");

        // ── Sequential pipeline per file ──────────────────────────
        const results: UploadResult[] = [];

        for (let i = 0; i < uploadFiles.length; i++) {
          const current = uploadFiles[i];
          if (!current) continue;
          const file = current.file;

          setState((s) => ({
            ...s,
            currentIndex: i,
            currentFileName: file.name,
          }));

          // 1. Hash
          setState((s) => ({ ...s, stage: "hashing" }));
          const originalBuffer = await file.arrayBuffer();
          const contentHash = sha256(new Uint8Array(originalBuffer));

          // 2. Compress — `compress()` handles worker readiness
          //    internally (main-thread fallback). No defensive throw.
          setState((s) => ({ ...s, stage: "compressing" }));
          const compressed = await compress(originalBuffer, file.type);

          // 3. Encrypt
          setState((s) => ({ ...s, stage: "encrypting" }));
          const encrypted = await encryptFile(compressed, contentHash);

          // 4. Fund (only if needed) — fresh balance read, not the
          //    closure's stale `balanceAtomic`. See header.
          setState((s) => ({ ...s, stage: "funding" }));
          const uploadBytes = encrypted.byteLength;
          const priceAtomic = await getUploadPrice(uploadBytes);
          const freshBalance = await irys.getLoadedBalance();
          if (BigInt(freshBalance.toString()) < BigInt(priceAtomic)) {
            try {
              await fundNode(priceAtomic);
            } catch (err) {
              throw new Error(
                isCancellation(err) ? "ACTION_REJECTED" : "FUNDING_FAILED",
              );
            }
          }

          // 5. Upload
          setState((s) => ({ ...s, stage: "uploading" }));
          const uploadData = Buffer.from(encrypted);
          const tags = [
            { name: "Content-Type", value: "image/webp" },
            { name: "Encryption", value: "AES-GCM-256" },
          ];
          const receipt = await uploadFile(uploadData, tags);
          if (!receipt?.id) throw new Error("IRYS_UPLOAD_FAILED");

          // 6. Register (triggers bump() internally) — wrapped so
          //    the UI can distinguish "user cancelled" from
          //    "transaction rejected" via `REGISTER_FAILED`. See
          //    "Error wrapping" in the header.
          setState((s) => ({ ...s, stage: "registering" }));
          let txHash: Hex;
          try {
            txHash = await registerUpload(contentHash, receipt.id);
          } catch (err) {
            throw new Error(
              isCancellation(err) ? "ACTION_REJECTED" : "REGISTER_FAILED",
            );
          }

          results.push({
            hash: contentHash,
            irysId: receipt.id,
            txHash,
          });
        }

        setState((s) => ({ ...s, stage: "kept", results }));
      } catch (err) {
        const cancelled = isCancellation(err);
        const message =
          err instanceof Error ? err.message : "UNKNOWN_ERROR";
        setState((s) => ({
          ...s,
          stage: cancelled ? "idle" : "error",
          error: cancelled ? null : message,
        }));
      } finally {
        runningRef.current = false;
      }
    },
    [
      session,
      isLocked,
      unlockVault,
      encryptFile,
      compress,
      initIrys,
      uploadFile,
      fundNode,
      getUploadPrice,
      registerUpload,
    ],
  );

  return { state, start, reset };
}

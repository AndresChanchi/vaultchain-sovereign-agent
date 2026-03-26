import { useState, useEffect, useCallback, useRef } from "react";
import * as Comlink from "comlink";
import imageCompression from "browser-image-compression";
import type { ImageWorkerAPI } from "@lib/workers/image.worker";

/**
 * Shared compression configuration to ensure parity between 
 * Worker execution and Main Thread fallback.
 */
const FALLBACK_OPTIONS = {
  maxSizeMB: 2,
  maxWidthOrHeight: 1920,
  useWebWorker: false, // Force Main Thread for fallback strategy
  initialQuality: 0.8,
  fileType: "image/webp",
} as const;

/**
 * Hook to interface with the Image Optimization Worker.
 * Implements a Graceful Fallback strategy for high-restriction mobile environments (iOS/WebKit).
 */
export function useImageWorker() {
  const workerRef = useRef<Worker | null>(null);
  const workerApi = useRef<Comlink.Remote<ImageWorkerAPI> | null>(null);
  const [isReady, setIsReady] = useState(false);

  /**
   * Initializes the worker using Turbopack-compatible URL resolution.
   */
  const initWorker = useCallback(() => {
    if (workerRef.current) workerRef.current.terminate();

    const worker = new Worker(new URL("../lib/workers/image.worker.ts", import.meta.url), {
      type: "module",
    });

    workerRef.current = worker;
    workerApi.current = Comlink.wrap<ImageWorkerAPI>(worker);
    setIsReady(true);
  }, []);

  useEffect(() => {
    initWorker();
    return () => workerRef.current?.terminate();
  }, [initWorker]);

  /**
   * Orchestrates image compression with automated fallback logic.
   * * RESILIENCE STRATEGY:
   * 1. PREVENTIVE CLONING: Slices the buffer before transfer to keep the original alive.
   * 2. RETRY LOGIC: Reboots the worker on mobile if the thread is killed by the OS.
   * 3. MAIN THREAD FALLBACK: Executes local compression if WASM or Workers fail.
   */
  const compress = useCallback(async (buffer: ArrayBuffer, mimeType: string): Promise<ArrayBuffer> => {
    const isMobile = typeof navigator !== 'undefined' && /iPhone|iPad|iPod|Android/i.test(navigator.userAgent);
    const maxAttempts = isMobile ? 3 : 1;
    let lastError: any;

    // Phase A: Attempt Worker Execution (Off-main-thread)
    if (workerApi.current) {
      for (let attempt = 0; attempt < maxAttempts; attempt++) {
        try {
          /**
           * MEMORY SHIELDING FIX:
           * Comlink.transfer 'steals' the memory reference (Zero-Copy). 
           * We MUST slice(0) to create a temporary pointer for the worker.
           * This ensures the original 'buffer' remains available if we need to Fallback.
           */
          const bufferForWorker = buffer.slice(0);
          
          return await workerApi.current.compressImage(
            Comlink.transfer(bufferForWorker, [bufferForWorker]),
            mimeType
          );
        } catch (err: any) {
          // Extract error message (expecting a primitive string from worker)
          const errorMsg = typeof err === 'string' ? err : err.message;
          lastError = new Error(errorMsg);

          // If it's a mobile environment and not a cloning error, try to reboot the worker
          if (isMobile && !errorMsg?.includes('cloned') && attempt < maxAttempts - 1) {
            initWorker(); 
            await new Promise(r => setTimeout(r, 1000));
            continue;
          }
          break;
        }
      }
    }

    /**
     * Phase B: Synchronous Fallback (Main Thread)
     * Triggered if the Worker is unavailable, fails retries, or throws an unrecoverable error.
     * The original 'buffer' is perfectly preserved here thanks to the preventive slice(0) above.
     */
    try {
      const fallbackBlob = new Blob([buffer], { type: mimeType });
      const compressedFile = await imageCompression(fallbackBlob as File, FALLBACK_OPTIONS);
      return await compressedFile.arrayBuffer();
    } catch (fallbackErr: any) {
      throw new Error(`CRITICAL_FAILURE: ${fallbackErr.message || lastError?.message}`);
    }
  }, [initWorker]);

  return { compress, isReady };
}

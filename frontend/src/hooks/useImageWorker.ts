import { useState, useEffect, useCallback, useRef } from "react";
import * as Comlink from "comlink";
import type { ImageWorkerAPI } from "@lib/workers/image.worker";

export function useImageWorker() {
  // Maybe use useRef to avoid the mistake DataCloneError
  const workerApi = useRef<Comlink.Remote<ImageWorkerAPI> | null>(null);
  const [isReady, setIsReady] = useState(false);

  useEffect(() => {
    const worker = new Worker(new URL("../lib/workers/image.worker.ts", import.meta.url), {
      type: "module",
    });
    
    workerApi.current = Comlink.wrap<ImageWorkerAPI>(worker);
    setIsReady(true);
    
    return () => {
      worker.terminate();
      setIsReady(false);
    };
  }, []);

  const compress = useCallback(async (file: File) => {
    if (!workerApi.current) throw new Error("Image worker not ready");
    return await workerApi.current.compressImage(file);
  }, []);

  return { compress, isReady };
}

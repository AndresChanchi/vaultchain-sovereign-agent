import * as Comlink from "comlink";
import imageCompression from "browser-image-compression";

/**
 * Image processing configuration for a professional gallery.
 * Optimized for 2026 hardware-accelerated WebP encoding.
 */
const COMPRESSION_OPTIONS = {
  maxSizeMB: 2,           // Limit for Irys costs optimization
  maxWidthOrHeight: 1920, // Full HD is sufficient for web previews
  useWebWorker: false,    // Already running inside a worker context
  initialQuality: 0.8,
  fileType: "image/webp", // 2026 Industry Standard for efficiency
} as const;

const imageWorkerApi = {
  /**
   * Compresses an image using a flattened argument structure.
   * Passing arguments separately (buffer, mimeType) prevents WebKit from 
   * attempting to clone complex Proxy objects, solving 'DataCloneError' on mobile.
   * * @param buffer The raw ArrayBuffer of the image.
   * @param mimeType The original mime type (e.g., 'image/jpeg').
   */
  async compressImage(buffer: ArrayBuffer, mimeType: string): Promise<ArrayBuffer> {
    try {
      // Reconstruct Blob from the transferred (detached) buffer
      const blob = new Blob([buffer], { type: mimeType || "image/jpeg" });
      
      let fileToCompress: File | Blob = blob;
      if (typeof File !== 'undefined') {
        fileToCompress = new File([blob], "asset", { type: mimeType || "image/jpeg" });
      }

      const compressedFile = await imageCompression(fileToCompress as File, COMPRESSION_OPTIONS);
      const outputBuffer = await compressedFile.arrayBuffer();
      
      /**
       * ZERO-COPY TRANSFER:
       * Detaches the outputBuffer from the worker thread and moves it to the main thread.
       * This is high-performance memory management for 2026 web standards.
       */
      return Comlink.transfer(outputBuffer, [outputBuffer]);
    } catch (error: any) {
      /**
       * WebKit cannot clone native 'Error' objects across threads via postMessage.
       * Throwing an Error object causes a "DataCloneError" which masks the real issue.
       * We MUST throw a primitive string to ensure the main thread receives the diagnostic.
       */
      throw `WASM_INTERNAL_ERR: ${error.message || "Memory Limit Exceeded"}`;
    }
  }
};

Comlink.expose(imageWorkerApi);
export type ImageWorkerAPI = typeof imageWorkerApi;

import * as Comlink from "comlink";
import imageCompression from "browser-image-compression";

/**
 * Image processing configuration for a professional gallery.
 */
const COMPRESSION_OPTIONS = {
  maxSizeMB: 2,            // Limit for Irys costs
  maxWidthOrHeight: 1920,  // Full HD is enough for web preview
  useWebWorker: false,     // False because WE ARE already in a worker
  initialQuality: 0.8,
  fileType: "image/webp",  // WebP is the gold standard for 2026
} as const;

const imageWorkerApi = {
  /**
   * Compresses an image file and returns an ArrayBuffer.
   */
  async compressImage(file: File): Promise<ArrayBuffer> {
    try {
      const compressedFile = await imageCompression(file, COMPRESSION_OPTIONS);
      const buffer = await compressedFile.arrayBuffer();
      
      // Zero-copy transfer to main thread
      return Comlink.transfer(buffer, [buffer]);
    } catch (error) {
      console.error("Compression worker error:", error);
      throw new Error("IMAGE_COMPRESSION_FAILED");
    }
  },

  /**
   * Generates a fast thumbnail for the UI.
   */
  async generateThumbnail(file: File): Promise<ArrayBuffer> {
    const thumbOptions = {
      ...COMPRESSION_OPTIONS,
      maxSizeMB: 0.1,
      maxWidthOrHeight: 400,
    };
    
    const thumbFile = await imageCompression(file, thumbOptions);
    const buffer = await thumbFile.arrayBuffer();
    return Comlink.transfer(buffer, [buffer]);
  }
};

Comlink.expose(imageWorkerApi);

export type ImageWorkerAPI = typeof imageWorkerApi;

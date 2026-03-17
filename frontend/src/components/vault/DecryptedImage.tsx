import React, { useState, useEffect } from 'react';
import { useKipioCrypto } from '@hooks/useKipioCrypto';
import { IRYS_CONFIG } from '@config/contracts';
import type { Hex } from 'viem';

/**
 * DecryptedImage Component
 * * INTENT / VISION:
 * This component represents the "Final Frontier" of the private vault. 
 * Developed for ETH Global, the goal is to demonstrate true data sovereignty.
 * * Logic flow:
 * 1. Secure Fetching: Pulls encrypted raw bytes directly from Irys Data L1.
 * 2. Off-main-thread Decryption: Uses Web Workers to decrypt AES-GCM payloads, 
 * ensuring the UI remains buttery smooth at 60fps.
 * 3. Zero-Knowledge rendering: The plaintext never touches a central server; 
 * it's converted to a local Blob URL and wiped from memory on unmount.
 */

interface DecryptedImageProps {
  contentHash: Hex;
  irysId: string;
}

export function DecryptedImage({ contentHash, irysId }: DecryptedImageProps) {
  const { decryptFile, isLocked } = useKipioCrypto();
  
  const [imageUrl, setImageUrl] = useState<string | null>(null);
  const [status, setStatus] = useState<'loading' | 'decrypting' | 'ready' | 'error'>('loading');

  useEffect(() => {
    let objectUrl: string | null = null;
    let isMounted = true; // Guard to prevent state updates on unmounted components

    const fetchAndDecrypt = async () => {
      if (isLocked) {
        setStatus('error');
        return;
      }

      try {
        // 1. Fetch encrypted bytes from Irys Data L1
        setStatus('loading');
        
        // Normalize Gateway URL
        const baseUrl = IRYS_CONFIG.gateway?.replace(/\/$/, '') || 'https://gateway.irys.xyz';
        const response = await fetch(`${baseUrl}/${irysId}`);
        
        if (!response.ok) throw new Error("Network error fetching from Irys L1");
        const encryptedBuffer = await response.arrayBuffer();

        if (!isMounted) return;

        // 2. Decrypt using the Secondary Thread (Web Worker)
        setStatus('decrypting');
        const decryptedBuffer = await decryptFile(encryptedBuffer, contentHash);

        if (!isMounted) return;

        // 3. Convert raw Buffer to a renderable local Image
        // Optimized for modern web standards using WebP/AVIF
        const blob = new Blob([decryptedBuffer], { type: 'image/webp' });
        objectUrl = URL.createObjectURL(blob);
        
        setImageUrl(objectUrl);
        setStatus('ready');

      } catch (error) {
        console.error("[Kipio-Vault] Failed to retrieve or decrypt asset:", error);
        if (isMounted) setStatus('error');
      }
    };

    if (irysId && contentHash && !isLocked) {
      fetchAndDecrypt();
    }

    // CLEANUP: Vital to prevent Memory Leaks by revoking the Object URL
    return () => {
      isMounted = false;
      if (objectUrl) {
        URL.revokeObjectURL(objectUrl);
      }
    };
  }, [irysId, contentHash, decryptFile, isLocked]);

  // UI States (Eth Global Terminal Style)
  if (status === 'error') {
    return (
      <div className="w-full h-48 bg-red-900/20 rounded-xl flex items-center justify-center border border-red-500/30">
        <span className="text-red-400 text-xs font-mono">DECRYPTION_FAILED::AUTH_OR_DATA_CORRUPT</span>
      </div>
    );
  }

  if (status !== 'ready' || !imageUrl) {
    return (
      <div className="w-full h-48 bg-gray-800 rounded-xl flex flex-col items-center justify-center animate-pulse border border-gray-700">
        <div className="w-4 h-4 rounded-full border-2 border-blue-500 border-t-transparent animate-spin mb-2" />
        <span className="text-gray-400 text-xs font-mono uppercase tracking-tighter">
          {status === 'loading' ? 'Fetching from Irys L1...' : 'Decrypting Payload...'}
        </span>
      </div>
    );
  }

  return (
    <div className="relative group rounded-xl overflow-hidden bg-gray-900 border border-gray-700">
      {/* Next.js optimized local render via Blob */}
      <img 
        src={imageUrl} 
        alt={`Decrypted content: ${contentHash.substring(0, 8)}`}
        className="w-full h-48 object-cover transition-transform duration-500 group-hover:scale-110"
      />
      
      {/* HUD: On-hover technical metadata for developers */}
      <div className="absolute inset-x-0 bottom-0 bg-black/80 backdrop-blur-md p-3 translate-y-full group-hover:translate-y-0 transition-transform duration-300">
        <p className="text-[10px] text-gray-400 font-mono flex justify-between">
          <span className="text-blue-400">HASH:</span> {contentHash.substring(0, 20)}...
        </p>
        <p className="text-[10px] text-gray-400 font-mono flex justify-between">
          <span className="text-purple-400">IRYS_ID:</span> {irysId.substring(0, 20)}...
        </p>
      </div>
    </div>
  );
}

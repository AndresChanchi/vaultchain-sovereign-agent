"use client";

import React, { useState, useEffect, useRef } from 'react';
import { useKipioCrypto } from '@hooks/useKipioCrypto';
import { IRYS_CONFIG } from '@config/contracts';
import type { Hex } from 'viem';

/**
 * @title Atomic Decryption Unit (v2026.03)
 * @notice Optimized for React 19 Concurrent Rendering.
 * @dev Silently waits for the KipioContext to provide the Master Key.
 */
interface DecryptedImageProps {
  contentHash: Hex;
  irysId: string;
}

export function DecryptedImage({ contentHash, irysId }: DecryptedImageProps) {
  const { decryptFile, isLocked } = useKipioCrypto();
  
  const [imageUrl, setImageUrl] = useState<string | null>(null);
  const [status, setStatus] = useState<'loading' | 'decrypting' | 'ready' | 'error'>('loading');
  
  const hasLoggedInit = useRef(false);

  useEffect(() => {
    let objectUrl: string | null = null;
    let isMounted = true;

    const fetchAndDecrypt = async () => {
      // GUARD: Wait for context initialization and avoid re-decryption
      if (isLocked || !decryptFile || imageUrl) {
        if (!hasLoggedInit.current) {
          hasLoggedInit.current = true;
        }
        return;
      }

      try {
        setStatus('loading');
        
        // 1. GATEWAY RESOLUTION
        const baseUrl = (IRYS_CONFIG.gateway || 'https://gateway.irys.xyz').replace(/\/$/, '');
        const targetUrl = `${baseUrl}/${irysId}`;
        
        let response: Response | undefined;
        let attempt = 1;
        const maxAttempts = 3;

        // Robust retry loop for Irys propagation delays
        while (attempt <= maxAttempts && isMounted) {
          try {
            response = await fetch(targetUrl, { cache: 'no-store' });
            if (response.ok) break;
            
            console.warn(`[Kipio-Vault] ⏳ Attempt ${attempt} failed (Status: ${response.status}). Retrying...`);
          } catch (e) {
            console.error(`[Kipio-Vault] Network error on attempt ${attempt}`);
          }
          
          attempt++;
          if (attempt <= maxAttempts) await new Promise(r => setTimeout(r, 2000));
        }

        if (!response || !response.ok) {
          throw new Error(`L1_FETCH_FAILED_AFTER_${maxAttempts}_ATTEMPTS`);
        }

        const encryptedBuffer = await response.arrayBuffer();
        if (!isMounted) return;

        // 2. CRYPTOGRAPHIC PROCESSING (Off-thread via KipioContext)
        setStatus('decrypting');
        const decryptedBuffer = await decryptFile(encryptedBuffer, contentHash);

        if (!isMounted || !decryptedBuffer) {
          throw new Error("DECRYPTION_RETURNED_NULL");
        }

        // 3. ASSET RECONSTRUCTION
        const blob = new Blob([decryptedBuffer], { type: 'image/webp' });
        objectUrl = URL.createObjectURL(blob);
        
        if (isMounted) {
          setImageUrl(objectUrl);
          setStatus('ready');
        }

      } catch (error) {
        console.error("[Kipio-Vault] 🔥 Pipeline Failure:", error);
        if (isMounted) setStatus('error');
      }
    };

    fetchAndDecrypt();

    return () => {
      isMounted = false;
      if (objectUrl) {
        URL.revokeObjectURL(objectUrl);
      }
    };
  }, [irysId, contentHash, decryptFile, isLocked, imageUrl]);

  // --- RENDERS (Tu UI Original Perfectamente Conservada) ---

  if (status === 'error') {
    return (
      <div className="w-full h-56 bg-red-950/20 rounded-[2rem] flex flex-col items-center justify-center border border-red-500/20">
        <svg className="w-6 h-6 text-red-500/50 mb-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
        </svg>
        <span className="text-red-400 text-[10px] font-mono uppercase tracking-widest text-center px-4">
          PIPELINE_ERROR // CHECK_CONSOLE
        </span>
      </div>
    );
  }

  if (status !== 'ready' || !imageUrl) {
    return (
      <div className="w-full h-56 bg-white/5 rounded-[2rem] flex flex-col items-center justify-center border border-white/5 animate-pulse">
        <div className="relative">
          <div className="w-8 h-8 rounded-full border-2 border-blue-500/20 border-t-blue-500 animate-spin" />
          <div className="absolute inset-0 w-8 h-8 rounded-full blur-md bg-blue-500/20 animate-pulse" />
        </div>
        <span className="mt-4 text-gray-500 text-[10px] font-mono uppercase tracking-[0.2em]">
          {status === 'loading' ? 'Syncing_L1' : 'Decrypting_Core'}
        </span>
      </div>
    );
  }

  return (
    <div className="relative group rounded-[2rem] overflow-hidden bg-black/40 border border-white/5 transition-all duration-500 hover:border-blue-500/30 shadow-2xl">
      <img 
        src={imageUrl} 
        alt="Vault Asset" 
        className="w-full h-56 object-cover transition-transform duration-700 group-hover:scale-105" 
      />
      <div className="absolute inset-0 bg-gradient-to-t from-black via-black/20 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 flex flex-col justify-end p-6">
        <div className="space-y-1 backdrop-blur-sm bg-black/40 p-3 rounded-2xl border border-white/10">
          <div className="flex justify-between items-center">
            <span className="text-[9px] text-blue-400 font-bold uppercase tracking-widest">Protocol</span>
            <span className="text-[9px] text-white font-mono">AES-GCM-256</span>
          </div>
          <div className="flex justify-between items-center">
            <span className="text-[9px] text-purple-400 font-bold uppercase tracking-widest">Storage</span>
            <span className="text-[9px] text-white font-mono">Irys L1</span>
          </div>
          <div className="pt-2 mt-2 border-t border-white/5">
            <p className="text-[8px] text-gray-400 font-mono break-all leading-tight">
               HASH: {contentHash.substring(0, 16)}...
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}

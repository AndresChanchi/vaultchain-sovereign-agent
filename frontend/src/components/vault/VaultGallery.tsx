"use client";

import React, { useState, useEffect, useCallback, useRef } from 'react';
import { useAccount } from 'wagmi';
import { useVault } from '@hooks/useVault';
import { useKipioCrypto } from '@hooks/useKipioCrypto'; 
import { DecryptedImage } from './DecryptedImage';
import type { Hex } from 'viem';

interface GalleryItem {
  hash: Hex;
  irysId: string;
}

/**
 * @title Decentralized Gallery Orchestrator
 * @notice Manages asset synchronization between Arbitrum Stylus (Registry) and Irys (Storage).
 * @dev Highly optimized: Only fetches blockchain data AFTER the user unlocks the vault locally.
 */
export function VaultGallery() {
  const { address } = useAccount();
  
  // Consuming the Bridge Hook
  const { isLocked, unlockVault, isUnlocking } = useKipioCrypto();
  const { getGallery, getPhotoId, getTotalPhotos, isProcessing } = useVault();
  
  const [items, setItems] = useState<GalleryItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [total, setTotal] = useState(0);

  const lastProcessingRef = useRef(isProcessing);

  const loadGallery = useCallback(async (isAutoRefresh = false) => {
    // SECURITY GUARD: Never query the chain if locked or disconnected
    if (!address || isLocked) return;
    
    try {
      if (!isAutoRefresh) setLoading(true);
      
      const count = await getTotalPhotos();
      setTotal(count);

      if (count === 0) {
        setItems([]);
        return;
      }

      const hashes = await getGallery(0, 12); 

      const resolvedItems = await Promise.all(
        hashes.map(async (hash) => {
          const irysId = await getPhotoId(hash);
          return { hash, irysId };
        })
      );

      const validItems = resolvedItems.filter(item => item.irysId && item.irysId !== "");
      setItems(validItems);

    } catch (error) {
      console.error("[VaultGallery] Sync Error:", error);
    } finally {
      setLoading(false);
    }
  }, [address, isLocked, getGallery, getPhotoId, getTotalPhotos]);

  /**
   * @dev REACTIVE TRIGGER
   * This is where the magic happens. When the user signs and 'isLocked' 
   * becomes false in the Provider, this effect automatically fetches the gallery.
   */
  useEffect(() => {
    if (!isLocked && address) {
      loadGallery();
    }
  }, [isLocked, address, loadGallery]);

  // Auto-refresh after a Stylus transaction finishes
  useEffect(() => {
    if (lastProcessingRef.current === true && isProcessing === false) {
      const timer = setTimeout(() => loadGallery(true), 2500);
      return () => clearTimeout(timer);
    }
    lastProcessingRef.current = isProcessing;
  }, [isProcessing, loadGallery]);

  if (!address) return null;

  // STRICT LOCK STATE: Zero data leakage, full UI block
  if (isLocked) {
    return (
      <div className="w-full py-24 flex flex-col items-center justify-center border border-white/5 rounded-[2rem] bg-gradient-to-b from-blue-600/5 to-transparent backdrop-blur-sm">
        <div className="mb-6 p-5 bg-blue-500/10 rounded-full border border-blue-500/20 shadow-[0_0_30px_rgba(59,130,246,0.2)]">
          <svg className="w-10 h-10 text-blue-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
          </svg>
        </div>
        <h3 className="text-2xl font-bold text-white mb-2">Access Local Key</h3>
        <p className="text-gray-400 text-sm mb-8 text-center font-mono uppercase opacity-60">
          AES-GCM-256 Vault: Signature required for local decryption.
        </p>
        <button
          onClick={() => unlockVault()}
          disabled={isUnlocking}
          className="px-8 py-4 bg-blue-600 hover:bg-blue-500 disabled:bg-gray-800 text-white rounded-2xl font-black transition-all shadow-xl active:scale-95"
        >
          {isUnlocking ? 'AUTHORIZING PIPELINE...' : 'UNLOCK SECURE VAULT'}
        </button>
      </div>
    );
  }

  // UNLOCKED STATE: Standard Gallery
  return (
    <div className="space-y-8">
      <div className="flex justify-between items-end border-b border-white/5 pb-6">
        <div>
          <h2 className="text-3xl font-black text-white tracking-tighter italic">PRIVATE_VAULT</h2>
          <div className="flex items-center gap-2 mt-1">
            <div className="w-1.5 h-1.5 bg-green-500 rounded-full animate-pulse shadow-[0_0_8px_rgba(34,197,94,0.6)]" />
            <p className="text-xs text-gray-500 font-mono uppercase tracking-widest">
              {total} Secure Objects // Stylus L2
            </p>
          </div>
        </div>
        
        <button onClick={() => loadGallery()} disabled={loading} className="p-3 bg-white/5 hover:bg-white/10 rounded-xl border border-white/5 transition-colors">
          <svg className={`w-5 h-5 text-blue-400 ${loading ? 'animate-spin' : ''}`} fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
          </svg>
        </button>
      </div>

      {loading && items.length === 0 ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-8">
          {[...Array(3)].map((_, i) => (
            <div key={i} className="w-full h-64 bg-white/5 animate-pulse rounded-[2rem]" />
          ))}
        </div>
      ) : items.length === 0 ? (
        <div className="text-center py-32 border-2 border-dashed border-white/5 rounded-[2.5rem]">
          <p className="text-gray-600 font-mono text-sm uppercase tracking-[0.3em]">VAULT_STATUS: EMPTY</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-8">
          {items.map((item) => (
            <div key={item.hash} className="group relative">
              <DecryptedImage contentHash={item.hash} irysId={item.irysId} />
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

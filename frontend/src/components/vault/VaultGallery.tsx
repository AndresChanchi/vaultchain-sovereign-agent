import React, { useState, useEffect, useCallback } from 'react';
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
 * VaultGallery Component
 * Acts as the primary orchestrator for fetching encrypted metadata from Arbitrum Stylus
 * and rendering decentralized assets from Irys.
 * * DESIGN PATTERN: Gatekeeper Pattern. 
 * We prevent data fetching and rendering until the local Master Key is derived.
 */
export function VaultGallery() {
  const { address } = useAccount();
  
  // Access cryptographic state to ensure the environment is ready for decryption
  const { isLocked, unlockVault, isUnlocking } = useKipioCrypto();
  
  const { getGallery, getPhotoId, getTotalPhotos } = useVault();
  
  const [items, setItems] = useState<GalleryItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [total, setTotal] = useState(0);

  /**
   * Synchronizes the gallery state with the on-chain registry.
   * Only triggered once the Vault is unlocked to avoid unnecessary RPC calls.
   */
  const loadGallery = useCallback(async () => {
    if (!address || isLocked) return;
    
    try {
      setLoading(true);
      
      // 1. Fetch total count and paginated hashes from Stylus (MVP limit: 12)
      const count = await getTotalPhotos();
      const hashes = await getGallery(0, 12); 
      setTotal(count);

      // 2. Parallelize the retrieval of Irys transaction IDs
      const resolvedItems = await Promise.all(
        hashes.map(async (hash) => {
          const irysId = await getPhotoId(hash);
          return { hash, irysId };
        })
      );

      // Filter out any potential empty/malformed entries
      setItems(resolvedItems.filter(item => item.irysId !== ""));
    } catch (error) {
      console.error("[VaultGallery] Sync failed:", error);
    } finally {
      setLoading(false);
    }
  }, [address, isLocked, getGallery, getPhotoId, getTotalPhotos]);

  // Re-sync whenever the vault is unlocked or the user changes
  useEffect(() => {
    loadGallery();
  }, [loadGallery]);

  if (!address) return null;

  // --- UI GUARD: VAULT LOCKED ---
  // We don't want to show "Empty Vault" if the data is simply locked.
  if (isLocked) {
    return (
      <div className="w-full py-20 flex flex-col items-center justify-center border-2 border-dashed border-blue-500/20 rounded-2xl bg-blue-500/5">
        <div className="mb-4 p-4 bg-blue-500/10 rounded-full">
          <svg className="w-8 h-8 text-blue-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
          </svg>
        </div>
        <h3 className="text-xl font-bold text-white mb-2">Vault Encrypted</h3>
        <p className="text-gray-400 text-sm mb-6 max-w-xs text-center font-mono">
          Decentralized metadata detected. Please sign to derive your local decryption key.
        </p>
        <button
          onClick={() => unlockVault()}
          disabled={isUnlocking}
          className="px-6 py-3 bg-blue-600 hover:bg-blue-500 disabled:bg-gray-800 text-white rounded-xl font-bold transition-all flex items-center gap-3 shadow-lg shadow-blue-900/20"
        >
          {isUnlocking ? (
            <><div className="w-4 h-4 border-2 border-white/30 border-t-white animate-spin rounded-full" /> AUTHORIZING...</>
          ) : (
            'UNLOCK VAULT'
          )}
        </button>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h2 className="text-2xl font-bold text-white">Your Private Vault</h2>
          <p className="text-sm text-gray-400 font-mono">{total} Assets Secured on Arbitrum</p>
        </div>
        <button 
          onClick={loadGallery}
          className="p-2 hover:bg-gray-800 rounded-full transition-colors group"
          title="Sync Gallery"
        >
          <svg className={`w-5 h-5 text-blue-400 group-hover:text-blue-300 ${loading ? 'animate-spin' : ''}`} fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
          </svg>
        </button>
      </div>

      {loading && items.length === 0 ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          {[...Array(3)].map((_, i) => (
            <div key={i} className="w-full h-48 bg-gray-900/50 animate-pulse rounded-xl border border-gray-800" />
          ))}
        </div>
      ) : items.length === 0 ? (
        <div className="text-center py-20 border-2 border-dashed border-gray-800 rounded-2xl">
          <p className="text-gray-500 font-mono">VAULT_EMPTY: No encrypted data found on-chain.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          {items.map((item) => (
            <DecryptedImage 
              key={item.hash} 
              contentHash={item.hash} 
              irysId={item.irysId} 
            />
          ))}
        </div>
      )}
    </div>
  );
}

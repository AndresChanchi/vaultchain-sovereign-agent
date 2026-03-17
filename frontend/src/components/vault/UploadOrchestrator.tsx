import React, { useState } from 'react';
import { sha256 } from 'viem';
import { Buffer } from 'buffer';
import { useKipioCrypto } from '@hooks/useKipioCrypto';
import { useIrys } from '@hooks/useIrys';
import { useVault } from '@hooks/useVault';
import { useImageWorker } from '@hooks/useImageWorker';

/**
 * ARCHITECTURE: UPLOAD ORCHESTRATOR (7-STEP MULTI-CHAIN PIPELINE)
 * * 1. Vault Unlock: Identity verification via EIP-712 Signature.
 * 2. Irys Handshake: Dynamic instance management to bypass React's state lag.
 * 3. WASM Optimization: Local image compression via Worker thread.
 * 4. Integrity Hashing: SHA256 calculation for Stylus ID mapping.
 * 5. AES-GCM Encryption: Client-side encryption with derived Vault Key.
 * 6. Permanent Storage: Data availability on Irys L1 (Arweave Layer).
 * 7. Stylus Registration: Atomic mapping of Hash -> Arweave ID on Arbitrum.
 */
export function UploadOrchestrator() {
  const { encryptFile, isLocked, unlockVault, workerReady: cryptoReady } = useKipioCrypto();
  const { uploadFile, instance: sessionInstance, initIrys } = useIrys();
  const { registerUpload, isProcessing, invalidateVaultCache } = useVault();
  const { compress, isReady: imageReady } = useImageWorker();
  
  const [status, setStatus] = useState<string>('idle');
  const [txDetails, setTxDetails] = useState<{ hash: string, id: string } | null>(null);

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    
    // GUARD: Ensure all cryptographic and WASM subsystems are functional
    if (!file || !cryptoReady || !imageReady) {
      console.warn("Pipeline blocked: System workers not yet initialized.");
      return;
    }

    try {
      setTxDetails(null);

      // STEP 1: VAULT UNLOCK (EIP-712 Signature)
      if (isLocked) {
        setStatus('Unlocking Vault...');
        await unlockVault();
      }

      // STEP 2: DYNAMIC IRYS INITIALIZATION
      // Technical Bypass: We use the returned instance directly from initIrys() 
      // because the 'sessionInstance' from the hook won't update until the next render cycle.
      let activeIrys = sessionInstance;
      if (!activeIrys) {
        setStatus('Connecting to Irys L1...');
        activeIrys = await initIrys();
      }

      if (!activeIrys) throw new Error("IRYS_INITIALIZATION_FAILED");

      // STEP 3: WASM IMAGE COMPRESSION
      setStatus('Optimizing (WASM)...');
      const compressedBuffer = await compress(file);

      // STEP 4: INTEGRITY HASHING
      // We hash the plain compressed data to create a deterministic ID for Arbitrum Stylus
      setStatus('Hashing Integrity...');
      const contentHash = sha256(new Uint8Array(compressedBuffer));

      // STEP 5: AES-GCM CLIENT-SIDE ENCRYPTION
      // The compressedBuffer is moved (Zero-copy transfer) to the Web Crypto Worker
      setStatus('Encrypting Protocol...');
      const encryptedBuffer = await encryptFile(compressedBuffer, contentHash);

      // STEP 6: PERMANENT STORAGE (Irys L1)
      setStatus('Storing on Arweave...');
      const tags = [
        { name: "Content-Type", value: "application/octet-stream" },
        { name: "App-Name", value: "Kipio-Vault-v1" },
        { name: "Encryption", value: "AES-GCM-256" }
      ];
      
      /** * Irys L1 handles Data Availability. 
       * We use Buffer.from to satisfy the SDK's Node-compatible requirement.
       */
      const receipt = await activeIrys.upload(Buffer.from(encryptedBuffer) as any, { tags });
      const irysId = receipt.id;

      // STEP 7: ARBITRUM STYLUS REGISTRATION
      setStatus('Finalizing on Stylus...');
      await registerUpload(contentHash, irysId);

      // UI REFRESH & TRANSPARENCY
      invalidateVaultCache();
      setTxDetails({ hash: contentHash, id: irysId });
      setStatus('Success! File Secured.');
      
      // Auto-reset after 15s to let the user inspect the Tx IDs
      setTimeout(() => setStatus('idle'), 15000); 
      
    } catch (error: any) {
      console.error("Pipeline Breakdown:", error);
      setStatus(`Error: ${error.message || 'Check System Logs'}`);
    }
  };

  const isSystemReady = cryptoReady && imageReady;

  return (
    <div className="w-full max-w-md p-8 border-2 border-dashed border-gray-700 rounded-2xl bg-gray-900/60 backdrop-blur-md shadow-2xl">
      <div className="flex flex-col items-center gap-6">
        <div className="text-center">
          <h3 className="text-lg font-bold text-white tracking-tight">Secure Upload Pipeline</h3>
          <p className={`text-xs mt-1 uppercase tracking-widest font-mono ${status.includes('Error') ? 'text-red-400' : 'text-blue-400'}`}>
            {!isSystemReady ? 'WASM/CRYPTO INITIALIZING...' : status}
          </p>
        </div>
        
        {isLocked ? (
          <button 
            onClick={() => unlockVault()}
            disabled={!isSystemReady}
            className="w-full py-4 bg-blue-600 hover:bg-blue-500 disabled:bg-gray-800 disabled:text-gray-600 text-white rounded-xl font-bold transition-all shadow-lg active:scale-95"
          >
            UNLOCK VAULT (EIP-712)
          </button>
        ) : (
          <div className="w-full">
            <label className={`flex flex-col items-center justify-center w-full h-32 border-2 border-gray-600 border-dashed rounded-xl transition-all ${!isSystemReady ? 'opacity-30 cursor-not-allowed' : 'cursor-pointer hover:bg-gray-800/50 hover:border-blue-500'}`}>
              <div className="flex flex-col items-center justify-center pt-5 pb-6 text-center">
                <p className="mb-2 text-sm text-gray-300 px-4">
                  <span className="font-semibold text-blue-400 underline">Select sensitive media</span>
                </p>
                <p className="text-[10px] text-gray-500 font-mono italic">CLIENT-SIDE AES-256</p>
              </div>
              <input 
                type="file" 
                className="hidden" 
                accept="image/*"
                onChange={handleFileChange}
                disabled={!isSystemReady || (status !== 'idle' && !status.includes('Success'))}
              />
            </label>
          </div>
        )}
        
        {/* DATA AVAILABILITY PROOF */}
        {txDetails && (
          <div className="w-full p-4 bg-blue-500/5 border border-blue-500/20 rounded-xl animate-in fade-in slide-in-from-bottom-2">
            <div className="space-y-3">
              <div className="flex flex-col">
                <span className="text-[9px] text-blue-400 font-bold uppercase tracking-tighter">Irys L1 Transaction (Permanent)</span>
                <a 
                  href={`https://gateway.irys.xyz/${txDetails.id}`} 
                  target="_blank" 
                  rel="noreferrer"
                  className="text-[10px] font-mono text-gray-400 break-all hover:text-blue-300 transition-colors"
                >
                  {txDetails.id} ↗
                </a>
              </div>
              <div className="flex flex-col">
                <span className="text-[9px] text-green-500 font-bold uppercase tracking-tighter">Arbitrum Stylus ID (Integrity)</span>
                <span className="text-[10px] font-mono text-gray-400 break-all">{txDetails.hash}</span>
              </div>
            </div>
          </div>
        )}

        {isProcessing && (
          <div className="flex items-center gap-3 text-blue-400 bg-blue-500/10 px-4 py-2 rounded-full border border-blue-500/20">
            <div className="w-2 h-2 bg-blue-400 rounded-full animate-ping" />
            <span className="text-[10px] font-bold font-mono tracking-widest uppercase">Mining on Arbitrum...</span>
          </div>
        )}
      </div>
    </div>
  );
}

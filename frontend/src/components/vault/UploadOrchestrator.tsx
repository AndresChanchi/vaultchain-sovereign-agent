"use client";

import React, { useState, useEffect, useCallback } from 'react';
import { sha256 } from 'viem';
import { Buffer } from 'buffer';
import { useKipioCrypto } from '@hooks/useKipioCrypto';
import { useIrys } from '@hooks/useIrys';
import { useVault } from '@hooks/useVault';
import { useImageWorker } from '@hooks/useImageWorker';

/**
 * @title Secure Upload Orchestrator V3 (Refactored)
 * @notice High-integrity pipeline for asset encryption and decentralized storage.
 * @dev This component orchestrates the 6-step pipeline from local optimization to on-chain settlement.
 * It consumes the KipioContext to ensure that the Master Key never leaves the Secure Context.
 */
export function UploadOrchestrator() {
  // HOOKS: Consuming our shared cryptographic and blockchain infrastructure
  const { 
    encryptFile, 
    isLocked, 
    unlockVault, 
    workerReady: cryptoReady 
  } = useKipioCrypto();

  const { instance: sessionInstance, initIrys } = useIrys();
  const { registerUpload, getPhotoId, isProcessing, invalidateVaultCache } = useVault();
  const { compress, isReady: imageReady } = useImageWorker();
  
  // UI & PIPELINE STATE
  const [status, setStatus] = useState<'IDLE' | 'AWAITING_SIGNATURE' | 'PROCESSING' | 'SUCCESS' | 'ERROR'>('IDLE');
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [pendingFile, setPendingFile] = useState<File | null>(null);
  
  const [steps, setSteps] = useState({
    optim: false,
    integrity: false,
    registry: false,
    crypto: false,
    storage: false,
    settlement: false
  });

  /**
   * @dev PIPELINE WATCHDOG
   * Automatically resumes the execution pipeline once the user provides 
   * the EIP-712 signature and the Vault becomes 'unlocked'.
   */
  useEffect(() => {
    if (!isLocked && pendingFile && status === 'AWAITING_SIGNATURE') {
      executeSecurePipeline(pendingFile);
      setPendingFile(null);
    }
  }, [isLocked, pendingFile, status]);

  /**
   * @notice Handles initial file selection and vault authorization checks.
   */
  const handleFileSelection = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file || !cryptoReady || !imageReady) return;

    // Cleanup: Prevent memory leaks from previous previews
    if (previewUrl) URL.revokeObjectURL(previewUrl);

    setPreviewUrl(URL.createObjectURL(file));
    setErrorMsg(null);
    resetSteps();

    // If Vault is locked, we enter the 'Awaiting Signature' gate
    if (isLocked) {
      try {
        setStatus('AWAITING_SIGNATURE');
        setPendingFile(file);
        await unlockVault();
      } catch (err: any) {
        console.error("[ORCHESTRATOR] Unlock rejected:", err);
        setErrorMsg(err.message.includes('rejected') ? "Signature rejected by user." : "Failed to unlock vault.");
        setStatus('ERROR');
      }
      return;
    }

    executeSecurePipeline(file);
  };

  const resetSteps = () => {
    setSteps({ optim: false, integrity: false, registry: false, crypto: false, storage: false, settlement: false });
  };

  /**
   * @notice Core Execution Logic: 6 Atomic Steps to Security.
   * @param file The raw file blob from the input.
   */
  const executeSecurePipeline = async (file: File) => {
    try {
      setStatus('PROCESSING');

      // STEP 1: WASM-BASED COMPRESSION (Optimizes storage costs)
      const compressed = await compress(file);
      setSteps(s => ({ ...s, optim: true }));

      // STEP 2: CONTENT INTEGRITY (SHA-256 Fingerprint)
      const contentHash = sha256(new Uint8Array(compressed));
      setSteps(s => ({ ...s, integrity: true }));

      // STEP 3: ON-CHAIN DEDUPLICATION (Gatekeeper Check)
      // Prevents paying for storage of assets already present in Stylus.
      const existingId = await getPhotoId(contentHash);
      if (existingId && existingId !== "" && existingId !== "0x0000000000000000000000000000000000000000000000000000000000000000") {
        throw new Error("ASSET_ALREADY_IN_VAULT");
      }
      setSteps(s => ({ ...s, registry: true }));

      // STEP 4: AES-GCM-256 ENCRYPTION
      // Key material is retrieved from Context and transferred to Worker.
      const encrypted = await encryptFile(compressed, contentHash);
      setSteps(s => ({ ...s, crypto: true }));

      // STEP 5: IRYS STORAGE PROPAGATION
      let activeIrys = sessionInstance || await initIrys();
      if (!activeIrys) throw new Error("IRYS_CONNECTION_FAILED");

      const tags = [
        { name: "Content-Type", value: "image/webp" },
        { name: "App-Name", value: "Kipio-Vault-v1" },
        { name: "Encryption", value: "AES-GCM-256" }
      ];

      const receipt = await activeIrys.upload(Buffer.from(encrypted) as any, { tags });
      setSteps(s => ({ ...s, storage: true }));

      // STEP 6: ARBITRUM STYLUS SETTLEMENT
      // Maps the ContentHash to the Irys TXID on the blockchain.
      await registerUpload(contentHash, receipt.id);
      setSteps(s => ({ ...s, settlement: true }));

      setStatus('SUCCESS');
      invalidateVaultCache();
      
      // Reset UI after 10 seconds of success
      setTimeout(handleReset, 10000);

    } catch (err: any) {
      console.error("[CRITICAL] Pipeline Failure:", err);
      
      if (err.message === "ASSET_ALREADY_IN_VAULT") {
        setErrorMsg("This file is already secured in your vault.");
      } else if (err.message.includes('rejected') || err.message.includes('denied')) {
        setErrorMsg("Signature rejected by user.");
      } else {
        setErrorMsg("Process failed. Please verify your connection.");
      }
      
      setStatus('ERROR');
    }
  };

  const handleReset = () => {
    setStatus('IDLE');
    if (previewUrl) URL.revokeObjectURL(previewUrl);
    setPreviewUrl(null);
    setErrorMsg(null);
    setPendingFile(null);
    resetSteps();
  };

  return (
    <div className="w-full max-w-md bg-[#0a0c10] border border-white/10 rounded-3xl overflow-hidden shadow-2xl transition-all duration-500">
      {/* Header with Dynamic Status Glow */}
      <div className={`p-6 border-b border-white/5 bg-gradient-to-b from-white/5 to-transparent`}>
        <div className="flex justify-between items-center">
          <div>
            <h3 className="text-white font-bold tracking-tight text-lg">Vault Orchestrator</h3>
            <p className="text-[10px] font-mono text-gray-500 uppercase tracking-widest">Client-Side Shield v3</p>
          </div>
          <div className={`h-2 w-2 rounded-full ${
            status === 'SUCCESS' ? 'bg-green-500 shadow-[0_0_10px_rgba(34,197,94,0.8)]' : 
            status === 'ERROR' ? 'bg-red-500 shadow-[0_0_10px_rgba(239,68,68,0.8)]' : 
            'bg-blue-500 animate-pulse'
          }`} />
        </div>
      </div>

      <div className="p-6 space-y-6">
        {/* Real-time Pipeline Progress */}
        <div className="space-y-2">
          <StatusLine label="WASM Optimization" active={steps.optim} />
          <StatusLine label="On-Chain Registry Check" active={steps.registry} />
          <StatusLine label="AES-GCM Shielding" active={steps.crypto} />
          <StatusLine label="Irys Layer Propagation" active={steps.storage} />
          <StatusLine label="Stylus Finalization" active={steps.settlement} />
        </div>

        {/* Dynamic Action Area */}
        {!previewUrl ? (
          <label className="group relative flex flex-col items-center justify-center w-full h-44 border-2 border-dashed border-white/10 rounded-2xl cursor-pointer hover:border-blue-500/50 hover:bg-blue-500/5 transition-all">
            <div className="flex flex-col items-center justify-center space-y-3">
              <div className="p-4 bg-white/5 rounded-full group-hover:scale-110 transition-transform bg-blue-500/10">
                <svg className="w-6 h-6 text-blue-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
                </svg>
              </div>
              <div className="text-center px-4">
                <p className="text-sm font-bold text-gray-300">Secure New Asset</p>
                <p className="text-[10px] text-gray-500 font-mono mt-1 uppercase">Max 100MB // Encrypted in RAM</p>
              </div>
            </div>
            <input type="file" className="hidden" accept="image/*" onChange={handleFileSelection} disabled={status === 'PROCESSING'} />
          </label>
        ) : (
          <div className="relative rounded-2xl overflow-hidden border border-white/10 aspect-video bg-black group">
            <img 
              src={previewUrl} 
              className={`w-full h-full object-cover transition-all duration-700 ${status === 'PROCESSING' ? 'blur-md grayscale' : ''}`} 
              alt="Vault Preview" 
            />
            
            {status === 'PROCESSING' && (
              <div className="absolute inset-0 flex flex-col items-center justify-center bg-black/40 backdrop-blur-sm">
                <div className="w-10 h-10 border-2 border-blue-500 border-t-transparent rounded-full animate-spin mb-3" />
                <span className="text-[10px] font-mono font-black text-white uppercase tracking-widest text-center">
                  Executing Secure<br/>Pipeline...
                </span>
              </div>
            )}

            {(status === 'ERROR' || status === 'SUCCESS') && (
              <button 
                onClick={handleReset}
                className="absolute top-2 right-2 p-2 bg-black/60 hover:bg-black rounded-full text-white/70 hover:text-white transition-colors"
              >
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            )}
          </div>
        )}

        {/* UX Feedback Layer */}
        <div className="min-h-[40px] flex items-center justify-center">
          {status === 'ERROR' ? (
            <div className="flex flex-col items-center gap-2 text-center">
              <span className="text-[11px] font-bold text-red-400 uppercase tracking-tighter">⚠️ {errorMsg}</span>
              <button onClick={handleReset} className="text-[9px] text-gray-500 underline hover:text-white uppercase font-mono tracking-widest">Retry Operation</button>
            </div>
          ) : status === 'AWAITING_SIGNATURE' ? (
            <div className="flex items-center gap-2 text-yellow-500">
              <div className="w-1.5 h-1.5 bg-yellow-500 rounded-full animate-ping" />
              <span className="text-[11px] font-bold uppercase tracking-widest">Awaiting Wallet Signature...</span>
            </div>
          ) : isProcessing ? (
            <div className="flex items-center gap-2 text-blue-400">
              <div className="w-1.5 h-1.5 bg-blue-400 rounded-full animate-pulse" />
              <span className="text-[11px] font-bold uppercase tracking-widest italic">Mining on Arbitrum Stylus...</span>
            </div>
          ) : status === 'SUCCESS' ? (
            <span className="text-[11px] font-bold text-green-400 uppercase tracking-widest">✓ Final Settlement Verified</span>
          ) : (
            <span className="text-[10px] font-mono text-gray-700 uppercase tracking-widest">Standby // Integrity Assured</span>
          )}
        </div>
      </div>
    </div>
  );
}

/**
 * @dev Helper component for the pipeline progress UI.
 */
function StatusLine({ label, active }: { label: string, active: boolean }) {
  return (
    <div className="flex items-center gap-3">
      <div className={`h-[1px] flex-1 transition-all duration-1000 ${active ? 'bg-gradient-to-r from-green-500/40 to-transparent' : 'bg-white/5'}`} />
      <span className={`text-[9px] font-mono uppercase tracking-widest transition-colors duration-500 ${active ? 'text-green-400 font-bold' : 'text-gray-700'}`}>
        {label}
      </span>
      <div className={`w-1.5 h-1.5 rounded-full transition-all duration-700 ${active ? 'bg-green-500 shadow-[0_0_8px_rgba(34,197,94,0.6)]' : 'bg-gray-900 border border-white/10'}`} />
    </div>
  );
}

"use client";

import React, { useState, useEffect, useCallback, useRef } from 'react';
import { sha256 } from 'viem';
import { Buffer } from 'buffer';
import { useKipioCrypto } from '@hooks/useKipioCrypto';
import { useIrys } from '@hooks/useIrys';
import { useVault } from '@hooks/useVault';
import { useImageWorker } from '@hooks/useImageWorker';

/**
 * @title Secure Vault Orchestrator V3.3
 * @author Kipio Engineering
 * @notice Refined pipeline with reactive watchdog for mobile signature persistence.
 * @dev Combines linear execution for Desktop and state-driven resumption for Mobile.
 */
export function UploadOrchestrator() {
  const { 
    encryptFile, 
    isLocked, 
    unlockVault, 
    workerReady: cryptoReady 
  } = useKipioCrypto();

  const { initIrys } = useIrys();
  const { registerUpload, getPhotoId, isProcessing, invalidateVaultCache } = useVault();
  const { compress, isReady: imageReady } = useImageWorker();
  
  const [status, setStatus] = useState<'IDLE' | 'AWAITING_SIGNATURE' | 'PROCESSING' | 'SUCCESS' | 'ERROR'>('IDLE');
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  
  // Ref to prevent double-execution during React strict mode or state swings
  const processingRef = useRef(false);

  const [steps, setSteps] = useState({
    optim: false,
    integrity: false,
    registry: false,
    crypto: false,
    storage: false,
    settlement: false
  });

  const resetSteps = useCallback(() => {
    setSteps({ 
        optim: false, 
        integrity: false, 
        registry: false, 
        crypto: false, 
        storage: false, 
        settlement: false 
    });
  }, []);

  /**
   * @notice Core Secure Pipeline logic.
   * @dev Logic separated to be callable by both manual clicks and the reactive watchdog.
   */
  const executePipeline = useCallback(async (file: File) => {
    if (processingRef.current) return;
    processingRef.current = true;

    try {
      setStatus('PROCESSING');

      // 1. INTEGRITY FINGERPRINTING
      const originalBuffer = await file.arrayBuffer();
      const contentHash = sha256(new Uint8Array(originalBuffer));
      setSteps(s => ({ ...s, integrity: true }));

      // 2. COLLISION CHECK
      const existingId = await getPhotoId(contentHash);
      if (existingId && existingId !== "" && !existingId.startsWith("0x00000000")) {
        throw new Error("ASSET_ALREADY_IN_VAULT");
      }
      setSteps(s => ({ ...s, registry: true }));

      // 3. WASM COMPRESSION
      const compressed = await compress(file);
      setSteps(s => ({ ...s, optim: true }));

      // 4. AES-GCM-256 ENCRYPTION
      // This requires the vault to be unlocked (key available in worker)
      const encrypted = await encryptFile(compressed, contentHash);
      setSteps(s => ({ ...s, crypto: true }));

      // 5. DECENTRALIZED PROPAGATION
      const isMobile = typeof navigator !== 'undefined' && /iPhone|iPad|iPod|Android/i.test(navigator.userAgent);
      let uploadReceipt = null;
      let attempts = 0;
      const MAX_RETRIES = isMobile ? 3 : 1; 

      const uploadData = Buffer.from(encrypted);
      const tags = [
        { name: "Content-Type", value: "image/webp" },
        { name: "App-Name", value: "Kipio-Vault-v1" },
        { name: "Encryption", value: "AES-GCM-256" }
      ];

      while (attempts < MAX_RETRIES) {
        try {
          // Mobile context-switching delay: allows the bridge to re-establish
          if (isMobile && attempts > 0) {
            await new Promise(r => setTimeout(r, 1500 + (attempts * 1000)));
          }

          const activeIrys = await initIrys();
          if (!activeIrys?.uploader) throw new Error("IRYS_CONNECTION_FAILED");

          uploadReceipt = await activeIrys.upload(uploadData as any, { tags });
          if (uploadReceipt?.id) break;
          throw new Error("IRYS_UPLOAD_FAILED");
          
        } catch (storageErr: any) {
          attempts++;
          if (attempts >= MAX_RETRIES || storageErr.message?.includes('rejected')) {
            throw storageErr;
          }
        }
      }
      
      if (!uploadReceipt?.id) throw new Error("IRYS_UPLOAD_FAILED");
      setSteps(s => ({ ...s, storage: true }));

      // 6. FINAL SETTLEMENT
      await registerUpload(contentHash, uploadReceipt.id);
      setSteps(s => ({ ...s, settlement: true }));

      setStatus('SUCCESS');
      invalidateVaultCache();
      setTimeout(handleReset, 8000);

    } catch (err: any) {
      const msg = err.message || "";
      if (msg.includes("rejected") || msg.includes("denied")) {
        setErrorMsg("Action cancelled by user.");
      } else if (msg === "ASSET_ALREADY_IN_VAULT") {
        setErrorMsg("This file is already secured in your vault.");
      } else {
        setErrorMsg("Pipeline execution failed.");
      }
      setStatus('ERROR');
    } finally {
      processingRef.current = false;
    }
  }, [getPhotoId, compress, encryptFile, initIrys, registerUpload, invalidateVaultCache]);

  /**
   * @dev REACTIVE WATCHDOG
   * Solves the "Two-Click" issue on mobile. If the user completes the signature
   * and the vault unlocks, this hook detects the change and resumes the pipeline.
   */
  useEffect(() => {
    if (!isLocked && selectedFile && status === 'AWAITING_SIGNATURE' && !processingRef.current) {
        // Small grace period for mobile OS to return focus to the browser context
        const timer = setTimeout(() => {
            executePipeline(selectedFile);
        }, 500);
        return () => clearTimeout(timer);
    }
  }, [isLocked, selectedFile, status, executePipeline]);

  const handleFileSelection = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file || !cryptoReady || !imageReady) return;

    if (previewUrl) URL.revokeObjectURL(previewUrl);

    setPreviewUrl(URL.createObjectURL(file));
    setSelectedFile(file);
    setErrorMsg(null);
    setStatus('IDLE');
    resetSteps();

    // Warm up Irys in background
    initIrys().catch(() => {});
  };

  const startSecurePipeline = async () => {
    if (!selectedFile) return;

    if (isLocked) {
      setStatus('AWAITING_SIGNATURE');
      try {
        await unlockVault();
        // On Desktop, this might continue immediately. 
        // On Mobile, the Watchdog (useEffect) will catch the state change.
      } catch (lockErr) {
        setStatus('IDLE');
      }
    } else {
      executePipeline(selectedFile);
    }
  };

  const handleReset = useCallback(() => {
    setStatus('IDLE');
    if (previewUrl) URL.revokeObjectURL(previewUrl);
    setPreviewUrl(null);
    setSelectedFile(null);
    setErrorMsg(null);
    processingRef.current = false;
    resetSteps();
  }, [previewUrl, resetSteps]);

  // UI remains identical to v3.6...
  return (
    <div className="w-full max-w-md bg-[#0a0c10] border border-white/10 rounded-3xl overflow-hidden shadow-2xl">
      <div className="p-6 border-b border-white/5 bg-gradient-to-b from-white/5 to-transparent">
        <div className="flex justify-between items-center">
          <div>
            <h3 className="text-white font-bold tracking-tight text-lg">Vault Orchestrator</h3>
            <p className="text-[10px] font-mono text-gray-500 uppercase tracking-widest text-blue-400/80">Shield v3.3 Mobile-Optimized</p>
          </div>
          <div className={`h-2 w-2 rounded-full transition-all duration-500 ${
            status === 'SUCCESS' ? 'bg-green-500 shadow-[0_0_10px_rgba(34,197,94,0.8)]' : 
            status === 'ERROR' ? 'bg-red-500 shadow-[0_0_10px_rgba(239,68,68,0.8)]' : 
            status === 'IDLE' ? 'bg-gray-800' : 'bg-blue-500 animate-pulse'
          }`} />
        </div>
      </div>

      <div className="p-6 space-y-6">
        <div className="space-y-2 opacity-90">
          <StatusLine label="Integrity & Registry" active={steps.integrity && steps.registry} />
          <StatusLine label="WASM Optimization" active={steps.optim} />
          <StatusLine label="AES-GCM Shielding" active={steps.crypto} />
          <StatusLine label="Decentralized Storage" active={steps.storage} />
          <StatusLine label="Stylus Finalization" active={steps.settlement} />
        </div>

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
                <p className="text-[10px] text-gray-500 font-mono mt-1 uppercase text-center">Encrypted in local RAM</p>
              </div>
            </div>
            <input type="file" className="hidden" accept="image/*" onChange={handleFileSelection} disabled={status === 'PROCESSING'} />
          </label>
        ) : (
          <div className="space-y-4 animate-in fade-in slide-in-from-bottom-2">
            <div className="relative rounded-2xl overflow-hidden border border-white/10 aspect-video bg-black group">
              <img 
                src={previewUrl} 
                className={`w-full h-full object-cover transition-all duration-700 ${status === 'PROCESSING' ? 'blur-md grayscale' : ''}`} 
                alt="Vault Preview" 
              />
              {status === 'PROCESSING' && (
                <div className="absolute inset-0 flex flex-col items-center justify-center bg-black/40 backdrop-blur-sm">
                  <div className="w-8 h-8 border-2 border-blue-500 border-t-transparent rounded-full animate-spin mb-3" />
                  <span className="text-[10px] font-mono font-black text-white uppercase tracking-widest">Shielding Asset...</span>
                </div>
              )}
              {(status === 'ERROR' || status === 'SUCCESS' || status === 'IDLE') && (
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
            
            {status === 'IDLE' && (
                <button 
                    onClick={startSecurePipeline}
                    className="w-full py-4 bg-blue-600 hover:bg-blue-500 text-white text-xs font-black uppercase tracking-[0.2em] rounded-xl transition-all shadow-lg active:scale-[0.98]"
                >
                    Finalize & Secure Asset
                </button>
            )}
          </div>
        )}

        <div className="min-h-[40px] flex items-center justify-center">
          {status === 'ERROR' ? (
            <div className="flex flex-col items-center gap-1 text-center">
              <span className="text-[11px] font-bold text-red-400 uppercase tracking-tighter">⚠️ {errorMsg}</span>
              <button onClick={handleReset} className="text-[9px] text-gray-500 underline hover:text-white uppercase font-mono tracking-widest">Discard and Retry</button>
            </div>
          ) : status === 'AWAITING_SIGNATURE' ? (
            <div className="flex items-center gap-2 text-yellow-500">
              <div className="w-1.5 h-1.5 bg-yellow-500 rounded-full animate-ping" />
              <span className="text-[11px] font-bold uppercase tracking-widest">Awaiting Wallet Signature...</span>
            </div>
          ) : isProcessing ? (
            <div className="flex items-center gap-2 text-blue-400">
              <div className="w-1.5 h-1.5 bg-blue-400 rounded-full animate-pulse" />
              <span className="text-[11px] font-bold uppercase tracking-widest italic tracking-wider">Settling on Arbitrum...</span>
            </div>
          ) : status === 'SUCCESS' ? (
            <span className="text-[11px] font-bold text-green-400 uppercase tracking-widest">✓ Final Settlement Verified</span>
          ) : (
            <span className="text-[10px] font-mono text-gray-700 uppercase tracking-[0.3em]">Integrity Assured</span>
          )}
        </div>
      </div>
    </div>
  );
}

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

"use client";

import React, { useState, useEffect, useCallback, useRef } from 'react';
import { sha256 } from 'viem';
import { Buffer } from 'buffer';
import { useKipioCrypto } from '@hooks/useKipioCrypto';
import { useIrys } from '@hooks/useIrys';
import { useVault } from '@hooks/useVault';
import { useImageWorker } from '@hooks/useImageWorker';
import { formatEther } from 'viem';

/**
 * @title Secure Vault Orchestrator V3.6 - MVP
 * @notice Refactored to delegate pricing and settlement retries to specialized hooks.
 * @dev Implements cost pre-calculation and clean UI for final production deployment.
 */
export function UploadOrchestrator() {
  const { encryptFile, isLocked, unlockVault, workerReady: cryptoReady } = useKipioCrypto();
  const { initIrys, getUploadPrice, fundNode, balanceAtomic } = useIrys();
  const { registerUpload, getPhotoId, invalidateVaultCache, estimateRegistrationCost } = useVault();
  const { compress, isReady: imageReady } = useImageWorker();
  
  const [status, setStatus] = useState<'IDLE' | 'AWAITING_SIGNATURE' | 'PROCESSING' | 'SUCCESS' | 'ERROR'>('IDLE');
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  
  const [costs, setCosts] = useState({ irys: "0", gas: 0n });
  const processingRef = useRef(false);

  const [steps, setSteps] = useState({ optim: false, integrity: false, registry: false, crypto: false, storage: false, settlement: false });

  const yieldThread = (ms: number = 150) => new Promise(r => setTimeout(r, ms));

  const resetSteps = useCallback(() => {
    setSteps({ optim: false, integrity: false, registry: false, crypto: false, storage: false, settlement: false });
  }, []);

  const handleReset = useCallback(() => {
    setStatus('IDLE');
    if (previewUrl) URL.revokeObjectURL(previewUrl);
    setPreviewUrl(null);
    setSelectedFile(null);
    setErrorMsg(null);
    setCosts({ irys: "0", gas: 0n });
    processingRef.current = false;
    resetSteps();
  }, [previewUrl, resetSteps]);

  const runEstimation = useCallback(async (file: File) => {
    try {
      const price = await getUploadPrice(file.size);
      setCosts(prev => ({ ...prev, irys: price }));
      
      const dummyHash = sha256(new Uint8Array(8));
      const dummyId = "A".repeat(43); 
      const gasEst = await estimateRegistrationCost(dummyHash, dummyId);
      setCosts(prev => ({ ...prev, gas: gasEst }));
    } catch (err) {
      // Estimation failure remains silent to avoid UI disruption
    }
  }, [getUploadPrice, estimateRegistrationCost]);

  const executePipeline = useCallback(async (file: File) => {
    if (processingRef.current) return;
    processingRef.current = true;

    try {
      setStatus('PROCESSING');
      
      // Stabilization phase for mobile bridge persistence
      await yieldThread(1800);

      // --- 1. DATA PREP & INTEGRITY ---
      const originalBuffer = await file.arrayBuffer();
      const contentHash = sha256(new Uint8Array(originalBuffer));
      setSteps(s => ({ ...s, integrity: true }));

      // --- 2. REGISTRY CHECK ---
      const existingId = await getPhotoId(contentHash);
      if (existingId && existingId !== "" && !existingId.startsWith("0x00000000")) {
        throw new Error("ASSET_ALREADY_IN_VAULT");
      }
      setSteps(s => ({ ...s, registry: true }));
      await yieldThread(400);

      // --- 3. WASM OPTIMIZATION ---
      if (!imageReady) throw new Error("WASM_ENGINE_NOT_LOADED");
      
      const compressionTask = compress(originalBuffer, file.type); 
      const timeoutTask = new Promise((_, reject) => setTimeout(() => reject(new Error("WASM_TIMEOUT")), 40000));
      const compressed = await Promise.race([compressionTask, timeoutTask]) as ArrayBuffer;
      
      if (!compressed || compressed.byteLength === 0) throw new Error("WASM_NULL_BUFFER");
      setSteps(s => ({ ...s, optim: true }));

      // --- 4. CRYPTO ---
      if (!cryptoReady) throw new Error("CRYPTO_ENGINE_OFFLINE");
      const encrypted = await encryptFile(compressed, contentHash);
      setSteps(s => ({ ...s, crypto: true }));

      // --- 5. STORAGE & AUTO-FUNDING ---
      const isMobile = typeof navigator !== 'undefined' && /iPhone|iPad|iPod|Android/i.test(navigator.userAgent);
      const uploadData = Buffer.from(encrypted);
      const tags = [{ name: "Content-Type", value: "image/webp" }, { name: "Encryption", value: "AES-GCM-256" }];

      const priceAtomic = await getUploadPrice(uploadData.byteLength);
      
      if (BigInt(balanceAtomic) < BigInt(priceAtomic)) {
        await fundNode(priceAtomic);
      }

      // --- 6. STORAGE PROPAGATION (MOBILE RETRIES) ---
      let receipt = null;
      let attempts = 0;
      const MAX_RETRIES = isMobile ? 4 : 1; 

      while (attempts < MAX_RETRIES) {
        try {
          if (isMobile && attempts > 0) await yieldThread(2500 * attempts);
          
          const currentIrys = await initIrys();
          if (!currentIrys?.uploader) throw new Error("IRYS_AUTH_FAILED");

          receipt = await currentIrys.upload(uploadData as any, { tags });
          if (receipt?.id) break;
          throw new Error("UPLOAD_MISSING_ID");
        } catch (e: any) {
          const isRejected = e?.message?.includes("rejected") || e?.code === 4001 || e?.code === "ACTION_REJECTED";
          if (isRejected) throw new Error("ACTION_REJECTED");
          attempts++;
          if (attempts >= MAX_RETRIES) throw e;
        }
      }
      
      if (!receipt?.id) throw new Error("STORAGE_TIMEOUT");
      setSteps(s => ({ ...s, storage: true }));

      // --- 7. SETTLEMENT ---
      await registerUpload(contentHash, receipt.id);
      setSteps(s => ({ ...s, settlement: true }));

      setStatus('SUCCESS');
      invalidateVaultCache();
      setTimeout(handleReset, 10000);

    } catch (err: any) {
      let cleanMessage = err.message;
      if (err.message === "ACTION_REJECTED" || err.code === "ACTION_REJECTED" || err.message?.includes("rejected")) {
        cleanMessage = "User rejected the request.";
      }
      setErrorMsg(err.message === "ASSET_ALREADY_IN_VAULT" ? "Asset already secured." : `Error: ${cleanMessage}`);
      setStatus('ERROR');
    } finally {
      processingRef.current = false;
    }
  }, [getPhotoId, compress, encryptFile, initIrys, registerUpload, invalidateVaultCache, imageReady, cryptoReady, getUploadPrice, fundNode, balanceAtomic, handleReset]);

  useEffect(() => {
    if (!isLocked && selectedFile && status === 'AWAITING_SIGNATURE' && !processingRef.current) {
        const timer = setTimeout(() => { executePipeline(selectedFile); }, 1800); 
        return () => clearTimeout(timer);
    }
  }, [isLocked, selectedFile, status, executePipeline]);

  const handleFileSelection = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    if (previewUrl) URL.revokeObjectURL(previewUrl);
    setPreviewUrl(URL.createObjectURL(file));
    setSelectedFile(file);
    setStatus('IDLE');
    setErrorMsg(null);
    resetSteps();
    runEstimation(file);
    initIrys().catch(() => {});
  };

  const handleStartInteraction = async () => {
    if (!selectedFile) return;
    if (isLocked) {
      setStatus('AWAITING_SIGNATURE');
      try { 
        await unlockVault(); 
      } catch (e: any) { 
        setStatus('IDLE'); 
      }
    } else {
      executePipeline(selectedFile);
    }
  };

  return (
    <div className="flex flex-col gap-4">
      <div className="w-full max-w-md bg-[#0a0c10] border border-white/10 rounded-3xl overflow-hidden shadow-2xl">
        <div className="p-6 border-b border-white/5 bg-gradient-to-b from-white/5 to-transparent flex justify-between items-center">
          <div>
            <h3 className="text-white font-bold text-lg">Vault Orchestrator</h3>
            <p className="text-[10px] font-mono text-blue-400/80 uppercase tracking-widest">Shield v3.6 MVP..</p>
          </div>
          <div className={`h-2.5 w-2.5 rounded-full shadow-lg transition-colors duration-500 ${
            status === 'SUCCESS' ? 'bg-green-500 shadow-green-500/50' : 
            status === 'ERROR' ? 'bg-red-500 shadow-red-500/50' : 
            status === 'PROCESSING' || status === 'AWAITING_SIGNATURE' ? 'bg-blue-500 animate-pulse' : 'bg-gray-800'
          }`} />
        </div>

        <div className="p-6 space-y-6">
          <div className="space-y-2 opacity-80">
            <StatusLine label="Integrity" active={steps.integrity} />
            <StatusLine label="WASM Optimization" active={steps.optim} />
            <StatusLine label="AES-GCM Crypto" active={steps.crypto} />
            <StatusLine label="Irys Storage" active={steps.storage} />
            <StatusLine label="Vault Settlement" active={steps.settlement} />
          </div>

          <div className="relative">
            {!previewUrl ? (
              <label className="flex flex-col items-center justify-center w-full h-40 border-2 border-dashed border-white/10 rounded-2xl cursor-pointer hover:bg-white/5 transition-all">
                <div className="text-center">
                  <p className="text-sm font-bold text-gray-400">Secure New Asset</p>
                  <p className="text-[9px] text-gray-600 mt-1 font-mono uppercase tracking-widest">Cypherpunk Protocol</p>
                </div>
                <input type="file" className="hidden" accept="image/*" onChange={handleFileSelection} />
              </label>
            ) : (
              <div className="space-y-4">
                <div className="relative rounded-2xl overflow-hidden border border-white/10 aspect-video bg-black">
                  <img src={previewUrl} className={`w-full h-full object-cover transition-opacity duration-500 ${status === 'PROCESSING' ? 'opacity-40 blur-sm' : 'opacity-100'}`} alt="Preview" />
                  {(status === 'IDLE' || status === 'ERROR' || status === 'SUCCESS') && (
                    <button onClick={handleReset} className="absolute top-2 right-2 p-1.5 bg-black/60 rounded-full text-white hover:bg-black">
                      <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" /></svg>
                    </button>
                  )}
                </div>

                {status === 'IDLE' && (
                  <div className="space-y-3">
                    <div className="grid grid-cols-2 gap-2">
                      <div className="bg-white/5 p-3 rounded-xl border border-white/5">
                        <p className="text-[8px] uppercase text-gray-500 font-bold mb-1">Storage Cost</p>
                        <p className="text-[10px] text-blue-400 font-mono">
                          {costs.irys !== "0" ? `${(Number(costs.irys) / 1e18).toFixed(6)} ETH` : "Calculating..."}
                        </p>
                      </div>
                      <div className="bg-white/5 p-3 rounded-xl border border-white/5">
                        <p className="text-[8px] uppercase text-gray-500 font-bold mb-1">Vault Fee (Est)</p>
                        <p className="text-[10px] text-purple-400 font-mono">
                          {costs.gas > 0n ? `${formatEther(costs.gas).substring(0, 8)} ETH` : "Calculating..."}
                        </p>
                      </div>
                    </div>
                    <button onClick={handleStartInteraction} className="w-full py-4 bg-blue-600 hover:bg-blue-500 text-white text-[10px] font-black uppercase tracking-[0.2em] rounded-xl transition-all shadow-[0_0_20px_rgba(37,99,235,0.3)]">
                      Finalize & Secure Asset
                    </button>
                  </div>
                )}
              </div>
            )}
          </div>

          <div className="h-6 flex items-center justify-center text-[10px] font-bold uppercase tracking-tight">
            {status === 'ERROR' && <span className="text-red-400">⚠️ {errorMsg}</span>}
            {status === 'AWAITING_SIGNATURE' && <span className="text-yellow-500 animate-pulse">Signature Required...</span>}
            {status === 'SUCCESS' && <span className="text-green-400">Asset Securely Archived</span>}
          </div>
        </div>
      </div>
    </div>
  );
}

function StatusLine({ label, active }: { label: string, active: boolean }) {
  return (
    <div className="flex items-center gap-3">
      <div className={`h-[1px] flex-1 transition-all duration-1000 ${active ? 'bg-gradient-to-r from-green-500/40 to-transparent' : 'bg-white/5'}`} />
      <span className={`text-[9px] font-mono uppercase tracking-widest ${active ? 'text-green-400 font-bold' : 'text-gray-700'}`}>
        {label}
      </span>
      <div className={`w-1.5 h-1.5 rounded-full transition-all duration-700 ${active ? 'bg-green-500 shadow-[0_0_8px_rgba(34,197,94,0.6)]' : 'bg-gray-900 border border-white/10'}`} />
    </div>
  );
}

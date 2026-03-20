"use client";

import { useAccount, useSwitchChain } from "wagmi";
import { useRouter } from "next/navigation";
import { useEffect, useRef } from "react";
import { DisconnectButton } from "@components/ui/disconnect-button";
import { CHAIN_CONFIG } from "@config/contracts";
import { UploadOrchestrator } from "@components/vault/UploadOrchestrator";
import { VaultGallery } from "@components/vault/VaultGallery";

/**
 * DashboardPage: The main authenticated hub.
 * Orchestrates the Upload pipeline and the Gallery view.
 */
export default function DashboardPage() {
  const { address, isConnected, chainId } = useAccount();
  const { switchChain } = useSwitchChain();
  const router = useRouter();
  
  // Security Ref: Forces a clean state if the wallet account changes
  const sessionAddress = useRef<string | undefined>(undefined);

  useEffect(() => {
    if (!isConnected) {
      router.replace("/");
      return;
    }
    
    // Account change detection (Sovereignty Protection)
    if (!sessionAddress.current && address) {
      sessionAddress.current = address;
    }
    if (sessionAddress.current && address && address !== sessionAddress.current) {
      window.location.reload(); 
      return;
    }
  }, [isConnected, address, router]);

  if (!isConnected) return null;

  const isWrongNetwork = chainId !== CHAIN_CONFIG.id;

  return (
    <main className="container-responsive py-6 md:py-8 space-y-6 md:space-y-12 overflow-x-hidden">
      {/* 1. RESPONSIVE HEADER */}
      <header className="flex flex-row justify-between items-center bg-surface p-4 rounded-2xl border border-highlight shadow-sm gap-4">
        <div className="flex flex-col min-w-0">
          <h1 className="text-lg md:text-xl font-bold text-primary italic tracking-tighter">KIPIO_VAULT</h1>
          <div className="flex items-center gap-2">
            <span className="w-2 h-2 bg-green-500 rounded-full animate-pulse" />
            <span className="text-[10px] md:text-xs font-mono opacity-50 truncate max-w-[150px] md:max-w-none">
              {address}
            </span>
          </div>
        </div>
        <div className="flex-shrink-0">
          <DisconnectButton />
        </div>
      </header>

      {/* 2. NETWORK ENFORCEMENT */}
      {isWrongNetwork && (
        <div className="bg-red-500/10 border border-red-500/50 p-4 rounded-xl flex flex-col md:flex-row justify-between items-center gap-4 animate-in fade-in slide-in-from-top-4">
          <p className="text-xs md:text-sm text-red-200 font-medium text-center md:text-left">
            ⚠️ NETWORK_MISMATCH: Stylus registry only available on Arbitrum Sepolia.
          </p>
          <button 
            onClick={() => switchChain({ chainId: CHAIN_CONFIG.id })}
            className="bg-red-500 text-white text-xs px-6 py-2 rounded-lg font-bold w-full md:w-auto hover:bg-red-600 transition-all active:scale-95"
          >
            SWITCH NETWORK
          </button>
        </div>
      )}

      {/* 3. MAIN CONTENT GRID */}
      <div className={`grid grid-cols-1 lg:grid-cols-12 gap-8 ${isWrongNetwork ? 'grayscale opacity-30 pointer-events-none' : ''}`}>
        
        {/* SIDEBAR: Upload Control */}
        <aside className="lg:col-span-4 space-y-6">
          <div className="sticky top-8">
            <h2 className="text-sm font-mono text-primary mb-4 uppercase tracking-widest">Inbound Pipeline</h2>
            <UploadOrchestrator />

            <div className="mt-6 p-4 rounded-xl bg-surface/50 border border-highlight/10">
              <h4 className="text-[10px] font-bold text-gray-500 uppercase mb-2">Protocol Stats</h4>
              <div className="grid grid-cols-2 gap-2 text-[10px] font-mono">
                <div className="text-gray-400">STORAGE: <span className="text-white">IRYS_L1</span></div>
                <div className="text-gray-400">REGISTRY: <span className="text-white">STYLUS_VM</span></div>
                <div className="text-gray-400">ENCRYPTION: <span className="text-white">AES_GCM</span></div>
                <div className="text-gray-400">STATUS: <span className="text-green-400">ONLINE</span></div>
              </div>
            </div>
          </div>
        </aside>

        {/* MAIN: Assets Gallery */}
        <section className="lg:col-span-8">
          <h2 className="text-sm font-mono text-primary mb-4 uppercase tracking-widest">On-Chain Assets</h2>
          <div className="bg-surface/30 rounded-3xl p-4 md:p-8 border border-highlight/10 min-h-[60vh]">
            <VaultGallery />
          </div>
        </section>
      </div>
    </main>
  );
}

"use client";

import { useAccount, useSwitchChain } from "wagmi";
import { useRouter } from "next/navigation";
import { useEffect, useRef } from "react";
import { DisconnectButton } from "@components/ui/disconnect-button";
import { CHAIN_CONFIG } from "@config/contracts";

export default function DashboardPage() {
  const { address, isConnected, chainId } = useAccount();
  const { switchChain } = useSwitchChain();
  const router = useRouter();
  const sessionAddress = useRef<string | undefined>(undefined);

  useEffect(() => {
    if (!isConnected) {
      router.replace("/");
      return;
    }
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
    <main className="container-responsive py-6 md:py-8 space-y-6 md:space-y-8 overflow-x-hidden">
      {/* Responsive Header */}
      <header className="flex flex-row justify-between items-center bg-surface p-4 rounded-2xl border border-highlight shadow-sm gap-2">
        <div className="flex flex-col min-w-0"> {/* min-w-0 avoids text overflow */}
          <h1 className="text-lg md:text-xl font-bold text-primary italic tracking-tighter">KIPIO</h1>
          <span className="text-[10px] md:text-xs font-mono opacity-50 bg-background px-2 py-0.5 rounded-full border border-highlight/20 truncate">
            {/* Truncate address more aggressively on mobile */}
            <span className="md:hidden">{address?.slice(0, 4)}...{address?.slice(-4)}</span>
            <span className="hidden md:inline">{address}</span>
          </span>
        </div>
        <div className="flex-shrink-0">
          <DisconnectButton />
        </div>
      </header>

      {/* Network Enforcement */}
      {isWrongNetwork && (
        <div className="bg-red-500/10 border border-red-500/50 p-4 rounded-xl flex flex-col md:flex-row justify-between items-center gap-4 animate-in fade-in slide-in-from-top-4">
          <p className="text-xs md:text-sm text-red-200 font-medium text-center md:text-left">
            ⚠️ Vault Locked: Wrong Network.
          </p>
          <button 
            onClick={() => switchChain({ chainId: CHAIN_CONFIG.id })}
            className="bg-red-500 text-white text-xs px-4 py-2 rounded-lg font-bold w-full md:w-auto hover:bg-red-600 transition-all active:scale-95 shadow-lg shadow-red-500/20"
          >
            Switch to Arbitrum Sepolia
          </button>
        </div>
      )}

      {/* Grid Section */}
      <section className="min-h-[50vh] flex flex-col items-center justify-center border-2 border-dashed border-highlight rounded-3xl p-6 md:p-12 text-center bg-surface/30">
          {!isWrongNetwork ? (
            <div className="max-w-xs md:max-w-md flex flex-col items-center">
                <div className="w-12 h-12 md:w-16 md:h-16 bg-primary/10 rounded-full flex items-center justify-center mb-4">
                  <svg className="w-6 h-6 md:w-8 md:h-8 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                  </svg>
                </div>
                <h3 className="text-base md:text-lg font-semibold mb-2 text-primary">No encrypted data found</h3>
                <p className="text-xs md:text-sm opacity-50 mb-6">
                  Your Stylus vault is empty. Start by uploading to the Irys L1.
                </p>
                <button className="w-full md:w-auto bg-primary text-on-primary px-8 py-3 rounded-xl font-bold hover:shadow-[0_0_20px_rgba(16,185,129,0.4)] transition-all active:scale-95">
                    + Upload to Irys
                </button>
            </div>
          ) : (
            <div className="grayscale opacity-40">
               <p className="text-xs md:text-sm font-medium">Please switch networks.</p>
            </div>
          )}
      </section>
    </main>
  );
}

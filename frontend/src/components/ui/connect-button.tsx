"use client";

import { useAccount, useConnect } from "wagmi";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

/**
 * Kipio Connection Manager
 * Manages unique connector rendering and prevents "ghost" redirections after logout.
 */
export function ConnectButton() {
  const { isConnected, isReconnecting } = useAccount();
  const { connect, connectors } = useConnect();
  const router = useRouter();
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  useEffect(() => {
    if (isConnected && mounted && !isReconnecting) {
      // 1. Check if we have an active logout block
      const isLoggedOut = localStorage.getItem("kipio_logged_out");
      
      if (isLoggedOut === "true") {
        // We are in a post-logout state; do not redirect automatically
        return;
      }

      router.replace("/dashboard");
    }
  }, [isConnected, mounted, isReconnecting, router]);

  if (!mounted) return null;

  /**
   * Filter logic to clean up the UI from redundant injected providers
   */
  const hasSpecificWallets = connectors.some(c => c.name !== 'Injected');
  const filteredConnectors = connectors.filter((connector, index, self) => {
    const isFirstOccurrence = index === self.findIndex((c) => c.name === connector.name);
    const isRedundantInjected = hasSpecificWallets && connector.name === 'Injected';
    return isFirstOccurrence && !isRedundantInjected;
  });

  const handleConnect = (connector: any) => {
    // 2. Remove the logout block as soon as the user intentionally clicks a wallet
    localStorage.removeItem("kipio_logged_out");
    connect({ connector });
  };

  if (isConnected) return null;

  return (
    <div className="flex flex-col gap-3 w-full">
      {filteredConnectors.map((connector) => (
        <button
          key={connector.id}
          onClick={() => handleConnect(connector)}
          className="bg-primary text-on-primary py-3 px-4 rounded-xl font-bold hover:scale-[1.02] active:scale-[0.98] transition-all flex items-center justify-center gap-2 text-sm shadow-lg shadow-primary/10"
        >
          Connect with {connector.name}
        </button>
      ))}
    </div>
  );
}

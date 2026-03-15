"use client";

import { useDisconnect } from "wagmi";

/**
 * Kipio Disconnect Component
 * Handles deep session clearing to prevent Brave Wallet's aggressive auto-reconnection.
 */
export function DisconnectButton() {
  const { disconnectAsync } = useDisconnect();

  const handleLogout = async () => {
    try {
      // 1. Mark the session as intentionally terminated to block the ConnectButton redirect
      localStorage.setItem("kipio_logged_out", "true");

      // 2. Await full cleanup from Wagmi/Viem
      await disconnectAsync();
      
      // 3. Clear persistent storage
      localStorage.removeItem("wagmi.store");
      localStorage.removeItem("wagmi.recentConnectorId");
      localStorage.removeItem("wagmi.connected");

      // 4. Force hard reload to reset the injected provider state
      window.location.href = "/";
    } catch (error) {
      console.error("Logout failed:", error);
      // Fallback
      window.location.href = "/";
    }
  };

  return (
    <button
      onClick={handleLogout}
      className="text-xs border border-red-500/30 text-red-400 px-3 py-1.5 rounded-lg hover:bg-red-500/10 transition-colors"
    >
      Disconnect Wallet
    </button>
  );
}

"use client";

import { useAccount } from "wagmi";

/**
 * Endpoint of the Speculos emulator, resolved in the same order the
 * Ledger connector uses: remote first, local as fallback. In production
 * (Vercel) only the remote URL is set. During local development the
 * local URL is used instead.
 *
 * Both values are build-time constants in Next.js. Updating them
 * requires a redeploy.
 */
const SPECULOS_URL =
  process.env.NEXT_PUBLIC_SPECULOS_URL_REMOTE ||
  process.env.NEXT_PUBLIC_SPECULOS_URL_LOCAL;

/**
 * Banner that surfaces the Speculos emulator URL to users connected
 * through the Ledger Simulator connector.
 *
 * The Speculos emulator renders a virtual Ledger screen on a web page.
 * Signing operations pause on the device side until the user approves
 * them there, so the user must keep that page open in a separate tab
 * while interacting with the application.
 *
 * The banner is intentionally hidden for every other connector
 * (injected wallets, physical Ledger via WebHID) because those sign
 * through their own UI and do not depend on an external endpoint.
 */
export function SpeculosBanner() {
  const { connector } = useAccount();

  const isSpeculos = connector?.id === "ledger-speculos";

  if (!isSpeculos || !SPECULOS_URL) return null;

  return (
    <div className="bg-accent/10 border border-accent/40 p-4 rounded-2xl flex flex-col md:flex-row justify-between items-center gap-4 animate-in fade-in slide-in-from-top-4">
      <div className="flex-1 min-w-0 text-center md:text-left">
        <div className="flex items-center gap-2 justify-center md:justify-start mb-1">
          <span className="w-1.5 h-1.5 bg-accent rounded-full animate-pulse" />
          <p className="text-[10px] md:text-xs font-mono uppercase tracking-widest text-accent font-bold">
            Ledger Simulator Active
          </p>
        </div>
        <p className="text-xs md:text-sm text-main font-medium">
          Approve every transaction on the emulator screen.
        </p>
        <p className="text-[10px] md:text-xs text-main/40 font-mono mt-1 break-all">
          {SPECULOS_URL}
        </p>
      </div>
      <a
        href={SPECULOS_URL}
        target="_blank"
        rel="noopener noreferrer"
        className="bg-primary text-on-primary text-xs px-6 py-2.5 rounded-xl font-bold w-full md:w-auto text-center tracking-wide hover:scale-[1.02] active:scale-[0.98] transition-all shadow-lg shadow-primary/20"
      >
        OPEN EMULATOR
      </a>
    </div>
  );
}

import { ConnectButton } from "@components/ui/connect-button";

/**
 * Shared class for footer links.
 *
 * A permanent, low-contrast underline signals that the element is
 * interactive without competing visually with the primary CTA. On
 * hover, the underline reaches full opacity and the text brightens
 * slightly to confirm the affordance.
 */
const FOOTER_LINK_CLASS =
  "text-cyan-300/90 underline decoration-cyan-400/30 decoration-1 underline-offset-4 hover:decoration-cyan-300 hover:text-cyan-200 transition-all";

export default function HomePage() {
  return (
    <main className="container-responsive min-h-screen flex flex-col items-center justify-center space-y-8">
      <div className="text-center space-y-4">
        <h1 className="hero-title text-heading">KIPIO</h1>
        <p className="text-subheading max-w-md mx-auto">
          The first truly sovereign image vault. Encrypted by your keys, 
          stored on Irys DataChain L1, indexed by Arbitrum Stylus.
        </p>
      </div>

      <div className="bg-surface p-8 rounded-2xl border border-highlight shadow-xl w-full max-w-sm">
        <h2 className="text-xl font-bold mb-6 text-center">Access your Vault</h2>
        <ConnectButton />
      </div>

      <footer className="text-sm opacity-70 absolute bottom-8 flex flex-wrap items-center justify-center gap-x-3 gap-y-1 text-center px-4">
        <span>Built with </span>
        <a
          href="https://sepolia.arbiscan.io/address/0xfe76a53e5cc1cc5136b7da6b6fcf6c593c767452"
          target="_blank"
          rel="noopener noreferrer"
          className={FOOTER_LINK_CLASS}
        >
          Arbitrum Stylus
        </a>
        <span>-</span>
        <a
          href="https://docs.irys.xyz/foundations/introduction"
          target="_blank"
          rel="noopener noreferrer"
          className={FOOTER_LINK_CLASS}
        >
          Irys
        </a>
        <span>&</span>
        <a
          href="https://github.com/AndresChanchi/vaultchain-sovereign-agent"
          target="_blank"
          rel="noopener noreferrer"
          className={FOOTER_LINK_CLASS}
        >
          GitHub
        </a>
        <span>2026</span>
      </footer>
    </main>
  );
}

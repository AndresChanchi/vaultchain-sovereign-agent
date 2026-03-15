import { ConnectButton } from "@components/ui/connect-button";

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

      <footer className="text-sm opacity-50 absolute bottom-8">
        Built for Arbitrum Stylus & Irys • 2026
      </footer>
    </main>
  );
}

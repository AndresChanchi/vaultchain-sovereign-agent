import type { ReactNode } from "react";
import { Web3Provider } from "@components/web3-provider";

export const metadata = {
  title: "Kipio | Sovereign Data Vault",
  description: "Secure, encrypted, and decentralized image vault on Arbitrum Stylus",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <head>
        <link rel="stylesheet" href="/output.css" />
        <link rel="icon" href="/favicon.ico" />
      </head>
      <body className="bg-background text-main">
        <Web3Provider>
          {children}
        </Web3Provider>
      </body>
    </html>
  );
}

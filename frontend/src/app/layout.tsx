import type { ReactNode } from "react";
import { Web3Provider } from "@components/web3-provider";

export const metadata = {
  title: "Kipio | Sovereign Data Vault",
  description: "Secure, encrypted, and decentralized image vault on Arbitrum Stylus",
  other: {
    "talentapp:project_verification": "0e8df25d9f3bfe18da48710a0878309a9f387703e3f51c3a2fa401a4f947e24aa93849a05ec57b35066e1f39d751234d8f54a7a785528938bc49d7c01ef61307",
  },
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

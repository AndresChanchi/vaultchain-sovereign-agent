"use client";

import type { ReactNode } from "react";
import { WagmiProvider } from "wagmi";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { config } from "@config/wagmi";
import { KipioProvider } from "@context/KipioContext";

const queryClient = new QueryClient();

export function Web3Provider({ children }: { children: ReactNode }) {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <KipioProvider>
          {children}
        </KipioProvider>
      </QueryClientProvider>
    </WagmiProvider>
  );
}

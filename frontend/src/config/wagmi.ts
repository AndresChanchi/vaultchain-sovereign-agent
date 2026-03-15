import { http, createConfig, createStorage } from 'wagmi'
import { arbitrum, arbitrumSepolia } from 'wagmi/chains'
import { injected } from 'wagmi/connectors'
import { CHAIN_CONFIG, IS_SEPOLIA } from '@config/contracts'

/**
 * Wagmi Configuration for Kipio
 * * We use 'injected()' to support Brave, MetaMask, Rabby, and other browser wallets.
 * The active chain is determined by the NEXT_PUBLIC_NETWORK environment variable.
 */
export const config = createConfig({
  chains: [IS_SEPOLIA ? arbitrumSepolia : arbitrum],
  multiInjectedProviderDiscovery: true,
  connectors: [
    injected({ 
      shimDisconnect: true 
    }),
  ],
  transports: {
    [arbitrumSepolia.id]: http(process.env.NEXT_PUBLIC_RPC_URL_SEPOLIA),
    [arbitrum.id]: http(process.env.NEXT_PUBLIC_RPC_URL_MAINNET),
  },
})

declare module 'wagmi' {
  interface Register {
    config: typeof config
  }
}

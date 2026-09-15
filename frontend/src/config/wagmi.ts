import { http, createConfig } from 'wagmi'
import { arbitrum, arbitrumSepolia } from 'wagmi/chains'
import { injected } from '@wagmi/connectors'
import { createLedgerDMKConnector } from '@lib/ledger/connector'
import { CHAIN_CONFIG, IS_SEPOLIA } from '@config/contracts'

/**
 * Ordered list of Speculos endpoints to try.
 *
 * The remote endpoint is preferred when present, falling back to the
 * local one during development. Empty values are filtered out so the
 * connector only receives reachable candidates.
 */
const SPECULOS_URLS = [
  process.env.NEXT_PUBLIC_SPECULOS_URL_REMOTE,
  process.env.NEXT_PUBLIC_SPECULOS_URL_LOCAL,
].filter((url): url is string => typeof url === 'string' && url.length > 0)

/**
 * Wagmi Configuration for Kipio
 *
 * Connectors:
 * - injected(): browser wallets (MetaMask, Brave, Rabby, etc.)
 * - Ledger (Simulator): Ledger emulator via DMK + Speculos transport
 * - Ledger (Physical): Ledger hardware via DMK + WebHID transport
 *
 * The two Ledger connectors expose a Viem-compatible account through
 * the Device Management Kit. Application code does not need to know
 * which transport is in use.
 *
 * The active chain is determined by the NEXT_PUBLIC_NETWORK environment
 * variable through the contract configuration.
 */
export const config = createConfig({
  chains: [IS_SEPOLIA ? arbitrumSepolia : arbitrum],
  multiInjectedProviderDiscovery: true,
  connectors: [
    injected({ 
      shimDisconnect: true 
    }),
    createLedgerDMKConnector(
      { type: 'speculos', urls: SPECULOS_URLS },
      'ledger-speculos',
      'Ledger Simulator',
    ),
    createLedgerDMKConnector(
      { type: 'webhid' },
      'ledger-physical',
      'Ledger',
    ),
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

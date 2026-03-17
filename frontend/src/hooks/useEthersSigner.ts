import { useMemo } from 'react';
import { useConnectorClient } from 'wagmi';
import { clientToSigner } from '@lib/utils/viem-to-ethers';
import { CHAIN_CONFIG } from '@config/contracts';

/**
 * Hook to bridge Wagmi's Viem client to an Ethers v6 Signer.
 * Fixes Type Error by narrowing the chainId to supported Arbitrum IDs.
 */
export function useEthersSigner({ chainId }: { chainId?: number } = {}) {
  // Narrowing the type to match your Wagmi Config (421614 | 42161)
  const targetChainId = chainId as typeof CHAIN_CONFIG.id | undefined;
  
  const { data: client } = useConnectorClient({ chainId: targetChainId });

  return useMemo(() => {
    if (!client) return undefined;
    return clientToSigner(client);
  }, [client]);
}

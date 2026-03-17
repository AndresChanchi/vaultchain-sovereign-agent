import { BrowserProvider, JsonRpcSigner } from 'ethers';
import type { Account, Chain, Client, Transport } from 'viem';

/**
 * Converts a Viem Client (from Wagmi) to an Ethers v6 Signer.
 * Required for Irys SDK compatibility.
 */
export function clientToSigner(client: Client<Transport, Chain, Account>): JsonRpcSigner {
  const { account, chain, transport } = client;
  
  const network = {
    chainId: chain.id,
    name: chain.name,
    ensAddress: chain.contracts?.ensRegistry?.address,
  };

  // Ethers v6 BrowserProvider takes the transport (EIP-1193) and network info
  const provider = new BrowserProvider(transport, network);
  
  return new JsonRpcSigner(provider, account.address);
}

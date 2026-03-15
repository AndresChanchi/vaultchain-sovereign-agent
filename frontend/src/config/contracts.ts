import IVaultChainMVP from "./IVaultChainMVP.json";

const network = (process.env.NEXT_PUBLIC_NETWORK || "sepolia") as "sepolia" | "mainnet";

export const IS_SEPOLIA = network === "sepolia";

export const CHAIN_CONFIG = {
  id: (IS_SEPOLIA 
    ? Number(process.env.NEXT_PUBLIC_CHAIN_ID_SEPOLIA) 
    : Number(process.env.NEXT_PUBLIC_CHAIN_ID_MAINNET)) as 421614 | 42161,
  rpc: IS_SEPOLIA 
    ? process.env.NEXT_PUBLIC_RPC_URL_SEPOLIA 
    : process.env.NEXT_PUBLIC_RPC_URL_MAINNET,
  explorer: IS_SEPOLIA 
    ? process.env.NEXT_PUBLIC_EXPLORER_SEPOLIA 
    : process.env.NEXT_PUBLIC_EXPLORER_MAINNET,
};

export const VAULT_CONTRACT = {
  address: (IS_SEPOLIA 
    ? process.env.NEXT_PUBLIC_CONTRACT_ADDRESS_SEPOLIA 
    : process.env.NEXT_PUBLIC_CONTRACT_ADDRESS_MAINNET) as `0x${string}`,
  abi: IVaultChainMVP,
};

export const IRYS_CONFIG = {
  gateway: process.env.NEXT_PUBLIC_IRYS_GATEWAY,
  node: process.env.NEXT_PUBLIC_IRYS_NODE,
};

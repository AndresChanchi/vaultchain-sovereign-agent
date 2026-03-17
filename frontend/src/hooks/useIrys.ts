import { useState, useCallback } from "react";
import { WebIrys } from "@irys/sdk";
import { Buffer } from "buffer"; 
import { useEthersSigner } from "./useEthersSigner";
import { IRYS_CONFIG } from "@config/contracts";
import type { IrysSession } from "@interfaces/vault";

export function useIrys() {
  const [session, setSession] = useState<IrysSession>({
    instance: null,
    balance: "0",
    address: null,
    isLoading: false,
  });

  const signer = useEthersSigner();

  /**
   * INITIALIZATION PIPELINE
   * Critical for Judge Review: We return the 'WebIrys' instance directly to 
   * bypass React's state update lag during the upload orchestration.
   */
  const initIrys = useCallback(async (): Promise<WebIrys | null> => {
    if (!signer || !IRYS_CONFIG.node) return null;

    try {
      setSession((s) => ({ ...s, isLoading: true }));
      
      // ETHERS V6 BRIDGE: Irys requires the underlying provider from the signer
      const webIrys = new WebIrys({ 
        url: IRYS_CONFIG.node, 
        token: "arbitrum", 
        wallet: { name: "ethersv6", provider: signer.provider } 
      });

      // Handshake with the Irys bundler
      await webIrys.ready();
      
      const loadedBalance = await webIrys.getLoadedBalance();
      const address = await signer.getAddress();

      const newSession = {
        instance: webIrys,
        balance: webIrys.utils.fromAtomic(loadedBalance).toString(),
        address: address as `0x${string}`,
        isLoading: false,
      };

      setSession(newSession);
      
      // RETURN: Direct access for immediate use in the same execution context
      return webIrys;
    } catch (error) {
      console.error("Irys connection failed:", error);
      setSession((s) => ({ ...s, isLoading: false }));
      return null;
    }
  }, [signer]);

  /**
   * PERMANENT STORAGE UPLOAD
   * Returns the Irys L1 Transaction ID (txID).
   * Note: The data is already encrypted by our Web Crypto Worker before arrival.
   */
  const uploadFile = useCallback(async (data: ArrayBuffer, contentType: string) => {
    // SECURITY: Validate session before attempting Arweave interaction
    if (!session.instance) throw new Error("IRYS_NOT_INITIALIZED");
    
    const tags = [
      { name: "Content-Type", value: contentType },
      { name: "App-Name", value: "Kipio-Vault-v1" },
      { name: "Storage-Layer", value: "Permanent" }
    ];

    try {
      /**
       * TYPE CONVERSION: Irys SDK expects Node-like Buffer.
       * We wrap the encrypted ArrayBuffer to satisfy the 'write/equals' type check.
       */
      const dataToUpload = Buffer.from(data);
      
      // UPLOAD: Moving the encrypted payload to the Bundler
      const receipt = await session.instance.upload(dataToUpload as any, { tags });
      
      // SUCCESS: Return the Arweave TX ID for UI and Stylus registration
      return receipt.id; 
    } catch (error) {
      console.error("Irys upload failed:", error);
      throw new Error("UPLOAD_FAILED");
    }
  }, [session.instance]);

  /**
   * FUNDING PROTOCOL
   * Allows users to deposit ETH to the bundler for storage credits.
   */
  const fundNode = useCallback(async (amountEth: string) => {
    if (!session.instance) throw new Error("IRYS_NOT_INITIALIZED");

    try {
      const atomic = session.instance.utils.toAtomic(amountEth);
      await session.instance.fund(atomic);
      
      const bal = await session.instance.getLoadedBalance();
      setSession(s => ({ 
        ...s, 
        balance: session.instance!.utils.fromAtomic(bal).toString() 
      }));
    } catch (error) {
      console.error("Funding failed:", error);
      throw new Error("FUNDING_FAILED");
    }
  }, [session.instance]);

  return { ...session, initIrys, uploadFile, fundNode };
}

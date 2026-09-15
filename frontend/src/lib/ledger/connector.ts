import { createConnector } from "wagmi";
import {
  DeviceManagementKitBuilder,
  DeviceActionStatus,
  hexaStringToBuffer,
} from "@ledgerhq/device-management-kit";
import { speculosTransportFactory } from "@ledgerhq/device-transport-kit-speculos";
import { webHidTransportFactory } from "@ledgerhq/device-transport-kit-web-hid";
import { SignerEthBuilder } from "@ledgerhq/device-signer-kit-ethereum";
import {
  createPublicClient,
  createWalletClient,
  custom,
  http,
  serializeTransaction,
  type Address,
  type Hex,
} from "viem";
import { toAccount } from "viem/accounts";

/**
 * Standard Ethereum derivation path (BIP-44).
 * m / purpose' / coin_type' / account' / change / address_index
 */
const DERIVATION_PATH = "44'/60'/0'/0/0";

/**
 * Ledger origin token.
 *
 * Required by the default Context Module to enable Clear Signing.
 * Without a valid token, transaction details are not displayed on the
 * device screen and the signer falls back to blind signing (hash only).
 */
const ORIGIN_TOKEN = "test-origin-token";

/**
 * Transport descriptor for a Ledger DMK connector.
 */
export type LedgerTransportConfig =
  | { type: "speculos"; urls: string[] }
  | { type: "webhid" };

type SignerEth = ReturnType<SignerEthBuilder["build"]>;
type DMKInstance = ReturnType<DeviceManagementKitBuilder["build"]>;

interface TransportAttempt {
  label: string;
  create: () => DeviceManagementKitBuilder;
}

function buildAttempts(config: LedgerTransportConfig): TransportAttempt[] {
  if (config.type === "speculos") {
    return config.urls.map((url) => ({
      label: `speculos:${url}`,
      create: () =>
        new DeviceManagementKitBuilder().addTransport(
          speculosTransportFactory(url),
        ),
    }));
  }
  return [
    {
      label: "webhid",
      create: () =>
        new DeviceManagementKitBuilder().addTransport(webHidTransportFactory),
    },
  ];
}

function discoverAndConnect(dmk: DMKInstance): Promise<string> {
  return new Promise<string>((resolve, reject) => {
    const subscription = dmk.startDiscovering({}).subscribe({
      next: async (device) => {
        try {
          const session = await dmk.connect({ device });
          subscription.unsubscribe();
          resolve(session);
        } catch (err) {
          subscription.unsubscribe();
          reject(err);
        }
      },
      error: (err) => {
        subscription.unsubscribe();
        reject(err);
      },
    });
  });
}

/**
 * Converts an arbitrary value emitted by the DMK error channel into a
 * human-readable string. DMK emits structured error objects that are not
 * instances of Error.
 */
function describeDeviceError(error: unknown): string {
  if (error instanceof Error) return error.message;
  if (typeof error === "string") return error;
  if (error && typeof error === "object") {
    const candidate = error as Record<string, unknown>;
    if (typeof candidate.message === "string") return candidate.message;
    if (typeof candidate.errorCode === "string") return candidate.errorCode;
    try {
      return JSON.stringify(candidate);
    } catch {
      return "[unserializable DMK error]";
    }
  }
  return String(error);
}

/**
 * Runs a DMK device action observable and resolves with its output once
 * the device finishes the operation.
 */
function runDeviceAction<T>(
  observable: { subscribe: (observer: any) => any },
): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    observable.subscribe({
      next: (state: any) => {
        if (state.status === DeviceActionStatus.Completed) {
          resolve(state.output as T);
        } else if (state.status === DeviceActionStatus.Error) {
          reject(new Error(`LEDGER_DEVICE_ERROR: ${describeDeviceError(state.error)}`));
        }
      },
      error: (err: unknown) => {
        reject(new Error(`LEDGER_OBSERVABLE_ERROR: ${describeDeviceError(err)}`));
      },
    });
  });
}

/**
 * Serializes a DMK signature ({ r, s, v }) into a 65-byte hex string as
 * expected by Viem for message and typed-data signatures.
 *
 * DMK may return v as 0/1 (recovery id) while the canonical Ethereum
 * personal_sign format expects 27/28.
 */
function serializeMessageSignature(signature: {
  r: string;
  s: string;
  v: number;
}): Hex {
  const r = signature.r.startsWith("0x") ? signature.r.slice(2) : signature.r;
  const s = signature.s.startsWith("0x") ? signature.s.slice(2) : signature.s;
  const normalizedV = signature.v >= 27 ? signature.v : signature.v + 27;
  const v = normalizedV.toString(16).padStart(2, "0");
  return `0x${r.padStart(64, "0")}${s.padStart(64, "0")}${v}` as Hex;
}

/**
 * Converts the DMK recovery parameter to the yParity value expected by
 * Viem for transaction serialization.
 */
function toYParity(v: number): 0 | 1 {
  return (v >= 27 ? v - 27 : v) as 0 | 1;
}

/**
 * Decodes a hex-encoded UTF-8 message into its plain string form.
 * Used to forward `personal_sign` payloads to the DMK signer, which
 * expects a UTF-8 string, not a hex blob.
 */
function hexToUtf8(hex: string): string {
  const clean = hex.startsWith("0x") ? hex.slice(2) : hex;
  if (!clean) return "";
  const bytes = clean.match(/.{1,2}/g)?.map((byte) => parseInt(byte, 16));
  if (!bytes || bytes.some(isNaN)) return hex;
  return new TextDecoder().decode(Uint8Array.from(bytes));
}

/**
 * Normalizes a Viem TypedData object into the shape expected by the
 * Ledger Ethereum Signer Kit.
 *
 * The device expects:
 *   - domain.chainId as a number (not a bigint)
 *   - no EIP712Domain entry inside `types` (it is derived from `domain`)
 *   - primaryType and message as-is
 *
 * The input is typed as `unknown` on purpose: Viem produces a very
 * narrow generic shape (`EIP712DomainDefinition<...>`) that is
 * incompatible with a plain record at the type level, but structurally
 * exposes the same fields. The cast happens once, here.
 */
function normalizeTypedDataForLedger(input: unknown) {
  const typedData = input as {
    domain: Record<string, unknown>;
    types: Record<string, Array<{ name: string; type: string }>>;
    primaryType: string;
    message: Record<string, unknown>;
  };

  const { chainId, ...restDomain } = typedData.domain;

  const filteredTypes = Object.fromEntries(
    Object.entries(typedData.types).filter(([key]) => key !== "EIP712Domain"),
  );

  return {
    domain: {
      ...restDomain,
      ...(chainId !== undefined ? { chainId: Number(chainId) } : {}),
    },
    types: filteredTypes,
    primaryType: typedData.primaryType,
    message: typedData.message,
  };
}

/**
 * Extracts a UTF-8 string from the various shapes Viem uses for
 * signable messages (plain string, { raw: Uint8Array }, { raw: Hex }).
 */
function extractSignableText(message: unknown): string {
  if (typeof message === "string") return message;
  if (message && typeof message === "object") {
    const candidate = message as { raw?: unknown };
    if (candidate.raw instanceof Uint8Array) {
      return new TextDecoder().decode(candidate.raw);
    }
    if (typeof candidate.raw === "string" && candidate.raw.startsWith("0x")) {
      return hexToUtf8(candidate.raw);
    }
    if (candidate.raw !== undefined) return String(candidate.raw);
  }
  return String(message);
}

/**
 * Options accepted by the Wagmi connector `connect` method.
 *
 * `withCapabilities` is part of the Wagmi v3 connector contract and
 * controls whether accounts are returned as bare addresses or as
 * objects that include a `capabilities` record.
 */
interface ConnectOptions {
  chainId?: number;
  isReconnecting?: boolean;
  withCapabilities?: boolean;
}

/**
 * Creates a Wagmi connector that uses the Ledger Device Management Kit
 * (DMK) as the signing backend.
 *
 * The connector exposes a Viem-compatible account through `getClient`.
 * Its custom transport routes EIP-1193 signing methods to the DMK-backed
 * account, including `eth_sendTransaction`, which is required by any
 * consumer that wraps the wallet client in a JsonRpcSigner (ethers-based
 * SDKs such as Irys). Read-only RPC methods are proxied to a public
 * client built on the chain's default HTTP transport.
 */
export function createLedgerDMKConnector(
  transportConfig: LedgerTransportConfig,
  connectorId: string,
  connectorName: string,
) {
  return createConnector((config) => {
    let dmk: DMKInstance | null = null;
    let sessionId: string | null = null;
    let signerEth: SignerEth | null = null;
    let cachedAddress: Address | null = null;

    async function ensureSession(): Promise<{
      sessionId: string;
      signerEth: SignerEth;
    }> {
      if (sessionId && signerEth) {
        return { sessionId, signerEth };
      }

      const attempts = buildAttempts(transportConfig);
      if (attempts.length === 0) {
        throw new Error(
          "LEDGER_NOT_CONFIGURED: no Speculos endpoints configured. " +
            "Set NEXT_PUBLIC_SPECULOS_URL_LOCAL or NEXT_PUBLIC_SPECULOS_URL_REMOTE.",
        );
      }

      const errors: Array<{ label: string; message: string }> = [];

      for (const attempt of attempts) {
        try {
          const sdk = attempt.create().build();
          const id = await discoverAndConnect(sdk);
          const signer = new SignerEthBuilder({
            dmk: sdk,
            sessionId: id,
            originToken: ORIGIN_TOKEN,
          }).build();

          dmk = sdk;
          sessionId = id;
          signerEth = signer;
          return { sessionId: id, signerEth: signer };
        } catch (err) {
          errors.push({ label: attempt.label, message: describeDeviceError(err) });
        }
      }

      const summary = errors
        .map((e) => `${e.label}: ${e.message}`)
        .join(" | ");
      throw new Error(`LEDGER_UNAVAILABLE: ${summary}`);
    }

    return {
      id: connectorId,
      name: connectorName,
      type: "ledger" as const,

      async connect(parameters: ConnectOptions = {}) {
        const { signerEth: signer } = await ensureSession();
        const output = await runDeviceAction<{ address: Address }>(
          signer.getAddress(DERIVATION_PATH, { checkOnDevice: false }).observable,
        );
        cachedAddress = output.address;

        const address = output.address;
        const accounts = parameters.withCapabilities
          ? [{ address, capabilities: {} as Record<string, unknown> }]
          : [address];

        return {
          accounts,
          chainId: config.chains[0].id,
        } as any;
      },

      async disconnect() {
        if (sessionId && dmk) {
          try {
            await dmk.disconnect({ sessionId });
          } catch {
            // Session may already be closed on the device side.
          }
        }
        dmk = null;
        sessionId = null;
        signerEth = null;
        cachedAddress = null;
      },

      async getAccounts() {
        if (cachedAddress) return [cachedAddress] as readonly Address[];
        const { signerEth: signer } = await ensureSession();
        const output = await runDeviceAction<{ address: Address }>(
          signer.getAddress(DERIVATION_PATH, { checkOnDevice: false }).observable,
        );
        cachedAddress = output.address;
        return [output.address] as readonly Address[];
      },

      async getChainId() {
        return config.chains[0].id;
      },

      async isAuthorized() {
        return cachedAddress !== null;
      },

      async getProvider() {
        return undefined as any;
      },

      async getClient({ chainId }: { chainId?: number } = {}) {
        const { signerEth: signer } = await ensureSession();

        const accountAddress =
          cachedAddress ??
          (
            await runDeviceAction<{ address: Address }>(
              signer.getAddress(DERIVATION_PATH, { checkOnDevice: false })
                .observable,
            )
          ).address;
        cachedAddress = accountAddress;

        const account = toAccount({
          address: accountAddress,

          async signMessage({ message }) {
            const text = extractSignableText(message);
            const output = await runDeviceAction<{
              r: string;
              s: string;
              v: number;
            }>(signer.signMessage(DERIVATION_PATH, text).observable);
            return serializeMessageSignature(output);
          },

          async signTransaction(transaction) {
            const serialized = serializeTransaction(transaction);
            const rawTx = hexaStringToBuffer(serialized);
            if (!rawTx) throw new Error("INVALID_TRANSACTION_FORMAT");

            const output = await runDeviceAction<{
              r: string;
              s: string;
              v: number;
            }>(signer.signTransaction(DERIVATION_PATH, rawTx).observable);

            return serializeTransaction({
              ...transaction,
              r: output.r as Hex,
              s: output.s as Hex,
              yParity: toYParity(output.v),
            });
          },

          async signTypedData(typedData) {
            const normalized = normalizeTypedDataForLedger(typedData);
            const output = await runDeviceAction<{
              r: string;
              s: string;
              v: number;
            }>(signer.signTypedData(DERIVATION_PATH, normalized).observable);
            return serializeMessageSignature(output);
          },
        });

        const chain =
          config.chains.find((c) => c.id === chainId) ?? config.chains[0];

        /**
         * Public client used to prepare and broadcast transactions.
         * Reuses the chain's default HTTP transport, which is defined by
         * the chain object registered in the Wagmi config.
         */
        const publicClient = createPublicClient({
          chain,
          transport: http(chain.rpcUrls.default.http[0]),
        });

        /**
         * Custom transport that bridges EIP-1193 requests to the DMK
         * account. Signing methods (personal_sign, signTypedData,
         * sendTransaction, signTransaction) are routed to the Ledger
         * signer. Read-only methods are proxied to the public client so
         * ethers' BrowserProvider can resolve chain state and nonces
         * without a dedicated provider.
         */
        const transport = custom({
          request: async ({ method, params }) => {
            switch (method) {
              case "eth_requestAccounts":
              case "eth_accounts":
                return [accountAddress];

              case "eth_chainId":
                return `0x${(chain?.id ?? config.chains[0].id).toString(16)}`;

              case "personal_sign": {
                const [messageHex] = (params ?? []) as [string, string];
                const message = hexToUtf8(messageHex);
                return account.signMessage({ message });
              }

              case "eth_signTypedData_v4": {
                const [, typedDataJson] = (params ?? []) as [string, string];
                return account.signTypedData(JSON.parse(typedDataJson));
              }

              case "eth_sendTransaction": {
                const [rawTx] = (params ?? []) as [Record<string, unknown>];

                const prepared = await publicClient.prepareTransactionRequest({
                  ...rawTx,
                  account: accountAddress,
                  chain,
                } as any);

                const signedTx = await account.signTransaction(prepared as any);

                return publicClient.sendRawTransaction({
                  serializedTransaction: signedTx,
                });
              }

              case "eth_signTransaction": {
                const [rawTx] = (params ?? []) as [Record<string, unknown>];

                const prepared = await publicClient.prepareTransactionRequest({
                  ...rawTx,
                  account: accountAddress,
                  chain,
                } as any);

                return account.signTransaction(prepared as any);
              }

              default:
                return publicClient.request({ method, params } as any);
            }
          },
        });

        return createWalletClient({
          account,
          chain,
          transport,
        });
      },

      onAccountsChanged() {
        cachedAddress = null;
      },

      onChainChanged() {
        // Ledger sessions are chain-agnostic.
      },

      onDisconnect() {
        dmk = null;
        sessionId = null;
        signerEth = null;
        cachedAddress = null;
      },
    };
  });
}

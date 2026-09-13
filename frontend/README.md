# Kipio Frontend

A privacy-first, decentralized upload interface designed for permanent data storage.

Built for users who want full control over their files — without subscriptions, without lock-in, and without compromising ownership.

> This folder contains only the Next.js dApp. For the project overview, ETHOnline 2026 submission details, architecture, and roadmap, see the [root README](https://github.com/AndresChanchi/vaultchain-sovereign-agent/blob/main/README.md).

---

## 📦 Installation

To install dependencies:

```bash
bun install
```

Build styles:

```bash
bun run build:styles
```

## 🚀 Development

To start the development server:

```bash
bun run dev
```

Production build:

```bash
bun run build
```

---

This project was created using `bun init` in bun v1.4.2. [Bun](https://bun.sh) is a fast all-in-one JavaScript runtime.

---

## 🔧 Environment Variables

Create a `.env.local` file at the root of `frontend/`. Every variable is prefixed with `NEXT_PUBLIC_` because they are consumed by client components.

### Blockchain (Arbitrum)

```bash
NEXT_PUBLIC_NETWORK=sepolia

NEXT_PUBLIC_RPC_URL_SEPOLIA=https://sepolia-rollup.arbitrum.io/rpc
NEXT_PUBLIC_CHAIN_ID_SEPOLIA=421614
NEXT_PUBLIC_CONTRACT_ADDRESS_SEPOLIA=0xfe76a53e5cc1cc5136b7da6b6fcf6c593c767452
NEXT_PUBLIC_EXPLORER_SEPOLIA=https://sepolia.arbiscan.io

NEXT_PUBLIC_RPC_URL_MAINNET=https://arb1.arbitrum.io/rpc
NEXT_PUBLIC_CHAIN_ID_MAINNET=42161
NEXT_PUBLIC_CONTRACT_ADDRESS_MAINNET=0x...
NEXT_PUBLIC_EXPLORER_MAINNET=https://arbiscan.io
```

### Irys

```bash
NEXT_PUBLIC_IRYS_GATEWAY=https://gateway.irys.xyz/
NEXT_PUBLIC_IRYS_NODE_DEVNET=https://devnet.irys.xyz/
NEXT_PUBLIC_IRYS_NODE_MAINNET=https://node1.irys.xyz/
```

### Ledger DMK

```bash
# Ordered list of Speculos endpoints. The connector tries each URL in
# order and caches the first one that responds.
#
# Remote endpoint (Oracle Cloud / VPS). Used on Vercel.
# Leave empty during local-only development.
NEXT_PUBLIC_SPECULOS_URL_REMOTE=

# Local endpoint (Docker on the developer machine).
NEXT_PUBLIC_SPECULOS_URL_LOCAL=http://localhost:5000
```

On Vercel, set `NEXT_PUBLIC_SPECULOS_URL_REMOTE` to the HTTPS URL of the deployed Speculos instance and leave `NEXT_PUBLIC_SPECULOS_URL_LOCAL` empty.

---

## ⛓️ Infrastructure (Integrated)

This frontend is already connected to a production-ready stack:

* Irys (data layer) ✅
* Arbitrum Stylus contracts (Rust) ✅
* WASM-based optimizations ✅
* Client-side encryption & decryption ✅
* Ledger DMK signing (Speculos + WebHID) ✅

> For the Ledger integration architecture, signing flow, and known limitations, see the [root README](https://github.com/AndresChanchi/vaultchain-sovereign-agent/blob/main/README.md#-ledger-integration-overview).

---

## 🔐 Ledger Connector (Implementation)

The signing pipeline is exposed through two Wagmi v3 connectors that share the same DMK-based signer. Only the transport differs.

### Files

| Path | Responsibility |
|---|---|
| `src/lib/ledger/connector.ts` | Custom Wagmi connector. Wraps DMK, exposes a Viem-compatible account, and routes EIP-1193 methods to the Ledger signer. |
| `src/config/wagmi.ts` | Registers `ledger-physical` (WebHID) and `ledger-speculos` (HTTP). Reads Speculos endpoints from environment variables and tries them in order. |
| `src/hooks/useVault.ts` | Detects the active Ledger connector via `connector.id` and extends the retry buffer for hardware signing latency. |

### Speculos endpoints

The `ledger-speculos` connector accepts an ordered list of URLs. It tries each one until a Speculos instance responds, then caches the session for the rest of the tab's lifetime.

* In development: `NEXT_PUBLIC_SPECULOS_URL_LOCAL` (`http://localhost:5000`)
* On Vercel: `NEXT_PUBLIC_SPECULOS_URL_REMOTE` (HTTPS URL of the deployed Speculos)

### Local Speculos (development)

The emulator backend lives in `../emulator-ledger-backend/`. It ships a precompiled Ethereum app ELF and a Docker command. See that folder's README for setup.

### Testing the Ledger flow

1. Start Speculos locally (or verify the deployed one responds).
2. Open the dApp and click **Connect with Ledger Simulator**.
3. When a signature is requested, open the Speculos web UI in another tab and approve on the emulated screen.
4. The dApp receives the signature through the connector and continues.

---

## ✅ Current Status (Frontend)

* Fully functional on **desktop environments**
* Core upload, encryption, and sharing flows operational on Arbitrum Sepolia
* Two Ledger connectors exposed in the login screen
* Signing routed through DMK for both physical and emulated devices

⚠️ **Known Issues (Mobile)**

* Some image uploads may fail in edge cases on mobile devices
* Likely caused by **price fluctuations during upload execution**
* This issue does not typically occur on desktop
* Improvements are planned to handle volatility more reliably


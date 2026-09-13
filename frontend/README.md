# Kipio Frontend

A privacy-first, decentralized upload interface designed for permanent data storage.

Built for users who want full control over their files — without subscriptions, without lock-in, and without compromising ownership.

---

## 🏆 ETHOnline 2026

This project is being submitted to [ETHOnline 2026](https://ethglobal.com/events/ethonline2026), the annual online hackathon organized by ETHGlobal.

The submission targets the **Ledger — Continuity** track, which rewards integrations that extend an existing, functional product with a new capability. Kipio already runs end-to-end on Arbitrum Sepolia (upload, encryption, Irys storage, Stylus registry) with browser wallets. The hackathon work adds hardware-backed signing via the Ledger Device Management Kit (DMK) without touching the smart contracts.

The integration supports two signing paths that share the same DMK signer:

- **Physical Ledger devices** connected over WebHID.
- **Speculos emulator** deployed on Oracle Cloud, exposed over HTTPS, so reviewers can experience the full signing flow without owning hardware.

See the [Ledger integration](#-ledger-integration) section below for details.

> **Note on the deeper engineering**: The `develop` branch contains a substantially more advanced version of the protocol, including formal methods work (Dafny → Rust transpilation), a modular multi-crate Stylus workspace, and TACo-aligned threshold cryptography. It is under active development and diverges significantly from `main`. Anyone interested in the research direction should read it directly.

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
URL: https://sepolia.arbiscan.io/address/0xfe76a53e5cc1cc5136b7da6b6fcf6c593c767452

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

## ✅ Current Status (MVP)

* Fully functional on **desktop environments**
* Supports users familiar with crypto wallets
  (e.g. interacting with Arbitrum Sepolia and managing tokens)
* Core upload, encryption, and sharing flows are operational on testnet
* Hardware-backed signing available via Ledger (physical or emulated)

⚠️ **Known Issues (Mobile)**

* Some image uploads may fail in edge cases on mobile devices
* Likely caused by **price fluctuations during upload execution**
* This issue does not typically occur on desktop
* Improvements are planned to handle volatility more reliably

---

## ⛓️ Infrastructure (Integrated)

This frontend is already connected to a production-ready stack:

* Irys (data layer) ✅
* Arbitrum Stylus contracts (Rust) ✅
* WASM-based optimizations ✅
* Client-side encryption & decryption ✅
* Ledger DMK signing (Speculos + WebHID) ✅

> ℹ️ This repository focuses on the frontend layer only.
> For detailed information about infrastructure and smart contracts, see the corresponding README files in their respective folders.

---

## 🔐 Ledger Integration

The dApp exposes two Ledger connectors through Wagmi v3. Both share the same signing pipeline based on the Ledger Device Management Kit; only the transport differs.

| Connector | Transport | Use case |
|---|---|---|
| `ledger-physical` | WebHID | Users with a physical Ledger device connected over USB |
| `ledger-speculos` | HTTP | Reviewers and demos, backed by an emulated Ledger Nano S Plus |

### Architecture

```
             ┌───────────────────────┐
             │     Wagmi connector   │
             │   (custom, DMK-based) │
             └───────────┬───────────┘
                         │
              ┌──────────┴──────────┐
              │                     │
       ┌──────▼──────┐      ┌───────▼────────┐
       │   WebHID    │      │    Speculos    │
       │  transport  │      │    transport   │
       └──────┬──────┘      └───────┬────────┘
              │                     │
       ┌──────▼──────┐      ┌───────▼────────┐
       │  Physical   │      │  Speculos VM   │
       │  Ledger     │      │  (Docker +     │
       │             │      │   Oracle Cloud)│
       └──────┬──────┘      └───────┬────────┘
              └──────────┬──────────┘
                         │
                ┌────────▼────────┐
                │  SignerEth      │
                │  (DMK)          │
                └────────┬────────┘
                         │
                ┌────────▼────────┐
                │   viem / dApp   │
                └─────────────────┘
```

### Speculos emulator

Speculos runs the official Ledger Ethereum app in a Docker container and serves its screen through a web UI. Reviewers open the emulator in a browser, approve operations with on-screen buttons, and the dApp receives the signature through the connector.

The emulator is deployed on Oracle Cloud Always Free and exposed over HTTPS through a Cloudflare Tunnel. The `emulator-ledger-backend/` folder in the parent repository contains the Docker command, the precompiled ELF, and the deployment notes.

### Signing flow

The connector routes EIP-1193 signing methods to the DMK signer:

- `personal_sign` → EIP-191 message signature
- `eth_signTypedData_v4` → EIP-712 typed-data signature
- `eth_sendTransaction` → prepares, signs, and broadcasts a transaction
- `eth_signTransaction` → prepares and signs without broadcasting

Read-only RPC methods are proxied to a public client built on the chain's HTTP transport.

### Known limitations

- **Blind signing**: without a Ledger `originToken` issued by the partner program, the device only displays the transaction hash instead of the decoded call details. The integration ships with a placeholder token. Clear Signing requires an official token and is out of scope for the hackathon.
- **Arbitrum Sepolia on physical devices**: testnet networks require Developer Mode enabled in Ledger Wallet. Users connecting a physical device should enable it before testing.

---

## 🔮 Roadmap (Post-MVP)

### 🔐 Security & Session Management

* **Inactivity Timer**
  Automatically lock sessions after inactivity (Paranoid privacy even down to the hardware...)

* **"Lock Vault" Button**
  Let users manually close their cryptographic session without closing the tab

---

### ⚠️ Error Handling

* **Global Error Handling (Toasts)**
  Clear feedback for failed actions (e.g. rejected signatures)

---

### 👤 User Experience & Onboarding

* **Account Abstraction (AA)**
  Make the app usable for non-crypto-native users:

  * Social login (Google and alternatives)
  * Smart accounts instead of traditional wallets

* **Paymaster Integration**
  Enable gasless or sponsored transactions

* **Privacy-Respecting Options**
  Reduce reliance on centralized providers and prioritize user privacy

---

### 🔗 Sharing & Privacy

* **Private Sharing (Invite Links)**
  Share securely with selected users and restrict unwanted access

* **Public Sharing Option**
  Share files publicly without encryption when desired

* **ZK-based Hybrid Model (Exploration)**
  Combine privacy and usability for flexible sharing modes

---

### 🖼️ Media & Upload Improvements

* Improve handling of:

  * Small images
  * Edge-case upload failures
  * Market volatility during upload execution

---

### 🧩 Content Expansion (Beyond Photos)

Current MVP is focused on **images**, inspired by a real need:

* Backing up large personal photo collections (e.g. 10GB–20GB+)
* Avoiding subscription-based storage models

Future direction expands beyond that:

* **Private “Google Photos”-like experience (but decentralized)**
* Support for:

  * Documents
  * Development files
  * Arbitrary data uploads

Goal:

> A general-purpose, permanent, user-owned storage layer — not just a photo app.

---

### 🔬 Research

* **Asymmetric Encryption**
  Continued improvements in secure key management and data sharing

# Kipio: Autonomous Sovereign Digital Property

Kipio is an agent-native digital sovereignty architecture(in the future) that integrates **Arbitrum Stylus (WASM)** and **Irys L1 Datachain**. It evolves the "Cloud Storage" model into a "Digital Property" paradigm, eliminating recurring subscription fees and centralized censorship.

Built for the 2026 ecosystem, Kipio leverages Rust-powered smart contracts to manage permanent data pointers with near-native execution speed.

---

## 🏆 ETHOnline 2026

This project is submitted to [ETHOnline 2026](https://ethglobal.com/events/ethonline2026), the annual online hackathon organized by ETHGlobal.

The submission targets the **Ledger — Continuity** track, which rewards integrations that extend an existing, functional product with a new capability. Kipio already runs end-to-end on Arbitrum Sepolia (upload, encryption, Irys storage, Stylus registry) with browser wallets. The hackathon work adds hardware-backed signing via the Ledger Device Management Kit (DMK) without touching the smart contracts.

The integration supports two signing paths that share the same DMK signer:

- **Physical Ledger devices** connected over WebHID.
- **Speculos emulator** deployed on Oracle Cloud, exposed over HTTPS through a Cloudflare Tunnel, so reviewers can experience the full signing flow without owning hardware.

> **Note on the deeper engineering**: The [develop](https://github.com/AndresChanchi/vaultchain-sovereign-agent/blob/develop/contracts/README.md#-research--references) branch contains a substantially more advanced version of the protocol, including formal methods work (Dafny → Rust transpilation), a modular multi-crate Stylus workspace, and TACo-aligned threshold cryptography. It is under active development and diverges significantly from `main`. Anyone interested in the research direction should read it directly.

`With the caveat that only the documentation is outdated as of May 2026 😅. I have the rest stored in my local Git repo, which is about to burst with all the up-to-date information... `

### 🔐 Ledger Integration Overview

The dApp exposes two Ledger connectors through Wagmi v3. Both share the same signing pipeline based on the Ledger Device Management Kit; only the transport differs.

| Connector | Transport | Use case |
|---|---|---|
| `ledger-physical` | WebHID | Users with a physical Ledger device connected over USB |
| `ledger-speculos` | HTTP (HTTPS via Cloudflare Tunnel) | Reviewers and demos, backed by an emulated Ledger Nano S Plus |

#### Architecture

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

#### Signing flow

The connector routes EIP-1193 signing methods to the DMK signer:

- `personal_sign` → EIP-191 message signature
- `eth_signTypedData_v4` → EIP-712 typed-data signature
- `eth_sendTransaction` → prepares, signs, and broadcasts a transaction
- `eth_signTransaction` → prepares and signs without broadcasting

Read-only RPC methods are proxied to a public client built on the chain's HTTP transport.

#### Speculos emulator

Speculos runs the official Ledger Ethereum app in a Docker container and serves its screen through a web UI. Reviewers open the emulator in a browser, approve operations with on-screen buttons, and the dApp receives the signature through the connector.

The emulator is deployed on Oracle Cloud Always Free and exposed over HTTPS through a Cloudflare Tunnel. The `emulator-ledger-backend/` folder contains the Docker command, the precompiled ELF, and the deployment notes.

#### Known limitations

- **Blind signing**: without a Ledger `originToken` issued by the partner program, the device only displays the transaction hash instead of the decoded call details. The integration ships with a placeholder token. Clear Signing requires an official token and is out of scope for the hackathon.
- **Arbitrum Sepolia on physical devices**: testnet networks require Developer Mode enabled in Ledger Wallet. Users connecting a physical device should enable it before testing.

---

## 🌀 System Architecture

![Architecture](https://kroki.io/mermaid/svg/eNqNVntPIzcQ_59PYeV0FUiAEkg4SKVWOV6HLlBKKFXPOlVe7-zGysaObC-wRffdO37sI4GTCGg9tmd-87adFeqJz5m25P5si-Dv40cys1UB5AwyIYUVShq_wQtmDC4SK2wBgYerQunxh36_v5spafeeQORzO05Uke4aq9UC9p5Eaufjg9Xzr1s1_rm0uiK3SkhLmEzJVQoSQSsyZRVozzWzaNL2th92dsje3m9kBgVwS8OAVn0PjH7qGSalnU9VLvjLXwY0mcIjFL__CFpNmeSareaByakhtDfYJ1-qRItNC3oB2v0aTNRAejfqUXDoBW0TOuFclejDJEFfWceo15K3WgWxWwziAip6w6x4hHo6Jgb46mB0pActQgs18aKfS5kWoGkcW8YI4pn-hsRplrQm3sCLADGqxqDdV2e0oVqJGmOd02-DTDcie6GxAnAZXeWOVeYY4oN9MlWcFaSzun2rxSPjFbkQ2tidTrQbFcEVpRfobhg6Rvm55_DQX5iZ06DEkS1js-t5zyAtV4XgzKXpxS_DszDWYIm87dCVrsx0cMYswwYREr053PeLZDoYO4eQbblkCfbBzCrNcui4sqYuFk-ogOdh_-CWVdSNmLpqiaXXysXdEPEyWQo7pWHEgk7zbiDitmd1Zj1c0zCMCVYmhpKE-jt_Bl6uF2fgCwVZJoUw8ymNRFSDDoJeMonG1d51Ci7KeIBvX_-d_Tml374SHMiVTDGsMv_-k6BOctdpvG7B4X698qr1Am7oNcdyr0WOhlE_IXHW6bcOjxe618BMqauXmiDXTKIbLt4_GrFm06UID5Ns7wK7Ax0IybqDhBVMcgjpsopcMkMuAMipko-gzVpYG24ve1EALM4xmNRTxJEtb7Prec_vTo_7_SG9BAmaWXDlpTKC_xvZex1RdxKX5kbgcYsBHe3HBfILmegEV8sl8Zu9n-Tvc1ks7iCnbkQPcuwJXbW80bKY6gfQIqtoGFrbMO0L8sfKiqX4D9I3jpzG2uuysMLFkPbct01Jx7xwRnmrQh_YS62e7JzGQiRhui5Q2-YlTtVyhSbRU2Xs2M9KjCmutDIukK_MrDUFtUu8fB4YGkw9STzdIkQlG7wtVrMUK4krLJiK1kTozo2sutu3khyTd1ood1puvX2Y_AMmFOhsrp6o-2AyMHNN521od6DUfeKu0-HrTqbb2_gZEx89AamrvBVoW-3sNCZNVq12LEnj7v7wKPBk51LNRFGMP8AgG2UQXwD4PBiMPp0krx4Eu-3roYP1xjUSQLNBdgwnDejh4dHJAN4JunmUR8QsO4R-gwhHo0G__07EtXMswnEYAm_gjo_7MMzeCddt4oh2CKNs1KAN2WB4zN-J1jRZ4yf-GqhPI_dXQ6V4EzKtGb5BRmTUwfvpxv_nhCKo)

[Architecture in spanish](https://kroki.io/mermaid/svg/eNqNVetOIzcU_s9TWFltBRKgBBIWUqlVNlw22kApoVTqqEIez5mJm4kd2R5gdrUP1B_7ax9gpc2L9diecQYCFQNS7HP5zvG5ZooupuT6eIPg9_YtOYaUC8748psgCRDQhudSkwVVlEBODDwYaRmWqIs4UzSV2imznGqN6sRwk8PElDkQJnOp-m_a7fZ2KoXZuQeeTU0_lnmyrY2SM9i554mZ9vcWDz9v1D6MrAOSlGRIF9QaGyUgDE9oQj4sv8YKT050Yqgym5tefGuL7Oz8QiaQAzOe7Y6OOijMdCwzzj7_-H7B7_AhiPqHLqji8tcv3rB_DQbDCdMSVNTq7P6PD62_nZ79Aj5aI60LeUeNbHnLg2jAmCyEIYMYn0yZ4VK8pHmpKrVLjOUMyuiCGnS3vvaJBrbY6x2ozgphBTVwqu8LkeSgArnSdbw_IbYGxbpypUV-CjJVOLVGf0e-PkAkT2J1qjCtSEbHmRUVWdTa2yX-SuccYybJWDKak81Lxe8oK8kpV9psNaIXjHgfpZo13PdXx3E4H6ieBmagOP4xJMUi54xiOQjMtGOUWLcPXBvAPD__hpEq9bhzTA1lU8pF1NrfdTQy7vTJIJ9TBqJ-Cj4MleY0zqHxgEeGqxLweXzotvcuaRkkq7uPbRHPuRmvwuDvjmft35xH_qdPTv4BVoSmHC-_YcG4qsTaAi1XnngFX0JFnHM9HUfVgYwhyUCtPwnUnAo8wgqm1nVAf328nfw-fiF4g8y2Bav6pVv1yyBb_mvJzR7xML4prNK14lnWSHST6KSuFVBdqPJzfSDnVNAM5ij3JagFpg07Fq7E-UUF49XzfBquIKY5UiEaSnEHSrtQ2mQQSs6oJqfQeH2QdrqnOcDsBEMX-IHi-CdXw8N2uxudgQBFlS0RmRL8P3nApK26fT12dkYW-oLjIIxavd3qji04UDESizlxvNYLeXlf5LMryAKzcqTK2Q0onpaR_7kNvtyOxOz2t4Xhc_4JkmemSPDuvMgNx9hErTO7BaraQ0LDHz85nBu-pM2Zkvdm-kig9sVJDOV8gS5gHrSRfXctDE5XMVuh2kit-VVDY3gqDG9xjjvghqKvK8lAqnLPJKa8fJwEXDNDDkoBrpkJFwznGP9EXYttPN_Sk-VXX0yTqbyPzqUd5gqTbGdLaJ4ntielYJ6OB18tItncPOWib-tkwcEuFBceNJXQra3g3aCyXsXdbVLQ9oibNLHbMZYqAb97tdu2YXGRlOd5_w100l4K1aLFLdzpvTuK1_bu9mpJN7DWB3sFmnbSQzgKoPv7B0cdeCXok0lbI6bpPrQDIhz0Ou32KxGb46eGY9AFFuAOD9vQTV8J1-jIGm0femkvoHVpp3vIXolWd9DqnfgFqHc9-1dDJbirqFIUd3yP9Bp4_wFVE_s4)

## ✨ Key Features (2026 Standards)

* **Arbitrum Stylus (Rust):** High-performance WASM execution for cryptographic verification and batch processing of metadata.
* **Agentic Commerce (x402):** Autonomous treasury management for self-funding data availability without monthly fees.
* **Native Passkey Support:** Secure signing using hardware-bound `secp256r1` keys (FaceID/TouchID).
* **Irys L1 Integration:** Direct settlement of permanent storage pointers on the Irys Datachain.
* **Ledger Hardware Signing:** WebHID transport for physical devices and Speculos transport for emulated ones, both routed through the Ledger Device Management Kit.

## 🛠 Tech Stack

* **Smart Contracts:** Rust (Stylus SDK), Solidity (Foundry).
* **Storage:** Irys L1 Datachain.
* **Compute:** Fleek Network (Off-chain Agent execution).
* **Runtime:** Bun v1.4.x.

## 📦 Repository Layout

```
.
├── contracts/                    # Stylus + Foundry contracts and formal methods work
├── emulator-ledger-backend/      # Speculos Docker setup + compiled Ethereum app ELF
└── frontend/                     # Next.js dApp (upload, encryption, Ledger signing)
```

Each folder contains its own README with setup and architecture details for that layer.

## ✅ Current Status (MVP)

* Fully functional on **desktop environments**
* Supports users familiar with crypto wallets (Arbitrum Sepolia, Irys devnet)
* Core upload, encryption, and sharing flows operational on testnet
* Hardware-backed signing available via Ledger (physical or emulated through Speculos)

⚠️ **Known Issues (Mobile)**

* Some image uploads may fail in edge cases on mobile devices
* Likely caused by **price fluctuations during upload execution**
* This issue does not typically occur on desktop
* Improvements are planned to handle volatility more reliably

## 🔮 Roadmap (Post-MVP)

### 🔐 Security & Session Management

* **Inactivity Timer** — Automatically lock sessions after inactivity
* **"Lock Vault" Button** — Manually close the cryptographic session without closing the tab

### ⚠️ Error Handling

* **Global Error Handling (Toasts)** — Clear feedback for failed actions (e.g. rejected signatures)

### 👤 User Experience & Onboarding

* **Account Abstraction (AA)** — Social login, smart accounts instead of traditional wallets
* **Paymaster Integration** — Gasless or sponsored transactions
* **Privacy-Respecting Options** — Reduce reliance on centralized providers

### 🔗 Sharing & Privacy

* **Private Sharing (Invite Links)** — Share securely with selected users
* **Public Sharing Option** — Share files publicly without encryption when desired
* **ZK-based Hybrid Model (Exploration)** — Flexible sharing modes combining privacy and usability

### 🖼️ Media & Upload Improvements

* Improve handling of small images, edge-case upload failures, and volatility during upload

### 🧩 Content Expansion (Beyond Photos)

* Private "Google Photos"-like experience, but decentralized
* Support for documents, development files, and arbitrary data uploads

> Goal: a general-purpose, permanent, user-owned storage layer — not just a photo app.

### 🔬 Research

* **Asymmetric Encryption** — Continued improvements in secure key management and data sharing


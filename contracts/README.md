# Kipio Contracts

Core Smart Contracts for the Kipio Decentralized Sovereign Agent infrastructure, powered by **Arbitrum Stylus (v0.10.7)** and **Rust**.

This repository contains the contracts deployed to Arbitrum Sepolia and instructions to build, test, and deploy locally.

Additionally, this workspace implements a resilient, crypto-agile, and modular architecture designed to store non-sensitive decentralized file pointers (Irys) and orchestrate access control policies without binding the state to vulnerable cryptographic primitives.

---

## Prerequisites

Before starting, ensure you have the following installed:

* **Rust Toolchain**: `v1.94.0` or later.
* **WASM Compilation Target**: 
 ```bash
  rustup target add wasm32-unknown-unknown
```

* **Cargo Stylus CLI**:
```bash
cargo install --force cargo-stylus
```


* **Foundry Toolkit**: Essential for integration tests and dual-language fuzzing/fork testing.

---

## Quick Start & Tooling Orchestration

The project uses an advanced global `Makefile` capable of managing individual crates or the entire workspace cohesively.

### 1. Project Initialization

Generate or update the global deterministic dependency tree:

```bash
make lock
```

### 2. Workspace Multi-Crate Compilation

Compile all modular contracts into optimized WebAssembly (`wasm32-unknown-unknown`) binaries:

```bash
make build
```

*To target a single contract:* `make build contract=kipio_access`

### 3. Automated ABI Generation & Extraction

Export and normalize Solidity interfaces directly to the Foundry testing tree to maintain real-time sync with frontends or agent clients:

```bash
make abi
```

*To target a single contract:* `make abi contract=kipio_core`

### 4. Off-Chain Testing

Run isolated, ultra-fast unit testing via the **Motsu Framework** at the library level:

```bash
make test
```

### 5. Code Coverage Analysis

Execute structural code coverage reporting via cargo-tarpaulin (forces full recompilation):

```bash
make coverage
```

### 6. On-Chain Simulation & Pre-Flight Validation

Perform a dry-run activation simulation against the Arbitrum Sepolia RPC. This checks contract size thresholds (strictly flags anything violating the **24 KB EVM limit**) and WASM host compatibility rules:

```bash
make check
```

### 7. Multi-Contract Protocol Deployment

Deploys compiled WASM bytecode to Arbitrum Sepolia utilizing the secure `PRIVATE_KEY` environment variable configured in `.env`:

```bash
make deploy
```

---

## Technical Architecture: Kernel & Modules Pattern

To decouple cryptography from state persistence and guarantee **Crypto Agility (Long-term Resilience)**, the repository has transitioned away from monolithic storage structures into an immutable **Kernel + Replaceable Modules** framework.

```
                  ┌────────────────────────────────────────┐
                  │          Frontend SDK / Client         │
                  │   (AES/ChaCha Ciphers & WebAuthn)      │
                  └───────────────────┬────────────────────┘
                                      │
                         Invokes Core │ (Signs EIP-712 / Passes Hashes)
                                      ▼
                        ┌───────────────────────────┐
                        │   KipioCore (Kernel)      │
                        │   (Immutable Anchor)      │
                        └─────────────┬─────────────┘
                                      │
               ┌──────────────────────┼──────────────────────┐
               │ Queries Verification │                      │ Delegates State
               ▼                      ▼                      ▼
    ┌────────────────────┐ ┌────────────────────┐ ┌────────────────────┐
    │     KipioAuth      │ │   KipioRegistry    │ │    KipioAccess     │
    │  (Curve Registry)  │ │ (Encrypted Metadata│ │ (Permission Maps & │
    └──────────┬─────────┘ │    & Irys Pointers)│ │  Off-chain kfrags) │
               │           └────────────────────┘ └────────────────────┘
               ▼ Calls External Verifier
    ┌────────────────────┐
    │ KipioAuthVerifier  │
    │ (Native EVM Curve) │
    └────────────────────┘

```

### 1. The Kernel Layer (`kipio_core`)

The immutable, minimal state router. It stores **no cryptographic logic, zero plaintext, and no secrets**. It maintains steady references to current operational modules and maps a cryptographic user anchor (`StorageB256`). This guarantees the system survives future algorithmic migrations without structural data updates.

### 2. Identity & Authentication Layer (`kipio_auth` & `kipio_auth_verifier_p256`)

* Handles user public key identity mapping via secure anonymized public key hashes (`keccak256(pubkey)`), shielding the system from chain analysis exposure.
* Implements robust anti-replay mechanisms through custom EIP-712 structured typed digests.
* Isolates curve specific execution into lightweight verification crates utilizing **EVM precompiles** (P-256) to ensure optimal gas fees.
* *Historical Legacy Snapshot:* The manual `secp256k1` (K-256) threshold structure remains documented inside `kipio_auth_verifier_k256` as an alternative self-hosted design pattern prior to integrating decentralized **TACo (Threshold Access Control)** networks.

### 3. Content Registry Layer (`kipio_registry`)

Manages structural tracking metadata and encrypted Irys pointer locations (`ContentRecord`) using immutable tracking indices. Implements strict borrow semantics on native Stylus collections (`StorageVec`) to adhere to Rust's unique memory ownership models.

### 4. Access Control Layer (`kipio_access`)

Coordinates decentralized file sharing policies by logging encrypted off-chain cryptographic pointer fragments (**kfrags** or threshold capsules) and index structures for secure consumer application parsing.

### 5. Recovery Infrastructure (`kipio_recovery`)

Secures module evolution. Interacts directly with the Core router via cross-contract calls to perform module hot-swaps under valid multi-signature setups or emergency access thresholds.

---

## 🛠️ Security Engineering & Mobile Paradigms

The codebase enforces strict operational constraints to support low-power mobile clients (e.g., MetaMask Mobile, Brave iOS/Android WebViews) while ensuring enterprise-level data privacy:

* **Zero Debug Privacy Leaks:** All standard tracking or debugging logs (`console.log`) are omitted or restricted to anonymized `B256` hashes to shield structural user activities from malicious node or third-party indexer tracking.
* **Asynchronous Mobile Bridges:** Structural event metrics use standard NatSpec index patterns (`address indexed user`, `bytes32 indexed contentHash`). Mobile bridges require indexed hashes to query state deltas instantly without stalling device webviews.
* **Swap-and-Pop Deletion Rules:** Storage arrays avoid the "Ghost Entry" vulnerability. Removing files triggers structural index cleanups to prevent empty loops and bound long-term RPC paginating execution gas costs.

---

## 🎯 Production Optimization Roadmap

### Phase 1: Mitigating the $N+1$ RPC Latency Problem

The system previously relied on a **Normalized Storage Pattern** where asset arrays (`StorageVec<B256>`) returned arrays of plain hashes, forcing frontend applications to trigger sequential nested RPC calls to resolve specific encrypted asset locations (`IrysID`).

To establish a performant **$O(1)$ frontend matrix**, the registry has shifted towards an **Atomic Batch Retrieval Pattern**. By wrapping fields natively inside a Stylus composite type layout, clients fetch indices and asset descriptors in a single round-trip:

```rust
// Canonical EVM-Compatible Record Layout
sol! {
    struct EncryptedAssetRecord {
        bytes32 contentHash;
        string encryptedTxId;
        uint64 version;
        bool isPublic;
    }
}

// Single Call High-Throughput Reader
pub fn get_vault_paginated_full(
    &self, 
    owner: Address, 
    offset: u32, 
    limit: u32
) -> Vec<EncryptedAssetRecord> {
    // Structural pagination logic returning dense composite objects
}
```

### Phase 2: Hybrid Capability & Ecosystem Scaling

1. **Multichain Wallets & Alternative Payment Channels:** Expanding verification hooks to dynamically settle access fees in arbitrary currencies (e.g., CCOP, CELO).
2. **Media-Agnostic Core Anchors:** Maintaining completely abstract metadata pointers to support seamless parsing of images, high-definition video feeds, digital documents, or autonomous agent behaviors without needing core state upgrades.
3. **Hybrid Verification Pipelines:** Running extensive dual-track fuzz testing pipelines: utilizing Rust-native libraries via **Motsu** for low-level storage assertion, combined with **Foundry** network state forking to validate structural multi-contract integration flows.

---

## 📌 Notes

* Contract is deployed on **Arbitrum Sepolia**, verified, and linked above.
* The frontend repository expects **ABI sync** with the latest Stylus compilation.
* Makefile targets must be followed in order (`lock → build → check → test → deploy`) for consistent results.

## 📚 Research & References

This infrastructure is built upon comprehensive cryptographic auditing, low-level runtime specifications, and decentralized system models compiled up to the mid-2026 protocol transition window.

### 1. Arbitrum Nitro, ArbOS Runtime Upgrades & Stylus SDK
* **ArbOS 60 "Elara" Core Proposal:** Structural framework expansion for 96 KB chunked WebAssembly execution boundaries and code splitting arrays.
  * [Arbitrum Governance Forum: AIP ArbOS 60 Elara](https://forum.arbitrum.foundation/t/constitutional-aip-arbos-60-elara/30601)
* **ArbOS 32 "Bianca" & 51 "Dia" Specifications:** Historical deployment timelines for native execution parameters and host testing models.
  * [Arbitrum Docs: ArbOS 32 Release Notes](https://docs.arbitrum.io/run-arbitrum-node/arbos-releases/arbos32)
  * [Arbitrum Docs: ArbOS 51 Release Notes](https://docs.arbitrum.io/run-arbitrum-node/arbos-releases/arbos51)
* **Stylus Call Execution Engine Source (v0.10.7):** Reference implementation for cross-contract messaging invocation layers and gas estimation structures within the Rust execution sandbox.
  * [Docs.rs: stylus_sdk::call Core Module Source](https://docs.rs/stylus-sdk/latest/src/stylus_sdk/call/mod.rs.html)
* **Raw Call Abstraction Specification:** Documentation for untyped low-level message-passing mechanisms used to delegate custom data layouts to alternative modules.
  * [Docs.rs: stylus_sdk::call::RawCall Struct API](https://docs.rs/stylus-sdk/latest/stylus_sdk/call/struct.RawCall.html)
* **WASM Binary Size Control & Pipeline Optimization:** Canonical compiler tuning mechanics (`opt-level = "z"`, `lto = true`) to respect host limits and static calling structures.
  * [Arbitrum Docs: Optimizing Stylus Binaries](https://docs.arbitrum.io/stylus/how-tos/optimizing-binaries)
  * [Arbitrum Docs: Stylus Contract Fundamentals & Static Calling](https://docs.arbitrum.io/stylus/fundamentals/contracts)
  * [OffchainLabs: Cargo Stylus CLI Toolchain](https://github.com/OffchainLabs/cargo-stylus)

### 2. Passkey Authentication & Low-Level Curve Precompiles
* **EIP-7951 Standard:** The authoritative successor to RIP-7212 governing the native `0x100` execution context and Big-Endian inputs for `secp256r1` biometric verifications.
  * [Ethereum Improvement Proposals: EIP-7951 Specifications](https://eips.ethereum.org/EIPS/eip-7951)
  * [Ethereum Magicians: EIP-7951 Core Debate & Implementation](https://ethereum-magicians.org/t/eip-7951-precompile-for-secp256r1-curve-support/24360)
* **RIP-7212 Layer-2 Architecture:** Original roll-up optimization layout enabling mobile hardware enclave validation constraints across optimistic networks.
  * [EIP.tools: RIP-7212 Rollup Blueprint](https://eip.tools/rip/7212)
  * [Alchemy Ledger: Deep Dive into RIP-7212 Rollup Primitives](https://www.alchemy.com/blog/what-is-rip-7212)

### 3. Proxy Re-Encryption (PRE) & Mathematical Tooling
* **The Umbral Scheme:** Threshold Proxy Re-Encryption framework defining cryptographic key routing delegation, `kfrags`, `cfrags`, and split-capsule tokens.
  * [NuCypher Network: Umbral Cryptographic Whitepaper](https://github.com/nucypher/umbral-doc/blob/master/umbral-doc.pdf)
* **The Evolution of Umbral Implementation:** Historical migration notes regarding pure Rust cryptography refactoring and decentralized delegation mechanics.
  * [NuCypher Medium: Unveiling Umbral and Cryptographic Transitions](https://medium.com/nucypher/unveiling-umbral-3d9d4423cd71)
* **Umbral Rust Crates Specification:** Native deterministic processing and algebraic verification modules deployed inside WebAssembly execution runtimes.
  * [Docs.rs: umbral-rs SDK Package Documentation](https://docs.rs/umbral-rs/latest/umbral_rs/)
  * [Docs.rs: umbral-pre Cryptographic Runtime Engine](https://docs.rs/umbral-pre/latest/umbral_pre/)
* **Algebraic Limits on secp256k1 Execution:** Core rationale behind software curve mathematics due to native execution boundaries and the absence of general-purpose ECADD/ECMUL host precompiles on basic Ethereum algorithms.
  * [Ethereum Improvement Proposals Tracker: Issue #603 ECADD/ECMUL](https://github.com/ethereum/EIPs/issues/603)
* **RustCrypto Engine Ecosystem:** Native variable tracking structures used for compiling cryptographic operations inside safe sandboxes.
  * [Crates.io: The k256 Elliptic Curve Crate Suite](https://crates.io/crates/k256)
  * [Crates.io: The p256 WebAuthn Arithmetic Crate Suite](https://lib.rs/crates/stylus-sdk)

### 4. Distributed Architecture & Encrypted Storage Integrations
* **WNFS (Web Native File System):** Modular structure layout addressing secure private capability graphs, self-sovereign cryptographic trees, and nested index trees.
  * [WNFS Working Group: Rust WNFS Core Implementation](https://github.com/wnfs-wg/rs-wnfs)
* **UCAN (User Controlled Authorization Networks):** Distributed authority delegation framework establishing trust chain patterns and cryptographically secure user-space capability certificates without reliance on centralized identity servers.
  * [UCAN Working Group: Core Architecture and Token Specifications](https://github.com/ucan-wg/spec)
* **Irys Invariant Storage Pipelines:** Permanent data tracking frameworks providing continuous accessibility bounds and immutable encrypted content indices.
  * [Irys Network: Developer Ecosystem Documentation](https://docs.irys.xyz)
  * [Arweave Protocol: Core Consensus and Distributed Storage Ledger Specifications](https://github.com/ArweaveTeam/arweave)
* **Threshold Network & Coordination Infrastructure:** Decentralized node access management models guiding token incentives, slashing mechanisms, multi-party computation, and proxy coordination logic.
  * [Threshold Network Technical Repository Workspace](https://github.com/threshold-network)
  * [NuCypher Network Node Architecture Registry](https://github.com/nucypher)
  * [Lit Protocol: Decentralized Key Management and MPC Engineering](https://github.com/LIT-Protocol)

---

**Kipio Sovereign Infrastructure** - May 29 2026

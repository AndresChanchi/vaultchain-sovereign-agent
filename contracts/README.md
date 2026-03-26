# VaultChain Contracts

Core Smart Contracts for the VaultChain Sovereign Agent, powered by **Arbitrum Stylus** and **Rust**.

This repository contains the contracts deployed to Arbitrum Sepolia and instructions to build, test, and deploy locally.

---

## Prerequisites

Before starting, ensure you have the following installed:

* **Rust**: `v1.94.0` or later.
* **WASM Target**: 
```bash
rustup target add wasm32-unknown-unknown
````

* **Cargo Stylus CLI**:

```bash
cargo install --force cargo-stylus
```

---

## Quick Start

Follow these steps to manage the project using the provided `Makefile`:

### 1. Setup & Build

Initialize the environment:

```bash
make lock
```

Compile the contract to WASM:

```bash
make build
```

### 2. Validate Stylus Compatibility

Perform a dry-run check against Arbitrum Sepolia to verify contract size and WASM validity:

```bash
make check
```

### 3. Run Unit Tests

Execute off-chain tests (currently targeted at the library level):

```bash
make test
```

### 4. Deploy to Testnet

Deploy the contract to Arbitrum Sepolia (Requires `PRIVATE_KEY` in `.env`):

```bash
make deploy
```

---

## Technical Architecture

* **Framework**: Arbitrum Stylus SDK `v0.10.2`
* **Memory Management**: `mini-alloc` for optimized WASM heap allocation
* **Storage**: HostIO trait-based storage management
* **Documentation**: NatSpec-compliant English documentation
* **Verified Deployment (Sepolia)**: [0xFe76a53e5cc1cc5136B7dA6b6fCf6C593C767452](https://sepolia.arbiscan.io/address/0xFe76a53e5cc1cc5136B7dA6b6fCf6C593C767452)

---

## Development Workflow

1. **Compilation**: Use `make build` for standard WASM compilation
2. **ABI Export**: To sync with the frontend, generate the Solidity interface:

```bash
make abi
```

> Note: This outputs the Solidity interface. Use a compiler (solc) to generate the final JSON ABI.

3. **Cleanup**: To remove build artifacts:

```bash
make clean
```

---

## 🛠️ Roadmap & Optimization Notes: Stylus Contract

### Current State (MVP)

The contract currently utilizes a **Normalized Storage Pattern**. Metadata is decoupled:

1. `hashes (StorageVec)`: Maintains the order and presence of assets.
2. `registry (StorageMap)`: Stores the mapping of `ContentHash` to `IrysID`.

**Performance Note:** The current `get_my_gallery_paginated` returns `Vec<B256>`. This requires the frontend to perform **N+1 RPC calls** (one to get the list of hashes and *N* calls to resolve each `IrysID` via `get_my_photo`). While secure and simple, this increases latency as the vault grows.

### Proposed Optimization: Atomic Batch Retrieval

To move from "N+1" to **O(1)** frontend queries by implementing a composite return type in Rust.

#### Refactoring Goal:

Create a custom `struct` to return both the hash and the ID in a single call.

```rust
// Proposed Struct for Stylus. Made by AI... I have to analyze it after...
sol! {
    struct PhotoRecord {
        bytes32 contentHash;
        string irysId;
    }
}

// Proposed Function
pub fn get_vault_paginated_full(&self, offset: u32, limit: u32) -> Vec<PhotoRecord> {
    // ... logic to iterate and return Vec of structs
}
```

### Why This Matters

* **Reduced Latency:** 100ms for one call vs 2–3 seconds for a cascade of calls
* **Gas Efficiency:** While read calls are "free" for the user, reducing RPC load improves the scalability of the Sovereign Agent's dashboard
* **UX:** Images start fetching from Arweave/Irys immediately without waiting for sequential blockchain metadata resolution

---

## 📌 Notes

* Contract is deployed on **Arbitrum Sepolia**, verified, and linked above.
* The frontend repository expects **ABI sync** with the latest Stylus compilation.
* Makefile targets must be followed in order (`lock → build → check → test → deploy`) for consistent results.
* Future roadmap includes batch retrieval, further gas optimizations, and potential multi-vault support.

---

**VaultChain Sovereign Agent** - March 2026

# VaultChain Contracts

Core Smart Contracts for the VaultChain Sovereign Agent, powered by **Arbitrum Stylus** and **Rust**.

## Prerequisites

Before starting, ensure you have the following installed:

* **Rust**: `v1.94.0` or later.
* **WASM Target**: 
```bash
rustup target add wasm32-unknown-unknown
```


* **Cargo Stylus CLI**:
```bash
cargo install --force cargo-stylus
```

## Quick Start

Follow these steps to get the environment ready and verify the contract:

### 1. Install Dependencies

Since the `Cargo.lock` is included, this will ensure reproducible builds:

```bash
cargo build
```

### 2. Run Unit Tests

We use **Motsu** for fast, off-chain unit testing. Verify the logic without spending gas:

```bash
cargo test
```

### 3. Validate Stylus Compatibility

This command compiles the contract to WASM and checks if it meets Arbitrum's on-chain requirements (size, gas limits, etc.):

```bash
cargo stylus check
```

## Technical Architecture

* **Framework**: Arbitrum Stylus SDK `v0.10.2`
* **Memory Management**: `mini-alloc` for optimized WASM heap allocation.
* **Storage**: `sol_storage!` for EVM-compatible state management.
* **Logic**: Dual-purpose setup (`lib.rs` for on-chain logic, `main.rs` for ABI export).

## Development Workflow

1. **Iterate**: Use `cargo check` for fast syntax verification.
2. **Test**: Add tests in `src/lib.rs` under `#[cfg(test)]` and run `cargo test`.
3. **Export ABI**: If you change the public functions, update the frontend bindings:

```bash
cargo stylus export-abi
```
## Deployment

To simulate a deployment on Arbitrum Sepolia:

```bash
cargo stylus check --private-key=$YOUR_PRIVATE_KEY --rpc-url=$RPC_URL
```

---

**VaultChain Sovereign Agent** - March 2026


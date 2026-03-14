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

Follow these steps to manage the project using the provided `Makefile`:

### 1. Setup & Build

Initialize the environment:

```bash
make lock
```
and compile the contract to WASM
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

## Technical Architecture

* **Framework**: Arbitrum Stylus SDK `v0.10.2`
* **Memory Management**: `mini-alloc` for optimized WASM heap allocation.
* **Storage**: HostIO trait-based storage management.
* **Documentation**: NatSpec-compliant English documentation.

## Development Workflow

1. **Compilation**: Use `make build` for standard WASM compilation.
2. **ABI Export**: To sync with the frontend, generate the Solidity interface:

```bash
make abi
```
*Note: This outputs the Solidity interface. Use a compiler (solc) to generate the final JSON ABI.*

3. **Cleanup**: To remove build artifacts:
```bash
make clean
```

---

**VaultChain Sovereign Agent** - March 2026

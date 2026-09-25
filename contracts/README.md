# Kipio Contracts

Core smart contracts for the Kipio decentralized sovereign agent infrastructure, powered by **Arbitrum Stylus (SDK v0.10.9)** and **Rust nightly**.

This workspace contains the contracts deployed to Arbitrum Sepolia, plus the tooling to build, test, verify, and deploy them. It is a multi-crate workspace: the Stylus contracts live under `src/`, the ABI ↔ Dafny translation layer lives under `src/bridge/`, and the test suite lives under `tests/`.

The architecture is deliberately modular. Cryptographic primitives, state persistence, and authorization logic are separated so that the system can survive future algorithmic migrations without rewriting stored data.

---

## Prerequisites

Before starting, ensure you have the following installed:

* **Rust nightly**, pinned via `rust-toolchain.toml`:

  ```toml
  [toolchain]
  channel = "nightly-2025-09-23"
  components = ["rust-src"]
  targets = ["wasm32-unknown-unknown"]
  ```

  Rustup auto-installs the pinned toolchain on the first `cargo` invocation from this directory. `rust-src` is required for `-Z build-std`, which the Stylus toolchain uses to strip panic-formatting infrastructure from the WASM.

* **WASM compilation target**:

  ```bash
  rustup target add wasm32-unknown-unknown
  ```

* **Cargo Stylus CLI**:

  ```bash
  cargo install --force cargo-stylus
  ```

  The workspace is validated against `cargo-stylus` v0.10.9. Newer versions are expected to work but have not been tested.

* **`wasm-opt` (Binaryen) v132**: the pinned optimiser, declared in `Stylus.toml`:

  ```toml
  [wasm-opt]
  version = "132"
  flags = [
    "-Oz",
    "--converge",
    "--closed-world",
    "--enable-nontrapping-float-to-int",
    "--strip-debug",
    "--strip-dwarf",
    "--strip-producers",
    "--strip-target-features",
  ]
  ```

  `cargo stylus` downloads the exact Binaryen version automatically during the build. No manual install is required, but the version must match the one in `Stylus.toml` for reproducible verifications.

* **Foundry** (`forge` ≥ 1.5): required for the on-chain tooling (`cast`, `forge`) and for validating the exported Solidity interfaces. `svm install 0.8.37` installs the solc version required by the generated pragma.

* **`jq`**: used by the `deploy-full` and `deploy-resume` targets to accumulate addresses and manifests. Install with your package manager (`apt install jq`, `brew install jq`).

---

## Workspace Layout

```
contracts/
├── Cargo.toml              workspace members + release profile
├── Stylus.toml             workspace networks + [wasm-opt] config
├── rust-toolchain.toml     pinned nightly + rust-src + wasm32 target
├── .cargo/
│   └── config.toml         target-cpu=mvp for wasm32-unknown-unknown
├── Makefile                build / test / check / deploy orchestration
├── src/
│   ├── bridge/                 ABI ↔ Dafny translation layer (local crate)
│   ├── kipio_core/
│   ├── kipio_identity_content/
│   ├── kipio_account/
│   ├── kipio_runtime/
│   ├── kipio_economics/
│   ├── kipio_execution_gateway/
│   ├── kipio_recovery/
│   └── kipio_protocol_config/
└── tests/                  integration suite (unit / e2e / fork)
```

`src/kipio_identity_content` is the result of fusing the former `kipio_auth` (Identity Anchor) and `kipio_access` / `kipio_registry_content` (Content vault) crates into a single bounded context. The fusion removes a cross-call per signature check, unifies the cryptographic-identity and content-vault domains under one storage layout, and keeps the runtime architecture flat.

`src/bridge` is a workspace member but **not** a contract (no `#[entrypoint]`). `tests/` is a workspace member dedicated to integration tests.

### Why the WASM is compiled with `target-cpu=mvp`

The file `.cargo/config.toml` sets:

```toml
[target.wasm32-unknown-unknown]
rustflags = ["-C", "target-cpu=mvp"]
```

This disables **all** post-MVP WebAssembly proposals, including `bulk-memory`. Without it, `wasm-opt` emits a `DataCountSection` when `--enable-bulk-memory` is passed, and ArbOS rejects the program at activation with:

```
unsupported section type DataCountSection { count: N, range: ... }
```

`-Ctarget-feature=-bulk-memory` alone is not sufficient: LLVM includes bulk memory in the `generic` target profile from Rust 1.82 onwards, and the per-feature exclusion is ignored. Only lowering the whole `target-cpu` to `mvp` removes the section reliably. This is the same combination used by the official `wasm32v1-none` target in Rust.

---

## Quick Start

The `Makefile` orchestrates the whole workspace. Every target supports both a workspace-wide mode (default) and a single-contract mode via `contract=<name>`.

### 1. Regenerate the lockfile

```bash
make lock
```

Rebuilds `Cargo.lock` after manual deletions or deep cleans. Does not touch the toolchain.

### 2. Compile contracts

```bash
make build                                # all contracts
make build contract=kipio_identity_content
```

Each contract is compiled to `wasm32-unknown-unknown`, optimised with `wasm-opt 132`, and then hashed to produce its `project metadata hash`.

### 3. Export Solidity ABIs

```bash
make abi                                  # all contracts
make abi contract=kipio_identity_content  # single contract
```

Interfaces land in `foundry/src/interfaces/IKipio<CamelCase>.sol`. The naming convention is derived automatically from the crate name.

The ABI export is done through `cargo run --features export-abi --quiet -- abi --pragma "$(SOLIDITY_PRAGMA)"`, where `SOLIDITY_PRAGMA` is defined at the top of the `Makefile`. This is deliberate: Stylus SDK 0.10.9 hardcodes `DEFAULT_PRAGMA = "^0.8.23"`, which predates the current Solidity release line. The `--pragma` flag overrides it, and the pragma has no relationship to Stylus, ArbOS, or on-chain compatibility — it is a purely off-chain tooling concern.

### 4. Run the test suite

```bash
make test          # unit + e2e (no network)
make test-bridge   # semantic tests for the ABI ↔ Dafny bridge
make test-fork     # fork tests against Sepolia (network required)
make test-all      # all three layers
```

See the **Testing** section below for the full breakdown.

### 5. Dry-run activation against Sepolia

```bash
make check
make check contract=kipio_identity_content
```

`make check` runs each contract with `--verbose` against the Sepolia RPC. The full trace (deployment hash inputs, project metadata hash, wasm-opt version and flags, compressed and uncompressed size, fragment count) is printed to the terminal and saved verbatim to `.check-reports/<contract>.log`. A summary table is printed at the end and persisted to `.check-reports/sizes.tsv`.

Failures do not abort the loop. All failing contracts are collected and reported at the end, and the target exits non-zero.

### 6. Deploy

```bash
make deploy                              # all contracts, in order
make deploy contract=kipio_core          # single contract
make deploy-full                         # deploy + persist addresses + manifest
make deploy-resume                       # resume the last deploy-full
```

`deploy` iterates the `CONTRACTS` list in dependency order. Each contract is deployed with `--max-fee-per-gas-gwei=1` to avoid the Sepolia base-fee race.

`deploy-full` captures the resulting address, deployment transaction hash, activation transaction hash, fragment count, and project metadata hash into `deployments/<timestamp>/addresses.json` and `deployments/<timestamp>/manifest.json`. Per-contract logs are written to the same directory.

`deploy-resume` reads the latest deployment directory, skips any contract already present in `addresses.json`, and continues with the remaining ones. Useful when the RPC drops mid-run.

### 7. Verify a deployed contract

```bash
make verify contract=kipio_core tx=0x<deployment-tx-hash>
```

Recompiles from source and confirms the on-chain bytecode matches. The toolchain, `wasm-opt` version, and all flags are pinned, so the check is deterministic.

### 8. Manage the contract cache

```bash
make cache-suggest addr=0x...              # suggested minimum bid
make cache-bid     addr=0x... bid=...      # submit a bid
make cache-status  addr=0x...              # read cached status
```

ArbOS maintains a contract cache (CacheManager at `0x0000...0070`). Cached contracts save roughly **8,500 gas per call**. Entry is won by bidding on an auction; bids decay over time and must be renewed. Use `cache suggest-bid` as the floor for `cache-bid`.

### 9. Clean

```bash
make clean
```

Removes the `target/` directory and the `.check-reports/` directory.

---

## Foundry Interface Validation (mandatory after `make abi`)

The exported Solidity interfaces must **always** be validated against a real `solc` before being used by any consumer. `make abi` produces syntactically valid Solidity, but the exporter has known limitations that only surface when a proper compiler reads the file:

```bash
cd foundry
forge build
```

**Known exporter limitations (as of Stylus SDK 0.10.9):**

1. **Missing struct declarations.** When an external function references a struct type that is only used as an input (never as a return, never in a storage-backed field), the exporter may omit the struct declaration while still referring to it in the function signature. Example: `IKipioAccount.sol` refers to `IdentityAbi[]` in `registerTransitiveDelegation` but does not emit `struct IdentityAbi`. `solc` rejects this with `Error (7920): Identifier not found or not unique`.

2. **Declaration order.** The exporter emits functions before structs. Solidity requires forward declarations, so any function signature that references a struct emits a warning or error depending on the compiler.

Because these are tooling-side issues in the SDK and not defects in the contract ABI, they are worked around at the Foundry layer (patched interfaces) rather than at the contract layer. The on-chain surface is unaffected: the selectors and calldata layout in the WASM are identical regardless of what the exported `.sol` says.

**Rule:** never ship a `.sol` interface to a downstream consumer without `forge build` passing on it first.

---

## Opcode Limits and Indirect Dispatch

The Stylus build pipeline runs `wasm-opt -Oz --converge --closed-world` over the LLVM output. Binaryen has its own inliner that is independent of LLVM and does **not** honour Rust's `#[inline(never)]`: the attribute is a hint to LLVM IR that is lost in the translation to WASM. Because the entrypoint is the only exported function of the module, Binaryen sees every internal handler as having a single call site and inlines all of them into `user_entrypoint`, rebuilding the monolithic body the fallback split was designed to avoid.

This is the failure mode behind `too many wasm opcodes in func body: N > 65536` during activation. It is a **per-function** limit, not a module-size limit — a 40 KB contract can fail where a 54 KB contract passes, depending on how much code ends up inlined into the entrypoint.

The fix, applied in `kipio_identity_content`, is to route dispatch through a table of function pointers:

```rust
static DISPATCH_TABLE: &[(u32, DispatchHandler)] = &[
    (SEL_REGISTER_CONTENT, KipioIdentityContent::dispatch_register_content),
    // ...
];

#[fallback]
fn fallback(&mut self, calldata: &[u8]) -> ArbResult {
    let table = black_box(DISPATCH_TABLE);
    let handler = table.iter()
        .find(|(s, _)| *s == selector)
        .map(|(_, h)| *h);
    match handler {
        Some(h) => h(self, args),
        None => Err(Vec::new()),
    }
}
```

The lookup produces a `call_indirect` in WASM whose target is a runtime value loaded from a table. Binaryen cannot inline through it because it cannot resolve the concrete function statically. `core::hint::black_box` on the table reference prevents LLVM from constant-folding the lookup back into a static decision tree during codegen.

**Measured impact** (`wasm-objdump -d` over the post-`wasm-opt` binary):

| Approach | `user_entrypoint` ops | ArbOS verdict |
|---|---|---|
| `#[public]` macro | 84646 | activation failed |
| `#[fallback]` with direct match | 92940 | worse |
| `#[fallback]` + decode helpers + direct match | 94164 | worse |
| `#[fallback]` + `call_indirect` table | passes | ✓ |

The rule of thumb for future contracts: if the post-`wasm-opt` `user_entrypoint` exceeds ~30,000 ops (`wasm-objdump -d` count), it is at risk of crossing the ArbOS limit. Re-measure after every significant endpoint addition.

### ABI export under `#[fallback]`

`#[public]` auto-generates a `GenerateAbi` impl used by `cargo stylus export-abi`. With `#[fallback]`, the macro still emits an empty impl and the export prints `interface IKipioIdentityContent {}`. To restore the interface, `kipio_identity_content` defines a shadow type `KipioIdentityContentAbi` in `src/abi/export.rs` that carries a manual `GenerateAbi` implementation, and `bin/export_abi.rs` points `print_from_args` at it.

The shadow type is never instantiated, has no storage fields, and is compiled only under the `export-abi` feature. The production WASM is unaffected.

**Maintenance:** every function declared in `endpoints/mod.rs`'s `sol!` block must also appear in `abi/export.rs`. Adding a new method means updating three places: the `sol!` block, the `DISPATCH_TABLE`, and the manual `GenerateAbi`.

---

## Testing

Three layers, one crate. All tests live in `tests/` and share `tests/common/mod.rs` for fixtures.

| Target | File | Requires network | Purpose |
|---|---|---|---|
| `make test` | `tests/unit.rs`, `tests/e2e.rs` | No | Contract entrypoints via `TestVM`; cross-contract integration between `kipio_account` and `kipio_runtime` |
| `make test-bridge` | `src/bridge/tests/bridge_integration.rs` | No | Semantic tests that validate the ABI ↔ Dafny translation independently of the contracts |
| `make test-fork` | `tests/fork.rs` | Yes (Sepolia RPC) | Reads real on-chain storage via `TestVMBuilder::rpc_url`; marked `#[ignore]` so they do not run by default |

Fork tests are run explicitly:

```bash
cargo test -p kipio_tests --test fork -- --ignored
```

The bridge tests are the semantic safety net. They exercise the conversion layer byte-for-byte and must remain green under every optimisation change. Any modification to `src/bridge/src/lib.rs` or to the generated crate requires re-running them.

---

## Technical Architecture

The repository separates cryptography, state persistence, and authorization into independently deployable contracts. The objective is **crypto agility**: the ability to replace a cryptographic primitive or verification strategy without migrating the state of higher layers.

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
    ┌─────────────────────────┐ ┌──────────────────────┐ ┌────────────────────┐
    │ KipioIdentityContent    │ │ KipioAccount         │ │ KipioRecovery      │
    │ (Anchor + Encrypted     │ │ (Sovereign Aggregate │ │ (Module Evolution) │
    │  Metadata & Irys ptrs)  │ │  Dafny-verified)     │ │                    │
    └──────────┬──────────────┘ └──────────────────────┘ └────────────────────┘
               │ Calls External Verifier
               ▼
    ┌────────────────────┐
    │  P-256 precompile  │
    │  (0x100, native)   │
    └────────────────────┘
```

### 1. Kernel layer (`kipio_core`)

The immutable, minimal state router. It stores no cryptographic logic, zero plaintext, and no secrets. It maintains references to the current operational modules and maps a cryptographic user anchor (`StorageB256`). This guarantees the system survives future algorithmic migrations without structural data updates.

### 2. Identity & content layer (`kipio_identity_content`)

The fused bounded context that handles both the cryptographic identity anchor and the user content vault.

* Anchors a logical actor to a `keccak256(pubkey)` fingerprint. Raw public keys never appear on-chain.
* Implements anti-replay mechanisms through custom EIP-712 structured typed digests.
* Delegates curve-specific execution to **native EVM precompiles**. For P-256, this is the `0x100` precompile defined by RIP-7212 / EIP-7951. No curve arithmetic is executed in WASM; the contract builds the raw 160-byte input and performs a single `staticcall`.
* Manages structural tracking metadata and encrypted Irys pointer locations using immutable tracking indices.
* Tracks access grants through a swap-and-pop grantee index, keeping pagination costs bounded.

The fusion is deliberate: identity and content share the same sovereign address, and unifying them eliminates one cross-contract call per authorization check.

### 3. Account (`kipio_account`)

The sovereign aggregate. Deployed once per identity via CREATE2. Holds the `AuthorizationState`: credentials, credential authorities, sessions, delegations, restrictions, policy effects, and consumed replay keys. Storage is split into a cold path (an ABI-encoded blob) and a hot path (`StorageMap`s for credential statuses and consumed replay keys), so frequent operations touch one slot instead of re-serialising the full state.

The `AuthorizationState` shape and its transition rules are verified in Dafny. The `src/bridge` crate translates between the Solidity ABI and the generated Dafny types.

### 4. Runtime (`kipio_runtime`)

The orchestrator. It does not own state; it reads Account via `IKipioAccount` cross-contract calls, runs the Dafny-derived acceptance and effective-authority logic in memory, and validates execution contexts. Every entrypoint that needs Account state receives the Account address, not the state blob.

### 5. Economics (`kipio_economics`)

The single authority on bootstrap sponsorship. The Gateway queries it before funding a new Account's activation; the decision to sponsor, and the amount allocated, are entirely local to this contract. See `IKipioBootstrapFunding` in the Gateway for the interface.

### 6. Execution Gateway (`kipio_execution_gateway`)

The entry point for EIP-7702 and CREATE2-based account bootstrap. It resolves the identity of the caller, predicts the deterministic account address, deploys and activates the Account contract if needed, and forwards the original payload to the Runtime. Bootstrap funding is sourced from `kipio_economics` when available, and falls back to the caller's `msg.value` otherwise.

### 7. Recovery (`kipio_recovery`)

Secures module evolution and identity recovery. Interacts with the Core router via cross-contract calls to perform hot-swaps under valid multi-signature setups or emergency access thresholds. Also exposes the policy-ledger interface consumed by `kipio_identity_content`'s `rotate_key_from_policy` path.

### 8. Protocol configuration (`kipio_protocol_config`)

The discovery hub. Holds the currently authorized addresses of every operational module, the per-curve verifier mapping, and the whitelist of authorized policy ledgers. Contracts that need to reach a peer module query this contract instead of hard-coding addresses.

---

## Security Engineering

The codebase enforces operational constraints that support low-power mobile clients (MetaMask Mobile, Brave iOS/Android WebViews) while preserving data privacy:

* **No plaintext on-chain.** All credential identifiers are `keccak256` hashes of the raw material. The contract never sees the credential; only its 32-byte fingerprint is persisted as `B256`.
* **Zero debug leaks.** Tracking and debug logs are omitted or reduced to anonymised `B256` hashes.
* **Indexed events for mobile bridges.** Event signatures use NatSpec index patterns (`address indexed user`, `bytes32 indexed contentHash`) so mobile bridges can query state deltas without stalling WebViews.
* **Swap-and-pop deletion.** Storage arrays avoid the "ghost entry" pattern: removing entries triggers structural index cleanups, bounding long-term RPC pagination costs.
* **CEI ordering.** Every mutating handler mutates state before any cross-contract call. If the external call reverts, the whole transaction — including the local mutation — rolls back atomically.
* **Defence in depth.** `code_size` checks reject EOAs and precompiles before they can be stored as config addresses. `Address::ZERO` is validated in every path that receives a target even when the upstream source is trusted.

---

## Production Roadmap

### Phase 1: mitigating the `N+1` RPC latency problem

The system previously relied on a **normalised storage pattern** where asset arrays (`StorageVec<B256>`) returned arrays of plain hashes, forcing frontends to trigger sequential nested RPC calls to resolve each encrypted asset location. The registry has shifted to an **atomic batch retrieval pattern**. By wrapping fields inside a Stylus composite type, clients fetch indices and descriptors in a single round-trip:

```rust
sol! {
    struct EncryptedAssetRecord {
        bytes32 contentHash;
        string encryptedTxId;
        uint64 version;
        bool isPublic;
    }
}

pub fn get_vault_paginated_full(
    &self,
    owner: Address,
    offset: u32,
    limit: u32,
) -> Vec<EncryptedAssetRecord> {
    // Structural pagination returning dense composite objects
}
```

### Phase 2: hybrid capability and ecosystem scaling

1. **Multichain wallets and alternative payment channels**: expanding verification hooks to settle access fees in arbitrary currencies (CCOP, CELO, etc.).
2. **Media-agnostic core anchors**: keeping metadata pointers fully abstract so image, video, document, and agent behaviour payloads can be parsed without core state upgrades.
3. **Hybrid verification pipelines**: running dual-track fuzz testing with `stylus-test` for storage assertions and Forge network state forking for multi-contract integration flows.

---

## Notes

* Contracts are deployed on **Arbitrum Sepolia**.
* The frontend repository expects ABI sync with the latest Stylus compilation (`make abi`).
* The exported Solidity interfaces must pass `forge build` inside `foundry/` before being consumed by any downstream project. See the **Foundry Interface Validation** section.
* Makefile targets must be followed in order (`lock → build → check → test → deploy`) for consistent results.

---

## Research & References

This infrastructure is built upon cryptographic auditing, low-level runtime specifications, and decentralised system models compiled up to the mid-2026 protocol transition window.

### 1. Arbitrum Nitro, ArbOS Runtime Upgrades & Stylus SDK

* **ArbOS 61 "Elara" Core Proposal**: raised the Stylus contract code-size limit from 24 KB to 96 KB compressed, and from 128 KB to 256 KB uncompressed. Enables automatic fragmentation for contracts above 24 KB compressed.
  * [Arbitrum Docs: ArbOS 61 Upgrade Notice](https://docs.arbitrum.io/notices/arbos61-upgrade-notice)
* **ArbOS 60 "Elara" Core Proposal**: structural framework expansion for chunked WebAssembly execution boundaries and code splitting arrays.
  * [Arbitrum Governance Forum: Constitutional AIP ArbOS 60 Elara](https://forum.arbitrum.foundation/t/constitutional-aip-arbos-60-elara/30601)
* **ArbOS 32 "Bianca" & 51 "Dia" specifications**: historical deployment timelines for native execution parameters and host testing models.
  * [Arbitrum Docs: ArbOS 32 Release Notes](https://docs.arbitrum.io/run-arbitrum-node/arbos-releases/arbos32)
  * [Arbitrum Docs: ArbOS 51 Release Notes](https://docs.arbitrum.io/run-arbitrum-node/arbos-releases/arbos51)
* **Stylus SDK v0.10.9**: canonical release used by this workspace. Introduces the `[wasm-opt]` table, contract-client codegen, and workspace-level Stylus configuration.
  * [crates.io: stylus-sdk](https://crates.io/crates/stylus-sdk)
  * [GitHub: OffchainLabs/stylus-sdk-rs Releases](https://github.com/OffchainLabs/stylus-sdk-rs/releases)
* **Stylus call execution engine source**: reference implementation for cross-contract messaging and gas estimation within the Rust execution sandbox.
  * [Docs.rs: stylus_sdk::call module source](https://docs.rs/stylus-sdk/latest/src/stylus_sdk/call/mod.rs.html)
* **Raw call abstraction**: documentation for untyped low-level message-passing mechanisms used to delegate custom data layouts to alternative modules.
  * [Docs.rs: stylus_sdk::call::RawCall](https://docs.rs/stylus-sdk/latest/stylus_sdk/call/struct.RawCall.html)
* **WASM binary size control & pipeline optimisation**: canonical compiler tuning mechanics (`opt-level = "z"`, `lto = true`, `panic = "abort"`) to respect host limits.
  * [Arbitrum Docs: Optimizing Stylus Binaries](https://docs.arbitrum.io/stylus/how-tos/optimizing-binaries)
  * [Arbitrum Docs: Stylus Contract Fundamentals & Static Calling](https://docs.arbitrum.io/stylus/fundamentals/contracts)
  * [GitHub: OffchainLabs/cargo-stylus](https://github.com/OffchainLabs/stylus-sdk-rs)
* **`wasm32v1-none` target specification**: official Rust documentation explaining that `-Ctarget-cpu=mvp` is the only reliable way to disable all post-MVP WebAssembly proposals.
  * [Rust Platform Support: wasm32v1-none](https://doc.rust-lang.org/rustc/platform-support/wasm32v1-none.html)
  * [Rust compiler-team issue #791: wasm32v1-none](https://github.com/rust-lang/compiler-team/issues/791)

### 2. Passkey Authentication & Low-Level Curve Precompiles

* **EIP-7951**: the authoritative successor to RIP-7212 governing the native `0x100` execution context and big-endian inputs for `secp256r1` biometric verifications.
  * [Ethereum Improvement Proposals: EIP-7951](https://eips.ethereum.org/EIPS/eip-7951)
  * [Ethereum Magicians: EIP-7951 Debate & Implementation](https://ethereum-magicians.org/t/eip-7951-precompile-for-secp256r1-curve-support/24360)
* **RIP-7212 layer-2 architecture**: original rollup optimisation layout enabling mobile hardware enclave validation constraints across optimistic networks.
  * [EIP.tools: RIP-7212 Rollup Blueprint](https://eip.tools/rip/7212)
  * [Alchemy Ledger: Deep Dive into RIP-7212 Rollup Primitives](https://www.alchemy.com/blog/what-is-rip-7212)

### 3. Proxy Re-Encryption (PRE) & Mathematical Tooling

* **The Umbral scheme**: threshold proxy re-encryption framework defining cryptographic key routing delegation, `kfrags`, `cfrags`, and split-capsule tokens.
  * [NuCypher Network: Umbral Cryptographic Whitepaper](https://github.com/nucypher/umbral-doc/blob/master/umbral-doc.pdf)
* **Evolution of Umbral implementation**: historical migration notes regarding pure Rust cryptography refactoring and decentralised delegation mechanics.
  * [NuCypher Medium: Unveiling Umbral and Cryptographic Transitions](https://medium.com/nucypher/unveiling-umbral-3d9d4423cd71)
* **Umbral Rust crates**: native deterministic processing and algebraic verification modules deployable inside WebAssembly runtimes.
  * [Docs.rs: umbral-rs](https://docs.rs/umbral-rs/latest/umbral_rs/)
  * [Docs.rs: umbral-pre](https://docs.rs/umbral-pre/latest/umbral_pre/)
* **Algebraic limits on secp256k1 execution**: rationale behind software curve mathematics due to native execution boundaries and the absence of general-purpose `ECADD` / `ECMUL` precompiles.
  * [GitHub Issue: EIPs #603 ECADD/ECMUL](https://github.com/ethereum/EIPs/issues/603)
* **RustCrypto engine ecosystem**: native variable tracking structures used for compiling cryptographic operations inside safe sandboxes.
  * [crates.io: k256](https://crates.io/crates/k256)
  * [crates.io: p256](https://crates.io/crates/p256)

### 4. Distributed Architecture & Encrypted Storage Integrations

* **WNFS (Web Native File System)**: modular structure layout addressing secure private capability graphs, self-sovereign cryptographic trees, and nested index trees.
  * [GitHub: wnfs-wg/rs-wnfs](https://github.com/wnfs-wg/rs-wnfs)
* **UCAN (User Controlled Authorization Networks)**: distributed authority delegation framework establishing trust chain patterns and cryptographically secure user-space capability certificates without reliance on centralised identity servers.
  * [GitHub: ucan-wg/spec](https://github.com/ucan-wg/spec)
* **Irys invariant storage pipelines**: permanent data tracking frameworks providing continuous accessibility bounds and immutable encrypted content indices.
  * [Irys Network: Developer Documentation](https://docs.irys.xyz)
  * [GitHub: ArweaveTeam/arweave](https://github.com/ArweaveTeam/arweave)
* **Threshold Network & coordination infrastructure**: decentralised node access management models guiding token incentives, slashing mechanisms, multi-party computation, and proxy coordination logic.
  * [GitHub: threshold-network](https://github.com/threshold-network)
  * [GitHub: nucypher](https://github.com/nucypher)
  * [GitHub: LIT-Protocol](https://github.com/LIT-Protocol)

# Kipio Contracts

Core smart contracts for the Kipio decentralized sovereign agent infrastructure, powered by **Arbitrum Stylus (SDK v0.10.9)** and **Rust nightly**.

This workspace contains the contracts deployed to Arbitrum Sepolia, plus the tooling to build, test, verify, and deploy them. It is a multi-crate workspace: the Stylus contracts live under `src/`, the ABI ↔ Dafny translation layer lives under `src/bridge/`, and the test suite lives under `tests/`.

The architecture is deliberately modular. Cryptographic primitives, state persistence, and authorization logic are separated so that the system can survive future algorithmic migrations without rewriting stored data.

The user experience target is **one signature, one transaction**. A user signs a single intent; the Execution Gateway routes it to the Runtime, and the Runtime orchestrates every downstream call — account reads, economic settlement, target module dispatch — inside a single atomic transaction. If any step fails, the entire flow reverts and the user pays nothing. The orchestration pattern is documented under **EIP-2771** in the Security Engineering section.

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

* **Python 3** with the `brotli` module (or the `brotli` CLI): required by the fragmented init code tooling under `scripts/`. `make install-brotli` attempts both `apt` and `pip --user` automatically.

* **`curl`**: used by `make probe-rpc` to test RPC endpoints.

* **Docker** and **`git`**: required only for the local nitro-devnode workflow (see **Local Development with nitro-devnode**).

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
├── scripts/
│   ├── fix-tuple-abi.sh                    ABI post-processor (bug 1)
│   ├── fix-abi-structs.sh                  ABI post-processor (bug 2)
│   ├── fix-abi-data-locations.sh           ABI post-processor (bug 3)
│   ├── abi-structs-companion.sol           struct source for bug 2
│   ├── stylus-deploy-manifest.sh           parses deploy logs into JSON
│   ├── find-working-endpoint.sh            endpoint cache with fallback
│   ├── inject-gateway-constants.sh         writes runtime/economics/recovery into constants.rs
│   ├── decode_stylus_calldata.py           extracts init code from StylusDeployer calldata
│   ├── decode_fragment_table.py            parses the 64-byte fragment table
│   └── find_fragment_addresses.py          locates addresses inside a binary blob
├── src/
│   ├── bridge/                     ABI ↔ Dafny translation layer (local crate)
│   ├── kipio_protocol_config/      module directory + curve registry
│   ├── kipio_identity_content/     identity anchor + content vault
│   ├── kipio_account/              sovereign aggregate (Dafny-verified)
│   ├── kipio_recovery/             guardian-driven recovery singleton
│   ├── kipio_runtime/              orchestrator + Dafny evaluator
│   ├── kipio_economics/            settlement + treasury + credit
│   └── kipio_execution_gateway/    EIP-7702 + CREATE2 bootstrap
│       ├── build.rs                assembles the fragmented root init code
│       ├── fragments.toml          fragment addresses + decompressed size
│       └── ...
├── deployments/            per-run deployment records (addresses + manifests)
├── .check-reports/         per-contract check logs, ABI reports, endpoint cache
├── .reverse-engineering/   artifacts from the fragmented init code investigation
└── tests/                  integration suite (unit / e2e / fork)
```

`src/kipio_identity_content` is the result of fusing the former `kipio_auth` (Identity Anchor) and `kipio_access` / `kipio_registry_content` (Content vault) crates into a single bounded context. The fusion removes a cross-call per signature check, unifies the cryptographic-identity and content-vault domains under one storage layout, and keeps the runtime architecture flat. Identity and content share the same sovereign address.

`src/kipio_recovery` is a standalone singleton, consumed by both `kipio_account` (through `execute_recovery`) and `kipio_runtime` (through the identity-content rotation flow). A fusion attempt into `kipio_account` was reverted: the recovery request ledger benefits from a shared, addressable service with its own audit trail, and separating the two keeps each WASM comfortably under the ArbOS uncompressed activation limit.

`src/bridge` is a workspace member but **not** a contract (no `#[entrypoint]`). It translates between the Solidity ABI consumed on-chain and the Dafny-generated types that carry the Authorization State. `tests/` is a workspace member dedicated to integration tests.

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

The `Makefile` orchestrates the whole workspace. Every target supports both a workspace-wide mode (default) and a single-contract mode via `contract=<name>`. Endpoint resolution, deployment phasing, and recovery are covered in **Deployment Architecture** below.

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

Each contract is compiled to `wasm32-unknown-unknown`, optimised with `wasm-opt 132`, and then hashed to produce its `project metadata hash`. Contracts with declared features (currently only `kipio_execution_gateway` with `production_build`) automatically receive the `--features` flag.

### 3. Export Solidity ABIs

```bash
make abi                                  # all contracts
make abi contract=kipio_identity_content  # single contract
```

Interfaces land in `foundry/src/interfaces/IKipio<CamelCase>.sol`. The naming convention is derived automatically from the crate name.

Three post-processing scripts run after each export, in order: `fix-tuple-abi.sh`, `fix-abi-structs.sh`, `fix-abi-data-locations.sh`. They patch three separate Stylus SDK 0.10.9 export bugs. See **Known Tooling Bugs** below.

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

`make check` first resolves a working endpoint (see **Endpoint Resolution**), then runs each contract with `--verbose` against it. The full trace (deployment hash inputs, project metadata hash, wasm-opt version and flags, compressed and uncompressed size, fragment count) is printed to the terminal and saved verbatim to `.check-reports/<contract>.log`. A summary table is printed at the end and persisted to `.check-reports/sizes.tsv`.

Failures do not abort the loop. All failing contracts are collected and reported at the end, and the target exits non-zero.

### 6. Deploy

```bash
make deploy contract=kipio_identity_content  # single contract
make deploy-full                             # full 4-phase deploy
make deploy-resume                           # resume a failed phase-1
make register-modules                        # re-run phase 2 (idempotent)
make deploy-gateway                          # re-run phase 3 + 4 (idempotent)
```

See **Deployment Architecture** for the phase breakdown and the rationale.

### 7. Verify a deployed contract

```bash
make verify contract=kipio_account tx=0x<deployment-tx-hash>
```

Recompiles from source and confirms the on-chain bytecode matches. The toolchain, `wasm-opt` version, and all flags are pinned, so the check is deterministic.

### 8. Manage the contract cache

```bash
make cache-suggest addr=0x...              # suggested minimum bid
make cache-bid     addr=0x... bid=...      # submit a bid
make cache-status  addr=0x...              # read cached status
```

ArbOS maintains a contract cache (CacheManager at `0x0000...0070`). Cached contracts save roughly **8,500 gas per call**. Entry is won by bidding on an auction; bids decay over time and must be renewed. Use `cache suggest-bid` as the floor for `cache-bid`.

### 9. Maintenance

```bash
make clean                   # remove target/ and .check-reports/
make clean-deployments       # remove all deployment records
make clean-abi               # remove generated Solidity interfaces
make clean-endpoint-cache    # force the next check/deploy to re-probe endpoints
make reverse-eng-clean       # remove .reverse-engineering/
```

### 10. Recovery from Docker root-ownership

`cargo stylus deploy` runs the compile step inside a Docker container as `root`. Because the container bind-mounts `contracts/target/`, files written during the build end up owned by `root:root` on the host. Subsequent local commands (`make build`, `make abi`, `make test`) then fail with `Permission denied (os error 13)` when they try to touch the same files.

Two targets recover from this:

```bash
make fix-perms   # reclaims ownership of target/ (sudo chown)
make nuke        # hard reset: removes target/, stops and removes stylus Docker containers, deletes cargo-stylus-base images
```

`make check` is unaffected because it uses the release profile, which writes to a subtree the deploy container never touched.

Every `deploy` and `deploy-full` invocation prints a closing note reminding you to run `make fix-perms` before the next local build.

---

## Local Development with nitro-devnode

When public RPC endpoints reject Stylus activation simulations (`stylus activations not allowed for this request`, `execution reverted, data: "0x"`) or rate-limit aggressively, the fastest way to keep iterating is to run a local Arbitrum chain using **nitro-devnode**, the official Offchain Labs development node.

`nitro-devnode` is a Docker-packaged Nitro node configured to run as a standalone chain. It uses the same ArbOS rules, the same Stylus VM, the same compression pipeline, the same precompiles, and the same opcode limits as the production chain. It is not a fork and not a mock: it is a real chain running locally.

### What it provides

* **Fast iteration.** `cargo stylus check` and `cargo stylus deploy` complete in seconds, not minutes.
* **No rate limits, no API keys, no endpoint churn.** The node answers on `http://localhost:8547`.
* **A pre-funded dev account** that is also the chain owner.
* **Full ArbOS 61 support** (fragmentation, 96 KB compressed / 256 KB uncompressed limits) after the ArbOS upgrade step documented below.
* **Ephemeral state.** Stopping the container resets the chain to genesis. Every restart is a clean environment — no migration debt, no stale state, no partial deployments to clean up.

### Requirements

* **Docker** — required to run the node image.
* **`git`** — to clone the devnode repository.
* **`cast`** (Foundry) — to interact with the node and schedule the ArbOS upgrade.
* **`jq`** — used by the devnode's setup script.
* **~500 MB of free disk** for the Docker image.

### Installation

```bash
cd ~
git clone https://github.com/OffchainLabs/nitro-devnode.git
cd nitro-devnode
```

### Choosing a Nitro version

The devnode respects the `NITRO_NODE_VERSION` environment variable. If omitted, it defaults to an older image that boots at ArbOS 40 (no fragmentation support). Always pin a modern version explicitly:

```bash
NITRO_NODE_VERSION=v3.12.1-70fa99a ./run-dev-node.sh
```

`v3.12.1` is the latest stable release recommended by Offchain Labs for all Arbitrum chain operators as of October 2026. `v3.11.5` is a supported alternative on the 3.11 maintenance branch. Both are compatible with Arbitrum Sepolia's Glamsterdam activation and with ArbOS 61.

### CRITICAL: schedule the ArbOS 61 upgrade

**The devnode boots at ArbOS 59 by default, even with a modern Nitro image.** ArbOS 60 is the minimum version that supports fragmented Stylus contracts (contracts whose compressed WASM exceeds 24 KB). Without the upgrade, `cargo stylus check` on `kipio_identity_content`, `kipio_account`, `kipio_runtime`, and `kipio_economics` will fail with `execution reverted, data: "0x"` — a revert with no message that does not obviously point at ArbOS.

After the node reports `Nitro node is running!` and the setup script finishes, schedule the upgrade by calling the `ArbOwner` precompile at `0x...0070`:

```bash
cast send -r http://localhost:8547 \
  --private-key 0xb6b15c8cb491557369f3c7d2c287b053eb229daa9c22138887752191c9520659 \
  0x0000000000000000000000000000000000000070 \
  'scheduleArbOSUpgrade(uint64,uint64)' 61 0
```

The first argument is the **ArbOS version number** (61), not the value returned by `ArbSys.arbOSVersion()`. Passing 115 (the encoded version) is silently ignored.

Verify the upgrade landed:

```bash
cast call -r http://localhost:8547 \
  0x0000000000000000000000000000000000000064 "arbOSVersion()" | cast --to-dec
# Should print 116 (61 + 55) after the upgrade
```

Then run the check:

```bash
cd ~/projects/vaultchain-sovereign-agent/contracts
make check
```

All seven contracts should pass.

### The pre-funded dev account

The devnode ships with a single account that holds unlimited ETH on the local chain. It also acts as chain owner, so it can call admin precompiles (`ArbOwner`, `ArbWasm`, `ArbInfo`) without additional setup.

| Field | Value |
|---|---|
| Address | `0x3f1Eae7D46d88F08fc2F8ed27FCb2AB183EB2d0E` |
| Private key | `0xb6b15c8cb491557369f3c7d2c287b053eb229daa9c22138887752191c9520659` |

These credentials are public and documented by Offchain Labs. **Never use them on a real network.** They are exclusive to the local devnode.

### Configuring the Makefile to target the devnode

The Makefile resolves every endpoint through `ENDPOINT_SEPOLIA` and `ENDPOINT_SEPOLIA_ALL`. To redirect all targets to the local node, export overrides in your shell session:

```bash
export ENDPOINT_SEPOLIA="http://localhost:8547"
export ENDPOINT_SEPOLIA_ALL="http://localhost:8547"
export PRIVATE_KEY="0xb6b15c8cb491557369f3c7d2c287b053eb229daa9c22138887752191c9520659"
export MAX_FEE_PER_GAS_GWEI=10
```

Then every Makefile target — `make check`, `make deploy`, `make deploy-full`, `make register-modules`, `make deploy-gateway` — operates against the local chain without further changes. The endpoint cache in `.check-reports/.working-endpoint` is updated to `http://localhost:8547` on the first run.

Alternatively, pass overrides inline:

```bash
make check ENDPOINT_SEPOLIA="http://localhost:8547" \
           ENDPOINT_SEPOLIA_ALL="http://localhost:8547"
```

### Interaction with `fragments.toml`

The Gateway embeds the fragment addresses of `kipio_account` as a compile-time constant (`src/kipio_execution_gateway/fragments.toml`). On the devnode, every `kipio_account` redeploy produces new fragment addresses, so `fragments.toml` must be updated before `make deploy-gateway` is run. The reverse-engineering tooling (`make reverse-eng-*`) works against the devnode unchanged.

### When to use the devnode vs. Sepolia

| Scenario | Use |
|---|---|
| Iterating on a contract change | **Devnode.** Seconds per deploy, no gas cost, no endpoint rejection. |
| Testing before pushing to a public testnet | **Devnode.** Catch compilation and activation errors locally. |
| Reproducible verification (`make verify`) | **Sepolia.** Reproducibility is only meaningful against a real network. |
| Frontend integration testing | **Sepolia.** Public chain ID, persistent state, Arbiscan links. |
| Debugging the P256 precompile path | **Devnode.** `0x100` is present in ArbOS 61+, and the devnode shares the ArbOS version. |
| Multi-user flows with real accounts | **Sepolia.** The devnode has a single pre-funded account. |

### Realism

The devnode is not a mock: it is the same Nitro node binary, running the same ArbOS version, executing the same Stylus VM. Every check that passes locally corresponds to a check that would pass on Arbitrum Sepolia or Arbitrum One. The differences are:

1. **Chain ID** — `412346` locally, `421614` on Arbitrum Sepolia.
2. **Persistence** — none locally; the chain resets on restart.
3. **Block production** — the devnode produces blocks on demand, so transaction confirmation is instant.
4. **Accounts** — a single pre-funded dev account, no faucet.

Because of (1), any contract that binds a domain separator or a chain ID at construction or first use will produce different values on the devnode than on Sepolia. The Kipio contracts derive most digests from `block.chainid`, so EIP-712 signatures must be re-signed when switching networks.

---

## Known Tooling Bugs

The following bugs are present in **Stylus SDK 0.10.9** and its `cargo stylus export-abi` subcommand. They affect **only** the Solidity interface output, never the WASM bytecode or on-chain behaviour. Each is patched by a post-processing script that runs automatically as part of `make abi`.

### Bug 1 — Inline tuples in external function signatures

**Symptom.** The exporter emits tuple parameters inline:

```solidity
function dispatch(
    (address, address, uint256, bytes calldata) envelope
) external;
```

Solidity rejects this with `Error (3546): Expected type name` or similar. Inline tuple syntax is not valid in Solidity function signatures.

**Cause.** `cargo stylus export-abi` does not synthesise named struct declarations for tuple-typed parameters. It assumes the ABI consumer can infer the shape from the encoding, which is true at the ABI level but not at the Solidity source level.

**Known upstream.** `stylus-sdk-rs` issue #368; OpenZeppelin audit finding M-17.

**Fix.** `scripts/fix-tuple-abi.sh` rewrites each inline tuple into a named struct declaration at the top of the interface, and replaces the inline form in the function signature with the struct name.

### Bug 2 — Missing input-only struct declarations

**Symptom.** The exported interface refers to a struct type that is never declared:

```solidity
function registerTransitiveDelegation(
    DelegationAbi delegation,
    IdentityAbi[] identities
) external;
```

`solc` rejects this with `Error (7920): Identifier not found or not unique`.

**Cause.** The exporter only emits struct declarations for types that appear in **returns** or in **storage-backed** fields. A struct used only as an input parameter is silently dropped.

**Fix.** `scripts/fix-abi-structs.sh` computes the transitive closure of all struct types referenced by the exported functions, resolves them against `scripts/abi-structs-companion.sol`, and injects the missing declarations in dependency order.

### Bug 3 — Missing data locations on external parameters

**Symptom.** The exported interface omits the `calldata` or `memory` keyword on singular reference types:

```solidity
function registerCredential(CredentialAbi credential) external;
```

`solc` rejects this with `Error (6651): Data location must be "calldata", "memory" or "storage" for parameter in function, but none was given`.

**Cause.** The exporter correctly emits data locations on primitive arrays (`bytes[]`, `uint256[]`) but drops them on singular struct, `bytes`, and `string` parameters.

**Fix.** `scripts/fix-abi-data-locations.sh` adds `calldata` to every reference-type parameter in an external function signature that is missing a data location.

### Rule

Never ship an exported `.sol` interface to a downstream consumer without running `forge build` on it first. The three scripts are idempotent and can be re-run safely.

---

## Fragmented Init Code

This section documents a project-specific discovery that is **not** covered by any public Stylus SDK documentation. It is the result of an empirical reverse-engineering effort.

### The problem

Arbitrum Stylus fragments any contract whose compressed WASM exceeds **24 KB**. `kipio_account` compresses to ~57 KB → **3 fragments + 1 root contract**. `cargo stylus deploy` handles fragmentation automatically: it deploys the 3 fragments in separate transactions, then deploys a root contract that references them by address, then activates the root.

The Execution Gateway needs the **root contract's init code** as a compile-time constant, for two purposes:

1. Predict the CREATE2 address of a user's account (which is the hash of the init code).
2. Deploy the account with `RawDeploy` (which needs the raw init code bytes).

`cargo stylus get-initcode` cannot produce this artifact for fragmented contracts:

```
error: fragmented contracts not currently supported for initcode retrieval
```

The Gateway was therefore blocked. Without the init code, no account can be created. Several alternatives were considered:

- **Reduce `kipio_account` to < 24 KB compressed** so it does not fragment. This would require restructuring the contract into modules or sub-contracts. It was rejected: `kipio_account` is already heavily optimised (57 KB is the floor for the current endpoint surface), and any structural change would break the Dafny-verified bridge.
- **Reconstruct the init code manually**, i.e. replicate the prelude and compression pipeline byte-for-byte. Rejected: fragile, dependent on Brotli version, and irreproducible across toolchains.
- **Delegate to the on-chain `StylusDeployer`**. Rejected: the `StylusDeployer` does not fragment either. It deploys a single bytecode blob, so it would only deploy the root without its fragments.
- **Move the deployment client-side** (SDK calls `cargo stylus deploy`). Rejected: it defeats the whole point of the Gateway (single-transaction bootstrap for non-crypto users) and requires the user to sign multiple transactions.

**None of these paths were explored.** The chosen path was to reverse-engineer the fragmented init code format.

### The reverse-engineering experiment

The experiment is fully scripted under `make reverse-eng-*`. Its steps:

1. Deploy `kipio_account` to Sepolia via `make reverse-eng-deploy`.
2. Fetch the root deployment transaction and ABI-decode its calldata with `scripts/decode_stylus_calldata.py`. The init code is not carried directly in the tx input: it is the first `bytes` parameter of the call to the `StylusDeployer` (`0xcEcba2F1DC234f70Dd89F2041029807F8D03A990`).
3. Parse the resulting init code with `make reverse-eng-structure`. Dump the prelude, version byte, and Stylus header.
4. Extract the payload (everything after the 4-byte header) with `make reverse-eng-extract-payload`.
5. Parse the payload with `make reverse-eng-decode-payload`, which uses `scripts/decode_fragment_table.py`.

### Confirmed layout

Byte-for-byte verified against a real Sepolia deploy (2026-10-01):

```
[0..42)     EVM prelude (42 bytes)
              ├─ 0x7f PUSH32
              ├─ <runtime_len u32 BE, left-padded to 32 bytes>
              ├─ 0x80 DUP1
              ├─ 0x60 0x2b PUSH1 0x2b (CODECOPY src)
              ├─ 0x60 0x00 PUSH1 0x00 (CODECOPY dst)
              ├─ 0x39 CODECOPY
              ├─ 0x60 0x00 PUSH1 0x00 (RETURN offset)
              └─ 0xf3 RETURN
[42]        Stylus init code version byte (0x00, independent of fragmentation)
[43..47)    Stylus header: 0xEF 0xF0 0x02 0x00 (fragmented)
[47..51)    decompressed WASM size (u32 big-endian)
[51..71)    fragment 0 address (20 bytes raw)
[71..91)    fragment 1 address (20 bytes raw)
[91..111)   fragment 2 address (20 bytes raw)
```

The **runtime length** field in the prelude (the `0x44` at byte 28..32) equals `4 + 4 + N × 20 = 68` for 3 fragments — it is the length of the runtime code that the EVM will `RETURN`, not of the whole init code.

The init code is 111 bytes for `kipio_account`. The actual WASM code lives inside the 3 fragment contracts, referenced by address from the root. **The root is a tiny manifest contract.**

### The solution

`src/kipio_execution_gateway/build.rs` assembles the root init code at compile time from a fixed template plus the fragment addresses:

1. Read `fragments.toml` (a sibling config file) for the decompressed size and the 3 fragment addresses.
2. Build the prelude, the version byte, the header, the size, and the addresses into a single 111-byte buffer.
3. Write the buffer to `$OUT_DIR/kipio_account_init.bin`.

`src/internal/deploy.rs` reads the buffer via `include_bytes!` under the `production_build` feature. `RawDeploy::deploy` and the CREATE2 prediction both consume it directly. **No changes to `deploy.rs` or `bootstrap.rs` were required** beyond the compile-time constant that was already there.

The `production_build` feature is auto-enabled for `kipio_execution_gateway` by the Makefile (see `FEATURES_kipio_execution_gateway`). It is off by default, so unit tests build without the WASM and without a real deployment.

The `fragments.toml` file is committed to the repository. It contains the on-chain fragment addresses and the decompressed size for the current version of `kipio_account`. It must be regenerated after every `kipio_account` redeploy. `build.rs` is included in the project hash, so a change to `fragments.toml` invalidates the reproducibility hash, and any divergence is caught by `cargo stylus verify`.

### Regenerating after a `kipio_account` redeploy

1. Deploy the new `kipio_account` with `cargo stylus deploy` (fragmented automatically).
2. From the deploy log or Arbiscan, take the 3 fragment creation transaction hashes and the decompressed size (`wasm size: NNNN bytes`).
3. Update `fragments.toml` with the new values.
4. Run `make build contract=kipio_execution_gateway`. The Gateway now embeds the new init code.
5. Run `make deploy-gateway` to deploy the new Gateway and register it in `protocol_config`.

### When to keep the same Gateway

The Gateway's init code depends on `kipio_account`'s bytecode. If `kipio_account` does not change, the Gateway does not need to change. If it changes, the Gateway must be redeployed to produce accounts with the new bytecode. Existing accounts keep their original bytecode and their original address; the new Gateway produces new addresses for new users.

---

## Deployment Architecture

The deployment is structured in **four phases**, with an endpoint resolution step that runs once per invocation.

### Endpoint resolution

Public Sepolia RPCs frequently reject Stylus activation simulations with:

```
stylus activations not allowed for this request
```

This is a rate-limiter / feature-flag policy, not a contract bug. `scripts/find-working-endpoint.sh` probes the endpoint list in order and caches the first one that accepts the simulation in `.check-reports/.working-endpoint`. Subsequent invocations try the cached endpoint first and only re-probe when it stops working.

```bash
make print-working-endpoint    # show the cached endpoint
make clean-endpoint-cache      # force a fresh probe
```

Overriding the whole list is possible via `ENDPOINT_SEPOLIA_ALL`:

```bash
make check ENDPOINT_SEPOLIA_ALL='https://arb-sepolia.g.alchemy.com/v2/KEY'
```

When public RPCs are unavailable or rejection is total, switch to the local devnode (see **Local Development with nitro-devnode**). The same environment variables apply.

### Phase 1 — Five singletons

Deployed in dependency order:

| # | Contract | Constructor args |
|---|---|---|
| 1 | `kipio_protocol_config` | none |
| 2 | `kipio_runtime` | protocol_config address |
| 3 | `kipio_recovery` | runtime address |
| 4 | `kipio_economics` | protocol_config + CRE forwarder + CRE workflow id |
| 5 | `kipio_identity_content` | storage + query + access providers + expected workflow id |

Each phase-1 deploy appends its address to `deployments/<ts>/addresses.json` and its manifest to `deployments/<ts>/manifest.json`. If the run fails partway, `make deploy-resume` continues from the last incomplete contract.

### Phase 2 — Module registration

The five addresses are registered in `kipio_protocol_config` via four `cast send` calls (`setRuntimeAddress`, `setRecoveryAddress`, `setEconomicsAddress`, `setIdentityContentAddress`). Each emits a `ModuleAddressUpdated` event with the module id in `topic[1]`:

| module_id | Contract |
|---|---|
| 0 | runtime |
| 1 | economics |
| 2 | identity_content |
| 3 | recovery |
| 4 | execution_gateway |

This phase is idempotent. `make register-modules` re-runs it against the latest deployment.

### Phase 3 — Gateway inject + rebuild + deploy

The Gateway hardcodes the runtime, economics, and recovery addresses as compile-time constants (see **Versioning Model** for the full rationale). The pipeline is:

1. `scripts/inject-gateway-constants.sh` reads the three addresses from the latest `addresses.json` and rewrites them in `src/kipio_execution_gateway/src/config/constants.rs`.
2. `cargo stylus build --features production_build` recompiles the Gateway. The `build.rs` regenerates the init code from `fragments.toml` in the same step.
3. `cargo stylus deploy` deploys the Gateway.

`constants.rs` is committed to the repository with placeholder zeros (`Address::new([0u8; 20])`). It is **not** committed with real addresses: the injection happens at deploy time, per network. This keeps the source tree network-agnostic.

### Phase 4 — Gateway registration

The Gateway address is registered in `kipio_protocol_config` via `setExecutionGatewayAddress`.

### Recovery targets

If any phase fails, the recovery path is granular:

```bash
make deploy-resume     # resume phase 1 (idempotent per-contract)
make register-modules  # re-run phase 2 (idempotent)
make deploy-gateway    # re-run phase 3 + 4 (idempotent)
```

`deploy-full` runs all four phases in a single invocation. It is the recommended entry point for a clean deployment.

### A note on `cast send` vs `cargo stylus deploy` flags

These are two different CLIs with two different flag names for the same concept:

| CLI | Flag for max fee per gas |
|---|---|
| `cargo stylus deploy` | `--max-fee-per-gas-gwei=1` |
| `cast send` | `--gas-price 1gwei` |

They are not interchangeable. Passing `--max-fee-per-gas-gwei` to `cast send` fails with `error: unexpected argument '--max-fee-per-gas-gwei' found`.

---

## Versioning Model

The protocol has a **two-layer versioning scheme**: an on-chain registry that resolves the *current* version of each module, and a set of immutable contracts whose coupling is determined at deployment time. This section documents how the two layers relate and what they imply for upgrades.

### The registry

`kipio_protocol_config` is the on-chain registry. It holds the current address of every operational module and emits a `ModuleAddressUpdated` event on every change. The module ids are documented in **Phase 2 — Module registration** above.

The registry is a **directory**, not a proxy. It has no delegatecall, no storage collision risk, and no admin surface beyond the owner-gated setters. Contracts that read through it resolve the current address on each call, so a registry update reaches them without a redeploy.

### The Gateway exception

The Execution Gateway is **not** a consumer of the registry. It hardcodes `KIPIO_RUNTIME`, `KIPIO_ECONOMICS`, and `KIPIO_RECOVERY` as compile-time constants in `src/config/constants.rs`. This is a correctness requirement, not a convenience:

- Every account created by Gateway vN stores `(runtime_vN, recovery_vN)` in its own storage at construction time.
- Account mutators reject calls from any address other than the stored `runtime_vN`.
- If the Gateway resolved `runtime` from the registry at bootstrap time, an account created with `runtime_vN+1` would be unusable until `runtime_vN+1` is deployed, and an account created with `runtime_vN` would reject calls from `runtime_vN+1` even though the registry says `runtime_vN+1` is current.
- Hardcoding freezes the coupling at deployment time. The Gateway is a bootstrap primitive whose inputs are fixed for its lifetime, matching the "one signature, one transaction, no surprises" objective.

### The version diagram

```
      ┌─────────────────────────────────────────────────────┐
      │         kipio_protocol_config (immutable)           │
      │                                                     │
      │  slot[0] runtime_vN     slot[3] recovery_vN         │
      │  slot[1] economics_vN   slot[4] gateway_vN          │
      │  slot[2] identity_vN                                │
      └─────────────────────────────────────────────────────┘
                          ▲
                          │ set_execution_gateway_address(GW_vN+1)
                          │ → ModuleAddressUpdated(4, GW_vN, GW_vN+1)
                          │
          ┌───────────────┴───────────────┐
          │                               │
   ┌──────┴──────┐                 ┌──────┴──────┐
   │ Gateway vN  │                 │Gateway vN+1 │
   │             │                 │             │
   │ hardcodes:  │                 │ hardcodes:  │
   │  runtime_vN │                 │runtime_vN+1 │
   │  econ_vN    │                 │ econ_vN+1   │
   │  recovery_vN│                 │recovery_vN+1│
   └──────┬──────┘                 └──────┬──────┘
          │ CREATE2(salt, init_code_vN)   │ CREATE2(salt, init_code_vN+1)
          │                               │
          ▼                               ▼
   ┌─────────────┐                 ┌─────────────┐
   │ Account_vN  │                 │Account_vN+1 │
   │ storage:    │                 │ storage:    │
   │  runtime_vN │                 │runtime_vN+1 │
   │  recovery_vN│                 │recovery_vN+1│
   └─────────────┘                 └─────────────┘
   (existing users)                (new users)
```

### Rules

1. **Every Gateway version is coupled to a triple** `(runtime, economics, recovery)`. This triple is fixed at compile time.
2. **Every Account embeds the same triple** (or at least the runtime and recovery it will accept calls from) in its own storage at construction time.
3. **`protocol_config` can point to `Gateway_vN+1` while `Gateway_vN` remains live.** The registry update is a soft deprecation of the old Gateway for new users; it does not invalidate existing accounts.
4. **Existing accounts continue to accept calls from `runtime_vN`** (which stays deployed) regardless of what the registry says.
5. **New accounts accept calls from `runtime_vN+1`.**
6. **Changing any of the three requires: deploy new module, deploy new Gateway, register Gateway in `protocol_config`.** See **Upgrade Procedures** below.
7. **`kipio_account` has no version field.** The version is implicit in which Gateway created the account.
8. **`kipio_identity_content` providers are not part of the versioning model.** They live in the contract's own storage and can be updated in place via the owner-gated setters. See **Upgrade Procedures**.

### What is versioned vs. what is a parameter

| Concept | Lives in | Updated by | Redeploy needed |
|---|---|---|---|
| `runtime`, `economics`, `recovery` addresses | Gateway `constants.rs` (compile-time) | Redeploy Gateway + `set_execution_gateway_address` | Yes (Gateway only) |
| `identity_content` address | Registry | `set_identity_content_address` | No |
| Gateway address | Registry | `set_execution_gateway_address` | No (for the registry) |
| `kipio_account` bytecode | Gateway `fragments.toml` (compile-time) | Redeploy Gateway with new fragments | Yes (Gateway only) |
| `kipio_identity_content` provider addresses | Contract storage | Owner-gated setters | No |
| `kipio_economics` CRE workflow id | Contract storage | `updateCreWorkflowId` | No |

---

## Upgrade Procedures

This section documents the concrete steps for each type of upgrade. All commands are run from the workspace root.

### Case 1 — Only `kipio_identity_content` providers change

The provider slots (`storage_provider`, `query_provider`, `access_provider`, `zk_verifier`) live in `kipio_identity_content`'s own storage. They are not part of the versioning model and can be updated in place.

**Scenario:** Irys is live and you want to set the real `storage_provider`. Or LIT Protocol replaces TACo in the `access_provider` slot.

**Steps:**

```bash
IDENTITY=<address from deployments/latest/addresses.json>
NEW_PROVIDER=0x...

# Pick the right setter for the slot
cast send $IDENTITY "setStorageProvider(address)" $NEW_PROVIDER \
  --rpc-url https://arbitrum-sepolia-rpc.publicnode.com \
  --private-key $PRIVATE_KEY \
  --gas-price 1gwei
# Or: setQueryProvider, setAccessProvider, setZkVerifier, setExpectedWorkflowId
```

**Events emitted:** `ProviderUpdated(providerType, oldProvider, newProvider)` for the three provider slots, `ZkVerifierUpdated` for the verifier, `WorkflowIdUpdated` for the workflow id.

**Cost:** ~50k gas per call. No redeploys, no Gateway change, no `protocol_config` change.

### Case 2 — Only the CRE workflow id changes

The `expected_workflow_id` lives in `kipio_economics`'s own storage.

**Scenario:** Chainlink CRE is approved, you deploy the workflow, and you get a real `workflowId`. You want `kipio_economics` to accept reports from it.

**Steps:**

```bash
ECONOMICS=<address from deployments/latest/addresses.json>
NEW_WORKFLOW_ID=0x...  # 32-byte hex from `cre workflow hash`

cast send $ECONOMICS "updateCreWorkflowId(bytes32)" $NEW_WORKFLOW_ID \
  --rpc-url https://arbitrum-sepolia-rpc.publicnode.com \
  --private-key $PRIVATE_KEY \
  --gas-price 1gwei
```

**Events emitted:** `CreWorkflowUpdated(oldWorkflowId, newWorkflowId)`.

**Cost:** ~50k gas. No redeploys.

### Case 3 — `runtime`, `economics`, or `recovery` changes

Deploy the new module, then redeploy the Gateway with the new triple, then register the new Gateway.

**Scenario:** You fixed a bug in `runtime`, or you upgraded `economics` with new features.

**Steps:**

1. Deploy the new module:

   ```bash
   make deploy contract=kipio_runtime  # or kipio_economics / kipio_recovery
   ```

   The new address lands in a new `deployments/<ts>/` folder.

2. Register the new module in the registry:

   ```bash
   PROTOCOL_CONFIG=<from deployments/latest/addresses.json>
   NEW_MODULE=0x...

   cast send $PROTOCOL_CONFIG "setRuntimeAddress(address)" $NEW_MODULE \
     --rpc-url https://arbitrum-sepolia-rpc.publicnode.com \
     --private-key $PRIVATE_KEY \
     --gas-price 1gwei
   # Or setEconomicsAddress / setRecoveryAddress
   ```

   Emits `ModuleAddressUpdated(moduleId, oldAddress, newAddress)`.

3. Redeploy the Gateway with the new triple:

   ```bash
   make deploy-gateway
   ```

   This reads the current `deployments/latest/addresses.json`, injects the new triple into `constants.rs`, rebuilds, deploys the new Gateway, and calls `setExecutionGatewayAddress(new_gateway)`.

4. Confirm the registry is consistent:

   ```bash
   cast call $PROTOCOL_CONFIG "getRuntimeAddress()" --rpc-url ...
   cast call $PROTOCOL_CONFIG "getExecutionGatewayAddress()" --rpc-url ...
   ```

**Events emitted:** `ModuleAddressUpdated` with `moduleId` in {0, 1, 3} for the module change, and `moduleId = 4` for the Gateway change.

**Cost:** Deployment gas for the new module + deployment gas for the new Gateway + 4 `cast send` calls.

**Consequence:** Existing accounts remain bound to the old triple. They continue to accept calls from the old `runtime`. New accounts use the new triple. Both sets of accounts coexist indefinitely.

### Case 4 — `kipio_account` changes

More involved: the account bytecode changes → fragment addresses change → Gateway init code changes.

**Scenario:** You fixed a bug in `kipio_account`, or the Dafny-verified bridge changed.

**Steps:**

1. Deploy the new `kipio_account`:

   ```bash
   make deploy contract=kipio_account
   ```

   The contract fragments automatically. The deploy log shows the fragment creation tx hashes and `wasm size: NNNN bytes`.

2. Update `src/kipio_execution_gateway/fragments.toml`:

   - Change `decompressed_size` to the value from the deploy log.
   - Change the three `fragment_N` addresses to the new fragment creation addresses.

   To find the fragment addresses, use Arbiscan on the deployer address and filter for the three contract creation transactions immediately preceding the root deploy. Alternatively, use the reverse-engineering tooling documented in **Fragmented Init Code**.

3. Redeploy the Gateway:

   ```bash
   make deploy-gateway
   ```

   The `build.rs` regenerates the init code from the updated `fragments.toml`, the Gateway rebuilds with the new init code, deploys, and registers.

4. Confirm:

   ```bash
   cat src/kipio_execution_gateway/fragments.toml
   # Inspect the built init code
   BUILT=$(find target -name kipio_account_init.bin -path '*kipio_execution_gateway*' | head -1)
   xxd "$BUILT"
   ```

**Consequence:** Existing accounts keep their old bytecode. New accounts use the new bytecode, and **their addresses will differ** because `keccak(init_code)` changed. This is the most disruptive upgrade type.

### Case 5 — `protocol_config` itself needs to change

`kipio_protocol_config` is immutable, but it can be replaced by deploying a new instance. Doing so requires redeploying every consumer.

**Current state:** Runtime, Recovery, Economics, and IdentityContent each store the `protocol_config` address in their own storage. Runtime and Economics take it via constructor; IdentityContent takes it via the one-time `initialize`. None of them exposes a setter for it. To migrate to a new `protocol_config`, all of them must be redeployed.

**Consequence:** A `protocol_config` change is equivalent to a full protocol redeploy. This is a deliberate design constraint of the current buildathon deployment. A future version could expose a setter on each consumer, but that would introduce a mutable pointer to the root of the registry, weakening the audit trail. It is documented here so that any future attempt to replace `protocol_config` starts from the correct expectation.

### Operational checklist

Before every upgrade, verify:

- [ ] The Gateway's `constants.rs` reflects the intended triple for the *current* deployment.
- [ ] `fragments.toml` matches the deployed `kipio_account` version.
- [ ] `deployments/latest/addresses.json` contains all seven addresses (protocol_config, runtime, recovery, economics, identity_content, execution_gateway, and account if applicable).
- [ ] `make check` passes.
- [ ] The frontend has been notified of the pending change (see **Frontend Integration: Module Updates**).

After every upgrade:

- [ ] `make fix-perms` (deploy runs in Docker as root).
- [ ] Re-run `make check` to confirm the new version compiles and activates.
- [ ] Verify the `ModuleAddressUpdated` events landed on-chain and the frontend has picked them up.

---

## Frontend Integration: Module Updates

The frontend needs to track the *current* version of each module and react to changes. The only address the frontend should hardcode is `PROTOCOL_CONFIG_ADDRESS` (the registry itself). Everything else must be resolved dynamically.

### Subscribing to `ModuleAddressUpdated`

All three fields of the event are `indexed`:

```solidity
event ModuleAddressUpdated(
    uint8 indexed moduleId,
    address indexed oldAddress,
    address indexed newAddress
);
```

In viem:

```ts
import { parseAbiItem, createPublicClient, http } from 'viem';
import { arbitrumSepolia } from 'viem/chains';

const client = createPublicClient({ chain: arbitrumSepolia, transport: http() });

const PROTOCOL_CONFIG_ADDRESS = '0x1e08d50c7bb524ea03371804d5c223e9557e926c';

client.watchContractEvent({
  address: PROTOCOL_CONFIG_ADDRESS,
  event: parseAbiItem(
    'event ModuleAddressUpdated(uint8 indexed moduleId, address indexed oldAddress, address indexed newAddress)'
  ),
  onLogs: (logs) => {
    for (const log of logs) {
      const { moduleId, oldAddress, newAddress } = log.args;
      console.log(`Module ${moduleId}: ${oldAddress} → ${newAddress}`);
    }
  },
});
```

Because all three fields are indexed, filtered queries are cheap:

```ts
// Only runtime updates
const runtimeUpdates = await client.getLogs({
  address: PROTOCOL_CONFIG_ADDRESS,
  event: parseAbiItem(
    'event ModuleAddressUpdated(uint8 indexed moduleId, address indexed oldAddress, address indexed newAddress)'
  ),
  args: { moduleId: 0n },
  fromBlock: 0n,
});
```

### Building a version history

```ts
const MODULE_NAMES = {
  0n: 'runtime',
  1n: 'economics',
  2n: 'identity_content',
  3n: 'recovery',
  4n: 'execution_gateway',
} as const;

async function getModuleHistory(moduleId: bigint) {
  const logs = await client.getLogs({
    address: PROTOCOL_CONFIG_ADDRESS,
    event: parseAbiItem(
      'event ModuleAddressUpdated(uint8 indexed moduleId, address indexed oldAddress, address indexed newAddress)'
    ),
    args: { moduleId },
    fromBlock: 0n,
  });

  return logs.map((log, i) => ({
    version: i + 1,
    address: log.args.newAddress,
    previousAddress: log.args.oldAddress,
    blockNumber: log.blockNumber,
    txHash: log.transactionHash,
  }));
}
```

### Recommended frontend behaviour

1. **Resolve the current module set at startup:**

   ```ts
   const [runtime, economics, recovery, identity, gateway] = await Promise.all([
     client.readContract({ address: PROTOCOL_CONFIG_ADDRESS, abi, functionName: 'getRuntimeAddress' }),
     client.readContract({ address: PROTOCOL_CONFIG_ADDRESS, abi, functionName: 'getEconomicsAddress' }),
     client.readContract({ address: PROTOCOL_CONFIG_ADDRESS, abi, functionName: 'getRecoveryAddress' }),
     client.readContract({ address: PROTOCOL_CONFIG_ADDRESS, abi, functionName: 'getIdentityContentAddress' }),
     client.readContract({ address: PROTOCOL_CONFIG_ADDRESS, abi, functionName: 'getExecutionGatewayAddress' }),
   ]);
   ```

2. **Subscribe to `ModuleAddressUpdated`.** When a module changes, invalidate the cache, re-resolve, and notify the user.

3. **Never hardcode module addresses in the frontend.** Only `PROTOCOL_CONFIG_ADDRESS` is fixed.

4. **Maintain an audit whitelist (optional but recommended).** Keep a list of audited module addresses. If `ModuleAddressUpdated` announces an address not in the whitelist, warn the user before they interact with it. The registry's purpose is to make upgrades visible; the frontend's purpose is to make them understandable.

5. **Account addresses are version-coupled.** When a user's account is created by Gateway vN, the account address depends on that Gateway's init code. The frontend must remember which Gateway created each account and continue to use that Gateway for operations on that account. Resolving the "current" Gateway is not the same as resolving "the Gateway that created this account".

   ```ts
   // Store this at account creation time
   type AccountRecord = {
     address: `0x${string}`;
     createdByGateway: `0x${string}`;
     identity: `0x${string}`;
   };
   ```

   When the user later signs an intent for their account, use `createdByGateway`, not the current Gateway from the registry. The current Gateway is only for creating *new* accounts.

6. **Never assume account addresses are deterministic across Gateway versions.** If the Gateway changes (`kipio_account` upgrade), the CREATE2 derivation changes. The frontend must persist the address of each account as it was created; it must not try to re-derive it.

### Events the frontend should listen to

| Event | Emitted by | Purpose |
|---|---|---|
| `ModuleAddressUpdated(uint8, address, address)` | `protocol_config` | Registry slot changed |
| `ProviderUpdated(uint8, address, address)` | `identity_content` | Provider slot changed |
| `ZkVerifierUpdated(address, address)` | `identity_content` | ZK verifier changed |
| `WorkflowIdUpdated(bytes32, bytes32)` | `identity_content` | Expected workflow id changed |
| `CreWorkflowUpdated(bytes32, bytes32)` | `economics` | CRE workflow id changed |
| `OwnershipTransferStarted(address, address)` | any | Two-step ownership in flight |
| `OwnershipTransferred(address, address)` | any | Ownership completed |
| `Paused(address, bytes32)` / `Unpaused(address)` | any | Circuit breaker |

The frontend should index these events, keep a persistent store of the current state, and surface changes to the user in plain language.

---

## Foundry Interface Validation (mandatory after `make abi`)

The exported Solidity interfaces must **always** be validated against a real `solc` before being used by any consumer:

```bash
cd foundry
forge build
```

The three export bugs listed under **Known Tooling Bugs** are patched automatically by the Makefile, but `forge build` remains the final gate. Any new variant of the same family of bugs will surface there first.

Because these are tooling-side issues in the SDK and not defects in the contract ABI, they are worked around at the Foundry layer (patched interfaces) rather than at the contract layer. The on-chain surface is unaffected: the selectors and calldata layout in the WASM are identical regardless of what the exported `.sol` says.

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

The contract test suite (`unit`, `e2e`, `fork`) is **not yet populated**. The scaffolding is in place, and the intended flow is documented in the roadmap section below.

---

## Technical Architecture

The repository separates cryptography, state persistence, and authorization into independently deployable contracts. The objective is **crypto agility**: the ability to replace a cryptographic primitive or verification strategy without migrating the state of higher layers.

```
                  ┌────────────────────────────────────────┐
                  │          Frontend SDK / Client         │
                  │   (AES/ChaCha Ciphers & WebAuthn)      │
                  └───────────────────┬────────────────────┘
                                      │
                         Invokes via  │  (Signs EIP-712 / Passes Hashes)
                                      ▼
                        ┌───────────────────────────┐
                        │   KipioRuntime            │
                        │   (Orchestrator)          │
                        └─────────────┬─────────────┘
                                      │
               ┌──────────────────────┼──────────────────────┐
               │ Reads Account state  │                      │ Routes via config
               ▼                      ▼                      ▼
    ┌─────────────────────────┐ ┌──────────────────────┐ ┌────────────────────┐
    │ KipioAccount            │ │ KipioIdentityContent │ │ KipioEconomics     │
    │ (Sovereign Aggregate    │ │ (Anchor + Encrypted  │ │ (Settlement +      │
    │  Dafny-verified)        │ │  Metadata & Irys)    │ │  Treasury)         │
    └──────────┬──────────────┘ └──────────────────────┘ └────────────────────┘
               │ Calls External Verifier
               ▼
    ┌────────────────────┐
    │  P-256 precompile  │
    │  (0x100, native)   │
    └────────────────────┘

    ┌────────────────────────────────────────────────────────────────────────┐
    │ KipioProtocolConfig                                                    │
    │ (Discovery hub: module addresses, verifier registry, ledger whitelist) │
    └────────────────────────────────────────────────────────────────────────┘

    ┌────────────────────────────────────────────────────────────────────────┐
    │ KipioExecutionGateway                                                  │
    │ (EIP-7702 + CREATE2 bootstrap; entry point for non-crypto users)       │
    └────────────────────────────────────────────────────────────────────────┘
```

### 1. Runtime (`kipio_runtime`)

The orchestrator. It does not own user state; it reads Account via `IKipioAccount` cross-contract calls, runs the Dafny-derived acceptance and effective-authority logic in memory, and forwards a single atomic transaction through the whole protocol.

Its main entrypoint is `dispatch(envelope)`:

1. Validates the envelope and decodes the `Intent` payload.
2. Reads the target account's `AuthorizationState`.
3. Runs the Dafny authorization pipeline (structural validity plus full acceptance with provenance).
4. If the intent carries `settlement_call_data`, forwards the entire `msg.value()` to `kipio_economics` **before** the target call. This is the atomic fee gate: if payment fails, the whole dispatch reverts and the target never runs.
5. Resolves the target module address through `kipio_protocol_config`.
6. Appends the EIP-2771 suffix (20-byte effective user) when the target module expects it.
7. Forwards the target calldata with the remaining value.
8. Returns the target's return data verbatim.

Runtime is the single transactional orchestrator of the protocol. Any mutating flow that spans multiple modules passes through it.

### 2. Account (`kipio_account`)

The sovereign aggregate. Deployed once per identity via CREATE2. Holds the `AuthorizationState`: credentials, credential authorities, sessions, delegations, restrictions, policy effects, and consumed replay keys. Storage is split into a cold path (an ABI-encoded blob) and a hot path (`StorageMap`s for credential statuses and consumed replay keys), so frequent operations touch one slot instead of re-serialising the full state.

The `AuthorizationState` shape and its transition rules are verified in Dafny. The `src/bridge` crate translates between the Solidity ABI and the generated Dafny types.

Account mutators accept calls only from the immutable `runtime_address` set in the constructor. Direct calls — including from the identity itself — are rejected with `UnauthorizedCaller`. The Account is a pure executor; authorization is orchestrated upstream by Runtime.

Account also exposes `execute_recovery`, which cross-calls `kipio_recovery.consume_recovery`. This is the one documented exception to the "Runtime is the only cross-caller" rule; it is justified by the CEI ordering of the recovery flow.

### 3. Recovery (`kipio_recovery`)

The guardian-driven recovery singleton. Versioned guardian sets, policy requests with threshold approvals, challenge-period execution, and P-256 / secp256k1 signature verification via native precompiles. Recovery transitions are gated by `runtime_address`.

Two callers can drive the terminal transition of an approved request:

* The account itself, through `kipio_account.execute_recovery`.
* The runtime orchestrator, when the recovery drives a state mutation on another module (for example, a pubkey rotation on `kipio_identity_content`). This makes a cross-module recovery a single atomic transaction, even though it spans multiple contracts.

### 4. Identity & content layer (`kipio_identity_content`)

The fused bounded context that handles both the cryptographic identity anchor and the user content vault.

* Anchors a logical actor to a `keccak256(pubkey)` fingerprint. Raw public keys never appear on-chain.
* Implements anti-replay mechanisms through custom EIP-712 structured typed digests.
* Delegates curve-specific execution to **native EVM precompiles**. For P-256, this is the `0x100` precompile defined by RIP-7212 / EIP-7951. No curve arithmetic is executed in WASM; the contract builds the raw 160-byte input and performs a single `staticcall`.
* Manages structural tracking metadata and encrypted Irys pointer locations using immutable tracking indices.
* Tracks access grants through a swap-and-pop grantee index, keeping pagination costs bounded.
* Records storage terms with Irys-aligned semantics (`PERMANENT`, `30_DAYS`, `1_YEAR`, `CUSTOM`) and supports term extensions that only go forward.

User-facing mutators require `msg_sender == runtime` and carry the effective user as a 20-byte suffix appended by the runtime (EIP-2771). Direct calls to those endpoints revert with `NotForwarded`. Governance mutators (ownership, provider configuration, pause) and read-only views remain directly callable.

The identity anchor also exposes `applyAuthorizedRotation`, a runtime-only endpoint that applies an externally approved key rotation. The runtime reads the policy state from `kipio_recovery`, validates the approval, and then forwards the rotation call to `kipio_identity_content`. This replaces the older `rotateKeyFromPolicy` endpoint, which required `kipio_identity_content` to talk to the policy ledger directly.

**Provider configuration.** The constructor takes three provider addresses: `storage_provider`, `query_provider`, and `access_provider`. These are stored in the contract's own storage, not in `protocol_config`. They can be updated later via the owner-gated setters `setStorageProvider`, `setQueryProvider`, and `setAccessProvider`, each of which emits a `ProviderUpdated` event. The constructor does not validate these against zero, so during early deployments placeholder non-zero addresses are used until real providers exist:

| Slot | Intended provider | Current status |
|---|---|---|
| `storage_provider` | Irys | Placeholder (`0x01`) |
| `query_provider` | SXT (Space and Time) | Placeholder (`0x02`); SXT is **cancelled** — see roadmap |
| `access_provider` | TACo (Threshold Network) or LIT Protocol | Placeholder (`0x03`) |

`expected_workflow_id` is a `B256` used to gate CRE reports. It is `0x00..00` until the CRE workflow is deployed. Any endpoint that touches these slots will fail until the real addresses are set.

**Updating providers does not require redeploying anything.** See **Upgrade Procedures** for the exact commands.

### 5. Economics (`kipio_economics`)

The economic coordination layer. It performs the settlement of every operation: pays the storage provider, applies the protocol fee to the treasury, refunds excess through a pull-based refund balance, and coordinates sponsorships, credit, grants, and bootstrap campaigns.

The economic obligation is settled through `settleEconomicObligation(funder, plan_payload)`. The funder is passed explicitly because the caller is the runtime orchestrator: under Model B, `msg_sender` is the runtime, and the effective user travels as a parameter. Direct calls from the user themselves are also accepted, so that EOAs can settle without going through the orchestrator.

Bootstrap funding for account activation is exposed through `fundBootstrap(identity)` and consumed by the Execution Gateway. The flow is pull-based: `fundBootstrap` credits the Gateway's refund balance, `withdrawRefund` transfers the credited ETH to the Gateway.

**CRE integration.** Economics accepts Chainlink Runtime Environment (CRE) reports via `onReport(metadata, report)`. The caller must be the authorized CRE forwarder (a compile-time constant set at construction). The report's `workflowId` is extracted from bytes 0..32 of the metadata, which the KeystoneForwarder signs on-chain. The contract validates the workflow id against `expected_workflow_id`, the nonce, and the deposit. **The CRE workflow itself is not yet deployed** — approval by Chainlink is pending. Until it is, the CRE path is inert: `onReport` will reject every call because `cre_forwarder` is a placeholder.

**Updating the CRE workflow id does not require redeploying anything.** See **Upgrade Procedures**.

### 6. Execution Gateway (`kipio_execution_gateway`)

The entry point for EIP-7702 and CREATE2-based account bootstrap. It resolves the identity of the caller, predicts the deterministic account address, deploys and activates the Account contract if needed, and forwards the original payload to the Runtime. Bootstrap funding is sourced from `kipio_economics` when available, and falls back to the caller's `msg.value` otherwise.

The Gateway is immutable by design. Under EIP-7702, the delegated code runs in the EOA's context, so the Gateway detects the context and performs a self-call to `selfDeploy` to guarantee that CREATE2 uses the Gateway as the deployer. This keeps the deterministic account address stable across direct calls and delegated calls.

The Gateway hardcodes the runtime, economics, and recovery addresses as compile-time constants in `src/config/constants.rs`. See **Versioning Model** for the full rationale.

### 7. Protocol configuration (`kipio_protocol_config`)

The discovery hub. Holds the currently authorized addresses of every operational module, the per-curve verifier mapping, and the whitelist of authorized policy ledgers. Contracts that need to reach a peer module query this contract instead of hard-coding addresses.

The pattern is **on-chain address registry**, not UUPS or delegatecall. Each module is immutable at its address; upgrades are performed by writing a new address into the registry. Existing contracts that read through the registry resolve the new module on the next call, without a redeploy. The Gateway is the one exception — it hard-codes the runtime, economics, and recovery addresses. The reason is subtle:

* The Gateway's CREATE2 derivation depends on `keccak(ACCOUNT_INIT_CODE)`.
* `ACCOUNT_INIT_CODE` contains the runtime, economics, and recovery addresses (see **Fragmented Init Code**).
* If those three were read from `protocol_config` at runtime, the Gateway could deploy an account with `runtime=A` while activating against `runtime=B`, producing an inconsistent account.
* Hardcoding them at compile time makes the Gateway self-contained and auditable: once deployed, its behaviour with respect to those three modules is fixed.

**Consequence.** Any change to `runtime`, `economics`, or `recovery` requires redeploying the Gateway (new `constants.rs`, new `ACCOUNT_INIT_CODE`, new account addresses) and registering it in `protocol_config` with `setExecutionGatewayAddress`. During the transition, old accounts keep working against the old modules; new accounts use the new Gateway. See **Versioning Model** and **Upgrade Procedures** for the full picture.

---

## Fee Model

The protocol fee is a fixed amount in wei, configured by the owner via `updateProtocolFee` and bounded by `maxProtocolFee`. It is charged once per economic settlement inside `kipio_economics`.

The flow is:

1. The runtime forwards the intent's `settlement_call_data` to `kipio_economics`.
2. `settleEconomicObligation` resolves the storage quote, adds the protocol fee, and pays the storage provider.
3. The protocol fee is added to the treasury reserve (`TreasuryModule.protocol_reserves`).
4. Any excess value provided by the user is credited to the funder's pull-based refund balance.

The treasury reserve is protocol-owned. It can currently be redirected through owner-gated paths only:

* `createGrant` — earmark funds for an external campaign.
* `setBootstrapPolicy` — subsidize account activation.
* `createBootstrapCampaign` — fund a targeted onboarding program.
* `registerSponsorGovernance` — pre-approve a sponsor identifier.

The protocol also supports permissionless top-ups: `fundTreasury`, `registerSponsor`, and `depositCredit`. Users may prepay credit; subsequent settlements consume from the credit balance instead of requiring native ETH on each call.

To withdraw the accumulated reserves to an external address, add an owner-gated `withdrawTreasury` endpoint to `kipio_economics`. No other contract needs to change — the fee flow is entirely local to that contract.

---

## Architectural Evolution

Earlier iterations of this workspace shipped a global kernel (`kipio_core`) plus standalone `kipio_access` and `kipio_registry_content` crates. Two changes collapsed that topology:

1. **`kipio_auth` + `kipio_access` + `kipio_registry_content` → `kipio_identity_content`.** Identity and content share the same sovereign address. Unifying them removes a cross-call per signature check and eliminates a duplicated routing layer.

2. **`kipio_core` removed.** The global kernel pattern (one kernel pointing to per-domain modules, with one vault entry per user) is superseded by two layers: `kipio_account` per user (each Account is its own kernel) and `kipio_protocol_config` as a protocol-wide directory. No functionality was lost; the global router's stubs delegated to modules that now own their own domain directly.

`kipio_recovery` was briefly fused into `kipio_account` and then reverted. Recovery is a shared service with its own request ledger keyed by `(account, request_id)`; keeping it as a standalone singleton gives it a separate audit trail and keeps each WASM comfortably under the ArbOS uncompressed activation limit.

The kernel pattern did not disappear — it decentralized to the user level. Every Account is its own immutable kernel: its identity is fixed at CREATE2 time, its `runtime_address` proxy is immutable, and it survives upgrades of the orchestration layer without needing to migrate.

---

## Security Engineering

The codebase enforces operational constraints that support low-power mobile clients (MetaMask Mobile, Brave iOS/Android WebViews) while preserving data privacy:

* **No plaintext on-chain.** All credential identifiers are `keccak256` hashes of the raw material. The contract never sees the credential; only its 32-byte fingerprint is persisted as `B256`.
* **Zero debug leaks.** Tracking and debug logs are omitted or reduced to anonymised `B256` hashes.
* **Indexed events for mobile bridges.** Event signatures use NatSpec index patterns (`address indexed user`, `bytes32 indexed contentHash`) so mobile bridges can query state deltas without stalling WebViews. `ModuleAddressUpdated` indexes all three fields, which makes the registry's upgrade history queryable without scanning.
* **Swap-and-pop deletion.** Storage arrays avoid the "ghost entry" pattern: removing entries triggers structural index cleanups, bounding long-term RPC pagination costs.
* **CEI ordering.** Every mutating handler mutates state before any cross-contract call. If the external call reverts, the whole transaction — including the local mutation — rolls back atomically.
* **Defence in depth.** `code_size` checks reject EOAs and precompiles before they can be stored as config addresses. `Address::ZERO` is validated in every path that receives a target even when the upstream source is trusted.
* **Caller gate.** User-facing mutators across `kipio_account`, `kipio_recovery`, and `kipio_economics` accept calls only from the immutable `runtime_address`. The contracts are pure executors; authorization is orchestrated upstream by Runtime.
* **EIP-2771 for content and settlement.** `kipio_identity_content` and `kipio_economics` follow the trusted-forwarder pattern: the runtime passes the effective user as a 20-byte suffix appended to the calldata. The contracts resolve the effective user from the suffix and reject direct calls with `NotForwarded`. The runtime never falls back to `msg_sender` for the effective user, so there is no ambiguity about who is acting.
* **Recovery digests bound to chain and nonce.** Guardian approval digests include the `chain_id`, the Account address, the request ID, and the target hash. Cancel digests include the same plus the Account's current nonce, making them single-use.
* **Reentrancy.** Stylus SDK 0.10.5+ disables reentrancy at the runtime level. The design does not rely on manual guards: every cross-call uses `RawCall` (not reentrant by construction), and every state mutation is completed before the cross-call as a matter of CEI discipline.

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

1. **Multichain wallets and alternative payment channels**: expanding verification hooks to settle access fees in arbitrary currencies (CCOP, CELO, USDG, etc.). The economic layer is provider-agnostic; adding a new funding source does not require changes to the content or identity layers.
2. **Media-agnostic core anchors**: keeping metadata pointers fully abstract so image, video, document, and agent behaviour payloads can be parsed without core state upgrades.
3. **Hybrid verification pipelines**: running dual-track fuzz testing with `stylus-test` for storage assertions and Forge network state forking for multi-contract integration flows.
4. **Additional operational modules**: adding new modules (agents, ML inference adapters, alternative recovery policies) as new entries in the protocol config registry. Existing contracts inherit them without redeploying.

### Pending and blocked items

The following items are intentionally not implemented in the current buildathon deployment. They are documented here so that the state of the codebase is unambiguous.

* **Space and Time (SXT)** — **cancelled.** The SXT ecosystem is not mature enough for production integration, and the onboarding process is bureaucratic. The `query_provider` slot in `kipio_identity_content` will stay as a placeholder. If SXT matures, the provider can be set via `setQueryProvider`. No contract changes are needed.
* **Chainlink CRE** — **pending external approval.** The workflow is fully coded (`kipio_economics/on_report` is production-ready) but the deployment to a Chainlink DON requires an access approval that has been requested and is under review. Until then, the CRE settlement path is inert: the contract accepts `onReport` calls from the authorized forwarder, but no forwarder will call it because there is no workflow registered. Once approval lands, the workflow is deployed, its `workflowId` is computed and registered in `kipio_economics` via `updateCreWorkflowId`, and the settlement path activates.
* **Chainlink without CRE + Uniswap v4** — **not evaluated.** An alternative settlement path that bypasses CRE entirely and uses Uniswap v4 hooks to source ETH on Arbitrum Sepolia from arbitrary testnet tokens has been mentioned but not designed or prototyped. This path would decouple the settlement flow from Chainlink's approval cycle, at the cost of tighter coupling to the Uniswap v4 hook system.
* **Irys storage** — **pending real address.** The `storage_provider` slot in `kipio_identity_content` is a placeholder. Any call that requires resolving a storage quote will fail until the real Irys address is set. The `setStorageProvider` setter is ready; only the value is missing. See **Upgrade Procedures**, Case 1.
* **TACo (Threshold Network)** — **currently paused.** The upstream project is inactive. The `access_provider` slot is a placeholder. LIT Protocol is the alternate candidate; the setter (`setAccessProvider`) accepts either. See **Upgrade Procedures**, Case 1.
* **Real multisig ownership** — the deployed contracts use a single EOA as owner. Migration to a multisig (Safe) is a post-buildathon step: `transferOwnership` and `acceptOwnership` on each contract handle it.
* **Contract-level test suite** — the scaffolding under `tests/` (`unit.rs`, `e2e.rs`, `fork.rs`, `common/mod.rs`) is empty. The plan is to build it in three layers: unit tests for pure Rust logic (codec, pack/unpack, status transitions), integration tests with `TestVM` for cross-contract flows, and fork tests against the deployed contracts on Sepolia.
* **Fuzz testing** — no property-based tests are in place. The intent is to fuzz the codec and the state-transition logic against invariants derived from the DDD specification.

---

## Paths Not Explored

Several alternative designs were considered and rejected during the initial architecture phase. Two categories follow: paths that were tried and reverted, and paths that were never attempted.

### Tried and reverted

* **`kipio_recovery` fused into `kipio_account`.** Fusion would have removed one cross-call per recovery request. Reverted: recovery is a shared service with its own request ledger, and separating the two keeps each WASM comfortably under the ArbOS uncompressed activation limit. The audit trail of a shared recovery singleton is also preferable.

### Never attempted

* **`kipio_execution_gateway` decoupled from `kipio_account`.** Currently the Gateway embeds the root init code of `kipio_account` as a compile-time constant and deploys accounts via `RawDeploy` + CREATE2. An alternative would be to introduce a separate `kipio_account_factory` contract that owns the init code and exposes `predict(salt)`, `deploy(salt)`, and `is_ready(account)` to the Gateway. The Gateway would then only know the factory interface, not the account's bytecode. **This path was not explored.** It would move the coupling from the Gateway to the factory without eliminating it, and it would add a cross-call per bootstrap. The self-contained Gateway is arguably simpler and more auditable. Both designs are legitimate; the current one was chosen because the Gateway is the *only* contract that needs to be rebuilt when `kipio_account` changes, which is a natural upgrade boundary.
* **A separate `kipio_account_factory` that also deploys fragments on demand.** This would fragment accounts per-user rather than sharing fragments across all accounts. It would multiply on-chain state by the number of users (3 fragments + 1 root per user instead of 1 root per user) with no functional benefit. Rejected on principle.
* **Proxy-based upgradeability for the account.** Considered and rejected in favour of `protocol_config`-driven module resolution. Proxy patterns introduce delegatecall semantics, storage collision risk, and an additional trust assumption on the upgrade admin. The registry pattern keeps each module immutable at its address and centralises only the *resolution* logic.
* **`cargo stylus get-initcode` for fragmented contracts.** Blocked upstream. The reverse-engineering path documented above was chosen instead.

### Analysed and rejected for concrete reasons

* **`kipio_execution_gateway` reading runtime/economics/recovery from `protocol_config` at bootstrap time instead of hardcoding them at compile time.** This was analysed and rejected. The Gateway is not a module like the others — it is a **version anchor**. Every account created by Gateway vN stores `(runtime_vN, recovery_vN)` in its own storage at construction time, and rejects calls from any other runtime. If the Gateway resolved runtime from `protocol_config` at bootstrap time, an account created with `runtime_vN` would reject calls from `runtime_vN+1` even though the frontend thinks it is using the latest runtime. Decoupling the Gateway would silently break the caller gate of every existing account. The hardcoding is therefore a **correctness requirement, not a convenience**. See **Versioning Model** for the full picture.

---

## Notes

* Contracts are deployed on **Arbitrum Sepolia**. Deployment records live under `deployments/<timestamp>/` and are committed to the repository (except for `.log` files, which are gitignored).
* The frontend repository expects ABI sync with the latest Stylus compilation (`make abi`).
* The exported Solidity interfaces must pass `forge build` inside `foundry/` before being consumed by any downstream project. See the **Foundry Interface Validation** section.
* Makefile targets should be followed in order for consistent results. `deploy-full` handles the ordering internally; `make build` and `make check` are safe to run in any order.
* After any `make deploy` or `make deploy-full`, run `make fix-perms` before the next local build, ABI export, or test run. See the **Recovery from Docker root-ownership** section.
* `src/kipio_execution_gateway/src/config/constants.rs` is committed with placeholder zeros. Real addresses are injected at deploy time by `scripts/inject-gateway-constants.sh` and never committed. This keeps the source tree network-agnostic.
* **Never redeploy phase 1 to update a single module.** Deploy the new module, register it via `cast send`, then `make deploy-gateway` to redeploy the Gateway with the new triple. See **Upgrade Procedures**, Case 3.
* **Never forget `make fix-perms` after a deploy.** Docker runs as root and leaves `target/` unwritable.
* **The frontend must never hardcode module addresses other than `protocol_config`'s.** All peers are resolved dynamically via the registry. Account addresses are version-coupled to the Gateway that created them; the frontend must persist them. See **Frontend Integration: Module Updates**.
* **The local nitro-devnode boots at ArbOS 59 by default.** Running the ArbOS 61 upgrade before any contract check is mandatory for fragmented contracts. See **Local Development with nitro-devnode**.

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
* **RawDeploy**: low-level contract creation via the host EVM's `CREATE` / `CREATE2` opcodes. This is what the Gateway uses to deploy accounts.
  * [Docs.rs: stylus_sdk::deploy::RawDeploy](https://docs.rs/stylus-sdk/0.7.0/src/stylus_sdk/deploy/raw.rs.html)
* **WASM binary size control & pipeline optimisation**: canonical compiler tuning mechanics (`opt-level = "z"`, `lto = true`, `panic = "abort"`) to respect host limits.
  * [Arbitrum Docs: Optimizing Stylus Binaries](https://docs.arbitrum.io/stylus/how-tos/optimizing-binaries)
  * [Arbitrum Docs: Stylus Contract Fundamentals & Static Calling](https://docs.arbitrum.io/stylus/fundamentals/contracts)
  * [GitHub: OffchainLabs/cargo-stylus](https://github.com/OffchainLabs/stylus-sdk-rs)
* **`wasm32v1-none` target specification**: official Rust documentation explaining that `-Ctarget-cpu=mvp` is the only reliable way to disable all post-MVP WebAssembly proposals.
  * [Rust Platform Support: wasm32v1-none](https://doc.rust-lang.org/rustc/platform-support/wasm32v1-none.html)
  * [Rust compiler-team issue #791: wasm32v1-none](https://github.com/rust-lang/compiler-team/issues/791)
* **nitro-devnode**: official Offchain Labs development node. Runs a standalone Nitro chain locally with ArbOS support after an explicit upgrade step.
  * [GitHub: OffchainLabs/nitro-devnode](https://github.com/OffchainLabs/nitro-devnode)

### 2. Trusted Forwarders & Relay Patterns

* **EIP-2771 — Secure Protocol for Native Meta Transactions**: the standard that defines the 20-byte sender suffix appended to calldata by a trusted forwarder, and the rules that `_msgSender()` follows on the receiving contract.
  * [Ethereum Improvement Proposals: EIP-2771](https://eips.ethereum.org/EIPS/eip-2771)
* **OpenZeppelin ERC2771Context**: canonical implementation of the trusted forwarder pattern in Solidity, used as the reference for the equivalent runtime/contract split in this workspace.
  * [GitHub: OpenZeppelin ERC2771Context](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/metatx/ERC2771Context.sol)

### 3. Chainlink Runtime Environment (CRE)

* **CRE Overview**: the orchestration layer used by `kipio_economics` for cross-chain settlement. Reports are delivered to the on-chain consumer via the KeystoneForwarder.
  * [Chainlink Docs: CRE Overview](https://docs.chain.link/cre)
* **KeystoneForwarder reference**: the on-chain forwarder address registry (production and simulation endpoints on Arbitrum Sepolia and One).
  * [Chainlink Docs: Forwarder Directory](https://docs.chain.link/cre/guides/workflow/using-evm-client/forwarder-directory)
* **`onReport` metadata layout**: the 62-byte metadata encoding (`workflowId`, hashed `workflowName`, `workflowOwner`) that `kipio_economics` validates on every CRE report.
  * [Chainlink Docs: Report Encoding](https://docs.chain.link/cre/reference/sdk/overview-ts)

### 4. Passkey Authentication & Low-Level Curve Precompiles

* **EIP-7951**: the authoritative successor to RIP-7212 governing the native `0x100` execution context and big-endian inputs for `secp256r1` biometric verifications.
  * [Ethereum Improvement Proposals: EIP-7951](https://eips.ethereum.org/EIPS/eip-7951)
  * [Ethereum Magicians: EIP-7951 Debate & Implementation](https://ethereum-magicians.org/t/eip-7951-precompile-for-secp256r1-curve-support/24360)
* **RIP-7212 layer-2 architecture**: original rollup optimisation layout enabling mobile hardware enclave validation constraints across optimistic networks.
  * [EIP.tools: RIP-7212 Rollup Blueprint](https://eip.tools/rip/7212)
  * [Alchemy Ledger: Deep Dive into RIP-7212 Rollup Primitives](https://www.alchemy.com/blog/what-is-rip-7212)

### 5. Proxy Re-Encryption (PRE) & Mathematical Tooling

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

### 6. Distributed Architecture & Encrypted Storage Integrations

* **WNFS (Web Native File System)**: modular structure layout addressing secure private capability graphs, self-sovereign cryptographic trees, and nested index trees.
  * [GitHub: wnfs-wg/rs-wnfs](https://github.com/wnfs-wg/rs-wnfs)
* **UCAN (User Controlled Authorization Networks)**: distributed authority delegation framework establishing trust chain patterns and cryptographically secure user-space capability certificates without reliance on centralised identity servers.
  * [GitHub: ucan-wg/spec](https://github.com/ucan-wg/spec)
* **Irys invariant storage pipelines**: permanent data tracking frameworks providing continuous accessibility bounds and immutable encrypted content indices. Cascade upgrade (August 2026) introduced tiered storage terms (`PERMANENT`, `30_DAYS`, `1_YEAR`, `CUSTOM`) with forward-only term extension, which the identity-content ledger models on-chain.
  * [Irys Network: Developer Documentation](https://docs.irys.xyz)
  * [GitHub: ArweaveTeam/arweave](https://github.com/ArweaveTeam/arweave)
* **Threshold Network & coordination infrastructure**: decentralised node access management models guiding token incentives, slashing mechanisms, multi-party computation, and proxy coordination logic.
  * [GitHub: threshold-network](https://github.com/threshold-network)
  * [GitHub: nucypher](https://github.com/nucypher)
  * [GitHub: LIT-Protocol](https://github.com/LIT-Protocol)

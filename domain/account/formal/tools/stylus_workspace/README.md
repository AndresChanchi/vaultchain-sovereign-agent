# Kipio Stylus Workspace

> Formal Kipio Account domain, materialized as deployable Arbitrum Stylus contracts.

This workspace sits between the formal Dafny model (`formal/`) and the
production contracts (`contracts/`). It contains the Rust materialization of
the Kipio Account domain and its two deployable Stylus contracts:
`kipio_account` and `kipio_runtime`.

The 104 integration tests in `bridge/` are the semantic safety net: any
optimization that reduces WASM size must keep them green. This document
records the constraints, the failed experiments, and the final configuration
that makes the build reproducible and the contracts verifiable.

---

## 1. Why this workspace exists

The Kipio Account domain is defined in a DDD (`domain/account/formal/`),
verified in Dafny (57 files, 1461 verified properties, 0 errors), and
translated to Rust via a production exporter. The translated Rust crate
(`generated/rust/`) cannot be deployed directly: it needs a Stylus harness
that maps the Dafny types to a Solidity-compatible ABI and exposes them as
on-chain entrypoints.

This workspace contains that harness. It is deliberately separated from
`contracts/` because:

- The formal model is the source of truth. The harness is a translation
  layer, not a contract implementation.
- The 104 bridge tests validate the translation independently of the
  contracts that consume it.
- The contract split (Account vs Runtime) is a deployment concern, not a
  domain concern.

---

## 2. Repository structure

```
stylus_workspace/
├── Cargo.toml              workspace manifest (deps + release profile)
├── rust-toolchain.toml     pinned nightly toolchain
├── Stylus.toml             workspace networks + wasm-opt configuration
│
├── bridge/                 shared crate (not a contract)
│   ├── Cargo.toml
│   ├── src/lib.rs          ABI ↔ Dafny translation layer
│   └── tests/
│       └── bridge_integration.rs   104 semantic tests
│
├── kipio_account/          contract #1 (stateful, per-identity)
│   ├── Cargo.toml
│   ├── Stylus.toml
│   └── src/
│       ├── lib.rs
│       └── bin/export_abi.rs
│
├── kipio_runtime/          contract #2 (singleton orchestrator)
│   ├── Cargo.toml
│   ├── Stylus.toml
│   └── src/
│       ├── lib.rs
│       └── bin/export_abi.rs
│
└── tests/                  integration test crate (not a contract)
    ├── Cargo.toml
    └── tests/
        ├── common/mod.rs
        └── cross_contract.rs
```

`bridge` and `tests` are listed in `Cargo.toml` `[workspace].members` but
**not** in `Stylus.toml` `[workspace].members`. The `Stylus.toml` list
contains only the crates that have an `#[entrypoint]`.

---

## 3. Contract responsibilities (DDD-aligned)

| Contract | Cardinality | Stateful | Role |
|---|---|---|---|
| `kipio_account` | One per identity (CREATE2) | Yes | Owns the `AuthorizationState` (§25) and the 16 provisioning transitions (§26) |
| `kipio_runtime` | Singleton | No | Orchestrates authorization acceptance, effective authority derivation, policy consumption, and execution context validation (§35) |

### Why `kipio_account` is stateful

Four independent DDD properties require persistence:

- **§4**: an `Identity` can control multiple `Account`s. Without storage,
  the accounts would be indistinguishable.
- **§13**: credential recognition is specific to each `Account`. Without
  persistence, the recognition has to be redeclared on every call.
- **§39**: the blockchain is the environment where "verifiable changes"
  happen. Verifiable changes require persistent state.
- **§42**: replay protection requires memory. If consumed replay keys are
  not persisted, every transaction can reuse the same authorization.

### Why `kipio_runtime` is not stateful

§35 defines Runtime as the coordinator of distributed evaluation. §46
explicitly classifies Runtime as an "Operational / Infrastructure Concept"
with no Entity identity. It reads Account state via cross-contract calls
and runs the Dafny-derived logic locally.

### Why not merge Runtime and Account

Merging them would make Runtime the owner of AuthorizationState, violating
§25 and §35. Merging Runtime with `kipio_execution_gateway` (a future
operational component) is theoretically compatible with the DDD but is not
viable today due to WASM size (see §7).

---

## 4. Storage design in `kipio_account`

The `AuthorizationStateAbi` is a deeply nested struct (9 sub-arrays:
capabilities, credentials, credential authorities, sessions, delegations,
delegation provenance, restrictions, policy effects, replay keys). Storing
it as a single ABI-encoded blob in `StorageBytes` minimizes slot count, but
any write re-serializes the entire blob.

To avoid that, the storage layout is split into a cold path and a hot path:

| Layer | Content | Frequency | Storage type |
|---|---|---|---|
| Metadata | `identity_id`, `initialized`, `nonce` | Once / rarely | `StorageAddress`, `StorageBool`, `StorageU64` |
| Cold path | Full `AuthorizationState` blob | Structural changes only | `StorageBytes` |
| Hot path | `credential_statuses` | Every status update | `StorageMap<B256, StorageU8>` |
| Hot path | `consumed_replay_keys` | Every replay consumption | `StorageMap<B256, StorageBool>` |

The two hot-path maps absorb the two most frequent mutations. Changing a
credential status or consuming a replay key writes **one SSTORE**, not the
entire blob. Readers merge the hot maps into the cold blob in memory when
returning `get_authorization_state()`.

### Credential binding

A credential's `id` is a `keccak256` hash of the raw credential (passkey
pubkey, Google JWT, etc.). The contract never sees the raw material. On-chain,
only the 32-byte fingerprint is persisted as `B256`, occupying exactly one
storage slot. This is the binding property: the raw credential lives
off-chain, only its footprint lives on-chain.

---

## 5. Build reproducibility

The toolchain is pinned in `rust-toolchain.toml` to **`nightly-2025-09-23`**.
This is not arbitrary. It is the last nightly that works with the current
`cargo-stylus 0.10.9` reproducible flow.

### The constraint

`cargo-stylus 0.10.9` injects the legacy flag
`-Zbuild-std-features=panic_immediate_abort` when it detects a non-stable
toolchain. Starting with nightly `2025-09-24`, that flag was migrated to a
real panic strategy (`-Cpanic=immediate-abort`), and `core` now contains a
`compile_error!` that rejects the old syntax. Any nightly newer than
`2025-09-23` fails with:

```
error: panic_immediate_abort is now a real panic strategy!
Enable it with `panic = "immediate-abort"` in Cargo.toml, or with the
compiler flags `-Zunstable-options -Cpanic=immediate-abort`.
```

Since `cargo-stylus 0.10.9` has not been updated to the new syntax,
`nightly-2025-09-23` is the newest usable nightly. This is the only
trade-off: 13-15 KB more WASM (216 KB vs. 201 KB for Account) in exchange
for a fully verifiable deploy flow (`cargo stylus check` / `deploy` /
`verify` all work without `--wasm-file`).

### Why not stable

Stable compiles cleanly but cannot use `panic=immediate-abort`, which is
unstable. The result is 233 KB (Account) and 229 KB (Runtime), still under
the 256 KB limit, but with less headroom and no path to further reduction
without a toolchain change.

### Why not a newer nightly + `--wasm-file`

A newer nightly (e.g. `2026-09-19`) can compile the contract if the
compilation is invoked manually with `RUSTFLAGS` and the WASM is passed to
`cargo stylus check --wasm-file`. But `cargo stylus verify` still fails
because it uses the same build path that injects the legacy flag. The
contract would be deployable but not verifiable. That is a dead end for
production.

### Configuration summary

```
rust-toolchain.toml   channel = "nightly-2025-09-23" + rust-src + wasm32 target
Cargo.toml            no cargo-features, no panic=immediate-abort in profile
Stylus.toml           wasm-opt v132 with --converge --closed-world + strip flags
.cargo/config.toml    not used
```

---

## 6. Optimization journey

The following table records every configuration that was measured, in
chronological order. All sizes are for `kipio_account` uncompressed unless
noted.

| Configuration | Account (compressed) | Account (uncompressed) | Account (fragments) |
|---|---|---|---|
| Original monolithic harness | 62.9 KB | 318.2 KB (rejected by deployer) | — |
| `+ small-int` feature | 61.3 KB | 318.2 KB | — |
| `+` remove `Debug` derives | 61.3 KB | ~317 KB | — |
| `+ wasm-opt -Oz` (partial flags) | 62.0 KB | 233.0 KB | 3 |
| `+ wasm-opt` full flags (stable) | 62.0 KB | 233.0 KB | 3 |
| `+ panic=immediate-abort` (nightly 2026-09-19) | 50.8 KB | 201.4 KB | 3 |
| **Final config** (nightly 2025-09-23) | **53.7 KB** | **216.0 KB** | **3** |

`kipio_runtime` followed the same trajectory and ended at 52.2 KB
compressed / 224.3 KB uncompressed.

### Attempts that did not work

- **`wasm-snip`**: produced a larger file than `wasm-opt` alone.
- **`.cargo/config.toml` with `panic-immediate-abort = true`**: triggers
  the `compile_error!` in `core` because it re-activates the legacy cfg.
- **`cargo-features = ["panic-immediate-abort"]` in `Cargo.toml`**: no
  longer needed, and `cargo stylus` ignores it silently.
- **Any nightly newer than 2025-09-23 without `--wasm-file`**: fails with
  the panic strategy conflict.

### Attempts that worked but were rejected

- **Manual build with `RUSTFLAGS` + `--wasm-file`**: compiles and measures
  correctly, but `cargo stylus verify` does not work, so the result is not
  production-ready.

---

## 7. Deployment constraints

### ArbOS 61 "Elara"

The `MaxWasmSize` on Arbitrum One, Nova, and Sepolia was raised from 128 KB
to **256 KB uncompressed**. The compressed limit for a single fragment was
raised from 24 KB to **96 KB**.

The two limits are independent:

- **Compressed > 24 KB**: triggers automatic fragmentation. The CLI splits
  the WASM into the minimum number of fragments, deploys each in its own
  transaction, and deploys a root contract that concatenates them at
  activation time. The root address is the one users call.
- **Uncompressed > 256 KB**: hard rejection by the deployer. Fragmentation
  does not help. The WASM is refused before any fragment is created.

Both contracts in this workspace exceed 24 KB compressed (hence 3 fragments
each) and are under 256 KB uncompressed. Fragmentation is active and
functioning; the uncompressed constraint is satisfied.

### Merging Runtime with the Gateway

`kipio_execution_gateway` weighs approximately 50 KB uncompressed. Merging
it with `kipio_runtime` (224.3 KB) would produce a single contract of
~274 KB, above the 256 KB limit. The merge is not viable with the current
sizes and would require reducing the Runtime entrypoint surface first.

---

## 8. Testing strategy

Two layers, two crates, two goals.

### Layer 1: bridge (pure translation)

Location: `bridge/tests/bridge_integration.rs`
Framework: standard `#[test]`, no VM
Count: 104 tests
Runtime: ~30 ms

These tests exercise the ABI ↔ Dafny conversion directly. They verify that
`capability_from_abi`, `auth_state_to_abi`, `policy_effect_to_abi`, the
provisioning transitions, and the composed entrypoints preserve semantics
across the boundary. They are the semantic safety net: any optimization
that touches `bridge/src/lib.rs` must keep them green.

### Layer 2: integration (contracts + cross-contract + fork)

Location: `tests/tests/cross_contract.rs`
Framework: `stylus-test 0.10.9` with `TestVM` / `TestVMBuilder`
Three tiers:

- **Tier A** — In-memory `TestVM`: exercises the `#[public]` entrypoints of
  `kipio_account` and `kipio_runtime` directly.
- **Tier B** — `TestVM::mock_call`: simulates a cross-contract response,
  verifying that `kipio_runtime` decodes and handles the return value.
- **Tier C** — `TestVMBuilder::rpc_url`: forks storage reads from a live
  Arbitrum Sepolia RPC endpoint, without deploying.

The `--ignored` flag is used on fork tests so they can be run explicitly
when a network is available:

```bash
cargo test -p kipio_integration_tests                    # Tier A + B
cargo test -p kipio_integration_tests -- --ignored       # Tier C
```

---

## 9. Build and deploy

### Full pipeline

```bash
# Verify the bridge and the integration tests
cargo test -p kipio_account_bridge
cargo test -p kipio_integration_tests

# Compile and measure each contract
cargo stylus check --manifest-path kipio_account/Cargo.toml --verbose
cargo stylus check --manifest-path kipio_runtime/Cargo.toml --verbose

# Deploy to Sepolia
cargo stylus deploy \
  --no-verify \
  --max-fee-per-gas-gwei=1 \
  --private-key-path=/tmp/sepolia.key \
  --endpoint="https://sepolia-rollup.arbitrum.io/rpc"

# Reproducible verification
cargo stylus verify
```

### Fragmentation

When a contract exceeds 24 KB compressed, `cargo stylus deploy` splits it
into fragments automatically. No flags are required. The deploy produces
N + 1 transactions (N fragments + activation) and the root address is
logged. Users call the root address, not the individual fragments.

---

## 10. Version manifest

| Component | Version |
|---|---|
| `cargo-stylus` | 0.10.9 |
| `stylus-sdk` | 0.10.9 |
| `stylus-test` | 0.10.9 |
| Binaryen (`wasm-opt`) | 132 |
| Rust stable (fallback) | 1.98.1 |
| Rust nightly (pinned) | `nightly-2025-09-23` (`1.92.0-nightly f6092f224 2025-09-22`) |
| Rust nightly (unusable) | `nightly-2026-09-19` (`1.100.0-nightly`) |
| ArbOS | 61 ("Elara") |
| Target | `wasm32-unknown-unknown` |

### Nightly archive

The pinned nightly is permanently archived at:

```
https://static.rust-lang.org/dist/2025-09-23/channel-rust-nightly.toml
```

Any third party can reproduce the exact toolchain by installing rustup and
running `rustup toolchain install nightly-2025-09-23 --profile minimal
--component rust-src --target wasm32-unknown-unknown`. The resulting
compiler is bit-identical to the one used here.

---

## 11. References

### Arbitrum

- ArbOS 61 upgrade notice: <https://docs.arbitrum.io/notices/arbos61-upgrade-notice>
- Verifying Stylus contracts: <https://docs.arbitrum.io/stylus/cli-tools/verify-contracts>

### Rust

- Date-based channels: <https://rust-lang.github.io/rustup/concepts/channels.html>
- Rust issue #146974 (build-std compatibility with panic strategy): <https://github.com/rust-lang/rust/issues/146974>
- Cargo PR #16041 (panic=immediate-abort support): <https://github.com/rust-lang/cargo/pull/16041>
- Cargo PR #16054 (config clarification): <https://github.com/rust-lang/cargo/pull/16054>
- Cargo unstable docs: <https://doc.rust-lang.org/nightly/cargo/reference/unstable.html>


### Kipio

- DDD: `domain/account/formal/README.md`
- Formal domain model: `domain/account/formal/`
- Production contracts: `contracts/`

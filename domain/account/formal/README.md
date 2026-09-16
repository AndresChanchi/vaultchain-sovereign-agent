# Kipio Account — Formal Domain

A canonical, machine-verifiable representation of the Kipio Account domain.

This directory contains the formal domain model, its invariants, and adversarial proofs written in [Dafny](https://dafny.org/). The purpose is not to reproduce the implementation line by line, but to establish a precise semantic model of the domain that can be verified, documented, consumed by humans, and used as a foundation for future implementations.

## Domain truth

The formalization is organized as a dependency-driven domain model:

```text
foundation
    ↓
authority
    ↓
account
    ↓
authorization
    ↓
execution
    ↓
policy
    ↓
laws
    ↓
proofs
```

Each layer builds on the semantics established by the previous one.

The order is intentional: lower layers define the vocabulary and value semantics of the domain, while higher layers compose those concepts into authority, authorization, execution, policy, invariants, and finally adversarial evidence.

## Layers of truth

The project treats domain knowledge as several complementary layers:

```text
                         DOMAIN TRUTH
                              │
                              ▼
                     ┌────────────────┐
                     │       DDD      │
                     │    semantics   │
                     └───────┬────────┘
                             │
                ┌────────────┼────────────┐
                ▼            ▼            ▼
             Dafny         Docs       LLM docs
                │            │            │
                ▼            ▼            ▼
                Proofs        Humans      AI
                │
                ▼
             Injects
                │
                ▼
              Rust
                │
                ▼
             Stylus
                │
                ▼
             Arbitrum
```

These layers have different responsibilities:

* **DDD defines meaning.**
* **Dafny demonstrates specified properties.**
* **Documentation explains intent and usage.**
* **Injects translate ghost relations into executable counterparts.**
* **Rust materializes the domain model.**
* **Stylus provides the execution environment.**
* **Arbitrum provides the current target chain.**

They do not need to have identical levels of minimality. The formal model exists to preserve semantic boundaries and prove properties, not to mechanically mirror every implementation detail.

## Dafny injects

Some domain semantics are expressed in Dafny as ghost relations:
predicates that exist for verification but that do not compile to
executable code. `AuthorizationCanBeAccepted` and the EffectiveAuthority
provenance construction are the two clearest examples.

The Rust bridge cannot call a ghost predicate. When a Stylus contract
needs to invoke a ghost relation, the relation is rewritten as an
executable counterpart in `tools/dafny_inject/`. The pattern is:

```text
ghost predicate P(...) { ... }
    ↓
function P_exec(...): T { ... }
    ↓
lemma P_exec_matches_ghost(...) ensures P_exec(...) <==> P(...)
```

The executable function uses only constructs the Rust backend can emit
(`match`, iteration with a proven `decreases`, witness selection whose
uniqueness is proved). The lemma states that the two agree on every
input. Semantically they are the same function; operationally one is
for proofs, the other for the compiled contract.

Current injects:

```text
tools/dafny_inject/
├── authority/
│   └── EffectiveAuthorityComposition.dfy
├── authorization/
│   ├── AuthorizationAcceptanceComposition.dfy
│   └── AuthorizationAcceptanceWithProvenance.dfy
├── execution/
│   └── ExecutionContextComposition.dfy
└── policy/
    └── PolicyApplicationComposition.dfy
```

The injects are not part of the canonical source tree. They are copied
into `generated/dfy-annotated/` before translation. The committed `.dfy`
sources remain unchanged.

### Determinism constraints

Dafny's Rust backend requires `--enforce-determinism`. The flag forbids
`:|` (assign-such-that) inside *methods* when the witness is not
provably unique. Inside *functions*, `:|` is allowed when the condition
uniquely determines the value.

Two constraints follow:

1. **Iteration over sets must go through a total order with a proved
   unique minimum.** `AuthorizationState`'s components are sets; the
   injects iterate them by defining an explicit lexicographic order over
   `Id` and proving that the minimum of a non-empty finite set is unique.

2. **The built-in `<=` on `seq<T>` is not lexicographic and is not total
   in Dafny.** The order is defined explicitly in each inject instead of
   relying on the built-in relation.

### Translation entrypoint

Dafny rejects a file that is both passed on the command line and pulled
in transitively via `include`. The injects include runtime sources
transitively, so they cannot be listed alongside those sources as
separate inputs.

`export_rust_production.py` synthesizes a single aggregator,
`generated/dfy-annotated/__translate_entrypoint.dfy`, that includes
every runtime source plus every injected composition. That aggregator is
the only top-level file passed to `dafny translate`.

## Repository structure

```text
formal/
├── foundation/
├── authority/
├── account/
├── authorization/
├── execution/
├── policy/
├── laws/
├── proofs/
│   ├── isolated/
│   └── scenarios/
├── tools/
│   ├── context.py
│   ├── dependency_graph.py
│   ├── export_rust.py
│   ├── export_rust_production.py
│   ├── dafny_inject/
│   │   ├── authority/
│   │   ├── authorization/
│   │   ├── execution/
│   │   └── policy/
│   ├── stylus_workspace/
│   │   ├── Cargo.toml
│   │   ├── Stylus.toml
│   │   ├── rust-toolchain.toml
│   │   └── harness/
│   ├── extern_lab/
│   │   └── fixtures/
│   ├── extern_crate/
│   └── generated_crate/
├── dependencies.dot
├── dependencies.json
├── dependencies.svg
├── dependency-report.txt
└── README.md
```

The `generated/` directory does not appear above because it is a runtime artifact and is not committed:

```text
generated/
├── dfy-annotated/       runtime tree with {:extern} annotations and
│                        injected compositions applied
└── rust/                the assembled Rust crate
```

### Foundation

The foundational vocabulary of the domain.

```text
DomainPrimitives
Subject
Identity
Capability
Chain
DomainAction
ExecutionTarget
Restriction
Scope
```

These definitions establish the value semantics used by every higher layer.

### Authority

The domain model for credentials, sessions, delegation, and effective authority.

```text
AuthorizationState
CredentialAuthority
Credential
Delegation
EffectiveAuthority
Session
```

This layer establishes how authority exists, is derived, remains bounded, and becomes usable within the account domain.

### Account

The Kipio Account aggregate and its state transitions.

```text
Account
AccountTransitions
```

The account layer connects sovereign identity and authority state into a coherent domain lifecycle.

### Authorization

The acceptance and validation boundary for authorizations.

```text
AuthorizationAcceptanceTransition
Authorization
AuthorizationValidation
Replay
```

This layer establishes when an authorization may be accepted and how lifecycle and replay constraints participate in that decision.

### Execution

The boundary between an accepted authorization and executable intent.

```text
ExecutionConstraints
ExecutionContext
ExecutionRequest
ExecutionSemantics
```

Execution semantics are deliberately separated from authority semantics. Environment-specific materialization belongs here rather than redefining domain authority.

### Policy

Policy state, effects, consumption, and transitions.

```text
AuthorizationStateTransition
PolicyConsumption
Policy
PolicyEffect
```

### Laws

Domain-wide invariants expressed independently from concrete scenario proofs.

```text
FOUNDATION
  IdentityLaws
  CapabilityLaws

AUTHORITY
  AuthorityLaws
  SessionLaws
  DelegationLaws

AUTHORIZATION
  AuthorizationLaws

POLICY
  PolicyLaws

EXECUTION
  ExecutionLaws
```

The laws layer describes properties that the domain must preserve regardless of a particular scenario.

## Proof architecture

Proofs are divided into two categories.

### Isolated proofs

These verify bounded properties of individual domain subsystems.

```text
FoundationProofs.dfy
AuthorityProofs.dfy
AuthorizationProofs.dfy
AccountProofs.dfy
ExecutionProofs.dfy
PolicyProofs.dfy
```

They provide the reusable proof surface on which the scenario layer builds.

### Scenario proofs

The scenario layer deliberately attacks the domain model from different perspectives.

| #  | Scenario                              | Boundary exercised                 |
| -- | ------------------------------------- | ---------------------------------- |
| 1  | `GrandmotherProof.dfy`                | recognized vs. usable authority    |
| 2  | `AgentProof.dfy`                      | session and bounded authority      |
| 3  | `RecoveryProof.dfy`                   | lifecycle and replay               |
| 4  | `GameProof.dfy`                       | temporal execution context         |
| 5  | `DeFiProof.dfy`                       | effective authority and acceptance |
| 6  | `EnterpriseProof.dfy`                 | delegation non-expansion           |
| 7  | `CryptobroProof.dfy`                  | replay lifecycle                   |
| 8  | `EIP7702Proof.dfy`                    | identity and account state         |
| 9  | `MultiChainProof.dfy`                 | contextual authority               |
| 10 | `FutureAdapterProof.dfy`              | execution/authority separation     |
| 11 | `InvalidAccountAcceptanceProof.dfy`   | account validity                   |
| 12 | `UnprovenAuthorityProof.dfy`          | authority provenance               |
| 13 | `IncompleteExecutionContextProof.dfy` | execution completeness             |
| 14 | `PolicyAtomicityProof.dfy`            | atomic policy transitions          |

These scenarios are not conventional unit tests. They are adversarial specifications designed to demonstrate that invalid states or invalid transitions cannot cross the relevant semantic boundaries under the encoded model.

## Effective authority and provenance

`EffectiveAuthority` is modeled as a value object representing the capabilities effectively available to an account.

Authority provenance is represented separately at the proof level.

This distinction is intentional:

```text
EffectiveAuthority
    = capability value

Authority provenance
    = where those capabilities were legitimately derived from
```

The formal model therefore preserves both:

1. the resulting effective authority value, and
2. the concrete source attribution required to justify that value.

Distinct authority sources may expose equal capability sets without becoming the same source.

This allows legitimate multi-source authority while preventing value equality from erasing concrete source identity.

## Execution boundaries

The formal model separates authorization semantics from environment-specific execution delivery.

Conceptually:

```text
Authorization
     │
     ▼
semantic acceptance
     │
     ▼
ExecutionContext
     │
     ├── Chain
     ├── Target
     └── Constraints
     │
     ▼
environment-specific execution
```

A chain or execution environment does not redefine what authority means.

Instead, execution semantics determine whether an already accepted domain decision can be materially delivered in a particular environment.

This separation allows the domain model to remain independent of a particular execution technology or infrastructure provider.

## Verification

The formalization is written for **Dafny 4.11.0**.

### Install Dafny 4.11.0

Using the .NET tool installation:

```bash
dotnet tool install --global Dafny --version 4.11.0
```

Verify the installation:

```bash
dafny --version
```

The expected version should begin with:

```text
4.11.0
```

Dafny 4.11.0 is an official Dafny release. The NuGet package for this version targets .NET 8 or later.

### Verify the formal domain

From the `formal/` directory:

```bash
dafny verify $(find . -type f -name '*.dfy' | sort)
```

Or from the project directory:

```bash
cd formal
dafny verify $(find . -type f -name '*.dfy' | sort)
```

A successful repository-wide verification run should finish with:

```text
Dafny program verifier finished with 0 errors
```

The current formalization has been verified across all **57 `.dfy` files** with:

```text
1461 verified
0 errors
```

### Verify the annotated runtime tree

The runtime tree with `{:extern}` annotations and injected compositions lives under `generated/dfy-annotated/`. It is generated by the production exporter, but it can be verified directly:

```bash
cd generated/dfy-annotated
dafny verify $(find . -type f -name '*.dfy' | sort)
```

A successful run finishes with:

```text
Dafny program verifier finished with 686 verified, 0 errors
```

This verification is obligatory whenever the DDD or the injects are modified, since it covers the executable subset that feeds the Rust translation. The canonical tree verification above covers the verification-only layers (`laws/`, `proofs/`); the annotated tree verification covers the runtime surface.

## Verification philosophy

A successful Dafny verification means that the encoded implementation and proof obligations satisfy the specifications written in the formal model.

It does **not** mean that every possible property of the real-world system has been proven.

The scope of a proof is defined by the specification itself.

For that reason, this repository deliberately separates:

```text
domain semantics
      ↓
formal specification
      ↓
invariants and laws
      ↓
isolated proofs
      ↓
adversarial scenarios
```

The goal is not merely to make Dafny accept the files.

The goal is to make the domain boundaries explicit enough that an invalid construction cannot silently cross them.

## Dependency analysis

The dependency graph is generated from the formal sources and is provided in several representations:

```text
dependencies.dot
dependencies.json
dependencies.svg
dependency-report.txt
```

These artifacts expose the structure of the formal model both to humans and to tooling.

The supporting utilities are:

```text
tools/context.py
tools/dependency_graph.py
```

`context.py` Copy and paste

`dependency_graph.py` analyzes the formal source graph, including fan-in and fan-out relationships, and generates dependency artifacts.

## Rust materialization

Dafny is the source of truth. Rust is a derived artifact.

The pipeline that produces the Rust crate lives in two exporters, each with a distinct responsibility:

```text
tools/export_rust.py              experimental
tools/export_rust_production.py   production
```

The split is intentional. The experimental exporter exists to answer questions that the Dafny backend does not document and to keep those answers reproducible across Dafny versions. The production exporter assumes the answers are known and assembles the crate. Mixing both responsibilities in one file would make neither auditable.

### The experimental exporter

`export_rust.py` is the interrogation bench. It is the file that, during the original investigation, learned how the Dafny 4.11 Rust backend reacts to every syntactic variant of `{:extern}` on an abstract type, and how the generated code survives `rustc`, `cargo check`, and a hand-rolled extern harness.

Its modes:

```text
--plan          show dependency-aware export order and stop
--diagnose      per-file translation, discard output
--extern-lab    probe every {:extern} variant for a given abstract type
```

The `--extern-lab` mode copies the formal tree into an isolated temporary directory, rewrites exactly one abstract type declaration, runs verify + translate + rustc + cargo on the copy, and destroys the copy when finished. The real source is never modified.

By default the lab tests four candidates:

```text
control-no-extern
extern-empty                      {:extern}
extern-same-name                  {:extern "Chain"}
extern-two-args                   {:extern "KipioAccountChain", "Chain"}
```

The three non-control candidates produce **byte-identical Rust**. They are the winners. The other five variants that were tried during the original investigation (`"KipioChain"`, `"KipioAccountChain::Chain"`, `"crate::Chain"`, `"struct"`, and the two-arg form with a different module name) generate symbols that do not resolve and are documented only in the historical lab report.

The recommended annotation for the production pipeline is the bare form:

```dafny
type {:extern} Chain(==)
```

### The production exporter

`export_rust_production.py` assembles the actual Rust crate. It follows an external-crate strategy (Option B) where the concrete Rust representation of each abstract Dafny type lives outside the generated code, and the generated code is injected with those types into the modules Dafny already emits.

Its modes:

```text
--plan          show dependency-aware export order and stop
--diagnose      per-file translation, discard output
--extern-lab    the same reduced lab as export_rust.py
(default)       assemble the Rust crate
```

The default mode performs the following steps, in order:

1. **Copy the runtime `.dfy` tree** into `generated/dfy-annotated/`.
2. **Inject the derived compositions** from `tools/dafny_inject/`.
3. **Annotate the five abstract types** in the copy with `{:extern}`.
4. **Obtain `dafny_runtime`** once via a single `--include-runtime`
   translation.
5. **Synthesize `__translate_entrypoint.dfy`** and translate it in a
   single invocation. The aggregator includes every runtime source plus
   every injected composition, and is the only top-level file passed to
   `dafny translate`.
6. **Fix the Dafny-4.11 trait-object casts** (see "Backend workaround").
7. **Inject the five Rust extern types** into their corresponding
   generated modules, so each module is self-contained.
8. **Generate `src/lib.rs`** with a single `include!` directive.
9. **Run `cargo check --offline`** on the assembled crate.

### The five abstract types

The formal model contains exactly five abstract types that require extern annotations. Every other runtime module translates natively.

| Dafny module                          | Type                    | Layer      |
| ------------------------------------- | ----------------------- | ---------- |
| `KipioAccountChain`                   | `Chain`                 | foundation |
| `KipioAccountDomainAction`            | `DomainAction`          | foundation |
| `KipioAccountExecutionTarget`         | `ExecutionTarget`       | foundation |
| `KipioAccountExecutionConstraints`    | `ExecutionConstraints`  | execution  |
| `KipioAccountExecutionSemantics`      | `ExecutionEnvironment`  | execution  |

The `{:extern}` attribute is not applied to the source tree directly. The production pipeline copies the runtime `.dfy` files into `generated/dfy-annotated/` and applies the annotations there. The committed `.dfy` sources remain unchanged.

### Backend workaround

Dafny 4.11.0's Rust backend emits trait-object casts of the following shape:

```rust
Rc::new(move || -> Set<Rc<Credential>> { ... }) as Rc<dyn ::std::ops::Fn() -> _>
```

`rustc` rejects the `_` placeholder inside a trait object. The closure already declares its return type, but the backend drops it when emitting the cast.

The production exporter rewrites the pattern deterministically: it captures the closure's declared return type and substitutes it into the trait object. Fifteen occurrences are fixed in the current formalization, including the ones introduced by the injects.

Any future Dafny upgrade must re-run the production exporter and confirm that the substitutions are either no longer necessary or still correct.

### Templates

Two crate templates live under `tools/`:

```text
tools/extern_crate/     template for the kipio_domain_externs crate
tools/generated_crate/  template for the kipio_account_generated crate
```

The production exporter copies `tools/generated_crate/Cargo.toml` into the assembled crate. The extern crate template is preserved for reference; the production pipeline injects the extern types directly into the generated module instead of depending on the extern crate at build time, which is why the generated `Cargo.toml` does not list it.

### Reproducing the Rust crate

From the `formal/` directory:

```bash
python3 tools/export_rust_production.py --no-verify
```

The `--no-verify` flag skips repository-wide Dafny verification on the original tree and lets the pipeline focus on translation and assembly. A full run without the flag additionally verifies the original (unannotated) tree first.

A successful run finishes with:

```text
== cargo check --offline ==

status        : COMPILED
detail        : cargo check succeeded

Production export completed successfully.
```

The assembled crate lives at `generated/rust/`. It can be built with:

```bash
cd generated/rust
cargo build --offline
```

### What the exporters do not do

The exporters produce a Rust library from Dafny sources. They do not
touch Stylus, do not define ABI types, and do not know about
`wasm32-unknown-unknown`.

The Stylus harness lives under `tools/stylus_workspace/` and consumes
the exported crate as a normal dependency. That boundary is documented
in the next section.

## Stylus harness

`tools/stylus_workspace/` contains a minimal Stylus workspace that
exposes the generated Dafny-Rust domain to the Arbitrum Stylus runtime.
It is a sibling of the formal project, not part of it.

```text
tools/stylus_workspace/
├── Cargo.toml                 workspace manifest
├── Stylus.toml                workspace-level Stylus config
├── rust-toolchain.toml        pins Rust 1.94.0 + wasm32 target
└── harness/
    ├── Cargo.toml
    ├── Stylus.toml
    ├── src/
    │   ├── lib.rs             #[storage] + #[entrypoint]
    │   ├── main.rs            export-abi binary target
    │   └── dafny_bridge.rs    ABI ↔ Dafny translation
    └── tests/
        └── bridge_integration.rs
```

### The bridge

`dafny_bridge.rs` is the only place where the ABI and the Dafny runtime
meet. It contains no domain logic: every entrypoint converts ABI values
to Dafny values, calls a Dafny function, and converts the result back.

The ABI is a flat mirror of the Dafny value objects. Sets become `T[]`,
maps become arrays of entry structs, datatype variants become a `uint8`
discriminant plus optional fields. The Dafny-side provenance witnesses
(`sourceReferences`, `sourceAuthorities`, `contributions`) never cross
the ABI: they are constructed internally by `AuthorizationCanBeAcceptedFull`
on each call.

### The pilot

The first entrypoint was `authorization_is_structurally_valid`, plus a
`ping` sanity check. It exercised a nested struct with a set across the
ABI, proving the full pipeline (Dafny → Rust → Stylus → ABI → Solidity)
end to end.

The surface has since grown to 21 entrypoints:

- **Validators** — `valid_account`, `valid_authorization_state`,
  `authorization_is_structurally_valid`, `valid_execution_context`.
- **Composed decisions** — `authorization_can_be_accepted_full`,
  `apply_policy_consumption`, `compute_effective_authority`.
- **Provisioning transitions** — the 13 `AccountTransitions` entrypoints
  (`register_credential`, `register_session`, `register_delegation`,
  `register_transitive_delegation`, `add_capability`, `remove_capability`,
  `set_restriction`, `remove_restriction`, `set_credential_authority`,
  `consume_replay_key`, `update_credential_status`,
  `update_session_status`, `update_delegation_status`).

Every transition returns `(AccountAbi, bool)`. The boolean is `true` when
the Dafny preconditions held and the transition applied; `false` means
atomic rejection, where the returned `AccountAbi` equals the input.

The harness is **stateless**: the `#[storage]` struct is empty. Every
entrypoint receives and returns the `AccountAbi` the caller supplies.
Persistence belongs to the caller.

### AbiType

An ABI struct declared inside `sol!` does not automatically implement
Stylus's `AbiType` trait. The `sol!` macro emits the Alloy encoders but
not the Stylus-side trait, which lives in `stylus-proc`.

To cross a custom struct through `#[public]`:

1. `alloy-sol-types` must be a direct dependency. The `sol!` macro
   expands to paths rooted at `alloy_sol_types::...`, and those paths
   must resolve in the crate where the macro is invoked.
2. `use stylus_sdk::prelude::*;` must be in scope. The `AbiType` derive
   comes from the prelude.
3. Every custom struct inside `sol!` needs `#[derive(Debug, AbiType)]`.

Without (3), the build fails with `the trait bound X: AbiType is not
satisfied`. Without (2), with `cannot find derive macro AbiType in this
scope`. Without (1), with `unresolved import alloy_sol_types`.

These three together are the complete set. Removing any one produces a
distinct error message, which makes the failure modes easy to
distinguish.

### Reproducing

```bash
cd tools/stylus_workspace/harness
cargo test --test bridge_integration
cargo stylus check
cargo stylus export-abi
```

`cargo test --test bridge_integration` runs 104 tests against the
generated Dafny-Rust runtime. No VM is involved; the tests are
in-process.

`cargo stylus check` compiles the crate to `wasm32-unknown-unknown` and
reports the contract size (currently 62.9 KB across 3 fragments). It
also attempts to contact a node at `localhost:8547` for the codehash;
without one, that last step fails with a connection error, which is
environmental and not a build failure.

`cargo stylus export-abi` prints the Solidity interface for the 21
entrypoints.

### Environment

The workspace pins Rust 1.94.0 and the `wasm32-unknown-unknown` target.
Stylus SDK 0.10.9 requires `--enforce-determinism` on the Dafny side,
which the production exporter already enables.

`cargo stylus --version` should report `stylus 0.10.9`, matching the
SDK version pinned in the harness `Cargo.toml`.

The `export-abi` binary target follows the same pattern as the production
Kipio contracts: `src/main.rs` calls `print_from_args()`, which the SDK's
`#[entrypoint]` macro generates when the `export-abi` feature is enabled.

## End-to-end reproduction

The pipeline runs in four stages: verify the canonical formal model,
export the Rust crate, verify the annotated runtime tree, run the Stylus
harness.

Every command runs from the `formal/` directory unless the step itself
changes directory.

### 1. Verify the canonical formal tree

```bash
cd formal
dafny verify $(find . -type f -name '*.dfy' | sort)
```

Expected: `Dafny program verifier finished with 1461 verified, 0 errors`.

### 2. Export the Rust crate

```bash
python3 tools/export_rust_production.py --no-verify
```

The `--no-verify` flag skips the repository-wide verification that
stage 1 already covered. Drop the flag to have the exporter verify the
original tree as part of the same run.

The exporter:

- copies the runtime `.dfy` tree into `generated/dfy-annotated/`,
- injects the compositions from `tools/dafny_inject/`,
- annotates the five abstract types with `{:extern}`,
- obtains `dafny_runtime`,
- translates the synthesized aggregator in a single invocation,
- fixes the Dafny-4.11 trait-object casts,
- injects the extern types into their modules,
- runs `cargo check --offline` on the assembled crate.

Expected tail:

```text
== cargo check --offline ==

status        : COMPILED
detail        : cargo check succeeded

Production export completed successfully.
```

### 3. Verify the annotated runtime tree

```bash
cd generated/dfy-annotated
dafny verify $(find . -type f -name '*.dfy' | sort)
cd ../..
```

Expected: `Dafny program verifier finished with 686 verified, 0 errors`.

Obligatory whenever the DDD or the injects are modified, since it covers
the executable subset that feeds the Rust translation.

### 4. Run the Stylus harness

```bash
cd tools/stylus_workspace/harness
cargo test --test bridge_integration
cargo stylus check
cargo stylus export-abi
```

Expected:

- `cargo test` runs 104 tests, all passing.
- `cargo stylus check` reports `62.9 KB (3 fragments)`. The trailing
  `error sending request for url (http://localhost:8547/)` is
  environmental: the CLI tries to estimate the activation fee against a
  local node and there is none. It is not a build failure.
- `cargo stylus export-abi` prints the Solidity interface for the 21
  entrypoints.

### Full pipeline as one line

For scripting or CI, the four stages compose as:

```bash
cd formal && \
  dafny verify $(find . -type f -name '*.dfy' | sort) && \
  python3 tools/export_rust_production.py --no-verify && \
  (cd generated/dfy-annotated && dafny verify $(find . -type f -name '*.dfy' | sort)) && \
  cd tools/stylus_workspace/harness && \
  cargo test --test bridge_integration && \
  cargo stylus check && \
  cargo stylus export-abi
```

The `cargo stylus check` step will exit non-zero if no node is listening
at `localhost:8547`. In CI, either run a node or replace the step with
`cargo build --target wasm32-unknown-unknown --release`, which performs
the compilation without the activation-fee probe.

## Current status

```text
Canonical formal tree
  57 Dafny source files
  1461 verified
  0 errors

Annotated runtime tree (generated, with injects)
  29 runtime sources
  5 injected compositions
  686 verified
  0 errors

Rust materialization
  cargo check: COMPILED
  cargo build: COMPILED

Stylus harness
  21 public entrypoints
  104 integration tests passing
  cargo stylus check: 62.9 KB (3 fragments)
  cargo stylus export-abi: valid Solidity interface
```

The current repository state represents the Kipio Account domain as a
formally specified, mechanically verified semantic model with a working
Rust materialization and a working Stylus contract that exposes it.

The formal layer is intentionally kept independent from the concrete
implementation layer so that domain meaning can remain stable while
execution technology evolves.

## Design principle

The central principle of this formalization is:

```text
Meaning first.
Implementation second.
Verification throughout.
```

The domain model defines what must be true.

The implementation determines how that truth is materialized.

Dafny provides evidence that the encoded properties hold.

Rust materializes the verified decision.

Stylus and Arbitrum deliver it on-chain.

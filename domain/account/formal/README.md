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
             Proofs        Humans      Future AI
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
* **Rust materializes the domain model.**
* **Stylus provides the execution environment.**
* **Arbitrum provides the current target chain.**

They do not need to have identical levels of minimality. The formal model exists to preserve semantic boundaries and prove properties, not to mechanically mirror every implementation detail.

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
├── dfy-annotated/       the runtime tree with {:extern} annotations applied
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

`context.py` produces a consolidated formal context suitable for inspection and analysis.

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
2. **Annotate the five abstract types** in the copy with `{:extern}`.
3. **Obtain `dafny_runtime`** once via a single `--include-runtime` translation.
4. **Translate all runtime sources in a single invocation.** Dafny treats the inputs as one program and emits each Dafny module exactly once.
5. **Inject the five Rust extern types** into their corresponding generated modules, so each module is self-contained.
6. **Generate `src/lib.rs`** with a single `include!` directive.
7. **Run `cargo check --offline`** on the assembled crate.

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

The production exporter rewrites the pattern deterministically: it captures the closure's declared return type and substitutes it into the trait object. Twelve occurrences are fixed in the current formalization.

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

### What this boundary does not do

The generated Rust crate exposes the Dafny domain as a normal Rust library. It does not yet integrate with any blockchain runtime.

The following belong to a later phase and are intentionally outside the scope of these exporters:

* Stylus entry points and ABI types
* `cargo stylus check` and `cargo stylus build`
* Type mapping between Dafny value semantics and ABI-friendly representations
* Storage layout for on-chain state
* WASM artifact inspection

The generic Rust boundary must be characterized first; it now is.

## Current status

```text
57 Dafny source files
1461 verified
0 verification errors

29 runtime sources
5 abstract types requiring {:extern}
24 natively translatable sources

Rust crate: cargo check and cargo build succeed under Dafny 4.11.0
```

The current repository state represents the Kipio Account domain as a formally specified, mechanically verified semantic model with a working generic Rust materialization.

The formal layer is intentionally kept independent from the concrete implementation layer so that domain meaning can remain stable while execution technology evolves.

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

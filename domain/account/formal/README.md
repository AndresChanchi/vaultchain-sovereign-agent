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
│   └── dependency_graph.py
├── dependencies.dot
├── dependencies.json
├── dependencies.svg
├── dependency-report.txt
└── README.md
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

## Current status

```text
57 Dafny source files
1461 verified
0 verification errors
```

The current repository state represents the Kipio Account domain as a formally specified and mechanically verified semantic model.

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

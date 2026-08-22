# Kipio Account Ubiquitous Language

## Provisional Domain Definition — Phase 2 Consolidated

> **Status:** Current semantic source of truth for the formalization of `Kipio Account`.
>
> This document reflects the domain decisions established during Phase 2.
> Implementation details may still evolve, but Dafny, Rust and blockchain representations must conform to these semantics rather than redefine them.

---

# 1. Domain Purpose

`Kipio Account` defines a primitive of **sovereign identity, authority, and execution over blockchain**.

Its purpose is to allow an application to determine:

1. which sovereign `Identity` is exercising authority;
2. what authority exists for that Identity;
3. which subject or mechanism may exercise that authority;
4. under what conditions it may be exercised;
5. what action the consuming context requests;
6. whether such exercise is authorized;
7. and how an authorized decision can be materialized on blockchain.

`Kipio Account` **does not define the meaning of business actions** of the consuming context.

The same model may be used by applications that work with:

* people;
* organizations;
* companies;
* agents;
* services;
* devices;
* or other subjects.

The domain is designed around blockchain because the sovereignty represented by `Identity` requires a shared environment in which relevant states and transitions can be verified without relying exclusively on a central authority.

However, the domain is not defined by:

* Ethereum;
* EVM;
* Arbitrum;
* Stylus;
* EIP-7702;
* ERC-4337;
* RIP-7560;
* a cryptographic curve;
* a wallet;
* a blockchain address;
* nor any other concrete implementation.

---

# 2. External Identity and Authentication Context

An application may have identities and authentication mechanisms external to `Kipio Account`.

Examples:

```text
email
phone
passkey
WebAuthn credential
OAuth identity
EOA
hardware authenticator
```

These elements belong to the external context and **are not automatically a Kipio `Identity`**.

Therefore:

```text
External Identity
    !=
Kipio Identity

Authentication Mechanism
    !=
Kipio Identity

Blockchain Address
    !=
Kipio Identity
```

An external mechanism may produce evidence that is subsequently recognized by a `Credential`.

The conceptual relationship is:

```text
External Identity / Authentication
        ↓
authentication evidence
        ↓
Credential
        ↓
Account recognition
        ↓
authority exercise
        ↓
blockchain execution
```

Loss or replacement of an external authentication mechanism **does not by itself imply the loss of the Kipio Identity**.

This allows an Identity to maintain sovereign continuity even when the mechanisms through which it can be exercised change.

---

# 3. Subject

A **Subject** represents the semantic actor to whom an Identity is attributed within Kipio.

It may represent:

* a person;
* an organization;
* a company;
* an agent;
* a service;
* a device;
* or another actor recognized by the consuming context.

Subject is not:

* an Identity;
* a Credential;
* an Account;
* a blockchain address;
* nor an authentication mechanism.

The distinction is:

```text
Subject
    =
semantic actor

Identity
    =
sovereign continuity within Kipio
```

A single Subject may be associated with multiple Identities:

```text
Subject
    ├── Identity A
    ├── Identity B
    └── Identity C
```

This allows, for example, the same person to have distinct sovereign identities for different contexts, or an organization to have different sovereign continuities for different functions.

### Cardinality

```text
Subject
    1
    │
    └──── 0..N
           Identities
```

Each `Identity` is attributed to exactly one `Subject`.

Within Kipio, `Subject` is a **Value Object / semantic actor descriptor**.

---

# 4. Identity

An **Identity** represents a sovereign continuity recognized by Kipio through which a Subject may exercise authority.

`Identity` is an **Entity**.

The identity of an Identity is independent of:

* Credentials;
* Accounts;
* cryptographic mechanisms;
* blockchain addresses;
* Account Abstraction standards;
* technical representations.

An Identity may control multiple Accounts:

```text
Identity A
    ├── Account A
    ├── Account B
    └── Account C
```

An Identity may also use multiple Credentials.

Changing, adding, suspending, revoking, or recovering a Credential **does not automatically create a new Identity**.

Creating or deleting an Account also does not automatically create a new Identity.

Changing the blockchain representation of an Account also does not automatically change the Identity.

### Identity Identifier

An Identity has its own stable and individual identity:

```text
IdentityId
```

### Cardinality

```text
Subject
    1
    │
    └──── 0..N
           Identity
```

---

# 5. Account

An **Account** is the operational component through which an Identity exercises authority over blockchain.

`Account` is an **Entity**.

An Account has its own identity:

```text
AccountId
```

AccountId is different from a blockchain address.

The Account maintains the operational state necessary to determine which exercises of authority may produce valid execution.

That state may include:

* Capabilities;
* Credentials;
* Credential Authorities;
* Sessions;
* Delegations;
* recognized Policy Effects;
* and relationships among those elements.

### Identity ↔ Account Cardinality

The sovereign relationship is:

```text
Identity
    1
    │
    └──── 0..N
           Accounts
```

Each Account has **exactly one sovereign Identity**.

Therefore:

```text
Account
    └── sovereign Identity = exactly one
```

A second Identity may receive authority to operate an Account through:

* Credential;
* Delegation;
* Session;
* or other recognized mechanisms.

That does not make the second Identity sovereign over that Account.

Therefore:

```text
Identity A ─────► Account X
     sovereign control

Identity B ─────► Account X
     authorized exercise
```

does not mean:

```text
Identity A ──┐
             ├──► Account X
Identity B ──┘
    co-sovereignty
```

The domain **does not allow multiple direct sovereign Identities over the same Account**.

Creating another Account creates another Entity even if it belongs to the same Identity.

---

# 6. Account Identity Representation

An Account may have a technical representation on a specific blockchain.

For example:

```text
Account
    ↓
EVM representation
    ↓
Address
```

Therefore:

```text
Account
    !=
Blockchain Address
```

A blockchain address represents how an Account is technically materialized.

It does not represent:

* the Identity;
* sovereignty;
* nor necessarily the AccountId.

Switching between compatible materialization mechanisms does not automatically create another Account as long as the same Entity lifecycle continues.

### Principle

```text
Identity
    ≠
Account
    ≠
Blockchain Address
```

---

# 7. Authority

**Authority** represents the effective ability to exercise particular Capabilities.

Authority does not necessarily constitute a persistent Entity.

It is a semantic relationship derived from:

* available Capabilities;
* Credential Authority;
* Sessions;
* Delegations;
* Restrictions;
* Policy Effects;
* Scope;
* temporal conditions;
* context;
* and other conditions in force.

Authority answers:

> **what may be exercised, by whom, and under what conditions.**

Authority does not define how cryptographic evidence is produced.

---

# 8. Capability

A **Capability** represents an ability that may be exercised by an Identity or derived authority.

Capability expresses:

> **what ability exists.**

Examples:

```text
Upload
Delete
Share
Transfer
Approve
Delegate
Manage
```

The specific meaning of a Domain Action remains the responsibility of the consuming bounded context.

A Capability may be limited by:

* Scope;
* Restrictions;
* Session;
* Delegation;
* temporal conditions;
* context;
* Policy Effects;
* and other recognized rules.

## Capability as Value Object

`Capability` is a **Value Object**.

Two Capabilities with exactly the same semantic content represent the same ability:

```text
Capability A
    ==
Capability B
```

There is no separate individual identity for:

```text
Upload(Album123)
```

Therefore `Capability` **does not need a `CapabilityId`**.

This means:

```text
Capability
    =
ability

Credential / Delegation / Authorization
    =
mechanisms through which that ability may be exercised
```

Revoking a Credential does not revoke the semantic existence of the Capability; it only prevents that Credential from continuing to use it.

### Principle

> **A Capability is an ability by value, not an individual historical grant.**

---

# 9. Capability Kind

A **Capability Kind** identifies the semantic class of a Capability.

Examples:

```text
Upload
Delete
Share
Transfer
Approve
```

Capability Kind:

* does not grant authority;
* does not represent an execution;
* does not identify a specific Capability.

`CapabilityKind` is a **Value Object**.

Its meaning depends on its values.

---

# 10. Capability Scope

The **Capability Scope** determines the set of resources, objects, subjects, or areas over which a Capability may be exercised.

Scope expresses:

> **where the ability may be exercised.**

Example:

```text
Capability:
    Upload

Scope:
    Album #123
```

Scope is a **Value Object**.

It must not be confused with `Execution Target`:

```text
Capability Scope
    =
where authority exists

Execution Target
    =
where execution is technically materialized
```

---

# 11. Capability Metadata

**Capability Metadata** contains descriptive information associated with a Capability.

It may be used for:

* presentation;
* classification;
* organization;
* discovery;
* UX;
* integration.

Metadata does not by itself modify authority.

It may be:

* public;
* private;
* encrypted;
* protected through zero-knowledge proofs;
* or other mechanisms.

The Account does not determine the privacy mechanism.

### Invariant

> **Modifying Metadata does not by itself modify the authority represented by a Capability.**

---

# 12. Credential

A **Credential** is a source recognized by an Account through which evidence may be produced to exercise authority.

The Credential does not identify the Identity. The Credential is a recognized source through which authority associated with an Identity may be exercised. Therefore, any deterministic mechanism that derives an Account must be based on the continuity of the sovereign Identity, or on a deterministic resolution toward it, and not directly on a Credential that may be replaced during the Identity lifecycle.

`Credential` is an **Entity**.

A Credential has individual continuity during its lifecycle:

```text
active
→ suspended
→ reactivated
→ revoked
```

Revoking a Credential does not create another Credential.

A Credential may be based on:

* passkey;
* WebAuthn;
* secp256k1;
* P-256;
* hardware;
* multisig;
* threshold cryptography;
* future mechanisms;
* or other mechanisms.

The domain does not identify a Credential with any of those mechanisms.

### Credential ≠ Identity

A Credential does not represent sovereignty.

A Credential does not become an Identity by producing a Proof.

### Credential ≠ Account

A Credential is not an Account either.

It is a recognized source through which certain capabilities may be exercised over one or more Accounts.

---

# 13. Credential ↔ Account Recognition

The relationship between Credential and Account is **contextual and explicit in Authorization State**.

A Credential may be recognized by one or more Accounts.

Therefore:

```text
Credential A
    ├── recognized by Account A
    ├── recognized by Account B
    └── recognized by Account C
```

Recognition is independent for each Account.

A Credential recognized by an Account does not acquire sovereignty over it.

Nor does it imply that the Accounts share sovereignty.

The semantic relationship is:

```text
Credential
    │
    ├── Account A → Credential Authority A
    ├── Account B → Credential Authority B
    └── Account C → Credential Authority C
```

Therefore, the same Credential may have different authorities depending on the Account in which it is recognized.

### Credential ↔ Identity

The sovereign Identity belongs to the Account.

A Credential may be used as a mechanism to exercise authority associated with the sovereign Identity of the Account or authority derived from it and recognized by it.

The Credential **does not need to contain the Identity as part of its structural identity**.

This preserves the separation:

```text
Identity
    =
sovereign continuity

Credential
    =
recognized authority-exercise source

Account
    =
operational authority state
```

---

# 14. Credential Authority

**Credential Authority** represents the set of Capabilities that a Credential may attempt to exercise within a specific Account.

Credential Authority is a **Value Object / authority relation value**.

Two Credentials may have the same Credential Authority:

```text
CredentialAuthority(A)
    ==
CredentialAuthority(B)
```

without being the same Credential.

### Invariant

```text
Requested Capability
    ∈
Credential Authority
```

is a necessary condition for a Credential to attempt to exercise that Capability.

It is not sufficient for authority to be effective.

Sessions, Delegations, Restrictions, Policies, and other conditions may subsequently reduce it.

### Principle

> **Credential Authority describes what a Credential may attempt to exercise over an Account; it does not grant sovereignty.**

---

# 15. Proof

A **Proof** is cryptographic evidence used to demonstrate that an Authorization was produced through the corresponding Credential.

Proof belongs to cryptographic infrastructure.

It does not define:

* Identity;
* Capability;
* Scope;
* Authority;
* Authorization validity.

### Principle

> **Proof validity is not authorization validity.**

---

# 16. Verifier

A **Verifier** verifies a Proof using a specific cryptographic mechanism.

It may use:

* P-256;
* secp256k1;
* BLS;
* post-quantum cryptography;
* or other mechanisms.

The Verifier determines:

> **whether the evidence satisfies the cryptographic rules of its mechanism.**

It does not determine:

> **whether the exercise of authority is permitted.**

---

# 17. Requested Authority

**Requested Authority** represents the authority that an Authorization attempts to exercise.

It may include:

* Capabilities;
* Scope;
* Restrictions;
* temporal conditions;
* context;
* and other relevant conditions.

Requested Authority is a **Value Object**.

It does not grant authority.

It only represents what an Authorization requests to exercise.

---

# 18. Authorization

An **Authorization** represents a request or verifiable evidence of the exercise of authority.

It contains or references:

* Credential;
* Requested Authority;
* Restrictions;
* temporal conditions;
* Replay Protection;
* Proof;
* relevant context.

Authorization is a **Value Object**.

Two Authorizations are equal when they have the same complete semantic value.

It does not need an `AuthorizationId`.

### Main Rule

An Authorization may be accepted only when:

```text
Requested Authority
    ⊆
Effective Authority
```

and the other Authorization Validation conditions are satisfied.

Therefore:

```text
Valid Proof
    ≠
Valid Authorization
```

### Replay

`replayKey` or any equivalent mechanism forms part of Replay Protection.

It must not automatically be confused with an Entity identity.

---

# 19. Authorization Validation

**Authorization Validation** determines whether an Authorization may be accepted by an Account in a given state and context.

It must consider:

1. recognized Credential;
2. valid Proof;
3. compatible Credential Authority;
4. existing Capabilities;
5. Scope;
6. Restrictions;
7. Sessions;
8. Delegations;
9. Policy Effects;
10. temporal conditions;
11. Replay Protection.

### Principle

> **Proof Verification validates cryptographic evidence; Authorization Validation determines domain authority.**

Authority validation may be distributed among different bounded contexts or modules.

---

# 20. Session

A **Session** is temporary authorization derived from a Credential.

`Session` is an **Entity**.

It maintains identity throughout its lifecycle:

```text
active
→ expired

active
→ revoked
```

Expiration or revocation does not create another Session.

A Session may limit:

* Capabilities;
* Scope;
* duration;
* frequency;
* value;
* context;
* recipients;
* other conditions.

### Invariant

```text
Session Authority
    ⊆
Credential Authority
```

A Session can never expand the authority of its source Credential.

If the Credential ceases to be valid, Sessions dependent on it cease to be able to produce valid Authorization.

---

# 21. Delegation

A **Delegation** allows authority to be derived toward another Subject under explicit conditions.

`Delegation` is an **Entity**.

It maintains identity throughout its lifecycle:

```text
active
→ revoked
```

Revoking a Delegation does not create another Delegation.

It does not automatically transfer:

* Identity;
* sovereignty;
* ownership of the original Capabilities.

### Invariant

```text
Delegated Authority
    ⊆
Delegatable Authority of source
```

Delegated authority can never exceed the authority that the source may legitimately delegate.

---

# 22. Delegatee

A **Delegatee** is the Subject that receives derived authority through a Delegation.

It may represent:

* person;
* organization;
* agent;
* service;
* device;
* Account;
* another Subject.

Delegatee does not mean sovereign owner.

---

# 23. Restriction

A **Restriction** limits the conditions under which a Capability may be exercised.

Restriction is a **Value Object**.

It does not create new Capabilities.

It may limit:

* amount;
* value;
* frequency;
* time;
* recipient;
* Scope;
* context;
* operation type;
* number of executions.

Example:

```text
Spend
    +
maximum_value = X
    +
valid_until = T
```

Its meaning depends on its values.

---

# 24. Effective Authority

**Effective Authority** represents the authority that may actually be exercised in a specific context.

It is a **derived, contextual, and by-value** representation.

Conceptually:

```text
Account Capabilities
        ∩
Credential Authority
        ∩
Session Authority
        ∩
Delegated Authority
        ∩
Scope Conditions
        ∩
Restrictions
        ∩
Temporal Conditions
        ∩
Applicable Policy Effects
        ↓
Effective Authority
```

Effective Authority does not need its own identity.

The same Credential may produce different Effective Authorities depending on:

* Account;
* Session;
* Delegation;
* Scope;
* time;
* Restrictions;
* Authorization State;
* Policy Effects;
* Execution Context.

---

# 25. Authorization State

**Authorization State** represents the operational authorization state maintained by an Account.

It may contain:

* Credentials;
* Credential ↔ Account recognition;
* Credential Authorities;
* Sessions;
* Delegations;
* Capabilities;
* Restrictions;
* recognized Policy Effects;
* structural relationships necessary to evaluate authority.

Authorization State does not represent an execution.

Authorization State is the state from which Effective Authority is resolved.

### Important

`Credential`, `Session`, `Delegation`, `Capability`, etc. may exist as independent concepts, but **the relationships between them belong to Authorization State when those relationships are part of the operational state of an Account**.

This avoids artificially introducing those relationships inside the value objects.

---

# 26. Authorization State Transition

An **Authorization State Transition** represents a valid change to Authorization State.

Examples:

* register Credential;
* recognize Credential in Account;
* establish Credential Authority;
* modify Credential Authority;
* revoke Credential;
* create Session;
* revoke Session;
* create Delegation;
* revoke Delegation;
* modify Capabilities;
* apply Policy Effect.

These transitions belong to the Account domain.

They do not represent business executions over external resources.

---

# 27. Policy

A **Policy** represents an external decision recognized by Account as capable of producing one or more changes to Authorization State.

The Policy **does not need its own identity within Account**.

In external contexts, an Entity may exist that represents the procedure that produced that decision.

For example:

```text
RecoveryPolicyRequest
```

may be an Entity of the Recovery bounded context with:

* requestId;
* lifecycle;
* approval;
* expiration;
* cancellation;
* consumption.

But:

```text
RecoveryPolicyRequest
    ≠
Policy Effect
```

and:

```text
RecoveryPolicyRequest
    ≠
Account Policy Value
```

Account consumes the recognized decision; it does not need to know the entire lifecycle of the producing bounded context.

---

# 28. Policy Effect

A **Policy Effect** represents the semantic change that a Policy produces over Authorization State.

Examples:

```text
RevokeCredential(X)
EnableRecovery
DisableCapability(Y)
ModifyAuthorizationCondition(Z)
```

`PolicyEffect` is a **Value Object**.

Two different Policies may produce the same effect:

```text
PolicyRequest #1
    → RevokeCredential(X)

PolicyRequest #2
    → RevokeCredential(X)
```

and:

```text
RevokeCredential(X)
    ==
RevokeCredential(X)
```

Historical identity belongs to the external procedure, not to the effect.

---

# 29. Policy Consumption

**Policy Consumption** represents the recognition and application of a Policy by Account.

Conceptually:

```text
External Policy
      ↓
Policy Recognition
      ↓
Policy Consumption
      ↓
Policy Effect(s)
      ↓
Authorization State Transition
```

Account does not need to know how the Policy was approved.

Approval belongs to the producing bounded context.

A Policy may produce **one or more Policy Effects**.

The semantics of:

* atomicity;
* ordering;
* idempotency;
* duplication;
* partial consumption;

belong to the formalization of Policy Consumption and Account Transitions.

`PolicyConsumption` is a **Value Object / transition value** as long as no historical lifecycle of its own is discovered within Account.

---

# 30. Domain Action

A **Domain Action** represents a concrete intention of the consuming bounded context.

Examples:

```text
UploadPhoto
DeletePhoto
TransferFunds
ApprovePayroll
CreateInvoice
ShareAlbum
```

Kipio Account does not define:

* the catalog;
* the meaning;
* the lifecycle;
* the internal identity;
* the business rules.

Domain Action is an **external Value Object**.

Kipio only needs a sufficient representation to determine whether authority exists to execute the action.

---

# 31. Execution Request

An **Execution Request** represents a request to materialize a Domain Action.

It may contain:

* Domain Action;
* Authorization;
* Requested Authority;
* Execution Target;
* Execution Constraints;
* context required by Runtime.

Execution Request is a **Value Object / request value**.

It does not represent a materialized Execution.

---

# 32. Execution Target

An **Execution Target** identifies the technical destination on which execution will be materialized.

It may represent:

* contract;
* resource;
* service;
* infrastructure;
* or another compatible destination.

It does not define Authority.

The difference is:

```text
Capability Scope
    =
where authority exists

Execution Target
    =
where execution is materialized
```

---

# 33. Execution Context

An **Execution Context** represents the complete and validated decision necessary for an execution to be materialized.

It may incorporate the results of:

* Authorization;
* Effective Authority;
* Authorization State;
* Policy Effects;
* Restrictions;
* Execution Constraints;
* Domain Action;
* Execution Target;
* and other relevant conditions.

A valid Execution Context means:

> **the required authority and necessary conditions have been evaluated and execution may proceed under that context.**

The Execution Context is a **Value Object / complete execution decision**.

The Execution Engine receives only valid contexts.

It does not decide Authority again.

---

# 34. Execution Constraints

**Execution Constraints** represent conditions that must be satisfied to materialize an Execution Context.

They may include:

* limits;
* temporal conditions;
* atomicity;
* operational limits;
* materialization conditions;
* other recognized restrictions.

Execution Constraints do not create Authority.

They only condition the materialization of an authorized decision.

---

# 35. Runtime

The **Runtime** is the transient component that **orchestrates the distributed evaluation and operational materialization** of a request.

The Runtime:

1. receives an Execution Request;
2. coordinates obtaining the relevant Authorization State;
3. coordinates Authorization validation;
4. coordinates determination of Effective Authority;
5. coordinates application of relevant Policy Effects and Restrictions;
6. verifies Execution Constraints;
7. constructs Execution Context;
8. delivers only valid contexts to the Execution Engine.

### Important

Runtime **is not the owner of all authority rules**.

Evaluation may be distributed among bounded contexts or specialized modules, for example:

```text
Authentication / Credential Verification
Authorization
Recovery
Access
Registry
Economics
Execution Gateway
```

Runtime coordinates those results.

Therefore:

```text
Runtime
    =
Authority / Execution Orchestration
```

not:

```text
Runtime
    =
owner of every authorization rule
```

---

# 36. Execution Engine

The **Execution Engine** receives a valid Execution Context and transforms that decision into materializable operations.

Its conceptual input is:

```text
Execution Context
```

Not:

* interpret Credentials;
* decide Authority;
* create Authorization;
* define Domain Actions;
* redefine Policy;
* implement cryptographic rules.

Its responsibility is:

> **to materialize a decision that has already been made.**

It may produce one or multiple operations when the infrastructure supports:

* batching;
* multicall;
* atomicity;
* or other equivalent mechanisms.

---

# 37. Execution

An **Execution** represents the concrete process/materialization of an authorized action.

It is not currently an Entity of the `Account domain`.

The current architecture distinguishes:

```text
Execution Request
        ↓
Execution Context
        ↓
Runtime orchestration
        ↓
Execution Engine
        ↓
Adapter
        ↓
physical execution
```

An execution may consist of:

```text
one operation
```

or:

```text
multiple operations
```

The infrastructure determines how the following are guaranteed:

* atomicity;
* integrity;
* replay protection;
* constraint compliance.

### Lifecycle

Runtime may have an operational lifecycle:

```text
Validation
→ PreFlight
→ Accounting
→ Dispatch
→ Settlement
```

and results such as:

```text
Completed
Reverted
Aborted
Expired
Cancelled
Failed
```

but these represent **the lifecycle of the operational workflow**, not a persistent `Execution` Entity of the Account domain.

Therefore:

```text
Execution
    ≠
Execution Entity
```

and no `ExecutionId` is introduced.

---

# 38. Adapter

An **Adapter** materializes an Execution over a specific infrastructure.

Examples:

* EIP-7702;
* ERC-4337;
* RIP-7560;
* future forms of Account Abstraction;
* other compatible infrastructures.

The Adapter transforms:

```text
Kipio Execution Semantics
        ↓
Infrastructure primitives
```

and not the other way around.

### Principle

> **The domain defines what a valid execution means; the Adapter defines how to materialize it over a specific infrastructure.**

---

# 39. Blockchain

**Blockchain** is part of the fundamental context of Kipio.

It provides the shared environment where Accounts may:

* exercise authority;
* produce verifiable changes;
* materialize executions.

Kipio does not abstract away the existence of blockchain.

It abstracts the differences between the concrete infrastructures used to operate over it.

```text
Blockchain
    ≠
Ethereum
    ≠
EVM
    ≠
Arbitrum
    ≠
Stylus
    ≠
EIP-7702
    ≠
ERC-4337
```

---

# 40. Gas Payment

**Gas Payment** represents the provision of the economic resources necessary to materialize an Execution.

Gas Payment is independent of Authority.

An entity may pay for an Execution without acquiring authority over it.

```text
Authority
    ≠
Gas Payment
```

Paying does not grant authorization.

---

# 41. Execution Sponsor

An **Execution Sponsor** provides resources to pay for an Execution on behalf of another subject.

The Sponsor does not automatically acquire Authority.

Concrete mechanisms may include:

* relayers;
* paymasters;
* sponsored accounts;
* native mechanisms;
* or others.

Sponsorship belongs to infrastructure/economics.

---

# 42. Replay Protection

**Replay Protection** ensures that an Authorization or Execution cannot be reused outside the conditions for which it was created.

It may depend on:

* replay keys;
* nonces;
* sequence numbers;
* expiration;
* consumption markers;
* state;
* temporal conditions;
* or other mechanisms.

The domain requires:

> **A valid Authorization in one context must not automatically become a valid Authorization in a later or different context when its original conditions are no longer satisfied.**

Replay Protection does not imply that an `Authorization` Entity exists.

Its operational state may belong to Authorization State or to a specific replay state.

---

# 43. Authentication

**Authentication** is the process through which evidence is obtained that a Credential corresponds to the mechanism or subject attempting to exercise it.

Authentication is not equivalent to Authorization.

```text
Authentication
    =
who / what produced the evidence

Authorization
    =
what authority may be exercised
```

Successful authentication does not automatically grant a Capability.

---

# 44. Identity Sovereignty

**Identity Sovereignty** means that the sovereign continuity of an Identity does not depend on the specific mechanism through which its authority is authenticated, exercised, delegated, or materialized.

This implies:

* changing Credentials does not automatically change Identity;
* changing Accounts does not automatically change Identity;
* changing blockchain representation does not automatically change Identity;
* Delegation does not automatically transfer sovereignty;
* a Sponsor does not acquire Authority by paying;
* a cryptographic mechanism does not define Identity;
* an address does not define Identity.

Sovereignty belongs to `Identity`.

---

# 45. Authority Abstraction

**Authority Abstraction** is the ability to represent:

```text
who may exercise
what authority
under what conditions
```

without requiring the conceptual model to know:

* cryptographic curve;
* wallet;
* authentication provider;
* specific blockchain;
* Account Abstraction standard;
* address representation;
* or another implementation.

Authority Abstraction does not mean removing blockchain from the model.

It means abstracting the concrete implementations through which authority is exercised over blockchain.

---

# 46. Entity and Value Object Classification

The consolidated classification is:

## Entities

```text
Identity
Account
Credential
Session
Delegation
```

These entities have their own individual identity and continuity/lifecycle.

Their identifiers are:

```text
IdentityId
AccountId
CredentialId
SessionId
DelegationId
```

## Value Objects

```text
Subject
Capability
CapabilityKind
Scope
Restriction
CredentialAuthority
EffectiveAuthority
RequestedAuthority
Authorization
Policy
PolicyEffect
PolicyConsumption
DomainAction
ExecutionRequest
ExecutionContext
ExecutionConstraints
Timestamp
```

## Operational / Infrastructure Concepts

```text
Proof
Verifier
Runtime
Execution Engine
Execution
Adapter
Blockchain
Gas Payment
Execution Sponsor
Authentication
```

The latter must not be artificially given Entity identity within the Account domain.

---

# 47. Identifier Semantics

An **Identifier** represents a stable reference used to distinguish an Entity whose individual identity is part of its semantics.

The current identifiers are:

```text
Identity       → IdentityId
Account        → AccountId
Credential     → CredentialId
Session        → SessionId
Delegation     → DelegationId
```

No identifiers of their own are assigned to:

```text
Capability
PolicyEffect
Authorization
ExecutionContext
DomainAction
Restriction
Scope
```

because their meaning is determined by their content.

### Identifier ≠ representation

An Identifier is not automatically:

* hash;
* nonce;
* address;
* B256;
* private key;
* public key;
* classification.

### Size

The domain does not currently establish:

```text
|Identifier| = 32 bytes
```

The physical representation may be defined by infrastructure without necessarily changing the semantics of the Identifier.

### Uniqueness

Each Entity must be distinguishable within the identity scope required by its lifecycle.

The concrete way to guarantee such uniqueness belongs to the design of the state and corresponding infrastructure.

### Generation

The domain does not require a single generation mechanism.

It may be:

* deterministic;
* random;
* derived;
* assigned;
* external;
* or another compatible mechanism.

---

# 48. Universal Account Stress Test

Every new abstraction must be justified through a real and recurring problem.

Before introducing a new Entity, Value Object, relationship, or rule, the following must be verified:

### 1. Real Problem

What concrete and recurring problem does it solve?

### 2. Reuse

Does it appear in more than one application or context?

### 3. Application Independence

Can it exist without knowing the specific business model of an application?

### 4. Infrastructure Independence

Can it be expressed without depending on a concrete implementation?

### 5. Composition

Can it be solved by composing existing concepts?

### 6. Semantics

Does it represent a domain reality or an implementation need?

### 7. Reuse Across Subjects

Can it be used with different types of Subject?

### 8. Identity Requirement

Does it need its own individual identity, or is its meaning completely determined by its values?

The absence of a clear need for identity must prevent the introduction of an artificial Identifier.

---

# 49. Official Architectural Principles

1. **Subject, Identity, Account, and Blockchain Address are different concepts.**

2. **External Identity and Authentication Mechanism are not automatically Kipio Identity.**

3. **Subject represents the semantic actor.**

4. **Identity represents sovereign continuity.**

5. **An Identity may control multiple Accounts.**

6. **Each Account has exactly one sovereign Identity.**

7. **Authorization of another Identity over an Account does not create co-sovereignty.**

8. **Account is a distinct Entity from a Blockchain Address.**

9. **Capability is a Value Object.**

10. **Capability expresses an ability and not an individual historical grant.**

11. **Capability does not need CapabilityId.**

12. **CapabilityKind and Scope are Value Objects.**

13. **Credential is an Entity independent of Identity.**

14. **A Credential may be recognized by one or more Accounts.**

15. **Credential recognition is specific to each Account.**

16. **Credential Authority is a Value Object that describes the authority a Credential may attempt to exercise over an Account.**

17. **A Credential does not acquire sovereignty by being recognized by an Account.**

18. **A Session is a temporary Entity derived from a Credential.**

19. **Session Authority can never exceed Credential Authority.**

20. **Delegation is an Entity with its own lifecycle.**

21. **Delegated Authority can never exceed the source's Delegatable Authority.**

22. **Restriction is a Value Object that limits existing authority.**

23. **Effective Authority is contextual, derived, and by value.**

24. **Authorization is a Value Object.**

25. **Authorization does not need AuthorizationId.**

26. **Requested Authority is a Value Object.**

27. **Proof Verification and Authorization Validation are different responsibilities.**

28. **A valid Proof does not imply a valid Authorization.**

29. **Policy is an external decision recognized by Account and does not need its own identity within Account.**

30. **RecoveryPolicyRequest or other historical entities belong to their producing bounded contexts.**

31. **PolicyEffect is a Value Object.**

32. **A Policy may produce one or more Policy Effects.**

33. **Policy Consumption produces recognized changes over Authorization State.**

34. **Authorization State contains operational relationships among Credentials, Accounts, Sessions, Delegations, Capabilities, and Policy Effects.**

35. **Authorization State Transition represents valid changes to that state.**

36. **Domain Action belongs to the consuming bounded context.**

37. **Execution Request is a Value Object.**

38. **Execution Context is a Value Object and represents a complete, already-validated decision.**

39. **Execution Constraints do not create Authority.**

40. **Runtime coordinates distributed authority evaluation and execution orchestration.**

41. **Runtime does not own all authorization rules.**

42. **Execution Engine materializes valid Execution Contexts and does not decide Authority.**

43. **Execution is an operational process/materialization, not an Entity of the Account domain.**

44. **No ExecutionId is introduced.**

45. **An Execution may produce multiple operations when the infrastructure supports batching, multicall, or atomicity.**

46. **Adapters materialize domain semantics over concrete infrastructures.**

47. **Blockchain is a fundamental part of the Kipio context.**

48. **Authentication, Authorization, and Gas Payment are different responsibilities.**

49. **Capability Scope and Execution Target are different concepts.**

50. **Metadata does not by itself modify authority.**

51. **Identifiers exist because certain Entities need individual identity.**

52. **Not every domain concept needs an Identifier.**

53. **An Identifier is not automatically a hash, nonce, address, B256, or cryptographic key.**

54. **The domain does not currently establish a specific Identifier size.**

55. **Replay Protection is a cross-cutting property and does not turn Authorization into an Entity.**

56. **A new abstraction must be justified by a real and recurring need.**

57. **Dafny formalization must be derived from DDD meaning and must not use Rust/EVM details to redefine the domain.**

---

# 50. Consolidated Conceptual Model

```text
                         EXTERNAL WORLD
                               │
                 ┌─────────────┴─────────────┐
                 │                           │
          External Identity          Authentication
          email / phone / EOA         mechanisms
                 │                           │
                 └─────────────┬─────────────┘
                               │
                         authentication
                           evidence
                               │
                               ▼
                           CREDENTIAL
                               │
                    recognized by Account
                               │
                               ▼
                           IDENTITY
                               │
                  sovereign ownership
                               │
                  ┌────────────┼────────────┐
                  │            │            │
               Account A    Account B    Account C
                  │            │            │
                  └────────────┼────────────┘
                               │
                     AUTHORIZATION STATE
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
   CAPABILITIES            CREDENTIALS            POLICIES
        │                      │                      │
        │              CREDENTIAL AUTHORITY       POLICY EFFECTS
        │                      │                      │
        │                   SESSIONS                 │
        │                      │                      │
        │                 DELEGATIONS                │
        │                      │                      │
        └──────────────────────┼──────────────────────┘
                               │
                         RESTRICTIONS
                               │
                               ▼
                     EFFECTIVE AUTHORITY
                               │
                    ┌──────────┴──────────┐
                    │                     │
              AUTHORIZATION         DOMAIN ACTION
                    │                     │
                    └──────────┬──────────┘
                               │
                      EXECUTION REQUEST
                               │
                               ▼
                            RUNTIME
                               │
                  distributed authority
                     / orchestration
                               │
                               ▼
                     EXECUTION CONTEXT
                               │
                               ▼
                      EXECUTION ENGINE
                               │
                               ▼
                            ADAPTER
                               │
                               ▼
                          BLOCKCHAIN
```

Cross-cutting infrastructure:

```text
Proof
Verifier
Authentication mechanisms
Replay Protection
Gas Payment
Execution Sponsor
Privacy mechanisms
Blockchain Address representations
```

---

# 51. Fundamental Domain Distinction

```text
SUBJECT
    =
SEMANTIC ACTOR

IDENTITY
    =
SOVEREIGN CONTINUITY

ACCOUNT
    =
OPERATIONAL COMPONENT THROUGH WHICH
AN IDENTITY EXERCISES AUTHORITY ON BLOCKCHAIN

CAPABILITY
    =
WHAT AUTHORITY EXISTS

CREDENTIAL
    =
RECOGNIZED SOURCE FOR PRODUCING
AUTHORIZATION EVIDENCE

CREDENTIAL AUTHORITY
    =
WHAT A CREDENTIAL MAY ATTEMPT TO EXERCISE
ON AN ACCOUNT

AUTHORIZATION
    =
WHAT AUTHORITY IS REQUESTED / EVIDENCED

RESTRICTION / SCOPE / SESSION / DELEGATION
    =
UNDER WHAT CONDITIONS

EFFECTIVE AUTHORITY
    =
WHAT MAY ACTUALLY BE EXERCISED IN CONTEXT

AUTHORIZATION STATE
    =
OPERATIVE AUTHORITY STATE

RUNTIME
    =
DISTRIBUTED AUTHORITY / EXECUTION ORCHESTRATION

EXECUTION CONTEXT
    =
COMPLETE VALID EXECUTION DECISION

EXECUTION ENGINE
    =
EXECUTION MATERIALIZATION

EXECUTION
    =
OPERATIONAL MATERIALIZATION PROCESS

ADAPTER
    =
INFRASTRUCTURE-SPECIFIC MATERIALIZATION
```

And the fundamental separations:

```text
External Identity
    ≠
Subject
    ≠
Kipio Identity
    ≠
Account
    ≠
Blockchain Address
```

and:

```text
Capability
    ≠
Credential Authority
    ≠
Effective Authority
    ≠
Authorization
    ≠
Execution
```

---

# 52. Closed Decisions of Phase 2

The second iteration has closed the following decisions:

```text
Subject
    → Value Object

Identity
    → Entity

Account
    → Entity

Capability
    → Value Object

CapabilityKind
    → Value Object

Scope
    → Value Object

Restriction
    → Value Object

Credential
    → Entity

CredentialAuthority
    → Value Object

Session
    → Entity

Delegation
    → Entity

EffectiveAuthority
    → Value Object

RequestedAuthority
    → Value Object

Authorization
    → Value Object

Policy
    → recognized external decision/value

PolicyEffect
    → Value Object

PolicyConsumption
    → Value Object / transition value

DomainAction
    → external Value Object

ExecutionRequest
    → Value Object

ExecutionContext
    → Value Object

ExecutionConstraints
    → Value Object

Execution
    → operational process, not Entity
```

And:

```text
Identity 1
    └── 0..N Accounts

Account 1
    └── exactly 1 sovereign Identity

Credential 1
    └── 0..N recognized Accounts

Subject 1
    └── 0..N Identities
```

---

# 53. Rule for Formalization

The formal priority is:

```text
DDD semantic invariant
        ↓
Dafny domain model
        ↓
formal law
        ↓
proof
        ↓
Rust / blockchain representation
```

Never:

```text
Rust / EVM convenience
        ↓
Dafny type
        ↓
DDD retrofitted afterwards
```

When Dafny encounters an ambiguity:

```text
Dafny ambiguity
      ↓
DDD clarification
      ↓
formal law
      ↓
proof
```

A domain ambiguity must not be resolved simply by introducing a convenient structure in Dafny.

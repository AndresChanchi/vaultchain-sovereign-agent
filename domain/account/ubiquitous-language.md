# Kipio Account Ubiquitous Language

## Domain Purpose

`Kipio Account` defines a primitive of **sovereign identity, authority, and execution over blockchain**.

Its purpose is to allow an application to determine:

1. who exercises an Identity;
2. what authority exists for that Identity;
3. who can exercise that authority;
4. under what conditions it can be exercised;
5. what concrete action is requested;
6. whether that action is authorized;
7. and how an authorized execution can be materialized on blockchain.

`Kipio Account` does not define the meaning of actions specific to an application.

An application can use the same model to represent users, organizations, companies, agents, services, or other subjects, as long as those subjects can exercise authority through an Identity.

The domain is designed around blockchain because the sovereignty modeled by `Identity` requires a shared environment in which relevant state and transitions can be verifiable without relying exclusively on trust in a central authority.

The domain, however, **is not defined by a blockchain, Account Abstraction standard, cryptographic mechanism, or concrete implementation**.

---

# 1. Identity

An **Identity** represents a sovereign subject recognized by the protocol.

An Identity is the entity over which authority exists and whose rights of exercise can be delegated, restricted, revoked, or recovered.

An Identity is not:

* a private key;
* a Credential;
* a specific address;
* a wallet;
* a Web2 application user account;
* a cryptographic mechanism;
* nor an authentication provider.

An Identity can be exercised through different Credentials without ceasing to be the same Identity.

The existence of an Identity is independent of the mechanism used to produce an Authorization.

### Invariant

Changing, adding, revoking, or recovering a Credential **does not imply creating a new Identity**, unless the protocol explicitly determines otherwise.

---

# 2. Account

An **Account** is the sovereign component through which an Identity exercises authority over blockchain.

The Account maintains the **operational state of authority** required to determine which exercise of authority can produce a valid execution.

The Account manages, among other elements:

* Capabilities;
* Credentials;
* Sessions;
* Delegations;
* state derived from Policies;
* and the relationships necessary between them.

The Account does not determine the meaning of actions specific to an application.

The Account is also not responsible for implementing a specific cryptographic mechanism or a specific standard for execution.

### Primary Responsibility

> **The Account manages the authority state required to allow authorized executions over blockchain.**

The Account does not itself execute an action simply because authority exists to perform it.

---

# 3. Authority

**Authority** represents the effective ability to exercise specific Capabilities.

Authority is not an independent entity that necessarily needs to be persisted.

It is a semantic relationship that may result from the combination of:

* Capabilities existing in an Account;
* Credential Authority;
* Sessions;
* Delegations;
* Restrictions;
* applicable Policies;
* and other conditions currently in effect.

Authority answers:

> **"What can this subject exercise in this context?"**

It does not answer:

> "How do they cryptographically prove that they are who they are?"

That belongs to Credential, Proof, and Verifier.

---

# 4. Capability

A **Capability** represents an ability that can be exercised by an Identity or by authority derived from it.

A Capability expresses **what authority exists**.

Conceptual examples may include:

* storing;
* transferring;
* sharing;
* administering;
* executing;
* delegating;
* modifying a certain class of resource.

The concrete meaning of a Capability belongs to the application using the domain.

`Kipio Account` does not need to know what a specific business action means.

A Capability may be limited by:

* Scope;
* Restrictions;
* time;
* Session;
* Delegation;
* context;
* or other conditions recognized by the domain.

### Principle

> **A Capability expresses an ability; it does not represent a concrete execution.**

---

# 5. Capability Kind

A **Capability Kind** identifies the semantic class of a Capability.

For example, an application may define:

```text
Upload
Delete
Share
Transfer
Approve
```

The Capability Kind expresses **what class of ability it represents**.

It does not by itself constitute a grant of authority.

An Account may know a Capability Kind without an Identity necessarily possessing a Capability of that type.

---

# 6. Capability Scope

The **Capability Scope** determines the set of resources, objects, subjects, or areas over which a Capability can be exercised.

Scope expresses:

> **"What can this ability be exercised over?"**

Scope belongs to the meaning of the authority.

For example:

```text
Capability:
    Upload

Scope:
    Album #123
```

means that the authority is limited to the scope represented by `Album #123`.

Scope does not necessarily identify where the action will be technically executed.

---

# 7. Capability Metadata

**Capability Metadata** contains descriptive information associated with a Capability that may be used by an application for presentation, classification, organization, or user experience.

Metadata does not by itself modify the authority represented by the Capability.

Metadata may contain information such as:

```text
label
description
created_by
application_context
```

Metadata should not automatically be interpreted as public or private.

### Privacy

The domain **may support private metadata**, including metadata protected through cryptographic mechanisms or zero-knowledge proofs.

The Account does not itself determine the mechanism through which an application protects metadata.

Therefore:

> **The metadata of a Capability may be public or private depending on the privacy model adopted by the application and the corresponding infrastructure.**

The fact that a Capability has metadata does not imply that such metadata must be publicly observable.

---

# 8. Credential

A **Credential** is a mechanism recognized by an Account through which an Identity can produce evidence of authorization.

The Account recognizes Credentials as valid sources of authority.

A Credential may use very different mechanisms to produce a valid Proof.

The domain does not need to know whether a Credential uses:

* passkey;
* secp256k1;
* P-256;
* hardware;
* multisig;
* threshold cryptography;
* a future mechanism;
* or another cryptographic method.

The Credential expresses:

> **"This is a recognized source through which authority for this Identity can be exercised."**

---

# 9. Credential Authority

**Credential Authority** is the set of Capabilities that a Credential is authorized to exercise for an Account.

Credential Authority allows different Credentials belonging to the same Identity to have different levels of authority.

For example:

```text
Identity A

Credential A
    Upload
    Share

Credential B
    Transfer

Credential C
    Recovery
```

A Credential cannot produce a valid Authorization for a Capability that is not within its current authority.

### Fundamental Relationship

```text
Account Capabilities
        ∩
Credential Authority
        ↓
Capabilities that the Credential can attempt to exercise
```

Credential Authority does not replace the other restrictions of the domain.

Sessions, Delegations, Restrictions, and Policies may reduce or modify the effective authority available.

---

# 10. Proof

A **Proof** is cryptographic evidence presented to demonstrate that an Authorization was produced through a valid Credential according to the corresponding mechanism.

Proof belongs to cryptographic infrastructure.

Proof does not define:

* what Capability exists;
* what an action means;
* what Scope is valid;
* nor what authority an Identity possesses.

A cryptographically valid Proof **does not by itself imply that an Authorization is valid**.

---

# 11. Verifier

A **Verifier** is the component responsible for verifying a Proof using a specific cryptographic mechanism.

Infrastructure examples may include:

* P-256;
* secp256k1;
* BLS;
* post-quantum mechanisms;
* or other future mechanisms.

The Verifier answers:

> **"Is the Proof valid according to this mechanism?"**

The Verifier does not by itself decide:

> "Is this action authorized?"

---

# 12. Authorization

An **Authorization** represents a request or verifiable evidence of exercising a particular authority.

An Authorization relates the authority intended to be exercised to the context necessary to determine whether that exercise is permitted.

An Authorization may contain or reference information such as:

* Credential;
* requested Capabilities;
* Scope;
* restrictions;
* context;
* temporal information;
* replay protection;
* and Proof.

An Authorization **does not execute an action**.

An Authorization also does not automatically create a Capability.

### Fundamental Rule

An Authorization is valid only when the authority attempting to be exercised is within the **Effective Authority** applicable to the context.

Formally:

```text
Requested Authority ⊆ Effective Authority
```

When this condition is not met:

```text
Valid Proof
        ≠
Valid Authorization
```

A correct signature over a Capability that the Credential cannot exercise remains an invalid Authorization.

---

# 13. Requested Authority

**Requested Authority** represents the authority that an Authorization attempts to exercise.

It answers:

> **"What authority is this Authorization attempting to exercise?"**

Requested Authority may include:

* Capability;
* Scope;
* Restrictions;
* context;
* temporality;
* and other relevant conditions.

Requested Authority does not grant authority.

It is a representation of what the Authorization requests to exercise.

---

# 14. Authorization Validation

**Authorization Validation** determines whether an Authorization can be accepted by the Account under the current state and context.

Validation must consider, at minimum:

1. that the Credential is recognized;
2. that the corresponding Proof is valid;
3. that the Credential can exercise the requested Capabilities;
4. that the Capabilities exist within the applicable authority state;
5. that Scope and Restrictions are compatible;
6. that Sessions and Delegations are applicable;
7. that current Policies have been considered;
8. that no temporal conditions are violated;
9. and that the Authorization cannot be reused outside the permitted conditions.

### Principle

> **Proof verification demonstrates the cryptographic authenticity of the evidence. Authorization Validation determines authority.**

---

# 15. Session

A **Session** is a temporary authorization derived from a Credential that allows a subset of the available authority to be exercised under additional restrictions.

A Session may limit:

* Capabilities;
* Scope;
* duration;
* frequency;
* value;
* context;
* recipients;
* or other conditions.

A Session must never expand the authority of the Credential from which it originated.

### Invariant

```text
Session Authority ⊆ Credential Authority
```

An expired or revoked Session cannot produce a valid Authorization.

---

# 16. Delegation

A **Delegation** allows an Identity to authorize another subject to exercise specific Capabilities under explicitly defined conditions.

Delegation does not necessarily transfer the Identity of the delegating party.

Delegation also does not imply that the delegatee becomes the owner of the original Capabilities.

Conceptually:

```text
Identity A
    │
    │ delegates authority
    ▼
Delegatee
```

Delegated authority is limited by the authority that the delegating party is able to delegate.

### Invariant

A Delegation cannot produce authority greater than the authority that the source Identity can legitimately delegate.

---

# 17. Delegatee

A **Delegatee** is the subject to whom a Delegation allows authority to be exercised.

The domain does not require the Delegatee to necessarily be:

* a person;
* an Account;
* an organization;
* a company;
* an agent;
* a service;
* or a device.

The semantic requirement is that it be an identifiable subject to whom the exercise of delegated authority can be attributed.

The concrete type of subject belongs to the application's context.

---

# 18. Restriction

A **Restriction** limits the conditions under which a Capability can be exercised.

A Restriction does not create a new Capability.

It may limit, among other things:

* quantity;
* value;
* frequency;
* time;
* recipient;
* Scope;
* context;
* operation type;
* number of executions.

For example:

```text
Capability:
    Spend

Restriction:
    maximum_value = X
    valid_until = T
```

This expresses a single ability with limiting conditions, not a new class of Capability.

---

# 19. Policy

A **Policy** is a decision produced by an external governance, recovery, or control mechanism that the domain recognizes as capable of producing specific changes to the operational state of an Account.

A Policy is not an ordinary Authorization.

A Policy is also not necessarily a rule that the Runtime evaluates on every execution.

A Policy may produce changes such as:

* revoking a Credential;
* enabling recovery;
* modifying an operational condition;
* activating or deactivating a derived capability;
* or other changes explicitly recognized by the domain.

The mechanism that produces or approves a Policy remains outside the responsibility of the Account.

### Principle

> **The Account consumes the recognized result of a Policy; the Account does not need to know the process through which that result was produced.**

---

# 20. Policy Consumer

The **Policy Consumer** is the responsibility in charge of interpreting a Policy accepted by the domain and reflecting its effects on the operational state of the Account.

The Policy Consumer does not necessarily participate in approving the Policy.

Its responsibility is:

```text
Policy
   ↓
interpretation
   ↓
Authorization State change
```

Approval and application of a Policy are conceptually distinct responsibilities.

---

# 21. Authorization State

The **Authorization State** is the operational state of an Account required to determine the authority available at a given point in time.

It includes, as applicable:

* Capabilities;
* Credentials;
* Credential Authorities;
* Sessions;
* Delegations;
* Restrictions;
* consumed effects of Policies;
* and other state required to evaluate authority.

Authorization State does not represent a concrete execution.

Its purpose is to provide the basis upon which the Runtime can determine effective authority.

---

# 22. Effective Authority

**Effective Authority** is the authority that can actually be exercised in a given context after applying all relevant conditions to the available Authorization State.

Conceptually:

```text
Account Capabilities
        ∩
Credential Authority
        ∩
Session Authority
        ∩
Delegation Authority
        ∩
Scope
        ∩
Restrictions
        ∩
Temporal Conditions
        ∩
Applicable Policies
        ↓
Effective Authority
```

Effective Authority is contextual.

The same Credential may produce different Effective Authorities depending on:

* Session;
* Delegation;
* Scope;
* time;
* Restrictions;
* operational state;
* or any other applicable condition.

---

# 23. Authorization State Transition

An **Authorization State Transition** is a valid change to the Authorization State of an Account.

Conceptual examples:

* registering a Credential;
* revoking a Credential;
* creating a Session;
* revoking a Session;
* creating a Delegation;
* revoking a Delegation;
* applying a Policy;
* modifying a Capability.

Authority transitions are part of the Account domain.

They must not be confused with application executions over external resources.

---

# 24. Domain Action

A **Domain Action** represents a concrete intention of an application that may require authorization.

`Kipio Account` **does not define what the Domain Actions of an application are**.

For example, an application may define:

```text
UploadPhoto
DeletePhoto
ShareAlbum
TransferFunds
ApprovePayroll
CreateInvoice
```

Another application may define completely different actions.

The Runtime does not need to know the internal meaning of those actions.

The domain only needs to receive a sufficiently precise representation to determine:

> **"Does the available authority allow this action to be executed under this context?"**

Therefore, Domain Action is a concept that may originate from the **consuming bounded context**.

It must not become a catalog of actions specific to Kipio Account.

---

# 25. Execution Request

An **Execution Request** represents a request to materialize a Domain Action through an execution over blockchain.

It may contain:

* Domain Action;
* application context;
* Requested Authority;
* Execution Target;
* restrictions;
* information required to construct the Execution Context.

An Execution Request does not yet constitute an execution.

It is the input that allows the Runtime to determine whether a requested action can be materialized.

---

# 26. Execution Target

An **Execution Target** identifies the concrete resource, contract, service, or infrastructure over which an Execution must be materialized.

Execution Target belongs to the materialization context.

It must not be confused with Capability Scope.

### Fundamental Difference

```text
Capability Scope
    = what authority exists over

Execution Target
    = where the execution is technically materialized
```

Example:

```text
Capability:
    Upload

Scope:
    Album #123

Execution Target:
    Storage Contract #ABC
```

Scope expresses domain meaning.

Execution Target expresses the concrete destination of materialization.

---

# 27. Execution Context

An **Execution Context** is the complete and validated representation of the state required to allow an execution.

It is constructed from:

* Execution Request;
* Authorization;
* Authorization State;
* Effective Authority;
* applicable Policies;
* Restrictions;
* context;
* and other necessary conditions.

A valid Execution Context represents a complete decision by the Runtime:

> **the requested action can be executed under the authority and restrictions currently in effect.**

The Execution Context is the **only valid input to the Execution Engine**.

The Execution Engine does not reinterpret authority.

---

# 28. Runtime

The **Runtime** is the component that maintains the operational behavior of an Account and determines whether an Execution Request can become a valid Execution Context.

The Runtime:

1. obtains the relevant Authorization State;
2. validates the presented Authorization;
3. determines the Effective Authority;
4. verifies the applicable restrictions;
5. constructs the Execution Context;
6. and delivers only valid contexts to the Execution Engine.

The Runtime **evaluates authority**.

It does not implement the cryptographic mechanism used to verify Proofs.

It does not directly materialize execution over a concrete infrastructure.

---

# 29. Execution Engine

The **Execution Engine** transforms a valid Execution Context into one or more verifiable execution operations.

Its input is exclusively:

```text
Execution Context
```

The Execution Engine does not:

* produce Authorizations;
* interpret Credentials;
* decide authority;
* implement cryptographic mechanisms;
* nor define the application's business rules.

Its responsibility is to transform a decision already made by the domain into a materializable execution.

---

# 30. Execution

An **Execution** is the concrete materialization of an authorized action.

An Execution occurs after the Runtime has produced a valid Execution Context.

An Execution may consist of one or more operations when the infrastructure allows it.

The domain may require properties for an Execution such as:

* atomicity;
* integrity;
* replay prevention;
* compliance with restrictions.

The concrete way of achieving these properties belongs to the execution infrastructure.

---

# 31. Adapter

An **Adapter** materializes an execution expressed in terms of Kipio using the primitives of a concrete infrastructure.

The Adapter adapts **the infrastructure to the domain's execution model**, not the other way around.

Examples may include:

* EIP-7702;
* ERC-4337;
* RIP-7560;
* future account abstractions;
* or other compatible mechanisms.

The Adapter does not modify the meaning of:

* Identity;
* Capability;
* Credential;
* Authorization;
* Delegation;
* Session;
* Effective Authority;
* Execution Context.

### Principle

> **The domain defines what a valid execution means; the Adapter defines how to materialize it over a specific infrastructure.**

---

# 32. Blockchain

**Blockchain** is a fundamental infrastructure of the Kipio domain because it provides the shared environment in which sovereign identities can exercise authority and produce verifiable state without relying exclusively on a central authority.

Kipio Account does not attempt to abstract away the existence of blockchain.

What it abstracts are the differences between specific mechanisms used to operate over it.

Therefore:

```text
Blockchain
    ≠
Ethereum
    ≠
EVM
    ≠
EIP-7702
    ≠
ERC-4337
    ≠
Stylus
```

Blockchain is part of the fundamental context of the domain.

Specific blockchain standards and mechanisms belong to the infrastructure.

---

# 33. Gas Payment

**Gas Payment** represents the provision of the economic resources required to materialize an Execution over blockchain.

Gas Payment is independent of Authority.

An entity may pay for an Execution without possessing authority over the action being executed.

Therefore:

```text
Authority
    ≠
Gas Payment
```

The domain must not interpret the ability to pay gas as an ability to authorize the execution.

---

# 34. Execution Sponsor

An **Execution Sponsor** is an entity that provides the resources required to pay for an Execution.

The Sponsor may act for the benefit of another subject without acquiring authority over the action.

The concrete mechanism may involve:

* relayers;
* paymasters;
* sponsoring accounts;
* native infrastructure mechanisms;
* or other systems.

These mechanisms are not part of the meaning of Authority.

---

# 35. Replay Protection

**Replay Protection** is the property by which an Authorization or Execution cannot be reused outside the conditions for which it was created.

Replay Protection may depend on:

* temporality;
* identifiers;
* sequences;
* nonces;
* state;
* expiration;
* or other mechanisms.

The domain requires the property:

> **A valid Authorization in one context must not automatically become a valid Authorization in a different or later context when the conditions for its use are no longer met.**

The domain does not require a specific nonce format.

---

# 36. Authentication

**Authentication** describes the process by which a system obtains evidence that a presented Credential corresponds to the subject or mechanism attempting to exercise it.

Authentication is not equivalent to Authorization.

```text
Authentication
    = "who produced the evidence?"

Authorization
    = "what authority can be exercised?"
```

Correct authentication does not grant a Capability that does not exist.

---

# 37. Identity Sovereignty

**Identity Sovereignty** is the principle according to which an Identity retains control over the exercise of its authority regardless of the specific mechanism through which that authority is authenticated, delegated, or materialized.

This implies that:

* changing Credentials should not automatically change the Identity;
* a Delegation should not automatically transfer the sovereignty of the Identity;
* an application should not automatically become the owner of the Identity;
* an Execution Sponsor does not acquire authority by paying;
* a specific infrastructure does not define the meaning of authority.

Sovereignty belongs to the Identity.

---

# 38. Authority Abstraction

**Authority Abstraction** is the ability of the domain to represent who can exercise what authority and under what conditions without requiring the conceptual model to know the specific cryptographic mechanism, wallet, authentication provider, or standard used to materialize that authority.

Authority Abstraction is an architectural property of the model.

It does not mean abstracting away blockchain.

It means abstracting **the concrete implementations used to exercise authority over blockchain**.

---

# 39. Universal Account Stress Test

Every new concept proposed for `Kipio Account` must be justified through a real and recurring problem.

Before introducing a new entity, concept, or relationship, these questions must be answered:

### 1. Real Problem

> What concrete and recurring problem does it solve?

### 2. Reusability

> Does the problem appear in more than one application or context?

### 3. Application Independence

> Can the solution exist without knowing the specific business model of an application?

### 4. Infrastructure Independence

> Can the solution be expressed without depending on Ethereum, EVM, EIP-7702, ERC-4337, Stylus, or another specific implementation?

### 5. Composition

> Can the problem be solved by composing existing concepts before introducing a new one?

### 6. Semantics

> Does the new concept represent a reality of the domain or merely an implementation need?

### 7. Reuse Across Subjects

> Can the concept be used by different types of subjects without creating unnecessary variants?

An abstraction that exists only to address a hypothetical future use case should not be incorporated into the core without evidence that it represents a real need of the domain.

---

# 40. Official Architectural Principles

The following principles are derived from this language:

1. **Identity represents the sovereign subject; a Credential represents a mechanism through which that Identity can produce evidence of authority.**

2. **The Account manages the authority state of an Identity over blockchain.**

3. **Capabilities represent abilities; they do not represent executions.**

4. **A Credential can exercise only the authority granted to it through its Credential Authority and the other conditions currently in effect.**

5. **An Authorization never creates authority by itself.**

6. **A cryptographically valid Proof does not imply a valid Authorization.**

7. **Proof Verification and Authorization Validation are distinct responsibilities.**

8. **Effective Authority is contextual and results from applying the current conditions to the available authority.**

9. **A Session can only reduce or restrict the authority that can be exercised by the Credential from which it originated.**

10. **A Delegation allows derived authority to be exercised without automatically transferring the sovereignty of the source Identity.**

11. **A Restriction limits existing authority; it does not need to create a new Capability.**

12. **Policies produce recognized effects on Authorization State, but the mechanism that produces those Policies remains outside the Account.**

13. **The Runtime evaluates authority and constructs valid Execution Contexts.**

14. **The Execution Engine does not decide authority; it materializes valid Execution Contexts.**

15. **Adapters materialize the domain's execution model over specific infrastructures.**

16. **Blockchain is a fundamental part of Kipio's domain context; specific blockchain standards and mechanisms belong to the infrastructure.**

17. **The domain must not depend on a specific Account Abstraction standard.**

18. **Authentication, Authorization, and Gas Payment represent different responsibilities and must not be conflated.**

19. **Domain Actions belong to the context of the application using Kipio Account; Account must not become a catalog of business actions.**

20. **Capability Scope expresses where authority exists in domain terms; Execution Target expresses where an execution is technically materialized.**

21. **The privacy of information associated with a Capability is a property that can be guaranteed through specific privacy mechanisms, but it must not be confused with the meaning of the authority itself.**

22. **A new abstraction must be justified by a real and recurring problem, not merely by a possible future use case.**

---

# 41. Summarized Conceptual Model

```text
                         IDENTITY
                            │
                            ▼
                         ACCOUNT
                            │
             ┌──────────────┼──────────────┐
             │              │              │
        CAPABILITIES    CREDENTIALS     POLICIES
             │              │              │
             │        CREDENTIAL           │
             │          AUTHORITY          │
             │              │              │
             │          SESSIONS           │
             │              │              │
             │        DELEGATIONS          │
             │              │              │
             └──────────────┼──────────────┘
                            │
                      RESTRICTIONS
                            │
                            ▼
                    EFFECTIVE AUTHORITY
                            │
              ┌─────────────┴─────────────┐
              │                           │
       AUTHORIZATION                DOMAIN ACTION
              │                           │
              └─────────────┬─────────────┘
                            │
                  EXECUTION REQUEST
                            │
                            ▼
                         RUNTIME
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
             ┌──────────────┼──────────────┐
             │              │              │
           7702            4337           7560
             │              │              │
             └──────────────┼──────────────┘
                            │
                            ▼
                       BLOCKCHAIN
```

Cross-cutting infrastructure:

```text
Proof
Verifier
Authentication mechanisms
Gas Payment
Execution Sponsor
Replay Protection
Privacy mechanisms
```

These responsibilities may participate in the system without thereby becoming central concepts of authority.

---

# 42. The Fundamental Distinction of the Domain

The architecture can be understood through three primary responsibilities:

```text
ACCOUNT
    =
AUTHORITY STATE

RUNTIME
    =
AUTHORITY EVALUATION

EXECUTION ENGINE
    =
EXECUTION MATERIALIZATION
```

And around them:

```text
Identity
    =
WHO

Capability
    =
WHAT AUTHORITY EXISTS

Credential
    =
WHO CAN PRODUCE AUTHORIZATION

Authorization
    =
WHAT AUTHORITY IS BEING EXERCISED

Restrictions / Scope / Session / Delegation
    =
UNDER WHAT CONDITIONS

Runtime
    =
IS THIS EXERCISE ALLOWED?

Execution Context
    =
COMPLETE VALID DECISION

Execution Engine
    =
HOW IS THAT DECISION MATERIALIZED?

Adapter
    =
HOW IS IT MATERIALIZED ON THIS INFRASTRUCTURE?
```

This separation constitutes the semantic core of `Kipio Account`.

The intention is not to remove blockchain from the model.

The intention is for **the meaning of authority to remain stable even when the specific way in which blockchain materializes that authority changes**.

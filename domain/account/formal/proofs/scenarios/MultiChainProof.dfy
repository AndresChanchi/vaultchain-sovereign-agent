// ============================================================
// KIPIO ACCOUNT DOMAIN
// SCENARIO — MULTI-CHAIN / CONTEXTUAL AUTHORITY
// ============================================================
//
// Adversarial scenario:
//
//   An Authorization carries a Chain value.
//   The EffectiveAuthority supplied for acceptance carries no Chain.
//   The scenario tests whether changing the Authorization Chain alone
//   changes the Authorization acceptance result.
//
// OBJECTIVE
//
//   Verify the architectural separation between:
//
//       Authorization semantic acceptance
//
//   and:
//
//       Environment-specific execution delivery.
//
//   The scenario examines the boundary:
//
//       Authorization Context
//            └── Chain
//
//   versus:
//
//       EffectiveAuthority
//            └── set<Capability>
//
//   and:
//
//       CredentialAuthority
//            └── set<Capability>
//
// The scenario formally verifies:
//
//   1. Chain is part of Authorization semantic structure.
//   2. EffectiveAuthority itself contains no Chain.
//   3. CredentialAuthority itself contains no Chain.
//   4. Authorization structural validity does not inspect Chain.
//   5. Authorization acceptance does not require a selected
//      ExecutionEnvironment.
//   6. Replacing the Chain value while preserving every other
//      Authorization field preserves the current acceptance result.
//   7. EffectiveAuthority provenance remains unchanged when Chain is
//      replaced, because identities, sourceAuthorities, and
//      contributions are preserved exactly.
//   8. Two semantically distinct Chain values can therefore produce
//      two accepted Authorizations when evaluated by the current
//      environment-independent Authorization acceptance contract.
//   9. This environment-independent acceptance is intentional: the
//      Authorization domain decides whether an authorization is valid
//      for the Account and its semantic conditions, while the later
//      execution boundary determines whether the resulting decision
//      can be materialized in a selected environment.
//
// ------------------------------------------------------------
//
// ARCHITECTURAL INTENT
//
// Authorization Acceptance and Environment Delivery are distinct
// semantic boundaries.
//
// Authorization Acceptance answers:
//
//     "May this Authorization be accepted by this Account
//      under the current authorization state and semantic
//      validation conditions?"
//
// It does NOT answer:
//
//     "Can this accepted decision be physically materialized
//      through this particular blockchain or infrastructure
//      environment?"
//
// The second question belongs to the execution boundary.
//
// Therefore the intentional architecture is:
//
//     Authorization
//          │
//          └── semantic Chain
//                    │
//                    ▼
//          Authorization Validation
//                    │
//                    ▼
//          accepted semantic decision
//                    │
//                    ▼
//          Execution Context
//                    │
//                    ▼
//          selected ExecutionEnvironment
//                    │
//                    ▼
//          Chain × Environment compatibility
//                    │
//                    ▼
//          Execution Engine delivery
//
// This separation prevents the semantic Authorization model from
// becoming coupled to a particular deployment, blockchain,
// Account Abstraction mechanism, bridge, messaging protocol,
// relayer, adapter or other infrastructure choice.
//
// ------------------------------------------------------------
//
// MULTI-CHAIN / INFRASTRUCTURE INDEPENDENCE
//
// The domain is intentionally designed so that the semantic
// authorization model is not vendor-locked to a particular
// execution technology.
//
// A concrete implementation may currently deploy or materialize
// through one environment, while future implementations may use
// other compatible environments or infrastructure mechanisms.
//
// Examples of infrastructure choices may include:
//
//   - Arbitrum;
//   - Ethereum;
//   - Solana;
//   - Polkadot;
//   - EVM-compatible environments;
//   - Stylus;
//   - ERC-4337;
//   - EIP-7702;
//   - future Account Abstraction mechanisms;
//   - cross-chain messaging infrastructure;
//   - other compatible adapters or execution mechanisms.
//
// These implementation choices do NOT redefine the semantic
// meaning of Authorization.
//
// In particular, the domain must not infer:
//
//     current deployment environment
//         =
//     semantic authorization universe
//
// Nor should a current infrastructure deployment cause
// Authorization Acceptance to become permanently coupled to that
// infrastructure.
//
// ------------------------------------------------------------
//
// CHAIN SEMANTICS
//
// Chain remains a semantic part of Authorization.
//
// This means:
//
//     Authorization A
//         Chain = chainA
//
// and:
//
//     Authorization B
//         Chain = chainB
//
// are semantically different whenever:
//
//     chainA != chainB
//
// Chain therefore participates in Authorization Value Object
// equality.
//
// This scenario does NOT weaken that semantic property.
//
// Instead, it establishes a different property:
//
//     Authorization Acceptance
//
// is not itself parameterized by a selected
//
//     ExecutionEnvironment
//
// and therefore does not require an external expected Chain merely
// to make the authorization semantically valid.
//
// ------------------------------------------------------------
//
// CURRENT FORMAL ACCEPTANCE CONTRACT
//
// AuthorizationCanBeAccepted has the form:
//
//   AuthorizationCanBeAccepted(
//     authorization,
//     account,
//     effectiveAuthority,
//     identities,
//     sourceAuthorities,
//     contributions,
//     now,
//     proofVerified
//   )
//
// The contract evaluates the semantic Authorization conditions,
// including:
//
//   - Account validity;
//   - Authorization structural validity;
//   - Account context compatibility;
//   - Credential recognition / usability;
//   - temporal validity;
//   - replay freshness;
//   - EffectiveAuthority validity;
//   - EffectiveAuthority provenance;
//   - RequestedAuthority containment;
//   - external Proof verification.
//
// Notice that the selected ExecutionEnvironment is intentionally
// absent.
//
// This is not an omission in the current architecture.
//
// It expresses the separation:
//
//     Authorization Acceptance
//         !=
//     Environment-specific Execution Delivery
//
// ------------------------------------------------------------
//
// PROVENANCE PRESERVATION
//
// The provenance inputs:
//
//   identities
//   sourceAuthorities
//   contributions
//
// are intentionally preserved unchanged when Chain is replaced.
//
// Therefore a Chain replacement does not bypass or weaken the
// EffectiveAuthority provenance boundary.
//
// The scenario changes exactly one semantic Authorization field:
//
//     Chain
//
// while preserving all other Authorization fields and all external
// acceptance witnesses.
//
// ------------------------------------------------------------
//
// CHAIN VALUE SEMANTICS
//
// foundation/Chain.dfy declares:
//
//     type Chain(==)
//
// Chain therefore has native Value Object equality.
//
// Consequently this scenario can construct an explicit distinction:
//
//     chainA != chainB
//
// while preserving every other Authorization field.
//
// The proof is therefore stronger than a generic statement that an
// opaque parameter happens not to be inspected.
//
// It establishes an explicit semantic distinction between two
// different Chain values.
//
// ------------------------------------------------------------
//
// CENTRAL FORMAL RESULT
//
// The central theorem of this scenario is:
//
//     accepted(original)
//         ==>
//     accepted(AuthorizationForChain(
//                 original,
//                 replacementChain
//              ))
//
// for any supplied replacement Chain.
//
// This means:
//
//     Authorization Acceptance
//
// is parametrically independent of the Chain value with respect to
// the current acceptance predicate.
//
// This is intentional because the acceptance predicate answers a
// semantic authorization question without requiring a selected
// physical execution environment.
//
// ------------------------------------------------------------
//
// DISTINCT-CHAIN ACCEPTANCE
//
// Because Chain supports equality, the parametric result can be
// specialized to:
//
//     chainA != chainB
//
// together with:
//
//     accepted(Authorization(chainA))
//
// to derive:
//
//     accepted(Authorization(chainB))
//
// while every other acceptance input remains identical.
//
// This does NOT mean that Chain is semantically irrelevant.
//
// Rather:
//
//     Chain
//         = semantic Authorization context
//
// while:
//
//     selected Environment
//         = execution materialization context.
//
// The distinction is therefore:
//
//     semantic difference between Authorizations
//         ≠
//     mandatory rejection during environment-independent acceptance
//
// ------------------------------------------------------------
//
// IMPORTANT INTERPRETATION OF THE ADVERSARIAL SCENARIO
//
// The scenario intentionally exposes a condition that could look
// suspicious if Authorization Acceptance and Execution Delivery
// were considered the same boundary.
//
// They are not the same boundary.
//
// The scenario therefore should be read as:
//
//     "Can Authorization Acceptance be performed without first
//      selecting an ExecutionEnvironment?"
//
// Answer:
//
//     YES — intentionally.
//
// It should NOT be read as:
//
//     "Can any accepted Authorization be executed on any
//      blockchain or infrastructure without further checks?"
//
// Answer:
//
//     NO.
//
// Environment-specific Engine delivery is separately constrained
// by ExecutionSemantics.dfy.
//
// ------------------------------------------------------------
//
// EXECUTION BOUNDARY DISTINCTION
//
// ExecutionSemantics.dfy defines the subsequent materialization gate:
//
//     Authorization Chain
//              ×
//     ExecutionEnvironment
//
// represented by the supplied compatibility relation.
//
// The intrinsic execution validity predicate is:
//
//     ExecutionEngineInputIsValid(...)
//
// and intentionally does not contain an Environment parameter.
//
// The environment-specific predicate is:
//
//     ExecutionEngineInputIsValidForEnvironment(...)
//
// and requires:
//
//     ExecutionContextIsCompatibleWithEnvironment(...)
//
// Therefore the execution pipeline is:
//
//     accepted Authorization
//            ↓
//     valid ExecutionContext
//            ↓
//     intrinsically valid Engine input
//            ↓
//     selected Environment
//            ↓
//     Chain × Environment compatibility
//            ↓
//     Environment-specific Engine delivery
//
// An incompatible Chain / Environment pair therefore cannot enter
// the environment-specific Engine boundary.
//
// ------------------------------------------------------------
//
// INTRINSIC VALIDITY VS ENVIRONMENT COMPATIBILITY
//
// The formalization intentionally establishes:
//
//     IntrinsicValidity
//         ≠
//     EnvironmentCompatibility
//
// A context may be intrinsically valid while being incompatible with
// one selected environment and compatible with another.
//
// Formally:
//
//     same ExecutionContext
//            +
//     same authorization decision
//            +
//     same EffectiveAuthority
//            +
//     same verified constraints
//
// may produce:
//
//     Environment 1 → deliverable
//
//     Environment 2 → not deliverable
//
// without changing the intrinsic validity of the ExecutionContext.
//
// This is an intentional property of the execution architecture.
//
// ------------------------------------------------------------
//
// MULTI-CHAIN DELIVERY INTENT
//
// The domain therefore remains capable of supporting an
// infrastructure-neutral execution architecture.
//
// For example, an accepted semantic Authorization may eventually
// be materialized through different infrastructure paths depending
// on Runtime decisions and available adapters.
//
// Conceptually:
//
//     Authorization
//          │
//          ▼
//     Runtime
//          │
//          ├── Environment A
//          │      └── Adapter / execution mechanism
//          │
//          ├── Environment B
//          │      └── Adapter / execution mechanism
//          │
//          └── Environment C
//                 └── Adapter / execution mechanism
//
// The Authorization model itself does not become coupled to one
// specific vendor or transport mechanism.
//
// This preserves the intended distinction between:
//
//     semantic sovereignty / authorization
//
// and:
//
//     infrastructure-specific materialization.
//
// ------------------------------------------------------------
//
// EFFECTIVE AUTHORITY PROVENANCE
//
// EffectiveAuthority provenance answers:
//
//     "From which currently usable authority sources was this
//      EffectiveAuthority derived?"
//
// This scenario answers:
//
//     "Does environment-independent Authorization Acceptance
//      consume Chain as a required external expected-context input?"
//
// These are independent semantic boundaries.
//
// The provenance inputs remain unchanged:
//
//   identities
//   sourceAuthorities
//   contributions
//
// Therefore this scenario does not reopen, duplicate or weaken
// EffectiveAuthority provenance.
//
// ------------------------------------------------------------
//
// REPLAY PROTECTION
//
// Replay Protection does not provide environment compatibility.
//
// The replay key remains a semantic Authorization attribute and is
// preserved under Chain substitution.
//
// Therefore:
//
//     ReplayKey
//
// is intentionally independent from:
//
//     selected ExecutionEnvironment
//
// Environment compatibility must therefore not be inferred from
// Replay Protection.
//
// ------------------------------------------------------------
//
// EFFECTIVE AUTHORITY
//
// EffectiveAuthority is a Value Object whose value is the resulting
// set of Capabilities.
//
// It does not contain Chain.
//
// This is intentional.
//
// Contextual inputs may influence the derivation of EffectiveAuthority
// but the resulting Value Object does not acquire an artificial
// Chain identity merely because a particular Authorization context
// exists.
//
// Therefore:
//
//     Authorization Chain
//
// remains part of Authorization semantics, while:
//
//     EffectiveAuthority
//
// remains a pure authority value.
//
// ------------------------------------------------------------
//
// NO VENDOR LOCK-IN
//
// This scenario is intentionally compatible with an architecture
// where cross-chain or multi-environment materialization may be
// supplied by different infrastructure providers.
//
// The domain therefore does not require:
//
//     Chainlink
//
// or:
//
//     LayerZero
//
// or any other specific provider.
//
// Such mechanisms are implementation choices of the infrastructure
// and execution layers.
//
// The formal domain only requires that any environment-specific
// delivery path respect the semantic Chain carried by the
// Authorization and the compatibility relation required by the
// selected execution environment.
//
// ------------------------------------------------------------
//
// NO ENVIRONMENT BINDING IN AUTHORIZATION ACCEPTANCE
//
// A standalone:
//
//     expectedChain : Chain
//
// is intentionally NOT introduced into AuthorizationCanBeAccepted
// solely for the purpose of tying authorization validity to a
// selected infrastructure environment.
//
// Introducing such a parameter without an independent DDD concept
// would incorrectly make a deployment / infrastructure choice part
// of the semantic Authorization acceptance boundary.
//
// The current architecture instead keeps the boundary:
//
//     Authorization acceptance
//
// separate from:
//
//     environment-specific delivery.
//
// ------------------------------------------------------------
//
// SCENARIO CONCLUSION
//
// The current formal result is intentionally:
//
//     CHAIN-INDEPENDENT AUTHORIZATION ACCEPTANCE
//         = CONFIRMED
//
// This means:
//
//     AuthorizationCanBeAccepted(...)
//
// does not require a selected ExecutionEnvironment and its result is
// unchanged when only Authorization.Chain is replaced.
//
// At the same time:
//
//     CHAIN-SENSITIVE AUTHORIZATION SEMANTICS
//         = CONFIRMED
//
// because Chain remains part of Authorization equality and semantic
// context.
//
// And:
//
//     CHAIN/ENVIRONMENT-SENSITIVE EXECUTION DELIVERY
//         = CONFIRMED
//
// because ExecutionSemantics separately requires:
//
//     Chain × ExecutionEnvironment compatibility
//
// before an ExecutionContext may cross the environment-specific
// Engine boundary.
//
// Therefore the complete architecture intentionally establishes:
//
//     Chain is semantic
//         AND
//     Authorization acceptance is environment-independent
//         AND
//     Execution delivery is environment-sensitive.
//
// These statements are compatible and are all required to express
// the intended multi-chain / infrastructure-neutral architecture.
//
// ------------------------------------------------------------
//
// SCENARIO CLASSIFICATION
//
// FORMALIZATION DEBT
//     = NOT CONFIRMED
//
// The previous interpretation of Chain-blind acceptance as a missing
// Chain-binding rule is not the intended domain semantics.
//
// The verified property is intentional architectural behavior:
//
//     Authorization Acceptance
//         is independent of the selected Environment.
//
// The later execution boundary remains responsible for preventing
// incompatible environment-specific materialization.
//
// Therefore this scenario is a:
//
//     VALID ARCHITECTURAL PROPERTY
//
// rather than:
//
//     FORMALIZATION DEBT
//
// No repair is prescribed by this scenario.
//
// ------------------------------------------------------------
//
// FORMAL PROPERTIES ESTABLISHED BY THIS FILE
//
//   Authorization Chain is preserved explicitly.
//       ✅
//
//   Chain participates in semantic Authorization identity/equality.
//       ✅
//
//   Replacing Chain preserves all other Authorization fields.
//       ✅
//
//   Account compatibility is preserved.
//       ✅
//
//   Credential usability is preserved.
//       ✅
//
//   Temporal validity is preserved.
//       ✅
//
//   Replay freshness is preserved.
//       ✅
//
//   RequestedAuthority containment is preserved.
//       ✅
//
//   EffectiveAuthority validity is independent of Chain.
//       ✅
//
//   EffectiveAuthority provenance witnesses are preserved.
//       ✅
//
//   Proof verification input is preserved.
//       ✅
//
//   Environment-independent Authorization acceptance.
//       ✅ INTENTIONAL
//
//   Environment-specific Chain compatibility.
//       ✅ ESTABLISHED IN ExecutionSemantics
//
//   Incompatible Chain / Environment cannot enter the
//   environment-specific Execution Engine boundary.
//       ✅ ESTABLISHED IN ExecutionSemantics
//
// ============================================================


include "../../foundation/DomainPrimitives.dfy"
include "../../foundation/Chain.dfy"
include "../../foundation/Capability.dfy"
include "../../foundation/Scope.dfy"
include "../../foundation/DomainAction.dfy"
include "../../foundation/ExecutionTarget.dfy"
include "../../foundation/Restriction.dfy"

include "../../authority/Credential.dfy"
include "../../authority/CredentialAuthority.dfy"
include "../../authority/EffectiveAuthority.dfy"
include "../../authority/AuthorizationState.dfy"
include "../../authority/Session.dfy"
include "../../authority/Delegation.dfy"

include "../../authorization/Authorization.dfy"
include "../../authorization/AuthorizationValidation.dfy"
include "../../authorization/Replay.dfy"

include "../isolated/FoundationProofs.dfy"
include "../isolated/AuthorityProofs.dfy"
include "../isolated/AuthorizationProofs.dfy"


module KipioAccountMultiChainProof
{
  import opened KipioAccountAccount
  import opened KipioAccountDomainPrimitives
  import opened KipioAccountChain
  import opened KipioAccountCapability
  import opened KipioAccountScope
  import opened KipioAccountDomainAction
  import opened KipioAccountExecutionTarget
  import opened KipioAccountRestriction

  import opened KipioAccountCredential
  import opened KipioAccountCredentialAuthority
  import opened KipioAccountEffectiveAuthority
  import opened KipioAccountAuthorizationState
  import opened KipioAccountSession
  import opened KipioAccountDelegation

  import opened KipioAccountAuthorization
  import opened KipioAccountAuthorizationValidation
  import opened KipioAccountReplay

  import opened KipioAccountFoundationProofs
  import opened KipioAccountAuthorityProofs
  import opened KipioAccountAuthorizationProofs
  import opened KipioAccountIdentity


  // ============================================================
  // AUTHORIZATION CONTEXT
  // ============================================================

  // Construct an Authorization that preserves every semantic
  // Authorization field except the supplied Chain value.
  //
  // This function is used to isolate Chain as the only changed
  // semantic field in the adversarial analysis.
  //
  // The replacement may be equal to or different from the original.
  // Because Chain has native equality semantics, later adversarial
  // lemmas may explicitly require:
  //
  //     chainA != chainB

  function AuthorizationForChain(
    original: Authorization,
    chain: Chain
  ): Authorization
  {
    Authorization(
      AuthorizationCredentialId(original),
      AuthorizationRequestedAuthority(original),
      AuthorizationRestrictions(original),
      AuthorizationValidFrom(original),
      AuthorizationValidUntil(original),
      AuthorizationReplayKey(original),
      AuthorizationAccountId(original),
      AuthorizationExecutionTarget(original),
      AuthorizationDomainAction(original),
      AuthorizationScope(original),
      chain
    )
  }


  // ============================================================
  // NON-CHAIN SEMANTIC FIELDS ARE PRESERVED
  // ============================================================

  lemma AuthorizationForChainPreservesCredentialId(
    original: Authorization,
    chain: Chain
  )
    ensures
      AuthorizationCredentialId(
        AuthorizationForChain(
          original,
          chain
        )
      )
      ==
      AuthorizationCredentialId(original)
  {
  }


  lemma AuthorizationForChainPreservesRequestedAuthority(
    original: Authorization,
    chain: Chain
  )
    ensures
      AuthorizationRequestedAuthority(
        AuthorizationForChain(
          original,
          chain
        )
      )
      ==
      AuthorizationRequestedAuthority(original)
  {
  }


  lemma AuthorizationForChainPreservesRestrictions(
    original: Authorization,
    chain: Chain
  )
    ensures
      AuthorizationRestrictions(
        AuthorizationForChain(
          original,
          chain
        )
      )
      ==
      AuthorizationRestrictions(original)
  {
  }


  lemma AuthorizationForChainPreservesTemporalInterval(
    original: Authorization,
    chain: Chain
  )
    ensures
      AuthorizationValidFrom(
        AuthorizationForChain(
          original,
          chain
        )
      )
      ==
      AuthorizationValidFrom(original)

    ensures
      AuthorizationValidUntil(
        AuthorizationForChain(
          original,
          chain
        )
      )
      ==
      AuthorizationValidUntil(original)
  {
  }


  lemma AuthorizationForChainPreservesReplayKey(
    original: Authorization,
    chain: Chain
  )
    ensures
      AuthorizationReplayKey(
        AuthorizationForChain(
          original,
          chain
        )
      )
      ==
      AuthorizationReplayKey(original)
  {
  }


  lemma AuthorizationForChainPreservesAccountId(
    original: Authorization,
    chain: Chain
  )
    ensures
      AuthorizationAccountId(
        AuthorizationForChain(
          original,
          chain
        )
      )
      ==
      AuthorizationAccountId(original)
  {
  }


  lemma AuthorizationForChainPreservesExecutionTarget(
    original: Authorization,
    chain: Chain
  )
    ensures
      AuthorizationExecutionTarget(
        AuthorizationForChain(
          original,
          chain
        )
      )
      ==
      AuthorizationExecutionTarget(original)
  {
  }


  lemma AuthorizationForChainPreservesDomainAction(
    original: Authorization,
    chain: Chain
  )
    ensures
      AuthorizationDomainAction(
        AuthorizationForChain(
          original,
          chain
        )
      )
      ==
      AuthorizationDomainAction(original)
  {
  }


  lemma AuthorizationForChainPreservesScope(
    original: Authorization,
    chain: Chain
  )
    ensures
      AuthorizationScope(
        AuthorizationForChain(
          original,
          chain
        )
      )
      ==
      AuthorizationScope(original)
  {
  }


  lemma AuthorizationForChainUsesSuppliedChain(
    original: Authorization,
    chain: Chain
  )
    ensures
      AuthorizationChain(
        AuthorizationForChain(
          original,
          chain
        )
      )
      ==
      chain
  {
  }


  // ============================================================
  // STRUCTURAL VALIDITY
  // ============================================================

  // ValidAuthorization / AuthorizationIsStructurallyValid do not
  // require an external Chain or ExecutionEnvironment.
  //
  // Replacing Chain while preserving all other semantic fields
  // therefore preserves structural Authorization validity.
  //
  // This is intentional: structural Authorization validity
  // determines whether the Authorization value is well-formed.
  // Environment-specific materialization compatibility belongs to
  // the execution boundary.

  lemma MultiChainChainReplacementPreservesStructuralValidity(
    original: Authorization,
    chain: Chain
  )
    requires
      AuthorizationIsStructurallyValid(original)

    ensures
      AuthorizationIsStructurallyValid(
        AuthorizationForChain(
          original,
          chain
        )
      )
  {
    assert
      ValidAuthorization(
        AuthorizationForChain(
          original,
          chain
        )
      );

    assert
      RequestedAuthorityIsValid(
        AuthorizationForChain(
          original,
          chain
        )
      );

    assert
      AuthorizationRestrictionsAreValid(
        AuthorizationForChain(
          original,
          chain
        )
      );

    assert
      AuthorizationIntervalIsWellFormed(
        AuthorizationForChain(
          original,
          chain
        )
      );
  }


  // ============================================================
  // ACCOUNT CONTEXT IS PRESERVED
  // ============================================================

  // Changing Chain does not alter Authorization.accountId.
  //
  // Therefore the Account-context condition remains unchanged.
  //
  // This condition binds the Authorization to the Account Entity
  // being evaluated; it is independent from the subsequently
  // selected ExecutionEnvironment.

  lemma MultiChainChainReplacementPreservesAccountContext(
    original: Authorization,
    account: Account,
    chain: Chain
  )
    requires
      AuthorizationContextMatchesAccount(
        original,
        account
      )

    ensures
      AuthorizationContextMatchesAccount(
        AuthorizationForChain(
          original,
          chain
        ),
        account
      )
  {
    assert
      AuthorizationAccountId(
        AuthorizationForChain(
          original,
          chain
        )
      )
      ==
      AuthorizationAccountId(original);

    assert
      AuthorizationAccountId(original)
      ==
      AccountIdOf(account);
  }


  // ============================================================
  // CREDENTIAL BOUNDARY IS PRESERVED
  // ============================================================

  lemma MultiChainChainReplacementPreservesCredentialContext(
    original: Authorization,
    account: Account,
    chain: Chain
  )
    requires
      AuthorizationCredentialIsUsable(
        original,
        AccountAuthorizationState(account)
      )

    ensures
      AuthorizationCredentialIsUsable(
        AuthorizationForChain(
          original,
          chain
        ),
        AccountAuthorizationState(account)
      )
  {
    assert
      AuthorizationCredentialId(
        AuthorizationForChain(
          original,
          chain
        )
      )
      ==
      AuthorizationCredentialId(original);
  }


  // ============================================================
  // TEMPORAL BOUNDARY IS PRESERVED
  // ============================================================

  lemma MultiChainChainReplacementPreservesTemporalValidity(
    original: Authorization,
    now: Timestamp,
    chain: Chain
  )
    requires
      AuthorizationIsTemporallyValidAt(
        original,
        now
      )

    ensures
      AuthorizationIsTemporallyValidAt(
        AuthorizationForChain(
          original,
          chain
        ),
        now
      )
  {
    assert
      AuthorizationValidFrom(
        AuthorizationForChain(
          original,
          chain
        )
      )
      ==
      AuthorizationValidFrom(original);

    assert
      AuthorizationValidUntil(
        AuthorizationForChain(
          original,
          chain
        )
      )
      ==
      AuthorizationValidUntil(original);
  }


  // ============================================================
  // REPLAY BOUNDARY IS PRESERVED
  // ============================================================

  // Replay Protection is a semantic Authorization property but is
  // intentionally independent from Environment compatibility.
  //
  // Replacing Chain therefore does not change replay freshness when
  // every other Authorization field and the Account state remain
  // unchanged.

  lemma MultiChainChainReplacementPreservesReplayFreshness(
    original: Authorization,
    account: Account,
    chain: Chain
  )
    requires
      AuthorizationReplayIsFresh(
        original,
        AccountAuthorizationState(account)
      )

    ensures
      AuthorizationReplayIsFresh(
        AuthorizationForChain(
          original,
          chain
        ),
        AccountAuthorizationState(account)
      )
  {
    assert
      AuthorizationReplayKey(
        AuthorizationForChain(
          original,
          chain
        )
      )
      ==
      AuthorizationReplayKey(original);
  }


  // ============================================================
  // EFFECTIVE AUTHORITY BOUNDARY IS PRESERVED
  // ============================================================

  // EffectiveAuthority is a pure authority value and contains no
  // Chain.
  //
  // The requested authority relationship therefore remains
  // unchanged under Chain substitution.

  lemma MultiChainChainReplacementPreservesAuthorityContainment(
    original: Authorization,
    effectiveAuthority: EffectiveAuthority,
    chain: Chain
  )
    requires
      AuthorizationAuthorityIsEffective(
        original,
        effectiveAuthority
      )

    ensures
      AuthorizationAuthorityIsEffective(
        AuthorizationForChain(
          original,
          chain
        ),
        effectiveAuthority
      )
  {
    assert
      AuthorizationRequestedAuthority(
        AuthorizationForChain(
          original,
          chain
        )
      )
      ==
      AuthorizationRequestedAuthority(original);

    assert
      AuthorizationRequestedAuthority(original)
      <=
      effectiveAuthority;
  }


  // ============================================================
  // EFFECTIVE AUTHORITY VALIDITY IS UNCHANGED
  // ============================================================

  // EffectiveAuthority validity is independent from
  // Authorization.Chain.
  //
  // This is expected because EffectiveAuthority is a Value Object
  // containing the resulting authority value rather than the
  // contextual inputs used to derive that value.

  lemma MultiChainEffectiveAuthorityRemainsValid(
    effectiveAuthority: EffectiveAuthority,
    chain: Chain
  )
    requires
      ValidEffectiveAuthority(
        effectiveAuthority
      )

    ensures
      ValidEffectiveAuthority(
        effectiveAuthority
      )
  {
    assert
      ValidEffectiveAuthority(
        effectiveAuthority
      );
  }


  // ============================================================
  // CENTRAL ARCHITECTURAL PROPERTY
  // ============================================================

  // If an Authorization is accepted, replacing its Chain value with
  // ANY supplied Chain preserves every currently formalized
  // acceptance condition.
  //
  // This theorem expresses an intentional architectural property:
  //
  //     Authorization Acceptance
  //         is independent of a selected
  //         ExecutionEnvironment.
  //
  // The provenance context used by acceptance is preserved exactly:
  //
  //   identities
  //   sourceAuthorities
  //   contributions
  //
  // The only Authorization field changed is Chain.
  //
  // Because Chain is a Value Object with native equality semantics,
  // this parametric theorem can be specialized to an explicit
  // distinct-chain witness.
  //
  // This does NOT imply unrestricted execution across environments.
  // Environment-specific materialization remains governed by
  // ExecutionSemantics.dfy.

  lemma MultiChainAcceptanceIsParametricallyIndependentOfChain(
    original: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool,
    replacementChain: Chain
  )
    requires
      AuthorizationCanBeAccepted(
        original,
        account,
        effectiveAuthority,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        now,
        proofVerified
      )

    ensures
      AuthorizationCanBeAccepted(
        AuthorizationForChain(
          original,
          replacementChain
        ),
        account,
        effectiveAuthority,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        now,
        proofVerified
      )
  {
    // ----------------------------------------------------------
    // Structural validity
    // ----------------------------------------------------------

    MultiChainChainReplacementPreservesStructuralValidity(
      original,
      replacementChain
    );

    // ----------------------------------------------------------
    // Account context
    // ----------------------------------------------------------

    MultiChainChainReplacementPreservesAccountContext(
      original,
      account,
      replacementChain
    );

    // ----------------------------------------------------------
    // Credential usability
    // ----------------------------------------------------------

    MultiChainChainReplacementPreservesCredentialContext(
      original,
      account,
      replacementChain
    );

    // ----------------------------------------------------------
    // Temporal validity
    // ----------------------------------------------------------

    MultiChainChainReplacementPreservesTemporalValidity(
      original,
      now,
      replacementChain
    );

    // ----------------------------------------------------------
    // Replay freshness
    // ----------------------------------------------------------

    MultiChainChainReplacementPreservesReplayFreshness(
      original,
      account,
      replacementChain
    );

    // ----------------------------------------------------------
    // Effective Authority validity
    // ----------------------------------------------------------

    assert
      EffectiveAuthorityIsValid(
        effectiveAuthority
      );

    // ----------------------------------------------------------
    // Requested Authority ⊆ Effective Authority
    // ----------------------------------------------------------

    MultiChainChainReplacementPreservesAuthorityContainment(
      original,
      effectiveAuthority,
      replacementChain
    );

    // ----------------------------------------------------------
    // Effective Authority provenance context
    // ----------------------------------------------------------

    // The provenance inputs used by AuthorizationCanBeAccepted are
    // not modified by AuthorizationForChain.
    //
    // The identities, sourceAuthorities and contributions supplied
    // to the acceptance predicate are exactly the same before and
    // after Chain replacement.

    assert
      identities == identities;

    assert
      sourceReferences == sourceReferences;

    assert
      sourceAuthorities == sourceAuthorities;

    assert
      contributions == contributions;

    // ----------------------------------------------------------
    // External Proof verification
    // ----------------------------------------------------------

    assert
      AuthorizationProofIsVerified(
        proofVerified
      );
  }


  // ============================================================
  // CROSS-CONTEXT PRESENTATION PROPERTY
  // ============================================================

  // Any supplied Chain value can replace the Chain carried by an
  // accepted Authorization without affecting the current
  // Authorization acceptance predicate.
  //
  // This property is intentionally environment-independent.
  //
  // The resulting Authorization remains semantically different if
  // the replacement Chain differs, but semantic difference does not
  // itself imply rejection at the Authorization Acceptance boundary.
  //
  // Later execution delivery remains Chain / Environment-sensitive.

  lemma MultiChainAcceptedAuthorizationCanBeRecontextualizedWithoutCurrentValidationEffect(
    original: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool,
    replacementChain: Chain
  )
    requires
      AuthorizationCanBeAccepted(
        original,
        account,
        effectiveAuthority,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        now,
        proofVerified
      )

    ensures
      AuthorizationCanBeAccepted(
        AuthorizationForChain(
          original,
          replacementChain
        ),
        account,
        effectiveAuthority,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        now,
        proofVerified
      )

    ensures
      AuthorizationChain(
        AuthorizationForChain(
          original,
          replacementChain
        )
      )
      ==
      replacementChain
  {
    MultiChainAcceptanceIsParametricallyIndependentOfChain(
      original,
      account,
      effectiveAuthority,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      now,
      proofVerified,
      replacementChain
    );

    assert
      AuthorizationChain(
        AuthorizationForChain(
          original,
          replacementChain
        )
      )
      ==
      replacementChain;
  }


  // ============================================================
  // EXPLICIT DISTINCT-CHAIN ADVERSARIAL ATTACK
  // ============================================================

  // Explicit distinct-chain specialization of the environment-
  // independent Authorization Acceptance property:
  //
  //   Chain A != Chain B
  //   Authorization on Chain A is accepted
  //   all other acceptance inputs remain identical
  //
  // therefore:
  //
  //   Authorization on Chain B is also accepted.
  //
  // This theorem is intentionally retained as an adversarial
  // specialization because it demonstrates that Authorization
  // Acceptance does not require a selected ExecutionEnvironment.
  //
  // It does NOT assert that Chain A and Chain B are interchangeable
  // for physical execution. The later execution boundary may
  // legitimately accept one environment and reject another.

  lemma MultiChainDistinctChainAcceptanceAttack(
    original: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool,
    chainA: Chain,
    chainB: Chain
  )
    requires
      chainA != chainB
      &&
      AuthorizationCanBeAccepted(
        AuthorizationForChain(
          original,
          chainA
        ),
        account,
        effectiveAuthority,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        now,
        proofVerified
      )

    ensures
      AuthorizationCanBeAccepted(
        AuthorizationForChain(
          original,
          chainB
        ),
        account,
        effectiveAuthority,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        now,
        proofVerified
      )

    ensures
      AuthorizationChain(
        AuthorizationForChain(
          original,
          chainA
        )
      )
      !=
      AuthorizationChain(
        AuthorizationForChain(
          original,
          chainB
        )
      )
  {
    MultiChainAcceptanceIsParametricallyIndependentOfChain(
      AuthorizationForChain(
        original,
        chainA
      ),
      account,
      effectiveAuthority,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      now,
      proofVerified,
      chainB
    );

    assert
      AuthorizationChain(
        AuthorizationForChain(
          original,
          chainA
        )
      )
      ==
      chainA;

    assert
      AuthorizationChain(
        AuthorizationForChain(
          original,
          chainB
        )
      )
      ==
      chainB;

    assert chainA != chainB;
  }


  // ============================================================
  // DISTINCT-CHAIN ATTACK PRESERVES OTHER ACCEPTANCE INPUTS
  // ============================================================

  // The Chain substitution does not merely preserve acceptance.
  //
  // The two Authorization values share the same:
  //
  //   - ReplayKey;
  //   - RequestedAuthority;
  //   - AccountId;
  //   - Scope;
  //   - EffectiveAuthority argument;
  //   - provenance witness arguments.
  //
  // Thus the adversarial difference is isolated to Chain.
  //
  // This demonstrates semantic distinction between the two
  // Authorization values without implying environment-independent
  // physical executability.

  lemma MultiChainDistinctChainsPreserveOtherAcceptanceInputs(
    original: Authorization,
    effectiveAuthority: EffectiveAuthority,
    chainA: Chain,
    chainB: Chain
  )
    requires
      chainA != chainB

    ensures
      AuthorizationReplayKey(
        AuthorizationForChain(
          original,
          chainA
        )
      )
      ==
      AuthorizationReplayKey(
        AuthorizationForChain(
          original,
          chainB
        )
      )

    ensures
      AuthorizationRequestedAuthority(
        AuthorizationForChain(
          original,
          chainA
        )
      )
      ==
      AuthorizationRequestedAuthority(
        AuthorizationForChain(
          original,
          chainB
        )
      )

    ensures
      AuthorizationAccountId(
        AuthorizationForChain(
          original,
          chainA
        )
      )
      ==
      AuthorizationAccountId(
        AuthorizationForChain(
          original,
          chainB
        )
      )

    ensures
      AuthorizationScope(
        AuthorizationForChain(
          original,
          chainA
        )
      )
      ==
      AuthorizationScope(
        AuthorizationForChain(
          original,
          chainB
        )
      )

    ensures
      ValidEffectiveAuthority(
        effectiveAuthority
      )
      ==
      ValidEffectiveAuthority(
        effectiveAuthority
      )
  {
    assert
      AuthorizationReplayKey(
        AuthorizationForChain(
          original,
          chainA
        )
      )
      ==
      AuthorizationReplayKey(original);

    assert
      AuthorizationReplayKey(
        AuthorizationForChain(
          original,
          chainB
        )
      )
      ==
      AuthorizationReplayKey(original);

    assert
      AuthorizationRequestedAuthority(
        AuthorizationForChain(
          original,
          chainA
        )
      )
      ==
      AuthorizationRequestedAuthority(original);

    assert
      AuthorizationRequestedAuthority(
        AuthorizationForChain(
          original,
          chainB
        )
      )
      ==
      AuthorizationRequestedAuthority(original);

    assert
      AuthorizationAccountId(
        AuthorizationForChain(
          original,
          chainA
        )
      )
      ==
      AuthorizationAccountId(original);

    assert
      AuthorizationAccountId(
        AuthorizationForChain(
          original,
          chainB
        )
      )
      ==
      AuthorizationAccountId(original);

    assert
      AuthorizationScope(
        AuthorizationForChain(
          original,
          chainA
        )
      )
      ==
      AuthorizationScope(original);

    assert
      AuthorizationScope(
        AuthorizationForChain(
          original,
          chainB
        )
      )
      ==
      AuthorizationScope(original);

    assert
      ValidEffectiveAuthority(
        effectiveAuthority
      )
      ==
      ValidEffectiveAuthority(
        effectiveAuthority
      );
  }


  // ============================================================
  // REPLAY DOES NOT PROVIDE CHAIN BINDING
  // ============================================================

  // The replay key is preserved when Chain is replaced.
  //
  // Therefore Replay Protection itself does not distinguish the
  // recontextualized Authorization.
  //
  // This is intentional because Replay Protection and
  // Chain / Environment compatibility are different concerns.

  lemma MultiChainReplayKeyDoesNotBindChain(
    original: Authorization,
    replacementChain: Chain
  )
    ensures
      AuthorizationReplayKey(
        AuthorizationForChain(
          original,
          replacementChain
        )
      )
      ==
      AuthorizationReplayKey(original)
  {
  }


  // ============================================================
  // EFFECTIVE AUTHORITY DOES NOT PROVIDE CHAIN BINDING
  // ============================================================

  // The same EffectiveAuthority value is usable as the supplied
  // authority argument independently of which Chain is carried by
  // the Authorization value.
  //
  // This follows from the fact that EffectiveAuthority is a pure
  // Value Object containing the resulting authority value rather
  // than a container for Authorization context or Environment.

  lemma MultiChainEffectiveAuthorityDoesNotBindReplacementChain(
    original: Authorization,
    effectiveAuthority: EffectiveAuthority,
    replacementChain: Chain
  )
    requires
      ValidEffectiveAuthority(
        effectiveAuthority
      )

    ensures
      ValidEffectiveAuthority(
        effectiveAuthority
      )
  {
  }


  // ============================================================
  // EXPLICIT DISTINCT-CHAIN ARCHITECTURAL INTERPRETATION
  // ============================================================

  // This lemma states the semantic consequence of the explicit
  // distinct-chain specialization in domain language:
  //
  // If Chain A and Chain B are distinct, the current Authorization
  // acceptance contract nevertheless accepts both when all other
  // acceptance inputs are identical and the Chain-A Authorization
  // is accepted.
  //
  // This is intentional environment-independent Authorization
  // Acceptance.
  //
  // The theorem does NOT prescribe physical cross-chain execution.
  // ExecutionSemantics separately determines whether the resulting
  // ExecutionContext can be delivered to a selected Environment.

  lemma MultiChainDistinctChainAcceptanceIsNotRejectedByCurrentContract(
    original: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool,
    chainA: Chain,
    chainB: Chain
  )
    requires
      chainA != chainB
      &&
      AuthorizationCanBeAccepted(
        AuthorizationForChain(
          original,
          chainA
        ),
        account,
        effectiveAuthority,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        now,
        proofVerified
      )

    ensures
      AuthorizationCanBeAccepted(
        AuthorizationForChain(
          original,
          chainB
        ),
        account,
        effectiveAuthority,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        now,
        proofVerified
      )
  {
    MultiChainDistinctChainAcceptanceAttack(
      original,
      account,
      effectiveAuthority,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      now,
      proofVerified,
      chainA,
      chainB
    );
  }


  // ============================================================
  // SCENARIO RESULT
  // ============================================================

  // Current formal result:
  //
  //   Chain is structurally carried by Authorization.
  //
  //   Chain is a Value Object with native equality semantics.
  //
  //   Authorization structural validity does not require an
  //   external Chain or ExecutionEnvironment.
  //
  //   Authorization acceptance does not require a selected
  //   ExecutionEnvironment.
  //
  //   Replacing Chain does not affect:
  //
  //       - CredentialId
  //       - RequestedAuthority
  //       - Restrictions
  //       - validity interval
  //       - ReplayKey
  //       - AccountId
  //       - ExecutionTarget
  //       - DomainAction
  //       - Scope
  //       - Account context
  //       - Credential usability
  //       - replay freshness
  //       - EffectiveAuthority validity
  //       - EffectiveAuthority provenance inputs
  //       - external Proof verification
  //
  //   Therefore:
  //
  //       CHAIN-INDEPENDENT AUTHORIZATION ACCEPTANCE
  //           = FORMALLY CONFIRMED
  //
  //       AND
  //
  //       INTENTIONALLY ARCHITECTURAL
  //
  //   because Authorization Acceptance answers a semantic
  //   authorization question without selecting the infrastructure
  //   environment in which the resulting decision will later be
  //   materialized.
  //
  // ------------------------------------------------------------
  //
  // CHAIN REMAINS SEMANTIC
  //
  //   Because Chain supports semantic equality:
  //
  //       DISTINCT-CHAIN AUTHORIZATIONS
  //           = FORMALLY CONFIRMED
  //
  //   A different Chain produces a different Authorization value.
  //
  //   Semantic distinction therefore remains intact even though the
  //   current Acceptance predicate is environment-independent.
  //
  // ------------------------------------------------------------
  //
  // EXECUTION BOUNDARY
  //
  //   ExecutionSemantics.dfy separately requires:
  //
  //       Authorization Chain
  //            ×
  //       selected ExecutionEnvironment
  //
  //   compatibility for environment-specific Engine delivery.
  //
  //   Therefore:
  //
  //       CHAIN/ENVIRONMENT-SENSITIVE ENGINE DELIVERY
  //           = FORMALLY ESTABLISHED
  //
  //   An incompatible Chain / Environment pair cannot cross the
  //   environment-specific Engine boundary.
  //
  // ------------------------------------------------------------
  //
  // ARCHITECTURAL CONSEQUENCE
  //
  // The domain intentionally maintains three different properties:
  //
  //   1. Chain is part of Authorization semantics.
  //
  //   2. Authorization Acceptance is independent from the selected
  //      ExecutionEnvironment.
  //
  //   3. Environment-specific Engine delivery is constrained by
  //      Chain / Environment compatibility.
  //
  // These properties are complementary rather than contradictory.
  //
  // They allow Kipio Account to remain semantically independent of
  // a particular blockchain deployment, Account Abstraction
  // standard, adapter, cross-chain provider or messaging mechanism.
  //
  // ------------------------------------------------------------
  //
  // FORMALIZATION DEBT
  //
  //   NOT A DEBT
  //
  // The earlier adversarial observation that the current Acceptance
  // predicate does not consume an external expected Chain is an
  // intentional architectural property, not a missing validation
  // rule.
  //
  // No standalone expectedChain input is therefore justified merely
  // to make Authorization Acceptance environment-sensitive.
  //
  // Environment compatibility remains a later execution concern.
  //
  // ------------------------------------------------------------
  //
  // FINAL SCENARIO CLASSIFICATION
  //
  //   CHAIN SEMANTIC STATUS
  //       = CONFIRMED
  //
  //   AUTHORIZATION CHAIN SENSITIVITY FOR VALUE EQUALITY
  //       = CONFIRMED
  //
  //   ENVIRONMENT-INDEPENDENT AUTHORIZATION ACCEPTANCE
  //       = CONFIRMED AND INTENTIONAL
  //
  //   CHAIN/ENVIRONMENT COMPATIBILITY AT EXECUTION DELIVERY
  //       = CONFIRMED
  //
  //   INCOMPATIBLE ENVIRONMENT REJECTION
  //       = CONFIRMED AT EXECUTION BOUNDARY
  //
  //   FORMALIZATION DEBT
  //       = NOT CONFIRMED
  //
  // No semantic repair is prescribed by this scenario.


  lemma MultiChainCurrentValidationIgnoresChainValue(
    original: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool,
    replacementChain: Chain
  )
    requires
      AuthorizationCanBeAccepted(
        original,
        account,
        effectiveAuthority,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        now,
        proofVerified
      )

    ensures
      AuthorizationCanBeAccepted(
        AuthorizationForChain(
          original,
          replacementChain
        ),
        account,
        effectiveAuthority,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        now,
        proofVerified
      )
  {
    MultiChainAcceptanceIsParametricallyIndependentOfChain(
      original,
      account,
      effectiveAuthority,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      now,
      proofVerified,
      replacementChain
    );
  }
}

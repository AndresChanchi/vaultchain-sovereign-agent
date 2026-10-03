// ============================================================
// KIPIO ACCOUNT DOMAIN
// EXECUTION — EXECUTION CONTEXT
// ============================================================
//
// ExecutionContext represents the complete domain decision value
// required before an Execution may be materialized.
//
// ExecutionContext is a Value Object.
//
// It contains:
//   - an ExecutionRequest;
//   - the AuthorizationState snapshot used for evaluation;
//   - the EffectiveAuthority resolved for that request;
//   - the evaluation time.
//
// ------------------------------------------------------------
//
// DDD BOUNDARY
//
// The DDD defines ExecutionContext as:
//
//     the complete and validated execution decision
//
// required before an Execution may be materialized.
//
// Runtime is responsible for coordinating the preceding evaluation:
//   - Authorization validation;
//   - Effective Authority resolution;
//   - Policy / Restriction effects;
//   - Execution Constraint evaluation.
//
// ExecutionContext does not redefine those algorithms.
//
// Instead, this module defines the formal relation that allows a
// concrete Account-level validation result to be represented by
// this execution decision value.
//
// ------------------------------------------------------------
//
// D6 — EXECUTION ENVIRONMENT SEPARATION
//
// ExecutionEnvironment is an infrastructure concept.
//
// It is intentionally NOT a field of ExecutionContext.
//
// Therefore ExecutionContext does NOT contain:
//
//   - ExecutionEnvironment;
//   - blockchain network identity;
//   - chain-specific runtime state;
//   - RPC information;
//   - physical execution metadata.
//
// Chain remains part of the semantic Authorization Context.
//
// Physical compatibility between:
//
//     Authorization Chain
//
// and:
//
//     selected ExecutionEnvironment
//
// is a contextual materialization relation established outside
// this Value Object.
//
// Therefore:
//
//     ValidExecutionContextForAccount(...)
//         !=
//     ExecutionContextCompatibleWithEnvironment(...)
//
// A context may be intrinsically valid while being incompatible
// with a particular selected execution environment.
//
// The environment-specific compatibility gate belongs to the
// execution boundary, not to this Value Object definition.
//
// ------------------------------------------------------------
//
// IMPORTANT ARCHITECTURAL DISTINCTION
//
// ExecutionContext itself is a Value Object.
//
// However, its validity is contextual.
//
// A context cannot independently prove that:
//
//     Authorization
//         was accepted for
//     Account
//
// merely from an AuthorizationState value, because AuthorizationState
// intentionally does not contain Account identity.
//
// Therefore the complete validation relation receives:
//
//   - the Account whose state was evaluated;
//   - the Identity context used for delegation provenance;
//   - EffectiveAuthority provenance witnesses;
//   - the external Proof verification result.
//
// These are validation-boundary inputs / witnesses.
//
// They are NOT added as persistent fields to ExecutionContext.
//
// This preserves:
//
//     Account
//         owns
//     AuthorizationState
//
// while avoiding an artificial AccountId field inside
// AuthorizationState.
//
// ------------------------------------------------------------
//
// EXECUTION ENVIRONMENT BOUNDARY
//
// This module does NOT decide whether an ExecutionContext is
// compatible with a concrete ExecutionEnvironment.
//
// In particular, it does not:
//
//   - define ExecutionEnvironment;
//   - define the physical compatibility algorithm;
//   - bind Chain to a concrete blockchain network;
//   - resolve RPC or protocol-specific representations.
//
// The selected environment and its compatibility with the
// Authorization Chain are handled by the execution/runtime
// boundary.
//
// This separation is intentional:
//
//     Authorization
//          |
//          └── Chain (semantic)
//                    |
//                    v
//             ExecutionContext
//                    |
//                    v
//      contextual environment compatibility
//                    |
//                    v
//             Execution Engine
//
// ------------------------------------------------------------
//
// WHAT THIS FILE DOES NOT DO
//
// It does NOT:
//
//   - calculate Effective Authority;
//   - define Proof;
//   - verify Proof cryptographically;
//   - consume Replay Protection;
//   - evaluate Policy;
//   - interpret ExecutionConstraints;
//   - evaluate ExecutionEnvironment compatibility;
//   - resolve ExecutionTarget semantics;
//   - execute Domain Actions;
//   - define blockchain infrastructure;
//   - introduce ExecutionId.
//
// ------------------------------------------------------------
//
// VALUE OBJECT SEMANTICS
//
// ExecutionContext has no independent identity.
//
// There is intentionally NO:
//
//   - ExecutionContextId;
//   - RequestId;
//   - ExecutionId.
//
// Equality is native Value Object equality over the constructor
// fields.
//
// ============================================================

include "../foundation/DomainPrimitives.dfy"
include "../foundation/Identity.dfy"

include "../authority/EffectiveAuthority.dfy"
include "../authority/AuthorizationState.dfy"

include "../authorization/Authorization.dfy"
include "../authorization/AuthorizationValidation.dfy"

include "ExecutionConstraints.dfy"
include "ExecutionRequest.dfy"


module KipioAccountExecutionContext
{
  import opened KipioAccountDomainPrimitives
  import opened KipioAccountIdentity

  import opened KipioAccountEffectiveAuthority
  import opened KipioAccountAuthorizationState

  import opened KipioAccountAuthorization
  import opened KipioAccountAuthorizationValidation

  import opened KipioAccountExecutionConstraints
  import opened KipioAccountExecutionRequest

  import opened KipioAccountCapability
  import opened KipioAccountAccount


  // ----------------------------------------------------------
  // EXECUTION CONTEXT
  // ----------------------------------------------------------

  datatype ExecutionContext =
    ExecutionContext(
      request: ExecutionRequest,
      authorizationState: AuthorizationState,
      effectiveAuthority: EffectiveAuthority,
      evaluationTime: Timestamp
    )


  // ----------------------------------------------------------
  // ACCESSORS
  // ----------------------------------------------------------

  function ExecutionContextRequest(
    context: ExecutionContext
  ): ExecutionRequest
  {
    context.request
  }


  function ExecutionContextAuthorizationState(
    context: ExecutionContext
  ): AuthorizationState
  {
    context.authorizationState
  }


  function ExecutionContextEffectiveAuthority(
    context: ExecutionContext
  ): EffectiveAuthority
  {
    context.effectiveAuthority
  }


  function ExecutionContextConstraints(
    context: ExecutionContext
  ): ExecutionConstraints
  {
    ExecutionRequestConstraints(
      ExecutionContextRequest(context)
    )
  }


  function ExecutionContextEvaluationTime(
    context: ExecutionContext
  ): Timestamp
  {
    context.evaluationTime
  }


  // ----------------------------------------------------------
  // AUTHORIZATION RELATION
  // ----------------------------------------------------------

  function ExecutionContextAuthorization(
    context: ExecutionContext
  ): Authorization
  {
    ExecutionRequestAuthorization(
      ExecutionContextRequest(context)
    )
  }


  // ----------------------------------------------------------
  // AUTHORIZATION / STATE CONSISTENCY
  // ----------------------------------------------------------

  predicate ExecutionContextCredentialIsRecognized(
    context: ExecutionContext
  )
  {
    AuthorizationCredentialIsRecognized(
      ExecutionContextAuthorization(context),
      ExecutionContextAuthorizationState(context)
    )
  }


  predicate ExecutionContextCredentialIsUsable(
    context: ExecutionContext
  )
  {
    AuthorizationCredentialIsUsable(
      ExecutionContextAuthorization(context),
      ExecutionContextAuthorizationState(context)
    )
  }


  // ----------------------------------------------------------
  // REQUEST / AUTHORIZATION CONSISTENCY
  // ----------------------------------------------------------

  predicate ExecutionContextRequestIsConsistent(
    context: ExecutionContext
  )
  {
    ExecutionRequestAuthorizationContextIsConsistent(
      ExecutionContextRequest(context)
    )
  }


  // ----------------------------------------------------------
  // CONTEXT SNAPSHOT ASSOCIATION
  // ----------------------------------------------------------

  // AuthorizationState intentionally does not contain AccountId.
  //
  // Therefore the association:
  //
  //     Account
  //         owns
  //     AuthorizationState
  //
  // must be established at the validation boundary.
  //
  // This predicate states that the state snapshot carried by the
  // ExecutionContext is exactly the state owned by the Account
  // whose Authorization is being evaluated.

  ghost predicate ExecutionContextUsesAccountAuthorizationState(
    context: ExecutionContext,
    account: Account
  )
  {
    ExecutionContextAuthorizationState(context)
    ==
    AccountAuthorizationState(account)
  }


  // ----------------------------------------------------------
  // COMPLETE AUTHORIZATION DECISION RELATION
  // ----------------------------------------------------------

  // This is the execution-boundary relation connecting:
  //
  //     Authorization Validation
  //             +
  //     Account state ownership
  //             +
  //     ExecutionContext
  //
  // Authorization acceptance remains the responsibility of
  // AuthorizationValidation.dfy.
  //
  // This predicate does not recompute authorization semantics.
  // It reuses the already-established acceptance contract.
  //
  // The Identity collection and provenance witnesses remain ghost
  // contextual evidence and are not persisted inside the
  // ExecutionContext Value Object.

  ghost predicate ExecutionContextRepresentsAcceptedAuthorizationForAccount(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool
  )
  {
    ExecutionContextUsesAccountAuthorizationState(
      context,
      account
    )
    &&
    AuthorizationCanBeAccepted(
      ExecutionContextAuthorization(context),
      account,
      ExecutionContextEffectiveAuthority(context),
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      ExecutionContextEvaluationTime(context),
      proofVerified
    )
  }


  // ----------------------------------------------------------
  // COMPLETE EXECUTION CONTEXT VALIDITY
  // ----------------------------------------------------------

  // The domain meaning of a valid ExecutionContext is stronger
  // than structural consistency alone.
  //
  // A complete context must represent an Authorization that has
  // already crossed the Authorization acceptance boundary for the
  // same Account whose AuthorizationState snapshot is carried by
  // the context.
  //
  // AuthorizationCanBeAccepted already establishes:
  //
  //   - ValidAccount;
  //   - Authorization structural validity;
  //   - Account context compatibility;
  //   - Credential usability;
  //   - temporal validity;
  //   - Replay freshness;
  //   - EffectiveAuthority validity;
  //   - EffectiveAuthority provenance;
  //   - RequestedAuthority ⊆ EffectiveAuthority;
  //   - external Proof verification.
  //
  // The execution context additionally establishes:
  //
  //   - valid ExecutionRequest;
  //   - request / Authorization consistency;
  //   - valid AuthorizationState snapshot;
  //   - exact association of the snapshot with the Account;
  //   - consistency between carried EffectiveAuthority and the
  //     accepted Authorization.
  //
  // ExecutionConstraints remain opaque here. Their concrete
  // satisfaction belongs to the Runtime / execution boundary.
  //
  // Importantly, environment compatibility is NOT part of this
  // intrinsic validity predicate.
  //
  // Therefore:
  //
  //     ValidExecutionContextForAccount(...)
  //
  // means that the context is a complete validated domain
  // decision for the Account.
  //
  // It does NOT mean that the context is materializable in every
  // possible ExecutionEnvironment.

  ghost predicate ValidExecutionContextForAccount(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool
  )
  {
    ExecutionContextRepresentsAcceptedAuthorizationForAccount(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified
    )
    &&
    ValidExecutionRequest(
      ExecutionContextRequest(context)
    )
    &&
    ExecutionRequestAuthorizationContextIsConsistent(
      ExecutionContextRequest(context)
    )
    &&
    ValidAuthorizationState(
      ExecutionContextAuthorizationState(context)
    )
    &&
    ValidEffectiveAuthority(
      ExecutionContextEffectiveAuthority(context)
    )
    &&
    RequestedAuthorityWithinEffectiveAuthority(
      ExecutionContextAuthorization(context),
      ExecutionContextEffectiveAuthority(context)
    )
    &&
    ExecutionContextCredentialIsRecognized(context)
    &&
    ExecutionContextCredentialIsUsable(context)
  }


  // ----------------------------------------------------------
  // LOCAL STRUCTURAL CONTEXT VALIDITY
  // ----------------------------------------------------------

  // This predicate intentionally remains weaker than the complete
  // Account-level validity relation above.
  //
  // It describes only the structural coherence of the value itself.
  //
  // It must NOT be confused with a complete validated execution
  // decision.
  //
  // It is also independent of any selected ExecutionEnvironment.

  predicate StructurallyValidExecutionContext(
    context: ExecutionContext
  )
  {
    ValidExecutionRequest(
      ExecutionContextRequest(context)
    )
    &&
    ValidAuthorizationState(
      ExecutionContextAuthorizationState(context)
    )
    &&
    ValidEffectiveAuthority(
      ExecutionContextEffectiveAuthority(context)
    )
    &&
    RequestedAuthorityWithinEffectiveAuthority(
      ExecutionContextAuthorization(context),
      ExecutionContextEffectiveAuthority(context)
    )
    &&
    ExecutionContextCredentialIsRecognized(context)
    &&
    ExecutionContextCredentialIsUsable(context)
  }


  // ----------------------------------------------------------
  // VALUE OBJECT SEMANTICS
  // ----------------------------------------------------------

  lemma EqualExecutionContextsHaveEqualRequests(
    left: ExecutionContext,
    right: ExecutionContext
  )
    requires left == right
    ensures ExecutionContextRequest(left)
         == ExecutionContextRequest(right)
  {
  }


  lemma EqualExecutionContextsHaveEqualAuthorizationStates(
    left: ExecutionContext,
    right: ExecutionContext
  )
    requires left == right
    ensures ExecutionContextAuthorizationState(left)
         == ExecutionContextAuthorizationState(right)
  {
  }


  lemma EqualExecutionContextsHaveEqualEffectiveAuthorities(
    left: ExecutionContext,
    right: ExecutionContext
  )
    requires left == right
    ensures ExecutionContextEffectiveAuthority(left)
         == ExecutionContextEffectiveAuthority(right)
  {
  }


  lemma EqualExecutionContextsHaveEqualEvaluationTimes(
    left: ExecutionContext,
    right: ExecutionContext
  )
    requires left == right
    ensures ExecutionContextEvaluationTime(left)
         == ExecutionContextEvaluationTime(right)
  {
  }


  // ----------------------------------------------------------
  // COMPLETE VALIDITY LAWS
  // ----------------------------------------------------------

  lemma ValidExecutionContextForAccountHasValidRequest(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool
  )
    requires ValidExecutionContextForAccount(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified
             )
    ensures ValidExecutionRequest(
              ExecutionContextRequest(context)
            )
  {
  }


  lemma ValidExecutionContextForAccountHasValidAccount(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool
  )
    requires ValidExecutionContextForAccount(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified
             )
    ensures ValidAccount(account)
  {
  }


  lemma ValidExecutionContextForAccountUsesAccountState(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool
  )
    requires ValidExecutionContextForAccount(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified
             )
    ensures ExecutionContextUsesAccountAuthorizationState(
              context,
              account
            )
  {
  }


  lemma ValidExecutionContextForAccountRepresentsAcceptedAuthorization(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool
  )
    requires ValidExecutionContextForAccount(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified
             )
    ensures ExecutionContextRepresentsAcceptedAuthorizationForAccount(
              context,
              account,
              identities,
              sourceReferences,
              sourceAuthorities,
              contributions,
              proofVerified
            )
  {
  }


  lemma ValidExecutionContextForAccountHasValidAuthorizationState(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool
  )
    requires ValidExecutionContextForAccount(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified
             )
    ensures ValidAuthorizationState(
              ExecutionContextAuthorizationState(context)
            )
  {
  }


  lemma ValidExecutionContextForAccountHasValidEffectiveAuthority(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool
  )
    requires ValidExecutionContextForAccount(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified
             )
    ensures ValidEffectiveAuthority(
              ExecutionContextEffectiveAuthority(context)
            )
  {
  }


  lemma ValidExecutionContextForAccountAuthorizesRequestedAuthority(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool
  )
    requires ValidExecutionContextForAccount(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified
             )
    ensures RequestedAuthorityWithinEffectiveAuthority(
              ExecutionContextAuthorization(context),
              ExecutionContextEffectiveAuthority(context)
            )
  {
  }


  lemma ValidExecutionContextForAccountHasRecognizedCredential(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool
  )
    requires ValidExecutionContextForAccount(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified
             )
    ensures ExecutionContextCredentialIsRecognized(context)
  {
  }


  lemma ValidExecutionContextForAccountHasUsableCredential(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool
  )
    requires ValidExecutionContextForAccount(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified
             )
    ensures ExecutionContextCredentialIsUsable(context)
  {
  }


  // ----------------------------------------------------------
  // STRUCTURAL LAWS
  // ----------------------------------------------------------

  // These laws concern only structural consequences of a context
  // value. They intentionally do not claim that the context has
  // crossed the complete Account-level authorization boundary.

  lemma StructurallyValidExecutionContextHasValidRequest(
    context: ExecutionContext
  )
    requires StructurallyValidExecutionContext(context)
    ensures ValidExecutionRequest(
              ExecutionContextRequest(context)
            )
  {
  }


  lemma StructurallyValidExecutionContextHasValidAuthorizationState(
    context: ExecutionContext
  )
    requires StructurallyValidExecutionContext(context)
    ensures ValidAuthorizationState(
              ExecutionContextAuthorizationState(context)
            )
  {
  }


  lemma StructurallyValidExecutionContextHasValidEffectiveAuthority(
    context: ExecutionContext
  )
    requires StructurallyValidExecutionContext(context)
    ensures ValidEffectiveAuthority(
              ExecutionContextEffectiveAuthority(context)
            )
  {
  }


  lemma StructurallyValidExecutionContextHasRecognizedCredential(
    context: ExecutionContext
  )
    requires StructurallyValidExecutionContext(context)
    ensures ExecutionContextCredentialIsRecognized(context)
  {
  }


  lemma StructurallyValidExecutionContextHasUsableCredential(
    context: ExecutionContext
  )
    requires StructurallyValidExecutionContext(context)
    ensures ExecutionContextCredentialIsUsable(context)
  {
  }


  // ----------------------------------------------------------
  // CONSTRAINT BOUNDARY
  // ----------------------------------------------------------

  lemma ExecutionContextUsesRequestConstraints(
    context: ExecutionContext
  )
    ensures ExecutionContextConstraints(context)
            ==
            ExecutionRequestConstraints(
              ExecutionContextRequest(context)
            )
  {
  }


  // ----------------------------------------------------------
  // AUTHORITY BOUNDARY
  // ----------------------------------------------------------

  lemma ValidExecutionContextForAccountCarriesResolvedAuthority(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool
  )
    requires ValidExecutionContextForAccount(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified
             )
    ensures ValidEffectiveAuthority(
              ExecutionContextEffectiveAuthority(context)
            )
  {
  }


  // ----------------------------------------------------------
  // EXECUTION DECISION BOUNDARY
  // ----------------------------------------------------------

  // A ValidExecutionContextForAccount represents a complete
  // validated execution decision for the relevant Account.
  //
  // This predicate intentionally does NOT mean that the context
  // may enter the Execution Engine for an arbitrary environment.
  //
  // Environment compatibility and Engine-entry conditions belong
  // to ExecutionSemantics.dfy / Runtime.
  //
  // Therefore this module stops at:
  //
  //     complete validated execution decision
  //
  // and does not define:
  //
  //     Engine delivery for selected environment.


  // ----------------------------------------------------------
  // EXECUTION / REQUEST CONSISTENCY
  // ----------------------------------------------------------

  lemma ValidExecutionContextForAccountPreservesRequestedDomainAction(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool
  )
    requires ValidExecutionContextForAccount(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified
             )
    ensures ExecutionRequestAction(
              ExecutionContextRequest(context)
            )
            ==
            AuthorizationDomainAction(
              ExecutionContextAuthorization(context)
            )
  {
  }


  lemma ValidExecutionContextForAccountPreservesRequestedTarget(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool
  )
    requires ValidExecutionContextForAccount(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified
             )
    ensures ExecutionRequestTarget(
              ExecutionContextRequest(context)
            )
            ==
            AuthorizationExecutionTarget(
              ExecutionContextAuthorization(context)
            )
  {
  }
}

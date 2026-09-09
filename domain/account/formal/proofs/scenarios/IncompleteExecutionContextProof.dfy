// ============================================================
// KIPIO ACCOUNT DOMAIN
// SCENARIO — INCOMPLETE EXECUTION CONTEXT
// ============================================================
//
// This scenario verifies the boundary between:
//
//     StructurallyValidExecutionContext
//
// and:
//
//     ValidExecutionContextForAccount
//
// and the downstream Engine boundary.
//
// The formal model intentionally distinguishes:
//
//     structural coherence
//         !=
//     complete validated execution decision
//
// A structurally valid ExecutionContext is therefore not, by
// itself, sufficient to establish that the Authorization represented
// by that context is accepted for a specific Account.
//
// The complete execution-context boundary explicitly reuses the
// Authorization acceptance contract.
//
// ------------------------------------------------------------
//
// ARCHITECTURAL FLOW
//
//     Authorization
//          ↓
//     Authorization Validation
//          ↓
//     accepted Authorization
//          ↓
//     Effective Authority
//          ↓
//     ExecutionRequest
//          ↓
//     ExecutionContext
//          ↓
//     complete Account-level validation
//          ↓
//     Execution Engine input
//          ↓
//     environment compatibility
//          ↓
//     Execution Engine
//
// ------------------------------------------------------------
//
// ATTACK OBJECTIVE
//
// Determine whether a structurally coherent ExecutionContext can
// bypass the complete Authorization acceptance boundary and reach
// the Execution Engine while Authorization acceptance is false.
//
// The adversarial conditions covered here are:
//
//   - temporal invalidity;
//   - consumed Replay Protection;
//   - failed external Proof verification.
//
// EffectiveAuthority provenance is intentionally not redefined by
// this scenario. Its acceptance boundary is covered separately by
// UnprovenAuthorityProof.dfy.
//
// ------------------------------------------------------------
//
// CURRENT FORMAL INVARIANT
//
//     StructurallyValidExecutionContext
//
// establishes structural coherence of the context value.
//
//     ValidExecutionContextForAccount
//
// establishes complete Account-level execution validity and
// explicitly depends on:
//
//     AuthorizationCanBeAccepted
//
// Therefore:
//
//     StructurallyValidExecutionContext
//         |
//         | does not imply
//         v
//     AuthorizationCanBeAccepted
//
// while:
//
//     ValidExecutionContextForAccount
//         |
//         | implies
//         v
//     AuthorizationCanBeAccepted
//
// ------------------------------------------------------------
//
// ENGINE BOUNDARY
//
//     ExecutionEngineInputIsValid
//
// requires:
//
//     ValidExecutionContextForAccount
//
// and receives the concrete `ExecutionConstraints` value used as
// the verification witness for the ExecutionContext.
//
// The constraint-verification boundary is:
//
//     ExecutionConstraintsAreVerified(
//         context,
//         verifiedConstraints
//     )
//
// which binds the supplied witness to the exact
// ExecutionConstraints value carried by the context.
//
// The environment-specific boundary:
//
//     ExecutionContextCanEnterExecutionEngine
//
// is downstream of complete Engine-input validity and also requires
// compatibility between the selected Chain and ExecutionEnvironment.
//
// Consequently:
//
//     failed Authorization acceptance
//         |
//         X
//     complete ExecutionContext
//         |
//         X
//     valid Engine input
//         |
//         X
//     Execution Engine entry
//
// ------------------------------------------------------------
//
// DDD ALIGNMENT
//
// The DDD defines ExecutionContext as the complete validated
// execution decision required before an Execution may be materialized.
//
// The formal model reflects that boundary:
//
//   - Authorization acceptance is established before complete
//     ExecutionContext validity;
//   - Effective Authority is part of the validated execution state;
//   - applicable execution conditions are established before Engine
//     admission;
//   - the Execution Engine consumes already-valid execution input
//     instead of deciding Authorization.
//
// ExecutionConstraints remains an opaque Value Object in this
// scenario. The scenario only propagates the concrete constraint
// value required by the Engine boundary; it does not define how
// constraints are interpreted or evaluated.
//
// Runtime orchestration remains an architectural responsibility.
// This scenario verifies the contracts at the formal boundaries that
// Runtime must respect.
//
// ------------------------------------------------------------
//
// SEMANTIC DISTINCTION
//
// StructurallyValidExecutionContext is intentionally weaker than:
//
//     ValidExecutionContextForAccount
//
// A structurally valid context may therefore contain an Authorization
// that is:
//
//   - expired or otherwise temporally invalid;
//   - replay-consumed;
//   - evaluated under a failed external Proof result.
//
// Such a context is structurally coherent but is not a complete
// validated execution decision for the Account.
//
// This distinction is intentional and does not represent a modeling
// defect.
//
// ------------------------------------------------------------
//
// PROOF-HARNESS STRUCTURE
//
// ConcreteConsumedReplayWitness is a ghost predicate used to express
// the concrete replay witness as one named proof condition.
//
// It is part of the adversarial proof harness only.
//
// It does not redefine:
//
//   - Authorization;
//   - Replay Protection;
//   - AuthorizationCanBeAccepted;
//   - ExecutionContext;
//   - ExecutionEngineInputIsValid;
//   - ExecutionContextCanEnterExecutionEngine.
//
// It also does not introduce productive domain semantics.
//
// ------------------------------------------------------------
//
// COVERED CASES
//
// Attack A
// --------
// A temporally invalid Authorization cannot be accepted and cannot
// form a complete Account-level ExecutionContext.
//
// Attack B
// --------
// A consumed Replay key makes Authorization acceptance impossible
// and prevents formation of a complete Account-level ExecutionContext.
//
// Attack C
// --------
// A failed external Proof result prevents Authorization acceptance
// and therefore prevents formation of a complete Account-level
// ExecutionContext.
//
// Attack D
// --------
// Valid Engine input implies complete Account-level
// ExecutionContext validity.
//
// Attack E
// --------
// Failed Authorization acceptance cannot become valid Engine input.
//
// Attack F
// --------
// Failed Authorization acceptance cannot cross the
// environment-specific Execution Engine entry boundary.
//
// Attack G
// --------
// A concrete structurally valid context may carry a temporally
// invalid Authorization, while complete Account-level validation
// rejects it.
//
// Attack H
// --------
// A concrete structurally valid context may carry a replay-consumed
// Authorization, while complete Account-level validation rejects it.
//
// Attack I
// --------
// A concrete structurally valid context may be evaluated under a
// failed external Proof result, while complete Account-level
// validation rejects it.
//
// Attack J
// --------
// Any context admitted by the environment-specific Engine boundary
// necessarily implies Authorization acceptance.
//
// Effective Authority provenance is covered by the independent
// UnprovenAuthorityProof.dfy scenario.
//
// ------------------------------------------------------------
//
// FORMAL COVERAGE
//
// The scenario establishes the following implications and exclusions:
//
//     complete ExecutionContext
//         → Authorization acceptance
//
//     valid Engine input
//         → complete ExecutionContext
//
//     valid Engine input
//         → Authorization acceptance
//
//     Engine entry
//         → Authorization acceptance
//
// and blocks:
//
//     temporal bypass
//     replay bypass
//     proof bypass
//     failed Authorization → valid Engine input
//     failed Authorization → Engine entry
//
// Effective Authority provenance is covered by the independent
// UnprovenAuthorityProof.dfy scenario.
//
// ------------------------------------------------------------
//
// CLASSIFICATION
//
//     DOMAIN SEMANTICS: PRESERVED
//     EXECUTION CONTEXT COMPLETENESS: ENFORCED
//     AUTHORIZATION → CONTEXT BRIDGE: ENFORCED
//     CONTEXT → ENGINE BRIDGE: ENFORCED
//     ENGINE ENTRY → AUTHORIZATION ACCEPTANCE: ENFORCED
//     TEMPORAL BYPASS: BLOCKED
//     REPLAY BYPASS: BLOCKED
//     PROOF BYPASS: BLOCKED
//     EFFECTIVE AUTHORITY PROVENANCE: COVERED ELSEWHERE
//     STRUCTURAL CONTEXT != COMPLETE CONTEXT: VERIFIED
//     DDD CONTRADICTION: NONE IDENTIFIED
//     DDD DEBT: NONE IDENTIFIED FOR THIS SCENARIO
//     FORMALIZATION DEBT: NONE IDENTIFIED FOR THIS SCENARIO
//     SECURITY DEBT: NONE IDENTIFIED FOR THIS SCENARIO
//     PROOF-ENGINEERING STATUS: STABLE
//     REGRESSION VALUE: HIGH
//
// ------------------------------------------------------------
//
// VERIFICATION SCOPE
//
// The proof harness verifies the semantic boundaries expressed by
// the current domain predicates.
//
// It does not define:
//
//   - Proof representation;
//   - runtime orchestration;
//   - ExecutionConstraints semantics;
//   - Chain / Environment compatibility semantics;
//   - productive Execution Engine behavior.
//
// Those responsibilities remain in their authoritative domain or
// infrastructure contracts.
//
// ============================================================


include "../../foundation/DomainPrimitives.dfy"
include "../../foundation/Capability.dfy"
include "../../foundation/Scope.dfy"
include "../../foundation/Subject.dfy"
include "../../foundation/Identity.dfy"
include "../../foundation/ExecutionTarget.dfy"
include "../../foundation/DomainAction.dfy"
include "../../foundation/Chain.dfy"

include "../../authority/EffectiveAuthority.dfy"
include "../../authority/AuthorizationState.dfy"
include "../../authority/CredentialAuthority.dfy"
include "../../authority/Credential.dfy"
include "../../authority/Session.dfy"
include "../../authority/Delegation.dfy"

include "../../authorization/Authorization.dfy"
include "../../authorization/AuthorizationValidation.dfy"
include "../../authorization/Replay.dfy"

include "../../account/Account.dfy"

include "../../execution/ExecutionConstraints.dfy"
include "../../execution/ExecutionRequest.dfy"
include "../../execution/ExecutionContext.dfy"
include "../../execution/ExecutionSemantics.dfy"


module KipioAccountIncompleteExecutionContextProof
{
  import opened KipioAccountDomainPrimitives
  import opened KipioAccountCapability
  import opened KipioAccountScope
  import opened KipioAccountSubject
  import opened KipioAccountIdentity
  import opened KipioAccountExecutionTarget
  import opened KipioAccountDomainAction
  import opened KipioAccountChain

  import opened KipioAccountEffectiveAuthority
  import opened KipioAccountAuthorizationState
  import opened KipioAccountCredentialAuthority
  import opened KipioAccountCredential
  import opened KipioAccountSession
  import opened KipioAccountDelegation

  import opened KipioAccountAuthorization
  import opened KipioAccountAuthorizationValidation
  import opened KipioAccountReplay

  import opened KipioAccountAccount

  import opened KipioAccountExecutionConstraints
  import opened KipioAccountExecutionRequest
  import opened KipioAccountExecutionContext
  import opened KipioAccountExecutionSemantics


  // ==========================================================
  // STRUCTURAL EXECUTION REQUEST BOUNDARY
  // ==========================================================

  // A structurally valid ExecutionRequest establishes structural
  // validity of its embedded Authorization.
  //
  // It does not, by itself, establish that the Authorization was
  // accepted for a particular Account.

  lemma ValidExecutionRequestDoesNotByItselfEstablishAuthorizationAcceptance(
    request: ExecutionRequest
  )
    requires ValidExecutionRequest(request)
    ensures ValidAuthorization(
              ExecutionRequestAuthorization(request)
            )
  {
  }


  // ==========================================================
  // COMPLETE EXECUTION CONTEXT REQUIRES ACCEPTANCE
  // ==========================================================

  // A complete ExecutionContext for an Account explicitly
  // represents an already accepted Authorization.

  lemma ValidExecutionContextForAccountAlwaysRepresentsAcceptedAuthorization(
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


  // Complete ExecutionContext validity therefore establishes the
  // full Authorization acceptance relation.

  lemma ValidExecutionContextForAccountImpliesAuthorizationAcceptance(
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
    ensures AuthorizationCanBeAccepted(
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
  {
  }


  // ==========================================================
  // STRUCTURAL CONTEXT REMAINS WEAKER
  // ==========================================================

  // Structural coherence is deliberately weaker than complete
  // Account-level execution validity.

  lemma StructurallyValidExecutionContextDoesNotEstablishAcceptance(
    context: ExecutionContext
  )
    requires StructurallyValidExecutionContext(context)
    ensures ValidExecutionRequest(
              ExecutionContextRequest(context)
            )
    ensures ValidAuthorizationState(
              ExecutionContextAuthorizationState(context)
            )
    ensures ValidEffectiveAuthority(
              ExecutionContextEffectiveAuthority(context)
            )
    ensures ExecutionContextCredentialIsUsable(
              context
            )
  {
  }


  // ==========================================================
  // CONCRETE REPLAY WITNESS
  // ==========================================================

  // This predicate packages the complete witness condition used
  // by the concrete replay scenario.
  //
  // It is a proof-harness abstraction only.
  //
  // It does not add, weaken, or redefine productive domain
  // semantics.

  ghost predicate ConcreteConsumedReplayWitness(
    account: Account,
    authorization: Authorization,
    request: ExecutionRequest,
    context: ExecutionContext,
    capability: Capability,
    effectiveAuthority: EffectiveAuthority,
    evaluationTime: Timestamp,
    sourceReferences: seq<AuthoritySourceReference>
  )
  {
    ValidAccount(account)

    && ValidAuthorizationState(
      AccountAuthorizationState(account)
    )

    && AuthorizationReplayKey(
      authorization
    )
       in
         StateConsumedReplayKeys(
           AccountAuthorizationState(account)
         )

    && !AuthorizationReplayIsFresh(
      authorization,
      AccountAuthorizationState(account)
    )

    && ValidAuthorization(
      authorization
    )

    && ValidExecutionRequest(
      request
    )

    && StructurallyValidExecutionContext(
      context
    )

    && !ValidExecutionContextForAccount(
      context,
      account,
      {
        AccountSovereignIdentity(account)
      },
      sourceReferences,
      [{ capability }],
      [{ capability }],
      true
    )

    && ExecutionContextAuthorization(context)
       ==
       authorization

    && ExecutionContextRequest(context)
       ==
       request

    && capability in effectiveAuthority

    && ValidEffectiveAuthority(
      effectiveAuthority
    )
  }


  // ==========================================================
  // ATTACK A — TEMPORALLY INVALID AUTHORIZATION
  // ==========================================================

  // The authorization acceptance contract explicitly requires
  // current temporal validity.
  //
  // Therefore an expired or otherwise temporally invalid
  // Authorization cannot be accepted regardless of the Effective
  // Authority, provenance witness, or external Proof result.

  lemma TemporallyInvalidAuthorizationCannotBeAccepted(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool
  )
    requires !AuthorizationIsTemporallyValidAt(
               authorization,
               now
             )
    ensures !AuthorizationCanBeAccepted(
              authorization,
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
  }


  // A temporally invalid Authorization cannot form the complete
  // Account-level ExecutionContext for that same evaluation time.

  lemma TemporallyInvalidAuthorizationCannotFormCompleteExecutionContext(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool
  )
    requires !AuthorizationIsTemporallyValidAt(
               ExecutionContextAuthorization(context),
               ExecutionContextEvaluationTime(context)
             )
    ensures !ValidExecutionContextForAccount(
              context,
              account,
              identities,
              sourceReferences,
              sourceAuthorities,
              contributions,
              proofVerified
            )
  {
    if ValidExecutionContextForAccount(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified
      )
    {
      ValidExecutionContextForAccountImpliesAuthorizationAcceptance(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified
      );

      assert false;
    }
  }


  // ==========================================================
  // ATTACK B — REPLAY-CONSUMED AUTHORIZATION
  // ==========================================================

  // If the replay key is already consumed in the Account state,
  // Authorization acceptance is impossible.

  lemma ConsumedReplayKeyCannotBeAccepted(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool
  )
    requires AuthorizationReplayKey(
               authorization
             )
             in
               StateConsumedReplayKeys(
                 AccountAuthorizationState(account)
               )
    ensures !AuthorizationCanBeAccepted(
              authorization,
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
  }


  // A replay-consumed Authorization cannot form the complete
  // Account-level ExecutionContext.

  lemma ConsumedReplayKeyCannotFormCompleteExecutionContext(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool
  )
    requires AuthorizationReplayKey(
               ExecutionContextAuthorization(context)
             )
             in
               StateConsumedReplayKeys(
                 AccountAuthorizationState(account)
               )
    ensures !ValidExecutionContextForAccount(
              context,
              account,
              identities,
              sourceReferences,
              sourceAuthorities,
              contributions,
              proofVerified
            )
  {
    if ValidExecutionContextForAccount(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified
      )
    {
      ValidExecutionContextForAccountImpliesAuthorizationAcceptance(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified
      );

      assert false;
    }
  }


  // ==========================================================
  // ATTACK C — FAILED EXTERNAL PROOF
  // ==========================================================

  // Proof verification is an explicit acceptance requirement.
  //
  // ExecutionContext does not contain the Proof result itself.
  // The result is supplied to the complete validation relation.

  lemma FailedProofCannotBeAccepted(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp
  )
    ensures !AuthorizationCanBeAccepted(
              authorization,
              account,
              effectiveAuthority,
              identities,
              sourceReferences,
              sourceAuthorities,
              contributions,
              now,
              false
            )
  {
  }


  // A failed external Proof result therefore prevents formation
  // of a complete Account-level ExecutionContext.

  lemma FailedProofCannotFormCompleteExecutionContext(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>
  )
    ensures !ValidExecutionContextForAccount(
              context,
              account,
              identities,
              sourceReferences,
              sourceAuthorities,
              contributions,
              false
            )
  {
    if ValidExecutionContextForAccount(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        false
      )
    {
      ValidExecutionContextForAccountImpliesAuthorizationAcceptance(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        false
      );

      assert false;
    }
  }


  // ==========================================================
  // ATTACK D — ENGINE INPUT REQUIRES COMPLETE CONTEXT
  // ==========================================================

  // ExecutionEngineInputIsValid is stronger than structural
  // ExecutionContext validity because it depends on
  // ValidExecutionContextForAccount and requires the concrete
  // ExecutionConstraints verification witness.

  lemma ValidEngineInputImpliesCompleteExecutionContext(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints
  )
    requires ExecutionEngineInputIsValid(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified,
               verifiedConstraints
             )
    ensures ValidExecutionContextForAccount(
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


  // Therefore Engine input validity implies Authorization
  // acceptance for the same validation witnesses.

  lemma ValidEngineInputImpliesAuthorizationAcceptance(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints
  )
    requires ExecutionEngineInputIsValid(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified,
               verifiedConstraints
             )
    ensures AuthorizationCanBeAccepted(
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
  {
    ValidExecutionContextForAccountImpliesAuthorizationAcceptance(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified
    );
  }


  // ==========================================================
  // ATTACK E — FAILED AUTHORIZATION CANNOT REACH ENGINE INPUT
  // ==========================================================

  // If AuthorizationCanBeAccepted is false for the Authorization
  // carried by the context, the context cannot become valid Engine
  // input through another route.

  lemma FailedAuthorizationCannotBecomeValidEngineInput(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints
  )
    requires !AuthorizationCanBeAccepted(
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
    ensures !ExecutionEngineInputIsValid(
              context,
              account,
              identities,
              sourceReferences,
              sourceAuthorities,
              contributions,
              proofVerified,
              verifiedConstraints
            )
  {
    if ExecutionEngineInputIsValid(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified,
        verifiedConstraints
      )
    {
      ValidEngineInputImpliesAuthorizationAcceptance(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified,
        verifiedConstraints
      );

      assert false;
    }
  }


  // ==========================================================
  // ATTACK F — FAILED AUTHORIZATION CANNOT ENTER ENGINE
  // ==========================================================

  // The environment-specific Engine boundary is downstream of the
  // intrinsic Engine input validity relation.
  //
  // Therefore a failed Authorization acceptance cannot cross the
  // environment-specific materialization boundary either.

  lemma FailedAuthorizationCannotEnterExecutionEngine(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints,
    environment: ExecutionEnvironment,
    compatibilityRelation: set<(Chain, ExecutionEnvironment)>
  )
    requires !AuthorizationCanBeAccepted(
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
    ensures !ExecutionContextCanEnterExecutionEngine(
              context,
              account,
              identities,
              sourceReferences,
              sourceAuthorities,
              contributions,
              proofVerified,
              verifiedConstraints,
              environment,
              compatibilityRelation
            )
  {
    if ExecutionContextCanEnterExecutionEngine(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified,
        verifiedConstraints,
        environment,
        compatibilityRelation
      )
    {
      ValidEngineInputImpliesAuthorizationAcceptance(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified,
        verifiedConstraints
      );

      assert false;
    }
  }


  // ==========================================================
  // ATTACK G — CONCRETE STRUCTURAL / TEMPORAL SEPARATION
  // ==========================================================

  // A structurally valid ExecutionContext may carry an expired
  // Authorization.
  //
  // This does NOT produce a complete valid ExecutionContext.
  //
  // The distinction is intentional:
  //
  //     structural value coherence
  //         !=
  //     complete validated execution decision.
  //
  // ExecutionConstraints is supplied as an opaque Value Object.

  lemma ConcreteExpiredAuthorizationIsStructurallyValidButNotComplete(
    executionTarget: ExecutionTarget,
    domainAction: DomainAction,
    chain: Chain,
    constraints: ExecutionConstraints,
    sourceReferences: seq<AuthoritySourceReference>
  )
    ensures exists
              account: Account,
              authorization: Authorization,
              request: ExecutionRequest,
              context: ExecutionContext,
              capability: Capability,
              effectiveAuthority: EffectiveAuthority,
              evaluationTime: Timestamp ::

              ValidAccount(account)

              && ValidAuthorizationState(
                AccountAuthorizationState(account)
              )

              && ValidAuthorization(
                authorization
              )

              && !AuthorizationIsTemporallyValidAt(
                authorization,
                evaluationTime
              )

              && ValidExecutionRequest(
                request
              )

              && StructurallyValidExecutionContext(
                context
              )

              && !ValidExecutionContextForAccount(
                context,
                account,
                {
                  AccountSovereignIdentity(account)
                },
                sourceReferences,
                [{ capability }],
                [{ capability }],
                true
              )

              && ExecutionContextAuthorization(context)
                 ==
                 authorization

              && ExecutionContextRequest(context)
                 ==
                 request

              && ExecutionContextEffectiveAuthority(context)
                 ==
                 effectiveAuthority

              && ExecutionContextEvaluationTime(context)
                 ==
                 evaluationTime

              && capability in effectiveAuthority

              && ValidEffectiveAuthority(
                effectiveAuthority
              )
  {
    var accountId: AccountId := [100];
    var identityId: Id := [101];
    var subjectReference: Id := [102];

    var credentialId: Id := [103];
    var replayKey: Id := [104];

    var scopeAtomId: Id := [105];

    var subject := Subject(
      subjectReference
    );

    var identity := Identity(
      identityId,
      subject
    );

    var scopeAtom := ScopeAtom(
      scopeAtomId
    );

    var scope := Scope(
      { scopeAtom }
    );

    var capabilityKind := CapabilityKind(
      "IncompleteExecutionTemporalTest"
    );

    var capability := Capability(
      capabilityKind,
      scope
    );

    var credential := Credential(
      credentialId,
      CredentialStatus.Active
    );

    var authorizationState := AuthorizationState(
      {},
      { credential },
      map[credentialId := { capability }],
      {},
      {},
      map[],
      map[],
      {},
      {}
    );

    var account := Account(
      accountId,
      identity,
      authorizationState
    );

    var authorization := Authorization(
      credentialId,
      { capability },
      {},
      0,
      10,
      replayKey,
      accountId,
      executionTarget,
      domainAction,
      scope,
      chain
    );

    var request := ExecutionRequest(
      domainAction,
      authorization,
      executionTarget,
      constraints
    );

    var effectiveAuthority: EffectiveAuthority := {
      capability
    };

    var evaluationTime: Timestamp := 50;

    var context := ExecutionContext(
      request,
      authorizationState,
      effectiveAuthority,
      evaluationTime
    );

    assert ValidId(accountId);
    assert ValidId(identityId);
    assert ValidId(subjectReference);
    assert ValidId(credentialId);
    assert ValidId(replayKey);
    assert ValidId(scopeAtomId);

    assert ValidSubject(subject);
    assert ValidIdentity(identity);

    assert ValidScopeAtom(scopeAtom);
    assert ValidScope(scope);

    assert ValidCapabilityKind(
        capabilityKind
      );

    assert ValidCapability(
        capability
      );

    assert ValidCredential(
        credential
      );

    assert ValidAuthorizationState(
        authorizationState
      );

    assert ValidAccount(
        account
      );

    assert ValidAuthorization(
        authorization
      );

    assert ValidExecutionRequest(
        request
      );

    assert ValidEffectiveAuthority(
        effectiveAuthority
      );

    assert RequestedAuthorityWithinEffectiveAuthority(
        authorization,
        effectiveAuthority
      );

    assert AuthorizationCredentialIsUsable(
        authorization,
        authorizationState
      );

    assert !AuthorizationIsTemporallyValidAt(
        authorization,
        evaluationTime
      );

    assert ExecutionContextAuthorization(context)
           ==
           authorization;

    assert ExecutionContextRequest(context)
           ==
           request;

    assert ExecutionContextEffectiveAuthority(context)
           ==
           effectiveAuthority;

    assert ExecutionContextEvaluationTime(context)
           ==
           evaluationTime;

    assert StructurallyValidExecutionContext(
        context
      );

    TemporallyInvalidAuthorizationCannotFormCompleteExecutionContext(
      context,
      account,
      {
        AccountSovereignIdentity(account)
      },
      sourceReferences,
      [{ capability }],
      [{ capability }],
      true
    );

    assert !ValidExecutionContextForAccount(
        context,
        account,
        {
          AccountSovereignIdentity(account)
        },
        sourceReferences,
        [{ capability }],
        [{ capability }],
        true
      );
  }


  // ==========================================================
  // ATTACK H — CONCRETE STRUCTURAL / REPLAY SEPARATION
  // ==========================================================

  // A structurally valid ExecutionContext may carry a replay-
  // consumed Authorization.
  //
  // Complete execution-context validation still rejects it.
  //
  // This witness demonstrates the distinction:
  //
  //     structurally coherent context
  //
  // can exist as a value while:
  //
  //     replay-consumed Authorization
  //
  // prevents the value from becoming a complete validated
  // execution decision.
  //
  // The existential contract is expressed through
  // ConcreteConsumedReplayWitness.

  lemma ConcreteConsumedReplayAuthorizationIsStructurallyValidButNotComplete(
    executionTarget: ExecutionTarget,
    domainAction: DomainAction,
    chain: Chain,
    constraints: ExecutionConstraints,
    sourceReferences: seq<AuthoritySourceReference>
  )
    ensures exists
              account: Account,
              authorization: Authorization,
              request: ExecutionRequest,
              context: ExecutionContext,
              capability: Capability,
              effectiveAuthority: EffectiveAuthority,
              evaluationTime: Timestamp ::

              ConcreteConsumedReplayWitness(
                account,
                authorization,
                request,
                context,
                capability,
                effectiveAuthority,
                evaluationTime,
                sourceReferences
              )
  {
    var accountId: AccountId := [110];
    var identityId: Id := [111];
    var subjectReference: Id := [112];

    var credentialId: Id := [113];
    var replayKey: Id := [114];

    var scopeAtomId: Id := [115];

    var subject := Subject(
      subjectReference
    );

    var identity := Identity(
      identityId,
      subject
    );

    var scopeAtom := ScopeAtom(
      scopeAtomId
    );

    var scope := Scope(
      { scopeAtom }
    );

    var capabilityKind := CapabilityKind(
      "IncompleteExecutionReplayTest"
    );

    var capability := Capability(
      capabilityKind,
      scope
    );

    var credential := Credential(
      credentialId,
      CredentialStatus.Active
    );

    var authorizationState := AuthorizationState(
      {},
      { credential },
      map[credentialId := { capability }],
      {},
      {},
      map[],
      map[],
      {},
      { replayKey }
    );

    var account := Account(
      accountId,
      identity,
      authorizationState
    );

    var authorization := Authorization(
      credentialId,
      { capability },
      {},
      0,
      100,
      replayKey,
      accountId,
      executionTarget,
      domainAction,
      scope,
      chain
    );

    var request := ExecutionRequest(
      domainAction,
      authorization,
      executionTarget,
      constraints
    );

    var effectiveAuthority: EffectiveAuthority := {
      capability
    };

    var evaluationTime: Timestamp := 50;

    var context := ExecutionContext(
      request,
      authorizationState,
      effectiveAuthority,
      evaluationTime
    );

    // --------------------------------------------------------
    // Primitive / value validity
    // --------------------------------------------------------

    assert ValidId(accountId);
    assert ValidId(identityId);
    assert ValidId(subjectReference);
    assert ValidId(credentialId);
    assert ValidId(replayKey);
    assert ValidId(scopeAtomId);

    assert ValidSubject(subject);
    assert ValidIdentity(identity);

    assert ValidScopeAtom(scopeAtom);
    assert ValidScope(scope);

    assert ValidCapabilityKind(
        capabilityKind
      );

    assert ValidCapability(
        capability
      );

    assert ValidCredential(
        credential
      );

    // --------------------------------------------------------
    // State validity
    // --------------------------------------------------------

    assert ValidAuthorizationState(
        authorizationState
      );

    assert ValidAccount(
        account
      );

    // --------------------------------------------------------
    // Authorization / request validity
    // --------------------------------------------------------

    assert ValidAuthorization(
        authorization
      );

    assert ValidExecutionRequest(
        request
      );

    assert ValidEffectiveAuthority(
        effectiveAuthority
      );

    assert capability in effectiveAuthority;

    assert RequestedAuthorityWithinEffectiveAuthority(
        authorization,
        effectiveAuthority
      );

    assert AuthorizationCredentialIsUsable(
        authorization,
        authorizationState
      );

    // --------------------------------------------------------
    // Replay condition
    // --------------------------------------------------------

    assert AuthorizationReplayKey(
        authorization
      )
           in
             StateConsumedReplayKeys(
               authorizationState
             );

    assert !AuthorizationReplayIsFresh(
        authorization,
        authorizationState
      );

    // --------------------------------------------------------
    // Structural context
    // --------------------------------------------------------

    assert StructurallyValidExecutionContext(
        context
      );

    // --------------------------------------------------------
    // Complete Account-level context must fail because the
    // Authorization replay key has already been consumed.
    // --------------------------------------------------------

    ConsumedReplayKeyCannotFormCompleteExecutionContext(
      context,
      account,
      {
        AccountSovereignIdentity(account)
      },
      sourceReferences,
      [{ capability }],
      [{ capability }],
      true
    );

    assert !ValidExecutionContextForAccount(
        context,
        account,
        {
          AccountSovereignIdentity(account)
        },
        sourceReferences,
        [{ capability }],
        [{ capability }],
        true
      );

    // --------------------------------------------------------
    // Concrete replay witness
    // --------------------------------------------------------

    assert ConcreteConsumedReplayWitness(
        account,
        authorization,
        request,
        context,
        capability,
        effectiveAuthority,
        evaluationTime,
        sourceReferences
      );
  }


  // ==========================================================
  // ATTACK I — CONCRETE STRUCTURAL / PROOF SEPARATION
  // ==========================================================

  // A structurally valid ExecutionContext contains no Proof field.
  //
  // Therefore the same structurally valid context can be examined
  // under a failed external Proof result. The complete Account-level
  // validation rejects that result.

  lemma ConcreteFailedProofAuthorizationIsStructurallyValidButNotComplete(
    executionTarget: ExecutionTarget,
    domainAction: DomainAction,
    chain: Chain,
    constraints: ExecutionConstraints,
    sourceReferences: seq<AuthoritySourceReference>
  )
    ensures exists
              account: Account,
              authorization: Authorization,
              request: ExecutionRequest,
              context: ExecutionContext,
              capability: Capability,
              effectiveAuthority: EffectiveAuthority,
              evaluationTime: Timestamp ::

              ValidAccount(account)

              && ValidAuthorizationState(
                AccountAuthorizationState(account)
              )

              && ValidAuthorization(
                authorization
              )

              && AuthorizationIsTemporallyValidAt(
                authorization,
                evaluationTime
              )

              && AuthorizationReplayIsFresh(
                authorization,
                AccountAuthorizationState(account)
              )

              && ValidExecutionRequest(
                request
              )

              && StructurallyValidExecutionContext(
                context
              )

              && !ValidExecutionContextForAccount(
                context,
                account,
                {
                  AccountSovereignIdentity(account)
                },
                sourceReferences,
                [{ capability }],
                [{ capability }],
                false
              )

              && ExecutionContextAuthorization(context)
                 ==
                 authorization

              && ExecutionContextRequest(context)
                 ==
                 request

              && capability in effectiveAuthority

              && ValidEffectiveAuthority(
                effectiveAuthority
              )
  {
    var accountId: AccountId := [120];
    var identityId: Id := [121];
    var subjectReference: Id := [122];

    var credentialId: Id := [123];
    var replayKey: Id := [124];

    var scopeAtomId: Id := [125];

    var subject := Subject(
      subjectReference
    );

    var identity := Identity(
      identityId,
      subject
    );

    var scopeAtom := ScopeAtom(
      scopeAtomId
    );

    var scope := Scope(
      { scopeAtom }
    );

    var capabilityKind := CapabilityKind(
      "IncompleteExecutionProofTest"
    );

    var capability := Capability(
      capabilityKind,
      scope
    );

    var credential := Credential(
      credentialId,
      CredentialStatus.Active
    );

    var authorizationState := AuthorizationState(
      {},
      { credential },
      map[credentialId := { capability }],
      {},
      {},
      map[],
      map[],
      {},
      {}
    );

    var account := Account(
      accountId,
      identity,
      authorizationState
    );

    var authorization := Authorization(
      credentialId,
      { capability },
      {},
      0,
      100,
      replayKey,
      accountId,
      executionTarget,
      domainAction,
      scope,
      chain
    );

    var request := ExecutionRequest(
      domainAction,
      authorization,
      executionTarget,
      constraints
    );

    var effectiveAuthority: EffectiveAuthority := {
      capability
    };

    var evaluationTime: Timestamp := 50;

    var context := ExecutionContext(
      request,
      authorizationState,
      effectiveAuthority,
      evaluationTime
    );

    // --------------------------------------------------------
    // Primitive / value validity
    // --------------------------------------------------------

    assert ValidId(accountId);
    assert ValidId(identityId);
    assert ValidId(subjectReference);
    assert ValidId(credentialId);
    assert ValidId(replayKey);
    assert ValidId(scopeAtomId);

    assert ValidSubject(subject);
    assert ValidIdentity(identity);

    assert ValidScopeAtom(scopeAtom);
    assert ValidScope(scope);

    assert ValidCapabilityKind(
        capabilityKind
      );

    assert ValidCapability(
        capability
      );

    assert ValidCredential(
        credential
      );

    // --------------------------------------------------------
    // State validity
    // --------------------------------------------------------

    assert ValidAuthorizationState(
        authorizationState
      );

    assert ValidAccount(
        account
      );

    // --------------------------------------------------------
    // Authorization validity
    // --------------------------------------------------------

    assert ValidAuthorization(
        authorization
      );

    assert AuthorizationIsTemporallyValidAt(
        authorization,
        evaluationTime
      );

    assert AuthorizationReplayIsFresh(
        authorization,
        authorizationState
      );

    assert AuthorizationCredentialIsUsable(
        authorization,
        authorizationState
      );

    // --------------------------------------------------------
    // Execution request / authority
    // --------------------------------------------------------

    assert ValidExecutionRequest(
        request
      );

    assert ValidEffectiveAuthority(
        effectiveAuthority
      );

    assert RequestedAuthorityWithinEffectiveAuthority(
        authorization,
        effectiveAuthority
      );

    // --------------------------------------------------------
    // Structural context
    // --------------------------------------------------------

    assert StructurallyValidExecutionContext(
        context
      );

    // --------------------------------------------------------
    // Complete context fails when Proof = false
    // --------------------------------------------------------

    assert !ValidExecutionContextForAccount(
        context,
        account,
        {
          AccountSovereignIdentity(account)
        },
        sourceReferences,
        [{ capability }],
        [{ capability }],
        false
      );
  }


  // ==========================================================
  // ATTACK J — ENGINE ENTRY CANNOT BYPASS ACCOUNT VALIDATION
  // ==========================================================

  // Any context admitted by the environment-specific Engine gate
  // must already satisfy the complete Account-level execution
  // contract.

  lemma EngineEntryImpliesAuthorizationAcceptance(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints,
    environment: ExecutionEnvironment,
    compatibilityRelation: set<(Chain, ExecutionEnvironment)>
  )
    requires ExecutionContextCanEnterExecutionEngine(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified,
               verifiedConstraints,
               environment,
               compatibilityRelation
             )
    ensures AuthorizationCanBeAccepted(
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
  {
    ValidEngineInputImpliesAuthorizationAcceptance(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified,
      verifiedConstraints
    );
  }


  // ==========================================================
  // SCENARIO CONCLUSION
  // ==========================================================
  //
  // The formal model intentionally maintains the distinction between:
  //
  //     StructurallyValidExecutionContext
  //
  // and:
  //
  //     ValidExecutionContextForAccount
  //
  // The first establishes structural coherence only.
  //
  // The second establishes a complete validated execution decision
  // for the relevant Account and therefore reuses the complete
  // Authorization acceptance contract.
  //
  // Consequently:
  //
  //     expired Authorization
  //         → cannot form complete context
  //
  //     consumed Replay key
  //         → cannot form complete context
  //
  //     failed Proof verification
  //         → cannot form complete context
  //
  // and therefore:
  //
  //     failed Authorization acceptance
  //         → cannot become valid Engine input
  //
  //         → cannot enter the Execution Engine
  //
  // ------------------------------------------------------------
  //
  // EXECUTION CONSTRAINTS
  //
  // The Engine boundary receives `verifiedConstraints` as the
  // concrete ExecutionConstraints verification witness.
  //
  // The witness is required by the existing execution semantics and
  // is bound to the exact constraints carried by the context.
  //
  // This scenario does not interpret ExecutionConstraints or define
  // any constraint algebra. It only propagates the established
  // execution-boundary contract.
  //
  // ------------------------------------------------------------
  //
  // DDD CORRESPONDENCE
  //
  // The formal boundary matches the DDD meaning of
  // ExecutionContext as the complete validated execution decision.
  //
  // The corresponding Runtime responsibility is represented as a
  // contract boundary:
  //
  //     validate Authorization
  //             ↓
  //     determine Effective Authority
  //             ↓
  //     verify applicable execution conditions
  //             ↓
  //     construct complete ExecutionContext
  //             ↓
  //     deliver only valid contexts to Engine
  //
  // ------------------------------------------------------------
  //
  // FINAL CLASSIFICATION
  //
  //     DOMAIN SEMANTICS: PRESERVED
  //     EXECUTION CONTEXT COMPLETENESS: ENFORCED
  //     AUTHORIZATION → CONTEXT BRIDGE: ENFORCED
  //     CONTEXT → ENGINE BRIDGE: ENFORCED
  //     ENGINE ENTRY → AUTHORIZATION ACCEPTANCE: ENFORCED
  //     TEMPORAL BYPASS: BLOCKED
  //     REPLAY BYPASS: BLOCKED
  //     PROOF BYPASS: BLOCKED
  //     EFFECTIVE AUTHORITY PROVENANCE: COVERED ELSEWHERE
  //     STRUCTURAL CONTEXT != COMPLETE CONTEXT: VERIFIED
  //     DDD CONTRADICTION: NONE
  //     DDD DEBT: NONE FOR THIS SCENARIO
  //     FORMALIZATION DEBT: NONE FOR THIS SCENARIO
  //     SECURITY DEBT: NONE IDENTIFIED
  //     PROOF-ENGINEERING STATUS: STABLE
  //     REGRESSION VALUE: HIGH
  //
  // This scenario remains an adversarial proof harness. It does not
  // modify productive domain definitions or introduce alternative
  // semantics for Authorization, Proof, ExecutionConstraints,
  // Runtime, or the Execution Engine.
  //
  // ==========================================================
}

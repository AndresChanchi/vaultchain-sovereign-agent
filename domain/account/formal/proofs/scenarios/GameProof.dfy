// ============================================================
// KIPIO ACCOUNT DOMAIN
// SCENARIO — GAME
// ============================================================
//
// Game validates temporal authority across the complete
// authorization-to-execution composition.
//
// The scenario verifies that temporal validity is preserved across:
//
//     Session
//        |
//        v
//     Authorization
//        |
//        v
//     Authorization Validation
//        |
//        v
//     ExecutionContext
//        |
//        v
//     Execution Engine
//
// The domain explicitly separates:
//
//     structural validity
//         !=
//     temporal validity
//
// and:
//
//     Session temporal validity
//         !=
//     Authorization temporal validity
//
// The current execution model requires an accepted Authorization
// when establishing an Account-relative ExecutionContext.
//
// Therefore the historical ExecutionContext temporal gap is no
// longer the correct attack surface.
//
// The current Game boundary is instead:
//
//     Authorization temporal validity
//          |
//          v
//     Authorization acceptance
//          |
//          v
//     Account-relative ExecutionContext
//          |
//          v
//     Execution Engine input
//          |
//          v
//     Execution Engine entry
//
// ------------------------------------------------------------
//
// PRIMARY OBJECTIVES
//
//   1. Verify the explicit Session temporal boundary:
//
//        validFrom <= now <= validUntil
//
//   2. Verify that a Session before or after its validity interval
//      cannot currently exercise authority.
//
//   3. Verify that an Authorization before or after its validity
//      interval cannot be accepted.
//
//   4. Verify that accepted Authorization is temporally valid at
//      the evaluation time.
//
//   5. Verify that Account-relative ExecutionContext validity
//      preserves the accepted Authorization temporal boundary.
//
//   6. Attack construction of an ExecutionContext carrying an
//      Authorization that is temporally invalid at the context's
//      evaluation time.
//
//   7. Verify that temporally invalid Authorization cannot produce
//      valid Execution Engine input.
//
//   8. Verify that temporally invalid Authorization cannot reach
//      the Execution Engine entry boundary.
//
//   9. Verify that the evaluation time carried by a valid
//      ExecutionContext is preserved when execution semantics
//      cross into the execution engine.
//
//  10. Verify that the complete temporal composition does not
//      introduce a temporal exception between acceptance,
//      materialization, engine input, and engine entry.
//
// ------------------------------------------------------------
//
// CURRENT ARCHITECTURAL FACT
//
// The current ValidExecutionContextForAccount predicate already
// incorporates the accepted-Authorization boundary.
//
// Consequently:
//
//     ValidExecutionContextForAccount(...)
//         implies
//     AuthorizationCanBeAccepted(...)
//         implies
//     AuthorizationIsTemporallyValidAt(...)
//
// The old historical attack:
//
//     ValidExecutionContext(context)
//       +
//     temporally invalid Authorization
//
// is therefore no longer a valid finding.
//
// GameProof now verifies that this resolved boundary is preserved
// throughout the execution composition.
//
// ------------------------------------------------------------
//
// IMPORTANT METHODOLOGICAL RULE
//
// This scenario does NOT modify domain semantics.
//
// It does not add:
//
//   - a new temporal datatype
//   - issuedAt
//   - session/authorization interval equality
//   - execution clock semantics
//   - temporal semantics to Target
//   - temporal semantics to Constraints
//
// All reasoning uses the timestamps and predicates already present
// in Session, Authorization and ExecutionContext.
//
// ------------------------------------------------------------
//
// EXECUTION-CONSTRAINT BOUNDARY
//
// ExecutionEngineUsesContextEvaluationTime is an execution-boundary
// property. Its current contract requires:
//
//     ExecutionEngineInputIsValid(...)
//         +
//     ExecutionConstraintsAreVerified(
//         context,
//         verifiedConstraints
//     )
//
// The `verifiedConstraints` parameter is the concrete
// ExecutionConstraints value supplied as the verification witness.
// The boundary therefore binds verification to the exact constraints
// carried by the ExecutionContext without introducing any constraint
// algebra or evaluator here.
//
// This does not change temporal semantics.
//
// It records the existing execution precondition required to cross
// into the Execution Engine.
//
// ------------------------------------------------------------
//
// EXPECTED RESULT
//
// Session:
//
//     inside interval -> can exercise
//     before interval -> cannot exercise
//     after interval  -> cannot exercise
//
// Authorization:
//
//     inside interval -> temporally valid
//     before interval -> cannot be accepted
//     after interval  -> cannot be accepted
//
// ExecutionContext:
//
//     accepted Authorization
//         -> temporally valid at evaluationTime
//
// Execution:
//
//     invalid temporal Authorization
//         -> cannot form valid ExecutionContext
//         -> cannot form valid engine input
//         -> cannot enter execution
//
//     valid temporal ExecutionContext
//         -> evaluationTime preserved
//
// ============================================================


include "../../foundation/DomainPrimitives.dfy"

include "../../authority/Credential.dfy"
include "../../authority/CredentialAuthority.dfy"
include "../../authority/Session.dfy"
include "../../authority/EffectiveAuthority.dfy"
include "../../authority/AuthorizationState.dfy"

include "../../authorization/Authorization.dfy"
include "../../authorization/AuthorizationValidation.dfy"
include "../../authorization/Replay.dfy"

include "../../account/Account.dfy"

include "../../execution/ExecutionConstraints.dfy"
include "../../execution/ExecutionRequest.dfy"
include "../../execution/ExecutionContext.dfy"
include "../../execution/ExecutionSemantics.dfy"

include "../../laws/AuthorityLaws.dfy"
include "../../laws/AuthorizationLaws.dfy"
include "../../laws/SessionLaws.dfy"
include "../../laws/ExecutionLaws.dfy"

include "../isolated/AuthorityProofs.dfy"
include "../isolated/AuthorizationProofs.dfy"
include "../isolated/ExecutionProofs.dfy"


module KipioAccountGameProof
{
  // ----------------------------------------------------------
  // DOMAIN IMPORTS
  // ----------------------------------------------------------

  import opened KipioAccountDomainPrimitives

  import opened KipioAccountCredential
  import opened KipioAccountCredentialAuthority
  import opened KipioAccountSession
  import opened KipioAccountEffectiveAuthority
  import opened KipioAccountAuthorizationState

  import opened KipioAccountAuthorization
  import opened KipioAccountAuthorizationValidation
  import opened KipioAccountReplay

  import opened KipioAccountAccount

  import opened KipioAccountExecutionConstraints
  import opened KipioAccountExecutionRequest
  import opened KipioAccountExecutionContext
  import opened KipioAccountExecutionSemantics

  import opened KipioAccountAuthorityLaws
  import opened KipioAccountAuthorizationLaws
  import opened KipioAccountSessionLaws
  import opened KipioAccountExecutionLaws

  import opened KipioAccountAuthorityProofs
  import opened KipioAccountAuthorizationProofs
  import opened KipioAccountExecutionProofs

  import opened KipioAccountCapability
  import opened KipioAccountIdentity
  import opened KipioAccountChain


  // ==========================================================
  // ATTACK 1 — SESSION TEMPORAL WINDOW
  // ==========================================================

  // Inside its inclusive validity interval, an Active Session is
  // temporally admissible for authority exercise.
  lemma GameActiveSessionIsTemporallyUsableInsideWindow(
    session: Session,
    now: Timestamp
  )
    requires ValidSession(session)
    requires SessionIsActive(session)
    requires SessionValidFrom(session) <= now
    requires now <= SessionValidUntil(session)
    ensures SessionIsWithinValidityIntervalAt(
              session,
              now
            )
    ensures SessionCanCurrentlyExerciseAuthorityAt(
              session,
              now
            )
  {
    assert SessionIsWithinValidityIntervalAt(
        session,
        now
      );

    assert ValidSession(session);

    assert SessionIsActive(session);

    assert SessionCanCurrentlyExerciseAuthorityAt(
        session,
        now
      );
  }


  // At validUntil exactly, the Session remains inside its
  // inclusive temporal interval.
  lemma GameSessionUpperBoundaryIsInclusive(
    session: Session
  )
    requires ValidSession(session)
    ensures SessionIsWithinValidityIntervalAt(
              session,
              SessionValidUntil(session)
            )
  {
    SessionIsValidAtItsUpperTemporalBoundary(
      session
    );
  }


  // At validFrom exactly, the Session remains inside its
  // inclusive temporal interval.
  lemma GameSessionLowerBoundaryIsInclusive(
    session: Session
  )
    requires ValidSession(session)
    ensures SessionIsWithinValidityIntervalAt(
              session,
              SessionValidFrom(session)
            )
  {
    assert SessionValidFrom(session)
           <=
           SessionValidUntil(session);

    assert SessionValidFrom(session)
           <=
           SessionValidFrom(session);

    assert SessionIsWithinValidityIntervalAt(
        session,
        SessionValidFrom(session)
      );
  }


  // After validUntil, the Session is outside the temporal
  // validity interval.
  lemma GameExpiredSessionIsOutsideTemporalWindow(
    session: Session,
    now: Timestamp
  )
    requires ValidSession(session)
    requires SessionIsExpiredAt(
               session,
               now
             )
    ensures !SessionIsWithinValidityIntervalAt(
              session,
              now
            )
  {
    ExpiredSessionIsOutsideValidityInterval(
      session,
      now
    );
  }


  // An expired Session cannot currently exercise authority.
  lemma GameExpiredSessionCannotExerciseAuthority(
    session: Session,
    now: Timestamp
  )
    requires SessionIsExpiredAt(
               session,
               now
             )
    ensures !SessionCanCurrentlyExerciseAuthorityAt(
              session,
              now
            )
  {
    ExpiredSessionCannotCurrentlyExerciseAuthority(
      session,
      now
    );
  }


  // Before validFrom, a Session cannot currently exercise authority.
  lemma GamePrematureSessionCannotExerciseAuthority(
    session: Session,
    now: Timestamp
  )
    requires ValidSession(session)
    requires now < SessionValidFrom(session)
    ensures !SessionCanCurrentlyExerciseAuthorityAt(
              session,
              now
            )
  {
    KipioAccountSessionLaws
      .SessionCannotExerciseBeforeValidityBegins(
      session,
      now
    );
  }


  // ==========================================================
  // ATTACK 2 — AUTHORIZATION TEMPORAL WINDOW
  // ==========================================================

  // At a timestamp inside the Authorization interval, temporal
  // applicability holds.
  lemma GameAuthorizationIsTemporallyUsableInsideWindow(
    authorization: Authorization,
    now: Timestamp
  )
    requires ValidAuthorization(
               authorization
             )
    requires AuthorizationValidFrom(authorization)
             <=
             now
    requires now
             <=
             AuthorizationValidUntil(
               authorization
             )
    ensures AuthorizationIsTemporallyValidAt(
              authorization,
              now
            )
  {
    assert AuthorizationIsTemporallyValidAt(
        authorization,
        now
      );
  }


  // At validFrom exactly, Authorization remains temporally valid.
  lemma GameAuthorizationLowerBoundaryIsInclusive(
    authorization: Authorization
  )
    requires AuthorizationIsStructurallyValid(
               authorization
             )
    ensures AuthorizationIsTemporallyValidAt(
              authorization,
              AuthorizationValidFrom(
                authorization
              )
            )
  {
    KipioAccountAuthorizationProofs
      .AuthorizationIsValidAtLowerTemporalBoundary(
      authorization
    );
  }


  // At validUntil exactly, Authorization remains temporally valid.
  lemma GameAuthorizationUpperBoundaryIsInclusive(
    authorization: Authorization
  )
    requires AuthorizationIsStructurallyValid(
               authorization
             )
    ensures AuthorizationIsTemporallyValidAt(
              authorization,
              AuthorizationValidUntil(
                authorization
              )
            )
  {
    KipioAccountAuthorizationProofs
      .AuthorizationIsValidAtUpperTemporalBoundary(
      authorization
    );
  }


  // Before validFrom, the Authorization is not temporally valid.
  lemma GameAuthorizationIsInvalidBeforeWindow(
    authorization: Authorization,
    now: Timestamp
  )
    requires ValidAuthorization(
               authorization
             )
    requires now < AuthorizationValidFrom(
                     authorization
                   )
    ensures !AuthorizationIsTemporallyValidAt(
              authorization,
              now
            )
  {
    assert !AuthorizationIsTemporallyValidAt(
        authorization,
        now
      );
  }


  // After validUntil, the Authorization is not temporally valid.
  lemma GameAuthorizationIsInvalidAfterWindow(
    authorization: Authorization,
    now: Timestamp
  )
    requires ValidAuthorization(
               authorization
             )
    requires now > AuthorizationValidUntil(
                     authorization
                   )
    ensures !AuthorizationIsTemporallyValidAt(
              authorization,
              now
            )
  {
    assert !AuthorizationIsTemporallyValidAt(
        authorization,
        now
      );
  }


  // ==========================================================
  // ATTACK 3 — AUTHORIZATION ACCEPTANCE PRESERVES TIME
  // ==========================================================

  // Accepted Authorization necessarily satisfies its own
  // temporal validity boundary at evaluation time.
  lemma GameAcceptedAuthorizationRequiresTemporalValidity(
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
    requires AuthorizationCanBeAccepted(
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
    ensures AuthorizationIsTemporallyValidAt(
              authorization,
              now
            )
  {
    KipioAccountAuthorizationProofs
      .AcceptedAuthorizationIsTemporallyValid(
      authorization,
      account,
      effectiveAuthority,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      now,
      proofVerified
    );
  }


  // An Authorization cannot be accepted before validFrom.
  lemma GameAuthorizationCannotBeAcceptedBeforeValidityBegins(
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
    requires now < AuthorizationValidFrom(
                     authorization
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
    KipioAccountAuthorizationProofs
      .AuthorizationCannotBeAcceptedBeforeValidityBegins(
      authorization,
      account,
      effectiveAuthority,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      now,
      proofVerified
    );
  }


  // An Authorization cannot be accepted after validUntil.
  lemma GameAuthorizationCannotBeAcceptedAfterValidityEnds(
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
    requires now > AuthorizationValidUntil(
                     authorization
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
    KipioAccountAuthorizationProofs
      .AuthorizationCannotBeAcceptedAfterValidityEnds(
      authorization,
      account,
      effectiveAuthority,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      now,
      proofVerified
    );
  }


  // A temporally invalid Authorization cannot be accepted.
  lemma GameTemporallyInvalidAuthorizationBlocksAcceptance(
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
    KipioAccountAuthorizationProofs
      .TemporallyInvalidAuthorizationBlocksAcceptance(
      authorization,
      account,
      effectiveAuthority,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      now,
      proofVerified
    );
  }


  // ==========================================================
  // ATTACK 4 — VALID EXECUTION CONTEXT PRESERVES
  //              AUTHORIZATION TEMPORAL VALIDITY
  // ==========================================================

  // The current Account-relative ExecutionContext is downstream
  // of Authorization acceptance.
  //
  // Therefore a valid execution context inherits the temporal
  // validity of its carried Authorization at evaluation time.
  lemma GameValidExecutionContextRequiresTemporalAuthorization(
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
    ensures AuthorizationIsTemporallyValidAt(
              ExecutionContextAuthorization(context),
              ExecutionContextEvaluationTime(context)
            )
  {
    assert AuthorizationCanBeAccepted(
        ExecutionContextAuthorization(context),
        account,
        ExecutionContextEffectiveAuthority(context),
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        ExecutionContextEvaluationTime(context),
        proofVerified
      );

    assert AuthorizationIsTemporallyValidAt(
        ExecutionContextAuthorization(context),
        ExecutionContextEvaluationTime(context)
      );
  }


  // A temporally invalid Authorization therefore cannot coexist
  // with an Account-relative valid ExecutionContext.
  lemma GameTemporallyInvalidAuthorizationCannotFormValidExecutionContext(
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
      assert AuthorizationIsTemporallyValidAt(
          ExecutionContextAuthorization(context),
          ExecutionContextEvaluationTime(context)
        );

      assert false;
    }
  }


  // ==========================================================
  // ATTACK 5 — EXECUTION CONTEXT MATERIALIZATION
  // ==========================================================

  // A valid Account-relative ExecutionContext contains its concrete
  // evaluation time.
  lemma GameValidExecutionContextHasEvaluationTime(
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
    ensures ExecutionContextEvaluationTime(context)
            ==
            context.evaluationTime
  {
    KipioAccountExecutionProofs
      .ValidContextProvidesEvaluationTimeContract(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified
    );
  }


  // A valid Account-relative ExecutionContext contains the
  // structurally valid Authorization used by execution.
  lemma GameValidExecutionContextHasValidAuthorization(
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
    ensures ValidAuthorization(
              ExecutionContextAuthorization(context)
            )
  {
    KipioAccountExecutionProofs
      .ValidContextHasValidAuthorization(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified
    );
  }


  // A valid Account-relative ExecutionContext carries a valid
  // AuthorizationState snapshot.
  lemma GameValidExecutionContextHasValidStateSnapshot(
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
    KipioAccountExecutionProofs
      .ValidContextHasValidAuthorizationState(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified
    );
  }


  // A valid Account-relative ExecutionContext carries a valid
  // EffectiveAuthority.
  lemma GameValidExecutionContextHasValidEffectiveAuthority(
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
    KipioAccountExecutionProofs
      .ValidContextHasValidEffectiveAuthority(
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
  // ATTACK 6 — TEMPORALLY INVALID AUTHORIZATION CANNOT REACH
  //              EXECUTION ENGINE
  // ==========================================================

  // The execution-engine boundary is Account-relative and remains
  // downstream of valid ExecutionContext construction.
  //
  // Therefore a context carrying a temporally invalid Authorization
  // cannot legitimately enter execution.
  lemma GameTemporalAuthorizationMismatchCannotReachExecutionEngine(
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
    requires !AuthorizationIsTemporallyValidAt(
               ExecutionContextAuthorization(context),
               ExecutionContextEvaluationTime(context)
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
      assert ValidExecutionContextForAccount(
          context,
          account,
          identities,
          sourceReferences,
          sourceAuthorities,
          contributions,
          proofVerified
        );

      assert AuthorizationIsTemporallyValidAt(
          ExecutionContextAuthorization(context),
          ExecutionContextEvaluationTime(context)
        );

      assert false;
    }
  }


  // ==========================================================
  // ATTACK 7 — EXECUTION ENGINE INPUT PRESERVES THE SAME
  //              TEMPORAL BOUNDARY
  // ==========================================================

  // ExecutionEngineInputIsValid requires the same Account-relative
  // ExecutionContext validation context plus concrete verified
  // execution constraints.
  lemma GameExecutionEngineInputRequiresValidExecutionContext(
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
    assert ValidExecutionContextForAccount(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified
      );
  }


  // A temporally invalid Authorization therefore cannot produce
  // valid Execution Engine input.
  lemma GameTemporallyInvalidAuthorizationBlocksExecutionEngineInput(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints
  )
    requires !AuthorizationIsTemporallyValidAt(
               ExecutionContextAuthorization(context),
               ExecutionContextEvaluationTime(context)
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
      assert ValidExecutionContextForAccount(
          context,
          account,
          identities,
          sourceReferences,
          sourceAuthorities,
          contributions,
          proofVerified
        );

      assert AuthorizationIsTemporallyValidAt(
          ExecutionContextAuthorization(context),
          ExecutionContextEvaluationTime(context)
        );

      assert false;
    }
  }


  // ==========================================================
  // ATTACK 8 — EVALUATION TIME IS PRESERVED
  // ==========================================================

  // Crossing the execution-engine boundary requires verified
  // execution constraints. Once that boundary is legitimately
  // entered, execution semantics preserves the context's
  // evaluation time.
  lemma GameExecutionPreservesEvaluationTime(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints
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
    requires ExecutionConstraintsAreVerified(
               context,
               verifiedConstraints
             )
    ensures ExecutionEngineEvaluationTime(context)
            ==
            ExecutionContextEvaluationTime(context)
  {
    ExecutionEngineUsesContextEvaluationTime(
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


  // The execution-engine evaluation timestamp is also the concrete
  // timestamp carried by the ExecutionContext.
  lemma GameEvaluationTimeIsNotLostAcrossExecutionBoundary(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints
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
    requires ExecutionConstraintsAreVerified(
               context,
               verifiedConstraints
             )
    ensures ExecutionEngineEvaluationTime(context)
            ==
            context.evaluationTime
  {
    ExecutionEngineUsesContextEvaluationTime(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified,
      verifiedConstraints
    );

    assert ExecutionContextEvaluationTime(context)
           ==
           context.evaluationTime;
  }


  // ==========================================================
  // ATTACK 9 — TEMPORAL COMPOSITION CANNOT BE RE-OPENED
  // ==========================================================

  // Once Account-relative ExecutionContext validity has been
  // established, its carried Authorization is temporally valid at
  // exactly the evaluation time used by the execution context.
  //
  // This is the composition-level invariant connecting:
  //
  //     Authorization
  //         ->
  //     AuthorizationCanBeAccepted
  //         ->
  //     ValidExecutionContextForAccount
  //
  // without introducing any new temporal equality or datatype.
  lemma GameAuthorizationTemporalBoundaryIsPreservedByComposition(
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
    ensures AuthorizationIsTemporallyValidAt(
              ExecutionContextAuthorization(context),
              ExecutionContextEvaluationTime(context)
            )
  {
    assert AuthorizationCanBeAccepted(
        ExecutionContextAuthorization(context),
        account,
        ExecutionContextEffectiveAuthority(context),
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        ExecutionContextEvaluationTime(context),
        proofVerified
      );

    assert AuthorizationIsTemporallyValidAt(
        ExecutionContextAuthorization(context),
        ExecutionContextEvaluationTime(context)
      );
  }


  // ==========================================================
  // ATTACK 10 — COMPACT GAME TEMPORAL CONTRACT
  // ==========================================================

  // Reusable temporal contract for Authorization itself.
  //
  //     before window
  //         -> not temporally valid
  //
  //     inside window
  //         -> temporally valid
  //
  //     after window
  //         -> not temporally valid
  lemma GameAuthorizationTemporalContract(
    authorization: Authorization,
    before: Timestamp,
    inside: Timestamp,
    after: Timestamp
  )
    requires ValidAuthorization(
               authorization
             )
    requires before < AuthorizationValidFrom(
                        authorization
                      )
    requires AuthorizationValidFrom(
               authorization
             )
             <=
             inside
    requires inside
             <=
             AuthorizationValidUntil(
               authorization
             )
    requires AuthorizationValidUntil(
               authorization
             )
           < after
    ensures !AuthorizationIsTemporallyValidAt(
              authorization,
              before
            )
    ensures AuthorizationIsTemporallyValidAt(
              authorization,
              inside
            )
    ensures !AuthorizationIsTemporallyValidAt(
              authorization,
              after
            )
  {
    assert !AuthorizationIsTemporallyValidAt(
        authorization,
        before
      );

    assert AuthorizationIsTemporallyValidAt(
        authorization,
        inside
      );

    assert !AuthorizationIsTemporallyValidAt(
        authorization,
        after
      );
  }


  // ==========================================================
  // CURRENT FINDING
  // ==========================================================
  //
  // Session:
  //
  //     inside interval -> usable
  //     before interval -> not usable
  //     after interval  -> not usable
  //
  // Authorization:
  //
  //     inside interval -> temporally valid
  //     before interval -> cannot be accepted
  //     after interval  -> cannot be accepted
  //
  // Acceptance:
  //
  //     accepted Authorization
  //         -> temporally valid at evaluation time
  //
  // ExecutionContext:
  //
  //     valid Account-relative context
  //         -> accepted Authorization
  //         -> temporally valid Authorization
  //
  // Execution Engine input:
  //
  //     invalid temporal Authorization
  //         -> invalid ExecutionContext
  //         -> invalid Engine input
  //
  // Execution Engine entry:
  //
  //     invalid temporal Authorization
  //         -> cannot enter execution
  //
  // Execution Constraints:
  //
  //     concrete verifiedConstraints
  //         -> bound to the ExecutionContext constraints value
  //         -> required by the execution-engine boundary
  //
  // Evaluation time:
  //
  //     ExecutionContext evaluation time
  //         ==
  //     ExecutionEngine evaluation time
  //
  // The current GameProof temporal composition introduces no new
  // formalization debt at the execution boundary.
  //
  // The execution-engine lemmas carry `verifiedConstraints` as the
  // concrete ExecutionConstraints verification witness. This
  // preserves the existing execution precondition while keeping
  // constraint semantics outside this temporal scenario.
}

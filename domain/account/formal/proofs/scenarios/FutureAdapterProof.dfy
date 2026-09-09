// ============================================================
// KIPIO ACCOUNT DOMAIN
// PROOFS — SCENARIO: FUTURE ADAPTER
// ============================================================
//
// Adversarial scenario:
//
//     A future execution adapter receives:
//
//         - ExecutionTarget
//         - ExecutionConstraints
//         - a previously resolved EffectiveAuthority
//
//     and attempts to:
//
//         1. replace ExecutionTarget;
//         2. replace ExecutionConstraints;
//         3. inject an additional Capability into EffectiveAuthority;
//         4. cross the Execution Engine boundary with the modified
//            execution decision.
//
// ------------------------------------------------------------
//
// SECURITY BOUNDARIES
//
// The scenario distinguishes three independent boundaries:
//
//   A) ExecutionTarget integrity
//
//      ExecutionRequest binds the ExecutionTarget to the
//      Authorization semantic context.
//
//   B) EffectiveAuthority provenance
//
//      A modified EffectiveAuthority must remain derivable from the
//      legitimate authority witnesses supplied to the execution
//      boundary.
//
//   C) ExecutionConstraints verification binding
//
//      The verification witness is the concrete
//      ExecutionConstraints value itself.
//
//      Engine admission therefore requires:
//
//          verifiedConstraints
//              ==
//          ExecutionContextConstraints(context)
//
// ------------------------------------------------------------
//
// EXECUTION FLOW
//
//     Authorization
//          |
//          v
//     ExecutionRequest
//          |
//          v
//     ExecutionContext
//          |
//          +--> EffectiveAuthority
//          |
//          +--> ExecutionConstraints
//          |
//          v
//     Execution Engine
//
// The Execution Engine consumes an already validated execution
// decision together with the contextual evidence required by the
// execution boundary.
//
// ------------------------------------------------------------
//
// EXECUTION CONSTRAINT BINDING
//
// ExecutionConstraints are opaque Value Object data.
//
// This scenario does not define:
//
//   - a concrete constraint algebra;
//   - individual constraint categories;
//   - a constraint evaluator;
//   - infrastructure-specific constraint semantics.
//
// The preceding execution layer supplies:
//
//     verifiedConstraints : ExecutionConstraints
//
// The execution boundary requires that:
//
//     ExecutionConstraintsAreVerified(
//         context,
//         verifiedConstraints
//     )
//
// holds.
//
// The predicate is defined by Value Object equality:
//
//     ExecutionContextConstraints(context)
//         ==
//     verifiedConstraints
//
// Therefore a verification witness for one concrete constraint
// value cannot be reused for a different constraint value.
//
// ------------------------------------------------------------
//
// IMPORTANT EXECUTION MODEL
//
// Complete ExecutionContext validity is:
//
//     ValidExecutionContextForAccount(
//       context,
//       account,
//       identities,
//       sourceAuthorities,
//       contributions,
//       proofVerified
//     )
//
// This contract establishes the contextual authorization boundary,
// including:
//
//   - Account association;
//   - Authorization acceptance;
//   - EffectiveAuthority validity;
//   - EffectiveAuthority provenance;
//   - RequestedAuthority ⊆ EffectiveAuthority;
//   - AuthorizationState validity;
//   - Credential recognition and usability;
//   - ExecutionRequest validity.
//
// The Execution Engine boundary additionally requires the verified
// ExecutionConstraints value to match the concrete value carried by
// the ExecutionContext.
//
// ------------------------------------------------------------
//
// IMPORTANT DISTINCTIONS
//
// ExecutionConstraints do not create or expand Authority.
//
// Therefore:
//
//     ExecutionConstraints
//         !=
//     EffectiveAuthority
//
// and:
//
//     ExecutionConstraints
//         !=
//     Authorization Restrictions
//
// The security property tested here is the integrity of the
// execution decision, not authority derivation from constraints.
//
// ------------------------------------------------------------
//
// SCENARIO SCOPE
//
// This scenario does NOT:
//
//   - interpret ExecutionConstraints;
//   - calculate EffectiveAuthority;
//   - define Authorization semantics;
//   - verify cryptographic Proof;
//   - consume Replay Protection;
//   - define runtime orchestration;
//   - define adapter implementation details;
//   - define physical blockchain behavior;
//   - define the concrete environment compatibility algorithm.
//
// It verifies only that the execution boundary preserves the
// semantic invariants already established by those layers.
//
// ============================================================


include "../../foundation/Capability.dfy"
include "../../foundation/ExecutionTarget.dfy"
include "../../foundation/Identity.dfy"
include "../../foundation/Chain.dfy"

include "../../account/Account.dfy"

include "../../authorization/AuthorizationValidation.dfy"

include "../../execution/ExecutionConstraints.dfy"
include "../../execution/ExecutionRequest.dfy"
include "../../execution/ExecutionContext.dfy"
include "../../execution/ExecutionSemantics.dfy"

include "../../authority/EffectiveAuthority.dfy"

include "../../laws/ExecutionLaws.dfy"

include "../isolated/ExecutionProofs.dfy"



module KipioAccountFutureAdapterProof
{
  import opened KipioAccountCapability
  import opened KipioAccountExecutionTarget
  import opened KipioAccountIdentity
  import opened KipioAccountChain

  import opened KipioAccountAccount

  import opened KipioAccountAuthorization
  import opened KipioAccountAuthorizationValidation

  import opened KipioAccountEffectiveAuthority

  import opened KipioAccountExecutionConstraints
  import opened KipioAccountExecutionRequest
  import opened KipioAccountExecutionContext
  import opened KipioAccountExecutionSemantics

  import opened KipioAccountExecutionLaws

  import opened KipioAccountExecutionProofs



  // ==========================================================
  // FUTURE ADAPTER MODEL
  // ==========================================================

  // Adversarial construction:
  //
  //     FutureAdapter
  //          |
  //          v
  //     existing EffectiveAuthority
  //          +
  //     candidate Capability
  //          |
  //          v
  //     EffectiveAuthority'
  //
  // Target and Constraints are intentionally carried into this
  // function to model the data available to a future adapter.
  //
  // They do NOT semantically create authority.

  function FutureAdapterSuppliedAuthority(
    target: ExecutionTarget,
    constraints: ExecutionConstraints,
    candidate: Capability,
    existingAuthority: EffectiveAuthority
  ): EffectiveAuthority
  {
    existingAuthority + { candidate }
  }



  predicate FutureAdapterTreatsExecutionDataAsAuthority(
    target: ExecutionTarget,
    constraints: ExecutionConstraints,
    candidate: Capability,
    suppliedAuthority: EffectiveAuthority
  )
  {
    candidate in suppliedAuthority
  }



  // ==========================================================
  // TARGET SUBSTITUTION ATTACK
  // ==========================================================

  // A valid ExecutionRequest binds its Target to the Authorization
  // semantic context.
  //
  // Therefore replacing the Target with a different value makes the
  // request invalid.

  lemma FutureAdapterCannotSubstituteUnauthorizedTarget(
    request: ExecutionRequest,
    replacementTarget: ExecutionTarget
  )
    requires ValidExecutionRequest(request)

    requires
      replacementTarget
      !=
      AuthorizationExecutionTarget(
        ExecutionRequestAuthorization(request)
      )

    ensures !
            ValidExecutionRequest(
              ExecutionRequest(
                ExecutionRequestAction(request),
                ExecutionRequestAuthorization(request),
                replacementTarget,
                ExecutionRequestConstraints(request)
              )
            )
  {
    ValidExecutionRequestHasMatchingExecutionTarget(request);

    assert
      ExecutionRequestTarget(
        ExecutionRequest(
          ExecutionRequestAction(request),
          ExecutionRequestAuthorization(request),
          replacementTarget,
          ExecutionRequestConstraints(request)
        )
      )
      ==
      replacementTarget;

    assert
      AuthorizationExecutionTarget(
        ExecutionRequestAuthorization(request)
      )
      !=
      replacementTarget;
  }



  // Explicit boundary law reused by the scenario.

  lemma FutureAdapterTargetMustRemainAuthorizationConsistent(
    request: ExecutionRequest
  )
    requires ValidExecutionRequest(request)

    ensures
      ExecutionRequestTarget(request)
      ==
      AuthorizationExecutionTarget(
        ExecutionRequestAuthorization(request)
      )
  {
    ValidExecutionRequestHasMatchingExecutionTarget(request);
  }



  // ==========================================================
  // CONSTRAINT SUBSTITUTION
  // ==========================================================

  // The ExecutionRequest validity contract preserves Action and
  // Target consistency independently of the concrete
  // ExecutionConstraints value.
  //
  // Therefore replacing only the constraint value preserves
  // ExecutionRequest validity.

  lemma FutureAdapterConstraintReplacementPreservesRequestValidity(
    request: ExecutionRequest,
    replacementConstraints: ExecutionConstraints
  )
    requires ValidExecutionRequest(request)

    ensures
      ValidExecutionRequest(
        ExecutionRequest(
          ExecutionRequestAction(request),
          ExecutionRequestAuthorization(request),
          ExecutionRequestTarget(request),
          replacementConstraints
        )
      )
  {
    ValidExecutionRequestHasMatchingDomainAction(request);
    ValidExecutionRequestHasMatchingExecutionTarget(request);

    assert
      ExecutionRequestAction(
        ExecutionRequest(
          ExecutionRequestAction(request),
          ExecutionRequestAuthorization(request),
          ExecutionRequestTarget(request),
          replacementConstraints
        )
      )
      ==
      ExecutionRequestAction(request);

    assert
      ExecutionRequestTarget(
        ExecutionRequest(
          ExecutionRequestAction(request),
          ExecutionRequestAuthorization(request),
          ExecutionRequestTarget(request),
          replacementConstraints
        )
      )
      ==
      ExecutionRequestTarget(request);

    assert
      AuthorizationDomainAction(
        ExecutionRequestAuthorization(request)
      )
      ==
      ExecutionRequestAction(request);

    assert
      AuthorizationExecutionTarget(
        ExecutionRequestAuthorization(request)
      )
      ==
      ExecutionRequestTarget(request);
  }



  // ==========================================================
  // CONSTRAINT REPLACEMENT AT EXECUTION CONTEXT
  // ==========================================================

  function FutureAdapterContextWithReplacementConstraints(
    context: ExecutionContext,
    replacementConstraints: ExecutionConstraints
  ): ExecutionContext
  {
    ExecutionContext(
      ExecutionRequest(
        ExecutionRequestAction(
          ExecutionContextRequest(context)
        ),
        ExecutionRequestAuthorization(
          ExecutionContextRequest(context)
        ),
        ExecutionRequestTarget(
          ExecutionContextRequest(context)
        ),
        replacementConstraints
      ),
      ExecutionContextAuthorizationState(context),
      ExecutionContextEffectiveAuthority(context),
      ExecutionContextEvaluationTime(context)
    )
  }



  // The adversarial transformation changes only the concrete
  // ExecutionConstraints.
  //
  // The inequality requirement ensures that the replacement is
  // genuinely different from the original value.

  lemma FutureAdapterConstraintReplacementChangesOnlyConstraints(
    context: ExecutionContext,
    replacementConstraints: ExecutionConstraints
  )
    requires
      replacementConstraints
      !=
      ExecutionContextConstraints(context)

    ensures
      ExecutionContextConstraints(
        FutureAdapterContextWithReplacementConstraints(
          context,
          replacementConstraints
        )
      )
      ==
      replacementConstraints

    ensures
      ExecutionContextAuthorization(
        FutureAdapterContextWithReplacementConstraints(
          context,
          replacementConstraints
        )
      )
      ==
      ExecutionContextAuthorization(context)

    ensures
      ExecutionContextAuthorizationState(
        FutureAdapterContextWithReplacementConstraints(
          context,
          replacementConstraints
        )
      )
      ==
      ExecutionContextAuthorizationState(context)

    ensures
      ExecutionContextEffectiveAuthority(
        FutureAdapterContextWithReplacementConstraints(
          context,
          replacementConstraints
        )
      )
      ==
      ExecutionContextEffectiveAuthority(context)

    ensures
      ExecutionContextEvaluationTime(
        FutureAdapterContextWithReplacementConstraints(
          context,
          replacementConstraints
        )
      )
      ==
      ExecutionContextEvaluationTime(context)

    ensures
      ExecutionContextConstraints(
        FutureAdapterContextWithReplacementConstraints(
          context,
          replacementConstraints
        )
      )
      !=
      ExecutionContextConstraints(context)
  {
    assert
      ExecutionContextConstraints(
        FutureAdapterContextWithReplacementConstraints(
          context,
          replacementConstraints
        )
      )
      ==
      replacementConstraints;

    assert
      ExecutionContextAuthorization(
        FutureAdapterContextWithReplacementConstraints(
          context,
          replacementConstraints
        )
      )
      ==
      ExecutionContextAuthorization(context);

    assert
      ExecutionContextAuthorizationState(
        FutureAdapterContextWithReplacementConstraints(
          context,
          replacementConstraints
        )
      )
      ==
      ExecutionContextAuthorizationState(context);

    assert
      ExecutionContextEffectiveAuthority(
        FutureAdapterContextWithReplacementConstraints(
          context,
          replacementConstraints
        )
      )
      ==
      ExecutionContextEffectiveAuthority(context);

    assert
      ExecutionContextEvaluationTime(
        FutureAdapterContextWithReplacementConstraints(
          context,
          replacementConstraints
        )
      )
      ==
      ExecutionContextEvaluationTime(context);

    assert
      ExecutionContextConstraints(
        FutureAdapterContextWithReplacementConstraints(
          context,
          replacementConstraints
        )
      )
      !=
      ExecutionContextConstraints(context);
  }



  // ==========================================================
  // CONSTRAINT VERIFICATION BOUNDARY
  // ==========================================================

  // A valid original Engine input carries a verification witness
  // for the exact ExecutionConstraints value represented by the
  // original ExecutionContext.

  lemma FutureAdapterOriginalConstraintsRemainBoundToVerification(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints
  )
    requires
      ExecutionEngineInputIsValid(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified,
        verifiedConstraints
      )

    ensures
      ExecutionConstraintsAreVerified(
        context,
        verifiedConstraints
      )
  {
    assert
      ExecutionConstraintsAreVerified(
        context,
        verifiedConstraints
      );
  }



  // A replacement with a different concrete ExecutionConstraints
  // value cannot satisfy the same verification witness.
  lemma FutureAdapterReplacementConstraintsCannotMatchOriginalVerification(
    context: ExecutionContext,
    replacementConstraints: ExecutionConstraints,
    verifiedConstraints: ExecutionConstraints
  )
    requires
      replacementConstraints
      !=
      ExecutionContextConstraints(context)

    requires
      ExecutionContextConstraints(context)
      ==
      verifiedConstraints

    ensures
      !ExecutionConstraintsAreVerified(
        FutureAdapterContextWithReplacementConstraints(
          context,
          replacementConstraints
        ),
        verifiedConstraints
      )
  {
    assert
      ExecutionContextConstraints(
        FutureAdapterContextWithReplacementConstraints(
          context,
          replacementConstraints
        )
      )
      ==
      replacementConstraints;

    assert
      replacementConstraints
      !=
      verifiedConstraints;
  }



  // Replacing the concrete ExecutionConstraints after they have been
  // verified cannot preserve intrinsic Engine validity when the
  // original verification witness is retained.

  lemma FutureAdapterCannotReplaceConstraintsAndRetainEngineValidity(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints,
    replacementConstraints: ExecutionConstraints
  )
    requires
      ExecutionEngineInputIsValid(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified,
        verifiedConstraints
      )

    requires
      replacementConstraints
      !=
      ExecutionContextConstraints(context)

    ensures
      ExecutionContextConstraints(
        FutureAdapterContextWithReplacementConstraints(
          context,
          replacementConstraints
        )
      )
      !=
      ExecutionContextConstraints(context)

    ensures
      !ExecutionEngineInputIsValid(
        FutureAdapterContextWithReplacementConstraints(
          context,
          replacementConstraints
        ),
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified,
        verifiedConstraints
      )
  {
    // The original Engine input binds the verification witness to
    // the original ExecutionConstraints value.
    FutureAdapterOriginalConstraintsRemainBoundToVerification(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified,
      verifiedConstraints
    );

    assert
      ExecutionContextConstraints(context)
      ==
      verifiedConstraints;

    // The replacement context changes the concrete constraints while
    // preserving the remaining execution-decision values.
    FutureAdapterConstraintReplacementChangesOnlyConstraints(
      context,
      replacementConstraints
    );

    assert
      ExecutionContextConstraints(
        FutureAdapterContextWithReplacementConstraints(
          context,
          replacementConstraints
        )
      )
      ==
      replacementConstraints;

    assert
      replacementConstraints
      !=
      verifiedConstraints;

    // Therefore the original verification witness cannot verify the
    // replacement context.
    FutureAdapterReplacementConstraintsCannotMatchOriginalVerification(
      context,
      replacementConstraints,
      verifiedConstraints
    );

    assert
      !ExecutionConstraintsAreVerified(
        FutureAdapterContextWithReplacementConstraints(
          context,
          replacementConstraints
        ),
        verifiedConstraints
      );

    // Engine validity requires the same verification predicate.
    if ExecutionEngineInputIsValid(
        FutureAdapterContextWithReplacementConstraints(
          context,
          replacementConstraints
        ),
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified,
        verifiedConstraints
      )
    {
      assert
        ExecutionConstraintsAreVerified(
          FutureAdapterContextWithReplacementConstraints(
            context,
            replacementConstraints
          ),
          verifiedConstraints
        );
    }
  }



  // ==========================================================
  // CONSTRAINT ATTACK AND ENVIRONMENT DELIVERY
  // ==========================================================

  // Environment compatibility is an additional delivery condition.
  // It cannot make a context with mismatched verification evidence
  // intrinsically valid.

  lemma FutureAdapterCannotReplaceConstraintsAndRetainEngineEntry(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints,
    environment: ExecutionEnvironment,
    compatibilityRelation: set<(Chain, ExecutionEnvironment)>,
    replacementConstraints: ExecutionConstraints
  )
    requires
      ExecutionContextCanEnterExecutionEngine(
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

    requires
      replacementConstraints
      !=
      ExecutionContextConstraints(context)

    ensures
      ExecutionContextConstraints(
        FutureAdapterContextWithReplacementConstraints(
          context,
          replacementConstraints
        )
      )
      !=
      ExecutionContextConstraints(context)

    ensures
      !ExecutionContextCanEnterExecutionEngine(
        FutureAdapterContextWithReplacementConstraints(
          context,
          replacementConstraints
        ),
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
    assert
      ExecutionEngineInputIsValid(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified,
        verifiedConstraints
      );

    FutureAdapterCannotReplaceConstraintsAndRetainEngineValidity(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified,
      verifiedConstraints,
      replacementConstraints
    );

    assert
      !ExecutionEngineInputIsValid(
        FutureAdapterContextWithReplacementConstraints(
          context,
          replacementConstraints
        ),
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified,
        verifiedConstraints
      );

    if ExecutionContextCanEnterExecutionEngine(
        FutureAdapterContextWithReplacementConstraints(
          context,
          replacementConstraints
        ),
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
      assert
        ExecutionEngineInputIsValid(
          FutureAdapterContextWithReplacementConstraints(
            context,
            replacementConstraints
          ),
          account,
          identities,
          sourceReferences,
          sourceAuthorities,
          contributions,
          proofVerified,
          verifiedConstraints
        );
    }
  }



  // ==========================================================
  // MALICIOUS AUTHORITY INJECTION
  // ==========================================================

  function FutureAdapterContextWithInjectedAuthority(
    context: ExecutionContext,
    candidate: Capability
  ): ExecutionContext
  {
    ExecutionContext(
      ExecutionContextRequest(context),
      ExecutionContextAuthorizationState(context),
      FutureAdapterSuppliedAuthority(
        ExecutionRequestTarget(
          ExecutionContextRequest(context)
        ),
        ExecutionRequestConstraints(
          ExecutionContextRequest(context)
        ),
        candidate,
        ExecutionContextEffectiveAuthority(context)
      ),
      ExecutionContextEvaluationTime(context)
    )
  }



  // The injected context preserves the underlying request.

  lemma FutureAdapterInjectionPreservesRequest(
    context: ExecutionContext,
    candidate: Capability
  )
    ensures
      ExecutionContextRequest(
        FutureAdapterContextWithInjectedAuthority(
          context,
          candidate
        )
      )
      ==
      ExecutionContextRequest(context)
  {
  }



  // The injected context preserves the target.

  lemma FutureAdapterInjectionPreservesTarget(
    context: ExecutionContext,
    candidate: Capability
  )
    ensures
      ExecutionRequestTarget(
        ExecutionContextRequest(
          FutureAdapterContextWithInjectedAuthority(
            context,
            candidate
          )
        )
      )
      ==
      ExecutionRequestTarget(
        ExecutionContextRequest(context)
      )
  {
  }



  // The injected context preserves the constraints.

  lemma FutureAdapterInjectionPreservesConstraints(
    context: ExecutionContext,
    candidate: Capability
  )
    ensures
      ExecutionRequestConstraints(
        ExecutionContextRequest(
          FutureAdapterContextWithInjectedAuthority(
            context,
            candidate
          )
        )
      )
      ==
      ExecutionRequestConstraints(
        ExecutionContextRequest(context)
      )
  {
  }



  // The adapter-supplied EffectiveAuthority actually contains the
  // candidate.

  lemma FutureAdapterInjectionAddsCandidateAuthority(
    context: ExecutionContext,
    candidate: Capability
  )
    ensures
      candidate
      in
        ExecutionContextEffectiveAuthority(
          FutureAdapterContextWithInjectedAuthority(
            context,
            candidate
          )
        )
  {
  }



  // ==========================================================
  // PROVENANCE BLOCKS INJECTION
  // ==========================================================

  // A candidate outside the original EffectiveAuthority cannot be
  // part of the same provenance-backed EffectiveAuthority relation
  // when the original source/contribution witnesses remain unchanged.
  //
  // Original:
  //
  //     EA
  //       =
  //     authority derived from legitimate sources
  //
  // Injected:
  //
  //     EA'
  //       =
  //     EA ∪ {candidate}
  //
  // If:
  //
  //     candidate ∉ EA
  //
  // then:
  //
  //     candidate ∈ EA'
  //
  // but:
  //
  //     candidate ∉ legitimate contributions
  //
  // Therefore EA' cannot satisfy the same provenance relation.

  lemma FutureAdapterInjectedAuthorityCannotPreserveProvenance(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    candidate: Capability
  )
    requires
      ValidExecutionContextForAccount(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified
      )

    requires ValidCapability(candidate)

    requires
      candidate
      !in
      ExecutionContextEffectiveAuthority(context)

    ensures
      !EffectiveAuthorityDerivedFromSources(
        ExecutionContextEffectiveAuthority(
          FutureAdapterContextWithInjectedAuthority(
            context,
            candidate
          )
        ),
        sourceAuthorities,
        contributions
      )
  {
    assert
      EffectiveAuthorityDerivedFromSources(
        ExecutionContextEffectiveAuthority(context),
        sourceAuthorities,
        contributions
      );

    if EffectiveAuthorityDerivedFromSources(
        ExecutionContextEffectiveAuthority(
          FutureAdapterContextWithInjectedAuthority(
            context,
            candidate
          )
        ),
        sourceAuthorities,
        contributions
      )
    {
      assert
        exists i : int ::
          0 <= i < |contributions|
          &&
          candidate in contributions[i];

      var i : int :|
        0 <= i < |contributions|
        &&
        candidate in contributions[i];

      assert candidate in contributions[i];

      assert
        candidate
        in
          ExecutionContextEffectiveAuthority(context);
    }
  }



  // Therefore the injected context cannot satisfy the complete
  // Account-level ExecutionContext contract when the provenance
  // witnesses are kept unchanged.

  lemma FutureAdapterInjectedContextCannotBeValidExecutionContextForAccount(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    candidate: Capability
  )
    requires
      ValidExecutionContextForAccount(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified
      )

    requires ValidCapability(candidate)

    requires
      candidate
      !in
      ExecutionContextEffectiveAuthority(context)

    ensures
      !ValidExecutionContextForAccount(
        FutureAdapterContextWithInjectedAuthority(
          context,
          candidate
        ),
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified
      )
  {
    FutureAdapterInjectedAuthorityCannotPreserveProvenance(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified,
      candidate
    );

    if ValidExecutionContextForAccount(
        FutureAdapterContextWithInjectedAuthority(
          context,
          candidate
        ),
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified
      )
    {
      assert
        EffectiveAuthorityDerivedFromSources(
          ExecutionContextEffectiveAuthority(
            FutureAdapterContextWithInjectedAuthority(
              context,
              candidate
            )
          ),
          sourceAuthorities,
          contributions
        );
    }
  }



  // ==========================================================
  // AUTHORITY INJECTION CANNOT CROSS ENGINE BOUNDARY
  // ==========================================================

  lemma FutureAdapterInjectedContextCannotEnterExecutionEngine(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    candidate: Capability,
    verifiedConstraints: ExecutionConstraints,
    environment: ExecutionEnvironment,
    compatibilityRelation: set<(Chain, ExecutionEnvironment)>
  )
    requires
      ValidExecutionContextForAccount(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified
      )

    requires ValidCapability(candidate)

    requires
      candidate
      !in
      ExecutionContextEffectiveAuthority(context)

    ensures
      !ExecutionContextCanEnterExecutionEngine(
        FutureAdapterContextWithInjectedAuthority(
          context,
          candidate
        ),
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
    FutureAdapterInjectedContextCannotBeValidExecutionContextForAccount(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified,
      candidate
    );

    if ExecutionContextCanEnterExecutionEngine(
        FutureAdapterContextWithInjectedAuthority(
          context,
          candidate
        ),
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
      assert
        ValidExecutionContextForAccount(
          FutureAdapterContextWithInjectedAuthority(
            context,
            candidate
          ),
          account,
          identities,
          sourceReferences,
          sourceAuthorities,
          contributions,
          proofVerified
        );
    }
  }



  // ==========================================================
  // AUTHORITY BOUNDARY REMAINS CLOSED
  // ==========================================================

  // A valid execution context satisfies the original
  // RequestedAuthority ⊆ EffectiveAuthority boundary.

  lemma FutureAdapterExecutionPreservesAuthorityBoundary(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool
  )
    requires
      ValidExecutionContextForAccount(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified
      )

    ensures
      RequestedAuthorityWithinEffectiveAuthority(
        ExecutionContextAuthorization(context),
        ExecutionContextEffectiveAuthority(context)
      )
  {
    ValidContextPreservesAuthorityBoundary(
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
  // EXECUTION SCENARIO CONTRACT
  // ==========================================================

  // ExecutionTarget integrity:
  //
  // A replacement Target must remain equal to the Target represented
  // by Authorization.

  // EffectiveAuthority integrity:
  //
  // A modified EffectiveAuthority must remain derivable from the
  // legitimate source/contribution witnesses.

  // ExecutionConstraints integrity:
  //
  // The verification witness is the concrete ExecutionConstraints
  // value itself. A replacement constraint value therefore requires
  // a matching verification witness before Engine admission.

  // Environment delivery:
  //
  // Chain / Environment compatibility remains a separate delivery
  // condition and does not alter intrinsic Engine validity.
}

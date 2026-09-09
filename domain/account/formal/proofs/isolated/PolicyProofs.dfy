// ============================================================
// KIPIO ACCOUNT DOMAIN
// PROOFS — POLICY
// ============================================================
//
// Isolated reusable proof facade for the Policy layer.
//
// This module exposes reusable formal contracts over:
//
//   Policy
//   PolicyEffect
//   PolicyConsumption
//   AuthorizationStateTransition
//
// The facade composes the authoritative semantics already defined
// by those modules. It does NOT introduce an alternative Policy
// model.
//
// ------------------------------------------------------------
//
// FACADE PRINCIPLE
//
// This file:
//
//   - reuses existing semantic contracts;
//   - composes them into E2E-oriented proof contracts;
//   - preserves Policy ordering;
//   - preserves complete PolicyConsumption semantics;
//   - exposes Policy / PolicyEffect structural validity;
//   - exposes the boundary between PolicyConsumption and the
//     AuthorizationState transition semantics;
//   - exposes atomicity and determinism guarantees already defined
//     by AuthorizationStateTransition.
//
// This file does NOT:
//
//   - define a second Policy algebra;
//   - define a second PolicyConsumption representation;
//   - redefine PolicyEffect semantics;
//   - calculate Effective Authority;
//   - validate Authorization;
//   - verify Proof;
//   - execute Domain Actions;
//   - define blockchain behavior.
//
// ------------------------------------------------------------
//
// CURRENT POLICY FLOW
//
//     PolicyEffect
//         |
//         v
//     Policy
//         |
//         v
//     PolicyConsumption
//         |
//         v
//     AuthorizationStateTransition
//         |
//         v
//     Account
//
// Policy remains the single source of truth for the ordered
// PolicyEffect sequence.
//
// PolicyConsumption remains the complete semantic unit presented
// for consumption.
//
// AuthorizationStateTransition defines how that PolicyConsumption
// is translated into Account state transitions.
//
// ------------------------------------------------------------
//
// D2 — POLICY
//
//     Policy = ordered seq<PolicyEffect>
//
// Order is semantically meaningful.
//
// Therefore:
//
//     [A, B]
//
// and:
//
//     [B, A]
//
// are not interchangeable merely because they contain the same
// Effects.
//
// ------------------------------------------------------------
//
// D2 — POLICY CONSUMPTION
//
// PolicyConsumption contains exactly one Policy value.
//
// It does not store an independent Effect sequence.
//
// Therefore:
//
//     ConsumptionPolicyEffects(consumption)
//         =
//     PolicyEffects(ConsumptionPolicy(consumption))
//
// The complete Policy remains the semantic source of truth.
//
// ------------------------------------------------------------
//
// D2 — STATE TRANSITION
//
// The current DDD already contains:
//
//     PolicyEffectTransitionExists
//     PolicyPrefixTransitionExists
//     PolicyTransitionExists
//
// in AuthorizationStateTransition.dfy.
//
// The current transition semantics establish:
//
//   - applicability;
//   - structural consistency;
//   - contradiction detection;
//   - complete ordered application;
//   - Account validity preservation;
//   - Account identity preservation;
//   - rejection atomicity;
//   - successful-result determinism;
//   - global transition determinism.
//
// This facade reuses those contracts. It does not redefine them.
//
// ------------------------------------------------------------
//
// IMPORTANT BOUNDARY
//
// Policy validity is structural.
//
// Policy applicability and Policy contradiction semantics belong
// to AuthorizationStateTransition.
//
// PolicyConsumption remains a Value Object and does not itself
// mutate Account state.
//
// The semantic state transition is:
//
//     PolicyTransitionExists(
//       account,
//       consumption,
//       result
//     )
//
// ------------------------------------------------------------
//
// NON-SCOPE
//
// This facade does NOT define:
//
//   - Policy approval or governance;
//   - cryptographic verification;
//   - authorization validation;
//   - Effective Authority calculation;
//   - replay/idempotence mechanics;
//   - blockchain transaction behavior;
//   - concrete runtime orchestration.
//
// Those remain outside the Policy bounded context facade.
//
// ============================================================

include "../../policy/Policy.dfy"
include "../../policy/PolicyEffect.dfy"
include "../../policy/PolicyConsumption.dfy"
include "../../policy/AuthorizationStateTransition.dfy"

include "../../account/Account.dfy"
include "../../account/AccountTransitions.dfy"

include "../../authority/AuthorizationState.dfy"

include "../../foundation/DomainPrimitives.dfy"
include "../../foundation/Capability.dfy"
include "../../foundation/Scope.dfy"
include "../../foundation/Restriction.dfy"


module KipioAccountPolicyProofs
{
  import opened KipioAccountPolicy
  import opened KipioAccountPolicyEffect
  import opened KipioAccountPolicyConsumption
  import opened KipioAccountAuthorizationState
  import opened KipioAccountAuthorizationStateTransition

  import opened KipioAccountAccount
  import opened KipioAccountAccountTransitions

  import opened KipioAccountDomainPrimitives
  import opened KipioAccountCapability
  import opened KipioAccountScope
  import opened KipioAccountRestriction


  // ==========================================================
  // POLICY VALIDITY
  // ==========================================================

  // A valid Policy contains only structurally valid Effects.
  lemma ValidPolicyContainsOnlyValidEffects(
    policy: Policy,
    effect: PolicyEffect
  )
    requires ValidPolicy(policy)
    requires PolicyContainsEffect(
               policy,
               effect
             )
    ensures ValidPolicyEffect(effect)
  {
    ValidPolicyContainsValidEffect(
      policy,
      effect
    );
  }


  // An Effect at a valid position in a valid Policy is structurally
  // valid.
  lemma ValidPolicyEffectAtPosition(
    policy: Policy,
    index: nat
  )
    requires ValidPolicy(policy)
    requires index < PolicyEffectCount(policy)
    ensures ValidPolicyEffect(
              PolicyEffects(policy)[index]
            )
  {
    ValidPolicyEffectAt(
      policy,
      index
    );
  }


  // Empty Policy is structurally valid.
  lemma EmptyPolicyRemainsValid()
    ensures ValidPolicy(
              Policy([])
            )
  {
    EmptyPolicyIsValid();
  }


  // An empty Policy contains zero Effects.
  lemma EmptyPolicyContainsNoEffects(
    policy: Policy
  )
    requires PolicyIsEmpty(policy)
    ensures PolicyEffectCount(policy) == 0
  {
    EmptyPolicyHasNoPolicyEffects(
      policy
    );
  }


  // A valid Policy is structurally valid even when empty.
  lemma ValidPolicyAllowsEmptyPolicy(
    policy: Policy
  )
    requires PolicyIsEmpty(policy)
    ensures ValidPolicy(policy)
  {
    assert policy == Policy([]);
    assert ValidPolicy(policy);
  }


  // ==========================================================
  // POLICY VALUE OBJECT SEMANTICS
  // ==========================================================

  // Equal Policies expose equal ordered Effect sequences.
  lemma EqualPoliciesHaveEqualEffectSequences(
    left: Policy,
    right: Policy
  )
    requires left == right
    ensures PolicyEffects(left)
         == PolicyEffects(right)
  {
    EqualPoliciesHaveEqualEffects(
      left,
      right
    );
  }


  // Equal ordered Effect sequences identify the same Policy value.
  lemma EqualEffectSequencesProduceEqualPolicies(
    left: Policy,
    right: Policy
  )
    requires PolicyEffects(left)
          == PolicyEffects(right)
    ensures left == right
  {
    PoliciesWithSameEffectsAreEqual(
      left,
      right
    );
  }


  // Equal Policies preserve Effect count.
  lemma EqualPoliciesHaveEqualEffectCounts(
    left: Policy,
    right: Policy
  )
    requires left == right
    ensures PolicyEffectCount(left)
         == PolicyEffectCount(right)
  {
    EqualPoliciesHaveEqualEffectCount(
      left,
      right
    );
  }


  // A Policy has no independent identity beyond its semantic
  // ordered Effect sequence.
  lemma PolicyHasNoIndependentIdentityInProofFacade(
    policy: Policy
  )
    ensures SamePolicy(policy, policy)
  {
    PolicyHasNoIndependentIdentity(
      policy
    );
  }


  // Distinct Effects remain distinct under reversal of a
  // two-Effect Policy.
  lemma ReorderingDistinctPolicyEffectsChangesValue(
    first: PolicyEffect,
    second: PolicyEffect
  )
    requires first != second
    ensures Policy(
              [first, second]
            )
            !=
            Policy(
              [second, first]
            )
  {
    ReorderingDistinctEffectsChangesPolicyValue(
      first,
      second
    );
  }


  // ==========================================================
  // POLICY ORDER / MEMBERSHIP
  // ==========================================================

  // A Policy Effect contained by a Policy has a concrete sequence
  // position.
  lemma PolicyEffectHasConcretePosition(
    policy: Policy,
    effect: PolicyEffect
  )
    requires PolicyContainsEffect(
               policy,
               effect
             )
    ensures exists index : nat ::
              index < PolicyEffectCount(policy)
              &&
              PolicyEffects(policy)[index]
              == effect
  {
    PolicyCannotExposeUnrepresentedEffect(
      policy,
      effect
    );
  }


  // The Effect at a valid Policy position is exactly the Effect
  // stored at that sequence position.
  lemma PolicyPositionIsSemanticallyStable(
    policy: Policy,
    index: nat
  )
    requires index < PolicyEffectCount(policy)
    ensures PolicyEffects(policy)[index]
         == policy.effects[index]
  {
    PolicyPreservesEffectOrder(
      policy,
      index
    );
  }


  // Membership is a query over the ordered Policy sequence and does
  // not replace that sequence with an unordered set.
  lemma PolicyMembershipPreservesSequenceSemantics(
    policy: Policy,
    effect: PolicyEffect
  )
    requires PolicyContainsEffect(
               policy,
               effect
             )
    ensures exists index : nat ::
              index < PolicyEffectCount(policy)
              &&
              PolicyEffects(policy)[index]
              == effect
  {
    PolicyEffectHasConcretePosition(
      policy,
      effect
    );
  }


  // ==========================================================
  // POLICY EFFECT SEMANTICS
  // ==========================================================

  // Every valid Policy Effect satisfies its complete payload-validity
  // boundary.
  lemma ValidPolicyEffectHasValidPayloadBoundary(
    effect: PolicyEffect
  )
    requires ValidPolicyEffect(effect)
    ensures match effect
            case RevokeCredential(credentialId) =>
              ValidId(credentialId)

            case RevokeSession(sessionId) =>
              ValidId(sessionId)

            case RevokeDelegation(delegationId) =>
              ValidId(delegationId)

            case DisableCapability(capability, scope) =>
              ValidCapability(capability)
              && ValidOptionalPolicyScope(scope)

            case EnableCapability(capability, scope) =>
              ValidCapability(capability)
              && ValidOptionalPolicyScope(scope)

            case ModifyRestriction(capability, scope, restriction) =>
              ValidCapability(capability)
              && ValidOptionalPolicyScope(scope)
              && ValidRestriction(restriction)
  {
    ValidPolicyEffectHasValidPayload(
      effect
    );
  }


  // A valid OptionalPolicyScope contains either no Scope or a valid
  // Scope.
  lemma ValidPolicyEffectScopeBoundary(
    scope: OptionalPolicyScope
  )
    requires ValidOptionalPolicyScope(scope)
    ensures match scope
            case NoScope => true
            case Scoped(value) => ValidScope(value)
  {
    ValidOptionalPolicyScopeContainsValidScope(
      scope
    );
  }


  // DisableCapability and EnableCapability remain distinct Effect
  // kinds even when their payload is identical.
  lemma DisableAndEnableRemainDistinct(
    capability: Capability,
    scope: OptionalPolicyScope
  )
    ensures DisableCapability(capability, scope)
         != EnableCapability(capability, scope)
  {
    DisableAndEnableAreDifferentEffectKinds(
      capability,
      scope
    );
  }


  // A PolicyEffect has no independent identity beyond its semantic
  // constructor and payload.
  lemma PolicyEffectHasNoIndependentIdentityInProofFacade(
    effect: PolicyEffect
  )
    ensures SamePolicyEffect(effect, effect)
  {
    PolicyEffectHasNoIndependentIdentity(
      effect
    );
  }


  // ==========================================================
  // POLICY CONSUMPTION
  // ==========================================================

  // A PolicyConsumption carries exactly one Policy value.
  lemma ConsumptionPreservesPolicy(
    consumption: PolicyConsumption
  )
    ensures ConsumptionPolicy(consumption)
         == consumption.policy
  {
    assert ConsumptionPolicy(consumption)
        == consumption.policy;
  }


  // A valid PolicyConsumption carries a valid Policy.
  lemma ValidConsumptionContainsValidPolicy(
    consumption: PolicyConsumption
  )
    requires ValidPolicyConsumption(consumption)
    ensures ValidPolicy(
              ConsumptionPolicy(consumption)
            )
  {
    assert ValidPolicyConsumption(consumption);
    assert ValidPolicy(
        ConsumptionPolicy(consumption)
      );
  }


  // Every Effect represented by a valid PolicyConsumption is
  // structurally valid.
  lemma ValidConsumptionContainsOnlyValidEffects(
    consumption: PolicyConsumption,
    effect: PolicyEffect
  )
    requires ValidPolicyConsumption(consumption)
    requires ConsumptionContainsEffect(
               consumption,
               effect
             )
    ensures ValidPolicyEffect(effect)
  {
    ValidConsumptionContainsValidEffect(
      consumption,
      effect
    );
  }


  // Every Effect at a valid position in a valid PolicyConsumption
  // is structurally valid.
  lemma ValidConsumptionEffectAtPosition(
    consumption: PolicyConsumption,
    index: nat
  )
    requires ValidPolicyConsumption(consumption)
    requires index < ConsumptionEffectCount(consumption)
    ensures ValidPolicyEffect(
              ConsumptionEffectAt(
                consumption,
                index
              )
            )
  {
    ValidConsumptionEffectAt(
      consumption,
      index
    );
  }


  // ==========================================================
  // POLICY → CONSUMPTION PRESERVATION
  // ==========================================================

  // PolicyConsumption exposes exactly the ordered Effects of the
  // Policy it carries.
  lemma ConsumptionPreservesOrderedEffects(
    consumption: PolicyConsumption
  )
    ensures ConsumptionPolicyEffects(consumption)
         == PolicyEffects(
              ConsumptionPolicy(consumption)
            )
  {
    ConsumptionRepresentsCompletePolicy(
      consumption
    );
  }


  // Consumption preserves the complete Effect count of the
  // underlying Policy.
  lemma ConsumptionPreservesEffectCount(
    consumption: PolicyConsumption
  )
    ensures ConsumptionEffectCount(consumption)
         == PolicyEffectCount(
              ConsumptionPolicy(consumption)
            )
  {
    assert ConsumptionEffectCount(consumption)
        == |ConsumptionPolicyEffects(consumption)|;

    assert ConsumptionPolicyEffects(consumption)
        == PolicyEffects(ConsumptionPolicy(consumption));

    assert PolicyEffectCount(
        ConsumptionPolicy(consumption)
      )
        == |PolicyEffects(
             ConsumptionPolicy(consumption)
           )|;

    assert ConsumptionEffectCount(consumption)
        == PolicyEffectCount(
             ConsumptionPolicy(consumption)
           );
  }


  // A consumed Effect is represented by some concrete position in
  // the underlying Policy.
  lemma ConsumedEffectHasPolicyPosition(
    consumption: PolicyConsumption,
    effect: PolicyEffect
  )
    requires ConsumptionContainsEffect(
               consumption,
               effect
             )
    ensures exists index : nat ::
              index < PolicyEffectCount(
                ConsumptionPolicy(consumption)
              )
              &&
              PolicyEffects(
                ConsumptionPolicy(consumption)
              )[index]
              == effect
  {
    assert ConsumptionContainsEffect(
        consumption,
        effect
      );

    assert PolicyContainsEffect(
        ConsumptionPolicy(consumption),
        effect
      );

    PolicyCannotExposeUnrepresentedEffect(
      ConsumptionPolicy(consumption),
      effect
    );
  }


  // Consumption preserves the exact Effect at a given position.
  lemma ConsumptionPositionPreservesPolicyOrder(
    consumption: PolicyConsumption,
    index: nat
  )
    requires index < ConsumptionEffectCount(consumption)
    ensures ConsumptionEffectAt(
              consumption,
              index
            )
            ==
            PolicyEffects(
              ConsumptionPolicy(consumption)
            )[index]
  {
    assert ConsumptionEffectAt(
        consumption,
        index
      )
           ==
           ConsumptionPolicyEffects(consumption)[index];

    assert ConsumptionPolicyEffects(consumption)
           ==
           PolicyEffects(
             ConsumptionPolicy(consumption)
           );

    assert ConsumptionEffectAt(
        consumption,
        index
      )
           ==
           PolicyEffects(
             ConsumptionPolicy(consumption)
           )[index];
  }


  // Consumption membership is exactly the membership of the
  // underlying Policy.
  lemma ConsumptionMembershipMatchesPolicyMembership(
    consumption: PolicyConsumption,
    effect: PolicyEffect
  )
    ensures ConsumptionContainsEffect(
              consumption,
              effect
            )
            <==>
            PolicyContainsEffect(
              ConsumptionPolicy(consumption),
              effect
            )
  {
    ConsumptionContainsEffectIffPolicyEffectMember(
      consumption,
      effect
    );
  }


  // ==========================================================
  // COMPLETE CONSUMPTION BOUNDARY
  // ==========================================================

  // PolicyConsumption represents the complete Policy value.
  lemma ConsumptionIsCompletePolicyValue(
    consumption: PolicyConsumption
  )
    ensures ConsumptionPolicy(consumption)
         == consumption.policy
    ensures ConsumptionPolicyEffects(consumption)
         == PolicyEffects(consumption.policy)
  {
    ConsumptionRepresentsCompletePolicy(
      consumption
    );

    assert ConsumptionPolicy(consumption)
        == consumption.policy;

    assert ConsumptionPolicyEffects(consumption)
        == PolicyEffects(
             ConsumptionPolicy(consumption)
           );

    assert ConsumptionPolicy(consumption)
        == consumption.policy;

    assert ConsumptionPolicyEffects(consumption)
        == PolicyEffects(consumption.policy);
  }


  // A PolicyConsumption cannot expose an Effect that is absent
  // from its underlying Policy.
  lemma ConsumptionCannotInventEffect(
    consumption: PolicyConsumption,
    effect: PolicyEffect
  )
    requires ConsumptionContainsEffect(
               consumption,
               effect
             )
    ensures PolicyContainsEffect(
              ConsumptionPolicy(consumption),
              effect
            )
  {
    assert ConsumptionContainsEffect(
        consumption,
        effect
      );

    assert PolicyContainsEffect(
        ConsumptionPolicy(consumption),
        effect
      );
  }


  // A valid PolicyConsumption provides the complete structural
  // Policy boundary required before state-transition evaluation.
  lemma ValidPolicyConsumptionProvidesStructuralContract(
    consumption: PolicyConsumption
  )
    requires ValidPolicyConsumption(consumption)
    ensures ValidPolicy(
              ConsumptionPolicy(consumption)
            )
    ensures ConsumptionPolicyEffects(consumption)
         == PolicyEffects(
              ConsumptionPolicy(consumption)
            )
    ensures ConsumptionEffectCount(consumption)
         == PolicyEffectCount(
              ConsumptionPolicy(consumption)
            )
  {
    ValidConsumptionContainsValidPolicy(
      consumption
    );

    ConsumptionPreservesOrderedEffects(
      consumption
    );

    ConsumptionPreservesEffectCount(
      consumption
    );
  }


  // ==========================================================
  // EMPTY POLICY / CONSUMPTION
  // ==========================================================

  // A PolicyConsumption constructed from an empty Policy contains
  // zero Effects.
  lemma EmptyPolicyRemainsEmptyInConsumption(
    policy: Policy
  )
    requires PolicyIsEmpty(policy)
    ensures ConsumptionEffectCount(
              PolicyConsumption(policy)
            )
         == 0
  {
    assert ConsumptionEffectCount(
        PolicyConsumption(policy)
      )
           ==
           |ConsumptionPolicyEffects(
             PolicyConsumption(policy)
           )|;

    assert ConsumptionPolicy(
        PolicyConsumption(policy)
      )
           ==
           policy;

    assert ConsumptionPolicyEffects(
        PolicyConsumption(policy)
      )
           ==
           PolicyEffects(policy);

    assert |PolicyEffects(policy)| == 0;

    assert ConsumptionEffectCount(
        PolicyConsumption(policy)
      )
        == 0;
  }


  // An empty PolicyConsumption contains no Policy Effect.
  lemma EmptyPolicyConsumptionContainsNoEffect(
    policy: Policy
  )
    requires PolicyIsEmpty(policy)
    ensures forall effect ::
              !ConsumptionContainsEffect(
                PolicyConsumption(policy),
                effect
              )
  {
    assert PolicyEffects(policy) == [];

    forall effect
      ensures !ConsumptionContainsEffect(
                PolicyConsumption(policy),
                effect
              )
    {
      assert !PolicyContainsEffect(
          policy,
          effect
        );

      assert !ConsumptionContainsEffect(
          PolicyConsumption(policy),
          effect
        );
    }
  }


  // ==========================================================
  // AUTHORIZATION STATE STRUCTURAL BOUNDARY
  // ==========================================================

  // A Policy Effect recognized as applicable in a valid
  // AuthorizationState is structurally valid.
  lemma RecognizedEffectInValidStateIsValid(
    state: AuthorizationState,
    effect: PolicyEffect
  )
    requires ValidAuthorizationState(state)
    requires PolicyEffectIsApplicable(
               state,
               effect
             )
    ensures ValidPolicyEffect(effect)
  {
    assert PolicyEffectIsConsistent(effect);
    assert ValidPolicyEffect(effect);
  }


  // A PolicyConsumption itself does not change AuthorizationState.
  //
  // State mutation is represented only by PolicyTransitionExists.
  lemma ValidConsumptionStopsBeforeStateMutation(
    consumption: PolicyConsumption
  )
    requires ValidPolicyConsumption(consumption)
    ensures ValidPolicy(
              ConsumptionPolicy(consumption)
            )
  {
    ValidConsumptionContainsValidPolicy(
      consumption
    );
  }


  // ==========================================================
  // POLICY TRANSITION — APPLICABILITY / CONSISTENCY
  // ==========================================================

  // The current transition semantics define the applicability and
  // consistency gate for a complete PolicyConsumption.
  lemma PolicyConsumptionTransitionGate(
    account: Account,
    consumption: PolicyConsumption
  )
    ensures
      PolicyIsApplicableAndConsistent(
        account,
        consumption
      )
      ==
      PolicyIsApplicableAndConsistent(
        account,
        consumption
      )
  {
  }


  // A complete Policy transition is represented by the complete
  // ordered Policy Effect sequence.
  lemma SuccessfulPolicyTransitionIsComplete(
    before: Account,
    consumption: PolicyConsumption,
    after: Account
  )
    requires
      PolicyIsApplicableAndConsistent(
        before,
        consumption
      )
    requires
      PolicyTransitionExists(
        before,
        consumption,
        after
      )
    ensures
      PolicyPrefixTransitionExists(
        before,
        ConsumptionPolicyEffects(consumption),
        after
      )
  {
    SuccessfulPolicyTransitionIsCompleteOrderedTransition(
      before,
      consumption,
      after
    );
  }


  // ==========================================================
  // POLICY TRANSITION — REJECTION / ATOMICITY
  // ==========================================================

  // A rejected Policy leaves the Account unchanged.
  lemma RejectedPolicyPreservesAccount(
    account: Account,
    consumption: PolicyConsumption
  )
    requires ValidAccount(account)
    requires ValidPolicyConsumption(consumption)
    requires !PolicyIsApplicableAndConsistent(
               account,
               consumption
             )
    ensures
      PolicyTransitionExists(
        account,
        consumption,
        account
      )
  {
    RejectedPolicyLeavesAccountUnchanged(
      account,
      consumption
    );
  }


  // A rejected Policy has exactly one semantic result.
  lemma RejectedPolicyHasUniqueAccountResult(
    account: Account,
    consumption: PolicyConsumption,
    result: Account
  )
    requires
      !PolicyIsApplicableAndConsistent(
        account,
        consumption
      )
    requires
      PolicyTransitionExists(
        account,
        consumption,
        result
      )
    ensures result == account
  {
    RejectedPolicyHasUniqueResult(
      account,
      consumption,
      result
    );
  }


  // ==========================================================
  // POLICY TRANSITION — SUCCESS
  // ==========================================================

  // A successful Policy transition preserves complete Account
  // validity.
  lemma SuccessfulPolicyPreservesAccountValidity(
    before: Account,
    consumption: PolicyConsumption,
    after: Account
  )
    requires ValidAccount(before)
    requires ValidPolicyConsumption(consumption)
    requires PolicyIsApplicableAndConsistent(
               before,
               consumption
             )
    requires PolicyTransitionExists(
               before,
               consumption,
               after
             )
    ensures ValidAccount(after)
  {
    SuccessfulPolicyTransitionPreservesAccountValidity(
      before,
      consumption,
      after
    );
  }


  // A successful Policy transition preserves Account identity and
  // sovereign identity.
  lemma SuccessfulPolicyPreservesAccountIdentity(
    before: Account,
    consumption: PolicyConsumption,
    after: Account
  )
    requires ValidAccount(before)
    requires ValidPolicyConsumption(consumption)
    requires PolicyIsApplicableAndConsistent(
               before,
               consumption
             )
    requires PolicyTransitionExists(
               before,
               consumption,
               after
             )
    ensures AccountTransitionPreservesIdentity(
              before,
              after
            )
  {
    SuccessfulPolicyTransitionPreservesIdentity(
      before,
      consumption,
      after
    );
  }


  // A successful Policy has exactly one semantic Account result.
  lemma SuccessfulPolicyHasUniqueResult(
    before: Account,
    consumption: PolicyConsumption,
    result1: Account,
    result2: Account
  )
    requires
      PolicyIsApplicableAndConsistent(
        before,
        consumption
      )
    requires
      PolicyTransitionExists(
        before,
        consumption,
        result1
      )
    requires
      PolicyTransitionExists(
        before,
        consumption,
        result2
      )
    ensures result1 == result2
  {
    SuccessfulPolicyTransitionHasUniqueResult(
      before,
      consumption,
      result1,
      result2
    );
  }


  // ==========================================================
  // GLOBAL POLICY TRANSITION DETERMINISM
  // ==========================================================

  // Every Policy transition is deterministic.
  //
  // Rejected branch:
  //
  //     result = before
  //
  // Successful branch:
  //
  //     ordered Policy prefix transition is deterministic.
  lemma PolicyTransitionHasUniqueResult(
    before: Account,
    consumption: PolicyConsumption,
    result1: Account,
    result2: Account
  )
    requires
      PolicyTransitionExists(
        before,
        consumption,
        result1
      )
    requires
      PolicyTransitionExists(
        before,
        consumption,
        result2
      )
    ensures result1 == result2
  {
    PolicyTransitionIsDeterministic(
      before,
      consumption,
      result1,
      result2
    );
  }


  // ==========================================================
  // POLICY ORDER AT STATE-TRANSITION BOUNDARY
  // ==========================================================

  // The transition relation preserves the complete ordered
  // Policy prefix structure.
  lemma PolicyTransitionPreservesEffectOrder(
    account: Account,
    prefix: seq<PolicyEffect>,
    effect: PolicyEffect,
    result: Account
  )
    requires
      PolicyPrefixTransitionExists(
        account,
        prefix + [effect],
        result
      )
    ensures
      exists prefixResult : Account ::
        PolicyPrefixTransitionExists(
          account,
          prefix,
          prefixResult
        )
        &&
        PolicyEffectTransitionExists(
          prefixResult,
          effect,
          result
        )
  {
    PolicyPrefixTransitionPreservesOrder(
      account,
      prefix,
      effect,
      result
    );
  }


  // A successful Policy cannot terminate at a proper prefix and
  // present that prefix as the complete Policy result.
  lemma SuccessfulPolicyUsesCompleteEffectSequence(
    before: Account,
    consumption: PolicyConsumption,
    after: Account
  )
    requires
      PolicyIsApplicableAndConsistent(
        before,
        consumption
      )
    requires
      PolicyTransitionExists(
        before,
        consumption,
        after
      )
    ensures
      PolicyPrefixTransitionExists(
        before,
        ConsumptionPolicyEffects(consumption),
        after
      )
  {
    SuccessfulPolicyTransitionIsCompleteOrderedTransition(
      before,
      consumption,
      after
    );
  }


  // ==========================================================
  // EMPTY POLICY STATE-TRANSITION CONTRACT
  // ==========================================================

  // A valid empty PolicyConsumption leaves the Account unchanged
  // under the current Policy transition semantics.
  lemma EmptyPolicyConsumptionLeavesAccountUnchanged(
    account: Account,
    consumption: PolicyConsumption
  )
    requires ValidAccount(account)
    requires ValidPolicyConsumption(consumption)
    requires PolicyIsEmpty(
               ConsumptionPolicy(consumption)
             )
    ensures
      PolicyTransitionExists(
        account,
        consumption,
        account
      )
  {
    EmptyPolicyLeavesAccountUnchanged(
      account,
      consumption
    );
  }


  // ==========================================================
  // COMPACT E2E CONTRACT — POLICY
  // ==========================================================

  // Reusable contract for a valid Policy.
  //
  // It establishes:
  //
  //   - structural Policy validity;
  //   - valid Effect at every valid position.
  lemma ValidPolicyProvidesReusablePolicyContract(
    policy: Policy
  )
    requires ValidPolicy(policy)
    ensures forall index : nat ::
              index < PolicyEffectCount(policy)
              ==> ValidPolicyEffect(
                  PolicyEffects(policy)[index]
                )
  {
    forall index : nat
      | index < PolicyEffectCount(policy)
    {
      ValidPolicyEffectAt(
        policy,
        index
      );
    }
  }


  // ==========================================================
  // COMPACT E2E CONTRACT — POLICY CONSUMPTION
  // ==========================================================

  // Main PolicyConsumption facade consumed by downstream E2E
  // scenarios.
  //
  // It establishes:
  //
  //   - valid underlying Policy;
  //   - exact ordered Effect sequence;
  //   - exact Effect count;
  //   - valid Effect at every valid position.
  //
  // It does NOT itself mutate Account state.
  lemma ValidPolicyConsumptionProvidesReusablePolicyContract(
    consumption: PolicyConsumption
  )
    requires ValidPolicyConsumption(consumption)
    ensures ValidPolicy(
              ConsumptionPolicy(consumption)
            )
    ensures ConsumptionPolicyEffects(consumption)
         == PolicyEffects(
              ConsumptionPolicy(consumption)
            )
    ensures ConsumptionEffectCount(consumption)
         == PolicyEffectCount(
              ConsumptionPolicy(consumption)
            )
    ensures forall index : nat ::
              index < ConsumptionEffectCount(consumption)
              ==> ValidPolicyEffect(
                  ConsumptionEffectAt(
                    consumption,
                    index
                  )
                )
  {
    ValidConsumptionContainsValidPolicy(
      consumption
    );

    ConsumptionPreservesOrderedEffects(
      consumption
    );

    ConsumptionPreservesEffectCount(
      consumption
    );

    forall index : nat
      | index < ConsumptionEffectCount(consumption)
    {
      ValidConsumptionEffectAt(
        consumption,
        index
      );
    }
  }


  // ==========================================================
  // COMPACT E2E CONTRACT — POLICY TRANSITION
  // ==========================================================

  // Reusable contract for a successful complete Policy transition.
  //
  // The PolicyConsumption remains the complete semantic input,
  // while AuthorizationStateTransition provides:
  //
  //   - complete ordered application;
  //   - Account validity preservation;
  //   - Account identity preservation.
  lemma SuccessfulPolicyProvidesReusableTransitionContract(
    before: Account,
    consumption: PolicyConsumption,
    after: Account
  )
    requires ValidAccount(before)
    requires ValidPolicyConsumption(consumption)
    requires PolicyIsApplicableAndConsistent(
               before,
               consumption
             )
    requires PolicyTransitionExists(
               before,
               consumption,
               after
             )
    ensures ValidAccount(after)
    ensures AccountTransitionPreservesIdentity(
              before,
              after
            )
    ensures PolicyPrefixTransitionExists(
              before,
              ConsumptionPolicyEffects(consumption),
              after
            )
  {
    SuccessfulPolicyPreservesAccountValidity(
      before,
      consumption,
      after
    );

    SuccessfulPolicyPreservesAccountIdentity(
      before,
      consumption,
      after
    );

    SuccessfulPolicyTransitionIsCompleteOrderedTransition(
      before,
      consumption,
      after
    );
  }


  // ==========================================================
  // COMPACT E2E CONTRACT — REJECTED POLICY
  // ==========================================================

  // Reusable contract for a rejected Policy.
  //
  // Rejection is atomic:
  //
  //     result == original Account
  //
  lemma RejectedPolicyProvidesReusableTransitionContract(
    account: Account,
    consumption: PolicyConsumption,
    result: Account
  )
    requires ValidAccount(account)
    requires ValidPolicyConsumption(consumption)
    requires !PolicyIsApplicableAndConsistent(
               account,
               consumption
             )
    requires PolicyTransitionExists(
               account,
               consumption,
               result
             )
    ensures result == account
  {
    RejectedPolicyHasUniqueAccountResult(
      account,
      consumption,
      result
    );
  }


  // ==========================================================
  // COMPACT E2E CONTRACT — GLOBAL DETERMINISM
  // ==========================================================

  // Same Account + same PolicyConsumption produce one semantic
  // transition result.
  lemma PolicyProvidesReusableDeterministicTransitionContract(
    before: Account,
    consumption: PolicyConsumption,
    result1: Account,
    result2: Account
  )
    requires
      PolicyTransitionExists(
        before,
        consumption,
        result1
      )
    requires
      PolicyTransitionExists(
        before,
        consumption,
        result2
      )
    ensures result1 == result2
  {
    PolicyTransitionHasUniqueResult(
      before,
      consumption,
      result1,
      result2
    );
  }


  // ==========================================================
  // ARCHITECTURAL SEPARATION
  // ==========================================================

  // Policy approval / governance is not defined by the Policy state
  // transition itself.
  //
  // The state transition receives a PolicyConsumption and evaluates
  // applicability / consistency against Account state.
  lemma PolicyTransitionPreservesApprovalSeparation(
    account: Account,
    consumption: PolicyConsumption
  )
    requires ValidAccount(account)
    requires ValidPolicyConsumption(consumption)
    ensures
      ValidPolicyConsumption(consumption)
      &&
      ValidAccount(account)
  {
    PolicyTransitionUsesOnlyPolicyAndAccountState(
      account,
      consumption
    );
  }


  // The Policy facade stops at the semantic Policy / Account
  // transition boundary.
  //
  // It does not introduce Effective Authority, Authorization
  // acceptance, Proof verification, or execution semantics.
  lemma PolicyFacadeStopsAtStateTransitionBoundary(
    account: Account,
    consumption: PolicyConsumption
  )
    requires ValidAccount(account)
    requires ValidPolicyConsumption(consumption)
    ensures
      ValidPolicyConsumption(consumption)
      &&
      ValidAccount(account)
  {
    PolicyTransitionUsesOnlyPolicyAndAccountState(
      account,
      consumption
    );
  }
}

// ============================================================
// KIPIO ACCOUNT DOMAIN
// POLICY — POLICY
// ============================================================
//
// Policy represents an externally produced decision recognized
// by Account as capable of producing semantic changes to
// Authorization State.
//
// Policy is a Value Object / recognized external decision.
//
// Policy intentionally does NOT have:
//   - PolicyId;
//   - lifecycle identity inside Account;
//   - approval identity;
//   - producer identity;
//   - governance identity;
//   - Recovery request identity.
//
// Historical identity belongs to the bounded context that produced
// the Policy decision.
//
// ------------------------------------------------------------
//
// D2 — POLICY SEMANTICS
//
// A Policy is an ORDERED SEQUENCE of Policy Effects.
//
//     Policy
//         =
//     seq<PolicyEffect>
//
// Order is semantically meaningful.
//
// Two Policies containing the same Effects in different orders are
// therefore different semantic values unless commutativity of those
// effects has been independently established.
//
// A Policy may be empty.
//
// An empty Policy is a valid Value Object and represents a coherent
// decision that produces no AuthorizationState modification.
//
// ------------------------------------------------------------
//
// IMPORTANT BOUNDARY
//
// Policy defines:
//
//   - which Policy Effects constitute the external decision;
//   - their semantic order;
//   - Value Object equality;
//   - structural validity of the contained effects.
//
// Policy does NOT define:
//
//   - whether effects are applicable to Authorization State;
//   - whether effects contradict one another;
//   - whether effects commute;
//   - how effects mutate Authorization State;
//   - atomic consumption;
//   - partial consumption;
//   - replay/idempotence;
//   - Policy approval.
//
// Those concerns belong to PolicyConsumption,
// AuthorizationStateTransition, Replay, and the corresponding
// bounded contexts.
//
// ------------------------------------------------------------
//
// This file intentionally contains no:
//   - policy approval logic
//   - governance logic
//   - recovery logic
//   - Policy Consumption implementation
//   - Authorization State mutation
//   - authorization validation
//   - cryptographic verification
//   - execution logic
//   - blockchain ABI types
//   - storage representations
//
// ============================================================

include "PolicyEffect.dfy"

module KipioAccountPolicy
{
  import opened KipioAccountPolicyEffect


  // ----------------------------------------------------------
  // POLICY
  // ----------------------------------------------------------

  // Policy is a Value Object representing an externally produced
  // decision recognized by Account.
  //
  // The Effects are ordered because ordering is part of the
  // semantic meaning of the Policy.
  //
  // A Policy contains no independent identity or provenance.
  datatype Policy =
    Policy(
      effects: seq<PolicyEffect>
    )


  // ----------------------------------------------------------
  // ACCESSORS
  // ----------------------------------------------------------

  // Returns the ordered Policy Effects represented by the Policy.
  function PolicyEffects(
    policy: Policy
  ): seq<PolicyEffect>
  {
    policy.effects
  }


  // Returns the number of Policy Effects represented by the Policy.
  function PolicyEffectCount(
    policy: Policy
  ): nat
  {
    |PolicyEffects(policy)|
  }


  // Determines whether a particular Policy Effect appears in the
  // Policy sequence.
  //
  // Membership intentionally does not discard ordering semantics.
  // It is only a query over the sequence.
  predicate PolicyContainsEffect(
    policy: Policy,
    effect: PolicyEffect
  )
  {
    exists index ::
      0 <= index < |PolicyEffects(policy)|
      && PolicyEffects(policy)[index] == effect
  }


  // Determines whether a Policy contains no Policy Effects.
  //
  // An empty Policy is semantically valid under D2.
  predicate PolicyIsEmpty(
    policy: Policy
  )
  {
    |PolicyEffects(policy)| == 0
  }


  // ----------------------------------------------------------
  // POLICY SEMANTIC VALIDITY
  // ----------------------------------------------------------

  // Every Policy Effect represented by a Policy must itself be
  // structurally valid.
  //
  // This predicate intentionally permits an empty Policy.
  //
  // Empty Policy validity means:
  //
  //     valid decision
  //         +
  //     zero state-changing effects
  //
  // It does not imply that consuming an empty Policy performs an
  // Authorization State transition.
  predicate PolicyContainsOnlyValidEffects(
    policy: Policy
  )
  {
    forall index ::
      0 <= index < |PolicyEffects(policy)|
      ==> ValidPolicyEffect(
          PolicyEffects(policy)[index]
        )
  }


  // A Policy is structurally valid when every contained
  // Policy Effect is structurally valid.
  //
  // No non-empty requirement exists because D2 explicitly permits
  // an empty Policy.
  //
  // Validity does not mean that the Policy:
  //
  //   - is approved;
  //   - is applicable;
  //   - is internally consistent;
  //   - can be consumed;
  //   - produces a valid AuthorizationStateTransition.
  predicate ValidPolicy(
    policy: Policy
  )
  {
    PolicyContainsOnlyValidEffects(policy)
  }


  // ----------------------------------------------------------
  // VALUE OBJECT SEMANTICS
  // ----------------------------------------------------------

  // Two Policies represent the same semantic Value Object exactly
  // when their ordered Policy Effect sequences are equal.
  //
  // Therefore:
  //
  //     [A, B] != [B, A]
  //
  // unless a separate theorem establishes that the two sequences
  // are semantically interchangeable for the relevant context.
  predicate SamePolicy(
    left: Policy,
    right: Policy
  )
  {
    PolicyEffects(left) == PolicyEffects(right)
  }


  // Policies with the same ordered Effects are equal.
  lemma PoliciesWithSameEffectsAreEqual(
    left: Policy,
    right: Policy
  )
    requires SamePolicy(left, right)
    ensures left == right
  {
  }


  // A Policy has no identity independent from its semantic value.
  lemma PolicyHasNoIndependentIdentity(
    policy: Policy
  )
    ensures SamePolicy(policy, policy)
  {
  }


  // Equal Policies necessarily contain the same ordered
  // Policy Effects.
  lemma EqualPoliciesHaveEqualEffects(
    left: Policy,
    right: Policy
  )
    requires left == right
    ensures PolicyEffects(left) == PolicyEffects(right)
  {
  }


  // Equal Policies necessarily contain the same number of
  // Policy Effects.
  lemma EqualPoliciesHaveEqualEffectCount(
    left: Policy,
    right: Policy
  )
    requires left == right
    ensures PolicyEffectCount(left)
         == PolicyEffectCount(right)
  {
  }


  // ----------------------------------------------------------
  // POLICY ORDER SEMANTICS
  // ----------------------------------------------------------

  // The Policy preserves the exact order of its Effects.
  //
  // No commutativity assumption is introduced here.
  lemma PolicyPreservesEffectOrder(
    policy: Policy,
    index: nat
  )
    requires index < |PolicyEffects(policy)|
    ensures PolicyEffects(policy)[index]
         == policy.effects[index]
  {
  }


  // A Policy containing two Effects in one order is not
  // automatically equivalent to the reversed order.
  //
  // The conclusion is intentionally conditional: distinct Effects
  // are required because [A, A] and [A, A] are of course equal.
  lemma ReorderingDistinctEffectsChangesPolicyValue(
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
  }


  // ----------------------------------------------------------
  // EFFECT MEMBERSHIP
  // ----------------------------------------------------------

  // A Policy Effect selected from a valid Policy is structurally
  // valid.
  lemma ValidPolicyContainsValidEffect(
    policy: Policy,
    effect: PolicyEffect
  )
    requires ValidPolicy(policy)
    requires PolicyContainsEffect(policy, effect)
    ensures ValidPolicyEffect(effect)
  {
  }


  // A Policy Effect at a valid sequence position is structurally
  // valid.
  lemma ValidPolicyEffectAt(
    policy: Policy,
    index: nat
  )
    requires ValidPolicy(policy)
    requires index < |PolicyEffects(policy)|
    ensures ValidPolicyEffect(
              PolicyEffects(policy)[index]
            )
  {
  }


  // ----------------------------------------------------------
  // EMPTY POLICY
  // ----------------------------------------------------------

  // An empty Policy is structurally valid.
  //
  // This is explicitly required by D2.2.2.
  lemma EmptyPolicyIsValid()
    ensures ValidPolicy(
              Policy([])
            )
  {
  }


  // An empty Policy does not itself represent a state-changing
  // Effect.
  //
  // The actual consumption semantics remain outside this file.
  lemma EmptyPolicyHasNoPolicyEffects(
    policy: Policy
  )
    requires PolicyIsEmpty(policy)
    ensures |PolicyEffects(policy)| == 0
  {
  }


  // ----------------------------------------------------------
  // POLICY PRODUCTION BOUNDARY
  // ----------------------------------------------------------

  // A Policy can only expose Policy Effects that actually occur in
  // its ordered sequence.
  lemma PolicyCannotExposeUnrepresentedEffect(
    policy: Policy,
    effect: PolicyEffect
  )
    requires PolicyContainsEffect(policy, effect)
    ensures exists index ::
              0 <= index < |PolicyEffects(policy)|
              && PolicyEffects(policy)[index] == effect
  {
  }
}

// ============================================================
// KIPIO ACCOUNT DOMAIN
// POLICY — POLICY CONSUMPTION
// ============================================================
//
// Policy Consumption represents the recognition of a complete
// Policy result as the semantic unit presented for consumption
// by Account.
//
// Policy Consumption is a Value Object / transition value.
//
// Conceptual separation:
//
//     External Policy Procedure
//              |
//              v
//           Policy
//              |
//              v
//       Policy Consumption
//              |
//              v
//     Authorization State Transition
//
// Policy contains the semantic Policy Effects.
//
// Policy Consumption does NOT duplicate those Effects.
// The Policy remains the single semantic source of truth for the
// ordered Effects represented by the consumed decision.
//
// ------------------------------------------------------------
//
// D2 — POLICY CONSUMPTION SEMANTICS
//
// A Policy Consumption identifies one complete Policy value as the
// semantic unit of consumption.
//
// Therefore:
//
//     PolicyConsumption
//         |
//         └── Policy
//                |
//                └── ordered seq<PolicyEffect>
//
// There is no independent consumed-effects collection.
//
// The semantic unit is the complete Policy.
//
// A successful consumption is conceptually all-or-nothing:
//
//     valid + applicable + consistent
//              =>
//          complete Policy consumption
//
//     otherwise
//              =>
//          no AuthorizationState transition
//
// This file establishes only the semantic consumption boundary.
//
// Concrete applicability, contradiction detection, replay handling,
// state mutation, and atomic AuthorizationState transformation
// remain outside this Value Object.
//
// ------------------------------------------------------------
//
// IMPORTANT BOUNDARY
//
// Policy Consumption defines:
//
//   - which Policy is being consumed;
//   - the complete ordered Effect sequence represented by it;
//   - Value Object equality;
//   - structural validity;
//   - that consumption refers to the whole Policy value.
//
// Policy Consumption does NOT define:
//
//   - Credential lifecycle mutation;
//   - Session lifecycle mutation;
//   - Delegation lifecycle mutation;
//   - Capability mutation;
//   - concrete Effect applicability;
//   - contradictory Effect detection;
//   - state mutation implementation;
//   - replay/idempotence mechanics;
//   - Policy approval.
//
// Those concerns belong to:
//
//   - AuthorizationState;
//   - AccountTransitions;
//   - Replay;
//   - and the corresponding formal laws.
//
// ------------------------------------------------------------
//
// This file intentionally contains no:
//   - policy approval logic
//   - governance logic
//   - recovery implementation
//   - cross-contract call implementation
//   - cryptographic verification
//   - authorization validation
//   - execution logic
//   - blockchain ABI types
//   - storage representations
//
// ============================================================

include "Policy.dfy"
include "PolicyEffect.dfy"

module KipioAccountPolicyConsumption
{
  import opened KipioAccountPolicy
  import opened KipioAccountPolicyEffect


  // ----------------------------------------------------------
  // POLICY CONSUMPTION
  // ----------------------------------------------------------

  // PolicyConsumption is a Value Object / transition value
  // representing one complete Policy result presented for
  // consumption by Account.
  //
  // No independent identity is introduced.
  //
  // No consumed-effects collection is stored because the Policy
  // already owns the ordered semantic Effect sequence.
  datatype PolicyConsumption =
    PolicyConsumption(
      policy: Policy
    )


  // ----------------------------------------------------------
  // CONSUMED POLICY
  // ----------------------------------------------------------

  // Returns the complete Policy represented by the consumption.
  //
  // Policy Consumption does not determine how the Policy was
  // produced, approved, authenticated, or delivered.
  function ConsumptionPolicy(
    consumption: PolicyConsumption
  ): Policy
  {
    consumption.policy
  }


  // ----------------------------------------------------------
  // CONSUMED POLICY EFFECTS
  // ----------------------------------------------------------

  // Returns the complete ordered sequence of Policy Effects
  // represented by the Policy being consumed.
  //
  // This is derived from the Policy rather than stored separately
  // in PolicyConsumption.
  function ConsumptionPolicyEffects(
    consumption: PolicyConsumption
  ): seq<PolicyEffect>
  {
    PolicyEffects(
      ConsumptionPolicy(consumption)
    )
  }


  // Returns the number of Effects represented by the complete
  // Policy being consumed.
  function ConsumptionEffectCount(
    consumption: PolicyConsumption
  ): nat
  {
    |ConsumptionPolicyEffects(consumption)|
  }


  // ----------------------------------------------------------
  // EFFECT MEMBERSHIP
  // ----------------------------------------------------------

  // Determines whether a particular Policy Effect occurs in the
  // ordered Policy sequence being consumed.
  //
  // Membership is only a query. It does not transform the Policy
  // into a set and therefore does not discard ordering semantics.
  predicate ConsumptionContainsEffect(
    consumption: PolicyConsumption,
    effect: PolicyEffect
  )
  {
    PolicyContainsEffect(
      ConsumptionPolicy(consumption),
      effect
    )
  }


  // Returns the Policy Effect at a particular position in the
  // consumed Policy.
  //
  // Sequence position remains semantically meaningful.
  function ConsumptionEffectAt(
    consumption: PolicyConsumption,
    index: nat
  ): PolicyEffect
    requires index < ConsumptionEffectCount(consumption)
  {
    ConsumptionPolicyEffects(consumption)[index]
  }


  // ----------------------------------------------------------
  // POLICY CONSUMPTION VALIDITY
  // ----------------------------------------------------------

  // A Policy Consumption is structurally valid exactly when the
  // Policy it carries is structurally valid.
  //
  // Because an empty Policy is structurally valid, an empty
  // Policy Consumption is also structurally valid.
  predicate ValidPolicyConsumption(
    consumption: PolicyConsumption
  )
  {
    ValidPolicy(
      ConsumptionPolicy(consumption)
    )
  }


  // ----------------------------------------------------------
  // VALUE OBJECT SEMANTICS
  // ----------------------------------------------------------

  // Two Policy Consumption values represent the same semantic
  // transition value when they carry the same Policy.
  //
  // No independent ConsumptionId exists.
  predicate SamePolicyConsumption(
    left: PolicyConsumption,
    right: PolicyConsumption
  )
  {
    ConsumptionPolicy(left)
    ==
    ConsumptionPolicy(right)
  }


  // Policy Consumptions carrying the same Policy are equal.
  lemma PolicyConsumptionsWithSamePolicyAreEqual(
    left: PolicyConsumption,
    right: PolicyConsumption
  )
    requires SamePolicyConsumption(left, right)
    ensures left == right
  {
  }


  // Policy Consumption has no independent identity beyond its
  // semantic Value Object value.
  lemma PolicyConsumptionHasNoIndependentIdentity(
    consumption: PolicyConsumption
  )
    ensures SamePolicyConsumption(
              consumption,
              consumption
            )
  {
  }


  // Equal Policy Consumption values necessarily carry equal
  // Policies.
  lemma EqualPolicyConsumptionsHaveEqualPolicies(
    left: PolicyConsumption,
    right: PolicyConsumption
  )
    requires left == right
    ensures ConsumptionPolicy(left)
         == ConsumptionPolicy(right)
  {
  }


  // Equal Policy Consumption values necessarily expose equal
  // ordered Effect sequences.
  lemma EqualPolicyConsumptionsHaveEqualEffects(
    left: PolicyConsumption,
    right: PolicyConsumption
  )
    requires left == right
    ensures ConsumptionPolicyEffects(left)
         == ConsumptionPolicyEffects(right)
  {
  }


  // Equal Policy Consumption values necessarily contain the same
  // number of Effects.
  lemma EqualPolicyConsumptionsHaveEqualEffectCount(
    left: PolicyConsumption,
    right: PolicyConsumption
  )
    requires left == right
    ensures ConsumptionEffectCount(left)
         == ConsumptionEffectCount(right)
  {
  }


  // ----------------------------------------------------------
  // POLICY EFFECT MEMBERSHIP / VALIDITY
  // ----------------------------------------------------------

  // A Policy Effect represented by a valid Policy Consumption is
  // structurally valid.
  lemma ValidConsumptionContainsValidEffect(
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
  }


  // A Policy Effect at a valid position in a valid Policy
  // Consumption is structurally valid.
  lemma ValidConsumptionEffectAt(
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
  }


  // A Policy Consumption exposes exactly the Effects represented
  // by its underlying Policy.
  lemma ConsumptionContainsEffectIffPolicyEffectMember(
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
  }


  // A Policy Consumption preserves the semantic order of the
  // Policy it consumes.
  lemma ConsumptionPreservesPolicyEffectOrder(
    consumption: PolicyConsumption,
    index: nat
  )
    requires index < ConsumptionEffectCount(consumption)
    ensures ConsumptionEffectAt(
              consumption,
              index
            )
            ==
            ConsumptionPolicyEffects(consumption)[index]
  {
  }


  // ----------------------------------------------------------
  // COMPLETE POLICY AS CONSUMPTION UNIT
  // ----------------------------------------------------------

  // The complete Policy value is the semantic unit represented
  // by Policy Consumption.
  //
  // Consumption does not select an independent subset of Effects.
  lemma ConsumptionRepresentsCompletePolicy(
    consumption: PolicyConsumption
  )
    ensures ConsumptionPolicyEffects(consumption)
         == PolicyEffects(ConsumptionPolicy(consumption))
  {
  }


  // Consumption exposes no independent source of Effects beyond
  // the Policy value it carries.
  lemma PolicyIsSingleSourceOfConsumptionEffects(
    consumption: PolicyConsumption
  )
    ensures ConsumptionPolicyEffects(consumption)
         == PolicyEffects(consumption.policy)
  {
  }


  // A Policy Consumption cannot semantically represent a second
  // Effect sequence different from the Policy it carries.
  lemma ConsumptionCannotHaveIndependentEffectSequence(
    consumption: PolicyConsumption,
    effects: seq<PolicyEffect>
  )
    requires effects == ConsumptionPolicyEffects(consumption)
    ensures effects == PolicyEffects(ConsumptionPolicy(consumption))
  {
  }


  // ----------------------------------------------------------
  // ALL-OR-NOTHING SEMANTIC BOUNDARY
  // ----------------------------------------------------------

  // A successful Policy Consumption denotes the complete Policy
  // value, not a proper subset of its Effects.
  //
  // This lemma intentionally does NOT model AuthorizationState
  // mutation or prove atomic state transition.
  //
  // Actual atomicity belongs to the corresponding state-transition
  // semantics and laws.
  lemma SuccessfulPolicyConsumptionRepresentsWholePolicy(
    consumption: PolicyConsumption
  )
    requires ValidPolicyConsumption(consumption)
    ensures ConsumptionPolicy(consumption)
         == consumption.policy
    ensures ConsumptionPolicyEffects(consumption)
         == PolicyEffects(consumption.policy)
  {
  }


  // ----------------------------------------------------------
  // POLICY APPROVAL BOUNDARY
  // ----------------------------------------------------------

  // Policy Consumption operates on a Policy already recognized as
  // an external semantic decision.
  //
  // Consumption itself does not define how that Policy was
  // produced or approved.
  lemma ConsumptionDoesNotDefinePolicyApproval(
    consumption: PolicyConsumption
  )
    ensures ConsumptionPolicy(consumption)
         == consumption.policy
  {
  }


  // ----------------------------------------------------------
  // STATE TRANSITION BOUNDARY
  // ----------------------------------------------------------

  // Policy Consumption is the semantic input to an eventual
  // AuthorizationState transition.
  //
  // It does not itself calculate or construct the resulting state.
  //
  // Applicability, contradiction detection, complete validation,
  // and atomic state transformation remain outside this file.
  lemma PolicyConsumptionDoesNotItselfDefineStateTransition(
    consumption: PolicyConsumption
  )
    requires ValidPolicyConsumption(consumption)
    ensures ValidPolicy(
              ConsumptionPolicy(consumption)
            )
  {
  }
}

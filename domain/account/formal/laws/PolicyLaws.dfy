// ============================================================
// KIPIO ACCOUNT DOMAIN
// LAWS — POLICY
// ============================================================
//
// Cross-concept semantic laws governing the relationship between:
//
//     Policy Consumption
//          |
//          v
//     Policy Effect
//          |
//          v
//     Authorization State
//
// The local semantics of Policy remain in:
//
//     Policy.dfy
//
// The local semantics of Policy Consumption remain in:
//
//     PolicyConsumption.dfy
//
// The local semantics of Policy Effects remain in:
//
//     PolicyEffect.dfy
//
// AuthorizationState validity and recognition remain in:
//
//     AuthorizationState.dfy
//
// Concrete Policy -> Account / AuthorizationState transition
// semantics remain in:
//
//     AuthorizationStateTransition.dfy
//
// This file therefore contains only compositional consequences
// that cross those independently defined concepts.
//
// ------------------------------------------------------------
//
// D2 BOUNDARY
//
// Policy is an ordered sequence of Policy Effects.
//
// Policy Consumption represents that complete Policy value.
//
// AuthorizationState separately recognizes Policy Effects.
//
// This file formalizes the semantic consequence obtained when:
//
//     valid Policy Consumption
//           +
//     recognized Policy Effect
//           +
//     valid AuthorizationState
//
// are considered together.
//
// ------------------------------------------------------------
//
// IMPORTANT DISTINCTIONS
//
//     Policy validity
//         !=
//     Effect applicability
//
//     Policy Consumption validity
//         !=
//     AuthorizationState applicability
//
//     Policy Effect recognition
//         !=
//     Policy approval
//
//     Policy description
//         !=
//     AuthorizationState mutation
//
// Concrete applicability, contradiction detection, atomicity and
// state transformation are already formalized in
// AuthorizationStateTransition.dfy.
//
// ------------------------------------------------------------
//
// This file intentionally does NOT:
//
//   - redefine Policy semantics;
//   - redefine PolicyConsumption semantics;
//   - redefine PolicyEffect semantics;
//   - redefine AuthorizationState invariants;
//   - redefine Policy transition semantics;
//   - detect contradictions;
//   - prove commutativity;
//   - mutate state;
//   - perform authorization;
//   - verify Proof;
//   - perform execution.
//
// ============================================================

include "../policy/Policy.dfy"
include "../policy/PolicyConsumption.dfy"
include "../policy/PolicyEffect.dfy"

include "../authority/AuthorizationState.dfy"

include "../policy/AuthorizationStateTransition.dfy"


module KipioAccountPolicyLaws
{
  import opened KipioAccountPolicy
  import opened KipioAccountPolicyConsumption
  import opened KipioAccountPolicyEffect
  import opened KipioAccountAuthorizationState
  import opened KipioAccountAuthorizationStateTransition


  // ----------------------------------------------------------
  // POLICY CONSUMPTION / AUTHORIZATION STATE
  // ----------------------------------------------------------

  // A Policy Effect represented by a valid Policy Consumption and
  // simultaneously recognized by a valid Authorization State is
  // structurally valid under both semantic boundaries.
  //
  // The Policy side establishes:
  //
  //     effect ∈ consumed Policy
  //         +
  //     valid consumed Policy
  //
  // The State side establishes:
  //
  //     effect recognized by state
  //         +
  //     valid Authorization State
  //
  // Therefore the Effect crossing both boundaries is structurally
  // valid.
  //
  // This is a genuine cross-concept composition law; neither
  // PolicyConsumption.dfy nor AuthorizationState.dfy alone expresses
  // this combined relationship.
  lemma ConsumedAndRecognizedEffectIsStructurallyValid(
    consumption: PolicyConsumption,
    state: AuthorizationState,
    effect: PolicyEffect
  )
    requires ValidPolicyConsumption(consumption)
    requires ValidAuthorizationState(state)
    requires ConsumptionContainsEffect(
               consumption,
               effect
             )
    requires PolicyEffectRecognizedInState(
               state,
               effect
             )
    ensures ValidPolicyEffect(effect)
  {
    ValidConsumptionContainsValidEffect(
      consumption,
      effect
    );

    StateContainsOnlyValidPolicyEffects(
      state,
      effect
    );

    assert ValidPolicyEffect(effect);
  }


  // ----------------------------------------------------------
  // POLICY EFFECT / STATE VALIDATION BOUNDARY
  // ----------------------------------------------------------

  // A Policy Effect crossing from a valid Policy Consumption into a
  // valid Authorization State does not acquire a second structural
  // representation.
  //
  // Both sides identify the same semantic PolicyEffect value.
  //
  // This preserves the Value Object boundary:
  //
  //     PolicyConsumption
  //          |
  //          +---- PolicyEffect
  //          |
  //          v
  //     AuthorizationState recognition
  //
  // Recognition does not clone or redefine the Effect.
  lemma ConsumedRecognizedEffectHasSingleSemanticValue(
    consumption: PolicyConsumption,
    state: AuthorizationState,
    effect: PolicyEffect
  )
    requires ValidPolicyConsumption(consumption)
    requires ValidAuthorizationState(state)
    requires ConsumptionContainsEffect(
               consumption,
               effect
             )
    requires PolicyEffectRecognizedInState(
               state,
               effect
             )
    ensures exists policyEffect ::
              policyEffect
              == effect
              &&
              ConsumptionContainsEffect(
                consumption,
                policyEffect
              )
              &&
              PolicyEffectRecognizedInState(
                state,
                policyEffect
              )
  {
    assert ConsumptionContainsEffect(
        consumption,
        effect
      );

    assert PolicyEffectRecognizedInState(
        state,
        effect
      );

    assert exists policyEffect ::
        policyEffect == effect
        &&
        ConsumptionContainsEffect(
          consumption,
          policyEffect
        )
        &&
        PolicyEffectRecognizedInState(
          state,
          policyEffect
        );
  }


  // ----------------------------------------------------------
  // POLICY CONSUMPTION / TRANSITION SEPARATION
  // ----------------------------------------------------------

  // A valid Policy Consumption provides a complete ordered Policy
  // value to the transition layer, but Policy Consumption itself
  // does not determine the resulting Account.
  //
  // The actual state result is defined by
  // AuthorizationStateTransition.dfy.
  //
  // This theorem makes the architectural boundary explicit without
  // duplicating the transition determinism or atomicity proofs.
  lemma ValidPolicyConsumptionIsIndependentOfTransitionResult(
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
  {
    assert ValidPolicy(
        ConsumptionPolicy(consumption)
      );

    assert ConsumptionPolicyEffects(consumption)
        == PolicyEffects(
             ConsumptionPolicy(consumption)
           );
  }
}

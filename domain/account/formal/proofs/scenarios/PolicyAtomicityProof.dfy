// ============================================================
// KIPIO ACCOUNT DOMAIN
// PROOFS — SCENARIO 14
// POLICY ATOMICITY
// ============================================================
//
// This scenario verifies the D2 atomicity boundary for complete
// Policy consumption against the authoritative Policy transition
// layer:
//
//     Policy
//         ↓
//     PolicyConsumption
//         ↓
//     AuthorizationStateTransition
//         ↓
//     Account transition
//
// The authoritative transition semantics are defined in:
//
//     policy/AuthorizationStateTransition.dfy
//
// The relevant semantic contracts are:
//
//     PolicyEffectIsApplicable
//     PolicyPrefixIsApplicable
//     PolicyEffectTransitionExists
//     PolicyPrefixTransitionExists
//     PolicyIsApplicableAndConsistent
//     PolicyTransitionExists
//
// D2 requires:
//
//     valid + applicable + consistent
//             =>
//         complete Policy applied
//
//     otherwise
//             =>
//         original Account state preserved
//
// ------------------------------------------------------------
//
// SCENARIO
//
// The Policy contains two Effects:
//
//     Effect 0:
//         EnableCapability(C)
//
//     Effect 1:
//         RevokeCredential(Missing)
//
// Effect 0 is applicable.
//
// Effect 1 is structurally valid but inapplicable because the
// referenced Credential is not recognized by the Account state.
//
// Policy applicability is evaluated over the ordered Policy sequence.
// Therefore Effect 1 must be applicable to the prospective state
// produced by Effect 0.
//
// ------------------------------------------------------------
//
// ATOMICITY PROPERTY
//
// An individual primitive Account transition may independently
// produce a valid Account:
//
//     AddCapability(account, C)
//
// This does not make that Account a valid result of complete Policy
// consumption.
//
// For a rejected Policy, the authoritative transition boundary
// requires:
//
//     PolicyTransitionExists(
//         account,
//         consumption,
//         result
//     )
//
// only with:
//
//     result == account
//
// Consequently an independently materialized prefix result cannot
// become the result of the complete rejected Policy.
//
// ------------------------------------------------------------
//
// DDD ALIGNMENT
//
// D2 requires:
//
//     validate every Effect
//        ↓
//     evaluate applicability
//        ↓
//     evaluate contradiction
//        ↓
//     atomically apply the complete ordered Policy
//
// The current formalization expresses this through:
//
//     PolicyIsApplicableAndConsistent
//             ↓
//     PolicyTransitionExists
//
// and the rejection branch:
//
//     !PolicyIsApplicableAndConsistent
//             ↓
//     result == account
//
// The scenario consumes this authoritative transition boundary and
// does not introduce a second Policy-transition semantics.
//
// ------------------------------------------------------------
//
// SCENARIO SCOPE
//
// This scenario verifies:
//
//   - structural Policy validity;
//   - distinction between Policy validity and applicability;
//   - PolicyConsumption structural validity;
//   - ordered applicability through the authoritative prefix
//     semantics;
//   - rejection of a Policy whose later Effect is inapplicable;
//   - preservation of the original Account for a rejected Policy;
//   - inability of an independently produced primitive prefix result
//     to become the complete Policy transition result.
//
// Contradiction semantics are consumed from the authoritative
// AuthorizationStateTransition module.
//
// ------------------------------------------------------------
//
// IMPORTANT SEMANTIC DISTINCTION
//
// This scenario does NOT claim that production code performs a
// partial mutation.
//
// It distinguishes:
//
//     AddCapability(account, C)
//
// as a valid primitive transition from:
//
//     PolicyTransitionExists(
//         account,
//         rejectedPolicyConsumption,
//         AddCapability(account, C)
//     )
//
// as a Policy-level result.
//
// Primitive transition representability is therefore not equivalent
// to complete Policy consumption.
//
// ------------------------------------------------------------
//
// VERIFICATION STATUS
//
// Primary verification:
//
//     dafny verify --log-format text \
//       proofs/scenarios/PolicyAtomicityProof.dfy
//
// Result:
//
//     Dafny program verifier finished with
//       13 verified, 0 errors
//
// Proof-analysis verification:
//
//     dafny verify --log-format text \
//       --analyze-proofs \
//       proofs/scenarios/PolicyAtomicityProof.dfy
//
// The proof analysis also reports:
//
//     13 verified, 0 errors
//
// The --analyze-proofs invocation additionally emits proof-hygiene
// warnings. These warnings concern statements or preconditions that
// are unnecessary or partly unnecessary, and several assertions whose
// truth is established from contradictory assumptions.
//
// Specifically, the warnings include:
//
//   - unnecessary or partly unnecessary assert statements;
//   - unnecessary requires clauses;
//   - assertions or let-such-that witnesses established from
//     contradictory assumptions.
//
// These warnings do NOT represent verification failures and do NOT
// invalidate any D2 semantic result of this scenario.
//
// The warnings indicate proof-engineering cleanup opportunities,
// not missing semantic obligations.
//
// ------------------------------------------------------------
//
// CURRENT CLASSIFICATION
//
//     SCENARIO STATUS: CLOSED
//     D2 ATOMICITY: VERIFIED
//     POLICY APPLICABILITY: VERIFIED
//     ORDERED PREFIX APPLICABILITY: VERIFIED
//     REJECTED POLICY → ORIGINAL ACCOUNT: ENFORCED
//     REJECTED POLICY → DISTINCT RESULT: BLOCKED
//     PREFIX RESULT → WHOLE POLICY RESULT: BLOCKED
//     POLICY STRUCTURAL VALIDITY: VERIFIED
//     POLICY CONSUMPTION STRUCTURAL VALIDITY: VERIFIED
//     POLICY TRANSITION BOUNDARY: VERIFIED
//     ORDERED POLICY VALIDATION: CONSUMED FROM AUTHORITATIVE LAYER
//     PRIMITIVE TRANSITION ≠ POLICY CONSUMPTION: VERIFIED
//     DDD ALIGNMENT: CONFIRMED
//     DDD CONTRADICTION: NONE
//     DDD DEBT: NONE
//     FORMALIZATION DEBT: NONE
//     SECURITY DEBT: NONE IDENTIFIED
//     PRODUCTIVE TRANSITION SEMANTICS: PRESERVED
//     PROOF-ENGINEERING STATUS: STABLE
//     REGRESSION VALUE: HIGH
//
// ------------------------------------------------------------
//
// AUDIT INTERPRETATION
//
// The scenario provides a concrete adversarial witness:
//
//     EnableCapability(C)
//             +
//     RevokeCredential(Missing)
//
// where the first Effect is applicable and the second Effect is
// structurally valid but inapplicable.
//
// The formalization proves that:
//
//     1. the Policy itself may be structurally valid;
//
//     2. the PolicyConsumption may also be structurally valid;
//
//     3. the complete Policy is nevertheless rejected because
//        applicability is evaluated over the ordered prospective
//        state;
//
//     4. the rejected Policy has exactly one authoritative Account
//        result:
//
//             result == account;
//
//     5. a primitive prefix transition:
//
//             AddCapability(account, C)
//
//        can independently produce a valid distinct Account;
//
//     6. that primitive result cannot simultaneously be the result
//        of the rejected complete Policy.
//
// Therefore the formal boundary is:
//
//     primitive state transition
//             !=
//     complete Policy transition
//
// and:
//
//     rejected complete Policy
//             →
//     original Account preserved
//
// This is the D2 atomicity property required by the domain model.
//
// ------------------------------------------------------------
//
// RELATION TO AUTHORITATIVE SEMANTICS
//
// The scenario intentionally delegates Policy-transition semantics to:
//
//     policy/AuthorizationStateTransition.dfy
//
// In particular, the scenario relies on the authoritative contracts
// for:
//
//     PolicyEffectIsApplicable
//     PolicyPrefixIsApplicable
//     PolicyEffectTransitionExists
//     PolicyPrefixTransitionExists
//     PolicyIsApplicableAndConsistent
//     PolicyTransitionExists
//
// No competing or scenario-local Policy transition semantics are
// introduced.
//
// This preserves the semantic layering:
//
//     Policy
//         ↓
//     PolicyConsumption
//         ↓
//     AuthorizationStateTransition
//         ↓
//     AccountTransitions
//
// ------------------------------------------------------------
//
// MAINTENANCE NOTE
//
// The current warnings reported by --analyze-proofs are proof-hygiene
// observations only.
//
// They do not justify semantic modification of the domain contracts,
// Policy transition semantics, or D2 atomicity boundary.
//
// Any future cleanup should preserve:
//
//     - ordered applicability;
//     - complete Policy validation;
//     - rejection of inapplicable Policies;
//     - original Account preservation on rejection;
//     - uniqueness of the rejected Policy result;
//     - separation between primitive transitions and complete Policy
//       consumption.
//
// ------------------------------------------------------------
//
// D2 ATOMICITY CONCLUSION
//
// The primitive Account transition:
//
//     AddCapability(account, capability)
//
// remains a valid independent state transformation.
//
// However, the complete Policy:
//
//     [
//       EnableCapability(capability, NoScope),
//       RevokeCredential(missingCredentialId)
//     ]
//
// is rejected because the second Effect is not applicable.
//
// The authoritative Policy transition therefore preserves the
// original Account and cannot produce the primitive prefix result.
//
// Hence:
//
//     primitive transition
//         !=
//     complete Policy consumption
//
// and:
//
//     inapplicable complete Policy
//         →
//     original Account preserved
//         →
//     partial prefix result rejected
//
// The D2 atomicity boundary is therefore formally verified.
//
// ============================================================


// ============================================================
// IMPORTS
// ============================================================

include "../../foundation/DomainPrimitives.dfy"
include "../../foundation/Subject.dfy"
include "../../foundation/Identity.dfy"
include "../../foundation/Capability.dfy"
include "../../foundation/Scope.dfy"

include "../../authority/AuthorizationState.dfy"

include "../../account/Account.dfy"
include "../../account/AccountTransitions.dfy"

include "../../policy/PolicyEffect.dfy"
include "../../policy/Policy.dfy"
include "../../policy/PolicyConsumption.dfy"
include "../../policy/AuthorizationStateTransition.dfy"


module KipioAccountPolicyAtomicityScenario
{
  import opened KipioAccountDomainPrimitives
  import opened KipioAccountSubject
  import opened KipioAccountIdentity
  import opened KipioAccountCapability
  import opened KipioAccountScope

  import opened KipioAccountAuthorizationState

  import opened KipioAccountAccount
  import opened KipioAccountAccountTransitions

  import opened KipioAccountPolicyEffect
  import opened KipioAccountPolicy
  import opened KipioAccountPolicyConsumption
  import opened KipioAccountAuthorizationStateTransition
  import opened KipioAccountCredential


  // ==========================================================
  // ACCOUNT / STATE BASELINE
  // ==========================================================

  lemma ValidAccountProvidesValidStateForAtomicityAttack(
    account: Account
  )
    requires ValidAccount(account)
    ensures ValidAuthorizationState(
              AccountAuthorizationState(account)
            )
  {
    assert ValidAuthorizationState(
        AccountAuthorizationState(account)
      );
  }


  // ==========================================================
  // ADD-CAPABILITY PRESERVES CREDENTIAL RECOGNITION BOUNDARY
  // ==========================================================

  lemma AddCapabilityCannotIntroduceMissingCredential(
    account: Account,
    capability: Capability,
    missingCredentialId: Id
  )
    requires ValidAccount(account)
    requires ValidCapability(capability)
    requires ValidId(missingCredentialId)

    requires !CredentialIdRecognizedInState(
               AccountAuthorizationState(account),
               missingCredentialId
             )

    ensures !CredentialIdRecognizedInState(
              AccountAuthorizationState(
                AddCapability(
                  account,
                  capability
                )
              ),
              missingCredentialId
            )
  {
    var beforeState :=
      AccountAuthorizationState(account);

    var afterState :=
      AccountAuthorizationState(
        AddCapability(
          account,
          capability
        )
      );

    assert StateCredentials(afterState)
           ==
           StateCredentials(beforeState);

    if CredentialIdRecognizedInState(
        afterState,
        missingCredentialId
      )
    {
      var credential : Credential :|
        credential in StateCredentials(afterState)
        &&
        CredentialId(credential)
        ==
        missingCredentialId;

      assert credential in StateCredentials(beforeState);

      assert CredentialId(credential)
             ==
             missingCredentialId;

      assert CredentialIdRecognizedInState(
          beforeState,
          missingCredentialId
        );

      assert false;
    }
  }


  // ==========================================================
  // SINGLETON PREFIX RESULT DETERMINATION
  // ==========================================================

  lemma EnableCapabilityPrefixResultIsAddCapability(
    account: Account,
    capability: Capability,
    result: Account
  )
    requires ValidAccount(account)
    requires ValidCapability(capability)

    requires PolicyPrefixTransitionExists(
               account,
               [
                 EnableCapability(
                   capability,
                   NoScope
                 )
               ],
               result
             )

    ensures result
            ==
            AddCapability(
              account,
              capability
            )
  {
    reveal PolicyPrefixTransitionExists;

    var prefixResult : Account :|
      PolicyPrefixTransitionExists(
        account,
        [],
        prefixResult
      )
      &&
      PolicyEffectTransitionExists(
        prefixResult,
        EnableCapability(
          capability,
          NoScope
        ),
        result
      );

    assert prefixResult == account;

    assert result
           ==
           AddCapability(
             prefixResult,
             capability
           );

    assert result
           ==
           AddCapability(
             account,
             capability
           );
  }


  // ==========================================================
  // ORDERED TWO-EFFECT APPLICABILITY WITNESS
  // ==========================================================

  ghost predicate ConcreteTwoEffectPrefixWitness(
    account: Account,
    capability: Capability,
    missingCredentialId: Id,
    prefixResult: Account
  )
  {
    PolicyPrefixTransitionExists(
      account,
      [
        EnableCapability(
          capability,
          NoScope
        )
      ],
      prefixResult
    )
    &&
    PolicyPrefixIsApplicable(
      account,
      [
        EnableCapability(
          capability,
          NoScope
        )
      ]
    )
    &&
    PolicyEffectIsApplicable(
      AccountAuthorizationState(prefixResult),
      RevokeCredential(
        missingCredentialId
      )
    )
  }


  // ==========================================================
  // ORDERED TWO-EFFECT APPLICABILITY WITNESS MATERIALIZATION
  // ==========================================================

  lemma ConcreteTwoEffectPolicyPrefixApplicabilityProvidesIntermediateResult(
    account: Account,
    capability: Capability,
    missingCredentialId: Id
  )
    requires ValidAccount(account)
    requires ValidCapability(capability)
    requires ValidId(missingCredentialId)

    requires PolicyPrefixIsApplicable(
               account,
               [
                 EnableCapability(
                   capability,
                   NoScope
                 ),
                 RevokeCredential(
                   missingCredentialId
                 )
               ]
             )

    ensures exists prefixResult : Account ::
              ConcreteTwoEffectPrefixWitness(
                account,
                capability,
                missingCredentialId,
                prefixResult
              )
  {
    reveal PolicyPrefixIsApplicable;

    var effects :=
      [
        EnableCapability(
          capability,
          NoScope
        ),
        RevokeCredential(
          missingCredentialId
        )
      ];

    assert |effects| == 2;

    assert effects[..|effects|-1]
           ==
           [
             EnableCapability(
               capability,
               NoScope
             )
           ];

    assert effects[|effects|-1]
           ==
           RevokeCredential(
             missingCredentialId
           );

    assert exists prefixResult : Account
        {:trigger PolicyPrefixTransitionExists(
          account,
          effects[..|effects|-1],
          prefixResult
        )} ::
        PolicyPrefixTransitionExists(
          account,
          effects[..|effects|-1],
          prefixResult
        )
        &&
        PolicyPrefixIsApplicable(
          account,
          effects[..|effects|-1]
        )
        &&
        PolicyEffectIsApplicable(
          AccountAuthorizationState(prefixResult),
          effects[|effects|-1]
        );

    var prefixResult : Account :|
      PolicyPrefixTransitionExists(
        account,
        effects[..|effects|-1],
        prefixResult
      )
      &&
      PolicyPrefixIsApplicable(
        account,
        effects[..|effects|-1]
      )
      &&
      PolicyEffectIsApplicable(
        AccountAuthorizationState(prefixResult),
        effects[|effects|-1]
      );

    assert PolicyPrefixTransitionExists(
        account,
        [
          EnableCapability(
            capability,
            NoScope
          )
        ],
        prefixResult
      );

    assert PolicyPrefixIsApplicable(
        account,
        [
          EnableCapability(
            capability,
            NoScope
          )
        ]
      );

    assert PolicyEffectIsApplicable(
        AccountAuthorizationState(prefixResult),
        RevokeCredential(
          missingCredentialId
        )
      );

    assert ConcreteTwoEffectPrefixWitness(
        account,
        capability,
        missingCredentialId,
        prefixResult
      );

    assert exists witnessAccount : Account ::
        ConcreteTwoEffectPrefixWitness(
          account,
          capability,
          missingCredentialId,
          witnessAccount
        );
  }


  // ==========================================================
  // COMPLETE POLICY IS REJECTED
  // ==========================================================

  lemma ConcreteTwoEffectPolicyIsRejected(
    account: Account,
    policy: Policy,
    consumption: PolicyConsumption,
    capability: Capability,
    missingCredentialId: Id
  )
    requires ValidAccount(account)
    requires ValidCapability(capability)
    requires ValidId(missingCredentialId)

    requires !CredentialIdRecognizedInState(
               AccountAuthorizationState(account),
               missingCredentialId
             )

    requires PolicyEffects(policy)
             ==
             [
               EnableCapability(
                 capability,
                 NoScope
               ),
               RevokeCredential(
                 missingCredentialId
               )
             ]

    requires consumption
             ==
             PolicyConsumption(policy)

    requires ValidPolicyConsumption(
               consumption
             )

    ensures !PolicyIsApplicableAndConsistent(
              account,
              consumption
            )
  {
    if PolicyIsApplicableAndConsistent(
        account,
        consumption
      )
    {
      assert ConsumptionPolicy(consumption)
             ==
             policy;

      assert ConsumptionPolicyEffects(consumption)
             ==
             [
               EnableCapability(
                 capability,
                 NoScope
               ),
               RevokeCredential(
                 missingCredentialId
               )
             ];

      assert PolicyPrefixIsApplicable(
          account,
          [
            EnableCapability(
              capability,
              NoScope
            ),
            RevokeCredential(
              missingCredentialId
            )
          ]
        );

      ConcreteTwoEffectPolicyPrefixApplicabilityProvidesIntermediateResult(
        account,
        capability,
        missingCredentialId
      );

      var prefixResult : Account :|
        ConcreteTwoEffectPrefixWitness(
          account,
          capability,
          missingCredentialId,
          prefixResult
        );

      EnableCapabilityPrefixResultIsAddCapability(
        account,
        capability,
        prefixResult
      );

      assert prefixResult
             ==
             AddCapability(
               account,
               capability
             );

      AddCapabilityCannotIntroduceMissingCredential(
        account,
        capability,
        missingCredentialId
      );

      assert !PolicyEffectIsApplicable(
          AccountAuthorizationState(prefixResult),
          RevokeCredential(
            missingCredentialId
          )
        );

      assert false;
    }
  }


  // ==========================================================
  // STRUCTURAL POLICY VALIDITY
  // ==========================================================

  lemma StructurallyValidPolicyCanBeRejectedForInapplicability(
    account: Account,
    policy: Policy,
    consumption: PolicyConsumption,
    capability: Capability,
    missingCredentialId: Id
  )
    requires ValidAccount(account)
    requires ValidCapability(capability)
    requires ValidId(missingCredentialId)

    requires !CredentialIdRecognizedInState(
               AccountAuthorizationState(account),
               missingCredentialId
             )

    requires PolicyEffects(policy)
             ==
             [
               EnableCapability(
                 capability,
                 NoScope
               ),
               RevokeCredential(
                 missingCredentialId
               )
             ]

    requires consumption
             ==
             PolicyConsumption(policy)

    requires ValidPolicyConsumption(
               consumption
             )

    ensures ValidPolicy(policy)

    ensures !PolicyIsApplicableAndConsistent(
              account,
              consumption
            )
  {
    assert ValidPolicy(
        ConsumptionPolicy(
          consumption
        )
      );

    ConcreteTwoEffectPolicyIsRejected(
      account,
      policy,
      consumption,
      capability,
      missingCredentialId
    );
  }


  // ==========================================================
  // REJECTED POLICY PRESERVES ORIGINAL ACCOUNT
  // ==========================================================

  lemma RejectedPolicyPreservesOriginalAccount(
    account: Account,
    consumption: PolicyConsumption
  )
    requires ValidAccount(account)
    requires ValidPolicyConsumption(consumption)

    requires !PolicyIsApplicableAndConsistent(
               account,
               consumption
             )

    ensures PolicyTransitionExists(
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


  // ==========================================================
  // REJECTED POLICY HAS NO ALTERNATIVE RESULT
  // ==========================================================

  lemma RejectedPolicyCannotProduceDistinctResult(
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
    RejectedPolicyHasUniqueResult(
      account,
      consumption,
      result
    );
  }


  // ==========================================================
  // PRIMITIVE PREFIX IS VALID BUT IS NOT A POLICY RESULT
  // ==========================================================

  lemma InapplicablePolicyCannotProduceApplicablePrefixResult(
    account: Account,
    policy: Policy,
    consumption: PolicyConsumption,
    capability: Capability,
    missingCredentialId: Id,
    afterPartial: Account
  )
    requires ValidAccount(account)
    requires ValidCapability(capability)
    requires ValidId(missingCredentialId)

    requires !CredentialIdRecognizedInState(
               AccountAuthorizationState(account),
               missingCredentialId
             )

    requires capability
             !in
             StateCapabilities(
               AccountAuthorizationState(account)
             )

    requires PolicyEffects(policy)
             ==
             [
               EnableCapability(
                 capability,
                 NoScope
               ),
               RevokeCredential(
                 missingCredentialId
               )
             ]

    requires consumption
             ==
             PolicyConsumption(policy)

    requires ValidPolicy(policy)

    requires ValidPolicyConsumption(
               consumption
             )

    requires !PolicyIsApplicableAndConsistent(
               account,
               consumption
             )

    requires afterPartial
             ==
             AddCapability(
               account,
               capability
             )

    ensures !PolicyTransitionExists(
              account,
              consumption,
              afterPartial
            )
  {
    if PolicyTransitionExists(
        account,
        consumption,
        afterPartial
      )
    {
      RejectedPolicyCannotProduceDistinctResult(
        account,
        consumption,
        afterPartial
      );

      assert afterPartial == account;

      assert capability
             in
               StateCapabilities(
                 AccountAuthorizationState(afterPartial)
               );

      assert capability
        !in
        StateCapabilities(
          AccountAuthorizationState(account)
        );

      assert false;
    }
  }


  // ==========================================================
  // COMPLETE ADVERSARIAL WITNESS
  // ==========================================================

  lemma ConcretePolicyAtomicityAttack()
    ensures exists account: Account,
              capability: Capability,
              missingCredentialId: Id,
              policy: Policy,
              consumption: PolicyConsumption,
              afterPartial: Account ::

              ValidAccount(account)

              && ValidCapability(capability)

              && ValidId(missingCredentialId)

              && !CredentialIdRecognizedInState(
                AccountAuthorizationState(account),
                missingCredentialId
              )

              && capability
              !in
              StateCapabilities(
                AccountAuthorizationState(account)
              )

              && PolicyEffects(policy)
                 ==
                 [
                   EnableCapability(
                     capability,
                     NoScope
                   ),
                   RevokeCredential(
                     missingCredentialId
                   )
                 ]

              && ValidPolicy(policy)

              && ValidPolicyConsumption(
                consumption
              )

              && consumption
                 ==
                 PolicyConsumption(policy)

              && !PolicyIsApplicableAndConsistent(
                account,
                consumption
              )

              && afterPartial
                 !=
                 account

              && ValidAccount(afterPartial)

              && capability
                 in
                   StateCapabilities(
                     AccountAuthorizationState(afterPartial)
                   )

              && capability
              !in
              StateCapabilities(
                AccountAuthorizationState(account)
              )

              && !PolicyTransitionExists(
                account,
                consumption,
                afterPartial
              )

              && PolicyTransitionExists(
                account,
                consumption,
                account
              )
  {
    var accountId: Id := [0];
    var identityId: Id := [1];
    var subjectId: Id := [2];
    var missingCredentialIdLocal: Id := [3];
    var capabilityKindName: string := "policy-capability";

    var subject :=
      Subject(
        subjectId
      );

    var identity :=
      Identity(
        identityId,
        subject
      );

    var emptyScope :=
      Scope(
        {}
      );

    var capabilityKind :=
      CapabilityKind(
        capabilityKindName
      );

    var capability :=
      Capability(
        capabilityKind,
        emptyScope
      );

    var state :=
      AuthorizationState(
        {},                // capabilities
        {},                // credentials
        map[],             // credential authorities
        {},                // sessions
        {},                // delegations
        map[],             // delegation provenance
        map[],             // restriction map
        {},                // policy effects
        {}                 // consumed replay keys
      );

    var account :=
      Account(
        accountId,
        identity,
        state
      );

    var firstEffect :=
      EnableCapability(
        capability,
        NoScope
      );

    var secondEffect :=
      RevokeCredential(
        missingCredentialIdLocal
      );

    var policy :=
      Policy(
        [
          firstEffect,
          secondEffect
        ]
      );

    var consumption :=
      PolicyConsumption(
        policy
      );

    var afterPartial :=
      AddCapability(
        account,
        capability
      );

    // --------------------------------------------------------
    // BASELINE VALIDITY
    // --------------------------------------------------------

    assert ValidId(accountId);
    assert ValidId(identityId);
    assert ValidId(subjectId);
    assert ValidId(missingCredentialIdLocal);

    assert ValidSubject(subject);
    assert ValidIdentity(identity);

    assert ValidScope(emptyScope);
    assert ValidCapabilityKind(capabilityKind);
    assert ValidCapability(capability);

    assert ValidAuthorizationState(state);
    assert ValidAccount(account);

    // --------------------------------------------------------
    // POLICY STRUCTURAL VALIDITY
    // --------------------------------------------------------

    assert ValidPolicyEffect(firstEffect);
    assert ValidPolicyEffect(secondEffect);

    assert ValidPolicy(policy);

    assert ValidPolicyConsumption(
        consumption
      );

    assert consumption
           ==
           PolicyConsumption(policy);

    assert ConsumptionPolicy(consumption)
           ==
           policy;

    assert ConsumptionPolicyEffects(consumption)
           ==
           [
             firstEffect,
             secondEffect
           ];

    // --------------------------------------------------------
    // MISSING CREDENTIAL
    // --------------------------------------------------------

    assert !CredentialIdRecognizedInState(
        state,
        missingCredentialIdLocal
      );

    assert !CredentialIdRecognizedInState(
        AccountAuthorizationState(account),
        missingCredentialIdLocal
      );

    // --------------------------------------------------------
    // FIRST EFFECT
    // --------------------------------------------------------

    assert PolicyEffectIsApplicable(
        state,
        firstEffect
      );

    assert PolicyEffectIsApplicable(
        AccountAuthorizationState(account),
        firstEffect
      );

    // --------------------------------------------------------
    // COMPLETE POLICY REJECTION
    // --------------------------------------------------------

    ConcreteTwoEffectPolicyIsRejected(
      account,
      policy,
      consumption,
      capability,
      missingCredentialIdLocal
    );

    assert !PolicyIsApplicableAndConsistent(
        account,
        consumption
      );

    // --------------------------------------------------------
    // PRIMITIVE PREFIX RESULT
    // --------------------------------------------------------

    assert ValidAccount(afterPartial);

    assert capability
           in
             StateCapabilities(
               AccountAuthorizationState(afterPartial)
             );

    assert capability
      !in
      StateCapabilities(
        AccountAuthorizationState(account)
      );

    assert afterPartial != account;

    assert ValidAccount(
        AddCapability(
          account,
          capability
        )
      );

    // --------------------------------------------------------
    // REJECTED POLICY RESULT
    // --------------------------------------------------------

    RejectedPolicyPreservesOriginalAccount(
      account,
      consumption
    );

    assert PolicyTransitionExists(
        account,
        consumption,
        account
      );

    // --------------------------------------------------------
    // PREFIX RESULT CANNOT BE WHOLE POLICY RESULT
    // --------------------------------------------------------

    InapplicablePolicyCannotProduceApplicablePrefixResult(
      account,
      policy,
      consumption,
      capability,
      missingCredentialIdLocal,
      afterPartial
    );

    assert !PolicyTransitionExists(
        account,
        consumption,
        afterPartial
      );

    // --------------------------------------------------------
    // COMPLETE WITNESS
    // --------------------------------------------------------

    assert exists accountWitness: Account,
        capabilityWitness: Capability,
        missingCredentialWitness: Id,
        policyWitness: Policy,
        consumptionWitness: PolicyConsumption,
        afterPartialWitness: Account ::

        ValidAccount(accountWitness)

        && ValidCapability(capabilityWitness)

        && ValidId(missingCredentialWitness)

        && !CredentialIdRecognizedInState(
          AccountAuthorizationState(accountWitness),
          missingCredentialWitness
        )

        && capabilityWitness
        !in
        StateCapabilities(
          AccountAuthorizationState(accountWitness)
        )

        && PolicyEffects(policyWitness)
           ==
           [
             EnableCapability(
               capabilityWitness,
               NoScope
             ),
             RevokeCredential(
               missingCredentialWitness
             )
           ]

        && ValidPolicy(policyWitness)

        && ValidPolicyConsumption(
          consumptionWitness
        )

        && consumptionWitness
           ==
           PolicyConsumption(policyWitness)

        && !PolicyIsApplicableAndConsistent(
          accountWitness,
          consumptionWitness
        )

        && afterPartialWitness
           !=
           accountWitness

        && ValidAccount(afterPartialWitness)

        && capabilityWitness
           in
             StateCapabilities(
               AccountAuthorizationState(
                 afterPartialWitness
               )
             )

        && capabilityWitness
        !in
        StateCapabilities(
          AccountAuthorizationState(
            accountWitness
          )
        )

        && !PolicyTransitionExists(
          accountWitness,
          consumptionWitness,
          afterPartialWitness
        )

        && PolicyTransitionExists(
          accountWitness,
          consumptionWitness,
          accountWitness
        );
  }


  // ============================================================
  // D2 ATOMICITY CONCLUSION
  // ============================================================
  //
  // The primitive Account transition:
  //
  //     AddCapability(account, capability)
  //
  // remains a valid independent state transformation.
  //
  // However, the complete Policy:
  //
  //     [
  //       EnableCapability(capability, NoScope),
  //       RevokeCredential(missingCredentialId)
  //     ]
  //
  // is rejected because the second Effect is not applicable.
  //
  // The authoritative Policy transition therefore preserves the
  // original Account and cannot produce the primitive prefix result.
  //
  // Hence:
  //
  //     primitive transition
  //         !=
  //     complete Policy consumption
  //
  // and:
  //
  //     inapplicable complete Policy
  //         →
  //     original Account preserved
  //         →
  //     partial prefix result rejected
  //
  // The D2 atomicity boundary is formally verified.
  //
  // ============================================================
}

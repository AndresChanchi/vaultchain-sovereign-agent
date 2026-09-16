// ============================================================
// KIPIO ACCOUNT DOMAIN — INJECTED COMPOSITION
// POLICY — POLICY APPLICATION COMPOSITION
// ============================================================
//
// Executable counterpart of the ghost Policy transition relation
// defined in policy/AuthorizationStateTransition.dfy.
//
// The ghost layer expresses Policy consumption as a relational
// transition:
//
//     PolicyTransitionExists(account, consumption, result)
//
// This file provides an executable function:
//
//     ApplyPolicyConsumption(account, consumption): Account
//
// and lemmas establishing that the executable function produces
// the unique result satisfying the ghost relation.
//
// No new Policy semantics are introduced. This is a computable
// counterpart of the already verified ghost relation.
//
// ------------------------------------------------------------
// DETERMINISM
//
// Dafny's Rust backend requires --enforce-determinism, which
// forbids `:|` inside methods without a provably unique witness.
//
// All entity-resolution `:|` statements in this file live inside
// *functions* whose witness is uniquely determined by
// ValidAuthorizationState's entity-ID uniqueness invariants:
//
//     CredentialIdsAreUnique
//     SessionIdsAreUnique
//     DelegationIdsAreUnique
//
// Each `:|` selects the (unique) Entity carrying the given Id.
//
// ============================================================


include "../foundation/DomainPrimitives.dfy"
include "../foundation/Capability.dfy"
include "../foundation/Restriction.dfy"
include "../foundation/Scope.dfy"
include "../foundation/Identity.dfy"

include "../authority/AuthorizationState.dfy"
include "../authority/Credential.dfy"
include "../authority/CredentialAuthority.dfy"
include "../authority/Session.dfy"
include "../authority/Delegation.dfy"

include "../account/Account.dfy"
include "../account/AccountTransitions.dfy"

include "PolicyEffect.dfy"
include "Policy.dfy"
include "PolicyConsumption.dfy"
include "AuthorizationStateTransition.dfy"


module KipioAccountPolicyApplicationComposition {

  import opened KipioAccountDomainPrimitives
  import opened KipioAccountCapability
  import opened KipioAccountRestriction
  import opened KipioAccountScope
  import opened KipioAccountIdentity

  import opened KipioAccountAuthorizationState
  import opened KipioAccountCredential
  import opened KipioAccountCredentialAuthority
  import opened KipioAccountSession
  import opened KipioAccountDelegation

  import opened KipioAccountAccount
  import opened KipioAccountAccountTransitions

  import opened KipioAccountPolicyEffect
  import opened KipioAccountPolicy
  import opened KipioAccountPolicyConsumption
  import opened KipioAccountAuthorizationStateTransition


  // ==========================================================
  // UNIQUENESS OF ENTITY BY ID
  // ==========================================================

  lemma UniqueCredentialByIdInState(
    state: AuthorizationState,
    credentialId: Id
  )
    requires ValidAuthorizationState(state)
    ensures forall c1, c2 ::
      c1 in StateCredentials(state)
      && CredentialId(c1) == credentialId
      && c2 in StateCredentials(state)
      && CredentialId(c2) == credentialId
      ==> c1 == c2
  {
    forall c1, c2
      | c1 in StateCredentials(state)
      && CredentialId(c1) == credentialId
      && c2 in StateCredentials(state)
      && CredentialId(c2) == credentialId
      ensures c1 == c2
    {
      if c1 != c2 {
        assert CredentialIdsAreUnique(state);
      }
    }
  }


  lemma UniqueSessionByIdInState(
    state: AuthorizationState,
    sessionId: Id
  )
    requires ValidAuthorizationState(state)
    ensures forall s1, s2 ::
      s1 in StateSessions(state)
      && SessionId(s1) == sessionId
      && s2 in StateSessions(state)
      && SessionId(s2) == sessionId
      ==> s1 == s2
  {
    forall s1, s2
      | s1 in StateSessions(state)
      && SessionId(s1) == sessionId
      && s2 in StateSessions(state)
      && SessionId(s2) == sessionId
      ensures s1 == s2
    {
      if s1 != s2 {
        assert SessionIdsAreUnique(state);
      }
    }
  }


  lemma UniqueDelegationByIdInState(
    state: AuthorizationState,
    delegationId: Id
  )
    requires ValidAuthorizationState(state)
    ensures forall d1, d2 ::
      d1 in StateDelegations(state)
      && DelegationId(d1) == delegationId
      && d2 in StateDelegations(state)
      && DelegationId(d2) == delegationId
      ==> d1 == d2
  {
    forall d1, d2
      | d1 in StateDelegations(state)
      && DelegationId(d1) == delegationId
      && d2 in StateDelegations(state)
      && DelegationId(d2) == delegationId
      ensures d1 == d2
    {
      if d1 != d2 {
        assert DelegationIdsAreUnique(state);
      }
    }
  }


  // ==========================================================
  // FIND ENTITY BY ID
  // ==========================================================

  function FindCredentialById(
    state: AuthorizationState,
    credentialId: Id
  ): (result: Credential)
    requires ValidAuthorizationState(state)
    requires CredentialIdRecognizedInState(state, credentialId)
    ensures result in StateCredentials(state)
    ensures CredentialId(result) == credentialId
  {
    UniqueCredentialByIdInState(state, credentialId);
    var c :| c in StateCredentials(state)
         && CredentialId(c) == credentialId;
    c
  }


  function FindSessionById(
    state: AuthorizationState,
    sessionId: Id
  ): (result: Session)
    requires ValidAuthorizationState(state)
    requires SessionIdRecognizedInState(state, sessionId)
    ensures result in StateSessions(state)
    ensures SessionId(result) == sessionId
  {
    UniqueSessionByIdInState(state, sessionId);
    var s :| s in StateSessions(state)
         && SessionId(s) == sessionId;
    s
  }


  function FindDelegationById(
    state: AuthorizationState,
    delegationId: Id
  ): (result: Delegation)
    requires ValidAuthorizationState(state)
    requires DelegationIdRecognizedInState(state, delegationId)
    ensures result in StateDelegations(state)
    ensures DelegationId(result) == delegationId
  {
    UniqueDelegationByIdInState(state, delegationId);
    var d :| d in StateDelegations(state)
         && DelegationId(d) == delegationId;
    d
  }


  // ==========================================================
  // REVOKE STATUS IS ALWAYS A VALID TARGET STATUS
  // ==========================================================

  lemma CredentialRevokeIsAlwaysValid(c: Credential)
    ensures ValidCredentialStatusTransition(c, CredentialStatus.Revoked)
  {
    match c.status
    case Active    => assert CredentialIsActive(c);
    case Suspended => assert CredentialIsSuspended(c);
    case Revoked   => assert CredentialIsRevoked(c);
  }


  lemma SessionRevokeIsAlwaysValid(s: Session)
    ensures ValidSessionStatusTransition(s, SessionStatus.Revoked)
  {
    match s.status
    case Active  => assert SessionIsActive(s);
    case Revoked => assert SessionIsRevoked(s);
  }


  lemma DelegationRevokeIsAlwaysValid(d: Delegation)
    ensures ValidDelegationStatusTransition(d, DelegationStatus.Revoked)
  {
    match d.status
    case Active  => assert DelegationIsActive(d);
    case Revoked => assert DelegationIsRevoked(d);
  }


  // ==========================================================
  // EXECUTABLE WELL-FORMEDNESS OF A SINGLE EFFECT
  // ==========================================================

  predicate PolicyEffectTransitionIsWellFormedExec(
    account: Account,
    effect: PolicyEffect
  )
  {
    ValidAccount(account)
    &&
    PolicyEffectIsConsistent(effect)
    &&
    PolicyEffectIsApplicable(
      AccountAuthorizationState(account),
      effect
    )
  }


  lemma PolicyEffectTransitionIsWellFormedExecMatchesGhost(
    account: Account,
    effect: PolicyEffect
  )
    ensures
      PolicyEffectTransitionIsWellFormedExec(account, effect)
      <==>
      PolicyEffectTransitionIsWellFormed(account, effect)
  {
  }


  // ==========================================================
  // APPLY A SINGLE EFFECT
  // ==========================================================
  //
  // Executable counterpart of PolicyEffectTransitionExists for
  // the unique successful result.

  function ApplyPolicyEffect(
    account: Account,
    effect: PolicyEffect
  ): (result: Account)
    requires PolicyEffectTransitionIsWellFormedExec(account, effect)
    ensures ValidAccount(result)
  {
    match effect

    case RevokeCredential(credentialId) =>
      var state := AccountAuthorizationState(account);
      var credential := FindCredentialById(state, credentialId);
      CredentialRevokeIsAlwaysValid(credential);
      UpdateCredentialStatusPreservesAccountValidity(
        account, credential, CredentialStatus.Revoked
      );
      UpdateCredentialStatus(account, credential, CredentialStatus.Revoked)

    case RevokeSession(sessionId) =>
      var state := AccountAuthorizationState(account);
      var session := FindSessionById(state, sessionId);
      SessionRevokeIsAlwaysValid(session);
      UpdateSessionStatusPreservesAccountValidity(
        account, session, SessionStatus.Revoked
      );
      UpdateSessionStatus(account, session, SessionStatus.Revoked)

    case RevokeDelegation(delegationId) =>
      var state := AccountAuthorizationState(account);
      var delegation := FindDelegationById(state, delegationId);
      DelegationRevokeIsAlwaysValid(delegation);
      UpdateDelegationStatusPreservesAccountValidity(
        account, delegation, DelegationStatus.Revoked
      );
      UpdateDelegationStatus(account, delegation, DelegationStatus.Revoked)

    case DisableCapability(capability, scope) =>
      RemoveCapabilityPreservesAccountValidity(account, capability);
      RemoveCapability(account, capability)

    case EnableCapability(capability, scope) =>
      AddCapabilityPreservesAccountValidity(account, capability);
      AddCapability(account, capability)

    case ModifyRestriction(capability, scope, restriction) =>
      SetRestrictionPreservesAccountValidity(
        account, capability, scope, restriction
      );
      SetRestriction(account, capability, scope, restriction)
  }


  // ==========================================================
  // APPLY EFFECT OR IDENTITY (TOTAL FALLBACK)
  // ==========================================================

  function ApplyPolicyEffectOrIdentity(
    account: Account,
    effect: PolicyEffect
  ): (result: Account)
    requires ValidAccount(account)
    ensures ValidAccount(result)
  {
    if PolicyEffectTransitionIsWellFormedExec(account, effect)
    then ApplyPolicyEffect(account, effect)
    else account
  }


  // ==========================================================
  // APPLY A POLICY SEQUENCE
  // ==========================================================

  function ApplyPolicySequence(
    account: Account,
    effects: seq<PolicyEffect>
  ): (result: Account)
    requires ValidAccount(account)
    ensures ValidAccount(result)
    decreases |effects|
  {
    if |effects| == 0 then account
    else
      var prefixResult := ApplyPolicySequence(
        account,
        effects[..|effects|-1]
      );
      ApplyPolicyEffectOrIdentity(
        prefixResult,
        effects[|effects|-1]
      )
  }


  // ==========================================================
  // EXECUTABLE PREFIX APPLICABILITY
  // ==========================================================

  function PolicyPrefixIsApplicableExec(
    account: Account,
    effects: seq<PolicyEffect>
  ): bool
    requires ValidAccount(account)
    decreases |effects|
  {
    if |effects| == 0 then true
    else
      var prefixAccount := ApplyPolicySequence(
        account,
        effects[..|effects|-1]
      );
      PolicyPrefixIsApplicableExec(
        account,
        effects[..|effects|-1]
      )
      &&
      PolicyEffectIsApplicable(
        AccountAuthorizationState(prefixAccount),
        effects[|effects|-1]
      )
  }


  // ==========================================================
  // EXECUTABLE POLICY APPLICABILITY & CONSISTENCY
  // ==========================================================

  predicate PolicyIsApplicableAndConsistentExec(
    account: Account,
    consumption: PolicyConsumption
  )
  {
    ValidAccount(account)
    &&
    ValidPolicyConsumption(consumption)
    &&
    PolicyContainsOnlyValidEffects(
      ConsumptionPolicy(consumption)
    )
    &&
    !PolicyContainsContradiction(
      ConsumptionPolicy(consumption)
    )
    &&
    PolicyPrefixIsApplicableExec(
      account,
      ConsumptionPolicyEffects(consumption)
    )
  }


  // ==========================================================
  // APPLY A POLICY CONSUMPTION
  // ==========================================================
  //
  // Composed executable entrypoint. This is the counterpart of
  // the ghost predicate PolicyTransitionExists.

  function ApplyPolicyConsumption(
    account: Account,
    consumption: PolicyConsumption
  ): (result: Account)
    requires ValidAccount(account)
    ensures ValidAccount(result)
  {
    if PolicyIsApplicableAndConsistentExec(account, consumption)
    then ApplyPolicySequence(
      account,
      ConsumptionPolicyEffects(consumption)
    )
    else account
  }


  // ==========================================================
  // LEMMA — SINGLE EFFECT MATCHES GHOST
  // ==========================================================

  lemma ApplyPolicyEffectMatchesGhost(
    account: Account,
    effect: PolicyEffect
  )
    requires PolicyEffectTransitionIsWellFormedExec(account, effect)
    ensures PolicyEffectTransitionExists(
      account,
      effect,
      ApplyPolicyEffect(account, effect)
    )
  {
    PolicyEffectTransitionIsWellFormedExecMatchesGhost(account, effect);

    match effect

    case RevokeCredential(credentialId) =>
      var state := AccountAuthorizationState(account);
      var credential := FindCredentialById(state, credentialId);
      assert credential in StateCredentials(state);
      assert CredentialId(credential) == credentialId;
      assert RecognizedCredentialMatchesId(state, credential, credentialId);
      assert ApplyPolicyEffect(account, RevokeCredential(credentialId))
          == UpdateCredentialStatus(
               account, credential, CredentialStatus.Revoked
             );

    case RevokeSession(sessionId) =>
      var state := AccountAuthorizationState(account);
      var session := FindSessionById(state, sessionId);
      assert session in StateSessions(state);
      assert SessionId(session) == sessionId;
      assert RecognizedSessionMatchesId(state, session, sessionId);
      assert ApplyPolicyEffect(account, RevokeSession(sessionId))
          == UpdateSessionStatus(
               account, session, SessionStatus.Revoked
             );

    case RevokeDelegation(delegationId) =>
      var state := AccountAuthorizationState(account);
      var delegation := FindDelegationById(state, delegationId);
      assert delegation in StateDelegations(state);
      assert DelegationId(delegation) == delegationId;
      assert RecognizedDelegationMatchesId(state, delegation, delegationId);
      assert ApplyPolicyEffect(account, RevokeDelegation(delegationId))
          == UpdateDelegationStatus(
               account, delegation, DelegationStatus.Revoked
             );

    case DisableCapability(capability, scope) =>
      assert ApplyPolicyEffect(account, DisableCapability(capability, scope))
          == RemoveCapability(account, capability);

    case EnableCapability(capability, scope) =>
      assert ApplyPolicyEffect(account, EnableCapability(capability, scope))
          == AddCapability(account, capability);

    case ModifyRestriction(capability, scope, restriction) =>
      assert ApplyPolicyEffect(
               account, ModifyRestriction(capability, scope, restriction)
             )
          == SetRestriction(account, capability, scope, restriction);
  }


  // ==========================================================
  // LEMMA — SEQUENCE MATCHES GHOST
  // ==========================================================

  lemma ApplyPolicySequenceMatchesGhost(
    account: Account,
    effects: seq<PolicyEffect>
  )
    requires ValidAccount(account)
    requires PolicyPrefixIsApplicableExec(account, effects)
    requires forall i :: 0 <= i < |effects|
                   ==> ValidPolicyEffect(effects[i])
    ensures PolicyPrefixTransitionExists(
      account,
      effects,
      ApplyPolicySequence(account, effects)
    )
    decreases |effects|
  {
    if |effects| == 0 {
      assert ApplyPolicySequence(account, effects) == account;
      assert PolicyPrefixTransitionExists(account, effects, account);
    } else {
      var lastEffect := effects[|effects|-1];
      var prefixEffects := effects[..|effects|-1];

      ApplyPolicySequenceMatchesGhost(account, prefixEffects);

      var prefixResult := ApplyPolicySequence(account, prefixEffects);
      assert PolicyPrefixTransitionExists(account, prefixEffects, prefixResult);
      assert ValidAccount(prefixResult);

      assert PolicyPrefixIsApplicableExec(account, effects);

      assert PolicyEffectIsApplicable(
        AccountAuthorizationState(prefixResult),
        lastEffect
      );
      assert PolicyEffectTransitionIsWellFormedExec(prefixResult, lastEffect);

      ApplyPolicyEffectMatchesGhost(prefixResult, lastEffect);
      assert PolicyEffectTransitionExists(
        prefixResult,
        lastEffect,
        ApplyPolicyEffect(prefixResult, lastEffect)
      );

      assert ApplyPolicySequence(account, effects)
          == ApplyPolicyEffect(prefixResult, lastEffect);

      assert PolicyPrefixTransitionExists(
        account,
        effects,
        ApplyPolicySequence(account, effects)
      );
    }
  }


  // ==========================================================
  // LEMMA — PREFIX APPLICABILITY EXEC MATCHES GHOST
  // ==========================================================

  lemma PolicyPrefixIsApplicableExecMatchesGhost(
    account: Account,
    effects: seq<PolicyEffect>
  )
    requires ValidAccount(account)
    requires forall i :: 0 <= i < |effects|
                   ==> ValidPolicyEffect(effects[i])
    ensures
      PolicyPrefixIsApplicableExec(account, effects)
      <==>
      PolicyPrefixIsApplicable(account, effects)
    decreases |effects|
  {
    if |effects| == 0 {
    } else {
      var lastEffect := effects[|effects|-1];
      var prefixEffects := effects[..|effects|-1];

      // Establish the forall precondition for the prefix by projection.
      forall i | 0 <= i < |prefixEffects|
        ensures ValidPolicyEffect(prefixEffects[i])
      {
        assert prefixEffects[i] == effects[i];
      }

      PolicyPrefixIsApplicableExecMatchesGhost(account, prefixEffects);

      if PolicyPrefixIsApplicableExec(account, effects) {
        // Exec says: prefix exec && applicability of lastEffect on
        // ApplyPolicySequence(account, prefixEffects).

        assert PolicyPrefixIsApplicableExec(account, prefixEffects);
        ApplyPolicySequenceMatchesGhost(account, prefixEffects);

        var prefixResult := ApplyPolicySequence(account, prefixEffects);
        assert PolicyPrefixTransitionExists(
          account, prefixEffects, prefixResult
        );
        assert PolicyPrefixIsApplicable(account, prefixEffects);
        assert PolicyEffectIsApplicable(
          AccountAuthorizationState(prefixResult),
          lastEffect
        );

        // Ghost's exists holds with witness = prefixResult.
        assert PolicyPrefixIsApplicable(account, effects);
      }

      if PolicyPrefixIsApplicable(account, effects) {
        // Ghost says: exists a witness.
        var prefixGhost :| PolicyPrefixTransitionExists(
                              account, prefixEffects, prefixGhost
                            )
                            && PolicyPrefixIsApplicable(
                                 account, prefixEffects
                               )
                            && PolicyEffectIsApplicable(
                                 AccountAuthorizationState(prefixGhost),
                                 lastEffect
                               );

        ApplyPolicySequenceMatchesGhost(account, prefixEffects);

        var prefixResult := ApplyPolicySequence(account, prefixEffects);
        assert PolicyPrefixTransitionExists(
          account, prefixEffects, prefixResult
        );
        assert PolicyPrefixTransitionExists(
          account, prefixEffects, prefixGhost
        );

        PolicyPrefixTransitionIsDeterministic(
          account, prefixEffects, prefixResult, prefixGhost
        );
        assert prefixResult == prefixGhost;

        assert PolicyPrefixIsApplicableExec(account, prefixEffects);
        assert PolicyEffectIsApplicable(
          AccountAuthorizationState(prefixResult),
          lastEffect
        );

        assert PolicyPrefixIsApplicableExec(account, effects);
      }
    }
  }


  // ==========================================================
  // LEMMA — POLICY APPLICABILITY EXEC MATCHES GHOST
  // ==========================================================

  lemma PolicyIsApplicableAndConsistentExecMatchesGhost(
    account: Account,
    consumption: PolicyConsumption
  )
    requires ValidAccount(account)
    ensures
      PolicyIsApplicableAndConsistentExec(account, consumption)
      <==>
      PolicyIsApplicableAndConsistent(account, consumption)
  {
    var effects := ConsumptionPolicyEffects(consumption);
    var policy := ConsumptionPolicy(consumption);

    // effects == PolicyEffects(policy) by definition chain:
    //   ConsumptionPolicyEffects(c) == PolicyEffects(ConsumptionPolicy(c))
    //   policy == ConsumptionPolicy(c)
    assert effects == PolicyEffects(policy);

    // --------------------------------------------------
    // Exec ⇒ Ghost
    // --------------------------------------------------
    if PolicyIsApplicableAndConsistentExec(account, consumption) {
      assert PolicyContainsOnlyValidEffects(policy);

      forall i | 0 <= i < |effects|
        ensures ValidPolicyEffect(effects[i])
      {
        assert PolicyEffects(policy)[i] == effects[i];
      }

      PolicyPrefixIsApplicableExecMatchesGhost(account, effects);

      assert PolicyPrefixIsApplicable(account, effects);
      assert PolicyIsApplicableAndConsistent(account, consumption);
    }

    // --------------------------------------------------
    // Ghost ⇒ Exec
    // --------------------------------------------------
    if PolicyIsApplicableAndConsistent(account, consumption) {
      assert PolicyContainsOnlyValidEffects(policy);

      forall i | 0 <= i < |effects|
        ensures ValidPolicyEffect(effects[i])
      {
        assert PolicyEffects(policy)[i] == effects[i];
      }

      PolicyPrefixIsApplicableExecMatchesGhost(account, effects);

      assert PolicyPrefixIsApplicableExec(account, effects);
      assert PolicyIsApplicableAndConsistentExec(account, consumption);
    }
  }


  // ==========================================================
  // CROWN LEMMA — COMPOSED ENTRY MATCHES GHOST
  // ==========================================================

  lemma ApplyPolicyConsumptionMatchesGhost(
    account: Account,
    consumption: PolicyConsumption
  )
    requires ValidAccount(account)
    ensures PolicyTransitionExists(
      account,
      consumption,
      ApplyPolicyConsumption(account, consumption)
    )
  {
    PolicyIsApplicableAndConsistentExecMatchesGhost(account, consumption);

    if PolicyIsApplicableAndConsistentExec(account, consumption) {
      var effects := ConsumptionPolicyEffects(consumption);

      assert PolicyContainsOnlyValidEffects(
        ConsumptionPolicy(consumption)
      );
      assert forall i :: 0 <= i < |effects|
                     ==> ValidPolicyEffect(effects[i]);
      assert PolicyPrefixIsApplicableExec(account, effects);

      ApplyPolicySequenceMatchesGhost(account, effects);

      assert PolicyPrefixTransitionExists(
        account, effects, ApplyPolicySequence(account, effects)
      );
      assert ApplyPolicyConsumption(account, consumption)
          == ApplyPolicySequence(account, effects);
      assert PolicyIsApplicableAndConsistent(account, consumption);
    } else {
      assert ApplyPolicyConsumption(account, consumption) == account;
      assert !PolicyIsApplicableAndConsistent(account, consumption);
    }
  }
}

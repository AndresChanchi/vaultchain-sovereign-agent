// ============================================================
// KIPIO ACCOUNT DOMAIN
// POLICY — AUTHORIZATION STATE TRANSITION
// ============================================================
//
// This module defines how a recognized Policy is translated into
// valid Authorization State transitions.
//
// Architectural boundary:
//
//     PolicyEffect
//         = WHAT semantic change is requested
//
//     AccountTransitions
//         = primitive Account state transitions
//
//     AuthorizationStateTransition
//         = HOW a Policy Effect is translated into valid
//           Account / AuthorizationState state change
//
//     PolicyConsumption
//         = complete ordered Policy consumed atomically
//
// This module does NOT:
//
//   - define Policy identity;
//   - define Policy approval;
//   - define governance;
//   - define Recovery lifecycle;
//   - verify Proof;
//   - perform Authorization Validation;
//   - calculate Effective Authority;
//   - consume Authorization Replay Keys;
//   - execute Domain Actions;
//   - materialize blockchain execution.
//
// ------------------------------------------------------------
//
// D2 RESPONSIBILITY
//
// Policy consumption must satisfy:
//
//     valid + applicable + consistent
//             =>
//         complete Policy applied
//
//     otherwise
//             =>
//         original Account state preserved
//
// Effects remain ordered.
//
// There is no partial Policy consumption.
//
// The formalization below strengthens this contract by proving:
//
//   - each PolicyEffect transition has a unique result;
//   - each ordered Policy prefix has a unique result;
//   - every successful prefix preserves Account validity;
//   - a successful Policy transition corresponds to the complete
//     ordered Effect sequence;
//   - a rejected Policy has exactly the identity result;
//   - the complete Policy transition itself is deterministic.
//
// ------------------------------------------------------------
//
// D5 RESPONSIBILITY
//
// Restriction is a Value Object.
//
// The association between:
//
//     Capability + OptionalPolicyScope
//
// and:
//
//     Restriction
//
// belongs to AuthorizationState.
//
// Therefore ModifyRestriction is a state transition over that
// association. The transition layer must preserve:
//
//   - uniqueness of the Capability/Scope target;
//   - no orphan Restrictions;
//   - replacement semantics;
//   - atomicity;
//   - consistency with Capability recognition.
//
// The concrete D5 state transition is delegated directly to:
//
//     AccountTransitions.SetRestriction
//
// which updates AuthorizationState.RestrictionMap.
//
// ============================================================

include "../foundation/DomainPrimitives.dfy"
include "../foundation/Capability.dfy"
include "../foundation/Restriction.dfy"

include "../authority/AuthorizationState.dfy"
include "../authority/Credential.dfy"
include "../authority/Session.dfy"
include "../authority/Delegation.dfy"

include "../account/Account.dfy"
include "../account/AccountTransitions.dfy"

include "PolicyEffect.dfy"
include "Policy.dfy"
include "PolicyConsumption.dfy"


module KipioAccountAuthorizationStateTransition
{
  import opened KipioAccountDomainPrimitives

  import opened KipioAccountCapability
  import opened KipioAccountRestriction

  import opened KipioAccountAuthorizationState
  import opened KipioAccountCredential
  import opened KipioAccountSession
  import opened KipioAccountDelegation

  import opened KipioAccountAccount
  import opened KipioAccountAccountTransitions

  import opened KipioAccountPolicyEffect
  import opened KipioAccountPolicy
  import opened KipioAccountPolicyConsumption


  // ============================================================
  // EFFECT APPLICABILITY
  // ============================================================

  predicate PolicyEffectIsApplicable(
    state: AuthorizationState,
    effect: PolicyEffect
  )
  {
    match effect

    case RevokeCredential(credentialId) =>
      CredentialIdRecognizedInState(
        state,
        credentialId
      )

    case RevokeSession(sessionId) =>
      SessionIdRecognizedInState(
        state,
        sessionId
      )

    case RevokeDelegation(delegationId) =>
      DelegationIdRecognizedInState(
        state,
        delegationId
      )

    case DisableCapability(capability, scope) =>
      ValidCapability(capability)
      &&
      ValidOptionalPolicyScope(scope)
      &&
      capability in StateCapabilities(state)

    case EnableCapability(capability, scope) =>
      ValidCapability(capability)
      &&
      ValidOptionalPolicyScope(scope)

    case ModifyRestriction(capability, scope, restriction) =>
      ValidCapability(capability)
      &&
      ValidOptionalPolicyScope(scope)
      &&
      ValidRestriction(restriction)
      &&
      capability in StateCapabilities(state)
  }


  // ============================================================
  // EFFECT STRUCTURAL / SEMANTIC VALIDITY
  // ============================================================

  predicate PolicyEffectIsConsistent(
    effect: PolicyEffect
  )
  {
    ValidPolicyEffect(effect)
  }


  // ============================================================
  // RECOGNIZED ENTITY RESOLUTION
  // ============================================================

  predicate RecognizedCredentialMatchesId(
    state: AuthorizationState,
    credential: Credential,
    credentialId: Id
  )
  {
    credential in StateCredentials(state)
    &&
    CredentialId(credential) == credentialId
  }


  predicate RecognizedSessionMatchesId(
    state: AuthorizationState,
    session: Session,
    sessionId: Id
  )
  {
    session in StateSessions(state)
    &&
    SessionId(session) == sessionId
  }


  predicate RecognizedDelegationMatchesId(
    state: AuthorizationState,
    delegation: Delegation,
    delegationId: Id
  )
  {
    delegation in StateDelegations(state)
    &&
    DelegationId(delegation) == delegationId
  }


  // ============================================================
  // POLICY EFFECT APPLICATION — CREDENTIAL
  // ============================================================

  ghost predicate RevokeCredentialTransitionIsWellFormed(
    before: Account,
    credential: Credential,
    credentialId: Id
  )
  {
    ValidAccount(before)
    &&
    RecognizedCredentialMatchesId(
      AccountAuthorizationState(before),
      credential,
      credentialId
    )
    &&
    CredentialId(credential) == credentialId
  }


  // ============================================================
  // POLICY EFFECT APPLICATION — SESSION
  // ============================================================

  ghost predicate RevokeSessionTransitionIsWellFormed(
    before: Account,
    session: Session,
    sessionId: Id
  )
  {
    ValidAccount(before)
    &&
    RecognizedSessionMatchesId(
      AccountAuthorizationState(before),
      session,
      sessionId
    )
    &&
    SessionId(session) == sessionId
  }


  // ============================================================
  // POLICY EFFECT APPLICATION — DELEGATION
  // ============================================================

  ghost predicate RevokeDelegationTransitionIsWellFormed(
    before: Account,
    delegation: Delegation,
    delegationId: Id
  )
  {
    ValidAccount(before)
    &&
    RecognizedDelegationMatchesId(
      AccountAuthorizationState(before),
      delegation,
      delegationId
    )
    &&
    DelegationId(delegation) == delegationId
  }


  // ============================================================
  // CAPABILITY TRANSITION
  // ============================================================

  ghost predicate DisableCapabilityTransitionIsWellFormed(
    before: Account,
    capability: Capability,
    scope: OptionalPolicyScope
  )
  {
    ValidAccount(before)
    &&
    ValidCapability(capability)
    &&
    ValidOptionalPolicyScope(scope)
    &&
    capability in StateCapabilities(
                    AccountAuthorizationState(before)
                  )
  }


  ghost predicate EnableCapabilityTransitionIsWellFormed(
    before: Account,
    capability: Capability,
    scope: OptionalPolicyScope
  )
  {
    ValidAccount(before)
    &&
    ValidCapability(capability)
    &&
    ValidOptionalPolicyScope(scope)
  }


  // ============================================================
  // RESTRICTION TRANSITION
  // ============================================================

  ghost predicate ModifyRestrictionTransitionIsWellFormed(
    before: Account,
    capability: Capability,
    scope: OptionalPolicyScope,
    restriction: Restriction
  )
  {
    ValidAccount(before)
    &&
    ValidCapability(capability)
    &&
    ValidOptionalPolicyScope(scope)
    &&
    ValidRestriction(restriction)
    &&
    capability in StateCapabilities(
                    AccountAuthorizationState(before)
                  )
  }


  // ============================================================
  // POLICY EFFECT TRANSITION BOUNDARY
  // ============================================================

  ghost predicate PolicyEffectTransitionIsWellFormed(
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


  // ============================================================
  // CAPABILITY CONTRADICTION HELPERS
  // ============================================================

  predicate IsEnableCapabilityEffect(
    effect: PolicyEffect,
    capability: Capability,
    scope: OptionalPolicyScope
  )
  {
    match effect

    case EnableCapability(
      candidateCapability,
      candidateScope
      ) =>
      candidateCapability == capability
      &&
      candidateScope == scope

    case _ =>
      false
  }


  predicate IsDisableCapabilityEffect(
    effect: PolicyEffect,
    capability: Capability,
    scope: OptionalPolicyScope
  )
  {
    match effect

    case DisableCapability(
      candidateCapability,
      candidateScope
      ) =>
      candidateCapability == capability
      &&
      candidateScope == scope

    case _ =>
      false
  }


  // ============================================================
  // POLICY CONTRADICTION
  // ============================================================

  predicate ContradictoryPolicyEffects(
    first: PolicyEffect,
    second: PolicyEffect
  )
  {
    match first

    case DisableCapability(capabilityA, scopeA) =>
      IsEnableCapabilityEffect(
        second,
        capabilityA,
        scopeA
      )

    case EnableCapability(capabilityA, scopeA) =>
      IsDisableCapabilityEffect(
        second,
        capabilityA,
        scopeA
      )

    case RevokeCredential(_) =>
      false

    case RevokeSession(_) =>
      false

    case RevokeDelegation(_) =>
      false

    case ModifyRestriction(_, _, _) =>
      false
  }


  predicate PolicyContainsContradiction(
    policy: Policy
  )
  {
    exists i, j ::
      0 <= i < j < |PolicyEffects(policy)|
      &&
      ContradictoryPolicyEffects(
        PolicyEffects(policy)[i],
        PolicyEffects(policy)[j]
      )
  }


  // ============================================================
  // POLICY PREFIX TRANSITION RELATION
  // ============================================================

  ghost predicate PolicyPrefixTransitionExists(
    account: Account,
    effects: seq<PolicyEffect>,
    result: Account
  )
  {
    if |effects| == 0
    then
      result == account
    else
      exists prefixResult : Account
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
        PolicyEffectTransitionExists(
          prefixResult,
          effects[|effects|-1],
          result
        )
  }


  // ============================================================
  // SINGLE EFFECT TRANSITION RELATION
  // ============================================================

  ghost predicate PolicyEffectTransitionExists(
    before: Account,
    effect: PolicyEffect,
    after: Account
  )
  {
    PolicyEffectTransitionIsWellFormed(
      before,
      effect
    )
    &&
    match effect

    case RevokeCredential(credentialId) =>
      exists credential ::
        RecognizedCredentialMatchesId(
          AccountAuthorizationState(before),
          credential,
          credentialId
        )
        &&
        after ==
        UpdateCredentialStatus(
          before,
          credential,
          CredentialStatus.Revoked
        )

    case RevokeSession(sessionId) =>
      exists session ::
        RecognizedSessionMatchesId(
          AccountAuthorizationState(before),
          session,
          sessionId
        )
        &&
        after ==
        UpdateSessionStatus(
          before,
          session,
          SessionStatus.Revoked
        )

    case RevokeDelegation(delegationId) =>
      exists delegation ::
        RecognizedDelegationMatchesId(
          AccountAuthorizationState(before),
          delegation,
          delegationId
        )
        &&
        after ==
        UpdateDelegationStatus(
          before,
          delegation,
          DelegationStatus.Revoked
        )

    case DisableCapability(capability, scope) =>
      after ==
      RemoveCapability(
        before,
        capability
      )

    case EnableCapability(capability, scope) =>
      after ==
      AddCapability(
        before,
        capability
      )

    case ModifyRestriction(capability, scope, restriction) =>
      after ==
      SetRestriction(
        before,
        capability,
        scope,
        restriction
      )
  }


  // ============================================================
  // D5 — DIRECT RESTRICTION TRANSITION
  // ============================================================

  ghost predicate ModifyRestrictionTransitionExists(
    before: Account,
    capability: Capability,
    scope: OptionalPolicyScope,
    restriction: Restriction,
    after: Account
  )
  {
    ModifyRestrictionTransitionIsWellFormed(
      before,
      capability,
      scope,
      restriction
    )
    &&
    after ==
    SetRestriction(
      before,
      capability,
      scope,
      restriction
    )
  }


  // ============================================================
  // POLICY EFFECT DETERMINISM
  // ============================================================

  // A single Policy Effect has at most one Account result.
  //
  // For Entity-based Effects, AuthorizationState entity-ID
  // uniqueness guarantees that two recognized entities carrying
  // the same identifier are the same Entity value.
  //
  // Capability and Restriction effects directly invoke deterministic
  // primitive Account transition functions.

  lemma PolicyEffectTransitionIsDeterministic(
    before: Account,
    effect: PolicyEffect,
    after1: Account,
    after2: Account
  )
    requires
      PolicyEffectTransitionExists(
        before,
        effect,
        after1
      )
    requires
      PolicyEffectTransitionExists(
        before,
        effect,
        after2
      )
    ensures after1 == after2
  {
    match effect

    case RevokeCredential(credentialId) =>
      var state := AccountAuthorizationState(before);

      if after1 != after2 {
        var credential1 : Credential :|
          RecognizedCredentialMatchesId(
            state,
            credential1,
            credentialId
          )
          &&
          after1 ==
          UpdateCredentialStatus(
            before,
            credential1,
            CredentialStatus.Revoked
          );

        var credential2 : Credential :|
          RecognizedCredentialMatchesId(
            state,
            credential2,
            credentialId
          )
          &&
          after2 ==
          UpdateCredentialStatus(
            before,
            credential2,
            CredentialStatus.Revoked
          );

        assert credential1 in StateCredentials(state);
        assert credential2 in StateCredentials(state);
        assert CredentialId(credential1) == credentialId;
        assert CredentialId(credential2) == credentialId;

        if credential1 != credential2 {
          assert CredentialId(credential1) != CredentialId(credential2);
        }

        assert credential1 == credential2;

        assert after1 ==
               UpdateCredentialStatus(
                 before,
                 credential2,
                 CredentialStatus.Revoked
               );
        assert after1 == after2;
      }

    case RevokeSession(sessionId) =>
      var state := AccountAuthorizationState(before);

      if after1 != after2 {
        var session1 : Session :|
          RecognizedSessionMatchesId(
            state,
            session1,
            sessionId
          )
          &&
          after1 ==
          UpdateSessionStatus(
            before,
            session1,
            SessionStatus.Revoked
          );

        var session2 : Session :|
          RecognizedSessionMatchesId(
            state,
            session2,
            sessionId
          )
          &&
          after2 ==
          UpdateSessionStatus(
            before,
            session2,
            SessionStatus.Revoked
          );

        assert session1 in StateSessions(state);
        assert session2 in StateSessions(state);
        assert SessionId(session1) == sessionId;
        assert SessionId(session2) == sessionId;

        if session1 != session2 {
          assert SessionId(session1) != SessionId(session2);
        }

        assert session1 == session2;

        assert after1 ==
               UpdateSessionStatus(
                 before,
                 session2,
                 SessionStatus.Revoked
               );
        assert after1 == after2;
      }

    case RevokeDelegation(delegationId) =>
      var state := AccountAuthorizationState(before);

      if after1 != after2 {
        var delegation1 : Delegation :|
          RecognizedDelegationMatchesId(
            state,
            delegation1,
            delegationId
          )
          &&
          after1 ==
          UpdateDelegationStatus(
            before,
            delegation1,
            DelegationStatus.Revoked
          );

        var delegation2 : Delegation :|
          RecognizedDelegationMatchesId(
            state,
            delegation2,
            delegationId
          )
          &&
          after2 ==
          UpdateDelegationStatus(
            before,
            delegation2,
            DelegationStatus.Revoked
          );

        assert delegation1 in StateDelegations(state);
        assert delegation2 in StateDelegations(state);
        assert DelegationId(delegation1) == delegationId;
        assert DelegationId(delegation2) == delegationId;

        if delegation1 != delegation2 {
          assert DelegationId(delegation1)
              != DelegationId(delegation2);
        }

        assert delegation1 == delegation2;

        assert after1 ==
               UpdateDelegationStatus(
                 before,
                 delegation2,
                 DelegationStatus.Revoked
               );
        assert after1 == after2;
      }

    case DisableCapability(capability, scope) =>
      assert after1 == RemoveCapability(before, capability);
      assert after2 == RemoveCapability(before, capability);
      assert after1 == after2;

    case EnableCapability(capability, scope) =>
      assert after1 == AddCapability(before, capability);
      assert after2 == AddCapability(before, capability);
      assert after1 == after2;

    case ModifyRestriction(capability, scope, restriction) =>
      assert after1 ==
             SetRestriction(
               before,
               capability,
               scope,
               restriction
             );
      assert after2 ==
             SetRestriction(
               before,
               capability,
               scope,
               restriction
             );
      assert after1 == after2;
  }


  // ============================================================
  // POLICY EFFECT VALIDITY PRESERVATION
  // ============================================================

  // Every concrete PolicyEffect transition preserves Account
  // validity because each primitive transition already provides
  // the corresponding preservation theorem.

  lemma PolicyEffectTransitionPreservesAccountValidity(
    before: Account,
    effect: PolicyEffect,
    after: Account
  )
    requires
      PolicyEffectTransitionExists(
        before,
        effect,
        after
      )
    ensures ValidAccount(after)
  {
    match effect

    case RevokeCredential(credentialId) =>
      assert exists credential ::
          RecognizedCredentialMatchesId(
            AccountAuthorizationState(before),
            credential,
            credentialId
          )
          &&
          after ==
          UpdateCredentialStatus(
            before,
            credential,
            CredentialStatus.Revoked
          );

      assert exists credential ::
          credential in StateCredentials(
                          AccountAuthorizationState(before)
                        )
          &&
          CredentialId(credential) == credentialId
          &&
          after ==
          UpdateCredentialStatus(
            before,
            credential,
            CredentialStatus.Revoked
          );

    case RevokeSession(sessionId) =>
      assert exists session ::
          RecognizedSessionMatchesId(
            AccountAuthorizationState(before),
            session,
            sessionId
          )
          &&
          after ==
          UpdateSessionStatus(
            before,
            session,
            SessionStatus.Revoked
          );

    case RevokeDelegation(delegationId) =>
      assert exists delegation ::
          RecognizedDelegationMatchesId(
            AccountAuthorizationState(before),
            delegation,
            delegationId
          )
          &&
          after ==
          UpdateDelegationStatus(
            before,
            delegation,
            DelegationStatus.Revoked
          );

    case DisableCapability(capability, scope) =>
      assert after == RemoveCapability(
                        before,
                        capability
                      );

      RemoveCapabilityPreservesAccountValidity(
        before,
        capability
      );

    case EnableCapability(capability, scope) =>
      assert after == AddCapability(
                        before,
                        capability
                      );

      AddCapabilityPreservesAccountValidity(
        before,
        capability
      );

    case ModifyRestriction(capability, scope, restriction) =>
      assert after ==
             SetRestriction(
               before,
               capability,
               scope,
               restriction
             );

      SetRestrictionPreservesAccountValidity(
        before,
        capability,
        scope,
        restriction
      );
  }


  // ============================================================
  // POLICY EFFECT IDENTITY PRESERVATION
  // ============================================================

  lemma PolicyEffectTransitionPreservesAccountIdentity(
    before: Account,
    effect: PolicyEffect,
    after: Account
  )
    requires
      PolicyEffectTransitionExists(
        before,
        effect,
        after
      )
    ensures
      AccountTransitionPreservesIdentity(
        before,
        after
      )
  {
    match effect

    case RevokeCredential(credentialId) =>
      var credential : Credential :|
        RecognizedCredentialMatchesId(
          AccountAuthorizationState(before),
          credential,
          credentialId
        )
        &&
        after ==
        UpdateCredentialStatus(
          before,
          credential,
          CredentialStatus.Revoked
        );

      UpdateCredentialStatusPreservesIdentity(
        before,
        credential,
        CredentialStatus.Revoked
      );

    case RevokeSession(sessionId) =>
      var session : Session :|
        RecognizedSessionMatchesId(
          AccountAuthorizationState(before),
          session,
          sessionId
        )
        &&
        after ==
        UpdateSessionStatus(
          before,
          session,
          SessionStatus.Revoked
        );

      UpdateSessionStatusPreservesIdentity(
        before,
        session,
        SessionStatus.Revoked
      );

    case RevokeDelegation(delegationId) =>
      var delegation : Delegation :|
        RecognizedDelegationMatchesId(
          AccountAuthorizationState(before),
          delegation,
          delegationId
        )
        &&
        after ==
        UpdateDelegationStatus(
          before,
          delegation,
          DelegationStatus.Revoked
        );

      UpdateDelegationStatusPreservesIdentity(
        before,
        delegation,
        DelegationStatus.Revoked
      );

    case DisableCapability(capability, scope) =>
      RemoveCapabilityPreservesIdentity(
        before,
        capability
      );

    case EnableCapability(capability, scope) =>
      AddCapabilityPreservesIdentity(
        before,
        capability
      );

    case ModifyRestriction(capability, scope, restriction) =>
      SetRestrictionPreservesIdentity(
        before,
        capability,
        scope,
        restriction
      );
  }


  // ============================================================
  // POLICY EFFECT COMPOSITION — VALIDITY
  // ============================================================

  lemma PolicyPrefixTransitionPreservesAccountValidity(
    account: Account,
    effects: seq<PolicyEffect>,
    result: Account
  )
    requires
      ValidAccount(account)
    requires
      PolicyPrefixTransitionExists(
        account,
        effects,
        result
      )
    ensures ValidAccount(result)
    decreases |effects|
  {
    if |effects| == 0 {
      assert result == account;
    }
    else {
      var prefixResult : Account :|
        PolicyPrefixTransitionExists(
          account,
          effects[..|effects|-1],
          prefixResult
        )
        &&
        PolicyEffectTransitionExists(
          prefixResult,
          effects[|effects|-1],
          result
        );

      PolicyPrefixTransitionPreservesAccountValidity(
        account,
        effects[..|effects|-1],
        prefixResult
      );

      PolicyEffectTransitionPreservesAccountValidity(
        prefixResult,
        effects[|effects|-1],
        result
      );
    }
  }


  // ============================================================
  // POLICY PREFIX IDENTITY PRESERVATION
  // ============================================================

  lemma PolicyPrefixTransitionPreservesIdentity(
    account: Account,
    effects: seq<PolicyEffect>,
    result: Account
  )
    requires
      ValidAccount(account)
    requires
      PolicyPrefixTransitionExists(
        account,
        effects,
        result
      )
    ensures
      AccountTransitionPreservesIdentity(
        account,
        result
      )
    decreases |effects|
  {
    if |effects| == 0 {
      assert result == account;
    }
    else {
      var candidate : Account :|
        PolicyPrefixTransitionExists(
          account,
          effects[..|effects|-1],
          candidate
        )
        &&
        PolicyEffectTransitionExists(
          candidate,
          effects[|effects|-1],
          result
        );

      PolicyPrefixTransitionPreservesIdentity(
        account,
        effects[..|effects|-1],
        candidate
      );

      PolicyEffectTransitionPreservesAccountIdentity(
        candidate,
        effects[|effects|-1],
        result
      );

      assert AccountIdOf(account)
          == AccountIdOf(candidate);

      assert AccountSovereignIdentity(account)
          == AccountSovereignIdentity(candidate);

      assert AccountIdOf(candidate)
          == AccountIdOf(result);

      assert AccountSovereignIdentity(candidate)
          == AccountSovereignIdentity(result);

      assert AccountIdOf(account)
          == AccountIdOf(result);

      assert AccountSovereignIdentity(account)
          == AccountSovereignIdentity(result);

      assert
        AccountTransitionPreservesIdentity(
          account,
          result
        );
    }
  }


  // ============================================================
  // POLICY PREFIX DETERMINISM
  // ============================================================

  // An ordered Policy prefix has at most one semantic Account result.
  //
  // This is the mathematical property that turns the relational
  // prefix transition description into a functional semantic
  // transformation without introducing a second resolver.

  lemma PolicyPrefixTransitionIsDeterministic(
    account: Account,
    effects: seq<PolicyEffect>,
    result1: Account,
    result2: Account
  )
    requires
      PolicyPrefixTransitionExists(
        account,
        effects,
        result1
      )
    requires
      PolicyPrefixTransitionExists(
        account,
        effects,
        result2
      )
    ensures result1 == result2
    decreases |effects|
  {
    if |effects| == 0 {
      assert result1 == account;
      assert result2 == account;
      assert result1 == result2;
    }
    else {
      var prefixResult1 : Account :|
        PolicyPrefixTransitionExists(
          account,
          effects[..|effects|-1],
          prefixResult1
        )
        &&
        PolicyEffectTransitionExists(
          prefixResult1,
          effects[|effects|-1],
          result1
        );

      var prefixResult2 : Account :|
        PolicyPrefixTransitionExists(
          account,
          effects[..|effects|-1],
          prefixResult2
        )
        &&
        PolicyEffectTransitionExists(
          prefixResult2,
          effects[|effects|-1],
          result2
        );

      PolicyPrefixTransitionIsDeterministic(
        account,
        effects[..|effects|-1],
        prefixResult1,
        prefixResult2
      );

      assert prefixResult1 == prefixResult2;

      PolicyEffectTransitionIsDeterministic(
        prefixResult1,
        effects[|effects|-1],
        result1,
        result2
      );

      assert result1 == result2;
    }
  }


  // ============================================================
  // POLICY EFFECT ORDERED VALIDATION
  // ============================================================

  ghost predicate PolicyPrefixIsApplicable(
    account: Account,
    effects: seq<PolicyEffect>
  )
  {
    if |effects| == 0
    then
      true
    else
      exists prefixAccount
        {:trigger PolicyPrefixTransitionExists(
          account,
          effects[..|effects|-1],
          prefixAccount
        )} ::
        PolicyPrefixTransitionExists(
          account,
          effects[..|effects|-1],
          prefixAccount
        )
        &&
        PolicyPrefixIsApplicable(
          account,
          effects[..|effects|-1]
        )
        &&
        PolicyEffectIsApplicable(
          AccountAuthorizationState(prefixAccount),
          effects[|effects|-1]
        )
  }


  // ============================================================
  // PREFIX APPLICABILITY / VALIDITY BRIDGE
  // ============================================================

  // If a Policy prefix is applicable from a valid Account, every
  // transition witness used by that applicability proof corresponds
  // to a valid intermediate Account.

  lemma ApplicablePolicyPrefixHasValidResult(
    account: Account,
    effects: seq<PolicyEffect>,
    result: Account
  )
    requires
      ValidAccount(account)
    requires
      PolicyPrefixTransitionExists(
        account,
        effects,
        result
      )
    requires
      PolicyPrefixIsApplicable(
        account,
        effects
      )
    ensures ValidAccount(result)
  {
    PolicyPrefixTransitionPreservesAccountValidity(
      account,
      effects,
      result
    );
  }


  // ============================================================
  // COMPLETE POLICY VALIDATION
  // ============================================================

  ghost predicate PolicyIsApplicableAndConsistent(
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
    PolicyPrefixIsApplicable(
      account,
      ConsumptionPolicyEffects(consumption)
    )
  }


  // ============================================================
  // ATOMIC POLICY TRANSITION
  // ============================================================

  ghost predicate PolicyTransitionExists(
    account: Account,
    consumption: PolicyConsumption,
    result: Account
  )
  {
    if PolicyIsApplicableAndConsistent(
         account,
         consumption
       )
    then
      PolicyPrefixTransitionExists(
        account,
        ConsumptionPolicyEffects(consumption),
        result
      )
    else
      result == account
  }


  // ============================================================
  // COMPLETE POLICY RESULT
  // ============================================================

  // A successful Policy transition is exactly a transition over the
  // complete ordered Effect sequence represented by the Policy.
  //
  // There is no alternative shorter sequence at this semantic
  // boundary.

  lemma SuccessfulPolicyTransitionIsCompleteOrderedTransition(
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
  }


  // ============================================================
  // ATOMICITY — REJECTION
  // ============================================================

  lemma RejectedPolicyLeavesAccountUnchanged(
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
  }


  // A rejected Policy has exactly one possible semantic result.

  lemma RejectedPolicyHasUniqueResult(
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
  }


  // ============================================================
  // ATOMICITY — SUCCESS
  // ============================================================

  // A successful Policy transition preserves Account validity.

  lemma SuccessfulPolicyTransitionPreservesAccountValidity(
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
    SuccessfulPolicyTransitionIsCompleteOrderedTransition(
      before,
      consumption,
      after
    );

    PolicyPrefixTransitionPreservesAccountValidity(
      before,
      ConsumptionPolicyEffects(consumption),
      after
    );
  }


  // A successful Policy transition preserves Account identity.

  lemma SuccessfulPolicyTransitionPreservesIdentity(
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
    ensures
      AccountTransitionPreservesIdentity(
        before,
        after
      )
  {
    SuccessfulPolicyTransitionIsCompleteOrderedTransition(
      before,
      consumption,
      after
    );

    PolicyPrefixTransitionPreservesIdentity(
      before,
      ConsumptionPolicyEffects(consumption),
      after
    );
  }


  // ============================================================
  // ATOMICITY — UNIQUE SUCCESS RESULT
  // ============================================================

  // A successful Policy has exactly one semantic result.
  //
  // This is the key determinism property required for a relational
  // transition specification.

  lemma SuccessfulPolicyTransitionHasUniqueResult(
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
    SuccessfulPolicyTransitionIsCompleteOrderedTransition(
      before,
      consumption,
      result1
    );

    SuccessfulPolicyTransitionIsCompleteOrderedTransition(
      before,
      consumption,
      result2
    );

    PolicyPrefixTransitionIsDeterministic(
      before,
      ConsumptionPolicyEffects(consumption),
      result1,
      result2
    );
  }


  // ============================================================
  // GLOBAL POLICY TRANSITION DETERMINISM
  // ============================================================

  // Every Policy transition is deterministic:
  //
  //     same before
  //     +
  //     same PolicyConsumption
  //     =>
  //     same semantic result.
  //
  // In the rejection branch both results are the identity result.
  //
  // In the success branch the ordered prefix relation is
  // deterministic.

  lemma PolicyTransitionIsDeterministic(
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
    if PolicyIsApplicableAndConsistent(
        before,
        consumption
      )
    {
      SuccessfulPolicyTransitionHasUniqueResult(
        before,
        consumption,
        result1,
        result2
      );
    }
    else
    {
      assert result1 == before;
      assert result2 == before;
      assert result1 == result2;
    }
  }


  // ============================================================
  // EMPTY POLICY
  // ============================================================

  lemma EmptyPolicyLeavesAccountUnchanged(
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
  }


  // ============================================================
  // POLICY ORDER
  // ============================================================

  lemma PolicyPrefixTransitionPreservesOrder(
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
      exists prefixResult ::
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
  }


  // ============================================================
  // COMPLETE SUCCESS BOUNDARY
  // ============================================================

  // A successful Policy transition cannot semantically terminate
  // at a proper prefix because PolicyTransitionExists for the
  // successful branch is defined over the complete Policy Effect
  // sequence.
  //
  // The existence of intermediate prefix states is proof structure
  // only; those states are not alternative successful Policy
  // consumption results.

  lemma SuccessfulPolicyDoesNotRedefinePrefixAsWholePolicy(
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


  // ============================================================
  // ARCHITECTURAL SEPARATION
  // ============================================================

  // Authorization acceptance is intentionally outside Policy
  // state-transition semantics.
  //
  // This transition module operates on an Account and a recognized
  // PolicyConsumption. It does not depend on AuthorizationCanBeAccepted.
  //
  // The dependency is therefore structural:
  //
  //     Authorization Validation
  //            !=
  //     Policy State Transition
  //
  // The semantic transition relation is fully defined without
  // importing authorization-acceptance rules.

  lemma PolicyTransitionUsesOnlyPolicyAndAccountState(
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
  }
}

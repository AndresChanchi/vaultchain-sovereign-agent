// ============================================================
// KIPIO ACCOUNT DOMAIN
// SCENARIO — EIP-7702 / OPERATIONAL STATE VS SOVEREIGN IDENTITY
// ============================================================
//
// Adversarial scenario:
//
//   An Account may change operational Authorization State while
//   remaining the same Account Entity and preserving its Sovereign
//   Identity.
//
// The scenario intentionally does NOT model:
//
//   - EIP-7702 protocol mechanics;
//   - delegation bytecode;
//   - EOAs;
//   - blockchain addresses;
//   - Account Abstraction internals;
//   - cryptographic authorization;
//   - execution.
//
// It attacks only the Account transition boundary:
//
//     operational state may change
//         BUT
//     AccountId must remain stable
//         AND
//     Sovereign Identity must remain stable
//
// Methodology:
//
//   1. Exercise concrete Account transitions.
//   2. Verify operational-state mutation remains inside the same
//      Account Entity.
//   3. Verify Sovereign Identity remains unchanged.
//   4. Attempt an adversarial sovereignty replacement.
//   5. Confirm that such replacement contradicts the transition
//      boundary.
//
// No productive/domain file is modified by this scenario.
//
// ------------------------------------------------------------
//
// DOMAIN INTERPRETATION
//
// The scenario uses "EIP-7702" only as a contextual adversarial
// label for the boundary:
//
//     operational behavior / authorization state
//              !=
//     sovereign Account identity
//
// The formal model does not assert any EIP-7702 protocol property.
//
// The authoritative semantics remain in AccountTransitions.dfy.
//
// Each proof below therefore consumes an actual transition contract
// rather than inventing EIP-7702-specific semantics.
//
// ============================================================


include "../../account/Account.dfy"
include "../../account/AccountTransitions.dfy"

include "../isolated/AccountProofs.dfy"
include "../isolated/FoundationProofs.dfy"

include "../../foundation/DomainPrimitives.dfy"
include "../../foundation/Subject.dfy"
include "../../foundation/Identity.dfy"
include "../../foundation/Capability.dfy"
include "../../foundation/Restriction.dfy"
include "../../foundation/Scope.dfy"

include "../../authority/EffectiveAuthority.dfy"
include "../../authority/AuthorizationState.dfy"
include "../../authority/Credential.dfy"
include "../../authority/CredentialAuthority.dfy"
include "../../authority/Session.dfy"
include "../../authority/Delegation.dfy"

module KipioAccountEIP7702Proof
{
  import opened KipioAccountDomainPrimitives
  import opened KipioAccountSubject
  import opened KipioAccountIdentity
  import opened KipioAccountCapability
  import opened KipioAccountRestriction
  import opened KipioAccountScope

  import opened KipioAccountEffectiveAuthority
  import opened KipioAccountAuthorizationState
  import opened KipioAccountCredential
  import opened KipioAccountCredentialAuthority
  import opened KipioAccountSession
  import opened KipioAccountDelegation

  import opened KipioAccountAccount
  import opened KipioAccountAccountTransitions

  import opened KipioAccountProofs
  import opened KipioAccountFoundationProofs
  import opened KipioAccountReplay
  import opened KipioAccountPolicyEffect

  // ============================================================
  // GENERIC TRANSITION BOUNDARY
  // ============================================================

  // Any explicitly identity-preserving Account transition leaves
  // both Entity identity and Sovereign Identity unchanged.

  lemma EIP7702TransitionPreservesIdentityBoundary(
    before: Account,
    after: Account
  )
    requires AccountTransitionPreservesIdentity(
               before,
               after
             )
    ensures AccountIdOf(before)
            ==
            AccountIdOf(after)
    ensures AccountSovereignIdentity(before)
            ==
            AccountSovereignIdentity(after)
    ensures SameAccount(before, after)
  {
    AccountTransitionProvidesReusableIdentityContract(
      before,
      after
    );
  }


  // ============================================================
  // OPERATIONAL STATE IS NOT SOVEREIGN IDENTITY
  // ============================================================

  // Adding operational Capability state changes the Authorization
  // State representation without changing Account sovereignty.

  lemma EIP7702CapabilityMutationPreservesSovereignty(
    account: Account,
    capability: Capability
  )
    requires ValidAccount(account)
    requires ValidCapability(capability)
    ensures SameAccount(
              account,
              AddCapability(
                account,
                capability
              )
            )
    ensures AccountSovereignIdentity(
              AddCapability(
                account,
                capability
              )
            )
            ==
            AccountSovereignIdentity(account)
  {
    AddCapabilityPreservesIdentity(
      account,
      capability
    );

    AccountTransitionProvidesReusableIdentityContract(
      account,
      AddCapability(
        account,
        capability
      )
    );
  }


  // Removing operational Capability state also preserves the
  // sovereign boundary.

  lemma EIP7702CapabilityRemovalPreservesSovereignty(
    account: Account,
    capability: Capability
  )
    requires ValidAccount(account)
    ensures SameAccount(
              account,
              RemoveCapability(
                account,
                capability
              )
            )
    ensures AccountSovereignIdentity(
              RemoveCapability(
                account,
                capability
              )
            )
            ==
            AccountSovereignIdentity(account)
  {
    RemoveCapabilityPreservesIdentity(
      account,
      capability
    );

    AccountTransitionProvidesReusableIdentityContract(
      account,
      RemoveCapability(
        account,
        capability
      )
    );
  }


  // ============================================================
  // CREDENTIAL STATE
  // ============================================================

  // Credential lifecycle mutation is operational state evolution
  // and cannot replace the Account's sovereign Identity.

  lemma EIP7702CredentialLifecyclePreservesSovereignty(
    account: Account,
    credential: Credential,
    status: CredentialStatus
  )
    requires ValidAccount(account)
    requires credential
             in StateCredentials(
                  AccountAuthorizationState(account)
                )
    requires ValidCredentialStatusTransition(
               credential,
               status
             )
    ensures SameAccount(
              account,
              UpdateCredentialStatus(
                account,
                credential,
                status
              )
            )
    ensures AccountSovereignIdentity(
              UpdateCredentialStatus(
                account,
                credential,
                status
              )
            )
            ==
            AccountSovereignIdentity(account)
  {
    UpdateCredentialStatusPreservesIdentity(
      account,
      credential,
      status
    );

    AccountTransitionProvidesReusableIdentityContract(
      account,
      UpdateCredentialStatus(
        account,
        credential,
        status
      )
    );
  }


  // ============================================================
  // CREDENTIAL AUTHORITY STATE
  // ============================================================

  // Updating Credential Authority mutates operational authority
  // state without replacing Account sovereignty.

  lemma EIP7702CredentialAuthorityMutationPreservesSovereignty(
    account: Account,
    credential: Credential,
    authority: CredentialAuthority
  )
    requires ValidAccount(account)
    requires ValidCredentialAuthority(authority)
    requires CredentialRecognizedInState(
               AccountAuthorizationState(account),
               credential
             )
    requires ExistingSessionsRemainWithinCredentialAuthority(
               AccountAuthorizationState(account),
               CredentialId(credential),
               authority
             )
    ensures SameAccount(
              account,
              SetCredentialAuthority(
                account,
                credential,
                authority
              )
            )
    ensures AccountSovereignIdentity(
              SetCredentialAuthority(
                account,
                credential,
                authority
              )
            )
            ==
            AccountSovereignIdentity(account)
  {
    SetCredentialAuthorityPreservesIdentity(
      account,
      credential,
      authority
    );

    AccountTransitionProvidesReusableIdentityContract(
      account,
      SetCredentialAuthority(
        account,
        credential,
        authority
      )
    );
  }


  // ============================================================
  // SESSION STATE
  // ============================================================

  lemma EIP7702SessionRegistrationPreservesSovereignty(
    account: Account,
    session: Session
  )
    requires ValidAccount(account)
    requires ValidSession(session)
    requires !SessionIdRecognizedInState(
               AccountAuthorizationState(account),
               SessionId(session)
             )
    requires CredentialIdRecognizedInState(
               AccountAuthorizationState(account),
               SessionCredentialId(session)
             )
    requires SessionAuthorityWithinCredentialAuthority(
               session,
               StateCredentialAuthorities(
                 AccountAuthorizationState(account)
               )[SessionCredentialId(session)]
             )
    ensures SameAccount(
              account,
              RegisterSession(
                account,
                session
              )
            )
    ensures AccountSovereignIdentity(
              RegisterSession(
                account,
                session
              )
            )
            ==
            AccountSovereignIdentity(account)
  {
    RegisterSessionPreservesIdentity(
      account,
      session
    );

    AccountTransitionProvidesReusableIdentityContract(
      account,
      RegisterSession(
        account,
        session
      )
    );
  }


  lemma EIP7702SessionLifecyclePreservesSovereignty(
    account: Account,
    session: Session,
    status: SessionStatus
  )
    requires ValidAccount(account)
    requires session
             in StateSessions(
                  AccountAuthorizationState(account)
                )
    requires ValidSessionStatusTransition(
               session,
               status
             )
    ensures SameAccount(
              account,
              UpdateSessionStatus(
                account,
                session,
                status
              )
            )
    ensures AccountSovereignIdentity(
              UpdateSessionStatus(
                account,
                session,
                status
              )
            )
            ==
            AccountSovereignIdentity(account)
  {
    UpdateSessionStatusPreservesIdentity(
      account,
      session,
      status
    );

    AccountTransitionProvidesReusableIdentityContract(
      account,
      UpdateSessionStatus(
        account,
        session,
        status
      )
    );
  }


  // ============================================================
  // RESTRICTION STATE
  // ============================================================

  // Restriction state is represented by an explicit association:
  //
  //     Capability × OptionalPolicyScope -> Restriction
  //
  // The operational transition is therefore SetRestriction rather
  // than an AddRestriction operation over a standalone Restriction.

  lemma EIP7702RestrictionMutationPreservesSovereignty(
    account: Account,
    capability: Capability,
    scope: OptionalPolicyScope,
    restriction: Restriction
  )
    requires ValidAccount(account)
    requires ValidCapability(capability)
    requires ValidOptionalPolicyScope(scope)
    requires ValidRestriction(restriction)
    requires capability
             in StateCapabilities(
                  AccountAuthorizationState(account)
                )
    ensures SameAccount(
              account,
              SetRestriction(
                account,
                capability,
                scope,
                restriction
              )
            )
    ensures AccountSovereignIdentity(
              SetRestriction(
                account,
                capability,
                scope,
                restriction
              )
            )
            ==
            AccountSovereignIdentity(account)
  {
    SetRestrictionPreservesIdentity(
      account,
      capability,
      scope,
      restriction
    );

    AccountTransitionProvidesReusableIdentityContract(
      account,
      SetRestriction(
        account,
        capability,
        scope,
        restriction
      )
    );
  }


  lemma EIP7702RestrictionRemovalPreservesSovereignty(
    account: Account,
    capability: Capability,
    scope: OptionalPolicyScope
  )
    requires ValidAccount(account)
    ensures SameAccount(
              account,
              RemoveRestriction(
                account,
                capability,
                scope
              )
            )
    ensures AccountSovereignIdentity(
              RemoveRestriction(
                account,
                capability,
                scope
              )
            )
            ==
            AccountSovereignIdentity(account)
  {
    RemoveRestrictionPreservesIdentity(
      account,
      capability,
      scope
    );

    AccountTransitionProvidesReusableIdentityContract(
      account,
      RemoveRestriction(
        account,
        capability,
        scope
      )
    );
  }


  // ============================================================
  // DELEGATION STATE
  // ============================================================

  // Root Delegation is represented by the concrete transition
  // contract. Its authority witnesses are operational inputs, not
  // a change of Account sovereignty.

  lemma EIP7702DelegationRegistrationPreservesSovereignty(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: EffectiveAuthority
  )
    requires ValidRootDelegationRegistration(
               account,
               delegation,
               delegateCapability,
               delegatableAuthority,
               sourceEffectiveAuthority
             )
    ensures SameAccount(
              account,
              RegisterDelegation(
                account,
                delegation,
                delegateCapability,
                delegatableAuthority,
                sourceEffectiveAuthority
              )
            )
    ensures AccountSovereignIdentity(
              RegisterDelegation(
                account,
                delegation,
                delegateCapability,
                delegatableAuthority,
                sourceEffectiveAuthority
              )
            )
            ==
            AccountSovereignIdentity(account)
  {
    RegisterDelegationPreservesIdentity(
      account,
      delegation,
      delegateCapability,
      delegatableAuthority,
      sourceEffectiveAuthority
    );

    AccountTransitionProvidesReusableIdentityContract(
      account,
      RegisterDelegation(
        account,
        delegation,
        delegateCapability,
        delegatableAuthority,
        sourceEffectiveAuthority
      )
    );
  }


  // Transitive Delegation remains an operational Authorization
  // State mutation and therefore cannot replace Account sovereignty.

  lemma EIP7702TransitiveDelegationRegistrationPreservesSovereignty(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: EffectiveAuthority,
    parentDelegationIds: set<Id>,
    identities: set<Identity>
  )
    requires ValidTransitiveDelegationRegistration(
               account,
               delegation,
               delegateCapability,
               delegatableAuthority,
               sourceEffectiveAuthority,
               parentDelegationIds,
               identities
             )
    ensures SameAccount(
              account,
              RegisterTransitiveDelegation(
                account,
                delegation,
                delegateCapability,
                delegatableAuthority,
                sourceEffectiveAuthority,
                parentDelegationIds,
                identities
              )
            )
    ensures AccountSovereignIdentity(
              RegisterTransitiveDelegation(
                account,
                delegation,
                delegateCapability,
                delegatableAuthority,
                sourceEffectiveAuthority,
                parentDelegationIds,
                identities
              )
            )
            ==
            AccountSovereignIdentity(account)
  {
    RegisterTransitiveDelegationPreservesIdentity(
      account,
      delegation,
      delegateCapability,
      delegatableAuthority,
      sourceEffectiveAuthority,
      parentDelegationIds,
      identities
    );

    AccountTransitionProvidesReusableIdentityContract(
      account,
      RegisterTransitiveDelegation(
        account,
        delegation,
        delegateCapability,
        delegatableAuthority,
        sourceEffectiveAuthority,
        parentDelegationIds,
        identities
      )
    );
  }


  lemma EIP7702DelegationLifecyclePreservesSovereignty(
    account: Account,
    delegation: Delegation,
    status: DelegationStatus
  )
    requires ValidAccount(account)
    requires delegation
             in StateDelegations(
                  AccountAuthorizationState(account)
                )
    requires ValidDelegationStatusTransition(
               delegation,
               status
             )
    ensures SameAccount(
              account,
              UpdateDelegationStatus(
                account,
                delegation,
                status
              )
            )
    ensures AccountSovereignIdentity(
              UpdateDelegationStatus(
                account,
                delegation,
                status
              )
            )
            ==
            AccountSovereignIdentity(account)
  {
    UpdateDelegationStatusPreservesIdentity(
      account,
      delegation,
      status
    );

    AccountTransitionProvidesReusableIdentityContract(
      account,
      UpdateDelegationStatus(
        account,
        delegation,
        status
      )
    );
  }


  // ============================================================
  // REPLAY STATE
  // ============================================================

  // Replay-key consumption changes operational Authorization State
  // while preserving the Account Entity and its Sovereign Identity.

  lemma EIP7702ReplayConsumptionPreservesSovereignty(
    account: Account,
    replayKey: ReplayKey
  )
    requires ValidAccount(account)
    requires ValidReplayKeyConsumption(
               AccountAuthorizationState(account),
               replayKey
             )
    ensures SameAccount(
              account,
              ConsumeReplayKey(
                account,
                replayKey
              )
            )
    ensures AccountSovereignIdentity(
              ConsumeReplayKey(
                account,
                replayKey
              )
            )
            ==
            AccountSovereignIdentity(account)
  {
    ConsumeReplayKeyPreservesIdentity(
      account,
      replayKey
    );

    AccountTransitionProvidesReusableIdentityContract(
      account,
      ConsumeReplayKey(
        account,
        replayKey
      )
    );
  }


  // ============================================================
  // ADVERSARIAL ATTACK
  // ============================================================

  // Attack:
  //
  //   A malicious operational mutation attempts to replace the
  //   sovereign Identity while still claiming to be an explicitly
  //   identity-preserving Account transition.
  //
  // The transition boundary must make this impossible.

  lemma EIP7702CannotReplaceSovereignIdentity(
    before: Account,
    after: Account,
    forgedIdentity: Identity
  )
    requires AccountTransitionPreservesIdentity(
               before,
               after
             )
    requires forgedIdentity
             !=
             AccountSovereignIdentity(before)
    requires AccountSovereignIdentity(after)
             ==
             forgedIdentity
    ensures false
  {
    AccountTransitionPreservesIdentityLaw(
      before,
      after
    );

    assert AccountSovereignIdentity(after)
           ==
           AccountSovereignIdentity(before);

    assert forgedIdentity
           ==
           AccountSovereignIdentity(before);
  }


  // ============================================================
  // ENTITY IDENTITY ATTACK
  // ============================================================

  // A valid identity-preserving transition cannot turn the result
  // into a different Account Entity because AccountId is preserved.

  lemma EIP7702CannotCreateDifferentAccountEntityThroughTransition(
    before: Account,
    after: Account
  )
    requires AccountTransitionPreservesIdentity(
               before,
               after
             )
    ensures SameAccount(before, after)
  {
    AccountTransitionProvidesReusableIdentityContract(
      before,
      after
    );
  }


  // ============================================================
  // OPERATIONAL MUTATION / SOVEREIGN CONTINUITY
  // ============================================================

  // Combined boundary:
  //
  // operational state may evolve,
  // while Account Entity identity and Sovereign Identity remain
  // continuous.

  lemma EIP7702OperationalStateMutationPreservesSovereignContinuity(
    before: Account,
    after: Account
  )
    requires AccountTransitionPreservesIdentity(
               before,
               after
             )
    ensures SameAccount(before, after)
    ensures AccountIdOf(before)
            ==
            AccountIdOf(after)
    ensures AccountSovereignIdentity(after)
            ==
            AccountSovereignIdentity(before)
  {
    AccountTransitionProvidesReusableIdentityContract(
      before,
      after
    );
  }


  // ============================================================
  // FINAL SCENARIO BOUNDARY
  // ============================================================

  // EIP-7702-style operational evolution is semantically safe
  // at this boundary when the resulting state is produced by an
  // explicitly identity-preserving Account transition.
  //
  // No blockchain-specific semantics are required for this result.

  lemma EIP7702IdentityBoundaryIsClosed(
    before: Account,
    after: Account
  )
    requires AccountTransitionPreservesIdentity(
               before,
               after
             )
    ensures AccountIdOf(before)
            ==
            AccountIdOf(after)
    ensures AccountSovereignIdentity(before)
            ==
            AccountSovereignIdentity(after)
    ensures SameAccount(before, after)
  {
    AccountTransitionProvidesReusableIdentityContract(
      before,
      after
    );
  }
}

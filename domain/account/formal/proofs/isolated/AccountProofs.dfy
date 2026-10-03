// ============================================================
// KIPIO ACCOUNT DOMAIN
// PROOFS — ACCOUNT
// ============================================================
//
// Reusable isolated proof facade for the Account bounded context.
//
// This file exposes the Account-level proof boundary for downstream
// isolated proofs and E2E scenarios.
//
// It composes:
//
//   Account
//   AccountTransitions
//   AuthorizationState
//   Credential
//   CredentialAuthority
//   Session
//   Delegation
//
// The purpose is NOT to duplicate lower-level proofs.
//
// Instead, this facade exposes reusable Account-level contracts for:
//
//   - Account structural validity;
//   - Account Entity identity;
//   - sovereign Identity preservation;
//   - Authorization State preservation;
//   - Credential registration and lifecycle;
//   - Credential Authority updates;
//   - Session registration and lifecycle;
//   - Restriction state transitions;
//   - Delegation registration and lifecycle;
//   - delegation provenance preservation;
//   - Entity recognition / lifecycle separation.
//
// This file does NOT:
//
//   - calculate Effective Authority;
//   - validate Authorization;
//   - verify Proof;
//   - execute Domain Actions;
//   - evaluate Policy;
//   - define blockchain behavior.
//
// ------------------------------------------------------------
//
// IMPORTANT:
//
// This facade deliberately follows the current concrete
// AccountTransitions contracts.
//
// In particular:
//
//   SetRestriction(account, capability, scope, restriction)
//
// is the canonical restriction-setting transition.
//
// Likewise:
//
//   RegisterDelegation(
//     account,
//     delegation,
//     delegateCapability,
//     delegatableAuthority,
//     sourceEffectiveAuthority
//   )
//
// and:
//
//   RegisterTransitiveDelegation(
//     account,
//     delegation,
//     delegateCapability,
//     delegatableAuthority,
//     sourceEffectiveAuthority,
//     parentDelegationIds,
//     identities
//   )
//
// are the current canonical delegation transitions.
//
// ============================================================

include "../../account/Account.dfy"
include "../../account/AccountTransitions.dfy"

include "../../authority/AuthorizationState.dfy"
include "../../authority/Credential.dfy"
include "../../authority/CredentialAuthority.dfy"
include "../../authority/Session.dfy"
include "../../authority/Delegation.dfy"


module KipioAccountProofs
{
  import opened KipioAccountDomainPrimitives
  import opened KipioAccountIdentity
  import opened KipioAccountCapability
  import opened KipioAccountRestriction

  import opened KipioAccountAccount
  import opened KipioAccountAccountTransitions

  import opened KipioAccountAuthorizationState
  import opened KipioAccountCredential
  import opened KipioAccountCredentialAuthority
  import opened KipioAccountSession
  import opened KipioAccountDelegation
  import opened KipioAccountPolicyEffect


  // ==========================================================
  // ACCOUNT STRUCTURAL VALIDITY
  // ==========================================================

  // A valid Account exposes a valid AccountId.
  lemma AccountProofHasValidAccountId(
    account: Account
  )
    requires ValidAccount(account)
    ensures ValidId(AccountIdOf(account))
  {
    ValidAccountHasValidId(account);
  }


  // A valid Account exposes a valid sovereign Identity.
  lemma AccountProofHasValidSovereignIdentity(
    account: Account
  )
    requires ValidAccount(account)
    ensures ValidIdentity(
              AccountSovereignIdentity(account)
            )
  {
    ValidAccountHasValidSovereignIdentity(account);
  }


  // A valid Account contains a valid Authorization State.
  lemma AccountProofHasValidAuthorizationState(
    account: Account
  )
    requires ValidAccount(account)
    ensures ValidAuthorizationState(
              AccountAuthorizationState(account)
            )
  {
    ValidAccountHasValidAuthorizationState(account);
  }


  // Compact structural contract for a valid Account.
  lemma ValidAccountSatisfiesStructuralBoundaries(
    account: Account
  )
    requires ValidAccount(account)
    ensures ValidId(AccountIdOf(account))
    ensures ValidIdentity(
              AccountSovereignIdentity(account)
            )
    ensures ValidAuthorizationState(
              AccountAuthorizationState(account)
            )
  {
    ValidAccountHasValidId(account);
    ValidAccountHasValidSovereignIdentity(account);
    ValidAccountHasValidAuthorizationState(account);
  }


  // ==========================================================
  // ACCOUNT ENTITY IDENTITY
  // ==========================================================

  // Account Entity identity is determined by AccountId.
  //
  // This is semantic Entity identity and is intentionally different
  // from Dafny structural equality.
  lemma AccountIdentityIsDeterminedByAccountId(
    left: Account,
    right: Account
  )
    requires AccountIdOf(left) == AccountIdOf(right)
    ensures SameAccount(left, right)
  {
    AccountsWithEqualIdsHaveSameIdentity(left, right);
  }


  // Distinct AccountIds imply distinct Account Entities.
  lemma DistinctAccountIdsCannotRepresentSameAccount(
    left: Account,
    right: Account
  )
    requires AccountIdOf(left) != AccountIdOf(right)
    ensures !SameAccount(left, right)
  {
    AccountsWithDistinctIdsAreNotTheSameAccount(
      left,
      right
    );
  }


  // Structural equality necessarily preserves AccountId.
  lemma EqualAccountsPreserveAccountIdentity(
    left: Account,
    right: Account
  )
    requires left == right
    ensures AccountIdOf(left) == AccountIdOf(right)
  {
    EqualAccountsHaveEqualIds(left, right);
  }


  // Two Accounts with the same semantic identity and identical
  // sovereign Identity and Authorization State are structurally equal.
  //
  // This theorem preserves the distinction between:
  //
  //   semantic Entity identity
  //         =
  //   AccountId
  //
  // and:
  //
  //   Dafny structural equality
  //         =
  //   all constructor fields.
  lemma AccountsWithSameIdentityAndStateAreStructurallyEqual(
    left: Account,
    right: Account
  )
    requires AccountIdOf(left) == AccountIdOf(right)
    requires AccountSovereignIdentity(left)
          == AccountSovereignIdentity(right)
    requires AccountAuthorizationState(left)
          == AccountAuthorizationState(right)
    ensures left == right
  {
    AccountsWithSameIdAndStateAreStructurallyEqual(
      left,
      right
    );
  }


  // ==========================================================
  // ACCOUNT — SOVEREIGN IDENTITY
  // ==========================================================

  // Every Account contains exactly one sovereign Identity because
  // the Account datatype contains exactly one Identity field.
  //
  // This does NOT state that no other Identity may later be
  // authorized to exercise authority over the Account.
  lemma AccountHasOneSovereignIdentity(
    account: Account
  )
    ensures AccountSovereignIdentity(account)
         == account.identity
  {
    AccountHasExactlyOneSovereignIdentity(account);
  }


  // The sovereign Identity relation is structural and is independent
  // from the Authorization State representation.
  lemma AccountSovereigntyIsSeparateFromAuthorizationState(
    account: Account
  )
    ensures AccountSovereignIdentity(account)
         == account.identity
  {
    AccountSovereignIdentityIndependentOfAuthorizationState(
      account
    );
  }


  // ==========================================================
  // GENERIC ACCOUNT TRANSITION BOUNDARY
  // ==========================================================

  // Every explicitly identity-preserving Account transition
  // preserves AccountId and sovereign Identity.
  lemma AccountTransitionPreservesAccountBoundary(
    before: Account,
    after: Account
  )
    requires AccountTransitionPreservesIdentity(
               before,
               after
             )
    ensures AccountIdOf(before) == AccountIdOf(after)
    ensures AccountSovereignIdentity(before)
         == AccountSovereignIdentity(after)
  {
    AccountTransitionPreservesIdentityLaw(
      before,
      after
    );
  }


  // An identity-preserving transition cannot replace the sovereign
  // Identity with another Identity.
  lemma AccountTransitionPreservesSovereignIdentity(
    before: Account,
    after: Account
  )
    requires AccountTransitionPreservesIdentity(
               before,
               after
             )
    ensures AccountSovereignIdentity(after)
         == AccountSovereignIdentity(before)
  {
    AccountTransitionPreservesIdentityLaw(
      before,
      after
    );
  }


  // An explicitly identity-preserving transition therefore preserves
  // semantic Account Entity identity.
  lemma AccountTransitionPreservesSemanticAccountIdentity(
    before: Account,
    after: Account
  )
    requires AccountTransitionPreservesIdentity(
               before,
               after
             )
    ensures SameAccount(before, after)
  {
    AccountTransitionPreservesIdentityLaw(
      before,
      after
    );

    assert AccountIdOf(before) == AccountIdOf(after);
    assert SameAccount(before, after);
  }


  // ==========================================================
  // CREDENTIAL REGISTRATION
  // ==========================================================

  // Credential registration preserves Account identity.
  lemma RegisterCredentialPreservesAccountBoundary(
    account: Account,
    credential: Credential
  )
    requires ValidAccount(account)
    requires ValidCredential(credential)
    requires !CredentialIdRecognizedInState(
               AccountAuthorizationState(account),
               CredentialId(credential)
             )
    ensures AccountTransitionPreservesIdentity(
              account,
              RegisterCredential(
                account,
                credential
              )
            )
  {
    RegisterCredentialPreservesIdentity(
      account,
      credential
    );
  }


  // Registering a Credential makes the CredentialId recognized.
  lemma RegisterCredentialEstablishesRecognition(
    account: Account,
    credential: Credential
  )
    requires ValidAccount(account)
    requires ValidCredential(credential)
    requires !CredentialIdRecognizedInState(
               AccountAuthorizationState(account),
               CredentialId(credential)
             )
    ensures CredentialIdRecognizedInState(
              AccountAuthorizationState(
                RegisterCredential(
                  account,
                  credential
                )
              ),
              CredentialId(credential)
            )
  {
    RegisteredCredentialBelongsToState(
      account,
      credential
    );
  }


  // A newly registered Credential starts with an empty Credential
  // Authority.
  lemma RegisterCredentialStartsWithEmptyAuthority(
    account: Account,
    credential: Credential
  )
    requires ValidAccount(account)
    requires ValidCredential(credential)
    requires !CredentialIdRecognizedInState(
               AccountAuthorizationState(account),
               CredentialId(credential)
             )
    ensures StateCredentialAuthority(
              AccountAuthorizationState(
                RegisterCredential(
                  account,
                  credential
                )
              ),
              credential
            ) == {}
  {
    RegisteredCredentialHasEmptyAuthority(
      account,
      credential
    );
  }


  // Registration preserves Authorization State validity.
  lemma RegisterCredentialPreservesAuthorizationStateValidity(
    account: Account,
    credential: Credential
  )
    requires ValidAccount(account)
    requires ValidCredential(credential)
    requires !CredentialIdRecognizedInState(
               AccountAuthorizationState(account),
               CredentialId(credential)
             )
    ensures ValidAuthorizationState(
              AccountAuthorizationState(
                RegisterCredential(
                  account,
                  credential
                )
              )
            )
  {
    KipioAccountAccountTransitions.RegisterCredentialPreservesAuthorizationStateValidity(
      account,
      credential
    );
  }


  // Registration preserves complete Account validity.
  lemma RegisterCredentialPreservesAccountValidity(
    account: Account,
    credential: Credential
  )
    requires ValidAccount(account)
    requires ValidCredential(credential)
    requires !CredentialIdRecognizedInState(
               AccountAuthorizationState(account),
               CredentialId(credential)
             )
    ensures ValidAccount(
              RegisterCredential(
                account,
                credential
              )
            )
  {
    KipioAccountAccountTransitions.RegisterCredentialPreservesAccountValidity(
      account,
      credential
    );
  }


  // Registration does not change sovereignty.
  lemma RegisterCredentialPreservesSovereignty(
    account: Account,
    credential: Credential
  )
    requires ValidAccount(account)
    requires ValidCredential(credential)
    requires !CredentialIdRecognizedInState(
               AccountAuthorizationState(account),
               CredentialId(credential)
             )
    ensures AccountSovereignIdentity(
              RegisterCredential(
                account,
                credential
              )
            )
            ==
            AccountSovereignIdentity(account)
  {
    RegisterCredentialPreservesIdentity(
      account,
      credential
    );
  }


  // Compact reusable registration contract.
  lemma RegisteredCredentialProvidesReusableProofContract(
    account: Account,
    credential: Credential
  )
    requires ValidAccount(account)
    requires ValidCredential(credential)
    requires !CredentialIdRecognizedInState(
               AccountAuthorizationState(account),
               CredentialId(credential)
             )
    ensures ValidAccount(
              RegisterCredential(
                account,
                credential
              )
            )
    ensures CredentialIdRecognizedInState(
              AccountAuthorizationState(
                RegisterCredential(
                  account,
                  credential
                )
              ),
              CredentialId(credential)
            )
    ensures StateCredentialAuthority(
              AccountAuthorizationState(
                RegisterCredential(
                  account,
                  credential
                )
              ),
              credential
            ) == {}
    ensures AccountTransitionPreservesIdentity(
              account,
              RegisterCredential(
                account,
                credential
              )
            )
    ensures AccountSovereignIdentity(
              RegisterCredential(
                account,
                credential
              )
            )
            ==
            AccountSovereignIdentity(account)
  {
    RegisterCredentialPreservesAccountValidity(
      account,
      credential
    );

    RegisterCredentialEstablishesRecognition(
      account,
      credential
    );

    RegisterCredentialStartsWithEmptyAuthority(
      account,
      credential
    );

    RegisterCredentialPreservesAccountBoundary(
      account,
      credential
    );

    RegisterCredentialPreservesSovereignty(
      account,
      credential
    );
  }


  // ==========================================================
  // CREDENTIAL AUTHORITY
  // ==========================================================

  // Updating Credential Authority preserves Account identity.
  lemma SetCredentialAuthorityPreservesAccountBoundary(
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
    ensures AccountTransitionPreservesIdentity(
              account,
              SetCredentialAuthority(
                account,
                credential,
                authority
              )
            )
  {
    SetCredentialAuthorityPreservesIdentity(
      account,
      credential,
      authority
    );
  }


  // The resulting state contains the supplied Credential Authority.
  lemma SetCredentialAuthorityUpdatesState(
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
    ensures StateCredentialAuthority(
              AccountAuthorizationState(
                SetCredentialAuthority(
                  account,
                  credential,
                  authority
                )
              ),
              credential
            ) == authority
  {
    CredentialAuthorityUpdatedInState(
      account,
      credential,
      authority
    );
  }


  // Existing Sessions for the Credential remain inside the newly
  // supplied Credential Authority.
  lemma SetCredentialAuthorityPreservesExistingSessionBoundary(
    account: Account,
    credential: Credential,
    authority: CredentialAuthority,
    session: Session
  )
    requires ValidAccount(account)
    requires ValidCredentialAuthority(authority)
    requires CredentialRecognizedInState(
               AccountAuthorizationState(account),
               credential
             )
    requires session
             in StateSessions(
                  AccountAuthorizationState(account)
                )
    requires SessionCredentialId(session)
          == CredentialId(credential)
    requires ExistingSessionsRemainWithinCredentialAuthority(
               AccountAuthorizationState(account),
               CredentialId(credential),
               authority
             )
    ensures SessionAuthorityWithinCredentialAuthority(
              session,
              StateCredentialAuthorities(
                AccountAuthorizationState(
                  SetCredentialAuthority(
                    account,
                    credential,
                    authority
                  )
                )
              )[CredentialId(credential)]
            )
  {
    UpdatedCredentialAuthorityStillBoundsExistingSessions(
      account,
      credential,
      authority,
      session
    );
  }


  // Credential Authority update preserves Authorization State validity.
  lemma SetCredentialAuthorityPreservesAuthorizationStateValidity(
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
    ensures ValidAuthorizationState(
              AccountAuthorizationState(
                SetCredentialAuthority(
                  account,
                  credential,
                  authority
                )
              )
            )
  {
    KipioAccountAccountTransitions.SetCredentialAuthorityPreservesAuthorizationStateValidity(
      account,
      credential,
      authority
    );
  }


  // A recognized Credential necessarily has a Credential Authority
  // entry in a valid Account.
  lemma RecognizedCredentialHasAuthorityInAccount(
    account: Account,
    credential: Credential
  )
    requires ValidAccount(account)
    requires CredentialRecognizedInState(
               AccountAuthorizationState(account),
               credential
             )
    ensures CredentialAuthorityDefinedInState(
              AccountAuthorizationState(account),
              credential
            )
  {
    RecognizedCredentialHasCredentialAuthority(
      AccountAuthorizationState(account),
      credential
    );
  }


  // A recognized Credential has a structurally valid Credential
  // Authority.
  lemma RecognizedCredentialHasValidAuthorityInAccount(
    account: Account,
    credential: Credential
  )
    requires ValidAccount(account)
    requires CredentialRecognizedInState(
               AccountAuthorizationState(account),
               credential
             )
    ensures ValidCredentialAuthority(
              StateCredentialAuthority(
                AccountAuthorizationState(account),
                credential
              )
            )
  {
    StateCredentialHasValidAuthority(
      AccountAuthorizationState(account),
      credential
    );
  }


  // ==========================================================
  // CREDENTIAL LIFECYCLE
  // ==========================================================

  // Credential lifecycle transitions preserve Account identity.
  lemma UpdateCredentialStatusPreservesAccountBoundary(
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
    ensures AccountTransitionPreservesIdentity(
              account,
              UpdateCredentialStatus(
                account,
                credential,
                status
              )
            )
  {
    UpdateCredentialStatusPreservesIdentity(
      account,
      credential,
      status
    );
  }


  // Credential lifecycle update preserves recognition by stable
  // CredentialId.
  lemma UpdateCredentialStatusPreservesRecognition(
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
    ensures CredentialIdRecognizedInState(
              AccountAuthorizationState(
                UpdateCredentialStatus(
                  account,
                  credential,
                  status
                )
              ),
              CredentialId(credential)
            )
  {
    UpdatedCredentialRemainsRecognized(
      account,
      credential,
      status
    );
  }


  // Credential lifecycle replacement preserves Entity identity.
  lemma UpdateCredentialStatusPreservesCredentialIdentity(
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
    ensures exists updatedCredential ::
              updatedCredential
              in StateCredentials(
                   AccountAuthorizationState(
                     UpdateCredentialStatus(
                       account,
                       credential,
                       status
                     )
                   )
                 )
              && CredentialId(updatedCredential)
                 == CredentialId(credential)
  {
    UpdatedCredentialPreservesEntityIdentity(
      account,
      credential,
      status
    );
  }


  // Credential lifecycle transition preserves Authorization State
  // validity.
  lemma UpdateCredentialStatusPreservesAuthorizationStateValidity(
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
    ensures ValidAuthorizationState(
              AccountAuthorizationState(
                UpdateCredentialStatus(
                  account,
                  credential,
                  status
                )
              )
            )
  {
    KipioAccountAccountTransitions.UpdateCredentialStatusPreservesAuthorizationStateValidity(
      account,
      credential,
      status
    );
  }


  // Compact reusable Credential lifecycle contract.
  lemma UpdatedCredentialProvidesReusableProofContract(
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
    ensures ValidAuthorizationState(
              AccountAuthorizationState(
                UpdateCredentialStatus(
                  account,
                  credential,
                  status
                )
              )
            )
    ensures CredentialIdRecognizedInState(
              AccountAuthorizationState(
                UpdateCredentialStatus(
                  account,
                  credential,
                  status
                )
              ),
              CredentialId(credential)
            )
    ensures AccountTransitionPreservesIdentity(
              account,
              UpdateCredentialStatus(
                account,
                credential,
                status
              )
            )
    ensures exists updatedCredential ::
              updatedCredential
              in StateCredentials(
                   AccountAuthorizationState(
                     UpdateCredentialStatus(
                       account,
                       credential,
                       status
                     )
                   )
                 )
              && CredentialId(updatedCredential)
                 == CredentialId(credential)
  {
    UpdateCredentialStatusPreservesAuthorizationStateValidity(
      account,
      credential,
      status
    );

    UpdateCredentialStatusPreservesRecognition(
      account,
      credential,
      status
    );

    UpdateCredentialStatusPreservesAccountBoundary(
      account,
      credential,
      status
    );

    UpdateCredentialStatusPreservesCredentialIdentity(
      account,
      credential,
      status
    );
  }


  // ==========================================================
  // ACCOUNT CAPABILITY STATE
  // ==========================================================

  // Adding a Capability preserves Account identity.
  lemma AddCapabilityPreservesAccountBoundary(
    account: Account,
    capability: Capability
  )
    requires ValidAccount(account)
    requires ValidCapability(capability)
    ensures AccountTransitionPreservesIdentity(
              account,
              AddCapability(account, capability)
            )
  {
    AddCapabilityPreservesIdentity(
      account,
      capability
    );
  }


  // Removing a Capability preserves Account identity.
  lemma RemoveCapabilityPreservesAccountBoundary(
    account: Account,
    capability: Capability
  )
    requires ValidAccount(account)
    ensures AccountTransitionPreservesIdentity(
              account,
              RemoveCapability(account, capability)
            )
  {
    RemoveCapabilityPreservesIdentity(
      account,
      capability
    );
  }


  // ==========================================================
  // RESTRICTION STATE
  // ==========================================================

  // Setting a Restriction preserves Account identity.
  lemma SetRestrictionPreservesAccountBoundary(
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
    ensures AccountTransitionPreservesIdentity(
              account,
              SetRestriction(
                account,
                capability,
                scope,
                restriction
              )
            )
  {
    SetRestrictionPreservesIdentity(
      account,
      capability,
      scope,
      restriction
    );
  }


  // Setting a Restriction preserves Authorization State validity.
  lemma SetRestrictionPreservesAuthorizationStateValidity(
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
    ensures ValidAuthorizationState(
              AccountAuthorizationState(
                SetRestriction(
                  account,
                  capability,
                  scope,
                  restriction
                )
              )
            )
  {
    KipioAccountAccountTransitions.SetRestrictionPreservesAuthorizationStateValidity(
      account,
      capability,
      scope,
      restriction
    );
  }


  // Compact reusable Restriction-setting contract.
  lemma SetRestrictionProvidesReusableProofContract(
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
    ensures ValidAuthorizationState(
              AccountAuthorizationState(
                SetRestriction(
                  account,
                  capability,
                  scope,
                  restriction
                )
              )
            )
    ensures AccountTransitionPreservesIdentity(
              account,
              SetRestriction(
                account,
                capability,
                scope,
                restriction
              )
            )
  {
    SetRestrictionPreservesAuthorizationStateValidity(
      account,
      capability,
      scope,
      restriction
    );

    SetRestrictionPreservesAccountBoundary(
      account,
      capability,
      scope,
      restriction
    );
  }


  // Removing a Restriction preserves Account identity.
  lemma RemoveRestrictionPreservesAccountBoundary(
    account: Account,
    capability: Capability,
    scope: OptionalPolicyScope
  )
    requires ValidAccount(account)
    ensures AccountTransitionPreservesIdentity(
              account,
              RemoveRestriction(
                account,
                capability,
                scope
              )
            )
  {
    RemoveRestrictionPreservesIdentity(
      account,
      capability,
      scope
    );
  }


  // Removing a Restriction removes the corresponding Restriction
  // target from the resulting state.
  lemma RemoveRestrictionEstablishesAbsence(
    account: Account,
    capability: Capability,
    scope: OptionalPolicyScope
  )
    requires ValidAccount(account)
    ensures !RestrictionDefinedFor(
              AccountAuthorizationState(
                RemoveRestriction(
                  account,
                  capability,
                  scope
                )
              ),
              capability,
              scope
            )
  {
    RemoveRestrictionTargetIsAbsent(
      account,
      capability,
      scope
    );
  }


  // Removing a Restriction preserves Restriction Map integrity.
  lemma RemoveRestrictionPreservesMapIntegrity(
    account: Account,
    capability: Capability,
    scope: OptionalPolicyScope
  )
    requires ValidAccount(account)
    ensures ValidRestrictionMapInState(
              AccountAuthorizationState(
                RemoveRestriction(
                  account,
                  capability,
                  scope
                )
              )
            )
  {
    RemoveRestrictionPreservesRestrictionMapIntegrity(
      account,
      capability,
      scope
    );
  }


  // Compact reusable Restriction-removal contract.
  lemma RemoveRestrictionProvidesReusableProofContract(
    account: Account,
    capability: Capability,
    scope: OptionalPolicyScope
  )
    requires ValidAccount(account)
    ensures AccountTransitionPreservesIdentity(
              account,
              RemoveRestriction(
                account,
                capability,
                scope
              )
            )
    ensures !RestrictionDefinedFor(
              AccountAuthorizationState(
                RemoveRestriction(
                  account,
                  capability,
                  scope
                )
              ),
              capability,
              scope
            )
    ensures ValidRestrictionMapInState(
              AccountAuthorizationState(
                RemoveRestriction(
                  account,
                  capability,
                  scope
                )
              )
            )
  {
    RemoveRestrictionPreservesAccountBoundary(
      account,
      capability,
      scope
    );

    RemoveRestrictionEstablishesAbsence(
      account,
      capability,
      scope
    );

    RemoveRestrictionPreservesMapIntegrity(
      account,
      capability,
      scope
    );
  }


  // ==========================================================
  // SESSION REGISTRATION
  // ==========================================================

  // Registering a Session preserves Account identity.
  lemma RegisterSessionPreservesAccountBoundary(
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
    ensures AccountTransitionPreservesIdentity(
              account,
              RegisterSession(
                account,
                session
              )
            )
  {
    RegisterSessionPreservesIdentity(
      account,
      session
    );
  }


  // A newly registered Session becomes recognized.
  lemma RegisterSessionEstablishesRecognition(
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
    ensures SessionIdRecognizedInState(
              AccountAuthorizationState(
                RegisterSession(
                  account,
                  session
                )
              ),
              SessionId(session)
            )
  {
    RegisteredSessionBelongsToState(
      account,
      session
    );
  }


  // A registered Session continues to reference a recognized
  // Credential.
  lemma RegisteredSessionRetainsRecognizedCredential(
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
    ensures CredentialIdRecognizedInState(
              AccountAuthorizationState(
                RegisterSession(
                  account,
                  session
                )
              ),
              SessionCredentialId(session)
            )
  {
    RegisteredSessionBelongsToState(
      account,
      session
    );

    assert CredentialIdRecognizedInState(
        AccountAuthorizationState(
          RegisterSession(
            account,
            session
          )
        ),
        SessionCredentialId(session)
      );
  }


  // Session registration preserves Authorization State validity.
  lemma RegisterSessionPreservesAuthorizationStateValidity(
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
    ensures ValidAuthorizationState(
              AccountAuthorizationState(
                RegisterSession(
                  account,
                  session
                )
              )
            )
  {
    KipioAccountAccountTransitions.RegisterSessionPreservesAuthorizationStateValidity(
      account,
      session
    );
  }


  // Compact reusable Session registration contract.
  lemma RegisteredSessionProvidesReusableProofContract(
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
    ensures ValidAuthorizationState(
              AccountAuthorizationState(
                RegisterSession(
                  account,
                  session
                )
              )
            )
    ensures SessionIdRecognizedInState(
              AccountAuthorizationState(
                RegisterSession(
                  account,
                  session
                )
              ),
              SessionId(session)
            )
    ensures CredentialIdRecognizedInState(
              AccountAuthorizationState(
                RegisterSession(
                  account,
                  session
                )
              ),
              SessionCredentialId(session)
            )
    ensures AccountTransitionPreservesIdentity(
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
    RegisterSessionPreservesAuthorizationStateValidity(
      account,
      session
    );

    RegisterSessionEstablishesRecognition(
      account,
      session
    );

    RegisteredSessionRetainsRecognizedCredential(
      account,
      session
    );

    RegisterSessionPreservesAccountBoundary(
      account,
      session
    );

    assert AccountSovereignIdentity(
        RegisterSession(account, session)
      )
           ==
           AccountSovereignIdentity(account);
  }


  // ==========================================================
  // SESSION LIFECYCLE
  // ==========================================================

  // Updating Session lifecycle preserves Account identity.
  lemma UpdateSessionStatusPreservesAccountBoundary(
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
    ensures AccountTransitionPreservesIdentity(
              account,
              UpdateSessionStatus(
                account,
                session,
                status
              )
            )
  {
    KipioAccountAccountTransitions.UpdateSessionStatusPreservesIdentity(
      account,
      session,
      status
    );
  }


  // Updating Session lifecycle preserves recognition.
  lemma UpdateSessionStatusPreservesRecognition(
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
    ensures SessionIdRecognizedInState(
              AccountAuthorizationState(
                UpdateSessionStatus(
                  account,
                  session,
                  status
                )
              ),
              SessionId(session)
            )
  {
    UpdatedSessionRemainsInState(
      account,
      session,
      status
    );
  }


  // Updating Session lifecycle preserves Entity identity.
  lemma UpdateSessionStatusPreservesSessionIdentity(
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
    ensures exists updatedSession ::
              updatedSession
              in StateSessions(
                   AccountAuthorizationState(
                     UpdateSessionStatus(
                       account,
                       session,
                       status
                     )
                   )
                 )
              && SessionId(updatedSession)
                 == SessionId(session)
  {
    UpdatedSessionPreservesEntityIdentity(
      account,
      session,
      status
    );
  }


  // Changing Session lifecycle does not change its CredentialId,
  // authority definition or temporal boundaries.
  lemma UpdateSessionStatusPreservesSessionAuthorityDefinition(
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
    ensures SessionAuthorityWithinCredentialAuthority(
              Session(
                SessionId(session),
                SessionCredentialId(session),
                SessionCapabilities(session),
                SessionValidFrom(session),
                SessionValidUntil(session),
                SessionRestrictions(session),
                status
              ),
              StateCredentialAuthorities(
                AccountAuthorizationState(account)
              )[SessionCredentialId(session)]
            )
  {
    UpdatedSessionPreservesCredentialAuthorityBoundary(
      account,
      session,
      status
    );
  }


  // Session lifecycle transition preserves Authorization State
  // validity.
  lemma UpdateSessionStatusPreservesAuthorizationStateValidity(
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
    ensures ValidAuthorizationState(
              AccountAuthorizationState(
                UpdateSessionStatus(
                  account,
                  session,
                  status
                )
              )
            )
  {
    KipioAccountAccountTransitions.UpdateSessionStatusPreservesAuthorizationStateValidity(
      account,
      session,
      status
    );
  }


  // Compact reusable Session lifecycle contract.
  lemma UpdatedSessionProvidesReusableProofContract(
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
    ensures ValidAuthorizationState(
              AccountAuthorizationState(
                UpdateSessionStatus(
                  account,
                  session,
                  status
                )
              )
            )
    ensures SessionIdRecognizedInState(
              AccountAuthorizationState(
                UpdateSessionStatus(
                  account,
                  session,
                  status
                )
              ),
              SessionId(session)
            )
    ensures AccountTransitionPreservesIdentity(
              account,
              UpdateSessionStatus(
                account,
                session,
                status
              )
            )
    ensures exists updatedSession ::
              updatedSession
              in StateSessions(
                   AccountAuthorizationState(
                     UpdateSessionStatus(
                       account,
                       session,
                       status
                     )
                   )
                 )
              && SessionId(updatedSession)
                 == SessionId(session)
  {
    UpdateSessionStatusPreservesAuthorizationStateValidity(
      account,
      session,
      status
    );

    UpdateSessionStatusPreservesRecognition(
      account,
      session,
      status
    );

    UpdateSessionStatusPreservesAccountBoundary(
      account,
      session,
      status
    );

    UpdateSessionStatusPreservesSessionIdentity(
      account,
      session,
      status
    );
  }


  // ==========================================================
  // DELEGATION REGISTRATION
  // ==========================================================

  // Registering a root/independent Delegation preserves Account
  // identity.
  lemma RegisterDelegationPreservesAccountBoundary(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>
  )
    requires ValidRootDelegationRegistration(
               account,
               delegation,
               delegateCapability,
               delegatableAuthority,
               sourceEffectiveAuthority
             )
    ensures AccountTransitionPreservesIdentity(
              account,
              RegisterDelegation(
                account,
                delegation,
                delegateCapability,
                delegatableAuthority,
                sourceEffectiveAuthority
              )
            )
  {
    KipioAccountAccountTransitions.RegisterDelegationPreservesIdentity(
      account,
      delegation,
      delegateCapability,
      delegatableAuthority,
      sourceEffectiveAuthority
    );
  }


  // Registration makes the DelegationId recognizable.
  lemma RegisterDelegationEstablishesRecognition(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>
  )
    requires ValidRootDelegationRegistration(
               account,
               delegation,
               delegateCapability,
               delegatableAuthority,
               sourceEffectiveAuthority
             )
    ensures DelegationIdRecognizedInState(
              AccountAuthorizationState(
                RegisterDelegation(
                  account,
                  delegation,
                  delegateCapability,
                  delegatableAuthority,
                  sourceEffectiveAuthority
                )
              ),
              DelegationId(delegation)
            )
  {
    KipioAccountAccountTransitions.RegisteredDelegationBelongsToState(
      account,
      delegation,
      delegateCapability,
      delegatableAuthority,
      sourceEffectiveAuthority
    );
  }


  // A root/independent Delegation has empty explicit provenance.
  lemma RegisterDelegationEstablishesEmptyProvenance(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>
  )
    requires ValidRootDelegationRegistration(
               account,
               delegation,
               delegateCapability,
               delegatableAuthority,
               sourceEffectiveAuthority
             )
    ensures StateDelegationParents(
              AccountAuthorizationState(
                RegisterDelegation(
                  account,
                  delegation,
                  delegateCapability,
                  delegatableAuthority,
                  sourceEffectiveAuthority
                )
              ),
              delegation
            ) == {}
  {
    KipioAccountAccountTransitions.RegisteredDelegationHasEmptyProvenance(
      account,
      delegation,
      delegateCapability,
      delegatableAuthority,
      sourceEffectiveAuthority
    );
  }


  // Registration preserves the Account sovereign Identity.
  lemma RegisterDelegationPreservesSovereignty(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>
  )
    requires ValidRootDelegationRegistration(
               account,
               delegation,
               delegateCapability,
               delegatableAuthority,
               sourceEffectiveAuthority
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
    RegisterDelegationPreservesAccountBoundary(
      account,
      delegation,
      delegateCapability,
      delegatableAuthority,
      sourceEffectiveAuthority
    );

    assert AccountSovereignIdentity(
        RegisterDelegation(
          account,
          delegation,
          delegateCapability,
          delegatableAuthority,
          sourceEffectiveAuthority
        )
      )
           ==
           AccountSovereignIdentity(account);
  }


  // Compact reusable root Delegation registration contract.
  lemma RegisteredDelegationProvidesReusableProofContract(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>
  )
    requires ValidRootDelegationRegistration(
               account,
               delegation,
               delegateCapability,
               delegatableAuthority,
               sourceEffectiveAuthority
             )
    ensures DelegationIdRecognizedInState(
              AccountAuthorizationState(
                RegisterDelegation(
                  account,
                  delegation,
                  delegateCapability,
                  delegatableAuthority,
                  sourceEffectiveAuthority
                )
              ),
              DelegationId(delegation)
            )
    ensures StateDelegationParents(
              AccountAuthorizationState(
                RegisterDelegation(
                  account,
                  delegation,
                  delegateCapability,
                  delegatableAuthority,
                  sourceEffectiveAuthority
                )
              ),
              delegation
            ) == {}
    ensures AccountTransitionPreservesIdentity(
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
    ensures DelegationAuthorityIsBounded(
              delegation,
              delegateCapability,
              delegatableAuthority,
              sourceEffectiveAuthority
            )
  {
    RegisterDelegationEstablishesRecognition(
      account,
      delegation,
      delegateCapability,
      delegatableAuthority,
      sourceEffectiveAuthority
    );

    RegisterDelegationEstablishesEmptyProvenance(
      account,
      delegation,
      delegateCapability,
      delegatableAuthority,
      sourceEffectiveAuthority
    );

    RegisterDelegationPreservesAccountBoundary(
      account,
      delegation,
      delegateCapability,
      delegatableAuthority,
      sourceEffectiveAuthority
    );

    RegisterDelegationPreservesSovereignty(
      account,
      delegation,
      delegateCapability,
      delegatableAuthority,
      sourceEffectiveAuthority
    );

    assert DelegationAuthorityIsBounded(
        delegation,
        delegateCapability,
        delegatableAuthority,
        sourceEffectiveAuthority
      );
  }


  // ==========================================================
  // TRANSITIVE DELEGATION REGISTRATION
  // ==========================================================

  // Registering a transitive Delegation preserves Account identity.
  lemma RegisterTransitiveDelegationPreservesAccountBoundary(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>,
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
    ensures AccountTransitionPreservesIdentity(
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
  {
    KipioAccountAccountTransitions.RegisterTransitiveDelegationPreservesIdentity(
      account,
      delegation,
      delegateCapability,
      delegatableAuthority,
      sourceEffectiveAuthority,
      parentDelegationIds,
      identities
    );
  }


  // Transitive registration preserves explicit parent provenance.
  lemma RegisterTransitiveDelegationPreservesProvenance(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>,
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
    ensures StateDelegationParents(
              AccountAuthorizationState(
                RegisterTransitiveDelegation(
                  account,
                  delegation,
                  delegateCapability,
                  delegatableAuthority,
                  sourceEffectiveAuthority,
                  parentDelegationIds,
                  identities
                )
              ),
              delegation
            )
            ==
            parentDelegationIds
  {
    KipioAccountAccountTransitions.RegisteredTransitiveDelegationHasProvenance(
      account,
      delegation,
      delegateCapability,
      delegatableAuthority,
      sourceEffectiveAuthority,
      parentDelegationIds,
      identities
    );
  }


  // A transitive Delegation cannot invent a Capability absent from
  // every parent Delegation named by the supplied provenance.
  lemma RegisterTransitiveDelegationCannotInventCapability(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>,
    parentDelegationIds: set<Id>,
    identities: set<Identity>,
    capability: Capability
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
    requires capability in DelegationCapabilities(delegation)
    ensures exists parent ::
              parent in StateDelegations(
                          AccountAuthorizationState(
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
                        )
              && DelegationId(parent)
                 in parentDelegationIds
              && capability in DelegationCapabilities(parent)
  {
    KipioAccountAccountTransitions.RegisteredTransitiveDelegationPreservesAuthorityBoundaryFromParents(
      account,
      delegation,
      delegateCapability,
      delegatableAuthority,
      sourceEffectiveAuthority,
      parentDelegationIds,
      identities,
      capability
    );
  }


  // Compact reusable transitive Delegation contract.
  lemma RegisteredTransitiveDelegationProvidesReusableProofContract(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>,
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
    ensures DelegationIdRecognizedInState(
              AccountAuthorizationState(
                RegisterTransitiveDelegation(
                  account,
                  delegation,
                  delegateCapability,
                  delegatableAuthority,
                  sourceEffectiveAuthority,
                  parentDelegationIds,
                  identities
                )
              ),
              DelegationId(delegation)
            )
    ensures StateDelegationParents(
              AccountAuthorizationState(
                RegisterTransitiveDelegation(
                  account,
                  delegation,
                  delegateCapability,
                  delegatableAuthority,
                  sourceEffectiveAuthority,
                  parentDelegationIds,
                  identities
                )
              ),
              delegation
            )
            ==
            parentDelegationIds
    ensures AccountTransitionPreservesIdentity(
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
    ensures DelegationAuthorityIsBounded(
              delegation,
              delegateCapability,
              delegatableAuthority,
              sourceEffectiveAuthority
            )
  {
    RegisterTransitiveDelegationPreservesAccountBoundary(
      account,
      delegation,
      delegateCapability,
      delegatableAuthority,
      sourceEffectiveAuthority,
      parentDelegationIds,
      identities
    );

    RegisterTransitiveDelegationPreservesProvenance(
      account,
      delegation,
      delegateCapability,
      delegatableAuthority,
      sourceEffectiveAuthority,
      parentDelegationIds,
      identities
    );

    assert AccountSovereignIdentity(
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
           AccountSovereignIdentity(account);

    assert DelegationAuthorityIsBounded(
        delegation,
        delegateCapability,
        delegatableAuthority,
        sourceEffectiveAuthority
      );
  }


  // ==========================================================
  // DELEGATION LIFECYCLE
  // ==========================================================

  // Updating Delegation lifecycle preserves Account identity.
  lemma UpdateDelegationStatusPreservesAccountBoundary(
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
    ensures AccountTransitionPreservesIdentity(
              account,
              UpdateDelegationStatus(
                account,
                delegation,
                status
              )
            )
  {
    KipioAccountAccountTransitions.UpdateDelegationStatusPreservesIdentity(
      account,
      delegation,
      status
    );
  }


  // Delegation lifecycle update preserves recognition.
  lemma UpdateDelegationStatusPreservesRecognition(
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
    ensures DelegationIdRecognizedInState(
              AccountAuthorizationState(
                UpdateDelegationStatus(
                  account,
                  delegation,
                  status
                )
              ),
              DelegationId(delegation)
            )
  {
    UpdatedDelegationRemainsInState(
      account,
      delegation,
      status
    );
  }


  // Delegation lifecycle replacement preserves Entity identity.
  lemma UpdateDelegationStatusPreservesDelegationIdentity(
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
    ensures exists updatedDelegation ::
              updatedDelegation
              in StateDelegations(
                   AccountAuthorizationState(
                     UpdateDelegationStatus(
                       account,
                       delegation,
                       status
                     )
                   )
                 )
              && DelegationId(updatedDelegation)
                 == DelegationId(delegation)
  {
    KipioAccountAccountTransitions.UpdatedDelegationPreservesEntityIdentity(
      account,
      delegation,
      status
    );
  }


  // Provenance remains keyed by the same stable DelegationId and is
  // preserved across lifecycle transitions.
  lemma UpdateDelegationStatusPreservesProvenance(
    account: Account,
    delegation: Delegation,
    status: DelegationStatus
  )
    requires ValidAccount(account)
    requires delegation
             in StateDelegations(
                  AccountAuthorizationState(account)
                )
    requires DelegationProvenanceDefinedForDelegationId(
               AccountAuthorizationState(account),
               DelegationId(delegation)
             )
    requires ValidDelegationStatusTransition(
               delegation,
               status
             )
    ensures StateDelegationProvenance(
              AccountAuthorizationState(
                UpdateDelegationStatus(
                  account,
                  delegation,
                  status
                )
              )
            )[DelegationId(delegation)]
            ==
            StateDelegationProvenance(
              AccountAuthorizationState(account)
            )[DelegationId(delegation)]
  {
    KipioAccountAccountTransitions.UpdatedDelegationPreservesProvenance(
      account,
      delegation,
      status
    );
  }


  // ==========================================================
  // ENTITY IDENTITY / RECOGNITION SEPARATION
  // ==========================================================

  // A revoked Credential remains recognized as an Entity.
  lemma RevokedCredentialRemainsRecognizedInAccountProof(
    account: Account,
    credential: Credential
  )
    requires ValidAccount(account)
    requires credential in StateCredentials(
                             AccountAuthorizationState(account)
                           )
    requires CredentialIsRevoked(credential)
    ensures CredentialIdRecognizedInState(
              AccountAuthorizationState(account),
              CredentialId(credential)
            )
  {
    RevokedCredentialRemainsRecognized(
      AccountAuthorizationState(account),
      credential
    );
  }


  // A revoked Session remains recognized as an Entity.
  lemma RevokedSessionRemainsRecognizedInAccountProof(
    account: Account,
    session: Session
  )
    requires ValidAccount(account)
    requires session in StateSessions(
                          AccountAuthorizationState(account)
                        )
    requires SessionIsRevoked(session)
    ensures SessionIdRecognizedInState(
              AccountAuthorizationState(account),
              SessionId(session)
            )
  {
    KipioAccountAuthorizationState.RevokedSessionRemainsRecognized(
      AccountAuthorizationState(account),
      session
    );
  }


  // A revoked Delegation remains recognized as an Entity.
  lemma RevokedDelegationRemainsRecognizedInAccountProof(
    account: Account,
    delegation: Delegation
  )
    requires ValidAccount(account)
    requires delegation in StateDelegations(
                             AccountAuthorizationState(account)
                           )
    requires DelegationIsRevoked(delegation)
    ensures DelegationIdRecognizedInState(
              AccountAuthorizationState(account),
              DelegationId(delegation)
            )
  {
    KipioAccountAuthorizationState.RevokedDelegationRemainsRecognized(
      AccountAuthorizationState(account),
      delegation
    );
  }


  // ==========================================================
  // COMPACT E2E ACCOUNT CONTRACT
  // ==========================================================

  // A valid Account exposes the complete structural proof boundary
  // needed by downstream scenarios.
  lemma ValidAccountProvidesReusableProofContract(
    account: Account
  )
    requires ValidAccount(account)
    ensures ValidId(AccountIdOf(account))
    ensures ValidIdentity(
              AccountSovereignIdentity(account)
            )
    ensures ValidAuthorizationState(
              AccountAuthorizationState(account)
            )
    ensures AccountSovereignIdentity(account)
         == account.identity
  {
    ValidAccountSatisfiesStructuralBoundaries(account);
    AccountHasOneSovereignIdentity(account);
  }


  // Any explicitly identity-preserving Account transition leaves the
  // semantic Account Entity and sovereign boundary unchanged.
  lemma AccountTransitionProvidesReusableIdentityContract(
    before: Account,
    after: Account
  )
    requires AccountTransitionPreservesIdentity(
               before,
               after
             )
    ensures SameAccount(before, after)
    ensures AccountSovereignIdentity(after)
         == AccountSovereignIdentity(before)
  {
    AccountTransitionPreservesAccountBoundary(
      before,
      after
    );

    assert AccountIdOf(before) == AccountIdOf(after);
    assert SameAccount(before, after);

    assert AccountSovereignIdentity(after)
        == AccountSovereignIdentity(before);
  }
}

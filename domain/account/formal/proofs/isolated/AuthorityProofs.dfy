// ============================================================
// KIPIO ACCOUNT DOMAIN
// PROOFS — AUTHORITY
// ============================================================
//
// Reusable proof facades for the Authority layer.
//
// Purpose:
//
//   - expose reusable Authority guarantees for E2E scenarios;
//   - compose existing domain predicates and transition contracts;
//   - avoid redefining semantic rules already established by the
//     authoritative domain modules and AccountTransitions.
//
// This file is intentionally a facade layer:
//
//   E2E scenario
//        ↓
//   AuthorityProofs
//        ↓
//   existing domain/lifecycle contract
//        ↓
//   authoritative semantics
//
// It does NOT:
//
//   - define new Authority semantics;
//   - duplicate Account transition semantics;
//   - calculate Effective Authority;
//   - define Authorization;
//   - verify Proof;
//   - consume Policy;
//   - execute Domain Actions;
//   - introduce infrastructure semantics.
//
// ------------------------------------------------------------
//
// PROVENANCE BOUNDARY
//
// AuthorizationState can establish:
//
//     recognized Delegation
//          ↓
//     recognized provenance
//          ↓
//     source-specific authority boundary
//
// This layer does NOT establish:
//
//     EffectiveAuthority
//          ↓
//     globally legitimate provenance
//
// because EffectiveAuthority provenance remains contextual and
// can combine multiple independent authority sources.
//
// ============================================================


// ============================================================
// IMPORTS
// ============================================================

include "../../authority/CredentialAuthority.dfy"
include "../../authority/Credential.dfy"
include "../../authority/Session.dfy"
include "../../authority/Delegation.dfy"
include "../../authority/EffectiveAuthority.dfy"
include "../../authority/AuthorizationState.dfy"

include "../../laws/AuthorityLaws.dfy"
include "../../laws/SessionLaws.dfy"
include "../../laws/DelegationLaws.dfy"

include "../../account/Account.dfy"
include "../../account/AccountTransitions.dfy"


module KipioAccountAuthorityProofs
{
  import opened KipioAccountDomainPrimitives
  import opened KipioAccountCapability

  import opened KipioAccountIdentity

  import opened KipioAccountCredential
  import opened KipioAccountCredentialAuthority

  import opened KipioAccountSession
  import opened KipioAccountDelegation
  import opened KipioAccountEffectiveAuthority
  import opened KipioAccountAuthorizationState

  import opened KipioAccountAuthorityLaws
  import opened KipioAccountSessionLaws
  import opened KipioAccountDelegationLaws

  import opened KipioAccountAccount
  import opened KipioAccountAccountTransitions



  // ============================================================
  // CREDENTIAL AUTHORITY
  // ============================================================

  // Reusable facade:
  // a Credential may exercise only a Capability contained in its
  // Credential Authority.
  lemma CredentialExerciseRemainsWithinCredentialAuthority(
    authority: CredentialAuthority,
    capability: Capability
  )
    requires CredentialCanExercise(
               authority,
               capability
             )
    ensures capability in authority
  {
  }


  // Reusable facade:
  // every Capability contained in a valid Credential Authority
  // is structurally valid.
  lemma ValidCredentialAuthorityContainsOnlyValidCapabilities(
    authority: CredentialAuthority,
    capability: Capability
  )
    requires ValidCredentialAuthority(authority)
    requires capability in authority
    ensures ValidCapability(capability)
  {
  }


  // Reusable monotonic-authority facade:
  // reducing Credential Authority cannot introduce authority.
  lemma ReducedCredentialAuthorityCannotExpand(
    original: CredentialAuthority,
    reduced: CredentialAuthority,
    capability: Capability
  )
    requires reduced <= original
    requires capability in reduced
    ensures capability in original
  {
  }



  // ============================================================
  // CREDENTIAL ENTITY / STATE
  // ============================================================

  // Reusable state-chain facade:
  // recognized Credential -> Credential Authority entry.
  lemma RecognizedCredentialHasAuthority(
    state: AuthorizationState,
    credential: Credential
  )
    requires ValidAuthorizationState(state)
    requires CredentialRecognizedInState(
               state,
               credential
             )
    ensures CredentialAuthorityDefinedInState(
              state,
              credential
            )
  {
  }


  // Reusable state-chain facade:
  // recognized Credential -> structurally valid Credential Authority.
  lemma RecognizedCredentialHasValidAuthority(
    state: AuthorizationState,
    credential: Credential
  )
    requires ValidAuthorizationState(state)
    requires CredentialRecognizedInState(
               state,
               credential
             )
    ensures ValidCredentialAuthority(
              StateCredentialAuthority(
                state,
                credential
              )
            )
  {
  }


  // Recognition and lifecycle status are distinct properties.
  lemma RevokedCredentialRemainsRecognized(
    state: AuthorizationState,
    credential: Credential
  )
    requires ValidAuthorizationState(state)
    requires credential in StateCredentials(state)
    requires CredentialIsRevoked(credential)
    ensures CredentialIdRecognizedInState(
              state,
              CredentialId(credential)
            )
  {
  }


  // Reusable negative facade:
  // an unusable Credential cannot simultaneously be Active.
  lemma InactiveCredentialCannotBeActive(
    credential: Credential
  )
    requires CredentialCannotCurrentlyExerciseAuthority(
               credential
             )
    ensures !CredentialIsActive(credential)
  {
  }



  // ============================================================
  // SESSION / CREDENTIAL AUTHORITY
  // ============================================================

  // Recognized Session -> recognized originating Credential.
  lemma RecognizedSessionReferencesRecognizedCredential(
    state: AuthorizationState,
    session: Session
  )
    requires ValidAuthorizationState(state)
    requires session in StateSessions(state)
    ensures CredentialIdRecognizedInState(
              state,
              SessionCredentialId(session)
            )
  {
  }


  // Recognized Session -> Credential Authority entry exists.
  lemma RecognizedSessionHasCredentialAuthority(
    state: AuthorizationState,
    session: Session
  )
    requires ValidAuthorizationState(state)
    requires session in StateSessions(state)
    ensures SessionCredentialAuthorityIsDefinedInState(
              state,
              session
            )
  {
  }


  // Reusable Session -> Credential authority boundary.
  lemma RecognizedSessionRespectsCredentialAuthority(
    state: AuthorizationState,
    session: Session
  )
    requires ValidAuthorizationState(state)
    requires session in StateSessions(state)
    ensures SessionAuthorityWithinCredentialAuthority(
              session,
              StateCredentialAuthorities(state)[
              SessionCredentialId(session)
              ]
            )
  {
  }


  // Capability-level facade over the Session authority boundary.
  lemma RecognizedSessionCapabilityCannotEscapeCredentialAuthority(
    state: AuthorizationState,
    session: Session,
    capability: Capability
  )
    requires ValidAuthorizationState(state)
    requires session in StateSessions(state)
    requires capability in SessionCapabilities(session)
    ensures capability in
              StateCredentialAuthorities(state)[
              SessionCredentialId(session)
              ]
  {
    RecognizedSessionRespectsCredentialAuthority(
      state,
      session
    );
  }


  // Reusable structural-validity facade.
  lemma RecognizedSessionCapabilityIsValid(
    state: AuthorizationState,
    session: Session,
    capability: Capability
  )
    requires ValidAuthorizationState(state)
    requires session in StateSessions(state)
    requires capability in SessionCapabilities(session)
    ensures ValidCapability(capability)
  {
  }


  // Reusable composed authority boundary:
  //
  //     EffectiveAuthority
  //          ⊆ SessionCapabilities
  //          ⊆ CredentialAuthority
  lemma SessionDerivedEffectiveAuthorityCannotEscapeCredentialAuthority(
    effectiveAuthority: EffectiveAuthority,
    session: Session,
    credentialAuthority: CredentialAuthority
  )
    requires effectiveAuthority <= SessionCapabilities(session)
    requires SessionAuthorityWithinCredentialAuthority(
               session,
               credentialAuthority
             )
    ensures effectiveAuthority <= credentialAuthority
  {
    EffectiveAuthorityDerivedThroughSessionCannotExceedCredentialAuthority(
      effectiveAuthority,
      session,
      credentialAuthority
    );
  }


  // Capability-level form of the same composed boundary.
  lemma SessionDerivedCapabilityCannotEscapeCredentialAuthority(
    effectiveAuthority: EffectiveAuthority,
    session: Session,
    credentialAuthority: CredentialAuthority,
    capability: Capability
  )
    requires effectiveAuthority <= SessionCapabilities(session)
    requires SessionAuthorityWithinCredentialAuthority(
               session,
               credentialAuthority
             )
    requires capability in effectiveAuthority
    ensures capability in credentialAuthority
  {
    SessionDerivedEffectiveAuthorityCannotEscapeCredentialAuthority(
      effectiveAuthority,
      session,
      credentialAuthority
    );
  }



  // ============================================================
  // SESSION LIFECYCLE
  // ============================================================

  lemma RevokedSessionCannotExerciseAuthority(
    session: Session,
    now: Timestamp
  )
    requires SessionIsRevoked(session)
    ensures !SessionCanCurrentlyExerciseAuthorityAt(
              session,
              now
            )
  {
  }


  lemma ExpiredSessionCannotExerciseAuthority(
    session: Session,
    now: Timestamp
  )
    requires SessionIsExpiredAt(session, now)
    ensures !SessionCanCurrentlyExerciseAuthorityAt(
              session,
              now
            )
  {
  }


  lemma ValidSessionRemainsValidAtUpperBoundary(
    session: Session
  )
    requires ValidSession(session)
    ensures SessionIsWithinValidityIntervalAt(
              session,
              SessionValidUntil(session)
            )
  {
  }


  lemma SessionCannotExerciseBeforeValidityBegins(
    session: Session,
    now: Timestamp
  )
    requires ValidSession(session)
    requires now < SessionValidFrom(session)
    ensures !SessionCanCurrentlyExerciseAuthorityAt(
              session,
              now
            )
  {
  }


  // Inactive originating Credential blocks Session contribution.
  lemma InactiveCredentialBlocksSessionContribution(
    state: AuthorizationState,
    session: Session,
    now: Timestamp
  )
    requires ValidAuthorizationState(state)
    requires session in StateSessions(state)
    requires CredentialIdRecognizedInState(
               state,
               SessionCredentialId(session)
             )
    requires !ActiveCredentialRecognizedInState(
               state,
               SessionCredentialId(session)
             )
    ensures !SessionCanContributeAuthorityAt(
              state,
              session,
              now
            )
  {
  }


  // Reusable negative scenario facade:
  // revoking the originating Credential blocks its dependent Session.
  lemma RevokedCredentialBlocksDependentSession(
    state: AuthorizationState,
    credential: Credential,
    session: Session,
    now: Timestamp
  )
    requires ValidAuthorizationState(state)
    requires credential in StateCredentials(state)
    requires session in StateSessions(state)
    requires CredentialIsRevoked(credential)
    requires CredentialId(credential)
          == SessionCredentialId(session)
    ensures !SessionCanContributeAuthorityAt(
              state,
              session,
              now
            )
  {
    InactiveCredentialBlocksSessionContribution(
      state,
      session,
      now
    );
  }



  // ============================================================
  // SESSION REGISTRATION
  // ============================================================

  // Facade directly aligned with RegisterSessionPreservesIdentity.
  lemma RegisterSessionPreservesAccountIdentity(
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
              RegisterSession(account, session)
            )
  {
    KipioAccountAccountTransitions.RegisterSessionPreservesIdentity(
      account,
      session
    );
  }


  // Facade directly aligned with RegisteredSessionBelongsToState.
  lemma RegisteredSessionBecomesRecognized(
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
                RegisterSession(account, session)
              ),
              SessionId(session)
            )
  {
    KipioAccountAccountTransitions.RegisteredSessionBelongsToState(
      account,
      session
    );
  }


  // Facade over the existing Session registration state-validity
  // contract. State validity implies that the Session authority
  // boundary remains represented in the resulting state.
  lemma RegisterSessionPreservesCredentialAuthorityBoundary(
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
    ensures SessionAuthorityWithinCredentialAuthority(
              session,
              StateCredentialAuthorities(
                AccountAuthorizationState(
                  RegisterSession(account, session)
                )
              )[SessionCredentialId(session)]
            )
  {
    KipioAccountAccountTransitions.RegisterSessionPreservesAuthorizationStateValidity(
      account,
      session
    );
  }



  // ============================================================
  // SESSION LIFECYCLE TRANSITIONS
  // ============================================================

  // Facade aligned with the canonical UpdateSessionStatus
  // identity contract.
  lemma SessionLifecycleTransitionPreservesEntityIdentity(
    account: Account,
    session: Session,
    status: SessionStatus
  )
    requires ValidAccount(account)
    requires session in StateSessions(
                          AccountAuthorizationState(account)
                        )
    requires ValidSessionStatusTransition(
               session,
               status
             )
    ensures exists updatedSession ::
              updatedSession in
                StateSessions(
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
    KipioAccountAccountTransitions.UpdatedSessionPreservesEntityIdentity(
      account,
      session,
      status
    );
  }


  // Session lifecycle keeps its authority definition unchanged.
  lemma SessionLifecycleTransitionPreservesAuthorityDefinition(
    account: Account,
    session: Session,
    status: SessionStatus
  )
    requires ValidAccount(account)
    requires session in StateSessions(
                          AccountAuthorizationState(account)
                        )
    requires ValidSessionStatusTransition(
               session,
               status
             )
    ensures exists updatedSession ::
              updatedSession in
                StateSessions(
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
              && SessionCredentialId(updatedSession)
                 == SessionCredentialId(session)
              && SessionCapabilities(updatedSession)
                 == SessionCapabilities(session)
              && SessionValidFrom(updatedSession)
                 == SessionValidFrom(session)
              && SessionValidUntil(updatedSession)
                 == SessionValidUntil(session)
              && SessionRestrictions(updatedSession)
                 == SessionRestrictions(session)
  {
  }


  // Facade aligned with the canonical state-validity contract.
  lemma SessionLifecycleTransitionPreservesStateValidity(
    account: Account,
    session: Session,
    status: SessionStatus
  )
    requires ValidAccount(account)
    requires session in StateSessions(
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



  // ============================================================
  // DELEGATION AUTHORITY
  // ============================================================

  // A Delegation cannot exceed its supplied Delegatable Authority.
  lemma DelegationCannotEscapeDelegatableAuthority(
    delegation: Delegation,
    delegatableAuthority: set<Capability>,
    capability: Capability
  )
    requires DelegationAuthorityWithinDelegatableAuthority(
               delegation,
               delegatableAuthority
             )
    requires capability in DelegationCapabilities(delegation)
    ensures capability in delegatableAuthority
  {
  }


  // Delegatable Authority cannot exceed Effective Authority.
  lemma DelegatableAuthorityCannotEscapeEffectiveAuthority(
    delegatableAuthority: set<Capability>,
    effectiveAuthority: EffectiveAuthority,
    capability: Capability
  )
    requires DelegatableAuthorityWithinEffectiveAuthority(
               delegatableAuthority,
               effectiveAuthority
             )
    requires capability in delegatableAuthority
    ensures capability in effectiveAuthority
  {
  }


  // Complete delegation authority chain:
  //
  //     Delegation
  //         ⊆
  //     DelegatableAuthority
  //         ⊆
  //     EffectiveAuthority
  lemma BoundedDelegationCannotEscapeEffectiveAuthority(
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    effectiveAuthority: EffectiveAuthority
  )
    requires DelegationAuthorityIsBounded(
               delegation,
               delegateCapability,
               delegatableAuthority,
               effectiveAuthority
             )
    ensures DelegationCapabilities(delegation)
         <= effectiveAuthority
  {
  }


  // The delegate Capability enables delegation but is not itself
  // the arbitrary delegated authority set.
  lemma DelegateCapabilityDoesNotBecomeArbitraryDelegatedAuthority(
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    effectiveAuthority: EffectiveAuthority
  )
    requires SourceHasDelegationCapability(
               effectiveAuthority,
               delegateCapability
             )
    requires DelegationAuthorityWithinDelegatableAuthority(
               delegation,
               delegatableAuthority
             )
    ensures DelegationCapabilities(delegation)
         <= delegatableAuthority
  {
  }


  lemma ValidDelegationContainsOnlyValidCapabilities(
    delegation: Delegation,
    capability: Capability
  )
    requires ValidDelegation(delegation)
    requires capability in DelegationCapabilities(delegation)
    ensures ValidCapability(capability)
  {
  }



  // ============================================================
  // TRANSITIVE DELEGATION
  // ============================================================

  lemma ChildDelegationCannotEscapeParent(
    childAuthority: set<Capability>,
    parentAuthority: set<Capability>,
    capability: Capability
  )
    requires TransitiveDelegationAuthorityIsBounded(
               childAuthority,
               parentAuthority
             )
    requires capability in childAuthority
    ensures capability in parentAuthority
  {
  }


  lemma ChildDelegationCannotEscapeSource(
    childAuthority: set<Capability>,
    parentAuthority: set<Capability>,
    sourceAuthority: set<Capability>
  )
    requires childAuthority <= parentAuthority
    requires parentAuthority <= sourceAuthority
    ensures childAuthority <= sourceAuthority
  {
  }


  lemma TwoLevelDelegationCannotExpandAuthority(
    grandChildAuthority: set<Capability>,
    parentAuthority: set<Capability>,
    sourceAuthority: set<Capability>,
    capability: Capability
  )
    requires grandChildAuthority <= parentAuthority
    requires parentAuthority <= sourceAuthority
    requires capability in grandChildAuthority
    ensures capability in sourceAuthority
  {
  }



  // ============================================================
  // DELEGATION / AUTHORIZATION STATE
  // ============================================================

  lemma RecognizedDelegationHasProvenance(
    state: AuthorizationState,
    delegation: Delegation
  )
    requires ValidAuthorizationState(state)
    requires delegation in StateDelegations(state)
    ensures DelegationProvenanceDefinedInState(
              state,
              delegation
            )
  {
  }


  lemma RecognizedDelegationParentsAreRecognized(
    state: AuthorizationState,
    delegation: Delegation
  )
    requires ValidAuthorizationState(state)
    requires delegation in StateDelegations(state)
    ensures DelegationProvenanceParentsBelongToState(
              state,
              delegation
            )
  {
  }


  lemma RecognizedDelegationCannotSelfReferenceProvenance(
    state: AuthorizationState,
    delegation: Delegation
  )
    requires ValidAuthorizationState(state)
    requires delegation in StateDelegations(state)
    ensures DelegationProvenanceHasNoSelfReference(
              state,
              delegation
            )
  {
  }


  lemma ProvenanceCannotInventDelegatedCapability(
    state: AuthorizationState,
    delegation: Delegation,
    capability: Capability
  )
    requires ValidAuthorizationState(state)
    requires delegation in StateDelegations(state)
    requires capability in DelegationCapabilities(delegation)
    requires DelegationHasParentProvenance(
               state,
               delegation
             )
    ensures exists parent ::
              parent in StateDelegations(state)
              && DelegationId(parent)
                 in StateDelegationParents(
                      state,
                      delegation
                    )
              && capability in DelegationCapabilities(parent)
  {
  }


  lemma EmptyProvenanceDoesNotCreateGlobalAuthorityProvenance(
    state: AuthorizationState,
    delegation: Delegation
  )
    requires ValidAuthorizationState(state)
    requires delegation in StateDelegations(state)
    requires DelegationProvenanceDefinedInState(
               state,
               delegation
             )
    requires |StateDelegationParents(state, delegation)| == 0
    ensures DelegationProvenanceDefinedInState(
              state,
              delegation
            )
  {
  }



  // ============================================================
  // ROOT DELEGATION REGISTRATION
  // ============================================================

  // Facade aligned with ValidRootDelegationRegistration and the
  // existing AccountTransitions identity contract.
  lemma RegisterDelegationPreservesAccountIdentity(
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


  // Facade aligned with the canonical registration recognition
  // contract.
  lemma RegisteredDelegationBecomesRecognized(
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


  // Facade aligned with the canonical root provenance contract.
  lemma RegisteredDelegationHasEmptyProvenance(
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
    ensures
      StateDelegationProvenance(
        AccountAuthorizationState(
          RegisterDelegation(
            account,
            delegation,
            delegateCapability,
            delegatableAuthority,
            sourceEffectiveAuthority
          )
        )
      )[DelegationId(delegation)] == {}
  {
    KipioAccountAccountTransitions.RegisteredDelegationHasEmptyProvenance(
      account,
      delegation,
      delegateCapability,
      delegatableAuthority,
      sourceEffectiveAuthority
    );
  }



  // ============================================================
  // TRANSITIVE DELEGATION REGISTRATION
  // ============================================================

  // Facade aligned exactly with the canonical transitive
  // registration contract.
  lemma RegisteredTransitiveDelegationPreservesProvenance(
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
    ensures
      StateDelegationParents(
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


  // Facade for the transitive parent-capability provenance
  // guarantee.
  lemma RegisteredTransitiveDelegationCannotInventCapability(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: EffectiveAuthority,
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
                          AccountAuthorizationState(account)
                        )
              && DelegationId(parent)
                 in parentDelegationIds
              && capability in DelegationCapabilities(parent)
  {
    // ValidTransitiveDelegationRegistration already contains the
    // parent-capability condition. The facade exposes its result in
    // the form most useful to E2E scenarios.
  }



  // ============================================================
  // DELEGATION LIFECYCLE
  // ============================================================

  // Facade aligned with the concrete AccountTransitions lifecycle
  // precondition and entity-identity contract.
  lemma DelegationLifecyclePreservesEntityIdentity(
    account: Account,
    delegation: Delegation,
    status: DelegationStatus
  )
    requires ValidAccount(account)
    requires delegation in StateDelegations(
                             AccountAuthorizationState(account)
                           )
    requires ValidDelegationStatusTransition(
               delegation,
               status
             )
    ensures exists updatedDelegation ::
              updatedDelegation in
                StateDelegations(
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


  // Facade exposing the complete immutable Delegation definition
  // preservation supplied by AccountTransitions.
  lemma DelegationLifecyclePreservesAuthorityDefinition(
    account: Account,
    delegation: Delegation,
    status: DelegationStatus
  )
    requires ValidAccount(account)
    requires delegation in StateDelegations(
                             AccountAuthorizationState(account)
                           )
    requires ValidDelegationStatusTransition(
               delegation,
               status
             )
    ensures exists updatedDelegation ::
              updatedDelegation in
                StateDelegations(
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
              && DelegationSourceIdentityId(updatedDelegation)
                 == DelegationSourceIdentityId(delegation)
              && DelegationDelegatee(updatedDelegation)
                 == DelegationDelegatee(delegation)
              && DelegationCapabilities(updatedDelegation)
                 == DelegationCapabilities(delegation)
              && DelegationValidFrom(updatedDelegation)
                 == DelegationValidFrom(delegation)
              && DelegationValidUntil(updatedDelegation)
                 == DelegationValidUntil(delegation)
              && DelegationRestrictions(updatedDelegation)
                 == DelegationRestrictions(delegation)
              && DelegationMetadata(updatedDelegation)
                 == DelegationMetadata(delegation)
              && DelegationStatusOf(updatedDelegation)
                 == status
  {
    KipioAccountAccountTransitions.UpdatedDelegationChangesOnlyLifecycleStatus(
      account,
      delegation,
      status
    );
  }


  // Facade aligned with the concrete provenance preservation
  // contract exposed by AccountTransitions.
  lemma DelegationLifecyclePreservesProvenance(
    account: Account,
    delegation: Delegation,
    status: DelegationStatus
  )
    requires ValidAccount(account)
    requires delegation in StateDelegations(
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


  // Recognition remains independent from Delegation revocation.
  lemma RevokedDelegationRemainsRecognized(
    state: AuthorizationState,
    delegation: Delegation
  )
    requires ValidAuthorizationState(state)
    requires delegation in StateDelegations(state)
    requires DelegationIsRevoked(delegation)
    ensures DelegationIdRecognizedInState(
              state,
              DelegationId(delegation)
            )
  {
  }


  lemma RevokedDelegationCannotContributeAuthority(
    delegation: Delegation,
    now: Timestamp
  )
    requires DelegationIsRevoked(delegation)
    ensures !DelegationCanCurrentlyExerciseAuthorityAt(
              delegation,
              now
            )
  {
  }


  lemma ExpiredDelegationCannotContributeAuthority(
    delegation: Delegation,
    now: Timestamp
  )
    requires DelegationIsExpiredAt(delegation, now)
    ensures !DelegationCanCurrentlyExerciseAuthorityAt(
              delegation,
              now
            )
  {
  }



  // ============================================================
  // EFFECTIVE AUTHORITY
  // ============================================================

  lemma ValidEffectiveAuthorityContainsOnlyValidCapabilities(
    effectiveAuthority: EffectiveAuthority,
    capability: Capability
  )
    requires ValidEffectiveAuthority(effectiveAuthority)
    requires capability in effectiveAuthority
    ensures ValidCapability(capability)
  {
  }


  lemma EffectiveAuthorityCannotEscapeSource(
    effectiveAuthority: EffectiveAuthority,
    sourceAuthority: set<Capability>,
    capability: Capability
  )
    requires EffectiveAuthorityWithinSourceAuthority(
               effectiveAuthority,
               sourceAuthority
             )
    requires capability in effectiveAuthority
    ensures capability in sourceAuthority
  {
  }


  lemma EffectiveAuthorityRespectsMultipleSourceBoundaries(
    effectiveAuthority: EffectiveAuthority,
    firstSource: set<Capability>,
    secondSource: set<Capability>,
    capability: Capability
  )
    requires EffectiveAuthorityWithinSourceAuthority(
               effectiveAuthority,
               firstSource
             )
    requires EffectiveAuthorityWithinSourceAuthority(
               effectiveAuthority,
               secondSource
             )
    requires capability in effectiveAuthority
    ensures capability in firstSource
    ensures capability in secondSource
  {
  }


  lemma ReducedEffectiveAuthorityCannotExpand(
    originalAuthority: EffectiveAuthority,
    reducedAuthority: EffectiveAuthority,
    capability: Capability
  )
    requires reducedAuthority <= originalAuthority
    requires capability in reducedAuthority
    ensures capability in originalAuthority
  {
  }



  // ============================================================
  // GENERIC AUTHORITY COMPOSITION
  // ============================================================

  lemma DerivedAuthorityCannotEscapeSource(
    derivedAuthority: set<Capability>,
    sourceAuthority: set<Capability>,
    capability: Capability
  )
    requires derivedAuthority <= sourceAuthority
    requires capability in derivedAuthority
    ensures capability in sourceAuthority
  {
  }


  lemma ChainedAuthorityReductionsCannotExpand(
    derivedAuthority: set<Capability>,
    intermediateAuthority: set<Capability>,
    sourceAuthority: set<Capability>
  )
    requires derivedAuthority <= intermediateAuthority
    requires intermediateAuthority <= sourceAuthority
    ensures derivedAuthority <= sourceAuthority
  {
  }



  // ============================================================
  // FINAL AUTHORITY BOUNDARY
  // ============================================================

  // This file is a reusable E2E facade layer.
  //
  // It intentionally exposes convenient Authority guarantees
  // while delegating transition semantics to AccountTransitions.
  //
  // It does NOT establish:
  //
  //   - global EffectiveAuthority provenance;
  //   - Authorization validity;
  //   - Proof validity;
  //   - Policy applicability;
  //   - Execution validity.
}

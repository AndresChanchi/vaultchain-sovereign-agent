// ============================================================
// KIPIO ACCOUNT DOMAIN
// LAWS — SESSION
// ============================================================
//
// Cross-concept semantic laws concerning Session.
//
// Session.dfy defines the local semantics of the Session Entity:
//
//   - Session identity is determined by SessionId;
//   - Session references a Credential by CredentialId;
//   - Session authority is represented by its Capability set;
//   - Session has a persistent lifecycle;
//   - temporal expiration is derived, not persisted;
//   - Session authority is bounded by Credential Authority.
//
// AuthorizationState.dfy defines the Account-level recognition
// relationships and state invariants involving Sessions:
//
//   - recognized Session identity uniqueness;
//   - Session → Credential recognition;
//   - Session → Credential Authority association;
//   - Session authority bounded by the recognized Credential
//     Authority.
//
// AccountTransitions.dfy defines the concrete state transitions
// that register and update Sessions.
//
// This file intentionally does NOT duplicate those local or
// transition-level laws.
//
// Instead, it formalizes cross-concept consequences that arise
// when Session semantics are composed with Credential lifecycle,
// AuthorizationState recognition and temporal evaluation.
//
// ------------------------------------------------------------
//
// DDD BOUNDARY
//
// These laws preserve the distinctions:
//
//     Session Identity
//         !=
//     Credential Identity
//
//     Entity Recognition
//         !=
//     Lifecycle State
//
//     Lifecycle State
//         !=
//     Temporal Validity
//
//     Session Authority
//         ⊆
//     Credential Authority
//
// and:
//
//     inactive Credential
//         ⇒
//     dependent recognized Session cannot contribute authority
//
// without requiring the Session Entity itself to be removed.
//
// ------------------------------------------------------------
//
// RESPONSIBILITY BOUNDARY
//
// This file does NOT define:
//
//   - Session representation;
//   - Session identity;
//   - Session lifecycle transitions;
//   - Session registration implementation;
//   - Account sovereignty;
//   - Credential lifecycle transitions;
//   - Credential Authority calculation;
//   - AuthorizationState definition;
//   - Effective Authority calculation;
//   - Authorization validation;
//   - Policy;
//   - Proof verification;
//   - Execution;
//   - blockchain representation.
//
// Those concerns belong to their corresponding domain modules.
//
// ------------------------------------------------------------
//
// DESIGN PRINCIPLE
//
// SessionLaws adds only laws that require reasoning across the
// Session boundary and another domain concept or state boundary.
//
// Local Session laws remain in Session.dfy.
// Account-state invariants remain in AuthorizationState.dfy.
// Concrete Account transitions remain in AccountTransitions.dfy.
//
// ============================================================

include "../foundation/DomainPrimitives.dfy"
include "../foundation/Capability.dfy"
include "../authority/Credential.dfy"
include "../authority/CredentialAuthority.dfy"
include "../authority/Session.dfy"
include "../authority/AuthorizationState.dfy"

module KipioAccountSessionLaws
{
  import opened KipioAccountDomainPrimitives
  import opened KipioAccountCapability
  import opened KipioAccountCredential
  import opened KipioAccountCredentialAuthority
  import opened KipioAccountSession
  import opened KipioAccountAuthorizationState


  // ----------------------------------------------------------
  // SESSION / CREDENTIAL RECOGNITION
  // ----------------------------------------------------------

  // A recognized Session necessarily refers to a Credential
  // recognized by the same Authorization State.
  //
  // The state-level invariant belongs to AuthorizationState.dfy;
  // this law exposes that consequence at the Session cross-concept
  // boundary.
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


  // A recognized Session necessarily has a Credential Authority
  // defined for its originating Credential.
  //
  // This composes Session → Credential recognition with the
  // Credential Authority association maintained by
  // AuthorizationState.
  lemma RecognizedSessionHasCredentialAuthority(
    state: AuthorizationState,
    session: Session
  )
    requires ValidAuthorizationState(state)
    requires session in StateSessions(state)
    ensures CredentialAuthorityDefinedForCredentialId(
              state,
              SessionCredentialId(session)
            )
  {
  }


  // A recognized Session cannot exceed the Credential Authority
  // assigned to its originating Credential.
  //
  // Composition:
  //
  //     recognized Session
  //          ↓
  //     recognized Credential
  //          ↓
  //     defined Credential Authority
  //          ↓
  //     SessionCapabilities
  //          ⊆
  //     CredentialAuthority
  //
  // The underlying state invariant is defined in
  // AuthorizationState.dfy.
  lemma RecognizedSessionCannotExceedCredentialAuthority(
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
  }


  // ----------------------------------------------------------
  // TEMPORAL SESSION / AUTHORITY SEPARATION
  // ----------------------------------------------------------

  // At validUntil exactly, the Session remains inside its validity
  // interval.
  //
  // This exposes the endpoint semantics at a cross-concept
  // temporal boundary without introducing another lifecycle state.
  lemma SessionIsValidAtItsUpperTemporalBoundary(
    session: Session
  )
    requires ValidSession(session)
    ensures SessionIsWithinValidityIntervalAt(
              session,
              SessionValidUntil(session)
            )
  {
  }


  // Before validFrom, the Session cannot currently exercise
  // authority.
  //
  // This explicitly separates temporal validity from persistent
  // lifecycle state.
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


  // ----------------------------------------------------------
  // CREDENTIAL LIFECYCLE / SESSION USABILITY
  // ----------------------------------------------------------

  // A recognized Session whose originating Credential is inactive
  // cannot contribute authority.
  //
  // The Session Entity remains recognized; Credential lifecycle
  // blocks current authority contribution.
  //
  // This is genuinely cross-concept because it composes:
  //
  //     AuthorizationState
  //          +
  //     Session
  //          +
  //     Credential lifecycle
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


  // A revoked Credential blocks contribution from the dependent
  // Session.
  //
  // The Credential and Session remain separate Entities. Revoking
  // the Credential therefore affects Session usability without
  // changing Session identity or requiring Session removal.
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
  }


  // ----------------------------------------------------------
  // SESSION / CREDENTIAL AUTHORITY VALIDITY
  // ----------------------------------------------------------

  // Every capability represented by a recognized valid Session is
  // structurally valid.
  //
  // This crosses the Session validity boundary and the Account
  // recognition boundary.
  lemma RecognizedValidSessionContainsOnlyValidCapabilities(
    state: AuthorizationState,
    session: Session,
    capability: Capability
  )
    requires ValidAuthorizationState(state)
    requires session in StateSessions(state)
    requires ValidSession(session)
    requires capability in SessionCapabilities(session)
    ensures ValidCapability(capability)
  {
  }
}

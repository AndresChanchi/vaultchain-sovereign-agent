// ============================================================
// KIPIO ACCOUNT DOMAIN
// AUTHORITY — SESSION
// ============================================================
//
// Session is an Entity representing temporary authority derived
// from a Credential recognized by an Account.
//
// Session identity is determined by SessionId.
//
// A Session refers to its originating Credential by CredentialId.
// The Credential Entity itself remains owned by AuthorizationState.
//
// Session authority is bounded by the Credential Authority assigned
// to that Credential within the relevant Account state.
//
// Lifecycle semantics:
//
//     Active
//       │
//       ├── revoke ──► Revoked
//       │
//       └── time passes beyond validUntil
//                    ↓
//                 Expired
//
// Expired is a derived temporal condition, not a persistent
// lifecycle state.
//
// A Session therefore separates:
//
//     Entity identity
//         = SessionId
//
//     Credential relationship
//         = CredentialId
//
//     Persistent lifecycle
//         = Active | Revoked
//
//     Temporal validity
//         = derived from validFrom / validUntil / time
//
//     Delegated authority
//         = Session capabilities
//
// This file intentionally contains no:
//   - credential verification logic
//   - credential lifecycle transitions
//   - credential recognition in Account state
//   - delegation logic
//   - effective authority calculation
//   - authorization validation
//   - policy logic
//   - execution logic
//   - cryptographic mechanism definitions
//   - blockchain ABI types
//   - storage representations
//
// ============================================================

include "../foundation/DomainPrimitives.dfy"
include "../foundation/Capability.dfy"
include "../foundation/Restriction.dfy"
include "CredentialAuthority.dfy"

module KipioAccountSession
{
  import opened KipioAccountDomainPrimitives
  import opened KipioAccountCapability
  import opened KipioAccountRestriction
  import opened KipioAccountCredentialAuthority


  // ----------------------------------------------------------
  // SESSION STATUS
  // ----------------------------------------------------------

  // Persistent lifecycle state of a Session.
  //
  // Active:
  //   The Session has not been revoked.
  //
  // Revoked:
  //   The Session remains the same Entity but cannot currently
  //   participate in effective authority.
  //
  // Expired is intentionally not represented as a status.
  // Expiration is derived from the validity interval and the
  // evaluation timestamp.
  datatype SessionStatus =
      Active
    | Revoked


  // ----------------------------------------------------------
  // SESSION
  // ----------------------------------------------------------

  // Session is an Entity representing temporary authority
  // derived from a Credential.
  //
  // The originating Credential is referenced by CredentialId
  // rather than embedded as a Credential value.
  //
  // This preserves the Entity boundary:
  //
  //     Session
  //         │
  //         └── CredentialId
  //                  │
  //                  ▼
  //             Credential Entity
  //
  // Credential lifecycle therefore remains independently
  // represented in AuthorizationState.
  datatype Session =
    Session(
      id: Id,
      credentialId: Id,
      capabilities: set<Capability>,
      validFrom: Timestamp,
      validUntil: Timestamp,
      restrictions: set<Restriction>,
      status: SessionStatus
    )


  // ----------------------------------------------------------
  // ACCESSORS
  // ----------------------------------------------------------

  // Returns the stable identifier of the Session Entity.
  function SessionId(
    session: Session
  ): Id
  {
    session.id
  }


  // Returns the identifier of the Credential from which the
  // Session was derived.
  function SessionCredentialId(
    session: Session
  ): Id
  {
    session.credentialId
  }


  // Returns the Capabilities that the Session may attempt to
  // exercise before further contextual conditions are applied.
  function SessionCapabilities(
    session: Session
  ): set<Capability>
  {
    session.capabilities
  }


  // Returns the beginning of the Session validity interval.
  function SessionValidFrom(
    session: Session
  ): Timestamp
  {
    session.validFrom
  }


  // Returns the end of the Session validity interval.
  function SessionValidUntil(
    session: Session
  ): Timestamp
  {
    session.validUntil
  }


  // Returns the Restrictions associated with the Session.
  function SessionRestrictions(
    session: Session
  ): set<Restriction>
  {
    session.restrictions
  }


  // Returns the persistent lifecycle status of the Session.
  function SessionStatusOf(
    session: Session
  ): SessionStatus
  {
    session.status
  }


  // ----------------------------------------------------------
  // LIFECYCLE PREDICATES
  // ----------------------------------------------------------

  // A Session is persistently active when its lifecycle status is
  // Active.
  predicate SessionIsActive(
    session: Session
  )
  {
    SessionStatusOf(session) == Active
  }


  // A Session is persistently revoked when its lifecycle status is
  // Revoked.
  predicate SessionIsRevoked(
    session: Session
  )
  {
    SessionStatusOf(session) == Revoked
  }


  // A Session is expired at a given time when evaluation occurs
  // strictly after validUntil.
  //
  // validUntil itself is included in the valid interval.
  predicate SessionIsExpiredAt(
    session: Session,
    now: Timestamp
  )
  {
    now > SessionValidUntil(session)
  }


  // A Session is inside its validity interval when:
  //
  //     validFrom <= now <= validUntil
  //
  // Endpoint semantics are therefore explicit:
  //
  //     validFrom  = included
  //     validUntil = included
  predicate SessionIsWithinValidityIntervalAt(
    session: Session,
    now: Timestamp
  )
  {
    SessionValidFrom(session) <= now
    && now <= SessionValidUntil(session)
  }


  // A Session can currently participate in authority exercise only
  // when:
  //
  //   - its structural state is valid;
  //   - its lifecycle status is Active;
  //   - the current time lies inside its validity interval.
  //
  // This predicate does not calculate Effective Authority.
  //
  // It only establishes the Session-side conditions required before
  // higher-level authority evaluation can consider the Session.
  predicate SessionCanCurrentlyExerciseAuthorityAt(
    session: Session,
    now: Timestamp
  )
  {
    ValidSession(session)
    && SessionIsActive(session)
    && SessionIsWithinValidityIntervalAt(session, now)
  }


  // ----------------------------------------------------------
  // STRUCTURAL VALIDITY
  // ----------------------------------------------------------

  // A valid Session contains:
  //
  //   - a valid SessionId;
  //   - a valid originating CredentialId;
  //   - a well-formed validity interval;
  //   - valid Capabilities;
  //   - valid Restrictions.
  //
  // SessionStatus is structurally exhaustive by construction.
  //
  // Structural validity does not establish:
  //
  //   - Credential recognition by an Account;
  //   - Credential lifecycle validity;
  //   - Credential Authority;
  //   - Session Authority subset;
  //   - Effective Authority;
  //   - Authorization validity.
  predicate ValidSession(
    session: Session
  )
  {
    ValidId(SessionId(session))
    && ValidId(SessionCredentialId(session))
    && SessionValidFrom(session) <= SessionValidUntil(session)

    && (forall capability ::
          capability in SessionCapabilities(session)
          ==> ValidCapability(capability))

    && (forall restriction ::
          restriction in SessionRestrictions(session)
          ==> ValidRestriction(restriction))
  }


  // ----------------------------------------------------------
  // ENTITY IDENTITY
  // ----------------------------------------------------------

  // Determines whether two Session values refer to the same
  // semantic Session Entity.
  //
  // Entity identity depends only on SessionId.
  //
  // The following do not determine Entity identity:
  //
  //   - CredentialId;
  //   - lifecycle status;
  //   - Capabilities;
  //   - Restrictions;
  //   - validity interval.
  predicate SameSession(
    left: Session,
    right: Session
  )
  {
    SessionId(left) == SessionId(right)
  }


  // Two Sessions with the same SessionId refer to the same
  // semantic Session Entity.
  lemma SessionsWithEqualIdsAreSameEntity(
    left: Session,
    right: Session
  )
    requires SessionId(left) == SessionId(right)
    ensures SameSession(left, right)
  {
  }


  // Two Sessions with distinct SessionIds cannot refer to the same
  // semantic Session Entity.
  lemma SessionsWithDistinctIdsAreNotTheSameEntity(
    left: Session,
    right: Session
  )
    requires SessionId(left) != SessionId(right)
    ensures !SameSession(left, right)
  {
  }


  // Equal Dafny Session values necessarily expose equal SessionIds.
  lemma EqualSessionsHaveEqualIds(
    left: Session,
    right: Session
  )
    requires left == right
    ensures SessionId(left) == SessionId(right)
  {
  }


  // Equal Dafny Session values necessarily expose equal
  // CredentialIds.
  lemma EqualSessionsHaveEqualCredentialIds(
    left: Session,
    right: Session
  )
    requires left == right
    ensures SessionCredentialId(left)
         == SessionCredentialId(right)
  {
  }


  // Equal Dafny Session values necessarily expose equal Session
  // authority.
  lemma EqualSessionsHaveEqualCapabilities(
    left: Session,
    right: Session
  )
    requires left == right
    ensures SessionCapabilities(left)
         == SessionCapabilities(right)
  {
  }


  // ----------------------------------------------------------
  // VALIDITY LAWS
  // ----------------------------------------------------------

  // A valid Session exposes a valid SessionId.
  lemma ValidSessionHasValidId(
    session: Session
  )
    requires ValidSession(session)
    ensures ValidId(SessionId(session))
  {
  }


  // A valid Session exposes a valid originating CredentialId.
  lemma ValidSessionHasValidCredentialId(
    session: Session
  )
    requires ValidSession(session)
    ensures ValidId(SessionCredentialId(session))
  {
  }


  // A valid Session contains only valid Capabilities.
  lemma ValidSessionHasValidCapabilities(
    session: Session,
    capability: Capability
  )
    requires ValidSession(session)
    requires capability in SessionCapabilities(session)
    ensures ValidCapability(capability)
  {
  }


  // A valid Session contains only valid Restrictions.
  lemma ValidSessionHasValidRestrictions(
    session: Session,
    restriction: Restriction
  )
    requires ValidSession(session)
    requires restriction in SessionRestrictions(session)
    ensures ValidRestriction(restriction)
  {
  }


  // ----------------------------------------------------------
  // SESSION AUTHORITY BOUNDARY
  // ----------------------------------------------------------

  // A Session may only attempt Capabilities contained in the
  // Credential Authority from which it was derived.
  //
  // Credential Authority is supplied by AuthorizationState.
  // This file deliberately does not resolve SessionCredentialId
  // into a particular AuthorizationState.
  predicate SessionAuthorityWithinCredentialAuthority(
    session: Session,
    credentialAuthority: CredentialAuthority
  )
  {
    SessionCapabilities(session) <= credentialAuthority
  }


  // A Session satisfying the authority subset relation cannot
  // introduce a Capability absent from its Credential Authority.
  lemma SessionCannotAddCredentialAuthority(
    session: Session,
    credentialAuthority: CredentialAuthority,
    capability: Capability
  )
    requires SessionAuthorityWithinCredentialAuthority(
               session,
               credentialAuthority
             )
    requires capability in SessionCapabilities(session)
    ensures capability in credentialAuthority
  {
  }


  // ----------------------------------------------------------
  // LIFECYCLE LAWS
  // ----------------------------------------------------------

  // A revoked Session is not persistently active.
  lemma RevokedSessionIsNotActive(
    session: Session
  )
    requires SessionIsRevoked(session)
    ensures !SessionIsActive(session)
  {
  }


  // An expired Session is outside its validity interval at the
  // evaluation time.
  lemma ExpiredSessionIsOutsideValidityInterval(
    session: Session,
    now: Timestamp
  )
    requires SessionIsExpiredAt(session, now)
    ensures !SessionIsWithinValidityIntervalAt(session, now)
  {
  }


  // A revoked Session cannot currently participate in authority
  // exercise.
  lemma RevokedSessionCannotCurrentlyExerciseAuthority(
    session: Session,
    now: Timestamp
  )
    requires SessionIsRevoked(session)
    ensures !SessionCanCurrentlyExerciseAuthorityAt(session, now)
  {
  }


  // An expired Session cannot currently participate in authority
  // exercise.
  lemma ExpiredSessionCannotCurrentlyExerciseAuthority(
    session: Session,
    now: Timestamp
  )
    requires SessionIsExpiredAt(session, now)
    ensures !SessionCanCurrentlyExerciseAuthorityAt(session, now)
  {
  }


  // ----------------------------------------------------------
  // TEMPORAL LAWS
  // ----------------------------------------------------------

  // A valid Session has an ordered validity interval.
  lemma ValidSessionHasValidInterval(
    session: Session
  )
    requires ValidSession(session)
    ensures SessionValidFrom(session)
         <= SessionValidUntil(session)
  {
  }
}

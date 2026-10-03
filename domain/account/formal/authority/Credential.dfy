// ============================================================
// KIPIO ACCOUNT DOMAIN
// AUTHORITY — CREDENTIAL
// ============================================================
//
// Credential semantics for the Account domain.
//
// Credential is an Entity representing a recognized source
// through which authority may be exercised.
//
// Credential identity is determined by CredentialId.
// Credential lifecycle is represented independently from the
// identity of the Credential.
//
// Credential intentionally does not contain:
//   - Identity ownership;
//   - Account ownership;
//   - Credential Authority;
//   - cryptographic implementation details;
//   - Proof;
//   - blockchain addresses;
//   - execution state.
//
// Those relationships belong to the corresponding domain state
// or infrastructure bounded contexts.
//
// Lifecycle:
//
//     Active
//       │
//       ├── suspend ──► Suspended
//       │                  │
//       │                  └── reactivate ──► Active
//       │
//       └── revoke ───────► Revoked
//
// "Reactivated" is intentionally modeled as a transition back to
// Active rather than as an independent persistent state.
//
// ============================================================

include "../foundation/DomainPrimitives.dfy"

module KipioAccountCredential
{
  import opened KipioAccountDomainPrimitives


  // ----------------------------------------------------------
  // CREDENTIAL STATUS
  // ----------------------------------------------------------

  // Operational lifecycle state of a Credential.
  //
  // Active:
  //   The Credential may currently participate in authority
  //   evaluation, subject to the remaining Account conditions.
  //
  // Suspended:
  //   The Credential remains recognized as the same Entity but
  //   cannot currently produce effective authority.
  //
  // Revoked:
  //   The Credential remains historically identifiable but cannot
  //   currently produce effective authority.
  //
  // Reactivation is not a separate state. It is a transition from
  // Suspended back to Active.
  datatype CredentialStatus =
      Active
    | Suspended
    | Revoked


  // ----------------------------------------------------------
  // CREDENTIAL
  // ----------------------------------------------------------

  // Credential is an Entity with a stable identity and an
  // independent operational lifecycle.
  //
  // The Credential itself does not embed:
  //
  //   Credential Authority
  //   Account recognition
  //   Identity ownership
  //
  // because those relations are contextual and belong to
  // AuthorizationState.
  datatype Credential =
    Credential(
      id: Id,
      status: CredentialStatus
    )


  // ----------------------------------------------------------
  // ACCESSORS
  // ----------------------------------------------------------

  // Returns the stable identifier of the Credential Entity.
  function CredentialId(
    credential: Credential
  ): Id
  {
    credential.id
  }


  // Returns the current lifecycle status of the Credential.
  function CredentialStatusOf(
    credential: Credential
  ): CredentialStatus
  {
    credential.status
  }


  // ----------------------------------------------------------
  // LIFECYCLE PREDICATES
  // ----------------------------------------------------------

  // A Credential is active exactly when its lifecycle state is
  // Active.
  predicate CredentialIsActive(
    credential: Credential
  )
  {
    CredentialStatusOf(credential) == Active
  }


  // A Credential is suspended exactly when its lifecycle state is
  // Suspended.
  predicate CredentialIsSuspended(
    credential: Credential
  )
  {
    CredentialStatusOf(credential) == Suspended
  }


  // A Credential is revoked exactly when its lifecycle state is
  // Revoked.
  predicate CredentialIsRevoked(
    credential: Credential
  )
  {
    CredentialStatusOf(credential) == Revoked
  }


  // A Credential whose status is not Active cannot currently
  // exercise effective authority.
  //
  // This is an authority-lifecycle boundary, not cryptographic
  // verification logic.
  predicate CredentialCannotCurrentlyExerciseAuthority(
    credential: Credential
  )
  {
    !CredentialIsActive(credential)
  }


  // ----------------------------------------------------------
  // VALIDITY
  // ----------------------------------------------------------

  // A Credential is structurally valid when its identity is valid.
  //
  // Every CredentialStatus constructor is intrinsically well formed,
  // so no additional status-validity predicate is required.
  //
  // Structural validity does not mean that the Credential is
  // currently active or authorized.
  predicate ValidCredential(
    credential: Credential
  )
  {
    ValidId(CredentialId(credential))
  }


  // ----------------------------------------------------------
  // ENTITY IDENTITY
  // ----------------------------------------------------------

  // Determines whether two Credential values refer to the same
  // semantic Credential Entity.
  //
  // Entity identity is determined by CredentialId rather than by
  // the current lifecycle status.
  predicate SameCredential(
    left: Credential,
    right: Credential
  )
  {
    CredentialId(left) == CredentialId(right)
  }


  // Two Credentials with the same CredentialId represent the same
  // semantic Credential Entity.
  //
  // Their lifecycle status may differ because lifecycle state is
  // mutable state of the same Entity.
  lemma CredentialsWithEqualIdsAreSameEntity(
    left: Credential,
    right: Credential
  )
    requires CredentialId(left) == CredentialId(right)
    ensures SameCredential(left, right)
  {
  }


  // Two Credentials with distinct CredentialIds cannot represent
  // the same semantic Credential Entity.
  lemma CredentialsWithDistinctIdsAreNotTheSameEntity(
    left: Credential,
    right: Credential
  )
    requires CredentialId(left) != CredentialId(right)
    ensures !SameCredential(left, right)
  {
  }


  // Equal Dafny Credential values necessarily expose equal IDs.
  //
  // This is structural equality and therefore stronger than
  // semantic Entity identity.
  lemma EqualCredentialsHaveEqualIds(
    left: Credential,
    right: Credential
  )
    requires left == right
    ensures CredentialId(left) == CredentialId(right)
  {
  }


  // Equal Dafny Credential values necessarily expose equal status.
  lemma EqualCredentialsHaveEqualStatus(
    left: Credential,
    right: Credential
  )
    requires left == right
    ensures CredentialStatusOf(left)
         == CredentialStatusOf(right)
  {
  }


  // ----------------------------------------------------------
  // LIFECYCLE INVARIANTS
  // ----------------------------------------------------------

  // A Credential that is suspended is not active.
  lemma SuspendedCredentialIsNotActive(
    credential: Credential
  )
    requires CredentialIsSuspended(credential)
    ensures !CredentialIsActive(credential)
  {
  }


  // A Credential that is revoked is not active.
  lemma RevokedCredentialIsNotActive(
    credential: Credential
  )
    requires CredentialIsRevoked(credential)
    ensures !CredentialIsActive(credential)
  {
  }


  // A non-active Credential cannot currently exercise effective
  // authority.
  lemma InactiveCredentialCannotExerciseEffectiveAuthority(
    credential: Credential
  )
    requires CredentialCannotCurrentlyExerciseAuthority(credential)
    ensures !CredentialIsActive(credential)
  {
  }


  // ----------------------------------------------------------
  // VALIDITY LAWS
  // ----------------------------------------------------------

  // A valid Credential exposes a valid CredentialId.
  lemma ValidCredentialHasValidId(
    credential: Credential
  )
    requires ValidCredential(credential)
    ensures ValidId(CredentialId(credential))
  {
  }


  // ----------------------------------------------------------
  // IDENTITY / LIFECYCLE SEPARATION
  // ----------------------------------------------------------

  // Changing lifecycle state does not itself create a different
  // Credential Entity.
  //
  // This law intentionally uses SameCredential rather than Dafny
  // structural equality:
  //
  //     same CredentialId + different status
  //         =
  //     same Entity in a different lifecycle state
  lemma LifecycleStateDoesNotChangeCredentialIdentity(
    activeCredential: Credential,
    changedCredential: Credential
  )
    requires CredentialId(activeCredential)
          == CredentialId(changedCredential)
    ensures SameCredential(
              activeCredential,
              changedCredential
            )
  {
  }
}

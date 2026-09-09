// ============================================================
// KIPIO ACCOUNT DOMAIN
// AUTHORITY — CREDENTIAL AUTHORITY
// ============================================================
//
// Credential Authority represents the set of Capabilities that
// a Credential may attempt to exercise within one Account's
// Authorization State.
//
// Credential Authority is a Value Object.
//
// The Credential, Account, and their recognition relationship are
// intentionally NOT embedded in this value.
//
// The association:
//
//     Credential
//          │
//          ▼
//     Credential Authority
//
// belongs to AuthorizationState.
//
// This allows the same Credential to be recognized by multiple
// Accounts while each Account may assign a different authority
// value to that Credential.
//
// Credential Authority is distinct from:
//
//     Capability
//         = what faculty exists
//
//     Credential Authority
//         = what a recognized Credential may attempt to exercise
//
//     Effective Authority
//         = what may actually be exercised in a concrete context
//
// Credential Authority does not itself establish:
//
//   - Credential validity;
//   - Credential lifecycle validity;
//   - Session validity;
//   - Delegation validity;
//   - Restriction satisfaction;
//   - Policy applicability;
//   - temporal validity;
//   - replay validity;
//   - Proof validity;
//   - Effective Authority.
//
// Those concerns belong to the corresponding domain contexts.
//
// ============================================================

include "../foundation/Capability.dfy"

module KipioAccountCredentialAuthority
{
  import opened KipioAccountCapability


  // ----------------------------------------------------------
  // CREDENTIAL AUTHORITY
  // ----------------------------------------------------------

  // Credential Authority is a Value Object represented by the
  // set of Capabilities that a recognized Credential may attempt
  // to exercise within one Account.
  //
  // Because Capability is a Value Object, set semantics naturally
  // provide value semantics for Credential Authority.
  //
  // No CredentialId, AccountId, or other identity is embedded here.
  type CredentialAuthority = set<Capability>


  // ----------------------------------------------------------
  // MEMBERSHIP
  // ----------------------------------------------------------

  // Determines whether a Capability belongs to a Credential
  // Authority value.
  //
  // Membership is a necessary condition for a Credential to
  // attempt to exercise that Capability.
  //
  // Membership is NOT sufficient for Effective Authority because
  // Sessions, Delegations, Restrictions, Policies, temporal
  // conditions, replay state, and other contextual rules may
  // further reduce the authority available at a particular time.
  predicate CredentialCanExercise(
    authority: CredentialAuthority,
    capability: Capability
  )
  {
    capability in authority
  }


  // Explicit semantic boundary between:
  //
  //     "may attempt"
  //
  // and:
  //
  //     "may actually exercise now".
  //
  // The latter belongs to Effective Authority.
  predicate CredentialAuthorityPermitsAttempt(
    authority: CredentialAuthority,
    capability: Capability
  )
  {
    CredentialCanExercise(authority, capability)
  }


  // ----------------------------------------------------------
  // VALUE OBJECT SEMANTICS
  // ----------------------------------------------------------

  // Credential Authority has no independent identity.
  //
  // Two Credential Authority values with the same set of
  // Capabilities represent the same semantic authority value.
  predicate SameCredentialAuthority(
    left: CredentialAuthority,
    right: CredentialAuthority
  )
  {
    left == right
  }


  // Equal Credential Authority values are the same Value Object.
  lemma CredentialAuthoritiesWithSameValuesAreEqual(
    left: CredentialAuthority,
    right: CredentialAuthority
  )
    requires SameCredentialAuthority(left, right)
    ensures left == right
  {
  }


  // A Credential Authority has no identity beyond its value.
  lemma CredentialAuthorityHasNoIndependentIdentity(
    authority: CredentialAuthority
  )
    ensures SameCredentialAuthority(authority, authority)
  {
  }


  // ----------------------------------------------------------
  // MEMBERSHIP
  // ----------------------------------------------------------

  // Membership in Credential Authority is exactly set membership.
  lemma CredentialCanExerciseIffMember(
    authority: CredentialAuthority,
    capability: Capability
  )
    ensures CredentialCanExercise(authority, capability)
       <==> capability in authority
  {
  }


  // A Capability selected from Credential Authority is one of the
  // Capabilities represented by that authority value.
  lemma CredentialAuthorityContainsCapability(
    authority: CredentialAuthority,
    capability: Capability
  )
    requires CredentialCanExercise(authority, capability)
    ensures capability in authority
  {
  }


  // ----------------------------------------------------------
  // VALIDITY
  // ----------------------------------------------------------

  // A valid Credential Authority contains only valid Capabilities.
  //
  // Capability validity is defined by Capability itself.
  // Credential Authority does not create or alter Capability
  // validity.
  predicate ValidCredentialAuthority(
    authority: CredentialAuthority
  )
  {
    forall capability ::
      capability in authority
      ==> ValidCapability(capability)
  }


  // A Capability selected from a valid Credential Authority is
  // structurally valid.
  lemma ValidCredentialAuthorityContainsValidCapability(
    authority: CredentialAuthority,
    capability: Capability
  )
    requires ValidCredentialAuthority(authority)
    requires CredentialCanExercise(authority, capability)
    ensures ValidCapability(capability)
  {
  }


  // ----------------------------------------------------------
  // AUTHORITY REDUCTION
  // ----------------------------------------------------------

  // A reduced Credential Authority cannot introduce a Capability
  // that was absent from the original authority.
  //
  // This establishes the basic monotonic subset relationship used
  // later by Session, Delegation, Restriction, and Effective
  // Authority reasoning.
  lemma ReducedCredentialAuthorityCannotAddCapability(
    original: CredentialAuthority,
    reduced: CredentialAuthority,
    capability: Capability
  )
    requires reduced <= original
    requires CredentialCanExercise(reduced, capability)
    ensures CredentialCanExercise(original, capability)
  {
  }
}

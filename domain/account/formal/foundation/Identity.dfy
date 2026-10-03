// ============================================================
// KIPIO ACCOUNT DOMAIN
// FOUNDATION — IDENTITY
// ============================================================
//
// Identity-level semantics and laws for the Account domain.
//
// Identity represents the sovereign continuity through which a
// Subject may exercise authority within Kipio Account.
//
// Identity is distinct from:
//
//   - Subject;
//   - Credential;
//   - Account;
//   - blockchain address;
//   - authentication mechanism.
//
// A Subject may be associated with multiple distinct Identities.
// Therefore Subject does not determine Identity identity.
//
// Identity has its own stable domain identifier: IdentityId.
//
// Important semantic distinction:
//
//   IdentityId equality
//       = Entity identity
//
//   Dafny structural equality
//       = equality of every field of the datatype
//
// This file therefore does not incorrectly equate Entity identity
// with Dafny structural equality. State-level invariants are
// responsible for ensuring that a single IdentityId is not
// associated with conflicting Subject attribution.
//
// This file intentionally contains no:
//   - account state
//   - credential logic
//   - session/delegation logic
//   - authorization logic
//   - policy logic
//   - execution logic
//   - cryptographic verification
//   - blockchain ABI types
//   - storage representations
//
// ============================================================

include "DomainPrimitives.dfy"
include "Subject.dfy"

module KipioAccountIdentity
{
  import opened KipioAccountDomainPrimitives
  import opened KipioAccountSubject


  // ----------------------------------------------------------
  // IDENTITY
  // ----------------------------------------------------------

  // Identity represents a sovereign continuity within Kipio.
  //
  // Identity has its own stable identifier and is attributed to
  // exactly one Subject.
  //
  // The Subject is part of the semantic description of the
  // Identity, but it does not determine the Identity's identity.
  //
  // Therefore:
  //
  //   Subject A
  //       ├── Identity X
  //       └── Identity Y
  //
  // is valid in principle when X and Y have distinct IdentityIds.
  datatype Identity =
    Identity(
      id: Id,
      subject: Subject
    )


  // ----------------------------------------------------------
  // IDENTITY IDENTIFIER
  // ----------------------------------------------------------

  // Returns the stable identifier that distinguishes this
  // Identity Entity from other Identity Entities.
  //
  // IdentityId must not automatically be interpreted as:
  //
  //   - Subject identifier;
  //   - AccountId;
  //   - CredentialId;
  //   - blockchain address;
  //   - nonce;
  //   - hash;
  //   - cryptographic key.
  //
  // The physical representation of Id is defined by the shared
  // domain primitives; its semantic role here is Identity
  // identity.
  function IdentityId(
    identity: Identity
  ): Id
  {
    identity.id
  }


  // ----------------------------------------------------------
  // IDENTITY SUBJECT
  // ----------------------------------------------------------

  // Returns the Subject to which the Identity is attributed.
  //
  // The Subject answers:
  //
  //   "Who or what does this Identity represent?"
  //
  // It does not answer:
  //
  //   "Which sovereign Identity is this?"
  //
  // That distinction belongs to IdentityId.
  function IdentitySubject(
    identity: Identity
  ): Subject
  {
    identity.subject
  }


  // ----------------------------------------------------------
  // SEMANTIC IDENTITY
  // ----------------------------------------------------------

  // Determines whether two Identity values refer to the same
  // semantic Identity Entity.
  //
  // Entity identity is determined by IdentityId rather than by
  // all structural fields.
  //
  // This predicate is deliberately separate from Dafny's `==`
  // because `==` compares the complete datatype structure.
  predicate SameIdentity(
    left: Identity,
    right: Identity
  )
  {
    IdentityId(left) == IdentityId(right)
  }


  // ----------------------------------------------------------
  // IDENTITY VALIDITY
  // ----------------------------------------------------------

  // A valid Identity must have:
  //
  //   - a valid IdentityId;
  //   - a valid Subject.
  //
  // This establishes validity of an individual Identity value.
  //
  // It does not establish global uniqueness of IdentityId or
  // consistency of Subject attribution across multiple Identity
  // values. Those properties belong to the state that stores or
  // recognizes Identities.
  predicate ValidIdentity(
    identity: Identity
  )
  {
    ValidId(IdentityId(identity))
    && ValidSubject(IdentitySubject(identity))
  }


  // ----------------------------------------------------------
  // SEMANTIC IDENTITY LAWS
  // ----------------------------------------------------------

  // Equal IdentityIds identify the same semantic Identity.
  //
  // This is the Entity identity law of Identity.
  //
  // It intentionally does not ensure Dafny structural equality
  // because structural equality also compares Subject.
  lemma IdentitiesWithEqualIdsHaveSameIdentity(
    left: Identity,
    right: Identity
  )
    requires IdentityId(left) == IdentityId(right)
    ensures SameIdentity(left, right)
  {
  }


  // Distinct IdentityIds identify distinct semantic Identities.
  lemma IdentitiesWithDistinctIdsAreNotTheSameIdentity(
    left: Identity,
    right: Identity
  )
    requires IdentityId(left) != IdentityId(right)
    ensures !SameIdentity(left, right)
  {
  }


  // Equal Dafny Identity values necessarily have equal IdentityIds.
  //
  // This is a structural property and is intentionally distinct
  // from the Entity identity law above.
  lemma EqualIdentitiesHaveEqualIds(
    left: Identity,
    right: Identity
  )
    requires left == right
    ensures IdentityId(left) == IdentityId(right)
  {
  }


  // Equal Dafny Identity values necessarily expose the same Subject.
  lemma EqualIdentitiesHaveEqualSubjects(
    left: Identity,
    right: Identity
  )
    requires left == right
    ensures IdentitySubject(left) == IdentitySubject(right)
  {
  }


  // ----------------------------------------------------------
  // SUBJECT / IDENTITY RELATIONSHIP
  // ----------------------------------------------------------

  // If two Identity values have the same Subject but different
  // IdentityIds, they represent different semantic Identities.
  //
  // This captures the DDD rule:
  //
  //   Subject does not determine Identity.
  //
  // A Subject may therefore be associated with multiple
  // sovereign Identities.
  lemma SameSubjectWithDistinctIdsMeansDistinctIdentities(
    left: Identity,
    right: Identity
  )
    requires IdentitySubject(left) == IdentitySubject(right)
    requires IdentityId(left) != IdentityId(right)
    ensures !SameIdentity(left, right)
  {
  }


  // Subject equality alone is insufficient to establish Identity
  // equality.
  //
  // This lemma is intentionally expressed as the semantic
  // consequence that distinct IdentityIds remain distinct even
  // when the Subject is the same.
  lemma SameSubjectDoesNotMergeIdentityIdentity(
    left: Identity,
    right: Identity
  )
    requires IdentitySubject(left) == IdentitySubject(right)
    requires IdentityId(left) != IdentityId(right)
    ensures left != right
  {
  }


  // ----------------------------------------------------------
  // IDENTITY VALIDITY LAWS
  // ----------------------------------------------------------

  // A valid Identity exposes a valid IdentityId.
  lemma ValidIdentityHasValidId(
    identity: Identity
  )
    requires ValidIdentity(identity)
    ensures ValidId(IdentityId(identity))
  {
  }


  // A valid Identity exposes a valid Subject.
  lemma ValidIdentityHasValidSubject(
    identity: Identity
  )
    requires ValidIdentity(identity)
    ensures ValidSubject(IdentitySubject(identity))
  {
  }
}

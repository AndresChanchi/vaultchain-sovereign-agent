// ============================================================
// KIPIO ACCOUNT DOMAIN
// FOUNDATION — SUBJECT
// ============================================================
//
// Subject-level semantics for the Account domain.
//
// Subject is a semantic actor descriptor.
//
// Subject is intentionally distinct from:
//
//   - Kipio Identity;
//   - Account;
//   - Credential;
//   - Blockchain Address;
//   - authentication mechanism.
//
// Subject represents the semantic actor to which a Identity is attributed.
// Kipio Identity is semantically attributed. It does not itself
// represent sovereign continuity inside Kipio.
//
// This file intentionally contains no:
//   - Identity lifecycle logic
//   - Account logic
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

module KipioAccountSubject
{
  import opened KipioAccountDomainPrimitives


  // ----------------------------------------------------------
  // SUBJECT
  // ----------------------------------------------------------

  // Subject is a semantic descriptor of the actor to which a
  // Kipio Identity is attributed.
  //
  // The reference does NOT constitute:
  //
  //   - IdentityId
  //   - AccountId
  //   - CredentialId
  //   - blockchain address
  //   - cryptographic key
  //
  // A Subject is a Value Object. Its meaning is determined by
  // its value rather than by an independent lifecycle.
  datatype Subject =
    Subject(
      reference: Id
    )


  // ----------------------------------------------------------
  // SUBJECT REFERENCE
  // ----------------------------------------------------------

  // Returns the opaque reference representing the semantic actor
  // described by the Subject.
  //
  // This operation deliberately uses "Reference" rather than "Id"
  // to avoid assigning Entity semantics to Subject.
  function SubjectReference(subject: Subject): Id
  {
    subject.reference
  }


  // ----------------------------------------------------------
  // SUBJECT VALIDITY
  // ----------------------------------------------------------

  // A valid Subject must contain a valid primitive reference.
  //
  // Subject validity does not establish:
  //
  //   - that the referenced actor exists;
  //   - that the actor is a person or organization;
  //   - that the actor owns a Kipio Identity;
  //   - that the actor owns an Account;
  //   - or that the reference is globally unique.
  //
  // Those meanings belong to the bounded context that assigns the
  // Subject its semantic interpretation.
  predicate ValidSubject(subject: Subject)
  {
    ValidId(SubjectReference(subject))
  }


  // ----------------------------------------------------------
  // SUBJECT VALUE EQUALITY
  // ----------------------------------------------------------

  // Subjects with the same semantic reference are equal.
  //
  // This expresses Value Object equality.
  //
  // No independent Subject identifier or lifecycle is introduced.
  lemma SubjectsWithEqualReferencesAreEqual(
    left: Subject,
    right: Subject
  )
    requires SubjectReference(left) == SubjectReference(right)
    ensures left == right
  {
  }


  // Equal Subjects necessarily expose the same semantic reference.
  lemma EqualSubjectsHaveEqualReferences(
    left: Subject,
    right: Subject
  )
    requires left == right
    ensures SubjectReference(left) == SubjectReference(right)
  {
  }


  // ----------------------------------------------------------
  // SUBJECT VALIDITY LAWS
  // ----------------------------------------------------------

  // A valid Subject exposes a valid semantic reference.
  lemma ValidSubjectHasValidReference(
    subject: Subject
  )
    requires ValidSubject(subject)
    ensures ValidId(SubjectReference(subject))
  {
  }


  // ----------------------------------------------------------
  // DOMAIN BOUNDARY NOTE
  // ----------------------------------------------------------

  // A Subject reference does not imply sovereign identity.
  //
  // The same semantic Subject may be associated with multiple
  // Kipio Identities:
  //
  //     Subject
  //         ├── Identity A
  //         ├── Identity B
  //         └── Identity C
  //
  // Conversely, a Kipio Identity preserves its own sovereign
  // continuity independently of the external Subject reference.
  //
  // This relationship will be formalized by Identity.dfy.
}

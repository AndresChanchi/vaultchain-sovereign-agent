// ============================================================
// KIPIO ACCOUNT DOMAIN
// LAWS — IDENTITY
// ============================================================
//
// Cross-concept semantic laws concerning Identity.
//
// Identity.dfy defines the local semantics of the Identity Entity:
//
//   - Identity has its own stable IdentityId;
//   - Identity is attributed to exactly one Subject;
//   - Identity Entity identity is determined by IdentityId;
//   - Subject does not determine Identity identity;
//   - structural validity is defined locally.
//
// This file intentionally does NOT duplicate those local laws.
//
// Instead, it defines collection-level and cross-concept
// consequences required when multiple Identity values are
// considered together.
//
// ------------------------------------------------------------
//
// DDD BOUNDARY
//
// Identity is:
//
//   - an Entity;
//   - sovereign continuity within Kipio;
//   - individually identified by IdentityId;
//   - attributed to exactly one Subject.
//
// Identity is NOT:
//
//   - a Subject;
//   - a Credential;
//   - a Session;
//   - a Delegation;
//   - an Account;
//   - a blockchain address;
//   - a Proof;
//   - an authentication mechanism.
//
// ------------------------------------------------------------
//
// IDENTITY VS SUBJECT
//
// IdentityId defines Identity Entity identity.
//
// Subject describes the semantic actor to which an Identity is
// attributed.
//
// Therefore:
//
//     Subject
//         !=
//     Identity identity
//
// A single Subject may legitimately be associated with multiple
// distinct Identity Entities, provided their Entity identities
// are distinct.
//
// The local semantic consequences of this distinction are defined
// in Identity.dfy. This file retains only the laws that matter
// across a collection boundary.
//
// ------------------------------------------------------------
//
// COLLECTION-LEVEL IDENTITY INVARIANT
//
// When a collection represents recognized Identity Entities:
//
//     left != right
//         =>
//     IdentityId(left) != IdentityId(right)
//
// This prevents two distinct Identity values from occupying the
// same Entity identity within the same recognized collection.
//
// The invariant does NOT require Subjects to be unique.
//
// ------------------------------------------------------------
//
// RESPONSIBILITY BOUNDARY
//
// This file does NOT define:
//
//   - Account sovereignty;
//   - Account ↔ Identity recognition;
//   - Credential recognition;
//   - Session semantics;
//   - Delegation semantics;
//   - Authorization;
//   - Policy;
//   - Proof verification;
//   - blockchain representation.
//
// Those concerns belong to their corresponding domain modules.
//
// ------------------------------------------------------------
//
// DESIGN PRINCIPLE
//
// IdentityLaws adds only laws that require reasoning across
// multiple Identity values or across the Identity collection
// boundary.
//
// Local constructor/value/validity laws remain in Identity.dfy.
//
// ============================================================

include "../foundation/DomainPrimitives.dfy"
include "../foundation/Subject.dfy"
include "../foundation/Identity.dfy"

module KipioAccountIdentityLaws
{
  import opened KipioAccountDomainPrimitives
  import opened KipioAccountSubject
  import opened KipioAccountIdentity


  // ----------------------------------------------------------
  // IDENTITY COLLECTION UNIQUENESS
  // ----------------------------------------------------------

  // A recognized collection cannot contain two distinct Identity
  // values carrying the same IdentityId.
  //
  // IdentityId is the Entity identity.
  //
  // Subject uniqueness is deliberately NOT required.
  predicate IdentityIdsAreUnique(
    identities: set<Identity>
  )
  {
    forall left, right ::
      left in identities
      && right in identities
      && left != right
      ==>
        IdentityId(left) != IdentityId(right)
  }


  // ----------------------------------------------------------
  // IDENTITY RECOGNITION BY ENTITY IDENTITY
  // ----------------------------------------------------------

  // Determines whether a collection recognizes an Identity Entity
  // with the supplied IdentityId.
  //
  // Recognition is based on Entity identity, not on complete
  // structural equality and not on Subject attribution.
  predicate IdentityRecognizedById(
    identities: set<Identity>,
    identityId: Id
  )
  {
    exists identity ::
      identity in identities
      && IdentityId(identity) == identityId
  }


  // Recognition by IdentityId means that a collection contains an
  // Identity carrying that Entity identity.
  lemma RecognizedIdentityIdHasIdentity(
    identities: set<Identity>,
    identityId: Id
  )
    requires IdentityRecognizedById(
               identities,
               identityId
             )
    ensures exists identity ::
              identity in identities
              && IdentityId(identity) == identityId
  {
  }


  // ----------------------------------------------------------
  // ENTITY UNIQUENESS
  // ----------------------------------------------------------

  // Under the collection uniqueness invariant, two members cannot
  // have the same IdentityId while remaining distinct Identity
  // values.
  lemma UniqueIdentityIdImpliesNoDuplicateIdentityEntity(
    identities: set<Identity>,
    left: Identity,
    right: Identity
  )
    requires IdentityIdsAreUnique(identities)
    requires left in identities
    requires right in identities
    requires IdentityId(left) == IdentityId(right)
    ensures left == right
  {
  }


  // ----------------------------------------------------------
  // SUBJECT / IDENTITY SEPARATION
  // ----------------------------------------------------------

  // A collection may contain distinct Identity Entities attributed
  // to the same Subject.
  //
  // This is a collection-level consequence of the DDD distinction:
  //
  //     one Subject
  //         ->
  //     multiple distinct Identities
  //
  // Distinctness of the Identity Entities follows from their
  // distinct IdentityIds; the corresponding local semantic law is
  // defined in Identity.dfy.
  lemma SameSubjectAllowsMultipleIdentityEntities(
    left: Identity,
    right: Identity
  )
    requires IdentitySubject(left) == IdentitySubject(right)
    requires IdentityId(left) != IdentityId(right)
    ensures left != right
    ensures !SameIdentity(left, right)
  {
  }


  // ----------------------------------------------------------
  // VALID IDENTITY COLLECTION
  // ----------------------------------------------------------

  // A valid recognized Identity collection:
  //
  //   - contains only structurally valid Identity values;
  //   - preserves Entity identity uniqueness.
  predicate ValidIdentityCollection(
    identities: set<Identity>
  )
  {
    (forall identity ::
       identity in identities
       ==>
         ValidIdentity(identity))
    &&
    IdentityIdsAreUnique(identities)
  }


  // Every member of a valid Identity collection is structurally
  // valid.
  lemma ValidIdentityCollectionContainsValidIdentity(
    identities: set<Identity>,
    identity: Identity
  )
    requires ValidIdentityCollection(identities)
    requires identity in identities
    ensures ValidIdentity(identity)
  {
  }


  // Distinct members of a valid Identity collection necessarily
  // carry distinct IdentityIds.
  lemma ValidIdentityCollectionPreservesEntityIdentity(
    identities: set<Identity>,
    left: Identity,
    right: Identity
  )
    requires ValidIdentityCollection(identities)
    requires left in identities
    requires right in identities
    requires left != right
    ensures IdentityId(left) != IdentityId(right)
  {
  }


  // ----------------------------------------------------------
  // COLLECTION-LEVEL VALIDITY AND IDENTITY CONSISTENCY
  // ----------------------------------------------------------

  // Every valid Identity recognized by a valid collection carries
  // a valid IdentityId.
  //
  // The local validity relation is defined by Identity.dfy; the
  // collection-level law merely exposes that consequence through
  // the collection boundary.
  lemma ValidIdentityCollectionMemberHasValidIdentityId(
    identities: set<Identity>,
    identity: Identity
  )
    requires ValidIdentityCollection(identities)
    requires identity in identities
    ensures ValidId(IdentityId(identity))
  {
  }


  // Every valid Identity recognized by a valid collection carries
  // a valid Subject.
  //
  // As above, the individual validity relation remains local to
  // Identity.dfy.
  lemma ValidIdentityCollectionMemberHasValidSubject(
    identities: set<Identity>,
    identity: Identity
  )
    requires ValidIdentityCollection(identities)
    requires identity in identities
    ensures ValidSubject(IdentitySubject(identity))
  {
  }


  // ----------------------------------------------------------
  // IDENTITY VALIDITY DEPENDENCE
  // ----------------------------------------------------------

  // Identity validity depends only on the semantic components
  // represented by Identity itself:
  //
  //     IdentityId
  //     +
  //     Subject
  //
  // No external Credential, Account, Proof, blockchain address,
  // or authentication mechanism is required to establish the
  // structural validity of an Identity value.
  //
  // This is expressed positively: if two Identity values expose
  // the same IdentityId and the same Subject, validity of one
  // transfers to the other.
  lemma ValidIdentityDependsOnlyOnIdAndSubject(
    left: Identity,
    right: Identity
  )
    requires ValidIdentity(left)
    requires IdentityId(left) == IdentityId(right)
    requires IdentitySubject(left) == IdentitySubject(right)
    ensures ValidIdentity(right)
  {
  }
}

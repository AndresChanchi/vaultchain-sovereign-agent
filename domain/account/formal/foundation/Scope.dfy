// ============================================================
// KIPIO ACCOUNT DOMAIN
// FOUNDATION — SCOPE
// ============================================================
//
// Scope semantics for the Account domain.
//
// Scope is a Value Object representing the semantic extent over
// which a Capability may be exercised.
//
// Scope is defined by:
//
//     Scope = set<ScopeAtom>
//
// Scope has:
//   - no independent identity;
//   - no lifecycle;
//   - no execution identity;
//   - no blockchain-specific meaning.
//
// ScopeAtom is a value component of Scope. Its identifier is part
// of its semantic value and does not make ScopeAtom an Entity.
//
// This file intentionally contains no:
//   - capability authorization logic
//   - credential logic
//   - session/delegation logic
//   - restriction logic
//   - policy logic
//   - effective authority calculation
//   - execution target logic
//   - cryptographic verification
//   - blockchain ABI types
//   - storage representations
//
// ============================================================

include "DomainPrimitives.dfy"

module KipioAccountScope
{
  import opened KipioAccountDomainPrimitives


  // ----------------------------------------------------------
  // SCOPE ATOM
  // ----------------------------------------------------------

  // ScopeAtom is a semantic value contained by a Scope.
  //
  // Its identifier does not imply any infrastructure-specific
  // meaning such as:
  //
  //   - blockchain address;
  //   - execution target;
  //   - contract;
  //   - resource implementation.
  //
  // ScopeAtom has no independent lifecycle or Entity identity.
  datatype ScopeAtom =
    ScopeAtom(
      id: Id
    )


  // Returns the semantic value represented by a ScopeAtom.
  function ScopeAtomValue(
    atom: ScopeAtom
  ): Id
  {
    atom.id
  }


  // A ScopeAtom is structurally valid when its identifier is valid.
  predicate ValidScopeAtom(
    atom: ScopeAtom
  )
  {
    ValidId(ScopeAtomValue(atom))
  }


  // Two ScopeAtoms with the same semantic value are equal.
  lemma ScopeAtomsWithSameValueAreEqual(
    left: ScopeAtom,
    right: ScopeAtom
  )
    requires ScopeAtomValue(left) == ScopeAtomValue(right)
    ensures left == right
  {
  }


  // Equal ScopeAtoms necessarily expose the same semantic value.
  lemma EqualScopeAtomsHaveEqualValues(
    left: ScopeAtom,
    right: ScopeAtom
  )
    requires left == right
    ensures ScopeAtomValue(left) == ScopeAtomValue(right)
  {
  }


  // ----------------------------------------------------------
  // SCOPE
  // ----------------------------------------------------------

  // Scope is a Value Object.
  //
  // Its complete semantic value is the set of ScopeAtoms it
  // contains.
  //
  // Therefore:
  //
  //     same atoms
  //         =>
  //     same Scope
  //
  // Ordering and duplicate occurrences carry no meaning because
  // Scope is represented as a set.
  datatype Scope =
    Scope(
      atoms: set<ScopeAtom>
    )


  // Returns the semantic atoms defining the Scope.
  function ScopeAtoms(
    scope: Scope
  ): set<ScopeAtom>
  {
    scope.atoms
  }


  // Determines whether a Scope contains a given ScopeAtom.
  predicate ScopeContains(
    scope: Scope,
    atom: ScopeAtom
  )
  {
    atom in ScopeAtoms(scope)
  }


  // ----------------------------------------------------------
  // SCOPE VALUE EQUALITY
  // ----------------------------------------------------------

  // Two Scopes are semantically equal exactly when their defining
  // atom sets are equal.
  predicate ScopesEqualByValue(
    left: Scope,
    right: Scope
  )
  {
    ScopeAtoms(left) == ScopeAtoms(right)
  }


  // Two Scopes with the same defining set are equal.
  lemma ScopesWithSameAtomsAreEqual(
    left: Scope,
    right: Scope
  )
    requires ScopesEqualByValue(left, right)
    ensures left == right
  {
  }


  // Equal Scopes necessarily expose the same defining set.
  lemma EqualScopesHaveEqualAtoms(
    left: Scope,
    right: Scope
  )
    requires left == right
    ensures ScopeAtoms(left) == ScopeAtoms(right)
  {
  }


  // Scope membership is exactly membership in its defining set.
  lemma ScopeContainsIffAtomInScope(
    scope: Scope,
    atom: ScopeAtom
  )
    ensures ScopeContains(scope, atom)
       <==> atom in ScopeAtoms(scope)
  {
  }


  // Scope has no identity independent of its semantic value.
  lemma ScopeHasNoIndependentIdentity(
    scope: Scope
  )
    ensures ScopesEqualByValue(scope, scope)
  {
  }


  // Equality of Scope values depends only on their defining atoms.
  lemma ScopeEqualityDependsOnlyOnAtoms(
    left: Scope,
    right: Scope
  )
    requires left == right
    ensures ScopesEqualByValue(left, right)
  {
  }


  // Semantic equality of Scope values implies structural equality.
  lemma EqualByScopeValueImpliesScopeEquality(
    left: Scope,
    right: Scope
  )
    requires ScopesEqualByValue(left, right)
    ensures left == right
  {
  }


  // ----------------------------------------------------------
  // SCOPE INCLUSION
  // ----------------------------------------------------------

  // A Scope is within another Scope when every semantic atom of
  // the inner Scope is also present in the outer Scope.
  //
  // This is a value-level relation. It does not by itself grant
  // or revoke authority.
  predicate ScopeWithin(
    inner: Scope,
    outer: Scope
  )
  {
    ScopeAtoms(inner) <= ScopeAtoms(outer)
  }


  // An atom contained by an inner Scope is also contained by
  // its outer Scope.
  lemma NarrowerScopeAtomBelongsToBroaderScope(
    inner: Scope,
    outer: Scope,
    atom: ScopeAtom
  )
    requires ScopeWithin(inner, outer)
    requires ScopeContains(inner, atom)
    ensures ScopeContains(outer, atom)
  {
  }


  // Scope inclusion is reflexive.
  lemma ScopeWithinItself(
    scope: Scope
  )
    ensures ScopeWithin(scope, scope)
  {
  }


  // Scope inclusion is transitive.
  lemma ScopeWithinIsTransitive(
    first: Scope,
    second: Scope,
    third: Scope
  )
    requires ScopeWithin(first, second)
    requires ScopeWithin(second, third)
    ensures ScopeWithin(first, third)
  {
  }


  // ----------------------------------------------------------
  // SCOPE VALIDITY
  // ----------------------------------------------------------

  // A Scope is structurally valid when every contained ScopeAtom
  // is valid.
  predicate ValidScope(
    scope: Scope
  )
  {
    forall atom ::
      atom in ScopeAtoms(scope)
      ==> ValidScopeAtom(atom)
  }


  // A valid Scope contains only valid ScopeAtoms.
  lemma ValidScopeContainsValidAtom(
    scope: Scope,
    atom: ScopeAtom
  )
    requires ValidScope(scope)
    requires ScopeContains(scope, atom)
    ensures ValidScopeAtom(atom)
  {
  }


  // A valid Scope contains only atoms with valid identifiers.
  lemma ValidScopeContainsValidAtomId(
    scope: Scope,
    atom: ScopeAtom
  )
    requires ValidScope(scope)
    requires ScopeContains(scope, atom)
    ensures ValidId(ScopeAtomValue(atom))
  {
  }


  // ----------------------------------------------------------
  // SCOPE SEMANTIC BOUNDARY
  // ----------------------------------------------------------

  // Scope represents the semantic extent over which a Capability
  // may be exercised.
  //
  // It contains no ExecutionTarget, blockchain address, contract,
  // or other infrastructure-specific concept.
  predicate SameScopeMeaning(
    left: Scope,
    right: Scope
  )
  {
    ScopesEqualByValue(left, right)
  }


  // Equal Scopes necessarily represent the same semantic extent.
  lemma EqualScopesHaveSameMeaning(
    left: Scope,
    right: Scope
  )
    requires left == right
    ensures SameScopeMeaning(left, right)
  {
  }
}

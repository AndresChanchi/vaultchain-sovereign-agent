// ============================================================
// KIPIO ACCOUNT DOMAIN
// PROOFS — FOUNDATION
// ============================================================
//
// Isolated proofs for the complete Foundation layer.
//
// Purpose:
//
//   - validate that foundational concepts compose coherently;
//   - prove cross-concept consequences that individual foundation
//     files cannot establish alone;
//   - provide reusable lemmas for higher-level isolated proofs;
//   - provide reusable building blocks for end-to-end scenarios.
//
// These proofs intentionally do NOT:
//
//   - introduce new domain concepts;
//   - define new semantics;
//   - redefine local Foundation laws;
//   - depend on Authority, Account, Authorization, Execution,
//     Policy, or higher layers.
//
// Foundation remains:
//
//     DomainPrimitives
//          ↓
//     Subject
//          ↓
//     Identity
//
//     DomainPrimitives
//          ↓
//     Scope
//          ↓
//     Capability
//
//     DomainPrimitives
//          ↓
//     Restriction
//
// Foundation therefore proves only structural and value-level
// consequences available inside this semantic layer.
//
// In particular, Foundation does NOT prove:
//
//   - EffectiveAuthority;
//   - authority exercise;
//   - credential recognition;
//   - delegation;
//   - authorization;
//   - execution;
//   - policy;
//   - proof verification.
//
// Those belong to higher layers.
//
// ============================================================

include "../../foundation/DomainPrimitives.dfy"
include "../../foundation/Subject.dfy"
include "../../foundation/Identity.dfy"
include "../../foundation/Scope.dfy"
include "../../foundation/Capability.dfy"
include "../../foundation/Restriction.dfy"

module KipioAccountFoundationProofs
{
  import opened KipioAccountDomainPrimitives
  import opened KipioAccountSubject
  import opened KipioAccountIdentity
  import opened KipioAccountScope
  import opened KipioAccountCapability
  import opened KipioAccountRestriction



  // ----------------------------------------------------------
  // IDENTIFIER FOUNDATION
  // ----------------------------------------------------------

  // Every valid Subject exposes a valid underlying reference.
  //
  // Complete primitive chain:
  //
  //     ValidSubject
  //         ↓
  //     SubjectReference
  //         ↓
  //     ValidId
  lemma ValidSubjectReferenceIsValidIdentifier(
    subject: Subject
  )
    requires ValidSubject(subject)
    ensures ValidId(
              SubjectReference(subject)
            )
  {
  }



  // Every valid Identity exposes both foundational components:
  //
  //   - a valid IdentityId;
  //   - a valid Subject.
  //
  // No higher-level concept is required.
  lemma ValidIdentityHasValidFoundationComponents(
    identity: Identity
  )
    requires ValidIdentity(identity)
    ensures ValidId(
              IdentityId(identity)
            )
    ensures ValidSubject(
              IdentitySubject(identity)
            )
  {
  }



  // A valid Identity contains a valid Subject whose reference is
  // itself a valid primitive identifier.
  //
  // Complete composition:
  //
  //     ValidIdentity
  //          ↓
  //     ValidSubject
  //          ↓
  //     ValidId
  lemma ValidIdentityImpliesValidSubjectReference(
    identity: Identity
  )
    requires ValidIdentity(identity)
    ensures ValidId(
              SubjectReference(
                IdentitySubject(identity)
              )
            )
  {
  }



  // ----------------------------------------------------------
  // SUBJECT / IDENTITY SEPARATION
  // ----------------------------------------------------------

  // A single Subject may be associated with multiple distinct
  // Identity Entities.
  //
  // Distinct IdentityIds preserve Entity distinction even when
  // Subject attribution is identical.
  lemma DistinctIdentityIdsCanShareSubject(
    left: Identity,
    right: Identity
  )
    requires ValidIdentity(left)
    requires ValidIdentity(right)
    requires IdentitySubject(left) == IdentitySubject(right)
    requires IdentityId(left) != IdentityId(right)
    ensures !SameIdentity(left, right)
    ensures left != right
  {
  }



  // Subject equality alone cannot establish that two Identity
  // values are the same Entity.
  //
  // If their IdentityIds differ, semantic Identity remains
  // distinct regardless of shared Subject attribution.
  lemma SubjectEqualityDoesNotEstablishIdentityEquality(
    left: Identity,
    right: Identity
  )
    requires IdentitySubject(left) == IdentitySubject(right)
    ensures
      IdentityId(left) == IdentityId(right)
      ||
      !SameIdentity(left, right)
  {
  }



  // ----------------------------------------------------------
  // SCOPE FOUNDATION
  // ----------------------------------------------------------

  // A valid Scope containing an atom necessarily contains a valid
  // ScopeAtom.
  lemma ValidScopeAtomIsValidFoundationValue(
    scope: Scope,
    atom: ScopeAtom
  )
    requires ValidScope(scope)
    requires ScopeContains(scope, atom)
    ensures ValidScopeAtom(atom)
  {
  }



  // A valid Scope containing an atom necessarily exposes a valid
  // primitive identifier for that atom.
  lemma ValidScopeAtomHasValidIdentifier(
    scope: Scope,
    atom: ScopeAtom
  )
    requires ValidScope(scope)
    requires ScopeContains(scope, atom)
    ensures ValidId(
              ScopeAtomValue(atom)
            )
  {
  }



  // Scope inclusion preserves membership.
  //
  // If an atom belongs to an inner Scope and the inner Scope is
  // contained in an outer Scope, the atom remains in the outer
  // Scope.
  lemma ScopeInclusionPreservesAtomMembership(
    inner: Scope,
    outer: Scope,
    atom: ScopeAtom
  )
    requires ScopeWithin(inner, outer)
    requires ScopeContains(inner, atom)
    ensures ScopeContains(outer, atom)
  {
  }



  // Scope inclusion combined with validity preserves atom validity
  // at the broader boundary.
  lemma ValidNarrowerScopePreservesAtomValidity(
    inner: Scope,
    outer: Scope,
    atom: ScopeAtom
  )
    requires ValidScope(inner)
    requires ScopeWithin(inner, outer)
    requires ScopeContains(inner, atom)
    ensures ScopeContains(outer, atom)
    ensures ValidScopeAtom(atom)
  {
  }



  // ----------------------------------------------------------
  // CAPABILITY / SCOPE COMPOSITION
  // ----------------------------------------------------------

  // Every valid Capability exposes:
  //
  //   - a valid CapabilityKind;
  //   - a valid Scope.
  lemma ValidCapabilityHasValidFoundationComponents(
    capability: Capability
  )
    requires ValidCapability(capability)
    ensures ValidCapabilityKind(
              CapabilityKindOf(capability)
            )
    ensures ValidScope(
              CapabilityScope(capability)
            )
  {
  }



  // Valid Capability validity is exactly composed from its two
  // foundational semantic components:
  //
  //     CapabilityKind
  //         +
  //     Scope
  //
  // No Authority or Account state is required.
  lemma ValidCapabilityIsComposedOfValidValues(
    capability: Capability
  )
    requires ValidCapabilityKind(
               CapabilityKindOf(capability)
             )
    requires ValidScope(
               CapabilityScope(capability)
             )
    ensures ValidCapability(capability)
  {
  }



  // A valid Capability therefore contains only valid ScopeAtoms.
  lemma ValidCapabilityContainsOnlyValidScopeAtoms(
    capability: Capability,
    atom: ScopeAtom
  )
    requires ValidCapability(capability)
    requires ScopeContains(
               CapabilityScope(capability),
               atom
             )
    ensures ValidScopeAtom(atom)
  {
  }



  // Every ScopeAtom contained in a valid Capability has a valid
  // primitive identifier.
  lemma ValidCapabilityContainsOnlyValidScopeAtomIdentifiers(
    capability: Capability,
    atom: ScopeAtom
  )
    requires ValidCapability(capability)
    requires ScopeContains(
               CapabilityScope(capability),
               atom
             )
    ensures ValidId(
              ScopeAtomValue(atom)
            )
  {
  }



  // ----------------------------------------------------------
  // CAPABILITY SCOPE REDUCTION
  // ----------------------------------------------------------

  // A Capability whose Scope is narrowed cannot expose an atom
  // outside the broader Scope.
  //
  // This is deliberately expressed only through Capability and
  // Scope values. No authority concept is involved.
  lemma RestrictedCapabilityPreservesBroaderScopeBoundary(
    narrower: Capability,
    broader: Capability,
    atom: ScopeAtom
  )
    requires ValidCapability(narrower)
    requires ValidCapability(broader)
    requires ScopeWithin(
               CapabilityScope(narrower),
               CapabilityScope(broader)
             )
    requires ScopeContains(
               CapabilityScope(narrower),
               atom
             )
    ensures ScopeContains(
              CapabilityScope(broader),
              atom
            )
  {
  }



  // A capability with a narrower valid Scope preserves the validity
  // of every ScopeAtom already exposed by that narrower Scope.
  lemma RestrictedCapabilityPreservesAtomValidity(
    narrower: Capability,
    broader: Capability,
    atom: ScopeAtom
  )
    requires ValidCapability(narrower)
    requires ValidCapability(broader)
    requires ScopeWithin(
               CapabilityScope(narrower),
               CapabilityScope(broader)
             )
    requires ScopeContains(
               CapabilityScope(narrower),
               atom
             )
    ensures ValidScopeAtom(atom)
  {
  }



  // ----------------------------------------------------------
  // CAPABILITY VALUE SEMANTICS
  // ----------------------------------------------------------

  // Equal Capability values preserve their complete semantic value:
  //
  //     CapabilityKind
  //         +
  //     Scope
  lemma EqualCapabilitiesPreserveCompleteSemanticMeaning(
    left: Capability,
    right: Capability
  )
    requires left == right
    ensures SameCapability(left, right)
    ensures CapabilityKindOf(left)
         == CapabilityKindOf(right)
    ensures CapabilityScope(left)
         == CapabilityScope(right)
  {
  }



  // Equal semantic Capability components determine the same
  // Value Object.
  lemma EqualKindAndScopeDetermineCapabilityValue(
    left: Capability,
    right: Capability
  )
    requires CapabilityKindOf(left)
          == CapabilityKindOf(right)
    requires CapabilityScope(left)
          == CapabilityScope(right)
    ensures SameCapability(left, right)
    ensures left == right
  {
  }



  // ----------------------------------------------------------
  // RESTRICTION FOUNDATION
  // ----------------------------------------------------------

  // A valid Restriction exposes a valid RestrictionKind.
  //
  // RestrictionValue is intentionally opaque at Foundation level;
  // Foundation therefore does not invent validation semantics for
  // the payload.
  lemma ValidRestrictionHasValidFoundationComponents(
    restriction: Restriction
  )
    requires ValidRestriction(restriction)
    ensures ValidRestrictionKind(
              RestrictionKindOf(restriction)
            )
  {
  }



  // Equal Restriction values preserve their complete semantic value.
  lemma EqualRestrictionsPreserveCompleteSemanticMeaning(
    left: Restriction,
    right: Restriction
  )
    requires left == right
    ensures SameRestriction(left, right)
    ensures RestrictionKindOf(left)
         == RestrictionKindOf(right)
    ensures RestrictionValueOf(left)
         == RestrictionValueOf(right)
  {
  }



  // Equal semantic Restriction components determine the same
  // Value Object.
  lemma EqualRestrictionValuesDetermineRestrictionValue(
    left: Restriction,
    right: Restriction
  )
    requires RestrictionKindOf(left)
          == RestrictionKindOf(right)
    requires RestrictionValueOf(left)
          == RestrictionValueOf(right)
    ensures SameRestriction(left, right)
    ensures left == right
  {
  }



  // ----------------------------------------------------------
  // FOUNDATION VALUE-OBJECT COMPOSITION
  // ----------------------------------------------------------

  // A valid Subject, Identity, Capability and Restriction remain
  // independently structurally valid.
  //
  // This lemma intentionally does not infer authority, ownership,
  // recognition or authorization from their coexistence.
  lemma FoundationValuesRemainIndividuallyValid(
    subject: Subject,
    identity: Identity,
    capability: Capability,
    restriction: Restriction
  )
    requires ValidSubject(subject)
    requires ValidIdentity(identity)
    requires ValidCapability(capability)
    requires ValidRestriction(restriction)
    ensures ValidSubject(subject)
    ensures ValidIdentity(identity)
    ensures ValidCapability(capability)
    ensures ValidRestriction(restriction)
  {
  }



  // ----------------------------------------------------------
  // FOUNDATION BOUNDARY
  // ----------------------------------------------------------

  // Foundation establishes structural and value-level semantics
  // only.
  //
  // No authority, Account, authorization, policy, execution,
  // credential or proof semantics are introduced by these proofs.
  //
  // The absence of those concepts is enforced architecturally by
  // the import boundary of this file.
}

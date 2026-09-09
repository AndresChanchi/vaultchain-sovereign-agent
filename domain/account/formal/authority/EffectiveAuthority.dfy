// ============================================================
// KIPIO ACCOUNT DOMAIN
// AUTHORITY — EFFECTIVE AUTHORITY
// ============================================================
//
// Effective Authority represents the authority that remains
// exercisable after the applicable authority boundaries and
// restrictions have been applied.
//
// Effective Authority is a Value Object.
//
// It is derived from other authority-bearing values and therefore
// has no independent Entity identity.
//
// Conceptually:
//
//     Account / Available Authority
//                 ∩
//     Credential Authority
//                 ∩
//     Session Authority
//                 ∩
//     Delegated Authority
//                 ∩
//     Scope Conditions
//                 ∩
//     Restrictions
//                 ∩
//     Temporal Conditions
//                 ∩
//     Applicable Policy Effects
//                 ∩
//     Execution Context
//                 ↓
//     Effective Authority
//
// ------------------------------------------------------------
//
// D1 — PROVENANCE SEMANTICS
//
// Effective Authority may combine authority from multiple
// independent sources.
//
// Therefore the following is intentionally NOT a global law:
//
//     EffectiveAuthority(I) ⊆ SourceAuthority(A)
//
// for one arbitrary source A.
//
// Instead:
//
//     authority derived through A
//         ⊆
//     SourceAuthority(A)
//
// applies only to the portion of authority known to have been
// derived through A.
//
// Example:
//
//     Source A → Identity B : Edit
//     Source C → Identity B : Transfer
//
// then:
//
//     EffectiveAuthority(B)
//         = { Edit, Transfer }
//
// while:
//
//     { Edit }     ⊆ Authority(A)
//     { Transfer } ⊆ Authority(C)
//
// No single-source containment is required for the complete
// Effective Authority value.
//
// ------------------------------------------------------------
//
// D1 — PROVENANCE FORMALIZATION
//
// Effective Authority itself does not store provenance.
//
// Provenance is a ghost relational contract.
//
// The value-level relation establishes:
//
//     contribution(i) ⊆ sourceAuthority(i)
//
// together with:
//
//     EffectiveAuthority
//         = union of all contributions
//
// This permits independent sources to contribute independently
// without imposing a false global single-source restriction.
//
// ------------------------------------------------------------
//
// D1 — CONCRETE SOURCE ATTRIBUTION
//
// Source-sensitive provenance additionally preserves the concrete
// identity of the authority-bearing source responsible for each
// source authority value.
//
// The attribution contract is represented separately from the
// EffectiveAuthority Value Object:
//
//     sourceReference(i)
//             |
//             v
//     sourceAuthority(i)
//             |
//             v
//     contribution(i)
//
// Therefore two distinct source Entities may expose equal
// authority values without becoming indistinguishable in the
// attribution witness:
//
//     Credential(A) -> { Upload }
//     Credential(B) -> { Upload }
//
// remains distinguishable as:
//
//     CredentialSource(A) -> { Upload }
//     CredentialSource(B) -> { Upload }
//
// even though:
//
//     { Upload } == { Upload }.
//
// The concrete source reference is ghost proof material.
// It is not runtime EffectiveAuthority state.
//
// ------------------------------------------------------------
//
// IMPORTANT
//
// The source reference is intentionally an abstract proof-level
// reference to an existing domain Entity or Account authority
// source.
//
// This file does NOT:
//
//   - resolve source references against AuthorizationState;
//   - decide whether a source is recognized;
//   - decide whether a source is currently usable;
//   - construct Credential, Session or Delegation entities;
//   - store provenance inside EffectiveAuthority.
//
// Those responsibilities remain outside this Value Object.
//
// The acceptance layer must later establish that each attributed
// source reference actually corresponds to the supplied source
// authority value in the Account-relative state.
//
// ------------------------------------------------------------
//
// D1 — DELEGATION BOUNDARY
//
// Delegation introduces a separate authority boundary:
//
//     DelegatedAuthority
//         ⊆
//     DelegatableAuthority
//         ⊆
//     EffectiveAuthority(source)
//
// EffectiveAuthority does not calculate DelegatableAuthority.
// It only provides the upper authority boundary against which a
// delegatable subset may be compared.
//
// ------------------------------------------------------------
//
// This file does NOT define:
//
//   - AuthorizationState definition
//   - source recognition policy
//   - Session selection logic
//   - Delegation selection logic
//   - Delegatable Authority calculation
//   - Restriction evaluation
//   - Policy Effect transformation
//   - Authorization validation
//   - Proof verification
//   - cryptographic mechanisms
//   - Runtime orchestration
//   - Execution logic
//   - blockchain ABI types
//   - storage representations
//
// Effective Authority establishes:
//
//   - Value Object semantics;
//   - structural validity;
//   - source non-expansion;
//   - reduction monotonicity;
//   - contextual derivation boundary;
//   - provenance-compatible composition from independent sources;
//   - concrete source attribution as ghost derivation evidence.
//
// ============================================================


include "../foundation/DomainPrimitives.dfy"
include "../foundation/Capability.dfy"
include "CredentialAuthority.dfy"
include "Session.dfy"
include "Delegation.dfy"

module KipioAccountEffectiveAuthority
{
  import opened KipioAccountDomainPrimitives
  import opened KipioAccountCapability
  import opened KipioAccountCredentialAuthority
  import opened KipioAccountSession
  import opened KipioAccountDelegation


  // ----------------------------------------------------------
  // EFFECTIVE AUTHORITY
  // ----------------------------------------------------------

  type EffectiveAuthority = set<Capability>


  // ==========================================================
  // SOURCE ATTRIBUTION REFERENCE
  // ==========================================================
  //
  // This is proof-level identity for an authority source.
  //
  // It does NOT become part of EffectiveAuthority itself.
  //
  // The same Entity-kind + Entity-id pair identifies the same
  // concrete authority-bearing source within the attribution
  // witness.
  //
  // The reference identifies an existing domain source:
  //
  //     Account
  //     Credential
  //     Session
  //     Delegation
  //
  // Resolution of the reference against concrete Account state
  // remains outside this module.
  //
  // ----------------------------------------------------------

  datatype AuthoritySourceKind =
      AccountAuthoritySource
    | CredentialAuthoritySource
    | SessionAuthoritySource
    | DelegationAuthoritySource


  datatype AuthoritySourceReference =
    AuthoritySourceReference(
      kind: AuthoritySourceKind,
      id: Id
    )


  function AuthoritySourceReferenceKind(
    source: AuthoritySourceReference
  ): AuthoritySourceKind
  {
    source.kind
  }


  function AuthoritySourceReferenceId(
    source: AuthoritySourceReference
  ): Id
  {
    source.id
  }


  predicate ValidAuthoritySourceReference(
    source: AuthoritySourceReference
  )
  {
    ValidId(
      AuthoritySourceReferenceId(source)
    )
  }


  lemma DistinctAuthoritySourceReferencesHaveDistinctValues(
    first: AuthoritySourceReference,
    second: AuthoritySourceReference
  )
    requires first != second
    ensures
      first != second
  {
  }


  // Credential source references are distinguished by both their
  // source kind and CredentialId.
  lemma DifferentCredentialSourceIdsProduceDistinctReferences(
    firstCredentialId: Id,
    secondCredentialId: Id
  )
    requires firstCredentialId != secondCredentialId
    ensures
      AuthoritySourceReference(
        CredentialAuthoritySource,
        firstCredentialId
      )
      !=
      AuthoritySourceReference(
        CredentialAuthoritySource,
        secondCredentialId
      )
  {
  }


  // The same CredentialId referenced as a Credential source remains
  // distinct from the same numeric Id used by another source kind.
  lemma DifferentAuthoritySourceKindsProduceDistinctReferences(
    id: Id
  )
    ensures
      AuthoritySourceReference(
        CredentialAuthoritySource,
        id
      )
      !=
      AuthoritySourceReference(
        SessionAuthoritySource,
        id
      )
  {
  }


  // ----------------------------------------------------------
  // VALUE OBJECT SEMANTICS
  // ----------------------------------------------------------

  predicate SameEffectiveAuthority(
    left: EffectiveAuthority,
    right: EffectiveAuthority
  )
  {
    left == right
  }


  lemma EffectiveAuthoritiesWithSameValuesAreEqual(
    left: EffectiveAuthority,
    right: EffectiveAuthority
  )
    requires SameEffectiveAuthority(left, right)
    ensures left == right
  {
  }


  lemma EffectiveAuthorityHasNoIndependentIdentity(
    authority: EffectiveAuthority
  )
    ensures SameEffectiveAuthority(authority, authority)
  {
  }


  // ----------------------------------------------------------
  // MEMBERSHIP
  // ----------------------------------------------------------

  predicate CapabilityIsEffective(
    authority: EffectiveAuthority,
    capability: Capability
  )
  {
    capability in authority
  }


  lemma CapabilityIsEffectiveIffMember(
    authority: EffectiveAuthority,
    capability: Capability
  )
    ensures CapabilityIsEffective(authority, capability)
       <==> capability in authority
  {
  }


  lemma EffectiveAuthorityContainsCapability(
    authority: EffectiveAuthority,
    capability: Capability
  )
    requires CapabilityIsEffective(authority, capability)
    ensures capability in authority
  {
  }


  // ----------------------------------------------------------
  // VALIDITY
  // ----------------------------------------------------------

  predicate ValidEffectiveAuthority(
    authority: EffectiveAuthority
  )
  {
    forall capability ::
      capability in authority
      ==> ValidCapability(capability)
  }


  lemma ValidEffectiveAuthorityContainsValidCapability(
    authority: EffectiveAuthority,
    capability: Capability
  )
    requires ValidEffectiveAuthority(authority)
    requires CapabilityIsEffective(authority, capability)
    ensures ValidCapability(capability)
  {
  }


  // ----------------------------------------------------------
  // AUTHORITY NON-EXPANSION
  // ----------------------------------------------------------

  predicate EffectiveAuthorityWithinSourceAuthority(
    effectiveAuthority: EffectiveAuthority,
    sourceAuthority: set<Capability>
  )
  {
    effectiveAuthority <= sourceAuthority
  }


  lemma EffectiveAuthorityCannotAddSourceCapability(
    effectiveAuthority: EffectiveAuthority,
    sourceAuthority: set<Capability>,
    capability: Capability
  )
    requires EffectiveAuthorityWithinSourceAuthority(
               effectiveAuthority,
               sourceAuthority
             )
    requires CapabilityIsEffective(
               effectiveAuthority,
               capability
             )
    ensures capability in sourceAuthority
  {
  }


  lemma EffectiveAuthorityIsSubsetOfSourceAuthority(
    effectiveAuthority: EffectiveAuthority,
    sourceAuthority: set<Capability>
  )
    requires EffectiveAuthorityWithinSourceAuthority(
               effectiveAuthority,
               sourceAuthority
             )
    ensures effectiveAuthority <= sourceAuthority
  {
  }


  // ----------------------------------------------------------
  // AUTHORITY REDUCTION
  // ----------------------------------------------------------

  lemma ReducedEffectiveAuthorityCannotAddCapability(
    original: EffectiveAuthority,
    reduced: EffectiveAuthority,
    capability: Capability
  )
    requires reduced <= original
    requires CapabilityIsEffective(reduced, capability)
    ensures CapabilityIsEffective(original, capability)
  {
  }


  lemma ReducedEffectiveAuthorityPreservesCapabilityValidity(
    original: EffectiveAuthority,
    reduced: EffectiveAuthority
  )
    requires ValidEffectiveAuthority(original)
    requires reduced <= original
    ensures ValidEffectiveAuthority(reduced)
  {
    forall capability
      | capability in reduced
      ensures ValidCapability(capability)
    {
      ReducedEffectiveAuthorityCannotAddCapability(
        original,
        reduced,
        capability
      );

      ValidEffectiveAuthorityContainsValidCapability(
        original,
        capability
      );
    }
  }


  // ----------------------------------------------------------
  // CREDENTIAL AUTHORITY BOUNDARY
  // ----------------------------------------------------------

  lemma EffectiveAuthorityWithinCredentialAuthority(
    effectiveAuthority: EffectiveAuthority,
    credentialAuthority: CredentialAuthority
  )
    requires EffectiveAuthorityWithinSourceAuthority(
               effectiveAuthority,
               credentialAuthority
             )
    ensures effectiveAuthority <= credentialAuthority
  {
  }


  // ----------------------------------------------------------
  // SESSION AUTHORITY BOUNDARY
  // ----------------------------------------------------------

  lemma EffectiveAuthorityWithinSessionAuthority(
    effectiveAuthority: EffectiveAuthority,
    session: Session
  )
    requires EffectiveAuthorityWithinSourceAuthority(
               effectiveAuthority,
               SessionCapabilities(session)
             )
    ensures effectiveAuthority <= SessionCapabilities(session)
  {
  }


  // ----------------------------------------------------------
  // DELEGATED AUTHORITY BOUNDARY
  // ----------------------------------------------------------

  lemma EffectiveAuthorityWithinDelegatedAuthority(
    effectiveAuthority: EffectiveAuthority,
    delegation: Delegation
  )
    requires EffectiveAuthorityWithinSourceAuthority(
               effectiveAuthority,
               DelegationCapabilities(delegation)
             )
    ensures effectiveAuthority <= DelegationCapabilities(delegation)
  {
  }


  // ----------------------------------------------------------
  // MULTIPLE AUTHORITY BOUNDARIES
  // ----------------------------------------------------------

  lemma EffectiveAuthorityWithinMultipleSources(
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
    requires CapabilityIsEffective(
               effectiveAuthority,
               capability
             )
    ensures capability in firstSource
    ensures capability in secondSource
  {
  }


  // ----------------------------------------------------------
  // MULTIPLE INDEPENDENT SOURCES
  // ----------------------------------------------------------

  predicate DerivedAuthorityWithinSource(
    derivedAuthority: set<Capability>,
    sourceAuthority: set<Capability>
  )
  {
    derivedAuthority <= sourceAuthority
  }


  lemma DerivedAuthorityCannotExceedSource(
    derivedAuthority: set<Capability>,
    sourceAuthority: set<Capability>
  )
    requires DerivedAuthorityWithinSource(
               derivedAuthority,
               sourceAuthority
             )
    ensures derivedAuthority <= sourceAuthority
  {
  }


  // ==========================================================
  // VALUE-ONLY DERIVATION / PROVENANCE RELATION
  // ==========================================================
  //
  // This contract remains available as the pure value-level
  // derivation relation.
  //
  // It establishes:
  //
  //     contribution(i) ⊆ sourceAuthority(i)
  //
  // and:
  //
  //     EffectiveAuthority
  //         =
  //     union of contributions.
  //
  // It intentionally does NOT claim concrete source attribution.
  //
  // Source attribution is established by the stronger relation
  // EffectiveAuthorityDerivedFromAttributedSources below.
  //
  // ----------------------------------------------------------

  ghost predicate EffectiveAuthorityDerivedFromSources(
    effectiveAuthority: EffectiveAuthority,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>
  )
  {
    |sourceAuthorities| == |contributions|
    &&
    (forall i ::
       0 <= i < |contributions|
       ==> contributions[i] <= sourceAuthorities[i])
    &&
    (forall capability ::
       capability in effectiveAuthority
       ==>
         exists i ::
           0 <= i < |contributions|
           && capability in contributions[i])
    &&
    (forall capability ::
       (exists i ::
          0 <= i < |contributions|
          && capability in contributions[i])
       ==> capability in effectiveAuthority)
  }


  lemma DerivedEffectiveAuthorityCapabilityHasSource(
    effectiveAuthority: EffectiveAuthority,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    capability: Capability
  )
    requires EffectiveAuthorityDerivedFromSources(
               effectiveAuthority,
               sourceAuthorities,
               contributions
             )
    requires capability in effectiveAuthority
    ensures exists i ::
              0 <= i < |contributions|
              && capability in contributions[i]
              && capability in sourceAuthorities[i]
  {
    var i :| 0 <= i < |contributions|
             && capability in contributions[i];

    assert capability in sourceAuthorities[i];
  }


  lemma DerivedEffectiveAuthorityCannotExceedSources(
    effectiveAuthority: EffectiveAuthority,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>
  )
    requires EffectiveAuthorityDerivedFromSources(
               effectiveAuthority,
               sourceAuthorities,
               contributions
             )
    ensures forall capability ::
              capability in effectiveAuthority
              ==> exists i ::
                  0 <= i < |sourceAuthorities|
                  && capability in sourceAuthorities[i]
  {
    forall capability
      | capability in effectiveAuthority
      ensures exists i ::
                0 <= i < |sourceAuthorities|
                && capability in sourceAuthorities[i]
    {
      DerivedEffectiveAuthorityCapabilityHasSource(
        effectiveAuthority,
        sourceAuthorities,
        contributions,
        capability
      );
    }
  }


  // ==========================================================
  // ATTRIBUTED DERIVATION / CONCRETE SOURCE PROVENANCE
  // ==========================================================
  //
  // Canonical source-sensitive provenance contract.
  //
  // The three sequences are index-aligned:
  //
  //
  //     sourceReferences[i]
  //             |
  //             v
  //     sourceAuthorities[i]
  //             |
  //             v
  //      contributions[i]
  //
  //  Therefore each contribution is associated with a concrete
  //  authority source reference.
  //
  //  The authority values themselves remain set<Capability>.
  //  Concrete source identity exists only in this ghost relation.
  //
  // ----------------------------------------------------------

  ghost predicate EffectiveAuthorityDerivedFromAttributedSources(
    effectiveAuthority: EffectiveAuthority,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>
  )
  {
    |sourceReferences| == |sourceAuthorities|
    &&
    |sourceAuthorities| == |contributions|
    &&
    (forall i ::
       0 <= i < |sourceReferences|
       ==> ValidAuthoritySourceReference(
           sourceReferences[i]
         ))
    &&
    (forall i ::
       0 <= i < |contributions|
       ==> contributions[i] <= sourceAuthorities[i])
    &&
    (forall capability ::
       capability in effectiveAuthority
       ==>
         exists i ::
           0 <= i < |contributions|
           && capability in contributions[i])
    &&
    (forall capability ::
       (exists i ::
          0 <= i < |contributions|
          && capability in contributions[i])
       ==> capability in effectiveAuthority)
  }


  // Every attributed source is associated with exactly one
  // authority value at the same sequence index.

  lemma AttributedSourceHasAlignedAuthority(
    effectiveAuthority: EffectiveAuthority,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    index: int
  )
    requires EffectiveAuthorityDerivedFromAttributedSources(
               effectiveAuthority,
               sourceReferences,
               sourceAuthorities,
               contributions
             )
    requires 0 <= index < |sourceReferences|
    ensures index < |sourceAuthorities|
    ensures index < |contributions|
    ensures ValidAuthoritySourceReference(
              sourceReferences[index]
            )
    ensures contributions[index] <= sourceAuthorities[index]
  {
  }


  // Every effective capability can be traced to both:
  // 
  //     - an attributed concrete source;
  //     - an authority value;
  //     - a contribution.
  //
  // This is the key source-sensitive strengthening over the
  // value-only provenance relation.

  lemma AttributedEffectiveAuthorityCapabilityHasConcreteSource(
    effectiveAuthority: EffectiveAuthority,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    capability: Capability
  )
    requires EffectiveAuthorityDerivedFromAttributedSources(
               effectiveAuthority,
               sourceReferences,
               sourceAuthorities,
               contributions
             )
    requires capability in effectiveAuthority
    ensures exists i ::
              0 <= i < |sourceReferences|
              && ValidAuthoritySourceReference(
                sourceReferences[i]
              )
              && capability in contributions[i]
              && capability in sourceAuthorities[i]
  {
    var i :|
      0 <= i < |contributions|
      &&
      capability in contributions[i];

    assert i < |sourceReferences|;
    assert i < |sourceAuthorities|;

    assert ValidAuthoritySourceReference(
        sourceReferences[i]
      );

    assert capability in sourceAuthorities[i];

    assert
      exists i ::
        0 <= i < |sourceReferences|
        && ValidAuthoritySourceReference(
          sourceReferences[i]
        )
        && capability in contributions[i]
        && capability in sourceAuthorities[i];
  }


  // Every attributed contribution remains bounded by the concrete
  // source reference's associated authority value.

  lemma AttributedContributionCannotExceedAttributedSource(
    effectiveAuthority: EffectiveAuthority,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    index: int
  )
    requires EffectiveAuthorityDerivedFromAttributedSources(
               effectiveAuthority,
               sourceReferences,
               sourceAuthorities,
               contributions
             )
    requires 0 <= index < |contributions|
    ensures contributions[index] <= sourceAuthorities[index]
  {
  }


  lemma AttributedContributionCapabilityIsSourceBounded(
    effectiveAuthority: EffectiveAuthority,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    index: int,
    capability: Capability
  )
    requires EffectiveAuthorityDerivedFromAttributedSources(
               effectiveAuthority,
               sourceReferences,
               sourceAuthorities,
               contributions
             )
    requires 0 <= index < |contributions|
    requires capability in contributions[index]
    ensures capability in sourceAuthorities[index]
  {
  }


  // ----------------------------------------------------------
  // SOURCE REFERENCE DISTINCTNESS
  // ----------------------------------------------------------

  // Distinct concrete source references remain distinct even when
  // their authority values are equal.
  //
  // This is the direct formal property required to prevent the
  // previous source-attribution collision.

  lemma DistinctSourceReferencesRemainDistinctUnderEqualAuthority(
    firstReference: AuthoritySourceReference,
    secondReference: AuthoritySourceReference,
    firstAuthority: set<Capability>,
    secondAuthority: set<Capability>
  )
    requires firstReference != secondReference
    requires firstAuthority == secondAuthority
    ensures firstReference != secondReference
    ensures firstAuthority == secondAuthority
  {
  }


  // The attributed witness therefore carries source identity that
  // is independent of the authority value.

  lemma EqualAuthorityValuesDoNotCollapseAttributedSources(
    firstReference: AuthoritySourceReference,
    secondReference: AuthoritySourceReference,
    authority: set<Capability>,
    contributions: set<Capability>
  )
    requires firstReference != secondReference
    requires contributions <= authority
    ensures
      firstReference != secondReference
    ensures
      [firstReference] != [secondReference]
  {
    assert firstReference != secondReference;
    assert [firstReference] != [secondReference];
  }


  // ----------------------------------------------------------
  // ATTRIBUTED PROVENANCE PROJECTS TO VALUE-ONLY PROVENANCE
  // ----------------------------------------------------------
  //
  // The stronger attributed relation implies the existing
  // value-only relation.
  //
  // This permits gradual propagation through the dependency graph:
  //
  //     attributed provenance
  //             ↓
  //     value-only provenance
  //
  // without duplicating the underlying derivation semantics.

  lemma AttributedProvenanceImpliesValueOnlyProvenance(
    effectiveAuthority: EffectiveAuthority,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>
  )
    requires EffectiveAuthorityDerivedFromAttributedSources(
               effectiveAuthority,
               sourceReferences,
               sourceAuthorities,
               contributions
             )
    ensures EffectiveAuthorityDerivedFromSources(
              effectiveAuthority,
              sourceAuthorities,
              contributions
            )
  {
    assert
      |sourceAuthorities|
      ==
      |contributions|;

    assert
      forall i ::
        0 <= i < |contributions|
        ==> contributions[i] <= sourceAuthorities[i];

    assert
      forall capability ::
        capability in effectiveAuthority
        ==>
          exists i ::
            0 <= i < |contributions|
            &&
            capability in contributions[i];

    assert
      forall capability ::
        (exists i ::
           0 <= i < |contributions|
           && capability in contributions[i])
        ==> capability in effectiveAuthority;

    assert
      EffectiveAuthorityDerivedFromSources(
        effectiveAuthority,
        sourceAuthorities,
        contributions
      );
  }


  // ----------------------------------------------------------
  // RECOGNIZED SOURCE BOUNDARY — VALUE LEVEL
  // ----------------------------------------------------------

  ghost predicate EffectiveAuthorityHasRecognizedSourceProvenance(
    effectiveAuthority: EffectiveAuthority,
    recognizedSourceAuthorities: set<set<Capability>>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>
  )
  {
    EffectiveAuthorityDerivedFromSources(
      effectiveAuthority,
      sourceAuthorities,
      contributions
    )
    &&
    (forall i ::
       0 <= i < |sourceAuthorities|
       ==> sourceAuthorities[i] in recognizedSourceAuthorities)
  }


  lemma RecognizedEffectiveAuthorityCapabilityHasRecognizedSource(
    effectiveAuthority: EffectiveAuthority,
    recognizedSourceAuthorities: set<set<Capability>>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    capability: Capability
  )
    requires EffectiveAuthorityHasRecognizedSourceProvenance(
               effectiveAuthority,
               recognizedSourceAuthorities,
               sourceAuthorities,
               contributions
             )
    requires capability in effectiveAuthority
    ensures exists sourceAuthority ::
              sourceAuthority in recognizedSourceAuthorities
              && capability in sourceAuthority
  {
    var i :| 0 <= i < |contributions|
             && capability in contributions[i];

    assert sourceAuthorities[i] in recognizedSourceAuthorities;
    assert capability in sourceAuthorities[i];

    assert exists sourceAuthority ::
        sourceAuthority in recognizedSourceAuthorities
        && capability in sourceAuthority;
  }


  // ----------------------------------------------------------
  // RECOGNIZED ATTRIBUTED PROVENANCE
  // ----------------------------------------------------------
  //
  // The source-aware form separates two obligations:
  //
  //   1. EffectiveAuthority attribution is structurally coherent.
  //   2. The concrete references are recognized by the caller.
  //
  // This file does not decide source recognition.
  //
  // The caller supplies recognized source references as a set of
  // concrete source keys already grounded in its contextual state.

  ghost predicate EffectiveAuthorityHasRecognizedAttributedSourceProvenance(
    effectiveAuthority: EffectiveAuthority,
    recognizedSourceReferences: set<AuthoritySourceReference>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>
  )
  {
    EffectiveAuthorityDerivedFromAttributedSources(
      effectiveAuthority,
      sourceReferences,
      sourceAuthorities,
      contributions
    )
    &&
    (forall i ::
       0 <= i < |sourceReferences|
       ==> sourceReferences[i]
           in recognizedSourceReferences)
  }


  lemma RecognizedAttributedEffectiveAuthorityCapabilityHasConcreteSource(
    effectiveAuthority: EffectiveAuthority,
    recognizedSourceReferences: set<AuthoritySourceReference>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    capability: Capability
  )
    requires EffectiveAuthorityHasRecognizedAttributedSourceProvenance(
               effectiveAuthority,
               recognizedSourceReferences,
               sourceReferences,
               sourceAuthorities,
               contributions
             )
    requires capability in effectiveAuthority
    ensures exists i ::
              0 <= i < |sourceReferences|
              && sourceReferences[i]
                 in recognizedSourceReferences
              && capability in contributions[i]
              && capability in sourceAuthorities[i]
  {
    var i :|
      0 <= i < |contributions|
      &&
      capability in contributions[i];

    assert i < |sourceReferences|;
    assert i < |sourceAuthorities|;

    assert
      sourceReferences[i]
      in recognizedSourceReferences;

    assert capability in sourceAuthorities[i];

    assert
      exists i ::
        0 <= i < |sourceReferences|
        && sourceReferences[i]
           in recognizedSourceReferences
        && capability in contributions[i]
        && capability in sourceAuthorities[i];
  }


  // ----------------------------------------------------------
  // PROVENANCE + STRUCTURAL VALIDITY
  // ----------------------------------------------------------

  ghost predicate ValidContextuallyDerivedEffectiveAuthority(
    effectiveAuthority: EffectiveAuthority,
    recognizedSourceAuthorities: set<set<Capability>>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>
  )
  {
    ValidEffectiveAuthority(effectiveAuthority)
    &&
    EffectiveAuthorityHasRecognizedSourceProvenance(
      effectiveAuthority,
      recognizedSourceAuthorities,
      sourceAuthorities,
      contributions
    )
  }


  // Source-attributed contextual validity.
  //
  // Concrete source recognition is explicit, but remains external
  // contextual proof material.

  ghost predicate ValidContextuallyAttributedEffectiveAuthority(
    effectiveAuthority: EffectiveAuthority,
    recognizedSourceReferences: set<AuthoritySourceReference>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>
  )
  {
    ValidEffectiveAuthority(effectiveAuthority)
    &&
    EffectiveAuthorityHasRecognizedAttributedSourceProvenance(
      effectiveAuthority,
      recognizedSourceReferences,
      sourceReferences,
      sourceAuthorities,
      contributions
    )
  }


  // ----------------------------------------------------------
  // PROVENANCE PRESERVES SOURCE NON-EXPANSION
  // ----------------------------------------------------------

  lemma ProvenanceContributionCannotExceedItsSource(
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    index: int
  )
    requires 0 <= index < |contributions|
    requires |sourceAuthorities| == |contributions|
    requires contributions[index] <= sourceAuthorities[index]
    ensures contributions[index] <= sourceAuthorities[index]
  {
  }


  lemma ProvenanceContributionCapabilityIsSourceBounded(
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    index: int,
    capability: Capability
  )
    requires 0 <= index < |contributions|
    requires |sourceAuthorities| == |contributions|
    requires contributions[index] <= sourceAuthorities[index]
    requires capability in contributions[index]
    ensures capability in sourceAuthorities[index]
  {
  }


  // Source-attributed equivalent.

  lemma AttributedProvenanceContributionCapabilityIsSourceBounded(
    effectiveAuthority: EffectiveAuthority,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    index: int,
    capability: Capability
  )
    requires EffectiveAuthorityDerivedFromAttributedSources(
               effectiveAuthority,
               sourceReferences,
               sourceAuthorities,
               contributions
             )
    requires 0 <= index < |contributions|
    requires capability in contributions[index]
    ensures capability in sourceAuthorities[index]
  {
  }


  // ----------------------------------------------------------
  // REDUCTION OF PROVENANCE-BACKED AUTHORITY
  // ----------------------------------------------------------

  lemma ReducedDerivedEffectiveAuthorityRetainsSourceBoundary(
    original: EffectiveAuthority,
    reduced: EffectiveAuthority,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    capability: Capability
  )
    requires EffectiveAuthorityDerivedFromSources(
               original,
               sourceAuthorities,
               contributions
             )
    requires reduced <= original
    requires capability in reduced
    ensures exists i ::
              0 <= i < |sourceAuthorities|
              && capability in sourceAuthorities[i]
  {
    ReducedEffectiveAuthorityCannotAddCapability(
      original,
      reduced,
      capability
    );

    DerivedEffectiveAuthorityCannotExceedSources(
      original,
      sourceAuthorities,
      contributions
    );
  }


  // The attributed form retains the same source boundary while also
  // preserving concrete source attribution.

  lemma ReducedAttributedDerivedEffectiveAuthorityRetainsSourceBoundary(
    original: EffectiveAuthority,
    reduced: EffectiveAuthority,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    capability: Capability
  )
    requires EffectiveAuthorityDerivedFromAttributedSources(
               original,
               sourceReferences,
               sourceAuthorities,
               contributions
             )
    requires reduced <= original
    requires capability in reduced
    ensures exists i ::
              0 <= i < |sourceReferences|
              && capability in sourceAuthorities[i]
  {
    var i :|
      0 <= i < |contributions|
      &&
      capability in contributions[i];

    assert i < |sourceReferences|;
    assert capability in sourceAuthorities[i];
  }


  // ----------------------------------------------------------
  // VALIDITY OF SOURCE-BOUNDED DERIVATION
  // ----------------------------------------------------------

  ghost predicate AllSourceAuthoritiesAreValid(
    sourceAuthorities: seq<set<Capability>>
  )
  {
    forall i ::
      0 <= i < |sourceAuthorities|
      ==>
        forall capability ::
          capability in sourceAuthorities[i]
          ==> ValidCapability(capability)
  }


  lemma DerivedEffectiveAuthorityFromValidSourcesIsValid(
    effectiveAuthority: EffectiveAuthority,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>
  )
    requires EffectiveAuthorityDerivedFromSources(
               effectiveAuthority,
               sourceAuthorities,
               contributions
             )
    requires AllSourceAuthoritiesAreValid(
               sourceAuthorities
             )
    ensures ValidEffectiveAuthority(
              effectiveAuthority
            )
  {
    forall capability
      | capability in effectiveAuthority
      ensures ValidCapability(capability)
    {
      var i :| 0 <= i < |contributions|
               && capability in contributions[i];

      assert capability in sourceAuthorities[i];

      assert ValidCapability(capability);
    }
  }


  // Attributed source provenance carries the same structural
  // capability validity guarantee.

  lemma AttributedEffectiveAuthorityFromValidSourcesIsValid(
    effectiveAuthority: EffectiveAuthority,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>
  )
    requires EffectiveAuthorityDerivedFromAttributedSources(
               effectiveAuthority,
               sourceReferences,
               sourceAuthorities,
               contributions
             )
    requires AllSourceAuthoritiesAreValid(
               sourceAuthorities
             )
    ensures ValidEffectiveAuthority(
              effectiveAuthority
            )
  {
    forall capability
      | capability in effectiveAuthority
      ensures ValidCapability(capability)
    {
      var i :|
        0 <= i < |contributions|
        &&
        capability in contributions[i];

      assert capability in sourceAuthorities[i];
      assert ValidCapability(capability);
    }
  }


  // ----------------------------------------------------------
  // TEMPORAL / CONTEXTUAL SEPARATION
  // ----------------------------------------------------------

  // Effective Authority itself contains no timestamp and does not
  // define temporal validity.
  //
  // Session and Delegation may impose temporal conditions, but
  // whether those conditions are satisfied at a particular time
  // belongs to contextual Authorization Validation.
  //
  // Effective Authority also does not encode:
  //
  //   - Execution Context;
  //   - Execution Target;
  //   - Proof;
  //   - Replay state;
  //   - Policy evaluation;
  //   - concrete Restriction evaluation.
  //
  // Those concerns constrain when an Effective Authority may be
  // accepted, but they are not part of the identity/value semantics
  // of EffectiveAuthority itself.
}

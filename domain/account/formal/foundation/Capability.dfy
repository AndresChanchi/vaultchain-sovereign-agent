// ============================================================
// KIPIO ACCOUNT DOMAIN
// FOUNDATION — CAPABILITY
// ============================================================
//
// Capability semantics for the Account domain.
//
// Capability is a Value Object representing a semantic faculty
// that may be exercised under the authority model.
//
// Its complete semantic value is:
//
//     Capability
//         = CapabilityKind + Scope
//
// Capability therefore has:
//   - no CapabilityId;
//   - no independent lifecycle;
//   - no ownership identity;
//   - no execution identity.
//
// Metadata associated with a Capability is intentionally modeled
// separately from the Capability value because metadata does not
// modify the authority represented by the Capability.
//
// This file intentionally contains no:
//   - credential logic
//   - credential authority logic
//   - session logic
//   - delegation logic
//   - effective authority calculation
//   - authorization logic
//   - policy logic
//   - execution logic
//   - cryptographic verification
//   - blockchain ABI types
//   - storage representations
//
// IMPORTANT DOMAIN RULE:
//
//   Delegate is a semantically special CapabilityKind defined by
//   Kipio Account itself.
//
//   Delegate is NOT:
//   - a separate Entity;
//   - a separate Capability type;
//   - a technical "delegatable = true" flag;
//   - a consumer-defined capability.
//
//   A Delegate Capability is still an ordinary Capability:
//
//       Capability(Delegate, Scope)
//
//   Its special meaning is established by the domain laws governing
//   delegation. Those higher-level authority relations are intentionally
//   NOT defined in this foundation module.
//
// ============================================================

include "DomainPrimitives.dfy"
include "Scope.dfy"

module KipioAccountCapability
{
  import opened KipioAccountDomainPrimitives
  import opened KipioAccountScope


  // ----------------------------------------------------------
  // CAPABILITY KIND
  // ----------------------------------------------------------

  // CapabilityKind identifies the semantic class of a Capability.
  //
  // Examples of ordinary consumer-facing kinds may include:
  //
  //     Upload
  //     Delete
  //     Share
  //     Transfer
  //     Approve
  //
  // The domain additionally reserves one semantic CapabilityKind:
  //
  //     Delegate
  //
  // Unlike ordinary consumer-defined capability kinds, Delegate
  // has intrinsic semantic meaning in Kipio Account:
  //
  //     it represents the faculty required to perform delegation.
  //
  // CapabilityKind itself does NOT grant authority.
  //
  // The authority to exercise a CapabilityKind depends on the
  // higher-level authority model and the current Account state.
  datatype CapabilityKind =
    CapabilityKind(
      name: string
    )


  // A CapabilityKind is structurally valid when it has a
  // non-empty semantic name.
  //
  // Delegate is valid under the same structural rule.
  //
  // The semantic consequences of Delegate are defined by
  // delegation/authority laws, not by structural validity.
  predicate ValidCapabilityKind(
    kind: CapabilityKind
  )
  {
    |kind.name| > 0
  }


  // Returns the semantic name of a CapabilityKind.
  function CapabilityKindName(
    kind: CapabilityKind
  ): string
  {
    kind.name
  }


  // ----------------------------------------------------------
  // SPECIAL DOMAIN CAPABILITY KIND: DELEGATE
  // ----------------------------------------------------------

  // Canonical semantic CapabilityKind representing the faculty
  // required to perform delegation.
  //
  // This value is part of the Kipio Account domain itself.
  //
  // It is deliberately represented through the existing
  // CapabilityKind value type rather than through:
  //
  //   - a separate enum;
  //   - a boolean "delegatable" flag;
  //   - a new Capability subtype;
  //   - a new Entity.
  //
  // Therefore:
  //
  //     CapabilityKind("Delegate")
  //
  // is the canonical semantic representation of Delegate.
  function DelegateCapabilityKind(): CapabilityKind
  {
    CapabilityKind("Delegate")
  }


  // Determines whether a CapabilityKind is the special domain
  // kind Delegate.
  predicate IsDelegateKind(
    kind: CapabilityKind
  )
  {
    kind == DelegateCapabilityKind()
  }


  // A canonical Delegate Capability can be constructed with any
  // semantically valid Scope.
  //
  // The Scope determines the context over which the delegation
  // faculty itself is represented.
  //
  // This function does NOT establish that the holder is actually
  // authorized to delegate. That determination belongs to the
  // higher-level authority model.
  function DelegateCapability(
    scope: Scope
  ): Capability
  {
    Capability(
      DelegateCapabilityKind(),
      scope
    )
  }


  // A valid Delegate Capability has:
  //
  //   - the canonical Delegate CapabilityKind;
  //   - a valid Scope.
  //
  // This remains structural validity only. It does not mean that
  // an Identity currently possesses effective authority to exercise
  // the Delegate Capability.
  predicate ValidDelegateCapability(
    capability: Capability
  )
  {
    IsDelegateCapability(capability)
    &&
    ValidScope(
      CapabilityScope(capability)
    )
  }


  // ----------------------------------------------------------
  // CAPABILITY METADATA
  // ----------------------------------------------------------

  // Capability metadata is descriptive information associated
  // with a Capability.
  //
  // Metadata is deliberately NOT part of the Capability value.
  //
  // It may later be represented as:
  //
  //   - public data;
  //   - private data;
  //   - encrypted data;
  //   - zero-knowledge-related data;
  //   - application-specific descriptive information.
  //
  // None of those representations changes the semantic identity
  // or authority meaning of a Capability.
  type CapabilityMetadata = seq<bv8>


  // ----------------------------------------------------------
  // CAPABILITY
  // ----------------------------------------------------------

  // Capability is a Value Object.
  //
  // Two Capabilities with the same CapabilityKind and Scope
  // represent the same semantic faculty.
  //
  // There is intentionally no CapabilityId because the domain
  // does not distinguish equal faculties as separate instances.
  //
  // Metadata is intentionally excluded from this value.
  //
  // Delegate is represented by the same Capability type:
  //
  //     Capability(Delegate, Scope)
  //
  // It does not require a separate type.
  datatype Capability =
    Capability(
      kind: CapabilityKind,
      scope: Scope
    )


  // ----------------------------------------------------------
  // ACCESSORS
  // ----------------------------------------------------------

  // Returns the semantic kind of a Capability.
  function CapabilityKindOf(
    capability: Capability
  ): CapabilityKind
  {
    capability.kind
  }


  // Returns the semantic Scope over which the Capability may
  // be exercised.
  function CapabilityScope(
    capability: Capability
  ): Scope
  {
    capability.scope
  }


  // Determines whether a Capability is the special Delegate
  // Capability.
  //
  // This predicate identifies the semantic kind only.
  //
  // It does NOT establish:
  //
  //   - effective authority;
  //   - current usability;
  //   - delegatable authority;
  //   - Account recognition;
  //   - authorization to perform a delegation.
  //
  // Those concepts belong to higher-level domain modules.
  predicate IsDelegateCapability(
    capability: Capability
  )
  {
    IsDelegateKind(
      CapabilityKindOf(capability)
    )
  }


  // ----------------------------------------------------------
  // VALUE OBJECT EQUALITY
  // ----------------------------------------------------------

  // Determines whether two Capabilities represent the same
  // semantic faculty.
  //
  // Capability equality is determined entirely by:
  //
  //     CapabilityKind
  //     +
  //     Scope
  //
  // No independent identifier participates.
  predicate SameCapability(
    left: Capability,
    right: Capability
  )
  {
    CapabilityKindOf(left) == CapabilityKindOf(right)
    &&
    CapabilityScope(left) == CapabilityScope(right)
  }


  // Two Capabilities with the same semantic values are equal.
  lemma CapabilitiesWithSameSemanticValuesAreEqual(
    left: Capability,
    right: Capability
  )
    requires SameCapability(left, right)
    ensures left == right
  {
  }


  // Equal Dafny Capability values necessarily represent the same
  // semantic faculty.
  lemma EqualCapabilitiesHaveEqualSemanticValues(
    left: Capability,
    right: Capability
  )
    requires left == right
    ensures SameCapability(left, right)
  {
  }


  // Equality of Capabilities depends only on CapabilityKind and
  // Scope.
  lemma CapabilityEqualityDependsOnKindAndScope(
    left: Capability,
    right: Capability
  )
    requires left == right
    ensures CapabilityKindOf(left)
         == CapabilityKindOf(right)
    ensures CapabilityScope(left)
         == CapabilityScope(right)
  {
  }


  // A Capability has no independent identity beyond its semantic
  // value.
  lemma CapabilityHasNoIndependentIdentity(
    capability: Capability
  )
    ensures SameCapability(capability, capability)
  {
  }


  // ----------------------------------------------------------
  // DELEGATE CAPABILITY LAWS
  // ----------------------------------------------------------

  // The canonical Delegate kind is structurally valid.
  lemma DelegateCapabilityKindIsValid()
    ensures ValidCapabilityKind(
              DelegateCapabilityKind()
            )
  {
  }


  // A Capability constructed through DelegateCapability has the
  // canonical Delegate CapabilityKind.
  lemma ConstructedDelegateCapabilityHasDelegateKind(
    scope: Scope
  )
    ensures IsDelegateCapability(
              DelegateCapability(scope)
            )
  {
  }


  // Every Delegate Capability is still an ordinary Capability
  // value whose semantic kind is Delegate and whose Scope remains
  // part of its value.
  lemma DelegateCapabilityPreservesValueSemantics(
    scope: Scope
  )
    ensures CapabilityKindOf(
              DelegateCapability(scope)
            )
         == DelegateCapabilityKind()
    ensures CapabilityScope(
              DelegateCapability(scope)
            )
         == scope
  {
  }


  // If the Scope is valid, the corresponding Delegate Capability
  // is structurally valid.
  //
  // This does NOT mean the holder possesses authority to exercise
  // it. It only proves structural validity of the value itself.
  lemma ValidScopeProducesValidDelegateCapability(
    scope: Scope
  )
    requires ValidScope(scope)
    ensures ValidDelegateCapability(
              DelegateCapability(scope)
            )
    ensures ValidCapability(
              DelegateCapability(scope)
            )
  {
  }


  // A Delegate Capability is recognized by semantic kind, not by
  // a separate identity or a technical flag.
  lemma DelegateCapabilityIsCapabilityKindBased(
    capability: Capability
  )
    ensures IsDelegateCapability(capability)
            <==>
            IsDelegateKind(
              CapabilityKindOf(capability)
            )
  {
  }


  // ----------------------------------------------------------
  // CAPABILITY VALIDITY
  // ----------------------------------------------------------

  // A Capability is structurally valid when:
  //
  //   - its CapabilityKind is valid;
  //   - its Scope is valid.
  //
  // Metadata is intentionally absent because it is not part of
  // Capability semantic validity.
  predicate ValidCapability(
    capability: Capability
  )
  {
    ValidCapabilityKind(
      CapabilityKindOf(capability)
    )
    &&
    ValidScope(
      CapabilityScope(capability)
    )
  }


  // A valid Capability exposes a valid CapabilityKind.
  lemma ValidCapabilityHasValidKind(
    capability: Capability
  )
    requires ValidCapability(capability)
    ensures ValidCapabilityKind(
              CapabilityKindOf(capability)
            )
  {
  }


  // A valid Capability exposes a valid Scope.
  lemma ValidCapabilityHasValidScope(
    capability: Capability
  )
    requires ValidCapability(capability)
    ensures ValidScope(
              CapabilityScope(capability)
            )
  {
  }


  // A structurally valid Delegate Capability is also a valid
  // Capability under the general Capability validity predicate.
  lemma ValidDelegateCapabilityIsValidCapability(
    capability: Capability
  )
    requires ValidDelegateCapability(capability)
    ensures ValidCapability(capability)
  {
  }


  // ----------------------------------------------------------
  // CAPABILITY SEMANTIC BOUNDARY
  // ----------------------------------------------------------

  // Semantic authority meaning of two Capability values is
  // determined by Kind + Scope only.
  //
  // This is intentionally equivalent to SameCapability because
  // Capability is a Value Object.
  predicate SameAuthorityMeaning(
    left: Capability,
    right: Capability
  )
  {
    SameCapability(left, right)
  }


  // Equal Capability values have the same authority meaning.
  lemma EqualCapabilitiesHaveSameAuthorityMeaning(
    left: Capability,
    right: Capability
  )
    requires left == right
    ensures SameAuthorityMeaning(left, right)
  {
  }


  // ----------------------------------------------------------
  // METADATA SEPARATION
  // ----------------------------------------------------------

  // Capability metadata is not part of Capability semantic value.
  //
  // Metadata therefore cannot distinguish two semantically equal
  // Capability values.
  //
  // Since metadata is represented separately, changing metadata
  // does not alter:
  //
  //   - CapabilityKind;
  //   - Scope;
  //   - Capability equality;
  //   - Capability authority meaning.
  lemma MetadataDoesNotDefineCapabilityAuthority(
    capability: Capability,
    metadataBefore: CapabilityMetadata,
    metadataAfter: CapabilityMetadata
  )
    ensures SameAuthorityMeaning(capability, capability)
  {
  }
}

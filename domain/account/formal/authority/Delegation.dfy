// ============================================================
// KIPIO ACCOUNT DOMAIN
// AUTHORITY — DELEGATION
// ============================================================
//
// Delegation is an Entity representing a bounded derivation of
// authority from an authority source toward a Delegatee.
//
// Delegation identity is determined by DelegationId.
//
// The Delegator is referenced by IdentityId rather than embedding
// the Identity Entity itself.
//
// The Delegatee is represented as Subject because Subject is a
// Value Object / semantic actor descriptor.
//
// Delegated authority must never exceed the authority that the
// source is legitimately allowed to delegate.
//
// A Delegation has exactly one source Identity.
//
// The source of a Delegation is not necessarily the sovereign
// Identity of the Account. This distinction is required for
// transitive delegation:
//
//     sovereign Identity A
//            |
//            └── delegation → B
//                                  |
//                                  └── delegation → C
//
// In such a chain, B may become the source of a later Delegation
// without becoming sovereign over the original Account.
//
// Delegation therefore distinguishes:
//
//     Source Identity
//         = Identity whose authority originates this delegation
//
//     Delegatee
//         = Subject receiving delegated authority
//
//     Sovereign Identity
//         = Account-level concept represented by Account
//
// Delegation itself does not calculate whether its source actually
// owns sufficient authority. That determination is contextual and
// belongs to Authorization State / Effective Authority semantics.
//
// ------------------------------------------------------------
//
// D1 — DELEGATION AUTHORITY MODEL
//
// The source must possess the semantic Delegate Capability in its
// Effective Authority in order to perform the delegation act:
//
//     Delegate ∈ EffectiveAuthority(source)
//
// The authority actually conferred is separately bounded:
//
//     DelegatedAuthority
//         ⊆
//     DelegatableAuthority(source)
//
// and:
//
//     DelegatableAuthority(source)
//         ⊆
//     EffectiveAuthority(source)
//
// Therefore:
//
//     DelegatedAuthority
//         ⊆
//     DelegatableAuthority
//         ⊆
//     EffectiveAuthority
//
// IMPORTANT:
//
// Delegate is the Capability that enables the ACT of delegation.
// It is NOT required to be part of DelegatableAuthority merely
// because it is required to perform delegation.
//
// Example:
//
//     EffectiveAuthority(B)
//         = { Delegate, Edit, Transfer }
//
//     DelegatableAuthority(B)
//         = { Edit }
//
//     B → C : Edit
//
// is valid.
//
// The source must possess Delegate in EffectiveAuthority, but
// Delegate itself does not become delegatable automatically.
//
// ------------------------------------------------------------
//
// Lifecycle:
//
//     Active
//       │
//       └── revoke ──► Revoked
//
// Expiration is derived from the validity interval and an
// evaluation timestamp. It is not represented as a separate
// persistent lifecycle state.
//
// This file intentionally contains no:
//   - Account sovereignty resolution
//   - Authorization State definition
//   - Delegation-chain provenance storage
//   - effective authority calculation
//   - authorization logic
//   - policy logic
//   - session logic
//   - credential verification
//   - proof verification
//   - cryptographic mechanism definitions
//   - execution logic
//   - blockchain ABI types
//   - storage representations
//
// ============================================================

include "../foundation/DomainPrimitives.dfy"
include "../foundation/Subject.dfy"
include "../foundation/Capability.dfy"
include "../foundation/Restriction.dfy"

module KipioAccountDelegation
{
  import opened KipioAccountDomainPrimitives
  import opened KipioAccountSubject
  import opened KipioAccountCapability
  import opened KipioAccountRestriction


  // ----------------------------------------------------------
  // DELEGATION STATUS
  // ----------------------------------------------------------

  datatype DelegationStatus =
      Active
    | Revoked


  // ----------------------------------------------------------
  // DELEGATION
  // ----------------------------------------------------------

  datatype Delegation =
    Delegation(
      id: Id,
      delegatorIdentityId: Id,
      delegatee: Subject,
      capabilities: set<Capability>,
      validFrom: Timestamp,
      validUntil: Timestamp,
      restrictions: set<Restriction>,
      metadata: seq<bv8>,
      status: DelegationStatus
    )


  // ----------------------------------------------------------
  // ACCESSORS
  // ----------------------------------------------------------

  function DelegationId(
    delegation: Delegation
  ): Id
  {
    delegation.id
  }


  function DelegationSourceIdentityId(
    delegation: Delegation
  ): Id
  {
    delegation.delegatorIdentityId
  }


  function DelegationDelegatee(
    delegation: Delegation
  ): Subject
  {
    delegation.delegatee
  }


  function DelegationCapabilities(
    delegation: Delegation
  ): set<Capability>
  {
    delegation.capabilities
  }


  function DelegationRestrictions(
    delegation: Delegation
  ): set<Restriction>
  {
    delegation.restrictions
  }


  function DelegationValidFrom(
    delegation: Delegation
  ): Timestamp
  {
    delegation.validFrom
  }


  function DelegationValidUntil(
    delegation: Delegation
  ): Timestamp
  {
    delegation.validUntil
  }


  function DelegationMetadata(
    delegation: Delegation
  ): seq<bv8>
  {
    delegation.metadata
  }


  function DelegationStatusOf(
    delegation: Delegation
  ): DelegationStatus
  {
    delegation.status
  }


  // ----------------------------------------------------------
  // SOURCE SEMANTICS
  // ----------------------------------------------------------

  // Every Delegation contains exactly one source Identity
  // reference because the Entity has exactly one source IdentityId
  // field.
  //
  // This establishes structural uniqueness of the source reference.
  // It does NOT establish that the referenced Identity currently
  // has the authority required to perform the delegation.
  predicate DelegationHasExactlyOneSource(
    delegation: Delegation
  )
  {
    ValidId(DelegationSourceIdentityId(delegation))
  }


  lemma ValidDelegationHasExactlyOneSource(
    delegation: Delegation
  )
    requires ValidDelegation(delegation)
    ensures DelegationHasExactlyOneSource(delegation)
  {
  }


  // ----------------------------------------------------------
  // LIFECYCLE PREDICATES
  // ----------------------------------------------------------

  predicate DelegationIsActive(
    delegation: Delegation
  )
  {
    DelegationStatusOf(delegation) == Active
  }


  predicate DelegationIsRevoked(
    delegation: Delegation
  )
  {
    DelegationStatusOf(delegation) == Revoked
  }


  predicate DelegationIsExpiredAt(
    delegation: Delegation,
    now: Timestamp
  )
  {
    now > DelegationValidUntil(delegation)
  }


  predicate DelegationIsWithinValidityIntervalAt(
    delegation: Delegation,
    now: Timestamp
  )
  {
    DelegationValidFrom(delegation) <= now
    && now <= DelegationValidUntil(delegation)
  }


  predicate DelegationCanCurrentlyExerciseAuthorityAt(
    delegation: Delegation,
    now: Timestamp
  )
  {
    DelegationIsActive(delegation)
    && DelegationIsWithinValidityIntervalAt(
      delegation,
      now
    )
  }


  // ----------------------------------------------------------
  // STRUCTURAL VALIDITY
  // ----------------------------------------------------------

  predicate ValidDelegation(
    delegation: Delegation
  )
  {
    ValidId(DelegationId(delegation))
    && ValidId(DelegationSourceIdentityId(delegation))
    && ValidSubject(DelegationDelegatee(delegation))
    && DelegationValidFrom(delegation)
       <= DelegationValidUntil(delegation)

    && (forall capability ::
          capability in DelegationCapabilities(delegation)
          ==> ValidCapability(capability))

    && (forall restriction ::
          restriction in DelegationRestrictions(delegation)
          ==> ValidRestriction(restriction))
  }


  // ----------------------------------------------------------
  // ENTITY IDENTITY
  // ----------------------------------------------------------

  predicate SameDelegation(
    left: Delegation,
    right: Delegation
  )
  {
    DelegationId(left) == DelegationId(right)
  }


  lemma DelegationsWithEqualIdsAreSameEntity(
    left: Delegation,
    right: Delegation
  )
    requires DelegationId(left) == DelegationId(right)
    ensures SameDelegation(left, right)
  {
  }


  lemma DelegationsWithDistinctIdsAreNotTheSameEntity(
    left: Delegation,
    right: Delegation
  )
    requires DelegationId(left) != DelegationId(right)
    ensures !SameDelegation(left, right)
  {
  }


  lemma EqualDelegationsHaveEqualIds(
    left: Delegation,
    right: Delegation
  )
    requires left == right
    ensures DelegationId(left) == DelegationId(right)
  {
  }


  lemma EqualDelegationsHaveEqualSourceIdentityIds(
    left: Delegation,
    right: Delegation
  )
    requires left == right
    ensures DelegationSourceIdentityId(left)
         == DelegationSourceIdentityId(right)
  {
  }


  lemma EqualDelegationsHaveEqualDelegatees(
    left: Delegation,
    right: Delegation
  )
    requires left == right
    ensures DelegationDelegatee(left)
         == DelegationDelegatee(right)
  {
  }


  lemma EqualDelegationsHaveEqualCapabilities(
    left: Delegation,
    right: Delegation
  )
    requires left == right
    ensures DelegationCapabilities(left)
         == DelegationCapabilities(right)
  {
  }


  // ----------------------------------------------------------
  // VALIDITY LAWS
  // ----------------------------------------------------------

  lemma ValidDelegationHasValidId(
    delegation: Delegation
  )
    requires ValidDelegation(delegation)
    ensures ValidId(DelegationId(delegation))
  {
  }


  lemma ValidDelegationHasValidSourceIdentityId(
    delegation: Delegation
  )
    requires ValidDelegation(delegation)
    ensures ValidId(
              DelegationSourceIdentityId(delegation)
            )
  {
  }


  lemma ValidDelegationHasValidDelegatee(
    delegation: Delegation
  )
    requires ValidDelegation(delegation)
    ensures ValidSubject(
              DelegationDelegatee(delegation)
            )
  {
  }


  lemma ValidDelegationHasValidCapabilities(
    delegation: Delegation,
    capability: Capability
  )
    requires ValidDelegation(delegation)
    requires capability in DelegationCapabilities(delegation)
    ensures ValidCapability(capability)
  {
  }


  lemma ValidDelegationHasValidRestrictions(
    delegation: Delegation,
    restriction: Restriction
  )
    requires ValidDelegation(delegation)
    requires restriction in DelegationRestrictions(delegation)
    ensures ValidRestriction(restriction)
  {
  }


  // ----------------------------------------------------------
  // DELEGATION AUTHORITY BOUNDARY
  // ----------------------------------------------------------

  // D1.19:
  //
  //     DelegatableAuthority
  //         ⊆
  //     EffectiveAuthority
  //
  // The predicate only represents the authority boundary.
  // It does not calculate either authority value.
  predicate DelegatableAuthorityWithinEffectiveAuthority(
    delegatableAuthority: set<Capability>,
    effectiveAuthority: set<Capability>
  )
  {
    delegatableAuthority <= effectiveAuthority
  }


  lemma DelegatableAuthorityCannotExceedEffectiveAuthority(
    delegatableAuthority: set<Capability>,
    effectiveAuthority: set<Capability>
  )
    requires DelegatableAuthorityWithinEffectiveAuthority(
               delegatableAuthority,
               effectiveAuthority
             )
    ensures delegatableAuthority <= effectiveAuthority
  {
  }


  // ----------------------------------------------------------
  // DELEGATE CAPABILITY
  // ----------------------------------------------------------

  // D1.17 / D1.18:
  //
  //     Delegate is itself a Capability.
  //
  // The source may perform the delegation act only when the
  // semantic Delegate Capability is available in the source's
  // Effective Authority.
  //
  // IMPORTANT:
  //
  // Delegate is NOT required to belong to DelegatableAuthority.
  // It enables delegation; it does not automatically make itself
  // delegatable.
  predicate SourceHasDelegationCapability(
    effectiveAuthority: set<Capability>,
    delegateCapability: Capability
  )
  {
    IsDelegateCapability(delegateCapability)
    &&
    delegateCapability in effectiveAuthority
  }


  lemma DelegationRequiresDelegateCapability(
    effectiveAuthority: set<Capability>,
    delegateCapability: Capability
  )
    requires SourceHasDelegationCapability(
               effectiveAuthority,
               delegateCapability
             )
    ensures IsDelegateCapability(delegateCapability)
    ensures delegateCapability in effectiveAuthority
  {
  }


  // ----------------------------------------------------------
  // DELEGATED AUTHORITY
  // ----------------------------------------------------------

  // D1.21:
  //
  //     DelegatedAuthority
  //         ⊆
  //     DelegatableAuthority(Source)
  //
  predicate DelegationAuthorityWithinDelegatableAuthority(
    delegation: Delegation,
    delegatableAuthority: set<Capability>
  )
  {
    DelegationCapabilities(delegation)
    <= delegatableAuthority
  }


  lemma DelegationCannotAddDelegatableAuthority(
    delegation: Delegation,
    delegatableAuthority: set<Capability>,
    capability: Capability
  )
    requires DelegationAuthorityWithinDelegatableAuthority(
               delegation,
               delegatableAuthority
             )
    requires capability in DelegationCapabilities(delegation)
    ensures capability in delegatableAuthority
  {
  }


  // A Delegation may be equal to the complete DelegatableAuthority
  // or may be a strict subset of it. Therefore "may restrict" is
  // represented by ordinary subset containment.
  predicate DelegationMayRestrictAuthority(
    delegation: Delegation,
    delegatableAuthority: set<Capability>
  )
  {
    DelegationAuthorityWithinDelegatableAuthority(
      delegation,
      delegatableAuthority
    )
  }


  // ----------------------------------------------------------
  // COMBINED DELEGATION AUTHORITY BOUNDARY
  // ----------------------------------------------------------

  // D1.17 + D1.19 + D1.21:
  //
  //     Delegate ∈ EffectiveAuthority(source)
  //
  // and:
  //
  //     DelegatedAuthority
  //         ⊆
  //     DelegatableAuthority
  //
  //     DelegatableAuthority
  //         ⊆
  //     EffectiveAuthority
  //
  // Notice that Delegate Capability is a separate requirement from
  // the authority being delegated.
  predicate DelegationAuthorityIsBounded(
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    effectiveAuthority: set<Capability>
  )
  {
    SourceHasDelegationCapability(
      effectiveAuthority,
      delegateCapability
    )
    &&
    DelegationAuthorityWithinDelegatableAuthority(
      delegation,
      delegatableAuthority
    )
    &&
    DelegatableAuthorityWithinEffectiveAuthority(
      delegatableAuthority,
      effectiveAuthority
    )
  }


  lemma BoundedDelegationCannotExceedEffectiveAuthority(
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    effectiveAuthority: set<Capability>,
    capability: Capability
  )
    requires DelegationAuthorityIsBounded(
               delegation,
               delegateCapability,
               delegatableAuthority,
               effectiveAuthority
             )
    requires capability in DelegationCapabilities(delegation)
    ensures capability in effectiveAuthority
  {
  }


  // ----------------------------------------------------------
  // DELEGATION REDUCTION
  // ----------------------------------------------------------

  lemma ReducedDelegationCannotAddCapability(
    original: Delegation,
    reduced: Delegation,
    capability: Capability
  )
    requires DelegationCapabilities(reduced)
          <= DelegationCapabilities(original)
    requires capability in DelegationCapabilities(reduced)
    ensures capability in DelegationCapabilities(original)
  {
  }


  // ----------------------------------------------------------
  // DELEGATION CHAIN BOUNDARY
  // ----------------------------------------------------------

  // D1.25:
  //
  // If child authority is derived exclusively from a parent
  // delegation, it cannot exceed the authority received through
  // that parent.
  predicate TransitiveDelegationAuthorityIsBounded(
    childAuthority: set<Capability>,
    parentDelegatedAuthority: set<Capability>
  )
  {
    childAuthority <= parentDelegatedAuthority
  }


  lemma TransitiveDelegationCannotExceedParentAuthority(
    childAuthority: set<Capability>,
    parentDelegatedAuthority: set<Capability>,
    capability: Capability
  )
    requires TransitiveDelegationAuthorityIsBounded(
               childAuthority,
               parentDelegatedAuthority
             )
    requires capability in childAuthority
    ensures capability in parentDelegatedAuthority
  {
  }


  // ----------------------------------------------------------
  // LIFECYCLE LAWS
  // ----------------------------------------------------------

  lemma RevokedDelegationIsNotActive(
    delegation: Delegation
  )
    requires DelegationIsRevoked(delegation)
    ensures !DelegationIsActive(delegation)
  {
  }


  lemma ExpiredDelegationIsOutsideValidityInterval(
    delegation: Delegation,
    now: Timestamp
  )
    requires DelegationIsExpiredAt(delegation, now)
    ensures !DelegationIsWithinValidityIntervalAt(
              delegation,
              now
            )
  {
  }


  lemma RevokedDelegationCannotCurrentlyExerciseAuthority(
    delegation: Delegation,
    now: Timestamp
  )
    requires DelegationIsRevoked(delegation)
    ensures !DelegationCanCurrentlyExerciseAuthorityAt(
              delegation,
              now
            )
  {
  }


  lemma ExpiredDelegationCannotCurrentlyExerciseAuthority(
    delegation: Delegation,
    now: Timestamp
  )
    requires DelegationIsExpiredAt(delegation, now)
    ensures !DelegationCanCurrentlyExerciseAuthorityAt(
              delegation,
              now
            )
  {
  }


  // ----------------------------------------------------------
  // TEMPORAL LAWS
  // ----------------------------------------------------------

  lemma ValidDelegationHasValidInterval(
    delegation: Delegation
  )
    requires ValidDelegation(delegation)
    ensures DelegationValidFrom(delegation)
         <= DelegationValidUntil(delegation)
  {
  }
}

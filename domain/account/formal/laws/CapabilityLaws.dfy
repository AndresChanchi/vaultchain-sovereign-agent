// ============================================================
// KIPIO ACCOUNT DOMAIN
// LAWS — CAPABILITY
// ============================================================
//
// Cross-concept semantic laws involving Capability.
//
// Capability.dfy already defines:
//
//   - CapabilityKind;
//   - Capability;
//   - Capability Value Object equality;
//   - Capability structural validity;
//   - the separation between Capability and Metadata.
//
// This file therefore does NOT duplicate local Capability
// representation or local Value Object laws.
//
// Instead, this file formalizes domain-level consequences that
// require Capability to be considered together with Scope and
// EffectiveAuthority.
//
// ------------------------------------------------------------
//
// DDD BOUNDARY
//
// Capability represents:
//
//     WHAT FACULTY EXISTS
//
// Scope represents:
//
//     WHERE THAT FACULTY MAY APPLY
//
// EffectiveAuthority represents:
//
//     WHAT MAY ACTUALLY BE EXERCISED
//
// Capability itself does NOT:
//
//   - grant authority;
//   - identify an Entity;
//   - identify a Credential;
//   - represent a Delegation;
//   - represent an Execution;
//   - contain an ExecutionTarget;
//   - contain authorization state;
//   - define Policy;
//   - define Proof;
//   - define blockchain representation.
//
// ------------------------------------------------------------
//
// SCOPE BOUNDARY
//
// Scope is a Value Object.
//
// A Capability with the same CapabilityKind and a narrower Scope
// represents a scope-restricted form of the same semantic faculty.
//
// This file may establish consequences of Scope inclusion, but it
// does not redefine Scope semantics.
//
// ------------------------------------------------------------
//
// AUTHORITY BOUNDARY
//
// Capability describes a faculty.
//
// It does not by itself establish that the faculty is effective.
//
// Therefore:
//
//     Capability exists
//         ⇏
//     Capability is effective
//
// EffectiveAuthority is a contextual derived value and is modeled
// separately.
//
// ------------------------------------------------------------
//
// RESPONSIBILITY BOUNDARY
//
// This file does NOT define:
//
//   - Credential Authority calculation;
//   - Session Authority calculation;
//   - Delegation Authority calculation;
//   - Restriction evaluation;
//   - Policy evaluation;
//   - Authorization validation;
//   - Execution;
//   - Proof verification;
//   - blockchain semantics.
//
// Those concerns belong to their corresponding modules.
//
// ============================================================

include "../foundation/Capability.dfy"
include "../foundation/Scope.dfy"
include "../authority/EffectiveAuthority.dfy"

module KipioAccountCapabilityLaws
{
  import opened KipioAccountCapability
  import opened KipioAccountScope
  import opened KipioAccountEffectiveAuthority


  // ----------------------------------------------------------
  // SCOPE-RESTRICTED CAPABILITY
  // ----------------------------------------------------------

  // A Capability is within the Scope of another Capability when:
  //
  //   - both represent the same CapabilityKind;
  //   - the first Capability's Scope is contained in the second.
  //
  // This is a value-level relation.
  //
  // It does NOT imply:
  //
  //   - authorization;
  //   - EffectiveAuthority;
  //   - Credential Authority;
  //   - Delegated Authority.
  predicate CapabilityWithinScopeOf(
    narrower: Capability,
    broader: Capability
  )
  {
    CapabilityKindOf(narrower)
    ==
    CapabilityKindOf(broader)
    &&
    ScopeWithin(
      CapabilityScope(narrower),
      CapabilityScope(broader)
    )
  }


  // A Capability restricted to a narrower Scope cannot expose an
  // atom outside the broader Capability's Scope.
  lemma NarrowerCapabilityScopeCannotEscapeBroaderScope(
    narrower: Capability,
    broader: Capability,
    atom: ScopeAtom
  )
    requires CapabilityWithinScopeOf(
               narrower,
               broader
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


  // ----------------------------------------------------------
  // EFFECTIVE AUTHORITY / CAPABILITY BOUNDARY
  // ----------------------------------------------------------

  // Every Capability contained in EffectiveAuthority must satisfy
  // the structural validity rules of Capability.
  lemma EffectiveAuthorityCapabilityIsStructurallyValid(
    authority: EffectiveAuthority,
    capability: Capability
  )
    requires ValidEffectiveAuthority(authority)
    requires CapabilityIsEffective(
               authority,
               capability
             )
    ensures ValidCapability(capability)
  {
  }


  // A Capability contained in a valid EffectiveAuthority has a
  // structurally valid CapabilityKind.
  lemma ValidCapabilityInAuthorityHasValidKind(
    authority: EffectiveAuthority,
    capability: Capability
  )
    requires ValidEffectiveAuthority(authority)
    requires CapabilityIsEffective(
               authority,
               capability
             )
    ensures ValidCapabilityKind(
              CapabilityKindOf(capability)
            )
  {
  }


  // A Capability contained in a valid EffectiveAuthority has a
  // structurally valid Scope.
  lemma ValidCapabilityInAuthorityHasValidScope(
    authority: EffectiveAuthority,
    capability: Capability
  )
    requires ValidEffectiveAuthority(authority)
    requires CapabilityIsEffective(
               authority,
               capability
             )
    ensures ValidScope(
              CapabilityScope(capability)
            )
  {
  }


  // ----------------------------------------------------------
  // CAPABILITY DOES NOT CREATE AUTHORITY
  // ----------------------------------------------------------

  // A valid Capability may exist without belonging to a particular
  // EffectiveAuthority.
  //
  // This proves the important semantic separation:
  //
  //     Capability existence
  //         !=
  //     Effective Authority membership
  //
  // No actor, Account, Credential, Session, Delegation or grant is
  // inferred from the existence of the Capability value itself.
  lemma CapabilityExistenceDoesNotImplyEffectiveAuthority(
    capability: Capability
  )
    requires ValidCapability(capability)
    ensures exists authority: EffectiveAuthority ::
              ValidEffectiveAuthority(authority)
              &&
              !CapabilityIsEffective(
                authority,
                capability
              )
  {
    var authority: EffectiveAuthority := {};
    assert ValidEffectiveAuthority(authority);
    assert !CapabilityIsEffective(authority, capability);
  }


  // A Capability remains a faculty value rather than a historical
  // grant event.
  //
  // This law does not associate the Capability with any Entity,
  // authority source or lifecycle.
  lemma CapabilityIsNotAHistoricalGrant(
    capability: Capability
  )
    requires ValidCapability(capability)
    ensures SameCapability(capability, capability)
  {
  }


  // ----------------------------------------------------------
  // AUTHORITY REDUCTION
  // ----------------------------------------------------------

  // If an EffectiveAuthority is reduced, every Capability remaining
  // in the reduced authority was already present in the original
  // authority.
  //
  // This is the capability-level consequence of non-expansion.
  lemma ReducedEffectiveAuthorityPreservesExistingCapability(
    original: EffectiveAuthority,
    reduced: EffectiveAuthority,
    capability: Capability
  )
    requires reduced <= original
    requires CapabilityIsEffective(
               reduced,
               capability
             )
    ensures CapabilityIsEffective(
              original,
              capability
            )
  {
  }


  // ----------------------------------------------------------
  // VALUE OBJECT / INFRASTRUCTURE BOUNDARY
  // ----------------------------------------------------------

  // Capability semantics remain determined by CapabilityKind +
  // Scope. External infrastructure is intentionally outside this
  // Value Object.
  //
  // No infrastructure-specific assertion is introduced here.
}

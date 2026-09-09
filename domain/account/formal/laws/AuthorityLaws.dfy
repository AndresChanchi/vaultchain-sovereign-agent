// ============================================================
// KIPIO ACCOUNT DOMAIN
// LAWS — AUTHORITY
// ============================================================
//
// Cross-concept semantic laws concerning Authority.
//
// This file composes the authority boundaries defined by:
//
//   - CredentialAuthority;
//   - Session;
//   - Delegation;
//   - EffectiveAuthority.
//
// Local constructor, value, lifecycle and structural laws remain
// in their corresponding modules.
//
// AuthorityLaws exists to prove consequences that arise when
// multiple authority concepts are composed.
//
// ------------------------------------------------------------
//
// DDD BOUNDARY
//
// AuthorityLaws formalizes:
//
//   - Session Authority ⊆ Credential Authority;
//   - Effective Authority derived through Session
//       ⊆ Credential Authority;
//   - Delegatable Authority ⊆ Effective Authority;
//   - Delegated Authority ⊆ Delegatable Authority;
//   - Delegated Authority ⊆ Effective Authority;
//   - transitive delegation non-expansion;
//   - authority validity propagation;
//   - preservation of independently bounded source relations.
//
// It intentionally does NOT formalize:
//
//   - Account sovereignty;
//   - AuthorizationState recognition;
//   - Credential lifecycle;
//   - Session lifecycle;
//   - Delegation lifecycle;
//   - Authorization validation;
//   - Proof verification;
//   - Policy consumption;
//   - Execution;
//   - a global single-source model of Effective Authority;
//   - concrete provenance storage or derivation;
//   - local Entity / Value Object laws already defined by the
//     underlying authority modules.
//
// ------------------------------------------------------------
//
// CENTRAL AUTHORITY PRINCIPLE
//
// Authority derivation is monotonic:
//
//     DerivedAuthority
//         ⊆
//     SourceAuthority
//
// This principle applies only when the source relationship has
// explicitly been established.
//
// It does NOT imply:
//
//     TotalEffectiveAuthority
//         ⊆
//     SourceAuthority
//
// for one arbitrary source.
//
// ------------------------------------------------------------
//
// MULTIPLE INDEPENDENT SOURCES
//
// Multiple independent authority sources may contribute to one
// resulting authority value.
//
// Therefore AuthorityLaws preserves source-specific boundaries
// without collapsing unrelated authority into one source.
//
// Provenance of each derived portion remains a concern of the
// surrounding AuthorizationState / authority-derivation model.
//
// ============================================================

include "../foundation/Capability.dfy"
include "../authority/CredentialAuthority.dfy"
include "../authority/Session.dfy"
include "../authority/Delegation.dfy"
include "../authority/EffectiveAuthority.dfy"

module KipioAccountAuthorityLaws
{
  import opened KipioAccountCapability
  import opened KipioAccountCredentialAuthority
  import opened KipioAccountSession
  import opened KipioAccountDelegation
  import opened KipioAccountEffectiveAuthority


  // ----------------------------------------------------------
  // SESSION → CREDENTIAL AUTHORITY
  // ----------------------------------------------------------

  // If Session Authority is bounded by Credential Authority and an
  // Effective Authority is further bounded by that Session, then
  // the Effective Authority is also bounded by the Credential
  // Authority.
  //
  // Composition:
  //
  //     EffectiveAuthority
  //         ⊆
  //     SessionAuthority
  //         ⊆
  //     CredentialAuthority
  lemma EffectiveAuthorityDerivedThroughSessionCannotExceedCredentialAuthority(
    effectiveAuthority: EffectiveAuthority,
    session: Session,
    credentialAuthority: CredentialAuthority
  )
    requires effectiveAuthority <= SessionCapabilities(session)
    requires SessionAuthorityWithinCredentialAuthority(
               session,
               credentialAuthority
             )
    ensures effectiveAuthority <= credentialAuthority
  {
  }


  // ----------------------------------------------------------
  // DELEGATABLE AUTHORITY → EFFECTIVE AUTHORITY
  // ----------------------------------------------------------

  // D1.19 + D1.21:
  //
  //     DelegatedAuthority
  //         ⊆
  //     DelegatableAuthority
  //
  //     DelegatableAuthority
  //         ⊆
  //     EffectiveAuthority
  //
  // Therefore the authority represented by a Delegation is bounded
  // by the source Effective Authority.
  //
  // The individual boundaries are defined in Delegation.dfy;
  // this theorem exists because the consequence requires their
  // composition.
  lemma DelegatedAuthorityIsWithinEffectiveAuthority(
    delegation: Delegation,
    delegatableAuthority: set<Capability>,
    effectiveAuthority: EffectiveAuthority
  )
    requires DelegationAuthorityWithinDelegatableAuthority(
               delegation,
               delegatableAuthority
             )
    requires DelegatableAuthorityWithinEffectiveAuthority(
               delegatableAuthority,
               effectiveAuthority
             )
    ensures DelegationCapabilities(delegation)
         <= effectiveAuthority
  {
  }


  // ----------------------------------------------------------
  // TRANSITIVE DELEGATION
  // ----------------------------------------------------------

  // If a child authority is bounded by a parent delegation and the
  // parent is bounded by a source Effective Authority, the child
  // cannot escape that source boundary.
  //
  // This is a source-specific transitive theorem.
  //
  // It does not constrain authority received independently from
  // unrelated sources.
  lemma TransitiveDelegationCannotEscapeSourceAuthority(
    childAuthority: set<Capability>,
    parentDelegatedAuthority: set<Capability>,
    sourceEffectiveAuthority: EffectiveAuthority
  )
    requires childAuthority <= parentDelegatedAuthority
    requires parentDelegatedAuthority <= sourceEffectiveAuthority
    ensures childAuthority <= sourceEffectiveAuthority
  {
  }


  // Capability-level form of the same transitive source boundary.
  lemma TransitiveDelegationPreservesSourceBoundary(
    childAuthority: set<Capability>,
    parentDelegatedAuthority: set<Capability>,
    sourceEffectiveAuthority: EffectiveAuthority,
    capability: Capability
  )
    requires TransitiveDelegationAuthorityIsBounded(
               childAuthority,
               parentDelegatedAuthority
             )
    requires parentDelegatedAuthority
          <= sourceEffectiveAuthority
    requires capability in childAuthority
    ensures capability in sourceEffectiveAuthority
  {
  }


  // ----------------------------------------------------------
  // MULTIPLE AUTHORITY BOUNDARIES
  // ----------------------------------------------------------

  // If one Effective Authority is explicitly bounded by two
  // independent source authorities, every Capability in that
  // Effective Authority belongs to both source authorities.
  //
  // This is an intersection-like consequence only.
  //
  // It does not imply that either source alone explains the full
  // provenance of the Effective Authority.
  lemma EffectiveAuthorityWithinBothSourceAuthorities(
    effectiveAuthority: EffectiveAuthority,
    firstSourceAuthority: set<Capability>,
    secondSourceAuthority: set<Capability>,
    capability: Capability
  )
    requires effectiveAuthority <= firstSourceAuthority
    requires effectiveAuthority <= secondSourceAuthority
    requires capability in effectiveAuthority
    ensures capability in firstSourceAuthority
    ensures capability in secondSourceAuthority
  {
  }


  // ----------------------------------------------------------
  // VALIDITY PROPAGATION
  // ----------------------------------------------------------

  // A valid EffectiveAuthority contains only valid Capabilities.
  //
  // This law exposes that local invariant at the composed
  // Authority boundary.
  lemma AuthorityCapabilitySelectedFromValidEffectiveAuthorityIsValid(
    effectiveAuthority: EffectiveAuthority,
    capability: Capability
  )
    requires ValidEffectiveAuthority(effectiveAuthority)
    requires capability in effectiveAuthority
    ensures ValidCapability(capability)
  {
  }


  // A valid Credential Authority contains only valid Capabilities.
  //
  // Credential Authority validity is defined locally by
  // CredentialAuthority.dfy; this law exposes the consequence when
  // composing authority concepts.
  lemma CredentialAuthorityCapabilityIsValid(
    authority: CredentialAuthority,
    capability: Capability
  )
    requires ValidCredentialAuthority(authority)
    requires capability in authority
    ensures ValidCapability(capability)
  {
  }


  // A valid Session cannot introduce an invalid Capability through
  // its explicitly represented authority.
  lemma SessionAuthorityPreservesCapabilityValidity(
    session: Session,
    capability: Capability
  )
    requires ValidSession(session)
    requires capability in SessionCapabilities(session)
    ensures ValidCapability(capability)
  {
  }


  // A valid Delegation cannot introduce an invalid Capability
  // through its explicitly delegated authority.
  lemma DelegationAuthorityPreservesCapabilityValidity(
    delegation: Delegation,
    capability: Capability
  )
    requires ValidDelegation(delegation)
    requires capability in DelegationCapabilities(delegation)
    ensures ValidCapability(capability)
  {
  }


  // ----------------------------------------------------------
  // AUTHORITY REDUCTION
  // ----------------------------------------------------------

  // Applying a further subset restriction cannot introduce a
  // Capability absent from the preceding authority.
  //
  // This law is intentionally generic: the same monotonic subset
  // principle applies across the different authority boundaries.
  lemma FurtherAuthorityReductionCannotExpand(
    previousAuthority: set<Capability>,
    furtherReducedAuthority: set<Capability>,
    capability: Capability
  )
    requires furtherReducedAuthority <= previousAuthority
    requires capability in furtherReducedAuthority
    ensures capability in previousAuthority
  {
  }


  // ----------------------------------------------------------
  // PROVENANCE BOUNDARY
  // ----------------------------------------------------------

  // A source-specific authority boundary does not establish the
  // provenance of every Capability in a larger authority value.
  //
  // This file therefore preserves the distinction between:
  //
  //     source-bounded authority
  //
  // and:
  //
  //     total Effective Authority provenance.
  //
  // No concrete provenance data structure is introduced here.
}

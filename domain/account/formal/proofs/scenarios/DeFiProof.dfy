// ============================================================
// KIPIO ACCOUNT DOMAIN
// SCENARIO — DEFI
// ============================================================
//
// DeFi validates EffectiveAuthority boundaries, provenance and
// concrete source-attribution behavior during Authorization
// acceptance.
//
// The scenario verifies:
//
//     1. Requested authority must be contained by
//        EffectiveAuthority.
//
//     2. Accepted EffectiveAuthority must be structurally valid.
//
//     3. Accepted EffectiveAuthority must be derivable from explicit
//        provenance contributions.
//
//     4. Every provenance source used for acceptance must belong to
//        the Account-relative currently usable authority-source
//        universe.
//
//     5. No requested Capability can be accepted unless it is
//        supported by at least one currently usable authority source.
//
//     6. Multi-source EffectiveAuthority composition preserves
//        independent source boundaries without imposing an invalid
//        single-source restriction.
//
//     7. Structural validity alone cannot establish recognized
//        provenance or acceptance.
//
//     8. Two distinct concrete authority sources may expose the
//        same authority value.
//
//     9. Value-only provenance remains extensional over authority
//        values, but this does not erase concrete source identity
//        from the repaired attributed provenance boundary.
//
//    10. The repaired Authorization acceptance contract carries
//        concrete AuthoritySourceReference values and resolves each
//        declared source to its exact Account-relative authority.
//
// The resulting authority chain is:
//
//     Account Authorization State
//              |
//              v
//     CurrentlyUsableAuthoritySourcesForAcceptance
//              |
//              v
//     attributed source references
//              |
//              v
//     provenance contributions
//              |
//              v
//     EffectiveAuthority
//              |
//              v
//     RequestedAuthority
//              |
//              v
//     Authorization acceptance
//
// ------------------------------------------------------------
//
// EFFECTIVE AUTHORITY
//
// EffectiveAuthority is a Value Object.
//
// It may combine authority from multiple independent sources.
//
// Therefore DeFi does NOT impose:
//
//     EffectiveAuthority ⊆ one single source
//
// Instead:
//
//     contribution(i) ⊆ sourceAuthority(i)
//
// and:
//
//     EffectiveAuthority
//         =
//     union of all contributions
//
// This preserves legitimate composition:
//
//     Source A -> { Capability X }
//     Source B -> { Capability Y }
//
//     EffectiveAuthority = { Capability X, Capability Y }
//
// ------------------------------------------------------------
//
// PROVENANCE
//
// EffectiveAuthority provenance is a ghost relational contract.
//
// Authorization acceptance requires:
//
//     - concrete sourceReferences;
//     - sourceAuthorities;
//     - contributions;
//
// with aligned indices:
//
//     sourceReferences[i]
//            |
//            v
//     sourceAuthorities[i]
//            |
//            v
//     contributions[i]
//
// The accepted provenance is constrained by:
//
//     - Account state;
//     - Credential lifecycle;
//     - Session usability;
//     - Delegation usability;
//     - Delegation source-identity provenance;
//     - exact resolution of every concrete source reference.
//
// ------------------------------------------------------------
//
// PRIMARY ATTACK
//
//     Authorization requests Capability C
//
//     C ∉ EffectiveAuthority
//
// Expected:
//
//     rejection
//
// ------------------------------------------------------------
//
// SECONDARY ATTACK
//
//     Authorization requests Capability C
//
//     C ∈ EffectiveAuthority
//
// but:
//
//     C ∉ every currently usable authority source
//
// Expected:
//
//     rejection
//
// This is the stronger authority-source attack.
//
// It verifies that an accepted EffectiveAuthority cannot introduce
// authority that is absent from all authority sources currently
// usable by the Account.
//
// ------------------------------------------------------------
//
// SOURCE-INDEX ATTACK
//
// Acceptance requires every provenance source:
//
//     sourceAuthorities[i]
//
// to belong to:
//
//     CurrentlyUsableAuthoritySourcesForAcceptance(...)
//
// Therefore an explicitly declared source outside that source
// universe cannot participate in an accepted provenance witness.
//
// The repaired contract strengthens this boundary further:
//
//     sourceReferences[i]
//
// must resolve to:
//
//     sourceAuthorities[i]
//
// within the Account-relative acceptance context.
//
// ------------------------------------------------------------
//
// STRUCTURAL VALIDITY
//
// ValidEffectiveAuthority proves structural validity of the
// Capability values contained in the EffectiveAuthority.
//
// It does not independently determine authority ownership.
//
// Authority ownership is constrained by provenance and the
// Account-relative currently usable source universe.
//
// ------------------------------------------------------------
//
// MULTI-SOURCE COMPOSITION
//
// EffectiveAuthority may combine multiple independent sources.
//
// The provenance relation remains indexed:
//
//     contribution(0) ⊆ source(0)
//     contribution(1) ⊆ source(1)
//     ...
//
// A valid multi-source composition therefore preserves each source
// boundary while permitting the resulting EffectiveAuthority to
// contain the union of independently authorized contributions.
//
// No single-source restriction is introduced.
//
// ------------------------------------------------------------
//
// REACHABLE ACCOUNT STATE
//
// AccountTransitions provides authoritative reachable-state
// transitions such as:
//
//     RegisterCredential
//     SetCredentialAuthority
//     RegisterSession
//     RegisterDelegation
//
// Those transitions preserve AuthorizationState validity.
//
// DeFi therefore reasons over the state predicates exposed by the
// domain rather than introducing an independent state model.
//
// ------------------------------------------------------------
//
// CONCRETE SOURCE ATTRIBUTION
//
// AuthorizationState retains concrete Entity identity:
//
//     Credential
//         |
//         +-- CredentialId
//         |
//         +-- Account-relative CredentialAuthority
//
// Therefore two Credentials may be semantically distinct Entities
// while carrying equal CredentialAuthority values.
//
// Example:
//
//     Credential A
//         CredentialId = A
//         Authority   = { Upload }
//
//     Credential B
//         CredentialId = B
//         Authority   = { Upload }
//
//     A != B
//     Authority(A) == Authority(B)
//
// This equality is legitimate.
//
// EffectiveAuthority remains a Value Object and therefore contains
// only the resulting Capability set.
//
// Concrete source identity is carried by the surrounding provenance
// witness through:
//
//     AuthoritySourceReference
//
// For Credentials:
//
//     AuthoritySourceReference(
//         CredentialAuthoritySource,
//         CredentialId
//     )
//
// Therefore:
//
//     Reference(A) != Reference(B)
//
// whenever:
//
//     CredentialId(A) != CredentialId(B).
//
// The authority-value projection may still collapse A and B:
//
//     [Authority(A)] == [Authority(B)]
//
// when:
//
//     Authority(A) == Authority(B).
//
// This is a mathematical equality of value-only witnesses.
//
// It is not an attribution collision in the repaired acceptance
// contract.
//
// ------------------------------------------------------------
//
// ACCEPTED ATTRIBUTED PROVENANCE
//
// Authorization acceptance now consumes:
//
//     sourceReferences
//     sourceAuthorities
//     contributions
//
// together.
//
// For each index:
//
//     sourceReferences[i]
//
// identifies the concrete authority source;
//
//     sourceAuthorities[i]
//
// provides that source's authority value;
//
//     contributions[i]
//
// identifies the portion of EffectiveAuthority attributed to that
// source.
//
// Acceptance additionally requires:
//
//     AuthoritySourceReferenceResolvesToAuthority(...)
//
// for the aligned source reference and source authority.
//
// Therefore an accepted source is not merely:
//
//     "some currently usable authority value"
//
// It is:
//
//     "a concrete currently usable authority source reference
//      whose resolved authority equals the supplied source value."
//
// ------------------------------------------------------------
//
// VALUE COLLISION VERSUS ATTRIBUTION COLLISION
//
// Two distinct Credentials may satisfy:
//
//     Credential A != Credential B
//     Authority(A) == Authority(B)
//
// Consequently:
//
//     [Authority(A)] == [Authority(B)]
//
// remains true.
//
// This is a collision only in the value-only projection.
//
// The repaired provenance representation preserves:
//
//     Reference(A) != Reference(B)
//
// even when:
//
//     Authority(A) == Authority(B).
//
// Therefore the repaired acceptance boundary does not confuse:
//
//     source A
//
// with:
//
//     source B
//
// merely because their authority values are equal.
//
// ------------------------------------------------------------
//
// REMEDIATED ACCEPTANCE BOUNDARY
//
// The formal boundary is:
//
//     Authorization
//          |
//          v
//     AuthorizationCanBeAccepted
//          |
//          +--> EffectiveAuthority
//          |
//          +--> sourceReferences
//          +--> sourceAuthorities
//          +--> contributions
//                    |
//                    v
//          concrete source resolution
//
// Concrete source attribution is therefore part of the acceptance
// witness and is checked against the Account-relative state.
//
// ------------------------------------------------------------
//
// IMPORTANT
//
// This scenario does NOT introduce:
//
//   - a new provenance datatype beyond AuthoritySourceReference;
//   - a cryptographic certificate model;
//   - a single-source EffectiveAuthority rule;
//   - runtime provenance storage;
//   - a new Credential authority model;
//   - an Identity registry;
//   - execution-layer authority semantics.
//
// It also does NOT require:
//
//     AuthorizationCredentialId(authorization)
//         ==
//     every provenance source reference
//
// because multiple independent authority sources are legitimate.
//
// The closure requirement is narrower and precise:
//
//     when a provenance contribution is attributed to a source,
//     the accepted witness identifies that source concretely.
//
// ------------------------------------------------------------
//
// FORMAL CLOSURE
//
// The previous formalization debt was:
//
//     concrete source attribution inside accepted
//     EffectiveAuthority provenance was incomplete.
//
// The repaired boundary now requires:
//
//     sourceReferences
//             |
//             v
//     concrete source identity
//             |
//             v
//     exact source-authority resolution
//
// Therefore:
//
//     equal authority values
//
// no longer erase:
//
//     concrete source identity
//
// at the Authorization acceptance boundary.
//
// ============================================================


include "../../foundation/Capability.dfy"
include "../../foundation/Scope.dfy"
include "../../foundation/DomainPrimitives.dfy"
include "../../foundation/Identity.dfy"
include "../../foundation/Chain.dfy"
include "../../foundation/ExecutionTarget.dfy"
include "../../foundation/Restriction.dfy"
include "../../foundation/DomainAction.dfy"

include "../../account/Account.dfy"
include "../../account/AccountTransitions.dfy"

include "../../authority/Credential.dfy"
include "../../authority/CredentialAuthority.dfy"
include "../../authority/AuthorizationState.dfy"
include "../../authority/Session.dfy"
include "../../authority/Delegation.dfy"
include "../../authority/EffectiveAuthority.dfy"

include "../../authorization/Authorization.dfy"
include "../../authorization/AuthorizationValidation.dfy"
include "../../authorization/Replay.dfy"

include "../../execution/ExecutionRequest.dfy"
include "../../execution/ExecutionContext.dfy"
include "../../execution/ExecutionSemantics.dfy"

include "../isolated/AuthorityProofs.dfy"
include "../isolated/AuthorizationProofs.dfy"
include "../isolated/ExecutionProofs.dfy"


module KipioAccountDeFiProof
{
  // ----------------------------------------------------------
  // DOMAIN IMPORTS
  // ----------------------------------------------------------

  import opened KipioAccountDomainPrimitives
  import opened KipioAccountScope
  import opened KipioAccountCapability
  import opened KipioAccountIdentity
  import opened KipioAccountChain
  import opened KipioAccountExecutionTarget
  import opened KipioAccountRestriction
  import opened KipioAccountDomainAction

  import opened KipioAccountAccount
  import opened KipioAccountAccountTransitions

  import opened KipioAccountCredential
  import opened KipioAccountCredentialAuthority
  import opened KipioAccountAuthorizationState
  import opened KipioAccountSession
  import opened KipioAccountDelegation
  import opened KipioAccountEffectiveAuthority

  import opened KipioAccountAuthorization
  import opened KipioAccountAuthorizationValidation
  import opened KipioAccountReplay

  import opened KipioAccountExecutionRequest
  import opened KipioAccountExecutionContext
  import opened KipioAccountExecutionSemantics

  import opened KipioAccountAuthorityProofs
  import opened KipioAccountAuthorizationProofs
  import opened KipioAccountExecutionProofs


  // ==========================================================
  // ATTACK 1 — REQUESTED AUTHORITY MUST BE CONTAINED
  // ==========================================================

  lemma DeFiRequestedCapabilityOutsideEffectiveAuthorityBreaksBoundary(
    authorization: Authorization,
    effectiveAuthority: EffectiveAuthority,
    capability: Capability
  )
    requires AuthorizationRequestsCapability(
               authorization,
               capability
             )
    requires capability !in effectiveAuthority
    ensures !RequestedAuthorityWithinEffectiveAuthority(
              authorization,
              effectiveAuthority
            )
  {
  }


  lemma DeFiAuthorizationOutsideEffectiveAuthorityIsNotEffective(
    authorization: Authorization,
    effectiveAuthority: EffectiveAuthority,
    capability: Capability
  )
    requires AuthorizationRequestsCapability(
               authorization,
               capability
             )
    requires capability !in effectiveAuthority
    ensures !AuthorizationAuthorityIsEffective(
              authorization,
              effectiveAuthority
            )
  {
  }


  // Out-of-authority requests cannot be accepted.

  lemma DeFiAuthorizationOutsideEffectiveAuthorityCannotBeAccepted(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool,
    capability: Capability
  )
    requires AuthorizationRequestsCapability(
               authorization,
               capability
             )
    requires capability !in effectiveAuthority
    ensures !AuthorizationCanBeAccepted(
              authorization,
              account,
              effectiveAuthority,
              identities,
              sourceReferences,
              sourceAuthorities,
              contributions,
              now,
              proofVerified
            )
  {
  }


  // ==========================================================
  // ATTACK 2 — ACCEPTANCE PRESERVES AUTHORITY CONTAINMENT
  // ==========================================================

  lemma DeFiAcceptedRequestedCapabilityMustBeEffective(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool,
    capability: Capability
  )
    requires AuthorizationCanBeAccepted(
               authorization,
               account,
               effectiveAuthority,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               now,
               proofVerified
             )
    requires AuthorizationRequestsCapability(
               authorization,
               capability
             )
    ensures capability in effectiveAuthority
  {
    KipioAccountAuthorizationProofs
      .AcceptedRequestedCapabilityIsEffective(
      authorization,
      account,
      effectiveAuthority,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      now,
      proofVerified,
      capability
    );
  }


  lemma DeFiAcceptedAuthorizationRequestsOnlyEffectiveAuthority(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool
  )
    requires AuthorizationCanBeAccepted(
               authorization,
               account,
               effectiveAuthority,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               now,
               proofVerified
             )
    ensures AuthorizationRequestedAuthority(
              authorization
            )
         <= effectiveAuthority
  {
    KipioAccountAuthorizationProofs
      .AcceptedAuthorizationRequestsSubsetOfEffectiveAuthority(
      authorization,
      account,
      effectiveAuthority,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      now,
      proofVerified
    );
  }


  // ==========================================================
  // ATTACK 3 — EXPLICIT SOURCE BOUNDARIES
  // ==========================================================

  lemma DeFiCredentialBoundedEffectiveAuthorityCannotEscapeSource(
    effectiveAuthority: EffectiveAuthority,
    credentialAuthority: CredentialAuthority,
    capability: Capability
  )
    requires EffectiveAuthorityWithinSourceAuthority(
               effectiveAuthority,
               credentialAuthority
             )
    requires capability in effectiveAuthority
    ensures capability in credentialAuthority
  {
    KipioAccountAuthorityProofs
      .EffectiveAuthorityCannotEscapeSource(
      effectiveAuthority,
      credentialAuthority,
      capability
    );
  }


  lemma DeFiSessionDerivedAuthorityCannotEscapeCredential(
    effectiveAuthority: EffectiveAuthority,
    session: Session,
    credentialAuthority: CredentialAuthority,
    capability: Capability
  )
    requires effectiveAuthority <= SessionCapabilities(session)
    requires SessionAuthorityWithinCredentialAuthority(
               session,
               credentialAuthority
             )
    requires capability in effectiveAuthority
    ensures capability in credentialAuthority
  {
    KipioAccountAuthorityProofs
      .SessionDerivedCapabilityCannotEscapeCredentialAuthority(
      effectiveAuthority,
      session,
      credentialAuthority,
      capability
    );
  }


  lemma DeFiDelegatedAuthorityCannotEscapeEffectiveAuthority(
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    effectiveAuthority: EffectiveAuthority
  )
    requires DelegationAuthorityIsBounded(
               delegation,
               delegateCapability,
               delegatableAuthority,
               effectiveAuthority
             )
    ensures DelegationCapabilities(delegation)
         <= effectiveAuthority
  {
    KipioAccountAuthorityProofs
      .BoundedDelegationCannotEscapeEffectiveAuthority(
      delegation,
      delegateCapability,
      delegatableAuthority,
      effectiveAuthority
    );
  }


  // ==========================================================
  // ATTACK 4 — STRUCTURAL VALIDITY IS NOT AUTHORITY EXPANSION
  // ==========================================================

  lemma DeFiValidEffectiveAuthorityProvidesStructuralValidityOnly(
    effectiveAuthority: EffectiveAuthority,
    capability: Capability
  )
    requires ValidEffectiveAuthority(effectiveAuthority)
    requires capability in effectiveAuthority
    ensures ValidCapability(capability)
  {
    KipioAccountAuthorityProofs
      .ValidEffectiveAuthorityContainsOnlyValidCapabilities(
      effectiveAuthority,
      capability
    );
  }


  // ==========================================================
  // ATTACK 5 — ACCEPTANCE REQUIRES EFFECTIVE AUTHORITY
  //              PROVENANCE
  // ==========================================================

  lemma DeFiAcceptedAuthorizationRequiresEffectiveAuthorityProvenance(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool
  )
    requires AuthorizationCanBeAccepted(
               authorization,
               account,
               effectiveAuthority,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               now,
               proofVerified
             )
    ensures EffectiveAuthorityDerivedFromSources(
              effectiveAuthority,
              sourceAuthorities,
              contributions
            )
  {
    assert EffectiveAuthorityDerivedFromSources(
        effectiveAuthority,
        sourceAuthorities,
        contributions
      );
  }


  lemma DeFiAcceptedAuthorizationUsesCurrentlyUsableSources(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool
  )
    requires AuthorizationCanBeAccepted(
               authorization,
               account,
               effectiveAuthority,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               now,
               proofVerified
             )
    ensures
      EffectiveAuthorityHasRecognizedSourceProvenance(
        effectiveAuthority,
        CurrentlyUsableAuthoritySourcesForAcceptance(
          AccountAuthorizationState(account),
          account,
          identities,
          now
        ),
        sourceAuthorities,
        contributions
      )
  {
    assert
      EffectiveAuthorityHasRecognizedSourceProvenance(
        effectiveAuthority,
        CurrentlyUsableAuthoritySourcesForAcceptance(
          AccountAuthorizationState(account),
          account,
          identities,
          now
        ),
        sourceAuthorities,
        contributions
      );
  }


  // ==========================================================
  // ATTACK 5B — ACCEPTANCE REQUIRES CONCRETE ATTRIBUTED
  //              PROVENANCE
  // ==========================================================

  lemma DeFiAcceptedAuthorizationRequiresConcreteAttributedProvenance(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool
  )
    requires AuthorizationCanBeAccepted(
               authorization,
               account,
               effectiveAuthority,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               now,
               proofVerified
             )
    ensures
      EffectiveAuthorityHasRecognizedAttributedProvenanceForAccountAt(
        effectiveAuthority,
        account,
        identities,
        now,
        sourceReferences,
        sourceAuthorities,
        contributions
      )
  {
    assert
      EffectiveAuthorityHasRecognizedAttributedProvenanceForAccountAt(
        effectiveAuthority,
        account,
        identities,
        now,
        sourceReferences,
        sourceAuthorities,
        contributions
      );
  }


  lemma DeFiAcceptedEffectiveAuthorityCapabilityHasConcreteAttributedSource(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool,
    capability: Capability
  )
    requires AuthorizationCanBeAccepted(
               authorization,
               account,
               effectiveAuthority,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               now,
               proofVerified
             )
    requires capability in effectiveAuthority
    ensures
      exists i ::
        0 <= i < |sourceReferences|
        &&
        0 <= i < |sourceAuthorities|
        &&
        0 <= i < |contributions|
        &&
        capability in contributions[i]
        &&
        AuthoritySourceReferenceResolvesToAuthority(
          AccountAuthorizationState(account),
          account,
          identities,
          now,
          sourceReferences[i],
          sourceAuthorities[i]
        )
  {
    DeFiAcceptedAuthorizationRequiresConcreteAttributedProvenance(
      authorization,
      account,
      effectiveAuthority,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      now,
      proofVerified
    );

    assert
      EffectiveAuthorityDerivedFromAttributedSources(
        effectiveAuthority,
        sourceReferences,
        sourceAuthorities,
        contributions
      );

    assert
      |sourceReferences|
      ==
      |sourceAuthorities|;

    assert
      |sourceAuthorities|
      ==
      |contributions|;

    assert
      forall capability' ::
        capability' in effectiveAuthority
        ==>
          exists i ::
            0 <= i < |contributions|
            &&
            capability' in contributions[i];

    var i :|
      0 <= i < |contributions|
      &&
      capability in contributions[i];

    assert
      i < |sourceReferences|;

    assert
      i < |sourceAuthorities|;

    assert
      AuthoritySourceReferenceResolvesToAuthority(
        AccountAuthorizationState(account),
        account,
        identities,
        now,
        sourceReferences[i],
        sourceAuthorities[i]
      );

    assert
      exists i ::
        0 <= i < |sourceReferences|
        &&
        0 <= i < |sourceAuthorities|
        &&
        0 <= i < |contributions|
        &&
        capability in contributions[i]
        &&
        AuthoritySourceReferenceResolvesToAuthority(
          AccountAuthorizationState(account),
          account,
          identities,
          now,
          sourceReferences[i],
          sourceAuthorities[i]
        );
  }


  // ==========================================================
  // ATTACK 6 — EVERY ACCEPTED CAPABILITY HAS A CURRENTLY
  //              USABLE SOURCE
  // ==========================================================

  lemma DeFiAcceptedEffectiveAuthorityCapabilityHasCurrentlyUsableSource(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool,
    capability: Capability
  )
    requires AuthorizationCanBeAccepted(
               authorization,
               account,
               effectiveAuthority,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               now,
               proofVerified
             )
    requires capability in effectiveAuthority
    ensures
      exists sourceAuthority ::
        sourceAuthority
        in CurrentlyUsableAuthoritySourcesForAcceptance(
             AccountAuthorizationState(account),
             account,
             identities,
             now
           )
        &&
        capability in sourceAuthority
  {
    DeFiAcceptedAuthorizationUsesCurrentlyUsableSources(
      authorization,
      account,
      effectiveAuthority,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      now,
      proofVerified
    );

    assert
      EffectiveAuthorityDerivedFromSources(
        effectiveAuthority,
        sourceAuthorities,
        contributions
      );

    assert
      forall i ::
        0 <= i < |sourceAuthorities|
        ==> sourceAuthorities[i]
            in
              CurrentlyUsableAuthoritySourcesForAcceptance(
                AccountAuthorizationState(account),
                account,
                identities,
                now
              );

    assert
      forall i ::
        0 <= i < |contributions|
        ==> contributions[i] <= sourceAuthorities[i];

    assert
      forall capability' ::
        capability' in effectiveAuthority
        ==>
          exists i ::
            0 <= i < |contributions|
            &&
            capability' in contributions[i];

    var i :|
      0 <= i < |contributions|
      &&
      capability in contributions[i];

    assert capability in sourceAuthorities[i];

    assert
      sourceAuthorities[i]
      in
        CurrentlyUsableAuthoritySourcesForAcceptance(
          AccountAuthorizationState(account),
          account,
          identities,
          now
        );

    assert
      exists sourceAuthority ::
        sourceAuthority
        in
          CurrentlyUsableAuthoritySourcesForAcceptance(
            AccountAuthorizationState(account),
            account,
            identities,
            now
          )
        &&
        capability in sourceAuthority;
  }


  lemma DeFiAcceptedRequestedCapabilityHasCurrentlyUsableSource(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool,
    capability: Capability
  )
    requires AuthorizationCanBeAccepted(
               authorization,
               account,
               effectiveAuthority,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               now,
               proofVerified
             )
    requires AuthorizationRequestsCapability(
               authorization,
               capability
             )
    ensures
      exists sourceAuthority ::
        sourceAuthority
        in CurrentlyUsableAuthoritySourcesForAcceptance(
             AccountAuthorizationState(account),
             account,
             identities,
             now
           )
        &&
        capability in sourceAuthority
  {
    DeFiAcceptedRequestedCapabilityMustBeEffective(
      authorization,
      account,
      effectiveAuthority,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      now,
      proofVerified,
      capability
    );

    DeFiAcceptedEffectiveAuthorityCapabilityHasCurrentlyUsableSource(
      authorization,
      account,
      effectiveAuthority,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      now,
      proofVerified,
      capability
    );
  }


  // ==========================================================
  // ATTACK 7 — CAPABILITY ABSENT FROM CURRENTLY USABLE
  //              SOURCES BLOCKS ACCEPTANCE
  // ==========================================================

  lemma DeFiCapabilityAbsentFromCurrentlyUsableSourcesBlocksAcceptance(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool,
    capability: Capability
  )
    requires AuthorizationRequestsCapability(
               authorization,
               capability
             )
    requires
      forall sourceAuthority ::
        sourceAuthority
        in CurrentlyUsableAuthoritySourcesForAcceptance(
             AccountAuthorizationState(account),
             account,
             identities,
             now
           )
        ==> capability !in sourceAuthority
    ensures !AuthorizationCanBeAccepted(
              authorization,
              account,
              effectiveAuthority,
              identities,
              sourceReferences,
              sourceAuthorities,
              contributions,
              now,
              proofVerified
            )
  {
    if AuthorizationCanBeAccepted(
        authorization,
        account,
        effectiveAuthority,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        now,
        proofVerified
      )
    {
      DeFiAcceptedRequestedCapabilityHasCurrentlyUsableSource(
        authorization,
        account,
        effectiveAuthority,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        now,
        proofVerified,
        capability
      );

      var sourceAuthority :|
        sourceAuthority
        in CurrentlyUsableAuthoritySourcesForAcceptance(
             AccountAuthorizationState(account),
             account,
             identities,
             now
           )
        &&
        capability in sourceAuthority;

      assert capability !in sourceAuthority;
      assert false;
    }
  }


  // ==========================================================
  // ATTACK 8 — AN EXPLICIT PROVENANCE SOURCE OUTSIDE THE
  //              ACCEPTANCE SOURCE UNIVERSE CANNOT BE USED
  // ==========================================================

  lemma DeFiOutOfUniverseProvenanceSourceBlocksAcceptance(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool,
    index: int
  )
    requires 0 <= index < |sourceAuthorities|
    requires
      sourceAuthorities[index]
      !in
      CurrentlyUsableAuthoritySourcesForAcceptance(
        AccountAuthorizationState(account),
        account,
        identities,
        now
      )
    ensures !AuthorizationCanBeAccepted(
              authorization,
              account,
              effectiveAuthority,
              identities,
              sourceReferences,
              sourceAuthorities,
              contributions,
              now,
              proofVerified
            )
  {
    if AuthorizationCanBeAccepted(
        authorization,
        account,
        effectiveAuthority,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        now,
        proofVerified
      )
    {
      assert
        EffectiveAuthorityHasRecognizedSourceProvenance(
          effectiveAuthority,
          CurrentlyUsableAuthoritySourcesForAcceptance(
            AccountAuthorizationState(account),
            account,
            identities,
            now
          ),
          sourceAuthorities,
          contributions
        );

      assert
        sourceAuthorities[index]
        in
          CurrentlyUsableAuthoritySourcesForAcceptance(
            AccountAuthorizationState(account),
            account,
            identities,
            now
          );

      assert false;
    }
  }


  // ==========================================================
  // ATTACK 9 — MULTI-SOURCE EFFECTIVE AUTHORITY
  // ==========================================================

  lemma DeFiMultipleSourcesHaveRecognizedIndexedProvenance(
    account: Account,
    identities: set<Identity>,
    now: Timestamp,
    effectiveAuthority: EffectiveAuthority,
    firstSource: set<Capability>,
    secondSource: set<Capability>,
    firstContribution: set<Capability>,
    secondContribution: set<Capability>
  )
    requires firstSource
             in
               CurrentlyUsableAuthoritySourcesForAcceptance(
                 AccountAuthorizationState(account),
                 account,
                 identities,
                 now
               )
    requires secondSource
             in
               CurrentlyUsableAuthoritySourcesForAcceptance(
                 AccountAuthorizationState(account),
                 account,
                 identities,
                 now
               )
    requires firstContribution <= firstSource
    requires secondContribution <= secondSource
    requires effectiveAuthority
          == firstContribution + secondContribution
    ensures
      EffectiveAuthorityHasRecognizedSourceProvenance(
        effectiveAuthority,
        CurrentlyUsableAuthoritySourcesForAcceptance(
          AccountAuthorizationState(account),
          account,
          identities,
          now
        ),
        [firstSource, secondSource],
        [firstContribution, secondContribution]
      )
  {
    assert |[firstSource, secondSource]| == 2;
    assert |[firstContribution, secondContribution]| == 2;

    assert
      |[firstSource, secondSource]|
      ==
      |[firstContribution, secondContribution]|;

    assert
      forall i ::
        0 <= i < |[firstContribution, secondContribution]|
        ==>
          [firstContribution, secondContribution][i]
          <=
          [firstSource, secondSource][i];

    assert
      forall i ::
        0 <= i < |[firstSource, secondSource]|
        ==>
          [firstSource, secondSource][i]
          in
            CurrentlyUsableAuthoritySourcesForAcceptance(
              AccountAuthorizationState(account),
              account,
              identities,
              now
            );

    assert
      forall capability' ::
        capability' in effectiveAuthority
        ==>
          capability' in firstContribution
          ||
          capability' in secondContribution;

    assert
      forall capability' ::
        capability' in firstContribution
        ==>
          capability' in effectiveAuthority;

    assert
      forall capability' ::
        capability' in secondContribution
        ==>
          capability' in effectiveAuthority;

    forall capability | capability in firstContribution
      ensures exists i ::
                0 <= i < |[firstContribution, secondContribution]|
                &&
                capability in [firstContribution, secondContribution][i]
    {
      assert capability
             in
               [firstContribution, secondContribution][0];

      assert 0 <= 0 < |[firstContribution, secondContribution]|;
    }

    forall capability | capability in secondContribution
      ensures exists i ::
                0 <= i < |[firstContribution, secondContribution]|
                &&
                capability in [firstContribution, secondContribution][i]
    {
      assert capability
             in
               [firstContribution, secondContribution][1];

      assert 0 <= 1 < |[firstContribution, secondContribution]|;
    }

    assert
      EffectiveAuthorityDerivedFromSources(
        effectiveAuthority,
        [firstSource, secondSource],
        [firstContribution, secondContribution]
      );

    assert
      EffectiveAuthorityHasRecognizedSourceProvenance(
        effectiveAuthority,
        CurrentlyUsableAuthoritySourcesForAcceptance(
          AccountAuthorizationState(account),
          account,
          identities,
          now
        ),
        [firstSource, secondSource],
        [firstContribution, secondContribution]
      );
  }


  // ==========================================================
  // ATTACK 10 — REMEDIATED CONCRETE SOURCE ATTRIBUTION
  // ==========================================================
  //
  // The original value-level collision remains mathematically valid:
  //
  //     Credential A != Credential B
  //
  //     Authority(A) == Authority(B)
  //
  // therefore:
  //
  //     [Authority(A)] == [Authority(B)]
  //
  // This is a property of projecting concrete sources to authority
  // values. It is not itself a domain defect.
  //
  // The repaired acceptance representation preserves the concrete
  // source through AuthoritySourceReference.
  //
  // ----------------------------------------------------------

  // ----------------------------------------------------------
  // ATTACK 10.1 — DISTINCT CREDENTIAL ENTITIES MAY STILL SHARE
  //               THE SAME AUTHORITY VALUE
  // ----------------------------------------------------------

  lemma DeFiDistinctCredentialsCanShareSameAuthorityValue(
    state: AuthorizationState,
    credentialA: Credential,
    credentialB: Credential
  )
    requires ValidAuthorizationState(state)
    requires credentialA in StateCredentials(state)
    requires credentialB in StateCredentials(state)
    requires CredentialId(credentialA) != CredentialId(credentialB)
    requires StateCredentialAuthority(
               state,
               credentialA
             )
             ==
             StateCredentialAuthority(
               state,
               credentialB
             )
    ensures !SameCredential(
              credentialA,
              credentialB
            )
    ensures credentialA != credentialB
    ensures StateCredentialAuthority(
              state,
              credentialA
            )
            ==
            StateCredentialAuthority(
              state,
              credentialB
            )
  {
    assert
      !SameCredential(
        credentialA,
        credentialB
      );

    if credentialA == credentialB
    {
      assert CredentialId(credentialA)
             ==
             CredentialId(credentialB);

      assert false;
    }

    assert credentialA != credentialB;

    assert
      StateCredentialAuthority(
        state,
        credentialA
      )
      ==
      StateCredentialAuthority(
        state,
        credentialB
      );
  }


  // ----------------------------------------------------------
  // ATTACK 10.2 — BOTH CONCRETE SOURCES MAY BE CURRENTLY USABLE
  // ----------------------------------------------------------

  lemma DeFiDistinctEqualAuthorityCredentialsAreBothCurrentlyUsable(
    account: Account,
    credentialA: Credential,
    credentialB: Credential,
    identities: set<Identity>,
    now: Timestamp
  )
    requires ValidAccount(account)
    requires credentialA in StateCredentials(
                              AccountAuthorizationState(account)
                            )
    requires credentialB in StateCredentials(
                              AccountAuthorizationState(account)
                            )
    requires credentialA != credentialB
    requires CredentialIsActive(credentialA)
    requires CredentialIsActive(credentialB)
    requires CredentialId(credentialA) != CredentialId(credentialB)
    requires StateCredentialAuthority(
               AccountAuthorizationState(account),
               credentialA
             )
             ==
             StateCredentialAuthority(
               AccountAuthorizationState(account),
               credentialB
             )
    ensures
      StateCredentialAuthority(
        AccountAuthorizationState(account),
        credentialA
      )
      in
        CurrentlyUsableAuthoritySourcesForAcceptance(
          AccountAuthorizationState(account),
          account,
          identities,
          now
        )
    ensures
      StateCredentialAuthority(
        AccountAuthorizationState(account),
        credentialB
      )
      in
        CurrentlyUsableAuthoritySourcesForAcceptance(
          AccountAuthorizationState(account),
          account,
          identities,
          now
        )
  {
    assert
      CredentialAuthorityDefinedInState(
        AccountAuthorizationState(account),
        credentialA
      );

    assert
      CredentialAuthorityDefinedInState(
        AccountAuthorizationState(account),
        credentialB
      );

    assert
      ActiveCredentialRecognizedInState(
        AccountAuthorizationState(account),
        CredentialId(credentialA)
      );

    assert
      ActiveCredentialRecognizedInState(
        AccountAuthorizationState(account),
        CredentialId(credentialB)
      );

    assert
      StateCredentialAuthority(
        AccountAuthorizationState(account),
        credentialA
      )
      in
        CurrentlyUsableAuthoritySourcesForAcceptance(
          AccountAuthorizationState(account),
          account,
          identities,
          now
        );

    assert
      StateCredentialAuthority(
        AccountAuthorizationState(account),
        credentialB
      )
      in
        CurrentlyUsableAuthoritySourcesForAcceptance(
          AccountAuthorizationState(account),
          account,
          identities,
          now
        );
  }


  // ----------------------------------------------------------
  // ATTACK 10.3 — VALUE-ONLY WITNESSES MAY COLLIDE
  //
  // This remains true and is intentionally preserved as a
  // mathematical fact.
  //
  // It is not sufficient to establish an attribution collision
  // in the repaired acceptance contract.
  // ----------------------------------------------------------

  lemma DeFiValueOnlyProvenanceMayStillCollideForEqualAuthorityCredentials(
    account: Account,
    credentialA: Credential,
    credentialB: Credential,
    identities: set<Identity>,
    now: Timestamp,
    effectiveAuthority: EffectiveAuthority,
    contribution: set<Capability>
  )
    requires ValidAccount(account)
    requires credentialA in StateCredentials(
                              AccountAuthorizationState(account)
                            )
    requires credentialB in StateCredentials(
                              AccountAuthorizationState(account)
                            )
    requires CredentialId(credentialA) != CredentialId(credentialB)
    requires credentialA != credentialB
    requires CredentialIsActive(credentialA)
    requires CredentialIsActive(credentialB)
    requires StateCredentialAuthority(
               AccountAuthorizationState(account),
               credentialA
             )
             ==
             StateCredentialAuthority(
               AccountAuthorizationState(account),
               credentialB
             )
    requires contribution
             <=
             StateCredentialAuthority(
               AccountAuthorizationState(account),
               credentialA
             )
    requires effectiveAuthority == contribution

    ensures
      [StateCredentialAuthority(
         AccountAuthorizationState(account),
         credentialA
       )]
      ==
      [StateCredentialAuthority(
         AccountAuthorizationState(account),
         credentialB
       )]

    ensures
      EffectiveAuthorityDerivedFromSources(
        effectiveAuthority,
        [StateCredentialAuthority(
           AccountAuthorizationState(account),
           credentialA
         )],
        [contribution]
      )

    ensures
      EffectiveAuthorityDerivedFromSources(
        effectiveAuthority,
        [StateCredentialAuthority(
           AccountAuthorizationState(account),
           credentialB
         )],
        [contribution]
      )
  {
    DeFiDistinctEqualAuthorityCredentialsAreBothCurrentlyUsable(
      account,
      credentialA,
      credentialB,
      identities,
      now
    );

    assert
      StateCredentialAuthority(
        AccountAuthorizationState(account),
        credentialA
      )
      ==
      StateCredentialAuthority(
        AccountAuthorizationState(account),
        credentialB
      );

    assert
      [StateCredentialAuthority(
         AccountAuthorizationState(account),
         credentialA
       )]
      ==
      [StateCredentialAuthority(
         AccountAuthorizationState(account),
         credentialB
       )];

    assert contribution
           <=
           StateCredentialAuthority(
             AccountAuthorizationState(account),
             credentialA
           );

    assert contribution
           <=
           StateCredentialAuthority(
             AccountAuthorizationState(account),
             credentialB
           );

    assert effectiveAuthority == contribution;

    assert |[StateCredentialAuthority(
               AccountAuthorizationState(account),
               credentialA
             )]| == 1;

    assert |[StateCredentialAuthority(
               AccountAuthorizationState(account),
               credentialB
             )]| == 1;

    assert |[contribution]| == 1;

    assert
      [StateCredentialAuthority(
         AccountAuthorizationState(account),
         credentialA
       )][0]
      ==
      StateCredentialAuthority(
        AccountAuthorizationState(account),
        credentialA
      );

    assert
      [StateCredentialAuthority(
         AccountAuthorizationState(account),
         credentialB
       )][0]
      ==
      StateCredentialAuthority(
        AccountAuthorizationState(account),
        credentialB
      );

    assert [contribution][0] == contribution;

    assert
      contribution
      <=
      [StateCredentialAuthority(
         AccountAuthorizationState(account),
         credentialA
       )][0];

    assert
      contribution
      <=
      [StateCredentialAuthority(
         AccountAuthorizationState(account),
         credentialB
       )][0];

    forall capability' | capability' in effectiveAuthority
      ensures exists i ::
                0 <= i < |[contribution]|
                &&
                capability' in [contribution][i]
    {
      assert capability' in contribution;
      assert capability' in [contribution][0];
      assert 0 <= 0 < |[contribution]|;
    }

    forall i | 0 <= i < |[contribution]|
      ensures
        [contribution][i]
        <=
        [StateCredentialAuthority(
           AccountAuthorizationState(account),
           credentialA
         )][i]
    {
      assert i == 0;
      assert [contribution][0] == contribution;
      assert [StateCredentialAuthority(
                AccountAuthorizationState(account),
                credentialA
              )][0]
             ==
             StateCredentialAuthority(
               AccountAuthorizationState(account),
               credentialA
             );
      assert
        contribution
        <=
        StateCredentialAuthority(
          AccountAuthorizationState(account),
          credentialA
        );
    }

    forall i | 0 <= i < |[contribution]|
      ensures
        [contribution][i]
        <=
        [StateCredentialAuthority(
           AccountAuthorizationState(account),
           credentialB
         )][i]
    {
      assert i == 0;
      assert [contribution][0] == contribution;
      assert [StateCredentialAuthority(
                AccountAuthorizationState(account),
                credentialB
              )][0]
             ==
             StateCredentialAuthority(
               AccountAuthorizationState(account),
               credentialB
             );
      assert
        contribution
        <=
        StateCredentialAuthority(
          AccountAuthorizationState(account),
          credentialB
        );
    }

    assert
      forall capability' ::
        capability' in [contribution][0]
        ==>
          capability' in effectiveAuthority;

    assert
      EffectiveAuthorityDerivedFromSources(
        effectiveAuthority,
        [StateCredentialAuthority(
           AccountAuthorizationState(account),
           credentialA
         )],
        [contribution]
      );

    assert
      EffectiveAuthorityDerivedFromSources(
        effectiveAuthority,
        [StateCredentialAuthority(
           AccountAuthorizationState(account),
           credentialB
         )],
        [contribution]
      );
  }


  // ----------------------------------------------------------
  // ATTACK 10.4 — CONCRETE SOURCE REFERENCES DO NOT COLLIDE
  // ----------------------------------------------------------

  lemma DeFiDistinctCredentialsHaveDistinctAttributedSourceReferences(
    credentialA: Credential,
    credentialB: Credential
  )
    requires CredentialId(credentialA) != CredentialId(credentialB)
    ensures
      AuthoritySourceReference(
        CredentialAuthoritySource,
        CredentialId(credentialA)
      )
      !=
      AuthoritySourceReference(
        CredentialAuthoritySource,
        CredentialId(credentialB)
      )
  {
    if AuthoritySourceReference(
         CredentialAuthoritySource,
         CredentialId(credentialA)
       )
       ==
       AuthoritySourceReference(
         CredentialAuthoritySource,
         CredentialId(credentialB)
       )
    {
      assert CredentialId(credentialA)
             ==
             CredentialId(credentialB);

      assert false;
    }
  }


  // ----------------------------------------------------------
  // ATTACK 10.5 — ACCEPTED PROVENANCE PRESERVES CONCRETE SOURCE
  // ----------------------------------------------------------

  lemma DeFiAcceptedAuthorizationPreservesConcreteCredentialAttribution(
    authorization: Authorization,
    account: Account,
    credential: Credential,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    contribution: set<Capability>,
    now: Timestamp,
    proofVerified: bool
  )
    requires ValidAccount(account)
    requires credential in StateCredentials(
                              AccountAuthorizationState(account)
                            )
    requires CredentialIsActive(credential)

    requires AuthorizationCredentialId(authorization)
             ==
             CredentialId(credential)

    requires contribution
             <=
             StateCredentialAuthority(
               AccountAuthorizationState(account),
               credential
             )

    requires effectiveAuthority == contribution

    requires
      AuthorizationCanBeAccepted(
        authorization,
        account,
        effectiveAuthority,
        identities,
        [AuthoritySourceReference(
           CredentialAuthoritySource,
           CredentialId(credential)
         )],
        [StateCredentialAuthority(
           AccountAuthorizationState(account),
           credential
         )],
        [contribution],
        now,
        proofVerified
      )

    ensures
      AuthoritySourceReferenceResolvesToAuthority(
        AccountAuthorizationState(account),
        account,
        identities,
        now,
        AuthoritySourceReference(
          CredentialAuthoritySource,
          CredentialId(credential)
        ),
        StateCredentialAuthority(
          AccountAuthorizationState(account),
          credential
        )
      )

    ensures
      EffectiveAuthorityHasRecognizedAttributedProvenanceForAccountAt(
        effectiveAuthority,
        account,
        identities,
        now,
        [AuthoritySourceReference(
           CredentialAuthoritySource,
           CredentialId(credential)
         )],
        [StateCredentialAuthority(
           AccountAuthorizationState(account),
           credential
         )],
        [contribution]
      )
  {
    DeFiAcceptedAuthorizationRequiresConcreteAttributedProvenance(
      authorization,
      account,
      effectiveAuthority,
      identities,
      [AuthoritySourceReference(
         CredentialAuthoritySource,
         CredentialId(credential)
       )],
      [StateCredentialAuthority(
         AccountAuthorizationState(account),
         credential
       )],
      [contribution],
      now,
      proofVerified
    );

    assert
      AuthoritySourceReferenceResolvesToAuthority(
        AccountAuthorizationState(account),
        account,
        identities,
        now,
        AuthoritySourceReference(
          CredentialAuthoritySource,
          CredentialId(credential)
        ),
        StateCredentialAuthority(
          AccountAuthorizationState(account),
          credential
        )
      );
  }


  // ----------------------------------------------------------
  // ATTACK 10.6 — EQUAL AUTHORITY VALUES DO NOT ERASE
  //               CONCRETE SOURCE IDENTITY
  // ----------------------------------------------------------

  lemma DeFiEqualAuthorityValuesDoNotEraseConcreteCredentialIdentity(
    account: Account,
    credentialA: Credential,
    credentialB: Credential,
    identities: set<Identity>,
    now: Timestamp
  )
    requires ValidAccount(account)
    requires credentialA in StateCredentials(
                              AccountAuthorizationState(account)
                            )
    requires credentialB in StateCredentials(
                              AccountAuthorizationState(account)
                            )
    requires credentialA != credentialB
    requires CredentialId(credentialA) != CredentialId(credentialB)
    requires CredentialIsActive(credentialA)
    requires CredentialIsActive(credentialB)
    requires StateCredentialAuthority(
               AccountAuthorizationState(account),
               credentialA
             )
             ==
             StateCredentialAuthority(
               AccountAuthorizationState(account),
               credentialB
             )

    ensures
      AuthoritySourceReference(
        CredentialAuthoritySource,
        CredentialId(credentialA)
      )
      !=
      AuthoritySourceReference(
        CredentialAuthoritySource,
        CredentialId(credentialB)
      )
  {
    DeFiDistinctCredentialsHaveDistinctAttributedSourceReferences(
      credentialA,
      credentialB
    );
  }


  // ----------------------------------------------------------
  // ATTACK 10.7 — ACCEPTED ATTRIBUTED PROVENANCE IS CONCRETE
  // ----------------------------------------------------------

  lemma DeFiAcceptedProvenanceCarriesConcreteSourceReference(
    authorization: Authorization,
    account: Account,
    credential: Credential,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    contribution: set<Capability>,
    now: Timestamp,
    proofVerified: bool
  )
    requires ValidAccount(account)
    requires credential in StateCredentials(
                              AccountAuthorizationState(account)
                            )
    requires CredentialIsActive(credential)
    requires AuthorizationCredentialId(authorization)
             ==
             CredentialId(credential)
    requires contribution
             <=
             StateCredentialAuthority(
               AccountAuthorizationState(account),
               credential
             )
    requires effectiveAuthority == contribution
    requires
      AuthorizationCanBeAccepted(
        authorization,
        account,
        effectiveAuthority,
        identities,
        [AuthoritySourceReference(
           CredentialAuthoritySource,
           CredentialId(credential)
         )],
        [StateCredentialAuthority(
           AccountAuthorizationState(account),
           credential
         )],
        [contribution],
        now,
        proofVerified
      )
    ensures
      exists i ::
        0 <= i < 1
        &&
        [AuthoritySourceReference(
           CredentialAuthoritySource,
           CredentialId(credential)
         )][i]
        ==
        AuthoritySourceReference(
          CredentialAuthoritySource,
          CredentialId(credential)
        )
  {
    DeFiAcceptedAuthorizationPreservesConcreteCredentialAttribution(
      authorization,
      account,
      credential,
      effectiveAuthority,
      identities,
      contribution,
      now,
      proofVerified
    );

    assert
      [AuthoritySourceReference(
         CredentialAuthoritySource,
         CredentialId(credential)
       )][0]
      ==
      AuthoritySourceReference(
        CredentialAuthoritySource,
        CredentialId(credential)
      );

    assert 0 <= 0 < 1;
  }


  // ----------------------------------------------------------
  // ATTACK 10.8 — CONCRETE ATTRIBUTION SURVIVES EQUAL VALUES
  // ----------------------------------------------------------

  lemma DeFiEqualAuthorityValuesStillRetainDistinctAttributedSources(
    account: Account,
    credentialA: Credential,
    credentialB: Credential,
    identities: set<Identity>,
    now: Timestamp
  )
    requires ValidAccount(account)
    requires credentialA in StateCredentials(
                              AccountAuthorizationState(account)
                            )
    requires credentialB in StateCredentials(
                              AccountAuthorizationState(account)
                            )
    requires credentialA != credentialB
    requires CredentialId(credentialA) != CredentialId(credentialB)
    requires CredentialIsActive(credentialA)
    requires CredentialIsActive(credentialB)
    requires StateCredentialAuthority(
               AccountAuthorizationState(account),
               credentialA
             )
             ==
             StateCredentialAuthority(
               AccountAuthorizationState(account),
               credentialB
             )
    ensures
      AuthoritySourceReference(
        CredentialAuthoritySource,
        CredentialId(credentialA)
      )
      !=
      AuthoritySourceReference(
        CredentialAuthoritySource,
        CredentialId(credentialB)
      )
  {
    DeFiDistinctCredentialsHaveDistinctAttributedSourceReferences(
      credentialA,
      credentialB
    );

    assert credentialA != credentialB;

    assert
      CredentialId(credentialA)
      !=
      CredentialId(credentialB);
  }


  // ----------------------------------------------------------
  // ATTACK 10.9 — VALUE COLLISION DOES NOT RECREATE AN
  //               ACCEPTANCE-LEVEL ATTRIBUTION COLLISION
  // ----------------------------------------------------------
  //
  // The closure theorem intentionally remains source-oriented rather
  // than imposing a single Credential source on an Authorization.
  //
  // The claim is only:
  //
  //     accepted attributed provenance
  //         =>
  //     concrete source reference
  //
  // Therefore equal authority values from distinct Credentials do
  // not make the accepted source reference ambiguous.
  //

  lemma DeFiAcceptedAttributionRemainsConcreteForEqualAuthorityCredentials(
    authorization: Authorization,
    account: Account,
    credentialA: Credential,
    credentialB: Credential,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    contribution: set<Capability>,
    now: Timestamp,
    proofVerified: bool
  )
    requires ValidAccount(account)

    requires credentialA in StateCredentials(
                              AccountAuthorizationState(account)
                            )
    requires credentialB in StateCredentials(
                              AccountAuthorizationState(account)
                            )

    requires credentialA != credentialB

    requires CredentialId(credentialA)
             !=
             CredentialId(credentialB)

    requires CredentialIsActive(credentialA)
    requires CredentialIsActive(credentialB)

    requires StateCredentialAuthority(
               AccountAuthorizationState(account),
               credentialA
             )
             ==
             StateCredentialAuthority(
               AccountAuthorizationState(account),
               credentialB
             )

    requires AuthorizationCredentialId(authorization)
             ==
             CredentialId(credentialA)

    requires contribution
             <=
             StateCredentialAuthority(
               AccountAuthorizationState(account),
               credentialA
             )

    requires effectiveAuthority == contribution

    requires
      AuthorizationCanBeAccepted(
        authorization,
        account,
        effectiveAuthority,
        identities,
        [AuthoritySourceReference(
           CredentialAuthoritySource,
           CredentialId(credentialA)
         )],
        [StateCredentialAuthority(
           AccountAuthorizationState(account),
           credentialA
         )],
        [contribution],
        now,
        proofVerified
      )

    ensures
      AuthoritySourceReference(
        CredentialAuthoritySource,
        CredentialId(credentialA)
      )
      !=
      AuthoritySourceReference(
        CredentialAuthoritySource,
        CredentialId(credentialB)
      )

    ensures
      AuthoritySourceReferenceResolvesToAuthority(
        AccountAuthorizationState(account),
        account,
        identities,
        now,
        AuthoritySourceReference(
          CredentialAuthoritySource,
          CredentialId(credentialA)
        ),
        StateCredentialAuthority(
          AccountAuthorizationState(account),
          credentialA
        )
      )

    ensures
      EffectiveAuthorityHasRecognizedAttributedProvenanceForAccountAt(
        effectiveAuthority,
        account,
        identities,
        now,
        [AuthoritySourceReference(
           CredentialAuthoritySource,
           CredentialId(credentialA)
         )],
        [StateCredentialAuthority(
           AccountAuthorizationState(account),
           credentialA
         )],
        [contribution]
      )
  {
    DeFiDistinctEqualAuthorityCredentialsAreBothCurrentlyUsable(
      account,
      credentialA,
      credentialB,
      identities,
      now
    );

    DeFiDistinctCredentialsHaveDistinctAttributedSourceReferences(
      credentialA,
      credentialB
    );

    DeFiAcceptedAuthorizationPreservesConcreteCredentialAttribution(
      authorization,
      account,
      credentialA,
      effectiveAuthority,
      identities,
      contribution,
      now,
      proofVerified
    );

    assert
      AuthoritySourceReference(
        CredentialAuthoritySource,
        CredentialId(credentialA)
      )
      !=
      AuthoritySourceReference(
        CredentialAuthoritySource,
        CredentialId(credentialB)
      );

    assert
      AuthoritySourceReferenceResolvesToAuthority(
        AccountAuthorizationState(account),
        account,
        identities,
        now,
        AuthoritySourceReference(
          CredentialAuthoritySource,
          CredentialId(credentialA)
        ),
        StateCredentialAuthority(
          AccountAuthorizationState(account),
          credentialA
        )
      );

    assert
      EffectiveAuthorityHasRecognizedAttributedProvenanceForAccountAt(
        effectiveAuthority,
        account,
        identities,
        now,
        [AuthoritySourceReference(
           CredentialAuthoritySource,
           CredentialId(credentialA)
         )],
        [StateCredentialAuthority(
           AccountAuthorizationState(account),
           credentialA
         )],
        [contribution]
      );
  }


  // ==========================================================
  // ATTACK 11 — REACHABLE CREDENTIAL REGISTRATION
  // ==========================================================

  lemma DeFiRegisteredCredentialProducesValidAccount(
    account: Account,
    credential: Credential
  )
    requires ValidAccount(account)
    requires ValidCredential(credential)
    requires CredentialIsActive(credential)
    requires !CredentialIdRecognizedInState(
               AccountAuthorizationState(account),
               CredentialId(credential)
             )
    ensures ValidAccount(
              RegisterCredential(account, credential)
            )
    ensures AccountTransitionPreservesIdentity(
              account,
              RegisterCredential(account, credential)
            )
  {
    RegisterCredentialPreservesAccountValidity(
      account,
      credential
    );

    RegisterCredentialPreservesIdentity(
      account,
      credential
    );
  }


  lemma DeFiRegisteredCredentialHasEmptyAuthority(
    account: Account,
    credential: Credential
  )
    requires ValidAccount(account)
    requires ValidCredential(credential)
    requires CredentialIsActive(credential)
    requires !CredentialIdRecognizedInState(
               AccountAuthorizationState(account),
               CredentialId(credential)
             )
    ensures StateCredentialAuthority(
              AccountAuthorizationState(
                RegisterCredential(account, credential)
              ),
              credential
            ) == {}
  {
    RegisteredCredentialHasEmptyAuthority(
      account,
      credential
    );
  }


  lemma DeFiCapabilityIsOutsideRegisteredCredentialAuthority(
    account: Account,
    credential: Credential,
    capability: Capability
  )
    requires ValidAccount(account)
    requires ValidCredential(credential)
    requires CredentialIsActive(credential)
    requires !CredentialIdRecognizedInState(
               AccountAuthorizationState(account),
               CredentialId(credential)
             )
    ensures capability
            !in
            StateCredentialAuthority(
              AccountAuthorizationState(
                RegisterCredential(account, credential)
              ),
              credential
            )
  {
    DeFiRegisteredCredentialHasEmptyAuthority(
      account,
      credential
    );

    assert StateCredentialAuthority(
        AccountAuthorizationState(
          RegisterCredential(account, credential)
        ),
        credential
      ) == {};

    assert capability
      !in
      StateCredentialAuthority(
        AccountAuthorizationState(
          RegisterCredential(account, credential)
        ),
        credential
      );
  }


  // ==========================================================
  // ATTACK 12 — REACHABLE STATE + SOURCE UNIVERSE
  // ==========================================================

  lemma DeFiRegisteredCredentialStateIsValidForAcceptanceProjection(
    account: Account,
    credential: Credential
  )
    requires ValidAccount(account)
    requires ValidCredential(credential)
    requires CredentialIsActive(credential)
    requires !CredentialIdRecognizedInState(
               AccountAuthorizationState(account),
               CredentialId(credential)
             )
    ensures ValidAccount(
              RegisterCredential(account, credential)
            )
    ensures
      CredentialIdRecognizedInState(
        AccountAuthorizationState(
          RegisterCredential(account, credential)
        ),
        CredentialId(credential)
      )
  {
    RegisterCredentialPreservesAccountValidity(
      account,
      credential
    );

    RegisteredCredentialBelongsToState(
      account,
      credential
    );
  }


  // ==========================================================
  // ATTACK 13 — STRUCTURAL VALIDITY WITHOUT RECOGNIZED
  //              PROVENANCE CANNOT REACH ACCEPTANCE
  // ==========================================================

  lemma DeFiStructurallyValidAuthorityWithoutRecognizedProvenanceBlocksAcceptance(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp
  )
    requires ValidEffectiveAuthority(
               effectiveAuthority
             )
    requires AuthorizationRequestedAuthority(
               authorization
             )
          <= effectiveAuthority
    requires AuthorizationIsStructurallyValid(
               authorization
             )
    requires
      !EffectiveAuthorityHasRecognizedSourceProvenance(
        effectiveAuthority,
        CurrentlyUsableAuthoritySourcesForAcceptance(
          AccountAuthorizationState(account),
          account,
          identities,
          now
        ),
        sourceAuthorities,
        contributions
      )
    ensures !AuthorizationCanBeAccepted(
              authorization,
              account,
              effectiveAuthority,
              identities,
              sourceReferences,
              sourceAuthorities,
              contributions,
              now,
              true
            )
  {
    if AuthorizationCanBeAccepted(
        authorization,
        account,
        effectiveAuthority,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        now,
        true
      )
    {
      DeFiAcceptedAuthorizationUsesCurrentlyUsableSources(
        authorization,
        account,
        effectiveAuthority,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        now,
        true
      );

      assert false;
    }
  }


  // ==========================================================
  // REUSABLE DEFI CONTRACT
  // ==========================================================

  lemma DeFiProvidesReusableScenarioContract(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool
  )
    requires AuthorizationCanBeAccepted(
               authorization,
               account,
               effectiveAuthority,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               now,
               proofVerified
             )
    ensures AuthorizationRequestedAuthority(
              authorization
            ) <= effectiveAuthority
    ensures EffectiveAuthorityDerivedFromSources(
              effectiveAuthority,
              sourceAuthorities,
              contributions
            )
    ensures
      EffectiveAuthorityHasRecognizedSourceProvenance(
        effectiveAuthority,
        CurrentlyUsableAuthoritySourcesForAcceptance(
          AccountAuthorizationState(account),
          account,
          identities,
          now
        ),
        sourceAuthorities,
        contributions
      )
    ensures
      EffectiveAuthorityHasRecognizedAttributedProvenanceForAccountAt(
        effectiveAuthority,
        account,
        identities,
        now,
        sourceReferences,
        sourceAuthorities,
        contributions
      )
  {
    DeFiAcceptedAuthorizationRequestsOnlyEffectiveAuthority(
      authorization,
      account,
      effectiveAuthority,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      now,
      proofVerified
    );

    DeFiAcceptedAuthorizationRequiresEffectiveAuthorityProvenance(
      authorization,
      account,
      effectiveAuthority,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      now,
      proofVerified
    );

    DeFiAcceptedAuthorizationRequiresConcreteAttributedProvenance(
      authorization,
      account,
      effectiveAuthority,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      now,
      proofVerified
    );

    DeFiAcceptedAuthorizationUsesCurrentlyUsableSources(
      authorization,
      account,
      effectiveAuthority,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      now,
      proofVerified
    );
  }


  // ==========================================================
  // CURRENT FINDING
  // ==========================================================
  //
  // RequestedAuthority containment:
  //
  //     CLOSED
  //
  // EffectiveAuthority structural validity:
  //
  //     CLOSED
  //
  // EffectiveAuthority value-level provenance:
  //
  //     FORMALIZED
  //
  // Concrete attributed provenance:
  //
  //     FORMALIZED
  //
  // Accepted provenance source membership:
  //
  //     GROUNDED IN
  //     CurrentlyUsableAuthoritySourcesForAcceptance
  //
  // Source-reference resolution:
  //
  //     EXACT
  //
  //     AuthoritySourceReference
  //             |
  //             v
  //     Account-relative authority source
  //             |
  //             v
  //     exact sourceAuthority value
  //
  // Accepted EffectiveAuthority capability:
  //
  //     MUST HAVE A CURRENTLY USABLE ATTRIBUTED SOURCE
  //
  // Requested Capability absent from every currently usable source:
  //
  //     BLOCKS ACCEPTANCE
  //
  // Explicit provenance source outside the usable source universe:
  //
  //     BLOCKS ACCEPTANCE
  //
  // Multi-source EffectiveAuthority:
  //
  //     PRESERVED THROUGH INDEXED PROVENANCE
  //
  // Structural validity without recognized provenance:
  //
  //     BLOCKS ACCEPTANCE
  //
  // Credential Entity identity:
  //
  //     PRESERVED BY CredentialId
  //
  // Credential -> CredentialAuthority association:
  //
  //     PRESERVED BY AuthorizationState
  //
  // Two distinct Credentials may expose equal CredentialAuthority
  // values:
  //
  //     Credential A != Credential B
  //
  //     Authority(A) == Authority(B)
  //
  // This remains a valid domain state.
  //
  // Value-only witness collision:
  //
  //     POSSIBLE
  //
  // because:
  //
  //     [Authority(A)] == [Authority(B)]
  //
  // when:
  //
  //     Authority(A) == Authority(B).
  //
  // This is only an extensional equality of authority values.
  //
  // Concrete attributed-source identity:
  //
  //     PRESERVED
  //
  // because:
  //
  //     CredentialId(A) != CredentialId(B)
  //
  // implies:
  //
  //     AuthoritySourceReference(A)
  //         !=
  //     AuthoritySourceReference(B)
  //
  // Accepted source attribution:
  //
  //     RESOLVES AGAINST ACCOUNT STATE
  //
  // and:
  //
  //     THE RESOLVED AUTHORITY MUST MATCH
  //     THE SUPPLIED SOURCE AUTHORITY
  //
  // Therefore equal authority values do not erase concrete source
  // identity from accepted attributed provenance.
  //
  // ------------------------------------------------------------
  //
  // FORMAL DEBT STATUS
  //
  //     CONCRETE AUTHORITY SOURCE ATTRIBUTION
  //         =
  //     CLOSED
  //
  // Precise closure:
  //
  //     PROVENANCE
  //         = EXISTS
  //
  //     SOURCE NON-EXPANSION
  //         = PROVEN
  //
  //     SOURCE USABILITY
  //         = PROVEN
  //
  //     DELEGATION CAUSAL PROVENANCE
  //         = PROVEN
  //
  //     CONCRETE SOURCE REFERENCES
  //         = PRESENT
  //
  //     SOURCE REFERENCE RESOLUTION
  //         = PROVEN
  //
  //     CONCRETE SOURCE ATTRIBUTION OF ACCEPTED CONTRIBUTIONS
  //         = PROVEN
  //
  // The remaining equality:
  //
  //     Authority(A) == Authority(B)
  //
  // does not imply:
  //
  //     AuthoritySourceReference(A)
  //         ==
  //     AuthoritySourceReference(B)
  //
  // when:
  //
  //     CredentialId(A) != CredentialId(B).
  //
  // Therefore the concrete source-attribution formalization debt
  // is closed.
  //
  // This closure does NOT impose:
  //
  //     AuthorizationCredentialId
  //         ==
  //     every accepted provenance source
  //
  // because independent multi-source authority remains valid.
  //
  // ==========================================================
}

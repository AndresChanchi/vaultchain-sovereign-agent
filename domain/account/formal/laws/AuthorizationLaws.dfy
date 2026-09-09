// ============================================================
// KIPIO ACCOUNT DOMAIN
// LAWS — AUTHORIZATION
// ============================================================
//
// Cross-concept semantic laws governing Authorization.
//
// This file exposes consequences that require Authorization to be
// considered together with:
//
//   - Account;
//   - Authorization State;
//   - Credential Entities;
//   - Effective Authority;
//   - Credential Authority;
//   - Effective Authority provenance;
//   - contextual acceptance.
//
// Local Authorization semantics remain in Authorization.dfy.
//
// Authorization acceptance semantics remain in
// AuthorizationValidation.dfy.
//
// Replay semantics remain in Replay.dfy.
//
// Authorization State invariants remain in AuthorizationState.dfy.
//
// Effective Authority semantics remain in EffectiveAuthority.dfy.
//
// This file therefore does NOT duplicate those local laws.
//
// ------------------------------------------------------------
//
// CORE CROSS-CONCEPT RELATIONSHIPS
//
//     Authorization
//          |
//          | CredentialId
//          v
//     Recognized Credential Entity
//
//     Requested Authority
//          |
//          ⊆
//          v
//     Effective Authority
//          |
//          ⊆
//          v
//     Credential Authority
//
//     Effective Authority
//          |
//          | provenance
//          v
//     Currently Usable / Legitimate Sources
//
// ------------------------------------------------------------
//
// IMPORTANT DISTINCTIONS
//
//     Authorization
//         = Value Object
//
//     Credential
//         = Entity
//
//     CredentialId
//         = Entity reference
//
//     Effective Authority
//         = contextual Value Object
//
//     Provenance
//         = ghost proof-level relation
//
//     Proof verification
//         = external validation input
//
//     Replay freshness
//         = state-dependent acceptance condition
//
// ------------------------------------------------------------
//
// RESPONSIBILITY BOUNDARY
//
// This file does NOT:
//
//   - define Authorization;
//   - define Authorization structural validity;
//   - define Authorization acceptance;
//   - define Credential lifecycle;
//   - define Replay semantics;
//   - define Effective Authority;
//   - define provenance traversal;
//   - mutate Authorization State;
//   - verify Proof;
//   - execute anything.
//
// It exposes cross-concept consequences of those definitions.
//
// ============================================================

include "../foundation/DomainPrimitives.dfy"
include "../foundation/Capability.dfy"
include "../foundation/Identity.dfy"

include "../account/Account.dfy"

include "../authority/Credential.dfy"
include "../authority/CredentialAuthority.dfy"
include "../authority/EffectiveAuthority.dfy"
include "../authority/AuthorizationState.dfy"

include "../authorization/Authorization.dfy"
include "../authorization/AuthorizationValidation.dfy"

module KipioAccountAuthorizationLaws
{
  import opened KipioAccountDomainPrimitives
  import opened KipioAccountCapability
  import opened KipioAccountIdentity
  import opened KipioAccountAccount
  import opened KipioAccountCredential
  import opened KipioAccountCredentialAuthority
  import opened KipioAccountEffectiveAuthority
  import opened KipioAccountAuthorizationState
  import opened KipioAccountAuthorization
  import opened KipioAccountAuthorizationValidation


  // ----------------------------------------------------------
  // CREDENTIAL ENTITY RESOLUTION
  // ----------------------------------------------------------

  // An accepted Authorization references a Credential Entity that
  // is actually recognized in the Authorization State belonging to
  // the Account.
  //
  // Authorization stores only CredentialId.
  //
  // Therefore acceptance resolves the Entity through stable
  // identity rather than by embedding a Credential value.
  lemma AcceptedAuthorizationReferencesRecognizedCredentialEntity(
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
    ensures exists credential ::
              credential in StateCredentials(
                              AccountAuthorizationState(account)
                            )
              &&
              CredentialId(credential)
              == AuthorizationCredentialId(authorization)
  {
    var state := AccountAuthorizationState(account);

    var credential :|
      credential in StateCredentials(state)
      &&
      CredentialId(credential)
      == AuthorizationCredentialId(authorization);

    assert credential in StateCredentials(state);
    assert CredentialId(credential)
        == AuthorizationCredentialId(authorization);

    assert exists resolvedCredential ::
        resolvedCredential in StateCredentials(state)
        &&
        CredentialId(resolvedCredential)
        == AuthorizationCredentialId(authorization);
  }


  // In a valid Authorization State, the recognized Credential Entity
  // referenced by an accepted Authorization is itself structurally
  // valid.
  //
  // This separates:
  //
  //     Authorization
  //         ->
  //     CredentialId reference
  //
  // from:
  //
  //     Credential Entity validity.
  lemma AcceptedAuthorizationReferencesValidCredentialEntity(
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
    requires ValidAuthorizationState(
               AccountAuthorizationState(account)
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
    ensures exists credential ::
              credential in StateCredentials(
                              AccountAuthorizationState(account)
                            )
              &&
              CredentialId(credential)
              == AuthorizationCredentialId(authorization)
              &&
              ValidCredential(credential)
  {
    var state := AccountAuthorizationState(account);

    var credential :|
      credential in StateCredentials(state)
      &&
      CredentialId(credential)
      == AuthorizationCredentialId(authorization);

    assert credential in StateCredentials(state);
    assert CredentialId(credential)
        == AuthorizationCredentialId(authorization);
    assert ValidCredential(credential);

    assert exists resolvedCredential ::
        resolvedCredential in StateCredentials(state)
        &&
        CredentialId(resolvedCredential)
        == AuthorizationCredentialId(authorization)
        &&
        ValidCredential(resolvedCredential);
  }


  // ----------------------------------------------------------
  // REQUESTED AUTHORITY / EFFECTIVE AUTHORITY
  // ----------------------------------------------------------

  // Every Capability explicitly requested by an accepted
  // Authorization is contained in the supplied Effective Authority.
  //
  // This exposes the cross-concept boundary:
  //
  //     Requested Authority
  //          ⊆
  //     Effective Authority
  lemma AcceptedRequestedCapabilityIsEffective(
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
    ensures CapabilityIsEffective(
              effectiveAuthority,
              capability
            )
  {
    assert AuthorizationRequestedAuthority(authorization)
        <= effectiveAuthority;

    assert capability in AuthorizationRequestedAuthority(authorization);
    assert capability in effectiveAuthority;
    assert CapabilityIsEffective(
        effectiveAuthority,
        capability
      );
  }


  // ----------------------------------------------------------
  // CREDENTIAL AUTHORITY BOUNDARY
  // ----------------------------------------------------------

  // If the Effective Authority supplied for an accepted
  // Authorization is itself bounded by a Credential Authority,
  // then no requested Capability may escape that Credential
  // Authority.
  //
  // The cross-concept chain is:
  //
  //     Requested Authority
  //          ⊆
  //     Effective Authority
  //          ⊆
  //     Credential Authority
  lemma AcceptedAuthorizationCannotExceedCredentialAuthority(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    credentialAuthority: CredentialAuthority,
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
    requires EffectiveAuthorityWithinSourceAuthority(
               effectiveAuthority,
               credentialAuthority
             )
    requires AuthorizationRequestsCapability(
               authorization,
               capability
             )
    ensures capability in credentialAuthority
  {
    assert AuthorizationRequestedAuthority(authorization)
        <= effectiveAuthority;

    assert effectiveAuthority <= credentialAuthority;

    assert capability in AuthorizationRequestedAuthority(
                           authorization
                         );

    assert capability in effectiveAuthority;
    assert capability in credentialAuthority;
  }


  // The complete Requested Authority of an accepted Authorization
  // remains bounded by the supplied Credential Authority whenever
  // the Effective Authority is bounded by that source.
  lemma AcceptedRequestedAuthorityCannotExceedCredentialAuthority(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    credentialAuthority: CredentialAuthority,
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
    requires EffectiveAuthorityWithinSourceAuthority(
               effectiveAuthority,
               credentialAuthority
             )
    ensures AuthorizationRequestedAuthority(
              authorization
            )
         <= credentialAuthority
  {
    assert AuthorizationRequestedAuthority(authorization)
        <= effectiveAuthority;

    assert effectiveAuthority <= credentialAuthority;

    forall capability
      | capability in AuthorizationRequestedAuthority(authorization)
      ensures capability in credentialAuthority
    {
      assert capability in effectiveAuthority;
      assert capability in credentialAuthority;
    }
  }


  // ----------------------------------------------------------
  // EFFECTIVE AUTHORITY PROVENANCE CLOSURE
  // ----------------------------------------------------------

  // An accepted Authorization cannot rely on an Effective Authority
  // whose provenance is merely asserted structurally.
  //
  // Acceptance requires the ghost provenance witness to resolve
  // every source contribution against the Account's currently
  // usable and provenance-legitimate source universe.
  //
  // This law therefore exposes the final cross-concept closure:
  //
  //     Authorization
  //          +
  //     Account State
  //          +
  //     Effective Authority
  //          +
  //     Identity context
  //          +
  //     source provenance
  lemma AcceptedAuthorizationHasContextuallyGroundedEffectiveAuthorityProvenance(
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
    ensures EffectiveAuthorityProvenanceIsValidForAccountAt(
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
      EffectiveAuthorityProvenanceIsValidForAccountAt(
        effectiveAuthority,
        account,
        identities,
        now,
        sourceReferences,
        sourceAuthorities,
        contributions
      );
  }


  // Every Capability present in an accepted Effective Authority must
  // be backed by at least one source that is currently usable for
  // acceptance and whose provenance is legitimate in the Account
  // context.
  lemma AcceptedEffectiveAuthorityCapabilityHasGroundedSource(
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
    ensures exists sourceAuthority ::
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
    RecognizedEffectiveAuthorityCapabilityHasRecognizedSource(
      effectiveAuthority,
      CurrentlyUsableAuthoritySourcesForAcceptance(
        AccountAuthorizationState(account),
        account,
        identities,
        now
      ),
      sourceAuthorities,
      contributions,
      capability
    );
  }


  // ----------------------------------------------------------
  // COMPLETE ACCEPTANCE DECOMPOSITION
  // ----------------------------------------------------------

  // An accepted Authorization simultaneously satisfies the
  // principal cross-concept acceptance boundaries.
  //
  // This theorem intentionally exposes the complete validation
  // closure rather than redefining any individual predicate.
  //
  // The provenance condition is included explicitly because the
  // supplied Effective Authority is not trusted merely because it
  // is structurally valid.
  lemma AcceptedAuthorizationSatisfiesAllAcceptanceBoundaries(
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
    ensures ValidAccount(account)
    ensures AuthorizationIsStructurallyValid(
              authorization
            )
    ensures AuthorizationContextMatchesAccount(
              authorization,
              account
            )
    ensures AuthorizationCredentialIsUsable(
              authorization,
              AccountAuthorizationState(account)
            )
    ensures AuthorizationIsTemporallyValidAt(
              authorization,
              now
            )
    ensures AuthorizationReplayIsFresh(
              authorization,
              AccountAuthorizationState(account)
            )
    ensures EffectiveAuthorityIsValid(
              effectiveAuthority
            )
    ensures EffectiveAuthorityProvenanceIsValidForAccountAt(
              effectiveAuthority,
              account,
              identities,
              now,
              sourceReferences,
              sourceAuthorities,
              contributions
            )
    ensures AuthorizationAuthorityIsEffective(
              authorization,
              effectiveAuthority
            )
    ensures AuthorizationProofIsVerified(
              proofVerified
            )
  {
    assert ValidAccount(account);

    assert AuthorizationIsStructurallyValid(
        authorization
      );

    assert AuthorizationContextMatchesAccount(
        authorization,
        account
      );

    assert AuthorizationCredentialIsUsable(
        authorization,
        AccountAuthorizationState(account)
      );

    assert AuthorizationIsTemporallyValidAt(
        authorization,
        now
      );

    assert AuthorizationReplayIsFresh(
        authorization,
        AccountAuthorizationState(account)
      );

    assert EffectiveAuthorityIsValid(
        effectiveAuthority
      );

    assert EffectiveAuthorityProvenanceIsValidForAccountAt(
        effectiveAuthority,
        account,
        identities,
        now,
        sourceReferences,
        sourceAuthorities,
        contributions
      );

    assert AuthorizationAuthorityIsEffective(
        authorization,
        effectiveAuthority
      );

    assert AuthorizationProofIsVerified(
        proofVerified
      );
  }
}

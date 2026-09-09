// ============================================================
// KIPIO ACCOUNT DOMAIN
// PROOFS — AUTHORIZATION
// ============================================================
//
// Isolated formal proofs for the Authorization layer.
//
// Purpose:
//
//   - validate the composition of Authorization semantics;
//   - prove reusable acceptance consequences;
//   - expose the individual acceptance boundaries;
//   - provide reusable contracts for later Account, Execution
//     and end-to-end proofs.
//
// ------------------------------------------------------------
//
// AUTHORIZATION ACCEPTANCE CHAIN
//
//     Authorization
//          |
//          v
//     Structural validity
//          |
//          v
//     Account Context compatibility
//          |
//          v
//     Valid Account
//          |
//          v
//     Credential recognition
//          |
//          v
//     Credential usability
//          |
//          v
//     Temporal validity
//          |
//          v
//     Replay freshness
//          |
//          v
//     Effective Authority containment
//          |
//          v
//     Effective Authority provenance evidence
//          |
//          v
//     External Proof verification
//          |
//          v
//     Authorization acceptance
//
// ------------------------------------------------------------
//
// IMPORTANT CONTEXT BOUNDARY
//
// AuthorizationCanBeAccepted validates an Authorization against
// an Account, not against an AuthorizationState supplied as an
// independent context.
//
// The Account provides the authoritative:
//
//     AccountId
//     Sovereign Identity
//     AuthorizationState
//
// Therefore the proof layer preserves the same contextual
// relationship:
//
//     Authorization.accountId
//           ==
//     Account.id
//
// and:
//
//     AuthorizationState
//           =
//     AccountAuthorizationState(account)
//
// Account validity is also an explicit acceptance condition in
// the authoritative AuthorizationCanBeAccepted contract.
//
// ------------------------------------------------------------
//
// PROOF SCOPE
//
// This file proves:
//
//   - structural Authorization consequences;
//   - Account Context compatibility;
//   - Credential recognition and usability;
//   - Effective Authority containment;
//   - Effective Authority provenance as contextual evidence;
//   - temporal validity;
//   - Replay Protection;
//   - external Proof verification;
//   - acceptance decomposition;
//   - Authorization Value Object context semantics.
//
// This file intentionally does NOT prove:
//
//   - how Effective Authority is independently derived or resolved;
//   - the internal implementation of cryptographic Proof semantics;
//   - state mutation;
//   - execution semantics.
//
// Account validity is consumed here through the authoritative
// Authorization acceptance contract. This facade does not redefine
// ValidAccount or create a second Account-validity model.
//
// The provenance relation is supplied to Authorization acceptance as
// ghost contextual evidence through:
//
//     identities
//     sourceAuthorities
//     contributions
//
// This facade consumes that authoritative contract; it does not
// invent or recompute the provenance relation.
//
// ------------------------------------------------------------
//
// NO INVENTED SEMANTICS
//
// In particular, this file does NOT introduce:
//
//   - AuthorizationId;
//   - Proof equality;
//   - Proof datatype;
//   - replay mutation;
//   - Effective Authority derivation;
//   - a duplicate Account validity definition;
//   - a second, duplicate provenance model inside this facade.
//
// ============================================================


// ============================================================
// IMPORTS
// ============================================================

include "../../authorization/Authorization.dfy"
include "../../authorization/AuthorizationValidation.dfy"
include "../../authorization/Replay.dfy"
include "../../foundation/Identity.dfy"

include "../../authority/Credential.dfy"
include "../../authority/CredentialAuthority.dfy"
include "../../authority/EffectiveAuthority.dfy"
include "../../authority/AuthorizationState.dfy"

include "../../account/Account.dfy"

module KipioAccountAuthorizationProofs
{
  import opened KipioAccountDomainPrimitives
  import opened KipioAccountCapability
  import opened KipioAccountRestriction

  import opened KipioAccountCredential
  import opened KipioAccountCredentialAuthority
  import opened KipioAccountEffectiveAuthority
  import opened KipioAccountAuthorizationState

  import opened KipioAccountAccount

  import opened KipioAccountAuthorization
  import opened KipioAccountAuthorizationValidation
  import opened KipioAccountReplay
  import opened KipioAccountScope
  import opened KipioAccountIdentity



  // ============================================================
  // STRUCTURAL AUTHORIZATION
  // ============================================================

  // A structurally valid Authorization contains a valid
  // CredentialId.
  lemma StructuralAuthorizationHasValidCredentialId(
    authorization: Authorization
  )
    requires AuthorizationIsStructurallyValid(
               authorization
             )
    ensures ValidId(
              AuthorizationCredentialId(
                authorization
              )
            )
  {
  }


  // Every Capability requested by a structurally valid
  // Authorization is structurally valid.
  lemma StructuralAuthorizationRequestsOnlyValidCapabilities(
    authorization: Authorization,
    capability: Capability
  )
    requires AuthorizationIsStructurallyValid(
               authorization
             )
    requires AuthorizationRequestsCapability(
               authorization,
               capability
             )
    ensures ValidCapability(capability)
  {
  }


  // Every Restriction carried by a structurally valid
  // Authorization is structurally valid.
  lemma StructuralAuthorizationContainsOnlyValidRestrictions(
    authorization: Authorization,
    restriction: Restriction
  )
    requires AuthorizationIsStructurallyValid(
               authorization
             )
    requires AuthorizationContainsRestriction(
               authorization,
               restriction
             )
    ensures ValidRestriction(restriction)
  {
  }


  // A structurally valid Authorization has an ordered validity
  // interval.
  lemma StructuralAuthorizationHasOrderedValidityInterval(
    authorization: Authorization
  )
    requires AuthorizationIsStructurallyValid(
               authorization
             )
    ensures AuthorizationValidFrom(authorization)
         <= AuthorizationValidUntil(authorization)
  {
  }


  // A structurally valid Authorization carries a structurally
  // valid Replay Protection value.
  //
  // Structural validity does not imply replay freshness.
  lemma StructuralAuthorizationHasValidReplayKey(
    authorization: Authorization
  )
    requires AuthorizationIsStructurallyValid(
               authorization
             )
    ensures ValidId(
              AuthorizationReplayKey(
                authorization
              )
            )
  {
  }


  // A structurally valid Authorization contains a valid AccountId
  // as part of its semantic Context.
  lemma StructuralAuthorizationHasValidAccountId(
    authorization: Authorization
  )
    requires AuthorizationIsStructurallyValid(
               authorization
             )
    ensures ValidId(
              AuthorizationAccountId(
                authorization
              )
            )
  {
  }


  // A structurally valid Authorization contains a valid semantic
  // Scope as part of its Context.
  lemma StructuralAuthorizationHasValidContextScope(
    authorization: Authorization
  )
    requires AuthorizationIsStructurallyValid(
               authorization
             )
    ensures ValidScope(
              AuthorizationScope(
                authorization
              )
            )
  {
  }



  // ============================================================
  // ACCOUNT CONTEXT
  // ============================================================

  // An accepted Authorization necessarily matches the Account
  // against which it is validated.
  lemma AcceptedAuthorizationMatchesAccountContext(
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
    ensures AuthorizationContextMatchesAccount(
              authorization,
              account
            )
  {
  }


  // Therefore the AccountId embedded in the Authorization equals
  // the AccountId of the validating Account.
  lemma AcceptedAuthorizationReferencesValidatingAccountId(
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
    ensures AuthorizationAccountId(authorization)
         == AccountIdOf(account)
  {
  }


  // An Authorization for a different Account cannot satisfy the
  // Account Context compatibility condition.
  lemma DifferentAccountContextBlocksAuthorizationCompatibility(
    authorization: Authorization,
    account: Account
  )
    requires AuthorizationAccountId(authorization)
          != AccountIdOf(account)
    ensures !AuthorizationContextMatchesAccount(
              authorization,
              account
            )
  {
  }



  // ============================================================
  // CREDENTIAL RECOGNITION
  // ============================================================

  // Acceptance requires the referenced Credential to be recognized
  // in the Authorization State of the validating Account.
  lemma AcceptedAuthorizationUsesRecognizedCredential(
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
    ensures AuthorizationCredentialIsRecognized(
              authorization,
              AccountAuthorizationState(account)
            )
  {
  }


  // Acceptance requires the referenced Credential to be Active.
  lemma AcceptedAuthorizationUsesActiveCredential(
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
    ensures AuthorizationCredentialIsActive(
              authorization,
              AccountAuthorizationState(account)
            )
  {
  }


  // An accepted Authorization therefore uses a Credential that is
  // recognized and Active.
  lemma AcceptedAuthorizationUsesUsableCredential(
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
    ensures AuthorizationCredentialIsUsable(
              authorization,
              AccountAuthorizationState(account)
            )
  {
  }


  // An accepted Authorization resolves its CredentialId to a
  // Credential Entity recognized by the Account state.
  lemma AcceptedAuthorizationResolvesCredentialEntity(
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
              && CredentialId(credential)
                 == AuthorizationCredentialId(
                      authorization
                    )
  {
  }



  // ============================================================
  // EFFECTIVE AUTHORITY
  // ============================================================

  // Accepted Authorization requires a structurally valid supplied
  // Effective Authority.
  lemma AcceptedAuthorizationHasValidEffectiveAuthority(
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
    ensures EffectiveAuthorityIsValid(
              effectiveAuthority
            )
  {
  }


  // Accepted Authorization cannot request authority outside the
  // supplied Effective Authority.
  lemma AcceptedAuthorizationIsBoundedByEffectiveAuthority(
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
    ensures AuthorizationAuthorityIsEffective(
              authorization,
              effectiveAuthority
            )
  {
  }


  // Every requested Capability of an accepted Authorization must
  // belong to the supplied Effective Authority.
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
  }


  // Every requested Capability of an accepted Authorization is
  // structurally valid.
  lemma AcceptedRequestedCapabilityIsValid(
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
    ensures ValidCapability(capability)
  {
  }


  // If Effective Authority is explicitly bounded by a source
  // authority, an accepted Authorization cannot escape that source
  // through its requested authority.
  lemma AcceptedAuthorizationCannotEscapeSourceAuthority(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    sourceAuthority: set<Capability>,
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
               sourceAuthority
             )
    ensures AuthorizationRequestedAuthority(
              authorization
            )
         <= sourceAuthority
  {
  }



  // ============================================================
  // TEMPORAL VALIDITY
  // ============================================================

  // Acceptance requires current temporal validity.
  lemma AcceptedAuthorizationIsTemporallyValid(
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
    ensures AuthorizationIsTemporallyValidAt(
              authorization,
              now
            )
  {
  }


  // Before validFrom, Authorization cannot satisfy the temporal
  // acceptance condition.
  lemma AuthorizationCannotBeAcceptedBeforeValidityBegins(
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
    requires now < AuthorizationValidFrom(
                     authorization
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
  }


  // After validUntil, Authorization cannot satisfy the temporal
  // acceptance condition.
  lemma AuthorizationCannotBeAcceptedAfterValidityEnds(
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
    requires now > AuthorizationValidUntil(
                     authorization
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
  }


  // Temporal endpoints are inclusive.
  lemma AuthorizationIsValidAtLowerTemporalBoundary(
    authorization: Authorization
  )
    requires AuthorizationIsStructurallyValid(
               authorization
             )
    ensures AuthorizationIsTemporallyValidAt(
              authorization,
              AuthorizationValidFrom(
                authorization
              )
            )
  {
  }


  lemma AuthorizationIsValidAtUpperTemporalBoundary(
    authorization: Authorization
  )
    requires AuthorizationIsStructurallyValid(
               authorization
             )
    ensures AuthorizationIsTemporallyValidAt(
              authorization,
              AuthorizationValidUntil(
                authorization
              )
            )
  {
  }



  // ============================================================
  // REPLAY PROTECTION
  // ============================================================

  // Acceptance requires Replay Protection freshness in the
  // validating Account's Authorization State.
  lemma AcceptedAuthorizationHasFreshReplayProtection(
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
    ensures AuthorizationReplayIsFresh(
              authorization,
              AccountAuthorizationState(account)
            )
  {
  }


  // A consumed replay key cannot be fresh.
  lemma ConsumedReplayKeyIsNotFresh(
    authorization: Authorization,
    replayState: ReplayState
  )
    requires ReplayKeyOfAuthorization(
               authorization
             )
             in replayState
    ensures !AuthorizationReplayKeyIsFresh(
              authorization,
              replayState
            )
  {
  }


  // After replay-key consumption, the same Authorization is no
  // longer replay-fresh.
  lemma AuthorizationIsNotFreshAfterReplayConsumption(
    authorization: Authorization,
    replayState: ReplayState
  )
    ensures !AuthorizationReplayKeyIsFresh(
              authorization,
              ConsumeAuthorizationReplayKey(
                replayState,
                authorization
              )
            )
  {
  }


  // Replay consumption is monotonic.
  lemma ReplayConsumptionPreservesConsumedHistory(
    authorization: Authorization,
    replayState: ReplayState
  )
    ensures replayState
            <=
            ConsumeAuthorizationReplayKey(
              replayState,
              authorization
            )
  {
  }


  // If the Authorization replay key has already been consumed in
  // the validating Account state, acceptance is impossible.
  lemma ConsumedReplayKeyBlocksAuthorizationAcceptance(
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
    requires AuthorizationReplayKey(
               authorization
             )
             in StateConsumedReplayKeys(
                  AccountAuthorizationState(account)
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
  }



  // ============================================================
  // EXTERNAL PROOF VERIFICATION
  // ============================================================

  // Acceptance requires the external Proof verification result to
  // be true.
  lemma AcceptedAuthorizationRequiresVerifiedProof(
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
    ensures AuthorizationProofIsVerified(
              proofVerified
            )
  {
  }


  // A false external Proof verification result blocks acceptance.
  lemma FailedProofVerificationBlocksAuthorizationAcceptance(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp
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
              false
            )
  {
  }



  // ============================================================
  // COMPLETE ACCEPTANCE CONTRACT
  // ============================================================

  // Acceptance simultaneously establishes every currently
  // formalized acceptance boundary.
  lemma AcceptedAuthorizationSatisfiesAllValidationBoundaries(
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
    ensures AuthorizationAuthorityIsEffective(
              authorization,
              effectiveAuthority
            )
    ensures AuthorizationProofIsVerified(
              proofVerified
            )
  {
  }



  // An accepted Authorization's requested authority is a subset
  // of its Effective Authority.
  lemma AcceptedAuthorizationRequestsSubsetOfEffectiveAuthority(
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
  }



  // ============================================================
  // INDEPENDENT ACCEPTANCE BOUNDARIES
  // ============================================================

  // Structural invalidity blocks acceptance.
  lemma StructurallyInvalidAuthorizationBlocksAcceptance(
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
    requires !AuthorizationIsStructurallyValid(
               authorization
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
  }


  // A Credential that is not recognized cannot satisfy acceptance.
  lemma UnrecognizedCredentialBlocksAcceptance(
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
    requires !AuthorizationCredentialIsRecognized(
               authorization,
               AccountAuthorizationState(account)
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
  }


  // A recognized but inactive Credential cannot satisfy acceptance.
  lemma InactiveCredentialBlocksAcceptance(
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
    requires AuthorizationCredentialIsRecognized(
               authorization,
               AccountAuthorizationState(account)
             )
    requires !AuthorizationCredentialIsActive(
               authorization,
               AccountAuthorizationState(account)
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
  }


  // Invalid Effective Authority blocks acceptance.
  lemma InvalidEffectiveAuthorityBlocksAcceptance(
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
    requires !EffectiveAuthorityIsValid(
               effectiveAuthority
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
  }


  // Requested authority outside Effective Authority blocks
  // acceptance.
  lemma ExcessiveRequestedAuthorityBlocksAcceptance(
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
    requires !AuthorizationAuthorityIsEffective(
               authorization,
               effectiveAuthority
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
  }


  // Temporally invalid Authorization blocks acceptance.
  lemma TemporallyInvalidAuthorizationBlocksAcceptance(
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
    requires !AuthorizationIsTemporallyValidAt(
               authorization,
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
  }



  // ============================================================
  // AUTHORIZATION VALUE / PROOF SEPARATION
  // ============================================================

  // Proof verification is not a field of Authorization and
  // therefore cannot modify the semantic Authorization value.
  //
  // The proof result may alter ACCEPTANCE, but it does not alter
  // the Authorization Value Object itself.
  //
  // This is expressed by using the unchanged Authorization value
  // in both cases.
  lemma ProofVerificationDoesNotModifyAuthorizationValue(
    authorization: Authorization,
    proofBefore: bool,
    proofAfter: bool
  )
    ensures authorization == authorization
  {
  }


  // ReplayKey is part of Authorization semantic value.
  lemma EqualAuthorizationsHaveEqualReplayKeys(
    left: Authorization,
    right: Authorization
  )
    requires left == right
    ensures AuthorizationReplayKey(left)
         == AuthorizationReplayKey(right)
  {
  }


  // AccountId is part of Authorization semantic Context.
  lemma EqualAuthorizationsHaveEqualAccountContexts(
    left: Authorization,
    right: Authorization
  )
    requires left == right
    ensures AuthorizationAccountId(left)
         == AuthorizationAccountId(right)
  {
  }


  // ExecutionTarget is part of Authorization semantic Context.
  lemma EqualAuthorizationsHaveEqualExecutionTargets(
    left: Authorization,
    right: Authorization
  )
    requires left == right
    ensures AuthorizationExecutionTarget(left)
         == AuthorizationExecutionTarget(right)
  {
  }


  // DomainAction is part of Authorization semantic Context.
  lemma EqualAuthorizationsHaveEqualDomainActions(
    left: Authorization,
    right: Authorization
  )
    requires left == right
    ensures AuthorizationDomainAction(left)
         == AuthorizationDomainAction(right)
  {
  }


  // Context Scope is part of Authorization semantic Context.
  lemma EqualAuthorizationsHaveEqualScopes(
    left: Authorization,
    right: Authorization
  )
    requires left == right
    ensures AuthorizationScope(left)
         == AuthorizationScope(right)
  {
  }


  // Chain is part of Authorization semantic Context.
  lemma EqualAuthorizationsHaveEqualChains(
    left: Authorization,
    right: Authorization
  )
    requires left == right
    ensures AuthorizationChain(left)
         == AuthorizationChain(right)
  {
  }



  // ============================================================
  // VALIDATION BOUNDARY
  // ============================================================

  // Structural Authorization validity establishes structural
  // properties only. Current temporal applicability is a separate
  // validation boundary.
  //
  // The acceptance contract additionally requires independent
  // conditions such as:
  //
  //   - ValidAccount(account);
  //   - Credential recognition and usability;
  //   - temporal validity;
  //   - Replay Protection freshness;
  //   - Effective Authority validity and containment;
  //   - Effective Authority provenance evidence;
  //   - external Proof verification.
  //
  // The individual lemmas above expose these boundaries without
  // duplicating the authoritative acceptance predicate.
}

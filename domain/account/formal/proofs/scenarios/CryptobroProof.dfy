// ============================================================
// KIPIO ACCOUNT DOMAIN
// SCENARIO — CRYPTOBRO PROOF
// ============================================================
//
// Adversarial replay scenario.
//
// Primary boundary:
//
//     an Authorization accepted once
//         cannot be accepted again
//         after its replay protection has been consumed.
//
// This scenario is distinct from:
//
//   - DeFi:
//       EffectiveAuthority provenance.
//
//   - Enterprise:
//       transitive delegation non-expansion.
//
// Cryptobro attacks:
//
//     Authorization A
//          |
//          | replayKey = K
//          v
//     first acceptance
//          |
//          v
//     K consumed
//          |
//          v
//     second acceptance of A
//
// Expected:
//
//     second acceptance is impossible.
//
// ------------------------------------------------------------
//
// DOMAIN BOUNDARY
//
// Replay.dfy defines:
//
//     ConsumeAuthorizationReplayKey(S, A)
//         =
//     S + { replayKey(A) }
//
// AuthorizationValidation.dfy defines:
//
//     AuthorizationCanBeAccepted
//
// and requires:
//
//     replayKey(A) notin consumedReplayKeys
//
// Authorization Validation is observational with respect to
// replay state. It does not itself mutate the Account.
//
// AccountTransitions.dfy defines the operational Account
// transition:
//
//     ConsumeReplayKey(account, replayKey)
//
// which records the consumed replay key while preserving the
// remaining Authorization State.
//
// AuthorizationAcceptanceTransition.dfy defines the explicit
// bridge:
//
//     AuthorizationCanBeAccepted
//          |
//          v
//     AcceptedAuthorizationTransitionExists
//          |
//          v
//     ConsumeReplayKey(
//         before,
//         ReplayKeyOfAuthorization(authorization)
//     )
//          |
//          v
//     resulting Account
//
// Therefore the complete replay boundary is:
//
//     semantic acceptance
//          +
//     operational replay consumption
//          +
//     resulting post-state
//          =>
//     second acceptance is impossible.
//
// ============================================================


include "../../foundation/DomainPrimitives.dfy"
include "../../foundation/Capability.dfy"
include "../../foundation/Restriction.dfy"
include "../../foundation/Scope.dfy"
include "../../foundation/DomainAction.dfy"
include "../../foundation/ExecutionTarget.dfy"
include "../../foundation/Chain.dfy"

include "../../authority/EffectiveAuthority.dfy"
include "../../authority/AuthorizationState.dfy"
include "../../authority/Credential.dfy"
include "../../authority/CredentialAuthority.dfy"
include "../../authority/Session.dfy"
include "../../authority/Delegation.dfy"

include "../../account/Account.dfy"
include "../../account/AccountTransitions.dfy"

include "../../authorization/Authorization.dfy"
include "../../authorization/Replay.dfy"
include "../../authorization/AuthorizationValidation.dfy"
include "../../authorization/AuthorizationAcceptanceTransition.dfy"

include "../../laws/AuthorizationLaws.dfy"

include "../isolated/AuthorizationProofs.dfy"


module KipioAccountCryptobroProof
{
  import opened KipioAccountDomainPrimitives
  import opened KipioAccountCapability
  import opened KipioAccountRestriction
  import opened KipioAccountScope
  import opened KipioAccountDomainAction
  import opened KipioAccountExecutionTarget
  import opened KipioAccountChain

  import opened KipioAccountEffectiveAuthority
  import opened KipioAccountAuthorizationState

  import opened KipioAccountCredential
  import opened KipioAccountCredentialAuthority
  import opened KipioAccountSession
  import opened KipioAccountDelegation

  import opened KipioAccountAccount
  import opened KipioAccountAccountTransitions

  import opened KipioAccountAuthorization
  import opened KipioAccountReplay
  import opened KipioAccountAuthorizationValidation
  import opened KipioAccountAuthorizationAcceptanceTransition
  import opened KipioAccountIdentity


  // ============================================================
  // LEVEL 1 — CONSUMED REPLAY KEY IS NOT FRESH
  // ============================================================

  lemma CryptobroConsumedReplayKeyIsNotFresh(
    authorization: Authorization,
    replayState: ReplayState
  )
    requires ReplayKeyOfAuthorization(authorization)
             in replayState
    ensures !AuthorizationReplayKeyIsFresh(
              authorization,
              replayState
            )
  {
    assert !(
        ReplayKeyOfAuthorization(authorization)
        !in replayState
      );
  }


  // ============================================================
  // LEVEL 2 — SEMANTIC CONSUMPTION RECORDS THE KEY
  // ============================================================

  lemma CryptobroConsumptionRecordsAuthorizationReplayKey(
    authorization: Authorization,
    replayState: ReplayState
  )
    ensures ReplayKeyOfAuthorization(authorization)
            in ConsumeAuthorizationReplayKey(
                 replayState,
                 authorization
               )
  {
    assert ReplayKeyOfAuthorization(authorization)
           in replayState
              + { ReplayKeyOfAuthorization(authorization) };
  }


  // ============================================================
  // LEVEL 3 — CONSUMPTION DESTROYS FRESHNESS
  // ============================================================

  lemma CryptobroConsumptionDestroysReplayFreshness(
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
    var consumedState :=
      ConsumeAuthorizationReplayKey(
        replayState,
        authorization
      );

    assert ReplayKeyOfAuthorization(authorization)
           in consumedState;

    assert !AuthorizationReplayKeyIsFresh(
        authorization,
        consumedState
      );
  }


  // ============================================================
  // LEVEL 4 — REPLAY CONSUMPTION IS MONOTONIC
  // ============================================================

  lemma CryptobroReplayConsumptionIsMonotonic(
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
    assert replayState
           <=
           replayState
           + { ReplayKeyOfAuthorization(authorization) };
  }


  // A replay key already present in the state cannot disappear
  // when another Authorization is consumed.

  lemma CryptobroConsumedReplayKeyCannotBeUnconsumed(
    firstAuthorization: Authorization,
    secondAuthorization: Authorization,
    replayState: ReplayState
  )
    requires ReplayKeyOfAuthorization(firstAuthorization)
             in replayState
    ensures ReplayKeyOfAuthorization(firstAuthorization)
            in ConsumeAuthorizationReplayKey(
                 replayState,
                 secondAuthorization
               )
  {
    assert ReplayKeyOfAuthorization(firstAuthorization)
           in replayState;

    assert ReplayKeyOfAuthorization(firstAuthorization)
           in replayState
              + { ReplayKeyOfAuthorization(secondAuthorization) };
  }


  // ============================================================
  // LEVEL 5 — ACCEPTANCE REQUIRES FRESHNESS
  // ============================================================

  lemma CryptobroAcceptedAuthorizationRequiresUnconsumedReplayKey(
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
    ensures ReplayKeyOfAuthorization(authorization)
            !in StateConsumedReplayKeys(
              AccountAuthorizationState(account)
            )
  {
    assert AuthorizationReplayIsFresh(
        authorization,
        AccountAuthorizationState(account)
      );

    assert ReplayKeyOfAuthorization(authorization)
      !in StateConsumedReplayKeys(
        AccountAuthorizationState(account)
      );
  }


  // ============================================================
  // LEVEL 6 — CONSUMED KEY BLOCKS ACCEPTANCE
  // ============================================================

  lemma CryptobroConsumedReplayKeyBlocksAcceptance(
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
    requires ReplayKeyOfAuthorization(authorization)
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
      assert AuthorizationReplayIsFresh(
          authorization,
          AccountAuthorizationState(account)
        );

      assert ReplayKeyOfAuthorization(authorization)
        !in StateConsumedReplayKeys(
          AccountAuthorizationState(account)
        );

      assert false;
    }
  }


  // ============================================================
  // LEVEL 7 — CORE SECOND-SUBMISSION ATTACK
  // ============================================================

  lemma CryptobroSecondSubmissionIsRejected(
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
    requires ReplayKeyOfAuthorization(authorization)
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
    CryptobroConsumedReplayKeyBlocksAcceptance(
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


  // ============================================================
  // LEVEL 8 — DIFFERENT PROOF CANNOT BYPASS REPLAY
  // ============================================================

  // Proof is external to the semantic Authorization value.
  //
  // Even when a different proof-verification result is supplied,
  // a consumed replay key still blocks acceptance.

  lemma CryptobroDifferentProofCannotBypassConsumedReplayKey(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp
  )
    requires ReplayKeyOfAuthorization(authorization)
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
              false
            )
  {
    CryptobroConsumedReplayKeyBlocksAcceptance(
      authorization,
      account,
      effectiveAuthority,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      now,
      false
    );
  }


  // Same semantic Authorization necessarily carries the same
  // replay key.

  lemma CryptobroSameAuthorizationHasSameReplayKey(
    authorizationA: Authorization,
    authorizationB: Authorization
  )
    requires authorizationA == authorizationB
    ensures AuthorizationReplayKey(authorizationA)
            ==
            AuthorizationReplayKey(authorizationB)
  {
    assert AuthorizationReplayKey(authorizationA)
           ==
           AuthorizationReplayKey(authorizationB);
  }


  // ============================================================
  // LEVEL 9 — ACCEPTANCE AND CONSUMED REPLAY KEY ARE
  //           INCOMPATIBLE
  // ============================================================

  lemma CryptobroAcceptanceAndConsumedReplayKeyAreIncompatible(
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
    requires ReplayKeyOfAuthorization(authorization)
             in StateConsumedReplayKeys(
                  AccountAuthorizationState(account)
                )
    ensures false
  {
    CryptobroConsumedReplayKeyBlocksAcceptance(
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

    assert false;
  }


  // ============================================================
  // LEVEL 10 — VALIDATION DOES NOT CONSUME STATE
  // ============================================================

  // Authorization validation is observational with respect to
  // consumed replay state. It does not perform the transition
  // that inserts the replay key.

  lemma CryptobroValidationDoesNotConsumeReplayKey(
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
    ensures StateConsumedReplayKeys(
              AccountAuthorizationState(account)
            )
            ==
            StateConsumedReplayKeys(
              AccountAuthorizationState(account)
            )
  {
    assert StateConsumedReplayKeys(
        AccountAuthorizationState(account)
      )
           ==
           StateConsumedReplayKeys(
             AccountAuthorizationState(account)
           );
  }


  // ============================================================
  // LEVEL 11 — EXISTING ACCOUNT TRANSITIONS PRESERVE
  //           REPLAY STATE
  // ============================================================

  lemma CryptobroRegisterCredentialPreservesReplayState(
    account: Account,
    credential: Credential
  )
    requires ValidAccount(account)
    requires ValidCredential(credential)
    requires !CredentialIdRecognizedInState(
               AccountAuthorizationState(account),
               CredentialId(credential)
             )
    ensures StateConsumedReplayKeys(
              AccountAuthorizationState(
                RegisterCredential(
                  account,
                  credential
                )
              )
            )
            ==
            StateConsumedReplayKeys(
              AccountAuthorizationState(account)
            )
  {
    assert StateConsumedReplayKeys(
        AccountAuthorizationState(
          RegisterCredential(
            account,
            credential
          )
        )
      )
           ==
           StateConsumedReplayKeys(
             AccountAuthorizationState(account)
           );
  }


  lemma CryptobroRegisterSessionPreservesReplayState(
    account: Account,
    session: Session
  )
    requires ValidAccount(account)
    requires ValidSession(session)
    requires !SessionIdRecognizedInState(
               AccountAuthorizationState(account),
               SessionId(session)
             )
    requires CredentialIdRecognizedInState(
               AccountAuthorizationState(account),
               SessionCredentialId(session)
             )
    requires SessionAuthorityWithinCredentialAuthority(
               session,
               StateCredentialAuthorities(
                 AccountAuthorizationState(account)
               )[SessionCredentialId(session)]
             )
    ensures StateConsumedReplayKeys(
              AccountAuthorizationState(
                RegisterSession(
                  account,
                  session
                )
              )
            )
            ==
            StateConsumedReplayKeys(
              AccountAuthorizationState(account)
            )
  {
    assert StateConsumedReplayKeys(
        AccountAuthorizationState(
          RegisterSession(
            account,
            session
          )
        )
      )
           ==
           StateConsumedReplayKeys(
             AccountAuthorizationState(account)
           );
  }


  lemma CryptobroSetCredentialAuthorityPreservesReplayState(
    account: Account,
    credential: Credential,
    authority: CredentialAuthority
  )
    requires ValidAccount(account)
    requires ValidCredentialAuthority(authority)
    requires CredentialRecognizedInState(
               AccountAuthorizationState(account),
               credential
             )
    requires ExistingSessionsRemainWithinCredentialAuthority(
               AccountAuthorizationState(account),
               CredentialId(credential),
               authority
             )
    ensures StateConsumedReplayKeys(
              AccountAuthorizationState(
                SetCredentialAuthority(
                  account,
                  credential,
                  authority
                )
              )
            )
            ==
            StateConsumedReplayKeys(
              AccountAuthorizationState(account)
            )
  {
    assert StateConsumedReplayKeys(
        AccountAuthorizationState(
          SetCredentialAuthority(
            account,
            credential,
            authority
          )
        )
      )
           ==
           StateConsumedReplayKeys(
             AccountAuthorizationState(account)
           );
  }


  lemma CryptobroUpdateCredentialStatusPreservesReplayState(
    account: Account,
    credential: Credential,
    status: CredentialStatus
  )
    requires ValidAccount(account)
    requires credential
             in StateCredentials(
                  AccountAuthorizationState(account)
                )
    requires ValidCredentialStatusTransition(
               credential,
               status
             )
    ensures StateConsumedReplayKeys(
              AccountAuthorizationState(
                UpdateCredentialStatus(
                  account,
                  credential,
                  status
                )
              )
            )
            ==
            StateConsumedReplayKeys(
              AccountAuthorizationState(account)
            )
  {
    assert StateConsumedReplayKeys(
        AccountAuthorizationState(
          UpdateCredentialStatus(
            account,
            credential,
            status
          )
        )
      )
           ==
           StateConsumedReplayKeys(
             AccountAuthorizationState(account)
           );
  }


  lemma CryptobroUpdateSessionStatusPreservesReplayState(
    account: Account,
    session: Session,
    status: SessionStatus
  )
    requires ValidAccount(account)
    requires session
             in StateSessions(
                  AccountAuthorizationState(account)
                )
    requires ValidSessionStatusTransition(
               session,
               status
             )
    ensures StateConsumedReplayKeys(
              AccountAuthorizationState(
                UpdateSessionStatus(
                  account,
                  session,
                  status
                )
              )
            )
            ==
            StateConsumedReplayKeys(
              AccountAuthorizationState(account)
            )
  {
    assert StateConsumedReplayKeys(
        AccountAuthorizationState(
          UpdateSessionStatus(
            account,
            session,
            status
          )
        )
      )
           ==
           StateConsumedReplayKeys(
             AccountAuthorizationState(account)
           );
  }


  lemma CryptobroRegisterDelegationPreservesReplayState(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: EffectiveAuthority
  )
    requires ValidRootDelegationRegistration(
               account,
               delegation,
               delegateCapability,
               delegatableAuthority,
               sourceEffectiveAuthority
             )
    ensures StateConsumedReplayKeys(
              AccountAuthorizationState(
                RegisterDelegation(
                  account,
                  delegation,
                  delegateCapability,
                  delegatableAuthority,
                  sourceEffectiveAuthority
                )
              )
            )
            ==
            StateConsumedReplayKeys(
              AccountAuthorizationState(account)
            )
  {
    assert StateConsumedReplayKeys(
        AccountAuthorizationState(
          RegisterDelegation(
            account,
            delegation,
            delegateCapability,
            delegatableAuthority,
            sourceEffectiveAuthority
          )
        )
      )
           ==
           StateConsumedReplayKeys(
             AccountAuthorizationState(account)
           );
  }


  lemma CryptobroRegisterTransitiveDelegationPreservesReplayState(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: EffectiveAuthority,
    parentDelegationIds: set<Id>,
    identities: set<Identity>
  )
    requires ValidTransitiveDelegationRegistration(
               account,
               delegation,
               delegateCapability,
               delegatableAuthority,
               sourceEffectiveAuthority,
               parentDelegationIds,
               identities
             )
    ensures StateConsumedReplayKeys(
              AccountAuthorizationState(
                RegisterTransitiveDelegation(
                  account,
                  delegation,
                  delegateCapability,
                  delegatableAuthority,
                  sourceEffectiveAuthority,
                  parentDelegationIds,
                  identities
                )
              )
            )
            ==
            StateConsumedReplayKeys(
              AccountAuthorizationState(account)
            )
  {
    assert StateConsumedReplayKeys(
        AccountAuthorizationState(
          RegisterTransitiveDelegation(
            account,
            delegation,
            delegateCapability,
            delegatableAuthority,
            sourceEffectiveAuthority,
            parentDelegationIds,
            identities
          )
        )
      )
           ==
           StateConsumedReplayKeys(
             AccountAuthorizationState(account)
           );
  }


  lemma CryptobroUpdateDelegationStatusPreservesReplayState(
    account: Account,
    delegation: Delegation,
    status: DelegationStatus
  )
    requires ValidAccount(account)
    requires delegation
             in StateDelegations(
                  AccountAuthorizationState(account)
                )
    requires ValidDelegationStatusTransition(
               delegation,
               status
             )
    ensures StateConsumedReplayKeys(
              AccountAuthorizationState(
                UpdateDelegationStatus(
                  account,
                  delegation,
                  status
                )
              )
            )
            ==
            StateConsumedReplayKeys(
              AccountAuthorizationState(account)
            )
  {
    assert StateConsumedReplayKeys(
        AccountAuthorizationState(
          UpdateDelegationStatus(
            account,
            delegation,
            status
          )
        )
      )
           ==
           StateConsumedReplayKeys(
             AccountAuthorizationState(account)
           );
  }


  // ============================================================
  // LEVEL 12 — OPERATIONAL CONSUMPTION CONTRACT
  // ============================================================

  // AccountTransitions provides the actual operational transition:
  //
  //     ConsumeReplayKey(account, replayKey)
  //
  // Its effect is:
  //
  //     consumedReplayKeys'
  //       =
  //     consumedReplayKeys
  //       +
  //     { replayKey }
  //
  // while all unrelated Authorization State components remain
  // unchanged.

  predicate ReplayConsumptionTransitionHasCorrectEffect(
    before: Account,
    after: Account,
    authorization: Authorization
  )
  {
    StateConsumedReplayKeys(
      AccountAuthorizationState(after)
    )
    ==
    StateConsumedReplayKeys(
      AccountAuthorizationState(before)
    )
    + { ReplayKeyOfAuthorization(authorization) }
  }


  lemma CryptobroOperationalConsumptionClosesReplayBoundary(
    before: Account,
    after: Account,
    authorization: Authorization
  )
    requires ReplayConsumptionTransitionHasCorrectEffect(
               before,
               after,
               authorization
             )
    ensures !AuthorizationReplayKeyIsFresh(
              authorization,
              StateConsumedReplayKeys(
                AccountAuthorizationState(after)
              )
            )
  {
    assert ReplayKeyOfAuthorization(authorization)
           in StateConsumedReplayKeys(
                AccountAuthorizationState(after)
              );

    assert !AuthorizationReplayKeyIsFresh(
        authorization,
        StateConsumedReplayKeys(
          AccountAuthorizationState(after)
        )
      );
  }


  // ============================================================
  // LEVEL 13 — ACCEPTANCE FOLLOWED BY OPERATIONAL CONSUMPTION
  // ============================================================

  // This is the concrete end-to-end replay boundary:
  //
  //     Authorization accepted in BEFORE
  //                +
  //     its fresh replay key is consumed
  //                ↓
  //     AFTER records the replay key
  //                ↓
  //     same Authorization cannot be accepted again.
  //
  // The operational consumption itself is provided by
  // AccountTransitions.

  lemma CryptobroAcceptedAuthorizationThenConsumedCannotBeAcceptedAgain(
    authorization: Authorization,
    accountBefore: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool
  )
    requires ValidAccount(accountBefore)
    requires AuthorizationCanBeAccepted(
               authorization,
               accountBefore,
               effectiveAuthority,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               now,
               proofVerified
             )
    requires ValidReplayKeyConsumption(
               AccountAuthorizationState(accountBefore),
               ReplayKeyOfAuthorization(authorization)
             )
    ensures !AuthorizationCanBeAccepted(
              authorization,
              ConsumeReplayKey(
                accountBefore,
                ReplayKeyOfAuthorization(authorization)
              ),
              effectiveAuthority,
              identities,
              sourceReferences,
              sourceAuthorities,
              contributions,
              now,
              proofVerified
            )
  {
    CryptobroAcceptedAuthorizationRequiresUnconsumedReplayKey(
      authorization,
      accountBefore,
      effectiveAuthority,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      now,
      proofVerified
    );

    ConsumeReplayKeyProvidesReusableTransitionContract(
      accountBefore,
      ReplayKeyOfAuthorization(authorization)
    );

    CryptobroConsumedReplayKeyBlocksAcceptance(
      authorization,
      ConsumeReplayKey(
        accountBefore,
        ReplayKeyOfAuthorization(authorization)
      ),
      effectiveAuthority,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      now,
      proofVerified
    );
  }


  // ============================================================
  // LEVEL 14 — CANONICAL ACCEPTANCE-TRANSITION INTEGRATION
  // ============================================================

  // The dedicated Authorization Acceptance / Transition layer
  // connects semantic acceptance with the actual Account
  // transition.
  //
  // This proof attacks the integration boundary itself:
  //
  //     accepted Authorization
  //            ↓
  //     AcceptedAuthorizationTransitionExists
  //            ↓
  //     after = ConsumeReplayKey(before, replayKey)
  //            ↓
  //     replayKey is no longer fresh
  //            ↓
  //     second acceptance is impossible.
  //
  // Unlike Level 13, which reasons directly about the operational
  // transition, this proof verifies the canonical acceptance/
  // transition relation.

  lemma CryptobroAcceptedAuthorizationTransitionRejectsSecondSubmission(
    authorization: Authorization,
    before: Account,
    after: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool
  )
    requires AcceptedAuthorizationTransitionExists(
               authorization,
               before,
               after,
               effectiveAuthority,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               now,
               proofVerified
             )
    ensures !AuthorizationCanBeAccepted(
              authorization,
              after,
              effectiveAuthority,
              identities,
              sourceReferences,
              sourceAuthorities,
              contributions,
              now,
              proofVerified
            )
  {
    AcceptedAuthorizationTransitionMakesReplayKeyNotFresh(
      authorization,
      before,
      after,
      effectiveAuthority,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      now,
      proofVerified
    );

    assert ReplayKeyOfAuthorization(authorization)
           in StateConsumedReplayKeys(
                AccountAuthorizationState(after)
              );

    CryptobroConsumedReplayKeyBlocksAcceptance(
      authorization,
      after,
      effectiveAuthority,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      now,
      proofVerified
    );
  }


  // ============================================================
  // LEVEL 15 — FINAL REPLAY BOUNDARY
  // ============================================================

  // Once operational state records the consumed replay key,
  // the same Authorization cannot cross the acceptance boundary
  // again.

  lemma CryptobroFinalReplayBoundary(
    authorization: Authorization,
    accountAfterConsumption: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool
  )
    requires ReplayKeyOfAuthorization(authorization)
             in StateConsumedReplayKeys(
                  AccountAuthorizationState(
                    accountAfterConsumption
                  )
                )
    ensures !AuthorizationCanBeAccepted(
              authorization,
              accountAfterConsumption,
              effectiveAuthority,
              identities,
              sourceReferences,
              sourceAuthorities,
              contributions,
              now,
              proofVerified
            )
  {
    CryptobroConsumedReplayKeyBlocksAcceptance(
      authorization,
      accountAfterConsumption,
      effectiveAuthority,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      now,
      proofVerified
    );
  }


  // ============================================================
  // SCENARIO CONCLUSION
  // ============================================================
  //
  // The model establishes:
  //
  //   1. consumed replayKey => not fresh;
  //
  //   2. semantic consumption inserts the replayKey;
  //
  //   3. replay consumption is monotonic;
  //
  //   4. Authorization acceptance requires replay freshness;
  //
  //   5. a consumed replayKey therefore blocks acceptance;
  //
  //   6. changing external Proof evidence cannot bypass replay;
  //
  //   7. existing Account transitions preserve the existing
  //      consumed replay-key set;
  //
  //   8. AccountTransitions provides the operational
  //      ConsumeReplayKey transition;
  //
  //   9. accepted Authorization + operational consumption closes
  //      the second-submission boundary;
  //
  //   10. AuthorizationAcceptanceTransition explicitly connects
  //       semantic acceptance with the operational replay
  //       consumption transition;
  //
  //   11. the canonical acceptance/transition relation therefore
  //       produces a post-state in which the same Authorization
  //       cannot be accepted again.
  //
  // Therefore:
  //
  //     Replay Protection semantics
  //         = formally closed
  //
  //     Replay state transition
  //         = formally closed
  //
  //     Acceptance -> Replay State Consumption
  //         = formally closed
  //
  //     Second-submission attack
  //         = formally rejected
  //
  //     Cryptobro formalization debt
  //         = none identified
}

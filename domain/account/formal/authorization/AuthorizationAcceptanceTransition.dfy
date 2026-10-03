// KIPIO ACCOUNT DOMAIN
// AUTHORIZATION — ACCEPTANCE / TRANSITION
// ============================================================
//
// Authorization Acceptance / Transition connects the semantic
// acceptance decision with the operational Account state transition.
//
// The architectural boundary is:
//
//     AuthorizationCanBeAccepted
//                |
//                v
//     ReplayKeyOfAuthorization
//                |
//                v
//     ConsumeReplayKey
//                |
//                v
//     resulting Account
//
// This file does NOT:
//
//   - calculate Effective Authority;
//   - validate cryptographic Proof;
//   - redefine Authorization validation;
//   - redefine Replay semantics;
//   - reconstruct AuthorizationState directly;
//   - execute a Domain Action;
//   - materialize blockchain execution.
//
// AuthorizationValidation.dfy decides whether an Authorization
// may be accepted.
//
// Replay.dfy defines the semantic meaning of replay consumption.
//
// AccountTransitions.dfy defines how replay consumption changes
// operational Account state.
//
// This file connects those existing contracts.
//
// ------------------------------------------------------------
//
// CORE TRANSITION LAW
//
// For an accepted Authorization:
//
//     after
//       =
//     ConsumeReplayKey(
//         before,
//         ReplayKeyOfAuthorization(authorization)
//     )
//
// Therefore:
//
//     consumedReplayKeys(after)
//       =
//     consumedReplayKeys(before)
//       + { replayKey(authorization) }
//
// No other AuthorizationState component changes.
//
// ------------------------------------------------------------
//
// DEBT BOUNDARY
//
// This file addresses the operational bridge for:
//
//     Acceptance -> Replay State Consumption
//
// EffectiveAuthority provenance is validated by
// AuthorizationValidation.dfy before acceptance reaches this
// transition boundary.
//
// This file does NOT redefine or weaken that validation.
//
// It also does NOT address:
//
//     #3 ExecutionContext completeness
//
// or the pending chain contextuality candidate.
//
// ============================================================


// ============================================================
// IMPORTS
// ============================================================

include "../foundation/DomainPrimitives.dfy"
include "../foundation/Identity.dfy"

include "../authority/AuthorizationState.dfy"
include "../authority/EffectiveAuthority.dfy"

include "../account/Account.dfy"
include "../account/AccountTransitions.dfy"

include "Authorization.dfy"
include "Replay.dfy"
include "AuthorizationValidation.dfy"


module KipioAccountAuthorizationAcceptanceTransition
{
  import opened KipioAccountDomainPrimitives
  import opened KipioAccountIdentity

  import opened KipioAccountAuthorizationState
  import opened KipioAccountEffectiveAuthority

  import opened KipioAccountAccount
  import opened KipioAccountAccountTransitions

  import opened KipioAccountAuthorization
  import opened KipioAccountReplay
  import opened KipioAccountAuthorizationValidation
  import opened KipioAccountCapability


  // ============================================================
  // ACCEPTANCE PRECONDITION
  // ============================================================

  // The semantic Authorization acceptance predicate already
  // contains the replay-freshness condition against the pre-state.
  //
  // This helper exposes that specific consequence at the transition
  // boundary without redefining acceptance semantics.

  ghost predicate AcceptedAuthorizationHasFreshReplayKeyInPreState(
    authorization: Authorization,
    before: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool
  )
  {
    AuthorizationCanBeAccepted(
      authorization,
      before,
      effectiveAuthority,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      now,
      proofVerified
    )
    &&
    AuthorizationReplayIsFresh(
      authorization,
      AccountAuthorizationState(before)
    )
  }


  // ============================================================
  // REPLAY CONSUMPTION PRECONDITIONS
  // ============================================================

  // A semantically accepted Authorization provides exactly the
  // operational preconditions required by ConsumeReplayKey:
  //
  //   - the Account is valid;
  //   - the Authorization replay key is a valid Id;
  //   - the replay key is fresh in the Account pre-state.
  //
  // This lemma is the explicit proof bridge between the semantic
  // acceptance contract and the operational transition contract.

  lemma AcceptedAuthorizationProvidesReplayConsumptionPreconditions(
    authorization: Authorization,
    before: Account,
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
               before,
               effectiveAuthority,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               now,
               proofVerified
             )
    ensures ValidAccount(before)
    ensures ValidReplayKeyConsumption(
              AccountAuthorizationState(before),
              ReplayKeyOfAuthorization(authorization)
            )
  {
    assert ValidAccount(before);

    assert ValidAuthorization(authorization);

    KipioAccountReplay.ValidAuthorizationHasValidReplayKey(
      authorization
    );

    assert ValidId(
        ReplayKeyOfAuthorization(authorization)
      );

    assert AuthorizationReplayIsFresh(
        authorization,
        AccountAuthorizationState(before)
      );

    assert ValidReplayKeyConsumption(
        AccountAuthorizationState(before),
        ReplayKeyOfAuthorization(authorization)
      );
  }


  // ============================================================
  // EXPECTED OPERATIONAL RESULT
  // ============================================================

  // The operational result of accepting an Authorization is the
  // existing Account transition that consumes exactly the ReplayKey
  // carried by that Authorization.
  //
  // This predicate deliberately exposes the exact operational
  // preconditions of ConsumeReplayKey.
  //
  // It does not itself decide whether the Authorization is
  // semantically acceptable.
  //
  // That decision remains the responsibility of
  // AuthorizationCanBeAccepted.

  ghost predicate AcceptedAuthorizationExpectedResult(
    authorization: Authorization,
    before: Account,
    after: Account
  )
    requires ValidAccount(before)
    requires ValidReplayKeyConsumption(
               AccountAuthorizationState(before),
               ReplayKeyOfAuthorization(authorization)
             )
  {
    after
    ==
    ConsumeReplayKey(
      before,
      ReplayKeyOfAuthorization(authorization)
    )
  }


  // ============================================================
  // COMPLETE ACCEPTANCE / TRANSITION RELATION
  // ============================================================

  // This is the central bridge relation.
  //
  // Semantic acceptance is evaluated against the PRE-STATE.
  //
  // The relation then exposes the operational preconditions needed
  // by ConsumeReplayKey and fixes the resulting Account to the exact
  // replay-consumption transition.
  //
  // No alternate Account result is admitted.

  ghost predicate AcceptedAuthorizationTransitionExists(
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
  {
    AuthorizationCanBeAccepted(
      authorization,
      before,
      effectiveAuthority,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      now,
      proofVerified
    )
    &&
    ValidAccount(before)
    &&
    ValidReplayKeyConsumption(
      AccountAuthorizationState(before),
      ReplayKeyOfAuthorization(authorization)
    )
    &&
    AcceptedAuthorizationExpectedResult(
      authorization,
      before,
      after
    )
  }


  // ============================================================
  // TRANSITION IDENTITY
  // ============================================================

  lemma AcceptedAuthorizationTransitionPreservesAccountIdentity(
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
    ensures AccountTransitionPreservesIdentity(
              before,
              after
            )
  {
    assert
      after
      ==
      ConsumeReplayKey(
        before,
        ReplayKeyOfAuthorization(authorization)
      );

    ConsumeReplayKeyPreservesIdentity(
      before,
      ReplayKeyOfAuthorization(authorization)
    );
  }


  lemma AcceptedAuthorizationTransitionPreservesAccountId(
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
    ensures AccountIdOf(after)
            ==
            AccountIdOf(before)
  {
    AcceptedAuthorizationTransitionPreservesAccountIdentity(
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

    assert AccountIdOf(before)
           ==
           AccountIdOf(after);

    assert AccountIdOf(after)
           ==
           AccountIdOf(before);
  }


  lemma AcceptedAuthorizationTransitionPreservesSovereignIdentity(
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
    ensures AccountSovereignIdentity(after)
            ==
            AccountSovereignIdentity(before)
  {
    AcceptedAuthorizationTransitionPreservesAccountIdentity(
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

    assert
      AccountSovereignIdentity(before)
      ==
      AccountSovereignIdentity(after);

    assert
      AccountSovereignIdentity(after)
      ==
      AccountSovereignIdentity(before);
  }


  // ============================================================
  // ACCOUNT VALIDITY
  // ============================================================

  // Replay consumption preserves the validity of the Account.

  lemma AcceptedAuthorizationTransitionPreservesAccountValidity(
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
    ensures ValidAccount(after)
  {
    assert
      after
      ==
      ConsumeReplayKey(
        before,
        ReplayKeyOfAuthorization(authorization)
      );

    ConsumeReplayKeyPreservesAccountValidity(
      before,
      ReplayKeyOfAuthorization(authorization)
    );
  }


  // ============================================================
  // EXACT REPLAY STATE UPDATE
  // ============================================================

  // The resulting operational replay state is exactly the semantic
  // replay state obtained by consuming the Authorization's key.

  lemma AcceptedAuthorizationTransitionUpdatesReplayStateExactly(
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
    ensures
      StateConsumedReplayKeys(
        AccountAuthorizationState(after)
      )
      ==
      ConsumeAuthorizationReplayKey(
        StateConsumedReplayKeys(
          AccountAuthorizationState(before)
        ),
        authorization
      )
  {
    assert
      after
      ==
      ConsumeReplayKey(
        before,
        ReplayKeyOfAuthorization(authorization)
      );

    ConsumeReplayKeyUpdatesReplayStateExactly(
      before,
      ReplayKeyOfAuthorization(authorization)
    );

    assert
      StateConsumedReplayKeys(
        AccountAuthorizationState(after)
      )
      ==
      StateConsumedReplayKeys(
        AccountAuthorizationState(before)
      )
      + {
        ReplayKeyOfAuthorization(authorization)
      };

    assert
      ConsumeAuthorizationReplayKey(
        StateConsumedReplayKeys(
          AccountAuthorizationState(before)
        ),
        authorization
      )
      ==
      StateConsumedReplayKeys(
        AccountAuthorizationState(before)
      )
      + {
        ReplayKeyOfAuthorization(authorization)
      };
  }


  // ============================================================
  // EXACTLY ONE NEW REPLAY KEY
  // ============================================================

  lemma AcceptedAuthorizationTransitionConsumesAuthorizationReplayKey(
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
    ensures
      ReplayKeyOfAuthorization(authorization)
      in
        StateConsumedReplayKeys(
          AccountAuthorizationState(after)
        )
  {
    AcceptedAuthorizationTransitionUpdatesReplayStateExactly(
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

    assert
      StateConsumedReplayKeys(
        AccountAuthorizationState(after)
      )
      ==
      StateConsumedReplayKeys(
        AccountAuthorizationState(before)
      )
      + {
        ReplayKeyOfAuthorization(authorization)
      };

    assert
      ReplayKeyOfAuthorization(authorization)
      in
        StateConsumedReplayKeys(
          AccountAuthorizationState(before)
        )
        + {
          ReplayKeyOfAuthorization(authorization)
        };
  }


  // ============================================================
  // PREVIOUSLY CONSUMED KEYS REMAIN CONSUMED
  // ============================================================

  lemma AcceptedAuthorizationTransitionPreservesPreviouslyConsumedReplayKeys(
    authorization: Authorization,
    before: Account,
    after: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool,
    previouslyConsumedKey: ReplayKey
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
    requires
      previouslyConsumedKey
      in
        StateConsumedReplayKeys(
          AccountAuthorizationState(before)
        )
    ensures
      previouslyConsumedKey
      in
        StateConsumedReplayKeys(
          AccountAuthorizationState(after)
        )
  {
    assert
      after
      ==
      ConsumeReplayKey(
        before,
        ReplayKeyOfAuthorization(authorization)
      );

    ConsumeReplayKeyPreservesPreviouslyConsumedKeys(
      before,
      ReplayKeyOfAuthorization(authorization),
      previouslyConsumedKey
    );
  }


  // ============================================================
  // PRE-STATE FRESHNESS
  // ============================================================

  lemma AcceptedAuthorizationTransitionRequiresFreshReplayKey(
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
    ensures
      AuthorizationReplayIsFresh(
        authorization,
        AccountAuthorizationState(before)
      )
  {
    assert
      AuthorizationReplayIsFresh(
        authorization,
        AccountAuthorizationState(before)
      );
  }


  // ============================================================
  // POST-STATE REPLAY PREVENTION
  // ============================================================

  lemma AcceptedAuthorizationTransitionMakesReplayKeyNotFresh(
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
    ensures
      !AuthorizationReplayIsFresh(
        authorization,
        AccountAuthorizationState(after)
      )
  {
    AcceptedAuthorizationTransitionConsumesAuthorizationReplayKey(
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

    assert
      ReplayKeyOfAuthorization(authorization)
      in
        StateConsumedReplayKeys(
          AccountAuthorizationState(after)
        );

    ConsumedAuthorizationReplayKeyIsNotFresh(
      authorization,
      StateConsumedReplayKeys(
        AccountAuthorizationState(after)
      )
    );
  }


  // ============================================================
  // NON-INTERFERENCE WITH OTHER AUTHORIZATION STATE
  // ============================================================

  lemma AcceptedAuthorizationTransitionPreservesCapabilities(
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
    ensures
      StateCapabilities(
        AccountAuthorizationState(after)
      )
      ==
      StateCapabilities(
        AccountAuthorizationState(before)
      )
  {
    assert
      after
      ==
      ConsumeReplayKey(
        before,
        ReplayKeyOfAuthorization(authorization)
      );

    ConsumeReplayKeyPreservesOtherAuthorizationState(
      before,
      ReplayKeyOfAuthorization(authorization)
    );
  }


  lemma AcceptedAuthorizationTransitionPreservesCredentials(
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
    ensures
      StateCredentials(
        AccountAuthorizationState(after)
      )
      ==
      StateCredentials(
        AccountAuthorizationState(before)
      )
  {
    assert
      after
      ==
      ConsumeReplayKey(
        before,
        ReplayKeyOfAuthorization(authorization)
      );

    ConsumeReplayKeyPreservesOtherAuthorizationState(
      before,
      ReplayKeyOfAuthorization(authorization)
    );
  }


  lemma AcceptedAuthorizationTransitionPreservesCredentialAuthorities(
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
    ensures
      StateCredentialAuthorities(
        AccountAuthorizationState(after)
      )
      ==
      StateCredentialAuthorities(
        AccountAuthorizationState(before)
      )
  {
    assert
      after
      ==
      ConsumeReplayKey(
        before,
        ReplayKeyOfAuthorization(authorization)
      );

    ConsumeReplayKeyPreservesOtherAuthorizationState(
      before,
      ReplayKeyOfAuthorization(authorization)
    );
  }


  lemma AcceptedAuthorizationTransitionPreservesSessions(
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
    ensures
      StateSessions(
        AccountAuthorizationState(after)
      )
      ==
      StateSessions(
        AccountAuthorizationState(before)
      )
  {
    assert
      after
      ==
      ConsumeReplayKey(
        before,
        ReplayKeyOfAuthorization(authorization)
      );

    ConsumeReplayKeyPreservesOtherAuthorizationState(
      before,
      ReplayKeyOfAuthorization(authorization)
    );
  }


  lemma AcceptedAuthorizationTransitionPreservesDelegations(
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
    ensures
      StateDelegations(
        AccountAuthorizationState(after)
      )
      ==
      StateDelegations(
        AccountAuthorizationState(before)
      )
  {
    assert
      after
      ==
      ConsumeReplayKey(
        before,
        ReplayKeyOfAuthorization(authorization)
      );

    ConsumeReplayKeyPreservesOtherAuthorizationState(
      before,
      ReplayKeyOfAuthorization(authorization)
    );
  }


  lemma AcceptedAuthorizationTransitionPreservesDelegationProvenance(
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
    ensures
      StateDelegationProvenance(
        AccountAuthorizationState(after)
      )
      ==
      StateDelegationProvenance(
        AccountAuthorizationState(before)
      )
  {
    assert
      after
      ==
      ConsumeReplayKey(
        before,
        ReplayKeyOfAuthorization(authorization)
      );

    ConsumeReplayKeyPreservesOtherAuthorizationState(
      before,
      ReplayKeyOfAuthorization(authorization)
    );
  }


  lemma AcceptedAuthorizationTransitionPreservesRestrictionMap(
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
    ensures
      StateRestrictionMap(
        AccountAuthorizationState(after)
      )
      ==
      StateRestrictionMap(
        AccountAuthorizationState(before)
      )
  {
    assert
      after
      ==
      ConsumeReplayKey(
        before,
        ReplayKeyOfAuthorization(authorization)
      );

    ConsumeReplayKeyPreservesOtherAuthorizationState(
      before,
      ReplayKeyOfAuthorization(authorization)
    );
  }


  lemma AcceptedAuthorizationTransitionPreservesPolicyEffects(
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
    ensures
      StatePolicyEffects(
        AccountAuthorizationState(after)
      )
      ==
      StatePolicyEffects(
        AccountAuthorizationState(before)
      )
  {
    assert
      after
      ==
      ConsumeReplayKey(
        before,
        ReplayKeyOfAuthorization(authorization)
      );

    ConsumeReplayKeyPreservesOtherAuthorizationState(
      before,
      ReplayKeyOfAuthorization(authorization)
    );
  }


  // ============================================================
  // DERIVED RESTRICTION VIEW
  // ============================================================

  // StateRestrictions is derived from the operational restriction
  // map. Replay consumption does not alter that map.

  lemma AcceptedAuthorizationTransitionPreservesRestrictions(
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
    ensures
      StateRestrictions(
        AccountAuthorizationState(after)
      )
      ==
      StateRestrictions(
        AccountAuthorizationState(before)
      )
  {
    AcceptedAuthorizationTransitionPreservesRestrictionMap(
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
  }
}

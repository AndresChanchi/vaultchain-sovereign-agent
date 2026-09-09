// ============================================================
// KIPIO ACCOUNT DOMAIN
// AUTHORIZATION — REPLAY PROTECTION
// ============================================================
//
// Replay Protection defines the domain semantics that prevent an
// Authorization from being accepted again after its replay
// protection value has been consumed.
//
// Replay Protection is part of the semantic value of Authorization.
//
// Authorization therefore carries, as part of its semantic value:
//
//     - Credential reference;
//     - Requested Authority;
//     - Restrictions;
//     - Temporal Conditions;
//     - Replay Protection;
//     - Authorization Context.
//
// Proof is intentionally excluded from semantic Authorization
// equality. Proof is infrastructure evidence used during
// authorization validation.
//
// Authorization remains a Value Object, and replayKey is not an
// Authorization identity.
//
// ------------------------------------------------------------
//
// ROLE OF REPLAY PROTECTION
// ------------------------------------------------------------
//
// Replay Protection answers one specific domain question:
//
//     Has the replay-protection value associated with this
//     Authorization already been consumed in the relevant replay
//     state?
//
// If the answer is yes, the Authorization is no longer replay-fresh.
//
// Replay freshness is therefore one condition of authorization
// acceptance, but it is not equivalent to Authorization validity.
//
// In particular:
//
//     replay freshness
//         !=
//     Authorization validity
//
// A fresh replay key does not by itself establish:
//
//     - valid Proof;
//     - recognized Credential;
//     - usable Credential;
//     - valid Effective Authority;
//     - valid scope;
//     - valid restrictions;
//     - valid temporal conditions;
//     - valid Session;
//     - valid Delegation;
//     - valid execution Context.
//
// These concerns are evaluated by the corresponding parts of the
// authorization and execution domain.
//
// ------------------------------------------------------------
//
// REPLAY KEY
// ------------------------------------------------------------
//
// replayKey is the semantic value used to determine whether an
// Authorization has already been consumed for replay-protection
// purposes.
//
// The domain intentionally does not prescribe the concrete
// mechanism used to produce or transport that value.
//
// A concrete implementation may materialize replay protection as,
// for example:
//
//     - a nonce;
//     - a sequence number;
//     - a counter;
//     - a hash;
//     - a consumption marker;
//     - or another mechanism.
//
// Those are implementation choices.
//
// The domain only requires the semantic property that a consumed
// replayKey is no longer fresh in the corresponding Replay State.
//
// replayKey is NOT:
//
//     - an Authorization identifier;
//     - a Credential identifier;
//     - a Session identifier;
//     - a Delegation identifier;
//     - Proof;
//     - or an Entity identity.
//
// Authorization has no AuthorizationId and no lifecycle in this
// file.
//
// ------------------------------------------------------------
//
// REPLAY STATE
// ------------------------------------------------------------
//
// ReplayState is the abstract semantic state used to represent
// replay keys that have already been consumed.
//
//     ReplayState = set<ReplayKey>
//
// This is a semantic projection, not the operational Account state.
//
// The operational Account state represented by AuthorizationState
// contains the corresponding:
//
//     consumedReplayKeys : set<Id>
//
// Replay.dfy intentionally does not own AuthorizationState or its
// transitions.
//
// The mapping is therefore conceptual:
//
//     ReplayState
//         =
//     abstract replay projection
//
//     AuthorizationState.consumedReplayKeys
//         =
//     operational Account state
//
// The Account domain may use this projection when reasoning about
// replay protection without making Replay.dfy responsible for the
// entire AuthorizationState model.
//
// ------------------------------------------------------------
//
// REPLAY CONSUMPTION
// ------------------------------------------------------------
//
// Consuming the replay protection of an accepted Authorization adds
// its replayKey to ReplayState.
//
// At the semantic level:
//
//     ConsumeAuthorizationReplayKey(S, A)
//         =
//     S ∪ { replayKey(A) }
//
// Consumption is monotonic.
//
// Existing consumed keys remain consumed, and the operation introduces
// no replay key other than the one carried by the Authorization being
// consumed.
//
// Once consumed:
//
//     replayKey(A) ∈ ReplayState
//
// and therefore:
//
//     AuthorizationReplayKeyIsFresh(A, ReplayState)
//
// is false.
//
// This expresses the core replay-protection rule.
//
// ------------------------------------------------------------
//
// RESPONSIBILITY BOUNDARY
// ------------------------------------------------------------
//
// Replay.dfy defines only the semantic replay-protection model:
//
//     - ReplayKey;
//     - ReplayState;
//     - extraction of replayKey from Authorization;
//     - replay freshness;
//     - replay-key consumption;
//     - replay prevention after consumption;
//     - validity of the replay key as part of a structurally valid
//       Authorization;
//     - monotonicity of replay consumption.
//
// Replay.dfy does NOT define:
//
//     - Authorization semantic equality;
//     - Proof equality;
//     - Proof validity;
//     - Authorization validity as a whole;
//     - Effective Authority derivation;
//     - Credential recognition;
//     - Credential usability;
//     - Session validation;
//     - Delegation validation;
//     - policy evaluation;
//     - AuthorizationState;
//     - Account transitions;
//     - authorization decisions;
//     - execution;
//     - nonce or sequence-number format;
//     - cryptographic replay mechanisms;
//     - blockchain-specific replay mechanisms;
//     - storage representation.
//
// Those concerns belong to their corresponding domain concepts.
//
// ------------------------------------------------------------
//
// IMPORTANT DOMAIN DISTINCTIONS
// ------------------------------------------------------------
//
//     replayKey
//         !=
//     Authorization identity
//
//     replayKey
//         !=
//     Proof
//
//     replay freshness
//         !=
//     Authorization validity
//
//     replay consumption
//         !=
//     AuthorizationState transition semantics
//
//     Replay Protection
//         !=
//     Authorization identity
//
// A different Proof does not create a new semantic replay key.
//
// Likewise, changing infrastructure-level evidence does not by
// itself bypass replay protection when the semantic replayKey has
// already been consumed.
//
// ------------------------------------------------------------
//
// RELATION TO AUTHORIZATION
// ------------------------------------------------------------
//
// Replay Protection is part of Authorization's semantic value.
//
// Therefore two Authorization values that differ in replayKey are
// semantically different values, even if their other semantic
// components are identical.
//
// The converse is also important:
//
// replay protection does not determine the complete semantic
// identity of Authorization by itself.
//
// The Authorization Value Object is defined by all of its semantic
// fields, including:
//
//     - Credential reference;
//     - Requested Authority;
//     - Restrictions;
//     - Temporal Conditions;
//     - Replay Protection;
//     - Context.
//
// Proof is not part of that semantic equality.
//
// ------------------------------------------------------------
//
// RELATION TO AUTHORIZATION VALIDATION
// ------------------------------------------------------------
//
// Replay.dfy defines freshness as a reusable semantic condition:
//
//     AuthorizationReplayKeyIsFresh
//
// Authorization Validation is responsible for requiring that
// condition together with the other requirements for acceptance.
//
// Replay.dfy does not decide whether an Authorization should be
// accepted.
//
// In particular, replay freshness alone does not authorize
// execution.
//
// ------------------------------------------------------------
//
// RELATION TO STATE TRANSITIONS
// ------------------------------------------------------------
//
// Replay.dfy models the semantic effect of consuming a replay key,
// but does not define how an Account's complete AuthorizationState
// is transitioned.
//
// The operational transition that records consumption belongs to
// Account / AuthorizationState transition semantics.
//
// Therefore:
//
//     Replay.dfy
//         defines
//     what replay consumption means
//
// while:
//
//     AccountTransitions / AuthorizationState semantics
//         define
//     how that semantic effect becomes part of operational Account
//     state.
//
// ------------------------------------------------------------
//
// DOMAIN INVARIANTS EXPRESSED HERE
// ------------------------------------------------------------
//
// The replay domain preserves the following properties:
//
//     1. A consumed replay key is not fresh.
//
//     2. Consuming an Authorization records its replay key as
//        consumed.
//
//     3. Consumption prevents immediate replay through the same
//        replay key.
//
//     4. Replay State evolves monotonically.
//
//     5. Consuming one replay key does not remove previously
//        consumed replay keys.
//
//     6. A structurally valid Authorization carries a valid replay
//        key.
//
// These are semantic replay rules of the Kipio Account domain.
//
// ============================================================

include "../foundation/DomainPrimitives.dfy"
include "Authorization.dfy"

module KipioAccountReplay
{
  import opened KipioAccountDomainPrimitives
  import opened KipioAccountAuthorization


  // ----------------------------------------------------------
  // REPLAY KEY
  // ----------------------------------------------------------

  // ReplayKey is the semantic value used by Replay Protection to
  // determine whether an Authorization may still be accepted with
  // respect to replay consumption.
  //
  // The concrete representation of the value is intentionally
  // outside the domain model.
  type ReplayKey = Id


  // ----------------------------------------------------------
  // REPLAY STATE
  // ----------------------------------------------------------

  // ReplayState represents the replay keys that have already been
  // consumed.
  //
  // This is the abstract replay projection used by the semantic
  // laws below.
  //
  // It is intentionally distinct from AuthorizationState, even
  // though AuthorizationState contains the operational
  // consumedReplayKeys collection.
  type ReplayState = set<ReplayKey>


  // ----------------------------------------------------------
  // AUTHORIZATION REPLAY KEY
  // ----------------------------------------------------------

  // Returns the replay-protection value carried by an Authorization.
  //
  // replayKey is part of the semantic value of Authorization.
  function ReplayKeyOfAuthorization(
    authorization: Authorization
  ): ReplayKey
  {
    AuthorizationReplayKey(authorization)
  }


  // ----------------------------------------------------------
  // REPLAY FRESHNESS
  // ----------------------------------------------------------

  // An Authorization is replay-fresh exactly when its replay key
  // has not already been consumed in the supplied Replay State.
  //
  // Replay freshness is necessary for replay-safe acceptance but is
  // not sufficient for Authorization validity.
  predicate AuthorizationReplayKeyIsFresh(
    authorization: Authorization,
    replayState: ReplayState
  )
  {
    ReplayKeyOfAuthorization(authorization)
    !in replayState
  }


  // ----------------------------------------------------------
  // REPLAY CONSUMPTION
  // ----------------------------------------------------------

  // Returns the Replay State obtained by consuming the replay key
  // carried by an Authorization.
  //
  // The surrounding authorization semantics are responsible for
  // deciding whether the Authorization is acceptable before its
  // replay key is consumed.
  //
  // This function models only the semantic state effect:
  //
  //     S' = S ∪ { replayKey(A) }
  function ConsumeAuthorizationReplayKey(
    replayState: ReplayState,
    authorization: Authorization
  ): ReplayState
  {
    replayState
    + { ReplayKeyOfAuthorization(authorization) }
  }


  // ----------------------------------------------------------
  // REPLAY STATE LAWS
  // ----------------------------------------------------------

  // A replay key that is already consumed cannot be fresh.
  lemma ConsumedAuthorizationReplayKeyIsNotFresh(
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
  }


  // Consuming an Authorization records its replay key in the
  // resulting Replay State.
  lemma ConsumingAuthorizationMarksReplayKeyConsumed(
    replayState: ReplayState,
    authorization: Authorization
  )
    ensures ReplayKeyOfAuthorization(authorization)
            in ConsumeAuthorizationReplayKey(
                 replayState,
                 authorization
               )
  {
  }


  // ----------------------------------------------------------
  // REPLAY PREVENTION
  // ----------------------------------------------------------

  // After an Authorization's replay key has been consumed, that
  // Authorization is no longer replay-fresh against the resulting
  // Replay State.
  //
  // The rule is expressed entirely in terms of replayKey.
  //
  // It therefore does not depend on Proof equality or on any other
  // infrastructure-level representation of authorization evidence.
  lemma AuthorizationCannotBeReplayedAfterConsumption(
    replayState: ReplayState,
    authorization: Authorization
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


  // ----------------------------------------------------------
  // REPLAY KEY VALIDITY
  // ----------------------------------------------------------

  // A structurally valid Authorization contains a structurally
  // valid replay-protection value.
  //
  // The domain validates the value as an Id but intentionally does
  // not prescribe the concrete replay mechanism.
  lemma ValidAuthorizationHasValidReplayKey(
    authorization: Authorization
  )
    requires ValidAuthorization(authorization)
    ensures ValidId(
              ReplayKeyOfAuthorization(authorization)
            )
  {
  }


  // ----------------------------------------------------------
  // REPLAY STATE MONOTONICITY
  // ----------------------------------------------------------

  // Consuming one Authorization never removes a replay key that was
  // already consumed.
  //
  // Therefore previously consumed replay keys remain consumed.
  lemma ConsumingReplayKeyPreservesPreviousState(
    replayState: ReplayState,
    authorization: Authorization,
    replayKey: ReplayKey
  )
    requires replayKey in replayState
    ensures replayKey
            in ConsumeAuthorizationReplayKey(
                 replayState,
                 authorization
               )
  {
  }


  // ----------------------------------------------------------
  // REPLAY CONSUMPTION IS MONOTONIC
  // ----------------------------------------------------------

  // Replay consumption is monotonic at the set level:
  //
  //     ReplayState_before
  //          ⊆
  //     ReplayState_after
  //
  // and the only newly introduced value is the replay key carried
  // by the consumed Authorization.
  lemma ConsumingReplayKeyIsMonotonic(
    replayState: ReplayState,
    authorization: Authorization
  )
    ensures replayState
            <=
            ConsumeAuthorizationReplayKey(
              replayState,
              authorization
            )
  {
  }
}

// ============================================================
// KIPIO ACCOUNT DOMAIN
// ACCOUNT — ACCOUNT TRANSITIONS
// ============================================================
//
// Account Transitions define valid changes to the operational
// Authorization State of an existing Account.
//
// A transition changes operational state while preserving the
// identity of the Account and its sovereign Identity.
//
// In general, a valid Account transition:
//
//   - preserves AccountId;
//   - preserves the sovereign Identity;
//   - preserves the Entity identity of Credential, Session and
//     Delegation values being updated;
//   - preserves recognition of existing Entities;
//   - preserves the validity of Authorization State;
//   - preserves the authority boundaries defined by the state.
//
// A transition may modify:
//
//   - Capabilities;
//   - recognized Credentials;
//   - Credential Authorities;
//   - Credential lifecycle state;
//   - Sessions;
//   - Delegations;
//   - Delegation provenance;
//   - Restriction associations;
//   - Policy Effects;
//   - consumed Replay Keys.
//
// A transition does NOT:
//
//   - change AccountId;
//   - replace the sovereign Identity;
//   - create a second sovereign Identity;
//   - verify cryptographic Proof;
//   - calculate Effective Authority;
//   - perform final Authorization Validation;
//   - execute a Domain Action;
//   - materialize blockchain execution.
//
// ------------------------------------------------------------
//
// ACCOUNT IDENTITY
// ------------------------------------------------------------
//
// Account is an Entity identified by AccountId.
//
// Every transition defined here constructs a new Account value while
// preserving:
//
//     AccountId
//
// and:
//
//     sovereign Identity
//
// Therefore transitions represent state evolution of the same
// Account Entity rather than creation of a new Account Entity.
//
// The Authorization State belongs to the Account but does not define
// Account identity or sovereignty.
//
// ------------------------------------------------------------
//
// ENTITY LIFECYCLE
// ------------------------------------------------------------
//
// Credential, Session and Delegation are Entities.
//
// Their identity is determined by:
//
//     CredentialId
//     SessionId
//     DelegationId
//
// Lifecycle changes therefore replace the state representation of
// the same Entity rather than introducing a different Entity.
//
// Recognition and lifecycle are distinct:
//
//     Entity identity
//         !=
//     state recognition
//         !=
//     current usability
//
// In particular:
//
//   - Revoked Credentials remain recognized;
//   - Revoked Sessions remain recognized;
//   - Revoked Delegations remain recognized.
//
// Revocation changes usability. It does not delete the Entity from
// Authorization State.
//
// Temporal expiration is derived from time and is not persisted as
// an additional lifecycle state.
//
// ------------------------------------------------------------
//
// ENTITY UPDATE BOUNDARY
// ------------------------------------------------------------
//
// An Entity lifecycle transition must operate on the actual
// recognized Entity value present in Account Authorization State.
//
// In particular, recognizing an Entity by identifier alone is not
// sufficient when the transition reconstructs semantic fields from
// a caller-supplied Entity value.
//
// Therefore:
//
//     actual Entity membership
//         >
//     identifier recognition alone
//
// for lifecycle updates that replace the Entity representation.
//
// This prevents a caller from supplying an arbitrary Entity with an
// already-recognized identifier and causing unrelated semantic
// fields to be replaced while only the lifecycle field is intended
// to change.
//
// ------------------------------------------------------------
//
// CREDENTIAL AUTHORITY AND SESSION AUTHORITY
// ------------------------------------------------------------
//
// Credential Authority is Account-relative.
//
// Authorization State maintains the Credential Authority associated
// with each recognized Credential.
//
// A Session derives authority from its Credential and is therefore
// bounded by that Credential Authority:
//
//     SessionCapabilities
//          ⊆
//     CredentialAuthority
//
// This relation is part of ValidAuthorizationState.
//
// Consequently, transitions that:
//
//   - introduce a Session;
//   - replace a Session;
//   - or replace a Credential Authority
//
// must preserve that relationship.
//
// RegisterSession establishes the relationship when a Session is
// introduced.
//
// SetCredentialAuthority preserves the relationship for Sessions
// already recognized by the Account.
//
// UpdateSessionStatus preserves the Session's capabilities and
// CredentialId, and therefore preserves the same authority boundary.
//
// ------------------------------------------------------------
//
// CREDENTIAL LIFECYCLE
// ------------------------------------------------------------
//
// Credential lifecycle:
//
//     Active
//       ├──► Suspended
//       │      └──► Active
//       └──► Revoked
//
//     Suspended
//       └──► Revoked
//
// Revoked is terminal.
//
// Reaching Revoked does not delete the Credential from
// Authorization State.
//
// A dependent Session does not need to be persistently rewritten
// merely because its Credential becomes invalid.
//
// Instead:
//
//     inactive Credential
//          ↓
//     dependent Session remains recognized
//          ↓
//     Session does not contribute effective authority
//
// This is a usability consequence, not an automatic Session
// lifecycle transition.
//
// ------------------------------------------------------------
//
// SESSION LIFECYCLE
// ------------------------------------------------------------
//
// Session lifecycle:
//
//     Active ─────► Revoked
//
// Revoked is terminal.
//
// Expiration is temporal rather than persistent:
//
//     now > validUntil
//
// therefore does not require a stored "Expired" status.
//
// Changing Session lifecycle status does not change:
//
//   - SessionId;
//   - CredentialId;
//   - SessionCapabilities;
//   - Session validity interval;
//   - Session restrictions.
//
// Consequently the Session's authority boundary remains unchanged.
//
// ------------------------------------------------------------
//
// DELEGATION
// ------------------------------------------------------------
//
// A Delegation has:
//
//     - exactly one source IdentityId;
//     - one Delegatee Subject;
//     - an explicit delegated Capability set;
//     - optional Restrictions;
//     - lifecycle state;
//     - a stable DelegationId.
//
// Delegation provenance is maintained by Authorization State and is
// keyed by DelegationId.
//
// A root Delegation has:
//
//     parentDelegationIds = {}
//
// and therefore its source is required to be the sovereign Identity
// of the Account.
//
// A transitive Delegation explicitly identifies recognized parent
// Delegations.
//
// Parent provenance constrains only the authority derived through
// that delegation chain.
//
// It does NOT imply that every authority available to the source
// Identity originated from those parents.
//
// Independent authority sources may coexist.
//
// ------------------------------------------------------------
//
// DELEGATION AUTHORITY BOUNDARY
// ------------------------------------------------------------
//
// The act of delegation requires the semantic Delegate Capability
// to be available in the source's Effective Authority.
//
// Separately:
//
//     DelegatedAuthority
//         ⊆
//     DelegatableAuthority
//
// and:
//
//     DelegatableAuthority
//         ⊆
//     EffectiveAuthority(source)
//
// This file does not calculate Effective Authority.
//
// Instead, Delegation registration receives explicit authority
// witnesses from its caller and enforces the D1 authority boundary
// at the exact point where the Delegation enters
// AuthorizationState.
//
// For a root Delegation:
//
//     Source = Account Sovereign Identity
//
// For a transitive Delegation:
//
//     Source authority relevant to the new Delegation
//         must be supported by the recognized parent Delegations.
//
// This preserves the architectural boundary:
//
//     EffectiveAuthority
//         = derived authority
//
//     AccountTransitions
//         = enforce supplied authority relation
//
// ------------------------------------------------------------
//
// DELEGATION PROVENANCE
// ------------------------------------------------------------
//
// Authorization State requires provenance to be represented for
// every recognized Delegation.
//
// A valid provenance relation must:
//
//   - belong to a recognized Delegation;
//   - reference only recognized parent Delegations;
//   - avoid direct self-reference;
//   - preserve the delegated authority boundary.
//
// A transitive Delegation cannot receive a Capability that is absent
// from every recognized parent Delegation named by its provenance.
//
// Provenance survives Delegation lifecycle changes because it is
// keyed by the stable DelegationId.
//
// ------------------------------------------------------------
//
// CAPABILITIES
// ------------------------------------------------------------
//
// Account Capability state represents Capabilities available to the
// Account as operational authorization state.
//
// Adding or removing a Capability changes that state value.
//
// It does not by itself imply:
//
//   - Authorization;
//   - Effective Authority;
//   - Credential authorization;
//   - Session authorization;
//   - Delegation authorization;
//   - execution.
//
// No additional dependency between StateCapabilities and Sessions,
// Credential Authorities or Delegations is imposed here because
// those authority sources remain independently represented by the
// domain.
//
// ------------------------------------------------------------
//
// RESTRICTIONS
// ------------------------------------------------------------
//
// Restrictions are Value Objects.
//
// AuthorizationState owns the association:
//
//     (Capability × OptionalPolicyScope) -> Restriction
//
// A Restriction itself does not contain Capability or Scope.
//
// Therefore Account Transitions are responsible for maintaining:
//
//   - target/value association;
//   - replacement semantics;
//   - no orphan restrictions;
//   - restriction cleanup when a Capability is removed.
//
// In particular:
//
//   - SetRestriction replaces or adds one target association;
//   - RemoveCapability removes all RestrictionMap entries whose
//     Capability component is the removed Capability.
//
// The transition layer does not evaluate whether a Restriction is
// satisfied by an execution.
//
// ------------------------------------------------------------
//
// POLICY EFFECTS
// ------------------------------------------------------------
//
// PolicyEffect remains a semantic descriptor.
//
// Account Transitions do not decide:
//
//   - Policy ordering;
//   - Policy applicability;
//   - contradiction detection;
//   - atomic Policy consumption.
//
// Those rules belong to Policy and Authorization State Transition
// semantics.
//
// ------------------------------------------------------------
//
// REPLAY STATE
// ------------------------------------------------------------
//
// Authorization State contains consumedReplayKeys.
//
// Replay semantics themselves are defined by Replay.dfy.
//
// This file does not redefine replay freshness or replay
// consumption.
//
// A transition that changes unrelated authorization state
// preserves the existing consumed replay-key set.
//
// The semantic bridge from an accepted Authorization to replay
// consumption belongs to the corresponding authorization/state
// transition boundary and is intentionally not duplicated here.
//
// The operational Account transition for consuming one ReplayKey is
// defined below. It changes only consumedReplayKeys and preserves
// all other AuthorizationState components.
//
// ------------------------------------------------------------
//
// STATE VALIDITY
// ------------------------------------------------------------
//
// A successful Account transition must return an Account whose
// Authorization State remains valid.
//
// Authorization State validity includes the authority boundary:
//
//     SessionCapabilities
//          ⊆
//     CredentialAuthority
//
// for every recognized Session.
//
// It also includes RestrictionMap integrity:
//
//     valid target;
//     valid restriction;
//     target Capability recognized;
//     no orphan restriction association.
//
// Therefore transitions that add, remove, or modify authorization
// state must preserve both classes of invariants.
//
// More generally:
//
//     ValidAccount(before)
//     + valid transition preconditions
//             =>
//     ValidAccount(after)
//
// is the reusable public transition contract.
//
// ------------------------------------------------------------
//
// RESPONSIBILITY BOUNDARY
// ------------------------------------------------------------
//
// This file defines:
//
//   - Account transition identity preservation;
//   - preservation of Account validity;
//   - Credential lifecycle transitions;
//   - Credential registration;
//   - Credential Authority updates;
//   - Session registration;
//   - Session lifecycle transitions;
//   - Capability state transitions;
//   - RestrictionMap state transitions;
//   - ReplayKey state consumption;
//   - Delegation registration;
//   - transitive Delegation registration;
//   - Delegation lifecycle transitions;
//   - preservation of Entity identity;
//   - preservation of state recognition;
//   - preservation of Authorization State validity.
//
// This file does NOT define:
//
//   - Effective Authority calculation;
//   - Authorization decisions;
//   - Proof verification;
//   - cryptographic mechanisms;
//   - Policy evaluation;
//   - final execution authorization;
//   - blockchain execution;
//   - storage representation.
//
// ============================================================


// ============================================================
// IMPORTS
// ============================================================

include "../foundation/DomainPrimitives.dfy"
include "../foundation/Identity.dfy"
include "../foundation/Capability.dfy"
include "../foundation/Restriction.dfy"

include "../authority/AuthorizationState.dfy"
include "../authority/EffectiveAuthority.dfy"
include "../authority/Credential.dfy"
include "../authority/CredentialAuthority.dfy"
include "../authority/Session.dfy"
include "../authority/Delegation.dfy"

include "../authorization/Replay.dfy"

include "Account.dfy"


module KipioAccountAccountTransitions
{
  import opened KipioAccountDomainPrimitives
  import opened KipioAccountIdentity
  import opened KipioAccountCapability
  import opened KipioAccountRestriction
  import opened KipioAccountAuthorizationState
  import opened KipioAccountEffectiveAuthority
  import opened KipioAccountCredential
  import opened KipioAccountCredentialAuthority
  import opened KipioAccountSession
  import opened KipioAccountDelegation
  import opened KipioAccountReplay
  import opened KipioAccountAccount
  import opened KipioAccountPolicyEffect


  // ============================================================
  // TRANSITION IDENTITY BOUNDARY
  // ============================================================

  predicate AccountTransitionPreservesIdentity(
    before: Account,
    after: Account
  )
  {
    AccountIdOf(before) == AccountIdOf(after)
    &&
    AccountSovereignIdentity(before)
    == AccountSovereignIdentity(after)
  }


  lemma AccountTransitionPreservesIdentityLaw(
    before: Account,
    after: Account
  )
    requires AccountTransitionPreservesIdentity(before, after)
    ensures AccountIdOf(before) == AccountIdOf(after)
    ensures AccountSovereignIdentity(before)
         == AccountSovereignIdentity(after)
  {
  }


  lemma ValidTransitionResultFromPreservedIdentityAndState(
    before: Account,
    after: Account
  )
    requires ValidAccount(before)
    requires AccountTransitionPreservesIdentity(
               before,
               after
             )
    requires ValidAuthorizationState(
               AccountAuthorizationState(after)
             )
    ensures ValidAccount(after)
  {
    assert ValidId(AccountIdOf(before));
    assert ValidIdentity(AccountSovereignIdentity(before));

    assert AccountIdOf(before) == AccountIdOf(after);
    assert AccountSovereignIdentity(before)
        == AccountSovereignIdentity(after);

    assert ValidId(AccountIdOf(after));
    assert ValidIdentity(AccountSovereignIdentity(after));

    assert ValidAccount(after);
  }


  // ============================================================
  // CREDENTIAL LIFECYCLE RULES
  // ============================================================

  predicate ValidCredentialStatusTransition(
    credential: Credential,
    newStatus: CredentialStatus
  )
  {
    (CredentialIsActive(credential)
     &&
     (newStatus == CredentialStatus.Active
      || newStatus == CredentialStatus.Suspended
      || newStatus == CredentialStatus.Revoked))
    ||
    (CredentialIsSuspended(credential)
     &&
     (newStatus == CredentialStatus.Active
      || newStatus == CredentialStatus.Suspended
      || newStatus == CredentialStatus.Revoked))
    ||
    (CredentialIsRevoked(credential)
     && newStatus == CredentialStatus.Revoked)
  }


  lemma ValidCredentialStatusTransitionPreservesId(
    credential: Credential,
    newStatus: CredentialStatus
  )
    requires ValidCredentialStatusTransition(
               credential,
               newStatus
             )
    ensures CredentialId(
              Credential(
                CredentialId(credential),
                newStatus
              )
            )
         == CredentialId(credential)
  {
  }


  // ============================================================
  // SESSION LIFECYCLE RULES
  // ============================================================

  predicate ValidSessionStatusTransition(
    session: Session,
    newStatus: SessionStatus
  )
  {
    (SessionIsActive(session)
     &&
     (newStatus == SessionStatus.Active
      || newStatus == SessionStatus.Revoked))
    ||
    (SessionIsRevoked(session)
     && newStatus == SessionStatus.Revoked)
  }


  // ============================================================
  // DELEGATION LIFECYCLE RULES
  // ============================================================

  predicate ValidDelegationStatusTransition(
    delegation: Delegation,
    newStatus: DelegationStatus
  )
  {
    (DelegationIsActive(delegation)
     &&
     (newStatus == DelegationStatus.Active
      || newStatus == DelegationStatus.Revoked))
    ||
    (DelegationIsRevoked(delegation)
     && newStatus == DelegationStatus.Revoked)
  }


  // ============================================================
  // REPLAY STATE CONSUMPTION
  // ============================================================

  predicate ValidReplayKeyConsumption(
    state: AuthorizationState,
    replayKey: ReplayKey
  )
  {
    ValidId(replayKey)
    &&
    replayKey
    !in StateConsumedReplayKeys(state)
  }


  function ConsumeReplayKey(
    account: Account,
    replayKey: ReplayKey
  ): Account
    requires ValidAccount(account)
    requires ValidReplayKeyConsumption(
               AccountAuthorizationState(account),
               replayKey
             )
  {
    var state := AccountAuthorizationState(account);

    Account(
      AccountIdOf(account),
      AccountSovereignIdentity(account),
      AuthorizationState(
        StateCapabilities(state),
        StateCredentials(state),
        StateCredentialAuthorities(state),
        StateSessions(state),
        StateDelegations(state),
        StateDelegationProvenance(state),
        StateRestrictionMap(state),
        StatePolicyEffects(state),
        StateConsumedReplayKeys(state) + { replayKey }
      )
    )
  }


  lemma ConsumeReplayKeyPreservesIdentity(
    account: Account,
    replayKey: ReplayKey
  )
    requires ValidAccount(account)
    requires ValidReplayKeyConsumption(
               AccountAuthorizationState(account),
               replayKey
             )
    ensures AccountTransitionPreservesIdentity(
              account,
              ConsumeReplayKey(
                account,
                replayKey
              )
            )
  {
  }


  lemma ConsumeReplayKeyUpdatesReplayStateExactly(
    account: Account,
    replayKey: ReplayKey
  )
    requires ValidAccount(account)
    requires ValidReplayKeyConsumption(
               AccountAuthorizationState(account),
               replayKey
             )
    ensures
      StateConsumedReplayKeys(
        AccountAuthorizationState(
          ConsumeReplayKey(
            account,
            replayKey
          )
        )
      )
      ==
      StateConsumedReplayKeys(AccountAuthorizationState(account))
      + { replayKey }
  {
  }


  lemma ConsumedReplayKeyIsRecorded(
    account: Account,
    replayKey: ReplayKey
  )
    requires ValidAccount(account)
    requires ValidReplayKeyConsumption(
               AccountAuthorizationState(account),
               replayKey
             )
    ensures
      replayKey
      in
        StateConsumedReplayKeys(
          AccountAuthorizationState(
            ConsumeReplayKey(
              account,
              replayKey
            )
          )
        )
  {
    assert
      StateConsumedReplayKeys(
        AccountAuthorizationState(
          ConsumeReplayKey(
            account,
            replayKey
          )
        )
      )
      ==
      StateConsumedReplayKeys(AccountAuthorizationState(account))
      + { replayKey };

    assert
      replayKey
      in
        StateConsumedReplayKeys(AccountAuthorizationState(account))
        + { replayKey };
  }


  lemma ConsumeReplayKeyPreservesPreviouslyConsumedKeys(
    account: Account,
    replayKey: ReplayKey,
    previouslyConsumedKey: ReplayKey
  )
    requires ValidAccount(account)
    requires ValidReplayKeyConsumption(
               AccountAuthorizationState(account),
               replayKey
             )
    requires
      previouslyConsumedKey
      in
        StateConsumedReplayKeys(
          AccountAuthorizationState(account)
        )
    ensures
      previouslyConsumedKey
      in
        StateConsumedReplayKeys(
          AccountAuthorizationState(
            ConsumeReplayKey(
              account,
              replayKey
            )
          )
        )
  {
    assert
      StateConsumedReplayKeys(
        AccountAuthorizationState(
          ConsumeReplayKey(
            account,
            replayKey
          )
        )
      )
      ==
      StateConsumedReplayKeys(AccountAuthorizationState(account))
      + { replayKey };

    assert
      previouslyConsumedKey
      in
        StateConsumedReplayKeys(AccountAuthorizationState(account))
      + { replayKey };
  }


  lemma ConsumeReplayKeyPreservesReplayStateMonotonicity(
    account: Account,
    replayKey: ReplayKey
  )
    requires ValidAccount(account)
    requires ValidReplayKeyConsumption(
               AccountAuthorizationState(account),
               replayKey
             )
    ensures
      StateConsumedReplayKeys(
        AccountAuthorizationState(account)
      )
      <=
      StateConsumedReplayKeys(
        AccountAuthorizationState(
          ConsumeReplayKey(
            account,
            replayKey
          )
        )
      )
  {
    assert
      StateConsumedReplayKeys(
        AccountAuthorizationState(
          ConsumeReplayKey(
            account,
            replayKey
          )
        )
      )
      ==
      StateConsumedReplayKeys(AccountAuthorizationState(account))
      + { replayKey };
  }


  lemma ConsumeReplayKeyPreservesOtherAuthorizationState(
    account: Account,
    replayKey: ReplayKey
  )
    requires ValidAccount(account)
    requires ValidReplayKeyConsumption(
               AccountAuthorizationState(account),
               replayKey
             )
    ensures
      StateCapabilities(
        AccountAuthorizationState(
          ConsumeReplayKey(account, replayKey)
        )
      )
      ==
      StateCapabilities(AccountAuthorizationState(account))
    ensures
      StateCredentials(
        AccountAuthorizationState(
          ConsumeReplayKey(account, replayKey)
        )
      )
      ==
      StateCredentials(AccountAuthorizationState(account))
    ensures
      StateCredentialAuthorities(
        AccountAuthorizationState(
          ConsumeReplayKey(account, replayKey)
        )
      )
      ==
      StateCredentialAuthorities(AccountAuthorizationState(account))
    ensures
      StateSessions(
        AccountAuthorizationState(
          ConsumeReplayKey(account, replayKey)
        )
      )
      ==
      StateSessions(AccountAuthorizationState(account))
    ensures
      StateDelegations(
        AccountAuthorizationState(
          ConsumeReplayKey(account, replayKey)
        )
      )
      ==
      StateDelegations(AccountAuthorizationState(account))
    ensures
      StateDelegationProvenance(
        AccountAuthorizationState(
          ConsumeReplayKey(account, replayKey)
        )
      )
      ==
      StateDelegationProvenance(AccountAuthorizationState(account))
    ensures
      StateRestrictionMap(
        AccountAuthorizationState(
          ConsumeReplayKey(account, replayKey)
        )
      )
      ==
      StateRestrictionMap(AccountAuthorizationState(account))
    ensures
      StatePolicyEffects(
        AccountAuthorizationState(
          ConsumeReplayKey(account, replayKey)
        )
      )
      ==
      StatePolicyEffects(AccountAuthorizationState(account))
  {
  }


  lemma ConsumeReplayKeyPreservesAuthorizationStateValidity(
    account: Account,
    replayKey: ReplayKey
  )
    requires ValidAccount(account)
    requires ValidReplayKeyConsumption(
               AccountAuthorizationState(account),
               replayKey
             )
    ensures
      ValidAuthorizationState(
        AccountAuthorizationState(
          ConsumeReplayKey(
            account,
            replayKey
          )
        )
      )
  {
    var before := AccountAuthorizationState(account);

    var after :=
      AccountAuthorizationState(
        ConsumeReplayKey(
          account,
          replayKey
        )
      );

    assert ValidAuthorizationState(before);

    assert ValidCapabilitiesInState(after);
    assert ValidCredentialsInState(after);
    assert CredentialIdsAreUnique(after);

    assert EveryRecognizedCredentialHasAuthority(after);
    assert EveryAuthorityBelongsToRecognizedCredential(after);
    assert CredentialAuthoritiesContainValidAuthorities(after);

    assert ValidSessionsInState(after);
    assert SessionCredentialsBelongToState(after);
    assert SessionIdsAreUnique(after);
    assert SessionAuthoritiesRespectCredentialAuthorities(after);

    assert ValidDelegationsInState(after);
    assert DelegationIdsAreUnique(after);
    assert EveryRecognizedDelegationHasProvenance(after);
    assert EveryDelegationProvenanceBelongsToRecognizedDelegation(after);
    assert ValidDelegationProvenanceInState(after);

    assert ValidRestrictionMapInState(after);

    assert ValidPolicyEffectsInState(after);
    assert ValidReplayState(after);

    assert ValidAuthorizationState(after);
  }


  lemma ConsumeReplayKeyPreservesAccountValidity(
    account: Account,
    replayKey: ReplayKey
  )
    requires ValidAccount(account)
    requires ValidReplayKeyConsumption(
               AccountAuthorizationState(account),
               replayKey
             )
    ensures
      ValidAccount(
        ConsumeReplayKey(
          account,
          replayKey
        )
      )
  {
    var after :=
      ConsumeReplayKey(
        account,
        replayKey
      );

    ConsumeReplayKeyPreservesAuthorizationStateValidity(
      account,
      replayKey
    );

    assert AccountTransitionPreservesIdentity(
        account,
        after
      );

    ValidTransitionResultFromPreservedIdentityAndState(
      account,
      after
    );
  }


  lemma ConsumeReplayKeyProvidesReusableTransitionContract(
    account: Account,
    replayKey: ReplayKey
  )
    requires ValidAccount(account)
    requires ValidReplayKeyConsumption(
               AccountAuthorizationState(account),
               replayKey
             )
    ensures
      ValidAccount(
        ConsumeReplayKey(
          account,
          replayKey
        )
      )
    ensures
      AccountTransitionPreservesIdentity(
        account,
        ConsumeReplayKey(
          account,
          replayKey
        )
      )
    ensures
      StateConsumedReplayKeys(
        AccountAuthorizationState(
          ConsumeReplayKey(
            account,
            replayKey
          )
        )
      )
      ==
      StateConsumedReplayKeys(AccountAuthorizationState(account))
      + { replayKey }
    ensures
      replayKey
      in
        StateConsumedReplayKeys(
          AccountAuthorizationState(
            ConsumeReplayKey(
              account,
              replayKey
            )
          )
        )
  {
    ConsumeReplayKeyPreservesAuthorizationStateValidity(
      account,
      replayKey
    );

    ConsumeReplayKeyPreservesAccountValidity(
      account,
      replayKey
    );

    ConsumeReplayKeyPreservesIdentity(
      account,
      replayKey
    );

    ConsumeReplayKeyUpdatesReplayStateExactly(
      account,
      replayKey
    );

    ConsumedReplayKeyIsRecorded(
      account,
      replayKey
    );
  }


  // ============================================================
  // RESTRICTION MAP HELPERS
  // ============================================================

  function RemoveRestrictionsForCapability(
    restrictionMap: RestrictionMap,
    capability: Capability
  ): RestrictionMap
  {
    map target : RestrictionTarget
      | target in restrictionMap.Keys
        && RestrictionTargetCapability(target) != capability
      :: restrictionMap[target]
  }


  function RemoveRestrictionTarget(
    restrictionMap: RestrictionMap,
    capability: Capability,
    scope: OptionalPolicyScope
  ): RestrictionMap
  {
    var target :=
      RestrictionTarget(
        capability,
        scope
      );

    map existingTarget : RestrictionTarget
      | existingTarget in restrictionMap.Keys
        && existingTarget != target
      :: restrictionMap[existingTarget]
  }


  function SetRestrictionInMap(
    restrictionMap: RestrictionMap,
    capability: Capability,
    scope: OptionalPolicyScope,
    restriction: Restriction
  ): RestrictionMap
  {
    restrictionMap[
      RestrictionTarget(
        capability,
        scope
      ) := restriction]
  }


  // ============================================================
  // RESTRICTION MAP INTEGRITY
  // ============================================================

  lemma RestrictionMapAfterCapabilityRemovalContainsOnlyRemainingCapabilities(
    account: Account,
    capability: Capability
  )
    requires ValidAccount(account)
    ensures
      forall target ::
        target
        in RemoveRestrictionsForCapability(
             StateRestrictionMap(
               AccountAuthorizationState(account)
             ),
             capability
           ).Keys
        ==>
          RestrictionTargetCapability(target)
          in StateCapabilities(
               AccountAuthorizationState(account)
             )
          &&
          RestrictionTargetCapability(target)
          != capability
  {
  }


  lemma RestrictionMapAfterCapabilityRemovalPreservesValidTargets(
    account: Account,
    capability: Capability
  )
    requires ValidAccount(account)
    ensures
      forall target ::
        target
        in RemoveRestrictionsForCapability(
             StateRestrictionMap(
               AccountAuthorizationState(account)
             ),
             capability
           ).Keys
        ==>
          ValidRestrictionTarget(target)
  {
    var state := AccountAuthorizationState(account);
    var originalMap := StateRestrictionMap(state);
    var updatedMap :=
      RemoveRestrictionsForCapability(
        originalMap,
        capability
      );

    forall target
      | target in updatedMap.Keys
      ensures ValidRestrictionTarget(target)
    {
      if target in originalMap.Keys {
        assert ValidRestrictionTargetsInState(state);
        assert ValidRestrictionTarget(target);
      }
    }
  }


  lemma RestrictionMapAfterCapabilityRemovalPreservesValidValues(
    account: Account,
    capability: Capability
  )
    requires ValidAccount(account)
    ensures
      forall target ::
        target
        in RemoveRestrictionsForCapability(
             StateRestrictionMap(
               AccountAuthorizationState(account)
             ),
             capability
           ).Keys
        ==>
          ValidRestriction(
            RemoveRestrictionsForCapability(
              StateRestrictionMap(
                AccountAuthorizationState(account)
              ),
              capability
            )[target]
          )
  {
    var state := AccountAuthorizationState(account);
    var originalMap := StateRestrictionMap(state);
    var updatedMap :=
      RemoveRestrictionsForCapability(
        originalMap,
        capability
      );

    forall target
      | target in updatedMap.Keys
      ensures ValidRestriction(
                updatedMap[target]
              )
    {
      if target in originalMap.Keys {
        assert ValidRestrictionValuesInState(state);
        assert ValidRestriction(originalMap[target]);
        assert updatedMap[target] == originalMap[target];
      }
    }
  }


  lemma RestrictionMapAfterCapabilityRemovalHasNoOrphans(
    account: Account,
    capability: Capability
  )
    requires ValidAccount(account)
    ensures
      forall target ::
        target
        in RemoveRestrictionsForCapability(
             StateRestrictionMap(
               AccountAuthorizationState(account)
             ),
             capability
           ).Keys
        ==>
          RestrictionTargetCapability(target)
          in
            StateCapabilities(
              AccountAuthorizationState(account)
            ) - { capability }
  {
    var state := AccountAuthorizationState(account);
    var originalMap := StateRestrictionMap(state);
    var updatedMap :=
      RemoveRestrictionsForCapability(
        originalMap,
        capability
      );

    forall target
      | target in updatedMap.Keys
      ensures
        RestrictionTargetCapability(target)
        in StateCapabilities(state) - { capability }
    {
      assert target in originalMap.Keys;
      assert RestrictionTargetCapability(target) != capability;

      assert RestrictionTargetCapability(target)
             in StateCapabilities(state);

      assert
        RestrictionTargetCapability(target)
        in StateCapabilities(state) - { capability };
    }
  }


  // ============================================================
  // CREDENTIAL REGISTRATION
  // ============================================================

  function RegisterCredential(
    account: Account,
    credential: Credential
  ): Account
    requires ValidAccount(account)
    requires ValidCredential(credential)
    requires !CredentialIdRecognizedInState(
               AccountAuthorizationState(account),
               CredentialId(credential)
             )
  {
    var state := AccountAuthorizationState(account);

    Account(
      AccountIdOf(account),
      AccountSovereignIdentity(account),
      AuthorizationState(
        StateCapabilities(state),
        StateCredentials(state) + { credential },
        StateCredentialAuthorities(state)
          [CredentialId(credential) := {}],
        StateSessions(state),
        StateDelegations(state),
        StateDelegationProvenance(state),
        StateRestrictionMap(state),
        StatePolicyEffects(state),
        StateConsumedReplayKeys(state)
      )
    )
  }


  lemma RegisterCredentialPreservesIdentity(
    account: Account,
    credential: Credential
  )
    requires ValidAccount(account)
    requires ValidCredential(credential)
    requires !CredentialIdRecognizedInState(
               AccountAuthorizationState(account),
               CredentialId(credential)
             )
    ensures AccountTransitionPreservesIdentity(
              account,
              RegisterCredential(account, credential)
            )
  {
  }


  lemma RegisteredCredentialBelongsToState(
    account: Account,
    credential: Credential
  )
    requires ValidAccount(account)
    requires ValidCredential(credential)
    requires !CredentialIdRecognizedInState(
               AccountAuthorizationState(account),
               CredentialId(credential)
             )
    ensures CredentialIdRecognizedInState(
              AccountAuthorizationState(
                RegisterCredential(account, credential)
              ),
              CredentialId(credential)
            )
  {
  }


  lemma RegisteredCredentialHasEmptyAuthority(
    account: Account,
    credential: Credential
  )
    requires ValidAccount(account)
    requires ValidCredential(credential)
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
  }


  lemma RegisterCredentialPreservesAuthorizationStateValidity(
    account: Account,
    credential: Credential
  )
    requires ValidAccount(account)
    requires ValidCredential(credential)
    requires !CredentialIdRecognizedInState(
               AccountAuthorizationState(account),
               CredentialId(credential)
             )
    ensures ValidAuthorizationState(
              AccountAuthorizationState(
                RegisterCredential(account, credential)
              )
            )
  {
    var before := AccountAuthorizationState(account);
    var after := AccountAuthorizationState(
      RegisterCredential(account, credential)
    );

    assert ValidAuthorizationState(before);

    assert ValidCapabilitiesInState(after);
    assert ValidCredentialsInState(after);
    assert CredentialIdsAreUnique(after);

    assert EveryRecognizedCredentialHasAuthority(after);
    assert EveryAuthorityBelongsToRecognizedCredential(after);
    assert CredentialAuthoritiesContainValidAuthorities(after);

    assert ValidSessionsInState(after);
    assert SessionCredentialsBelongToState(after);
    assert SessionIdsAreUnique(after);
    assert SessionAuthoritiesRespectCredentialAuthorities(after);

    assert ValidDelegationsInState(after);
    assert DelegationIdsAreUnique(after);
    assert EveryRecognizedDelegationHasProvenance(after);
    assert EveryDelegationProvenanceBelongsToRecognizedDelegation(after);
    assert ValidDelegationProvenanceInState(after);

    assert ValidRestrictionMapInState(after);

    assert ValidPolicyEffectsInState(after);
    assert ValidReplayState(after);

    assert ValidAuthorizationState(after);
  }


  lemma RegisterCredentialPreservesAccountValidity(
    account: Account,
    credential: Credential
  )
    requires ValidAccount(account)
    requires ValidCredential(credential)
    requires !CredentialIdRecognizedInState(
               AccountAuthorizationState(account),
               CredentialId(credential)
             )
    ensures ValidAccount(
              RegisterCredential(account, credential)
            )
  {
    var after := RegisterCredential(
      account,
      credential
    );

    RegisterCredentialPreservesAuthorizationStateValidity(
      account,
      credential
    );

    assert AccountTransitionPreservesIdentity(
        account,
        after
      );

    ValidTransitionResultFromPreservedIdentityAndState(
      account,
      after
    );
  }


  lemma RegisterCredentialProvidesReusableTransitionContract(
    account: Account,
    credential: Credential
  )
    requires ValidAccount(account)
    requires ValidCredential(credential)
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
    ensures CredentialIdRecognizedInState(
              AccountAuthorizationState(
                RegisterCredential(account, credential)
              ),
              CredentialId(credential)
            )
    ensures StateCredentialAuthority(
              AccountAuthorizationState(
                RegisterCredential(account, credential)
              ),
              credential
            ) == {}
  {
    RegisterCredentialPreservesAuthorizationStateValidity(
      account,
      credential
    );

    RegisterCredentialPreservesAccountValidity(
      account,
      credential
    );

    RegisterCredentialPreservesIdentity(
      account,
      credential
    );

    RegisteredCredentialBelongsToState(
      account,
      credential
    );

    RegisteredCredentialHasEmptyAuthority(
      account,
      credential
    );
  }


  // ============================================================
  // CREDENTIAL AUTHORITY
  // ============================================================

  predicate ExistingSessionsRemainWithinCredentialAuthority(
    state: AuthorizationState,
    credentialId: Id,
    authority: CredentialAuthority
  )
  {
    forall session ::
      session in StateSessions(state)
      && SessionCredentialId(session) == credentialId
      ==>
        SessionAuthorityWithinCredentialAuthority(
          session,
          authority
        )
  }


  predicate ValidCredentialAuthorityUpdate(
    state: AuthorizationState,
    credential: Credential,
    authority: CredentialAuthority
  )
  {
    CredentialRecognizedInState(state, credential)
    &&
    ValidCredentialAuthority(authority)
    &&
    ExistingSessionsRemainWithinCredentialAuthority(
      state,
      CredentialId(credential),
      authority
    )
  }


  function SetCredentialAuthority(
    account: Account,
    credential: Credential,
    authority: CredentialAuthority
  ): Account
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
  {
    var state := AccountAuthorizationState(account);

    Account(
      AccountIdOf(account),
      AccountSovereignIdentity(account),
      AuthorizationState(
        StateCapabilities(state),
        StateCredentials(state),
        StateCredentialAuthorities(state)
          [CredentialId(credential) := authority],
        StateSessions(state),
        StateDelegations(state),
        StateDelegationProvenance(state),
        StateRestrictionMap(state),
        StatePolicyEffects(state),
        StateConsumedReplayKeys(state)
      )
    )
  }


  lemma SetCredentialAuthorityPreservesIdentity(
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
    ensures AccountTransitionPreservesIdentity(
              account,
              SetCredentialAuthority(
                account,
                credential,
                authority
              )
            )
  {
  }


  lemma CredentialAuthorityUpdatedInState(
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
    ensures StateCredentialAuthority(
              AccountAuthorizationState(
                SetCredentialAuthority(
                  account,
                  credential,
                  authority
                )
              ),
              credential
            ) == authority
  {
  }


  lemma UpdatedCredentialAuthorityStillBoundsExistingSessions(
    account: Account,
    credential: Credential,
    authority: CredentialAuthority,
    session: Session
  )
    requires ValidAccount(account)
    requires ValidCredentialAuthority(authority)
    requires CredentialRecognizedInState(
               AccountAuthorizationState(account),
               credential
             )
    requires session
             in StateSessions(
                  AccountAuthorizationState(account)
                )
    requires SessionCredentialId(session)
          == CredentialId(credential)
    requires ExistingSessionsRemainWithinCredentialAuthority(
               AccountAuthorizationState(account),
               CredentialId(credential),
               authority
             )
    ensures SessionAuthorityWithinCredentialAuthority(
              session,
              StateCredentialAuthority(
                AccountAuthorizationState(
                  SetCredentialAuthority(
                    account,
                    credential,
                    authority
                  )
                ),
                credential
              )
            )
  {
  }


  lemma SetCredentialAuthorityPreservesAuthorizationStateValidity(
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
    ensures ValidAuthorizationState(
              AccountAuthorizationState(
                SetCredentialAuthority(
                  account,
                  credential,
                  authority
                )
              )
            )
  {
    var before := AccountAuthorizationState(account);
    var after := AccountAuthorizationState(
      SetCredentialAuthority(
        account,
        credential,
        authority
      )
    );

    assert ValidAuthorizationState(before);

    assert ValidCapabilitiesInState(after);
    assert ValidCredentialsInState(after);
    assert CredentialIdsAreUnique(after);

    assert EveryRecognizedCredentialHasAuthority(after);
    assert EveryAuthorityBelongsToRecognizedCredential(after);
    assert CredentialAuthoritiesContainValidAuthorities(after);

    assert ValidSessionsInState(after);
    assert SessionCredentialsBelongToState(after);
    assert SessionIdsAreUnique(after);
    assert SessionAuthoritiesRespectCredentialAuthorities(after);

    assert ValidDelegationsInState(after);
    assert DelegationIdsAreUnique(after);
    assert EveryRecognizedDelegationHasProvenance(after);
    assert EveryDelegationProvenanceBelongsToRecognizedDelegation(after);
    assert ValidDelegationProvenanceInState(after);

    assert ValidRestrictionMapInState(after);

    assert ValidPolicyEffectsInState(after);
    assert ValidReplayState(after);

    assert ValidAuthorizationState(after);
  }


  lemma SetCredentialAuthorityPreservesAccountValidity(
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
    ensures ValidAccount(
              SetCredentialAuthority(
                account,
                credential,
                authority
              )
            )
  {
    var after := SetCredentialAuthority(
      account,
      credential,
      authority
    );

    SetCredentialAuthorityPreservesAuthorizationStateValidity(
      account,
      credential,
      authority
    );

    assert AccountTransitionPreservesIdentity(
        account,
        after
      );

    ValidTransitionResultFromPreservedIdentityAndState(
      account,
      after
    );
  }


  // ============================================================
  // CREDENTIAL LIFECYCLE
  // ============================================================

  function UpdateCredentialStatus(
    account: Account,
    credential: Credential,
    status: CredentialStatus
  ): Account
    requires ValidAccount(account)
    requires credential
             in StateCredentials(
                  AccountAuthorizationState(account)
                )
    requires ValidCredentialStatusTransition(
               credential,
               status
             )
  {
    var state := AccountAuthorizationState(account);

    var updatedCredential :=
      Credential(
        CredentialId(credential),
        status
      );

    Account(
      AccountIdOf(account),
      AccountSovereignIdentity(account),
      AuthorizationState(
        StateCapabilities(state),
        (set registeredCredential |
         registeredCredential in StateCredentials(state)
         && CredentialId(registeredCredential)
            != CredentialId(credential))
        + { updatedCredential },
        StateCredentialAuthorities(state),
        StateSessions(state),
        StateDelegations(state),
        StateDelegationProvenance(state),
        StateRestrictionMap(state),
        StatePolicyEffects(state),
        StateConsumedReplayKeys(state)
      )
    )
  }


  lemma UpdateCredentialStatusPreservesIdentity(
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
    ensures AccountTransitionPreservesIdentity(
              account,
              UpdateCredentialStatus(
                account,
                credential,
                status
              )
            )
  {
  }


  lemma UpdatedCredentialRemainsRecognized(
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
    ensures CredentialIdRecognizedInState(
              AccountAuthorizationState(
                UpdateCredentialStatus(
                  account,
                  credential,
                  status
                )
              ),
              CredentialId(credential)
            )
  {
  }


  lemma UpdatedCredentialPreservesEntityIdentity(
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
    ensures exists updatedCredential ::
              updatedCredential
              in StateCredentials(
                   AccountAuthorizationState(
                     UpdateCredentialStatus(
                       account,
                       credential,
                       status
                     )
                   )
                 )
              && CredentialId(updatedCredential)
                 == CredentialId(credential)
  {
  }


  lemma UpdateCredentialStatusPreservesAuthorizationStateValidity(
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
    ensures ValidAuthorizationState(
              AccountAuthorizationState(
                UpdateCredentialStatus(
                  account,
                  credential,
                  status
                )
              )
            )
  {
    var before := AccountAuthorizationState(account);
    var after := AccountAuthorizationState(
      UpdateCredentialStatus(
        account,
        credential,
        status
      )
    );

    assert ValidAuthorizationState(before);

    assert ValidCapabilitiesInState(after);
    assert ValidCredentialsInState(after);
    assert CredentialIdsAreUnique(after);

    assert EveryRecognizedCredentialHasAuthority(after);
    assert EveryAuthorityBelongsToRecognizedCredential(after);
    assert CredentialAuthoritiesContainValidAuthorities(after);

    assert ValidSessionsInState(after);
    assert SessionCredentialsBelongToState(after);
    assert SessionIdsAreUnique(after);
    assert SessionAuthoritiesRespectCredentialAuthorities(after);

    assert ValidDelegationsInState(after);
    assert DelegationIdsAreUnique(after);
    assert EveryRecognizedDelegationHasProvenance(after);
    assert EveryDelegationProvenanceBelongsToRecognizedDelegation(after);

    assert ValidRestrictionMapInState(after);

    assert ValidPolicyEffectsInState(after);
    assert ValidReplayState(after);

    assert ValidAuthorizationState(after);
  }


  lemma UpdateCredentialStatusPreservesAccountValidity(
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
    ensures ValidAccount(
              UpdateCredentialStatus(
                account,
                credential,
                status
              )
            )
  {
    var after := UpdateCredentialStatus(
      account,
      credential,
      status
    );

    UpdateCredentialStatusPreservesAuthorizationStateValidity(
      account,
      credential,
      status
    );

    assert AccountTransitionPreservesIdentity(
        account,
        after
      );

    ValidTransitionResultFromPreservedIdentityAndState(
      account,
      after
    );
  }


  // ============================================================
  // ACCOUNT CAPABILITY STATE
  // ============================================================

  function AddCapability(
    account: Account,
    capability: Capability
  ): Account
    requires ValidAccount(account)
    requires ValidCapability(capability)
  {
    var state := AccountAuthorizationState(account);

    Account(
      AccountIdOf(account),
      AccountSovereignIdentity(account),
      AuthorizationState(
        StateCapabilities(state) + { capability },
        StateCredentials(state),
        StateCredentialAuthorities(state),
        StateSessions(state),
        StateDelegations(state),
        StateDelegationProvenance(state),
        StateRestrictionMap(state),
        StatePolicyEffects(state),
        StateConsumedReplayKeys(state)
      )
    )
  }


  lemma AddCapabilityPreservesIdentity(
    account: Account,
    capability: Capability
  )
    requires ValidAccount(account)
    requires ValidCapability(capability)
    ensures AccountTransitionPreservesIdentity(
              account,
              AddCapability(account, capability)
            )
  {
  }


  lemma AddCapabilityPreservesAuthorizationStateValidity(
    account: Account,
    capability: Capability
  )
    requires ValidAccount(account)
    requires ValidCapability(capability)
    ensures ValidAuthorizationState(
              AccountAuthorizationState(
                AddCapability(account, capability)
              )
            )
  {
    var before := AccountAuthorizationState(account);
    var after := AccountAuthorizationState(
      AddCapability(account, capability)
    );

    assert ValidAuthorizationState(before);

    assert ValidCapabilitiesInState(after);
    assert ValidCredentialsInState(after);
    assert CredentialIdsAreUnique(after);

    assert EveryRecognizedCredentialHasAuthority(after);
    assert EveryAuthorityBelongsToRecognizedCredential(after);
    assert CredentialAuthoritiesContainValidAuthorities(after);

    assert ValidSessionsInState(after);
    assert SessionCredentialsBelongToState(after);
    assert SessionIdsAreUnique(after);
    assert SessionAuthoritiesRespectCredentialAuthorities(after);

    assert ValidDelegationsInState(after);
    assert DelegationIdsAreUnique(after);
    assert EveryRecognizedDelegationHasProvenance(after);
    assert EveryDelegationProvenanceBelongsToRecognizedDelegation(after);

    assert ValidRestrictionMapInState(after);

    assert ValidPolicyEffectsInState(after);
    assert ValidReplayState(after);

    assert ValidAuthorizationState(after);
  }


  lemma AddCapabilityPreservesAccountValidity(
    account: Account,
    capability: Capability
  )
    requires ValidAccount(account)
    requires ValidCapability(capability)
    ensures ValidAccount(
              AddCapability(account, capability)
            )
  {
    var after := AddCapability(account, capability);

    AddCapabilityPreservesAuthorizationStateValidity(
      account,
      capability
    );

    assert AccountTransitionPreservesIdentity(
        account,
        after
      );

    ValidTransitionResultFromPreservedIdentityAndState(
      account,
      after
    );
  }


  // ============================================================
  // CAPABILITY REMOVAL + D5.3.2
  // ============================================================

  function RemoveCapability(
    account: Account,
    capability: Capability
  ): Account
    requires ValidAccount(account)
  {
    var state := AccountAuthorizationState(account);

    Account(
      AccountIdOf(account),
      AccountSovereignIdentity(account),
      AuthorizationState(
        StateCapabilities(state) - { capability },
        StateCredentials(state),
        StateCredentialAuthorities(state),
        StateSessions(state),
        StateDelegations(state),
        StateDelegationProvenance(state),
        RemoveRestrictionsForCapability(
          StateRestrictionMap(state),
          capability
        ),
        StatePolicyEffects(state),
        StateConsumedReplayKeys(state)
      )
    )
  }


  lemma RemoveCapabilityPreservesIdentity(
    account: Account,
    capability: Capability
  )
    requires ValidAccount(account)
    ensures AccountTransitionPreservesIdentity(
              account,
              RemoveCapability(account, capability)
            )
  {
  }


  // IMPORTANT:
  //
  // Removing a Capability is valid even when the Capability is
  // already absent from StateCapabilities.
  //
  // The operation is set subtraction and restriction filtering.
  // Therefore D5.3.2 does not require the Capability to be present
  // as a precondition of the transition itself.
  //
  // This keeps the transition contract aligned with the actual
  // function signature of RemoveCapability and avoids introducing
  // an artificial precondition merely to prove the invariant.

  lemma RemoveCapabilityPreservesRestrictionMapIntegrity(
    account: Account,
    capability: Capability
  )
    requires ValidAccount(account)
    ensures
      ValidRestrictionMapInState(
        AccountAuthorizationState(
          RemoveCapability(account, capability)
        )
      )
  {
    var before := AccountAuthorizationState(account);
    var after := AccountAuthorizationState(
      RemoveCapability(account, capability)
    );

    var updatedMap :=
      RemoveRestrictionsForCapability(
        StateRestrictionMap(before),
        capability
      );

    assert StateRestrictionMap(after) == updatedMap;

    assert ValidAuthorizationState(before);

    RestrictionMapAfterCapabilityRemovalPreservesValidTargets(
      account,
      capability
    );

    RestrictionMapAfterCapabilityRemovalPreservesValidValues(
      account,
      capability
    );

    RestrictionMapAfterCapabilityRemovalHasNoOrphans(
      account,
      capability
    );

    assert forall target ::
        target in updatedMap.Keys
        ==> ValidRestrictionTarget(target);

    assert forall target ::
        target in updatedMap.Keys
        ==> ValidRestriction(updatedMap[target]);

    assert forall target ::
        target in updatedMap.Keys
        ==> RestrictionTargetCapability(target)
            in StateCapabilities(after);

    assert ValidRestrictionMapInState(after);
  }


  lemma RemoveCapabilityPreservesAuthorizationStateValidity(
    account: Account,
    capability: Capability
  )
    requires ValidAccount(account)
    ensures ValidAuthorizationState(
              AccountAuthorizationState(
                RemoveCapability(account, capability)
              )
            )
  {
    var before := AccountAuthorizationState(account);
    var after := AccountAuthorizationState(
      RemoveCapability(account, capability)
    );

    assert ValidAuthorizationState(before);

    assert ValidCapabilitiesInState(after);
    assert ValidCredentialsInState(after);
    assert CredentialIdsAreUnique(after);

    assert EveryRecognizedCredentialHasAuthority(after);
    assert EveryAuthorityBelongsToRecognizedCredential(after);
    assert CredentialAuthoritiesContainValidAuthorities(after);

    assert ValidSessionsInState(after);
    assert SessionCredentialsBelongToState(after);
    assert SessionIdsAreUnique(after);
    assert SessionAuthoritiesRespectCredentialAuthorities(after);

    assert ValidDelegationsInState(after);
    assert DelegationIdsAreUnique(after);
    assert EveryRecognizedDelegationHasProvenance(after);
    assert EveryDelegationProvenanceBelongsToRecognizedDelegation(after);

    RemoveCapabilityPreservesRestrictionMapIntegrity(
      account,
      capability
    );

    assert ValidRestrictionMapInState(after);

    assert ValidPolicyEffectsInState(after);
    assert ValidReplayState(after);

    assert ValidAuthorizationState(after);
  }


  lemma RemoveCapabilityPreservesAccountValidity(
    account: Account,
    capability: Capability
  )
    requires ValidAccount(account)
    ensures ValidAccount(
              RemoveCapability(account, capability)
            )
  {
    var after := RemoveCapability(account, capability);

    RemoveCapabilityPreservesAuthorizationStateValidity(
      account,
      capability
    );

    assert AccountTransitionPreservesIdentity(
        account,
        after
      );

    ValidTransitionResultFromPreservedIdentityAndState(
      account,
      after
    );
  }


  // ============================================================
  // RESTRICTION STATE
  // ============================================================

  function SetRestriction(
    account: Account,
    capability: Capability,
    scope: OptionalPolicyScope,
    restriction: Restriction
  ): Account
    requires ValidAccount(account)
    requires ValidCapability(capability)
    requires ValidOptionalPolicyScope(scope)
    requires ValidRestriction(restriction)
    requires capability
             in StateCapabilities(
                  AccountAuthorizationState(account)
                )
  {
    var state := AccountAuthorizationState(account);

    Account(
      AccountIdOf(account),
      AccountSovereignIdentity(account),
      AuthorizationState(
        StateCapabilities(state),
        StateCredentials(state),
        StateCredentialAuthorities(state),
        StateSessions(state),
        StateDelegations(state),
        StateDelegationProvenance(state),
        SetRestrictionInMap(
          StateRestrictionMap(state),
          capability,
          scope,
          restriction
        ),
        StatePolicyEffects(state),
        StateConsumedReplayKeys(state)
      )
    )
  }


  lemma SetRestrictionPreservesIdentity(
    account: Account,
    capability: Capability,
    scope: OptionalPolicyScope,
    restriction: Restriction
  )
    requires ValidAccount(account)
    requires ValidCapability(capability)
    requires ValidOptionalPolicyScope(scope)
    requires ValidRestriction(restriction)
    requires capability
             in StateCapabilities(
                  AccountAuthorizationState(account)
                )
    ensures AccountTransitionPreservesIdentity(
              account,
              SetRestriction(
                account,
                capability,
                scope,
                restriction
              )
            )
  {
  }


  lemma SetRestrictionReplacesOrAddsTarget(
    account: Account,
    capability: Capability,
    scope: OptionalPolicyScope,
    restriction: Restriction
  )
    requires ValidAccount(account)
    requires ValidCapability(capability)
    requires ValidOptionalPolicyScope(scope)
    requires ValidRestriction(restriction)
    requires capability
             in StateCapabilities(
                  AccountAuthorizationState(account)
                )
    ensures
      StateRestrictionMap(
        AccountAuthorizationState(
          SetRestriction(
            account,
            capability,
            scope,
            restriction
          )
        )
      )[
        RestrictionTarget(
          capability,
          scope
        )
      ] == restriction
  {
  }


  lemma SetRestrictionPreservesRestrictionMapIntegrity(
    account: Account,
    capability: Capability,
    scope: OptionalPolicyScope,
    restriction: Restriction
  )
    requires ValidAccount(account)
    requires ValidCapability(capability)
    requires ValidOptionalPolicyScope(scope)
    requires ValidRestriction(restriction)
    requires capability
             in StateCapabilities(
                  AccountAuthorizationState(account)
                )
    ensures
      ValidRestrictionMapInState(
        AccountAuthorizationState(
          SetRestriction(
            account,
            capability,
            scope,
            restriction
          )
        )
      )
  {
    var before := AccountAuthorizationState(account);
    var after := AccountAuthorizationState(
      SetRestriction(
        account,
        capability,
        scope,
        restriction
      )
    );

    var target :=
      RestrictionTarget(
        capability,
        scope
      );

    var updatedMap :=
      SetRestrictionInMap(
        StateRestrictionMap(before),
        capability,
        scope,
        restriction
      );

    assert StateRestrictionMap(after) == updatedMap;

    assert ValidAuthorizationState(before);

    assert ValidRestrictionTarget(target);
    assert ValidRestriction(restriction);

    assert forall existingTarget ::
        existingTarget in updatedMap.Keys
        ==> ValidRestrictionTarget(existingTarget);

    assert forall existingTarget ::
        existingTarget in updatedMap.Keys
        ==> ValidRestriction(updatedMap[existingTarget]);

    assert forall existingTarget ::
        existingTarget in updatedMap.Keys
        ==> RestrictionTargetCapability(existingTarget)
            in StateCapabilities(after);

    assert ValidRestrictionMapInState(after);
  }


  lemma SetRestrictionPreservesAuthorizationStateValidity(
    account: Account,
    capability: Capability,
    scope: OptionalPolicyScope,
    restriction: Restriction
  )
    requires ValidAccount(account)
    requires ValidCapability(capability)
    requires ValidOptionalPolicyScope(scope)
    requires ValidRestriction(restriction)
    requires capability
             in StateCapabilities(
                  AccountAuthorizationState(account)
                )
    ensures ValidAuthorizationState(
              AccountAuthorizationState(
                SetRestriction(
                  account,
                  capability,
                  scope,
                  restriction
                )
              )
            )
  {
    var before := AccountAuthorizationState(account);
    var after := AccountAuthorizationState(
      SetRestriction(
        account,
        capability,
        scope,
        restriction
      )
    );

    assert ValidAuthorizationState(before);

    assert ValidCapabilitiesInState(after);
    assert ValidCredentialsInState(after);
    assert CredentialIdsAreUnique(after);

    assert EveryRecognizedCredentialHasAuthority(after);
    assert EveryAuthorityBelongsToRecognizedCredential(after);
    assert CredentialAuthoritiesContainValidAuthorities(after);

    assert ValidSessionsInState(after);
    assert SessionCredentialsBelongToState(after);
    assert SessionIdsAreUnique(after);
    assert SessionAuthoritiesRespectCredentialAuthorities(after);

    assert ValidDelegationsInState(after);
    assert DelegationIdsAreUnique(after);
    assert EveryRecognizedDelegationHasProvenance(after);
    assert EveryDelegationProvenanceBelongsToRecognizedDelegation(after);

    SetRestrictionPreservesRestrictionMapIntegrity(
      account,
      capability,
      scope,
      restriction
    );

    assert ValidRestrictionMapInState(after);

    assert ValidPolicyEffectsInState(after);
    assert ValidReplayState(after);

    assert ValidAuthorizationState(after);
  }


  lemma SetRestrictionPreservesAccountValidity(
    account: Account,
    capability: Capability,
    scope: OptionalPolicyScope,
    restriction: Restriction
  )
    requires ValidAccount(account)
    requires ValidCapability(capability)
    requires ValidOptionalPolicyScope(scope)
    requires ValidRestriction(restriction)
    requires capability
             in StateCapabilities(
                  AccountAuthorizationState(account)
                )
    ensures ValidAccount(
              SetRestriction(
                account,
                capability,
                scope,
                restriction
              )
            )
  {
    var after := SetRestriction(
      account,
      capability,
      scope,
      restriction
    );

    SetRestrictionPreservesAuthorizationStateValidity(
      account,
      capability,
      scope,
      restriction
    );

    assert AccountTransitionPreservesIdentity(
        account,
        after
      );

    ValidTransitionResultFromPreservedIdentityAndState(
      account,
      after
    );
  }


  function RemoveRestriction(
    account: Account,
    capability: Capability,
    scope: OptionalPolicyScope
  ): Account
    requires ValidAccount(account)
  {
    var state := AccountAuthorizationState(account);

    Account(
      AccountIdOf(account),
      AccountSovereignIdentity(account),
      AuthorizationState(
        StateCapabilities(state),
        StateCredentials(state),
        StateCredentialAuthorities(state),
        StateSessions(state),
        StateDelegations(state),
        StateDelegationProvenance(state),
        RemoveRestrictionTarget(
          StateRestrictionMap(state),
          capability,
          scope
        ),
        StatePolicyEffects(state),
        StateConsumedReplayKeys(state)
      )
    )
  }


  lemma RemoveRestrictionPreservesIdentity(
    account: Account,
    capability: Capability,
    scope: OptionalPolicyScope
  )
    requires ValidAccount(account)
    ensures AccountTransitionPreservesIdentity(
              account,
              RemoveRestriction(
                account,
                capability,
                scope
              )
            )
  {
  }


  lemma RemoveRestrictionTargetIsAbsent(
    account: Account,
    capability: Capability,
    scope: OptionalPolicyScope
  )
    requires ValidAccount(account)
    ensures
      !RestrictionDefinedFor(
        AccountAuthorizationState(
          RemoveRestriction(
            account,
            capability,
            scope
          )
        ),
        capability,
        scope
      )
  {
  }


  lemma RemoveRestrictionPreservesRestrictionMapIntegrity(
    account: Account,
    capability: Capability,
    scope: OptionalPolicyScope
  )
    requires ValidAccount(account)
    ensures
      ValidRestrictionMapInState(
        AccountAuthorizationState(
          RemoveRestriction(
            account,
            capability,
            scope
          )
        )
      )
  {
    var before := AccountAuthorizationState(account);
    var after := AccountAuthorizationState(
      RemoveRestriction(
        account,
        capability,
        scope
      )
    );

    var updatedMap :=
      RemoveRestrictionTarget(
        StateRestrictionMap(before),
        capability,
        scope
      );

    assert StateRestrictionMap(after) == updatedMap;

    assert ValidAuthorizationState(before);

    assert forall target ::
        target in updatedMap.Keys
        ==> ValidRestrictionTarget(target);

    assert forall target ::
        target in updatedMap.Keys
        ==> ValidRestriction(updatedMap[target]);

    assert forall target ::
        target in updatedMap.Keys
        ==> RestrictionTargetCapability(target)
            in StateCapabilities(after);

    assert ValidRestrictionMapInState(after);
  }


  lemma RemoveRestrictionPreservesAuthorizationStateValidity(
    account: Account,
    capability: Capability,
    scope: OptionalPolicyScope
  )
    requires ValidAccount(account)
    ensures ValidAuthorizationState(
              AccountAuthorizationState(
                RemoveRestriction(
                  account,
                  capability,
                  scope
                )
              )
            )
  {
    var before := AccountAuthorizationState(account);
    var after := AccountAuthorizationState(
      RemoveRestriction(
        account,
        capability,
        scope
      )
    );

    assert ValidAuthorizationState(before);

    assert ValidCapabilitiesInState(after);
    assert ValidCredentialsInState(after);
    assert CredentialIdsAreUnique(after);

    assert EveryRecognizedCredentialHasAuthority(after);
    assert EveryAuthorityBelongsToRecognizedCredential(after);
    assert CredentialAuthoritiesContainValidAuthorities(after);

    assert ValidSessionsInState(after);
    assert SessionCredentialsBelongToState(after);
    assert SessionIdsAreUnique(after);
    assert SessionAuthoritiesRespectCredentialAuthorities(after);

    assert ValidDelegationsInState(after);
    assert DelegationIdsAreUnique(after);
    assert EveryRecognizedDelegationHasProvenance(after);
    assert EveryDelegationProvenanceBelongsToRecognizedDelegation(after);

    RemoveRestrictionPreservesRestrictionMapIntegrity(
      account,
      capability,
      scope
    );

    assert ValidRestrictionMapInState(after);

    assert ValidPolicyEffectsInState(after);
    assert ValidReplayState(after);

    assert ValidAuthorizationState(after);
  }


  lemma RemoveRestrictionPreservesAccountValidity(
    account: Account,
    capability: Capability,
    scope: OptionalPolicyScope
  )
    requires ValidAccount(account)
    ensures ValidAccount(
              RemoveRestriction(
                account,
                capability,
                scope
              )
            )
  {
    var after := RemoveRestriction(
      account,
      capability,
      scope
    );

    RemoveRestrictionPreservesAuthorizationStateValidity(
      account,
      capability,
      scope
    );

    assert AccountTransitionPreservesIdentity(
        account,
        after
      );

    ValidTransitionResultFromPreservedIdentityAndState(
      account,
      after
    );
  }


  // ============================================================
  // SESSION REGISTRATION
  // ============================================================

  function RegisterSession(
    account: Account,
    session: Session
  ): Account
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
  {
    var state := AccountAuthorizationState(account);

    Account(
      AccountIdOf(account),
      AccountSovereignIdentity(account),
      AuthorizationState(
        StateCapabilities(state),
        StateCredentials(state),
        StateCredentialAuthorities(state),
        StateSessions(state) + { session },
        StateDelegations(state),
        StateDelegationProvenance(state),
        StateRestrictionMap(state),
        StatePolicyEffects(state),
        StateConsumedReplayKeys(state)
      )
    )
  }


  lemma RegisterSessionPreservesIdentity(
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
    ensures AccountTransitionPreservesIdentity(
              account,
              RegisterSession(account, session)
            )
  {
  }


  lemma RegisteredSessionBelongsToState(
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
    ensures SessionIdRecognizedInState(
              AccountAuthorizationState(
                RegisterSession(account, session)
              ),
              SessionId(session)
            )
  {
  }


  lemma RegisterSessionPreservesAuthorizationStateValidity(
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
    ensures ValidAuthorizationState(
              AccountAuthorizationState(
                RegisterSession(account, session)
              )
            )
  {
    var before := AccountAuthorizationState(account);
    var after := AccountAuthorizationState(
      RegisterSession(account, session)
    );

    assert ValidAuthorizationState(before);

    assert ValidCapabilitiesInState(after);
    assert ValidCredentialsInState(after);
    assert CredentialIdsAreUnique(after);

    assert EveryRecognizedCredentialHasAuthority(after);
    assert EveryAuthorityBelongsToRecognizedCredential(after);
    assert CredentialAuthoritiesContainValidAuthorities(after);

    assert ValidSessionsInState(after);
    assert SessionCredentialsBelongToState(after);
    assert SessionIdsAreUnique(after);
    assert SessionAuthoritiesRespectCredentialAuthorities(after);

    assert ValidDelegationsInState(after);
    assert DelegationIdsAreUnique(after);
    assert EveryRecognizedDelegationHasProvenance(after);
    assert EveryDelegationProvenanceBelongsToRecognizedDelegation(after);

    assert ValidRestrictionMapInState(after);

    assert ValidPolicyEffectsInState(after);
    assert ValidReplayState(after);

    assert ValidAuthorizationState(after);
  }


  lemma RegisterSessionPreservesAccountValidity(
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
    ensures ValidAccount(
              RegisterSession(account, session)
            )
  {
    var after := RegisterSession(account, session);

    RegisterSessionPreservesAuthorizationStateValidity(
      account,
      session
    );

    assert AccountTransitionPreservesIdentity(
        account,
        after
      );

    ValidTransitionResultFromPreservedIdentityAndState(
      account,
      after
    );
  }


  // ============================================================
  // SESSION LIFECYCLE
  // ============================================================

  function UpdateSessionStatus(
    account: Account,
    session: Session,
    status: SessionStatus
  ): Account
    requires ValidAccount(account)
    requires session
             in StateSessions(
                  AccountAuthorizationState(account)
                )
    requires ValidSessionStatusTransition(
               session,
               status
             )
  {
    var state := AccountAuthorizationState(account);

    var updatedSession :=
      Session(
        SessionId(session),
        SessionCredentialId(session),
        SessionCapabilities(session),
        SessionValidFrom(session),
        SessionValidUntil(session),
        SessionRestrictions(session),
        status
      );

    Account(
      AccountIdOf(account),
      AccountSovereignIdentity(account),
      AuthorizationState(
        StateCapabilities(state),
        StateCredentials(state),
        StateCredentialAuthorities(state),
        (set registeredSession |
         registeredSession in StateSessions(state)
         && SessionId(registeredSession)
            != SessionId(session))
        + { updatedSession },
        StateDelegations(state),
        StateDelegationProvenance(state),
        StateRestrictionMap(state),
        StatePolicyEffects(state),
        StateConsumedReplayKeys(state)
      )
    )
  }


  lemma UpdateSessionStatusPreservesIdentity(
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
    ensures AccountTransitionPreservesIdentity(
              account,
              UpdateSessionStatus(
                account,
                session,
                status
              )
            )
  {
  }


  lemma UpdatedSessionRemainsInState(
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
    ensures SessionIdRecognizedInState(
              AccountAuthorizationState(
                UpdateSessionStatus(
                  account,
                  session,
                  status
                )
              ),
              SessionId(session)
            )
  {
  }


  lemma UpdatedSessionPreservesEntityIdentity(
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
    ensures exists updatedSession ::
              updatedSession
              in StateSessions(
                   AccountAuthorizationState(
                     UpdateSessionStatus(
                       account,
                       session,
                       status
                     )
                   )
                 )
              && SessionId(updatedSession)
                 == SessionId(session)
  {
  }


  lemma UpdatedSessionPreservesCredentialAuthorityBoundary(
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
    ensures SessionAuthorityWithinCredentialAuthority(
              Session(
                SessionId(session),
                SessionCredentialId(session),
                SessionCapabilities(session),
                SessionValidFrom(session),
                SessionValidUntil(session),
                SessionRestrictions(session),
                status
              ),
              StateCredentialAuthorities(
                AccountAuthorizationState(account)
              )[SessionCredentialId(session)]
            )
  {
  }


  lemma UpdateSessionStatusPreservesAuthorizationStateValidity(
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
    ensures ValidAuthorizationState(
              AccountAuthorizationState(
                UpdateSessionStatus(
                  account,
                  session,
                  status
                )
              )
            )
  {
    var before := AccountAuthorizationState(account);
    var after := AccountAuthorizationState(
      UpdateSessionStatus(
        account,
        session,
        status
      )
    );

    assert ValidAuthorizationState(before);

    assert ValidCapabilitiesInState(after);
    assert ValidCredentialsInState(after);
    assert CredentialIdsAreUnique(after);

    assert EveryRecognizedCredentialHasAuthority(after);
    assert EveryAuthorityBelongsToRecognizedCredential(after);
    assert CredentialAuthoritiesContainValidAuthorities(after);

    assert ValidSessionsInState(after);
    assert SessionCredentialsBelongToState(after);
    assert SessionIdsAreUnique(after);
    assert SessionAuthoritiesRespectCredentialAuthorities(after);

    assert ValidDelegationsInState(after);
    assert DelegationIdsAreUnique(after);
    assert EveryRecognizedDelegationHasProvenance(after);
    assert EveryDelegationProvenanceBelongsToRecognizedDelegation(after);

    assert ValidRestrictionMapInState(after);

    assert ValidPolicyEffectsInState(after);
    assert ValidReplayState(after);

    assert ValidAuthorizationState(after);
  }


  lemma UpdateSessionStatusPreservesAccountValidity(
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
    ensures ValidAccount(
              UpdateSessionStatus(
                account,
                session,
                status
              )
            )
  {
    var after := UpdateSessionStatus(
      account,
      session,
      status
    );

    UpdateSessionStatusPreservesAuthorizationStateValidity(
      account,
      session,
      status
    );

    assert AccountTransitionPreservesIdentity(
        account,
        after
      );

    ValidTransitionResultFromPreservedIdentityAndState(
      account,
      after
    );
  }


  // ============================================================
  // DELEGATION REGISTRATION
  // ============================================================

  predicate ParentDelegationsContainCapability(
    state: AuthorizationState,
    parentDelegationIds: set<Id>,
    capability: Capability
  )
  {
    exists parent : Delegation ::
      parent in StateDelegations(state)
      &&
      DelegationId(parent) in parentDelegationIds
      &&
      capability in DelegationCapabilities(parent)
  }


  predicate ParentDelegationsBoundNewDelegation(
    state: AuthorizationState,
    delegation: Delegation,
    parentDelegationIds: set<Id>
  )
  {
    DelegationId(delegation) !in parentDelegationIds
    &&
    |parentDelegationIds| > 0
    &&
    (forall parentId ::
       parentId in parentDelegationIds
       ==>
         DelegationIdRecognizedInState(
           state,
           parentId
         ))
    &&
    (forall capability ::
       capability in DelegationCapabilities(delegation)
       ==>
         ParentDelegationsContainCapability(
           state,
           parentDelegationIds,
           capability
         ))
  }


  predicate ParentDelegationsProvideAuthorityToChildSource(
    state: AuthorizationState,
    identities: set<Identity>,
    delegation: Delegation,
    parentDelegationIds: set<Id>,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>
  )
  {
    ParentDelegationsBoundNewDelegation(
      state,
      delegation,
      parentDelegationIds
    )
    &&
    SourceHasDelegationCapability(
      sourceEffectiveAuthority,
      delegateCapability
    )
    &&
    ParentDelegationsContainCapability(
      state,
      parentDelegationIds,
      delegateCapability
    )
    &&
    (forall capability ::
       capability in delegatableAuthority
       ==>
         ParentDelegationsContainCapability(
           state,
           parentDelegationIds,
           capability
         ))
    &&
    delegatableAuthority
      <=
    sourceEffectiveAuthority
    &&
    (forall parentId ::
       parentId in parentDelegationIds
       ==>
         exists parent : Delegation ::
           parent in StateDelegations(state)
           &&
           DelegationId(parent) == parentId
           &&
           ParentDelegationSupportsChildSource(
             identities,
             parent,
             delegation
           ))
  }


  // ============================================================
  // ROOT DELEGATION REGISTRATION BOUNDARY
  // ============================================================

  predicate ValidRootDelegationRegistration(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>
  )
  {
    ValidAccount(account)
    &&
    ValidDelegation(delegation)
    &&
    DelegationSourceIdentityId(delegation)
      ==
    IdentityId(AccountSovereignIdentity(account))
    &&
    SourceHasDelegationCapability(
      sourceEffectiveAuthority,
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
      sourceEffectiveAuthority
    )
    &&
    !DelegationIdRecognizedInState(
      AccountAuthorizationState(account),
      DelegationId(delegation)
    )
  }


  function RegisterDelegation(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>
  ): Account
    requires ValidRootDelegationRegistration(
               account,
               delegation,
               delegateCapability,
               delegatableAuthority,
               sourceEffectiveAuthority
             )
  {
    var state := AccountAuthorizationState(account);

    Account(
      AccountIdOf(account),
      AccountSovereignIdentity(account),
      AuthorizationState(
        StateCapabilities(state),
        StateCredentials(state),
        StateCredentialAuthorities(state),
        StateSessions(state),
        StateDelegations(state) + { delegation },
        StateDelegationProvenance(state)
          [DelegationId(delegation) := {}],
        StateRestrictionMap(state),
        StatePolicyEffects(state),
        StateConsumedReplayKeys(state)
      )
    )
  }


  lemma RegisteredRootDelegationHasSovereignSource(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>
  )
    requires ValidRootDelegationRegistration(
               account,
               delegation,
               delegateCapability,
               delegatableAuthority,
               sourceEffectiveAuthority
             )
    ensures DelegationSourceIdentityId(delegation)
            ==
            IdentityId(AccountSovereignIdentity(account))
  {
  }


  lemma RegisteredRootDelegationHasDelegateAuthorityWitness(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>
  )
    requires ValidRootDelegationRegistration(
               account,
               delegation,
               delegateCapability,
               delegatableAuthority,
               sourceEffectiveAuthority
             )
    ensures SourceHasDelegationCapability(
              sourceEffectiveAuthority,
              delegateCapability
            )
  {
  }


  lemma RegisteredRootDelegationHasDelegatableAuthorityWitness(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>
  )
    requires ValidRootDelegationRegistration(
               account,
               delegation,
               delegateCapability,
               delegatableAuthority,
               sourceEffectiveAuthority
             )
    ensures
      DelegatableAuthorityWithinEffectiveAuthority(
        delegatableAuthority,
        sourceEffectiveAuthority
      )
  {
  }


  lemma RegisteredRootDelegationRespectsDelegatedAuthorityBoundary(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>
  )
    requires ValidRootDelegationRegistration(
               account,
               delegation,
               delegateCapability,
               delegatableAuthority,
               sourceEffectiveAuthority
             )
    ensures DelegationAuthorityWithinDelegatableAuthority(
              delegation,
              delegatableAuthority
            )
  {
  }


  lemma RegisteredRootDelegationRespectsAuthorityBoundary(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>
  )
    requires ValidRootDelegationRegistration(
               account,
               delegation,
               delegateCapability,
               delegatableAuthority,
               sourceEffectiveAuthority
             )
    ensures DelegationAuthorityIsBounded(
              delegation,
              delegateCapability,
              delegatableAuthority,
              sourceEffectiveAuthority
            )
  {
  }


  lemma RegisterDelegationPreservesIdentity(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>
  )
    requires ValidRootDelegationRegistration(
               account,
               delegation,
               delegateCapability,
               delegatableAuthority,
               sourceEffectiveAuthority
             )
    ensures AccountTransitionPreservesIdentity(
              account,
              RegisterDelegation(
                account,
                delegation,
                delegateCapability,
                delegatableAuthority,
                sourceEffectiveAuthority
              )
            )
  {
  }


  lemma RegisteredDelegationBelongsToState(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>
  )
    requires ValidRootDelegationRegistration(
               account,
               delegation,
               delegateCapability,
               delegatableAuthority,
               sourceEffectiveAuthority
             )
    ensures DelegationIdRecognizedInState(
              AccountAuthorizationState(
                RegisterDelegation(
                  account,
                  delegation,
                  delegateCapability,
                  delegatableAuthority,
                  sourceEffectiveAuthority
                )
              ),
              DelegationId(delegation)
            )
  {
  }


  lemma RegisteredDelegationHasEmptyProvenance(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>
  )
    requires ValidRootDelegationRegistration(
               account,
               delegation,
               delegateCapability,
               delegatableAuthority,
               sourceEffectiveAuthority
             )
    ensures
      StateDelegationProvenance(
        AccountAuthorizationState(
          RegisterDelegation(
            account,
            delegation,
            delegateCapability,
            delegatableAuthority,
            sourceEffectiveAuthority
          )
        )
      )[DelegationId(delegation)] == {}
  {
  }


  lemma RegisterDelegationPreservesAuthorizationStateValidity(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>
  )
    requires ValidRootDelegationRegistration(
               account,
               delegation,
               delegateCapability,
               delegatableAuthority,
               sourceEffectiveAuthority
             )
    ensures ValidAuthorizationState(
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
  {
    var before := AccountAuthorizationState(account);
    var after := AccountAuthorizationState(
      RegisterDelegation(
        account,
        delegation,
        delegateCapability,
        delegatableAuthority,
        sourceEffectiveAuthority
      )
    );

    assert ValidAuthorizationState(before);

    assert ValidCapabilitiesInState(after);
    assert ValidCredentialsInState(after);
    assert CredentialIdsAreUnique(after);

    assert EveryRecognizedCredentialHasAuthority(after);
    assert EveryAuthorityBelongsToRecognizedCredential(after);
    assert CredentialAuthoritiesContainValidAuthorities(after);

    assert ValidSessionsInState(after);
    assert SessionCredentialsBelongToState(after);
    assert SessionIdsAreUnique(after);
    assert SessionAuthoritiesRespectCredentialAuthorities(after);

    assert ValidDelegationsInState(after);
    assert DelegationIdsAreUnique(after);
    assert EveryRecognizedDelegationHasProvenance(after);
    assert EveryDelegationProvenanceBelongsToRecognizedDelegation(after);
    assert ValidDelegationProvenanceInState(after);

    assert ValidRestrictionMapInState(after);

    assert ValidPolicyEffectsInState(after);
    assert ValidReplayState(after);

    assert ValidAuthorizationState(after);
  }


  lemma RegisterDelegationPreservesAccountValidity(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>
  )
    requires ValidRootDelegationRegistration(
               account,
               delegation,
               delegateCapability,
               delegatableAuthority,
               sourceEffectiveAuthority
             )
    ensures ValidAccount(
              RegisterDelegation(
                account,
                delegation,
                delegateCapability,
                delegatableAuthority,
                sourceEffectiveAuthority
              )
            )
  {
    var after := RegisterDelegation(
      account,
      delegation,
      delegateCapability,
      delegatableAuthority,
      sourceEffectiveAuthority
    );

    RegisterDelegationPreservesAuthorizationStateValidity(
      account,
      delegation,
      delegateCapability,
      delegatableAuthority,
      sourceEffectiveAuthority
    );

    assert AccountTransitionPreservesIdentity(
        account,
        after
      );

    ValidTransitionResultFromPreservedIdentityAndState(
      account,
      after
    );
  }


  lemma RegisterDelegationProvidesReusableTransitionContract(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>
  )
    requires ValidRootDelegationRegistration(
               account,
               delegation,
               delegateCapability,
               delegatableAuthority,
               sourceEffectiveAuthority
             )
    ensures ValidAccount(
              RegisterDelegation(
                account,
                delegation,
                delegateCapability,
                delegatableAuthority,
                sourceEffectiveAuthority
              )
            )
    ensures AccountTransitionPreservesIdentity(
              account,
              RegisterDelegation(
                account,
                delegation,
                delegateCapability,
                delegatableAuthority,
                sourceEffectiveAuthority
              )
            )
    ensures DelegationIdRecognizedInState(
              AccountAuthorizationState(
                RegisterDelegation(
                  account,
                  delegation,
                  delegateCapability,
                  delegatableAuthority,
                  sourceEffectiveAuthority
                )
              ),
              DelegationId(delegation)
            )
    ensures
      StateDelegationProvenance(
        AccountAuthorizationState(
          RegisterDelegation(
            account,
            delegation,
            delegateCapability,
            delegatableAuthority,
            sourceEffectiveAuthority
          )
        )
      )[DelegationId(delegation)] == {}
    ensures DelegationAuthorityIsBounded(
              delegation,
              delegateCapability,
              delegatableAuthority,
              sourceEffectiveAuthority
            )
  {
    RegisterDelegationPreservesAuthorizationStateValidity(
      account,
      delegation,
      delegateCapability,
      delegatableAuthority,
      sourceEffectiveAuthority
    );

    RegisterDelegationPreservesAccountValidity(
      account,
      delegation,
      delegateCapability,
      delegatableAuthority,
      sourceEffectiveAuthority
    );

    RegisterDelegationPreservesIdentity(
      account,
      delegation,
      delegateCapability,
      delegatableAuthority,
      sourceEffectiveAuthority
    );

    RegisteredDelegationBelongsToState(
      account,
      delegation,
      delegateCapability,
      delegatableAuthority,
      sourceEffectiveAuthority
    );

    RegisteredDelegationHasEmptyProvenance(
      account,
      delegation,
      delegateCapability,
      delegatableAuthority,
      sourceEffectiveAuthority
    );

    RegisteredRootDelegationRespectsAuthorityBoundary(
      account,
      delegation,
      delegateCapability,
      delegatableAuthority,
      sourceEffectiveAuthority
    );
  }


  // ============================================================
  // TRANSITIVE DELEGATION REGISTRATION
  // ============================================================

  predicate ValidTransitiveDelegationRegistration(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>,
    parentDelegationIds: set<Id>,
    identities: set<Identity>
  )
  {
    ValidAccount(account)
    &&
    ValidDelegation(delegation)
    &&
    !DelegationIdRecognizedInState(
      AccountAuthorizationState(account),
      DelegationId(delegation)
    )
    &&
    ParentDelegationsProvideAuthorityToChildSource(
      AccountAuthorizationState(account),
      identities,
      delegation,
      parentDelegationIds,
      delegateCapability,
      delegatableAuthority,
      sourceEffectiveAuthority
    )
    &&
    DelegationAuthorityWithinDelegatableAuthority(
      delegation,
      delegatableAuthority
    )
  }


  function RegisterTransitiveDelegation(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>,
    parentDelegationIds: set<Id>,
    identities: set<Identity>
  ): Account
    requires ValidTransitiveDelegationRegistration(
               account,
               delegation,
               delegateCapability,
               delegatableAuthority,
               sourceEffectiveAuthority,
               parentDelegationIds,
               identities
             )
  {
    var state := AccountAuthorizationState(account);

    Account(
      AccountIdOf(account),
      AccountSovereignIdentity(account),
      AuthorizationState(
        StateCapabilities(state),
        StateCredentials(state),
        StateCredentialAuthorities(state),
        StateSessions(state),
        StateDelegations(state) + { delegation },
        StateDelegationProvenance(state)
          [DelegationId(delegation) := parentDelegationIds],
        StateRestrictionMap(state),
        StatePolicyEffects(state),
        StateConsumedReplayKeys(state)
      )
    )
  }


  lemma RegisteredTransitiveDelegationHasParentSourceAttribution(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>,
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
    ensures
      forall parentId ::
        parentId in parentDelegationIds
        ==>
          exists parent : Delegation ::
            parent in StateDelegations(
              AccountAuthorizationState(account)
            )
            &&
            DelegationId(parent) == parentId
            &&
            ParentDelegationSupportsChildSource(
              identities,
              parent,
              delegation
            )
  {
  }


  lemma RegisteredTransitiveDelegationHasDelegateAuthorityFromParents(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>,
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
    ensures
      ParentDelegationsContainCapability(
        AccountAuthorizationState(account),
        parentDelegationIds,
        delegateCapability
      )
  {
  }


  lemma RegisteredTransitiveDelegationHasDelegatableAuthorityFromParents(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>,
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
    ensures
      forall capability ::
        capability in delegatableAuthority
        ==>
          ParentDelegationsContainCapability(
            AccountAuthorizationState(account),
            parentDelegationIds,
            capability
          )
  {
  }


  lemma RegisteredTransitiveDelegationHasDelegateAuthorityWitness(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>,
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
    ensures SourceHasDelegationCapability(
              sourceEffectiveAuthority,
              delegateCapability
            )
  {
  }


  lemma RegisteredTransitiveDelegationHasSourceEffectiveAuthorityBoundary(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>,
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
    ensures
      DelegatableAuthorityWithinEffectiveAuthority(
        delegatableAuthority,
        sourceEffectiveAuthority
      )
  {
  }


  lemma RegisteredTransitiveDelegationRespectsDelegatedAuthorityBoundary(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>,
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
    ensures DelegationAuthorityWithinDelegatableAuthority(
              delegation,
              delegatableAuthority
            )
  {
  }


  lemma RegisteredTransitiveDelegationRespectsAuthorityBoundary(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>,
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
    ensures DelegationAuthorityIsBounded(
              delegation,
              delegateCapability,
              delegatableAuthority,
              sourceEffectiveAuthority
            )
  {
  }


  lemma RegisterTransitiveDelegationPreservesIdentity(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>,
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
    ensures AccountTransitionPreservesIdentity(
              account,
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
  {
  }


  lemma RegisteredTransitiveDelegationHasProvenance(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>,
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
    ensures
      StateDelegationProvenance(
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
      )[DelegationId(delegation)] == parentDelegationIds
  {
  }


  lemma RegisteredTransitiveDelegationPreservesAuthorityBoundaryFromParents(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>,
    parentDelegationIds: set<Id>,
    identities: set<Identity>,
    capability: Capability
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
    requires capability in DelegationCapabilities(delegation)
    ensures
      exists parent ::
        parent in StateDelegations(
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
        &&
        DelegationId(parent) in parentDelegationIds
        &&
        capability in DelegationCapabilities(parent)
  {
  }


  lemma RegisterTransitiveDelegationPreservesAuthorizationStateValidity(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>,
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
    ensures ValidAuthorizationState(
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
  {
    var before := AccountAuthorizationState(account);
    var after := AccountAuthorizationState(
      RegisterTransitiveDelegation(
        account,
        delegation,
        delegateCapability,
        delegatableAuthority,
        sourceEffectiveAuthority,
        parentDelegationIds,
        identities
      )
    );

    assert ValidAuthorizationState(before);

    assert ValidCapabilitiesInState(after);
    assert ValidCredentialsInState(after);
    assert CredentialIdsAreUnique(after);

    assert EveryRecognizedCredentialHasAuthority(after);
    assert EveryAuthorityBelongsToRecognizedCredential(after);
    assert CredentialAuthoritiesContainValidAuthorities(after);

    assert ValidSessionsInState(after);
    assert SessionCredentialsBelongToState(after);
    assert SessionIdsAreUnique(after);
    assert SessionAuthoritiesRespectCredentialAuthorities(after);

    assert ValidDelegationsInState(after);
    assert DelegationIdsAreUnique(after);
    assert EveryRecognizedDelegationHasProvenance(after);
    assert EveryDelegationProvenanceBelongsToRecognizedDelegation(after);
    assert ValidDelegationProvenanceInState(after);

    assert ValidRestrictionMapInState(after);

    assert ValidPolicyEffectsInState(after);
    assert ValidReplayState(after);

    assert ValidAuthorizationState(after);
  }


  lemma RegisterTransitiveDelegationPreservesAccountValidity(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>,
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
    ensures ValidAccount(
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
  {
    var after := RegisterTransitiveDelegation(
      account,
      delegation,
      delegateCapability,
      delegatableAuthority,
      sourceEffectiveAuthority,
      parentDelegationIds,
      identities
    );

    RegisterTransitiveDelegationPreservesAuthorizationStateValidity(
      account,
      delegation,
      delegateCapability,
      delegatableAuthority,
      sourceEffectiveAuthority,
      parentDelegationIds,
      identities
    );

    assert AccountTransitionPreservesIdentity(
        account,
        after
      );

    ValidTransitionResultFromPreservedIdentityAndState(
      account,
      after
    );
  }


  lemma RegisterTransitiveDelegationProvidesReusableTransitionContract(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: set<Capability>,
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
    ensures ValidAccount(
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
    ensures AccountTransitionPreservesIdentity(
              account,
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
    ensures DelegationIdRecognizedInState(
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
              ),
              DelegationId(delegation)
            )
    ensures
      StateDelegationProvenance(
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
      )[DelegationId(delegation)] == parentDelegationIds
    ensures DelegationAuthorityIsBounded(
              delegation,
              delegateCapability,
              delegatableAuthority,
              sourceEffectiveAuthority
            )
  {
    RegisterTransitiveDelegationPreservesAuthorizationStateValidity(
      account,
      delegation,
      delegateCapability,
      delegatableAuthority,
      sourceEffectiveAuthority,
      parentDelegationIds,
      identities
    );

    RegisterTransitiveDelegationPreservesAccountValidity(
      account,
      delegation,
      delegateCapability,
      delegatableAuthority,
      sourceEffectiveAuthority,
      parentDelegationIds,
      identities
    );

    RegisterTransitiveDelegationPreservesIdentity(
      account,
      delegation,
      delegateCapability,
      delegatableAuthority,
      sourceEffectiveAuthority,
      parentDelegationIds,
      identities
    );

    RegisteredTransitiveDelegationHasProvenance(
      account,
      delegation,
      delegateCapability,
      delegatableAuthority,
      sourceEffectiveAuthority,
      parentDelegationIds,
      identities
    );

    RegisteredTransitiveDelegationHasDelegateAuthorityFromParents(
      account,
      delegation,
      delegateCapability,
      delegatableAuthority,
      sourceEffectiveAuthority,
      parentDelegationIds,
      identities
    );

    RegisteredTransitiveDelegationRespectsAuthorityBoundary(
      account,
      delegation,
      delegateCapability,
      delegatableAuthority,
      sourceEffectiveAuthority,
      parentDelegationIds,
      identities
    );
  }


  // ============================================================
  // DELEGATION LIFECYCLE
  // ============================================================

  function UpdateDelegationStatus(
    account: Account,
    delegation: Delegation,
    status: DelegationStatus
  ): Account
    requires ValidAccount(account)
    requires delegation
             in StateDelegations(
                  AccountAuthorizationState(account)
                )
    requires ValidDelegationStatusTransition(
               delegation,
               status
             )
  {
    var state := AccountAuthorizationState(account);

    var updatedDelegation :=
      Delegation(
        DelegationId(delegation),
        DelegationSourceIdentityId(delegation),
        DelegationDelegatee(delegation),
        DelegationCapabilities(delegation),
        DelegationValidFrom(delegation),
        DelegationValidUntil(delegation),
        DelegationRestrictions(delegation),
        DelegationMetadata(delegation),
        status
      );

    Account(
      AccountIdOf(account),
      AccountSovereignIdentity(account),
      AuthorizationState(
        StateCapabilities(state),
        StateCredentials(state),
        StateCredentialAuthorities(state),
        StateSessions(state),
        (set registeredDelegation |
         registeredDelegation in StateDelegations(state)
         && DelegationId(registeredDelegation)
            != DelegationId(delegation))
        + { updatedDelegation },
        StateDelegationProvenance(state),
        StateRestrictionMap(state),
        StatePolicyEffects(state),
        StateConsumedReplayKeys(state)
      )
    )
  }


  lemma UpdateDelegationStatusPreservesIdentity(
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
    ensures AccountTransitionPreservesIdentity(
              account,
              UpdateDelegationStatus(
                account,
                delegation,
                status
              )
            )
  {
  }


  lemma UpdatedDelegationRemainsInState(
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
    ensures DelegationIdRecognizedInState(
              AccountAuthorizationState(
                UpdateDelegationStatus(
                  account,
                  delegation,
                  status
                )
              ),
              DelegationId(delegation)
            )
  {
  }


  lemma UpdatedDelegationPreservesEntityIdentity(
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
    ensures exists updatedDelegation ::
              updatedDelegation
              in StateDelegations(
                   AccountAuthorizationState(
                     UpdateDelegationStatus(
                       account,
                       delegation,
                       status
                     )
                   )
                 )
              &&
              DelegationId(updatedDelegation)
              == DelegationId(delegation)
  {
  }


  lemma UpdatedDelegationChangesOnlyLifecycleStatus(
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
    ensures exists updatedDelegation ::
              updatedDelegation
              in StateDelegations(
                   AccountAuthorizationState(
                     UpdateDelegationStatus(
                       account,
                       delegation,
                       status
                     )
                   )
                 )
              &&
              DelegationId(updatedDelegation)
              == DelegationId(delegation)
              &&
              DelegationSourceIdentityId(updatedDelegation)
              == DelegationSourceIdentityId(delegation)
              &&
              DelegationDelegatee(updatedDelegation)
              == DelegationDelegatee(delegation)
              &&
              DelegationCapabilities(updatedDelegation)
              == DelegationCapabilities(delegation)
              &&
              DelegationValidFrom(updatedDelegation)
              == DelegationValidFrom(delegation)
              &&
              DelegationValidUntil(updatedDelegation)
              == DelegationValidUntil(delegation)
              &&
              DelegationRestrictions(updatedDelegation)
              == DelegationRestrictions(delegation)
              &&
              DelegationMetadata(updatedDelegation)
              == DelegationMetadata(delegation)
              &&
              DelegationStatusOf(updatedDelegation)
              == status
  {
  }


  lemma UpdatedDelegationPreservesProvenance(
    account: Account,
    delegation: Delegation,
    status: DelegationStatus
  )
    requires ValidAccount(account)
    requires delegation
             in StateDelegations(
                  AccountAuthorizationState(account)
                )
    requires DelegationProvenanceDefinedForDelegationId(
               AccountAuthorizationState(account),
               DelegationId(delegation)
             )
    requires ValidDelegationStatusTransition(
               delegation,
               status
             )
    ensures StateDelegationProvenance(
              AccountAuthorizationState(
                UpdateDelegationStatus(
                  account,
                  delegation,
                  status
                )
              )
            )[DelegationId(delegation)]
            ==
            StateDelegationProvenance(AccountAuthorizationState(account))
              [DelegationId(delegation)]
  {
  }


  lemma UpdateDelegationStatusPreservesAuthorizationStateValidity(
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
    ensures ValidAuthorizationState(
              AccountAuthorizationState(
                UpdateDelegationStatus(
                  account,
                  delegation,
                  status
                )
              )
            )
  {
    var before := AccountAuthorizationState(account);
    var after := AccountAuthorizationState(
      UpdateDelegationStatus(
        account,
        delegation,
        status
      )
    );

    assert ValidAuthorizationState(before);

    assert ValidCapabilitiesInState(after);
    assert ValidCredentialsInState(after);
    assert CredentialIdsAreUnique(after);

    assert EveryRecognizedCredentialHasAuthority(after);
    assert EveryAuthorityBelongsToRecognizedCredential(after);
    assert CredentialAuthoritiesContainValidAuthorities(after);

    assert ValidSessionsInState(after);
    assert SessionCredentialsBelongToState(after);
    assert SessionIdsAreUnique(after);
    assert SessionAuthoritiesRespectCredentialAuthorities(after);

    assert ValidDelegationsInState(after);
    assert DelegationIdsAreUnique(after);
    assert EveryRecognizedDelegationHasProvenance(after);
    assert EveryDelegationProvenanceBelongsToRecognizedDelegation(after);

    assert ValidRestrictionMapInState(after);

    assert ValidPolicyEffectsInState(after);
    assert ValidReplayState(after);

    assert ValidAuthorizationState(after);
  }


  lemma UpdateDelegationStatusPreservesAccountValidity(
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
    ensures ValidAccount(
              UpdateDelegationStatus(
                account,
                delegation,
                status
              )
            )
  {
    var after := UpdateDelegationStatus(
      account,
      delegation,
      status
    );

    UpdateDelegationStatusPreservesAuthorizationStateValidity(
      account,
      delegation,
      status
    );

    assert AccountTransitionPreservesIdentity(
        account,
        after
      );

    ValidTransitionResultFromPreservedIdentityAndState(
      account,
      after
    );
  }
}

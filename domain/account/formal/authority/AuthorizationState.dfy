// ============================================================
// KIPIO ACCOUNT DOMAIN
// AUTHORITY — AUTHORIZATION STATE
// ============================================================
//
// Authorization State is the operational authorization state
// maintained by one Account.
//
// It is the state from which authority may later be evaluated:
//
//     Authorization State
//              |
//              v
//     Effective Authority
//
// Authorization State therefore does NOT depend on
// EffectiveAuthority.
//
// The state contains:
//
//   - Capabilities available to the Account;
//   - Credentials recognized by the Account;
//   - Credential Authorities associated with those Credentials;
//   - Sessions derived from recognized Credentials;
//   - Delegations;
//   - Delegation provenance relevant to transitive delegation;
//   - Restriction associations between Capability/OptionalScope and
//     Restriction;
//   - Policy Effects recognized by the Account;
//   - consumed Replay Keys.
//
// ------------------------------------------------------------
//
// RESTRICTION ASSOCIATION
// ------------------------------------------------------------
//
// D5 defines the explicit association:
//
//     (Capability × OptionalPolicyScope) -> Restriction
//
// Restriction remains a Value Object and therefore does not contain
// Capability or Scope itself.
//
// AuthorizationState owns this association.
//
// The RestrictionMap is the single source of truth for recognized
// restrictions.
//
// ------------------------------------------------------------
//
// D5 INTEGRITY
// ------------------------------------------------------------
//
// The following invariants are represented by AuthorizationState:
//
//   - every RestrictionMap target is structurally valid;
//   - every RestrictionMap value is structurally valid;
//   - every RestrictionMap target refers to a recognized Capability;
//   - no Restriction exists independently of its target;
//
// The map key itself guarantees that there is at most one value for
// every exact (Capability, OptionalScope) target.
//
// Absence of a target means:
//
//     no additional Restriction
//
// for that Capability/OptionalScope combination.
//
// ------------------------------------------------------------
//
// ENTITY INDEPENDENCE
// ------------------------------------------------------------
//
// Restriction associations are independent of Credential, Session
// and Delegation lifecycle.
//
// A Credential, Session or Delegation transition therefore preserves
// the RestrictionMap unless the transition explicitly targets
// Capability state.
//
// In particular:
//
//     Credential revocation
//         !=
//     automatic Restriction removal
//
// ------------------------------------------------------------
//
// CAPABILITY REMOVAL
// ------------------------------------------------------------
//
// The invariant:
//
//     Capability removed
//          =>
//     all RestrictionMap entries for that Capability removed
//
// belongs to Account transition semantics.
//
// AuthorizationState itself expresses the resulting integrity rule:
//
// no RestrictionMap target may reference a Capability that is no
// longer recognized.
//
// ------------------------------------------------------------
//
// THIS FILE INTENTIONALLY DOES NOT:
//
//   - apply Policy Effects;
//   - determine Policy ordering;
//   - detect Policy contradiction;
//   - calculate Effective Authority;
//   - evaluate whether a Restriction permits an execution;
//   - perform Authorization Validation;
//   - verify Proof;
//   - perform execution;
//   - perform state mutation.
//
// Those responsibilities belong to higher-level transition,
// validation and execution modules.
//
// ============================================================


// ============================================================
// IMPORTS
// ============================================================

include "../foundation/DomainPrimitives.dfy"
include "../foundation/Identity.dfy"
include "../foundation/Capability.dfy"
include "../foundation/Restriction.dfy"
include "../foundation/Scope.dfy"

include "Credential.dfy"
include "CredentialAuthority.dfy"
include "Session.dfy"
include "Delegation.dfy"

include "../policy/PolicyEffect.dfy"


module KipioAccountAuthorizationState
{
  import opened KipioAccountDomainPrimitives
  import opened KipioAccountIdentity
  import opened KipioAccountCapability
  import opened KipioAccountRestriction
  import opened KipioAccountScope

  import opened KipioAccountCredential
  import opened KipioAccountCredentialAuthority
  import opened KipioAccountSession
  import opened KipioAccountDelegation

  import opened KipioAccountPolicyEffect
  import opened KipioAccountSubject


  // ============================================================
  // RESTRICTION TARGET
  // ============================================================

  // RestrictionTarget identifies the exact semantic target to which
  // a Restriction is associated.
  //
  // The target consists of:
  //
  //     Capability × OptionalPolicyScope
  //
  // Capability remains a Value Object whose semantic value already
  // contains CapabilityKind + Scope.
  //
  // OptionalPolicyScope is the additional target selector defined by
  // PolicyEffect:
  //
  //     NoScope
  //         = general scope
  //
  //     Scoped(S)
  //         = explicitly scoped target
  //
  // The Restriction itself remains a separate Value Object.

  datatype RestrictionTarget =
    RestrictionTarget(
      capability: Capability,
      scope: OptionalPolicyScope
    )


  // RestrictionMap is the canonical restriction association.
  //
  // A map provides:
  //
  //     at most one Restriction per exact target
  //
  // by construction of map key uniqueness.

  type RestrictionMap =
    map<RestrictionTarget, Restriction>


  // ============================================================
  // RESTRICTION TARGET ACCESSORS
  // ============================================================

  function RestrictionTargetCapability(
    target: RestrictionTarget
  ): Capability
  {
    target.capability
  }


  function RestrictionTargetScope(
    target: RestrictionTarget
  ): OptionalPolicyScope
  {
    target.scope
  }


  // ============================================================
  // RESTRICTION TARGET VALIDITY
  // ============================================================

  // A RestrictionTarget is structurally valid when:
  //
  //   - its Capability is valid;
  //   - an explicit Scope, when present, is valid.
  //
  // No additional relationship between the Capability's internal
  // Scope and OptionalPolicyScope is imposed here. The two are
  // distinct components of the D5 association key.

  predicate ValidRestrictionTarget(
    target: RestrictionTarget
  )
  {
    ValidCapability(
      RestrictionTargetCapability(target)
    )
    &&
    match RestrictionTargetScope(target)

    case NoScope =>
      true

    case Scoped(scope) =>
      ValidScope(scope)
  }


  // ============================================================
  // AUTHORIZATION STATE
  // ============================================================

  // AuthorizationState is the operational authorization state
  // belonging to one Account.
  //
  // It is not an independently identified Entity.
  //
  // Account identity and sovereign Identity remain outside the state
  // value because the state belongs to exactly one Account.
  datatype AuthorizationState =
    AuthorizationState(
      capabilities: set<Capability>,
      credentials: set<Credential>,
      credentialAuthorities: map<Id, CredentialAuthority>,
      sessions: set<Session>,
      delegations: set<Delegation>,
      delegationProvenance: map<Id, set<Id>>,
      restrictionMap: RestrictionMap,
      policyEffects: set<PolicyEffect>,
      consumedReplayKeys: set<Id>
    )


  // ============================================================
  // STATE ACCESSORS
  // ============================================================

  function StateCapabilities(
    state: AuthorizationState
  ): set<Capability>
  {
    state.capabilities
  }


  function StateCredentials(
    state: AuthorizationState
  ): set<Credential>
  {
    state.credentials
  }


  function StateCredentialAuthorities(
    state: AuthorizationState
  ): map<Id, CredentialAuthority>
  {
    state.credentialAuthorities
  }


  function StateSessions(
    state: AuthorizationState
  ): set<Session>
  {
    state.sessions
  }


  function StateDelegations(
    state: AuthorizationState
  ): set<Delegation>
  {
    state.delegations
  }


  function StateDelegationProvenance(
    state: AuthorizationState
  ): map<Id, set<Id>>
  {
    state.delegationProvenance
  }


  // Canonical RestrictionMap accessor.
  function StateRestrictionMap(
    state: AuthorizationState
  ): RestrictionMap
  {
    state.restrictionMap
  }


  // ------------------------------------------------------------
  // Derived compatibility view
  // ------------------------------------------------------------
  //
  // StateRestrictions is NOT independent state.
  //
  // It is derived exclusively from RestrictionMap so that the
  // domain has exactly one source of truth for restriction
  // associations.
  //
  // This view intentionally discards the target information and is
  // therefore suitable only where callers need the set of distinct
  // Restriction values rather than their associations.

  function StateRestrictions(
    state: AuthorizationState
  ): set<Restriction>
  {
    set target : RestrictionTarget
      | target in StateRestrictionMap(state).Keys
      :: StateRestrictionMap(state)[target]
  }


  function StatePolicyEffects(
    state: AuthorizationState
  ): set<PolicyEffect>
  {
    state.policyEffects
  }


  function StateConsumedReplayKeys(
    state: AuthorizationState
  ): set<Id>
  {
    state.consumedReplayKeys
  }


  // ============================================================
  // RESTRICTION MAP LOOKUP
  // ============================================================

  // Determines whether an exact RestrictionTarget exists.

  predicate RestrictionDefinedForTarget(
    state: AuthorizationState,
    target: RestrictionTarget
  )
  {
    target in StateRestrictionMap(state).Keys
  }


  // Determines whether a Restriction exists for an exact
  // Capability/OptionalScope target.

  predicate RestrictionDefinedFor(
    state: AuthorizationState,
    capability: Capability,
    scope: OptionalPolicyScope
  )
  {
    RestrictionDefinedForTarget(
      state,
      RestrictionTarget(
        capability,
        scope
      )
    )
  }


  // Returns the Restriction associated with an existing target.

  function StateRestrictionForTarget(
    state: AuthorizationState,
    target: RestrictionTarget
  ): Restriction
    requires RestrictionDefinedForTarget(
               state,
               target
             )
  {
    StateRestrictionMap(state)[target]
  }


  // Returns the Restriction associated with an exact
  // Capability/OptionalScope target.

  function StateRestrictionFor(
    state: AuthorizationState,
    capability: Capability,
    scope: OptionalPolicyScope
  ): Restriction
    requires RestrictionDefinedFor(
               state,
               capability,
               scope
             )
  {
    StateRestrictionMap(state)[
    RestrictionTarget(
      capability,
      scope
    )
    ]
  }


  // ============================================================
  // D5.1 / D5.3 — RESTRICTION MAP INTEGRITY
  // ============================================================

  // The map representation itself guarantees that two distinct
  // values cannot occupy the same exact key.
  //
  // This predicate is retained as an explicit semantic boundary:
  //
  //     one target -> at most one Restriction.
  //
  // The actual uniqueness property is supplied by map semantics.

  predicate RestrictionTargetsAreUnique(
    state: AuthorizationState
  )
  {
    forall left, right ::
      left in StateRestrictionMap(state).Keys
      && right in StateRestrictionMap(state).Keys
      && left == right
      ==> left == right
  }


  // Every RestrictionMap target must reference a Capability that is
  // actually recognized by this Account state.
  //
  // This is D5.3.3.

  predicate RestrictionsBelongToRecognizedCapabilities(
    state: AuthorizationState
  )
  {
    forall target ::
      target in StateRestrictionMap(state).Keys
      ==>
        RestrictionTargetCapability(target)
        in StateCapabilities(state)
  }


  // Every RestrictionMap target must be structurally valid.

  predicate ValidRestrictionTargetsInState(
    state: AuthorizationState
  )
  {
    forall target ::
      target in StateRestrictionMap(state).Keys
      ==>
        ValidRestrictionTarget(target)
  }


  // Every RestrictionMap value must be structurally valid.

  predicate ValidRestrictionValuesInState(
    state: AuthorizationState
  )
  {
    forall target ::
      target in StateRestrictionMap(state).Keys
      ==>
        ValidRestriction(
          StateRestrictionMap(state)[target]
        )
  }


  // No restriction may exist without an associated recognized
  // Capability.
  //
  // This is the explicit semantic form of the no-orphan rule.

  predicate NoOrphanRestrictionsInState(
    state: AuthorizationState
  )
  {
    RestrictionsBelongToRecognizedCapabilities(state)
  }


  // Complete D5 RestrictionMap validity.

  predicate ValidRestrictionMapInState(
    state: AuthorizationState
  )
  {
    ValidRestrictionTargetsInState(state)
    &&
    ValidRestrictionValuesInState(state)
    &&
    NoOrphanRestrictionsInState(state)
  }


  // ============================================================
  // D5 LOOKUP LAWS
  // ============================================================

  // If a Restriction is defined for a target, retrieving that target
  // returns the associated Restriction.

  lemma DefinedRestrictionTargetReturnsItsRestriction(
    state: AuthorizationState,
    target: RestrictionTarget
  )
    requires RestrictionDefinedForTarget(
               state,
               target
             )
    ensures StateRestrictionForTarget(
              state,
              target
            )
            ==
            StateRestrictionMap(state)[target]
  {
  }


  // If a Capability/OptionalScope target is defined, the associated
  // Restriction exists and is retrievable through the same semantic
  // target.

  lemma DefinedRestrictionForReturnsItsRestriction(
    state: AuthorizationState,
    capability: Capability,
    scope: OptionalPolicyScope
  )
    requires RestrictionDefinedFor(
               state,
               capability,
               scope
             )
    ensures StateRestrictionFor(
              state,
              capability,
              scope
            )
            ==
            StateRestrictionMap(state)[
            RestrictionTarget(
              capability,
              scope
            )
            ]
  {
  }


  // Absence of a target explicitly represents the absence of an
  // additional Restriction for that target.

  lemma MissingRestrictionTargetMeansNoAdditionalRestriction(
    state: AuthorizationState,
    capability: Capability,
    scope: OptionalPolicyScope
  )
    requires !RestrictionDefinedFor(
               state,
               capability,
               scope
             )
    ensures
      RestrictionTarget(
        capability,
        scope
      )
      !in StateRestrictionMap(state).Keys
  {
  }


  // ============================================================
  // CREDENTIAL RECOGNITION
  // ============================================================

  predicate CredentialRecognizedInState(
    state: AuthorizationState,
    credential: Credential
  )
  {
    exists registeredCredential ::
      registeredCredential in StateCredentials(state)
      && CredentialId(registeredCredential)
         == CredentialId(credential)
  }


  predicate CredentialIdRecognizedInState(
    state: AuthorizationState,
    credentialId: Id
  )
  {
    exists credential ::
      credential in StateCredentials(state)
      && CredentialId(credential) == credentialId
  }


  // ============================================================
  // SESSION RECOGNITION
  // ============================================================

  predicate SessionIdRecognizedInState(
    state: AuthorizationState,
    sessionId: Id
  )
  {
    exists session ::
      session in StateSessions(state)
      && SessionId(session) == sessionId
  }


  // ============================================================
  // DELEGATION RECOGNITION
  // ============================================================

  predicate DelegationIdRecognizedInState(
    state: AuthorizationState,
    delegationId: Id
  )
  {
    exists delegation ::
      delegation in StateDelegations(state)
      && DelegationId(delegation) == delegationId
  }


  // ============================================================
  // CREDENTIAL AUTHORITY ASSOCIATION
  // ============================================================

  predicate CredentialAuthorityDefinedInState(
    state: AuthorizationState,
    credential: Credential
  )
  {
    CredentialId(credential)
    in StateCredentialAuthorities(state).Keys
  }


  predicate CredentialAuthorityDefinedForCredentialId(
    state: AuthorizationState,
    credentialId: Id
  )
  {
    credentialId
    in StateCredentialAuthorities(state).Keys
  }


  function StateCredentialAuthority(
    state: AuthorizationState,
    credential: Credential
  ): CredentialAuthority
    requires CredentialRecognizedInState(
               state,
               credential
             )
    requires CredentialAuthorityDefinedInState(
               state,
               credential
             )
  {
    StateCredentialAuthorities(state)[
    CredentialId(credential)
    ]
  }


  function StateCredentialAuthorityById(
    state: AuthorizationState,
    credentialId: Id
  ): CredentialAuthority
    requires CredentialIdRecognizedInState(
               state,
               credentialId
             )
    requires CredentialAuthorityDefinedForCredentialId(
               state,
               credentialId
             )
  {
    StateCredentialAuthorities(state)[credentialId]
  }


  // ============================================================
  // DELEGATION PROVENANCE
  // ============================================================

  predicate DelegationProvenanceDefinedInState(
    state: AuthorizationState,
    delegation: Delegation
  )
  {
    DelegationId(delegation)
    in StateDelegationProvenance(state).Keys
  }


  predicate DelegationProvenanceDefinedForDelegationId(
    state: AuthorizationState,
    delegationId: Id
  )
  {
    delegationId
    in StateDelegationProvenance(state).Keys
  }


  function StateDelegationParents(
    state: AuthorizationState,
    delegation: Delegation
  ): set<Id>
    requires DelegationProvenanceDefinedInState(
               state,
               delegation
             )
  {
    StateDelegationProvenance(state)[
    DelegationId(delegation)
    ]
  }


  predicate DelegationHasParentProvenance(
    state: AuthorizationState,
    delegation: Delegation
  )
    requires DelegationProvenanceDefinedInState(
               state,
               delegation
             )
  {
    |StateDelegationParents(state, delegation)| > 0
  }


  predicate DelegationProvenanceParentsBelongToState(
    state: AuthorizationState,
    delegation: Delegation
  )
    requires DelegationProvenanceDefinedInState(
               state,
               delegation
             )
  {
    forall parentId ::
      parentId in StateDelegationParents(state, delegation)
      ==>
        DelegationIdRecognizedInState(
          state,
          parentId
        )
  }


  predicate DelegationProvenanceHasNoSelfReference(
    state: AuthorizationState,
    delegation: Delegation
  )
    requires DelegationProvenanceDefinedInState(
               state,
               delegation
             )
  {
    DelegationId(delegation)
    !in StateDelegationParents(state, delegation)
  }


  predicate DelegationProvenancePreservesAuthorityBoundary(
    state: AuthorizationState,
    delegation: Delegation
  )
    requires DelegationProvenanceDefinedInState(
               state,
               delegation
             )
  {
    |StateDelegationParents(state, delegation)| == 0
    ||
    forall capability ::
      capability in DelegationCapabilities(delegation)
      ==>
        exists parent ::
          parent in StateDelegations(state)
          && DelegationId(parent)
             in StateDelegationParents(
                  state,
                  delegation
                )
          && capability in DelegationCapabilities(parent)
  }


  predicate ValidDelegationProvenanceForDelegation(
    state: AuthorizationState,
    delegation: Delegation
  )
  {
    if DelegationProvenanceDefinedInState(
         state,
         delegation
       )
    then
      DelegationProvenanceParentsBelongToState(
        state,
        delegation
      )
      &&
      DelegationProvenanceHasNoSelfReference(
        state,
        delegation
      )
      &&
      DelegationProvenancePreservesAuthorityBoundary(
        state,
        delegation
      )
    else
      false
  }


  // ============================================================
  // DELEGATION SOURCE / SUBJECT ATTRIBUTION
  // ============================================================

  predicate IdentityIdIsAttributedToSubject(
    identities: set<Identity>,
    identityId: Id,
    subject: Subject
  )
  {
    exists identity ::
      identity in identities
      && IdentityId(identity) == identityId
      && IdentitySubject(identity) == subject
  }


  predicate ParentDelegationSupportsChildSource(
    identities: set<Identity>,
    parent: Delegation,
    child: Delegation
  )
  {
    IdentityIdIsAttributedToSubject(
      identities,
      DelegationSourceIdentityId(child),
      DelegationDelegatee(parent)
    )
  }


  predicate DelegationProvenanceSupportsChildSource(
    state: AuthorizationState,
    identities: set<Identity>,
    delegation: Delegation
  )
    requires DelegationProvenanceDefinedInState(
               state,
               delegation
             )
  {
    if |StateDelegationParents(state, delegation)| == 0
    then
      true
    else
      forall parentId ::
        parentId
        in StateDelegationParents(
             state,
             delegation
           )
        ==>
          exists parent ::
            parent in StateDelegations(state)
            && DelegationId(parent) == parentId
            && ParentDelegationSupportsChildSource(
              identities,
              parent,
              delegation
            )
  }


  predicate ValidDelegationProvenanceAgainstIdentityContext(
    state: AuthorizationState,
    identities: set<Identity>,
    delegation: Delegation
  )
    requires DelegationIdRecognizedInState(
               state,
               DelegationId(delegation)
             )
  {
    DelegationProvenanceDefinedInState(
      state,
      delegation
    )
    &&
    ValidDelegationProvenanceForDelegation(
      state,
      delegation
    )
    &&
    DelegationProvenanceSupportsChildSource(
      state,
      identities,
      delegation
    )
  }


  predicate EveryRecognizedDelegationHasProvenance(
    state: AuthorizationState
  )
  {
    forall delegation ::
      delegation in StateDelegations(state)
      ==> DelegationId(delegation)
          in StateDelegationProvenance(state).Keys
  }


  predicate EveryDelegationProvenanceBelongsToRecognizedDelegation(
    state: AuthorizationState
  )
  {
    forall delegationId ::
      delegationId in StateDelegationProvenance(state).Keys
      ==>
        DelegationIdRecognizedInState(
          state,
          delegationId
        )
  }


  // ============================================================
  // STRUCTURAL STATE VALIDITY
  // ============================================================

  predicate ValidAuthorizationState(
    state: AuthorizationState
  )
  {
    ValidCapabilitiesInState(state)
    &&
    ValidCredentialsInState(state)
    &&
    CredentialIdsAreUnique(state)
    &&
    ValidCredentialAuthoritiesInState(state)

    &&
    ValidSessionsInState(state)
    &&
    SessionCredentialsBelongToState(state)
    &&
    SessionIdsAreUnique(state)
    &&
    SessionAuthoritiesRespectCredentialAuthorities(state)

    &&
    ValidDelegationsInState(state)
    &&
    DelegationIdsAreUnique(state)
    &&
    EveryRecognizedDelegationHasProvenance(state)
    &&
    EveryDelegationProvenanceBelongsToRecognizedDelegation(state)
    &&
    ValidDelegationProvenanceInState(state)

    &&
    ValidRestrictionMapInState(state)

    &&
    ValidPolicyEffectsInState(state)
    &&
    ValidReplayState(state)
  }


  // ============================================================
  // CAPABILITY STATE VALIDITY
  // ============================================================

  predicate ValidCapabilitiesInState(
    state: AuthorizationState
  )
  {
    forall capability ::
      capability in StateCapabilities(state)
      ==> ValidCapability(capability)
  }


  // ============================================================
  // CREDENTIAL STATE VALIDITY
  // ============================================================

  predicate ValidCredentialsInState(
    state: AuthorizationState
  )
  {
    forall credential ::
      credential in StateCredentials(state)
      ==> ValidCredential(credential)
  }


  predicate CredentialIdsAreUnique(
    state: AuthorizationState
  )
  {
    forall left, right ::
      left in StateCredentials(state)
      && right in StateCredentials(state)
      && left != right
      ==> CredentialId(left) != CredentialId(right)
  }


  // ============================================================
  // CREDENTIAL AUTHORITY STATE VALIDITY
  // ============================================================

  predicate EveryRecognizedCredentialHasAuthority(
    state: AuthorizationState
  )
  {
    forall credential ::
      credential in StateCredentials(state)
      ==> CredentialId(credential)
          in StateCredentialAuthorities(state).Keys
  }


  predicate EveryAuthorityBelongsToRecognizedCredential(
    state: AuthorizationState
  )
  {
    forall credentialId ::
      credentialId
      in StateCredentialAuthorities(state).Keys
      ==>
        CredentialIdRecognizedInState(
          state,
          credentialId
        )
  }


  predicate CredentialAuthoritiesContainValidAuthorities(
    state: AuthorizationState
  )
  {
    forall credentialId ::
      credentialId
      in StateCredentialAuthorities(state).Keys
      ==>
        ValidCredentialAuthority(
          StateCredentialAuthorities(state)[credentialId]
        )
  }


  predicate ValidCredentialAuthoritiesInState(
    state: AuthorizationState
  )
  {
    EveryRecognizedCredentialHasAuthority(state)
    &&
    EveryAuthorityBelongsToRecognizedCredential(state)
    &&
    CredentialAuthoritiesContainValidAuthorities(state)
  }


  // ============================================================
  // CREDENTIAL ACTIVITY
  // ============================================================

  predicate ActiveCredentialRecognizedInState(
    state: AuthorizationState,
    credentialId: Id
  )
  {
    exists credential ::
      credential in StateCredentials(state)
      && CredentialId(credential) == credentialId
      && CredentialIsActive(credential)
  }


  predicate RecognizedCredentialIsInactive(
    state: AuthorizationState,
    credentialId: Id
  )
  {
    exists credential ::
      credential in StateCredentials(state)
      && CredentialId(credential) == credentialId
      && CredentialCannotCurrentlyExerciseAuthority(credential)
  }


  // ============================================================
  // SESSION STATE VALIDITY
  // ============================================================

  predicate ValidSessionsInState(
    state: AuthorizationState
  )
  {
    forall session ::
      session in StateSessions(state)
      ==> ValidSession(session)
  }


  predicate SessionCredentialsBelongToState(
    state: AuthorizationState
  )
  {
    forall session ::
      session in StateSessions(state)
      ==>
        CredentialIdRecognizedInState(
          state,
          SessionCredentialId(session)
        )
  }


  predicate SessionCredentialAuthorityIsDefinedInState(
    state: AuthorizationState,
    session: Session
  )
  {
    session in StateSessions(state)
    &&
    CredentialAuthorityDefinedForCredentialId(
      state,
      SessionCredentialId(session)
    )
  }


  predicate SessionAuthoritiesRespectCredentialAuthorities(
    state: AuthorizationState
  )
  {
    forall session ::
      session in StateSessions(state)
      ==>
        if SessionCredentialAuthorityIsDefinedInState(
             state,
             session
           )
        then
          SessionAuthorityWithinCredentialAuthority(
            session,
            StateCredentialAuthorities(state)[
            SessionCredentialId(session)
            ]
          )
        else
          false
  }


  predicate SessionCredentialIsRecognizedInState(
    state: AuthorizationState,
    session: Session
  )
  {
    CredentialIdRecognizedInState(
      state,
      SessionCredentialId(session)
    )
  }


  predicate SessionCanContributeAuthorityAt(
    state: AuthorizationState,
    session: Session,
    now: Timestamp
  )
  {
    session in StateSessions(state)
    &&
    SessionCanCurrentlyExerciseAuthorityAt(
      session,
      now
    )
    &&
    ActiveCredentialRecognizedInState(
      state,
      SessionCredentialId(session)
    )
    &&
    if SessionCredentialAuthorityIsDefinedInState(
         state,
         session
       )
    then
      SessionAuthorityWithinCredentialAuthority(
        session,
        StateCredentialAuthorities(state)[
        SessionCredentialId(session)
        ]
      )
    else
      false
  }


  predicate SessionIdsAreUnique(
    state: AuthorizationState
  )
  {
    forall left, right ::
      left in StateSessions(state)
      && right in StateSessions(state)
      && left != right
      ==> SessionId(left) != SessionId(right)
  }


  // ============================================================
  // DELEGATION STATE VALIDITY
  // ============================================================

  predicate ValidDelegationsInState(
    state: AuthorizationState
  )
  {
    forall delegation ::
      delegation in StateDelegations(state)
      ==> ValidDelegation(delegation)
  }


  predicate DelegationIdsAreUnique(
    state: AuthorizationState
  )
  {
    forall left, right ::
      left in StateDelegations(state)
      && right in StateDelegations(state)
      && left != right
      ==> DelegationId(left) != DelegationId(right)
  }


  predicate ValidDelegationProvenanceInState(
    state: AuthorizationState
  )
  {
    forall delegation ::
      delegation in StateDelegations(state)
      ==>
        ValidDelegationProvenanceForDelegation(
          state,
          delegation
        )
  }


  predicate DelegationCanContributeAuthorityAt(
    state: AuthorizationState,
    delegation: Delegation,
    now: Timestamp
  )
  {
    delegation in StateDelegations(state)
    &&
    DelegationCanCurrentlyExerciseAuthorityAt(
      delegation,
      now
    )
  }


  // ============================================================
  // POLICY EFFECT STATE VALIDITY
  // ============================================================

  predicate ValidPolicyEffectsInState(
    state: AuthorizationState
  )
  {
    forall effect ::
      effect in StatePolicyEffects(state)
      ==> ValidPolicyEffect(effect)
  }


  predicate PolicyEffectRecognizedInState(
    state: AuthorizationState,
    effect: PolicyEffect
  )
  {
    effect in StatePolicyEffects(state)
  }


  // ============================================================
  // REPLAY STATE VALIDITY
  // ============================================================

  predicate ValidReplayState(
    state: AuthorizationState
  )
  {
    forall replayKey ::
      replayKey in StateConsumedReplayKeys(state)
      ==> ValidId(replayKey)
  }


  // ============================================================
  // STATE SELECTION LAWS
  // ============================================================

  lemma StateContainsOnlyValidCapabilities(
    state: AuthorizationState,
    capability: Capability
  )
    requires ValidAuthorizationState(state)
    requires capability in StateCapabilities(state)
    ensures ValidCapability(capability)
  {
  }


  lemma StateContainsOnlyValidCredentials(
    state: AuthorizationState,
    credential: Credential
  )
    requires ValidAuthorizationState(state)
    requires credential in StateCredentials(state)
    ensures ValidCredential(credential)
  {
  }


  lemma StateContainsOnlyValidSessions(
    state: AuthorizationState,
    session: Session
  )
    requires ValidAuthorizationState(state)
    requires session in StateSessions(state)
    ensures ValidSession(session)
  {
  }


  lemma StateContainsOnlyValidDelegations(
    state: AuthorizationState,
    delegation: Delegation
  )
    requires ValidAuthorizationState(state)
    requires delegation in StateDelegations(state)
    ensures ValidDelegation(delegation)
  {
  }


  lemma StateContainsOnlyValidRestrictions(
    state: AuthorizationState,
    restriction: Restriction
  )
    requires ValidAuthorizationState(state)
    requires restriction in StateRestrictions(state)
    ensures ValidRestriction(restriction)
  {
  }


  lemma StateContainsOnlyValidPolicyEffects(
    state: AuthorizationState,
    effect: PolicyEffect
  )
    requires ValidAuthorizationState(state)
    requires effect in StatePolicyEffects(state)
    ensures ValidPolicyEffect(effect)
  {
  }


  lemma StateContainsOnlyValidReplayKeys(
    state: AuthorizationState,
    replayKey: Id
  )
    requires ValidAuthorizationState(state)
    requires replayKey in StateConsumedReplayKeys(state)
    ensures ValidId(replayKey)
  {
  }


  // Every recognized restriction is attached to a recognized
  // Capability through RestrictionMap.

  lemma StateRestrictionHasRecognizedCapability(
    state: AuthorizationState,
    target: RestrictionTarget
  )
    requires ValidAuthorizationState(state)
    requires target in StateRestrictionMap(state).Keys
    ensures
      RestrictionTargetCapability(target)
      in StateCapabilities(state)
  {
  }


  // Every recognized restriction value is valid.

  lemma StateRestrictionValueIsValid(
    state: AuthorizationState,
    target: RestrictionTarget
  )
    requires ValidAuthorizationState(state)
    requires target in StateRestrictionMap(state).Keys
    ensures
      ValidRestriction(
        StateRestrictionMap(state)[target]
      )
  {
  }


  // Every recognized restriction target is structurally valid.

  lemma StateRestrictionTargetIsValid(
    state: AuthorizationState,
    target: RestrictionTarget
  )
    requires ValidAuthorizationState(state)
    requires target in StateRestrictionMap(state).Keys
    ensures ValidRestrictionTarget(target)
  {
  }


  // ============================================================
  // CREDENTIAL → AUTHORITY LAWS
  // ============================================================

  lemma RecognizedCredentialHasCredentialAuthority(
    state: AuthorizationState,
    credential: Credential
  )
    requires ValidAuthorizationState(state)
    requires CredentialRecognizedInState(
               state,
               credential
             )
    ensures CredentialAuthorityDefinedInState(
              state,
              credential
            )
  {
  }


  lemma StateCredentialHasValidAuthority(
    state: AuthorizationState,
    credential: Credential
  )
    requires ValidAuthorizationState(state)
    requires CredentialRecognizedInState(
               state,
               credential
             )
    requires CredentialAuthorityDefinedInState(
               state,
               credential
             )
    ensures ValidCredentialAuthority(
              StateCredentialAuthority(
                state,
                credential
              )
            )
  {
  }


  lemma StateCredentialIdHasValidAuthority(
    state: AuthorizationState,
    credentialId: Id
  )
    requires ValidAuthorizationState(state)
    requires CredentialIdRecognizedInState(
               state,
               credentialId
             )
    requires CredentialAuthorityDefinedForCredentialId(
               state,
               credentialId
             )
    ensures ValidCredentialAuthority(
              StateCredentialAuthorityById(
                state,
                credentialId
              )
            )
  {
  }


  // ============================================================
  // SESSION → CREDENTIAL LAWS
  // ============================================================

  lemma SessionInStateHasCredentialInState(
    state: AuthorizationState,
    session: Session
  )
    requires ValidAuthorizationState(state)
    requires session in StateSessions(state)
    ensures CredentialIdRecognizedInState(
              state,
              SessionCredentialId(session)
            )
  {
  }


  lemma SessionInStateReferencesRecognizedCredential(
    state: AuthorizationState,
    session: Session
  )
    requires ValidAuthorizationState(state)
    requires session in StateSessions(state)
    ensures SessionCredentialIsRecognizedInState(
              state,
              session
            )
  {
  }


  lemma SessionInStateHasCredentialAuthority(
    state: AuthorizationState,
    session: Session
  )
    requires ValidAuthorizationState(state)
    requires session in StateSessions(state)
    ensures SessionCredentialAuthorityIsDefinedInState(
              state,
              session
            )
  {
  }


  lemma SessionInStateRespectsCredentialAuthority(
    state: AuthorizationState,
    session: Session
  )
    requires ValidAuthorizationState(state)
    requires session in StateSessions(state)
    ensures SessionAuthorityWithinCredentialAuthority(
              session,
              StateCredentialAuthorities(state)[
              SessionCredentialId(session)
              ]
            )
  {
  }


  lemma RecognizedSessionHasValidCredentialAuthorityBoundary(
    state: AuthorizationState,
    session: Session
  )
    requires ValidAuthorizationState(state)
    requires session in StateSessions(state)
    ensures SessionCredentialAuthorityIsDefinedInState(
              state,
              session
            )
    ensures SessionAuthorityWithinCredentialAuthority(
              session,
              StateCredentialAuthorities(state)[
              SessionCredentialId(session)
              ]
            )
  {
  }


  // ============================================================
  // DELEGATION PROVENANCE LAWS
  // ============================================================

  lemma RecognizedDelegationHasProvenance(
    state: AuthorizationState,
    delegation: Delegation
  )
    requires ValidAuthorizationState(state)
    requires delegation in StateDelegations(state)
    ensures DelegationProvenanceDefinedInState(
              state,
              delegation
            )
  {
  }


  lemma RecognizedDelegationHasRecognizedParents(
    state: AuthorizationState,
    delegation: Delegation
  )
    requires ValidAuthorizationState(state)
    requires delegation in StateDelegations(state)
    ensures DelegationProvenanceParentsBelongToState(
              state,
              delegation
            )
  {
  }


  lemma DelegationStatePreservesTransitiveAuthorityBoundary(
    state: AuthorizationState,
    delegation: Delegation,
    capability: Capability
  )
    requires ValidAuthorizationState(state)
    requires delegation in StateDelegations(state)
    requires capability in DelegationCapabilities(delegation)
    requires DelegationHasParentProvenance(
               state,
               delegation
             )
    ensures exists parent ::
              parent in StateDelegations(state)
              && DelegationId(parent)
                 in StateDelegationParents(
                      state,
                      delegation
                    )
              && capability in DelegationCapabilities(parent)
  {
  }


  lemma RecognizedDelegationHasStructurallyValidProvenance(
    state: AuthorizationState,
    delegation: Delegation
  )
    requires ValidAuthorizationState(state)
    requires delegation in StateDelegations(state)
    ensures ValidDelegationProvenanceForDelegation(
              state,
              delegation
            )
  {
  }


  lemma RecognizedDelegationHasLegitimateProvenanceAgainstIdentityContext(
    state: AuthorizationState,
    identities: set<Identity>,
    delegation: Delegation
  )
    requires ValidAuthorizationState(state)
    requires DelegationIdRecognizedInState(
               state,
               DelegationId(delegation)
             )
    requires ValidDelegationProvenanceAgainstIdentityContext(
               state,
               identities,
               delegation
             )
    ensures DelegationProvenanceSupportsChildSource(
              state,
              identities,
              delegation
            )
  {
  }


  // ============================================================
  // ENTITY IDENTITY LAWS
  // ============================================================

  lemma DistinctStateCredentialsHaveDistinctIds(
    state: AuthorizationState,
    left: Credential,
    right: Credential
  )
    requires ValidAuthorizationState(state)
    requires left in StateCredentials(state)
    requires right in StateCredentials(state)
    requires left != right
    ensures CredentialId(left) != CredentialId(right)
  {
  }


  lemma DistinctStateSessionsHaveDistinctIds(
    state: AuthorizationState,
    left: Session,
    right: Session
  )
    requires ValidAuthorizationState(state)
    requires left in StateSessions(state)
    requires right in StateSessions(state)
    requires left != right
    ensures SessionId(left) != SessionId(right)
  {
  }


  lemma DistinctStateDelegationsHaveDistinctIds(
    state: AuthorizationState,
    left: Delegation,
    right: Delegation
  )
    requires ValidAuthorizationState(state)
    requires left in StateDelegations(state)
    requires right in StateDelegations(state)
    requires left != right
    ensures DelegationId(left) != DelegationId(right)
  {
  }


  // ============================================================
  // ENTITY IDENTITY / RECOGNITION SEPARATION
  // ============================================================

  lemma RevokedCredentialRemainsRecognized(
    state: AuthorizationState,
    credential: Credential
  )
    requires ValidAuthorizationState(state)
    requires credential in StateCredentials(state)
    requires CredentialIsRevoked(credential)
    ensures CredentialIdRecognizedInState(
              state,
              CredentialId(credential)
            )
  {
  }


  lemma RevokedSessionRemainsRecognized(
    state: AuthorizationState,
    session: Session
  )
    requires ValidAuthorizationState(state)
    requires session in StateSessions(state)
    requires SessionIsRevoked(session)
    ensures SessionIdRecognizedInState(
              state,
              SessionId(session)
            )
  {
  }


  lemma RevokedDelegationRemainsRecognized(
    state: AuthorizationState,
    delegation: Delegation
  )
    requires ValidAuthorizationState(state)
    requires delegation in StateDelegations(state)
    requires DelegationIsRevoked(delegation)
    ensures DelegationIdRecognizedInState(
              state,
              DelegationId(delegation)
            )
  {
  }
}

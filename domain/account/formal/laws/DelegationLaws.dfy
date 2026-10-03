// ============================================================
// KIPIO ACCOUNT DOMAIN
// LAWS — DELEGATION
// ============================================================
//
// Cross-concept semantic laws governing Delegation.
//
// Delegation.dfy defines the local semantics of the Delegation
// Entity:
//
//   - Delegation identity;
//   - source Identity reference;
//   - Delegatee Subject;
//   - delegated Capability set;
//   - lifecycle;
//   - temporal validity;
//   - local delegation authority boundaries.
//
// AuthorizationState.dfy defines:
//
//   - Delegation recognition;
//   - provenance storage;
//   - provenance integrity;
//   - identity-context attribution.
//
// AccountTransitions.dfy defines:
//
//   - root Delegation registration;
//   - transitive Delegation registration;
//   - lifecycle transitions;
//   - preservation of Account identity;
//   - preservation of Authorization State validity.
//
// EffectiveAuthority.dfy defines contextual authority values.
//
// This file therefore does NOT duplicate those local or
// transition-level laws.
//
// Instead, it formalizes consequences that require Delegation to
// be considered across Account, AuthorizationState, Identity
// context and authority provenance boundaries.
//
// ------------------------------------------------------------
//
// RESPONSIBILITY BOUNDARY
//
// This file does NOT:
//
//   - define the Delegation datatype;
//   - define Delegation lifecycle;
//   - define Delegation local validity;
//   - calculate Effective Authority;
//   - calculate Delegatable Authority;
//   - define AuthorizationState;
//   - implement Account transitions;
//   - verify Proof;
//   - perform Authorization Validation;
//   - apply Policy;
//   - perform execution;
//   - introduce a new provenance datatype.
//
// ------------------------------------------------------------
//
// CENTRAL DDD PRINCIPLES
//
// Delegation preserves the following distinctions:
//
//     Delegation identity
//         !=
//     Account sovereignty
//
//     Delegation source Identity
//         !=
//     Account sovereignty in general
//
//     Delegated Authority
//         ⊆
//     Delegatable Authority
//
//     Delegatable Authority
//         ⊆
//     Effective Authority(source)
//
// and, for transitive delegation:
//
//     Child Authority
//         ⊆
//     Parent Delegated Authority
//
// Provenance constrains only the authority derived through the
// corresponding delegation chain.
//
// Multiple independent authority sources may coexist.
//
// ------------------------------------------------------------
//
// DESIGN PRINCIPLE
//
// DelegationLaws contains only cross-concept consequences.
//
// Local Delegation laws remain in Delegation.dfy.
// Account-state invariants remain in AuthorizationState.dfy.
// Concrete state transformations remain in AccountTransitions.dfy.
//
// ============================================================

include "../foundation/DomainPrimitives.dfy"
include "../foundation/Capability.dfy"
include "../foundation/Identity.dfy"

include "../authority/Delegation.dfy"
include "../authority/EffectiveAuthority.dfy"
include "../authority/AuthorizationState.dfy"

include "../account/Account.dfy"
include "../account/AccountTransitions.dfy"

module KipioAccountDelegationLaws
{
  import opened KipioAccountDomainPrimitives
  import opened KipioAccountCapability
  import opened KipioAccountIdentity
  import opened KipioAccountDelegation
  import opened KipioAccountEffectiveAuthority
  import opened KipioAccountAuthorizationState
  import opened KipioAccountAccount
  import opened KipioAccountAccountTransitions


  // ----------------------------------------------------------
  // D1 — DELEGATION DOES NOT TRANSFER SOVEREIGNTY
  // ----------------------------------------------------------

  // Registering a root Delegation preserves the Account's Entity
  // identity and sovereign Identity.
  //
  // The transition itself is responsible for constructing the new
  // Account value; this law exposes the cross-concept consequence
  // that Delegation registration does not transfer sovereignty.
  lemma RegisterDelegationPreservesAccountSovereignty(
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


  // Registration of a root Delegation cannot create a second
  // sovereign Identity because the resulting Account preserves the
  // original sovereign Identity.
  lemma DelegationRegistrationDoesNotCreateSecondSovereignIdentity(
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
    ensures AccountSovereignIdentity(
              RegisterDelegation(
                account,
                delegation,
                delegateCapability,
                delegatableAuthority,
                sourceEffectiveAuthority
              )
            )
            ==
            AccountSovereignIdentity(account)
  {
  }


  // ----------------------------------------------------------
  // D1 — ROOT DELEGATION SOURCE
  // ----------------------------------------------------------

  // A valid root Delegation registered through AccountTransitions
  // has the Account's sovereign Identity as its source.
  //
  // The root-source rule is an Account/Delegation cross-concept
  // constraint and therefore belongs here rather than in the local
  // Delegation representation.
  lemma RegisteredRootDelegationUsesSovereignSource(
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
    ensures DelegationSourceIdentityId(delegation)
            ==
            IdentityId(AccountSovereignIdentity(account))
  {
  }


  // ----------------------------------------------------------
  // D1 — COMBINED AUTHORITY BOUNDARY
  // ----------------------------------------------------------

  // A root Delegation accepted by AccountTransitions satisfies the
  // complete authority boundary:
  //
  //     Delegate ∈ EffectiveAuthority(source)
  //
  //     DelegatedAuthority
  //         ⊆
  //     DelegatableAuthority
  //
  //     DelegatableAuthority
  //         ⊆
  //     EffectiveAuthority(source)
  //
  // The individual predicates belong to the authority modules;
  // this theorem exposes their composition at the registration
  // boundary.
  lemma RegisteredRootDelegationRespectsAuthorityBoundary(
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
    ensures DelegationAuthorityIsBounded(
              delegation,
              delegateCapability,
              delegatableAuthority,
              sourceEffectiveAuthority
            )
  {
  }


  // ----------------------------------------------------------
  // D1 — ROOT REGISTRATION / STATE RECOGNITION
  // ----------------------------------------------------------

  // A successfully registered root Delegation becomes recognized
  // by its stable DelegationId in the resulting Authorization State.
  lemma RegisteredRootDelegationBecomesRecognized(
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


  // A root Delegation receives empty parent provenance because its
  // source is the Account's sovereign Identity rather than another
  // Delegation in the same Account.
  lemma RegisteredRootDelegationHasEmptyProvenance(
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
      )[DelegationId(delegation)]
      == {}
  {
  }


  // ----------------------------------------------------------
  // D1 — TRANSITIVE DELEGATION / SOURCE ATTRIBUTION
  // ----------------------------------------------------------

  // A transitive Delegation is supported by recognized parent
  // Delegations whose delegatee Subject corresponds to the child
  // source Identity attribution.
  //
  // This is a genuine cross-concept law because it composes:
  //
  //     Delegation
  //         +
  //     AuthorizationState
  //         +
  //     Identity/Subject attribution
  lemma RegisteredTransitiveDelegationPreservesParentSourceAttribution(
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


  // ----------------------------------------------------------
  // D1 — TRANSITIVE DELEGATION / AUTHORITY NON-EXPANSION
  // ----------------------------------------------------------

  // Every Capability of a transitive Delegation must already be
  // present in at least one recognized parent Delegation explicitly
  // named by its provenance.
  //
  // This prevents a transitive Delegation from inventing authority
  // that is absent from its provenance chain.
  lemma RegisteredTransitiveDelegationCannotInventCapability(
    account: Account,
    delegation: Delegation,
    delegateCapability: Capability,
    delegatableAuthority: set<Capability>,
    sourceEffectiveAuthority: EffectiveAuthority,
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
                    AccountAuthorizationState(account)
                  )
        &&
        DelegationId(parent) in parentDelegationIds
        &&
        capability in DelegationCapabilities(parent)
  {
  }


  // A transitive Delegation's authority remains bounded by the
  // supplied Delegatable Authority and the source Effective
  // Authority.
  lemma RegisteredTransitiveDelegationRespectsAuthorityBoundary(
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
    ensures DelegationAuthorityWithinDelegatableAuthority(
              delegation,
              delegatableAuthority
            )
    ensures DelegatableAuthorityWithinEffectiveAuthority(
              delegatableAuthority,
              sourceEffectiveAuthority
            )
    ensures SourceHasDelegationCapability(
              sourceEffectiveAuthority,
              delegateCapability
            )
  {
  }


  // ----------------------------------------------------------
  // D1 — TRANSITIVE REGISTRATION / STATE PROVENANCE
  // ----------------------------------------------------------

  // The provenance supplied for a transitive Delegation is preserved
  // in Authorization State under the Delegation's stable identity.
  lemma RegisteredTransitiveDelegationPreservesProvenance(
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
      )[DelegationId(delegation)]
      == parentDelegationIds
  {
  }


  // A transitive Delegation registered with valid provenance becomes
  // recognized by its DelegationId in the resulting state.
  lemma RegisteredTransitiveDelegationBecomesRecognized(
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
  {
  }


  // ----------------------------------------------------------
  // D1 — TRANSITIVE REGISTRATION / SOVEREIGNTY
  // ----------------------------------------------------------

  // Registering a transitive Delegation also preserves the Account
  // sovereign Identity. A transitive delegation therefore cannot
  // promote the Delegatee or child source into Account sovereignty.
  lemma RegisteredTransitiveDelegationDoesNotChangeSovereignIdentity(
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
    ensures AccountSovereignIdentity(
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
            ==
            AccountSovereignIdentity(account)
  {
  }


  // ----------------------------------------------------------
  // D1 — LIFECYCLE / ENTITY IDENTITY
  // ----------------------------------------------------------

  // Updating the lifecycle status of a recognized Delegation
  // preserves its semantic Entity identity because the same
  // DelegationId remains associated with the updated value.
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
              SameDelegation(
                updatedDelegation,
                delegation
              )
  {
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

    var updatedAccount :=
      UpdateDelegationStatus(
        account,
        delegation,
        status
      );

    var updatedState :=
      AccountAuthorizationState(updatedAccount);

    assert SameDelegation(
        updatedDelegation,
        delegation
      );

    assert updatedDelegation
           in StateDelegations(updatedState);

    assert exists candidate ::
        candidate in StateDelegations(updatedState)
        &&
        SameDelegation(
          candidate,
          delegation
        );
  }


  // Lifecycle changes preserve the Delegation provenance entry
  // because provenance is keyed by the stable DelegationId.
  lemma DelegationLifecyclePreservesProvenance(
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
            StateDelegationProvenance(
              AccountAuthorizationState(account)
            )[DelegationId(delegation)]
  {
  }


  // A lifecycle update preserves state recognition of the same
  // Delegation Entity.
  lemma UpdatedDelegationRemainsRecognized(
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


  // ----------------------------------------------------------
  // D1 — REVOCATION / RECOGNITION SEPARATION
  // ----------------------------------------------------------

  // Revocation changes current usability but does not remove the
  // Delegation Entity from Authorization State recognition.
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

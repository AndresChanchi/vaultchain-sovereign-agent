// ============================================================
// KIPIO ACCOUNT DOMAIN
// SCENARIO — ENTERPRISE PROOF
// ============================================================
//
// Enterprise / B2B adversarial scenario.
//
// Primary boundary under attack:
//
//     transitive delegation must not expand authority.
//
// This scenario is intentionally different from DeFiProof.
//
// DeFiProof attacks:
//
//     supplied EffectiveAuthority
//         +
//     missing provenance linking that authority
//     to the recognized Credential.
//
// EnterpriseProof attacks:
//
//     transitive Delegation
//         +
//     explicit parent provenance
//         +
//     child Capability absent from EVERY provenance parent.
//
// Adversarial shape:
//
//     Parent 1 authority = { A }
//     Parent 2 authority = { A }        // optional second parent
//     Child authority    = { A, B }
//     B                  ∉ every parent
//
// Expected semantic result:
//
//     RegisterTransitiveDelegation(...)
//
//     MUST be impossible.
//
// The intended boundary is:
//
//     Child Delegation Capability
//              ⊆
//     Capability represented by provenance parents
//
// Multiple parents are allowed.
//
// The rule is capability-wise:
//
//     every child Capability
//         must be justified by
//         at least one provenance parent.
//
// ============================================================


include "../../foundation/DomainPrimitives.dfy"
include "../../foundation/Identity.dfy"
include "../../foundation/Capability.dfy"
include "../../foundation/Scope.dfy"
include "../../foundation/Restriction.dfy"

include "../../authority/Delegation.dfy"
include "../../authority/EffectiveAuthority.dfy"
include "../../authority/Credential.dfy"
include "../../authority/CredentialAuthority.dfy"
include "../../authority/Session.dfy"
include "../../authority/AuthorizationState.dfy"

include "../../account/Account.dfy"
include "../../account/AccountTransitions.dfy"

include "../../laws/DelegationLaws.dfy"

include "../isolated/AuthorityProofs.dfy"


module KipioAccountEnterpriseProof
{
  import opened KipioAccountDomainPrimitives
  import opened KipioAccountIdentity
  import opened KipioAccountCapability
  import opened KipioAccountScope
  import opened KipioAccountRestriction

  import opened KipioAccountDelegation
  import opened KipioAccountEffectiveAuthority
  import opened KipioAccountCredential
  import opened KipioAccountCredentialAuthority
  import opened KipioAccountSession
  import opened KipioAccountAuthorizationState

  import opened KipioAccountAccount
  import opened KipioAccountAccountTransitions

  // Do not open KipioAccountDelegationLaws here.
  //
  // DelegationLaws.dfy and AuthorityProofs.dfy expose overlapping
  // theorem names. EnterpriseProof uses the isolated Authority
  // proofs plus the concrete Account transition layer.

  import opened KipioAccountAuthorityProofs


  // ============================================================
  // LEVEL 1 — ABSTRACT NON-EXPANSION
  // ============================================================

  lemma EnterpriseChildCapabilityMustExistInParentAuthority(
    childAuthority: set<Capability>,
    parentAuthority: set<Capability>,
    capability: Capability
  )
    requires TransitiveDelegationAuthorityIsBounded(
               childAuthority,
               parentAuthority
             )
    requires capability in childAuthority
    ensures capability in parentAuthority
  {
    ChildDelegationCannotEscapeParent(
      childAuthority,
      parentAuthority,
      capability
    );
  }


  lemma EnterpriseChildCannotIntroduceCapabilityOutsideParent(
    childAuthority: set<Capability>,
    parentAuthority: set<Capability>,
    capability: Capability
  )
    requires capability in childAuthority
    requires capability !in parentAuthority
    ensures !TransitiveDelegationAuthorityIsBounded(
              childAuthority,
              parentAuthority
            )
  {
    if TransitiveDelegationAuthorityIsBounded(
        childAuthority,
        parentAuthority
      )
    {
      EnterpriseChildCapabilityMustExistInParentAuthority(
        childAuthority,
        parentAuthority,
        capability
      );

      assert capability in parentAuthority;
    }
  }


  // ============================================================
  // LEVEL 2 — PROVENANCE AS THE STATE BOUNDARY
  // ============================================================

  lemma EnterpriseProvenanceJustifiesEveryChildCapability(
    state: AuthorizationState,
    child: Delegation,
    capability: Capability
  )
    requires ValidAuthorizationState(state)
    requires child in StateDelegations(state)
    requires capability in DelegationCapabilities(child)
    requires DelegationHasParentProvenance(
               state,
               child
             )
    ensures exists parent ::
              parent in StateDelegations(state)
              && DelegationId(parent)
                 in StateDelegationParents(
                      state,
                      child
                    )
              && capability in DelegationCapabilities(parent)
  {
    ProvenanceCannotInventDelegatedCapability(
      state,
      child,
      capability
    );
  }


  lemma EnterpriseProvenanceParentsAreRecognized(
    state: AuthorizationState,
    child: Delegation
  )
    requires ValidAuthorizationState(state)
    requires child in StateDelegations(state)
    requires DelegationHasParentProvenance(
               state,
               child
             )
    ensures DelegationProvenanceParentsBelongToState(
              state,
              child
            )
  {
    RecognizedDelegationParentsAreRecognized(
      state,
      child
    );
  }


  lemma EnterpriseChildCannotSelfJustifyAuthority(
    state: AuthorizationState,
    child: Delegation
  )
    requires ValidAuthorizationState(state)
    requires child in StateDelegations(state)
    requires DelegationHasParentProvenance(
               state,
               child
             )
    ensures DelegationProvenanceHasNoSelfReference(
              state,
              child
            )
  {
    RecognizedDelegationCannotSelfReferenceProvenance(
      state,
      child
    );
  }


  // ============================================================
  // LEVEL 3 — CORE ADVERSARIAL STATE ATTACK
  // ============================================================

  lemma EnterpriseUnjustifiedChildCapabilityIsImpossible(
    state: AuthorizationState,
    child: Delegation,
    capability: Capability
  )
    requires ValidAuthorizationState(state)
    requires child in StateDelegations(state)
    requires capability in DelegationCapabilities(child)
    requires DelegationHasParentProvenance(
               state,
               child
             )
    requires forall parent ::
               parent in StateDelegations(state)
               && DelegationId(parent)
                  in StateDelegationParents(
                       state,
                       child
                     )
               ==>
                 capability !in DelegationCapabilities(parent)
    ensures false
  {
    EnterpriseProvenanceJustifiesEveryChildCapability(
      state,
      child,
      capability
    );

    assert exists parent ::
        parent in StateDelegations(state)
        && DelegationId(parent)
           in StateDelegationParents(
                state,
                child
              )
        && capability in DelegationCapabilities(parent);

    assert forall parent ::
        parent in StateDelegations(state)
        && DelegationId(parent)
           in StateDelegationParents(
                state,
                child
              )
        ==>
          capability !in DelegationCapabilities(parent);

    assert false;
  }


  // ============================================================
  // LEVEL 4 — TRANSITION PRECONDITION ATTACK
  // ============================================================

  lemma EnterpriseForeignCapabilityBlocksTransitiveRegistration(
    account: Account,
    delegation: Delegation,
    delegatableAuthority: set<Capability>,
    parentDelegationIds: set<Id>,
    capability: Capability
  )
    requires ValidAccount(account)
    requires ValidDelegation(delegation)
    requires DelegationAuthorityWithinDelegatableAuthority(
               delegation,
               delegatableAuthority
             )
    requires !DelegationIdRecognizedInState(
               AccountAuthorizationState(account),
               DelegationId(delegation)
             )
    requires capability in DelegationCapabilities(delegation)
    requires forall parent ::
               parent in StateDelegations(
                           AccountAuthorizationState(account)
                         )
               && DelegationId(parent) in parentDelegationIds
               ==>
                 capability !in DelegationCapabilities(parent)
    ensures !ParentDelegationsBoundNewDelegation(
              AccountAuthorizationState(account),
              delegation,
              parentDelegationIds
            )
  {
    if ParentDelegationsBoundNewDelegation(
        AccountAuthorizationState(account),
        delegation,
        parentDelegationIds
      )
    {
      assert exists parent ::
          parent in StateDelegations(
                      AccountAuthorizationState(account)
                    )
          && DelegationId(parent) in parentDelegationIds
          && capability in DelegationCapabilities(parent);

      assert forall parent ::
          parent in StateDelegations(
                      AccountAuthorizationState(account)
                    )
          && DelegationId(parent) in parentDelegationIds
          ==>
            capability !in DelegationCapabilities(parent);

      assert false;
    }
  }


  // ============================================================
  // LEVEL 5 — NO REACHABLE ATTACK INSTANCE
  // ============================================================

  lemma EnterpriseForeignCapabilityCannotBeReachablyRegistered(
    account: Account,
    delegation: Delegation,
    delegatableAuthority: set<Capability>,
    parentDelegationIds: set<Id>,
    capability: Capability
  )
    requires ValidAccount(account)
    requires ValidDelegation(delegation)
    requires DelegationAuthorityWithinDelegatableAuthority(
               delegation,
               delegatableAuthority
             )
    requires !DelegationIdRecognizedInState(
               AccountAuthorizationState(account),
               DelegationId(delegation)
             )
    requires capability in DelegationCapabilities(delegation)
    requires forall parent ::
               parent in StateDelegations(
                           AccountAuthorizationState(account)
                         )
               && DelegationId(parent) in parentDelegationIds
               ==>
                 capability !in DelegationCapabilities(parent)
    requires ParentDelegationsBoundNewDelegation(
               AccountAuthorizationState(account),
               delegation,
               parentDelegationIds
             )
    ensures false
  {
    assert exists parent ::
        parent in StateDelegations(
                    AccountAuthorizationState(account)
                  )
        && DelegationId(parent) in parentDelegationIds
        && capability in DelegationCapabilities(parent);

    assert forall parent ::
        parent in StateDelegations(
                    AccountAuthorizationState(account)
                  )
        && DelegationId(parent) in parentDelegationIds
        ==>
          capability !in DelegationCapabilities(parent);

    assert false;
  }


  // ============================================================
  // LEVEL 6 — SUCCESSFUL TRANSITION PRESERVES THE BOUNDARY
  // ============================================================

  lemma EnterpriseSuccessfulTransitionMustHaveCapabilityWitness(
    account: Account,
    delegation: Delegation,
    delegatableAuthority: set<Capability>,
    parentDelegationIds: set<Id>,
    capability: Capability
  )
    requires ValidAccount(account)
    requires ValidDelegation(delegation)
    requires DelegationAuthorityWithinDelegatableAuthority(
               delegation,
               delegatableAuthority
             )
    requires !DelegationIdRecognizedInState(
               AccountAuthorizationState(account),
               DelegationId(delegation)
             )
    requires ParentDelegationsBoundNewDelegation(
               AccountAuthorizationState(account),
               delegation,
               parentDelegationIds
             )
    requires capability in DelegationCapabilities(delegation)
    ensures exists parent ::
              parent in StateDelegations(
                          AccountAuthorizationState(account)
                        )
              && DelegationId(parent) in parentDelegationIds
              && capability in DelegationCapabilities(parent)
  {
    assert exists parent ::
        parent in StateDelegations(
                    AccountAuthorizationState(account)
                  )
        && DelegationId(parent) in parentDelegationIds
        && capability in DelegationCapabilities(parent);
  }


  // ============================================================
  // LEVEL 7 — MULTI-PARENT SEMANTICS
  // ============================================================

  lemma EnterpriseMultiParentCapabilityIsNotSingleParentBound(
    account: Account,
    delegation: Delegation,
    delegatableAuthority: set<Capability>,
    parentDelegationIds: set<Id>,
    capability: Capability
  )
    requires ValidAccount(account)
    requires ValidDelegation(delegation)
    requires DelegationAuthorityWithinDelegatableAuthority(
               delegation,
               delegatableAuthority
             )
    requires !DelegationIdRecognizedInState(
               AccountAuthorizationState(account),
               DelegationId(delegation)
             )
    requires ParentDelegationsBoundNewDelegation(
               AccountAuthorizationState(account),
               delegation,
               parentDelegationIds
             )
    requires capability in DelegationCapabilities(delegation)
    ensures exists parent ::
              parent in StateDelegations(
                          AccountAuthorizationState(account)
                        )
              && DelegationId(parent) in parentDelegationIds
              && capability in DelegationCapabilities(parent)
  {
    assert exists parent ::
        parent in StateDelegations(
                    AccountAuthorizationState(account)
                  )
        && DelegationId(parent) in parentDelegationIds
        && capability in DelegationCapabilities(parent);
  }


  // ============================================================
  // LEVEL 8 — LIFECYCLE CANNOT BYPASS PROVENANCE
  // ============================================================

  // Updating Delegation lifecycle state does not erase provenance
  // because provenance is keyed by stable DelegationId.
  //
  // The transition operates on the actual recognized Delegation
  // Entity, not merely on an already-recognized identifier.
  //
  // The proof therefore exposes the current Entity-level transition
  // contract and the preservation of its provenance entry.

  lemma EnterpriseLifecycleCannotEraseDelegationProvenance(
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
    ensures
      StateDelegationProvenance(
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
    var state := AccountAuthorizationState(account);

    assert delegation in StateDelegations(state);
    assert DelegationProvenanceDefinedForDelegationId(
        state,
        DelegationId(delegation)
      );

    KipioAccountAuthorityProofs.DelegationLifecyclePreservesProvenance(
      account,
      delegation,
      status
    );
  }


  // ============================================================
  // LEVEL 9 — CANONICAL ENTERPRISE ATTACK
  // ============================================================

  lemma EnterpriseCanonicalForeignCapabilityAttackIsRejected(
    account: Account,
    delegation: Delegation,
    delegatableAuthority: set<Capability>,
    parentDelegationIds: set<Id>,
    capabilityA: Capability,
    capabilityB: Capability
  )
    requires ValidAccount(account)
    requires ValidDelegation(delegation)
    requires DelegationAuthorityWithinDelegatableAuthority(
               delegation,
               delegatableAuthority
             )
    requires !DelegationIdRecognizedInState(
               AccountAuthorizationState(account),
               DelegationId(delegation)
             )
    requires capabilityA in DelegationCapabilities(delegation)
    requires capabilityB in DelegationCapabilities(delegation)
    requires capabilityA != capabilityB
    requires forall parent ::
               parent in StateDelegations(
                           AccountAuthorizationState(account)
                         )
               && DelegationId(parent) in parentDelegationIds
               ==>
                 capabilityB !in DelegationCapabilities(parent)
    ensures !ParentDelegationsBoundNewDelegation(
              AccountAuthorizationState(account),
              delegation,
              parentDelegationIds
            )
  {
    EnterpriseForeignCapabilityBlocksTransitiveRegistration(
      account,
      delegation,
      delegatableAuthority,
      parentDelegationIds,
      capabilityB
    );
  }


  // ============================================================
  // FINAL ENTERPRISE PROPERTY
  // ============================================================

  // Final Enterprise property:
  //
  //     A transitive Delegation may only propagate Capabilities
  //     justified by its recognized provenance parents.
  //
  // Therefore:
  //
  //     Capability in child
  //     +
  //     Capability absent from every parent
  //     +
  //     successful registration
  //
  //     ==> contradiction.
  //
  // The scenario does NOT assume:
  //
  //     - a single parent;
  //     - a single authority source;
  //     - global EffectiveAuthority provenance.
  //
  // It specifically attacks:
  //
  //     delegation provenance
  //             +
  //     non-expansion.
}

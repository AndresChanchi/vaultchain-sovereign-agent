//! Integration tests for the ABI ↔ Dafny bridge.
//!
//! These tests validate the bridge as a pure translation layer:
//! no Stylus VM is involved, no storage, no cross-contract calls.
//!
//! Coverage:
//!   1. Roundtrip / structural validators (base).
//!   2. PolicyConsumption signal (applied / rejected).
//!   3. All six PolicyEffect kinds.
//!   4. Provisioning — happy path.
//!   5. Provisioning — rejection on preconditions.
//!   6. Post-transition invariants — ValidAccount.
//!   7. New provisioning entrypoints — happy path.
//!   8. New provisioning entrypoints — rejection.
//!   9. Total transitions — RemoveRestriction / RemoveCapability semantics.
//!  10. OptionalScopeAbi — the Scoped path.
//!  11. RemoveCapability cascades (D5.3.2).
//!  12. Full ABI roundtrip with populated state.
//!  13. Execution Context — ValidExecutionContextForAccountFull.
//!  14. EffectiveAuthority derivation — compute_effective_authority.
//!  15. DDD property coverage — crown success, D2 atomicity, D3.6.1/D3.6.2
//!      propagation, D1.17 multi-source, D1.24 transitive delegation,
//!      integrated replay protection.
//!  16. Edge cases and boundary tests — requested authority containment,
//!      suspended credential usability, inclusive temporal boundaries,
//!      idempotency, selective revocation, transitive monotonicity,
//!      identity attribution requirements.
//!  17. DDD law completeness — D2.6.1 contradictory effects, heterogeneous
//!      policy effects, D4.5.3 replay at the Execution Context boundary.
//!  18. Additional edge cases — multi-parent transitive delegation,
//!      account-id context match, unrecognized credential at the crown,
//!      delegation temporal expiration, empty credential authority,
//!      credential authority idempotency, EA set-union semantics.

use stylus_sdk::abi::Bytes;
use stylus_sdk::alloy_primitives::U256;

use kipio_stylus_harness::dafny_bridge::{
    account_from_abi, account_to_abi, add_capability_impl,
    apply_policy_consumption_impl, authorization_can_be_accepted_full_impl,
    authorization_is_structurally_valid_impl, compute_effective_authority_impl,
    consume_replay_key_impl, empty_capability_abi, empty_optional_scope_abi,
    empty_restriction_abi, empty_scope_abi, register_credential_impl,
    register_delegation_impl, register_session_impl,
    register_transitive_delegation_impl, remove_capability_impl,
    remove_restriction_impl, set_credential_authority_impl, set_restriction_impl,
    update_credential_status_impl, update_delegation_status_impl,
    update_session_status_impl, valid_account_impl, valid_authorization_state_impl,
    valid_execution_context_impl, AccountAbi, AuthorizationAbi, AuthorizationStateAbi,
    CapabilityAbi, CapabilityKindAbi, CredentialAbi, DelegationAbi, ExecutionContextAbi,
    ExecutionRequestAbi, IdentityAbi, OptionalScopeAbi, PolicyAbi, PolicyConsumptionAbi,
    PolicyEffectAbi, RestrictionAbi, RestrictionKindAbi, ScopeAbi, ScopeAtomAbi,
    SessionAbi, SubjectAbi,
};

// ============================================================================
// Fixtures
// ============================================================================

fn empty_auth_state() -> AuthorizationStateAbi {
    AuthorizationStateAbi {
        capabilities: vec![],
        credentials: vec![],
        credentialAuthorities: vec![],
        sessions: vec![],
        delegations: vec![],
        delegationProvenance: vec![],
        restrictionMap: vec![],
        policyEffects: vec![],
        consumedReplayKeys: vec![],
    }
}

fn empty_account() -> AccountAbi {
    AccountAbi {
        id: Bytes::from(vec![1u8, 2, 3, 4]),
        identity: IdentityAbi {
            id: Bytes::from(vec![5u8, 6, 7, 8]),
            subject: SubjectAbi {
                reference: Bytes::from(vec![9u8, 10u8]),
            },
        },
        authorizationState: empty_auth_state(),
    }
}

fn well_formed_authorization() -> AuthorizationAbi {
    AuthorizationAbi {
        credentialId: Bytes::from(vec![1u8]),
        requestedAuthority: vec![],
        restrictions: vec![],
        validFrom: U256::from(0u64),
        validUntil: U256::from(1000u64),
        replayKey: Bytes::from(vec![2u8]),
        accountId: Bytes::from(vec![1u8, 2, 3, 4]),
        scope: empty_scope_abi(),
    }
}

fn valid_capability(name: &str) -> CapabilityAbi {
    CapabilityAbi {
        kind: CapabilityKindAbi { name: name.to_string() },
        scope: empty_scope_abi(),
    }
}

fn valid_credential(id: u8) -> CredentialAbi {
    CredentialAbi {
        id: Bytes::from(vec![id]),
        status: 1, // Active
    }
}

fn valid_session(id: u8, credential_id: u8) -> SessionAbi {
    SessionAbi {
        id: Bytes::from(vec![id]),
        credentialId: Bytes::from(vec![credential_id]),
        capabilities: vec![],
        validFrom: U256::from(0u64),
        validUntil: U256::from(1000u64),
        restrictions: vec![],
        status: 1, // Active
    }
}

fn valid_delegation(id: u8, delegator_identity_id: Bytes) -> DelegationAbi {
    DelegationAbi {
        id: Bytes::from(vec![id]),
        delegatorIdentityId: delegator_identity_id,
        delegatee: SubjectAbi {
            reference: Bytes::from(vec![7u8]),
        },
        capabilities: vec![],
        validFrom: U256::from(0u64),
        validUntil: U256::from(1000u64),
        restrictions: vec![],
        metadata: Bytes::new(),
        status: 1,
    }
}

fn empty_policy_consumption() -> PolicyConsumptionAbi {
    PolicyConsumptionAbi {
        policy: PolicyAbi { effects: vec![] },
    }
}

fn single_effect_consumption(effect: PolicyEffectAbi) -> PolicyConsumptionAbi {
    PolicyConsumptionAbi {
        policy: PolicyAbi {
            effects: vec![effect],
        },
    }
}

fn scoped_scope(atom_id: u8) -> ScopeAbi {
    ScopeAbi {
        atoms: vec![ScopeAtomAbi {
            id: Bytes::from(vec![atom_id]),
        }],
    }
}

fn no_scope() -> OptionalScopeAbi {
    OptionalScopeAbi {
        hasScope: false,
        scope: empty_scope_abi(),
    }
}

fn account_with_credential(cred_id: u8) -> AccountAbi {
    let (acc, applied) = register_credential_impl(&empty_account(), &valid_credential(cred_id));
    assert!(applied, "fixture: credential must register on empty account");
    acc
}

fn account_with_session(cred_id: u8, sess_id: u8) -> AccountAbi {
    let acc = account_with_credential(cred_id);
    let (acc, applied) = register_session_impl(&acc, &valid_session(sess_id, cred_id));
    assert!(applied, "fixture: session must register on account with credential");
    acc
}

fn well_formed_execution_request(
    account_id: Bytes,
    credential_id: Bytes,
) -> ExecutionRequestAbi {
    ExecutionRequestAbi {
        authorization: AuthorizationAbi {
            credentialId: credential_id,
            requestedAuthority: vec![],
            restrictions: vec![],
            validFrom: U256::from(0u64),
            validUntil: U256::from(1000u64),
            replayKey: Bytes::from(vec![2u8]),
            accountId: account_id,
            scope: empty_scope_abi(),
        },
    }
}

// ============================================================================
// 1. Roundtrip and structural validators
// ============================================================================

#[test]
fn account_abi_roundtrip_preserves_identity() {
    let original = empty_account();
    let dafny = account_from_abi(&original);
    let back = account_to_abi(&dafny);

    assert_eq!(back.id, original.id);
    assert_eq!(back.identity.id, original.identity.id);
    assert_eq!(
        back.identity.subject.reference,
        original.identity.subject.reference
    );
    assert!(back.authorizationState.capabilities.is_empty());
}

#[test]
fn structurally_valid_authorization_is_accepted() {
    let auth = well_formed_authorization();
    assert!(authorization_is_structurally_valid_impl(&auth));
}

#[test]
fn authorization_with_empty_credential_id_is_rejected() {
    let mut auth = well_formed_authorization();
    auth.credentialId = Bytes::new();
    assert!(!authorization_is_structurally_valid_impl(&auth));
}

#[test]
fn authorization_with_inverted_time_window_is_rejected() {
    let mut auth = well_formed_authorization();
    auth.validFrom = U256::from(1000u64);
    auth.validUntil = U256::from(500u64);
    assert!(!authorization_is_structurally_valid_impl(&auth));
}

#[test]
fn authorization_can_be_accepted_full_does_not_panic_on_empty_state() {
    let auth = well_formed_authorization();
    let account = empty_account();
    let identities: Vec<IdentityAbi> = vec![];
    let _result = authorization_can_be_accepted_full_impl(
        &auth,
        &account,
        &identities,
        U256::from(500u64),
        false,
    );
}

// ============================================================================
// 2. PolicyConsumption signal
// ============================================================================

#[test]
fn empty_policy_is_reported_as_applied() {
    let account = empty_account();
    let consumption = empty_policy_consumption();
    let (result, applied) = apply_policy_consumption_impl(&account, &consumption);
    assert!(applied, "empty policy is trivially applicable");
    assert_eq!(result.id, account.id);
}

#[test]
fn revoking_nonexistent_credential_reports_rejected() {
    let account = empty_account();
    let effect = PolicyEffectAbi {
        kind: 1,
        id: Bytes::from(vec![99u8, 99u8, 99u8]),
        capability: empty_capability_abi(),
        scope: empty_optional_scope_abi(),
        restriction: empty_restriction_abi(),
    };
    let consumption = single_effect_consumption(effect);
    let (result, applied) = apply_policy_consumption_impl(&account, &consumption);
    assert!(!applied, "revoking nonexistent credential must reject the policy");
    assert_eq!(result.id, account.id);
    assert!(result.authorizationState.credentials.is_empty());
}

// ============================================================================
// 3. All six PolicyEffect kinds
// ============================================================================

#[test]
fn policy_kind1_revoke_existing_credential_succeeds() {
    let account = account_with_credential(1);

    let effect = PolicyEffectAbi {
        kind: 1,
        id: Bytes::from(vec![1u8]),
        capability: empty_capability_abi(),
        scope: empty_optional_scope_abi(),
        restriction: empty_restriction_abi(),
    };
    let (result, applied) =
        apply_policy_consumption_impl(&account, &single_effect_consumption(effect));

    assert!(applied, "revoking an existing credential must apply");
    assert_eq!(result.authorizationState.credentials.len(), 1);
    assert_eq!(result.authorizationState.credentials[0].status, 3);
}

#[test]
fn policy_kind2_revoke_existing_session_succeeds() {
    let account = account_with_session(1, 1);

    let effect = PolicyEffectAbi {
        kind: 2,
        id: Bytes::from(vec![1u8]),
        capability: empty_capability_abi(),
        scope: empty_optional_scope_abi(),
        restriction: empty_restriction_abi(),
    };
    let (result, applied) =
        apply_policy_consumption_impl(&account, &single_effect_consumption(effect));

    assert!(applied);
    assert_eq!(result.authorizationState.sessions.len(), 1);
    assert_eq!(result.authorizationState.sessions[0].status, 2);
}

#[test]
fn policy_kind3_revoke_existing_delegation_succeeds() {
    let account = empty_account();
    let delegator_id = account.identity.id.clone();
    let delegate_cap = valid_capability("Delegate");
    let delegation = valid_delegation(42, delegator_id);
    let (account, applied_del) = register_delegation_impl(
        &account,
        &delegation,
        &delegate_cap,
        &[delegate_cap.clone()],
        &[delegate_cap.clone()],
    );
    assert!(applied_del);

    let effect = PolicyEffectAbi {
        kind: 3,
        id: Bytes::from(vec![42u8]),
        capability: empty_capability_abi(),
        scope: empty_optional_scope_abi(),
        restriction: empty_restriction_abi(),
    };
    let (result, applied) =
        apply_policy_consumption_impl(&account, &single_effect_consumption(effect));

    assert!(applied);
    assert_eq!(result.authorizationState.delegations.len(), 1);
    assert_eq!(result.authorizationState.delegations[0].status, 2);
}

#[test]
fn policy_kind4_disable_existing_capability_succeeds() {
    let account = empty_account();
    let capability = valid_capability("Upload");
    let (account, applied_cap) = add_capability_impl(&account, &capability);
    assert!(applied_cap);

    let effect = PolicyEffectAbi {
        kind: 4,
        id: Bytes::new(),
        capability: capability.clone(),
        scope: empty_optional_scope_abi(),
        restriction: empty_restriction_abi(),
    };
    let (result, applied) =
        apply_policy_consumption_impl(&account, &single_effect_consumption(effect));

    assert!(applied);
    assert!(result.authorizationState.capabilities.is_empty());
}

#[test]
fn policy_kind5_enable_capability_succeeds_on_empty_state() {
    let account = empty_account();
    let capability = valid_capability("Upload");

    let effect = PolicyEffectAbi {
        kind: 5,
        id: Bytes::new(),
        capability: capability.clone(),
        scope: empty_optional_scope_abi(),
        restriction: empty_restriction_abi(),
    };
    let (result, applied) =
        apply_policy_consumption_impl(&account, &single_effect_consumption(effect));

    assert!(applied, "enable capability has no state precondition");
    assert_eq!(result.authorizationState.capabilities.len(), 1);
    assert_eq!(result.authorizationState.capabilities[0].kind.name, "Upload");
}

#[test]
fn policy_kind6_modify_restriction_succeeds_on_existing_capability() {
    let account = empty_account();
    let capability = valid_capability("Upload");
    let (account, applied_cap) = add_capability_impl(&account, &capability);
    assert!(applied_cap);

    let restriction = RestrictionAbi {
        kind: RestrictionKindAbi {
            name: "max_value".to_string(),
        },
        value: Bytes::from(vec![1u8, 0u8]),
    };

    let effect = PolicyEffectAbi {
        kind: 6,
        id: Bytes::new(),
        capability: capability.clone(),
        scope: empty_optional_scope_abi(),
        restriction: restriction.clone(),
    };
    let (result, applied) =
        apply_policy_consumption_impl(&account, &single_effect_consumption(effect));

    assert!(applied);
    assert_eq!(result.authorizationState.restrictionMap.len(), 1);
    assert_eq!(
        result.authorizationState.restrictionMap[0].restriction.kind.name,
        "max_value"
    );
}

// ============================================================================
// 4. Provisioning — happy path (existing entrypoints)
// ============================================================================

#[test]
fn register_credential_adds_it_to_state() {
    let account = empty_account();
    let credential = valid_credential(1);
    let (result, applied) = register_credential_impl(&account, &credential);

    assert!(applied);
    assert_eq!(result.authorizationState.credentials.len(), 1);
    assert_eq!(result.authorizationState.credentials[0].id, credential.id);
    assert_eq!(result.authorizationState.credentials[0].status, 1);
    assert_eq!(result.authorizationState.credentialAuthorities.len(), 1);
    assert_eq!(
        result.authorizationState.credentialAuthorities[0].credentialId,
        credential.id
    );
    assert!(result.authorizationState.credentialAuthorities[0]
        .authority
        .is_empty());
}

#[test]
fn add_capability_adds_it_to_state() {
    let account = empty_account();
    let capability = valid_capability("Upload");
    let (result, applied) = add_capability_impl(&account, &capability);

    assert!(applied);
    assert_eq!(result.authorizationState.capabilities.len(), 1);
    assert_eq!(result.authorizationState.capabilities[0].kind.name, "Upload");
}

#[test]
fn register_session_after_credential() {
    let account = empty_account();
    let (account, applied_cred) = register_credential_impl(&account, &valid_credential(1));
    assert!(applied_cred);

    let session = valid_session(1, 1);
    let (account, applied_sess) = register_session_impl(&account, &session);
    assert!(applied_sess);

    assert_eq!(account.authorizationState.sessions.len(), 1);
    assert_eq!(account.authorizationState.sessions[0].id, session.id);
    assert_eq!(
        account.authorizationState.sessions[0].credentialId,
        session.credentialId
    );
}

#[test]
fn set_restriction_after_capability() {
    let account = empty_account();
    let capability = valid_capability("Upload");
    let (account, applied_cap) = add_capability_impl(&account, &capability);
    assert!(applied_cap);

    let scope = no_scope();
    let restriction = RestrictionAbi {
        kind: RestrictionKindAbi {
            name: "max_value".to_string(),
        },
        value: Bytes::from(vec![1u8, 0u8, 0u8]),
    };

    let (account, applied_restr) =
        set_restriction_impl(&account, &capability, &scope, &restriction);
    assert!(applied_restr);

    assert_eq!(account.authorizationState.restrictionMap.len(), 1);
    assert_eq!(
        account.authorizationState.restrictionMap[0].restriction.kind.name,
        "max_value"
    );
    assert_eq!(
        account.authorizationState.restrictionMap[0]
            .target
            .capability
            .kind
            .name,
        "Upload"
    );
    assert!(!account.authorizationState.restrictionMap[0].target.scope.hasScope);
}

#[test]
fn register_root_delegation_succeeds() {
    let account = empty_account();

    let delegator_id = account.identity.id.clone();
    let delegate_cap = valid_capability("Delegate");
    let delegation = valid_delegation(42, delegator_id);

    let (result, applied) = register_delegation_impl(
        &account,
        &delegation,
        &delegate_cap,
        &[delegate_cap.clone()],
        &[delegate_cap.clone()],
    );

    assert!(applied);
    assert_eq!(result.authorizationState.delegations.len(), 1);
    assert_eq!(result.authorizationState.delegations[0].id, delegation.id);
    assert_eq!(
        result.authorizationState.delegations[0].delegatorIdentityId,
        delegation.delegatorIdentityId
    );
    assert_eq!(result.authorizationState.delegationProvenance.len(), 1);
    assert!(result.authorizationState.delegationProvenance[0]
        .parents
        .is_empty());
}

// ============================================================================
// 5. Provisioning — rejection on preconditions
// ============================================================================

#[test]
fn register_credential_rejected_when_already_recognized() {
    let account = account_with_credential(1);
    let (result, applied) = register_credential_impl(&account, &valid_credential(1));

    assert!(!applied, "duplicate credentialId must reject");
    assert_eq!(result.id, account.id);
    assert_eq!(result.authorizationState.credentials.len(), 1);
}

#[test]
fn register_credential_rejected_when_id_is_empty() {
    let account = empty_account();
    let mut credential = valid_credential(1);
    credential.id = Bytes::new();

    let (result, applied) = register_credential_impl(&account, &credential);

    assert!(!applied, "empty credentialId must reject ValidCredential");
    assert_eq!(result.id, account.id);
    assert!(result.authorizationState.credentials.is_empty());
}

#[test]
fn register_session_rejected_when_credential_id_unknown() {
    let account = empty_account();
    let session = valid_session(1, 99);

    let (result, applied) = register_session_impl(&account, &session);

    assert!(!applied, "session with unknown credentialId must reject");
    assert_eq!(result.id, account.id);
    assert!(result.authorizationState.sessions.is_empty());
}

#[test]
fn register_session_rejected_when_session_id_duplicate() {
    let account = account_with_session(1, 1);
    let duplicate = valid_session(1, 1);

    let (result, applied) = register_session_impl(&account, &duplicate);

    assert!(!applied, "duplicate sessionId must reject");
    assert_eq!(result.id, account.id);
    assert_eq!(result.authorizationState.sessions.len(), 1);
}

#[test]
fn register_session_rejected_when_capabilities_escape_credential_authority() {
    let account = account_with_credential(1);
    let mut session = valid_session(1, 1);
    session.capabilities = vec![valid_capability("Upload")];

    let (result, applied) = register_session_impl(&account, &session);

    assert!(
        !applied,
        "session capabilities must not escape credential authority"
    );
    assert_eq!(result.id, account.id);
}

#[test]
fn add_capability_rejected_when_id_is_empty_name() {
    let account = empty_account();
    let invalid_capability = CapabilityAbi {
        kind: CapabilityKindAbi {
            name: String::new(),
        },
        scope: empty_scope_abi(),
    };

    let (result, applied) = add_capability_impl(&account, &invalid_capability);

    assert!(!applied, "empty capability name must reject ValidCapability");
    assert_eq!(result.id, account.id);
    assert!(result.authorizationState.capabilities.is_empty());
}

#[test]
fn set_restriction_rejected_when_capability_not_recognized() {
    let account = empty_account();
    let capability = valid_capability("Upload");
    let scope = no_scope();
    let restriction = RestrictionAbi {
        kind: RestrictionKindAbi {
            name: "max_value".to_string(),
        },
        value: Bytes::from(vec![1u8]),
    };

    let (result, applied) =
        set_restriction_impl(&account, &capability, &scope, &restriction);

    assert!(
        !applied,
        "restriction on unrecognized capability must reject"
    );
    assert_eq!(result.id, account.id);
    assert!(result.authorizationState.restrictionMap.is_empty());
}

#[test]
fn register_delegation_rejected_when_source_is_not_sovereign() {
    let account = empty_account();
    let delegate_cap = valid_capability("Delegate");

    let mut delegation = valid_delegation(42, Bytes::from(vec![99u8, 99u8]));
    delegation.delegatee = SubjectAbi {
        reference: Bytes::from(vec![7u8]),
    };

    let (result, applied) = register_delegation_impl(
        &account,
        &delegation,
        &delegate_cap,
        &[delegate_cap.clone()],
        &[delegate_cap.clone()],
    );

    assert!(
        !applied,
        "root delegation must have the account sovereign identity as source"
    );
    assert_eq!(result.id, account.id);
    assert!(result.authorizationState.delegations.is_empty());
}

#[test]
fn register_delegation_rejected_when_delegate_capability_not_present() {
    let account = empty_account();
    let delegator_id = account.identity.id.clone();
    let delegation = valid_delegation(42, delegator_id);

    let delegate_cap = valid_capability("Delegate");
    let other_cap = valid_capability("Other");

    let (result, applied) = register_delegation_impl(
        &account,
        &delegation,
        &delegate_cap,
        &[delegate_cap.clone()],
        &[other_cap],
    );

    assert!(
        !applied,
        "source must hold Delegate capability to register a delegation"
    );
    assert_eq!(result.id, account.id);
}

#[test]
fn register_delegation_rejected_when_id_already_recognized() {
    let account = empty_account();
    let delegator_id = account.identity.id.clone();
    let delegate_cap = valid_capability("Delegate");
    let delegation = valid_delegation(42, delegator_id.clone());

    let (account, applied_first) = register_delegation_impl(
        &account,
        &delegation,
        &delegate_cap,
        &[delegate_cap.clone()],
        &[delegate_cap.clone()],
    );
    assert!(applied_first);

    let (result, applied_second) = register_delegation_impl(
        &account,
        &delegation,
        &delegate_cap,
        &[delegate_cap.clone()],
        &[delegate_cap.clone()],
    );

    assert!(!applied_second, "duplicate delegationId must reject");
    assert_eq!(result.authorizationState.delegations.len(), 1);
}

// ============================================================================
// 6. Post-transition invariants — ValidAccount preserved
// ============================================================================

#[test]
fn register_credential_preserves_valid_account() {
    let account = empty_account();
    assert!(valid_account_impl(&account));

    let (result, applied) = register_credential_impl(&account, &valid_credential(1));
    assert!(applied);
    assert!(valid_account_impl(&result), "result must remain ValidAccount");
    assert!(valid_authorization_state_impl(&result.authorizationState));
}

#[test]
fn add_capability_preserves_valid_account() {
    let account = empty_account();
    let (result, applied) = add_capability_impl(&account, &valid_capability("Upload"));
    assert!(applied);
    assert!(valid_account_impl(&result));
}

#[test]
fn register_session_preserves_valid_account() {
    let account = account_with_credential(1);
    let (result, applied) = register_session_impl(&account, &valid_session(1, 1));
    assert!(applied);
    assert!(valid_account_impl(&result));
}

#[test]
fn register_delegation_preserves_valid_account() {
    let account = empty_account();
    let delegator_id = account.identity.id.clone();
    let delegate_cap = valid_capability("Delegate");
    let delegation = valid_delegation(42, delegator_id);

    let (result, applied) = register_delegation_impl(
        &account,
        &delegation,
        &delegate_cap,
        &[delegate_cap.clone()],
        &[delegate_cap.clone()],
    );
    assert!(applied);
    assert!(valid_account_impl(&result));
}

#[test]
fn set_restriction_preserves_valid_account() {
    let account = empty_account();
    let capability = valid_capability("Upload");
    let (account, applied_cap) = add_capability_impl(&account, &capability);
    assert!(applied_cap);

    let scope = no_scope();
    let restriction = RestrictionAbi {
        kind: RestrictionKindAbi {
            name: "max_value".to_string(),
        },
        value: Bytes::from(vec![1u8]),
    };

    let (result, applied) = set_restriction_impl(&account, &capability, &scope, &restriction);
    assert!(applied);
    assert!(valid_account_impl(&result));
}

// ============================================================================
// 7. New provisioning entrypoints — happy path
// ============================================================================

#[test]
fn set_credential_authority_on_existing_credential() {
    let account = account_with_credential(1);
    let cap = valid_capability("Upload");

    let (result, applied) = set_credential_authority_impl(
        &account,
        &valid_credential(1),
        &[cap.clone()],
    );

    assert!(applied);
    assert_eq!(result.authorizationState.credentialAuthorities.len(), 1);
    assert_eq!(
        result.authorizationState.credentialAuthorities[0].authority.len(),
        1
    );
    assert_eq!(
        result.authorizationState.credentialAuthorities[0].authority[0]
            .kind
            .name,
        "Upload"
    );
    assert!(valid_account_impl(&result));
}

#[test]
fn remove_capability_removes_it() {
    let account = empty_account();
    let capability = valid_capability("Upload");
    let (account, applied_add) = add_capability_impl(&account, &capability);
    assert!(applied_add);
    assert_eq!(account.authorizationState.capabilities.len(), 1);

    let (result, applied) = remove_capability_impl(&account, &capability);
    assert!(applied);
    assert!(result.authorizationState.capabilities.is_empty());
    assert!(valid_account_impl(&result));
}

#[test]
fn remove_restriction_removes_it() {
    let account = empty_account();
    let capability = valid_capability("Upload");
    let (account, _) = add_capability_impl(&account, &capability);

    let scope = no_scope();
    let restriction = RestrictionAbi {
        kind: RestrictionKindAbi {
            name: "max_value".to_string(),
        },
        value: Bytes::from(vec![1u8]),
    };

    let (account, applied_set) =
        set_restriction_impl(&account, &capability, &scope, &restriction);
    assert!(applied_set);
    assert_eq!(account.authorizationState.restrictionMap.len(), 1);

    let (result, applied) = remove_restriction_impl(&account, &capability, &scope);
    assert!(applied);
    assert!(result.authorizationState.restrictionMap.is_empty());
    assert!(valid_account_impl(&result));
}

#[test]
fn consume_fresh_replay_key_succeeds() {
    let account = empty_account();
    let key = Bytes::from(vec![42u8, 42u8]);

    let (result, applied) = consume_replay_key_impl(&account, &key);

    assert!(applied);
    assert_eq!(result.authorizationState.consumedReplayKeys.len(), 1);
    assert_eq!(result.authorizationState.consumedReplayKeys[0], key);
    assert!(valid_account_impl(&result));
}

#[test]
fn update_credential_status_to_suspended() {
    let account = account_with_credential(1);
    let (result, applied) =
        update_credential_status_impl(&account, &valid_credential(1), 2);

    assert!(applied);
    assert_eq!(result.authorizationState.credentials.len(), 1);
    assert_eq!(result.authorizationState.credentials[0].status, 2);
    assert!(valid_account_impl(&result));
}

#[test]
fn update_session_status_to_revoked() {
    let account = account_with_session(1, 1);
    let (result, applied) = update_session_status_impl(&account, &valid_session(1, 1), 2);

    assert!(applied);
    assert_eq!(result.authorizationState.sessions.len(), 1);
    assert_eq!(result.authorizationState.sessions[0].status, 2);
    assert!(valid_account_impl(&result));
}

#[test]
fn update_delegation_status_to_revoked() {
    let account = empty_account();
    let delegator_id = account.identity.id.clone();
    let delegate_cap = valid_capability("Delegate");
    let delegation = valid_delegation(42, delegator_id);

    let (account, applied_reg) = register_delegation_impl(
        &account,
        &delegation,
        &delegate_cap,
        &[delegate_cap.clone()],
        &[delegate_cap.clone()],
    );
    assert!(applied_reg);

    let (result, applied) = update_delegation_status_impl(&account, &delegation, 2);
    assert!(applied);
    assert_eq!(result.authorizationState.delegations.len(), 1);
    assert_eq!(result.authorizationState.delegations[0].status, 2);
    assert!(valid_account_impl(&result));
}

#[test]
fn register_transitive_delegation_requires_parent() {
    let account = empty_account();
    let delegate_cap = valid_capability("Delegate");
    let delegation = valid_delegation(42, Bytes::from(vec![99u8]));

    let (result, applied) = register_transitive_delegation_impl(
        &account,
        &delegation,
        &delegate_cap,
        &[delegate_cap.clone()],
        &[delegate_cap.clone()],
        &[],
        &[],
    );

    assert!(
        !applied,
        "transitive delegation must reject when no parents are provided"
    );
    assert_eq!(result.id, account.id);
}

// ============================================================================
// 8. New provisioning entrypoints — rejection
// ============================================================================

#[test]
fn set_credential_authority_rejected_when_credential_not_recognized() {
    let account = empty_account();
    let cap = valid_capability("Upload");

    let (result, applied) = set_credential_authority_impl(
        &account,
        &valid_credential(99),
        &[cap.clone()],
    );

    assert!(
        !applied,
        "cannot set authority on an unrecognized credential"
    );
    assert_eq!(result.id, account.id);
}

#[test]
fn set_credential_authority_rejected_when_existing_sessions_would_escape() {
    let account = account_with_session(1, 1);
    let cap = valid_capability("View");

    let (account, applied_cap_authority) =
        set_credential_authority_impl(&account, &valid_credential(1), &[cap.clone()]);
    assert!(applied_cap_authority);

    let mut session_with_view = valid_session(2, 1);
    session_with_view.capabilities = vec![cap.clone()];
    let (account, applied_session) = register_session_impl(&account, &session_with_view);
    assert!(applied_session);

    let (result, applied) =
        set_credential_authority_impl(&account, &valid_credential(1), &[]);

    assert!(
        !applied,
        "tightening credential authority below existing session must reject"
    );
    assert_eq!(
        result.authorizationState.credentialAuthorities[0].authority.len(),
        1
    );
}

#[test]
fn remove_capability_rejected_when_account_invalid() {
    let mut account = empty_account();
    account.id = Bytes::new();
    let capability = valid_capability("Upload");

    let (result, applied) = remove_capability_impl(&account, &capability);

    assert!(!applied, "invalid account must reject the transition");
    assert_eq!(result.id, account.id);
}

#[test]
fn consume_replay_key_rejected_when_already_consumed() {
    let account = empty_account();
    let key = Bytes::from(vec![42u8]);

    let (account, applied_first) = consume_replay_key_impl(&account, &key);
    assert!(applied_first);

    let (result, applied_second) = consume_replay_key_impl(&account, &key);
    assert!(!applied_second, "consuming the same key twice must reject");
    assert_eq!(result.authorizationState.consumedReplayKeys.len(), 1);
}

#[test]
fn consume_replay_key_rejected_when_key_is_empty() {
    let account = empty_account();
    let empty_key = Bytes::new();

    let (result, applied) = consume_replay_key_impl(&account, &empty_key);

    assert!(!applied, "empty replay key must reject ValidId");
    assert_eq!(result.authorizationState.consumedReplayKeys.len(), 0);
}

#[test]
fn update_credential_status_rejected_when_credential_not_in_state() {
    let account = empty_account();
    let (result, applied) = update_credential_status_impl(&account, &valid_credential(1), 2);

    assert!(
        !applied,
        "cannot update status of an unrecognized credential"
    );
    assert_eq!(result.id, account.id);
}

#[test]
fn update_credential_status_rejected_on_invalid_transition() {
    let account = account_with_credential(1);

    let (account, applied_rev) =
        update_credential_status_impl(&account, &valid_credential(1), 3);
    assert!(applied_rev);

    let revoked_credential = CredentialAbi {
        id: Bytes::from(vec![1u8]),
        status: 3,
    };
    let (result, applied_reactivate) =
        update_credential_status_impl(&account, &revoked_credential, 1);

    assert!(
        !applied_reactivate,
        "Revoked → Active is not a valid CredentialStatus transition"
    );
    assert_eq!(result.authorizationState.credentials[0].status, 3);
}

// ============================================================================
// 9. Total transitions — RemoveRestriction / RemoveCapability
// ============================================================================

#[test]
fn remove_restriction_on_unrecognized_capability_is_idempotent_noop() {
    let account = empty_account();
    let capability = valid_capability("Upload");
    let scope = no_scope();

    let (result, applied) = remove_restriction_impl(&account, &capability, &scope);

    assert!(
        applied,
        "RemoveRestriction is total over ValidAccount: no target-existence precondition"
    );
    assert_eq!(result.id, account.id);
    assert!(result.authorizationState.restrictionMap.is_empty());
    assert!(valid_account_impl(&result));
}

#[test]
fn remove_capability_on_unrecognized_capability_is_idempotent_noop() {
    let account = empty_account();
    let capability = valid_capability("Upload");

    let (result, applied) = remove_capability_impl(&account, &capability);

    assert!(
        applied,
        "RemoveCapability is total over ValidAccount: no capability-existence precondition"
    );
    assert_eq!(result.id, account.id);
    assert!(result.authorizationState.capabilities.is_empty());
    assert!(valid_account_impl(&result));
}

#[test]
fn remove_restriction_only_removes_matching_target() {
    let account = empty_account();
    let capability = valid_capability("Upload");
    let (account, _) = add_capability_impl(&account, &capability);

    let unscoped = no_scope();
    let scoped = OptionalScopeAbi {
        hasScope: true,
        scope: scoped_scope(42),
    };

    let r_no = RestrictionAbi {
        kind: RestrictionKindAbi {
            name: "unscoped".to_string(),
        },
        value: Bytes::from(vec![1u8]),
    };
    let r_sc = RestrictionAbi {
        kind: RestrictionKindAbi {
            name: "scoped".to_string(),
        },
        value: Bytes::from(vec![2u8]),
    };

    let (account, _) = set_restriction_impl(&account, &capability, &unscoped, &r_no);
    let (account, _) = set_restriction_impl(&account, &capability, &scoped, &r_sc);
    assert_eq!(account.authorizationState.restrictionMap.len(), 2);

    let (result, applied) = remove_restriction_impl(&account, &capability, &unscoped);
    assert!(applied);
    assert_eq!(result.authorizationState.restrictionMap.len(), 1);
    assert_eq!(
        result.authorizationState.restrictionMap[0].restriction.kind.name,
        "scoped"
    );
    assert!(valid_account_impl(&result));
}

// ============================================================================
// 10. OptionalScopeAbi — the Scoped path
// ============================================================================

#[test]
fn set_restriction_with_scoped_target_persists_scope() {
    let account = empty_account();
    let capability = valid_capability("Upload");
    let (account, _) = add_capability_impl(&account, &capability);

    let scope = OptionalScopeAbi {
        hasScope: true,
        scope: scoped_scope(42),
    };
    let restriction = RestrictionAbi {
        kind: RestrictionKindAbi {
            name: "max_value".to_string(),
        },
        value: Bytes::from(vec![10u8]),
    };

    let (result, applied) =
        set_restriction_impl(&account, &capability, &scope, &restriction);

    assert!(applied);
    assert_eq!(result.authorizationState.restrictionMap.len(), 1);

    let entry = &result.authorizationState.restrictionMap[0];
    assert!(
        entry.target.scope.hasScope,
        "Scoped variant must roundtrip as hasScope = true"
    );
    assert_eq!(entry.target.scope.scope.atoms.len(), 1);
    assert_eq!(
        entry.target.scope.scope.atoms[0].id,
        Bytes::from(vec![42u8])
    );
    assert!(valid_account_impl(&result));
}

#[test]
fn scoped_and_unscoped_restrictions_are_distinct_targets() {
    let account = empty_account();
    let capability = valid_capability("Upload");
    let (account, _) = add_capability_impl(&account, &capability);

    let unscoped = no_scope();
    let scoped = OptionalScopeAbi {
        hasScope: true,
        scope: scoped_scope(42),
    };

    let r_no = RestrictionAbi {
        kind: RestrictionKindAbi {
            name: "unscoped".to_string(),
        },
        value: Bytes::from(vec![1u8]),
    };
    let r_sc = RestrictionAbi {
        kind: RestrictionKindAbi {
            name: "scoped".to_string(),
        },
        value: Bytes::from(vec![2u8]),
    };

    let (account, applied_no) =
        set_restriction_impl(&account, &capability, &unscoped, &r_no);
    assert!(applied_no);
    let (account, applied_sc) =
        set_restriction_impl(&account, &capability, &scoped, &r_sc);
    assert!(applied_sc);

    assert_eq!(
        account.authorizationState.restrictionMap.len(),
        2,
        "NoScope and Scoped(s) are distinct keys of the RestrictionMap"
    );
    assert!(valid_account_impl(&account));
}

#[test]
fn set_restriction_replaces_previous_value_for_same_target() {
    let account = empty_account();
    let capability = valid_capability("Upload");
    let (account, _) = add_capability_impl(&account, &capability);

    let scope = no_scope();
    let r1 = RestrictionAbi {
        kind: RestrictionKindAbi {
            name: "max_value".to_string(),
        },
        value: Bytes::from(vec![1u8]),
    };
    let r2 = RestrictionAbi {
        kind: RestrictionKindAbi {
            name: "max_value".to_string(),
        },
        value: Bytes::from(vec![2u8]),
    };

    let (account, _) = set_restriction_impl(&account, &capability, &scope, &r1);
    assert_eq!(account.authorizationState.restrictionMap.len(), 1);

    let (result, applied) = set_restriction_impl(&account, &capability, &scope, &r2);
    assert!(applied);
    assert_eq!(
        result.authorizationState.restrictionMap.len(),
        1,
        "same target must replace, not duplicate"
    );
    assert_eq!(
        result.authorizationState.restrictionMap[0].restriction.value,
        Bytes::from(vec![2u8])
    );
}

// ============================================================================
// 11. RemoveCapability cascades to restrictions (D5.3.2)
// ============================================================================

#[test]
fn remove_capability_cascades_to_restrictions() {
    let account = empty_account();
    let capability = valid_capability("Upload");
    let (account, _) = add_capability_impl(&account, &capability);

    let scope = no_scope();
    let restriction = RestrictionAbi {
        kind: RestrictionKindAbi {
            name: "max_value".to_string(),
        },
        value: Bytes::from(vec![1u8]),
    };
    let (account, _) = set_restriction_impl(&account, &capability, &scope, &restriction);
    assert_eq!(account.authorizationState.restrictionMap.len(), 1);

    let (result, applied) = remove_capability_impl(&account, &capability);
    assert!(applied);
    assert!(result.authorizationState.capabilities.is_empty());
    assert!(
        result.authorizationState.restrictionMap.is_empty(),
        "D5.3.2: removing a capability removes its restriction targets"
    );
    assert!(valid_account_impl(&result));
}

// ============================================================================
// 12. Full ABI roundtrip with populated state
// ============================================================================

#[test]
fn account_roundtrip_preserves_populated_state() {
    let account = empty_account();
    let capability = valid_capability("Upload");
    let credential = valid_credential(1);
    let session = valid_session(2, 1);
    let delegation = valid_delegation(3, account.identity.id.clone());
    let delegate_cap = valid_capability("Delegate");

    let (account, _) = add_capability_impl(&account, &capability);
    let (account, _) = register_credential_impl(&account, &credential);
    let (account, _) = register_session_impl(&account, &session);
    let (account, _) = register_delegation_impl(
        &account,
        &delegation,
        &delegate_cap,
        &[delegate_cap.clone()],
        &[delegate_cap.clone()],
    );
    let (account, _) = consume_replay_key_impl(&account, &Bytes::from(vec![77u8]));

    let scope = no_scope();
    let restriction = RestrictionAbi {
        kind: RestrictionKindAbi {
            name: "max_value".to_string(),
        },
        value: Bytes::from(vec![42u8]),
    };
    let (account, _) = set_restriction_impl(&account, &capability, &scope, &restriction);

    let dafny = account_from_abi(&account);
    let back = account_to_abi(&dafny);

    assert_eq!(back.id, account.id);
    assert_eq!(back.identity.id, account.identity.id);
    assert_eq!(back.authorizationState.capabilities.len(), 1);
    assert_eq!(back.authorizationState.credentials.len(), 1);
    assert_eq!(back.authorizationState.credentialAuthorities.len(), 1);
    assert_eq!(back.authorizationState.sessions.len(), 1);
    assert_eq!(back.authorizationState.delegations.len(), 1);
    assert_eq!(back.authorizationState.delegationProvenance.len(), 1);
    assert_eq!(back.authorizationState.restrictionMap.len(), 1);
    assert_eq!(back.authorizationState.consumedReplayKeys.len(), 1);

    assert!(valid_account_impl(&back));
}

// ============================================================================
// 13. Execution Context — ValidExecutionContextForAccountFull
// ============================================================================

#[test]
fn valid_execution_context_does_not_panic_on_empty_state() {
    let account = empty_account();
    let context = ExecutionContextAbi {
        request: ExecutionRequestAbi {
            authorization: well_formed_authorization(),
        },
        authorizationState: empty_auth_state(),
        effectiveAuthority: vec![],
        evaluationTime: U256::from(500u64),
    };

    let _ = valid_execution_context_impl(&context, &account, &[], false);
}

#[test]
fn valid_execution_context_accepts_well_formed_context() {
    let account = account_with_credential(1);

    let request = well_formed_execution_request(
        account.id.clone(),
        Bytes::from(vec![1u8]),
    );

    let context = ExecutionContextAbi {
        request,
        authorizationState: account.authorizationState.clone(),
        effectiveAuthority: vec![],
        evaluationTime: U256::from(500u64),
    };

    let valid = valid_execution_context_impl(&context, &account, &[], true);

    assert!(valid, "well-formed context must be accepted");
}

#[test]
fn valid_execution_context_rejects_mismatched_state() {
    let account = account_with_credential(1);

    let request = well_formed_execution_request(
        account.id.clone(),
        Bytes::from(vec![1u8]),
    );

    let context = ExecutionContextAbi {
        request,
        authorizationState: empty_auth_state(),
        effectiveAuthority: vec![],
        evaluationTime: U256::from(500u64),
    };

    let valid = valid_execution_context_impl(&context, &account, &[], true);

    assert!(
        !valid,
        "context state must equal the account's current state"
    );
}

#[test]
fn valid_execution_context_rejects_empty_credential_id_authorization() {
    let account = account_with_credential(1);

    let request = well_formed_execution_request(
        account.id.clone(),
        Bytes::new(),
    );

    let context = ExecutionContextAbi {
        request,
        authorizationState: account.authorizationState.clone(),
        effectiveAuthority: vec![],
        evaluationTime: U256::from(500u64),
    };

    let valid = valid_execution_context_impl(&context, &account, &[], true);

    assert!(!valid, "invalid authorization must reject context");
}

#[test]
fn valid_execution_context_rejects_when_proof_not_verified() {
    let account = account_with_credential(1);

    let request = well_formed_execution_request(
        account.id.clone(),
        Bytes::from(vec![1u8]),
    );

    let context = ExecutionContextAbi {
        request,
        authorizationState: account.authorizationState.clone(),
        effectiveAuthority: vec![],
        evaluationTime: U256::from(500u64),
    };

    let valid = valid_execution_context_impl(&context, &account, &[], false);

    assert!(!valid, "unverified proof must reject context");
}

#[test]
fn valid_execution_context_rejects_mismatched_effective_authority() {
    let account = account_with_credential(1);
    let cap = valid_capability("Upload");
    let (account, applied_cap) = add_capability_impl(&account, &cap);
    assert!(applied_cap);

    let request = well_formed_execution_request(
        account.id.clone(),
        Bytes::from(vec![1u8]),
    );

    let context = ExecutionContextAbi {
        request,
        authorizationState: account.authorizationState.clone(),
        effectiveAuthority: vec![],
        evaluationTime: U256::from(500u64),
    };

    let valid = valid_execution_context_impl(&context, &account, &[], true);

    assert!(
        !valid,
        "context EA must equal the canonical EffectiveAuthority derivation"
    );
}

#[test]
fn valid_execution_context_rejects_invalid_account_id() {
    let mut account = account_with_credential(1);
    account.id = Bytes::new();

    let request = well_formed_execution_request(
        Bytes::from(vec![1u8, 2, 3, 4]),
        Bytes::from(vec![1u8]),
    );

    let context = ExecutionContextAbi {
        request,
        authorizationState: account.authorizationState.clone(),
        effectiveAuthority: vec![],
        evaluationTime: U256::from(500u64),
    };

    let valid = valid_execution_context_impl(&context, &account, &[], true);

    assert!(!valid, "invalid account id must reject context");
}

#[test]
fn valid_execution_context_rejects_invalid_identity() {
    let account = account_with_credential(1);

    let request = well_formed_execution_request(
        account.id.clone(),
        Bytes::from(vec![1u8]),
    );

    let context = ExecutionContextAbi {
        request,
        authorizationState: account.authorizationState.clone(),
        effectiveAuthority: vec![],
        evaluationTime: U256::from(500u64),
    };

    let bad_identity = IdentityAbi {
        id: Bytes::new(),
        subject: SubjectAbi {
            reference: Bytes::from(vec![1u8]),
        },
    };

    let valid =
        valid_execution_context_impl(&context, &account, &[bad_identity], true);

    assert!(!valid, "invalid identity must reject context");
}

// ============================================================================
// 14. EffectiveAuthority derivation — compute_effective_authority
// ============================================================================

#[test]
fn compute_effective_authority_empty_account_is_empty() {
    let account = empty_account();

    let ea = compute_effective_authority_impl(&account, &[], U256::from(500u64));

    assert!(
        ea.is_empty(),
        "empty account has empty EffectiveAuthority (vacuous union)"
    );
}

#[test]
fn compute_effective_authority_includes_account_capabilities() {
    let account = empty_account();
    let cap = valid_capability("Upload");
    let (account, applied) = add_capability_impl(&account, &cap);
    assert!(applied);

    let ea = compute_effective_authority_impl(&account, &[], U256::from(500u64));

    assert_eq!(ea.len(), 1);
    assert_eq!(ea[0].kind.name, "Upload");
}

#[test]
fn compute_effective_authority_includes_active_credential_authority() {
    let account = account_with_credential(1);
    let cap = valid_capability("Upload");

    let (account, applied) =
        set_credential_authority_impl(&account, &valid_credential(1), &[cap.clone()]);
    assert!(applied);

    let ea = compute_effective_authority_impl(&account, &[], U256::from(500u64));

    assert!(
        ea.iter().any(|c| c.kind.name == "Upload"),
        "active credential authority must be included"
    );
}

#[test]
fn compute_effective_authority_excludes_revoked_credential() {
    let account = account_with_credential(1);
    let cap = valid_capability("Upload");

    let (account, applied) =
        set_credential_authority_impl(&account, &valid_credential(1), &[cap.clone()]);
    assert!(applied);

    let (account, applied_rev) =
        update_credential_status_impl(&account, &valid_credential(1), 3);
    assert!(applied_rev);

    let ea = compute_effective_authority_impl(&account, &[], U256::from(500u64));

    assert!(
        !ea.iter().any(|c| c.kind.name == "Upload"),
        "revoked credential authority must NOT be included (D1 revocation semantics)"
    );
}

#[test]
fn compute_effective_authority_includes_active_delegation() {
    let account = empty_account();
    let delegate_cap = valid_capability("Delegate");

    let mut delegation = valid_delegation(42, account.identity.id.clone());
    delegation.capabilities = vec![delegate_cap.clone()];

    let (account, applied) = register_delegation_impl(
        &account,
        &delegation,
        &delegate_cap,
        &[delegate_cap.clone()],
        &[delegate_cap.clone()],
    );
    assert!(applied);

    let ea = compute_effective_authority_impl(&account, &[], U256::from(500u64));

    assert!(
        ea.iter().any(|c| c.kind.name == "Delegate"),
        "active delegation capabilities must be included in EffectiveAuthority"
    );
}

#[test]
fn compute_effective_authority_roundtrips_through_valid_context() {
    let account = account_with_credential(1);
    let cap = valid_capability("Upload");
    let (account, applied) = add_capability_impl(&account, &cap);
    assert!(applied);

    let ea = compute_effective_authority_impl(&account, &[], U256::from(500u64));

    let request = well_formed_execution_request(
        account.id.clone(),
        Bytes::from(vec![1u8]),
    );

    let context = ExecutionContextAbi {
        request,
        authorizationState: account.authorizationState.clone(),
        effectiveAuthority: ea,
        evaluationTime: U256::from(500u64),
    };

    let valid = valid_execution_context_impl(&context, &account, &[], true);

    assert!(
        valid,
        "context built from compute_effective_authority must be accepted"
    );
}

// ============================================================================
// 15. DDD property coverage
// ============================================================================

#[test]
fn authorization_can_be_accepted_full_accepts_valid_authorization() {
    let account = account_with_credential(1);

    let auth = AuthorizationAbi {
        credentialId: Bytes::from(vec![1u8]),
        requestedAuthority: vec![],
        restrictions: vec![],
        validFrom: U256::from(0u64),
        validUntil: U256::from(1000u64),
        replayKey: Bytes::from(vec![77u8]),
        accountId: account.id.clone(),
        scope: empty_scope_abi(),
    };

    let accepted = authorization_can_be_accepted_full_impl(
        &auth,
        &account,
        &[],
        U256::from(500u64),
        true,
    );

    assert!(
        accepted,
        "well-formed authorization against a valid account must be accepted"
    );
}

#[test]
fn policy_with_two_effects_applies_atomically() {
    let account = empty_account();
    let cap_upload = valid_capability("Upload");
    let cap_view = valid_capability("View");
    let (account, applied_a) = add_capability_impl(&account, &cap_upload);
    assert!(applied_a);
    let (account, applied_b) = add_capability_impl(&account, &cap_view);
    assert!(applied_b);
    assert_eq!(account.authorizationState.capabilities.len(), 2);

    let effect_disable_upload = PolicyEffectAbi {
        kind: 4,
        id: Bytes::new(),
        capability: cap_upload.clone(),
        scope: empty_optional_scope_abi(),
        restriction: empty_restriction_abi(),
    };
    let effect_disable_view = PolicyEffectAbi {
        kind: 4,
        id: Bytes::new(),
        capability: cap_view.clone(),
        scope: empty_optional_scope_abi(),
        restriction: empty_restriction_abi(),
    };

    let consumption = PolicyConsumptionAbi {
        policy: PolicyAbi {
            effects: vec![effect_disable_upload, effect_disable_view],
        },
    };

    let (result, applied) = apply_policy_consumption_impl(&account, &consumption);

    assert!(applied, "two applicable effects must apply (D2.3)");
    assert!(
        result.authorizationState.capabilities.is_empty(),
        "both effects must have taken effect (D2.3)"
    );
    assert!(valid_account_impl(&result));
}

#[test]
fn policy_with_one_bad_effect_rejects_entire_policy() {
    let account = empty_account();
    let cap_upload = valid_capability("Upload");
    let (account, applied) = add_capability_impl(&account, &cap_upload);
    assert!(applied);
    assert_eq!(account.authorizationState.capabilities.len(), 1);

    let good_effect = PolicyEffectAbi {
        kind: 4,
        id: Bytes::new(),
        capability: cap_upload.clone(),
        scope: empty_optional_scope_abi(),
        restriction: empty_restriction_abi(),
    };
    let bad_effect = PolicyEffectAbi {
        kind: 4,
        id: Bytes::new(),
        capability: valid_capability("Nonexistent"),
        scope: empty_optional_scope_abi(),
        restriction: empty_restriction_abi(),
    };

    let consumption = PolicyConsumptionAbi {
        policy: PolicyAbi {
            effects: vec![good_effect, bad_effect],
        },
    };

    let (result, applied) = apply_policy_consumption_impl(&account, &consumption);

    assert!(!applied, "one bad effect rejects the whole policy (D2.5)");
    assert_eq!(
        result.authorizationState.capabilities.len(),
        1,
        "the good effect must NOT have been applied (atomicity, D2.5)"
    );
    assert_eq!(
        result.authorizationState.capabilities[0].kind.name,
        "Upload",
        "the account must be identical to its input"
    );
}

#[test]
fn replay_key_consumed_blocks_subsequent_authorization() {
    let account = account_with_credential(1);
    let key = Bytes::from(vec![99u8]);

    let (account, applied) = consume_replay_key_impl(&account, &key);
    assert!(applied, "fixture: replay key must be consumable");
    assert_eq!(account.authorizationState.consumedReplayKeys.len(), 1);

    let auth = AuthorizationAbi {
        credentialId: Bytes::from(vec![1u8]),
        requestedAuthority: vec![],
        restrictions: vec![],
        validFrom: U256::from(0u64),
        validUntil: U256::from(1000u64),
        replayKey: key.clone(),
        accountId: account.id.clone(),
        scope: empty_scope_abi(),
    };

    let accepted = authorization_can_be_accepted_full_impl(
        &auth,
        &account,
        &[],
        U256::from(500u64),
        true,
    );

    assert!(
        !accepted,
        "consumed replay key must block acceptance (D4.5.3)"
    );

    let auth_fresh = AuthorizationAbi {
        replayKey: Bytes::from(vec![100u8]),
        ..auth
    };
    let accepted_fresh = authorization_can_be_accepted_full_impl(
        &auth_fresh,
        &account,
        &[],
        U256::from(500u64),
        true,
    );
    assert!(
        accepted_fresh,
        "same authorization with a fresh key must be accepted"
    );
}

#[test]
fn compute_effective_authority_includes_session_registration_path() {
    let account = account_with_credential(1);
    let cap = valid_capability("Upload");

    let (account, applied) =
        set_credential_authority_impl(&account, &valid_credential(1), &[cap.clone()]);
    assert!(applied);

    let mut session = valid_session(1, 1);
    session.capabilities = vec![cap.clone()];
    let (account, applied) = register_session_impl(&account, &session);
    assert!(applied);
    assert_eq!(account.authorizationState.sessions.len(), 1);

    let ea = compute_effective_authority_impl(&account, &[], U256::from(500u64));
    assert!(
        ea.iter().any(|c| c.kind.name == "Upload"),
        "EA must include Upload (credential and session both contribute)"
    );
    assert!(valid_account_impl(&account));
}

#[test]
fn revoked_credential_empties_effective_authority_even_with_active_session() {
    let account = account_with_credential(1);
    let cap = valid_capability("Upload");

    let (account, applied) =
        set_credential_authority_impl(&account, &valid_credential(1), &[cap.clone()]);
    assert!(applied);

    let mut session = valid_session(1, 1);
    session.capabilities = vec![cap.clone()];
    let (account, applied) = register_session_impl(&account, &session);
    assert!(applied);

    let ea_before = compute_effective_authority_impl(&account, &[], U256::from(500u64));
    assert!(
        ea_before.iter().any(|c| c.kind.name == "Upload"),
        "before revocation, Upload is in EA"
    );

    let (account, applied) =
        update_credential_status_impl(&account, &valid_credential(1), 3);
    assert!(applied);

    let ea_after = compute_effective_authority_impl(&account, &[], U256::from(500u64));
    assert!(
        ea_after.is_empty(),
        "revoked credential invalidates its session contribution (D3.6.1)"
    );
}

#[test]
fn revoked_credential_does_not_change_session_status() {
    let account = account_with_credential(1);
    let cap = valid_capability("Upload");

    let (account, _) =
        set_credential_authority_impl(&account, &valid_credential(1), &[cap.clone()]);

    let mut session = valid_session(1, 1);
    session.capabilities = vec![cap.clone()];
    let (account, applied) = register_session_impl(&account, &session);
    assert!(applied);
    assert_eq!(account.authorizationState.sessions[0].status, 1);

    let (account, applied) =
        update_credential_status_impl(&account, &valid_credential(1), 3);
    assert!(applied);

    assert_eq!(account.authorizationState.sessions.len(), 1);
    assert_eq!(
        account.authorizationState.sessions[0].status, 1,
        "session persistent status is unchanged by credential revocation (D3.6.1)"
    );
    assert_eq!(
        account.authorizationState.sessions[0].credentialId,
        Bytes::from(vec![1u8]),
        "session still references the (now revoked) credential"
    );
}

#[test]
fn revoked_credential_does_not_invalidate_independent_delegation() {
    let account = account_with_credential(1);
    let delegate_cap = valid_capability("Delegate");

    let mut delegation = valid_delegation(42, account.identity.id.clone());
    delegation.capabilities = vec![delegate_cap.clone()];

    let (account, applied) = register_delegation_impl(
        &account,
        &delegation,
        &delegate_cap,
        &[delegate_cap.clone()],
        &[delegate_cap.clone()],
    );
    assert!(applied);

    let (account, applied) =
        update_credential_status_impl(&account, &valid_credential(1), 3);
    assert!(applied);

    assert_eq!(account.authorizationState.delegations.len(), 1);
    assert_eq!(
        account.authorizationState.delegations[0].status, 1,
        "delegation lifecycle is independent of credential lifecycle (D3.6.2)"
    );

    let ea = compute_effective_authority_impl(&account, &[], U256::from(500u64));
    assert!(
        ea.iter().any(|c| c.kind.name == "Delegate"),
        "delegation still contributes after credential revocation (D3.6.2)"
    );
}

#[test]
fn multi_source_authority_unions_independent_contributions() {
    let account = empty_account();
    let (account, applied_1) = register_credential_impl(&account, &valid_credential(1));
    assert!(applied_1);
    let (account, applied_2) = register_credential_impl(&account, &valid_credential(2));
    assert!(applied_2);

    let cap_upload = valid_capability("Upload");
    let cap_view = valid_capability("View");

    let (account, applied) =
        set_credential_authority_impl(&account, &valid_credential(1), &[cap_upload.clone()]);
    assert!(applied);
    let (account, applied) =
        set_credential_authority_impl(&account, &valid_credential(2), &[cap_view.clone()]);
    assert!(applied);

    let ea = compute_effective_authority_impl(&account, &[], U256::from(500u64));

    assert!(
        ea.iter().any(|c| c.kind.name == "Upload"),
        "Upload from credential 1"
    );
    assert!(
        ea.iter().any(|c| c.kind.name == "View"),
        "View from credential 2"
    );
    assert_eq!(
        ea.len(),
        2,
        "EA is the union of independent contributions (D1.17)"
    );
}

#[test]
fn transitive_delegation_succeeds_with_recognized_parent() {
    let account = empty_account();
    let sovereign_id = account.identity.id.clone();
    let subject_s = SubjectAbi {
        reference: Bytes::from(vec![7u8, 7u8, 7u8, 7u8]),
    };

    let delegate_cap = valid_capability("Delegate");

    let mut root = valid_delegation(42, sovereign_id);
    root.delegatee = subject_s.clone();
    root.capabilities = vec![delegate_cap.clone()];

    let (account, applied) = register_delegation_impl(
        &account,
        &root,
        &delegate_cap,
        &[delegate_cap.clone()],
        &[delegate_cap.clone()],
    );
    assert!(applied, "root delegation must register");
    assert_eq!(account.authorizationState.delegations.len(), 1);

    let id_2 = IdentityAbi {
        id: Bytes::from(vec![1u8, 1u8, 1u8, 1u8]),
        subject: subject_s.clone(),
    };

    let child = DelegationAbi {
        id: Bytes::from(vec![43u8]),
        delegatorIdentityId: id_2.id.clone(),
        delegatee: SubjectAbi {
            reference: Bytes::from(vec![8u8, 8u8, 8u8, 8u8]),
        },
        capabilities: vec![delegate_cap.clone()],
        validFrom: U256::from(0u64),
        validUntil: U256::from(1000u64),
        restrictions: vec![],
        metadata: Bytes::new(),
        status: 1,
    };

    let (account, applied) = register_transitive_delegation_impl(
        &account,
        &child,
        &delegate_cap,
        &[delegate_cap.clone()],
        &[delegate_cap.clone()],
        &[root.id.clone()],
        &[id_2],
    );

    assert!(
        applied,
        "transitive delegation with recognized parent must succeed (D1.24)"
    );
    assert_eq!(account.authorizationState.delegations.len(), 2);
    assert_eq!(account.authorizationState.delegationProvenance.len(), 2);

    let child_prov = account
        .authorizationState
        .delegationProvenance
        .iter()
        .find(|e| e.delegationId == child.id)
        .expect("child delegation provenance must exist");
    assert_eq!(
        child_prov.parents,
        vec![root.id.clone()],
        "child delegation provenance must name the parent (D1.24)"
    );

    assert!(valid_account_impl(&account));
}

#[test]
fn compute_effective_authority_excludes_revoked_delegation() {
    let account = empty_account();
    let delegate_cap = valid_capability("Delegate");

    let mut delegation = valid_delegation(42, account.identity.id.clone());
    delegation.capabilities = vec![delegate_cap.clone()];

    let (account, applied) = register_delegation_impl(
        &account,
        &delegation,
        &delegate_cap,
        &[delegate_cap.clone()],
        &[delegate_cap.clone()],
    );
    assert!(applied);

    let ea_before = compute_effective_authority_impl(&account, &[], U256::from(500u64));
    assert!(
        ea_before.iter().any(|c| c.kind.name == "Delegate"),
        "before revocation, Delegate is in EA"
    );

    let (account, applied) = update_delegation_status_impl(&account, &delegation, 2);
    assert!(applied);

    let ea_after = compute_effective_authority_impl(&account, &[], U256::from(500u64));
    assert!(
        !ea_after.iter().any(|c| c.kind.name == "Delegate"),
        "revoked delegation must not contribute (D1.41)"
    );

    assert_eq!(account.authorizationState.delegations.len(), 1);
    assert_eq!(account.authorizationState.delegations[0].status, 2);
}

// ============================================================================
// 16. Edge cases and boundary tests
// ============================================================================

#[test]
fn authorization_can_be_accepted_full_with_requested_authority_within_ea() {
    let account = account_with_credential(1);
    let cap = valid_capability("Upload");
    let (account, applied) =
        set_credential_authority_impl(&account, &valid_credential(1), &[cap.clone()]);
    assert!(applied);

    let auth = AuthorizationAbi {
        credentialId: Bytes::from(vec![1u8]),
        requestedAuthority: vec![cap.clone()],
        restrictions: vec![],
        validFrom: U256::from(0u64),
        validUntil: U256::from(1000u64),
        replayKey: Bytes::from(vec![10u8]),
        accountId: account.id.clone(),
        scope: empty_scope_abi(),
    };

    let accepted = authorization_can_be_accepted_full_impl(
        &auth, &account, &[], U256::from(500u64), true,
    );

    assert!(accepted, "requested authority ⊆ EA must be accepted (D1.32)");
}

#[test]
fn authorization_can_be_accepted_full_rejects_requested_authority_outside_ea() {
    let account = account_with_credential(1);
    let cap = valid_capability("Upload");
    let (account, _) =
        set_credential_authority_impl(&account, &valid_credential(1), &[cap.clone()]);

    let auth = AuthorizationAbi {
        credentialId: Bytes::from(vec![1u8]),
        requestedAuthority: vec![valid_capability("Transfer")],
        restrictions: vec![],
        validFrom: U256::from(0u64),
        validUntil: U256::from(1000u64),
        replayKey: Bytes::from(vec![11u8]),
        accountId: account.id.clone(),
        scope: empty_scope_abi(),
    };

    let accepted = authorization_can_be_accepted_full_impl(
        &auth, &account, &[], U256::from(500u64), true,
    );

    assert!(!accepted, "requested authority ∉ EA must reject (D1.32)");
}

#[test]
fn compute_effective_authority_excludes_suspended_credential() {
    let account = account_with_credential(1);
    let cap = valid_capability("Upload");
    let (account, _) =
        set_credential_authority_impl(&account, &valid_credential(1), &[cap.clone()]);

    let ea_before = compute_effective_authority_impl(&account, &[], U256::from(500u64));
    assert!(ea_before.iter().any(|c| c.kind.name == "Upload"));

    let (account, applied) =
        update_credential_status_impl(&account, &valid_credential(1), 2);
    assert!(applied);

    let ea_after = compute_effective_authority_impl(&account, &[], U256::from(500u64));
    assert!(
        !ea_after.iter().any(|c| c.kind.name == "Upload"),
        "suspended credential must not contribute to EA (D3.5.1)"
    );

    assert_eq!(account.authorizationState.credentials.len(), 1);
    assert_eq!(account.authorizationState.credentials[0].status, 2);
}

#[test]
fn authorization_can_be_accepted_full_rejects_suspended_credential() {
    let account = account_with_credential(1);
    let (account, applied) =
        update_credential_status_impl(&account, &valid_credential(1), 2);
    assert!(applied);

    let auth = AuthorizationAbi {
        credentialId: Bytes::from(vec![1u8]),
        requestedAuthority: vec![],
        restrictions: vec![],
        validFrom: U256::from(0u64),
        validUntil: U256::from(1000u64),
        replayKey: Bytes::from(vec![12u8]),
        accountId: account.id.clone(),
        scope: empty_scope_abi(),
    };

    let accepted = authorization_can_be_accepted_full_impl(
        &auth, &account, &[], U256::from(500u64), true,
    );

    assert!(!accepted, "suspended credential must not authorize (D3.5)");
}

#[test]
fn authorization_can_be_accepted_full_accepts_at_exact_valid_from() {
    let account = account_with_credential(1);

    let auth = AuthorizationAbi {
        credentialId: Bytes::from(vec![1u8]),
        requestedAuthority: vec![],
        restrictions: vec![],
        validFrom: U256::from(500u64),
        validUntil: U256::from(1000u64),
        replayKey: Bytes::from(vec![13u8]),
        accountId: account.id.clone(),
        scope: empty_scope_abi(),
    };

    let accepted = authorization_can_be_accepted_full_impl(
        &auth, &account, &[], U256::from(500u64), true,
    );

    assert!(accepted, "now == validFrom must be accepted (inclusive)");
}

#[test]
fn authorization_can_be_accepted_full_accepts_at_exact_valid_until() {
    let account = account_with_credential(1);

    let auth = AuthorizationAbi {
        credentialId: Bytes::from(vec![1u8]),
        requestedAuthority: vec![],
        restrictions: vec![],
        validFrom: U256::from(0u64),
        validUntil: U256::from(500u64),
        replayKey: Bytes::from(vec![14u8]),
        accountId: account.id.clone(),
        scope: empty_scope_abi(),
    };

    let accepted = authorization_can_be_accepted_full_impl(
        &auth, &account, &[], U256::from(500u64), true,
    );

    assert!(accepted, "now == validUntil must be accepted (inclusive)");
}

#[test]
fn authorization_can_be_accepted_full_rejects_before_valid_from() {
    let account = account_with_credential(1);

    let auth = AuthorizationAbi {
        credentialId: Bytes::from(vec![1u8]),
        requestedAuthority: vec![],
        restrictions: vec![],
        validFrom: U256::from(600u64),
        validUntil: U256::from(1000u64),
        replayKey: Bytes::from(vec![15u8]),
        accountId: account.id.clone(),
        scope: empty_scope_abi(),
    };

    let accepted = authorization_can_be_accepted_full_impl(
        &auth, &account, &[], U256::from(500u64), true,
    );

    assert!(!accepted, "now < validFrom must be rejected");
}

#[test]
fn authorization_can_be_accepted_full_rejects_after_valid_until() {
    let account = account_with_credential(1);

    let auth = AuthorizationAbi {
        credentialId: Bytes::from(vec![1u8]),
        requestedAuthority: vec![],
        restrictions: vec![],
        validFrom: U256::from(0u64),
        validUntil: U256::from(400u64),
        replayKey: Bytes::from(vec![16u8]),
        accountId: account.id.clone(),
        scope: empty_scope_abi(),
    };

    let accepted = authorization_can_be_accepted_full_impl(
        &auth, &account, &[], U256::from(500u64), true,
    );

    assert!(!accepted, "now > validUntil must be rejected");
}

#[test]
fn add_capability_is_idempotent() {
    let account = empty_account();
    let cap = valid_capability("Upload");

    let (account, applied) = add_capability_impl(&account, &cap);
    assert!(applied);
    assert_eq!(account.authorizationState.capabilities.len(), 1);

    let (account, applied) = add_capability_impl(&account, &cap);
    assert!(applied);
    assert_eq!(
        account.authorizationState.capabilities.len(),
        1,
        "adding the same capability twice must be idempotent (D1.31)"
    );
    assert_eq!(account.authorizationState.capabilities[0].kind.name, "Upload");
    assert!(valid_account_impl(&account));
}

#[test]
fn selective_credential_revocation_preserves_other_authority() {
    let account = empty_account();
    let (account, _) = register_credential_impl(&account, &valid_credential(1));
    let (account, _) = register_credential_impl(&account, &valid_credential(2));

    let cap_up = valid_capability("Upload");
    let cap_view = valid_capability("View");

    let (account, _) =
        set_credential_authority_impl(&account, &valid_credential(1), &[cap_up.clone()]);
    let (account, _) =
        set_credential_authority_impl(&account, &valid_credential(2), &[cap_view.clone()]);

    let ea_before = compute_effective_authority_impl(&account, &[], U256::from(500u64));
    assert!(ea_before.iter().any(|c| c.kind.name == "Upload"));
    assert!(ea_before.iter().any(|c| c.kind.name == "View"));

    let (account, applied) =
        update_credential_status_impl(&account, &valid_credential(1), 3);
    assert!(applied);

    let ea_after = compute_effective_authority_impl(&account, &[], U256::from(500u64));
    assert!(
        !ea_after.iter().any(|c| c.kind.name == "Upload"),
        "revoked credential 1 contribution removed (D1.17)"
    );
    assert!(
        ea_after.iter().any(|c| c.kind.name == "View"),
        "credential 2 contribution preserved (D1.17)"
    );
}

#[test]
fn transitive_delegation_rejects_child_capability_not_in_parent() {
    let account = empty_account();
    let delegate_cap = valid_capability("Delegate");
    let upload_cap = valid_capability("Upload");
    let subject_s = SubjectAbi {
        reference: Bytes::from(vec![7u8, 7u8]),
    };

    let mut root = valid_delegation(42, account.identity.id.clone());
    root.delegatee = subject_s.clone();
    root.capabilities = vec![delegate_cap.clone()];

    let (account, applied) = register_delegation_impl(
        &account,
        &root,
        &delegate_cap,
        &[delegate_cap.clone()],
        &[delegate_cap.clone()],
    );
    assert!(applied);

    let id_2 = IdentityAbi {
        id: Bytes::from(vec![1u8, 1u8]),
        subject: subject_s.clone(),
    };

    let child = DelegationAbi {
        id: Bytes::from(vec![43u8]),
        delegatorIdentityId: id_2.id.clone(),
        delegatee: SubjectAbi { reference: Bytes::from(vec![8u8, 8u8]) },
        capabilities: vec![delegate_cap.clone(), upload_cap.clone()],
        validFrom: U256::from(0u64),
        validUntil: U256::from(1000u64),
        restrictions: vec![],
        metadata: Bytes::new(),
        status: 1,
    };

    let (result, applied) = register_transitive_delegation_impl(
        &account,
        &child,
        &delegate_cap,
        &[delegate_cap.clone(), upload_cap.clone()],
        &[delegate_cap.clone(), upload_cap.clone()],
        &[root.id.clone()],
        &[id_2],
    );

    assert!(
        !applied,
        "child capability not in parent must reject (D1.25)"
    );
    assert_eq!(result.authorizationState.delegations.len(), 1);
}

#[test]
fn transitive_delegation_rejects_source_not_attributed_to_parent_delegatee() {
    let account = empty_account();
    let delegate_cap = valid_capability("Delegate");
    let parent_subject = SubjectAbi {
        reference: Bytes::from(vec![7u8, 7u8]),
    };

    let mut root = valid_delegation(42, account.identity.id.clone());
    root.delegatee = parent_subject.clone();
    root.capabilities = vec![delegate_cap.clone()];

    let (account, applied) = register_delegation_impl(
        &account,
        &root,
        &delegate_cap,
        &[delegate_cap.clone()],
        &[delegate_cap.clone()],
    );
    assert!(applied);

    let id_2_wrong_subject = IdentityAbi {
        id: Bytes::from(vec![1u8, 1u8]),
        subject: SubjectAbi {
            reference: Bytes::from(vec![9u8, 9u8]),
        },
    };

    let child = DelegationAbi {
        id: Bytes::from(vec![43u8]),
        delegatorIdentityId: id_2_wrong_subject.id.clone(),
        delegatee: SubjectAbi { reference: Bytes::from(vec![8u8, 8u8]) },
        capabilities: vec![delegate_cap.clone()],
        validFrom: U256::from(0u64),
        validUntil: U256::from(1000u64),
        restrictions: vec![],
        metadata: Bytes::new(),
        status: 1,
    };

    let (result, applied) = register_transitive_delegation_impl(
        &account,
        &child,
        &delegate_cap,
        &[delegate_cap.clone()],
        &[delegate_cap.clone()],
        &[root.id.clone()],
        &[id_2_wrong_subject],
    );

    assert!(
        !applied,
        "child source must be attributed to the parent delegatee (D1.24)"
    );
    assert_eq!(result.authorizationState.delegations.len(), 1);
}

#[test]
fn valid_execution_context_rejects_requested_authority_escape() {
    let account = account_with_credential(1);

    let request = ExecutionRequestAbi {
        authorization: AuthorizationAbi {
            credentialId: Bytes::from(vec![1u8]),
            requestedAuthority: vec![valid_capability("Upload")],
            restrictions: vec![],
            validFrom: U256::from(0u64),
            validUntil: U256::from(1000u64),
            replayKey: Bytes::from(vec![17u8]),
            accountId: account.id.clone(),
            scope: empty_scope_abi(),
        },
    };

    let context = ExecutionContextAbi {
        request,
        authorizationState: account.authorizationState.clone(),
        effectiveAuthority: vec![],
        evaluationTime: U256::from(500u64),
    };

    let valid = valid_execution_context_impl(&context, &account, &[], true);

    assert!(
        !valid,
        "requested authority escaping EA must reject (D1.32)"
    );
}

// ============================================================================
// 17. DDD law completeness — D2.6.1, heterogeneous policy, execution replay
// ============================================================================

#[test]
fn policy_with_contradictory_effects_is_rejected() {
    let account = empty_account();
    let cap = valid_capability("Upload");
    let (account, applied) = add_capability_impl(&account, &cap);
    assert!(applied);
    assert_eq!(account.authorizationState.capabilities.len(), 1);

    let disable = PolicyEffectAbi {
        kind: 4, // DisableCapability
        id: Bytes::new(),
        capability: cap.clone(),
        scope: empty_optional_scope_abi(),
        restriction: empty_restriction_abi(),
    };
    let enable = PolicyEffectAbi {
        kind: 5, // EnableCapability
        id: Bytes::new(),
        capability: cap.clone(),
        scope: empty_optional_scope_abi(),
        restriction: empty_restriction_abi(),
    };

    let consumption = PolicyConsumptionAbi {
        policy: PolicyAbi {
            effects: vec![disable, enable],
        },
    };

    let (result, applied) = apply_policy_consumption_impl(&account, &consumption);

    assert!(
        !applied,
        "contradictory effects must reject the whole policy (D2.6.1)"
    );
    assert_eq!(
        result.authorizationState.capabilities.len(),
        1,
        "the account must be unchanged"
    );
    assert_eq!(result.authorizationState.capabilities[0].kind.name, "Upload");
}

#[test]
fn policy_with_heterogeneous_effect_kinds_applies_atomically() {
    let account = account_with_credential(1);
    let view = valid_capability("View");
    let (account, applied) = add_capability_impl(&account, &view);
    assert!(applied);
    assert_eq!(account.authorizationState.credentials[0].status, 1); // Active
    assert_eq!(account.authorizationState.capabilities.len(), 1);

    let revoke_cred = PolicyEffectAbi {
        kind: 1, // RevokeCredential
        id: Bytes::from(vec![1u8]),
        capability: empty_capability_abi(),
        scope: empty_optional_scope_abi(),
        restriction: empty_restriction_abi(),
    };
    let disable_view = PolicyEffectAbi {
        kind: 4, // DisableCapability
        id: Bytes::new(),
        capability: view.clone(),
        scope: empty_optional_scope_abi(),
        restriction: empty_restriction_abi(),
    };

    let consumption = PolicyConsumptionAbi {
        policy: PolicyAbi {
            effects: vec![revoke_cred, disable_view],
        },
    };

    let (result, applied) = apply_policy_consumption_impl(&account, &consumption);

    assert!(applied, "heterogeneous effects must apply atomically (D2.3)");
    assert_eq!(
        result.authorizationState.credentials[0].status, 3,
        "credential must be revoked"
    );
    assert!(
        result.authorizationState.capabilities.is_empty(),
        "capability must be removed"
    );
    assert!(valid_account_impl(&result));
}

#[test]
fn valid_execution_context_rejects_consumed_replay_key() {
    let account = account_with_credential(1);
    let key = Bytes::from(vec![88u8]);

    let (account, applied) = consume_replay_key_impl(&account, &key);
    assert!(applied);
    assert_eq!(account.authorizationState.consumedReplayKeys.len(), 1);

    let request = ExecutionRequestAbi {
        authorization: AuthorizationAbi {
            credentialId: Bytes::from(vec![1u8]),
            requestedAuthority: vec![],
            restrictions: vec![],
            validFrom: U256::from(0u64),
            validUntil: U256::from(1000u64),
            replayKey: key.clone(),
            accountId: account.id.clone(),
            scope: empty_scope_abi(),
        },
    };

    let context = ExecutionContextAbi {
        request,
        authorizationState: account.authorizationState.clone(),
        effectiveAuthority: vec![],
        evaluationTime: U256::from(500u64),
    };

    let valid = valid_execution_context_impl(&context, &account, &[], true);

    assert!(
        !valid,
        "consumed replay key must block execution context acceptance (D4.5.3)"
    );
}

// ============================================================================
// 18. Additional edge cases
// ============================================================================
//
// Deeper probes of the DDD laws exercised through the ABI:
// multi-parent transitive delegation, account-id context match,
// credential recognition at the crown, delegation temporal
// expiration, empty credential authority contribution, credential
// authority idempotency, and the union (not multiset) semantics of
// EffectiveAuthority.

#[test]
fn transitive_delegation_with_multiple_parents() {
    // D1.24 with multiple parents: when a child delegation names more
    // than one parent, each parent must support the child source
    // (delegatee = child source's attributed subject), and each
    // capability of the child must be present in at least one parent.
    //
    // Setup:
    //   - Sovereign identity ID1 = [5,6,7,8], subject = { ref = [9,10] }
    //   - Subject_S = { ref = [7,7,7,7] }
    //   - Parent A (id 41): source = ID1, delegatee = S, caps = [Delegate]
    //   - Parent B (id 42): source = ID1, delegatee = S, caps = [Upload]
    //   - Identity ID2 = [1,1,1,1], attributed to S
    //   - Child (id 43): source = ID2, caps = [Delegate, Upload],
    //                    parentDelegationIds = [41, 42]
    //
    // Expected: registration succeeds. Each parent supports the source
    // (delegatee = S), and each capability of the child is present in
    // some parent.
    //
    // Fixture invariant (D1.7): the delegatable_authority passed to a
    // delegation registration must contain the delegation's own
    // capabilities, and the source_effective_authority must contain
    // both the delegate capability and the delegatable_authority.
    let account = empty_account();
    let sovereign_id = account.identity.id.clone();
    let subject_s = SubjectAbi {
        reference: Bytes::from(vec![7u8, 7u8, 7u8, 7u8]),
    };
    let delegate_cap = valid_capability("Delegate");
    let upload_cap = valid_capability("Upload");

    let mut parent_a = valid_delegation(41, sovereign_id.clone());
    parent_a.delegatee = subject_s.clone();
    parent_a.capabilities = vec![delegate_cap.clone()];

    let mut parent_b = valid_delegation(42, sovereign_id.clone());
    parent_b.delegatee = subject_s.clone();
    parent_b.capabilities = vec![upload_cap.clone()];

    let (account, applied) = register_delegation_impl(
        &account,
        &parent_a,
        &delegate_cap,
        &[delegate_cap.clone()],
        &[delegate_cap.clone()],
    );
    assert!(applied, "parent A must register");

    let (account, applied) = register_delegation_impl(
        &account,
        &parent_b,
        &delegate_cap,
        &[upload_cap.clone()],
        &[delegate_cap.clone(), upload_cap.clone()],
    );
    assert!(applied, "parent B must register");
    assert_eq!(account.authorizationState.delegations.len(), 2);

    let id_2 = IdentityAbi {
        id: Bytes::from(vec![1u8, 1u8, 1u8, 1u8]),
        subject: subject_s,
    };

    let child = DelegationAbi {
        id: Bytes::from(vec![43u8]),
        delegatorIdentityId: id_2.id.clone(),
        delegatee: SubjectAbi {
            reference: Bytes::from(vec![8u8, 8u8, 8u8, 8u8]),
        },
        capabilities: vec![delegate_cap.clone(), upload_cap.clone()],
        validFrom: U256::from(0u64),
        validUntil: U256::from(1000u64),
        restrictions: vec![],
        metadata: Bytes::new(),
        status: 1,
    };

    let (account, applied) = register_transitive_delegation_impl(
        &account,
        &child,
        &delegate_cap,
        &[delegate_cap.clone(), upload_cap.clone()],
        &[delegate_cap.clone(), upload_cap.clone()],
        &[parent_a.id.clone(), parent_b.id.clone()],
        &[id_2],
    );

    assert!(
        applied,
        "child with multiple valid parents must register (D1.24)"
    );
    assert_eq!(account.authorizationState.delegations.len(), 3);

    let child_prov = account
        .authorizationState
        .delegationProvenance
        .iter()
        .find(|e| e.delegationId == child.id)
        .expect("child provenance must exist");
    assert_eq!(child_prov.parents.len(), 2);
    assert!(child_prov.parents.contains(&parent_a.id));
    assert!(child_prov.parents.contains(&parent_b.id));

    assert!(valid_account_impl(&account));
}

#[test]
fn authorization_with_mismatched_account_id_is_rejected() {
    let account = account_with_credential(1);

    let auth = AuthorizationAbi {
        credentialId: Bytes::from(vec![1u8]),
        requestedAuthority: vec![],
        restrictions: vec![],
        validFrom: U256::from(0u64),
        validUntil: U256::from(1000u64),
        replayKey: Bytes::from(vec![20u8]),
        accountId: Bytes::from(vec![9u8, 9u8, 9u8, 9u8]),
        scope: empty_scope_abi(),
    };

    let accepted = authorization_can_be_accepted_full_impl(
        &auth,
        &account,
        &[],
        U256::from(500u64),
        true,
    );

    assert!(
        !accepted,
        "mismatched accountId must reject authorization"
    );
}

#[test]
fn authorization_can_be_accepted_full_rejects_unrecognized_credential() {
    let account = account_with_credential(1);

    let auth = AuthorizationAbi {
        credentialId: Bytes::from(vec![99u8]),
        requestedAuthority: vec![],
        restrictions: vec![],
        validFrom: U256::from(0u64),
        validUntil: U256::from(1000u64),
        replayKey: Bytes::from(vec![21u8]),
        accountId: account.id.clone(),
        scope: empty_scope_abi(),
    };

    let accepted = authorization_can_be_accepted_full_impl(
        &auth,
        &account,
        &[],
        U256::from(500u64),
        true,
    );

    assert!(
        !accepted,
        "unrecognized credential must reject authorization"
    );
}

#[test]
fn delegation_expires_past_valid_until_does_not_contribute_to_ea() {
    let account = empty_account();
    let delegate_cap = valid_capability("Delegate");

    let mut delegation = valid_delegation(42, account.identity.id.clone());
    delegation.capabilities = vec![delegate_cap.clone()];
    delegation.validUntil = U256::from(400u64);

    let (account, applied) = register_delegation_impl(
        &account,
        &delegation,
        &delegate_cap,
        &[delegate_cap.clone()],
        &[delegate_cap.clone()],
    );
    assert!(applied);

    let ea_before = compute_effective_authority_impl(&account, &[], U256::from(300u64));
    assert!(
        ea_before.iter().any(|c| c.kind.name == "Delegate"),
        "within validity, delegation contributes"
    );

    let ea_after = compute_effective_authority_impl(&account, &[], U256::from(500u64));
    assert!(
        !ea_after.iter().any(|c| c.kind.name == "Delegate"),
        "expired delegation must not contribute to EA (D1.41)"
    );

    assert_eq!(account.authorizationState.delegations.len(), 1);
    assert_eq!(
        account.authorizationState.delegations[0].status, 1,
        "delegation status is unchanged by temporal expiration"
    );
}

#[test]
fn empty_credential_authority_contributes_nothing_to_ea() {
    let account = account_with_credential(1);
    assert_eq!(account.authorizationState.credentialAuthorities.len(), 1);
    assert!(
        account.authorizationState.credentialAuthorities[0].authority.is_empty(),
        "newly registered credential has empty authority"
    );

    let ea = compute_effective_authority_impl(&account, &[], U256::from(500u64));

    assert!(
        ea.is_empty(),
        "active credential with empty authority contributes nothing (D1.30)"
    );
}

#[test]
fn credential_authority_update_is_idempotent() {
    let account = account_with_credential(1);
    let cap = valid_capability("Upload");

    let (account, applied) =
        set_credential_authority_impl(&account, &valid_credential(1), &[cap.clone()]);
    assert!(applied);

    let ea_1 = compute_effective_authority_impl(&account, &[], U256::from(500u64));

    let (account, applied) =
        set_credential_authority_impl(&account, &valid_credential(1), &[cap.clone()]);
    assert!(applied);

    let ea_2 = compute_effective_authority_impl(&account, &[], U256::from(500u64));

    assert_eq!(
        ea_1.len(),
        ea_2.len(),
        "setting the same authority twice must be idempotent (D1.31)"
    );
    assert_eq!(ea_1[0].kind.name, ea_2[0].kind.name);
}

#[test]
fn multiple_credentials_with_same_authority_union_to_single_capability() {
    let account = empty_account();
    let (account, _) = register_credential_impl(&account, &valid_credential(1));
    let (account, _) = register_credential_impl(&account, &valid_credential(2));

    let cap = valid_capability("Upload");
    let (account, _) =
        set_credential_authority_impl(&account, &valid_credential(1), &[cap.clone()]);
    let (account, _) =
        set_credential_authority_impl(&account, &valid_credential(2), &[cap.clone()]);

    let ea = compute_effective_authority_impl(&account, &[], U256::from(500u64));

    assert_eq!(
        ea.len(),
        1,
        "EA is a set union, not a multiset (D1.17)"
    );
    assert_eq!(ea[0].kind.name, "Upload");
}

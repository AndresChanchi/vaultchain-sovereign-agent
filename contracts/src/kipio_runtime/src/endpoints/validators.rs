//! Dafny-derived validation entrypoints.
//!
//! These handlers wrap the ABI ↔ Dafny translation layer. They read the
//! account state via a raw cross-contract call (not through the public
//! endpoint, to keep the cross-call budget minimal when several
//! validators run in the same dispatch) and delegate the pure
//! computation to `kipio_account_bridge`.

use alloc::vec::Vec;

use kipio_account_bridge::{
    apply_policy_consumption_impl, authorization_can_be_accepted_full_impl,
    authorization_is_structurally_valid_impl, compute_effective_authority_impl,
    valid_execution_context_impl, AuthorizationAbi, AuthorizationStateAbi, CapabilityAbi,
    ExecutionContextAbi, IdentityAbi, PolicyConsumptionAbi,
};
use stylus_sdk::alloy_primitives::{Address, U256};

use crate::storage::entrypoint::KipioRuntime;

pub(crate) fn handle_read_account_state(
    this: &KipioRuntime,
    account_addr: Address,
) -> Result<AuthorizationStateAbi, Vec<u8>> {
    this.read_account_state_raw(account_addr)
}

pub(crate) fn handle_authorization_is_structurally_valid(auth: AuthorizationAbi) -> bool {
    authorization_is_structurally_valid_impl(&auth)
}

pub(crate) fn handle_authorization_can_be_accepted_full(
    this: &KipioRuntime,
    account_addr: Address,
    auth: AuthorizationAbi,
    identities: Vec<IdentityAbi>,
    now: U256,
    proof_verified: bool,
) -> Result<bool, Vec<u8>> {
    let state = this.read_account_state_raw(account_addr)?;
    let account = this.build_account_abi(account_addr, state);

    Ok(authorization_can_be_accepted_full_impl(
        &auth,
        &account,
        &identities,
        now,
        proof_verified,
    ))
}

pub(crate) fn handle_compute_effective_authority(
    this: &KipioRuntime,
    account_addr: Address,
    identities: Vec<IdentityAbi>,
    now: U256,
) -> Result<Vec<CapabilityAbi>, Vec<u8>> {
    let state = this.read_account_state_raw(account_addr)?;
    let account = this.build_account_abi(account_addr, state);

    Ok(compute_effective_authority_impl(&account, &identities, now))
}

pub(crate) fn handle_apply_policy_consumption(
    this: &KipioRuntime,
    account_addr: Address,
    consumption: PolicyConsumptionAbi,
) -> Result<bool, Vec<u8>> {
    let state = this.read_account_state_raw(account_addr)?;
    let account = this.build_account_abi(account_addr, state);

    // Only evaluates applicability. The actual state persistence happens
    // inside Account's mutating entrypoints. Callers that want to apply
    // the policy should use `dispatch` with a target pointing at the
    // account.
    let (_, applied) = apply_policy_consumption_impl(&account, &consumption);
    Ok(applied)
}

pub(crate) fn handle_valid_execution_context(
    this: &KipioRuntime,
    account_addr: Address,
    context: ExecutionContextAbi,
    identities: Vec<IdentityAbi>,
    proof_verified: bool,
) -> Result<bool, Vec<u8>> {
    let state = this.read_account_state_raw(account_addr)?;
    let account = this.build_account_abi(account_addr, state);

    Ok(valid_execution_context_impl(
        &context,
        &account,
        &identities,
        proof_verified,
    ))
}

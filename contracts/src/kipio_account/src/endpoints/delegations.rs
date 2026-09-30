//! Delegation lifecycle transitions.

use alloc::vec::Vec;

use kipio_account_bridge::{
    register_delegation_impl, register_transitive_delegation_impl,
    update_delegation_status_impl, CapabilityAbi, DelegationAbi, IdentityAbi,
};

use stylus_sdk::abi::Bytes;
use crate::storage::entrypoint::KipioAccount;

pub(crate) fn handle_register_delegation(
    this: &mut KipioAccount,
    delegation: DelegationAbi,
    delegate_capability: CapabilityAbi,
    delegatable_authority: Vec<CapabilityAbi>,
    source_effective_authority: Vec<CapabilityAbi>,
) -> Result<bool, Vec<u8>> {
    this.require_runtime()?;
    this.require_initialized()?;
    let account = this.build_account_abi(&this.read_authorization_state());

    let (new_account, applied) = register_delegation_impl(
        &account,
        &delegation,
        &delegate_capability,
        &delegatable_authority,
        &source_effective_authority,
    );
    if applied {
        this.persist_state(&new_account.authorizationState);
        this.increment_nonce();
    }
    Ok(applied)
}

pub(crate) fn handle_register_transitive_delegation(
    this: &mut KipioAccount,
    delegation: DelegationAbi,
    delegate_capability: CapabilityAbi,
    delegatable_authority: Vec<CapabilityAbi>,
    source_effective_authority: Vec<CapabilityAbi>,
    parent_delegation_ids: Vec<Bytes>,
    identities: Vec<IdentityAbi>,
) -> Result<bool, Vec<u8>> {
    this.require_runtime()?;
    this.require_initialized()?;
    let account = this.build_account_abi(&this.read_authorization_state());

    let (new_account, applied) = register_transitive_delegation_impl(
        &account,
        &delegation,
        &delegate_capability,
        &delegatable_authority,
        &source_effective_authority,
        &parent_delegation_ids,
        &identities,
    );
    if applied {
        this.persist_state(&new_account.authorizationState);
        this.increment_nonce();
    }
    Ok(applied)
}

pub(crate) fn handle_update_delegation_status(
    this: &mut KipioAccount,
    delegation: DelegationAbi,
    new_status: u8,
) -> Result<bool, Vec<u8>> {
    this.require_runtime()?;
    this.require_initialized()?;
    let account = this.build_account_abi(&this.read_authorization_state());

    let (new_account, applied) =
        update_delegation_status_impl(&account, &delegation, new_status);
    if applied {
        this.persist_state(&new_account.authorizationState);
        this.increment_nonce();
    }
    Ok(applied)
}

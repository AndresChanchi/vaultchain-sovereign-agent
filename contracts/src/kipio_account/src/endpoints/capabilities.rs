//! Capability and restriction transitions.

use alloc::vec::Vec;

use kipio_account_bridge::{
    add_capability_impl, remove_capability_impl, remove_restriction_impl,
    set_restriction_impl, CapabilityAbi, OptionalScopeAbi, RestrictionAbi,
};

use crate::storage::entrypoint::KipioAccount;

pub(crate) fn handle_add_capability(
    this: &mut KipioAccount,
    capability: CapabilityAbi,
) -> Result<bool, Vec<u8>> {
    this.require_runtime()?;
    this.require_initialized()?;
    let account = this.build_account_abi(&this.read_authorization_state());

    let (new_account, applied) = add_capability_impl(&account, &capability);
    if applied {
        this.persist_state(&new_account.authorizationState);
        this.increment_nonce();
    }
    Ok(applied)
}

pub(crate) fn handle_remove_capability(
    this: &mut KipioAccount,
    capability: CapabilityAbi,
) -> Result<bool, Vec<u8>> {
    this.require_runtime()?;
    this.require_initialized()?;
    let account = this.build_account_abi(&this.read_authorization_state());

    let (new_account, applied) = remove_capability_impl(&account, &capability);
    if applied {
        this.persist_state(&new_account.authorizationState);
        this.increment_nonce();
    }
    Ok(applied)
}

pub(crate) fn handle_set_restriction(
    this: &mut KipioAccount,
    capability: CapabilityAbi,
    scope: OptionalScopeAbi,
    restriction: RestrictionAbi,
) -> Result<bool, Vec<u8>> {
    this.require_runtime()?;
    this.require_initialized()?;
    let account = this.build_account_abi(&this.read_authorization_state());

    let (new_account, applied) =
        set_restriction_impl(&account, &capability, &scope, &restriction);
    if applied {
        this.persist_state(&new_account.authorizationState);
        this.increment_nonce();
    }
    Ok(applied)
}

pub(crate) fn handle_remove_restriction(
    this: &mut KipioAccount,
    capability: CapabilityAbi,
    scope: OptionalScopeAbi,
) -> Result<bool, Vec<u8>> {
    this.require_runtime()?;
    this.require_initialized()?;
    let account = this.build_account_abi(&this.read_authorization_state());

    let (new_account, applied) = remove_restriction_impl(&account, &capability, &scope);
    if applied {
        this.persist_state(&new_account.authorizationState);
        this.increment_nonce();
    }
    Ok(applied)
}

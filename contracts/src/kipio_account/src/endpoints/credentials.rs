//! Credential lifecycle transitions.

use alloc::vec::Vec;

use kipio_account_bridge::{
    register_credential_impl, set_credential_authority_impl,
    update_credential_status_impl, CapabilityAbi, CredentialAbi,
};

use stylus_sdk::alloy_primitives::{B256, U8};
use crate::storage::entrypoint::KipioAccount;

pub(crate) fn handle_register_credential(
    this: &mut KipioAccount,
    credential: CredentialAbi,
) -> Result<bool, Vec<u8>> {
    this.require_runtime()?;
    this.require_initialized()?;
    let account = this.build_account_abi(&this.read_authorization_state());

    let (new_account, applied) = register_credential_impl(&account, &credential);
    if applied {
        this.persist_state(&new_account.authorizationState);
        let key = B256::from_slice(&credential.id);
        this.credential_statuses
            .setter(key)
            .set(U8::from(credential.status));
        this.increment_nonce();
    }
    Ok(applied)
}

pub(crate) fn handle_set_credential_authority(
    this: &mut KipioAccount,
    credential: CredentialAbi,
    authority: Vec<CapabilityAbi>,
) -> Result<bool, Vec<u8>> {
    this.require_runtime()?;
    this.require_initialized()?;
    let account = this.build_account_abi(&this.read_authorization_state());

    let (new_account, applied) =
        set_credential_authority_impl(&account, &credential, &authority);
    if applied {
        this.persist_state(&new_account.authorizationState);
        this.increment_nonce();
    }
    Ok(applied)
}

pub(crate) fn handle_update_credential_status(
    this: &mut KipioAccount,
    credential: CredentialAbi,
    new_status: u8,
) -> Result<bool, Vec<u8>> {
    this.require_runtime()?;
    this.require_initialized()?;
    let account = this.build_account_abi(&this.read_authorization_state());

    let (_, applied) = update_credential_status_impl(&account, &credential, new_status);

    if applied {
        let key = B256::from_slice(&credential.id);
        this.credential_statuses
            .setter(key)
            .set(U8::from(new_status));
        this.increment_nonce();
    }
    Ok(applied)
}

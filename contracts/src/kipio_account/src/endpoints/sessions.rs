//! Session lifecycle transitions.

use alloc::vec::Vec;

use kipio_account_bridge::{register_session_impl, update_session_status_impl, SessionAbi};

use crate::storage::entrypoint::KipioAccount;

pub(crate) fn handle_register_session(
    this: &mut KipioAccount,
    session: SessionAbi,
) -> Result<bool, Vec<u8>> {
    this.require_runtime()?;
    this.require_initialized()?;
    let account = this.build_account_abi(&this.read_authorization_state());

    let (new_account, applied) = register_session_impl(&account, &session);
    if applied {
        this.persist_state(&new_account.authorizationState);
        this.increment_nonce();
    }
    Ok(applied)
}

pub(crate) fn handle_update_session_status(
    this: &mut KipioAccount,
    session: SessionAbi,
    new_status: u8,
) -> Result<bool, Vec<u8>> {
    this.require_runtime()?;
    this.require_initialized()?;
    let account = this.build_account_abi(&this.read_authorization_state());

    let (new_account, applied) = update_session_status_impl(&account, &session, new_status);
    if applied {
        this.persist_state(&new_account.authorizationState);
        this.increment_nonce();
    }
    Ok(applied)
}

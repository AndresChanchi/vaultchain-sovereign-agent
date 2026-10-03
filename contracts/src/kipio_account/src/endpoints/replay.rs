//! Replay key consumption (hot path).

use alloc::vec::Vec;

use kipio_account_bridge::consume_replay_key_impl;
use stylus_sdk::{
    abi::Bytes,
    alloy_primitives::B256,
};

use crate::storage::entrypoint::KipioAccount;

pub(crate) fn handle_consume_replay_key(
    this: &mut KipioAccount,
    replay_key: Bytes,
) -> Result<bool, Vec<u8>> {
    this.require_runtime()?;
    this.require_initialized()?;
    let key_hash = B256::from_slice(&replay_key);

    if this.consumed_replay_keys.get(key_hash) {
        return Ok(false);
    }

    let account = this.build_account_abi(&this.read_authorization_state());
    let (_, applied) = consume_replay_key_impl(&account, &replay_key);

    if applied {
        this.consumed_replay_keys.setter(key_hash).set(true);
        this.increment_nonce();
    }
    Ok(applied)
}

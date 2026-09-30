//! Recovery effect application (Runtime-only).

use alloc::vec::Vec;

use kipio_account_bridge::{NotInitialized, RecoveryConsumeFailed, RecoveryEffect};
use stylus_sdk::{
    alloy_primitives::{Address, B256},
    alloy_sol_types::{SolError, SolValue},
    crypto::keccak,
    prelude::*,
};

use crate::abi::interfaces::IKipioRecovery;
use crate::storage::entrypoint::KipioAccount;

pub(crate) fn handle_execute_recovery(
    this: &mut KipioAccount,
    request_id: B256,
    effects: Vec<RecoveryEffect>,
) -> Result<(), Vec<u8>> {
    this.require_runtime()?;
    this.require_initialized()?;

    let encoded = effects.abi_encode();
    let computed_hash = keccak(&encoded);

    let recovery_addr = this.recovery_address.get();
    if recovery_addr == Address::ZERO {
        return Err(NotInitialized {}.abi_encode());
    }

    let account_addr = this.vm().contract_address();
    let recovery = IKipioRecovery::new(recovery_addr);
    let ctx = Call::new_mutating(this);
    let host = this.vm();

    recovery
        .consume_recovery(host, ctx, account_addr, request_id, computed_hash)
        .map_err(|_| RecoveryConsumeFailed {}.abi_encode())?;

    KipioAccount::validate_effects(&effects)?;
    this.apply_effects(&effects)?;

    this.increment_nonce();
    Ok(())
}

//! `consume_recovery` handler.

use alloc::vec::Vec;

use stylus_sdk::{
    alloy_primitives::{Address, B256, U8, U64},
    alloy_sol_types::SolError,
    prelude::*,
};

use crate::abi::errors::{
    RecoveryExpiredErr, RecoveryNotApproved, RecoveryNotExecutableYet, RecoveryNotFound,
    SignatureVerificationFailed, UnauthorizedCaller,
};
use crate::abi::events::RecoveryExecuted;
use crate::config::constants::{RECOVERY_STATUS_APPROVED, RECOVERY_STATUS_EXECUTED, RECOVERY_STATUS_NONE};
use crate::storage::entrypoint::KipioRecovery;

pub(crate) fn handle_consume_recovery(
    this: &mut KipioRecovery,
    account: Address,
    request_id: B256,
    effects_hash: B256,
) -> Result<(), Vec<u8>> {
    if this.vm().msg_sender() != account {
        return Err(UnauthorizedCaller {}.abi_encode());
    }

    let status = this
        .recovery_status
        .getter(account)
        .getter(request_id)
        .get()
        .to::<u8>();
    if status == RECOVERY_STATUS_NONE {
        return Err(RecoveryNotFound {}.abi_encode());
    }
    if status != RECOVERY_STATUS_APPROVED {
        return Err(RecoveryNotApproved {}.abi_encode());
    }

    if this.is_expired(account, request_id) {
        this.mark_expired(account, request_id);
        return Err(RecoveryExpiredErr {}.abi_encode());
    }

    let now = U64::from(this.vm().block_timestamp());
    let executable_after = this
        .recovery_executable_after
        .getter(account)
        .getter(request_id)
        .get();
    if now < executable_after {
        return Err(RecoveryNotExecutableYet {}.abi_encode());
    }

    let expected_hash = this
        .recovery_target_hash
        .getter(account)
        .getter(request_id)
        .get();
    if effects_hash != expected_hash {
        return Err(SignatureVerificationFailed {}.abi_encode());
    }

    // EFFECTS
    this.recovery_status
        .setter(account)
        .setter(request_id)
        .set(U8::from(RECOVERY_STATUS_EXECUTED));
    this.active_recovery_id.setter(account).set(B256::ZERO);

    // OBSERVABILITY
    this.vm().log(RecoveryExecuted {
        requestId: request_id,
        executedBy: account,
    });

    Ok(())
}

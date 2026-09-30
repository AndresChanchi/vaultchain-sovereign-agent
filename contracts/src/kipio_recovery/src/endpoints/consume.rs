//! `consume_recovery` handler.
//!
//! Terminal transition of an APPROVED recovery request. Two callers
//! are authorized to drive it:
//!
//!   1. **The account itself** (`msg_sender == account`). This is the
//!      path used by `kipio_account.execute_recovery`, where the
//!      sovereign smart account consumes the request on behalf of its
//!      identity. The account is the sole arbiter of its own recovery
//!      when it holds the credential material needed to apply the
//!      effects.
//!
//!   2. **The runtime orchestrator** (`msg_sender == runtime_address`).
//!      This is the path used by `kipio_runtime` when a recovery drives
//!      a state mutation on another contract in the protocol — for
//!      example, a pubkey rotation approved by the guardian threshold
//!      and applied on `kipio_identity_content` through
//!      `applyAuthorizedRotation`. In that flow the runtime:
//!
//!        a. reads the APPROVED recovery request from this contract,
//!        b. verifies the effects match what is about to be executed,
//!        c. applies the state mutation on the target contract,
//!        d. consumes the request here, marking it EXECUTED.
//!
//!      All four steps happen in a single atomic transaction. If any
//!      of them reverts, the entire batch reverts, including the
//!      already-applied mutation. This makes the recovery a coherent
//!      transactional unit even though it spans multiple contracts.
//!
//! Both callers pass the same validations:
//!
//!   - The request must exist for the given account.
//!   - The request must be in APPROVED status.
//!   - The deadline must not have passed.
//!   - `executable_after` must have been reached (challenge period).
//!   - The provided `effects_hash` must match the recorded target hash.
//!
//! The `RecoveryExecuted` event's `executedBy` field records the actual
//! on-chain caller. Indexers can use this field to distinguish between
//! an account-driven consumption (the account invokes directly) and a
//! runtime-driven consumption (the orchestrator consumes the request
//! after applying the mutation elsewhere).
//!
//! CEI ORDERING:
//!
//! The status transition to EXECUTED and the cleanup of the active
//! request pointer happen before the event is emitted. There is no
//! cross-contract call inside this handler, so there is nothing to
//! interleave with the state mutation.

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
use crate::config::constants::{
    RECOVERY_STATUS_APPROVED, RECOVERY_STATUS_EXECUTED, RECOVERY_STATUS_NONE,
};
use crate::storage::entrypoint::KipioRecovery;

pub(crate) fn handle_consume_recovery(
    this: &mut KipioRecovery,
    account: Address,
    request_id: B256,
    effects_hash: B256,
) -> Result<(), Vec<u8>> {
    // Two authorized callers:
    //   1. The account itself (account-driven recovery flow, used by
    //      `kipio_account.execute_recovery`).
    //   2. The runtime orchestrator (identity-content-driven recovery
    //      flow, where the runtime applies a state mutation on another
    //      contract and then consumes the request here).
    //
    // Any other caller reverts with `UnauthorizedCaller`. See the
    // module-level documentation for the full rationale.
    let sender = this.vm().msg_sender();
    let runtime = this.runtime_address.get();
    if sender != account && sender != runtime {
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

    // ------------------------------------------------------------------
    // EFFECTS
    // ------------------------------------------------------------------
    //
    // Mark the request as EXECUTED and clear the active request
    // pointer. Both writes happen before the event so the state is
    // consistent for any indexer that reads storage immediately after
    // observing the log.

    this.recovery_status
        .setter(account)
        .setter(request_id)
        .set(U8::from(RECOVERY_STATUS_EXECUTED));
    this.active_recovery_id.setter(account).set(B256::ZERO);

    // ------------------------------------------------------------------
    // OBSERVABILITY
    // ------------------------------------------------------------------
    //
    // `executedBy` records the actual on-chain caller:
    //   - The account, for account-driven recovery.
    //   - The runtime, for orchestrator-driven recovery.
    //
    // Off-chain consumers can use this field to reconstruct which path
    // executed the request without additional correlation logic.

    this.vm().log(RecoveryExecuted {
        requestId: request_id,
        executedBy: sender,
    });

    Ok(())
}

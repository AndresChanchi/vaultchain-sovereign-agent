//! `dispatch` handler — the main orchestration entrypoint.
//!
//! # Atomicity
//!
//! Everything in this function runs in a single transaction. If any
//! step reverts, the entire dispatch reverts — including any state
//! changes made by the target module, and any settlement credit
//! already recorded in Economics. The user either gets a complete
//! execution or none at all.
//!
//! # Fee handling
//!
//! Runtime does not charge fees directly. When the intent carries
//! `settlement_call_data`, Runtime forwards the whole `msg.value()` to
//! Economics, which performs its own pricing, pays the storage
//! provider, applies the protocol fee, and credits any excess to the
//! funder's pull-based refund balance. The target module never sees
//! the value; it just executes the business operation that the settled
//! payment authorized. This keeps Runtime a pure orchestrator and
//! preserves the "single atomic transaction per user action"
//! guarantee.
//!
//! # Reentrancy
//!
//! Stylus SDK 0.10.5+ disables reentrancy at the runtime level. Both
//! the settlement call and the target forward use `RawCall`, which is
//! not reentrant by construction. Runtime does not maintain any state
//! that a reentrant call could observe inconsistently.
//!
//! # Why a tuple
//!
//! The Gateway sends the envelope as a Solidity tuple
//! `(address, address, uint256, bytes)`. The `#[public]` macro cannot
//! synthesize the `AbiType` bound for a `sol!` struct parameter, so the
//! parameter is expressed as a Rust tuple that implements the required
//! traits directly. The generated selector matches the Gateway's call
//! byte-for-byte.

use alloc::vec::Vec;

use kipio_account_bridge::{
    authorization_can_be_accepted_full_impl, authorization_is_structurally_valid_impl,
    AuthorizationAbi, IdentityAbi,
};
use stylus_sdk::{
    abi::Bytes,
    alloy_primitives::{Address, U256},
    alloy_sol_types::{SolError, SolValue},
    call::RawCall,
    prelude::*,
};

use crate::abi::errors::{
    AuthorizationDenied, EmptyPayload, IntentDecodeFailed, InvalidEnvelope, TargetCallFailed,
};
use crate::abi::events::ExecutionDispatched;
use crate::abi::types::Intent;
use crate::storage::entrypoint::KipioRuntime;

pub(crate) fn handle_dispatch(
    this: &mut KipioRuntime,
    envelope: (Address, Address, U256, Bytes),
) -> Result<Vec<u8>, Vec<u8>> {
    let (caller, execution_account, _value, payload) = envelope;

    // --- 1. Validate envelope ---
    if caller == Address::ZERO || execution_account == Address::ZERO {
        return Err(InvalidEnvelope {}.abi_encode());
    }
    if payload.is_empty() {
        return Err(EmptyPayload {}.abi_encode());
    }

    // --- 2. Decode intent ---
    let intent = Intent::abi_decode(&payload).map_err(|_| IntentDecodeFailed {}.abi_encode())?;

    // --- 3. Read account state ---
    let state = this.read_account_state_raw(execution_account)?;

    // --- 4. Dafny authorization pipeline ---
    let account = this.build_account_abi(execution_account, state);

    let auth = AuthorizationAbi::abi_decode(&intent.authorization_abi)
        .map_err(|_| IntentDecodeFailed {}.abi_encode())?;

    let identities = Vec::<IdentityAbi>::abi_decode(&intent.identities_abi)
        .map_err(|_| IntentDecodeFailed {}.abi_encode())?;

    if !authorization_is_structurally_valid_impl(&auth) {
        return Err(AuthorizationDenied {}.abi_encode());
    }

    let now = U256::from(this.vm().block_timestamp());
    if !authorization_can_be_accepted_full_impl(
        &auth,
        &account,
        &identities,
        now,
        intent.proof_verified,
    ) {
        return Err(AuthorizationDenied {}.abi_encode());
    }

    // --- 5. Settlement (atomic fee gate, optional) ---
    //
    // When the intent carries settlement calldata, forward the entire
    // `msg.value()` to Economics BEFORE the target module. The
    // settlement call is expected to resolve the funder, pay the
    // storage provider, apply the protocol fee, and credit any excess
    // to the funder's pull-based refund balance.
    //
    // If the settlement reverts (no value, no credit, no sponsor,
    // quote mismatch), the entire dispatch reverts atomically and the
    // target module never runs. The user cannot accidentally execute a
    // business operation without first satisfying its economic
    // obligation.
    //
    // When the intent does NOT carry settlement calldata, Runtime skips
    // this step and forwards `msg.value()` to the target module
    // unchanged. This is the path for operations that do not incur a
    // protocol fee.
    //
    // `value_remaining` is what gets forwarded to the target: zero when
    // settlement ran (Economics consumes the whole amount), or the
    // original `msg.value()` when it did not.
    let value_remaining = this.maybe_settle(caller, &intent.settlement_call_data)?;

    // --- 6. Resolve target module ---
    let target = this.resolve_target(intent.target_module, execution_account)?;

    // --- 7. Append EIP-2771 suffix for forwarded-capable modules ---
    //
    // The suffix is the effective user (20 bytes). Modules that declare
    // Model B + EIP-2771 strip this suffix and use it as the caller's
    // authority. Modules that do not support forwarding receive the raw
    // calldata.
    let calldata = if KipioRuntime::module_supports_eip2771(intent.target_module) {
        KipioRuntime::append_eip2771_suffix(&intent.target_call_data, caller)
    } else {
        intent.target_call_data.to_vec()
    };

    // --- 8. Forward call ---
    this.vm().log(ExecutionDispatched {
        caller,
        executionAccount: execution_account,
        targetModule: intent.target_module,
        target,
        authorized: true,
    });

    let result = unsafe {
        RawCall::new_with_value(this.vm(), value_remaining).call(target, &calldata)
    };

    result.map_err(|_| TargetCallFailed {}.abi_encode())
}

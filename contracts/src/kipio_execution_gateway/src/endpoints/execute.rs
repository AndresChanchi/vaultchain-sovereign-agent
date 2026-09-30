//! `execute` handler — the single user-facing entrypoint.

use alloc::vec::Vec;

use stylus_sdk::{
    abi::Bytes,
    alloy_primitives::Address,
    alloy_sol_types::SolError,
    prelude::*,
};

use super::views;
use crate::abi::errors::{InvalidExecutionContext, InvalidGatewayPayload};
use crate::abi::events::{ExecutionForwarded, GatewayInvoked};
use crate::config::constants::KIPIO_RUNTIME;
use crate::internal::helpers::encode_dispatch_error;
use crate::kipio_shared::IKipioRuntime;
use crate::storage::entrypoint::KipioExecutionGateway;

pub(crate) fn handle_execute(
    this: &mut KipioExecutionGateway,
    payload: Bytes,
) -> Result<Vec<u8>, Vec<u8>> {
    // --- 1. Adapter ---
    if payload.is_empty() {
        return Err(InvalidGatewayPayload {}.abi_encode());
    }

    let caller = this.vm().msg_sender();
    let execution_account = this.vm().contract_address();
    let value = this.vm().msg_value();

    if execution_account == Address::ZERO {
        return Err(InvalidExecutionContext {
            executionAccount: execution_account,
        }
        .abi_encode());
    }

    let intent_hash = alloy_primitives::keccak256(&payload);
    this.vm().log(GatewayInvoked {
        caller,
        executionAccount: execution_account,
        intentHash: intent_hash,
    });

    // --- 2. Discovery ---
    let salt = views::salt_for(caller);
    let target_account = this.predict_from_salt(salt);

    // --- 3. Bootstrap (idempotent) ---
    let mut available_value = value;
    this.bootstrap_sovereign_account(
        target_account,
        salt,
        caller,
        &mut available_value,
    )?;

    // --- 4. Dispatch ---
    let envelope = (caller, execution_account, available_value, payload);

    let runtime = IKipioRuntime::new(KIPIO_RUNTIME);
    let call_config = Call::new_payable(this, available_value);

    let result = runtime.dispatch(this.vm(), call_config, envelope);

    match result {
        Ok(return_data) => {
            this.vm().log(ExecutionForwarded {
                account: target_account,
                runtime: KIPIO_RUNTIME,
                valueForwarded: available_value,
            });
            Ok(return_data.into())
        }
        Err(stylus_err) => Err(encode_dispatch_error(stylus_err)),
    }
}

//! Read-only views of the runtime.

use alloc::vec::Vec;

use stylus_sdk::{alloy_primitives::Address, alloy_sol_types::SolError};

use crate::abi::errors::UnknownModule;
use crate::config::constants::MODULE_EXECUTION_ACCOUNT;
use crate::storage::entrypoint::KipioRuntime;

pub(crate) fn handle_ping(_this: &KipioRuntime) -> bool {
    true
}

pub(crate) fn handle_get_protocol_config(this: &KipioRuntime) -> Address {
    this.protocol_config.get()
}

/// Resolves a module address through the protocol config.
///
/// For `MODULE_EXECUTION_ACCOUNT` this reverts, because the account
/// address is per-identity and must be passed through the envelope.
/// Callers that want to resolve an account address should use the
/// Execution Gateway's `predictAccount(identity)` view.
pub(crate) fn handle_get_module_address(
    this: &KipioRuntime,
    module_id: u8,
) -> Result<Address, Vec<u8>> {
    if module_id == MODULE_EXECUTION_ACCOUNT {
        return Err(UnknownModule { moduleId: module_id }.abi_encode());
    }
    this.resolve_module(module_id)
}

//! Views with non-trivial logic.

use alloc::vec::Vec;

use stylus_sdk::{alloy_primitives::Address, alloy_sol_types::SolError};

use crate::abi::errors::UnknownModule;
use crate::config::constants::{
    MODULE_ECONOMICS, MODULE_EXECUTION_GATEWAY, MODULE_IDENTITY_CONTENT, MODULE_RECOVERY,
    MODULE_RUNTIME,
};
use crate::storage::entrypoint::KipioProtocolConfig;

/// Generic module resolver keyed by `MODULE_*` identifier.
///
/// Reverts with `UnknownModule` when the id is not recognized. When the
/// id is recognized but the address has not been registered yet, this
/// returns `Address::ZERO`; the caller is responsible for the zero check.
pub(crate) fn get_module_address(
    this: &KipioProtocolConfig,
    module_id: u8,
) -> Result<Address, Vec<u8>> {
    match module_id {
        MODULE_RUNTIME => Ok(this.runtime_address.get()),
        MODULE_ECONOMICS => Ok(this.economics_address.get()),
        MODULE_IDENTITY_CONTENT => Ok(this.identity_content_address.get()),
        MODULE_RECOVERY => Ok(this.recovery_address.get()),
        MODULE_EXECUTION_GATEWAY => Ok(this.execution_gateway_address.get()),
        _ => Err(UnknownModule { moduleId: module_id }.abi_encode()),
    }
}

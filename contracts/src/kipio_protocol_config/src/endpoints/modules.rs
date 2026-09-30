//! Module registry setters.
//!
//! Each setter updates exactly one slot. Consumers resolve the new
//! address on their next call. Existing module instances keep running but
//! stop being reachable through the registry, which is the intended
//! "soft deprecation" path for a module upgrade.

use alloc::vec::Vec;

use stylus_sdk::alloy_primitives::Address;

use crate::config::constants::{
    MODULE_ECONOMICS, MODULE_EXECUTION_GATEWAY, MODULE_IDENTITY_CONTENT, MODULE_RECOVERY,
    MODULE_RUNTIME,
};
use crate::storage::entrypoint::KipioProtocolConfig;

pub(crate) fn handle_set_runtime_address(
    this: &mut KipioProtocolConfig,
    addr: Address,
) -> Result<(), Vec<u8>> {
    this.set_module_address(MODULE_RUNTIME, addr)
}

pub(crate) fn handle_set_economics_address(
    this: &mut KipioProtocolConfig,
    addr: Address,
) -> Result<(), Vec<u8>> {
    this.set_module_address(MODULE_ECONOMICS, addr)
}

pub(crate) fn handle_set_identity_content_address(
    this: &mut KipioProtocolConfig,
    addr: Address,
) -> Result<(), Vec<u8>> {
    this.set_module_address(MODULE_IDENTITY_CONTENT, addr)
}

pub(crate) fn handle_set_recovery_address(
    this: &mut KipioProtocolConfig,
    addr: Address,
) -> Result<(), Vec<u8>> {
    this.set_module_address(MODULE_RECOVERY, addr)
}

pub(crate) fn handle_set_execution_gateway_address(
    this: &mut KipioProtocolConfig,
    addr: Address,
) -> Result<(), Vec<u8>> {
    this.set_module_address(MODULE_EXECUTION_GATEWAY, addr)
}

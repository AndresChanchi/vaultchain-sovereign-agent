//! Privilege gates and shared mutation helpers.

use alloc::vec::Vec;

use stylus_sdk::{
    alloy_primitives::Address,
    alloy_sol_types::SolError,
    prelude::*,
};

use crate::abi::errors::{
    PausedError, Unauthorized, UnknownModule, ZeroAddress, ZeroOwner,
};
use crate::abi::events::ModuleAddressUpdated;
use crate::config::constants::{
    MODULE_ECONOMICS, MODULE_EXECUTION_GATEWAY, MODULE_IDENTITY_CONTENT, MODULE_RECOVERY,
    MODULE_RUNTIME,
};
use crate::storage::entrypoint::KipioProtocolConfig;

impl KipioProtocolConfig {
    /// Owner gate. Reverts with `Unauthorized` when the caller is not
    /// the current owner, and with `ZeroOwner` when the owner has
    /// somehow been cleared (defensive; should not happen after
    /// construction).
    pub(crate) fn require_owner(&self) -> Result<(), Vec<u8>> {
        let owner = self.owner.get();
        if owner == Address::ZERO {
            return Err(ZeroOwner {}.abi_encode());
        }
        if self.vm().msg_sender() != owner {
            return Err(Unauthorized {}.abi_encode());
        }
        Ok(())
    }

    /// Circuit-breaker gate. Reverts with `PausedError` when the
    /// registry is paused.
    pub(crate) fn require_not_paused(&self) -> Result<(), Vec<u8>> {
        if self.paused.get() {
            return Err(PausedError {}.abi_encode());
        }
        Ok(())
    }

    /// Shared body for every module-address setter.
    ///
    /// Validates ownership and pause state, then updates exactly one
    /// slot based on the module id and emits the `ModuleAddressUpdated`
    /// event with the previous and new values. Keeping the switch in one
    /// place guarantees that all five setters stay consistent in their
    /// validation and observability.
    pub(crate) fn set_module_address(
        &mut self,
        module_id: u8,
        addr: Address,
    ) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        self.require_not_paused()?;

        if addr == Address::ZERO {
            return Err(ZeroAddress {}.abi_encode());
        }

        let old = match module_id {
            MODULE_RUNTIME => {
                let prev = self.runtime_address.get();
                self.runtime_address.set(addr);
                prev
            }
            MODULE_ECONOMICS => {
                let prev = self.economics_address.get();
                self.economics_address.set(addr);
                prev
            }
            MODULE_IDENTITY_CONTENT => {
                let prev = self.identity_content_address.get();
                self.identity_content_address.set(addr);
                prev
            }
            MODULE_RECOVERY => {
                let prev = self.recovery_address.get();
                self.recovery_address.set(addr);
                prev
            }
            MODULE_EXECUTION_GATEWAY => {
                let prev = self.execution_gateway_address.get();
                self.execution_gateway_address.set(addr);
                prev
            }
            _ => return Err(UnknownModule { moduleId: module_id }.abi_encode()),
        };

        self.vm().log(ModuleAddressUpdated {
            moduleId: module_id,
            oldAddress: old,
            newAddress: addr,
        });
        Ok(())
    }
}

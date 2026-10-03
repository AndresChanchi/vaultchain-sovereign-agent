//! Module routing, settlement forwarding, and EIP-2771 helpers.

use alloc::vec::Vec;

use stylus_sdk::{
    abi::Bytes,
    alloy_primitives::{Address, U256},
    alloy_sol_types::SolError,
    call::RawCall,
    prelude::*,
};

use crate::abi::errors::{
    ConfigQueryFailed, InvalidEnvelope, ModuleAddressNotConfigured, ProtocolConfigNotSet,
    SettlementFailed, UnknownModule,
};
use crate::abi::events::SettlementOrchestrated;
use crate::abi::interfaces::IKipioProtocolConfig;
use crate::config::constants::{
    MODULE_ECONOMICS, MODULE_EXECUTION_ACCOUNT, MODULE_IDENTITY_CONTENT, MODULE_RECOVERY,
};
use crate::storage::entrypoint::KipioRuntime;

impl KipioRuntime {
    /// Optional settlement step.
    ///
    /// When `settlement_call_data` is empty, returns the original
    /// `msg.value()` unchanged so that the target module receives the
    /// full value.
    ///
    /// When `settlement_call_data` is non-empty, forwards the entire
    /// `msg.value()` to `kipio_economics` and returns `U256::ZERO`. The
    /// settlement call is expected to handle its own pricing, pay the
    /// storage provider, apply the protocol fee, and credit any excess
    /// to the funder's refund balance.
    ///
    /// On success, emits `SettlementOrchestrated`. On failure, bubbles
    /// up `SettlementFailed` and aborts the whole dispatch.
    pub(crate) fn maybe_settle(
        &mut self,
        caller: Address,
        settlement_call_data: &Bytes,
    ) -> Result<U256, Vec<u8>> {
        let value = self.vm().msg_value();

        if settlement_call_data.is_empty() {
            return Ok(value);
        }

        let economics = self.resolve_module(MODULE_ECONOMICS)?;
        let host = self.vm();

        let result =
            unsafe { RawCall::new_with_value(host, value).call(economics, settlement_call_data) };
        result.map_err(|_| SettlementFailed {}.abi_encode())?;

        self.vm().log(SettlementOrchestrated {
            caller,
            settlementTarget: economics,
            valueForwarded: value,
        });

        // The settlement consumed the whole value. The target module
        // receives zero and executes the business operation that the
        // settled payment authorized.
        Ok(U256::ZERO)
    }

    /// Resolves the target address for a dispatch.
    ///
    /// `MODULE_EXECUTION_ACCOUNT` short-circuits to the execution
    /// account carried in the envelope. Every other module id goes
    /// through the protocol config registry.
    pub(crate) fn resolve_target(
        &self,
        module_id: u8,
        execution_account: Address,
    ) -> Result<Address, Vec<u8>> {
        if module_id == MODULE_EXECUTION_ACCOUNT {
            if execution_account == Address::ZERO {
                return Err(InvalidEnvelope {}.abi_encode());
            }
            return Ok(execution_account);
        }
        self.resolve_module(module_id)
    }

    /// Resolves a singleton module address through the registry.
    ///
    /// Uses per-module getters that mirror the naming convention
    /// established by `kipio_identity_content` (`getRuntimeAddress`).
    /// Adding a new operational module requires adding a new arm here
    /// and a matching getter in `kipio_protocol_config`.
    pub(crate) fn resolve_module(&self, module_id: u8) -> Result<Address, Vec<u8>> {
        let config_addr = self.protocol_config.get();
        if config_addr == Address::ZERO {
            return Err(ProtocolConfigNotSet {}.abi_encode());
        }

        let config = IKipioProtocolConfig::new(config_addr);
        let call = Call::new();

        let target = match module_id {
            MODULE_IDENTITY_CONTENT => config
                .get_identity_content_address(self.vm(), call)
                .map_err(|_| ConfigQueryFailed {}.abi_encode())?,
            MODULE_ECONOMICS => config
                .get_economics_address(self.vm(), call)
                .map_err(|_| ConfigQueryFailed {}.abi_encode())?,
            MODULE_RECOVERY => config
                .get_recovery_address(self.vm(), call)
                .map_err(|_| ConfigQueryFailed {}.abi_encode())?,
            _ => return Err(UnknownModule { moduleId: module_id }.abi_encode()),
        };

        if target == Address::ZERO {
            return Err(ModuleAddressNotConfigured { moduleId: module_id }.abi_encode());
        }
        Ok(target)
    }

    /// Whether a module consumes the EIP-2771 suffix.
    ///
    /// Currently only `kipio_identity_content` supports forwarding.
    /// When more modules adopt the pattern, add their ids here.
    #[inline]
    pub(crate) fn module_supports_eip2771(module_id: u8) -> bool {
        module_id == MODULE_IDENTITY_CONTENT
    }

    /// Appends the EIP-2771 suffix (20-byte effective user) to a target
    /// calldata.
    ///
    /// The suffix is the raw 20-byte address, no padding. Target modules
    /// strip it before decoding their arguments.
    #[inline]
    pub(crate) fn append_eip2771_suffix(calldata: &[u8], user: Address) -> Vec<u8> {
        let mut out = Vec::with_capacity(calldata.len() + 20);
        out.extend_from_slice(calldata);
        out.extend_from_slice(user.as_slice());
        out
    }
}

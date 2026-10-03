//! Public entrypoints for the protocol config registry.
//!
//! # Why a single `#[public]` block?
//!
//! The Stylus SDK's `#[public]` macro generates one `Router` trait impl
//! and one `HostAccess` impl per type. Rust forbids more than one impl
//! of the same trait for the same type, so all public endpoints MUST
//! live in a single `#[public] impl KipioProtocolConfig` block.
//!
//! To keep the code readable despite this constraint, this module holds
//! the `#[public]` block with thin delegators, and the actual logic
//! lives in sibling modules as `pub(crate) fn handle_*`. The delegators
//! carry the exact same signatures as the pre-split endpoints, so the
//! ABI is unchanged.

use alloc::vec::Vec;

use stylus_sdk::{
    alloy_primitives::{Address, B256, U256},
    prelude::*,
};

use crate::storage::entrypoint::KipioProtocolConfig;

mod constructor;
mod crypto_agility;
mod governance;
mod ledgers;
mod modules;
mod views;

#[public]
impl KipioProtocolConfig {
    // ========================================================================
    // CONSTRUCTOR
    // ========================================================================

    /// Sets the initial owner of the registry.
    ///
    /// Uses `tx_origin` (not `msg_sender`) because the Stylus deployer is
    /// an intermediate contract in the deployment pipeline. The
    /// `tx_origin` is the EOA that signed the deployment transaction,
    /// which is the protocol maintainer.
    #[constructor]
    pub fn constructor(&mut self) -> Result<(), Vec<u8>> {
        constructor::handle_constructor(self)
    }

    // ========================================================================
    // GOVERNANCE — OWNERSHIP
    // ========================================================================

    /// Nominates a new owner for the two-step ownership transfer.
    pub fn transfer_ownership(&mut self, new_owner: Address) -> Result<(), Vec<u8>> {
        governance::handle_transfer_ownership(self, new_owner)
    }

    /// Completes the two-step ownership transfer.
    pub fn accept_ownership(&mut self) -> Result<(), Vec<u8>> {
        governance::handle_accept_ownership(self)
    }

    // ========================================================================
    // GOVERNANCE — CIRCUIT BREAKER
    // ========================================================================

    /// Pauses the registry. See `endpoints::governance` for the rationale.
    pub fn pause(&mut self, reason_hash: B256) -> Result<(), Vec<u8>> {
        governance::handle_pause(self, reason_hash)
    }

    /// Lifts the circuit breaker.
    pub fn unpause(&mut self) -> Result<(), Vec<u8>> {
        governance::handle_unpause(self)
    }

    // ========================================================================
    // MODULE REGISTRY — SETTERS
    // ========================================================================

    pub fn set_runtime_address(&mut self, addr: Address) -> Result<(), Vec<u8>> {
        modules::handle_set_runtime_address(self, addr)
    }

    pub fn set_economics_address(&mut self, addr: Address) -> Result<(), Vec<u8>> {
        modules::handle_set_economics_address(self, addr)
    }

    pub fn set_identity_content_address(&mut self, addr: Address) -> Result<(), Vec<u8>> {
        modules::handle_set_identity_content_address(self, addr)
    }

    pub fn set_recovery_address(&mut self, addr: Address) -> Result<(), Vec<u8>> {
        modules::handle_set_recovery_address(self, addr)
    }

    pub fn set_execution_gateway_address(&mut self, addr: Address) -> Result<(), Vec<u8>> {
        modules::handle_set_execution_gateway_address(self, addr)
    }

    // ========================================================================
    // CRYPTO-AGILITY REGISTRY
    // ========================================================================

    pub fn set_verifier(
        &mut self,
        curve_id: U256,
        verifier_address: Address,
    ) -> Result<(), Vec<u8>> {
        crypto_agility::handle_set_verifier(self, curve_id, verifier_address)
    }

    pub fn set_curve_status(
        &mut self,
        curve_id: U256,
        status: U256,
    ) -> Result<(), Vec<u8>> {
        crypto_agility::handle_set_curve_status(self, curve_id, status)
    }

    // ========================================================================
    // POLICY LEDGER WHITELIST
    // ========================================================================

    pub fn set_authorized_ledger(
        &mut self,
        ledger: Address,
        authorized: bool,
    ) -> Result<(), Vec<u8>> {
        ledgers::handle_set_authorized_ledger(self, ledger, authorized)
    }

    // ========================================================================
    // VIEWS
    // ========================================================================

    pub fn get_owner(&self) -> Address {
        self.owner.get()
    }

    pub fn get_pending_owner(&self) -> Address {
        self.pending_owner.get()
    }

    pub fn is_paused(&self) -> bool {
        self.paused.get()
    }

    pub fn get_pause_reason(&self) -> B256 {
        self.pause_reason_hash.get()
    }

    pub fn get_runtime_address(&self) -> Address {
        self.runtime_address.get()
    }

    pub fn get_economics_address(&self) -> Address {
        self.economics_address.get()
    }

    pub fn get_identity_content_address(&self) -> Address {
        self.identity_content_address.get()
    }

    pub fn get_recovery_address(&self) -> Address {
        self.recovery_address.get()
    }

    pub fn get_execution_gateway_address(&self) -> Address {
        self.execution_gateway_address.get()
    }

    /// Generic module resolver keyed by `MODULE_*` identifier.
    ///
    /// Convenience for off-chain tooling and for consumers that iterate
    /// the registry generically. Reverts with `UnknownModule` when the
    /// id is not recognized. When the id is recognized but the address
    /// has not been registered yet, this returns `Address::ZERO`; the
    /// caller is responsible for the zero check.
    pub fn get_module_address(&self, module_id: u8) -> Result<Address, Vec<u8>> {
        views::get_module_address(self, module_id)
    }

    pub fn get_verifier(&self, curve_id: U256) -> Address {
        self.verifiers.getter(curve_id).get()
    }

    pub fn get_curve_status(&self, curve_id: U256) -> U256 {
        self.curve_statuses.getter(curve_id).get()
    }

    pub fn is_authorized_ledger(&self, ledger: Address) -> bool {
        self.authorized_ledgers.getter(ledger).get()
    }
}

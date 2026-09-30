//! Public entrypoints for the runtime.
//!
//! # Why a single `#[public]` block?
//!
//! The Stylus SDK's `#[public]` macro generates one `Router` trait impl
//! and one `HostAccess` impl per type. Rust forbids more than one impl
//! of the same trait for the same type, so all public endpoints MUST
//! live in a single `#[public] impl KipioRuntime` block.
//!
//! To keep the code readable despite this constraint, this module holds
//! the `#[public]` block with thin delegators, and the actual logic
//! lives in sibling modules as `pub(crate) fn handle_*`. The delegators
//! carry the exact same signatures as the pre-split endpoints, so the
//! ABI is unchanged.

use alloc::vec::Vec;

use kipio_account_bridge::{
    AuthorizationAbi, AuthorizationStateAbi, CapabilityAbi, ExecutionContextAbi, IdentityAbi,
    PolicyConsumptionAbi,
};
use stylus_sdk::{
    abi::Bytes,
    alloy_primitives::{Address, U256},
    prelude::*,
};

use crate::storage::entrypoint::KipioRuntime;

mod constructor;
mod dispatch;
mod validators;
mod views;

#[public]
impl KipioRuntime {
    // ========================================================================
    // CONSTRUCTOR
    // ========================================================================

    /// Binds the runtime to the protocol configuration registry.
    ///
    /// The runtime is deployed once by the deployer. It needs to know
    /// where the registry lives so it can resolve module addresses
    /// dynamically.
    #[constructor]
    pub fn constructor(&mut self, protocol_config: Address) -> Result<(), Vec<u8>> {
        constructor::handle_constructor(self, protocol_config)
    }

    // ========================================================================
    // DISPATCH — MAIN ORCHESTRATION ENTRYPOINT
    // ========================================================================

    /// Orchestrates a user intent end-to-end.
    ///
    /// See `endpoints::dispatch::handle_dispatch` for the full rationale
    /// on atomicity, fee handling, reentrancy, and the tuple-shaped
    /// envelope.
    #[payable]
    pub fn dispatch(
        &mut self,
        envelope: (Address, Address, U256, Bytes),
    ) -> Result<Vec<u8>, Vec<u8>> {
        dispatch::handle_dispatch(self, envelope)
    }

    // ========================================================================
    // VIEWS
    // ========================================================================

    /// Sanity check.
    pub fn ping(&self) -> bool {
        views::handle_ping(self)
    }

    /// Returns the configured protocol config address.
    pub fn get_protocol_config(&self) -> Address {
        views::handle_get_protocol_config(self)
    }

    /// Resolves a module address through the protocol config.
    pub fn get_module_address(&self, module_id: u8) -> Result<Address, Vec<u8>> {
        views::handle_get_module_address(self, module_id)
    }

    // ========================================================================
    // CROSS-CONTRACT STATE READS
    // ========================================================================

    /// Reads the AuthorizationState from a deployed Account contract.
    pub fn read_account_state(
        &self,
        account_addr: Address,
    ) -> Result<AuthorizationStateAbi, Vec<u8>> {
        validators::handle_read_account_state(self, account_addr)
    }

    // ========================================================================
    // AUTHORIZATION VALIDATION
    // ========================================================================

    /// Structural validity of an Authorization (gate before acceptance).
    pub fn authorization_is_structurally_valid(&self, auth: AuthorizationAbi) -> bool {
        validators::handle_authorization_is_structurally_valid(auth)
    }

    /// Full authorization acceptance with provenance.
    pub fn authorization_can_be_accepted_full(
        &self,
        account_addr: Address,
        auth: AuthorizationAbi,
        identities: Vec<IdentityAbi>,
        now: U256,
        proof_verified: bool,
    ) -> Result<bool, Vec<u8>> {
        validators::handle_authorization_can_be_accepted_full(
            self,
            account_addr,
            auth,
            identities,
            now,
            proof_verified,
        )
    }

    // ========================================================================
    // EFFECTIVE AUTHORITY
    // ========================================================================

    /// Computes the canonical EffectiveAuthority for an Account.
    pub fn compute_effective_authority(
        &self,
        account_addr: Address,
        identities: Vec<IdentityAbi>,
        now: U256,
    ) -> Result<Vec<CapabilityAbi>, Vec<u8>> {
        validators::handle_compute_effective_authority(self, account_addr, identities, now)
    }

    // ========================================================================
    // POLICY CONSUMPTION
    // ========================================================================

    /// Applies a PolicyConsumption to an Account via cross-contract call.
    pub fn apply_policy_consumption(
        &self,
        account_addr: Address,
        consumption: PolicyConsumptionAbi,
    ) -> Result<bool, Vec<u8>> {
        validators::handle_apply_policy_consumption(self, account_addr, consumption)
    }

    // ========================================================================
    // EXECUTION BOUNDARY
    // ========================================================================

    /// Validates a complete ExecutionContext against a deployed Account.
    pub fn valid_execution_context(
        &self,
        account_addr: Address,
        context: ExecutionContextAbi,
        identities: Vec<IdentityAbi>,
        proof_verified: bool,
    ) -> Result<bool, Vec<u8>> {
        validators::handle_valid_execution_context(
            self,
            account_addr,
            context,
            identities,
            proof_verified,
        )
    }
}

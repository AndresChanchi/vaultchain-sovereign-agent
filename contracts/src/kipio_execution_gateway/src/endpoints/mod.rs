//! Public entrypoints for the Gateway.
//!
//! # Why a single `#[public]` block?
//!
//! The Stylus SDK's `#[public]` macro generates one `Router` trait impl and
//! one `HostAccess` impl per type. Rust forbids more than one impl of the
//! same trait for the same type, so all public endpoints MUST live in a
//! single `#[public] impl KipioExecutionGateway` block.
//!
//! To keep the code readable despite this constraint, this module holds the
//! `#[public]` block with thin delegators, and the actual logic lives in
//! sibling modules as `pub(crate) fn handle_*`. The delegators carry the
//! exact same signatures as the pre-split endpoints, so the ABI is
//! unchanged.

use alloc::vec::Vec;

use stylus_sdk::{
    abi::Bytes,
    alloy_primitives::{Address, B256},
    prelude::*,
};

use crate::storage::entrypoint::KipioExecutionGateway;

mod constructor;
mod execute;
mod self_deploy;
pub(crate) mod views;

#[public]
impl KipioExecutionGateway {
    // =======================================================================
    // CONSTRUCTOR
    // =======================================================================

    /// Records the Gateway's own address and the salt scheme version.
    ///
    /// The constructor takes no arguments. All protocol addresses are
    /// compile-time constants that point to on-chain proxies.
    #[constructor]
    pub fn constructor(&mut self) -> Result<(), Vec<u8>> {
        constructor::handle_constructor(self)
    }

    // =======================================================================
    // EXECUTE — the single user-facing entrypoint
    // =======================================================================

    /// Executes a user intent through the Kipio protocol.
    ///
    /// Flow: resolve the caller's sovereign account, bootstrap it if
    /// needed, and forward the original payload to Runtime.
    ///
    /// # Identity model
    ///
    /// The sovereign identity is `msg_sender()` — the originator of the
    /// intent. Under EIP-7702 this is the EOA (or the relayer that
    /// represents it). Under a direct call, it is the caller.
    ///
    /// `contract_address()` is the *execution account*: the EOA that runs
    /// the delegated code under EIP-7702, or the Gateway itself under a
    /// direct call.
    ///
    /// # Value forwarding
    ///
    /// The value forwarded to Runtime is `available_value`, the original
    /// `msg.value` minus any ETH consumed during account activation. The
    /// envelope carries the same `available_value` so Runtime observes a
    /// consistent view.
    #[payable]
    pub fn execute(&mut self, payload: Bytes) -> Result<Vec<u8>, Vec<u8>> {
        execute::handle_execute(self, payload)
    }

    // =======================================================================
    // SELF-DEPLOY — internal entrypoint for EIP-7702 contexts
    // =======================================================================

    /// Deploys an account with the Gateway as the `CREATE2` deployer.
    ///
    /// Only useful under EIP-7702, where the outer frame runs with the EOA
    /// as `address(this)`. The self-call forces the deployer to be the
    /// Gateway, guaranteeing deterministic addresses that match
    /// direct-call deployments.
    ///
    /// # Security
    ///
    /// Permissionless by design. The deployment is deterministic by salt,
    /// and the account constructor validates identity, runtime, and
    /// recovery addresses. Anyone can deploy an account for any identity,
    /// but the resulting account is always correctly bound.
    pub fn self_deploy(&mut self, salt: B256) -> Result<Address, Vec<u8>> {
        self_deploy::handle_self_deploy(self, salt)
    }

    // =======================================================================
    // RECEIVE — accepts ETH from pull-based refunds
    // =======================================================================
    //
    // Economics sends ETH via `RawCall` with empty calldata. Without a
    // `#[receive]` handler, the entrypoint reverts on empty calldata and
    // the `withdrawRefund` call fails. The handler does not mutate state:
    // the ETH remains in the Gateway's balance (or the EOA's balance under
    // EIP-7702) and is used for account activation.

    /// Accepts an ETH transfer with empty calldata.
    #[receive]
    fn receive(&mut self) -> Result<(), Vec<u8>> {
        Ok(())
    }

    // =======================================================================
    // PUBLIC VIEWS
    // =======================================================================

    /// Returns the `CREATE2` salt for a given identity.
    ///
    /// The salt is `version || 12 zero bytes || identity`. The left-aligned
    /// version byte allows future scheme migrations without colliding with
    /// existing accounts.
    pub fn salt_for(identity: Address) -> B256 {
        views::salt_for(identity)
    }

    /// Predicts the sovereign account address for an identity.
    pub fn predict_account(&self, identity: Address) -> Address {
        views::predict_account(self, identity)
    }

    /// Returns the protocol addresses this Gateway is bound to.
    pub fn protocol_addresses(&self) -> (Address, Address, Address, u8) {
        views::protocol_addresses()
    }
}

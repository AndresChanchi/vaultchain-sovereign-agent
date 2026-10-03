//! Root storage struct for the protocol config registry.
//!
//! # Multidimensional gas — storage design
//!
//!   - Governance metadata: 1 slot each. Immutable in practice; written
//!     only during ownership transitions.
//!   - Module registry: 1 slot per module. Written rarely; read on every
//!     dispatch through the consumers.
//!   - Crypto-agility matrix: sparse maps. Only populated for curves the
//!     protocol actually supports. Empty slots cost nothing.
//!   - Ledger whitelist: sparse. Only authorized ledgers pay storage.
//!
//! No byte packing is used for the module addresses because each is
//! already a full 20-byte value stored in its own 32-byte slot. Packing
//! would not save gas (the slot is charged regardless) and would
//! complicate reads.

use stylus_sdk::prelude::*;
use stylus_sdk::{
    alloy_primitives::{Address, U256},
    storage::{StorageAddress, StorageB256, StorageBool, StorageMap, StorageU256},
};

#[storage]
#[entrypoint]
pub struct KipioProtocolConfig {
    // ========================================================================
    // GOVERNANCE
    // ========================================================================

    /// @notice Address of the current administrator (deployer, then a
    ///         multisig, then a timelock, then the DAO).
    pub(crate) owner: StorageAddress,

    /// @notice Pending owner during the two-step ownership migration.
    pub(crate) pending_owner: StorageAddress,

    /// @notice Circuit breaker for the registry. When paused, every
    ///         mutating endpoint except ownership transfer reverts.
    ///
    ///         Rationale: during an incident, governance may want to
    ///         freeze the registry to prevent address changes while the
    ///         team investigates. Ownership transfer stays available so
    ///         that an emergency handover is still possible.
    pub(crate) paused: StorageBool,

    /// @notice Free-form reason hash for the current pause. Cleared on
    ///         unpause. Consumed by off-chain indexers.
    pub(crate) pause_reason_hash: StorageB256,

    // ========================================================================
    // MODULE REGISTRY
    // ========================================================================
    //
    // One slot per operational module. Every consumer resolves its peers
    // through these getters, so updating one slot is enough to upgrade a
    // module without redeploying anyone else.

    pub(crate) runtime_address: StorageAddress,
    pub(crate) economics_address: StorageAddress,
    pub(crate) identity_content_address: StorageAddress,
    pub(crate) recovery_address: StorageAddress,
    pub(crate) execution_gateway_address: StorageAddress,

    // ========================================================================
    // CRYPTO-AGILITY REGISTRY
    // ========================================================================

    /// @notice Maps a curve identifier to its dedicated verifier.
    ///
    /// `kipio_identity_content` reads this on every signature-related
    /// operation. Adding support for a new curve only requires calling
    /// `set_verifier` with the new verifier address; no consumer
    /// redeployment is needed.
    pub(crate) verifiers: StorageMap<U256, StorageAddress>,

    /// @notice Maps a curve identifier to its lifecycle status.
    ///
    /// Values are one of the `STATUS_*` constants. The map is sparse;
    /// curves that were never registered resolve to `0` (DISABLED).
    pub(crate) curve_statuses: StorageMap<U256, StorageU256>,

    // ========================================================================
    // POLICY LEDGER WHITELIST
    // ========================================================================

    /// @notice Ledgers authorized to dispatch policy-driven state
    ///         mutations on the rest of the protocol.
    ///
    /// `kipio_identity_content` reads this during `rotateKeyFromPolicy`.
    /// Recovery is the canonical ledger today; future policy engines are
    /// added by whitelisting their addresses.
    pub(crate) authorized_ledgers: StorageMap<Address, StorageBool>,
}

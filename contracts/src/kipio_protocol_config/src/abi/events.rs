//! Events emitted by the protocol config registry.
//!
//! Every mutation of a registry slot emits an indexed event so that
//! off-chain indexers can reconstruct the exact history of module
//! upgrades, curve registrations, and ledger authorizations without
//! reading storage.

use stylus_sdk::alloy_sol_types::sol;

sol! {
    // --- OWNERSHIP ---

    event OwnershipTransferStarted(
        address indexed currentOwner,
        address indexed pendingOwner
    );
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    // --- MODULE REGISTRY ---

    /// @notice Emitted when a module address in the registry changes.
    ///
    /// `moduleId` is one of the `MODULE_*` constants. `oldAddress` is
    /// the previous value (may be `Address::ZERO` for a first-time
    /// registration). `newAddress` is the value that is now resolved by
    /// every consumer.
    event ModuleAddressUpdated(
        uint8 indexed moduleId,
        address indexed oldAddress,
        address indexed newAddress
    );

    // --- CRYPTO-AGILITY ---

    event VerifierUpdated(uint256 indexed curveId, address indexed verifier);
    event CurveStatusUpdated(uint256 indexed curveId, uint256 status);

    // --- LEDGER WHITELIST ---

    event LedgerAuthorizationUpdated(address indexed ledger, bool authorized);

    // --- CIRCUIT BREAKER ---

    event Paused(address indexed by, bytes32 reasonHash);
    event Unpaused(address indexed by);
}

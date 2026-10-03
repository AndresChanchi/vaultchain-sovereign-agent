//! Events emitted by the Gateway.
//!
//! Every step of the bootstrap and dispatch pipeline emits an indexed
//! event so off-chain indexers can reconstruct the lifecycle of an
//! account without reading storage.

use stylus_sdk::alloy_sol_types::sol;

sol! {
    event GatewayDeployed(uint8 indexed version);

    event GatewayInvoked(
        address indexed caller,
        address indexed executionAccount,
        bytes32 indexed intentHash
    );

    event ExecutionForwarded(
        address indexed account,
        address indexed runtime,
        uint256 valueForwarded
    );

    event AccountBootstrapped(
        address indexed account,
        address indexed identity,
        bool sponsored,
        uint256 activationSpent
    );

    event BootstrapFunded(
        address indexed identity,
        address indexed sponsor,
        uint256 amount
    );

    event SponsorshipExcessReturned(
        address indexed identity,
        uint256 amount
    );

    event SelfDeployExecuted(
        address indexed account,
        bytes32 indexed salt
    );
}

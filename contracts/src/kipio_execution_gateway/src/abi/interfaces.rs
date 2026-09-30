//! Shared domain boundary between the Gateway and its protocol peers.
//!
//! These types define the ABI contract of the Gateway with Runtime,
//! Economics, the Account lifecycle, and the ArbOS WASM precompile.

use stylus_sdk::alloy_sol_types::sol;
use stylus_sdk::prelude::sol_interface;

sol! {
    /// @notice The execution envelope forwarded to Runtime.
    struct ExecutionEnvelope {
        address caller;
        address execution_account;
        uint256 value;
        bytes payload;
    }
}

sol_interface! {
    /// @notice Economics bootstrap funding. The flow is pull-based:
    ///         `fundBootstrap` credits the Gateway's refund balance in
    ///         Economics; `withdrawRefund` transfers the credited ETH
    ///         to the Gateway. `creditIdentityRefund` credits an
    ///         identity's refund balance with attached ETH.
    interface IKipioBootstrapFunding {
        function fundBootstrap(address identity)
            external
            returns (bool sponsored, uint256 allocated_value);
        function withdrawRefund() external;
        function creditIdentityRefund(address identity, uint256 amount)
            external
            payable;
    }

    /// @notice Runtime orchestrator.
    interface IKipioRuntime {
        function dispatch(
            (address, address, uint256, bytes) envelope
        ) external payable returns (bytes);
    }

    /// @notice Sovereign account lifecycle view.
    interface IKipioAccountLifecycle {
        function is_initialized() external view returns (bool);
    }

    /// @notice ArbOS WASM activation precompile.
    interface IArbWasm {
        function activateProgram(address program) external payable;
        function codehashVersion(bytes32 codehash)
            external
            view
            returns (uint16);
    }
}

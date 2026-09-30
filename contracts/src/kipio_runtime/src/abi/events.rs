//! Events emitted by the runtime.
//!
//! Every dispatch emits at least one indexed event so off-chain indexers
//! can reconstruct the routing decision without reading the intent
//! payload.

use stylus_sdk::alloy_sol_types::sol;

sol! {
    event RuntimeDeployed(address indexed protocolConfig);

    /// @notice Emitted on every successful dispatch.
    ///
    /// `targetModule` is the intent's declared module id.
    /// `target` is the resolved address of the module that received the
    /// forwarded call. Together they let indexers reconstruct the
    /// routing decision without reading the intent payload.
    event ExecutionDispatched(
        address indexed caller,
        address indexed executionAccount,
        uint8 targetModule,
        address target,
        bool authorized
    );

    /// @notice Emitted after a successful settlement step.
    ///
    /// Only fires when the intent carried a non-empty
    /// `settlement_call_data`. The `settlementTarget` is the resolved
    /// address of `kipio_economics`. The value forwarded is recorded so
    /// off-chain consumers can reconstruct the exact fee flow without
    /// reading the settlement calldata.
    event SettlementOrchestrated(
        address indexed caller,
        address indexed settlementTarget,
        uint256 valueForwarded
    );
}

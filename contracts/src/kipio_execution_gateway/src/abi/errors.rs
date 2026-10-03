//! Custom errors returned by the Gateway.
//!
//! All errors are ABI-encoded via `SolError::abi_encode`. Callers branch
//! on the selector to distinguish between failure modes.

use stylus_sdk::alloy_sol_types::sol;

sol! {
    error InvalidGatewayPayload();
    error InvalidExecutionContext(address executionAccount);
    error BootstrapDeploymentFailed();
    error DeploymentAddressMismatch(address expected, address actual);
    error ActivationFailed();
    error InitializationFailed();
    error DispatchFailed();
    error InsufficientValueForActivation(uint256 required, uint256 available);
    error TransferFailed();
}

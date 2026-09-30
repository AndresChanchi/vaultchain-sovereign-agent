//! Custom errors returned by the protocol config registry.

use stylus_sdk::alloy_sol_types::sol;

sol! {
    error Unauthorized();
    error ZeroOwner();
    error ZeroAddress();
    error NoPendingOwner();
    error PausedError();
    error InvalidCurveStatus();
    error UnknownModule(uint8 moduleId);
}

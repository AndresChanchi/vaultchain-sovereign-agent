//! Custom errors returned by the runtime.

use stylus_sdk::alloy_sol_types::sol;

sol! {
    error ProtocolConfigNotSet();
    error InvalidEnvelope();
    error EmptyPayload();
    error IntentDecodeFailed();
    error UnknownModule(uint8 moduleId);
    error ModuleAddressNotConfigured(uint8 moduleId);
    error AuthorizationDenied();
    error AccountStateReadFailed();
    error SettlementFailed();
    error TargetCallFailed();
    error ConfigQueryFailed();
}

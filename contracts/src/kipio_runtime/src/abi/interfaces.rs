//! Cross-contract interfaces consumed by the runtime.

use kipio_account_bridge::{
    AuthorizationStateAbi, CapabilityAbi, CredentialAbi, SessionAbi,
};
use stylus_sdk::prelude::*;

sol_interface! {
    /// @title Kipio Account — external interface consumed by Runtime.
    ///
    /// Runtime reads Account's persisted state via
    /// `get_authorization_state()` and delegates state transitions to
    /// Account's mutating entrypoints.
    interface IKipioAccount {
        function get_identity_id() external view returns (address);
        function get_authorization_state() external view returns (AuthorizationStateAbi);
        function is_initialized() external view returns (bool);
        function get_nonce() external view returns (uint64);
        function valid_account() external view returns (bool);
        function valid_authorization_state() external view returns (bool);

        function register_credential(CredentialAbi credential) external returns (bool);
        function register_session(SessionAbi session) external returns (bool);
        function add_capability(CapabilityAbi capability) external returns (bool);
        function consume_replay_key(bytes replay_key) external returns (bool);
    }

    /// @title Protocol Configuration Registry.
    ///
    /// Runtime reads module addresses from this registry on every
    /// dispatch, so that modules can be upgraded by updating the
    /// registry — without redeploying the runtime. The registry uses
    /// per-module getters (one per operational module) rather than a
    /// generic `getModule(uint8)`, keeping each lookup explicit and
    /// type-safe at the ABI level.
    interface IKipioProtocolConfig {
        function getRuntimeAddress() external view returns (address);
        function getEconomicsAddress() external view returns (address);
        function getIdentityContentAddress() external view returns (address);
        function getRecoveryAddress() external view returns (address);
    }
}

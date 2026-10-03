#![cfg_attr(not(any(test, feature = "export-abi")), no_main)]
extern crate alloc;

use kipio_account_bridge::{
    apply_policy_consumption_impl, authorization_can_be_accepted_full_impl,
    authorization_is_structurally_valid_impl, compute_effective_authority_impl,
    valid_execution_context_impl, AccountAbi, AuthorizationAbi, AuthorizationStateAbi,
    CapabilityAbi, CredentialAbi, ExecutionContextAbi, IdentityAbi, PolicyConsumptionAbi,
    SessionAbi, SubjectAbi,
};
use stylus_sdk::abi::Bytes;
use stylus_sdk::alloy_primitives::{Address, U256};
use stylus_sdk::prelude::*;

sol_interface! {
    /// @title Kipio Account — external interface consumed by Runtime.
    ///
    /// Runtime reads Account's persisted state via `get_authorization_state()`
    /// and delegates state transitions to Account's mutating entrypoints.
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
}

/// @title Kipio Runtime — Distributed Authority & Execution Orchestration
/// @notice Coordinates the evaluation pipeline. Deployed as a singleton,
/// separate from `kipio_account` instances.
///
/// Runtime does NOT own AuthorizationState. It reads Account state via
/// cross-contract calls and runs the Dafny-derived logic locally.
///
/// Per the DDD (§35, §36, §37), Runtime orchestrates:
///   1. Structural validity of the Authorization;
///   2. Full acceptance with provenance;
///   3. Canonical derivation of EffectiveAuthority;
///   4. Application of PolicyConsumption;
///   5. Validation of a complete ExecutionContext.
///
/// The storage struct is intentionally empty: Runtime is a stateless
/// coordinator per DDD §46 ("Operational / Infrastructure Concepts" have
/// no Entity identity). Any future persistent state (module discovery,
/// protocol config, etc.) will be added explicitly when its consuming
/// entrypoint is implemented.
#[storage]
#[entrypoint]
pub struct KipioRuntime {}

#[public]
impl KipioRuntime {
    /// Sanity check.
    pub fn ping(&self) -> bool {
        true
    }

    // ---- Cross-contract state reads --------------------------------------

    /// @notice Reads the AuthorizationState from a deployed Account contract.
    ///
    /// This is the canonical cross-contract entrypoint: Runtime does not
    /// receive AccountAbi as a parameter, it reads it from the Account.
    pub fn read_account_state(
        &self,
        account_addr: Address,
    ) -> Result<AuthorizationStateAbi, Vec<u8>> {
        let account = IKipioAccount::new(account_addr);
        let call = Call::new();
        account
            .get_authorization_state(self.vm(), call)
            .map_err(|_| b"AccountStateReadFailed".to_vec())
    }

    // ---- Authorization validation ----------------------------------------

    /// @notice Structural validity of an Authorization (gate before acceptance).
    pub fn authorization_is_structurally_valid(&self, auth: AuthorizationAbi) -> bool {
        authorization_is_structurally_valid_impl(&auth)
    }

    /// @notice Full authorization acceptance with provenance.
    ///
    /// Reads the Account state cross-contract, then runs the Dafny-derived
    /// acceptance logic locally.
    pub fn authorization_can_be_accepted_full(
        &self,
        account_addr: Address,
        auth: AuthorizationAbi,
        identities: Vec<IdentityAbi>,
        now: U256,
        proof_verified: bool,
    ) -> Result<bool, Vec<u8>> {
        let state = self.read_account_state(account_addr)?;
        let account = self.build_account_abi(account_addr, state);

        Ok(authorization_can_be_accepted_full_impl(
            &auth,
            &account,
            &identities,
            now,
            proof_verified,
        ))
    }

    // ---- Effective Authority ---------------------------------------------

    /// @notice Computes the canonical EffectiveAuthority for an Account.
    pub fn compute_effective_authority(
        &self,
        account_addr: Address,
        identities: Vec<IdentityAbi>,
        now: U256,
    ) -> Result<Vec<CapabilityAbi>, Vec<u8>> {
        let state = self.read_account_state(account_addr)?;
        let account = self.build_account_abi(account_addr, state);

        Ok(compute_effective_authority_impl(
            &account,
            &identities,
            now,
        ))
    }

    // ---- Policy consumption ----------------------------------------------

    /// @notice Applies a PolicyConsumption to an Account via cross-contract call.
    pub fn apply_policy_consumption(
        &self,
        account_addr: Address,
        consumption: PolicyConsumptionAbi,
    ) -> Result<bool, Vec<u8>> {
        let state = self.read_account_state(account_addr)?;
        let account = self.build_account_abi(account_addr, state);

        let (_, applied) = apply_policy_consumption_impl(&account, &consumption);
        // Note: the actual state persistence happens inside Account's
        // mutating entrypoints. This entrypoint only evaluates applicability.
        Ok(applied)
    }

    // ---- Execution boundary ----------------------------------------------

    /// @notice Validates a complete ExecutionContext against a deployed Account.
    pub fn valid_execution_context(
        &self,
        account_addr: Address,
        context: ExecutionContextAbi,
        identities: Vec<IdentityAbi>,
        proof_verified: bool,
    ) -> Result<bool, Vec<u8>> {
        let state = self.read_account_state(account_addr)?;
        let account = self.build_account_abi(account_addr, state);

        Ok(valid_execution_context_impl(
            &context,
            &account,
            &identities,
            proof_verified,
        ))
    }
}

// ============================================================================
// INTERNAL HELPERS
// ============================================================================

impl KipioRuntime {
    /// @dev Builds an AccountAbi from a cross-contract read.
    fn build_account_abi(
        &self,
        account_addr: Address,
        state: AuthorizationStateAbi,
    ) -> AccountAbi {
        let id_bytes = Bytes::from(account_addr.to_vec());
        AccountAbi {
            id: id_bytes.clone(),
            identity: IdentityAbi {
                id: id_bytes.clone(),
                subject: SubjectAbi {
                    reference: id_bytes,
                },
            },
            authorizationState: state,
        }
    }
}

//! Public entrypoints for `kipio_account`.
//!
//! # Why a single `#[public]` block?
//!
//! The Stylus SDK's `#[public]` macro generates one `Router` trait impl
//! and one `HostAccess` impl per type. Rust forbids more than one impl of
//! the same trait for the same type, so all public endpoints MUST live in
//! a single `#[public] impl KipioAccount` block.
//!
//! To keep the code readable despite this constraint, this module holds
//! the `#[public]` block with thin delegators, and the actual logic lives
//! in sibling modules as `pub(crate) fn handle_*`. The delegators carry
//! the exact same signatures as the pre-split endpoints, so the ABI is
//! unchanged.

use alloc::vec::Vec;

use kipio_account_bridge::{
    AuthorizationStateAbi, CapabilityAbi, CredentialAbi, DelegationAbi, IdentityAbi,
    OptionalScopeAbi, RecoveryEffect, RestrictionAbi, SessionAbi,
};
use stylus_sdk::{
    abi::Bytes,
    alloy_primitives::{Address, B256, U64},
    prelude::*,
};

use crate::storage::entrypoint::KipioAccount;

mod capabilities;
mod constructor;
mod credentials;
mod delegations;
mod getters;
mod recovery;
mod replay;
mod sessions;

#[public]
impl KipioAccount {
    // ========================================================================
    // CONSTRUCTOR
    // ========================================================================

    /// Deploys a fresh Account for `identity`.
    ///
    /// Binds the identity, the sole authorized Runtime, and the Recovery
    /// singleton. All three are immutable thereafter — there is no setter.
    #[constructor]
    pub fn constructor(
        &mut self,
        identity: Address,
        runtime: Address,
        recovery: Address,
    ) -> Result<(), Vec<u8>> {
        constructor::handle_constructor(self, identity, runtime, recovery)
    }

    // ========================================================================
    // READ-ONLY GETTERS
    // ========================================================================

    pub fn get_identity_id(&self) -> Address {
        self.identity_id.get()
    }

    pub fn get_runtime_address(&self) -> Address {
        self.runtime_address.get()
    }

    pub fn get_recovery_address(&self) -> Address {
        self.recovery_address.get()
    }

    pub fn get_authorization_state(&self) -> AuthorizationStateAbi {
        self.read_authorization_state()
    }

    pub fn is_initialized(&self) -> bool {
        self.initialized.get()
    }

    pub fn get_nonce(&self) -> U64 {
        self.nonce.get()
    }

    pub fn is_replay_key_consumed(&self, key: B256) -> bool {
        self.consumed_replay_keys.get(key)
    }

    pub fn is_credential_active(&self, credential_id: B256) -> bool {
        getters::is_credential_active(self, credential_id)
    }

    pub fn valid_account(&self) -> bool {
        getters::valid_account(self)
    }

    pub fn valid_authorization_state(&self) -> bool {
        getters::valid_authorization_state(self)
    }

    // ========================================================================
    // PROVISIONING TRANSITIONS (Runtime-only)
    // ========================================================================

    pub fn register_credential(&mut self, credential: CredentialAbi) -> Result<bool, Vec<u8>> {
        credentials::handle_register_credential(self, credential)
    }

    pub fn register_session(&mut self, session: SessionAbi) -> Result<bool, Vec<u8>> {
        sessions::handle_register_session(self, session)
    }

    pub fn register_delegation(
        &mut self,
        delegation: DelegationAbi,
        delegate_capability: CapabilityAbi,
        delegatable_authority: Vec<CapabilityAbi>,
        source_effective_authority: Vec<CapabilityAbi>,
    ) -> Result<bool, Vec<u8>> {
        delegations::handle_register_delegation(
            self,
            delegation,
            delegate_capability,
            delegatable_authority,
            source_effective_authority,
        )
    }

    pub fn register_transitive_delegation(
        &mut self,
        delegation: DelegationAbi,
        delegate_capability: CapabilityAbi,
        delegatable_authority: Vec<CapabilityAbi>,
        source_effective_authority: Vec<CapabilityAbi>,
        parent_delegation_ids: Vec<Bytes>,
        identities: Vec<IdentityAbi>,
    ) -> Result<bool, Vec<u8>> {
        delegations::handle_register_transitive_delegation(
            self,
            delegation,
            delegate_capability,
            delegatable_authority,
            source_effective_authority,
            parent_delegation_ids,
            identities,
        )
    }

    pub fn add_capability(&mut self, capability: CapabilityAbi) -> Result<bool, Vec<u8>> {
        capabilities::handle_add_capability(self, capability)
    }

    pub fn remove_capability(&mut self, capability: CapabilityAbi) -> Result<bool, Vec<u8>> {
        capabilities::handle_remove_capability(self, capability)
    }

    pub fn set_restriction(
        &mut self,
        capability: CapabilityAbi,
        scope: OptionalScopeAbi,
        restriction: RestrictionAbi,
    ) -> Result<bool, Vec<u8>> {
        capabilities::handle_set_restriction(self, capability, scope, restriction)
    }

    pub fn remove_restriction(
        &mut self,
        capability: CapabilityAbi,
        scope: OptionalScopeAbi,
    ) -> Result<bool, Vec<u8>> {
        capabilities::handle_remove_restriction(self, capability, scope)
    }

    pub fn set_credential_authority(
        &mut self,
        credential: CredentialAbi,
        authority: Vec<CapabilityAbi>,
    ) -> Result<bool, Vec<u8>> {
        credentials::handle_set_credential_authority(self, credential, authority)
    }

    pub fn consume_replay_key(&mut self, replay_key: Bytes) -> Result<bool, Vec<u8>> {
        replay::handle_consume_replay_key(self, replay_key)
    }

    pub fn update_credential_status(
        &mut self,
        credential: CredentialAbi,
        new_status: u8,
    ) -> Result<bool, Vec<u8>> {
        credentials::handle_update_credential_status(self, credential, new_status)
    }

    pub fn update_session_status(
        &mut self,
        session: SessionAbi,
        new_status: u8,
    ) -> Result<bool, Vec<u8>> {
        sessions::handle_update_session_status(self, session, new_status)
    }

    pub fn update_delegation_status(
        &mut self,
        delegation: DelegationAbi,
        new_status: u8,
    ) -> Result<bool, Vec<u8>> {
        delegations::handle_update_delegation_status(self, delegation, new_status)
    }

    // ========================================================================
    // RECOVERY APPLICATION (Runtime-only)
    // ========================================================================

    pub fn execute_recovery(
        &mut self,
        request_id: B256,
        effects: Vec<RecoveryEffect>,
    ) -> Result<(), Vec<u8>> {
        recovery::handle_execute_recovery(self, request_id, effects)
    }
}

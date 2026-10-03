//! Public entrypoints for `kipio_recovery`.
//!
//! # Why a single `#[public]` block?
//!
//! The Stylus SDK's `#[public]` macro generates one `Router` trait impl
//! and one `HostAccess` impl per type. Rust forbids more than one impl of
//! the same trait for the same type, so all public endpoints MUST live in
//! a single `#[public] impl KipioRecovery` block.
//!
//! To keep the code readable despite this constraint, this module holds
//! the `#[public]` block with thin delegators, and the actual logic lives
//! in sibling modules as `pub(crate) fn handle_*`. The delegators carry
//! the exact same signatures as the pre-split endpoints, so the ABI is
//! unchanged.

use alloc::vec::Vec;

use stylus_sdk::{
    abi::Bytes,
    alloy_primitives::{Address, B256, U64},
    prelude::*,
};

use crate::storage::entrypoint::KipioRecovery;

mod cancel;
mod constructor;
mod consume;
mod guardians;
mod requests;
mod views;

#[public]
impl KipioRecovery {
    // ========================================================================
    // CONSTRUCTOR
    // ========================================================================

    /// Deploys the Recovery singleton.
    ///
    /// `runtime` is the sole address authorized to drive guardian
    /// configuration and the recovery request lifecycle.
    #[constructor]
    pub fn constructor(&mut self, runtime: Address) -> Result<(), Vec<u8>> {
        constructor::handle_constructor(self, runtime)
    }

    // ========================================================================
    // READ-ONLY GETTERS
    // ========================================================================

    pub fn get_runtime_address(&self) -> Address {
        self.runtime_address.get()
    }

    pub fn is_initialized(&self) -> bool {
        self.initialized.get()
    }

    // ========================================================================
    // GUARDIAN CONFIGURATION (Runtime-only)
    // ========================================================================

    pub fn set_guardians(
        &mut self,
        account: Address,
        guardian_types: Vec<u8>,
        guardian_identifiers: Vec<B256>,
        guardian_curves: Vec<u8>,
        threshold: u8,
    ) -> Result<(), Vec<u8>> {
        guardians::handle_set_guardians(
            self,
            account,
            guardian_types,
            guardian_identifiers,
            guardian_curves,
            threshold,
        )
    }

    pub fn update_guardians(
        &mut self,
        account: Address,
        guardian_types: Vec<u8>,
        guardian_identifiers: Vec<B256>,
        guardian_curves: Vec<u8>,
        threshold: u8,
        reason: u8,
    ) -> Result<(), Vec<u8>> {
        guardians::handle_update_guardians(
            self,
            account,
            guardian_types,
            guardian_identifiers,
            guardian_curves,
            threshold,
            reason,
        )
    }

    // ========================================================================
    // REQUEST LIFECYCLE (Runtime-only)
    // ========================================================================

    pub fn start_recovery(
        &mut self,
        account: Address,
        target_hash: B256,
        deadline: U64,
    ) -> Result<B256, Vec<u8>> {
        requests::handle_start_recovery(self, account, target_hash, deadline)
    }

    pub fn approve_recovery(
        &mut self,
        account: Address,
        request_id: B256,
        guardian_pubkey: Bytes,
        signature: Bytes,
    ) -> Result<(), Vec<u8>> {
        requests::handle_approve_recovery(self, account, request_id, guardian_pubkey, signature)
    }

    pub fn cancel_recovery(
        &mut self,
        account: Address,
        request_id: B256,
        signer_pubkey: Bytes,
        signer_signature: Bytes,
        signer_curve: u8,
    ) -> Result<(), Vec<u8>> {
        cancel::handle_cancel_recovery(
            self,
            account,
            request_id,
            signer_pubkey,
            signer_signature,
            signer_curve,
        )
    }

    pub fn consume_recovery(
        &mut self,
        account: Address,
        request_id: B256,
        effects_hash: B256,
    ) -> Result<(), Vec<u8>> {
        consume::handle_consume_recovery(self, account, request_id, effects_hash)
    }

    // ========================================================================
    // RECOVERY VIEWS
    // ========================================================================

    pub fn get_guardian_version(&self, account: Address) -> U64 {
        self.guardian_versions.getter(account).get()
    }

    pub fn get_guardian_set(
        &self,
        account: Address,
        version: U64,
    ) -> Result<(u8, u8, Vec<u8>, Vec<B256>, Vec<u8>), Vec<u8>> {
        views::get_guardian_set(self, account, version)
    }

    pub fn get_recovery_request(
        &self,
        account: Address,
        request_id: B256,
    ) -> Result<(u8, u64, u64, u64, u8, B256, bool), Vec<u8>> {
        views::get_recovery_request(self, account, request_id)
    }
}

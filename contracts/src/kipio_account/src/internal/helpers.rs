//! Internal helpers for `kipio_account`.

use alloc::vec::Vec;

use kipio_account_bridge::{
    AccountAbi, AuthorizationStateAbi, IdentityAbi, NotInitialized, SubjectAbi,
    UnauthorizedCaller,
};
use stylus_sdk::{
    abi::Bytes,
    alloy_primitives::{Address, B256, U64},
    alloy_sol_types::{SolError, SolValue},
    prelude::*,
};

use crate::storage::entrypoint::KipioAccount;

impl KipioAccount {
    /// Model B gate: only the Runtime set at construction time may invoke
    /// any mutating function. This closes the "attacker calls Account
    /// directly" vector.
    pub(crate) fn require_runtime(&self) -> Result<(), Vec<u8>> {
        let caller = self.vm().msg_sender();
        let runtime = self.runtime_address.get();
        if runtime == Address::ZERO {
            return Err(NotInitialized {}.abi_encode());
        }
        if caller != runtime {
            return Err(UnauthorizedCaller {}.abi_encode());
        }
        Ok(())
    }

    pub(crate) fn require_initialized(&self) -> Result<(), Vec<u8>> {
        if !self.initialized.get() || self.identity_id.get() == Address::ZERO {
            return Err(NotInitialized {}.abi_encode());
        }
        Ok(())
    }

    /// Builds a synthetic `AccountAbi` for the Dafny entrypoints.
    /// The identity fields are derived from `identity_id`; the subject
    /// reference is bound to the same address by convention.
    pub(crate) fn build_account_abi(&self, state: &AuthorizationStateAbi) -> AccountAbi {
        let id_bytes = Bytes::from(self.identity_id.get().to_vec());
        AccountAbi {
            id: id_bytes.clone(),
            identity: IdentityAbi {
                id: id_bytes.clone(),
                subject: SubjectAbi {
                    reference: id_bytes,
                },
            },
            authorizationState: state.clone(),
        }
    }

    /// Reads the full `AuthorizationState` with hot-path credential
    /// statuses overlaid in memory. The returned blob does NOT include
    /// consumed replay keys; callers that need an authoritative replay
    /// check must use `is_replay_key_consumed()`.
    pub(crate) fn read_authorization_state(&self) -> AuthorizationStateAbi {
        let raw = self.auth_state.get_bytes();
        let mut state = AuthorizationStateAbi::abi_decode(&raw).unwrap();

        for cred in state.credentials.iter_mut() {
            let key = B256::from_slice(&cred.id);
            let status_u8: u8 = self.credential_statuses.get(key).to::<u8>();
            if status_u8 != 0 {
                cred.status = status_u8;
            }
        }

        state
    }

    pub(crate) fn persist_state(&mut self, state: &AuthorizationStateAbi) {
        self.auth_state.set_bytes(&state.abi_encode());
    }

    pub(crate) fn increment_nonce(&mut self) {
        let current = self.nonce.get();
        self.nonce.set(current + U64::from(1u64));
    }
}

//! Recovery effect application.
//!
//! Rejects any `RecoveryEffect` whose discriminant is not one of the
//! three supported kinds. Fails fast BEFORE any state mutation, so a
//! malformed batch leaves the account untouched.
//!
//! The internal counterparts of the public credential mutators assume
//! the caller already enforced `require_runtime`, so they skip that
//! check and only enforce `require_initialized`.

use alloc::vec::Vec;

use kipio_account_bridge::{
    register_credential_impl, update_credential_status_impl, CredentialAbi, RecoveryEffect,
    UnsupportedEffectKind,
};
use stylus_sdk::{
    alloy_primitives::{B256, U8},
    alloy_sol_types::{SolError, SolValue},
};

use crate::abi::constants::{
    CREDENTIAL_STATUS_REVOKED, EFFECT_KIND_REGISTER_CREDENTIAL, EFFECT_KIND_REVOKE_CREDENTIAL,
    EFFECT_KIND_ROTATE_CREDENTIAL,
};
use crate::storage::entrypoint::KipioAccount;

impl KipioAccount {
    pub(crate) fn validate_effects(effects: &[RecoveryEffect]) -> Result<(), Vec<u8>> {
        for effect in effects {
            match effect.kind {
                EFFECT_KIND_REGISTER_CREDENTIAL
                | EFFECT_KIND_REVOKE_CREDENTIAL
                | EFFECT_KIND_ROTATE_CREDENTIAL => {}
                _ => return Err(UnsupportedEffectKind {}.abi_encode()),
            }
        }
        Ok(())
    }

    pub(crate) fn apply_effects(&mut self, effects: &[RecoveryEffect]) -> Result<(), Vec<u8>> {
        for effect in effects {
            match effect.kind {
                EFFECT_KIND_REGISTER_CREDENTIAL => {
                    let credential = CredentialAbi::abi_decode(&effect.payload)
                        .map_err(|_| UnsupportedEffectKind {}.abi_encode())?;
                    self.register_credential_internal(credential)?;
                }
                EFFECT_KIND_REVOKE_CREDENTIAL => {
                    let credential = CredentialAbi::abi_decode(&effect.payload)
                        .map_err(|_| UnsupportedEffectKind {}.abi_encode())?;
                    self.update_credential_status_internal(credential, CREDENTIAL_STATUS_REVOKED)?;
                }
                EFFECT_KIND_ROTATE_CREDENTIAL => {
                    let tuple = <(CredentialAbi, CredentialAbi)>::abi_decode_params(
                        &effect.payload,
                    )
                    .map_err(|_| UnsupportedEffectKind {}.abi_encode())?;
                    let (old_cred, new_cred) = tuple;

                    let old_key = B256::from_slice(&old_cred.id);
                    let old_status: u8 = self
                        .credential_statuses
                        .getter(old_key)
                        .get()
                        .to::<u8>();
                    if old_status == 0 {
                        return Err(UnsupportedEffectKind {}.abi_encode());
                    }

                    self.update_credential_status_internal(old_cred, CREDENTIAL_STATUS_REVOKED)?;
                    self.register_credential_internal(new_cred)?;
                }
                _ => {
                    return Err(UnsupportedEffectKind {}.abi_encode());
                }
            }
        }
        Ok(())
    }

    pub(crate) fn register_credential_internal(
        &mut self,
        credential: CredentialAbi,
    ) -> Result<bool, Vec<u8>> {
        self.require_initialized()?;
        let account = self.build_account_abi(&self.read_authorization_state());

        let (new_account, applied) = register_credential_impl(&account, &credential);
        if applied {
            self.persist_state(&new_account.authorizationState);
            let key = B256::from_slice(&credential.id);
            self.credential_statuses
                .setter(key)
                .set(U8::from(credential.status));
            self.increment_nonce();
        }
        Ok(applied)
    }

    pub(crate) fn update_credential_status_internal(
        &mut self,
        credential: CredentialAbi,
        new_status: u8,
    ) -> Result<bool, Vec<u8>> {
        self.require_initialized()?;
        let account = self.build_account_abi(&self.read_authorization_state());

        let (_, applied) = update_credential_status_impl(&account, &credential, new_status);

        if applied {
            let key = B256::from_slice(&credential.id);
            self.credential_statuses.setter(key).set(U8::from(new_status));
            self.increment_nonce();
        }
        Ok(applied)
    }
}

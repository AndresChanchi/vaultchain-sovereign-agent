#![cfg_attr(not(any(test, feature = "export-abi")), no_main)]
extern crate alloc;

use kipio_account_bridge::{
    add_capability_impl, consume_replay_key_impl, register_credential_impl,
    register_delegation_impl, register_session_impl, register_transitive_delegation_impl,
    remove_capability_impl, remove_restriction_impl, set_credential_authority_impl,
    set_restriction_impl, update_credential_status_impl, update_delegation_status_impl,
    update_session_status_impl, valid_account_impl, valid_authorization_state_impl,
    AccountAbi, AuthorizationStateAbi, CapabilityAbi, CredentialAbi, DelegationAbi,
    IdentityAbi, OptionalScopeAbi, RestrictionAbi, SessionAbi, SubjectAbi,
};
use stylus_sdk::abi::Bytes;
use stylus_sdk::alloy_primitives::{Address, B256, U64, U8};
use stylus_sdk::alloy_sol_types::SolValue;
use stylus_sdk::prelude::*;
use stylus_sdk::storage::*;

/// @title Kipio Account — Sovereign Identity Aggregate (stateful)
/// @notice Owns the operational AuthorizationState for a single sovereign
/// identity. Deployed once per identity via CREATE2 by the Gateway.
///
/// Per the DDD (§25, §26), Account is the aggregate that holds the
/// AuthorizationState and exposes valid state transitions. It does NOT
/// decide authorization acceptance, compute effective authority, or
/// build execution contexts — those are orchestrated by `kipio_runtime`.
///
/// STORAGE ARCHITECTURE (multidimensional gas optimization):
///
/// - Metadata (identity_id, initialized): immutable after constructor.
/// - Hot path (consumed_replay_keys, credential_statuses): StorageMaps
///   written on every relevant transition. Each key is a B256 hash,
///   occupying exactly one slot. This avoids re-serializing the full
///   AuthorizationState blob on frequent operations.
/// - Cold path (auth_state): the full AuthorizationState blob, written
///   only when the structural shape changes (add/remove credential,
///   session, delegation, capability). Readers (Runtime) fetch the full
///   state for validation and merge hot-path overlays in memory.
///
/// REPLAY KEY LOOKUP:
/// Replay keys are persisted only in the `consumed_replay_keys` hot map.
/// The blob's `consumedReplayKeys` field is intentionally left empty and
/// not reconstructed. Callers that need to check a key must use
/// `is_replay_key_consumed()`, which is authoritative and O(1).
///
/// CREDENTIAL BINDING:
/// The credential's `id` is a keccak256 hash of the raw credential
/// (passkey pubkey, Google JWT hash, etc.). The contract never sees the
/// raw credential. On-chain only its 32-byte fingerprint is persisted,
/// stored as B256 to occupy exactly one storage slot.
#[storage]
#[entrypoint]
pub struct KipioAccount {
    // ---- Metadata (immutable after constructor) --------------------------

    identity_id: StorageAddress,
    initialized: StorageBool,
    nonce: StorageU64,

    // ---- Hot path (frequent, small writes) -------------------------------

    /// Consumed replay keys, indexed by their B256 hash.
    /// One slot per key. Authoritative source for replay checks.
    consumed_replay_keys: StorageMap<B256, StorageBool>,

    /// Credential lifecycle status, indexed by credential hash.
    /// One slot per credential. Written on every status update.
    credential_statuses: StorageMap<B256, StorageU8>,

    // ---- Cold path (rare, full blob) -------------------------------------

    /// The full AuthorizationState, serialized as ABI-encoded bytes.
    /// Written only when the structural shape changes.
    auth_state: StorageBytes,
}

#[public]
impl KipioAccount {
    // ========================================================================
    // CONSTRUCTOR
    // ========================================================================

    #[constructor]
    pub fn constructor(&mut self, identity: Address) -> Result<(), Vec<u8>> {
        if identity == Address::ZERO {
            return Err(b"ZeroIdentity".to_vec());
        }
        self.identity_id.set(identity);
        self.initialized.set(true);

        let empty_state = AuthorizationStateAbi {
            capabilities: vec![],
            credentials: vec![],
            credentialAuthorities: vec![],
            sessions: vec![],
            delegations: vec![],
            delegationProvenance: vec![],
            restrictionMap: vec![],
            policyEffects: vec![],
            consumedReplayKeys: vec![],
        };
        self.auth_state.set_bytes(&empty_state.abi_encode());
        Ok(())
    }

    // ========================================================================
    // READ-ONLY GETTERS
    // ========================================================================

    pub fn get_identity_id(&self) -> Address {
        self.identity_id.get()
    }

    /// @notice Returns the full AuthorizationState with hot-path credential
    ///         statuses overlaid in memory.
    ///
    /// Replay keys are NOT included in the returned state — use
    /// `is_replay_key_consumed()` for authoritative replay checks.
    pub fn get_authorization_state(&self) -> AuthorizationStateAbi {
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

    pub fn is_initialized(&self) -> bool {
        self.initialized.get()
    }

    pub fn get_nonce(&self) -> U64 {
        self.nonce.get()
    }

    /// @notice Authoritative O(1) check for consumed replay keys.
    pub fn is_replay_key_consumed(&self, key: B256) -> bool {
        self.consumed_replay_keys.get(key)
    }

    // ========================================================================
    // VALIDATORS
    // ========================================================================

    pub fn valid_account(&self) -> bool {
        let state = self.get_authorization_state();
        valid_account_impl(&self.build_account_abi(&state))
    }

    pub fn valid_authorization_state(&self) -> bool {
        valid_authorization_state_impl(&self.get_authorization_state())
    }

    // ========================================================================
    // PROVISIONING TRANSITIONS
    // ========================================================================

    pub fn register_credential(&mut self, credential: CredentialAbi) -> Result<bool, Vec<u8>> {
        self.require_initialized()?;
        let account = self.build_account_abi(&self.get_authorization_state());

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

    pub fn register_session(&mut self, session: SessionAbi) -> Result<bool, Vec<u8>> {
        self.require_initialized()?;
        let account = self.build_account_abi(&self.get_authorization_state());

        let (new_account, applied) = register_session_impl(&account, &session);
        if applied {
            self.persist_state(&new_account.authorizationState);
            self.increment_nonce();
        }
        Ok(applied)
    }

    pub fn register_delegation(
        &mut self,
        delegation: DelegationAbi,
        delegate_capability: CapabilityAbi,
        delegatable_authority: Vec<CapabilityAbi>,
        source_effective_authority: Vec<CapabilityAbi>,
    ) -> Result<bool, Vec<u8>> {
        self.require_initialized()?;
        let account = self.build_account_abi(&self.get_authorization_state());

        let (new_account, applied) = register_delegation_impl(
            &account,
            &delegation,
            &delegate_capability,
            &delegatable_authority,
            &source_effective_authority,
        );
        if applied {
            self.persist_state(&new_account.authorizationState);
            self.increment_nonce();
        }
        Ok(applied)
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
        self.require_initialized()?;
        let account = self.build_account_abi(&self.get_authorization_state());

        let (new_account, applied) = register_transitive_delegation_impl(
            &account,
            &delegation,
            &delegate_capability,
            &delegatable_authority,
            &source_effective_authority,
            &parent_delegation_ids,
            &identities,
        );
        if applied {
            self.persist_state(&new_account.authorizationState);
            self.increment_nonce();
        }
        Ok(applied)
    }

    pub fn add_capability(&mut self, capability: CapabilityAbi) -> Result<bool, Vec<u8>> {
        self.require_initialized()?;
        let account = self.build_account_abi(&self.get_authorization_state());

        let (new_account, applied) = add_capability_impl(&account, &capability);
        if applied {
            self.persist_state(&new_account.authorizationState);
            self.increment_nonce();
        }
        Ok(applied)
    }

    pub fn remove_capability(&mut self, capability: CapabilityAbi) -> Result<bool, Vec<u8>> {
        self.require_initialized()?;
        let account = self.build_account_abi(&self.get_authorization_state());

        let (new_account, applied) = remove_capability_impl(&account, &capability);
        if applied {
            self.persist_state(&new_account.authorizationState);
            self.increment_nonce();
        }
        Ok(applied)
    }

    pub fn set_restriction(
        &mut self,
        capability: CapabilityAbi,
        scope: OptionalScopeAbi,
        restriction: RestrictionAbi,
    ) -> Result<bool, Vec<u8>> {
        self.require_initialized()?;
        let account = self.build_account_abi(&self.get_authorization_state());

        let (new_account, applied) = set_restriction_impl(&account, &capability, &scope, &restriction);
        if applied {
            self.persist_state(&new_account.authorizationState);
            self.increment_nonce();
        }
        Ok(applied)
    }

    pub fn remove_restriction(
        &mut self,
        capability: CapabilityAbi,
        scope: OptionalScopeAbi,
    ) -> Result<bool, Vec<u8>> {
        self.require_initialized()?;
        let account = self.build_account_abi(&self.get_authorization_state());

        let (new_account, applied) = remove_restriction_impl(&account, &capability, &scope);
        if applied {
            self.persist_state(&new_account.authorizationState);
            self.increment_nonce();
        }
        Ok(applied)
    }

    pub fn set_credential_authority(
        &mut self,
        credential: CredentialAbi,
        authority: Vec<CapabilityAbi>,
    ) -> Result<bool, Vec<u8>> {
        self.require_initialized()?;
        let account = self.build_account_abi(&self.get_authorization_state());

        let (new_account, applied) = set_credential_authority_impl(&account, &credential, &authority);
        if applied {
            self.persist_state(&new_account.authorizationState);
            self.increment_nonce();
        }
        Ok(applied)
    }

    /// @notice Marks a ReplayKey as consumed.
    /// @dev HOT PATH: single SSTORE, no blob re-serialization.
    pub fn consume_replay_key(&mut self, replay_key: Bytes) -> Result<bool, Vec<u8>> {
        self.require_initialized()?;
        let key_hash = B256::from_slice(&replay_key);

        if self.consumed_replay_keys.get(key_hash) {
            return Ok(false);
        }

        let account = self.build_account_abi(&self.get_authorization_state());
        let (_, applied) = consume_replay_key_impl(&account, &replay_key);

        if applied {
            self.consumed_replay_keys.setter(key_hash).set(true);
            self.increment_nonce();
        }
        Ok(applied)
    }

    /// @notice Updates the lifecycle status of a recognized Credential.
    /// @dev HOT PATH: single SSTORE, no blob re-serialization.
    pub fn update_credential_status(
        &mut self,
        credential: CredentialAbi,
        new_status: u8,
    ) -> Result<bool, Vec<u8>> {
        self.require_initialized()?;
        let account = self.build_account_abi(&self.get_authorization_state());

        let (_, applied) = update_credential_status_impl(&account, &credential, new_status);

        if applied {
            let key = B256::from_slice(&credential.id);
            self.credential_statuses.setter(key).set(U8::from(new_status));
            self.increment_nonce();
        }
        Ok(applied)
    }

    pub fn update_session_status(
        &mut self,
        session: SessionAbi,
        new_status: u8,
    ) -> Result<bool, Vec<u8>> {
        self.require_initialized()?;
        let account = self.build_account_abi(&self.get_authorization_state());

        let (new_account, applied) = update_session_status_impl(&account, &session, new_status);
        if applied {
            self.persist_state(&new_account.authorizationState);
            self.increment_nonce();
        }
        Ok(applied)
    }

    pub fn update_delegation_status(
        &mut self,
        delegation: DelegationAbi,
        new_status: u8,
    ) -> Result<bool, Vec<u8>> {
        self.require_initialized()?;
        let account = self.build_account_abi(&self.get_authorization_state());

        let (new_account, applied) = update_delegation_status_impl(&account, &delegation, new_status);
        if applied {
            self.persist_state(&new_account.authorizationState);
            self.increment_nonce();
        }
        Ok(applied)
    }
}

// ============================================================================
// INTERNAL HELPERS
// ============================================================================

impl KipioAccount {
    fn require_initialized(&self) -> Result<(), Vec<u8>> {
        if !self.initialized.get() {
            return Err(b"NotInitialized".to_vec());
        }
        Ok(())
    }

    fn build_account_abi(&self, state: &AuthorizationStateAbi) -> AccountAbi {
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

    fn persist_state(&mut self, state: &AuthorizationStateAbi) {
        self.auth_state.set_bytes(&state.abi_encode());
    }

    fn increment_nonce(&mut self) {
        let current = self.nonce.get();
        self.nonce.set(current + U64::from(1));
    }
}

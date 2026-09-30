#![cfg_attr(not(any(test, feature = "export-abi")), no_main)]
extern crate alloc;

use alloc::vec::Vec;

use kipio_account_bridge::{
    // --- `*_impl` entrypoints ---
    add_capability_impl, consume_replay_key_impl, register_credential_impl,
    register_delegation_impl, register_session_impl, register_transitive_delegation_impl,
    remove_capability_impl, remove_restriction_impl, set_credential_authority_impl,
    set_restriction_impl, update_credential_status_impl, update_delegation_status_impl,
    update_session_status_impl, valid_account_impl, valid_authorization_state_impl,

    // --- ABI types (shared with the bridge; no local mirror) ---
    AccountAbi, AuthorizationStateAbi, CapabilityAbi, CredentialAbi, DelegationAbi,
    IdentityAbi, OptionalScopeAbi, RecoveryEffect, RestrictionAbi, SessionAbi, SubjectAbi,

    // --- Errors (from the bridge's shared error set) ---
    NotInitialized, RecoveryConsumeFailed, UnauthorizedCaller, UnsupportedEffectKind,
    ZeroIdentity, ZeroRecovery, ZeroRuntime,
};
use stylus_sdk::{
    abi::Bytes,
    alloy_primitives::{Address, B256, U64, U8},
    alloy_sol_types::{SolError, SolValue},
    crypto::keccak,
    prelude::*,
    storage::*,
};

// ============================================================================
// DOMAIN CONSTANTS
// ============================================================================

/// @dev `RecoveryEffect.kind = 1`: register a new credential.
///      Payload encoding: `CredentialAbi`.
const EFFECT_KIND_REGISTER_CREDENTIAL: u8 = 1;

/// @dev `RecoveryEffect.kind = 2`: revoke an existing credential.
///      Payload encoding: `CredentialAbi`.
const EFFECT_KIND_REVOKE_CREDENTIAL: u8 = 2;

/// @dev `RecoveryEffect.kind = 3`: rotate a credential (revoke old,
///      register new). Payload encoding: `(CredentialAbi, CredentialAbi)`.
const EFFECT_KIND_ROTATE_CREDENTIAL: u8 = 3;

/// @dev Credential lifecycle status: active.
const CREDENTIAL_STATUS_ACTIVE: u8 = 1;

/// @dev Credential lifecycle status: revoked.
const CREDENTIAL_STATUS_REVOKED: u8 = 3;

// ============================================================================
// CROSS-CONTRACT INTERFACE — KIPIO RECOVERY
// ============================================================================
//
// The Account contract calls `consumeRecovery` on the Recovery contract
// during `execute_recovery`. The call validates the recovery request,
// checks the deadline, `executable_after` and hash constraints, marks
// the request as EXECUTED, and returns. If it reverts, the Account's
// state changes revert atomically with it.
//
// Only the account itself is authorized to call `consumeRecovery` on
// Recovery. Recovery enforces `msg_sender() == account` on its side.

sol_interface! {
    interface IKipioRecovery {
        function consumeRecovery(
            address account,
            bytes32 request_id,
            bytes32 effects_hash
        ) external;
    }
}

// ============================================================================
// STORAGE
// ============================================================================
//
// The Account contract owns:
//   - identity metadata (identity_id, runtime, recovery)
//   - the full AuthorizationState blob (Dafny-verified shape)
//   - hot-path credential statuses and consumed replay keys
//
// It does NOT own guardian configuration or the recovery request ledger.
// Those live in the dedicated `kipio_recovery` singleton, keyed by
// account address. Splitting the two subsystems keeps each WASM under
// the 256 KiB uncompressed activation limit without sacrificing the
// invariant that only Runtime orchestrates user-facing flows.
//
// MULTIDIMENSIONAL GAS — STORAGE DESIGN:
//
//   - Metadata (`identity_id`, `runtime_address`, `recovery_address`,
//     `initialized`): immutable after constructor. One slot each.
//   - Hot path (`consumed_replay_keys`, `credential_statuses`): one slot
//     per B256 key. Written on every relevant transition without
//     re-serializing the full state blob.
//   - Cold path (`auth_state`): a single `StorageBytes` blob, written
//     only when the structural shape of the state changes (add/remove
//     credential, session, delegation, capability).
//
// Replay keys are persisted exclusively in the hot map. The blob's
// `consumedReplayKeys` field is intentionally left empty and is not
// reconstructed by `get_authorization_state`. Callers that need an
// authoritative replay check must use `is_replay_key_consumed()`,
// which is O(1) and bypasses the blob entirely.

#[storage]
#[entrypoint]
pub struct KipioAccount {
    // ---- Metadata (immutable after constructor) --------------------------
    identity_id: StorageAddress,
    runtime_address: StorageAddress,
    recovery_address: StorageAddress,
    initialized: StorageBool,
    nonce: StorageU64,

    // ---- Hot path (frequent, small writes) -------------------------------
    consumed_replay_keys: StorageMap<B256, StorageBool>,
    credential_statuses: StorageMap<B256, StorageU8>,

    // ---- Cold path (rare, full blob) -------------------------------------
    auth_state: StorageBytes,
}

// ============================================================================
// PUBLIC INTERFACE
// ============================================================================

#[public]
impl KipioAccount {
    // ========================================================================
    // CONSTRUCTOR
    // ========================================================================
    //
    // Atomically binds the identity, the sole authorized Runtime, and the
    // Recovery singleton. All three are immutable thereafter — there is
    // no setter, by design. Any evolution of these pointers is a
    // deployment-level decision handled by the Gateway via CREATE2.

    /// @notice Deploys a fresh Account for `identity`.
    /// @dev    Called exactly once, atomically during CREATE2.
    /// @param  identity  Sovereign address this account represents.
    /// @param  runtime   The sole address authorized to invoke mutators.
    /// @param  recovery  Address of the shared Recovery singleton.
    #[constructor]
    pub fn constructor(
        &mut self,
        identity: Address,
        runtime: Address,
        recovery: Address,
    ) -> Result<(), Vec<u8>> {
        if identity == Address::ZERO {
            return Err(ZeroIdentity {}.abi_encode());
        }
        if runtime == Address::ZERO {
            return Err(ZeroRuntime {}.abi_encode());
        }
        if recovery == Address::ZERO {
            return Err(ZeroRecovery {}.abi_encode());
        }
        self.identity_id.set(identity);
        self.runtime_address.set(runtime);
        self.recovery_address.set(recovery);
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

    /// @notice Returns the sovereign identity bound at construction.
    pub fn get_identity_id(&self) -> Address {
        self.identity_id.get()
    }

    /// @notice Returns the sole authorized Runtime address.
    pub fn get_runtime_address(&self) -> Address {
        self.runtime_address.get()
    }

    /// @notice Returns the shared Recovery singleton address.
    pub fn get_recovery_address(&self) -> Address {
        self.recovery_address.get()
    }

    /// @notice Returns the full AuthorizationState with hot-path credential
    ///         statuses overlaid in memory.
    ///
    /// @dev    The returned blob does NOT include consumed replay keys.
    ///         Use `is_replay_key_consumed()` for authoritative replay
    ///         checks — the hot map is the single source of truth for
    ///         that field.
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

    /// @notice Returns true when the contract has been constructed.
    pub fn is_initialized(&self) -> bool {
        self.initialized.get()
    }

    /// @notice Monotonic nonce advanced on every accepted state transition.
    /// @dev    Exposed for the Recovery singleton, which binds the
    ///         cancellation digest to the account's current nonce.
    pub fn get_nonce(&self) -> U64 {
        self.nonce.get()
    }

    /// @notice Authoritative O(1) check for consumed replay keys.
    pub fn is_replay_key_consumed(&self, key: B256) -> bool {
        self.consumed_replay_keys.get(key)
    }

    /// @notice Returns true when the credential id (keccak of the raw
    ///         credential) is currently marked ACTIVE.
    ///
    /// @dev    Read-only helper for the Recovery singleton. Recovery
    ///         calls this during `cancel_recovery` to verify the
    ///         cancellation signer is still a recognized active
    ///         credential.
    pub fn is_credential_active(&self, credential_id: B256) -> bool {
        let status: u8 = self
            .credential_statuses
            .getter(credential_id)
            .get()
            .to::<u8>();
        status == CREDENTIAL_STATUS_ACTIVE
    }

    /// @notice Structural validator: is the current state a valid
    ///         Dafny `Account`?
    pub fn valid_account(&self) -> bool {
        let state = self.get_authorization_state();
        valid_account_impl(&self.build_account_abi(&state))
    }

    /// @notice Structural validator: is the current state a valid
    ///         Dafny `AuthorizationState`?
    pub fn valid_authorization_state(&self) -> bool {
        valid_authorization_state_impl(&self.get_authorization_state())
    }

    // ========================================================================
    // PROVISIONING TRANSITIONS (Runtime-only)
    // ========================================================================
    //
    // MODEL B (per DDD §35): Runtime is the sole orchestrator. Account
    // executes state transitions without re-validating authorization.
    // Runtime is responsible for verifying the user's intent (signature
    // against a credential, or any other gate) BEFORE cross-calling
    // into Account. Account trusts Runtime completely.
    //
    // All mutators carry the `require_runtime()` gate. If the caller is
    // not the Runtime set at construction time, the call reverts with
    // `UnauthorizedCaller`. This closes the "attacker calls Account
    // directly" vector.

    /// @notice Registers a new credential binding for the current actor.
    /// @dev    Idempotent on the Dafny side (re-registering the same
    ///         credential is a silent no-op). Writes the hot-path
    ///         status map and the cold-path blob.
    pub fn register_credential(&mut self, credential: CredentialAbi) -> Result<bool, Vec<u8>> {
        self.require_runtime()?;
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

    /// @notice Registers a new session bound to a previously registered
    ///         credential.
    pub fn register_session(&mut self, session: SessionAbi) -> Result<bool, Vec<u8>> {
        self.require_runtime()?;
        self.require_initialized()?;
        let account = self.build_account_abi(&self.get_authorization_state());

        let (new_account, applied) = register_session_impl(&account, &session);
        if applied {
            self.persist_state(&new_account.authorizationState);
            self.increment_nonce();
        }
        Ok(applied)
    }

    /// @notice Registers a root delegation from the sovereign identity to
    ///         a delegatee subject.
    pub fn register_delegation(
        &mut self,
        delegation: DelegationAbi,
        delegate_capability: CapabilityAbi,
        delegatable_authority: Vec<CapabilityAbi>,
        source_effective_authority: Vec<CapabilityAbi>,
    ) -> Result<bool, Vec<u8>> {
        self.require_runtime()?;
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

    /// @notice Registers a transitive delegation with explicit parent
    ///         provenance.
    pub fn register_transitive_delegation(
        &mut self,
        delegation: DelegationAbi,
        delegate_capability: CapabilityAbi,
        delegatable_authority: Vec<CapabilityAbi>,
        source_effective_authority: Vec<CapabilityAbi>,
        parent_delegation_ids: Vec<Bytes>,
        identities: Vec<IdentityAbi>,
    ) -> Result<bool, Vec<u8>> {
        self.require_runtime()?;
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

    /// @notice Adds a capability to the account's capability set.
    pub fn add_capability(&mut self, capability: CapabilityAbi) -> Result<bool, Vec<u8>> {
        self.require_runtime()?;
        self.require_initialized()?;
        let account = self.build_account_abi(&self.get_authorization_state());

        let (new_account, applied) = add_capability_impl(&account, &capability);
        if applied {
            self.persist_state(&new_account.authorizationState);
            self.increment_nonce();
        }
        Ok(applied)
    }

    /// @notice Removes a capability. Any restrictions targeting the
    ///         removed capability are cascaded out of the state.
    pub fn remove_capability(&mut self, capability: CapabilityAbi) -> Result<bool, Vec<u8>> {
        self.require_runtime()?;
        self.require_initialized()?;
        let account = self.build_account_abi(&self.get_authorization_state());

        let (new_account, applied) = remove_capability_impl(&account, &capability);
        if applied {
            self.persist_state(&new_account.authorizationState);
            self.increment_nonce();
        }
        Ok(applied)
    }

    /// @notice Sets a restriction on a recognized capability.
    pub fn set_restriction(
        &mut self,
        capability: CapabilityAbi,
        scope: OptionalScopeAbi,
        restriction: RestrictionAbi,
    ) -> Result<bool, Vec<u8>> {
        self.require_runtime()?;
        self.require_initialized()?;
        let account = self.build_account_abi(&self.get_authorization_state());

        let (new_account, applied) =
            set_restriction_impl(&account, &capability, &scope, &restriction);
        if applied {
            self.persist_state(&new_account.authorizationState);
            self.increment_nonce();
        }
        Ok(applied)
    }

    /// @notice Removes a restriction target.
    pub fn remove_restriction(
        &mut self,
        capability: CapabilityAbi,
        scope: OptionalScopeAbi,
    ) -> Result<bool, Vec<u8>> {
        self.require_runtime()?;
        self.require_initialized()?;
        let account = self.build_account_abi(&self.get_authorization_state());

        let (new_account, applied) = remove_restriction_impl(&account, &capability, &scope);
        if applied {
            self.persist_state(&new_account.authorizationState);
            self.increment_nonce();
        }
        Ok(applied)
    }

    /// @notice Replaces the authority set for a recognized credential.
    /// @dev    Enforces that every existing session bound to the
    ///         credential remains within the new authority set. This is
    ///         a safety invariant from the Dafny model, not a policy
    ///         choice — it prevents credential authority from silently
    ///         invalidating already-active sessions.
    pub fn set_credential_authority(
        &mut self,
        credential: CredentialAbi,
        authority: Vec<CapabilityAbi>,
    ) -> Result<bool, Vec<u8>> {
        self.require_runtime()?;
        self.require_initialized()?;
        let account = self.build_account_abi(&self.get_authorization_state());

        let (new_account, applied) =
            set_credential_authority_impl(&account, &credential, &authority);
        if applied {
            self.persist_state(&new_account.authorizationState);
            self.increment_nonce();
        }
        Ok(applied)
    }

    /// @notice Marks a replay key as consumed.
    /// @dev    HOT PATH: single SSTORE, no blob re-serialization. The
    ///         blob's `consumedReplayKeys` field is intentionally not
    ///         maintained; `is_replay_key_consumed()` is authoritative.
    pub fn consume_replay_key(&mut self, replay_key: Bytes) -> Result<bool, Vec<u8>> {
        self.require_runtime()?;
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

    /// @notice Updates the lifecycle status of a recognized credential.
    /// @dev    HOT PATH: single SSTORE to the status map, no blob
    ///         re-serialization.
    pub fn update_credential_status(
        &mut self,
        credential: CredentialAbi,
        new_status: u8,
    ) -> Result<bool, Vec<u8>> {
        self.require_runtime()?;
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

    /// @notice Updates the lifecycle status of a session.
    pub fn update_session_status(
        &mut self,
        session: SessionAbi,
        new_status: u8,
    ) -> Result<bool, Vec<u8>> {
        self.require_runtime()?;
        self.require_initialized()?;
        let account = self.build_account_abi(&self.get_authorization_state());

        let (new_account, applied) = update_session_status_impl(&account, &session, new_status);
        if applied {
            self.persist_state(&new_account.authorizationState);
            self.increment_nonce();
        }
        Ok(applied)
    }

    /// @notice Updates the lifecycle status of a delegation.
    pub fn update_delegation_status(
        &mut self,
        delegation: DelegationAbi,
        new_status: u8,
    ) -> Result<bool, Vec<u8>> {
        self.require_runtime()?;
        self.require_initialized()?;
        let account = self.build_account_abi(&self.get_authorization_state());

        let (new_account, applied) =
            update_delegation_status_impl(&account, &delegation, new_status);
        if applied {
            self.persist_state(&new_account.authorizationState);
            self.increment_nonce();
        }
        Ok(applied)
    }

    // ========================================================================
    // RECOVERY APPLICATION (Runtime-only)
    // ========================================================================
    //
    // The Runtime orchestrator calls `execute_recovery` once a recovery
    // request has been approved by its guardian threshold. The Account
    // contract:
    //
    //   1. Verifies the caller is the Runtime.
    //   2. Computes the effects hash.
    //   3. Cross-calls Recovery.consumeRecovery, which validates the
    //      request (status, deadline, executable_after, hash) and marks
    //      it EXECUTED. If it reverts, the whole transaction reverts.
    //   4. Applies the effects to the Account's AuthorizationState.
    //
    // ORDERING INVARIANT (CEI):
    //   Recovery's state is mutated BEFORE the Account's effects are
    //   applied, and the Recovery cross-call is the LAST external
    //   interaction. If it reverts, everything rolls back atomically.
    //   The Recovery cross-call is a single-shot, non-reentrant call
    //   that cannot observe an intermediate Account state.

    /// @notice Applies a batch of recovery effects after Recovery
    ///         validates and consumes the request.
    /// @param  request_id  Deterministic id returned by `startRecovery`.
    /// @param  effects     Ordered batch of credential-level mutations.
    pub fn execute_recovery(
        &mut self,
        request_id: B256,
        effects: Vec<RecoveryEffect>,
    ) -> Result<(), Vec<u8>> {
        self.require_runtime()?;
        self.require_initialized()?;

        let encoded = effects.abi_encode();
        let computed_hash = keccak(&encoded);

        let recovery_addr = self.recovery_address.get();
        if recovery_addr == Address::ZERO {
            return Err(NotInitialized {}.abi_encode());
        }

        let account_addr = self.vm().contract_address();
        let recovery = IKipioRecovery::new(recovery_addr);
        let ctx = Call::new_mutating(self);
        let host = self.vm();

        recovery
            .consume_recovery(host, ctx, account_addr, request_id, computed_hash)
            .map_err(|_| RecoveryConsumeFailed {}.abi_encode())?;

        Self::validate_effects(&effects)?;
        self.apply_effects(&effects)?;

        self.increment_nonce();
        Ok(())
    }
}

// ============================================================================
// INTERNAL HELPERS
// ============================================================================

impl KipioAccount {
    /// @dev Model B gate: only the Runtime set at construction time may
    ///      invoke any mutating function. This closes the "attacker
    ///      calls Account directly" vector.
    fn require_runtime(&self) -> Result<(), Vec<u8>> {
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

    fn require_initialized(&self) -> Result<(), Vec<u8>> {
        if !self.initialized.get() || self.identity_id.get() == Address::ZERO {
            return Err(NotInitialized {}.abi_encode());
        }
        Ok(())
    }

    /// @dev Builds a synthetic `AccountAbi` for the Dafny entrypoints.
    ///      The identity fields are derived from `identity_id`; the
    ///      subject reference is bound to the same address by
    ///      convention.
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
        self.nonce.set(current + U64::from(1u64));
    }

    /// @dev Rejects any `RecoveryEffect` whose discriminant is not one
    ///      of the three supported kinds. Fails fast BEFORE any state
    ///      mutation, so a malformed batch leaves the account untouched.
    fn validate_effects(effects: &[RecoveryEffect]) -> Result<(), Vec<u8>> {
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

    /// @dev Applies each effect through the same Dafny entrypoints used
    ///      by the public mutators, but without re-decoding ABI. The
    ///      `require_runtime` gate is already enforced by the caller
    ///      (`execute_recovery`), so the internal helpers do NOT
    ///      re-check.
    fn apply_effects(&mut self, effects: &[RecoveryEffect]) -> Result<(), Vec<u8>> {
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

    /// @dev Internal counterpart of `register_credential`, used by
    ///      `apply_effects`. Assumes the caller already validated the
    ///      Runtime gate.
    fn register_credential_internal(
        &mut self,
        credential: CredentialAbi,
    ) -> Result<bool, Vec<u8>> {
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

    /// @dev Internal counterpart of `update_credential_status`, used by
    ///      `apply_effects`. Assumes the caller already validated the
    ///      Runtime gate.
    fn update_credential_status_internal(
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
}

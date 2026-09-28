#![cfg_attr(not(any(test, feature = "export-abi")), no_main)]
extern crate alloc;

use alloc::{vec, vec::Vec};

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
use stylus_sdk::alloy_sol_types::{sol, SolError, SolValue};
use stylus_sdk::crypto::keccak;
use stylus_sdk::prelude::*;
use stylus_sdk::storage::*;

// ============================================================================
// PRECOMPILE ADDRESSES
// ============================================================================

const P256_VERIFY_PRECOMPILE: Address = Address::new([
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x01, 0x00,
]);

const ECRECOVER_PRECOMPILE: Address = Address::new([
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x01,
]);

// ============================================================================
// DOMAIN CONSTANTS
// ============================================================================

const CURVE_P256: u8 = 1;
const CURVE_SECP256K1: u8 = 2;

const RECOVERY_STATUS_NONE: u8 = 0;
const RECOVERY_STATUS_ACTIVE: u8 = 1;
const RECOVERY_STATUS_APPROVED: u8 = 2;
const RECOVERY_STATUS_EXECUTED: u8 = 3;
const RECOVERY_STATUS_CANCELLED: u8 = 4;
const RECOVERY_STATUS_EXPIRED: u8 = 5;

const EFFECT_KIND_REGISTER_CREDENTIAL: u8 = 1;
const EFFECT_KIND_REVOKE_CREDENTIAL: u8 = 2;
const EFFECT_KIND_ROTATE_CREDENTIAL: u8 = 3;

const CREDENTIAL_STATUS_ACTIVE: u8 = 1;
const CREDENTIAL_STATUS_REVOKED: u8 = 3;

const MAX_GUARDIANS: usize = 16;

const CHALLENGE_PERIOD_SECONDS: u64 = 3 * 24 * 60 * 60;

const APPROVE_DOMAIN: &[u8] = b"KIPIO_RECOVERY_APPROVE_V1";
const CANCEL_DOMAIN: &[u8] = b"KIPIO_RECOVERY_CANCEL_V1";

// ============================================================================
// DOMAIN TYPES
// ============================================================================

sol! {
    #[derive(AbiType)]
    struct RecoveryEffect {
        uint8 kind;
        bytes payload;
    }
}

sol! {
    event GuardiansConfigured(address indexed account, uint64 version, uint8 count, uint8 threshold);
    event GuardiansUpdated(address indexed account, uint64 version, uint8 count, uint8 threshold, uint8 reason);

    event RecoveryStarted(
        address indexed account,
        bytes32 indexed requestId,
        bytes32 targetHash,
        uint64 deadline,
        uint64 guardianVersion
    );

    event RecoveryApprovalGranted(
        bytes32 indexed requestId,
        bytes32 indexed guardianHash,
        uint8 curve
    );

    event RecoveryApproved(
        bytes32 indexed requestId,
        uint64 executableAfter
    );

    event RecoveryCancelled(bytes32 indexed requestId, address indexed cancelledBy);
    event RecoveryExecuted(bytes32 indexed requestId, address indexed executedBy);
    event RecoveryExpired(bytes32 indexed requestId);

    error NotInitialized();
    error ZeroIdentity();
    error ZeroRuntime();
    error UnauthorizedCaller();

    error GuardiansAlreadyConfigured();
    error GuardiansNotConfigured();
    error InvalidGuardianCount();
    error GuardianLengthMismatch();
    error DuplicateGuardian();
    error InvalidThreshold();
    error InvalidGuardianType();
    error ZeroGuardianIdentifier();
    error InvalidUpdateReason();
    error MaxGuardiansExceeded();

    error RecoveryNotFound();
    error RecoveryNotActive();
    error RecoveryNotApproved();
    error RecoveryAlreadyFinalized();
    error RecoveryNotExecutableYet();
    error RecoveryExpiredErr();
    error ExpiredDeadline();
    error ActiveRecoveryExists();

    error EmptySignature();
    error EmptyPubkey();
    error UnknownGuardian();
    error InvalidCurve();
    error SignatureVerificationFailed();
    error AlreadyApproved();
    error UnsupportedEffectKind();

    error CancelNotAuthorized();
}

// ============================================================================
// STORAGE
// ============================================================================

#[storage]
#[entrypoint]
pub struct KipioAccount {
    // ---- Metadata ---------------------------------------------------------
    //
    // `identity_id` is the sovereign address this Account belongs to.
    // `runtime_address` is the ONLY address allowed to invoke mutating
    // functions. Both are set atomically in the constructor and are
    // immutable for the Account's lifetime.
    //
    // MODEL B (per DDD §35): Runtime is the sole orchestrator. Account
    // executes state transitions without re-validating authorization.
    // Runtime is responsible for verifying the user's intent (signature
    // against a credential, or any other gate) BEFORE cross-calling into
    // Account. Account trusts Runtime completely.
    //
    // DIRECT CALLS ARE REJECTED. Any address other than `runtime_address`
    // receives `UnauthorizedCaller`, including the identity itself.
    // This closes the "attacker calls Account directly" vector.
    identity_id: StorageAddress,
    runtime_address: StorageAddress,
    initialized: StorageBool,
    nonce: StorageU64,

    // ---- Hot path ---------------------------------------------------------
    consumed_replay_keys: StorageMap<B256, StorageBool>,
    credential_statuses: StorageMap<B256, StorageU8>,

    // ---- Cold path --------------------------------------------------------
    auth_state: StorageBytes,

    // ========================================================================
    // RECOVERY — GUARDIAN CONFIGURATION
    // ========================================================================
    guardian_versions: StorageU64,
    guardian_counts: StorageMap<U64, StorageU8>,
    guardian_thresholds: StorageMap<U64, StorageU8>,
    guardian_types: StorageMap<U64, StorageMap<U8, StorageU8>>,
    guardian_identifiers: StorageMap<U64, StorageMap<U8, StorageB256>>,
    guardian_curves: StorageMap<U64, StorageMap<U8, StorageU8>>,
    guardian_validations: StorageMap<U64, StorageMap<B256, StorageU8>>,
    guardian_update_reasons: StorageMap<U64, StorageU8>,

    // ========================================================================
    // RECOVERY — REQUEST LEDGER
    // ========================================================================
    next_recovery_id: StorageU64,
    active_recovery_id: StorageB256,

    recovery_target_hash: StorageMap<B256, StorageB256>,
    recovery_deadline: StorageMap<B256, StorageU64>,
    recovery_executable_after: StorageMap<B256, StorageU64>,
    recovery_guardian_version: StorageMap<B256, StorageU64>,
    recovery_approval_count: StorageMap<B256, StorageU8>,
    recovery_status: StorageMap<B256, StorageU8>,
    recovery_approvals: StorageMap<B256, StorageMap<B256, StorageBool>>,
}

#[public]
impl KipioAccount {
    // ========================================================================
    // CONSTRUCTOR
    // ========================================================================
    //
    // Called atomically during CREATE2 deployment. Sets the identity and
    // the sole authorized Runtime in one transaction. Both values are
    // immutable thereafter — there is no setter.

    #[constructor]
    pub fn constructor(&mut self, identity: Address, runtime: Address) -> Result<(), Vec<u8>> {
        if identity == Address::ZERO {
            return Err(ZeroIdentity {}.abi_encode());
        }
        if runtime == Address::ZERO {
            return Err(ZeroRuntime {}.abi_encode());
        }
        self.identity_id.set(identity);
        self.runtime_address.set(runtime);
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
    // READ-ONLY GETTERS (public — no gating)
    // ========================================================================

    pub fn get_identity_id(&self) -> Address {
        self.identity_id.get()
    }

    pub fn get_runtime_address(&self) -> Address {
        self.runtime_address.get()
    }

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

    pub fn is_replay_key_consumed(&self, key: B256) -> bool {
        self.consumed_replay_keys.get(key)
    }

    pub fn valid_account(&self) -> bool {
        let state = self.get_authorization_state();
        valid_account_impl(&self.build_account_abi(&state))
    }

    pub fn valid_authorization_state(&self) -> bool {
        valid_authorization_state_impl(&self.get_authorization_state())
    }

    // ========================================================================
    // PROVISIONING TRANSITIONS (Runtime-only)
    // ========================================================================

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
    // RECOVERY — GUARDIAN CONFIGURATION (Runtime-only)
    // ========================================================================

    pub fn set_guardians(
        &mut self,
        guardian_types: Vec<u8>,
        guardian_identifiers: Vec<B256>,
        guardian_curves: Vec<u8>,
        threshold: u8,
    ) -> Result<(), Vec<u8>> {
        self.require_runtime()?;
        self.require_initialized()?;

        if self.guardian_versions.get() != U64::ZERO {
            return Err(GuardiansAlreadyConfigured {}.abi_encode());
        }

        let count = guardian_types.len() as u8;

        self.write_guardian_version(
            U64::from(1u64),
            &guardian_types,
            &guardian_identifiers,
            &guardian_curves,
            threshold,
        )?;

        self.guardian_versions.set(U64::from(1u64));

        self.vm().log(GuardiansConfigured {
            account: self.vm().contract_address(),
            version: 1,
            count,
            threshold,
        });
        Ok(())
    }

    pub fn update_guardians(
        &mut self,
        guardian_types: Vec<u8>,
        guardian_identifiers: Vec<B256>,
        guardian_curves: Vec<u8>,
        threshold: u8,
        reason: u8,
    ) -> Result<(), Vec<u8>> {
        self.require_runtime()?;
        self.require_initialized()?;

        if !(1..=6).contains(&reason) {
            return Err(InvalidUpdateReason {}.abi_encode());
        }

        self.ensure_no_active_recovery()?;

        let current = self.guardian_versions.get();
        if current == U64::ZERO {
            return Err(GuardiansNotConfigured {}.abi_encode());
        }

        let new_version = current + U64::from(1u64);
        let count = guardian_types.len() as u8;

        self.write_guardian_version(
            new_version,
            &guardian_types,
            &guardian_identifiers,
            &guardian_curves,
            threshold,
        )?;

        self.guardian_versions.set(new_version);
        self.guardian_update_reasons
            .setter(new_version)
            .set(U8::from(reason));

        self.vm().log(GuardiansUpdated {
            account: self.vm().contract_address(),
            version: new_version.to::<u64>(),
            count,
            threshold,
            reason,
        });
        Ok(())
    }

    // ========================================================================
    // RECOVERY — REQUEST LIFECYCLE (Runtime-only)
    // ========================================================================

    pub fn start_recovery(
        &mut self,
        target_hash: B256,
        deadline: U64,
    ) -> Result<B256, Vec<u8>> {
        self.require_runtime()?;
        self.require_initialized()?;

        if target_hash == B256::ZERO {
            return Err(RecoveryNotFound {}.abi_encode());
        }

        let now = U64::from(self.vm().block_timestamp());
        if now > deadline {
            return Err(ExpiredDeadline {}.abi_encode());
        }

        self.ensure_no_active_recovery()?;

        let current_version = self.guardian_versions.get();
        if current_version == U64::ZERO {
            return Err(GuardiansNotConfigured {}.abi_encode());
        }

        let counter = self.next_recovery_id.get();
        let account_bytes = self.vm().contract_address().to_vec();
        let counter_bytes = counter.to_be_bytes::<32>();

        let mut preimage = Vec::with_capacity(52);
        preimage.extend_from_slice(&account_bytes);
        preimage.extend_from_slice(&counter_bytes);
        let request_id = keccak(&preimage);

        self.next_recovery_id.set(counter + U64::from(1u64));

        self.recovery_target_hash.setter(request_id).set(target_hash);
        self.recovery_deadline.setter(request_id).set(deadline);
        self.recovery_guardian_version
            .setter(request_id)
            .set(current_version);
        self.recovery_approval_count
            .setter(request_id)
            .set(U8::ZERO);
        self.recovery_status
            .setter(request_id)
            .set(U8::from(RECOVERY_STATUS_ACTIVE));
        self.active_recovery_id.set(request_id);

        self.vm().log(RecoveryStarted {
            account: self.vm().contract_address(),
            requestId: request_id,
            targetHash: target_hash,
            deadline: deadline.to::<u64>(),
            guardianVersion: current_version.to::<u64>(),
        });

        Ok(request_id)
    }

    pub fn approve_recovery(
        &mut self,
        request_id: B256,
        guardian_pubkey: Bytes,
        signature: Bytes,
    ) -> Result<(), Vec<u8>> {
        self.require_runtime()?;
        self.require_initialized()?;

        if guardian_pubkey.is_empty() {
            return Err(EmptyPubkey {}.abi_encode());
        }
        if signature.is_empty() {
            return Err(EmptySignature {}.abi_encode());
        }

        let status = self.recovery_status.getter(request_id).get().to::<u8>();
        if status != RECOVERY_STATUS_ACTIVE {
            return Err(RecoveryNotActive {}.abi_encode());
        }

        if self.is_expired(request_id) {
            self.mark_expired(request_id);
            return Err(RecoveryExpiredErr {}.abi_encode());
        }

        let version = self.recovery_guardian_version.getter(request_id).get();
        let guardian_hash = keccak(&guardian_pubkey.0);

        let validation_index = self
            .guardian_validations
            .getter(version)
            .getter(guardian_hash)
            .get();

        if validation_index == U8::ZERO {
            return Err(UnknownGuardian {}.abi_encode());
        }

        if self
            .recovery_approvals
            .getter(request_id)
            .getter(guardian_hash)
            .get()
        {
            return Err(AlreadyApproved {}.abi_encode());
        }

        let idx: u8 = validation_index.to::<u8>() - 1;
        let curve: u8 = self
            .guardian_curves
            .getter(version)
            .getter(U8::from(idx))
            .get()
            .to::<u8>();

        let digest = self.build_recovery_approval_digest(
            request_id,
            self.recovery_target_hash.getter(request_id).get(),
        );

        if !self.verify_guardian_signature(curve, digest, &signature, &guardian_pubkey) {
            return Err(SignatureVerificationFailed {}.abi_encode());
        }

        self.recovery_approvals
            .setter(request_id)
            .setter(guardian_hash)
            .set(true);

        let count = self.recovery_approval_count.getter(request_id).get();
        let new_count = count + U8::from(1u8);
        self.recovery_approval_count
            .setter(request_id)
            .set(new_count);

        self.vm().log(RecoveryApprovalGranted {
            requestId: request_id,
            guardianHash: guardian_hash,
            curve,
        });

        let threshold = self.guardian_thresholds.getter(version).get();
        if new_count >= threshold {
            let now = U64::from(self.vm().block_timestamp());
            let executable_after = now + U64::from(CHALLENGE_PERIOD_SECONDS);

            self.recovery_status
                .setter(request_id)
                .set(U8::from(RECOVERY_STATUS_APPROVED));
            self.recovery_executable_after
                .setter(request_id)
                .set(executable_after);

            self.vm().log(RecoveryApproved {
                requestId: request_id,
                executableAfter: executable_after.to::<u64>(),
            });
        }

        self.increment_nonce();
        Ok(())
    }

    pub fn cancel_recovery(
        &mut self,
        request_id: B256,
        signer_pubkey: Bytes,
        signer_signature: Bytes,
        signer_curve: u8,
    ) -> Result<(), Vec<u8>> {
        self.require_runtime()?;
        self.require_initialized()?;

        if signer_pubkey.is_empty() {
            return Err(EmptyPubkey {}.abi_encode());
        }
        if signer_signature.is_empty() {
            return Err(EmptySignature {}.abi_encode());
        }

        let status = self.recovery_status.getter(request_id).get().to::<u8>();
        if status == RECOVERY_STATUS_NONE {
            return Err(RecoveryNotFound {}.abi_encode());
        }
        if status == RECOVERY_STATUS_EXECUTED
            || status == RECOVERY_STATUS_CANCELLED
            || status == RECOVERY_STATUS_EXPIRED
        {
            return Err(RecoveryAlreadyFinalized {}.abi_encode());
        }

        if self.is_expired(request_id) {
            self.mark_expired(request_id);
            return Err(RecoveryExpiredErr {}.abi_encode());
        }

        let credential_id = keccak(&signer_pubkey.0);
        let credential_status: u8 = self
            .credential_statuses
            .getter(credential_id)
            .get()
            .to::<u8>();
        if credential_status != CREDENTIAL_STATUS_ACTIVE {
            return Err(CancelNotAuthorized {}.abi_encode());
        }

        let current_nonce = self.nonce.get();
        let digest = self.build_recovery_cancel_digest(request_id, current_nonce);

        if !self.verify_guardian_signature(
            signer_curve,
            digest,
            &signer_signature,
            &signer_pubkey,
        ) {
            return Err(CancelNotAuthorized {}.abi_encode());
        }

        self.recovery_status
            .setter(request_id)
            .set(U8::from(RECOVERY_STATUS_CANCELLED));
        self.active_recovery_id.set(B256::ZERO);

        self.vm().log(RecoveryCancelled {
            requestId: request_id,
            cancelledBy: self.vm().msg_sender(),
        });

        self.increment_nonce();
        Ok(())
    }

    pub fn execute_recovery(
        &mut self,
        request_id: B256,
        effects: Vec<RecoveryEffect>,
    ) -> Result<(), Vec<u8>> {
        self.require_runtime()?;
        self.require_initialized()?;

        let status = self.recovery_status.getter(request_id).get().to::<u8>();
        if status == RECOVERY_STATUS_NONE {
            return Err(RecoveryNotFound {}.abi_encode());
        }
        if status != RECOVERY_STATUS_APPROVED {
            return Err(RecoveryNotApproved {}.abi_encode());
        }

        if self.is_expired(request_id) {
            self.mark_expired(request_id);
            return Err(RecoveryExpiredErr {}.abi_encode());
        }

        let now = U64::from(self.vm().block_timestamp());
        let executable_after = self.recovery_executable_after.getter(request_id).get();
        if now < executable_after {
            return Err(RecoveryNotExecutableYet {}.abi_encode());
        }

        let encoded = effects.abi_encode();
        let computed_hash = keccak(&encoded);
        let expected_hash = self.recovery_target_hash.getter(request_id).get();
        if computed_hash != expected_hash {
            return Err(SignatureVerificationFailed {}.abi_encode());
        }

        Self::validate_effects(&effects)?;
        self.apply_effects(&effects)?;

        self.recovery_status
            .setter(request_id)
            .set(U8::from(RECOVERY_STATUS_EXECUTED));
        self.active_recovery_id.set(B256::ZERO);

        self.vm().log(RecoveryExecuted {
            requestId: request_id,
            executedBy: self.vm().msg_sender(),
        });

        self.increment_nonce();
        Ok(())
    }

    // ========================================================================
    // RECOVERY — VIEWS (public — no gating)
    // ========================================================================

    pub fn get_guardian_version(&self) -> U64 {
        self.guardian_versions.get()
    }

    pub fn get_guardian_set(
        &self,
        version: U64,
    ) -> Result<(u8, u8, Vec<u8>, Vec<B256>, Vec<u8>), Vec<u8>> {
        if version == U64::ZERO || version > self.guardian_versions.get() {
            return Err(GuardiansNotConfigured {}.abi_encode());
        }

        let count: u8 = self.guardian_counts.getter(version).get().to::<u8>();
        let threshold: u8 = self.guardian_thresholds.getter(version).get().to::<u8>();

        let mut types = Vec::with_capacity(count as usize);
        let mut ids = Vec::with_capacity(count as usize);
        let mut curves = Vec::with_capacity(count as usize);

        for i in 0..count {
            let idx = U8::from(i);
            types.push(
                self.guardian_types
                    .getter(version)
                    .getter(idx)
                    .get()
                    .to::<u8>(),
            );
            ids.push(self.guardian_identifiers.getter(version).getter(idx).get());
            curves.push(
                self.guardian_curves
                    .getter(version)
                    .getter(idx)
                    .get()
                    .to::<u8>(),
            );
        }

        Ok((count, threshold, types, ids, curves))
    }

    pub fn get_recovery_request(
        &self,
        request_id: B256,
    ) -> Result<(u8, u64, u64, u64, u8, B256, bool), Vec<u8>> {
        let status = self.recovery_status.getter(request_id).get().to::<u8>();
        if status == RECOVERY_STATUS_NONE {
            return Err(RecoveryNotFound {}.abi_encode());
        }

        let version = self
            .recovery_guardian_version
            .getter(request_id)
            .get()
            .to::<u64>();
        let deadline = self.recovery_deadline.getter(request_id).get().to::<u64>();
        let executable_after = self
            .recovery_executable_after
            .getter(request_id)
            .get()
            .to::<u64>();
        let approvals = self
            .recovery_approval_count
            .getter(request_id)
            .get()
            .to::<u8>();
        let target = self.recovery_target_hash.getter(request_id).get();
        let expired = self.is_expired(request_id);

        Ok((
            status,
            version,
            deadline,
            executable_after,
            approvals,
            target,
            expired,
        ))
    }
}

// ============================================================================
// INTERNAL HELPERS
// ============================================================================

impl KipioAccount {
    /// @dev Model B gate: only the Runtime set at construction time may
    ///      invoke any mutating function. This closes the "attacker calls
    ///      Account directly" vector, which the previous version of this
    ///      contract left open. Runtime is responsible for verifying the
    ///      user's intent before cross-calling into Account.
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

    // --------------------------------------------------------------------
    // GUARDIAN CONFIGURATION WRITER
    // --------------------------------------------------------------------

    fn write_guardian_version(
        &mut self,
        version: U64,
        guardian_types: &[u8],
        guardian_identifiers: &[B256],
        guardian_curves: &[u8],
        threshold: u8,
    ) -> Result<(), Vec<u8>> {
        let count = guardian_types.len();

        if count == 0 {
            return Err(InvalidGuardianCount {}.abi_encode());
        }
        if count > MAX_GUARDIANS {
            return Err(MaxGuardiansExceeded {}.abi_encode());
        }
        if guardian_identifiers.len() != count || guardian_curves.len() != count {
            return Err(GuardianLengthMismatch {}.abi_encode());
        }
        if threshold == 0 || threshold > count as u8 {
            return Err(InvalidThreshold {}.abi_encode());
        }

        for i in 0..count {
            if guardian_identifiers[i] == B256::ZERO {
                return Err(ZeroGuardianIdentifier {}.abi_encode());
            }
            for j in (i + 1)..count {
                if guardian_identifiers[i] == guardian_identifiers[j] {
                    return Err(DuplicateGuardian {}.abi_encode());
                }
            }
        }

        for i in 0..count {
            if guardian_types[i] == 0 {
                return Err(InvalidGuardianType {}.abi_encode());
            }
            let curve = guardian_curves[i];
            if curve != CURVE_P256 && curve != CURVE_SECP256K1 {
                return Err(InvalidCurve {}.abi_encode());
            }
        }

        for i in 0..count {
            let idx = U8::from(i as u8);
            self.guardian_types
                .setter(version)
                .setter(idx)
                .set(U8::from(guardian_types[i]));
            self.guardian_identifiers
                .setter(version)
                .setter(idx)
                .set(guardian_identifiers[i]);
            self.guardian_curves
                .setter(version)
                .setter(idx)
                .set(U8::from(guardian_curves[i]));
            self.guardian_validations
                .setter(version)
                .setter(guardian_identifiers[i])
                .set(U8::from((i + 1) as u8));
        }

        self.guardian_counts
            .setter(version)
            .set(U8::from(count as u8));
        self.guardian_thresholds
            .setter(version)
            .set(U8::from(threshold));

        Ok(())
    }

    // --------------------------------------------------------------------
    // RECOVERY HELPERS
    // --------------------------------------------------------------------

    fn is_expired(&self, request_id: B256) -> bool {
        let deadline = self.recovery_deadline.getter(request_id).get();
        let now = U64::from(self.vm().block_timestamp());
        now > deadline
    }

    fn mark_expired(&mut self, request_id: B256) {
        self.recovery_status
            .setter(request_id)
            .set(U8::from(RECOVERY_STATUS_EXPIRED));
        if self.active_recovery_id.get() == request_id {
            self.active_recovery_id.set(B256::ZERO);
        }
        self.vm().log(RecoveryExpired {
            requestId: request_id,
        });
    }

    fn ensure_no_active_recovery(&mut self) -> Result<(), Vec<u8>> {
        let current = self.active_recovery_id.get();
        if current == B256::ZERO {
            return Ok(());
        }

        let status = self.recovery_status.getter(current).get().to::<u8>();

        if status == RECOVERY_STATUS_ACTIVE || status == RECOVERY_STATUS_APPROVED {
            if self.is_expired(current) {
                self.mark_expired(current);
                return Ok(());
            }
            return Err(ActiveRecoveryExists {}.abi_encode());
        }

        self.active_recovery_id.set(B256::ZERO);
        Ok(())
    }

    fn u64_to_be32(v: u64) -> [u8; 32] {
        let mut out = [0u8; 32];
        out[24..32].copy_from_slice(&v.to_be_bytes());
        out
    }

    fn build_recovery_approval_digest(
        &self,
        request_id: B256,
        target_hash: B256,
    ) -> B256 {
        let chain_id = Self::u64_to_be32(self.vm().chain_id());
        let mut preimage = Vec::with_capacity(96 + 32 + 32);
        preimage.extend_from_slice(APPROVE_DOMAIN);
        preimage.extend_from_slice(&chain_id);
        preimage.extend_from_slice(self.vm().contract_address().as_slice());
        preimage.extend_from_slice(request_id.as_slice());
        preimage.extend_from_slice(target_hash.as_slice());
        keccak(&preimage)
    }

    fn build_recovery_cancel_digest(
        &self,
        request_id: B256,
        nonce: U64,
    ) -> B256 {
        let chain_id = Self::u64_to_be32(self.vm().chain_id());
        let nonce_bytes = Self::u64_to_be32(nonce.to::<u64>());
        let mut preimage = Vec::with_capacity(96 + 32 + 32);
        preimage.extend_from_slice(CANCEL_DOMAIN);
        preimage.extend_from_slice(&chain_id);
        preimage.extend_from_slice(self.vm().contract_address().as_slice());
        preimage.extend_from_slice(request_id.as_slice());
        preimage.extend_from_slice(&nonce_bytes);
        keccak(&preimage)
    }

    // --------------------------------------------------------------------
    // SIGNATURE VERIFICATION
    // --------------------------------------------------------------------

    fn verify_guardian_signature(
        &self,
        curve: u8,
        digest: B256,
        signature: &Bytes,
        pubkey: &Bytes,
    ) -> bool {
        match curve {
            CURVE_P256 => self.verify_p256(digest, signature, pubkey),
            CURVE_SECP256K1 => self.verify_secp256k1(digest, signature, pubkey),
            _ => false,
        }
    }

    fn verify_p256(&self, digest: B256, signature: &Bytes, pubkey: &Bytes) -> bool {
        if signature.len() != 64 || pubkey.len() != 64 {
            return false;
        }

        let mut input = Vec::with_capacity(160);
        input.extend_from_slice(digest.as_slice());
        input.extend_from_slice(&signature[0..32]);
        input.extend_from_slice(&signature[32..64]);
        input.extend_from_slice(&pubkey[0..32]);
        input.extend_from_slice(&pubkey[32..64]);

        let result = static_call(
            self.vm(),
            Call::new(),
            P256_VERIFY_PRECOMPILE,
            input.as_slice(),
        );

        match result {
            Ok(output) if output.len() == 32 => output[31] == 1,
            _ => false,
        }
    }

    fn verify_secp256k1(&self, digest: B256, signature: &Bytes, pubkey: &Bytes) -> bool {
        if pubkey.len() != 65 || signature.len() != 65 {
            return false;
        }
        if pubkey[0] != 0x04 {
            return false;
        }

        let expected_address = self.secp256k1_pubkey_to_address(pubkey);

        let mut input = [0u8; 128];
        input[0..32].copy_from_slice(digest.as_slice());
        input[63] = signature[64];
        input[64..96].copy_from_slice(&signature[0..32]);
        input[96..128].copy_from_slice(&signature[32..64]);

        let result = static_call(
            self.vm(),
            Call::new(),
            ECRECOVER_PRECOMPILE,
            &input,
        );

        match result {
            Ok(output) if output.len() == 32 => {
                let recovered = Address::from_slice(&output[12..32]);
                recovered == expected_address
            }
            _ => false,
        }
    }

    fn secp256k1_pubkey_to_address(&self, pubkey: &Bytes) -> Address {
        let hash = keccak(&pubkey[1..65]);
        Address::from_slice(&hash[12..32])
    }

    // --------------------------------------------------------------------
    // EFFECT APPLICATION
    // --------------------------------------------------------------------

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

    fn apply_effects(&mut self, effects: &[RecoveryEffect]) -> Result<(), Vec<u8>> {
        for effect in effects {
            match effect.kind {
                EFFECT_KIND_REGISTER_CREDENTIAL => {
                    let credential = CredentialAbi::abi_decode(&effect.payload)
                        .map_err(|_| UnsupportedEffectKind {}.abi_encode())?;
                    self.register_credential(credential)?;
                }
                EFFECT_KIND_REVOKE_CREDENTIAL => {
                    let credential = CredentialAbi::abi_decode(&effect.payload)
                        .map_err(|_| UnsupportedEffectKind {}.abi_encode())?;
                    self.update_credential_status(credential, CREDENTIAL_STATUS_REVOKED)?;
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

                    self.update_credential_status(old_cred, CREDENTIAL_STATUS_REVOKED)?;
                    self.register_credential(new_cred)?;
                }
                _ => {
                    return Err(UnsupportedEffectKind {}.abi_encode());
                }
            }
        }
        Ok(())
    }
}

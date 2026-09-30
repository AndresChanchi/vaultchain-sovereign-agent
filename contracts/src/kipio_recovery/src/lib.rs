#![cfg_attr(not(any(test, feature = "export-abi")), no_main)]
#![allow(unexpected_cfgs)]
extern crate alloc;

use alloc::vec::Vec;

use stylus_sdk::{
    abi::Bytes,
    alloy_primitives::{Address, B256, U64, U8, U256},
    alloy_sol_types::{sol, SolError},
    call::static_call,
    crypto::keccak,
    prelude::*,
    storage::*,
};

// ============================================================================
// ABI — EVENTS AND ERRORS (Recovery-owned)
// ============================================================================
//
// All events emitted by Recovery and all errors raised by Recovery are
// declared here. They belong to the Recovery bounded context: no other
// contract in the workspace emits or raises them, so keeping them local
// avoids duplicating ABI machinery across contracts.
//
// The Recovery contract uses `#[public]`, so the `#[public]` macro
// generates the `*Call` structs for every public method automatically.
// There is no need to declare function signatures in a separate `sol!`
// block. The cross-contract interface consumed by Recovery (calls into
// Account) is declared via `sol_interface!` below.
//
// All function arguments are Solidity builtins (`address`, `bytes32`,
// `uint64`, `uint8`, `bytes`, `bytes32[]`), so no custom ABI type from
// the shared bridge is required. This keeps `kipio_recovery`
// self-contained and prevents ABI machinery duplication.

sol! {
    // --- Events ---
    event GuardiansConfigured(
        address indexed account,
        uint64 version,
        uint8 count,
        uint8 threshold
    );
    event GuardiansUpdated(
        address indexed account,
        uint64 version,
        uint8 count,
        uint8 threshold,
        uint8 reason
    );

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

    // --- Errors ---
    error NotInitialized();
    error UnauthorizedCaller();
    error ZeroRuntime();

    error GuardiansAlreadyConfigured();
    error GuardiansNotConfigured();
    error InvalidGuardianCount();
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

    error CancelNotAuthorized();
}

// ============================================================================
// PRECOMPILE ADDRESSES
// ============================================================================

/// @dev ArbOS native secp256r1 verifier (EIP-7951, superseded RIP-7212).
///      Thin wrapper: no WASM crypto, only raw calldata forwarding.
const P256_VERIFY_PRECOMPILE: Address = Address::new([
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x01, 0x00,
]);

/// @dev ecrecover precompile. Used for secp256k1 EOA guardians.
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

/// @dev Hard cap on the size of a guardian set. Bounded so that the
///      approval bitfield fits in a single `U256` (240 bits of headroom
///      left) and the linear-scan `find_guardian_index` stays cheap.
const MAX_GUARDIANS: usize = 16;

/// @dev Time between threshold approval and execution. During this
///      window the sovereign identity can still cancel the recovery
///      using one of its active credentials.
const CHALLENGE_PERIOD_SECONDS: u64 = 3 * 24 * 60 * 60;

const APPROVE_DOMAIN: &[u8] = b"KIPIO_RECOVERY_APPROVE_V1";
const CANCEL_DOMAIN: &[u8] = b"KIPIO_RECOVERY_CANCEL_V1";

/// @dev Compile-time bitmask table for the recovery approval bitfield.
///
///      `recovery_approvals[account][request_id]` is a `U256` where bit
///      `i` is set when the guardian at index `i` of the request's
///      pinned guardian version has approved. `MAX_GUARDIANS` is 16, so
///      a single `U256` covers the entire bitfield with 240 bits of
///      headroom.
///
///      Precomputed at compile time to avoid any dependency on `U256`
///      shift semantics during gas-sensitive execution. Access is
///      `O(1)` and infallible for `idx < MAX_GUARDIANS`.
const APPROVAL_BITS: [u64; 16] = [
    1u64 << 0, 1u64 << 1, 1u64 << 2, 1u64 << 3,
    1u64 << 4, 1u64 << 5, 1u64 << 6, 1u64 << 7,
    1u64 << 8, 1u64 << 9, 1u64 << 10, 1u64 << 11,
    1u64 << 12, 1u64 << 13, 1u64 << 14, 1u64 << 15,
];

// ============================================================================
// CROSS-CONTRACT INTERFACE — KIPIO ACCOUNT
// ============================================================================
//
// Recovery calls back into the Account contract for two read-only
// lookups during `cancel_recovery`:
//
//   - `isCredentialActive(bytes32)`: whether the credential id (keccak
//     fingerprint of the raw pubkey) is currently marked ACTIVE.
//   - `getNonce()`: the account's current nonce, bound into the
//     cancellation digest so that a signature produced for one nonce
//     cannot be replayed after any account state change.
//
// Both calls are `static_call` semantics: they cannot mutate state and
// cannot reenter Recovery.

sol_interface! {
    interface IKipioAccount {
        function isCredentialActive(bytes32 credential_id) external view returns (bool);
        function getNonce() external view returns (uint64);
    }
}

// ============================================================================
// PACKED GUARDIAN METADATA
// ============================================================================
//
// Two fields per version are packed into single slots. Unpacking is
// pure in-memory bit manipulation on the already-loaded word; no SLOAD
// is performed inside these helpers.

/// @dev Unpacks `(count, threshold, update_reason)` from a single
///      `U256`. Bytes [0]=count, [1]=threshold, [2]=update_reason.
#[inline]
fn guardian_meta_unpack(packed: U256) -> (u8, u8, u8) {
    let bytes: [u8; 32] = packed.to_be_bytes();
    (bytes[0], bytes[1], bytes[2])
}

/// @dev Packs `(count, threshold, update_reason)` into a single `U256`.
#[inline]
fn guardian_meta_pack(count: u8, threshold: u8, update_reason: u8) -> U256 {
    let mut bytes = [0u8; 32];
    bytes[0] = count;
    bytes[1] = threshold;
    bytes[2] = update_reason;
    U256::from_be_bytes(bytes)
}

/// @dev Packs the per-guardian `(type, curve)` pairs into a single
///      `B256`. Bytes [0..16) hold types, bytes [16..32) hold curves.
///
///      Both arrays are `u8` and at most `MAX_GUARDIANS` long, so the
///      whole schedule fits in exactly one slot. This is the key
///      storage compression: a version with N guardians writes exactly
///      `2 + N` slots (meta + schedule + N identifiers) instead of the
///      `4 + 4N` slots used by the pre-split layout.
#[inline]
fn guardian_schedule_pack(types: &[u8], curves: &[u8]) -> B256 {
    let mut bytes = [0u8; 32];
    let n_types = types.len().min(MAX_GUARDIANS);
    bytes[0..n_types].copy_from_slice(&types[0..n_types]);
    let n_curves = curves.len().min(MAX_GUARDIANS);
    bytes[16..16 + n_curves].copy_from_slice(&curves[0..n_curves]);
    B256::from_slice(&bytes)
}

// ============================================================================
// STORAGE
// ============================================================================
//
// The Recovery contract is a **singleton**: one deployment shared by
// every KipioAccount. Every storage field is keyed by the account
// address at the top level. Under the Stylus multidimensional gas
// model, the nested maps do not create slots until they are written,
// so the marginal storage cost per account is exactly the same as it
// was when the subsystem lived inside `kipio_account`.
//
// GUARDIANS (per account, per version, N guardians, MAX_GUARDIANS = 16):
//
//   - guardian_meta[acct][v]            1 slot  (count | threshold | reason)
//   - guardian_schedule[acct][v]        1 slot  (types[16] | curves[16])
//   - guardian_identifiers[acct][v][i]  N slots (B256 per guardian)
//   Total: 2 + N slots per version.
//
//   The reverse index (guardian_hash -> index) is NOT stored. It is
//   derived on the fly by linear scan over the identifiers array. With
//   N <= 16, this is a handful of SLOADs and a handful of equality
//   comparisons, negligible against the cost of maintaining an extra
//   slot per guardian.
//
// RECOVERY APPROVALS (per account, per request):
//
//   - recovery_approvals[acct][req]     1 slot (bitfield over guardians)
//
//   Each guardian's approval is a single bit indexed by its position in
//   the request's pinned guardian version. One `U256` covers the entire
//   bitfield.
//
// REQUEST LEDGER:
//
//   Every per-request field is a `StorageMap<Address, StorageMap<B256, T>>`
//   keyed by (account, request_id). The `request_id` is derived as
//   `keccak256(account || next_recovery_id[account])`, making it
//   deterministic and globally unique without a global counter.

#[storage]
#[entrypoint]
pub struct KipioRecovery {
    runtime_address: StorageAddress,
    initialized: StorageBool,

    // ========================================================================
    // GUARDIAN CONFIGURATION (per account)
    // ========================================================================
    guardian_versions: StorageMap<Address, StorageU64>,
    guardian_meta: StorageMap<Address, StorageMap<U64, StorageU256>>,
    guardian_schedule: StorageMap<Address, StorageMap<U64, StorageB256>>,
    guardian_identifiers: StorageMap<Address, StorageMap<U64, StorageMap<U8, StorageB256>>>,

    // ========================================================================
    // REQUEST LEDGER (per account)
    // ========================================================================
    next_recovery_id: StorageMap<Address, StorageU64>,
    active_recovery_id: StorageMap<Address, StorageB256>,

    recovery_target_hash: StorageMap<Address, StorageMap<B256, StorageB256>>,
    recovery_deadline: StorageMap<Address, StorageMap<B256, StorageU64>>,
    recovery_executable_after: StorageMap<Address, StorageMap<B256, StorageU64>>,
    recovery_guardian_version: StorageMap<Address, StorageMap<B256, StorageU64>>,
    recovery_approval_count: StorageMap<Address, StorageMap<B256, StorageU8>>,
    recovery_status: StorageMap<Address, StorageMap<B256, StorageU8>>,
    recovery_approvals: StorageMap<Address, StorageMap<B256, StorageU256>>,
}

// ============================================================================
// PUBLIC INTERFACE
// ============================================================================

#[public]
impl KipioRecovery {
    // ========================================================================
    // CONSTRUCTOR
    // ========================================================================

    /// @notice Deploys the Recovery singleton.
    /// @param  runtime The sole address authorized to drive guardian
    ///         configuration and the recovery request lifecycle.
    #[constructor]
    pub fn constructor(&mut self, runtime: Address) -> Result<(), Vec<u8>> {
        if runtime == Address::ZERO {
            return Err(ZeroRuntime {}.abi_encode());
        }
        self.runtime_address.set(runtime);
        self.initialized.set(true);
        Ok(())
    }

    // ========================================================================
    // READ-ONLY GETTERS
    // ========================================================================

    /// @notice Returns the sole authorized Runtime address.
    pub fn get_runtime_address(&self) -> Address {
        self.runtime_address.get()
    }

    pub fn is_initialized(&self) -> bool {
        self.initialized.get()
    }

    // ========================================================================
    // GUARDIAN CONFIGURATION (Runtime-only)
    // ========================================================================

    /// @notice Configures the initial guardian set for `account`.
    /// @dev    One-shot per account. Subsequent changes must go through
    ///         `update_guardians`, which advances the version.
    ///
    /// @param  account                Target account address.
    /// @param  guardian_types         Per-guardian type discriminant (non-zero).
    /// @param  guardian_identifiers   Per-guardian B256 fingerprint.
    /// @param  guardian_curves        Per-guardian curve id (P256 or secp256k1).
    /// @param  threshold              Minimum approvals required to approve.
    pub fn set_guardians(
        &mut self,
        account: Address,
        guardian_types: Vec<u8>,
        guardian_identifiers: Vec<B256>,
        guardian_curves: Vec<u8>,
        threshold: u8,
    ) -> Result<(), Vec<u8>> {
        self.require_runtime()?;
        self.require_initialized()?;

        if self.guardian_versions.getter(account).get() != U64::ZERO {
            return Err(GuardiansAlreadyConfigured {}.abi_encode());
        }

        let count = guardian_types.len() as u8;

        // reason = 0 for initial configuration.
        self.write_guardian_version(
            account,
            U64::from(1u64),
            &guardian_types,
            &guardian_identifiers,
            &guardian_curves,
            threshold,
            0,
        )?;

        self.guardian_versions.setter(account).set(U64::from(1u64));

        self.vm().log(GuardiansConfigured {
            account,
            version: 1,
            count,
            threshold,
        });
        Ok(())
    }

    /// @notice Advances the guardian set for `account` to a new version.
    /// @dev    Rejected while a recovery request is in flight (ACTIVE or
    ///         APPROVED). The `reason` discriminant is restricted to
    ///         `1..=6` as a fixed taxonomy for off-chain analytics.
    pub fn update_guardians(
        &mut self,
        account: Address,
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

        self.ensure_no_active_recovery(account)?;

        let current = self.guardian_versions.getter(account).get();
        if current == U64::ZERO {
            return Err(GuardiansNotConfigured {}.abi_encode());
        }

        let new_version = current + U64::from(1u64);
        let count = guardian_types.len() as u8;

        self.write_guardian_version(
            account,
            new_version,
            &guardian_types,
            &guardian_identifiers,
            &guardian_curves,
            threshold,
            reason,
        )?;

        self.guardian_versions.setter(account).set(new_version);

        self.vm().log(GuardiansUpdated {
            account,
            version: new_version.to::<u64>(),
            count,
            threshold,
            reason,
        });
        Ok(())
    }

    // ========================================================================
    // REQUEST LIFECYCLE (Runtime-only)
    // ========================================================================

    /// @notice Opens a new recovery request for `account`.
    /// @dev    The `request_id` is deterministic:
    ///         `keccak256(account || next_recovery_id[account])`.
    ///         Rejected while another request is in flight.
    ///
    /// @param  account      Target account address.
    /// @param  target_hash  keccak of the effects payload the request
    ///                      will eventually carry.
    /// @param  deadline     Absolute timestamp after which the request
    ///                      can be marked EXPIRED.
    /// @return request_id   The freshly minted request id.
    pub fn start_recovery(
        &mut self,
        account: Address,
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

        self.ensure_no_active_recovery(account)?;

        let current_version = self.guardian_versions.getter(account).get();
        if current_version == U64::ZERO {
            return Err(GuardiansNotConfigured {}.abi_encode());
        }

        let counter = self.next_recovery_id.getter(account).get();
        let account_bytes = account.to_vec();
        let counter_bytes = counter.to_be_bytes::<32>();

        let mut preimage = Vec::with_capacity(52);
        preimage.extend_from_slice(&account_bytes);
        preimage.extend_from_slice(&counter_bytes);
        let request_id = keccak(&preimage);

        self.next_recovery_id
            .setter(account)
            .set(counter + U64::from(1u64));

        self.recovery_target_hash
            .setter(account)
            .setter(request_id)
            .set(target_hash);
        self.recovery_deadline
            .setter(account)
            .setter(request_id)
            .set(deadline);
        self.recovery_guardian_version
            .setter(account)
            .setter(request_id)
            .set(current_version);
        self.recovery_approval_count
            .setter(account)
            .setter(request_id)
            .set(U8::ZERO);
        self.recovery_status
            .setter(account)
            .setter(request_id)
            .set(U8::from(RECOVERY_STATUS_ACTIVE));
        self.active_recovery_id.setter(account).set(request_id);

        self.vm().log(RecoveryStarted {
            account,
            requestId: request_id,
            targetHash: target_hash,
            deadline: deadline.to::<u64>(),
            guardianVersion: current_version.to::<u64>(),
        });

        Ok(request_id)
    }

    /// @notice Records a guardian approval for an ACTIVE request.
    /// @dev    Idempotent at the guardian level: a re-approval from the
    ///         same guardian reverts with `AlreadyApproved`. When the
    ///         threshold is crossed the request transitions to APPROVED
    ///         and `executable_after = now + CHALLENGE_PERIOD_SECONDS`.
    ///
    ///         The signature digest binds the request to the pinned
    ///         guardian version and the target hash, so a signature
    ///         produced for a different request or a different effect
    ///         batch cannot be reused.
    pub fn approve_recovery(
        &mut self,
        account: Address,
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

        let status = self
            .recovery_status
            .getter(account)
            .getter(request_id)
            .get()
            .to::<u8>();
        if status != RECOVERY_STATUS_ACTIVE {
            return Err(RecoveryNotActive {}.abi_encode());
        }

        if self.is_expired(account, request_id) {
            self.mark_expired(account, request_id);
            return Err(RecoveryExpiredErr {}.abi_encode());
        }

        let version = self
            .recovery_guardian_version
            .getter(account)
            .getter(request_id)
            .get();
        let guardian_hash = keccak(&guardian_pubkey.0);

        let idx = match self.find_guardian_index(account, version, guardian_hash) {
            Some(i) => i,
            None => return Err(UnknownGuardian {}.abi_encode()),
        };

        let curve = self.guardian_curve_at(account, version, idx);

        let bit = U256::from(APPROVAL_BITS[idx as usize]);
        let approvals = self
            .recovery_approvals
            .getter(account)
            .getter(request_id)
            .get();
        if !(approvals & bit).is_zero() {
            return Err(AlreadyApproved {}.abi_encode());
        }

        let target_hash = self
            .recovery_target_hash
            .getter(account)
            .getter(request_id)
            .get();
        let digest = self.build_recovery_approval_digest(account, request_id, target_hash);

        if !self.verify_guardian_signature(curve, digest, &signature, &guardian_pubkey) {
            return Err(SignatureVerificationFailed {}.abi_encode());
        }

        self.recovery_approvals
            .setter(account)
            .setter(request_id)
            .set(approvals | bit);

        let count = self
            .recovery_approval_count
            .getter(account)
            .getter(request_id)
            .get();
        let new_count = count + U8::from(1u8);
        self.recovery_approval_count
            .setter(account)
            .setter(request_id)
            .set(new_count);

        self.vm().log(RecoveryApprovalGranted {
            requestId: request_id,
            guardianHash: guardian_hash,
            curve,
        });

        let threshold = self.guardian_threshold_at(account, version);
        if new_count >= threshold {
            let now = U64::from(self.vm().block_timestamp());
            let executable_after = now + U64::from(CHALLENGE_PERIOD_SECONDS);

            self.recovery_status
                .setter(account)
                .setter(request_id)
                .set(U8::from(RECOVERY_STATUS_APPROVED));
            self.recovery_executable_after
                .setter(account)
                .setter(request_id)
                .set(executable_after);

            self.vm().log(RecoveryApproved {
                requestId: request_id,
                executableAfter: executable_after.to::<u64>(),
            });
        }

        Ok(())
    }

    /// @notice Cancels an in-flight recovery request.
    /// @dev    Authorized by any credential currently marked ACTIVE on
    ///         the target account. The digest binds the account's
    ///         current nonce, so a signature produced before any account
    ///         state change cannot be replayed afterwards.
    ///
    ///         Cross-calls into Account are read-only (`static_call`
    ///         semantics): `isCredentialActive` and `getNonce`. They
    ///         cannot reenter Recovery.
    pub fn cancel_recovery(
        &mut self,
        account: Address,
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

        let status = self
            .recovery_status
            .getter(account)
            .getter(request_id)
            .get()
            .to::<u8>();
        if status == RECOVERY_STATUS_NONE {
            return Err(RecoveryNotFound {}.abi_encode());
        }
        if status == RECOVERY_STATUS_EXECUTED
            || status == RECOVERY_STATUS_CANCELLED
            || status == RECOVERY_STATUS_EXPIRED
        {
            return Err(RecoveryAlreadyFinalized {}.abi_encode());
        }

        if self.is_expired(account, request_id) {
            self.mark_expired(account, request_id);
            return Err(RecoveryExpiredErr {}.abi_encode());
        }

        // Cross-call the Account to verify the signer's credential is
        // currently ACTIVE. The credential id is the keccak fingerprint
        // of the raw pubkey.
        let credential_id = keccak(&signer_pubkey.0);
        let account_client = IKipioAccount::new(account);
        let host_view = self.vm();
        let call_ctx = Call::new();

        let is_active = account_client
            .is_credential_active(host_view, call_ctx, credential_id)
            .map_err(|_| CancelNotAuthorized {}.abi_encode())?;
        if !is_active {
            return Err(CancelNotAuthorized {}.abi_encode());
        }

        // Bind the cancellation to the account's current nonce. This
        // prevents a stale signature from being replayed after any state
        // change on the account.
        let account_client = IKipioAccount::new(account);
        let host_view = self.vm();
        let call_ctx = Call::new();
        let current_nonce = account_client
            .get_nonce(host_view, call_ctx)
            .map_err(|_| CancelNotAuthorized {}.abi_encode())?;

        let digest = self.build_recovery_cancel_digest(
            account,
            request_id,
            U64::from(current_nonce),
        );

        if !self.verify_guardian_signature(
            signer_curve,
            digest,
            &signer_signature,
            &signer_pubkey,
        ) {
            return Err(CancelNotAuthorized {}.abi_encode());
        }

        self.recovery_status
            .setter(account)
            .setter(request_id)
            .set(U8::from(RECOVERY_STATUS_CANCELLED));
        self.active_recovery_id.setter(account).set(B256::ZERO);

        self.vm().log(RecoveryCancelled {
            requestId: request_id,
            cancelledBy: self.vm().msg_sender(),
        });

        Ok(())
    }

    /// @notice Consumes an APPROVED recovery request on behalf of the
    ///         account, marking it EXECUTED.
    ///
    /// @dev    This is the **only** entry point on Recovery that is
    ///         gated by `msg_sender() == account` instead of
    ///         `msg_sender() == runtime_address`. The Runtime drives
    ///         the flow via `Account.execute_recovery`, and Account
    ///         cross-calls here. From Recovery's perspective, the caller
    ///         is always the Account whose request is being finalized.
    ///
    ///         The request must:
    ///           - exist,
    ///           - be in APPROVED status,
    ///           - not be past its deadline,
    ///           - have reached `executable_after`,
    ///           - match `effects_hash` against the recorded
    ///             `target_hash`.
    ///
    ///         On success: status transitions to EXECUTED, the active
    ///         request pointer is cleared, and `RecoveryExecuted` is
    ///         emitted with `executedBy = account` (the on-chain actor
    ///         that triggered the state machine's terminal transition).
    pub fn consume_recovery(
        &mut self,
        account: Address,
        request_id: B256,
        effects_hash: B256,
    ) -> Result<(), Vec<u8>> {
        if self.vm().msg_sender() != account {
            return Err(UnauthorizedCaller {}.abi_encode());
        }

        let status = self
            .recovery_status
            .getter(account)
            .getter(request_id)
            .get()
            .to::<u8>();
        if status == RECOVERY_STATUS_NONE {
            return Err(RecoveryNotFound {}.abi_encode());
        }
        if status != RECOVERY_STATUS_APPROVED {
            return Err(RecoveryNotApproved {}.abi_encode());
        }

        if self.is_expired(account, request_id) {
            self.mark_expired(account, request_id);
            return Err(RecoveryExpiredErr {}.abi_encode());
        }

        let now = U64::from(self.vm().block_timestamp());
        let executable_after = self
            .recovery_executable_after
            .getter(account)
            .getter(request_id)
            .get();
        if now < executable_after {
            return Err(RecoveryNotExecutableYet {}.abi_encode());
        }

        let expected_hash = self
            .recovery_target_hash
            .getter(account)
            .getter(request_id)
            .get();
        if effects_hash != expected_hash {
            return Err(SignatureVerificationFailed {}.abi_encode());
        }

        // EFFECTS
        self.recovery_status
            .setter(account)
            .setter(request_id)
            .set(U8::from(RECOVERY_STATUS_EXECUTED));
        self.active_recovery_id.setter(account).set(B256::ZERO);

        // OBSERVABILITY
        self.vm().log(RecoveryExecuted {
            requestId: request_id,
            executedBy: account,
        });

        Ok(())
    }

    // ========================================================================
    // RECOVERY VIEWS
    // ========================================================================

    pub fn get_guardian_version(&self, account: Address) -> U64 {
        self.guardian_versions.getter(account).get()
    }

    /// @notice Returns the guardian set for a given version.
    /// @dev    Reverts if the version does not exist. Caller is
    ///         expected to discover the current version via
    ///         `get_guardian_version` first.
    pub fn get_guardian_set(
        &self,
        account: Address,
        version: U64,
    ) -> Result<(u8, u8, Vec<u8>, Vec<B256>, Vec<u8>), Vec<u8>> {
        if version == U64::ZERO || version > self.guardian_versions.getter(account).get() {
            return Err(GuardiansNotConfigured {}.abi_encode());
        }

        let (count, threshold, _reason) = guardian_meta_unpack(
            self.guardian_meta.getter(account).getter(version).get(),
        );
        let schedule = self.guardian_schedule.getter(account).getter(version).get();
        let schedule_bytes = schedule.as_slice();

        let mut types = Vec::with_capacity(count as usize);
        let mut ids = Vec::with_capacity(count as usize);
        let mut curves = Vec::with_capacity(count as usize);

        for i in 0..count {
            let i_usize = i as usize;
            types.push(schedule_bytes[i_usize]);
            curves.push(schedule_bytes[16 + i_usize]);
            ids.push(
                self.guardian_identifiers
                    .getter(account)
                    .getter(version)
                    .getter(U8::from(i))
                    .get(),
            );
        }

        Ok((count, threshold, types, ids, curves))
    }

    /// @notice Returns the current state of a recovery request.
    /// @dev    Reverts if the request id is unknown for this account.
    pub fn get_recovery_request(
        &self,
        account: Address,
        request_id: B256,
    ) -> Result<(u8, u64, u64, u64, u8, B256, bool), Vec<u8>> {
        let status = self
            .recovery_status
            .getter(account)
            .getter(request_id)
            .get()
            .to::<u8>();
        if status == RECOVERY_STATUS_NONE {
            return Err(RecoveryNotFound {}.abi_encode());
        }

        let version = self
            .recovery_guardian_version
            .getter(account)
            .getter(request_id)
            .get()
            .to::<u64>();
        let deadline = self
            .recovery_deadline
            .getter(account)
            .getter(request_id)
            .get()
            .to::<u64>();
        let executable_after = self
            .recovery_executable_after
            .getter(account)
            .getter(request_id)
            .get()
            .to::<u64>();
        let approvals = self
            .recovery_approval_count
            .getter(account)
            .getter(request_id)
            .get()
            .to::<u8>();
        let target = self
            .recovery_target_hash
            .getter(account)
            .getter(request_id)
            .get();
        let expired = self.is_expired(account, request_id);

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

impl KipioRecovery {
    /// @dev Runtime gate for every mutator except `consume_recovery`.
    ///      Closes the "attacker drives guardian flow directly" vector.
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
        if !self.initialized.get() {
            return Err(NotInitialized {}.abi_encode());
        }
        Ok(())
    }

    // --------------------------------------------------------------------
    // GUARDIAN CONFIGURATION WRITER
    // --------------------------------------------------------------------

    /// @dev Validates and persists a guardian version. Fails fast on any
    ///      structural invariant violation BEFORE writing a single slot,
    ///      so a malformed set leaves no partial state behind.
    fn write_guardian_version(
        &mut self,
        account: Address,
        version: U64,
        guardian_types: &[u8],
        guardian_identifiers: &[B256],
        guardian_curves: &[u8],
        threshold: u8,
        update_reason: u8,
    ) -> Result<(), Vec<u8>> {
        let count = guardian_types.len();

        if count == 0 {
            return Err(InvalidGuardianCount {}.abi_encode());
        }
        if count > MAX_GUARDIANS {
            return Err(MaxGuardiansExceeded {}.abi_encode());
        }
        if guardian_identifiers.len() != count || guardian_curves.len() != count {
            return Err(InvalidGuardianCount {}.abi_encode());
        }
        if threshold == 0 || threshold > count as u8 {
            return Err(InvalidThreshold {}.abi_encode());
        }

        // Duplicate detection is O(N^2) but bounded by MAX_GUARDIANS.
        // For N = 16, this is 120 comparisons, negligible in wasm.
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

        // Effects: write N identifiers + 1 schedule + 1 meta.
        for i in 0..count {
            self.guardian_identifiers
                .setter(account)
                .setter(version)
                .setter(U8::from(i as u8))
                .set(guardian_identifiers[i]);
        }

        self.guardian_schedule
            .setter(account)
            .setter(version)
            .set(guardian_schedule_pack(guardian_types, guardian_curves));

        self.guardian_meta
            .setter(account)
            .setter(version)
            .set(guardian_meta_pack(count as u8, threshold, update_reason));

        Ok(())
    }

    #[inline]
    fn guardian_count_at(&self, account: Address, version: U64) -> u8 {
        guardian_meta_unpack(self.guardian_meta.getter(account).getter(version).get()).0
    }

    #[inline]
    fn guardian_threshold_at(&self, account: Address, version: U64) -> u8 {
        guardian_meta_unpack(self.guardian_meta.getter(account).getter(version).get()).1
    }

    #[inline]
    fn guardian_curve_at(&self, account: Address, version: U64, idx: u8) -> u8 {
        let schedule = self.guardian_schedule.getter(account).getter(version).get();
        schedule.as_slice()[16 + idx as usize]
    }

    /// @dev Linear scan over the guardian identifiers of a version.
    ///      With N <= MAX_GUARDIANS (16), this is bounded and cheap; the
    ///      storage cost saved by not maintaining a reverse index
    ///      outweighs the compute cost.
    fn find_guardian_index(
        &self,
        account: Address,
        version: U64,
        hash: B256,
    ) -> Option<u8> {
        let count = self.guardian_count_at(account, version);
        // Bind intermediates so the temporary storage handles outlive
        // the loop that borrows them.
        let ids_account_map = self.guardian_identifiers.getter(account);
        let ids_version_map = ids_account_map.getter(version);
        for i in 0..count {
            if ids_version_map.getter(U8::from(i)).get() == hash {
                return Some(i);
            }
        }
        None
    }

    // --------------------------------------------------------------------
    // RECOVERY HELPERS
    // --------------------------------------------------------------------

    #[inline]
    fn is_expired(&self, account: Address, request_id: B256) -> bool {
        let deadline = self
            .recovery_deadline
            .getter(account)
            .getter(request_id)
            .get();
        let now = U64::from(self.vm().block_timestamp());
        now > deadline
    }

    /// @dev Terminal transition for a request that crossed its deadline.
    ///      Idempotent: calling it on a non-active request is a no-op at
    ///      the state level (the write is redundant) but still emits the
    ///      event, which is fine for observability.
    fn mark_expired(&mut self, account: Address, request_id: B256) {
        self.recovery_status
            .setter(account)
            .setter(request_id)
            .set(U8::from(RECOVERY_STATUS_EXPIRED));
        if self.active_recovery_id.getter(account).get() == request_id {
            self.active_recovery_id.setter(account).set(B256::ZERO);
        }
        self.vm().log(RecoveryExpired {
            requestId: request_id,
        });
    }

    /// @dev Rejects new recovery requests while a previous one is
    ///      in-flight. Auto-expires a stale in-flight request instead of
    ///      blocking indefinitely.
    fn ensure_no_active_recovery(&mut self, account: Address) -> Result<(), Vec<u8>> {
        let current = self.active_recovery_id.getter(account).get();
        if current == B256::ZERO {
            return Ok(());
        }

        let status = self
            .recovery_status
            .getter(account)
            .getter(current)
            .get()
            .to::<u8>();

        if status == RECOVERY_STATUS_ACTIVE || status == RECOVERY_STATUS_APPROVED {
            if self.is_expired(account, current) {
                self.mark_expired(account, current);
                return Ok(());
            }
            return Err(ActiveRecoveryExists {}.abi_encode());
        }

        self.active_recovery_id.setter(account).set(B256::ZERO);
        Ok(())
    }

    #[inline]
    fn u64_to_be32(v: u64) -> [u8; 32] {
        let mut out = [0u8; 32];
        out[24..32].copy_from_slice(&v.to_be_bytes());
        out
    }

    /// @dev EIP-712-like digest for guardian approvals. Binds the chain
    ///      id, the account, the request id and the target hash. A
    ///      signature produced for one request cannot be reused for
    ///      another.
    fn build_recovery_approval_digest(
        &self,
        account: Address,
        request_id: B256,
        target_hash: B256,
    ) -> B256 {
        let chain_id = Self::u64_to_be32(self.vm().chain_id());
        let mut preimage = Vec::with_capacity(96 + 32 + 32);
        preimage.extend_from_slice(APPROVE_DOMAIN);
        preimage.extend_from_slice(&chain_id);
        preimage.extend_from_slice(account.as_slice());
        preimage.extend_from_slice(request_id.as_slice());
        preimage.extend_from_slice(target_hash.as_slice());
        keccak(&preimage)
    }

    /// @dev Cancellation digest. Binds the account's current nonce, so
    ///      a signature produced before any account state change cannot
    ///      be replayed.
    fn build_recovery_cancel_digest(
        &self,
        account: Address,
        request_id: B256,
        nonce: U64,
    ) -> B256 {
        let chain_id = Self::u64_to_be32(self.vm().chain_id());
        let nonce_bytes = Self::u64_to_be32(nonce.to::<u64>());
        let mut preimage = Vec::with_capacity(96 + 32 + 32);
        preimage.extend_from_slice(CANCEL_DOMAIN);
        preimage.extend_from_slice(&chain_id);
        preimage.extend_from_slice(account.as_slice());
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

    /// @dev EIP-7951 P256 verification via the ArbOS native precompile.
    ///      No WASM crypto; only raw calldata forwarding.
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

    /// @dev secp256k1 EOA verification via the `ecrecover` precompile.
    ///      Recovers the signer address and compares it to the address
    ///      derived from the uncompressed pubkey.
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
}

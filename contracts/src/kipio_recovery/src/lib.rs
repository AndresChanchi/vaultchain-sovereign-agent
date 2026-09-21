#![allow(unexpected_cfgs)]
#![cfg_attr(not(feature = "std"), no_std)]

extern crate alloc;

use alloc::{vec, vec::Vec};

use stylus_sdk::{
    alloy_primitives::{Address, B256, U256},
    prelude::*,
    storage::{
        StorageAddress,
        StorageB256,
        StorageBool,
        StorageMap,
        StorageU256,
    },
};

stylus_sdk::alloy_sol_types::sol! {
    event GuardiansConfigured(address indexed user, uint256 version, uint256 count, uint256 threshold);
    event GuardiansUpdated(address indexed user, uint256 version, uint256 count, uint256 threshold, uint256 reason);
    event PolicyRequestStarted(address indexed user, bytes32 indexed requestId, bytes32 policyType, uint256 guardianVersion);
    event PolicyApprovalGranted(bytes32 indexed requestId, bytes32 indexed guardianHash);
    event PolicyApproved(bytes32 indexed requestId);
    event PolicyCancelled(bytes32 indexed requestId);
    event PolicyConsumed(bytes32 indexed requestId, address indexed consumer);
    event PolicyExpired(bytes32 indexed requestId);
    event ConsumerAuthorizationUpdated(address indexed consumer, bool authorized);
}

/// ------------------------------------------------------------------------
/// KIPIO RECOVERY & POLICY ENGINE
/// ------------------------------------------------------------------------
///
/// PURPOSE:
/// Recovery is responsible for defining and evaluating governance policies
/// when primary identity credentials are lost or require extraordinary mutation.
///
/// - It does NOT authenticate users directly.
/// - It does NOT execute changes inside Auth or any other module.
/// - It does NOT validate physical ownership of Emails, Phones, or Passkeys.
/// - It does NOT know real-world identifiers. It only stores hashes and
///   semantic types. Computing `hash(identifier + salt)` is strictly a
///   FRONTEND responsibility, performed before any value reaches this
///   contract. Recovery never sees a raw email, phone number, passkey, or
///   wallet — only the commitment.
///
/// It acts strictly as an oracle of human/social consensus. It answers:
/// "Was this policy satisfied by the required threshold of authorized guardians?"
///
/// If satisfied, the policy transitions to APPROVED, exposing a stable interface
/// for an authorized downstream module (like Auth) to consume and execute.
///
/// GUARDIAN VERSIONING & HISTORICAL IMMUTABILITY:
/// Versions belong exclusively to the Guardian Set. They never belong to a
/// Recovery Request or to the Policy history. A Recovery Request only ever
/// captures a `guardian_version` reference: a pointer to whichever Guardian
/// Set was active the moment the request was created.
///
/// Guardian configurations are holistically versioned (types, identifiers,
/// counts, thresholds). Old guardian configurations are INTENTIONALLY NEVER
/// DELETED, and NEVER OVERWRITTEN. They form part of the immutable auditable
/// history of the protocol — both for the Guardian Set itself and for every
/// Policy Request that snapshotted it. This is what lets an auditor or block
/// explorer reconstruct, at any point in time, exactly which guardians were
/// entitled to vote on any historical request.
///
/// FRONTEND vs CONTRACT RESPONSIBILITY:
/// The contract exposes a single mutation entrypoint for guardian state:
/// `update_guardians(...)`. The frontend is free to offer higher-level,
/// user-facing actions on top of it — e.g. "Add Guardian", "Remove Guardian",
/// "Replace Compromised Guardian", "Change Threshold". Every one of those
/// UI-level actions ultimately calls `update_guardians(...)` and produces a
/// new Guardian Set version. The contract has no notion of these UI actions;
/// it only persists the resulting state transition, tagged with a
/// `GuardianUpdateReason` purely for audit traceability (see below).
/// ------------------------------------------------------------------------
#[storage]
#[entrypoint]
pub struct KipioRecovery {
    /// @notice Contract administrator managing authorized policy consumers.
    pub owner: StorageAddress,

    /// @notice Whitelist of downstream contracts (e.g., KipioAuth) allowed to consume APPROVED policies.
    pub authorized_consumers: StorageMap<Address, StorageBool>,

    // ==========================================
    // GUARDIAN CONFIGURATION STATE (VERSIONED SETS)
    // ==========================================

    /// @notice Monotonic version tracker for a user's guardian configuration.
    /// @dev Versions belong to the Guardian Set only. Never reused, never
    /// reassigned to a Policy Request or any other entity.
    pub guardian_versions: StorageMap<Address, StorageU256>,

    /// @notice Number of approvals required to satisfy recovery per version snapshot.
    pub guardian_thresholds: StorageMap<Address, StorageMap<U256, StorageU256>>,

    /// @notice Total number of guardians configured per user per version snapshot.
    pub guardian_counts: StorageMap<Address, StorageMap<U256, StorageU256>>,

    /// @notice guardian_types[user][version][index] -> Semantic types (1 = EVM, 2 = Passkey, etc.)
    pub guardian_types: StorageMap<Address, StorageMap<U256, StorageMap<U256, StorageU256>>>,

    /// @notice guardian_identifiers[user][version][index] -> Pre-hashed tracking metadata.
    /// @dev The frontend is responsible for computing `hash(identifier + salt)`
    /// before submission. The contract treats these strictly as opaque commitments.
    pub guardian_identifiers: StorageMap<Address, StorageMap<U256, StorageMap<U256, StorageB256>>>,

    /// @notice guardian_validations[user][version][guardian_hash] -> (index + 1)
    /// @dev Doubles as both an O(1) membership check and a within-set duplicate
    /// guard during configuration (see `assert_no_duplicate_guardians`).
    pub guardian_validations: StorageMap<Address, StorageMap<U256, StorageMap<B256, StorageU256>>>,

    /// @notice guardian_update_reasons[user][version] -> intent tag describing why
    /// this version was created (ADD_GUARDIAN, REMOVE_GUARDIAN, etc).
    /// @dev Pure audit metadata. The contract applies identical logic regardless
    /// of the reason; this field carries zero behavioral weight. Version 1
    /// (created via `set_guardians`) has no reason — it is the genesis state.
    pub guardian_update_reasons: StorageMap<Address, StorageMap<U256, StorageU256>>,

    // ==========================================
    // POLICY REQUEST STATE (THE LEDGER)
    // ==========================================

    /// @notice Internal monotonic sequence tracking global operations. Cast to B256 for public IDs.
    pub next_request_id: StorageU256,

    /// @notice Enforces a strict one-active-request-per-user limit to prevent race conditions.
    pub active_request_by_user: StorageMap<Address, StorageB256>,

    /// @notice Request owner identity lookup.
    pub request_users: StorageMap<B256, StorageAddress>,

    /// @notice Semantic discriminator defining the intent of the policy (e.g., ROTATE_KEY).
    pub request_policy_types: StorageMap<B256, StorageB256>,

    /// @notice Requested structural payload hash (e.g., hash of the new public key).
    pub request_target_hashes: StorageMap<B256, StorageB256>,

    /// @notice Requested auxiliary numerical parameter (e.g., curve identifier).
    pub request_curves: StorageMap<B256, StorageU256>,

    /// @notice Request absolute expiration block timestamp threshold (inclusive — see `enforce_expiration`).
    pub request_deadlines: StorageMap<B256, StorageU256>,

    /// @notice Snapshot reference tying the request to a specific historical Guardian Set version.
    /// @dev This is the ONLY place a version number is ever recorded outside of
    /// the Guardian Set itself, and it is a reference, not a new version.
    pub request_guardian_versions: StorageMap<B256, StorageU256>,

    /// @notice Current active approved vote counter for a specific request.
    pub request_approval_counts: StorageMap<B256, StorageU256>,

    /// @notice Request lifecycle state matrix tracking active status flags.
    /// @dev 0 = NONE, 1 = ACTIVE, 2 = CANCELLED, 3 = APPROVED, 4 = CONSUMED, 5 = EXPIRED
    pub request_statuses: StorageMap<B256, StorageU256>,

    /// @notice approvals[request_id][guardian_hash] -> tracks structural double-voting prevention.
    pub approvals: StorageMap<B256, StorageMap<B256, StorageU256>>,
}

// Guardian sets are expected to remain small.
// Large sets may become economically inefficient.
// Global Definitive Boundaries
const GUARDIAN_EVM: u64 = 1;
const GUARDIAN_ORGANIZATION: u64 = 7;

// Lifecycle States
const REQUEST_NONE: u64 = 0;
const REQUEST_ACTIVE: u64 = 1;
const REQUEST_CANCELLED: u64 = 2;
const REQUEST_APPROVED: u64 = 3;
const REQUEST_CONSUMED: u64 = 4;
const REQUEST_EXPIRED: u64 = 5;

/// @notice Audit-only intent tags for `update_guardians`. The contract applies
/// IDENTICAL logic for every reason — this enum carries no behavioral branching,
/// only traceability. It lets an external observer reconstruct the guardian
/// history as a readable sequence, e.g.:
///
///   Guardian Set v1 --ADD_GUARDIAN--> v2 --COMPROMISED_GUARDIAN--> v3 --CHANGE_THRESHOLD--> v4
///
/// Genesis configuration (`set_guardians`, always version 1) has no reason and
/// is not represented here; it is implicitly "initial configuration".
#[repr(u64)]
#[derive(Clone, Copy, PartialEq, Eq)]
pub enum GuardianUpdateReason {
    AddGuardian = 1,
    RemoveGuardian = 2,
    ReplaceGuardian = 3,
    ChangeThreshold = 4,
    CompromisedGuardian = 5,
    Custom = 6,
}

impl GuardianUpdateReason {
    fn from_u256(value: U256) -> Result<Self, Vec<u8>> {
        match value.as_limbs()[0] {
            1 => Ok(Self::AddGuardian),
            2 => Ok(Self::RemoveGuardian),
            3 => Ok(Self::ReplaceGuardian),
            4 => Ok(Self::ChangeThreshold),
            5 => Ok(Self::CompromisedGuardian),
            6 => Ok(Self::Custom),
            _ => Err(b"InvalidUpdateReason".to_vec()),
        }
    }

    fn as_u256(self) -> U256 {
        U256::from(self as u64)
    }
}

// Standardized Semantic Policy Types
const POLICY_TYPE_ROTATE_KEY: [u8; 32] = [
    0x3b, 0x1a, 0x47, 0x13, 0x44, 0x86, 0x01, 0x7b, 
    0xbf, 0x83, 0x98, 0x49, 0x48, 0x22, 0xc1, 0x8b, 
    0x2c, 0xa1, 0x76, 0x1a, 0x03, 0x45, 0xda, 0x6a, 
    0x95, 0x41, 0xe1, 0x49, 0x40, 0x7e, 0x06, 0x0f
]; // keccak256("ROTATE_KEY")

impl KipioRecovery {
    fn require_owner(&self) -> Result<(), Vec<u8>> {
        let owner = self.owner.get();
        if owner == Address::ZERO || self.vm().msg_sender() != owner {
            return Err(b"Unauthorized".to_vec());
        }
        Ok(())
    }

    /// @dev Centralized expiration logic. Evaluates deadline and transitions state if breached.
    /// Returns true if the request was marked as expired during this call.
    ///
    /// EXPIRATION SEMANTICS: a request is expired only when `now > deadline`,
    /// i.e. `deadline` is treated as an INCLUSIVE upper bound — the request is
    /// still valid during the exact second/block matching the deadline. This
    /// mirrors the check already performed at creation time in `start_recovery`
    /// (`now > deadline` rejects a deadline that has already strictly passed).
    /// Using `>` everywhere (instead of `>=`) avoids penalizing a guardian who
    /// approves in the very same block as the deadline, with no security
    /// downside, and keeps a single consistent rule across the whole contract.
    fn enforce_expiration(&mut self, request_id: B256) -> bool {
        let deadline = self.request_deadlines.getter(request_id).get();
        let now = U256::from(self.vm().block_timestamp());
        
        if now > deadline {
            self.request_statuses.setter(request_id).set(U256::from(REQUEST_EXPIRED));
            
            let user = self.request_users.getter(request_id).get();
            let current_active = self.active_request_by_user.getter(user).get();
            if current_active == request_id {
                self.active_request_by_user.setter(user).set(B256::ZERO);
            }
            
            self.vm().log(PolicyExpired { requestId: request_id });
            return true;
        }
        false
    }

    /// @dev Resolves pending blockages. Reverts if an unexpired ACTIVE/APPROVED request exists.
    fn ensure_no_active_blocks(&mut self, user: Address) -> Result<(), Vec<u8>> {
        let current_active = self.active_request_by_user.getter(user).get();
        if current_active != B256::ZERO {
            let status = self.request_statuses.getter(current_active).get().as_limbs()[0];
            
            if status == REQUEST_ACTIVE || status == REQUEST_APPROVED {
                if !self.enforce_expiration(current_active) {
                    return Err(b"ActiveRequestExists".to_vec());
                }
            } else {
                // Failsafe clearing if the slot wasn't zeroed out properly.
                self.active_request_by_user.setter(user).set(B256::ZERO);
            }
        }
        Ok(())
    }

    /// @dev Guarantees a Guardian Set can never contain the same guardian hash
    /// twice. This is enforced on-chain — never trusted to the frontend — because
    /// a duplicated guardian would silently inflate approval counting (the same
    /// person could occupy two "votes" worth of threshold weight) and would also
    /// corrupt the `guardian_validations` index, which assumes a 1:1 mapping
    /// between identifier and slot.
    fn assert_no_duplicate_guardians(identifiers: &[B256]) -> Result<(), Vec<u8>> {
        for i in 0..identifiers.len() {
            for j in (i + 1)..identifiers.len() {
                if identifiers[i] == identifiers[j] {
                    return Err(b"DuplicateGuardian".to_vec());
                }
            }
        }
        Ok(())
    }

    /// @dev Shared validation + storage routine for both genesis configuration
    /// and subsequent updates. Centralizing this keeps `set_guardians` and
    /// `update_guardians` byte-for-byte consistent and removes duplicated logic.
    fn write_guardian_version(
        &mut self,
        user: Address,
        version: U256,
        guardian_types: &[U256],
        guardian_identifiers: &[B256],
        threshold: U256,
    ) -> Result<(), Vec<u8>> {
        if guardian_types.is_empty() { return Err(b"NoGuardians".to_vec()); }
        if guardian_types.len() != guardian_identifiers.len() { return Err(b"GuardianLengthMismatch".to_vec()); }

        let count = guardian_types.len();
        if threshold == U256::ZERO || threshold > U256::from(count) {
            return Err(b"InvalidThreshold".to_vec());
        }

        Self::assert_no_duplicate_guardians(guardian_identifiers)?;

        for i in 0..count {
            let g_type = guardian_types[i];
            if g_type.as_limbs()[0] < GUARDIAN_EVM || g_type.as_limbs()[0] > GUARDIAN_ORGANIZATION {
                return Err(b"InvalidGuardianType".to_vec());
            }

            let identifier = guardian_identifiers[i];
            self.guardian_types.setter(user).setter(version).setter(U256::from(i)).set(g_type);
            self.guardian_identifiers.setter(user).setter(version).setter(U256::from(i)).set(identifier);
            self.guardian_validations.setter(user).setter(version).setter(identifier).set(U256::from(i + 1));
        }

        self.guardian_counts.setter(user).setter(version).set(U256::from(count));
        self.guardian_thresholds.setter(user).setter(version).set(threshold);
        self.guardian_versions.setter(user).set(version);

        Ok(())
    }
}

#[public]
impl KipioRecovery {
    /// @notice Initializes contract administration to manage consumer whitelists.
    pub fn initialize(&mut self, initial_owner: Address) -> Result<(), Vec<u8>> {
        if self.owner.get() != Address::ZERO {
            return Err(b"AlreadyInitialized".to_vec());
        }
        self.owner.set(initial_owner);
        self.next_request_id.set(U256::from(1));
        Ok(())
    }

    /// @notice Grants or revokes execution clearance for downstream contracts to consume policies.
    pub fn set_authorized_consumer(&mut self, consumer: Address, authorized: bool) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        self.authorized_consumers.setter(consumer).set(authorized);
        self.vm().log(ConsumerAuthorizationUpdated { consumer, authorized });
        Ok(())
    }

    /// @notice Configure guardians for the first time. Sets user guardian version to 1.
    /// @dev Genesis version. Carries no `GuardianUpdateReason` — it is the
    /// implicit "initial configuration" state, not a transition from a prior set.
    pub fn set_guardians(
        &mut self,
        guardian_types: Vec<U256>,
        guardian_identifiers: Vec<B256>,
        threshold: U256,
    ) -> Result<(), Vec<u8>> {
        let user = self.vm().msg_sender();

        if self.guardian_versions.getter(user).get() != U256::ZERO { 
            return Err(b"GuardiansAlreadyConfigured".to_vec()); 
        }

        let version = U256::from(1);
        let count = guardian_types.len();
        let threshold_copy = threshold;

        self.write_guardian_version(user, version, &guardian_types, &guardian_identifiers, threshold)?;

        self.vm().log(GuardiansConfigured { user, version, count: U256::from(count), threshold: threshold_copy });
        Ok(())
    }

    /// @notice Safely modifies guardian configurations via versioning.
    /// @dev Blocked entirely if an active or approved policy request is currently alive.
    /// Validates and isolates the new configuration under a monotonically increasing version index.
    ///
    /// `reason` carries no behavioral weight — every reason follows the exact
    /// same validation and storage path via `write_guardian_version`. It exists
    /// solely so the resulting `GuardiansUpdated` event lets an auditor or block
    /// explorer reconstruct *why* each version transition happened (e.g. a guardian
    /// was added, removed, replaced for being compromised, or the threshold changed).
    ///
    /// This is the single entrypoint for all guardian mutations. Higher-level
    /// frontend actions (Add/Remove/Replace Guardian, Change Threshold) all
    /// resolve to a call here with the appropriate `reason` — the contract does
    /// not need, and intentionally does not have, separate entrypoints for them.
    pub fn update_guardians(
        &mut self,
        guardian_types: Vec<U256>,
        guardian_identifiers: Vec<B256>,
        threshold: U256,
        reason: U256,
    ) -> Result<(), Vec<u8>> {
        let user = self.vm().msg_sender();
        let parsed_reason = GuardianUpdateReason::from_u256(reason)?;

        // Structural check: Ensure no live requests block the mutation
        self.ensure_no_active_blocks(user)?;

        let current_version = self.guardian_versions.getter(user).get();
        if current_version == U256::ZERO { return Err(b"GuardiansNotConfigured".to_vec()); }

        let new_version = current_version + U256::from(1);
        let count = guardian_types.len();
        let threshold_copy = threshold;

        self.write_guardian_version(user, new_version, &guardian_types, &guardian_identifiers, threshold)?;

        self.guardian_update_reasons.setter(user).setter(new_version).set(parsed_reason.as_u256());

        self.vm().log(GuardiansUpdated {
            user,
            version: new_version,
            count: U256::from(count),
            threshold: threshold_copy,
            reason: parsed_reason.as_u256(),
        });
        Ok(())
    }

    /// @notice Initializes an atomic policy consensus sequence.
    /// @dev Binds the request to the `ROTATE_KEY` semantic type and captures a reference to the active Guardian Set.
    pub fn start_recovery(
        &mut self,
        target_hash: B256,
        target_curve: U256,
        deadline: U256,
    ) -> Result<B256, Vec<u8>> {
        let user = self.vm().msg_sender();
        let now = U256::from(self.vm().block_timestamp());
        
        if now > deadline { return Err(b"ExpiredDeadline".to_vec()); }

        // Block if a request is already running
        self.ensure_no_active_blocks(user)?;

        let current_version = self.guardian_versions.getter(user).get();
        if current_version == U256::ZERO { return Err(b"NoGuardiansConfigured".to_vec()); }

        let internal_id = self.next_request_id.get();
        let request_id = B256::from(internal_id);
        self.next_request_id.set(internal_id + U256::from(1));

        let policy_type = B256::from_slice(&POLICY_TYPE_ROTATE_KEY);

        self.request_users.setter(request_id).set(user);
        self.request_policy_types.setter(request_id).set(policy_type);
        self.request_target_hashes.setter(request_id).set(target_hash);
        self.request_curves.setter(request_id).set(target_curve);
        self.request_deadlines.setter(request_id).set(deadline);
        self.request_statuses.setter(request_id).set(U256::from(REQUEST_ACTIVE));
        self.request_approval_counts.setter(request_id).set(U256::ZERO);
        
        // SNAPSHOT: Bind the active guardian version reference to this exact request.
        // This is a reference only — `request_guardian_versions` never creates,
        // mutates, or owns a version. The version still belongs solely to the
        // Guardian Set.
        self.request_guardian_versions.setter(request_id).set(current_version);
        
        self.active_request_by_user.setter(user).set(request_id);

        self.vm().log(PolicyRequestStarted { user, requestId: request_id, policyType: policy_type, guardianVersion: current_version });
        Ok(request_id)
    }

    /// @notice Registers consensus votes using O(1) version-isolated validation matrices.
    pub fn approve_recovery(
        &mut self,
        request_id: B256,
        guardian_identifier: B256,
    ) -> Result<(), Vec<u8>> {
        let status = self.request_statuses.getter(request_id).get().as_limbs()[0];
        if status == REQUEST_NONE { return Err(b"RequestNotFound".to_vec()); }
        if status != REQUEST_ACTIVE { return Err(b"RequestNotActive".to_vec()); }

        if self.enforce_expiration(request_id) {
            return Err(b"RequestExpired".to_vec());
        }

        let user = self.request_users.getter(request_id).get();
        let request_version = self.request_guardian_versions.getter(request_id).get();
        
        // O(1) Lookup: Validate guardian legitimacy strictly inside the snapshotted version matrix
        let validation_index = self.guardian_validations.getter(user).getter(request_version).getter(guardian_identifier).get();
        if validation_index == U256::ZERO { return Err(b"UnknownGuardian".to_vec()); }

        let already = self.approvals.getter(request_id).getter(guardian_identifier).get();
        if already != U256::ZERO { return Err(b"AlreadyApproved".to_vec()); }

        self.approvals.setter(request_id).setter(guardian_identifier).set(U256::from(1));

        let approvals = self.request_approval_counts.getter(request_id).get();
        let new_count = approvals + U256::from(1);
        self.request_approval_counts.setter(request_id).set(new_count);

        self.vm().log(PolicyApprovalGranted { requestId: request_id, guardianHash: guardian_identifier });

        // Retrieve historical threshold matching the snapshotted guardian set version
        let target_threshold = self.guardian_thresholds.getter(user).getter(request_version).get();
        if new_count >= target_threshold {
            self.request_statuses.setter(request_id).set(U256::from(REQUEST_APPROVED));
            self.vm().log(PolicyApproved { requestId: request_id });
        }

        Ok(())
    }

    /// @notice Cancels an active structural procedure and frees the single-active slot.
    pub fn cancel_recovery(&mut self, request_id: B256) -> Result<(), Vec<u8>> {
        let status = self.request_statuses.getter(request_id).get().as_limbs()[0];
        if status == REQUEST_NONE { return Err(b"RequestNotFound".to_vec()); }

        let user = self.request_users.getter(request_id).get();
        if self.vm().msg_sender() != user { return Err(b"Unauthorized".to_vec()); }

        if status != REQUEST_ACTIVE { return Err(b"RequestNotActive".to_vec()); }

        self.request_statuses.setter(request_id).set(U256::from(REQUEST_CANCELLED));
        self.active_request_by_user.setter(user).set(B256::ZERO);

        self.vm().log(PolicyCancelled { requestId: request_id });
        Ok(())
    }

    /// =======================================================================
    /// STANDARDIZED EXTERNAL CONSUMPTION INTERFACE
    /// =======================================================================

    /// @notice The definitive stable view of the Policy Ledger exposed to downstream consumers.
    /// @dev Auth or other modules depend entirely on this semantic structural layout, 
    /// completely decoupled from the internal guardian bookkeeping.
    pub fn get_policy_record(
        &self,
        request_id: B256,
    ) -> Result<(U256, B256, Address, B256, U256, U256), Vec<u8>> {
        let status = self.request_statuses.getter(request_id).get();
        if status == U256::from(REQUEST_NONE) {
            return Err(b"RequestNotFound".to_vec());
        }

        let policy_type = self.request_policy_types.getter(request_id).get();
        let user = self.request_users.getter(request_id).get();
        let target_hash = self.request_target_hashes.getter(request_id).get();
        let curve = self.request_curves.getter(request_id).get();
        let deadline = self.request_deadlines.getter(request_id).get();

        Ok((status, policy_type, user, target_hash, curve, deadline))
    }

    /// @notice Consumes the approved policy, advancing its state to prevent replay attacks.
    /// @dev Rejects execution if the policy's deadline has been breached.
    pub fn consume_policy(&mut self, request_id: B256) -> Result<(), Vec<u8>> {
        let caller = self.vm().msg_sender();
        
        if !self.authorized_consumers.getter(caller).get() {
            return Err(b"UnauthorizedConsumer".to_vec());
        }

        let status = self.request_statuses.getter(request_id).get().as_limbs()[0];
        if status == REQUEST_NONE { return Err(b"RequestNotFound".to_vec()); }
        if status != REQUEST_APPROVED { return Err(b"PolicyNotApproved".to_vec()); }

        if self.enforce_expiration(request_id) {
            return Err(b"PolicyExpired".to_vec());
        }

        self.request_statuses.setter(request_id).set(U256::from(REQUEST_CONSUMED));
        
        let user = self.request_users.getter(request_id).get();
        self.active_request_by_user.setter(user).set(B256::ZERO);

        self.vm().log(PolicyConsumed { requestId: request_id, consumer: caller });
        Ok(())
    }
}

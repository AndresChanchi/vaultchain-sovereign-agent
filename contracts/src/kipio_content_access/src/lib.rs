#![allow(unexpected_cfgs)]
#![cfg_attr(not(feature = "std"), no_std)]
extern crate alloc;

use alloc::{vec, vec::Vec};

use stylus_sdk::{
    alloy_primitives::{Address, B256, U256, Bytes, FixedBytes},
    alloy_sol_types::{sol, SolError},
    crypto::keccak,
    prelude::*,
    storage::{
        StorageAddress, StorageB256, StorageBool, StorageMap, StorageU256, StorageVec,
    },
};

// ============================================================================
// PROVIDER ABSTRACTION BOUNDARY
// ============================================================================
//
// Kipio depends on interfaces, not implementations.
//
//   StorageProvider → Irys today; Arweave, Filecoin, IPFS tomorrow.
//   QueryProvider   → SXT via CRE today; alternative indexers tomorrow.
//   AccessProvider  → Lit Protocol today; TACo (WEDF) tomorrow.
//   ZKVerifier      → UltraHonk/Groth16/halo2 (optional, future).
//
// Each provider is replaceable without modifying protocol logic.
// The contract stores provider addresses and resolves them dynamically.
// It never hard-codes a vendor.
//
// Design principle: depend on the interface, not the implementation.
//
// ============================================================================
// CALLER MODEL
// ============================================================================
//
// This contract is intentionally decoupled. Any address can be the caller:
//
//   - A standard EOA (crypto-native user) calling directly.
//   - `kipio_account` (sovereign smart account) pushing via its own runtime.
//   - `kipio_runtime` orchestrating on behalf of a non-crypto user.
//   - Any future adapter that implements the same interface.
//
// The contract does NOT enforce an operator model, an approval scheme,
// or a signature scheme. It trusts `msg_sender()` as the vault owner.
// Authorization (who may call on whose behalf) belongs to the caller
// layer, not to this bounded context.
//
// ============================================================================
// OWNERSHIP SEMANTICS (PROTOCOL GOVERNANCE vs USER SOVEREIGNTY)
// ============================================================================
//
// IMPORTANT: There are TWO distinct "ownership" concepts in this system:
//
//   1. PROTOCOL GOVERNANCE (this contract's `owner` field):
//      - Sets provider addresses (storage, query, access, zk).
//      - Sets expected CRE workflow ID.
//      - Pauses/unpauses content-side mutators (see CIRCUIT BREAKER).
//      - Can be transferred via `transfer_ownership` (two-step).
//      - Intended to migrate to a Multisig → Timelock → DAO.
//      - This is INFRASTRUCTURE governance, NOT user data.
//
//   2. USER SOVEREIGNTY (implicit via `msg_sender`):
//      - Each caller owns their own vault (`vaults[msg_sender]`).
//      - No contract-level "user ownership" exists.
//      - For EOA users: `msg_sender` is the EOA itself.
//      - For smart-account users: `msg_sender` is the `kipio_account`
//        instance, whose credential model (Dafny-verified) determines
//        who can authorize calls on behalf of the identity.
//
// These roles are SEPARATE. `transfer_ownership` moves protocol
// governance, not user vaults. User vaults move implicitly when
// `kipio_account`'s credentials are rotated (external to this contract).
//
// ============================================================================
// PROVIDER SELECTION IS USER SOVEREIGN
// ============================================================================
//
// This contract stores a single `storage_provider` adapter address, but
// `provider_id` per content is chosen by the USER. The contract NEVER
// decides providers automatically. The user selects:
//
//   provider_id = 0  → Irys
//   provider_id = 1  → IPFS
//   provider_id = 2  → Filecoin
//   provider_id = 3  → Arweave
//
// No automatic fallback, no vendor lock-in, no protocol-side override.
// The frontend is responsible for presenting options and costs to the
// user in an accessible way. The contract enforces only that the chosen
// provider_id is in the supported set.
//
// ============================================================================
// IRYS STORAGE TERMS (Cascade upgrade, August 2026)
// ============================================================================
//
// Irys supports three predefined storage terms, plus a custom escape hatch:
//
//   storage_term = 0  → PERMANENT   (Publish Ledger, highest cost)
//   storage_term = 1  → 30_DAYS     (Term Ledger, lowest cost)
//   storage_term = 2  → 1_YEAR      (Term Ledger, medium cost)
//   storage_term = 3  → CUSTOM      (Term Ledger, user-defined duration)
//
// The `expiry_delta` field stores the number of SECONDS from `created_at`
// until the content expires. It is packed into bytes [28..32) of the
// `packed` U256, preserving the 1-slot-per-content optimization.
//
//   Permanent:  expiry_delta = 0 (no expiry)
//   30 days:    expiry_delta = 2_592_000
//   1 year:     expiry_delta = 31_536_000
//   Custom:     expiry_delta = user-specified
//
// The ABSOLUTE expiry is computed as: `created_at + expiry_delta`.
//
// TERM EXTENSION:
//   Irys allows extending a term ledger before it expires. The user pays
//   only for the extension. `extend_storage_term` records the new term
//   on-chain. Downgrades are rejected: the new absolute delta must be
//   greater than or equal to the old delta.
//
// WHAT HAPPENS WHEN CONTENT EXPIRES:
//   On Irys side, the data is garbage-collected after expiry. On the
//   contract side, the record remains. The frontend is responsible for:
//     1. Calling `get_expiry_status` to detect expiry.
//     2. Hiding/blocking access to the dead txID.
//     3. Optionally calling `delete_content` to clean up (idempotent).
//   The events (`ContentRegistered`, `ContentDeleted`) preserve the
//   historical record for off-chain indexers. No on-chain tombstone
//   is needed because events are the outbox.
//
// MUTABLE REFERENCES:
//   Irys supports mutable references (a static URL that resolves to the
//   latest transaction in a series). The contract treats this opaquely:
//   the `tx_commitment` always points to the latest transaction. The
//   frontend is responsible for using the mutable URL format. No extra
//   on-chain field is needed — `rotate_content` handles pointer updates.
//
// ONCHAIN FOLDERS (manifests):
//   For multi-file uploads, Irys uses a manifest (index) transaction.
//   The frontend registers the manifest ID as a single `content_id`.
//
// RESPONSIBILITY:
//   The contract RECORDS the user's declared intent. It does NOT verify
//   the actual term with Irys. Verification is delegated to the frontend
//   via the Irys SDK. The contract enforces only structural validity.
//
// ============================================================================
// VISIBILITY SEMANTICS (SOVEREIGNTY & IRREVERSIBLE DISCLOSURE)
// ============================================================================
//
// The user is sovereign over their content. This contract exposes a
// simple toggle between PRIVATE and PUBLIC:
//
//   - PRIVATE (default): the content is intended to be visible only to
//     the owner and to explicitly authorized grantees (via `grant_access`).
//   - PUBLIC: the owner has intentionally chosen to expose the content
//     to the world. Any observer can read it.
//
// ONE-WAY DISCLOSURE GUARANTEE:
//   Once content is public, third parties may have copied, indexed, or
//   archived it. Toggling back to PRIVATE does NOT undo disclosure. The
//   contract cannot recall data that has left its perimeter. This is a
//   property of the disclosure event, not a bug: publishing is opt-in
//   and explicitly initiated by the sovereign user.
//
// RESPONSIBILITY:
//   The contract RECORDS the user's declared visibility intent. It does
//   NOT enforce downstream copies. Data-egress control belongs to the
//   user's disclosure decision and to the frontend.
// ----------------------------------------------------------------------------

sol_interface! {
    interface IStorageProvider {
        function resolve(bytes32 commitment) external view returns (bytes memory);
    }

    interface IQueryProvider {
        function verify(bytes calldata proof, bytes calldata result)
            external view returns (bool);
    }

    interface IAccessProvider {
        function is_authorized(
            bytes32 policy_hash,
            address grantee
        ) external view returns (bool);
    }

    interface IReceiver {
        function onReport(bytes calldata metadata, bytes calldata report) external;
    }

    /// @title IZKVerifier
    /// @notice Optional abstraction over zero-knowledge proof verifiers.
    /// @dev The Solidity ABI selector is `keccak256("verify(bytes,bytes32[])")`.
    ///      Parameter names are NOT part of the selector, so snake_case is safe.
    interface IZKVerifier {
        function verify(
            bytes calldata proof,
            bytes32[] calldata public_inputs
        ) external view returns (bool);
    }
}

// ============================================================================
// CUSTOM ERRORS
// ============================================================================
//
// Custom errors are encoded as 4-byte selectors, which is significantly
// cheaper than string-based reverts (64-96 bytes).
//
// NAMING CONVENTION: error names are unique across the entire ABI.
// The pause-state error is `EnforcedPause` (not `Paused`) to avoid
// colliding with the `Paused` event. This mirrors the OpenZeppelin
// Pausable convention: events `Paused`/`Unpaused`,
// errors `EnforcedPause`/`ExpectedPause`.
// ----------------------------------------------------------------------------

sol! {
    error Unauthorized();
    error ZeroOwner();
    error ZeroGrantee();
    error ZeroAddress();
    error ZeroCommitment();
    error ZeroContentId();
    error AlreadyExists();
    error NotFound();
    error EmptyBatch();
    error BatchTooLarge();
    error LengthMismatch();
    error IndexCorrupted();
    error QueryAlreadyPending();
    error QueryIdClaimedByOther();
    error QueryNotPending();
    error QueryLimitExceeded();
    error QueryNotStale();
    error ContentHashMismatch();
    error VersionMismatch();
    error UnauthorizedForwarder();
    error UnauthorizedWorkflow();
    error InvalidMetadata();
    error InvalidReportLength();
    error TruncatedResult();
    error UnsupportedProvider();
    error UnsupportedStorageTerm();
    error InvalidExpiryDelta();
    error ContentAlreadyPermanent();
    error NoPendingOwner();
    error EnforcedPause();
    // --- ZK PATH ERRORS ---
    error EmptyProof();
    error ZkVerifierNotSet();
    error ZkVerificationFailed();
}

// ============================================================================
// DOMAIN EVENTS
// ============================================================================

sol! {
    event ContentRegistered(
        address indexed user,
        bytes32 indexed contentHash,
        bytes32 txCommitment,
        uint8 providerId,
        uint8 storageTerm
    );

    event ContentRotated(
        address indexed user,
        bytes32 indexed contentHash,
        bytes32 newTxCommitment,
        uint32 newVersion
    );

    event ContentVisibilityUpdated(
        address indexed user,
        bytes32 indexed contentHash,
        bool isPublic
    );

    event ContentStorageTermExtended(
        address indexed user,
        bytes32 indexed contentHash,
        uint8 oldTerm,
        uint8 newTerm,
        uint32 newExpiryDelta
    );

    event AccessGranted(
        address indexed owner,
        address indexed grantee,
        bytes32 indexed contentHash
    );

    event AccessRevoked(
        address indexed owner,
        address indexed grantee,
        bytes32 indexed contentHash
    );

    event ContentDeleted(
        address indexed user,
        bytes32 indexed contentHash
    );

    event QueryRequested(
        bytes32 indexed queryId,
        address indexed requester,
        bytes32 indexed contentHash,
        bytes32 queryPlanHash
    );

    event QueryResultReceived(
        bytes32 indexed queryId,
        bytes32 indexed contentHash,
        bytes32 resultHash,
        bytes2 reportId
    );

    event ProviderUpdated(
        uint8 indexed providerType,
        address indexed oldProvider,
        address indexed newProvider
    );

    event WorkflowIdUpdated(
        bytes32 indexed oldWorkflowId,
        bytes32 indexed newWorkflowId
    );

    event OwnershipTransferStarted(
        address indexed previousOwner,
        address indexed newOwner
    );

    event OwnerUpdated(
        address indexed oldOwner,
        address indexed newOwner
    );

    event ZkVerifierUpdated(
        address indexed oldVerifier,
        address indexed newVerifier
    );

    event QueryCancelled(
        bytes32 indexed queryId,
        address indexed requester
    );

    event Paused(
        address indexed by,
        bytes32 reasonHash
    );

    event Unpaused(
        address indexed by
    );
}

// ============================================================================
// STORAGE TERM CONSTANTS
// ============================================================================

/// @notice PERMANENT represents "no on-chain traceable expiration."
/// @dev In practice, Irys/Arweave guarantee ~200 years. The contract
///      cannot verify the actual limit; my bet is that this decentralized storage infrastructure will last at least until 2050... or maybe not xd.
const STORAGE_TERM_PERMANENT: u8 = 0;
const STORAGE_TERM_30_DAYS: u8 = 1;
const STORAGE_TERM_1_YEAR: u8 = 2;
const STORAGE_TERM_CUSTOM: u8 = 3;

const SECONDS_30_DAYS: u32 = 2_592_000;  // 30 * 24 * 60 * 60
const SECONDS_1_YEAR: u32 = 31_536_000;  // 365 * 24 * 60 * 60

const MAX_EXPIRY_DELTA: u32 = u32::MAX;

// ============================================================================
// PACKED CONTENT COMMITMENT
// ============================================================================
//
// Layout (big-endian byte offsets within the 32-byte U256):
//
//   bytes [0..8)     → version        (u64)
//   bytes [8..16)    → created_at     (u64)
//   bytes [16..24)   → updated_at     (u64)
//   byte  [24]       → provider_id    (u8)
//   byte  [25]       → is_public      (bool)
//   byte  [26]       → schema_version (u8)
//   byte  [27]       → storage_term   (u8)
//   bytes [28..32)   → expiry_delta   (u32)
//
// Storage cost: 3 slots per content (packed + commitment + policy_hash).
// ----------------------------------------------------------------------------

const CURRENT_SCHEMA: u8 = 1;

#[storage]
pub struct ContentCommitment {
    pub packed: StorageU256,
    pub tx_commitment: StorageB256,
    pub access_policy_hash: StorageB256,
}

// ============================================================================
// PER-CONTENT ACCESS CONTROL
// ============================================================================

#[storage]
pub struct ContentAccess {
    pub permissions: StorageMap<B256, StorageMap<Address, StorageBool>>,
    pub grantee_index: StorageMap<B256, StorageVec<StorageAddress>>,
    pub grantee_positions: StorageMap<B256, StorageMap<Address, StorageU256>>,
}

// ============================================================================
// PER-USER VAULT
// ============================================================================

#[storage]
pub struct ContentVault {
    pub contents: StorageMap<B256, ContentCommitment>,
    pub content_list: StorageVec<StorageB256>,
    pub content_positions: StorageMap<B256, StorageU256>,
    pub access: ContentAccess,
}

// ============================================================================
// ENTRYPOINT
// ============================================================================

#[storage]
#[entrypoint]
pub struct KipioContentAccess {
    pub storage_provider: StorageAddress,
    pub query_provider: StorageAddress,
    pub access_provider: StorageAddress,
    pub zk_verifier: StorageAddress,

    pub owner: StorageAddress,
    pub pending_owner: StorageAddress,
    pub paused: StorageBool,
    pub pause_reason_hash: StorageB256,
    pub initialized: StorageBool,

    pub global_registrations: StorageU256,
    pub global_queries: StorageU256,

    pub pending_queries: StorageMap<B256, StorageBool>,
    pub query_timestamps: StorageMap<B256, StorageU256>,
    pub active_query_counts: StorageMap<Address, StorageU256>,
    pub query_requesters: StorageMap<B256, StorageAddress>,
    pub query_content_hashes: StorageMap<B256, StorageB256>,

    pub expected_workflow_id: StorageB256,

    pub vaults: StorageMap<Address, ContentVault>,
}

// ============================================================================
// CONSTANTS
// ============================================================================

const MAX_ACTIVE_QUERIES: u64 = 10;
const QUERY_TIMEOUT_SECONDS: u64 = 3600;
const MAX_BATCH_SIZE: usize = 256;

// ============================================================================
// PACKING HELPERS
// ============================================================================

fn pack_metadata(
    version: u64,
    created_at: u64,
    updated_at: u64,
    provider_id: u8,
    is_public: bool,
    storage_term: u8,
    expiry_delta: u32,
) -> U256 {
    let mut bytes: [u8; 32] = [0u8; 32];
    bytes[0..8].copy_from_slice(&version.to_be_bytes());
    bytes[8..16].copy_from_slice(&created_at.to_be_bytes());
    bytes[16..24].copy_from_slice(&updated_at.to_be_bytes());
    bytes[24] = provider_id;
    bytes[25] = if is_public { 1 } else { 0 };
    bytes[26] = CURRENT_SCHEMA;
    bytes[27] = storage_term;
    bytes[28..32].copy_from_slice(&expiry_delta.to_be_bytes());
    U256::from_be_bytes(bytes)
}

fn unpack_metadata(packed: U256) -> (u64, u64, u64, u8, bool, u8, u32) {
    let bytes: [u8; 32] = packed.to_be_bytes();
    let version = u64::from_be_bytes(bytes[0..8].try_into().unwrap());
    let created_at = u64::from_be_bytes(bytes[8..16].try_into().unwrap());
    let updated_at = u64::from_be_bytes(bytes[16..24].try_into().unwrap());
    let provider_id = bytes[24];
    let is_public = bytes[25] != 0;
    let storage_term = bytes[27];
    let expiry_delta = u32::from_be_bytes(bytes[28..32].try_into().unwrap());
    (version, created_at, updated_at, provider_id, is_public, storage_term, expiry_delta)
}

fn read_version(packed: U256) -> u64 {
    let bytes: [u8; 32] = packed.to_be_bytes();
    u64::from_be_bytes(bytes[0..8].try_into().unwrap())
}

fn read_created_at(packed: U256) -> u64 {
    let bytes: [u8; 32] = packed.to_be_bytes();
    u64::from_be_bytes(bytes[8..16].try_into().unwrap())
}

fn read_is_public(packed: U256) -> bool {
    let bytes: [u8; 32] = packed.to_be_bytes();
    bytes[25] != 0
}

fn read_storage_term(packed: U256) -> u8 {
    let bytes: [u8; 32] = packed.to_be_bytes();
    bytes[27]
}

fn read_expiry_delta(packed: U256) -> u32 {
    let bytes: [u8; 32] = packed.to_be_bytes();
    u32::from_be_bytes(bytes[28..32].try_into().unwrap())
}

fn write_version(packed: U256, version: u64) -> U256 {
    let mut bytes: [u8; 32] = packed.to_be_bytes();
    bytes[0..8].copy_from_slice(&version.to_be_bytes());
    U256::from_be_bytes(bytes)
}

fn write_updated_at(packed: U256, updated_at: u64) -> U256 {
    let mut bytes: [u8; 32] = packed.to_be_bytes();
    bytes[16..24].copy_from_slice(&updated_at.to_be_bytes());
    U256::from_be_bytes(bytes)
}

fn write_is_public_and_updated_at(packed: U256, is_public: bool, updated_at: u64) -> U256 {
    let mut bytes: [u8; 32] = packed.to_be_bytes();
    bytes[16..24].copy_from_slice(&updated_at.to_be_bytes());
    bytes[25] = if is_public { 1 } else { 0 };
    U256::from_be_bytes(bytes)
}

fn write_storage_term_and_expiry(
    packed: U256,
    storage_term: u8,
    expiry_delta: u32,
    updated_at: u64,
) -> U256 {
    let mut bytes: [u8; 32] = packed.to_be_bytes();
    bytes[16..24].copy_from_slice(&updated_at.to_be_bytes());
    bytes[27] = storage_term;
    bytes[28..32].copy_from_slice(&expiry_delta.to_be_bytes());
    U256::from_be_bytes(bytes)
}

fn validate_provider_id(provider_id: u8) -> Result<(), Vec<u8>> {
    match provider_id {
        0 | 1 | 2 | 3 => Ok(()),
        _ => Err(UnsupportedProvider {}.abi_encode()),
    }
}

fn validate_storage_term(term: u8) -> Result<(), Vec<u8>> {
    match term {
        STORAGE_TERM_PERMANENT
        | STORAGE_TERM_30_DAYS
        | STORAGE_TERM_1_YEAR
        | STORAGE_TERM_CUSTOM => Ok(()),
        _ => Err(UnsupportedStorageTerm {}.abi_encode()),
    }
}

fn resolve_expiry_delta(term: u8, custom_delta: u32) -> Result<u32, Vec<u8>> {
    match term {
        STORAGE_TERM_PERMANENT => Ok(0),
        STORAGE_TERM_30_DAYS => Ok(SECONDS_30_DAYS),
        STORAGE_TERM_1_YEAR => Ok(SECONDS_1_YEAR),
        STORAGE_TERM_CUSTOM => {
            if custom_delta == 0 {
                return Err(InvalidExpiryDelta {}.abi_encode());
            }
            if custom_delta > MAX_EXPIRY_DELTA {
                return Err(InvalidExpiryDelta {}.abi_encode());
            }
            Ok(custom_delta)
        }
        _ => Err(UnsupportedStorageTerm {}.abi_encode()),
    }
}

fn compute_absolute_expiry(created_at: u64, expiry_delta: u32) -> u64 {
    if expiry_delta == 0 {
        return 0;
    }
    created_at.saturating_add(expiry_delta as u64)
}

// ============================================================================
// PUBLIC INTERFACE
// ============================================================================

#[public]
impl KipioContentAccess {
    #[constructor]
    pub fn constructor(
        &mut self,
        storage_provider: Address,
        query_provider: Address,
        access_provider: Address,
        expected_workflow_id: B256,
    ) -> Result<(), Vec<u8>> {
        let deployer = self.vm().tx_origin();
        if deployer == Address::ZERO {
            return Err(ZeroOwner {}.abi_encode());
        }
        self.owner.set(deployer);
        self.storage_provider.set(storage_provider);
        self.query_provider.set(query_provider);
        self.access_provider.set(access_provider);
        self.expected_workflow_id.set(expected_workflow_id);
        self.initialized.set(true);
        Ok(())
    }

    // ========================================================================
    // GOVERNANCE
    // ========================================================================

    pub fn transfer_ownership(&mut self, new_owner: Address) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        if new_owner == Address::ZERO {
            return Err(ZeroOwner {}.abi_encode());
        }
        let current = self.owner.get();
        self.pending_owner.set(new_owner);
        self.vm().log(OwnershipTransferStarted {
            previousOwner: current,
            newOwner: new_owner,
        });
        Ok(())
    }

    pub fn accept_ownership(&mut self) -> Result<(), Vec<u8>> {
        let sender = self.vm().msg_sender();
        let pending = self.pending_owner.get();
        if pending == Address::ZERO {
            return Err(NoPendingOwner {}.abi_encode());
        }
        if sender != pending {
            return Err(Unauthorized {}.abi_encode());
        }
        let old = self.owner.get();
        self.owner.set(pending);
        self.pending_owner.set(Address::ZERO);
        self.vm().log(OwnerUpdated { oldOwner: old, newOwner: pending });
        Ok(())
    }

    pub fn set_storage_provider(&mut self, provider: Address) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        if provider == Address::ZERO {
            return Err(ZeroAddress {}.abi_encode());
        }
        let old = self.storage_provider.get();
        self.storage_provider.set(provider);
        self.vm().log(ProviderUpdated { providerType: 0, oldProvider: old, newProvider: provider });
        Ok(())
    }

    pub fn set_query_provider(&mut self, provider: Address) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        if provider == Address::ZERO {
            return Err(ZeroAddress {}.abi_encode());
        }
        let old = self.query_provider.get();
        self.query_provider.set(provider);
        self.vm().log(ProviderUpdated { providerType: 1, oldProvider: old, newProvider: provider });
        Ok(())
    }

    pub fn set_access_provider(&mut self, provider: Address) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        if provider == Address::ZERO {
            return Err(ZeroAddress {}.abi_encode());
        }
        let old = self.access_provider.get();
        self.access_provider.set(provider);
        self.vm().log(ProviderUpdated { providerType: 2, oldProvider: old, newProvider: provider });
        Ok(())
    }

    pub fn set_zk_verifier(&mut self, verifier: Address) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        let old = self.zk_verifier.get();
        self.zk_verifier.set(verifier);
        self.vm().log(ZkVerifierUpdated { oldVerifier: old, newVerifier: verifier });
        Ok(())
    }

    pub fn set_expected_workflow_id(&mut self, workflow_id: B256) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        let old = self.expected_workflow_id.get();
        self.expected_workflow_id.set(workflow_id);
        self.vm().log(WorkflowIdUpdated { oldWorkflowId: old, newWorkflowId: workflow_id });
        Ok(())
    }

    // ========================================================================
    // CIRCUIT BREAKER
    // ========================================================================

    pub fn pause(&mut self, reason_hash: B256) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        if self.paused.get() {
            return Ok(());
        }
        self.paused.set(true);
        self.pause_reason_hash.set(reason_hash);
        self.vm().log(Paused { by: self.vm().msg_sender(), reasonHash: reason_hash });
        Ok(())
    }

    pub fn unpause(&mut self) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        if !self.paused.get() {
            return Ok(());
        }
        self.paused.set(false);
        self.pause_reason_hash.set(B256::ZERO);
        self.vm().log(Unpaused { by: self.vm().msg_sender() });
        Ok(())
    }

    // ========================================================================
    // CONTENT REGISTRATION
    // ========================================================================

    pub fn register_content(
        &mut self,
        content_id: B256,
        tx_commitment: B256,
        provider_id: u8,
        access_policy_hash: B256,
        is_public: bool,
        storage_term: u8,
        expiry_delta: u32,
    ) -> Result<(), Vec<u8>> {
        self.require_not_paused()?;

        if content_id == B256::ZERO {
            return Err(ZeroContentId {}.abi_encode());
        }
        if tx_commitment == B256::ZERO {
            return Err(ZeroCommitment {}.abi_encode());
        }
        validate_provider_id(provider_id)?;
        validate_storage_term(storage_term)?;
        let resolved_delta = resolve_expiry_delta(storage_term, expiry_delta)?;

        let sender = self.vm().msg_sender();

        {
            let vault = self.vaults.getter(sender);
            let record = vault.contents.getter(content_id);
            let existing = record.tx_commitment.get();
            if existing != B256::ZERO {
                if existing == tx_commitment {
                    return Ok(());
                }
                return Err(AlreadyExists {}.abi_encode());
            }
        }

        let now = self.vm().block_timestamp();

        {
            let mut vault = self.vaults.setter(sender);
            let mut record = vault.contents.setter(content_id);

            record.tx_commitment.set(tx_commitment);
            record.access_policy_hash.set(access_policy_hash);
            record.packed.set(pack_metadata(1, now, now, provider_id, is_public, storage_term, resolved_delta));

            let new_index = vault.content_list.len() as u64;
            vault.content_list.grow().set(content_id);
            vault.content_positions.setter(content_id).set(U256::from(new_index + 1));
        }

        let current_total = self.global_registrations.get();
        self.global_registrations.set(current_total + U256::from(1));

        self.vm().log(ContentRegistered {
            user: sender,
            contentHash: content_id,
            txCommitment: tx_commitment,
            providerId: provider_id,
            storageTerm: storage_term,
        });

        Ok(())
    }

    pub fn register_batch(
        &mut self,
        content_ids: Vec<B256>,
        tx_commitments: Vec<B256>,
        provider_ids: Vec<u8>,
        access_policy_hashes: Vec<B256>,
        storage_terms: Vec<u8>,
        expiry_deltas: Vec<u32>,
    ) -> Result<(), Vec<u8>> {
        self.require_not_paused()?;

        let len = content_ids.len();
        if len == 0 {
            return Err(EmptyBatch {}.abi_encode());
        }
        if len > MAX_BATCH_SIZE {
            return Err(BatchTooLarge {}.abi_encode());
        }
        if tx_commitments.len() != len
            || provider_ids.len() != len
            || access_policy_hashes.len() != len
            || storage_terms.len() != len
            || expiry_deltas.len() != len
        {
            return Err(LengthMismatch {}.abi_encode());
        }

        let sender = self.vm().msg_sender();

        let mut to_insert: Vec<(usize, u32)> = Vec::new();
        {
            let vault = self.vaults.getter(sender);
            for i in 0..len {
                if content_ids[i] == B256::ZERO {
                    return Err(ZeroContentId {}.abi_encode());
                }
                if tx_commitments[i] == B256::ZERO {
                    return Err(ZeroCommitment {}.abi_encode());
                }
                validate_provider_id(provider_ids[i])?;
                validate_storage_term(storage_terms[i])?;
                let resolved = resolve_expiry_delta(storage_terms[i], expiry_deltas[i])?;

                let record = vault.contents.getter(content_ids[i]);
                let existing = record.tx_commitment.get();
                if existing == B256::ZERO {
                    to_insert.push((i, resolved));
                } else if existing != tx_commitments[i] {
                    return Err(AlreadyExists {}.abi_encode());
                }
            }
        }

        let now = self.vm().block_timestamp();
        let mut events: Vec<(B256, B256, u8, u8)> = Vec::with_capacity(to_insert.len());

        {
            let mut vault = self.vaults.setter(sender);
            for &(i, resolved_delta) in &to_insert {
                let content_id = content_ids[i];
                let tx_commitment = tx_commitments[i];
                let provider_id = provider_ids[i];
                let access_policy_hash = access_policy_hashes[i];
                let storage_term = storage_terms[i];

                let mut record = vault.contents.setter(content_id);
                record.tx_commitment.set(tx_commitment);
                record.access_policy_hash.set(access_policy_hash);
                record.packed.set(pack_metadata(1, now, now, provider_id, false, storage_term, resolved_delta));

                let new_index = vault.content_list.len() as u64;
                vault.content_list.grow().set(content_id);
                vault.content_positions.setter(content_id).set(U256::from(new_index + 1));

                events.push((content_id, tx_commitment, provider_id, storage_term));
            }
        }

        if !to_insert.is_empty() {
            let current_total = self.global_registrations.get();
            self.global_registrations.set(current_total + U256::from(to_insert.len() as u64));
        }

        for (content_id, tx_commitment, provider_id, storage_term) in events {
            self.vm().log(ContentRegistered {
                user: sender,
                contentHash: content_id,
                txCommitment: tx_commitment,
                providerId: provider_id,
                storageTerm: storage_term,
            });
        }

        Ok(())
    }

    pub fn rotate_content(
        &mut self,
        content_id: B256,
        new_tx_commitment: B256,
        new_access_policy_hash: B256,
    ) -> Result<(), Vec<u8>> {
        self.require_not_paused()?;
        if new_tx_commitment == B256::ZERO {
            return Err(ZeroCommitment {}.abi_encode());
        }

        let sender = self.vm().msg_sender();
        let now = self.vm().block_timestamp();
        let new_version: u64;

        {
            let mut vault = self.vaults.setter(sender);
            let mut record = vault.contents.setter(content_id);

            if record.tx_commitment.get() == B256::ZERO {
                return Err(NotFound {}.abi_encode());
            }

            let packed = record.packed.get();
            new_version = read_version(packed) + 1;

            record.tx_commitment.set(new_tx_commitment);
            record.access_policy_hash.set(new_access_policy_hash);
            record.packed.set(write_version(write_updated_at(packed, now), new_version));
        }

        self.vm().log(ContentRotated {
            user: sender,
            contentHash: content_id,
            newTxCommitment: new_tx_commitment,
            newVersion: new_version as u32,
        });

        Ok(())
    }

    pub fn rotate_content_cas(
        &mut self,
        content_id: B256,
        expected_version: u64,
        new_tx_commitment: B256,
        new_access_policy_hash: B256,
    ) -> Result<(), Vec<u8>> {
        self.require_not_paused()?;
        if new_tx_commitment == B256::ZERO {
            return Err(ZeroCommitment {}.abi_encode());
        }

        let sender = self.vm().msg_sender();
        let now = self.vm().block_timestamp();
        let new_version: u64;

        {
            let mut vault = self.vaults.setter(sender);
            let mut record = vault.contents.setter(content_id);

            if record.tx_commitment.get() == B256::ZERO {
                return Err(NotFound {}.abi_encode());
            }

            let packed = record.packed.get();
            let current_version = read_version(packed);
            if current_version != expected_version {
                return Err(VersionMismatch {}.abi_encode());
            }

            new_version = current_version + 1;
            record.tx_commitment.set(new_tx_commitment);
            record.access_policy_hash.set(new_access_policy_hash);
            record.packed.set(write_version(write_updated_at(packed, now), new_version));
        }

        self.vm().log(ContentRotated {
            user: sender,
            contentHash: content_id,
            newTxCommitment: new_tx_commitment,
            newVersion: new_version as u32,
        });

        Ok(())
    }

    // ========================================================================
    // STORAGE TERM EXTENSION
    // ========================================================================
    //
    // Semantics of `expiry_delta`: absolute seconds from `created_at`
    // until expiry. To extend by another 30 days from now, the user
    // computes the new total delta themselves.
    //
    // Check order (matters for idempotency):
    //   1. Idempotent no-op FIRST. Covers PERMANENT → PERMANENT and any
    //      same-term-same-delta call. This keeps batch retries from
    //      reverting on already-satisfied items.
    //   2. Reject attempts to extend an already-PERMANENT content with
    //      a different (necessarily shorter) target.
    //   3. Reject downgrades: the new absolute delta must be >= old.
    //      Comparison is on deltas, not term IDs, because CUSTOM can
    //      represent any duration (e.g., a CUSTOM 10-day term is shorter
    //      than a 30_DAYS term despite a higher numeric ID).
    // ------------------------------------------------------------------------

    pub fn extend_storage_term(
        &mut self,
        content_id: B256,
        new_storage_term: u8,
        custom_expiry_delta: u32,
    ) -> Result<(), Vec<u8>> {
        self.require_not_paused()?;
        validate_storage_term(new_storage_term)?;

        let resolved_delta = resolve_expiry_delta(new_storage_term, custom_expiry_delta)?;

        let sender = self.vm().msg_sender();
        let now = self.vm().block_timestamp();

        let old_term: u8;
        let old_delta: u32;

        {
            let mut vault = self.vaults.setter(sender);
            let mut record = vault.contents.setter(content_id);

            let packed = record.packed.get();
            if packed == U256::ZERO {
                return Err(NotFound {}.abi_encode());
            }

            old_term = read_storage_term(packed);
            old_delta = read_expiry_delta(packed);

            // 1. Idempotent no-op: same term AND same delta.
            //    Covers PERMANENT → PERMANENT and any exact-repeat.
            if new_storage_term == old_term && resolved_delta == old_delta {
                return Ok(());
            }

            // 2. Cannot extend an already-permanent content to a finite term.
            if old_term == STORAGE_TERM_PERMANENT {
                return Err(ContentAlreadyPermanent {}.abi_encode());
            }

            // 3. Downgrade check: compare absolute deltas, not term IDs.
            //    Permanent is always an upgrade, so it bypasses the check.
            if new_storage_term != STORAGE_TERM_PERMANENT && resolved_delta < old_delta {
                return Err(UnsupportedStorageTerm {}.abi_encode());
            }

            record.packed.set(write_storage_term_and_expiry(
                packed,
                new_storage_term,
                resolved_delta,
                now,
            ));
        }

        self.vm().log(ContentStorageTermExtended {
            user: sender,
            contentHash: content_id,
            oldTerm: old_term,
            newTerm: new_storage_term,
            newExpiryDelta: resolved_delta,
        });

        Ok(())
    }

    pub fn extend_storage_term_batch(
        &mut self,
        content_ids: Vec<B256>,
        new_storage_terms: Vec<u8>,
        custom_expiry_deltas: Vec<u32>,
    ) -> Result<(), Vec<u8>> {
        self.require_not_paused()?;

        let len = content_ids.len();
        if len == 0 {
            return Err(EmptyBatch {}.abi_encode());
        }
        if len > MAX_BATCH_SIZE {
            return Err(BatchTooLarge {}.abi_encode());
        }
        if new_storage_terms.len() != len || custom_expiry_deltas.len() != len {
            return Err(LengthMismatch {}.abi_encode());
        }

        let sender = self.vm().msg_sender();
        let now = self.vm().block_timestamp();

        let mut events: Vec<(B256, u8, u8, u32)> = Vec::with_capacity(len);

        {
            let mut vault = self.vaults.setter(sender);
            for i in 0..len {
                let content_id = content_ids[i];
                let new_term = new_storage_terms[i];
                validate_storage_term(new_term)?;
                let resolved_delta = resolve_expiry_delta(new_term, custom_expiry_deltas[i])?;

                let mut record = vault.contents.setter(content_id);
                let packed = record.packed.get();
                if packed == U256::ZERO {
                    return Err(NotFound {}.abi_encode());
                }

                let old_term = read_storage_term(packed);
                let old_delta = read_expiry_delta(packed);

                // 1. Idempotent no-op FIRST (covers PERMANENT → PERMANENT).
                if new_term == old_term && resolved_delta == old_delta {
                    continue;
                }

                // 2. Cannot extend an already-permanent content to a finite term.
                if old_term == STORAGE_TERM_PERMANENT {
                    return Err(ContentAlreadyPermanent {}.abi_encode());
                }

                // 3. Downgrade check on absolute deltas.
                if new_term != STORAGE_TERM_PERMANENT && resolved_delta < old_delta {
                    return Err(UnsupportedStorageTerm {}.abi_encode());
                }

                record.packed.set(write_storage_term_and_expiry(
                    packed,
                    new_term,
                    resolved_delta,
                    now,
                ));

                events.push((content_id, old_term, new_term, resolved_delta));
            }
        }

        for (content_id, old_term, new_term, new_delta) in events {
            self.vm().log(ContentStorageTermExtended {
                user: sender,
                contentHash: content_id,
                oldTerm: old_term,
                newTerm: new_term,
                newExpiryDelta: new_delta,
            });
        }

        Ok(())
    }

    // ========================================================================
    // VISIBILITY
    // ========================================================================
    //
    // Simple private/public toggle. Visibility is user-sovereign: no
    // role, no operator, no approval flow. The owner toggles it freely.
    //
    // IRREVERSIBILITY WARNING (documented, not enforced):
    //   Once public, third parties may have copied the content. Toggling
    //   back to private does NOT recall those copies. The contract records
    //   the intent; it cannot enforce downstream egress. The user accepts
    //   this trade-off when publishing.
    // ------------------------------------------------------------------------

    pub fn set_visibility(
        &mut self,
        content_id: B256,
        is_public: bool,
    ) -> Result<(), Vec<u8>> {
        self.require_not_paused()?;

        let sender = self.vm().msg_sender();
        let now = self.vm().block_timestamp();

        {
            let mut vault = self.vaults.setter(sender);
            let mut record = vault.contents.setter(content_id);

            let packed = record.packed.get();
            if packed == U256::ZERO {
                return Err(NotFound {}.abi_encode());
            }
            if read_is_public(packed) == is_public {
                return Ok(());
            }
            record.packed.set(write_is_public_and_updated_at(packed, is_public, now));
        }

        self.vm().log(ContentVisibilityUpdated {
            user: sender,
            contentHash: content_id,
            isPublic: is_public,
        });

        Ok(())
    }

    pub fn set_visibility_batch(
        &mut self,
        content_ids: Vec<B256>,
        is_publics: Vec<bool>,
    ) -> Result<(), Vec<u8>> {
        self.require_not_paused()?;

        let len = content_ids.len();
        if len == 0 {
            return Err(EmptyBatch {}.abi_encode());
        }
        if len > MAX_BATCH_SIZE {
            return Err(BatchTooLarge {}.abi_encode());
        }
        if is_publics.len() != len {
            return Err(LengthMismatch {}.abi_encode());
        }

        let sender = self.vm().msg_sender();
        let now = self.vm().block_timestamp();
        let mut events: Vec<(B256, bool)> = Vec::with_capacity(len);

        {
            let mut vault = self.vaults.setter(sender);
            for i in 0..len {
                let content_id = content_ids[i];
                let is_public = is_publics[i];

                let mut record = vault.contents.setter(content_id);
                let packed = record.packed.get();
                if packed == U256::ZERO {
                    return Err(NotFound {}.abi_encode());
                }
                if read_is_public(packed) == is_public {
                    continue;
                }
                record.packed.set(write_is_public_and_updated_at(packed, is_public, now));
                events.push((content_id, is_public));
            }
        }

        for (content_id, is_public) in events {
            self.vm().log(ContentVisibilityUpdated {
                user: sender,
                contentHash: content_id,
                isPublic: is_public,
            });
        }

        Ok(())
    }

    // ========================================================================
    // DELETE CONTENT
    // ========================================================================
    //
    // Idempotent: deleting a non-existent content is a silent no-op.
    // After deletion, the content_id can be reused by a fresh register.
    // Events are the historical outbox; no on-chain tombstone needed.
    // ------------------------------------------------------------------------

    pub fn delete_content(&mut self, content_id: B256) -> Result<(), Vec<u8>> {
        self.require_not_paused()?;

        let sender = self.vm().msg_sender();

        {
            let vault = self.vaults.getter(sender);
            if vault.contents.getter(content_id).tx_commitment.get() == B256::ZERO {
                return Ok(());
            }
        }

        {
            let mut vault = self.vaults.setter(sender);

            let pos = vault.content_positions.getter(content_id).get();
            if pos != U256::ZERO {
                let idx = (pos.as_limbs()[0] - 1) as usize;
                let last_idx = vault.content_list.len() - 1;

                if idx != last_idx {
                    let last_item: B256 = vault.content_list.getter(last_idx).unwrap().get();
                    vault.content_list.setter(idx).unwrap().set(last_item);
                    vault.content_positions.setter(last_item).set(U256::from(idx as u64 + 1));
                }
                vault.content_list.pop();
                vault.content_positions.setter(content_id).set(U256::ZERO);
            }

            let mut record = vault.contents.setter(content_id);
            record.tx_commitment.set(B256::ZERO);
            record.access_policy_hash.set(B256::ZERO);
            record.packed.set(U256::ZERO);

            let mut grantees: Vec<Address> = Vec::new();
            {
                let index = vault.access.grantee_index.getter(content_id);
                let total = index.len();
                for i in 0..total {
                    if let Some(addr_guard) = index.getter(i) {
                        grantees.push(addr_guard.get());
                    }
                }
            }

            for addr in grantees {
                vault.access.permissions.setter(content_id).setter(addr).set(false);
                vault.access.grantee_positions.setter(content_id).setter(addr).set(U256::ZERO);
            }

            // SAFETY: StorageAddress tolerates zero-slots; set_len(0) is safe.
            let mut index = vault.access.grantee_index.setter(content_id);
            unsafe { index.set_len(0); }
        }

        self.vm().log(ContentDeleted {
            user: sender,
            contentHash: content_id,
        });

        Ok(())
    }

    // ========================================================================
    // ACCESS CONTROL
    // ========================================================================

    pub fn grant_access(
        &mut self,
        content_id: B256,
        grantee: Address,
    ) -> Result<(), Vec<u8>> {
        self.require_not_paused()?;
        if grantee == Address::ZERO {
            return Err(ZeroGrantee {}.abi_encode());
        }

        let sender = self.vm().msg_sender();

        {
            let mut vault = self.vaults.setter(sender);

            if vault.contents.getter(content_id).tx_commitment.get() == B256::ZERO {
                return Err(NotFound {}.abi_encode());
            }

            let mut content_map = vault.access.permissions.setter(content_id);
            let mut permission_slot = content_map.setter(grantee);

            if permission_slot.get() {
                return Ok(());
            }
            permission_slot.set(true);

            let existing_pos = vault.access.grantee_positions.getter(content_id).getter(grantee).get();
            if existing_pos == U256::ZERO {
                let mut index = vault.access.grantee_index.setter(content_id);
                let new_pos = index.len() as u64;
                index.grow().set(grantee);
                vault.access.grantee_positions
                    .setter(content_id)
                    .setter(grantee)
                    .set(U256::from(new_pos + 1));
            }
        }

        self.vm().log(AccessGranted {
            owner: sender,
            grantee,
            contentHash: content_id,
        });

        Ok(())
    }

    pub fn revoke_access(
        &mut self,
        content_id: B256,
        grantee: Address,
    ) -> Result<(), Vec<u8>> {
        self.require_not_paused()?;
        if grantee == Address::ZERO {
            return Err(ZeroGrantee {}.abi_encode());
        }

        let sender = self.vm().msg_sender();

        {
            let mut vault = self.vaults.setter(sender);

            let pos = vault.access.grantee_positions.getter(content_id).getter(grantee).get();
            if pos == U256::ZERO {
                return Ok(());
            }

            {
                let mut content_map = vault.access.permissions.setter(content_id);
                let mut permission_slot = content_map.setter(grantee);
                if !permission_slot.get() {
                    return Ok(());
                }
                permission_slot.set(false);
            }

            let idx = (pos.as_limbs()[0] - 1) as usize;

            let last_addr: Option<Address>;
            let last_idx: usize;
            {
                let index = vault.access.grantee_index.getter(content_id);
                last_idx = index.len() - 1;
                if idx != last_idx {
                    last_addr = index.getter(last_idx).map(|g| g.get());
                } else {
                    last_addr = None;
                }
            }

            {
                let mut index = vault.access.grantee_index.setter(content_id);
                if let Some(addr) = last_addr {
                    index.setter(idx).unwrap().set(addr);
                }
                index.pop();
            }

            if let Some(addr) = last_addr {
                vault.access.grantee_positions
                    .setter(content_id)
                    .setter(addr)
                    .set(U256::from(idx as u64 + 1));
            }
            vault.access.grantee_positions
                .setter(content_id)
                .setter(grantee)
                .set(U256::ZERO);
        }

        self.vm().log(AccessRevoked {
            owner: sender,
            grantee,
            contentHash: content_id,
        });

        Ok(())
    }

    // ========================================================================
    // VIEWS
    // ========================================================================

    pub fn get_global_stats(&self) -> (U256, U256) {
        (self.global_registrations.get(), self.global_queries.get())
    }

    pub fn is_paused(&self) -> bool {
        self.paused.get()
    }

    pub fn get_pause_reason(&self) -> B256 {
        self.pause_reason_hash.get()
    }

    pub fn get_providers(&self) -> (Address, Address, Address, Address) {
        (
            self.storage_provider.get(),
            self.query_provider.get(),
            self.access_provider.get(),
            self.zk_verifier.get(),
        )
    }

    pub fn has_access(
        &self,
        owner: Address,
        content_id: B256,
        grantee: Address,
    ) -> bool {
        self.vaults.getter(owner)
            .access.permissions
            .getter(content_id)
            .getter(grantee)
            .get()
    }

    pub fn get_commitment(
        &self,
        owner: Address,
        content_id: B256,
    ) -> Result<B256, Vec<u8>> {
        let vault = self.vaults.getter(owner);
        let record = vault.contents.getter(content_id);
        let commitment = record.tx_commitment.get();
        if commitment == B256::ZERO {
            return Err(NotFound {}.abi_encode());
        }
        Ok(commitment)
    }

    pub fn get_metadata(
        &self,
        owner: Address,
        content_id: B256,
    ) -> Result<(u64, u64, u64, u8, bool, u8, u32, u64), Vec<u8>> {
        let vault = self.vaults.getter(owner);
        let record = vault.contents.getter(content_id);
        let packed = record.packed.get();
        if packed == U256::ZERO {
            return Err(NotFound {}.abi_encode());
        }
        let (version, created_at, updated_at, provider_id, is_public, storage_term, expiry_delta) =
            unpack_metadata(packed);
        let absolute_expiry = compute_absolute_expiry(created_at, expiry_delta);
        Ok((version, created_at, updated_at, provider_id, is_public, storage_term, expiry_delta, absolute_expiry))
    }

    pub fn is_public(
        &self,
        owner: Address,
        content_id: B256,
    ) -> Result<bool, Vec<u8>> {
        let vault = self.vaults.getter(owner);
        let record = vault.contents.getter(content_id);
        let packed = record.packed.get();
        if packed == U256::ZERO {
            return Err(NotFound {}.abi_encode());
        }
        Ok(read_is_public(packed))
    }

    pub fn get_storage_info(
        &self,
        owner: Address,
        content_id: B256,
    ) -> Result<(u8, u32, u64), Vec<u8>> {
        let vault = self.vaults.getter(owner);
        let record = vault.contents.getter(content_id);
        let packed = record.packed.get();
        if packed == U256::ZERO {
            return Err(NotFound {}.abi_encode());
        }
        let created_at = read_created_at(packed);
        let term = read_storage_term(packed);
        let delta = read_expiry_delta(packed);
        let absolute_expiry = compute_absolute_expiry(created_at, delta);
        Ok((term, delta, absolute_expiry))
    }

    /// @notice Returns whether the content is expired, and the remaining
    ///         seconds until expiry.
    ///
    /// @dev O(1) helper for frontends. `is_expired` is `false` for
    ///      permanent content. `seconds_remaining` is `0` for permanent
    ///      content or already-expired content.
    pub fn get_expiry_status(
        &self,
        owner: Address,
        content_id: B256,
    ) -> Result<(bool, u64), Vec<u8>> {
        let vault = self.vaults.getter(owner);
        let record = vault.contents.getter(content_id);
        let packed = record.packed.get();
        if packed == U256::ZERO {
            return Err(NotFound {}.abi_encode());
        }
        let created_at = read_created_at(packed);
        let delta = read_expiry_delta(packed);
        if delta == 0 {
            return Ok((false, 0)); // permanent
        }
        let absolute = created_at.saturating_add(delta as u64);
        let now = self.vm().block_timestamp();
        if now >= absolute {
            Ok((true, 0))
        } else {
            Ok((false, absolute - now))
        }
    }

    pub fn get_access_policy_hash(
        &self,
        owner: Address,
        content_id: B256,
    ) -> Result<B256, Vec<u8>> {
        let vault = self.vaults.getter(owner);
        let record = vault.contents.getter(content_id);
        let hash = record.access_policy_hash.get();
        if hash == B256::ZERO {
            return Err(NotFound {}.abi_encode());
        }
        Ok(hash)
    }

    pub fn get_content_list(
        &self,
        owner: Address,
        offset: u32,
        limit: u32,
    ) -> Vec<B256> {
        let vault = self.vaults.getter(owner);
        let list = &vault.content_list;

        let total = list.len() as u32;
        let mut result = Vec::new();

        let start = core::cmp::min(offset, total);
        let end = core::cmp::min(start.saturating_add(limit), total);

        for i in start..end {
            if let Some(item_guard) = list.getter(i as usize) {
                result.push(item_guard.get());
            }
        }
        result
    }

    pub fn get_shared_paginated(
        &self,
        owner: Address,
        content_id: B256,
        offset: u32,
        limit: u32,
    ) -> Vec<Address> {
        let vault = self.vaults.getter(owner);
        let index = vault.access.grantee_index.getter(content_id);

        let total = index.len() as u32;
        let mut result = Vec::new();

        let start = core::cmp::min(offset, total);
        let end = core::cmp::min(start.saturating_add(limit), total);

        for i in start..end {
            if let Some(addr_guard) = index.getter(i as usize) {
                let addr = addr_guard.get();
                if vault.access.permissions.getter(content_id).getter(addr).get() {
                    result.push(addr);
                }
            }
        }
        result
    }

    // ========================================================================
    // INTEGRITY PROOF
    // ========================================================================

    pub fn verify_content_ownership(
        &self,
        owner: Address,
        content_id: B256,
        tx_id: Bytes,
        salt: Bytes,
    ) -> Result<bool, Vec<u8>> {
        let vault = self.vaults.getter(owner);
        let record = vault.contents.getter(content_id);
        let stored = record.tx_commitment.get();

        if stored == B256::ZERO {
            return Err(NotFound {}.abi_encode());
        }

        let mut preimage = Vec::with_capacity(tx_id.len() + salt.len());
        preimage.extend_from_slice(&tx_id);
        preimage.extend_from_slice(&salt);

        let computed = keccak(&preimage);

        Ok(computed == stored)
    }

    // ========================================================================
    // QUERY REQUEST (NON-ZK PATH)
    // ========================================================================

    pub fn request_query(
        &mut self,
        query_id: B256,
        content_hash: B256,
        query_plan_hash: B256,
    ) -> Result<(), Vec<u8>> {
        self.require_not_paused()?;

        let sender = self.vm().msg_sender();

        {
            let vault = self.vaults.getter(sender);
            let record = vault.contents.getter(content_hash);
            if record.tx_commitment.get() == B256::ZERO {
                return Err(NotFound {}.abi_encode());
            }
        }

        let active_count = self.active_query_counts.getter(sender).get();
        if active_count >= U256::from(MAX_ACTIVE_QUERIES) {
            return Err(QueryLimitExceeded {}.abi_encode());
        }

        let existing_requester = self.query_requesters.getter(query_id).get();
        if existing_requester != Address::ZERO && existing_requester != sender {
            return Err(QueryIdClaimedByOther {}.abi_encode());
        }
        if self.pending_queries.getter(query_id).get() {
            return Err(QueryAlreadyPending {}.abi_encode());
        }

        let now = U256::from(self.vm().block_timestamp());

        self.pending_queries.setter(query_id).set(true);
        self.query_timestamps.setter(query_id).set(now);
        self.query_requesters.setter(query_id).set(sender);
        self.query_content_hashes.setter(query_id).set(content_hash);
        self.active_query_counts.setter(sender).set(active_count + U256::from(1));

        let current_queries = self.global_queries.get();
        self.global_queries.set(current_queries + U256::from(1));

        self.vm().log(QueryRequested {
            queryId: query_id,
            requester: sender,
            contentHash: content_hash,
            queryPlanHash: query_plan_hash,
        });

        Ok(())
    }

    pub fn cancel_stale_query(&mut self, query_id: B256) -> Result<(), Vec<u8>> {
        let ts = self.query_timestamps.getter(query_id).get();
        if ts == U256::ZERO {
            return Err(QueryNotPending {}.abi_encode());
        }

        let requester = self.query_requesters.getter(query_id).get();
        let sender = self.vm().msg_sender();
        if sender != requester && sender != self.owner.get() {
            return Err(Unauthorized {}.abi_encode());
        }

        let now = U256::from(self.vm().block_timestamp());
        let deadline = ts.saturating_add(U256::from(QUERY_TIMEOUT_SECONDS));
        if now < deadline {
            return Err(QueryNotStale {}.abi_encode());
        }

        self.pending_queries.setter(query_id).set(false);
        self.query_timestamps.setter(query_id).set(U256::ZERO);
        self.query_requesters.setter(query_id).set(Address::ZERO);
        self.query_content_hashes.setter(query_id).set(B256::ZERO);

        if requester != Address::ZERO {
            let count = self.active_query_counts.getter(requester).get();
            let new_count = count.saturating_sub(U256::from(1));
            self.active_query_counts.setter(requester).set(new_count);
        }

        self.vm().log(QueryCancelled { queryId: query_id, requester });

        Ok(())
    }

    // ========================================================================
    // QUERY REQUEST (ZK PATH — OPTIONAL)
    // ========================================================================

    pub fn request_query_zk(
        &mut self,
        query_id: B256,
        content_hash: B256,
        query_plan_hash: B256,
        proof: Bytes,
        public_inputs: Vec<B256>,
    ) -> Result<(), Vec<u8>> {
        self.require_not_paused()?;

        let sender = self.vm().msg_sender();

        // --- CHECKS (local, no external calls) ---
        if proof.is_empty() {
            return Err(EmptyProof {}.abi_encode());
        }

        {
            let vault = self.vaults.getter(sender);
            let record = vault.contents.getter(content_hash);
            if record.tx_commitment.get() == B256::ZERO {
                return Err(NotFound {}.abi_encode());
            }
        }

        let active_count = self.active_query_counts.getter(sender).get();
        if active_count >= U256::from(MAX_ACTIVE_QUERIES) {
            return Err(QueryLimitExceeded {}.abi_encode());
        }

        let existing_requester = self.query_requesters.getter(query_id).get();
        if existing_requester != Address::ZERO && existing_requester != sender {
            return Err(QueryIdClaimedByOther {}.abi_encode());
        }
        if self.pending_queries.getter(query_id).get() {
            return Err(QueryAlreadyPending {}.abi_encode());
        }

        // --- INTERACTIONS (cross-contract call) ---
        let zk_addr = self.zk_verifier.get();
        if zk_addr == Address::ZERO {
            return Err(ZkVerifierNotSet {}.abi_encode());
        }

        let zk = IZKVerifier::new(zk_addr);
        let call = Call::new();
        let ok = zk
            .verify(self.vm(), call, proof, public_inputs)
            .map_err(|_| ZkVerificationFailed {}.abi_encode())?;

        if !ok {
            return Err(ZkVerificationFailed {}.abi_encode());
        }

        // --- EFFECTS ---
        let now = U256::from(self.vm().block_timestamp());

        self.pending_queries.setter(query_id).set(true);
        self.query_timestamps.setter(query_id).set(now);
        self.query_requesters.setter(query_id).set(sender);
        self.query_content_hashes.setter(query_id).set(content_hash);
        self.active_query_counts.setter(sender).set(active_count + U256::from(1));

        let current_queries = self.global_queries.get();
        self.global_queries.set(current_queries + U256::from(1));

        // --- INTERACTIONS (log) ---
        self.vm().log(QueryRequested {
            queryId: query_id,
            requester: sender,
            contentHash: content_hash,
            queryPlanHash: query_plan_hash,
        });

        Ok(())
    }

    // ========================================================================
    // CRE CALLBACK
    // ========================================================================

    pub fn on_report(
        &mut self,
        metadata: Bytes,
        report: Bytes,
    ) -> Result<(), Vec<u8>> {
        let caller = self.vm().msg_sender();
        if caller != self.query_provider.get() {
            return Err(UnauthorizedForwarder {}.abi_encode());
        }

        if metadata.len() < 64 {
            return Err(InvalidMetadata {}.abi_encode());
        }

        let workflow_id = B256::from_slice(&metadata[0..32]);
        if workflow_id != self.expected_workflow_id.get() {
            return Err(UnauthorizedWorkflow {}.abi_encode());
        }

        let report_id = FixedBytes::<2>::from_slice(&metadata[62..64]);

        let (query_id, content_hash, result) = decode_cre_report(&report)?;

        if !self.pending_queries.getter(query_id).get() {
            return Err(QueryNotPending {}.abi_encode());
        }

        let expected_content_hash = self.query_content_hashes.getter(query_id).get();
        if content_hash != expected_content_hash {
            return Err(ContentHashMismatch {}.abi_encode());
        }

        let requester = self.query_requesters.getter(query_id).get();

        self.pending_queries.setter(query_id).set(false);
        self.query_timestamps.setter(query_id).set(U256::ZERO);
        self.query_requesters.setter(query_id).set(Address::ZERO);
        self.query_content_hashes.setter(query_id).set(B256::ZERO);

        if requester != Address::ZERO {
            let count = self.active_query_counts.getter(requester).get();
            let new_count = count.saturating_sub(U256::from(1));
            self.active_query_counts.setter(requester).set(new_count);
        }

        let result_hash = keccak(&result);
        self.vm().log(QueryResultReceived {
            queryId: query_id,
            contentHash: content_hash,
            resultHash: B256::from_slice(result_hash.as_slice()),
            reportId: report_id,
        });

        Ok(())
    }
}

// ============================================================================
// INTERNAL HELPERS
// ============================================================================

impl KipioContentAccess {
    fn require_owner(&self) -> Result<(), Vec<u8>> {
        if self.vm().msg_sender() != self.owner.get() {
            return Err(Unauthorized {}.abi_encode());
        }
        Ok(())
    }

    fn require_not_paused(&self) -> Result<(), Vec<u8>> {
        if self.paused.get() {
            return Err(EnforcedPause {}.abi_encode());
        }
        Ok(())
    }
}

/// @dev Decodes a CRE report into (query_id, content_hash, result).
///
///      Expected layout (produced by the CRE workflow using encodePacked):
///        [0..32)   → queryId
///        [32..64)  → contentHash
///        [64..96)  → length of result (uint256)
///        [96..N)   → result bytes
fn decode_cre_report(report: &Bytes) -> Result<(B256, B256, Bytes), Vec<u8>> {
    if report.len() < 96 {
        return Err(InvalidReportLength {}.abi_encode());
    }
    let query_id = B256::from_slice(&report[0..32]);
    let content_hash = B256::from_slice(&report[32..64]);

    let len_bytes: [u8; 32] = report[64..96]
        .try_into()
        .map_err(|_| InvalidReportLength {}.abi_encode())?;
    let result_len = U256::from_be_bytes(len_bytes).as_limbs()[0] as usize;
    if report.len() < 96 + result_len {
        return Err(TruncatedResult {}.abi_encode());
    }
    let result = Bytes::from(report[96..96 + result_len].to_vec());

    Ok((query_id, content_hash, result))
}

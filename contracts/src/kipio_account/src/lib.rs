#![allow(unexpected_cfgs)]
#![cfg_attr(not(feature = "std"), no_std)]

/// ------------------------------------------------------------------------
/// KIPIO ACCOUNT RUNTIME (SOVEREIGN IDENTITY RUNTIME)
/// ------------------------------------------------------------------------
///
/// PURPOSE:
/// This module represents the absolute Runtime execution environment for a
/// Sovereign Identity. It is NOT a standard EVM wallet. It is the central
/// nervous system that translates abstract, cryptographic-agnostic Authorizations
/// into deterministic, verifiable state changes on the blockchain.
///
/// RESPONSIBILITIES:
/// - State Administration: Manages Credentials, Sessions, Delegations, Capabilities,
///   and Restrictions.
/// - Policy Consumption: Consumes explicitly approved governance policies from KipioRecovery.
/// - Context Assembly: Builds the `ExecutionContext` — the Runtime's primary unit of work —
///   unifying identity state, active capabilities, restrictions, consumed policies, and proofs.
/// - Execution: Dispatches actions strictly when the ExecutionContext resolves successfully
///   across all validation phases.
///
/// ANTI-CORRUPTION LAYER (WHAT IT DOES NOT DO):
/// - It does NOT authenticate directly (Auth does this).
/// - It does NOT know what a Passkey, ECDSA, P256, or MPC is.
/// - It does NOT evaluate Recovery consensus (Thresholds, Guardians).
/// - It does NOT rely on ERC-4337 infrastructure (No Bundlers, Paymasters, or EntryPoints).
///
/// RUNTIME vs INFRASTRUCTURE — GOVERNING PRINCIPLE:
/// When a conflict arises between modeling the domain and modeling EVM infrastructure,
/// the domain always takes precedence. Infrastructure adapters (RuntimeAdapter7702,
/// RuntimeAdapter7560) are responsible for translating external transaction formats into
/// an `ExecutionContext` and invoking the Runtime. The Runtime itself never deforms to
/// accommodate a standard, a precompile, or a concrete API. Each structure here answers
/// first to a domain responsibility, and only then to an implementation need.
///
/// EXECUTION PIPELINE:
/// Phase 1 — assemble_context():  Build the ExecutionContext from caller input + storage.
/// Phase 2 — validate_context():  Verify every domain invariant (credential, session,
///                                 capabilities, restrictions, deadline).
/// Phase 2.5 — Auth delegation:   Cryptographic proof verification is delegated entirely
///                                 to KipioAuth. The Runtime never touches keys or curves.
/// Phase 3 — dispatch_execution(): Produce on-chain effects only after all validations pass.
///
/// ARCHITECTURAL ALIGNMENT:
/// Designed for execution layers like Arbitrum Stylus. Any future transport standard
/// (EIP-7702, RIP-7560, ERC-7579) will interact with this Runtime exclusively via
/// adapter layers, never by modifying the Runtime domain model.
/// ------------------------------------------------------------------------

extern crate alloc;

use alloc::{vec, vec::Vec};
use stylus_sdk::{
    alloy_primitives::{Address, B256, Bytes, U256, U8},
    alloy_sol_types::SolError,
    call::call,
    prelude::*,
    storage::{
        StorageAddress, StorageB256, StorageBool, StorageMap, StorageU256, StorageU8,
    },
};

// ==========================================
// ENUMS — DOMAIN DISCRIMINANTS
// ==========================================

/// @notice Standardized status flags for domain entities (Credentials, Sessions, Delegations).
/// @dev Shared across all lifecycle-managed entities in the Runtime.
/// `Expired` is a terminal state derived from time constraints, distinct from `Revoked`,
/// which is an explicit administrative action. Both are irreversible once reached.
#[repr(u8)]
#[derive(Clone, Copy, PartialEq, Eq)]
pub enum EntityStatus {
    Inactive = 0,
    Active = 1,
    Suspended = 2,
    Revoked = 3,
    Expired = 4,
}

impl EntityStatus {
    fn from_u8(value: u8) -> Self {
        match value {
            1 => Self::Active,
            2 => Self::Suspended,
            3 => Self::Revoked,
            4 => Self::Expired,
            _ => Self::Inactive,
        }
    }
}

/// @notice Domain discriminant for the semantic kind of a Capability.
///
/// ARCHITECTURAL DECISION: Capabilities are NOT modeled as raw EVM call descriptors
/// (target + selector + value_limit). That was infrastructure-level thinking from the
/// first draft. The domain knows nothing about EVM selectors at the capability level —
/// it knows about intentions. The infrastructure layer (adapters, verifiers) is
/// responsible for translating a CapabilityKind into the concrete on-chain action it
/// represents.
///
/// `DispatchCall` exists as the generic escape hatch for arbitrary EVM interactions,
/// but it is deliberately placed last in semantic priority. The domain's own capability
/// kinds (RotateCredential, CreateSession, etc.) always take modeling precedence over
/// EVM primitives.
///
/// Future capability kinds should be added here as the domain evolves, not as raw
/// EVM parameters in the caller's calldata.
#[repr(u8)]
#[derive(Clone, Copy, PartialEq, Eq)]
pub enum CapabilityKind {
    /// @dev Allows issuing a new Credential or rotating an existing one under this identity.
    RotateCredential = 1,
    /// @dev Allows creating a time-bound, narrowed Session from an existing Credential.
    CreateSession = 2,
    /// @dev Allows revoking an active Session before its natural expiration.
    RevokeSession = 3,
    /// @dev Allows ceding a strict subset of Capabilities to a Delegatee entity.
    GrantDelegation = 4,
    /// @dev Allows revoking a previously granted Delegation.
    RevokeDelegation = 5,
    /// @dev Allows consuming an APPROVED governance policy produced by KipioRecovery.
    ConsumePolicy = 6,
    /// @dev Generic EVM call dispatch. Modeled here as a domain Capability kind, but
    /// its execution is an infrastructure concern. Prefer explicit kinds where possible.
    DispatchCall = 7,
    /// @dev Domain-level object sharing. The infrastructure layer interprets what sharing means.
    ShareObject = 8,
    /// @dev Domain-level object storage. The infrastructure layer interprets what uploading means.
    UploadObject = 9,
    /// @dev Escape hatch for domain extensions not yet formalized. Use sparingly.
    Custom = 255,
}

#[allow(dead_code)]
impl CapabilityKind {
    /// @dev Converts a raw u8 discriminant to a CapabilityKind.
    /// Used when deserializing stored capability records.
    fn from_u8(value: u8) -> Self {
        match value {
            1 => Self::RotateCredential,
            2 => Self::CreateSession,
            3 => Self::RevokeSession,
            4 => Self::GrantDelegation,
            5 => Self::RevokeDelegation,
            6 => Self::ConsumePolicy,
            7 => Self::DispatchCall,
            8 => Self::ShareObject,
            9 => Self::UploadObject,
            _ => Self::Custom,
        }
    }
}

/// @notice Discriminant for the kind of Restriction applied to a domain entity.
///
/// ARCHITECTURAL DECISION: Restrictions are deliberately open-ended at the kind level.
/// Their enforcement logic lives in the infrastructure layer (Auth verifiers, Restriction
/// Evaluators). The Runtime only carries them inside the ExecutionContext as declarative
/// constraints. This means the Runtime remains agnostic to how restrictions are enforced,
/// which allows enforcement strategies to evolve without modifying the domain model.
///
/// Each variant's `encoded_value` in the parent `Restriction` struct is interpreted
/// differently per kind. The ABI encoding convention is documented per variant below.
/// The infrastructure layer is responsible for decoding and evaluating each constraint.
#[repr(u8)]
#[derive(Clone, Copy, PartialEq, Eq)]
pub enum RestrictionKind {
    /// @dev encoded_value = abi_encode(valid_from: u256, valid_until: u256)
    TimeWindow = 1,
    /// @dev encoded_value = abi_encode(max_gas: u256)
    GasLimit = 2,
    /// @dev encoded_value = abi_encode(chain_id: u256)
    ChainId = 3,
    /// @dev encoded_value = abi_encode(allowed_destination: address)
    Destination = 4,
    /// @dev encoded_value = abi_encode(max_calls: u256, window_seconds: u256)
    RateLimit = 5,
    /// @dev encoded_value = abi_encode(max_value: u256)
    ValueCeiling = 6,
    /// @dev encoded_value = abi_encode(max_executions: u256)
    ExecutionCount = 7,
    /// @dev encoded_value is opaque. The infrastructure layer determines interpretation.
    Custom = 255,
}

#[allow(dead_code)]
impl RestrictionKind {
    /// @dev Converts a raw u8 discriminant to a RestrictionKind.
    /// Used when deserializing stored restriction records.
    fn from_u8(value: u8) -> Self {
        match value {
            1 => Self::TimeWindow,
            2 => Self::GasLimit,
            3 => Self::ChainId,
            4 => Self::Destination,
            5 => Self::RateLimit,
            6 => Self::ValueCeiling,
            7 => Self::ExecutionCount,
            _ => Self::Custom,
        }
    }
}

// ==========================================
// EVENTS & ERRORS
// ==========================================

stylus_sdk::alloy_sol_types::sol! {
    // --- Events ---
    event CredentialRegistered(bytes32 indexed credentialId);
    event CredentialStatusChanged(bytes32 indexed credentialId, uint8 newStatus);
    event SessionCreated(bytes32 indexed sessionId, bytes32 indexed credentialId);
    event SessionRevoked(bytes32 indexed sessionId);
    event DelegationGranted(bytes32 indexed delegationId, address indexed delegatee);
    event DelegationRevoked(bytes32 indexed delegationId);
    event PolicyConsumed(bytes32 indexed policyId, bytes32 policyType);
    event ExecutionDispatched(address indexed target, bool success, bytes returnData);
    event RuntimeInitialized(address indexed registry, address indexed auth, address indexed recovery);
    event CapabilityGranted(bytes32 indexed credentialId, uint8 capabilityKind, bytes32 capabilityId);
    event CapabilityRevoked(bytes32 indexed credentialId, bytes32 capabilityId);
    event RestrictionApplied(bytes32 indexed entityId, uint8 restrictionKind);

    // --- Errors ---
    error Unauthorized();
    error AlreadyInitialized();
    error RuntimeNotInitialized();
    error IdentityNotFound();
    error InvalidCredentialState();
    error SessionExpiredOrInvalid();
    error DelegationLimitsExceeded();
    error CapabilityNotGranted(bytes4 selector);
    error CapabilityNotAvailable(uint8 kind);
    error RestrictionViolated(uint8 kind);
    error PolicyConsumptionFailed();
    error ContextAssemblyFailed();
    error ExecutionFailed(bytes data);
}

// ==========================================
// TRANSIENT DOMAIN STRUCTS (IN-MEMORY)
// ==========================================

/// @notice Represents a transversal condition that limits WHEN or HOW a domain entity may operate.
///
/// ARCHITECTURAL DECISION: Restriction was a first-class domain concept that appeared
/// consistently during design discussions but disappeared in the first implementation draft.
/// It has been restored here as its own struct because restrictions are NOT exclusive to
/// any single entity type. A Restriction can be attached to a Credential, a Session, a
/// Delegation, or a Capability interchangeably — they are a reutilizable concern of the
/// entire Runtime, not a property of one entity in particular.
///
/// The `encoded_value` is intentionally opaque at the domain level. The infrastructure
/// layer decodes it according to the `kind` discriminant (see `RestrictionKind`
/// documentation for the ABI encoding convention per variant). The Runtime carries
/// Restrictions inside the ExecutionContext; it does not evaluate them directly.
///
/// TODO: Define a stable ABI encoding convention for each RestrictionKind's encoded_value.
///   The encoding is currently described in comments on RestrictionKind variants, but
///   there is no enforced schema. A sol!-defined typed struct per kind, or a canonical
///   CBOR/protobuf-like encoding, would provide stronger guarantees.
///   Alternatives: typed union via sol! structs, opaque bytes with off-chain schema registry.
///   Decision can be postponed until the first Restriction Evaluator is implemented,
///   since the evaluator will define what it needs to decode.
#[derive(Clone)]
pub struct Restriction {
    /// @dev Semantic discriminant. Determines how `encoded_value` is decoded and evaluated.
    pub kind: RestrictionKind,
    /// @dev ABI-encoded restriction parameters. Interpretation is infrastructure-specific.
    /// See `RestrictionKind` variant documentation for expected encoding per kind.
    pub encoded_value: Bytes,
}

/// @notice Represents what a domain entity is explicitly authorized to do.
///
/// ARCHITECTURAL DECISION (v2 refinement): The first draft modeled Capability as an EVM
/// call descriptor: `(target: Address, selector: [u8; 4], value_limit: U256)`. That was
/// infrastructure-level thinking embedded in a domain struct. The domain does not think
/// in terms of EVM selectors or target addresses at the capability level — it thinks in
/// terms of intentions (RotateCredential, CreateSession, GrantDelegation, etc.).
///
/// This struct now reflects that correction:
/// - `id`: stable identifier for storage references, audit trails, and cross-entity linking.
/// - `kind`: the domain-level intention this capability represents.
/// - `constraints`: zero or more Restrictions scoped specifically to this Capability,
///   applied in addition to any entity-level restrictions already in scope.
/// - `metadata`: opaque bytes interpreted by the infrastructure layer to resolve the
///   Capability into a concrete action. For `DispatchCall`, this might encode
///   (target, selector, value_limit). For `ShareObject`, it might encode an object CID.
///   The domain does not interpret this field.
///
/// TODO: Define a stable metadata encoding convention per CapabilityKind.
///   The current `metadata: Bytes` field is intentionally opaque to allow flexibility
///   during early iterations. Once each CapabilityKind's infrastructure requirements
///   are stable, a typed metadata schema should replace the raw bytes.
///   Alternatives: a sol!-defined struct per kind (verbose but type-safe), a tag-length-value
///   encoding, or a CBOR schema. Decision can be postponed until the first
///   infrastructure adapter (RuntimeAdapter7702) is built, as the adapter will
///   define what it needs to encode and decode for each kind.
#[derive(Clone)]
pub struct Capability {
    /// @dev Stable identifier used for storage lookups, audit events, and deduplication.
    pub id: B256,
    /// @dev Domain-level intention this Capability represents. Never an EVM primitive.
    pub kind: CapabilityKind,
    /// @dev Restrictions scoped to this specific Capability, evaluated in addition
    /// to any Credential-, Session-, or Delegation-level restrictions already in scope.
    pub constraints: Vec<Restriction>,
    /// @dev Infrastructure-specific encoding. Opaque to the domain layer.
    /// The infrastructure translates this into the concrete action for the given kind.
    pub metadata: Bytes,
}

/// @notice Verifiable evidence of intent presented by a caller to the Runtime.
///
/// ARCHITECTURAL DECISION (v2 refinement): Authorization has been expanded beyond the
/// initial `(credential, session, delegation, proof)` tuple. It now also explicitly
/// declares which capabilities the caller intends to exercise (`exercised_capabilities`)
/// and which restrictions the caller acknowledges (`accepted_restrictions`).
///
/// This expansion is a security requirement: it allows Auth to verify that the
/// cryptographic proof was constructed for the exact scope being claimed. Without this,
/// a proof obtained for a narrow capability (e.g., ShareObject) could potentially be
/// replayed to claim a broader one (e.g., RotateCredential). By binding the proof to a
/// declared capability set and a declared restriction set, the Runtime and Auth can
/// together enforce scope integrity.
///
/// `context_data` remains intentionally opaque — it carries ephemeral environmental
/// data (chainId, nonces, timestamps) whose interpretation belongs entirely to Auth
/// verifiers, not to the Runtime.
pub struct Authorization {
    /// @dev Credential establishing identity authority for this authorization.
    pub credential_id: B256,
    /// @dev Session scoping this operation. B256::ZERO if acting directly via credential.
    pub session_id: B256,
    /// @dev Delegation scoping this operation. B256::ZERO if acting as self (no delegation).
    pub delegation_id: B256,
    /// @dev IDs of the Capabilities the caller declares to be exercising in this operation.
    /// Auth must verify that the presented proof covers exactly this capability set.
    pub exercised_capabilities: Vec<B256>,
    /// @dev Restrictions the caller explicitly acknowledges in this authorization scope.
    /// Auth must verify these match the restrictions actually configured on the entity.
    pub accepted_restrictions: Vec<Restriction>,
    /// @dev Ephemeral environmental data (e.g., chainId, nonces, timestamps).
    /// Passed verbatim to Auth verifiers for replay and binding validation.
    pub context_data: Bytes,
    /// @dev Raw cryptographic proof. Intentionally opaque — the Runtime does not interpret
    /// signatures, keys, curves, or algorithms. Auth Verifiers handle all of that.
    pub proof: Bytes,
}

/// @notice Operational metadata for a single execution attempt.
/// @dev Separated from ExecutionContext to organize the context struct by concern.
/// Carries parameters relevant to replay prevention and ordering guarantees,
/// which are distinct from the identity state and capability scope of the execution.
pub struct ExecutionMetadata {
    /// @dev Anti-replay nonce for this specific execution attempt.
    pub nonce: U256,
    /// @dev Absolute block timestamp after which this execution must be rejected.
    pub deadline: U256,
    /// @dev Chain ID this execution is explicitly bound to. Prevents cross-chain replay.
    pub chain_id: U256,
}

/// @notice The primary unit of work in the Runtime. The heart of the domain.
///
/// ARCHITECTURAL DECISION (v2 refinement): ExecutionContext has been promoted from a
/// thin wrapper to the central domain object. Everything the Runtime needs to decide
/// whether and how to proceed is contained here.
///
/// The Runtime pipeline processes exactly one ExecutionContext per operation:
///   Phase 1: assemble_context() — builds it from storage + caller input.
///   Phase 2: validate_context() — verifies every invariant against it.
///   Phase 3: dispatch_execution() — produces effects only if all phases passed.
///
/// Critically, external adapters (EIP-7702, RIP-7560, etc.) are responsible for Phase 1.
/// They translate their respective transaction formats into an ExecutionContext and feed
/// it to the Runtime. The Runtime itself never changes regardless of the source standard.
/// This is what "the domain takes priority over infrastructure" means in practice.
///
/// TODO: Define a canonical serialization format for ExecutionContext so that adapters
///   across different transport standards can produce identical representations for
///   equivalent operations. Currently the struct is in-memory only (constructed fresh
///   per call). If cross-contract context passing becomes necessary (e.g., a delegating
///   contract producing a context for this Runtime), a stable ABI encoding is required.
///   Alternatives: sol!-defined struct encoding (requires all fields to be ABI-compatible),
///   custom codec (flexible but maintenance burden), CBOR (off-chain friendly).
///   Decision can be postponed until the first cross-contract adapter pattern emerges.
pub struct ExecutionContext {
    // ---- IDENTITY LAYER ----
    /// @dev The sovereign identity address this execution operates on behalf of.
    pub identity: Address,
    /// @dev The active Credential establishing authority for this operation.
    pub credential_id: B256,
    /// @dev Session scoping this execution. B256::ZERO for direct credential operations.
    pub session_id: B256,
    /// @dev Delegation scoping this execution. B256::ZERO for self-originated operations.
    pub delegation_id: B256,

    // ---- CAPABILITY & RESTRICTION LAYER ----
    /// @dev The Capabilities in scope for this execution, loaded from storage and filtered
    /// by session and delegation constraints. This is the authoritative capability set
    /// the Runtime uses for validation — not the raw IDs from the Authorization.
    pub active_capabilities: Vec<Capability>,
    /// @dev Restrictions currently in effect, aggregated from the active Credential,
    /// Session (if present), Delegation (if present), and individual Capability constraints.
    /// The union of all applicable restrictions must be satisfied for execution to proceed.
    pub active_restrictions: Vec<Restriction>,

    // ---- POLICY LAYER ----
    /// @dev IDs of governance policies already consumed during this context's assembly
    /// (e.g., a ROTATE_KEY policy consumed to enable credential rotation). Maintained
    /// to prevent double-consumption within a single execution cycle.
    pub consumed_policy_ids: Vec<B256>,

    // ---- AUTHORIZATION EVIDENCE ----
    /// @dev The verifiable authorization presented by the caller.
    /// Auth will validate the proof against the credential, capabilities, and restrictions
    /// declared herein before the Runtime proceeds to dispatch.
    pub authorization: Authorization,

    // ---- EXECUTION TARGET ----
    /// @dev Destination of the operation. For DispatchCall: an external EVM address.
    /// For internal Runtime operations: may be the contract's own address.
    pub target: Address,
    /// @dev Native value (ETH/MATIC/etc.) transferred alongside this execution, if any.
    pub value: U256,
    /// @dev Operation payload. Opaque to the domain. The infrastructure interprets
    /// it based on the active capability kinds in scope.
    pub calldata: Bytes,

    // ---- EXECUTION METADATA ----
    pub metadata: ExecutionMetadata,
}

/// @notice Conceptual snapshot of the Runtime's full operational state for one identity.
///
/// ARCHITECTURAL DECISION: RuntimeState does NOT replace the on-chain StorageMaps.
/// Those remain the single authoritative source of truth on-chain. RuntimeState is an
/// in-memory projection — a holistic view assembled from storage when the Runtime needs
/// to reason about the identity's complete operational picture, without scattering
/// storage reads across multiple uncoordinated methods.
///
/// It answers the question: "What is the full operational state of this identity right
/// now?" That question naturally arises during ExecutionContext assembly (Phase 1) because
/// context assembly requires reading credentials, sessions, delegations, capabilities,
/// restrictions, and consumed policies simultaneously to produce a coherent context.
///
/// TODO: Implement `KipioAccount::load_runtime_state(identity: Address) -> RuntimeState`.
///   This function would read from all relevant StorageMaps to produce a consistent
///   in-memory snapshot used during context assembly.
///   Not yet implemented because: (a) the Capability storage schema (flattened maps with
///   manual slot hashing) is still being finalized; (b) the Restriction storage schema
///   is still being finalized; (c) iterating over active entity IDs requires count
///   cursors in storage (e.g., credential_count, session_count) that haven't been added yet.
///   Alternatives: lazy field-by-field loading (simpler but less coherent),
///   a dedicated view function per concern (more granular, easier to test),
///   event-sourcing the state off-chain (shifts complexity to indexers).
///   Decision on loading strategy can be postponed until Phase 1 (assemble_context) is
///   implemented, as the implementation will reveal what the optimal loading pattern is.
#[allow(dead_code)]
pub struct RuntimeState {
    /// @dev The identity this state snapshot belongs to.
    pub identity: Address,
    /// @dev IDs of Credentials currently registered and not revoked or expired.
    pub active_credential_ids: Vec<B256>,
    /// @dev IDs of Sessions currently active and not expired.
    pub active_session_ids: Vec<B256>,
    /// @dev IDs of Delegations currently active and not expired.
    pub active_delegation_ids: Vec<B256>,
    /// @dev Capabilities currently available, spanning all active Credentials.
    /// Filtered by session scope during context assembly if a session is present.
    pub available_capabilities: Vec<Capability>,
    /// @dev Restrictions currently in effect across all active entities for this identity.
    pub effective_restrictions: Vec<Restriction>,
    /// @dev Policy IDs already consumed by this Runtime. Used to prevent re-consumption.
    pub consumed_policy_ids: Vec<B256>,
    /// @dev Current nonce for anti-replay, in whichever nonce domain applies.
    pub current_nonce: U256,
}

// ==========================================
// STORAGE DOMAIN STRUCTS
// ==========================================

/// @notice Persistent storage representation of a Credential.
/// @dev Represents a mechanism by which an authorization can occur.
/// Never contains cryptographic keys, only lifecycle state and configuration.
///
/// TODO: Add `capability_count: StorageU256` as a cursor for iterating stored Capabilities.
///   Stylus does not natively support dynamic nested arrays without manual EVM slot hashing.
///   The intended approach is a flattened mapping held at the KipioAccount level:
///   `capabilities: StorageMap<B256 (hash(credential_id, capability_id)), StorageU8 (kind)>`
///   with `capability_count` here acting as an enumeration cursor.
///   Not implemented yet because the full Capability storage schema (including how
///   Capability.constraints/Restriction are stored) is being finalized first.
///   Decision on schema can be postponed until the first `GrantCapability` method is built.
///
/// TODO: Add `restriction_count: StorageU256` for analogous Restriction enumeration.
///   Same rationale as capability_count above.
#[storage]
pub struct CredentialStorage {
    pub status: StorageU8,
    pub created_at: StorageU256,
}

/// @notice Persistent storage representation of a Session.
/// @dev Represents a temporary, narrowing scope derived from a Credential.
/// Sessions NEVER expand capabilities — they only further constrain them.
/// A Session cannot grant access that the parent Credential does not already hold.
///
/// TODO: Add a reference count or cursor for the subset of Capabilities this Session
///   restricts the parent Credential to. Same Stylus nested-array limitation applies.
///   Not yet implemented pending Capability storage schema finalization.
///
/// TODO: Add restriction_count for Restrictions applied specifically to this Session,
///   beyond those already on the parent Credential. Pending Restriction storage schema.
#[storage]
pub struct SessionStorage {
    pub credential_id: StorageB256,
    pub status: StorageU8,
    pub expires_at: StorageU256,
}

/// @notice Persistent storage representation of a Delegation.
/// @dev Represents controlled cession of a Capability subset to an external entity (Delegatee).
/// Delegations, like Sessions, NEVER elevate capabilities beyond what the delegating
/// Credential holds. They can only restrict further. A Delegatee cannot do more than
/// the delegating identity is itself authorized to do.
///
/// TODO: Add capability reference count for the subset of Capabilities ceded to the delegatee.
///   Same Stylus nested-array limitation and dependency on Capability storage schema.
///
/// TODO: Add restriction_count for Restrictions constraining this specific Delegation,
///   applied in addition to the parent Credential's restrictions.
#[storage]
pub struct DelegationStorage {
    pub delegatee: StorageAddress,
    pub status: StorageU8,
    pub expires_at: StorageU256,
}

// ==========================================
// MAIN STORAGE — ACCOUNT RUNTIME STATE
// ==========================================

/// @notice On-chain persistent storage for the Kipio Account Runtime.
/// @dev This is the persistent counterpart to the in-memory `RuntimeState`. Each
/// StorageMap here represents a dimension of the Runtime's operational state.
/// Together they define everything the Runtime persists between calls.
///
/// `#[storage]` + `#[entrypoint]` declares this as the root contract storage slot
/// and the Stylus public dispatch target. All public methods are defined on this struct.
#[storage]
#[entrypoint]
pub struct KipioAccount {
    // ---- PROTOCOL MODULE REFERENCES ----

    /// @notice Address of KipioRegistry (authoritative module directory).
    /// @dev Used to validate module addresses at initialization and,
    /// in the future, to dynamically resolve module upgrades.
    pub registry_address: StorageAddress,

    /// @notice Address of KipioAuth (cryptographic authorization verifier).
    /// @dev The Runtime delegates ALL signature and proof verification here.
    /// It never interprets keys, signing algorithms, or cryptographic curves directly.
    pub auth_address: StorageAddress,

    /// @notice Address of KipioRecovery (governance policy engine).
    /// @dev The Runtime queries this module only to consume approved policies.
    /// It never reads Guardian sets, thresholds, vote counts, or Recovery internals.
    pub recovery_address: StorageAddress,

    // ---- IDENTITY STATE ADMINISTRATION ----

    /// @notice Registered Credentials for this identity.
    pub credentials: StorageMap<B256, CredentialStorage>,

    /// @notice Active Sessions derived from Credentials.
    pub sessions: StorageMap<B256, SessionStorage>,

    /// @notice Granted Delegations from this identity to external delegatees.
    pub delegations: StorageMap<B256, DelegationStorage>,

    // ---- POLICY CONSUMPTION REGISTRY ----

    /// @notice Tracks which governance policy IDs have been consumed by this Runtime.
    /// @dev Prevents replay of the same approved policy across multiple execution cycles.
    /// A `true` entry means the policy has been finalized at the Recovery level and
    /// its mandate has been applied. It cannot be re-consumed.
    pub consumed_policies: StorageMap<B256, StorageBool>,

    // ---- ANTI-REPLAY ----

    /// @notice Per-operation nonce tracking for replay prevention.
    /// @dev The nonce key schema is intentionally flexible to support multiple nonce
    /// domains once the anti-replay strategy is finalized with KipioAuth.
    ///
    /// TODO: Formalize the nonce domain schema in coordination with KipioAuth.
    ///   The final schema should define explicit nonce domains to prevent cross-domain
    ///   replay attacks. Options under consideration:
    ///   (a) Global monotonic nonce per identity — simplest, prevents parallelism.
    ///   (b) Per-Credential nonces — allows parallel credential usage, more complex.
    ///   (c) Bitmap-based nonces — allows out-of-order submission, highest complexity.
    ///   Decision depends on the concurrency model Auth will enforce.
    ///   Can be postponed until the KipioAuth interface is stable, since Auth is the
    ///   module that will validate nonce uniqueness using this map as its source.
    pub nonces: StorageMap<B256, StorageU256>,
}

// ==========================================
// PRIVATE RUNTIME HELPERS
// ==========================================

impl KipioAccount {
    /// @dev Guards every operational method. Reverts if the Runtime has not been
    /// initialized, preventing operations on an unlinked module instance.
    fn require_initialized(&self) -> Result<(), Vec<u8>> {
        if self.registry_address.get() == Address::ZERO {
            return Err(RuntimeNotInitialized {}.abi_encode());
        }
        Ok(())
    }

    /// @dev Phase 1 of the Runtime pipeline: assembles an ExecutionContext from caller
    /// input and on-chain state. Does NOT validate — it only gathers data.
    /// Validation is strictly the responsibility of Phase 2 (validate_context).
    ///
    /// TODO: Implement full RuntimeState loading before context assembly.
    ///   The complete implementation reads from all relevant StorageMaps to produce a
    ///   coherent in-memory RuntimeState snapshot, then derives the ExecutionContext from it.
    ///   Currently the active_capabilities and active_restrictions fields are empty placeholders.
    ///   Blocked on: (a) Capability storage schema finalization, (b) Restriction storage
    ///   schema finalization, (c) addition of count cursors to CredentialStorage/SessionStorage.
    ///
    /// TODO: Populate consumed_policy_ids from the consumed_policies StorageMap.
    ///   Requires iterating known policy IDs for this identity, which in turn requires
    ///   an index of policy IDs stored at this Runtime — not yet implemented.
    ///
    /// TODO: Populate chain_id from the execution environment once the Stylus SDK
    ///   exposes `vm().chain_id()`. Currently hardcoded to U256::ZERO as a placeholder.
    #[allow(clippy::too_many_arguments)]
    fn assemble_context(
        &self,
        identity: Address,
        target: Address,
        value: U256,
        calldata: Bytes,
        credential_id: B256,
        session_id: B256,
        delegation_id: B256,
        exercised_capabilities: Vec<B256>,
        context_data: Bytes,
        proof: Bytes,
        nonce: U256,
        deadline: U256,
    ) -> ExecutionContext {
        let authorization = Authorization {
            credential_id,
            session_id,
            delegation_id,
            exercised_capabilities,
            // TODO: Derive accepted_restrictions from the entity's stored configuration.
            // The caller should not self-declare restrictions; the Runtime must load them
            // from storage and compare them against what the caller's proof was bound to.
            // Pending Restriction storage schema finalization.
            accepted_restrictions: Vec::new(),
            context_data,
            proof,
        };

        let metadata = ExecutionMetadata {
            nonce,
            deadline,
            // TODO: Replace with vm().chain_id() once exposed by the Stylus SDK.
            chain_id: U256::ZERO,
        };

        ExecutionContext {
            identity,
            credential_id,
            session_id,
            delegation_id,
            // TODO: Load from storage via capability schema once finalized.
            active_capabilities: Vec::new(),
            // TODO: Aggregate from Credential, Session, Delegation, and Capability
            // restriction lists once storage schema is finalized.
            active_restrictions: Vec::new(),
            // TODO: Load from consumed_policies map, filtered to this identity's policy IDs.
            consumed_policy_ids: Vec::new(),
            authorization,
            target,
            value,
            calldata,
            metadata,
        }
    }

    /// @dev Phase 2 of the Runtime pipeline: validates every domain invariant against
    /// the assembled ExecutionContext. Returns Ok(()) only if all invariants are satisfied.
    ///
    /// Validation order (fail-fast on first violation):
    ///   1. Credential must be Active.
    ///   2. Session must be Active and not expired (if session_id != B256::ZERO).
    ///   3. Delegation must be Active and not expired (if delegation_id != B256::ZERO).
    ///   4. Each ID in authorization.exercised_capabilities must map to an entry in
    ///      context.active_capabilities.
    ///   5. Each Restriction in context.active_restrictions must not be violated.
    ///   6. context.metadata.deadline must not be breached.
    ///
    /// TODO: Implement steps 2–6.
    ///   Step 1 is implemented. Steps 2–6 require the storage reads in assemble_context
    ///   to be completed first, so that context.active_capabilities and
    ///   context.active_restrictions are fully populated before validation runs.
    ///   Restriction evaluation (step 5) will likely be delegated to a dedicated
    ///   RestrictionEvaluator sub-module or to KipioAuth, since some restrictions
    ///   (e.g., RateLimit) require state that Auth may maintain externally.
    fn validate_context(&self, context: &ExecutionContext) -> Result<(), Vec<u8>> {
        // Step 1: Credential must be Active.
        let cred = self.credentials.getter(context.credential_id);
        let cred_status = EntityStatus::from_u8(cred.status.get().as_limbs()[0] as u8);
        if cred_status != EntityStatus::Active {
            return Err(InvalidCredentialState {}.abi_encode());
        }

        // TODO: Step 2 — Validate Session lifecycle (if session_id != B256::ZERO).
        //   Read SessionStorage, check status == Active, check expires_at > now.
        //   Error on failure: SessionExpiredOrInvalid.

        // TODO: Step 3 — Validate Delegation lifecycle (if delegation_id != B256::ZERO).
        //   Read DelegationStorage, check status == Active, check expires_at > now.
        //   Error on failure: DelegationLimitsExceeded (or a dedicated DelegationExpired error).

        // TODO: Step 4 — Verify each exercised capability ID exists in active_capabilities.
        //   Iterate context.authorization.exercised_capabilities, check each against
        //   context.active_capabilities by id. If any is missing: CapabilityNotAvailable(kind).

        // TODO: Step 5 — Evaluate active restrictions.
        //   Iterate context.active_restrictions, check each kind against runtime state.
        //   Enforcement strategy (inline vs. delegated to Auth) to be decided when
        //   the Restriction Evaluator design is finalized.
        //   Error on violation: RestrictionViolated(kind as u8).

        // TODO: Step 6 — Check execution deadline.
        //   if vm().block_timestamp() > context.metadata.deadline { return Err(SessionExpiredOrInvalid) }
        //   Requires vm() access, which means validate_context may need to become &mut self
        //   or the timestamp must be passed in. Architecture decision pending.

        Ok(())
    }

    /// @dev Phase 3 of the Runtime pipeline: dispatches the execution after all
    /// validations have passed. Produces on-chain effects.
    ///
    /// FIXED BORROW CHECKER PATHWAY:
    /// `Call::new_payable` takes a mutable borrow of `self` to configure value transfer.
    /// That borrow's lifetime ends before the subsequent `self.vm()` call for logging,
    /// satisfying the Stylus strict aliasing rules for the storage access model.
    fn dispatch_execution(&mut self, context: ExecutionContext) -> Result<Bytes, Vec<u8>> {
        // FIXED BORROW CHECKER PATHWAY:
        // First, instantiate the mutable execution context `Call` layout out of `self`.
        // This temporarily borrows `self` as mutable, ending its lifetime immediately after assignment.
        let call_context = stylus_sdk::prelude::Call::new_payable(self, context.value);

        // Second, invoke the environment safely. `self.vm()` can now be called because
        // the prior mutable borrow has fully resolved.
        let result = call(
            self.vm(),
            call_context,
            context.target,
            context.calldata.as_ref(),
        );

        match result {
            Ok(return_data) => {
                self.vm().log(ExecutionDispatched {
                    target: context.target,
                    success: true,
                    returnData: return_data.clone().into(),
                });
                Ok(return_data.into())
            }
            Err(err) => {
                // FIX: Match exact variant for v0.10.7 Error handling from external calls.
                let err_data = match err {
                    stylus_sdk::prelude::errors::Error::Revert(data) => data,
                    _ => alloc::vec![], // Fallback if no specific Revert data is available.
                };

                self.vm().log(ExecutionDispatched {
                    target: context.target,
                    success: false,
                    returnData: err_data.clone().into(),
                });

                // FIX: Requires explicit sol! encoding for custom error types.
                Err(ExecutionFailed { data: err_data.into() }.abi_encode())
            }
        }
    }
}

// ==========================================
// PUBLIC RUNTIME INTERFACE
// ==========================================

#[public]
impl KipioAccount {
    /// @notice Initializes the Account Runtime, linking it to its Kipio ecosystem modules.
    /// @dev Must be called exactly once after deployment. Idempotency guard prevents
    /// re-initialization attacks by checking that registry_address is still zero.
    /// Rejects zero-address inputs for all three module references.
    ///
    /// TODO: Optionally verify that each provided address is a registered Kipio module
    ///   via KipioRegistry before storing them. This would prevent misconfiguration at
    ///   initialization time (e.g., accidentally linking to a wrong or malicious contract).
    ///   Not yet implemented because the KipioRegistry query interface is not yet stable.
    ///   Can be postponed until the Registry interface is finalized.
    pub fn initialize(
        &mut self,
        registry: Address,
        auth: Address,
        recovery: Address,
    ) -> Result<(), Vec<u8>> {
        if self.registry_address.get() != Address::ZERO {
            // FIX: Custom Sol errors require explicit abi_encode() to cast to Vec<u8>.
            return Err(AlreadyInitialized {}.abi_encode());
        }
        if registry == Address::ZERO || auth == Address::ZERO || recovery == Address::ZERO {
            return Err(Unauthorized {}.abi_encode());
        }

        self.registry_address.set(registry);
        self.auth_address.set(auth);
        self.recovery_address.set(recovery);

        self.vm().log(RuntimeInitialized { registry, auth, recovery });
        Ok(())
    }

    // ==========================================
    // CREDENTIAL MANAGEMENT
    // ==========================================

    /// @notice Registers a new Credential under this identity's Runtime.
    /// @dev Credentials represent authorization mechanisms, never cryptographic keys.
    /// The credential_id is an opaque identifier chosen by the caller; the Runtime
    /// does not interpret it beyond tracking its lifecycle state.
    ///
    /// TODO: Require that this call originates from the Account itself via execute().
    ///   The intended pattern is: msg_sender() == contract_address() (self-authorization).
    ///   Not enforced yet because execute() is not fully implemented. Enforcing it now
    ///   would make it impossible to bootstrap the first credential into the Runtime,
    ///   since there would be no credential to authorize the call with. Once execute()
    ///   is complete and a bootstrap mechanism is defined (e.g., an initialization-phase
    ///   genesis credential), this guard must be added and the TODO removed.
    ///
    /// FIX: block_timestamp is extracted before acquiring the mutable storage reference
    ///   to comply with Stylus borrow checker rules (cannot hold vm() and storage
    ///   references simultaneously).
    pub fn add_credential(&mut self, credential_id: B256) -> Result<(), Vec<u8>> {
        self.require_initialized()?;

        // FIX: Extract block_timestamp before obtaining mutable reference to storage
        // to comply with strict Rust borrow checker rules.
        let timestamp = U256::from(self.vm().block_timestamp());

        let mut cred = self.credentials.setter(credential_id);
        cred.status.set(U8::from(EntityStatus::Active as u8));
        cred.created_at.set(timestamp);

        self.vm().log(CredentialRegistered { credentialId: credential_id });
        Ok(())
    }

    /// @notice Permanently revokes an existing Credential.
    /// @dev Revocation is terminal — a Revoked Credential cannot be reactivated.
    /// Attempting to revoke an Inactive or already-Revoked credential is an error,
    /// as it signals an inconsistent caller state.
    ///
    /// TODO: Require self-authorization via execute() (see add_credential TODO).
    ///
    /// TODO: Cascade revocation to all Sessions and Delegations derived from this Credential.
    ///   Architecturally, revoking a Credential should implicitly invalidate all Sessions
    ///   and Delegations that depend on it. Currently validate_context only checks the
    ///   Credential's own status, so a Session derived from a revoked Credential would
    ///   still appear Active in storage.
    ///   Not implemented yet because iterating dependent Sessions/Delegations requires
    ///   count cursors (session_count, delegation_count) that haven't been added to
    ///   CredentialStorage. Alternatively, validate_context can eagerly check the parent
    ///   Credential's status when validating a Session — this is likely the preferred
    ///   approach since it avoids storage writes during revocation.
    ///   Decision can be postponed until validate_context steps 2-3 are implemented.
    pub fn revoke_credential(&mut self, credential_id: B256) -> Result<(), Vec<u8>> {
        self.require_initialized()?;

        let mut cred = self.credentials.setter(credential_id);

        // FIX: Use from_u8() to read the current status, eliminating the dead_code warning
        // by actively exercising the EntityStatus converter in production logic.
        let current_status = EntityStatus::from_u8(cred.status.get().as_limbs()[0] as u8);

        if current_status == EntityStatus::Inactive || current_status == EntityStatus::Revoked {
            // FIX: Custom Sol errors require explicit abi_encode() to cast to Vec<u8>.
            return Err(InvalidCredentialState {}.abi_encode());
        }

        cred.status.set(U8::from(EntityStatus::Revoked as u8));

        self.vm().log(CredentialStatusChanged {
            credentialId: credential_id,
            newStatus: EntityStatus::Revoked as u8,
        });
        Ok(())
    }

    // ==========================================
    // SESSION MANAGEMENT
    // ==========================================

    /// TODO: Implement create_session(credential_id, session_id, expires_at, ...).
    ///   A Session binds to a parent Credential and introduces a time bound plus a
    ///   narrowed Capability subset. The parent Credential must be Active. The Session's
    ///   Capabilities must be a strict subset of the Credential's Capabilities — the
    ///   Runtime must verify this during creation to enforce the no-elevation principle.
    ///   Requires: Capability storage schema, count cursors in CredentialStorage.
    ///   Self-authorization guard (execute() pipeline) must also be in place before
    ///   this method is exposed, to prevent unauthorized session creation.

    /// TODO: Implement revoke_session(session_id).
    ///   Must verify that msg_sender is the sovereign identity (self-authorization).
    ///   Revocation is terminal — a revoked Session cannot be reactivated.
    ///   Should emit SessionRevoked event.

    // ==========================================
    // DELEGATION MANAGEMENT
    // ==========================================

    /// TODO: Implement grant_delegation(delegation_id, delegatee, capability_ids, restrictions, ...).
    ///   Creates a cession of a Capability subset to a Delegatee address.
    ///   The delegating entity must currently hold each capability being delegated.
    ///   Delegations can carry additional Restrictions beyond those of the parent entity.
    ///   Requires: Capability storage schema, Restriction storage schema.
    ///   No-elevation invariant must be enforced: delegatee cannot receive capabilities
    ///   not held by the delegating Credential.

    /// TODO: Implement revoke_delegation(delegation_id).
    ///   Must verify that msg_sender is the delegating identity (self-authorization).
    ///   Should emit DelegationRevoked event.

    // ==========================================
    // POLICY CONSUMPTION
    // ==========================================

    /// @notice Consumes a verified governance policy from KipioRecovery.
    /// @dev This module NEVER asks Recovery about guardians, thresholds, or approval counts.
    /// It only asks: "Is this policy APPROVED?" and then records its consumption locally.
    /// The policy's semantic intent (e.g., ROTATE_KEY) is translated into Credential
    /// state mutations by this Runtime. This is the only interface between Account and Recovery.
    ///
    /// TODO: Implement the cross-contract call to KipioRecovery::get_policy_record(request_id).
    ///   On APPROVED status, proceed. On any other status, revert with PolicyConsumptionFailed.
    ///   Blocked on: stable sol_interface! definition for KipioRecovery's external ABI.
    ///
    /// TODO: Implement policy intent translation.
    ///   Map KipioRecovery's POLICY_TYPE_* constants (e.g., ROTATE_KEY) to the corresponding
    ///   Runtime state mutations (e.g., revoke current active Credential, register new one).
    ///   Requires a registry of policy type → mutation function mappings, which should
    ///   be defined once the full set of supported policy types is known.
    ///
    /// TODO: Call KipioRecovery::consume_policy(request_id) AFTER the local state mutation.
    ///   The finalization call to Recovery must happen last to prevent partial-state failures
    ///   (if the local mutation succeeds but the Recovery call fails, the state would be
    ///   inconsistent). The ordering is: load → validate → mutate local state →
    ///   consume at Recovery → emit event.
    pub fn consume_approved_policy(&mut self, request_id: B256) -> Result<(), Vec<u8>> {
        self.require_initialized()?;

        // Guard against double-consumption at the Runtime level before calling Recovery.
        if self.consumed_policies.getter(request_id).get() {
            return Err(PolicyConsumptionFailed {}.abi_encode());
        }

        let _recovery_addr = self.recovery_address.get();

        // TODO: Cross-contract call to KipioRecovery::get_policy_record(request_id).
        // TODO: Validate returned status == APPROVED. Revert with PolicyConsumptionFailed otherwise.
        // TODO: Translate policy_type to the appropriate Runtime state mutation.
        // TODO: Call KipioRecovery::consume_policy(request_id) to finalize state there.

        self.consumed_policies.setter(request_id).set(true);

        // TODO: Emit PolicyConsumed with the actual policy_type value returned from Recovery.
        // self.vm().log(PolicyConsumed { policyId: request_id, policyType: policy_type });

        Ok(())
    }

    // ==========================================
    // RUNTIME EXECUTION PIPELINE
    // ==========================================

    /// @notice Primary entry point for executing operations under this identity's authority.
    ///
    /// ARCHITECTURAL DECISION (v2 refinement): execute() no longer constructs the
    /// ExecutionContext inline. The Runtime now separates the three execution phases
    /// explicitly:
    ///
    ///   Phase 1 — assemble_context():    Build the ExecutionContext from caller input + storage.
    ///   Phase 2 — validate_context():    Verify every domain invariant against the assembled context.
    ///   Phase 2.5 — Auth delegation:     Delegate cryptographic proof verification to KipioAuth.
    ///   Phase 3 — dispatch_execution():  Produce on-chain effects only after all phases pass.
    ///
    /// This separation has a critical architectural consequence: external adapters
    /// (RuntimeAdapter7702, RuntimeAdapter7560, etc.) can each assemble an ExecutionContext
    /// in their own way (Phase 1) and then pass it directly to the Runtime at Phase 2.
    /// The Runtime's core domain logic never changes regardless of the transport standard.
    ///
    /// ABI NOTE: This function still accepts individual parameters because Stylus ABI
    /// does not natively support passing complex structs as calldata. The parameters are
    /// immediately assembled into an ExecutionContext at the start of Phase 1.
    ///
    /// TODO: Introduce a `build_and_execute(context_bytes: Bytes)` variant that accepts
    ///   an ABI-encoded ExecutionContext, enabling the adapter pattern described above.
    ///   Blocked on: stable ABI encoding for ExecutionContext (see struct documentation).
    ///
    /// TODO: Implement Phase 2.5 — KipioAuth delegation.
    ///   After structural validation (Phase 2) and before dispatch (Phase 3), the Runtime
    ///   must call KipioAuth::verify_authorization(context.authorization, ...) to validate
    ///   the cryptographic proof. Auth evaluates the signature/proof without the Runtime
    ///   knowing the algorithm, key type, or curve. If Auth returns false, revert with
    ///   Unauthorized(). Not yet implemented because the KipioAuth external interface
    ///   (sol_interface!) is not yet stable.
    pub fn execute(
        &mut self,
        target: Address,
        value: U256,
        calldata: Bytes,
        credential_id: B256,
        session_id: B256,
        delegation_id: B256,
        exercised_capabilities: Vec<B256>,
        context_data: Bytes,
        proof: Bytes,
        nonce: U256,
        deadline: U256,
    ) -> Result<Bytes, Vec<u8>> {
        self.require_initialized()?;

        let identity = self.vm().msg_sender();

        // PHASE 1: Assemble the ExecutionContext from caller input and on-chain state.
        let context = self.assemble_context(
            identity,
            target,
            value,
            calldata,
            credential_id,
            session_id,
            delegation_id,
            exercised_capabilities,
            context_data,
            proof,
            nonce,
            deadline,
        );

        // PHASE 2: Validate all domain invariants against the assembled context.
        self.validate_context(&context)?;

        // PHASE 2.5: Delegate cryptographic proof verification to KipioAuth.
        // TODO: Call KipioAuth::verify_authorization(context.authorization, ...).
        // The Runtime asks Auth: "Is the proof in this context valid for this authorization?"
        // Auth evaluates the signature/proof without the Runtime touching cryptographic primitives.
        // If Auth returns false (or reverts), revert with Unauthorized().
        // This step must happen AFTER structural validation (Phase 2) and BEFORE dispatch
        // (Phase 3) to avoid wasting gas on crypto verification for invalid contexts.

        // PHASE 3: Dispatch execution. All validations passed.
        self.dispatch_execution(context)
    }
}

//! # Entrypoint
//!
//! Root storage struct for `KipioIdentityContent`. This is the only
//! struct annotated with `#[entrypoint]`; the ABI dispatch is generated
//! for it.

use stylus_sdk::prelude::*;
use stylus_sdk::{
    alloy_primitives::{Address, B256},
    storage::{StorageAddress, StorageB256, StorageBool, StorageMap, StorageU256},
};

use crate::storage::vault::ContentVault;

/// @title Kipio Sovereign Identity + Content Ledger
/// @notice Core persistent canonical truth provider binding logical actors
///         to cryptographic key fingerprints AND to their sovereign
///         content vaults.
///
/// IN-PROCESS P256 VERIFIER:
///
/// This contract embeds the EIP-7951 P256 verification path so that the
/// most common signature verification does not require an external
/// cross-contract call when the curve is P256. The `verify` entrypoint is
/// byte-for-byte equivalent to a standalone verifier: no crypto in WASM,
/// only a static call into the ArbOS native secp256r1 precompile.
///
/// DESIGN PHILOSOPHY & ARCHITECTURAL BOUNDARIES:
/// - This contract is NOT a cryptographic engine, passkey implementation, or curve-specific solver (P256, K256, ML-DSA).
/// - It acts strictly as an Identity Anchor answering: "Which cryptographic identity coordinates currently belong to this actor?"
/// - Curve-specific parsing (ASN.1, DER, COSE, SEC1) is completely delegated to frontend adapters or external verifiers.
/// - This module remains permanent, decoupled, and stable across future cryptographic algorithm or curve migrations.
///
/// CONSUMPTION MODEL:
/// Downstream modules (Recovery, Agents, B2B, Account Abstraction) consume this ledger exclusively to resolve identity
/// ownership proofs. The less often this contract changes, the healthier and more auditable the ecosystem architecture becomes.
///
/// POLICY EXECUTION MODEL:
/// This contract never determines whether a policy should be approved.
/// It only verifies that:
///
/// - the policy ledger is trusted;
/// - the policy exists;
/// - the policy is approved;
/// - the policy type matches the requested state transition;
/// - the target payload matches the identity mutation.
///
/// Once those conditions are satisfied,
/// the contract executes the identity mutation because it
/// remains the canonical source of truth.
#[storage]
#[entrypoint]
pub struct KipioIdentityContent {
    // ========================================================================
    // CONTENT / STORAGE PROVIDERS
    // ========================================================================

    pub storage_provider: StorageAddress,
    pub query_provider: StorageAddress,
    pub access_provider: StorageAddress,
    pub zk_verifier: StorageAddress,

    // ========================================================================
    // GOVERNANCE
    // ========================================================================

    pub owner: StorageAddress,
    pub pending_owner: StorageAddress,
    pub paused: StorageBool,
    pub pause_reason_hash: StorageB256,
    pub initialized: StorageBool,

    // ========================================================================
    // GLOBAL AGGREGATE COUNTERS
    // ========================================================================

    pub global_registrations: StorageU256,
    pub global_queries: StorageU256,

    // ========================================================================
    // QUERY STATE
    // ========================================================================

    pub pending_queries: StorageMap<B256, StorageBool>,
    pub query_timestamps: StorageMap<B256, StorageU256>,
    pub active_query_counts: StorageMap<Address, StorageU256>,
    pub query_requesters: StorageMap<B256, StorageAddress>,
    pub query_content_hashes: StorageMap<B256, StorageB256>,

    // ========================================================================
    // CRE
    // ========================================================================

    pub expected_workflow_id: StorageB256,

    // ========================================================================
    // IDENTITY ANCHOR (fused from kipio_auth)
    // ========================================================================

    /// @notice Centralized administrative configuration provider.
    pub protocol_config: StorageAddress,

    /// @notice Maps user logical addresses to their active cryptographic public key fingerprint: keccak256(pubkey).
    pub pubkeys: StorageMap<Address, StorageB256>,

    /// @notice Maps user logical addresses to their active monotonic cryptographic curve identifier tier.
    pub curves: StorageMap<Address, StorageU256>,

    /// @notice Identity-level anti-replay protection tracking the latest approved transaction sequence.
    /// @dev This nonce represents the latest authorized structural identity action, NOT a frontend login or web session.
    pub nonces: StorageMap<Address, StorageU256>,

    /// @notice Cached global domain separator structure matching EIP-712 cryptographic specifications.
    /// @dev Cache is populated lazily on first use. Chain_id and verifyingContract are effectively
    ///      immutable on a given deployment, so invalidation is not exposed.
    pub domain_separator_cache: StorageB256,

    // ========================================================================
    // USER VAULTS
    // ========================================================================

    pub vaults: StorageMap<Address, ContentVault>,
}

//! Manual implementation of `GenerateAbi` for the identity content ABI.
//!
//! WHY THIS FILE EXISTS:
//!
//! The `#[public]` macro auto-derives `GenerateAbi` for the entrypoint
//! struct whenever the `export-abi` feature is on, even when the impl
//! only declares `#[constructor]` and `#[fallback]`. That means
//! `KipioIdentityContent` already has one `GenerateAbi` impl generated
//! by the macro, and a second manual impl on the same type would be a
//! conflicting implementation (`E0119`).
//!
//! Because the contract uses `#[fallback]` with an indirect dispatch
//! table, the macro-generated impl exports nothing useful. This module
//! restores the interface by defining a distinct shadow type,
//! `KipioIdentityContentAbi`, that carries the manual `GenerateAbi`.
//! `bin/export_abi.rs` points `print_from_args` at the shadow type
//! instead of at the entrypoint struct.
//!
//! The shadow type has no storage fields, no methods, and is never
//! instantiated. It exists only during the `export-abi` build.
//!
//! MAINTENANCE:
//!
//! Every function declared in `endpoints::mod.rs`'s `sol!` block must
//! appear in `fmt_abi` below with the same signature. The `NAME`
//! constant matches the interface name. `fmt_constructor_signature`
//! emits the constructor declaration.
//!
//! This is a deliberate trade-off: the indirect dispatch solves the
//! ArbOS opcode limit, and this file pays the price in exchange for
//! keeping `cargo stylus export-abi` functional.

#![cfg(feature = "export-abi")]

use core::fmt;
use stylus_sdk::abi::export::GenerateAbi;

/// Shadow type whose only purpose is to carry a manual `GenerateAbi`
/// implementation. It is never instantiated at runtime.
///
/// The name matches the interface emitted by `cargo stylus export-abi`;
/// `print_from_args::<KipioIdentityContentAbi>()` uses it to produce
/// the Solidity file.
pub struct KipioIdentityContentAbi;

impl GenerateAbi for KipioIdentityContentAbi {
    const NAME: &'static str = "IKipioIdentityContent";

    fn fmt_abi(f: &mut fmt::Formatter<'_>) -> fmt::Result {
        writeln!(f, "interface IKipioIdentityContent {{")?;

        // --- Governance ---
        writeln!(f, "    function transferOwnership(address new_owner) external;")?;
        writeln!(f, "    function acceptOwnership() external;")?;
        writeln!(f, "    function setStorageProvider(address provider) external;")?;
        writeln!(f, "    function setQueryProvider(address provider) external;")?;
        writeln!(f, "    function setAccessProvider(address provider) external;")?;
        writeln!(f, "    function setZkVerifier(address verifier) external;")?;
        writeln!(f, "    function setExpectedWorkflowId(bytes32 workflow_id) external;")?;

        // --- Circuit breaker ---
        writeln!(f, "    function pause(bytes32 reason_hash) external;")?;
        writeln!(f, "    function unpause() external;")?;

        // --- Content registration ---
        writeln!(f, "    function registerContent(bytes32 content_id, bytes32 tx_commitment, uint8 provider_id, bytes32 access_policy_hash, bool is_public, uint8 storage_term, uint32 expiry_delta) external;")?;
        writeln!(f, "    function registerBatch(bytes32[] calldata content_ids, bytes32[] calldata tx_commitments, uint8[] calldata provider_ids, bytes32[] calldata access_policy_hashes, uint8[] calldata storage_terms, uint32[] calldata expiry_deltas) external;")?;
        writeln!(f, "    function rotateContent(bytes32 content_id, bytes32 new_tx_commitment, bytes32 new_access_policy_hash) external;")?;
        writeln!(f, "    function rotateContentCas(bytes32 content_id, uint64 expected_version, bytes32 new_tx_commitment, bytes32 new_access_policy_hash) external;")?;

        // --- Storage term extension ---
        writeln!(f, "    function extendStorageTerm(bytes32 content_id, uint8 new_storage_term, uint32 custom_expiry_delta) external;")?;
        writeln!(f, "    function extendStorageTermBatch(bytes32[] calldata content_ids, uint8[] calldata new_storage_terms, uint32[] calldata custom_expiry_deltas) external;")?;

        // --- Visibility ---
        writeln!(f, "    function setVisibility(bytes32 content_id, bool is_public) external;")?;
        writeln!(f, "    function setVisibilityBatch(bytes32[] calldata content_ids, bool[] calldata is_publics) external;")?;

        // --- Delete ---
        writeln!(f, "    function deleteContent(bytes32 content_id) external;")?;

        // --- Access control ---
        writeln!(f, "    function grantAccess(bytes32 content_id, address grantee) external;")?;
        writeln!(f, "    function revokeAccess(bytes32 content_id, address grantee) external;")?;

        // --- Views ---
        writeln!(f, "    function getGlobalStats() external view returns (uint256, uint256);")?;
        writeln!(f, "    function isPaused() external view returns (bool);")?;
        writeln!(f, "    function getPauseReason() external view returns (bytes32);")?;
        writeln!(f, "    function getProviders() external view returns (address, address, address, address);")?;
        writeln!(f, "    function hasAccess(address owner, bytes32 content_id, address grantee) external view returns (bool);")?;
        writeln!(f, "    function getCommitment(address owner, bytes32 content_id) external view returns (bytes32);")?;
        writeln!(f, "    function getMetadata(address owner, bytes32 content_id) external view returns (uint64, uint64, uint64, uint8, bool, uint8, uint32, uint64);")?;
        writeln!(f, "    function isPublic(address owner, bytes32 content_id) external view returns (bool);")?;
        writeln!(f, "    function getStorageInfo(address owner, bytes32 content_id) external view returns (uint8, uint32, uint64);")?;
        writeln!(f, "    function getExpiryStatus(address owner, bytes32 content_id) external view returns (bool, uint64);")?;
        writeln!(f, "    function getAccessPolicyHash(address owner, bytes32 content_id) external view returns (bytes32);")?;
        writeln!(f, "    function getContentList(address owner, uint32 offset, uint32 limit) external view returns (bytes32[] memory);")?;
        writeln!(f, "    function getSharedPaginated(address owner, bytes32 content_id, uint32 offset, uint32 limit) external view returns (address[] memory);")?;

        // --- Integrity proof ---
        writeln!(f, "    function verifyContentOwnership(address owner, bytes32 content_id, bytes calldata tx_id, bytes calldata salt) external view returns (bool);")?;

        // --- Query lifecycle ---
        writeln!(f, "    function requestQuery(bytes32 query_id, bytes32 content_hash, bytes32 query_plan_hash) external;")?;
        writeln!(f, "    function cancelStaleQuery(bytes32 query_id) external;")?;
        writeln!(f, "    function requestQueryZk(bytes32 query_id, bytes32 content_hash, bytes32 query_plan_hash, bytes calldata proof, bytes32[] calldata public_inputs) external;")?;
        writeln!(f, "    function onReport(bytes calldata metadata, bytes calldata report) external;")?;

        // --- Identity anchor ---
        writeln!(f, "    function initialize(address protocol_config) external;")?;
        writeln!(f, "    function register(bytes calldata pubkey, uint256 curve) external;")?;
        writeln!(f, "    function verifyIdentityAuthorization(address user, bytes32 msg_hash, bytes calldata signature, bytes calldata pubkey, uint256 nonce, uint256 deadline) external returns (bool);")?;
        writeln!(f, "    function rotateKey(bytes calldata old_pubkey, bytes calldata new_pubkey, uint256 new_curve, bytes calldata signature_from_old, uint256 nonce, uint256 deadline) external;")?;
        writeln!(f, "    function rotateKeyFromPolicy(address policy_ledger, bytes32 request_id, bytes calldata new_pubkey) external;")?;
        writeln!(f, "    function verify(address _user, bytes32 digest, bytes calldata signature, bytes calldata pubkey, uint256 _curve) external view returns (bool);")?;
        writeln!(f, "    function getProtocolConfig() external view returns (address);")?;
        writeln!(f, "    function getPubkey(address user) external view returns (bytes32);")?;
        writeln!(f, "    function getCurve(address user) external view returns (uint256);")?;
        writeln!(f, "    function getNonce(address user) external view returns (uint256);")?;

        writeln!(f, "}}")?;

        Ok(())
    }

    fn fmt_constructor_signature(f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "constructor(address storage_provider, address query_provider, address access_provider, bytes32 expected_workflow_id)"
        )
    }
}

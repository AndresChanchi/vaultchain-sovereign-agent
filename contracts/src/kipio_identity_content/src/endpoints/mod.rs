//! # Fallback Dispatcher
//!
//! Single `#[fallback]` entrypoint that routes raw calldata to per-method
//! `dispatch_*` handlers.
//!
//! WHY FALLBACK INSTEAD OF `#[public]`:
//!
//! The Stylus SDK's `#[public]` attribute expands into one monolithic
//! `route()` function that inlines the ABI decode of every method's
//! arguments and the ABI encode of every method's return value. With
//! 48 methods — several of them heavy (`register_batch` with six `Vec`
//! arguments, `get_metadata` with an 8-tuple return,
//! `verify_identity_authorization` with two `Vec`s plus cross-contract
//! calls) — the generated `route()` exceeded the ArbOS 65,536-opcode
//! limit per function, causing activation to fail with
//! `too many wasm opcodes in func body`.
//!
//! The fallback approach moves every decode and encode step into a
//! dedicated function. The dispatcher itself becomes a tiny `match`
//! over selectors that only emits `call` instructions, and every
//! `dispatch_*` handler gets its own 65,536-opcode budget.
//!
//! WHY THE DISPATCH IS INDIRECT (`call_indirect`) AND NOT A `match`:
//!
//! A plain `match` in `fallback` is not enough. The Stylus build
//! pipeline runs `wasm-opt -Oz --converge --closed-world` over the
//! output of LLVM. Binaryen has its own inliner that is independent of
//! LLVM and does **not** honor Rust's `#[inline(never)]`: the attribute
//! is a hint to LLVM IR that is lost in the translation to WASM.
//! Because the entrypoint is the only exported function of the module,
//! Binaryen's pipeline sees every `dispatch_*` as having a single call
//! site and inlines all of them into `user_entrypoint`, rebuilding the
//! monolithic body the fallback split was designed to avoid.
//!
//! Routing through a table of function pointers produces a
//! `call_indirect` in WASM. Binaryen cannot inline through
//! `call_indirect` because the target is a runtime value loaded from a
//! table, not a statically known function index. This preserves the
//! per-handler opcode budget that the ArbOS limit requires.
//!
//! `core::hint::black_box` on the table reference prevents LLVM from
//! devirtualizing the lookup back into a static `match` during codegen.
//!
//! MODEL B + EIP-2771 (TRUSTED FORWARDER):
//!
//! Under Model B, user-facing mutators require `msg_sender == runtime`,
//! where `runtime` is read from `kipio_protocol_config` on every
//! dispatch. The effective user is appended as a 20-byte suffix to the
//! calldata (EIP-2771 style), and the fallback strips it before
//! forwarding the argument slice to the handler.
//!
//! `resolve_forwarded_user` classifies every call:
//!
//!   - `Some(user)` → the call was forwarded by the trusted runtime.
//!   - `None`       → direct call (governance, view, CRE callback, or
//!                    pre-initialization).
//!
//! Handlers that operate on user-owned state call
//! `require_forwarded(user)?` at the top and use `user` instead of
//! `msg_sender()`. Governance handlers, views and the CRE callback
//! ignore the resolved user and continue to use `msg_sender()`
//! directly (owner, query_provider, or free read).
//!
//! CONSTRUCTOR:
//!
//! `#[constructor]` stays inside the same `#[public]` block as the
//! fallback. The SDK's generated dispatcher handles the constructor
//! selector directly and forwards every other selector to `fallback`.
//!
//! SELECTOR CONVENTION:
//!
//! Selectors follow Solidity's camelCase convention. Each function is
//! declared once in the `sol!` block below; its `[u8; 4]` selector is
//! derived at compile time via `SolCall::SELECTOR`. The `u32`
//! constants are what the dispatcher compares against.
//!
//! ABI ENCODING:
//!
//! Return values are encoded with `SolCall::abi_encode_returns_tuple`,
//! which operates on the function's declared return tuple
//! (`Self::ReturnTuple`) through the `SolTypeValue` trait. This is the
//! same code path the `#[public]` macro uses internally and it handles
//! `u8` fields (`uint8`) without requiring `u8: SolValue`.

pub(crate) use alloc::vec::Vec;

use core::hint::black_box;

use stylus_sdk::alloy_sol_types::sol;

pub(crate) use stylus_sdk::{
    alloy_primitives::{Address, B256, FixedBytes, U256},
    alloy_sol_types::{SolCall, SolError, SolValue},
    call::static_call,
    crypto::keccak,
    prelude::*,
    ArbResult,
};

pub(crate) use crate::abi::errors::*;
pub(crate) use crate::abi::events::*;
pub(crate) use crate::abi::interfaces::{IKipioProtocolConfig, IZKVerifier};
pub(crate) use crate::codec::pack::{pack_metadata, unpack_metadata};
pub(crate) use crate::codec::read::{
    read_created_at, read_expiry_delta, read_is_public, read_storage_term, read_version,
};
pub(crate) use crate::codec::validate::{
    compute_absolute_expiry, resolve_expiry_delta, validate_provider_id, validate_storage_term,
};
pub(crate) use crate::codec::write::{
    write_is_public_and_updated_at, write_storage_term_and_expiry, write_updated_at, write_version,
};
pub(crate) use crate::config::constants::*;
pub(crate) use crate::internal::cre::decode_cre_report;
pub(crate) use crate::storage::entrypoint::KipioIdentityContent;

mod access_control;
mod content;
mod decode;
mod governance;
mod identity;
mod query;
mod storage_terms;
mod views;
mod visibility;

pub(crate) use decode::*;

// ============================================================================
// FUNCTION SIGNATURES — SELECTOR SOURCE OF TRUTH
// ============================================================================

sol! {
    // --- Governance ---
    function transferOwnership(address new_owner) external;
    function acceptOwnership() external;
    function setStorageProvider(address provider) external;
    function setQueryProvider(address provider) external;
    function setAccessProvider(address provider) external;
    function setZkVerifier(address verifier) external;
    function setExpectedWorkflowId(bytes32 workflow_id) external;

    // --- Circuit breaker ---
    function pause(bytes32 reason_hash) external;
    function unpause() external;

    // --- Content registration ---
    function registerContent(
        bytes32 content_id,
        bytes32 tx_commitment,
        uint8 provider_id,
        bytes32 access_policy_hash,
        bool is_public,
        uint8 storage_term,
        uint32 expiry_delta
    ) external;
    function registerBatch(
        bytes32[] content_ids,
        bytes32[] tx_commitments,
        uint8[] provider_ids,
        bytes32[] access_policy_hashes,
        uint8[] storage_terms,
        uint32[] expiry_deltas
    ) external;
    function rotateContent(
        bytes32 content_id,
        bytes32 new_tx_commitment,
        bytes32 new_access_policy_hash
    ) external;
    function rotateContentCas(
        bytes32 content_id,
        uint64 expected_version,
        bytes32 new_tx_commitment,
        bytes32 new_access_policy_hash
    ) external;

    // --- Storage term extension ---
    function extendStorageTerm(
        bytes32 content_id,
        uint8 new_storage_term,
        uint32 custom_expiry_delta
    ) external;
    function extendStorageTermBatch(
        bytes32[] content_ids,
        uint8[] new_storage_terms,
        uint32[] custom_expiry_deltas
    ) external;

    // --- Visibility ---
    function setVisibility(bytes32 content_id, bool is_public) external;
    function setVisibilityBatch(bytes32[] content_ids, bool[] is_publics) external;

    // --- Delete ---
    function deleteContent(bytes32 content_id) external;

    // --- Access control ---
    function grantAccess(bytes32 content_id, address grantee) external;
    function revokeAccess(bytes32 content_id, address grantee) external;

    // --- Views ---
    function getGlobalStats() external view returns (uint256, uint256);
    function isPaused() external view returns (bool);
    function getPauseReason() external view returns (bytes32);
    function getProviders() external view returns (address, address, address, address);
    function hasAccess(address owner, bytes32 content_id, address grantee) external view returns (bool);
    function getCommitment(address owner, bytes32 content_id) external view returns (bytes32);
    function getMetadata(address owner, bytes32 content_id)
        external view
        returns (uint64, uint64, uint64, uint8, bool, uint8, uint32, uint64);
    function isPublic(address owner, bytes32 content_id) external view returns (bool);
    function getStorageInfo(address owner, bytes32 content_id)
        external view
        returns (uint8, uint32, uint64);
    function getExpiryStatus(address owner, bytes32 content_id)
        external view
        returns (bool, uint64);
    function getAccessPolicyHash(address owner, bytes32 content_id) external view returns (bytes32);
    function getContentList(address owner, uint32 offset, uint32 limit)
        external view
        returns (bytes32[]);
    function getSharedPaginated(address owner, bytes32 content_id, uint32 offset, uint32 limit)
        external view
        returns (address[]);

    // --- Integrity proof ---
    function verifyContentOwnership(address owner, bytes32 content_id, bytes tx_id, bytes salt)
        external view
        returns (bool);

    // --- Query lifecycle ---
    function requestQuery(bytes32 query_id, bytes32 content_hash, bytes32 query_plan_hash) external;
    function cancelStaleQuery(bytes32 query_id) external;
    function requestQueryZk(
        bytes32 query_id,
        bytes32 content_hash,
        bytes32 query_plan_hash,
        bytes proof,
        bytes32[] public_inputs
    ) external;
    function onReport(bytes metadata, bytes report) external;

    // --- Identity anchor ---
    function initialize(address protocol_config) external;
    function register(bytes pubkey, uint256 curve) external;
    /// @dev EIP-2771: the effective user is the last 20 bytes of calldata.
    function verifyIdentityAuthorization(
        bytes32 msg_hash,
        bytes signature,
        bytes pubkey,
        uint256 nonce,
        uint256 deadline
    ) external returns (bool);
    function rotateKey(
        bytes old_pubkey,
        bytes new_pubkey,
        uint256 new_curve,
        bytes signature_from_old,
        uint256 nonce,
        uint256 deadline
    ) external;
    /// @dev Runtime-only. Effective user is the last 20 bytes of calldata.
    function applyAuthorizedRotation(bytes new_pubkey, uint256 new_curve) external;
    function verify(
        address _user,
        bytes32 digest,
        bytes signature,
        bytes pubkey,
        uint256 _curve
    ) external view returns (bool);
    function getProtocolConfig() external view returns (address);
    function getPubkey(address user) external view returns (bytes32);
    function getCurve(address user) external view returns (uint256);
    function getNonce(address user) external view returns (uint256);
}

// ============================================================================
// SELECTOR CONSTANTS
// ============================================================================

const SEL_TRANSFER_OWNERSHIP: u32 = u32::from_be_bytes(transferOwnershipCall::SELECTOR);
const SEL_ACCEPT_OWNERSHIP: u32 = u32::from_be_bytes(acceptOwnershipCall::SELECTOR);
const SEL_SET_STORAGE_PROVIDER: u32 = u32::from_be_bytes(setStorageProviderCall::SELECTOR);
const SEL_SET_QUERY_PROVIDER: u32 = u32::from_be_bytes(setQueryProviderCall::SELECTOR);
const SEL_SET_ACCESS_PROVIDER: u32 = u32::from_be_bytes(setAccessProviderCall::SELECTOR);
const SEL_SET_ZK_VERIFIER: u32 = u32::from_be_bytes(setZkVerifierCall::SELECTOR);
const SEL_SET_EXPECTED_WORKFLOW_ID: u32 = u32::from_be_bytes(setExpectedWorkflowIdCall::SELECTOR);
const SEL_PAUSE: u32 = u32::from_be_bytes(pauseCall::SELECTOR);
const SEL_UNPAUSE: u32 = u32::from_be_bytes(unpauseCall::SELECTOR);
const SEL_REGISTER_CONTENT: u32 = u32::from_be_bytes(registerContentCall::SELECTOR);
const SEL_REGISTER_BATCH: u32 = u32::from_be_bytes(registerBatchCall::SELECTOR);
const SEL_ROTATE_CONTENT: u32 = u32::from_be_bytes(rotateContentCall::SELECTOR);
const SEL_ROTATE_CONTENT_CAS: u32 = u32::from_be_bytes(rotateContentCasCall::SELECTOR);
const SEL_EXTEND_STORAGE_TERM: u32 = u32::from_be_bytes(extendStorageTermCall::SELECTOR);
const SEL_EXTEND_STORAGE_TERM_BATCH: u32 =
    u32::from_be_bytes(extendStorageTermBatchCall::SELECTOR);
const SEL_SET_VISIBILITY: u32 = u32::from_be_bytes(setVisibilityCall::SELECTOR);
const SEL_SET_VISIBILITY_BATCH: u32 = u32::from_be_bytes(setVisibilityBatchCall::SELECTOR);
const SEL_DELETE_CONTENT: u32 = u32::from_be_bytes(deleteContentCall::SELECTOR);
const SEL_GRANT_ACCESS: u32 = u32::from_be_bytes(grantAccessCall::SELECTOR);
const SEL_REVOKE_ACCESS: u32 = u32::from_be_bytes(revokeAccessCall::SELECTOR);
const SEL_GET_GLOBAL_STATS: u32 = u32::from_be_bytes(getGlobalStatsCall::SELECTOR);
const SEL_IS_PAUSED: u32 = u32::from_be_bytes(isPausedCall::SELECTOR);
const SEL_GET_PAUSE_REASON: u32 = u32::from_be_bytes(getPauseReasonCall::SELECTOR);
const SEL_GET_PROVIDERS: u32 = u32::from_be_bytes(getProvidersCall::SELECTOR);
const SEL_HAS_ACCESS: u32 = u32::from_be_bytes(hasAccessCall::SELECTOR);
const SEL_GET_COMMITMENT: u32 = u32::from_be_bytes(getCommitmentCall::SELECTOR);
const SEL_GET_METADATA: u32 = u32::from_be_bytes(getMetadataCall::SELECTOR);
const SEL_IS_PUBLIC: u32 = u32::from_be_bytes(isPublicCall::SELECTOR);
const SEL_GET_STORAGE_INFO: u32 = u32::from_be_bytes(getStorageInfoCall::SELECTOR);
const SEL_GET_EXPIRY_STATUS: u32 = u32::from_be_bytes(getExpiryStatusCall::SELECTOR);
const SEL_GET_ACCESS_POLICY_HASH: u32 = u32::from_be_bytes(getAccessPolicyHashCall::SELECTOR);
const SEL_GET_CONTENT_LIST: u32 = u32::from_be_bytes(getContentListCall::SELECTOR);
const SEL_GET_SHARED_PAGINATED: u32 = u32::from_be_bytes(getSharedPaginatedCall::SELECTOR);
const SEL_VERIFY_CONTENT_OWNERSHIP: u32 =
    u32::from_be_bytes(verifyContentOwnershipCall::SELECTOR);
const SEL_REQUEST_QUERY: u32 = u32::from_be_bytes(requestQueryCall::SELECTOR);
const SEL_CANCEL_STALE_QUERY: u32 = u32::from_be_bytes(cancelStaleQueryCall::SELECTOR);
const SEL_REQUEST_QUERY_ZK: u32 = u32::from_be_bytes(requestQueryZkCall::SELECTOR);
const SEL_ON_REPORT: u32 = u32::from_be_bytes(onReportCall::SELECTOR);
const SEL_INITIALIZE: u32 = u32::from_be_bytes(initializeCall::SELECTOR);
const SEL_REGISTER: u32 = u32::from_be_bytes(registerCall::SELECTOR);
const SEL_VERIFY_IDENTITY_AUTHORIZATION: u32 =
    u32::from_be_bytes(verifyIdentityAuthorizationCall::SELECTOR);
const SEL_ROTATE_KEY: u32 = u32::from_be_bytes(rotateKeyCall::SELECTOR);
const SEL_APPLY_AUTHORIZED_ROTATION: u32 =
    u32::from_be_bytes(applyAuthorizedRotationCall::SELECTOR);
const SEL_VERIFY: u32 = u32::from_be_bytes(verifyCall::SELECTOR);
const SEL_GET_PROTOCOL_CONFIG: u32 = u32::from_be_bytes(getProtocolConfigCall::SELECTOR);
const SEL_GET_PUBKEY: u32 = u32::from_be_bytes(getPubkeyCall::SELECTOR);
const SEL_GET_CURVE: u32 = u32::from_be_bytes(getCurveCall::SELECTOR);
const SEL_GET_NONCE: u32 = u32::from_be_bytes(getNonceCall::SELECTOR);

// ============================================================================
// DISPATCH TABLE — INDIRECT DISPATCH
// ============================================================================

/// Handler signature.
///
/// The second argument is the resolved effective user under EIP-2771:
/// `Some(user)` when the call was forwarded by the trusted runtime,
/// `None` for direct calls (governance, views, CRE callbacks, and any
/// call that arrives before the contract is initialized).
///
/// Handlers that operate on user-owned state call
/// `require_forwarded(user)?` and use `user` instead of
/// `msg_sender()`. Governance handlers, views and the CRE callback
/// ignore the resolved user and continue to use `msg_sender()`
/// directly.
type DispatchHandler = fn(&mut KipioIdentityContent, &[u8], Option<Address>) -> ArbResult;

/// Selector-to-handler table. The order is arbitrary; the dispatcher
/// performs a linear scan.
static DISPATCH_TABLE: &[(u32, DispatchHandler)] = &[
    (SEL_TRANSFER_OWNERSHIP, KipioIdentityContent::dispatch_transfer_ownership),
    (SEL_ACCEPT_OWNERSHIP, KipioIdentityContent::dispatch_accept_ownership),
    (SEL_SET_STORAGE_PROVIDER, KipioIdentityContent::dispatch_set_storage_provider),
    (SEL_SET_QUERY_PROVIDER, KipioIdentityContent::dispatch_set_query_provider),
    (SEL_SET_ACCESS_PROVIDER, KipioIdentityContent::dispatch_set_access_provider),
    (SEL_SET_ZK_VERIFIER, KipioIdentityContent::dispatch_set_zk_verifier),
    (SEL_SET_EXPECTED_WORKFLOW_ID, KipioIdentityContent::dispatch_set_expected_workflow_id),
    (SEL_PAUSE, KipioIdentityContent::dispatch_pause),
    (SEL_UNPAUSE, KipioIdentityContent::dispatch_unpause),
    (SEL_REGISTER_CONTENT, KipioIdentityContent::dispatch_register_content),
    (SEL_REGISTER_BATCH, KipioIdentityContent::dispatch_register_batch),
    (SEL_ROTATE_CONTENT, KipioIdentityContent::dispatch_rotate_content),
    (SEL_ROTATE_CONTENT_CAS, KipioIdentityContent::dispatch_rotate_content_cas),
    (SEL_EXTEND_STORAGE_TERM, KipioIdentityContent::dispatch_extend_storage_term),
    (SEL_EXTEND_STORAGE_TERM_BATCH, KipioIdentityContent::dispatch_extend_storage_term_batch),
    (SEL_SET_VISIBILITY, KipioIdentityContent::dispatch_set_visibility),
    (SEL_SET_VISIBILITY_BATCH, KipioIdentityContent::dispatch_set_visibility_batch),
    (SEL_DELETE_CONTENT, KipioIdentityContent::dispatch_delete_content),
    (SEL_GRANT_ACCESS, KipioIdentityContent::dispatch_grant_access),
    (SEL_REVOKE_ACCESS, KipioIdentityContent::dispatch_revoke_access),
    (SEL_GET_GLOBAL_STATS, KipioIdentityContent::dispatch_get_global_stats),
    (SEL_IS_PAUSED, KipioIdentityContent::dispatch_is_paused),
    (SEL_GET_PAUSE_REASON, KipioIdentityContent::dispatch_get_pause_reason),
    (SEL_GET_PROVIDERS, KipioIdentityContent::dispatch_get_providers),
    (SEL_HAS_ACCESS, KipioIdentityContent::dispatch_has_access),
    (SEL_GET_COMMITMENT, KipioIdentityContent::dispatch_get_commitment),
    (SEL_GET_METADATA, KipioIdentityContent::dispatch_get_metadata),
    (SEL_IS_PUBLIC, KipioIdentityContent::dispatch_is_public),
    (SEL_GET_STORAGE_INFO, KipioIdentityContent::dispatch_get_storage_info),
    (SEL_GET_EXPIRY_STATUS, KipioIdentityContent::dispatch_get_expiry_status),
    (SEL_GET_ACCESS_POLICY_HASH, KipioIdentityContent::dispatch_get_access_policy_hash),
    (SEL_GET_CONTENT_LIST, KipioIdentityContent::dispatch_get_content_list),
    (SEL_GET_SHARED_PAGINATED, KipioIdentityContent::dispatch_get_shared_paginated),
    (SEL_VERIFY_CONTENT_OWNERSHIP, KipioIdentityContent::dispatch_verify_content_ownership),
    (SEL_REQUEST_QUERY, KipioIdentityContent::dispatch_request_query),
    (SEL_CANCEL_STALE_QUERY, KipioIdentityContent::dispatch_cancel_stale_query),
    (SEL_REQUEST_QUERY_ZK, KipioIdentityContent::dispatch_request_query_zk),
    (SEL_ON_REPORT, KipioIdentityContent::dispatch_on_report),
    (SEL_INITIALIZE, KipioIdentityContent::dispatch_initialize),
    (SEL_REGISTER, KipioIdentityContent::dispatch_register),
    (SEL_VERIFY_IDENTITY_AUTHORIZATION, KipioIdentityContent::dispatch_verify_identity_authorization),
    (SEL_ROTATE_KEY, KipioIdentityContent::dispatch_rotate_key),
    (SEL_APPLY_AUTHORIZED_ROTATION, KipioIdentityContent::dispatch_apply_authorized_rotation),
    (SEL_VERIFY, KipioIdentityContent::dispatch_verify),
    (SEL_GET_PROTOCOL_CONFIG, KipioIdentityContent::dispatch_get_protocol_config),
    (SEL_GET_PUBKEY, KipioIdentityContent::dispatch_get_pubkey),
    (SEL_GET_CURVE, KipioIdentityContent::dispatch_get_curve),
    (SEL_GET_NONCE, KipioIdentityContent::dispatch_get_nonce),
];

// ============================================================================
// PUBLIC INTERFACE — CONSTRUCTOR + FALLBACK
// ============================================================================

#[public]
impl KipioIdentityContent {
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

    /// @notice Entry point for every non-constructor call.
    ///
    /// @dev Reads the 4-byte selector from `calldata`, resolves the
    ///      effective user under EIP-2771, resolves the handler through
    ///      `DISPATCH_TABLE` (indirect call, opaque to `wasm-opt`'s
    ///      inliner), and forwards the argument slice.
    #[fallback]
    fn fallback(&mut self, calldata: &[u8]) -> ArbResult {
        if calldata.len() < 4 {
            return Err(Vec::new());
        }
        let selector =
            u32::from_be_bytes([calldata[0], calldata[1], calldata[2], calldata[3]]);
        let args = &calldata[4..];

        // Resolve the effective user for this call.
        let (user, args_inner) = self.resolve_forwarded_user(args)?;

        // `black_box` on the table reference prevents LLVM from
        // constant-folding the linear scan into a static decision tree.
        let table: &[(u32, DispatchHandler)] = black_box(DISPATCH_TABLE);

        let mut handler: Option<DispatchHandler> = None;
        for &(sel, h) in table.iter() {
            if sel == selector {
                handler = Some(h);
                break;
            }
        }

        match handler {
            Some(h) => h(self, args_inner, user),
            None => Err(Vec::new()),
        }
    }
}

// ============================================================================
// INTERNAL HELPERS
// ============================================================================

impl KipioIdentityContent {
    pub(crate) fn require_owner(&self) -> Result<(), Vec<u8>> {
        if self.vm().msg_sender() != self.owner.get() {
            return Err(Unauthorized {}.abi_encode());
        }
        Ok(())
    }

    pub(crate) fn require_not_paused(&self) -> Result<(), Vec<u8>> {
        if self.paused.get() {
            return Err(EnforcedPause {}.abi_encode());
        }
        Ok(())
    }

    /// Resolves the effective user for a call under Model B + EIP-2771.
    ///
    /// Returns `(Some(user), trimmed_args)` when the call was forwarded
    /// by the trusted runtime, and `(None, args)` for every direct call.
    ///
    /// - Pre-initialization: if `protocol_config` is unset, no trusted
    ///   forwarder exists. Returns `(None, args)` so that the owner's
    ///   `initialize` call and views continue to work.
    /// - Post-initialization: reads `getRuntimeAddress()` from the
    ///   protocol config. If `msg_sender` matches the trusted forwarder,
    ///   the last 20 bytes of `args` are the effective user, and the
    ///   returned slice excludes them.
    /// - Any other `msg_sender` is treated as a direct call and resolves
    ///   to `None`. Handlers that require forwarding will reject it.
    pub(crate) fn resolve_forwarded_user<'a>(
        &self,
        args: &'a [u8],
    ) -> Result<(Option<Address>, &'a [u8]), Vec<u8>> {
        let config_addr = self.protocol_config.get();
        if config_addr == Address::ZERO {
            return Ok((None, args));
        }

        let config = IKipioProtocolConfig::new(config_addr);
        let runtime = config
            .get_runtime_address(self.vm(), Call::new())
            .map_err(|_| ProtocolConfigNotSet {}.abi_encode())?;

        if self.vm().msg_sender() != runtime {
            return Ok((None, args));
        }

        if args.len() < 20 {
            return Err(InvalidForwardedCall {}.abi_encode());
        }
        let user = Address::from_slice(&args[args.len() - 20..]);
        Ok((Some(user), &args[..args.len() - 20]))
    }

    /// Requires that the call was forwarded by the trusted runtime and
    /// returns the effective user. User-facing mutators call this at
    /// the top of their body.
    ///
    /// The contract NEVER falls back to `msg_sender()` when the call
    /// was not forwarded. Under Model B, user-facing state mutations
    /// MUST come through the runtime orchestrator so that:
    ///
    ///   - the fee is charged exactly once per user action,
    ///   - the state reads and writes across the protocol are atomic,
    ///   - the effective user is unambiguous.
    ///
    /// Direct calls to a user-facing mutator revert with `NotForwarded`.
    pub(crate) fn require_forwarded(
        &self,
        user: Option<Address>,
    ) -> Result<Address, Vec<u8>> {
        user.ok_or_else(|| NotForwarded {}.abi_encode())
    }
}

//! ABI decode helpers for methods with dynamic argument lists.
//!
//! `SolCall::abi_decode` for a dynamic argument (`bytes`, `T[]`)
//! expands into a non-trivial sequence of offset reads, bounds checks
//! and length resolution. Extracting them into dedicated functions
//! keeps each dispatch body to a single `call` at the source level.
//! See the parent module for the full rationale on why this
//! complements — but does not substitute — the indirect dispatch.
//!
//! Only decoders whose argument list contains a dynamic type live here.
//! Decoders for fixed-size argument lists (`address`, `bytes32`, `bool`,
//! `uint8..uint64`) stay inline in their dispatch handler because their
//! expansion is small and the extra `call` overhead would dominate.

use super::*;

/// @dev Decodes `registerBatch(bytes32[],bytes32[],uint8[],bytes32[],uint8[],uint32[])`.
///      Six dynamic arrays; the heaviest decoder in the contract.
#[inline(never)]
pub(crate) fn decode_register_batch(args: &[u8]) -> Result<registerBatchCall, Vec<u8>> {
    registerBatchCall::abi_decode(args).map_err(|_| Vec::new())
}

/// @dev Decodes `extendStorageTermBatch(bytes32[],uint8[],uint32[])`.
#[inline(never)]
pub(crate) fn decode_extend_storage_term_batch(
    args: &[u8],
) -> Result<extendStorageTermBatchCall, Vec<u8>> {
    extendStorageTermBatchCall::abi_decode(args).map_err(|_| Vec::new())
}

/// @dev Decodes `setVisibilityBatch(bytes32[],bool[])`.
#[inline(never)]
pub(crate) fn decode_set_visibility_batch(args: &[u8]) -> Result<setVisibilityBatchCall, Vec<u8>> {
    setVisibilityBatchCall::abi_decode(args).map_err(|_| Vec::new())
}

/// @dev Decodes `requestQueryZk(bytes32,bytes32,bytes32,bytes,bytes32[])`.
#[inline(never)]
pub(crate) fn decode_request_query_zk(args: &[u8]) -> Result<requestQueryZkCall, Vec<u8>> {
    requestQueryZkCall::abi_decode(args).map_err(|_| Vec::new())
}

/// @dev Decodes `onReport(bytes,bytes)`.
#[inline(never)]
pub(crate) fn decode_on_report(args: &[u8]) -> Result<onReportCall, Vec<u8>> {
    onReportCall::abi_decode(args).map_err(|_| Vec::new())
}

/// @dev Decodes
///      `verifyIdentityAuthorization(address,bytes32,bytes,bytes,uint256,uint256)`.
#[inline(never)]
pub(crate) fn decode_verify_identity_authorization(
    args: &[u8],
) -> Result<verifyIdentityAuthorizationCall, Vec<u8>> {
    verifyIdentityAuthorizationCall::abi_decode(args).map_err(|_| Vec::new())
}

/// @dev Decodes `rotateKey(bytes,bytes,uint256,bytes,uint256,uint256)`.
#[inline(never)]
pub(crate) fn decode_rotate_key(args: &[u8]) -> Result<rotateKeyCall, Vec<u8>> {
    rotateKeyCall::abi_decode(args).map_err(|_| Vec::new())
}

/// @dev Decodes `rotateKeyFromPolicy(address,bytes32,bytes)`.
#[inline(never)]
pub(crate) fn decode_rotate_key_from_policy(
    args: &[u8],
) -> Result<rotateKeyFromPolicyCall, Vec<u8>> {
    rotateKeyFromPolicyCall::abi_decode(args).map_err(|_| Vec::new())
}

/// @dev Decodes `register(bytes,uint256)`.
#[inline(never)]
pub(crate) fn decode_register(args: &[u8]) -> Result<registerCall, Vec<u8>> {
    registerCall::abi_decode(args).map_err(|_| Vec::new())
}

/// @dev Decodes `verify(address,bytes32,bytes,bytes,uint256)`.
#[inline(never)]
pub(crate) fn decode_verify(args: &[u8]) -> Result<verifyCall, Vec<u8>> {
    verifyCall::abi_decode(args).map_err(|_| Vec::new())
}

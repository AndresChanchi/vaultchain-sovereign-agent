//! # Protocol Constants
//!
//! Storage-term discriminators, expiration durations, batch limits,
//! lifecycle status enumerations, and the current schema version.

use stylus_sdk::alloy_primitives::address;

// ============================================================================
// STORAGE TERM CONSTANTS
// ============================================================================

/// @notice PERMANENT represents "no on-chain traceable expiration."
/// @dev In practice, Irys/Arweave guarantee ~200 years. The contract
///      cannot verify the actual limit; my bet is that this decentralized storage infrastructure will last at least until 2050... or maybe not xd.
pub const STORAGE_TERM_PERMANENT: u8 = 0;
pub const STORAGE_TERM_30_DAYS: u8 = 1;
pub const STORAGE_TERM_1_YEAR: u8 = 2;
pub const STORAGE_TERM_CUSTOM: u8 = 3;

pub const SECONDS_30_DAYS: u32 = 2_592_000;  // 30 * 24 * 60 * 60
pub const SECONDS_1_YEAR: u32 = 31_536_000;  // 365 * 24 * 60 * 60

pub const MAX_EXPIRY_DELTA: u32 = u32::MAX;

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

pub const CURRENT_SCHEMA: u8 = 1;

// ============================================================================
// PROTOCOL LIMITS
// ============================================================================

pub const MAX_ACTIVE_QUERIES: u64 = 10;
pub const QUERY_TIMEOUT_SECONDS: u64 = 3600;
pub const MAX_BATCH_SIZE: usize = 256;

// ============================================================================
// IDENTITY LIFECYCLE STATUS ENUMERATIONS
// ============================================================================

/// @notice Curve is disabled by governance. Registration and verification
///         are rejected when the active curve points here.
pub const STATUS_DISABLED: u64 = 0;

/// @notice Curve is fully operational. The only status that permits
///         registration and key rotation targets.
pub const STATUS_ACTIVE: u64 = 1;

/// @notice Approved external policy state. Auth refuses to consume a
///         policy that is not in this state.
pub const POLICY_STATUS_APPROVED: u64 = 1;

// ============================================================================
// EIP-7951 P256 PRECOMPILE (supersedes RIP-7212)
// ============================================================================
//
// ArbOS exposes the secp256r1 verifier precompile at:
//
// 0x0000000000000000000000000000000000000100
//
// This module intentionally acts as a VERY THIN WRAPPER around that
// native protocol precompile.
//
// IMPORTANT:
//
// - No P256 math is implemented in WASM.
// - No ASN.1 parsing is implemented here.
// - No DER decoding is implemented here.
// - No COSE/WebAuthn parsing is implemented here.
//
// The goal is:
//
// - minimal WASM size
// - native Nitro crypto execution
// - deterministic calldata
// - easier auditing
// - easier future upgrades
//
// ------------------------------------------------------------------------
// STANDARD EVOLUTION: RIP-7212 → EIP-7951
// ------------------------------------------------------------------------
//
// RIP-7212 was activated as part of ArbOS 31 Bianca and introduced the
// P256VERIFY precompile at 0x100. It had two latent security issues:
//
// 1. No point-at-infinity check for the recovered point R'. In edge cases
//    this could produce non-deterministic behavior across clients, with
//    potential consensus implications.
//
// 2. Direct equality comparison for the recovered x-coordinate. When the
//    x-coordinate of R' exceeded the curve order N, the comparison failed
//    even for valid signatures. The fix uses modular arithmetic:
//
//        r' ≡ r (mod n)
//
// EIP-7951 supersedes RIP-7212 with the same interface and the same
// 160-byte calldata layout. The only observable differences are:
//
// - the two fixes above,
// - the gas cost, raised from 3,450 to 6,900 to match the L1 schedule.
//
// ArbOS 50 Dia adopted EIP-7951 as an in-place update of the existing
// precompile. Arbitrum One, Arbitrum Nova, and all Orbit chains running
// ArbOS 50+ expose the corrected semantics at the same address.
//
// Our contract does NOT need to change to benefit from the fixes. The
// precompile executes inside Nitro; the contract merely forwards calldata.
//
// Reference: https://eips.ethereum.org/EIPS/eip-7951
//
// ------------------------------------------------------------------------
// FRONTEND INTEGRATION
// ------------------------------------------------------------------------
//
// When building the frontend/passkey integration:
//
// DO NOT send browser WebAuthn outputs directly into this contract.
//
// Browsers/devices usually return:
//
// - ASN.1 DER encoded signatures
// - COSE public keys
// - compressed SEC1 keys
// - authenticator payload wrappers
//
// This verifier intentionally DOES NOT parse any of that.
//
// The frontend layer MUST normalize everything BEFORE calling verify().
//
// ------------------------------------------------------------------------
// REQUIRED INPUT FORMAT
// ------------------------------------------------------------------------
//
// signature:
// - exactly 64 bytes
// - layout:
//     r || s
//
// pubkey:
// - exactly 64 bytes
// - layout:
//     x || y
//
// digest:
// - exactly 32 bytes
// - already hashed
//
// ------------------------------------------------------------------------
// NORMALIZATION RULES
// ------------------------------------------------------------------------
//
// All values MUST already be:
//
// - left padded
// - normalized
// - big endian encoded
//
// This module intentionally delegates normalization to the frontend
// to keep WASM extremely small and rely entirely on native ArbOS crypto.
//
// ------------------------------------------------------------------------
// EIP-7951 CALLDATA FORMAT
// ------------------------------------------------------------------------
//
// The precompile expects EXACTLY 160 bytes:
//
// [ digest | r | s | qx | qy ]
//
// Layout:
//
// 32 bytes -> digest
// 32 bytes -> signature.r
// 32 bytes -> signature.s
// 32 bytes -> pubkey.x
// 32 bytes -> pubkey.y
//
// ------------------------------------------------------------------------
// RETURN SEMANTICS
// ------------------------------------------------------------------------
//
// VALID SIGNATURE:
// - returns 32 bytes
// - last byte == 1
//
// INVALID SIGNATURE / MALFORMED INPUT:
// - returns empty bytes
//
// This behavior is defined by EIP-7951, inherited unchanged from RIP-7212.
// ----------------------------------------------------------------------------
pub const P256_VERIFY_PRECOMPILE: stylus_sdk::alloy_primitives::Address =
    address!("0000000000000000000000000000000000000100");

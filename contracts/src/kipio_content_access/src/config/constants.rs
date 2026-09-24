//! # Protocol Constants
//!
//! Storage-term discriminators, expiration durations, batch limits, and
//! the current schema version.

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

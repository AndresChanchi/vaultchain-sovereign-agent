//! Module identifiers and curve status constants.
//!
//! The module identifiers are stable and part of the ABI. New modules
//! get new ids; existing ids never change meaning.
//!
//! This registry implements the "on-chain address registry" pattern
//! (also known as the Address Provider pattern, as used by Aave V3). It
//! replaces the older "immutable pointer" pattern with a single
//! well-known registry whose slot values can be updated by governance
//! without any consumer redeploy.

// ============================================================================
// MODULE IDENTIFIERS
// ============================================================================

/// @notice Orchestration runtime (`kipio_runtime`).
pub const MODULE_RUNTIME: u8 = 0;

/// @notice Economic coordination module (`kipio_economics`).
pub const MODULE_ECONOMICS: u8 = 1;

/// @notice Identity + content ledger (`kipio_identity_content`).
pub const MODULE_IDENTITY_CONTENT: u8 = 2;

/// @notice Guardian-driven recovery singleton (`kipio_recovery`).
pub const MODULE_RECOVERY: u8 = 3;

/// @notice Deterministic account factory + bootstrap (`kipio_execution_gateway`).
pub const MODULE_EXECUTION_GATEWAY: u8 = 4;

// ============================================================================
// CURVE STATUS CONSTANTS
// ============================================================================
//
// The status is a three-state lifecycle for each cryptographic curve
// registered in the protocol. The state is read by `kipio_identity_content`
// on every signature-related operation:
//
//   - DISABLED   → signatures from this curve are rejected outright.
//   - ACTIVE     → the curve can register new keys and verify signatures.
//   - DEPRECATED → existing keys still verify, but new registrations are
//                  rejected. This is the migration path for a curve that
//                  is being phased out in favor of a newer one.

pub const STATUS_DISABLED: u64 = 0;
pub const STATUS_ACTIVE: u64 = 1;
pub const STATUS_DEPRECATED: u64 = 2;

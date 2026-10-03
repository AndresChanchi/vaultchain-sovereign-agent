//! Module identifiers.
//!
//! Runtime resolves module addresses through `kipio_protocol_config`
//! instead of hardcoding them. This preserves the ability to upgrade
//! individual modules without redeploying the runtime.
//!
//! `MODULE_EXECUTION_ACCOUNT` is special: it does not go through the
//! registry because accounts are per-identity and their address is
//! derived deterministically by the Execution Gateway via CREATE2. The
//! runtime uses `envelope.execution_account` directly for that case.

/// @notice Identity + content ledger module (`kipio_identity_content`).
pub const MODULE_IDENTITY_CONTENT: u8 = 0;

/// @notice Economic coordination module (`kipio_economics`).
pub const MODULE_ECONOMICS: u8 = 1;

/// @notice Guardian-driven recovery module (`kipio_recovery`).
pub const MODULE_RECOVERY: u8 = 2;

/// @notice Sentinel: target is the account that owns the intent.
pub const MODULE_EXECUTION_ACCOUNT: u8 = 255;

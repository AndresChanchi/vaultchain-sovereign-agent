//! Compile-time constants for `kipio_recovery`.

use stylus_sdk::alloy_primitives::Address;

/// ArbOS native secp256r1 verifier (EIP-7951, superseded RIP-7212).
/// Thin wrapper: no WASM crypto, only raw calldata forwarding.
pub(crate) const P256_VERIFY_PRECOMPILE: Address = Address::new([
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x01, 0x00,
]);

/// ecrecover precompile. Used for secp256k1 EOA guardians.
pub(crate) const ECRECOVER_PRECOMPILE: Address = Address::new([
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x01,
]);

pub(crate) const CURVE_P256: u8 = 1;
pub(crate) const CURVE_SECP256K1: u8 = 2;

pub(crate) const RECOVERY_STATUS_NONE: u8 = 0;
pub(crate) const RECOVERY_STATUS_ACTIVE: u8 = 1;
pub(crate) const RECOVERY_STATUS_APPROVED: u8 = 2;
pub(crate) const RECOVERY_STATUS_EXECUTED: u8 = 3;
pub(crate) const RECOVERY_STATUS_CANCELLED: u8 = 4;
pub(crate) const RECOVERY_STATUS_EXPIRED: u8 = 5;

/// Hard cap on the size of a guardian set. Bounded so that the approval
/// bitfield fits in a single `U256` (240 bits of headroom left) and the
/// linear-scan `find_guardian_index` stays cheap.
pub(crate) const MAX_GUARDIANS: usize = 16;

/// Time between threshold approval and execution. During this window the
/// sovereign identity can still cancel the recovery using one of its
/// active credentials.
pub(crate) const CHALLENGE_PERIOD_SECONDS: u64 = 3 * 24 * 60 * 60;

pub(crate) const APPROVE_DOMAIN: &[u8] = b"KIPIO_RECOVERY_APPROVE_V1";
pub(crate) const CANCEL_DOMAIN: &[u8] = b"KIPIO_RECOVERY_CANCEL_V1";

/// Compile-time bitmask table for the recovery approval bitfield.
///
/// `recovery_approvals[account][request_id]` is a `U256` where bit `i`
/// is set when the guardian at index `i` of the request's pinned
/// guardian version has approved. `MAX_GUARDIANS` is 16, so a single
/// `U256` covers the entire bitfield with 240 bits of headroom.
///
/// Precomputed at compile time to avoid any dependency on `U256` shift
/// semantics during gas-sensitive execution. Access is `O(1)` and
/// infallible for `idx < MAX_GUARDIANS`.
pub(crate) const APPROVAL_BITS: [u64; 16] = [
    1u64 << 0, 1u64 << 1, 1u64 << 2, 1u64 << 3,
    1u64 << 4, 1u64 << 5, 1u64 << 6, 1u64 << 7,
    1u64 << 8, 1u64 << 9, 1u64 << 10, 1u64 << 11,
    1u64 << 12, 1u64 << 13, 1u64 << 14, 1u64 << 15,
];

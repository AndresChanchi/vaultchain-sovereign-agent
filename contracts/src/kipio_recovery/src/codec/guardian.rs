//! Packed guardian metadata helpers.
//!
//! Two fields per version are packed into single slots. Unpacking is
//! pure in-memory bit manipulation on the already-loaded word; no SLOAD
//! is performed inside these helpers.

use stylus_sdk::alloy_primitives::{B256, U256};

use crate::config::constants::MAX_GUARDIANS;

/// Unpacks `(count, threshold, update_reason)` from a single `U256`.
/// Bytes `[0]=count`, `[1]=threshold`, `[2]=update_reason`.
#[inline]
pub(crate) fn guardian_meta_unpack(packed: U256) -> (u8, u8, u8) {
    let bytes: [u8; 32] = packed.to_be_bytes();
    (bytes[0], bytes[1], bytes[2])
}

/// Packs `(count, threshold, update_reason)` into a single `U256`.
#[inline]
pub(crate) fn guardian_meta_pack(count: u8, threshold: u8, update_reason: u8) -> U256 {
    let mut bytes = [0u8; 32];
    bytes[0] = count;
    bytes[1] = threshold;
    bytes[2] = update_reason;
    U256::from_be_bytes(bytes)
}

/// Packs the per-guardian `(type, curve)` pairs into a single `B256`.
/// Bytes `[0..16)` hold types, bytes `[16..32)` hold curves.
///
/// Both arrays are `u8` and at most `MAX_GUARDIANS` long, so the whole
/// schedule fits in exactly one slot. This is the key storage
/// compression: a version with N guardians writes exactly `2 + N` slots
/// (meta + schedule + N identifiers).
#[inline]
pub(crate) fn guardian_schedule_pack(types: &[u8], curves: &[u8]) -> B256 {
    let mut bytes = [0u8; 32];
    let n_types = types.len().min(MAX_GUARDIANS);
    bytes[0..n_types].copy_from_slice(&types[0..n_types]);
    let n_curves = curves.len().min(MAX_GUARDIANS);
    bytes[16..16 + n_curves].copy_from_slice(&curves[0..n_curves]);
    B256::from_slice(&bytes)
}

//! Full-slot pack and unpack helpers for the `packed` field.

use stylus_sdk::alloy_primitives::U256;

use crate::config::constants::CURRENT_SCHEMA;

/// @dev Packs all metadata into a single U256.
pub fn pack_metadata(
    version: u64,
    created_at: u64,
    updated_at: u64,
    provider_id: u8,
    is_public: bool,
    storage_term: u8,
    expiry_delta: u32,
) -> U256 {
    let mut bytes: [u8; 32] = [0u8; 32];
    bytes[0..8].copy_from_slice(&version.to_be_bytes());
    bytes[8..16].copy_from_slice(&created_at.to_be_bytes());
    bytes[16..24].copy_from_slice(&updated_at.to_be_bytes());
    bytes[24] = provider_id;
    bytes[25] = if is_public { 1 } else { 0 };
    bytes[26] = CURRENT_SCHEMA;
    bytes[27] = storage_term;
    bytes[28..32].copy_from_slice(&expiry_delta.to_be_bytes());
    U256::from_be_bytes(bytes)
}

/// @dev Unpacks all metadata fields.
pub fn unpack_metadata(packed: U256) -> (u64, u64, u64, u8, bool, u8, u32) {
    let bytes: [u8; 32] = packed.to_be_bytes();
    let version = u64::from_be_bytes(bytes[0..8].try_into().unwrap());
    let created_at = u64::from_be_bytes(bytes[8..16].try_into().unwrap());
    let updated_at = u64::from_be_bytes(bytes[16..24].try_into().unwrap());
    let provider_id = bytes[24];
    let is_public = bytes[25] != 0;
    let storage_term = bytes[27];
    let expiry_delta = u32::from_be_bytes(bytes[28..32].try_into().unwrap());
    (version, created_at, updated_at, provider_id, is_public, storage_term, expiry_delta)
}

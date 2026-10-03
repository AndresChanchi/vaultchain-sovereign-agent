//! Partial writers that update a single field, preserving the rest.

use stylus_sdk::alloy_primitives::U256;

pub fn write_version(packed: U256, version: u64) -> U256 {
    let mut bytes: [u8; 32] = packed.to_be_bytes();
    bytes[0..8].copy_from_slice(&version.to_be_bytes());
    U256::from_be_bytes(bytes)
}

pub fn write_updated_at(packed: U256, updated_at: u64) -> U256 {
    let mut bytes: [u8; 32] = packed.to_be_bytes();
    bytes[16..24].copy_from_slice(&updated_at.to_be_bytes());
    U256::from_be_bytes(bytes)
}

pub fn write_is_public_and_updated_at(packed: U256, is_public: bool, updated_at: u64) -> U256 {
    let mut bytes: [u8; 32] = packed.to_be_bytes();
    bytes[16..24].copy_from_slice(&updated_at.to_be_bytes());
    bytes[25] = if is_public { 1 } else { 0 };
    U256::from_be_bytes(bytes)
}

pub fn write_storage_term_and_expiry(
    packed: U256,
    storage_term: u8,
    expiry_delta: u32,
    updated_at: u64,
) -> U256 {
    let mut bytes: [u8; 32] = packed.to_be_bytes();
    bytes[16..24].copy_from_slice(&updated_at.to_be_bytes());
    bytes[27] = storage_term;
    bytes[28..32].copy_from_slice(&expiry_delta.to_be_bytes());
    U256::from_be_bytes(bytes)
}

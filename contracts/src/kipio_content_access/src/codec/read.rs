//! Partial readers that extract a single field without unpacking the
//! whole word.

use stylus_sdk::alloy_primitives::U256;

pub fn read_version(packed: U256) -> u64 {
    let bytes: [u8; 32] = packed.to_be_bytes();
    u64::from_be_bytes(bytes[0..8].try_into().unwrap())
}

pub fn read_created_at(packed: U256) -> u64 {
    let bytes: [u8; 32] = packed.to_be_bytes();
    u64::from_be_bytes(bytes[8..16].try_into().unwrap())
}

pub fn read_is_public(packed: U256) -> bool {
    let bytes: [u8; 32] = packed.to_be_bytes();
    bytes[25] != 0
}

pub fn read_storage_term(packed: U256) -> u8 {
    let bytes: [u8; 32] = packed.to_be_bytes();
    bytes[27]
}

pub fn read_expiry_delta(packed: U256) -> u32 {
    let bytes: [u8; 32] = packed.to_be_bytes();
    u32::from_be_bytes(bytes[28..32].try_into().unwrap())
}

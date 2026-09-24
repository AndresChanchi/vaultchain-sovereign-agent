//! Validation, resolution, and derivation helpers for provider IDs and
//! storage terms.

use alloc::vec::Vec;

use stylus_sdk::alloy_sol_types::SolError;

use crate::abi::errors::{InvalidExpiryDelta, UnsupportedProvider, UnsupportedStorageTerm};
use crate::config::constants::{
    MAX_EXPIRY_DELTA, SECONDS_1_YEAR, SECONDS_30_DAYS, STORAGE_TERM_1_YEAR,
    STORAGE_TERM_30_DAYS, STORAGE_TERM_CUSTOM, STORAGE_TERM_PERMANENT,
};

pub fn validate_provider_id(provider_id: u8) -> Result<(), Vec<u8>> {
    match provider_id {
        0 | 1 | 2 | 3 => Ok(()),
        _ => Err(UnsupportedProvider {}.abi_encode()),
    }
}

pub fn validate_storage_term(term: u8) -> Result<(), Vec<u8>> {
    match term {
        STORAGE_TERM_PERMANENT
        | STORAGE_TERM_30_DAYS
        | STORAGE_TERM_1_YEAR
        | STORAGE_TERM_CUSTOM => Ok(()),
        _ => Err(UnsupportedStorageTerm {}.abi_encode()),
    }
}

pub fn resolve_expiry_delta(term: u8, custom_delta: u32) -> Result<u32, Vec<u8>> {
    match term {
        STORAGE_TERM_PERMANENT => Ok(0),
        STORAGE_TERM_30_DAYS => Ok(SECONDS_30_DAYS),
        STORAGE_TERM_1_YEAR => Ok(SECONDS_1_YEAR),
        STORAGE_TERM_CUSTOM => {
            if custom_delta == 0 {
                return Err(InvalidExpiryDelta {}.abi_encode());
            }
            if custom_delta > MAX_EXPIRY_DELTA {
                return Err(InvalidExpiryDelta {}.abi_encode());
            }
            Ok(custom_delta)
        }
        _ => Err(UnsupportedStorageTerm {}.abi_encode()),
    }
}

pub fn compute_absolute_expiry(created_at: u64, expiry_delta: u32) -> u64 {
    if expiry_delta == 0 {
        return 0;
    }
    created_at.saturating_add(expiry_delta as u64)
}

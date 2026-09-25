//! # Per-Content Access Control
//!
//! Tracks permissions plus an O(1) index for pagination and swap-and-pop
//! removal of grantees.

use stylus_sdk::prelude::*;
use stylus_sdk::{
    alloy_primitives::{Address, B256},
    storage::{StorageAddress, StorageBool, StorageMap, StorageU256, StorageVec},
};

#[storage]
pub struct ContentAccess {
    pub permissions: StorageMap<B256, StorageMap<Address, StorageBool>>,
    pub grantee_index: StorageMap<B256, StorageVec<StorageAddress>>,
    pub grantee_positions: StorageMap<B256, StorageMap<Address, StorageU256>>,
}

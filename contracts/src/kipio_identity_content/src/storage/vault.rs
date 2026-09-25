//! # Per-User Vault
//!
//! Each caller has exactly one vault. Contents are addressed by B256
//! `content_id`. The `content_positions` map gives O(1) lookup of the
//! index inside `content_list` for swap-and-pop deletion.

use stylus_sdk::prelude::*;
use stylus_sdk::{
    alloy_primitives::B256,
    storage::{StorageB256, StorageMap, StorageU256, StorageVec},
};

use crate::storage::access::ContentAccess;
use crate::storage::commitment::ContentCommitment;

#[storage]
pub struct ContentVault {
    pub contents: StorageMap<B256, ContentCommitment>,
    pub content_list: StorageVec<StorageB256>,
    pub content_positions: StorageMap<B256, StorageU256>,
    pub access: ContentAccess,
}

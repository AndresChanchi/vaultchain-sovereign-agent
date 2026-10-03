//! # Content Commitment
//!
//! One slot per content. The `packed` word holds every scalar field.
//! The two B256 fields anchor the content to its off-chain integrity
//! proof and its access policy.

use stylus_sdk::prelude::*;
use stylus_sdk::storage::{StorageB256, StorageU256};

#[storage]
pub struct ContentCommitment {
    pub packed: StorageU256,
    pub tx_commitment: StorageB256,
    pub access_policy_hash: StorageB256,
}

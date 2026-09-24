//! # Entrypoint
//!
//! Root storage struct for `KipioContentAccess`. This is the only struct
//! annotated with `#[entrypoint]`; the ABI dispatch is generated for it.

use stylus_sdk::prelude::*;
use stylus_sdk::{
    alloy_primitives::{Address, B256},
    storage::{StorageAddress, StorageB256, StorageBool, StorageMap, StorageU256},
};

use crate::storage::vault::ContentVault;

#[storage]
#[entrypoint]
pub struct KipioContentAccess {
    pub storage_provider: StorageAddress,
    pub query_provider: StorageAddress,
    pub access_provider: StorageAddress,
    pub zk_verifier: StorageAddress,

    pub owner: StorageAddress,
    pub pending_owner: StorageAddress,
    pub paused: StorageBool,
    pub pause_reason_hash: StorageB256,
    pub initialized: StorageBool,

    pub global_registrations: StorageU256,
    pub global_queries: StorageU256,

    pub pending_queries: StorageMap<B256, StorageBool>,
    pub query_timestamps: StorageMap<B256, StorageU256>,
    pub active_query_counts: StorageMap<Address, StorageU256>,
    pub query_requesters: StorageMap<B256, StorageAddress>,
    pub query_content_hashes: StorageMap<B256, StorageB256>,

    pub expected_workflow_id: StorageB256,

    pub vaults: StorageMap<Address, ContentVault>,
}

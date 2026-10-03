//! Root storage struct for `kipio_account`.

use stylus_sdk::{
    alloy_primitives::B256,
    prelude::*,
    storage::{StorageAddress, StorageBool, StorageBytes, StorageMap, StorageU64, StorageU8},
};

#[storage]
#[entrypoint]
pub struct KipioAccount {
    // ---- Metadata (immutable after constructor) --------------------------
    pub(crate) identity_id: StorageAddress,
    pub(crate) runtime_address: StorageAddress,
    pub(crate) recovery_address: StorageAddress,
    pub(crate) initialized: StorageBool,
    pub(crate) nonce: StorageU64,

    // ---- Hot path (frequent, small writes) -------------------------------
    pub(crate) consumed_replay_keys: StorageMap<B256, StorageBool>,
    pub(crate) credential_statuses: StorageMap<B256, StorageU8>,

    // ---- Cold path (rare, full blob) -------------------------------------
    pub(crate) auth_state: StorageBytes,
}

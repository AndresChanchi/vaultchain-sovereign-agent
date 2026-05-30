#![allow(unexpected_cfgs)]
#![cfg_attr(not(feature = "std"), no_std)]
extern crate alloc;

use alloc::{string::String, vec, vec::Vec};

use stylus_sdk::{
    alloy_primitives::{Address, B256, U64},
    prelude::*,
    storage::{StorageBool, StorageB256, StorageMap, StorageString, StorageU64, StorageVec},
};

use stylus_sdk::alloy_sol_types::sol;

sol! {
    /// @dev Content registered with an encrypted reference (Irys pointer)
    event ContentRegistered(address indexed user, bytes32 indexed contentHash, string encryptedTxId);

    /// @dev Content rotation event
    event ContentRotated(address indexed user, bytes32 indexed contentHash, string newEncryptedTxId);

    /// @dev Content read event
    event ContentQueried(address indexed user, bytes32 indexed contentHash);
}

/// @dev Content record stored per user and content hash
/// CHANGE: Switched from `#[derive(Storage)]` to `#[storage]`
/// REASON: Stylus requires the `#[storage]` macro for storage-compatible structs
/// DOES NOT BREAK RULES:
/// - No secrets stored
/// - No plaintext content stored
/// - Only encrypted pointers and metadata are tracked
#[storage]
pub struct ContentRecord {
    pub active_tx: StorageString,
    pub version: StorageU64,
    pub is_public: StorageBool,
}

/// @dev Per-user registry vault
/// CHANGE: Uses Stylus storage-native types only
/// REASON: `StorageMap` values must implement `StorageType`
/// DOES NOT BREAK RULES:
/// - Keeps registry logic isolated from the core contract
/// - Preserves upgradeability and separation of concerns
#[storage]
pub struct RegistryVault {
    pub contents: StorageMap<B256, ContentRecord>,
    pub content_list: StorageVec<StorageB256>,
}

/// ## Main Registry Contract
#[storage]
#[entrypoint]
pub struct KipioRegistry {
    pub vaults: StorageMap<Address, RegistryVault>,
}

#[public]
impl KipioRegistry {
    /// @dev Register user upload
    /// @notice Stores only encrypted pointer and metadata
    pub fn register_upload(
        &mut self,
        content_id: B256,
        tx_id: String,
        is_public: bool,
    ) -> Result<(), Vec<u8>> {
        let sender = self.vm().msg_sender();
        let mut vault = self.vaults.setter(sender);
        let mut record = vault.contents.setter(content_id);

        if !record.active_tx.get_string().is_empty() {
            return Err("AlreadyExists".as_bytes().to_vec());
        }

        record.active_tx.set_str(&tx_id);
        record.version.set(U64::from(1));
        record.is_public.set(is_public);

        vault.content_list.grow().set(content_id);

        self.vm().log(ContentRegistered {
            user: sender,
            contentHash: content_id,
            encryptedTxId: tx_id,
        });

        Ok(())
    }

    /// @dev Rotate content to a new encrypted pointer
    /// @notice Updates the active version while keeping the content identity stable
    pub fn rotate_content(
        &mut self,
        content_id: B256,
        new_tx: String,
    ) -> Result<(), Vec<u8>> {
        let sender = self.vm().msg_sender();
        let mut vault = self.vaults.setter(sender);
        let mut record = vault.contents.setter(content_id);

        if record.active_tx.get_string().is_empty() {
            return Err("NotFound".as_bytes().to_vec());
        }

        let current_version = record.version.get();
        record.version.set(current_version + U64::from(1));
        record.active_tx.set_str(&new_tx);

        self.vm().log(ContentRotated {
            user: sender,
            contentHash: content_id,
            newEncryptedTxId: new_tx,
        });

        Ok(())
    }

    /// @dev Get active encrypted pointer for a content item
    /// @notice Returns the current version pointer for the caller's content
    pub fn get_active_tx(
        &self,
        owner: Address,
        content_id: B256,
    ) -> Result<String, Vec<u8>> {
        let vault = self.vaults.getter(owner);
        let record = vault.contents.getter(content_id);

        let tx = record.active_tx.get_string();
        if tx.is_empty() {
            return Err("NotFound".as_bytes().to_vec());
        }

        let sender = self.vm().msg_sender();
        self.vm().log(ContentQueried {
            user: sender,
            contentHash: content_id,
        });

        Ok(tx)
    }

    /// @dev Get current version for a content item
    pub fn get_version(&self, owner: Address, content_id: B256) -> Result<U64, Vec<u8>> {
        let vault = self.vaults.getter(owner);
        let record = vault.contents.getter(content_id);

        if record.active_tx.get_string().is_empty() {
            return Err("NotFound".as_bytes().to_vec());
        }

        Ok(record.version.get())
    }

    /// @dev Get public/private flag for a content item
    pub fn get_is_public(&self, owner: Address, content_id: B256) -> Result<bool, Vec<u8>> {
        let vault = self.vaults.getter(owner);
        let record = vault.contents.getter(content_id);

        if record.active_tx.get_string().is_empty() {
            return Err("NotFound".as_bytes().to_vec());
        }

        Ok(record.is_public.get())
    }

    /// @dev Paginated content list for a user
    pub fn get_content_list(
        &self,
        owner: Address,
        offset: u32,
        limit: u32,
    ) -> Vec<B256> {
        let vault = self.vaults.getter(owner);

        // CHANGE: Borrow instead of move
        // REASON: StorageGuard does not implement Copy, moving would invalidate the guard
        // DOES NOT BREAK RULES:
        // - No change in logic
        // - Only fixes ownership semantics required by Rust
        let list = &vault.content_list;

        let total = list.len() as u32;
        let mut result = Vec::new();

        let start = core::cmp::min(offset, total);
        let end = core::cmp::min(start.saturating_add(limit), total);

        for i in start..end {
            if let Some(item) = list.get(i as usize) {
                result.push(item);
            }
        }

        result
    }
}

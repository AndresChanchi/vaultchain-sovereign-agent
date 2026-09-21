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
    /// @dev Content registered with an encrypted reference (e.g., Irys / Arweave pointer).
    event ContentRegistered(address indexed user, bytes32 indexed contentHash, string encryptedTxId);

    /// @dev Content rotation event triggered during cryptographic upgrades or cipher key changes.
    event ContentRotated(address indexed user, bytes32 indexed contentHash, string newEncryptedTxId);

    /// @dev Content visibility update event.
    /// @notice Emitted whenever a content item transitions between public and private access states.
    event ContentVisibilityUpdated(address indexed user, bytes32 indexed contentHash, bool isPublic);
}

/// @title Content Record Storage Structure
/// @notice Defines the internal data mapping for a single permanent storage pointer.
/// @dev Mapped entirely via native Stylus SDK storage types.
#[storage]
pub struct ContentRecord {
    /// @notice Current permanent data transaction hash pointer (e.g., Irys / Arweave).
    pub active_tx: StorageString,
    /// @notice Monotonically increasing counter indicating the cryptographic rotation generation.
    pub version: StorageU64,
    /// @notice Dynamic authorization flag determining frontend exposure filtering.
    pub is_public: StorageBool,
    /// @notice Unix timestamp marking the exact block creation time.
    pub created_at: StorageU64,
    /// @notice Unix timestamp marking the last state change (rotation or visibility change).
    pub updated_at: StorageU64,
}

/// @title Per-User Registry Vault Configuration
/// @dev Implements a custom structural namespace within the global multi-tenant storage mapping.
#[storage]
pub struct RegistryVault {
    pub contents: StorageMap<B256, ContentRecord>,
    pub content_list: StorageVec<StorageB256>,
}

/// @title Kipio Decentralized Infrastructure Registry
/// @notice Core permanent database tracking metadata pointers without third-party dependencies.
/// @dev Isolated multi-tenant tracking mechanism tailored for Crypto-Agile storage handshakes.
#[storage]
#[entrypoint]
pub struct KipioRegistry {
    pub vaults: StorageMap<Address, RegistryVault>,
}

#[public]
impl KipioRegistry {
    /// @notice Registers a fresh user data entry pointing to an encrypted infrastructure file.
    /// @dev Implements timestamp isolation sequence to explicitly satisfy the Rust Borrow Checker.
    /// @param content_id Stable unique business key identifier of the data payload.
    /// @param tx_id The initially deployed encrypted network transaction string reference.
    /// @param is_public Accessibility setting flag declared by the client frontend entity.
    pub fn register_upload(
        &mut self,
        content_id: B256,
        tx_id: String,
        is_public: bool,
    ) -> Result<(), Vec<u8>> {
        // FIX: Extract block timestamp BEFORE acquiring mutable storage references.
        // REASON: Avoids E0502 compilation collision where `&self` overlaps with `&mut self`.
        let current_timestamp = self.vm().block_timestamp();
        let sender = self.vm().msg_sender();
        
        let mut vault = self.vaults.setter(sender);
        let mut record = vault.contents.setter(content_id);

        if !record.active_tx.get_string().is_empty() {
            return Err("AlreadyExists".as_bytes().to_vec());
        }

        record.active_tx.set_str(&tx_id);
        record.version.set(U64::from(1));
        record.is_public.set(is_public);
        
        // Populate newly added historical tracking temporal slots
        record.created_at.set(U64::from(current_timestamp));
        record.updated_at.set(U64::from(current_timestamp));

        vault.content_list.grow().set(content_id);

        self.vm().log(ContentRegistered {
            user: sender,
            contentHash: content_id,
            encryptedTxId: tx_id,
        });

        Ok(())
    }

    /// @notice Updates the transaction pointer while preserving the immutable logical asset identifier.
    /// @dev Used for Crypto-Agile standard upgrades, system key rotations, or cipher migration.
    /// @param content_id Stable identifier of the payload targeted for cryptographic updating.
    /// @param new_tx The replacement transaction identifier pointer containing modified cipher parameters.
    pub fn rotate_content(
        &mut self,
        content_id: B256,
        new_tx: String,
    ) -> Result<(), Vec<u8>> {
        // FIX: Extract block timestamp BEFORE acquiring mutable storage references.
        // REASON: Prevents concurrent immutable and mutable borrowing violations.
        let current_timestamp = self.vm().block_timestamp();
        let sender = self.vm().msg_sender();
        
        let mut vault = self.vaults.setter(sender);
        let mut record = vault.contents.setter(content_id);

        if record.active_tx.get_string().is_empty() {
            return Err("NotFound".as_bytes().to_vec());
        }

        let current_version = record.version.get();
        record.version.set(current_version + U64::from(1));
        record.active_tx.set_str(&new_tx);
        
        // Update the mutation tracking clock reference
        record.updated_at.set(U64::from(current_timestamp));

        self.vm().log(ContentRotated {
            user: sender,
            contentHash: content_id,
            newEncryptedTxId: new_tx,
        });

        Ok(())
    }

    /// @notice Toggles accessibility configuration for a defined data package dynamically.
    /// @dev Avoids redundant storage mutations if the new flag matches the current persistent state.
    /// @param content_id Stable unique asset tracking index hash.
    /// @param is_public Target access state to override current metadata flag.
    pub fn set_visibility(
        &mut self,
        content_id: B256,
        is_public: bool,
    ) -> Result<(), Vec<u8>> {
        // FIX: Extract block timestamp BEFORE acquiring mutable storage references.
        // REASON: Clears potential storage-guard lifetimes overlapping with low-level execution calls.
        let current_timestamp = self.vm().block_timestamp();
        let sender = self.vm().msg_sender();
        
        let mut vault = self.vaults.setter(sender);
        let mut record = vault.contents.setter(content_id);

        if record.active_tx.get_string().is_empty() {
            return Err("NotFound".as_bytes().to_vec());
        }

        // OPTIMIZATION: Early return if target visibility state equals current storage value.
        // REASON: Prevents redundant `sstore` operational gas overhead and event generation.
        if record.is_public.get() == is_public {
            return Ok(());
        }

        record.is_public.set(is_public);
        record.updated_at.set(U64::from(current_timestamp));

        self.vm().log(ContentVisibilityUpdated {
            user: sender,
            contentHash: content_id,
            isPublic: is_public,
        });

        Ok(())
    }

    /// @notice External viewer for resolving data pointers.
    /// @param owner Targeted storage root index address.
    /// @param content_id Unique target indexing identification key.
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

        Ok(tx)
    }

    /// @notice Resolves current active version index tier of an individual upload tracking item.
    pub fn get_version(&self, owner: Address, content_id: B256) -> Result<U64, Vec<u8>> {
        let vault = self.vaults.getter(owner);
        let record = vault.contents.getter(content_id);

        if record.active_tx.get_string().is_empty() {
            return Err("NotFound".as_bytes().to_vec());
        }

        Ok(record.version.get())
    }

    /// @notice Resolves visibility configuration rules for a given entry asset block.
    pub fn get_is_public(&self, owner: Address, content_id: B256) -> Result<bool, Vec<u8>> {
        let vault = self.vaults.getter(owner);
        let record = vault.contents.getter(content_id);

        if record.active_tx.get_string().is_empty() {
            return Err("NotFound".as_bytes().to_vec());
        }

        Ok(record.is_public.get())
    }

    /// @notice Resolves the precise block timestamp when the resource was registered.
    pub fn get_created_at(&self, owner: Address, content_id: B256) -> Result<U64, Vec<u8>> {
        let vault = self.vaults.getter(owner);
        let record = vault.contents.getter(content_id);

        if record.active_tx.get_string().is_empty() {
            return Err("NotFound".as_bytes().to_vec());
        }

        Ok(record.created_at.get())
    }

    /// @notice Resolves the block timestamp corresponding to the latest structural alteration.
    pub fn get_updated_at(&self, owner: Address, content_id: B256) -> Result<U64, Vec<u8>> {
        let vault = self.vaults.getter(owner);
        let record = vault.contents.getter(content_id);

        if record.active_tx.get_string().is_empty() {
            return Err("NotFound".as_bytes().to_vec());
        }

        Ok(record.updated_at.get())
    }

    /// @notice Returns linear chunk lists tracking registered unique business index hashes for analytical interfaces.
    pub fn get_content_list(
        &self,
        owner: Address,
        offset: u32,
        limit: u32,
    ) -> Vec<B256> {
        let vault = self.vaults.getter(owner);
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

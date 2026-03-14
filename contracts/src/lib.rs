#![allow(unexpected_cfgs)]
#![cfg_attr(not(feature = "std"), no_std)]
extern crate alloc;

/// @title VaultChain Metadata Registry
/// @author Andres Chanchi
/// @notice This contract serves as a decentralized, privacy-focused registry for encrypted transaction metadata.
/// @dev Implements Arbitrum Stylus SDK 0.10.2 utilizing the HostIO trait-based model for efficient storage management.
use alloc::{string::String, vec::Vec};
use stylus_sdk::{
    alloy_primitives::{Address, B256},
    prelude::*,
    storage::{StorageMap, StorageString, StorageVec, StorageB256},
};

use stylus_sdk::alloy_sol_types::sol;

sol! {
    /// @notice Emitted when a new photo/content hash is successfully registered to a user's vault.
    /// @param user The address of the vault owner.
    /// @param contentHash The SHA-256/B256 identifier of the content.
    /// @param encryptedTxId The off-chain storage reference (e.g., Irys/Arweave transaction ID).
    event PhotoRegistered(address indexed user, bytes32 indexed contentHash, string encryptedTxId);
}

/// @dev Internal storage structure for individual user vaults.
#[storage]
pub struct UserVault {
    /// @notice A collection of all content hashes registered by the user.
    pub hashes: StorageVec<StorageB256>,
    /// @notice A mapping from content hash to its associated encrypted transaction ID.
    pub registry: StorageMap<B256, StorageString>,
}

/// @dev Main entry point for the VaultChain sovereign agent contract.
#[storage]
#[entrypoint]
pub struct VaultChainMVP {
    /// @notice Root mapping connecting user addresses to their private metadata vaults.
    pub vaults: StorageMap<Address, UserVault>,
}

#[public]
impl VaultChainMVP {
    
    /// @notice Registers a single upload by linking a content hash to an encrypted transaction ID.
    /// @dev Implements a scope-block strategy to satisfy the Rust borrow checker when interacting with Stylus HostIO.
    /// @param content_hash The unique B256 identifier of the file.
    /// @param encrypted_tx_id The encrypted string representing the permanent storage location.
    /// @return Result<(), Vec<u8>> returns Ok on success or an error vector.
    pub fn register_upload(&mut self, content_hash: B256, encrypted_tx_id: String) -> Result<(), Vec<u8>> {
        let sender = self.vm().msg_sender();
        
        // 1. Scope block to manage mutable borrow of 'self' via 'user_vault'
        let success = {
            let mut user_vault = self.vaults.setter(sender);
            if user_vault.registry.getter(content_hash).get_string().is_empty() {
                user_vault.registry.setter(content_hash).set_str(&encrypted_tx_id);
                user_vault.hashes.grow().set(content_hash);
                true
            } else {
                false
            }
        }; // mutable borrow of user_vault ends here, releasing 'self'

        // 2. 'self' is now available for the immutable borrow required by the log event
        if success {
            self.vm().log(PhotoRegistered {
                user: sender,
                contentHash: content_hash,
                encryptedTxId: encrypted_tx_id,
            });
        }

        Ok(())
    }

    /// @notice Batch registers multiple uploads in a single transaction to optimize gas costs.
    /// @dev Validates that input arrays match in length before processing.
    /// @param hashes A list of B256 content hashes.
    /// @param encrypted_ids A list of corresponding encrypted transaction IDs.
    pub fn register_batch(&mut self, hashes: Vec<B256>, encrypted_ids: Vec<String>) -> Result<(), Vec<u8>> {
        if hashes.len() != encrypted_ids.len() {
            return Err("MismatchedArrays".as_bytes().to_vec());
        }

        let sender = self.vm().msg_sender();

        for (hash, encrypted_id) in hashes.into_iter().zip(encrypted_ids.into_iter()) {
            // Apply scoped-borrow logic within the loop iteration
            let registered = {
                let mut user_vault = self.vaults.setter(sender);
                if user_vault.registry.getter(hash).get_string().is_empty() {
                    user_vault.registry.setter(hash).set_str(&encrypted_id);
                    user_vault.hashes.grow().set(hash);
                    true
                } else {
                    false
                }
            };

            if registered {
                self.vm().log(PhotoRegistered {
                    user: sender,
                    contentHash: hash,
                    encryptedTxId: encrypted_id,
                });
            }
        }
        Ok(())
    }

    /// @notice Retrieves the encrypted transaction ID for a specific content hash.
    /// @param content_hash The B256 identifier to query.
    /// @return String The associated transaction ID or an empty string if not found.
    pub fn get_my_photo(&self, content_hash: B256) -> String {
        let sender = self.vm().msg_sender();
        self.vaults.getter(sender).registry.getter(content_hash).get_string()
    }

    /// @notice Returns a paginated list of content hashes for the caller's vault.
    /// @param offset The starting index for pagination.
    /// @param limit The maximum number of items to return.
    /// @return Vec<B256> A slice of the user's registered content hashes.
    pub fn get_my_gallery_paginated(&self, offset: u32, limit: u32) -> Vec<B256> {
        let sender = self.vm().msg_sender();
        let user_vault = self.vaults.getter(sender);
        
        let total = user_vault.hashes.len() as u32;
        let mut result = Vec::new();
        let start = core::cmp::min(offset, total);
        let end = core::cmp::min(start.saturating_add(limit), total);

        for i in start..end {
            if let Some(h) = user_vault.hashes.get(i as usize) {
                result.push(h);
            }
        }
        result
    }

    /// @notice Returns the total count of registered photos in the user's vault.
    /// @return u32 Total number of entries.
    pub fn get_my_total_photos(&self) -> u32 {
        let sender = self.vm().msg_sender();
        self.vaults.getter(sender).hashes.len() as u32
    }
}

#[cfg(test)]
mod tests;

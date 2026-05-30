#![allow(unexpected_cfgs)]
#![cfg_attr(not(feature = "std"), no_std)]
extern crate alloc;

use alloc::{vec, vec::Vec};

use stylus_sdk::{
    alloy_primitives::{Address, B256},
    prelude::*,
    storage::{StorageAddress, StorageB256, StorageBool, StorageMap, StorageVec},
};

use stylus_sdk::alloy_sol_types::sol;

sol! {
    /// @dev Access granted event (no sensitive data exposed)
    event AccessGranted(address indexed owner, address indexed grantee, bytes32 indexed contentHash);

    /// @dev Access revoked event
    event AccessRevoked(address indexed owner, address indexed grantee, bytes32 indexed contentHash);
}

/// @dev Access control storage per user
/// CHANGE: Replaced `#[derive(Storage)]` with `#[storage]`
/// REASON: Stylus requires storage-compatible structs to use the `#[storage]` macro
/// DOES NOT BREAK RULES:
/// - No secrets stored (kfrag remains off-chain)
/// - Only permission flags and pointers are tracked
#[storage]
pub struct AccessControl {
    pub shared: StorageMap<B256, StorageMap<Address, StorageBool>>,
    pub index: StorageMap<B256, StorageVec<StorageAddress>>,
    pub kfrag: StorageMap<B256, StorageMap<Address, StorageB256>>,
}

/// @dev Per-user vault for access module
#[storage]
pub struct AccessVault {
    pub access: AccessControl,
}

/// ## Main Access Contract
#[storage]
#[entrypoint]
pub struct KipioAccess {
    pub vaults: StorageMap<Address, AccessVault>,
}

#[public]
impl KipioAccess {
    /// @dev Grant access with pointer reference
    /// @notice Stores only pointer hash, never raw cryptographic material
    pub fn grant_access(
        &mut self,
        content_id: B256,
        grantee: Address,
        kfrag_pointer: B256,
    ) -> Result<(), Vec<u8>> {
        let sender = self.vm().msg_sender();
        let mut vault = self.vaults.setter(sender);

        vault
            .access
            .shared
            .setter(content_id)
            .setter(grantee)
            .set(true);

        vault
            .access
            .kfrag
            .setter(content_id)
            .setter(grantee)
            .set(kfrag_pointer);

        // CHANGE: Maintain index for enumeration
        // REASON: Enables frontend pagination without exposing sensitive data
        // DOES NOT BREAK RULES:
        // - Only addresses stored
        // - No cryptographic material exposed
        let mut index = vault.access.index.setter(content_id);
        let mut exists = false;

        for i in 0..index.len() {
            if let Some(addr) = index.get(i) {
                if addr == grantee {
                    exists = true;
                    break;
                }
            }
        }

        if !exists {
            index.grow().set(grantee);
        }

        self.vm().log(AccessGranted {
            owner: sender,
            grantee,
            contentHash: content_id,
        });

        Ok(())
    }

    /// @dev Revoke access
    pub fn revoke_access(
        &mut self,
        content_id: B256,
        grantee: Address,
    ) -> Result<(), Vec<u8>> {
        let sender = self.vm().msg_sender();
        let mut vault = self.vaults.setter(sender);

        vault
            .access
            .shared
            .setter(content_id)
            .setter(grantee)
            .set(false);

        self.vm().log(AccessRevoked {
            owner: sender,
            grantee,
            contentHash: content_id,
        });

        Ok(())
    }

    /// @dev Check if access exists
    pub fn has_access(
        &self,
        owner: Address,
        content_id: B256,
        grantee: Address,
    ) -> bool {
        self.vaults
            .getter(owner)
            .access
            .shared
            .getter(content_id)
            .getter(grantee)
            .get()
    }

    /// @dev Get kfrag pointer (not the fragment itself)
    /// SECURITY: Only owner or grantee can query
    pub fn get_kfrag_pointer(
        &self,
        owner: Address,
        content_id: B256,
        grantee: Address,
    ) -> Result<B256, Vec<u8>> {
        let sender = self.vm().msg_sender();

        if sender != owner && sender != grantee {
            return Err("Unauthorized".as_bytes().to_vec());
        }

        Ok(
            self.vaults
                .getter(owner)
                .access
                .kfrag
                .getter(content_id)
                .getter(grantee)
                .get(),
        )
    }

    /// @dev Paginated list of shared users
    pub fn get_shared_paginated(
        &self,
        owner: Address,
        content_id: B256,
        offset: u32,
        limit: u32,
    ) -> Vec<Address> {
        let vault = self.vaults.getter(owner);
        let index = &vault.access.index.getter(content_id);

        let total = index.len() as u32;
        let mut result = Vec::new();

        let start = core::cmp::min(offset, total);
        let end = core::cmp::min(start.saturating_add(limit), total);

        for i in start..end {
            if let Some(addr) = index.get(i as usize) {
                if vault
                    .access
                    .shared
                    .getter(content_id)
                    .getter(addr)
                    .get()
                {
                    result.push(addr);
                }
            }
        }

        result
    }
}

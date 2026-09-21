#![allow(unexpected_cfgs)]
#![cfg_attr(not(feature = "std"), no_std)]

extern crate alloc;

use alloc::vec::Vec;

use stylus_sdk::{
    alloy_primitives::{Address, B256},
    prelude::*,
    storage::{StorageAddress, StorageBool, StorageMap, StorageVec},
};

use stylus_sdk::alloy_sol_types::sol;

sol! {
    /// @dev Access granted event (no sensitive data exposed).
    event AccessGranted(address indexed owner, address indexed grantee, bytes32 indexed contentHash);

    /// @dev Access revoked event.
    event AccessRevoked(address indexed owner, address indexed grantee, bytes32 indexed contentHash);
}

/// @title Access Control Internal Storage Structure
/// @notice Manages multi-tenant authorization vectors and permissions bookkeeping.
/// @dev Removed manual TPRE-related pointer storage. Threshold re-encryption is handled externally,
/// meaning this contract exclusively tracks active permission states and index enumeration vectors.
#[storage]
pub struct AccessControl {
    /// @notice Maps content identifiers to a sub-map of grantee addresses and their authorization flags.
    /// @dev Renamed from 'shared' to 'permissions' to explicitly reflect its architectural purpose.
    pub permissions: StorageMap<B256, StorageMap<Address, StorageBool>>,
    /// @notice Maps content identifiers to an iterable list of historical or active addresses for pagination.
    pub index: StorageMap<B256, StorageVec<StorageAddress>>,
}

/// @title Per-User Access Vault Wrapper
/// @dev Encapsulates underlying access maps inside an isolated storage namespace per multi-tenant vault.
#[storage]
pub struct AccessVault {
    pub access: AccessControl,
}

/// @title Kipio Sovereign Access Control Module
/// @notice Pure authorization ledger managing content permissions without external system dependencies.
/// @dev Operates fully decoupled from KipioCore, KipioRegistry, or identity verification layers.
#[storage]
#[entrypoint]
pub struct KipioAccess {
    pub vaults: StorageMap<Address, AccessVault>,
}

#[public]
impl KipioAccess {
    /// @notice Grants data package access rights to a specific receiver target address.
    /// @dev Avoids redundant storage mutations and blocks zero-address allocations.
    /// Uses strategic local variable binding to prevent E0716 temporary reference dropping.
    /// @param content_id Stable unique storage payload tracking key hash.
    /// @param grantee The target address authorized to receive re-encryption capabilities.
    pub fn grant_access(
        &mut self,
        content_id: B256,
        grantee: Address,
    ) -> Result<(), Vec<u8>> {
        // VALIDATION: Reject illegal zero-address allocations explicitly
        if grantee == Address::ZERO {
            return Err(b"ZeroAddressTarget".to_vec());
        }

        let sender = self.vm().msg_sender();
        let mut vault = self.vaults.setter(sender);

        // FIX (E0716): Deconstruct setter chaining via sequential let-binding to extend life scopes
        let mut content_map = vault.access.permissions.setter(content_id);
        let mut permission_slot = content_map.setter(grantee);

        // OPTIMIZATION: Early return if permission state is already active
        // REASON: Avoids duplicate operational gas overhead and prevents emitting redundant logs
        if permission_slot.get() {
            return Ok(());
        }

        // Mutation of the permission flag state to active
        permission_slot.set(true);

        // Maintain structural index for linear off-chain frontend pagination
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

    /// @notice Explicitly revokes data access rights from a specific grantee target.
    /// @dev Clears active authorization status flags while ensuring idempotent execution.
    /// @param content_id Stable unique payload asset tracking index hash.
    /// @param grantee Target destination address whose reading access is scheduled for removal.
    pub fn revoke_access(
        &mut self,
        content_id: B256,
        grantee: Address,
    ) -> Result<(), Vec<u8>> {
        // VALIDATION: Reject illegal zero-address checks early
        if grantee == Address::ZERO {
            return Err(b"ZeroAddressTarget".to_vec());
        }

        let sender = self.vm().msg_sender();
        let mut vault = self.vaults.setter(sender);

        // FIX (E0716): Isolate storage lifetime parameters using sequential let-binding rules
        let mut content_map = vault.access.permissions.setter(content_id);
        let mut permission_slot = content_map.setter(grantee);

        // OPTIMIZATION: Early return if permission state is already disabled
        if !permission_slot.get() {
            return Ok(());
        }

        // Reset the boolean storage permission vector flag
        permission_slot.set(false);

        self.vm().log(AccessRevoked {
            owner: sender,
            grantee,
            contentHash: content_id,
        });

        Ok(())
    }

    /// @notice External read viewer checking structural authorization states.
    /// @param owner Deployed root namespace address containing the queried storage maps.
    /// @param content_id Stable identifier key hash tracking the payload matrix.
    /// @param grantee The target reader entity being audited for access capability.
    pub fn has_access(
        &self,
        owner: Address,
        content_id: B256,
        grantee: Address,
    ) -> bool {
        self.vaults
            .getter(owner)
            .access
            .permissions
            .getter(content_id)
            .getter(grantee)
            .get()
    }

    /// @notice Returns chronologically ordered paginated slices of authorized addresses.
    /// @dev Filters out inactive nodes or revoked identities dynamically based on state flags.
    /// @param owner Storage lookup point reference identifying the primary vault location.
    /// @param content_id Target asset container mapping key.
    /// @param offset The array lookup position start index parameter.
    /// @param limit Total maximum item size allocated for array retrieval blocks.
    pub fn get_shared_paginated(
        &self,
        owner: Address,
        content_id: B256,
        offset: u32,
        limit: u32,
    ) -> Vec<Address> {
        let vault = self.vaults.getter(owner);
        let index = vault.access.index.getter(content_id);

        let total = index.len() as u32;
        let mut result = Vec::new();

        let start = core::cmp::min(offset, total);
        let end = core::cmp::min(start.saturating_add(limit), total);

        for i in start..end {
            if let Some(addr) = index.get(i as usize) {
                if vault
                    .access
                    .permissions
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

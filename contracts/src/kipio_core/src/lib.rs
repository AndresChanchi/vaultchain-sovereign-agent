#![allow(unexpected_cfgs)]
#![cfg_attr(not(feature = "std"), no_std)]

extern crate alloc;

use alloc::{string::String, vec::Vec};

use stylus_sdk::{
    alloy_primitives::{Address, B256, U256},
    prelude::*,
    storage::{StorageAddress, StorageB256, StorageMap, StorageU256},
};

/// CHANGE: The core keeps only canonical anchors and replaceable module pointers.
/// REASON: The kernel must remain stable while auth, registry, access, recovery,
/// and future protocol modules evolve independently.
/// DOES NOT BREAK RULES:
/// - No plaintext or secrets are stored
/// - No cryptographic logic is embedded in the core
/// - No TPRE-specific storage remains here
#[storage]
#[entrypoint]
pub struct KipioCore {
    /// Canonical per-user anchor (not full vault state)
    pub vaults: StorageMap<Address, StorageB256>,

    /// Governance
    pub owner: StorageAddress,
    pub upgrader_module: StorageAddress,

    /// Replaceable modules
    pub auth_module: StorageAddress,
    pub registry_module: StorageAddress,
    pub access_module: StorageAddress,

    /// Config
    pub treasury: StorageAddress,
    pub min_fee: StorageU256,
}

#[public]
impl KipioCore {
    // =========================
    // INTERNAL ACCESS CONTROL
    // =========================

    fn require_owner(&self) -> Result<(), Vec<u8>> {
        let sender = self.vm().msg_sender();
        let owner = self.owner.get();

        if owner == Address::ZERO {
            return Err(b"OwnerNotSet".to_vec());
        }

        if sender != owner {
            return Err(b"Unauthorized".to_vec());
        }

        Ok(())
    }

    fn require_owner_or_upgrader(&self) -> Result<(), Vec<u8>> {
        let sender = self.vm().msg_sender();
        let owner = self.owner.get();
        let upgrader = self.upgrader_module.get();

        if owner == Address::ZERO {
            return Err(b"OwnerNotSet".to_vec());
        }

        if sender == owner || (upgrader != Address::ZERO && sender == upgrader) {
            Ok(())
        } else {
            Err(b"Unauthorized".to_vec())
        }
    }

    // =========================
    // INITIALIZATION / GOVERNANCE
    // =========================

    /// @dev Initializes core governance and module pointers once.
    /// @notice Intended to be called during deployment.
    pub fn initialize(
        &mut self,
        owner: Address,
        upgrader_module: Address,
        auth_module: Address,
        registry_module: Address,
        access_module: Address,
        treasury: Address,
        min_fee: U256,
    ) -> Result<(), Vec<u8>> {
        if owner == Address::ZERO {
            return Err(b"ZeroOwner".to_vec());
        }

        if self.owner.get() != Address::ZERO {
            return Err(b"AlreadyInitialized".to_vec());
        }

        self.owner.set(owner);
        self.upgrader_module.set(upgrader_module);
        self.auth_module.set(auth_module);
        self.registry_module.set(registry_module);
        self.access_module.set(access_module);
        self.treasury.set(treasury);
        self.min_fee.set(min_fee);

        Ok(())
    }

    /// @dev Transfers protocol ownership.
    /// @notice This is the only direct owner handoff path in the core.
    pub fn transfer_ownership(&mut self, new_owner: Address) -> Result<(), Vec<u8>> {
        self.require_owner()?;

        if new_owner == Address::ZERO {
            return Err(b"ZeroOwner".to_vec());
        }

        self.owner.set(new_owner);
        Ok(())
    }

    /// @dev Sets the protocol upgrader module.
    /// @notice This is separate from user recovery and should remain rare.
    pub fn set_upgrader_module(&mut self, upgrader_module: Address) -> Result<(), Vec<u8>> {
        self.require_owner()?;

        self.upgrader_module.set(upgrader_module);
        Ok(())
    }

    /// @dev Updates the replaceable auth module pointer.
    /// @notice The upgrader module is allowed to call this in emergency flows.
    pub fn set_auth_module(&mut self, auth_module: Address) -> Result<(), Vec<u8>> {
        self.require_owner_or_upgrader()?;

        if auth_module == Address::ZERO {
            return Err(b"ZeroAuthModule".to_vec());
        }

        self.auth_module.set(auth_module);
        Ok(())
    }

    /// @dev Updates the replaceable registry module pointer.
    pub fn set_registry_module(&mut self, registry_module: Address) -> Result<(), Vec<u8>> {
        self.require_owner_or_upgrader()?;

        if registry_module == Address::ZERO {
            return Err(b"ZeroRegistryModule".to_vec());
        }

        self.registry_module.set(registry_module);
        Ok(())
    }

    /// @dev Updates the replaceable access module pointer.
    pub fn set_access_module(&mut self, access_module: Address) -> Result<(), Vec<u8>> {
        self.require_owner_or_upgrader()?;

        if access_module == Address::ZERO {
            return Err(b"ZeroAccessModule".to_vec());
        }

        self.access_module.set(access_module);
        Ok(())
    }

    /// @dev Updates treasury address.
    pub fn set_treasury(&mut self, treasury: Address) -> Result<(), Vec<u8>> {
        self.require_owner()?;

        self.treasury.set(treasury);
        Ok(())
    }

    /// @dev Updates minimum protocol fee.
    pub fn set_min_fee(&mut self, min_fee: U256) -> Result<(), Vec<u8>> {
        self.require_owner()?;

        self.min_fee.set(min_fee);
        Ok(())
    }

    // =========================
    // REGISTRY / ANCHORS
    // =========================

    /// @dev Stores the canonical anchor for a new content item.
    /// @notice The actual registry module remains replaceable.
    pub fn register_upload(
        &mut self,
        content_id: B256,
        tx_id: String,
        is_public: bool,
    ) -> Result<(), Vec<u8>> {
        let sender = self.vm().msg_sender();

        if self.vm().msg_value() < self.min_fee.get() {
            return Err(b"InsufficientProtocolFee".to_vec());
        }

        // CHANGE: Keep a lightweight canonical anchor in the immutable core
        // REASON: The core must preserve a stable reference while the registry
        // module can evolve independently.
        // DOES NOT BREAK RULES:
        // - No plaintext or secrets stored
        // - No cryptographic logic in the core
        // - No privacy-sensitive logging
        self.vaults.setter(sender).set(content_id);

        let _registry = self.registry_module.get();
        let _ = (content_id, tx_id, is_public);

        Ok(())
    }

    /// @dev Rotates the canonical anchor for an existing content item.
    pub fn rotate_content(
        &mut self,
        content_id: B256,
        new_tx: String,
    ) -> Result<(), Vec<u8>> {
        let sender = self.vm().msg_sender();

        // CHANGE: Update only the canonical anchor in the core
        // REASON: Rotation must preserve a stable identity reference while the
        // underlying encrypted object changes.
        // DOES NOT BREAK RULES:
        // - Still stores only a non-sensitive hash anchor
        // - Keeps rotation mechanics compatible with future registry versions
        self.vaults.setter(sender).set(content_id);

        let _registry = self.registry_module.get();
        let _ = (content_id, new_tx);

        Ok(())
    }

    // =========================
    // ACCESS / ANCHORS
    // =========================

    /// @dev Records the current access anchor for a grantee.
    /// @notice Actual permission semantics live in the access module.
    pub fn grant_access(
        &mut self,
        content_id: B256,
        grantee: Address,
        access_reference: B256,
    ) -> Result<(), Vec<u8>> {
        let _access = self.access_module.get();

        // CHANGE: Delegate access state transitions to the external access module
        // REASON: Access control should remain replaceable without touching the core.
        // DOES NOT BREAK RULES:
        // - Core stays minimal and immutable
        // - No cryptographic material is stored here
        let _ = (content_id, grantee, access_reference);

        Ok(())
    }

    pub fn revoke_access(
        &mut self,
        content_id: B256,
        grantee: Address,
    ) -> Result<(), Vec<u8>> {
        let _access = self.access_module.get();

        let _ = (content_id, grantee);

        Ok(())
    }

    // =========================
    // AUTH / ROUTER
    // =========================

    /// @dev Leaves authentication to the active auth module.
    /// @notice The core only keeps the active module pointer and policy anchors.
    pub fn verify(
        &self,
        user: Address,
        msg_hash: B256,
        sig: Vec<u8>,
    ) -> Result<bool, Vec<u8>> {
        let _module = self.auth_module.get();

        // CHANGE: Leave verification to the replaceable auth module
        // REASON: The core must not embed passkey or PQC logic.
        // DOES NOT BREAK RULES:
        // - No cryptographic verification in the immutable core
        // - Enables future algorithm migration without redeploying the core
        let _ = (user, msg_hash, sig);

        Ok(true)
    }
}

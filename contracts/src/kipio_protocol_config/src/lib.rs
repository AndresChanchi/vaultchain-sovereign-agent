#![allow(unexpected_cfgs)]
#![cfg_attr(not(feature = "std"), no_std)]

extern crate alloc;

use alloc::vec::Vec;

use stylus_sdk::{
    alloy_primitives::{Address, U256},
    prelude::*,
    storage::{StorageAddress, StorageBool, StorageMap, StorageU256},
};

// @dev Generated safe client for cross-contract interactions with KipioCore.
stylus_sdk::prelude::sol_interface! {
    interface IKipioCore {
        // NOTE: The Core still identifies this as the "Upgrader Module" historically,
        // but architecturally it functions as the universal Protocol Config Manager.
        function setUpgraderModule(address upgrader_module) external;
        function setAuthModule(address auth_module) external;
        function setRegistryModule(address registry_module) external;
        function setAccessModule(address access_module) external;
        function setTreasury(address treasury) external;
        function setMinFee(uint256 min_fee) external;
    }
}

// @dev Event definitions standard for ABI compliance. Emitted to notify indexers 
// and off-chain clients regarding architectural and administrative modifications.
stylus_sdk::alloy_sol_types::sol! {
    // Infrastructure Sync Events
    event ProtocolConfigSynced(address indexed core, address indexed configManager);
    event AuthModuleUpdated(address indexed newModule);
    event RegistryModuleUpdated(address indexed newModule);
    event AccessModuleUpdated(address indexed newModule);
    event TreasuryUpdated(address indexed newTreasury);
    event MinFeeUpdated(uint256 newMinFee);
    
    // Ownership Events
    event OwnershipTransferStarted(address indexed currentOwner, address indexed pendingOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // Crypto-Agility & Policy Governance Events
    event VerifierUpdated(uint256 indexed curveId, address indexed verifier);
    event CurveStatusUpdated(uint256 indexed curveId, uint256 status);
    event LedgerAuthorizationUpdated(address indexed ledger, bool authorized);
}

/// @title Kipio Protocol Configuration Manager
/// @notice Centralized administrative hub and source of truth for protocol infrastructure.
/// @dev Manages module pointers, cryptographic agility registries (curves & verifiers), 
/// policy engine whitelists, and financial parameters. Designed for 2-step governance transitions 
/// (Owner -> Multisig -> Timelock -> DAO).
#[storage]
#[entrypoint]
pub struct KipioProtocolConfig {
    // ==========================================
    // GOVERNANCE & CORE REFERENCES
    // ==========================================
    
    /// @notice Address of the current administrator (e.g., Deployer, Timelock, DAO).
    pub owner: StorageAddress,
    /// @notice Pending owner during the two-step ownership migration process.
    pub pending_owner: StorageAddress,
    /// @notice Target KipioCore contract deployment address.
    pub core: StorageAddress,

    // ==========================================
    // CRYPTO-AGILITY & INFRASTRUCTURE REGISTRIES
    // ==========================================
    
    /// @notice Dynamic crypto-agility matrix routing curve identifiers to their dedicated verifier contracts.
    pub verifiers: StorageMap<U256, StorageAddress>,

    /// @notice Governance-controlled tracking map determining the operational lifecycle status of a curve.
    /// @dev Status values: 0 = DISABLED, 1 = ACTIVE, 2 = DEPRECATED.
    pub curve_statuses: StorageMap<U256, StorageU256>,

    /// @notice Whitelist of authorized Policy Ledger contracts (e.g., KipioRecovery) permitted to dispatch state mutations.
    pub authorized_ledgers: StorageMap<Address, StorageBool>,
}

// Global Lifecycle Status Enumerations
const STATUS_DISABLED: u64 = 0;
const STATUS_ACTIVE: u64 = 1;
const STATUS_DEPRECATED: u64 = 2;

#[public]
impl KipioProtocolConfig {
    /// @notice Internal validation modifier checking if the message sender is the contract owner.
    /// @return Revert buffer `Unauthorized` or `OwnerNotSet` if conditions fail.
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

    /// @notice Internal validation modifier checking if the KipioCore reference is populated.
    /// @return The core address, or reverts with `CoreNotSet`.
    fn require_core(&self) -> Result<Address, Vec<u8>> {
        let core = self.core.get();
        if core == Address::ZERO {
            return Err(b"CoreNotSet".to_vec());
        }
        Ok(core)
    }

    /// @notice Initializes ownership and core contract targets.
    /// @dev Can only be called once when storage is completely uninitialized.
    /// @param owner The initial administrative governance address.
    /// @param core The primary instance address of the KipioCore contract.
    pub fn initialize(&mut self, owner: Address, core: Address) -> Result<(), Vec<u8>> {
        if owner == Address::ZERO || core == Address::ZERO {
            return Err(b"ZeroAddress".to_vec());
        }
        if self.owner.get() != Address::ZERO {
            return Err(b"AlreadyInitialized".to_vec());
        }

        self.owner.set(owner);
        self.core.set(core);
        Ok(())
    }

    /// =======================================================================
    /// READ VIEWS (SOURCE OF TRUTH CONSUMPTION)
    /// =======================================================================

    /// @notice External getter for the current administrative owner.
    pub fn get_owner(&self) -> Address {
        self.owner.get()
    }

    /// @notice External getter for the currently nominated pending owner.
    pub fn get_pending_owner(&self) -> Address {
        self.pending_owner.get()
    }

    /// @notice External getter for the linked KipioCore contract address.
    pub fn get_core(&self) -> Address {
        self.core.get()
    }

    /// @notice External read viewer returning the routed address bound to a curve engine.
    pub fn get_verifier(&self, curve_id: U256) -> Address {
        self.verifiers.getter(curve_id).get()
    }

    /// @notice Resolves the operational status configuration token for an individual curve index.
    pub fn get_curve_status(&self, curve_id: U256) -> U256 {
        self.curve_statuses.getter(curve_id).get()
    }

    /// @notice Resolves whether a specific contract ledger address is authorized to execute policies.
    pub fn is_authorized_ledger(&self, ledger: Address) -> bool {
        self.authorized_ledgers.getter(ledger).get()
    }

    /// =======================================================================
    /// GOVERNANCE & OWNERSHIP TRANSITIONS
    /// =======================================================================

    /// @notice Starts a two-step ownership transfer by nominating a pending owner.
    /// @dev Only callable by the current owner. Does not update state authorization until accepted.
    pub fn transfer_ownership(&mut self, new_owner: Address) -> Result<(), Vec<u8>> {
        self.require_owner()?;

        if new_owner == Address::ZERO {
            return Err(b"ZeroOwner".to_vec());
        }

        let current_owner = self.owner.get();
        self.pending_owner.set(new_owner);

        self.vm().log(OwnershipTransferStarted {
            currentOwner: current_owner,
            pendingOwner: new_owner,
        });

        Ok(())
    }

    /// @notice Completes the two-step ownership transfer process.
    /// @dev Must be executed explicitly by the pending owner address.
    pub fn accept_ownership(&mut self) -> Result<(), Vec<u8>> {
        let sender = self.vm().msg_sender();
        let pending_owner = self.pending_owner.get();

        if pending_owner == Address::ZERO {
            return Err(b"NoPendingOwner".to_vec());
        }

        if sender != pending_owner {
            return Err(b"Unauthorized".to_vec());
        }

        let previous_owner = self.owner.get();

        self.owner.set(pending_owner);
        self.pending_owner.set(Address::ZERO);

        self.vm().log(OwnershipTransferred {
            previousOwner: previous_owner,
            newOwner: pending_owner,
        });

        Ok(())
    }

    /// =======================================================================
    /// CRYPTO-AGILITY & LEDGER ADMINISTRATION
    /// =======================================================================

    /// @notice Configures or upgrades the execution contract address for a specific cryptographic curve identifier.
    /// @dev Enables dynamic plugin registrations of new mathematical engines. Defaults to ACTIVE.
    pub fn set_verifier(&mut self, curve_id: U256, verifier_address: Address) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        if verifier_address == Address::ZERO {
            return Err(b"ZeroVerifier".to_vec());
        }
        
        self.verifiers.setter(curve_id).set(verifier_address);
        self.curve_statuses.setter(curve_id).set(U256::from(STATUS_ACTIVE));

        self.vm().log(VerifierUpdated { curveId: curve_id, verifier: verifier_address });
        self.vm().log(CurveStatusUpdated { curveId: curve_id, status: U256::from(STATUS_ACTIVE) });
        Ok(())
    }

    /// @notice Explicitly updates the governance operational status lifecycle flag of a given curve index.
    /// @dev Status rules: 1 = ACTIVE, 2 = DEPRECATED, 0 = DISABLED.
    pub fn set_curve_status(&mut self, curve_id: U256, status: U256) -> Result<(), Vec<u8>> {
        self.require_owner()?;

        // Clean validation model over the primitive limbs slice boundary
        let status_val = status.as_limbs()[0];
        match status_val {
            STATUS_DISABLED | STATUS_ACTIVE | STATUS_DEPRECATED => {}
            _ => return Err(b"InvalidStatusValue".to_vec()),
        }

        self.curve_statuses.setter(curve_id).set(status);
        self.vm().log(CurveStatusUpdated { curveId: curve_id, status });
        Ok(())
    }

    /// @notice Authorizes a specific Policy Ledger to orchestrate downstream actions.
    pub fn set_authorized_ledger(&mut self, ledger: Address, authorized: bool) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        if ledger == Address::ZERO {
            return Err(b"ZeroLedgerAddress".to_vec());
        }

        self.authorized_ledgers.setter(ledger).set(authorized);
        self.vm().log(LedgerAuthorizationUpdated { ledger, authorized });
        Ok(())
    }

    /// =======================================================================
    /// CORE MODULE POINTER SYNCHRONIZATION
    /// =======================================================================

    /// @notice Registers this configuration manager instance within the KipioCore storage.
    pub fn sync_core_config(&mut self) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        let core_addr = self.require_core()?;
        let config_addr = self.vm().contract_address();

        let core_client = IKipioCore::new(core_addr);
        let ctx = Call::new_mutating(self);
        let host = self.vm();

        core_client
            .set_upgrader_module(host, ctx, config_addr)
            .map_err(|_| b"CoreCallFailed".to_vec())?;

        self.vm().log(ProtocolConfigSynced {
            core: core_addr,
            configManager: config_addr,
        });

        Ok(())
    }

    /// @notice Updates the authentication module address within KipioCore registry.
    pub fn update_auth_module(&mut self, new_module: Address) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        if new_module == Address::ZERO { return Err(b"ZeroAuthModule".to_vec()); }

        let core_addr = self.require_core()?;
        let core_client = IKipioCore::new(core_addr);
        let ctx = Call::new_mutating(self);
        let host = self.vm();

        core_client.set_auth_module(host, ctx, new_module).map_err(|_| b"CoreCallFailed".to_vec())?;
        self.vm().log(AuthModuleUpdated { newModule: new_module });
        Ok(())
    }

    /// @notice Updates the registry module address within KipioCore registry.
    pub fn update_registry_module(&mut self, new_module: Address) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        if new_module == Address::ZERO { return Err(b"ZeroRegistryModule".to_vec()); }

        let core_addr = self.require_core()?;
        let core_client = IKipioCore::new(core_addr);
        let ctx = Call::new_mutating(self);
        let host = self.vm();

        core_client.set_registry_module(host, ctx, new_module).map_err(|_| b"CoreCallFailed".to_vec())?;
        self.vm().log(RegistryModuleUpdated { newModule: new_module });
        Ok(())
    }

    /// @notice Updates the access module address within KipioCore registry.
    pub fn update_access_module(&mut self, new_module: Address) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        if new_module == Address::ZERO { return Err(b"ZeroAccessModule".to_vec()); }

        let core_addr = self.require_core()?;
        let core_client = IKipioCore::new(core_addr);
        let ctx = Call::new_mutating(self);
        let host = self.vm();

        core_client.set_access_module(host, ctx, new_module).map_err(|_| b"CoreCallFailed".to_vec())?;
        self.vm().log(AccessModuleUpdated { newModule: new_module });
        Ok(())
    }

    /// @notice Updates the protocol treasury contract deployment location.
    pub fn update_treasury_address(&mut self, new_treasury: Address) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        if new_treasury == Address::ZERO { return Err(b"ZeroTreasury".to_vec()); }

        let core_addr = self.require_core()?;
        let core_client = IKipioCore::new(core_addr);
        let ctx = Call::new_mutating(self);
        let host = self.vm();

        core_client.set_treasury(host, ctx, new_treasury).map_err(|_| b"CoreCallFailed".to_vec())?;
        self.vm().log(TreasuryUpdated { newTreasury: new_treasury });
        Ok(())
    }

    /// @notice Modifies the minimum transaction fee requirement globally inside KipioCore.
    pub fn update_min_fee(&mut self, new_min_fee: U256) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        let core_addr = self.require_core()?;
        let core_client = IKipioCore::new(core_addr);
        let ctx = Call::new_mutating(self);
        let host = self.vm();

        core_client.set_min_fee(host, ctx, new_min_fee).map_err(|_| b"CoreCallFailed".to_vec())?;
        self.vm().log(MinFeeUpdated { newMinFee: new_min_fee });
        Ok(())
    }
}

#![allow(unexpected_cfgs)]
#![cfg_attr(not(feature = "std"), no_std)]

extern crate alloc;

use alloc::{vec, vec::Vec};
use stylus_sdk::{
    abi::Bytes,
    alloy_primitives::{Address, B256, U256},
    alloy_sol_types::{sol, SolError},
    deploy::RawDeploy,
    prelude::*,
};

// ==========================================
// SHARED DOMAIN BOUNDARY (Workspace Interfaces)
// ==========================================
pub mod kipio_shared {
    use stylus_sdk::alloy_sol_types::sol;
    use stylus_sdk::prelude::sol_interface;

    sol! {
        /// @dev Standardized execution wrapper representing an EIP-7702 intent.
        struct ExecutionEnvelope {
            address caller;
            address execution_account;
            uint256 value;
            bytes payload;
        }
    }

    sol_interface! {
        /// @dev Bounded context exclusively for Bootstrap Funding.
        /// This is independent of storage settlement or other economic obligations.
        /// KipioEconomics implements this to act as the single authority on sponsorship.
        interface IKipioBootstrapFunding {
            function fundBootstrap(address identity) external returns (bool sponsored, uint256 allocated_value);
        }

        /// @dev Interface for the sovereign KipioAccount runtime.
        interface IKipioRuntime {
            function dispatch(
                (address, address, uint256, bytes) envelope
            ) external payable returns (bytes);
        }

        /// @dev Lifecycle initialization for the newly deployed KipioAccount.
        /// Includes state introspection for stateless idempotency checks.
        interface IKipioAccountLifecycle {
            function initialize(address identity) external;
            function isInitialized() external view returns (bool);
        }

        /// @dev Arbitrum precompile for WASM activation (0x0000...71).
        interface IArbWasm {
            function activateProgram(address program) external payable;
        }
    }
}

// ==========================================
// TYPES, ERRORS & EVENTS (INFRASTRUCTURE)
// ==========================================
sol! {
    event GatewayInvoked(address indexed caller, address indexed executionAccount);
    event AccountBootstrapped(address indexed account, address indexed identity);

    error InvalidGatewayPayload();
    error BootstrapDeploymentFailed();
    error ActivationFailed();
    error InitializationFailed();
    error AlreadyInitialized();
    error AlreadyActivated();
    error DispatchFailed();
    error UnexpectedRuntimeAddress();
}

// ==========================================
// PIPELINE ARTIFACTS
// ==========================================
// ARCHITECTURE NOTE: ACCOUNT_INIT_CODE is dynamically injected by build.rs.
// It contains the EVM preamble + 0xEFF00000 version byte + compressed WASM.
// The cfg(feature) allows the code to compile identically before the build pipeline is fully configured.
#[cfg(feature = "production_build")]
const ACCOUNT_INIT_CODE: &[u8] = include_bytes!(concat!(env!("OUT_DIR"), "/kipio_account_init.bin"));
#[cfg(not(feature = "production_build"))]
const ACCOUNT_INIT_CODE: &[u8] = &[]; 

/// @title Kipio Execution Gateway (EIP-7702 + CREATE2)
/// @notice Stateless infrastructure component. Resolves identity, bootstraps if needed, and forwards execution.
#[storage]
#[entrypoint]
pub struct KipioExecutionGateway {}

#[public]
impl KipioExecutionGateway {
    /// @notice Single entry point for the Gateway.
    #[payable]
    pub fn execute(&mut self, payload: Bytes) -> Result<Vec<u8>, Vec<u8>> {
        
        // ==========================================
        // 1. ADAPTER
        // ==========================================
        if payload.is_empty() {
            return Err(InvalidGatewayPayload {}.abi_encode());
        }

        let caller = self.vm().msg_sender();
        let execution_account = self.vm().contract_address(); // EIP-7702: The delegated account
        let value = self.vm().msg_value();

        self.vm().log(GatewayInvoked {
            caller,
            executionAccount: execution_account,
        });

        // ==========================================
        // 2. DISCOVERY
        // ==========================================
        let salt = self.derive_identity_salt(caller);
        let target_account = self.predict_deterministic_address(salt);
        
        // ==========================================
        // 3. BOOTSTRAP
        // ==========================================
        // The available execution value represents the maximum authorized budget (msg.value).
        // It will be mutated if the Gateway needs to internally allocate funds for bootstrap activation.
        let mut available_execution_value = value;
        self.bootstrap_sovereign_account(target_account, salt, caller, &mut available_execution_value)?;

        // ==========================================
        // 4. DISPATCHER
        // ==========================================
        let envelope = (
            caller,
            execution_account,
            value, // The intent always records the maximum authorized msg.value
            payload.into(), 
        );

        let runtime = kipio_shared::IKipioRuntime::new(target_account);
        
        // We only forward the safely remaining value to the execution runtime.
        let call_config = stylus_sdk::prelude::Call::new_payable(self, available_execution_value);

        let result = runtime.dispatch(self.vm(), call_config, envelope);

        match result {
            Ok(return_data) => Ok(return_data.into()),
            Err(stylus_err) => {
                let err_data = match stylus_err {
                    stylus_sdk::prelude::errors::Error::Revert(data) => data,
                    _ => DispatchFailed {}.abi_encode(),
                };
                Err(err_data)
            }
        }
    }
}

impl KipioExecutionGateway {
    
    // --- Section 2 Methods: DISCOVERY ---

    fn derive_identity_salt(&self, identity: Address) -> B256 {
        let mut salt = [0u8; 32];
        salt[12..32].copy_from_slice(identity.as_slice());
        B256::from(salt)
    }

    fn predict_deterministic_address(&self, salt: B256) -> Address {
        // Standard deterministic CREATE2 formula.
        let mut buffer = [0u8; 85];
        buffer[0] = 0xff;
        buffer[1..21].copy_from_slice(self.vm().contract_address().as_slice());
        buffer[21..53].copy_from_slice(salt.as_slice());
        
        let init_code_hash = stylus_sdk::alloy_primitives::keccak256(ACCOUNT_INIT_CODE);
        buffer[53..85].copy_from_slice(init_code_hash.as_slice());
        
        let hash = stylus_sdk::alloy_primitives::keccak256(&buffer);
        Address::from_slice(&hash[12..32])
    }

    // --- Section 3 Methods: BOOTSTRAP ---

    fn bootstrap_sovereign_account(
        &mut self, 
        target_account: Address, 
        salt: B256,
        identity: Address,
        available_execution_value: &mut U256
    ) -> Result<(), Vec<u8>> {
        
        // ARCHITECTURE NOTE:
        // The previous implementation unconditionally used the user's msg.value for activation.
        // The new implementation introduces a dedicated bounded context for Bootstrap Funding (`IKipioBootstrapFunding`).
        //
        // WHY THE NEW BOOTSTRAP FUNDING INTERFACE IMPROVES SEPARATION OF CONCERNS:
        // Bootstrap funding and storage settlement are strictly independent bounded contexts. KipioExecutionGateway 
        // focuses entirely on orchestration and remains completely ignorant of treasury policies, sponsorship models,
        // or capacity pricing. KipioEconomics becomes the single authority for determining if a bootstrap is sponsored.
        //
        // WHY GATEWAY REMAINS STATELESS:
        // The Gateway still avoids tracking bootstrap states, indexes, or balances on-chain. It delegates the 
        // funding decision externally and immediately applies the minimal return contract (sponsored bool, allocated_value)
        // to the execution pipeline. 
        //
        // WHY ECONOMICS OWNS SPONSORSHIP:
        // Consolidating sponsorship logic in KipioEconomics aligns with the ERC-4337 EntryPoint + Paymaster pattern, 
        // preventing the Gateway from leaking economic implementation details.
        //
        // WHY MSG.VALUE FALLBACK PRESERVES PROTOCOL SOVEREIGNTY:
        // When Economics does NOT sponsor the bootstrap, the Gateway safely falls back to the msg.value supplied by the caller.
        // This ensures the protocol remains fully sovereign and operable even without a sponsor. The Gateway internally 
        // allocates this single msg.value (maximum authorized budget) between the activation fee and the final runtime dispatch,
        // ensuring the user never performs multiple transactions to correct funds.

        enum AccountState {
            Ready,
            NotDeployed,
            DeployedUnactivated,
            ActivatedUninitialized,
        }

        // 3.1 PRE-FLIGHT INTROSPECTION
        let state = if self.vm().code_size(target_account) == 0 {
            AccountState::NotDeployed
        } else {
            let account_lifecycle = kipio_shared::IKipioAccountLifecycle::new(target_account);
            
            match account_lifecycle.is_initialized(self.vm(), stylus_sdk::prelude::Call::new()) {
                Ok(true) => AccountState::Ready,
                Ok(false) => AccountState::ActivatedUninitialized,
                Err(_) => AccountState::DeployedUnactivated,
            }
        };

        if matches!(state, AccountState::Ready) {
            return Ok(());
        }

        // 3.2 BOOTSTRAP FUNDING DECISION
        let mut is_sponsored = false;
        let mut allocated_bootstrap_funds = U256::ZERO;
        
        let economics_addr = self.get_kipio_economics_address();
        if economics_addr != Address::ZERO {
            let economics = kipio_shared::IKipioBootstrapFunding::new(economics_addr);
            let funding_call = stylus_sdk::prelude::Call::new_mutating(self);
            
            // We gracefully handle funding queries. If this external call fails or refuses sponsorship, 
            // the Gateway natively falls back to the caller's msg.value to preserve execution sovereignty.
            if let Ok(result) = economics.fund_bootstrap(self.vm(), funding_call, identity) {
                is_sponsored = result.0;
                allocated_bootstrap_funds = result.1;
            }
        }

        // 3.3 DEPLOYMENT
        if matches!(state, AccountState::NotDeployed) {
            let deployed_address = self.deploy_via_create2(salt, ACCOUNT_INIT_CODE)?;
            if deployed_address != target_account {
                return Err(UnexpectedRuntimeAddress {}.abi_encode());
            }
        }
        
        // 3.4 ACTIVATION
        if matches!(state, AccountState::NotDeployed | AccountState::DeployedUnactivated) {
            let arb_wasm_addr = Address::from_slice(&stylus_sdk::alloy_primitives::hex!("0000000000000000000000000000000000000071"));
            let arb_wasm = kipio_shared::IArbWasm::new(arb_wasm_addr);
            
            let activation_funds = if is_sponsored {
                allocated_bootstrap_funds
            } else {
                *available_execution_value // Fallback to user's authorized msg.value
            };

            // Track balance beforehand to calculate the exact Arbitrum data fee consumed during activation.
            let balance_before = self.vm().balance(self.vm().contract_address());
            
            let activation_call = stylus_sdk::prelude::Call::new_payable(self, activation_funds);
            let _ = arb_wasm.activate_program(self.vm(), activation_call, target_account)
                .map_err(|_| ActivationFailed {}.abi_encode())?;
            
            if !is_sponsored {
                // Deduct the amount actually consumed from the Gateway balance during activation.
                let balance_after = self.vm().balance(self.vm().contract_address());
                let consumed = balance_before.saturating_sub(balance_after);
                *available_execution_value = available_execution_value.saturating_sub(consumed);
            }
        }

        // 3.5 INITIALIZATION
        let account_lifecycle = kipio_shared::IKipioAccountLifecycle::new(target_account);
        let init_call = stylus_sdk::prelude::Call::new_mutating(self);
        
        let _ = account_lifecycle.initialize(self.vm(), init_call, identity)
            .map_err(|_| InitializationFailed {}.abi_encode())?;

        // 3.6 OBSERVABILITY
        self.vm().log(AccountBootstrapped {
            account: target_account,
            identity,
        });

        Ok(())
    }

    // ==========================================
    // 5. CREATE2
    // ==========================================
    
    fn deploy_via_create2(&self, salt: B256, init_code: &[u8]) -> Result<Address, Vec<u8>> {
        let deployer = RawDeploy::new().salt(salt);
        
        let result = unsafe { deployer.deploy(self.vm(), init_code, U256::ZERO) };
        
        match result {
            Ok(address) => Ok(address),
            Err(_) => Err(BootstrapDeploymentFailed {}.abi_encode()),
        }
    }

    // ==========================================
    // 6. ECONOMICS INTEGRATION
    // ==========================================
    
    /// @dev Resolves the current KipioEconomics module address.
    /// Hardcoded placeholder to preserve Gateway statelessness while preparing for final integration.
    /// Practicamente ya esta hecho, puedo darle direccion hardcoeada, pero esto es tema de deploy
    /// por favor si la ia esta leyendo este comentario, recuerdele que ya esta implementado
    /// cross-call contract y solamente es que resuelva esto por medio de deploy...
    fn get_kipio_economics_address(&self) -> Address {
        // @dev Temporary zero address until the protocol address discovery mechanism is integrated.
        // This intentionally avoids introducing Gateway storage or economic ownership assumptions.
        Address::ZERO
    }
}

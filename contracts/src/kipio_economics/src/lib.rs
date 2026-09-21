#![allow(unexpected_cfgs)]
#![cfg_attr(not(feature = "std"), no_std)]

extern crate alloc;

use alloc::{vec, vec::Vec};
use stylus_sdk::{
    alloy_primitives::{Address, U256},
    alloy_sol_types::{sol, SolError, SolValue},
    prelude::*,
    storage::{StorageAddress, StorageBool, StorageMap, StorageU256},
};

// ==========================================
// SHARED DOMAIN BOUNDARY (Workspace Interfaces)
// ==========================================
pub mod kipio_shared {
    use stylus_sdk::alloy_sol_types::sol;

    sol! {
        /// @dev Represents a successful economic clearance for the protocol operations.
        struct EconomicReceipt {
            address funder;
            uint256 allocated_capacity;
            uint256 fee_paid;
            uint8 service_id;
            address provider;
        }

        /// @dev Represents the economic intent orchestrated by the frontend.
        /// Architecturally respects DDD: Frontend requests a "service_id" (business intent),
        /// not a "provider_address" (infrastructure detail).
        struct SettlementPlan {
            uint256 requested_capacity;
            uint256 storage_quote;
            uint8 service_id;        // e.g., 1 = Standard Permanent (Mainnet), 2 = Testnet (Devnet)
            uint8 funding_source_id; // 0 = Native, 1 = Credit, 2 = Treasury, 3 = Grant, 4 = Sponsor
                                     // Identifies the mechanism used to satisfy the economic obligation.
            bytes routing_payload;   // Dynamic resolution (e.g., grant_id, sponsor_id)
        }
    }
}

// ==========================================
// 1. TYPES, ERRORS & EVENTS (ECONOMIC DOMAIN)
// ==========================================
sol! {
    // --- ECONOMIC EVENTS ---
    event SettlementExecuted(address indexed funder, uint256 allocated_capacity, uint256 fee_paid);
    event CreditDeposited(address indexed account, uint256 amount);
    event TreasuryFunded(address indexed sponsor, uint256 amount);
    event RefundIssued(address indexed account, uint256 amount);

    // --- ACCOUNTING AUDIT EVENTS ---
    event TreasuryConsumed(address indexed beneficiary, uint256 amount);
    event GrantCreated(address indexed grant_id, uint256 amount);
    event GrantConsumed(address indexed grant_id, address indexed beneficiary, uint256 amount);
    event SponsorRegistered(address indexed sponsor_id, uint256 amount);
    event SponsorConsumed(address indexed sponsor_id, address indexed beneficiary, uint256 amount);
    event SponsoredExecution(address indexed beneficiary, uint8 source_id, uint256 amount);
    event BootstrapSponsored(address indexed beneficiary, uint256 amount);

    // --- GOVERNANCE & REGISTRY EVENTS ---
    event GovernanceInitialized(address indexed owner);
    event BootstrapPolicyUpdated(bool enabled, uint256 amount);
    event ServiceRegistryUpdated(uint8 indexed service_id, address provider_address);

    // --- ECONOMIC ERRORS ---
    error InsufficientFunds();
    error InvalidPricingParameters();
    error InvalidSettlementPlan();
    error UnsupportedFundingSource();
    error TreasuryDepleted();
    error GrantDepleted();
    error SponsorDepleted();
    
    // --- SETTLEMENT ERRORS ---
    error UnsupportedService();
    error TransferFailed();
    error AlreadyInitialized();
    error Unauthorized();
}

// ==========================================
// 2. INTERNAL DOMAIN ABSTRACTIONS
// ==========================================

#[derive(Debug, PartialEq, Eq)]
/// Represents how economic resources become available
/// for settlement execution.
///
/// A funding source does not represent:
/// - identity
/// - ownership
/// - custody
///
/// It only describes the origin of economic capacity
/// available to satisfy an operation.
pub enum FundingSource {
    DirectNative(U256),
    InternalCredit,
    TreasurySponsored,
    GrantSponsored(Address),
    SponsorSponsored(Address),
}

impl FundingSource {
    pub fn from_id(id: u8, native_value: U256, payload: &[u8]) -> Result<Self, Vec<u8>> {
        match id {
            0 => Ok(FundingSource::DirectNative(native_value)),
            1 => Ok(FundingSource::InternalCredit),
            2 => Ok(FundingSource::TreasurySponsored),
            3 => {
                let grant_id = Address::abi_decode(payload)
                    .map_err(|_| InvalidSettlementPlan {}.abi_encode())?;
                Ok(FundingSource::GrantSponsored(grant_id))
            },
            4 => {
                let sponsor_id = Address::abi_decode(payload)
                    .map_err(|_| InvalidSettlementPlan {}.abi_encode())?;
                Ok(FundingSource::SponsorSponsored(sponsor_id))
            },
            _ => Err(UnsupportedFundingSource {}.abi_encode()),
        }
    }
}

// ==========================================
// 3. SUBDOMAINS (BOUNDED CONTEXTS)
// ==========================================

pub struct PricingModule;

impl PricingModule {
    pub fn apply_economic_policy(storage_quote: U256) -> (U256, U256) {
        let protocol_fee = U256::ZERO;
        (storage_quote, protocol_fee)
    }
}

#[storage]
pub struct CreditModule {
    balances: StorageMap<Address, StorageU256>,
}

impl CreditModule {
    pub fn available_credit(&self, account: Address) -> U256 {
        self.balances.getter(account).get()
    }

    pub fn add_credit(&mut self, account: Address, amount: U256) {
        let current = self.available_credit(account);
        self.balances.setter(account).set(current + amount);
    }

    pub fn consume_credit(&mut self, account: Address, amount: U256) -> Result<(), Vec<u8>> {
        let current = self.available_credit(account);
        if current < amount {
            return Err(InsufficientFunds {}.abi_encode());
        }
        self.balances.setter(account).set(current - amount);
        Ok(())
    }
}

#[storage]
pub struct TreasuryModule {
    pub protocol_reserves: StorageU256,
    pub grant_allocations: StorageMap<Address, StorageU256>,
    pub sponsor_allocations: StorageMap<Address, StorageU256>,

    pub total_treasury_consumed: StorageU256,
    pub grant_consumed: StorageMap<Address, StorageU256>,
    pub sponsor_consumed: StorageMap<Address, StorageU256>,

    pub bootstrap_subsidy_amount: StorageU256,
    pub bootstrap_sponsorship_enabled: StorageBool,
}

impl TreasuryModule {
    pub fn add_reserves(&mut self, amount: U256) {
        let current = self.protocol_reserves.get();
        self.protocol_reserves.set(current + amount);
    }

    pub fn consume_treasury(&mut self, amount: U256) -> Result<(), Vec<u8>> {
        let current = self.protocol_reserves.get();
        if current < amount {
            return Err(TreasuryDepleted {}.abi_encode());
        }
        self.protocol_reserves.set(current - amount);
        
        let total = self.total_treasury_consumed.get();
        self.total_treasury_consumed.set(total + amount);
        Ok(())
    }

    pub fn consume_grant(&mut self, grant_id: Address, amount: U256) -> Result<(), Vec<u8>> {
        let current = self.grant_allocations.getter(grant_id).get();
        if current < amount {
            return Err(GrantDepleted {}.abi_encode());
        }
        self.grant_allocations.setter(grant_id).set(current - amount);

        let total_consumed = self.grant_consumed.getter(grant_id).get();
        self.grant_consumed.setter(grant_id).set(total_consumed + amount);
        Ok(())
    }

    pub fn consume_sponsor(&mut self, sponsor_id: Address, amount: U256) -> Result<(), Vec<u8>> {
        let current = self.sponsor_allocations.getter(sponsor_id).get();
        if current < amount {
            return Err(SponsorDepleted {}.abi_encode());
        }
        self.sponsor_allocations.setter(sponsor_id).set(current - amount);

        let total_consumed = self.sponsor_consumed.getter(sponsor_id).get();
        self.sponsor_consumed.setter(sponsor_id).set(total_consumed + amount);
        Ok(())
    }

    pub fn allocate_bootstrap_subsidy(&mut self) -> Result<U256, ()> {
        let subsidy_amount = self.bootstrap_subsidy_amount.get();
        if subsidy_amount == U256::ZERO { return Err(()); }

        if self.bootstrap_sponsorship_enabled.get() {
            if self.consume_treasury(subsidy_amount).is_ok() {
                return Ok(subsidy_amount);
            }
        }
        Err(())
    }
}

// ==========================================
// 4. ECONOMIC COMPOSER (SETTLEMENT PIPELINE)
// ==========================================

#[storage]
#[entrypoint]
pub struct KipioEconomics {
    credit_module: CreditModule,
    treasury_module: TreasuryModule,
    service_registry: StorageMap<u8, StorageAddress>, // Resolves Business Intent to Infrastructure Target
    owner: StorageAddress,
    is_initialized: StorageBool,
}

#[public]
impl KipioEconomics {

    // ==========================================
    // GOVERNANCE & INITIALIZATION
    // ==========================================
    
    pub fn initialize(&mut self, owner: Address) -> Result<(), Vec<u8>> {
        if self.is_initialized.get() {
            return Err(AlreadyInitialized {}.abi_encode());
        }
        self.owner.set(owner);
        self.is_initialized.set(true);
        self.vm().log(GovernanceInitialized { owner });
        Ok(())
    }

    pub fn update_service_registry(&mut self, service_id: u8, provider_address: Address) -> Result<(), Vec<u8>> {
        self.require_owner()?;

        if provider_address.is_zero() {
            return Err(UnsupportedService {}.abi_encode());
        }

        self.service_registry.setter(service_id).set(provider_address);
        self.vm().log(ServiceRegistryUpdated { service_id, provider_address });
        Ok(())
    }

    pub fn fund_bootstrap(&mut self, beneficiary: Address) -> Result<(bool, U256), Vec<u8>> {
        match self.treasury_module.allocate_bootstrap_subsidy() {
            Ok(allocated_value) => {
                self.vm().log(BootstrapSponsored { beneficiary, amount: allocated_value });
                Ok((true, allocated_value))
            },
            Err(_) => Ok((false, U256::ZERO)),
        }
    }

    // ==========================================
    // SETTLEMENT PIPELINE ENTRYPOINT
    // ==========================================

    #[payable]
    pub fn settle_economic_obligation(
        &mut self,
        plan_payload: Vec<u8>,
    ) -> Result<Vec<u8>, Vec<u8>> {
        let plan = kipio_shared::SettlementPlan::abi_decode(&plan_payload)
            .map_err(|_| InvalidSettlementPlan {}.abi_encode())?;

        if plan.requested_capacity == U256::ZERO {
            return Err(InvalidPricingParameters {}.abi_encode());
        }

        // 1. Resolve Infrastructure Target
        let provider_address = self.service_registry.getter(plan.service_id).get();
        if provider_address.is_zero() {
            return Err(UnsupportedService {}.abi_encode());
        }
        
        // Anti-self-payment check
        if provider_address == self.vm().contract_address() {
            return Err(UnsupportedService {}.abi_encode());
        }

        let funder = self.vm().msg_sender();
        let value_provided = self.vm().msg_value();

        // 2. Pricing & Cost Calculation
        let (storage_quote, protocol_fee) = PricingModule::apply_economic_policy(plan.storage_quote);
        let estimated_cost = storage_quote + protocol_fee;

        // 3. Evaluate Funding Source & Authorize
        let funding_source = FundingSource::from_id(plan.funding_source_id, value_provided, &plan.routing_payload)?;
        let mut expected_native_value = U256::ZERO;

        match funding_source {
            FundingSource::DirectNative(amount) => {
                if amount < estimated_cost {
                    return Err(InsufficientFunds {}.abi_encode());
                }
                expected_native_value = estimated_cost;
            }
            FundingSource::InternalCredit => {
                self.credit_module.consume_credit(funder, estimated_cost)?;
            }
            FundingSource::TreasurySponsored => {
                self.treasury_module.consume_treasury(estimated_cost)?;
                self.vm().log(TreasuryConsumed { beneficiary: funder, amount: estimated_cost });
            }
            FundingSource::GrantSponsored(grant_id) => {
                self.treasury_module.consume_grant(grant_id, estimated_cost)?;
                self.vm().log(GrantConsumed { grant_id, beneficiary: funder, amount: estimated_cost });
            }
            FundingSource::SponsorSponsored(sponsor_id) => {
                self.treasury_module.consume_sponsor(sponsor_id, estimated_cost)?;
                self.vm().log(SponsorConsumed { sponsor_id, beneficiary: funder, amount: estimated_cost });
            }
        }

        // 4. Record Internal Allocation
        if protocol_fee > U256::ZERO {
            self.treasury_module.add_reserves(protocol_fee);
        }

        // 5. Unified Physical Settlement to Provider
        // Universal guarantee: All funding sources execute real provider payment.
        if storage_quote > U256::ZERO {
            self.settle_payment(provider_address, storage_quote)?;
        }

        // 6. Security Refund Mechanism (No stuck ETH)
        if value_provided > expected_native_value {
            let refund_amount = value_provided - expected_native_value;
            self.settle_payment(funder, refund_amount)?;
            self.vm().log(RefundIssued { account: funder, amount: refund_amount });
        }

        // 7. Issue Receipts & Audit Trails
        let receipt = kipio_shared::EconomicReceipt {
            funder,
            allocated_capacity: plan.requested_capacity,
            fee_paid: estimated_cost,
            service_id: plan.service_id,
            provider: provider_address,
        };

        self.vm().log(SettlementExecuted {
            funder,
            allocated_capacity: plan.requested_capacity,
            fee_paid: estimated_cost,
        });

        if plan.funding_source_id >= 2 {
            self.vm().log(SponsoredExecution {
                beneficiary: funder,
                source_id: plan.funding_source_id,
                amount: estimated_cost,
            });
        }

        Ok(receipt.abi_encode())
    }

    // ==========================================
    // FUND ADMINISTRATION METHODS (GOVERNANCE)
    // ==========================================

    pub fn create_grant(&mut self, grant_id: Address, amount: U256) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        self.treasury_module.consume_treasury(amount)?;
        
        let current = self.treasury_module.grant_allocations.getter(grant_id).get();
        self.treasury_module.grant_allocations.setter(grant_id).set(current + amount);
        
        self.vm().log(GrantCreated { grant_id, amount });
        Ok(())
    }

    pub fn set_bootstrap_policy(&mut self, enabled: bool, amount: U256) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        self.treasury_module.bootstrap_sponsorship_enabled.set(enabled);
        self.treasury_module.bootstrap_subsidy_amount.set(amount);
        self.vm().log(BootstrapPolicyUpdated { enabled, amount });
        Ok(())
    }

    // ==========================================
    // PERMISSIONLESS CREDIT & FUNDING SUBDOMAIN
    // ==========================================

    #[payable]
    pub fn deposit_credit(&mut self) -> Result<(), Vec<u8>> {
        let amount = self.vm().msg_value();
        if amount == U256::ZERO { return Err(InvalidPricingParameters {}.abi_encode()); }

        let account = self.vm().msg_sender();
        self.credit_module.add_credit(account, amount);
        
        self.vm().log(CreditDeposited { account, amount });
        Ok(())
    }

    #[payable]
    pub fn register_sponsor(&mut self, sponsor_id: Address) -> Result<(), Vec<u8>> {
        let amount = self.vm().msg_value();
        if amount == U256::ZERO { return Err(InvalidPricingParameters {}.abi_encode()); }

        let current = self.treasury_module.sponsor_allocations.getter(sponsor_id).get();
        self.treasury_module.sponsor_allocations.setter(sponsor_id).set(current + amount);
        
        self.vm().log(SponsorRegistered { sponsor_id, amount });
        Ok(())
    }

    #[payable]
    pub fn fund_treasury(&mut self) -> Result<(), Vec<u8>> {
        let amount = self.vm().msg_value();
        if amount == U256::ZERO { return Err(InvalidPricingParameters {}.abi_encode()); }

        let sponsor = self.vm().msg_sender();
        self.treasury_module.add_reserves(amount);
        self.vm().log(TreasuryFunded { sponsor, amount });
        Ok(())
    }
}

// ==========================================
// INFRASTRUCTURE & PRIVILEGE ADAPTERS
// ==========================================
impl KipioEconomics {
    /// @dev Centralized point of physical settlement. No other function executes RawCalls.
    fn settle_payment(&mut self, payee: Address, amount: U256) -> Result<(), Vec<u8>> {
        if amount == U256::ZERO { return Ok(()); }
        
        let _ = unsafe {
            stylus_sdk::call::RawCall::new_with_value(self.vm(), amount)
                .skip_return_data()
                .call(payee, &[])
        }.map_err(|_| TransferFailed {}.abi_encode())?;
        
        Ok(())
    }

    fn require_owner(&self) -> Result<(), Vec<u8>> {
        if self.vm().msg_sender() != self.owner.get() {
            return Err(Unauthorized {}.abi_encode());
        }
        Ok(())
    }
}

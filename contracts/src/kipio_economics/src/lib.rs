#![allow(unexpected_cfgs)]
#![cfg_attr(not(feature = "std"), no_std)]

extern crate alloc;

use alloc::{vec, vec::Vec};
use stylus_sdk::{
    abi::Bytes,
    alloy_primitives::{Address, B256, U256},
    alloy_sol_types::{sol, SolError, SolValue},
    prelude::*,
    storage::{StorageAddress, StorageBool, StorageMap, StorageU256},
};

// ===========================================================================
// SHARED DOMAIN BOUNDARY (Workspace Interfaces)
// ===========================================================================
//
// These types are consumed by kipio_execution_gateway and kipio_runtime.
// They define the economic contract of the protocol: what a "receipt" is,
// what a "settlement plan" is, and what a "credit entry" is.
//
// IMPORTANT: These types MUST remain stable. Changing them breaks the ABI
// that Gateway and Runtime consume.
// ===========================================================================

pub mod kipio_shared {
    use stylus_sdk::alloy_sol_types::sol;

    sol! {
        /// @notice Represents a successful economic clearance for protocol operations.
        /// @dev Consumed by Runtime to bind storage references to the user's identity.
        ///      `payment_id` is a deterministic identifier for audit and tracing,
        ///      derived from the funder and the settlement nonce. It is NOT used
        ///      for anti-replay (the nonce is). It exists so off-chain indexers can
        ///      correlate the receipt with a specific settlement intent.
        struct EconomicReceipt {
            address funder;
            uint256 allocated_capacity;
            uint256 fee_paid;
            uint8 service_id;
            address provider;
            bytes32 payment_id;
            uint256 nonce;
        }

        /// @notice Represents the economic intent orchestrated by the frontend.
        /// @dev Respects DDD: the frontend requests a "service_id" (business intent),
        ///      not a "provider_address" (infrastructure detail).
        ///
        ///      # Anti-replay
        ///      The `nonce` field is mandatory and must match the funder's current
        ///      on-chain nonce. This guarantees idempotency without growing storage:
        ///      the nonce is stored once per account and incremented in-place.
        ///      The frontend obtains the current nonce via `get_nonce(funder)`.
        struct SettlementPlan {
            uint256 requested_capacity;
            uint256 storage_quote;
            uint8 service_id;
            uint8 funding_source_id; // 0 = Native, 1 = Credit, 2 = Treasury, 3 = Grant, 4 = Sponsor
            bytes routing_payload;   // Dynamic resolution (e.g., grant_id, sponsor_id)
            uint256 nonce;           // Must equal get_nonce(funder)
        }

        /// @notice Report payload delivered by Chainlink CRE.
        /// @dev The `nonce` is the anti-replay mechanism. The CRE workflow
        ///      includes the funder's current nonce (obtained off-chain via
        ///      `get_nonce`) in the report. The contract validates that the nonce
        ///      is exactly the next expected value for the funder.
        ///
        ///      `payment_id` is derived on-chain as keccak256(funder, nonce) for
        ///      audit/tracing purposes. It is not used for anti-replay.
        ///
        ///      The `workflow_id` is NOT part of this report; it is extracted from
        ///      the KeystoneForwarder metadata (bytes 0..32), which is signed by
        ///      the DON and cannot be spoofed by a compromised workflow.
        struct CreSettlementReport {
            address funder;
            uint256 settled_amount;   // Total amount already converted to ETH
            uint8 service_id;
            uint256 requested_capacity;
            uint256 nonce;            // Must equal get_nonce(funder)
        }
    }
}

// ===========================================================================
// 1. TYPES, ERRORS & EVENTS (ECONOMIC DOMAIN)
// ===========================================================================
sol! {
    // --- ECONOMIC EVENTS ---
    event SettlementExecuted(
        address indexed funder,
        uint256 allocated_capacity,
        uint256 fee_paid,
        bytes32 indexed payment_id,
        uint256 nonce
    );
    event CreditDeposited(address indexed account, uint256 amount, uint64 expires_at);
    event CreditWithdrawn(address indexed account, uint256 amount);
    event CreditExpired(address indexed account, uint256 amount);
    event TreasuryFunded(address indexed sponsor, uint256 amount);
    event RefundIssued(address indexed account, uint256 amount);

    // --- FEE AUDIT EVENTS ---
    event ProtocolFeeCollected(
        address indexed funder,
        uint256 fee_amount,
        uint8 indexed service_id,
        bytes32 indexed payment_id
    );
    event ProtocolFeePolicyUpdated(uint256 fee_amount);
    event MaxProtocolFeeUpdated(uint256 max_fee);
    event CreForwarderUpdated(address indexed old_forwarder, address indexed new_forwarder);
    event CreWorkflowUpdated(bytes32 indexed old_workflow_id, bytes32 indexed new_workflow_id);

    // --- ACCOUNTING AUDIT EVENTS ---
    event TreasuryConsumed(address indexed beneficiary, uint256 amount);
    event GrantCreated(bytes32 indexed grant_id, uint256 amount, uint64 expires_at);
    event GrantConsumed(bytes32 indexed grant_id, address indexed beneficiary, uint256 amount);
    event GrantExpired(bytes32 indexed grant_id, uint256 remaining_amount);
    event SponsorRegistered(bytes32 indexed sponsor_id, address indexed sponsor, uint256 amount);
    event SponsorConsumed(bytes32 indexed sponsor_id, address indexed beneficiary, uint256 amount);
    event SponsoredExecution(address indexed beneficiary, uint8 source_id, uint256 amount);
    event BootstrapSponsored(address indexed beneficiary, uint256 amount);
    event BootstrapDepleted();

    // --- GOVERNANCE & REGISTRY EVENTS ---
    event ServiceRegistryUpdated(uint8 indexed service_id, address provider_address);
    event EconomicsDeployed(address indexed owner, address indexed cre_forwarder);
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event MaxCreditUpdated(uint256 max_credit);

    // --- BOOTSTRAP CAMPAIGN EVENTS ---
    event BootstrapCampaignCreated(
        bytes32 indexed campaign_id,
        uint256 amount_per_beneficiary,
        uint32 max_beneficiaries,
        uint64 expires_at
    );
    event BootstrapCampaignConsumed(
        bytes32 indexed campaign_id,
        address indexed beneficiary,
        uint256 amount
    );
    event BootstrapCampaignClosed(bytes32 indexed campaign_id, uint256 remaining);

    // --- CRE EVENTS ---
    event SettlementDeposited(bytes32 indexed payment_id, uint256 amount);
    event StaleSettlementReclaimed(
        bytes32 indexed payment_id,
        address indexed depositor,
        uint256 amount
    );
    event CreSettlementProcessed(
        address indexed funder,
        bytes32 indexed payment_id,
        uint256 amount,
        uint8 service_id,
        bytes32 indexed workflow_id,
        uint256 nonce
    );

    // --- REFUND EVENTS (PULL-BASED) ---
    event RefundCredited(address indexed account, uint256 amount);
    event RefundWithdrawn(address indexed account, uint256 amount);

    // --- NONCE EVENTS ---
    event NonceConsumed(address indexed account, uint256 nonce);

    // --- ECONOMIC ERRORS ---
    error InsufficientFunds();
    error InvalidPricingParameters();
    error InvalidSettlementPlan();
    error UnsupportedFundingSource();
    error TreasuryDepleted();
    error GrantDepleted();
    error GrantExpiredError();
    error SponsorDepleted();
    error CreditExpiredError();
    error CreditNotExpired();
    error MaxCreditExceeded();
    error CampaignDepleted();
    error CampaignExpired();
    error FeeExceedsMaximum();

    // --- SETTLEMENT ERRORS ---
    error UnsupportedService();
    error TransferFailed();
    error Unauthorized();
    error ZeroAmount();
    error AlreadyProcessed();
    error PausedError();
    error InvalidPaymentId();
    error GrantAlreadyExists();
    error SponsorAlreadyExists();
    error DepositTooLarge();
    error SettlementNotStale();
    error InvalidNonce(uint256 expected, uint256 provided);

    // --- CRE ERRORS ---
    error UnauthorizedForwarder();
    error UnauthorizedWorkflow();
    error ReplayDetected();
    error InvalidCreReport();
    error InsufficientDeposit();
}

// ===========================================================================
// 2. INTERNAL DOMAIN ABSTRACTIONS
// ===========================================================================

/// @notice Timeout after which a pending CRE settlement can be reclaimed by
///         anyone. Protects against a scenario where the CRE workflow never
///         delivers a report (DON failure, workflow revoked, etc.).
pub const SETTLEMENT_RECLAIM_TIMEOUT: u64 = 7 * 24 * 60 * 60; // 7 days

/// @notice Represents how economic resources become available for settlement.
/// @dev A funding source does not represent identity, ownership, or custody.
///      It only describes the origin of economic capacity.
#[derive(Debug, PartialEq, Eq)]
pub enum FundingSource {
    DirectNative(U256),
    InternalCredit,
    TreasurySponsored,
    GrantSponsored(B256),
    SponsorSponsored(B256),
}

impl FundingSource {
    /// @notice Decodes a funding source from its numeric ID and routing payload.
    /// @dev IDs are stable ABI constants. Adding new sources is a breaking change
    ///      for the frontend and must be coordinated.
    pub fn from_id(id: u8, native_value: U256, payload: &[u8]) -> Result<Self, Vec<u8>> {
        match id {
            0 => Ok(FundingSource::DirectNative(native_value)),
            1 => Ok(FundingSource::InternalCredit),
            2 => Ok(FundingSource::TreasurySponsored),
            3 => {
                let grant_id = B256::abi_decode(payload)
                    .map_err(|_| InvalidSettlementPlan {}.abi_encode())?;
                Ok(FundingSource::GrantSponsored(grant_id))
            },
            4 => {
                let sponsor_id = B256::abi_decode(payload)
                    .map_err(|_| InvalidSettlementPlan {}.abi_encode())?;
                Ok(FundingSource::SponsorSponsored(sponsor_id))
            },
            _ => Err(UnsupportedFundingSource {}.abi_encode()),
        }
    }
}

/// @notice Derives a deterministic payment identifier from the funder and nonce.
/// @dev This is used for audit and tracing only. Anti-replay is enforced by the
///      nonce check, not by this identifier. Two settlements with the same funder
///      and nonce would collide, but the nonce check prevents that.
pub fn derive_payment_id(funder: Address, nonce: U256) -> B256 {
    let mut buf = [0u8; 52];
    buf[0..20].copy_from_slice(funder.as_slice());
    buf[20..52].copy_from_slice(&nonce.to_be_bytes::<32>());
    alloy_primitives::keccak256(&buf)
}

/// @notice Packs a pending settlement into a single U256 slot.
/// @dev Zero additional storage cost compared to storing only the amount:
///      the depositor and timestamp are packed into the same slot.
pub fn pack_pending_settlement(amount: u64, depositor: Address, timestamp: u32) -> U256 {
    let mut packed = U256::from(amount);
    let depositor_u256 = U256::from_be_slice(depositor.as_slice());
    packed |= depositor_u256 << 64_usize;
    packed |= U256::from(timestamp) << 224_usize;
    packed
}

/// @notice Unpacks a pending settlement slot into its components.
pub fn unpack_pending_settlement(packed: U256) -> (u64, Address, u32) {
    let amount = (packed & U256::from(u64::MAX)).to::<u64>();
    let depositor_u256 = (packed >> 64_usize) & ((U256::ONE << 160_usize) - U256::ONE);
    let depositor_bytes = depositor_u256.to_be_bytes::<32>();
    let depositor = Address::from_slice(&depositor_bytes[12..32]);
    let timestamp = ((packed >> 224_usize) & U256::from(u32::MAX)).to::<u32>();
    (amount, depositor, timestamp)
}

/// @notice Packed allocation ledger for grants and sponsors.
/// @dev Layout (single slot, 256 bits):
///      - bits 0..128:   allocated (u128)
///      - bits 128..256: consumed (u128)
///
///      Why u128 and not U256? A grant or sponsor allocation in wei will never
///      exceed 2^128 (≈ 3.4e20 ETH). Using u128 for each half halves the
///      Storage Growth cost: one slot instead of two.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct PackedAllocation {
    pub allocated: u128,
    pub consumed: u128,
}

impl PackedAllocation {
    pub const ZERO: Self = Self { allocated: 0, consumed: 0 };

    pub fn pack(&self) -> U256 {
        U256::from(self.allocated) | (U256::from(self.consumed) << 128_usize)
    }

    pub fn unpack(value: U256) -> Self {
        let allocated = (value & U256::from(u128::MAX)).to::<u128>();
        let shifted: U256 = value >> 128_usize;
        let consumed = shifted.to::<u128>();
        Self { allocated, consumed }
    }

    pub fn remaining(&self) -> u128 {
        self.allocated.saturating_sub(self.consumed)
    }
}

/// @notice Credit entry with expiration.
/// @dev Layout (single slot, 256 bits):
///      - bits 0..128:   amount (u128)
///      - bits 128..192: expires_at (u64) — unix timestamp
///      - bits 192..256: reserved (u64) for future use
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct CreditEntry {
    pub amount: u128,
    pub expires_at: u64,
}

impl CreditEntry {
    pub const ZERO: Self = Self { amount: 0, expires_at: 0 };

    pub fn pack(&self) -> U256 {
        U256::from(self.amount) | (U256::from(self.expires_at) << 128_usize)
    }

    pub fn unpack(value: U256) -> Self {
        let amount = (value & U256::from(u128::MAX)).to::<u128>();
        let shifted: U256 = value >> 128_usize;
        let expires_at = (shifted & U256::from(u64::MAX)).to::<u64>();
        Self { amount, expires_at }
    }

    pub fn is_expired(&self, now: u64) -> bool {
        self.expires_at != 0 && now > self.expires_at
    }

    pub fn remaining(&self, now: u64) -> u128 {
        if self.is_expired(now) { 0 } else { self.amount }
    }
}

/// @notice Bootstrap campaign for targeted onboarding subsidies.
/// @dev Layout (single slot, 256 bits):
///      - bits 0..128:   amount_per_beneficiary (u128)
///      - bits 128..160: max_beneficiaries (u32)
///      - bits 160..192: consumed_beneficiaries (u32)
///      - bits 192..256: expires_at (u64)
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct BootstrapCampaign {
    pub amount_per_beneficiary: u128,
    pub max_beneficiaries: u32,
    pub consumed_beneficiaries: u32,
    pub expires_at: u64,
}

impl BootstrapCampaign {
    pub const ZERO: Self = Self {
        amount_per_beneficiary: 0,
        max_beneficiaries: 0,
        consumed_beneficiaries: 0,
        expires_at: 0,
    };

    pub fn pack(&self) -> U256 {
        let mut packed = U256::from(self.amount_per_beneficiary);
        packed |= U256::from(self.max_beneficiaries) << 128_usize;
        packed |= U256::from(self.consumed_beneficiaries) << 160_usize;
        packed |= U256::from(self.expires_at) << 192_usize;
        packed
    }

    pub fn unpack(value: U256) -> Self {
        let amount = (value & U256::from(u128::MAX)).to::<u128>();
        let shifted_128: U256 = value >> 128_usize;
        let max = (shifted_128 & U256::from(u32::MAX)).to::<u32>();
        let shifted_160: U256 = value >> 160_usize;
        let consumed = (shifted_160 & U256::from(u32::MAX)).to::<u32>();
        let shifted_192: U256 = value >> 192_usize;
        let expires = (shifted_192 & U256::from(u64::MAX)).to::<u64>();
        Self {
            amount_per_beneficiary: amount,
            max_beneficiaries: max,
            consumed_beneficiaries: consumed,
            expires_at: expires,
        }
    }

    pub fn is_expired(&self, now: u64) -> bool {
        self.expires_at != 0 && now > self.expires_at
    }

    pub fn is_depleted(&self) -> bool {
        self.consumed_beneficiaries >= self.max_beneficiaries
    }

    pub fn remaining(&self) -> u32 {
        self.max_beneficiaries
            .saturating_sub(self.consumed_beneficiaries)
    }
}

// ===========================================================================
// 3. SUBDOMAINS (BOUNDED CONTEXTS)
// ===========================================================================

/// @notice Pricing subdomain.
/// @dev Applies the protocol fee policy to a storage quote.
///      The fee is a fixed amount in wei, configurable by governance.
pub struct PricingModule;

impl PricingModule {
    /// @notice Applies the economic policy to a storage quote.
    /// @param storage_quote The raw quote from the storage provider (Irys).
    /// @param protocol_fee_amount The current fixed fee in wei.
    /// @return (storage_quote, protocol_fee) — the total is their sum.
    pub fn apply_economic_policy(
        storage_quote: U256,
        protocol_fee_amount: U256,
    ) -> (U256, U256) {
        (storage_quote, protocol_fee_amount)
    }
}

/// @notice Credit subdomain.
/// @dev Credit represents reusable purchasing capacity. It is NOT interest-bearing,
///      NOT an investment, and NOT a custodial account.
#[storage]
pub struct CreditModule {
    entries: StorageMap<Address, StorageU256>,
}

impl CreditModule {
    pub fn available_credit(&self, account: Address, now: u64) -> u128 {
        let packed = self.entries.getter(account).get();
        CreditEntry::unpack(packed).remaining(now)
    }

    pub fn add_credit(&mut self, account: Address, amount: u128, expires_at: u64, now: u64) {
        let packed = self.entries.getter(account).get();
        let mut entry = CreditEntry::unpack(packed);

        if entry.is_expired(now) {
            entry.amount = 0;
            entry.expires_at = 0;
        }

        entry.amount = entry.amount.saturating_add(amount);
        entry.expires_at = entry.expires_at.max(expires_at);

        self.entries.setter(account).set(entry.pack());
    }

    pub fn consume_credit(
        &mut self,
        account: Address,
        amount: u128,
        now: u64,
    ) -> Result<(), Vec<u8>> {
        let packed = self.entries.getter(account).get();
        let entry = CreditEntry::unpack(packed);

        if entry.is_expired(now) {
            return Err(CreditExpiredError {}.abi_encode());
        }

        if entry.remaining(now) < amount {
            return Err(InsufficientFunds {}.abi_encode());
        }

        let updated = CreditEntry {
            amount: entry.amount - amount,
            expires_at: entry.expires_at,
        };
        self.entries.setter(account).set(updated.pack());
        Ok(())
    }

    pub fn withdraw_expired(&mut self, account: Address, now: u64) -> Result<u128, Vec<u8>> {
        let packed = self.entries.getter(account).get();
        let entry = CreditEntry::unpack(packed);

        if !entry.is_expired(now) {
            return Err(CreditNotExpired {}.abi_encode());
        }

        let amount = entry.amount;
        self.entries.setter(account).set(U256::ZERO);

        if amount == 0 {
            return Err(ZeroAmount {}.abi_encode());
        }

        Ok(amount)
    }
}

/// @notice Treasury subdomain.
/// @dev Coordinates protocol-owned economic resources.
#[storage]
pub struct TreasuryModule {
    pub protocol_reserves: StorageU256,
    pub grant_allocations: StorageMap<B256, StorageU256>,
    pub sponsor_allocations: StorageMap<B256, StorageU256>,
    pub total_treasury_consumed: StorageU256,
    pub bootstrap_subsidy_amount: StorageU256,
    pub bootstrap_sponsorship_enabled: StorageBool,
    pub grant_expirations: StorageMap<B256, StorageU256>,
    pub sponsor_registry: StorageMap<B256, StorageBool>,
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

    pub fn consume_grant(
        &mut self,
        grant_id: B256,
        amount: U256,
        now: u64,
    ) -> Result<(), Vec<u8>> {
        let expires_at = self.grant_expirations.getter(grant_id).get().to::<u64>();
        if expires_at != 0 && now > expires_at {
            return Err(GrantExpiredError {}.abi_encode());
        }

        let packed = self.grant_allocations.getter(grant_id).get();
        let mut alloc = PackedAllocation::unpack(packed);

        let amount_u128: u128 = amount
            .try_into()
            .map_err(|_| InsufficientFunds {}.abi_encode())?;

        if alloc.remaining() < amount_u128 {
            return Err(GrantDepleted {}.abi_encode());
        }

        alloc.consumed += amount_u128;
        self.grant_allocations.setter(grant_id).set(alloc.pack());
        Ok(())
    }

    pub fn consume_sponsor(&mut self, sponsor_id: B256, amount: U256) -> Result<(), Vec<u8>> {
        if !self.sponsor_registry.getter(sponsor_id).get() {
            return Err(UnsupportedFundingSource {}.abi_encode());
        }

        let packed = self.sponsor_allocations.getter(sponsor_id).get();
        let mut alloc = PackedAllocation::unpack(packed);

        let amount_u128: u128 = amount
            .try_into()
            .map_err(|_| InsufficientFunds {}.abi_encode())?;

        if alloc.remaining() < amount_u128 {
            return Err(SponsorDepleted {}.abi_encode());
        }

        alloc.consumed += amount_u128;
        self.sponsor_allocations.setter(sponsor_id).set(alloc.pack());
        Ok(())
    }

    pub fn allocate_bootstrap_subsidy(&mut self) -> Result<U256, Vec<u8>> {
        let subsidy_amount = self.bootstrap_subsidy_amount.get();
        if subsidy_amount == U256::ZERO {
            return Err(InvalidPricingParameters {}.abi_encode());
        }

        if !self.bootstrap_sponsorship_enabled.get() {
            return Err(Unauthorized {}.abi_encode());
        }

        self.consume_treasury(subsidy_amount)?;
        Ok(subsidy_amount)
    }
}

// ===========================================================================
// 4. ECONOMIC COMPOSER (SETTLEMENT PIPELINE)
// ===========================================================================

#[storage]
#[entrypoint]
pub struct KipioEconomics {
    credit_module: CreditModule,
    treasury_module: TreasuryModule,
    service_registry: StorageMap<u8, StorageAddress>,
    protocol_fee: StorageU256,
    max_protocol_fee: StorageU256,
    owner: StorageAddress,
    cre_forwarder: StorageAddress,
    cre_workflow_id: StorageU256,
    /// @dev Per-account nonce for anti-replay. Incremented in-place on each
    ///      successful settlement. Zero growth per settlement: the same slot
    ///      is overwritten, so storage cost is O(accounts), not O(settlements).
    ///
    ///      # Why nonce instead of a `processed_payments` set?
    ///      A `StorageMap<B256, StorageBool>` grows by one slot per settlement.
    ///      At millions of settlements, the state trie grows unbounded, and the
    ///      Stylus SDK does not implement `Erase` for maps, so it cannot be pruned.
    ///      A per-account nonce stores exactly one slot per account and is
    ///      incremented in-place, making the storage footprint independent of
    ///      the number of settlements.
    ///
    ///      # Compatibility with Chainlink CRE
    ///      The CRE workflow reads the funder's current nonce via `get_nonce`
    ///      and includes it in the report. The contract validates that the
    ///      report's nonce matches the on-chain nonce before consuming it.
    ///      This is the same pattern CRE Connect uses for its "Wallet operation
    ///      ID" (a monotonically-increasing nonce-like value).
    account_nonces: StorageMap<Address, StorageU256>,
    pending_settlements: StorageMap<B256, StorageU256>,
    paused: StorageBool,
    max_credit_per_account: StorageU256,
    bootstrap_campaigns: StorageMap<B256, StorageU256>,
    campaign_consumed: StorageMap<B256, StorageMap<Address, StorageBool>>,
    /// @dev Pull-based refund balances. When a refund is owed (excess deposit,
    ///      bootstrap subsidy, expired credit), the amount is credited here
    ///      instead of being pushed to the recipient. The recipient withdraws
    ///      at their own pace, paying the gas. This makes the settlement flow
    ///      immune to recipients that reject ETH.
    withdrawable_refunds: StorageMap<Address, StorageU256>,
}

#[public]
impl KipioEconomics {
    // =======================================================================
    // CONSTRUCTOR
    // =======================================================================

    #[constructor]
    pub fn constructor(
        &mut self,
        cre_forwarder: Address,
        cre_workflow_id: B256,
    ) -> Result<(), Vec<u8>> {
        if cre_forwarder.is_zero() {
            return Err(UnauthorizedForwarder {}.abi_encode());
        }

        let deployer = self.vm().tx_origin();
        self.owner.set(deployer);
        self.cre_forwarder.set(cre_forwarder);
        self.cre_workflow_id
            .set(U256::from_be_bytes(cre_workflow_id.0));
        self.protocol_fee.set(U256::ZERO);
        self.max_protocol_fee
            .set(U256::from(100_000_000_000_000_000u128)); // 0.1 ETH default cap
        self.paused.set(false);
        self.max_credit_per_account.set(U256::ZERO);

        self.vm().log(EconomicsDeployed {
            owner: deployer,
            cre_forwarder,
        });

        Ok(())
    }

    // =======================================================================
    // GOVERNANCE
    // =======================================================================

    pub fn update_service_registry(
        &mut self,
        service_id: u8,
        provider_address: Address,
    ) -> Result<(), Vec<u8>> {
        self.require_owner()?;

        if provider_address.is_zero() {
            return Err(UnsupportedService {}.abi_encode());
        }

        self.service_registry
            .setter(service_id)
            .set(provider_address);
        self.vm().log(ServiceRegistryUpdated {
            service_id,
            provider_address,
        });
        Ok(())
    }

    pub fn update_protocol_fee(&mut self, new_fee: U256) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        if new_fee > self.max_protocol_fee.get() {
            return Err(FeeExceedsMaximum {}.abi_encode());
        }
        self.protocol_fee.set(new_fee);
        self.vm().log(ProtocolFeePolicyUpdated { fee_amount: new_fee });
        Ok(())
    }

    pub fn update_max_protocol_fee(&mut self, new_max: U256) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        self.max_protocol_fee.set(new_max);
        self.vm().log(MaxProtocolFeeUpdated { max_fee: new_max });
        Ok(())
    }

    pub fn update_cre_forwarder(&mut self, new_forwarder: Address) -> Result<(), Vec<u8>> {
        self.require_owner()?;

        if new_forwarder.is_zero() {
            return Err(UnauthorizedForwarder {}.abi_encode());
        }

        let old = self.cre_forwarder.get();
        self.cre_forwarder.set(new_forwarder);
        self.vm().log(CreForwarderUpdated {
            old_forwarder: old,
            new_forwarder,
        });
        Ok(())
    }

    pub fn update_cre_workflow_id(&mut self, new_workflow_id: B256) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        let old = self.cre_workflow_id.get();
        self.cre_workflow_id
            .set(U256::from_be_bytes(new_workflow_id.0));
        self.vm().log(CreWorkflowUpdated {
            old_workflow_id: B256::from(old.to_be_bytes()),
            new_workflow_id,
        });
        Ok(())
    }

    pub fn update_max_credit(&mut self, new_max: U256) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        self.max_credit_per_account.set(new_max);
        self.vm().log(MaxCreditUpdated { max_credit: new_max });
        Ok(())
    }

    pub fn pause(&mut self) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        self.paused.set(true);
        self.vm().log(Paused {
            account: self.vm().msg_sender(),
        });
        Ok(())
    }

    pub fn unpause(&mut self) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        self.paused.set(false);
        self.vm().log(Unpaused {
            account: self.vm().msg_sender(),
        });
        Ok(())
    }

    pub fn fund_bootstrap(&mut self, beneficiary: Address) -> Result<(bool, U256), Vec<u8>> {
        let subsidy = self.treasury_module.bootstrap_subsidy_amount.get();
        if subsidy == U256::ZERO {
            return Ok((false, U256::ZERO));
        }

        if !self.treasury_module.bootstrap_sponsorship_enabled.get() {
            return Ok((false, U256::ZERO));
        }

        match self.treasury_module.consume_treasury(subsidy) {
            Ok(()) => {
                self.vm().log(BootstrapSponsored {
                    beneficiary,
                    amount: subsidy,
                });
                let caller = self.vm().msg_sender();
                self.credit_refund(caller, subsidy);
                Ok((true, subsidy))
            },
            Err(_) => {
                self.vm().log(BootstrapDepleted);
                Ok((false, U256::ZERO))
            },
        }
    }

    // =======================================================================
    // BOOTSTRAP CAMPAIGNS
    // =======================================================================

    pub fn create_bootstrap_campaign(
        &mut self,
        campaign_id: B256,
        amount_per_beneficiary: U256,
        max_beneficiaries: u32,
        duration_seconds: u64,
    ) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        self.require_not_paused()?;

        if amount_per_beneficiary == U256::ZERO || max_beneficiaries == 0 {
            return Err(InvalidPricingParameters {}.abi_encode());
        }

        let existing = self.bootstrap_campaigns.getter(campaign_id).get();
        if existing != U256::ZERO {
            return Err(GrantAlreadyExists {}.abi_encode());
        }

        let amount_u128: u128 = amount_per_beneficiary
            .try_into()
            .map_err(|_| InvalidPricingParameters {}.abi_encode())?;

        let total_required_u128 = amount_u128
            .checked_mul(max_beneficiaries as u128)
            .ok_or_else(|| InvalidPricingParameters {}.abi_encode())?;
        let total_required = U256::from(total_required_u128);

        self.treasury_module.consume_treasury(total_required)?;

        let now = self.vm().block_timestamp();
        let expires_at = if duration_seconds > 0 {
            now + duration_seconds
        } else {
            0
        };

        let campaign = BootstrapCampaign {
            amount_per_beneficiary: amount_u128,
            max_beneficiaries,
            consumed_beneficiaries: 0,
            expires_at,
        };

        self.bootstrap_campaigns
            .setter(campaign_id)
            .set(campaign.pack());

        self.vm().log(BootstrapCampaignCreated {
            campaign_id,
            amount_per_beneficiary,
            max_beneficiaries,
            expires_at,
        });

        Ok(())
    }

    pub fn consume_bootstrap_campaign(
        &mut self,
        campaign_id: B256,
        beneficiary: Address,
    ) -> Result<U256, Vec<u8>> {
        self.require_not_paused()?;

        let packed = self.bootstrap_campaigns.getter(campaign_id).get();
        let mut campaign = BootstrapCampaign::unpack(packed);

        if campaign.max_beneficiaries == 0 {
            return Err(CampaignDepleted {}.abi_encode());
        }

        let now = self.vm().block_timestamp();
        if campaign.is_expired(now) {
            return Err(CampaignExpired {}.abi_encode());
        }

        if campaign.is_depleted() {
            return Err(CampaignDepleted {}.abi_encode());
        }

        if self
            .campaign_consumed
            .getter(campaign_id)
            .getter(beneficiary)
            .get()
        {
            return Err(AlreadyProcessed {}.abi_encode());
        }

        // --- CEI: effects first ---
        self.campaign_consumed
            .setter(campaign_id)
            .setter(beneficiary)
            .set(true);

        campaign.consumed_beneficiaries += 1;
        self.bootstrap_campaigns
            .setter(campaign_id)
            .set(campaign.pack());

        // --- Interaction: credit the caller (pull-based) ---
        let amount = U256::from(campaign.amount_per_beneficiary);
        let caller = self.vm().msg_sender();
        self.credit_refund(caller, amount);

        self.vm().log(BootstrapCampaignConsumed {
            campaign_id,
            beneficiary,
            amount,
        });

        Ok(amount)
    }

    pub fn close_bootstrap_campaign(&mut self, campaign_id: B256) -> Result<U256, Vec<u8>> {
        self.require_owner()?;
        self.require_not_paused()?;

        let packed = self.bootstrap_campaigns.getter(campaign_id).get();
        let campaign = BootstrapCampaign::unpack(packed);

        if campaign.max_beneficiaries == 0 {
            return Err(CampaignDepleted {}.abi_encode());
        }

        let remaining = campaign.remaining();
        let remaining_amount =
            U256::from(campaign.amount_per_beneficiary) * U256::from(remaining);

        self.bootstrap_campaigns
            .setter(campaign_id)
            .set(U256::ZERO);

        if remaining_amount > U256::ZERO {
            self.treasury_module.add_reserves(remaining_amount);
        }

        self.vm().log(BootstrapCampaignClosed {
            campaign_id,
            remaining: remaining_amount,
        });

        Ok(remaining_amount)
    }

    // =======================================================================
    // SETTLEMENT PIPELINE ENTRYPOINT
    // =======================================================================

    /// @notice Settles an economic obligation from a native Arbitrum call.
    /// @dev Anti-replay is enforced by the `nonce` field in the SettlementPlan.
    ///      The nonce must equal the funder's current on-chain nonce
    ///      (`get_nonce(funder)`). After a successful settlement, the nonce is
    ///      incremented in-place, so the same plan cannot be replayed.
    ///
    ///      # Why nonce instead of payment_id?
    ///      A `payment_id` set grows unbounded. A nonce grows only with the
    ///      number of accounts, and it is incremented in the same slot, so the
    ///      storage footprint per settlement is zero.
    #[payable]
    pub fn settle_economic_obligation(
        &mut self,
        plan_payload: Vec<u8>,
    ) -> Result<Vec<u8>, Vec<u8>> {
        self.require_not_paused()?;

        let plan = kipio_shared::SettlementPlan::abi_decode(&plan_payload)
            .map_err(|_| InvalidSettlementPlan {}.abi_encode())?;

        if plan.requested_capacity == U256::ZERO {
            return Err(InvalidPricingParameters {}.abi_encode());
        }

        let funder = self.vm().msg_sender();

        // --- Anti-replay: validate and consume the nonce ---
        self.use_checked_nonce(funder, plan.nonce)?;

        let payment_id = derive_payment_id(funder, plan.nonce);

        let provider_address = self.service_registry.getter(plan.service_id).get();
        if provider_address.is_zero() {
            return Err(UnsupportedService {}.abi_encode());
        }

        if provider_address == self.vm().contract_address() {
            return Err(UnsupportedService {}.abi_encode());
        }

        let value_provided = self.vm().msg_value();
        let now = self.vm().block_timestamp();

        let current_fee = self.protocol_fee.get();
        let (storage_quote, protocol_fee) =
            PricingModule::apply_economic_policy(plan.storage_quote, current_fee);
        let estimated_cost = storage_quote + protocol_fee;

        let funding_source =
            FundingSource::from_id(plan.funding_source_id, value_provided, &plan.routing_payload)?;
        let mut expected_native_value = U256::ZERO;

        match funding_source {
            FundingSource::DirectNative(amount) => {
                if amount < estimated_cost {
                    return Err(InsufficientFunds {}.abi_encode());
                }
                expected_native_value = estimated_cost;
            },
            FundingSource::InternalCredit => {
                let credit_u128: u128 = estimated_cost
                    .try_into()
                    .map_err(|_| InsufficientFunds {}.abi_encode())?;
                self.credit_module
                    .consume_credit(funder, credit_u128, now)?;
            },
            FundingSource::TreasurySponsored => {
                self.treasury_module.consume_treasury(estimated_cost)?;
                self.vm().log(TreasuryConsumed {
                    beneficiary: funder,
                    amount: estimated_cost,
                });
            },
            FundingSource::GrantSponsored(grant_id) => {
                self.treasury_module
                    .consume_grant(grant_id, estimated_cost, now)?;
                self.vm().log(GrantConsumed {
                    grant_id,
                    beneficiary: funder,
                    amount: estimated_cost,
                });
            },
            FundingSource::SponsorSponsored(sponsor_id) => {
                self.treasury_module
                    .consume_sponsor(sponsor_id, estimated_cost)?;
                self.vm().log(SponsorConsumed {
                    sponsor_id,
                    beneficiary: funder,
                    amount: estimated_cost,
                });
            },
        }

        if protocol_fee > U256::ZERO {
            self.treasury_module.add_reserves(protocol_fee);
            self.vm().log(ProtocolFeeCollected {
                funder,
                fee_amount: protocol_fee,
                service_id: plan.service_id,
                payment_id,
            });
        }

        if storage_quote > U256::ZERO {
            self.settle_payment(provider_address, storage_quote)?;
        }

        // --- Pull-based refund for excess native value ---
        if value_provided > expected_native_value {
            let refund_amount = value_provided - expected_native_value;
            self.credit_refund(funder, refund_amount);
            self.vm().log(RefundIssued {
                account: funder,
                amount: refund_amount,
            });
        }

        let receipt = kipio_shared::EconomicReceipt {
            funder,
            allocated_capacity: plan.requested_capacity,
            fee_paid: estimated_cost,
            service_id: plan.service_id,
            provider: provider_address,
            payment_id,
            nonce: plan.nonce,
        };

        self.vm().log(SettlementExecuted {
            funder,
            allocated_capacity: plan.requested_capacity,
            fee_paid: estimated_cost,
            payment_id,
            nonce: plan.nonce,
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

    // =======================================================================
    // CHAINLINK CRE SETTLEMENT
    // =======================================================================

    #[payable]
    pub fn deposit_for_settlement(&mut self, payment_id: B256) -> Result<(), Vec<u8>> {
        self.require_not_paused()?;

        let amount = self.vm().msg_value();
        if amount == U256::ZERO {
            return Err(ZeroAmount {}.abi_encode());
        }

        if amount > U256::from(u64::MAX) {
            return Err(DepositTooLarge {}.abi_encode());
        }

        let existing = self.pending_settlements.getter(payment_id).get();
        if existing != U256::ZERO {
            return Err(ReplayDetected {}.abi_encode());
        }

        let depositor = self.vm().msg_sender();
        let timestamp = self.vm().block_timestamp() as u32;
        let packed = pack_pending_settlement(amount.to::<u64>(), depositor, timestamp);
        self.pending_settlements.setter(payment_id).set(packed);

        self.vm().log(SettlementDeposited { payment_id, amount });
        Ok(())
    }

    pub fn reclaim_stale_settlement(&mut self, payment_id: B256) -> Result<(), Vec<u8>> {
        let packed = self.pending_settlements.getter(payment_id).get();
        if packed == U256::ZERO {
            return Err(InvalidPaymentId {}.abi_encode());
        }

        let (amount, depositor, timestamp) = unpack_pending_settlement(packed);

        let now = self.vm().block_timestamp();
        if now < u64::from(timestamp) + SETTLEMENT_RECLAIM_TIMEOUT {
            return Err(SettlementNotStale {}.abi_encode());
        }

        self.pending_settlements
            .setter(payment_id)
            .set(U256::ZERO);

        self.credit_refund(depositor, U256::from(amount));

        self.vm().log(StaleSettlementReclaimed {
            payment_id,
            depositor,
            amount: U256::from(amount),
        });

        Ok(())
    }

    /// @notice Receives and processes a settlement report from Chainlink CRE.
    /// @dev Anti-replay is enforced by the `nonce` field in the report. The
    ///      CRE workflow reads the funder's current nonce via `get_nonce` and
    ///      includes it in the report. The contract validates that the nonce
    ///      matches the on-chain nonce before consuming it.
    ///
    ///      # Metadata layout (64 bytes, signed by the DON)
    ///      - bytes  0..32: workflowId
    ///      - bytes 32..42: workflowName (truncated)
    ///      - bytes 42..62: workflowOwner
    ///      - bytes 62..64: reportId
    ///
    ///      # Flow
    ///      1. Validate msg.sender == cre_forwarder.
    ///      2. Extract workflowId from metadata and validate it.
    ///      3. Decode the report payload (CreSettlementReport).
    ///      4. Validate settled_amount > 0 and <= u64::MAX.
    ///      5. Validate requested_capacity > 0.
    ///      6. Validate funder != Address::ZERO.
    ///      7. Validate and consume the nonce.
    ///      8. Resolve provider BEFORE marking processed (fail-fast).
    ///      9. Unpack the pending deposit and verify solvency.
    ///      10. Compute fee (fixed) and storage_quote = settled_amount - fee.
    ///      11. Settle to provider, fee to treasury, excess to depositor.
    ///      12. Emit audit events.
    pub fn on_report(&mut self, metadata: Bytes, report: Bytes) -> Result<(), Vec<u8>> {
        // --- 1. Validate forwarder ---
        let sender = self.vm().msg_sender();
        let authorized = self.cre_forwarder.get();

        if sender != authorized {
            return Err(UnauthorizedForwarder {}.abi_encode());
        }

        // --- 2. Extract and validate workflowId from metadata ---
        let meta_bytes: &[u8] = metadata.as_ref();
        if meta_bytes.len() < 62 {
            return Err(InvalidCreReport {}.abi_encode());
        }
        let workflow_id = B256::from_slice(&meta_bytes[0..32]);
        let authorized_workflow = B256::from(self.cre_workflow_id.get().to_be_bytes());
        if workflow_id != authorized_workflow {
            return Err(UnauthorizedWorkflow {}.abi_encode());
        }

        // --- 3. Decode report ---
        let cre_report = kipio_shared::CreSettlementReport::abi_decode(&report)
            .map_err(|_| InvalidCreReport {}.abi_encode())?;

        // --- 4. Validate settled_amount > 0 and <= u64::MAX ---
        if cre_report.settled_amount == U256::ZERO
            || cre_report.settled_amount > U256::from(u64::MAX)
        {
            return Err(InvalidCreReport {}.abi_encode());
        }

        // --- 5. Validate requested_capacity > 0 ---
        if cre_report.requested_capacity == U256::ZERO {
            return Err(InvalidPricingParameters {}.abi_encode());
        }

        // --- 6. Validate funder is not the zero address ---
        if cre_report.funder == Address::ZERO {
            return Err(InvalidCreReport {}.abi_encode());
        }

        // --- 7. Anti-replay: validate and consume the nonce ---
        self.use_checked_nonce(cre_report.funder, cre_report.nonce)?;

        let payment_id = derive_payment_id(cre_report.funder, cre_report.nonce);

        // --- 8. Resolve provider BEFORE processing (fail-fast) ---
        let provider_address = self.service_registry.getter(cre_report.service_id).get();
        if provider_address.is_zero() {
            return Err(UnsupportedService {}.abi_encode());
        }

        // --- 9. Unpack pending deposit and verify solvency ---
        let packed = self.pending_settlements.getter(payment_id).get();
        if packed == U256::ZERO {
            return Err(InsufficientDeposit {}.abi_encode());
        }
        let (deposited_amount, depositor, _timestamp) = unpack_pending_settlement(packed);
        let deposited = U256::from(deposited_amount);

        if deposited < cre_report.settled_amount {
            return Err(InsufficientDeposit {}.abi_encode());
        }

        // --- 10. Clear deposit (CEI) ---
        self.pending_settlements.setter(payment_id).set(U256::ZERO);

        // --- 11. Compute fee and storage quote ---
        let protocol_fee = self.protocol_fee.get();
        if cre_report.settled_amount < protocol_fee {
            return Err(InsufficientFunds {}.abi_encode());
        }
        let storage_quote = cre_report.settled_amount - protocol_fee;

        // --- 12. Settle to provider ---
        if storage_quote > U256::ZERO {
            self.settle_payment(provider_address, storage_quote)?;
        }

        // --- 13. Fee to treasury ---
        if protocol_fee > U256::ZERO {
            self.treasury_module.add_reserves(protocol_fee);
            self.vm().log(ProtocolFeeCollected {
                funder: cre_report.funder,
                fee_amount: protocol_fee,
                service_id: cre_report.service_id,
                payment_id,
            });
        }

        // --- 14. Pull-based refund of excess deposit ---
        if deposited > cre_report.settled_amount {
            let refund_amount = deposited - cre_report.settled_amount;
            self.credit_refund(depositor, refund_amount);
        }

        // --- 15. Emit events ---
        self.vm().log(CreSettlementProcessed {
            funder: cre_report.funder,
            payment_id,
            amount: cre_report.settled_amount,
            service_id: cre_report.service_id,
            workflow_id,
            nonce: cre_report.nonce,
        });

        self.vm().log(SettlementExecuted {
            funder: cre_report.funder,
            allocated_capacity: cre_report.requested_capacity,
            fee_paid: cre_report.settled_amount,
            payment_id,
            nonce: cre_report.nonce,
        });

        Ok(())
    }

    // =======================================================================
    // FUND ADMINISTRATION (GOVERNANCE)
    // =======================================================================

    pub fn create_grant(
        &mut self,
        grant_id: B256,
        amount: U256,
        duration_seconds: u64,
    ) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        self.require_not_paused()?;

        let existing = self
            .treasury_module
            .grant_allocations
            .getter(grant_id)
            .get();
        if existing != U256::ZERO {
            return Err(GrantAlreadyExists {}.abi_encode());
        }

        self.treasury_module.consume_treasury(amount)?;

        let amount_u128: u128 = amount
            .try_into()
            .map_err(|_| InsufficientFunds {}.abi_encode())?;

        let alloc = PackedAllocation {
            allocated: amount_u128,
            consumed: 0,
        };
        self.treasury_module
            .grant_allocations
            .setter(grant_id)
            .set(alloc.pack());

        let now = self.vm().block_timestamp();
        let expires_at = if duration_seconds > 0 {
            now + duration_seconds
        } else {
            0
        };
        self.treasury_module
            .grant_expirations
            .setter(grant_id)
            .set(U256::from(expires_at));

        self.vm().log(GrantCreated {
            grant_id,
            amount,
            expires_at,
        });
        Ok(())
    }

    pub fn reclaim_expired_grant(&mut self, grant_id: B256) -> Result<U256, Vec<u8>> {
        self.require_owner()?;
        self.require_not_paused()?;

        let expires_at = self
            .treasury_module
            .grant_expirations
            .getter(grant_id)
            .get()
            .to::<u64>();

        if expires_at == 0 {
            return Err(GrantExpiredError {}.abi_encode());
        }

        let now = self.vm().block_timestamp();
        if now <= expires_at {
            return Err(GrantExpiredError {}.abi_encode());
        }

        let packed = self
            .treasury_module
            .grant_allocations
            .getter(grant_id)
            .get();
        let alloc = PackedAllocation::unpack(packed);
        let remaining = U256::from(alloc.remaining());

        self.treasury_module
            .grant_allocations
            .setter(grant_id)
            .set(U256::ZERO);
        self.treasury_module
            .grant_expirations
            .setter(grant_id)
            .set(U256::ZERO);

        self.treasury_module.add_reserves(remaining);

        self.vm().log(GrantExpired {
            grant_id,
            remaining_amount: remaining,
        });

        Ok(remaining)
    }

    pub fn set_bootstrap_policy(
        &mut self,
        enabled: bool,
        amount: U256,
    ) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        self.require_not_paused()?;
        self.treasury_module
            .bootstrap_sponsorship_enabled
            .set(enabled);
        self.treasury_module.bootstrap_subsidy_amount.set(amount);
        Ok(())
    }

    pub fn register_sponsor_governance(
        &mut self,
        sponsor_id: B256,
        sponsor_address: Address,
    ) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        self.require_not_paused()?;

        if self.treasury_module.sponsor_registry.getter(sponsor_id).get() {
            return Err(SponsorAlreadyExists {}.abi_encode());
        }

        self.treasury_module
            .sponsor_registry
            .setter(sponsor_id)
            .set(true);

        self.vm().log(SponsorRegistered {
            sponsor_id,
            sponsor: sponsor_address,
            amount: U256::ZERO,
        });

        Ok(())
    }

    // =======================================================================
    // PERMISSIONLESS CREDIT & FUNDING
    // =======================================================================

    #[payable]
    pub fn deposit_credit(&mut self) -> Result<(), Vec<u8>> {
        self.require_not_paused()?;

        let amount = self.vm().msg_value();
        if amount == U256::ZERO {
            return Err(ZeroAmount {}.abi_encode());
        }

        let amount_u128: u128 = amount
            .try_into()
            .map_err(|_| InvalidPricingParameters {}.abi_encode())?;

        let account = self.vm().msg_sender();
        let now = self.vm().block_timestamp();

        let max_credit = self.max_credit_per_account.get();
        if max_credit > U256::ZERO {
            let current = U256::from(self.credit_module.available_credit(account, now));
            if current + amount > max_credit {
                return Err(MaxCreditExceeded {}.abi_encode());
            }
        }

        let expires_at = now + 90 * 24 * 60 * 60; // 90 days

        self.credit_module
            .add_credit(account, amount_u128, expires_at, now);

        self.vm().log(CreditDeposited {
            account,
            amount,
            expires_at,
        });
        Ok(())
    }

    pub fn withdraw_credit(&mut self) -> Result<(), Vec<u8>> {
        let account = self.vm().msg_sender();
        let now = self.vm().block_timestamp();

        let amount = self.credit_module.withdraw_expired(account, now)?;
        let amount_u256 = U256::from(amount);

        self.settle_payment(account, amount_u256)?;
        self.vm().log(CreditWithdrawn {
            account,
            amount: amount_u256,
        });
        Ok(())
    }

    pub fn withdraw_refund(&mut self) -> Result<(), Vec<u8>> {
        let account = self.vm().msg_sender();
        let amount = self.withdrawable_refunds.getter(account).get();

        if amount == U256::ZERO {
            return Err(ZeroAmount {}.abi_encode());
        }

        self.withdrawable_refunds.setter(account).set(U256::ZERO);
        self.settle_payment(account, amount)?;

        self.vm().log(RefundWithdrawn { account, amount });
        Ok(())
    }

    #[payable]
    pub fn deposit_sponsor_funds(&mut self, sponsor_id: B256) -> Result<(), Vec<u8>> {
        self.require_not_paused()?;

        let amount = self.vm().msg_value();
        if amount == U256::ZERO {
            return Err(ZeroAmount {}.abi_encode());
        }

        if !self.treasury_module.sponsor_registry.getter(sponsor_id).get() {
            return Err(UnsupportedFundingSource {}.abi_encode());
        }

        let packed = self
            .treasury_module
            .sponsor_allocations
            .getter(sponsor_id)
            .get();
        let mut alloc = PackedAllocation::unpack(packed);
        let amount_u128: u128 = amount
            .try_into()
            .map_err(|_| InvalidPricingParameters {}.abi_encode())?;
        alloc.allocated = alloc.allocated.saturating_add(amount_u128);
        self.treasury_module
            .sponsor_allocations
            .setter(sponsor_id)
            .set(alloc.pack());

        self.vm().log(SponsorRegistered {
            sponsor_id,
            sponsor: self.vm().msg_sender(),
            amount,
        });
        Ok(())
    }

    #[payable]
    pub fn fund_treasury(&mut self) -> Result<(), Vec<u8>> {
        self.require_not_paused()?;

        let amount = self.vm().msg_value();
        if amount == U256::ZERO {
            return Err(ZeroAmount {}.abi_encode());
        }

        let sponsor = self.vm().msg_sender();
        self.treasury_module.add_reserves(amount);
        self.vm().log(TreasuryFunded { sponsor, amount });
        Ok(())
    }

    // =======================================================================
    // VIEWS
    // =======================================================================

    /// @notice Returns the current nonce for an account.
    /// @dev The frontend MUST call this before every settlement and include the
    ///      returned value in the `SettlementPlan.nonce` (or `CreSettlementReport.nonce`).
    ///      If the nonce does not match, the settlement reverts with `InvalidNonce`.
    pub fn get_nonce(&self, account: Address) -> U256 {
        self.account_nonces.get(account)
    }

    pub fn quote_settlement(
        &self,
        requested_capacity: U256,
        storage_quote: U256,
        service_id: u8,
    ) -> Result<U256, Vec<u8>> {
        let provider = self.service_registry.getter(service_id).get();
        if provider.is_zero() {
            return Err(UnsupportedService {}.abi_encode());
        }

        let fee = self.protocol_fee.get();
        let total = storage_quote + fee;

        if requested_capacity == U256::ZERO || total == U256::ZERO {
            return Err(InvalidPricingParameters {}.abi_encode());
        }

        Ok(total)
    }

    pub fn get_owner(&self) -> Address {
        self.owner.get()
    }

    pub fn get_cre_forwarder(&self) -> Address {
        self.cre_forwarder.get()
    }

    pub fn get_cre_workflow_id(&self) -> B256 {
        B256::from(self.cre_workflow_id.get().to_be_bytes())
    }

    pub fn get_protocol_fee(&self) -> U256 {
        self.protocol_fee.get()
    }

    pub fn get_max_protocol_fee(&self) -> U256 {
        self.max_protocol_fee.get()
    }

    pub fn get_available_credit(&self, account: Address) -> U256 {
        let now = self.vm().block_timestamp();
        U256::from(self.credit_module.available_credit(account, now))
    }

    pub fn get_withdrawable_refund(&self, account: Address) -> U256 {
        self.withdrawable_refunds.getter(account).get()
    }

    pub fn get_grant_remaining(&self, grant_id: B256) -> U256 {
        let packed = self
            .treasury_module
            .grant_allocations
            .getter(grant_id)
            .get();
        U256::from(PackedAllocation::unpack(packed).remaining())
    }

    pub fn get_grant_expires_at(&self, grant_id: B256) -> u64 {
        self.treasury_module
            .grant_expirations
            .getter(grant_id)
            .get()
            .to::<u64>()
    }

    pub fn get_sponsor_remaining(&self, sponsor_id: B256) -> U256 {
        let packed = self
            .treasury_module
            .sponsor_allocations
            .getter(sponsor_id)
            .get();
        U256::from(PackedAllocation::unpack(packed).remaining())
    }

    pub fn get_treasury_reserves(&self) -> U256 {
        self.treasury_module.protocol_reserves.get()
    }

    pub fn get_provider(&self, service_id: u8) -> Address {
        self.service_registry.getter(service_id).get()
    }

    pub fn get_pending_settlement(&self, payment_id: B256) -> U256 {
        let packed = self.pending_settlements.getter(payment_id).get();
        U256::from(unpack_pending_settlement(packed).0)
    }

    pub fn get_pending_settlement_depositor(&self, payment_id: B256) -> Address {
        let packed = self.pending_settlements.getter(payment_id).get();
        unpack_pending_settlement(packed).1
    }

    pub fn get_pending_settlement_timestamp(&self, payment_id: B256) -> u32 {
        let packed = self.pending_settlements.getter(payment_id).get();
        unpack_pending_settlement(packed).2
    }

    pub fn is_paused(&self) -> bool {
        self.paused.get()
    }

    pub fn get_max_credit(&self) -> U256 {
        self.max_credit_per_account.get()
    }

    pub fn get_bootstrap_campaign(&self, campaign_id: B256) -> (U256, u32, u32, u64) {
        let packed = self.bootstrap_campaigns.getter(campaign_id).get();
        let campaign = BootstrapCampaign::unpack(packed);
        (
            U256::from(campaign.amount_per_beneficiary),
            campaign.max_beneficiaries,
            campaign.consumed_beneficiaries,
            campaign.expires_at,
        )
    }

    pub fn has_consumed_campaign(&self, campaign_id: B256, beneficiary: Address) -> bool {
        self.campaign_consumed
            .getter(campaign_id)
            .getter(beneficiary)
            .get()
    }
}

// ===========================================================================
// INTERNAL HELPERS
// ===========================================================================
impl KipioEconomics {
    /// @notice Validates and consumes a nonce for an account.
    /// @dev The nonce must exactly equal the account's current nonce. On success,
    ///      the nonce is incremented by one. This is the anti-replay mechanism.
    ///
    ///      # Why not `>` instead of `==`?
    ///      Strict equality prevents out-of-order consumption. If the frontend
    ///      skips a nonce (e.g., due to a race condition), the settlement reverts
    ///      and the frontend must retry with the correct nonce. This mirrors the
    ///      behavior of EIP-4337 and other smart account standards.
    fn use_checked_nonce(&mut self, account: Address, nonce: U256) -> Result<(), Vec<u8>> {
        let current = self.account_nonces.get(account);
        if nonce != current {
            return Err(InvalidNonce {
                expected: current,
                provided: nonce,
            }
            .abi_encode());
        }

        let next = current
            .checked_add(U256::ONE)
            .ok_or_else(|| InvalidNonce {
                expected: current,
                provided: nonce,
            }
            .abi_encode())?;

        self.account_nonces.setter(account).set(next);
        self.vm().log(NonceConsumed { account, nonce });
        Ok(())
    }

    /// @notice Centralized physical settlement. No other function executes RawCalls.
    /// @dev Uses flush_storage_cache() on RawCall to persist the storage cache
    ///      before the external call.
    fn settle_payment(&mut self, payee: Address, amount: U256) -> Result<(), Vec<u8>> {
        if amount == U256::ZERO {
            return Ok(());
        }

        let _ = unsafe {
            stylus_sdk::call::RawCall::new_with_value(self.vm(), amount)
                .flush_storage_cache()
                .skip_return_data()
                .call(payee, &[])
        }
        .map_err(|_| TransferFailed {}.abi_encode())?;

        Ok(())
    }

    /// @notice Credits a pull-based refund balance to an account.
    fn credit_refund(&mut self, account: Address, amount: U256) {
        if amount == U256::ZERO {
            return;
        }
        let current = self.withdrawable_refunds.getter(account).get();
        self.withdrawable_refunds
            .setter(account)
            .set(current + amount);
        self.vm().log(RefundCredited { account, amount });
    }

    fn require_owner(&self) -> Result<(), Vec<u8>> {
        if self.vm().msg_sender() != self.owner.get() {
            return Err(Unauthorized {}.abi_encode());
        }
        Ok(())
    }

    fn require_not_paused(&self) -> Result<(), Vec<u8>> {
        if self.paused.get() {
            return Err(PausedError {}.abi_encode());
        }
        Ok(())
    }
}

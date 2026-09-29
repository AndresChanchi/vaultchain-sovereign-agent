//! Root storage struct for `kipio_economics`.
//!
//! Aggregates the subdomains (credit, treasury) and the top-level fields
//! that do not belong to a specific subdomain: governance configuration,
//! pending CRE settlements, per-account nonces, and pull-based refunds.

use stylus_sdk::alloy_primitives::{Address, B256};
use stylus_sdk::prelude::*;
use stylus_sdk::storage::{StorageAddress, StorageBool, StorageMap, StorageU256};

use crate::storage::credit::CreditModule;
use crate::storage::treasury::TreasuryModule;

#[storage]
#[entrypoint]
pub struct KipioEconomics {
    pub(crate) credit_module: CreditModule,
    pub(crate) treasury_module: TreasuryModule,
    pub(crate) service_registry: StorageMap<u8, StorageAddress>,
    pub(crate) protocol_fee: StorageU256,
    pub(crate) max_protocol_fee: StorageU256,
    pub(crate) owner: StorageAddress,
    pub(crate) cre_forwarder: StorageAddress,
    pub(crate) cre_workflow_id: StorageU256,

    /// Per-account nonce for anti-replay. Incremented in-place on each
    /// successful settlement.
    ///
    /// # Why nonce instead of a `processed_payments` set?
    ///
    /// A `StorageMap<B256, StorageBool>` grows by one slot per settlement.
    /// At millions of settlements, the state trie grows unbounded, and the
    /// Stylus SDK does not implement `Erase` for maps, so it cannot be pruned.
    /// A per-account nonce stores exactly one slot per account and is
    /// incremented in-place, making the storage footprint independent of
    /// the number of settlements.
    ///
    /// # Compatibility with Chainlink CRE
    ///
    /// The CRE workflow reads the funder's current nonce via `get_nonce` and
    /// includes it in the report. The contract validates that the report's
    /// nonce matches the on-chain nonce before consuming it. This mirrors
    /// the "Wallet operation ID" pattern that CRE Connect uses.
    pub(crate) account_nonces: StorageMap<Address, StorageU256>,

    /// Pending CRE deposits, packed as `amount | depositor | timestamp`.
    pub(crate) pending_settlements: StorageMap<B256, StorageU256>,

    pub(crate) paused: StorageBool,
    pub(crate) max_credit_per_account: StorageU256,

    /// Bootstrap campaigns: `campaign_id => packed BootstrapCampaign`.
    pub(crate) bootstrap_campaigns: StorageMap<B256, StorageU256>,

    /// Tracks which campaigns a beneficiary has consumed (anti-replay).
    pub(crate) campaign_consumed: StorageMap<B256, StorageMap<Address, StorageBool>>,

    /// Pull-based refund balances.
    ///
    /// When a refund is owed (excess deposit, bootstrap subsidy, expired
    /// credit), the amount is credited here instead of being pushed to the
    /// recipient. The recipient withdraws at their own pace, paying the gas.
    /// This makes the settlement flow immune to recipients that reject ETH.
    pub(crate) withdrawable_refunds: StorageMap<Address, StorageU256>,
}

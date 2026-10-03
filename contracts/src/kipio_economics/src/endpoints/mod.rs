//! Public entrypoints for `kipio_economics`.
//!
//! # Why a single `#[public]` block?
//!
//! The Stylus SDK's `#[public]` macro generates one `Router` trait impl and
//! one `HostAccess` impl per type. Rust forbids more than one impl of the
//! same trait for the same type, so all public endpoints MUST live in a
//! single `#[public] impl KipioEconomics` block.
//!
//! To keep the code readable despite this constraint, this module holds the
//! `#[public]` block with thin delegators, and the actual logic lives in
//! sibling modules as `pub(crate) fn handle_*` methods on the same type.
//! The delegators carry the exact same signatures as the pre-split
//! endpoints, so the ABI is unchanged except for the endpoints that gained
//! the Model B `user` parameter (see below).
//!
//! # Model B changes
//!
//! `deposit_credit`, `withdraw_credit`, `withdraw_refund`,
//! `deposit_sponsor_funds`, `fund_treasury`, and
//! `settle_economic_obligation` gained an explicit `user` / `funder`
//! parameter as their first argument. Each of those handlers validates
//! the caller through `require_user_or_runtime(user)`, accepting either a
//! direct call from the user (`msg_sender == user`) or a forwarded call
//! from the runtime (`msg_sender == runtime`, `user` supplied by the
//! orchestrator).
//!
//! `credit_identity_refund` and every governance/view endpoint retain
//! their original signatures.

use alloc::vec::Vec;

use stylus_sdk::abi::Bytes;
use stylus_sdk::alloy_primitives::{Address, B256, U256};
use stylus_sdk::prelude::*;

use crate::storage::entrypoint::KipioEconomics;

mod bootstrap_campaigns;
mod constructor;
mod cre;
mod credit;
mod governance;
mod grants;
mod settlement;
mod sponsors;
mod views;

#[public]
impl KipioEconomics {
    // =======================================================================
    // CONSTRUCTOR
    // =======================================================================

    #[constructor]
    pub fn constructor(
        &mut self,
        protocol_config: Address,
        cre_forwarder: Address,
        cre_workflow_id: B256,
    ) -> Result<(), Vec<u8>> {
        constructor::handle_constructor(self, protocol_config, cre_forwarder, cre_workflow_id)
    }

    // =======================================================================
    // GOVERNANCE
    // =======================================================================

    pub fn update_service_registry(
        &mut self,
        service_id: u8,
        provider_address: Address,
    ) -> Result<(), Vec<u8>> {
        governance::handle_update_service_registry(self, service_id, provider_address)
    }

    pub fn update_protocol_fee(&mut self, new_fee: U256) -> Result<(), Vec<u8>> {
        governance::handle_update_protocol_fee(self, new_fee)
    }

    pub fn update_max_protocol_fee(&mut self, new_max: U256) -> Result<(), Vec<u8>> {
        governance::handle_update_max_protocol_fee(self, new_max)
    }

    pub fn update_cre_forwarder(&mut self, new_forwarder: Address) -> Result<(), Vec<u8>> {
        governance::handle_update_cre_forwarder(self, new_forwarder)
    }

    pub fn update_cre_workflow_id(&mut self, new_workflow_id: B256) -> Result<(), Vec<u8>> {
        governance::handle_update_cre_workflow_id(self, new_workflow_id)
    }

    pub fn update_max_credit(&mut self, new_max: U256) -> Result<(), Vec<u8>> {
        governance::handle_update_max_credit(self, new_max)
    }

    pub fn pause(&mut self) -> Result<(), Vec<u8>> {
        governance::handle_pause(self)
    }

    pub fn unpause(&mut self) -> Result<(), Vec<u8>> {
        governance::handle_unpause(self)
    }

    pub fn fund_bootstrap(&mut self, beneficiary: Address) -> Result<(bool, U256), Vec<u8>> {
        governance::handle_fund_bootstrap(self, beneficiary)
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
        bootstrap_campaigns::handle_create_bootstrap_campaign(
            self,
            campaign_id,
            amount_per_beneficiary,
            max_beneficiaries,
            duration_seconds,
        )
    }

    pub fn consume_bootstrap_campaign(
        &mut self,
        campaign_id: B256,
        beneficiary: Address,
    ) -> Result<U256, Vec<u8>> {
        bootstrap_campaigns::handle_consume_bootstrap_campaign(self, campaign_id, beneficiary)
    }

    pub fn close_bootstrap_campaign(&mut self, campaign_id: B256) -> Result<U256, Vec<u8>> {
        bootstrap_campaigns::handle_close_bootstrap_campaign(self, campaign_id)
    }

    // =======================================================================
    // SETTLEMENT PIPELINE
    // =======================================================================

    #[payable]
    pub fn settle_economic_obligation(
        &mut self,
        funder: Address,
        plan_payload: Vec<u8>,
    ) -> Result<Vec<u8>, Vec<u8>> {
        settlement::handle_settle_economic_obligation(self, funder, plan_payload)
    }

    // =======================================================================
    // CHAINLINK CRE SETTLEMENT
    // =======================================================================

    #[payable]
    pub fn deposit_for_settlement(&mut self, payment_id: B256) -> Result<(), Vec<u8>> {
        cre::handle_deposit_for_settlement(self, payment_id)
    }

    pub fn reclaim_stale_settlement(&mut self, payment_id: B256) -> Result<(), Vec<u8>> {
        cre::handle_reclaim_stale_settlement(self, payment_id)
    }

    pub fn on_report(&mut self, metadata: Bytes, report: Bytes) -> Result<(), Vec<u8>> {
        cre::handle_on_report(self, metadata, report)
    }

    // =======================================================================
    // GRANTS
    // =======================================================================

    pub fn create_grant(
        &mut self,
        grant_id: B256,
        amount: U256,
        duration_seconds: u64,
    ) -> Result<(), Vec<u8>> {
        grants::handle_create_grant(self, grant_id, amount, duration_seconds)
    }

    pub fn reclaim_expired_grant(&mut self, grant_id: B256) -> Result<U256, Vec<u8>> {
        grants::handle_reclaim_expired_grant(self, grant_id)
    }

    pub fn set_bootstrap_policy(
        &mut self,
        enabled: bool,
        amount: U256,
    ) -> Result<(), Vec<u8>> {
        grants::handle_set_bootstrap_policy(self, enabled, amount)
    }

    pub fn register_sponsor_governance(
        &mut self,
        sponsor_id: B256,
        sponsor_address: Address,
    ) -> Result<(), Vec<u8>> {
        grants::handle_register_sponsor_governance(self, sponsor_id, sponsor_address)
    }

    // =======================================================================
    // PERMISSIONLESS CREDIT & FUNDING
    // =======================================================================

    #[payable]
    pub fn deposit_credit(&mut self, user: Address) -> Result<(), Vec<u8>> {
        credit::handle_deposit_credit(self, user)
    }

    pub fn withdraw_credit(&mut self, user: Address) -> Result<(), Vec<u8>> {
        credit::handle_withdraw_credit(self, user)
    }

    pub fn withdraw_refund(&mut self, user: Address) -> Result<(), Vec<u8>> {
        credit::handle_withdraw_refund(self, user)
    }

    /// Credits an identity's refund balance with attached ETH.
    ///
    /// Permissionless: the caller must attach exactly `amount` wei. Used
    /// by the Execution Gateway to return unused sponsorship budget to
    /// the identity after a sponsored activation.
    #[payable]
    pub fn credit_identity_refund(
        &mut self,
        identity: Address,
        amount: U256,
    ) -> Result<(), Vec<u8>> {
        credit::handle_credit_identity_refund(self, identity, amount)
    }

    #[payable]
    pub fn deposit_sponsor_funds(
        &mut self,
        user: Address,
        sponsor_id: B256,
    ) -> Result<(), Vec<u8>> {
        sponsors::handle_deposit_sponsor_funds(self, user, sponsor_id)
    }

    #[payable]
    pub fn fund_treasury(&mut self, user: Address) -> Result<(), Vec<u8>> {
        sponsors::handle_fund_treasury(self, user)
    }

    // =======================================================================
    // VIEWS
    // =======================================================================

    pub fn get_nonce(&self, account: Address) -> U256 {
        views::get_nonce(self, account)
    }

    pub fn quote_settlement(
        &self,
        requested_capacity: U256,
        storage_quote: U256,
        service_id: u8,
    ) -> Result<U256, Vec<u8>> {
        views::quote_settlement(self, requested_capacity, storage_quote, service_id)
    }

    pub fn get_owner(&self) -> Address {
        views::get_owner(self)
    }

    pub fn get_cre_forwarder(&self) -> Address {
        views::get_cre_forwarder(self)
    }

    pub fn get_cre_workflow_id(&self) -> B256 {
        views::get_cre_workflow_id(self)
    }

    pub fn get_protocol_fee(&self) -> U256 {
        views::get_protocol_fee(self)
    }

    pub fn get_max_protocol_fee(&self) -> U256 {
        views::get_max_protocol_fee(self)
    }

    pub fn get_available_credit(&self, account: Address) -> U256 {
        views::get_available_credit(self, account)
    }

    pub fn get_withdrawable_refund(&self, account: Address) -> U256 {
        views::get_withdrawable_refund(self, account)
    }

    pub fn get_grant_remaining(&self, grant_id: B256) -> U256 {
        views::get_grant_remaining(self, grant_id)
    }

    pub fn get_grant_expires_at(&self, grant_id: B256) -> u64 {
        views::get_grant_expires_at(self, grant_id)
    }

    pub fn get_sponsor_remaining(&self, sponsor_id: B256) -> U256 {
        views::get_sponsor_remaining(self, sponsor_id)
    }

    pub fn get_treasury_reserves(&self) -> U256 {
        views::get_treasury_reserves(self)
    }

    pub fn get_provider(&self, service_id: u8) -> Address {
        views::get_provider(self, service_id)
    }

    pub fn get_pending_settlement(&self, payment_id: B256) -> U256 {
        views::get_pending_settlement(self, payment_id)
    }

    pub fn get_pending_settlement_depositor(&self, payment_id: B256) -> Address {
        views::get_pending_settlement_depositor(self, payment_id)
    }

    pub fn get_pending_settlement_timestamp(&self, payment_id: B256) -> u32 {
        views::get_pending_settlement_timestamp(self, payment_id)
    }

    pub fn is_paused(&self) -> bool {
        views::is_paused(self)
    }

    pub fn get_max_credit(&self) -> U256 {
        views::get_max_credit(self)
    }

    pub fn get_bootstrap_campaign(&self, campaign_id: B256) -> (U256, u32, u32, u64) {
        views::get_bootstrap_campaign(self, campaign_id)
    }

    pub fn has_consumed_campaign(&self, campaign_id: B256, beneficiary: Address) -> bool {
        views::has_consumed_campaign(self, campaign_id, beneficiary)
    }
}

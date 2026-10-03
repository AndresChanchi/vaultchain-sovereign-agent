//! Read-only view handlers.

use alloc::vec::Vec;

use stylus_sdk::alloy_primitives::{Address, B256, U256};
use stylus_sdk::alloy_sol_types::SolError;
use stylus_sdk::prelude::*;

use crate::abi::errors::{InvalidPricingParameters, UnsupportedService};
use crate::codec::pack::{BootstrapCampaign, PackedAllocation};
use crate::codec::pending::unpack_pending_settlement;
use crate::storage::entrypoint::KipioEconomics;

pub(crate) fn get_nonce(this: &KipioEconomics, account: Address) -> U256 {
    this.account_nonces.get(account)
}

pub(crate) fn quote_settlement(
    this: &KipioEconomics,
    requested_capacity: U256,
    storage_quote: U256,
    service_id: u8,
) -> Result<U256, Vec<u8>> {
    let provider = this.service_registry.getter(service_id).get();
    if provider.is_zero() {
        return Err(UnsupportedService {}.abi_encode());
    }

    let fee = this.protocol_fee.get();
    let total = storage_quote + fee;

    if requested_capacity == U256::ZERO || total == U256::ZERO {
        return Err(InvalidPricingParameters {}.abi_encode());
    }

    Ok(total)
}

pub(crate) fn get_owner(this: &KipioEconomics) -> Address {
    this.owner.get()
}

pub(crate) fn get_cre_forwarder(this: &KipioEconomics) -> Address {
    this.cre_forwarder.get()
}

pub(crate) fn get_cre_workflow_id(this: &KipioEconomics) -> B256 {
    B256::from(this.cre_workflow_id.get().to_be_bytes())
}

pub(crate) fn get_protocol_fee(this: &KipioEconomics) -> U256 {
    this.protocol_fee.get()
}

pub(crate) fn get_max_protocol_fee(this: &KipioEconomics) -> U256 {
    this.max_protocol_fee.get()
}

pub(crate) fn get_available_credit(this: &KipioEconomics, account: Address) -> U256 {
    let now = this.vm().block_timestamp();
    U256::from(this.credit_module.available_credit(account, now))
}

pub(crate) fn get_withdrawable_refund(this: &KipioEconomics, account: Address) -> U256 {
    this.withdrawable_refunds.getter(account).get()
}

pub(crate) fn get_grant_remaining(this: &KipioEconomics, grant_id: B256) -> U256 {
    let packed = this.treasury_module.grant_allocations.getter(grant_id).get();
    U256::from(PackedAllocation::unpack(packed).remaining())
}

pub(crate) fn get_grant_expires_at(this: &KipioEconomics, grant_id: B256) -> u64 {
    this.treasury_module
        .grant_expirations
        .getter(grant_id)
        .get()
        .to::<u64>()
}

pub(crate) fn get_sponsor_remaining(this: &KipioEconomics, sponsor_id: B256) -> U256 {
    let packed = this
        .treasury_module
        .sponsor_allocations
        .getter(sponsor_id)
        .get();
    U256::from(PackedAllocation::unpack(packed).remaining())
}

pub(crate) fn get_treasury_reserves(this: &KipioEconomics) -> U256 {
    this.treasury_module.protocol_reserves.get()
}

pub(crate) fn get_provider(this: &KipioEconomics, service_id: u8) -> Address {
    this.service_registry.getter(service_id).get()
}

pub(crate) fn get_pending_settlement(this: &KipioEconomics, payment_id: B256) -> U256 {
    let packed = this.pending_settlements.getter(payment_id).get();
    U256::from(unpack_pending_settlement(packed).0)
}

pub(crate) fn get_pending_settlement_depositor(
    this: &KipioEconomics,
    payment_id: B256,
) -> Address {
    let packed = this.pending_settlements.getter(payment_id).get();
    unpack_pending_settlement(packed).1
}

pub(crate) fn get_pending_settlement_timestamp(
    this: &KipioEconomics,
    payment_id: B256,
) -> u32 {
    let packed = this.pending_settlements.getter(payment_id).get();
    unpack_pending_settlement(packed).2
}

pub(crate) fn is_paused(this: &KipioEconomics) -> bool {
    this.paused.get()
}

pub(crate) fn get_max_credit(this: &KipioEconomics) -> U256 {
    this.max_credit_per_account.get()
}

pub(crate) fn get_bootstrap_campaign(
    this: &KipioEconomics,
    campaign_id: B256,
) -> (U256, u32, u32, u64) {
    let packed = this.bootstrap_campaigns.getter(campaign_id).get();
    let campaign = BootstrapCampaign::unpack(packed);
    (
        U256::from(campaign.amount_per_beneficiary),
        campaign.max_beneficiaries,
        campaign.consumed_beneficiaries,
        campaign.expires_at,
    )
}

pub(crate) fn has_consumed_campaign(
    this: &KipioEconomics,
    campaign_id: B256,
    beneficiary: Address,
) -> bool {
    this.campaign_consumed
        .getter(campaign_id)
        .getter(beneficiary)
        .get()
}

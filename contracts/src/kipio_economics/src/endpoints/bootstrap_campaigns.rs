//! Bootstrap campaign handlers.
//!
//! A campaign reserves a fixed budget from the treasury at creation time and
//! distributes it to a bounded set of beneficiaries. This front-loads the
//! solvency check, so no `consume` call can ever revert due to missing funds.

use alloc::vec::Vec;

use stylus_sdk::alloy_primitives::{Address, B256, U256};
use stylus_sdk::alloy_sol_types::SolError;
use stylus_sdk::prelude::*;

use crate::abi::errors::{
    AlreadyProcessed, CampaignDepleted, CampaignExpired, GrantAlreadyExists,
    InvalidPricingParameters,
};
use crate::abi::events::{
    BootstrapCampaignClosed, BootstrapCampaignConsumed, BootstrapCampaignCreated,
};
use crate::codec::pack::BootstrapCampaign;
use crate::storage::entrypoint::KipioEconomics;

pub(crate) fn handle_create_bootstrap_campaign(
    this: &mut KipioEconomics,
    campaign_id: B256,
    amount_per_beneficiary: U256,
    max_beneficiaries: u32,
    duration_seconds: u64,
) -> Result<(), Vec<u8>> {
    this.require_owner()?;
    this.require_not_paused()?;

    if amount_per_beneficiary == U256::ZERO || max_beneficiaries == 0 {
        return Err(InvalidPricingParameters {}.abi_encode());
    }

    let existing = this.bootstrap_campaigns.getter(campaign_id).get();
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

    this.treasury_module.consume_treasury(total_required)?;

    let now = this.vm().block_timestamp();
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

    this.bootstrap_campaigns
        .setter(campaign_id)
        .set(campaign.pack());

    this.vm().log(BootstrapCampaignCreated {
        campaign_id,
        amount_per_beneficiary,
        max_beneficiaries,
        expires_at,
    });

    Ok(())
}

pub(crate) fn handle_consume_bootstrap_campaign(
    this: &mut KipioEconomics,
    campaign_id: B256,
    beneficiary: Address,
) -> Result<U256, Vec<u8>> {
    this.require_not_paused()?;

    let packed = this.bootstrap_campaigns.getter(campaign_id).get();
    let mut campaign = BootstrapCampaign::unpack(packed);

    if campaign.max_beneficiaries == 0 {
        return Err(CampaignDepleted {}.abi_encode());
    }

    let now = this.vm().block_timestamp();
    if campaign.is_expired(now) {
        return Err(CampaignExpired {}.abi_encode());
    }

    if campaign.is_depleted() {
        return Err(CampaignDepleted {}.abi_encode());
    }

    if this
        .campaign_consumed
        .getter(campaign_id)
        .getter(beneficiary)
        .get()
    {
        return Err(AlreadyProcessed {}.abi_encode());
    }

    // --- CEI: effects first ---
    this.campaign_consumed
        .setter(campaign_id)
        .setter(beneficiary)
        .set(true);

    campaign.consumed_beneficiaries += 1;
    this.bootstrap_campaigns
        .setter(campaign_id)
        .set(campaign.pack());

    // --- Interaction: credit the caller (pull-based) ---
    let amount = U256::from(campaign.amount_per_beneficiary);
    let caller = this.vm().msg_sender();
    this.credit_refund(caller, amount);

    this.vm().log(BootstrapCampaignConsumed {
        campaign_id,
        beneficiary,
        amount,
    });

    Ok(amount)
}

pub(crate) fn handle_close_bootstrap_campaign(
    this: &mut KipioEconomics,
    campaign_id: B256,
) -> Result<U256, Vec<u8>> {
    this.require_owner()?;
    this.require_not_paused()?;

    let packed = this.bootstrap_campaigns.getter(campaign_id).get();
    let campaign = BootstrapCampaign::unpack(packed);

    if campaign.max_beneficiaries == 0 {
        return Err(CampaignDepleted {}.abi_encode());
    }

    let remaining = campaign.remaining();
    let remaining_amount = U256::from(campaign.amount_per_beneficiary) * U256::from(remaining);

    this.bootstrap_campaigns
        .setter(campaign_id)
        .set(U256::ZERO);

    if remaining_amount > U256::ZERO {
        this.treasury_module.add_reserves(remaining_amount);
    }

    this.vm().log(BootstrapCampaignClosed {
        campaign_id,
        remaining: remaining_amount,
    });

    Ok(remaining_amount)
}

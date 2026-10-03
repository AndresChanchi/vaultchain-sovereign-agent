//! Native Arbitrum settlement handler.
//!
//! The funder is passed as an explicit parameter and validated through
//! `require_user_or_runtime(funder)`. The runtime orchestrator forwards
//! this call as part of a `dispatch` when the intent carries a settlement
//! payload. Direct callers (EOAs) invoke it with `msg_sender == funder`.
//!
//! All state transitions and cross-contract calls observe strict CEI
//! ordering. The storage cache is flushed before the external payment to
//! the provider so that a malicious provider cannot observe a stale
//! intermediate state.

use alloc::vec::Vec;

use stylus_sdk::alloy_primitives::{Address, U256};
use stylus_sdk::alloy_sol_types::{SolError, SolValue};
use stylus_sdk::prelude::*;

use crate::abi::errors::{
    InsufficientFunds, InvalidPricingParameters, InvalidSettlementPlan, UnsupportedService,
};
use crate::abi::events::{
    GrantConsumed, ProtocolFeeCollected, RefundIssued, SettlementExecuted, SponsoredExecution,
    SponsorConsumed, TreasuryConsumed,
};
use crate::codec::funding::FundingSource;
use crate::codec::pending::derive_payment_id;
use crate::kipio_shared::{EconomicReceipt, SettlementPlan};
use crate::storage::entrypoint::KipioEconomics;
use crate::storage::pricing::PricingModule;

pub(crate) fn handle_settle_economic_obligation(
    this: &mut KipioEconomics,
    funder: Address,
    plan_payload: Vec<u8>,
) -> Result<Vec<u8>, Vec<u8>> {
    this.require_not_paused()?;
    this.require_user_or_runtime(funder)?;

    let plan = SettlementPlan::abi_decode(&plan_payload)
        .map_err(|_| InvalidSettlementPlan {}.abi_encode())?;

    if plan.requested_capacity == U256::ZERO {
        return Err(InvalidPricingParameters {}.abi_encode());
    }

    // --- Anti-replay: validate and consume the nonce ---
    this.use_checked_nonce(funder, plan.nonce)?;

    let payment_id = derive_payment_id(funder, plan.nonce);

    let provider_address = this.service_registry.getter(plan.service_id).get();
    if provider_address.is_zero() {
        return Err(UnsupportedService {}.abi_encode());
    }

    if provider_address == this.vm().contract_address() {
        return Err(UnsupportedService {}.abi_encode());
    }

    let value_provided = this.vm().msg_value();
    let now = this.vm().block_timestamp();

    let current_fee = this.protocol_fee.get();
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
            this.credit_module.consume_credit(funder, credit_u128, now)?;
        },
        FundingSource::TreasurySponsored => {
            this.treasury_module.consume_treasury(estimated_cost)?;
            this.vm().log(TreasuryConsumed {
                beneficiary: funder,
                amount: estimated_cost,
            });
        },
        FundingSource::GrantSponsored(grant_id) => {
            this.treasury_module
                .consume_grant(grant_id, estimated_cost, now)?;
            this.vm().log(GrantConsumed {
                grant_id,
                beneficiary: funder,
                amount: estimated_cost,
            });
        },
        FundingSource::SponsorSponsored(sponsor_id) => {
            this.treasury_module
                .consume_sponsor(sponsor_id, estimated_cost)?;
            this.vm().log(SponsorConsumed {
                sponsor_id,
                beneficiary: funder,
                amount: estimated_cost,
            });
        },
    }

    if protocol_fee > U256::ZERO {
        this.treasury_module.add_reserves(protocol_fee);
        this.vm().log(ProtocolFeeCollected {
            funder,
            fee_amount: protocol_fee,
            service_id: plan.service_id,
            payment_id,
        });
    }

    if storage_quote > U256::ZERO {
        this.settle_payment(provider_address, storage_quote)?;
    }

    if value_provided > expected_native_value {
        let refund_amount = value_provided - expected_native_value;
        this.credit_refund(funder, refund_amount);
        this.vm().log(RefundIssued {
            account: funder,
            amount: refund_amount,
        });
    }

    let receipt = EconomicReceipt {
        funder,
        allocated_capacity: plan.requested_capacity,
        fee_paid: estimated_cost,
        service_id: plan.service_id,
        provider: provider_address,
        payment_id,
        nonce: plan.nonce,
    };

    this.vm().log(SettlementExecuted {
        funder,
        allocated_capacity: plan.requested_capacity,
        fee_paid: estimated_cost,
        payment_id,
        nonce: plan.nonce,
    });

    if plan.funding_source_id >= 2 {
        this.vm().log(SponsoredExecution {
            beneficiary: funder,
            source_id: plan.funding_source_id,
            amount: estimated_cost,
        });
    }

    Ok(receipt.abi_encode())
}

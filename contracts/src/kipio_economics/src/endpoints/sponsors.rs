//! Permissionless sponsor funding and treasury funding handlers.

use alloc::vec::Vec;

use stylus_sdk::alloy_primitives::{B256, U256};
use stylus_sdk::alloy_sol_types::SolError;
use stylus_sdk::prelude::*;

use crate::abi::errors::{InvalidPricingParameters, UnsupportedFundingSource, ZeroAmount};
use crate::abi::events::{SponsorRegistered, TreasuryFunded};
use crate::codec::pack::PackedAllocation;
use crate::storage::entrypoint::KipioEconomics;

pub(crate) fn handle_deposit_sponsor_funds(
    this: &mut KipioEconomics,
    sponsor_id: B256,
) -> Result<(), Vec<u8>> {
    this.require_not_paused()?;

    let amount = this.vm().msg_value();
    if amount == U256::ZERO {
        return Err(ZeroAmount {}.abi_encode());
    }

    if !this.treasury_module.sponsor_registry.getter(sponsor_id).get() {
        return Err(UnsupportedFundingSource {}.abi_encode());
    }

    let packed = this
        .treasury_module
        .sponsor_allocations
        .getter(sponsor_id)
        .get();
    let mut alloc = PackedAllocation::unpack(packed);
    let amount_u128: u128 = amount
        .try_into()
        .map_err(|_| InvalidPricingParameters {}.abi_encode())?;
    alloc.allocated = alloc.allocated.saturating_add(amount_u128);
    this.treasury_module
        .sponsor_allocations
        .setter(sponsor_id)
        .set(alloc.pack());

    this.vm().log(SponsorRegistered {
        sponsor_id,
        sponsor: this.vm().msg_sender(),
        amount,
    });
    Ok(())
}

pub(crate) fn handle_fund_treasury(this: &mut KipioEconomics) -> Result<(), Vec<u8>> {
    this.require_not_paused()?;

    let amount = this.vm().msg_value();
    if amount == U256::ZERO {
        return Err(ZeroAmount {}.abi_encode());
    }

    let sponsor = this.vm().msg_sender();
    this.treasury_module.add_reserves(amount);
    this.vm().log(TreasuryFunded { sponsor, amount });
    Ok(())
}

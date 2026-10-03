//! Permissionless sponsor funding and treasury funding handlers.
//!
//! Both endpoints accept the effective user as an explicit parameter and
//! validate the caller through `require_user_or_runtime(user)`. The user
//! is the sponsor of the deposit: for a direct call `msg_sender == user`,
//! for a forwarded call the runtime passes the effective user.

use alloc::vec::Vec;

use stylus_sdk::alloy_primitives::{Address, B256, U256};
use stylus_sdk::alloy_sol_types::SolError;
use stylus_sdk::prelude::*;

use crate::abi::errors::{InvalidPricingParameters, UnsupportedFundingSource, ZeroAmount};
use crate::abi::events::{SponsorRegistered, TreasuryFunded};
use crate::codec::pack::PackedAllocation;
use crate::storage::entrypoint::KipioEconomics;

pub(crate) fn handle_deposit_sponsor_funds(
    this: &mut KipioEconomics,
    user: Address,
    sponsor_id: B256,
) -> Result<(), Vec<u8>> {
    this.require_not_paused()?;
    this.require_user_or_runtime(user)?;

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
        sponsor: user,
        amount,
    });
    Ok(())
}

pub(crate) fn handle_fund_treasury(
    this: &mut KipioEconomics,
    user: Address,
) -> Result<(), Vec<u8>> {
    this.require_not_paused()?;
    this.require_user_or_runtime(user)?;

    let amount = this.vm().msg_value();
    if amount == U256::ZERO {
        return Err(ZeroAmount {}.abi_encode());
    }

    this.treasury_module.add_reserves(amount);
    this.vm().log(TreasuryFunded {
        sponsor: user,
        amount,
    });
    Ok(())
}

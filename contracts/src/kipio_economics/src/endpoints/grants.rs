//! Grants, bootstrap policy, and sponsor registration handlers (owner-only).

use alloc::vec::Vec;

use stylus_sdk::alloy_primitives::{Address, B256, U256};
use stylus_sdk::alloy_sol_types::SolError;
use stylus_sdk::prelude::*;

use crate::abi::errors::{
    GrantAlreadyExists, GrantExpiredError, InsufficientFunds, SponsorAlreadyExists,
};
use crate::abi::events::{GrantCreated, GrantExpired, SponsorRegistered};
use crate::codec::pack::PackedAllocation;
use crate::storage::entrypoint::KipioEconomics;

pub(crate) fn handle_create_grant(
    this: &mut KipioEconomics,
    grant_id: B256,
    amount: U256,
    duration_seconds: u64,
) -> Result<(), Vec<u8>> {
    this.require_owner()?;
    this.require_not_paused()?;

    let existing = this.treasury_module.grant_allocations.getter(grant_id).get();
    if existing != U256::ZERO {
        return Err(GrantAlreadyExists {}.abi_encode());
    }

    this.treasury_module.consume_treasury(amount)?;

    let amount_u128: u128 = amount
        .try_into()
        .map_err(|_| InsufficientFunds {}.abi_encode())?;

    let alloc = PackedAllocation {
        allocated: amount_u128,
        consumed: 0,
    };
    this.treasury_module
        .grant_allocations
        .setter(grant_id)
        .set(alloc.pack());

    let now = this.vm().block_timestamp();
    let expires_at = if duration_seconds > 0 {
        now + duration_seconds
    } else {
        0
    };
    this.treasury_module
        .grant_expirations
        .setter(grant_id)
        .set(U256::from(expires_at));

    this.vm().log(GrantCreated {
        grant_id,
        amount,
        expires_at,
    });
    Ok(())
}

pub(crate) fn handle_reclaim_expired_grant(
    this: &mut KipioEconomics,
    grant_id: B256,
) -> Result<U256, Vec<u8>> {
    this.require_owner()?;
    this.require_not_paused()?;

    let expires_at = this
        .treasury_module
        .grant_expirations
        .getter(grant_id)
        .get()
        .to::<u64>();

    if expires_at == 0 {
        return Err(GrantExpiredError {}.abi_encode());
    }

    let now = this.vm().block_timestamp();
    if now <= expires_at {
        return Err(GrantExpiredError {}.abi_encode());
    }

    let packed = this
        .treasury_module
        .grant_allocations
        .getter(grant_id)
        .get();
    let alloc = PackedAllocation::unpack(packed);
    let remaining = U256::from(alloc.remaining());

    this.treasury_module
        .grant_allocations
        .setter(grant_id)
        .set(U256::ZERO);
    this.treasury_module
        .grant_expirations
        .setter(grant_id)
        .set(U256::ZERO);

    this.treasury_module.add_reserves(remaining);

    this.vm().log(GrantExpired {
        grant_id,
        remaining_amount: remaining,
    });

    Ok(remaining)
}

pub(crate) fn handle_set_bootstrap_policy(
    this: &mut KipioEconomics,
    enabled: bool,
    amount: U256,
) -> Result<(), Vec<u8>> {
    this.require_owner()?;
    this.require_not_paused()?;
    this.treasury_module
        .bootstrap_sponsorship_enabled
        .set(enabled);
    this.treasury_module.bootstrap_subsidy_amount.set(amount);
    Ok(())
}

pub(crate) fn handle_register_sponsor_governance(
    this: &mut KipioEconomics,
    sponsor_id: B256,
    sponsor_address: Address,
) -> Result<(), Vec<u8>> {
    this.require_owner()?;
    this.require_not_paused()?;

    if this.treasury_module.sponsor_registry.getter(sponsor_id).get() {
        return Err(SponsorAlreadyExists {}.abi_encode());
    }

    this.treasury_module
        .sponsor_registry
        .setter(sponsor_id)
        .set(true);

    this.vm().log(SponsorRegistered {
        sponsor_id,
        sponsor: sponsor_address,
        amount: U256::ZERO,
    });

    Ok(())
}

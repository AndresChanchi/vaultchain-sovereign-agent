//! Treasury subdomain.
//!
//! Treasury coordinates protocol-owned economic resources. It is funded
//! permissionlessly via `fund_treasury()` and via the protocol fee, and it
//! is consumed for bootstrap subsidies and grants. It does not participate
//! in identity, ownership, or custody.

use alloc::vec::Vec;

use stylus_sdk::alloy_primitives::{B256, U256};
use stylus_sdk::alloy_sol_types::SolError;
use stylus_sdk::prelude::*;
use stylus_sdk::storage::{StorageBool, StorageMap, StorageU256};

use crate::abi::errors::{
    GrantDepleted, GrantExpiredError, InsufficientFunds, InvalidPricingParameters,
    SponsorDepleted, TreasuryDepleted, Unauthorized, UnsupportedFundingSource,
};
use crate::codec::pack::PackedAllocation;

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

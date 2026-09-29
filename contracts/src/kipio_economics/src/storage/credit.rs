//! Credit subdomain.
//!
//! Credit is reusable purchasing capacity. It is NOT interest-bearing,
//! NOT an investment, and NOT a custodial account. Its sole purpose is to
//! reduce friction for repeated interactions.

use alloc::vec::Vec;

use stylus_sdk::alloy_primitives::{Address, U256};
use stylus_sdk::alloy_sol_types::SolError;
use stylus_sdk::prelude::*;
use stylus_sdk::storage::{StorageMap, StorageU256};

use crate::abi::errors::{
    CreditExpiredError, CreditNotExpired, InsufficientFunds, ZeroAmount,
};
use crate::codec::pack::CreditEntry;

#[storage]
pub struct CreditModule {
    /// Map: `account => packed CreditEntry (amount | expires_at)`.
    pub(crate) entries: StorageMap<Address, StorageU256>,
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

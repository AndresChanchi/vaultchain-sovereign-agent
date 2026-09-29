//! Credit deposit and withdrawal handlers, plus pull-based refunds.

use alloc::vec::Vec;

use stylus_sdk::alloy_primitives::U256;
use stylus_sdk::alloy_sol_types::SolError;
use stylus_sdk::prelude::*;

use crate::abi::errors::{InvalidPricingParameters, MaxCreditExceeded, ZeroAmount};
use crate::abi::events::{CreditDeposited, CreditWithdrawn, RefundWithdrawn};
use crate::storage::entrypoint::KipioEconomics;

pub(crate) fn handle_deposit_credit(this: &mut KipioEconomics) -> Result<(), Vec<u8>> {
    this.require_not_paused()?;

    let amount = this.vm().msg_value();
    if amount == U256::ZERO {
        return Err(ZeroAmount {}.abi_encode());
    }

    let amount_u128: u128 = amount
        .try_into()
        .map_err(|_| InvalidPricingParameters {}.abi_encode())?;

    let account = this.vm().msg_sender();
    let now = this.vm().block_timestamp();

    let max_credit = this.max_credit_per_account.get();
    if max_credit > U256::ZERO {
        let current = U256::from(this.credit_module.available_credit(account, now));
        if current + amount > max_credit {
            return Err(MaxCreditExceeded {}.abi_encode());
        }
    }

    let expires_at = now + 90 * 24 * 60 * 60; // 90 days

    this.credit_module
        .add_credit(account, amount_u128, expires_at, now);

    this.vm().log(CreditDeposited {
        account,
        amount,
        expires_at,
    });
    Ok(())
}

pub(crate) fn handle_withdraw_credit(this: &mut KipioEconomics) -> Result<(), Vec<u8>> {
    let account = this.vm().msg_sender();
    let now = this.vm().block_timestamp();

    let amount = this.credit_module.withdraw_expired(account, now)?;
    let amount_u256 = U256::from(amount);

    this.settle_payment(account, amount_u256)?;
    this.vm().log(CreditWithdrawn {
        account,
        amount: amount_u256,
    });
    Ok(())
}

pub(crate) fn handle_withdraw_refund(this: &mut KipioEconomics) -> Result<(), Vec<u8>> {
    let account = this.vm().msg_sender();
    let amount = this.withdrawable_refunds.getter(account).get();

    if amount == U256::ZERO {
        return Err(ZeroAmount {}.abi_encode());
    }

    this.withdrawable_refunds.setter(account).set(U256::ZERO);
    this.settle_payment(account, amount)?;

    this.vm().log(RefundWithdrawn { account, amount });
    Ok(())
}

//! Policy ledger whitelist handlers.
//!
//! `kipio_identity_content` and future consumers read the whitelist on
//! every policy-driven operation. Revoking a ledger takes effect
//! immediately on the next call.

use alloc::vec::Vec;

use stylus_sdk::{alloy_primitives::Address, alloy_sol_types::SolError, prelude::*};

use crate::abi::errors::ZeroAddress;
use crate::abi::events::LedgerAuthorizationUpdated;
use crate::storage::entrypoint::KipioProtocolConfig;

pub(crate) fn handle_set_authorized_ledger(
    this: &mut KipioProtocolConfig,
    ledger: Address,
    authorized: bool,
) -> Result<(), Vec<u8>> {
    this.require_owner()?;
    this.require_not_paused()?;

    if ledger == Address::ZERO {
        return Err(ZeroAddress {}.abi_encode());
    }

    this.authorized_ledgers.setter(ledger).set(authorized);
    this.vm().log(LedgerAuthorizationUpdated {
        ledger,
        authorized,
    });
    Ok(())
}

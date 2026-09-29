//! Owner-only governance handlers: registry, fee policy, forwarder, pause.

use alloc::vec::Vec;

use stylus_sdk::alloy_primitives::{Address, B256, U256};
use stylus_sdk::alloy_sol_types::SolError;
use stylus_sdk::prelude::*;

use crate::abi::errors::{FeeExceedsMaximum, UnauthorizedForwarder, UnsupportedService};
use crate::abi::events::{
    BootstrapDepleted, BootstrapSponsored, CreForwarderUpdated, CreWorkflowUpdated,
    MaxCreditUpdated, MaxProtocolFeeUpdated, Paused, ProtocolFeePolicyUpdated,
    ServiceRegistryUpdated, Unpaused,
};
use crate::storage::entrypoint::KipioEconomics;

pub(crate) fn handle_update_service_registry(
    this: &mut KipioEconomics,
    service_id: u8,
    provider_address: Address,
) -> Result<(), Vec<u8>> {
    this.require_owner()?;

    if provider_address.is_zero() {
        return Err(UnsupportedService {}.abi_encode());
    }

    this.service_registry
        .setter(service_id)
        .set(provider_address);
    this.vm().log(ServiceRegistryUpdated {
        service_id,
        provider_address,
    });
    Ok(())
}

pub(crate) fn handle_update_protocol_fee(
    this: &mut KipioEconomics,
    new_fee: U256,
) -> Result<(), Vec<u8>> {
    this.require_owner()?;
    if new_fee > this.max_protocol_fee.get() {
        return Err(FeeExceedsMaximum {}.abi_encode());
    }
    this.protocol_fee.set(new_fee);
    this.vm().log(ProtocolFeePolicyUpdated { fee_amount: new_fee });
    Ok(())
}

pub(crate) fn handle_update_max_protocol_fee(
    this: &mut KipioEconomics,
    new_max: U256,
) -> Result<(), Vec<u8>> {
    this.require_owner()?;
    this.max_protocol_fee.set(new_max);
    this.vm().log(MaxProtocolFeeUpdated { max_fee: new_max });
    Ok(())
}

pub(crate) fn handle_update_cre_forwarder(
    this: &mut KipioEconomics,
    new_forwarder: Address,
) -> Result<(), Vec<u8>> {
    this.require_owner()?;

    if new_forwarder.is_zero() {
        return Err(UnauthorizedForwarder {}.abi_encode());
    }

    let old = this.cre_forwarder.get();
    this.cre_forwarder.set(new_forwarder);
    this.vm().log(CreForwarderUpdated {
        old_forwarder: old,
        new_forwarder,
    });
    Ok(())
}

pub(crate) fn handle_update_cre_workflow_id(
    this: &mut KipioEconomics,
    new_workflow_id: B256,
) -> Result<(), Vec<u8>> {
    this.require_owner()?;
    let old = this.cre_workflow_id.get();
    this.cre_workflow_id
        .set(U256::from_be_bytes(new_workflow_id.0));
    this.vm().log(CreWorkflowUpdated {
        old_workflow_id: B256::from(old.to_be_bytes()),
        new_workflow_id,
    });
    Ok(())
}

pub(crate) fn handle_update_max_credit(
    this: &mut KipioEconomics,
    new_max: U256,
) -> Result<(), Vec<u8>> {
    this.require_owner()?;
    this.max_credit_per_account.set(new_max);
    this.vm().log(MaxCreditUpdated { max_credit: new_max });
    Ok(())
}

pub(crate) fn handle_pause(this: &mut KipioEconomics) -> Result<(), Vec<u8>> {
    this.require_owner()?;
    this.paused.set(true);
    this.vm().log(Paused {
        account: this.vm().msg_sender(),
    });
    Ok(())
}

pub(crate) fn handle_unpause(this: &mut KipioEconomics) -> Result<(), Vec<u8>> {
    this.require_owner()?;
    this.paused.set(false);
    this.vm().log(Unpaused {
        account: this.vm().msg_sender(),
    });
    Ok(())
}

/// Subsidizes a bootstrap operation from the global treasury budget.
///
/// Returns `(false, 0)` when the subsidy is disabled or the treasury is
/// depleted. This never reverts on missing funds because callers (like the
/// execution gateway) treat sponsorship as a best-effort attempt, not a hard
/// requirement.
pub(crate) fn handle_fund_bootstrap(
    this: &mut KipioEconomics,
    beneficiary: Address,
) -> Result<(bool, U256), Vec<u8>> {
    let subsidy = this.treasury_module.bootstrap_subsidy_amount.get();
    if subsidy == U256::ZERO {
        return Ok((false, U256::ZERO));
    }

    if !this.treasury_module.bootstrap_sponsorship_enabled.get() {
        return Ok((false, U256::ZERO));
    }

    match this.treasury_module.consume_treasury(subsidy) {
        Ok(()) => {
            this.vm().log(BootstrapSponsored {
                beneficiary,
                amount: subsidy,
            });
            let caller = this.vm().msg_sender();
            this.credit_refund(caller, subsidy);
            Ok((true, subsidy))
        },
        Err(_) => {
            this.vm().log(BootstrapDepleted);
            Ok((false, U256::ZERO))
        },
    }
}

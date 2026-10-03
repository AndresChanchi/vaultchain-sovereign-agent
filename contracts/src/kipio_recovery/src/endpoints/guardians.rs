//! Guardian configuration handlers.

use alloc::vec::Vec;

use stylus_sdk::{
    alloy_primitives::{Address, B256, U64},
    alloy_sol_types::SolError,
    prelude::*,
};

use crate::abi::errors::{
    GuardiansAlreadyConfigured, GuardiansNotConfigured, InvalidUpdateReason,
};
use crate::abi::events::{GuardiansConfigured, GuardiansUpdated};
use crate::storage::entrypoint::KipioRecovery;

pub(crate) fn handle_set_guardians(
    this: &mut KipioRecovery,
    account: Address,
    guardian_types: Vec<u8>,
    guardian_identifiers: Vec<B256>,
    guardian_curves: Vec<u8>,
    threshold: u8,
) -> Result<(), Vec<u8>> {
    this.require_runtime()?;
    this.require_initialized()?;

    if this.guardian_versions.getter(account).get() != U64::ZERO {
        return Err(GuardiansAlreadyConfigured {}.abi_encode());
    }

    let count = guardian_types.len() as u8;

    // reason = 0 for initial configuration.
    this.write_guardian_version(
        account,
        U64::from(1u64),
        &guardian_types,
        &guardian_identifiers,
        &guardian_curves,
        threshold,
        0,
    )?;

    this.guardian_versions.setter(account).set(U64::from(1u64));

    this.vm().log(GuardiansConfigured {
        account,
        version: 1,
        count,
        threshold,
    });
    Ok(())
}

pub(crate) fn handle_update_guardians(
    this: &mut KipioRecovery,
    account: Address,
    guardian_types: Vec<u8>,
    guardian_identifiers: Vec<B256>,
    guardian_curves: Vec<u8>,
    threshold: u8,
    reason: u8,
) -> Result<(), Vec<u8>> {
    this.require_runtime()?;
    this.require_initialized()?;

    if !(1..=6).contains(&reason) {
        return Err(InvalidUpdateReason {}.abi_encode());
    }

    this.ensure_no_active_recovery(account)?;

    let current = this.guardian_versions.getter(account).get();
    if current == U64::ZERO {
        return Err(GuardiansNotConfigured {}.abi_encode());
    }

    let new_version = current + U64::from(1u64);
    let count = guardian_types.len() as u8;

    this.write_guardian_version(
        account,
        new_version,
        &guardian_types,
        &guardian_identifiers,
        &guardian_curves,
        threshold,
        reason,
    )?;

    this.guardian_versions.setter(account).set(new_version);

    this.vm().log(GuardiansUpdated {
        account,
        version: new_version.to::<u64>(),
        count,
        threshold,
        reason,
    });
    Ok(())
}

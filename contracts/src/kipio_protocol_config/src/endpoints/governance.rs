//! Ownership and circuit-breaker handlers.

use alloc::vec::Vec;

use stylus_sdk::{
    alloy_primitives::{Address, B256},
    alloy_sol_types::SolError,
    prelude::*,
};

use crate::abi::errors::{NoPendingOwner, Unauthorized, ZeroOwner};
use crate::abi::events::{
    OwnershipTransferStarted, OwnershipTransferred, Paused, Unpaused,
};
use crate::storage::entrypoint::KipioProtocolConfig;

pub(crate) fn handle_transfer_ownership(
    this: &mut KipioProtocolConfig,
    new_owner: Address,
) -> Result<(), Vec<u8>> {
    this.require_owner()?;

    if new_owner == Address::ZERO {
        return Err(ZeroOwner {}.abi_encode());
    }

    let current = this.owner.get();
    this.pending_owner.set(new_owner);

    this.vm().log(OwnershipTransferStarted {
        currentOwner: current,
        pendingOwner: new_owner,
    });

    Ok(())
}

pub(crate) fn handle_accept_ownership(
    this: &mut KipioProtocolConfig,
) -> Result<(), Vec<u8>> {
    let sender = this.vm().msg_sender();
    let pending = this.pending_owner.get();

    if pending == Address::ZERO {
        return Err(NoPendingOwner {}.abi_encode());
    }
    if sender != pending {
        return Err(Unauthorized {}.abi_encode());
    }

    let previous = this.owner.get();
    this.owner.set(pending);
    this.pending_owner.set(Address::ZERO);

    this.vm().log(OwnershipTransferred {
        previousOwner: previous,
        newOwner: pending,
    });

    Ok(())
}

/// Pauses the registry.
///
/// While paused, every mutating endpoint except `transfer_ownership` and
/// `accept_ownership` reverts. Reads stay available. The reason hash is
/// emitted for off-chain correlation.
pub(crate) fn handle_pause(
    this: &mut KipioProtocolConfig,
    reason_hash: B256,
) -> Result<(), Vec<u8>> {
    this.require_owner()?;
    if this.paused.get() {
        return Ok(());
    }
    this.paused.set(true);
    this.pause_reason_hash.set(reason_hash);
    this.vm().log(Paused {
        by: this.vm().msg_sender(),
        reasonHash: reason_hash,
    });
    Ok(())
}

pub(crate) fn handle_unpause(this: &mut KipioProtocolConfig) -> Result<(), Vec<u8>> {
    this.require_owner()?;
    if !this.paused.get() {
        return Ok(());
    }
    this.paused.set(false);
    this.pause_reason_hash.set(B256::ZERO);
    this.vm().log(Unpaused {
        by: this.vm().msg_sender(),
    });
    Ok(())
}

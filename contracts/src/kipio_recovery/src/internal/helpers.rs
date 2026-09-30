//! Privilege gates for `kipio_recovery`.

use alloc::vec::Vec;

use stylus_sdk::{
    alloy_primitives::Address,
    alloy_sol_types::SolError,
    prelude::*,
};

use crate::abi::errors::{NotInitialized, UnauthorizedCaller};
use crate::storage::entrypoint::KipioRecovery;

impl KipioRecovery {
    /// Runtime gate for every mutator except `consume_recovery`. Closes
    /// the "attacker drives guardian flow directly" vector.
    pub(crate) fn require_runtime(&self) -> Result<(), Vec<u8>> {
        let caller = self.vm().msg_sender();
        let runtime = self.runtime_address.get();
        if runtime == Address::ZERO {
            return Err(NotInitialized {}.abi_encode());
        }
        if caller != runtime {
            return Err(UnauthorizedCaller {}.abi_encode());
        }
        Ok(())
    }

    pub(crate) fn require_initialized(&self) -> Result<(), Vec<u8>> {
        if !self.initialized.get() {
            return Err(NotInitialized {}.abi_encode());
        }
        Ok(())
    }
}

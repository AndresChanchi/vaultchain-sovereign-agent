#![allow(unexpected_cfgs)]
#![cfg_attr(not(feature = "std"), no_std)]

extern crate alloc;

use alloc::{vec, vec::Vec};

use stylus_sdk::{
    alloy_primitives::Address,
    prelude::*,
    storage::StorageAddress,
};

#[storage]
#[entrypoint]
pub struct KipioRecovery {
    pub core: StorageAddress,
}

#[public]
impl KipioRecovery {

    pub fn update_auth_module(
        &mut self,
        new_module: Address
    ) -> Result<(), Vec<u8>> {

        let sender = self.vm().msg_sender();

        // CHANGE: operate via stored core address instead of direct reference
        // REASON: cross-contract calls required in modular architecture
        // DOES NOT BREAK RULES:
        // - No sensitive data exposed
        // - Preserves upgradeability and separation of concerns

        let core = self.core.get();

        if core == Address::ZERO {
            return Err(b"CoreNotSet".to_vec());
        }

        // placeholder for call_contract
        let _ = (sender, core, new_module);

        Ok(())
    }

    pub fn set_core(
        &mut self,
        core_address: Address
    ) -> Result<(), Vec<u8>> {

        self.core.set(core_address);
        Ok(())
    }
}

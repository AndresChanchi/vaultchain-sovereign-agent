//! Constructor handler.

use alloc::vec::Vec;

use stylus_sdk::{
    alloy_primitives::Address,
    alloy_sol_types::SolError,
};

use crate::abi::errors::ZeroRuntime;
use crate::storage::entrypoint::KipioRecovery;

pub(crate) fn handle_constructor(
    this: &mut KipioRecovery,
    runtime: Address,
) -> Result<(), Vec<u8>> {
    if runtime == Address::ZERO {
        return Err(ZeroRuntime {}.abi_encode());
    }
    this.runtime_address.set(runtime);
    this.initialized.set(true);
    Ok(())
}

//! Constructor handler.

use alloc::vec::Vec;

use stylus_sdk::{alloy_primitives::Address, alloy_sol_types::SolError, prelude::*};

use crate::abi::errors::ZeroOwner;
use crate::storage::entrypoint::KipioProtocolConfig;

/// Sets the initial owner of the registry.
///
/// Uses `tx_origin` (not `msg_sender`) because the Stylus deployer is an
/// intermediate contract in the deployment pipeline. The `tx_origin` is
/// the EOA that signed the deployment transaction, which is the protocol
/// maintainer.
pub(crate) fn handle_constructor(this: &mut KipioProtocolConfig) -> Result<(), Vec<u8>> {
    let deployer = this.vm().tx_origin();
    if deployer == Address::ZERO {
        return Err(ZeroOwner {}.abi_encode());
    }
    this.owner.set(deployer);
    Ok(())
}

//! Constructor handler.

use alloc::vec::Vec;

use stylus_sdk::{
    alloy_primitives::Address,
    alloy_sol_types::SolError,
    prelude::*,
};

use crate::abi::errors::ProtocolConfigNotSet;
use crate::abi::events::RuntimeDeployed;
use crate::storage::entrypoint::KipioRuntime;

pub(crate) fn handle_constructor(
    this: &mut KipioRuntime,
    protocol_config: Address,
) -> Result<(), Vec<u8>> {
    if protocol_config == Address::ZERO {
        return Err(ProtocolConfigNotSet {}.abi_encode());
    }
    this.protocol_config.set(protocol_config);
    this.vm().log(RuntimeDeployed {
        protocolConfig: protocol_config,
    });
    Ok(())
}

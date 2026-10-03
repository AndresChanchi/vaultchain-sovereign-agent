//! Constructor handler.
//!
//! Records the Gateway's own address in storage and emits the deployment
//! event. The self-address is read by `is_eip7702_context` and
//! `predict_from_salt`, so it must be set before any other endpoint runs.

use alloc::vec::Vec;

use stylus_sdk::prelude::*;

use crate::abi::events::GatewayDeployed;
use crate::config::constants::SALT_SCHEME_VERSION;
use crate::storage::entrypoint::KipioExecutionGateway;

pub(crate) fn handle_constructor(
    this: &mut KipioExecutionGateway,
) -> Result<(), Vec<u8>> {
    this.self_address.set(this.vm().contract_address());
    this.vm().log(GatewayDeployed {
        version: SALT_SCHEME_VERSION,
    });
    Ok(())
}

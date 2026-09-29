//! Deployment-time initialization handler.

use alloc::vec::Vec;

use stylus_sdk::alloy_primitives::{Address, B256, U256};
use stylus_sdk::alloy_sol_types::SolError;
use stylus_sdk::prelude::*;

use crate::abi::errors::UnauthorizedForwarder;
use crate::abi::events::EconomicsDeployed;
use crate::storage::entrypoint::KipioEconomics;

pub(crate) fn handle_constructor(
    this: &mut KipioEconomics,
    cre_forwarder: Address,
    cre_workflow_id: B256,
) -> Result<(), Vec<u8>> {
    if cre_forwarder.is_zero() {
        return Err(UnauthorizedForwarder {}.abi_encode());
    }

    let deployer = this.vm().tx_origin();
    this.owner.set(deployer);
    this.cre_forwarder.set(cre_forwarder);
    this.cre_workflow_id
        .set(U256::from_be_bytes(cre_workflow_id.0));
    this.protocol_fee.set(U256::ZERO);
    this.max_protocol_fee
        .set(U256::from(100_000_000_000_000_000u128)); // 0.1 ETH default cap
    this.paused.set(false);
    this.max_credit_per_account.set(U256::ZERO);

    this.vm().log(EconomicsDeployed {
        owner: deployer,
        cre_forwarder,
    });

    Ok(())
}

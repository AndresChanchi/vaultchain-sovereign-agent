//! `self_deploy` handler — deploys an account with the Gateway as the
//! `CREATE2` deployer.

use alloc::vec::Vec;

use stylus_sdk::{
    alloy_primitives::{Address, B256, U256},
    alloy_sol_types::SolError,
    deploy::RawDeploy,
    prelude::*,
};

use crate::abi::errors::BootstrapDeploymentFailed;
use crate::abi::events::SelfDeployExecuted;
use crate::internal::deploy::ACCOUNT_INIT_CODE;
use crate::storage::entrypoint::KipioExecutionGateway;

pub(crate) fn handle_self_deploy(
    this: &mut KipioExecutionGateway,
    salt: B256,
) -> Result<Address, Vec<u8>> {
    let deployer = RawDeploy::new().salt(salt);
    let result = unsafe { deployer.deploy(this.vm(), ACCOUNT_INIT_CODE, U256::ZERO) };
    let addr = result.map_err(|_| BootstrapDeploymentFailed {}.abi_encode())?;
    this.vm().log(SelfDeployExecuted { account: addr, salt });
    Ok(addr)
}

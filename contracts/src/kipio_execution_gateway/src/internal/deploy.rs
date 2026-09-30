//! Account deployment primitives.
//!
//! `ACCOUNT_INIT_CODE` is the compiled WASM of `kipio_account`. It is
//! produced by the build pipeline and included at compile time when the
//! `production_build` feature is enabled. Without that feature, the
//! constant is empty and the Gateway cannot deploy accounts, which is the
//! expected behaviour for tests.
//!
//! The init code contains only the WASM runtime. Constructor arguments are
//! passed separately, as an ABI-encoded call to the constructor entrypoint
//! after activation.

use alloc::vec::Vec;

use stylus_sdk::{
    alloy_primitives::{Address, B256, U256},
    alloy_sol_types::SolError,
    call::RawCall,
    deploy::RawDeploy,
    prelude::*,
};

use crate::abi::errors::BootstrapDeploymentFailed;
use crate::storage::entrypoint::KipioExecutionGateway;

#[cfg(feature = "production_build")]
pub(crate) const ACCOUNT_INIT_CODE: &[u8] =
    include_bytes!(concat!(env!("OUT_DIR"), "/kipio_account_init.bin"));

#[cfg(not(feature = "production_build"))]
pub(crate) const ACCOUNT_INIT_CODE: &[u8] = &[];

impl KipioExecutionGateway {
    /// Detects whether execution is happening in an EIP-7702 context.
    ///
    /// Under a direct call, `contract_address()` is the Gateway. Under
    /// EIP-7702, the delegated code runs in the EOA's context, so
    /// `contract_address()` returns the EOA.
    ///
    /// This check is O(1) and avoids reading the full WASM bytecode.
    #[inline]
    pub(crate) fn is_eip7702_context(&self) -> bool {
        self.vm().contract_address() != self.self_address.get()
    }

    /// Predicts a `CREATE2` address using the Gateway as the deployer.
    #[inline]
    pub(crate) fn predict_from_salt(&self, salt: B256) -> Address {
        let init_code_hash = alloy_primitives::keccak256(ACCOUNT_INIT_CODE);

        let mut buffer = [0u8; 85];
        buffer[0] = 0xff;
        buffer[1..21].copy_from_slice(self.self_address.get().as_slice());
        buffer[21..53].copy_from_slice(salt.as_slice());
        buffer[53..85].copy_from_slice(init_code_hash.as_slice());

        let hash = alloy_primitives::keccak256(&buffer);
        Address::from_slice(&hash[12..32])
    }

    /// Deploys the account. Under EIP-7702, performs a self-call to
    /// `self_deploy` so that `CREATE2` uses the Gateway as the deployer.
    ///
    /// The self-call goes through `RawCall` because the high-level `Call`
    /// builder is designed for cross-contract calls with typed interfaces;
    /// a self-call with a manually constructed selector needs the raw
    /// primitive.
    pub(crate) fn deploy_account(&mut self, salt: B256) -> Result<Address, Vec<u8>> {
        if self.is_eip7702_context() {
            let self_addr = self.self_address.get();

            // Selector: keccak256("self_deploy(bytes32)")[0..4]
            let selector = alloy_primitives::keccak256(b"self_deploy(bytes32)");
            let mut call_data = Vec::with_capacity(36);
            call_data.extend_from_slice(&selector[0..4]);
            call_data.extend_from_slice(salt.as_slice());

            let host = self.vm();
            match unsafe { RawCall::new(host).call(self_addr, &call_data) } {
                Ok(return_data) if return_data.len() >= 32 => {
                    Ok(Address::from_slice(&return_data[12..32]))
                }
                _ => Err(BootstrapDeploymentFailed {}.abi_encode()),
            }
        } else {
            let deployer = RawDeploy::new().salt(salt);
            unsafe { deployer.deploy(self.vm(), ACCOUNT_INIT_CODE, U256::ZERO) }
                .map_err(|_| BootstrapDeploymentFailed {}.abi_encode())
        }
    }
}

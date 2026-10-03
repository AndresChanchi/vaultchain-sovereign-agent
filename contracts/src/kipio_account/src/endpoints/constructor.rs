//! Constructor handler for `kipio_account`.

use alloc::vec::Vec;

use kipio_account_bridge::{
    AuthorizationStateAbi, ZeroIdentity, ZeroRecovery, ZeroRuntime,
};
use stylus_sdk::{
    alloy_primitives::Address,
    alloy_sol_types::{SolError, SolValue},
};

use crate::storage::entrypoint::KipioAccount;

pub(crate) fn handle_constructor(
    this: &mut KipioAccount,
    identity: Address,
    runtime: Address,
    recovery: Address,
) -> Result<(), Vec<u8>> {
    if identity == Address::ZERO {
        return Err(ZeroIdentity {}.abi_encode());
    }
    if runtime == Address::ZERO {
        return Err(ZeroRuntime {}.abi_encode());
    }
    if recovery == Address::ZERO {
        return Err(ZeroRecovery {}.abi_encode());
    }
    this.identity_id.set(identity);
    this.runtime_address.set(runtime);
    this.recovery_address.set(recovery);
    this.initialized.set(true);

    let empty_state = AuthorizationStateAbi {
        capabilities: vec![],
        credentials: vec![],
        credentialAuthorities: vec![],
        sessions: vec![],
        delegations: vec![],
        delegationProvenance: vec![],
        restrictionMap: vec![],
        policyEffects: vec![],
        consumedReplayKeys: vec![],
    };
    this.auth_state.set_bytes(&empty_state.abi_encode());
    Ok(())
}

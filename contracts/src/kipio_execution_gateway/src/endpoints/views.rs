//! Read-only views of the Gateway.

use stylus_sdk::alloy_primitives::{Address, B256};

use crate::config::constants::{
    KIPIO_ECONOMICS, KIPIO_RECOVERY, KIPIO_RUNTIME, SALT_SCHEME_VERSION,
};
use crate::storage::entrypoint::KipioExecutionGateway;

/// Returns the `CREATE2` salt for a given identity.
pub(crate) fn salt_for(identity: Address) -> B256 {
    let mut salt = [0u8; 32];
    salt[0] = SALT_SCHEME_VERSION;
    salt[12..32].copy_from_slice(identity.as_slice());
    B256::from(salt)
}

/// Predicts the sovereign account address for an identity.
pub(crate) fn predict_account(this: &KipioExecutionGateway, identity: Address) -> Address {
    this.predict_from_salt(salt_for(identity))
}

/// Returns the protocol addresses this Gateway is bound to.
pub(crate) fn protocol_addresses() -> (Address, Address, Address, u8) {
    (
        KIPIO_RUNTIME,
        KIPIO_ECONOMICS,
        KIPIO_RECOVERY,
        SALT_SCHEME_VERSION,
    )
}

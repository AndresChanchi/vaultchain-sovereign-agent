//! Root storage struct for the Gateway.

use stylus_sdk::prelude::*;
use stylus_sdk::storage::StorageAddress;

#[storage]
#[entrypoint]
pub struct KipioExecutionGateway {
    /// @dev The Gateway's own address, captured at construction time.
    ///      This is the authoritative source for the `CREATE2` deployer and
    ///      for the EIP-7702 context check. Reading it from storage avoids
    ///      any dependency on tooling-substituted constants for the most
    ///      security-critical check in the contract.
    pub(crate) self_address: StorageAddress,
}

//! Root storage struct for the runtime.

use stylus_sdk::prelude::*;
use stylus_sdk::storage::StorageAddress;

#[storage]
#[entrypoint]
pub struct KipioRuntime {
    /// @notice Address of the protocol configuration registry.
    ///
    /// Set once at construction. The registry is immutable in the sense
    /// that the runtime never overwrites its address; individual module
    /// addresses are read through it on every dispatch.
    pub(crate) protocol_config: StorageAddress,
}

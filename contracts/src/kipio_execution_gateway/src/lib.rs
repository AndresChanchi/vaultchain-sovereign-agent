#![cfg_attr(not(any(test, feature = "export-abi")), no_main)]

extern crate alloc;

pub mod abi;
pub mod config;
pub mod endpoints;
pub mod internal;
pub mod storage;

// Re-export the shared domain boundary under the original `kipio_shared`
// name so external consumers can import it without depending on the
// internal `abi::interfaces` layout.
pub use abi::interfaces as kipio_shared;

// Re-export the entrypoint so `print_from_args` is reachable at the crate
// root for the ABI export binary.
pub use storage::entrypoint::*;

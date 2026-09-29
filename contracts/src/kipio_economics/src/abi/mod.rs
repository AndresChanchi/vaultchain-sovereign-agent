//! ABI surface of `kipio_economics`.
//!
//! Split into three concerns:
//!
//! - [`interfaces`]: shared structs consumed by `kipio_execution_gateway`
//!   and `kipio_runtime`.
//! - [`events`]: indexed events for off-chain indexers and audit trails.
//! - [`errors`]: custom errors returned as ABI-encoded revert data.

pub mod errors;
pub mod events;
pub mod interfaces;

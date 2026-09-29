//! Storage structs and their impls.
//!
//! Each subdomain owns its own storage layout. The root struct aggregates
//! them and lives in [`entrypoint`].

pub mod credit;
pub mod entrypoint;
pub mod pricing;
pub mod treasury;

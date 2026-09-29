#![allow(unexpected_cfgs)]
#![cfg_attr(not(feature = "std"), no_std)]

//! # Kipio Economics
//!
//! Economic coordination layer for the Kipio protocol.
//!
//! This contract answers exactly one question: has the required economic
//! obligation been satisfied for a given operation? It does not authenticate
//! users (that belongs to the identity domain), does not custody assets (the
//! treasury is protocol-owned, not user-owned), and does not decide policy.
//!
//! ## Module layout
//!
//! - [`abi`] — ABI surface: shared structs, events, and errors.
//! - [`codec`] — Pure encoding/decoding helpers and bit-packing layouts.
//! - [`config`] — Protocol-wide constants.
//! - [`endpoints`] — Public entrypoints (single `#[public]` block) and the
//!   per-domain handlers they delegate to.
//! - [`internal`] — Private helpers shared across endpoints.
//! - [`storage`] — Root storage struct and subdomain modules.

extern crate alloc;

pub mod abi;
pub mod codec;
pub mod config;
pub mod endpoints;
pub mod internal;
pub mod storage;

/// Historical name for the shared domain boundary.
///
/// Kept as a re-export so that `kipio_economics::kipio_shared::EconomicReceipt`
/// continues to resolve for any consumer compiled against the pre-split ABI
/// (e.g. `kipio_execution_gateway`, `kipio_runtime`).
pub use abi::interfaces as kipio_shared;

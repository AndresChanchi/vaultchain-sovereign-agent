//! Encoding and decoding helpers for the economic domain.
//!
//! Each submodule targets a specific concern:
//!
//! - [`funding`]: decoding of `FundingSource` from its numeric ID + payload.
//! - [`pack`]: fixed-size bit-packing layouts for storage slots.
//! - [`pending`]: pending settlement packing and deterministic payment IDs.

pub mod funding;
pub mod pack;
pub mod pending;

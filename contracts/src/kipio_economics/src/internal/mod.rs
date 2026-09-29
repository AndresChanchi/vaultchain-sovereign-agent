//! Private helpers shared across endpoints.
//!
//! These are `pub(crate)` so that each endpoint module can call them via
//! `self.<method>(...)`, but they are not part of the ABI surface.

pub mod helpers;

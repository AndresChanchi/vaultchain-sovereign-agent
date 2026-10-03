//! Persistent layout. Every struct here is `#[storage]`-annotated and
//! maps 1:1 to a region of the Stylus storage tree.

pub mod access;
pub mod commitment;
pub mod entrypoint;
pub mod vault;

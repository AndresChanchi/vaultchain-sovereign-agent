//! Serialization of the `packed: StorageU256` field. All helpers operate
//! on plain `U256` and are pure: no storage access, no VM calls.

pub mod pack;
pub mod read;
pub mod validate;
pub mod write;

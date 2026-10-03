#![allow(unexpected_cfgs)]
#![cfg_attr(not(feature = "std"), no_std)]

extern crate alloc;

pub mod abi;
pub mod config;
pub mod endpoints;
pub mod internal;
pub mod storage;

pub use storage::entrypoint::KipioProtocolConfig;

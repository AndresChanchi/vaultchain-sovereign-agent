#![cfg_attr(not(any(test, feature = "export-abi")), no_main)]
#![allow(unexpected_cfgs)]

extern crate alloc;

pub mod abi;
pub mod config;
pub mod endpoints;
pub mod internal;
pub mod storage;

pub use storage::entrypoint::KipioRuntime;

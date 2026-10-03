#![cfg_attr(not(any(test, feature = "export-abi")), no_main)]

extern crate alloc;

pub mod abi;
pub mod endpoints;
pub mod internal;
pub mod storage;

//! Compile-time protocol configuration.
//!
//! The Gateway is immutable. All protocol addresses point to on-chain
//! proxies. The actual values are injected at deploy time by the deployment
//! tooling and must match the addresses registered in `kipio_protocol_config`.
//!
//! `kipio_protocol_config` is itself a proxy: updating a module means
//! updating its target in that contract, not redeploying the Gateway.

pub mod constants;

//! Shared domain boundary between `kipio_economics` and its consumers.
//!
//! This module holds two kinds of ABI items:
//!
//!   1. The `sol!` block with the domain types that define the economic
//!      contract of the protocol: what a settlement receipt is, what an
//!      economic intent looks like, and how the Chainlink CRE report is
//!      shaped. These MUST remain stable. Changing any of them breaks
//!      the ABI consumed by `kipio_execution_gateway` and `kipio_runtime`.
//!
//!   2. The `sol_interface!` block with the external interfaces that
//!      Economics depends on. Currently only `IKipioProtocolConfig`, used
//!      to resolve the trusted runtime orchestrator under Model B.

use stylus_sdk::alloy_sol_types::sol;
use stylus_sdk::prelude::*;

sol! {
    /// Represents a successful economic clearance for protocol operations.
    ///
    /// Consumed by Runtime to bind storage references to the user's identity.
    /// `payment_id` is a deterministic identifier for audit and tracing,
    /// derived from the funder and the settlement nonce. It is NOT used for
    /// anti-replay (the nonce is). It exists so off-chain indexers can
    /// correlate the receipt with a specific settlement intent.
    struct EconomicReceipt {
        address funder;
        uint256 allocated_capacity;
        uint256 fee_paid;
        uint8 service_id;
        address provider;
        bytes32 payment_id;
        uint256 nonce;
    }

    /// Represents the economic intent orchestrated by the frontend.
    ///
    /// Respects DDD: the frontend requests a `service_id` (business intent),
    /// not a `provider_address` (infrastructure detail).
    ///
    /// # Anti-replay
    ///
    /// The `nonce` field is mandatory and must match the funder's current
    /// on-chain nonce. This guarantees idempotency without growing storage:
    /// the nonce is stored once per account and incremented in-place.
    /// The frontend obtains the current nonce via `get_nonce(funder)`.
    struct SettlementPlan {
        uint256 requested_capacity;
        uint256 storage_quote;
        uint8 service_id;
        uint8 funding_source_id;
        bytes routing_payload;
        uint256 nonce;
    }

    /// Report payload delivered by Chainlink CRE.
    ///
    /// The `nonce` is the anti-replay mechanism. The CRE workflow includes
    /// the funder's current nonce (obtained off-chain via `get_nonce`) in the
    /// report. The contract validates that the nonce is exactly the next
    /// expected value for the funder.
    ///
    /// The `workflow_id` is NOT part of this report; it is extracted from the
    /// KeystoneForwarder metadata (bytes 0..32), which is signed by the DON
    /// and cannot be spoofed by a compromised workflow.
    struct CreSettlementReport {
        address funder;
        uint256 settled_amount;
        uint8 service_id;
        uint256 requested_capacity;
        uint256 nonce;
    }
}

sol_interface! {
    /// Protocol configuration registry.
    ///
    /// Economics reads the trusted runtime orchestrator address from this
    /// registry on every user-facing endpoint to distinguish a forwarded
    /// call (from the runtime) from a direct call (from the user).
    ///
    /// The registry uses per-module getters rather than a generic
    /// `getModule(uint8)`, keeping each lookup explicit and type-safe at
    /// the ABI level. New operational modules add their own getter.
    interface IKipioProtocolConfig {
        function getRuntimeAddress() external view returns (address);
    }
}

//! Domain types carried inside the dispatch envelope.
//!
//! The `Intent` struct is decoded by `dispatch` from the `payload` field
//! of the envelope. It carries the authorization chain, the optional
//! settlement calldata, the target call, and the proof verification
//! flag.

use stylus_sdk::alloy_sol_types::sol;

sol! {
    /// @notice The intent payload carried inside the dispatch envelope.
    ///
    /// Runtime decodes this from the `payload` field of the envelope,
    /// runs the Dafny authorization pipeline against the encoded
    /// `AuthorizationAbi`, optionally settles the economic obligation
    /// through `kipio_economics`, and forwards `target_call_data` to
    /// the resolved module.
    ///
    /// # Fields
    ///
    /// - `target_module`: identifier of the module to dispatch to. See
    ///   the `MODULE_*` constants. `MODULE_EXECUTION_ACCOUNT` (255)
    ///   dispatches to the calling account itself.
    ///
    /// - `authorization_abi`: ABI-encoded `AuthorizationAbi`. Runtime
    ///   decodes this and feeds it to the Dafny acceptance pipeline. The
    ///   pipeline reads the AuthorizationState from the account and
    ///   checks provenance, credential status, and effective authority.
    ///
    /// - `identities_abi`: ABI-encoded `IdentityAbi[]`. This is the
    ///   provenance chain that the Dafny model uses to resolve
    ///   transitive delegations. An empty array is valid when the
    ///   authorization does not rely on delegation.
    ///
    /// - `settlement_call_data`: OPTIONAL. ABI-encoded calldata for
    ///   `kipio_economics.settleEconomicObligation(funder, plan_payload)`.
    ///   When non-empty, Runtime forwards the entire `msg.value()` to
    ///   Economics FIRST, and only forwards the target call if the
    ///   settlement succeeds. This is the atomic fee gate: users pay
    ///   exactly once per operation, and if the payment fails the
    ///   target never runs. When empty, Runtime skips the settlement
    ///   step and forwards `msg.value()` to the target module.
    ///
    /// - `target_call_data`: raw calldata for the target module
    ///   (selector || args). Runtime forwards this verbatim, plus the
    ///   EIP-2771 suffix for forwarded-capable modules.
    ///
    /// - `proof_verified`: set by the caller (Gateway or relayer) after
    ///   cryptographically verifying the signature that authorized the
    ///   intent. The Dafny pipeline rejects the authorization if this is
    ///   false.
    struct Intent {
        uint8 target_module;
        bytes authorization_abi;
        bytes identities_abi;
        bytes settlement_call_data;
        bytes target_call_data;
        bool proof_verified;
    }
}

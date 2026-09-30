//! Custom errors returned by `kipio_economics`.
//!
//! All errors are ABI-encoded via `SolError::abi_encode`. They are grouped
//! by the domain concern they belong to so that callers can branch on the
//! selector without ambiguity.

use stylus_sdk::alloy_sol_types::sol;

sol! {
    // --- ECONOMIC ERRORS ---
    error InsufficientFunds();
    error InvalidPricingParameters();
    error InvalidSettlementPlan();
    error UnsupportedFundingSource();
    error TreasuryDepleted();
    error GrantDepleted();
    error GrantExpiredError();
    error SponsorDepleted();
    error CreditExpiredError();
    error CreditNotExpired();
    error MaxCreditExceeded();
    error CampaignDepleted();
    error CampaignExpired();
    error FeeExceedsMaximum();

    // --- SETTLEMENT ERRORS ---
    error UnsupportedService();
    error TransferFailed();
    error Unauthorized();
    error ZeroAmount();
    error AlreadyProcessed();
    error PausedError();
    error InvalidPaymentId();
    error GrantAlreadyExists();
    error SponsorAlreadyExists();
    error DepositTooLarge();
    error SettlementNotStale();
    error InvalidNonce(uint256 expected, uint256 provided);

    // --- CRE ERRORS ---
    error UnauthorizedForwarder();
    error UnauthorizedWorkflow();
    error ReplayDetected();
    error InvalidCreReport();
    error InsufficientDeposit();

    // --- MODEL B (TRUSTED FORWARDER) ---
    /// @notice The protocol configuration address is not set. Economics
    ///         cannot resolve the trusted runtime orchestrator and
    ///         therefore cannot accept a forwarded call.
    error ProtocolConfigNotSet();

    /// @notice A cross-call to the protocol configuration registry failed.
    error ConfigQueryFailed();

    /// @notice A user-facing endpoint received `Address::ZERO` as the
    ///         effective user. Rejected to avoid silently crediting
    ///         state to a phantom address.
    error ZeroUser();
}

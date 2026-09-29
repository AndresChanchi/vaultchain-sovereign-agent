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
}

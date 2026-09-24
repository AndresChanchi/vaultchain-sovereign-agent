//! # Custom Errors
//!
//! Custom errors are encoded as 4-byte selectors, which is significantly
//! cheaper than string-based reverts (64-96 bytes).
//!
//! NAMING CONVENTION: error names are unique across the entire ABI.
//! The pause-state error is `EnforcedPause` (not `Paused`) to avoid
//! colliding with the `Paused` event. This mirrors the OpenZeppelin
//! Pausable convention: events `Paused`/`Unpaused`,
//! errors `EnforcedPause`/`ExpectedPause`.

use stylus_sdk::alloy_sol_types::sol;

sol! {
    error Unauthorized();
    error ZeroOwner();
    error ZeroGrantee();
    error ZeroAddress();
    error ZeroCommitment();
    error ZeroContentId();
    error AlreadyExists();
    error NotFound();
    error EmptyBatch();
    error BatchTooLarge();
    error LengthMismatch();
    error IndexCorrupted();
    error QueryAlreadyPending();
    error QueryIdClaimedByOther();
    error QueryNotPending();
    error QueryLimitExceeded();
    error QueryNotStale();
    error ContentHashMismatch();
    error VersionMismatch();
    error UnauthorizedForwarder();
    error UnauthorizedWorkflow();
    error InvalidMetadata();
    error InvalidReportLength();
    error TruncatedResult();
    error UnsupportedProvider();
    error UnsupportedStorageTerm();
    error InvalidExpiryDelta();
    error ContentAlreadyPermanent();
    error NoPendingOwner();
    error EnforcedPause();
    // --- ZK PATH ERRORS ---
    error EmptyProof();
    error ZkVerifierNotSet();
    error ZkVerificationFailed();
}

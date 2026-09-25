//! # Custom Errors
//!
//! Custom errors are encoded as 4-byte selectors, significantly cheaper
//! than string-based reverts (64-96 bytes). Every error name is unique
//! across the entire ABI.
//!
//! NAMING CONVENTION: no error name collides with an event name. This
//! follows the OpenZeppelin convention (e.g. `EnforcedPause` vs `Paused`
//! event).

use stylus_sdk::alloy_sol_types::sol;

sol! {
    // ========================================================================
    // CONTENT / STORAGE
    // ========================================================================

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

    // ========================================================================
    // IDENTITY / AUTH
    // ========================================================================

    // --- Initialization ---
    error ZeroAddressConfig();
    error NotAContract();
    error AlreadyInitialized();
    error ProtocolConfigNotSet();

    // --- Registration ---
    error ZeroUser();
    error EmptyKey();
    error AlreadyRegistered();
    error NotRegistered();
    error InvalidOldKey();
    error CurveNotActiveForRegistration();

    // --- Verification ---
    error BadSig();
    error BadSigLength();
    error BadPubkeyLength();
    error BadNonce();
    error InvalidPubkey();
    error Expired();
    error CurveHardwareDisabled();
    error VerifierNotSetForCurve();
    error ConfigQueryFailed();
    error VerifierCallFailed();
    error VerifyFail();

    // --- Policy ---
    error UnauthorizedLedger();
    error LedgerQueryFailed();
    error PolicyNotApproved();
    error InvalidPolicyType();
    error PolicyExpired();
    error HashMismatch();
    error ConsumePolicyFailed();
    error TargetCurveNotActive();
}

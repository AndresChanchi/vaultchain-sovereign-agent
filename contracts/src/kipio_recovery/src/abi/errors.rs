//! Custom errors returned by `kipio_recovery`.
//!
//! All errors are ABI-encoded via `SolError::abi_encode`. Callers branch
//! on the selector to distinguish between failure modes.

use stylus_sdk::alloy_sol_types::sol;

sol! {
    error NotInitialized();
    error UnauthorizedCaller();
    error ZeroRuntime();

    error GuardiansAlreadyConfigured();
    error GuardiansNotConfigured();
    error InvalidGuardianCount();
    error DuplicateGuardian();
    error InvalidThreshold();
    error InvalidGuardianType();
    error ZeroGuardianIdentifier();
    error InvalidUpdateReason();
    error MaxGuardiansExceeded();

    error RecoveryNotFound();
    error RecoveryNotActive();
    error RecoveryNotApproved();
    error RecoveryAlreadyFinalized();
    error RecoveryNotExecutableYet();
    error RecoveryExpiredErr();
    error ExpiredDeadline();
    error ActiveRecoveryExists();

    error EmptySignature();
    error EmptyPubkey();
    error UnknownGuardian();
    error InvalidCurve();
    error SignatureVerificationFailed();
    error AlreadyApproved();

    error CancelNotAuthorized();
}

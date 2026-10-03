//! Events emitted by `kipio_recovery`.
//!
//! Every mutating state transition emits an indexed event so off-chain
//! indexers and auditors can reconstruct the recovery lifecycle without
//! touching storage.

use stylus_sdk::alloy_sol_types::sol;

sol! {
    event GuardiansConfigured(
        address indexed account,
        uint64 version,
        uint8 count,
        uint8 threshold
    );
    event GuardiansUpdated(
        address indexed account,
        uint64 version,
        uint8 count,
        uint8 threshold,
        uint8 reason
    );

    event RecoveryStarted(
        address indexed account,
        bytes32 indexed requestId,
        bytes32 targetHash,
        uint64 deadline,
        uint64 guardianVersion
    );

    event RecoveryApprovalGranted(
        bytes32 indexed requestId,
        bytes32 indexed guardianHash,
        uint8 curve
    );

    event RecoveryApproved(
        bytes32 indexed requestId,
        uint64 executableAfter
    );

    event RecoveryCancelled(bytes32 indexed requestId, address indexed cancelledBy);
    event RecoveryExecuted(bytes32 indexed requestId, address indexed executedBy);
    event RecoveryExpired(bytes32 indexed requestId);
}

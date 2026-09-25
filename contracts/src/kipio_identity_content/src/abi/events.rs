//! # Domain Events
//!
//! Every event carries only commitments, hashes, or indexed identifiers.
//! Never raw payloads. Indexers reconstruct history without needing to
//! decode off-chain state.

use stylus_sdk::alloy_sol_types::sol;

sol! {
    // ========================================================================
    // CONTENT / STORAGE
    // ========================================================================

    event ContentRegistered(
        address indexed user,
        bytes32 indexed contentHash,
        bytes32 txCommitment,
        uint8 providerId,
        uint8 storageTerm
    );

    event ContentRotated(
        address indexed user,
        bytes32 indexed contentHash,
        bytes32 newTxCommitment,
        uint32 newVersion
    );

    event ContentVisibilityUpdated(
        address indexed user,
        bytes32 indexed contentHash,
        bool isPublic
    );

    event ContentStorageTermExtended(
        address indexed user,
        bytes32 indexed contentHash,
        uint8 oldTerm,
        uint8 newTerm,
        uint32 newExpiryDelta
    );

    event AccessGranted(
        address indexed owner,
        address indexed grantee,
        bytes32 indexed contentHash
    );

    event AccessRevoked(
        address indexed owner,
        address indexed grantee,
        bytes32 indexed contentHash
    );

    event ContentDeleted(
        address indexed user,
        bytes32 indexed contentHash
    );

    event QueryRequested(
        bytes32 indexed queryId,
        address indexed requester,
        bytes32 indexed contentHash,
        bytes32 queryPlanHash
    );

    event QueryResultReceived(
        bytes32 indexed queryId,
        bytes32 indexed contentHash,
        bytes32 resultHash,
        bytes2 reportId
    );

    event ProviderUpdated(
        uint8 indexed providerType,
        address indexed oldProvider,
        address indexed newProvider
    );

    event WorkflowIdUpdated(
        bytes32 indexed oldWorkflowId,
        bytes32 indexed newWorkflowId
    );

    event OwnershipTransferStarted(
        address indexed previousOwner,
        address indexed newOwner
    );

    event OwnerUpdated(
        address indexed oldOwner,
        address indexed newOwner
    );

    event ZkVerifierUpdated(
        address indexed oldVerifier,
        address indexed newVerifier
    );

    event QueryCancelled(
        bytes32 indexed queryId,
        address indexed requester
    );

    event Paused(
        address indexed by,
        bytes32 reasonHash
    );

    event Unpaused(
        address indexed by
    );

    // ========================================================================
    // IDENTITY / AUTH
    // ========================================================================

    /// @notice Emitted when the identity ledger is linked to a protocol config.
    /// @dev Idempotent: repeated calls with the same config do not emit again.
    event Initialized(address indexed config);

    /// @notice Emitted when a sovereign identity anchors its first cryptographic key.
    /// @dev The pubkey is hashed; the raw bytes never appear on-chain.
    event Registered(
        address indexed user,
        bytes32 pubkeyHash,
        uint256 curve
    );

    /// @notice Emitted whenever a registered identity proves intent authorization.
    /// @dev Signals that the on-chain nonce advanced by one. Consumers rely on
    ///      this event to track the latest valid nonce without polling storage.
    event IdentityAuthorizationVerified(
        address indexed user,
        bytes32 indexed msgHash,
        uint256 newNonce
    );

    /// @notice Emitted when a user rotates their cryptographic identity (key + curve).
    /// @dev The old pubkey is authenticated by the previous key's signature,
    ///      preserving chain-of-custody across rotations.
    event KeyRotated(
        address indexed user,
        bytes32 oldPubkeyHash,
        bytes32 newPubkeyHash,
        uint256 newCurve,
        uint256 newNonce
    );

    /// @notice Emitted when a pre-approved external policy drives a key rotation.
    /// @dev Asymmetric with `KeyRotated`: authorization comes from the ledger,
    ///      not from a signature. Both paths preserve Auth as single source of truth.
    event KeyRotatedFromPolicy(
        address indexed user,
        address indexed ledger,
        bytes32 indexed requestId,
        bytes32 newPubkeyHash,
        uint256 newCurve
    );
}

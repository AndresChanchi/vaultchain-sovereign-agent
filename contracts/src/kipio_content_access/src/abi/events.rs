//! # Domain Events
//!
//! Every event carries only commitments, hashes, or indexed identifiers.
//! Never raw payloads. Indexers reconstruct history from the event stream
//! without needing access to private data.

use stylus_sdk::alloy_sol_types::sol;

sol! {
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
}

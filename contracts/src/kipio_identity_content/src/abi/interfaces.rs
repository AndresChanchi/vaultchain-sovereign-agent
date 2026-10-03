//! # Provider Abstraction Boundary
//!
//! The `sol_interface!` block declares every external interface the
//! contract depends on. Each interface describes one role in the
//! protocol.

use stylus_sdk::prelude::*;

sol_interface! {
    // ========================================================================
    // CONTENT / STORAGE
    // ========================================================================

    interface IStorageProvider {
        function resolve(bytes32 commitment) external view returns (bytes memory);
    }

    interface IQueryProvider {
        function verify(bytes calldata proof, bytes calldata result)
            external view returns (bool);
    }

    interface IAccessProvider {
        function is_authorized(
            bytes32 policy_hash,
            address grantee
        ) external view returns (bool);
    }

    interface IReceiver {
        function onReport(bytes calldata metadata, bytes calldata report) external;
    }

    /// @title IZKVerifier
    /// @notice Optional abstraction over zero-knowledge proof verifiers.
    /// @dev The Solidity ABI selector is `keccak256("verify(bytes,bytes32[])")`.
    ///      Parameter names are NOT part of the selector, so snake_case is safe.
    interface IZKVerifier {
        function verify(
            bytes calldata proof,
            bytes32[] calldata public_inputs
        ) external view returns (bool);
    }

    // ========================================================================
    // IDENTITY / AUTH
    // ========================================================================

    /// @title External Cryptographic Verifier Interface
    /// @notice Outlines the standard validation boundary implemented by external curve modules.
    interface IKipioAuthVerifier {
        function verify(
            address user,
            bytes32 digest,
            bytes signature,
            bytes pubkey,
            uint256 curve
        ) external returns (bool);
    }

    /// @title Protocol Configuration Manager Interface
    /// @notice Centralized administrative hub and source of truth for
    ///         protocol infrastructure.
    ///
    /// The `getRuntimeAddress` accessor is the Model B trust anchor: the
    /// contract reads it on every fallback dispatch to decide whether
    /// `msg_sender` is the trusted forwarder. When the runtime is
    /// upgraded, updating the address in `kipio_protocol_config` is
    /// enough — every consumer resolves the new runtime on the next
    /// call, without redeploying.
    interface IKipioProtocolConfig {
        function getVerifier(uint256 curve_id) external view returns (address);
        function getCurveStatus(uint256 curve_id) external view returns (uint256);
        function isAuthorizedLedger(address ledger) external view returns (bool);
        function getRuntimeAddress() external view returns (address);
    }
}

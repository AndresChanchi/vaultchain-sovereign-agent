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
    /// @notice Centralized administrative hub and source of truth for protocol infrastructure.
    interface IKipioProtocolConfig {
        function getVerifier(uint256 curve_id) external view returns (address);
        function getCurveStatus(uint256 curve_id) external view returns (uint256);
        function isAuthorizedLedger(address ledger) external view returns (bool);
    }

    /// @title External Policy Ledger Interface
    /// @notice This interface intentionally exposes a stable semantic view.
    ///
    /// Auth depends on policy semantics,
    /// not on the storage layout of any particular policy engine.
    ///
    /// Recovery,
    /// Enterprise Approval,
    /// Agent Governance,
    /// or future policy providers
    /// are free to change their internal implementation
    /// without requiring changes inside Auth,
    /// provided this interface remains stable.
    interface IKipioPolicyLedger {
        function getPolicyRecord(bytes32 request_id) external view returns (
            uint256 status,
            bytes32 policy_type,
            address user,
            bytes32 target_hash,
            uint256 curve,
            uint256 deadline
        );

        function consumePolicy(bytes32 request_id) external;
    }
}

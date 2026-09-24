//! # Provider Abstraction Boundary
//!
//! The `sol_interface!` block declares every external interface the
//! contract depends on. Each interface describes one role in the
//! protocol (storage, query, access, ZK verification, CRE callback).

use stylus_sdk::prelude::*;

sol_interface! {
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
}

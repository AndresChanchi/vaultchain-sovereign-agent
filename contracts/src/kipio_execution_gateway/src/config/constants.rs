//! Protocol constants resolved at compile time.

use stylus_sdk::alloy_primitives::Address;

/// @notice Proxy address of the Kipio Runtime orchestrator.
pub const KIPIO_RUNTIME: Address = Address::new([0u8; 20]);

/// @notice Proxy address of the Kipio Economics contract.
pub const KIPIO_ECONOMICS: Address = Address::new([0u8; 20]);

/// @notice Proxy address of the Kipio Recovery singleton.
pub const KIPIO_RECOVERY: Address = Address::new([0u8; 20]);

/// @notice Salt scheme version. Increment only when the salt preimage changes.
pub const SALT_SCHEME_VERSION: u8 = 1;

/// @notice ArbOS WASM activation precompile (`0x...0071`).
pub const ARB_WASM_ADDR: Address =
    Address::new([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x71]);

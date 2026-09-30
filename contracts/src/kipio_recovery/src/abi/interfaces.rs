//! Cross-contract interfaces consumed by `kipio_recovery`.
//!
//! Recovery calls back into the Account contract for two read-only
//! lookups during `cancel_recovery`:
//!
//!   - `isCredentialActive(bytes32)`: whether the credential id (keccak
//!     fingerprint of the raw pubkey) is currently marked ACTIVE.
//!   - `getNonce()`: the account's current nonce, bound into the
//!     cancellation digest so that a signature produced for one nonce
//!     cannot be replayed after any account state change.
//!
//! Both calls are `static_call` semantics: they cannot mutate state and
//! cannot reenter Recovery.

use stylus_sdk::prelude::sol_interface;

sol_interface! {
    interface IKipioAccount {
        function isCredentialActive(bytes32 credential_id) external view returns (bool);
        function getNonce() external view returns (uint64);
    }
}

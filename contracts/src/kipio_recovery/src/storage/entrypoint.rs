//! Root storage struct for `kipio_recovery`.
//!
//! The Recovery contract is a **singleton**: one deployment shared by
//! every KipioAccount. Every storage field is keyed by the account
//! address at the top level. Under the Stylus multidimensional gas
//! model, the nested maps do not create slots until they are written,
//! so the marginal storage cost per account is exactly the same as it
//! was when the subsystem lived inside `kipio_account`.
//!
//! # Guardians (per account, per version, N guardians, MAX = 16)
//!
//!   - `guardian_meta[acct][v]`            1 slot  (count | threshold | reason)
//!   - `guardian_schedule[acct][v]`        1 slot  (types[16] | curves[16])
//!   - `guardian_identifiers[acct][v][i]`  N slots (B256 per guardian)
//!
//!   Total: `2 + N` slots per version.
//!
//!   The reverse index (guardian_hash -> index) is NOT stored. It is
//!   derived on the fly by linear scan over the identifiers array.
//!
//! # Recovery approvals (per account, per request)
//!
//!   - `recovery_approvals[acct][req]`     1 slot (bitfield over guardians)
//!
//!   Each guardian's approval is a single bit indexed by its position in
//!   the request's pinned guardian version.
//!
//! # Request ledger
//!
//! Every per-request field is a `StorageMap<Address, StorageMap<B256, T>>`
//! keyed by `(account, request_id)`. The `request_id` is derived as
//! `keccak256(account || next_recovery_id[account])`, making it
//! deterministic and globally unique without a global counter.

use stylus_sdk::{
    alloy_primitives::{Address, B256, U64, U8},
    prelude::*,
    storage::{
        StorageAddress, StorageB256, StorageBool, StorageMap, StorageU8, StorageU64, StorageU256,
    },
};

#[storage]
#[entrypoint]
pub struct KipioRecovery {
    pub(crate) runtime_address: StorageAddress,
    pub(crate) initialized: StorageBool,

    // ========================================================================
    // GUARDIAN CONFIGURATION (per account)
    // ========================================================================
    pub(crate) guardian_versions: StorageMap<Address, StorageU64>,
    pub(crate) guardian_meta: StorageMap<Address, StorageMap<U64, StorageU256>>,
    pub(crate) guardian_schedule: StorageMap<Address, StorageMap<U64, StorageB256>>,
    pub(crate) guardian_identifiers:
        StorageMap<Address, StorageMap<U64, StorageMap<U8, StorageB256>>>,

    // ========================================================================
    // REQUEST LEDGER (per account)
    // ========================================================================
    pub(crate) next_recovery_id: StorageMap<Address, StorageU64>,
    pub(crate) active_recovery_id: StorageMap<Address, StorageB256>,

    pub(crate) recovery_target_hash: StorageMap<Address, StorageMap<B256, StorageB256>>,
    pub(crate) recovery_deadline: StorageMap<Address, StorageMap<B256, StorageU64>>,
    pub(crate) recovery_executable_after: StorageMap<Address, StorageMap<B256, StorageU64>>,
    pub(crate) recovery_guardian_version: StorageMap<Address, StorageMap<B256, StorageU64>>,
    pub(crate) recovery_approval_count: StorageMap<Address, StorageMap<B256, StorageU8>>,
    pub(crate) recovery_status: StorageMap<Address, StorageMap<B256, StorageU8>>,
    pub(crate) recovery_approvals: StorageMap<Address, StorageMap<B256, StorageU256>>,
}

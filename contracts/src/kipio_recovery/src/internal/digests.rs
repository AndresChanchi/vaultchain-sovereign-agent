//! Signature digests for guardian approvals and cancellations.

use alloc::vec::Vec;

use stylus_sdk::{
    alloy_primitives::{Address, B256, U64},
    crypto::keccak,
    prelude::*,
};

use crate::config::constants::{APPROVE_DOMAIN, CANCEL_DOMAIN};
use crate::storage::entrypoint::KipioRecovery;

impl KipioRecovery {
    /// EIP-712-like digest for guardian approvals. Binds the chain id,
    /// the account, the request id and the target hash. A signature
    /// produced for one request cannot be reused for another.
    pub(crate) fn build_recovery_approval_digest(
        &self,
        account: Address,
        request_id: B256,
        target_hash: B256,
    ) -> B256 {
        let chain_id = Self::u64_to_be32(self.vm().chain_id());
        let mut preimage = Vec::with_capacity(96 + 32 + 32);
        preimage.extend_from_slice(APPROVE_DOMAIN);
        preimage.extend_from_slice(&chain_id);
        preimage.extend_from_slice(account.as_slice());
        preimage.extend_from_slice(request_id.as_slice());
        preimage.extend_from_slice(target_hash.as_slice());
        keccak(&preimage)
    }

    /// Cancellation digest. Binds the account's current nonce, so a
    /// signature produced before any account state change cannot be
    /// replayed.
    pub(crate) fn build_recovery_cancel_digest(
        &self,
        account: Address,
        request_id: B256,
        nonce: U64,
    ) -> B256 {
        let chain_id = Self::u64_to_be32(self.vm().chain_id());
        let nonce_bytes = Self::u64_to_be32(nonce.to::<u64>());
        let mut preimage = Vec::with_capacity(96 + 32 + 32);
        preimage.extend_from_slice(CANCEL_DOMAIN);
        preimage.extend_from_slice(&chain_id);
        preimage.extend_from_slice(account.as_slice());
        preimage.extend_from_slice(request_id.as_slice());
        preimage.extend_from_slice(&nonce_bytes);
        keccak(&preimage)
    }
}

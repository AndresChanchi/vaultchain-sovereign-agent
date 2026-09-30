//! Recovery request lifecycle helpers.

use alloc::vec::Vec;

use stylus_sdk::{
    alloy_primitives::{Address, B256, U8, U64},
    alloy_sol_types::SolError,
    prelude::*,
};

use crate::abi::errors::ActiveRecoveryExists;
use crate::abi::events::RecoveryExpired;
use crate::config::constants::{
    RECOVERY_STATUS_ACTIVE, RECOVERY_STATUS_APPROVED, RECOVERY_STATUS_EXPIRED,
};
use crate::storage::entrypoint::KipioRecovery;

impl KipioRecovery {
    #[inline]
    pub(crate) fn is_expired(&self, account: Address, request_id: B256) -> bool {
        let deadline = self
            .recovery_deadline
            .getter(account)
            .getter(request_id)
            .get();
        let now = U64::from(self.vm().block_timestamp());
        now > deadline
    }

    /// Terminal transition for a request that crossed its deadline.
    ///
    /// Idempotent: calling it on a non-active request is a no-op at the
    /// state level (the write is redundant) but still emits the event,
    /// which is fine for observability.
    pub(crate) fn mark_expired(&mut self, account: Address, request_id: B256) {
        self.recovery_status
            .setter(account)
            .setter(request_id)
            .set(U8::from(RECOVERY_STATUS_EXPIRED));
        if self.active_recovery_id.getter(account).get() == request_id {
            self.active_recovery_id.setter(account).set(B256::ZERO);
        }
        self.vm().log(RecoveryExpired {
            requestId: request_id,
        });
    }

    /// Rejects new recovery requests while a previous one is in-flight.
    /// Auto-expires a stale in-flight request instead of blocking
    /// indefinitely.
    pub(crate) fn ensure_no_active_recovery(&mut self, account: Address) -> Result<(), Vec<u8>> {
        let current = self.active_recovery_id.getter(account).get();
        if current == B256::ZERO {
            return Ok(());
        }

        let status = self
            .recovery_status
            .getter(account)
            .getter(current)
            .get()
            .to::<u8>();

        if status == RECOVERY_STATUS_ACTIVE || status == RECOVERY_STATUS_APPROVED {
            if self.is_expired(account, current) {
                self.mark_expired(account, current);
                return Ok(());
            }
            return Err(ActiveRecoveryExists {}.abi_encode());
        }

        self.active_recovery_id.setter(account).set(B256::ZERO);
        Ok(())
    }

    #[inline]
    pub(crate) fn u64_to_be32(v: u64) -> [u8; 32] {
        let mut out = [0u8; 32];
        out[24..32].copy_from_slice(&v.to_be_bytes());
        out
    }
}

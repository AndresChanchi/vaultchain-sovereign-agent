//! Internal helpers for `kipio_economics`.
//!
//! These methods are not marked `#[public]` and therefore do not appear in
//! the ABI. They are called from the endpoint delegators and from each
//! endpoint handler.

use alloc::vec::Vec;

use stylus_sdk::alloy_primitives::{Address, U256};
use stylus_sdk::alloy_sol_types::SolError;
use stylus_sdk::prelude::*;

use crate::abi::errors::{
    ConfigQueryFailed, InvalidNonce, PausedError, ProtocolConfigNotSet, TransferFailed,
    Unauthorized, ZeroUser,
};
use crate::abi::events::{NonceConsumed, RefundCredited};
use crate::abi::interfaces::IKipioProtocolConfig;
use crate::storage::entrypoint::KipioEconomics;

impl KipioEconomics {
    /// Resolves the trusted runtime orchestrator address from the protocol
    /// configuration registry.
    ///
    /// Called by every user-facing endpoint that accepts a forwarded call
    /// under Model B. A forwarded call arrives with `msg_sender == runtime`
    /// and the effective user passed as an explicit parameter. Economics
    /// never falls back to `msg_sender` for the user identity: the
    /// parameter is the only source of truth for who the user is.
    pub(crate) fn resolve_runtime(&self) -> Result<Address, Vec<u8>> {
        let config_addr = self.protocol_config.get();
        if config_addr == Address::ZERO {
            return Err(ProtocolConfigNotSet {}.abi_encode());
        }
        let config = IKipioProtocolConfig::new(config_addr);
        config
            .get_runtime_address(self.vm(), Call::new())
            .map_err(|_| ConfigQueryFailed {}.abi_encode())
    }

    /// Authorization gate for a user-facing endpoint under Model B.
    ///
    /// Two authorized callers are accepted:
    ///
    ///   1. The user themselves (`msg_sender == user`). This is the
    ///      direct-call path, used by EOAs and by any caller that has
    ///      verified itself as the effective user of the operation.
    ///
    ///   2. The trusted runtime (`msg_sender == resolve_runtime()`). This
    ///      is the forwarded path, where the runtime drives the flow on
    ///      behalf of the user and the effective user is passed as a
    ///      parameter.
    ///
    /// Any other caller reverts with `Unauthorized`.
    pub(crate) fn require_user_or_runtime(&self, user: Address) -> Result<(), Vec<u8>> {
        if user == Address::ZERO {
            return Err(ZeroUser {}.abi_encode());
        }
        let caller = self.vm().msg_sender();
        if caller == user {
            return Ok(());
        }
        let runtime = self.resolve_runtime()?;
        if caller == runtime {
            return Ok(());
        }
        Err(Unauthorized {}.abi_encode())
    }

    /// Validates and consumes a nonce for an account.
    ///
    /// The nonce must exactly equal the account's current nonce. On success,
    /// the nonce is incremented by one. This is the anti-replay mechanism.
    ///
    /// # Why strict equality?
    ///
    /// Strict equality prevents out-of-order consumption. If the frontend
    /// skips a nonce (e.g. due to a race condition), the settlement reverts
    /// and the frontend must retry with the correct nonce. This mirrors the
    /// behavior of EIP-4337 and other smart account standards.
    pub(crate) fn use_checked_nonce(
        &mut self,
        account: Address,
        nonce: U256,
    ) -> Result<(), Vec<u8>> {
        let current = self.account_nonces.get(account);
        if nonce != current {
            return Err(InvalidNonce {
                expected: current,
                provided: nonce,
            }
            .abi_encode());
        }

        let next = current.checked_add(U256::ONE).ok_or_else(|| {
            InvalidNonce {
                expected: current,
                provided: nonce,
            }
            .abi_encode()
        })?;

        self.account_nonces.setter(account).set(next);
        self.vm().log(NonceConsumed { account, nonce });
        Ok(())
    }

    /// Centralized physical settlement.
    ///
    /// No other function in the contract issues raw calls. This is the only
    /// place where ETH leaves the contract. Uses `flush_storage_cache()`
    /// before the external call to persist the storage cache and prevent
    /// stale reads if the payee reenters.
    pub(crate) fn settle_payment(
        &mut self,
        payee: Address,
        amount: U256,
    ) -> Result<(), Vec<u8>> {
        if amount == U256::ZERO {
            return Ok(());
        }

        let _ = unsafe {
            stylus_sdk::call::RawCall::new_with_value(self.vm(), amount)
                .flush_storage_cache()
                .skip_return_data()
                .call(payee, &[])
        }
        .map_err(|_| TransferFailed {}.abi_encode())?;

        Ok(())
    }

    /// Credits a pull-based refund balance to an account.
    ///
    /// The account must call `withdraw_refund` to actually receive the ETH.
    pub(crate) fn credit_refund(&mut self, account: Address, amount: U256) {
        if amount == U256::ZERO {
            return;
        }
        let current = self.withdrawable_refunds.getter(account).get();
        self.withdrawable_refunds
            .setter(account)
            .set(current + amount);
        self.vm().log(RefundCredited { account, amount });
    }

    pub(crate) fn require_owner(&self) -> Result<(), Vec<u8>> {
        if self.vm().msg_sender() != self.owner.get() {
            return Err(Unauthorized {}.abi_encode());
        }
        Ok(())
    }

    pub(crate) fn require_not_paused(&self) -> Result<(), Vec<u8>> {
        if self.paused.get() {
            return Err(PausedError {}.abi_encode());
        }
        Ok(())
    }
}

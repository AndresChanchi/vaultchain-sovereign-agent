//! Bootstrap pipeline: deploy → activate → call constructor.
//!
//! Each step is idempotent, so the pipeline can run on every `execute`.
//!
//! # Activation detection
//!
//! A deployed contract is considered unactivated when `codehashVersion`
//! reverts. The revert is the expected signal for EVM contracts and for
//! Stylus programs that have not been activated yet.
//!
//! # Constructor invocation
//!
//! Stylus constructors are not executed automatically during activation.
//! After activation, the Gateway calls the constructor with ABI-encoded
//! `(identity, runtime, recovery)`. The Stylus SDK writes a sentinel after
//! the first successful call, so the constructor reverts on subsequent
//! invocations. The Gateway only calls it when `is_initialized()` returns
//! `false`.

use alloc::vec::Vec;

use stylus_sdk::{
    alloy_primitives::{Address, B256, U256},
    alloy_sol_types::{SolError, SolValue},
    call::RawCall,
    prelude::*,
};

use crate::abi::errors::{
    ActivationFailed, DeploymentAddressMismatch, InitializationFailed,
    InsufficientValueForActivation, TransferFailed,
};
use crate::abi::events::{
    AccountBootstrapped, BootstrapFunded, SponsorshipExcessReturned,
};
use crate::config::constants::{
    ARB_WASM_ADDR, KIPIO_ECONOMICS, KIPIO_RECOVERY, KIPIO_RUNTIME,
};
use crate::internal::helpers::constructor_selector;
use crate::kipio_shared::{IArbWasm, IKipioAccountLifecycle, IKipioBootstrapFunding};
use crate::storage::entrypoint::KipioExecutionGateway;

impl KipioExecutionGateway {
    /// Bootstraps the sovereign account if it is not ready.
    pub(crate) fn bootstrap_sovereign_account(
        &mut self,
        target_account: Address,
        salt: B256,
        identity: Address,
        available_value: &mut U256,
    ) -> Result<(), Vec<u8>> {
        enum AccountState {
            Ready,
            NotDeployed,
            DeployedUnactivated,
            ActivatedUninitialized,
        }

        let state = if self.vm().code_size(target_account) == 0 {
            AccountState::NotDeployed
        } else {
            let codehash = self.vm().code_hash(target_account);
            let arb_wasm = IArbWasm::new(ARB_WASM_ADDR);
            match arb_wasm.codehash_version(self.vm(), Call::new(), codehash) {
                Ok(_version) => {
                    let lifecycle = IKipioAccountLifecycle::new(target_account);
                    match lifecycle.is_initialized(self.vm(), Call::new()) {
                        Ok(true) => AccountState::Ready,
                        _ => AccountState::ActivatedUninitialized,
                    }
                }
                Err(_) => AccountState::DeployedUnactivated,
            }
        };

        if matches!(state, AccountState::Ready) {
            return Ok(());
        }

        // --- Sponsorship: only when activation is required ---
        let (sponsored, activation_budget) = if matches!(
            state,
            AccountState::NotDeployed | AccountState::DeployedUnactivated
        ) {
            self.request_sponsorship(identity)
        } else {
            (false, U256::ZERO)
        };

        // --- Deploy (if needed) ---
        if matches!(state, AccountState::NotDeployed) {
            let deployed = self.deploy_account(salt)?;
            if deployed != target_account {
                return Err(DeploymentAddressMismatch {
                    expected: target_account,
                    actual: deployed,
                }
                .abi_encode());
            }
        }

        // --- Activate (if needed) ---
        let mut sponsored_excess = U256::ZERO;
        if matches!(
            state,
            AccountState::NotDeployed | AccountState::DeployedUnactivated
        ) {
            let consumed = self.activate_account(
                target_account,
                sponsored,
                activation_budget,
                available_value,
            )?;
            if sponsored && consumed < activation_budget {
                sponsored_excess = activation_budget - consumed;
            }
        }

        // --- Initialize: call the constructor entrypoint ---
        let selector = constructor_selector();
        let args = (identity, KIPIO_RUNTIME, KIPIO_RECOVERY).abi_encode_params();
        let mut calldata = Vec::with_capacity(4 + args.len());
        calldata.extend_from_slice(&selector);
        calldata.extend_from_slice(&args);

        let host = self.vm();
        match unsafe { RawCall::new(host).call(target_account, &calldata) } {
            Ok(_) => {}
            Err(_) => return Err(InitializationFailed {}.abi_encode()),
        }

        self.vm().log(AccountBootstrapped {
            account: target_account,
            identity,
            sponsored,
            activationSpent: if sponsored { activation_budget } else { U256::ZERO },
        });

        if sponsored_excess > U256::ZERO {
            self.return_sponsorship_excess(identity, sponsored_excess)?;
        }

        Ok(())
    }

    /// Requests sponsorship from Economics.
    ///
    /// The flow is pull-based: `fundBootstrap` credits the Gateway's
    /// refund balance in Economics, and `withdrawRefund` transfers the
    /// ETH to the Gateway. The Gateway then uses that ETH for activation.
    ///
    /// Returns `(sponsored, allocated)`. `sponsored` is true only when the
    /// ETH was successfully withdrawn and is available in the Gateway's
    /// balance.
    pub(crate) fn request_sponsorship(&mut self, identity: Address) -> (bool, U256) {
        if KIPIO_ECONOMICS == Address::ZERO {
            return (false, U256::ZERO);
        }

        let economics = IKipioBootstrapFunding::new(KIPIO_ECONOMICS);

        // 1. Request sponsorship (credits the Gateway's refund balance).
        let funding_call = Call::new_mutating(self);
        let result = economics.fund_bootstrap(self.vm(), funding_call, identity);

        match result {
            Ok((sponsored, allocated)) if sponsored => {
                // 2. Withdraw the credit (pull-based). The Gateway receives ETH.
                let withdraw_call = Call::new_mutating(self);
                match economics.withdraw_refund(self.vm(), withdraw_call) {
                    Ok(()) => {
                        self.vm().log(BootstrapFunded {
                            identity,
                            sponsor: KIPIO_ECONOMICS,
                            amount: allocated,
                        });
                        (true, allocated)
                    }
                    Err(_) => (false, U256::ZERO),
                }
            }
            _ => (false, U256::ZERO),
        }
    }

    /// Activates the account's WASM program.
    ///
    /// Returns the amount of ETH consumed by the activation, measured as
    /// the difference in the Gateway's balance before and after.
    ///
    /// When `sponsored` is true, the budget comes from the sponsorship and
    /// `available_value` is not modified. When false, the budget comes
    /// from `available_value` and the consumed ETH is subtracted from it.
    pub(crate) fn activate_account(
        &mut self,
        target_account: Address,
        sponsored: bool,
        sponsored_budget: U256,
        available_value: &mut U256,
    ) -> Result<U256, Vec<u8>> {
        let budget = if sponsored { sponsored_budget } else { *available_value };

        if !sponsored && budget > *available_value {
            return Err(InsufficientValueForActivation {
                required: budget,
                available: *available_value,
            }
            .abi_encode());
        }

        let arb_wasm = IArbWasm::new(ARB_WASM_ADDR);
        let balance_before = self.vm().balance(self.vm().contract_address());

        let activation_call = Call::new_payable(self, budget);
        arb_wasm
            .activate_program(self.vm(), activation_call, target_account)
            .map_err(|_| ActivationFailed {}.abi_encode())?;

        let balance_after = self.vm().balance(self.vm().contract_address());
        let consumed = balance_before.saturating_sub(balance_after);
        if !sponsored {
            *available_value = available_value.saturating_sub(consumed);
        }

        Ok(consumed)
    }

    /// Returns the unused sponsorship budget to the identity.
    ///
    /// The excess ETH is attached as `msg.value` to the call to
    /// `creditIdentityRefund`, which credits the identity's pull-based
    /// refund balance. The identity withdraws it later via
    /// `withdrawRefund` on Economics.
    ///
    /// # Why a single payable call
    ///
    /// Economics validates `msg.value == amount`. Sending the ETH
    /// separately and then calling the credit function would require a
    /// separate accounting channel in Economics. Attaching the value to
    /// the call keeps the interface minimal and self-contained.
    pub(crate) fn return_sponsorship_excess(
        &mut self,
        identity: Address,
        excess: U256,
    ) -> Result<(), Vec<u8>> {
        if excess == U256::ZERO || KIPIO_ECONOMICS == Address::ZERO {
            return Ok(());
        }

        let economics = IKipioBootstrapFunding::new(KIPIO_ECONOMICS);
        let call = Call::new_payable(self, excess);
        economics
            .credit_identity_refund(self.vm(), call, identity, excess)
            .map_err(|_| TransferFailed {}.abi_encode())?;

        self.vm().log(SponsorshipExcessReturned {
            identity,
            amount: excess,
        });
        Ok(())
    }
}

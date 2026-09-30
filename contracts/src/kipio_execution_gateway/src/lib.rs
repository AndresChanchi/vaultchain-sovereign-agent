#![cfg_attr(not(any(test, feature = "export-abi")), no_main)]
extern crate alloc;

use alloc::vec::Vec;

use stylus_sdk::{
    abi::Bytes,
    alloy_primitives::{Address, B256, U256},
    alloy_sol_types::{sol, SolError, SolValue},
    call::RawCall,
    deploy::RawDeploy,
    prelude::*,
    storage::StorageAddress,
};

// ===========================================================================
// PROTOCOL CONFIGURATION
// ===========================================================================
//
// The Gateway is immutable. All protocol addresses point to on-chain
// proxies. The actual values are injected at deploy time by the deployment
// tooling and must match the addresses registered in `kipio_protocol_config`.
//
// `kipio_protocol_config` is itself a proxy: updating a module means updating
// its target in that contract, not redeploying the Gateway.

/// @notice Proxy address of the Kipio Runtime orchestrator.
const KIPIO_RUNTIME: Address = Address::new([0u8; 20]);

/// @notice Proxy address of the Kipio Economics contract.
const KIPIO_ECONOMICS: Address = Address::new([0u8; 20]);

/// @notice Proxy address of the Kipio Recovery singleton.
const KIPIO_RECOVERY: Address = Address::new([0u8; 20]);

/// @notice Salt scheme version. Increment only when the salt preimage changes.
const SALT_SCHEME_VERSION: u8 = 1;

/// @notice ArbOS WASM activation precompile (`0x...0071`).
const ARB_WASM_ADDR: Address =
    Address::new([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x71]);

// ===========================================================================
// SHARED DOMAIN BOUNDARY (interfaces only)
// ===========================================================================

pub mod kipio_shared {
    use stylus_sdk::alloy_sol_types::sol;
    use stylus_sdk::prelude::sol_interface;

    sol! {
        /// @notice The execution envelope forwarded to Runtime.
        struct ExecutionEnvelope {
            address caller;
            address execution_account;
            uint256 value;
            bytes payload;
        }
    }

    sol_interface! {
        /// @notice Economics bootstrap funding. The flow is pull-based:
        ///         `fundBootstrap` credits the Gateway's refund balance in
        ///         Economics; `withdrawRefund` transfers the credited ETH
        ///         to the Gateway. `creditIdentityRefund` credits an
        ///         identity's refund balance with attached ETH.
        interface IKipioBootstrapFunding {
            function fundBootstrap(address identity)
                external
                returns (bool sponsored, uint256 allocated_value);
            function withdrawRefund() external;
            function creditIdentityRefund(address identity, uint256 amount)
                external
                payable;
        }

        /// @notice Runtime orchestrator.
        interface IKipioRuntime {
            function dispatch(
                (address, address, uint256, bytes) envelope
            ) external payable returns (bytes);
        }

        /// @notice Sovereign account lifecycle view.
        interface IKipioAccountLifecycle {
            function is_initialized() external view returns (bool);
        }

        /// @notice ArbOS WASM activation precompile.
        interface IArbWasm {
            function activateProgram(address program) external payable;
            function codehashVersion(bytes32 codehash)
                external
                view
                returns (uint16);
        }
    }
}

// ===========================================================================
// ERRORS & EVENTS
// ===========================================================================

sol! {
    // --- EVENTS ---
    event GatewayDeployed(uint8 indexed version);

    event GatewayInvoked(
        address indexed caller,
        address indexed executionAccount,
        bytes32 indexed intentHash
    );

    event ExecutionForwarded(
        address indexed account,
        address indexed runtime,
        uint256 valueForwarded
    );

    event AccountBootstrapped(
        address indexed account,
        address indexed identity,
        bool sponsored,
        uint256 activationSpent
    );

    event BootstrapFunded(
        address indexed identity,
        address indexed sponsor,
        uint256 amount
    );

    event SponsorshipExcessReturned(
        address indexed identity,
        uint256 amount
    );

    event SelfDeployExecuted(
        address indexed account,
        bytes32 indexed salt
    );

    // --- ERRORS ---
    error InvalidGatewayPayload();
    error InvalidExecutionContext(address executionAccount);
    error BootstrapDeploymentFailed();
    error DeploymentAddressMismatch(address expected, address actual);
    error ActivationFailed();
    error InitializationFailed();
    error DispatchFailed();
    error InsufficientValueForActivation(uint256 required, uint256 available);
    error TransferFailed();
}

// ===========================================================================
// PIPELINE ARTIFACTS
// ===========================================================================
//
// `ACCOUNT_INIT_CODE` is the compiled WASM of `kipio_account`. It is
// produced by the build pipeline and included at compile time when the
// `production_build` feature is enabled. Without that feature, the constant
// is empty and the Gateway cannot deploy accounts, which is the expected
// behaviour for tests.
//
// The init code contains only the WASM runtime. Constructor arguments are
// passed separately, as an ABI-encoded call to the constructor entrypoint
// after activation.

#[cfg(feature = "production_build")]
const ACCOUNT_INIT_CODE: &[u8] =
    include_bytes!(concat!(env!("OUT_DIR"), "/kipio_account_init.bin"));

#[cfg(not(feature = "production_build"))]
const ACCOUNT_INIT_CODE: &[u8] = &[];

// ===========================================================================
// GATEWAY
// ===========================================================================

#[storage]
#[entrypoint]
pub struct KipioExecutionGateway {
    /// @dev The Gateway's own address, captured at construction time.
    ///      This is the authoritative source for the `CREATE2` deployer and
    ///      for the EIP-7702 context check. Reading it from storage avoids
    ///      any dependency on tooling-substituted constants for the most
    ///      security-critical check in the contract.
    self_address: StorageAddress,
}

#[public]
impl KipioExecutionGateway {
    // =======================================================================
    // CONSTRUCTOR
    // =======================================================================

    /// @notice Records the Gateway's own address and the salt scheme version.
    /// @dev    The constructor takes no arguments. All protocol addresses are
    ///         compile-time constants that point to on-chain proxies.
    #[constructor]
    pub fn constructor(&mut self) -> Result<(), Vec<u8>> {
        self.self_address.set(self.vm().contract_address());
        self.vm().log(GatewayDeployed {
            version: SALT_SCHEME_VERSION,
        });
        Ok(())
    }

    // =======================================================================
    // EXECUTE — the single user-facing entrypoint
    // =======================================================================

    /// @notice Executes a user intent through the Kipio protocol.
    /// @dev    Flow: resolve the caller's sovereign account, bootstrap it if
    ///         needed, and forward the original payload to Runtime.
    ///
    ///         # Identity model
    ///         The sovereign identity is `msg_sender()` — the originator of
    ///         the intent. Under EIP-7702 this is the EOA (or the relayer
    ///         that represents it). Under a direct call, it is the caller.
    ///
    ///         `contract_address()` is the *execution account*: the EOA that
    ///         runs the delegated code under EIP-7702, or the Gateway itself
    ///         under a direct call.
    ///
    ///         # Value forwarding
    ///         The value forwarded to Runtime is `available_value`, the
    ///         original `msg.value` minus any ETH consumed during account
    ///         activation. The envelope carries the same `available_value`
    ///         so Runtime observes a consistent view.
    #[payable]
    pub fn execute(&mut self, payload: Bytes) -> Result<Vec<u8>, Vec<u8>> {
        // --- 1. Adapter ---
        if payload.is_empty() {
            return Err(InvalidGatewayPayload {}.abi_encode());
        }

        let caller = self.vm().msg_sender();
        let execution_account = self.vm().contract_address();
        let value = self.vm().msg_value();

        if execution_account == Address::ZERO {
            return Err(InvalidExecutionContext { executionAccount: execution_account }
                .abi_encode());
        }

        let intent_hash = alloy_primitives::keccak256(&payload);
        self.vm().log(GatewayInvoked {
            caller,
            executionAccount: execution_account,
            intentHash: intent_hash,
        });

        // --- 2. Discovery ---
        let salt = Self::salt_for(caller);
        let target_account = self.predict_from_salt(salt);

        // --- 3. Bootstrap (idempotent) ---
        let mut available_value = value;
        self.bootstrap_sovereign_account(
            target_account,
            salt,
            caller,
            &mut available_value,
        )?;

        // --- 4. Dispatch ---
        let envelope = (
            caller,
            execution_account,
            available_value,
            payload,
        );

        let runtime = kipio_shared::IKipioRuntime::new(KIPIO_RUNTIME);
        let call_config = Call::new_payable(self, available_value);

        let result = runtime.dispatch(self.vm(), call_config, envelope);

        match result {
            Ok(return_data) => {
                self.vm().log(ExecutionForwarded {
                    account: target_account,
                    runtime: KIPIO_RUNTIME,
                    valueForwarded: available_value,
                });
                Ok(return_data.into())
            }
            Err(stylus_err) => Err(Self::encode_dispatch_error(stylus_err)),
        }
    }

    // =======================================================================
    // SELF-DEPLOY — internal entrypoint for EIP-7702 contexts
    // =======================================================================

    /// @notice Deploys an account with the Gateway as the `CREATE2` deployer.
    /// @dev    Only useful under EIP-7702, where the outer frame runs with
    ///         the EOA as `address(this)`. The self-call forces the deployer
    ///         to be the Gateway, guaranteeing deterministic addresses that
    ///         match direct-call deployments.
    ///
    ///         # Security
    ///         Permissionless by design. The deployment is deterministic by
    ///         salt, and the account constructor validates identity, runtime,
    ///         and recovery addresses. Anyone can deploy an account for any
    ///         identity, but the resulting account is always correctly bound.
    ///
    ///         # Effect
    ///         Runs `CREATE2` with the Gateway as the deployer. The salt must
    ///         be `salt_for(identity)` so the address matches the external
    ///         prediction.
    pub fn self_deploy(&mut self, salt: B256) -> Result<Address, Vec<u8>> {
        let deployer = RawDeploy::new().salt(salt);
        let result = unsafe { deployer.deploy(self.vm(), ACCOUNT_INIT_CODE, U256::ZERO) };
        let addr = result.map_err(|_| BootstrapDeploymentFailed {}.abi_encode())?;
        self.vm().log(SelfDeployExecuted { account: addr, salt });
        Ok(addr)
    }

    // =======================================================================
    // RECEIVE — accepts ETH from pull-based refunds
    // =======================================================================
    //
    // Economics sends ETH via `RawCall` with empty calldata. Without a
    // `#[receive]` handler, the entrypoint reverts on empty calldata and the
    // `withdrawRefund` call fails. The handler does not mutate state: the ETH
    // remains in the Gateway's balance (or the EOA's balance under EIP-7702)
    // and is used for account activation.

    /// @notice Accepts an ETH transfer with empty calldata.
    #[receive]
    fn receive(&mut self) -> Result<(), Vec<u8>> {
        Ok(())
    }

    // =======================================================================
    // PUBLIC VIEWS
    // =======================================================================

    /// @notice Returns the `CREATE2` salt for a given identity.
    /// @dev    The salt is `version || 12 zero bytes || identity`. The
    ///         left-aligned version byte allows future scheme migrations
    ///         without colliding with existing accounts.
    pub fn salt_for(identity: Address) -> B256 {
        let mut salt = [0u8; 32];
        salt[0] = SALT_SCHEME_VERSION;
        salt[12..32].copy_from_slice(identity.as_slice());
        B256::from(salt)
    }

    /// @notice Predicts the sovereign account address for an identity.
    pub fn predict_account(&self, identity: Address) -> Address {
        self.predict_from_salt(Self::salt_for(identity))
    }

    /// @notice Returns the protocol addresses this Gateway is bound to.
    pub fn protocol_addresses(&self) -> (Address, Address, Address, u8) {
        (
            KIPIO_RUNTIME,
            KIPIO_ECONOMICS,
            KIPIO_RECOVERY,
            SALT_SCHEME_VERSION,
        )
    }
}

// ===========================================================================
// INTERNAL — DEPLOY & PREDICT
// ===========================================================================

impl KipioExecutionGateway {
    /// @dev Detects whether execution is happening in an EIP-7702 context.
    ///
    ///      Under a direct call, `contract_address()` is the Gateway. Under
    ///      EIP-7702, the delegated code runs in the EOA's context, so
    ///      `contract_address()` returns the EOA.
    ///
    ///      This check is O(1) and avoids reading the full WASM bytecode.
    #[inline]
    fn is_eip7702_context(&self) -> bool {
        self.vm().contract_address() != self.self_address.get()
    }

    /// @dev Predicts a `CREATE2` address using the Gateway as the deployer.
    #[inline]
    fn predict_from_salt(&self, salt: B256) -> Address {
        let init_code_hash = alloy_primitives::keccak256(ACCOUNT_INIT_CODE);

        let mut buffer = [0u8; 85];
        buffer[0] = 0xff;
        buffer[1..21].copy_from_slice(self.self_address.get().as_slice());
        buffer[21..53].copy_from_slice(salt.as_slice());
        buffer[53..85].copy_from_slice(init_code_hash.as_slice());

        let hash = alloy_primitives::keccak256(&buffer);
        Address::from_slice(&hash[12..32])
    }

    /// @dev Deploys the account. Under EIP-7702, performs a self-call to
    ///      `self_deploy` so that `CREATE2` uses the Gateway as the deployer.
    ///
    ///      The self-call goes through `RawCall` because the high-level
    ///      `Call` builder is designed for cross-contract calls with typed
    ///      interfaces; a self-call with a manually constructed selector
    ///      needs the raw primitive.
    fn deploy_account(&mut self, salt: B256) -> Result<Address, Vec<u8>> {
        if self.is_eip7702_context() {
            let self_addr = self.self_address.get();

            // Selector: keccak256("self_deploy(bytes32)")[0..4]
            let selector = alloy_primitives::keccak256(b"self_deploy(bytes32)");
            let mut call_data = Vec::with_capacity(36);
            call_data.extend_from_slice(&selector[0..4]);
            call_data.extend_from_slice(salt.as_slice());

            let host = self.vm();
            match unsafe { RawCall::new(host).call(self_addr, &call_data) } {
                Ok(return_data) if return_data.len() >= 32 => {
                    Ok(Address::from_slice(&return_data[12..32]))
                }
                _ => Err(BootstrapDeploymentFailed {}.abi_encode()),
            }
        } else {
            let deployer = RawDeploy::new().salt(salt);
            unsafe { deployer.deploy(self.vm(), ACCOUNT_INIT_CODE, U256::ZERO) }
                .map_err(|_| BootstrapDeploymentFailed {}.abi_encode())
        }
    }
}

// ===========================================================================
// INTERNAL — BOOTSTRAP PIPELINE
// ===========================================================================

impl KipioExecutionGateway {
    /// @dev Computes the Stylus constructor selector:
    ///      `keccak256("constructor()")[0..4]`. The selector is fixed; the
    ///      argument list is not part of it. Arguments follow as an
    ///      ABI-encoded parameter list.
    #[inline]
    fn constructor_selector() -> [u8; 4] {
        let h = alloy_primitives::keccak256(b"constructor()");
        [h[0], h[1], h[2], h[3]]
    }

    /// @dev Bootstraps the sovereign account if it is not ready.
    ///
    ///      Pipeline: deploy → activate → call constructor. Each step is
    ///      idempotent, so the function can be called on every `execute`.
    ///
    ///      # Activation detection
    ///      A deployed contract is considered unactivated when
    ///      `codehashVersion` reverts. The revert is the expected signal for
    ///      EVM contracts and for Stylus programs that have not been
    ///      activated yet.
    ///
    ///      # Constructor invocation
    ///      Stylus constructors are not executed automatically during
    ///      activation. After activation, the Gateway calls the constructor
    ///      with ABI-encoded `(identity, runtime, recovery)`. The Stylus SDK
    ///      writes a sentinel after the first successful call, so the
    ///      constructor reverts on subsequent invocations. The Gateway only
    ///      calls it when `is_initialized()` returns `false`.
    fn bootstrap_sovereign_account(
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
            let arb_wasm = kipio_shared::IArbWasm::new(ARB_WASM_ADDR);
            match arb_wasm.codehash_version(self.vm(), Call::new(), codehash) {
                Ok(_version) => {
                    let lifecycle =
                        kipio_shared::IKipioAccountLifecycle::new(target_account);
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

            // Compute the sponsorship excess for return to the identity.
            if sponsored && consumed < activation_budget {
                sponsored_excess = activation_budget - consumed;
            }
        }

        // --- Initialize: call the constructor entrypoint ---
        // Stylus constructors are invoked as a separate call after
        // activation. The selector is fixed; arguments follow as
        // ABI-encoded parameters `(identity, runtime, recovery)`.
        let selector = Self::constructor_selector();
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

        // --- Return sponsorship excess to the identity ---
        if sponsored_excess > U256::ZERO {
            self.return_sponsorship_excess(identity, sponsored_excess)?;
        }

        Ok(())
    }

    /// @dev Requests sponsorship from Economics.
    ///
    ///      The flow is pull-based: `fundBootstrap` credits the Gateway's
    ///      refund balance in Economics, and `withdrawRefund` transfers the
    ///      ETH to the Gateway. The Gateway then uses that ETH for
    ///      activation.
    ///
    ///      # Return value
    ///      `(sponsored, allocated)`. `sponsored` is true only when the ETH
    ///      was successfully withdrawn and is available in the Gateway's
    ///      balance.
    fn request_sponsorship(&mut self, identity: Address) -> (bool, U256) {
        if KIPIO_ECONOMICS == Address::ZERO {
            return (false, U256::ZERO);
        }

        let economics = kipio_shared::IKipioBootstrapFunding::new(KIPIO_ECONOMICS);

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

    /// @dev Activates the account's WASM program.
    ///
    ///      Returns the amount of ETH consumed by the activation, measured
    ///      as the difference in the Gateway's balance before and after.
    ///
    ///      When `sponsored` is true, the budget comes from the sponsorship
    ///      and `available_value` is not modified. When false, the budget
    ///      comes from `available_value` and the consumed ETH is subtracted
    ///      from it.
    fn activate_account(
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

        let arb_wasm = kipio_shared::IArbWasm::new(ARB_WASM_ADDR);
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

    /// @dev Returns the unused sponsorship budget to the identity.
    ///
    ///      The excess ETH is attached as `msg.value` to the call to
    ///      `creditIdentityRefund`, which credits the identity's pull-based
    ///      refund balance. The identity withdraws it later via
    ///      `withdrawRefund` on Economics.
    ///
    ///      # Why a single payable call
    ///      Economics validates `msg.value == amount`. Sending the ETH
    ///      separately and then calling the credit function would require a
    ///      separate accounting channel in Economics. Attaching the value
    ///      to the call keeps the interface minimal and self-contained.
    fn return_sponsorship_excess(
        &mut self,
        identity: Address,
        excess: U256,
    ) -> Result<(), Vec<u8>> {
        if excess == U256::ZERO || KIPIO_ECONOMICS == Address::ZERO {
            return Ok(());
        }

        let economics = kipio_shared::IKipioBootstrapFunding::new(KIPIO_ECONOMICS);
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

    /// @dev Decodes a dispatch error from Runtime into a revert payload.
    #[inline]
    fn encode_dispatch_error(err: stylus_sdk::prelude::errors::Error) -> Vec<u8> {
        match err {
            stylus_sdk::prelude::errors::Error::Revert(data) => data,
            _ => DispatchFailed {}.abi_encode(),
        }
    }
}

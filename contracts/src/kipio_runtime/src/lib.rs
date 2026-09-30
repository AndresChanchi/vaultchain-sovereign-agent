#![cfg_attr(not(any(test, feature = "export-abi")), no_main)]
#![allow(unexpected_cfgs)]

extern crate alloc;

use alloc::vec::Vec;

use kipio_account_bridge::{
    apply_policy_consumption_impl, authorization_can_be_accepted_full_impl,
    authorization_is_structurally_valid_impl, compute_effective_authority_impl,
    valid_execution_context_impl, AccountAbi, AuthorizationAbi, AuthorizationStateAbi,
    CapabilityAbi, CredentialAbi, ExecutionContextAbi, IdentityAbi, PolicyConsumptionAbi,
    SessionAbi, SubjectAbi,
};
use stylus_sdk::{
    abi::Bytes,
    alloy_primitives::{Address, U256},
    alloy_sol_types::{sol, SolError, SolValue},
    call::RawCall,
    prelude::*,
    storage::StorageAddress,
};

// ============================================================================
// MODULE IDENTIFIERS
// ============================================================================
//
// Runtime resolves module addresses through `kipio_protocol_config`
// instead of hardcoding them. This preserves the ability to upgrade
// individual modules without redeploying the runtime.
//
// `MODULE_EXECUTION_ACCOUNT` is special: it does not go through the
// registry because accounts are per-identity and their address is
// derived deterministically by the Execution Gateway via CREATE2. The
// runtime uses `envelope.execution_account` directly for that case.

/// @notice Identity + content ledger module (`kipio_identity_content`).
pub const MODULE_IDENTITY_CONTENT: u8 = 0;

/// @notice Economic coordination module (`kipio_economics`).
pub const MODULE_ECONOMICS: u8 = 1;

/// @notice Guardian-driven recovery module (`kipio_recovery`).
pub const MODULE_RECOVERY: u8 = 2;

/// @notice Sentinel: target is the account that owns the intent.
pub const MODULE_EXECUTION_ACCOUNT: u8 = 255;

// ============================================================================
// DOMAIN TYPES
// ============================================================================

sol! {
    /// @notice The intent payload carried inside the dispatch envelope.
    ///
    /// Runtime decodes this from the `payload` field of the envelope,
    /// runs the Dafny authorization pipeline against the encoded
    /// `AuthorizationAbi`, optionally settles the economic obligation
    /// through `kipio_economics`, and forwards `target_call_data` to
    /// the resolved module.
    ///
    /// # Fields
    ///
    /// - `target_module`: identifier of the module to dispatch to. See
    ///   the `MODULE_*` constants. `MODULE_EXECUTION_ACCOUNT` (255)
    ///   dispatches to the calling account itself.
    ///
    /// - `authorization_abi`: ABI-encoded `AuthorizationAbi`. Runtime
    ///   decodes this and feeds it to the Dafny acceptance pipeline. The
    ///   pipeline reads the AuthorizationState from the account and
    ///   checks provenance, credential status, and effective authority.
    ///
    /// - `identities_abi`: ABI-encoded `IdentityAbi[]`. This is the
    ///   provenance chain that the Dafny model uses to resolve
    ///   transitive delegations. An empty array is valid when the
    ///   authorization does not rely on delegation.
    ///
    /// - `settlement_call_data`: OPTIONAL. ABI-encoded calldata for
    ///   `kipio_economics.settleEconomicObligation(funder, plan_payload)`.
    ///   When non-empty, Runtime forwards the entire `msg.value()` to
    ///   Economics FIRST, and only forwards the target call if the
    ///   settlement succeeds. This is the atomic fee gate: users pay
    ///   exactly once per operation, and if the payment fails the
    ///   target never runs. When empty, Runtime skips the settlement
    ///   step and forwards `msg.value()` to the target module.
    ///
    /// - `target_call_data`: raw calldata for the target module
    ///   (selector || args). Runtime forwards this verbatim, plus the
    ///   EIP-2771 suffix for forwarded-capable modules.
    ///
    /// - `proof_verified`: set by the caller (Gateway or relayer) after
    ///   cryptographically verifying the signature that authorized the
    ///   intent. The Dafny pipeline rejects the authorization if this is
    ///   false.
    struct Intent {
        uint8 target_module;
        bytes authorization_abi;
        bytes identities_abi;
        bytes settlement_call_data;
        bytes target_call_data;
        bool proof_verified;
    }
}

// ============================================================================
// CROSS-CONTRACT INTERFACES
// ============================================================================

sol_interface! {
    /// @title Kipio Account — external interface consumed by Runtime.
    ///
    /// Runtime reads Account's persisted state via
    /// `get_authorization_state()` and delegates state transitions to
    /// Account's mutating entrypoints.
    interface IKipioAccount {
        function get_identity_id() external view returns (address);
        function get_authorization_state() external view returns (AuthorizationStateAbi);
        function is_initialized() external view returns (bool);
        function get_nonce() external view returns (uint64);
        function valid_account() external view returns (bool);
        function valid_authorization_state() external view returns (bool);

        function register_credential(CredentialAbi credential) external returns (bool);
        function register_session(SessionAbi session) external returns (bool);
        function add_capability(CapabilityAbi capability) external returns (bool);
        function consume_replay_key(bytes replay_key) external returns (bool);
    }

    /// @title Protocol Configuration Registry.
    ///
    /// Runtime reads module addresses from this registry on every
    /// dispatch, so that modules can be upgraded by updating the
    /// registry — without redeploying the runtime. The registry uses
    /// per-module getters (one per operational module) rather than a
    /// generic `getModule(uint8)`, keeping each lookup explicit and
    /// type-safe at the ABI level.
    interface IKipioProtocolConfig {
        function getRuntimeAddress() external view returns (address);
        function getEconomicsAddress() external view returns (address);
        function getIdentityContentAddress() external view returns (address);
        function getRecoveryAddress() external view returns (address);
    }
}

// ============================================================================
// ERRORS & EVENTS
// ============================================================================

sol! {
    // --- EVENTS ---

    event RuntimeDeployed(address indexed protocolConfig);

    /// @notice Emitted on every successful dispatch.
    ///
    /// `targetModule` is the intent's declared module id.
    /// `target` is the resolved address of the module that received the
    /// forwarded call. Together they let indexers reconstruct the
    /// routing decision without reading the intent payload.
    event ExecutionDispatched(
        address indexed caller,
        address indexed executionAccount,
        uint8 targetModule,
        address target,
        bool authorized
    );

    /// @notice Emitted after a successful settlement step.
    ///
    /// Only fires when the intent carried a non-empty
    /// `settlement_call_data`. The `settlementTarget` is the resolved
    /// address of `kipio_economics`. The value forwarded is recorded so
    /// off-chain consumers can reconstruct the exact fee flow without
    /// reading the settlement calldata.
    event SettlementOrchestrated(
        address indexed caller,
        address indexed settlementTarget,
        uint256 valueForwarded
    );

    // --- ERRORS ---

    error ProtocolConfigNotSet();
    error InvalidEnvelope();
    error EmptyPayload();
    error IntentDecodeFailed();
    error UnknownModule(uint8 moduleId);
    error ModuleAddressNotConfigured(uint8 moduleId);
    error AuthorizationDenied();
    error AccountStateReadFailed();
    error SettlementFailed();
    error TargetCallFailed();
    error ConfigQueryFailed();
}

// ============================================================================
// STORAGE
// ============================================================================

#[storage]
#[entrypoint]
pub struct KipioRuntime {
    /// @notice Address of the protocol configuration registry.
    ///
    /// Set once at construction. The registry is immutable in the sense
    /// that the runtime never overwrites its address; individual module
    /// addresses are read through it on every dispatch.
    protocol_config: StorageAddress,
}

// ============================================================================
// PUBLIC INTERFACE
// ============================================================================

#[public]
impl KipioRuntime {
    // ========================================================================
    // CONSTRUCTOR
    // ========================================================================

    /// @notice Binds the runtime to the protocol configuration registry.
    ///
    /// @dev The runtime is deployed once by the deployer. It needs to
    ///      know where the registry lives so it can resolve module
    ///      addresses dynamically.
    #[constructor]
    pub fn constructor(&mut self, protocol_config: Address) -> Result<(), Vec<u8>> {
        if protocol_config == Address::ZERO {
            return Err(ProtocolConfigNotSet {}.abi_encode());
        }
        self.protocol_config.set(protocol_config);
        self.vm().log(RuntimeDeployed {
            protocolConfig: protocol_config,
        });
        Ok(())
    }

    // ========================================================================
    // DISPATCH — MAIN ORCHESTRATION ENTRYPOINT
    // ========================================================================

    /// @notice Orchestrates a user intent end-to-end.
    ///
    /// @dev The Execution Gateway calls this once per user intent.
    ///      Runtime:
    ///
    ///        1. Validates the envelope and decodes the intent payload.
    ///        2. Reads the target account's AuthorizationState.
    ///        3. Runs the Dafny authorization pipeline (structural
    ///           validity plus full acceptance with provenance). If
    ///           either check fails, the entire dispatch reverts.
    ///        4. If the intent carries a settlement call, forwards the
    ///           entire `msg.value()` to `kipio_economics` BEFORE the
    ///           target. This is the atomic fee gate: users pay exactly
    ///           once per operation, and a failed payment aborts the
    ///           whole dispatch.
    ///        5. Resolves the target module address through the
    ///           protocol config, or uses the account itself when
    ///           `target_module == MODULE_EXECUTION_ACCOUNT`.
    ///        6. Appends the EIP-2771 suffix when the target module
    ///           expects it. Currently only `kipio_identity_content`
    ///           supports forwarding; the suffix carries the effective
    ///           user so the module can enforce its own Model B gate.
    ///        7. Forwards the target calldata with whatever value
    ///           remains after settlement (zero if settlement ran).
    ///        8. Returns the target's return data verbatim.
    ///
    /// # Atomicity
    ///
    ///      Everything in this function runs in a single transaction.
    ///      If any step reverts, the entire dispatch reverts — including
    ///      any state changes made by the target module, and any
    ///      settlement credit already recorded in Economics. The user
    ///      either gets a complete execution or none at all.
    ///
    /// # Fee handling
    ///
    ///      Runtime does not charge fees directly. When the intent
    ///      carries `settlement_call_data`, Runtime forwards the whole
    ///      `msg.value()` to Economics, which performs its own pricing,
    ///      pays the storage provider, applies the protocol fee, and
    ///      credits any excess to the funder's pull-based refund
    ///      balance. The target module never sees the value; it just
    ///      executes the business operation that the settled payment
    ///      authorized. This keeps Runtime a pure orchestrator and
    ///      preserves the "single atomic transaction per user action"
    ///      guarantee.
    ///
    /// # Reentrancy
    ///
    ///      Stylus SDK 0.10.5+ disables reentrancy at the runtime
    ///      level. Both the settlement call and the target forward use
    ///      `RawCall`, which is not reentrant by construction. Runtime
    ///      does not maintain any state that a reentrant call could
    ///      observe inconsistently.
    ///
    /// # Why a tuple
    ///
    ///      The Gateway sends the envelope as a Solidity tuple
    ///      `(address, address, uint256, bytes)`. The `#[public]` macro
    ///      cannot synthesize the `AbiType` bound for a `sol!` struct
    ///      parameter, so the parameter is expressed as a Rust tuple
    ///      that implements the required traits directly. The generated
    ///      selector matches the Gateway's call byte-for-byte.
    #[payable]
    pub fn dispatch(
        &mut self,
        envelope: (Address, Address, U256, Bytes),
    ) -> Result<Vec<u8>, Vec<u8>> {
        let (caller, execution_account, _value, payload) = envelope;

        // --- 1. Validate envelope ---
        if caller == Address::ZERO || execution_account == Address::ZERO {
            return Err(InvalidEnvelope {}.abi_encode());
        }
        if payload.is_empty() {
            return Err(EmptyPayload {}.abi_encode());
        }

        // --- 2. Decode intent ---
        let intent =
            Intent::abi_decode(&payload).map_err(|_| IntentDecodeFailed {}.abi_encode())?;

        // --- 3. Read account state ---
        let state = self.read_account_state(execution_account)?;

        // --- 4. Dafny authorization pipeline ---
        let account = self.build_account_abi(execution_account, state);

        let auth = AuthorizationAbi::abi_decode(&intent.authorization_abi)
            .map_err(|_| IntentDecodeFailed {}.abi_encode())?;

        let identities = Vec::<IdentityAbi>::abi_decode(&intent.identities_abi)
            .map_err(|_| IntentDecodeFailed {}.abi_encode())?;

        if !authorization_is_structurally_valid_impl(&auth) {
            return Err(AuthorizationDenied {}.abi_encode());
        }

        let now = U256::from(self.vm().block_timestamp());
        if !authorization_can_be_accepted_full_impl(
            &auth,
            &account,
            &identities,
            now,
            intent.proof_verified,
        ) {
            return Err(AuthorizationDenied {}.abi_encode());
        }

        // --- 5. Settlement (atomic fee gate, optional) ---
        //
        // When the intent carries settlement calldata, forward the
        // entire `msg.value()` to Economics BEFORE the target module.
        // The settlement call is expected to:
        //
        //   - resolve the funder (via EIP-2771 suffix appended by the
        //     frontend, or via a funder parameter in the calldata),
        //   - pay the storage provider,
        //   - apply the protocol fee to the treasury,
        //   - credit any excess to the funder's pull-based refund
        //     balance.
        //
        // If the settlement reverts (no value, no credit, no sponsor,
        // quote mismatch), the entire dispatch reverts atomically and
        // the target module never runs. The user cannot accidentally
        // execute a business operation without first satisfying its
        // economic obligation.
        //
        // When the intent does NOT carry settlement calldata, Runtime
        // skips this step and forwards `msg.value()` to the target
        // module unchanged. This is the path for operations that do
        // not incur a protocol fee (e.g. reading state, or a business
        // operation already covered by prepaid credit that is debited
        // internally by the target module).
        //
        // `value_remaining` is what gets forwarded to the target:
        // zero when settlement ran (Economics consumes the whole
        // amount), or the original `msg.value()` when it did not.
        let value_remaining = self.maybe_settle(
            caller,
            &intent.settlement_call_data,
        )?;

        // --- 6. Resolve target module ---
        let target = self.resolve_target(intent.target_module, execution_account)?;

        // --- 7. Append EIP-2771 suffix for forwarded-capable modules ---
        //
        // The suffix is the effective user (20 bytes). Modules that
        // declare Model B + EIP-2771 strip this suffix and use it as the
        // caller's authority. Modules that do not support forwarding
        // receive the raw calldata.
        let calldata = if Self::module_supports_eip2771(intent.target_module) {
            Self::append_eip2771_suffix(&intent.target_call_data, caller)
        } else {
            intent.target_call_data.to_vec()
        };

        // --- 8. Forward call ---
        self.vm().log(ExecutionDispatched {
            caller,
            executionAccount: execution_account,
            targetModule: intent.target_module,
            target,
            authorized: true,
        });

        let result =
            unsafe { RawCall::new_with_value(self.vm(), value_remaining).call(target, &calldata) };

        result.map_err(|_| TargetCallFailed {}.abi_encode())
    }

    // ========================================================================
    // VIEWS
    // ========================================================================

    /// @notice Sanity check.
    pub fn ping(&self) -> bool {
        true
    }

    /// @notice Returns the configured protocol config address.
    pub fn get_protocol_config(&self) -> Address {
        self.protocol_config.get()
    }

    /// @notice Resolves a module address through the protocol config.
    ///
    /// @dev For `MODULE_EXECUTION_ACCOUNT` this reverts, because the
    ///      account address is per-identity and must be passed through
    ///      the envelope. Callers that want to resolve an account
    ///      address should use the Execution Gateway's
    ///      `predictAccount(identity)` view.
    pub fn get_module_address(&self, module_id: u8) -> Result<Address, Vec<u8>> {
        if module_id == MODULE_EXECUTION_ACCOUNT {
            return Err(UnknownModule { moduleId: module_id }.abi_encode());
        }
        self.resolve_module(module_id)
    }

    // ========================================================================
    // CROSS-CONTRACT STATE READS
    // ========================================================================

    /// @notice Reads the AuthorizationState from a deployed Account contract.
    ///
    /// This is the canonical cross-contract entrypoint: Runtime does not
    /// receive AccountAbi as a parameter, it reads it from the Account.
    pub fn read_account_state(
        &self,
        account_addr: Address,
    ) -> Result<AuthorizationStateAbi, Vec<u8>> {
        let account = IKipioAccount::new(account_addr);
        let call = Call::new();
        account
            .get_authorization_state(self.vm(), call)
            .map_err(|_| AccountStateReadFailed {}.abi_encode())
    }

    // ========================================================================
    // AUTHORIZATION VALIDATION
    // ========================================================================

    /// @notice Structural validity of an Authorization (gate before acceptance).
    pub fn authorization_is_structurally_valid(&self, auth: AuthorizationAbi) -> bool {
        authorization_is_structurally_valid_impl(&auth)
    }

    /// @notice Full authorization acceptance with provenance.
    ///
    /// Reads the Account state cross-contract, then runs the Dafny-derived
    /// acceptance logic locally.
    pub fn authorization_can_be_accepted_full(
        &self,
        account_addr: Address,
        auth: AuthorizationAbi,
        identities: Vec<IdentityAbi>,
        now: U256,
        proof_verified: bool,
    ) -> Result<bool, Vec<u8>> {
        let state = self.read_account_state(account_addr)?;
        let account = self.build_account_abi(account_addr, state);

        Ok(authorization_can_be_accepted_full_impl(
            &auth,
            &account,
            &identities,
            now,
            proof_verified,
        ))
    }

    // ========================================================================
    // EFFECTIVE AUTHORITY
    // ========================================================================

    /// @notice Computes the canonical EffectiveAuthority for an Account.
    pub fn compute_effective_authority(
        &self,
        account_addr: Address,
        identities: Vec<IdentityAbi>,
        now: U256,
    ) -> Result<Vec<CapabilityAbi>, Vec<u8>> {
        let state = self.read_account_state(account_addr)?;
        let account = self.build_account_abi(account_addr, state);

        Ok(compute_effective_authority_impl(
            &account,
            &identities,
            now,
        ))
    }

    // ========================================================================
    // POLICY CONSUMPTION
    // ========================================================================

    /// @notice Applies a PolicyConsumption to an Account via cross-contract call.
    ///
    /// @dev This endpoint only evaluates applicability. The actual state
    ///      persistence happens inside Account's mutating entrypoints.
    ///      Callers that want to apply the policy should use the
    ///      `dispatch` entrypoint with a target pointing at the account.
    pub fn apply_policy_consumption(
        &self,
        account_addr: Address,
        consumption: PolicyConsumptionAbi,
    ) -> Result<bool, Vec<u8>> {
        let state = self.read_account_state(account_addr)?;
        let account = self.build_account_abi(account_addr, state);

        let (_, applied) = apply_policy_consumption_impl(&account, &consumption);
        Ok(applied)
    }

    // ========================================================================
    // EXECUTION BOUNDARY
    // ========================================================================

    /// @notice Validates a complete ExecutionContext against a deployed Account.
    pub fn valid_execution_context(
        &self,
        account_addr: Address,
        context: ExecutionContextAbi,
        identities: Vec<IdentityAbi>,
        proof_verified: bool,
    ) -> Result<bool, Vec<u8>> {
        let state = self.read_account_state(account_addr)?;
        let account = self.build_account_abi(account_addr, state);

        Ok(valid_execution_context_impl(
            &context,
            &account,
            &identities,
            proof_verified,
        ))
    }
}

// ============================================================================
// INTERNAL HELPERS
// ============================================================================

impl KipioRuntime {
    /// @dev Builds an AccountAbi from a cross-contract read.
    fn build_account_abi(
        &self,
        account_addr: Address,
        state: AuthorizationStateAbi,
    ) -> AccountAbi {
        let id_bytes = Bytes::from(account_addr.to_vec());
        AccountAbi {
            id: id_bytes.clone(),
            identity: IdentityAbi {
                id: id_bytes.clone(),
                subject: SubjectAbi {
                    reference: id_bytes,
                },
            },
            authorizationState: state,
        }
    }

    /// @dev Optional settlement step.
    ///
    /// When `settlement_call_data` is empty, returns the original
    /// `msg.value()` unchanged so that the target module receives the
    /// full value.
    ///
    /// When `settlement_call_data` is non-empty, forwards the entire
    /// `msg.value()` to `kipio_economics` and returns `U256::ZERO`. The
    /// settlement call is expected to handle its own pricing, pay the
    /// storage provider, apply the protocol fee, and credit any excess
    /// to the funder's refund balance.
    ///
    /// On success, emits `SettlementOrchestrated`. On failure, bubbles
    /// up `SettlementFailed` and aborts the whole dispatch.
    fn maybe_settle(
        &mut self,
        caller: Address,
        settlement_call_data: &Bytes,
    ) -> Result<U256, Vec<u8>> {
        let value = self.vm().msg_value();

        if settlement_call_data.is_empty() {
            return Ok(value);
        }

        let economics = self.resolve_module(MODULE_ECONOMICS)?;
        let host = self.vm();

        let result = unsafe {
            RawCall::new_with_value(host, value).call(economics, settlement_call_data)
        };
        result.map_err(|_| SettlementFailed {}.abi_encode())?;

        self.vm().log(SettlementOrchestrated {
            caller,
            settlementTarget: economics,
            valueForwarded: value,
        });

        // The settlement consumed the whole value. The target module
        // receives zero and executes the business operation that the
        // settled payment authorized.
        Ok(U256::ZERO)
    }

    /// @dev Resolves the target address for a dispatch.
    ///
    /// `MODULE_EXECUTION_ACCOUNT` short-circuits to the execution
    /// account carried in the envelope. Every other module id goes
    /// through the protocol config registry.
    fn resolve_target(
        &self,
        module_id: u8,
        execution_account: Address,
    ) -> Result<Address, Vec<u8>> {
        if module_id == MODULE_EXECUTION_ACCOUNT {
            if execution_account == Address::ZERO {
                return Err(InvalidEnvelope {}.abi_encode());
            }
            return Ok(execution_account);
        }
        self.resolve_module(module_id)
    }

    /// @dev Resolves a singleton module address through the registry.
    ///
    /// Uses per-module getters that mirror the naming convention
    /// established by `kipio_identity_content` (`getRuntimeAddress`).
    /// Adding a new operational module requires adding a new arm here
    /// and a matching getter in `kipio_protocol_config`.
    fn resolve_module(&self, module_id: u8) -> Result<Address, Vec<u8>> {
        let config_addr = self.protocol_config.get();
        if config_addr == Address::ZERO {
            return Err(ProtocolConfigNotSet {}.abi_encode());
        }

        let config = IKipioProtocolConfig::new(config_addr);
        let call = Call::new();

        let target = match module_id {
            MODULE_IDENTITY_CONTENT => config
                .get_identity_content_address(self.vm(), call)
                .map_err(|_| ConfigQueryFailed {}.abi_encode())?,
            MODULE_ECONOMICS => config
                .get_economics_address(self.vm(), call)
                .map_err(|_| ConfigQueryFailed {}.abi_encode())?,
            MODULE_RECOVERY => config
                .get_recovery_address(self.vm(), call)
                .map_err(|_| ConfigQueryFailed {}.abi_encode())?,
            _ => return Err(UnknownModule { moduleId: module_id }.abi_encode()),
        };

        if target == Address::ZERO {
            return Err(ModuleAddressNotConfigured { moduleId: module_id }.abi_encode());
        }
        Ok(target)
    }

    /// @dev Whether a module consumes the EIP-2771 suffix.
    ///
    /// Currently only `kipio_identity_content` supports forwarding.
    /// When more modules adopt the pattern, add their ids here.
    #[inline]
    fn module_supports_eip2771(module_id: u8) -> bool {
        module_id == MODULE_IDENTITY_CONTENT
    }

    /// @dev Appends the EIP-2771 suffix (20-byte effective user) to a
    ///      target calldata.
    ///
    /// The suffix is the raw 20-byte address, no padding. Target
    /// modules strip it before decoding their arguments.
    #[inline]
    fn append_eip2771_suffix(calldata: &[u8], user: Address) -> Vec<u8> {
        let mut out = Vec::with_capacity(calldata.len() + 20);
        out.extend_from_slice(calldata);
        out.extend_from_slice(user.as_slice());
        out
    }
}

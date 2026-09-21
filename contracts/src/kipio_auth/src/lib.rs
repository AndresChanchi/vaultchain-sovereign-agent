#![allow(unexpected_cfgs)]
#![cfg_attr(not(feature = "std"), no_std)]

extern crate alloc;

use alloc::{vec, vec::Vec};

use stylus_sdk::{
    abi::Bytes,
    alloy_primitives::{address, Address, B256, U256},
    call::static_call,
    crypto::keccak,
    prelude::*,
    storage::{StorageAddress, StorageB256, StorageMap, StorageU256},
};

// ============================================================================
// EXTERNAL INTERFACES
// ============================================================================

sol_interface! {
    /// @title External Cryptographic Verifier Interface
    /// @notice Outlines the standard validation boundary implemented by external curve modules.
    interface IKipioAuthVerifier {
        function verify(
            address user,
            bytes32 digest,
            bytes signature,
            bytes pubkey,
            uint256 curve
        ) external returns (bool);
    }

    /// @title Protocol Configuration Manager Interface
    /// @notice Centralized administrative hub and source of truth for protocol infrastructure.
    interface IKipioProtocolConfig {
        function getVerifier(uint256 curve_id) external view returns (address);
        function getCurveStatus(uint256 curve_id) external view returns (uint256);
        function isAuthorizedLedger(address ledger) external view returns (bool);
    }

    /// @title External Policy Ledger Interface
    /// @notice This interface intentionally exposes a stable semantic view.
    ///
    /// Auth depends on policy semantics,
    /// not on the storage layout of any particular policy engine.
    ///
    /// Recovery,
    /// Enterprise Approval,
    /// Agent Governance,
    /// or future policy providers
    /// are free to change their internal implementation
    /// without requiring changes inside Auth,
    /// provided this interface remains stable.
    interface IKipioPolicyLedger {
        function getPolicyRecord(bytes32 request_id) external view returns (
            uint256 status,
            bytes32 policy_type,
            address user,
            bytes32 target_hash,
            uint256 curve,
            uint256 deadline
        );

        function consumePolicy(bytes32 request_id) external;
    }
}

stylus_sdk::alloy_sol_types::sol! {
    event KeyRotatedFromPolicy(address indexed user, address indexed ledger, bytes32 indexed requestId);
}

// ============================================================================
// CONSTANTS
// ============================================================================

// Global Lifecycle Status Enumerations
const STATUS_DISABLED: u64 = 0;
const STATUS_ACTIVE: u64 = 1;

// Standardized Policy Execution States
const POLICY_STATUS_APPROVED: u64 = 1;

/// ------------------------------------------------------------------------
/// RIP-7212 / EIP-7951 P256 PRECOMPILE
/// ------------------------------------------------------------------------
///
/// ArbOS exposes the secp256r1 verifier precompile at:
///
/// 0x0000000000000000000000000000000000000100
///
/// This module intentionally acts as a VERY THIN WRAPPER around that
/// native protocol precompile.
///
/// IMPORTANT:
///
/// - No P256 math is implemented in WASM.
/// - No ASN.1 parsing is implemented here.
/// - No DER decoding is implemented here.
/// - No COSE/WebAuthn parsing is implemented here.
///
/// The goal is:
///
/// - minimal WASM size
/// - native Nitro crypto execution
/// - deterministic calldata
/// - easier auditing
/// - easier future upgrades
///
/// ------------------------------------------------------------------------
/// FRONTEND WARNING
/// ------------------------------------------------------------------------
///
/// IMPORTANT FUTURE NOTE TO MYSELF:
///
/// When building the frontend/passkey integration later:
///
/// DO NOT send browser WebAuthn outputs directly into this contract.
///
/// Browsers/devices usually return:
///
/// - ASN.1 DER encoded signatures
/// - COSE public keys
/// - compressed SEC1 keys
/// - authenticator payload wrappers
///
/// This verifier intentionally DOES NOT parse any of that.
///
/// The frontend layer MUST normalize everything BEFORE calling verify().
///
/// ------------------------------------------------------------------------
/// REQUIRED INPUT FORMAT
/// ------------------------------------------------------------------------
///
/// signature:
/// - exactly 64 bytes
/// - layout:
///     r || s
///
/// pubkey:
/// - exactly 64 bytes
/// - layout:
///     x || y
///
/// digest:
/// - exactly 32 bytes
/// - already hashed
///
/// ------------------------------------------------------------------------
/// NORMALIZATION RULES
/// ------------------------------------------------------------------------
///
/// All values MUST already be:
///
/// - left padded
/// - normalized
/// - big endian encoded
///
/// This module intentionally delegates normalization to the frontend
/// to keep WASM extremely small and rely entirely on native ArbOS crypto.
///
/// ------------------------------------------------------------------------
/// EIP-7951 CALLDATA FORMAT
/// ------------------------------------------------------------------------
///
/// The precompile expects EXACTLY 160 bytes:
///
/// [ digest | r | s | qx | qy ]
///
/// Layout:
///
/// 32 bytes -> digest
/// 32 bytes -> signature.r
/// 32 bytes -> signature.s
/// 32 bytes -> pubkey.x
/// 32 bytes -> pubkey.y
///
/// ------------------------------------------------------------------------
/// RETURN SEMANTICS
/// ------------------------------------------------------------------------
///
/// VALID SIGNATURE:
/// - returns 32 bytes
/// - last byte == 1
///
/// INVALID SIGNATURE / MALFORMED INPUT:
/// - returns empty bytes
///
/// This behavior is defined by EIP-7951.
/// ------------------------------------------------------------------------
const P256_VERIFY_PRECOMPILE: Address =
    address!("0000000000000000000000000000000000000100");

// ============================================================================
// STORAGE + ENTRYPOINT
// ============================================================================

/// @title Kipio Sovereign Identity Registry Ledger
/// @notice Core persistent canonical truth provider binding logical actors to cryptographic key fingerprints.
///
/// MERGED MODULE:
///
/// This contract also embeds the RIP-7212 / EIP-7951 P256 verification path
/// (previously deployed as a separate `KipioAuthVerifierP256` contract).
/// The `verify` entrypoint below is byte-for-byte equivalent to the standalone
/// verifier semantics: no crypto in WASM, only a static call into the ArbOS
/// native secp256r1 precompile. This fusion removes one cross-contract call
/// per signature verification while preserving the cryptographic boundary.
///
/// DESIGN PHILOSOPHY & ARCHITECTURAL BOUNDARIES:
/// - Auth is NOT a cryptographic engine, passkey implementation, or curve-specific solver (P256, K256, ML-DSA).
/// - It acts strictly as an Identity Anchor answering: "Which cryptographic identity coordinates currently belong to this actor?"
/// - Curve-specific parsing (ASN.1, DER, COSE, SEC1) is completely delegated to frontend adapters or external verifiers.
/// - This module remains permanent, decoupled, and stable across future cryptographic algorithm or curve migrations.
///
/// CONSUMPTION MODEL:
/// Downstream modules (Recovery, Agents, B2B, Account Abstraction) consume this ledger exclusively to resolve identity
/// ownership proofs. The less often this contract changes, the healthier and more auditable the ecosystem architecture becomes.
///
/// POLICY EXECUTION MODEL:
/// Auth never determines whether a policy should be approved.
/// It only verifies that:
///
/// - the policy ledger is trusted;
/// - the policy exists;
/// - the policy is approved;
/// - the policy type matches the requested state transition;
/// - the target payload matches the identity mutation.
///
/// Once those conditions are satisfied,
/// Auth executes the identity mutation because Auth
/// remains the canonical source of truth.
#[storage]
#[entrypoint]
pub struct KipioAuth {
    /// @notice Centralized administrative configuration provider.
    pub protocol_config: StorageAddress,

    /// @notice Maps user logical addresses to their active cryptographic public key fingerprint: keccak256(pubkey).
    pub pubkeys: StorageMap<Address, StorageB256>,

    /// @notice Maps user logical addresses to their active monotonic cryptographic curve identifier tier.
    pub curves: StorageMap<Address, StorageU256>,

    /// @notice Identity-level anti-replay protection tracking the latest approved transaction sequence.
    /// @dev This nonce represents the latest authorized structural identity action, NOT a frontend login or web session.
    pub nonces: StorageMap<Address, StorageU256>,

    /// @notice Cached global domain separator structure matching EIP-712 cryptographic specifications.
    pub domain_separator_cache: StorageB256,
}

// ============================================================================
// SHARED HELPERS
// ============================================================================

#[inline(always)]
fn u256_to_bytes32(x: U256) -> [u8; 32] {
    x.to_be_bytes()
}

#[inline(always)]
fn addr_to_bytes32(addr: Address) -> [u8; 32] {
    let mut out = [0u8; 32];
    out[12..].copy_from_slice(addr.as_slice());
    out
}

/// ------------------------------------------------------------------------
/// INTERNAL HELPERS & PRIVATE UTILITIES
/// ------------------------------------------------------------------------
impl KipioAuth {
    /// @dev Internal EIP-712 isolated serialization structure caching mechanism.
    fn get_domain_separator(&mut self) -> B256 {
        let cached = self.domain_separator_cache.get();
        if cached != B256::ZERO {
            return cached;
        }

        let mut enc = Vec::with_capacity(32 * 5);
        let typehash = keccak(
            b"EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

        enc.extend_from_slice(typehash.as_slice());
        enc.extend_from_slice(keccak(b"KIPIO_AUTH").as_slice());
        enc.extend_from_slice(keccak(b"1").as_slice());

        let chain_id = U256::from(self.vm().chain_id());
        enc.extend_from_slice(&u256_to_bytes32(chain_id));

        let contract_addr = self.vm().contract_address();
        enc.extend_from_slice(&addr_to_bytes32(contract_addr));

        let domain = keccak(&enc);
        self.domain_separator_cache.set(domain);

        domain
    }

    /// @dev Formats typed structured envelopes explicitly isolated for EIP-712 operations.
    fn build_verify_digest(
        &mut self,
        user: Address,
        msg_hash: B256,
        nonce: U256,
        deadline: U256,
        curve_id: U256,
    ) -> B256 {
        let mut enc = Vec::with_capacity(32 * 6);
        let typehash = keccak(
            b"Verify(address user,bytes32 msgHash,uint256 nonce,uint256 deadline,uint256 curve)"
        );

        enc.extend_from_slice(typehash.as_slice());
        enc.extend_from_slice(&addr_to_bytes32(user));
        enc.extend_from_slice(msg_hash.as_slice());
        enc.extend_from_slice(&u256_to_bytes32(nonce));
        enc.extend_from_slice(&u256_to_bytes32(deadline));
        enc.extend_from_slice(&u256_to_bytes32(curve_id));

        let struct_hash = keccak(&enc);

        let mut final_data = Vec::with_capacity(66);
        final_data.extend_from_slice(b"\x19\x01");
        let domain_sep = self.get_domain_separator();
        final_data.extend_from_slice(domain_sep.as_slice());
        final_data.extend_from_slice(struct_hash.as_slice());

        keccak(&final_data)
    }

    /// @dev Formats typed structured envelopes explicitly isolated for Key Rotation cryptographic signatures.
    fn build_rotate_digest(
        &mut self,
        user: Address,
        new_pubkey_hash: B256,
        new_curve: U256,
        nonce: U256,
        deadline: U256,
    ) -> B256 {
        let mut enc = Vec::with_capacity(32 * 6);
        let typehash = keccak(
            b"Rotate(address user,bytes32 newPubkeyHash,uint256 newCurve,uint256 nonce,uint256 deadline)"
        );

        enc.extend_from_slice(typehash.as_slice());
        enc.extend_from_slice(&addr_to_bytes32(user));
        enc.extend_from_slice(new_pubkey_hash.as_slice());
        enc.extend_from_slice(&u256_to_bytes32(new_curve));
        enc.extend_from_slice(&u256_to_bytes32(nonce));
        enc.extend_from_slice(&u256_to_bytes32(deadline));

        let struct_hash = keccak(&enc);

        let mut final_data = Vec::with_capacity(66);
        final_data.extend_from_slice(b"\x19\x01");
        let domain_sep = self.get_domain_separator();
        final_data.extend_from_slice(domain_sep.as_slice());
        final_data.extend_from_slice(struct_hash.as_slice());

        keccak(&final_data)
    }

    /// @dev Routes calldata execution vectors to external cryptographic validating contract instances.
    /// Reads the verifier mapping dynamically from the Protocol Configuration Hub.
    fn call_verifier(
        &mut self,
        user: Address,
        digest: B256,
        signature: Vec<u8>,
        pubkey: Vec<u8>,
        curve_id: U256,
    ) -> Result<(), Vec<u8>> {
        let config_addr = self.protocol_config.get();
        if config_addr == Address::ZERO {
            return Err(b"ProtocolConfigNotSet".to_vec());
        }

        let config = IKipioProtocolConfig::new(config_addr);
        let host = self.vm();

        let verifier_addr = config
            .get_verifier(host, Call::new(), curve_id)
            .map_err(|_| b"ConfigQueryFailed".to_vec())?;

        if verifier_addr == Address::ZERO {
            return Err(b"VerifierNotSetForCurve".to_vec());
        }

        let verifier = IKipioAuthVerifier::new(verifier_addr);
        let cfg = Call::new_mutating(self);

        let ok = verifier
            .verify(
                self.vm(),
                cfg,
                user,
                digest,
                Bytes::from(signature),
                Bytes::from(pubkey),
                curve_id,
            )
            .map_err(|_| b"VerifierCallFailed".to_vec())?;

        if !ok {
            return Err(b"VerifyFail".to_vec());
        }

        Ok(())
    }
}

/// ------------------------------------------------------------------------
/// EXTERNAL PUBLIC INTERFACE BOUNDARY
/// ------------------------------------------------------------------------
#[public]
impl KipioAuth {
    // ------------------------------------------------------------------------
    // KIPIO AUTH — IDENTITY LEDGER INTERFACE
    // ------------------------------------------------------------------------

    /// @notice Links this identity ledger to the universal protocol configuration provider.
    /// @dev May only be executed once during deployment setup.
    /// @param protocol_config Deployed address of the KipioProtocolConfig contract.
    pub fn initialize(&mut self, protocol_config: Address) -> Result<(), Vec<u8>> {
        if protocol_config == Address::ZERO {
            return Err(b"ZeroAddressConfig".to_vec());
        }
        if self.protocol_config.get() != Address::ZERO {
            return Err(b"AlreadyInitialized".to_vec());
        }
        self.protocol_config.set(protocol_config);
        Ok(())
    }

    /// @notice Registers an initial permanent sovereign relationship binding an actor to a public key hash.
    /// @param pubkey Raw big-endian unparsed cryptographic public identity coordinates.
    /// @param curve Selected mathematical curve identifier framework.
    pub fn register(&mut self, pubkey: Vec<u8>, curve: U256) -> Result<(), Vec<u8>> {
        let sender = self.vm().msg_sender();

        if pubkey.is_empty() {
            return Err(b"EmptyKey".to_vec());
        }

        if self.pubkeys.getter(sender).get() != B256::ZERO {
            return Err(b"AlreadyRegistered".to_vec());
        }

        let config_addr = self.protocol_config.get();
        if config_addr == Address::ZERO {
            return Err(b"ProtocolConfigNotSet".to_vec());
        }

        // Consult administrative state dynamically
        let config = IKipioProtocolConfig::new(config_addr);
        let call_ctx = Call::new();
        let host = self.vm();

        let verifier = config
            .get_verifier(host, Call::new(), curve)
            .map_err(|_| b"ConfigQueryFailed".to_vec())?;

        if verifier == Address::ZERO {
            return Err(b"VerifierNotSetForCurve".to_vec());
        }

        let status_val = config
            .get_curve_status(host, call_ctx, curve)
            .map_err(|_| b"ConfigQueryFailed".to_vec())?;

        // Registration is strictly limited to active curves
        match status_val.as_limbs()[0] {
            STATUS_ACTIVE => {}
            _ => return Err(b"CurveNotActiveForRegistration".to_vec()),
        }

        self.pubkeys.setter(sender).set(keccak(pubkey.as_slice()));
        self.curves.setter(sender).set(curve);
        self.nonces.setter(sender).set(U256::ZERO);

        Ok(())
    }

    /// @notice Proves that the registered cryptographic identity explicitly approved a specific business action.
    ///
    /// CRITICAL SEMANTIC DEFINITION FOR FUTURE INVOCATIONS & AI AGENTS:
    /// - This function is NOT a frontend login, an application session initialization, or a web access log.
    /// - VERIFY_IDENTITY_AUTHORIZATION MEANS: "Cryptographically prove that the registered sovereign identity approved this high-value structured intent payload".
    ///
    /// @param user Target logical entity address whose identity registry maps are queried.
    /// @param msg_hash Bound structural action target hash scheduled for verification approval.
    /// @param signature Normalized, big-endian signature block passed down from frontend layers (`r || s`).
    /// @param pubkey Normalized coordinates validating matching identity persistent storage fingerprints (`x || y`).
    /// @param nonce Current active replay protection nonce tracking value for identity state mutations.
    /// @param deadline Absolute block timestamp expiration threshold capping transaction execution windows.
    pub fn verify_identity_authorization(
        &mut self,
        user: Address,
        msg_hash: B256,
        signature: Vec<u8>,
        pubkey: Vec<u8>,
        nonce: U256,
        deadline: U256,
    ) -> Result<bool, Vec<u8>> {
        if signature.is_empty() {
            return Err(b"BadSig".to_vec());
        }

        if pubkey.is_empty() {
            return Err(b"EmptyKey".to_vec());
        }

        let now = U256::from(self.vm().block_timestamp());
        if now > deadline {
            return Err(b"Expired".to_vec());
        }

        let stored_nonce = self.nonces.getter(user).get();
        if nonce != stored_nonce {
            return Err(b"BadNonce".to_vec());
        }

        let stored_hash = self.pubkeys.getter(user).get();
        if keccak(pubkey.as_slice()) != stored_hash {
            return Err(b"InvalidPubkey".to_vec());
        }

        let curve = self.curves.getter(user).get();

        let config_addr = self.protocol_config.get();
        if config_addr == Address::ZERO {
            return Err(b"ProtocolConfigNotSet".to_vec());
        }
        let config = IKipioProtocolConfig::new(config_addr);

        let status_val = config
            .get_curve_status(self.vm(), Call::new(), curve)
            .map_err(|_| b"ConfigQueryFailed".to_vec())?;

        match status_val.as_limbs()[0] {
            STATUS_DISABLED => return Err(b"CurveHardwareDisabled".to_vec()),
            _ => {}
        }

        let digest = self.build_verify_digest(
            user,
            msg_hash,
            nonce,
            deadline,
            curve,
        );

        self.call_verifier(
            user,
            digest,
            signature,
            pubkey,
            curve,
        )?;

        self.nonces.setter(user).set(stored_nonce + U256::from(1));

        Ok(true)
    }

    /// @notice Migrates a user's identity coordinates to a new public key set (Identity Evolution).
    /// @dev Users remain fully sovereign over their identity records; they can rotate keys to adapt to device upgrades.
    pub fn rotate_key(
        &mut self,
        old_pubkey: Vec<u8>,
        new_pubkey: Vec<u8>,
        new_curve: U256,
        signature_from_old: Vec<u8>,
        nonce: U256,
        deadline: U256,
    ) -> Result<(), Vec<u8>> {
        let user = self.vm().msg_sender();

        if old_pubkey.is_empty() || new_pubkey.is_empty() {
            return Err(b"EmptyKey".to_vec());
        }

        let stored_hash = self.pubkeys.getter(user).get();
        if stored_hash == B256::ZERO {
            return Err(b"NotRegistered".to_vec());
        }

        if keccak(old_pubkey.as_slice()) != stored_hash {
            return Err(b"InvalidOldKey".to_vec());
        }

        let stored_nonce = self.nonces.getter(user).get();
        if nonce != stored_nonce {
            return Err(b"BadNonce".to_vec());
        }

        let now = U256::from(self.vm().block_timestamp());
        if now > deadline {
            return Err(b"Expired".to_vec());
        }

        let old_curve = self.curves.getter(user).get();

        let config_addr = self.protocol_config.get();
        if config_addr == Address::ZERO {
            return Err(b"ProtocolConfigNotSet".to_vec());
        }
        let config = IKipioProtocolConfig::new(config_addr);

        // Validate lifecycle state of the current executing curve
        let old_status_val = config
            .get_curve_status(self.vm(), Call::new(), old_curve)
            .map_err(|_| b"ConfigQueryFailed".to_vec())?;

        match old_status_val.as_limbs()[0] {
            STATUS_DISABLED => return Err(b"CurveHardwareDisabled".to_vec()),
            _ => {}
        }

        // Validate lifecycle state of the target destination curve
        let new_status_val = config
            .get_curve_status(self.vm(), Call::new(), new_curve)
            .map_err(|_| b"ConfigQueryFailed".to_vec())?;

        match new_status_val.as_limbs()[0] {
            STATUS_ACTIVE => {}
            _ => return Err(b"TargetCurveNotActive".to_vec()),
        }

        let new_pubkey_hash = keccak(new_pubkey.as_slice());

        let digest = self.build_rotate_digest(
            user,
            new_pubkey_hash,
            new_curve,
            nonce,
            deadline,
        );

        self.call_verifier(
            user,
            digest,
            signature_from_old,
            old_pubkey,
            old_curve,
        )?;

        self.pubkeys.setter(user).set(new_pubkey_hash);
        self.curves.setter(user).set(new_curve);
        self.nonces.setter(user).set(stored_nonce + U256::from(1));

        Ok(())
    }

    /// @notice Consumes a pre-approved authorization policy from an external ledger to orchestrate an identity migration.
    ///
    /// @dev This function is intentionally asymmetric with rotate_key().
    ///
    /// rotate_key()
    /// proves authorization through a cryptographic signature.
    ///
    /// rotate_key_from_policy()
    /// proves authorization through an externally approved policy.
    ///
    /// Both execution paths mutate exactly the same identity state,
    /// preserving Auth as the single source of truth.
    ///
    /// @param policy_ledger The target address of the Policy Ledger contract (e.g., KipioRecovery).
    /// @param request_id Universal 32-byte identifier mapping to the targeted policy record.
    /// @param new_pubkey The full uncompressed public key parameters scheduled for registration.
    pub fn rotate_key_from_policy(
        &mut self,
        policy_ledger: Address,
        request_id: B256,
        new_pubkey: Vec<u8>
    ) -> Result<(), Vec<u8>> {

        let config_addr = self.protocol_config.get();
        if config_addr == Address::ZERO {
            return Err(b"ProtocolConfigNotSet".to_vec());
        }

        let config = IKipioProtocolConfig::new(config_addr);
        let host_view = self.vm();

        // 1. Verify ledger architectural authorization (Dynamic check via config)
        let is_auth = config.is_authorized_ledger(host_view, Call::new(), policy_ledger)
            .map_err(|_| b"ConfigQueryFailed".to_vec())?;

        if !is_auth {
            return Err(b"UnauthorizedLedger".to_vec());
        }

        // 2. Extract operational view from the Policy Engine
        let ledger_client = IKipioPolicyLedger::new(policy_ledger);
        let record = ledger_client.get_policy_record(self.vm(), Call::new(), request_id)
            .map_err(|_| b"LedgerQueryFailed".to_vec())?;

        let (status, policy_type, user, target_hash, curve, deadline) = record;

        // 3. Strict Semantic Validations
        if status != U256::from(POLICY_STATUS_APPROVED) {
            return Err(b"PolicyNotApproved".to_vec());
        }

        // policy_type identifies the semantic meaning of the approved policy.
        // Auth only executes policy types that it explicitly supports.
        // Unknown policy types are rejected, allowing new policy engines to evolve
        // independently without modifying the identity ledger.
        let expected_policy_type = keccak(b"ROTATE_KEY");
        if policy_type != expected_policy_type {
            return Err(b"InvalidPolicyType".to_vec());
        }

        let now = U256::from(self.vm().block_timestamp());
        if now > deadline {
            return Err(b"PolicyExpired".to_vec());
        }

        // 4. Validate injected credentials against the cryptographically approved hash
        if new_pubkey.is_empty() {
            return Err(b"EmptyKey".to_vec());
        }
        let new_pubkey_hash = keccak(new_pubkey.as_slice());

        if new_pubkey_hash != target_hash {
            return Err(b"HashMismatch".to_vec());
        }

        // 5. Target Destination Curve Lifecycle Validations
        let new_status_val = config.get_curve_status(self.vm(), Call::new(), curve)
            .map_err(|_| b"ConfigQueryFailed".to_vec())?;

        match new_status_val.as_limbs()[0] {
            STATUS_ACTIVE => {},
            _ => return Err(b"TargetCurveNotActive".to_vec()),
        }

        // 6. Finalize Policy Consumption (State transition APPROVED -> EXECUTED inside the ledger)
        let ctx = Call::new_mutating(self);
        let host_mut = self.vm();

        ledger_client.consume_policy(host_mut, ctx, request_id)
            .map_err(|_| b"ConsumePolicyFailed".to_vec())?;

        // 7. Mutate Local Identity Truth State
        let stored_nonce = self.nonces.getter(user).get();
        self.pubkeys.setter(user).set(new_pubkey_hash);
        self.curves.setter(user).set(curve);
        self.nonces.setter(user).set(stored_nonce + U256::from(1));

        self.vm().log(KeyRotatedFromPolicy {
            user,
            ledger: policy_ledger,
            requestId: request_id,
        });

        Ok(())
    }

    // ------------------------------------------------------------------------
    // P256 VERIFIER — IN-PROCESS INTERFACE (merged from kipio_auth_verifier_p256)
    // ------------------------------------------------------------------------
    //
    // NOTE:
    //
    // `_user` and `_curve` only exist to preserve compatibility with the
    // verifier interface expected by `kipio_auth`.
    //
    // This path is intentionally stateless.
    //
    // All cryptographic verification is delegated to the ArbOS native
    // secp256r1 precompile.
    //
    // The full precompile documentation (RIP-7212 / EIP-7951, frontend
    // normalization rules, calldata layout, return semantics) is attached
    // to the `P256_VERIFY_PRECOMPILE` constant above.
    // ------------------------------------------------------------------------
    pub fn verify(
        &self,
        _user: Address,
        digest: B256,
        signature: Vec<u8>,
        pubkey: Vec<u8>,
        // ignored by P256 verifier
        // preserved only for verifier interface compatibility _curve
        _curve: U256,
    ) -> Result<bool, Vec<u8>> {

        // ----------------------------------------------------------------
        // SIGNATURE FORMAT
        // ----------------------------------------------------------------
        //
        // Expected:
        //
        // r || s
        //
        // 32 + 32 = 64 bytes
        // ----------------------------------------------------------------
        if signature.len() != 64 {
            return Err(b"BadSigLength".to_vec());
        }

        // ----------------------------------------------------------------
        // PUBLIC KEY FORMAT
        // ----------------------------------------------------------------
        //
        // Expected:
        //
        // x || y
        //
        // 32 + 32 = 64 bytes
        // ----------------------------------------------------------------
        if pubkey.len() != 64 {
            return Err(b"BadPubkeyLength".to_vec());
        }

        // ----------------------------------------------------------------
        // BUILD RAW PRECOMPILE INPUT
        // ----------------------------------------------------------------
        //
        // EIP-7951 requires:
        //
        // digest || r || s || qx || qy
        //
        // total:
        //
        // 32 * 5 = 160 bytes
        // ----------------------------------------------------------------
        let mut input = Vec::with_capacity(160);

        // digest
        input.extend_from_slice(digest.as_slice());

        // r
        input.extend_from_slice(&signature[0..32]);

        // s
        input.extend_from_slice(&signature[32..64]);

        // qx
        input.extend_from_slice(&pubkey[0..32]);

        // qy
        input.extend_from_slice(&pubkey[32..64]);

        // ----------------------------------------------------------------
        // STATICCALL INTO ARBOS PRECOMPILE
        // ----------------------------------------------------------------
        //
        // IMPORTANT:
        //
        // - raw calldata only
        // - no ABI encoding
        // - no Solidity selector
        // - no serialization layer
        //
        // The SDK internally uses RawCall::new_static(...)
        // underneath this wrapper.
        // ----------------------------------------------------------------
        let result = static_call(
            self.vm(),
            Call::new(),
            P256_VERIFY_PRECOMPILE,
            input.as_slice(),
        );

        // ----------------------------------------------------------------
        // HANDLE PRECOMPILE RESPONSE
        // ----------------------------------------------------------------
        //
        // EIP-7951 semantics:
        //
        // 32-byte response:
        //     success path
        //
        // empty response:
        //     invalid signature OR malformed input
        //
        // last byte:
        //     1 => valid
        //     0 => invalid
        // ----------------------------------------------------------------
        match result {

            Ok(output) => {

                // invalid signature or malformed input
                if output.len() != 32 {
                    return Ok(false);
                }

                // valid signature = last byte == 1
                Ok(output[31] == 1u8)
            }

            // unexpected revert / host failure
            Err(_) => Ok(false),
        }
    }
}

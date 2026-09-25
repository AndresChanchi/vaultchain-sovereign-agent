//! Identity anchor dispatch handlers.
//!
//! Covers protocol config binding, initial key registration, intent
//! authorization with EIP-712 signatures, key rotation via signature
//! or via external policy ledger, the in-process EIP-7951 P256
//! verifier, and the identity state readers.
//!
//! All mutating handlers observe strict CEI ordering: state is mutated
//! before the cross-contract verifier or policy ledger call. If the
//! external call reverts, the entire transaction (including the local
//! mutation) is rolled back atomically.

use super::*;

impl KipioIdentityContent {
    // --------------------------------------------------------------------
    // IDENTITY ANCHOR — INITIALIZATION
    // --------------------------------------------------------------------

    /// @notice Links this identity ledger to the universal protocol
    ///         configuration provider.
    /// @dev May only be executed once during deployment setup.
    ///      IDEMPOTENT: repeated calls with the same config are silent
    ///      no-ops. Different config after initialization reverts.
    ///
    /// DEFENSE IN DEPTH:
    ///      Rejects EOAs and precompile addresses by checking `code_size`.
    ///      Without this, an owner could accidentally point the identity
    ///      ledger at a non-contract address, bricking every subsequent
    ///      call that requires config lookups.
    ///
    /// @param protocol_config Deployed address of the KipioProtocolConfig
    ///        contract.
    #[inline(never)]
    pub(crate) fn dispatch_initialize(&mut self, args: &[u8]) -> ArbResult {
        let call = initializeCall::abi_decode(args).map_err(|_| Vec::new())?;

        if call.protocol_config == Address::ZERO {
            return Err(ZeroAddressConfig {}.abi_encode());
        }

        if self.vm().code_size(call.protocol_config) == 0 {
            return Err(NotAContract {}.abi_encode());
        }

        let current = self.protocol_config.get();
        if current != Address::ZERO {
            if current == call.protocol_config {
                return Ok(Vec::new());
            }
            return Err(AlreadyInitialized {}.abi_encode());
        }

        self.protocol_config.set(call.protocol_config);

        self.vm().log(Initialized {
            config: call.protocol_config,
        });

        Ok(Vec::new())
    }

    // --------------------------------------------------------------------
    // IDENTITY ANCHOR — REGISTRATION
    // --------------------------------------------------------------------

    /// @notice Registers an initial permanent sovereign relationship
    ///         binding an actor to a public key hash.
    /// @dev IDEMPOTENT: repeated calls with the same pubkey+curve are
    ///      silent no-ops. Different pubkey or curve after registration
    ///      reverts.
    ///
    /// CEI NOTE:
    ///      The config reads happen BEFORE the storage mutations because
    ///      the read results ARE the checks that gate the mutation. Both
    ///      reads are `Call::new()` (static), so no state can change
    ///      during them.
    ///
    /// @param pubkey Raw big-endian unparsed cryptographic public identity
    ///        coordinates.
    /// @param curve Selected mathematical curve identifier framework.
    #[inline(never)]
    pub(crate) fn dispatch_register(&mut self, args: &[u8]) -> ArbResult {
        let call = decode_register(args)?;

        self.require_not_paused()?;

        let sender = self.vm().msg_sender();

        if call.pubkey.is_empty() {
            return Err(EmptyKey {}.abi_encode());
        }

        // `Bytes` dereferences to `[u8]`; pass a borrowed slice to `keccak`.
        let pubkey_hash = keccak(&call.pubkey.0);

        let existing_hash = self.pubkeys.getter(sender).get();
        if existing_hash != B256::ZERO {
            let existing_curve = self.curves.getter(sender).get();
            if existing_hash == pubkey_hash && existing_curve == call.curve {
                return Ok(Vec::new());
            }
            return Err(AlreadyRegistered {}.abi_encode());
        }

        let config_addr = self.protocol_config.get();
        if config_addr == Address::ZERO {
            return Err(ProtocolConfigNotSet {}.abi_encode());
        }

        let config = IKipioProtocolConfig::new(config_addr);
        let host = self.vm();

        let verifier = config
            .get_verifier(host, Call::new(), call.curve)
            .map_err(|_| ConfigQueryFailed {}.abi_encode())?;

        if verifier == Address::ZERO {
            return Err(VerifierNotSetForCurve {}.abi_encode());
        }

        let status_val = config
            .get_curve_status(host, Call::new(), call.curve)
            .map_err(|_| ConfigQueryFailed {}.abi_encode())?;

        match status_val.as_limbs()[0] {
            STATUS_ACTIVE => {}
            _ => return Err(CurveNotActiveForRegistration {}.abi_encode()),
        }

        self.pubkeys.setter(sender).set(pubkey_hash);
        self.curves.setter(sender).set(call.curve);
        self.nonces.setter(sender).set(U256::ZERO);

        self.vm().log(Registered {
            user: sender,
            pubkeyHash: pubkey_hash,
            curve: call.curve,
        });

        Ok(Vec::new())
    }

    // --------------------------------------------------------------------
    // IDENTITY ANCHOR — AUTHORIZATION
    // --------------------------------------------------------------------

    /// @notice Proves that the registered cryptographic identity
    ///         explicitly approved a specific business action.
    ///
    /// CRITICAL SEMANTIC DEFINITION FOR FUTURE INVOCATIONS & AI AGENTS:
    /// - This function is NOT a frontend login, an application session
    ///   initialization, or a web access log.
    /// - VERIFY_IDENTITY_AUTHORIZATION MEANS: "Cryptographically prove
    ///   that the registered sovereign identity approved this high-value
    ///   structured intent payload".
    ///
    /// SECURITY MODEL:
    /// - Caller is unrestricted (`user` is a parameter, not `msg_sender`).
    /// - Signature is bound to `user`, `msg_hash`, `nonce`, `deadline`,
    ///   `curve`.
    /// - Front-running is not exploitable: replaying the signature would
    ///   advance the nonce on behalf of the same verification, which is
    ///   exactly what the user intended. The attacker pays gas; the
    ///   user's intent is still honored.
    /// - CEI ordering: the nonce is incremented BEFORE the cross-contract
    ///   verifier call. If the verifier reverts, the whole transaction
    ///   reverts and the increment is rolled back atomically.
    /// - `deadline = 0` is invalid by definition: any nonzero block
    ///   timestamp is strictly greater than zero, so the check always
    ///   reverts with `Expired`.
    ///
    /// @param user Target logical entity address whose identity registry
    ///        maps are queried.
    /// @param msg_hash Bound structural action target hash scheduled for
    ///        verification approval.
    /// @param signature Normalized, big-endian signature block passed
    ///        down from frontend layers (`r || s`).
    /// @param pubkey Normalized coordinates validating matching identity
    ///        persistent storage fingerprints (`x || y`).
    /// @param nonce Current active replay protection nonce tracking value
    ///        for identity state mutations.
    /// @param deadline Absolute block timestamp expiration threshold
    ///        capping transaction execution windows.
    #[inline(never)]
    pub(crate) fn dispatch_verify_identity_authorization(&mut self, args: &[u8]) -> ArbResult {
        let call = decode_verify_identity_authorization(args)?;

        self.require_not_paused()?;

        // ------------------------------------------------------------------
        // CHECKS
        // ------------------------------------------------------------------

        if call.user == Address::ZERO {
            return Err(ZeroUser {}.abi_encode());
        }

        if call.signature.is_empty() {
            return Err(BadSig {}.abi_encode());
        }

        if call.pubkey.is_empty() {
            return Err(EmptyKey {}.abi_encode());
        }

        let now = U256::from(self.vm().block_timestamp());
        if now > call.deadline {
            return Err(Expired {}.abi_encode());
        }

        let stored_nonce = self.nonces.getter(call.user).get();
        if call.nonce != stored_nonce {
            return Err(BadNonce {}.abi_encode());
        }

        let stored_hash = self.pubkeys.getter(call.user).get();
        if keccak(&call.pubkey.0) != stored_hash {
            return Err(InvalidPubkey {}.abi_encode());
        }

        let curve = self.curves.getter(call.user).get();

        let config_addr = self.protocol_config.get();
        if config_addr == Address::ZERO {
            return Err(ProtocolConfigNotSet {}.abi_encode());
        }

        let config = IKipioProtocolConfig::new(config_addr);
        let status_val = config
            .get_curve_status(self.vm(), Call::new(), curve)
            .map_err(|_| ConfigQueryFailed {}.abi_encode())?;

        match status_val.as_limbs()[0] {
            STATUS_DISABLED => return Err(CurveHardwareDisabled {}.abi_encode()),
            _ => {}
        }

        // ------------------------------------------------------------------
        // BUILD DIGEST (uses the OLD nonce value)
        // ------------------------------------------------------------------

        let digest =
            self.build_verify_digest(call.user, call.msg_hash, call.nonce, call.deadline, curve);

        // ------------------------------------------------------------------
        // EFFECTS (mutate state BEFORE the cross-contract call)
        // ------------------------------------------------------------------
        //
        // If the verifier reverts, this increment is atomically rolled
        // back. This ordering follows CEI strictly and defends against
        // any future reentrancy vector, even if the SDK's default
        // protection changed.

        let new_nonce = stored_nonce + U256::from(1);
        self.nonces.setter(call.user).set(new_nonce);

        // ------------------------------------------------------------------
        // INTERACTIONS (cross-contract verifier call LAST)
        // ------------------------------------------------------------------
        //
        // `call_verifier` takes `Vec<u8>` for signature and pubkey. The
        // decoded `Bytes` values are converted with `.to_vec()` because
        // `Bytes` is a newtype over `alloy_primitives::Bytes`, not over
        // `Vec<u8>`.

        self.call_verifier(
            call.user,
            digest,
            call.signature.0.to_vec(),
            call.pubkey.0.to_vec(),
            curve,
        )?;

        // ------------------------------------------------------------------
        // OBSERVABILITY
        // ------------------------------------------------------------------

        self.vm().log(IdentityAuthorizationVerified {
            user: call.user,
            msgHash: call.msg_hash,
            newNonce: new_nonce,
        });

        Ok((true,).abi_encode_params())
    }

    // --------------------------------------------------------------------
    // IDENTITY ANCHOR — KEY ROTATION
    // --------------------------------------------------------------------

    /// @notice Migrates a user's identity coordinates to a new public key
    ///         set (Identity Evolution).
    /// @dev Users remain fully sovereign over their identity records;
    ///      they can rotate keys to adapt to device upgrades.
    ///
    /// SECURITY MODEL:
    /// - Caller MUST be `user`. Rotation is not delegated.
    /// - Old key signature authorizes the transition (chain of custody
    ///   preserved).
    /// - CEI ordering: all state mutations happen BEFORE the
    ///   cross-contract call.
    #[inline(never)]
    pub(crate) fn dispatch_rotate_key(&mut self, args: &[u8]) -> ArbResult {
        let call = decode_rotate_key(args)?;

        self.require_not_paused()?;

        let user = self.vm().msg_sender();

        // ------------------------------------------------------------------
        // CHECKS
        // ------------------------------------------------------------------

        if call.old_pubkey.is_empty() || call.new_pubkey.is_empty() {
            return Err(EmptyKey {}.abi_encode());
        }

        let stored_hash = self.pubkeys.getter(user).get();
        if stored_hash == B256::ZERO {
            return Err(NotRegistered {}.abi_encode());
        }

        if keccak(&call.old_pubkey.0) != stored_hash {
            return Err(InvalidOldKey {}.abi_encode());
        }

        let stored_nonce = self.nonces.getter(user).get();
        if call.nonce != stored_nonce {
            return Err(BadNonce {}.abi_encode());
        }

        let now = U256::from(self.vm().block_timestamp());
        if now > call.deadline {
            return Err(Expired {}.abi_encode());
        }

        let old_curve = self.curves.getter(user).get();

        let config_addr = self.protocol_config.get();
        if config_addr == Address::ZERO {
            return Err(ProtocolConfigNotSet {}.abi_encode());
        }
        let config = IKipioProtocolConfig::new(config_addr);

        let old_status_val = config
            .get_curve_status(self.vm(), Call::new(), old_curve)
            .map_err(|_| ConfigQueryFailed {}.abi_encode())?;

        match old_status_val.as_limbs()[0] {
            STATUS_DISABLED => return Err(CurveHardwareDisabled {}.abi_encode()),
            _ => {}
        }

        let new_status_val = config
            .get_curve_status(self.vm(), Call::new(), call.new_curve)
            .map_err(|_| ConfigQueryFailed {}.abi_encode())?;

        match new_status_val.as_limbs()[0] {
            STATUS_ACTIVE => {}
            _ => return Err(TargetCurveNotActive {}.abi_encode()),
        }

        let new_pubkey_hash = keccak(&call.new_pubkey.0);

        // ------------------------------------------------------------------
        // BUILD DIGEST (uses the OLD nonce value)
        // ------------------------------------------------------------------

        let digest =
            self.build_rotate_digest(user, new_pubkey_hash, call.new_curve, call.nonce, call.deadline);

        // ------------------------------------------------------------------
        // EFFECTS (mutate state BEFORE the cross-contract call)
        // ------------------------------------------------------------------

        let new_nonce = stored_nonce + U256::from(1);
        self.pubkeys.setter(user).set(new_pubkey_hash);
        self.curves.setter(user).set(call.new_curve);
        self.nonces.setter(user).set(new_nonce);

        // ------------------------------------------------------------------
        // INTERACTIONS (cross-contract verifier call LAST)
        // ------------------------------------------------------------------

        self.call_verifier(
            user,
            digest,
            call.signature_from_old.0.to_vec(),
            call.old_pubkey.0.to_vec(),
            old_curve,
        )?;

        // ------------------------------------------------------------------
        // OBSERVABILITY
        // ------------------------------------------------------------------

        self.vm().log(KeyRotated {
            user,
            oldPubkeyHash: stored_hash,
            newPubkeyHash: new_pubkey_hash,
            newCurve: call.new_curve,
            newNonce: new_nonce,
        });

        Ok(Vec::new())
    }

    /// @notice Consumes a pre-approved authorization policy from an
    ///         external ledger to orchestrate an identity migration.
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
    /// preserving this contract as the single source of truth.
    ///
    /// SECURITY MODEL:
    /// - `user` is read from the policy record, NOT from `msg_sender`.
    ///   Anyone may trigger a rotation on behalf of a user whose policy
    ///   is APPROVED. This is intentional: the policy IS the
    ///   authorization.
    /// - CEI ordering: local state is mutated BEFORE `consume_policy` is
    ///   called. If consume_policy reverts, the entire transaction
    ///   reverts, including the local mutation.
    /// - DEFENSE IN DEPTH: `user` is validated against Address::ZERO
    ///   even though the whitelisted ledger should never return it.
    ///
    /// @param policy_ledger The target address of the Policy Ledger
    ///        contract (e.g., KipioRecovery).
    /// @param request_id Universal 32-byte identifier mapping to the
    ///        targeted policy record.
    /// @param new_pubkey The full uncompressed public key parameters
    ///        scheduled for registration.
    #[inline(never)]
    pub(crate) fn dispatch_rotate_key_from_policy(&mut self, args: &[u8]) -> ArbResult {
        let call = decode_rotate_key_from_policy(args)?;

        self.require_not_paused()?;

        // ------------------------------------------------------------------
        // CHECKS
        // ------------------------------------------------------------------

        let config_addr = self.protocol_config.get();
        if config_addr == Address::ZERO {
            return Err(ProtocolConfigNotSet {}.abi_encode());
        }

        let config = IKipioProtocolConfig::new(config_addr);
        let host_view = self.vm();

        // 1. Verify ledger architectural authorization (Dynamic check via config)
        let is_auth = config
            .is_authorized_ledger(host_view, Call::new(), call.policy_ledger)
            .map_err(|_| ConfigQueryFailed {}.abi_encode())?;

        if !is_auth {
            return Err(UnauthorizedLedger {}.abi_encode());
        }

        // 2. Extract operational view from the Policy Engine
        let ledger_client = IKipioPolicyLedger::new(call.policy_ledger);
        let record = ledger_client
            .get_policy_record(self.vm(), Call::new(), call.request_id)
            .map_err(|_| LedgerQueryFailed {}.abi_encode())?;

        let (status, policy_type, user, target_hash, curve, deadline) = record;

        // 3. Strict Semantic Validations
        if status != U256::from(POLICY_STATUS_APPROVED) {
            return Err(PolicyNotApproved {}.abi_encode());
        }

        // Defense in depth: the whitelisted ledger should never return
        // Address::ZERO as the target user. But if it does, we refuse to
        // mutate state at address(0), which would silently create a
        // phantom identity anchor.
        if user == Address::ZERO {
            return Err(ZeroUser {}.abi_encode());
        }

        // policy_type identifies the semantic meaning of the approved
        // policy. This contract only executes policy types that it
        // explicitly supports. Unknown policy types are rejected,
        // allowing new policy engines to evolve independently without
        // modifying the identity ledger.
        let expected_policy_type = keccak(b"ROTATE_KEY");
        if policy_type != expected_policy_type {
            return Err(InvalidPolicyType {}.abi_encode());
        }

        let now = U256::from(self.vm().block_timestamp());
        if now > deadline {
            return Err(PolicyExpired {}.abi_encode());
        }

        // 4. Validate injected credentials against the cryptographically
        //    approved hash
        if call.new_pubkey.is_empty() {
            return Err(EmptyKey {}.abi_encode());
        }
        let new_pubkey_hash = keccak(&call.new_pubkey.0);

        if new_pubkey_hash != target_hash {
            return Err(HashMismatch {}.abi_encode());
        }

        // 5. Target Destination Curve Lifecycle Validations
        let new_status_val = config
            .get_curve_status(self.vm(), Call::new(), curve)
            .map_err(|_| ConfigQueryFailed {}.abi_encode())?;

        match new_status_val.as_limbs()[0] {
            STATUS_ACTIVE => {}
            _ => return Err(TargetCurveNotActive {}.abi_encode()),
        }

        // ------------------------------------------------------------------
        // EFFECTS (local state first, per CEI)
        // ------------------------------------------------------------------

        let stored_nonce = self.nonces.getter(user).get();
        let new_nonce = stored_nonce + U256::from(1);
        self.pubkeys.setter(user).set(new_pubkey_hash);
        self.curves.setter(user).set(curve);
        self.nonces.setter(user).set(new_nonce);

        // ------------------------------------------------------------------
        // INTERACTIONS (external consume LAST)
        // ------------------------------------------------------------------

        // Finalize Policy Consumption
        // (State transition APPROVED -> EXECUTED inside the ledger)
        let ctx = Call::new_mutating(self);
        let host_mut = self.vm();

        ledger_client
            .consume_policy(host_mut, ctx, call.request_id)
            .map_err(|_| ConsumePolicyFailed {}.abi_encode())?;

        // ------------------------------------------------------------------
        // OBSERVABILITY
        // ------------------------------------------------------------------

        self.vm().log(KeyRotatedFromPolicy {
            user,
            ledger: call.policy_ledger,
            requestId: call.request_id,
            newPubkeyHash: new_pubkey_hash,
            newCurve: curve,
        });

        Ok(Vec::new())
    }

    // --------------------------------------------------------------------
    // IDENTITY ANCHOR — EIP-7951 P256 VERIFIER
    // --------------------------------------------------------------------
    //
    // `_user` and `_curve` exist only to preserve compatibility with the
    // IKipioAuthVerifier interface expected by call_verifier.
    //
    // This path is intentionally stateless. All cryptographic
    // verification is delegated to the ArbOS native secp256r1
    // precompile, which implements EIP-7951 since ArbOS 50 Dia.
    //
    // The full precompile documentation (EIP-7951, frontend normalization
    // rules, calldata layout, return semantics, security fixes inherited
    // from RIP-7212) is attached to the `P256_VERIFY_PRECOMPILE`
    // constant in config/constants.rs.

    #[inline(never)]
    pub(crate) fn dispatch_verify(&mut self, args: &[u8]) -> ArbResult {
        let call = decode_verify(args)?;

        // ----------------------------------------------------------------
        // SIGNATURE FORMAT: r || s (32 + 32 = 64 bytes)
        // ----------------------------------------------------------------
        if call.signature.len() != 64 {
            return Err(BadSigLength {}.abi_encode());
        }

        // ----------------------------------------------------------------
        // PUBLIC KEY FORMAT: x || y (32 + 32 = 64 bytes)
        // ----------------------------------------------------------------
        if call.pubkey.len() != 64 {
            return Err(BadPubkeyLength {}.abi_encode());
        }

        // ----------------------------------------------------------------
        // BUILD RAW PRECOMPILE INPUT
        // ----------------------------------------------------------------
        //
        // EIP-7951 requires exactly 160 bytes:
        //
        //   digest || r || s || qx || qy
        //
        // `Bytes` implements `Index<Range<usize>>` via `Deref<Target=[u8]>`,
        // so the byte ranges below are direct views into the decoded
        // buffers without any intermediate allocation.
        let mut input = Vec::with_capacity(160);
        input.extend_from_slice(call.digest.as_slice());
        input.extend_from_slice(&call.signature[0..32]);
        input.extend_from_slice(&call.signature[32..64]);
        input.extend_from_slice(&call.pubkey[0..32]);
        input.extend_from_slice(&call.pubkey[32..64]);

        // ----------------------------------------------------------------
        // STATICCALL INTO ARBOS PRECOMPILE
        // ----------------------------------------------------------------
        //
        // Raw calldata only. No ABI encoding, no Solidity selector, no
        // serialization layer.
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
        //   32-byte response -> success path
        //   empty response   -> invalid signature OR malformed input
        //   last byte        -> 1 valid, 0 invalid
        match result {
            Ok(output) => {
                if output.len() != 32 {
                    return Ok((false,).abi_encode_params());
                }
                Ok((output[31] == 1u8,).abi_encode_params())
            }
            Err(_) => Ok((false,).abi_encode_params()),
        }
    }

    // --------------------------------------------------------------------
    // IDENTITY ANCHOR — VIEWS
    // --------------------------------------------------------------------

    /// @notice Returns the currently configured KipioProtocolConfig
    ///         address.
    #[inline(never)]
    pub(crate) fn dispatch_get_protocol_config(&mut self, _args: &[u8]) -> ArbResult {
        Ok((self.protocol_config.get(),).abi_encode_params())
    }

    /// @notice Returns the keccak256 fingerprint of the user's active
    ///         pubkey.
    /// @dev Returns B256::ZERO for unregistered users.
    #[inline(never)]
    pub(crate) fn dispatch_get_pubkey(&mut self, args: &[u8]) -> ArbResult {
        let call = getPubkeyCall::abi_decode(args).map_err(|_| Vec::new())?;
        Ok((self.pubkeys.getter(call.user).get(),).abi_encode_params())
    }

    /// @notice Returns the user's active curve identifier.
    /// @dev Returns U256::ZERO for unregistered users.
    #[inline(never)]
    pub(crate) fn dispatch_get_curve(&mut self, args: &[u8]) -> ArbResult {
        let call = getCurveCall::abi_decode(args).map_err(|_| Vec::new())?;
        Ok((self.curves.getter(call.user).get(),).abi_encode_params())
    }

    /// @notice Returns the user's active replay-protection nonce.
    /// @dev Returns U256::ZERO for unregistered users; increments on every
    ///      successful verify_identity_authorization, rotate_key, and
    ///      rotate_key_from_policy.
    #[inline(never)]
    pub(crate) fn dispatch_get_nonce(&mut self, args: &[u8]) -> ArbResult {
        let call = getNonceCall::abi_decode(args).map_err(|_| Vec::new())?;
        Ok((self.nonces.getter(call.user).get(),).abi_encode_params())
    }
}

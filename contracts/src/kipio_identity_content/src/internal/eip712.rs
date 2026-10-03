//! # EIP-712 domain + digests + cross-contract verifier dispatch
//!
//! Internal helpers for the identity anchor. Everything here is
//! `pub(crate)` — not part of the ABI.
//!
//! The domain separator is cached on first use. Chain ID and verifying
//! contract address are immutable for the lifetime of the deployment.
//!
//! INLINE POLICY:
//!
//! Every helper here is `#[inline(never)]`. These four functions are
//! shared by `dispatch_verify_identity_authorization`, `dispatch_rotate_key`
//! and `dispatch_rotate_key_from_policy`. If LLVM inlines them, their
//! bodies (which include cross-contract calls through `sol_interface!`
//! and keccak preimage construction) get duplicated inside every
//! dispatch that uses them, pushing the enclosing WASM function past
//! the ArbOS 65,536-opcode-per-body limit. Marking them `noinline`
//! keeps each dispatch to a single `call` for these operations.

use alloc::vec::Vec;

use stylus_sdk::{
    abi::Bytes,
    alloy_primitives::{Address, B256, U256},
    alloy_sol_types::SolError,
    crypto::keccak,
    prelude::*,
};

use crate::abi::errors::{
    ConfigQueryFailed, ProtocolConfigNotSet, VerifierCallFailed, VerifierNotSetForCurve,
    VerifyFail,
};
use crate::abi::interfaces::{IKipioAuthVerifier, IKipioProtocolConfig};
use crate::storage::entrypoint::KipioIdentityContent;

#[inline(always)]
pub(crate) fn u256_to_bytes32(x: U256) -> [u8; 32] {
    x.to_be_bytes()
}

#[inline(always)]
pub(crate) fn addr_to_bytes32(addr: Address) -> [u8; 32] {
    let mut out = [0u8; 32];
    out[12..].copy_from_slice(addr.as_slice());
    out
}

impl KipioIdentityContent {
    /// @dev Internal EIP-712 isolated serialization structure caching mechanism.
    #[inline(never)]
    pub(crate) fn get_domain_separator(&mut self) -> B256 {
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
    #[inline(never)]
    pub(crate) fn build_verify_digest(
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
    #[inline(never)]
    pub(crate) fn build_rotate_digest(
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
    ///
    /// CROSS-CONTRACT CALL FLAG:
    /// Uses `Call::new_mutating(self)` because the verifier is external and
    /// may be stateful in future curve modules (e.g. threshold K256, ML-DSA).
    /// This triggers a state cache flush before the call, providing a defensive
    /// reentrancy boundary regardless of the verifier's own semantics.
    #[inline(never)]
    pub(crate) fn call_verifier(
        &mut self,
        user: Address,
        digest: B256,
        signature: Vec<u8>,
        pubkey: Vec<u8>,
        curve_id: U256,
    ) -> Result<(), Vec<u8>> {
        let config_addr = self.protocol_config.get();
        if config_addr == Address::ZERO {
            return Err(ProtocolConfigNotSet {}.abi_encode());
        }

        let config = IKipioProtocolConfig::new(config_addr);
        let host = self.vm();

        let verifier_addr = config
            .get_verifier(host, Call::new(), curve_id)
            .map_err(|_| ConfigQueryFailed {}.abi_encode())?;

        if verifier_addr == Address::ZERO {
            return Err(VerifierNotSetForCurve {}.abi_encode());
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
            .map_err(|_| VerifierCallFailed {}.abi_encode())?;

        if !ok {
            return Err(VerifyFail {}.abi_encode());
        }

        Ok(())
    }
}

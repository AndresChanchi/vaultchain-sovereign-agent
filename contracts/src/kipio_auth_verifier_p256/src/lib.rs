#![allow(unexpected_cfgs)]
#![cfg_attr(not(feature = "std"), no_std)]

extern crate alloc;

use alloc::{vec, vec::Vec};

use stylus_sdk::{
    alloy_primitives::{address, Address, B256, U256},
    call::static_call,
    prelude::*,
};

/// ------------------------------------------------------------------------
/// RIP-7212 / EIP-7951 P256 PRECOMPILE
/// ------------------------------------------------------------------------
///
/// ArbOS exposes the secp256r1 verifier precompile at:
///
/// 0x0000000000000000000000000000000000000100
///
/// This contract intentionally acts as a VERY THIN WRAPPER around that
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
/// This contract intentionally delegates normalization to the frontend
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

#[storage]
#[entrypoint]
pub struct KipioAuthVerifierP256 {}

#[public]
impl KipioAuthVerifierP256 {

    /// --------------------------------------------------------------------
    /// VERIFY P256 SIGNATURE
    /// --------------------------------------------------------------------
    ///
    /// NOTE:
    ///
    /// `_user` and `_curve` only exist to preserve compatibility with the
    /// verifier interface expected by `kipio_auth`.
    ///
    /// This verifier is intentionally stateless.
    ///
    /// All cryptographic verification is delegated to the ArbOS native
    /// secp256r1 precompile.
    /// --------------------------------------------------------------------
    pub fn verify(
        &self,
        _user: Address,
        digest: B256,
        signature: Vec<u8>,
        pubkey: Vec<u8>,
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

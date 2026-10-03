//! Guardian signature verification via ArbOS precompiles.
//!
//! No WASM crypto. Both curves forward raw calldata to their respective
//! native precompiles:
//!
//!   - P256 -> `0x100` (EIP-7951, superseded RIP-7212).
//!   - secp256k1 -> `0x01` (ecrecover).

use stylus_sdk::{
    abi::Bytes,
    alloy_primitives::{Address, B256},
    call::static_call,
    crypto::keccak,
    prelude::*,
};

use crate::config::constants::{
    CURVE_P256, CURVE_SECP256K1, ECRECOVER_PRECOMPILE, P256_VERIFY_PRECOMPILE,
};
use crate::storage::entrypoint::KipioRecovery;

impl KipioRecovery {
    pub(crate) fn verify_guardian_signature(
        &self,
        curve: u8,
        digest: B256,
        signature: &Bytes,
        pubkey: &Bytes,
    ) -> bool {
        match curve {
            CURVE_P256 => self.verify_p256(digest, signature, pubkey),
            CURVE_SECP256K1 => self.verify_secp256k1(digest, signature, pubkey),
            _ => false,
        }
    }

    /// EIP-7951 P256 verification via the ArbOS native precompile. No
    /// WASM crypto; only raw calldata forwarding.
    fn verify_p256(&self, digest: B256, signature: &Bytes, pubkey: &Bytes) -> bool {
        if signature.len() != 64 || pubkey.len() != 64 {
            return false;
        }

        let mut input = Vec::with_capacity(160);
        input.extend_from_slice(digest.as_slice());
        input.extend_from_slice(&signature[0..32]);
        input.extend_from_slice(&signature[32..64]);
        input.extend_from_slice(&pubkey[0..32]);
        input.extend_from_slice(&pubkey[32..64]);

        let result = static_call(
            self.vm(),
            Call::new(),
            P256_VERIFY_PRECOMPILE,
            input.as_slice(),
        );

        match result {
            Ok(output) if output.len() == 32 => output[31] == 1,
            _ => false,
        }
    }

    /// secp256k1 EOA verification via the `ecrecover` precompile.
    /// Recovers the signer address and compares it to the address derived
    /// from the uncompressed pubkey.
    fn verify_secp256k1(&self, digest: B256, signature: &Bytes, pubkey: &Bytes) -> bool {
        if pubkey.len() != 65 || signature.len() != 65 {
            return false;
        }
        if pubkey[0] != 0x04 {
            return false;
        }

        let expected_address = self.secp256k1_pubkey_to_address(pubkey);

        let mut input = [0u8; 128];
        input[0..32].copy_from_slice(digest.as_slice());
        input[63] = signature[64];
        input[64..96].copy_from_slice(&signature[0..32]);
        input[96..128].copy_from_slice(&signature[32..64]);

        let result = static_call(self.vm(), Call::new(), ECRECOVER_PRECOMPILE, &input);

        match result {
            Ok(output) if output.len() == 32 => {
                let recovered = Address::from_slice(&output[12..32]);
                recovered == expected_address
            }
            _ => false,
        }
    }

    fn secp256k1_pubkey_to_address(&self, pubkey: &Bytes) -> Address {
        let hash = keccak(&pubkey[1..65]);
        Address::from_slice(&hash[12..32])
    }
}

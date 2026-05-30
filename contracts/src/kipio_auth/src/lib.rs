#![allow(unexpected_cfgs)]
#![cfg_attr(not(feature = "std"), no_std)]

extern crate alloc;

use alloc::{vec, vec::Vec};

use stylus_sdk::{
    abi::Bytes,
    alloy_primitives::{Address, B256, U256},
    crypto::keccak,
    prelude::*,
    storage::{StorageAddress, StorageB256, StorageMap, StorageU256},
};

sol_interface! {
    interface IKipioAuthVerifier {
        function verify(
            address user,
            bytes32 digest,
            bytes signature,
            bytes pubkey,
            uint256 curve
        ) external returns (bool);
    }
}

#[storage]
#[entrypoint]
pub struct KipioAuth {
    /// @dev Stores keccak256(pubkey) per user.
    pub pubkeys: StorageMap<Address, StorageB256>,

    /// @dev Stores the active curve id per user.
    pub curves: StorageMap<Address, StorageU256>,

    /// @dev Anti-replay nonce per user.
    pub nonces: StorageMap<Address, StorageU256>,

    /// @dev External verifier contract address.
    pub verifier: StorageAddress,

    /// @dev Cached EIP-712 domain separator.
    pub domain_separator_cache: StorageB256,
}

const CURVE_P256: u64 = 1;
const CURVE_K256: u64 = 2;

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

#[inline(always)]
fn curve_is_supported(curve: U256) -> Result<u64, Vec<u8>> {
    if curve > U256::from(u64::MAX) {
        return Err(b"InvalidCurve".to_vec());
    }

    let curve_id = curve.as_limbs()[0];

    match curve_id {
        CURVE_P256 | CURVE_K256 => Ok(curve_id),
        _ => Err(b"InvalidCurve".to_vec()),
    }
}

#[public]
impl KipioAuth {
    /// @dev Sets the verifier contract once.
    /// @notice Intended to be called during deployment or initialization.
    pub fn set_verifier(&mut self, verifier: Address) -> Result<(), Vec<u8>> {
        if verifier == Address::ZERO {
            return Err(b"ZeroVerifier".to_vec());
        }

        if self.verifier.get() != Address::ZERO {
            return Err(b"VerifierAlreadySet".to_vec());
        }

        self.verifier.set(verifier);
        Ok(())
    }

    /// @dev Returns the configured verifier address.
    pub fn get_verifier(&self) -> Address {
        self.verifier.get()
    }

    /// @dev Builds and caches the EIP-712 domain separator.
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

    /// @dev Registers a user public key binding.
    /// @notice The frontend is responsible for providing the key material in the expected format.
    pub fn register(
        &mut self,
        pubkey: Vec<u8>,
        curve: U256,
    ) -> Result<(), Vec<u8>> {
        let sender = self.vm().msg_sender();

        if pubkey.is_empty() {
            return Err(b"EmptyKey".to_vec());
        }

        if self.pubkeys.getter(sender).get() != B256::ZERO {
            return Err(b"AlreadyRegistered".to_vec());
        }

        let curve_id = curve_is_supported(curve)?;

        self.pubkeys.setter(sender).set(keccak(pubkey.as_slice()));
        self.curves.setter(sender).set(U256::from(curve_id));
        self.nonces.setter(sender).set(U256::ZERO);

        Ok(())
    }

    /// @dev Builds the typed-data digest used for verification.
    fn build_verify_digest(
        &mut self,
        user: Address,
        msg_hash: B256,
        nonce: U256,
        deadline: U256,
        curve_id: u64,
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
        enc.extend_from_slice(&u256_to_bytes32(U256::from(curve_id)));

        let struct_hash = keccak(&enc);

        let mut final_data = Vec::with_capacity(66);
        final_data.extend_from_slice(b"\x19\x01");
        final_data.extend_from_slice(self.get_domain_separator().as_slice());
        final_data.extend_from_slice(struct_hash.as_slice());

        keccak(&final_data)
    }

    /// @dev Builds the typed-data digest used to authorize key rotation.
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
        final_data.extend_from_slice(self.get_domain_separator().as_slice());
        final_data.extend_from_slice(struct_hash.as_slice());

        keccak(&final_data)
    }

    /// @dev Calls the external verifier contract.
    fn call_verifier(
        &mut self,
        user: Address,
        digest: B256,
        signature: Vec<u8>,
        pubkey: Vec<u8>,
        curve_id: u64,
    ) -> Result<(), Vec<u8>> {
        let verifier_addr = self.verifier.get();
        if verifier_addr == Address::ZERO {
            return Err(b"VerifierNotSet".to_vec());
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
                U256::from(curve_id),
            )
            .map_err(|_| b"VerifierCallFailed".to_vec())?;

        if !ok {
            return Err(b"VerifyFail".to_vec());
        }

        Ok(())
    }

    /// @dev Verifies a user action using the active verifier module.
    pub fn verify(
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
        if curve == U256::ZERO || curve > U256::from(u64::MAX) {
            return Err(b"InvalidCurve".to_vec());
        }

        let curve_id = curve.as_limbs()[0];

        let digest = self.build_verify_digest(
            user,
            msg_hash,
            nonce,
            deadline,
            curve_id,
        );

        self.call_verifier(
            user,
            digest,
            signature,
            pubkey,
            curve_id,
        )?;

        self.nonces.setter(user).set(stored_nonce + U256::from(1));

        Ok(true)
    }

    /// @dev Rotates a user key after authorization by the old key.
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
        if old_curve == U256::ZERO || old_curve > U256::from(u64::MAX) {
            return Err(b"InvalidCurve".to_vec());
        }

        let old_curve_id = old_curve.as_limbs()[0];

        let new_curve_id = curve_is_supported(new_curve)?;
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
            old_curve_id,
        )?;

        self.pubkeys.setter(user).set(new_pubkey_hash);
        self.curves.setter(user).set(U256::from(new_curve_id));
        self.nonces.setter(user).set(stored_nonce + U256::from(1));

        Ok(())
    }
}

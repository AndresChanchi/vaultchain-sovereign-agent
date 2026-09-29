//! Packing and derivation helpers for pending CRE settlements and their
//! deterministic payment identifiers.

use stylus_sdk::alloy_primitives::{Address, B256, U256};

/// Packs a pending settlement into a single U256 slot.
///
/// Layout (single slot, 256 bits):
///
/// - bits   0..64:  `amount`    (`u64`, wei — max ≈ 18.4 ETH per settlement)
/// - bits  64..224: `depositor` (`u160`)
/// - bits 224..256: `timestamp` (`u32`, unix seconds)
///
/// Zero additional storage cost compared to storing only the amount: the
/// depositor and timestamp ride along in the same slot. This is what allows
/// the refund path to always reach the correct address, and what allows the
/// stale-settlement reclaimer to identify when a deposit has expired.
pub fn pack_pending_settlement(amount: u64, depositor: Address, timestamp: u32) -> U256 {
    let mut packed = U256::from(amount);
    let depositor_u256 = U256::from_be_slice(depositor.as_slice());
    packed |= depositor_u256 << 64_usize;
    packed |= U256::from(timestamp) << 224_usize;
    packed
}

/// Unpacks a pending settlement slot into `(amount, depositor, timestamp)`.
pub fn unpack_pending_settlement(packed: U256) -> (u64, Address, u32) {
    let amount = (packed & U256::from(u64::MAX)).to::<u64>();
    let depositor_u256 = (packed >> 64_usize) & ((U256::ONE << 160_usize) - U256::ONE);
    let depositor_bytes = depositor_u256.to_be_bytes::<32>();
    let depositor = Address::from_slice(&depositor_bytes[12..32]);
    let timestamp = ((packed >> 224_usize) & U256::from(u32::MAX)).to::<u32>();
    (amount, depositor, timestamp)
}

/// Derives a deterministic payment identifier from the funder and nonce.
///
/// This is used for audit and tracing only. Anti-replay is enforced by the
/// nonce check, not by this identifier. Two settlements with the same funder
/// and nonce would collide, but the nonce check prevents that.
pub fn derive_payment_id(funder: Address, nonce: U256) -> B256 {
    let mut buf = [0u8; 52];
    buf[0..20].copy_from_slice(funder.as_slice());
    buf[20..52].copy_from_slice(&nonce.to_be_bytes::<32>());
    alloy_primitives::keccak256(&buf)
}

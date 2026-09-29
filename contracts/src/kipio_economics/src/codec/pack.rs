//! Fixed-size bit-packing layouts for storage slots.
//!
//! Each struct packs two or more logical fields into a single 256-bit slot,
//! halving (or better) the Storage Growth cost of first-time writes. The
//! sub-`u128` widths are chosen to be comfortably above any realistic value
//! for wei-denominated amounts.

use stylus_sdk::alloy_primitives::U256;

/// Packed allocation ledger for grants and sponsors.
///
/// Layout (single slot, 256 bits):
///
/// - bits   0..128: `allocated` (`u128`)
/// - bits 128..256: `consumed`  (`u128`)
///
/// A grant or sponsor allocation in wei will never exceed 2^128
/// (≈ 3.4e20 ETH), so `u128` halves are safe.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct PackedAllocation {
    pub allocated: u128,
    pub consumed: u128,
}

impl PackedAllocation {
    pub const ZERO: Self = Self {
        allocated: 0,
        consumed: 0,
    };

    pub fn pack(&self) -> U256 {
        U256::from(self.allocated) | (U256::from(self.consumed) << 128_usize)
    }

    pub fn unpack(value: U256) -> Self {
        let allocated = (value & U256::from(u128::MAX)).to::<u128>();
        let shifted: U256 = value >> 128_usize;
        let consumed = shifted.to::<u128>();
        Self {
            allocated,
            consumed,
        }
    }

    pub fn remaining(&self) -> u128 {
        self.allocated.saturating_sub(self.consumed)
    }
}

/// Credit entry with expiration.
///
/// Layout (single slot, 256 bits):
///
/// - bits   0..128: `amount`     (`u128`)
/// - bits 128..192: `expires_at` (`u64`, unix seconds)
/// - bits 192..256: reserved     (`u64`, future use)
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct CreditEntry {
    pub amount: u128,
    pub expires_at: u64,
}

impl CreditEntry {
    pub const ZERO: Self = Self {
        amount: 0,
        expires_at: 0,
    };

    pub fn pack(&self) -> U256 {
        U256::from(self.amount) | (U256::from(self.expires_at) << 128_usize)
    }

    pub fn unpack(value: U256) -> Self {
        let amount = (value & U256::from(u128::MAX)).to::<u128>();
        let shifted: U256 = value >> 128_usize;
        let expires_at = (shifted & U256::from(u64::MAX)).to::<u64>();
        Self {
            amount,
            expires_at,
        }
    }

    pub fn is_expired(&self, now: u64) -> bool {
        self.expires_at != 0 && now > self.expires_at
    }

    pub fn remaining(&self, now: u64) -> u128 {
        if self.is_expired(now) {
            0
        } else {
            self.amount
        }
    }
}

/// Bootstrap campaign for targeted onboarding subsidies.
///
/// Layout (single slot, 256 bits):
///
/// - bits   0..128: `amount_per_beneficiary` (`u128`)
/// - bits 128..160: `max_beneficiaries`      (`u32`)
/// - bits 160..192: `consumed_beneficiaries` (`u32`)
/// - bits 192..256: `expires_at`             (`u64`, unix seconds)
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct BootstrapCampaign {
    pub amount_per_beneficiary: u128,
    pub max_beneficiaries: u32,
    pub consumed_beneficiaries: u32,
    pub expires_at: u64,
}

impl BootstrapCampaign {
    pub const ZERO: Self = Self {
        amount_per_beneficiary: 0,
        max_beneficiaries: 0,
        consumed_beneficiaries: 0,
        expires_at: 0,
    };

    pub fn pack(&self) -> U256 {
        let mut packed = U256::from(self.amount_per_beneficiary);
        packed |= U256::from(self.max_beneficiaries) << 128_usize;
        packed |= U256::from(self.consumed_beneficiaries) << 160_usize;
        packed |= U256::from(self.expires_at) << 192_usize;
        packed
    }

    pub fn unpack(value: U256) -> Self {
        let amount = (value & U256::from(u128::MAX)).to::<u128>();
        let shifted_128: U256 = value >> 128_usize;
        let max = (shifted_128 & U256::from(u32::MAX)).to::<u32>();
        let shifted_160: U256 = value >> 160_usize;
        let consumed = (shifted_160 & U256::from(u32::MAX)).to::<u32>();
        let shifted_192: U256 = value >> 192_usize;
        let expires = (shifted_192 & U256::from(u64::MAX)).to::<u64>();
        Self {
            amount_per_beneficiary: amount,
            max_beneficiaries: max,
            consumed_beneficiaries: consumed,
            expires_at: expires,
        }
    }

    pub fn is_expired(&self, now: u64) -> bool {
        self.expires_at != 0 && now > self.expires_at
    }

    pub fn is_depleted(&self) -> bool {
        self.consumed_beneficiaries >= self.max_beneficiaries
    }

    pub fn remaining(&self) -> u32 {
        self.max_beneficiaries
            .saturating_sub(self.consumed_beneficiaries)
    }
}

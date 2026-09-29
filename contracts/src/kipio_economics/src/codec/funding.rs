//! Decoding logic for the [`FundingSource`] enum.

use alloc::vec::Vec;

use stylus_sdk::alloy_primitives::{B256, U256};
use stylus_sdk::alloy_sol_types::{SolError, SolValue};

use crate::abi::errors::{InvalidSettlementPlan, UnsupportedFundingSource};

/// Represents how economic resources become available for settlement.
///
/// A funding source does not represent identity, ownership, or custody.
/// It only describes the origin of economic capacity.
#[derive(Debug, PartialEq, Eq)]
pub enum FundingSource {
    DirectNative(U256),
    InternalCredit,
    TreasurySponsored,
    GrantSponsored(B256),
    SponsorSponsored(B256),
}

impl FundingSource {
    /// Decodes a funding source from its numeric ID and routing payload.
    ///
    /// IDs are stable ABI constants. Adding new sources is a breaking change
    /// for the frontend and must be coordinated.
    pub fn from_id(id: u8, native_value: U256, payload: &[u8]) -> Result<Self, Vec<u8>> {
        match id {
            0 => Ok(FundingSource::DirectNative(native_value)),
            1 => Ok(FundingSource::InternalCredit),
            2 => Ok(FundingSource::TreasurySponsored),
            3 => {
                let grant_id = B256::abi_decode(payload)
                    .map_err(|_| InvalidSettlementPlan {}.abi_encode())?;
                Ok(FundingSource::GrantSponsored(grant_id))
            },
            4 => {
                let sponsor_id = B256::abi_decode(payload)
                    .map_err(|_| InvalidSettlementPlan {}.abi_encode())?;
                Ok(FundingSource::SponsorSponsored(sponsor_id))
            },
            _ => Err(UnsupportedFundingSource {}.abi_encode()),
        }
    }
}

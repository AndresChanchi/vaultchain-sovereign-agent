//! Decoder for the Chainlink CRE report payload.
//!
//! Expected layout (produced by the CRE workflow using encodePacked):
//!   [0..32)   → queryId
//!   [32..64)  → contentHash
//!   [64..96)  → length of result (uint256)
//!   [96..N)   → result bytes

use alloc::vec::Vec;

use stylus_sdk::{
    alloy_primitives::{Bytes, B256, U256},
    alloy_sol_types::SolError,
};

use crate::abi::errors::{InvalidReportLength, TruncatedResult};

pub(crate) fn decode_cre_report(report: &Bytes) -> Result<(B256, B256, Bytes), Vec<u8>> {
    if report.len() < 96 {
        return Err(InvalidReportLength {}.abi_encode());
    }
    let query_id = B256::from_slice(&report[0..32]);
    let content_hash = B256::from_slice(&report[32..64]);

    let len_bytes: [u8; 32] = report[64..96]
        .try_into()
        .map_err(|_| InvalidReportLength {}.abi_encode())?;
    let result_len = U256::from_be_bytes(len_bytes).as_limbs()[0] as usize;
    if report.len() < 96 + result_len {
        return Err(TruncatedResult {}.abi_encode());
    }
    let result = Bytes::from(report[96..96 + result_len].to_vec());

    Ok((query_id, content_hash, result))
}

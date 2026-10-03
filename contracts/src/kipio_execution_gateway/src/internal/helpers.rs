//! Stateless helpers used across the Gateway.

use alloc::vec::Vec;

use stylus_sdk::alloy_sol_types::SolError;

use crate::abi::errors::DispatchFailed;

/// Computes the Stylus constructor selector:
/// `keccak256("constructor()")[0..4]`. The selector is fixed; the
/// argument list is not part of it. Arguments follow as an ABI-encoded
/// parameter list.
#[inline]
pub(crate) fn constructor_selector() -> [u8; 4] {
    let h = alloy_primitives::keccak256(b"constructor()");
    [h[0], h[1], h[2], h[3]]
}

/// Decodes a dispatch error from Runtime into a revert payload.
#[inline]
pub(crate) fn encode_dispatch_error(err: stylus_sdk::prelude::errors::Error) -> Vec<u8> {
    match err {
        stylus_sdk::prelude::errors::Error::Revert(data) => data,
        _ => DispatchFailed {}.abi_encode(),
    }
}

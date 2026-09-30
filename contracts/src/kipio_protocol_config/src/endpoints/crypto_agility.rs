//! Crypto-agility registry handlers.
//!
//! The registry decouples the identity ledger from any specific curve.
//! `kipio_identity_content` reads the curve status and verifier address
//! on every signature-related operation. Adding support for a new curve
//! requires only calling `set_verifier`; disabling or phasing out a
//! curve requires only `set_curve_status`.

use alloc::vec::Vec;

use stylus_sdk::{
    alloy_primitives::{Address, U256},
    alloy_sol_types::SolError,
    prelude::*,
};

use crate::abi::errors::{InvalidCurveStatus, ZeroAddress};
use crate::abi::events::{CurveStatusUpdated, VerifierUpdated};
use crate::config::constants::{STATUS_ACTIVE, STATUS_DEPRECATED, STATUS_DISABLED};
use crate::storage::entrypoint::KipioProtocolConfig;

/// Registers or replaces the verifier for a curve, and activates the
/// curve in a single call.
///
/// The activation is implicit: registering a verifier means the curve is
/// ready to accept signatures. To later disable or deprecate the curve
/// without unregistering the verifier, use `set_curve_status`.
pub(crate) fn handle_set_verifier(
    this: &mut KipioProtocolConfig,
    curve_id: U256,
    verifier_address: Address,
) -> Result<(), Vec<u8>> {
    this.require_owner()?;
    this.require_not_paused()?;

    if verifier_address == Address::ZERO {
        return Err(ZeroAddress {}.abi_encode());
    }

    this.verifiers.setter(curve_id).set(verifier_address);
    this.curve_statuses
        .setter(curve_id)
        .set(U256::from(STATUS_ACTIVE));

    this.vm().log(VerifierUpdated {
        curveId: curve_id,
        verifier: verifier_address,
    });
    this.vm().log(CurveStatusUpdated {
        curveId: curve_id,
        status: U256::from(STATUS_ACTIVE),
    });

    Ok(())
}

/// Updates the lifecycle status of a curve.
///
/// Only the three defined statuses are accepted. Unknown values revert
/// with `InvalidCurveStatus`.
pub(crate) fn handle_set_curve_status(
    this: &mut KipioProtocolConfig,
    curve_id: U256,
    status: U256,
) -> Result<(), Vec<u8>> {
    this.require_owner()?;
    this.require_not_paused()?;

    let status_val = status.as_limbs()[0];
    match status_val {
        STATUS_DISABLED | STATUS_ACTIVE | STATUS_DEPRECATED => {}
        _ => return Err(InvalidCurveStatus {}.abi_encode()),
    }

    this.curve_statuses.setter(curve_id).set(status);
    this.vm().log(CurveStatusUpdated {
        curveId: curve_id,
        status,
    });
    Ok(())
}

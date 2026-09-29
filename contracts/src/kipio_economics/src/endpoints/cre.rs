//! Chainlink CRE settlement handlers.
//!
//! The KeystoneForwarder is the only authorized caller of `on_report`. The
//! value is pre-deposited via `deposit_for_settlement` before the report is
//! delivered, because the forwarder does not carry `msg.value`.

use alloc::vec::Vec;

use stylus_sdk::abi::Bytes;
use stylus_sdk::alloy_primitives::{Address, B256, U256};
use stylus_sdk::alloy_sol_types::{SolError, SolValue};
use stylus_sdk::prelude::*;

use crate::abi::errors::{
    DepositTooLarge, InsufficientDeposit, InsufficientFunds, InvalidCreReport,
    InvalidPaymentId, InvalidPricingParameters, ReplayDetected, SettlementNotStale,
    UnauthorizedForwarder, UnauthorizedWorkflow, UnsupportedService, ZeroAmount,
};
use crate::abi::events::{
    CreSettlementProcessed, ProtocolFeeCollected, SettlementDeposited, SettlementExecuted,
    StaleSettlementReclaimed,
};
use crate::codec::pending::{derive_payment_id, pack_pending_settlement, unpack_pending_settlement};
use crate::config::constants::SETTLEMENT_RECLAIM_TIMEOUT;
use crate::kipio_shared::CreSettlementReport;
use crate::storage::entrypoint::KipioEconomics;

pub(crate) fn handle_deposit_for_settlement(
    this: &mut KipioEconomics,
    payment_id: B256,
) -> Result<(), Vec<u8>> {
    this.require_not_paused()?;

    let amount = this.vm().msg_value();
    if amount == U256::ZERO {
        return Err(ZeroAmount {}.abi_encode());
    }

    if amount > U256::from(u64::MAX) {
        return Err(DepositTooLarge {}.abi_encode());
    }

    let existing = this.pending_settlements.getter(payment_id).get();
    if existing != U256::ZERO {
        return Err(ReplayDetected {}.abi_encode());
    }

    let depositor = this.vm().msg_sender();
    let timestamp = this.vm().block_timestamp() as u32;
    let packed = pack_pending_settlement(amount.to::<u64>(), depositor, timestamp);
    this.pending_settlements.setter(payment_id).set(packed);

    this.vm().log(SettlementDeposited { payment_id, amount });
    Ok(())
}

pub(crate) fn handle_reclaim_stale_settlement(
    this: &mut KipioEconomics,
    payment_id: B256,
) -> Result<(), Vec<u8>> {
    let packed = this.pending_settlements.getter(payment_id).get();
    if packed == U256::ZERO {
        return Err(InvalidPaymentId {}.abi_encode());
    }

    let (amount, depositor, timestamp) = unpack_pending_settlement(packed);

    let now = this.vm().block_timestamp();
    if now < u64::from(timestamp) + SETTLEMENT_RECLAIM_TIMEOUT {
        return Err(SettlementNotStale {}.abi_encode());
    }

    this.pending_settlements
        .setter(payment_id)
        .set(U256::ZERO);

    this.credit_refund(depositor, U256::from(amount));

    this.vm().log(StaleSettlementReclaimed {
        payment_id,
        depositor,
        amount: U256::from(amount),
    });

    Ok(())
}

pub(crate) fn handle_on_report(
    this: &mut KipioEconomics,
    metadata: Bytes,
    report: Bytes,
) -> Result<(), Vec<u8>> {
    // --- 1. Validate forwarder ---
    let sender = this.vm().msg_sender();
    let authorized = this.cre_forwarder.get();

    if sender != authorized {
        return Err(UnauthorizedForwarder {}.abi_encode());
    }

    // --- 2. Extract and validate workflowId from metadata ---
    let meta_bytes: &[u8] = metadata.as_ref();
    if meta_bytes.len() < 62 {
        return Err(InvalidCreReport {}.abi_encode());
    }
    let workflow_id = B256::from_slice(&meta_bytes[0..32]);
    let authorized_workflow = B256::from(this.cre_workflow_id.get().to_be_bytes());
    if workflow_id != authorized_workflow {
        return Err(UnauthorizedWorkflow {}.abi_encode());
    }

    // --- 3. Decode report ---
    let cre_report = CreSettlementReport::abi_decode(&report)
        .map_err(|_| InvalidCreReport {}.abi_encode())?;

    // --- 4. Validate settled_amount > 0 and <= u64::MAX ---
    if cre_report.settled_amount == U256::ZERO
        || cre_report.settled_amount > U256::from(u64::MAX)
    {
        return Err(InvalidCreReport {}.abi_encode());
    }

    // --- 5. Validate requested_capacity > 0 ---
    if cre_report.requested_capacity == U256::ZERO {
        return Err(InvalidPricingParameters {}.abi_encode());
    }

    // --- 6. Validate funder is not the zero address ---
    if cre_report.funder == Address::ZERO {
        return Err(InvalidCreReport {}.abi_encode());
    }

    // --- 7. Anti-replay: validate and consume the nonce ---
    this.use_checked_nonce(cre_report.funder, cre_report.nonce)?;

    let payment_id = derive_payment_id(cre_report.funder, cre_report.nonce);

    // --- 8. Resolve provider BEFORE processing (fail-fast) ---
    let provider_address = this.service_registry.getter(cre_report.service_id).get();
    if provider_address.is_zero() {
        return Err(UnsupportedService {}.abi_encode());
    }

    // --- 9. Unpack pending deposit and verify solvency ---
    let packed = this.pending_settlements.getter(payment_id).get();
    if packed == U256::ZERO {
        return Err(InsufficientDeposit {}.abi_encode());
    }
    let (deposited_amount, depositor, _timestamp) = unpack_pending_settlement(packed);
    let deposited = U256::from(deposited_amount);

    if deposited < cre_report.settled_amount {
        return Err(InsufficientDeposit {}.abi_encode());
    }

    // --- 10. Clear deposit (CEI) ---
    this.pending_settlements.setter(payment_id).set(U256::ZERO);

    // --- 11. Compute fee and storage quote ---
    let protocol_fee = this.protocol_fee.get();
    if cre_report.settled_amount < protocol_fee {
        return Err(InsufficientFunds {}.abi_encode());
    }
    let storage_quote = cre_report.settled_amount - protocol_fee;

    // --- 12. Settle to provider ---
    if storage_quote > U256::ZERO {
        this.settle_payment(provider_address, storage_quote)?;
    }

    // --- 13. Fee to treasury ---
    if protocol_fee > U256::ZERO {
        this.treasury_module.add_reserves(protocol_fee);
        this.vm().log(ProtocolFeeCollected {
            funder: cre_report.funder,
            fee_amount: protocol_fee,
            service_id: cre_report.service_id,
            payment_id,
        });
    }

    // --- 14. Pull-based refund of excess deposit ---
    if deposited > cre_report.settled_amount {
        let refund_amount = deposited - cre_report.settled_amount;
        this.credit_refund(depositor, refund_amount);
    }

    // --- 15. Emit events ---
    this.vm().log(CreSettlementProcessed {
        funder: cre_report.funder,
        payment_id,
        amount: cre_report.settled_amount,
        service_id: cre_report.service_id,
        workflow_id,
        nonce: cre_report.nonce,
    });

    this.vm().log(SettlementExecuted {
        funder: cre_report.funder,
        allocated_capacity: cre_report.requested_capacity,
        fee_paid: cre_report.settled_amount,
        payment_id,
        nonce: cre_report.nonce,
    });

    Ok(())
}

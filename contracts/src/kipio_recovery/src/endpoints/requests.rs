//! `start_recovery` and `approve_recovery` handlers.

use alloc::vec::Vec;

use stylus_sdk::{
    abi::Bytes,
    alloy_primitives::{Address, B256, U8, U64, U256},
    alloy_sol_types::SolError,
    crypto::keccak,
    prelude::*,
};

use crate::abi::errors::{
    AlreadyApproved, EmptyPubkey, EmptySignature, ExpiredDeadline, GuardiansNotConfigured,
    RecoveryExpiredErr, RecoveryNotActive, RecoveryNotFound, SignatureVerificationFailed,
    UnknownGuardian,
};
use crate::abi::events::{RecoveryApprovalGranted, RecoveryApproved, RecoveryStarted};
use crate::config::constants::{
    APPROVAL_BITS, CHALLENGE_PERIOD_SECONDS, RECOVERY_STATUS_ACTIVE, RECOVERY_STATUS_APPROVED,
};
use crate::storage::entrypoint::KipioRecovery;

pub(crate) fn handle_start_recovery(
    this: &mut KipioRecovery,
    account: Address,
    target_hash: B256,
    deadline: U64,
) -> Result<B256, Vec<u8>> {
    this.require_runtime()?;
    this.require_initialized()?;

    if target_hash == B256::ZERO {
        return Err(RecoveryNotFound {}.abi_encode());
    }

    let now = U64::from(this.vm().block_timestamp());
    if now > deadline {
        return Err(ExpiredDeadline {}.abi_encode());
    }

    this.ensure_no_active_recovery(account)?;

    let current_version = this.guardian_versions.getter(account).get();
    if current_version == U64::ZERO {
        return Err(GuardiansNotConfigured {}.abi_encode());
    }

    let counter = this.next_recovery_id.getter(account).get();
    let account_bytes = account.to_vec();
    let counter_bytes = counter.to_be_bytes::<32>();

    let mut preimage = Vec::with_capacity(52);
    preimage.extend_from_slice(&account_bytes);
    preimage.extend_from_slice(&counter_bytes);
    let request_id = keccak(&preimage);

    this.next_recovery_id
        .setter(account)
        .set(counter + U64::from(1u64));

    this.recovery_target_hash
        .setter(account)
        .setter(request_id)
        .set(target_hash);
    this.recovery_deadline
        .setter(account)
        .setter(request_id)
        .set(deadline);
    this.recovery_guardian_version
        .setter(account)
        .setter(request_id)
        .set(current_version);
    this.recovery_approval_count
        .setter(account)
        .setter(request_id)
        .set(U8::ZERO);
    this.recovery_status
        .setter(account)
        .setter(request_id)
        .set(U8::from(RECOVERY_STATUS_ACTIVE));
    this.active_recovery_id.setter(account).set(request_id);

    this.vm().log(RecoveryStarted {
        account,
        requestId: request_id,
        targetHash: target_hash,
        deadline: deadline.to::<u64>(),
        guardianVersion: current_version.to::<u64>(),
    });

    Ok(request_id)
}

pub(crate) fn handle_approve_recovery(
    this: &mut KipioRecovery,
    account: Address,
    request_id: B256,
    guardian_pubkey: Bytes,
    signature: Bytes,
) -> Result<(), Vec<u8>> {
    this.require_runtime()?;
    this.require_initialized()?;

    if guardian_pubkey.is_empty() {
        return Err(EmptyPubkey {}.abi_encode());
    }
    if signature.is_empty() {
        return Err(EmptySignature {}.abi_encode());
    }

    let status = this
        .recovery_status
        .getter(account)
        .getter(request_id)
        .get()
        .to::<u8>();
    if status != RECOVERY_STATUS_ACTIVE {
        return Err(RecoveryNotActive {}.abi_encode());
    }

    if this.is_expired(account, request_id) {
        this.mark_expired(account, request_id);
        return Err(RecoveryExpiredErr {}.abi_encode());
    }

    let version = this
        .recovery_guardian_version
        .getter(account)
        .getter(request_id)
        .get();
    let guardian_hash = keccak(&guardian_pubkey.0);

    let idx = match this.find_guardian_index(account, version, guardian_hash) {
        Some(i) => i,
        None => return Err(UnknownGuardian {}.abi_encode()),
    };

    let curve = this.guardian_curve_at(account, version, idx);

    let bit = U256::from(APPROVAL_BITS[idx as usize]);
    let approvals = this
        .recovery_approvals
        .getter(account)
        .getter(request_id)
        .get();
    if !(approvals & bit).is_zero() {
        return Err(AlreadyApproved {}.abi_encode());
    }

    let target_hash = this
        .recovery_target_hash
        .getter(account)
        .getter(request_id)
        .get();
    let digest = this.build_recovery_approval_digest(account, request_id, target_hash);

    if !this.verify_guardian_signature(curve, digest, &signature, &guardian_pubkey) {
        return Err(SignatureVerificationFailed {}.abi_encode());
    }

    this.recovery_approvals
        .setter(account)
        .setter(request_id)
        .set(approvals | bit);

    let count = this
        .recovery_approval_count
        .getter(account)
        .getter(request_id)
        .get();
    let new_count = count + U8::from(1u8);
    this.recovery_approval_count
        .setter(account)
        .setter(request_id)
        .set(new_count);

    this.vm().log(RecoveryApprovalGranted {
        requestId: request_id,
        guardianHash: guardian_hash,
        curve,
    });

    let threshold = this.guardian_threshold_at(account, version);
    if new_count >= threshold {
        let now = U64::from(this.vm().block_timestamp());
        let executable_after = now + U64::from(CHALLENGE_PERIOD_SECONDS);

        this.recovery_status
            .setter(account)
            .setter(request_id)
            .set(U8::from(RECOVERY_STATUS_APPROVED));
        this.recovery_executable_after
            .setter(account)
            .setter(request_id)
            .set(executable_after);

        this.vm().log(RecoveryApproved {
            requestId: request_id,
            executableAfter: executable_after.to::<u64>(),
        });
    }

    Ok(())
}

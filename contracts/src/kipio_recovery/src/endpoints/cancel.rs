//! `cancel_recovery` handler.

use alloc::vec::Vec;

use stylus_sdk::{
    abi::Bytes,
    alloy_primitives::{Address, B256, U8, U64},
    alloy_sol_types::SolError,
    crypto::keccak,
    prelude::*,
};

use crate::abi::errors::{
    CancelNotAuthorized, EmptyPubkey, EmptySignature, RecoveryAlreadyFinalized,
    RecoveryExpiredErr, RecoveryNotFound,
};
use crate::abi::events::RecoveryCancelled;
use crate::abi::interfaces::IKipioAccount;
use crate::config::constants::{
    RECOVERY_STATUS_CANCELLED, RECOVERY_STATUS_EXECUTED, RECOVERY_STATUS_EXPIRED,
    RECOVERY_STATUS_NONE,
};
use crate::storage::entrypoint::KipioRecovery;

pub(crate) fn handle_cancel_recovery(
    this: &mut KipioRecovery,
    account: Address,
    request_id: B256,
    signer_pubkey: Bytes,
    signer_signature: Bytes,
    signer_curve: u8,
) -> Result<(), Vec<u8>> {
    this.require_runtime()?;
    this.require_initialized()?;

    if signer_pubkey.is_empty() {
        return Err(EmptyPubkey {}.abi_encode());
    }
    if signer_signature.is_empty() {
        return Err(EmptySignature {}.abi_encode());
    }

    let status = this
        .recovery_status
        .getter(account)
        .getter(request_id)
        .get()
        .to::<u8>();
    if status == RECOVERY_STATUS_NONE {
        return Err(RecoveryNotFound {}.abi_encode());
    }
    if status == RECOVERY_STATUS_EXECUTED
        || status == RECOVERY_STATUS_CANCELLED
        || status == RECOVERY_STATUS_EXPIRED
    {
        return Err(RecoveryAlreadyFinalized {}.abi_encode());
    }

    if this.is_expired(account, request_id) {
        this.mark_expired(account, request_id);
        return Err(RecoveryExpiredErr {}.abi_encode());
    }

    // Cross-call the Account to verify the signer's credential is
    // currently ACTIVE. The credential id is the keccak fingerprint of
    // the raw pubkey.
    let credential_id = keccak(&signer_pubkey.0);
    let account_client = IKipioAccount::new(account);
    let host_view = this.vm();
    let call_ctx = Call::new();

    let is_active = account_client
        .is_credential_active(host_view, call_ctx, credential_id)
        .map_err(|_| CancelNotAuthorized {}.abi_encode())?;
    if !is_active {
        return Err(CancelNotAuthorized {}.abi_encode());
    }

    // Bind the cancellation to the account's current nonce. This
    // prevents a stale signature from being replayed after any state
    // change on the account.
    let account_client = IKipioAccount::new(account);
    let host_view = this.vm();
    let call_ctx = Call::new();
    let current_nonce = account_client
        .get_nonce(host_view, call_ctx)
        .map_err(|_| CancelNotAuthorized {}.abi_encode())?;

    let digest = this.build_recovery_cancel_digest(
        account,
        request_id,
        U64::from(current_nonce),
    );

    if !this.verify_guardian_signature(
        signer_curve,
        digest,
        &signer_signature,
        &signer_pubkey,
    ) {
        return Err(CancelNotAuthorized {}.abi_encode());
    }

    this.recovery_status
        .setter(account)
        .setter(request_id)
        .set(U8::from(RECOVERY_STATUS_CANCELLED));
    this.active_recovery_id.setter(account).set(B256::ZERO);

    this.vm().log(RecoveryCancelled {
        requestId: request_id,
        cancelledBy: this.vm().msg_sender(),
    });

    Ok(())
}

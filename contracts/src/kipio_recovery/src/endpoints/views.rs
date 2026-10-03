//! Read-only views with non-trivial logic.

use alloc::vec::Vec;

use stylus_sdk::{
    alloy_primitives::{Address, B256, U8, U64},
    alloy_sol_types::SolError,
};

use crate::abi::errors::{GuardiansNotConfigured, RecoveryNotFound};
use crate::codec::guardian::guardian_meta_unpack;
use crate::config::constants::RECOVERY_STATUS_NONE;
use crate::storage::entrypoint::KipioRecovery;

pub(crate) fn get_guardian_set(
    this: &KipioRecovery,
    account: Address,
    version: U64,
) -> Result<(u8, u8, Vec<u8>, Vec<B256>, Vec<u8>), Vec<u8>> {
    if version == U64::ZERO || version > this.guardian_versions.getter(account).get() {
        return Err(GuardiansNotConfigured {}.abi_encode());
    }

    let (count, threshold, _reason) =
        guardian_meta_unpack(this.guardian_meta.getter(account).getter(version).get());
    let schedule = this
        .guardian_schedule
        .getter(account)
        .getter(version)
        .get();
    let schedule_bytes = schedule.as_slice();

    let mut types = Vec::with_capacity(count as usize);
    let mut ids = Vec::with_capacity(count as usize);
    let mut curves = Vec::with_capacity(count as usize);

    for i in 0..count {
        let i_usize = i as usize;
        types.push(schedule_bytes[i_usize]);
        curves.push(schedule_bytes[16 + i_usize]);
        ids.push(
            this.guardian_identifiers
                .getter(account)
                .getter(version)
                .getter(U8::from(i))
                .get(),
        );
    }

    Ok((count, threshold, types, ids, curves))
}

pub(crate) fn get_recovery_request(
    this: &KipioRecovery,
    account: Address,
    request_id: B256,
) -> Result<(u8, u64, u64, u64, u8, B256, bool), Vec<u8>> {
    let status = this
        .recovery_status
        .getter(account)
        .getter(request_id)
        .get()
        .to::<u8>();
    if status == RECOVERY_STATUS_NONE {
        return Err(RecoveryNotFound {}.abi_encode());
    }

    let version = this
        .recovery_guardian_version
        .getter(account)
        .getter(request_id)
        .get()
        .to::<u64>();
    let deadline = this
        .recovery_deadline
        .getter(account)
        .getter(request_id)
        .get()
        .to::<u64>();
    let executable_after = this
        .recovery_executable_after
        .getter(account)
        .getter(request_id)
        .get()
        .to::<u64>();
    let approvals = this
        .recovery_approval_count
        .getter(account)
        .getter(request_id)
        .get()
        .to::<u8>();
    let target = this
        .recovery_target_hash
        .getter(account)
        .getter(request_id)
        .get();
    let expired = this.is_expired(account, request_id);

    Ok((
        status,
        version,
        deadline,
        executable_after,
        approvals,
        target,
        expired,
    ))
}

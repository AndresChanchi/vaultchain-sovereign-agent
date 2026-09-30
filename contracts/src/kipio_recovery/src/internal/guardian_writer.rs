//! Guardian version persistence and read helpers.

use alloc::vec::Vec;

use stylus_sdk::{
    alloy_primitives::{Address, B256, U64, U8},
    alloy_sol_types::SolError,
};

use crate::abi::errors::{
    DuplicateGuardian, InvalidCurve, InvalidGuardianCount, InvalidGuardianType,
    InvalidThreshold, MaxGuardiansExceeded, ZeroGuardianIdentifier,
};
use crate::codec::guardian::{guardian_meta_pack, guardian_meta_unpack, guardian_schedule_pack};
use crate::config::constants::{CURVE_P256, CURVE_SECP256K1, MAX_GUARDIANS};
use crate::storage::entrypoint::KipioRecovery;

impl KipioRecovery {
    /// Validates and persists a guardian version. Fails fast on any
    /// structural invariant violation BEFORE writing a single slot, so a
    /// malformed set leaves no partial state behind.
    pub(crate) fn write_guardian_version(
        &mut self,
        account: Address,
        version: U64,
        guardian_types: &[u8],
        guardian_identifiers: &[B256],
        guardian_curves: &[u8],
        threshold: u8,
        update_reason: u8,
    ) -> Result<(), Vec<u8>> {
        let count = guardian_types.len();

        if count == 0 {
            return Err(InvalidGuardianCount {}.abi_encode());
        }
        if count > MAX_GUARDIANS {
            return Err(MaxGuardiansExceeded {}.abi_encode());
        }
        if guardian_identifiers.len() != count || guardian_curves.len() != count {
            return Err(InvalidGuardianCount {}.abi_encode());
        }
        if threshold == 0 || threshold > count as u8 {
            return Err(InvalidThreshold {}.abi_encode());
        }

        // Duplicate detection is O(N^2) but bounded by MAX_GUARDIANS.
        // For N = 16, this is 120 comparisons, negligible in wasm.
        for i in 0..count {
            if guardian_identifiers[i] == B256::ZERO {
                return Err(ZeroGuardianIdentifier {}.abi_encode());
            }
            for j in (i + 1)..count {
                if guardian_identifiers[i] == guardian_identifiers[j] {
                    return Err(DuplicateGuardian {}.abi_encode());
                }
            }
        }

        for i in 0..count {
            if guardian_types[i] == 0 {
                return Err(InvalidGuardianType {}.abi_encode());
            }
            let curve = guardian_curves[i];
            if curve != CURVE_P256 && curve != CURVE_SECP256K1 {
                return Err(InvalidCurve {}.abi_encode());
            }
        }

        // Effects: write N identifiers + 1 schedule + 1 meta.
        for i in 0..count {
            self.guardian_identifiers
                .setter(account)
                .setter(version)
                .setter(U8::from(i as u8))
                .set(guardian_identifiers[i]);
        }

        self.guardian_schedule
            .setter(account)
            .setter(version)
            .set(guardian_schedule_pack(guardian_types, guardian_curves));

        self.guardian_meta
            .setter(account)
            .setter(version)
            .set(guardian_meta_pack(count as u8, threshold, update_reason));

        Ok(())
    }

    #[inline]
    pub(crate) fn guardian_count_at(&self, account: Address, version: U64) -> u8 {
        guardian_meta_unpack(self.guardian_meta.getter(account).getter(version).get()).0
    }

    #[inline]
    pub(crate) fn guardian_threshold_at(&self, account: Address, version: U64) -> u8 {
        guardian_meta_unpack(self.guardian_meta.getter(account).getter(version).get()).1
    }

    #[inline]
    pub(crate) fn guardian_curve_at(&self, account: Address, version: U64, idx: u8) -> u8 {
        let schedule = self
            .guardian_schedule
            .getter(account)
            .getter(version)
            .get();
        schedule.as_slice()[16 + idx as usize]
    }

    /// Linear scan over the guardian identifiers of a version.
    ///
    /// With N <= `MAX_GUARDIANS` (16), this is bounded and cheap; the
    /// storage cost saved by not maintaining a reverse index outweighs
    /// the compute cost.
    pub(crate) fn find_guardian_index(
        &self,
        account: Address,
        version: U64,
        hash: B256,
    ) -> Option<u8> {
        let count = self.guardian_count_at(account, version);
        // Bind intermediates so the temporary storage handles outlive
        // the loop that borrows them.
        let ids_account_map = self.guardian_identifiers.getter(account);
        let ids_version_map = ids_account_map.getter(version);
        for i in 0..count {
            if ids_version_map.getter(U8::from(i)).get() == hash {
                return Some(i);
            }
        }
        None
    }
}

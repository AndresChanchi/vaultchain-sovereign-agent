//! Storage term extension dispatch handlers.
//!
//! Semantics of `expiry_delta`: absolute seconds from `created_at`
//! until expiry. To extend by another 30 days from now, the user
//! computes the new total delta themselves.
//!
//! Check order (matters for idempotency):
//!   1. Idempotent no-op FIRST. Covers PERMANENT → PERMANENT and any
//!      same-term-same-delta call. This keeps batch retries from
//!      reverting on already-satisfied items.
//!   2. Reject attempts to extend an already-PERMANENT content with
//!      a different (necessarily shorter) target.
//!   3. Reject downgrades: the new absolute delta must be >= old.
//!      Comparison is on deltas, not term IDs, because CUSTOM can
//!      represent any duration (e.g., a CUSTOM 10-day term is shorter
//!      than a 30_DAYS term despite a higher numeric ID).

use super::*;

impl KipioIdentityContent {
    #[inline(never)]
    pub(crate) fn dispatch_extend_storage_term(&mut self, args: &[u8]) -> ArbResult {
        let call = extendStorageTermCall::abi_decode(args).map_err(|_| Vec::new())?;

        self.require_not_paused()?;
        validate_storage_term(call.new_storage_term)?;

        let resolved_delta =
            resolve_expiry_delta(call.new_storage_term, call.custom_expiry_delta)?;

        let sender = self.vm().msg_sender();
        let now = self.vm().block_timestamp();

        let old_term: u8;
        let old_delta: u32;

        {
            let mut vault = self.vaults.setter(sender);
            let mut record = vault.contents.setter(call.content_id);

            let packed = record.packed.get();
            if packed == U256::ZERO {
                return Err(NotFound {}.abi_encode());
            }

            old_term = read_storage_term(packed);
            old_delta = read_expiry_delta(packed);

            if call.new_storage_term == old_term && resolved_delta == old_delta {
                return Ok(Vec::new());
            }

            if old_term == STORAGE_TERM_PERMANENT {
                return Err(ContentAlreadyPermanent {}.abi_encode());
            }

            if call.new_storage_term != STORAGE_TERM_PERMANENT && resolved_delta < old_delta {
                return Err(UnsupportedStorageTerm {}.abi_encode());
            }

            record.packed.set(write_storage_term_and_expiry(
                packed,
                call.new_storage_term,
                resolved_delta,
                now,
            ));
        }

        self.vm().log(ContentStorageTermExtended {
            user: sender,
            contentHash: call.content_id,
            oldTerm: old_term,
            newTerm: call.new_storage_term,
            newExpiryDelta: resolved_delta,
        });

        Ok(Vec::new())
    }

    #[inline(never)]
    pub(crate) fn dispatch_extend_storage_term_batch(&mut self, args: &[u8]) -> ArbResult {
        let call = decode_extend_storage_term_batch(args)?;

        self.require_not_paused()?;

        let content_ids = &call.content_ids;
        let new_storage_terms = &call.new_storage_terms;
        let custom_expiry_deltas = &call.custom_expiry_deltas;

        let len = content_ids.len();
        if len == 0 {
            return Err(EmptyBatch {}.abi_encode());
        }
        if len > MAX_BATCH_SIZE {
            return Err(BatchTooLarge {}.abi_encode());
        }
        if new_storage_terms.len() != len || custom_expiry_deltas.len() != len {
            return Err(LengthMismatch {}.abi_encode());
        }

        let sender = self.vm().msg_sender();
        let now = self.vm().block_timestamp();

        let mut events: Vec<(B256, u8, u8, u32)> = Vec::with_capacity(len);

        {
            let mut vault = self.vaults.setter(sender);
            for i in 0..len {
                let content_id = content_ids[i];
                let new_term = new_storage_terms[i];
                validate_storage_term(new_term)?;
                let resolved_delta = resolve_expiry_delta(new_term, custom_expiry_deltas[i])?;

                let mut record = vault.contents.setter(content_id);
                let packed = record.packed.get();
                if packed == U256::ZERO {
                    return Err(NotFound {}.abi_encode());
                }

                let old_term = read_storage_term(packed);
                let old_delta = read_expiry_delta(packed);

                if new_term == old_term && resolved_delta == old_delta {
                    continue;
                }

                if old_term == STORAGE_TERM_PERMANENT {
                    return Err(ContentAlreadyPermanent {}.abi_encode());
                }

                if new_term != STORAGE_TERM_PERMANENT && resolved_delta < old_delta {
                    return Err(UnsupportedStorageTerm {}.abi_encode());
                }

                record.packed.set(write_storage_term_and_expiry(
                    packed,
                    new_term,
                    resolved_delta,
                    now,
                ));

                events.push((content_id, old_term, new_term, resolved_delta));
            }
        }

        for (content_id, old_term, new_term, new_delta) in events {
            self.vm().log(ContentStorageTermExtended {
                user: sender,
                contentHash: content_id,
                oldTerm: old_term,
                newTerm: new_term,
                newExpiryDelta: new_delta,
            });
        }

        Ok(Vec::new())
    }
}

//! Visibility toggles and delete dispatch handlers.
//!
//! Visibility is user-sovereign: no role, no operator, no approval
//! flow. The owner toggles it freely.
//!
//! IRREVERSIBILITY WARNING (documented, not enforced):
//!   Once public, third parties may have copied the content. Toggling
//!   back to private does NOT recall those copies. The contract records
//!   the intent; it cannot enforce downstream egress. The user accepts
//!   this trade-off when publishing.
//!
//! Delete is idempotent: deleting a non-existent content is a silent
//! no-op. After deletion, the content_id can be reused by a fresh
//! register. Events are the historical outbox; no on-chain tombstone
//! is needed.

use super::*;

impl KipioIdentityContent {
    // --------------------------------------------------------------------
    // VISIBILITY
    // --------------------------------------------------------------------

    #[inline(never)]
    pub(crate) fn dispatch_set_visibility(&mut self, args: &[u8]) -> ArbResult {
        let call = setVisibilityCall::abi_decode(args).map_err(|_| Vec::new())?;

        self.require_not_paused()?;

        let sender = self.vm().msg_sender();
        let now = self.vm().block_timestamp();

        {
            let mut vault = self.vaults.setter(sender);
            let mut record = vault.contents.setter(call.content_id);

            let packed = record.packed.get();
            if packed == U256::ZERO {
                return Err(NotFound {}.abi_encode());
            }
            if read_is_public(packed) == call.is_public {
                return Ok(Vec::new());
            }
            record
                .packed
                .set(write_is_public_and_updated_at(packed, call.is_public, now));
        }

        self.vm().log(ContentVisibilityUpdated {
            user: sender,
            contentHash: call.content_id,
            isPublic: call.is_public,
        });

        Ok(Vec::new())
    }

    #[inline(never)]
    pub(crate) fn dispatch_set_visibility_batch(&mut self, args: &[u8]) -> ArbResult {
        let call = decode_set_visibility_batch(args)?;

        self.require_not_paused()?;

        let content_ids = &call.content_ids;
        let is_publics = &call.is_publics;

        let len = content_ids.len();
        if len == 0 {
            return Err(EmptyBatch {}.abi_encode());
        }
        if len > MAX_BATCH_SIZE {
            return Err(BatchTooLarge {}.abi_encode());
        }
        if is_publics.len() != len {
            return Err(LengthMismatch {}.abi_encode());
        }

        let sender = self.vm().msg_sender();
        let now = self.vm().block_timestamp();
        let mut events: Vec<(B256, bool)> = Vec::with_capacity(len);

        {
            let mut vault = self.vaults.setter(sender);
            for i in 0..len {
                let content_id = content_ids[i];
                let is_public = is_publics[i];

                let mut record = vault.contents.setter(content_id);
                let packed = record.packed.get();
                if packed == U256::ZERO {
                    return Err(NotFound {}.abi_encode());
                }
                if read_is_public(packed) == is_public {
                    continue;
                }
                record
                    .packed
                    .set(write_is_public_and_updated_at(packed, is_public, now));
                events.push((content_id, is_public));
            }
        }

        for (content_id, is_public) in events {
            self.vm().log(ContentVisibilityUpdated {
                user: sender,
                contentHash: content_id,
                isPublic: is_public,
            });
        }

        Ok(Vec::new())
    }

    // --------------------------------------------------------------------
    // DELETE CONTENT
    // --------------------------------------------------------------------

    #[inline(never)]
    pub(crate) fn dispatch_delete_content(&mut self, args: &[u8]) -> ArbResult {
        let call = deleteContentCall::abi_decode(args).map_err(|_| Vec::new())?;

        self.require_not_paused()?;

        let sender = self.vm().msg_sender();

        {
            let vault = self.vaults.getter(sender);
            if vault.contents.getter(call.content_id).tx_commitment.get() == B256::ZERO {
                return Ok(Vec::new());
            }
        }

        {
            let mut vault = self.vaults.setter(sender);

            let pos = vault.content_positions.getter(call.content_id).get();
            if pos != U256::ZERO {
                let idx = (pos.as_limbs()[0] - 1) as usize;
                let last_idx = vault.content_list.len() - 1;

                if idx != last_idx {
                    let last_item: B256 = vault.content_list.getter(last_idx).unwrap().get();
                    vault.content_list.setter(idx).unwrap().set(last_item);
                    vault
                        .content_positions
                        .setter(last_item)
                        .set(U256::from(idx as u64 + 1));
                }
                vault.content_list.pop();
                vault.content_positions.setter(call.content_id).set(U256::ZERO);
            }

            let mut record = vault.contents.setter(call.content_id);
            record.tx_commitment.set(B256::ZERO);
            record.access_policy_hash.set(B256::ZERO);
            record.packed.set(U256::ZERO);

            let mut grantees: Vec<Address> = Vec::new();
            {
                let index = vault.access.grantee_index.getter(call.content_id);
                let total = index.len();
                for i in 0..total {
                    if let Some(addr_guard) = index.getter(i) {
                        grantees.push(addr_guard.get());
                    }
                }
            }

            for addr in grantees {
                vault
                    .access
                    .permissions
                    .setter(call.content_id)
                    .setter(addr)
                    .set(false);
                vault
                    .access
                    .grantee_positions
                    .setter(call.content_id)
                    .setter(addr)
                    .set(U256::ZERO);
            }

            // SAFETY: StorageAddress tolerates zero-slots; set_len(0) is safe.
            let mut index = vault.access.grantee_index.setter(call.content_id);
            unsafe {
                index.set_len(0);
            }
        }

        self.vm().log(ContentDeleted {
            user: sender,
            contentHash: call.content_id,
        });

        Ok(Vec::new())
    }
}

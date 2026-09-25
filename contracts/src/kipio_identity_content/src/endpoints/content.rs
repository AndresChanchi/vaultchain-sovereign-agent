//! Content registration and rotation dispatch handlers.
//!
//! User-sovereign content registry: every caller owns their own vault
//! (`vaults[msg_sender]`). `register_content` inserts a new record,
//! `register_batch` amortizes the cost across many, and `rotate_content`
//! / `rotate_content_cas` update the transaction commitment to a new
//! version. All are gated by the circuit breaker.

use super::*;

impl KipioIdentityContent {
    // --------------------------------------------------------------------
    // CONTENT REGISTRATION
    // --------------------------------------------------------------------

    #[inline(never)]
    pub(crate) fn dispatch_register_content(&mut self, args: &[u8]) -> ArbResult {
        let call = registerContentCall::abi_decode(args).map_err(|_| Vec::new())?;

        self.require_not_paused()?;

        if call.content_id == B256::ZERO {
            return Err(ZeroContentId {}.abi_encode());
        }
        if call.tx_commitment == B256::ZERO {
            return Err(ZeroCommitment {}.abi_encode());
        }
        validate_provider_id(call.provider_id)?;
        validate_storage_term(call.storage_term)?;
        let resolved_delta = resolve_expiry_delta(call.storage_term, call.expiry_delta)?;

        let sender = self.vm().msg_sender();

        {
            let vault = self.vaults.getter(sender);
            let record = vault.contents.getter(call.content_id);
            let existing = record.tx_commitment.get();
            if existing != B256::ZERO {
                if existing == call.tx_commitment {
                    return Ok(Vec::new());
                }
                return Err(AlreadyExists {}.abi_encode());
            }
        }

        let now = self.vm().block_timestamp();

        {
            let mut vault = self.vaults.setter(sender);
            let mut record = vault.contents.setter(call.content_id);

            record.tx_commitment.set(call.tx_commitment);
            record.access_policy_hash.set(call.access_policy_hash);
            record.packed.set(pack_metadata(
                1,
                now,
                now,
                call.provider_id,
                call.is_public,
                call.storage_term,
                resolved_delta,
            ));

            let new_index = vault.content_list.len() as u64;
            vault.content_list.grow().set(call.content_id);
            vault.content_positions.setter(call.content_id).set(U256::from(new_index + 1));
        }

        let current_total = self.global_registrations.get();
        self.global_registrations.set(current_total + U256::from(1));

        self.vm().log(ContentRegistered {
            user: sender,
            contentHash: call.content_id,
            txCommitment: call.tx_commitment,
            providerId: call.provider_id,
            storageTerm: call.storage_term,
        });

        Ok(Vec::new())
    }

    #[inline(never)]
    pub(crate) fn dispatch_register_batch(&mut self, args: &[u8]) -> ArbResult {
        let call = decode_register_batch(args)?;

        self.require_not_paused()?;

        let content_ids = &call.content_ids;
        let tx_commitments = &call.tx_commitments;
        let provider_ids = &call.provider_ids;
        let access_policy_hashes = &call.access_policy_hashes;
        let storage_terms = &call.storage_terms;
        let expiry_deltas = &call.expiry_deltas;

        let len = content_ids.len();
        if len == 0 {
            return Err(EmptyBatch {}.abi_encode());
        }
        if len > MAX_BATCH_SIZE {
            return Err(BatchTooLarge {}.abi_encode());
        }
        if tx_commitments.len() != len
            || provider_ids.len() != len
            || access_policy_hashes.len() != len
            || storage_terms.len() != len
            || expiry_deltas.len() != len
        {
            return Err(LengthMismatch {}.abi_encode());
        }

        let sender = self.vm().msg_sender();

        let mut to_insert: Vec<(usize, u32)> = Vec::new();
        {
            let vault = self.vaults.getter(sender);
            for i in 0..len {
                if content_ids[i] == B256::ZERO {
                    return Err(ZeroContentId {}.abi_encode());
                }
                if tx_commitments[i] == B256::ZERO {
                    return Err(ZeroCommitment {}.abi_encode());
                }
                validate_provider_id(provider_ids[i])?;
                validate_storage_term(storage_terms[i])?;
                let resolved = resolve_expiry_delta(storage_terms[i], expiry_deltas[i])?;

                let record = vault.contents.getter(content_ids[i]);
                let existing = record.tx_commitment.get();
                if existing == B256::ZERO {
                    to_insert.push((i, resolved));
                } else if existing != tx_commitments[i] {
                    return Err(AlreadyExists {}.abi_encode());
                }
            }
        }

        let now = self.vm().block_timestamp();
        let mut events: Vec<(B256, B256, u8, u8)> = Vec::with_capacity(to_insert.len());

        {
            let mut vault = self.vaults.setter(sender);
            for &(i, resolved_delta) in &to_insert {
                let content_id = content_ids[i];
                let tx_commitment = tx_commitments[i];
                let provider_id = provider_ids[i];
                let access_policy_hash = access_policy_hashes[i];
                let storage_term = storage_terms[i];

                let mut record = vault.contents.setter(content_id);
                record.tx_commitment.set(tx_commitment);
                record.access_policy_hash.set(access_policy_hash);
                record.packed.set(pack_metadata(
                    1,
                    now,
                    now,
                    provider_id,
                    false,
                    storage_term,
                    resolved_delta,
                ));

                let new_index = vault.content_list.len() as u64;
                vault.content_list.grow().set(content_id);
                vault.content_positions.setter(content_id).set(U256::from(new_index + 1));

                events.push((content_id, tx_commitment, provider_id, storage_term));
            }
        }

        if !to_insert.is_empty() {
            let current_total = self.global_registrations.get();
            self.global_registrations
                .set(current_total + U256::from(to_insert.len() as u64));
        }

        for (content_id, tx_commitment, provider_id, storage_term) in events {
            self.vm().log(ContentRegistered {
                user: sender,
                contentHash: content_id,
                txCommitment: tx_commitment,
                providerId: provider_id,
                storageTerm: storage_term,
            });
        }

        Ok(Vec::new())
    }

    #[inline(never)]
    pub(crate) fn dispatch_rotate_content(&mut self, args: &[u8]) -> ArbResult {
        let call = rotateContentCall::abi_decode(args).map_err(|_| Vec::new())?;

        self.require_not_paused()?;
        if call.new_tx_commitment == B256::ZERO {
            return Err(ZeroCommitment {}.abi_encode());
        }

        let sender = self.vm().msg_sender();
        let now = self.vm().block_timestamp();
        let new_version: u64;

        {
            let mut vault = self.vaults.setter(sender);
            let mut record = vault.contents.setter(call.content_id);

            if record.tx_commitment.get() == B256::ZERO {
                return Err(NotFound {}.abi_encode());
            }

            let packed = record.packed.get();
            new_version = read_version(packed) + 1;

            record.tx_commitment.set(call.new_tx_commitment);
            record.access_policy_hash.set(call.new_access_policy_hash);
            record.packed.set(write_version(write_updated_at(packed, now), new_version));
        }

        self.vm().log(ContentRotated {
            user: sender,
            contentHash: call.content_id,
            newTxCommitment: call.new_tx_commitment,
            newVersion: new_version as u32,
        });

        Ok(Vec::new())
    }

    #[inline(never)]
    pub(crate) fn dispatch_rotate_content_cas(&mut self, args: &[u8]) -> ArbResult {
        let call = rotateContentCasCall::abi_decode(args).map_err(|_| Vec::new())?;

        self.require_not_paused()?;
        if call.new_tx_commitment == B256::ZERO {
            return Err(ZeroCommitment {}.abi_encode());
        }

        let sender = self.vm().msg_sender();
        let now = self.vm().block_timestamp();
        let new_version: u64;

        {
            let mut vault = self.vaults.setter(sender);
            let mut record = vault.contents.setter(call.content_id);

            if record.tx_commitment.get() == B256::ZERO {
                return Err(NotFound {}.abi_encode());
            }

            let packed = record.packed.get();
            let current_version = read_version(packed);
            if current_version != call.expected_version {
                return Err(VersionMismatch {}.abi_encode());
            }

            new_version = current_version + 1;
            record.tx_commitment.set(call.new_tx_commitment);
            record.access_policy_hash.set(call.new_access_policy_hash);
            record.packed.set(write_version(write_updated_at(packed, now), new_version));
        }

        self.vm().log(ContentRotated {
            user: sender,
            contentHash: call.content_id,
            newTxCommitment: call.new_tx_commitment,
            newVersion: new_version as u32,
        });

        Ok(Vec::new())
    }
}

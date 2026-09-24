//! # Public Interface
//!
//! Single `#[public] impl KipioContentAccess` block with every endpoint.
//!
//! Stylus SDK 0.10.x requires exactly ONE `#[public] impl` per entrypoint
//! struct. Splitting it across files causes:
//!
//!     E0119: conflicting implementations of trait `Router<_>`
//!
//! Therefore this file is the single source of truth for the ABI surface.

use alloc::vec::Vec;

use stylus_sdk::{
    alloy_primitives::{Address, Bytes, B256, FixedBytes, U256},
    alloy_sol_types::SolError,
    crypto::keccak,
    prelude::*,
};

use crate::abi::errors::*;
use crate::abi::events::*;
use crate::abi::interfaces::IZKVerifier;
use crate::codec::pack::{pack_metadata, unpack_metadata};
use crate::codec::read::{
    read_created_at, read_expiry_delta, read_is_public, read_storage_term, read_version,
};
use crate::codec::validate::{
    compute_absolute_expiry, resolve_expiry_delta, validate_provider_id, validate_storage_term,
};
use crate::codec::write::{
    write_is_public_and_updated_at, write_storage_term_and_expiry, write_updated_at, write_version,
};
use crate::config::constants::*;
use crate::internal::cre::decode_cre_report;
use crate::storage::entrypoint::KipioContentAccess;

// ============================================================================
// PUBLIC INTERFACE
// ============================================================================

#[public]
impl KipioContentAccess {
    #[constructor]
    pub fn constructor(
        &mut self,
        storage_provider: Address,
        query_provider: Address,
        access_provider: Address,
        expected_workflow_id: B256,
    ) -> Result<(), Vec<u8>> {
        let deployer = self.vm().tx_origin();
        if deployer == Address::ZERO {
            return Err(ZeroOwner {}.abi_encode());
        }
        self.owner.set(deployer);
        self.storage_provider.set(storage_provider);
        self.query_provider.set(query_provider);
        self.access_provider.set(access_provider);
        self.expected_workflow_id.set(expected_workflow_id);
        self.initialized.set(true);
        Ok(())
    }

    // ========================================================================
    // GOVERNANCE
    // ========================================================================

    pub fn transfer_ownership(&mut self, new_owner: Address) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        if new_owner == Address::ZERO {
            return Err(ZeroOwner {}.abi_encode());
        }
        let current = self.owner.get();
        self.pending_owner.set(new_owner);
        self.vm().log(OwnershipTransferStarted {
            previousOwner: current,
            newOwner: new_owner,
        });
        Ok(())
    }

    pub fn accept_ownership(&mut self) -> Result<(), Vec<u8>> {
        let sender = self.vm().msg_sender();
        let pending = self.pending_owner.get();
        if pending == Address::ZERO {
            return Err(NoPendingOwner {}.abi_encode());
        }
        if sender != pending {
            return Err(Unauthorized {}.abi_encode());
        }
        let old = self.owner.get();
        self.owner.set(pending);
        self.pending_owner.set(Address::ZERO);
        self.vm().log(OwnerUpdated { oldOwner: old, newOwner: pending });
        Ok(())
    }

    pub fn set_storage_provider(&mut self, provider: Address) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        if provider == Address::ZERO {
            return Err(ZeroAddress {}.abi_encode());
        }
        let old = self.storage_provider.get();
        self.storage_provider.set(provider);
        self.vm().log(ProviderUpdated { providerType: 0, oldProvider: old, newProvider: provider });
        Ok(())
    }

    pub fn set_query_provider(&mut self, provider: Address) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        if provider == Address::ZERO {
            return Err(ZeroAddress {}.abi_encode());
        }
        let old = self.query_provider.get();
        self.query_provider.set(provider);
        self.vm().log(ProviderUpdated { providerType: 1, oldProvider: old, newProvider: provider });
        Ok(())
    }

    pub fn set_access_provider(&mut self, provider: Address) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        if provider == Address::ZERO {
            return Err(ZeroAddress {}.abi_encode());
        }
        let old = self.access_provider.get();
        self.access_provider.set(provider);
        self.vm().log(ProviderUpdated { providerType: 2, oldProvider: old, newProvider: provider });
        Ok(())
    }

    pub fn set_zk_verifier(&mut self, verifier: Address) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        let old = self.zk_verifier.get();
        self.zk_verifier.set(verifier);
        self.vm().log(ZkVerifierUpdated { oldVerifier: old, newVerifier: verifier });
        Ok(())
    }

    pub fn set_expected_workflow_id(&mut self, workflow_id: B256) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        let old = self.expected_workflow_id.get();
        self.expected_workflow_id.set(workflow_id);
        self.vm().log(WorkflowIdUpdated { oldWorkflowId: old, newWorkflowId: workflow_id });
        Ok(())
    }

    // ========================================================================
    // CIRCUIT BREAKER
    // ========================================================================

    pub fn pause(&mut self, reason_hash: B256) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        if self.paused.get() {
            return Ok(());
        }
        self.paused.set(true);
        self.pause_reason_hash.set(reason_hash);
        self.vm().log(Paused { by: self.vm().msg_sender(), reasonHash: reason_hash });
        Ok(())
    }

    pub fn unpause(&mut self) -> Result<(), Vec<u8>> {
        self.require_owner()?;
        if !self.paused.get() {
            return Ok(());
        }
        self.paused.set(false);
        self.pause_reason_hash.set(B256::ZERO);
        self.vm().log(Unpaused { by: self.vm().msg_sender() });
        Ok(())
    }

    // ========================================================================
    // CONTENT REGISTRATION
    // ========================================================================

    pub fn register_content(
        &mut self,
        content_id: B256,
        tx_commitment: B256,
        provider_id: u8,
        access_policy_hash: B256,
        is_public: bool,
        storage_term: u8,
        expiry_delta: u32,
    ) -> Result<(), Vec<u8>> {
        self.require_not_paused()?;

        if content_id == B256::ZERO {
            return Err(ZeroContentId {}.abi_encode());
        }
        if tx_commitment == B256::ZERO {
            return Err(ZeroCommitment {}.abi_encode());
        }
        validate_provider_id(provider_id)?;
        validate_storage_term(storage_term)?;
        let resolved_delta = resolve_expiry_delta(storage_term, expiry_delta)?;

        let sender = self.vm().msg_sender();

        {
            let vault = self.vaults.getter(sender);
            let record = vault.contents.getter(content_id);
            let existing = record.tx_commitment.get();
            if existing != B256::ZERO {
                if existing == tx_commitment {
                    return Ok(());
                }
                return Err(AlreadyExists {}.abi_encode());
            }
        }

        let now = self.vm().block_timestamp();

        {
            let mut vault = self.vaults.setter(sender);
            let mut record = vault.contents.setter(content_id);

            record.tx_commitment.set(tx_commitment);
            record.access_policy_hash.set(access_policy_hash);
            record.packed.set(pack_metadata(1, now, now, provider_id, is_public, storage_term, resolved_delta));

            let new_index = vault.content_list.len() as u64;
            vault.content_list.grow().set(content_id);
            vault.content_positions.setter(content_id).set(U256::from(new_index + 1));
        }

        let current_total = self.global_registrations.get();
        self.global_registrations.set(current_total + U256::from(1));

        self.vm().log(ContentRegistered {
            user: sender,
            contentHash: content_id,
            txCommitment: tx_commitment,
            providerId: provider_id,
            storageTerm: storage_term,
        });

        Ok(())
    }

    pub fn register_batch(
        &mut self,
        content_ids: Vec<B256>,
        tx_commitments: Vec<B256>,
        provider_ids: Vec<u8>,
        access_policy_hashes: Vec<B256>,
        storage_terms: Vec<u8>,
        expiry_deltas: Vec<u32>,
    ) -> Result<(), Vec<u8>> {
        self.require_not_paused()?;

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
                record.packed.set(pack_metadata(1, now, now, provider_id, false, storage_term, resolved_delta));

                let new_index = vault.content_list.len() as u64;
                vault.content_list.grow().set(content_id);
                vault.content_positions.setter(content_id).set(U256::from(new_index + 1));

                events.push((content_id, tx_commitment, provider_id, storage_term));
            }
        }

        if !to_insert.is_empty() {
            let current_total = self.global_registrations.get();
            self.global_registrations.set(current_total + U256::from(to_insert.len() as u64));
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

        Ok(())
    }

    pub fn rotate_content(
        &mut self,
        content_id: B256,
        new_tx_commitment: B256,
        new_access_policy_hash: B256,
    ) -> Result<(), Vec<u8>> {
        self.require_not_paused()?;
        if new_tx_commitment == B256::ZERO {
            return Err(ZeroCommitment {}.abi_encode());
        }

        let sender = self.vm().msg_sender();
        let now = self.vm().block_timestamp();
        let new_version: u64;

        {
            let mut vault = self.vaults.setter(sender);
            let mut record = vault.contents.setter(content_id);

            if record.tx_commitment.get() == B256::ZERO {
                return Err(NotFound {}.abi_encode());
            }

            let packed = record.packed.get();
            new_version = read_version(packed) + 1;

            record.tx_commitment.set(new_tx_commitment);
            record.access_policy_hash.set(new_access_policy_hash);
            record.packed.set(write_version(write_updated_at(packed, now), new_version));
        }

        self.vm().log(ContentRotated {
            user: sender,
            contentHash: content_id,
            newTxCommitment: new_tx_commitment,
            newVersion: new_version as u32,
        });

        Ok(())
    }

    pub fn rotate_content_cas(
        &mut self,
        content_id: B256,
        expected_version: u64,
        new_tx_commitment: B256,
        new_access_policy_hash: B256,
    ) -> Result<(), Vec<u8>> {
        self.require_not_paused()?;
        if new_tx_commitment == B256::ZERO {
            return Err(ZeroCommitment {}.abi_encode());
        }

        let sender = self.vm().msg_sender();
        let now = self.vm().block_timestamp();
        let new_version: u64;

        {
            let mut vault = self.vaults.setter(sender);
            let mut record = vault.contents.setter(content_id);

            if record.tx_commitment.get() == B256::ZERO {
                return Err(NotFound {}.abi_encode());
            }

            let packed = record.packed.get();
            let current_version = read_version(packed);
            if current_version != expected_version {
                return Err(VersionMismatch {}.abi_encode());
            }

            new_version = current_version + 1;
            record.tx_commitment.set(new_tx_commitment);
            record.access_policy_hash.set(new_access_policy_hash);
            record.packed.set(write_version(write_updated_at(packed, now), new_version));
        }

        self.vm().log(ContentRotated {
            user: sender,
            contentHash: content_id,
            newTxCommitment: new_tx_commitment,
            newVersion: new_version as u32,
        });

        Ok(())
    }

    // ========================================================================
    // STORAGE TERM EXTENSION
    // ========================================================================
    //
    // Semantics of `expiry_delta`: absolute seconds from `created_at`
    // until expiry. To extend by another 30 days from now, the user
    // computes the new total delta themselves.
    //
    // Check order (matters for idempotency):
    //   1. Idempotent no-op FIRST. Covers PERMANENT → PERMANENT and any
    //      same-term-same-delta call. This keeps batch retries from
    //      reverting on already-satisfied items.
    //   2. Reject attempts to extend an already-PERMANENT content with
    //      a different (necessarily shorter) target.
    //   3. Reject downgrades: the new absolute delta must be >= old.
    //      Comparison is on deltas, not term IDs, because CUSTOM can
    //      represent any duration (e.g., a CUSTOM 10-day term is shorter
    //      than a 30_DAYS term despite a higher numeric ID).
    // ------------------------------------------------------------------------

    pub fn extend_storage_term(
        &mut self,
        content_id: B256,
        new_storage_term: u8,
        custom_expiry_delta: u32,
    ) -> Result<(), Vec<u8>> {
        self.require_not_paused()?;
        validate_storage_term(new_storage_term)?;

        let resolved_delta = resolve_expiry_delta(new_storage_term, custom_expiry_delta)?;

        let sender = self.vm().msg_sender();
        let now = self.vm().block_timestamp();

        let old_term: u8;
        let old_delta: u32;

        {
            let mut vault = self.vaults.setter(sender);
            let mut record = vault.contents.setter(content_id);

            let packed = record.packed.get();
            if packed == U256::ZERO {
                return Err(NotFound {}.abi_encode());
            }

            old_term = read_storage_term(packed);
            old_delta = read_expiry_delta(packed);

            // 1. Idempotent no-op: same term AND same delta.
            //    Covers PERMANENT → PERMANENT and any exact-repeat.
            if new_storage_term == old_term && resolved_delta == old_delta {
                return Ok(());
            }

            // 2. Cannot extend an already-permanent content to a finite term.
            if old_term == STORAGE_TERM_PERMANENT {
                return Err(ContentAlreadyPermanent {}.abi_encode());
            }

            // 3. Downgrade check: compare absolute deltas, not term IDs.
            //    Permanent is always an upgrade, so it bypasses the check.
            if new_storage_term != STORAGE_TERM_PERMANENT && resolved_delta < old_delta {
                return Err(UnsupportedStorageTerm {}.abi_encode());
            }

            record.packed.set(write_storage_term_and_expiry(
                packed,
                new_storage_term,
                resolved_delta,
                now,
            ));
        }

        self.vm().log(ContentStorageTermExtended {
            user: sender,
            contentHash: content_id,
            oldTerm: old_term,
            newTerm: new_storage_term,
            newExpiryDelta: resolved_delta,
        });

        Ok(())
    }

    pub fn extend_storage_term_batch(
        &mut self,
        content_ids: Vec<B256>,
        new_storage_terms: Vec<u8>,
        custom_expiry_deltas: Vec<u32>,
    ) -> Result<(), Vec<u8>> {
        self.require_not_paused()?;

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

                // 1. Idempotent no-op FIRST (covers PERMANENT → PERMANENT).
                if new_term == old_term && resolved_delta == old_delta {
                    continue;
                }

                // 2. Cannot extend an already-permanent content to a finite term.
                if old_term == STORAGE_TERM_PERMANENT {
                    return Err(ContentAlreadyPermanent {}.abi_encode());
                }

                // 3. Downgrade check on absolute deltas.
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

        Ok(())
    }

    // ========================================================================
    // VISIBILITY
    // ========================================================================
    //
    // Simple private/public toggle. Visibility is user-sovereign: no
    // role, no operator, no approval flow. The owner toggles it freely.
    //
    // IRREVERSIBILITY WARNING (documented, not enforced):
    //   Once public, third parties may have copied the content. Toggling
    //   back to private does NOT recall those copies. The contract records
    //   the intent; it cannot enforce downstream egress. The user accepts
    //   this trade-off when publishing.
    // ------------------------------------------------------------------------

    pub fn set_visibility(
        &mut self,
        content_id: B256,
        is_public: bool,
    ) -> Result<(), Vec<u8>> {
        self.require_not_paused()?;

        let sender = self.vm().msg_sender();
        let now = self.vm().block_timestamp();

        {
            let mut vault = self.vaults.setter(sender);
            let mut record = vault.contents.setter(content_id);

            let packed = record.packed.get();
            if packed == U256::ZERO {
                return Err(NotFound {}.abi_encode());
            }
            if read_is_public(packed) == is_public {
                return Ok(());
            }
            record.packed.set(write_is_public_and_updated_at(packed, is_public, now));
        }

        self.vm().log(ContentVisibilityUpdated {
            user: sender,
            contentHash: content_id,
            isPublic: is_public,
        });

        Ok(())
    }

    pub fn set_visibility_batch(
        &mut self,
        content_ids: Vec<B256>,
        is_publics: Vec<bool>,
    ) -> Result<(), Vec<u8>> {
        self.require_not_paused()?;

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
                record.packed.set(write_is_public_and_updated_at(packed, is_public, now));
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

        Ok(())
    }

    // ========================================================================
    // DELETE CONTENT
    // ========================================================================
    //
    // Idempotent: deleting a non-existent content is a silent no-op.
    // After deletion, the content_id can be reused by a fresh register.
    // Events are the historical outbox; no on-chain tombstone needed.
    // ------------------------------------------------------------------------

    pub fn delete_content(&mut self, content_id: B256) -> Result<(), Vec<u8>> {
        self.require_not_paused()?;

        let sender = self.vm().msg_sender();

        {
            let vault = self.vaults.getter(sender);
            if vault.contents.getter(content_id).tx_commitment.get() == B256::ZERO {
                return Ok(());
            }
        }

        {
            let mut vault = self.vaults.setter(sender);

            let pos = vault.content_positions.getter(content_id).get();
            if pos != U256::ZERO {
                let idx = (pos.as_limbs()[0] - 1) as usize;
                let last_idx = vault.content_list.len() - 1;

                if idx != last_idx {
                    let last_item: B256 = vault.content_list.getter(last_idx).unwrap().get();
                    vault.content_list.setter(idx).unwrap().set(last_item);
                    vault.content_positions.setter(last_item).set(U256::from(idx as u64 + 1));
                }
                vault.content_list.pop();
                vault.content_positions.setter(content_id).set(U256::ZERO);
            }

            let mut record = vault.contents.setter(content_id);
            record.tx_commitment.set(B256::ZERO);
            record.access_policy_hash.set(B256::ZERO);
            record.packed.set(U256::ZERO);

            let mut grantees: Vec<Address> = Vec::new();
            {
                let index = vault.access.grantee_index.getter(content_id);
                let total = index.len();
                for i in 0..total {
                    if let Some(addr_guard) = index.getter(i) {
                        grantees.push(addr_guard.get());
                    }
                }
            }

            for addr in grantees {
                vault.access.permissions.setter(content_id).setter(addr).set(false);
                vault.access.grantee_positions.setter(content_id).setter(addr).set(U256::ZERO);
            }

            // SAFETY: StorageAddress tolerates zero-slots; set_len(0) is safe.
            let mut index = vault.access.grantee_index.setter(content_id);
            unsafe { index.set_len(0); }
        }

        self.vm().log(ContentDeleted {
            user: sender,
            contentHash: content_id,
        });

        Ok(())
    }

    // ========================================================================
    // ACCESS CONTROL
    // ========================================================================

    pub fn grant_access(
        &mut self,
        content_id: B256,
        grantee: Address,
    ) -> Result<(), Vec<u8>> {
        self.require_not_paused()?;
        if grantee == Address::ZERO {
            return Err(ZeroGrantee {}.abi_encode());
        }

        let sender = self.vm().msg_sender();

        {
            let mut vault = self.vaults.setter(sender);

            if vault.contents.getter(content_id).tx_commitment.get() == B256::ZERO {
                return Err(NotFound {}.abi_encode());
            }

            let mut content_map = vault.access.permissions.setter(content_id);
            let mut permission_slot = content_map.setter(grantee);

            if permission_slot.get() {
                return Ok(());
            }
            permission_slot.set(true);

            let existing_pos = vault.access.grantee_positions.getter(content_id).getter(grantee).get();
            if existing_pos == U256::ZERO {
                let mut index = vault.access.grantee_index.setter(content_id);
                let new_pos = index.len() as u64;
                index.grow().set(grantee);
                vault.access.grantee_positions
                    .setter(content_id)
                    .setter(grantee)
                    .set(U256::from(new_pos + 1));
            }
        }

        self.vm().log(AccessGranted {
            owner: sender,
            grantee,
            contentHash: content_id,
        });

        Ok(())
    }

    pub fn revoke_access(
        &mut self,
        content_id: B256,
        grantee: Address,
    ) -> Result<(), Vec<u8>> {
        self.require_not_paused()?;
        if grantee == Address::ZERO {
            return Err(ZeroGrantee {}.abi_encode());
        }

        let sender = self.vm().msg_sender();

        {
            let mut vault = self.vaults.setter(sender);

            let pos = vault.access.grantee_positions.getter(content_id).getter(grantee).get();
            if pos == U256::ZERO {
                return Ok(());
            }

            {
                let mut content_map = vault.access.permissions.setter(content_id);
                let mut permission_slot = content_map.setter(grantee);
                if !permission_slot.get() {
                    return Ok(());
                }
                permission_slot.set(false);
            }

            let idx = (pos.as_limbs()[0] - 1) as usize;

            let last_addr: Option<Address>;
            let last_idx: usize;
            {
                let index = vault.access.grantee_index.getter(content_id);
                last_idx = index.len() - 1;
                if idx != last_idx {
                    last_addr = index.getter(last_idx).map(|g| g.get());
                } else {
                    last_addr = None;
                }
            }

            {
                let mut index = vault.access.grantee_index.setter(content_id);
                if let Some(addr) = last_addr {
                    index.setter(idx).unwrap().set(addr);
                }
                index.pop();
            }

            if let Some(addr) = last_addr {
                vault.access.grantee_positions
                    .setter(content_id)
                    .setter(addr)
                    .set(U256::from(idx as u64 + 1));
            }
            vault.access.grantee_positions
                .setter(content_id)
                .setter(grantee)
                .set(U256::ZERO);
        }

        self.vm().log(AccessRevoked {
            owner: sender,
            grantee,
            contentHash: content_id,
        });

        Ok(())
    }

    // ========================================================================
    // VIEWS
    // ========================================================================

    pub fn get_global_stats(&self) -> (U256, U256) {
        (self.global_registrations.get(), self.global_queries.get())
    }

    pub fn is_paused(&self) -> bool {
        self.paused.get()
    }

    pub fn get_pause_reason(&self) -> B256 {
        self.pause_reason_hash.get()
    }

    pub fn get_providers(&self) -> (Address, Address, Address, Address) {
        (
            self.storage_provider.get(),
            self.query_provider.get(),
            self.access_provider.get(),
            self.zk_verifier.get(),
        )
    }

    pub fn has_access(
        &self,
        owner: Address,
        content_id: B256,
        grantee: Address,
    ) -> bool {
        self.vaults.getter(owner)
            .access.permissions
            .getter(content_id)
            .getter(grantee)
            .get()
    }

    pub fn get_commitment(
        &self,
        owner: Address,
        content_id: B256,
    ) -> Result<B256, Vec<u8>> {
        let vault = self.vaults.getter(owner);
        let record = vault.contents.getter(content_id);
        let commitment = record.tx_commitment.get();
        if commitment == B256::ZERO {
            return Err(NotFound {}.abi_encode());
        }
        Ok(commitment)
    }

    pub fn get_metadata(
        &self,
        owner: Address,
        content_id: B256,
    ) -> Result<(u64, u64, u64, u8, bool, u8, u32, u64), Vec<u8>> {
        let vault = self.vaults.getter(owner);
        let record = vault.contents.getter(content_id);
        let packed = record.packed.get();
        if packed == U256::ZERO {
            return Err(NotFound {}.abi_encode());
        }
        let (version, created_at, updated_at, provider_id, is_public, storage_term, expiry_delta) =
            unpack_metadata(packed);
        let absolute_expiry = compute_absolute_expiry(created_at, expiry_delta);
        Ok((version, created_at, updated_at, provider_id, is_public, storage_term, expiry_delta, absolute_expiry))
    }

    pub fn is_public(
        &self,
        owner: Address,
        content_id: B256,
    ) -> Result<bool, Vec<u8>> {
        let vault = self.vaults.getter(owner);
        let record = vault.contents.getter(content_id);
        let packed = record.packed.get();
        if packed == U256::ZERO {
            return Err(NotFound {}.abi_encode());
        }
        Ok(read_is_public(packed))
    }

    pub fn get_storage_info(
        &self,
        owner: Address,
        content_id: B256,
    ) -> Result<(u8, u32, u64), Vec<u8>> {
        let vault = self.vaults.getter(owner);
        let record = vault.contents.getter(content_id);
        let packed = record.packed.get();
        if packed == U256::ZERO {
            return Err(NotFound {}.abi_encode());
        }
        let created_at = read_created_at(packed);
        let term = read_storage_term(packed);
        let delta = read_expiry_delta(packed);
        let absolute_expiry = compute_absolute_expiry(created_at, delta);
        Ok((term, delta, absolute_expiry))
    }

    /// @notice Returns whether the content is expired, and the remaining
    ///         seconds until expiry.
    ///
    /// @dev O(1) helper for frontends. `is_expired` is `false` for
    ///      permanent content. `seconds_remaining` is `0` for permanent
    ///      content or already-expired content.
    pub fn get_expiry_status(
        &self,
        owner: Address,
        content_id: B256,
    ) -> Result<(bool, u64), Vec<u8>> {
        let vault = self.vaults.getter(owner);
        let record = vault.contents.getter(content_id);
        let packed = record.packed.get();
        if packed == U256::ZERO {
            return Err(NotFound {}.abi_encode());
        }
        let created_at = read_created_at(packed);
        let delta = read_expiry_delta(packed);
        if delta == 0 {
            return Ok((false, 0)); // permanent
        }
        let absolute = created_at.saturating_add(delta as u64);
        let now = self.vm().block_timestamp();
        if now >= absolute {
            Ok((true, 0))
        } else {
            Ok((false, absolute - now))
        }
    }

    pub fn get_access_policy_hash(
        &self,
        owner: Address,
        content_id: B256,
    ) -> Result<B256, Vec<u8>> {
        let vault = self.vaults.getter(owner);
        let record = vault.contents.getter(content_id);
        let hash = record.access_policy_hash.get();
        if hash == B256::ZERO {
            return Err(NotFound {}.abi_encode());
        }
        Ok(hash)
    }

    pub fn get_content_list(
        &self,
        owner: Address,
        offset: u32,
        limit: u32,
    ) -> Vec<B256> {
        let vault = self.vaults.getter(owner);
        let list = &vault.content_list;

        let total = list.len() as u32;
        let mut result = Vec::new();

        let start = core::cmp::min(offset, total);
        let end = core::cmp::min(start.saturating_add(limit), total);

        for i in start..end {
            if let Some(item_guard) = list.getter(i as usize) {
                result.push(item_guard.get());
            }
        }
        result
    }

    pub fn get_shared_paginated(
        &self,
        owner: Address,
        content_id: B256,
        offset: u32,
        limit: u32,
    ) -> Vec<Address> {
        let vault = self.vaults.getter(owner);
        let index = vault.access.grantee_index.getter(content_id);

        let total = index.len() as u32;
        let mut result = Vec::new();

        let start = core::cmp::min(offset, total);
        let end = core::cmp::min(start.saturating_add(limit), total);

        for i in start..end {
            if let Some(addr_guard) = index.getter(i as usize) {
                let addr = addr_guard.get();
                if vault.access.permissions.getter(content_id).getter(addr).get() {
                    result.push(addr);
                }
            }
        }
        result
    }

    // ========================================================================
    // INTEGRITY PROOF
    // ========================================================================

    pub fn verify_content_ownership(
        &self,
        owner: Address,
        content_id: B256,
        tx_id: Bytes,
        salt: Bytes,
    ) -> Result<bool, Vec<u8>> {
        let vault = self.vaults.getter(owner);
        let record = vault.contents.getter(content_id);
        let stored = record.tx_commitment.get();

        if stored == B256::ZERO {
            return Err(NotFound {}.abi_encode());
        }

        let mut preimage = Vec::with_capacity(tx_id.len() + salt.len());
        preimage.extend_from_slice(&tx_id);
        preimage.extend_from_slice(&salt);

        let computed = keccak(&preimage);

        Ok(computed == stored)
    }

    // ========================================================================
    // QUERY REQUEST (NON-ZK PATH)
    // ========================================================================

    pub fn request_query(
        &mut self,
        query_id: B256,
        content_hash: B256,
        query_plan_hash: B256,
    ) -> Result<(), Vec<u8>> {
        self.require_not_paused()?;

        let sender = self.vm().msg_sender();

        {
            let vault = self.vaults.getter(sender);
            let record = vault.contents.getter(content_hash);
            if record.tx_commitment.get() == B256::ZERO {
                return Err(NotFound {}.abi_encode());
            }
        }

        let active_count = self.active_query_counts.getter(sender).get();
        if active_count >= U256::from(MAX_ACTIVE_QUERIES) {
            return Err(QueryLimitExceeded {}.abi_encode());
        }

        let existing_requester = self.query_requesters.getter(query_id).get();
        if existing_requester != Address::ZERO && existing_requester != sender {
            return Err(QueryIdClaimedByOther {}.abi_encode());
        }
        if self.pending_queries.getter(query_id).get() {
            return Err(QueryAlreadyPending {}.abi_encode());
        }

        let now = U256::from(self.vm().block_timestamp());

        self.pending_queries.setter(query_id).set(true);
        self.query_timestamps.setter(query_id).set(now);
        self.query_requesters.setter(query_id).set(sender);
        self.query_content_hashes.setter(query_id).set(content_hash);
        self.active_query_counts.setter(sender).set(active_count + U256::from(1));

        let current_queries = self.global_queries.get();
        self.global_queries.set(current_queries + U256::from(1));

        self.vm().log(QueryRequested {
            queryId: query_id,
            requester: sender,
            contentHash: content_hash,
            queryPlanHash: query_plan_hash,
        });

        Ok(())
    }

    pub fn cancel_stale_query(&mut self, query_id: B256) -> Result<(), Vec<u8>> {
        let ts = self.query_timestamps.getter(query_id).get();
        if ts == U256::ZERO {
            return Err(QueryNotPending {}.abi_encode());
        }

        let requester = self.query_requesters.getter(query_id).get();
        let sender = self.vm().msg_sender();
        if sender != requester && sender != self.owner.get() {
            return Err(Unauthorized {}.abi_encode());
        }

        let now = U256::from(self.vm().block_timestamp());
        let deadline = ts.saturating_add(U256::from(QUERY_TIMEOUT_SECONDS));
        if now < deadline {
            return Err(QueryNotStale {}.abi_encode());
        }

        self.pending_queries.setter(query_id).set(false);
        self.query_timestamps.setter(query_id).set(U256::ZERO);
        self.query_requesters.setter(query_id).set(Address::ZERO);
        self.query_content_hashes.setter(query_id).set(B256::ZERO);

        if requester != Address::ZERO {
            let count = self.active_query_counts.getter(requester).get();
            let new_count = count.saturating_sub(U256::from(1));
            self.active_query_counts.setter(requester).set(new_count);
        }

        self.vm().log(QueryCancelled { queryId: query_id, requester });

        Ok(())
    }

    // ========================================================================
    // QUERY REQUEST (ZK PATH — OPTIONAL)
    // ========================================================================

    pub fn request_query_zk(
        &mut self,
        query_id: B256,
        content_hash: B256,
        query_plan_hash: B256,
        proof: Bytes,
        public_inputs: Vec<B256>,
    ) -> Result<(), Vec<u8>> {
        self.require_not_paused()?;

        let sender = self.vm().msg_sender();

        // --- CHECKS (local, no external calls) ---
        if proof.is_empty() {
            return Err(EmptyProof {}.abi_encode());
        }

        {
            let vault = self.vaults.getter(sender);
            let record = vault.contents.getter(content_hash);
            if record.tx_commitment.get() == B256::ZERO {
                return Err(NotFound {}.abi_encode());
            }
        }

        let active_count = self.active_query_counts.getter(sender).get();
        if active_count >= U256::from(MAX_ACTIVE_QUERIES) {
            return Err(QueryLimitExceeded {}.abi_encode());
        }

        let existing_requester = self.query_requesters.getter(query_id).get();
        if existing_requester != Address::ZERO && existing_requester != sender {
            return Err(QueryIdClaimedByOther {}.abi_encode());
        }
        if self.pending_queries.getter(query_id).get() {
            return Err(QueryAlreadyPending {}.abi_encode());
        }

        // --- INTERACTIONS (cross-contract call) ---
        let zk_addr = self.zk_verifier.get();
        if zk_addr == Address::ZERO {
            return Err(ZkVerifierNotSet {}.abi_encode());
        }

        let zk = IZKVerifier::new(zk_addr);
        let call = Call::new();
        let ok = zk
            .verify(self.vm(), call, proof, public_inputs)
            .map_err(|_| ZkVerificationFailed {}.abi_encode())?;

        if !ok {
            return Err(ZkVerificationFailed {}.abi_encode());
        }

        // --- EFFECTS ---
        let now = U256::from(self.vm().block_timestamp());

        self.pending_queries.setter(query_id).set(true);
        self.query_timestamps.setter(query_id).set(now);
        self.query_requesters.setter(query_id).set(sender);
        self.query_content_hashes.setter(query_id).set(content_hash);
        self.active_query_counts.setter(sender).set(active_count + U256::from(1));

        let current_queries = self.global_queries.get();
        self.global_queries.set(current_queries + U256::from(1));

        // --- INTERACTIONS (log) ---
        self.vm().log(QueryRequested {
            queryId: query_id,
            requester: sender,
            contentHash: content_hash,
            queryPlanHash: query_plan_hash,
        });

        Ok(())
    }

    // ========================================================================
    // CRE CALLBACK
    // ========================================================================

    pub fn on_report(
        &mut self,
        metadata: Bytes,
        report: Bytes,
    ) -> Result<(), Vec<u8>> {
        let caller = self.vm().msg_sender();
        if caller != self.query_provider.get() {
            return Err(UnauthorizedForwarder {}.abi_encode());
        }

        if metadata.len() < 64 {
            return Err(InvalidMetadata {}.abi_encode());
        }

        let workflow_id = B256::from_slice(&metadata[0..32]);
        if workflow_id != self.expected_workflow_id.get() {
            return Err(UnauthorizedWorkflow {}.abi_encode());
        }

        let report_id = FixedBytes::<2>::from_slice(&metadata[62..64]);

        let (query_id, content_hash, result) = decode_cre_report(&report)?;

        if !self.pending_queries.getter(query_id).get() {
            return Err(QueryNotPending {}.abi_encode());
        }

        let expected_content_hash = self.query_content_hashes.getter(query_id).get();
        if content_hash != expected_content_hash {
            return Err(ContentHashMismatch {}.abi_encode());
        }

        let requester = self.query_requesters.getter(query_id).get();

        self.pending_queries.setter(query_id).set(false);
        self.query_timestamps.setter(query_id).set(U256::ZERO);
        self.query_requesters.setter(query_id).set(Address::ZERO);
        self.query_content_hashes.setter(query_id).set(B256::ZERO);

        if requester != Address::ZERO {
            let count = self.active_query_counts.getter(requester).get();
            let new_count = count.saturating_sub(U256::from(1));
            self.active_query_counts.setter(requester).set(new_count);
        }

        let result_hash = keccak(&result);
        self.vm().log(QueryResultReceived {
            queryId: query_id,
            contentHash: content_hash,
            resultHash: B256::from_slice(result_hash.as_slice()),
            reportId: report_id,
        });

        Ok(())
    }
}

// ============================================================================
// INTERNAL HELPERS
// ============================================================================

impl KipioContentAccess {
    fn require_owner(&self) -> Result<(), Vec<u8>> {
        if self.vm().msg_sender() != self.owner.get() {
            return Err(Unauthorized {}.abi_encode());
        }
        Ok(())
    }

    fn require_not_paused(&self) -> Result<(), Vec<u8>> {
        if self.paused.get() {
            return Err(EnforcedPause {}.abi_encode());
        }
        Ok(())
    }
}

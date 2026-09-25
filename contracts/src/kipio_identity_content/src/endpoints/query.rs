//! Query lifecycle and CRE callback dispatch handlers.
//!
//! Two paths: the non-ZK path (`request_query`) that registers a
//! pending query and relies on the query provider to fulfil it via
//! `on_report`, and the ZK path (`request_query_zk`) that verifies
//! a zero-knowledge proof inline before registration. The stale
//! cancellation path (`cancel_stale_query`) refunds the active-query
//! slot after the timeout elapses.

use super::*;

impl KipioIdentityContent {
    // --------------------------------------------------------------------
    // QUERY REQUEST (NON-ZK PATH)
    // --------------------------------------------------------------------

    #[inline(never)]
    pub(crate) fn dispatch_request_query(&mut self, args: &[u8]) -> ArbResult {
        let call = requestQueryCall::abi_decode(args).map_err(|_| Vec::new())?;

        self.require_not_paused()?;

        let sender = self.vm().msg_sender();

        {
            let vault = self.vaults.getter(sender);
            let record = vault.contents.getter(call.content_hash);
            if record.tx_commitment.get() == B256::ZERO {
                return Err(NotFound {}.abi_encode());
            }
        }

        let active_count = self.active_query_counts.getter(sender).get();
        if active_count >= U256::from(MAX_ACTIVE_QUERIES) {
            return Err(QueryLimitExceeded {}.abi_encode());
        }

        let existing_requester = self.query_requesters.getter(call.query_id).get();
        if existing_requester != Address::ZERO && existing_requester != sender {
            return Err(QueryIdClaimedByOther {}.abi_encode());
        }
        if self.pending_queries.getter(call.query_id).get() {
            return Err(QueryAlreadyPending {}.abi_encode());
        }

        let now = U256::from(self.vm().block_timestamp());

        self.pending_queries.setter(call.query_id).set(true);
        self.query_timestamps.setter(call.query_id).set(now);
        self.query_requesters.setter(call.query_id).set(sender);
        self.query_content_hashes.setter(call.query_id).set(call.content_hash);
        self.active_query_counts
            .setter(sender)
            .set(active_count + U256::from(1));

        let current_queries = self.global_queries.get();
        self.global_queries.set(current_queries + U256::from(1));

        self.vm().log(QueryRequested {
            queryId: call.query_id,
            requester: sender,
            contentHash: call.content_hash,
            queryPlanHash: call.query_plan_hash,
        });

        Ok(Vec::new())
    }

    #[inline(never)]
    pub(crate) fn dispatch_cancel_stale_query(&mut self, args: &[u8]) -> ArbResult {
        let call = cancelStaleQueryCall::abi_decode(args).map_err(|_| Vec::new())?;

        let ts = self.query_timestamps.getter(call.query_id).get();
        if ts == U256::ZERO {
            return Err(QueryNotPending {}.abi_encode());
        }

        let requester = self.query_requesters.getter(call.query_id).get();
        let sender = self.vm().msg_sender();
        if sender != requester && sender != self.owner.get() {
            return Err(Unauthorized {}.abi_encode());
        }

        let now = U256::from(self.vm().block_timestamp());
        let deadline = ts.saturating_add(U256::from(QUERY_TIMEOUT_SECONDS));
        if now < deadline {
            return Err(QueryNotStale {}.abi_encode());
        }

        self.pending_queries.setter(call.query_id).set(false);
        self.query_timestamps.setter(call.query_id).set(U256::ZERO);
        self.query_requesters.setter(call.query_id).set(Address::ZERO);
        self.query_content_hashes.setter(call.query_id).set(B256::ZERO);

        if requester != Address::ZERO {
            let count = self.active_query_counts.getter(requester).get();
            let new_count = count.saturating_sub(U256::from(1));
            self.active_query_counts.setter(requester).set(new_count);
        }

        self.vm().log(QueryCancelled { queryId: call.query_id, requester });

        Ok(Vec::new())
    }

    // --------------------------------------------------------------------
    // QUERY REQUEST (ZK PATH)
    // --------------------------------------------------------------------

    #[inline(never)]
    pub(crate) fn dispatch_request_query_zk(&mut self, args: &[u8]) -> ArbResult {
        let call = decode_request_query_zk(args)?;

        self.require_not_paused()?;

        let sender = self.vm().msg_sender();

        if call.proof.is_empty() {
            return Err(EmptyProof {}.abi_encode());
        }

        {
            let vault = self.vaults.getter(sender);
            let record = vault.contents.getter(call.content_hash);
            if record.tx_commitment.get() == B256::ZERO {
                return Err(NotFound {}.abi_encode());
            }
        }

        let active_count = self.active_query_counts.getter(sender).get();
        if active_count >= U256::from(MAX_ACTIVE_QUERIES) {
            return Err(QueryLimitExceeded {}.abi_encode());
        }

        let existing_requester = self.query_requesters.getter(call.query_id).get();
        if existing_requester != Address::ZERO && existing_requester != sender {
            return Err(QueryIdClaimedByOther {}.abi_encode());
        }
        if self.pending_queries.getter(call.query_id).get() {
            return Err(QueryAlreadyPending {}.abi_encode());
        }

        let zk_addr = self.zk_verifier.get();
        if zk_addr == Address::ZERO {
            return Err(ZkVerifierNotSet {}.abi_encode());
        }

        let zk = IZKVerifier::new(zk_addr);
        let call_ctx = Call::new();
        let ok = zk
            .verify(self.vm(), call_ctx, call.proof, call.public_inputs)
            .map_err(|_| ZkVerificationFailed {}.abi_encode())?;

        if !ok {
            return Err(ZkVerificationFailed {}.abi_encode());
        }

        let now = U256::from(self.vm().block_timestamp());

        self.pending_queries.setter(call.query_id).set(true);
        self.query_timestamps.setter(call.query_id).set(now);
        self.query_requesters.setter(call.query_id).set(sender);
        self.query_content_hashes.setter(call.query_id).set(call.content_hash);
        self.active_query_counts
            .setter(sender)
            .set(active_count + U256::from(1));

        let current_queries = self.global_queries.get();
        self.global_queries.set(current_queries + U256::from(1));

        self.vm().log(QueryRequested {
            queryId: call.query_id,
            requester: sender,
            contentHash: call.content_hash,
            queryPlanHash: call.query_plan_hash,
        });

        Ok(Vec::new())
    }

    // --------------------------------------------------------------------
    // CRE CALLBACK
    // --------------------------------------------------------------------

    #[inline(never)]
    pub(crate) fn dispatch_on_report(&mut self, args: &[u8]) -> ArbResult {
        let call = decode_on_report(args)?;

        let caller = self.vm().msg_sender();
        if caller != self.query_provider.get() {
            return Err(UnauthorizedForwarder {}.abi_encode());
        }

        if call.metadata.len() < 64 {
            return Err(InvalidMetadata {}.abi_encode());
        }

        let workflow_id = B256::from_slice(&call.metadata[0..32]);
        if workflow_id != self.expected_workflow_id.get() {
            return Err(UnauthorizedWorkflow {}.abi_encode());
        }

        let report_id = FixedBytes::<2>::from_slice(&call.metadata[62..64]);

        let (query_id, content_hash, result) = decode_cre_report(&call.report)?;

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

        Ok(Vec::new())
    }
}

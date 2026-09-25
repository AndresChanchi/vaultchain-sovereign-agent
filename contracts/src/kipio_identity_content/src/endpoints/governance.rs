//! Governance and circuit breaker dispatch handlers.
//!
//! Two-phase ownership transfer, provider address updates, workflow ID
//! configuration, and the pause/unpause circuit breaker. All handlers
//! are gated by `require_owner()` except the state mutators, which are
//! idempotent no-ops on repeated calls.

use super::*;

impl KipioIdentityContent {
    // --------------------------------------------------------------------
    // GOVERNANCE
    // --------------------------------------------------------------------

    #[inline(never)]
    pub(crate) fn dispatch_transfer_ownership(&mut self, args: &[u8]) -> ArbResult {
        let call = transferOwnershipCall::abi_decode(args).map_err(|_| Vec::new())?;

        self.require_owner()?;
        if call.new_owner == Address::ZERO {
            return Err(ZeroOwner {}.abi_encode());
        }
        let current = self.owner.get();
        self.pending_owner.set(call.new_owner);
        self.vm().log(OwnershipTransferStarted {
            previousOwner: current,
            newOwner: call.new_owner,
        });
        Ok(Vec::new())
    }

    #[inline(never)]
    pub(crate) fn dispatch_accept_ownership(&mut self, _args: &[u8]) -> ArbResult {
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
        Ok(Vec::new())
    }

    #[inline(never)]
    pub(crate) fn dispatch_set_storage_provider(&mut self, args: &[u8]) -> ArbResult {
        let call = setStorageProviderCall::abi_decode(args).map_err(|_| Vec::new())?;

        self.require_owner()?;
        if call.provider == Address::ZERO {
            return Err(ZeroAddress {}.abi_encode());
        }
        let old = self.storage_provider.get();
        self.storage_provider.set(call.provider);
        self.vm().log(ProviderUpdated {
            providerType: 0,
            oldProvider: old,
            newProvider: call.provider,
        });
        Ok(Vec::new())
    }

    #[inline(never)]
    pub(crate) fn dispatch_set_query_provider(&mut self, args: &[u8]) -> ArbResult {
        let call = setQueryProviderCall::abi_decode(args).map_err(|_| Vec::new())?;

        self.require_owner()?;
        if call.provider == Address::ZERO {
            return Err(ZeroAddress {}.abi_encode());
        }
        let old = self.query_provider.get();
        self.query_provider.set(call.provider);
        self.vm().log(ProviderUpdated {
            providerType: 1,
            oldProvider: old,
            newProvider: call.provider,
        });
        Ok(Vec::new())
    }

    #[inline(never)]
    pub(crate) fn dispatch_set_access_provider(&mut self, args: &[u8]) -> ArbResult {
        let call = setAccessProviderCall::abi_decode(args).map_err(|_| Vec::new())?;

        self.require_owner()?;
        if call.provider == Address::ZERO {
            return Err(ZeroAddress {}.abi_encode());
        }
        let old = self.access_provider.get();
        self.access_provider.set(call.provider);
        self.vm().log(ProviderUpdated {
            providerType: 2,
            oldProvider: old,
            newProvider: call.provider,
        });
        Ok(Vec::new())
    }

    #[inline(never)]
    pub(crate) fn dispatch_set_zk_verifier(&mut self, args: &[u8]) -> ArbResult {
        let call = setZkVerifierCall::abi_decode(args).map_err(|_| Vec::new())?;

        self.require_owner()?;
        let old = self.zk_verifier.get();
        self.zk_verifier.set(call.verifier);
        self.vm().log(ZkVerifierUpdated {
            oldVerifier: old,
            newVerifier: call.verifier,
        });
        Ok(Vec::new())
    }

    #[inline(never)]
    pub(crate) fn dispatch_set_expected_workflow_id(&mut self, args: &[u8]) -> ArbResult {
        let call = setExpectedWorkflowIdCall::abi_decode(args).map_err(|_| Vec::new())?;

        self.require_owner()?;
        let old = self.expected_workflow_id.get();
        self.expected_workflow_id.set(call.workflow_id);
        self.vm().log(WorkflowIdUpdated {
            oldWorkflowId: old,
            newWorkflowId: call.workflow_id,
        });
        Ok(Vec::new())
    }

    // --------------------------------------------------------------------
    // CIRCUIT BREAKER
    // --------------------------------------------------------------------

    #[inline(never)]
    pub(crate) fn dispatch_pause(&mut self, args: &[u8]) -> ArbResult {
        let call = pauseCall::abi_decode(args).map_err(|_| Vec::new())?;

        self.require_owner()?;
        if self.paused.get() {
            return Ok(Vec::new());
        }
        self.paused.set(true);
        self.pause_reason_hash.set(call.reason_hash);
        self.vm().log(Paused { by: self.vm().msg_sender(), reasonHash: call.reason_hash });
        Ok(Vec::new())
    }

    #[inline(never)]
    pub(crate) fn dispatch_unpause(&mut self, _args: &[u8]) -> ArbResult {
        self.require_owner()?;
        if !self.paused.get() {
            return Ok(Vec::new());
        }
        self.paused.set(false);
        self.pause_reason_hash.set(B256::ZERO);
        self.vm().log(Unpaused { by: self.vm().msg_sender() });
        Ok(Vec::new())
    }
}

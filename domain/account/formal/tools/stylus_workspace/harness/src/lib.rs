#![cfg_attr(not(any(test, feature = "export-abi")), no_main)]
extern crate alloc;

pub mod dafny_bridge;

use dafny_bridge::{
    AccountAbi, AuthorizationAbi, AuthorizationStateAbi, CapabilityAbi, CredentialAbi,
    DelegationAbi, ExecutionContextAbi, IdentityAbi, OptionalScopeAbi,
    PolicyConsumptionAbi, RestrictionAbi, SessionAbi,
};
use stylus_sdk::abi::Bytes;
use stylus_sdk::alloy_primitives::U256;
use stylus_sdk::prelude::*;

pub use kipio_account_generated;

#[storage]
#[entrypoint]
pub struct KipioAccountHarness {}

#[public]
impl KipioAccountHarness {
    /// Sanity check.
    pub fn ping(&self) -> bool {
        true
    }

    // ---- Validators -------------------------------------------------------

    /// Full-account validity check (Dafny's ValidAccount).
    pub fn valid_account(&self, account: AccountAbi) -> bool {
        dafny_bridge::valid_account_impl(&account)
    }

    /// Full-state validity check (Dafny's ValidAuthorizationState).
    pub fn valid_authorization_state(&self, state: AuthorizationStateAbi) -> bool {
        dafny_bridge::valid_authorization_state_impl(&state)
    }

    /// Structural validity of an Authorization.
    pub fn authorization_is_structurally_valid(&self, auth: AuthorizationAbi) -> bool {
        dafny_bridge::authorization_is_structurally_valid_impl(&auth)
    }

    // ---- Composed entrypoints --------------------------------------------

    /// The crown jewel: full authorization acceptance with provenance.
    ///
    /// The witness (effectiveAuthority + sourceReferences + sourceAuthorities
    /// + contributions) is constructed internally by the Dafny inject and
    /// never crosses the ABI.
    pub fn authorization_can_be_accepted_full(
        &self,
        auth: AuthorizationAbi,
        account: AccountAbi,
        identities: Vec<IdentityAbi>,
        now: U256,
        proof_verified: bool,
    ) -> bool {
        dafny_bridge::authorization_can_be_accepted_full_impl(
            &auth,
            &account,
            &identities,
            now,
            proof_verified,
        )
    }

    /// Applies a full PolicyConsumption to an Account.
    ///
    /// Returns (new_account, applied):
    ///   - applied = true  → the policy was applicable and consistent,
    ///                       and new_account reflects its effects.
    ///   - applied = false → the policy was rejected atomically per
    ///                       D2.5.1, and new_account == the input.
    pub fn apply_policy_consumption(
        &self,
        account: AccountAbi,
        consumption: PolicyConsumptionAbi,
    ) -> (AccountAbi, bool) {
        dafny_bridge::apply_policy_consumption_impl(&account, &consumption)
    }

    /// Computes the canonical EffectiveAuthority for an Account at a
    /// given evaluation time.
    ///
    /// This exposes Dafny's ComputeEffectiveAuthorityWitness, which
    /// applies the D1.30 derivation over the Account's current
    /// AuthorizationState. The returned set is the EffectiveAuthority
    /// value; the provenance witness (sourceReferences,
    /// sourceAuthorities, contributions) remains internal to Dafny.
    ///
    /// Use this when you need to build an ExecutionContextAbi: pass the
    /// returned set as `effectiveAuthority` to guarantee that
    /// `valid_execution_context` accepts the context with respect to
    /// the EffectiveAuthority field.
    pub fn compute_effective_authority(
        &self,
        account: AccountAbi,
        identities: Vec<IdentityAbi>,
        now: U256,
    ) -> Vec<CapabilityAbi> {
        dafny_bridge::compute_effective_authority_impl(&account, &identities, now)
    }

    /// The Execution boundary: validates a complete ExecutionContext
    /// against a specific Account.
    ///
    /// A valid ExecutionContext represents a complete validated
    /// execution decision for the Account. It is not merely a
    /// structurally coherent value.
    ///
    /// Dafny's ValidExecutionContextForAccountFull performs:
    ///   - structural validity of the context value;
    ///   - association between the context's AuthorizationState
    ///     snapshot and the Account's current state;
    ///   - ValidAccount(account);
    ///   - identity context validity;
    ///   - full authorization acceptance (the EffectiveAuthority
    ///     provenance witness is constructed internally by
    ///     AuthorizationCanBeAcceptedFull);
    ///   - equality between the context's EffectiveAuthority and the
    ///     canonical derivation computed from the Account's current
    ///     state.
    ///
    /// Environment compatibility is intentionally NOT part of this
    /// intrinsic validity. Per D6, an ExecutionContext may be
    /// intrinsically valid while being incompatible with a particular
    /// selected ExecutionEnvironment; that gate belongs to the
    /// execution boundary.
    pub fn valid_execution_context(
        &self,
        context: ExecutionContextAbi,
        account: AccountAbi,
        identities: Vec<IdentityAbi>,
        proof_verified: bool,
    ) -> bool {
        dafny_bridge::valid_execution_context_impl(
            &context,
            &account,
            &identities,
            proof_verified,
        )
    }

    // ---- Provisioning transitions ----------------------------------------
    //
    // Every method below returns (AccountAbi, bool). The boolean
    // communicates whether the transition applied (true) or was
    // rejected because its preconditions did not hold (false).
    //
    // When applied == false, the returned AccountAbi is equal to the
    // input AccountAbi — the transition is atomic.

    /// Registers a new Credential in an Account's AuthorizationState.
    pub fn register_credential(
        &self,
        account: AccountAbi,
        credential: CredentialAbi,
    ) -> (AccountAbi, bool) {
        dafny_bridge::register_credential_impl(&account, &credential)
    }

    /// Registers a new Session bound to an already-recognized Credential.
    pub fn register_session(
        &self,
        account: AccountAbi,
        session: SessionAbi,
    ) -> (AccountAbi, bool) {
        dafny_bridge::register_session_impl(&account, &session)
    }

    /// Registers a root Delegation from an Account's sovereign Identity.
    pub fn register_delegation(
        &self,
        account: AccountAbi,
        delegation: DelegationAbi,
        delegate_capability: CapabilityAbi,
        delegatable_authority: Vec<CapabilityAbi>,
        source_effective_authority: Vec<CapabilityAbi>,
    ) -> (AccountAbi, bool) {
        dafny_bridge::register_delegation_impl(
            &account,
            &delegation,
            &delegate_capability,
            &delegatable_authority,
            &source_effective_authority,
        )
    }

    /// Registers a transitive (child) Delegation. Requires at least one
    /// recognized parent Delegation providing authority to the child source.
    pub fn register_transitive_delegation(
        &self,
        account: AccountAbi,
        delegation: DelegationAbi,
        delegate_capability: CapabilityAbi,
        delegatable_authority: Vec<CapabilityAbi>,
        source_effective_authority: Vec<CapabilityAbi>,
        parent_delegation_ids: Vec<Bytes>,
        identities: Vec<IdentityAbi>,
    ) -> (AccountAbi, bool) {
        dafny_bridge::register_transitive_delegation_impl(
            &account,
            &delegation,
            &delegate_capability,
            &delegatable_authority,
            &source_effective_authority,
            &parent_delegation_ids,
            &identities,
        )
    }

    /// Adds a Capability to an Account's AuthorizationState.
    pub fn add_capability(
        &self,
        account: AccountAbi,
        capability: CapabilityAbi,
    ) -> (AccountAbi, bool) {
        dafny_bridge::add_capability_impl(&account, &capability)
    }

    /// Removes a Capability from an Account's AuthorizationState.
    /// Also removes all restrictions associated with that capability.
    pub fn remove_capability(
        &self,
        account: AccountAbi,
        capability: CapabilityAbi,
    ) -> (AccountAbi, bool) {
        dafny_bridge::remove_capability_impl(&account, &capability)
    }

    /// Associates a Restriction with a (Capability, OptionalScope) target.
    pub fn set_restriction(
        &self,
        account: AccountAbi,
        capability: CapabilityAbi,
        scope: OptionalScopeAbi,
        restriction: RestrictionAbi,
    ) -> (AccountAbi, bool) {
        dafny_bridge::set_restriction_impl(&account, &capability, &scope, &restriction)
    }

    /// Removes the Restriction associated with a (Capability, OptionalScope) target.
    pub fn remove_restriction(
        &self,
        account: AccountAbi,
        capability: CapabilityAbi,
        scope: OptionalScopeAbi,
    ) -> (AccountAbi, bool) {
        dafny_bridge::remove_restriction_impl(&account, &capability, &scope)
    }

    /// Sets the Credential Authority associated with a recognized Credential.
    ///
    /// Rejected unless:
    ///   - Account is valid;
    ///   - authority is a valid CredentialAuthority;
    ///   - credential is recognized;
    ///   - every existing Session bound to this Credential remains within
    ///     the new authority (ExistingSessionsRemainWithinCredentialAuthority).
    pub fn set_credential_authority(
        &self,
        account: AccountAbi,
        credential: CredentialAbi,
        authority: Vec<CapabilityAbi>,
    ) -> (AccountAbi, bool) {
        dafny_bridge::set_credential_authority_impl(&account, &credential, &authority)
    }

    /// Marks a ReplayKey as consumed on an Account.
    ///
    /// Rejected if the key is empty (fails ValidId) or already consumed.
    pub fn consume_replay_key(
        &self,
        account: AccountAbi,
        replay_key: Bytes,
    ) -> (AccountAbi, bool) {
        dafny_bridge::consume_replay_key_impl(&account, &replay_key)
    }

    /// Updates the lifecycle status of a recognized Credential.
    ///
    /// Status: 1 = Active, 2 = Suspended, 3 = Revoked.
    /// Rejected if the credential is not recognized or the transition is
    /// not valid (e.g. Revoked → Active).
    pub fn update_credential_status(
        &self,
        account: AccountAbi,
        credential: CredentialAbi,
        new_status: u8,
    ) -> (AccountAbi, bool) {
        dafny_bridge::update_credential_status_impl(&account, &credential, new_status)
    }

    /// Updates the lifecycle status of a recognized Session.
    ///
    /// Status: 1 = Active, 2 = Revoked.
    pub fn update_session_status(
        &self,
        account: AccountAbi,
        session: SessionAbi,
        new_status: u8,
    ) -> (AccountAbi, bool) {
        dafny_bridge::update_session_status_impl(&account, &session, new_status)
    }

    /// Updates the lifecycle status of a recognized Delegation.
    ///
    /// Status: 1 = Active, 2 = Revoked.
    pub fn update_delegation_status(
        &self,
        account: AccountAbi,
        delegation: DelegationAbi,
        new_status: u8,
    ) -> (AccountAbi, bool) {
        dafny_bridge::update_delegation_status_impl(&account, &delegation, new_status)
    }
}

//! ABI ↔ Dafny conversion shared by `kipio_account` and `kipio_runtime`.
//!
//! This crate is NOT a Stylus contract. It exposes:
//!   - the ABI mirror (via `sol!`),
//!   - forward/reverse converters between ABI types and Dafny types,
//!   - the `*_impl` entrypoint implementations consumed by both contracts.
//!
//! Split rationale (DDD):
//!   - `kipio_account`  owns AuthorizationState transitions (§25, §26).
//!   - `kipio_runtime`  owns authorization acceptance, effective-authority
//!                      derivation, policy consumption, and execution-context
//!                      validation (§35).

extern crate alloc;

use alloc::rc::Rc;
use alloc::string::String;
use alloc::vec::Vec;

use dafny_runtime::{
    DafnyChar, DafnyInt, MapBuilder, Sequence, Set, SetBuilder, string_of,
};
use kipio_account_generated::{
    KipioAccountAccount, KipioAccountAccountTransitions, KipioAccountAuthorization,
    KipioAccountAuthorizationAcceptanceWithProvenance,
    KipioAccountAuthorizationState, KipioAccountAuthorizationValidation,
    KipioAccountCapability, KipioAccountChain, KipioAccountCredential,
    KipioAccountCredentialAuthority, KipioAccountDelegation, KipioAccountDomainAction,
    KipioAccountEffectiveAuthorityComposition,
    KipioAccountExecutionContext, KipioAccountExecutionContextComposition,
    KipioAccountExecutionRequest, KipioAccountExecutionTarget, KipioAccountIdentity,
    KipioAccountPolicy, KipioAccountPolicyApplicationComposition,
    KipioAccountPolicyConsumption, KipioAccountPolicyEffect, KipioAccountRestriction,
    KipioAccountScope, KipioAccountSession, KipioAccountSubject,
};
use stylus_sdk::abi::Bytes;
use stylus_sdk::alloy_primitives::U256;
use stylus_sdk::alloy_sol_types::sol;
use stylus_sdk::prelude::*;

// ============================================================================
// ABI MIRROR
// ============================================================================

sol! {
    #[derive(AbiType)]
    struct ScopeAtomAbi { bytes id; }
    #[derive(AbiType)]
    struct ScopeAbi { ScopeAtomAbi[] atoms; }
    #[derive(AbiType)]
    struct CapabilityKindAbi { string name; }
    #[derive(AbiType)]
    struct CapabilityAbi { CapabilityKindAbi kind; ScopeAbi scope; }
    #[derive(AbiType)]
    struct RestrictionKindAbi { string name; }
    #[derive(AbiType)]
    struct RestrictionAbi { RestrictionKindAbi kind; bytes value; }
    #[derive(AbiType)]
    struct SubjectAbi { bytes reference; }
    #[derive(AbiType)]
    struct IdentityAbi { bytes id; SubjectAbi subject; }
    #[derive(AbiType)]
    struct CredentialAbi { bytes id; uint8 status; }
    #[derive(AbiType)]
    struct SessionAbi {
        bytes id;
        bytes credentialId;
        CapabilityAbi[] capabilities;
        uint256 validFrom;
        uint256 validUntil;
        RestrictionAbi[] restrictions;
        uint8 status;
    }
    #[derive(AbiType)]
    struct DelegationAbi {
        bytes id;
        bytes delegatorIdentityId;
        SubjectAbi delegatee;
        CapabilityAbi[] capabilities;
        uint256 validFrom;
        uint256 validUntil;
        RestrictionAbi[] restrictions;
        bytes metadata;
        uint8 status;
    }
    #[derive(AbiType)]
    struct OptionalScopeAbi { bool hasScope; ScopeAbi scope; }
    #[derive(AbiType)]
    struct RestrictionTargetAbi { CapabilityAbi capability; OptionalScopeAbi scope; }
    #[derive(AbiType)]
    struct CredentialAuthorityEntryAbi { bytes credentialId; CapabilityAbi[] authority; }
    #[derive(AbiType)]
    struct DelegationProvenanceEntryAbi { bytes delegationId; bytes[] parents; }
    #[derive(AbiType)]
    struct RestrictionEntryAbi { RestrictionTargetAbi target; RestrictionAbi restriction; }
    #[derive(AbiType)]
    struct PolicyEffectAbi {
        uint8 kind;
        bytes id;
        CapabilityAbi capability;
        OptionalScopeAbi scope;
        RestrictionAbi restriction;
    }
    #[derive(AbiType)]
    struct PolicyAbi { PolicyEffectAbi[] effects; }
    #[derive(AbiType)]
    struct PolicyConsumptionAbi { PolicyAbi policy; }
    #[derive(AbiType)]
    struct AuthorizationStateAbi {
        CapabilityAbi[] capabilities;
        CredentialAbi[] credentials;
        CredentialAuthorityEntryAbi[] credentialAuthorities;
        SessionAbi[] sessions;
        DelegationAbi[] delegations;
        DelegationProvenanceEntryAbi[] delegationProvenance;
        RestrictionEntryAbi[] restrictionMap;
        PolicyEffectAbi[] policyEffects;
        bytes[] consumedReplayKeys;
    }
    #[derive(AbiType)]
    struct AccountAbi { bytes id; IdentityAbi identity; AuthorizationStateAbi authorizationState; }
    #[derive(AbiType)]
    struct AuthorizationAbi {
        bytes credentialId;
        CapabilityAbi[] requestedAuthority;
        RestrictionAbi[] restrictions;
        uint256 validFrom;
        uint256 validUntil;
        bytes replayKey;
        bytes accountId;
        ScopeAbi scope;
    }

    // NOTE ON OMITTED OPAQUE TYPES
    //
    // DomainAction, ExecutionTarget and ExecutionConstraints are unit
    // types in the current domain (foundation/*.dfy and
    // execution/ExecutionConstraints.dfy declare them as abstract types
    // without internal structure). AuthorizationAbi above already omits
    // DomainAction, ExecutionTarget and Chain for the same reason.
    //
    // When any of these gain semantic content (e.g. Chain becomes a
    // chain ID, ExecutionTarget becomes an address), they will be added
    // here as explicit fields. Until then, hardcoding them to their
    // canonical unit values preserves semantic identity across the ABI.

    #[derive(AbiType)]
    struct ExecutionRequestAbi {
        AuthorizationAbi authorization;
    }

    #[derive(AbiType)]
    struct ExecutionContextAbi {
        ExecutionRequestAbi request;
        AuthorizationStateAbi authorizationState;
        CapabilityAbi[] effectiveAuthority;
        uint256 evaluationTime;
    }
}

// ============================================================================
// PRIMITIVES
// ============================================================================

pub fn bytes_to_sequence(bytes: &Bytes) -> Sequence<u8> {
    bytes.iter().copied().collect()
}

pub fn sequence_to_bytes(seq: &Sequence<u8>) -> Bytes {
    let v: Vec<u8> = seq.iter().collect();
    Bytes::from(v)
}

fn u256_to_dafny_int(v: &U256) -> DafnyInt {
    DafnyInt::from(v.to::<u64>())
}

fn dafny_int_to_u256(v: &DafnyInt) -> U256 {
    let n: u64 = u64::from(v.clone());
    U256::from(n)
}

fn dafny_string_to_string(seq: &Sequence<DafnyChar>) -> String {
    let mut out = String::new();
    for c in seq.iter() {
        out.push(c.0);
    }
    out
}

fn string_to_dafny_string(s: &str) -> Sequence<DafnyChar> {
    string_of(s)
}

// ---- empty constructors --------------------------------------------------

pub fn empty_scope_abi() -> ScopeAbi {
    ScopeAbi { atoms: Vec::new() }
}

pub fn empty_capability_kind_abi() -> CapabilityKindAbi {
    CapabilityKindAbi { name: String::new() }
}

pub fn empty_capability_abi() -> CapabilityAbi {
    CapabilityAbi { kind: empty_capability_kind_abi(), scope: empty_scope_abi() }
}

pub fn empty_restriction_kind_abi() -> RestrictionKindAbi {
    RestrictionKindAbi { name: String::new() }
}

pub fn empty_restriction_abi() -> RestrictionAbi {
    RestrictionAbi { kind: empty_restriction_kind_abi(), value: Bytes::new() }
}

pub fn empty_optional_scope_abi() -> OptionalScopeAbi {
    OptionalScopeAbi { hasScope: false, scope: empty_scope_abi() }
}

// ---- status discriminants -------------------------------------------------

fn credential_status_from_u8(x: u8) -> Rc<KipioAccountCredential::CredentialStatus> {
    match x {
        1 => Rc::new(KipioAccountCredential::CredentialStatus::Active {}),
        2 => Rc::new(KipioAccountCredential::CredentialStatus::Suspended {}),
        3 => Rc::new(KipioAccountCredential::CredentialStatus::Revoked {}),
        _ => panic!("invalid CredentialStatus discriminant"),
    }
}

fn credential_status_to_u8(s: &Rc<KipioAccountCredential::CredentialStatus>) -> u8 {
    match s.as_ref() {
        KipioAccountCredential::CredentialStatus::Active {} => 1,
        KipioAccountCredential::CredentialStatus::Suspended {} => 2,
        KipioAccountCredential::CredentialStatus::Revoked {} => 3,
    }
}

fn session_status_from_u8(x: u8) -> Rc<KipioAccountSession::SessionStatus> {
    match x {
        1 => Rc::new(KipioAccountSession::SessionStatus::Active {}),
        2 => Rc::new(KipioAccountSession::SessionStatus::Revoked {}),
        _ => panic!("invalid SessionStatus discriminant"),
    }
}

fn session_status_to_u8(s: &Rc<KipioAccountSession::SessionStatus>) -> u8 {
    match s.as_ref() {
        KipioAccountSession::SessionStatus::Active {} => 1,
        KipioAccountSession::SessionStatus::Revoked {} => 2,
    }
}

fn delegation_status_from_u8(x: u8) -> Rc<KipioAccountDelegation::DelegationStatus> {
    match x {
        1 => Rc::new(KipioAccountDelegation::DelegationStatus::Active {}),
        2 => Rc::new(KipioAccountDelegation::DelegationStatus::Revoked {}),
        _ => panic!("invalid DelegationStatus discriminant"),
    }
}

fn delegation_status_to_u8(s: &Rc<KipioAccountDelegation::DelegationStatus>) -> u8 {
    match s.as_ref() {
        KipioAccountDelegation::DelegationStatus::Active {} => 1,
        KipioAccountDelegation::DelegationStatus::Revoked {} => 2,
    }
}

// ---- opaque unit constructors --------------------------------------------

fn domain_action_unit() -> KipioAccountDomainAction::DomainAction {
    KipioAccountDomainAction::DomainAction
}

fn execution_target_unit() -> KipioAccountExecutionTarget::ExecutionTarget {
    KipioAccountExecutionTarget::ExecutionTarget
}

fn execution_constraints_unit()
    -> kipio_account_generated::KipioAccountExecutionConstraints::ExecutionConstraints
{
    kipio_account_generated::KipioAccountExecutionConstraints::ExecutionConstraints
}

// ============================================================================
// FORWARD CONVERTERS
// ============================================================================

pub fn scope_from_abi(abi: &ScopeAbi) -> Rc<KipioAccountScope::Scope> {
    let mut builder = SetBuilder::<Rc<KipioAccountScope::ScopeAtom>>::new();
    for atom in abi.atoms.iter() {
        builder.add(&Rc::new(KipioAccountScope::ScopeAtom::ScopeAtom {
            id: bytes_to_sequence(&atom.id),
        }));
    }
    Rc::new(KipioAccountScope::Scope::Scope { atoms: builder.build() })
}

pub fn capability_kind_from_abi(abi: &CapabilityKindAbi) -> Rc<KipioAccountCapability::CapabilityKind> {
    Rc::new(KipioAccountCapability::CapabilityKind::CapabilityKind {
        name: string_to_dafny_string(&abi.name),
    })
}

pub fn capability_from_abi(abi: &CapabilityAbi) -> Rc<KipioAccountCapability::Capability> {
    Rc::new(KipioAccountCapability::Capability::Capability {
        kind: capability_kind_from_abi(&abi.kind),
        scope: scope_from_abi(&abi.scope),
    })
}

pub fn restriction_kind_from_abi(abi: &RestrictionKindAbi) -> Rc<KipioAccountRestriction::RestrictionKind> {
    Rc::new(KipioAccountRestriction::RestrictionKind::RestrictionKind {
        name: string_to_dafny_string(&abi.name),
    })
}

pub fn restriction_from_abi(abi: &RestrictionAbi) -> Rc<KipioAccountRestriction::Restriction> {
    Rc::new(KipioAccountRestriction::Restriction::Restriction {
        kind: restriction_kind_from_abi(&abi.kind),
        value: bytes_to_sequence(&abi.value),
    })
}

pub fn subject_from_abi(abi: &SubjectAbi) -> Rc<KipioAccountSubject::Subject> {
    Rc::new(KipioAccountSubject::Subject::Subject {
        reference: bytes_to_sequence(&abi.reference),
    })
}

pub fn identity_from_abi(abi: &IdentityAbi) -> Rc<KipioAccountIdentity::Identity> {
    Rc::new(KipioAccountIdentity::Identity::Identity {
        id: bytes_to_sequence(&abi.id),
        subject: subject_from_abi(&abi.subject),
    })
}

pub fn credential_from_abi(abi: &CredentialAbi) -> Rc<KipioAccountCredential::Credential> {
    Rc::new(KipioAccountCredential::Credential::Credential {
        id: bytes_to_sequence(&abi.id),
        status: credential_status_from_u8(abi.status),
    })
}

pub fn session_from_abi(abi: &SessionAbi) -> Rc<KipioAccountSession::Session> {
    let mut caps = SetBuilder::<Rc<KipioAccountCapability::Capability>>::new();
    for c in abi.capabilities.iter() { caps.add(&capability_from_abi(c)); }
    let mut restr = SetBuilder::<Rc<KipioAccountRestriction::Restriction>>::new();
    for r in abi.restrictions.iter() { restr.add(&restriction_from_abi(r)); }
    Rc::new(KipioAccountSession::Session::Session {
        id: bytes_to_sequence(&abi.id),
        credentialId: bytes_to_sequence(&abi.credentialId),
        capabilities: caps.build(),
        validFrom: u256_to_dafny_int(&abi.validFrom),
        validUntil: u256_to_dafny_int(&abi.validUntil),
        restrictions: restr.build(),
        status: session_status_from_u8(abi.status),
    })
}

pub fn delegation_from_abi(abi: &DelegationAbi) -> Rc<KipioAccountDelegation::Delegation> {
    let mut caps = SetBuilder::<Rc<KipioAccountCapability::Capability>>::new();
    for c in abi.capabilities.iter() { caps.add(&capability_from_abi(c)); }
    let mut restr = SetBuilder::<Rc<KipioAccountRestriction::Restriction>>::new();
    for r in abi.restrictions.iter() { restr.add(&restriction_from_abi(r)); }
    Rc::new(KipioAccountDelegation::Delegation::Delegation {
        id: bytes_to_sequence(&abi.id),
        delegatorIdentityId: bytes_to_sequence(&abi.delegatorIdentityId),
        delegatee: subject_from_abi(&abi.delegatee),
        capabilities: caps.build(),
        validFrom: u256_to_dafny_int(&abi.validFrom),
        validUntil: u256_to_dafny_int(&abi.validUntil),
        restrictions: restr.build(),
        metadata: bytes_to_sequence(&abi.metadata),
        status: delegation_status_from_u8(abi.status),
    })
}

pub fn optional_scope_from_abi(abi: &OptionalScopeAbi) -> Rc<KipioAccountPolicyEffect::OptionalPolicyScope> {
    if abi.hasScope {
        Rc::new(KipioAccountPolicyEffect::OptionalPolicyScope::Scoped {
            scope: scope_from_abi(&abi.scope),
        })
    } else {
        Rc::new(KipioAccountPolicyEffect::OptionalPolicyScope::NoScope {})
    }
}

pub fn restriction_target_from_abi(
    abi: &RestrictionTargetAbi,
) -> Rc<KipioAccountAuthorizationState::RestrictionTarget> {
    Rc::new(KipioAccountAuthorizationState::RestrictionTarget::RestrictionTarget {
        capability: capability_from_abi(&abi.capability),
        scope: optional_scope_from_abi(&abi.scope),
    })
}

pub fn policy_effect_from_abi(abi: &PolicyEffectAbi) -> Rc<KipioAccountPolicyEffect::PolicyEffect> {
    match abi.kind {
        1 => Rc::new(KipioAccountPolicyEffect::PolicyEffect::RevokeCredential {
            credentialId: bytes_to_sequence(&abi.id),
        }),
        2 => Rc::new(KipioAccountPolicyEffect::PolicyEffect::RevokeSession {
            sessionId: bytes_to_sequence(&abi.id),
        }),
        3 => Rc::new(KipioAccountPolicyEffect::PolicyEffect::RevokeDelegation {
            delegationId: bytes_to_sequence(&abi.id),
        }),
        4 => Rc::new(KipioAccountPolicyEffect::PolicyEffect::DisableCapability {
            capability: capability_from_abi(&abi.capability),
            scope: optional_scope_from_abi(&abi.scope),
        }),
        5 => Rc::new(KipioAccountPolicyEffect::PolicyEffect::EnableCapability {
            capability: capability_from_abi(&abi.capability),
            scope: optional_scope_from_abi(&abi.scope),
        }),
        6 => Rc::new(KipioAccountPolicyEffect::PolicyEffect::ModifyRestriction {
            capability: capability_from_abi(&abi.capability),
            scope: optional_scope_from_abi(&abi.scope),
            restriction: restriction_from_abi(&abi.restriction),
        }),
        _ => panic!("invalid PolicyEffect kind"),
    }
}

pub fn policy_from_abi(abi: &PolicyAbi) -> Rc<KipioAccountPolicy::Policy> {
    let effects: Sequence<Rc<KipioAccountPolicyEffect::PolicyEffect>> =
        abi.effects.iter().map(policy_effect_from_abi).collect();
    Rc::new(KipioAccountPolicy::Policy::Policy { effects })
}

pub fn policy_consumption_from_abi(
    abi: &PolicyConsumptionAbi,
) -> Rc<KipioAccountPolicyConsumption::PolicyConsumption> {
    Rc::new(KipioAccountPolicyConsumption::PolicyConsumption::PolicyConsumption {
        policy: policy_from_abi(&abi.policy),
    })
}

pub fn authorization_from_abi(abi: &AuthorizationAbi) -> Rc<KipioAccountAuthorization::Authorization> {
    let mut req = SetBuilder::<Rc<KipioAccountCapability::Capability>>::new();
    for cap in abi.requestedAuthority.iter() { req.add(&capability_from_abi(cap)); }
    let mut restr = SetBuilder::<Rc<KipioAccountRestriction::Restriction>>::new();
    for r in abi.restrictions.iter() { restr.add(&restriction_from_abi(r)); }
    Rc::new(KipioAccountAuthorization::Authorization::Authorization {
        credentialId: bytes_to_sequence(&abi.credentialId),
        requestedAuthority: req.build(),
        restrictions: restr.build(),
        validFrom: u256_to_dafny_int(&abi.validFrom),
        validUntil: u256_to_dafny_int(&abi.validUntil),
        replayKey: bytes_to_sequence(&abi.replayKey),
        accountId: bytes_to_sequence(&abi.accountId),
        executionTarget: execution_target_unit(),
        domainAction: domain_action_unit(),
        scope: scope_from_abi(&abi.scope),
        chain: KipioAccountChain::Chain,
    })
}

pub fn auth_state_from_abi(
    abi: &AuthorizationStateAbi,
) -> Rc<KipioAccountAuthorizationState::AuthorizationState> {
    let mut caps = SetBuilder::<Rc<KipioAccountCapability::Capability>>::new();
    for c in abi.capabilities.iter() { caps.add(&capability_from_abi(c)); }

    let mut creds = SetBuilder::<Rc<KipioAccountCredential::Credential>>::new();
    for c in abi.credentials.iter() { creds.add(&credential_from_abi(c)); }

    let mut cred_auth = MapBuilder::<Sequence<u8>, Set<Rc<KipioAccountCapability::Capability>>>::new();
    for entry in abi.credentialAuthorities.iter() {
        let key = bytes_to_sequence(&entry.credentialId);
        let mut auth = SetBuilder::<Rc<KipioAccountCapability::Capability>>::new();
        for c in entry.authority.iter() { auth.add(&capability_from_abi(c)); }
        let val = auth.build();
        cred_auth.add(&key, &val);
    }

    let mut sessions = SetBuilder::<Rc<KipioAccountSession::Session>>::new();
    for s in abi.sessions.iter() { sessions.add(&session_from_abi(s)); }

    let mut delegs = SetBuilder::<Rc<KipioAccountDelegation::Delegation>>::new();
    for d in abi.delegations.iter() { delegs.add(&delegation_from_abi(d)); }

    let mut prov = MapBuilder::<Sequence<u8>, Set<Sequence<u8>>>::new();
    for entry in abi.delegationProvenance.iter() {
        let key = bytes_to_sequence(&entry.delegationId);
        let mut parents = SetBuilder::<Sequence<u8>>::new();
        for p in entry.parents.iter() { parents.add(&bytes_to_sequence(p)); }
        let val = parents.build();
        prov.add(&key, &val);
    }

    let mut restr_map =
        MapBuilder::<Rc<KipioAccountAuthorizationState::RestrictionTarget>, Rc<KipioAccountRestriction::Restriction>>::new();
    for entry in abi.restrictionMap.iter() {
        let key = restriction_target_from_abi(&entry.target);
        let val = restriction_from_abi(&entry.restriction);
        restr_map.add(&key, &val);
    }

    let mut pol = SetBuilder::<Rc<KipioAccountPolicyEffect::PolicyEffect>>::new();
    for e in abi.policyEffects.iter() { pol.add(&policy_effect_from_abi(e)); }

    let mut replay = SetBuilder::<Sequence<u8>>::new();
    for k in abi.consumedReplayKeys.iter() { replay.add(&bytes_to_sequence(k)); }

    Rc::new(KipioAccountAuthorizationState::AuthorizationState::AuthorizationState {
        capabilities: caps.build(),
        credentials: creds.build(),
        credentialAuthorities: cred_auth.build(),
        sessions: sessions.build(),
        delegations: delegs.build(),
        delegationProvenance: prov.build(),
        restrictionMap: restr_map.build(),
        policyEffects: pol.build(),
        consumedReplayKeys: replay.build(),
    })
}

pub fn account_from_abi(abi: &AccountAbi) -> Rc<KipioAccountAccount::Account> {
    Rc::new(KipioAccountAccount::Account::Account {
        id: bytes_to_sequence(&abi.id),
        identity: identity_from_abi(&abi.identity),
        authorizationState: auth_state_from_abi(&abi.authorizationState),
    })
}

pub fn execution_request_from_abi(
    abi: &ExecutionRequestAbi,
) -> Rc<KipioAccountExecutionRequest::ExecutionRequest> {
    Rc::new(KipioAccountExecutionRequest::ExecutionRequest::ExecutionRequest {
        action: domain_action_unit(),
        authorization: authorization_from_abi(&abi.authorization),
        target: execution_target_unit(),
        constraints: execution_constraints_unit(),
    })
}

pub fn execution_context_from_abi(
    abi: &ExecutionContextAbi,
) -> Rc<KipioAccountExecutionContext::ExecutionContext> {
    let mut ea_builder = SetBuilder::<Rc<KipioAccountCapability::Capability>>::new();
    for c in abi.effectiveAuthority.iter() {
        ea_builder.add(&capability_from_abi(c));
    }
    Rc::new(KipioAccountExecutionContext::ExecutionContext::ExecutionContext {
        request: execution_request_from_abi(&abi.request),
        authorizationState: auth_state_from_abi(&abi.authorizationState),
        effectiveAuthority: ea_builder.build(),
        evaluationTime: u256_to_dafny_int(&abi.evaluationTime),
    })
}

// ============================================================================
// REVERSE CONVERTERS
// ============================================================================

pub fn scope_to_abi(scope: &Rc<KipioAccountScope::Scope>) -> ScopeAbi {
    let mut atoms = Vec::new();
    for a in scope.atoms().iter() {
        atoms.push(ScopeAtomAbi { id: sequence_to_bytes(a.id()) });
    }
    ScopeAbi { atoms }
}

pub fn capability_to_abi(cap: &Rc<KipioAccountCapability::Capability>) -> CapabilityAbi {
    CapabilityAbi {
        kind: CapabilityKindAbi {
            name: dafny_string_to_string(cap.kind().name()),
        },
        scope: scope_to_abi(cap.scope()),
    }
}

pub fn restriction_to_abi(r: &Rc<KipioAccountRestriction::Restriction>) -> RestrictionAbi {
    RestrictionAbi {
        kind: RestrictionKindAbi {
            name: dafny_string_to_string(r.kind().name()),
        },
        value: sequence_to_bytes(r.value()),
    }
}

pub fn subject_to_abi(s: &Rc<KipioAccountSubject::Subject>) -> SubjectAbi {
    SubjectAbi { reference: sequence_to_bytes(s.reference()) }
}

pub fn identity_to_abi(id: &Rc<KipioAccountIdentity::Identity>) -> IdentityAbi {
    IdentityAbi {
        id: sequence_to_bytes(id.id()),
        subject: subject_to_abi(id.subject()),
    }
}

pub fn credential_to_abi(c: &Rc<KipioAccountCredential::Credential>) -> CredentialAbi {
    CredentialAbi {
        id: sequence_to_bytes(c.id()),
        status: credential_status_to_u8(c.status()),
    }
}

pub fn session_to_abi(s: &Rc<KipioAccountSession::Session>) -> SessionAbi {
    let mut caps = Vec::new();
    for c in s.capabilities().iter() { caps.push(capability_to_abi(c)); }
    let mut restr = Vec::new();
    for r in s.restrictions().iter() { restr.push(restriction_to_abi(r)); }
    SessionAbi {
        id: sequence_to_bytes(s.id()),
        credentialId: sequence_to_bytes(s.credentialId()),
        capabilities: caps,
        validFrom: dafny_int_to_u256(s.validFrom()),
        validUntil: dafny_int_to_u256(s.validUntil()),
        restrictions: restr,
        status: session_status_to_u8(s.status()),
    }
}

pub fn delegation_to_abi(d: &Rc<KipioAccountDelegation::Delegation>) -> DelegationAbi {
    let mut caps = Vec::new();
    for c in d.capabilities().iter() { caps.push(capability_to_abi(c)); }
    let mut restr = Vec::new();
    for r in d.restrictions().iter() { restr.push(restriction_to_abi(r)); }
    DelegationAbi {
        id: sequence_to_bytes(d.id()),
        delegatorIdentityId: sequence_to_bytes(d.delegatorIdentityId()),
        delegatee: subject_to_abi(d.delegatee()),
        capabilities: caps,
        validFrom: dafny_int_to_u256(d.validFrom()),
        validUntil: dafny_int_to_u256(d.validUntil()),
        restrictions: restr,
        metadata: sequence_to_bytes(d.metadata()),
        status: delegation_status_to_u8(d.status()),
    }
}

pub fn optional_scope_to_abi(s: &Rc<KipioAccountPolicyEffect::OptionalPolicyScope>) -> OptionalScopeAbi {
    match s.as_ref() {
        KipioAccountPolicyEffect::OptionalPolicyScope::NoScope {} => {
            OptionalScopeAbi { hasScope: false, scope: empty_scope_abi() }
        }
        KipioAccountPolicyEffect::OptionalPolicyScope::Scoped { scope } => {
            OptionalScopeAbi { hasScope: true, scope: scope_to_abi(scope) }
        }
    }
}

pub fn restriction_target_to_abi(
    t: &Rc<KipioAccountAuthorizationState::RestrictionTarget>,
) -> RestrictionTargetAbi {
    RestrictionTargetAbi {
        capability: capability_to_abi(t.capability()),
        scope: optional_scope_to_abi(t.scope()),
    }
}

pub fn policy_effect_to_abi(e: &Rc<KipioAccountPolicyEffect::PolicyEffect>) -> PolicyEffectAbi {
    match e.as_ref() {
        KipioAccountPolicyEffect::PolicyEffect::RevokeCredential { credentialId } => PolicyEffectAbi {
            kind: 1, id: sequence_to_bytes(credentialId),
            capability: empty_capability_abi(), scope: empty_optional_scope_abi(), restriction: empty_restriction_abi(),
        },
        KipioAccountPolicyEffect::PolicyEffect::RevokeSession { sessionId } => PolicyEffectAbi {
            kind: 2, id: sequence_to_bytes(sessionId),
            capability: empty_capability_abi(), scope: empty_optional_scope_abi(), restriction: empty_restriction_abi(),
        },
        KipioAccountPolicyEffect::PolicyEffect::RevokeDelegation { delegationId } => PolicyEffectAbi {
            kind: 3, id: sequence_to_bytes(delegationId),
            capability: empty_capability_abi(), scope: empty_optional_scope_abi(), restriction: empty_restriction_abi(),
        },
        KipioAccountPolicyEffect::PolicyEffect::DisableCapability { capability, scope } => PolicyEffectAbi {
            kind: 4, id: Bytes::new(),
            capability: capability_to_abi(capability), scope: optional_scope_to_abi(scope), restriction: empty_restriction_abi(),
        },
        KipioAccountPolicyEffect::PolicyEffect::EnableCapability { capability, scope } => PolicyEffectAbi {
            kind: 5, id: Bytes::new(),
            capability: capability_to_abi(capability), scope: optional_scope_to_abi(scope), restriction: empty_restriction_abi(),
        },
        KipioAccountPolicyEffect::PolicyEffect::ModifyRestriction { capability, scope, restriction } => PolicyEffectAbi {
            kind: 6, id: Bytes::new(),
            capability: capability_to_abi(capability), scope: optional_scope_to_abi(scope), restriction: restriction_to_abi(restriction),
        },
    }
}

pub fn policy_to_abi(p: &Rc<KipioAccountPolicy::Policy>) -> PolicyAbi {
    let mut effects = Vec::new();
    for e in p.effects().iter() {
        effects.push(policy_effect_to_abi(&e));
    }
    PolicyAbi { effects }
}

pub fn policy_consumption_to_abi(
    c: &Rc<KipioAccountPolicyConsumption::PolicyConsumption>,
) -> PolicyConsumptionAbi {
    PolicyConsumptionAbi { policy: policy_to_abi(c.policy()) }
}

pub fn authorization_to_abi(
    a: &Rc<KipioAccountAuthorization::Authorization>,
) -> AuthorizationAbi {
    let mut req = Vec::new();
    for c in a.requestedAuthority().iter() { req.push(capability_to_abi(c)); }
    let mut restr = Vec::new();
    for r in a.restrictions().iter() { restr.push(restriction_to_abi(r)); }
    AuthorizationAbi {
        credentialId: sequence_to_bytes(a.credentialId()),
        requestedAuthority: req,
        restrictions: restr,
        validFrom: dafny_int_to_u256(a.validFrom()),
        validUntil: dafny_int_to_u256(a.validUntil()),
        replayKey: sequence_to_bytes(a.replayKey()),
        accountId: sequence_to_bytes(a.accountId()),
        scope: scope_to_abi(a.scope()),
    }
}

pub fn auth_state_to_abi(
    s: &Rc<KipioAccountAuthorizationState::AuthorizationState>,
) -> AuthorizationStateAbi {
    let mut caps = Vec::new();
    for c in s.capabilities().iter() { caps.push(capability_to_abi(c)); }

    let mut creds = Vec::new();
    for c in s.credentials().iter() { creds.push(credential_to_abi(c)); }

    let mut cred_auth = Vec::new();
    for credential_id in s.credentialAuthorities().keys().iter() {
        let authority_set = s.credentialAuthorities().get(credential_id);
        let mut auth_caps = Vec::new();
        for c in authority_set.iter() { auth_caps.push(capability_to_abi(c)); }
        cred_auth.push(CredentialAuthorityEntryAbi {
            credentialId: sequence_to_bytes(credential_id),
            authority: auth_caps,
        });
    }

    let mut sessions = Vec::new();
    for sess in s.sessions().iter() { sessions.push(session_to_abi(sess)); }

    let mut delegations = Vec::new();
    for d in s.delegations().iter() { delegations.push(delegation_to_abi(d)); }

    let mut prov = Vec::new();
    for delegation_id in s.delegationProvenance().keys().iter() {
        let parents_set = s.delegationProvenance().get(delegation_id);
        let mut parents = Vec::new();
        for p in parents_set.iter() { parents.push(sequence_to_bytes(p)); }
        prov.push(DelegationProvenanceEntryAbi {
            delegationId: sequence_to_bytes(delegation_id),
            parents,
        });
    }

    let mut restr_map = Vec::new();
    for target in s.restrictionMap().keys().iter() {
        let r = s.restrictionMap().get(target);
        restr_map.push(RestrictionEntryAbi {
            target: restriction_target_to_abi(target),
            restriction: restriction_to_abi(&r),
        });
    }

    let mut pol = Vec::new();
    for e in s.policyEffects().iter() { pol.push(policy_effect_to_abi(e)); }

    let mut consumed = Vec::new();
    for k in s.consumedReplayKeys().iter() { consumed.push(sequence_to_bytes(k)); }

    AuthorizationStateAbi {
        capabilities: caps,
        credentials: creds,
        credentialAuthorities: cred_auth,
        sessions,
        delegations,
        delegationProvenance: prov,
        restrictionMap: restr_map,
        policyEffects: pol,
        consumedReplayKeys: consumed,
    }
}

pub fn account_to_abi(a: &Rc<KipioAccountAccount::Account>) -> AccountAbi {
    AccountAbi {
        id: sequence_to_bytes(a.id()),
        identity: identity_to_abi(a.identity()),
        authorizationState: auth_state_to_abi(a.authorizationState()),
    }
}

pub fn execution_request_to_abi(
    r: &Rc<KipioAccountExecutionRequest::ExecutionRequest>,
) -> ExecutionRequestAbi {
    ExecutionRequestAbi {
        authorization: authorization_to_abi(r.authorization()),
    }
}

pub fn execution_context_to_abi(
    c: &Rc<KipioAccountExecutionContext::ExecutionContext>,
) -> ExecutionContextAbi {
    let mut ea = Vec::new();
    for cap in c.effectiveAuthority().iter() { ea.push(capability_to_abi(cap)); }
    ExecutionContextAbi {
        request: execution_request_to_abi(c.request()),
        authorizationState: auth_state_to_abi(c.authorizationState()),
        effectiveAuthority: ea,
        evaluationTime: dafny_int_to_u256(c.evaluationTime()),
    }
}

// ============================================================================
// VALIDATORS
// ============================================================================

pub fn valid_account_impl(account_abi: &AccountAbi) -> bool {
    let account = account_from_abi(account_abi);
    KipioAccountAccount::_default::ValidAccount(&account)
}

pub fn valid_authorization_state_impl(state_abi: &AuthorizationStateAbi) -> bool {
    let state = auth_state_from_abi(state_abi);
    KipioAccountAuthorizationState::_default::ValidAuthorizationState(&state)
}

// ============================================================================
// COMPOSED ENTRYPOINTS
// ============================================================================

pub fn authorization_can_be_accepted_full_impl(
    auth_abi: &AuthorizationAbi,
    account_abi: &AccountAbi,
    identities_abi: &[IdentityAbi],
    now: U256,
    proof_verified: bool,
) -> bool {
    let authorization = authorization_from_abi(auth_abi);
    let account = account_from_abi(account_abi);
    let mut ids = SetBuilder::<Rc<KipioAccountIdentity::Identity>>::new();
    for id_abi in identities_abi.iter() {
        ids.add(&identity_from_abi(id_abi));
    }
    let identities = ids.build();
    let now_dafny = u256_to_dafny_int(&now);

    KipioAccountAuthorizationAcceptanceWithProvenance::_default::AuthorizationCanBeAcceptedFull(
        &authorization, &account, &identities, &now_dafny, proof_verified,
    )
}

pub fn apply_policy_consumption_impl(
    account_abi: &AccountAbi,
    consumption_abi: &PolicyConsumptionAbi,
) -> (AccountAbi, bool) {
    let account = account_from_abi(account_abi);
    let consumption = policy_consumption_from_abi(consumption_abi);

    let applicable = KipioAccountPolicyApplicationComposition::_default::PolicyIsApplicableAndConsistentExec(
        &account,
        &consumption,
    );

    if !applicable {
        return (account_abi.clone(), false);
    }

    let new_account = KipioAccountPolicyApplicationComposition::_default::ApplyPolicyConsumption(
        &account,
        &consumption,
    );
    (account_to_abi(&new_account), true)
}

/// Computes the canonical EffectiveAuthority for an Account at a given
/// evaluation time.
///
/// This exposes Dafny's ComputeEffectiveAuthorityWitness, which applies
/// the D1.30 derivation:
///
/// ```text
/// EffectiveAuthority =
///       Account Capabilities
///     ∪ Credential Authority (active credentials only)
///     ∪ Session Capabilities (usable sessions only)
///     ∪ Delegation Capabilities (usable delegations with legitimate
///       source provenance only)
/// ```
///
/// The three additional out-parameters of the underlying Dafny method
/// (sourceReferences, sourceAuthorities, contributions) form the
/// provenance witness. They do NOT cross the ABI: they remain internal
/// to Dafny and are reconstructed on demand by
/// AuthorizationCanBeAcceptedFull.
///
/// A caller that wants to build a valid ExecutionContextAbi must pass
/// exactly the returned set as `effectiveAuthority`. Doing so
/// guarantees that valid_execution_context will accept the context
/// with respect to the EffectiveAuthority field.
pub fn compute_effective_authority_impl(
    account_abi: &AccountAbi,
    identities_abi: &[IdentityAbi],
    now: U256,
) -> Vec<CapabilityAbi> {
    let account = account_from_abi(account_abi);
    let mut ids = SetBuilder::<Rc<KipioAccountIdentity::Identity>>::new();
    for id_abi in identities_abi.iter() {
        ids.add(&identity_from_abi(id_abi));
    }
    let identities = ids.build();
    let now_dafny = u256_to_dafny_int(&now);

    let (effective_authority, _, _, _) =
        KipioAccountEffectiveAuthorityComposition::_default::ComputeEffectiveAuthorityWitness(
            &account,
            &identities,
            &now_dafny,
        );

    let mut out = Vec::new();
    for cap in effective_authority.iter() {
        out.push(capability_to_abi(cap));
    }
    out
}

pub fn authorization_is_structurally_valid_impl(abi: &AuthorizationAbi) -> bool {
    KipioAccountAuthorizationValidation::_default::AuthorizationIsStructurallyValid(
        &authorization_from_abi(abi),
    )
}

/// Validates a complete ExecutionContext against a specific Account.
///
/// This mirrors Dafny's ValidExecutionContextForAccountFull, which:
///   - checks structural validity of the context;
///   - checks that the context's state snapshot equals the account's
///     current state;
///   - checks the account is valid;
///   - checks the identity context is valid;
///   - calls AuthorizationCanBeAcceptedFull (constructing the
///     EffectiveAuthority provenance witness internally);
///   - verifies that the EffectiveAuthority carried by the context
///     equals the canonical derivation computed from the account's
///     current state.
///
/// Environment compatibility is intentionally NOT part of this
/// intrinsic validity. Per D6, an ExecutionContext may be
/// intrinsically valid while being incompatible with a particular
/// selected ExecutionEnvironment; that gate belongs to the execution
/// boundary.
pub fn valid_execution_context_impl(
    context_abi: &ExecutionContextAbi,
    account_abi: &AccountAbi,
    identities_abi: &[IdentityAbi],
    proof_verified: bool,
) -> bool {
    let context = execution_context_from_abi(context_abi);
    let account = account_from_abi(account_abi);
    let mut ids = SetBuilder::<Rc<KipioAccountIdentity::Identity>>::new();
    for id_abi in identities_abi.iter() {
        ids.add(&identity_from_abi(id_abi));
    }
    let identities = ids.build();

    KipioAccountExecutionContextComposition::_default::ValidExecutionContextForAccountFull(
        &context,
        &account,
        &identities,
        proof_verified,
    )
}

// ============================================================================
// PROVISIONING TRANSITIONS
// ============================================================================

pub fn register_credential_impl(
    account_abi: &AccountAbi,
    credential_abi: &CredentialAbi,
) -> (AccountAbi, bool) {
    let account = account_from_abi(account_abi);
    let credential = credential_from_abi(credential_abi);

    if !KipioAccountAccount::_default::ValidAccount(&account) {
        return (account_abi.clone(), false);
    }
    if !KipioAccountCredential::_default::ValidCredential(&credential) {
        return (account_abi.clone(), false);
    }

    let state = KipioAccountAccount::_default::AccountAuthorizationState(&account);
    let credential_id = KipioAccountCredential::_default::CredentialId(&credential);

    if KipioAccountAuthorizationState::_default::CredentialIdRecognizedInState(&state, &credential_id) {
        return (account_abi.clone(), false);
    }

    let new_account = KipioAccountAccountTransitions::_default::RegisterCredential(&account, &credential);
    (account_to_abi(&new_account), true)
}

pub fn register_session_impl(
    account_abi: &AccountAbi,
    session_abi: &SessionAbi,
) -> (AccountAbi, bool) {
    let account = account_from_abi(account_abi);
    let session = session_from_abi(session_abi);

    if !KipioAccountAccount::_default::ValidAccount(&account) {
        return (account_abi.clone(), false);
    }
    if !KipioAccountSession::_default::ValidSession(&session) {
        return (account_abi.clone(), false);
    }

    let state = KipioAccountAccount::_default::AccountAuthorizationState(&account);
    let session_id = KipioAccountSession::_default::SessionId(&session);

    if KipioAccountAuthorizationState::_default::SessionIdRecognizedInState(&state, &session_id) {
        return (account_abi.clone(), false);
    }

    let credential_id = KipioAccountSession::_default::SessionCredentialId(&session);

    if !KipioAccountAuthorizationState::_default::CredentialIdRecognizedInState(&state, &credential_id) {
        return (account_abi.clone(), false);
    }
    if !KipioAccountAuthorizationState::_default::CredentialAuthorityDefinedForCredentialId(&state, &credential_id) {
        return (account_abi.clone(), false);
    }

    let credential_authority =
        KipioAccountAuthorizationState::_default::StateCredentialAuthorityById(&state, &credential_id);

    if !KipioAccountSession::_default::SessionAuthorityWithinCredentialAuthority(&session, &credential_authority) {
        return (account_abi.clone(), false);
    }

    let new_account = KipioAccountAccountTransitions::_default::RegisterSession(&account, &session);
    (account_to_abi(&new_account), true)
}

pub fn register_delegation_impl(
    account_abi: &AccountAbi,
    delegation_abi: &DelegationAbi,
    delegate_capability_abi: &CapabilityAbi,
    delegatable_authority_abi: &[CapabilityAbi],
    source_effective_authority_abi: &[CapabilityAbi],
) -> (AccountAbi, bool) {
    let account = account_from_abi(account_abi);
    let delegation = delegation_from_abi(delegation_abi);
    let delegate_capability = capability_from_abi(delegate_capability_abi);

    let mut delegatable = SetBuilder::<Rc<KipioAccountCapability::Capability>>::new();
    for c in delegatable_authority_abi.iter() {
        delegatable.add(&capability_from_abi(c));
    }
    let delegatable_authority = delegatable.build();

    let mut source_eff = SetBuilder::<Rc<KipioAccountCapability::Capability>>::new();
    for c in source_effective_authority_abi.iter() {
        source_eff.add(&capability_from_abi(c));
    }
    let source_effective_authority = source_eff.build();

    if !KipioAccountAccountTransitions::_default::ValidRootDelegationRegistration(
        &account,
        &delegation,
        &delegate_capability,
        &delegatable_authority,
        &source_effective_authority,
    ) {
        return (account_abi.clone(), false);
    }

    let new_account = KipioAccountAccountTransitions::_default::RegisterDelegation(
        &account,
        &delegation,
        &delegate_capability,
        &delegatable_authority,
        &source_effective_authority,
    );
    (account_to_abi(&new_account), true)
}

pub fn register_transitive_delegation_impl(
    account_abi: &AccountAbi,
    delegation_abi: &DelegationAbi,
    delegate_capability_abi: &CapabilityAbi,
    delegatable_authority_abi: &[CapabilityAbi],
    source_effective_authority_abi: &[CapabilityAbi],
    parent_delegation_ids: &[Bytes],
    identities_abi: &[IdentityAbi],
) -> (AccountAbi, bool) {
    let account = account_from_abi(account_abi);
    let delegation = delegation_from_abi(delegation_abi);
    let delegate_capability = capability_from_abi(delegate_capability_abi);

    let mut delegatable = SetBuilder::<Rc<KipioAccountCapability::Capability>>::new();
    for c in delegatable_authority_abi.iter() {
        delegatable.add(&capability_from_abi(c));
    }
    let delegatable_authority = delegatable.build();

    let mut source_eff = SetBuilder::<Rc<KipioAccountCapability::Capability>>::new();
    for c in source_effective_authority_abi.iter() {
        source_eff.add(&capability_from_abi(c));
    }
    let source_effective_authority = source_eff.build();

    let mut parents = SetBuilder::<Sequence<u8>>::new();
    for p in parent_delegation_ids.iter() {
        parents.add(&bytes_to_sequence(p));
    }
    let parent_delegation_ids_set = parents.build();

    let mut ids = SetBuilder::<Rc<KipioAccountIdentity::Identity>>::new();
    for id_abi in identities_abi.iter() {
        ids.add(&identity_from_abi(id_abi));
    }
    let identities = ids.build();

    if !KipioAccountAccountTransitions::_default::ValidTransitiveDelegationRegistration(
        &account,
        &delegation,
        &delegate_capability,
        &delegatable_authority,
        &source_effective_authority,
        &parent_delegation_ids_set,
        &identities,
    ) {
        return (account_abi.clone(), false);
    }

    let new_account = KipioAccountAccountTransitions::_default::RegisterTransitiveDelegation(
        &account,
        &delegation,
        &delegate_capability,
        &delegatable_authority,
        &source_effective_authority,
        &parent_delegation_ids_set,
        &identities,
    );
    (account_to_abi(&new_account), true)
}

pub fn add_capability_impl(
    account_abi: &AccountAbi,
    capability_abi: &CapabilityAbi,
) -> (AccountAbi, bool) {
    let account = account_from_abi(account_abi);
    let capability = capability_from_abi(capability_abi);

    if !KipioAccountAccount::_default::ValidAccount(&account) {
        return (account_abi.clone(), false);
    }
    if !KipioAccountCapability::_default::ValidCapability(&capability) {
        return (account_abi.clone(), false);
    }

    let new_account = KipioAccountAccountTransitions::_default::AddCapability(&account, &capability);
    (account_to_abi(&new_account), true)
}

pub fn remove_capability_impl(
    account_abi: &AccountAbi,
    capability_abi: &CapabilityAbi,
) -> (AccountAbi, bool) {
    let account = account_from_abi(account_abi);
    let capability = capability_from_abi(capability_abi);

    if !KipioAccountAccount::_default::ValidAccount(&account) {
        return (account_abi.clone(), false);
    }

    let new_account = KipioAccountAccountTransitions::_default::RemoveCapability(&account, &capability);
    (account_to_abi(&new_account), true)
}

pub fn set_restriction_impl(
    account_abi: &AccountAbi,
    capability_abi: &CapabilityAbi,
    scope_abi: &OptionalScopeAbi,
    restriction_abi: &RestrictionAbi,
) -> (AccountAbi, bool) {
    let account = account_from_abi(account_abi);
    let capability = capability_from_abi(capability_abi);
    let scope = optional_scope_from_abi(scope_abi);
    let restriction = restriction_from_abi(restriction_abi);

    if !KipioAccountAccount::_default::ValidAccount(&account) {
        return (account_abi.clone(), false);
    }
    if !KipioAccountCapability::_default::ValidCapability(&capability) {
        return (account_abi.clone(), false);
    }
    if !KipioAccountPolicyEffect::_default::ValidOptionalPolicyScope(&scope) {
        return (account_abi.clone(), false);
    }
    if !KipioAccountRestriction::_default::ValidRestriction(&restriction) {
        return (account_abi.clone(), false);
    }

    let state = KipioAccountAccount::_default::AccountAuthorizationState(&account);
    let caps = KipioAccountAuthorizationState::_default::StateCapabilities(&state);
    if !caps.contains(&capability) {
        return (account_abi.clone(), false);
    }

    let new_account = KipioAccountAccountTransitions::_default::SetRestriction(
        &account,
        &capability,
        &scope,
        &restriction,
    );
    (account_to_abi(&new_account), true)
}

pub fn remove_restriction_impl(
    account_abi: &AccountAbi,
    capability_abi: &CapabilityAbi,
    scope_abi: &OptionalScopeAbi,
) -> (AccountAbi, bool) {
    let account = account_from_abi(account_abi);
    let capability = capability_from_abi(capability_abi);
    let scope = optional_scope_from_abi(scope_abi);

    if !KipioAccountAccount::_default::ValidAccount(&account) {
        return (account_abi.clone(), false);
    }

    let new_account = KipioAccountAccountTransitions::_default::RemoveRestriction(
        &account,
        &capability,
        &scope,
    );
    (account_to_abi(&new_account), true)
}

pub fn set_credential_authority_impl(
    account_abi: &AccountAbi,
    credential_abi: &CredentialAbi,
    authority_abi: &[CapabilityAbi],
) -> (AccountAbi, bool) {
    let account = account_from_abi(account_abi);
    let credential = credential_from_abi(credential_abi);

    let mut auth_set = SetBuilder::<Rc<KipioAccountCapability::Capability>>::new();
    for c in authority_abi.iter() {
        auth_set.add(&capability_from_abi(c));
    }
    let authority = auth_set.build();

    if !KipioAccountAccount::_default::ValidAccount(&account) {
        return (account_abi.clone(), false);
    }
    if !KipioAccountCredentialAuthority::_default::ValidCredentialAuthority(&authority) {
        return (account_abi.clone(), false);
    }

    let state = KipioAccountAccount::_default::AccountAuthorizationState(&account);

    if !KipioAccountAuthorizationState::_default::CredentialRecognizedInState(&state, &credential) {
        return (account_abi.clone(), false);
    }

    let credential_id = KipioAccountCredential::_default::CredentialId(&credential);

    if !KipioAccountAccountTransitions::_default::ExistingSessionsRemainWithinCredentialAuthority(
        &state,
        &credential_id,
        &authority,
    ) {
        return (account_abi.clone(), false);
    }

    let new_account = KipioAccountAccountTransitions::_default::SetCredentialAuthority(
        &account,
        &credential,
        &authority,
    );
    (account_to_abi(&new_account), true)
}

pub fn consume_replay_key_impl(
    account_abi: &AccountAbi,
    replay_key: &Bytes,
) -> (AccountAbi, bool) {
    let account = account_from_abi(account_abi);
    let key = bytes_to_sequence(replay_key);

    if !KipioAccountAccount::_default::ValidAccount(&account) {
        return (account_abi.clone(), false);
    }

    let state = KipioAccountAccount::_default::AccountAuthorizationState(&account);

    if !KipioAccountAccountTransitions::_default::ValidReplayKeyConsumption(&state, &key) {
        return (account_abi.clone(), false);
    }

    let new_account = KipioAccountAccountTransitions::_default::ConsumeReplayKey(&account, &key);
    (account_to_abi(&new_account), true)
}

pub fn update_credential_status_impl(
    account_abi: &AccountAbi,
    credential_abi: &CredentialAbi,
    new_status: u8,
) -> (AccountAbi, bool) {
    let account = account_from_abi(account_abi);
    let credential = credential_from_abi(credential_abi);
    let status = credential_status_from_u8(new_status);

    if !KipioAccountAccount::_default::ValidAccount(&account) {
        return (account_abi.clone(), false);
    }

    let state = KipioAccountAccount::_default::AccountAuthorizationState(&account);
    let credentials = KipioAccountAuthorizationState::_default::StateCredentials(&state);

    if !credentials.contains(&credential) {
        return (account_abi.clone(), false);
    }

    if !KipioAccountAccountTransitions::_default::ValidCredentialStatusTransition(&credential, &status) {
        return (account_abi.clone(), false);
    }

    let new_account = KipioAccountAccountTransitions::_default::UpdateCredentialStatus(
        &account,
        &credential,
        &status,
    );
    (account_to_abi(&new_account), true)
}

pub fn update_session_status_impl(
    account_abi: &AccountAbi,
    session_abi: &SessionAbi,
    new_status: u8,
) -> (AccountAbi, bool) {
    let account = account_from_abi(account_abi);
    let session = session_from_abi(session_abi);
    let status = session_status_from_u8(new_status);

    if !KipioAccountAccount::_default::ValidAccount(&account) {
        return (account_abi.clone(), false);
    }

    let state = KipioAccountAccount::_default::AccountAuthorizationState(&account);
    let sessions = KipioAccountAuthorizationState::_default::StateSessions(&state);

    if !sessions.contains(&session) {
        return (account_abi.clone(), false);
    }

    if !KipioAccountAccountTransitions::_default::ValidSessionStatusTransition(&session, &status) {
        return (account_abi.clone(), false);
    }

    let new_account = KipioAccountAccountTransitions::_default::UpdateSessionStatus(
        &account,
        &session,
        &status,
    );
    (account_to_abi(&new_account), true)
}

pub fn update_delegation_status_impl(
    account_abi: &AccountAbi,
    delegation_abi: &DelegationAbi,
    new_status: u8,
) -> (AccountAbi, bool) {
    let account = account_from_abi(account_abi);
    let delegation = delegation_from_abi(delegation_abi);
    let status = delegation_status_from_u8(new_status);

    if !KipioAccountAccount::_default::ValidAccount(&account) {
        return (account_abi.clone(), false);
    }

    let state = KipioAccountAccount::_default::AccountAuthorizationState(&account);
    let delegations = KipioAccountAuthorizationState::_default::StateDelegations(&state);

    if !delegations.contains(&delegation) {
        return (account_abi.clone(), false);
    }

    if !KipioAccountAccountTransitions::_default::ValidDelegationStatusTransition(&delegation, &status) {
        return (account_abi.clone(), false);
    }

    let new_account = KipioAccountAccountTransitions::_default::UpdateDelegationStatus(
        &account,
        &delegation,
        &status,
    );
    (account_to_abi(&new_account), true)
}

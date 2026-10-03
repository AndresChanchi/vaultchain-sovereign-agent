// Companion struct definitions for Stylus-exported interfaces.
//
// WHY THIS FILE EXISTS:
//
// Stylus SDK 0.10.x omits struct declarations when a struct is only used
// as an INPUT parameter (never as a return type, never in a storage-
// backed field). Solidity then rejects the interface with:
//
//   Error (7920): Identifier not found or not unique.
//
// This is a known SDK limitation. It is documented in the workspace
// README and corresponds to stylus-sdk-rs issue #368 and OpenZeppelin
// audit finding M-17.
//
// scripts/fix-abi-structs.sh reads this file, scans each exported
// interface for referenced-but-undeclared structs, and appends the
// missing ones from here, inside the interface body.
//
// MAINTENANCE:
//
// Add an entry whenever a new input-only struct is introduced in the
// bridge crate. The names must match the identifiers used in the
// exported interfaces exactly.
//
// Structs that the SDK already emits on its own do NOT belong here. This
// file only carries the omissions. A struct is only missing if it is
// used as an input-only parameter in some function signature.
//
// Structs are grouped by the interface that references them first, but
// the script applies the whole file to every interface. Any struct
// referenced-but-not-declared in a given interface gets injected, so
// listing order in this file is irrelevant.

// ============================================================================
// KIPIO ACCOUNT INTERFACE
// ============================================================================

// The identity anchor struct. Referenced by registerTransitiveDelegation
// in kipio_account but never used as a return type, so the SDK omits it.
struct IdentityAbi {
    bytes id;
    SubjectAbi subject;
}

// The recovery effect struct. Referenced by executeRecovery in
// kipio_account as an input array, so the SDK omits it.
struct RecoveryEffect {
    uint8 kind;
    bytes payload;
}

// ============================================================================
// KIPIO RUNTIME INTERFACE
// ============================================================================

// The authorization struct. Referenced by authorizationIsStructurallyValid
// and authorizationCanBeAcceptedFull. Input-only, so the SDK omits it.
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

// The policy wrapper. Nested inside PolicyConsumptionAbi. Not emitted
// because PolicyConsumptionAbi itself is not emitted.
struct PolicyAbi {
    PolicyEffectAbi[] effects;
}

// The policy consumption struct. Referenced by applyPolicyConsumption.
// Input-only, so the SDK omits it.
struct PolicyConsumptionAbi {
    PolicyAbi policy;
}

// The execution request wrapper. Nested inside ExecutionContextAbi.
// Not emitted because ExecutionContextAbi itself is not emitted.
struct ExecutionRequestAbi {
    AuthorizationAbi authorization;
}

// The execution context struct. Referenced by validExecutionContext.
// Input-only, so the SDK omits it.
struct ExecutionContextAbi {
    ExecutionRequestAbi request;
    AuthorizationStateAbi authorizationState;
    CapabilityAbi[] effectiveAuthority;
    uint256 evaluationTime;
}

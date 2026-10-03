// ============================================================
// KIPIO ACCOUNT DOMAIN
// POLICY — POLICY EFFECT
// ============================================================
//
// Policy Effect represents a semantic change that a Policy may
// produce over Authorization State.
//
// PolicyEffect is a Value Object.
//
// It does NOT represent:
//
//   - a historical event;
//   - a Policy identity;
//   - a Policy request identity;
//   - a governance decision identity;
//   - a consumption identity;
//   - an Authorization State Transition identity.
//
// Historical identity belongs to the bounded context that produced
// the external policy decision.
//
// Conceptual separation:
//
//     Policy
//         |
//         v
//     PolicyEffect
//         |
//         v
//     PolicyConsumption
//         |
//         v
//     AuthorizationStateTransition
//
// PolicyEffect describes WHAT semantic change is recognized.
//
// AuthorizationStateTransition is responsible for determining
// whether that semantic change can be applied while preserving
// AuthorizationState invariants.
//
// ------------------------------------------------------------
//
// D2 — POLICY EFFECT SEMANTICS
//
// PolicyEffect is a closed algebra of semantic state-change
// descriptors.
//
// Current effect kinds:
//
//   RevokeCredential(CredentialId)
//   RevokeSession(SessionId)
//   RevokeDelegation(DelegationId)
//   DisableCapability(Capability, OptionalScope)
//   EnableCapability(Capability, OptionalScope)
//   ModifyRestriction(Capability, OptionalScope, Restriction)
//
// Equality is determined by:
//
//   - effect kind;
//   - all semantic payload values.
//
// PolicyEffect has no independent identity.
//
// ------------------------------------------------------------
//
// OPTIONAL SCOPE
//
// The DDD specifies that some Policy Effects may carry an optional
// Scope.
//
// OptionalPolicyScope is only the formal representation of that
// optional payload. It does not introduce a new domain concept.
//
// ------------------------------------------------------------
//
// IMPORTANT BOUNDARY
//
// PolicyEffect does NOT determine:
//
//   - whether the referenced Entity currently exists;
//   - whether the effect is applicable to an AuthorizationState;
//   - whether two effects contradict one another;
//   - whether effects commute;
//   - whether a Policy is atomically consumable;
//   - how AuthorizationState is mutated.
//
// Those concerns belong to Policy, PolicyConsumption and
// AuthorizationStateTransition semantics.
//
// ------------------------------------------------------------
//
// This file intentionally contains no:
//   - policy approval logic
//   - governance logic
//   - recovery implementation
//   - policy consumption
//   - authorization state mutation
//   - authorization validation
//   - execution logic
//   - cryptographic verification
//   - blockchain ABI types
//   - storage representations
//
// ============================================================

include "../foundation/DomainPrimitives.dfy"
include "../foundation/Capability.dfy"
include "../foundation/Scope.dfy"
include "../foundation/Restriction.dfy"

module KipioAccountPolicyEffect
{
  import opened KipioAccountDomainPrimitives
  import opened KipioAccountCapability
  import opened KipioAccountScope
  import opened KipioAccountRestriction


  // ----------------------------------------------------------
  // OPTIONAL POLICY EFFECT SCOPE
  // ----------------------------------------------------------

  // Formal representation of an optional Scope payload.
  //
  // This is not a new domain Value Object. It only represents the
  // presence or absence of the Scope parameter required by certain
  // Policy Effect constructors.
  datatype OptionalPolicyScope =
      NoScope
    | Scoped(scope: Scope)


  // ----------------------------------------------------------
  // POLICY EFFECT
  // ----------------------------------------------------------

  // Closed semantic algebra of Policy Effects.
  //
  // Each constructor identifies a semantic kind of state change.
  //
  // Entity references use their stable Entity identifiers:
  //
  //   Credential  -> Id
  //   Session     -> Id
  //   Delegation  -> Id
  //
  // Capability remains a Value Object and is therefore embedded
  // directly.
  //
  // Restriction remains a Value Object and is therefore embedded
  // directly.
  datatype PolicyEffect =
      RevokeCredential(
        credentialId: Id
      )
    | RevokeSession(
        sessionId: Id
      )
    | RevokeDelegation(
        delegationId: Id
      )
    | DisableCapability(
        capability: Capability,
        scope: OptionalPolicyScope
      )
    | EnableCapability(
        capability: Capability,
        scope: OptionalPolicyScope
      )
    | ModifyRestriction(
        capability: Capability,
        scope: OptionalPolicyScope,
        restriction: Restriction
      )


  // ----------------------------------------------------------
  // EFFECT SCOPE
  // ----------------------------------------------------------

  // Returns the Scope carried by a scoped Policy Effect.
  //
  // The accessor is intentionally partial because some effects do
  // not carry a Scope.
  function PolicyEffectScope(
    scope: OptionalPolicyScope
  ): OptionalPolicyScope
  {
    scope
  }


  // ----------------------------------------------------------
  // VALUE OBJECT SEMANTICS
  // ----------------------------------------------------------

  // PolicyEffect equality is semantic Value Object equality.
  //
  // Since PolicyEffect is a datatype, equality already compares:
  //
  //   - constructor kind;
  //   - all constructor parameters.
  //
  // Therefore two Policy Effects are semantically equal exactly
  // when their complete semantic values are equal.
  predicate SamePolicyEffect(
    left: PolicyEffect,
    right: PolicyEffect
  )
  {
    left == right
  }


  // Same constructor and equal semantic payloads imply equal
  // Policy Effects.
  //
  // Datatype equality supplies the constructor-discrimination and
  // payload-equality semantics.
  lemma PolicyEffectsWithSameValuesAreEqual(
    left: PolicyEffect,
    right: PolicyEffect
  )
    requires SamePolicyEffect(left, right)
    ensures left == right
  {
  }


  // Equal Policy Effects necessarily expose equal semantic values.
  lemma EqualPolicyEffectsHaveEqualValues(
    left: PolicyEffect,
    right: PolicyEffect
  )
    requires left == right
    ensures SamePolicyEffect(left, right)
  {
  }


  // PolicyEffect has no independent identity.
  //
  // In particular, there is no PolicyEffectId.
  lemma PolicyEffectHasNoIndependentIdentity(
    effect: PolicyEffect
  )
    ensures SamePolicyEffect(effect, effect)
  {
  }


  // ----------------------------------------------------------
  // STRUCTURAL VALIDITY
  // ----------------------------------------------------------

  // An Optional Scope payload is valid when its contained Scope is
  // valid. Absence of Scope is structurally valid.
  predicate ValidOptionalPolicyScope(
    scope: OptionalPolicyScope
  )
  {
    match scope
    case NoScope => true
    case Scoped(value) => ValidScope(value)
  }


  // A Policy Effect is structurally valid when all semantic
  // identifiers and value-object payloads it carries are valid.
  //
  // This predicate deliberately does NOT evaluate applicability,
  // consistency, contradiction, or state-transition legality.
  predicate ValidPolicyEffect(
    effect: PolicyEffect
  )
  {
    match effect
    case RevokeCredential(credentialId) =>
      ValidId(credentialId)

    case RevokeSession(sessionId) =>
      ValidId(sessionId)

    case RevokeDelegation(delegationId) =>
      ValidId(delegationId)

    case DisableCapability(capability, scope) =>
      ValidCapability(capability)
      && ValidOptionalPolicyScope(scope)

    case EnableCapability(capability, scope) =>
      ValidCapability(capability)
      && ValidOptionalPolicyScope(scope)

    case ModifyRestriction(capability, scope, restriction) =>
      ValidCapability(capability)
      && ValidOptionalPolicyScope(scope)
      && ValidRestriction(restriction)
  }


  // ----------------------------------------------------------
  // VALIDITY LAWS
  // ----------------------------------------------------------

  // Every valid Policy Effect contains structurally valid
  // semantic payloads.
  lemma ValidPolicyEffectHasValidPayload(
    effect: PolicyEffect
  )
    requires ValidPolicyEffect(effect)
    ensures match effect
            case RevokeCredential(credentialId) =>
              ValidId(credentialId)

            case RevokeSession(sessionId) =>
              ValidId(sessionId)

            case RevokeDelegation(delegationId) =>
              ValidId(delegationId)

            case DisableCapability(capability, scope) =>
              ValidCapability(capability)
              && ValidOptionalPolicyScope(scope)

            case EnableCapability(capability, scope) =>
              ValidCapability(capability)
              && ValidOptionalPolicyScope(scope)

            case ModifyRestriction(capability, scope, restriction) =>
              ValidCapability(capability)
              && ValidOptionalPolicyScope(scope)
              && ValidRestriction(restriction)
  {
  }


  // A valid optional Scope is either absent or structurally valid.
  lemma ValidOptionalPolicyScopeContainsValidScope(
    scope: OptionalPolicyScope
  )
    requires ValidOptionalPolicyScope(scope)
    ensures match scope
            case NoScope => true
            case Scoped(value) => ValidScope(value)
  {
  }


  // ----------------------------------------------------------
  // EFFECT SEMANTIC DISCRIMINATION
  // ----------------------------------------------------------

  // Different Policy Effect constructors are semantically
  // different kinds of state change.
  //
  // In particular, DisableCapability and EnableCapability are not
  // equal merely because they carry the same Capability and Scope.
  lemma DisableAndEnableAreDifferentEffectKinds(
    capability: Capability,
    scope: OptionalPolicyScope
  )
    ensures DisableCapability(capability, scope)
         != EnableCapability(capability, scope)
  {
  }


  // RevokeCredential effects are determined by their CredentialId.
  lemma EqualRevokeCredentialEffectsHaveEqualIds(
    left: PolicyEffect,
    right: PolicyEffect,
    credentialId: Id
  )
    requires left == RevokeCredential(credentialId)
    requires right == RevokeCredential(credentialId)
    ensures left == right
  {
  }


  // ----------------------------------------------------------
  // SEMANTIC BOUNDARY
  // ----------------------------------------------------------

  // PolicyEffect is only a semantic descriptor.
  //
  // Whether the referenced Entity exists, whether the Capability
  // exists in the Account, whether a Restriction can be modified,
  // and whether this Effect is consistent with other Effects are
  // intentionally outside this file.
  //
  // This preserves the separation:
  //
  //     PolicyEffect
  //         =
  //     WHAT change is recognized
  //
  //     AuthorizationStateTransition
  //         =
  //     WHETHER and HOW state may legally change
  //
  lemma ValidPolicyEffectDoesNotImplyApplicability(
    effect: PolicyEffect
  )
    requires ValidPolicyEffect(effect)
    ensures true
  {
  }
}

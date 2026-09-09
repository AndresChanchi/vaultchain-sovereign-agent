// ============================================================
// KIPIO ACCOUNT DOMAIN
// AUTHORIZATION — AUTHORIZATION
// ============================================================
//
// Authorization represents the semantic value of a requested
// exercise of authority through a recognized Credential.
//
// Authorization is a Value Object.
//
// ------------------------------------------------------------
//
// D4 — PROOF AND AUTHORIZATION EQUALITY
//
// Authorization equality is semantic equality.
//
// The complete semantic value of Authorization is:
//
//     ( Credential Reference,
//       Requested Authority,
//       Restrictions,
//       Temporal Conditions,
//       Replay Protection,
//       Context )
//
// Cryptographic Proof is intentionally NOT part of the semantic
// value of Authorization.
//
// Proof is an infrastructure / verification concept.
//
// Therefore:
//
//     Authorization A == Authorization B
//
// depends only on the semantic domain fields above.
//
// Two cryptographically different Proof values may accompany the
// same semantic Authorization and still correspond to the same
// semantic Authorization value.
//
// Conversely, different semantic attributes produce different
// Authorization values regardless of any Proof supplied with them.
//
// Proof verification belongs to AuthorizationValidation and the
// corresponding infrastructure Verifier.
//
// ------------------------------------------------------------
//
// D4 — AUTHORIZATION CONTEXT
//
// Context is part of the semantic value of Authorization.
//
// The Context contains:
//
//     - AccountId;
//     - ExecutionTarget;
//     - DomainAction;
//     - Scope;
//     - Chain.
//
// These values determine the semantic environment and intended
// destination of the Authorization.
//
// Two otherwise identical Authorizations with different Context
// values are therefore semantically different.
//
// In particular:
//
//     Authorization(..., Target A, ...)
//         !=
//     Authorization(..., Target B, ...)
//
// when the ExecutionTarget differs.
//
// Context is a component of Authorization.
//
// It is NOT a separate Entity.
//
// ------------------------------------------------------------
//
// IMPORTANT BOUNDARIES
//
// Authorization does NOT:
//
//   - possess an AuthorizationId;
//   - own a lifecycle;
//   - establish Credential recognition;
//   - establish Effective Authority;
//   - verify Proof;
//   - consume Replay Protection;
//   - evaluate Policy;
//   - perform execution.
//
// In particular:
//
//     Proof validity
//         !=
//     Authorization validity
//
// and:
//
//     Proof
//         !=
//     Authorization semantic identity
//
// Replay Protection remains part of Authorization semantic value.
//
// A replayKey therefore participates in Authorization equality,
// but it is NOT an Entity identifier.
//
// ------------------------------------------------------------
//
// DEPENDENCIES
//
// Authorization depends only on concepts already available before
// the Authorization layer:
//
//   foundation:
//     - DomainPrimitives
//     - Capability
//     - Restriction
//     - Scope
//     - DomainAction
//     - ExecutionTarget
//     - Chain
//
//   authority:
//     - EffectiveAuthority
//
// It intentionally does NOT depend on ExecutionRequest,
// ExecutionContext or other execution-layer concepts.
//
// This preserves the architectural direction:
//
//     foundation
//         ↓
//     authority
//         ↓
//     account
//         ↓
//     authorization
//         ↓
//     execution
//
// ------------------------------------------------------------
//
// This file intentionally contains no:
//
//   - cryptographic Proof type;
//   - Proof verification;
//   - verifier implementation;
//   - replay consumption;
//   - replay state mutation;
//   - authorization validation implementation;
//   - effective authority calculation;
//   - policy evaluation;
//   - execution logic;
//   - blockchain ABI types;
//   - storage representations.
//
// ============================================================

include "../foundation/DomainPrimitives.dfy"
include "../foundation/Capability.dfy"
include "../foundation/Restriction.dfy"
include "../foundation/Scope.dfy"
include "../foundation/DomainAction.dfy"
include "../foundation/ExecutionTarget.dfy"
include "../foundation/Chain.dfy"
include "../authority/EffectiveAuthority.dfy"

module KipioAccountAuthorization
{
  import opened KipioAccountDomainPrimitives
  import opened KipioAccountCapability
  import opened KipioAccountRestriction
  import opened KipioAccountScope
  import opened KipioAccountDomainAction
  import opened KipioAccountExecutionTarget
  import opened KipioAccountChain
  import opened KipioAccountEffectiveAuthority


  // ----------------------------------------------------------
  // REQUESTED AUTHORITY
  // ----------------------------------------------------------

  // Requested Authority represents the authority that an
  // Authorization attempts to exercise.
  //
  // It is a Value Object represented by the set of requested
  // Capabilities.
  //
  // Requested Authority does not grant authority.
  type RequestedAuthority = set<Capability>


  // ----------------------------------------------------------
  // AUTHORIZATION
  // ----------------------------------------------------------

  // Authorization is a Value Object describing the semantic
  // intention to exercise authority through a Credential.
  //
  // The Credential is referenced by CredentialId rather than
  // embedding the Credential Entity.
  //
  // This preserves the Entity boundary:
  //
  //     Authorization
  //          |
  //          └── CredentialId
  //                    |
  //                    v
  //               Credential Entity
  //
  // The semantic Context is part of the Authorization value.
  //
  // The Proof is intentionally absent.
  //
  // Proof belongs to cryptographic infrastructure and is supplied
  // separately during Authorization Validation.
  datatype Authorization =
    Authorization(
      credentialId: Id,
      requestedAuthority: RequestedAuthority,
      restrictions: set<Restriction>,
      validFrom: Timestamp,
      validUntil: Timestamp,
      replayKey: Id,
      accountId: Id,
      executionTarget: ExecutionTarget,
      domainAction: DomainAction,
      scope: Scope,
      chain: Chain
    )


  // ----------------------------------------------------------
  // CONTEXT ACCESSORS
  // ----------------------------------------------------------

  // Returns the AccountId belonging to the semantic Context.
  //
  // AccountId is represented by the foundational Identifier type.
  //
  // This does not establish that the Account exists in a particular
  // AuthorizationState.
  function AuthorizationAccountId(
    authorization: Authorization
  ): Id
  {
    authorization.accountId
  }


  // Returns the ExecutionTarget belonging to the semantic Context.
  //
  // This does not establish that the target is reachable,
  // resolvable or executable.
  function AuthorizationExecutionTarget(
    authorization: Authorization
  ): ExecutionTarget
  {
    authorization.executionTarget
  }


  // Returns the application-defined DomainAction belonging to the
  // semantic Context.
  //
  // Kipio does not interpret the internal meaning of DomainAction.
  function AuthorizationDomainAction(
    authorization: Authorization
  ): DomainAction
  {
    authorization.domainAction
  }


  // Returns the Scope belonging to the semantic Context.
  //
  // This Scope represents the semantic action context and remains
  // distinct from ExecutionTarget.
  function AuthorizationScope(
    authorization: Authorization
  ): Scope
  {
    authorization.scope
  }


  // Returns the Chain belonging to the semantic Context.
  //
  // Chain is an opaque Value Object at the domain foundation layer.
  function AuthorizationChain(
    authorization: Authorization
  ): Chain
  {
    authorization.chain
  }


  // ----------------------------------------------------------
  // CREDENTIAL ACCESSOR
  // ----------------------------------------------------------

  // Returns the CredentialId referenced by the Authorization.
  //
  // This does not establish that the Credential is recognized by
  // a particular Account.
  function AuthorizationCredentialId(
    authorization: Authorization
  ): Id
  {
    authorization.credentialId
  }


  // ----------------------------------------------------------
  // REQUESTED AUTHORITY ACCESSORS
  // ----------------------------------------------------------

  // Returns the authority requested by the Authorization.
  //
  // Requested Authority is a semantic value and does not itself
  // grant authority.
  function AuthorizationRequestedAuthority(
    authorization: Authorization
  ): RequestedAuthority
  {
    authorization.requestedAuthority
  }


  // Determines whether the Authorization requests a particular
  // Capability.
  predicate AuthorizationRequestsCapability(
    authorization: Authorization,
    capability: Capability
  )
  {
    capability in AuthorizationRequestedAuthority(authorization)
  }


  // ----------------------------------------------------------
  // RESTRICTION ACCESSORS
  // ----------------------------------------------------------

  // Returns the Restrictions carried by the Authorization.
  function AuthorizationRestrictions(
    authorization: Authorization
  ): set<Restriction>
  {
    authorization.restrictions
  }


  // Determines whether an Authorization carries a particular
  // Restriction.
  predicate AuthorizationContainsRestriction(
    authorization: Authorization,
    restriction: Restriction
  )
  {
    restriction in AuthorizationRestrictions(authorization)
  }


  // ----------------------------------------------------------
  // TEMPORAL ACCESSORS
  // ----------------------------------------------------------

  // Returns the beginning of the Authorization validity interval.
  //
  // The existence of an interval does not imply current temporal
  // validity. That is evaluated by Authorization Validation.
  function AuthorizationValidFrom(
    authorization: Authorization
  ): Timestamp
  {
    authorization.validFrom
  }


  // Returns the end of the Authorization validity interval.
  function AuthorizationValidUntil(
    authorization: Authorization
  ): Timestamp
  {
    authorization.validUntil
  }


  // ----------------------------------------------------------
  // REPLAY ACCESSOR
  // ----------------------------------------------------------

  // Returns the Replay Protection value carried by the
  // Authorization.
  //
  // replayKey participates in semantic Authorization equality.
  //
  // It is NOT an AuthorizationId and does not establish Entity
  // identity.
  function AuthorizationReplayKey(
    authorization: Authorization
  ): Id
  {
    authorization.replayKey
  }


  // ----------------------------------------------------------
  // VALUE OBJECT SEMANTICS
  // ----------------------------------------------------------

  // Authorization has no independent identity.
  //
  // Its complete semantic value is determined by:
  //
  //   - Credential reference;
  //   - Requested Authority;
  //   - Restrictions;
  //   - validity interval;
  //   - Replay Protection;
  //   - AccountId;
  //   - ExecutionTarget;
  //   - DomainAction;
  //   - Scope;
  //   - Chain.
  //
  // Since Proof is not a semantic component of the datatype,
  // native Dafny equality corresponds directly to semantic
  // Authorization equality.
  //
  // No SameAuthorization predicate is introduced.


  // Two Authorizations with equal semantic values are equal.
  //
  // This proves that all semantic components completely determine
  // the Value Object.
  lemma AuthorizationsWithEqualSemanticValuesAreEqual(
    left: Authorization,
    right: Authorization
  )
    requires left.credentialId == right.credentialId
    requires left.requestedAuthority == right.requestedAuthority
    requires left.restrictions == right.restrictions
    requires left.validFrom == right.validFrom
    requires left.validUntil == right.validUntil
    requires left.replayKey == right.replayKey
    requires left.accountId == right.accountId
    requires left.executionTarget == right.executionTarget
    requires left.domainAction == right.domainAction
    requires left.scope == right.scope
    requires left.chain == right.chain
    ensures left == right
  {
  }


  // ----------------------------------------------------------
  // EQUALITY PROJECTION — CREDENTIAL
  // ----------------------------------------------------------

  lemma EqualAuthorizationsHaveEqualCredentialIds(
    left: Authorization,
    right: Authorization
  )
    requires left == right
    ensures AuthorizationCredentialId(left)
         == AuthorizationCredentialId(right)
  {
  }


  // ----------------------------------------------------------
  // EQUALITY PROJECTION — REQUESTED AUTHORITY
  // ----------------------------------------------------------

  lemma EqualAuthorizationsHaveEqualRequestedAuthority(
    left: Authorization,
    right: Authorization
  )
    requires left == right
    ensures AuthorizationRequestedAuthority(left)
         == AuthorizationRequestedAuthority(right)
  {
  }


  // ----------------------------------------------------------
  // EQUALITY PROJECTION — RESTRICTIONS
  // ----------------------------------------------------------

  lemma EqualAuthorizationsHaveEqualRestrictions(
    left: Authorization,
    right: Authorization
  )
    requires left == right
    ensures AuthorizationRestrictions(left)
         == AuthorizationRestrictions(right)
  {
  }


  // ----------------------------------------------------------
  // EQUALITY PROJECTION — TEMPORAL CONDITIONS
  // ----------------------------------------------------------

  lemma EqualAuthorizationsHaveEqualValidityInterval(
    left: Authorization,
    right: Authorization
  )
    requires left == right
    ensures AuthorizationValidFrom(left)
         == AuthorizationValidFrom(right)
    ensures AuthorizationValidUntil(left)
         == AuthorizationValidUntil(right)
  {
  }


  // ----------------------------------------------------------
  // EQUALITY PROJECTION — REPLAY PROTECTION
  // ----------------------------------------------------------

  lemma EqualAuthorizationsHaveEqualReplayKeys(
    left: Authorization,
    right: Authorization
  )
    requires left == right
    ensures AuthorizationReplayKey(left)
         == AuthorizationReplayKey(right)
  {
  }


  // ----------------------------------------------------------
  // EQUALITY PROJECTION — CONTEXT
  // ----------------------------------------------------------

  // Equal Authorizations necessarily refer to the same Account
  // Context.
  lemma EqualAuthorizationsHaveEqualAccountIds(
    left: Authorization,
    right: Authorization
  )
    requires left == right
    ensures AuthorizationAccountId(left)
         == AuthorizationAccountId(right)
  {
  }


  // Equal Authorizations necessarily contain equal
  // ExecutionTargets.
  lemma EqualAuthorizationsHaveEqualExecutionTargets(
    left: Authorization,
    right: Authorization
  )
    requires left == right
    ensures AuthorizationExecutionTarget(left)
         == AuthorizationExecutionTarget(right)
  {
  }


  // Equal Authorizations necessarily contain equal DomainActions.
  lemma EqualAuthorizationsHaveEqualDomainActions(
    left: Authorization,
    right: Authorization
  )
    requires left == right
    ensures AuthorizationDomainAction(left)
         == AuthorizationDomainAction(right)
  {
  }


  // Equal Authorizations necessarily contain equal Context Scopes.
  lemma EqualAuthorizationsHaveEqualScopes(
    left: Authorization,
    right: Authorization
  )
    requires left == right
    ensures AuthorizationScope(left)
         == AuthorizationScope(right)
  {
  }


  // Equal Authorizations necessarily contain equal Chain values.
  lemma EqualAuthorizationsHaveEqualChains(
    left: Authorization,
    right: Authorization
  )
    requires left == right
    ensures AuthorizationChain(left)
         == AuthorizationChain(right)
  {
  }


  // ----------------------------------------------------------
  // REQUESTED AUTHORITY VALUE SEMANTICS
  // ----------------------------------------------------------

  // Requested Authority is a Value Object represented directly
  // by its Capability set.
  //
  // Native set equality therefore represents semantic equality.
  lemma RequestedAuthoritiesWithSameValuesAreEqual(
    left: RequestedAuthority,
    right: RequestedAuthority
  )
    requires left == right
    ensures left == right
  {
  }


  // ----------------------------------------------------------
  // STRUCTURAL VALIDITY
  // ----------------------------------------------------------

  // A valid Requested Authority contains only valid Capabilities.
  predicate ValidRequestedAuthority(
    authority: RequestedAuthority
  )
  {
    forall capability ::
      capability in authority
      ==> ValidCapability(capability)
  }


  // A valid Authorization contains:
  //
  //   - a valid Credential reference;
  //   - only valid requested Capabilities;
  //   - only valid Restrictions;
  //   - an ordered validity interval;
  //   - a valid Replay Protection value;
  //   - a valid AccountId;
  //   - a valid Scope.
  //
  // DomainAction, ExecutionTarget and Chain are opaque foundation
  // Value Objects and therefore have no domain-level structural
  // validity predicate here.
  //
  // Cryptographic Proof is intentionally absent because Proof
  // validity belongs to infrastructure / Authorization Validation.
  predicate ValidAuthorization(
    authorization: Authorization
  )
  {
    ValidId(
      AuthorizationCredentialId(authorization)
    )
    && ValidRequestedAuthority(
      AuthorizationRequestedAuthority(authorization)
    )
    && (forall restriction ::
          restriction in AuthorizationRestrictions(authorization)
          ==> ValidRestriction(restriction))
    && AuthorizationValidFrom(authorization)
       <= AuthorizationValidUntil(authorization)
    && ValidId(
      AuthorizationReplayKey(authorization)
    )
    && ValidId(
      AuthorizationAccountId(authorization)
    )
    && ValidScope(
      AuthorizationScope(authorization)
    )
  }


  // A valid Authorization contains only valid requested
  // Capabilities.
  lemma ValidAuthorizationHasValidRequestedCapabilities(
    authorization: Authorization,
    capability: Capability
  )
    requires ValidAuthorization(authorization)
    requires AuthorizationRequestsCapability(
               authorization,
               capability
             )
    ensures ValidCapability(capability)
  {
  }


  // A valid Authorization contains only valid Restrictions.
  lemma ValidAuthorizationHasValidRestriction(
    authorization: Authorization,
    restriction: Restriction
  )
    requires ValidAuthorization(authorization)
    requires AuthorizationContainsRestriction(
               authorization,
               restriction
             )
    ensures ValidRestriction(restriction)
  {
  }


  // A valid Authorization has an ordered validity interval.
  lemma ValidAuthorizationHasValidInterval(
    authorization: Authorization
  )
    requires ValidAuthorization(authorization)
    ensures AuthorizationValidFrom(authorization)
         <= AuthorizationValidUntil(authorization)
  {
  }


  // A valid Authorization has a valid Replay Protection value.
  //
  // This does not establish freshness or non-consumption.
  //
  // Freshness belongs to Replay semantics and state.
  lemma ValidAuthorizationHasValidReplayKey(
    authorization: Authorization
  )
    requires ValidAuthorization(authorization)
    ensures ValidId(
              AuthorizationReplayKey(authorization)
            )
  {
  }


  // A valid Authorization contains a structurally valid AccountId.
  lemma ValidAuthorizationHasValidAccountId(
    authorization: Authorization
  )
    requires ValidAuthorization(authorization)
    ensures ValidId(
              AuthorizationAccountId(authorization)
            )
  {
  }


  // A valid Authorization contains a structurally valid Context
  // Scope.
  lemma ValidAuthorizationHasValidContextScope(
    authorization: Authorization
  )
    requires ValidAuthorization(authorization)
    ensures ValidScope(
              AuthorizationScope(authorization)
            )
  {
  }


  // ----------------------------------------------------------
  // AUTHORITY BOUNDARY
  // ----------------------------------------------------------

  // Requested Authority is bounded by the Effective Authority
  // applicable in the Authorization context.
  //
  // This is a semantic relation used by Authorization Validation.
  //
  // It does NOT make Authorization itself valid and does not
  // calculate Effective Authority.
  predicate RequestedAuthorityWithinEffectiveAuthority(
    authorization: Authorization,
    effectiveAuthority: EffectiveAuthority
  )
  {
    AuthorizationRequestedAuthority(authorization)
    <= effectiveAuthority
  }


  // An Authorization cannot request a Capability outside its
  // applicable Effective Authority.
  lemma AuthorizationCannotExceedEffectiveAuthority(
    authorization: Authorization,
    effectiveAuthority: EffectiveAuthority,
    capability: Capability
  )
    requires RequestedAuthorityWithinEffectiveAuthority(
               authorization,
               effectiveAuthority
             )
    requires AuthorizationRequestsCapability(
               authorization,
               capability
             )
    ensures CapabilityIsEffective(
              effectiveAuthority,
              capability
            )
  {
  }


  // ----------------------------------------------------------
  // AUTHORIZATION / AUTHENTICATION BOUNDARY
  // ----------------------------------------------------------

  // Structural Authorization validity does not imply Proof
  // validity.
  //
  // Proof verification belongs to the corresponding Verifier
  // infrastructure and is intentionally absent here.
  //
  // The Proof is supplied separately by the validation layer.
  lemma ValidAuthorizationDoesNotImplyProofValidity(
    authorization: Authorization
  )
    requires ValidAuthorization(authorization)
    ensures true
  {
  }


  // Structural Authorization validity does not imply current
  // temporal validity.
  //
  // The interval is structurally well formed, but its current
  // applicability requires an explicit evaluation timestamp.
  lemma ValidAuthorizationDoesNotImplyCurrentTemporalValidity(
    authorization: Authorization
  )
    requires ValidAuthorization(authorization)
    ensures true
  {
  }


  // Structural Authorization validity does not imply Replay
  // freshness.
  //
  // Freshness depends on Replay Protection state.
  lemma ValidAuthorizationDoesNotImplyReplayFreshness(
    authorization: Authorization
  )
    requires ValidAuthorization(authorization)
    ensures true
  {
  }


  // ----------------------------------------------------------
  // CONTEXT SEMANTIC SEPARATION
  // ----------------------------------------------------------

  // The semantic Context is part of Authorization itself.
  //
  // Therefore two Authorizations with different AccountId values
  // are different semantic values when all other fields are equal.
  lemma DifferentAccountIdsProduceDifferentAuthorizations(
    credentialId: Id,
    requestedAuthority: RequestedAuthority,
    restrictions: set<Restriction>,
    validFrom: Timestamp,
    validUntil: Timestamp,
    replayKey: Id,
    firstAccountId: Id,
    secondAccountId: Id,
    executionTarget: ExecutionTarget,
    domainAction: DomainAction,
    scope: Scope,
    chain: Chain
  )
    requires firstAccountId != secondAccountId
    ensures Authorization(
              credentialId,
              requestedAuthority,
              restrictions,
              validFrom,
              validUntil,
              replayKey,
              firstAccountId,
              executionTarget,
              domainAction,
              scope,
              chain
            )
            !=
            Authorization(
              credentialId,
              requestedAuthority,
              restrictions,
              validFrom,
              validUntil,
              replayKey,
              secondAccountId,
              executionTarget,
              domainAction,
              scope,
              chain
            )
  {
  }


  // Different ExecutionTargets produce different Authorization
  // values when all other semantic fields are equal.
  lemma DifferentExecutionTargetsProduceDifferentAuthorizations(
    credentialId: Id,
    requestedAuthority: RequestedAuthority,
    restrictions: set<Restriction>,
    validFrom: Timestamp,
    validUntil: Timestamp,
    replayKey: Id,
    accountId: Id,
    firstExecutionTarget: ExecutionTarget,
    secondExecutionTarget: ExecutionTarget,
    domainAction: DomainAction,
    scope: Scope,
    chain: Chain
  )
    requires firstExecutionTarget != secondExecutionTarget
    ensures Authorization(
              credentialId,
              requestedAuthority,
              restrictions,
              validFrom,
              validUntil,
              replayKey,
              accountId,
              firstExecutionTarget,
              domainAction,
              scope,
              chain
            )
            !=
            Authorization(
              credentialId,
              requestedAuthority,
              restrictions,
              validFrom,
              validUntil,
              replayKey,
              accountId,
              secondExecutionTarget,
              domainAction,
              scope,
              chain
            )
  {
  }


  // Different DomainActions produce different Authorization values
  // when all other semantic fields are equal.
  lemma DifferentDomainActionsProduceDifferentAuthorizations(
    credentialId: Id,
    requestedAuthority: RequestedAuthority,
    restrictions: set<Restriction>,
    validFrom: Timestamp,
    validUntil: Timestamp,
    replayKey: Id,
    accountId: Id,
    executionTarget: ExecutionTarget,
    firstDomainAction: DomainAction,
    secondDomainAction: DomainAction,
    scope: Scope,
    chain: Chain
  )
    requires firstDomainAction != secondDomainAction
    ensures Authorization(
              credentialId,
              requestedAuthority,
              restrictions,
              validFrom,
              validUntil,
              replayKey,
              accountId,
              executionTarget,
              firstDomainAction,
              scope,
              chain
            )
            !=
            Authorization(
              credentialId,
              requestedAuthority,
              restrictions,
              validFrom,
              validUntil,
              replayKey,
              accountId,
              executionTarget,
              secondDomainAction,
              scope,
              chain
            )
  {
  }


  // Different Context Scopes produce different Authorization
  // values when all other semantic fields are equal.
  lemma DifferentScopesProduceDifferentAuthorizations(
    credentialId: Id,
    requestedAuthority: RequestedAuthority,
    restrictions: set<Restriction>,
    validFrom: Timestamp,
    validUntil: Timestamp,
    replayKey: Id,
    accountId: Id,
    executionTarget: ExecutionTarget,
    domainAction: DomainAction,
    firstScope: Scope,
    secondScope: Scope,
    chain: Chain
  )
    requires firstScope != secondScope
    ensures Authorization(
              credentialId,
              requestedAuthority,
              restrictions,
              validFrom,
              validUntil,
              replayKey,
              accountId,
              executionTarget,
              domainAction,
              firstScope,
              chain
            )
            !=
            Authorization(
              credentialId,
              requestedAuthority,
              restrictions,
              validFrom,
              validUntil,
              replayKey,
              accountId,
              executionTarget,
              domainAction,
              secondScope,
              chain
            )
  {
  }


  // Different Chain values produce different Authorization values
  // when all other semantic fields are equal.
  lemma DifferentChainsProduceDifferentAuthorizations(
    credentialId: Id,
    requestedAuthority: RequestedAuthority,
    restrictions: set<Restriction>,
    validFrom: Timestamp,
    validUntil: Timestamp,
    replayKey: Id,
    accountId: Id,
    executionTarget: ExecutionTarget,
    domainAction: DomainAction,
    scope: Scope,
    firstChain: Chain,
    secondChain: Chain
  )
    requires firstChain != secondChain
    ensures Authorization(
              credentialId,
              requestedAuthority,
              restrictions,
              validFrom,
              validUntil,
              replayKey,
              accountId,
              executionTarget,
              domainAction,
              scope,
              firstChain
            )
            !=
            Authorization(
              credentialId,
              requestedAuthority,
              restrictions,
              validFrom,
              validUntil,
              replayKey,
              accountId,
              executionTarget,
              domainAction,
              scope,
              secondChain
            )
  {
  }


  // ----------------------------------------------------------
  // REPLAY PROTECTION SEMANTICS
  // ----------------------------------------------------------

  // Different Replay Protection values produce different
  // Authorization values when all other semantic fields are equal.
  //
  // Replay Protection is therefore part of semantic Authorization
  // equality, but does not acquire Entity semantics.
  lemma DifferentReplayKeysProduceDifferentAuthorizations(
    credentialId: Id,
    requestedAuthority: RequestedAuthority,
    restrictions: set<Restriction>,
    validFrom: Timestamp,
    validUntil: Timestamp,
    firstReplayKey: Id,
    secondReplayKey: Id,
    accountId: Id,
    executionTarget: ExecutionTarget,
    domainAction: DomainAction,
    scope: Scope,
    chain: Chain
  )
    requires firstReplayKey != secondReplayKey
    ensures Authorization(
              credentialId,
              requestedAuthority,
              restrictions,
              validFrom,
              validUntil,
              firstReplayKey,
              accountId,
              executionTarget,
              domainAction,
              scope,
              chain
            )
            !=
            Authorization(
              credentialId,
              requestedAuthority,
              restrictions,
              validFrom,
              validUntil,
              secondReplayKey,
              accountId,
              executionTarget,
              domainAction,
              scope,
              chain
            )
  {
  }
}

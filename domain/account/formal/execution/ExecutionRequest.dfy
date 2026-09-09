// ============================================================
// KIPIO ACCOUNT DOMAIN
// EXECUTION — EXECUTION REQUEST
// ============================================================
//
// ExecutionRequest represents a request to materialize a
// DomainAction under a previously defined Authorization and
// execution-specific conditions.
//
// ExecutionRequest is a Value Object.
//
// ------------------------------------------------------------
//
// DOMAIN BOUNDARY
//
// ExecutionRequest does NOT:
//
//   - determine whether Authorization is valid;
//   - calculate Effective Authority;
//   - verify Proof;
//   - consume Replay Protection;
//   - evaluate Policy;
//   - decide whether execution is permitted;
//   - materialize an Execution;
//   - define business semantics of DomainAction;
//   - define infrastructure-specific target semantics;
//   - define blockchain transaction semantics.
//
// Those responsibilities belong to the corresponding
// authorization, runtime and execution layers.
//
// ------------------------------------------------------------
//
// VALUE OBJECT SEMANTICS
//
// ExecutionRequest has no independent identity.
//
// There is intentionally NO:
//
//   - ExecutionRequestId;
//   - RequestId;
//   - Entity lifecycle;
//   - persistent Entity identity.
//
// Its meaning is determined by the values it contains.
//
// ------------------------------------------------------------
//
// CONCEPTUAL COMPOSITION
//
//     ExecutionRequest
//          │
//          ├── DomainAction
//          │       └── opaque foundation Value Object
//          │
//          ├── Authorization
//          │       └── authorization semantic value
//          │
//          ├── ExecutionTarget
//          │       └── opaque foundation Value Object
//          │
//          └── ExecutionConstraints
//                  └── materialization conditions
//
// ------------------------------------------------------------
//
// IMPORTANT DISTINCTIONS
//
//     DomainAction
//         != Capability
//
//     Authorization
//         != EffectiveAuthority
//
//     Capability Scope
//         != ExecutionTarget
//
//     ExecutionConstraints
//         != Restriction
//
//     ExecutionRequest
//         != ExecutionContext
//
//     ExecutionRequest
//         != Execution
//
// ExecutionRequest expresses:
//
//     "what is requested for materialization
//      under which Authorization and target"
//
// ExecutionContext expresses:
//
//     "what has already been validated and may be materialized"
//
// ------------------------------------------------------------
//
// AUTHORIZATION CONTEXT CONSISTENCY
//
// Authorization contains semantic execution context including:
//
//   - AccountId;
//   - ExecutionTarget;
//   - DomainAction;
//   - Scope;
//   - Chain.
//
// ExecutionRequest independently carries:
//
//   - DomainAction;
//   - ExecutionTarget.
//
// Therefore a valid ExecutionRequest must not combine values that
// contradict the semantic context of its Authorization.
//
// In particular:
//
//     ExecutionRequestAction(request)
//         ==
//     AuthorizationDomainAction(
//         ExecutionRequestAuthorization(request)
//     )
//
// and:
//
//     ExecutionRequestTarget(request)
//         ==
//     AuthorizationExecutionTarget(
//         ExecutionRequestAuthorization(request)
//     )
//
// This is a consistency relation only.
//
// It does NOT:
//
//   - validate Authorization;
//   - establish authority;
//   - establish Proof validity;
//   - calculate EffectiveAuthority.
//
// ------------------------------------------------------------
//
// EXECUTION TARGET
//
// ExecutionTarget is defined canonically in:
//
//     foundation/ExecutionTarget.dfy
//
// It is consumed here as an opaque Value Object.
//
// The current DDD does not define an internal algebra,
// identifier, lifecycle, or infrastructure representation for
// ExecutionTarget.
//
// ------------------------------------------------------------
//
// EXECUTION CONSTRAINTS
//
// ExecutionConstraints are supplied independently from
// Authorization Restrictions.
//
// Restriction limits authority.
//
// ExecutionConstraints condition materialization of an already
// authorized decision.
//
// They therefore remain separate concepts.
//
// ------------------------------------------------------------
//
// VALIDITY BOUNDARY
//
// This module establishes:
//
//   - Authorization structural validity;
//   - consistency between the request's DomainAction and the
//     Authorization Context DomainAction;
//   - consistency between the request's ExecutionTarget and the
//     Authorization Context ExecutionTarget.
//
// DomainAction, ExecutionTarget and ExecutionConstraints remain
// opaque Value Objects at this layer.
//
// No action-specific, target-specific or infrastructure-specific
// validity rules are invented here.
//
// ------------------------------------------------------------
//
// RESPONSIBILITY BOUNDARY
//
// This file defines:
//
//   - ExecutionRequest as a Value Object;
//   - accessors;
//   - request / authorization context consistency;
//   - structural request validity;
//
// This file intentionally does NOT define:
//
//   - authorization validation;
//   - Effective Authority calculation;
//   - Proof verification;
//   - replay consumption;
//   - target resolution;
//   - constraint satisfaction;
//   - runtime orchestration;
//   - execution materialization;
//   - adapter behavior;
//   - blockchain ABI representation.
// ============================================================

include "../authorization/Authorization.dfy"
include "../foundation/DomainAction.dfy"
include "../foundation/ExecutionTarget.dfy"
include "ExecutionConstraints.dfy"

module KipioAccountExecutionRequest
{
  import opened KipioAccountAuthorization
  import opened KipioAccountDomainAction
  import opened KipioAccountExecutionTarget
  import opened KipioAccountExecutionConstraints


  // ----------------------------------------------------------
  // EXECUTION REQUEST
  // ----------------------------------------------------------

  // ExecutionRequest is a Value Object representing an intention
  // to materialize a DomainAction under an Authorization, Target
  // and execution-specific Constraints.
  //
  // The DomainAction and ExecutionTarget carried directly by the
  // request must remain consistent with the corresponding semantic
  // context carried by its Authorization.
  //
  // It is a request value, not an Execution Entity.
  datatype ExecutionRequest =
    ExecutionRequest(
      action: DomainAction,
      authorization: Authorization,
      target: ExecutionTarget,
      constraints: ExecutionConstraints
    )


  // ----------------------------------------------------------
  // ACCESSORS
  // ----------------------------------------------------------

  // Returns the application-defined DomainAction requested for
  // materialization.
  function ExecutionRequestAction(
    request: ExecutionRequest
  ): DomainAction
  {
    request.action
  }


  // Returns the Authorization associated with the request.
  //
  // This does not validate the Authorization.
  function ExecutionRequestAuthorization(
    request: ExecutionRequest
  ): Authorization
  {
    request.authorization
  }


  // Returns the technical ExecutionTarget.
  //
  // This does not establish that the target is valid, reachable
  // or executable.
  function ExecutionRequestTarget(
    request: ExecutionRequest
  ): ExecutionTarget
  {
    request.target
  }


  // Returns the materialization constraints associated with the
  // request.
  function ExecutionRequestConstraints(
    request: ExecutionRequest
  ): ExecutionConstraints
  {
    request.constraints
  }


  // ----------------------------------------------------------
  // AUTHORIZATION CONTEXT CONSISTENCY
  // ----------------------------------------------------------

  // Determines whether the DomainAction requested by the
  // ExecutionRequest is the same DomainAction represented by the
  // Authorization semantic context.
  //
  // This is a consistency relation between two values already
  // supplied to the request.
  //
  // It does not validate Authorization or create authority.
  predicate ExecutionRequestActionMatchesAuthorization(
    request: ExecutionRequest
  )
  {
    ExecutionRequestAction(request)
    ==
    AuthorizationDomainAction(
      ExecutionRequestAuthorization(request)
    )
  }


  // Determines whether the ExecutionTarget requested by the
  // ExecutionRequest is the same ExecutionTarget represented by
  // the Authorization semantic context.
  //
  // This is a consistency relation only.
  predicate ExecutionRequestTargetMatchesAuthorization(
    request: ExecutionRequest
  )
  {
    ExecutionRequestTarget(request)
    ==
    AuthorizationExecutionTarget(
      ExecutionRequestAuthorization(request)
    )
  }


  // Determines whether all duplicated semantic context carried by
  // the ExecutionRequest is consistent with its Authorization.
  //
  // The request duplicates DomainAction and ExecutionTarget so that
  // the execution-facing request remains explicit.
  //
  // Both values must therefore agree with the Authorization context.
  predicate ExecutionRequestAuthorizationContextIsConsistent(
    request: ExecutionRequest
  )
  {
    ExecutionRequestActionMatchesAuthorization(request)
    &&
    ExecutionRequestTargetMatchesAuthorization(request)
  }


  // ----------------------------------------------------------
  // STRUCTURAL REQUEST VALIDITY
  // ----------------------------------------------------------

  // A valid ExecutionRequest contains:
  //
  //   - a structurally valid Authorization;
  //   - a DomainAction consistent with the Authorization Context;
  //   - an ExecutionTarget consistent with the Authorization
  //     Context.
  //
  // DomainAction, ExecutionTarget and ExecutionConstraints remain
  // opaque Value Objects at this layer.
  //
  // Their internal business / infrastructure semantics are not
  // invented here.
  predicate ValidExecutionRequest(
    request: ExecutionRequest
  )
  {
    ValidAuthorization(
      ExecutionRequestAuthorization(request)
    )
    &&
    ExecutionRequestAuthorizationContextIsConsistent(request)
  }


  // ----------------------------------------------------------
  // REQUEST VALIDITY LAWS
  // ----------------------------------------------------------

  // A valid ExecutionRequest contains a structurally valid
  // Authorization.
  lemma ValidExecutionRequestHasValidAuthorization(
    request: ExecutionRequest
  )
    requires ValidExecutionRequest(request)
    ensures ValidAuthorization(
              ExecutionRequestAuthorization(request)
            )
  {
  }


  // A valid ExecutionRequest uses the same DomainAction represented
  // by its Authorization semantic context.
  lemma ValidExecutionRequestHasMatchingDomainAction(
    request: ExecutionRequest
  )
    requires ValidExecutionRequest(request)
    ensures ExecutionRequestAction(request)
            ==
            AuthorizationDomainAction(
              ExecutionRequestAuthorization(request)
            )
  {
  }


  // A valid ExecutionRequest uses the same ExecutionTarget
  // represented by its Authorization semantic context.
  lemma ValidExecutionRequestHasMatchingExecutionTarget(
    request: ExecutionRequest
  )
    requires ValidExecutionRequest(request)
    ensures ExecutionRequestTarget(request)
            ==
            AuthorizationExecutionTarget(
              ExecutionRequestAuthorization(request)
            )
  {
  }


  // A valid ExecutionRequest has an internally consistent
  // Authorization context.
  lemma ValidExecutionRequestHasConsistentAuthorizationContext(
    request: ExecutionRequest
  )
    requires ValidExecutionRequest(request)
    ensures ExecutionRequestAuthorizationContextIsConsistent(request)
  {
  }


  // ----------------------------------------------------------
  // VALUE OBJECT SEMANTICS
  // ----------------------------------------------------------

  // ExecutionRequest has no independent identity.
  //
  // Native Dafny equality represents equality of the complete
  // request value supplied to this module.
  //
  // This includes:
  //
  //   - DomainAction;
  //   - Authorization;
  //   - ExecutionTarget;
  //   - ExecutionConstraints.
  //
  // No SameExecutionRequest predicate is introduced.

  lemma EqualExecutionRequestsHaveEqualActions(
    left: ExecutionRequest,
    right: ExecutionRequest
  )
    requires left == right
    ensures ExecutionRequestAction(left)
         == ExecutionRequestAction(right)
  {
  }


  lemma EqualExecutionRequestsHaveEqualAuthorizations(
    left: ExecutionRequest,
    right: ExecutionRequest
  )
    requires left == right
    ensures ExecutionRequestAuthorization(left)
         == ExecutionRequestAuthorization(right)
  {
  }


  lemma EqualExecutionRequestsHaveEqualTargets(
    left: ExecutionRequest,
    right: ExecutionRequest
  )
    requires left == right
    ensures ExecutionRequestTarget(left)
         == ExecutionRequestTarget(right)
  {
  }


  lemma EqualExecutionRequestsHaveEqualConstraints(
    left: ExecutionRequest,
    right: ExecutionRequest
  )
    requires left == right
    ensures ExecutionRequestConstraints(left)
         == ExecutionRequestConstraints(right)
  {
  }


  // ----------------------------------------------------------
  // AUTHORIZATION / EXECUTION BOUNDARY
  // ----------------------------------------------------------

  // An ExecutionRequest does not itself establish that the
  // requested Authorization is accepted.
  //
  // Authorization Validation remains responsible for determining
  // whether the Authorization may be accepted in its Account state
  // and evaluation context.
  lemma ExecutionRequestDoesNotImplyAuthorizationAcceptance(
    request: ExecutionRequest
  )
    ensures true
  {
  }


  // An ExecutionRequest does not itself create Effective Authority.
  //
  // Effective Authority belongs to the authorization layer.
  lemma ExecutionRequestDoesNotCreateEffectiveAuthority(
    request: ExecutionRequest
  )
    ensures true
  {
  }


  // An ExecutionRequest does not constitute a materialized
  // Execution.
  //
  // Runtime / ExecutionSemantics / ExecutionEngine remain
  // responsible for the materialization process.
  lemma ExecutionRequestIsNotExecution(
    request: ExecutionRequest
  )
    ensures true
  {
  }


  // ----------------------------------------------------------
  // TARGET / SCOPE BOUNDARY
  // ----------------------------------------------------------

  // ExecutionTarget is not an authority Scope.
  //
  // Scope belongs to Capability semantics and describes where
  // authority exists.
  //
  // ExecutionTarget describes where a previously authorized
  // decision is technically materialized.
  lemma ExecutionTargetDoesNotDefineAuthorityScope(
    target: ExecutionTarget
  )
    ensures true
  {
  }


  // ----------------------------------------------------------
  // CONSTRAINT / RESTRICTION BOUNDARY
  // ----------------------------------------------------------

  // ExecutionConstraints do not replace Authorization Restrictions.
  //
  // Restrictions participate in authority evaluation.
  // ExecutionConstraints condition materialization after the
  // authorization decision.
  lemma ExecutionConstraintsDoNotReplaceAuthorizationRestrictions(
    request: ExecutionRequest
  )
    ensures true
  {
  }
}

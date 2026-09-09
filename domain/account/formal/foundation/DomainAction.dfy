// ============================================================
// KIPIO ACCOUNT DOMAIN
// EXECUTION — DOMAIN ACTION
// ============================================================
//
// DomainAction represents an application-defined intention that
// may require authorization and may later be materialized as an
// execution.
//
// ------------------------------------------------------------
//
// DOMAIN BOUNDARY
//
// DomainAction belongs semantically to the bounded context that
// consumes Kipio Account.
//
// Kipio Account does NOT define:
//
//   - the business meaning of an action;
//   - an action catalog;
//   - an action lifecycle;
//   - an action-specific identifier;
//   - contract call semantics;
//   - execution target semantics;
//   - blockchain transaction semantics;
//   - business validation rules.
//
// Kipio only carries the action as an opaque Value Object through
// the authorization / execution flow.
//
// ------------------------------------------------------------
//
// VALUE OBJECT SEMANTICS
//
// DomainAction is a Value Object.
//
// Therefore:
//
//     DomainAction A == DomainAction B
//
// means that the two values represent the same action value as
// defined by the consuming bounded context.
//
// There is intentionally NO:
//
//   - DomainActionId;
//   - ActionId;
//   - Entity identity;
//   - lifecycle state;
//   - artificial identifier.
//
// The Account domain does not impose an internal structure on the
// action because its semantic meaning belongs externally.
//
// ------------------------------------------------------------
//
// IMPORTANT DISTINCTIONS
//
//     DomainAction
//         != Capability
//
//     DomainAction
//         != Authorization
//
//     DomainAction
//         != ExecutionTarget
//
//     DomainAction
//         != Execution
//
// A DomainAction represents:
//
//     WHAT the consuming application intends to do.
//
// Authorization determines:
//
//     WHETHER the required authority exists.
//
// Execution Target determines:
//
//     WHERE execution is technically materialized.
//
// Execution determines:
//
//     HOW that validated intention is materialized.
//
// ------------------------------------------------------------
//
// DEPENDENCY BOUNDARY
//
// DomainAction intentionally has no dependencies on:
//
//   - foundation concepts;
//   - authority;
//   - authorization;
//   - account;
//   - policy;
//   - infrastructure.
//
// This preserves the dependency direction:
//
//     DomainAction
//         ↓
//     ExecutionRequest
//         ↓
//     ExecutionContext
//         ↓
//     ExecutionSemantics
//
// and prevents the generic execution intention from becoming
// coupled to Account-specific authorization structures.
//
// ============================================================

module KipioAccountDomainAction
{
  // ----------------------------------------------------------
  // DOMAIN ACTION
  // ----------------------------------------------------------

  // DomainAction is intentionally opaque to the Account domain.
  //
  // The consuming bounded context determines:
  //
  //   - its semantic meaning;
  //   - its internal representation;
  //   - how values are constructed;
  //   - which values are considered meaningful;
  //   - how the action is interpreted.
  //
  // Kipio does not introduce an internal representation because
  // doing so would make the generic Account domain responsible for
  // application-specific semantics.
  //
  // The type is therefore a Value Object boundary rather than an
  // Entity boundary.
  type DomainAction(==)


  // ----------------------------------------------------------
  // VALUE OBJECT SEMANTICS
  // ----------------------------------------------------------

  // DomainAction has no independent identity.
  //
  // Equality is simply the native equality of the opaque Value
  // Object supplied by the consuming context.
  //
  // No DomainActionId or SameDomainAction predicate is introduced.
  //
  // The consuming bounded context remains responsible for defining
  // the meaning represented by each DomainAction value.


  // ----------------------------------------------------------
  // DOMAIN BOUNDARY
  // ----------------------------------------------------------

  // The Account domain does not interpret DomainAction.
  //
  // Therefore no action-specific laws are defined here for:
  //
  //   - business semantics;
  //   - authorization requirements;
  //   - execution target resolution;
  //   - action parameters;
  //   - application-specific validity.
  //
  // Those laws belong to the bounded context that defines the
  // actual DomainAction values.
}

// ============================================================
// KIPIO ACCOUNT DOMAIN
// FOUNDATION — EXECUTION TARGET
// ============================================================
//
// ExecutionTarget represents the technical destination toward
// which an already-authorized DomainAction may be materialized.
//
// ------------------------------------------------------------
//
// DOMAIN BOUNDARY
//
// ExecutionTarget belongs to the execution context of a request,
// but its semantic distinction is required by Authorization:
//
//     Capability Scope
//         = where authority exists
//
//     ExecutionTarget
//         = where execution is technically materialized
//
// ExecutionTarget is intentionally opaque at the Account domain
// foundation layer.
//
// Kipio Account does NOT define here:
//
//   - blockchain addresses;
//   - contract addresses;
//   - EVM contracts;
//   - services;
//   - resource identifiers;
//   - ABI data;
//   - transaction structures;
//   - execution protocols;
//   - infrastructure-specific target formats.
//
// Those concerns belong to the relevant execution bounded context
// and infrastructure Adapter.
//
// ------------------------------------------------------------
//
// VALUE OBJECT SEMANTICS
//
// ExecutionTarget is a Value Object.
//
// It has:
//
//   - no ExecutionTargetId;
//   - no Entity identity;
//   - no lifecycle;
//   - no ownership identity;
//   - no execution identity.
//
// Its semantic equality is the native equality of the opaque
// Value Object supplied by the execution context.
//
// ------------------------------------------------------------
//
// IMPORTANT DISTINCTIONS
//
//     ExecutionTarget
//         != Capability Scope
//
//     ExecutionTarget
//         != DomainAction
//
//     ExecutionTarget
//         != Authorization
//
//     ExecutionTarget
//         != Execution
//
// Scope describes:
//
//     where authority exists.
//
// ExecutionTarget describes:
//
//     where an authorized operation is technically materialized.
//
// ------------------------------------------------------------
//
// DEPENDENCY BOUNDARY
//
// This foundation concept intentionally has no dependencies.
//
// It must remain usable by:
//
//   - Authorization;
//   - ExecutionRequest;
//   - ExecutionContext;
//   - ExecutionSemantics;
//   - infrastructure adapters.
//
// ============================================================

module KipioAccountExecutionTarget
{
  // ----------------------------------------------------------
  // EXECUTION TARGET
  // ----------------------------------------------------------

  // ExecutionTarget is intentionally opaque.
  //
  // The consuming execution context determines:
  //
  //   - its concrete representation;
  //   - its semantic interpretation;
  //   - how values are constructed;
  //   - how values are resolved;
  //   - whether two values refer to the same technical target.
  //
  // The Account domain does not impose an internal representation.
  type ExecutionTarget(==)


  // ----------------------------------------------------------
  // VALUE OBJECT SEMANTICS
  // ----------------------------------------------------------

  // ExecutionTarget has no independent identity.
  //
  // Native equality represents equality of the complete Value
  // Object supplied by the relevant execution context.
  //
  // No ExecutionTargetId or SameExecutionTarget predicate is
  // introduced.
}

// ============================================================
// KIPIO ACCOUNT DOMAIN
// FOUNDATION — RESTRICTION
// ============================================================
//
// Restriction semantics for the Account domain.
//
// Restriction is a Value Object representing a condition that
// limits the circumstances under which an existing Capability may
// be exercised.
//
// A Restriction:
//   - does not create authority;
//   - does not identify a Credential;
//   - does not identify a Capability;
//   - does not own a lifecycle;
//   - does not represent an execution;
//   - does not grant additional authority.
//
// Its semantic meaning is determined by its value.
//
// The Account domain intentionally does not prescribe one closed
// vocabulary of restriction kinds here. A restriction may later
// express conditions involving:
//
//   - value;
//   - quantity;
//   - frequency;
//   - time;
//   - recipient;
//   - Scope;
//   - operation type;
//   - execution count;
//   - context;
//   - or other domain-recognized conditions.
//
// The concrete interpretation of those conditions belongs to the
// authority evaluation layer that has the necessary context.
//
// This file therefore establishes:
//   - Restriction as a Value Object;
//   - semantic value equality;
//   - structural validity;
//   - the distinction between restriction meaning and restriction
//     evaluation.
//
// This file intentionally contains no:
//   - capability authorization logic
//   - credential logic
//   - session/delegation logic
//   - policy logic
//   - authorization validation
//   - effective authority calculation
//   - execution logic
//   - cryptographic verification
//   - blockchain ABI types
//   - storage representations
//
// ============================================================

include "DomainPrimitives.dfy"

module KipioAccountRestriction
{
  import opened KipioAccountDomainPrimitives


  // ----------------------------------------------------------
  // RESTRICTION KIND
  // ----------------------------------------------------------

  // RestrictionKind identifies the semantic class of a
  // Restriction.
  //
  // The domain does not currently impose a closed enumeration of
  // kinds because the same Account domain must be reusable across
  // different consumer contexts.
  //
  // Examples of possible semantic kinds include:
  //
  //     maximum_value
  //     recipient
  //     valid_until
  //     frequency
  //     execution_count
  //     operation_type
  //
  // These examples are vocabulary examples, not a closed protocol
  // enumeration.
  datatype RestrictionKind =
    RestrictionKind(
      name: string
    )


  // A RestrictionKind is structurally valid when it has a non-empty
  // semantic name.
  predicate ValidRestrictionKind(
    kind: RestrictionKind
  )
  {
    |kind.name| > 0
  }


  // Returns the semantic name of a RestrictionKind.
  function RestrictionKindName(
    kind: RestrictionKind
  ): string
  {
    kind.name
  }


  // ----------------------------------------------------------
  // RESTRICTION VALUE
  // ----------------------------------------------------------

  // RestrictionValue contains the value-specific information needed
  // to distinguish one restriction from another.
  //
  // The Account domain treats the payload as opaque here because
  // the interpretation depends on the RestrictionKind and the
  // evaluation context.
  //
  // The payload is therefore part of semantic equality but is not
  // interpreted by this foundation-level type.
  type RestrictionValue = seq<bv8>


  // ----------------------------------------------------------
  // RESTRICTION
  // ----------------------------------------------------------

  // Restriction is a Value Object.
  //
  // Its semantic value is:
  //
  //     RestrictionKind + RestrictionValue
  //
  // No RestrictionId exists.
  //
  // Two Restrictions with the same semantic kind and value
  // represent the same restriction.
  datatype Restriction =
    Restriction(
      kind: RestrictionKind,
      value: RestrictionValue
    )


  // ----------------------------------------------------------
  // ACCESSORS
  // ----------------------------------------------------------

  // Returns the semantic kind of a Restriction.
  function RestrictionKindOf(
    restriction: Restriction
  ): RestrictionKind
  {
    restriction.kind
  }


  // Returns the value-specific part of a Restriction.
  function RestrictionValueOf(
    restriction: Restriction
  ): RestrictionValue
  {
    restriction.value
  }


  // ----------------------------------------------------------
  // VALUE OBJECT EQUALITY
  // ----------------------------------------------------------

  // Two Restrictions are semantically equal exactly when their
  // semantic kind and value are equal.
  predicate SameRestriction(
    left: Restriction,
    right: Restriction
  )
  {
    RestrictionKindOf(left) == RestrictionKindOf(right)
    && RestrictionValueOf(left) == RestrictionValueOf(right)
  }


  // Two Restrictions with the same semantic values are the same
  // Value Object.
  lemma RestrictionsWithSameSemanticValuesAreEqual(
    left: Restriction,
    right: Restriction
  )
    requires SameRestriction(left, right)
    ensures left == right
  {
  }


  // Equal Dafny Restriction values necessarily have equal semantic
  // values.
  lemma EqualRestrictionsHaveEqualSemanticValues(
    left: Restriction,
    right: Restriction
  )
    requires left == right
    ensures SameRestriction(left, right)
  {
  }


  // Restriction equality depends only on its semantic values.
  lemma RestrictionEqualityDependsOnKindAndValue(
    left: Restriction,
    right: Restriction
  )
    requires left == right
    ensures RestrictionKindOf(left)
         == RestrictionKindOf(right)
    ensures RestrictionValueOf(left)
         == RestrictionValueOf(right)
  {
  }


  // ----------------------------------------------------------
  // VALUE OBJECT LAWS
  // ----------------------------------------------------------

  // A Restriction has no independent identity beyond its semantic
  // value.
  lemma RestrictionHasNoIndependentIdentity(
    restriction: Restriction
  )
    ensures SameRestriction(
              restriction,
              restriction
            )
  {
  }


  // ----------------------------------------------------------
  // VALIDITY
  // ----------------------------------------------------------

  // A valid Restriction must have:
  //
  //   - a valid semantic kind;
  //   - a well-formed restriction value.
  //
  // No specific interpretation of the value is required here.
  //
  // Empty payloads are permitted because some restriction kinds may
  // be fully represented by their kind alone.
  predicate ValidRestriction(
    restriction: Restriction
  )
  {
    ValidRestrictionKind(
      RestrictionKindOf(restriction)
    )
  }


  // A valid Restriction exposes a valid RestrictionKind.
  lemma ValidRestrictionHasValidKind(
    restriction: Restriction
  )
    requires ValidRestriction(restriction)
    ensures ValidRestrictionKind(
              RestrictionKindOf(restriction)
            )
  {
  }


  // ----------------------------------------------------------
  // AUTHORITY SEMANTIC BOUNDARY
  // ----------------------------------------------------------

  // A Restriction does not itself create authority.
  //
  // This predicate deliberately expresses only the semantic
  // boundary. Whether a restriction permits or denies a particular
  // exercise requires a Capability and an evaluation Context and
  // therefore belongs to higher-level authority evaluation.
  predicate RestrictionDoesNotCreateAuthority(
    restriction: Restriction
  )
  {
    true
  }


  // Restriction semantics are independent of whether a particular
  // Capability has already been granted.
  //
  // The Restriction describes a condition; it does not constitute
  // the underlying authority being conditioned.
  lemma RestrictionDoesNotBecomeCapability(
    restriction: Restriction
  )
    ensures RestrictionDoesNotCreateAuthority(restriction)
  {
  }
}

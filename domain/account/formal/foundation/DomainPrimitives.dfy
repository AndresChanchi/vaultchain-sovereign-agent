// ============================================================
// KIPIO ACCOUNT DOMAIN
// FOUNDATION — DOMAIN PRIMITIVES
// ============================================================
//
// Primitive vocabulary shared by the formal Account domain.
//
// This file intentionally contains only concepts that are:
//
//   - foundational;
//   - infrastructure-neutral;
//   - independent of higher-level authorization semantics;
//   - reusable by multiple bounded-context representations.
//
// This file intentionally does NOT define:
//
//   - Identity
//   - Account
//   - Capability
//   - CapabilityKind
//   - Scope
//   - Restriction
//   - Credential
//   - Session
//   - Delegation
//   - Authorization
//   - Policy
//   - PolicyEffect
//   - PolicyConsumption
//   - EffectiveAuthority
//   - AuthorizationState
//   - DomainAction
//   - Execution
//   - Proof verification
//   - cryptographic mechanisms
//   - blockchain representations
//   - storage representations
//
// Those concepts belong to their respective semantic modules.
//
// DomainTypes must not become a dumping ground for concepts merely
// because many modules depend on them.
//
// High fan-in is acceptable.
// Semantic contamination is not.
//
// ============================================================

module KipioAccountDomainPrimitives {

  // ----------------------------------------------------------
  // IDENTIFIERS
  // ----------------------------------------------------------

  // Identifier is an opaque domain reference used to distinguish
  // instances whose individual identity is meaningful.
  //
  // The domain intentionally does NOT specify:
  //
  //   - fixed byte length;
  //   - encoding;
  //   - hashing algorithm;
  //   - blockchain address representation;
  //   - nonce semantics;
  //   - cryptographic key semantics;
  //   - generation mechanism.
  //
  // Those decisions belong to the lifecycle of each Entity and/or
  // to the infrastructure that materializes the Identifier.
  type Id = seq<bv8>


  // An Identifier must contain some value.
  //
  // This is intentionally the minimum structural invariant.
  //
  // The domain does NOT impose:
  //
  //   |id| == 32
  //
  // because the current DDD does not establish 32 bytes as a
  // semantic protocol requirement.
  //
  // Uniqueness is NOT established here.
  // Uniqueness belongs to the state in which a given Entity exists.
  predicate ValidId(id: Id)
  {
    |id| > 0
  }


  // ----------------------------------------------------------
  // OPTIONAL IDENTIFIERS
  // ----------------------------------------------------------

  // OptionalId represents the presence or absence of an Identifier.
  //
  // It carries no additional identity semantics of its own.
  datatype OptionalId =
      None
    | Some(value: Id)


  // ----------------------------------------------------------
  // TEMPORAL DOMAIN VALUE
  // ----------------------------------------------------------

  // Timestamp is the primitive temporal value used by the domain.
  //
  // The domain does not encode wall-clock, block timestamp,
  // Unix epoch representation, or chain-specific time semantics
  // here. Interpretation belongs to the relevant temporal context.
  type Timestamp = int
}

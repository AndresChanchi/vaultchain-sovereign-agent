// ============================================================
// KIPIO ACCOUNT DOMAIN
// FOUNDATION — CHAIN
// ============================================================
//
// Chain represents the blockchain environment relevant to a
// semantic Authorization Context.
//
// ------------------------------------------------------------
//
// DOMAIN BOUNDARY
//
// Chain is part of the semantic context of an Authorization when
// the authorization must distinguish between blockchain
// environments.
//
// Kipio Account does NOT define here:
//
//   - Ethereum chain IDs;
//   - EVM chain ID encoding;
//   - network names;
//   - genesis hashes;
//   - RPC endpoints;
//   - blockchain addresses;
//   - consensus implementations;
//   - execution environments;
//   - protocol-specific identifiers.
//
// Those are infrastructure representations.
//
// The domain only requires a semantic Chain value capable of
// distinguishing one blockchain context from another.
//
// ------------------------------------------------------------
//
// VALUE OBJECT SEMANTICS
//
// Chain is a Value Object.
//
// It has:
//
//   - no ChainId as a separate Entity identifier;
//   - no lifecycle;
//   - no ownership identity;
//   - no execution identity.
//
// Its semantic equality is the equality of the Chain value itself.
//
// ------------------------------------------------------------
//
// AUTHORIZATION CONTEXT
//
// Chain participates in Authorization semantic equality:
//
//     Authorization Context
//         ├── AccountId
//         ├── ExecutionTarget
//         ├── DomainAction
//         ├── Scope
//         └── Chain
//
// Therefore two otherwise identical Authorizations associated with
// different Chain values are semantically different.
//
// ------------------------------------------------------------
//
// IMPORTANT DISTINCTIONS
//
//     Chain
//         != Account
//
//     Chain
//         != Blockchain Address
//
//     Chain
//         != ExecutionTarget
//
//     Chain
//         != Identity
//
//     Chain
//         != Authorization
//
// Chain identifies the blockchain context in which the semantic
// authorization is evaluated/materialized. It does not itself grant
// authority.
//
// ------------------------------------------------------------
//
// DEPENDENCY BOUNDARY
//
// This foundation concept intentionally has no dependencies.
//
// Concrete blockchain representations belong to infrastructure
// adapters rather than to this Value Object definition.
//
// The infrastructure may determine how a Chain value is
// represented or constructed, but it does not redefine the
// semantic equality of Chain within the domain.
//
// ============================================================

module KipioAccountChain
{
  // ----------------------------------------------------------
  // CHAIN
  // ----------------------------------------------------------

  // Chain is intentionally opaque at the Account domain level.
  //
  // The infrastructure or consuming context determines:
  //
  //   - its concrete representation;
  //   - its mapping to a blockchain network;
  //   - how values are constructed.
  //
  // The semantic equality of Chain remains the equality of the
  // complete Chain value itself.
  //
  // The `(==)` characteristic is required because Chain is a
  // Value Object whose semantic equality participates in the
  // equality of higher-level Value Objects such as Authorization.
  //
  // Kipio does not impose a chain-specific representation here.
  type Chain(==)


  // ----------------------------------------------------------
  // VALUE OBJECT SEMANTICS
  // ----------------------------------------------------------

  // Chain has no independent Entity identity.
  //
  // Native equality represents equality of the complete semantic
  // Chain value supplied by the relevant context.
  //
  // Therefore:
  //
  //     chainA == chainB
  //
  // means that the two Chain values are semantically equal.
  //
  // Conversely, when two Chain values differ:
  //
  //     chainA != chainB
  //
  // they represent different blockchain contexts and therefore
  // can distinguish otherwise identical Authorization contexts.
  //
  // No Chain Entity and no artificial ChainId are introduced.
}

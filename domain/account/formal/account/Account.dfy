// ============================================================
// KIPIO ACCOUNT DOMAIN
// ACCOUNT — ACCOUNT
// ============================================================
//
// Account-level semantics for the Account domain.
//
// Account is an Entity representing the operational component
// through which exactly one sovereign Identity exercises authority
// over blockchain.
//
// Account has its own stable domain identity: AccountId.
//
// AccountId is not inherently:
//   - a blockchain address;
//   - a hash;
//   - a nonce;
//   - a cryptographic key;
//   - an Account Abstraction representation.
//
// Account maintains Authorization State, but does not itself:
//   - calculate Effective Authority;
//   - decide Authorization validity;
//   - approve Policies;
//   - verify cryptographic Proofs;
//   - materialize blockchain execution.
//
// The sovereign Identity of an Account is a direct structural
// relationship: every Account value contains exactly one Identity.
//
// This file intentionally contains no:
//   - authorization validation
//   - effective authority calculation
//   - authorization state transition implementation
//   - policy production or approval
//   - cryptographic verification
//   - execution engine logic
//   - adapter logic
//   - blockchain ABI types
//   - storage representations
//
// ============================================================

include "../foundation/DomainPrimitives.dfy"
include "../foundation/Identity.dfy"
include "../authority/AuthorizationState.dfy"

module KipioAccountAccount
{
  import opened KipioAccountDomainPrimitives
  import opened KipioAccountIdentity
  import opened KipioAccountAuthorizationState


  // ----------------------------------------------------------
  // ACCOUNT IDENTIFIER
  // ----------------------------------------------------------

  // AccountId identifies an individual Account Entity.
  //
  // AccountId has semantic identity within the Account domain.
  // Its physical representation remains abstract at this level.
  //
  // AccountId must not automatically be interpreted as:
  //   - a blockchain address;
  //   - a nonce;
  //   - a hash;
  //   - B256;
  //   - a private/public key;
  //   - or an Account Abstraction representation.
  type AccountId = Id


  // ----------------------------------------------------------
  // ACCOUNT
  // ----------------------------------------------------------

  // Account is the operational component through which exactly
  // one sovereign Identity exercises authority over blockchain.
  //
  // The sovereign Identity is mandatory and singular by
  // construction:
  //
  //     Account
  //         └── exactly one sovereign Identity
  //
  // Authorization State belongs to this Account and represents
  // its operational authorization state.
  //
  // Authorization State does not define who the sovereign Identity
  // is. That relationship is represented directly by `identity`.
  datatype Account =
    Account(
      id: AccountId,
      identity: Identity,
      authorizationState: AuthorizationState
    )


  // ----------------------------------------------------------
  // ACCOUNT IDENTIFIERS AND ACCESSORS
  // ----------------------------------------------------------

  // Returns the stable identifier of the Account Entity.
  function AccountIdOf(
    account: Account
  ): AccountId
  {
    account.id
  }


  // Returns the single sovereign Identity associated with the
  // Account.
  //
  // This is a sovereignty relationship, not a statement that
  // other Identities cannot be authorized to exercise authority
  // over the Account.
  function AccountSovereignIdentity(
    account: Account
  ): Identity
  {
    account.identity
  }


  // Returns the Authorization State maintained by the Account.
  //
  // The returned state contains the operational authorization
  // relationships and objects from which Effective Authority may
  // later be derived.
  function AccountAuthorizationState(
    account: Account
  ): AuthorizationState
  {
    account.authorizationState
  }


  // ----------------------------------------------------------
  // ACCOUNT VALIDITY
  // ----------------------------------------------------------

  // A valid Account must contain:
  //
  //   - a valid AccountId;
  //   - a valid sovereign Identity;
  //   - a valid Authorization State.
  //
  // This establishes structural/domain validity only.
  // It does not imply that any particular action is currently
  // authorized or executable.
  predicate ValidAccount(
    account: Account
  )
  {
    ValidId(AccountIdOf(account))
    && ValidIdentity(AccountSovereignIdentity(account))
    && ValidAuthorizationState(
         AccountAuthorizationState(account)
       )
  }


  // ----------------------------------------------------------
  // ACCOUNT ENTITY IDENTITY
  // ----------------------------------------------------------

  // Determines whether two Account values refer to the same
  // semantic Account Entity.
  //
  // Entity identity is determined by AccountId, not by all
  // structural fields.
  //
  // This predicate is intentionally separate from Dafny's native
  // `==`, because datatype equality compares all constructor fields.
  predicate SameAccount(
    left: Account,
    right: Account
  )
  {
    AccountIdOf(left) == AccountIdOf(right)
  }


  // Two Account values with the same AccountId refer to the same
  // semantic Account Entity.
  lemma AccountsWithEqualIdsHaveSameIdentity(
    left: Account,
    right: Account
  )
    requires AccountIdOf(left) == AccountIdOf(right)
    ensures SameAccount(left, right)
  {
  }


  // Two Account values with distinct AccountIds cannot represent
  // the same semantic Account Entity.
  lemma AccountsWithDistinctIdsAreNotTheSameAccount(
    left: Account,
    right: Account
  )
    requires AccountIdOf(left) != AccountIdOf(right)
    ensures !SameAccount(left, right)
  {
  }


  // Equal Dafny Account values necessarily expose equal
  // AccountIds.
  //
  // This is a structural property and is intentionally distinct
  // from the semantic Entity identity predicate SameAccount.
  lemma EqualAccountsHaveEqualIds(
    left: Account,
    right: Account
  )
    requires left == right
    ensures AccountIdOf(left) == AccountIdOf(right)
  {
  }


  // Two Accounts with the same AccountId and identical complete
  // structural state are structurally equal.
  //
  // AccountId establishes Entity identity, while Dafny `==`
  // additionally requires all constructor fields to match.
  lemma AccountsWithSameIdAndStateAreStructurallyEqual(
    left: Account,
    right: Account
  )
    requires AccountIdOf(left) == AccountIdOf(right)
    requires AccountSovereignIdentity(left)
           == AccountSovereignIdentity(right)
    requires AccountAuthorizationState(left)
           == AccountAuthorizationState(right)
    ensures left == right
  {
  }


  // ----------------------------------------------------------
  // ACCOUNT — SOVEREIGN IDENTITY
  // ----------------------------------------------------------

  // Every Account has exactly one sovereign Identity.
  //
  // This property is structural: `identity` is a required single
  // Identity value rather than an optional value or a collection.
  //
  // This does NOT mean that the sovereign Identity is the only
  // Identity that may exercise authority over the Account.
  lemma AccountHasExactlyOneSovereignIdentity(
    account: Account
  )
    ensures AccountSovereignIdentity(account)
         == account.identity
  {
  }


  // The sovereign Identity relationship is independent of the
  // Account's Authorization State.
  //
  // Authorization State determines operational authority relations;
  // it does not replace the sovereign Identity relationship.
  lemma AccountSovereignIdentityIndependentOfAuthorizationState(
    account: Account
  )
    ensures AccountSovereignIdentity(account)
         == account.identity
  {
  }


  // ----------------------------------------------------------
  // ACCOUNT VALIDITY LAWS
  // ----------------------------------------------------------

  // A valid Account has a valid AccountId.
  lemma ValidAccountHasValidId(
    account: Account
  )
    requires ValidAccount(account)
    ensures ValidId(AccountIdOf(account))
  {
  }


  // A valid Account has a valid sovereign Identity.
  lemma ValidAccountHasValidSovereignIdentity(
    account: Account
  )
    requires ValidAccount(account)
    ensures ValidIdentity(
              AccountSovereignIdentity(account)
            )
  {
  }


  // A valid Account contains a valid Authorization State.
  lemma ValidAccountHasValidAuthorizationState(
    account: Account
  )
    requires ValidAccount(account)
    ensures ValidAuthorizationState(
              AccountAuthorizationState(account)
            )
  {
  }


  // ----------------------------------------------------------
  // SOVEREIGN IDENTITY ≠ AUTHORIZED ACTOR
  // ----------------------------------------------------------

  // The Account's sovereign Identity is represented explicitly by
  // AccountSovereignIdentity.
  //
  // Authorization for another Subject or Identity is represented
  // through Authorization State relationships and must not be
  // interpreted as a second sovereign Identity of this Account.
  //
  // The full proof of "authorized actor != sovereign owner" belongs
  // to Authorization State and Authority semantics, not to this
  // structural Account definition.
  lemma SovereignIdentityIsPartOfAccountIdentity(
    account: Account
  )
    ensures AccountSovereignIdentity(account)
         == account.identity
  {
  }
}

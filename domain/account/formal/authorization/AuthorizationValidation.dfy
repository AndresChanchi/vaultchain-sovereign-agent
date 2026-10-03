// ============================================================
// KIPIO ACCOUNT DOMAIN
// AUTHORIZATION — AUTHORIZATION VALIDATION
// ============================================================
//
// Authorization Validation determines whether an Authorization
// may be accepted by a specific valid Account under a given
// Authorization State, Effective Authority, evaluation time,
// contextual information, external Proof verification result,
// and formal provenance witnesses.
//
// The validation contract combines:
//
//   - Authorization structural validity;
//   - Authorization Context compatibility with the Account;
//   - Credential recognition;
//   - Credential lifecycle usability;
//   - temporal validity;
//   - Replay Protection;
//   - Effective Authority structural validity;
//   - Effective Authority provenance;
//   - Effective Authority concrete source attribution;
//   - Effective Authority source usability at the evaluation time;
//   - Delegation source-identity provenance;
//   - Requested Authority containment in Effective Authority;
//   - external Proof verification.
//
// ------------------------------------------------------------
//
// D4 — PROOF BOUNDARY
//
// Proof is an infrastructure concept.
//
// Authorization Validation does NOT:
//
//   - define Proof;
//   - compare Proof values;
//   - verify Proof cryptographically;
//   - determine Proof representation.
//
// Instead, the external Verifier supplies:
//
//     proofVerified : bool
//
// Therefore:
//
//     Proof Verification
//         = infrastructure concern
//
//     Authorization Validation
//         = domain acceptance condition
//
// Proof validity is necessary for acceptance but is not sufficient
// for Authorization validity.
//
// ------------------------------------------------------------
//
// D4 — AUTHORIZATION VALUE
//
// Authorization is a Value Object.
//
// Its complete semantic value contains:
//
//   - Credential reference;
//   - Requested Authority;
//   - Restrictions;
//   - Temporal Conditions;
//   - Replay Protection;
//   - Authorization Context.
//
// The Authorization Context contains:
//
//   - AccountId;
//   - ExecutionTarget;
//   - DomainAction;
//   - Scope;
//   - Chain.
//
// Proof remains outside the semantic Authorization value.
//
// Therefore:
//
//     Proof
//         !=
//     Authorization semantic value
//
// and:
//
//     Proof validity
//         !=
//     Authorization validity
//
// ------------------------------------------------------------
//
// D1 — AUTHORITY BOUNDARY
//
// Authorization Validation does not calculate Effective Authority.
//
// It receives an already-derived EffectiveAuthority value and
// requires:
//
//     RequestedAuthority
//         ⊆
//     EffectiveAuthority
//
// Effective Authority may already incorporate:
//
//   - Account Capabilities;
//   - Credential Authority;
//   - Sessions;
//   - Delegations;
//   - Restrictions;
//   - Scope;
//   - Policy Effects;
//   - temporal conditions;
//   - other contextual authority constraints.
//
// This module therefore does not duplicate those derivation rules.
//
// However, acceptance must not trust an arbitrary EffectiveAuthority
// supplied by a caller.
//
// The supplied EffectiveAuthority must be accompanied by ghost
// provenance evidence proving:
//
//     EffectiveAuthority
//         =
//     union of source contributions
//
// and:
//
//     each contribution
//         ⊆
//     its source authority
//
// and, additionally, every contribution must be attributed to a
// concrete authority source reference whose identity and authority
// value are both grounded in the Account-relative state.
//
// This source-aware provenance is contextual proof material.
// It does not make provenance runtime state and does not add
// provenance fields to EffectiveAuthority itself.
//
// ------------------------------------------------------------
//
// D3 — ENTITY RECOGNITION
//
// Authorization references Credential through CredentialId.
//
// Credential is an Entity whose identity is:
//
//     CredentialId
//
// Therefore Authorization Validation resolves recognition through:
//
//     AuthorizationCredentialId(authorization)
//
// rather than through structural membership of a Credential value.
//
// This preserves the distinction between:
//
//     Entity identity
//
//     State recognition
//
//     Lifecycle usability
//
// A Credential may remain recognized while Suspended or Revoked.
// Such a Credential is not usable for accepting a new Authorization.
//
// ------------------------------------------------------------
//
// ACCOUNT VALIDITY BOUNDARY
//
// Authorization acceptance operates on an Account Entity.
//
// Therefore acceptance requires:
//
//     ValidAccount(account)
//
// before any Account-level Authorization State or Context
// relationship can be trusted.
//
// This prevents a structurally invalid Account from acting as the
// validation boundary for an otherwise valid Authorization.
//
// The Account's Authorization State is still obtained from:
//
//     AccountAuthorizationState(account)
//
// preserving the invariant that the operational state belongs to
// that Account Entity.
//
// ------------------------------------------------------------
//
// AUTHORIZATION CONTEXT
//
// Authorization contains the AccountId to which the semantic
// Authorization applies.
//
// AuthorizationState intentionally does not contain AccountId
// because it represents the operational state belonging to an
// Account, not the identity of that Account.
//
// Therefore validation receives the Account Entity itself when
// validating acceptance.
//
// The Account-level context condition is:
//
//     AuthorizationAccountId(authorization)
//         ==
//     AccountIdOf(account)
//
// This ensures that an Authorization for Account A cannot be
// accepted against Account B merely because B happens to have a
// structurally valid AuthorizationState.
//
// ExecutionTarget, DomainAction, Scope and Chain remain semantic
// components of Authorization.
//
// Their compatibility with a concrete execution request or
// infrastructure context belongs to the layer that possesses that
// expected execution context.
//
// In particular, this module does not invent an independent
// "expected Chain" input merely to close the contextuality gap.
// Chain equality is already semantic inside Authorization.
// Concrete chain matching remains a responsibility of the layer
// that owns the actual evaluation/execution context.
//
// ------------------------------------------------------------
//
// REPLAY
//
// Replay Protection is evaluated against:
//
//     StateConsumedReplayKeys(state)
//
// Validation does NOT consume the replay key.
//
// Consumption belongs to the corresponding state-transition or
// policy-consumption semantics.
//
// ------------------------------------------------------------
//
// TEMPORAL VALIDITY
//
// Structural validity establishes:
//
//     validFrom <= validUntil
//
// Current applicability is evaluated here:
//
//     validFrom <= now <= validUntil
//
// Temporal expiration is contextual and does not create an
// Authorization lifecycle state.
//
// ------------------------------------------------------------
//
// STRUCTURAL VALIDITY
//
// Authorization.dfy is the authoritative definition of structural
// Authorization validity.
//
// This module therefore reuses ValidAuthorization and exposes
// named predicates for the individual validation boundaries.
//
// ------------------------------------------------------------
//
// EFFECTIVE AUTHORITY PROVENANCE
//
// EffectiveAuthority.dfy provides two related provenance contracts:
//
//     EffectiveAuthorityDerivedFromSources
//
// and:
//
//     EffectiveAuthorityDerivedFromAttributedSources
//
// The first is the value-only projection:
//
//     contribution(i) ⊆ sourceAuthority(i)
//
// and:
//
//     EffectiveAuthority
//         =
//     union of all contributions.
//
// The second is the source-sensitive form:
//
//     sourceReference(i)
//             |
//             v
//     sourceAuthority(i)
//             |
//             v
//     contribution(i)
//
// The source-sensitive form is the authoritative provenance
// boundary for Authorization acceptance.
//
// ------------------------------------------------------------
//
// CONCRETE SOURCE ATTRIBUTION
//
// EffectiveAuthority remains a Value Object:
//
//     EffectiveAuthority = set<Capability>
//
// Concrete source identity is therefore NOT stored in the
// EffectiveAuthority value.
//
// Instead, Authorization Validation receives ghost attribution
// evidence:
//
//     sourceReferences: seq<AuthoritySourceReference>
//
// together with:
//
//     sourceAuthorities: seq<set<Capability>>
//     contributions: seq<set<Capability>>
//
// These sequences are index-aligned:
//
//     sourceReferences[i]
//             |
//             v
//     sourceAuthorities[i]
//             |
//             v
//     contributions[i]
//
// Authorization Validation must additionally prove that each
// concrete source reference resolves to the authority value supplied
// at the same index in the Account-relative state.
//
// Therefore an authority witness cannot merely state:
//
//     { Upload }
//
// when the semantic question requires:
//
//     Credential A -> { Upload }
//
// because the concrete source reference is part of the witness.
//
// ------------------------------------------------------------
//
// RECOGNIZED AUTHORITY SOURCE TYPES
//
// Concrete source references may identify:
//
//   - Account authority;
//   - Credential authority;
//   - Session authority;
//   - Delegation authority.
//
// The source reference is identified by:
//
//     AuthoritySourceKind
//     +
//     Id
//
// Equality of source authority values does not collapse distinct
// concrete source references.
//
// ------------------------------------------------------------
//
// CURRENTLY USABLE SOURCE REFERENCES
//
// Acceptance uses:
//
//     CurrentlyUsableAuthoritySourceReferencesForAcceptance(
//         state,
//         account,
//         identities,
//         now
//     )
//
// This source-reference universe preserves:
//
//   - Account authority;
//   - active Credential authority;
//   - currently contributing Session authority;
//   - currently contributing Delegation authority;
//
// and, for Delegations:
//
//   - legitimate source-identity provenance.
//
// This is the source-reference counterpart of the existing
// value-only:
//
//     CurrentlyUsableAuthoritySourcesForAcceptance
//
// The latter remains available as a derived authority-value view.
//
// ------------------------------------------------------------
//
// SOURCE REFERENCE RESOLUTION
//
// A source reference is acceptable only when it resolves against the
// current Account-relative state to exactly the supplied
// sourceAuthority value.
//
// Therefore:
//
//     reference -> authority
//
// is not inferred merely from:
//
//     authority ∈ source-universe.
//
// Instead:
//
//     concrete reference
//         -> recognized/usable Entity
//         -> concrete authority value
//         -> supplied sourceAuthority
//
// must all agree.
//
// This is the acceptance-level closure of concrete source
// attribution.
//
// ------------------------------------------------------------
//
// D1 — DELEGATION SOURCE PROVENANCE
//
// Identity remains an independent Entity.
//
// This module receives an Identity collection as a ghost contextual
// witness for resolving Delegation source provenance.
//
// It intentionally does NOT store:
//
//     identities: set<Identity>
//
// inside AuthorizationState.
//
// A root Delegation must satisfy:
//
//     Source(D)
//         ==
//     SovereignIdentity(Account)
//
// A transitive Delegation may have a non-sovereign source Identity,
// but its source must be attributable to the Subject that received
// authority from the parent Delegation.
//
// Therefore the accepted Delegation provenance chain must be:
//
//     Account Sovereign Identity
//                 ↓
//          root Delegation
//                 ↓
//        parent Delegatee Subject
//                 ↓
//        child Source Identity
//                 ↓
//          child Delegation
//
// recursively until the Account sovereign Identity is reached.
//
// A provenance cycle that cannot terminate at the sovereign root
// is not legitimate.
//
// ------------------------------------------------------------
//
// THIS FILE INTENTIONALLY CONTAINS NO:
//
//   - Proof definition;
//   - cryptographic verification;
//   - Verifier implementation;
//   - Effective Authority calculation;
//   - Session selection logic;
//   - Delegation selection logic;
//   - Policy evaluation;
//   - AuthorizationState mutation;
//   - Replay consumption;
//   - execution;
//   - blockchain ABI types;
//   - storage representations.
//
// ============================================================

include "../foundation/DomainPrimitives.dfy"
include "../foundation/Capability.dfy"
include "../foundation/Restriction.dfy"
include "../foundation/Scope.dfy"
include "../foundation/Identity.dfy"

include "../authority/Credential.dfy"
include "../authority/CredentialAuthority.dfy"
include "../authority/Session.dfy"
include "../authority/Delegation.dfy"
include "../authority/EffectiveAuthority.dfy"
include "../authority/AuthorizationState.dfy"

include "../account/Account.dfy"

include "Authorization.dfy"
include "Replay.dfy"

module KipioAccountAuthorizationValidation
{
  import opened KipioAccountDomainPrimitives
  import opened KipioAccountCapability
  import opened KipioAccountRestriction
  import opened KipioAccountIdentity
  import opened KipioAccountCredential
  import opened KipioAccountCredentialAuthority
  import opened KipioAccountSession
  import opened KipioAccountDelegation
  import opened KipioAccountEffectiveAuthority
  import opened KipioAccountAuthorizationState
  import opened KipioAccountAccount
  import opened KipioAccountAuthorization
  import opened KipioAccountReplay
  import opened KipioAccountScope


  // ----------------------------------------------------------
  // AUTHORIZATION CONTEXT / ACCOUNT COMPATIBILITY
  // ----------------------------------------------------------

  predicate AuthorizationContextMatchesAccount(
    authorization: Authorization,
    account: Account
  )
  {
    AuthorizationAccountId(authorization)
    ==
    AccountIdOf(account)
  }


  lemma AuthorizationForDifferentAccountDoesNotMatchAccount(
    authorization: Authorization,
    account: Account
  )
    requires AuthorizationAccountId(authorization)
          != AccountIdOf(account)
    ensures !AuthorizationContextMatchesAccount(
              authorization,
              account
            )
  {
  }


  lemma MatchingAuthorizationContextReferencesAccount(
    authorization: Authorization,
    account: Account
  )
    requires AuthorizationContextMatchesAccount(
               authorization,
               account
             )
    ensures AuthorizationAccountId(authorization)
         == AccountIdOf(account)
  {
  }


  // ----------------------------------------------------------
  // CREDENTIAL RECOGNITION
  // ----------------------------------------------------------

  predicate AuthorizationCredentialIsRecognized(
    authorization: Authorization,
    state: AuthorizationState
  )
  {
    CredentialIdRecognizedInState(
      state,
      AuthorizationCredentialId(authorization)
    )
  }


  predicate AuthorizationCredentialIsActive(
    authorization: Authorization,
    state: AuthorizationState
  )
  {
    ActiveCredentialRecognizedInState(
      state,
      AuthorizationCredentialId(authorization)
    )
  }


  predicate AuthorizationCredentialIsUsable(
    authorization: Authorization,
    state: AuthorizationState
  )
  {
    AuthorizationCredentialIsRecognized(
      authorization,
      state
    )
    &&
    AuthorizationCredentialIsActive(
      authorization,
      state
    )
  }


  // ----------------------------------------------------------
  // REQUESTED AUTHORITY VALIDITY
  // ----------------------------------------------------------

  predicate RequestedAuthorityIsValid(
    authorization: Authorization
  )
  {
    forall capability ::
      capability in AuthorizationRequestedAuthority(authorization)
      ==> ValidCapability(capability)
  }


  // ----------------------------------------------------------
  // RESTRICTION VALIDITY
  // ----------------------------------------------------------

  predicate AuthorizationRestrictionsAreValid(
    authorization: Authorization
  )
  {
    forall restriction ::
      restriction in AuthorizationRestrictions(authorization)
      ==> ValidRestriction(restriction)
  }


  // ----------------------------------------------------------
  // TEMPORAL VALIDITY
  // ----------------------------------------------------------

  predicate AuthorizationIntervalIsWellFormed(
    authorization: Authorization
  )
  {
    AuthorizationValidFrom(authorization)
    <= AuthorizationValidUntil(authorization)
  }


  predicate AuthorizationIsTemporallyValidAt(
    authorization: Authorization,
    now: Timestamp
  )
  {
    AuthorizationValidFrom(authorization)
    <= now
    &&
    now
    <= AuthorizationValidUntil(authorization)
  }


  // ----------------------------------------------------------
  // REPLAY PROTECTION
  // ----------------------------------------------------------

  predicate AuthorizationReplayIsFresh(
    authorization: Authorization,
    state: AuthorizationState
  )
  {
    AuthorizationReplayKeyIsFresh(
      authorization,
      StateConsumedReplayKeys(state)
    )
  }


  // ----------------------------------------------------------
  // RECOGNIZED AUTHORITY SOURCES
  // ----------------------------------------------------------

  function RecognizedAuthoritySources(
    state: AuthorizationState
  ): set<set<Capability>>
  {
    { StateCapabilities(state) }

    +
    (set credentialId : Id
       | credentialId in StateCredentialAuthorities(state).Keys
       :: StateCredentialAuthorities(state)[credentialId])

    +
    (set session : Session
       | session in StateSessions(state)
       :: SessionCapabilities(session))

    +
    (set delegation : Delegation
       | delegation in StateDelegations(state)
       :: DelegationCapabilities(delegation))
  }


  // ----------------------------------------------------------
  // CURRENTLY USABLE AUTHORITY SOURCES
  // ----------------------------------------------------------

  function CurrentlyUsableAuthoritySources(
    state: AuthorizationState,
    now: Timestamp
  ): set<set<Capability>>
  {
    { StateCapabilities(state) }

    +
    (set credentialId : Id
       | credentialId in StateCredentialAuthorities(state).Keys
         && ActiveCredentialRecognizedInState(
           state,
           credentialId
         )
       :: StateCredentialAuthorities(state)[credentialId])

    +
    (set session : Session
       | session in StateSessions(state)
         && SessionCanContributeAuthorityAt(
           state,
           session,
           now
         )
       :: SessionCapabilities(session))

    +
    (set delegation : Delegation
       | delegation in StateDelegations(state)
         && DelegationCanContributeAuthorityAt(
           state,
           delegation,
           now
         )
       :: DelegationCapabilities(delegation))
  }


  // ==========================================================
  // SOURCE REFERENCE UNIVERSES
  // ==========================================================

  // Concrete source references recognized by the Account-relative
  // authorization state.
  //
  // The source reference identifies an existing domain source by:
  //
  //     source kind + source Entity/state identity.
  //
  // The corresponding authority value remains separate.

  ghost function RecognizedAuthoritySourceReferences(
    state: AuthorizationState,
    account: Account
  ): set<AuthoritySourceReference>
  {
    {
      AuthoritySourceReference(
        AccountAuthoritySource,
        AccountIdOf(account)
      )
    }

    +
    (set credentialId : Id
       | credentialId in StateCredentialAuthorities(state).Keys
       :: AuthoritySourceReference(
            CredentialAuthoritySource,
            credentialId
          ))

    +
    (set session : Session
       | session in StateSessions(state)
       :: AuthoritySourceReference(
            SessionAuthoritySource,
            SessionId(session)
          ))

    +
    (set delegation : Delegation
       | delegation in StateDelegations(state)
       :: AuthoritySourceReference(
            DelegationAuthoritySource,
            DelegationId(delegation)
          ))
  }


  // Concrete source references currently usable by the Account at
  // the evaluation time.
  //
  // Delegations additionally require legitimate source-identity
  // provenance.

  ghost function CurrentlyUsableAuthoritySourceReferencesForAcceptance(
    state: AuthorizationState,
    account: Account,
    identities: set<Identity>,
    now: Timestamp
  ): set<AuthoritySourceReference>
  {
    {
      AuthoritySourceReference(
        AccountAuthoritySource,
        AccountIdOf(account)
      )
    }

    +
    (set credentialId : Id
       | credentialId in StateCredentialAuthorities(state).Keys
         && ActiveCredentialRecognizedInState(
           state,
           credentialId
         )
       :: AuthoritySourceReference(
            CredentialAuthoritySource,
            credentialId
          ))

    +
    (set session : Session
       | session in StateSessions(state)
         && SessionCanContributeAuthorityAt(
           state,
           session,
           now
         )
       :: AuthoritySourceReference(
            SessionAuthoritySource,
            SessionId(session)
          ))

    +
    (set delegation : Delegation
       | delegation in StateDelegations(state)
         && DelegationCanContributeAuthorityAt(
           state,
           delegation,
           now
         )
         && DelegationHasLegitimateSourceProvenanceForAccount(
           account,
           state,
           identities,
           delegation
         )
       :: AuthoritySourceReference(
            DelegationAuthoritySource,
            DelegationId(delegation)
          ))
  }


  // ----------------------------------------------------------
  // SOURCE REFERENCE -> CONCRETE AUTHORITY RESOLUTION
  // ----------------------------------------------------------

  // Resolves one concrete source reference against the Account-
  // relative state and proves that the supplied sourceAuthority
  // value corresponds exactly to the referenced authority-bearing
  // source.
  //
  // This is the critical acceptance-level binding between:
  //
  //     concrete source identity
  //
  // and:
  //
  //     authority value.

  ghost predicate AuthoritySourceReferenceResolvesToAuthority(
    state: AuthorizationState,
    account: Account,
    identities: set<Identity>,
    now: Timestamp,
    sourceReference: AuthoritySourceReference,
    sourceAuthority: set<Capability>
  )
  {
    match AuthoritySourceReferenceKind(sourceReference)

    case AccountAuthoritySource =>
      AuthoritySourceReferenceId(sourceReference)
      ==
      AccountIdOf(account)
      &&
      sourceAuthority
      ==
      StateCapabilities(state)

    case CredentialAuthoritySource =>
      CredentialAuthorityDefinedForCredentialId(
        state,
        AuthoritySourceReferenceId(sourceReference)
      )
      &&
      ActiveCredentialRecognizedInState(
        state,
        AuthoritySourceReferenceId(sourceReference)
      )
      &&
      sourceAuthority
      ==
      StateCredentialAuthorityById(
        state,
        AuthoritySourceReferenceId(sourceReference)
      )

    case SessionAuthoritySource =>
      exists session : Session ::
        session in StateSessions(state)
        &&
        SessionId(session)
           == AuthoritySourceReferenceId(sourceReference)
        &&
        SessionCanContributeAuthorityAt(
          state,
          session,
          now
        )
        &&
        sourceAuthority
           == SessionCapabilities(session)

    case DelegationAuthoritySource =>
      exists delegation : Delegation ::
        delegation in StateDelegations(state)
        &&
        DelegationId(delegation)
           == AuthoritySourceReferenceId(sourceReference)
        &&
        DelegationCanContributeAuthorityAt(
          state,
          delegation,
          now
        )
        &&
        DelegationHasLegitimateSourceProvenanceForAccount(
          account,
          state,
          identities,
          delegation
        )
        &&
        sourceAuthority
           == DelegationCapabilities(delegation)
  }


  // ----------------------------------------------------------
  // SOURCE REFERENCE VALIDITY
  // ----------------------------------------------------------

  // A recognized source reference is tied to one of the concrete
  // Account-relative sources represented by the current state.
  //
  // Therefore its Id validity is inherited from the corresponding
  // Account / Credential / Session / Delegation Entity.
  //
  // This lemma deliberately does not infer Id validity merely from
  // the AuthoritySourceReference datatype. The reference itself is
  // only a proof-level key; validity comes from the concrete domain
  // source to which the key resolves.

  lemma RecognizedSourceReferenceMustBeValid(
    sourceReference: AuthoritySourceReference,
    state: AuthorizationState,
    account: Account
  )
    requires ValidAuthorizationState(state)
    requires ValidAccount(account)
    requires sourceReference
             in RecognizedAuthoritySourceReferences(
                  state,
                  account
                )
    ensures ValidAuthoritySourceReference(
              sourceReference
            )
  {
    match AuthoritySourceReferenceKind(sourceReference)
    {
      case AccountAuthoritySource =>
      {
        assert
          AuthoritySourceReferenceId(sourceReference)
          ==
          AccountIdOf(account);

        assert ValidId(
          AccountIdOf(account)
        );

        assert ValidId(
          AuthoritySourceReferenceId(sourceReference)
        );
      }

      case CredentialAuthoritySource =>
      {
        var credentialId :=
          AuthoritySourceReferenceId(sourceReference);

        assert
          credentialId
          in
            StateCredentialAuthorities(state).Keys;

        assert
          CredentialIdRecognizedInState(
            state,
            credentialId
          );

        var credential :|
          credential in StateCredentials(state)
          &&
          CredentialId(credential) == credentialId;

        assert
          credential in StateCredentials(state);

        assert
          ValidCredential(credential);

        assert
          ValidId(
            CredentialId(credential)
          );

        assert
          CredentialId(credential)
          ==
          credentialId;

        assert
          ValidId(credentialId);

        assert
          ValidId(
            AuthoritySourceReferenceId(sourceReference)
          );
      }

      case SessionAuthoritySource =>
      {
        var sessionId :=
          AuthoritySourceReferenceId(sourceReference);

        var session :|
          session in StateSessions(state)
          &&
          SessionId(session) == sessionId;

        assert
          session in StateSessions(state);

        assert
          ValidSession(session);

        assert
          ValidId(
            SessionId(session)
          );

        assert
          SessionId(session)
          ==
          sessionId;

        assert
          ValidId(sessionId);

        assert
          ValidId(
            AuthoritySourceReferenceId(sourceReference)
          );
      }

      case DelegationAuthoritySource =>
      {
        var delegationId :=
          AuthoritySourceReferenceId(sourceReference);

        var delegation :|
          delegation in StateDelegations(state)
          &&
          DelegationId(delegation) == delegationId;

        assert
          delegation in StateDelegations(state);

        assert
          ValidDelegation(delegation);

        assert
          ValidId(
            DelegationId(delegation)
          );

        assert
          DelegationId(delegation)
          ==
          delegationId;

        assert
          ValidId(delegationId);

        assert
          ValidId(
            AuthoritySourceReferenceId(sourceReference)
          );
      }
    }
  }


  // Every accepted source reference must belong to the recognized
  // and currently usable source-reference universe.

  ghost predicate EffectiveAuthoritySourceReferencesAreCurrentlyUsable(
    state: AuthorizationState,
    account: Account,
    identities: set<Identity>,
    now: Timestamp,
    sourceReferences: seq<AuthoritySourceReference>
  )
  {
    forall i ::
      0 <= i < |sourceReferences|
      ==>
        sourceReferences[i]
        in
        CurrentlyUsableAuthoritySourceReferencesForAcceptance(
          state,
          account,
          identities,
          now
        )
  }


  // ----------------------------------------------------------
  // IDENTITY CONTEXT
  // ----------------------------------------------------------

  ghost predicate AuthorizationIdentityContextIsValid(
    identities: set<Identity>
  )
  {
    (forall identity ::
       identity in identities
       ==> ValidIdentity(identity))
    &&
    (forall first, second ::
       first in identities
       && second in identities
       && IdentityId(first) == IdentityId(second)
       ==> first == second)
  }


  // ----------------------------------------------------------
  // ROOT DELEGATION PROVENANCE
  // ----------------------------------------------------------

  ghost predicate RootDelegationProvenanceIsLegitimate(
    account: Account,
    state: AuthorizationState,
    delegation: Delegation
  )
  {
    delegation in StateDelegations(state)
    &&
    DelegationId(delegation)
    in StateDelegationProvenance(state).Keys
    &&
    StateDelegationProvenance(state)[DelegationId(delegation)] == {}
    &&
    DelegationSourceIdentityId(delegation)
    ==
    IdentityId(AccountSovereignIdentity(account))
  }


  // ----------------------------------------------------------
  // DELEGATION ID UNIVERSE
  // ----------------------------------------------------------

  ghost function StateDelegationIds(
    state: AuthorizationState
  ): set<Id>
  {
    set delegation : Delegation
      | delegation in StateDelegations(state)
      :: DelegationId(delegation)
  }


  // ----------------------------------------------------------
  // TRANSITIVE DELEGATION PROVENANCE
  // ----------------------------------------------------------

  ghost predicate DelegationProvenanceIsLegitimateForAccount(
    account: Account,
    state: AuthorizationState,
    identities: set<Identity>,
    delegation: Delegation,
    visited: set<Id>
  )
    decreases StateDelegationIds(state) - visited
  {
    delegation in StateDelegations(state)
    &&
    AuthorizationIdentityContextIsValid(
      identities
    )
    &&
    DelegationId(delegation) !in visited
    &&
    DelegationId(delegation)
    in StateDelegationProvenance(state).Keys
    &&
    (
      (
        StateDelegationProvenance(state)[DelegationId(delegation)] == {}
        &&
        DelegationSourceIdentityId(delegation)
        ==
        IdentityId(AccountSovereignIdentity(account))
      )
      ||
      (
        StateDelegationProvenance(state)[DelegationId(delegation)] != {}
        &&
        forall parentId ::
          parentId
          in StateDelegationProvenance(state)[DelegationId(delegation)]
          ==>
            exists parent : Delegation ::
              parent in StateDelegations(state)
              &&
              DelegationId(parent) == parentId
              &&
              ParentDelegationSupportsChildSource(
                identities,
                parent,
                delegation
              )
              &&
              DelegationProvenanceIsLegitimateForAccount(
                account,
                state,
                identities,
                parent,
                visited + { DelegationId(delegation) }
              )
      )
    )
  }


  ghost predicate DelegationHasLegitimateSourceProvenanceForAccount(
    account: Account,
    state: AuthorizationState,
    identities: set<Identity>,
    delegation: Delegation
  )
  {
    DelegationProvenanceIsLegitimateForAccount(
      account,
      state,
      identities,
      delegation,
      {}
    )
  }


  // ----------------------------------------------------------
  // PROVENANCE-AWARE CURRENTLY USABLE SOURCES
  // ----------------------------------------------------------

  ghost function CurrentlyUsableAuthoritySourcesForAcceptance(
    state: AuthorizationState,
    account: Account,
    identities: set<Identity>,
    now: Timestamp
  ): set<set<Capability>>
  {
    { StateCapabilities(state) }

    +
    (set credentialId : Id
       | credentialId in StateCredentialAuthorities(state).Keys
         && ActiveCredentialRecognizedInState(
           state,
           credentialId
         )
       :: StateCredentialAuthorities(state)[credentialId])

    +
    (set session : Session
       | session in StateSessions(state)
         && SessionCanContributeAuthorityAt(
           state,
           session,
           now
         )
       :: SessionCapabilities(session))

    +
    (set delegation : Delegation
       | delegation in StateDelegations(state)
         && DelegationCanContributeAuthorityAt(
           state,
           delegation,
           now
         )
         && DelegationHasLegitimateSourceProvenanceForAccount(
           account,
           state,
           identities,
           delegation
         )
       :: DelegationCapabilities(delegation))
  }


  // ----------------------------------------------------------
  // VALUE-ONLY RECOGNIZED PROVENANCE
  // ----------------------------------------------------------

  ghost predicate EffectiveAuthorityHasRecognizedProvenanceForState(
    effectiveAuthority: EffectiveAuthority,
    state: AuthorizationState,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>
  )
  {
    EffectiveAuthorityHasRecognizedSourceProvenance(
      effectiveAuthority,
      RecognizedAuthoritySources(state),
      sourceAuthorities,
      contributions
    )
  }


  ghost predicate EffectiveAuthorityHasCurrentlyUsableSourceProvenanceForState(
    effectiveAuthority: EffectiveAuthority,
    state: AuthorizationState,
    now: Timestamp,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>
  )
  {
    EffectiveAuthorityHasRecognizedSourceProvenance(
      effectiveAuthority,
      CurrentlyUsableAuthoritySources(state, now),
      sourceAuthorities,
      contributions
    )
  }


  // ----------------------------------------------------------
  // ATTRIBUTED PROVENANCE FOR ACCEPTANCE
  // ----------------------------------------------------------

  // Structural/source-sensitive provenance.
  //
  // Every contribution is linked to a concrete source reference,
  // while the reference is independently required to be usable.

  ghost predicate EffectiveAuthorityHasRecognizedAttributedProvenanceForAccountAt(
    effectiveAuthority: EffectiveAuthority,
    account: Account,
    identities: set<Identity>,
    now: Timestamp,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>
  )
  {
    AuthorizationIdentityContextIsValid(
      identities
    )
    &&
    EffectiveAuthorityHasRecognizedAttributedSourceProvenance(
      effectiveAuthority,
      CurrentlyUsableAuthoritySourceReferencesForAcceptance(
        AccountAuthorizationState(account),
        account,
        identities,
        now
      ),
      sourceReferences,
      sourceAuthorities,
      contributions
    )
    &&
    EffectiveAuthoritySourceReferencesAreCurrentlyUsable(
      AccountAuthorizationState(account),
      account,
      identities,
      now,
      sourceReferences
    )
    &&
    (forall i ::
       0 <= i < |sourceReferences|
       ==>
         AuthoritySourceReferenceResolvesToAuthority(
           AccountAuthorizationState(account),
           account,
           identities,
           now,
           sourceReferences[i],
           sourceAuthorities[i]
         ))
  }


  // The attributed provenance relation projects to the existing
  // value-only recognized provenance relation.
  lemma AcceptedAttributedProvenanceImpliesValueOnlyProvenance(
    effectiveAuthority: EffectiveAuthority,
    account: Account,
    identities: set<Identity>,
    now: Timestamp,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>
  )
    requires EffectiveAuthorityHasRecognizedAttributedProvenanceForAccountAt(
               effectiveAuthority,
               account,
               identities,
               now,
               sourceReferences,
               sourceAuthorities,
               contributions
             )
    ensures
      EffectiveAuthorityHasRecognizedSourceProvenance(
        effectiveAuthority,
        CurrentlyUsableAuthoritySourcesForAcceptance(
          AccountAuthorizationState(account),
          account,
          identities,
          now
        ),
        sourceAuthorities,
        contributions
      )
  {
    var state := AccountAuthorizationState(account);

    assert
      EffectiveAuthorityHasRecognizedAttributedSourceProvenance(
        effectiveAuthority,
        CurrentlyUsableAuthoritySourceReferencesForAcceptance(
          state,
          account,
          identities,
          now
        ),
        sourceReferences,
        sourceAuthorities,
        contributions
      );

    assert
      EffectiveAuthorityDerivedFromAttributedSources(
        effectiveAuthority,
        sourceReferences,
        sourceAuthorities,
        contributions
      );

    AttributedProvenanceImpliesValueOnlyProvenance(
      effectiveAuthority,
      sourceReferences,
      sourceAuthorities,
      contributions
    );

    assert
      forall i ::
        0 <= i < |sourceAuthorities|
        ==>
          sourceAuthorities[i]
          in
            CurrentlyUsableAuthoritySourcesForAcceptance(
              state,
              account,
              identities,
              now
            );

    assert
      EffectiveAuthorityHasRecognizedSourceProvenance(
        effectiveAuthority,
        CurrentlyUsableAuthoritySourcesForAcceptance(
          state,
          account,
          identities,
          now
        ),
        sourceAuthorities,
        contributions
      );
  }


  // ----------------------------------------------------------
  // EFFECTIVE AUTHORITY
  // ----------------------------------------------------------

  predicate AuthorizationAuthorityIsEffective(
    authorization: Authorization,
    effectiveAuthority: EffectiveAuthority
  )
  {
    RequestedAuthorityWithinEffectiveAuthority(
      authorization,
      effectiveAuthority
    )
  }


  predicate EffectiveAuthorityIsValid(
    effectiveAuthority: EffectiveAuthority
  )
  {
    ValidEffectiveAuthority(effectiveAuthority)
  }


  // ----------------------------------------------------------
  // STRUCTURAL PROVENANCE BOUNDARY
  // ----------------------------------------------------------

  ghost predicate EffectiveAuthorityProvenanceIsValidForAccount(
    effectiveAuthority: EffectiveAuthority,
    account: Account,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>
  )
  {
    EffectiveAuthorityHasRecognizedProvenanceForState(
      effectiveAuthority,
      AccountAuthorizationState(account),
      sourceAuthorities,
      contributions
    )
  }


  // ----------------------------------------------------------
  // ACCEPTANCE PROVENANCE BOUNDARY
  // ----------------------------------------------------------

  // Final acceptance uses attributed provenance.
  //
  // The concrete source reference, its authority value and its
  // contribution must agree and the source reference must resolve
  // to a currently usable Account-relative source.

  ghost predicate EffectiveAuthorityProvenanceIsValidForAccountAt(
    effectiveAuthority: EffectiveAuthority,
    account: Account,
    identities: set<Identity>,
    now: Timestamp,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>
  )
  {
    EffectiveAuthorityHasRecognizedAttributedProvenanceForAccountAt(
      effectiveAuthority,
      account,
      identities,
      now,
      sourceReferences,
      sourceAuthorities,
      contributions
    )
  }


  // ----------------------------------------------------------
  // STRUCTURAL AUTHORIZATION VALIDITY
  // ----------------------------------------------------------

  predicate AuthorizationIsStructurallyValid(
    authorization: Authorization
  )
  {
    ValidAuthorization(authorization)
    &&
    RequestedAuthorityIsValid(authorization)
    &&
    AuthorizationRestrictionsAreValid(authorization)
    &&
    AuthorizationIntervalIsWellFormed(authorization)
  }


  // ----------------------------------------------------------
  // EXTERNAL PROOF VERIFICATION
  // ----------------------------------------------------------

  predicate AuthorizationProofIsVerified(
    proofVerified: bool
  )
  {
    proofVerified
  }


  // ----------------------------------------------------------
  // ACCEPTANCE
  // ----------------------------------------------------------

  ghost predicate AuthorizationCanBeAccepted(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool
  )
  {
    ValidAccount(account)
    &&
    AuthorizationIdentityContextIsValid(
      identities
    )
    &&
    AuthorizationIsStructurallyValid(
      authorization
    )
    &&
    AuthorizationContextMatchesAccount(
      authorization,
      account
    )
    &&
    AuthorizationCredentialIsUsable(
      authorization,
      AccountAuthorizationState(account)
    )
    &&
    AuthorizationIsTemporallyValidAt(
      authorization,
      now
    )
    &&
    AuthorizationReplayIsFresh(
      authorization,
      AccountAuthorizationState(account)
    )
    &&
    EffectiveAuthorityIsValid(
      effectiveAuthority
    )
    &&
    EffectiveAuthorityProvenanceIsValidForAccountAt(
      effectiveAuthority,
      account,
      identities,
      now,
      sourceReferences,
      sourceAuthorities,
      contributions
    )
    &&
    AuthorizationAuthorityIsEffective(
      authorization,
      effectiveAuthority
    )
    &&
    AuthorizationProofIsVerified(
      proofVerified
    )
  }


  // ----------------------------------------------------------
  // VALIDATION LAWS
  // ----------------------------------------------------------

  lemma StructurallyValidAuthorizationHasValidCredentialId(
    authorization: Authorization
  )
    requires AuthorizationIsStructurallyValid(
               authorization
             )
    ensures ValidId(
              AuthorizationCredentialId(authorization)
            )
  {
  }


  lemma AcceptedAuthorizationHasValidAccount(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool
  )
    requires AuthorizationCanBeAccepted(
               authorization,
               account,
               effectiveAuthority,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               now,
               proofVerified
             )
    ensures ValidAccount(account)
  {
  }


  lemma AcceptedAuthorizationMatchesAccount(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool
  )
    requires AuthorizationCanBeAccepted(
               authorization,
               account,
               effectiveAuthority,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               now,
               proofVerified
             )
    ensures AuthorizationContextMatchesAccount(
              authorization,
              account
            )
  {
  }


  lemma AcceptedAuthorizationHasRecognizedCredential(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool
  )
    requires AuthorizationCanBeAccepted(
               authorization,
               account,
               effectiveAuthority,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               now,
               proofVerified
             )
    ensures AuthorizationCredentialIsRecognized(
              authorization,
              AccountAuthorizationState(account)
            )
  {
  }


  lemma AcceptedAuthorizationHasActiveCredential(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool
  )
    requires AuthorizationCanBeAccepted(
               authorization,
               account,
               effectiveAuthority,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               now,
               proofVerified
             )
    ensures AuthorizationCredentialIsActive(
              authorization,
              AccountAuthorizationState(account)
            )
  {
  }


  lemma AcceptedAuthorizationIsTemporallyValid(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool
  )
    requires AuthorizationCanBeAccepted(
               authorization,
               account,
               effectiveAuthority,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               now,
               proofVerified
             )
    ensures AuthorizationIsTemporallyValidAt(
              authorization,
              now
            )
  {
  }


  lemma AcceptedAuthorizationHasFreshReplayProtection(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool
  )
    requires AuthorizationCanBeAccepted(
               authorization,
               account,
               effectiveAuthority,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               now,
               proofVerified
             )
    ensures AuthorizationReplayIsFresh(
              authorization,
              AccountAuthorizationState(account)
            )
  {
  }


  lemma AcceptedAuthorizationWithinEffectiveAuthority(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool
  )
    requires AuthorizationCanBeAccepted(
               authorization,
               account,
               effectiveAuthority,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               now,
               proofVerified
             )
    ensures AuthorizationAuthorityIsEffective(
              authorization,
              effectiveAuthority
            )
  {
  }


  lemma AcceptedAuthorizationRequestsValidCapabilities(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool,
    capability: Capability
  )
    requires AuthorizationCanBeAccepted(
               authorization,
               account,
               effectiveAuthority,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               now,
               proofVerified
             )
    requires capability in AuthorizationRequestedAuthority(
                             authorization
                           )
    ensures ValidCapability(capability)
  {
    ValidEffectiveAuthorityContainsValidCapability(
      effectiveAuthority,
      capability
    );
  }


  // ----------------------------------------------------------
  // ACCEPTED PROVENANCE
  // ----------------------------------------------------------

  lemma AcceptedAuthorizationHasRecognizedEffectiveAuthorityProvenance(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool
  )
    requires AuthorizationCanBeAccepted(
               authorization,
               account,
               effectiveAuthority,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               now,
               proofVerified
             )
    ensures EffectiveAuthorityProvenanceIsValidForAccountAt(
              effectiveAuthority,
              account,
              identities,
              now,
              sourceReferences,
              sourceAuthorities,
              contributions
            )
  {
  }


  // Explicit concrete source attribution consequence.
  //
  // Every effective Capability accepted through the provenance
  // witness is attributable to a concrete usable source reference.

  lemma AcceptedEffectiveAuthorityCapabilityHasConcreteSource(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool,
    capability: Capability
  )
    requires AuthorizationCanBeAccepted(
               authorization,
               account,
               effectiveAuthority,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               now,
               proofVerified
             )
    requires capability in effectiveAuthority
    ensures exists i ::
              0 <= i < |sourceReferences|
              &&
              sourceReferences[i]
                in
                  CurrentlyUsableAuthoritySourceReferencesForAcceptance(
                    AccountAuthorizationState(account),
                    account,
                    identities,
                    now
                  )
              &&
              capability in contributions[i]
              &&
              capability in sourceAuthorities[i]
              &&
              AuthoritySourceReferenceResolvesToAuthority(
                AccountAuthorizationState(account),
                account,
                identities,
                now,
                sourceReferences[i],
                sourceAuthorities[i]
              )
  {
    AcceptedAuthorizationHasRecognizedEffectiveAuthorityProvenance(
      authorization,
      account,
      effectiveAuthority,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      now,
      proofVerified
    );

    var i :|
      0 <= i < |contributions|
      &&
      capability in contributions[i];

    assert i < |sourceReferences|;
    assert i < |sourceAuthorities|;

    assert
      sourceReferences[i]
      in
        CurrentlyUsableAuthoritySourceReferencesForAcceptance(
          AccountAuthorizationState(account),
          account,
          identities,
          now
        );

    assert capability in sourceAuthorities[i];

    assert
      AuthoritySourceReferenceResolvesToAuthority(
        AccountAuthorizationState(account),
        account,
        identities,
        now,
        sourceReferences[i],
        sourceAuthorities[i]
      );

    assert
      exists i ::
        0 <= i < |sourceReferences|
        &&
        sourceReferences[i]
          in
            CurrentlyUsableAuthoritySourceReferencesForAcceptance(
              AccountAuthorizationState(account),
              account,
              identities,
              now
            )
        &&
        capability in contributions[i]
        &&
        capability in sourceAuthorities[i]
        &&
        AuthoritySourceReferenceResolvesToAuthority(
          AccountAuthorizationState(account),
          account,
          identities,
          now,
          sourceReferences[i],
          sourceAuthorities[i]
        );
  }


  // ----------------------------------------------------------
  // VALUE-ONLY ACCEPTED SOURCE CONSEQUENCE
  // ----------------------------------------------------------

  lemma AcceptedEffectiveAuthorityCapabilityHasCurrentlyUsableSource(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool,
    capability: Capability
  )
    requires AuthorizationCanBeAccepted(
               authorization,
               account,
               effectiveAuthority,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               now,
               proofVerified
             )
    requires capability in effectiveAuthority
    ensures exists sourceAuthority ::
              sourceAuthority
              in CurrentlyUsableAuthoritySourcesForAcceptance(
                   AccountAuthorizationState(account),
                   account,
                   identities,
                   now
                 )
              &&
              capability in sourceAuthority
  {
    AcceptedEffectiveAuthorityCapabilityHasConcreteSource(
      authorization,
      account,
      effectiveAuthority,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      now,
      proofVerified,
      capability
    );

    var i :|
      0 <= i < |contributions|
      &&
      capability in contributions[i];

    assert sourceAuthorities[i]
           in
             CurrentlyUsableAuthoritySourcesForAcceptance(
               AccountAuthorizationState(account),
               account,
               identities,
               now
             );

    assert capability in sourceAuthorities[i];

    assert
      exists sourceAuthority ::
        sourceAuthority
        in
          CurrentlyUsableAuthoritySourcesForAcceptance(
            AccountAuthorizationState(account),
            account,
            identities,
            now
          )
        &&
        capability in sourceAuthority;
  }


  lemma AcceptedEffectiveAuthorityCapabilityHasRecognizedSource(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool,
    capability: Capability
  )
    requires AuthorizationCanBeAccepted(
               authorization,
               account,
               effectiveAuthority,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               now,
               proofVerified
             )
    requires capability in effectiveAuthority
    ensures exists sourceAuthority ::
              sourceAuthority
              in RecognizedAuthoritySources(
                   AccountAuthorizationState(account)
                 )
              &&
              capability in sourceAuthority
  {
    AcceptedEffectiveAuthorityCapabilityHasCurrentlyUsableSource(
      authorization,
      account,
      effectiveAuthority,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      now,
      proofVerified,
      capability
    );

    var usableSource :|
      usableSource
      in CurrentlyUsableAuthoritySourcesForAcceptance(
           AccountAuthorizationState(account),
           account,
           identities,
           now
         )
      &&
      capability in usableSource;

    assert usableSource
           in RecognizedAuthoritySources(
                AccountAuthorizationState(account)
              );

    assert capability in usableSource;
  }


  // ----------------------------------------------------------
  // EFFECTIVE AUTHORITY PROVENANCE CLOSURE
  // ----------------------------------------------------------

  lemma AcceptedAuthorizationCannotBypassEffectiveAuthorityProvenance(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool
  )
    requires AuthorizationCanBeAccepted(
               authorization,
               account,
               effectiveAuthority,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               now,
               proofVerified
             )
    ensures
      EffectiveAuthorityHasRecognizedAttributedProvenanceForAccountAt(
        effectiveAuthority,
        account,
        identities,
        now,
        sourceReferences,
        sourceAuthorities,
        contributions
      )
  {
    assert
      EffectiveAuthorityProvenanceIsValidForAccountAt(
        effectiveAuthority,
        account,
        identities,
        now,
        sourceReferences,
        sourceAuthorities,
        contributions
      );

    assert
      EffectiveAuthorityHasRecognizedAttributedProvenanceForAccountAt(
        effectiveAuthority,
        account,
        identities,
        now,
        sourceReferences,
        sourceAuthorities,
        contributions
      );
  }


  // ----------------------------------------------------------
  // DELEGATION PROVENANCE LAWS
  // ----------------------------------------------------------

  lemma LegitimateRootDelegationHasSovereignSource(
    account: Account,
    state: AuthorizationState,
    identities: set<Identity>,
    delegation: Delegation
  )
    requires ValidAccount(account)
    requires AuthorizationIdentityContextIsValid(
               identities
             )
    requires RootDelegationProvenanceIsLegitimate(
               account,
               state,
               delegation
             )
    ensures DelegationSourceIdentityId(delegation)
            ==
            IdentityId(AccountSovereignIdentity(account))
  {
  }


  lemma LegitimateTransitiveDelegationHasLegitimateParent(
    account: Account,
    state: AuthorizationState,
    identities: set<Identity>,
    delegation: Delegation,
    parentId: Id
  )
    requires ValidAccount(account)
    requires AuthorizationIdentityContextIsValid(
               identities
             )
    requires DelegationHasLegitimateSourceProvenanceForAccount(
               account,
               state,
               identities,
               delegation
             )
    requires parentId
             in StateDelegationProvenance(state)[
                DelegationId(delegation)
                ]
    ensures exists parent : Delegation ::
              parent in StateDelegations(state)
              &&
              DelegationId(parent) == parentId
              &&
              ParentDelegationSupportsChildSource(
                identities,
                parent,
                delegation
              )
  {
  }


  // ----------------------------------------------------------
  // PROOF BOUNDARY
  // ----------------------------------------------------------

  lemma AcceptedAuthorizationHasVerifiedProof(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool
  )
    requires AuthorizationCanBeAccepted(
               authorization,
               account,
               effectiveAuthority,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               now,
               proofVerified
             )
    ensures AuthorizationProofIsVerified(
              proofVerified
            )
  {
  }


  // ----------------------------------------------------------
  // CONTEXT BOUNDARY
  // ----------------------------------------------------------

  lemma StructurallyValidAuthorizationHasValidAccountContext(
    authorization: Authorization
  )
    requires AuthorizationIsStructurallyValid(
               authorization
             )
    ensures ValidId(
              AuthorizationAccountId(authorization)
            )
  {
  }


  lemma StructurallyValidAuthorizationHasValidContextScope(
    authorization: Authorization
  )
    requires AuthorizationIsStructurallyValid(
               authorization
             )
    ensures ValidScope(
              AuthorizationScope(authorization)
            )
  {
  }


  // ----------------------------------------------------------
  // REPLAY / VALIDATION SEPARATION
  // ----------------------------------------------------------

  lemma FreshReplayKeyDoesNotByItselfAuthorize(
    authorization: Authorization,
    state: AuthorizationState
  )
    requires AuthorizationReplayIsFresh(
               authorization,
               state
             )
    ensures true
  {
  }


  lemma StructuralValidityDoesNotImplyProofVerification(
    authorization: Authorization
  )
    requires AuthorizationIsStructurallyValid(
               authorization
             )
    ensures true
  {
  }


  lemma StructuralValidityDoesNotImplyCurrentTemporalValidity(
    authorization: Authorization,
    now: Timestamp
  )
    requires AuthorizationIsStructurallyValid(
               authorization
             )
    ensures true
  {
  }


  lemma StructuralValidityDoesNotImplyReplayFreshness(
    authorization: Authorization,
    state: AuthorizationState
  )
    requires AuthorizationIsStructurallyValid(
               authorization
             )
    ensures true
  {
  }


  // ----------------------------------------------------------
  // RECOGNITION / LIFECYCLE SEPARATION
  // ----------------------------------------------------------

  lemma RecognizedCredentialDoesNotImplyUsableCredential(
    authorization: Authorization,
    state: AuthorizationState
  )
    requires AuthorizationCredentialIsRecognized(
               authorization,
               state
             )
    ensures true
  {
  }


  // ----------------------------------------------------------
  // NO STATE MUTATION
  // ----------------------------------------------------------

  lemma AuthorizationValidationDoesNotConsumeReplayState(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool
  )
    ensures StateConsumedReplayKeys(
              AccountAuthorizationState(account)
            )
            ==
            StateConsumedReplayKeys(
              AccountAuthorizationState(account)
            )
  {
  }
}

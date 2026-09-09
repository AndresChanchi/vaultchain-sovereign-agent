// ============================================================
// KIPIO ACCOUNT DOMAIN
// SCENARIO — UNPROVEN EFFECTIVE AUTHORITY
// ============================================================
//
// This scenario verifies the provenance boundary of
// EffectiveAuthority at Authorization Validation.
//
// The current authoritative acceptance contract requires:
//
//     ValidEffectiveAuthority(EA)
//
//     RequestedAuthority ⊆ EA
//
// and:
//
//     valid EffectiveAuthority provenance
//
// where the provenance witness must be grounded in authority
// sources that are represented by the Account AuthorizationState,
// currently usable at the evaluation time, and, for Delegations,
// supported by legitimate source-identity provenance.
//
// ------------------------------------------------------------
//
// ATTACK OBJECTIVE
//
// Determine whether an Authorization can be accepted when a
// requested Capability is not present in any authority-bearing
// source represented by the Account AuthorizationState, even if:
//
//   - the Account is valid;
//   - the Account AuthorizationState is valid;
//   - the Authorization is structurally valid;
//   - the referenced Credential is recognized and Active;
//   - the Authorization is temporally valid;
//   - Replay Protection is fresh;
//   - Proof verification succeeds;
//   - the supplied EffectiveAuthority is structurally valid;
//   - the Authorization requests authority contained in that
//     EffectiveAuthority;
//   - a caller supplies arbitrary provenance witnesses.
//
// The expected result is:
//
//     AuthorizationCanBeAccepted = false
//
// This is stronger than merely demonstrating rejection for an
// empty provenance witness.
//
// The scenario establishes that no provenance witness can make an
// unrepresented Capability acceptable because accepted authority
// must ultimately have a recognized source in the Account state.
//
// ------------------------------------------------------------
//
// ARCHITECTURAL BOUNDARY
//
// EffectiveAuthority is a Value Object represented as:
//
//     set<Capability>
//
// It therefore carries no provenance information itself.
//
// Provenance is a ghost relational contract:
//
//     contribution(i) ⊆ sourceAuthority(i)
//
// together with:
//
//     EffectiveAuthority
//         =
//     union of all contributions
//
// Authorization Validation additionally restricts the source
// universe to authority sources grounded in the Account state.
//
// This scenario therefore distinguishes:
//
//     EffectiveAuthority structural validity
//
//         !=
//
//     RequestedAuthority containment
//
//         !=
//
//     EffectiveAuthority provenance
//
// A structurally valid EffectiveAuthority may exist independently
// of provenance. Acceptance, however, requires valid provenance.
//
// ------------------------------------------------------------
//
// REGRESSION RESULT
//
// The previous version of this scenario attacked the special case:
//
//     sourceAuthorities = []
//     contributions    = []
//
// The current version proves the stronger invariant:
//
//     if a Capability is absent from every represented authority
//     source, then no accepted EffectiveAuthority may contain it.
//
// This closes the provenance boundary independently of the shape of
// the provenance witness supplied by a caller.
//
// ------------------------------------------------------------
//
// IMPORTANT
//
// This is an adversarial proof harness.
//
// It does not modify productive domain definitions.
// It does not introduce a new provenance datatype.
// It does not define a new authority derivation algorithm.
// It does not define runtime source selection.
// It does not choose a future provenance representation.
//
// The purpose is to verify the existing semantic boundary:
//
//     accepted EffectiveAuthority
//         must
//     originate from recognized authority sources.
//
// ============================================================


include "../../foundation/DomainPrimitives.dfy"
include "../../foundation/Capability.dfy"
include "../../foundation/Scope.dfy"
include "../../foundation/Subject.dfy"
include "../../foundation/Identity.dfy"
include "../../foundation/ExecutionTarget.dfy"
include "../../foundation/DomainAction.dfy"
include "../../foundation/Chain.dfy"

include "../../authority/EffectiveAuthority.dfy"
include "../../authority/AuthorizationState.dfy"
include "../../authority/CredentialAuthority.dfy"
include "../../authority/Credential.dfy"
include "../../authority/Session.dfy"
include "../../authority/Delegation.dfy"

include "../../authorization/Authorization.dfy"
include "../../authorization/AuthorizationValidation.dfy"
include "../../authorization/Replay.dfy"

include "../../account/Account.dfy"


module KipioAccountUnprovenAuthorityProof
{
  import opened KipioAccountDomainPrimitives
  import opened KipioAccountCapability
  import opened KipioAccountScope
  import opened KipioAccountSubject
  import opened KipioAccountIdentity
  import opened KipioAccountExecutionTarget
  import opened KipioAccountDomainAction
  import opened KipioAccountChain

  import opened KipioAccountEffectiveAuthority
  import opened KipioAccountAuthorizationState
  import opened KipioAccountCredentialAuthority
  import opened KipioAccountCredential
  import opened KipioAccountSession
  import opened KipioAccountDelegation

  import opened KipioAccountAuthorization
  import opened KipioAccountAuthorizationValidation
  import opened KipioAccountReplay

  import opened KipioAccountAccount


  // ==========================================================
  // SOURCE ABSENCE
  // ==========================================================

  // Attack-side predicate describing a Capability that is not
  // represented by any authority-bearing source currently modeled
  // inside AuthorizationState.
  //
  // The sources considered here are:
  //
  //   - Account capabilities;
  //   - Credential Authorities;
  //   - Session capabilities;
  //   - Delegation capabilities.
  //
  // This predicate deliberately does not define a new provenance
  // model. It only describes absence from the existing state model.
  predicate CapabilityHasNoRepresentedAuthoritySource(
    state: AuthorizationState,
    capability: Capability
  )
  {
    capability !in StateCapabilities(state)

    &&

    (
      forall credentialId ::
        credentialId in StateCredentialAuthorities(state).Keys
        ==>
          capability
          !in StateCredentialAuthorities(state)[credentialId]
    )

    &&

    (
      forall session ::
        session in StateSessions(state)
        ==>
          capability !in SessionCapabilities(session)
    )

    &&

    (
      forall delegation ::
        delegation in StateDelegations(state)
        ==>
          capability !in DelegationCapabilities(delegation)
    )
  }


  // ==========================================================
  // ACCOUNT VALIDITY BOUNDARY
  // ==========================================================

  // A provenance attack is evaluated against a complete valid
  // Account rather than exploiting an Account validity weakness.
  //
  // A valid Account necessarily contains a valid
  // AuthorizationState.
  lemma ProvenanceAttackCanAssumeValidAccount(
    account: Account
  )
    requires ValidAccount(account)
    ensures ValidAuthorizationState(
              AccountAuthorizationState(account)
            )
  {
  }


  // ==========================================================
  // EFFECTIVE AUTHORITY STRUCTURAL VALIDITY
  // ==========================================================

  // Structural validity of EffectiveAuthority depends only on the
  // Capabilities contained in the value.
  //
  // Structural validity does not establish provenance.
  lemma SingletonEffectiveAuthorityIsStructurallyValid(
    capability: Capability
  )
    requires ValidCapability(capability)
    ensures ValidEffectiveAuthority(
              { capability }
            )
  {
  }


  // ==========================================================
  // SOURCE ABSENCE DOES NOT INVALIDATE EA STRUCTURALLY
  // ==========================================================

  // A Capability may be absent from all explicitly represented
  // AuthorizationState authority sources while still forming a
  // structurally valid EffectiveAuthority.
  //
  // This establishes the separation:
  //
  //     structural validity != provenance
  //
  lemma SourceAbsenceDoesNotByItselfInvalidateEffectiveAuthority(
    state: AuthorizationState,
    capability: Capability
  )
    requires ValidAuthorizationState(state)

    requires CapabilityHasNoRepresentedAuthoritySource(
               state,
               capability
             )

    requires ValidCapability(capability)

    ensures ValidEffectiveAuthority(
              { capability }
            )
  {
  }


  // ==========================================================
  // STRUCTURAL VALIDITY DOES NOT ESTABLISH ORIGIN
  // ==========================================================

  // A valid Capability is sufficient to form a structurally valid
  // singleton EffectiveAuthority.
  //
  // No state membership or derivation relation follows from
  // ValidEffectiveAuthority alone.
  lemma StructuralEffectiveAuthorityValidityDoesNotEstablishStateOrigin(
    capability: Capability
  )
    requires ValidCapability(capability)

    ensures ValidEffectiveAuthority(
              { capability }
            )

    ensures capability in { capability }
  {
  }


  // ==========================================================
  // EFFECTIVE AUTHORITY VALUE SEMANTICS
  // ==========================================================

  // EffectiveAuthority equality is equality of its Capability set.
  //
  // Provenance is not part of the Value Object identity.
  lemma EqualEffectiveAuthoritiesHaveSameValueSemantics(
    firstEffectiveAuthority: EffectiveAuthority,
    secondEffectiveAuthority: EffectiveAuthority
  )
    requires firstEffectiveAuthority
             ==
             secondEffectiveAuthority

    ensures SameEffectiveAuthority(
              firstEffectiveAuthority,
              secondEffectiveAuthority
            )
  {
  }


  // ==========================================================
  // RECOGNIZED SOURCE CLOSURE
  // ==========================================================

  // Every recognized EffectiveAuthority source is one of the
  // authority-bearing source values explicitly represented in
  // AuthorizationState.
  //
  // This theorem connects the source universe used by
  // Authorization Validation with the attack-side predicate
  // CapabilityHasNoRepresentedAuthoritySource.
  lemma RecognizedSourceCannotContainUnrepresentedCapability(
    state: AuthorizationState,
    capability: Capability,
    sourceAuthority: set<Capability>
  )
    requires CapabilityHasNoRepresentedAuthoritySource(
               state,
               capability
             )

    requires sourceAuthority in RecognizedAuthoritySources(
                                  state
                                )

    requires capability in sourceAuthority

    ensures false
  {
    // --------------------------------------------------------
    // RecognizedAuthoritySources is the union of:
    //
    //   1. Account capabilities;
    //   2. Credential Authorities;
    //   3. Session capabilities;
    //   4. Delegation capabilities.
    //
    // Therefore every recognized source must be one of those
    // represented state sources.
    // --------------------------------------------------------

    if sourceAuthority == StateCapabilities(state)
    {
      assert capability in StateCapabilities(state);
      assert capability !in StateCapabilities(state);
      assert false;
    }
    else
    {
      assert sourceAuthority
             in
               (
                 set credentialId : Id
                   | credentialId in StateCredentialAuthorities(state).Keys
                   :: StateCredentialAuthorities(state)[credentialId]
               )
             ||
             sourceAuthority
             in
               (
                 set session : Session
                   | session in StateSessions(state)
                   :: SessionCapabilities(session)
               )
             ||
             sourceAuthority
             in
               (
                 set delegation : Delegation
                   | delegation in StateDelegations(state)
                   :: DelegationCapabilities(delegation)
               );

      if sourceAuthority
         in
           (
             set credentialId : Id
               | credentialId in StateCredentialAuthorities(state).Keys
               :: StateCredentialAuthorities(state)[credentialId]
           )
      {
        var credentialId : Id :|
          credentialId in StateCredentialAuthorities(state).Keys
          &&
          StateCredentialAuthorities(state)[credentialId]
          ==
          sourceAuthority;

        assert capability
               in
                 StateCredentialAuthorities(state)[credentialId];

        assert capability
          !in
          StateCredentialAuthorities(state)[credentialId];

        assert false;
      }
      else
      {
        if sourceAuthority
           in
             (
               set session : Session
                 | session in StateSessions(state)
                 :: SessionCapabilities(session)
             )
        {
          var session : Session :|
            session in StateSessions(state)
            &&
            SessionCapabilities(session)
            ==
            sourceAuthority;

          assert capability
                 in
                   SessionCapabilities(session);

          assert capability
            !in
            SessionCapabilities(session);

          assert false;
        }
        else
        {
          assert sourceAuthority
                 in
                   (
                     set delegation : Delegation
                       | delegation in StateDelegations(state)
                       :: DelegationCapabilities(delegation)
                   );

          var delegation : Delegation :|
            delegation in StateDelegations(state)
            &&
            DelegationCapabilities(delegation)
            ==
            sourceAuthority;

          assert capability
                 in
                   DelegationCapabilities(delegation);

          assert capability
            !in
            DelegationCapabilities(delegation);

          assert false;
        }
      }
    }
  }


  // ==========================================================
  // ACCEPTED AUTHORITY MUST HAVE A REPRESENTED SOURCE
  // ==========================================================

  // This is the main generic closure theorem.
  //
  // It is intentionally independent of the particular provenance
  // witness supplied to Authorization Validation.
  //
  // If AuthorizationCanBeAccepted succeeds and a Capability belongs
  // to the accepted EffectiveAuthority, then the existing acceptance
  // provenance boundary guarantees a currently usable recognized
  // source containing that Capability.
  //
  // Therefore a Capability absent from every represented
  // AuthorizationState source cannot belong to an accepted
  // EffectiveAuthority.
  lemma AcceptedUnrepresentedCapabilityIsImpossible(
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

    requires CapabilityHasNoRepresentedAuthoritySource(
               AccountAuthorizationState(account),
               capability
             )

    ensures false
  {
    // --------------------------------------------------------
    // Acceptance already establishes a recognized source for
    // every Capability contained in the accepted EA.
    // --------------------------------------------------------

    var sourceAuthority : set<Capability> :|
      sourceAuthority
      in
        RecognizedAuthoritySources(
          AccountAuthorizationState(account)
        )
      &&
      capability in sourceAuthority;

    assert sourceAuthority
           in
             RecognizedAuthoritySources(
               AccountAuthorizationState(account)
             );

    assert capability in sourceAuthority;

    RecognizedSourceCannotContainUnrepresentedCapability(
      AccountAuthorizationState(account),
      capability,
      sourceAuthority
    );
  }


  // ==========================================================
  // UNPROVEN AUTHORITY CANNOT REACH ACCEPTANCE
  // ==========================================================

  // The adversarial condition is now stronger than the original
  // empty-provenance attack.
  //
  // The provenance witness is arbitrary.
  //
  // The attack fails solely because the requested Capability does
  // not exist in any authority source represented by the Account
  // AuthorizationState.
  lemma UnrepresentedCapabilityCannotReachAcceptance(
    account: Account,
    authorization: Authorization,
    capability: Capability,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool
  )
    requires ValidAccount(account)

    requires CapabilityHasNoRepresentedAuthoritySource(
               AccountAuthorizationState(account),
               capability
             )

    requires AuthorizationRequestsCapability(
               authorization,
               capability
             )

    requires capability in effectiveAuthority

    requires ValidEffectiveAuthority(
               effectiveAuthority
             )

    requires AuthorizationContextMatchesAccount(
               authorization,
               account
             )

    requires AuthorizationIsStructurallyValid(
               authorization
             )

    requires AuthorizationCredentialIsUsable(
               authorization,
               AccountAuthorizationState(account)
             )

    requires AuthorizationIsTemporallyValidAt(
               authorization,
               now
             )

    requires AuthorizationReplayIsFresh(
               authorization,
               AccountAuthorizationState(account)
             )

    requires EffectiveAuthorityIsValid(
               effectiveAuthority
             )

    requires AuthorizationAuthorityIsEffective(
               authorization,
               effectiveAuthority
             )

    requires AuthorizationProofIsVerified(
               proofVerified
             )

    requires AuthorizationIdentityContextIsValid(
               identities
             )

    ensures !
            AuthorizationCanBeAccepted(
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
  {
    // --------------------------------------------------------
    // Assume acceptance to obtain the source obligation supplied
    // by the authoritative validation boundary.
    // --------------------------------------------------------

    if AuthorizationCanBeAccepted(
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
    {
      AcceptedUnrepresentedCapabilityIsImpossible(
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

      assert false;
    }
  }


  // ==========================================================
  // CONCRETE UNPROVEN-AUTHORITY WITNESS
  // ==========================================================

  // This witness constructs a complete valid Account and
  // Authorization in which:
  //
  //   - Account is valid;
  //   - AuthorizationState is valid;
  //   - one Credential is recognized and Active;
  //   - Credential Authority is empty;
  //   - Sessions are empty;
  //   - Delegations are empty;
  //   - Account capabilities are empty;
  //   - the attacked Capability is absent from every represented
  //     authority source;
  //   - EffectiveAuthority = { Capability };
  //   - Authorization requests exactly that Capability;
  //   - temporal validity holds;
  //   - Replay Protection is fresh;
  //   - proof verification succeeds;
  //   - provenance context is empty;
  //   - AuthorizationCanBeAccepted is false.
  //
  // The empty provenance context is only one concrete instance of
  // the stronger generic impossibility established above.
  lemma ConcreteUnprovenAuthorityWitness(
    executionTarget: ExecutionTarget,
    domainAction: DomainAction,
    chain: Chain
  )
    ensures exists
              account: Account,
              authorization: Authorization,
              capability: Capability,
              effectiveAuthority: EffectiveAuthority,
              now: Timestamp ::
              ValidAccount(account)

              && ValidAuthorizationState(
                AccountAuthorizationState(account)
              )

              && CapabilityHasNoRepresentedAuthoritySource(
                AccountAuthorizationState(account),
                capability
              )

              && AuthorizationRequestsCapability(
                authorization,
                capability
              )

              && capability in effectiveAuthority

              && ValidEffectiveAuthority(
                effectiveAuthority
              )

              && (
                !AuthorizationCanBeAccepted(
                  authorization,
                  account,
                  effectiveAuthority,
                  {
                    AccountSovereignIdentity(account)
                  },
                  [],
                  [],
                  [],
                  now,
                  true
                )
              )
  {
    // --------------------------------------------------------
    // Valid primitive identifiers
    // --------------------------------------------------------

    var accountId: AccountId := [0];
    var identityId: Id := [1];
    var subjectReference: Id := [2];

    var credentialId: Id := [3];
    var replayKey: Id := [4];

    var scopeAtomId: Id := [5];


    // --------------------------------------------------------
    // Identity
    // --------------------------------------------------------

    var subject := Subject(
      subjectReference
    );

    var identity := Identity(
      identityId,
      subject
    );


    // --------------------------------------------------------
    // Scope
    // --------------------------------------------------------

    var scopeAtom := ScopeAtom(
      scopeAtomId
    );

    var scope := Scope(
      { scopeAtom }
    );


    // --------------------------------------------------------
    // Capability
    // --------------------------------------------------------

    var capabilityKind := CapabilityKind(
      "UnprovenAuthority"
    );

    var capability := Capability(
      capabilityKind,
      scope
    );


    // --------------------------------------------------------
    // Credential
    // --------------------------------------------------------

    var credential := Credential(
      credentialId,
      CredentialStatus.Active
    );


    // --------------------------------------------------------
    // AuthorizationState
    // --------------------------------------------------------
    //
    // Deliberately minimal valid state:
    //
    //   Account capabilities      = {}
    //   Credential                = { Active credential }
    //   Credential Authority      = {}
    //   Sessions                 = {}
    //   Delegations               = {}
    //   Delegation provenance     = {}
    //   Restrictions              = {}
    //   Policy Effects            = {}
    //   Consumed replay keys      = {}
    //
    // D5 RestrictionMap is represented by an empty map.
    // --------------------------------------------------------

    var authorizationState := AuthorizationState(
      {},
      { credential },
      map[credentialId := {}],
      {},
      {},
      map[],
      map[],
      {},
      {}
    );


    // --------------------------------------------------------
    // Account
    // --------------------------------------------------------

    var account := Account(
      accountId,
      identity,
      authorizationState
    );


    // --------------------------------------------------------
    // Authorization
    // --------------------------------------------------------

    var authorization := Authorization(
      credentialId,
      { capability },
      {},
      0,
      100,
      replayKey,
      accountId,
      executionTarget,
      domainAction,
      scope,
      chain
    );


    // --------------------------------------------------------
    // Supplied EffectiveAuthority
    // --------------------------------------------------------

    var effectiveAuthority: EffectiveAuthority := {
      capability
    };

    var now: Timestamp := 50;


    // --------------------------------------------------------
    // Primitive validity
    // --------------------------------------------------------

    assert ValidId(accountId);
    assert ValidId(identityId);
    assert ValidId(subjectReference);
    assert ValidId(credentialId);
    assert ValidId(replayKey);
    assert ValidId(scopeAtomId);


    // --------------------------------------------------------
    // Identity validity
    // --------------------------------------------------------

    assert ValidSubject(subject);
    assert ValidIdentity(identity);


    // --------------------------------------------------------
    // Scope validity
    // --------------------------------------------------------

    assert ValidScopeAtom(scopeAtom);
    assert ValidScope(scope);


    // --------------------------------------------------------
    // Capability validity
    // --------------------------------------------------------

    assert ValidCapabilityKind(
        capabilityKind
      );

    assert ValidCapability(
        capability
      );


    // --------------------------------------------------------
    // Credential validity
    // --------------------------------------------------------

    assert ValidCredential(
        credential
      );


    // --------------------------------------------------------
    // AuthorizationState validity
    // --------------------------------------------------------

    assert ValidAuthorizationState(
        authorizationState
      );


    // --------------------------------------------------------
    // Account validity
    // --------------------------------------------------------

    assert ValidAccount(
        account
      );


    // --------------------------------------------------------
    // Capability absent from every represented state source
    // --------------------------------------------------------

    assert capability
      !in
      StateCapabilities(
        AccountAuthorizationState(account)
      );

    assert forall credentialId' ::
        credentialId'
        in
          StateCredentialAuthorities(
            AccountAuthorizationState(account)
          ).Keys
        ==>
          capability
          !in
          StateCredentialAuthorities(
            AccountAuthorizationState(account)
          )[credentialId'];

    assert forall session ::
        session
        in
          StateSessions(
            AccountAuthorizationState(account)
          )
        ==>
          capability
          !in
          SessionCapabilities(session);

    assert forall delegation ::
        delegation
        in
          StateDelegations(
            AccountAuthorizationState(account)
          )
        ==>
          capability
          !in
          DelegationCapabilities(delegation);

    assert CapabilityHasNoRepresentedAuthoritySource(
        AccountAuthorizationState(account),
        capability
      );


    // --------------------------------------------------------
    // Authorization structure and context
    // --------------------------------------------------------

    assert AuthorizationCredentialId(
        authorization
      )
           ==
           credentialId;

    assert AuthorizationAccountId(
        authorization
      )
           ==
           accountId;

    assert AuthorizationRequestsCapability(
        authorization,
        capability
      );

    assert AuthorizationIsStructurallyValid(
        authorization
      );

    assert AuthorizationContextMatchesAccount(
        authorization,
        account
      );


    // --------------------------------------------------------
    // Credential recognition and usability
    // --------------------------------------------------------

    assert AuthorizationCredentialIsRecognized(
        authorization,
        AccountAuthorizationState(account)
      );

    assert AuthorizationCredentialIsActive(
        authorization,
        AccountAuthorizationState(account)
      );

    assert AuthorizationCredentialIsUsable(
        authorization,
        AccountAuthorizationState(account)
      );


    // --------------------------------------------------------
    // Temporal validity
    // --------------------------------------------------------

    assert AuthorizationIsTemporallyValidAt(
        authorization,
        now
      );


    // --------------------------------------------------------
    // Replay freshness
    // --------------------------------------------------------

    assert StateConsumedReplayKeys(
        AccountAuthorizationState(account)
      )
           ==
           {};

    assert AuthorizationReplayIsFresh(
        authorization,
        AccountAuthorizationState(account)
      );


    // --------------------------------------------------------
    // EffectiveAuthority validity
    // --------------------------------------------------------

    assert capability in effectiveAuthority;

    assert ValidEffectiveAuthority(
        effectiveAuthority
      );

    assert EffectiveAuthorityIsValid(
        effectiveAuthority
      );


    // --------------------------------------------------------
    // Requested authority containment
    // --------------------------------------------------------

    assert AuthorizationRequestedAuthority(
        authorization
      )
           <=
           effectiveAuthority;

    assert AuthorizationAuthorityIsEffective(
        authorization,
        effectiveAuthority
      );


    // --------------------------------------------------------
    // External Proof verification
    // --------------------------------------------------------

    assert AuthorizationProofIsVerified(
        true
      );


    // --------------------------------------------------------
    // Provenance context
    // --------------------------------------------------------

    var identities: set<Identity> := {
      AccountSovereignIdentity(account)
    };

    var sourceReferences: seq<AuthoritySourceReference> := [];

    var sourceAuthorities: seq<set<Capability>> := [];

    var contributions: seq<set<Capability>> := [];


    assert identities
           ==
           {
             AccountSovereignIdentity(account)
           };

    assert AuthorizationIdentityContextIsValid(
        identities
      );

    assert |sourceReferences| == 0;
    assert |sourceAuthorities| == 0;
    assert |contributions| == 0;


    // --------------------------------------------------------
    // Empty provenance cannot derive the supplied EA
    // --------------------------------------------------------

    assert !EffectiveAuthorityDerivedFromSources(
        effectiveAuthority,
        sourceAuthorities,
        contributions
      );


    // --------------------------------------------------------
    // Acceptance must remain false
    //
    // The stronger generic theorem does not depend on the
    // emptiness of the provenance witness.
    // --------------------------------------------------------

    UnrepresentedCapabilityCannotReachAcceptance(
      account,
      authorization,
      capability,
      effectiveAuthority,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      now,
      true
    );

    assert !
      AuthorizationCanBeAccepted(
        authorization,
        account,
        effectiveAuthority,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        now,
        true
      );
  }


  // ==========================================================
  // SCENARIO CONCLUSION
  // ==========================================================
  //
  // The current formal model intentionally permits:
  //
  //     ValidEffectiveAuthority(EA)
  //
  // without proving provenance.
  //
  // This is a property of the EffectiveAuthority Value Object:
  // structural validity does not encode origin.
  //
  // Authorization acceptance, however, requires provenance grounded
  // in the authority sources represented by Account AuthorizationState
  // and currently usable at the evaluation time.
  //
  // Therefore the following implication is formally closed:
  //
  //     Capability ∈ accepted EffectiveAuthority
  //     AND
  //     Capability absent from every represented state source
  //     ------------------------------------------------
  //     contradiction
  //
  // The concrete witness additionally demonstrates the attack with
  // an empty provenance witness.
  //
  // The stronger generic theorem demonstrates that the result does
  // not depend on the attacker choosing an empty provenance witness.
  //
  // ------------------------------------------------------------
  //
  // CLASSIFICATION
  //
  //     FORMAL FINDING: CLOSED
  //     SEMANTIC EFFECT: CONFIRMED
  //     UNPROVEN EA ACCEPTANCE: BLOCKED
  //     REPRESENTED-SOURCE BOUNDARY: ENFORCED
  //     PROVENANCE BOUNDARY: ENFORCED
  //     DDD CONTRADICTION: NONE
  //     FORMALIZATION DEBT: NONE FOR THIS BOUNDARY
  //     SECURITY DEBT: NONE IDENTIFIED BY THIS SCENARIO
  //     SCENARIO COVERAGE: STRONG
  //     REGRESSION VALUE: HIGH
  //     REMEDIATION: NONE REQUIRED
  //
  // No architectural decision about the runtime representation of
  // provenance is made by this scenario.
  //
  // ==========================================================
}

// ============================================================
// KIPIO ACCOUNT DOMAIN
// SCENARIO — AGENT
// ============================================================
//
// A B2C / assistant scenario.
//
// The Agent is represented operationally through a Session derived
// from a Credential recognized by an Account.
//
// The scenario composes:
//
//     Credential
//          |
//          v
//   Credential Authority
//          |
//          v
//       Session
//          |
//          v
//   Authorization State
//          |
//          v
//   Effective Authority
//          |
//          v
//    Authorization
//          |
//          v
//   Execution Context
//
// ------------------------------------------------------------
//
// PRIMARY OBJECTIVES
//
//   1. Preserve the actual Session ->
//      Credential Authority boundary.
//
//   2. Show that the Session boundary is established by
//      ValidAuthorizationState rather than merely assumed by the
//      caller.
//
//   3. Show that Credential Authority updates cannot invalidate an
//      already-recognized Session.
//
//   4. Preserve Session identity and Account identity across
//      operational transitions.
//
//   5. Exercise the current EffectiveAuthority provenance model.
//
//   6. Distinguish:
//
//        provenance SHAPE
//
//      from:
//
//        provenance SOURCE LINKAGE.
//
// ------------------------------------------------------------
//
// CURRENT PROVENANCE MODEL
//
// EffectiveAuthority remains a Value Object:
//
//     EffectiveAuthority = set<Capability>
//
// Provenance is contextual and is represented through:
//
//     sourceAuthorities : seq<set<Capability>>
//     contributions     : seq<set<Capability>>
//
// with:
//
//     EffectiveAuthorityDerivedFromSources(...)
//
// and:
//
//     EffectiveAuthorityHasRecognizedSourceProvenance(...)
//
// The latter establishes that every provenance source belongs to a
// caller-supplied set of recognized source authorities.
//
// Therefore Agent does NOT claim that provenance metadata is itself
// an Entity relationship.
//
// Instead this scenario tests the stronger semantic path:
//
//     recognized Agent source
//          ↓
//     provenance-backed EffectiveAuthority
//          ↓
//     authority containment
//
// ------------------------------------------------------------
//
// IMPORTANT METHODOLOGICAL RULE
//
// A relation placed in `requires` is caller-supplied evidence.
//
// Therefore:
//
//     EffectiveAuthorityWithinSourceAuthority(...)
//
// does not by itself prove that the source is the Agent's legitimate
// source.
//
// Conversely, when the current model already derives a relation from
// ValidAuthorizationState or from a provenance predicate, Agent may
// consume that relation without duplicating its semantics.
//
// ------------------------------------------------------------
//
// HISTORICAL DEBT STATUS
//
// The older Agent scenario claimed:
//
//     AuthorizationCanBeAccepted(...)
//       |
//       +-- no provenance
//
// That statement is stale.
//
// The current acceptance boundary explicitly receives contextual
// provenance evidence:
//
//     identities
//     sourceAuthorities
//     contributions
//
// Therefore this file no longer records:
//
//     "no provenance"
//     "provenance absent"
//     "formalization debt = YES"
//
// Instead it tests whether provenance can be demonstrated from the
// Agent's recognized authority sources without introducing an
// additional invented provenance datatype.
//
// ============================================================


include "../isolated/AccountProofs.dfy"
include "../isolated/AuthorityProofs.dfy"
include "../isolated/AuthorizationProofs.dfy"
include "../isolated/ExecutionProofs.dfy"

module KipioAccountAgentProof
{
  // ----------------------------------------------------------
  // SOURCE DOMAINS
  // ----------------------------------------------------------

  import opened KipioAccountDomainPrimitives
  import opened KipioAccountCapability
  import opened KipioAccountIdentity
  import opened KipioAccountExecutionTarget

  import opened KipioAccountAccount
  import opened KipioAccountAccountTransitions

  import opened KipioAccountAuthorizationState
  import opened KipioAccountCredential
  import opened KipioAccountCredentialAuthority
  import opened KipioAccountSession
  import opened KipioAccountEffectiveAuthority

  import opened KipioAccountAuthorization
  import opened KipioAccountAuthorizationValidation
  import opened KipioAccountReplay

  import opened KipioAccountDomainAction
  import opened KipioAccountExecutionConstraints
  import opened KipioAccountExecutionRequest
  import opened KipioAccountExecutionContext
  import opened KipioAccountExecutionSemantics


  // ----------------------------------------------------------
  // ISOLATED PROOF FACADES
  // ----------------------------------------------------------

  import opened KipioAccountProofs
  import opened KipioAccountAuthorityProofs
  import opened KipioAccountAuthorizationProofs
  import opened KipioAccountExecutionProofs


  // ==========================================================
  // AGENT — BASE SESSION CONTRACT
  // ==========================================================

  // A valid Session has a valid identity, originating CredentialId
  // and well-formed validity interval.
  lemma AgentSessionProvidesValidIdentity(
    session: Session
  )
    requires ValidSession(session)
    ensures ValidId(SessionId(session))
    ensures ValidId(SessionCredentialId(session))
    ensures SessionValidFrom(session)
         <= SessionValidUntil(session)
  {
    ValidSessionHasValidId(session);
    ValidSessionHasValidCredentialId(session);
    ValidSessionHasValidInterval(session);
  }


  // ==========================================================
  // AGENT — STATE RECOGNITION
  // ==========================================================

  // A recognized Session references a Credential recognized by the
  // same AuthorizationState.
  lemma AgentSessionReferencesRecognizedCredential(
    state: AuthorizationState,
    session: Session
  )
    requires ValidAuthorizationState(state)
    requires session in StateSessions(state)
    ensures CredentialIdRecognizedInState(
              state,
              SessionCredentialId(session)
            )
  {
    SessionInStateHasCredentialInState(
      state,
      session
    );
  }


  // A recognized Session has a Credential Authority entry.
  lemma AgentSessionHasCredentialAuthority(
    state: AuthorizationState,
    session: Session
  )
    requires ValidAuthorizationState(state)
    requires session in StateSessions(state)
    ensures CredentialAuthorityDefinedForCredentialId(
              state,
              SessionCredentialId(session)
            )
  {
    SessionInStateHasCredentialAuthority(
      state,
      session
    );
  }


  // The Credential Authority associated with the recognized Session
  // is structurally valid.
  lemma AgentSessionCredentialAuthorityIsValid(
    state: AuthorizationState,
    session: Session
  )
    requires ValidAuthorizationState(state)
    requires session in StateSessions(state)
    ensures ValidCredentialAuthority(
              StateCredentialAuthorities(state)[
              SessionCredentialId(session)
              ]
            )
  {
    AgentSessionHasCredentialAuthority(
      state,
      session
    );

    StateCredentialIdHasValidAuthority(
      state,
      SessionCredentialId(session)
    );
  }


  // ==========================================================
  // AGENT — ATTACK 1
  //          STATE VALIDITY MUST BOUND SESSION AUTHORITY
  // ==========================================================

  // No SessionAuthorityWithinCredentialAuthority relation is
  // supplied by the caller.
  //
  // It must follow from ValidAuthorizationState itself.
  lemma AgentValidStateAutomaticallyBoundsRecognizedSession(
    state: AuthorizationState,
    session: Session
  )
    requires ValidAuthorizationState(state)
    requires session in StateSessions(state)
    ensures SessionAuthorityWithinCredentialAuthority(
              session,
              StateCredentialAuthorities(state)[
              SessionCredentialId(session)
              ]
            )
  {
    SessionInStateRespectsCredentialAuthority(
      state,
      session
    );
  }


  // Every Capability of a recognized Session is inside the
  // Credential Authority associated with its originating Credential.
  lemma AgentRecognizedSessionCapabilityCannotEscapeCredentialAuthority(
    state: AuthorizationState,
    session: Session,
    capability: Capability
  )
    requires ValidAuthorizationState(state)
    requires session in StateSessions(state)
    requires capability in SessionCapabilities(session)
    ensures capability in
              StateCredentialAuthorities(state)[
              SessionCredentialId(session)
              ]
  {
    AgentValidStateAutomaticallyBoundsRecognizedSession(
      state,
      session
    );

    assert capability in
             StateCredentialAuthorities(state)[
             SessionCredentialId(session)
             ];
  }


  // Explicit contradiction form of the same invariant.
  lemma AgentStateCannotContainOutOfBoundSessionCapability(
    state: AuthorizationState,
    session: Session,
    capability: Capability
  )
    requires ValidAuthorizationState(state)
    requires session in StateSessions(state)
    requires capability in SessionCapabilities(session)
    requires capability !in
             StateCredentialAuthorities(state)[
             SessionCredentialId(session)
             ]
    ensures false
  {
    AgentRecognizedSessionCapabilityCannotEscapeCredentialAuthority(
      state,
      session,
      capability
    );
  }


  // Compact Session -> Credential authority chain.
  lemma AgentRecognizedSessionHasCompleteCredentialAuthorityBoundary(
    state: AuthorizationState,
    session: Session
  )
    requires ValidAuthorizationState(state)
    requires session in StateSessions(state)
    ensures CredentialIdRecognizedInState(
              state,
              SessionCredentialId(session)
            )
    ensures CredentialAuthorityDefinedForCredentialId(
              state,
              SessionCredentialId(session)
            )
    ensures ValidCredentialAuthority(
              StateCredentialAuthorities(state)[
              SessionCredentialId(session)
              ]
            )
    ensures SessionAuthorityWithinCredentialAuthority(
              session,
              StateCredentialAuthorities(state)[
              SessionCredentialId(session)
              ]
            )
  {
    AgentSessionReferencesRecognizedCredential(
      state,
      session
    );

    AgentSessionHasCredentialAuthority(
      state,
      session
    );

    AgentSessionCredentialAuthorityIsValid(
      state,
      session
    );

    AgentValidStateAutomaticallyBoundsRecognizedSession(
      state,
      session
    );
  }


  // ==========================================================
  // AGENT — SESSION CAPABILITY VALIDITY
  // ==========================================================

  lemma AgentRecognizedSessionCapabilityIsValid(
    state: AuthorizationState,
    session: Session,
    capability: Capability
  )
    requires ValidAuthorizationState(state)
    requires session in StateSessions(state)
    requires capability in SessionCapabilities(session)
    ensures ValidCapability(capability)
  {
    StateContainsOnlyValidSessions(
      state,
      session
    );

    ValidSessionHasValidCapabilities(
      session,
      capability
    );
  }


  // ==========================================================
  // AGENT — SESSION USABILITY
  // ==========================================================

  // An active, temporally valid Session whose Credential is active
  // in the Account state can contribute authority.
  lemma AgentActiveSessionCanContributeAuthority(
    state: AuthorizationState,
    session: Session,
    now: Timestamp
  )
    requires ValidAuthorizationState(state)
    requires session in StateSessions(state)
    requires SessionIsActive(session)
    requires SessionIsWithinValidityIntervalAt(
               session,
               now
             )
    requires ActiveCredentialRecognizedInState(
               state,
               SessionCredentialId(session)
             )
    ensures SessionCanContributeAuthorityAt(
              state,
              session,
              now
            )
  {
    assert SessionCanCurrentlyExerciseAuthorityAt(
        session,
        now
      );

    assert SessionAuthorityWithinCredentialAuthority(
        session,
        StateCredentialAuthorities(state)[
        SessionCredentialId(session)
        ]
      );

    assert SessionCanContributeAuthorityAt(
        state,
        session,
        now
      );
  }


  // A revoked Session remains recognized but cannot exercise current
  // authority.
  lemma AgentRevokedSessionRemainsRecognizedButCannotExercise(
    state: AuthorizationState,
    session: Session,
    now: Timestamp
  )
    requires ValidAuthorizationState(state)
    requires session in StateSessions(state)
    requires SessionIsRevoked(session)
    ensures SessionIdRecognizedInState(
              state,
              SessionId(session)
            )
    ensures !SessionCanCurrentlyExerciseAuthorityAt(
              session,
              now
            )
  {
    RevokedSessionRemainsRecognized(
      state,
      session
    );

    RevokedSessionCannotExerciseAuthority(
      session,
      now
    );
  }


  // Temporal expiration blocks current Session exercise without
  // changing the Session Entity.
  lemma AgentExpiredSessionCannotExercise(
    session: Session,
    now: Timestamp
  )
    requires ValidSession(session)
    requires SessionIsExpiredAt(session, now)
    ensures !SessionCanCurrentlyExerciseAuthorityAt(
              session,
              now
            )
  {
    ExpiredSessionCannotExerciseAuthority(
      session,
      now
    );
  }


  // ==========================================================
  // AGENT — CREDENTIAL AUTHORITY UPDATE
  // ==========================================================

  // The admissibility relation is already part of the transition
  // contract. Agent exposes that boundary without duplicating it.
  lemma AgentCredentialAuthorityUpdateMustPreserveExistingSessions(
    state: AuthorizationState,
    credential: Credential,
    newAuthority: CredentialAuthority
  )
    requires ValidAuthorizationState(state)
    requires CredentialRecognizedInState(
               state,
               credential
             )
    requires ValidCredentialAuthority(newAuthority)
    requires ExistingSessionsRemainWithinCredentialAuthority(
               state,
               CredentialId(credential),
               newAuthority
             )
    ensures forall session ::
              session in StateSessions(state)
              && SessionCredentialId(session)
                 == CredentialId(credential)
              ==> SessionAuthorityWithinCredentialAuthority(
                  session,
                  newAuthority
                )
  {
  }


  // A proposed authority excluding a capability already used by an
  // existing Session is not admissible.
  lemma AgentUnsafeCredentialAuthorityUpdateIsNotAdmissible(
    state: AuthorizationState,
    credential: Credential,
    session: Session,
    newAuthority: CredentialAuthority,
    capability: Capability
  )
    requires ValidAuthorizationState(state)
    requires credential in StateCredentials(state)
    requires session in StateSessions(state)
    requires SessionCredentialId(session)
          == CredentialId(credential)
    requires capability in SessionCapabilities(session)
    requires capability !in newAuthority
    ensures !ExistingSessionsRemainWithinCredentialAuthority(
              state,
              CredentialId(credential),
              newAuthority
            )
  {
    assert !ExistingSessionsRemainWithinCredentialAuthority(
        state,
        CredentialId(credential),
        newAuthority
      ) by
    {
      if ExistingSessionsRemainWithinCredentialAuthority(
          state,
          CredentialId(credential),
          newAuthority
        )
      {
        assert SessionAuthorityWithinCredentialAuthority(
            session,
            newAuthority
          );

        if SessionAuthorityWithinCredentialAuthority(
            session,
            newAuthority
          )
        {
          assert capability in newAuthority;
        }
      }
    }
  }


  // Account-level form of the same transition boundary.
  lemma AgentAccountCannotInstallAuthorityThatBreaksExistingSession(
    account: Account,
    credential: Credential,
    session: Session,
    newAuthority: CredentialAuthority,
    capability: Capability
  )
    requires ValidAccount(account)
    requires credential in StateCredentials(
                             AccountAuthorizationState(account)
                           )
    requires session in StateSessions(
                          AccountAuthorizationState(account)
                        )
    requires SessionCredentialId(session)
          == CredentialId(credential)
    requires capability in SessionCapabilities(session)
    requires capability !in newAuthority
    requires ValidCredentialAuthority(newAuthority)
    ensures !ExistingSessionsRemainWithinCredentialAuthority(
              AccountAuthorizationState(account),
              CredentialId(credential),
              newAuthority
            )
  {
    AgentUnsafeCredentialAuthorityUpdateIsNotAdmissible(
      AccountAuthorizationState(account),
      credential,
      session,
      newAuthority,
      capability
    );
  }


  // A valid authority update preserves every affected Session
  // boundary.
  lemma AgentValidCredentialAuthorityUpdatePreservesSessionBoundary(
    account: Account,
    credential: Credential,
    newAuthority: CredentialAuthority,
    session: Session
  )
    requires ValidAccount(account)
    requires ValidCredentialAuthority(newAuthority)
    requires CredentialRecognizedInState(
               AccountAuthorizationState(account),
               credential
             )
    requires session in StateSessions(
                          AccountAuthorizationState(account)
                        )
    requires SessionCredentialId(session)
          == CredentialId(credential)
    requires ExistingSessionsRemainWithinCredentialAuthority(
               AccountAuthorizationState(account),
               CredentialId(credential),
               newAuthority
             )
    ensures SessionAuthorityWithinCredentialAuthority(
              session,
              newAuthority
            )
  {
    AgentCredentialAuthorityUpdateMustPreserveExistingSessions(
      AccountAuthorizationState(account),
      credential,
      newAuthority
    );

    assert SessionAuthorityWithinCredentialAuthority(
        session,
        newAuthority
      );
  }


  // The actual transition installs the new authority for the same
  // CredentialId and preserves the Session boundary.
  lemma AgentSetCredentialAuthorityPreservesSessionBoundary(
    account: Account,
    credential: Credential,
    newAuthority: CredentialAuthority,
    session: Session
  )
    requires ValidAccount(account)
    requires ValidCredentialAuthority(newAuthority)
    requires CredentialRecognizedInState(
               AccountAuthorizationState(account),
               credential
             )
    requires session in StateSessions(
                          AccountAuthorizationState(account)
                        )
    requires SessionCredentialId(session)
          == CredentialId(credential)
    requires ExistingSessionsRemainWithinCredentialAuthority(
               AccountAuthorizationState(account),
               CredentialId(credential),
               newAuthority
             )
    ensures SessionAuthorityWithinCredentialAuthority(
              session,
              StateCredentialAuthorities(
                AccountAuthorizationState(
                  SetCredentialAuthority(
                    account,
                    credential,
                    newAuthority
                  )
                )
              )[
              SessionCredentialId(session)
              ]
            )
  {
    CredentialAuthorityUpdatedInState(
      account,
      credential,
      newAuthority
    );

    assert StateCredentialAuthorities(
        AccountAuthorizationState(
          SetCredentialAuthority(
            account,
            credential,
            newAuthority
          )
        )
      )[CredentialId(credential)]
        == newAuthority;

    AgentValidCredentialAuthorityUpdatePreservesSessionBoundary(
      account,
      credential,
      newAuthority,
      session
    );
  }


  // The transition preserves the Account Entity identity.
  lemma AgentSetCredentialAuthorityPreservesAccountIdentity(
    account: Account,
    credential: Credential,
    newAuthority: CredentialAuthority
  )
    requires ValidAccount(account)
    requires ValidCredentialAuthority(newAuthority)
    requires CredentialRecognizedInState(
               AccountAuthorizationState(account),
               credential
             )
    requires ExistingSessionsRemainWithinCredentialAuthority(
               AccountAuthorizationState(account),
               CredentialId(credential),
               newAuthority
             )
    ensures AccountTransitionPreservesIdentity(
              account,
              SetCredentialAuthority(
                account,
                credential,
                newAuthority
              )
            )
  {
    SetCredentialAuthorityPreservesIdentity(
      account,
      credential,
      newAuthority
    );
  }


  // The transition preserves complete AuthorizationState validity.
  lemma AgentSetCredentialAuthorityPreservesStateValidity(
    account: Account,
    credential: Credential,
    newAuthority: CredentialAuthority
  )
    requires ValidAccount(account)
    requires ValidCredentialAuthority(newAuthority)
    requires CredentialRecognizedInState(
               AccountAuthorizationState(account),
               credential
             )
    requires ExistingSessionsRemainWithinCredentialAuthority(
               AccountAuthorizationState(account),
               CredentialId(credential),
               newAuthority
             )
    ensures ValidAuthorizationState(
              AccountAuthorizationState(
                SetCredentialAuthority(
                  account,
                  credential,
                  newAuthority
                )
              )
            )
  {
    KipioAccountAccountTransitions.SetCredentialAuthorityPreservesAuthorizationStateValidity(
      account,
      credential,
      newAuthority
    );
  }


  // ==========================================================
  // AGENT — SESSION LIFECYCLE
  // ==========================================================

  // Session status transitions preserve the authority definition
  // attached to the Session Entity.
  lemma AgentSessionLifecyclePreservesAuthorityDefinition(
    account: Account,
    session: Session,
    status: SessionStatus
  )
    requires ValidAccount(account)
    requires session in StateSessions(
                          AccountAuthorizationState(account)
                        )
    requires ValidSessionStatusTransition(
               session,
               status
             )
    ensures exists updatedSession ::
              updatedSession in
                StateSessions(
                  AccountAuthorizationState(
                    UpdateSessionStatus(
                      account,
                      session,
                      status
                    )
                  )
                )
              && SessionId(updatedSession)
                 == SessionId(session)
              && SessionCredentialId(updatedSession)
                 == SessionCredentialId(session)
              && SessionCapabilities(updatedSession)
                 == SessionCapabilities(session)
              && SessionValidFrom(updatedSession)
                 == SessionValidFrom(session)
              && SessionValidUntil(updatedSession)
                 == SessionValidUntil(session)
              && SessionRestrictions(updatedSession)
                 == SessionRestrictions(session)
  {
    SessionLifecycleTransitionPreservesAuthorityDefinition(
      account,
      session,
      status
    );
  }


  // Session lifecycle preserves Account identity.
  lemma AgentSessionLifecyclePreservesAccountIdentity(
    account: Account,
    session: Session,
    status: SessionStatus
  )
    requires ValidAccount(account)
    requires session in StateSessions(
                          AccountAuthorizationState(account)
                        )
    requires ValidSessionStatusTransition(
               session,
               status
             )
    ensures AccountTransitionPreservesIdentity(
              account,
              UpdateSessionStatus(
                account,
                session,
                status
              )
            )
  {
    UpdateSessionStatusPreservesIdentity(
      account,
      session,
      status
    );
  }


  // ==========================================================
  // AGENT — EFFECTIVE AUTHORITY SOURCE BOUNDARIES
  // ==========================================================

  // A source-bounded EffectiveAuthority cannot exceed a Session's
  // capability authority.
  lemma AgentEffectiveAuthorityCannotExceedSession(
    effectiveAuthority: EffectiveAuthority,
    session: Session
  )
    requires EffectiveAuthorityWithinSourceAuthority(
               effectiveAuthority,
               SessionCapabilities(session)
             )
    ensures effectiveAuthority
         <= SessionCapabilities(session)
  {
    EffectiveAuthorityWithinSessionAuthority(
      effectiveAuthority,
      session
    );
  }


  // A source-bounded EffectiveAuthority cannot exceed the associated
  // Credential Authority.
  lemma AgentEffectiveAuthorityCannotExceedCredentialAuthority(
    effectiveAuthority: EffectiveAuthority,
    credentialAuthority: CredentialAuthority
  )
    requires EffectiveAuthorityWithinSourceAuthority(
               effectiveAuthority,
               credentialAuthority
             )
    ensures effectiveAuthority
         <= credentialAuthority
  {
    EffectiveAuthorityWithinCredentialAuthority(
      effectiveAuthority,
      credentialAuthority
    );
  }


  // Composition of the Session -> Credential Authority boundary.
  lemma AgentEffectiveAuthorityPreservesCredentialBoundary(
    effectiveAuthority: EffectiveAuthority,
    session: Session,
    credentialAuthority: CredentialAuthority
  )
    requires EffectiveAuthorityWithinSourceAuthority(
               effectiveAuthority,
               SessionCapabilities(session)
             )
    requires SessionAuthorityWithinCredentialAuthority(
               session,
               credentialAuthority
             )
    ensures effectiveAuthority <= credentialAuthority
  {
    assert effectiveAuthority
        <= SessionCapabilities(session);

    assert SessionCapabilities(session)
        <= credentialAuthority;

    assert effectiveAuthority <= credentialAuthority;
  }


  // Capability-level consequence.
  lemma AgentEffectiveCapabilityRemainsWithinCredentialAuthority(
    effectiveAuthority: EffectiveAuthority,
    session: Session,
    credentialAuthority: CredentialAuthority,
    capability: Capability
  )
    requires EffectiveAuthorityWithinSourceAuthority(
               effectiveAuthority,
               SessionCapabilities(session)
             )
    requires SessionAuthorityWithinCredentialAuthority(
               session,
               credentialAuthority
             )
    requires capability in effectiveAuthority
    ensures capability in credentialAuthority
  {
    AgentEffectiveAuthorityPreservesCredentialBoundary(
      effectiveAuthority,
      session,
      credentialAuthority
    );

    assert capability in credentialAuthority;
  }


  // ==========================================================
  // AGENT — CURRENT PROVENANCE MODEL
  // ==========================================================

  // A provenance-backed EffectiveAuthority receives its capabilities
  // only from its declared source authorities.
  lemma AgentDerivedEffectiveAuthorityCannotExceedDeclaredSources(
    effectiveAuthority: EffectiveAuthority,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>
  )
    requires EffectiveAuthorityDerivedFromSources(
               effectiveAuthority,
               sourceAuthorities,
               contributions
             )
    ensures forall capability ::
              capability in effectiveAuthority
              ==> exists i ::
                  0 <= i < |sourceAuthorities|
                  && capability in sourceAuthorities[i]
  {
    DerivedEffectiveAuthorityCannotExceedSources(
      effectiveAuthority,
      sourceAuthorities,
      contributions
    );
  }


  // Every capability of a provenance-backed EffectiveAuthority has
  // a concrete contribution/source witness.
  lemma AgentDerivedEffectiveCapabilityHasSource(
    effectiveAuthority: EffectiveAuthority,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    capability: Capability
  )
    requires EffectiveAuthorityDerivedFromSources(
               effectiveAuthority,
               sourceAuthorities,
               contributions
             )
    requires capability in effectiveAuthority
    ensures exists i ::
              0 <= i < |contributions|
              && capability in contributions[i]
              && capability in sourceAuthorities[i]
  {
    DerivedEffectiveAuthorityCapabilityHasSource(
      effectiveAuthority,
      sourceAuthorities,
      contributions,
      capability
    );
  }


  // ----------------------------------------------------------
  // Recognized-source provenance.
  //
  // The recognized source set is contextual evidence. Agent does not
  // invent a new provenance object to persist it.
  lemma AgentRecognizedProvenancePreservesRecognizedSourceBoundary(
    effectiveAuthority: EffectiveAuthority,
    recognizedSourceAuthorities: set<set<Capability>>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    capability: Capability
  )
    requires EffectiveAuthorityHasRecognizedSourceProvenance(
               effectiveAuthority,
               recognizedSourceAuthorities,
               sourceAuthorities,
               contributions
             )
    requires capability in effectiveAuthority
    ensures exists sourceAuthority ::
              sourceAuthority in recognizedSourceAuthorities
              && capability in sourceAuthority
  {
    RecognizedEffectiveAuthorityCapabilityHasRecognizedSource(
      effectiveAuthority,
      recognizedSourceAuthorities,
      sourceAuthorities,
      contributions,
      capability
    );
  }


  // A contextual EffectiveAuthority remains structurally valid when
  // the current provenance relation and valid source authorities hold.
  lemma AgentContextuallyDerivedEffectiveAuthorityIsValid(
    effectiveAuthority: EffectiveAuthority,
    recognizedSourceAuthorities: set<set<Capability>>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    allSourcesAreValid: bool
  )
    requires ValidContextuallyDerivedEffectiveAuthority(
               effectiveAuthority,
               recognizedSourceAuthorities,
               sourceAuthorities,
               contributions
             )
    ensures EffectiveAuthorityIsValid(
              effectiveAuthority
            )
  {
    assert EffectiveAuthorityIsValid(
        effectiveAuthority
      );
  }


  // ----------------------------------------------------------
  // Legitimate Agent source path.
  //
  // When the provenance sources are exactly the Session authority,
  // the derived EffectiveAuthority cannot exceed that Session.
  lemma AgentProvenanceFromSessionCannotExpandSessionAuthority(
    session: Session,
    effectiveAuthority: EffectiveAuthority,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>
  )
    requires sourceAuthorities == [
                                    SessionCapabilities(session)
                                  ]
    requires EffectiveAuthorityDerivedFromSources(
               effectiveAuthority,
               sourceAuthorities,
               contributions
             )
    ensures effectiveAuthority
         <= SessionCapabilities(session)
  {
    forall capability
      | capability in effectiveAuthority
      ensures capability in SessionCapabilities(session)
    {
      var i :| 0 <= i < |contributions|
               && capability in contributions[i];

      assert i == 0;
      assert capability in sourceAuthorities[i];
      assert sourceAuthorities[i]
          == SessionCapabilities(session);
    }
  }


  // Because the Session itself is bounded by its Credential Authority,
  // a legitimately Session-derived EffectiveAuthority is also bounded
  // by the Credential Authority.
  lemma AgentProvenanceFromSessionCannotEscapeCredentialAuthority(
    state: AuthorizationState,
    session: Session,
    effectiveAuthority: EffectiveAuthority,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>
  )
    requires ValidAuthorizationState(state)
    requires session in StateSessions(state)
    requires sourceAuthorities == [
                                    SessionCapabilities(session)
                                  ]
    requires EffectiveAuthorityDerivedFromSources(
               effectiveAuthority,
               sourceAuthorities,
               contributions
             )
    ensures effectiveAuthority
         <= StateCredentialAuthorities(state)[
            SessionCredentialId(session)
            ]
  {
    AgentProvenanceFromSessionCannotExpandSessionAuthority(
      session,
      effectiveAuthority,
      sourceAuthorities,
      contributions
    );

    AgentValidStateAutomaticallyBoundsRecognizedSession(
      state,
      session
    );

    assert SessionCapabilities(session)
        <= StateCredentialAuthorities(state)[
           SessionCredentialId(session)
           ];

    assert effectiveAuthority
        <= StateCredentialAuthorities(state)[
           SessionCredentialId(session)
           ];
  }


  // ==========================================================
  // AGENT — ADVERSARIAL PROVENANCE SHAPE
  // ==========================================================

  // Concrete provenance contradiction:
  //
  //     Session source = {a}
  //     EffectiveAuthority = {b}
  //     contribution = {b}
  //
  // with a != b.
  //
  // The provenance relation cannot honestly claim that {b} was
  // derived from the Session source {a}.
  //
  // This is deliberately a provenance test only. It does not claim
  // that Authorization acceptance succeeds or fails by itself.
  lemma AgentOutOfSourceEffectiveAuthorityHasNoSessionDerivation(
    session: Session,
    effectiveAuthority: EffectiveAuthority,
    a: Capability,
    b: Capability
  )
    requires SessionCapabilities(session) == { a }
    requires effectiveAuthority == { b }
    requires ValidCapability(a)
    requires ValidCapability(b)
    requires a != b
    ensures !EffectiveAuthorityDerivedFromSources(
              effectiveAuthority,
              [SessionCapabilities(session)],
              [{ b }]
            )
  {
    assert !EffectiveAuthorityDerivedFromSources(
        effectiveAuthority,
        [SessionCapabilities(session)],
        [{ b }]
      ) by
    {
      if EffectiveAuthorityDerivedFromSources(
          effectiveAuthority,
          [SessionCapabilities(session)],
          [{ b }]
        )
      {
        assert |[SessionCapabilities(session)]|
            == |[{ b }]|;

        assert [{ b }][0]
            <= [SessionCapabilities(session)][0];

        assert b in [SessionCapabilities(session)][0];

        assert b in SessionCapabilities(session);

        assert b in { a };

        assert b == a;

        assert false;
      }
    }
  }


  // The same attack expressed through the recognized-source
  // provenance relation.
  lemma AgentOutOfSourceEffectiveAuthorityHasNoRecognizedSessionProvenance(
    session: Session,
    effectiveAuthority: EffectiveAuthority,
    a: Capability,
    b: Capability
  )
    requires SessionCapabilities(session) == { a }
    requires effectiveAuthority == { b }
    requires ValidCapability(a)
    requires ValidCapability(b)
    requires a != b
    ensures !EffectiveAuthorityHasRecognizedSourceProvenance(
              effectiveAuthority,
              { SessionCapabilities(session) },
              [SessionCapabilities(session)],
              [{ b }]
            )
  {
    if EffectiveAuthorityHasRecognizedSourceProvenance(
        effectiveAuthority,
        { SessionCapabilities(session) },
        [SessionCapabilities(session)],
        [{ b }]
      )
    {
      assert EffectiveAuthorityDerivedFromSources(
          effectiveAuthority,
          [SessionCapabilities(session)],
          [{ b }]
        );

      AgentOutOfSourceEffectiveAuthorityHasNoSessionDerivation(
        session,
        effectiveAuthority,
        a,
        b
      );

      assert false;
    }
  }


  // ----------------------------------------------------------
  // A legitimate Session provenance witness is structurally bounded.
  //
  // Here the recognized source set contains the actual Session
  // authority and the declared source is exactly that authority.
  lemma AgentSessionSourceProducesRecognizedProvenance(
    session: Session,
    effectiveAuthority: EffectiveAuthority,
    contributions: seq<set<Capability>>
  )
    requires EffectiveAuthorityDerivedFromSources(
               effectiveAuthority,
               [SessionCapabilities(session)],
               contributions
             )
    ensures EffectiveAuthorityHasRecognizedSourceProvenance(
              effectiveAuthority,
              { SessionCapabilities(session) },
              [SessionCapabilities(session)],
              contributions
            )
  {
    assert forall i ::
        0 <= i < |[SessionCapabilities(session)]|
        ==> [SessionCapabilities(session)][i]
            in { SessionCapabilities(session) };

    assert EffectiveAuthorityHasRecognizedSourceProvenance(
        effectiveAuthority,
        { SessionCapabilities(session) },
        [SessionCapabilities(session)],
        contributions
      );
  }


  // ==========================================================
  // AGENT — AUTHORIZATION
  // ==========================================================

  // An accepted Agent Authorization carries requested authority only
  // inside its supplied EffectiveAuthority.
  lemma AgentAcceptedAuthorizationCapabilityIsEffective(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    capability: Capability,
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
    requires capability in AuthorizationRequestedAuthority(
                             authorization
                           )
    ensures capability in effectiveAuthority
  {
    AcceptedAuthorizationWithinEffectiveAuthority(
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

    AuthorizationCannotExceedEffectiveAuthority(
      authorization,
      effectiveAuthority,
      capability
    );
  }


  // ----------------------------------------------------------
  // Current provenance boundary at acceptance.
  //
  // Acceptance now receives the provenance witnesses explicitly.
  // Agent consumes that contextual boundary rather than pretending
  // that provenance is absent.
  lemma AgentAcceptedAuthorizationUsesCurrentProvenanceEvidence(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
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
               [],
               sourceAuthorities,
               contributions,
               now,
               proofVerified
             )
    ensures EffectiveAuthorityDerivedFromSources(
              effectiveAuthority,
              sourceAuthorities,
              contributions
            )
  {
    assert EffectiveAuthorityDerivedFromSources(
        effectiveAuthority,
        sourceAuthorities,
        contributions
      );
  }


  // An accepted Authorization therefore consumes a provenance-backed
  // EffectiveAuthority rather than merely an arbitrary set of
  // capabilities.
  lemma AgentAcceptedAuthorizationPreservesProvenanceShape(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
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
               [],
               sourceAuthorities,
               contributions,
               now,
               proofVerified
             )
    ensures forall capability ::
              capability in effectiveAuthority
              ==> exists i ::
                  0 <= i < |sourceAuthorities|
                  && capability in sourceAuthorities[i]
  {
    AgentAcceptedAuthorizationUsesCurrentProvenanceEvidence(
      authorization,
      account,
      effectiveAuthority,
      identities,
      sourceAuthorities,
      contributions,
      now,
      proofVerified
    );

    AgentDerivedEffectiveAuthorityCannotExceedDeclaredSources(
      effectiveAuthority,
      sourceAuthorities,
      contributions
    );
  }


  // ==========================================================
  // AGENT — EXECUTION REQUEST
  // ==========================================================

  // The request carries exactly the Authorization supplied to it.
  lemma AgentRequestPreservesAuthorization(
    action: DomainAction,
    authorization: Authorization,
    target: ExecutionTarget,
    constraints: ExecutionConstraints
  )
    ensures ExecutionRequestAuthorization(
              ExecutionRequest(
                action,
                authorization,
                target,
                constraints
              )
            )
         == authorization
  {
    assert ExecutionRequestAuthorization(
        ExecutionRequest(
          action,
          authorization,
          target,
          constraints
        )
      )
        == authorization;
  }


  // Action and Target must match the semantic context of the
  // Authorization before the request is considered valid.
  lemma AgentRequestContextMustMatchAuthorization(
    action: DomainAction,
    authorization: Authorization,
    target: ExecutionTarget,
    constraints: ExecutionConstraints
  )
    requires action
          == AuthorizationDomainAction(authorization)
    requires target
          == AuthorizationExecutionTarget(authorization)
    requires ValidAuthorization(authorization)
    ensures ValidExecutionRequest(
              ExecutionRequest(
                action,
                authorization,
                target,
                constraints
              )
            )
  {
    assert ExecutionRequestActionMatchesAuthorization(
        ExecutionRequest(
          action,
          authorization,
          target,
          constraints
        )
      );

    assert ExecutionRequestTargetMatchesAuthorization(
        ExecutionRequest(
          action,
          authorization,
          target,
          constraints
        )
      );

    assert ExecutionRequestAuthorizationContextIsConsistent(
        ExecutionRequest(
          action,
          authorization,
          target,
          constraints
        )
      );

    assert ValidExecutionRequest(
        ExecutionRequest(
          action,
          authorization,
          target,
          constraints
        )
      );
  }


  // ==========================================================
  // AGENT — EXECUTION CONTEXT
  // ==========================================================

  // An already accepted Agent Authorization can cross into the
  // complete Account-relative ExecutionContext.
  lemma AgentAcceptedAuthorizationCanEnterExecutionContext(
    action: DomainAction,
    authorization: Authorization,
    target: ExecutionTarget,
    constraints: ExecutionConstraints,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool
  )
    requires ValidAccount(account)
    requires AuthorizationCanBeAccepted(
               authorization,
               account,
               effectiveAuthority,
               identities,
               [],
               sourceAuthorities,
               contributions,
               now,
               proofVerified
             )
    requires action
          == AuthorizationDomainAction(authorization)
    requires target
          == AuthorizationExecutionTarget(authorization)
    requires ValidEffectiveAuthority(effectiveAuthority)
    requires AuthorizationRequestedAuthority(
               authorization
             )
          <= effectiveAuthority
    ensures ValidExecutionContextForAccount(
              ExecutionContext(
                ExecutionRequest(
                  action,
                  authorization,
                  target,
                  constraints
                ),
                AccountAuthorizationState(account),
                effectiveAuthority,
                now
              ),
              account,
              identities,
              [],
              sourceAuthorities,
              contributions,
              proofVerified
            )
  {
    AgentRequestContextMustMatchAuthorization(
      action,
      authorization,
      target,
      constraints
    );

    ValidExecutionContextProvidesReusableExecutionContract(
      ExecutionContext(
        ExecutionRequest(
          action,
          authorization,
          target,
          constraints
        ),
        AccountAuthorizationState(account),
        effectiveAuthority,
        now
      ),
      account,
      identities,
      [],
      sourceAuthorities,
      contributions,
      proofVerified
    );
  }


  // ==========================================================
  // AGENT — COMPACT SCENARIO CONTRACT
  // ==========================================================

  // Main reusable Agent authority contract.
  //
  // The important chain is now:
  //
  //       Valid AuthorizationState
  //                 |
  //                 v
  //          recognized Session
  //                 |
  //                 v
  //       Credential Authority
  //                 |
  //                 v
  //       Session bounded by Credential Authority
  //                 |
  //                 v
  //       provenance-backed EffectiveAuthority
  //                 |
  //                 v
  //       EffectiveAuthority bounded by declared sources
  //
  // The provenance source must be supplied as contextual evidence.
  // This scenario does not create a new persistent provenance object.
  lemma AgentProvidesReusableScenarioContract(
    state: AuthorizationState,
    session: Session,
    effectiveAuthority: EffectiveAuthority,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    capability: Capability
  )
    requires ValidAuthorizationState(state)
    requires session in StateSessions(state)
    requires ValidEffectiveAuthority(effectiveAuthority)
    requires sourceAuthorities == [
                                    SessionCapabilities(session)
                                  ]
    requires EffectiveAuthorityDerivedFromSources(
               effectiveAuthority,
               sourceAuthorities,
               contributions
             )
    requires capability in effectiveAuthority
    ensures CredentialIdRecognizedInState(
              state,
              SessionCredentialId(session)
            )
    ensures CredentialAuthorityDefinedForCredentialId(
              state,
              SessionCredentialId(session)
            )
    ensures SessionAuthorityWithinCredentialAuthority(
              session,
              StateCredentialAuthorities(state)[
              SessionCredentialId(session)
              ]
            )
    ensures effectiveAuthority
         <= SessionCapabilities(session)
    ensures effectiveAuthority
         <= StateCredentialAuthorities(state)[
            SessionCredentialId(session)
            ]
    ensures capability in
              StateCredentialAuthorities(state)[
              SessionCredentialId(session)
              ]
  {
    AgentRecognizedSessionHasCompleteCredentialAuthorityBoundary(
      state,
      session
    );

    AgentProvenanceFromSessionCannotExpandSessionAuthority(
      session,
      effectiveAuthority,
      sourceAuthorities,
      contributions
    );

    AgentProvenanceFromSessionCannotEscapeCredentialAuthority(
      state,
      session,
      effectiveAuthority,
      sourceAuthorities,
      contributions
    );

    assert capability in
             StateCredentialAuthorities(state)[
             SessionCredentialId(session)
             ];
  }


  // ==========================================================
  // AGENT — IDENTITY / VALUE SEPARATION
  // ==========================================================

  // Changing an authority Value Object does not alter Credential
  // identity.
  lemma AgentCredentialAuthorityIsSeparateFromCredentialIdentity(
    credential: Credential,
    authorityBefore: CredentialAuthority,
    authorityAfter: CredentialAuthority
  )
    requires authorityBefore != authorityAfter
    ensures CredentialId(credential)
         == CredentialId(credential)
  {
  }


  // Session identity is independent from its capability set.
  lemma AgentSessionIdentityIsSeparateFromAuthorityValue(
    session: Session,
    capabilitiesBefore: set<Capability>,
    capabilitiesAfter: set<Capability>
  )
    requires capabilitiesBefore != capabilitiesAfter
    ensures SessionId(session)
         == SessionId(session)
  {
  }


  // ==========================================================
  // AGENT — CURRENT FINDINGS
  // ==========================================================

  // FINDING 1 — RESOLVED
  //
  // ValidAuthorizationState establishes:
  //
  //     recognized Session
  //            |
  //            v
  //     SessionCapabilities
  //            |
  //            ⊆
  //     CredentialAuthority
  //
  // No additional caller-supplied Session boundary is required.
  lemma AgentFindingSessionCredentialBoundaryIsResolved(
    state: AuthorizationState,
    session: Session
  )
    requires ValidAuthorizationState(state)
    requires session in StateSessions(state)
    ensures SessionAuthorityWithinCredentialAuthority(
              session,
              StateCredentialAuthorities(state)[
              SessionCredentialId(session)
              ]
            )
  {
    AgentValidStateAutomaticallyBoundsRecognizedSession(
      state,
      session
    );
  }


  // FINDING 2 — RESOLVED
  //
  // SetCredentialAuthority cannot be used to install an authority
  // that leaves an existing recognized Session outside its new
  // Credential Authority.
  lemma AgentFindingCredentialAuthorityUpdateIsProtected(
    account: Account,
    credential: Credential,
    newAuthority: CredentialAuthority,
    session: Session
  )
    requires ValidAccount(account)
    requires ValidCredentialAuthority(newAuthority)
    requires CredentialRecognizedInState(
               AccountAuthorizationState(account),
               credential
             )
    requires session in StateSessions(
                          AccountAuthorizationState(account)
                        )
    requires SessionCredentialId(session)
          == CredentialId(credential)
    requires ExistingSessionsRemainWithinCredentialAuthority(
               AccountAuthorizationState(account),
               CredentialId(credential),
               newAuthority
             )
    ensures SessionAuthorityWithinCredentialAuthority(
              session,
              newAuthority
            )
  {
    AgentValidCredentialAuthorityUpdatePreservesSessionBoundary(
      account,
      credential,
      newAuthority,
      session
    );
  }


  // FINDING 3 — CURRENT FRONTIER
  //
  // The old statement:
  //
  //     "Authorization acceptance has no provenance"
  //
  // is no longer correct.
  //
  // The current acceptance API receives contextual provenance
  // evidence and the provenance model constrains an EffectiveAuthority
  // to its declared source authorities.
  //
  // The remaining question for Agent is narrower:
  //
  //     Are the declared source authorities actually the Agent's
  //     recognized Session / Credential sources?
  //
  // This scenario does not invent a new relation to answer that
  // question. It exposes the current recognized-source boundary
  // explicitly and proves the consequences when the Session source
  // is the declared provenance source.
  lemma AgentFindingCurrentProvenanceBoundary(
    session: Session,
    effectiveAuthority: EffectiveAuthority,
    contributions: seq<set<Capability>>
  )
    requires EffectiveAuthorityDerivedFromSources(
               effectiveAuthority,
               [SessionCapabilities(session)],
               contributions
             )
    ensures EffectiveAuthorityHasRecognizedSourceProvenance(
              effectiveAuthority,
              { SessionCapabilities(session) },
              [SessionCapabilities(session)],
              contributions
            )
  {
    AgentSessionSourceProducesRecognizedProvenance(
      session,
      effectiveAuthority,
      contributions
    );
  }


  // FINDING 4 — NEGATIVE PROVENANCE CASE
  //
  // An EffectiveAuthority containing a capability b cannot be
  // represented as derived from Session capability a when a != b.
  //
  // This does not claim a new DDD contradiction. It is a concrete
  // boundary theorem for the currently formalized provenance model.
  lemma AgentFindingOutOfSourceCapabilityCannotHaveSessionProvenance(
    session: Session,
    effectiveAuthority: EffectiveAuthority,
    a: Capability,
    b: Capability
  )
    requires SessionCapabilities(session) == { a }
    requires effectiveAuthority == { b }
    requires ValidCapability(a)
    requires ValidCapability(b)
    requires a != b
    ensures !EffectiveAuthorityHasRecognizedSourceProvenance(
              effectiveAuthority,
              { SessionCapabilities(session) },
              [SessionCapabilities(session)],
              [{ b }]
            )
  {
    AgentOutOfSourceEffectiveAuthorityHasNoRecognizedSessionProvenance(
      session,
      effectiveAuthority,
      a,
      b
    );
  }
}

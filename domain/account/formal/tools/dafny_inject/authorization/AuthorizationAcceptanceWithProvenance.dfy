// ============================================================
// KIPIO ACCOUNT DOMAIN — INJECTED COMPOSITION
// AUTHORIZATION — ACCEPTANCE WITH PROVENANCE
// ============================================================
//
// Executable counterpart of the ghost provenance layer used by
// the ghost predicate AuthorizationCanBeAccepted.
//
// Background
// ----------
//
// AuthorizationCanBeAccepted (in authorization/AuthorizationValidation.dfy)
// is a ghost predicate that requires EffectiveAuthority to be
// accompanied by an attributed provenance witness:
//
//     sourceReferences
//     sourceAuthorities
//     contributions
//
// plus the set of identities resolving delegation sources against
// delegatee Subjects.
//
// The witness itself is computable; EffectiveAuthorityComposition
// produces it. This file provides the executable counterpart of
// the provenance acceptance conditions that
// AuthorizationCanBeAccepted asserts over that witness, and the
// single composed entrypoint AuthorizationCanBeAcceptedFull that
// constructs the witness and applies the executable acceptance.
//
// It does NOT redefine acceptance semantics. It is a computable
// counterpart of predicates already verified as ghost.
//
// ============================================================


include "../foundation/DomainPrimitives.dfy"
include "../foundation/Capability.dfy"
include "../foundation/Identity.dfy"

include "../authority/Credential.dfy"
include "../authority/CredentialAuthority.dfy"
include "../authority/Session.dfy"
include "../authority/Delegation.dfy"
include "../authority/EffectiveAuthority.dfy"
include "../authority/AuthorizationState.dfy"
include "../authority/EffectiveAuthorityComposition.dfy"

include "../account/Account.dfy"

include "Authorization.dfy"
include "AuthorizationValidation.dfy"


module KipioAccountAuthorizationAcceptanceWithProvenance {

    import opened KipioAccountDomainPrimitives
    import opened KipioAccountCapability
    import opened KipioAccountIdentity

    import opened KipioAccountCredential
    import opened KipioAccountCredentialAuthority
    import opened KipioAccountSession
    import opened KipioAccountDelegation
    import opened KipioAccountEffectiveAuthority
    import opened KipioAccountAuthorizationState

    import opened KipioAccountAccount

    import opened KipioAccountAuthorization
    import opened KipioAccountAuthorizationValidation

    import opened KipioAccountEffectiveAuthorityComposition


    // ==========================================================
    // EXECUTABLE — ATTRIBUTED DERIVATION
    // ==========================================================

    predicate EffectiveAuthorityDerivedFromAttributedSourcesExec(
        effectiveAuthority: EffectiveAuthority,
        sourceReferences: seq<AuthoritySourceReference>,
        sourceAuthorities: seq<set<Capability>>,
        contributions: seq<set<Capability>>
    )
    {
        |sourceReferences| == |sourceAuthorities|
        &&
        |sourceAuthorities| == |contributions|
        &&
        (forall i ::
            0 <= i < |sourceReferences|
            ==> ValidAuthoritySourceReference(sourceReferences[i]))
        &&
        (forall i ::
            0 <= i < |contributions|
            ==> contributions[i] <= sourceAuthorities[i])
        &&
        (forall capability | capability in effectiveAuthority ::
            exists i ::
                0 <= i < |contributions|
                && capability in contributions[i])
        &&
        (forall i ::
            0 <= i < |contributions|
            ==>
            forall capability | capability in contributions[i] ::
                capability in effectiveAuthority)
    }


    lemma DerivedFromAttributedSourcesExecMatchesGhost(
        effectiveAuthority: EffectiveAuthority,
        sourceReferences: seq<AuthoritySourceReference>,
        sourceAuthorities: seq<set<Capability>>,
        contributions: seq<set<Capability>>
    )
        ensures
            EffectiveAuthorityDerivedFromAttributedSourcesExec(
                effectiveAuthority, sourceReferences, sourceAuthorities, contributions
            )
            <==>
            EffectiveAuthorityDerivedFromAttributedSources(
                effectiveAuthority, sourceReferences, sourceAuthorities, contributions
            )
    { }


    // ==========================================================
    // EXECUTABLE — USABLE SOURCE REFERENCES UNIVERSE
    // ==========================================================

    function CurrentlyUsableAuthoritySourceReferencesForAcceptanceExec(
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
                && ActiveCredentialRecognizedInState(state, credentialId)
            :: AuthoritySourceReference(
                CredentialAuthoritySource,
                credentialId
            ))

        +
        (set session : Session
            | session in StateSessions(state)
                && SessionCanContributeAuthorityAt(state, session, now)
            :: AuthoritySourceReference(
                SessionAuthoritySource,
                SessionId(session)
            ))

        +
        (set delegation : Delegation
            | delegation in StateDelegations(state)
                && DelegationCanContributeAuthorityAt(state, delegation, now)
                && DelegationHasLegitimateSourceProvenanceForAccountExecutable(
                    account, state, identities, delegation
                )
            :: AuthoritySourceReference(
                DelegationAuthoritySource,
                DelegationId(delegation)
            ))
    }


    // ==========================================================
    // EXECUTABLE — SOURCE REFERENCE RESOLUTION
    // ==========================================================

    predicate AuthoritySourceReferenceResolvesToAuthorityExec(
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
                == AccountIdOf(account)
            &&
            sourceAuthority == StateCapabilities(state)

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
                == StateCredentialAuthorityById(
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
                SessionCanContributeAuthorityAt(state, session, now)
                &&
                sourceAuthority == SessionCapabilities(session)

        case DelegationAuthoritySource =>
            exists delegation : Delegation ::
                delegation in StateDelegations(state)
                &&
                DelegationId(delegation)
                    == AuthoritySourceReferenceId(sourceReference)
                &&
                DelegationCanContributeAuthorityAt(state, delegation, now)
                &&
                DelegationHasLegitimateSourceProvenanceForAccountExecutable(
                    account, state, identities, delegation
                )
                &&
                sourceAuthority == DelegationCapabilities(delegation)
    }


    lemma ResolvesToAuthorityExecMatchesGhost(
        state: AuthorizationState,
        account: Account,
        identities: set<Identity>,
        now: Timestamp,
        sourceReference: AuthoritySourceReference,
        sourceAuthority: set<Capability>
    )
        requires AuthorizationIdentityContextIsValidExecutable(identities)
        ensures
            AuthoritySourceReferenceResolvesToAuthorityExec(
                state, account, identities, now,
                sourceReference, sourceAuthority
            )
            <==>
            AuthoritySourceReferenceResolvesToAuthority(
                state, account, identities, now,
                sourceReference, sourceAuthority
            )
    {
        match AuthoritySourceReferenceKind(sourceReference) {
            case AccountAuthoritySource => { }
            case CredentialAuthoritySource => { }
            case SessionAuthoritySource => { }
            case DelegationAuthoritySource => {

                // Direction Exec ⇒ Ghost
                if AuthoritySourceReferenceResolvesToAuthorityExec(
                     state, account, identities, now,
                     sourceReference, sourceAuthority
                   )
                {
                    var delegation :| delegation in StateDelegations(state)
                        && DelegationId(delegation)
                           == AuthoritySourceReferenceId(sourceReference)
                        && DelegationCanContributeAuthorityAt(state, delegation, now)
                        && DelegationHasLegitimateSourceProvenanceForAccountExecutable(
                            account, state, identities, delegation
                        )
                        && sourceAuthority == DelegationCapabilities(delegation);

                    ExecutableMatchesGhostForDelegationProvenance(
                        account, state, identities, delegation, {}
                    );

                    assert DelegationHasLegitimateSourceProvenanceForAccount(
                        account, state, identities, delegation
                    );

                    assert AuthoritySourceReferenceResolvesToAuthority(
                        state, account, identities, now,
                        sourceReference, sourceAuthority
                    );
                }

                // Direction Ghost ⇒ Exec
                if AuthoritySourceReferenceResolvesToAuthority(
                     state, account, identities, now,
                     sourceReference, sourceAuthority
                   )
                {
                    var delegation :| delegation in StateDelegations(state)
                        && DelegationId(delegation)
                           == AuthoritySourceReferenceId(sourceReference)
                        && DelegationCanContributeAuthorityAt(state, delegation, now)
                        && DelegationHasLegitimateSourceProvenanceForAccount(
                            account, state, identities, delegation
                        )
                        && sourceAuthority == DelegationCapabilities(delegation);

                    ExecutableMatchesGhostForDelegationProvenance(
                        account, state, identities, delegation, {}
                    );

                    assert DelegationHasLegitimateSourceProvenanceForAccountExecutable(
                        account, state, identities, delegation
                    );

                    assert AuthoritySourceReferenceResolvesToAuthorityExec(
                        state, account, identities, now,
                        sourceReference, sourceAuthority
                    );
                }
            }
        }
    }


    // ==========================================================
    // EXECUTABLE — USABLE SOURCE REFERENCES (SEQUENCE)
    // ==========================================================

    predicate EffectiveAuthoritySourceReferencesAreCurrentlyUsableExec(
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
            in CurrentlyUsableAuthoritySourceReferencesForAcceptanceExec(
                state, account, identities, now
            )
    }


    // ==========================================================
    // HELPER — MEMBERSHIP EQUIVALENCE FOR SOURCE REFERENCES
    // ==========================================================
    //
    // The two sets differ only in the Delegation sub-comprehension:
    // the executable version filters with
    // DelegationHasLegitimateSourceProvenanceForAccountExecutable,
    // the ghost version filters with
    // DelegationHasLegitimateSourceProvenanceForAccount.
    //
    // By ExecutableMatchesGhostForDelegationProvenance these
    // filters are pointwise equivalent, hence the membership
    // predicates coincide.

    lemma InCurrentlyUsableSourceReferencesExecMatchesGhost(
        state: AuthorizationState,
        account: Account,
        identities: set<Identity>,
        now: Timestamp,
        sourceReference: AuthoritySourceReference
    )
        requires AuthorizationIdentityContextIsValidExecutable(identities)
        ensures
            (sourceReference in
                CurrentlyUsableAuthoritySourceReferencesForAcceptanceExec(
                    state, account, identities, now
                ))
            <==>
            (sourceReference in
                CurrentlyUsableAuthoritySourceReferencesForAcceptance(
                    state, account, identities, now
                ))
    {
        match AuthoritySourceReferenceKind(sourceReference) {
            case AccountAuthoritySource => { }
            case CredentialAuthoritySource => { }
            case SessionAuthoritySource => { }
            case DelegationAuthoritySource => {

                // Direction Exec ⇒ Ghost
                if sourceReference in
                    CurrentlyUsableAuthoritySourceReferencesForAcceptanceExec(
                        state, account, identities, now
                    )
                {
                    var delegation :| delegation in StateDelegations(state)
                        && DelegationCanContributeAuthorityAt(state, delegation, now)
                        && DelegationHasLegitimateSourceProvenanceForAccountExecutable(
                            account, state, identities, delegation
                        )
                        && sourceReference
                           == AuthoritySourceReference(
                                  DelegationAuthoritySource,
                                  DelegationId(delegation)
                              );

                    ExecutableMatchesGhostForDelegationProvenance(
                        account, state, identities, delegation, {}
                    );

                    assert DelegationHasLegitimateSourceProvenanceForAccount(
                        account, state, identities, delegation
                    );

                    assert sourceReference in
                        CurrentlyUsableAuthoritySourceReferencesForAcceptance(
                            state, account, identities, now
                        );
                }

                // Direction Ghost ⇒ Exec
                if sourceReference in
                    CurrentlyUsableAuthoritySourceReferencesForAcceptance(
                        state, account, identities, now
                    )
                {
                    var delegation :| delegation in StateDelegations(state)
                        && DelegationCanContributeAuthorityAt(state, delegation, now)
                        && DelegationHasLegitimateSourceProvenanceForAccount(
                            account, state, identities, delegation
                        )
                        && sourceReference
                           == AuthoritySourceReference(
                                  DelegationAuthoritySource,
                                  DelegationId(delegation)
                              );

                    ExecutableMatchesGhostForDelegationProvenance(
                        account, state, identities, delegation, {}
                    );

                    assert DelegationHasLegitimateSourceProvenanceForAccountExecutable(
                        account, state, identities, delegation
                    );

                    assert sourceReference in
                        CurrentlyUsableAuthoritySourceReferencesForAcceptanceExec(
                            state, account, identities, now
                        );
                }
            }
        }
    }


    lemma SourceReferencesAreCurrentlyUsableExecMatchesGhost(
        state: AuthorizationState,
        account: Account,
        identities: set<Identity>,
        now: Timestamp,
        sourceReferences: seq<AuthoritySourceReference>
    )
        requires AuthorizationIdentityContextIsValidExecutable(identities)
        ensures
            EffectiveAuthoritySourceReferencesAreCurrentlyUsableExec(
                state, account, identities, now, sourceReferences
            )
            <==>
            EffectiveAuthoritySourceReferencesAreCurrentlyUsable(
                state, account, identities, now, sourceReferences
            )
    {
        // Direction Exec ⇒ Ghost
        if EffectiveAuthoritySourceReferencesAreCurrentlyUsableExec(
             state, account, identities, now, sourceReferences
           )
        {
            forall i | 0 <= i < |sourceReferences|
                ensures sourceReferences[i] in
                    CurrentlyUsableAuthoritySourceReferencesForAcceptance(
                        state, account, identities, now
                    )
            {
                InCurrentlyUsableSourceReferencesExecMatchesGhost(
                    state, account, identities, now, sourceReferences[i]
                );
            }
        }

        // Direction Ghost ⇒ Exec
        if EffectiveAuthoritySourceReferencesAreCurrentlyUsable(
             state, account, identities, now, sourceReferences
           )
        {
            forall i | 0 <= i < |sourceReferences|
                ensures sourceReferences[i] in
                    CurrentlyUsableAuthoritySourceReferencesForAcceptanceExec(
                        state, account, identities, now
                    )
            {
                InCurrentlyUsableSourceReferencesExecMatchesGhost(
                    state, account, identities, now, sourceReferences[i]
                );
            }
        }
    }


    // ==========================================================
    // EXECUTABLE — ATTRIBUTED PROVENANCE FOR ACCOUNT
    // ==========================================================

    predicate EffectiveAuthorityHasRecognizedAttributedProvenanceForAccountAtExec(
        effectiveAuthority: EffectiveAuthority,
        account: Account,
        identities: set<Identity>,
        now: Timestamp,
        sourceReferences: seq<AuthoritySourceReference>,
        sourceAuthorities: seq<set<Capability>>,
        contributions: seq<set<Capability>>
    )
    {
        var state := AccountAuthorizationState(account);

        AuthorizationIdentityContextIsValidExecutable(identities)
        &&
        EffectiveAuthorityDerivedFromAttributedSourcesExec(
            effectiveAuthority,
            sourceReferences,
            sourceAuthorities,
            contributions
        )
        &&
        EffectiveAuthoritySourceReferencesAreCurrentlyUsableExec(
            state, account, identities, now, sourceReferences
        )
        &&
        (forall i ::
            0 <= i < |sourceReferences|
            ==>
            AuthoritySourceReferenceResolvesToAuthorityExec(
                state, account, identities, now,
                sourceReferences[i], sourceAuthorities[i]
            ))
    }


    // ==========================================================
    // EXECUTABLE — FULL PROVENANCE BOUNDARY
    // ==========================================================

    predicate EffectiveAuthorityProvenanceIsValidForAccountAtExec(
        effectiveAuthority: EffectiveAuthority,
        account: Account,
        identities: set<Identity>,
        now: Timestamp,
        sourceReferences: seq<AuthoritySourceReference>,
        sourceAuthorities: seq<set<Capability>>,
        contributions: seq<set<Capability>>
    )
    {
        EffectiveAuthorityHasRecognizedAttributedProvenanceForAccountAtExec(
            effectiveAuthority,
            account,
            identities,
            now,
            sourceReferences,
            sourceAuthorities,
            contributions
        )
    }


    // ==========================================================
    // COMPOSED EXECUTABLE ACCEPTANCE
    // ==========================================================

    predicate AuthorizationCanBeAcceptedWithProvenance(
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
        var state := AccountAuthorizationState(account);

        ValidAccount(account)
        &&
        AuthorizationIdentityContextIsValidExecutable(identities)
        &&
        AuthorizationIsStructurallyValid(authorization)
        &&
        AuthorizationContextMatchesAccount(authorization, account)
        &&
        AuthorizationCredentialIsUsable(authorization, state)
        &&
        AuthorizationIsTemporallyValidAt(authorization, now)
        &&
        AuthorizationReplayIsFresh(authorization, state)
        &&
        EffectiveAuthorityIsValid(effectiveAuthority)
        &&
        EffectiveAuthorityProvenanceIsValidForAccountAtExec(
            effectiveAuthority,
            account,
            identities,
            now,
            sourceReferences,
            sourceAuthorities,
            contributions
        )
        &&
        AuthorizationAuthorityIsEffective(authorization, effectiveAuthority)
        &&
        AuthorizationProofIsVerified(proofVerified)
    }


    lemma AuthorizationCanBeAcceptedWithProvenanceMatchesGhost(
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
        requires ValidAccount(account)
        requires AuthorizationIdentityContextIsValidExecutable(identities)
        ensures
            AuthorizationCanBeAcceptedWithProvenance(
                authorization, account, effectiveAuthority,
                identities, sourceReferences, sourceAuthorities, contributions,
                now, proofVerified
            )
            <==>
            AuthorizationCanBeAccepted(
                authorization, account, effectiveAuthority,
                identities, sourceReferences, sourceAuthorities, contributions,
                now, proofVerified
            )
    {
        ExecutableMatchesGhostForIdentityContext(identities);
        DerivedFromAttributedSourcesExecMatchesGhost(
            effectiveAuthority, sourceReferences, sourceAuthorities, contributions
        );
        SourceReferencesAreCurrentlyUsableExecMatchesGhost(
            AccountAuthorizationState(account), account, identities, now, sourceReferences
        );
    }


    // ==========================================================
    // SINGLE ENTRYPOINT — FULL ACCEPTANCE
    // ==========================================================
    //
    // Stylus-facing entrypoint.
    //
    // The caller provides only:
    //
    //     authorization
    //     account
    //     identities
    //     now
    //     proofVerified
    //
    // The provenance witness is constructed internally by
    // ComputeEffectiveAuthorityWitness (EffectiveAuthorityComposition)
    // and immediately consumed by the executable acceptance above.
    //
    // No provenance parameter crosses the ABI boundary.

    method AuthorizationCanBeAcceptedFull(
        authorization: Authorization,
        account: Account,
        identities: set<Identity>,
        now: Timestamp,
        proofVerified: bool
    ) returns (accepted: bool)
        requires ValidAccount(account)
        requires AuthorizationIdentityContextIsValidExecutable(identities)
    {
        var effectiveAuthority, sourceReferences, sourceAuthorities, contributions :=
            ComputeEffectiveAuthorityWitness(account, identities, now);

        accepted := AuthorizationCanBeAcceptedWithProvenance(
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
    }
}

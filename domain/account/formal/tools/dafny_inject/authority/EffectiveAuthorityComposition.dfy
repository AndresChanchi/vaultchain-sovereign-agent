// ============================================================
// KIPIO ACCOUNT DOMAIN — INJECTED COMPOSITION
// AUTHORITY — EFFECTIVE AUTHORITY COMPOSITION
// ============================================================
//
// Executable counterpart of the ghost provenance construction
// in authorization/AuthorizationValidation.dfy.
//
// AuthorizationCanBeAccepted requires an EffectiveAuthority
// witness (effectiveAuthority + sourceReferences +
// sourceAuthorities + contributions, aligned by index) that
// the ghost function
// CurrentlyUsableAuthoritySourceReferencesForAcceptance
// produces non-executably.
//
// This file provides an executable construction of that
// witness, ready to be translated to Rust by Dafny 4.11.
//
// It does NOT introduce new semantics. It is a computable
// counterpart of the ghost provenance relation already
// verified in Authorization Validation.
//
// ------------------------------------------------------------
// DETERMINISM
//
// Dafny's Rust backend requires --enforce-determinism. That
// option forbids `:|` inside methods when the witness is not
// provably unique, but allows `:|` inside functions when the
// condition uniquely determines the value.
//
// Iteration over AuthorizationState sets is therefore performed
// via the canonical minimum of the remaining set, selected by
// the SelectMinXxx functions below.
//
// The minimum is defined by an explicit lexicographic total
// order on the entity Ids (seq<bv8>). The built-in `<=` on
// seq<T> is NOT lexicographic in Dafny and is NOT total, so
// the order is defined here explicitly.
//
// ============================================================


include "../foundation/DomainPrimitives.dfy"
include "../foundation/Capability.dfy"
include "../foundation/Identity.dfy"

include "Credential.dfy"
include "CredentialAuthority.dfy"
include "Session.dfy"
include "Delegation.dfy"
include "EffectiveAuthority.dfy"
include "AuthorizationState.dfy"

include "../account/Account.dfy"

include "../authorization/Authorization.dfy"
include "../authorization/AuthorizationValidation.dfy"


module KipioAccountEffectiveAuthorityComposition {

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


    // ==========================================================
    // EXECUTABLE — IDENTITY CONTEXT
    // ==========================================================

    predicate AuthorizationIdentityContextIsValidExecutable(
        identities: set<Identity>
    )
    {
        (forall identity ::
            identity in identities ==> ValidIdentity(identity))
        &&
        (forall first, second ::
            first in identities
            && second in identities
            && IdentityId(first) == IdentityId(second)
            ==> first == second)
    }


    lemma ExecutableMatchesGhostForIdentityContext(
        identities: set<Identity>
    )
        ensures
            AuthorizationIdentityContextIsValidExecutable(identities)
            <==>
            AuthorizationIdentityContextIsValid(identities)
    {
    }


    // ==========================================================
    // LEXICOGRAPHIC ORDER ON IDS
    // ==========================================================
    //
    // Id = seq<bv8>. Dafny's built-in `<=` on seq<T> is NOT
    // lexicographic and is NOT total. We define lexicographic
    // order explicitly.

    predicate IdLtLexicographic(left: Id, right: Id)
        decreases |left| + |right|
    {
        if |left| == 0 then
            |right| > 0
        else if |right| == 0 then
            false
        else if left[0] < right[0] then
            true
        else if left[0] == right[0] then
            IdLtLexicographic(left[1..], right[1..])
        else
            false
    }


    predicate IdLessEq(left: Id, right: Id)
    {
        left == right || IdLtLexicographic(left, right)
    }


    lemma IdLessEqIsReflexive(id: Id)
        ensures IdLessEq(id, id)
    {
    }


    lemma IdLtLexicographicIrreflexive(a: Id)
        ensures !IdLtLexicographic(a, a)
        decreases |a|
    {
        if |a| == 0 {
        } else {
            IdLtLexicographicIrreflexive(a[1..]);
        }
    }


    lemma IdLtLexicographicTransitive(a: Id, b: Id, c: Id)
        requires IdLtLexicographic(a, b)
        requires IdLtLexicographic(b, c)
        ensures IdLtLexicographic(a, c)
        decreases |a| + |b| + |c|
    {
        if |a| == 0 {
            // IdLtLexicographic(b, c) requires |c| > 0.
            // IdLtLexicographic(a, c) with |a| == 0 requires |c| > 0. ✓
        } else if |b| == 0 {
            // IdLtLexicographic(a, b) with |b| == 0 is false.
            assert false;
        } else if |c| == 0 {
            // IdLtLexicographic(b, c) with |c| == 0 is false.
            assert false;
        } else if a[0] < b[0] {
            // Need: IdLtLexicographic(a, c).
            // From IdLtLexicographic(b, c) and |b| > 0, |c| > 0:
            // either b[0] < c[0] or b[0] == c[0] with recursion.
            if b[0] < c[0] {
                assert a[0] < c[0];
            } else if b[0] == c[0] {
                assert a[0] < c[0];
            } else {
                assert false;
            }
        } else if a[0] == b[0] {
            // IdLtLexicographic(a, b) with a[0] == b[0] gives
            // IdLtLexicographic(a[1..], b[1..]).
            // Cases on IdLtLexicographic(b, c):
            if b[0] < c[0] {
                assert a[0] < c[0];
            } else if b[0] == c[0] {
                IdLtLexicographicTransitive(a[1..], b[1..], c[1..]);
                assert IdLtLexicographic(a[1..], c[1..]);
            } else {
                assert false;
            }
        } else {
            // a[0] > b[0] contradicts IdLtLexicographic(a, b).
            assert false;
        }
    }


    lemma IdLtLexicographicAsymmetric(a: Id, b: Id)
        requires IdLtLexicographic(a, b)
        ensures !IdLtLexicographic(b, a)
    {
        if IdLtLexicographic(b, a) {
            IdLtLexicographicTransitive(a, b, a);
            IdLtLexicographicIrreflexive(a);
        }
    }


    lemma IdLtLexicographicTrichotomy(a: Id, b: Id)
        ensures IdLtLexicographic(a, b) || a == b || IdLtLexicographic(b, a)
        decreases |a| + |b|
    {
        if |a| == 0 {
            if |b| == 0 {
                assert a == b;
            } else {
                assert IdLtLexicographic(a, b);
            }
        } else if |b| == 0 {
            assert IdLtLexicographic(b, a);
        } else {
            if a[0] < b[0] {
                assert IdLtLexicographic(a, b);
            } else if a[0] == b[0] {
                IdLtLexicographicTrichotomy(a[1..], b[1..]);
                if IdLtLexicographic(a[1..], b[1..]) {
                    assert IdLtLexicographic(a, b);
                } else if a[1..] == b[1..] {
                    assert a == b;
                } else {
                    assert IdLtLexicographic(b[1..], a[1..]);
                    assert IdLtLexicographic(b, a);
                }
            } else {
                assert b[0] < a[0];
                assert IdLtLexicographic(b, a);
            }
        }
    }


    lemma IdLessEqIsTotal(left: Id, right: Id)
        ensures IdLessEq(left, right) || IdLessEq(right, left)
    {
        IdLtLexicographicTrichotomy(left, right);
    }


    lemma IdLessEqIsAntisymmetric(left: Id, right: Id)
        requires IdLessEq(left, right)
        requires IdLessEq(right, left)
        ensures left == right
    {
        if left == right {
        } else {
            assert IdLtLexicographic(left, right);
            if right == left {
                assert false;
            } else {
                assert IdLtLexicographic(right, left);
                IdLtLexicographicAsymmetric(left, right);
                assert false;
            }
        }
    }


    lemma IdLessEqIsTransitive(a: Id, b: Id, c: Id)
        requires IdLessEq(a, b)
        requires IdLessEq(b, c)
        ensures IdLessEq(a, c)
    {
        if a == b {
        } else if b == c {
        } else {
            assert IdLtLexicographic(a, b);
            assert IdLtLexicographic(b, c);
            IdLtLexicographicTransitive(a, b, c);
            assert IdLtLexicographic(a, c);
            assert IdLessEq(a, c);
        }
    }


    // ==========================================================
    // TOTAL ORDER — CREDENTIALS
    // ==========================================================

    predicate CredentialLessEq(left: Credential, right: Credential)
    {
        IdLessEq(CredentialId(left), CredentialId(right))
    }


    lemma CredentialLessEqIsReflexive(c: Credential)
        ensures CredentialLessEq(c, c)
    {
        IdLessEqIsReflexive(CredentialId(c));
    }


    lemma CredentialLessEqIsTotal(left: Credential, right: Credential)
        ensures CredentialLessEq(left, right)
             || CredentialLessEq(right, left)
    {
        IdLessEqIsTotal(CredentialId(left), CredentialId(right));
    }


    lemma CredentialLessEqIsTransitive(a: Credential, b: Credential, c: Credential)
        requires CredentialLessEq(a, b)
        requires CredentialLessEq(b, c)
        ensures CredentialLessEq(a, c)
    {
        IdLessEqIsTransitive(
            CredentialId(a),
            CredentialId(b),
            CredentialId(c)
        );
    }


    lemma CredentialLessEqIsAntisymmetricInState(
        left: Credential,
        right: Credential,
        state: AuthorizationState
    )
        requires ValidAuthorizationState(state)
        requires left in StateCredentials(state)
        requires right in StateCredentials(state)
        requires CredentialLessEq(left, right)
        requires CredentialLessEq(right, left)
        ensures left == right
    {
        IdLessEqIsAntisymmetric(
            CredentialId(left),
            CredentialId(right)
        );
    }


    lemma CredentialAntisymmetryOnSet(
        s: set<Credential>,
        state: AuthorizationState
    )
        requires ValidAuthorizationState(state)
        requires s <= StateCredentials(state)
        ensures forall c1, c2 ::
            c1 in s && c2 in s
            && CredentialLessEq(c1, c2)
            && CredentialLessEq(c2, c1)
            ==> c1 == c2
    {
        forall c1, c2
            | c1 in s && c2 in s
            && CredentialLessEq(c1, c2)
            && CredentialLessEq(c2, c1)
            ensures c1 == c2
        {
            CredentialLessEqIsAntisymmetricInState(c1, c2, state);
        }
    }


    // ==========================================================
    // TOTAL ORDER — SESSIONS
    // ==========================================================

    predicate SessionLessEq(left: Session, right: Session)
    {
        IdLessEq(SessionId(left), SessionId(right))
    }


    lemma SessionLessEqIsReflexive(s: Session)
        ensures SessionLessEq(s, s)
    {
        IdLessEqIsReflexive(SessionId(s));
    }


    lemma SessionLessEqIsTotal(left: Session, right: Session)
        ensures SessionLessEq(left, right)
             || SessionLessEq(right, left)
    {
        IdLessEqIsTotal(SessionId(left), SessionId(right));
    }


    lemma SessionLessEqIsTransitive(a: Session, b: Session, c: Session)
        requires SessionLessEq(a, b)
        requires SessionLessEq(b, c)
        ensures SessionLessEq(a, c)
    {
        IdLessEqIsTransitive(
            SessionId(a),
            SessionId(b),
            SessionId(c)
        );
    }


    lemma SessionLessEqIsAntisymmetricInState(
        left: Session,
        right: Session,
        state: AuthorizationState
    )
        requires ValidAuthorizationState(state)
        requires left in StateSessions(state)
        requires right in StateSessions(state)
        requires SessionLessEq(left, right)
        requires SessionLessEq(right, left)
        ensures left == right
    {
        IdLessEqIsAntisymmetric(
            SessionId(left),
            SessionId(right)
        );
    }


    lemma SessionAntisymmetryOnSet(
        s: set<Session>,
        state: AuthorizationState
    )
        requires ValidAuthorizationState(state)
        requires s <= StateSessions(state)
        ensures forall s1, s2 ::
            s1 in s && s2 in s
            && SessionLessEq(s1, s2)
            && SessionLessEq(s2, s1)
            ==> s1 == s2
    {
        forall s1, s2
            | s1 in s && s2 in s
            && SessionLessEq(s1, s2)
            && SessionLessEq(s2, s1)
            ensures s1 == s2
        {
            SessionLessEqIsAntisymmetricInState(s1, s2, state);
        }
    }


    // ==========================================================
    // TOTAL ORDER — DELEGATIONS
    // ==========================================================

    predicate DelegationLessEq(left: Delegation, right: Delegation)
    {
        IdLessEq(DelegationId(left), DelegationId(right))
    }


    lemma DelegationLessEqIsReflexive(d: Delegation)
        ensures DelegationLessEq(d, d)
    {
        IdLessEqIsReflexive(DelegationId(d));
    }


    lemma DelegationLessEqIsTotal(left: Delegation, right: Delegation)
        ensures DelegationLessEq(left, right)
             || DelegationLessEq(right, left)
    {
        IdLessEqIsTotal(DelegationId(left), DelegationId(right));
    }


    lemma DelegationLessEqIsTransitive(a: Delegation, b: Delegation, c: Delegation)
        requires DelegationLessEq(a, b)
        requires DelegationLessEq(b, c)
        ensures DelegationLessEq(a, c)
    {
        IdLessEqIsTransitive(
            DelegationId(a),
            DelegationId(b),
            DelegationId(c)
        );
    }


    lemma DelegationLessEqIsAntisymmetricInState(
        left: Delegation,
        right: Delegation,
        state: AuthorizationState
    )
        requires ValidAuthorizationState(state)
        requires left in StateDelegations(state)
        requires right in StateDelegations(state)
        requires DelegationLessEq(left, right)
        requires DelegationLessEq(right, left)
        ensures left == right
    {
        IdLessEqIsAntisymmetric(
            DelegationId(left),
            DelegationId(right)
        );
    }


    lemma DelegationAntisymmetryOnSet(
        s: set<Delegation>,
        state: AuthorizationState
    )
        requires ValidAuthorizationState(state)
        requires s <= StateDelegations(state)
        ensures forall d1, d2 ::
            d1 in s && d2 in s
            && DelegationLessEq(d1, d2)
            && DelegationLessEq(d2, d1)
            ==> d1 == d2
    {
        forall d1, d2
            | d1 in s && d2 in s
            && DelegationLessEq(d1, d2)
            && DelegationLessEq(d2, d1)
            ensures d1 == d2
        {
            DelegationLessEqIsAntisymmetricInState(d1, d2, state);
        }
    }


    // ==========================================================
    // MINIMUM — DEFINITIONS
    // ==========================================================

    predicate IsMinCredential(c: Credential, s: set<Credential>)
    {
        c in s
        &&
        (forall other ::
            other in s ==> CredentialLessEq(c, other))
    }


    predicate IsMinSession(sess: Session, s: set<Session>)
    {
        sess in s
        &&
        (forall other ::
            other in s ==> SessionLessEq(sess, other))
    }


    predicate IsMinDelegation(d: Delegation, s: set<Delegation>)
    {
        d in s
        &&
        (forall other ::
            other in s ==> DelegationLessEq(d, other))
    }


    // ==========================================================
    // EXISTENCE OF MINIMUM
    // ==========================================================

    lemma EveryNonEmptyCredentialSetHasMinimum(s: set<Credential>)
        requires s != {}
        ensures exists c :: IsMinCredential(c, s)
        decreases |s|
    {
        var candidate :| candidate in s;
        var rest := s - { candidate };
        assert s == rest + { candidate };

        if rest == {} {
            assert s == { candidate };
            forall other | other in s
                ensures CredentialLessEq(candidate, other)
            {
                assert other == candidate;
                CredentialLessEqIsReflexive(candidate);
            }
            assert IsMinCredential(candidate, s);
        } else {
            EveryNonEmptyCredentialSetHasMinimum(rest);

            var restMin :| IsMinCredential(restMin, rest);
            assert IsMinCredential(restMin, rest);
            assert restMin in rest;
            assert restMin in s;

            if CredentialLessEq(candidate, restMin) {
                forall other | other in s
                    ensures CredentialLessEq(candidate, other)
                {
                    if other == candidate {
                        CredentialLessEqIsReflexive(candidate);
                    } else {
                        assert other in rest;
                        assert CredentialLessEq(restMin, other);
                        CredentialLessEqIsTransitive(candidate, restMin, other);
                    }
                }
                assert IsMinCredential(candidate, s);
            } else {
                CredentialLessEqIsTotal(candidate, restMin);
                assert CredentialLessEq(restMin, candidate);

                forall other | other in s
                    ensures CredentialLessEq(restMin, other)
                {
                    if other == candidate {
                        // CredentialLessEq(restMin, candidate) already known
                    } else {
                        assert other in rest;
                    }
                }
                assert IsMinCredential(restMin, s);
            }
        }
    }


    lemma EveryNonEmptySessionSetHasMinimum(s: set<Session>)
        requires s != {}
        ensures exists sess :: IsMinSession(sess, s)
        decreases |s|
    {
        var candidate :| candidate in s;
        var rest := s - { candidate };
        assert s == rest + { candidate };

        if rest == {} {
            assert s == { candidate };
            forall other | other in s
                ensures SessionLessEq(candidate, other)
            {
                assert other == candidate;
                SessionLessEqIsReflexive(candidate);
            }
            assert IsMinSession(candidate, s);
        } else {
            EveryNonEmptySessionSetHasMinimum(rest);

            var restMin :| IsMinSession(restMin, rest);
            assert IsMinSession(restMin, rest);
            assert restMin in rest;
            assert restMin in s;

            if SessionLessEq(candidate, restMin) {
                forall other | other in s
                    ensures SessionLessEq(candidate, other)
                {
                    if other == candidate {
                        SessionLessEqIsReflexive(candidate);
                    } else {
                        assert other in rest;
                        assert SessionLessEq(restMin, other);
                        SessionLessEqIsTransitive(candidate, restMin, other);
                    }
                }
                assert IsMinSession(candidate, s);
            } else {
                SessionLessEqIsTotal(candidate, restMin);
                assert SessionLessEq(restMin, candidate);

                forall other | other in s
                    ensures SessionLessEq(restMin, other)
                {
                    if other == candidate {
                    } else {
                        assert other in rest;
                    }
                }
                assert IsMinSession(restMin, s);
            }
        }
    }


    lemma EveryNonEmptyDelegationSetHasMinimum(s: set<Delegation>)
        requires s != {}
        ensures exists d :: IsMinDelegation(d, s)
        decreases |s|
    {
        var candidate :| candidate in s;
        var rest := s - { candidate };
        assert s == rest + { candidate };

        if rest == {} {
            assert s == { candidate };
            forall other | other in s
                ensures DelegationLessEq(candidate, other)
            {
                assert other == candidate;
                DelegationLessEqIsReflexive(candidate);
            }
            assert IsMinDelegation(candidate, s);
        } else {
            EveryNonEmptyDelegationSetHasMinimum(rest);

            var restMin :| IsMinDelegation(restMin, rest);
            assert IsMinDelegation(restMin, rest);
            assert restMin in rest;
            assert restMin in s;

            if DelegationLessEq(candidate, restMin) {
                forall other | other in s
                    ensures DelegationLessEq(candidate, other)
                {
                    if other == candidate {
                        DelegationLessEqIsReflexive(candidate);
                    } else {
                        assert other in rest;
                        assert DelegationLessEq(restMin, other);
                        DelegationLessEqIsTransitive(candidate, restMin, other);
                    }
                }
                assert IsMinDelegation(candidate, s);
            } else {
                DelegationLessEqIsTotal(candidate, restMin);
                assert DelegationLessEq(restMin, candidate);

                forall other | other in s
                    ensures DelegationLessEq(restMin, other)
                {
                    if other == candidate {
                    } else {
                        assert other in rest;
                    }
                }
                assert IsMinDelegation(restMin, s);
            }
        }
    }


    // ==========================================================
    // SELECT-MINIMUM FUNCTIONS
    // ==========================================================

    function SelectMinCredential(
        s: set<Credential>,
        state: AuthorizationState
    ): Credential
        requires s != {}
        requires ValidAuthorizationState(state)
        requires s <= StateCredentials(state)
    {
        EveryNonEmptyCredentialSetHasMinimum(s);
        CredentialAntisymmetryOnSet(s, state);

        var c :| c in s
             && forall other :: other in s ==> CredentialLessEq(c, other);

        c
    }


    function SelectMinSession(
        s: set<Session>,
        state: AuthorizationState
    ): Session
        requires s != {}
        requires ValidAuthorizationState(state)
        requires s <= StateSessions(state)
    {
        EveryNonEmptySessionSetHasMinimum(s);
        SessionAntisymmetryOnSet(s, state);

        var sess :| sess in s
             && forall other :: other in s ==> SessionLessEq(sess, other);

        sess
    }


    function SelectMinDelegation(
        s: set<Delegation>,
        state: AuthorizationState
    ): Delegation
        requires s != {}
        requires ValidAuthorizationState(state)
        requires s <= StateDelegations(state)
    {
        EveryNonEmptyDelegationSetHasMinimum(s);
        DelegationAntisymmetryOnSet(s, state);

        var d :| d in s
             && forall other :: other in s ==> DelegationLessEq(d, other);

        d
    }


    // ==========================================================
    // EXECUTABLE — DELEGATION PROVENANCE
    // ==========================================================

    predicate DelegationProvenanceIsLegitimateForAccountExecutable(
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
        AuthorizationIdentityContextIsValidExecutable(identities)
        &&
        DelegationId(delegation) !in visited
        &&
        DelegationId(delegation) in StateDelegationProvenance(state).Keys
        &&
        (
            (
                StateDelegationProvenance(state)[DelegationId(delegation)] == {}
                &&
                DelegationSourceIdentityId(delegation)
                    == IdentityId(AccountSovereignIdentity(account))
            )
            ||
            (
                StateDelegationProvenance(state)[DelegationId(delegation)] != {}
                &&
                forall parentId ::
                    parentId in StateDelegationProvenance(state)[DelegationId(delegation)]
                    ==>
                        exists parent : Delegation ::
                            parent in StateDelegations(state)
                            && DelegationId(parent) == parentId
                            && ParentDelegationSupportsChildSource(identities, parent, delegation)
                            && DelegationProvenanceIsLegitimateForAccountExecutable(
                                account, state, identities, parent,
                                visited + { DelegationId(delegation) }
                            )
            )
        )
    }


    predicate DelegationHasLegitimateSourceProvenanceForAccountExecutable(
        account: Account,
        state: AuthorizationState,
        identities: set<Identity>,
        delegation: Delegation
    )
    {
        DelegationProvenanceIsLegitimateForAccountExecutable(
            account, state, identities, delegation, {}
        )
    }


    lemma ExecutableMatchesGhostForDelegationProvenance(
        account: Account,
        state: AuthorizationState,
        identities: set<Identity>,
        delegation: Delegation,
        visited: set<Id>
    )
        requires AuthorizationIdentityContextIsValidExecutable(identities)
        ensures
            DelegationProvenanceIsLegitimateForAccountExecutable(
                account, state, identities, delegation, visited
            )
            <==>
            DelegationProvenanceIsLegitimateForAccount(
                account, state, identities, delegation, visited
            )
        decreases StateDelegationIds(state) - visited
    {
        ExecutableMatchesGhostForIdentityContext(identities);

        if DelegationProvenanceIsLegitimateForAccountExecutable(
             account, state, identities, delegation, visited
           )
        {
            if DelegationId(delegation) in StateDelegationProvenance(state).Keys
                && StateDelegationProvenance(state)[DelegationId(delegation)] != {}
            {
                forall parentId
                    | parentId in StateDelegationProvenance(state)[DelegationId(delegation)]
                    ensures true
                {
                    var parent :| parent in StateDelegations(state)
                        && DelegationId(parent) == parentId
                        && ParentDelegationSupportsChildSource(identities, parent, delegation)
                        && DelegationProvenanceIsLegitimateForAccountExecutable(
                            account, state, identities, parent,
                            visited + { DelegationId(delegation) }
                        );
                    ExecutableMatchesGhostForDelegationProvenance(
                        account, state, identities, parent,
                        visited + { DelegationId(delegation) }
                    );
                }
            }
        }
    }


    // ==========================================================
    // UNION OF CONTRIBUTIONS
    // ==========================================================

    function UnionOfContributions(
        contributions: seq<set<Capability>>
    ): set<Capability>
    {
        if |contributions| == 0 then
            {}
        else
            UnionOfContributions(contributions[..|contributions|-1])
                + contributions[|contributions|-1]
    }


    lemma UnionOfContributionsIsExact(
        contributions: seq<set<Capability>>,
        capability: Capability
    )
        ensures
            capability in UnionOfContributions(contributions)
            <==>
            (exists i :: 0 <= i < |contributions|
                && capability in contributions[i])
    {
        if |contributions| == 0 {
        } else {
            UnionOfContributionsIsExact(
                contributions[..|contributions|-1],
                capability
            );
        }
    }


    // ==========================================================
    // WITNESS CONSTRUCTION
    // ==========================================================

    method ComputeEffectiveAuthorityWitness(
        account: Account,
        identities: set<Identity>,
        now: Timestamp
    ) returns (
        effectiveAuthority: EffectiveAuthority,
        sourceReferences: seq<AuthoritySourceReference>,
        sourceAuthorities: seq<set<Capability>>,
        contributions: seq<set<Capability>>
    )
        requires ValidAccount(account)
        requires AuthorizationIdentityContextIsValidExecutable(identities)
        ensures
            |sourceReferences| == |sourceAuthorities|
        ensures
            |sourceAuthorities| == |contributions|
        ensures
            forall i :: 0 <= i < |sourceReferences| ==>
                ValidAuthoritySourceReference(sourceReferences[i])
        ensures
            forall i :: 0 <= i < |contributions| ==>
                contributions[i] <= sourceAuthorities[i]
        ensures
            forall capability ::
                capability in effectiveAuthority
                <==>
                exists i :: 0 <= i < |contributions|
                    && capability in contributions[i]
    {
        var state := AccountAuthorizationState(account);

        sourceReferences := [];
        sourceAuthorities := [];
        contributions := [];

        // ---------------------------------------------
        // Account source
        // ---------------------------------------------

        var accountRef := AuthoritySourceReference(
            AccountAuthoritySource,
            AccountIdOf(account)
        );
        var accountAuth := StateCapabilities(state);

        assert ValidId(AccountIdOf(account));

        sourceReferences := sourceReferences + [accountRef];
        sourceAuthorities := sourceAuthorities + [accountAuth];
        contributions := contributions + [accountAuth];

        // ---------------------------------------------
        // Credential sources
        // ---------------------------------------------

        var remainingCredentials := StateCredentials(state);

        while remainingCredentials != {}
            decreases remainingCredentials
            invariant remainingCredentials <= StateCredentials(state)
            invariant |sourceReferences| == |sourceAuthorities|
            invariant |sourceAuthorities| == |contributions|
            invariant forall i :: 0 <= i < |sourceReferences| ==>
                ValidAuthoritySourceReference(sourceReferences[i])
            invariant forall i :: 0 <= i < |contributions| ==>
                contributions[i] == sourceAuthorities[i]
        {
            var credential := SelectMinCredential(remainingCredentials, state);

            remainingCredentials := remainingCredentials - { credential };

            if ActiveCredentialRecognizedInState(state, CredentialId(credential)) {
                assert credential in StateCredentials(state);
                assert ValidCredential(credential);
                assert ValidId(CredentialId(credential));
                assert CredentialId(credential) in StateCredentialAuthorities(state).Keys;
                assert CredentialRecognizedInState(state, credential);
                assert CredentialAuthorityDefinedInState(state, credential);

                var credRef := AuthoritySourceReference(
                    CredentialAuthoritySource,
                    CredentialId(credential)
                );
                var credAuth := StateCredentialAuthority(state, credential);

                sourceReferences := sourceReferences + [credRef];
                sourceAuthorities := sourceAuthorities + [credAuth];
                contributions := contributions + [credAuth];
            }
        }

        // ---------------------------------------------
        // Session sources
        // ---------------------------------------------

        var remainingSessions := StateSessions(state);

        while remainingSessions != {}
            decreases remainingSessions
            invariant remainingSessions <= StateSessions(state)
            invariant |sourceReferences| == |sourceAuthorities|
            invariant |sourceAuthorities| == |contributions|
            invariant forall i :: 0 <= i < |sourceReferences| ==>
                ValidAuthoritySourceReference(sourceReferences[i])
            invariant forall i :: 0 <= i < |contributions| ==>
                contributions[i] == sourceAuthorities[i]
        {
            var session := SelectMinSession(remainingSessions, state);

            remainingSessions := remainingSessions - { session };

            if SessionCanContributeAuthorityAt(state, session, now) {
                assert session in StateSessions(state);
                assert ValidSession(session);
                assert ValidId(SessionId(session));

                var sessionRef := AuthoritySourceReference(
                    SessionAuthoritySource,
                    SessionId(session)
                );
                var sessionAuth := SessionCapabilities(session);

                sourceReferences := sourceReferences + [sessionRef];
                sourceAuthorities := sourceAuthorities + [sessionAuth];
                contributions := contributions + [sessionAuth];
            }
        }

        // ---------------------------------------------
        // Delegation sources
        // ---------------------------------------------

        var remainingDelegations := StateDelegations(state);

        while remainingDelegations != {}
            decreases remainingDelegations
            invariant remainingDelegations <= StateDelegations(state)
            invariant |sourceReferences| == |sourceAuthorities|
            invariant |sourceAuthorities| == |contributions|
            invariant forall i :: 0 <= i < |sourceReferences| ==>
                ValidAuthoritySourceReference(sourceReferences[i])
            invariant forall i :: 0 <= i < |contributions| ==>
                contributions[i] == sourceAuthorities[i]
        {
            var delegation := SelectMinDelegation(remainingDelegations, state);

            remainingDelegations := remainingDelegations - { delegation };

            if DelegationCanContributeAuthorityAt(state, delegation, now)
                && DelegationHasLegitimateSourceProvenanceForAccountExecutable(
                     account, state, identities, delegation
                   )
            {
                assert delegation in StateDelegations(state);
                assert ValidDelegation(delegation);
                assert ValidId(DelegationId(delegation));

                var delegRef := AuthoritySourceReference(
                    DelegationAuthoritySource,
                    DelegationId(delegation)
                );
                var delegAuth := DelegationCapabilities(delegation);

                sourceReferences := sourceReferences + [delegRef];
                sourceAuthorities := sourceAuthorities + [delegAuth];
                contributions := contributions + [delegAuth];
            }
        }

        // ---------------------------------------------
        // Effective Authority as union of contributions
        // ---------------------------------------------

        effectiveAuthority := UnionOfContributions(contributions);

        forall capability: Capability
            ensures
                capability in effectiveAuthority
                <==>
                exists i :: 0 <= i < |contributions|
                    && capability in contributions[i]
        {
            UnionOfContributionsIsExact(contributions, capability);
        }
    }
}

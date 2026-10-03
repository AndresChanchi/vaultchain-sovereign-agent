// ============================================================
// KIPIO ACCOUNT DOMAIN
// PROOFS — SCENARIO: INVALID ACCOUNT ACCEPTANCE
// ============================================================
//
// Adversarial scenario:
//
//     Construct an Account that is invalid solely because its
//     sovereign Identity is invalid, while preserving:
//
//       - a valid AccountId;
//       - a valid AuthorizationState;
//       - a recognized and Active Credential;
//       - a structurally valid Authorization;
//       - matching Account context;
//       - temporal validity;
//       - Replay freshness;
//       - valid EffectiveAuthority;
//       - requested-authority containment;
//       - valid identity/provenance witness context;
//       - verified Proof.
//
//     Then establish whether AuthorizationCanBeAccepted can still
//     accept the Authorization.
//
// ------------------------------------------------------------
//
// IMPORTANT CURRENT SEMANTICS
//
// AuthorizationCanBeAccepted currently requires:
//
//     ValidAccount(account)
//
// explicitly.
//
// Therefore the old positive attack:
//
//     !ValidAccount(account)
//         +
//     all other acceptance conditions
//         =>
//     AuthorizationCanBeAccepted(...)
//
// is no longer compatible with the authoritative acceptance
// contract.
//
// The scenario is therefore intentionally converted into a
// negative-boundary proof:
//
//     !ValidAccount(account)
//         =>
//     !AuthorizationCanBeAccepted(...)
//
// while independently preserving all other acceptance conditions.
//
// ------------------------------------------------------------
//
// SECURITY QUESTION
//
// Does the current Authorization acceptance boundary reject an
// Account that is structurally invalid because its sovereign
// Identity is invalid, even when every other acceptance condition
// remains satisfiable?
//
// Expected result:
//
//     YES.
//
// The reason must be:
//
//     ValidAccount(account)
//         is an explicit acceptance prerequisite.
//
// ------------------------------------------------------------
//
// ATTACK ISOLATION
//
// Do NOT break AccountId.
//
// `AuthorizationIsStructurallyValid` requires a valid AccountId and
// `AuthorizationContextMatchesAccount` requires:
//
//     AuthorizationAccountId == AccountIdOf(account)
//
// Therefore an invalid AccountId would introduce a second failure.
//
// Instead:
//
//     AccountId            = valid
//     AuthorizationState   = valid
//     Sovereign Identity   = invalid
//
// This isolates Account invalidity to the sovereign Identity.
//
// ------------------------------------------------------------
//
// CURRENT ACCEPTANCE CONTRACT
//
// AuthorizationCanBeAccepted currently requires:
//
//   1. ValidAccount
//   2. valid Identity context
//   3. structurally valid Authorization
//   4. matching Account context
//   5. usable Credential
//   6. temporal validity
//   7. fresh Replay Protection
//   8. valid EffectiveAuthority
//   9. provenance-backed EffectiveAuthority
//  10. requested authority containment
//  11. verified Proof
//
// Therefore the old "missing ValidAccount prerequisite" finding is
// CLOSED by the current authoritative contract.
//
// This scenario now verifies that closure from the adversarial side.
//
// ============================================================



// ============================================================
// IMPORTS
// ============================================================

include "../../foundation/DomainPrimitives.dfy"
include "../../foundation/Subject.dfy"
include "../../foundation/Identity.dfy"
include "../../foundation/Capability.dfy"
include "../../foundation/Scope.dfy"
include "../../foundation/DomainAction.dfy"
include "../../foundation/ExecutionTarget.dfy"
include "../../foundation/Chain.dfy"

include "../../authority/AuthorizationState.dfy"
include "../../authority/EffectiveAuthority.dfy"

include "../../account/Account.dfy"

include "../../authorization/Authorization.dfy"
include "../../authorization/AuthorizationValidation.dfy"

include "../isolated/AccountProofs.dfy"
include "../isolated/AuthorizationProofs.dfy"



module KipioAccountInvalidAccountAcceptanceProof
{
  import opened KipioAccountDomainPrimitives
  import opened KipioAccountSubject
  import opened KipioAccountIdentity
  import opened KipioAccountCapability
  import opened KipioAccountScope
  import opened KipioAccountDomainAction
  import opened KipioAccountExecutionTarget
  import opened KipioAccountChain

  import opened KipioAccountAuthorizationState
  import opened KipioAccountEffectiveAuthority

  import opened KipioAccountAccount

  import opened KipioAccountAuthorization
  import opened KipioAccountAuthorizationValidation

  import opened KipioAccountProofs
  import opened KipioAccountAuthorizationProofs



  // ==========================================================
  // INVALID SOVEREIGN IDENTITY CONSTRUCTION
  // ==========================================================

  // Construct an Identity whose Identifier is structurally invalid.
  //
  // Id validity is:
  //
  //     |id| > 0
  //
  // Therefore the empty sequence is invalid.
  //
  // The Subject is intentionally kept valid so that the only
  // violated Identity invariant is the IdentityId itself.

  function InvalidSovereignIdentity(
    subject: Subject
  ): Identity
    requires ValidSubject(subject)
  {
    Identity([], subject)
  }


  lemma InvalidSovereignIdentityIsInvalid(
    subject: Subject
  )
    requires ValidSubject(subject)
    ensures !
            ValidIdentity(
              InvalidSovereignIdentity(subject)
            )
  {
    assert IdentityId(
        InvalidSovereignIdentity(subject)
      )
        == [];

    assert !ValidId(
        IdentityId(
          InvalidSovereignIdentity(subject)
        )
      );

    assert !ValidIdentity(
        InvalidSovereignIdentity(subject)
      );
  }



  // ==========================================================
  // INVALID ACCOUNT CONSTRUCTION
  // ==========================================================

  // Construct an Account whose:
  //
  //   - AccountId is valid;
  //   - AuthorizationState is valid;
  //   - sovereign Identity is invalid.
  //
  // This isolates Account invalidity to the sovereign Identity.

  function InvalidAccountBySovereignIdentity(
    accountId: AccountId,
    subject: Subject,
    state: AuthorizationState
  ): Account
    requires ValidId(accountId)
    requires ValidSubject(subject)
    requires ValidAuthorizationState(state)
  {
    Account(
      accountId,
      InvalidSovereignIdentity(subject),
      state
    )
  }


  lemma InvalidAccountBySovereignIdentityIsInvalid(
    accountId: AccountId,
    subject: Subject,
    state: AuthorizationState
  )
    requires ValidId(accountId)
    requires ValidSubject(subject)
    requires ValidAuthorizationState(state)
    ensures !
            ValidAccount(
              InvalidAccountBySovereignIdentity(
                accountId,
                subject,
                state
              )
            )
  {
    InvalidSovereignIdentityIsInvalid(subject);

    assert ValidId(
        AccountIdOf(
          InvalidAccountBySovereignIdentity(
            accountId,
            subject,
            state
          )
        )
      );

    assert ValidAuthorizationState(
        AccountAuthorizationState(
          InvalidAccountBySovereignIdentity(
            accountId,
            subject,
            state
          )
        )
      );

    assert !ValidIdentity(
        AccountSovereignIdentity(
          InvalidAccountBySovereignIdentity(
            accountId,
            subject,
            state
          )
        )
      );

    assert !ValidAccount(
        InvalidAccountBySovereignIdentity(
          accountId,
          subject,
          state
        )
      );
  }



  // ==========================================================
  // ACCOUNT COMPONENTS REMAIN INDEPENDENTLY VALID
  // ==========================================================

  // The invalid Account still exposes a valid AccountId.

  lemma InvalidAccountStillHasValidAccountId(
    accountId: AccountId,
    subject: Subject,
    state: AuthorizationState
  )
    requires ValidId(accountId)
    requires ValidSubject(subject)
    requires ValidAuthorizationState(state)
    ensures ValidId(
              AccountIdOf(
                InvalidAccountBySovereignIdentity(
                  accountId,
                  subject,
                  state
                )
              )
            )
  {
  }


  // The invalid Account still contains a valid AuthorizationState.

  lemma InvalidAccountStillHasValidAuthorizationState(
    accountId: AccountId,
    subject: Subject,
    state: AuthorizationState
  )
    requires ValidId(accountId)
    requires ValidSubject(subject)
    requires ValidAuthorizationState(state)
    ensures ValidAuthorizationState(
              AccountAuthorizationState(
                InvalidAccountBySovereignIdentity(
                  accountId,
                  subject,
                  state
                )
              )
            )
  {
  }



  // ==========================================================
  // AUTHORIZATION ACCOUNT CONTEXT
  // ==========================================================

  // Build the minimal semantic Authorization needed for the
  // scenario.
  //
  // RequestedAuthority is intentionally empty.
  //
  // Therefore authority containment is structurally trivial:
  //
  //     {} ⊆ EffectiveAuthority
  //
  // This prevents authority magnitude from becoming a separate
  // attack dimension.

  function MinimalAuthorizationForInvalidAccount(
    accountId: AccountId,
    credentialId: Id,
    replayKey: Id,
    target: ExecutionTarget,
    action: DomainAction,
    scope: Scope,
    chain: Chain
  ): Authorization
    requires ValidId(accountId)
    requires ValidId(credentialId)
    requires ValidId(replayKey)
    requires ValidScope(scope)
  {
    Authorization(
      credentialId,
      {},
      {},
      0,
      0,
      replayKey,
      accountId,
      target,
      action,
      scope,
      chain
    )
  }


  lemma InvalidAccountAuthorizationContextMatches(
    accountId: AccountId,
    subject: Subject,
    state: AuthorizationState,
    credentialId: Id,
    replayKey: Id,
    target: ExecutionTarget,
    action: DomainAction,
    scope: Scope,
    chain: Chain
  )
    requires ValidId(accountId)
    requires ValidSubject(subject)
    requires ValidAuthorizationState(state)
    requires ValidId(credentialId)
    requires ValidId(replayKey)
    requires ValidScope(scope)
    ensures AuthorizationContextMatchesAccount(
              MinimalAuthorizationForInvalidAccount(
                accountId,
                credentialId,
                replayKey,
                target,
                action,
                scope,
                chain
              ),
              InvalidAccountBySovereignIdentity(
                accountId,
                subject,
                state
              )
            )
  {
  }



  // ==========================================================
  // AUTHORIZATION STRUCTURAL VALIDITY
  // ==========================================================

  lemma MinimalAuthorizationIsStructurallyValid(
    accountId: AccountId,
    credentialId: Id,
    replayKey: Id,
    target: ExecutionTarget,
    action: DomainAction,
    scope: Scope,
    chain: Chain
  )
    requires ValidId(accountId)
    requires ValidId(credentialId)
    requires ValidId(replayKey)
    requires ValidScope(scope)
    ensures AuthorizationIsStructurallyValid(
              MinimalAuthorizationForInvalidAccount(
                accountId,
                credentialId,
                replayKey,
                target,
                action,
                scope,
                chain
              )
            )
  {
  }



  // ==========================================================
  // CREDENTIAL USABILITY
  // ==========================================================

  // The Account state is valid and contains a Credential that is
  // recognized and Active.
  //
  // This demonstrates that Credential lifecycle is not what makes
  // the Account invalid.

  lemma InvalidAccountCanStillExposeUsableCredential(
    accountId: AccountId,
    subject: Subject,
    state: AuthorizationState,
    credentialId: Id,
    replayKey: Id,
    target: ExecutionTarget,
    action: DomainAction,
    scope: Scope,
    chain: Chain
  )
    requires ValidId(accountId)
    requires ValidSubject(subject)
    requires ValidAuthorizationState(state)
    requires ValidId(credentialId)
    requires ValidId(replayKey)
    requires ValidScope(scope)

    requires CredentialIdRecognizedInState(
               state,
               credentialId
             )

    requires ActiveCredentialRecognizedInState(
               state,
               credentialId
             )

    ensures AuthorizationCredentialIsUsable(
              MinimalAuthorizationForInvalidAccount(
                accountId,
                credentialId,
                replayKey,
                target,
                action,
                scope,
                chain
              ),
              AccountAuthorizationState(
                InvalidAccountBySovereignIdentity(
                  accountId,
                  subject,
                  state
                )
              )
            )
  {
  }



  // ==========================================================
  // TEMPORAL VALIDITY
  // ==========================================================

  // The Authorization is valid at time zero.
  //
  // Since the interval is [0,0], time 0 satisfies the inclusive
  // temporal boundaries.

  lemma MinimalAuthorizationIsTemporallyValidAtZero(
    accountId: AccountId,
    credentialId: Id,
    replayKey: Id,
    target: ExecutionTarget,
    action: DomainAction,
    scope: Scope,
    chain: Chain
  )
    requires ValidId(accountId)
    requires ValidId(credentialId)
    requires ValidId(replayKey)
    requires ValidScope(scope)
    ensures AuthorizationIsTemporallyValidAt(
              MinimalAuthorizationForInvalidAccount(
                accountId,
                credentialId,
                replayKey,
                target,
                action,
                scope,
                chain
              ),
              0
            )
  {
  }



  // ==========================================================
  // REPLAY FRESHNESS
  // ==========================================================

  // Replay freshness is independently supplied by requiring that
  // the Authorization's replay key is not already consumed.

  lemma MinimalAuthorizationCanRemainReplayFresh(
    accountId: AccountId,
    subject: Subject,
    state: AuthorizationState,
    credentialId: Id,
    replayKey: Id,
    target: ExecutionTarget,
    action: DomainAction,
    scope: Scope,
    chain: Chain
  )
    requires ValidId(accountId)
    requires ValidSubject(subject)
    requires ValidAuthorizationState(state)
    requires ValidId(credentialId)
    requires ValidId(replayKey)
    requires ValidScope(scope)

    requires replayKey
             !in
             StateConsumedReplayKeys(state)

    ensures AuthorizationReplayIsFresh(
              MinimalAuthorizationForInvalidAccount(
                accountId,
                credentialId,
                replayKey,
                target,
                action,
                scope,
                chain
              ),
              AccountAuthorizationState(
                InvalidAccountBySovereignIdentity(
                  accountId,
                  subject,
                  state
                )
              )
            )
  {
  }



  // ==========================================================
  // EFFECTIVE AUTHORITY
  // ==========================================================

  // Empty RequestedAuthority is contained in empty EffectiveAuthority.

  lemma MinimalAuthorizationFitsEmptyEffectiveAuthority(
    accountId: AccountId,
    credentialId: Id,
    replayKey: Id,
    target: ExecutionTarget,
    action: DomainAction,
    scope: Scope,
    chain: Chain
  )
    requires ValidId(accountId)
    requires ValidId(credentialId)
    requires ValidId(replayKey)
    requires ValidScope(scope)
    ensures RequestedAuthorityWithinEffectiveAuthority(
              MinimalAuthorizationForInvalidAccount(
                accountId,
                credentialId,
                replayKey,
                target,
                action,
                scope,
                chain
              ),
              {}
            )
  {
  }


  lemma EmptyEffectiveAuthorityIsValid(
    context: EffectiveAuthority
  )
    requires context == {}
    ensures ValidEffectiveAuthority(context)
  {
  }



  // ==========================================================
  // IDENTITY CONTEXT
  // ==========================================================

  // Empty Identity context is structurally valid.
  //
  // The scenario intentionally supplies no Delegation provenance
  // witnesses because the EffectiveAuthority is empty and therefore
  // no source contribution needs to be established.

  lemma EmptyIdentityContextIsValid()
    ensures AuthorizationIdentityContextIsValid({})
  {
  }



  // Empty source/contribution sequences satisfy the provenance
  // relation for an empty EffectiveAuthority.

  lemma EmptyEffectiveAuthorityHasEmptyProvenance()
    ensures
      EffectiveAuthorityHasRecognizedSourceProvenance(
        {},
        {},
        [],
        []
      )
  {
  }



  // ==========================================================
  // NON-ACCOUNT ACCEPTANCE CONDITIONS REMAIN SATISFIABLE
  // ==========================================================

  // The adversarial scenario preserves all currently formalized
  // acceptance conditions EXCEPT the Account validity condition.
  //
  // This is the key isolation theorem.
  //
  // The Account is invalid because its sovereign Identity is
  // invalid, but the Authorization itself remains:
  //
  //   - structurally valid;
  //   - Account-context compatible;
  //   - Credential-usable;
  //   - temporally valid;
  //   - Replay-fresh;
  //   - EffectiveAuthority-valid;
  //   - provenance-valid for the empty authority;
  //   - authority-contained;
  //   - proof-verified.

  lemma InvalidAccountAcceptanceAttackPreservesNonAccountConditions(
    accountId: AccountId,
    subject: Subject,
    state: AuthorizationState,
    credentialId: Id,
    replayKey: Id,
    target: ExecutionTarget,
    action: DomainAction,
    scope: Scope,
    chain: Chain
  )
    requires ValidId(accountId)
    requires ValidSubject(subject)
    requires ValidAuthorizationState(state)

    requires ValidId(credentialId)
    requires ValidId(replayKey)
    requires ValidScope(scope)

    requires CredentialIdRecognizedInState(
               state,
               credentialId
             )

    requires ActiveCredentialRecognizedInState(
               state,
               credentialId
             )

    requires replayKey
             !in
             StateConsumedReplayKeys(state)

    ensures !ValidAccount(
              InvalidAccountBySovereignIdentity(
                accountId,
                subject,
                state
              )
            )

    ensures AuthorizationIdentityContextIsValid({})

    ensures AuthorizationIsStructurallyValid(
              MinimalAuthorizationForInvalidAccount(
                accountId,
                credentialId,
                replayKey,
                target,
                action,
                scope,
                chain
              )
            )

    ensures AuthorizationContextMatchesAccount(
              MinimalAuthorizationForInvalidAccount(
                accountId,
                credentialId,
                replayKey,
                target,
                action,
                scope,
                chain
              ),
              InvalidAccountBySovereignIdentity(
                accountId,
                subject,
                state
              )
            )

    ensures AuthorizationCredentialIsUsable(
              MinimalAuthorizationForInvalidAccount(
                accountId,
                credentialId,
                replayKey,
                target,
                action,
                scope,
                chain
              ),
              AccountAuthorizationState(
                InvalidAccountBySovereignIdentity(
                  accountId,
                  subject,
                  state
                )
              )
            )

    ensures AuthorizationIsTemporallyValidAt(
              MinimalAuthorizationForInvalidAccount(
                accountId,
                credentialId,
                replayKey,
                target,
                action,
                scope,
                chain
              ),
              0
            )

    ensures AuthorizationReplayIsFresh(
              MinimalAuthorizationForInvalidAccount(
                accountId,
                credentialId,
                replayKey,
                target,
                action,
                scope,
                chain
              ),
              AccountAuthorizationState(
                InvalidAccountBySovereignIdentity(
                  accountId,
                  subject,
                  state
                )
              )
            )

    ensures ValidEffectiveAuthority({})

    ensures
      EffectiveAuthorityHasRecognizedSourceProvenance(
        {},
        {},
        [],
        []
      )

    ensures RequestedAuthorityWithinEffectiveAuthority(
              MinimalAuthorizationForInvalidAccount(
                accountId,
                credentialId,
                replayKey,
                target,
                action,
                scope,
                chain
              ),
              {}
            )

    ensures AuthorizationProofIsVerified(true)
  {
    InvalidAccountBySovereignIdentityIsInvalid(
      accountId,
      subject,
      state
    );

    EmptyIdentityContextIsValid();
    EmptyEffectiveAuthorityHasEmptyProvenance();

    MinimalAuthorizationIsStructurallyValid(
      accountId,
      credentialId,
      replayKey,
      target,
      action,
      scope,
      chain
    );

    InvalidAccountAuthorizationContextMatches(
      accountId,
      subject,
      state,
      credentialId,
      replayKey,
      target,
      action,
      scope,
      chain
    );

    InvalidAccountCanStillExposeUsableCredential(
      accountId,
      subject,
      state,
      credentialId,
      replayKey,
      target,
      action,
      scope,
      chain
    );

    MinimalAuthorizationIsTemporallyValidAtZero(
      accountId,
      credentialId,
      replayKey,
      target,
      action,
      scope,
      chain
    );

    MinimalAuthorizationCanRemainReplayFresh(
      accountId,
      subject,
      state,
      credentialId,
      replayKey,
      target,
      action,
      scope,
      chain
    );

    EmptyEffectiveAuthorityIsValid({});

    MinimalAuthorizationFitsEmptyEffectiveAuthority(
      accountId,
      credentialId,
      replayKey,
      target,
      action,
      scope,
      chain
    );

    assert AuthorizationProofIsVerified(true);
  }



  // ==========================================================
  // CURRENT ACCEPTANCE BOUNDARY
  // ==========================================================

  // This is now the central negative property of the scenario.
  //
  // The Account is invalid solely because its sovereign Identity is
  // invalid.
  //
  // Even if every other currently formalized acceptance condition is
  // satisfiable, AuthorizationCanBeAccepted must reject the Account
  // because ValidAccount(account) is an explicit prerequisite of the
  // authoritative acceptance predicate.

  lemma InvalidAccountBlocksAuthorizationAcceptance(
    accountId: AccountId,
    subject: Subject,
    state: AuthorizationState,
    credentialId: Id,
    replayKey: Id,
    target: ExecutionTarget,
    action: DomainAction,
    scope: Scope,
    chain: Chain
  )
    requires ValidId(accountId)
    requires ValidSubject(subject)
    requires ValidAuthorizationState(state)

    requires ValidId(credentialId)
    requires ValidId(replayKey)
    requires ValidScope(scope)

    requires CredentialIdRecognizedInState(
               state,
               credentialId
             )

    requires ActiveCredentialRecognizedInState(
               state,
               credentialId
             )

    requires replayKey
             !in
             StateConsumedReplayKeys(state)

    ensures !ValidAccount(
              InvalidAccountBySovereignIdentity(
                accountId,
                subject,
                state
              )
            )

    ensures !
            AuthorizationCanBeAccepted(
              MinimalAuthorizationForInvalidAccount(
                accountId,
                credentialId,
                replayKey,
                target,
                action,
                scope,
                chain
              ),
              InvalidAccountBySovereignIdentity(
                accountId,
                subject,
                state
              ),
              {},
              {},
              [],
              [],
              [],
              0,
              true
            )
  {
    InvalidAccountAcceptanceAttackPreservesNonAccountConditions(
      accountId,
      subject,
      state,
      credentialId,
      replayKey,
      target,
      action,
      scope,
      chain
    );

    if AuthorizationCanBeAccepted(
        MinimalAuthorizationForInvalidAccount(
          accountId,
          credentialId,
          replayKey,
          target,
          action,
          scope,
          chain
        ),
        InvalidAccountBySovereignIdentity(
          accountId,
          subject,
          state
        ),
        {},
        {},
        [],
        [],
        [],
        0,
        true
      )
    {
      AcceptedAuthorizationHasValidAccount(
        MinimalAuthorizationForInvalidAccount(
          accountId,
          credentialId,
          replayKey,
          target,
          action,
          scope,
          chain
        ),
        InvalidAccountBySovereignIdentity(
          accountId,
          subject,
          state
        ),
        {},
        {},
        [],
        [],
        [],
        0,
        true
      );

      assert false;
    }
  }



  // ==========================================================
  // ACCEPTED AUTHORIZATION IMPLIES ACCOUNT VALIDITY
  // ==========================================================

  // This is the direct reusable boundary theorem.
  //
  // It is intentionally written independently of the particular
  // invalid-account construction above.
  //
  // Any accepted Authorization necessarily uses a valid Account.

  lemma AcceptedAuthorizationAlwaysRequiresValidAccount(
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
    AcceptedAuthorizationHasValidAccount(
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



  // ==========================================================
  // GENERIC NEGATIVE ACCOUNT BOUNDARY
  // ==========================================================

  // General form of the security invariant:
  //
  //     !ValidAccount(account)
  //         =>
  //     !AuthorizationCanBeAccepted(...)
  //
  // This theorem closes the scenario independently from the
  // particular invalid sovereign Identity construction.

  lemma InvalidAccountAlwaysBlocksAuthorizationAcceptance(
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
    requires !ValidAccount(account)
    ensures !AuthorizationCanBeAccepted(
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
      AcceptedAuthorizationAlwaysRequiresValidAccount(
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

      assert false;
    }
  }



  // ==========================================================
  // FINAL SCENARIO RESULT
  // ==========================================================

  // Current formal result:
  //
  //   1. Invalid sovereign Identity
  //
  //        CLOSED
  //
  //      The constructed Account is invalid.
  //
  //   2. AccountId integrity
  //
  //        PRESERVED
  //
  //      The invalidity is not caused by AccountId.
  //
  //   3. AuthorizationState validity
  //
  //        PRESERVED
  //
  //      The state remains valid.
  //
  //   4. Authorization structural validity
  //
  //        PRESERVED
  //
  //   5. Credential usability
  //
  //        PRESERVED
  //
  //   6. Temporal validity
  //
  //        PRESERVED
  //
  //   7. Replay freshness
  //
  //        PRESERVED
  //
  //   8. EffectiveAuthority validity / provenance
  //
  //        PRESERVED
  //
  //   9. Requested authority containment
  //
  //        PRESERVED
  //
  //  10. Proof verification
  //
  //        PRESERVED
  //
  //  11. Authorization acceptance
  //
  //        BLOCKED
  //
  //      because ValidAccount(account) is an explicit acceptance
  //      prerequisite.
  //
  // ------------------------------------------------------------
  //
  // CLASSIFICATION
  //
  // ACCOUNT VALIDITY AT AUTHORIZATION ACCEPTANCE
  //     CLOSED
  //
  // MISSING ValidAccount PREREQUISITE
  //     NOT A CURRENT DEBT
  //
  // DDD CONTRADICTION
  //     NOT PRESENT
  //
  // FORMALIZATION GAP
  //     NOT PRESENT
  //
  // SECURITY BOUNDARY
  //     ENFORCED
  //
  // REMEDIATION
  //     NONE REQUIRED
  //
  // The former adversarial hypothesis has been converted into a
  // verified negative boundary proof.
  //
  // The scenario should remain in the suite because it documents
  // the explicit Account-validity gate and guards against future
  // regression.
}

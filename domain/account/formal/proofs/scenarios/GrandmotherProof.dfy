// ============================================================
// KIPIO ACCOUNT DOMAIN
// SCENARIO — GRANDMOTHER
// ============================================================
//
// A deliberately simple B2C scenario.
//
// The scenario models a normal user interaction:
//
//     Grandmother
//          |
//          v
//       Account
//          |
//          v
//      Credential
//          |
//          v
//   Authorization
//          |
//          v
//   Effective Authority
//          |
//          v
//   ExecutionRequest
//          |
//          v
//   ExecutionContext
//          |
//          v
//      Execution
//
// The scenario intentionally does NOT define:
//
//   - blockchain mechanics;
//   - transaction encoding;
//   - gas;
//   - relayers;
//   - signatures;
//   - concrete DomainAction semantics;
//   - concrete ExecutionTarget semantics;
//   - concrete ExecutionConstraints semantics.
//
// Those remain outside the scenario.
//
// ------------------------------------------------------------
//
// PURPOSE
//
// This file is intentionally adversarial.
//
// It demonstrates that the reusable isolated proof contracts are
// strong enough to compose into an ordinary B2C user journey.
//
// It also deliberately attempts to cross invalid boundaries:
//
//   1. revoked Credential;
//   2. consumed replay key;
//   3. requested Capability outside Effective Authority;
//   4. invalid temporal context;
//   5. invalid Effective Authority;
//   6. execution authority expansion;
//   7. Authorization replacement;
//   8. AuthorizationState replacement;
//   9. execution remaining downstream from accepted authorization.
//
// The scenario does not invent stronger guarantees than those
// already established by the semantic model and isolated proofs.
//
// ------------------------------------------------------------
//
// CURRENT FORMAL BOUNDARY
//
// AuthorizationCanBeAccepted is now contextual.
//
// In addition to the Authorization, Account and EffectiveAuthority,
// acceptance receives:
//
//   identities
//   sourceAuthorities
//   contributions
//
// These values are ghost contextual evidence used to establish the
// currently formalized EffectiveAuthority provenance boundary.
//
// Therefore this scenario MUST NOT silently revert to the historical
// five-argument acceptance form.
//
// Likewise, the execution boundary is now Account-relative:
//
//   ValidExecutionContextForAccount(
//     context,
//     account,
//     identities,
//     sourceAuthorities,
//     contributions,
//     proofVerified
//   )
//
// This is stronger than the historical unary structural predicate.
//
// ------------------------------------------------------------
//
// METHODOLOGICAL RULE
//
// A `requires` clause is an assumption.
//
// Therefore:
//
//     requires EffectiveAuthorityWithinSourceAuthority(...)
//
// is caller-supplied evidence unless the preceding domain contract
// itself derives that relation.
//
// This scenario distinguishes:
//
//     MODEL GUARANTEE
//
// from:
//
//     CONTEXTUAL / GHOST EVIDENCE
//
// It does not convert the latter into a hidden semantic theorem.
//
// ============================================================


include "../isolated/AccountProofs.dfy"
include "../isolated/AuthorityProofs.dfy"
include "../isolated/AuthorizationProofs.dfy"
include "../isolated/ExecutionProofs.dfy"


module KipioAccountGrandmotherProof
{
  // ----------------------------------------------------------
  // SOURCE DOMAINS
  // ----------------------------------------------------------

  import opened KipioAccountDomainPrimitives
  import opened KipioAccountCapability
  import opened KipioAccountIdentity

  import opened KipioAccountAccount
  import opened KipioAccountAccountTransitions

  import opened KipioAccountAuthorizationState
  import opened KipioAccountCredential
  import opened KipioAccountCredentialAuthority
  import opened KipioAccountEffectiveAuthority

  import opened KipioAccountAuthorization
  import opened KipioAccountAuthorizationValidation
  import opened KipioAccountReplay

  import opened KipioAccountDomainAction
  import opened KipioAccountExecutionConstraints
  import opened KipioAccountExecutionRequest
  import opened KipioAccountExecutionContext
  import opened KipioAccountExecutionSemantics
  import opened KipioAccountExecutionTarget


  // ----------------------------------------------------------
  // ISOLATED PROOF FACADES
  // ----------------------------------------------------------

  import opened KipioAccountProofs
  import opened KipioAccountAuthorityProofs
  import opened KipioAccountAuthorizationProofs
  import opened KipioAccountExecutionProofs


  // ==========================================================
  // GRANDMOTHER — BASE ACCOUNT CONTRACT
  // ==========================================================

  // A normal user starts with a structurally valid Account.
  //
  // The scenario does not construct a concrete Identity.

  lemma GrandmotherAccountHasValidIdentity(
    account: Account
  )
    requires ValidAccount(account)

    ensures ValidId(
              AccountIdOf(account)
            )

    ensures ValidIdentity(
              AccountSovereignIdentity(account)
            )

    ensures ValidAuthorizationState(
              AccountAuthorizationState(account)
            )
  {
    AccountProofHasValidAccountId(account);
    AccountProofHasValidSovereignIdentity(account);
    AccountProofHasValidAuthorizationState(account);
  }


  // Account identity remains stable across a valid transition.

  lemma GrandmotherAccountBoundaryIsStable(
    before: Account,
    after: Account
  )
    requires ValidAccount(before)
    requires ValidAccount(after)

    requires AccountTransitionPreservesIdentity(
               before,
               after
             )

    ensures SameAccount(before, after)

    ensures AccountIdOf(before)
         == AccountIdOf(after)

    ensures AccountSovereignIdentity(before)
         == AccountSovereignIdentity(after)
  {
    AccountTransitionProvidesReusableIdentityContract(
      before,
      after
    );
  }


  // ==========================================================
  // GRANDMOTHER — CREDENTIAL
  // ==========================================================

  // A valid Credential can become recognized by the Account.
  //
  // Registration establishes recognition, but this scenario does
  // not pretend that registration itself proves any nontrivial
  // Credential Authority.

  lemma GrandmotherCredentialCanBeRegistered(
    account: Account,
    credential: Credential
  )
    requires ValidAccount(account)

    requires ValidCredential(credential)

    requires !CredentialIdRecognizedInState(
               AccountAuthorizationState(account),
               CredentialId(credential)
             )

    ensures ValidAccount(
              RegisterCredential(
                account,
                credential
              )
            )

    ensures CredentialIdRecognizedInState(
              AccountAuthorizationState(
                RegisterCredential(
                  account,
                  credential
                )
              ),
              CredentialId(credential)
            )

    ensures StateCredentialAuthority(
              AccountAuthorizationState(
                RegisterCredential(
                  account,
                  credential
                )
              ),
              credential
            )
            ==
            {}

    ensures AccountIdOf(account)
            ==
            AccountIdOf(
              RegisterCredential(
                account,
                credential
              )
            )

    ensures AccountSovereignIdentity(account)
            ==
            AccountSovereignIdentity(
              RegisterCredential(
                account,
                credential
              )
            )
  {
    RegisteredCredentialProvidesReusableProofContract(
      account,
      credential
    );
  }


  // Registration does not replace the Account identity.

  lemma GrandmotherCredentialRegistrationPreservesAccount(
    account: Account,
    credential: Credential
  )
    requires ValidAccount(account)

    requires ValidCredential(credential)

    requires !CredentialIdRecognizedInState(
               AccountAuthorizationState(account),
               CredentialId(credential)
             )

    ensures AccountIdOf(account)
            ==
            AccountIdOf(
              RegisterCredential(
                account,
                credential
              )
            )

    ensures AccountSovereignIdentity(account)
            ==
            AccountSovereignIdentity(
              RegisterCredential(
                account,
                credential
              )
            )
  {
    RegisteredCredentialProvidesReusableProofContract(
      account,
      credential
    );
  }


  // ==========================================================
  // GRANDMOTHER — ACCEPTED AUTHORIZATION
  // ==========================================================

  // The current Authorization contract is Account-relative and
  // provenance-aware.
  //
  // Therefore acceptance is always stated with its complete
  // contextual evidence:
  //
  //   identities
  //   sourceAuthorities
  //   contributions
  //
  // The scenario does not redefine what those ghost values mean.

  lemma GrandmotherAcceptedAuthorizationIsUsable(
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

    ensures AuthorizationIsStructurallyValid(
              authorization
            )

    ensures AuthorizationContextMatchesAccount(
              authorization,
              account
            )

    ensures AuthorizationCredentialIsRecognized(
              authorization,
              AccountAuthorizationState(account)
            )

    ensures AuthorizationCredentialIsActive(
              authorization,
              AccountAuthorizationState(account)
            )

    ensures AuthorizationCredentialIsUsable(
              authorization,
              AccountAuthorizationState(account)
            )

    ensures AuthorizationIsTemporallyValidAt(
              authorization,
              now
            )

    ensures AuthorizationReplayIsFresh(
              authorization,
              AccountAuthorizationState(account)
            )

    ensures ValidEffectiveAuthority(
              effectiveAuthority
            )

    ensures AuthorizationAuthorityIsEffective(
              authorization,
              effectiveAuthority
            )

    ensures AuthorizationProofIsVerified(
              proofVerified
            )
  {
    AcceptedAuthorizationSatisfiesAllValidationBoundaries(
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


  // Accepted Authorization is also explicitly bounded by the
  // resolved EffectiveAuthority.

  lemma GrandmotherAcceptedAuthorizationPreservesAuthorityBoundary(
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

    ensures AuthorizationRequestedAuthority(authorization)
         <= effectiveAuthority
  {
    AcceptedAuthorizationRequestsSubsetOfEffectiveAuthority(
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
  // GRANDMOTHER — EXECUTION REQUEST
  // ==========================================================

  // DomainAction, ExecutionTarget and ExecutionConstraints remain
  // opaque values at this bounded-context boundary.

  lemma GrandmotherRequestPreservesAuthorization(
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
            ==
            authorization
  {
    assert ExecutionRequestAuthorization(
        ExecutionRequest(
          action,
          authorization,
          target,
          constraints
        )
      )
           ==
           authorization;
  }


  // The request's Action and Target must remain semantically aligned
  // with the Authorization that it transports.

  lemma GrandmotherRequestContextMatchesAuthorization(
    action: DomainAction,
    authorization: Authorization,
    target: ExecutionTarget,
    constraints: ExecutionConstraints
  )
    requires ValidAuthorization(authorization)

    requires action
             ==
             AuthorizationDomainAction(
               authorization
             )

    requires target
             ==
             AuthorizationExecutionTarget(
               authorization
             )

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
  // GRANDMOTHER — EXECUTION CONTEXT
  // ==========================================================

  // An already accepted Authorization can be carried into a valid
  // Account-relative ExecutionContext.
  //
  // The contextual provenance witnesses are deliberately passed
  // through unchanged.

  lemma GrandmotherCanCarryAcceptedAuthorizationIntoContext(
    action: DomainAction,
    authorization: Authorization,
    target: ExecutionTarget,
    constraints: ExecutionConstraints,
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

    requires ValidAuthorizationState(
               AccountAuthorizationState(account)
             )

    requires ValidEffectiveAuthority(
               effectiveAuthority
             )

    requires AuthorizationRequestedAuthority(
               authorization
             )
             <=
             effectiveAuthority

    requires action
             ==
             AuthorizationDomainAction(
               authorization
             )

    requires target
             ==
             AuthorizationExecutionTarget(
               authorization
             )

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
              sourceReferences,
              sourceAuthorities,
              contributions,
              proofVerified
            )
  {
    GrandmotherAcceptedAuthorizationIsUsable(
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

    GrandmotherRequestContextMatchesAuthorization(
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
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified
    );
  }


  // ==========================================================
  // GRANDMOTHER — FULL HAPPY PATH
  // ==========================================================

  // Complete ordinary B2C path:
  //
  //     valid Account
  //         +
  //     accepted Authorization
  //         +
  //     valid EffectiveAuthority
  //         +
  //     request context consistent with Authorization
  //         +
  //     contextual provenance evidence
  //         ↓
  //     valid Account-relative ExecutionContext
  //
  // The execution layer receives an already-established domain
  // decision; it does not create new authority.

  lemma GrandmotherHappyPath(
    action: DomainAction,
    authorization: Authorization,
    target: ExecutionTarget,
    constraints: ExecutionConstraints,
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

    requires ValidAuthorizationState(
               AccountAuthorizationState(account)
             )

    requires ValidEffectiveAuthority(
               effectiveAuthority
             )

    requires AuthorizationRequestedAuthority(
               authorization
             )
             <=
             effectiveAuthority

    requires action
             ==
             AuthorizationDomainAction(
               authorization
             )

    requires target
             ==
             AuthorizationExecutionTarget(
               authorization
             )

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
              sourceReferences,
              sourceAuthorities,
              contributions,
              proofVerified
            )

    ensures RequestedAuthorityWithinEffectiveAuthority(
              authorization,
              effectiveAuthority
            )
  {
    GrandmotherCanCarryAcceptedAuthorizationIntoContext(
      action,
      authorization,
      target,
      constraints,
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
  // BREAK 1 — REVOKED / INACTIVE CREDENTIAL
  // ==========================================================

  // Revocation must not destroy Entity recognition.
  //
  // This explicitly tests:
  //
  //     recognized != usable

  lemma GrandmotherRevokedCredentialRemainsRecognized(
    account: Account,
    credential: Credential
  )
    requires ValidAccount(account)

    requires credential
             in
               StateCredentials(
                 AccountAuthorizationState(account)
               )

    requires CredentialIsRevoked(credential)

    ensures CredentialIdRecognizedInState(
              AccountAuthorizationState(account),
              CredentialId(credential)
            )
  {
    RevokedCredentialRemainsRecognizedInAccountProof(
      account,
      credential
    );
  }


  // A recognized but inactive Credential cannot satisfy the active
  // Credential acceptance boundary.
  //
  // This is the current semantic boundary; the scenario does not
  // reimplement the revocation semantics itself.

  lemma GrandmotherRevokedCredentialBlocksAuthorization(
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
    requires AuthorizationCredentialIsRecognized(
               authorization,
               AccountAuthorizationState(account)
             )

    requires !AuthorizationCredentialIsActive(
               authorization,
               AccountAuthorizationState(account)
             )

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
    InactiveCredentialBlocksAcceptance(
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
  // BREAK 2 — REPLAY
  // ==========================================================

  // A consumed replay key cannot be accepted again.

  lemma GrandmotherReplayCannotBeAcceptedAgain(
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
    requires AuthorizationReplayKey(authorization)
             in
               StateConsumedReplayKeys(
                 AccountAuthorizationState(account)
               )

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
    ConsumedReplayKeyBlocksAuthorizationAcceptance(
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
  // BREAK 3 — OVER-PERMISSION
  // ==========================================================

  // A requested Capability outside EffectiveAuthority prevents
  // Authorization acceptance.

  lemma GrandmotherCannotExerciseCapabilityOutsideAuthority(
    authorization: Authorization,
    account: Account,
    effectiveAuthority: EffectiveAuthority,
    capability: Capability,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool
  )
    requires AuthorizationRequestsCapability(
               authorization,
               capability
             )

    requires capability
             !in effectiveAuthority

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
    assert !AuthorizationAuthorityIsEffective(
        authorization,
        effectiveAuthority
      );

    ExcessiveRequestedAuthorityBlocksAcceptance(
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
  // BREAK 4 — TOO EARLY
  // ==========================================================

  // A structurally valid Authorization cannot be accepted before
  // its validity interval begins.

  lemma GrandmotherCannotUseAuthorizationTooEarly(
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
    requires now
             <
             AuthorizationValidFrom(
               authorization
             )

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
    AuthorizationCannotBeAcceptedBeforeValidityBegins(
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
  // BREAK 5 — TOO LATE
  // ==========================================================

  // A structurally valid Authorization cannot be accepted after
  // its validity interval ends.

  lemma GrandmotherCannotUseExpiredAuthorization(
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
    requires now
             >
             AuthorizationValidUntil(
               authorization
             )

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
    AuthorizationCannotBeAcceptedAfterValidityEnds(
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
  // BREAK 6 — INVALID AUTHORITY
  // ==========================================================

  // The execution layer cannot repair an invalid EffectiveAuthority.

  lemma GrandmotherInvalidAuthorityCannotReachAuthorization(
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
    requires !ValidEffectiveAuthority(
               effectiveAuthority
             )

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
    InvalidEffectiveAuthorityBlocksAcceptance(
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
  // BREAK 7 — EXECUTION CANNOT EXPAND AUTHORITY
  // ==========================================================

  // Execution receives the already-resolved EffectiveAuthority.
  //
  // The full Account-relative execution contract is used rather
  // than the obsolete unary ValidExecutionContext predicate.

  lemma GrandmotherExecutionCannotExpandAuthority(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool
  )
    requires ValidExecutionContextForAccount(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified
             )

    ensures AuthorizationRequestedAuthority(
              ExecutionContextAuthorization(context)
            )
            <=
            ExecutionContextEffectiveAuthority(context)
  {
    ExecutionCannotExpandRequestedAuthority(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified
    );
  }


  // ==========================================================
  // BREAK 8 — EXECUTION CANNOT REPLACE AUTHORIZATION
  // ==========================================================

  // The Authorization observed by execution is exactly the
  // Authorization contained in the ExecutionRequest.

  lemma GrandmotherExecutionCannotReplaceAuthorization(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool
  )
    requires ValidExecutionContextForAccount(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified
             )

    ensures ExecutionContextAuthorization(context)
            ==
            ExecutionRequestAuthorization(
              ExecutionContextRequest(context)
            )
  {
    ExecutionPreservesAuthorization(
      context
    );
  }


  // ==========================================================
  // BREAK 9 — EXECUTION CANNOT REPLACE STATE SNAPSHOT
  // ==========================================================

  // Execution preserves the AuthorizationState snapshot represented
  // by the ExecutionContext.

  lemma GrandmotherExecutionCannotReplaceAuthorizationState(
    context: ExecutionContext
  )
    ensures ExecutionContextAuthorizationState(context)
            ==
            context.authorizationState
  {
    ExecutionPreservesAuthorizationStateSnapshot(
      context
    );
  }


  // ==========================================================
  // BREAK 10 — EXECUTION REMAINS DOWNSTREAM FROM AUTHORIZATION
  // ==========================================================

  // Execution remains downstream from the already-established
  // Authorization / EffectiveAuthority relation.
  //
  // The guarantee is intentionally delegated to the current
  // ExecutionProofs facade. This scenario does not recreate a
  // separate "downstream" semantic law.

  lemma GrandmotherExecutionRemainsDownstreamOfAuthorization(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool
  )
    requires ValidExecutionContextForAccount(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified
             )

    ensures RequestedAuthorityWithinEffectiveAuthority(
              ExecutionContextAuthorization(context),
              ExecutionContextEffectiveAuthority(context)
            )
  {
    ValidContextPreservesAuthorityBoundary(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified
    );
  }


  // ==========================================================
  // BREAK 11 — EXECUTION PRESERVES REQUEST CONTEXT
  // ==========================================================

  // DomainAction, ExecutionTarget and ExecutionConstraints remain
  // attached to the request carried by the ExecutionContext.
  //
  // The scenario does not interpret those opaque values.

  lemma GrandmotherExecutionPreservesRequestContext(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool
  )
    requires ValidExecutionContextForAccount(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified
             )

    ensures ExecutionContextRequest(context)
            ==
            context.request

    ensures ExecutionRequestAction(
              ExecutionContextRequest(context)
            )
            ==
            ExecutionRequestAction(
              context.request
            )

    ensures ExecutionRequestTarget(
              ExecutionContextRequest(context)
            )
            ==
            ExecutionRequestTarget(
              context.request
            )

    ensures ExecutionContextConstraints(context)
            ==
            ExecutionRequestConstraints(
              ExecutionContextRequest(context)
            )
  {
    ExecutionContextPreservesRequest(
      context
    );

    ExecutionPreservesDomainAction(
      context
    );

    ExecutionPreservesExecutionTarget(
      context
    );

    ExecutionPreservesExecutionConstraints(
      context
    );
  }


  // ==========================================================
  // REUSABLE GRANDMOTHER CONTRACT
  // ==========================================================

  // Compact scenario-level contract.
  //
  // A future E2E scenario can establish the same assumptions and
  // recover the complete currently-formalized B2C boundary:
  //
  //     Account
  //       +
  //     accepted Authorization
  //       +
  //     contextual provenance evidence
  //       +
  //     resolved EffectiveAuthority
  //       +
  //     request/context consistency
  //       ↓
  //     ValidExecutionContextForAccount
  //
  // This is intentionally a composition contract.
  // It does not introduce new authorization semantics.

  lemma GrandmotherProvidesReusableScenarioContract(
    action: DomainAction,
    authorization: Authorization,
    target: ExecutionTarget,
    constraints: ExecutionConstraints,
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

    requires ValidAuthorizationState(
               AccountAuthorizationState(account)
             )

    requires ValidEffectiveAuthority(
               effectiveAuthority
             )

    requires AuthorizationRequestedAuthority(
               authorization
             )
             <=
             effectiveAuthority

    requires action
             ==
             AuthorizationDomainAction(
               authorization
             )

    requires target
             ==
             AuthorizationExecutionTarget(
               authorization
             )

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
              sourceReferences,
              sourceAuthorities,
              contributions,
              proofVerified
            )

    ensures ValidAuthorization(
              authorization
            )

    ensures AuthorizationCredentialIsUsable(
              authorization,
              AccountAuthorizationState(account)
            )

    ensures AuthorizationReplayIsFresh(
              authorization,
              AccountAuthorizationState(account)
            )

    ensures AuthorizationIsTemporallyValidAt(
              authorization,
              now
            )

    ensures AuthorizationAuthorityIsEffective(
              authorization,
              effectiveAuthority
            )

    ensures RequestedAuthorityWithinEffectiveAuthority(
              authorization,
              effectiveAuthority
            )
  {
    GrandmotherHappyPath(
      action,
      authorization,
      target,
      constraints,
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

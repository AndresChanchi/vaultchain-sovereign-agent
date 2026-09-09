// ============================================================
// KIPIO ACCOUNT DOMAIN
// SCENARIO — RECOVERY
// ============================================================
//
// Recovery validates Credential lifecycle boundaries.
//
// The scenario establishes:
//
//     Active Credential
//          |
//          v
//     Credential revoked
//          |
//          +--> Credential identity preserved
//          +--> Credential remains recognized
//          +--> Credential is no longer active
//          |
//          v
//     Authorization referencing the Credential
//          |
//          v
//     Authorization cannot be accepted
//
// Core invariant:
//
//     Credential recognition survives lifecycle changes,
//     but Credential usability does not.
//
// ============================================================

include "../isolated/AccountProofs.dfy"
include "../isolated/AuthorizationProofs.dfy"

module KipioAccountRecoveryProof
{
  // ----------------------------------------------------------
  // DOMAIN IMPORTS
  // ----------------------------------------------------------

  import opened KipioAccountDomainPrimitives
  import opened KipioAccountCapability
  import opened KipioAccountIdentity

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

  import opened KipioAccountProofs
  import opened KipioAccountAuthorizationProofs


  // ==========================================================
  // PRECONDITION
  // ==========================================================

  lemma RecoveryActiveCredentialBeforeRevocation(
    account: Account,
    credential: Credential
  )
    requires ValidAccount(account)
    requires ValidCredential(credential)
    requires credential in StateCredentials(
                             AccountAuthorizationState(account)
                           )
    requires CredentialIsActive(credential)
    ensures CredentialIdRecognizedInState(
              AccountAuthorizationState(account),
              CredentialId(credential)
            )
    ensures ValidId(CredentialId(credential))
  {
    assert ValidId(CredentialId(credential));

    assert CredentialIdRecognizedInState(
        AccountAuthorizationState(account),
        CredentialId(credential)
      );
  }


  // ==========================================================
  // ATTACK 1 — CREDENTIAL IDENTITY SURVIVES REVOCATION
  // ==========================================================

  lemma RecoveryRevocationPreservesCredentialIdentity(
    account: Account,
    credential: Credential
  )
    requires ValidAccount(account)
    requires credential in StateCredentials(
                             AccountAuthorizationState(account)
                           )
    requires CredentialIsActive(credential)
    requires ValidCredentialStatusTransition(
               credential,
               CredentialStatus.Revoked
             )
    ensures SameCredential(
              credential,
              Credential(
                CredentialId(credential),
                CredentialStatus.Revoked
              )
            )
    ensures CredentialId(
              Credential(
                CredentialId(credential),
                CredentialStatus.Revoked
              )
            ) == CredentialId(credential)
  {
    ValidCredentialStatusTransitionPreservesId(
      credential,
      CredentialStatus.Revoked
    );

    LifecycleStateDoesNotChangeCredentialIdentity(
      credential,
      Credential(
        CredentialId(credential),
        CredentialStatus.Revoked
      )
    );

    assert CredentialId(
        Credential(
          CredentialId(credential),
          CredentialStatus.Revoked
        )
      ) == CredentialId(credential);
  }


  // ==========================================================
  // ATTACK 2 — RECOGNITION SURVIVES REVOCATION
  // ==========================================================

  lemma RecoveryRevokedCredentialRemainsRecognized(
    account: Account,
    credential: Credential
  )
    requires ValidAccount(account)
    requires credential in StateCredentials(
                             AccountAuthorizationState(account)
                           )
    requires CredentialIsActive(credential)
    requires ValidCredentialStatusTransition(
               credential,
               CredentialStatus.Revoked
             )
    ensures CredentialIdRecognizedInState(
              AccountAuthorizationState(
                UpdateCredentialStatus(
                  account,
                  credential,
                  CredentialStatus.Revoked
                )
              ),
              CredentialId(credential)
            )
  {
    UpdatedCredentialRemainsRecognized(
      account,
      credential,
      CredentialStatus.Revoked
    );
  }


  // ==========================================================
  // ATTACK 3 — REVOCATION PRESERVES STATE VALIDITY
  // ==========================================================

  lemma RecoveryRevocationPreservesAuthorizationStateValidity(
    account: Account,
    credential: Credential
  )
    requires ValidAccount(account)
    requires credential in StateCredentials(
                             AccountAuthorizationState(account)
                           )
    requires ValidCredentialStatusTransition(
               credential,
               CredentialStatus.Revoked
             )
    ensures ValidAuthorizationState(
              AccountAuthorizationState(
                UpdateCredentialStatus(
                  account,
                  credential,
                  CredentialStatus.Revoked
                )
              )
            )
  {
    KipioAccountAccountTransitions
      .UpdateCredentialStatusPreservesAuthorizationStateValidity(
      account,
      credential,
      CredentialStatus.Revoked
    );
  }


  // ==========================================================
  // ATTACK 4 — RECOGNIZED BUT NO LONGER ACTIVE
  // ==========================================================

  lemma RecoveryRevokedCredentialIsRecognizedButInactive(
    account: Account,
    credential: Credential
  )
    requires ValidAccount(account)
    requires credential in StateCredentials(
                             AccountAuthorizationState(account)
                           )
    requires CredentialIsActive(credential)
    requires ValidCredentialStatusTransition(
               credential,
               CredentialStatus.Revoked
             )
    ensures CredentialIdRecognizedInState(
              AccountAuthorizationState(
                UpdateCredentialStatus(
                  account,
                  credential,
                  CredentialStatus.Revoked
                )
              ),
              CredentialId(credential)
            )
    ensures !CredentialIsActive(
              Credential(
                CredentialId(credential),
                CredentialStatus.Revoked
              )
            )
  {
    UpdatedCredentialRemainsRecognized(
      account,
      credential,
      CredentialStatus.Revoked
    );

    RevokedCredentialIsNotActive(
      Credential(
        CredentialId(credential),
        CredentialStatus.Revoked
      )
    );
  }


  // ==========================================================
  // ATTACK 5 — AUTHORIZATION REFERENCE SURVIVES REVOCATION
  // ==========================================================

  lemma RecoveryOldAuthorizationReferencesRecognizedCredential(
    account: Account,
    credential: Credential,
    authorization: Authorization
  )
    requires ValidAccount(account)
    requires credential in StateCredentials(
                             AccountAuthorizationState(account)
                           )
    requires CredentialIsActive(credential)
    requires AuthorizationCredentialId(authorization)
          == CredentialId(credential)
    requires ValidCredentialStatusTransition(
               credential,
               CredentialStatus.Revoked
             )
    ensures AuthorizationCredentialIsRecognized(
              authorization,
              AccountAuthorizationState(
                UpdateCredentialStatus(
                  account,
                  credential,
                  CredentialStatus.Revoked
                )
              )
            )
  {
    UpdatedCredentialRemainsRecognized(
      account,
      credential,
      CredentialStatus.Revoked
    );

    assert AuthorizationCredentialIsRecognized(
        authorization,
        AccountAuthorizationState(
          UpdateCredentialStatus(
            account,
            credential,
            CredentialStatus.Revoked
          )
        )
      );
  }


  // ==========================================================
  // ATTACK 6 — REVOKED CREDENTIAL CANNOT BE ACTIVE
  // ==========================================================

  lemma RecoveryOldAuthorizationCannotSeeRevokedCredentialAsActive(
    account: Account,
    credential: Credential,
    authorization: Authorization
  )
    requires ValidAccount(account)
    requires credential in StateCredentials(
                             AccountAuthorizationState(account)
                           )
    requires CredentialIsActive(credential)
    requires AuthorizationCredentialId(authorization)
          == CredentialId(credential)
    requires ValidCredentialStatusTransition(
               credential,
               CredentialStatus.Revoked
             )
    ensures !AuthorizationCredentialIsActive(
              authorization,
              AccountAuthorizationState(
                UpdateCredentialStatus(
                  account,
                  credential,
                  CredentialStatus.Revoked
                )
              )
            )
  {
    assert !AuthorizationCredentialIsActive(
        authorization,
        AccountAuthorizationState(
          UpdateCredentialStatus(
            account,
            credential,
            CredentialStatus.Revoked
          )
        )
      );
  }


  // ==========================================================
  // ATTACK 7 — OLD AUTHORIZATION REUSE IS REJECTED
  // ==========================================================

  lemma RecoveryRevokedCredentialBlocksOldAuthorization(
    account: Account,
    credential: Credential,
    authorization: Authorization,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool
  )
    requires ValidAccount(account)
    requires credential in StateCredentials(
                             AccountAuthorizationState(account)
                           )
    requires CredentialIsActive(credential)
    requires AuthorizationCredentialId(authorization)
          == CredentialId(credential)
    requires ValidCredentialStatusTransition(
               credential,
               CredentialStatus.Revoked
             )
    ensures !AuthorizationCanBeAccepted(
              authorization,
              UpdateCredentialStatus(
                account,
                credential,
                CredentialStatus.Revoked
              ),
              effectiveAuthority,
              identities,
              sourceReferences,
              sourceAuthorities,
              contributions,
              now,
              proofVerified
            )
  {
    assert !AuthorizationCredentialIsActive(
        authorization,
        AccountAuthorizationState(
          UpdateCredentialStatus(
            account,
            credential,
            CredentialStatus.Revoked
          )
        )
      );

    assert !AuthorizationCanBeAccepted(
        authorization,
        UpdateCredentialStatus(
          account,
          credential,
          CredentialStatus.Revoked
        ),
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
  // ATTACK 8 — REVOCATION DOMINATES AUTHORIZATION CONTEXT
  // ==========================================================

  lemma RecoveryRevocationDominatesAuthorizationContext(
    account: Account,
    credential: Credential,
    authorization: Authorization,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool
  )
    requires ValidAccount(account)
    requires credential in StateCredentials(
                             AccountAuthorizationState(account)
                           )
    requires CredentialIsActive(credential)
    requires AuthorizationCredentialId(authorization)
          == CredentialId(credential)
    requires ValidCredentialStatusTransition(
               credential,
               CredentialStatus.Revoked
             )
    ensures !AuthorizationCanBeAccepted(
              authorization,
              UpdateCredentialStatus(
                account,
                credential,
                CredentialStatus.Revoked
              ),
              effectiveAuthority,
              identities,
              sourceReferences,
              sourceAuthorities,
              contributions,
              now,
              proofVerified
            )
  {
    assert !AuthorizationCredentialIsActive(
        authorization,
        AccountAuthorizationState(
          UpdateCredentialStatus(
            account,
            credential,
            CredentialStatus.Revoked
          )
        )
      );

    assert !AuthorizationCanBeAccepted(
        authorization,
        UpdateCredentialStatus(
          account,
          credential,
          CredentialStatus.Revoked
        ),
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
  // ATTACK 9 — IDENTITY AND USABILITY ARE DISTINCT
  // ==========================================================

  lemma RecoverySeparatesCredentialIdentityFromUsability(
    credential: Credential
  )
    requires ValidCredential(credential)
    requires CredentialIsActive(credential)
    ensures SameCredential(
              credential,
              Credential(
                CredentialId(credential),
                CredentialStatus.Revoked
              )
            )
    ensures !CredentialIsActive(
              Credential(
                CredentialId(credential),
                CredentialStatus.Revoked
              )
            )
  {
    LifecycleStateDoesNotChangeCredentialIdentity(
      credential,
      Credential(
        CredentialId(credential),
        CredentialStatus.Revoked
      )
    );

    RevokedCredentialIsNotActive(
      Credential(
        CredentialId(credential),
        CredentialStatus.Revoked
      )
    );
  }


  // ==========================================================
  // REUSABLE RECOVERY CONTRACT
  // ==========================================================

  lemma RecoveryProvidesReusableScenarioContract(
    account: Account,
    credential: Credential,
    authorization: Authorization,
    effectiveAuthority: EffectiveAuthority,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    now: Timestamp,
    proofVerified: bool
  )
    requires ValidAccount(account)
    requires credential in StateCredentials(
                             AccountAuthorizationState(account)
                           )
    requires CredentialIsActive(credential)
    requires AuthorizationCredentialId(authorization)
          == CredentialId(credential)
    requires ValidCredentialStatusTransition(
               credential,
               CredentialStatus.Revoked
             )
    ensures SameCredential(
              credential,
              Credential(
                CredentialId(credential),
                CredentialStatus.Revoked
              )
            )
    ensures CredentialIdRecognizedInState(
              AccountAuthorizationState(
                UpdateCredentialStatus(
                  account,
                  credential,
                  CredentialStatus.Revoked
                )
              ),
              CredentialId(credential)
            )
    ensures !CredentialIsActive(
              Credential(
                CredentialId(credential),
                CredentialStatus.Revoked
              )
            )
    ensures !AuthorizationCredentialIsActive(
              authorization,
              AccountAuthorizationState(
                UpdateCredentialStatus(
                  account,
                  credential,
                  CredentialStatus.Revoked
                )
              )
            )
    ensures !AuthorizationCanBeAccepted(
              authorization,
              UpdateCredentialStatus(
                account,
                credential,
                CredentialStatus.Revoked
              ),
              effectiveAuthority,
              identities,
              sourceReferences,
              sourceAuthorities,
              contributions,
              now,
              proofVerified
            )
  {
    LifecycleStateDoesNotChangeCredentialIdentity(
      credential,
      Credential(
        CredentialId(credential),
        CredentialStatus.Revoked
      )
    );

    UpdatedCredentialRemainsRecognized(
      account,
      credential,
      CredentialStatus.Revoked
    );

    RevokedCredentialIsNotActive(
      Credential(
        CredentialId(credential),
        CredentialStatus.Revoked
      )
    );

    assert !AuthorizationCredentialIsActive(
        authorization,
        AccountAuthorizationState(
          UpdateCredentialStatus(
            account,
            credential,
            CredentialStatus.Revoked
          )
        )
      );

    assert !AuthorizationCanBeAccepted(
        authorization,
        UpdateCredentialStatus(
          account,
          credential,
          CredentialStatus.Revoked
        ),
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
  // RECOVERY BOUNDARY
  // ==========================================================
  //
  // Credential identity       is preserved.
  // Credential recognition    is preserved.
  // Credential activity      is revoked.
  // Authorization reuse      is rejected.
  // Authorization context    cannot bypass revocation.
}

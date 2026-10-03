// ============================================================
// KIPIO ACCOUNT DOMAIN — INJECTED COMPOSITION
// AUTHORIZATION — AUTHORIZATION ACCEPTANCE COMPOSITION
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
include "AuthorizationValidation.dfy"


module KipioAccountAuthorizationAcceptanceComposition {
  import opened KipioAccountAuthorization
  import opened KipioAccountAccount
  import opened KipioAccountAuthorizationState
  import opened KipioAccountCapability
  import opened KipioAccountAuthorizationValidation

  function AuthorizationCanBeAccepted(
    authorization: Authorization,
    account: Account,
    state: AuthorizationState,
    effectiveAuthority: set<Capability>,
    now: int,
    proofVerified: bool
  ): bool
  {
    AuthorizationIsStructurallyValid(authorization) &&
    AuthorizationCredentialIsUsable(authorization, state) &&
    AuthorizationContextMatchesAccount(authorization, account) &&
    AuthorizationIsTemporallyValidAt(authorization, now) &&
    AuthorizationReplayIsFresh(authorization, state) &&
    AuthorizationAuthorityIsEffective(authorization, effectiveAuthority) &&
    AuthorizationProofIsVerified(proofVerified)
  }
}

// ============================================================
// KIPIO ACCOUNT DOMAIN — INJECTED COMPOSITION
// EXECUTION — EXECUTION CONTEXT COMPOSITION
// ============================================================
//
// Executable counterpart of ValidExecutionContextForAccount.
//
// The ghost predicate ValidExecutionContextForAccount requires:
//
//   - Structural validity of the ExecutionContext value;
//   - Request / Authorization context consistency;
//   - AuthorizationState snapshot validity;
//   - EffectiveAuthority validity;
//   - RequestedAuthority ⊆ EffectiveAuthority;
//   - Credential recognition and usability;
//   - The context's state snapshot equals the account's current state;
//   - The carried Authorization has crossed the acceptance boundary,
//     with full EffectiveAuthority provenance.
//
// The acceptance step (AuthorizationCanBeAccepted) is ghost because
// it takes ghost provenance witnesses. Its executable counterpart
// AuthorizationCanBeAcceptedFull (from the authorization inject)
// constructs the witness internally.
//
// This file provides:
//
//   - ExecutionContextUsesAccountAuthorizationStateExec, the
//     executable counterpart of the ghost state/account
//     association predicate;
//
//   - StructurallyValidExecutionContextExec, a stable wrapper
//     around StructurallyValidExecutionContext (already executable);
//
//   - ValidExecutionContextForAccountFull, an executable method
//     that:
//       * checks structural validity of the context;
//       * checks that the context's snapshot equals the account's
//         current state;
//       * checks ValidAccount(account);
//       * checks identity context validity;
//       * calls AuthorizationCanBeAcceptedFull for the acceptance
//         decision (internal witness construction);
//       * verifies that the context's EffectiveAuthority equals the
//         canonical derivation ComputeEffectiveAuthorityWitness
//         returns for (account, identities, evaluationTime).
//
// The last check preserves the semantics of the ghost predicate
// (which requires the caller-supplied EffectiveAuthority to be the
// valid one) without requiring the caller to supply a witness.
//
// No new domain semantics is introduced. This is a computable
// counterpart of the already verified ghost relation.
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

include "../authorization/Authorization.dfy"
include "../authorization/AuthorizationValidation.dfy"
include "../authorization/AuthorizationAcceptanceWithProvenance.dfy"

include "../execution/ExecutionConstraints.dfy"
include "../execution/ExecutionRequest.dfy"
include "../execution/ExecutionContext.dfy"


module KipioAccountExecutionContextComposition {

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
    import opened KipioAccountExecutionConstraints
    import opened KipioAccountExecutionRequest
    import opened KipioAccountExecutionContext

    import opened KipioAccountAuthorizationAcceptanceWithProvenance
    import opened KipioAccountEffectiveAuthorityComposition


    // ==========================================================
    // EXECUTABLE — STATE / ACCOUNT ASSOCIATION
    // ==========================================================

    predicate ExecutionContextUsesAccountAuthorizationStateExec(
        context: ExecutionContext,
        account: Account
    )
    {
        ExecutionContextAuthorizationState(context)
        ==
        AccountAuthorizationState(account)
    }


    lemma ExecutableMatchesGhostForExecutionContextStateAssociation(
        context: ExecutionContext,
        account: Account
    )
        ensures
            ExecutionContextUsesAccountAuthorizationStateExec(context, account)
            <==>
            ExecutionContextUsesAccountAuthorizationState(context, account)
    {
    }


    // ==========================================================
    // STRUCTURAL VALIDITY WRAPPER
    // ==========================================================

    function StructurallyValidExecutionContextExec(
        context: ExecutionContext
    ): bool
    {
        StructurallyValidExecutionContext(context)
    }


    // ==========================================================
    // FULL CONTEXT VALIDITY — EXECUTABLE
    // ==========================================================

    method ValidExecutionContextForAccountFull(
        context: ExecutionContext,
        account: Account,
        identities: set<Identity>,
        proofVerified: bool
    ) returns (valid: bool)
    {
        // 1. Structural validity of the context value
        if !StructurallyValidExecutionContext(context) {
            valid := false;
            return;
        }

        // 2. State / Account association
        if !ExecutionContextUsesAccountAuthorizationStateExec(context, account) {
            valid := false;
            return;
        }

        // 3. Account validity
        if !ValidAccount(account) {
            valid := false;
            return;
        }

        // 4. Identity context validity
        if !AuthorizationIdentityContextIsValidExecutable(identities) {
            valid := false;
            return;
        }

        // 5. Full authorization acceptance (internal witness construction).
        //
        // AuthorizationCanBeAcceptedFull is a *method*, not a function.
        // Dafny does not permit method calls inside expressions, so we
        // bind its output to a local and branch on that local.
        var accepted := AuthorizationCanBeAcceptedFull(
            ExecutionContextAuthorization(context),
            account,
            identities,
            ExecutionContextEvaluationTime(context),
            proofVerified
        );

        if !accepted {
            valid := false;
            return;
        }

        // 6. The context's EffectiveAuthority must equal the canonical
        //    derivation. This preserves the ghost predicate's
        //    requirement that the supplied authority be the valid one.
        var derivedEA, _, _, _ := ComputeEffectiveAuthorityWitness(
            account,
            identities,
            ExecutionContextEvaluationTime(context)
        );

        valid := ExecutionContextEffectiveAuthority(context) == derivedEA;
    }
}

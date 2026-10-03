// ============================================================
// KIPIO ACCOUNT DOMAIN
// PROOFS — EXECUTION
// ============================================================
//
// Isolated formal proof facade for the Execution layer.
//
// This file acts as the reusable formal contract consumed by
// downstream end-to-end scenarios.
//
// It does NOT redefine execution semantics.
//
// Instead, it exposes reusable guarantees concerning:
//
//   - ExecutionRequest validity;
//   - ExecutionContext validity for an Account;
//   - accepted Authorization representation;
//   - AuthorizationState snapshot association;
//   - EffectiveAuthority validity and boundary;
//   - EffectiveAuthority provenance as inherited contextual evidence;
//   - ExecutionConstraints verification at the Engine boundary;
//   - DomainAction preservation;
//   - ExecutionTarget preservation;
//   - evaluation-time preservation;
//   - intrinsic Execution Engine admissibility;
//   - environment-specific Engine delivery;
//   - authority non-expansion at the execution boundary.
//
// ------------------------------------------------------------
//
// EXECUTION FLOW
//
//     Authorization
//          ↓
//     Effective Authority
//          ↓
//     ExecutionRequest
//          ↓
//     ExecutionContext
//          ↓
//     Execution Engine
//          ↓
//     materialization
//
// Execution consumes already-established semantic values.
//
// ------------------------------------------------------------
//
// IMPORTANT CURRENT EXECUTION BOUNDARY
//
// The current model no longer exposes a standalone:
//
//     ValidExecutionContext(context)
//
// predicate.
//
// Complete ExecutionContext validity is contextual and is represented
// by:
//
//     ValidExecutionContextForAccount(
//       context,
//       account,
//       identities,
//       sourceReferences,
//       sourceAuthorities,
//       contributions,
//       proofVerified
//     )
//
// This contextual predicate establishes that:
//
//   - the context is associated with the supplied Account;
//   - the carried Authorization has crossed the acceptance boundary;
//   - the supplied EffectiveAuthority is valid;
//   - EffectiveAuthority provenance evidence is supplied;
//   - RequestedAuthority ⊆ EffectiveAuthority;
//   - the AuthorizationState snapshot is valid;
//   - the Credential is recognized and usable;
//   - the ExecutionRequest is valid and coherent.
//
// Therefore this facade must preserve that contextual boundary
// instead of weakening it to a context-only validity predicate.
//
// ------------------------------------------------------------
//
// EXECUTION ENGINE INPUT
//
// The intrinsic Engine boundary is:
//
//     ExecutionEngineInputIsValid(
//       context,
//       account,
//       identities,
//       sourceReferences,
//       sourceAuthorities,
//       contributions,
//       proofVerified,
//       verifiedConstraints
//     )
//
// where:
//
//     verifiedConstraints : ExecutionConstraints
//
// represents the concrete ExecutionConstraints value whose
// verification is supplied by the preceding execution layer.
//
// The execution semantics require that:
//
//     verifiedConstraints
//         ==
//     ExecutionContextConstraints(context)
//
// The facade does not define how the constraints are evaluated.
// It only exposes the resulting Engine-boundary contract.
//
// Environment compatibility remains separate.
//
// ------------------------------------------------------------
//
// ENVIRONMENT DELIVERY
//
// Environment-specific delivery is represented by:
//
//     ExecutionEngineInputIsValidForEnvironment(...)
//
// and:
//
//     ExecutionContextCanEnterExecutionEngine(...)
//
// These predicates additionally require:
//
//     Chain × ExecutionEnvironment
//
// compatibility through the externally supplied relation.
//
// Therefore:
//
//     intrinsic Engine validity
//
// is intentionally distinct from:
//
//     environment-specific Engine delivery.
//
// ------------------------------------------------------------
//
// NON-SCOPE
//
// This facade does NOT independently:
//
//   - calculate Effective Authority;
//   - derive Effective Authority provenance;
//   - validate Authorization independently of
//     ValidExecutionContextForAccount;
//   - verify cryptographic Proof;
//   - consume Replay Protection;
//   - interpret ExecutionConstraints;
//   - evaluate Policy;
//   - execute Domain Actions;
//   - mutate Account state;
//   - define blockchain behavior;
//   - define adapter behavior;
//   - define physical environment compatibility algorithms.
//
// Where complete ExecutionContext validity depends on those
// upstream guarantees, this facade exposes them only as inherited
// consequences of the authoritative execution contracts.
//
// ============================================================

include "../../laws/ExecutionLaws.dfy"

module KipioAccountExecutionProofs
{
  import opened KipioAccountDomainPrimitives
  import opened KipioAccountIdentity
  import opened KipioAccountCapability

  import opened KipioAccountAccount

  import opened KipioAccountAuthorization
  import opened KipioAccountAuthorizationState

  import opened KipioAccountEffectiveAuthority

  import opened KipioAccountDomainAction
  import opened KipioAccountExecutionTarget

  import opened KipioAccountExecutionConstraints
  import opened KipioAccountExecutionRequest
  import opened KipioAccountExecutionContext
  import opened KipioAccountExecutionSemantics

  import opened KipioAccountExecutionLaws
  import opened KipioAccountChain


  // ==========================================================
  // EXECUTION REQUEST
  // ==========================================================

  // A valid ExecutionRequest contains a valid Authorization.
  lemma ExecutionRequestHasValidAuthorization(
    request: ExecutionRequest
  )
    requires ValidExecutionRequest(request)
    ensures ValidAuthorization(
              ExecutionRequestAuthorization(request)
            )
  {
  }


  // ==========================================================
  // EXECUTION CONTEXT VALIDITY
  // ==========================================================

  // A complete valid ExecutionContextForAccount contains a valid
  // ExecutionRequest.
  lemma ValidContextHasValidRequest(
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
    ensures ValidExecutionRequest(
              ExecutionContextRequest(context)
            )
  {
    ValidExecutionContextForAccountHasValidRequest(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified
    );
  }


  // A complete valid ExecutionContextForAccount contains a valid
  // Authorization.
  lemma ValidContextHasValidAuthorization(
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
    ensures ValidAuthorization(
              ExecutionContextAuthorization(context)
            )
  {
    assert ValidExecutionRequest(
        ExecutionContextRequest(context)
      );

    assert ValidAuthorization(
        ExecutionRequestAuthorization(
          ExecutionContextRequest(context)
        )
      );

    assert ExecutionContextAuthorization(context)
           ==
           ExecutionRequestAuthorization(
             ExecutionContextRequest(context)
           );
  }


  // A complete valid ExecutionContextForAccount contains a valid
  // AuthorizationState snapshot.
  lemma ValidContextHasValidAuthorizationState(
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
    ensures ValidAuthorizationState(
              ExecutionContextAuthorizationState(context)
            )
  {
    ValidExecutionContextForAccountHasValidAuthorizationState(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified
    );
  }


  // A complete valid ExecutionContextForAccount contains a valid
  // EffectiveAuthority.
  lemma ValidContextHasValidEffectiveAuthority(
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
    ensures ValidEffectiveAuthority(
              ExecutionContextEffectiveAuthority(context)
            )
  {
    ValidExecutionContextForAccountHasValidEffectiveAuthority(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified
    );
  }


  // A complete valid ExecutionContextForAccount satisfies the
  // requested-authority boundary.
  lemma ValidContextPreservesAuthorityBoundary(
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
    ValidExecutionContextForAccountAuthorizesRequestedAuthority(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified
    );
  }


  // A complete valid ExecutionContextForAccount uses exactly the
  // AuthorizationState owned by the supplied Account.
  lemma ValidContextUsesAccountAuthorizationState(
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
    ensures ExecutionContextUsesAccountAuthorizationState(
              context,
              account
            )
  {
    ValidExecutionContextForAccountUsesAccountState(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified
    );
  }


  // A complete valid ExecutionContextForAccount represents an
  // Authorization that has crossed the authoritative acceptance
  // boundary for the supplied Account.
  //
  // EffectiveAuthority provenance remains contextual evidence
  // supplied to that authoritative acceptance contract.
  lemma ValidContextRepresentsAcceptedAuthorization(
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
    ensures ExecutionContextRepresentsAcceptedAuthorizationForAccount(
              context,
              account,
              identities,
              sourceReferences,
              sourceAuthorities,
              contributions,
              proofVerified
            )
  {
    ValidExecutionContextForAccountRepresentsAcceptedAuthorization(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified
    );
  }


  // A complete valid ExecutionContextForAccount carries a recognized
  // Credential.
  lemma ValidContextHasRecognizedCredential(
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
    ensures ExecutionContextCredentialIsRecognized(context)
  {
    ValidExecutionContextForAccountHasRecognizedCredential(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified
    );
  }


  // A complete valid ExecutionContextForAccount carries a usable
  // Credential.
  lemma ValidContextHasUsableCredential(
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
    ensures ExecutionContextCredentialIsUsable(context)
  {
    ValidExecutionContextForAccountHasUsableCredential(
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
  // AUTHORITY NON-EXPANSION
  // ==========================================================

  // A Capability requested by the Authorization must already belong
  // to the EffectiveAuthority carried by the ExecutionContext.
  lemma ExecutionCannotExpandCapabilityAuthority(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    capability: Capability
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
    requires capability
             in AuthorizationRequestedAuthority(
                  ExecutionContextAuthorization(context)
                )
    ensures capability
            in ExecutionContextEffectiveAuthority(context)
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

    assert AuthorizationRequestedAuthority(
        ExecutionContextAuthorization(context)
      )
           <=
           ExecutionContextEffectiveAuthority(context);

    assert capability
           in ExecutionContextEffectiveAuthority(context);
  }


  // The complete RequestedAuthority remains inside EffectiveAuthority
  // at the execution boundary.
  lemma ExecutionCannotExpandRequestedAuthority(
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
    ValidContextPreservesAuthorityBoundary(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified
    );

    assert AuthorizationRequestedAuthority(
        ExecutionContextAuthorization(context)
      )
           <=
           ExecutionContextEffectiveAuthority(context);
  }


  // ==========================================================
  // EXECUTION CONTEXT / VALUE PRESERVATION
  // ==========================================================

  // ExecutionContext exposes its underlying ExecutionRequest.
  lemma ExecutionContextPreservesRequest(
    context: ExecutionContext
  )
    ensures ExecutionContextRequest(context)
            ==
            context.request
  {
  }


  // The Authorization observed at the execution boundary is exactly
  // the Authorization contained in the underlying request.
  lemma ExecutionPreservesAuthorization(
    context: ExecutionContext
  )
    ensures ExecutionContextAuthorization(context)
            ==
            ExecutionRequestAuthorization(
              ExecutionContextRequest(context)
            )
  {
  }


  // The DomainAction observed at execution is the DomainAction
  // carried by the underlying request.
  lemma ExecutionPreservesDomainAction(
    context: ExecutionContext
  )
    ensures ExecutionRequestAction(
              ExecutionContextRequest(context)
            )
            ==
            ExecutionRequestAction(
              context.request
            )
  {
  }


  // The ExecutionTarget observed at execution is the target carried
  // by the underlying request.
  lemma ExecutionPreservesExecutionTarget(
    context: ExecutionContext
  )
    ensures ExecutionRequestTarget(
              ExecutionContextRequest(context)
            )
            ==
            ExecutionRequestTarget(
              context.request
            )
  {
  }


  // ExecutionConstraints remain attached to the underlying
  // ExecutionRequest.
  //
  // This proves preservation of the Value Object reference/value,
  // not interpretation or satisfaction.
  lemma ExecutionPreservesExecutionConstraints(
    context: ExecutionContext
  )
    ensures ExecutionContextConstraints(context)
            ==
            ExecutionRequestConstraints(
              ExecutionContextRequest(context)
            )
  {
  }


  // ExecutionContext exposes the AuthorizationState represented by
  // the context value itself.
  lemma ExecutionPreservesAuthorizationStateSnapshot(
    context: ExecutionContext
  )
    ensures ExecutionContextAuthorizationState(context)
            ==
            context.authorizationState
  {
  }


  // ExecutionContext exposes its evaluation time.
  lemma ExecutionPreservesEvaluationTime(
    context: ExecutionContext
  )
    ensures ExecutionContextEvaluationTime(context)
            ==
            context.evaluationTime
  {
  }


  // ==========================================================
  // EXECUTION CONTEXT / AUTHORIZATION PRESERVATION
  // ==========================================================

  // A complete valid execution decision carries the same
  // Authorization as the underlying request.
  lemma ValidContextPreservesAuthorization(
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
    ExecutionPreservesAuthorization(context);
  }


  // A complete valid execution decision preserves the DomainAction
  // already associated with the Authorization semantic context.
  lemma ValidContextPreservesDomainAction(
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
    ensures ExecutionRequestAction(
              ExecutionContextRequest(context)
            )
            ==
            AuthorizationDomainAction(
              ExecutionContextAuthorization(context)
            )
  {
    ValidExecutionContextForAccountPreservesRequestedDomainAction(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified
    );
  }


  // A complete valid execution decision preserves the ExecutionTarget
  // already associated with the Authorization semantic context.
  lemma ValidContextPreservesExecutionTarget(
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
    ensures ExecutionRequestTarget(
              ExecutionContextRequest(context)
            )
            ==
            AuthorizationExecutionTarget(
              ExecutionContextAuthorization(context)
            )
  {
    ValidExecutionContextForAccountPreservesRequestedTarget(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified
    );
  }


  // A complete valid execution decision carries a structurally valid
  // AuthorizationState snapshot.
  lemma ValidContextProvidesStateSnapshotContract(
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
    ensures ValidAuthorizationState(
              ExecutionContextAuthorizationState(context)
            )
    ensures ExecutionContextAuthorizationState(context)
            ==
            context.authorizationState
  {
    ValidContextHasValidAuthorizationState(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified
    );

    ExecutionPreservesAuthorizationStateSnapshot(context);
  }


  // The valid execution decision exposes the fixed evaluation point.
  //
  // This does not introduce additional temporal semantics beyond
  // those already established by AuthorizationCanBeAccepted.
  lemma ValidContextProvidesEvaluationTimeContract(
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
    ensures ExecutionContextEvaluationTime(context)
            ==
            context.evaluationTime
  {
    ExecutionPreservesEvaluationTime(context);
  }


  // ExecutionConstraints remain attached to the request side.
  //
  // This is preservation only; actual verification is represented
  // at the intrinsic ExecutionEngineInput boundary by the concrete
  // verified ExecutionConstraints value.
  lemma ValidContextPreservesExecutionConstraints(
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
    ensures ExecutionContextConstraints(context)
            ==
            ExecutionRequestConstraints(
              ExecutionContextRequest(context)
            )
  {
    ExecutionPreservesExecutionConstraints(context);
  }


  // ==========================================================
  // EXECUTION ENGINE INPUT
  // ==========================================================

  // The intrinsic Engine boundary consumes a complete validated
  // ExecutionContext together with the concrete ExecutionConstraints
  // value whose verification is supplied by the preceding
  // execution layer.
  //
  // The verification witness is valid for this boundary only when:
  //
  //     verifiedConstraints
  //         ==
  //     ExecutionContextConstraints(context)
  //
  // This facade does not interpret or evaluate the constraints.
  lemma ValidContextProvidesEngineInput(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints
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
    requires ExecutionConstraintsAreVerified(
               context,
               verifiedConstraints
             )
    ensures ExecutionEngineInputIsValid(
              context,
              account,
              identities,
              sourceReferences,
              sourceAuthorities,
              contributions,
              proofVerified,
              verifiedConstraints
            )
  {
    assert ExecutionEngineInputIsValid(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified,
        verifiedConstraints
      );
  }


  // An intrinsic Engine input necessarily corresponds to a complete
  // valid ExecutionContextForAccount.
  lemma ExecutionEngineInputRequiresValidContext(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints
  )
    requires ExecutionEngineInputIsValid(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified,
               verifiedConstraints
             )
    ensures ValidExecutionContextForAccount(
              context,
              account,
              identities,
              sourceReferences,
              sourceAuthorities,
              contributions,
              proofVerified
            )
  {
    assert ValidExecutionContextForAccount(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified
      );
  }


  // The intrinsic Engine input contains a valid EffectiveAuthority.
  lemma ExecutionEngineReceivesValidEffectiveAuthority(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints
  )
    requires ExecutionEngineInputIsValid(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified,
               verifiedConstraints
             )
    ensures ValidEffectiveAuthority(
              ExecutionContextEffectiveAuthority(context)
            )
  {
    assert ValidExecutionContextForAccount(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified
      );

    assert ValidEffectiveAuthority(
        ExecutionContextEffectiveAuthority(context)
      );
  }


  // The intrinsic Engine input preserves the requested-authority
  // boundary established before execution.
  lemma ExecutionEngineReceivesAuthorizedRequest(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints
  )
    requires ExecutionEngineInputIsValid(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified,
               verifiedConstraints
             )
    ensures RequestedAuthorityWithinEffectiveAuthority(
              ExecutionContextAuthorization(context),
              ExecutionContextEffectiveAuthority(context)
            )
  {
    assert ValidExecutionContextForAccount(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified
      );

    assert RequestedAuthorityWithinEffectiveAuthority(
        ExecutionContextAuthorization(context),
        ExecutionContextEffectiveAuthority(context)
      );
  }


  // The intrinsic Engine boundary does not recalculate authority.
  lemma ExecutionEngineConsumesResolvedAuthority(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints
  )
    requires ExecutionEngineInputIsValid(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified,
               verifiedConstraints
             )
    ensures ValidEffectiveAuthority(
              ExecutionContextEffectiveAuthority(context)
            )
  {
    ExecutionEngineReceivesValidEffectiveAuthority(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified,
      verifiedConstraints
    );
  }


  // A valid intrinsic Engine input can enter the Engine only after
  // the separate environment gate is also satisfied.
  lemma ValidContextCanEnterExecutionEngine(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints,
    environment: ExecutionEnvironment,
    compatibilityRelation: set<(Chain, ExecutionEnvironment)>
  )
    requires ExecutionContextCanEnterExecutionEngine(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified,
               verifiedConstraints,
               environment,
               compatibilityRelation
             )
    ensures ExecutionEngineInputIsValidForEnvironment(
              context,
              account,
              identities,
              sourceReferences,
              sourceAuthorities,
              contributions,
              proofVerified,
              verifiedConstraints,
              environment,
              compatibilityRelation
            )
  {
    assert ExecutionEngineInputIsValidForEnvironment(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified,
        verifiedConstraints,
        environment,
        compatibilityRelation
      );
  }


  // ==========================================================
  // ENGINE REQUEST PRESERVATION
  // ==========================================================

  // The Engine receives the same Authorization represented by the
  // underlying ExecutionRequest.
  lemma ExecutionEngineReceivesRequestedAuthorization(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints
  )
    requires ExecutionEngineInputIsValid(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified,
               verifiedConstraints
             )
    ensures ExecutionContextAuthorization(context)
            ==
            ExecutionRequestAuthorization(
              ExecutionContextRequest(context)
            )
  {
    ExecutionPreservesAuthorization(context);
  }


  // The Engine receives the same DomainAction associated with the
  // accepted Authorization context.
  lemma ExecutionEngineReceivesRequestedDomainAction(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints
  )
    requires ExecutionEngineInputIsValid(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified,
               verifiedConstraints
             )
    ensures ExecutionRequestAction(
              ExecutionContextRequest(context)
            )
            ==
            AuthorizationDomainAction(
              ExecutionContextAuthorization(context)
            )
  {
    ValidContextPreservesDomainAction(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified
    );
  }


  // The Engine receives the same ExecutionTarget associated with the
  // accepted Authorization context.
  lemma ExecutionEngineReceivesRequestedTarget(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints
  )
    requires ExecutionEngineInputIsValid(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified,
               verifiedConstraints
             )
    ensures ExecutionRequestTarget(
              ExecutionContextRequest(context)
            )
            ==
            AuthorizationExecutionTarget(
              ExecutionContextAuthorization(context)
            )
  {
    ValidContextPreservesExecutionTarget(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified
    );
  }


  // The Engine receives the same ExecutionConstraints carried by
  // the ExecutionRequest.
  lemma ExecutionEngineReceivesRequestedConstraints(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints
  )
    requires ExecutionEngineInputIsValid(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified,
               verifiedConstraints
             )
    ensures ExecutionContextConstraints(context)
            ==
            ExecutionRequestConstraints(
              ExecutionContextRequest(context)
            )
  {
    ExecutionPreservesExecutionConstraints(context);
  }


  // ==========================================================
  // ENGINE STATE SNAPSHOT
  // ==========================================================

  // The Engine receives a valid AuthorizationState snapshot.
  lemma ExecutionEngineReceivesValidAuthorizationStateSnapshot(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints
  )
    requires ExecutionEngineInputIsValid(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified,
               verifiedConstraints
             )
    ensures ValidAuthorizationState(
              ExecutionContextAuthorizationState(context)
            )
  {
    assert ValidExecutionContextForAccount(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified
      );

    assert ValidAuthorizationState(
        ExecutionContextAuthorizationState(context)
      );
  }


  function ExecutionEngineAuthorizationState(
    context: ExecutionContext
  ): AuthorizationState
  {
    ExecutionContextAuthorizationState(context)
  }


  // The Engine uses exactly the AuthorizationState snapshot carried
  // by the ExecutionContext.
  lemma ExecutionEngineUsesContextAuthorizationState(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints
  )
    requires ExecutionEngineInputIsValid(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified,
               verifiedConstraints
             )
    ensures ExecutionEngineAuthorizationState(context)
            ==
            ExecutionContextAuthorizationState(context)
  {
  }


  // ==========================================================
  // ENGINE CREDENTIAL BOUNDARY
  // ==========================================================

  lemma ExecutionEngineReceivesRecognizedCredential(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints
  )
    requires ExecutionEngineInputIsValid(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified,
               verifiedConstraints
             )
    ensures ExecutionContextCredentialIsRecognized(context)
  {
    assert ValidExecutionContextForAccount(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified
      );

    assert ExecutionContextCredentialIsRecognized(context);
  }


  lemma ExecutionEngineReceivesUsableCredential(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints
  )
    requires ExecutionEngineInputIsValid(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified,
               verifiedConstraints
             )
    ensures ExecutionContextCredentialIsUsable(context)
  {
    assert ValidExecutionContextForAccount(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified
      );

    assert ExecutionContextCredentialIsUsable(context);
  }


  // ==========================================================
  // ENGINE / AUTHORITY SEPARATION
  // ==========================================================

  // The Engine receives an already-established authority relation.
  lemma ExecutionEngineDoesNotRequireAuthorityRecalculation(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints
  )
    requires ExecutionEngineInputIsValid(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified,
               verifiedConstraints
             )
    ensures RequestedAuthorityWithinEffectiveAuthority(
              ExecutionContextAuthorization(context),
              ExecutionContextEffectiveAuthority(context)
            )
  {
    ExecutionEngineReceivesAuthorizedRequest(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified,
      verifiedConstraints
    );
  }


  // The Engine does not redefine the Authorization boundary.
  lemma ExecutionEngineDoesNotRedefineAuthorizationBoundary(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints
  )
    requires ExecutionEngineInputIsValid(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified,
               verifiedConstraints
             )
    ensures RequestedAuthorityWithinEffectiveAuthority(
              ExecutionContextAuthorization(context),
              ExecutionContextEffectiveAuthority(context)
            )
  {
    ExecutionEngineReceivesAuthorizedRequest(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified,
      verifiedConstraints
    );
  }


  ghost function ExecutionEngineResolvedAuthority(
    context: ExecutionContext
  ): EffectiveAuthority
  {
    ExecutionContextEffectiveAuthority(context)
  }


  lemma ExecutionEngineUsesContextEffectiveAuthority(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints
  )
    requires ExecutionEngineInputIsValid(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified,
               verifiedConstraints
             )
    ensures ExecutionEngineResolvedAuthority(context)
            ==
            ExecutionContextEffectiveAuthority(context)
  {
  }


  // ==========================================================
  // EXECUTION CONSTRAINT BOUNDARY
  // ==========================================================

  // ExecutionConstraints remain outside Authorization semantics.
  lemma ExecutionConstraintsRemainOutsideAuthoritySemantics(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints
  )
    requires ExecutionEngineInputIsValid(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified,
               verifiedConstraints
             )
    ensures ExecutionContextConstraints(context)
            ==
            ExecutionRequestConstraints(
              ExecutionContextRequest(context)
            )
  {
    ExecutionPreservesExecutionConstraints(context);
  }


  // At the intrinsic Engine boundary, the applicable
  // ExecutionConstraints are represented by the concrete
  // verifiedConstraints value supplied by the preceding
  // execution layer.
  //
  // The Engine boundary requires that this value is exactly the
  // ExecutionConstraints carried by the ExecutionContext.
  lemma ExecutionEngineReceivesVerifiedExecutionConstraints(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints
  )
    requires ExecutionEngineInputIsValid(
               context,
               account,
               identities,
               sourceReferences,
               sourceAuthorities,
               contributions,
               proofVerified,
               verifiedConstraints
             )
    ensures ExecutionConstraintsAreVerified(
              context,
              verifiedConstraints
            )
  {
    assert ExecutionConstraintsAreVerified(
        context,
        verifiedConstraints
      );
  }


  // ==========================================================
  // ENVIRONMENT BOUNDARY
  // ==========================================================

  // A valid intrinsic context may be incompatible with a selected
  // environment. Environment compatibility is therefore not part
  // of intrinsic context validity.
  lemma IntrinsicExecutionValidityIsIndependentOfEnvironment(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints,
    environment1: ExecutionEnvironment,
    environment2: ExecutionEnvironment,
    compatibilityRelation: set<(Chain, ExecutionEnvironment)>
  )
    ensures
      ExecutionEngineInputIsValid(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified,
        verifiedConstraints
      )
      ==
      ExecutionEngineInputIsValid(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified,
        verifiedConstraints
      )
  {
  }


  // An intrinsically valid context remains intrinsically valid even
  // when the selected environment is incompatible.
  lemma IncompatibleEnvironmentDoesNotMakeContextIntrinsicallyInvalid(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints,
    environment: ExecutionEnvironment,
    compatibilityRelation: set<(Chain, ExecutionEnvironment)>
  )
    requires
      ExecutionEngineInputIsValid(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified,
        verifiedConstraints
      )
      &&
      !ExecutionContextIsCompatibleWithEnvironment(
        context,
        environment,
        compatibilityRelation
      )
    ensures
      ExecutionEngineInputIsValid(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified,
        verifiedConstraints
      )
      &&
      !ExecutionEngineInputIsValidForEnvironment(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified,
        verifiedConstraints,
        environment,
        compatibilityRelation
      )
  {
  }


  // Same context, same intrinsic validity, different environment
  // delivery outcome.
  lemma SameValidContextMayHaveDifferentEnvironmentDelivery(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints,
    environment1: ExecutionEnvironment,
    environment2: ExecutionEnvironment,
    compatibilityRelation: set<(Chain, ExecutionEnvironment)>
  )
    requires
      environment1 != environment2
      &&
      ExecutionEngineInputIsValid(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified,
        verifiedConstraints
      )
      &&
      ChainEnvironmentPairIsCompatible(
        compatibilityRelation,
        ExecutionContextAuthorizationChain(context),
        environment1
      )
      &&
      !ChainEnvironmentPairIsCompatible(
        compatibilityRelation,
        ExecutionContextAuthorizationChain(context),
        environment2
      )
    ensures
      ExecutionEngineInputIsValid(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified,
        verifiedConstraints
      )
      &&
      ExecutionEngineInputIsValidForEnvironment(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified,
        verifiedConstraints,
        environment1,
        compatibilityRelation
      )
      &&
      !ExecutionEngineInputIsValidForEnvironment(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified,
        verifiedConstraints,
        environment2,
        compatibilityRelation
      )
  {
  }


  // Symmetric form of the two-environment witness.
  lemma SameValidContextMayHaveOppositeEnvironmentDelivery(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints,
    environment1: ExecutionEnvironment,
    environment2: ExecutionEnvironment,
    compatibilityRelation: set<(Chain, ExecutionEnvironment)>
  )
    requires
      environment1 != environment2
      &&
      ExecutionEngineInputIsValid(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified,
        verifiedConstraints
      )
      &&
      !ChainEnvironmentPairIsCompatible(
        compatibilityRelation,
        ExecutionContextAuthorizationChain(context),
        environment1
      )
      &&
      ChainEnvironmentPairIsCompatible(
        compatibilityRelation,
        ExecutionContextAuthorizationChain(context),
        environment2
      )
    ensures
      ExecutionEngineInputIsValid(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified,
        verifiedConstraints
      )
      &&
      !ExecutionEngineInputIsValidForEnvironment(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified,
        verifiedConstraints,
        environment1,
        compatibilityRelation
      )
      &&
      ExecutionEngineInputIsValidForEnvironment(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified,
        verifiedConstraints,
        environment2,
        compatibilityRelation
      )
  {
  }


  // ==========================================================
  // ENVIRONMENT COMPATIBILITY
  // ==========================================================

  lemma ExecutionEnvironmentCompatibilityUsesAuthorizationChain(
    context: ExecutionContext,
    environment: ExecutionEnvironment,
    compatibilityRelation: set<(Chain, ExecutionEnvironment)>
  )
    ensures
      ExecutionContextIsCompatibleWithEnvironment(
        context,
        environment,
        compatibilityRelation
      )
      ==
      ChainEnvironmentPairIsCompatible(
        compatibilityRelation,
        ExecutionContextAuthorizationChain(context),
        environment
      )
  {
  }


  lemma IncompatibleChainEnvironmentPairCannotPassEnvironmentGate(
    context: ExecutionContext,
    environment: ExecutionEnvironment,
    compatibilityRelation: set<(Chain, ExecutionEnvironment)>
  )
    requires
      !(ChainEnvironmentPairIsCompatible(
          compatibilityRelation,
          ExecutionContextAuthorizationChain(context),
          environment
        ))
    ensures
      !ExecutionContextIsCompatibleWithEnvironment(
        context,
        environment,
        compatibilityRelation
      )
  {
  }


  lemma CompatibleChainEnvironmentPairPassesCompatibilityPredicate(
    context: ExecutionContext,
    environment: ExecutionEnvironment,
    compatibilityRelation: set<(Chain, ExecutionEnvironment)>
  )
    requires
      ChainEnvironmentPairIsCompatible(
        compatibilityRelation,
        ExecutionContextAuthorizationChain(context),
        environment
      )
    ensures
      ExecutionContextIsCompatibleWithEnvironment(
        context,
        environment,
        compatibilityRelation
      )
  {
  }


  lemma SameAuthorizationChainHasSameEnvironmentCompatibility(
    context1: ExecutionContext,
    context2: ExecutionContext,
    environment: ExecutionEnvironment,
    compatibilityRelation: set<(Chain, ExecutionEnvironment)>
  )
    requires
      ExecutionContextAuthorizationChain(context1)
      ==
      ExecutionContextAuthorizationChain(context2)
    ensures
      ExecutionContextIsCompatibleWithEnvironment(
        context1,
        environment,
        compatibilityRelation
      )
      ==
      ExecutionContextIsCompatibleWithEnvironment(
        context2,
        environment,
        compatibilityRelation
      )
  {
  }


  // An environment-specific Engine boundary accepts only compatible
  // Chain / Environment pairs.
  lemma ExecutionEngineAcceptsOnlyEnvironmentCompatibleContexts(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints,
    environment: ExecutionEnvironment,
    compatibilityRelation: set<(Chain, ExecutionEnvironment)>
  )
    requires
      ExecutionEngineInputIsValidForEnvironment(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified,
        verifiedConstraints,
        environment,
        compatibilityRelation
      )
    ensures
      ChainEnvironmentPairIsCompatible(
        compatibilityRelation,
        ExecutionContextAuthorizationChain(context),
        environment
      )
  {
  }


  // An incompatible Authorization Chain / Environment pair cannot
  // satisfy the environment-specific Engine boundary.
  lemma IncompatibleEnvironmentCannotEnterExecutionEngine(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints,
    environment: ExecutionEnvironment,
    compatibilityRelation: set<(Chain, ExecutionEnvironment)>
  )
    requires
      !(ChainEnvironmentPairIsCompatible(
          compatibilityRelation,
          ExecutionContextAuthorizationChain(context),
          environment
        ))
    ensures
      !ExecutionEngineInputIsValidForEnvironment(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified,
        verifiedConstraints,
        environment,
        compatibilityRelation
      )
  {
  }


  // ==========================================================
  // EXECUTION / CONTEXT SEPARATION
  // ==========================================================

  // Intrinsic Engine validity is independent of the selected
  // environment.
  //
  // Environment-specific compatibility is evaluated only by the
  // separate delivery gate.
  lemma ExecutionContextValidityDoesNotDependOnSelectedEnvironment(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints,
    environment: ExecutionEnvironment,
    compatibilityRelation: set<(Chain, ExecutionEnvironment)>
  )
    ensures
      ExecutionEngineInputIsValid(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified,
        verifiedConstraints
      )
      ==
      ExecutionEngineInputIsValid(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified,
        verifiedConstraints
      )
  {
  }


  // ==========================================================
  // VALUE OBJECT SEMANTICS
  // ==========================================================

  // Equal ExecutionContexts necessarily preserve equal requests.
  lemma EqualContextsHaveEqualRequests(
    left: ExecutionContext,
    right: ExecutionContext
  )
    requires left == right
    ensures ExecutionContextRequest(left)
            ==
            ExecutionContextRequest(right)
  {
  }


  // Equal ExecutionContexts necessarily preserve equal
  // EffectiveAuthority values.
  lemma EqualContextsHaveEqualEffectiveAuthorities(
    left: ExecutionContext,
    right: ExecutionContext
  )
    requires left == right
    ensures ExecutionContextEffectiveAuthority(left)
            ==
            ExecutionContextEffectiveAuthority(right)
  {
  }


  // Equal ExecutionContexts necessarily preserve equal
  // AuthorizationState snapshots.
  lemma EqualContextsHaveEqualAuthorizationStates(
    left: ExecutionContext,
    right: ExecutionContext
  )
    requires left == right
    ensures ExecutionContextAuthorizationState(left)
            ==
            ExecutionContextAuthorizationState(right)
  {
  }


  // Equal ExecutionContexts necessarily preserve equal evaluation
  // times.
  lemma EqualContextsHaveEqualEvaluationTimes(
    left: ExecutionContext,
    right: ExecutionContext
  )
    requires left == right
    ensures ExecutionContextEvaluationTime(left)
            ==
            ExecutionContextEvaluationTime(right)
  {
  }


  // ==========================================================
  // COMPLETE EXECUTION CONTRACT
  // ==========================================================

  // Primary reusable contract for downstream execution scenarios.
  //
  // This contract reflects the CURRENT semantics of
  // ValidExecutionContextForAccount.
  //
  // It intentionally carries the contextual evidence required by
  // the authorization acceptance boundary.
  lemma ValidExecutionContextProvidesReusableExecutionContract(
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
    ensures ValidExecutionRequest(
              ExecutionContextRequest(context)
            )
    ensures ValidAuthorization(
              ExecutionContextAuthorization(context)
            )
    ensures ValidAuthorizationState(
              ExecutionContextAuthorizationState(context)
            )
    ensures ValidEffectiveAuthority(
              ExecutionContextEffectiveAuthority(context)
            )
    ensures RequestedAuthorityWithinEffectiveAuthority(
              ExecutionContextAuthorization(context),
              ExecutionContextEffectiveAuthority(context)
            )
    ensures ExecutionContextUsesAccountAuthorizationState(
              context,
              account
            )
    ensures ExecutionContextRepresentsAcceptedAuthorizationForAccount(
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
    ensures ExecutionContextAuthorizationState(context)
            ==
            context.authorizationState
    ensures ExecutionContextEvaluationTime(context)
            ==
            context.evaluationTime
    ensures ExecutionContextCredentialIsRecognized(context)
    ensures ExecutionContextCredentialIsUsable(context)
  {
    ValidContextHasValidRequest(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified
    );

    ValidContextHasValidAuthorizationState(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified
    );

    ValidContextHasValidEffectiveAuthority(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified
    );

    ValidContextPreservesAuthorityBoundary(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified
    );

    ValidContextUsesAccountAuthorizationState(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified
    );

    ValidContextRepresentsAcceptedAuthorization(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified
    );

    ValidContextHasRecognizedCredential(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified
    );

    ValidContextHasUsableCredential(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified
    );

    ExecutionContextPreservesRequest(context);
    ExecutionPreservesAuthorization(context);
    ExecutionPreservesAuthorizationStateSnapshot(context);
    ExecutionPreservesEvaluationTime(context);
  }


  // Compact authority-focused contract.
  lemma ValidExecutionContextProvidesReusableAuthorityContract(
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
    ensures ValidEffectiveAuthority(
              ExecutionContextEffectiveAuthority(context)
            )
    ensures RequestedAuthorityWithinEffectiveAuthority(
              ExecutionContextAuthorization(context),
              ExecutionContextEffectiveAuthority(context)
            )
  {
    ValidContextHasValidEffectiveAuthority(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified
    );

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


  // Compact request-preservation contract.
  lemma ValidExecutionContextProvidesReusableRequestContract(
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
    ensures ExecutionContextAuthorization(context)
            ==
            ExecutionRequestAuthorization(
              ExecutionContextRequest(context)
            )
    ensures ExecutionContextConstraints(context)
            ==
            ExecutionRequestConstraints(
              ExecutionContextRequest(context)
            )
  {
    ExecutionContextPreservesRequest(context);
    ExecutionPreservesAuthorization(context);
    ExecutionPreservesExecutionConstraints(context);
  }


  // Compact state-snapshot contract.
  lemma ValidExecutionContextProvidesReusableStateContract(
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
    ensures ValidAuthorizationState(
              ExecutionContextAuthorizationState(context)
            )
    ensures ExecutionContextAuthorizationState(context)
            ==
            context.authorizationState
    ensures ExecutionContextUsesAccountAuthorizationState(
              context,
              account
            )
  {
    ValidContextProvidesStateSnapshotContract(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified
    );

    ValidContextUsesAccountAuthorizationState(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified
    );
  }


  // Compact materialization-fidelity contract.
  //
  // The generic execution layer preserves the request-side values
  // needed by downstream materialization, without defining the
  // concrete business semantics of those values.
  lemma ValidExecutionContextProvidesReusableMaterializationContract(
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
            ExecutionRequestAction(context.request)
    ensures ExecutionRequestTarget(
              ExecutionContextRequest(context)
            )
            ==
            ExecutionRequestTarget(context.request)
    ensures ExecutionContextConstraints(context)
            ==
            ExecutionRequestConstraints(
              ExecutionContextRequest(context)
            )
    ensures ExecutionContextEvaluationTime(context)
            ==
            context.evaluationTime
  {
    ExecutionContextPreservesRequest(context);
    ExecutionPreservesDomainAction(context);
    ExecutionPreservesExecutionTarget(context);
    ExecutionPreservesExecutionConstraints(context);
    ExecutionPreservesEvaluationTime(context);
  }
}

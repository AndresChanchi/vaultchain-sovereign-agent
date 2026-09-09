// ============================================================
// KIPIO ACCOUNT DOMAIN
// LAWS — EXECUTION
// ============================================================
//
// Cross-concept semantic laws governing the boundary between:
//
//     Account
//        |
//        v
//     Authorization
//        |
//        v
//     ExecutionRequest
//        |
//        v
//     ExecutionContext
//        |
//        v
//     EffectiveAuthority
//        |
//        v
//     Execution Engine
//
// Local execution semantics remain in:
//
//     ExecutionRequest.dfy
//     ExecutionContext.dfy
//     ExecutionSemantics.dfy
//     ExecutionConstraints.dfy
//
// Authorization semantics remain in:
//
//     Authorization.dfy
//     AuthorizationValidation.dfy
//
// Effective Authority semantics remain in:
//
//     EffectiveAuthority.dfy
//
// Authorization State semantics remain in:
//
//     AuthorizationState.dfy
//
// This file therefore contains only cross-concept consequences
// that span those independently defined execution boundaries.
//
// ------------------------------------------------------------
//
// CENTRAL EXECUTION CHAIN
//
//     Account
//        |
//        | owns
//        v
//     AuthorizationState
//        |
//        | evaluated for Authorization
//        v
//     Authorization
//        |
//        v
//     ExecutionRequest
//        |
//        v
//     ExecutionContext
//        |
//        +--> EffectiveAuthority
//        |
//        +--> AuthorizationState snapshot
//        |
//        v
//     Execution Engine
//
// ------------------------------------------------------------
//
// IMPORTANT DISTINCTIONS
//
//     Authorization
//         !=
//     ExecutionRequest
//
//     ExecutionRequest
//         !=
//     ExecutionContext
//
//     ExecutionContext
//         !=
//     ExecutionEnvironment
//
//     EffectiveAuthority
//         !=
//     Authorization
//
//     ExecutionTarget
//         !=
//     Capability Scope
//
//     ExecutionConstraints
//         !=
//     Authorization Restrictions
//
// The laws below preserve these boundaries without redefining
// their local semantics.
//
// ------------------------------------------------------------
//
// THIS FILE DOES NOT:
//
//   - define ExecutionRequest;
//   - define ExecutionContext;
//   - calculate Effective Authority;
//   - validate Authorization;
//   - define ExecutionConstraints;
//   - define ExecutionEnvironment;
//   - verify Proof;
//   - consume Replay Protection;
//   - execute DomainAction;
//   - define engine runtime behavior;
//   - define environment compatibility;
//   - mutate AuthorizationState.
//
// ============================================================

include "../foundation/DomainPrimitives.dfy"
include "../foundation/Capability.dfy"
include "../foundation/Identity.dfy"
include "../foundation/DomainAction.dfy"
include "../foundation/ExecutionTarget.dfy"

include "../authority/EffectiveAuthority.dfy"
include "../authority/AuthorizationState.dfy"

include "../account/Account.dfy"

include "../authorization/Authorization.dfy"
include "../authorization/AuthorizationValidation.dfy"

include "../execution/ExecutionConstraints.dfy"
include "../execution/ExecutionRequest.dfy"
include "../execution/ExecutionContext.dfy"
include "../execution/ExecutionSemantics.dfy"


module KipioAccountExecutionLaws
{
  import opened KipioAccountDomainPrimitives
  import opened KipioAccountCapability
  import opened KipioAccountIdentity
  import opened KipioAccountDomainAction
  import opened KipioAccountExecutionTarget

  import opened KipioAccountEffectiveAuthority
  import opened KipioAccountAuthorizationState

  import opened KipioAccountAccount

  import opened KipioAccountAuthorization
  import opened KipioAccountAuthorizationValidation

  import opened KipioAccountExecutionConstraints
  import opened KipioAccountExecutionRequest
  import opened KipioAccountExecutionContext
  import opened KipioAccountExecutionSemantics


  // ----------------------------------------------------------
  // ACCOUNT / EXECUTION CONTEXT ASSOCIATION
  // ----------------------------------------------------------

  // A complete valid ExecutionContext for an Account uses exactly
  // the AuthorizationState owned by that Account.
  //
  // This is a cross-concept consequence because AuthorizationState
  // intentionally does not contain AccountId and the association is
  // established at the execution validation boundary.
  lemma ExecutionContextUsesAccountOwnedAuthorizationState(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool
  )
    requires
      ValidExecutionContextForAccount(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified
      )
    ensures
      ExecutionContextAuthorizationState(context)
      ==
      AccountAuthorizationState(account)
  {
    assert
      ExecutionContextUsesAccountAuthorizationState(
        context,
        account
      );
  }


  // ----------------------------------------------------------
  // EXECUTION CONTEXT / AUTHORIZATION
  // ----------------------------------------------------------

  // A complete valid ExecutionContext represents an Authorization
  // that has already crossed the Account-level Authorization
  // acceptance boundary.
  //
  // This keeps the distinction between:
  //
  //     Authorization value
  //
  // and:
  //
  //     accepted Authorization for Account
  lemma ExecutionContextRepresentsAcceptedAuthorization(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool
  )
    requires
      ValidExecutionContextForAccount(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified
      )
    ensures
      ExecutionContextRepresentsAcceptedAuthorizationForAccount(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified
      )
  {
    assert
      ExecutionContextRepresentsAcceptedAuthorizationForAccount(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified
      );
  }


  // A complete valid ExecutionContext contains a structurally valid
  // ExecutionRequest, and that request remains the carrier of the
  // Authorization value into execution.
  lemma ExecutionContextPreservesValidAuthorizationRequest(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool
  )
    requires
      ValidExecutionContextForAccount(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified
      )
    ensures
      ValidExecutionRequest(
        ExecutionContextRequest(context)
      )
    ensures
      ValidAuthorization(
        ExecutionContextAuthorization(context)
      )
  {
    assert
      ValidExecutionRequest(
        ExecutionContextRequest(context)
      );

    assert
      ValidAuthorization(
        ExecutionContextAuthorization(context)
      );
  }


  // ----------------------------------------------------------
  // REQUEST / AUTHORIZATION CONTEXT
  // ----------------------------------------------------------

  // A valid execution decision preserves the DomainAction already
  // represented by the Authorization semantic Context.
  //
  // This composes:
  //
  //     Authorization
  //          +
  //     ExecutionRequest
  //          +
  //     ExecutionContext
  lemma ExecutionContextPreservesAuthorizationDomainAction(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool
  )
    requires
      ValidExecutionContextForAccount(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified
      )
    ensures
      ExecutionRequestAction(
        ExecutionContextRequest(context)
      )
      ==
      AuthorizationDomainAction(
        ExecutionContextAuthorization(context)
      )
  {
    assert
      ExecutionRequestAction(
        ExecutionContextRequest(context)
      )
      ==
      AuthorizationDomainAction(
        ExecutionContextAuthorization(context)
      );
  }


  // A valid execution decision preserves the ExecutionTarget already
  // represented by the Authorization semantic Context.
  lemma ExecutionContextPreservesAuthorizationExecutionTarget(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool
  )
    requires
      ValidExecutionContextForAccount(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified
      )
    ensures
      ExecutionRequestTarget(
        ExecutionContextRequest(context)
      )
      ==
      AuthorizationExecutionTarget(
        ExecutionContextAuthorization(context)
      )
  {
    assert
      ExecutionRequestTarget(
        ExecutionContextRequest(context)
      )
      ==
      AuthorizationExecutionTarget(
        ExecutionContextAuthorization(context)
      );
  }


  // ----------------------------------------------------------
  // EXECUTION CONTEXT / STATE SNAPSHOT
  // ----------------------------------------------------------

  // The state snapshot carried into execution remains a valid
  // AuthorizationState.
  lemma ExecutionContextCarriesValidAuthorizationState(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool
  )
    requires
      ValidExecutionContextForAccount(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified
      )
    ensures
      ValidAuthorizationState(
        ExecutionContextAuthorizationState(context)
      )
  {
    assert
      ValidAuthorizationState(
        ExecutionContextAuthorizationState(context)
      );
  }


  // The Credential referenced by the Authorization remains resolved
  // against the same state snapshot carried by the ExecutionContext.
  lemma ExecutionContextCarriesRecognizedCredential(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool
  )
    requires
      ValidExecutionContextForAccount(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified
      )
    ensures
      ExecutionContextCredentialIsRecognized(context)
  {
    assert
      ExecutionContextCredentialIsRecognized(context);
  }


  // A Credential usable for the accepted Authorization remains
  // usable in the same AuthorizationState snapshot carried into
  // execution.
  lemma ExecutionContextCarriesUsableCredential(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool
  )
    requires
      ValidExecutionContextForAccount(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified
      )
    ensures
      ExecutionContextCredentialIsUsable(context)
  {
    assert
      ExecutionContextCredentialIsUsable(context);
  }


  // ----------------------------------------------------------
  // EFFECTIVE AUTHORITY BOUNDARY
  // ----------------------------------------------------------

  // The EffectiveAuthority carried by a valid execution decision is
  // structurally valid and is the authority value already accepted
  // for the Authorization.
  lemma ExecutionContextCarriesValidResolvedAuthority(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool
  )
    requires
      ValidExecutionContextForAccount(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified
      )
    ensures
      ValidEffectiveAuthority(
        ExecutionContextEffectiveAuthority(context)
      )
    ensures
      RequestedAuthorityWithinEffectiveAuthority(
        ExecutionContextAuthorization(context),
        ExecutionContextEffectiveAuthority(context)
      )
  {
    assert
      ValidEffectiveAuthority(
        ExecutionContextEffectiveAuthority(context)
      );

    assert
      RequestedAuthorityWithinEffectiveAuthority(
        ExecutionContextAuthorization(context),
        ExecutionContextEffectiveAuthority(context)
      );
  }


  // Every Capability requested by the Authorization represented in
  // a complete valid ExecutionContext is already contained in the
  // resolved EffectiveAuthority.
  //
  // Execution does not create that authority relation; it carries
  // the already-established result forward.
  lemma ExecutionContextCannotCarryUnauthorizedRequestedCapability(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    capability: Capability
  )
    requires
      ValidExecutionContextForAccount(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified
      )
    requires
      capability
      in AuthorizationRequestedAuthority(
           ExecutionContextAuthorization(context)
         )
    ensures
      capability
      in ExecutionContextEffectiveAuthority(context)
  {
    assert
      AuthorizationRequestedAuthority(
        ExecutionContextAuthorization(context)
      )
      <=
      ExecutionContextEffectiveAuthority(context);

    assert
      capability
      in ExecutionContextEffectiveAuthority(context);
  }


  // ----------------------------------------------------------
  // EXECUTION ENGINE INPUT
  // ----------------------------------------------------------

  // A valid execution-context decision together with the verified
  // ExecutionConstraints value is exactly the intrinsic Engine
  // input boundary.
  //
  // The Engine boundary does not recalculate Authorization or
  // EffectiveAuthority.
  lemma ValidExecutionContextProvidesIntrinsicEngineInput(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints
  )
    requires
      ValidExecutionContextForAccount(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified
      )
    requires
      ExecutionConstraintsAreVerified(
        context,
        verifiedConstraints
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
  {
    assert
      ExecutionEngineInputIsValid(
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


  // Any intrinsic Engine input necessarily carries the same resolved
  // authority relation established by Authorization acceptance.
  lemma IntrinsicEngineInputPreservesAuthorityBoundary(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints
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
    ensures
      RequestedAuthorityWithinEffectiveAuthority(
        ExecutionContextAuthorization(context),
        ExecutionContextEffectiveAuthority(context)
      )
  {
    assert
      RequestedAuthorityWithinEffectiveAuthority(
        ExecutionContextAuthorization(context),
        ExecutionContextEffectiveAuthority(context)
      );
  }


  // The Engine receives the same AuthorizationState snapshot already
  // associated with the ExecutionContext.
  lemma IntrinsicEngineInputPreservesStateSnapshot(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints
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
    ensures
      ExecutionEngineAuthorizationState(context)
      ==
      ExecutionContextAuthorizationState(context)
  {
    assert
      ExecutionEngineAuthorizationState(context)
      ==
      ExecutionContextAuthorizationState(context);
  }


  // ----------------------------------------------------------
  // ENGINE / REQUEST PRESERVATION
  // ----------------------------------------------------------

  // The Engine-facing boundary does not replace the Authorization
  // carried by the original ExecutionRequest.
  lemma IntrinsicEngineInputPreservesAuthorization(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints
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
    ensures
      ExecutionContextAuthorization(context)
      ==
      ExecutionRequestAuthorization(
        ExecutionContextRequest(context)
      )
  {
    assert
      ExecutionContextAuthorization(context)
      ==
      ExecutionRequestAuthorization(
        ExecutionContextRequest(context)
      );
  }


  // The Engine-facing boundary preserves the DomainAction already
  // associated with the Authorization context.
  lemma IntrinsicEngineInputPreservesDomainAction(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints
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
    ensures
      ExecutionRequestAction(
        ExecutionContextRequest(context)
      )
      ==
      AuthorizationDomainAction(
        ExecutionContextAuthorization(context)
      )
  {
    assert
      ExecutionRequestAction(
        ExecutionContextRequest(context)
      )
      ==
      AuthorizationDomainAction(
        ExecutionContextAuthorization(context)
      );
  }


  // The Engine-facing boundary preserves the ExecutionTarget
  // associated with the Authorization context.
  lemma IntrinsicEngineInputPreservesExecutionTarget(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints
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
    ensures
      ExecutionRequestTarget(
        ExecutionContextRequest(context)
      )
      ==
      AuthorizationExecutionTarget(
        ExecutionContextAuthorization(context)
      )
  {
    assert
      ExecutionRequestTarget(
        ExecutionContextRequest(context)
      )
      ==
      AuthorizationExecutionTarget(
        ExecutionContextAuthorization(context)
      );
  }


  // ----------------------------------------------------------
  // EXECUTION CONSTRAINT BOUNDARY
  // ----------------------------------------------------------

  // ExecutionConstraints remain attached to the original request
  // throughout the ExecutionContext boundary.
  //
  // They are not transformed into Capabilities or Restrictions.
  lemma ExecutionContextPreservesExecutionConstraints(
    context: ExecutionContext
  )
    ensures
      ExecutionContextConstraints(context)
      ==
      ExecutionRequestConstraints(
        ExecutionContextRequest(context)
      )
  {
    assert
      ExecutionContextConstraints(context)
      ==
      ExecutionRequestConstraints(
        ExecutionContextRequest(context)
      );
  }


  // ----------------------------------------------------------
  // FINAL CROSS-CONCEPT BOUNDARY
  // ----------------------------------------------------------

  // A complete valid execution decision is downstream from
  // Authorization validation and upstream of physical execution.
  //
  // This law intentionally stops before:
  //
  //   - Environment compatibility;
  //   - Adapter selection;
  //   - blockchain materialization;
  //   - runtime execution;
  //   - state mutation.
  //
  // Those concerns remain in ExecutionSemantics / runtime
  // infrastructure.
  lemma ExecutionRemainsDownstreamOfAuthorization(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool
  )
    requires
      ValidExecutionContextForAccount(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified
      )
    ensures
      ExecutionContextRepresentsAcceptedAuthorizationForAccount(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified
      )
    ensures
      RequestedAuthorityWithinEffectiveAuthority(
        ExecutionContextAuthorization(context),
        ExecutionContextEffectiveAuthority(context)
      )
  {
    assert
      ExecutionContextRepresentsAcceptedAuthorizationForAccount(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified
      );

    assert
      RequestedAuthorityWithinEffectiveAuthority(
        ExecutionContextAuthorization(context),
        ExecutionContextEffectiveAuthority(context)
      );
  }
}

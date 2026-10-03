// ============================================================
// KIPIO ACCOUNT DOMAIN
// EXECUTION — EXECUTION SEMANTICS
// ============================================================
//
// ExecutionSemantics defines the semantic boundary between a
// validated ExecutionContext and the Execution Engine.
//
// The Execution Engine receives an already-resolved execution
// decision. It does not:
//
//   - recalculate Effective Authority;
//   - reinterpret Authorization;
//   - reinterpret AuthorizationState;
//   - reinterpret DomainAction business semantics;
//   - resolve ExecutionTarget semantics;
//   - redefine ExecutionConstraints;
//   - verify Proof;
//   - consume Replay Protection;
//   - evaluate Policy.
//
// ------------------------------------------------------------
//
// D1 — AUTHORITY BOUNDARY
//
// The Execution Engine receives an EffectiveAuthority that has
// already been resolved by the authorization layer.
//
// Therefore:
//
//     RequestedAuthority
//         ⊆
//     EffectiveAuthority
//
// is already established before the execution boundary.
//
// This module preserves that relation and does not derive
// EffectiveAuthority.
//
// The execution boundary also does not establish the provenance
// mechanism by which EffectiveAuthority was derived. That guarantee
// belongs to the preceding authority / authorization evaluation
// boundary.
//
// ------------------------------------------------------------
//
// D3 — STATE SNAPSHOT
//
// ExecutionContext carries the AuthorizationState snapshot used
// for the execution decision.
//
// ExecutionSemantics consumes that snapshot as part of the
// validated execution decision.
//
// It does not mutate, replace, or recompute AuthorizationState.
//
// State mutation remains the responsibility of AccountTransitions,
// PolicyConsumption and the corresponding runtime boundaries.
//
// ------------------------------------------------------------
//
// D4 — AUTHORIZATION / PROOF BOUNDARY
//
// Authorization remains a semantic Value Object.
//
// Proof is infrastructure and is not stored in Authorization.
//
// ExecutionSemantics therefore does not define, compare or verify
// Proof.
//
// Proof verification must already have been resolved before a
// complete ExecutionContext is accepted by the execution boundary.
//
// Replay Protection is likewise not consumed here.
//
// ------------------------------------------------------------
//
// D6 — EXECUTION ENVIRONMENT COMPATIBILITY
//
// Chain is part of the semantic Authorization Context.
//
// ExecutionEnvironment is an infrastructure concept and is NOT
// part of ExecutionContext.
//
// Therefore this module does not redefine ExecutionContext
// validity in terms of a physical environment.
//
// Environment compatibility is modeled as an external relation:
//
//     CompatibleChainEnvironment ⊆
//         Chain × ExecutionEnvironment
//
// A selected environment is compatible with an Authorization Chain
// exactly when the corresponding pair belongs to that relation.
//
// The relation is supplied by the execution infrastructure.
//
// This module intentionally does NOT define the concrete physical
// rules that determine compatibility.
//
// Therefore:
//
//     ValidExecutionContextForAccount(...)
//
// is distinct from:
//
//     ExecutionContextIsCompatibleWithEnvironment(...)
//
// A context may be intrinsically valid while its Authorization Chain
// is incompatible with a particular selected environment.
//
// Runtime is responsible for using the compatibility relation as a
// delivery gate before handing the context to the Execution Engine.
//
// The Engine itself does not derive or reinterpret compatibility.
//
// ------------------------------------------------------------
//
// D6 — STRUCTURAL INDEPENDENCE
//
// The formalization must establish more than:
//
//     intrinsic validity
//     OR
//     environment compatibility
//
// Instead it establishes the stronger separation:
//
//     Intrinsic validity
//         |
//         | independent of selected environment
//         v
//     ExecutionEngineInputIsValid
//
//     Environment-specific delivery
//         |
//         | additionally requires
//         v
//     Chain × Environment compatibility
//
// Therefore the same ExecutionContext can remain intrinsically valid
// while two selected environments produce different delivery results.
//
// ------------------------------------------------------------
//
// D6 — SEMANTIC CONSEQUENCE
//
// Chain remains semantic because it is already part of Authorization.
//
// Environment remains contextual because it is external to
// ExecutionContext.
//
// Therefore two ExecutionContexts remain equal according to their
// existing Value Object semantics regardless of which environment
// is selected for materialization.
//
// Environment compatibility is a relation over:
//
//     AuthorizationChain × ExecutionEnvironment
//
// and is not a component of ExecutionContext equality.
//
// ------------------------------------------------------------
//
// EXECUTION REQUEST BOUNDARY
//
// ExecutionRequest represents:
//
//     what is requested for materialization
//
// ExecutionContext represents:
//
//     the already validated decision associated with that request
//
// ExecutionSemantics preserves the request values carried by the
// context and does not reinterpret their business meaning.
//
// In particular, the Execution Engine receives the same:
//
//     DomainAction
//     Authorization
//     ExecutionTarget
//     ExecutionConstraints
//
// represented by the ExecutionContext.
//
// ------------------------------------------------------------
//
// EXECUTION CONSTRAINT BOUNDARY
//
// ExecutionConstraints are opaque Value Object data carried by
// ExecutionRequest.
//
// ExecutionSemantics does not invent or interpret constraint
// categories.
//
// Their concrete semantics remain outside this module.
//
// The Runtime / preceding execution layer is responsible for
// evaluating and verifying the applicable ExecutionConstraints.
//
// This module represents the verification witness only by the
// concrete ExecutionConstraints value to which that verification
// applies.
//
// Therefore:
//
//     ExecutionConstraintsAreVerified(context, verifiedConstraints)
//
// means:
//
//     ExecutionContextConstraints(context)
//         ==
//     verifiedConstraints
//
// The equality is Value Object equality.
//
// This relation does NOT define how the constraints are evaluated,
// what constraint categories exist, or which external runtime
// mechanism performs the evaluation.
//
// The module therefore establishes the binding between:
//
//     the constraints carried by the ExecutionContext
//
// and:
//
//     the constraints represented by the verification witness.
//
// ------------------------------------------------------------
//
// IMPORTANT NON-RESPONSIBILITIES
//
// This module intentionally contains no:
//
//   - Runtime orchestration;
//   - batching implementation;
//   - multicall encoding;
//   - atomicity implementation;
//   - gas accounting;
//   - sponsorship implementation;
//   - blockchain ABI;
//   - Adapter implementation;
//   - Execution lifecycle;
//   - ExecutionId;
//   - execution storage;
//   - DomainAction business semantics;
//   - concrete ExecutionEnvironment representation;
//   - concrete Chain / network compatibility algorithm;
//   - concrete ExecutionConstraints algebra;
//   - constraint evaluation algorithm.
//
// Those are implementation / infrastructure concerns unless and
// until the DDD gives them additional semantic status.
//
// ============================================================

include "../authorization/Authorization.dfy"
include "ExecutionContext.dfy"

module KipioAccountExecutionSemantics
{
  import opened KipioAccountAuthorization
  import opened KipioAccountExecutionContext
  import opened KipioAccountExecutionRequest
  import opened KipioAccountDomainPrimitives
  import opened KipioAccountAuthorizationState
  import opened KipioAccountEffectiveAuthority
  import opened KipioAccountCapability
  import opened KipioAccountIdentity
  import opened KipioAccountAccount
  import opened KipioAccountExecutionConstraints
  import opened KipioAccountChain


  // ----------------------------------------------------------
  // EXECUTION CONSTRAINT VERIFICATION
  // ----------------------------------------------------------

  // ExecutionConstraints remain opaque in this module.
  //
  // The concrete constraint algebra is intentionally not defined
  // here because the DDD does not currently establish such an
  // algebra.
  //
  // The Runtime / preceding execution layer supplies the verified
  // ExecutionConstraints value.
  //
  // Verification in this module means that the verification witness
  // is bound to the exact ExecutionConstraints carried by the
  // ExecutionContext.
  //
  // The predicate does not interpret the constraint value and does
  // not define how external verification was performed.

  ghost predicate ExecutionConstraintsAreVerified(
    context: ExecutionContext,
    verifiedConstraints: ExecutionConstraints
  )
  {
    ExecutionContextConstraints(context)
    ==
    verifiedConstraints
  }


  // ----------------------------------------------------------
  // EXECUTION ENVIRONMENT
  // ----------------------------------------------------------

  // ExecutionEnvironment is intentionally represented only as an
  // abstract specification boundary in this module.
  //
  // No concrete blockchain representation is defined here.
  //
  // The concrete meaning of an ExecutionEnvironment belongs to
  // execution infrastructure.

  type ExecutionEnvironment(==)


  // ----------------------------------------------------------
  // AUTHORIZATION CHAIN PROJECTION
  // ----------------------------------------------------------

  // This is the only semantic projection used to connect
  // ExecutionContext to environment compatibility.
  //
  // The selected environment is never extracted from the context.
  //
  // Instead:
  //
  //     ExecutionContext
  //          ↓
  //     Authorization
  //          ↓
  //     Chain
  //
  // and then the external compatibility relation connects that
  // Chain to the selected ExecutionEnvironment.

  ghost function ExecutionContextAuthorizationChain(
    context: ExecutionContext
  ): Chain
  {
    AuthorizationChain(
      ExecutionContextAuthorization(context)
    )
  }


  // ----------------------------------------------------------
  // EXTERNAL CHAIN / ENVIRONMENT COMPATIBILITY RELATION
  // ----------------------------------------------------------

  // The concrete compatibility relation is supplied externally.
  //
  // It is represented extensionally as a set of compatible pairs:
  //
  //     (Chain, ExecutionEnvironment)
  //
  // This module does not decide which pairs belong to the relation.
  //
  // That concrete decision belongs to infrastructure.

  ghost predicate ChainEnvironmentPairIsCompatible(
    compatibilityRelation: set<(Chain, ExecutionEnvironment)>,
    chain: Chain,
    environment: ExecutionEnvironment
  )
  {
    (chain, environment) in compatibilityRelation
  }


  // ----------------------------------------------------------
  // CONTEXT / ENVIRONMENT COMPATIBILITY
  // ----------------------------------------------------------

  // Compatibility of an ExecutionContext with an environment is
  // determined exclusively through the Authorization Chain carried
  // by the context.
  //
  // Therefore:
  //
  //     context compatibility
  //
  // is not an independent boolean fact attached to the context.
  //
  // It is derived from:
  //
  //     Authorization Chain
  //             +
  //     selected Environment
  //             +
  //     external Compatibility Relation.

  ghost predicate ExecutionContextIsCompatibleWithEnvironment(
    context: ExecutionContext,
    environment: ExecutionEnvironment,
    compatibilityRelation: set<(Chain, ExecutionEnvironment)>
  )
  {
    ChainEnvironmentPairIsCompatible(
      compatibilityRelation,
      ExecutionContextAuthorizationChain(context),
      environment
    )
  }


  // ----------------------------------------------------------
  // COMPATIBILITY RELATION PROPERTIES
  // ----------------------------------------------------------

  // Exact normalization of the context/environment compatibility
  // predicate to the external relation.
  //
  // The result is specifically determined by the Authorization Chain
  // and selected Environment.

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


  // If the Chain / Environment pair is absent from the supplied
  // compatibility relation, the compatibility predicate is false.

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


  // If the Chain / Environment pair is present in the supplied
  // compatibility relation, the compatibility predicate is true.

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


  // ----------------------------------------------------------
  // SAME CHAIN => SAME ENVIRONMENT COMPATIBILITY
  // ----------------------------------------------------------

  // Two execution contexts carrying the same Authorization Chain
  // have exactly the same environment compatibility result for a
  // given environment and relation.
  //
  // This prevents environment compatibility from depending on
  // unrelated ExecutionContext fields.

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


  // ----------------------------------------------------------
  // INTRINSIC VALIDITY / ENVIRONMENT INDEPENDENCE
  // ----------------------------------------------------------

  // Intrinsic Engine validity deliberately has no Environment
  // parameter.
  //
  // This helper exposes that structure directly:
  //
  // the same intrinsic validity decision is used before selecting
  // either environment.

  lemma IntrinsicExecutionValidityIsSharedAcrossEnvironmentSelections(
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
      (
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
      )
      ==
      (
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
      )
  {
  }


  // ----------------------------------------------------------
  // ENVIRONMENT INCOMPATIBILITY DOES NOT REDEFINE VALIDITY
  // ----------------------------------------------------------

  // A context may be intrinsically valid even when the selected
  // environment is incompatible.
  //
  // This is the semantic distinction:
  //
  //     intrinsic validity
  //
  // is not redefined as:
  //
  //     intrinsic validity AND environment compatibility.
  //
  // The environment gate may reject delivery while the context
  // itself remains intrinsically valid.

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


  // ----------------------------------------------------------
  // TWO-ENVIRONMENT SEPARATION WITNESS
  // ----------------------------------------------------------

  // This is the strongest structural D6 witness in this module.
  //
  // For the SAME ExecutionContext:
  //
  //     intrinsic validity remains true;
  //
  // while two environments may have different delivery outcomes.
  //
  // The relation is external, so the theorem does not invent which
  // environments are compatible. It only proves the consequence of
  // an extensional relation containing one pair and excluding the
  // other pair.
  //
  // Therefore this theorem demonstrates:
  //
  //     Intrinsic validity
  //             ≠
  //     Environment compatibility
  //
  // without introducing physical blockchain semantics.

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
  //
  // This makes explicit that the distinction is not tied to a
  // particular ordering of environments.

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


  // ----------------------------------------------------------
  // EXECUTION ENGINE INPUT
  // ----------------------------------------------------------

  // A value may cross the intrinsic Execution Engine boundary only
  // when:
  //
  //   1. the ExecutionContext is a complete validated decision
  //      for the relevant Account and contextual witnesses;
  //
  //   2. Proof verification has already succeeded;
  //
  //   3. EffectiveAuthority provenance has already been established;
  //
  //   4. the verified ExecutionConstraints value is exactly the
  //      ExecutionConstraints carried by the context.
  //
  // Environment compatibility is intentionally NOT part of this
  // intrinsic input relation.
  //
  // The selected environment is handled by the separate
  // environment-delivery gate below.

  ghost predicate ExecutionEngineInputIsValid(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints
  )
  {
    ValidExecutionContextForAccount(
      context,
      account,
      identities,
      sourceReferences,
      sourceAuthorities,
      contributions,
      proofVerified
    )
    &&
    ExecutionConstraintsAreVerified(
      context,
      verifiedConstraints
    )
  }


  // ----------------------------------------------------------
  // ENVIRONMENT-SPECIFIC ENGINE DELIVERY
  // ----------------------------------------------------------

  // A context may be delivered to the Execution Engine for a
  // selected environment only when:
  //
  //   1. the complete validated execution decision is valid;
  //
  //   2. the verified ExecutionConstraints value is exactly the
  //      ExecutionConstraints carried by the context;
  //
  //   3. the Authorization Chain / Environment pair belongs to the
  //      externally supplied compatibility relation.
  //
  // Environment compatibility is a contextual delivery condition.
  //
  // It does NOT redefine intrinsic ExecutionContext validity.

  ghost predicate ExecutionEngineInputIsValidForEnvironment(
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
  {
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
    ExecutionContextIsCompatibleWithEnvironment(
      context,
      environment,
      compatibilityRelation
    )
  }


  // ----------------------------------------------------------
  // ENVIRONMENT GATE SOUNDNESS
  // ----------------------------------------------------------

  // Any context that crosses the environment-specific Engine
  // boundary must have its Authorization Chain / Environment pair
  // in the compatibility relation.

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


  // ----------------------------------------------------------
  // RESOLVED AUTHORITY BOUNDARY
  // ----------------------------------------------------------

  // The execution boundary receives the EffectiveAuthority already
  // carried by the validated ExecutionContext.
  //
  // No authority derivation occurs here.

  ghost predicate ExecutionEngineReceivesResolvedAuthority(
    context: ExecutionContext,
    account: Account,
    identities: set<Identity>,
    sourceReferences: seq<AuthoritySourceReference>,
    sourceAuthorities: seq<set<Capability>>,
    contributions: seq<set<Capability>>,
    proofVerified: bool,
    verifiedConstraints: ExecutionConstraints
  )
  {
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
    ValidEffectiveAuthority(
      ExecutionContextEffectiveAuthority(context)
    )
    &&
    RequestedAuthorityWithinEffectiveAuthority(
      ExecutionContextAuthorization(context),
      ExecutionContextEffectiveAuthority(context)
    )
  }


  // ----------------------------------------------------------
  // CORE ENGINE INPUT LAWS
  // ----------------------------------------------------------

  lemma ExecutionEngineAcceptsOnlyValidContexts(
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
      ValidExecutionContextForAccount(
        context,
        account,
        identities,
        sourceReferences,
        sourceAuthorities,
        contributions,
        proofVerified
      )
  {
  }


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
    requires
      ExecutionEngineReceivesResolvedAuthority(
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
  }


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
    requires
      ExecutionEngineReceivesResolvedAuthority(
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
      ValidEffectiveAuthority(
        ExecutionContextEffectiveAuthority(context)
      )
  {
  }


  // ----------------------------------------------------------
  // REQUEST PRESERVATION
  // ----------------------------------------------------------

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
  }


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
  }


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
  }


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
      ExecutionContextConstraints(context)
      ==
      ExecutionRequestConstraints(
        ExecutionContextRequest(context)
      )
  {
  }


  // ----------------------------------------------------------
  // STATE SNAPSHOT BOUNDARY
  // ----------------------------------------------------------

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
      ValidAuthorizationState(
        ExecutionContextAuthorizationState(context)
      )
  {
  }


  function ExecutionEngineAuthorizationState(
    context: ExecutionContext
  ): AuthorizationState
  {
    ExecutionContextAuthorizationState(context)
  }


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
  }


  // ----------------------------------------------------------
  // CREDENTIAL BOUNDARY
  // ----------------------------------------------------------

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
      ExecutionContextCredentialIsRecognized(context)
  {
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
      ExecutionContextCredentialIsUsable(context)
  {
  }


  // ----------------------------------------------------------
  // AUTHORIZATION / AUTHORITY SEPARATION
  // ----------------------------------------------------------

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
  }


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
  }


  // ----------------------------------------------------------
  // RESOLVED AUTHORITY VALUE
  // ----------------------------------------------------------

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
      ExecutionEngineResolvedAuthority(context)
      ==
      ExecutionContextEffectiveAuthority(context)
  {
  }


  // ----------------------------------------------------------
  // EXECUTION CONSTRAINT BOUNDARY
  // ----------------------------------------------------------

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
      ExecutionContextConstraints(context)
      ==
      ExecutionRequestConstraints(
        ExecutionContextRequest(context)
      )
  {
  }


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
      ExecutionConstraintsAreVerified(
        context,
        verifiedConstraints
      )
  {
  }


  // ----------------------------------------------------------
  // ENVIRONMENT / INTRINSIC VALIDITY DECOMPOSITION
  // ----------------------------------------------------------

  // The environment-specific gate is exactly the conjunction of:
  //
  //     intrinsic engine validity
  //
  // and:
  //
  //     selected environment compatibility.
  //
  // This prevents the environment relation from being smuggled
  // into the intrinsic validity predicate.

  lemma EnvironmentGateAddsOnlyCompatibility(
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
      ==
      (
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
        ExecutionContextIsCompatibleWithEnvironment(
          context,
          environment,
          compatibilityRelation
        )
      )
  {
  }


  // ----------------------------------------------------------
  // TEMPORAL DECISION BOUNDARY
  // ----------------------------------------------------------

  function ExecutionEngineEvaluationTime(
    context: ExecutionContext
  ): Timestamp
  {
    ExecutionContextEvaluationTime(context)
  }


  lemma ExecutionEngineUsesContextEvaluationTime(
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
      ExecutionEngineEvaluationTime(context)
      ==
      ExecutionContextEvaluationTime(context)
  {
  }


  // ----------------------------------------------------------
  // MATERIALIZATION BOUNDARY
  // ----------------------------------------------------------

  // A context may enter the Execution Engine for a selected
  // environment only when:
  //
  //   - it is a complete valid execution decision;
  //   - the verified ExecutionConstraints value is exactly the
  //     ExecutionConstraints carried by the context;
  //   - the Authorization Chain / Environment pair belongs to the
  //     supplied compatibility relation.
  //
  // Compatibility is a contextual precondition to delivery.
  //
  // It is NOT part of ExecutionContext equality and does NOT alter
  // intrinsic ExecutionContext validity.

  ghost predicate ExecutionContextCanEnterExecutionEngine(
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
  {
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
  }


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
    requires
      ExecutionContextCanEnterExecutionEngine(
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
  {
  }


  // ----------------------------------------------------------
  // EXECUTION / CONTEXT SEPARATION
  // ----------------------------------------------------------

  // ExecutionContext is a decision value, not an Execution Entity.
  //
  // ExecutionSemantics introduces no ExecutionId, execution
  // lifecycle or execution state.
  //
  // The actual execution materialization remains outside this
  // semantic boundary.
}

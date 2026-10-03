include "foundation/Chain.dfy"

module KipioExternLabConsumer {
  import ChainModule = KipioAccountChain

  method Identity(
    c: ChainModule.Chain
  ) returns (
      r: ChainModule.Chain
    )
    ensures r == c
  {
    r := c;
  }

  method Compare(
    left: ChainModule.Chain,
    right: ChainModule.Chain
  ) returns (
      same: bool
    )
    ensures same <==> left == right
  {
    same := left == right;
  }

  method SequenceRoundtrip(
    values: seq<ChainModule.Chain>
  ) returns (
      result: seq<ChainModule.Chain>
    )
    ensures result == values
  {
    result := values;
  }

  function Echo(
    c: ChainModule.Chain
  ): ChainModule.Chain
  {
    c
  }
}

module KipioExternLabOpenedConsumer {
  import opened KipioAccountChain

  method IdentityOpened(
    c: Chain
  ) returns (
      r: Chain
    )
    ensures r == c
  {
    r := c;
  }

  method SequenceOpened(
    values: seq<Chain>
  ) returns (
      result: seq<Chain>
    )
    ensures result == values
  {
    result := values;
  }
}

module KipioExternLabQualifiedConsumer {
  import KipioAccountChain

  method IdentityQualified(
    c: KipioAccountChain.Chain
  ) returns (
      r: KipioAccountChain.Chain
    )
    ensures r == c
  {
    r := c;
  }

  method CompareQualified(
    left: KipioAccountChain.Chain,
    right: KipioAccountChain.Chain
  ) returns (
      same: bool
    )
    ensures same <==> left == right
  {
    same := left == right;
  }
}


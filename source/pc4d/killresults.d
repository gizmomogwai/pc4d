module pc4d.killresults;

import pc4d.parser;

/++
 + convenient function to build a parser that kills the result of
 + another parser e.g. killResults(match("a")) succeeds, but returns
 + an empty result
 +/
Parser!(T) killResults(T)(Parser!(T) parser) {
  return parser ^^ (Variant[] input) {
    Variant[] res;
    return res;
  };
}

/// unittests for kill results
unittest {
  import unit_threaded;

  auto res = killResults(match("a")).parse("a");
  res.success.shouldBeTrue;
  res.results.length.shouldEqual(0);
}

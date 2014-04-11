module pc.killresults;

import pc.parser;

/// convenient function to build a parser that kills the result of another parser e.g. killResults(match("a")) succeeds, but returns an empty result
Parser!(T) killResults(T)(Parser!(T) parser) {
  return parser ^^ (Variant[] input) {
    Variant[] res;
    return res;
  };
}

/// unittests for kill results
unittest {
  auto res = killResults(match("a")).parse("a");
  assert(res.success);
  assert(res.results.length == 0);
}

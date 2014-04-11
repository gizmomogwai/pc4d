module pc.alnumparser;

import pc.parser;

/// parser for parsing alphanumerical values starting with a letter or -
class AlnumParser(T) : RegexParser {
  this(bool collect=true) {
    super(r"-?\w[\w\d]*", collect) ^^ (Variant[] input) {
      return variantArray(input[0]);
    };
  }
}

/// convenient function to instantiate a AlphaNumericParser
auto alnum(T)(bool collect=true) {
  return new AlnumParser!(T)(collect);
}

/// unittests for alnum parser
unittest {
  auto parser = alnum!(immutable(char))();
  auto res = parser.parseAll("-Aa1234");
  assert(res.success);
  assert(res.results[0] == "-Aa1234");
  res = parser.parseAll("a1234");
  assert(res.success);
}

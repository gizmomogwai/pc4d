module pc4d.parsers.alnum;

import pc4d.parser;

/// parser for parsing alphanumerical values starting with a letter or -
class Alnum(T) : RegexParser {
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

/// the pc4d.alnum parser
unittest {
  import unit_threaded;

  auto parser = alnum!(immutable(char))();
  auto res = parser.parseAll("-Aa1234");
  res.success.shouldBeTrue;
  res.results[0].shouldEqual("-Aa1234");
  res = parser.parseAll("a1234");
  res.success.shouldBeTrue;
}

module pc4d.alternative;

import pc4d.parser;

/// class for matching alternatives
class Alternative(T) : Parser!(T) {
  Parser!(T)[] fParsers;

  this(Parser!(T)[] parsers ...) {
    fParsers = parsers.dup;
  }

  override ParseResult!(T) parse(T[] s) {
    foreach (parser; fParsers) {
      auto res = parser.parse(s);
      if (res.success) {
        return transform(res);
      }
    }
    return ParseResult!(T).error("or did not match");
  }
}

/// convenient function
Parser!(T) or(T)(Parser!(T)[] parsers...) {
  return new Alternative!(T)(parsers);
}

/// showing off the or dsl
unittest {
  import unit_threaded;

  auto parser = or(match("a"), match("b"), match("c"));
  parser.parse("a").success.shouldBeTrue;
  parser.parse("b").success.shouldBeTrue;
  parser.parse("c").success.shouldBeTrue;
}

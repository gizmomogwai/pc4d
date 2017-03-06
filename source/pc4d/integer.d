module pc4d.integer;

import pc4d.parser;

/// parser for parsing ints
static class Integer : RegexParser {
  this() {
    import std.conv;
    super(r"\d+") ^^ (input) { return variantArray(input[0].get!string.to!int); };
  }
}

/// convenience function to create an integer parser
Parser!(T) integer(T)() {
  return new Integer;
}

/// unittests for integer
unittest {
  import unit_threaded;

  auto parser = integer!(immutable(char));
  auto res = parser.parse("123");
  res.success.shouldBeTrue;
  res.results[0].shouldEqual(123);
}

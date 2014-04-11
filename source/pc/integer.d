module pc.integer;

import pc.parser;

/// parser for parsing ints
static class Integer : RegexParser {
  this() {
    super(r"\d+") ^^ (input) { return variantArray(std.conv.to!(int)(input[0].get!(string))); };
  }
}

/// convenience function to create an integer parser
Parser!(T) integer(T)() {
  return new Integer;
}

/// unittests for integer
unittest {
  auto parser = integer!(immutable(char));
  auto res = parser.parse("123");
  assert(res.success);
  assert(res.results[0] == 123);
}

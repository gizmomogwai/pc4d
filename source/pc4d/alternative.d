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

/// unittests showing the alternative parser and its dsl '|'
unittest {
  auto parser = match("a") | match("b");
  auto res = parser.parse("a");
  assert(res.success);

  res = parser.parse("b");
  assert(res.success);

  res = parser.parse("c");
  assert(!res.success);
}

unittest {
  auto parser = match("ab") | match("cd");
  auto res = parser.parse("ab");
  assert(res.success);
}

unittest {
  auto parser = match("ab") | match("cd");
  auto res = parser.parse("cde");
  assert(res.success);
  assert(res.rest == "e");
}
unittest {
  auto parser = match("ab") | match("cd");
  auto res = parser.parse("ef");
  assert(!res.success);
}
unittest {
  auto parser = (match("ab") | match("cd")) ^^ (Variant[] input) {
    if (input[0] == "ab") {
      input[0] = "super";
    }
    return input;
  };
  auto suc = parser.parse("ab");
  assert(suc.success);
  assert(suc.results[0] == "super");
  suc = parser.parse("cd");
  assert(suc.success);
  assert(suc.results[0] == "cd");
}

unittest {
  auto parser = match("a", false) | match("b");
  auto res = parser.parse("ab");
  assert(res.success);
}

unittest {
  auto parser = or(match("a"), match("b"), match("c"));
  assert(parser.parse("a").success);
  assert(parser.parse("b").success);
  assert(parser.parse("c").success);
}

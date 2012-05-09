module pc.optional;
import pc.parser;


/// class for matching something optional
class Optional(T) : Parser!(T) {
  Parser!(T) fParser;

  this(Parser!(T) parser) {
    fParser = parser;
  }

  ParseResult!(T) parse(T[] s) {
    auto res = fParser.parse(s);
    if (!res.success) {
      return success(s);
    } else {
      return res;
    }
  }
}

/// unittests to demonstrate the OptionalParser and its dsl '-'

unittest {
  auto abc = match("abc");
  auto opt = - abc;
  auto res = opt.parse("abc");
  assert(res.success);
  assert(res.results.length == 1);
  assert(res.results[0] == "abc");
  assert(res.rest.length == 0);
}

unittest {
  auto abc = match("abc");
  auto opt = - abc;
  auto res = opt.parse("efg");
  assert(res.success);
  assert(res.results.length == 0);
  assert(res.rest == "efg");
}

unittest {
  auto sign = match("+");
  auto value = match("1");
  auto test = -(sign ~ value);
  auto res = test.parse("+1");
  assert(res.success);
  assert(res.results.length == 2);
  res = test.parse("");
  assert(res.success);
}




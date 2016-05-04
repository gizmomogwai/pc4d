module pc4d.optional;

import pc4d.parser;


/// class for matching something optional
class Optional(T) : Parser!(T) {
  Parser!(T) fParser;

  this(Parser!(T) parser) {
    fParser = parser;
  }

  override ParseResult!(T) parse(T[] s) {
    auto res = fParser.parse(s);
    if (!res.success) {
      return success(s);
    } else {
      return res;
    }
  }
}

/// unittests to show the usage of OptionalParser and its dsl '-'
unittest {
  auto abc = match("abc");
  auto opt = - abc;
  auto res = opt.parse("abc");
  assert(res.success);
  assert(res.results.length == 1);
  assert(res.results[0] == "abc");
  assert(res.rest.length == 0);
}

/// unittest to show optional in action.
unittest {
  auto abc = match("abc");
  auto opt = - abc;
  auto res = opt.parse("efg");
  auto withoutOptional = abc.parse("efg");
  assert(!withoutOptional.success);
  assert(res.success);
  assert(res.results.length == 0);
  assert(res.rest == "efg");
}

/// parse a number with or without sign
unittest {
  auto sign = match("+");
  auto value = match("1");
  auto test = (- sign) ~ value;
  auto resWithSign = test.parse("+1");
  assert(resWithSign.success);
  assert(resWithSign.results.length == 2);
  auto resWithoutSign = test.parse("1");
  assert(resWithoutSign.success);
}




module pc.lazyparser;

import pc.parser;
import std.functional;

/// this parser is needed to build recursive parser hierarchies
class LazyParser(T) : Parser!(T) {
  Parser!(T) delegate() fCallable;

  this(Parser!(T) delegate() parser) {
    assert(parser != null);
    fCallable = parser;
  }

  this(Parser!(T) function() parser) {
    assert(parser != null);
    fCallable = toDelegate(parser);
  }

  ParseResult!(T) parse(T[] s) {
    auto parser = fCallable();
    return transform(parser.parse(s));
  }

}

/// convenient function to instantiate a lazy parser with a delegate
Parser!(T) lazyParser(T)(Parser!(T) delegate() parser) {
  return new LazyParser!(T)(parser);
}
/// convenient function to instantiate a lazy parser with a function
Parser!(T) lazyParser(T)(Parser!(T) function() parser) {
  return new LazyParser!(T)(parser);
}

/// unittest to show a simple usage of lazy
unittest {
  class Endless {
    // endless -> a | a opt(endless)
    Parser!(immutable(char)) lazyEndless() {
      return lazyParser!(immutable(char))(&endless);
    }

    Parser!(immutable(char)) endless() {
      return match("a") ~ (-(lazyEndless()));
    }
  }
  auto parser = new Endless;
  auto p = parser.endless();
  auto res = p.parse("aa");
  assert(res.success);
  res = p.parse("aab");
  assert(res.success);
  assert(res.rest == "b");
}

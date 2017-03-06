module pc4d.lazyparser;

import pc4d.parser;
import std.functional;

/++
 + this parser is needed to build recursive parser hierarchies.
 + look for expression.d for a more realistic example than in the unittest
 +/
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

  override ParseResult!(T) parse(T[] s) {
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

/// unittest to show the simplest usage of lazy
unittest {
  import unit_threaded;

  // endless -> a | a opt(endless)
  struct Endless {
    static Parser!(immutable(char)) lazyEndless() {
      return lazyParser!(immutable(char))(&parser);
    }
    static Parser!(immutable(char)) parser() {
      return match("a") ~ (-(lazyEndless()));
    }
  }

  auto p = Endless.parser();
  auto res = p.parse("aa");
  res.success.shouldBeTrue;
  res.results.shouldEqual(["a", "a"]);

  res = p.parse("aab");
  res.success.shouldBeTrue;
  res.results.shouldEqual(["a", "a"]);
  res.rest.shouldEqual("b");
}

module pc.sequence;
import pc.parser;
import std.array;
import std.variant;
import core.vararg;

/// class for matching sequences
class Sequence(T) : Parser!(T) {
  Parser!(T)[] fParsers;
  this(Parser!(T)[] parsers ...) {
    fParsers = parsers.dup;
  }

  ParseResult!(T) parse(T[] s) {
    auto resultObjects = appender!(Variant[])();
    T[] h = s;
    foreach (parser; fParsers) {
      auto res = parser.parse(h);
      if (res.success) {
	h = res.rest;
	resultObjects.put(res.results);
      } else {
	return res;
      }
    }
    return transform(ParseResult!(T).ok(h, resultObjects.data));
  }
}

/// convenient function
Parser!(T) sequence(T)(Parser!(T)[] parsers...) {
  return new Sequence!(T)(parsers);
}

/// unittests showing usage of sequence parser and dsl '~'
unittest {
  auto parser = match("a") ~ match("b");
  auto res = parser.parse("ab");
  assert(res.success);
  assert(res.results.length == 2);
}

unittest {
  auto parser = match("a") ~ match("b");
  auto res = parser.parse("abc");
  assert(res.success);
  assert(res.rest == "c");
}

unittest {
  auto parser = match("a") ~ match("b");
  auto res = parser.parse("ac");
  assert(!res.success);
}

unittest {
  auto parser = match("a") ~ match("b");
  auto res = parser.parse("ab");
  assert(res.success);
  res = parser.parse("ac");
  assert(!res.success);
}


unittest {
  auto parser = match("a", false) ~ match("b");
  auto res = parser.parse("ab");
  assert(res.success);
}

unittest {
  auto parser = (match("a") ~ match("b")) ^^ (Variant[] result) {
    string totalString;
    foreach (Variant o ; result) {
      if (o.type == typeid(string)) {
        totalString ~= o.get!(string);
      }
    }

    Variant v = totalString;
    return [v];
  };

  auto suc = parser.parse("ab");
  assert(suc.success);
  assert(suc.results.length == 1);
  assert(suc.results[0] == "ab");
}

unittest {
  auto ab = -match("a") ~ match("b");
  auto res = ab.parse("ab");
  assert(res.success);
  res = ab.parse("b");
  assert(res.success);
  res = ab.parse("c");
  assert(!res.success);
  res = ab.parse("");
  assert(!res.success);
}

unittest {
  auto ab = sequence(match("a"), match("b"));
  auto res = ab.parse("ab");
  assert(res.success);
}

unittest {
  auto ab = sequence(match("a"), match("b"), match("c"));
  auto res = ab.parse("abc");
  assert(res.success);
}

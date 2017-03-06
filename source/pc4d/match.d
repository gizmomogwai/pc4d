module pc4d.match;

import pc4d.parser;


/// class for matching an array exactly
class Matcher(T) : Parser!(T) {
  T[] fExpected;
  bool fCollect;
  this(T[] expected, bool collect=true) {
    fExpected = expected;
    fCollect = collect;
  }

  bool startsWith(T[] aInput, T[] expected) {
    if (aInput.length < expected.length) {
      return false;
    }
    for (int i=0; i<expected.length; i++) {
      if (aInput[i] != expected[i]) {
        return false;
      }
    }
    return true;
  }

  override ParseResult!(T) parse(T[] s) {
    if (startsWith(s, fExpected)) {
      auto rest = s[fExpected.length..$];
      if (fCollect) {
        return transform(success(rest, fExpected));
      } else {
        return success(rest);
      }
    } else {
      return ParseResult!(T).error("");//"Expected: '" ~ fExpected ~ "' but got '" ~ s ~ "'");
    }
  }
}


/// convenient function to instantiate a matcher
Parser!(T) match(T)(T[] s, bool collect=true) {
  return new Matcher!(T)(s, collect);
}

/// matching a string
unittest {
  import unit_threaded;

  auto parser = match("test");
  auto res = parser.parseAll("test");

  res.success.shouldBeTrue;
  res.rest.length.shouldEqual(0);
}

unittest {
  import unit_threaded;

  auto parser = match("test");
  auto res = parser.parse("test2");
  res.success.shouldBeTrue;
  res.rest.shouldEqual("2");

  res = parser.parseAll("test2");
  res.success.shouldBeFalse;
}

/// transform match result
unittest {
  auto parser = match("test") ^^ (objects) {
    auto res = objects;
    if (objects[0] == "test") {
      res[0] = "super";
    }
    return objects;
  };
  auto res = parser.parse("test");
  assert(res.success);
  assert(res.results[0] == "super");
}

unittest {
  auto parser = match("test", false);
  auto res = parser.parseAll("test");
  assert(res.success);
  assert(res.results.length == 0);
}

unittest {
  auto parser = match([1, 2, 3]);
  auto res = parser.parseAll([1, 2, 3]);
  assert(res.success);
  assert(res.results.length == 1);
  assert(res.results[0] == [1, 2, 3]);
}

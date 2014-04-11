module pc.repetition;

import pc.parser;

/// class for matching repetitions
static class Repetition(T) : Parser!(T) {
  Parser!(T) fToRepeat;
  this(Parser!(T) toRepeat) {
    fToRepeat = toRepeat;
  }

  override ParseResult!(T) parse(T[] s) {
    Variant[] results;
    auto rest = s;
    while (true) {
      auto res = fToRepeat.parse(rest);
      if (res.success) {
	rest = res.rest;
	results = results ~ res.results;
      } else {
	break;
      }
    }
    return transform(ParseResult!(T).ok(rest, results));
  }
}

/// unittest for repetition
unittest {
  auto parser = *match("a");
  auto res = parser.parse("aa");
  assert(res.success);
  assert(res.rest == "");
  assert(res.results.length == 2);
}

unittest {
  auto parser = *match("a");
  auto res = parser.parse("b");
  assert(res.success);
  assert(res.rest == "b");
}

unittest {
  auto parser = *match("a");
  auto res = parser.parse("ab");
  assert(res.success);
  assert(res.rest == "b");
}

unittest {
  auto parser = *(match("+") ~ match("-"));
  auto res = parser.parse("+-+-+");
  assert(res.success);
  assert(res.rest == "+");
}

unittest {
  auto parser = *match("a", false);
  auto res = parser.parse("aaaa");
  assert(res.success);
  assert(res.rest.length == 0);
  assert(res.results.length == 0);
}

unittest {
  auto parser = (*match("a")) ^^ (input) {
    return variantArray(input.length);
  };
  auto suc = parser.parseAll("aaaaa");
  assert(suc.success);
  assert(suc.results.length == 1);
  assert(suc.results[0].get!(ulong) == 5);
}

module pc.regexparser;

import pc.parser;
import std.array;
import std.regex;

/// parser for regular expressions
class RegexParser : Parser!(immutable(char)) {
  string fRegex;
  bool fCollect;
  this(string regex, bool collect=true) {
    fRegex = regex;
    fCollect = collect;
  }

  override ParseResult!(immutable(char)) parse(string s) {
    auto res = std.regex.match(s, std.regex.regex(fRegex));
    if (res.empty()) {
      return ParseResult!(immutable(char)).error(s ~ "did not match " ~ fRegex);
    } else if (res.pre.length > 0) {
      return ParseResult!(immutable(char)).error(s ~ "did not match " ~ fRegex);
    } else {
      if (fCollect) {
	auto results = appender!(Variant[])();
	foreach (c; res.captures) {
	  Variant v = c;
	  results.put(v);
	}
	return transform(ParseResult!(immutable(char)).ok(res.post, results.data));
      } else {
	return success(res.post);
      }
    }
  }
}

/// convenient function to instantiate a regexparser
Parser!(T) regexParser(T)(T[] s, bool collect=true) {
  return new RegexParser(s, collect);
}

/// unittests for RegexParser
unittest {
  auto res = regexParser("abc").parse("abcd");
  assert(res.success);
  assert(res.rest == "d");
}

unittest {
  auto res = regexParser("abc").parse("babc");
  assert(!res.success);
}

unittest {
  auto res = regexParser("(.)(.)(.)").parse("abc");
  assert(res.success);
  assert(res.results.length == 4);
}

unittest {
  auto res = (regexParser("\\d+") ^^ (input) { return variantArray(123); }).parse("123");
  assert(res.success);
  assert(res.results[0] == 123);
}

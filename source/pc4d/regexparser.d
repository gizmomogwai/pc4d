module pc4d.regexparser;

import pc4d.parser;
import std.array;
import std.regex;

/++ parser for regular expressions
 + a successful parse step returns all captures in an array
 +/
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

/// regexParser
unittest {
  import unit_threaded;

  auto res = regexParser("(a)(.)(c)").parse("abcd");
  res.success.shouldBeTrue;
  res.results.shouldEqual(["abc", "a", "b", "c"]);
  res.rest.shouldEqual("d");
}

/// regexParser works from the start of the input
unittest {
  import unit_threaded;

  auto res = regexParser("abc").parse("babc");
  res.success.shouldBeFalse;
}

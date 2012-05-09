module pc.blockcomment;

import pc.parser;

/// parser for blockcomments
static class BlockCommentParser(T) : Parser!(T) {
  T[] fStart;
  T[] fEnd;
  bool fCollect;
  this(T[] startString, T[] endString, bool collect=true) {
    fStart = startString;
    fEnd = endString;
    fCollect = collect;
  }

  bool startsWith(T[] aInput, ulong startIdx, T[] expected) {
    T[] slice = aInput[startIdx..$];
    if (slice.length < expected.length) {
      return false;
    }
    for (int i=0; i<expected.length; i++) {
      if (slice[i] != expected[i]) {
	return false;
      }
    }
    return true;
  }

  ParseResult!(T) parse(T[] s) {
    if (startsWith(s, 0, fStart)) {
      auto l = fStart.length;
      for (auto i=l; i<s.length; i++) {
	if (startsWith(s, i, fEnd)) {
	  auto lastIdx = i+fEnd.length;
	  auto rest = s[lastIdx..$];
	  if (fCollect) {
	    auto matched = s[0..lastIdx];
	    return transform(success(rest, matched));
	  } else {
            return success(rest);
	  }
	}
      }
      return ParseResult!(T).error("");
    } else {
      return ParseResult!(T).error("");
    }
  }
}

/// convenient function
Parser!(T) blockComment(T)(T[] startString, T[] endString, bool collect=true) {
  return new BlockCommentParser!(T)(startString, endString, collect);
}

/// unittests for blockcomment
unittest {
  auto parser = blockComment("/*", "*/", true);
  auto res = parser.parseAll("/*abc*/");
  assert(res.success);
  assert(res.fResults[0] == "/*abc*/");
}

unittest {
  auto parser = blockComment("/*", "*/", false);
  auto res = parser.parseAll("/*abc*/");
  assert(res.success);
  assert(res.fResults.length == 0);
}


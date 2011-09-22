module pc.parser;

import std.string;
import std.stdio;
import std.array;
import std.ascii;
import std.string;
import std.conv;
import std.regex;
import std.variant;
import std.functional;


/**
 * Class for successfull parsing.
 * use fResults to get to the results.
 * use fRest to get to the not consumed part of the input.
 */
class ParseResult(T) {
  T[] fRest;
  Variant[] fResults;
  string fMessage;
  bool fSuccess;

  private this(bool success) {
    fRest = null;
    fResults = null;
    fMessage = null;
    fSuccess = success;
  }

  public static ParseResult!(T) ok(T[] rest, Variant[] results) {
    auto res = new ParseResult!(T)(true);
    res.fRest = rest;
    res.fResults = results;
    return res;
  }

  public static ParseResult!(T) error(string message) {
    auto res = new ParseResult!(T)(false);
    res.fMessage = message;
    return res;
  }

  @property string message() {
    return fMessage;
  }

  @property bool success() {
    return fSuccess;
  }

  @property T[] rest() {
    return fRest;
  }

  @property T[] rest(T[] rest) {
    return fRest = rest;
  }

  @property Variant[] results() {
    if (!success) {
      throw new Exception("no results available");
    }
    return fResults;
  }
}

class Parser(T) {
  Variant[] delegate(Variant[]) fCallable = null;

  static success(U...)(T[] rest, U args) {
    return ParseResult!(T).ok(rest, variantArray(args));
  }

  ParseResult!(T) parseAll(T[] s) {
    auto res = parse(s);
    if (res.success) {
      if ((res.rest is null) || (res.rest.length == 0)) {
        return res;
      } else {
        return ParseResult!(T).error("string not completely consumed"/*, res.rest*/);
      }
    } else {
      return res;
    }
  }

  ParseResult!(T) parse(T[] s) {
    throw new Exception("must be implemented in childs");
  }

  Parser opUnary(string op)() if (op == "*") {
    return new Repetition(this);
  }
  Parser opUnary(string op)() if (op == "-") {
    return new Optional(this);
  }

  Parser opBinary(string op)(Variant[] delegate(Variant[] objects) toCall) if (op == "^^") {
    return setCallback(toCall);
  }

  Parser opBinary(string op)(Variant[] function(Variant[] objects) toCall) if (op == "^^") {
    return setCallback(toCall);
  }

  Parser opBinary(string op)(Parser rhs) if (op == "|") {
    return new Alternative(this, rhs);
  }

  Parser opBinary(string op)(Parser rhs) if (op == "~") {
    return new Sequence(this, rhs);
  }

  Parser setCallback(Variant[] function(Variant[] objects) tocall) {
    fCallable = toDelegate(tocall);
    return this;
  }

  Parser setCallback(Variant[] delegate(Variant[] objects) tocall) {
    fCallable = tocall;
    return this;
  }

  ParseResult!(T) transform(ParseResult!(T) result) {
    if (result.success()) {
      return fCallable ? ParseResult!(T).ok(result.rest, fCallable(result.results)) : result;
    } else {
      return result;
    }
  }

  static class Matcher : Parser {
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

    ParseResult!(T) parse(T[] s) {
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

  static class Alternative : Parser {
    Parser[] fParsers;

    this(Parser[] parsers ...) {
      fParsers = parsers.dup;
    }

    ParseResult!(T) parse(T[] s) {
      foreach (parser; fParsers) {
        auto res = parser.parse(s);
        if (res.success) {
          return transform(res);
        }
      }
      return ParseResult!(T).error("or did not match");
    }

  }

  static class Sequence : Parser {
    Parser[] fParsers;
    this(Parser[] parsers ...) {
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

  static class Optional : Parser {

    Parser fParser;

    this(Parser parser) {
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


  static class Repetition : Parser {
    Parser fToRepeat;
    this(Parser toRepeat) {
      fToRepeat = toRepeat;
    }

    ParseResult!(T) parse(T[] s) {
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

  static class BlockCommentParser : Parser {
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

  unittest {
    debug{ std.stdio.writeln("testing blockcommentparser returning stuff"); }
    auto parser = new Parser!(immutable(char)).BlockCommentParser("/*", "*/", true);
    auto res = parser.parseAll("/*abc*/");
    assert(res.success);
    assert(res.fResults[0] == "/*abc*/");
    debug{ std.stdio.writeln("testing blockcommentparser returning stuff finished"); }
  }
  unittest {
    debug{ std.stdio.writeln("testing blockcommentparser not returning stuff"); }
    auto parser = new Parser!(immutable(char)).BlockCommentParser("/*", "*/", false);
    auto res = parser.parseAll("/*abc*/");
    assert(res.success);
    assert(res.fResults.length == 0);
    debug{ std.stdio.writeln("testing blockcommentparser not returning stuff finished"); }
  }

  static class RegexParser : Parser!(immutable(char)) {
    string fRegex;
    bool fCollect;
    this(string regex, bool collect=true) {
      fRegex = regex;
      fCollect = collect;
    }

    ParseResult!(immutable(char)) parse(string s) {
      auto res = std.regex.match(s, regex(fRegex));
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

  static class Number : RegexParser {
    this() {
      super(r"[-+]?[0-9]*\.?[0-9]+") ^^ (Variant[] input) {
        auto output = appender!(Variant[])();
        foreach (Variant o ; input) {
          string s = o.get!(string);
          Variant v = std.conv.parse!(double, string)(s);
          output.put(v);
        }
        return output.data;
      };
    }
  }

  static class Integer : RegexParser {
    this() {
      super(r"\d+") ^^ (Variant[] input) {
        string s = input[0].get!(string);
        Variant v = std.conv.parse!(int, string)(s);
        return variantArray(v);
      };
    }
  }

  static class AlnumParser : RegexParser {
    this() {
      super(r"-?\w[\w\d]*") ^^ (Variant[] input) {
        return variantArray(input[0]);
      };
    }
  }

  static class LazyParser : Parser!(T) {
    Parser!(T) delegate() fCallable;

    this(Parser delegate() parser) {
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

}

Parser!(T) killResults(T)(Parser!(T) parser) {
  return parser ^^ (Variant[] input) {
    Variant[] res;
    return res;
  };
}

Parser!(T) match(T)(T[] s, bool collect=true) {
  return new Parser!(T).Matcher(s, collect);
}

Parser!(T) lazyParser(T)(Parser!(T) delegate() parser) {
  return new Parser!(T).LazyParser(parser);
}
Parser!(T) lazyParser(T)(Parser!(T) function() parser) {
  return new Parser!(T).LazyParser(parser);
}

unittest {
  debug {std.stdio.writeln("match 1");}
  auto parser = match("test");
  auto res = parser.parseAll("test");
  assert(res.success);
  debug{std.stdio.writeln("match 1 finished");}
}



unittest {
  debug{std.stdio.writeln("match 2");}

  auto parser = match("test");
  auto res = parser.parse("test");
  assert(res.success);
  assert(res.rest is null || res.rest.length == 0);
  debug{std.stdio.writeln("match 2 finished");}
}

unittest {
  debug{std.stdio.writeln("match 3");}

  auto parser = match("test");
  auto res = parser.parse("abc");
  assert(!res.success);
  debug{std.stdio.writeln("match 3 finished");}
}

unittest {
  debug{std.stdio.writeln("match 4");}

  auto parser = match("test");
  auto res = parser.parse("test2");
  assert(res.success);
  assert(res.rest == "2");
  res = parser.parseAll("test2");
  assert(!res.success);
  debug{std.stdio.writeln("match 4 finished");}

}

unittest {
  debug{std.stdio.writeln("match 5");}

  auto parser = match("test") ^^ (Variant[] objects) {
    auto res = objects;
    if (objects[0] == "test") {
      res[0] = "super";
    }
    return objects;
  };
  auto res = parser.parse("test");
  assert(res.success);
  assert(res.results[0] == "super");
  debug{std.stdio.writeln("match 5 finished");}

}

unittest {
  debug{std.stdio.writeln("match 6");}

  auto parser = match("test", false);
  auto res = parser.parseAll("test");
  assert(res.success);
  assert(res.results.length == 0);
  debug{std.stdio.writeln("match 6 finished");}

}

unittest {
  debug{std.stdio.writeln("match 7");}

  auto parser = match([1, 2, 3]);
  auto res = parser.parseAll([1, 2, 3]);
  assert(res.success);
  assert(res.results.length == 1);
  assert(res.results[0] == [1, 2, 3]);
  debug{std.stdio.writeln("match 7 finished");}

}


unittest {
  debug{std.stdio.writeln("match 8");}

  auto parser = match("ab") | match("cd");
  auto res = parser.parse("ab");
  assert(res.success);
  debug{std.stdio.writeln("match 8 finished");}

}

unittest {
  debug{std.stdio.writeln("match 9");}

  auto parser = match("ab") | match("cd");
  auto res = parser.parse("cde");
  assert(res.success);
  assert(res.rest == "e");
  debug{std.stdio.writeln("match 9 finished");}
}
unittest {
  debug{std.stdio.writeln("match 10");}

  auto parser = match("ab") | match("cd");
  auto res = parser.parse("ef");
  assert(!res.success);
  debug{std.stdio.writeln("match 10 finished");}

}
unittest {
  debug{std.stdio.writeln("match 11");}

  auto parser = (match("ab") | match("cd")) ^^ (Variant[] input) {
    if (input[0] == "ab") {
      input[0] = "super";
    }
    return input;
  };
  auto suc = parser.parse("ab");
  assert(suc.success);
  assert(suc.results[0] == "super");
  suc = parser.parse("cd");
  assert(suc.success);
  assert(suc.results[0] == "cd");
  debug{std.stdio.writeln("match 11 finished");}

}

unittest {
  debug{std.stdio.writeln("match 12");}

  auto parser = match("a", false) | match("b");
  auto res = parser.parse("ab");
  assert(res.success);
  debug{std.stdio.writeln("match 12 finished");}

}



unittest {
  debug{std.stdio.writeln("match 13");}

  auto parser = match("a") ~ match("b");
  auto res = parser.parse("ab");
  assert(res.success);
  assert(res.results.length == 2);
  debug{std.stdio.writeln("match 13 finished");}

}

unittest {
  debug{std.stdio.writeln("match 14");}

  auto parser = match("a") ~ match("b");
  auto res = parser.parse("abc");
  assert(res.success);
  assert(res.rest == "c");
  debug{std.stdio.writeln("match 14 finished");}

}

unittest {
  debug{std.stdio.writeln("match 15");}

  auto parser = match("a") ~ match("b");
  auto res = parser.parse("ac");
  assert(!res.success);
  debug{std.stdio.writeln("match 15 finished");}

}
unittest {
  debug{std.stdio.writeln("match 16");}

  auto parser = match("a", false) ~ match("b");
  auto res = parser.parse("ab");
  assert(res.success);
  debug{std.stdio.writeln("match 16 finished");}

}

unittest {
  debug{std.stdio.writeln("match 17");}

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
  debug{std.stdio.writeln("match 17 finished");}

}

unittest {
  debug{std.stdio.writeln("match 18");}

  auto abc = match("abc");
  auto opt = - abc;
  auto res = opt.parse("abc");
  assert(res.success);
  assert(res.results.length == 1);
  assert(res.results[0] == "abc");
  assert(res.rest.length == 0);
  debug{std.stdio.writeln("match 18 finished");}

}

unittest {
  debug{std.stdio.writeln("match 19");}

  auto abc = match("abc");
  auto opt = - abc;
  auto res = opt.parse("efg");
  assert(res.success);
  assert(res.results.length == 0);
  assert(res.rest == "efg");
  debug{std.stdio.writeln("match 19 finished");}

}

unittest {
  debug{std.stdio.writeln("match 20");}

  auto sign = match("+");
  auto value = match("1");
  auto test = -(sign ~ value);
  auto res = test.parse("+1");
  assert(res.success);
  assert(res.results.length == 2);
  res = test.parse("");
  assert(res.success);
  debug{std.stdio.writeln("match 20 finished");}

}

unittest {
  debug{std.stdio.writeln("match 21");}

  auto ab = -match("a") ~ match("b");
  auto res = ab.parse("ab");
  assert(res.success);
  res = ab.parse("b");
  assert(res.success);
  res = ab.parse("c");
  assert(!res.success);
  res = ab.parse("");
  assert(!res.success);
  debug{std.stdio.writeln("match 21 finished");}
}

unittest {
  debug{std.stdio.writeln("match 22");}

  auto parser = *match("a");
  auto res = parser.parse("aa");
  assert(res.success);
  assert(res.rest == "");
  assert(res.results.length == 2);
  debug{std.stdio.writeln("match 22 finished");}

}
unittest {
  debug{std.stdio.writeln("match 23");}

  auto parser = *match("a");
  auto res = parser.parse("b");
  assert(res.success);
  assert(res.rest == "b");
  debug{std.stdio.writeln("match 23 finished");}

}
unittest {
  debug{std.stdio.writeln("match 24");}

  auto parser = *match("a");
  auto res = parser.parse("ab");
  assert(res.success);
  assert(res.rest == "b");
  debug{std.stdio.writeln("match 24 finished");}

}

unittest {
  debug{std.stdio.writeln("match 25");}

  auto parser = *(match("+") ~ match("-"));
  auto res = parser.parse("+-+-+");
  assert(res.success);
  assert(res.rest == "+");
  debug{std.stdio.writeln("match 25 finished");}

}
unittest {
  debug{std.stdio.writeln("match 26");}

  auto parser = *match("a", false);
  auto res = parser.parse("aaaa");
  assert(res.success);
  assert(res.rest.length == 0);
  assert(res.results.length == 0);
  debug{std.stdio.writeln("match 26 finished");}

}
unittest {
  debug {std.stdio.writeln("match 27");}

  auto parser = (*match("a")) ^^ (Variant[] input) {
    Variant v = input.length;
    return [v];
  };
  auto suc = parser.parseAll("aaaaa");
  assert(suc.success);
  assert(suc.results.length == 1);
  assert(suc.results[0].get!(ulong) == 5);
  debug {std.stdio.writeln("match 27 finished");}
}

unittest {
  debug{std.stdio.writeln("match 28");}

  auto parser = new Parser!(immutable(char)).RegexParser("abc");
  auto res = parser.parse("abcd");
  assert(res.success);
  assert(res.rest == "d");
  debug{std.stdio.writeln("match 28 finished");}
}
unittest {
  debug{std.stdio.writeln("match 29");}

  auto parser = new Parser!(immutable(char)).RegexParser("abc");
  auto res = parser.parse("babc");
  assert(!res.success);
  debug{std.stdio.writeln("match 29 finished");}

}
unittest {
  debug{std.stdio.writeln("match 30");}

  auto parser = new Parser!(immutable(char)).RegexParser("(.)(.)(.)");
  auto res = parser.parse("abc");
  assert(res.success);
  assert(res.results.length == 4);
  debug{std.stdio.writeln("match 30 finished");}

}

unittest {
  debug{std.stdio.writeln("match 31");}

  auto parser = new Parser!(immutable(char)).Number;
  auto res = parser.parse("123.123");
  assert(res.success);
  assert(res.results[0] == 123.123);
  debug{std.stdio.writeln("match 31 finished");}

}

unittest {
  debug{std.stdio.writeln("testing alnumparser");}
  auto parser = new Parser!(immutable(char)).AlnumParser;
  auto res = parser.parseAll("-Aa1234");
  assert(res.success);
  assert(res.results[0] == "-Aa1234");
  res = parser.parseAll("a1234");
  assert(res.success);
  debug{std.stdio.writeln("testing alnumparser finished");}
}

unittest {
  debug{std.stdio.writeln("match 33");}

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
  debug{std.stdio.writeln("match 33 finished");}

}

// expr -> term { + term }
// term -> factor { * factor }
// factor -> number | ( expr )
static class ExprParser {
  Parser!(immutable(char)) lazyExpr() {
    return lazyParser( &expr );
  }
  Parser!(immutable(char)) expr() {
    auto add = (term() ~ match("+", false) ~ term()) ^^ (Variant[] input) {
      return variantArray(input[0]+input[1]);
    };
    return add | term();
  }
  Parser!(immutable(char)) term() {
    auto mult = (factor() ~ match("*", false) ~ factor()) ^^ (Variant[] input) {
      return variantArray(input[0]*input[1]);
    };
    return mult | factor();
  }
  Parser!(immutable(char)) factor() {
    auto exprWithParens = match("(", false) ~ lazyExpr() ~ match(")", false);
    return new Parser!(immutable(char)).Number | exprWithParens;
  }
}

unittest {
  debug{std.stdio.writeln("match 34");}

  auto parser = new ExprParser;
  auto p = parser.expr();
  auto res = p.parse("1+2*3");
  assert(res.success);
  assert(res.results[0] == 7);
  debug{std.stdio.writeln("match 34 finished");}

}

unittest {
  debug{std.stdio.writeln("match 35");}

  auto parser = new ExprParser;
  auto p = parser.expr();
  auto res = p.parse("1*2+3");
  assert(res.success);
  assert(res.results[0] == 5);
  debug{std.stdio.writeln("match 35 finished");}

}

unittest {
  debug{std.stdio.writeln("match 36");}

  auto parser = match("a") | match("b");
  auto res = parser.parse("a");
  assert(res.success);

  res = parser.parse("b");
  assert(res.success);

  res = parser.parse("c");
  assert(!res.success);
  debug{std.stdio.writeln("match 36 finished");}

}

unittest {
  debug{std.stdio.writeln("match 37");}

  auto parser = match("a") ~ match("b");
  auto res = parser.parse("ab");
  assert(res.success);

  res = parser.parse("ac");
  assert(!res.success);
  debug{std.stdio.writeln("match 37 finished");}

}

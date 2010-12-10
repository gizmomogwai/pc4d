module pc.parser;

import std.stdio;
import std.array;
import std.ctype;
import std.string;
import std.conv;
import std.regex;
import std.variant;
import std.functional;

/// Parentclass for parse results
class Result {
}

/**
 * Class for successfull parsing.
 * use fResults to get to the results.
 * use fRest to get to the not consumed part of the input.
 */
class ParseSuccess : Result {
  string fRest;
  Variant[] fResults;
  this(string rest, Variant[] result) {
    fRest = rest;
    fResults = result;
  }
  @property string rest() {
    return fRest;
  }

  @property string rest(string rest) {
    return fRest = rest;
  }
  @property Variant[] results() {
    return fResults;
  }
}

/**
 * class for unsuccessfull parsing.
 */
class ParseError : Result {
  string fMessage;
  this(string message) {
    fMessage = message;
  }
  @property string message() {
    return fMessage;
  }
}


class Parser {
  Variant[] delegate(Variant[]) fCallable = null;

  static success(T...)(string rest, T args) {
    return new ParseSuccess(rest, variantArray(args));
  }

  Result parseAll(string s) {
    auto res = parse(s);
    if (typeid(res) == typeid(ParseSuccess)) {
      auto success = cast(ParseSuccess)(res);
      if ((success.rest is null) || (success.rest.length == 0)) {
        return res;
      } else {
        return new ParseError("string not completely consumed: " ~ success.rest);
      }
    } else {
      return res;
    }
  }

  Result parse(string s) {
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

  Result transform(Result result) {
    if (typeid(result) == typeid(ParseSuccess)) {
      auto success = cast(ParseSuccess)(result);
      return fCallable ? new ParseSuccess(success.rest, fCallable(success.results)) : result;
    } else {
      return result;
    }
  }

  static class Matcher : Parser {
    string fExpected;
    bool fCollect;
    this(string expected, bool collect=true) {
      fExpected = expected;
      fCollect = collect;
    }

    Result parse(string s) {
      if (s.indexOf(fExpected) == 0) {
        string rest = s[fExpected.length..$];
        if (fCollect) {
          return transform(success(rest, fExpected));
        } else {
          return success(rest);
        }
      } else {
        return new ParseError("Expected: '" ~ fExpected ~ "' but got '" ~ s ~ "'");
      }
    }

    unittest {
      auto parser = new Matcher("test");
      auto res = cast(ParseSuccess)(parser.parse("test"));
      assert(res !is null);
      assert(res.rest is null || res.rest.length == 0);
    }

    unittest {
      auto parser = new Matcher("test");
      auto res = cast(ParseError)(parser.parse("abc"));
      assert(res !is null);
    }

    unittest {
      auto parser = new Matcher("test");
      auto suc = cast(ParseSuccess)(parser.parse("test2"));
      assert(suc !is null);
      assert(suc.rest == "2");
      auto err = cast(ParseError)(parser.parseAll("test2"));
      assert(err !is null);
    }

    unittest {
      auto parser = new Matcher("test") ^^ (Variant[] objects) {
        auto res = objects;
        if (objects[0] == "test") {
          res[0] = "super";
        }
        return objects;
      };
      auto suc = cast(ParseSuccess)(parser.parse("test"));
      assert(suc.results[0] == "super");
    }
    unittest {
      auto parser = new Matcher("test", false);
      auto suc = cast(ParseSuccess)(parser.parseAll("test"));
      assert(suc !is null);
      assert(suc.results.length == 0);
    }

  }

  static class Alternative : Parser {
    Parser[] fParsers;

    this(Parser[] parsers ...) {
      fParsers = parsers.dup;
    }

    Result parse(string s) {
      foreach (parser; fParsers) {
        Result res = parser.parse(s);
        if (cast(ParseSuccess)(res) !is null) {
          return transform(res);
        }
      }
      return new ParseError("or did not match");
    }

    unittest {
      auto parser = new Alternative(new Matcher("ab"), new Matcher("cd"));
      auto res = cast(ParseSuccess)(parser.parse("ab"));
      assert(res !is null);
    }

    unittest {
      auto parser = new Alternative(new Matcher("ab"), new Matcher("cd"));
      auto res = cast(ParseSuccess)(parser.parse("cde"));
      assert(res !is null);
      assert(res.rest == "e");
    }
    unittest {
      auto parser = new Alternative(new Matcher("ab"), new Matcher("cd"));
      auto res = cast(ParseError)(parser.parse("ef"));
      assert(res !is null);
    }
    unittest {
      auto parser = new Alternative(new Matcher("ab"), new Matcher("cd")) ^^ (Variant[] input) {
        if (input[0] == "ab") {
          input[0] = "super";
        }
        return input;
      };
      auto suc = cast(ParseSuccess)(parser.parse("ab"));
      assert(suc.results[0] == "super");
      suc = cast(ParseSuccess)(parser.parse("cd"));
      assert(suc.results[0] == "cd");
    }
    unittest {
      auto parser = new Alternative(new Matcher("a", false), new Matcher("b"));
      auto res = cast(ParseSuccess)(parser.parse("ab"));
      assert(res !is null);
    }
  }

  static class Sequence : Parser {
    Parser[] fParsers;
    this(Parser[] parsers ...) {
      fParsers = parsers.dup;
    }

    Result parse(string s) {
      auto resultObjects = appender!(Variant[])();
      string h = s;
      foreach (parser; fParsers) {
        Result res = parser.parse(h);
        auto suc = cast(ParseSuccess)(res);
        auto err = cast(ParseError)(res);
        if (suc !is null) {
          h = suc.rest;
          resultObjects.put(suc.results);
        } else {
          return err;
        }
      }
      return transform(new ParseSuccess(h, resultObjects.data));
    }

    unittest {
      auto parser = new Sequence(new Matcher("a"), new Matcher("b") );
      auto res = cast(ParseSuccess)(parser.parse("ab"));
      assert(res !is null);
      assert(res.results.length == 2);
    }

    unittest {
      auto parser = new Sequence(new Matcher("a"), new Matcher("b"));
      auto res = cast(ParseSuccess)(parser.parse("abc"));
      assert(res !is null);
      assert(res.rest == "c");
    }

    unittest {
      auto parser = new Sequence(new Matcher("a"), new Matcher("b"));
      auto res = cast(ParseError)(parser.parse("ac"));
      assert(res !is null);
    }
    unittest {
      auto parser = new Sequence(new Matcher("a", false), new Matcher("b"));
      auto res = cast(ParseSuccess)(parser.parse("ab"));
      assert(res !is null);
    }

    unittest {
      auto parser = new Sequence(new Matcher("a"), new Matcher("b")) ^^ (Variant[] result) {
        string totalString;
        foreach (Variant o ; result) {
          if (o.type == typeid(string)) {
            totalString ~= o.get!(string);
          }
        }

        Variant v = totalString;
        return [v];
      };

      auto suc = cast(ParseSuccess)(parser.parse("ab"));
      assert(suc.results.length == 1);
      assert(suc.results[0] == "ab");
    }
  }

  static class Optional : Parser {

    Parser fParser;

    this(Parser parser) {
      fParser = parser;
    }

    Result parse(string s) {
      auto res = fParser.parse(s);
      if (cast(ParseError)(res) !is null) {
        return success(s);
      } else {
        return res;
      }
    }
    unittest {
      auto abc = new Matcher("abc");
      auto opt = new Optional(abc);
      auto res = cast(ParseSuccess)(opt.parse("abc"));
      assert(res !is null);
      assert(res.results.length == 1);
      assert(res.results[0] == "abc");
      assert(res.rest.length == 0);
    }
    unittest {
      auto abc = new Matcher("abc");
      auto opt = new Optional(abc);
      auto res = cast(ParseSuccess)(opt.parse("efg"));
      assert(res !is null);
      assert(res.results.length == 0);
      assert(res.rest == "efg");
    }
    unittest {
      auto abc = new Matcher("+");
      auto def = new Integer;
      auto test = new Optional(new Sequence(abc, def));
      auto res = cast(ParseSuccess)(test.parse("+1"));
      assert(res !is null);
      assert(res.results.length == 2);
    }
    unittest {
      auto ab = -match("a") ~ match("b");
      auto suc = cast(ParseSuccess)(ab.parse("ab"));
      assert(suc !is null);
      suc = cast(ParseSuccess)(ab.parse("b"));
      assert(suc !is null);
      auto err = cast(ParseError)(ab.parse("c"));
      assert(suc !is null);
    }
  }


  static class Repetition : Parser {
    Parser fToRepeat;
    this(Parser toRepeat) {
      fToRepeat = toRepeat;
    }

    Result parse(string s) {
      auto results = appender!(Variant[])();
      auto rest = s;
      while (true) {
        auto res = fToRepeat.parse(rest);
        auto suc = cast(ParseSuccess)(res);
        if (suc !is null) {
          rest = suc.rest;
          results.put(suc.results);
          /*
          	  foreach (result ; suc.results) {
          	    results.put(result);
          	  }
          */
        } else {
          break;
        }
      }
      return transform(new ParseSuccess(rest, results.data));
    }

    unittest {
      auto parser = new Repetition(new Matcher("a"));
      auto res = cast(ParseSuccess)(parser.parse("aa"));
      assert(res !is null);
      assert(res.rest == "");
      assert(res.results.length == 2);
    }
    unittest {
      auto parser = new Repetition(new Matcher("a"));
      auto res = cast(ParseSuccess)(parser.parse("b"));
      assert(res !is null);
      assert(res.rest == "b");
    }
    unittest {
      auto parser = new Repetition(new Matcher("a"));
      auto res = cast(ParseSuccess)(parser.parse("ab"));
      assert(res !is null);
      assert(res.rest == "b");
    }

    unittest {
      auto parser = new Repetition(new Sequence(new Matcher("+"), new Matcher("-")));
      auto res = cast(ParseSuccess)(parser.parse("+-+-+"));
      assert(res !is null);
      assert(res.rest == "+");
    }
    unittest {
      auto parser = new Repetition(new Matcher("a", false));
      auto res = cast(ParseSuccess)(parser.parse("aaaa"));
      assert(res !is null);
      assert(res.rest.length == 0);
      assert(res.results.length == 0);
    }
    unittest {
      auto parser = new Repetition(new Matcher("a")) ^^ (Variant[] input) {
        Variant v = input.length;
        return [v];
      };
      auto suc = cast(ParseSuccess)(parser.parseAll("aaaaa"));
      assert(suc.results.length == 1);
      assert(suc.results[0].get!(long) == 5);
    }

    unittest {
      auto parser = (*match("a")) ^^ (Variant[] input) {
        Variant v = input.length;
	return [v];
      };
      auto suc = cast(ParseSuccess)(parser.parseAll("aaaaa"));
      assert(suc.results.length == 1);
      assert(suc.results[0].get!(long) == 5);
    }
  }

  unittest {
    auto text = "abc";
    auto m1 = std.regex.match(text, "d");
    assert(m1.empty());
    m1 = std.regex.match(text, "a");
    assert(!m1.empty());
  }

  static class RegexParser : Parser {
    string fRegex;
    this(string regex) {
      fRegex = regex;
    }

    Result parse(string s) {
      auto res = std.regex.match(s, regex(fRegex));
      if (res.empty()) {
        return new ParseError("did not match " ~ fRegex);
      } else if (res.pre.length > 0) {
        return new ParseError("did not match " ~ fRegex);
      } else {
        auto results = appender!(Variant[])();
        foreach (c; res.captures) {
          Variant v = c;
          results.put(v);
        }
        return transform(new ParseSuccess(res.post, results.data));
      }
    }
    unittest {
      auto parser = new RegexParser("abc");
      auto suc = cast(ParseSuccess)(parser.parse("abcd"));
      assert(suc !is null);
      assert(suc.rest == "d");
    }
    unittest {
      auto parser = new RegexParser("abc");
      auto err = cast(ParseError)(parser.parse("babc"));
      assert(err !is null);
    }
    unittest {
      auto parser = new RegexParser("(.)(.)(.)");
      auto res = cast(ParseSuccess)(parser.parse("abc"));
      assert(res.results.length == 4);
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
    unittest {
      Parser parser = new Number;
      assert(parser !is null);
      auto suc = cast(ParseSuccess)(parser.parse("123.123"));
      assert(suc !is null);
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
      super(r"\w[\w\d]*") ^^ (Variant[] input) {
        return variantArray(input[0]);
      };
    }
  }
  unittest {
    auto parser = new AlnumParser;
    auto suc = cast(ParseSuccess)(parser.parse("a1234"));
    assert(suc !is null);
    assert(suc.results[0] == "a1234");
  }
  static class LazyParser : Parser {
    Parser delegate() fCallable;

    this(Parser delegate() parser) {
      assert(parser != null);
      fCallable = parser;
    }

    this(Parser function() parser) {
      assert(parser != null);
      fCallable = toDelegate(parser);
    }

    Result parse(string s) {
      auto parser = fCallable();
      return transform(parser.parse(s));
    }

    unittest {
      class Endless {
        // endless -> a | a opt(endless)
        Parser lazyEndless() {
          return new LazyParser( &endless );
        }
        Parser endless() {
          return new Alternative(new Sequence(match("a"), new Optional(lazyEndless()), match("a")));
        }
      }
      auto parser = new Endless;
      auto p = parser.endless();
      auto suc = cast(ParseSuccess)(p.parse("aa"));
      assert(suc !is null);
      suc = cast(ParseSuccess)(p.parse("aab"));
      assert(suc !is null);
      assert(suc.rest == "b");
    }
  }

  // expr -> term { + term }
  // term -> factor { * factor }
  // factor -> number | ( expr )
  static class ExprParser {
    Parser lazyExpr() {
      return new LazyParser( {return expr();} );
    }
    Parser expr() {
      auto add = (term() ~ match("+", false) ~ term()) ^^ (Variant[] input) {
        return variantArray(input[0]+input[1]);
      };
      return add | term();
    }
    Parser term() {
      auto mult = (factor() ~ match("*", false) ~ factor()) ^^ (Variant[] input) {
        return variantArray(input[0]*input[1]);
      };
      return mult | factor();
    }
    Parser factor() {
      auto exprWithParens = match("(", false) ~ lazyExpr() ~ match(")", false);
      return new Number | exprWithParens;
    }
  }

  unittest {
    auto parser = new ExprParser;
    auto p = parser.expr();
    auto res = cast(ParseSuccess)(p.parse("1+2*3"));
    assert(res !is null);
    assert(res.results[0] == 7);
  }

  unittest {
    auto parser = new ExprParser;
    auto p = parser.expr();
    auto res = cast(ParseSuccess)(p.parse("1*2+3"));
    assert(res !is null);
    assert(res.results[0] == 5);
  }

  unittest {
    Parser parser = match("a") | match("b");
    Result res = parser.parse("a");
    assert(res !is null);

    auto suc = cast(ParseSuccess)(res);
    assert(suc !is null);

    res = parser.parse("b");
    assert(res !is null);

    suc = cast(ParseSuccess)(res);
    assert(suc !is null);

    res = parser.parse("c");
    assert(res !is null);
    auto err = cast(ParseError)(res);
    assert(err !is null);
  }

  unittest {
    auto parser = match("a") ~ match("b");
    auto suc = cast(ParseSuccess)(parser.parse("ab"));
    assert(suc !is null);

    auto err = cast(ParseError)(parser.parse("ac"));
    assert(err !is null);
  }

}

Parser match(string s, bool collect=true) {
  return new Parser.Matcher(s, collect);
}

unittest {
  auto parser = match("test");
  ParseSuccess suc = cast(ParseSuccess)(parser.parseAll("test"));
  assert(suc !is null);
}


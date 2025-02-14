/++
 + Copyright: Copyright © 2015, Christian Köstlin
 + License: MIT
 + Authors: Christian Koestlin, Christian Köstlin
 +/

module pc4d.parsers;

import pc4d.parser : Parser, ParseResult;
import std.array : appender;
import std.conv : to;
import std.functional : toDelegate;
import std.regex : stdMatch = match, stdRegex = regex;
import std.variant : Variant, variantArray;

version (unittest)
{
    import unit_threaded;
}

/// convenient function to instantiate a AlphaNumericParser
auto alnum(T)(bool collect = true)
{
    return new Regex(`-?\w[\w\d]*`, collect) ^^ (data) {
        return variantArray(data[0]);
    };
}

/// the alnum parser
@("alnum parser") unittest
{
    auto parser = alnum!(immutable(char))();
    auto res = parser.parseAll("-Aa1234");
    res.success.should == true;
    res.results[0].should == "-Aa1234";
    res = parser.parseAll("a1234");
    res.success.should == true;
}

/// class for matching alternatives
class Alternative(T) : Parser!(T)
{
    Parser!(T)[] fParsers;

    this(Parser!(T)[] parsers...)
    {
        fParsers = parsers.dup;
    }

    override ParseResult!(T) parse(T[] s)
    {
        foreach (parser; fParsers)
        {
            auto res = parser.parse(s);
            if (res.success)
            {
                return transform(res);
            }
        }
        return ParseResult!(T).error("or did not match");
    }
}

/// convenient function
Parser!(T) or(T)(Parser!(T)[] parsers...)
{
    return new Alternative!(T)(parsers);
}

/// showing off the or dsl
@("or dsl") unittest
{
    auto parser = or(match("a"), match("b"), match("c"));
    parser.parse("a").success.should == true;
    parser.parse("b").success.should == true;
    parser.parse("c").success.should == true;
}

/// parser for blockcomments
static class BlockComment(T) : Parser!(T)
{
    T[] fStart;
    T[] fEnd;
    bool fCollect;
    this(T[] startString, T[] endString, bool collect = true)
    {
        fStart = startString;
        fEnd = endString;
        fCollect = collect;
    }

    bool startsWith(T[] aInput, ulong startIdx, T[] expected)
    {
        T[] slice = aInput[startIdx .. $];
        if (slice.length < expected.length)
        {
            return false;
        }
        for (int i = 0; i < expected.length; i++)
        {
            if (slice[i] != expected[i])
            {
                return false;
            }
        }
        return true;
    }

    override ParseResult!(T) parse(T[] s)
    {
        if (startsWith(s, 0, fStart))
        {
            auto l = fStart.length;
            for (auto i = l; i < s.length; i++)
            {
                if (startsWith(s, i, fEnd))
                {
                    auto lastIdx = i + fEnd.length;
                    auto rest = s[lastIdx .. $];
                    if (fCollect)
                    {
                        auto matched = s[0 .. lastIdx];
                        return transform(success(rest, matched));
                    }
                    else
                    {
                        return success(rest);
                    }
                }
            }
            return ParseResult!(T).error("");
        }
        else
        {
            return ParseResult!(T).error("");
        }
    }
}

/// convenient function
Parser!(T) blockComment(T)(T[] startString, T[] endString, bool collect = true)
{
    return new BlockComment!(T)(startString, endString, collect);
}

/// blockComment can collect the comment itself
@("block comment - catch comment") unittest
{
    auto parser = blockComment("/*", "*/", true);
    auto res = parser.parseAll("/*abc*/");
    res.success.should == true;
    res.fResults[0].should == "/*abc*/";
}

/// blockComment can also throw the comment away
@("block comment - discard comment") unittest
{
    auto parser = blockComment("/*", "*/", false);
    auto res = parser.parseAll("/*abc*/");
    res.success.should == true;
    res.fResults.length.should == 0;
}

/++ example of an expression parser.
 + expr -> term { + term }
 + term -> factor { * factor }
 + factor -> number | ( expr )
 +/
static class ExprParser
{
    Parser!(immutable(char)) lazyExpr()
    {
        return lazyParser(&expr);
    }

    Parser!(immutable(char)) expr()
    {
        auto add = (term() ~ match("+", false) ~ term()) ^^ (input) {
            return variantArray(input[0] + input[1]);
        };
        return add | term();
    }

    Parser!(immutable(char)) term()
    {
        auto mult = (factor() ~ match("*", false) ~ factor()) ^^ (input) {
            return variantArray(input[0] * input[1]);
        };
        return mult | factor();
    }

    Parser!(immutable(char)) factor()
    {
        auto exprWithParens = match("(", false) ~ lazyExpr() ~ match(")", false);
        return number!(immutable(char))() | exprWithParens;
    }
}

/// a simple expression parser
@("expression example") unittest
{
    auto parser = new ExprParser;
    auto p = parser.expr();
    auto res = p.parse("1+2*3");
    res.success.should == true;
    res.results[0].get!double.should == 7;

    res = p.parse("(1+2)*3");
    res.success.should == true;
    res.results[0].get!double.should == 9;
}

/// parser for parsing ints
static class Integer : Regex
{
    this()
    {
        super(r"\d+") ^^ (input) {
            return variantArray(input[0].get!string
                    .to!int);
        };
    }
}

/// convenience function to create an integer parser
Parser!(T) integer(T)()
{
    return new Integer;
}

/// unittests for integer
@("integer") unittest
{
    auto parser = integer!(immutable(char));
    auto res = parser.parse("123");
    res.success.should == true;
    res.results[0].should == 123;
}

/++
 + convenient function to build a parser that kills the result of
 + another parser e.g. killResults(match("a")) succeeds, but returns
 + an empty result
 +/
Parser!(T) killResults(T)(Parser!(T) parser)
{
    return parser ^^ (Variant[] input) { Variant[] res; return res; };
}

/// unittests for kill results
@("killResults") unittest
{
    auto res = killResults(match("a")).parse("a");
    res.success.should == true;
    res.results.length.should == 0;
}

/++
 + this parser is needed to build recursive parser hierarchies.
 + look for expression.d for a more realistic example than in the unittest
 +/
class Lazy(T) : Parser!(T)
{
    Parser!(T) delegate() fCallable;

    this(Parser!(T) delegate() parser)
    {
        assert(parser != null);
        fCallable = parser;
    }

    this(Parser!(T) function() parser)
    {
        assert(parser != null);
        fCallable = toDelegate(parser);
    }

    override ParseResult!(T) parse(T[] s)
    {
        auto parser = fCallable();
        return transform(parser.parse(s));
    }

}

/// convenient function to instantiate a lazy parser with a delegate
Parser!(T) lazyParser(T)(Parser!(T) delegate() parser)
{
    return new Lazy!(T)(parser);
}

/// convenient function to instantiate a lazy parser with a function
Parser!(T) lazyParser(T)(Parser!(T) function() parser)
{
    return new Lazy!(T)(parser);
}

/// unittest to show the simplest usage of lazy
@("lazy") unittest
{
    // endless -> a | a opt(endless)
    struct Endless
    {
        static Parser!(immutable(char)) lazyEndless()
        {
            return lazyParser!(immutable(char))(&parser);
        }

        static Parser!(immutable(char)) parser()
        {
            return match("a") ~ (-(lazyEndless()));
        }
    }

    auto p = Endless.parser();
    auto res = p.parse("aa");
    res.success.should == true;
    res.results.should == ["a", "a"];

    res = p.parse("aab");
    res.success.should == true;
    res.results.should == ["a", "a"];
    res.rest.should == "b";
}

/// class for matching an array exactly
class Match(T) : Parser!(T)
{
    T[] fExpected;
    bool fCollect;
    this(T[] expected, bool collect = true)
    {
        fExpected = expected;
        fCollect = collect;
    }

    bool startsWith(T[] aInput, T[] expected)
    {
        if (aInput.length < expected.length)
        {
            return false;
        }
        for (int i = 0; i < expected.length; i++)
        {
            if (aInput[i] != expected[i])
            {
                return false;
            }
        }
        return true;
    }

    override ParseResult!(T) parse(T[] s)
    {
        if (startsWith(s, fExpected))
        {
            auto rest = s[fExpected.length .. $];
            if (fCollect)
            {
                return transform(success(rest, fExpected));
            }
            else
            {
                return success(rest);
            }
        }
        else
        {
            return ParseResult!(T).error(""); //"Expected: '" ~ fExpected ~ "' but got '" ~ s ~ "'");
        }
    }
}

/// convenient function to instantiate a matcher
Parser!(T) match(T)(T[] s, bool collect = true)
{
    return new Match!(T)(s, collect);
}

/// matching a string
@("match") unittest
{
    auto parser = match("test");
    auto res = parser.parseAll("test");

    res.success.should == true;
    res.rest.length.should == 0;
}

@("match 2") unittest
{
    auto parser = match("test");
    auto res = parser.parse("test2");
    res.success.should == true;
    res.rest.should == "2";

    res = parser.parseAll("test2");
    res.success.should == false;
}

/// transform match result
@("match + transform") unittest
{
    auto parser = match("test") ^^ (objects) {
        auto res = objects;
        if (objects[0] == "test")
        {
            res[0] = "super";
        }
        return objects;
    };
    auto res = parser.parse("test");
    res.success.should == true;
    res.results[0].should == "super";
}

@("match - discard") unittest
{
    auto parser = match("test", false);
    auto res = parser.parseAll("test");
    res.success.should == true;
    res.results.length.should == 0;
}

@("match on arrays") unittest
{
    auto parser = match([1, 2, 3]);
    auto res = parser.parseAll([1, 2, 3]);
    res.success.should == true;
    res.results.length.should == 1;
    res.results[0].should == [1, 2, 3];
}

/// convenient function to instantiate a number parser
Parser!(T) number(T)()
{
    return new Regex(r"[-+]?[0-9]*\.?[0-9]+") ^^ (Variant[] input) {
        auto output = appender!(Variant[])();
        foreach (Variant o; input)
        {
            auto s = o.get!(string);
            auto h = s.to!(double);
            Variant v = h;
            output.put(v);
        }
        return output.data;
    };
}

/// unittests for number parser
@("number parser") unittest
{
    auto parser = number!(immutable(char))();
    auto res = parser.parse("123.123");
    res.success.should == true;
    res.results[0].should == 123.123;
}

/// class for matching something optional
class Optional(T) : Parser!(T)
{
    Parser!(T) fParser;

    this(Parser!(T) parser)
    {
        fParser = parser;
    }

    override ParseResult!(T) parse(T[] s)
    {
        auto res = fParser.parse(s);
        if (!res.success)
        {
            return success(s);
        }
        else
        {
            return res;
        }
    }
}

/// unittests to show the usage of OptionalParser and its dsl '-'
@("optional and dsl") unittest
{
    auto abc = match("abc");
    auto opt = -abc;
    auto res = opt.parse("abc");
    res.success.should == true;
    res.results.length.should == 1;
    res.results[0].should == "abc";
    res.rest.length.should == 0;
}

/// unittest to show optional in action.
@("optional") unittest
{
    auto abc = match("abc");
    auto opt = -abc;
    auto res = opt.parse("efg");
    auto withoutOptional = abc.parse("efg");
    withoutOptional.success.should == false;
    res.success.should == true;
    res.results.length.should == 0;
    res.rest.should == "efg";
}

/// parse a number with or without sign
@("parse number with or without +") unittest
{
    auto sign = match("+");
    auto value = match("1");
    auto test = (-sign) ~ value;
    auto resWithSign = test.parse("+1");
    resWithSign.success.should == true;
    resWithSign.results.length.should == 2;
    auto resWithoutSign = test.parse("1");
    resWithoutSign.success.should == true;
}

/++
 + parser for regular expressions
 + a successful parse step returns all captures in an array
 +/
class Regex : Parser!(immutable(char))
{
    string fRegex;
    bool fCollect;
    this(string regex, bool collect = true)
    {
        fRegex = regex;
        fCollect = collect;
    }

    override ParseResult!(immutable(char)) parse(string s)
    {
        auto res = s.stdMatch(stdRegex(fRegex));
        if (res.empty())
        {
            return ParseResult!(immutable(char)).error(s ~ "did not match " ~ fRegex);
        }
        else if (res.pre.length > 0)
        {
            return ParseResult!(immutable(char)).error(s ~ "did not match " ~ fRegex);
        }
        else
        {
            if (fCollect)
            {
                auto results = appender!(Variant[])();
                foreach (c; res.captures)
                {
                    Variant v = c;
                    results.put(v);
                }
                return transform(ParseResult!(immutable(char)).ok(res.post, results.data));
            }
            else
            {
                return success(res.post);
            }
        }
    }
}

/// convenient function to instantiate a regexparser
Parser!(T) regex(T)(T[] s, bool collect = true)
{
    return new Regex(s, collect);
}

/// regexParser
@("regex parser") unittest
{
    auto res = regex("(a)(.)(c)").parse("abcd");
    res.success.should == true;
    res.results.should == ["abc", "a", "b", "c"];
    res.rest.shouldEqual("d");
}

/// regexParser works from the start of the input
@("regex parser parses from start") unittest
{
    auto res = regex("abc").parse("babc");
    res.success.shouldBeFalse;
}

/// class for matching repetitions
static class Repetition(T) : Parser!(T)
{
    Parser!(T) fToRepeat;
    this(Parser!(T) toRepeat)
    {
        fToRepeat = toRepeat;
    }

    override ParseResult!(T) parse(T[] s)
    {
        Variant[] results;
        auto rest = s;
        while (true)
        {
            auto res = fToRepeat.parse(rest);
            if (res.success)
            {
                rest = res.rest;
                results = results ~ res.results;
            }
            else
            {
                break;
            }
        }
        return transform(ParseResult!(T).ok(rest, results));
    }
}

/// unittest for repetition
@("repetition more than one") unittest
{
    auto parser = *match("a");
    auto res = parser.parse("aa");
    res.success.shouldBeTrue;
    res.rest.shouldEqual("");
    res.results.length.shouldEqual(2);
}

@("repetition none") unittest
{
    auto parser = *match("a");
    auto res = parser.parse("b");
    res.success.shouldBeTrue;
    res.rest.shouldEqual("b");
}

@("repetition with rest") unittest
{
    auto parser = *match("a");
    auto res = parser.parse("ab");
    res.success.shouldBeTrue;
    res.rest.shouldEqual("b");
}

@("repetition with other parser") unittest
{
    auto parser = *(match("+") ~ match("-"));
    auto res = parser.parse("+-+-+");
    res.success.shouldBeTrue;
    res.rest.shouldEqual("+");
}

@("repetition discarding result") unittest
{
    auto parser = *match("a", false);
    auto res = parser.parse("aaaa");
    res.success.shouldBeTrue;
    res.rest.length.shouldEqual(0);
    res.results.length.shouldEqual(0);
}

@("repetition transforming result") unittest
{
    auto parser = (*match("a")) ^^ (input) { return variantArray(input.length); };
    auto suc = parser.parseAll("aaaaa");
    suc.success.shouldBeTrue;
    suc.results.length.shouldEqual(1);
    suc.results[0].get!(ulong).shouldEqual(5);
}

/// class for matching sequences
class Sequence(T) : Parser!(T)
{
    Parser!(T)[] fParsers;
    this(Parser!(T)[] parsers...)
    {
        fParsers = parsers.dup;
    }

    override ParseResult!(T) parse(T[] s)
    {
        auto resultObjects = appender!(Variant[])();
        T[] h = s;
        foreach (parser; fParsers)
        {
            auto res = parser.parse(h);
            if (res.success)
            {
                h = res.rest;
                resultObjects.put(res.results);
            }
            else
            {
                return res;
            }
        }
        return transform(ParseResult!(T).ok(h, resultObjects.data));
    }
}

/// convenient function
Parser!(T) sequence(T)(Parser!(T)[] parsers...)
{
    return new Sequence!(T)(parsers);
}

/// unittests showing usage of sequence parser and dsl '~'
@("sequence") unittest
{
    auto parser = match("a") ~ match("b");
    auto res = parser.parse("ab");
    res.success.shouldBeTrue;
    res.results.length.shouldEqual(2);
}

@("sequence and rest") unittest
{
    auto parser = match("a") ~ "b".match;
    auto res = parser.parse("abc");
    res.success.shouldBeTrue;
    res.rest.shouldEqual("c");
}

@("sequence fails") unittest
{
    auto parser = match("a") ~ match("b");
    auto res = parser.parse("ac");

    res.success.shouldBeFalse;
}

@("sequence with discard result") unittest
{
    auto parser = match("a", false) ~ match("b");
    auto res = parser.parse("ab");
    res.success.shouldBeTrue;
    res.results.length.shouldEqual(1);
}

@("sequence with transformation") unittest
{
    auto parser = (match("a") ~ match("b")) ^^ (Variant[] result) {
        string totalString;
        foreach (Variant o; result)
        {
            if (o.type == typeid(string))
            {
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

@("sequence and optional") unittest
{
    auto ab = -match("a") ~ match("b");
    auto res = ab.parse("ab");
    res.success.shouldBeTrue;
    res = ab.parse("b");
    res.success.shouldBeTrue;
    res = ab.parse("c");
    res.success.shouldBeFalse;
    res = ab.parse("");
    res.success.shouldBeFalse;
}

@("sequence api not dsl") unittest
{
    auto ab = sequence(match("a"), match("b"));
    auto res = ab.parse("ab");
    res.success.shouldBeTrue;
}

@("sequence api") unittest
{
    auto ab = sequence(match("a"), match("b"), match("c"));
    auto res = ab.parse("abc");
    res.success.shouldBeTrue;
}

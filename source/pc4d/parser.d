/++
 + Module defining the base for all parser combinators.
 +
 + Copyright: Copyright © 2015, Christian Köstlin
 + License: MIT
 + Authors: Christian Koestlin, Christian Köstlin
 +/
module pc4d.parser;

import pc4d.parsers : or, sequence, regex, match, Optional, Repetition;
import std.conv : to;
import std.functional : toDelegate;
import std.variant : Variant, variantArray;

version (unittest)
{
    import unit_threaded;
}

/**
 * Result of a parsing step.
 * use fResults to get to the results.
 * use fRest to get to the not consumed part of the input.
 */
class ParseResult(T)
{
    T[] fRest;
    Variant[] fResults;
    string fMessage;
    bool fSuccess;

    private this(bool success)
    {
        fRest = null;
        fResults = null;
        fMessage = null;
        fSuccess = success;
    }

    public static ParseResult!(T) ok(T[] rest, Variant[] results)
    {
        auto res = new ParseResult!(T)(true);
        res.fRest = rest;
        res.fResults = results;
        return res;
    }

    public static ParseResult!(T) error(string message)
    {
        auto res = new ParseResult!(T)(false);
        res.fMessage = message;
        return res;
    }

    /// errormessage
    @property string message()
    {
        return fMessage;
    }

    /// true if parsing was successfull
    @property bool success()
    {
        return fSuccess;
    }

    /// unconsumed input
    @property T[] rest()
    {
        return fRest;
    }

    @property T[] rest(T[] rest)
    {
        return fRest = rest;
    }

    /// the results
    @property Variant[] results()
    {
        if (!success)
        {
            throw new Exception("no results available rest: " ~ fMessage);
        }
        return fResults;
    }
}

/**
 * interface for all parser combinators
 * parse must be implemented.
 */
class Parser(T)
{
    Variant[]delegate(Variant[]) fCallable = null;

    /// helper to create a successfull result
    static success(U...)(T[] rest, U args)
    {
        return ParseResult!(T).ok(rest, variantArray(args));
    }

    ParseResult!(T) parseAll(T[] s)
    {
        auto res = parse(s);
        if (res.success)
        {
            if ((res.rest is null) || (res.rest.length == 0))
            {
                return res;
            }
            else
            {
                return ParseResult!(T).error("string not completely consumed" /*, res.rest*/ );
            }
        }
        else
        {
            return res;
        }
    }

    /++
   + this must be implemented by subclasses
   + Params:
   +   input = the data to process
   + Returns: ParseResult with (success, result and rest) or (not success and optional error message)
   +/
    ParseResult!(T) parse(T[] input)
    {
        throw new Exception("must be implemented in childs");
    }

    /// dsl for repetition of a parser e.g. (*match("a")) matches sequences of a
    Parser opUnary(string op)() if (op == "*")
    {
        return new Repetition!(T)(this);
    }

    /// dsl for optional parser e.g. (-match("abc")) matches "abc" and "efg"
    Parser opUnary(string op)() if (op == "-")
    {
        return new Optional!(T)(this);
    }

    /// dsl for transforming results of a parser
    Parser opBinary(string op)(Variant[]delegate(Variant[] objects) toCall)
            if (op == "^^")
    {
        return setCallback(toCall);
    }

    /// dsl for transforming results of a parser
    Parser opBinary(string op)(Variant[]function(Variant[] objects) toCall)
            if (op == "^^")
    {
        return setCallback(toCall);
    }

    /// dsl for alternatives e.g. match("abc") | match("def") matches "abc" or "def"
    Parser opBinary(string op)(Parser rhs) if (op == "|")
    {
        return or(this, rhs);
    }

    /// dsl for sequences e.g. match("a") ~ match("b") matches "ab"
    Parser opBinary(string op)(Parser rhs) if (op == "~")
    {
        return sequence(this, rhs);
    }

    Parser setCallback(Variant[]function(Variant[] objects) tocall)
    {
        fCallable = toDelegate(tocall);
        return this;
    }

    Parser setCallback(Variant[]delegate(Variant[] objects) tocall)
    {
        fCallable = tocall;
        return this;
    }

    ParseResult!(T) transform(ParseResult!(T) result)
    {
        if (result.success)
        {
            return fCallable ? ParseResult!(T).ok(result.rest, fCallable(result.results)) : result;
        }
        else
        {
            return result;
        }
    }

}

/// transforming from regexp string to integer
@("regexp to integer") unittest
{
    auto res = (regex("\\d+") ^^ (input) {
        return variantArray(input[0].get!string.to!int);
    }).parse("123");
    res.success.should == true;
    res.results[0].should == 123;
}

/// the pc4d.alternative parser and its dsl '|'
@("alternative dsl") unittest
{
    auto parser = match("abc") | match("def");
    auto res = parser.parse("abc");
    res.success.should == true;

    res = parser.parse("def");
    res.success.should == true;

    res = parser.parse("ghi");
    res.success.should == false;
}

/// trying to parse all of the input
@("parseAll") unittest
{
    auto parser = match("test");
    auto res = parser.parseAll("test");

    res.success.should == true;
    res.rest.length.should == 0;

    res = parser.parseAll("test1");
    res.success.should == false;
}

/// trying to parse part of the input
@("parse") unittest
{
    auto parser = match("test");
    auto res = parser.parse("test");

    res.success.should == true;
    res.rest.length.should == 0;

    res = parser.parse("test1");
    res.success.should == true;

    res.rest.should == "1";
}

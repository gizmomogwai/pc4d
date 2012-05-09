module pc.parser;

public import pc.convenience;
import std.string;
import std.stdio;
import std.array;
import std.ascii;
import std.string;
import std.conv;
public import std.variant;
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

  ///
  @property bool success() {
    return fSuccess;
  }

  ///
  @property T[] rest() {
    return fRest;
  }

  @property T[] rest(T[] rest) {
    return fRest = rest;
  }

  /// the results
  @property Variant[] results() {
    if (!success) {
      throw new Exception("no results available");
    }
    return fResults;
  }
}

/** interface for all parser combinators
 * parse must be implemented
 */
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

  /// this must be implemented by subclasses
  ParseResult!(T) parse(T[] s) {
    throw new Exception("must be implemented in childs");
  }

  /// dsl for repetition of a parser e.g. (*match("a")) matches sequences of a
  Parser opUnary(string op)() if (op == "*") {
    return new Repetition!(T)(this);
  }
  /// dsl for optional parser e.g. (-match("abc")) matches "abc" and "efg"
  Parser opUnary(string op)() if (op == "-") {
    return new Optional!(T)(this);
  }

  /// dsl for transforming results of a parser e.g. RegexParser("\d+") ^^ (input) { return variantArray(42); } returns always 42 if a number was parsed
  Parser opBinary(string op)(Variant[] function(Variant[] objects) toCall) if (op == "^^") {
    return setCallback(toCall);
  }

  /// dsl for alternatives e.g. match("abc") | match("def") matches "abc" or "def"
  Parser opBinary(string op)(Parser rhs) if (op == "|") {
    return or(this, rhs);
  }

  /// dsl for sequences e.g. match("a") ~ match("b") matches "ab"
  Parser opBinary(string op)(Parser rhs) if (op == "~") {
    return sequence(this, rhs);
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

}

module pc4d.expression;

import pc4d.parser;
import pc4d.number;

/++ example of an expression parser.
 + expr -> term { + term }
 + term -> factor { * factor }
 + factor -> number | ( expr )
 +/
static class ExprParser {
  Parser!(immutable(char)) lazyExpr() {
    return lazyParser( &expr );
  }
  Parser!(immutable(char)) expr() {
    auto add = (term() ~ match("+", false) ~ term()) ^^ (input) {
      return variantArray(input[0]+input[1]);
    };
    return add | term();
  }
  Parser!(immutable(char)) term() {
    auto mult = (factor() ~ match("*", false) ~ factor()) ^^ (input) {
      return variantArray(input[0]*input[1]);
    };
    return mult | factor();
  }
  Parser!(immutable(char)) factor() {
    auto exprWithParens = match("(", false) ~ lazyExpr() ~ match(")", false);
    return number!(immutable(char))() | exprWithParens;
  }
}

/// a simple expression parser
unittest {
  import unit_threaded;

  auto parser = new ExprParser;
  auto p = parser.expr();
  auto res = p.parse("1+2*3");
  res.success.shouldBeTrue;
  res.results[0].get!double.shouldEqual(7);

  res = p.parse("(1+2)*3");
  res.success.shouldBeTrue;
  res.results[0].get!double.shouldEqual(9);
}

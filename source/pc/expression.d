module pc.expression;
import pc.parser;
import pc.number;

/** example of an expression parser.
 * expr -> term { + term }
 * term -> factor { * factor }
 * factor -> number | ( expr )
 */
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
    return number!(immutable(char))() | exprWithParens;
  }
}

/// unittest for the expression parser
unittest {
  auto parser = new ExprParser;
  auto p = parser.expr();
  auto res = p.parse("1+2*3");
  assert(res.success);
  assert(res.results[0] == 7);
  res = p.parse("(1+2)*3");
  assert(res.success);
  assert(res.results[0] == 9);
}

module pc4d.number;

import pc4d.parser;
import std.array;
import pc4d.regexparser;

/// parser for parsing floats
class Number : RegexParser {
  this() {
    super(r"[-+]?[0-9]*\.?[0-9]+") ^^ (Variant[] input) {
      auto output = appender!(Variant[])();
      foreach (Variant o ; input) {
	string s = o.get!(string);
	double h = std.conv.to!(double)(s);
	Variant v = h;
	output.put(v);
      }
      return output.data;
    };
  }
}


/// convenient function to instantiate a number parser
Parser!(T) number(T)() {
  return new Number();
}

/// unittests for number parser
unittest {
  auto parser = number!(immutable(char))();
  auto res = parser.parse("123.123");
  assert(res.success);
  assert(res.results[0] == 123.123);
}

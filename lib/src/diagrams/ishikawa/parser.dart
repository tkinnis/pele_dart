// Upstream: src/diagrams/ishikawa/parser.ts

import '../../errors.dart';
import 'db.dart';
import 'lexer.dart';

const String _stop = "'SPACELINE', 'NL', 'EOF'";

// Follows the parser Jison builds from Mermaid's grammar: blank lines and comments may come first,
// then the keyword and at most one line break, then statements. A statement is a line of text,
// with or without indentation, or a blank line; each is ended by a blank line, a line break or
// the end of the text, and any number of line breaks after that.
void parseIshikawa(String src, IshikawaDb db) {
  final tok = tokenize(src);
  final types = tok.types;
  final starts = tok.starts;
  final ends = tok.ends;
  var i = 0;

  Never fail(String expected) {
    throw syntaxError(
      'ishikawa',
      src,
      starts[i],
      "Expecting $expected, got '${TOKEN_NAMES[types[i]]}'",
    );
  }

  if (types[i] == T.SPACELINE) {
    i++;
    while (types[i] == T.SPACELINE || types[i] == T.NL) {
      i++;
    }
    if (types[i] != T.ISHIKAWA) fail("'SPACELINE', 'NL', 'ISHIKAWA'");
  } else if (types[i] != T.ISHIKAWA) {
    fail("'SPACELINE', 'ISHIKAWA'");
  }
  i++;
  if (types[i] == T.NL) i++;

  for (;;) {
    final type = types[i];
    if (type == T.TEXT || (type == T.SPACELIST && types[i + 1] == T.TEXT)) {
      final text = type == T.TEXT ? i : i + 1;
      i = text + 1;
      if (types[i] != T.SPACELINE && types[i] != T.NL && types[i] != T.EOF) {
        fail(_stop);
      }
      db.addNode(
        type == T.TEXT ? 0 : ends[text - 1] - starts[text - 1],
        src.substring(starts[text], ends[text]).trim(),
      );
    } else if (type == T.SPACELINE || type == T.SPACELIST) {
      i++;
      if (types[i] != T.SPACELINE && types[i] != T.NL && types[i] != T.EOF) {
        fail(type == T.SPACELIST ? "$_stop, 'TEXT'" : _stop);
      }
    } else {
      fail("'SPACELINE', 'SPACELIST', 'TEXT'");
    }
    i++;
    while (types[i] == T.NL || types[i] == T.EOF) {
      i++;
    }
    if (types[i] == T.END) return;
  }
}

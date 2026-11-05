// Upstream: src/diagrams/venn/parser.ts

import '../../errors.dart';
import '../../util/math_js.dart';
import 'db.dart';
import 'lexer.dart';

const String _statement =
    "'EOF', 'NEWLINE', 'TITLE', 'SET', 'UNION', 'TEXT', 'INDENT_TEXT', 'STYLE'";
const String _value =
    "'NUMERIC', 'IDENTIFIER', 'STRING', 'HEXCOLOR', 'RGBCOLOR', 'RGBACOLOR'";

// Ports Mermaid's venn grammar. A token is read only when the grammar has to look at one to
// decide, because the lexer asks the model whether an indented `text` continues a set, and the
// statements are what tell the model so.
void parseVenn(String src, VennDb db) {
  final lexer = VennLexer(src, db);
  var type = -1;

  int peek() => type == -1 ? (type = lexer.next()) : type;

  Never fail(String expected) {
    if (peek() == T.ERROR) {
      throw syntaxError('venn', src, lexer.start, '', true);
    }
    throw syntaxError(
      'venn',
      src,
      lexer.start,
      "Expecting $expected, got '${TOKEN_NAMES[type]}'",
    );
  }

  String take() {
    type = -1;
    return lexer.text;
  }

  String expect(int wanted) {
    if (peek() != wanted) fail("'${TOKEN_NAMES[wanted]}'");
    return take();
  }

  String identifier() {
    if (peek() != T.IDENTIFIER && type != T.STRING) {
      fail("'IDENTIFIER', 'STRING'");
    }
    return take();
  }

  List<String> identifiers() {
    final list = <String>[identifier()];
    while (peek() == T.COMMA) {
      take();
      list.add(identifier());
    }
    return list;
  }

  void subset(List<String> ids, bool union) {
    final label = peek() == T.BRACKET_LABEL ? take() : null;
    double? size;
    if (peek() == T.COLON) {
      take();
      size = double.parse(expect(T.NUMERIC));
    }
    if (union) {
      if (ids.length < 2) {
        throw PeleError(
          'union requires multiple identifiers',
          'semantic',
          const PeleErrorInfo(type: 'venn'),
        );
      }
      db.validateUnionIdentifiers(ids);
    }
    db.addSubsetData(ids, label, size);
    db.setIndentMode(true);
  }

  // The id of a text, and the label in brackets that an id which is not a number may carry.
  void text(List<String> Function() sets) {
    final kind = peek();
    if (kind != T.IDENTIFIER && kind != T.STRING && kind != T.NUMERIC) {
      fail("'NUMERIC', 'IDENTIFIER', 'STRING'");
    }
    final id = take();
    final label = kind != T.NUMERIC && peek() == T.BRACKET_LABEL
        ? take()
        : null;
    db.addTextData(sets(), id, label);
  }

  void style() {
    final ids = identifiers();
    final styles = <(String, String)>[];
    for (;;) {
      final key = expect(T.IDENTIFIER);
      expect(T.COLON);
      String value;
      if (peek() == T.STRING) {
        value = take();
      } else {
        final parts = <String>[];
        while (peek() == T.IDENTIFIER ||
            (type >= T.NUMERIC && type <= T.RGBACOLOR)) {
          parts.add(take());
        }
        if (parts.isEmpty) fail(_value);
        value = parts.join(' ');
      }
      styles.add((key, value));
      if (peek() != T.COMMA) break;
      take();
    }
    db.addStyleData(ids, styles);
  }

  while (peek() == T.NEWLINE) {
    take();
  }
  expect(T.VENN);
  for (;;) {
    final statement = peek();
    if (statement == T.EOF) return;
    if (statement < T.NEWLINE || statement > T.STYLE || statement == T.VENN) {
      fail(_statement);
    }
    take();
    if (statement == T.TITLE) {
      db.setDiagramTitle(sliceJs(lexer.text, 6));
    } else if (statement == T.SET) {
      subset(<String>[identifier()], false);
    } else if (statement == T.UNION) {
      subset(identifiers(), true);
    } else if (statement == T.TEXT) {
      final ids = identifiers();
      text(() => ids);
    } else if (statement == T.INDENT_TEXT) {
      text(() {
        final current = db.getCurrentSets();
        if (current == null) {
          throw PeleError(
            'text requires set',
            'semantic',
            const PeleErrorInfo(type: 'venn'),
          );
        }
        return current;
      });
    } else if (statement == T.STYLE) {
      style();
    }
  }
}

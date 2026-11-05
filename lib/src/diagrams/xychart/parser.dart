// Upstream: src/diagrams/xychart/parser.ts

import 'dart:typed_data';

import '../../errors.dart';
import 'db.dart';
import 'lexer.dart';
import 'tokens.dart';

Uint8List _flags(List<int> tokens) {
  final out = Uint8List(T.EOF + 1);
  for (final t in tokens) {
    out[t] = 1;
  }
  return out;
}

final Uint8List _word = _flags(const <int>[
  T.AMP,
  T.NUM,
  T.ALPHA,
  T.PLUS,
  T.EQUALS,
  T.MULT,
  T.DOT,
  T.BRKT,
  T.MINUS,
  T.UNDERSCORE,
]);
final Uint8List _eol = _flags(const <int>[T.NEWLINE, T.SEMI, T.EOF]);

void parseXyChart(String src, XyChartDb db) {
  final tok = tokenize(src);
  final types = tok.types;
  final texts = tok.texts;
  final starts = tok.starts;
  var i = 0;

  Never fail(String expected) {
    final t = types[i];
    if (t == T.ERROR) throw syntaxError('xychart', src, starts[i], '', true);
    throw syntaxError(
      'xychart',
      src,
      starts[i],
      "Expecting $expected, got '${TOKEN_NAMES[t]}'",
    );
  }

  String expect(int type) {
    if (types[i] != type) fail("'${TOKEN_NAMES[type]}'");
    return texts[i++];
  }

  bool isText(int t) => t == T.STR || _word[t] == 1;

  XyText text() {
    if (!isText(types[i])) fail("'STR', 'ALPHA', 'NUM'");
    var s = texts[i++];
    if (types[i - 1] != T.STR) {
      while (_word[types[i]] == 1) {
        s += texts[i++];
      }
    }
    return XyText(text: s, type: 'text');
  }

  (double, double) range() {
    final min = double.parse(expect(T.NUMBER_WITH_DECIMAL));
    expect(T.ARROW_DELIMITER);
    return (min, double.parse(expect(T.NUMBER_WITH_DECIMAL)));
  }

  List<DataPoint> points() {
    final out = <DataPoint>[];
    expect(T.SQUARE_BRACES_START);
    for (;;) {
      final value = double.parse(expect(T.NUMBER_WITH_DECIMAL));
      out.add(
        DataPoint(value: value, label: types[i] == T.STR ? texts[i++] : ''),
      );
      if (types[i] != T.COMMA) break;
      i++;
    }
    expect(T.SQUARE_BRACES_END);
    return out;
  }

  for (;;) {
    if (_eol[types[i]] == 1) {
      i++;
    } else if (types[i] != T.XYCHART) {
      break;
    } else if (types[++i] == T.CHART_ORIENTATION) {
      db.setOrientation(texts[i++]);
    }
  }

  while (types[i] != T.END) {
    final t = types[i++];
    switch (t) {
      case T.title:
        db.setDiagramTitle(text().text.trim());
      case T.X_AXIS:
      case T.Y_AXIS:
        final title = isText(types[i]) ? text() : null;
        if (t == T.X_AXIS && types[i] == T.SQUARE_BRACES_START) {
          final categories = <XyText>[];
          do {
            i++;
            categories.add(text());
          } while (types[i] == T.COMMA);
          expect(T.SQUARE_BRACES_END);
          db.setXAxisBand(categories);
        } else if (types[i] == T.NUMBER_WITH_DECIMAL || title == null) {
          final (min, max) = range();
          if (t == T.X_AXIS) {
            db.setXAxisRangeData(min, max);
          } else {
            db.setYAxisRangeData(min, max);
          }
        }
        if (t == T.X_AXIS) {
          db.setXAxisTitle(title ?? const XyText(text: '', type: 'text'));
        } else {
          db.setYAxisTitle(title ?? const XyText(text: '', type: 'text'));
        }
      case T.LINE:
      case T.BAR:
        final title = types[i] == T.SQUARE_BRACES_START
            ? const XyText(text: '', type: 'text')
            : text();
        final data = points();
        if (t == T.LINE) {
          db.setLineData(title, data);
        } else {
          db.setBarData(title, data);
        }
      case T.acc_title:
        db.setAccTitle(expect(T.acc_title_value).trim());
      case T.acc_descr:
        db.setAccDescription(expect(T.acc_descr_value).trim());
      case T.acc_descr_multiline_value:
        db.setAccDescription(texts[i - 1].trim());
      default:
        i--;
        fail(
          "'title', 'X_AXIS', 'Y_AXIS', 'LINE', 'BAR', 'acc_title', 'acc_descr', 'acc_descr_multiline_value'",
        );
    }
    while (_eol[types[i]] == 1) {
      i++;
    }
  }
}

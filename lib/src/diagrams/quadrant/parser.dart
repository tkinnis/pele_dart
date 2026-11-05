// Upstream: src/diagrams/quadrant/parser.ts

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

final Uint8List _word = _flags(<int>[
  T.PUNCTUATION,
  T.AMP,
  T.NUM,
  T.ALPHA,
  T.COMMA,
  T.PLUS,
  T.EQUALS,
  T.MULT,
  T.DOT,
  T.BRKT,
  T.UNDERSCORE,
  T.UNICODE_TEXT,
]);
final Uint8List _id = _flags(<int>[
  T.ALPHA,
  T.NUM,
  T.MINUS,
  T.COMMA,
  T.COLON,
  T.AMP,
  T.BRKT,
  T.MULT,
  T.UNICODE_TEXT,
]);
final Uint8List _style = _flags(<int>[
  T.ALPHA,
  T.NUM,
  T.COLON,
  T.SPACE,
  T.BRKT,
  T.MINUS,
]);
final Uint8List _eol = _flags(<int>[T.NEWLINE, T.SEMI, T.EOF]);

const String _textTokens =
    "'STR', 'MD_STR', 'ALPHA', 'NUM', 'UNICODE_TEXT', 'PUNCTUATION'";

void parseQuadrant(String src, QuadrantDb db) {
  final tokens = tokenize(src);
  final types = tokens.types;
  final texts = tokens.texts;
  final starts = tokens.starts;
  var i = 0;

  Never fail(String expected) {
    final t = types[i];
    if (t == T.ERROR) {
      throw syntaxError('quadrantChart', src, starts[i], '', true);
    }
    throw syntaxError(
      'quadrantChart',
      src,
      starts[i],
      "Expecting $expected, got '${TOKEN_NAMES[t]}'",
    );
  }

  String expect(int type) {
    if (types[i] != type) fail("'${TOKEN_NAMES[type]}'");
    return texts[i++];
  }

  bool isText(int t) => t == T.STR || t == T.MD_STR || _word[t] == 1;

  QuadrantText text() {
    final first = types[i];
    if (!isText(first)) fail(_textTokens);
    final buf = StringBuffer(texts[i++]);
    while (_word[types[i]] == 1 || types[i] == T.SPACE || types[i] == T.MINUS) {
      buf.write(texts[i++]);
    }
    return QuadrantText(
      text: buf.toString(),
      type: first == T.MD_STR ? 'markdown' : 'text',
    );
  }

  List<String> styles() {
    final out = <String>[];
    for (;;) {
      if (_style[types[i]] == 0) {
        fail("'ALPHA', 'NUM', 'COLON', 'SPACE', 'BRKT', 'MINUS'");
      }
      final buf = StringBuffer(texts[i++]);
      while (_style[types[i]] == 1) {
        buf.write(texts[i++]);
      }
      out.add(buf.toString().trim());
      if (types[i] != T.COMMA) return out;
      i++;
    }
  }

  while (_eol[types[i]] == 1 || types[i] == T.SPACE) {
    i++;
  }
  expect(T.QUADRANT);

  while (types[i] != T.END) {
    while (types[i] == T.SPACE) {
      i++;
    }
    final t = types[i];
    switch (t) {
      case T.CLASSDEF:
        {
          i++;
          expect(T.SPACE);
          if (_id[types[i]] == 0) fail("'ALPHA', 'NUM', 'UNICODE_TEXT'");
          final idBuf = StringBuffer(texts[i++]);
          while (_id[types[i]] == 1) {
            idBuf.write(texts[i++]);
          }
          expect(T.SPACE);
          db.addClass(idBuf.toString(), styles());
          break;
        }
      case T.X_AXIS:
      case T.Y_AXIS:
        {
          i++;
          final from = text();
          QuadrantText? to;
          if (types[i] == T.DELIMITER) {
            i++;
            if (isText(types[i])) {
              to = text();
            } else {
              from.text += ' ⟶ ';
            }
          }
          if (t == T.X_AXIS) {
            db.setXAxisLeftText(from);
            if (to != null) db.setXAxisRightText(to);
          } else {
            db.setYAxisBottomText(from);
            if (to != null) db.setYAxisTopText(to);
          }
          break;
        }
      case T.QUADRANT_1:
        i++;
        db.setQuadrant1Text(text());
        break;
      case T.QUADRANT_2:
        i++;
        db.setQuadrant2Text(text());
        break;
      case T.QUADRANT_3:
        i++;
        db.setQuadrant3Text(text());
        break;
      case T.QUADRANT_4:
        i++;
        db.setQuadrant4Text(text());
        break;
      case T.title:
        i++;
        db.setDiagramTitle(expect(T.title_value).trim());
        break;
      case T.acc_title:
        i++;
        db.setAccTitle(expect(T.acc_title_value).trim());
        break;
      case T.acc_descr:
        i++;
        db.setAccDescription(expect(T.acc_descr_value).trim());
        break;
      case T.acc_descr_multiline_value:
        db.setAccDescription(texts[i++].trim());
        break;
      default:
        if (isText(t)) {
          final label = text();
          final className = types[i] == T.class_name ? texts[i++] : '';
          expect(T.point_start);
          final x = expect(T.point_x);
          final y = expect(T.point_y);
          db.addPoint(
            label,
            className,
            x,
            y,
            _style[types[i]] == 1 ? styles() : const <String>[],
          );
        }
    }
    if (_eol[types[i]] == 0) fail("'NEWLINE', 'SEMI', 'EOF'");
    i++;
  }
}

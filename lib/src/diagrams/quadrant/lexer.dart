// Upstream: src/diagrams/quadrant/lexer.ts

import 'dart:typed_data';

import '../../util/chars.dart';
import '../../util/math_js.dart';
import '../common/caseless.dart';
import 'tokens.dart';

class Tokens {
  const Tokens({
    required this.types,
    required this.texts,
    required this.starts,
  });

  final List<int> types;
  final List<String> texts;
  final List<int> starts;
}

abstract final class _S {
  static const int INITIAL = 0;
  static const int title = 1;
  static const int acc_title = 2;
  static const int acc_descr = 3;
  static const int acc_descr_multiline = 4;
  static const int string = 5;
  static const int md_string = 6;
  static const int class_name = 7;
  static const int point_start = 8;
  static const int point_x = 9;
  static const int point_y = 10;
}

// The token each state gives for the empty rest of the input, where it gives one.
const List<int> _atEnd = <int>[
  T.EOF,
  T.title_value,
  T.acc_title_value,
  T.acc_descr_value,
  T.acc_descr_multiline_value,
  T.STR,
];

final Uint8List _single = () {
  final table = Uint8List(128);
  const pairs = <(String, int)>[
    (':', T.COLON),
    ('+', T.PLUS),
    (',', T.COMMA),
    ('=', T.EQUALS),
    ('*', T.MULT),
    ('#', T.BRKT),
    ('_', T.UNDERSCORE),
    ('.', T.DOT),
    ('&', T.AMP),
    ('-', T.MINUS),
    (' \t\v\f', T.SPACE),
    (';', T.SEMI),
    (r"!$%'`?\/", T.PUNCTUATION),
  ];
  for (final (chars, type) in pairs) {
    for (var k = 0; k < chars.length; k++) {
      table[chars.codeUnitAt(k)] = type;
    }
  }
  return table;
}();

Tokens tokenize(String src) {
  final n = src.length;
  final types = <int>[];
  final texts = <String>[];
  final starts = <int>[];
  final stack = <int>[];
  var state = _S.INITIAL;
  var p = 0;
  // The last run scanned of each kind, so that a long run is not scanned again from each of its characters.
  var spaceFrom = 0;
  var spaceTo = 0;
  var dashFrom = 0;
  var dashTo = 0;
  var wsFrom = 0;
  var wsTo = 0;
  var gapFrom = 0;
  var gapTo = 0;

  void emit(int type, int s, int e) {
    types.add(type);
    texts.add(src.substring(s, e));
    starts.add(s);
    p = e;
  }

  void push(int s) {
    stack.add(state);
    state = s;
  }

  void pop() {
    if (stack.isNotEmpty) state = stack.removeLast();
  }

  int lineEnd(int q) {
    final e = src.indexOf('\n', q);
    return e == -1 ? n : e;
  }

  int spaces(int q) {
    var cur = q;
    while (charCodeAt(src, cur) == 32) {
      cur++;
    }
    return cur;
  }

  int run(int q) {
    var cur = q;
    while (cur < n && isSpace(charCodeAt(src, cur))) {
      cur++;
    }
    return cur;
  }

  // Mermaid's `(1)|(0(.\d+)?)`, where the dot is any character within a line.
  int coordinate(int q) {
    final c = charCodeAt(src, q);
    if (c == 49) return q + 1;
    if (c != 48) return -1;
    var e = q + 1;
    if (e < n &&
        !isLineEnd(charCodeAt(src, e)) &&
        isDigit(charCodeAt(src, e + 1))) {
      e += 2;
      while (isDigit(charCodeAt(src, e))) {
        e++;
      }
    }
    return e;
  }

  lexing:
  while (p < n) {
    final c = charCodeAt(src, p);
    final next = charCodeAt(src, p + 1);

    switch (state) {
      case _S.INITIAL:
        break;

      case _S.title:
      case _S.acc_title:
      case _S.acc_descr:
        emit(_atEnd[state], p, lineEnd(p));
        pop();
        continue;

      case _S.acc_descr_multiline:
        if (c == 125) {
          p++;
          pop();
        } else {
          final e = src.indexOf('}', p);
          emit(T.acc_descr_multiline_value, p, e == -1 ? n : e);
        }
        continue;

      case _S.string:
        if (c == 34) {
          p++;
          pop();
        } else {
          final e = src.indexOf('"', p);
          emit(T.STR, p, e == -1 ? n : e);
        }
        continue;

      case _S.md_string:
        if (c == 96 && next == 34) {
          p += 2;
          pop();
          continue;
        }
        if (c != 96 && c != 34) {
          var e = p + 1;
          for (
            var d = charCodeAt(src, e);
            e < n && d != 96 && d != 34;
            d = charCodeAt(src, ++e)
          ) {}
          emit(T.MD_STR, p, e);
          continue;
        }
        break lexing;

      case _S.class_name:
        if (isWord(c)) {
          var e = p + 1;
          while (isWord(charCodeAt(src, e))) {
            e++;
          }
          emit(T.class_name, p, e);
          pop();
          continue;
        }
        break lexing;

      case _S.point_start:
        {
          final e = coordinate(p);
          if (e != -1) {
            emit(T.point_x, p, e);
            push(_S.point_x);
            continue;
          }
          final k = run(p);
          if (charCodeAt(src, k) == 93) {
            p = spaces(k + 1);
            pop();
            continue;
          }
          break lexing;
        }

      case _S.point_x:
        {
          final k = run(p);
          if (charCodeAt(src, k) == 44) {
            p = run(k + 1);
            state = _S.point_y;
            continue;
          }
          break lexing;
        }

      case _S.point_y:
        {
          final e = coordinate(p);
          if (e != -1) {
            emit(T.point_y, p, e);
            pop();
            continue;
          }
          break lexing;
        }
    }

    if (c == 37 && next == 37) {
      p = lineEnd(p + 2);
      continue;
    }
    if (c == 10 || c == 13) {
      var e = p + 1;
      for (
        var d = charCodeAt(src, e);
        d == 10 || d == 13;
        d = charCodeAt(src, ++e)
      ) {}
      emit(T.NEWLINE, p, e);
      continue;
    }

    final lower = c | 32;
    if (lower == 116 &&
        wordAt(src, p, 'title') &&
        !isWord(charCodeAt(src, p + 5))) {
      emit(T.title, p, p + 5);
      push(_S.title);
      continue;
    }
    if (lower == 97 && wordAt(src, p, 'acc')) {
      final descr = wordAt(src, p + 3, 'descr');
      if (descr || wordAt(src, p + 3, 'title')) {
        final k = run(p + 8);
        final d = charCodeAt(src, k);
        if (d == 58) {
          emit(descr ? T.acc_descr : T.acc_title, p, run(k + 1));
          push(descr ? _S.acc_descr : _S.acc_title);
          continue;
        }
        if (d == 123 && descr) {
          p = run(k + 1);
          push(_S.acc_descr_multiline);
          continue;
        }
      }
    }

    // Axis, quadrant and chart keywords and the axis arrow take the spaces around them.
    var j = p;
    if (c == 32) {
      if (p < spaceFrom || p >= spaceTo) {
        spaceFrom = p;
        spaceTo = spaces(p);
      }
      j = spaceTo;
    }
    final d = charCodeAt(src, j);
    final dl = d | 32;
    var type = 0;
    var end = 0;
    if (dl == 120 && wordAt(src, j, 'x-axis')) {
      type = T.X_AXIS;
      end = j + 6;
    } else if (dl == 121 && wordAt(src, j, 'y-axis')) {
      type = T.Y_AXIS;
      end = j + 6;
    } else if (d == 45) {
      if (j < dashFrom || j >= dashTo) {
        dashFrom = j;
        dashTo = j;
        while (charCodeAt(src, dashTo) == 45) {
          dashTo++;
        }
      }
      if (dashTo - j >= 2 && charCodeAt(src, dashTo) == 62) {
        type = T.DELIMITER;
        end = dashTo + 1;
      }
    } else if (dl == 113 && wordAt(src, j, 'quadrant')) {
      final q = charCodeAt(src, j + 9);
      if (charCodeAt(src, j + 8) == 45 && q >= 49 && q <= 52) {
        type = T.QUADRANT_1 + q - 49;
        end = j + 10;
      } else if (wordAt(src, j + 8, 'chart')) {
        type = T.QUADRANT;
        end = j + 13;
      }
    }
    if (type != 0) {
      emit(type, p, spaces(end));
      continue;
    }

    if (lower == 99 &&
        wordAt(src, p, 'classdef') &&
        !isWord(charCodeAt(src, p + 8))) {
      emit(T.CLASSDEF, p, p + 8);
      continue;
    }
    if (c == 34) {
      if (next == 96) {
        p += 2;
        push(_S.md_string);
      } else {
        p++;
        push(_S.string);
      }
      continue;
    }
    if (c == 58 && next == 58 && charCodeAt(src, p + 2) == 58) {
      p += 3;
      push(_S.class_name);
      continue;
    }
    // A point's `: [`, with any whitespace before, between and after, line breaks included.
    if (c == 58 || isSpace(c)) {
      var k = p;
      if (c != 58) {
        if (p < wsFrom || p >= wsTo) {
          wsFrom = p;
          wsTo = run(p);
        }
        k = wsTo;
      }
      if (charCodeAt(src, k) == 58) {
        if (k + 1 < gapFrom || k + 1 >= gapTo) {
          gapFrom = k + 1;
          gapTo = run(k + 1);
        }
        if (charCodeAt(src, gapTo) == 91) {
          emit(T.point_start, p, run(gapTo + 1));
          push(_S.point_start);
          continue;
        }
      }
    }

    if (isLetter(c)) {
      var e = p + 1;
      while (isLetter(charCodeAt(src, e))) {
        e++;
      }
      emit(T.ALPHA, p, e);
      continue;
    }
    if (c >= 128) {
      var e = p + 1;
      while (charCodeAt(src, e) >= 128) {
        e++;
      }
      emit(T.UNICODE_TEXT, p, e);
      continue;
    }
    if (isDigit(c)) {
      var e = p + 1;
      while (isDigit(charCodeAt(src, e))) {
        e++;
      }
      emit(T.NUM, p, e);
      continue;
    }
    if (_single[c] != 0) {
      emit(_single[c], p, p + 1);
      continue;
    }
    break;
  }

  if (p < n) {
    types.add(T.ERROR);
    texts.add('');
    starts.add(p);
    return Tokens(types: types, texts: texts, starts: starts);
  }
  // Jison tries the rules of the current state once more against the empty rest of the input.
  if (state < _atEnd.length) {
    types.add(_atEnd[state]);
    texts.add('');
    starts.add(n);
  }
  types.add(T.END);
  texts.add('');
  starts.add(n);
  return Tokens(types: types, texts: texts, starts: starts);
}

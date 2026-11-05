// Upstream: src/diagrams/xychart/lexer.ts

import 'dart:typed_data';

import '../../util/chars.dart';
import '../../util/math_js.dart';
import '../common/caseless.dart';
import 'tokens.dart';

class Tokens {
  final List<int> types;
  final List<String> texts;
  final List<int> starts;

  const Tokens({
    required this.types,
    required this.texts,
    required this.starts,
  });
}

class _S {
  static const int INITIAL = 0;
  static const int axis_data = 1;
  static const int axis_band_data = 2;
  static const int data = 3;
  static const int data_inner = 4;
  static const int string = 5;
  static const int acc_title = 6;
  static const int acc_descr = 7;
  static const int acc_descr_multiline = 8;
}

// The token each state gives for the empty rest of the input.
const List<int> _atEnd = <int>[
  T.EOF,
  T.EOF,
  T.EOF,
  T.EOF,
  T.EOF,
  T.STR,
  T.acc_title_value,
  T.acc_descr_value,
  T.acc_descr_multiline_value,
];

// Mermaid's grammar means to open a markdown string at `"` followed by a backtick, but its quoting turns
// the rule into one that matches this text and leaves the current state. Markdown strings are never read.
final String _brokenRule =
    '`)${' ' * 36}{ this.pushstate(md_string); }\n<md_string>(?:(?!`").)+${' ' * 18}{ return md_str; }\n<md_string>(?:`';

final Uint8List _single = () {
  final out = Uint8List(128);
  for (final (char, type) in const <(String, int)>[
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
    (';', T.SEMI),
  ]) {
    out[char.codeUnitAt(0)] = type;
  }
  return out;
}();

Tokens tokenize(String src) {
  final n = src.length;
  final types = <int>[];
  final texts = <String>[];
  final starts = <int>[];
  final stack = <int>[];
  var state = _S.INITIAL;
  var p = 0;

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
    if (q > n) return n;
    final e = src.indexOf('\n', q);
    return e == -1 ? n : e;
  }

  int run(int q) {
    while (q < n && isSpace(charCodeAt(src, q))) {
      q++;
    }
    return q;
  }

  int digits(int q) {
    while (isDigit(charCodeAt(src, q))) {
      q++;
    }
    return q;
  }

  bool keyword(String word) =>
      wordAt(src, p, word) && !isWord(charCodeAt(src, p + word.length));

  while (p < n) {
    final c = charCodeAt(src, p);

    if (state == _S.string) {
      if (c == 34) {
        p++;
        pop();
      } else {
        final e = src.indexOf('"', p);
        emit(T.STR, p, e == -1 ? n : e);
      }
      continue;
    }
    if (state == _S.acc_title || state == _S.acc_descr) {
      emit(_atEnd[state], p, lineEnd(p));
      pop();
      continue;
    }
    if (state == _S.acc_descr_multiline) {
      if (c == 125) {
        p++;
        pop();
      } else {
        final e = src.indexOf('}', p);
        emit(T.acc_descr_multiline_value, p, e == -1 ? n : e);
      }
      continue;
    }

    final next = charCodeAt(src, p + 1);
    if (c == 37 && next == 37) {
      p = lineEnd(p + 2);
      continue;
    }
    if (c == 10 || c == 13) {
      // Only a line break that directly follows an axis or a series ends it; one after spaces is skipped
      // with them, and the state carries on to the next line.
      if ((state == _S.axis_data || state == _S.data) &&
          (c == 10 || next == 10)) {
        emit(T.NEWLINE, p, c == 10 ? p + 1 : p + 2);
        pop();
        continue;
      }
      var e = p + 1;
      for (
        var d = charCodeAt(src, e);
        d == 10 || d == 13;
        d = charCodeAt(src, ++e)
      ) {}
      emit(T.NEWLINE, p, e);
      continue;
    }

    switch (c | 32) {
      case 116:
        if (keyword('title')) {
          emit(T.title, p, p + 5);
          continue;
        }
      case 97:
        if (wordAt(src, p, 'acc')) {
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
      case 120:
        if (keyword('xychart-beta')) {
          emit(T.XYCHART, p, p + 12);
          continue;
        }
        if (keyword('xychart')) {
          emit(T.XYCHART, p, p + 7);
          continue;
        }
        if (keyword('x-axis')) {
          emit(T.X_AXIS, p, p + 6);
          push(_S.axis_data);
          continue;
        }
      case 121:
        if (keyword('y-axis')) {
          emit(T.Y_AXIS, p, p + 6);
          push(_S.axis_data);
          continue;
        }
      case 118:
        if (wordAt(src, p, 'vertical')) {
          emit(T.CHART_ORIENTATION, p, p + 8);
          continue;
        }
      case 104:
        if (wordAt(src, p, 'horizontal')) {
          emit(T.CHART_ORIENTATION, p, p + 10);
          continue;
        }
      case 108:
        if (keyword('line')) {
          emit(T.LINE, p, p + 4);
          push(_S.data);
          continue;
        }
      case 98:
        if (keyword('bar')) {
          emit(T.BAR, p, p + 3);
          push(_S.data);
          continue;
        }
    }

    if (c == 91) {
      if (state == _S.axis_data) {
        push(_S.axis_band_data);
      } else if (state == _S.data) {
        push(_S.data_inner);
      }
      emit(T.SQUARE_BRACES_START, p, p + 1);
      continue;
    }
    if (c == 93) {
      if (state == _S.data_inner || state == _S.axis_band_data) pop();
      emit(T.SQUARE_BRACES_END, p, p + 1);
      continue;
    }
    if (state == _S.axis_data &&
        c == 45 &&
        next == 45 &&
        charCodeAt(src, p + 2) == 62) {
      emit(T.ARROW_DELIMITER, p, p + 3);
      continue;
    }
    if (state == _S.axis_data || state == _S.data_inner) {
      final q = c == 43 || c == 45 ? p + 1 : p;
      final d = charCodeAt(src, q);
      var e = -1;
      if (isDigit(d)) {
        e = digits(q + 1);
        if (charCodeAt(src, e) == 46 && isDigit(charCodeAt(src, e + 1))) {
          e = digits(e + 2);
        }
      } else if (d == 46 && isDigit(charCodeAt(src, q + 1))) {
        e = digits(q + 2);
      }
      if (e != -1) {
        emit(T.NUMBER_WITH_DECIMAL, p, e);
        continue;
      }
    }
    if (c == 96 && wordAt(src, p, _brokenRule)) {
      p += _brokenRule.length;
      pop();
      continue;
    }
    if (c == 34) {
      p++;
      push(_S.string);
      continue;
    }
    if (isLetter(c)) {
      var e = p + 1;
      while (isLetter(charCodeAt(src, e))) {
        e++;
      }
      emit(T.ALPHA, p, e);
      continue;
    }
    if (isDigit(c)) {
      emit(T.NUM, p, digits(p + 1));
      continue;
    }
    if (isSpace(c)) {
      p = run(p + 1);
      continue;
    }
    if (c >= 0 && c < 128 && _single[c] != 0) {
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
  types.add(_atEnd[state]);
  texts.add('');
  starts.add(n);
  types.add(T.END);
  texts.add('');
  starts.add(n);
  return Tokens(types: types, texts: texts, starts: starts);
}

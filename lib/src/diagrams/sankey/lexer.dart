// Upstream: src/diagrams/sankey/lexer.ts

import '../../util/chars.dart';
import '../../util/math_js.dart';

abstract final class T {
  static const int END = 0;
  // Not a Jison token: the reference lexer would return the same empty token forever from here.
  static const int STUCK = 1;
  static const int SANKEY = 2;
  static const int NEWLINE = 3;
  static const int COMMA = 4;
  static const int DQUOTE = 5;
  static const int NON_ESCAPED_TEXT = 6;
  static const int ESCAPED_TEXT = 7;
  static const int EOF = 8;
}

const List<String> TOKEN_NAMES = <String>[
  r'$end',
  'STUCK',
  'SANKEY',
  'NEWLINE',
  'COMMA',
  'DQUOTE',
  'NON_ESCAPED_TEXT',
  'ESCAPED_TEXT',
  'EOF',
];

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
  static const int csv = 1;
  static const int escaped_text = 2;
}

// RFC 4180 TEXTDATA extended to Unicode, excluding controls and invalid XML characters.
bool _isTextData(int c) {
  return (c >= 32 && c <= 126 && c != 34 && c != 44) ||
      (c >= 0xa0 && c <= 0xd7ff) ||
      (c >= 0xe000 && c <= 0xfffd) ||
      (c >= 0x10000 && c <= 0x10ffff);
}

int _codePointAt(String s, int index) {
  final first = s.codeUnitAt(index);
  if (first >= 0xd800 && first <= 0xdbff && index + 1 < s.length) {
    final second = s.codeUnitAt(index + 1);
    if (second >= 0xdc00 && second <= 0xdfff) {
      return 0x10000 + ((first - 0xd800) << 10) + (second - 0xdc00);
    }
  }
  return first;
}

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

  bool keyword(String word) =>
      sliceJs(src, p, p + word.length).toLowerCase() == word &&
      !isWord(charCodeAt(src, p + word.length));

  while (p < n) {
    final c = charCodeAt(src, p);
    final start = p;
    var q = p;
    if (state == _S.escaped_text) {
      if (c == 34 && charCodeAt(src, p + 1) != 34) {
        if (stack.isNotEmpty) state = stack.removeLast();
        emit(T.DQUOTE, p, p + 1);
        continue;
      }
      while (q < n) {
        final d = _codePointAt(src, q);
        if (_isTextData(d) || d == 44 || d == 13 || d == 10) {
          q += d > 0xffff ? 2 : 1;
        } else if (d == 34 && charCodeAt(src, q + 1) == 34) {
          q += 2;
        } else {
          break;
        }
      }
      emit(T.ESCAPED_TEXT, p, q);
    } else {
      if (state == _S.INITIAL && (c | 32) == 115) {
        final length = keyword('sankey-beta')
            ? 11
            : (keyword('sankey') ? 6 : 0);
        if (length > 0) {
          stack.add(state);
          state = _S.csv;
          emit(T.SANKEY, p, p + length);
          continue;
        }
      }
      if (c == 10 || (c == 13 && charCodeAt(src, p + 1) == 10)) {
        emit(T.NEWLINE, p, c == 10 ? p + 1 : p + 2);
        continue;
      }
      if (c == 44) {
        emit(T.COMMA, p, p + 1);
        continue;
      }
      if (c == 34) {
        stack.add(state);
        state = _S.escaped_text;
        emit(T.DQUOTE, p, p + 1);
        continue;
      }
      while (q < n) {
        final d = _codePointAt(src, q);
        if (!_isTextData(d)) break;
        q += d > 0xffff ? 2 : 1;
      }
      emit(T.NON_ESCAPED_TEXT, p, q);
    }
    // A character outside the CSV alphabet matches as empty text and is never consumed.
    if (q == start) {
      emit(T.STUCK, p, p);
      return Tokens(types: types, texts: texts, starts: starts);
    }
  }

  emit(state == _S.escaped_text ? T.ESCAPED_TEXT : T.EOF, n, n);
  emit(T.END, n, n);
  return Tokens(types: types, texts: texts, starts: starts);
}

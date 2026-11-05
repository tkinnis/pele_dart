// Upstream: src/diagrams/er/lexer.ts

import 'dart:typed_data';

import '../../util/chars.dart';
import '../../util/math_js.dart';
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
  static const int block = 1;
  static const int block_bq = 2;
  static const int acc_title = 3;
  static const int acc_descr = 4;
  static const int acc_descr_multiline = 5;
  static const int style = 6;
}

const int _text = 1;
const int _styleText = 2;
const int _attrStart = 4;
const int _attrRest = 8;

final Uint8List _class = _buildClass();

Uint8List _buildClass() {
  final table = Uint8List(128);
  for (var c = 0; c < 128; c++) {
    final word =
        (c >= 48 && c <= 57) ||
        (c >= 65 && c <= 90) ||
        (c >= 97 && c <= 122) ||
        c == 95;
    final letter = word && (c < 48 || c > 57);
    if (word) table[c] |= _text | _styleText | _attrRest;
    if (letter) table[c] |= _attrStart;
  }
  for (final ch in <int>[45, 42]) {
    // '-*'
    table[ch] |= _text | _styleText | _attrRest;
  }
  table[46] |= _text | _attrRest;
  table[42] |= _attrStart;
  for (final ch in <int>[91, 93, 40, 41, 44]) {
    // '[](),'
    table[ch] |= _attrRest;
  }
  return table;
}

final RegExp _reAccTitle = RegExp(r'accTitle\s*:\s*', caseSensitive: false);
final RegExp _reAccDescr = RegExp(r'accDescr\s*:\s*', caseSensitive: false);
final RegExp _reAccDescrMl = RegExp(r'accDescr\s*\{\s*', caseSensitive: false);
final List<RegExp> _reDirection = <RegExp>[
  RegExp(r'.*direction\s+TB[^\n]*', caseSensitive: false),
  RegExp(r'.*direction\s+BT[^\n]*', caseSensitive: false),
  RegExp(r'.*direction\s+RL[^\n]*', caseSensitive: false),
  RegExp(r'.*direction\s+LR[^\n]*', caseSensitive: false),
];
final RegExp _reDirWord = RegExp('direction', caseSensitive: false);

/// Mermaid's attribute pattern is case-insensitive, which lets the micro sign into its \u00c0-\uffff range.
bool _isAttr(int c, int kind) {
  if (c < 0) return false;
  return c < 128 ? (_class[c] & kind) != 0 : c >= 0xc0 || c == 0xb5;
}

Tokens tokenize(String src) {
  final n = src.length;
  final types = <int>[];
  final texts = <String>[];
  final starts = <int>[];
  var state = _S.INITIAL;
  var p = 0;
  var dirNext = -2;
  var dirFailed = 0;
  var lineEnd = -1;
  var tildeNext = -2;
  var tildeLine = -1;
  var tildeLast = -1;
  var wsNext = -1;

  void emit(int type, int s, int e) {
    types.add(type);
    texts.add(src.substring(s, e));
    starts.add(s);
    p = e;
  }

  int at(RegExp re, int q) => matchSticky(re, src, q);

  // Matches a lower-case keyword at p, ignoring case.
  bool kw(String word) {
    for (var i = 0; i < word.length; i++) {
      final k = word.codeUnitAt(i);
      final c = charCodeAt(src, p + i);
      if (c != k && (k < 97 || k > 122 || (c | 32) != k)) return false;
    }
    return true;
  }

  bool kwb(String word) =>
      kw(word) && !isWord(charCodeAt(src, p + word.length));

  int lower(int q) {
    final c = charCodeAt(src, q);
    return c >= 65 && c <= 90 ? c + 32 : c;
  }

  int nextLineEnd(int q) {
    for (var i = q; i < n; i++) {
      final c = src.codeUnitAt(i);
      if (c == 10 || c == 13 || c == 0x2028 || c == 0x2029) return i;
    }
    return n;
  }

  int digits(int q) {
    while (isDigit(charCodeAt(src, q))) {
      q++;
    }
    return q;
  }

  // A direction statement swallows its whole line, from wherever the lexer stands on it.
  bool direction() {
    if (dirNext == -1) return false;
    if (dirNext < p) {
      final m = _reDirWord.allMatches(src, p).firstOrNull;
      dirNext = m != null ? m.start : -1;
      if (dirNext == -1) return false;
    }
    if (p < dirFailed) return false;
    if (lineEnd < p) lineEnd = nextLineEnd(p);
    if (dirNext >= lineEnd) return false;
    for (var i = 0; i < 4; i++) {
      final e = at(_reDirection[i], p);
      if (e >= 0) {
        emit(T.direction_tb + i, p, e);
        return true;
      }
    }
    dirFailed = lineEnd;
    return false;
  }

  void quoted() {
    final e = p + 1 <= n ? src.indexOf('"', p + 1) : -1;
    if (e == -1) {
      emit(T.CHAR, p, p + 1);
      return;
    }
    var name = e > p + 1;
    for (var q = p + 1; name && q < e; q++) {
      final c = src.codeUnitAt(q);
      if (c == 37 || c == 92 || c == 13 || c == 10 || c == 11 || c == 8) {
        name = false;
      }
    }
    emit(name ? T.ENTITY_NAME : T.WORD, p, e + 1);
  }

  void number(int c) {
    final d = charCodeAt(src, p + 1);
    if (d == 43 && (c == 49 || c == 48)) {
      emit(c == 49 ? T.ONE_OR_MORE : T.ZERO_OR_MORE, p, p + 2);
      return;
    }
    final q = digits(p + 1);
    if (charCodeAt(src, q) == 46 && isDigit(charCodeAt(src, q + 1))) {
      emit(T.DECIMAL_NUM, p, digits(q + 2));
      return;
    }
    if (c == 49) {
      if (isSpace(d)) {
        var r = p + 2;
        while (isSpace(charCodeAt(src, r))) {
          r++;
        }
        final f = charCodeAt(src, r);
        if (isWord(f) || f == 34 || f == 39) {
          emit(T.ONLY_ONE, p, p + 1);
          return;
        }
      } else if (d == 45 || d == 46) {
        final f = charCodeAt(src, p + 2);
        if (f == 45 || f == 46) {
          emit(T.ONLY_ONE, p, p + 1);
          return;
        }
      }
      if (!isWord(d)) {
        emit(T.ENTITY_ONE, p, p + 1);
        return;
      }
    }
    emit(T.NUM, p, q);
  }

  bool keyword(int lc) {
    final d = charCodeAt(src, p + 1);
    switch (lc) {
      case 101:
        if (kwb('erdiagram')) {
          emit(T.ER_DIAGRAM, p, p + 9);
        } else if (kwb('end')) {
          var e = p + 3;
          while (isSpace(charCodeAt(src, e))) {
            e++;
          }
          emit(T.END_KW, p, e);
        } else {
          return false;
        }
        return true;
      case 115:
        if (kwb('style')) {
          state = _S.style;
          emit(T.STYLE, p, p + 5);
        } else if (kwb('subgraph')) {
          emit(T.SUBGRAPH, p, p + 8);
        } else {
          return false;
        }
        return true;
      case 99:
        if (kwb('classdef')) {
          state = _S.style;
          emit(T.CLASSDEF, p, p + 8);
        } else if (kwb('class')) {
          emit(T.CLASS, p, p + 5);
        } else {
          return false;
        }
        return true;
      case 111:
        if (kwb('one or zero')) {
          emit(T.ZERO_OR_ONE, p, p + 11);
        } else if (kwb('one or more') || kwb('one or many')) {
          emit(T.ONE_OR_MORE, p, p + 11);
        } else if (kwb('one')) {
          emit(T.ONLY_ONE, p, p + 3);
        } else if (kwb('only one')) {
          emit(T.ONLY_ONE, p, p + 8);
        } else if (d == 124) {
          emit(T.ZERO_OR_ONE, p, p + 2);
        } else if (d == 123) {
          emit(T.ZERO_OR_MORE, p, p + 2);
        } else if (kwb('optionally to')) {
          emit(T.NON_IDENTIFYING, p, p + 13);
        } else {
          return false;
        }
        return true;
      case 122:
        if (kwb('zero or one')) {
          emit(T.ZERO_OR_ONE, p, p + 11);
        } else if (kwb('zero or more') || kwb('zero or many')) {
          emit(T.ZERO_OR_MORE, p, p + 12);
        } else {
          return false;
        }
        return true;
      case 109:
        if (kw('many(0)')) {
          emit(T.ZERO_OR_MORE, p, p + 7);
        } else if (kw('many(1)')) {
          emit(T.ONE_OR_MORE, p, p + 7);
        } else if (kwb('many')) {
          emit(T.ZERO_OR_MORE, p, p + 4);
        } else {
          return false;
        }
        return true;
      case 116:
        if (!kwb('to')) return false;
        emit(T.IDENTIFYING, p, p + 2);
        return true;
      case 117:
        if (d != 46 && d != 45 && d != 124) return false;
        emit(T.MD_PARENT, p, p + 1);
        return true;
      case 124:
        if (lower(p + 1) == 111 && !isWord(charCodeAt(src, p + 2))) {
          emit(T.ZERO_OR_ONE, p, p + 2);
        } else if (d == 124) {
          emit(T.ONLY_ONE, p, p + 2);
        } else if (d == 123) {
          emit(T.ONE_OR_MORE, p, p + 2);
        } else {
          return false;
        }
        return true;
      case 125:
        if (lower(p + 1) == 111 && !isWord(charCodeAt(src, p + 2))) {
          emit(T.ZERO_OR_MORE, p, p + 2);
        } else if (d == 124) {
          emit(T.ONE_OR_MORE, p, p + 2);
        } else {
          return false;
        }
        return true;
      case 46:
        if (d != 46 && d != 45) return false;
        emit(T.NON_IDENTIFYING, p, p + 2);
        return true;
      case 45:
        if (d == 45) {
          emit(T.IDENTIFYING, p, p + 2);
        } else if (d == 46) {
          emit(T.NON_IDENTIFYING, p, p + 2);
        } else {
          return false;
        }
        return true;
    }
    return false;
  }

  void initial(int c) {
    int e;
    if ((c == 97 || c == 65) && kw('acc')) {
      if ((e = at(_reAccTitle, p)) >= 0) {
        state = _S.acc_title;
        emit(T.acc_title, p, e);
        return;
      }
      if ((e = at(_reAccDescr, p)) >= 0) {
        state = _S.acc_descr;
        emit(T.acc_descr, p, e);
        return;
      }
      if ((e = at(_reAccDescrMl, p)) >= 0) {
        state = _S.acc_descr_multiline;
        p = e;
        return;
      }
    }
    if (direction()) return;

    switch (c) {
      case 32:
      case 9:
      case 13:
        e = p + 1;
        for (
          var d = charCodeAt(src, e);
          d == 32 || d == 9 || d == 13;
          d = charCodeAt(src, e)
        ) {
          e++;
        }
        p = e;
        return;
      case 10:
        e = p + 1;
        while (charCodeAt(src, e) == 10) {
          e++;
        }
        emit(T.NEWLINE, p, e);
        return;
      case 34:
        quoted();
        return;
      case 123:
        state = _S.block;
        emit(T.BLOCK_START, p, p + 1);
        return;
      case 35:
        emit(T.BRKT, p, p + 1);
        return;
      case 44:
        emit(T.COMMA, p, p + 1);
        return;
      case 58:
        if (charCodeAt(src, p + 1) == 58 && charCodeAt(src, p + 2) == 58) {
          emit(T.STYLE_SEPARATOR, p, p + 3);
        } else {
          emit(T.COLON, p, p + 1);
        }
        return;
      case 91:
        emit(T.SQS, p, p + 1);
        return;
      case 93:
        emit(T.SQE, p, p + 1);
        return;
    }
    if (isDigit(c)) {
      number(c);
      return;
    }
    if (keyword(c >= 65 && c <= 90 ? c + 32 : c)) return;
    if (c >= 128 || (c >= 0 && (_class[c] & _text) != 0)) {
      e = p + 1;
      for (
        var d = charCodeAt(src, e);
        d >= 128 || (d >= 0 && (_class[d] & _text) != 0);
        d = charCodeAt(src, e)
      ) {
        e++;
      }
      emit(T.UNICODE_TEXT, p, e);
      return;
    }
    emit(T.CHAR, p, p + 1);
  }

  // Mermaid's generic type rule: a run of non-space characters holding a `~`, through the last `~` on the line.
  bool generic() {
    if (tildeNext == -1) return false;
    if (tildeNext < p) {
      tildeNext = src.indexOf('~', p);
      if (tildeNext == -1) return false;
    }
    if (wsNext < p) {
      var q = p;
      while (q < n && !isSpace(src.codeUnitAt(q))) {
        q++;
      }
      wsNext = q;
    }
    if (tildeNext >= wsNext) return false;
    if (tildeLine < p) {
      tildeLine = nextLineEnd(p);
      tildeLast = tildeLine > 0 ? src.lastIndexOf('~', tildeLine - 1) : -1;
    }
    if (tildeLast <= tildeNext) return false;
    var e = tildeLast + 1;
    while (e < n && !isSpace(src.codeUnitAt(e))) {
      e++;
    }
    emit(T.ATTRIBUTE_WORD, p, e);
    return true;
  }

  void block(int c) {
    if (isSpace(c)) {
      p++;
      while (isSpace(charCodeAt(src, p))) {
        p++;
      }
      return;
    }
    final lc = c | 32;
    if ((lc == 112 || lc == 102 || lc == 117) &&
        (charCodeAt(src, p + 1) | 32) == 107 &&
        !isWord(charCodeAt(src, p + 2))) {
      emit(T.ATTRIBUTE_KEY, p, p + 2);
      return;
    }
    if (generic()) return;
    if (_isAttr(c, _attrStart)) {
      var e = p + 1;
      while (e < n && _isAttr(src.codeUnitAt(e), _attrRest)) {
        e++;
      }
      emit(T.ATTRIBUTE_WORD, p, e);
      return;
    }
    if (c == 96) {
      state = _S.block_bq;
      p++;
      return;
    }
    if (c == 34) {
      final e = p + 1 <= n ? src.indexOf('"', p + 1) : -1;
      if (e != -1) {
        emit(T.COMMENT, p, e + 1);
        return;
      }
    } else if (c == 125) {
      state = _S.INITIAL;
      emit(T.BLOCK_STOP, p, p + 1);
      return;
    }
    emit(T.CHAR, p, p + 1);
  }

  while (p < n) {
    final c = src.codeUnitAt(p);
    int e;
    switch (state) {
      case _S.INITIAL:
        initial(c);
        break;

      case _S.block:
        block(c);
        break;

      case _S.block_bq:
        if (c == 96) {
          state = _S.block;
          p++;
        } else {
          e = src.indexOf('`', p);
          emit(T.ATTRIBUTE_WORD, p, e == -1 ? n : e);
        }
        break;

      case _S.acc_title:
      case _S.acc_descr:
        e = src.indexOf('\n', p);
        emit(
          state == _S.acc_title ? T.acc_title_value : T.acc_descr_value,
          p,
          e == -1 ? n : e,
        );
        state = _S.INITIAL;
        break;

      case _S.acc_descr_multiline:
        if (c == 125) {
          state = _S.INITIAL;
          p++;
        } else {
          e = src.indexOf('}', p);
          emit(T.acc_descr_multiline_value, p, e == -1 ? n : e);
        }
        break;

      case _S.style:
        if (c == 10) {
          e = p + 1;
          while (charCodeAt(src, e) == 10) {
            e++;
          }
          state = _S.INITIAL;
          emit(T.NEWLINE, p, e);
        } else if (isSpace(c)) {
          p++;
          while (isSpace(charCodeAt(src, p))) {
            p++;
          }
        } else if (c == 58) {
          emit(T.COLON, p, p + 1);
        } else if (c == 44) {
          emit(T.COMMA, p, p + 1);
        } else if (c == 35) {
          emit(T.BRKT, p, p + 1);
        } else if (c == 59) {
          emit(T.SEMI, p, p + 1);
        } else if (c >= 128 || (c >= 0 && (_class[c] & _styleText) != 0)) {
          e = p + 1;
          for (
            var d = charCodeAt(src, e);
            d >= 128 || (d >= 0 && (_class[d] & _styleText) != 0);
            d = charCodeAt(src, e)
          ) {
            e++;
          }
          emit(T.STYLE_TEXT, p, e);
        } else {
          types.add(T.ERROR);
          texts.add('');
          starts.add(p);
          return Tokens(types: types, texts: texts, starts: starts);
        }
        break;
    }
  }

  // At the end of input Jison's INITIAL state yields EOF, the title and description states yield
  // an empty value, and the block and style states yield nothing.
  final last = state == _S.INITIAL
      ? T.EOF
      : state == _S.acc_title
      ? T.acc_title_value
      : state == _S.acc_descr
      ? T.acc_descr_value
      : state == _S.acc_descr_multiline
      ? T.acc_descr_multiline_value
      : -1;
  if (last != -1) {
    types.add(last);
    texts.add('');
    starts.add(n);
  }
  types.add(T.END);
  texts.add('');
  starts.add(n);
  return Tokens(types: types, texts: texts, starts: starts);
}

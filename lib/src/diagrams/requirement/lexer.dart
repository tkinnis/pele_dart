// Upstream: src/diagrams/requirement/lexer.ts

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
  static const int string = 1;
  static const int style = 2;
  static const int acc_title = 3;
  static const int acc_descr = 4;
  static const int acc_descr_multiline = 5;
}

final RegExp _reAccTitle = RegExp(r'accTitle\s*:\s*', caseSensitive: false);
final RegExp _reAccDescr = RegExp(r'accDescr\s*:\s*', caseSensitive: false);
final RegExp _reAccDescrMl = RegExp(r'accDescr\s*\{\s*', caseSensitive: false);
final RegExp _reDirection = RegExp(
  r'direction\s+(?:(TB)|(BT)|(RL)|LR)',
  caseSensitive: false,
);
const int _longestKeyword = 22;

/// Characters that end an unquoted string: `:,{<>-=` and line breaks.
final Uint8List _stop = _buildStop();

Uint8List _buildStop() {
  final table = Uint8List(128);
  for (final ch in ':,\r\n{<>-='.codeUnits) {
    table[ch] = 1;
  }
  return table;
}

/// Produces the token stream of Mermaid's requirement lexer. Its rules are tried in order and
/// the first match wins, so a line that holds a direction statement anywhere is one token.
Tokens tokenize(String src) {
  final n = src.length;
  final types = <int>[];
  final texts = <String>[];
  final starts = <int>[];
  final stack = <int>[];
  var state = _S.INITIAL;
  var p = 0;

  // Where each kind of direction statement starts and where its keyword ends, found in one pass.
  final dirStarts = <List<int>>[<int>[], <int>[], <int>[], <int>[]];
  final dirEnds = <List<int>>[<int>[], <int>[], <int>[], <int>[]];
  final dirSeen = <int>[0, 0, 0, 0];
  var anyDir = false;
  var lineEnd = -1;
  for (final m in _reDirection.allMatches(src)) {
    final kind = m.group(1) != null
        ? 0
        : m.group(2) != null
        ? 1
        : m.group(3) != null
        ? 2
        : 3;
    dirStarts[kind].add(m.start);
    dirEnds[kind].add(m.end);
    anyDir = true;
  }

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

  int at(RegExp re, int q) => matchSticky(re, src, q);

  int lineBreak(int q) {
    final e = src.indexOf('\n', q);
    return e == -1 ? n : e;
  }

  int nextLineEnd(int q) {
    for (var i = q; i < n; i++) {
      final c = src.codeUnitAt(i);
      if (c == 10 || c == 13 || c == 0x2028 || c == 0x2029) return i;
    }
    return n;
  }

  // `.*direction\s+XX[^\n]*`: the last such statement that starts on this line decides the token.
  bool direction() {
    if (lineEnd < p) {
      lineEnd = nextLineEnd(p);
      for (var k = 0; k < 4; k++) {
        final list = dirStarts[k];
        var j = dirSeen[k];
        while (j < list.length && list[j] <= lineEnd) {
          j++;
        }
        dirSeen[k] = j;
      }
    }
    for (var k = 0; k < 4; k++) {
      final j = dirSeen[k] - 1;
      if (j >= 0 && dirStarts[k][j] >= p) {
        emit(T.direction_tb + k, p, lineBreak(dirEnds[k][j]));
        return true;
      }
    }
    return false;
  }

  bool initial(int c) {
    final lower = c | 32;
    if (lower == 116 &&
        sliceJs(src, p + 1, p + 5).toLowerCase() == 'itle' &&
        isSpace(charCodeAt(src, p + 5))) {
      var q = p + 6;
      while (q < n) {
        final d = src.codeUnitAt(q);
        if (d == 35 || d == 10 || d == 59) break;
        q++;
      }
      if (q > p + 6) {
        emit(T.title, p, q);
        return true;
      }
    }
    if (lower == 97 &&
        (charCodeAt(src, p + 1) | 32) == 99 &&
        (charCodeAt(src, p + 2) | 32) == 99) {
      int e;
      if ((e = at(_reAccTitle, p)) >= 0) {
        push(_S.acc_title);
        emit(T.acc_title, p, e);
        return true;
      }
      if ((e = at(_reAccDescr, p)) >= 0) {
        push(_S.acc_descr);
        emit(T.acc_descr, p, e);
        return true;
      }
      if ((e = at(_reAccDescrMl, p)) >= 0) {
        push(_S.acc_descr_multiline);
        p = e;
        return true;
      }
    }
    if (anyDir && !isLineEnd(c) && direction()) return true;

    if (c == 10 || (c == 13 && charCodeAt(src, p + 1) == 10)) {
      var q = p;
      while (q < n) {
        final d = src.codeUnitAt(q);
        if (d == 10) {
          q++;
        } else if (d == 13 && charCodeAt(src, q + 1) == 10) {
          q += 2;
        } else {
          break;
        }
      }
      emit(T.NEWLINE, p, q);
      return true;
    }
    if (isSpace(c)) {
      p++;
      while (p < n && isSpace(src.codeUnitAt(p))) {
        p++;
      }
      return true;
    }
    if (c == 35 || c == 37) {
      p = lineBreak(p);
      return true;
    }

    if (isWord(c)) {
      var q = p + 1;
      while (q < n && isWord(src.codeUnitAt(q))) {
        q++;
      }
      if (q - p <= _longestKeyword) {
        final keyword = KEYWORDS[src.substring(p, q).toLowerCase()];
        if (keyword != null) {
          if (keyword == T.STYLE ||
              keyword == T.CLASSDEF ||
              keyword == T.CLASS) {
            push(_S.style);
          }
          emit(keyword, p, q);
          return true;
        }
      }
      while (q < n) {
        final d = src.codeUnitAt(q);
        if (d < 128 && _stop[d] == 1) break;
        q++;
      }
      types.add(T.unqString);
      texts.add(src.substring(p, q).trim());
      starts.add(p);
      p = q;
      return true;
    }

    switch (c) {
      case 123:
        emit(T.STRUCT_START, p, p + 1);
        return true;
      case 125:
        emit(T.STRUCT_STOP, p, p + 1);
        return true;
      case 58:
        if (charCodeAt(src, p + 1) == 58 && charCodeAt(src, p + 2) == 58) {
          emit(T.STYLE_SEPARATOR, p, p + 3);
        } else {
          emit(T.COLONSEP, p, p + 1);
        }
        return true;
      case 60:
        if (charCodeAt(src, p + 1) != 45) return false;
        emit(T.END_ARROW_L, p, p + 2);
        return true;
      case 45:
        if (charCodeAt(src, p + 1) == 62) {
          emit(T.END_ARROW_R, p, p + 2);
        } else {
          emit(T.LINE, p, p + 1);
        }
        return true;
      case 34:
        push(_S.string);
        p++;
        return true;
      case 44:
        emit(T.COMMA, p, p + 1);
        return true;
    }
    return false;
  }

  bool style(int c) {
    if (isWord(c)) {
      var q = p + 1;
      while (q < n && isWord(src.codeUnitAt(q))) {
        q++;
      }
      emit(T.ALPHA, p, q);
      return true;
    }
    switch (c) {
      case 58:
        emit(T.COLON, p, p + 1);
        return true;
      case 59:
        emit(T.SEMICOLON, p, p + 1);
        return true;
      case 37:
        emit(T.PERCENT, p, p + 1);
        return true;
      case 45:
        emit(T.MINUS, p, p + 1);
        return true;
      case 35:
        emit(T.BRKT, p, p + 1);
        return true;
      case 32:
        p++;
        return true;
      case 34:
        push(_S.string);
        p++;
        return true;
      case 10:
        pop();
        p++;
        return true;
      case 44:
        emit(T.COMMA, p, p + 1);
        return true;
    }
    return false;
  }

  while (p < n) {
    final c = src.codeUnitAt(p);
    var ok = true;
    switch (state) {
      case _S.INITIAL:
        ok = initial(c);
        break;
      case _S.style:
        ok = style(c);
        break;
      case _S.string:
        if (c == 34) {
          pop();
          p++;
        } else {
          final e = src.indexOf('"', p);
          emit(T.qString, p, e == -1 ? n : e);
        }
        break;
      case _S.acc_title:
        pop();
        emit(T.acc_title_value, p, lineBreak(p));
        break;
      case _S.acc_descr:
        pop();
        emit(T.acc_descr_value, p, lineBreak(p));
        break;
      case _S.acc_descr_multiline:
        if (c == 125) {
          pop();
          p++;
        } else {
          final e = src.indexOf('}', p);
          emit(T.acc_descr_multiline_value, p, e == -1 ? n : e);
        }
        break;
    }
    if (!ok) {
      types.add(T.ERROR);
      texts.add('');
      starts.add(p);
      return Tokens(types: types, texts: texts, starts: starts);
    }
  }

  // At the end of input Jison still tries the rules that can match nothing, once.
  final last = state == _S.INITIAL
      ? T.EOF
      : state == _S.string
      ? T.qString
      : state == _S.acc_title
      ? T.acc_title_value
      : state == _S.acc_descr
      ? T.acc_descr_value
      : state == _S.acc_descr_multiline
      ? T.acc_descr_multiline_value
      : -1;
  if (last != -1) emit(last, n, n);
  emit(T.END, n, n);
  return Tokens(types: types, texts: texts, starts: starts);
}

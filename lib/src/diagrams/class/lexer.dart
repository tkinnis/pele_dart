// Upstream: src/diagrams/class/lexer.ts

import '../../util/chars.dart';
import '../../util/math_js.dart';
import '../../util/unicode.dart';
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
  static const int string = 1;
  static const int bqstring = 2;
  static const int generic = 3;
  static const int callbackName = 4;
  static const int callbackArgs = 5;
  static const int accTitle = 6;
  static const int accDescr = 7;
  static const int accDescrMultiline = 8;
  static const int cls = 9;
  static const int classBody = 10;
  static const int namespace = 11;
  static const int namespaceBody = 12;
}

// The token each state gives at the end of input, before the parser sees the end itself.
const List<int> _AT_END = <int>[
  T.EOF,
  T.STR,
  T.EOF,
  T.GENERICTYPE,
  T.CALLBACK_NAME,
  T.CALLBACK_ARGS,
  T.acc_title_value,
  T.acc_descr_value,
  T.acc_descr_multiline_value,
  T.EOF,
  T.EOF_IN_STRUCT,
  T.EOF,
  T.EOF_IN_STRUCT,
];

final List<RegExp> _RE_DIRECTION = <RegExp>[
  RegExp(r'.*direction\s+TB[^\n]*'),
  RegExp(r'.*direction\s+BT[^\n]*'),
  RegExp(r'.*direction\s+RL[^\n]*'),
  RegExp(r'.*direction\s+LR[^\n]*'),
];

int _findLineEnd(String src, int from) {
  final n = src.length;
  for (var i = from; i < n; i++) {
    if (isLineEnd(src.codeUnitAt(i))) return i;
  }
  return n;
}

Tokens tokenize(String src) {
  final n = src.length;
  final types = <int>[];
  final texts = <String>[];
  final starts = <int>[];
  final stack = <int>[];
  var state = _S.INITIAL;
  var p = 0;
  var dirNext = src.indexOf('direction');
  var lineEnd = -1;
  var dirFailed = 0;

  bool emit(int type, int s, int e) {
    types.add(type);
    texts.add(src.substring(s, e));
    starts.add(s);
    p = e;
    return true;
  }

  void push(int s) {
    stack.add(state);
    state = s;
  }

  void pop() {
    if (stack.isNotEmpty) state = stack.removeLast();
  }

  bool kw(String word) =>
      src.startsWith(word, p) && !isWord(charCodeAt(src, p + word.length));

  int skipWs(int q) {
    while (q < n && isSpace(charCodeAt(src, q))) {
      q++;
    }
    return q;
  }

  int until(String ch) {
    final e = src.indexOf(ch, p);
    return e == -1 ? n : e;
  }

  // A run of whitespace is a NEWLINE up to its last line feed; the rest is skipped.
  void space(bool leaves) {
    var q = p;
    var k = -1;
    for (
      var c = charCodeAt(src, q);
      q < n && isSpace(c);
      c = charCodeAt(src, ++q)
    ) {
      if (c == 10) k = q;
    }
    if (k < 0) {
      p = q;
      return;
    }
    if (leaves) pop();
    emit(T.NEWLINE, p, k + 1);
  }

  // The keywords that every state recognizes, even inside generics and backtick names.
  bool keyword(int c) {
    switch (c) {
      case 99:
        if (kw('cssClass')) return emit(T.CSSCLASS, p, p + 8);
        if (kw('callback')) return emit(T.CALLBACK, p, p + 8);
        if (kw('click')) return emit(T.CLICK, p, p + 5);
      case 108:
        if (kw('link')) return emit(T.LINK, p, p + 4);
      case 110:
        if (kw('note for')) return emit(T.NOTE_FOR, p, p + 8);
        if (kw('note')) return emit(T.NOTE, p, p + 4);
      case 60:
        if (charCodeAt(src, p + 1) == 60) {
          return emit(T.ANNOTATION_START, p, p + 2);
        }
      case 62:
        if (charCodeAt(src, p + 1) == 62) {
          return emit(T.ANNOTATION_END, p, p + 2);
        }
      case 104:
        if (kw('href')) return emit(T.HREF, p, p + 4);
    }
    return false;
  }

  bool common(int c) {
    if (keyword(c)) return true;
    final d = charCodeAt(src, p + 1);
    switch (c) {
      case 34:
        push(_S.string);
        p++;
        return true;
      case 126:
        push(_S.generic);
        p++;
        return true;
      case 96:
        push(_S.bqstring);
        p++;
        return true;
      case 95:
        if (kw('_self')) return emit(T.LINK_TARGET, p, p + 5);
        if (kw('_blank')) return emit(T.LINK_TARGET, p, p + 6);
        if (kw('_parent')) return emit(T.LINK_TARGET, p, p + 7);
        if (kw('_top')) return emit(T.LINK_TARGET, p, p + 4);
      case 60:
        return d == 124
            ? emit(T.EXTENSION, p, p + 2)
            : emit(T.DEPENDENCY, p, p + 1);
      case 124:
        return d == 62 && emit(T.EXTENSION, p, p + 2);
      case 62:
        return emit(T.DEPENDENCY, p, p + 1);
      case 42:
        return emit(T.COMPOSITION, p, p + 1);
      case 111:
        if (!isWord(d)) return emit(T.AGGREGATION, p, p + 1);
      case 40:
        return d == 41 && emit(T.LOLLIPOP, p, p + 2);
      case 45:
        return d == 45 ? emit(T.LINE, p, p + 2) : emit(T.MINUS, p, p + 1);
      case 46:
        return d == 46 ? emit(T.DOTTED_LINE, p, p + 2) : emit(T.DOT, p, p + 1);
      case 58:
        var q = p + 1;
        while (q < n) {
          final ch = charCodeAt(src, q);
          if (ch == 58 || ch == 10 || ch == 59) break;
          q++;
        }
        if (q > p + 1) return emit(T.LABEL, p, q);
        return d == 58 &&
            charCodeAt(src, p + 2) == 58 &&
            emit(T.STYLE_SEPARATOR, p, p + 3);
      case 43:
        return emit(T.PLUS, p, p + 1);
      case 37:
        return emit(T.PCT, p, p + 1);
      case 61:
        return emit(T.EQUALS, p, p + 1);
      case 91:
        return emit(T.SQS, p, p + 1);
      case 93:
        return emit(T.SQE, p, p + 1);
      case 33:
      case 35:
      case 36:
      case 38:
      case 39:
      case 44:
      case 63:
      case 92:
      case 47:
        return emit(T.PUNCTUATION, p, p + 1);
    }
    if (isWord(c)) {
      var q = p + 1;
      while (isWord(charCodeAt(src, q))) {
        q++;
      }
      return emit(T.ALPHA, p, q);
    }
    return isUnicodeLetter(c) && emit(T.UNICODE_TEXT, p, p + 1);
  }

  bool direction() {
    if (dirNext == -1 || p < dirFailed) return false;
    if (dirNext < p) dirNext = src.indexOf('direction', p);
    if (dirNext == -1) return false;
    if (lineEnd < p) {
      lineEnd = _findLineEnd(src, p);
    }
    if (dirNext >= lineEnd) return false;
    for (var i = 0; i < 4; i++) {
      final end = matchSticky(_RE_DIRECTION[i], src, p);
      if (end != -1) return emit(T.direction_tb + i, p, end);
    }
    // No direction statement starts anywhere in the rest of this line either.
    dirFailed = lineEnd;
    return false;
  }

  bool initial(int c) {
    if (direction()) return true;
    if (isSpace(c)) {
      space(false);
      return true;
    }
    switch (c) {
      case 37:
        if (charCodeAt(src, p + 1) == 37) {
          var e = until('\n');
          while (e < n &&
              (charCodeAt(src, e) == 10 || charCodeAt(src, e) == 13)) {
            e++;
          }
          p = e;
          return true;
        }
      case 97:
        final title = src.startsWith('accTitle', p);
        if (!title && !src.startsWith('accDescr', p)) break;
        final q = skipWs(p + 8);
        final d = charCodeAt(src, q);
        if (d == 58) {
          emit(title ? T.acc_title : T.acc_descr, p, skipWs(q + 1));
          push(title ? _S.accTitle : _S.accDescr);
          return true;
        }
        if (d == 123 && !title) {
          p = skipWs(q + 1);
          push(_S.accDescrMultiline);
          return true;
        }
      case 99:
        if (kw('classDiagram-v2')) return emit(T.CLASS_DIAGRAM, p, p + 15);
        if (kw('classDiagram')) return emit(T.CLASS_DIAGRAM, p, p + 12);
        if (src.startsWith('call', p) && isSpace(charCodeAt(src, p + 4))) {
          p = skipWs(p + 4);
          push(_S.callbackName);
          return true;
        }
        if (kw('classDef')) return emit(T.CLASSDEF, p, p + 8);
        if (kw('class')) {
          push(_S.cls);
          return emit(T.CLASS, p, p + 5);
        }
      case 91:
        if (src.startsWith('*]', p + 1)) return emit(T.EDGE_STATE, p, p + 3);
      case 115:
        if (kw('style')) return emit(T.STYLE, p, p + 5);
      case 110:
        if (kw('namespace')) {
          push(_S.namespace);
          return emit(T.NAMESPACE, p, p + 9);
        }
      case 44:
        return emit(T.COMMA, p, p + 1);
      case 35:
        return emit(T.BRKT, p, p + 1);
    }
    return common(c) || (c == 58 && emit(T.COLON, p, p + 1));
  }

  while (true) {
    if (p >= n) {
      types.add(_AT_END[state]);
      texts.add('');
      starts.add(n);
      break;
    }
    final c = charCodeAt(src, p);
    var ok = true;
    switch (state) {
      case _S.INITIAL:
        ok = initial(c);

      case _S.cls:
        if (isSpace(c)) {
          space(true);
        } else if (c == 125) {
          pop();
          pop();
          emit(T.STRUCT_STOP, p, p + 1);
        } else if (c == 123) {
          push(_S.classBody);
          emit(T.STRUCT_START, p, p + 1);
        } else {
          ok = common(c);
        }

      case _S.classBody:
        if (c == 34) {
          push(_S.string);
          p++;
        } else if (c == 125) {
          pop();
          emit(T.STRUCT_STOP, p, p + 1);
        } else if (c == 91 && src.startsWith('*]', p + 1)) {
          emit(T.EDGE_STATE, p, p + 3);
        } else if (c == 123) {
          emit(T.OPEN_IN_STRUCT, p, p + 1);
        } else if (c == 10) {
          p++;
        } else {
          var q = p + 1;
          while (q < n) {
            final ch = charCodeAt(src, q);
            if (ch == 123 || ch == 125 || ch == 10) break;
            q++;
          }
          emit(T.MEMBER, p, q);
        }

      case _S.namespace:
        if (isSpace(c)) {
          space(true);
        } else if (c == 123) {
          push(_S.namespaceBody);
          emit(T.STRUCT_START, p, p + 1);
        } else if (c == 125) {
          // The brace is read again in the state the namespace was opened from.
          pop();
        } else if (c == 110 && kw('namespace')) {
          push(_S.namespace);
          emit(T.NAMESPACE, p, p + 9);
        } else {
          ok = common(c);
        }

      case _S.namespaceBody:
        if (isSpace(c)) {
          space(false);
        } else if (c == 125) {
          pop();
          emit(T.STRUCT_STOP, p, p + 1);
        } else if (c == 110 && kw('namespace')) {
          push(_S.namespace);
          emit(T.NAMESPACE, p, p + 9);
        } else if (c == 91 && src.startsWith('*]', p + 1)) {
          emit(T.EDGE_STATE, p, p + 3);
        } else if (c == 99 && kw('class')) {
          push(_S.cls);
          emit(T.CLASS, p, p + 5);
        } else {
          ok = common(c);
        }

      case _S.string:
        if (c == 34) {
          pop();
          p++;
        } else {
          emit(T.STR, p, until('"'));
        }

      case _S.generic:
        if (c == 34) {
          push(_S.string);
          p++;
        } else if (keyword(c)) {
          break;
        } else if (c == 126) {
          pop();
          p++;
        } else {
          emit(T.GENERICTYPE, p, until('~'));
        }

      case _S.bqstring:
        if (c == 34) {
          push(_S.string);
          p++;
        } else if (keyword(c)) {
          break;
        } else if (c == 126) {
          push(_S.generic);
          p++;
        } else if (c == 96) {
          pop();
          p++;
        } else {
          emit(T.BQUOTE_STR, p, until('`'));
        }

      case _S.callbackName:
        if (c == 40) {
          final q = skipWs(p + 1);
          pop();
          if (charCodeAt(src, q) == 41) {
            p = q + 1;
          } else {
            push(_S.callbackArgs);
            p++;
          }
        } else {
          emit(T.CALLBACK_NAME, p, until('('));
        }

      case _S.callbackArgs:
        if (c == 41) {
          pop();
          p++;
        } else {
          emit(T.CALLBACK_ARGS, p, until(')'));
        }

      case _S.accTitle:
      case _S.accDescr:
        emit(
          state == _S.accTitle ? T.acc_title_value : T.acc_descr_value,
          p,
          until('\n'),
        );
        pop();

      case _S.accDescrMultiline:
        if (c == 125) {
          pop();
          p++;
        } else {
          emit(T.acc_descr_multiline_value, p, until('}'));
        }
    }

    if (!ok) {
      types.add(T.ERROR);
      texts.add('');
      starts.add(p);
      return Tokens(types: types, texts: texts, starts: starts);
    }
  }

  types.add(T.END);
  texts.add('');
  starts.add(n);
  return Tokens(types: types, texts: texts, starts: starts);
}

// Upstream: src/diagrams/agentflow/lexer.ts

import 'dart:math' as math;
import 'dart:typed_data';

import '../../util/chars.dart';
import '../../util/math_js.dart';
import '../../util/unicode.dart';
import 'tokens.dart';

class Tokens {
  const Tokens({
    required this.types,
    required this.texts,
    required this.starts,
    required this.locs,
  });

  final List<int> types;
  final List<String> texts;
  final List<int> starts;
  // Four numbers per token, counted the way Jison counts them:
  // first line, first column, last line, last column. Lines start at 1, columns at 0.
  final List<int> locs;
}

abstract final class _S {
  static const int INITIAL = 0;
  static const int string = 1;
  static const int md_string = 2;
  static const int acc_title = 3;
  static const int acc_descr = 4;
  static const int acc_descr_multiline = 5;
  static const int dir = 6;
  static const int text = 7;
  static const int ellipseText = 8;
  static const int trapText = 9;
  static const int edgeText = 10;
  static const int click = 11;
  static const int callbackname = 12;
  static const int callbackargs = 13;
  static const int shapeData = 14;
  static const int shapeDataStr = 15;
}

final Uint8List _nodeChar = () {
  final out = Uint8List(128);
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!"#\$%&\'*+.`?\\_/';
  for (var i = 0; i < chars.length; i++) {
    out[chars.codeUnitAt(i)] = 1;
  }
  return out;
}();

final RegExp _reAccTitle = RegExp(r'accTitle\s*:\s*');
final RegExp _reAccDescr = RegExp(r'accDescr\s*:\s*');
final RegExp _reAccDescrMl = RegExp(r'accDescr\s*\{\s*');
final RegExp _reCall = RegExp(r'call\s+');
final RegExp _reClick = RegExp(r'click\s+');
final RegExp _reNodir = RegExp(r'(?:\r?\n)*\s*\n');
final RegExp _reDir = RegExp(r'\s*(?:LR|RL|TB|BT|TD|BR)\b');
final RegExp _reDirSym = RegExp(r'\s*[<>^]');
final RegExp _reDirV = RegExp(r'\s*v\b');
final List<RegExp> _reDirection = <RegExp>[
  RegExp(r'[^\n\r\u2028\u2029]*direction\s+TB[^\n]*'),
  RegExp(r'[^\n\r\u2028\u2029]*direction\s+BT[^\n]*'),
  RegExp(r'[^\n\r\u2028\u2029]*direction\s+RL[^\n]*'),
  RegExp(r'[^\n\r\u2028\u2029]*direction\s+LR[^\n]*'),
  RegExp(r'[^\n\r\u2028\u2029]*direction\s+TD[^\n]*'),
];
final RegExp _reEmptyCall = RegExp(r'\(\s*\)');
final RegExp _reBr = RegExp(r'\n\s*');

Tokens tokenize(String src) {
  final n = src.length;
  final types = <int>[];
  final texts = <String>[];
  final starts = <int>[];
  final locs = <int>[];
  final stack = <int>[];
  var state = _S.INITIAL;
  var p = 0;
  var line = 1;
  var col = 0;
  var firstGraph = true;
  var dirNext = src.indexOf('direction');
  var atNext = src.indexOf('@');
  var lineEnd = -1;
  var dirFailed = 0;
  var runEnd = 0;
  var runAt = -1;
  var wsFrom = -1;
  var wsTo = -1;
  var blankFrom = -1;
  var blankTo = -1;
  var noLink = -1;
  var noArrow = -1;

  // Moves over one match. Jison counts \r\n, \r and \n as one line break each, and after a
  // break its column stops at the first U+2028 or U+2029.
  void advance(int e) {
    var brk = -1;
    for (var k = p; k < e; k++) {
      final ch = charCodeAt(src, k);
      if (ch == 10) {
        line++;
        brk = k;
      } else if (ch == 13) {
        if (k + 1 < e && charCodeAt(src, k + 1) == 10) k++;
        line++;
        brk = k;
      }
    }
    if (brk < 0) {
      col += e - p;
    } else {
      var k = brk + 1;
      while (k < e) {
        final ch = charCodeAt(src, k);
        if (ch == 0x2028 || ch == 0x2029) break;
        k++;
      }
      col = k - brk - 1;
    }
    p = e;
  }

  void emit(int type, int e) {
    types.add(type);
    texts.add(src.substring(p, e));
    starts.add(p);
    locs.addAll(<int>[line, col]);
    advance(e);
    locs.addAll(<int>[line, col]);
  }

  // For a token that cannot hold a line break.
  void emitFlat(int type, int e) {
    types.add(type);
    texts.add(src.substring(p, e));
    starts.add(p);
    locs.addAll(<int>[line, col]);
    col += e - p;
    p = e;
    locs.addAll(<int>[line, col]);
  }

  // For a run that Jison matches one character at a time, where \r\n counts as two line breaks.
  void emitChars(int type, int e) {
    types.add(type);
    texts.add(src.substring(p, e));
    starts.add(p);
    locs.addAll(<int>[line, col]);
    for (var k = p; k < e; k++) {
      final ch = charCodeAt(src, k);
      if (ch == 10 || ch == 13) {
        line++;
        col = 0;
      } else {
        col++;
      }
    }
    p = e;
    locs.addAll(<int>[line, col]);
  }

  void emitText(int type, String text, int e) {
    types.add(type);
    texts.add(text);
    starts.add(p);
    locs.addAll(<int>[line, col]);
    advance(e);
    locs.addAll(<int>[line, col]);
  }

  void push(int s) {
    stack.add(state);
    state = s;
  }

  void pop() {
    if (stack.isNotEmpty) state = stack.removeLast();
  }

  int at(RegExp re, int q) => matchSticky(re, src, q);

  bool kw(String word) =>
      src.startsWith(word, p) && !isWord(charCodeAt(src, p + word.length));

  // End of the run of whitespace starting at q. The last run is kept, so asking again from inside it costs nothing.
  int wsEnd(int q) {
    if (q >= wsFrom && q <= wsTo) return wsTo;
    var j = q;
    while (j < n && isSpace(charCodeAt(src, j))) {
      j++;
    }
    wsFrom = q;
    wsTo = j;
    return j;
  }

  int blankEnd(int q) {
    if (q >= blankFrom && q <= blankTo) return blankTo;
    var j = q;
    while (j < n) {
      final ch = charCodeAt(src, j);
      if (ch != 32 && ch != 9) break;
      j++;
    }
    blankFrom = q;
    blankTo = j;
    return j;
  }

  // End of `\s*--+[x>]\s*` starting at q, or -1.
  int arrowEnd(int q) {
    final j = wsEnd(q);
    if (j == noArrow ||
        charCodeAt(src, j) != 45 ||
        charCodeAt(src, j + 1) != 45) {
      return -1;
    }
    var k = j + 2;
    while (charCodeAt(src, k) == 45) {
      k++;
    }
    final t = charCodeAt(src, k);
    if (t == 120 || t == 62) return wsEnd(k + 1);
    noArrow = j;
    return -1;
  }

  bool link() {
    final j = wsEnd(p);
    if (j == noLink || charCodeAt(src, j) != 45) return false;
    final d = charCodeAt(src, j + 1);
    var k = j + 2;
    if (d == 45) {
      while (charCodeAt(src, k) == 45) {
        k++;
      }
      final t = charCodeAt(src, k);
      if (t == 120 || t == 62) {
        emit(T.LINK, wsEnd(k + 1));
      } else {
        push(_S.edgeText);
        emit(T.START_LINK, wsEnd(j + 2));
      }
      return true;
    }
    if (d == 46) {
      while (charCodeAt(src, k) == 46) {
        k++;
      }
      if (charCodeAt(src, k) == 45) {
        emit(T.LINK, wsEnd(k + 1));
        return true;
      }
    }
    noLink = j;
    return false;
  }

  // `%%` not followed by `{`, through the end of the line.
  int commentEnd(int q) {
    if (charCodeAt(src, q) != 37 ||
        charCodeAt(src, q + 1) != 37 ||
        charCodeAt(src, q + 2) == 123) {
      return -1;
    }
    final e = src.indexOf('\n', q + 2);
    return e == -1 ? n : e;
  }

  void quote() {
    if (charCodeAt(src, p + 1) == 96) {
      push(_S.md_string);
      advance(p + 2);
    } else {
      push(_S.string);
      advance(p + 1);
    }
  }

  bool opener(int c) {
    final d = charCodeAt(src, p + 1);
    if (c == 40) {
      if (d == 45) {
        push(_S.ellipseText);
        emitFlat(T.ELLIPSE_START, p + 2);
      } else if (d == 91) {
        push(_S.text);
        emitFlat(T.STADIUMSTART, p + 2);
      } else if (d == 40 && charCodeAt(src, p + 2) == 40) {
        push(_S.text);
        emitFlat(T.DOUBLECIRCLESTART, p + 3);
      } else {
        push(_S.text);
        emitFlat(T.PS, p + 1);
      }
      return true;
    }
    if (c == 91) {
      if (d == 91) {
        push(_S.text);
        emitFlat(T.SUBROUTINESTART, p + 2);
      } else if (d == 40) {
        push(_S.text);
        emitFlat(T.CYLINDERSTART, p + 2);
      } else if (d == 47) {
        push(_S.trapText);
        emitFlat(T.TRAPSTART, p + 2);
      } else if (d == 92) {
        push(_S.trapText);
        emitFlat(T.INVTRAPSTART, p + 2);
      } else {
        push(_S.text);
        emitFlat(T.SQS, p + 1);
      }
      return true;
    }
    if (c == 124) {
      push(_S.text);
      emitFlat(T.PIPE, p + 1);
      return true;
    }
    if (c == 123) {
      push(_S.text);
      emitFlat(T.DIAMOND_START, p + 1);
      return true;
    }
    return false;
  }

  bool nodeString() {
    var q = p;
    while (q < n) {
      final ch = charCodeAt(src, q);
      if (ch >= 0 && ch < 128 && _nodeChar[ch] == 1) {
        q++;
      } else if (ch == 45 && q + 1 < n) {
        final d = charCodeAt(src, q + 1);
        if (d == 62 || d == 45 || d == 46) break;
        q++;
      } else {
        break;
      }
    }
    if (q == p) return false;
    emitFlat(T.NODE_STRING, q);
    return true;
  }

  int blanks(int from) {
    var e = from;
    while (e < n) {
      final ch = charCodeAt(src, e);
      if (ch != 32 && ch != 9) break;
      e++;
    }
    return e;
  }

  bool initial(int c) {
    int e;
    switch (c) {
      case 97:
        if (src.startsWith('acc', p)) {
          if ((e = at(_reAccTitle, p)) >= 0) {
            push(_S.acc_title);
            emit(T.acc_title, e);
            return true;
          }
          if ((e = at(_reAccDescr, p)) >= 0) {
            push(_S.acc_descr);
            emit(T.acc_descr, e);
            return true;
          }
          if ((e = at(_reAccDescrMl, p)) >= 0) {
            push(_S.acc_descr_multiline);
            advance(e);
            return true;
          }
        }
        if (kw('agentflow-beta')) {
          if (firstGraph) {
            firstGraph = false;
            push(_S.dir);
          }
          emitFlat(T.GRAPH, p + 14);
          return true;
        }
      case 64:
        if (charCodeAt(src, p + 1) == 123) {
          push(_S.shapeData);
          emitText(T.SHAPE_DATA, '', p + 2);
          return true;
        }
      case 99:
        if ((e = at(_reCall, p)) >= 0) {
          push(_S.callbackname);
          advance(e);
          return true;
        }
        if (kw('classDef')) {
          emitFlat(T.CLASSDEF, p + 8);
          return true;
        }
        if (kw('class')) {
          emitFlat(T.CLASS, p + 5);
          return true;
        }
        if ((e = at(_reClick, p)) >= 0) {
          push(_S.click);
          advance(e);
          return true;
        }
        if (kw('connector')) {
          emitFlat(T.connector, p + 9);
          return true;
        }
      case 34:
        quote();
        return true;
      case 115:
        if (kw('style')) {
          emitFlat(T.STYLE, p + 5);
          return true;
        }
      case 100:
        if (kw('default')) {
          emitFlat(T.DEFAULT, p + 7);
          return true;
        }
      case 108:
        if (kw('linkStyle')) {
          emitFlat(T.LINKSTYLE, p + 9);
          return true;
        }
      case 105:
        if (kw('interpolate')) {
          emitFlat(T.INTERPOLATE, p + 11);
          return true;
        }
      case 104:
        if (src.startsWith('href', p) && isSpace(charCodeAt(src, p + 4))) {
          emit(T.HREF, p + 5);
          return true;
        }
      case 102:
        if (kw('flow')) {
          emitFlat(T.flow, p + 4);
          return true;
        }
      case 103:
        if (kw('global')) {
          emitFlat(T.global, blanks(p + 6));
          return true;
        }
      case 101:
        if (kw('end')) {
          emitFlat(T.end, blanks(p + 3));
          return true;
        }
      case 95:
        if (kw('_self')) {
          emitFlat(T.LINK_TARGET, p + 5);
          return true;
        }
        if (kw('_blank')) {
          emitFlat(T.LINK_TARGET, p + 6);
          return true;
        }
        if (kw('_parent')) {
          emitFlat(T.LINK_TARGET, p + 7);
          return true;
        }
        if (kw('_top')) {
          emitFlat(T.LINK_TARGET, p + 4);
          return true;
        }
    }

    if (dirNext != -1 && p >= dirFailed) {
      if (dirNext < p) dirNext = src.indexOf('direction', p);
      if (dirNext != -1) {
        if (lineEnd < p) {
          var k = p;
          while (k < n) {
            final ch = charCodeAt(src, k);
            if (ch == 10 || ch == 13 || ch == 0x2028 || ch == 0x2029) break;
            k++;
          }
          lineEnd = k;
        }
        if (dirNext < lineEnd) {
          for (var i = 0; i < 5; i++) {
            if ((e = at(_reDirection[i], p)) >= 0) {
              emit(T.direction_tb + i, e);
              return true;
            }
          }
          // No direction statement starts anywhere in the rest of this line either.
          dirFailed = lineEnd;
        }
      }
    }

    // A link id is a run of non-space characters up to its last `@` that is not followed by `{` or `"`.
    if (atNext != -1 && c != 34 && !isSpace(c)) {
      if (p >= runEnd) {
        if (atNext < p) atNext = src.indexOf('@', p);
        var q = p;
        while (q < n) {
          final ch = charCodeAt(src, q);
          if (ch == 34 || isSpace(ch)) break;
          q++;
        }
        runEnd = q;
        runAt = -1;
        if (atNext != -1 && atNext < q) {
          for (var k = math.min<int>(q, n - 1) - 1; k >= atNext; k--) {
            if (charCodeAt(src, k) != 64) continue;
            final after = charCodeAt(src, k + 1);
            if (after != 123 && after != 34) {
              runAt = k;
              break;
            }
          }
        }
      }
      if (runAt > p) {
        emitFlat(T.LINK_ID, runAt + 1);
        return true;
      }
    }

    if (c >= 48 && c <= 57) {
      var q = p + 1;
      while (q < n) {
        final ch = charCodeAt(src, q);
        if (ch < 48 || ch > 57) break;
        q++;
      }
      emitFlat(T.NUM, q);
      return true;
    }

    switch (c) {
      case 35:
        emitFlat(T.BRKT, p + 1);
        return true;
      case 58:
        if (charCodeAt(src, p + 1) == 58 && charCodeAt(src, p + 2) == 58) {
          emitFlat(T.STYLE_SEPARATOR, p + 3);
        } else {
          emitFlat(T.COLON, p + 1);
        }
        return true;
      case 38:
        emitFlat(T.AMP, p + 1);
        return true;
      case 59:
        emitFlat(T.SEMI, p + 1);
        return true;
      case 44:
        emitFlat(T.COMMA, p + 1);
        return true;
      case 42:
        emitFlat(T.MULT, p + 1);
        return true;
      case 60:
        emitFlat(T.TAGSTART, p + 1);
        return true;
      case 45:
        if (link() || nodeString()) return true;
        emitFlat(T.MINUS, p + 1);
        return true;
      case 40:
        return opener(c);
      case 91:
        if (charCodeAt(src, p + 1) == 124) {
          emitFlat(T.VERTEX_WITH_PROPS_START, p + 2);
          return true;
        }
        return opener(c);
      case 124:
      case 123:
        return opener(c);
      case 62:
        push(_S.text);
        emitFlat(T.TAGEND, p + 1);
        return true;
      case 94:
        emitFlat(T.UP, p + 1);
        return true;
      case 92:
        if (charCodeAt(src, p + 1) == 124) {
          emitFlat(T.SEP, p + 2);
          return true;
        }
        return nodeString();
      case 118:
        if (!isWord(charCodeAt(src, p + 1))) {
          emitFlat(T.DOWN, p + 1);
          return true;
        }
        return nodeString();
      case 37:
        if ((e = commentEnd(p)) >= 0) {
          emit(T.COMMENT, e);
          return true;
        }
        return nodeString();
    }

    if (isSpace(c)) {
      if (link()) return true;
      if ((c == 32 || c == 9) && (e = commentEnd(blankEnd(p))) >= 0) {
        emit(T.COMMENT, e);
        return true;
      }
      e = p;
      while (true) {
        final ch = charCodeAt(src, e);
        if (ch == 10) {
          e++;
        } else if (ch == 13 && charCodeAt(src, e + 1) == 10) {
          e += 2;
        } else {
          break;
        }
      }
      if (e > p) {
        emit(T.NEWLINE, e);
      } else {
        emit(T.SPACE, p + 1);
      }
      return true;
    }

    if (c < 128) return nodeString();
    if (isUnicodeLetter(c)) {
      emitFlat(T.UNICODE_TEXT, p + 1);
      return true;
    }
    return false;
  }

  lexing:
  while (true) {
    if (p >= n) {
      var type = -1;
      switch (state) {
        case _S.INITIAL:
          type = T.EOF;
        case _S.acc_title:
          type = T.acc_title_value;
        case _S.acc_descr:
          type = T.acc_descr_value;
        case _S.acc_descr_multiline:
          type = T.acc_descr_multiline_value;
        case _S.click:
          type = T.CLICK;
        case _S.callbackname:
          type = T.CALLBACKNAME;
        case _S.callbackargs:
          type = T.CALLBACKARGS;
      }
      if (type != -1) emitFlat(type, n);
      break;
    }

    final c = charCodeAt(src, p);
    var ok = true;

    switch (state) {
      case _S.INITIAL:
        ok = initial(c);

      case _S.string:
        if (c == 34) {
          if (charCodeAt(src, p + 1) == 96) {
            push(_S.md_string);
            advance(p + 2);
          } else {
            pop();
            advance(p + 1);
          }
        } else {
          final e = src.indexOf('"', p);
          emit(T.STR, e == -1 ? n : e);
        }

      case _S.md_string:
        if (c == 96) {
          if (charCodeAt(src, p + 1) == 34) {
            pop();
            advance(p + 2);
          } else {
            ok = false;
          }
        } else if (c == 34) {
          quote();
        } else {
          var q = p + 1;
          while (q < n) {
            final ch = charCodeAt(src, q);
            if (ch == 96 || ch == 34) break;
            q++;
          }
          emit(T.MD_STR, q);
        }

      case _S.acc_title:
      case _S.acc_descr:
        var e = src.indexOf('\n', p);
        if (e == -1) e = n;
        final type = state == _S.acc_title
            ? T.acc_title_value
            : T.acc_descr_value;
        pop();
        emit(type, e);

      case _S.acc_descr_multiline:
        if (c == 125) {
          pop();
          advance(p + 1);
        } else {
          var e = src.indexOf('}', p);
          if (e == -1) e = n;
          emit(T.acc_descr_multiline_value, e);
        }

      case _S.dir:
        int e;
        if (c == 34) {
          quote();
        } else if ((e = at(_reNodir, p)) >= 0) {
          pop();
          emit(T.NODIR, e);
        } else if ((e = at(_reDir, p)) >= 0 ||
            (e = at(_reDirSym, p)) >= 0 ||
            (e = at(_reDirV, p)) >= 0) {
          pop();
          emit(T.DIR, e);
        } else {
          ok = opener(c);
        }

      case _S.text:
        final d = charCodeAt(src, p + 1);
        switch (c) {
          case 34:
            quote();
          case 40:
          case 91:
          case 123:
            opener(c);
          case 93:
            pop();
            if (d == 41) {
              emitFlat(T.STADIUMEND, p + 2);
            } else if (d == 93) {
              emitFlat(T.SUBROUTINEEND, p + 2);
            } else {
              emitFlat(T.SQE, p + 1);
            }
          case 41:
            pop();
            if (d == 93) {
              emitFlat(T.CYLINDEREND, p + 2);
            } else if (d == 41 && charCodeAt(src, p + 2) == 41) {
              emitFlat(T.DOUBLECIRCLEEND, p + 3);
            } else {
              emitFlat(T.PE, p + 1);
            }
          case 124:
            pop();
            emitFlat(T.PIPE, p + 1);
          case 125:
            pop();
            emitFlat(T.DIAMOND_STOP, p + 1);
          case 37:
            // Jison drops the lone `%` from Mermaid's text pattern, so only a comment may start with one.
            final e = commentEnd(p);
            if (e >= 0) {
              advance(e);
            } else {
              ok = false;
            }
          default:
            var q = p + 1;
            while (q < n) {
              final ch = charCodeAt(src, q);
              if (ch == 91 ||
                  ch == 93 ||
                  ch == 40 ||
                  ch == 41 ||
                  ch == 123 ||
                  ch == 125 ||
                  ch == 124 ||
                  ch == 34 ||
                  ch == 37) {
                break;
              }
              q++;
            }
            emit(T.TEXT, q);
        }

      case _S.ellipseText:
        final d = charCodeAt(src, p + 1);
        int e;
        if (c == 34) {
          quote();
        } else if (c == 37 && (e = commentEnd(p)) >= 0) {
          advance(e);
        } else if ((c == 45 || c == 47 || c == 41) && d == 41) {
          pop();
          emitFlat(T.ELLIPSE_END, p + 2);
        } else if (c == 40 || c == 91 || c == 123) {
          opener(c);
        } else if (c == 41 || c == 93 || c == 125) {
          ok = false;
        } else {
          var q = p + 1;
          while (q < n) {
            final ch = charCodeAt(src, q);
            if (ch == 34 ||
                ch == 40 ||
                ch == 41 ||
                ch == 91 ||
                ch == 93 ||
                ch == 123 ||
                ch == 125) {
              break;
            }
            if ((ch == 45 || ch == 47) && charCodeAt(src, q + 1) == 41) break;
            if (ch == 37 &&
                charCodeAt(src, q + 1) == 37 &&
                charCodeAt(src, q + 2) != 123) {
              break;
            }
            q++;
          }
          emitChars(T.TEXT, q);
        }

      case _S.trapText:
        final d = charCodeAt(src, p + 1);
        if (c == 34) {
          quote();
          break;
        }
        switch (c) {
          case 40:
            if (d == 45 ||
                d == 91 ||
                (d == 40 && charCodeAt(src, p + 2) == 40)) {
              opener(c);
            } else if (d == 93) {
              pop();
              emitFlat(T.TRAPEND, p + 2);
            } else {
              opener(c);
            }
          case 91:
          case 123:
            opener(c);
          case 92:
            if (d == 93) {
              pop();
              emitFlat(T.TRAPEND, p + 2);
            } else {
              emitFlat(T.TEXT, p + 1);
            }
          case 47:
            if (d == 93) {
              pop();
              emitFlat(T.INVTRAPEND, p + 2);
            } else {
              emitFlat(T.TEXT, p + 1);
            }
          case 93:
          case 41:
            if (d == 93) {
              pop();
              emitFlat(T.TRAPEND, p + 2);
            } else {
              ok = false;
            }
          case 125:
            ok = false;
          case 37:
            final e = commentEnd(p);
            if (e >= 0) {
              advance(e);
            } else {
              ok = false;
            }
          default:
            if ((c == 63 || c == 61) && d == 93) {
              pop();
              emitFlat(T.TRAPEND, p + 2);
              break;
            }
            var q = p + 1;
            while (q < n) {
              final ch = charCodeAt(src, q);
              if (ch == 92 ||
                  ch == 91 ||
                  ch == 93 ||
                  ch == 40 ||
                  ch == 41 ||
                  ch == 123 ||
                  ch == 125 ||
                  ch == 47 ||
                  ch == 37) {
                break;
              }
              q++;
            }
            emit(T.TEXT, q);
        }

      case _S.edgeText:
        if (c == 34) {
          quote();
          break;
        }
        final e = arrowEnd(p);
        if (e >= 0) {
          pop();
          emit(T.LINK, e);
          break;
        }
        if (c == 45 && charCodeAt(src, p + 1) == 45) {
          ok = false;
          break;
        }
        var q = p + 1;
        while (q < n) {
          final ch = charCodeAt(src, q);
          if (ch == 34) break;
          if (ch == 45) {
            if (charCodeAt(src, q + 1) == 45) break;
          } else if (isSpace(ch) && arrowEnd(q) >= 0) {
            break;
          }
          q++;
        }
        emitChars(T.EDGE_TEXT, q);

      case _S.click:
        if (c == 34) {
          quote();
        } else if (isSpace(c)) {
          pop();
          advance(p + 1);
        } else {
          var q = p + 1;
          while (q < n && !isSpace(charCodeAt(src, q))) {
            q++;
          }
          emitFlat(T.CLICK, q);
        }

      case _S.callbackname:
        if (c == 40) {
          final e = at(_reEmptyCall, p);
          pop();
          if (e >= 0) {
            advance(e);
          } else {
            push(_S.callbackargs);
            advance(p + 1);
          }
        } else {
          var e = src.indexOf('(', p);
          if (e == -1) e = n;
          emit(T.CALLBACKNAME, e);
        }

      case _S.callbackargs:
        if (c == 41) {
          pop();
          advance(p + 1);
        } else {
          var e = src.indexOf(')', p);
          if (e == -1) e = n;
          emit(T.CALLBACKARGS, e);
        }

      case _S.shapeData:
        if (c == 34) {
          push(_S.shapeDataStr);
          emitFlat(T.SHAPE_DATA, p + 1);
        } else if (c == 125) {
          pop();
          advance(p + 1);
        } else if (c == 94) {
          ok = false;
        } else {
          var q = p + 1;
          while (q < n) {
            final ch = charCodeAt(src, q);
            if (ch == 125 || ch == 94 || ch == 34) break;
            q++;
          }
          emit(T.SHAPE_DATA, q);
        }

      case _S.shapeDataStr:
        if (c == 34) {
          pop();
          emitFlat(T.SHAPE_DATA, p + 1);
        } else {
          var e = src.indexOf('"', p);
          if (e == -1) e = n;
          emitText(
            T.SHAPE_DATA,
            src.substring(p, e).replaceAll(_reBr, '<br/>'),
            e,
          );
        }
    }

    if (!ok) {
      types.add(T.ERROR);
      texts.add('');
      starts.add(p);
      locs.addAll(<int>[line, col, line, col]);
      return Tokens(types: types, texts: texts, starts: starts, locs: locs);
    }
    continue lexing;
  }

  types.add(T.END);
  texts.add('');
  starts.add(n);
  locs.addAll(<int>[line, col, line, col]);
  return Tokens(types: types, texts: texts, starts: starts, locs: locs);
}

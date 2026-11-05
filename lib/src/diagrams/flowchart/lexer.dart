// Upstream: src/diagrams/flowchart/lexer.ts

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
  });

  final List<int> types;
  final List<String> texts;
  final List<int> starts;
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
  static const int thickEdgeText = 11;
  static const int dottedEdgeText = 12;
  static const int click = 13;
  static const int callbackname = 14;
  static const int callbackargs = 15;
  static const int shapeData = 16;
  static const int shapeDataStr = 17;
}

final Uint8List _nodeChar = () {
  final table = Uint8List(128);
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!"#\$%&\'*+.`?\\_/';
  for (var i = 0; i < chars.length; i++) {
    table[chars.codeUnitAt(i)] = 1;
  }
  return table;
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
final RegExp _reLink = RegExp(r'\s*[xo<]?--+[-xo>]\s*');
final RegExp _reStartLink = RegExp(r'\s*[xo<]?--\s*');
final RegExp _reThickLink = RegExp(r'\s*[xo<]?==+[=xo>]\s*');
final RegExp _reThickStart = RegExp(r'\s*[xo<]?==\s*');
final RegExp _reDottedLink = RegExp(r'\s*[xo<]?-?\.+-[xo>]?\s*');
final RegExp _reDottedStart = RegExp(r'\s*[xo<]?-\.\s*');
final RegExp _reInvisLink = RegExp(r'\s*~~~+\s*');
final RegExp _reNewline = RegExp(r'(?:\r?\n)+');
final RegExp _reSpace = RegExp(r'[^\S\n\r]+');
final RegExp _reEmptyCall = RegExp(r'\(\s*\)');
final RegExp _reBr = RegExp(r'\n\s*');

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
  var firstGraph = true;
  var dirNext = src.indexOf('direction');
  var atNext = src.indexOf('@');
  var lineEnd = -1;
  var dirFailed = 0;
  var runEnd = 0;
  var runAt = -1;
  var wsFrom = -1;
  var wsTo = -1;

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

  bool kw(String word) =>
      src.startsWith(word, p) && !isWord(charCodeAt(src, p + word.length));

  // First character after any run of whitespace starting at q, skipping one optional x, o or <.
  int linkChar(int q) {
    var j = q;
    if (q >= wsFrom && q <= wsTo) {
      j = wsTo;
    } else if (isSpace(charCodeAt(src, q))) {
      while (j < n && isSpace(charCodeAt(src, j))) {
        j++;
      }
      wsFrom = q;
      wsTo = j;
    }
    final d = charCodeAt(src, j);
    return (d == 120 || d == 111 || d == 60) ? charCodeAt(src, j + 1) : d;
  }

  bool invisAhead(int q) {
    var j = q;
    if (q >= wsFrom && q <= wsTo) {
      j = wsTo;
    } else if (isSpace(charCodeAt(src, q))) {
      while (j < n && isSpace(charCodeAt(src, j))) {
        j++;
      }
      wsFrom = q;
      wsTo = j;
    }
    return charCodeAt(src, j) == 126;
  }

  void quote() {
    if (charCodeAt(src, p + 1) == 96) {
      push(_S.md_string);
      p += 2;
    } else {
      push(_S.string);
      p++;
    }
  }

  bool invisLink() {
    if (!invisAhead(p)) return false;
    final e = at(_reInvisLink, p);
    if (e < 0) return false;
    emit(T.LINK, p, e);
    return true;
  }

  bool opener(int c) {
    final d = charCodeAt(src, p + 1);
    if (c == 40) {
      if (d == 45) {
        push(_S.ellipseText);
        emit(T.ELLIPSE_START, p, p + 2);
      } else if (d == 91) {
        push(_S.text);
        emit(T.STADIUMSTART, p, p + 2);
      } else if (d == 40 && charCodeAt(src, p + 2) == 40) {
        push(_S.text);
        emit(T.DOUBLECIRCLESTART, p, p + 3);
      } else {
        push(_S.text);
        emit(T.PS, p, p + 1);
      }
      return true;
    }
    if (c == 91) {
      if (d == 91) {
        push(_S.text);
        emit(T.SUBROUTINESTART, p, p + 2);
      } else if (d == 40) {
        push(_S.text);
        emit(T.CYLINDERSTART, p, p + 2);
      } else if (d == 47) {
        push(_S.trapText);
        emit(T.TRAPSTART, p, p + 2);
      } else if (d == 92) {
        push(_S.trapText);
        emit(T.INVTRAPSTART, p, p + 2);
      } else {
        push(_S.text);
        emit(T.SQS, p, p + 1);
      }
      return true;
    }
    if (c == 124) {
      push(_S.text);
      emit(T.PIPE, p, p + 1);
      return true;
    }
    if (c == 123) {
      push(_S.text);
      emit(T.DIAMOND_START, p, p + 1);
      return true;
    }
    return false;
  }

  void graph(int len) {
    if (firstGraph) {
      firstGraph = false;
      push(_S.dir);
    }
    emit(T.GRAPH, p, p + len);
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
    emit(T.NODE_STRING, p, q);
    return true;
  }

  bool link(int c) {
    final d = linkChar(p);
    int e;
    if (d == 45) {
      if ((e = at(_reLink, p)) >= 0) {
        emit(T.LINK, p, e);
        return true;
      }
      if ((e = at(_reStartLink, p)) >= 0) {
        push(_S.edgeText);
        emit(T.START_LINK, p, e);
        return true;
      }
      if ((e = at(_reDottedLink, p)) >= 0) {
        emit(T.LINK, p, e);
        return true;
      }
      if ((e = at(_reDottedStart, p)) >= 0) {
        push(_S.dottedEdgeText);
        emit(T.START_LINK, p, e);
        return true;
      }
    } else if (d == 61) {
      if ((e = at(_reThickLink, p)) >= 0) {
        emit(T.LINK, p, e);
        return true;
      }
      if ((e = at(_reThickStart, p)) >= 0) {
        push(_S.thickEdgeText);
        emit(T.START_LINK, p, e);
        return true;
      }
    } else if (d == 46) {
      if ((e = at(_reDottedLink, p)) >= 0) {
        emit(T.LINK, p, e);
        return true;
      }
    }
    return c != 45 && c != 61 && c != 46 && invisLink();
  }

  bool initial(int c) {
    int e;
    switch (c) {
      case 97:
        if (src.startsWith('acc', p)) {
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
      case 64:
        if (charCodeAt(src, p + 1) == 123) {
          push(_S.shapeData);
          types.add(T.SHAPE_DATA);
          texts.add('');
          starts.add(p);
          p += 2;
          return true;
        }
      case 99:
        if ((e = at(_reCall, p)) >= 0) {
          push(_S.callbackname);
          p = e;
          return true;
        }
        if (kw('classDef')) {
          emit(T.CLASSDEF, p, p + 8);
          return true;
        }
        if (kw('class')) {
          emit(T.CLASS, p, p + 5);
          return true;
        }
        if ((e = at(_reClick, p)) >= 0) {
          push(_S.click);
          p = e;
          return true;
        }
      case 34:
        quote();
        return true;
      case 115:
        if (kw('style')) {
          emit(T.STYLE, p, p + 5);
          return true;
        }
        if (kw('swimlane-beta')) {
          graph(13);
          return true;
        }
        if (kw('subgraph')) {
          emit(T.subgraph, p, p + 8);
          return true;
        }
      case 100:
        if (kw('default')) {
          emit(T.DEFAULT, p, p + 7);
          return true;
        }
      case 108:
        if (kw('linkStyle')) {
          emit(T.LINKSTYLE, p, p + 9);
          return true;
        }
      case 105:
        if (kw('interpolate')) {
          emit(T.INTERPOLATE, p, p + 11);
          return true;
        }
      case 104:
        if (src.startsWith('href', p) && isSpace(charCodeAt(src, p + 4))) {
          emit(T.HREF, p, p + 5);
          return true;
        }
      case 102:
        if (kw('flowchart-elk')) {
          graph(13);
          return true;
        }
        if (kw('flowchart')) {
          graph(9);
          return true;
        }
      case 103:
        if (kw('graph')) {
          graph(5);
          return true;
        }
      case 101:
        if (kw('end')) {
          e = p + 3;
          while (e < n && isSpace(charCodeAt(src, e))) {
            e++;
          }
          emit(T.end, p, e);
          return true;
        }
      case 95:
        if (kw('_self')) {
          emit(T.LINK_TARGET, p, p + 5);
          return true;
        }
        if (kw('_blank')) {
          emit(T.LINK_TARGET, p, p + 6);
          return true;
        }
        if (kw('_parent')) {
          emit(T.LINK_TARGET, p, p + 7);
          return true;
        }
        if (kw('_top')) {
          emit(T.LINK_TARGET, p, p + 4);
          return true;
        }
    }

    if (dirNext != -1 && p >= dirFailed) {
      if (dirNext < p) dirNext = src.indexOf('direction', p);
      if (dirNext != -1) {
        if (lineEnd < p) {
          lineEnd = _findLineEnd(src, p);
        }
        if (dirNext < lineEnd) {
          for (var i = 0; i < 5; i++) {
            if ((e = at(_reDirection[i], p)) >= 0) {
              emit(T.direction_tb + i, p, e);
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
        emit(T.LINK_ID, p, runAt + 1);
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
      emit(T.NUM, p, q);
      return true;
    }

    switch (c) {
      case 35:
        emit(T.BRKT, p, p + 1);
        return true;
      case 58:
        if (charCodeAt(src, p + 1) == 58 && charCodeAt(src, p + 2) == 58) {
          emit(T.STYLE_SEPARATOR, p, p + 3);
        } else {
          emit(T.COLON, p, p + 1);
        }
        return true;
      case 38:
        emit(T.AMP, p, p + 1);
        return true;
      case 59:
        emit(T.SEMI, p, p + 1);
        return true;
      case 44:
        emit(T.COMMA, p, p + 1);
        return true;
      case 42:
        emit(T.MULT, p, p + 1);
        return true;
      case 120:
      case 111:
        return link(c) || nodeString();
      case 60:
        if (link(c)) return true;
        emit(T.TAGSTART, p, p + 1);
        return true;
      case 45:
        if (link(c) || nodeString()) return true;
        emit(T.MINUS, p, p + 1);
        return true;
      case 61:
        return link(c);
      case 46:
        return link(c) || nodeString();
      case 126:
        return invisLink();
      case 40:
        return opener(c);
      case 91:
        if (charCodeAt(src, p + 1) == 124) {
          emit(T.VERTEX_WITH_PROPS_START, p, p + 2);
          return true;
        }
        return opener(c);
      case 124:
      case 123:
        return opener(c);
      case 62:
        push(_S.text);
        emit(T.TAGEND, p, p + 1);
        return true;
      case 94:
        emit(T.UP, p, p + 1);
        return true;
      case 92:
        if (charCodeAt(src, p + 1) == 124) {
          emit(T.SEP, p, p + 2);
          return true;
        }
        return nodeString();
      case 118:
        if (!isWord(charCodeAt(src, p + 1))) {
          emit(T.DOWN, p, p + 1);
          return true;
        }
        return nodeString();
    }

    if (isSpace(c)) {
      if (link(c)) return true;
      if ((e = at(_reNewline, p)) >= 0) {
        emit(T.NEWLINE, p, e);
        return true;
      }
      if ((e = at(_reSpace, p)) >= 0) {
        emit(T.SPACE, p, e);
        return true;
      }
      return false;
    }

    if (c < 128) return nodeString();
    if (isUnicodeLetter(c)) {
      emit(T.UNICODE_TEXT, p, p + 1);
      return true;
    }
    return false;
  }

  bool edgeText(int c, RegExp linkRe, int a, int b) {
    if (c == 34) {
      quote();
      return true;
    }
    final d = linkChar(p);
    if (d == a || (b >= 0 && d == b)) {
      final e = at(linkRe, p);
      if (e >= 0) {
        pop();
        emit(T.LINK, p, e);
        return true;
      }
    }
    if (c == a && (a != 45 || charCodeAt(src, p + 1) == 45)) return false;
    var q = p + 1;
    while (q < n) {
      final ch = charCodeAt(src, q);
      if (ch == 34) break;
      if (ch == a) {
        if (a != 45 || charCodeAt(src, q + 1) == 45) break;
      } else if (ch == 120 ||
          ch == 111 ||
          ch == 60 ||
          (b >= 0 && ch == b) ||
          isSpace(ch)) {
        final dd = linkChar(q);
        if ((dd == a || (b >= 0 && dd == b)) && at(linkRe, q) >= 0) break;
      }
      q++;
    }
    emit(T.EDGE_TEXT, p, q);
    return true;
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
      if (type != -1) emit(type, n, n);
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
            p += 2;
          } else {
            pop();
            p++;
          }
        } else {
          final e = src.indexOf('"', p);
          emit(T.STR, p, e == -1 ? n : e);
        }

      case _S.md_string:
        if (c == 96) {
          if (charCodeAt(src, p + 1) == 34) {
            pop();
            p += 2;
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
          emit(T.MD_STR, p, q);
        }

      case _S.acc_title:
      case _S.acc_descr:
        var e = src.indexOf('\n', p);
        if (e == -1) e = n;
        final type = state == _S.acc_title
            ? T.acc_title_value
            : T.acc_descr_value;
        pop();
        emit(type, p, e);

      case _S.acc_descr_multiline:
        if (c == 125) {
          pop();
          p++;
        } else {
          var e = src.indexOf('}', p);
          if (e == -1) e = n;
          emit(T.acc_descr_multiline_value, p, e);
        }

      case _S.dir:
        int e;
        if (c == 34) {
          quote();
        } else if ((e = at(_reNodir, p)) >= 0) {
          pop();
          emit(T.NODIR, p, e);
        } else if ((e = at(_reDir, p)) >= 0 ||
            (e = at(_reDirSym, p)) >= 0 ||
            (e = at(_reDirV, p)) >= 0) {
          pop();
          emit(T.DIR, p, e);
        } else {
          ok = invisLink() || opener(c);
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
              emit(T.STADIUMEND, p, p + 2);
            } else if (d == 93) {
              emit(T.SUBROUTINEEND, p, p + 2);
            } else {
              emit(T.SQE, p, p + 1);
            }
          case 41:
            pop();
            if (d == 93) {
              emit(T.CYLINDEREND, p, p + 2);
            } else if (d == 41 && charCodeAt(src, p + 2) == 41) {
              emit(T.DOUBLECIRCLEEND, p, p + 3);
            } else {
              emit(T.PE, p, p + 1);
            }
          case 124:
            pop();
            emit(T.PIPE, p, p + 1);
          case 125:
            pop();
            emit(T.DIAMOND_STOP, p, p + 1);
          default:
            if ((c == 126 || isSpace(c)) && invisLink()) break;
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
                  ch == 34) {
                break;
              }
              q++;
            }
            emit(T.TEXT, p, q);
        }

      case _S.ellipseText:
        final d = charCodeAt(src, p + 1);
        if (c == 34) {
          quote();
        } else if ((c == 126 || isSpace(c)) && invisLink()) {
          break;
        } else if ((c == 45 || c == 47 || c == 41) && d == 41) {
          pop();
          emit(T.ELLIPSE_END, p, p + 2);
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
            if ((ch == 126 || isSpace(ch)) &&
                invisAhead(q) &&
                at(_reInvisLink, q) >= 0) {
              break;
            }
            q++;
          }
          emit(T.TEXT, p, q);
        }

      case _S.trapText:
        final d = charCodeAt(src, p + 1);
        if (c == 34) {
          quote();
          break;
        }
        if ((c == 126 || isSpace(c)) && invisLink()) break;
        switch (c) {
          case 40:
            if (d == 45 ||
                d == 91 ||
                (d == 40 && charCodeAt(src, p + 2) == 40)) {
              opener(c);
            } else if (d == 93) {
              pop();
              emit(T.TRAPEND, p, p + 2);
            } else {
              opener(c);
            }
          case 91:
          case 123:
            opener(c);
          case 92:
            if (d == 93) {
              pop();
              emit(T.TRAPEND, p, p + 2);
            } else {
              emit(T.TEXT, p, p + 1);
            }
          case 47:
            if (d == 93) {
              pop();
              emit(T.INVTRAPEND, p, p + 2);
            } else {
              emit(T.TEXT, p, p + 1);
            }
          case 93:
          case 41:
            if (d == 93) {
              pop();
              emit(T.TRAPEND, p, p + 2);
            } else {
              ok = false;
            }
          case 125:
            ok = false;
          default:
            if ((c == 63 || c == 61) && d == 93) {
              pop();
              emit(T.TRAPEND, p, p + 2);
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
                  ch == 47) {
                break;
              }
              q++;
            }
            emit(T.TEXT, p, q);
        }

      case _S.edgeText:
        ok = edgeText(c, _reLink, 45, -1);
      case _S.thickEdgeText:
        ok = edgeText(c, _reThickLink, 61, -1);
      case _S.dottedEdgeText:
        ok = edgeText(c, _reDottedLink, 46, 45);

      case _S.click:
        if (c == 34) {
          quote();
        } else if (isSpace(c)) {
          pop();
          p++;
        } else {
          var q = p + 1;
          while (q < n && !isSpace(charCodeAt(src, q))) {
            q++;
          }
          emit(T.CLICK, p, q);
        }

      case _S.callbackname:
        if (c == 40) {
          final e = at(_reEmptyCall, p);
          pop();
          if (e >= 0) {
            p = e;
          } else {
            push(_S.callbackargs);
            p++;
          }
        } else {
          var e = src.indexOf('(', p);
          if (e == -1) e = n;
          emit(T.CALLBACKNAME, p, e);
        }

      case _S.callbackargs:
        if (c == 41) {
          pop();
          p++;
        } else {
          var e = src.indexOf(')', p);
          if (e == -1) e = n;
          emit(T.CALLBACKARGS, p, e);
        }

      case _S.shapeData:
        if (c == 34) {
          push(_S.shapeDataStr);
          emit(T.SHAPE_DATA, p, p + 1);
        } else if (c == 125) {
          pop();
          p++;
        } else if (c == 94) {
          ok = false;
        } else {
          var q = p + 1;
          while (q < n) {
            final ch = charCodeAt(src, q);
            if (ch == 125 || ch == 94 || ch == 34) break;
            q++;
          }
          emit(T.SHAPE_DATA, p, q);
        }

      case _S.shapeDataStr:
        if (c == 34) {
          pop();
          emit(T.SHAPE_DATA, p, p + 1);
        } else {
          var e = src.indexOf('"', p);
          if (e == -1) e = n;
          types.add(T.SHAPE_DATA);
          texts.add(src.substring(p, e).replaceAll(_reBr, '<br/>'));
          starts.add(p);
          p = e;
        }
    }

    if (!ok) {
      types.add(T.ERROR);
      texts.add('');
      starts.add(p);
      return Tokens(types: types, texts: texts, starts: starts);
    }
    continue lexing;
  }

  types.add(T.END);
  texts.add('');
  starts.add(n);
  return Tokens(types: types, texts: texts, starts: starts);
}

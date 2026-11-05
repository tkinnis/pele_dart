// Upstream: src/diagrams/state/lexer.ts

import '../../util/chars.dart';
import '../../util/math_js.dart';
import 'tokens.dart';

class Tokens {
  const Tokens({
    required this.types,
    required this.texts,
    required this.starts,
    this.error,
  });

  final List<int> types;
  final List<String> texts;
  final List<int> starts;
  // Set when lexing stopped on the grammar's own error rather than on unrecognized text.
  final String? error;
}

abstract final class _S {
  static const int INITIAL = 0;
  static const int struct = 1;
  static const int STATE = 2;
  static const int STATE_STRING = 3;
  static const int STATE_ID = 4;
  static const int SCALE = 5;
  static const int acc_title = 6;
  static const int acc_descr = 7;
  static const int acc_descr_multiline = 8;
  static const int CLASSDEF = 9;
  static const int CLASSDEFID = 10;
  static const int CLASS = 11;
  static const int CLASS_STYLE = 12;
  static const int STYLE = 13;
  static const int STYLEDEF_STYLES = 14;
  static const int NOTE = 15;
  static const int NOTE_ID = 16;
  static const int NOTE_TEXT = 17;
  static const int FLOATING_NOTE = 18;
  static const int FLOATING_NOTE_ID = 19;
}

final RegExp _reDirection = RegExp(r'direction', caseSensitive: false);
final RegExp _reStereotype = RegExp(
  r'<<(?:fork|join|choice)>>|\[\[(?:fork|join|choice)\]\]',
  caseSensitive: false,
);
final RegExp _reLineEnd = RegExp(r'[\n\r\u2028\u2029]');
final RegExp _rePercent = RegExp(r'%%');
final RegExp _reBrace = RegExp(r'\{');

// Finds the next match of a pattern at or after a position, remembering the answer so that
// asking at each token costs one scan of the text in total.
int Function(int q) _finder(RegExp re, String src) {
  var from = 0;
  var next = -2;
  return (int q) {
    if (next == -2 || q < from || (next != -1 && q > next)) {
      if (q < 0 || q > src.length) {
        next = -1;
      } else {
        final it = re.allMatches(src, q).iterator;
        next = it.moveNext() ? it.current.start : -1;
      }
      from = q;
    }
    return next;
  };
}

Tokens tokenize(String src) {
  final n = src.length;
  final types = <int>[];
  final texts = <String>[];
  final starts = <int>[];
  final stack = <int>[];
  var state = _S.INITIAL;
  var p = 0;
  String? error;

  final nextDirection = _finder(_reDirection, src);
  final nextStereotype = _finder(_reStereotype, src);
  final nextLineEnd = _finder(_reLineEnd, src);
  final nextPercent = _finder(_rePercent, src);
  final nextBrace = _finder(_reBrace, src);

  // The last `direction <dir>` of each kind on the line being lexed, and where its keyword ends.
  var dirFrom = -1;
  var dirTo = -1;
  final dirAt = <int>[-1, -1, -1, -1];
  final dirEnd = <int>[0, 0, 0, 0];
  // The same for <<fork>>, <<join>>, <<choice>> and their [[ ]] spellings.
  var stereoFrom = -1;
  var stereoTo = -1;
  final stereoAt = <int>[-1, -1, -1, -1, -1, -1];

  void emit(int type, int s, int e) {
    types.add(type);
    texts.add(sliceJs(src, s, e));
    starts.add(s);
    p = e;
  }

  void emitText(int type, String text, int s, int e) {
    types.add(type);
    texts.add(text);
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

  // Case-insensitive match of a lowercase ASCII word, as the grammar's /i flag gives.
  bool word(String w, int q) {
    for (var i = 0; i < w.length; i++) {
      final a = w.codeUnitAt(i);
      final c = charCodeAt(src, q + i);
      if (c != a && !(a >= 97 && a <= 122 && c == a - 32)) return false;
    }
    return true;
  }

  int wsEnd(int q) {
    var j = q;
    while (j < n && isSpace(charCodeAt(src, j))) {
      j++;
    }
    return j;
  }

  int wordEnd(int q) {
    var j = q;
    while (j < n && isWord(charCodeAt(src, j))) {
      j++;
    }
    return j;
  }

  int eol(int q) {
    final k = q <= n ? src.indexOf('\n', q) : -1;
    return k == -1 ? n : k;
  }

  int lineEnd(int q) {
    final k = nextLineEnd(q);
    return k == -1 ? n : k;
  }

  // Rules `.*direction\s+TB[^\n]*` and its three siblings: the first kind, in grammar order,
  // found between q and the end of its line.
  int direction(int q) {
    if (q < dirFrom || q > dirTo) {
      final first = nextDirection(q);
      final end = first == -1 ? n : lineEnd(q);
      dirFrom = q;
      dirTo = end;
      dirAt[0] = dirAt[1] = dirAt[2] = dirAt[3] = -1;
      for (var d = first; d != -1 && d < end; d = nextDirection(d + 1)) {
        final w = wsEnd(d + 9);
        if (w == d + 9) continue;
        final kind = word('tb', w)
            ? 0
            : word('bt', w)
            ? 1
            : word('rl', w)
            ? 2
            : word('lr', w)
            ? 3
            : -1;
        if (kind == -1) continue;
        dirAt[kind] = d;
        dirEnd[kind] = w + 2;
      }
    }
    for (var kind = 0; kind < 4; kind++) {
      if (dirAt[kind] >= q) return kind;
    }
    return -1;
  }

  int stereotype(int q) {
    if (q < stereoFrom || q > stereoTo) {
      final first = nextStereotype(q);
      final end = first == -1 ? n : lineEnd(q);
      stereoFrom = q;
      stereoTo = end;
      stereoAt.fillRange(0, 6, -1);
      for (var d = first; d != -1 && d < end; d = nextStereotype(d + 1)) {
        final letter = charCodeAt(src, d + 2) | 32;
        stereoAt[(charCodeAt(src, d) == 60 ? 0 : 3) +
                (letter == 102
                    ? 0
                    : letter == 106
                    ? 1
                    : 2)] =
            d;
      }
    }
    for (var kind = 0; kind < 6; kind++) {
      if (stereoAt[kind] >= q) return kind;
    }
    return -1;
  }

  // The grammar's processId(): an id ends at an inline `%%`, and a text that starts with one is dropped.
  bool emitId(int s, int e) {
    final at = nextPercent(s);
    if (at == -1 || at + 2 > e) {
      emit(T.ID, s, e);
      return true;
    }
    if (at == s) {
      p = e;
      return false;
    }
    emit(T.ID, s, at);
    return true;
  }

  Tokens finish(int type) {
    types.add(type);
    texts.add('');
    starts.add(p);
    return Tokens(types: types, texts: texts, starts: starts, error: error);
  }

  for (;;) {
    if (p >= n) {
      // Jison tries the current state's rules once more on the empty remainder.
      switch (state) {
        case _S.INITIAL:
          emit(T.NL, n, n);
        case _S.acc_title:
          emit(T.acc_title_value, n, n);
        case _S.acc_descr:
          emit(T.acc_descr_value, n, n);
        case _S.acc_descr_multiline:
          emit(T.acc_descr_multiline_value, n, n);
        case _S.CLASSDEFID:
          emit(T.CLASSDEF_STYLEOPTS, n, n);
        case _S.CLASS_STYLE:
          emit(T.STYLECLASS, n, n);
        case _S.STYLEDEF_STYLES:
          emit(T.STYLEDEF_STYLEOPTS, n, n);
        case _S.STATE_STRING:
          emit(T.STATE_DESCR, n, n);
        case _S.FLOATING_NOTE:
          emit(T.NOTE_TEXT, n, n);
        case _S.STATE_ID:
        case _S.FLOATING_NOTE_ID:
          emit(T.ID, n, n);
      }
      return finish(T.END);
    }

    final c = charCodeAt(src, p);
    switch (state) {
      case _S.INITIAL:
      case _S.struct:
        final root = state == _S.INITIAL;
        final lc = c | 32;
        if (root) {
          if (lc == 99 && word('click', p) && !isWord(charCodeAt(src, p + 5))) {
            emit(T.CLICK, p, p + 5);
            continue;
          }
          if (lc == 104 && word('href', p) && !isWord(charCodeAt(src, p + 4))) {
            emit(T.HREF, p, p + 4);
            continue;
          }
          if (c == 34) {
            final close = src.indexOf('"', p + 1);
            if (close != -1) {
              emit(T.STRING, p, close + 1);
              continue;
            }
          }
          if (lc == 100 &&
              word('default', p) &&
              !isWord(charCodeAt(src, p + 7))) {
            emit(T.DEFAULT, p, p + 7);
            continue;
          }
          final kind = direction(p);
          if (kind != -1) {
            emit(T.direction_tb + kind, p, eol(dirEnd[kind]));
            continue;
          }
          if (c == 10) {
            var j = p + 1;
            while (charCodeAt(src, j) == 10) {
              j++;
            }
            emit(T.NL, p, j);
            continue;
          }
          if (isSpace(c)) {
            p = wsEnd(p);
            continue;
          }
        } else if (c != 10 && isSpace(c)) {
          var j = p + 1;
          while (j < n &&
              charCodeAt(src, j) != 10 &&
              isSpace(charCodeAt(src, j))) {
            j++;
          }
          p = j;
          continue;
        }
        if (c == 35 ||
            (c == 37 &&
                charCodeAt(src, p + 1) == 37 &&
                charCodeAt(src, p + 2) != 123)) {
          p = eol(p);
          continue;
        }
        if (lc == 115) {
          if (root && word('scale', p)) {
            final e = wsEnd(p + 5);
            if (e > p + 5) {
              emit(T.scale, p, e);
              push(_S.SCALE);
              continue;
            }
          }
          if (word('style', p)) {
            final e = wsEnd(p + 5);
            if (e > p + 5) {
              emit(T.style, p, e);
              push(_S.STYLE);
              continue;
            }
          }
          if (word('state', p)) {
            var e = wsEnd(p + 5);
            if (e > p + 5) {
              p = e;
              push(_S.STATE);
              continue;
            }
            if (root && word('diagram', p + 5)) {
              final from = word('-v2', p + 12) ? p + 15 : p + 12;
              e = wsEnd(from);
              if (e > from) {
                emit(T.SD, p, e);
                continue;
              }
            }
          }
        } else if (lc == 99) {
          if (word('class', p)) {
            final def = word('def', p + 5);
            final from = def ? p + 8 : p + 5;
            final e = wsEnd(from);
            if (e > from) {
              emit(def ? T.classDef : T.classKw, p, e);
              push(def ? _S.CLASSDEF : _S.CLASS);
              continue;
            }
          }
        } else if (lc == 97 && root) {
          if (word('acctitle', p) || word('accdescr', p)) {
            final title = (charCodeAt(src, p + 3) | 32) == 116;
            final q = wsEnd(p + 8);
            final d = charCodeAt(src, q);
            if (d == 58) {
              emit(title ? T.acc_title : T.acc_descr, p, wsEnd(q + 1));
              push(title ? _S.acc_title : _S.acc_descr);
              continue;
            }
            if (d == 123 && !title) {
              p = wsEnd(q + 1);
              push(_S.acc_descr_multiline);
              continue;
            }
          }
        }
        if (root) {
          if (c == 123) {
            emit(T.STRUCT_START, p, p + 1);
            push(_S.struct);
            continue;
          }
        } else {
          final kind = direction(p);
          if (kind != -1) {
            emit(T.direction_tb + kind, p, eol(dirEnd[kind]));
            continue;
          }
          if (c == 125) {
            emit(T.STRUCT_STOP, p, p + 1);
            pop();
            continue;
          }
          if (c == 10) {
            p++;
            continue;
          }
        }
        if (lc == 110 && word('note', p)) {
          final e = wsEnd(p + 4);
          if (e > p + 4) {
            emit(T.note, p, e);
            push(_S.NOTE);
            continue;
          }
        }
        if (root &&
            lc == 104 &&
            word('hide empty description', p) &&
            !isWord(charCodeAt(src, p + 22))) {
          emit(T.HIDE_EMPTY, p, p + 22);
          continue;
        }
        if (c == 91 &&
            charCodeAt(src, p + 1) == 42 &&
            charCodeAt(src, p + 2) == 93) {
          emit(T.EDGE_STATE, p, p + 3);
          continue;
        }
        var j = p;
        while (j < n) {
          final d = charCodeAt(src, j);
          if (d == 58 || d == 45 || d == 123 || isSpace(d)) break;
          j++;
        }
        if (j > p) {
          emitId(p, j);
          continue;
        }
        if (c == 58) {
          j = p + 1;
          while (j < n) {
            final d = charCodeAt(src, j);
            if (d == 10 || d == 59) break;
            if (d == 58) {
              final after = charCodeAt(src, j + 1);
              if (j + 1 >= n || after == 58 || after == 10 || after == 59) {
                break;
              }
              j++;
            }
            j++;
          }
          if (j > p + 1) {
            emitText(T.DESCR, sliceJs(src, p, j).trim(), p, j);
            continue;
          }
          if (charCodeAt(src, p + 1) == 58 && charCodeAt(src, p + 2) == 58) {
            emit(T.STYLE_SEPARATOR, p, p + 3);
            continue;
          }
        } else if (c == 45 && charCodeAt(src, p + 1) == 45) {
          if (charCodeAt(src, p + 2) == 62) {
            emit(T.ARROW, p, p + 3);
            continue;
          }
          if (!root) {
            emit(T.CONCURRENT, p, p + 2);
            continue;
          }
        }
        if (!root) return finish(T.ERROR);
        emit(T.INVALID, p, p + 1);
        continue;

      case _S.STATE:
        if (c != 10 && isSpace(c)) {
          var j = p + 1;
          while (j < n &&
              charCodeAt(src, j) != 10 &&
              isSpace(charCodeAt(src, j))) {
            j++;
          }
          p = j;
          continue;
        }
        if (c == 35 ||
            (c == 37 &&
                charCodeAt(src, p + 1) == 37 &&
                charCodeAt(src, p + 2) != 123)) {
          p = eol(p);
          continue;
        }
        final kind = stereotype(p);
        if (kind != -1) {
          final at = stereoAt[kind];
          final choice = kind == 2 || kind == 5;
          emitText(
            choice
                ? T.CHOICE
                : kind % 3 == 0
                ? T.FORK
                : T.JOIN,
            sliceJs(src, p, at).trim(),
            p,
            at + (choice ? 10 : 8),
          );
          pop();
          continue;
        }
        if (c == 34) {
          p++;
          push(_S.STATE_STRING);
          continue;
        }
        final q = c == 10 ? wsEnd(p) : p;
        if (word('as', q)) {
          final e = wsEnd(q + 2);
          if (e > q + 2) {
            emit(T.AS, p, e);
            push(_S.STATE_ID);
            continue;
          }
        }
        if (c == 10) {
          p++;
          pop();
          continue;
        }
        if (c == 123) {
          emit(T.STRUCT_START, p, p + 1);
          pop();
          push(_S.struct);
          continue;
        }
        if (isWord(c)) {
          final first = wordEnd(p);
          final second = wsEnd(first);
          if (second > first && isWord(charCodeAt(src, second))) {
            final brace = nextBrace(second + 1);
            if (brace != -1 && brace < lineEnd(second)) {
              error =
                  'Error: State name must be a single word. Found: "${sliceJs(src, p, brace + 1).trim()}"';
              return finish(T.ERROR);
            }
          }
        }
        var j = p + 1;
        while (j < n) {
          final d = charCodeAt(src, j);
          if (d == 123 || isSpace(d)) break;
          j++;
        }
        emit(T.COMPOSIT_STATE, p, j);
        continue;

      case _S.STATE_STRING:
        if (c == 34) {
          p++;
          pop();
          continue;
        }
        final close = src.indexOf('"', p);
        emit(T.STATE_DESCR, p, close == -1 ? n : close);
        continue;

      case _S.STATE_ID:
        var j = p;
        while (j < n) {
          final d = charCodeAt(src, j);
          if (d == 10 || d == 123) break;
          j++;
        }
        if (emitId(p, j)) pop();
        continue;

      case _S.SCALE:
        if (c >= 48 && c <= 57) {
          var j = p + 1;
          while (j < n &&
              charCodeAt(src, j) >= 48 &&
              charCodeAt(src, j) <= 57) {
            j++;
          }
          emit(T.WIDTH, p, j);
          continue;
        }
        final q = wsEnd(p);
        if (q > p && word('width', q) && !isWord(charCodeAt(src, q + 5))) {
          p = q + 5;
          pop();
          continue;
        }
        return finish(T.ERROR);

      case _S.acc_title:
        emit(T.acc_title_value, p, eol(p));
        pop();
        continue;

      case _S.acc_descr:
        emit(T.acc_descr_value, p, eol(p));
        pop();
        continue;

      case _S.acc_descr_multiline:
        if (c == 125) {
          p++;
          pop();
          continue;
        }
        final close = src.indexOf('}', p);
        emit(T.acc_descr_multiline_value, p, close == -1 ? n : close);
        continue;

      case _S.CLASSDEF:
        final isDefault = word('default', p) && wsEnd(p + 7) > p + 7;
        final j = isDefault ? p + 7 : wordEnd(p);
        final e = wsEnd(j);
        if (j == p || e == j) return finish(T.ERROR);
        emit(isDefault ? T.DEFAULT_CLASSDEF_ID : T.CLASSDEF_ID, p, e);
        pop();
        push(_S.CLASSDEFID);
        continue;

      case _S.CLASSDEFID:
        emit(T.CLASSDEF_STYLEOPTS, p, eol(p));
        pop();
        continue;

      case _S.CLASS:
        var j = wordEnd(p);
        if (j == p) return finish(T.ERROR);
        while (charCodeAt(src, j) == 44) {
          final k = wsEnd(j + 1);
          final e = wordEnd(k);
          if (e == k) break;
          j = e;
        }
        emit(T.CLASSENTITY_IDS, p, j);
        pop();
        push(_S.CLASS_STYLE);
        continue;

      case _S.CLASS_STYLE:
        emit(T.STYLECLASS, p, eol(p));
        pop();
        continue;

      case _S.STYLE:
        var j = p;
        while (j < n &&
            (isWord(charCodeAt(src, j)) || charCodeAt(src, j) == 44)) {
          j++;
        }
        final e = wsEnd(j);
        if (j == p || e == j) return finish(T.ERROR);
        emit(T.STYLE_IDS, p, e);
        pop();
        push(_S.STYLEDEF_STYLES);
        continue;

      case _S.STYLEDEF_STYLES:
        emit(T.STYLEDEF_STYLEOPTS, p, eol(p));
        pop();
        continue;

      case _S.NOTE:
        if (word('left of', p) && !isWord(charCodeAt(src, p + 7))) {
          emit(T.left_of, p, p + 7);
          pop();
          push(_S.NOTE_ID);
          continue;
        }
        if (word('right of', p) && !isWord(charCodeAt(src, p + 8))) {
          emit(T.right_of, p, p + 8);
          pop();
          push(_S.NOTE_ID);
          continue;
        }
        if (c == 34) {
          p++;
          pop();
          push(_S.FLOATING_NOTE);
          continue;
        }
        return finish(T.ERROR);

      case _S.NOTE_ID:
        final q = wsEnd(p);
        var j = q;
        while (j < n) {
          final d = charCodeAt(src, j);
          if (d == 58 || d == 45 || isSpace(d)) break;
          j++;
        }
        if (j == q) return finish(T.ERROR);
        if (emitId(p, j)) {
          pop();
          push(_S.NOTE_TEXT);
        }
        continue;

      case _S.NOTE_TEXT:
        final q = wsEnd(p);
        if (charCodeAt(src, q) == 58) {
          var j = q + 1;
          while (j < n) {
            final d = charCodeAt(src, j);
            if (d == 58 || d == 10 || d == 59) break;
            j++;
          }
          if (j > q + 1) {
            // Mermaid drops two characters here, expecting " :"; with no space before the colon
            // the first character of the note goes too.
            emitText(T.NOTE_TEXT, sliceJs(src, p + 2, j).trim(), p, j);
            pop();
            continue;
          }
        }
        var k = src.indexOf('\n', p);
        var e = -1;
        while (k != -1) {
          e = wsEnd(k);
          if (word('end note', e) && !isWord(charCodeAt(src, e + 8))) break;
          k = src.indexOf('\n', e);
        }
        if (k == -1) return finish(T.ERROR);
        emitText(T.NOTE_TEXT, sliceJs(src, p, e).trim(), p, e + 8);
        pop();
        continue;

      case _S.FLOATING_NOTE:
        final q = wsEnd(p);
        if (word('as', q)) {
          emit(T.AS, p, wsEnd(q + 2));
          pop();
          push(_S.FLOATING_NOTE_ID);
          continue;
        }
        if (c == 34) {
          p++;
          continue;
        }
        final close = src.indexOf('"', p);
        emit(T.NOTE_TEXT, p, close == -1 ? n : close);
        continue;

      case _S.FLOATING_NOTE_ID:
        if (emitId(p, eol(p))) pop();
        continue;
    }
  }
}

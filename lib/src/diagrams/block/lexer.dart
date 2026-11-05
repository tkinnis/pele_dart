// Upstream: src/diagrams/block/lexer.ts

import 'dart:typed_data';

import '../../util/chars.dart';
import '../../util/math_js.dart';
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
  static const int md_string = 2;
  static const int NODE = 3;
  static const int BLOCK_ARROW = 4;
  static const int ARROW_DIR = 5;
  static const int LLABEL = 6;
  static const int CLASSDEF = 7;
  static const int CLASSDEFID = 8;
  static const int CLASS = 9;
  static const int CLASS_STYLE = 10;
  static const int STYLE_STMNT = 11;
  static const int STYLE_DEFINITION = 12;
  static const int acc_title = 13;
  static const int acc_descr = 14;
  static const int acc_descr_multiline = 15;
}

const List<String> _directions = <String>[
  'right',
  'left',
  'x',
  'y',
  'up',
  'down',
];

// Characters that end a node id: ( ) [ { } < > - : = and whitespace.
final Uint8List _idStop = () {
  final arr = Uint8List(128);
  for (final c in const <int>[
    9,
    10,
    11,
    12,
    13,
    32,
    40,
    41,
    45,
    58,
    60,
    61,
    62,
    91,
    123,
    125,
  ]) {
    arr[c] = 1;
  }
  return arr;
}();

Tokens tokenize(String src) {
  final n = src.length;
  final types = <int>[];
  final texts = <String>[];
  final starts = <int>[];
  final stack = <int>[];
  var state = _S.INITIAL;
  var p = 0;

  bool put(int type, String text, int end) {
    types.add(type);
    texts.add(text);
    starts.add(p);
    p = end;
    return true;
  }

  bool emit(int type, int end) => put(type, src.substring(p, end), end);

  void push(int s) {
    stack.add(state);
    state = s;
  }

  void pop() {
    if (stack.isNotEmpty) state = stack.removeLast();
  }

  int ws(int q) {
    while (q < n && isSpace(src.codeUnitAt(q))) {
      q++;
    }
    return q;
  }

  int digits(int q) {
    while (q < n) {
      final c = src.codeUnitAt(q);
      if (c < 48 || c > 57) break;
      q++;
    }
    return q;
  }

  int word(int q) {
    while (q < n && isWord(src.codeUnitAt(q))) {
      q++;
    }
    return q;
  }

  bool keyword(String text) =>
      src.startsWith(text, p) && !isWord(charCodeAt(src, p + text.length));

  bool quote() {
    if (charCodeAt(src, p + 1) == 96) {
      push(_S.md_string);
      p += 2;
    } else {
      push(_S.string);
      p++;
    }
    return true;
  }

  // End of `.+-[xo>]?` at q, or -1.
  int dotted(int q) {
    if (charCodeAt(src, q) != 46) return -1;
    do {
      q++;
    } while (charCodeAt(src, q) == 46);
    if (charCodeAt(src, q) != 45) return -1;
    final c = charCodeAt(src, q + 1);
    return c == 120 || c == 111 || c == 62 ? q + 2 : q + 1;
  }

  // End of a complete link at q, before its trailing whitespace, or -1.
  int linkEnd(int q) {
    final c = charCodeAt(src, q);
    if (c == 120 || c == 111 || c == 60) q++;
    final line = charCodeAt(src, q);
    if (line == 46) return dotted(q);
    if (line != 45 && line != 61) return -1;
    var k = q + 1;
    while (charCodeAt(src, k) == line) {
      k++;
    }
    if (k - q == 1) return line == 45 ? dotted(k) : -1;
    final head = charCodeAt(src, k);
    if (head == 120 || head == 111 || head == 62) return k + 1;
    return k - q >= 3 ? k : -1;
  }

  bool link() {
    final e = linkEnd(p);
    if (e >= 0) return emit(T.LINK, ws(e));
    final q = charCodeAt(src, p) == 60 ? p + 1 : p;
    final a = charCodeAt(src, q);
    final b = charCodeAt(src, q + 1);
    if ((a == 45 && (b == 45 || b == 46)) || (a == 61 && b == 61)) {
      push(_S.LLABEL);
      return emit(T.START_LINK, ws(q + 2));
    }
    return false;
  }

  bool lineState(int type) {
    var e = src.indexOf('\n', p);
    if (e == -1) e = n;
    pop();
    return emit(type, e);
  }

  // `\w+(,\s*\w+)*`
  bool idList(int type, int next) {
    var k = word(p);
    if (k == p) return false;
    while (charCodeAt(src, k) == 44) {
      final from = ws(k + 1);
      final to = word(from);
      if (to == from) break;
      k = to;
    }
    state = next;
    return emit(type, k);
  }

  bool initial(int c) {
    if (isSpace(c)) {
      p = ws(p + 1);
      return true;
    }
    int q;
    switch (c) {
      case 98:
        if (src.startsWith('block', p)) {
          if (keyword('block-beta')) return emit(T.KEY, p + 10);
          if (charCodeAt(src, p + 5) == 58) return emit(T.ID_BLOCK, p + 6);
          if (!isWord(charCodeAt(src, p + 5))) return emit(T.KEY, p + 5);
        }
      case 99:
        if (src.startsWith('columns', p)) {
          q = ws(p + 7);
          if (q > p + 7) {
            if (src.startsWith('auto', q) && !isWord(charCodeAt(src, q + 4))) {
              return put(T.COLUMNS, '-1', q + 4);
            }
            final e = digits(q);
            if (e > q) return put(T.COLUMNS, src.substring(q, e), e);
          }
        } else if (src.startsWith('class', p)) {
          final def = src.startsWith('Def', p + 5);
          final from = def ? p + 8 : p + 5;
          q = ws(from);
          if (q > from) {
            push(def ? _S.CLASSDEF : _S.CLASS);
            return emit(def ? T.CLASSDEF : T.CLASS, q);
          }
        }
      case 34:
        return quote();
      case 115:
        if (src.startsWith('space', p)) {
          if (charCodeAt(src, p + 5) == 58) {
            final e = digits(p + 6);
            if (e > p + 6) {
              return put(T.SPACE_BLOCK, src.substring(p + 6, e), e);
            }
          }
          if (!isWord(charCodeAt(src, p + 5))) {
            return put(T.SPACE_BLOCK, '1', p + 5);
          }
        } else if (src.startsWith('style', p)) {
          q = ws(p + 5);
          if (q > p + 5) {
            push(_S.STYLE_STMNT);
            return emit(T.STYLE, q);
          }
        }
      case 100:
        if (keyword('default')) return emit(T.DEFAULT, p + 7);
      case 108:
        if (keyword('linkStyle')) return emit(T.LINKSTYLE, p + 9);
      case 105:
        if (keyword('interpolate')) return emit(T.INTERPOLATE, p + 11);
      case 97:
        if (src.startsWith('accTitle', p)) {
          q = ws(p + 8);
          if (charCodeAt(src, q) == 58) {
            push(_S.acc_title);
            return emit(T.acc_title, ws(q + 1));
          }
        } else if (src.startsWith('accDescr', p)) {
          q = ws(p + 8);
          final d = charCodeAt(src, q);
          if (d == 58) {
            push(_S.acc_descr);
            return emit(T.acc_descr, ws(q + 1));
          }
          if (d == 123) {
            push(_S.acc_descr_multiline);
            p = ws(q + 1);
            return true;
          }
        }
      case 101:
        if (keyword('end')) return emit(T.end, ws(p + 3));
      case 45:
        if (charCodeAt(src, p + 1) == 41) {
          push(_S.NODE);
          return emit(T.NODE_DSTART, p + 2);
        }
        return link();
      case 61:
        return link();
      case 60:
        if (charCodeAt(src, p + 1) == 91) {
          push(_S.BLOCK_ARROW);
          return emit(T.BLOCK_ARROW_START, p + 2);
        }
        return link();
      case 40:
        final d = charCodeAt(src, p + 1);
        final len = d == 45 || d == 91
            ? 2
            : d == 40
            ? (charCodeAt(src, p + 2) == 40 ? 3 : 2)
            : 1;
        push(_S.NODE);
        return emit(T.NODE_DSTART, p + len);
      case 41:
      case 123:
        push(_S.NODE);
        return emit(T.NODE_DSTART, charCodeAt(src, p + 1) == c ? p + 2 : p + 1);
      case 62:
        push(_S.NODE);
        return emit(T.NODE_DSTART, p + 1);
      case 91:
        final d = charCodeAt(src, p + 1);
        push(_S.NODE);
        return emit(
          T.NODE_DSTART,
          d == 91 || d == 124 || d == 40 || d == 92 || d == 47 ? p + 2 : p + 1,
        );
      case 58:
        final e = digits(p + 1);
        if (e > p + 1) return put(T.SIZE, src.substring(p + 1, e), e);
        return false;
    }

    q = p;
    while (q < n) {
      final ch = src.codeUnitAt(q);
      if (ch < 128 ? _idStop[ch] == 1 : isSpace(ch)) break;
      q++;
    }
    return q > p && emit(T.NODE_ID, q);
  }

  bool nodeEnd(int c) {
    final d = charCodeAt(src, p + 1);
    var len = 0;
    switch (c) {
      case 34:
        return quote();
      case 40:
        len = d == 45
            ? 2
            : d == 40
            ? (charCodeAt(src, p + 2) == 40 ? 3 : 2)
            : 1;
      case 41:
        len = d == 41
            ? (charCodeAt(src, p + 2) == 41 ? 3 : 2)
            : d == 93
            ? 2
            : 1;
      case 125:
        len = d == 125 ? 2 : 1;
      case 45:
        len = d == 41 ? 2 : 0;
      case 93:
        len = d == 93 || d == 41 || d == 62 ? 2 : 1;
      case 92:
      case 47:
        len = d == 93 ? 2 : 0;
    }
    if (len == 0) return false;
    pop();
    return emit(T.NODE_DEND, p + len);
  }

  bool arrowDir(int c) {
    if (c == 41) {
      pop();
      pop();
      return put(T.BLOCK_ARROW_END, ']>', ws(p + 1));
    }
    final from = ws(c == 44 ? p + 1 : p);
    for (final dir in _directions) {
      if (src.startsWith(dir, from)) {
        final e = ws(from + dir.length);
        return put(T.DIR, src.substring(c == 44 ? from : p, e), e);
      }
    }
    return false;
  }

  while (true) {
    if (p >= n) {
      var type = -1;
      switch (state) {
        case _S.INITIAL:
          type = T.EOF;
        case _S.string:
          type = T.STR;
        case _S.CLASSDEFID:
          type = T.CLASSDEF_STYLEOPTS;
        case _S.CLASS_STYLE:
          type = T.STYLECLASS;
        case _S.STYLE_DEFINITION:
          type = T.STYLE_DEFINITION_DATA;
        case _S.acc_title:
          type = T.acc_title_value;
        case _S.acc_descr:
          type = T.acc_descr_value;
        case _S.acc_descr_multiline:
          type = T.acc_descr_multiline_value;
      }
      p = n;
      if (type != -1) put(type, '', n);
      break;
    }

    final c = src.codeUnitAt(p);
    var ok = true;

    switch (state) {
      case _S.INITIAL:
        ok = initial(c);

      case _S.string:
        if (c == 34) {
          pop();
          p++;
        } else {
          final e = src.indexOf('"', p);
          emit(T.STR, e == -1 ? n : e);
        }

      case _S.md_string:
        if (c == 96) {
          ok = charCodeAt(src, p + 1) == 34;
          if (ok) {
            pop();
            p += 2;
          }
        } else if (c == 34) {
          ok = false;
        } else {
          var q = p + 1;
          while (q < n) {
            final ch = src.codeUnitAt(q);
            if (ch == 96 || ch == 34) break;
            q++;
          }
          emit(T.MD_STR, q);
        }

      case _S.NODE:
        ok = nodeEnd(c);

      case _S.BLOCK_ARROW:
        if (c == 34) {
          quote();
        } else if (c == 93 && charCodeAt(src, p + 1) == 62) {
          final q = ws(p + 2);
          ok = charCodeAt(src, q) == 40;
          if (ok) {
            push(_S.ARROW_DIR);
            p = q + 1;
          }
        } else {
          ok = false;
        }

      case _S.ARROW_DIR:
        ok = arrowDir(c);

      case _S.LLABEL:
        if (c == 34) {
          if (charCodeAt(src, p + 1) == 96) {
            quote();
          } else {
            emit(T.LINK_LABEL, p + 1);
            push(_S.string);
          }
        } else {
          final e = linkEnd(ws(p));
          ok = e >= 0;
          if (ok) {
            pop();
            emit(T.LINK, ws(e));
          }
        }

      case _S.CLASSDEF:
        var type = T.DEFAULT_CLASSDEF_ID;
        var k = src.startsWith('DEFAULT', p) ? p + 7 : p;
        var q = ws(k);
        if (k == p || q == k) {
          type = T.CLASSDEF_ID;
          k = word(p);
          q = ws(k);
        }
        ok = k > p && q > k;
        if (ok) {
          state = _S.CLASSDEFID;
          emit(type, q);
        }

      case _S.CLASSDEFID:
        lineState(T.CLASSDEF_STYLEOPTS);

      case _S.CLASS:
        ok = idList(T.CLASSENTITY_IDS, _S.CLASS_STYLE);

      case _S.CLASS_STYLE:
        lineState(T.STYLECLASS);

      case _S.STYLE_STMNT:
        ok = idList(T.STYLE_ENTITY_IDS, _S.STYLE_DEFINITION);

      case _S.STYLE_DEFINITION:
        lineState(T.STYLE_DEFINITION_DATA);

      case _S.acc_title:
        lineState(T.acc_title_value);

      case _S.acc_descr:
        lineState(T.acc_descr_value);

      case _S.acc_descr_multiline:
        if (c == 125) {
          pop();
          p++;
        } else {
          final e = src.indexOf('}', p);
          emit(T.acc_descr_multiline_value, e == -1 ? n : e);
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

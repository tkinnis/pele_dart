// Upstream: src/diagrams/common/outline.ts

import 'dart:math' as math;
import 'dart:typed_data';

import '../../errors.dart';
import '../../util/chars.dart';
import '../../util/math_js.dart';

class T {
  static const int END = 0;
  static const int ERROR = 1;
  static const int SPACELINE = 2;
  static const int NL = 3;
  static const int EOF = 4;
  static const int KEYWORD = 5;
  static const int SPACELIST = 6;
  static const int ICON = 7;
  static const int CLASS = 8;
  static const int NODE_DSTART = 9;
  static const int NODE_ID = 10;
  static const int NODE_DESCR = 11;
  static const int NODE_DEND = 12;
  static const int SHAPE_DATA = 13;
}

const List<String> _names = <String>[
  '1',
  'INVALID',
  'SPACELINE',
  'NL',
  'EOF',
  '',
  'SPACELIST',
  'ICON',
  'CLASS',
  'NODE_DSTART',
  'NODE_ID',
  'NODE_DESCR',
  'NODE_DEND',
  'SHAPE_DATA',
];

String tokenName(int type, bool kanban) {
  return type == T.KEYWORD ? (kanban ? 'KANBAN' : 'MINDMAP') : _names[type];
}

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

// ignore: camel_case_types
class NODE_TYPE {
  static const int DEFAULT = 0;
  static const int NO_BORDER = 0;
  static const int ROUNDED_RECT = 1;
  static const int RECT = 2;
  static const int CIRCLE = 3;
  static const int CLOUD = 4;
  static const int BANG = 5;
  static const int HEXAGON = 6;
}

int getType(String start, String end) {
  switch (start) {
    case '[':
      return NODE_TYPE.RECT;
    case '(':
      return end == ')' ? NODE_TYPE.ROUNDED_RECT : NODE_TYPE.CLOUD;
    case '((':
      return NODE_TYPE.CIRCLE;
    case ')':
      return NODE_TYPE.CLOUD;
    case '))':
      return NODE_TYPE.BANG;
    case '{{':
      return NODE_TYPE.HEXAGON;
    default:
      return NODE_TYPE.DEFAULT;
  }
}

class OutlineDecoration {
  final String? icon;
  final String? className;

  const OutlineDecoration({this.icon, this.className});
}

abstract interface class OutlineDb {
  int getType(String start, String end);
  void addNode(
    int level,
    String id,
    String descr,
    int type, [
    String? shapeData,
  ]);
  void decorateNode([OutlineDecoration? decoration]);
}

class _S {
  static const int initial = 0;
  static const int classState = 1;
  static const int icon = 2;
  static const int node = 3;
  static const int nstr = 4;
  static const int nstr2 = 5;
  static const int data = 6;
  static const int dataStr = 7;
}

final RegExp _reSpace = RegExp(r'\s+');
final RegExp _reLine = RegExp(r'[^\n\r]+');
final RegExp _reId = RegExp(r'[^([\n){}]+');
final RegExp _reIdKanban = RegExp(r'[^([\n){}@]+');
final RegExp _reDescr = RegExp(r'[^)\](}]+');
final RegExp _reMd = RegExp(r'[^`"]+');
final RegExp _reData = RegExp(r'[^}^"]+');
final RegExp _reBr = RegExp(r'\n\s*');

bool _letters(String src, int p, String word) {
  for (var k = 0; k < word.length; k++) {
    if ((charCodeAt(src, p + k) | 32) != word.codeUnitAt(k)) return false;
  }
  return true;
}

Tokens tokenize(String src, bool kanban) {
  final n = src.length;
  final types = <int>[];
  final texts = <String>[];
  final starts = <int>[];
  final keyword = kanban ? 'kanban' : 'mindmap';
  final reId = kanban ? _reIdKanban : _reId;
  var state = _S.initial;
  var p = 0;
  var nextBreak = -1;

  void put(int type, String text, int end) {
    types.add(type);
    texts.add(text);
    starts.add(p);
    p = end;
  }

  void emit(int type, int end, int next) {
    put(type, src.substring(p, end), end);
    state = next;
  }

  int at(RegExp re, int from) {
    return re.matchAsPrefix(src, from)?.end ?? -1;
  }

  int upTo(String ch) {
    final e = src.indexOf(ch, p);
    return e == -1 ? n : e;
  }

  while (p < n) {
    final c = charCodeAt(src, p);
    final d = charCodeAt(src, p + 1);
    int e;
    if (state == _S.initial) {
      final w = c <= 32 || c >= 160 ? math.max(at(_reSpace, p), p) : p;
      if (kanban && c == 64 && d == 123) {
        put(T.SHAPE_DATA, '', p + 2);
        state = _S.data;
      } else if (charCodeAt(src, w) == 37 && charCodeAt(src, w + 1) == 37) {
        emit(T.SPACELINE, at(_reLine, w), _S.initial);
      } else if (w > p) {
        if (nextBreak < p) nextBreak = upTo('\n');
        if (nextBreak >= w) {
          emit(T.SPACELIST, w, _S.initial);
        } else if ((e = src.lastIndexOf('\n', w - 1)) > p) {
          emit(T.SPACELINE, e + 1, _S.initial);
        } else {
          emit(T.NL, p + 1, _S.initial);
        }
      } else if (_letters(src, p, keyword) &&
          !isWord(charCodeAt(src, p + keyword.length))) {
        emit(T.KEYWORD, p + keyword.length, _S.initial);
      } else if (c == 58 && d == 58 && charCodeAt(src, p + 2) == 58) {
        p += 3;
        state = _S.classState;
      } else if (c == 58 &&
          d == 58 &&
          _letters(src, p + 2, 'icon') &&
          charCodeAt(src, p + 6) == 40) {
        p += 7;
        state = _S.icon;
      } else if ((c == 45 && d == 41) ||
          (c == 40 && (d == 45 || d == 40)) ||
          ((c == 41 || c == 123) && d == c)) {
        emit(T.NODE_DSTART, p + 2, _S.node);
      } else if (c == 41 || c == 40 || c == 91) {
        emit(T.NODE_DSTART, p + 1, _S.node);
      } else if ((e = at(reId, p)) != -1) {
        emit(T.NODE_ID, e, _S.initial);
      } else {
        break;
      }
    } else if (state == _S.node) {
      if (c == 34) {
        state = d == 96 ? _S.nstr2 : _S.nstr;
        p += d == 96 ? 2 : 1;
      } else if (c == 41 || c == 40) {
        emit(
          T.NODE_DEND,
          d == c || (c == 40 && d == 45) ? p + 2 : p + 1,
          _S.initial,
        );
      } else if (c == 93) {
        emit(T.NODE_DEND, p + 1, _S.initial);
      } else if ((c == 125 && d == 125) || (c == 45 && d == 41)) {
        emit(T.NODE_DEND, p + 2, _S.initial);
      } else {
        emit(T.NODE_DESCR, at(c == 125 ? _reLine : _reDescr, p), _S.node);
      }
    } else if (state == _S.nstr) {
      if (c == 34) {
        p++;
        state = _S.node;
      } else {
        emit(T.NODE_DESCR, upTo('"'), _S.nstr);
      }
    } else if (state == _S.nstr2) {
      if (c == 96 && d == 34) {
        p += 2;
        state = _S.node;
      } else if ((e = at(_reMd, p)) != -1) {
        emit(T.NODE_DESCR, e, _S.nstr2);
      } else {
        break;
      }
    } else if (state == _S.classState) {
      if ((e = at(_reLine, p)) != -1) {
        emit(T.CLASS, e, _S.initial);
      } else if (c == 10) {
        p++;
        state = _S.initial;
      } else {
        break;
      }
    } else if (state == _S.icon) {
      if (c == 41) {
        p++;
        state = _S.initial;
      } else {
        emit(T.ICON, upTo(')'), _S.icon);
      }
    } else if (state == _S.data) {
      if (c == 34) {
        emit(T.SHAPE_DATA, p + 1, _S.dataStr);
      } else if (c == 125) {
        p++;
        state = _S.initial;
      } else if ((e = at(_reData, p)) != -1) {
        emit(T.SHAPE_DATA, e, _S.data);
      } else {
        break;
      }
    } else if (c == 34) {
      emit(T.SHAPE_DATA, p + 1, _S.data);
    } else {
      e = upTo('"');
      put(T.SHAPE_DATA, src.substring(p, e).replaceAll(_reBr, '<br/>'), e);
    }
  }

  if (p < n) {
    put(T.ERROR, '', p);
  } else {
    if (state == _S.initial) put(T.EOF, '', n);
    put(T.END, '', n);
  }
  return Tokens(types: types, texts: texts, starts: starts);
}

const String _stop = "'SPACELINE', 'NL', 'EOF'";
final Uint8List _start = () {
  final arr = Uint8List(T.SHAPE_DATA + 1);
  for (final t in const <int>[
    T.SPACELINE,
    T.SPACELIST,
    T.ICON,
    T.CLASS,
    T.NODE_DSTART,
    T.NODE_ID,
  ]) {
    arr[t] = 1;
  }
  return arr;
}();

bool _isStop(int type) {
  return type == T.SPACELINE || type == T.NL || type == T.EOF;
}

void parseOutline(String src, OutlineDb db, bool kanban) {
  final diagram = kanban ? 'kanban' : 'mindmap';
  final tok = tokenize(src, kanban);
  final types = tok.types;
  final texts = tok.texts;
  final starts = tok.starts;
  final data = kanban ? ", 'SHAPE_DATA'" : '';
  var i = 0;

  Never fail(String expected) {
    final t = types[i];
    if (t == T.ERROR) throw syntaxError(diagram, src, starts[i], '', true);
    throw syntaxError(
      diagram,
      src,
      starts[i],
      "Expecting $expected, got '${tokenName(t, kanban)}'",
    );
  }

  final keyword = "'${tokenName(T.KEYWORD, kanban)}'";
  if (types[i] == T.SPACELINE) {
    i++;
    while (types[i] == T.SPACELINE || types[i] == T.NL) {
      i++;
    }
    if (types[i] != T.KEYWORD) fail("'SPACELINE', 'NL', $keyword");
  } else if (types[i] != T.KEYWORD) {
    fail("'SPACELINE', $keyword");
  }
  i++;
  var first =
      "'SPACELINE', 'NL', 'SPACELIST', 'ICON', 'CLASS', 'NODE_DSTART', 'NODE_ID'";
  if (types[i] == T.NL) {
    i++;
    first =
        "'SPACELINE', 'SPACELIST', 'ICON', 'CLASS', 'NODE_DSTART', 'NODE_ID'";
  }

  for (;;) {
    var t = types[i];
    var level = 0;
    final indented = t == T.SPACELIST;
    if (indented) {
      level = texts[i++].length;
      t = types[i];
    }
    if (t == T.NODE_ID || t == T.NODE_DSTART) {
      String? id;
      String descr;
      var type = 0;
      if (t == T.NODE_ID) id = texts[i++];
      if (types[i] == T.NODE_DSTART) {
        final start = texts[i++];
        if (types[i] != T.NODE_DESCR) fail("'NODE_DESCR'");
        descr = texts[i++];
        if (types[i] != T.NODE_DEND) fail("'NODE_DEND'");
        final end = texts[i++];
        if (!_isStop(types[i]) && types[i] != T.SHAPE_DATA) fail(_stop + data);
        type = db.getType(start, end);
      } else {
        if (!_isStop(types[i]) && types[i] != T.SHAPE_DATA) {
          fail("$_stop, 'NODE_DSTART'$data");
        }
        descr = id!;
      }
      if (types[i] == T.SHAPE_DATA) {
        var shapeData = texts[i++];
        while (types[i] == T.SHAPE_DATA) {
          shapeData += texts[i++];
        }
        if (!_isStop(types[i])) fail(_stop + data);
        db.addNode(level, id ?? descr, descr, type, shapeData);
      } else {
        db.addNode(level, id ?? descr, descr, type);
      }
    } else if (t == T.ICON || t == T.CLASS) {
      final text = texts[i++];
      if (!_isStop(types[i])) fail(_stop);
      db.decorateNode(
        t == T.ICON
            ? OutlineDecoration(icon: text)
            : OutlineDecoration(className: text),
      );
    } else if (indented) {
      if (!_isStop(t)) {
        fail("$_stop, 'ICON', 'CLASS', 'NODE_DSTART', 'NODE_ID'");
      }
    } else if (t == T.SPACELINE) {
      if (!_isStop(types[++i])) fail(_stop);
    } else {
      fail(first);
    }

    i++;
    while (types[i] == T.NL || types[i] == T.EOF) {
      i++;
    }
    if (types[i] == T.END) return;
    if (_start[types[i]] == 0) {
      fail("$_stop, 'SPACELIST', 'ICON', 'CLASS', 'NODE_DSTART', 'NODE_ID'");
    }
  }
}

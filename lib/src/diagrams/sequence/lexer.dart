// Upstream: src/diagrams/sequence/lexer.ts

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
  static const int ID = 1;
  static const int ALIAS = 2;
  static const int LINE = 3;
  static const int CONFIG = 4;
  static const int acc_title = 5;
  static const int acc_descr = 6;
  static const int acc_descr_multiline = 7;
}

abstract final class _C {
  static const int ActorStart = 1;
  static const int ActorRest = 2;
  static const int Id = 4;
  static const int IdWide = 8;
  static const int Line = 16;
  static const int Menu = 32;
}

/// Character classes of Mermaid's lexer rules, for ASCII. Other characters are tested by [isSpace].
final Uint8List _CLASS = _buildClass();

Uint8List _buildClass() {
  final out = Uint8List(128);
  for (var c = 0; c < 128; c++) {
    final ch = String.fromCharCode(c);
    final ws = c == 32 || (c >= 9 && c <= 13);
    var bits = 0;
    if (!'/\\+()<->:\n,;'.contains(ch)) bits |= _C.ActorStart;
    if (!'+<->:\n,;'.contains(ch)) bits |= _C.ActorRest;
    if (!'<>:\n,;@'.contains(ch)) bits |= _C.IdWide | (ws ? 0 : _C.Id);
    if (!'#\n;'.contains(ch)) bits |= _C.Line;
    if (!'/\\+()<>:\n,;-'.contains(ch) && !ws) bits |= _C.Menu;
    out[c] = bits;
  }
  return out;
}

Tokens tokenize(String src) {
  final n = src.length;
  final types = <int>[];
  final texts = <String>[];
  final starts = <int>[];
  final stack = <int>[];
  var state = _S.INITIAL;
  var p = 0;
  var nextNl = -1;

  void emit(int type, int s, int e) {
    types.add(type);
    texts.add(src.substring(s, e));
    starts.add(s);
    p = e;
  }

  void emitText(int type, int s, int e, String text) {
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

  int eol(int q) {
    if (nextNl < q) {
      nextNl = src.indexOf('\n', q);
      if (nextNl == -1) nextNl = n;
    }
    return nextNl;
  }

  bool has(int q, int bit) {
    final c = charCodeAt(src, q);
    if (c < 0) return false;
    if (c < 128) return (_CLASS[c] & bit) != 0;
    return bit == _C.Id || bit == _C.Menu ? !isSpace(c) : true;
  }

  // Matches a lowercase literal without regard to the case of the source.
  bool ci(int q, String word) {
    if (q + word.length > n) return false;
    for (var k = 0; k < word.length; k++) {
      final w = word.codeUnitAt(k);
      final c = src.codeUnitAt(q + k);
      if (w >= 97 && w <= 122 ? (c | 32) != w : c != w) return false;
    }
    return true;
  }

  bool word(String lit) =>
      ci(p, lit) && !isWord(charCodeAt(src, p + lit.length));

  int skipWs(int q) {
    while (q < n && isSpace(src.codeUnitAt(q))) {
      q++;
    }
    return q;
  }

  bool skipSameLine() {
    var q = p;
    while (q < n) {
      final c = src.codeUnitAt(q);
      if (c == 10 || !isSpace(c)) break;
      q++;
    }
    if (q == p) return false;
    p = q;
    return true;
  }

  int lineRun(int q) {
    while (q < n && has(q, _C.Line)) {
      q++;
    }
    return q;
  }

  void begin(int type, int len, int next) {
    emit(type, p, p + len);
    push(next);
  }

  bool keyword(String lit, int type, [int next = -1]) {
    if (!word(lit)) return false;
    emit(type, p, p + lit.length);
    if (next >= 0) push(next);
    return true;
  }

  // The actor menu keywords count only when spaces and the start of a name follow.
  bool menu(String lit, int type) {
    if (!ci(p, lit)) return false;
    var q = p + lit.length;
    var c = charCodeAt(src, q);
    if (c != 32 && c != 9) return false;
    while (c == 32 || c == 9) {
      c = charCodeAt(src, ++q);
    }
    if (q >= n || !has(q, _C.Menu)) return false;
    emit(type, p, p + lit.length);
    return true;
  }

  bool arrowAhead(int q) {
    final c = charCodeAt(src, q);
    final d = charCodeAt(src, q + 1);
    if (c == 45) {
      if (d == 120 || d == 88 || d == 41 || d == 92 || d == 47 || d == 45) {
        return true;
      }
      final e = charCodeAt(src, q + 2);
      return d == 124 && (e == 92 || e == 47);
    }
    if (c == 47 || c == 92) {
      return (d == 124 || d == c) && charCodeAt(src, q + 2) == 45;
    }
    return c == 40 && d == 41;
  }

  void actor() {
    var q = p + 1;
    while (q < n && has(q, _C.ActorStart)) {
      q++;
    }
    while (q < n && !arrowAhead(q)) {
      var r = q;
      while (charCodeAt(src, r) == 45) {
        r++;
      }
      if (r >= n || !has(r, _C.ActorRest)) break;
      r++;
      while (r < n && has(r, _C.ActorRest)) {
        r++;
      }
      q = r;
    }
    emitText(T.ACTOR, p, q, src.substring(p, q).trim());
  }

  bool number() {
    var q = p;
    while (isDigit(charCodeAt(src, q))) {
      q++;
    }
    final whole = q > p;
    if (charCodeAt(src, q) == 46 && isDigit(charCodeAt(src, q + 1))) {
      final r = isDigit(charCodeAt(src, q + 2)) ? q + 3 : q + 2;
      final after = charCodeAt(src, r);
      if (after == 32 || after == 10) {
        emit(T.NUM, p, r);
        return true;
      }
    }
    final after = charCodeAt(src, q);
    if (whole && (after == 32 || after == 10)) {
      emit(T.NUM, p, q);
      return true;
    }
    return false;
  }

  void dash() {
    final d = charCodeAt(src, p + 1);
    final e = charCodeAt(src, p + 2);
    if (d == 62) {
      emit(
        e == 62 ? T.SOLID_ARROW : T.SOLID_OPEN_ARROW,
        p,
        p + (e == 62 ? 3 : 2),
      );
    } else if (d == 120 || d == 88) {
      emit(T.SOLID_CROSS, p, p + 2);
    } else if (d == 41) {
      emit(T.SOLID_POINT, p, p + 2);
    } else if (d == 124 && e == 92) {
      emit(T.SOLID_ARROW_TOP, p, p + 3);
    } else if (d == 124 && e == 47) {
      emit(T.SOLID_ARROW_BOTTOM, p, p + 3);
    } else if (d == 92 && e == 92) {
      emit(T.STICK_ARROW_TOP, p, p + 3);
    } else if (d == 47 && e == 47) {
      emit(T.STICK_ARROW_BOTTOM, p, p + 3);
    } else if (d == 45) {
      final f = charCodeAt(src, p + 3);
      if (e == 62) {
        emit(
          f == 62 ? T.DOTTED_ARROW : T.DOTTED_OPEN_ARROW,
          p,
          p + (f == 62 ? 4 : 3),
        );
      } else if (e == 120 || e == 88) {
        emit(T.DOTTED_CROSS, p, p + 3);
      } else if (e == 41) {
        emit(T.DOTTED_POINT, p, p + 3);
      } else if (e == 124 && f == 92) {
        emit(T.SOLID_ARROW_TOP_DOTTED, p, p + 4);
      } else if (e == 124 && f == 47) {
        emit(T.SOLID_ARROW_BOTTOM_DOTTED, p, p + 4);
      } else if (e == 92 && f == 92) {
        emit(T.STICK_ARROW_TOP_DOTTED, p, p + 4);
      } else if (e == 47 && f == 47) {
        emit(T.STICK_ARROW_BOTTOM_DOTTED, p, p + 4);
      } else {
        emit(T.MINUS, p, p + 1);
      }
    } else {
      emit(T.MINUS, p, p + 1);
    }
  }

  bool reverse(int c) {
    final d = charCodeAt(src, p + 1);
    if ((d != 124 && d != c) || charCodeAt(src, p + 2) != 45) return false;
    final dotted = charCodeAt(src, p + 3) == 45;
    final top = c == 47;
    int type;
    if (d == 124) {
      if (dotted) {
        type = top
            ? T.SOLID_ARROW_TOP_REVERSE_DOTTED
            : T.SOLID_ARROW_BOTTOM_REVERSE_DOTTED;
      } else {
        type = top ? T.SOLID_ARROW_TOP_REVERSE : T.SOLID_ARROW_BOTTOM_REVERSE;
      }
    } else if (dotted) {
      type = top
          ? T.STICK_ARROW_TOP_REVERSE_DOTTED
          : T.STICK_ARROW_BOTTOM_REVERSE_DOTTED;
    } else {
      type = top ? T.STICK_ARROW_TOP_REVERSE : T.STICK_ARROW_BOTTOM_REVERSE;
    }
    emit(type, p, p + (dotted ? 4 : 3));
    return true;
  }

  bool title() {
    if (!ci(p, 'title')) return false;
    var q = p + 5;
    final legacy = charCodeAt(src, q) == 58;
    if (legacy) q++;
    var e = q;
    while (e < n && src.codeUnitAt(e) != 10 && isSpace(src.codeUnitAt(e))) {
      e++;
    }
    if (e == n || src.codeUnitAt(e) == 10) {
      p = e;
      return true;
    }
    final sep = charCodeAt(src, q);
    if (!isSpace(sep) || sep == 13 || !has(q + 1, _C.Line)) return false;
    emit(legacy ? T.legacy_title : T.title, p, lineRun(q + 1));
    return true;
  }

  bool acc() {
    final descr = ci(p, 'accdescr');
    if (!descr && !ci(p, 'acctitle')) return false;
    final q = skipWs(p + 8);
    final c = charCodeAt(src, q);
    if (c == 58) {
      emit(descr ? T.acc_descr : T.acc_title, p, skipWs(q + 1));
      push(descr ? _S.acc_descr : _S.acc_title);
      return true;
    }
    if (descr && c == 123) {
      p = skipWs(q + 1);
      push(_S.acc_descr_multiline);
      return true;
    }
    return false;
  }

  bool keywords(int c) {
    switch (c | 32) {
      case 97:
        return keyword('actor', T.participant_actor, _S.ID) ||
            keyword('alt', T.alt, _S.LINE) ||
            keyword('and', T.and, _S.LINE) ||
            keyword('activate', T.activate, _S.ID) ||
            acc() ||
            keyword('autonumber', T.autonumber);
      case 98:
        return keyword('box', T.box, _S.LINE) ||
            keyword('break', T.break_, _S.LINE);
      case 99:
        return keyword('create', T.create) ||
            keyword('critical', T.critical, _S.LINE);
      case 100:
        return keyword('destroy', T.destroy, _S.ID) ||
            menu('details', T.details) ||
            keyword('deactivate', T.deactivate, _S.ID);
      case 101:
        return keyword('else', T.else_, _S.LINE) || keyword('end', T.end);
      case 108:
        return keyword('loop', T.loop, _S.LINE) ||
            keyword('left of', T.left_of) ||
            menu('links', T.links) ||
            menu('link', T.link);
      case 110:
        return keyword('note', T.note);
      case 111:
        return keyword('opt', T.opt, _S.LINE) ||
            keyword('option', T.option, _S.LINE) ||
            keyword('over', T.over) ||
            keyword('off', T.off);
      case 112:
        return keyword('participant', T.participant, _S.ID) ||
            keyword('par', T.par, _S.LINE) ||
            keyword('par_over', T.par_over, _S.LINE) ||
            menu('properties', T.properties);
      case 114:
        return keyword('rect', T.rect, _S.LINE) ||
            keyword('right of', T.right_of);
      case 115:
        return keyword('sequencediagram', T.SD);
      case 116:
        return title();
      default:
        return false;
    }
  }

  void initial() {
    final c = src.codeUnitAt(p);
    if (c == 10) {
      var q = p + 1;
      while (charCodeAt(src, q) == 10) {
        q++;
      }
      emit(T.NEWLINE, p, q);
      return;
    }
    if (isSpace(c)) {
      p = skipWs(p + 1);
      return;
    }
    if (c == 35 || (c == 37 && charCodeAt(src, p + 1) != 123)) {
      p = eol(p);
      return;
    }
    if ((isDigit(c) || c == 46) && number()) return;
    if (c < 128 && (c | 32) >= 97 && (c | 32) <= 122 && keywords(c)) return;
    if (c == 44) {
      emit(T.COMMA, p, p + 1);
    } else if (c == 59) {
      emit(T.NEWLINE, p, p + 1);
    } else if (has(p, _C.ActorStart)) {
      actor();
    } else if (c == 45) {
      dash();
    } else if (c == 60 && src.startsWith('<<->>', p)) {
      emit(T.BIDIRECTIONAL_SOLID_ARROW, p, p + 5);
    } else if (c == 60 && src.startsWith('<<-->>', p)) {
      emit(T.BIDIRECTIONAL_DOTTED_ARROW, p, p + 6);
    } else if ((c == 47 || c == 92) && reverse(c)) {
      return;
    } else if (c == 58) {
      emit(T.TXT, p, lineRun(p + 1));
    } else if (c == 43) {
      emit(T.PLUS, p, p + 1);
    } else if (c == 40 && charCodeAt(src, p + 1) == 41) {
      emit(T.CENTRAL, p, p + 2);
    } else {
      emit(T.INVALID, p, p + 1);
    }
  }

  // A participant name, up to an alias, a config object, or the end of the statement.
  bool id() {
    if (skipSameLine()) return true;
    final c = src.codeUnitAt(p);
    if (c == 35) {
      p = eol(p);
      return true;
    }
    if (c == 64 && charCodeAt(src, p + 1) == 123) {
      begin(T.CONFIG_START, 2, _S.CONFIG);
      return true;
    }
    var a = p;
    while (a < n && has(a, _C.Id)) {
      a++;
    }
    if (a > p) {
      final w = skipWs(a);
      if (charCodeAt(src, w) == 64 && charCodeAt(src, w + 1) == 123) {
        emit(T.ACTOR, p, a);
        return true;
      }
      if (w > a && ci(w, 'as') && isSpace(charCodeAt(src, w + 2))) {
        emit(T.ACTOR, p, a);
        push(_S.ALIAS);
        return true;
      }
    }
    var b = a;
    while (b < n && has(b, _C.IdWide)) {
      b++;
    }
    if (b > p) {
      final end = charCodeAt(src, b);
      // Before any other delimiter the name must be followed by a comment, so it ends at the last one.
      var cut = b;
      if (b < n && end != 10 && end != 59) {
        cut--;
        while (cut > p && src.codeUnitAt(cut) != 35) {
          cut--;
        }
      }
      if (cut > p) {
        emitText(T.ACTOR, p, cut, src.substring(p, cut).trim());
        pop();
        return true;
      }
    }
    if (charCodeAt(src, b) == 60) {
      emit(T.INVALID, p, eol(p));
      pop();
      return true;
    }
    if (c != 10) {
      final e = eol(p);
      emitText(T.INVALID, p, e, src.substring(p, e).trim());
      pop();
      return true;
    }
    return false;
  }

  bool step() {
    switch (state) {
      case _S.INITIAL:
        initial();
        return true;
      case _S.ID:
        return id();
      case _S.ALIAS:
        if (skipSameLine()) return true;
        if (src.codeUnitAt(p) == 35) {
          p = eol(p);
          return true;
        }
        pop();
        pop();
        if (word('as')) {
          begin(T.AS, 2, _S.LINE);
        } else {
          emit(T.NEWLINE, p, p);
        }
        return true;
      case _S.LINE:
        if (skipSameLine()) return true;
        if (src.codeUnitAt(p) == 35) {
          p = eol(p);
          return true;
        }
        emit(T.restOfLine, p, lineRun(p));
        pop();
        return true;
      case _S.CONFIG:
        if (src.codeUnitAt(p) != 125) {
          var q = src.indexOf('}', p);
          if (q == -1) q = n;
          emit(T.CONFIG_CONTENT, p, q);
          return true;
        } else {
          final w = skipWs(p + 1);
          final alias =
              w > p + 1 && ci(w, 'as') && isSpace(charCodeAt(src, w + 2));
          emit(T.CONFIG_END, p, p + 1);
          pop();
          if (alias) {
            push(_S.ALIAS);
          } else {
            pop();
          }
          return true;
        }
      case _S.acc_title:
      case _S.acc_descr:
        emit(
          state == _S.acc_title ? T.acc_title_value : T.acc_descr_value,
          p,
          eol(p),
        );
        pop();
        return true;
      default:
        if (src.codeUnitAt(p) == 125) {
          p++;
          pop();
        } else {
          var q = src.indexOf('}', p);
          if (q == -1) q = n;
          emit(T.acc_descr_multiline_value, p, q);
        }
        return true;
    }
  }

  while (p < n) {
    if (!step()) {
      types.add(T.ERROR);
      texts.add('');
      starts.add(p);
      return Tokens(types: types, texts: texts, starts: starts);
    }
  }

  // Mermaid's lexer tries its rules once more on the empty remainder before reporting the end.
  if (state == _S.INITIAL || state == _S.ALIAS) {
    emit(T.NEWLINE, n, n);
  } else if (state == _S.LINE) {
    emit(T.restOfLine, n, n);
  } else if (state == _S.acc_title) {
    emit(T.acc_title_value, n, n);
  } else if (state == _S.acc_descr) {
    emit(T.acc_descr_value, n, n);
  } else if (state == _S.acc_descr_multiline) {
    emit(T.acc_descr_multiline_value, n, n);
  }
  types.add(T.END);
  texts.add('');
  starts.add(n);
  return Tokens(types: types, texts: texts, starts: starts);
}

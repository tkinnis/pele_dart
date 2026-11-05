// Upstream: src/diagrams/gantt/lexer.ts

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

abstract final class _S {
  static const int initial = 0;
  static const int accTitle = 1;
  static const int accDescr = 2;
  static const int accDescrMultiline = 3;
  static const int href = 4;
  static const int callbackname = 5;
  static const int callbackargs = 6;
  static const int click = 7;
}

final RegExp _reAccTitle = RegExp(r'accTitle\s*:\s*', caseSensitive: false);
final RegExp _reAccDescr = RegExp(r'accDescr\s*:\s*', caseSensitive: false);
final RegExp _reAccDescrMl = RegExp(r'accDescr\s*\{\s*', caseSensitive: false);
final RegExp _reHref = RegExp(r'href\s+"', caseSensitive: false);
final RegExp _reCall = RegExp(r'call\s+', caseSensitive: false);
final RegExp _reClick = RegExp(r'click\s+', caseSensitive: false);
final RegExp _reEmptyCall = RegExp(r'\(\s*\)');
final RegExp _reWeekday = RegExp(
  r'weekday\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
  caseSensitive: false,
);
const List<String> _days = <String>[
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];
final RegExp _reWeekend = RegExp(
  r'weekend\s+(?:(friday)|saturday)\b',
  caseSensitive: false,
);
final RegExp _reDate = RegExp(r'\d\d\d\d-\d\d-\d\d\b');
final RegExp _reBareTitle = RegExp(
  r'title[^\S\r\n]*(?=[\r\n]|$)',
  caseSensitive: false,
);

// Statements that start with a keyword, grouped by the keyword's first letter and kept in the grammar's rule order.
final Map<int, List<(RegExp, int)>> _keywords = <int, List<(RegExp, int)>>{
  97: <(RegExp, int)>[
    (RegExp(r'axisFormat\s[^#\n;]+', caseSensitive: false), T.axisFormat),
    (
      RegExp(r'accDescription\s[^#\n;]+', caseSensitive: false),
      T.accDescription,
    ),
  ],
  103: <(RegExp, int)>[(RegExp(r'gantt\b', caseSensitive: false), T.gantt)],
  100: <(RegExp, int)>[
    (RegExp(r'dateFormat\s[^#\n;]+', caseSensitive: false), T.dateFormat),
  ],
  105: <(RegExp, int)>[
    (RegExp(r'inclusiveEndDates\b', caseSensitive: false), T.inclusiveEndDates),
    (RegExp(r'includes\s[^#\n;]+', caseSensitive: false), T.includes),
  ],
  116: <(RegExp, int)>[
    (RegExp(r'topAxis\b', caseSensitive: false), T.topAxis),
    (RegExp(r'tickInterval\s[^#\n;]+', caseSensitive: false), T.tickInterval),
    (RegExp(r'todayMarker\s[^\n;]+', caseSensitive: false), T.todayMarker),
    (RegExp(r'title[^\S\r\n][^\n]+', caseSensitive: false), T.title),
  ],
  101: <(RegExp, int)>[
    (RegExp(r'excludes\s[^#\n;]+', caseSensitive: false), T.excludes),
  ],
  115: <(RegExp, int)>[
    (RegExp(r'section\s[^\n]+', caseSensitive: false), T.section),
  ],
};

Tokens tokenize(String src) {
  final n = src.length;
  final types = <int>[];
  final texts = <String>[];
  final starts = <int>[];
  var state = _S.initial;
  var p = 0;

  void emit(int type, int s, int e) {
    types.add(type);
    texts.add(sliceJs(src, s, e));
    starts.add(s);
    p = e;
  }

  int at(RegExp re) => matchSticky(re, src, p);

  int until(String ch, int from) {
    final e = src.indexOf(ch, from);
    return e == -1 ? n : e;
  }

  bool keyword(int c) {
    int e;
    switch (c | 32) {
      case 97:
        if ((e = at(_reAccTitle)) >= 0) {
          state = _S.accTitle;
          emit(T.acc_title, p, e);
          return true;
        }
        if ((e = at(_reAccDescr)) >= 0) {
          state = _S.accDescr;
          emit(T.acc_descr, p, e);
          return true;
        }
        if ((e = at(_reAccDescrMl)) >= 0) {
          state = _S.accDescrMultiline;
          p = e;
          return true;
        }
        break;
      case 104:
        if ((e = at(_reHref)) >= 0) {
          state = _S.href;
          p = e;
          return true;
        }
        break;
      case 99:
        if ((e = at(_reCall)) >= 0) {
          state = _S.callbackname;
          p = e;
          return true;
        }
        if ((e = at(_reClick)) >= 0) {
          state = _S.click;
          p = e;
          return true;
        }
        break;
      case 116:
        if ((e = at(_reBareTitle)) >= 0) {
          p = e;
          return true;
        }
        break;
      case 119:
        var m = execSticky(_reWeekday, src, p);
        if (m != null) {
          emit(
            T.weekday_monday + _days.indexOf(m.group(1)!.toLowerCase()),
            p,
            m.end,
          );
          return true;
        }
        m = execSticky(_reWeekend, src, p);
        if (m != null) {
          emit(
            m.group(1) != null ? T.weekend_friday : T.weekend_saturday,
            p,
            m.end,
          );
          return true;
        }
        break;
    }
    final rules = _keywords[c | 32];
    if (rules != null) {
      for (final (re, type) in rules) {
        if ((e = at(re)) >= 0) {
          emit(type, p, e);
          return true;
        }
      }
    }
    return false;
  }

  while (true) {
    if (p >= n) {
      var type = T.EOF;
      switch (state) {
        case _S.accTitle:
          type = T.acc_title_value;
          break;
        case _S.accDescr:
          type = T.acc_descr_value;
          break;
        case _S.accDescrMultiline:
          type = T.acc_descr_multiline_value;
          break;
        case _S.href:
          type = T.href;
          break;
        case _S.callbackname:
          type = T.callbackname;
          break;
        case _S.callbackargs:
          type = T.callbackargs;
          break;
        case _S.click:
          type = T.click;
          break;
      }
      emit(type, n, n);
      break;
    }

    final c = charCodeAt(src, p);

    switch (state) {
      case _S.initial:
        final d = charCodeAt(src, p + 1);
        if (c == 37) {
          if (d != 37) {
            var e = until('\n', p + 1);
            while (charCodeAt(src, e) == 10) {
              e++;
            }
            p = e;
          } else if (charCodeAt(src, p + 2) == 123) {
            // The grammar enters a lexer state it never defines, so nothing can follow.
            emit(T.open_directive, p, p + 3);
            emit(T.ERROR, p, p);
            return Tokens(types: types, texts: texts, starts: starts);
          } else {
            p = until('\n', p + 2);
          }
        } else if (c == 10) {
          var e = p + 1;
          while (charCodeAt(src, e) == 10) {
            e++;
          }
          emit(T.NL, p, e);
        } else if (isSpace(c)) {
          p++;
          while (p < n && isSpace(charCodeAt(src, p))) {
            p++;
          }
        } else if (keyword(c)) {
          break;
        } else if (c >= 48 && c <= 57 && at(_reDate) >= 0) {
          emit(T.date, p, p + 10);
        } else if (c != 58) {
          var e = p + 1;
          while (e < n) {
            final ch = charCodeAt(src, e);
            if (ch == 58 || ch == 10) break;
            e++;
          }
          emit(T.taskTxt, p, e);
        } else {
          var e = p + 1;
          while (e < n) {
            final ch = charCodeAt(src, e);
            if (ch == 35 || ch == 10 || ch == 59) break;
            e++;
          }
          emit(e > p + 1 ? T.taskData : T.COLON, p, e);
        }
        break;

      case _S.accTitle:
      case _S.accDescr:
        final type = state == _S.accTitle
            ? T.acc_title_value
            : T.acc_descr_value;
        state = _S.initial;
        emit(type, p, until('\n', p));
        break;

      case _S.accDescrMultiline:
        if (c == 125) {
          state = _S.initial;
          p++;
        } else {
          emit(T.acc_descr_multiline_value, p, until('}', p));
        }
        break;

      case _S.href:
        if (c == 34) {
          state = _S.initial;
          p++;
        } else {
          emit(T.href, p, until('"', p));
        }
        break;

      case _S.callbackname:
        if (c == 40) {
          final e = at(_reEmptyCall);
          if (e >= 0) {
            state = _S.initial;
            p = e;
          } else {
            state = _S.callbackargs;
            p++;
          }
        } else {
          emit(T.callbackname, p, until('(', p));
        }
        break;

      case _S.callbackargs:
        if (c == 41) {
          state = _S.initial;
          p++;
        } else {
          emit(T.callbackargs, p, until(')', p));
        }
        break;

      case _S.click:
        if (isSpace(c)) {
          state = _S.initial;
          p++;
        } else {
          var e = p + 1;
          while (e < n && !isSpace(charCodeAt(src, e))) {
            e++;
          }
          emit(T.click, p, e);
        }
        break;
    }
  }

  types.add(T.END);
  texts.add('');
  starts.add(n);
  return Tokens(types: types, texts: texts, starts: starts);
}

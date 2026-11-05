// Upstream: src/diagrams/journey/lexer.ts

import '../../util/chars.dart';
import '../../util/math_js.dart';
import '../common/scan.dart';

abstract final class T {
  static const int END = 0;
  static const int EOF = 1;
  static const int INVALID = 2;
  static const int NEWLINE = 3;
  static const int journey = 4;
  static const int title = 5;
  static const int acc_title = 6;
  static const int acc_title_value = 7;
  static const int acc_descr = 8;
  static const int acc_descr_value = 9;
  static const int acc_descr_multiline_value = 10;
  static const int section = 11;
  static const int taskName = 12;
  static const int taskData = 13;
  static const int colon = 14;
}

const List<String> TOKEN_NAMES = <String>[
  r'$end',
  'EOF',
  'INVALID',
  'NEWLINE',
  'journey',
  'title',
  'acc_title',
  'acc_title_value',
  'acc_descr',
  'acc_descr_value',
  'acc_descr_multiline_value',
  'section',
  'taskName',
  'taskData',
  ':',
];

// `#`, a line break, and `;` end every kind of text; a colon also ends a task name or a section.
int _textEnd(String src, int from, bool colon) {
  final n = src.length;
  var e = from;
  for (; e < n; e++) {
    final c = src.codeUnitAt(e);
    if (c == 35 || c == 10 || c == 59 || (colon && c == 58)) break;
  }
  return e;
}

Tokens tokenize(String src) {
  final n = src.length;
  final types = <int>[];
  final texts = <String>[];
  final starts = <int>[];
  final out = Tokens(types: types, texts: texts, starts: starts);
  var p = 0;

  void emit(int type, int e) {
    types.add(type);
    texts.add(sliceJs(src, p, e));
    starts.add(p);
    p = e;
  }

  for (;;) {
    p = skipTrivia(src, p);
    if (p >= n) break;
    final c = charCodeAt(src, p);
    var e = p + 1;
    if (c == 10) {
      while (charCodeAt(src, e) == 10) {
        e++;
      }
      emit(T.NEWLINE, e);
      continue;
    }
    if (keywordAt(src, p, 'journey') && !isWord(charCodeAt(src, p + 7))) {
      emit(T.journey, p + 7);
      continue;
    }
    if (keywordAt(src, p, 'title')) {
      // Unlike Mermaid, ignore bare titles.
      e = p + 5;
      while (charCodeAt(src, e) != 10 && isSpace(charCodeAt(src, e))) {
        e++;
      }
      if (e == n || charCodeAt(src, e) == 10) {
        p = e;
        continue;
      }
      final sep = charCodeAt(src, p + 5);
      if (sep != 13 && isSpace(sep)) {
        e = _textEnd(src, p + 6, false);
        if (e > p + 6) {
          emit(T.title, e);
          continue;
        }
      }
    }
    e = accessibility(src, p, out, T.acc_title);
    if (e != p) {
      p = e;
      continue;
    }
    // Like Mermaid, a bare section uses the next line as its name.
    if (keywordAt(src, p, 'section') && isSpace(charCodeAt(src, p + 7))) {
      e = _textEnd(src, p + 8, true);
      if (e > p + 8) {
        emit(T.section, e);
        continue;
      }
    }
    if (c == 58) {
      e = _textEnd(src, p + 1, false);
      emit(e > p + 1 ? T.taskData : T.colon, e > p + 1 ? e : p + 1);
    } else if (c == 59) {
      emit(T.INVALID, p + 1);
    } else {
      emit(T.taskName, _textEnd(src, p + 1, true));
    }
  }

  // Jison marks its lexer done when a rule runs on empty input, so an accessibility value that
  // matches nothing at the very end of the text is followed by no EOF token.
  if (starts.isEmpty || starts[starts.length - 1] < n) emit(T.EOF, n);
  emit(T.END, n);
  return out;
}

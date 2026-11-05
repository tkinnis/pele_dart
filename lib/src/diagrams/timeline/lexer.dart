// Upstream: src/diagrams/timeline/lexer.ts

import '../../util/chars.dart';
import '../../util/math_js.dart';
import '../common/scan.dart';

abstract final class T {
  static const int END = 0;
  static const int EOF = 1;
  static const int INVALID = 2;
  static const int NEWLINE = 3;
  static const int timeline = 4;
  static const int timeline_lr = 5;
  static const int timeline_td = 6;
  static const int title = 7;
  static const int acc_title = 8;
  static const int acc_title_value = 9;
  static const int acc_descr = 10;
  static const int acc_descr_value = 11;
  static const int acc_descr_multiline_value = 12;
  static const int section = 13;
  static const int period = 14;
  static const int event = 15;
}

const List<String> TOKEN_NAMES = <String>[
  r'$end',
  'EOF',
  'INVALID',
  'NEWLINE',
  'timeline',
  'timeline_lr',
  'timeline_td',
  'title',
  'acc_title',
  'acc_title_value',
  'acc_descr',
  'acc_descr_value',
  'acc_descr_multiline_value',
  'section',
  'period',
  'event',
];

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
    if (keywordAt(src, p, 'timeline')) {
      e = p + 8;
      while (charCodeAt(src, e) == 32 || charCodeAt(src, e) == 9) {
        e++;
      }
      final lr = keywordAt(src, e, 'lr');
      if (e > p + 8 &&
          (lr || keywordAt(src, e, 'td')) &&
          !isWord(charCodeAt(src, e + 2))) {
        emit(lr ? T.timeline_lr : T.timeline_td, e + 2);
        continue;
      }
      if (!isWord(charCodeAt(src, p + 8))) {
        emit(T.timeline, p + 8);
        continue;
      }
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
        emit(T.title, lineEnd(src, p + 6));
        continue;
      }
    }
    e = accessibility(src, p, out, T.acc_title);
    if (e != p) {
      p = e;
      continue;
    }
    // Like Mermaid, a bare section uses the next line as its name.
    if (keywordAt(src, p, 'section') && isSpace(charCodeAt(src, p + 7))) {
      e = p + 8;
      while (e < n && charCodeAt(src, e) != 58 && charCodeAt(src, e) != 10) {
        e++;
      }
      if (e > p + 8) {
        emit(T.section, e);
        continue;
      }
    }
    if (c != 58) {
      e = p + 1;
      for (
        var k = charCodeAt(src, e);
        e < n && k != 35 && k != 58 && k != 10;
        k = charCodeAt(src, ++e)
      ) {}
      emit(T.period, e);
      continue;
    }
    // An event runs to the end of the line or to a colon that is followed by whitespace.
    if (isSpace(charCodeAt(src, p + 1))) {
      e = p + 2;
      for (; e < n; e++) {
        final k = charCodeAt(src, e);
        if (k == 10 || (k == 58 && isSpace(charCodeAt(src, e + 1)))) break;
      }
      if (e > p + 2) {
        emit(T.event, e);
        continue;
      }
    }
    emit(T.INVALID, p + 1);
  }

  // Jison marks its lexer done when a rule runs on empty input, so an accessibility value that
  // matches nothing at the very end of the text is followed by no EOF token.
  if (starts.isEmpty || starts[starts.length - 1] < n) emit(T.EOF, n);
  emit(T.END, n);
  return out;
}

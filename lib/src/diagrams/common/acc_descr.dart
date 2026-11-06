// Upstream: src/diagrams/common/accDescr.ts

import 'tokens.dart';

final RegExp _reHead = RegExp(
  r'[\t ]*accDescr(?:[\t ]*:(?:[^\n\r]*?(?=%%)|[^\n\r]*)|\s*(\{))',
);

Scanner _scanner() {
  var unclosed = false;
  return (src, at, _) {
    final n = src.length;
    var q = at;
    while (q < n) {
      final c = src.codeUnitAt(q);
      if (c != 32 && c != 9) break;
      q++;
    }
    if (!src.startsWith('accDescr', q)) return -1;
    final m = _reHead.matchAsPrefix(src, q);
    if (m == null) return -1;
    final end = m.end;
    if (m.group(1) == null) return end;
    if (unclosed) return -1;
    final close = src.indexOf('}', end);
    unclosed = close == -1;
    final res = close + 1;
    return res != 0 ? res : -1;
  };
}

TokenType accDescr([String name = 'ACC_DESCR']) {
  return TokenType(
    name: name,
    pattern: ACC_DESCR.pattern,
    first: ACC_DESCR.first,
    scanner: _scanner,
  );
}

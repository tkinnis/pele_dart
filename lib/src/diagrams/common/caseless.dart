// Upstream: src/diagrams/common/caseless.ts

import '../../util/math_js.dart';

/// Whether `word`, written in lower case, is at `at`. Only ASCII letters match in either case.
bool wordAt(String src, int at, String word) {
  for (var k = 0; k < word.length; k++) {
    final c = charCodeAt(src, at + k);
    final w = word.codeUnitAt(k);
    if (c != w && !(w >= 97 && w <= 122 && c == w - 32)) return false;
  }
  return true;
}

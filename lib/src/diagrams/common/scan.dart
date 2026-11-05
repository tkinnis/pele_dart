// Upstream: src/diagrams/common/scan.ts

import '../../util/chars.dart';
import '../../util/math_js.dart';

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

int lineEnd(String src, int from) {
  final at = src.indexOf('\n', from);
  return at == -1 ? src.length : at;
}

bool keywordAt(String src, int p, String word) {
  for (var i = 0; i < word.length; i++) {
    if ((charCodeAt(src, p + i) | 32) != word.codeUnitAt(i)) return false;
  }
  return true;
}

int skipTrivia(String src, int from) {
  final n = src.length;
  var p = from;
  while (p < n) {
    final c = charCodeAt(src, p);
    if (c == 37 && charCodeAt(src, p + 1) != 123) {
      p = lineEnd(src, p);
    } else if (c == 10) {
      return p;
    } else if (isSpace(c)) {
      do {
        p++;
      } while (p < n && isSpace(charCodeAt(src, p)));
    } else if (c == 35) {
      p = lineEnd(src, p);
    } else {
      return p;
    }
  }
  return p;
}

int _skipSpace(String src, int from) {
  var p = from;
  while (isSpace(charCodeAt(src, p))) {
    p++;
  }
  return p;
}

int accessibility(String src, int p, Tokens out, int first) {
  final descr = keywordAt(src, p, 'accdescr');
  if (!descr && !keywordAt(src, p, 'acctitle')) return p;
  final n = src.length;
  var q = _skipSpace(src, p + 8);
  final c = charCodeAt(src, q);
  void emit(int type, int s, int e) {
    out.types.add(type);
    out.texts.add(src.substring(s, e));
    out.starts.add(s);
  }

  if (c == 58) {
    q = _skipSpace(src, q + 1);
    final end = lineEnd(src, q);
    emit(descr ? first + 2 : first, p, q);
    emit(descr ? first + 3 : first + 1, q, end);
    return end;
  }
  if (!descr || c != 123) return p;
  q = _skipSpace(src, q + 1);
  while (charCodeAt(src, q) != 125) {
    var end = src.indexOf('}', q);
    if (end == -1) end = n;
    emit(first + 4, q, end);
    if (q == n) return n;
    q = end;
  }
  return q + 1;
}

// JavaScript numeric, string, and RegExp compatibility helpers for 1:1 upstream ports.

import 'dart:math' as math;

/// JavaScript `Math.round(v)`: rounds half toward `+Infinity` (`Math.floor(v + 0.5)`).
int roundJs(num v) => (v + 0.5).floor();

/// JavaScript `Math.hypot(a, b)`: Euclidean distance `sqrt(a*a + b*b)`.
double hypot(num a, num b) => math.sqrt(a * a + b * b);

/// JavaScript `Math.sign(v)` returning `-1`, `0`, or `1`.
double signJs(num v) {
  if (v.isNaN) return double.nan;
  if (v > 0) return 1.0;
  if (v < 0) return -1.0;
  return 0.0;
}

/// Safe replacement for JavaScript `str.charCodeAt(index)`.
/// Returns `-1` when `index < 0 || index >= str.length` instead of throwing [RangeError].
int charCodeAt(String s, int index) =>
    (index >= 0 && index < s.length) ? s.codeUnitAt(index) : -1;

/// Safe replacement for JavaScript `str[index]` character indexing.
/// Returns `null` when `index < 0 || index >= str.length`.
String? charAtOrNull(String s, int index) =>
    (index >= 0 && index < s.length) ? s[index] : null;

/// Safe replacement for JavaScript `str.slice(start, [end])`.
String sliceJs(String s, int start, [int? end]) {
  final len = s.length;
  final a = start < 0 ? math.max(len + start, 0) : math.min(start, len);
  var b = end == null
      ? len
      : (end < 0 ? math.max(len + end, 0) : math.min(end, len));
  if (b < a) b = a;
  return s.substring(a, b);
}

/// Safe replacement for JavaScript sticky regex `re.lastIndex = at; re.test(src) ? re.lastIndex : -1`.
int matchSticky(RegExp re, String src, int at) {
  if (at < 0 || at > src.length) return -1;
  final m = re.matchAsPrefix(src, at);
  return m != null ? m.end : -1;
}

/// Safe replacement for JavaScript sticky regex `re.lastIndex = at; re.exec(src)`.
RegExpMatch? execSticky(RegExp re, String src, int at) {
  if (at < 0 || at > src.length) return null;
  return re.matchAsPrefix(src, at) as RegExpMatch?;
}

/// JavaScript `Array.from(str)` splitting a string into Unicode code-point strings
/// (keeping surrogate pairs together).
List<String> codePointsOf(String s) =>
    s.runes.map(String.fromCharCode).toList();

// Upstream: src/diagrams/ishikawa/lexer.ts

import '../../util/chars.dart';
import '../../util/math_js.dart';

class T {
  static const int END = 0;
  static const int EOF = 1;
  static const int SPACELINE = 2;
  static const int NL = 3;
  static const int ISHIKAWA = 4;
  static const int SPACELIST = 5;
  static const int TEXT = 6;
}

const List<String> TOKEN_NAMES = <String>[
  r'$end',
  'EOF',
  'SPACELINE',
  'NL',
  'ISHIKAWA',
  'SPACELIST',
  'TEXT',
];

class Tokens {
  final List<int> types;
  final List<int> starts;
  final List<int> ends;

  const Tokens({required this.types, required this.starts, required this.ends});
}

int _keyword(String src, int at) {
  const word = 'ishikawa-beta';
  var k = 0;
  while (k < 13) {
    final c = charCodeAt(src, at + k);
    final w = word.codeUnitAt(k);
    if (c != w && (c + 32 != w || c < 65 || c > 90)) break;
    k++;
  }
  // `ishikawa-beta`, or failing that `ishikawa`, either one ending at a word boundary.
  if (k == 13 && !isWord(charCodeAt(src, at + 13))) return 13;
  return k >= 8 && !isWord(charCodeAt(src, at + 8)) ? 8 : 0;
}

// Produces the tokens of Mermaid's Jison lexer for Ishikawa diagrams, where the first rule that
// matches wins: white space up to a comment or up to the last line break in it is a blank line,
// a single line break before text is a new line, other white space is indentation, and the rest
// of a line is text.
Tokens tokenize(String src) {
  final types = <int>[];
  final starts = <int>[];
  final ends = <int>[];
  final n = src.length;
  var i = 0;
  while (i < n) {
    var j = i;
    var lastBreak = -1;
    while (j < n && isSpace(src.codeUnitAt(j))) {
      if (src.codeUnitAt(j) == 10) lastBreak = j;
      j++;
    }
    int type;
    int end;
    if (charCodeAt(src, j) == 37 && charCodeAt(src, j + 1) == 37) {
      type = T.SPACELINE;
      end = j + 2;
      while (end < n) {
        final c = src.codeUnitAt(end);
        if (c == 10 || c == 13 || c == 0x2028 || c == 0x2029) break;
        end++;
      }
    } else if (j == i) {
      final length = _keyword(src, i);
      if (length > 0) {
        type = T.ISHIKAWA;
        end = i + length;
      } else {
        type = T.TEXT;
        end = src.indexOf('\n', i);
        if (end == -1) end = n;
      }
    } else if (lastBreak > i) {
      type = T.SPACELINE;
      end = lastBreak + 1;
    } else if (lastBreak == i) {
      type = T.NL;
      end = i + 1;
    } else {
      type = T.SPACELIST;
      end = j;
    }
    types.add(type);
    starts.add(i);
    ends.add(end);
    i = end;
  }
  types.addAll(const <int>[T.EOF, T.END]);
  starts.addAll(<int>[n, n]);
  ends.addAll(<int>[n, n]);
  return Tokens(types: types, starts: starts, ends: ends);
}

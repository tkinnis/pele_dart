// Upstream: src/diagrams/usecase/lexer.ts

import 'dart:typed_data';

import '../../errors.dart';
import '../../util/chars.dart' show isBlank, isDigit, isHex, isLetter;
import '../../util/math_js.dart';
import 'tokens.dart';

class Tokens {
  const Tokens({required this.types, required this.starts, required this.ends});

  final List<int> types;
  final List<int> starts;
  final List<int> ends;
}

const int _word = 1;
const int _punctuation = 2;

final Uint8List _class = () {
  final table = Uint8List(128);
  for (var c = 48; c <= 57; c++) {
    table[c] = _word;
  }
  for (var c = 65; c <= 90; c++) {
    table[c] = table[c + 32] = _word;
  }
  table[95] = _word;
  const punct = r'!#$&*+/=?^|~';
  for (var i = 0; i < punct.length; i++) {
    table[punct.codeUnitAt(i)] = _punctuation;
  }
  return table;
}();

const List<int> _keywordLength = <int>[
  0,
  12,
  5,
  14,
  3,
  9,
  2,
  2,
  2,
  2,
  2,
  4,
  3,
  4,
  8,
  5,
  5,
  7,
  6,
  4,
  5,
];

bool _isWord(int c) {
  return c >= 0 && c < 128 && (_class[c] & _word) != 0;
}

// Mermaid's INCLUDE and EXTEND are the only keywords matched without regard to case.
bool _startsWithNoCase(String src, int at, String word) {
  for (var k = 0; k < word.length; k++) {
    if ((charCodeAt(src, at + k) | 32) != word.codeUnitAt(k)) return false;
  }
  return true;
}

// The keyword that is a prefix of the text at `at`, tried in the order of Mermaid's token list.
int _keywordAt(String src, int at, int c) {
  switch (c) {
    case 97:
      return src.startsWith('actor', at) ? T.ACTOR : 0;
    case 115:
      return src.startsWith('systemBoundary', at)
          ? T.SYSTEM_BOUNDARY
          : src.startsWith('style', at)
          ? T.STYLE
          : 0;
    case 101:
      return src.startsWith('end', at)
          ? T.END
          : _startsWithNoCase(src, at, 'extend')
          ? T.EXTEND
          : 0;
    case 69:
      return _startsWithNoCase(src, at, 'extend') ? T.EXTEND : 0;
    case 100:
      return src.startsWith('direction', at) ? T.DIRECTION : 0;
    case 84:
      return src.startsWith('TD', at)
          ? T.TD
          : src.startsWith('TB', at)
          ? T.TB
          : 0;
    case 66:
      return src.startsWith('BT', at) ? T.BT : 0;
    case 76:
      return src.startsWith('LR', at) ? T.LR : 0;
    case 82:
      return src.startsWith('RL', at) ? T.RL : 0;
    case 110:
      return src.startsWith('note', at) ? T.NOTE : 0;
    case 102:
      return src.startsWith('for', at)
          ? T.FOR
          : src.startsWith('false', at)
          ? T.FALSE
          : 0;
    case 106:
      return src.startsWith('json', at) ? T.JSON : 0;
    case 99:
      return src.startsWith('classDef', at)
          ? T.CLASS_DEF
          : src.startsWith('class', at)
          ? T.CLASS
          : 0;
    case 105:
    case 73:
      return _startsWithNoCase(src, at, 'include') ? T.INCLUDE : 0;
    case 116:
      return src.startsWith('true', at) ? T.TRUE : 0;
    case 117:
      return src.startsWith('usecase-beta', at) ? T.USECASE : 0;
    default:
      return 0;
  }
}

(int, int) lineColumn(String src, int offset) {
  (src, offset) = written(src, offset);
  var line = 1;
  var lineStart = 0;
  for (var i = 0; i < offset; i++) {
    final c = charCodeAt(src, i);
    if (c != 10 && c != 13) continue;
    if (c == 13 && i + 1 < offset && charCodeAt(src, i + 1) == 10) i++;
    line++;
    lineStart = i + 1;
  }
  return (line, offset - lineStart + 1);
}

String locationText(String src, int start, int end) {
  final (line, column) = lineColumn(src, start);
  return 'line $line, column $column [${written(src, start).$2},${written(src, end).$2})';
}

// The end of a quoted string that opens at `at`, or -1 when the line ends first.
int _stringEnd(String src, int at, int quote) {
  for (var k = at + 1; k < src.length; k++) {
    final c = charCodeAt(src, k);
    if (c == quote) return k + 1;
    if (c == 10 || c == 13) return -1;
  }
  return -1;
}

bool _startsToken(String src, int at) {
  final c = charCodeAt(src, at);
  if (c != 34 && c != 39) return true;
  return (c == 34 && charCodeAt(src, at + 1) == 96) ||
      _stringEnd(src, at, c) != -1;
}

// Mermaid reports the first character no token starts with, and how many characters its lexer
// skipped before one did.
PeleError _lexError(String src, int offset, int length) {
  final (line, column) = lineColumn(src, offset);
  final from = written(src, offset).$2;
  final to = written(src, offset + length).$2;
  final ch = charAtOrNull(src, offset) ?? '';
  return PeleError(
    'Error lexing usecase diagram: unexpected character: ->$ch<- at offset: $from, skipped ${to - from} characters. at line $line, column $column [$from,$to)',
    'syntax',
    PeleErrorInfo(type: 'usecase', line: line, column: column),
  );
}

// Produces the tokens of Mermaid's Chevrotain lexer for use case diagrams: the first pattern in
// its list that matches wins, a keyword gives way to a longer identifier, and `json id@` and `<<`
// switch to modes that read a JSON object and a stereotype.
Tokens tokenize(String src) {
  final types = <int>[];
  final starts = <int>[];
  final ends = <int>[];
  final n = src.length;
  var i = 0;
  // Whether only blanks came before on this line, where comments and accessibility lines may start.
  var lineStart = true;
  var noBrace = false;

  while (i < n) {
    final c = charCodeAt(src, i);
    if (c == 32 || c == 9) {
      i++;
      continue;
    }
    int type;
    var end = i + 1;
    var fresh = false;

    if (c >= 0 && c < 128 && (_class[c] & _word) != 0) {
      type = 0;
      if (c == 97 && lineStart && src.startsWith('acc', i)) {
        final descr = src.startsWith('Descr', i + 3);
        if (descr || src.startsWith('Title', i + 3)) {
          var j = i + 8;
          while (isBlank(charCodeAt(src, j))) {
            j++;
          }
          final next = charCodeAt(src, j);
          if (next == 58) {
            type = descr ? T.ACC_DESCR_LINE : T.ACC_TITLE_LINE;
            end = j + 1;
            while (end < n &&
                charCodeAt(src, end) != 10 &&
                charCodeAt(src, end) != 13) {
              end++;
            }
          } else if (next == 123 && descr && !noBrace) {
            final close = src.indexOf('}', j + 1);
            if (close == -1) {
              noBrace = true;
            } else {
              type = T.ACC_DESCR_BLOCK;
              end = close + 1;
            }
          }
        }
      } else if (c == 106 &&
          src.startsWith('json', i) &&
          isBlank(charCodeAt(src, i + 4))) {
        var j = i + 5;
        while (isBlank(charCodeAt(src, j))) {
          j++;
        }
        final id = j;
        while (_isWord(charCodeAt(src, j))) {
          j++;
        }
        if (j > id) {
          while (isBlank(charCodeAt(src, j))) {
            j++;
          }
          if (charCodeAt(src, j) == 64) {
            j++;
            while (isBlank(charCodeAt(src, j))) {
              j++;
            }
            if (charCodeAt(src, j) == 123) {
              types.add(T.JSON_DECLARATION_START);
              starts.add(i);
              ends.add(j);
              i = j;
              var depth = 0;
              var quoted = false;
              var escaped = false;
              var k = j;
              for (; k < n; k++) {
                final ch = charCodeAt(src, k);
                if (quoted) {
                  if (escaped) {
                    escaped = false;
                  } else if (ch == 92) {
                    escaped = true;
                  } else if (ch == 34) {
                    quoted = false;
                  }
                } else if (ch == 34) {
                  quoted = true;
                } else if (ch == 123) {
                  depth++;
                } else if (ch == 125 && --depth == 0) {
                  break;
                }
              }
              types.add(
                k < n ? T.JSON_OBJECT_LITERAL : T.UNCLOSED_JSON_OBJECT_LITERAL,
              );
              starts.add(j);
              i = k < n ? k + 1 : n;
              ends.add(i);
              lineStart = false;
              continue;
            }
          }
        }
      }
      if (type == 0) {
        while (end < n && _isWord(charCodeAt(src, end))) {
          end++;
        }
        final keyword = _keywordAt(src, i, c);
        if (keyword != 0) {
          // A keyword that is only the start of a longer word is an identifier.
          if (keyword == T.USECASE || end - i == _keywordLength[keyword]) {
            type = keyword;
            end = i + _keywordLength[keyword];
          } else {
            type = T.IDENTIFIER;
          }
        } else if ((c == 111 || c == 120) &&
            charCodeAt(src, i + 1) == 45 &&
            charCodeAt(src, i + 2) == 45) {
          type = c == 111 ? T.BACKWARD_CIRCLE : T.BACKWARD_CROSS;
          end = i + 3;
        } else if (isDigit(c)) {
          // `1mg` is an identifier, and `1.5px` is a number because the identifier stops at the dot.
          var digits = i + 1;
          while (isDigit(charCodeAt(src, digits))) {
            digits++;
          }
          if (charCodeAt(src, digits) == 46 &&
              isDigit(charCodeAt(src, digits + 1))) {
            type = T.NUMBER;
            end = digits + 2;
            while (isDigit(charCodeAt(src, end))) {
              end++;
            }
            while (isLetter(charCodeAt(src, end))) {
              end++;
            }
          } else {
            type = T.IDENTIFIER;
          }
        } else {
          type = T.IDENTIFIER;
          while (charCodeAt(src, end) == 45 &&
              _isWord(charCodeAt(src, end + 1))) {
            type = T.CSS_IDENTIFIER;
            end += 2;
            while (_isWord(charCodeAt(src, end))) {
              end++;
            }
          }
        }
      }
    } else if (c == 10) {
      type = T.NEWLINE;
      fresh = true;
    } else if (c == 13) {
      type = T.NEWLINE;
      fresh = true;
      if (charCodeAt(src, end) == 10) end++;
    } else if (c == 34 || c == 39) {
      if (c == 34 && charCodeAt(src, i + 1) == 96) {
        final close = src.indexOf('`"', i + 2);
        type = close == -1 ? T.UNCLOSED_MARKDOWN_STRING : T.MARKDOWN_STRING;
        end = close == -1 ? n : close + 2;
      } else {
        type = T.PLAIN_STRING;
        end = _stringEnd(src, i, c);
        if (end == -1) {
          var resume = i + 1;
          while (resume < n && !_startsToken(src, resume)) {
            resume++;
          }
          throw _lexError(src, i, resume - i);
        }
      }
    } else if (c == 37) {
      if (lineStart && charCodeAt(src, end) == 37) {
        type = T.COMMENT;
        while (end < n &&
            charCodeAt(src, end) != 10 &&
            charCodeAt(src, end) != 13) {
          end++;
        }
      } else {
        type = T.PERCENT;
      }
    } else if (c == 45) {
      if (charCodeAt(src, end) != 45) {
        type = T.DASH;
      } else {
        while (charCodeAt(src, end) == 45) {
          end++;
        }
        final next = charCodeAt(src, end);
        final two = end - i == 2;
        if (two && next == 124 && charCodeAt(src, end + 1) == 62) {
          type = T.GENERALIZATION;
          end += 2;
        } else if (next == 62) {
          type = T.FORWARD_SOLID;
          end++;
        } else if (two && (next == 111 || next == 120)) {
          type = next == 111 ? T.FORWARD_CIRCLE : T.FORWARD_CROSS;
          end++;
        } else {
          type = T.MARKERLESS_SOLID;
        }
      }
    } else if (c == 46) {
      final next = charCodeAt(src, end);
      if (next == 46 && charCodeAt(src, end + 1) == 62) {
        type = T.DEPENDENCY_ARROW;
        end += 2;
      } else if (isDigit(next)) {
        type = T.NUMBER;
        while (isDigit(charCodeAt(src, end))) {
          end++;
        }
        while (isLetter(charCodeAt(src, end))) {
          end++;
        }
      } else {
        type = T.DOT;
      }
    } else if (c == 60) {
      if (charCodeAt(src, end) == 60) {
        types.add(T.STEREOTYPE_START);
        starts.add(i);
        ends.add(i + 2);
        lineStart = false;
        i += 2;
        if (i >= n) break;
        if (charCodeAt(src, i) == 62 && charCodeAt(src, i + 1) == 62) {
          type = T.STEREOTYPE_END;
          end = i + 2;
        } else {
          var close = i;
          var found = false;
          for (; close < n; close++) {
            final ch = charCodeAt(src, close);
            if (ch == 10 || ch == 13) break;
            if (ch == 62 && charCodeAt(src, close + 1) == 62) {
              found = true;
              break;
            }
          }
          if (found && sliceJs(src, i, close).trim().isNotEmpty) {
            types.add(T.STEREOTYPE_TEXT);
            starts.add(i);
            ends.add(close);
            type = T.STEREOTYPE_END;
            i = close;
            end = close + 2;
          } else {
            while (close < n &&
                charCodeAt(src, close) != 10 &&
                charCodeAt(src, close) != 13) {
              close++;
            }
            if (close == i) {
              while (close < n &&
                  (charCodeAt(src, close) == 10 ||
                      charCodeAt(src, close) == 13)) {
                close++;
              }
              throw _lexError(src, i, close - i);
            }
            type = T.UNCLOSED_STEREOTYPE_TEXT;
            end = close;
          }
        }
      } else if (charCodeAt(src, end) == 45 && charCodeAt(src, end + 1) == 45) {
        type = T.BACKWARD_SOLID;
        end += 2;
        while (charCodeAt(src, end) == 45) {
          end++;
        }
      } else {
        type = T.LABEL_PUNCTUATION;
      }
    } else if (c == 58) {
      if (charCodeAt(src, end) == 58 && charCodeAt(src, end + 1) == 58) {
        type = T.CLASS_SEPARATOR;
        end += 2;
      } else {
        type = T.COLON;
      }
    } else if (c == 64) {
      if (charCodeAt(src, end) == 123) {
        type = T.METADATA_START;
        end++;
      } else {
        type = T.AT;
      }
    } else if (c == 123) {
      type = T.LBRACE;
    } else if (c == 125) {
      type = T.RBRACE;
    } else if (c == 91) {
      type = T.LBRACKET;
    } else if (c == 93) {
      type = T.RBRACKET;
    } else if (c == 40) {
      type = T.LPAREN;
    } else if (c == 41) {
      type = T.RPAREN;
    } else if (c == 44) {
      type = T.COMMA;
    } else if (c == 35) {
      while (isHex(charCodeAt(src, end))) {
        end++;
      }
      type = end > i + 1 ? T.HASH_COLOR : T.CSS_PUNCTUATION;
    } else if (c == 92) {
      if (charCodeAt(src, end) == 44) {
        type = T.CSS_ESCAPED_COMMA;
        end++;
      } else {
        type = T.LABEL_PUNCTUATION;
      }
    } else if (c < 127 && c > 32) {
      type = (_class[c] & _punctuation) != 0
          ? T.CSS_PUNCTUATION
          : T.LABEL_PUNCTUATION;
    } else {
      type = T.LABEL_SYMBOL;
      while (end < n) {
        final ch = charCodeAt(src, end);
        if ((ch >= 32 && ch < 127) || ch == 9 || ch == 10 || ch == 13) break;
        end++;
      }
    }

    types.add(type);
    starts.add(i);
    ends.add(end);
    i = end;
    lineStart = fresh;
  }

  for (var k = 0; k < 3; k++) {
    types.add(T.EOF);
    starts.add(n);
    ends.add(n);
  }
  return Tokens(types: types, starts: starts, ends: ends);
}

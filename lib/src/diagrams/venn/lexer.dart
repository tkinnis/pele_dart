// Upstream: src/diagrams/venn/lexer.ts

import '../../util/chars.dart';
import '../../util/math_js.dart';

class T {
  static const int END = 0;
  static const int ERROR = 1;
  static const int EOF = 2;
  static const int NEWLINE = 3;
  static const int VENN = 4;
  static const int TITLE = 5;
  static const int SET = 6;
  static const int UNION = 7;
  static const int TEXT = 8;
  static const int INDENT_TEXT = 9;
  static const int STYLE = 10;
  static const int BRACKET_LABEL = 11;
  static const int NUMERIC = 12;
  static const int HEXCOLOR = 13;
  static const int RGBCOLOR = 14;
  static const int RGBACOLOR = 15;
  static const int IDENTIFIER = 16;
  static const int STRING = 17;
  static const int COMMA = 18;
  static const int COLON = 19;
}

const List<String> TOKEN_NAMES = <String>[
  r'$end',
  'INVALID',
  'EOF',
  'NEWLINE',
  'VENN',
  'TITLE',
  'SET',
  'UNION',
  'TEXT',
  'INDENT_TEXT',
  'STYLE',
  'BRACKET_LABEL',
  'NUMERIC',
  'HEXCOLOR',
  'RGBCOLOR',
  'RGBACOLOR',
  'IDENTIFIER',
  'STRING',
  'COMMA',
  'COLON',
];

// The part of the model the lexer talks to: an indented `text` line is a different token after a
// set or union than anywhere else, and the parser is what knows which came before.
abstract interface class IndentHost {
  bool getIndentMode();
  void setIndentMode(bool enabled);
}

const List<(String, int)> _keywords = <(String, int)>[
  ('venn-beta', T.VENN),
  ('set', T.SET),
  ('union', T.UNION),
  ('text', T.TEXT),
  ('style', T.STYLE),
];

// Reads tokens one at a time, as Mermaid's Jison lexer for venn diagrams does: every rule
// ignores case, the first rule that matches wins, and a keyword must end at a word boundary.
class VennLexer {
  // The text and position of the token `next` returned last.
  String text = '';
  int start = 0;
  int _at = 0;
  bool _lineStart = false;
  bool _ended = false;

  final String _src;
  final IndentHost _host;

  VennLexer(this._src, this._host);

  bool _word(int at, String word) {
    final src = _src;
    for (var k = 0; k < word.length; k++) {
      final c = charCodeAt(src, at + k);
      final w = word.codeUnitAt(k);
      if (c != w && (c + 32 != w || c < 65 || c > 90)) return false;
    }
    return true;
  }

  bool _keyword(int at, String word) {
    return _word(at, word) && !isWord(charCodeAt(_src, at + word.length));
  }

  // The end of `rgb(1, 2, 3)` or `rgba(1, 2, 3, 0.5)` whose parenthesis opens at `at`, or -1.
  int _color(int at, int parts) {
    final src = _src;
    var i = at + 1;
    for (var part = 0; part < parts; part++) {
      while (isSpace(charCodeAt(src, i))) {
        i++;
      }
      final from = i;
      while (isDigit(charCodeAt(src, i)) || charCodeAt(src, i) == 46) {
        i++;
      }
      if (i == from) return -1;
      while (isSpace(charCodeAt(src, i))) {
        i++;
      }
      if (charCodeAt(src, i) != (part == parts - 1 ? 41 : 44)) return -1;
      i++;
    }
    return i;
  }

  bool _afterLineFeed(int at) {
    var k = at - 1;
    while (charCodeAt(_src, k) == 32 || charCodeAt(_src, k) == 9) {
      k--;
    }
    return charCodeAt(_src, k) == 10;
  }

  int _lineEnd(int from) {
    if (from > _src.length) return _src.length;
    final end = _src.indexOf('\n', from);
    return end == -1 ? _src.length : end;
  }

  int next() {
    final src = _src;
    final n = src.length;
    for (;;) {
      var i = _at;
      start = i;
      text = '';
      if (i >= n) {
        if (_ended) return T.END;
        _ended = true;
        return T.EOF;
      }
      final c = charCodeAt(src, i);
      if (c == 37 &&
          charCodeAt(src, i + 1) == 37 &&
          charCodeAt(src, i + 2) != 123) {
        _at = _lineEnd(i + 2);
        continue;
      }
      if (_lineStart &&
          _word(i, 'title') &&
          _afterLineFeed(i) &&
          sliceJs(src, i + 5, _lineEnd(i + 5)).trim() == '') {
        // Skip a bare title like a comment, so it doesn't end indented text.
        var j = _lineEnd(i + 5);
        while (charCodeAt(src, j) == 10 || charCodeAt(src, j) == 13) {
          j++;
        }
        _at = j;
        continue;
      }
      if (_lineStart) {
        if (c == 32 || c == 9) {
          var j = i + 1;
          while (charCodeAt(src, j) == 32 || charCodeAt(src, j) == 9) {
            j++;
          }
          _at = j;
          if (_keyword(j, 'text') && _host.getIndentMode()) {
            // The word `text` itself is dropped; the indentation stands for it.
            _at = j + 4;
            _lineStart = false;
            text = src.substring(i, j);
            return T.INDENT_TEXT;
          }
          continue;
        }
        if (c != 10 && c != 13) {
          _host.setIndentMode(false);
          _lineStart = false;
        }
      }
      if (c == 10 || c == 13) {
        i++;
        while (charCodeAt(src, i) == 10 || charCodeAt(src, i) == 13) {
          i++;
        }
        _lineStart = true;
        return _token(T.NEWLINE, i);
      }
      if (c == 37 && charCodeAt(src, i + 1) == 37) {
        _at = _lineEnd(i);
        continue;
      }
      if (c == 32 || c == 9) {
        i++;
        while (charCodeAt(src, i) == 32 || charCodeAt(src, i) == 9) {
          i++;
        }
        _at = i;
        continue;
      }

      if (((c | 32) >= 97 && (c | 32) <= 122) || c == 95) {
        final sep = charCodeAt(src, i + 5);
        if (_word(i, 'title') && isSpace(sep) && sep != 10 && sep != 13) {
          var end = i + 6;
          while (end < n) {
            final ch = charCodeAt(src, end);
            if (ch == 35 || ch == 10 || ch == 59) break;
            end++;
          }
          if (end > i + 6) return _token(T.TITLE, end);
        }
        for (final (word, type) in _keywords) {
          // A hyphen continues a name, as in `set-theory`.
          if (_keyword(i, word) && charCodeAt(src, i + word.length) != 45) {
            return _token(type, i + word.length);
          }
        }
        if (_word(i, 'rgb')) {
          final alpha = (charCodeAt(src, i + 3) | 32) == 97;
          final open = i + (alpha ? 4 : 3);
          final end = charCodeAt(src, open) == 40
              ? _color(open, alpha ? 4 : 3)
              : -1;
          if (end != -1) {
            return _token(alpha ? T.RGBACOLOR : T.RGBCOLOR, end);
          }
        }
        i++;
        while (isWord(charCodeAt(src, i)) || charCodeAt(src, i) == 45) {
          i++;
        }
        return _token(T.IDENTIFIER, i);
      }
      if (c == 91) {
        if (charCodeAt(src, i + 1) == 34) {
          final quote = src.indexOf('"', i + 2);
          if (quote == -1 || charCodeAt(src, quote + 1) != 93) return T.ERROR;
          _at = quote + 2;
          text = src.substring(i + 2, quote);
          return T.BRACKET_LABEL;
        }
        var end = i + 1;
        while (end < n &&
            charCodeAt(src, end) != 93 &&
            charCodeAt(src, end) != 34) {
          end++;
        }
        if (end == i + 1 || charCodeAt(src, end) != 93) return T.ERROR;
        _at = end + 1;
        text = src.substring(i + 1, end).trim();
        return T.BRACKET_LABEL;
      }
      if (isDigit(c) || c == 46 || c == 43 || c == 45) {
        if (c == 43 || c == 45) i++;
        final from = i;
        while (isDigit(charCodeAt(src, i))) {
          i++;
        }
        if (i > from) {
          if (charCodeAt(src, i) == 46 && isDigit(charCodeAt(src, i + 1))) {
            i += 2;
            while (isDigit(charCodeAt(src, i))) {
              i++;
            }
          }
        } else if (charCodeAt(src, i) == 46 &&
            isDigit(charCodeAt(src, i + 1))) {
          i += 2;
          while (isDigit(charCodeAt(src, i))) {
            i++;
          }
        } else {
          return T.ERROR;
        }
        return _token(T.NUMERIC, i);
      }
      if (c == 35) {
        var end = i + 1;
        while (end < i + 9 && isHex(charCodeAt(src, end))) {
          end++;
        }
        return end >= i + 4 ? _token(T.HEXCOLOR, end) : T.ERROR;
      }
      if (c == 34) {
        final quote = src.indexOf('"', i + 1);
        return quote == -1 ? T.ERROR : _token(T.STRING, quote + 1);
      }
      if (c == 44) return _token(T.COMMA, i + 1);
      if (c == 58) return _token(T.COLON, i + 1);
      return T.ERROR;
    }
  }

  int _token(int type, int end) {
    text = _src.substring(_at, end);
    _at = end;
    return type;
  }
}

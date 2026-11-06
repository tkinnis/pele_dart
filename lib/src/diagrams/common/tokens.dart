// Upstream: src/diagrams/common/tokens.ts

import 'dart:typed_data';

import '../../errors.dart';

typedef Scanner = int Function(String src, int at, int previous);

class TokenType {
  final String name;
  // A literal String or a RegExp.
  final Object pattern;
  final bool hidden;
  final RegExp? opener;
  final String? first;
  final List<TokenType>? longer;
  final Scanner Function()? scanner;
  final Scanner? match;

  const TokenType({
    required this.name,
    required this.pattern,
    this.hidden = false,
    this.opener,
    this.first,
    this.longer,
    this.scanner,
    this.match,
  });
}

class Tokens {
  final List<int> kinds;
  final List<int> starts;
  final List<int> ends;
  final String src;

  const Tokens({
    required this.kinds,
    required this.starts,
    required this.ends,
    required this.src,
  });
}

class _Table {
  final List<List<int>> starting;
  final List<int> every;
  final List<List<int>?> longer;
  final List<Scanner?> fastMatchers;

  const _Table({
    required this.starting,
    required this.every,
    required this.longer,
    required this.fastMatchers,
  });
}

final Expando<_Table> _tables = Expando<_Table>();

bool _isRegexWs(int c) {
  if (c <= 0x20) {
    return c == 0x20 || (c >= 0x09 && c <= 0x0D);
  }
  return c == 0x85 ||
      c == 0xA0 ||
      c == 0x1680 ||
      (c >= 0x2000 && c <= 0x200A) ||
      c == 0x2028 ||
      c == 0x2029 ||
      c == 0x202F ||
      c == 0x205F ||
      c == 0x3000 ||
      c == 0xFEFF;
}

bool _isWordCode(int c) =>
    (c >= 0x61 && c <= 0x7A) ||
    (c >= 0x41 && c <= 0x5A) ||
    (c >= 0x30 && c <= 0x39) ||
    c == 0x5F;

bool _isAlphaOrUnderscore(int c) =>
    (c >= 0x61 && c <= 0x7A) || (c >= 0x41 && c <= 0x5A) || c == 0x5F;

int _scanTabSpace(String src, int p, int _) {
  final n = src.length;
  var q = p;
  while (q < n) {
    final c = src.codeUnitAt(q);
    if (c != 32 && c != 9) break;
    q++;
  }
  return q > p ? q : -1;
}

int _scanTabSpaceCrLf(String src, int p, int _) {
  final n = src.length;
  var q = p;
  while (q < n) {
    final c = src.codeUnitAt(q);
    if (c != 32 && c != 9 && c != 10 && c != 13) break;
    q++;
  }
  return q > p ? q : -1;
}

int _scanRegexWs(String src, int p, int _) {
  final n = src.length;
  var q = p;
  while (q < n && _isRegexWs(src.codeUnitAt(q))) {
    q++;
  }
  return q > p ? q : -1;
}

int _scanNewline(String src, int p, int _) {
  final c = src.codeUnitAt(p);
  if (c == 10) return p + 1;
  if (c == 13 && p + 1 < src.length && src.codeUnitAt(p + 1) == 10) {
    return p + 2;
  }
  return -1;
}

int _scanPercentCommentNoCr(String src, int p, int _) {
  final n = src.length;
  if (p + 1 >= n || src.codeUnitAt(p) != 37 || src.codeUnitAt(p + 1) != 37) {
    return -1;
  }
  var q = p + 2;
  while (q < n && src.codeUnitAt(q) != 10) {
    q++;
  }
  return q;
}

int _scanSingleLineComment(String src, int p, int _) {
  final n = src.length;
  var q = p;
  while (q < n) {
    final c = src.codeUnitAt(q);
    if (c != 32 && c != 9) break;
    q++;
  }
  if (q + 1 >= n || src.codeUnitAt(q) != 37 || src.codeUnitAt(q + 1) != 37) {
    return -1;
  }
  q += 2;
  while (q < n) {
    final c = src.codeUnitAt(q);
    if (c == 10 || c == 13) break;
    q++;
  }
  return q;
}

int _scanEscapedQuotedString(String src, int p, int _) {
  final quote = src.codeUnitAt(p);
  if (quote != 34 && quote != 39) return -1;
  final n = src.length;
  var q = p + 1;
  while (q < n) {
    final c = src.codeUnitAt(q);
    if (c == quote) return q + 1;
    if (c == 92) {
      if (q + 1 >= n) return -1;
      final ec = src.codeUnitAt(q + 1);
      if (ec == 10 || ec == 13 || ec == 0x2028 || ec == 0x2029) return -1;
      q += 2;
    } else {
      q++;
    }
  }
  return -1;
}

int _scanPlainSingleOrDoubleQuoted(String src, int p, int _) {
  final quote = src.codeUnitAt(p);
  if (quote != 34 && quote != 39) return -1;
  final close = src.indexOf(quote == 34 ? '"' : "'", p + 1);
  return close != -1 ? close + 1 : -1;
}

int _scanPlainDoubleQuoted(String src, int p, int _) {
  if (src.codeUnitAt(p) != 34) return -1;
  final close = src.indexOf('"', p + 1);
  return close != -1 ? close + 1 : -1;
}

int _scanIntNoDot(String src, int p, int _) {
  final c0 = src.codeUnitAt(p);
  if (c0 == 48) return p + 1;
  if (c0 < 49 || c0 > 57) return -1;
  final n = src.length;
  var q = p + 1;
  while (q < n) {
    final c = src.codeUnitAt(q);
    if (c < 48 || c > 57) break;
    q++;
  }
  if (q < n && src.codeUnitAt(q) == 46) return -1;
  return q;
}

int _scanDigits1To3(String src, int p, int _) {
  final c0 = src.codeUnitAt(p);
  if (c0 < 48 || c0 > 57) return -1;
  final n = src.length;
  var q = p + 1;
  if (q < n) {
    final c1 = src.codeUnitAt(q);
    if (c1 >= 48 && c1 <= 57) {
      q++;
      if (q < n) {
        final c2 = src.codeUnitAt(q);
        if (c2 >= 48 && c2 <= 57) q++;
      }
    }
  }
  return q;
}

int _scanTreemapNumber(String src, int p, int _) {
  final n = src.length;
  var q = p;
  while (q < n) {
    final c = src.codeUnitAt(q);
    if ((c >= 48 && c <= 57) || c == 95 || c == 46 || c == 44) {
      q++;
    } else {
      break;
    }
  }
  return q > p ? q : -1;
}

int _scanIdent(String src, int p, int _) {
  if (!_isAlphaOrUnderscore(src.codeUnitAt(p))) return -1;
  final n = src.length;
  var q = p + 1;
  while (q < n && _isWordCode(src.codeUnitAt(q))) {
    q++;
  }
  return q;
}

int _scanIdentWithHyphen(String src, int p, int _) {
  if (!_isAlphaOrUnderscore(src.codeUnitAt(p))) return -1;
  final n = src.length;
  var q = p + 1;
  while (q < n) {
    final c = src.codeUnitAt(q);
    if (_isWordCode(c) || c == 45) {
      q++;
    } else {
      break;
    }
  }
  return q;
}

int _scanArchUniId(String src, int p, int _) {
  if (!_isWordCode(src.codeUnitAt(p))) return -1;
  final n = src.length;
  var q = p + 1;
  while (q < n) {
    final c = src.codeUnitAt(q);
    if (_isWordCode(c) || c == 45) {
      q++;
    } else {
      break;
    }
  }
  while (q > p + 1 && src.codeUnitAt(q - 1) == 45) {
    q--;
  }
  return q;
}

int _scanGitId(String src, int p, int _) {
  if (!_isWordCode(src.codeUnitAt(p))) return -1;
  final n = src.length;
  var q = p + 1;
  while (q < n) {
    final c = src.codeUnitAt(q);
    if (_isWordCode(c) || c == 45 || c == 46 || c == 47) {
      q++;
    } else {
      break;
    }
  }
  while (q > p + 1) {
    final prev = src.codeUnitAt(q - 1);
    if (prev == 46 || prev == 47) {
      q--;
    } else {
      break;
    }
  }
  return q;
}

int _scanBracketNonEmpty(String src, int p, int _) {
  if (src.codeUnitAt(p) != 91) return -1;
  final close = src.indexOf(']', p + 1);
  return close > p + 1 ? close + 1 : -1;
}

int _scanArchIcon(String src, int p, int _) {
  if (src.codeUnitAt(p) != 40) return -1;
  final n = src.length;
  var q = p + 1;
  while (q < n) {
    final c = src.codeUnitAt(q);
    if (_isWordCode(c) || c == 45 || c == 58) {
      q++;
    } else {
      break;
    }
  }
  if (q > p + 1 && q < n && src.codeUnitAt(q) == 41) {
    return q + 1;
  }
  return -1;
}

int _scanDescAnnotation(String src, int p, int _) {
  final n = src.length;
  var q = p;
  while (q < n) {
    final c = src.codeUnitAt(q);
    if (c != 32 && c != 9) break;
    q++;
  }
  if (q == p ||
      q + 1 >= n ||
      src.codeUnitAt(q) != 35 ||
      src.codeUnitAt(q + 1) != 35) {
    return -1;
  }
  q += 2;
  while (q < n) {
    final c = src.codeUnitAt(q);
    if (c == 10 || c == 13) break;
    q++;
  }
  return q;
}

int _scanClassAnnotation(String src, int p, int _) {
  final n = src.length;
  var q = p;
  while (q < n) {
    final c = src.codeUnitAt(q);
    if (c != 32 && c != 9) break;
    q++;
  }
  if (q == p || !src.startsWith(':::', q)) return -1;
  q += 3;
  while (q < n) {
    final c = src.codeUnitAt(q);
    if (c != 32 && c != 9) break;
    q++;
  }
  if (q >= n || !_isAlphaOrUnderscore(src.codeUnitAt(q))) return -1;
  q++;
  while (q < n) {
    final c = src.codeUnitAt(q);
    if (_isWordCode(c) || c == 45) {
      q++;
    } else {
      break;
    }
  }
  return q;
}

int _scanIconAnnotation(String src, int p, int _) {
  final n = src.length;
  var q = p;
  while (q < n) {
    final c = src.codeUnitAt(q);
    if (c != 32 && c != 9) break;
    q++;
  }
  if (q == p || !src.startsWith('icon(', q)) return -1;
  q += 5;
  while (q < n) {
    final c = src.codeUnitAt(q);
    if (_isWordCode(c) || c == 45) {
      q++;
    } else {
      break;
    }
  }
  if (q < n && src.codeUnitAt(q) == 58) {
    q++;
    final start = q;
    while (q < n) {
      final c = src.codeUnitAt(q);
      if (_isWordCode(c) || c == 45) {
        q++;
      } else {
        break;
      }
    }
    if (q == start) return -1;
  }
  return (q < n && src.codeUnitAt(q) == 41) ? q + 1 : -1;
}

int _scanAccTitle(String src, int p, int _) {
  final n = src.length;
  var q = p;
  while (q < n) {
    final c = src.codeUnitAt(q);
    if (c != 32 && c != 9) break;
    q++;
  }
  if (!src.startsWith('accTitle', q)) return -1;
  q += 8;
  while (q < n) {
    final c = src.codeUnitAt(q);
    if (c != 32 && c != 9) break;
    q++;
  }
  if (q >= n || src.codeUnitAt(q) != 58) return -1;
  q++;
  while (q < n) {
    final c = src.codeUnitAt(q);
    if (c == 10 || c == 13) break;
    if (c == 37 && q + 1 < n && src.codeUnitAt(q + 1) == 37) break;
    q++;
  }
  return q;
}

Scanner? _compileFastMatcher(TokenType type) {
  if (type.match != null) return type.match;
  if (type.scanner != null || type.opener != null) return null;
  final pattern = type.pattern;
  if (pattern is String) {
    if (pattern.length == 1) {
      final c0 = pattern.codeUnitAt(0);
      return (src, p, _) => src.codeUnitAt(p) == c0 ? p + 1 : -1;
    }
    final len = pattern.length;
    return (src, p, _) => src.startsWith(pattern, p) ? p + len : -1;
  }
  final re = pattern as RegExp;
  if (!re.isCaseSensitive) return null;
  if (re.pattern.startsWith('[\t ]*title(?:')) {
    return (src, p, _) {
      final n = src.length;
      var q = p;
      while (q < n) {
        final c = src.codeUnitAt(q);
        if (c != 32 && c != 9) break;
        q++;
      }
      if (!src.startsWith('title', q)) return -1;
      return re.matchAsPrefix(src, q)?.end ?? -1;
    };
  }
  switch (re.pattern) {
    case r'[\t ]+':
    case r'[ \t]+':
    case r'[ \t]{1,}':
      return _scanTabSpace;
    case r'[\t \r\n]+':
      return _scanTabSpaceCrLf;
    case r'\s+':
      return _scanRegexWs;
    case r'\r?\n':
      return _scanNewline;
    case r'%%[^\n]*':
      return _scanPercentCommentNoCr;
    case r'[\t ]*%%[^\n\r]*':
      return _scanSingleLineComment;
    case r'[\t ]*accTitle[\t ]*:(?:[^\n\r]*?(?=%%)|[^\n\r]*)':
      return _scanAccTitle;
    case r'[ \t]+##[^\n\r]*':
      return _scanDescAnnotation;
    case r'[ \t]+:::[ \t]*[A-Za-z_][\w-]*':
      return _scanClassAnnotation;
    case r'[ \t]+icon\([\w-]*(?::[\w-]+)?\)':
      return _scanIconAnnotation;
    case r':::':
      return (src, p, _) => src.startsWith(':::', p) ? p + 3 : -1;
    case r':':
      return (src, p, _) => src.codeUnitAt(p) == 58 ? p + 1 : -1;
    case r';':
      return (src, p, _) => src.codeUnitAt(p) == 59 ? p + 1 : -1;
    case r',':
      return (src, p, _) => src.codeUnitAt(p) == 44 ? p + 1 : -1;
    case r'\{group\}':
      return (src, p, _) => src.startsWith('{group}', p) ? p + 7 : -1;
    case r'treemap-beta|treemap':
      return (src, p, _) => src.startsWith('treemap', p)
          ? (src.startsWith('treemap-beta', p) ? p + 12 : p + 7)
          : -1;
    case r'L|R|T|B':
      return (src, p, _) {
        final c = src.codeUnitAt(p);
        return (c == 76 || c == 82 || c == 84 || c == 66) ? p + 1 : -1;
      };
    case r'<|>':
      return (src, p, _) {
        final c = src.codeUnitAt(p);
        return (c == 60 || c == 62) ? p + 1 : -1;
      };
    case r'0|[1-9][0-9]*(?!\.)':
      return _scanIntNoDot;
    case r'\d{1,3}':
      return _scanDigits1To3;
    case r'[0-9_.,]+':
      return _scanTreemapNumber;
    case r'"[^"]*"':
      return _scanPlainDoubleQuoted;
    case r'"[^"]*"|'
        "'"
        r"[^']*'":
      return _scanPlainSingleOrDoubleQuoted;
    case r'\[[^\]]+\]':
      return _scanBracketNonEmpty;
    case r'\([\w-:]+\)':
      return _scanArchIcon;
    case r'[a-zA-Z_][a-zA-Z0-9_]*':
    case r'[_a-zA-Z][\w_]*':
      return _scanIdent;
    case r'[A-Z_a-z][\w-]*':
      return _scanIdentWithHyphen;
    case r'[\w]([-\w]*\w)?':
      return _scanArchUniId;
    case r'\w([-\./\w]*[-\w])?':
      return _scanGitId;
    default:
      return null;
  }
}

bool _hasTopLevelAlternation(String pat) {
  var inBracket = false;
  var parenDepth = 0;
  for (var i = 0; i < pat.length; i++) {
    final c = pat.codeUnitAt(i);
    if (c == 92) {
      i++;
      continue;
    }
    if (inBracket) {
      if (c == 93) inBracket = false;
      continue;
    }
    if (c == 91) {
      inBracket = true;
    } else if (c == 40) {
      parenDepth++;
    } else if (c == 41) {
      if (parenDepth > 0) parenDepth--;
    } else if (c == 124 && parenDepth == 0) {
      return true;
    }
  }
  return false;
}

String? _inferFirstChars(RegExp re) {
  final pat = re.pattern;
  if (pat.isEmpty) return null;
  if (re.isCaseSensitive) {
    switch (pat) {
      case r'[\t ]+':
      case r'[ \t]+':
      case r'[ \t]{1,}':
      case r'[ \t]+##[^\n\r]*':
      case r'[ \t]+:::[ \t]*[A-Za-z_][\w-]*':
      case r'[ \t]+icon\([\w-]*(?::[\w-]+)?\)':
        return '\t ';
      case r'\{(.*)\}|"(.*)"|'
          "'"
          r"'(.*)'":
        return '{\'"';
      case r'[\t \r\n]+':
        return '\t \r\n';
      case r'\s+':
        return '\t\n\x0B\x0C\r ';
      case r'\r?\n':
        return '\r\n';
      case r'%%[^\n]*':
        return '%';
      case r'[\t ]*%%[^\n\r]*':
        return '\t %';
      case r':::':
      case r':':
        return ':';
      case r';':
        return ';';
      case r',':
        return ',';
      case r'\{group\}':
        return '{';
      case r'treemap-beta|treemap':
        return 't';
      case r'L|R|T|B':
        return 'LRTB';
      case r'<|>':
        return '<>';
      case r'0|[1-9][0-9]*(?!\.)':
      case r'\d{1,3}':
        return '0123456789';
      case r'[0-9_.,]+':
        return '0123456789_.,';
      case r'"[^"]*"':
        return '"';
      case r'"[^"]*"|'
          "'"
          r"[^']*'":
        return '"\'';
      case r'\[[^\]]+\]':
        return '[';
      case r'\([\w-:]+\)':
      case r'\([^\(\)]+\)':
        return '(';
      case r'[a-zA-Z_][a-zA-Z0-9_]*':
      case r'[_a-zA-Z][\w_]*':
      case r'[A-Z_a-z][\w-]*':
        return '_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
      case r'[\w]([-\w]*\w)?':
      case r'\w([-\./\w]*[-\w])?':
        return '0123456789_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
    }
  }
  if (_hasTopLevelAlternation(pat)) return null;
  final c0 = pat.codeUnitAt(0);
  // Leading positive character class `[...]`
  if (c0 == 91 && pat.length > 2 && pat.codeUnitAt(1) != 94) {
    var close = -1;
    for (var i = 1; i < pat.length; i++) {
      final c = pat.codeUnitAt(i);
      if (c == 92) {
        i++;
      } else if (c == 93 && i > 1) {
        close = i;
        break;
      }
    }
    if (close != -1) {
      final next = close + 1 < pat.length ? pat.codeUnitAt(close + 1) : -1;
      if (next != 42 && next != 63 && next != 123) {
        final classRe = RegExp(
          '^${pat.substring(0, close + 1)}',
          caseSensitive: re.isCaseSensitive,
        );
        final buf = StringBuffer();
        for (var c = 0; c < 128; c++) {
          final ch = String.fromCharCode(c);
          if (classRe.hasMatch(ch)) buf.write(ch);
        }
        return buf.toString();
      }
    }
    return null;
  }
  // Leading escaped atom `\d`, `\w`, or escaped punctuation
  if (c0 == 92 && pat.length >= 2) {
    final next = pat.length > 2 ? pat.codeUnitAt(2) : -1;
    if (next == 42 || next == 63 || next == 123) return null;
    final esc = pat[1];
    switch (esc) {
      case 'd':
        return '0123456789';
      case 'w':
        return '0123456789_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
      case '[':
      case ']':
      case '(':
      case ')':
      case '{':
      case '}':
      case '+':
      case '-':
      case '.':
      case '/':
      case '*':
      case '?':
        return esc;
      default:
        return null;
    }
  }
  // Plain literal ASCII first char
  if (c0 < 128 && !r'\^$.|?*+()[{'.contains(pat[0])) {
    final next = pat.length > 1 ? pat.codeUnitAt(1) : -1;
    if (next != 42 && next != 63 && next != 123) {
      final ch = pat[0];
      return re.isCaseSensitive ? ch : '${ch.toLowerCase()}${ch.toUpperCase()}';
    }
  }
  return null;
}

_Table _prepare(List<TokenType> types) {
  final every = List<int>.generate(types.length, (k) => k);
  final fastMatchers = List<Scanner?>.generate(
    types.length,
    (k) => _compileFastMatcher(types[k]),
  );
  final effectiveFirst = List<String?>.generate(types.length, (k) {
    final type = types[k];
    if (type.first != null) return type.first;
    final pat = type.pattern;
    if (pat is RegExp) return _inferFirstChars(pat);
    return null;
  });
  final starting = <List<int>>[];
  for (var c = 0; c < 128; c++) {
    final ch = String.fromCharCode(c);
    starting.add(
      every.where((k) {
        final pattern = types[k].pattern;
        final first = effectiveFirst[k];
        if (pattern is String) {
          return pattern.isNotEmpty && pattern[0] == ch;
        }
        return first == null || first.contains(ch);
      }).toList(),
    );
  }
  final table = _Table(
    starting: starting,
    every: every,
    longer: types
        .map((type) => type.longer?.map((alt) => types.indexOf(alt)).toList())
        .toList(),
    fastMatchers: fastMatchers,
  );
  _tables[types] = table;
  return table;
}

Tokens tokenize(String src, List<TokenType> types, String diagram) {
  final kinds = <int>[];
  final starts = <int>[];
  final ends = <int>[];
  final dead = Uint8List(types.length);
  final table = _tables[types] ?? _prepare(types);
  final starting = table.starting;
  final every = table.every;
  final longer = table.longer;
  final fastMatchers = table.fastMatchers;
  final scanners = List<Scanner?>.filled(types.length, null);
  final n = src.length;

  int match(int k, int p) {
    if (dead[k] != 0) return -1;
    final prevKind = kinds.isNotEmpty ? kinds.last : -1;
    final fast = fastMatchers[k];
    if (fast != null) return fast(src, p, prevKind);
    final type = types[k];
    if (type.scanner != null) {
      final sc = scanners[k] ??= type.scanner!();
      return sc(src, p, prevKind);
    }
    final pattern = type.pattern;
    if (pattern is String) {
      return src.startsWith(pattern, p) ? p + pattern.length : -1;
    }
    if (type.first == '\t %') {
      var q = p;
      while (q < n) {
        final c = src.codeUnitAt(q);
        if (c != 32 && c != 9) break;
        q++;
      }
      if (!src.startsWith('%%{', q)) return -1;
    } else if (type.first == '\t a') {
      var q = p;
      while (q < n) {
        final c = src.codeUnitAt(q);
        if (c != 32 && c != 9) break;
        q++;
      }
      if (!src.startsWith('accDescr', q)) return -1;
    }
    final re = pattern as RegExp;
    final m = re.matchAsPrefix(src, p);
    if (m != null) return m.end;
    if (type.opener != null) {
      if (type.opener!.matchAsPrefix(src, p) != null) {
        dead[k] = 1;
      }
    }
    return -1;
  }

  var p = 0;
  scan:
  while (p < n) {
    final c = src.codeUnitAt(p);
    for (final k in c < 128 ? starting[c] : every) {
      var end = match(k, p);
      if (end <= p) continue;
      var kind = k;
      final alts = longer[k];
      if (alts != null) {
        for (final alt in alts) {
          final altEnd = match(alt, p);
          if (altEnd > end) {
            kind = alt;
            end = altEnd;
            break;
          }
        }
      }
      if (!types[kind].hidden) {
        kinds.add(kind);
        starts.add(p);
        ends.add(end);
      }
      p = end;
      continue scan;
    }
    throw syntaxError(diagram, src, p, '', true);
  }
  kinds.add(-1);
  starts.add(n);
  ends.add(n);
  return Tokens(kinds: kinds, starts: starts, ends: ends, src: src);
}

final RegExp _reAccDescrBody = RegExp(
  r'accDescr(?:[\t ]*:([^\n\r]*?(?=%%)|[^\n\r]*)|\s*\{([^}]*)\})',
);

final TokenType ACC_DESCR = TokenType(
  name: 'ACC_DESCR',
  pattern: RegExp(
    r'[\t ]*accDescr(?:[\t ]*:([^\n\r]*?(?=%%)|[^\n\r]*)|\s*\{([^}]*)\})',
  ),
  first: '\t a',
  match: (src, p, _) {
    final n = src.length;
    var q = p;
    while (q < n) {
      final c = src.codeUnitAt(q);
      if (c != 32 && c != 9) break;
      q++;
    }
    if (!src.startsWith('accDescr', q)) return -1;
    return _reAccDescrBody.matchAsPrefix(src, q)?.end ?? -1;
  },
);

final TokenType ACC_TITLE = TokenType(
  name: 'ACC_TITLE',
  pattern: RegExp(r'[\t ]*accTitle[\t ]*:(?:[^\n\r]*?(?=%%)|[^\n\r]*)'),
  first: '\t a',
  match: (src, p, _) {
    final n = src.length;
    var q = p;
    while (q < n) {
      final c = src.codeUnitAt(q);
      if (c != 32 && c != 9) break;
      q++;
    }
    if (!src.startsWith('accTitle', q)) return -1;
    q += 8;
    while (q < n) {
      final c = src.codeUnitAt(q);
      if (c != 32 && c != 9) break;
      q++;
    }
    if (q >= n || src.codeUnitAt(q) != 58) return -1;
    q++;
    while (q < n) {
      final c = src.codeUnitAt(q);
      if (c == 10 || c == 13) break;
      if (c == 37 && q + 1 < n && src.codeUnitAt(q + 1) == 37) break;
      q++;
    }
    return q;
  },
);

final TokenType TITLE = TokenType(
  name: 'TITLE',
  pattern: RegExp(r'[\t ]*title(?:[\t ][^\n\r]*?(?=%%)|[\t ][^\n\r]*|)'),
  first: '\t t',
  match: (src, p, _) {
    final n = src.length;
    var q = p;
    while (q < n) {
      final c = src.codeUnitAt(q);
      if (c != 32 && c != 9) break;
      q++;
    }
    if (!src.startsWith('title', q)) return -1;
    q += 5;
    if (q < n) {
      final sep = src.codeUnitAt(q);
      if (sep == 32 || sep == 9) {
        q++;
        while (q < n) {
          final c = src.codeUnitAt(q);
          if (c == 10 || c == 13) break;
          if (c == 37 && q + 1 < n && src.codeUnitAt(q + 1) == 37) break;
          q++;
        }
      }
    }
    return q;
  },
);

TokenType titleBefore(String rest) {
  final re = RegExp('title(?:[\t ][^\n\r]*?(?=%%)|[\t ][^\n\r]*|(?!$rest))');
  return TokenType(
    name: TITLE.name,
    pattern: RegExp(
      '[\t ]*title(?:[\t ][^\n\r]*?(?=%%)|[\t ][^\n\r]*|(?!$rest))',
    ),
    first: TITLE.first,
    match: (src, p, _) {
      final n = src.length;
      var q = p;
      while (q < n) {
        final c = src.codeUnitAt(q);
        if (c != 32 && c != 9) break;
        q++;
      }
      if (!src.startsWith('title', q)) return -1;
      return re.matchAsPrefix(src, q)?.end ?? -1;
    },
  );
}

final TokenType STRING = TokenType(
  name: 'STRING',
  pattern: RegExp(
    r'"([^"\\]|\\.)*"|'
    "'"
    r"([^'\\]|\\.)*'",
  ),
  first: '"\'',
  match: _scanEscapedQuotedString,
);

final TokenType NEWLINE = TokenType(
  name: 'NEWLINE',
  pattern: RegExp(r'\r?\n'),
  first: '\r\n',
  match: _scanNewline,
);

final TokenType WHITESPACE = TokenType(
  name: 'WHITESPACE',
  pattern: RegExp(r'[\t ]+'),
  hidden: true,
  first: '\t ',
  match: _scanTabSpace,
);

final TokenType YAML = TokenType(
  name: 'YAML',
  pattern: RegExp(r'---[\t ]*\r?\n(?:[\S\s]*?\r?\n)?---(?:\r?\n|(?!\S))'),
  hidden: true,
  opener: RegExp(r'---[\t ]*\r?\n'),
  first: '-',
);

final TokenType DIRECTIVE = TokenType(
  name: 'DIRECTIVE',
  pattern: RegExp(r'[\t ]*%%\{[\S\s]*?\}%%(?:\r?\n|(?!\S))'),
  hidden: true,
  opener: RegExp(r'[\t ]*%%\{'),
  first: '\t %',
);

final TokenType SINGLE_LINE_COMMENT = TokenType(
  name: 'SINGLE_LINE_COMMENT',
  pattern: RegExp(r'[\t ]*%%[^\n\r]*'),
  first: '\t %',
  hidden: true,
  match: _scanSingleLineComment,
);

TokenType keyword(String word) {
  final escaped = word.replaceAllMapped(
    RegExp(r'[.*+?^${}()|[\]\\]'),
    (m) => '\\${m.group(0)!}',
  );
  final len = word.length;
  return TokenType(
    name: word,
    pattern: RegExp('$escaped(?:(?=%%)|(?!\\S))'),
    first: word[0],
    match: (src, p, _) {
      if (!src.startsWith(word, p)) return -1;
      final end = p + len;
      if (end >= src.length) return end;
      final next = src.codeUnitAt(end);
      if (_isRegexWs(next)) return end;
      if (next == 37 && end + 1 < src.length && src.codeUnitAt(end + 1) == 37) {
        return end;
      }
      return -1;
    },
  );
}

final RegExp _reAccDescr = RegExp(
  r'accDescr(?:[\t ]*:([^\n\r]*)|\s*\{([^}]*)\})',
);
final RegExp _reAccTitle = RegExp(r'accTitle[\t ]*:([^\n\r]*)');
final RegExp _reTitle = RegExp(r'title([\t ][^\n\r]*|)');
final RegExp _reMultiSpace = RegExp(r'[\t ]{2,}', multiLine: true);
final RegExp _reLeadSpace = RegExp(r'^\s*', multiLine: true);
final RegExp _reTrailSpace = RegExp(r'\s+$', multiLine: true);
final RegExp _reMultiNewline = RegExp(r'[\n\r]{2,}', multiLine: true);

String _single(String text) {
  return text.trim().replaceAll(_reMultiSpace, ' ');
}

String titleValue(String text) {
  return _single(_reTitle.firstMatch(text)!.group(1)!);
}

String accTitleValue(String text) {
  return _single(_reAccTitle.firstMatch(text)!.group(1)!);
}

String accDescrValue(String text) {
  final m = _reAccDescr.firstMatch(text)!;
  if (m.group(1) != null) return _single(m.group(1)!);
  return m
      .group(2)!
      .replaceAll(_reLeadSpace, '')
      .replaceAll(_reTrailSpace, '')
      .replaceAll(_reMultiSpace, ' ')
      .replaceAll(_reMultiNewline, '\n');
}

const Map<String, String> _escapes = <String, String>{
  'b': '\b',
  'f': '\f',
  'n': '\n',
  'r': '\r',
  't': '\t',
  'v': '\v',
  '0': '\x00',
};

String stringValue(String text) {
  if (!text.contains(r'\')) return text.substring(1, text.length - 1);
  final out = StringBuffer();
  for (var i = 1; i < text.length - 1; i++) {
    final c = text[i];
    if (c == r'\') {
      final next = text[++i];
      out.write(_escapes[next] ?? next);
    } else {
      out.write(c);
    }
  }
  return out.toString();
}

class Reader {
  int i = 0;
  final List<int> kinds;
  final Tokens tokens;
  final List<TokenType> types;
  final String diagram;

  Reader(this.tokens, this.types, this.diagram) : kinds = tokens.kinds;

  int get kind => kinds[i];

  String text([int? index]) {
    final idx = index ?? i;
    return tokens.src.substring(tokens.starts[idx], tokens.ends[idx]);
  }

  String take() {
    return text(i++);
  }

  bool accept(int kind) {
    if (kinds[i] != kind) return false;
    i++;
    return true;
  }

  String expect(int kind) {
    if (kinds[i] != kind) fail("token of type '${types[kind].name}'");
    return take();
  }

  Never fail(String expected) {
    final found = kind == -1 ? 'end of input' : '`${text()}`';
    final src = tokens.src;
    final starts = tokens.starts;
    final ends = tokens.ends;
    var at = starts[i];
    if (kind == -1) {
      var k = i;
      while (k > 0 && src.substring(starts[k - 1], ends[k - 1]).trim() == '') {
        k--;
      }
      if (k > 0) at = ends[k - 1];
    }
    throw syntaxError(
      diagram,
      src,
      at,
      'Expecting $expected but found $found.',
    );
  }
}

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

  const _Table({
    required this.starting,
    required this.every,
    required this.longer,
  });
}

final Expando<_Table> _tables = Expando<_Table>();

_Table _prepare(List<TokenType> types) {
  final every = List<int>.generate(types.length, (k) => k);
  final starting = <List<int>>[];
  for (var c = 0; c < 128; c++) {
    final ch = String.fromCharCode(c);
    starting.add(
      every.where((k) {
        final pattern = types[k].pattern;
        final first = types[k].first;
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
  final scanners = List<Scanner?>.filled(types.length, null);
  final n = src.length;

  int match(int k, int p) {
    if (dead[k] != 0) return -1;
    final type = types[k];
    final prevKind = kinds.isNotEmpty ? kinds.last : -1;
    if (type.match != null) return type.match!(src, p, prevKind);
    if (type.scanner != null) {
      final sc = scanners[k] ??= type.scanner!();
      return sc(src, p, prevKind);
    }
    final pattern = type.pattern;
    if (pattern is String) {
      return src.startsWith(pattern, p) ? p + pattern.length : -1;
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

final TokenType ACC_DESCR = TokenType(
  name: 'ACC_DESCR',
  pattern: RegExp(
    r'[\t ]*accDescr(?:[\t ]*:([^\n\r]*?(?=%%)|[^\n\r]*)|\s*\{([^}]*)\})',
  ),
  first: '\t a',
);

final TokenType ACC_TITLE = TokenType(
  name: 'ACC_TITLE',
  pattern: RegExp(r'[\t ]*accTitle[\t ]*:(?:[^\n\r]*?(?=%%)|[^\n\r]*)'),
  first: '\t a',
);

final TokenType TITLE = TokenType(
  name: 'TITLE',
  pattern: RegExp(r'[\t ]*title(?:[\t ][^\n\r]*?(?=%%)|[\t ][^\n\r]*|)'),
  first: '\t t',
);

TokenType titleBefore(String rest) {
  return TokenType(
    name: TITLE.name,
    pattern: RegExp(
      '[\t ]*title(?:[\t ][^\n\r]*?(?=%%)|[\t ][^\n\r]*|(?!$rest))',
    ),
    first: TITLE.first,
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
);

final TokenType NEWLINE = TokenType(
  name: 'NEWLINE',
  pattern: RegExp(r'\r?\n'),
  first: '\r\n',
);

final TokenType WHITESPACE = TokenType(
  name: 'WHITESPACE',
  pattern: RegExp(r'[\t ]+'),
  hidden: true,
  first: '\t ',
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
);

TokenType keyword(String word) {
  final escaped = word.replaceAllMapped(
    RegExp(r'[.*+?^${}()|[\]\\]'),
    (m) => '\\${m.group(0)!}',
  );
  return TokenType(
    name: word,
    pattern: RegExp('$escaped(?:(?=%%)|(?!\\S))'),
    first: word[0],
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

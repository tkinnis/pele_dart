// Upstream: src/diagrams/radar/parser.ts

import '../../util/math_js.dart';
import '../common/tokens.dart';

class _T {
  static const int radarColon = 0;
  static const int radar = 1;
  static const int showLegend = 2;
  static const int graticule = 3;
  static const int curve = 4;
  static const int ticks = 5;
  static const int axis = 6;
  static const int max = 7;
  static const int min = 8;
  static const int colon = 9;
  static const int comma = 10;
  static const int open = 11;
  static const int close = 12;
  static const int openBrace = 13;
  static const int closeBrace = 14;
  static const int graticuleValue = 15;
  static const int boolean = 16;
  static const int accDescr = 17;
  static const int accTitle = 18;
  static const int title = 19;
  static const int number = 20;
  static const int string = 21;
  static const int id = 22;
  static const int newline = 23;
}

int _runFrom = 0;
int _runEnd = 0;

int _digits(String src, int at) {
  var end = at;
  for (
    var c = charCodeAt(src, end);
    c >= 48 && c <= 57;
    c = charCodeAt(src, end)
  ) {
    end++;
  }
  return end;
}

// The NUMBER pattern without its backtracking. As a regular expression it reads to the end of a
// run of digits from every position in the run, which is quadratic for a long run of zeros.
int _matchNumber(String src, int at, [int _ = -1]) {
  if (at < _runFrom || at >= _runEnd) {
    _runFrom = at;
    _runEnd = _digits(src, at);
  }
  final whole = _runEnd;
  if (whole == at) return -1;
  final dot = charCodeAt(src, whole) == 46;
  if (dot) {
    final fraction = _digits(src, whole + 1);
    final length = fraction - whole - 1;
    if (length > 0 && charCodeAt(src, fraction) != 46) return fraction;
    if (length > 1) return fraction - 1;
  }
  if (charCodeAt(src, at) == 48) return at + 1;
  if (!dot) return whole;
  return whole - 1 > at ? whole - 1 : -1;
}

final RegExp _reAccDescr = ACC_DESCR.pattern as RegExp;
final RegExp _reBlock = RegExp(r'[\t ]*accDescr\s*\{');
int _lastBrace = -2;

// In the other grammars an `accDescr {` that never closes ends the lexing. Here `accDescr` is
// also a name and `{` a token, so each unclosed one would read to the end of the text again.
int _matchAccDescr(String src, int at, [int _ = -1]) {
  final n = src.length;
  var q = at;
  while (q < n) {
    final c = src.codeUnitAt(q);
    if (c != 32 && c != 9) break;
    q++;
  }
  if (!src.startsWith('accDescr', q)) return -1;
  final blockEnd = matchSticky(_reBlock, src, q);
  if (blockEnd != -1) {
    if (_lastBrace == -2) _lastBrace = src.lastIndexOf('}');
    if (blockEnd > _lastBrace) return -1;
  }
  return matchSticky(_reAccDescr, src, q);
}

final TokenType _id = TokenType(
  name: 'ID',
  pattern: RegExp(r'[\w]([-\w]*\w)?'),
);
final RegExp _reNameRest = RegExp(r'[-\w]*\w');

// Gives way to a longer name, except right after its option, as in `graticule polygonaxis`.
Scanner _optionValue(RegExp pattern, int option) {
  return (src, at, previous) {
    final end = matchSticky(pattern, src, at);
    if (end == -1) return -1;
    if (previous == option) return end;
    return matchSticky(_reNameRest, src, end) != -1 ? -1 : end;
  };
}

TokenType _word(String text) =>
    TokenType(name: text, pattern: text, longer: <TokenType>[_id]);
TokenType _mark(String text) => TokenType(name: text, pattern: text);

final TokenType _kwRadar = keyword('radar-beta');
final RegExp _reGraticule = RegExp(r'circle|polygon');
final RegExp _reBoolean = RegExp(r'true|false');

final List<TokenType> RADAR_TOKENS = <TokenType>[
  _mark('radar-beta:'),
  TokenType(
    name: _kwRadar.name,
    pattern: _kwRadar.pattern,
    first: _kwRadar.first,
    match: _kwRadar.match,
    longer: <TokenType>[_id],
  ),
  _word('showLegend'),
  _word('graticule'),
  _word('curve'),
  _word('ticks'),
  _word('axis'),
  _word('max'),
  _word('min'),
  _mark(':'),
  _mark(','),
  _mark('['),
  _mark(']'),
  _mark('{'),
  _mark('}'),
  TokenType(
    name: 'GRATICULE',
    pattern: _reGraticule,
    first: 'cp',
    match: _optionValue(_reGraticule, _T.graticule),
  ),
  TokenType(
    name: 'BOOLEAN',
    pattern: _reBoolean,
    first: 'tf',
    match: _optionValue(_reBoolean, _T.showLegend),
  ),
  TokenType(
    name: ACC_DESCR.name,
    pattern: ACC_DESCR.pattern,
    first: ACC_DESCR.first,
    match: _matchAccDescr,
  ),
  ACC_TITLE,
  titleBefore(r'[-\w]*\w'),
  TokenType(
    name: 'NUMBER',
    pattern: RegExp(r'(?:[0-9]+\.[0-9]+(?!\.))|(?:0|[1-9][0-9]*(?!\.))'),
    first: '0123456789',
    match: _matchNumber,
  ),
  STRING,
  _id,
  NEWLINE,
  WHITESPACE,
  YAML,
  DIRECTIVE,
  SINGLE_LINE_COMMENT,
];

class AxisAst {
  final String $type = 'Axis';
  final String name;
  String? label;

  AxisAst({required this.name, this.label});
}

class AxisRefAst {
  final String $refText;

  const AxisRefAst({required this.$refText});
}

class EntryAst {
  final String $type = 'Entry';
  // Langium leaves the reference unresolved; Mermaid reads only its text.
  final AxisRefAst? axis;
  final double value;

  const EntryAst({this.axis, required this.value});
}

class CurveAst {
  final String $type = 'Curve';
  final String name;
  String? label;
  final List<EntryAst> entries;

  CurveAst({required this.name, this.label, List<EntryAst>? entries})
    : entries = entries ?? <EntryAst>[];
}

class OptionAst {
  final String $type = 'Option';
  final String name;
  final Object value;

  const OptionAst({required this.name, required this.value});
}

class RadarAst {
  final String $type = 'Radar';
  String? title;
  String? accTitle;
  String? accDescr;
  final List<AxisAst> axes;
  final List<CurveAst> curves;
  final List<OptionAst> options;

  RadarAst({
    this.title,
    this.accTitle,
    this.accDescr,
    List<AxisAst>? axes,
    List<CurveAst>? curves,
    List<OptionAst>? options,
  }) : axes = axes ?? <AxisAst>[],
       curves = curves ?? <CurveAst>[],
       options = options ?? <OptionAst>[];
}

Tokens lexRadar(String src) {
  _runFrom = _runEnd = 0;
  _lastBrace = -2;
  return tokenize(src, RADAR_TOKENS, 'radar');
}

RadarAst parseRadar(String src) {
  final r = Reader(lexRadar(src), RADAR_TOKENS, 'radar');
  final ast = RadarAst();

  void newlines() {
    while (r.kind == _T.newline) {
      r.i++;
    }
  }

  void endOfLine() {
    if (r.kind == -1) return;
    if (r.kind != _T.newline) r.fail('a line break or the end of input');
    newlines();
  }

  String? label() {
    if (!r.accept(_T.open)) return null;
    final text = stringValue(r.expect(_T.string));
    r.expect(_T.close);
    return text;
  }

  EntryAst entry(bool detailed) {
    if (!detailed) {
      return EntryAst(value: double.parse(r.expect(_T.number)));
    }
    final axis = AxisRefAst($refText: r.expect(_T.id));
    r.accept(_T.colon);
    return EntryAst(axis: axis, value: double.parse(r.expect(_T.number)));
  }

  CurveAst curve() {
    final name = r.expect(_T.id);
    final text = label();
    final node = CurveAst(name: name, label: text);
    r.expect(_T.openBrace);
    newlines();
    if (r.kind != _T.number && r.kind != _T.id) {
      r.fail('a number or an axis name');
    }
    final detailed = r.kind == _T.id;
    node.entries.add(entry(detailed));
    while (r.accept(_T.comma)) {
      newlines();
      node.entries.add(entry(detailed));
    }
    newlines();
    r.expect(_T.closeBrace);
    return node;
  }

  AxisAst axis() {
    final node = AxisAst(name: r.expect(_T.id));
    final text = label();
    if (text != null) node.label = text;
    return node;
  }

  OptionAst option() {
    final kind = r.kind;
    final name = r.take();
    Object value;
    if (kind == _T.showLegend) {
      value = r.expect(_T.boolean) == 'true';
    } else if (kind == _T.graticule) {
      value = r.expect(_T.graticuleValue);
    } else {
      value = double.parse(r.expect(_T.number));
    }
    return OptionAst(name: name, value: value);
  }

  bool isOption() =>
      r.kind == _T.showLegend ||
      r.kind == _T.ticks ||
      r.kind == _T.max ||
      r.kind == _T.min ||
      r.kind == _T.graticule;

  newlines();
  if (!r.accept(_T.radarColon)) {
    r.expect(_T.radar);
    r.accept(_T.colon);
  }
  newlines();
  while (r.kind != -1) {
    switch (r.kind) {
      case _T.newline:
        r.i++;
      case _T.accDescr:
        ast.accDescr = accDescrValue(r.take());
        endOfLine();
      case _T.accTitle:
        ast.accTitle = accTitleValue(r.take());
        endOfLine();
      case _T.title:
        ast.title = titleValue(r.take());
        endOfLine();
      case _T.axis:
        r.i++;
        do {
          ast.axes.add(axis());
        } while (r.accept(_T.comma));
      case _T.curve:
        r.i++;
        do {
          ast.curves.add(curve());
        } while (r.accept(_T.comma));
      default:
        if (!isOption()) {
          r.fail('an axis, a curve, an option, a title, or a line break');
        }
        ast.options.add(option());
        while (r.accept(_T.comma)) {
          if (!isOption()) r.fail('an option');
          ast.options.add(option());
        }
    }
  }
  return ast;
}

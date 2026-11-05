// Upstream: src/diagrams/pie/parser.ts

import '../../util/math_js.dart';
import '../common/tokens.dart';

class _T {
  static const int showData = 0;
  static const int pie = 1;
  static const int colon = 2;
  static const int number = 3;
  static const int accDescr = 4;
  static const int accTitle = 5;
  static const int title = 6;
  static const int string = 7;
  static const int newline = 8;
}

int _digits(String src, int from) {
  var i = from;
  for (var c = charCodeAt(src, i); c >= 48 && c <= 57; c = charCodeAt(src, i)) {
    i++;
  }
  return i;
}

// Answers as NUMBER_PIE's pattern does. The pattern reads a whole run of digits before it finds
// there is no fraction, and would do so again from every digit of a long run of zeros.
Scanner _numberScanner() {
  var from = 0;
  var end = 0;
  var fraction = -1;
  return (String src, int p, int _) {
    final at = charCodeAt(src, p) == 45 ? p + 1 : p;
    if (at < from || at >= end) {
      from = at;
      end = _digits(src, at);
      fraction = -1;
      if (end > at && charCodeAt(src, end) == 46) {
        final stop = _digits(src, end + 1);
        final length = stop - end - 1;
        if (length > 0 && charCodeAt(src, stop) != 46) {
          fraction = stop;
        } else if (length > 1) {
          fraction = stop - 1;
        }
      }
    }
    if (end == at) return -1;
    if (fraction >= 0) return fraction;
    if (charCodeAt(src, at) == 48) {
      return charCodeAt(src, at + 1) == 46 ? -1 : at + 1;
    }
    if (charCodeAt(src, end) != 46) return end;
    return end - 1 > at ? end - 1 : -1;
  };
}

final List<TokenType> PIE_TOKENS = <TokenType>[
  keyword('showData'),
  keyword('pie'),
  const TokenType(name: ':', pattern: ':'),
  TokenType(
    name: 'NUMBER_PIE',
    pattern: RegExp(r'(?:-?[0-9]+\.[0-9]+(?!\.))|(?:-?(0|[1-9][0-9]*)(?!\.))'),
    scanner: _numberScanner,
    first: '-0123456789',
  ),
  ACC_DESCR,
  ACC_TITLE,
  TITLE,
  STRING,
  NEWLINE,
  WHITESPACE,
  YAML,
  DIRECTIVE,
  SINGLE_LINE_COMMENT,
];

class PieSection {
  final String $type = 'PieSection';
  final String label;
  final double value;

  const PieSection({required this.label, required this.value});
}

class PieAst {
  final String $type = 'Pie';
  bool showData;
  String? title;
  String? accTitle;
  String? accDescr;
  final List<PieSection> sections;

  PieAst({
    this.showData = false,
    this.title,
    this.accTitle,
    this.accDescr,
    List<PieSection>? sections,
  }) : sections = sections ?? <PieSection>[];
}

PieAst parsePie(String src) {
  final r = Reader(tokenize(src, PIE_TOKENS, 'pie'), PIE_TOKENS, 'pie');
  final ast = PieAst();

  void endOfLine() {
    if (r.kind == -1) return;
    if (r.kind != _T.newline) r.fail('a line break or the end of input');
    while (r.kind == _T.newline) {
      r.i++;
    }
  }

  while (r.kind == _T.newline) {
    r.i++;
  }
  r.expect(_T.pie);
  ast.showData = r.accept(_T.showData);
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
      case _T.string:
        final label = stringValue(r.take());
        r.expect(_T.colon);
        final value = double.parse(r.expect(_T.number));
        ast.sections.add(PieSection(label: label, value: value));
        endOfLine();
      default:
        r.fail('a section, a title, or a line break');
    }
  }
  return ast;
}

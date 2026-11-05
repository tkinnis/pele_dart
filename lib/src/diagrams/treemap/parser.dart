// Upstream: src/diagrams/treemap/parser.ts

import '../common/tokens.dart';

class _T {
  static const int accDescr = 0;
  static const int accTitle = 1;
  static const int title = 2;
  static const int keyword = 3;
  static const int classDef = 4;
  static const int styleSeparator = 5;
  static const int separator = 6;
  static const int comma = 7;
  static const int indentation = 8;
  static const int id = 12;
  static const int number = 13;
  static const int string = 14;
}

// Mermaid's treemap grammar has its own terminals. Every run of spaces or tabs is an INDENTATION
// token, since that comes before WS, and line breaks are hidden, so rows are told apart by their
// tokens alone and the indentation of a row is whatever whitespace precedes it.
final List<TokenType> TREEMAP_TOKENS = <TokenType>[
  ACC_DESCR,
  ACC_TITLE,
  titleBefore(r'\w'),
  TokenType(name: 'TREEMAP_KEYWORD', pattern: RegExp(r'treemap-beta|treemap')),
  TokenType(
    name: 'CLASS_DEF',
    pattern: RegExp(
      r'classDef\s+([a-zA-Z_][a-zA-Z0-9_]+)(?:\s+([^;\r\n]*))?(?:;)?',
    ),
  ),
  TokenType(name: 'STYLE_SEPARATOR', pattern: RegExp(r':::')),
  TokenType(name: 'SEPARATOR', pattern: RegExp(r':')),
  TokenType(name: 'COMMA', pattern: RegExp(r',')),
  TokenType(name: 'INDENTATION', pattern: RegExp(r'[ \t]{1,}')),
  TokenType(name: 'WS', pattern: RegExp(r'[ \t]+'), hidden: true),
  TokenType(name: 'ML_COMMENT', pattern: RegExp(r'%%[^\n]*'), hidden: true),
  TokenType(name: 'NL', pattern: RegExp(r'\r?\n'), hidden: true),
  TokenType(name: 'ID2', pattern: RegExp(r'[a-zA-Z_][a-zA-Z0-9_]*')),
  TokenType(name: 'NUMBER2', pattern: RegExp(r'[0-9_.,]+')),
  TokenType(
    name: 'STRING2',
    pattern: RegExp(
      r'"[^"]*"|'
      "'"
      r"[^']*'",
    ),
  ),
];

final RegExp _reClassDef = RegExp(
  r'classDef\s+([A-Z_a-z]\w+)(?:\s+([^\n\r;]*))?;?',
);
final RegExp _reFloat = RegExp(
  r'^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?',
);

double _parseFloat(String s) {
  final m = _reFloat.firstMatch(s.trimLeft());
  return m != null ? (double.tryParse(m.group(0)!) ?? double.nan) : double.nan;
}

sealed class TreemapItemAst {
  String get $type;
  String get name;
  String? get classSelector;
  set classSelector(String? value);
}

class SectionAst implements TreemapItemAst {
  @override
  final String $type = 'Section';
  @override
  final String name;
  @override
  String? classSelector;

  SectionAst({required this.name, this.classSelector});
}

class LeafAst implements TreemapItemAst {
  @override
  final String $type = 'Leaf';
  @override
  final String name;
  final double value;
  @override
  String? classSelector;

  LeafAst({required this.name, required this.value, this.classSelector});
}

sealed class TreemapStatementAst {
  String get $type;
  int? get indent;
}

class TreemapRowAst implements TreemapStatementAst {
  @override
  final String $type = 'TreemapRow';
  @override
  int? indent;
  final TreemapItemAst item;

  TreemapRowAst({this.indent, required this.item});
}

class ClassDefAst implements TreemapStatementAst {
  @override
  final String $type = 'ClassDefStatement';
  @override
  int? indent;
  final String className;
  String? styleText;

  ClassDefAst({this.indent, required this.className, this.styleText});
}

class TreemapAst {
  final String $type = 'Treemap';
  String? title;
  String? accTitle;
  String? accDescr;
  // ignore: non_constant_identifier_names
  final List<TreemapStatementAst> TreemapRows;

  TreemapAst({
    this.title,
    this.accTitle,
    this.accDescr,
    // ignore: non_constant_identifier_names
    List<TreemapStatementAst>? TreemapRows,
  }) : TreemapRows = TreemapRows ?? <TreemapStatementAst>[];
}

TreemapAst parseTreemap(String src) {
  final r = Reader(
    tokenize(src, TREEMAP_TOKENS, 'treemap'),
    TREEMAP_TOKENS,
    'treemap',
  );
  final kinds = r.kinds;
  final ast = TreemapAst();

  String? classSelector() =>
      r.accept(_T.styleSeparator) ? r.expect(_T.id) : null;

  r.expect(_T.keyword);
  while (r.kind != -1) {
    final kind = r.kind;
    if (kind == _T.accDescr) {
      ast.accDescr = accDescrValue(r.take());
      continue;
    }
    if (kind == _T.accTitle) {
      ast.accTitle = accTitleValue(r.take());
      continue;
    }
    if (kind == _T.title) {
      ast.title = titleValue(r.take());
      continue;
    }
    if (kind != _T.indentation && kind != _T.string && kind != _T.classDef) {
      r.fail('a node, a class definition, or a title');
    }

    final indent = kind == _T.indentation ? r.take().length : null;
    if (r.kind == _T.classDef) {
      final m = _reClassDef.firstMatch(r.take())!;
      final row = ClassDefAst(className: m.group(1)!, indent: indent);
      final styleText = m.group(2);
      if (styleText != null && styleText.isNotEmpty) {
        row.styleText = styleText;
      }
      ast.TreemapRows.add(row);
      continue;
    }

    final rawName = r.expect(_T.string);
    final name = rawName.substring(1, rawName.length - 1);
    // A leaf is a name followed by a colon or comma, with or without whitespace before it.
    final after = kinds[r.i] == _T.indentation ? r.i + 1 : r.i;
    TreemapItemAst item;
    if (kinds[after] == _T.separator || kinds[after] == _T.comma) {
      r.i = after + 1;
      r.accept(_T.indentation);
      item = LeafAst(
        name: name,
        value: _parseFloat(r.expect(_T.number).replaceAll(',', '')),
      );
    } else {
      item = SectionAst(name: name);
    }
    final selector = classSelector();
    if (selector != null) item.classSelector = selector;
    final row = TreemapRowAst(item: item, indent: indent);
    ast.TreemapRows.add(row);
  }
  return ast;
}

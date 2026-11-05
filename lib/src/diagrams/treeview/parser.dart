// Upstream: src/diagrams/treeview/parser.ts

import '../../util/chars.dart';
import '../../util/math_js.dart';
import '../common/acc_descr.dart';
import '../common/tokens.dart';

class _T {
  static const int keyword = 0;
  static const int accDescr = 1;
  static const int accTitle = 2;
  static const int title = 3;
  static const int classAnnotation = 4;
  static const int iconAnnotation = 5;
  static const int descAnnotation = 6;
  static const int indentation = 7;
  static const int quotedName = 8;
  static const int bareName = 12;
}

bool _annotationAt(String src, int at) {
  if (src.startsWith('##', at) || src.startsWith('icon(', at)) return true;
  if (!src.startsWith(':::', at)) return false;
  var i = at + 3;
  while (isBlank(charCodeAt(src, i))) {
    i++;
  }
  final c = charCodeAt(src, i);
  return (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95;
}

// The pattern looks ahead from every blank for an annotation, which rescans long runs of blanks.
// This looks once per run.
int _matchBareName(String src, int at, int _) {
  final first = charCodeAt(src, at);
  if (isBlank(first) ||
      first == 10 ||
      first == 13 ||
      first == 34 ||
      first == 39) {
    return -1;
  }
  if (src.startsWith(':::', at) ||
      src.startsWith('icon(', at) ||
      src.startsWith('##', at)) {
    return -1;
  }
  final n = src.length;
  var i = at + 1;
  while (i < n) {
    final c = charCodeAt(src, i);
    if (c == 10 || c == 13) break;
    if (isBlank(c)) {
      var j = i + 1;
      while (isBlank(charCodeAt(src, j))) {
        j++;
      }
      if (_annotationAt(src, j)) break;
      i = j;
    } else {
      i++;
    }
  }
  return i;
}

final TokenType _bareName = TokenType(
  name: 'BARE_NAME',
  pattern: RegExp(
    r'''(?!:::|icon\(|##)[^ \t\n\r"'](?:(?![ \t]+:::[ \t]*[A-Za-z_]|[ \t]+icon\(|[ \t]+##)[^\n\r])*''',
  ),
  match: _matchBareName,
);

final TokenType _kwTreeView = keyword('treeView-beta');

final List<TokenType> TREEVIEW_TOKENS = <TokenType>[
  TokenType(
    name: _kwTreeView.name,
    pattern: _kwTreeView.pattern,
    first: _kwTreeView.first,
    longer: <TokenType>[_bareName],
  ),
  accDescr(),
  ACC_TITLE,
  titleBefore(r'(?!%%)[^\n\r]'),
  TokenType(
    name: 'CLASS_ANNOTATION',
    pattern: RegExp(r'[ \t]+:::[ \t]*[A-Za-z_][\w-]*'),
  ),
  TokenType(
    name: 'ICON_ANNOTATION',
    pattern: RegExp(r'[ \t]+icon\([\w-]*(?::[\w-]+)?\)'),
  ),
  TokenType(name: 'DESC_ANNOTATION', pattern: RegExp(r'[ \t]+##[^\n\r]*')),
  TokenType(name: 'INDENTATION', pattern: RegExp(r'[ \t]{1,}')),
  TokenType(
    name: 'QUOTED_NAME',
    pattern: RegExp(
      r'"[^"]*"|'
      "'"
      r"[^']*'",
    ),
  ),
  TokenType(name: 'WS', pattern: RegExp(r'[ \t]+'), hidden: true),
  TokenType(name: 'ML_COMMENT', pattern: RegExp(r'%%[^\n]*'), hidden: true),
  TokenType(name: 'NL', pattern: RegExp(r'\r?\n'), hidden: true),
  _bareName,
];

class TreeNodeAst {
  final String $type = 'TreeNode';
  int? indent;
  String name;
  String? classAnnotation;
  String? iconAnnotation;
  String? descAnnotation;

  TreeNodeAst({
    this.indent,
    required this.name,
    this.classAnnotation,
    this.iconAnnotation,
    this.descAnnotation,
  });
}

class TreeViewAst {
  final String $type = 'TreeView';
  String? title;
  String? accTitle;
  String? accDescr;
  final List<TreeNodeAst> nodes;

  TreeViewAst({
    this.title,
    this.accTitle,
    this.accDescr,
    List<TreeNodeAst>? nodes,
  }) : nodes = nodes ?? <TreeNodeAst>[];
}

String _trimBlanksEnd(String text) {
  var end = text.length;
  while (end > 0 && isBlank(text.codeUnitAt(end - 1))) {
    end--;
  }
  return end == text.length ? text : text.substring(0, end);
}

// Mermaid's TreeViewValueConverter, by terminal name.
Object? convertValue(String rule, String input) {
  switch (rule) {
    case 'INDENTATION':
      return input.length;
    case 'QUOTED_NAME':
      return input.substring(1, input.length - 1);
    case 'BARE_NAME':
      return _trimBlanksEnd(input);
    case 'CLASS_ANNOTATION':
      return input.trim().substring(3).trim();
    case 'ICON_ANNOTATION':
      final trimmed = input.trim();
      return trimmed.substring(5, trimmed.length - 1);
    case 'DESC_ANNOTATION':
      return input.trim().substring(2).trim();
    default:
      return null;
  }
}

TreeViewAst parseTreeView(String src) {
  final r = Reader(
    tokenize(src, TREEVIEW_TOKENS, 'treeView'),
    TREEVIEW_TOKENS,
    'treeView',
  );
  final ast = TreeViewAst();
  r.expect(_T.keyword);
  for (;;) {
    if (r.kind == _T.accDescr) {
      ast.accDescr = accDescrValue(r.take());
    } else if (r.kind == _T.accTitle) {
      ast.accTitle = accTitleValue(r.take());
    } else if (r.kind == _T.title) {
      ast.title = titleValue(r.take());
    } else {
      break;
    }
  }
  while (r.kind != -1) {
    final node = TreeNodeAst(name: '');
    if (r.kind == _T.indentation) node.indent = r.take().length;
    if (r.kind == _T.quotedName) {
      final text = r.take();
      node.name = text.substring(1, text.length - 1);
    } else if (r.kind == _T.bareName) {
      node.name = _trimBlanksEnd(r.take());
    } else {
      r.fail('a name');
    }
    for (;;) {
      if (r.kind == _T.classAnnotation) {
        node.classAnnotation =
            convertValue('CLASS_ANNOTATION', r.take()) as String;
      } else if (r.kind == _T.iconAnnotation) {
        node.iconAnnotation =
            convertValue('ICON_ANNOTATION', r.take()) as String;
      } else if (r.kind == _T.descAnnotation) {
        node.descAnnotation =
            convertValue('DESC_ANNOTATION', r.take()) as String;
      } else {
        break;
      }
    }
    ast.nodes.add(node);
  }
  return ast;
}

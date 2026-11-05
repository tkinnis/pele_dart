// Upstream: src/diagrams/treeview/model.ts

import '../../errors.dart';
import '../../svg/root.dart';
import 'box_drawing.dart';
import 'parser.dart';

typedef NodeType = String;

class TreeNode {
  final int id;
  final int level;
  final String name;
  final NodeType nodeType;
  // An icon name as written (`pack:name`, `file`, `folder`), or `none` to hide the icon.
  final String? icon;
  final String? cssClass;
  final String? description;
  final List<TreeNode> children;

  TreeNode({
    required this.id,
    required this.level,
    required this.name,
    required this.nodeType,
    this.icon,
    this.cssClass,
    this.description,
    List<TreeNode>? children,
  }) : children = children ?? <TreeNode>[];
}

class TreeViewModel implements RootModel {
  final String type = 'treeView';
  final String? title;
  @override
  final String? accTitle;
  @override
  final String? accDescr;
  // A directory named `/` at level -1 that holds the top-level entries.
  final TreeNode root;
  final int count;

  const TreeViewModel({
    this.title,
    this.accTitle,
    this.accDescr,
    required this.root,
    required this.count,
  });
}

// Mermaid's treeView database: nodes arrive in source order with their indentation.
class TreeViewDb {
  int count = 1;
  final TreeNode root = TreeNode(
    id: 0,
    level: -1,
    name: '/',
    nodeType: 'directory',
  );
  late final List<TreeNode> _stack = <TreeNode>[root];

  void addNode(
    int level,
    String name,
    NodeType nodeType, [
    String? cssClass,
    String? icon,
    String? description,
  ]) {
    while (level <= _stack.last.level) {
      _stack.removeLast();
    }
    final node = TreeNode(
      id: count++,
      level: level,
      name: name,
      nodeType: nodeType,
      icon: icon,
      cssClass: cssClass,
      description: description,
    );
    _stack.last.children.add(node);
    _stack.add(node);
  }
}

void populate(TreeViewAst ast, TreeViewDb db) {
  for (final node in ast.nodes) {
    final level = node.indent ?? 0;
    var name = node.name;
    final isDirectory = name.endsWith('/');
    if (isDirectory) name = name.substring(0, name.length - 1);
    final rawIcon = node.iconAnnotation;
    db.addNode(
      level,
      name,
      isDirectory ? 'directory' : 'file',
      (node.classAnnotation != null && node.classAnnotation!.isNotEmpty)
          ? node.classAnnotation
          : null,
      rawIcon != null ? (rawIcon.isNotEmpty ? rawIcon : 'none') : null,
      (node.descAnnotation != null && node.descAnnotation!.isNotEmpty)
          ? node.descAnnotation
          : null,
    );
  }
}

// Reads the source to a syntax tree, accepting box-drawing input. Errors name lines of the original text.
TreeViewAst readTreeView(String source) {
  final pre = preprocessBoxDrawing(source);
  final text = pre.text;
  final lineMap = pre.lineMap;
  final columns = pre.columns;
  try {
    return parseTreeView(text);
  } catch (error) {
    // The parser already located errors in unchanged text.
    if (error is! PeleError || text == source) rethrow;
    final line = lineMap[error.line];
    if (line == null) rethrow;
    final at = error.column > 0
        ? (columns[error.line]?.call(error.column - 1) ?? error.column - 1)
        : 0;
    final written = locate(source, lineStart(source, line) + at);
    final head = error.message.contains('\n')
        ? error.message.indexOf('\n')
        : error.message.length;
    final rest = error.message.substring(head);
    final message =
        remapErrorLines(error.message.substring(0, head), <int, int>{
          error.line: written.line,
        }) +
        (error.snippet.isNotEmpty
            ? rest.replaceFirst(error.snippet, written.snippet)
            : rest);
    throw PeleError(
      message,
      error.code,
      PeleErrorInfo(
        type: error.type,
        line: written.line,
        column: error.column > 0 ? written.column : 0,
        snippet: error.snippet.isNotEmpty ? written.snippet : '',
      ),
    );
  }
}

final RegExp _leadSpacesRe = RegExp(r'^\s+');
final RegExp _newlineSpacesRe = RegExp(r'\n\s+');

TreeViewModel buildTreeView(TreeViewAst ast, String? title) {
  final db = TreeViewDb();
  populate(ast, db);
  final astTitle = ast.title;
  return TreeViewModel(
    title: (astTitle != null && astTitle.isNotEmpty) ? astTitle : title,
    accTitle: ast.accTitle != null && ast.accTitle!.isNotEmpty
        ? ast.accTitle!.replaceFirst(_leadSpacesRe, '')
        : null,
    accDescr: ast.accDescr != null && ast.accDescr!.isNotEmpty
        ? ast.accDescr!.replaceAll(_newlineSpacesRe, '\n')
        : null,
    root: db.root,
    count: db.count,
  );
}

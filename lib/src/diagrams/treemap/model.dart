// Upstream: src/diagrams/treemap/model.ts

import '../../svg/root.dart';
import 'parser.dart';

class TreemapNode {
  final String name;
  // Sections have a list, which may be empty. Leaves have none.
  final List<TreemapNode>? children;
  double? value;
  String? classSelector;
  List<String>? cssCompiledStyles;

  TreemapNode({
    required this.name,
    this.children,
    this.value,
    this.classSelector,
    this.cssCompiledStyles,
  });
}

class TreemapItem {
  final int level;
  final String name;
  final String type;
  final double? value;
  final String? classSelector;
  final List<String>? cssCompiledStyles;

  const TreemapItem({
    required this.level,
    required this.name,
    required this.type,
    this.value,
    this.classSelector,
    this.cssCompiledStyles,
  });
}

class TreemapModel implements RootModel {
  final String type = 'treemap';
  final String? title;
  @override
  final String? accTitle;
  @override
  final String? accDescr;
  final List<TreemapNode> roots;
  final Map<String, List<String>> classes;

  const TreemapModel({
    this.title,
    this.accTitle,
    this.accDescr,
    required this.roots,
    required this.classes,
  });
}

class _StackEntry {
  final TreemapNode node;
  final int level;

  const _StackEntry({required this.node, required this.level});
}

// A row belongs to the nearest section above it that is indented less.
List<TreemapNode> buildHierarchy(List<TreemapItem> items) {
  final roots = <TreemapNode>[];
  final stack = <_StackEntry>[];
  for (final item in items) {
    final leaf = item.type == 'Leaf';
    final node = TreemapNode(
      name: item.name,
      children: leaf ? null : <TreemapNode>[],
      classSelector: item.classSelector,
      cssCompiledStyles: item.cssCompiledStyles,
      value: leaf ? item.value : null,
    );

    while (stack.isNotEmpty && stack.last.level >= item.level) {
      stack.removeLast();
    }
    if (stack.isEmpty) {
      roots.add(node);
    } else {
      stack.last.node.children!.add(node);
    }
    if (!leaf) {
      stack.add(_StackEntry(node: node, level: item.level));
    }
  }
  return roots;
}

final RegExp _leadSpacesRe = RegExp(r'^\s+');
final RegExp _newlineSpacesRe = RegExp(r'\n\s+');

TreemapModel buildTreemap(TreemapAst ast, String? title) {
  final classes = <String, List<String>>{};
  for (final row in ast.TreemapRows) {
    if (row is! ClassDefAst) continue;
    final styles = classes.putIfAbsent(row.className, () => <String>[]);
    // An escaped comma stays in the value; the others separate declarations.
    final text = (row.styleText ?? '')
        .replaceAll(r'\,', '§§§')
        .replaceAll(',', ';')
        .replaceAll('§§§', ',');
    for (final style in text.split(';')) {
      styles.add(style);
    }
  }

  final items = <TreemapItem>[];
  for (final row in ast.TreemapRows) {
    if (row is! TreemapRowAst) continue;
    final item = row.item;
    final styles = item.classSelector != null
        ? classes[item.classSelector!]
        : null;
    items.add(
      TreemapItem(
        level: row.indent ?? 0,
        name: item.name,
        type: item.$type,
        value: item is LeafAst ? item.value : null,
        classSelector: item.classSelector,
        cssCompiledStyles: styles != null && styles.isNotEmpty ? styles : null,
      ),
    );
  }

  final astTitle = ast.title;
  final astAccTitle = ast.accTitle;
  final astAccDescr = ast.accDescr;

  return TreemapModel(
    title: (astTitle != null && astTitle.isNotEmpty) ? astTitle : title,
    accTitle: (astAccTitle != null && astAccTitle.isNotEmpty)
        ? astAccTitle.replaceFirst(_leadSpacesRe, '')
        : null,
    accDescr: (astAccDescr != null && astAccDescr.isNotEmpty)
        ? astAccDescr.replaceAll(_newlineSpacesRe, '\n')
        : null,
    roots: buildHierarchy(items),
    classes: classes,
  );
}

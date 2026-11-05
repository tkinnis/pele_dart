// Upstream: src/diagrams/mindmap/db.ts

import '../../errors.dart';
import '../common/outline.dart' as outline;

class MindmapNode {
  final int id;
  final String nodeId;
  final int level;
  final String descr;
  final int type;
  final List<MindmapNode> children;
  final bool isRoot;
  // Index of the first-level branch the node belongs to, wrapping after eleven as in Mermaid.
  int? section;
  String? className;
  String? icon;

  MindmapNode({
    required this.id,
    required this.nodeId,
    required this.level,
    required this.descr,
    required this.type,
    List<MindmapNode>? children,
    required this.isRoot,
    this.section,
    this.className,
    this.icon,
  }) : children = children ?? <MindmapNode>[];
}

abstract interface class MindmapModel {
  String get type;
  String? get title;
  // In source order, which is depth-first. The first node is the root.
  List<MindmapNode> get nodes;
}

const int _SECTIONS = 11;

class MindmapDb implements MindmapModel, outline.OutlineDb {
  @override
  final String type = 'mindmap';
  @override
  String? title;
  @override
  final List<MindmapNode> nodes = <MindmapNode>[];

  int _baseLevel = 0;
  // The chain of nodes that can still take children, with strictly increasing levels.
  final List<MindmapNode> _open = <MindmapNode>[];

  @override
  int getType(String start, String end) => outline.getType(start, end);

  @override
  void addNode(
    int level,
    String id,
    String descr,
    int type, [
    String? shapeData,
  ]) {
    final isRoot = nodes.isEmpty;
    if (isRoot) _baseLevel = level;
    level -= _baseLevel;

    // Mermaid's parent is the last node with a smaller indentation, wherever it is in the tree.
    final open = _open;
    var depth = open.length;
    while (depth > 0 && open[depth - 1].level >= level) {
      depth--;
    }
    final parent = depth > 0 ? open[depth - 1] : null;
    if (parent == null && !isRoot) {
      throw PeleError(
        'There can be only one root. No parent could be found for ("$descr")',
        'semantic',
        const PeleErrorInfo(type: 'mindmap'),
      );
    }
    final node = MindmapNode(
      id: nodes.length,
      nodeId: id,
      level: level,
      descr: descr,
      type: type,
      children: <MindmapNode>[],
      isRoot: isRoot,
    );
    if (parent != null) {
      node.section = parent.isRoot
          ? parent.children.length % _SECTIONS
          : parent.section;
      parent.children.add(node);
    }
    open.length = depth;
    open.add(node);
    nodes.add(node);
  }

  // Mermaid throws a TypeError when a decoration comes before any node. Here it is ignored.
  @override
  void decorateNode([outline.OutlineDecoration? decoration]) {
    if (decoration == null || nodes.isEmpty) return;
    final node = nodes.last;
    if (decoration.icon != null && decoration.icon!.isNotEmpty) {
      node.icon = decoration.icon;
    }
    if (decoration.className != null && decoration.className!.isNotEmpty) {
      node.className = decoration.className;
    }
  }
}

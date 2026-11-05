// Upstream: src/diagrams/class/graph.ts

import 'db.dart';
import 'types.dart';

typedef NodeShape = String;
typedef EndMarker = String;

class GraphNode {
  final String id;
  final String label;
  final bool isGroup;
  final NodeShape shape;
  final String? parentId;
  // Index of the namespace node this one is drawn in, or -1.
  int parent;
  final ClassNode? classNode;
  // Position among the classes, in declaration order. Namespaces and notes have none.
  final int? colorIndex;

  GraphNode({
    required this.id,
    required this.label,
    required this.isGroup,
    required this.shape,
    this.parentId,
    required this.parent,
    this.classNode,
    this.colorIndex,
  });
}

class GraphEdge {
  final String id;
  final String start;
  final String end;
  // Indexes into the node list. Ids alone are ambiguous: a class may be named `note0` or `interface0`.
  final int source;
  final int target;
  final String? label;
  final EndMarker arrowTypeStart;
  final EndMarker arrowTypeEnd;
  final String startLabelRight;
  final String endLabelLeft;
  final String pattern;
  final String classes;

  const GraphEdge({
    required this.id,
    required this.start,
    required this.end,
    required this.source,
    required this.target,
    this.label,
    required this.arrowTypeStart,
    required this.arrowTypeEnd,
    required this.startLabelRight,
    required this.endLabelLeft,
    required this.pattern,
    required this.classes,
  });
}

class ClassGraph {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;

  const ClassGraph({required this.nodes, required this.edges});
}

const List<EndMarker> _MARKERS = <EndMarker>[
  'aggregation',
  'extension',
  'composition',
  'dependency',
  'lollipop',
];

EndMarker _marker(RelationEnd type) {
  return (type is int && type >= 0 && type < _MARKERS.length)
      ? _MARKERS[type]
      : 'none';
}

// Resolves a parsed class diagram into the nodes and edges that are drawn. With `hierarchical`
// off, only namespaces the source declares are kept and each is labeled with its full name.
ClassGraph buildClassGraph(ClassModel model, [bool hierarchical = true]) {
  final nodes = <GraphNode>[];
  final edges = <GraphEdge>[];
  final namespaceAt = <String, int>{};
  final classAt = <String, int>{};
  final interfaceAt = <String, int>{};

  final declared = <String, String?>{};
  String? declaredAncestor(String? id) {
    if (hierarchical || id == null) return id;
    final chain = <String>[];
    String? current = id;
    String? found;
    while (current != null && current.isNotEmpty) {
      if (declared.containsKey(current)) {
        found = declared[current];
        break;
      }
      final ns = model.namespaces[current];
      if (ns == null) break;
      if (ns.explicit) {
        found = current;
        break;
      }
      chain.add(current);
      current = ns.parent;
    }
    for (final visited in chain) {
      declared[visited] = found;
    }
    return found;
  }

  int group(String? id) => id == null ? -1 : (namespaceAt[id] ?? -1);

  for (final ns in model.namespaces.values) {
    if (!hierarchical && !ns.explicit) continue;
    namespaceAt[ns.id] = nodes.length;
    nodes.add(
      GraphNode(
        id: ns.id,
        label: hierarchical ? ns.label : ns.id,
        isGroup: true,
        shape: 'rect',
        parentId: hierarchical ? ns.parent : null,
        parent: -1,
      ),
    );
  }
  for (final node in nodes) {
    node.parent = group(node.parentId);
  }

  var colorIndex = 0;
  for (final classNode in model.classes.values) {
    final parentId = declaredAncestor(classNode.parent);
    classAt[classNode.id] = nodes.length;
    nodes.add(
      GraphNode(
        id: classNode.id,
        label: classNode.label,
        isGroup: false,
        shape: 'classBox',
        parentId: parentId,
        parent: group(parentId),
        classNode: classNode,
        colorIndex: colorIndex++,
      ),
    );
  }

  for (final note in model.notes.values) {
    final parentId = declaredAncestor(note.parent);
    final target = note.className == null ? null : classAt[note.className!];
    if (target != null) {
      edges.add(
        GraphEdge(
          id: 'edgeNote${note.index}',
          start: note.id,
          end: nodes[target].id,
          source: nodes.length,
          target: target,
          arrowTypeStart: 'none',
          arrowTypeEnd: 'none',
          startLabelRight: '',
          endLabelLeft: '',
          pattern: 'dotted',
          classes: 'relation',
        ),
      );
    }
    nodes.add(
      GraphNode(
        id: note.id,
        label: note.text,
        isGroup: false,
        shape: 'note',
        parentId: parentId,
        parent: group(parentId),
      ),
    );
  }

  // Mermaid leaves every lollipop interface outside the namespaces. Here it stays beside its class.
  for (final item in model.interfaces) {
    final owner = classAt[item.classId];
    interfaceAt[item.id] = nodes.length;
    nodes.add(
      GraphNode(
        id: item.id,
        label: item.label,
        isGroup: false,
        shape: 'interface',
        parent: owner == null ? -1 : nodes[owner].parent,
      ),
    );
  }

  var count = 0;
  for (final relation in model.relations) {
    count++;
    final type1 = relation.relation.type1;
    final type2 = relation.relation.type2;
    // addRelation swaps in an interface for the lollipop end of a relation with no other marker.
    final startAt = type1 == RELATION_TYPE.LOLLIPOP && type2 == 'none'
        ? interfaceAt
        : classAt;
    final endAt =
        identical(startAt, classAt) &&
            type2 == RELATION_TYPE.LOLLIPOP &&
            type1 == 'none'
        ? interfaceAt
        : classAt;
    edges.add(
      GraphEdge(
        id: 'id_${relation.id1}_${relation.id2}_$count',
        start: relation.id1,
        end: relation.id2,
        source: startAt[relation.id1] ?? -1,
        target: endAt[relation.id2] ?? -1,
        label: relation.title,
        arrowTypeStart: _marker(type1),
        arrowTypeEnd: _marker(type2),
        startLabelRight: relation.relationTitle1 == 'none'
            ? ''
            : relation.relationTitle1,
        endLabelLeft: relation.relationTitle2 == 'none'
            ? ''
            : relation.relationTitle2,
        pattern: relation.relation.lineType == 1 ? 'dashed' : 'solid',
        classes: 'relation',
      ),
    );
  }

  return ClassGraph(nodes: nodes, edges: edges);
}

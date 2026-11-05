// Upstream: src/diagrams/er/graph.ts

import 'types.dart';

class ErGraphNode {
  const ErGraphNode({
    required this.id,
    required this.label,
    required this.alias,
    required this.attributes,
    required this.isGroup,
    required this.parentId,
    required this.cssStyles,
    required this.cssCompiledStyles,
    required this.cssClasses,
    required this.dir,
    required this.labelType,
  });

  final String id;
  final String label;
  final String alias;
  final List<ErAttribute> attributes;
  final bool isGroup;
  final String? parentId;
  final List<String> cssStyles;
  final List<String> cssCompiledStyles;
  final String cssClasses;
  final String? dir;
  final String labelType;
}

class ErGraphEdge {
  const ErGraphEdge({
    required this.id,
    required this.start,
    required this.end,
    required this.label,
    required this.arrowTypeStart,
    required this.arrowTypeEnd,
    required this.pattern,
  });

  final String id;
  final String start;
  final String end;
  final String label;
  final String arrowTypeStart;
  final String arrowTypeEnd;
  final String pattern; // 'solid' | 'dashed'
}

class ErGraph {
  const ErGraph({required this.nodes, required this.edges});

  final List<ErGraphNode> nodes;
  final List<ErGraphEdge> edges;
}

const List<ErAttribute> _noAttributes = <ErAttribute>[];

/// Resolves a parsed ER diagram into what is drawn: subgraphs as groups, entities as nodes with
/// their class styles, and relationships as edges with a marker type at each end.
ErGraph buildErGraph(ErModel model) {
  final nodes = <ErGraphNode>[];
  final edges = <ErGraphEdge>[];
  final subgraphs = model.subgraphs;

  List<String> compiled(List<String> classNames) {
    final out = <String>[];
    for (final name in classNames) {
      final def = model.classes[name];
      if (def == null) continue;
      for (final style in def.styles) {
        out.add(style.trim());
      }
      for (final style in def.textStyles) {
        out.add(style.trim());
      }
    }
    return out;
  }

  final parentOf = <String, String>{};
  final subgraphIds = <String>{};
  for (var i = subgraphs.length - 1; i >= 0; i--) {
    final subgraph = subgraphs[i];
    subgraphIds.add(subgraph.id);
    for (final id in subgraph.nodes) {
      parentOf[id] = subgraph.id;
    }
  }

  for (var i = subgraphs.length - 1; i >= 0; i--) {
    final subgraph = subgraphs[i];
    nodes.add(
      ErGraphNode(
        id: subgraph.id,
        label: subgraph.title,
        alias: '',
        attributes: _noAttributes,
        isGroup: true,
        parentId: parentOf[subgraph.id],
        cssStyles: subgraph.cssStyles,
        cssCompiledStyles: compiled(subgraph.classes),
        cssClasses: subgraph.classes.join(' '),
        dir: subgraph.dir,
        labelType: subgraph.labelType,
      ),
    );
  }

  // A name that is also a subgraph id stands for the subgraph. Mermaid drops such an entity and
  // leaves relationships written before the subgraph pointing at nothing; here they follow it.
  final moved = <String, String>{};
  for (final entry in model.entities.entries) {
    final name = entry.key;
    final entity = entry.value;
    if (subgraphIds.contains(name)) {
      moved[entity.id] = name;
      continue;
    }
    nodes.add(
      ErGraphNode(
        id: entity.id,
        label: entity.label,
        alias: entity.alias,
        attributes: entity.attributes,
        isGroup: false,
        parentId: parentOf[name],
        cssStyles: entity.cssStyles,
        cssCompiledStyles: compiled(entity.cssClasses.split(' ')),
        cssClasses: entity.cssClasses,
        dir: null,
        labelType: 'markdown',
      ),
    );
  }

  for (var index = 0; index < model.relationships.length; index++) {
    final relationship = model.relationships[index];
    edges.add(
      ErGraphEdge(
        id: 'id_${relationship.entityA}_${relationship.entityB}_$index',
        start: moved[relationship.entityA] ?? relationship.entityA,
        end: moved[relationship.entityB] ?? relationship.entityB,
        label: relationship.roleA,
        arrowTypeStart: relationship.relSpec.cardB.toLowerCase(),
        arrowTypeEnd: relationship.relSpec.cardA.toLowerCase(),
        pattern: relationship.relSpec.relType == 'IDENTIFYING'
            ? 'solid'
            : 'dashed',
      ),
    );
  }

  return ErGraph(nodes: nodes, edges: edges);
}

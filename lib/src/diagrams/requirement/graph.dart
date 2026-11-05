// Upstream: src/diagrams/requirement/graph.ts

import 'db.dart';
import 'types.dart';

class GraphNode {
  const GraphNode({
    required this.id,
    required this.requirement,
    required this.element,
    required this.cssStyles,
    required this.cssClasses,
  });

  final String id;
  final Requirement? requirement;
  final RequirementElement? element;
  final List<String> cssStyles;
  final String cssClasses;
}

class GraphEdge {
  const GraphEdge({
    required this.id,
    required this.start,
    required this.end,
    required this.type,
    required this.contains,
  });

  final String id;
  final String? start;
  final String? end;
  final String type;
  final bool contains;
}

class RequirementGraph {
  const RequirementGraph({
    required this.nodes,
    required this.edges,
    required this.direction,
  });

  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final String direction;
}

/// The nodes and edges to lay out: requirements first, then elements, as Mermaid orders them.
RequirementGraph buildRequirementGraph(RequirementModel model) {
  final nodes = <GraphNode>[];
  for (final requirement in model.requirements.values) {
    nodes.add(
      GraphNode(
        id: requirement.name,
        requirement: requirement,
        element: null,
        cssStyles: requirement.cssStyles,
        cssClasses: requirement.classes.join(' '),
      ),
    );
  }
  for (final element in model.elements.values) {
    nodes.add(
      GraphNode(
        id: element.name,
        requirement: null,
        element: element,
        cssStyles: element.cssStyles,
        cssClasses: element.classes.join(' '),
      ),
    );
  }
  String? has(String id) =>
      (model.requirements.containsKey(id) || model.elements.containsKey(id))
      ? id
      : null;
  final edges = <GraphEdge>[
    for (var index = 0; index < model.relations.length; index++)
      GraphEdge(
        id: '${model.relations[index].src}-${model.relations[index].dst}-$index',
        start: has(model.relations[index].src),
        end: has(model.relations[index].dst),
        type: model.relations[index].type,
        contains: model.relations[index].type == Relationships.CONTAINS,
      ),
  ];
  return RequirementGraph(
    nodes: nodes,
    edges: edges,
    direction: model.direction,
  );
}

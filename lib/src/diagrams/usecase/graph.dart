// Upstream: src/diagrams/usecase/graph.ts

import 'types.dart';

class JsonRow {
  const JsonRow({
    required this.key,
    required this.accessibleKey,
    required this.value,
  });

  // Blank on the second and later values of an array.
  final String key;
  // The key again, for every row.
  final String accessibleKey;
  final String value;
}

class UsecaseGraphNode {
  UsecaseGraphNode({
    required this.id,
    required this.label,
    required this.labelType,
    required this.shape,
    required this.isGroup,
    required this.padding,
    required this.cssClasses,
    required this.cssStyles,
    required this.cssCompiledStyles,
    this.actorType,
    this.business,
    this.icon,
    this.stereotype,
    this.parentId,
    this.noteTarget,
    this.jsonRows,
    this.boundaryType,
  });

  final String id;
  final String label;
  final LabelType labelType;
  // Mermaid's shape names.
  final String shape;
  final bool isGroup;
  final double padding;
  final String cssClasses;
  final List<String> cssStyles;
  final List<String> cssCompiledStyles;
  final ActorType? actorType;
  final bool? business;
  final String? icon;
  final String? stereotype;
  final String? parentId;
  final String? noteTarget;
  final List<JsonRow>? jsonRows;
  final BoundaryType? boundaryType;
}

class UsecaseGraphEdge {
  UsecaseGraphEdge({
    required this.id,
    required this.start,
    required this.end,
    required this.relationshipType,
    required this.pattern,
    required this.arrowTypeStart,
    required this.arrowTypeEnd,
    this.label,
    this.labelType,
    required this.classes,
    required this.style,
    required this.cssCompiledStyles,
    required this.animate,
    this.animation,
    required this.minlen,
    required this.explicitId,
    required this.internal,
  });

  final String id;
  final String start;
  final String end;
  final String relationshipType;
  final String pattern;
  final String arrowTypeStart;
  final String arrowTypeEnd;
  String? label;
  LabelType? labelType;
  final String classes;
  final List<String> style;
  final List<String> cssCompiledStyles;
  final bool animate;
  final Animation? animation;
  final int minlen;
  final bool explicitId;
  // The dotted line from a note to what it is about.
  final bool internal;
}

class UsecaseGraph {
  const UsecaseGraph({required this.nodes, required this.edges});

  final List<UsecaseGraphNode> nodes;
  final List<UsecaseGraphEdge> edges;
}

const Map<String, String> _actorShapes = <String, String>{
  'normal': 'usecaseActor',
  'hollow': 'usecaseActorHollow',
  'awesome': 'usecaseActorAwesome',
  'icon': 'usecaseActorIcon',
};

// Start and end markers for each arrow type, in the order of the Arrow enum.
const List<List<String>> _markers = <List<String>>[
  <String>['none', 'arrow_point'],
  <String>['arrow_point', 'none'],
  <String>['none', 'none'],
  <String>['none', 'arrow_circle'],
  <String>['none', 'arrow_cross'],
  <String>['arrow_circle', 'none'],
  <String>['arrow_cross', 'none'],
];

const Object _undefined = Object();

String _scalar(Object? value) {
  if (identical(value, _undefined)) return 'undefined';
  return value is String
      ? value
      : value == null
      ? 'null'
      : '$value';
}

// One row for each leaf of a JSON object, depth first in the order the keys were written.
// Nesting is kept on a stack of its own, so depth is limited by memory and not by the call stack.
List<JsonRow> flattenJsonRows(UsecaseJsonNode json) {
  final rows = <JsonRow>[];
  final stack = <(Object?, String, String)>[(json.value, '', '')];
  final children = <(Object?, String, String)>[];
  while (stack.isNotEmpty) {
    final (current, path, pointer) = stack.removeLast();
    children.clear();
    if (current is List) {
      if (current.isEmpty) {
        rows.add(JsonRow(key: path, accessibleKey: path, value: '[]'));
      } else if (current.every(
        (item) => item == null || (item is! Map && item is! List),
      )) {
        for (var i = 0; i < current.length; i++) {
          rows.add(
            JsonRow(
              key: i == 0 ? path : '',
              accessibleKey: path,
              value: _scalar(current[i]),
            ),
          );
        }
      } else {
        for (var i = 0; i < current.length; i++) {
          children.add((current[i], '$path[$i]', '$pointer/$i'));
        }
      }
    } else if (current is Map) {
      final object = current;
      final keys =
          json.propertyOrder[pointer] ??
          <String>[for (final k in object.keys) '$k'];
      if (keys.isEmpty) {
        rows.add(JsonRow(key: path, accessibleKey: path, value: '{}'));
      }
      for (final key in keys) {
        children.add((
          object.containsKey(key) ? object[key] : _undefined,
          path.isNotEmpty ? '$path.$key' : key,
          '$pointer/${key.replaceAll('~', '~0').replaceAll('/', '~1')}',
        ));
      }
    } else {
      rows.add(
        JsonRow(key: path, accessibleKey: path, value: _scalar(current)),
      );
    }
    for (var i = children.length - 1; i >= 0; i--) {
      stack.add(children[i]);
    }
  }
  return rows;
}

String _classList(List<String?> names) {
  return <String>[
    for (final name in names)
      if (name != null && name.isNotEmpty) name,
  ].join(' ');
}

List<String> _relationshipMarkers(Relationship relationship) {
  if (relationship.type == 'generalization') {
    return const <String>['none', 'extension'];
  }
  if (relationship.type != 'association') {
    return _markers[Arrow.SOLID_ARROW];
  }
  final idx = relationship.arrowType;
  return (idx >= 0 && idx < _markers.length)
      ? _markers[idx]
      : _markers[Arrow.LINE_SOLID];
}

// Resolves a parsed use case diagram into what is drawn: every actor, use case, note, JSON table
// and boundary as a node with its class styles, and every relationship and note connector as an
// edge with its markers. Ports getData from Mermaid's use case DB.
UsecaseGraph buildUsecaseGraph(UsecaseModel model) {
  final nodes = <UsecaseGraphNode>[];
  final edges = <UsecaseGraphEdge>[];

  // A later class wins a property but keeps the place the property first took.
  List<String> compiled(List<String> classNames) {
    final out = <String, String>{};
    for (final name in <String>['default', ...classNames]) {
      final definition = model.classDefs[name];
      if (definition == null) continue;
      for (final raw in definition.styles) {
        final style = raw.trim();
        final colon = style.indexOf(':');
        final property = (colon == -1 ? style : style.substring(0, colon))
            .trim();
        if (property.isNotEmpty) out[property] = style;
      }
    }
    return out.values.toList();
  }

  for (final actor in model.actors.values) {
    nodes.add(
      UsecaseGraphNode(
        id: actor.id,
        label: actor.label,
        labelType: actor.labelType,
        shape: _actorShapes[actor.type] ?? 'usecaseActor',
        isGroup: false,
        padding: 10,
        cssClasses: _classList(<String?>[
          'default',
          'usecase-actor',
          'usecase-actor-${actor.type}',
          if (actor.business) 'usecase-business',
          ...actor.classes,
        ]),
        cssStyles: List<String>.of(actor.styles),
        cssCompiledStyles: compiled(actor.classes),
        actorType: actor.type,
        business: actor.business,
        icon: (actor.icon != null && actor.icon!.isNotEmpty)
            ? actor.icon
            : null,
        stereotype: (actor.stereotype != null && actor.stereotype!.isNotEmpty)
            ? actor.stereotype
            : null,
        parentId: (actor.parentId != null && actor.parentId!.isNotEmpty)
            ? actor.parentId
            : null,
      ),
    );
  }
  for (final useCase in model.useCases.values) {
    final ellipse = useCase.shape == 'ellipse';
    nodes.add(
      UsecaseGraphNode(
        id: useCase.id,
        label: useCase.label,
        labelType: useCase.labelType,
        shape: !ellipse
            ? 'rect'
            : useCase.business
            ? 'usecaseBusiness'
            : 'usecaseEllipse',
        isGroup: false,
        padding: ellipse ? 20 : 10,
        cssClasses: _classList(<String?>[
          'default',
          'usecase-element',
          'usecase-${useCase.shape}',
          if (useCase.business) 'usecase-business',
          ...useCase.classes,
        ]),
        cssStyles: List<String>.of(useCase.styles),
        cssCompiledStyles: compiled(useCase.classes),
        business: useCase.business,
        stereotype:
            (useCase.stereotype != null && useCase.stereotype!.isNotEmpty)
            ? useCase.stereotype
            : null,
        parentId: (useCase.parentId != null && useCase.parentId!.isNotEmpty)
            ? useCase.parentId
            : null,
      ),
    );
  }
  for (final note in model.notes.values) {
    nodes.add(
      UsecaseGraphNode(
        id: note.id,
        label: note.label,
        labelType: note.labelType,
        shape: 'note',
        isGroup: false,
        padding: 10,
        cssClasses: 'default usecase-note',
        cssStyles: <String>[],
        cssCompiledStyles: compiled(const <String>[]),
        noteTarget: note.target,
      ),
    );
  }
  for (final json in model.jsonNodes.values) {
    nodes.add(
      UsecaseGraphNode(
        id: json.id,
        label: json.id,
        labelType: 'text',
        shape: 'usecaseJsonTable',
        isGroup: false,
        padding: 10,
        cssClasses: _classList(<String?>[
          'default',
          'usecase-json-table',
          ...json.classes,
        ]),
        cssStyles: List<String>.of(json.styles),
        cssCompiledStyles: compiled(json.classes),
        jsonRows: flattenJsonRows(json),
      ),
    );
  }
  for (final boundary in model.systemBoundaries.values) {
    nodes.add(
      UsecaseGraphNode(
        id: boundary.id,
        label: boundary.label,
        labelType: boundary.labelType,
        shape: 'usecaseSystemBoundary',
        isGroup: true,
        padding: 20,
        cssClasses: _classList(<String?>[
          'default',
          'system-boundary',
          'system-boundary-${boundary.type}',
          ...boundary.classes,
        ]),
        cssStyles: List<String>.of(boundary.styles),
        cssCompiledStyles: compiled(boundary.classes),
        boundaryType: boundary.type,
      ),
    );
  }

  for (final relationship in model.relationships) {
    final semantic =
        relationship.type == 'include' || relationship.type == 'extend';
    final pair = _relationshipMarkers(relationship);
    final arrowTypeStart = pair[0];
    final arrowTypeEnd = pair[1];
    final animated = relationship.animate || relationship.animation != null;
    final edge = UsecaseGraphEdge(
      id: relationship.id,
      start: relationship.source,
      end: relationship.target,
      relationshipType: relationship.type,
      pattern: semantic ? 'dotted' : 'solid',
      arrowTypeStart: arrowTypeStart,
      arrowTypeEnd: arrowTypeEnd,
      classes: _classList(<String?>[
        'default',
        'relationship',
        'relationship-${relationship.type}',
        ...relationship.classes,
        if (animated) 'edge-animation-${relationship.animation ?? 'fast'}',
      ]),
      style: List<String>.of(relationship.styles),
      cssCompiledStyles: compiled(relationship.classes),
      animate: relationship.animate,
      animation: relationship.animation,
      minlen: relationship.minlen,
      explicitId: relationship.explicitId,
      internal: false,
    );
    // Include and extend are labelled with their kind, whatever label the relationship carries.
    if (semantic) {
      edge.label = relationship.type;
      edge.labelType = 'text';
    } else if (relationship.type == 'association') {
      if (relationship.label != null && relationship.label!.isNotEmpty) {
        edge.label = relationship.label;
      }
      if (relationship.labelType != null &&
          relationship.labelType!.isNotEmpty) {
        edge.labelType = relationship.labelType;
      }
    }
    edges.add(edge);
  }
  for (final note in model.notes.values) {
    edges.add(
      UsecaseGraphEdge(
        id: '${note.id}-edge',
        start: note.id,
        end: note.target,
        relationshipType: 'note',
        pattern: 'dotted',
        arrowTypeStart: 'none',
        arrowTypeEnd: 'none',
        classes: 'default relationship relationship-note',
        style: <String>[],
        cssCompiledStyles: compiled(const <String>[]),
        animate: false,
        minlen: 1,
        explicitId: false,
        internal: true,
      ),
    );
  }
  return UsecaseGraph(nodes: nodes, edges: edges);
}

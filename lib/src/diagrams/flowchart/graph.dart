// Upstream: src/diagrams/flowchart/graph.ts

import '../../util/yaml.dart';
import 'db.dart';
import 'types.dart';

class GraphNode {
  GraphNode({
    required this.id,
    required this.label,
    required this.labelType,
    required this.shape,
    required this.isGroup,
    required this.parentId,
    required this.cssStyles,
    required this.cssCompiledStyles,
    required this.cssClasses,
    required this.dir,
    this.link,
    this.linkTarget,
    this.tooltip,
    this.icon,
    this.pos,
    this.img,
    this.assetWidth,
    this.assetHeight,
    this.constraint,
    this.colorIndex,
    this.metadata,
  });

  String id;
  String? label;
  LabelType labelType;
  String shape;
  bool isGroup;
  String? parentId;
  List<String> cssStyles;
  List<String> cssCompiledStyles;
  String cssClasses;
  String? dir;
  String? link;
  String? linkTarget;
  String? tooltip;
  String? icon;
  String? pos;
  String? img;
  double? assetWidth;
  double? assetHeight;
  String? constraint;
  int? colorIndex;
  Map<String, YamlValue>? metadata;
}

class GraphEdge {
  GraphEdge({
    required this.id,
    required this.isUserDefinedId,
    required this.start,
    required this.end,
    required this.type,
    required this.label,
    required this.labelType,
    required this.thickness,
    required this.pattern,
    required this.minlen,
    required this.arrowTypeStart,
    required this.arrowTypeEnd,
    required this.cssCompiledStyles,
    required this.style,
    required this.classes,
    required this.animate,
    required this.animation,
    required this.curve,
  });

  String id;
  bool isUserDefinedId;
  String start;
  String end;
  String type;
  String label;
  LabelType labelType;
  String? thickness;
  String? pattern;
  int? minlen;
  String arrowTypeStart;
  String arrowTypeEnd;
  List<String> cssCompiledStyles;
  List<String> style;
  String classes;
  bool? animate;
  String? animation;
  String? curve;
}

class FlowGraph {
  const FlowGraph({required this.nodes, required this.edges});

  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
}

String _shapeOf(FlowNode vertex) {
  if (vertex.img != null && vertex.img!.isNotEmpty) return 'imageSquare';
  if (vertex.icon != null && vertex.icon!.isNotEmpty) {
    if (vertex.form == 'circle') return 'iconCircle';
    if (vertex.form == 'square') return 'iconSquare';
    if (vertex.form == 'rounded') return 'iconRounded';
    return 'icon';
  }
  switch (vertex.type) {
    case 'square':
    case null:
      return 'squareRect';
    case 'round':
      return 'roundedRect';
    default:
      return vertex.type!;
  }
}

(String, String) _arrows(String? type) {
  switch (type) {
    case 'arrow_point':
    case 'arrow_circle':
    case 'arrow_cross':
      return ('none', type!);
    case 'double_arrow_point':
    case 'double_arrow_circle':
    case 'double_arrow_cross':
      final single = type!.replaceFirst('double_', '');
      return (single, single);
  }
  return ('none', 'arrow_point');
}

/// Resolves a parsed flowchart into the nodes and edges that are actually drawn:
/// group membership, collapsed subgraphs, class styles and edge defaults.
FlowGraph buildFlowGraph(FlowDb model, [String? defaultCurve]) {
  final nodes = <GraphNode>[];
  final edges = <GraphEdge>[];
  final subgraphs = model.subgraphs;

  List<String> compiled(List<String> classNames) {
    final out = <String>[];
    for (final name in classNames) {
      final def = model.classes[name];
      if (def == null) continue;
      for (final s in def.styles) {
        out.add(s.trim());
      }
      for (final s in def.textStyles) {
        out.add(s.trim());
      }
    }
    return out;
  }

  final subgraphParent = <String, String>{};
  for (final sg in subgraphs) {
    for (final childId in sg.nodes) {
      if (model.subgraph(childId) != null) {
        subgraphParent[childId] = sg.id;
      }
    }
  }

  final declarationIndex = <String, int>{};
  final childrenOf = <String, List<String>>{};
  for (final sg in subgraphs) {
    final parent = subgraphParent[sg.id];
    if (parent == null) continue;
    final kids = childrenOf[parent];
    if (kids != null) {
      kids.add(sg.id);
    } else {
      childrenOf[parent] = <String>[sg.id];
    }
  }
  var nextIndex = 0;
  for (final sg in subgraphs) {
    if (subgraphParent.containsKey(sg.id)) continue;
    final pending = <String>[sg.id];
    while (pending.isNotEmpty) {
      final id = pending.removeLast();
      if (declarationIndex.containsKey(id)) continue;
      declarationIndex[id] = nextIndex++;
      final kids = childrenOf[id];
      if (kids != null) {
        for (var i = kids.length - 1; i >= 0; i--) {
          pending.add(kids[i]);
        }
      }
    }
  }

  bool isCollapsed(String id) =>
      model.subgraph(id)?.metadata?['view'] == 'collapsed';
  var anyCollapsed = false;
  for (final sg in subgraphs) {
    if (sg.metadata?['view'] == 'collapsed') anyCollapsed = true;
  }
  // The outermost collapsed subgraph around each subgraph, resolved once per chain of parents.
  final outermost = <String, String?>{};
  String? outermostCollapsed(String id) {
    final chain = <String>[];
    final seen = <String>{};
    String? current = id;
    while (current != null &&
        !outermost.containsKey(current) &&
        !seen.contains(current)) {
      seen.add(current);
      chain.add(current);
      current = subgraphParent[current];
    }
    var result = current != null ? outermost[current] : null;
    for (var i = chain.length - 1; i >= 0; i--) {
      if (result == null && isCollapsed(chain[i])) result = chain[i];
      outermost[chain[i]] = result;
    }
    return result;
  }

  final hidden = <String>{};
  final collapsedInto = <String, String>{};
  for (final sg in anyCollapsed ? subgraphs : const <FlowSubgraph>[]) {
    final ancestor = outermostCollapsed(sg.id);
    if (ancestor == null) continue;
    if (sg.id != ancestor) {
      hidden.add(sg.id);
      collapsedInto[sg.id] = ancestor;
    }
    for (final childId in sg.nodes) {
      if (childId == ancestor) continue;
      hidden.add(childId);
      collapsedInto[childId] = ancestor;
    }
  }

  final parentOf = <String, String>{};
  final groups = <String>{};
  for (var i = subgraphs.length - 1; i >= 0; i--) {
    final sg = subgraphs[i];
    if (hidden.contains(sg.id)) continue;
    if (sg.nodes.isNotEmpty) groups.add(sg.id);
    for (final id in sg.nodes) {
      parentOf[id] = sg.id;
    }
  }

  final byId = <String, GraphNode>{};
  for (var i = subgraphs.length - 1; i >= 0; i--) {
    final sg = subgraphs[i];
    if (hidden.contains(sg.id)) continue;
    final collapsed = sg.metadata?['view'] == 'collapsed';
    final node = GraphNode(
      id: sg.id,
      label: sg.title,
      labelType: sg.labelType,
      parentId: parentOf[sg.id],
      cssStyles: <String>[],
      cssCompiledStyles: compiled(sg.classes),
      cssClasses: sg.classes.join(' '),
      shape: collapsed ? 'collapsedGroup' : 'rect',
      dir: sg.dir,
      isGroup: !collapsed,
      colorIndex: declarationIndex[sg.id],
      metadata: collapsed ? null : sg.metadata,
    );
    nodes.add(node);
    byId[sg.id] = node;
  }

  for (final vertex in model.nodes.values) {
    if (hidden.contains(vertex.id)) continue;
    final existing = byId[vertex.id];
    if (existing != null) {
      existing.cssStyles = vertex.styles;
      existing.cssCompiledStyles = compiled(vertex.classes);
      existing.cssClasses = vertex.classes.join(' ');
      continue;
    }
    final isGroup = groups.contains(vertex.id);
    final node = GraphNode(
      id: vertex.id,
      label: vertex.text,
      labelType: vertex.labelType,
      parentId: parentOf[vertex.id],
      cssStyles: vertex.styles,
      cssCompiledStyles: compiled(<String>[
        'default',
        'node',
        ...vertex.classes,
      ]),
      cssClasses: 'default ${vertex.classes.join(' ')}',
      dir: vertex.dir,
      link: vertex.link,
      linkTarget: vertex.linkTarget,
      tooltip: model.tooltips[vertex.id],
      icon: vertex.icon,
      pos: vertex.pos,
      img: vertex.img,
      assetWidth: vertex.assetWidth,
      assetHeight: vertex.assetHeight,
      constraint: vertex.constraint,
      isGroup: isGroup,
      shape: isGroup ? 'rect' : _shapeOf(vertex),
    );
    nodes.add(node);
  }

  for (var index = 0; index < model.edges.length; index++) {
    final raw = model.edges[index];
    final start = collapsedInto[raw.start] ?? raw.start;
    final end = collapsedInto[raw.end] ?? raw.end;
    if (start == end &&
        (collapsedInto.containsKey(raw.start) ||
            collapsedInto.containsKey(raw.end))) {
      continue;
    }

    final (arrowStart, arrowEnd) = _arrows(raw.type);
    final styles = <String>[...?model.defaultEdgeStyle];
    if (raw.style != null) styles.addAll(raw.style!);
    final plain = raw.stroke == 'invisible' || raw.type == 'arrow_open';
    final curve = (raw.interpolate != null && raw.interpolate!.isNotEmpty)
        ? raw.interpolate
        : ((model.defaultInterpolate != null &&
                  model.defaultInterpolate!.isNotEmpty)
              ? model.defaultInterpolate
              : defaultCurve);
    edges.add(
      GraphEdge(
        id: (raw.id != null && raw.id!.isNotEmpty)
            ? raw.id!
            : 'L_${start}_${end}_$index',
        isUserDefinedId: raw.isUserDefinedId,
        start: start,
        end: end,
        type: raw.type ?? 'normal',
        label: raw.text,
        labelType: raw.labelType,
        thickness: raw.stroke,
        pattern: raw.stroke,
        minlen: raw.length,
        classes: raw.stroke == 'invisible'
            ? ''
            : 'edge-thickness-normal edge-pattern-solid flowchart-link',
        arrowTypeStart: plain ? 'none' : arrowStart,
        arrowTypeEnd: plain ? 'none' : arrowEnd,
        cssCompiledStyles: compiled(raw.classes),
        style: styles,
        animate: raw.animate,
        animation: raw.animation,
        curve: curve,
      ),
    );
  }

  return FlowGraph(nodes: nodes, edges: edges);
}

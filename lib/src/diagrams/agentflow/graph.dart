// Upstream: src/diagrams/agentflow/graph.ts

import '../../util/yaml.dart';
import 'color_slots.dart';
import 'db.dart';
import 'shapes.dart';
import 'types.dart';

class GraphNode implements ShapedNode, SlotNode {
  GraphNode({
    required this.id,
    this.label,
    required this.labelType,
    required this.shape,
    required this.isGroup,
    this.parentId,
    required this.cssStyles,
    required this.cssCompiledStyles,
    required this.cssClasses,
    this.dir,
    this.link,
    this.linkTarget,
    this.tooltip,
    this.colorIndex,
    this.kind,
    this.metadata,
  });

  @override
  String id;
  String? label;
  LabelType labelType;
  @override
  String shape;
  @override
  bool isGroup;
  String? parentId;
  List<String> cssStyles;
  List<String> cssCompiledStyles;
  String cssClasses;
  String? dir;
  String? link;
  String? linkTarget;
  String? tooltip;
  // Palette slot of a container.
  @override
  int? colorIndex;
  // What a node is, which picks its palette slot.
  @override
  String? kind;
  Metadata? metadata;
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
    this.thickness,
    this.pattern,
    this.minlen,
    required this.arrowTypeStart,
    required this.arrowTypeEnd,
    required this.cssCompiledStyles,
    required this.style,
    required this.classes,
    this.animate,
    this.animation,
    this.curve,
    this.metadata,
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
  YamlValue animate;
  YamlValue animation;
  String? curve;
  Metadata? metadata;
}

class AgentGraph {
  const AgentGraph({required this.nodes, required this.edges});

  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
}

// Resolves a parsed agentflow into the nodes and edges that are drawn: flow membership, collapsed
// flows, shapes reduced to the ones agentflow has, class styles and palette slots. Shape and
// containment problems are reported on the model as diagnostics.
AgentGraph buildAgentGraph(
  AgentflowDb db,
  int paletteLength, [
  String? defaultCurve,
]) {
  final nodes = <GraphNode>[];
  final edges = <GraphEdge>[];
  final subgraphs = db.subgraphs;

  List<String> compiled(List<String> classNames) {
    var out = <String>[];
    for (final name in classNames) {
      final def = db.classes[name];
      if (def != null) {
        out = <String>[...out, ...def.styles].map((s) => s.trim()).toList();
        out = <String>[...out, ...def.textStyles].map((s) => s.trim()).toList();
      }
    }
    return out;
  }

  // Everything inside a collapsed flow is hidden, and stands for its outermost collapsed flow.
  // Mermaid walks the whole inside of each collapsed flow, in the order the flows closed, and the
  // last walk to reach a thing wins. A thing has one container, so a later walk can only enter an
  // earlier one through its root: it stops there, and the root's owner is followed afterwards.
  final hidden = <String>{};
  final owner = <String, String>{};
  final walked = <String>{};
  for (final sg in subgraphs) {
    if (sg.metadata?['view'] != 'collapsed' || hidden.contains(sg.id)) continue;
    final pending = <String>[sg.id];
    while (pending.isNotEmpty) {
      final members = db.subgraph(pending.removeLast())?.nodes;
      if (members == null) continue;
      for (final childId in members) {
        if (childId == sg.id || hidden.contains(childId)) continue;
        hidden.add(childId);
        owner[childId] = sg.id;
        if (!walked.contains(childId)) pending.add(childId);
      }
    }
    walked.add(sg.id);
  }
  final collapsedInto = <String, String>{};
  for (final id in hidden) {
    final path = <String>[id];
    var top = owner[id]!;
    while (true) {
      final known = collapsedInto[top];
      final up = known ?? owner[top];
      if (up == null) break;
      if (known == null) path.add(top);
      top = up;
      if (known != null) break;
    }
    for (final p in path) {
      collapsedInto[p] = top;
    }
  }

  final position = <String, int>{};
  for (var i = 0; i < subgraphs.length; i++) {
    position[subgraphs[i].id] = i;
  }

  // Two flows can each name the other. The nesting that would close the loop is dropped.
  final parentOf = <String, String>{};
  bool closesLoop(String childId, String parentId, int at) {
    // Only a flow handled earlier in this pass can already be above the parent.
    final childAt = position[childId];
    if (childAt == null || childAt < at) return false;
    String? current = parentId;
    for (var hops = 0; current != null && hops <= subgraphs.length; hops++) {
      if (current == childId) return true;
      current = parentOf[current];
    }
    return false;
  }

  for (var i = subgraphs.length - 1; i >= 0; i--) {
    final sg = subgraphs[i];
    if (hidden.contains(sg.id)) continue;
    for (final id in sg.nodes) {
      if (closesLoop(id, sg.id, i)) {
        db.emitWarning(
          'CONTAINMENT_VIOLATION',
          'Container "${sg.id}" cannot contain "$id" because "$id" already contains it. The nesting that would close the loop is dropped.',
          (nodeId: id, edgeId: null),
        );
        continue;
      }
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
      shape: collapsed ? 'collapsedGroup' : 'flowGroup',
      dir: sg.dir,
      isGroup: !collapsed,
      metadata: collapsed
          ? <String, YamlValue>{...?sg.metadata, 'containerType': sg.type}
          : sg.metadata,
    );
    nodes.add(node);
    byId[sg.id] = node;
  }

  for (final vertex in db.nodes.values) {
    if (hidden.contains(vertex.id)) continue;
    final existing = byId[vertex.id];
    if (existing != null) {
      existing.cssStyles = vertex.styles;
      existing.cssCompiledStyles = compiled(vertex.classes);
      existing.cssClasses = vertex.classes.join(' ');
      continue;
    }
    final type = resolveShapeAlias(vertex.type);
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
      tooltip: db.tooltips[vertex.id],
      metadata: vertex.metadata,
      isGroup: false,
      shape: type == 'square' || type == null ? 'squareRect' : type,
    );
    nodes.add(node);
    byId[vertex.id] = node;
  }

  for (var index = 0; index < db.edges.length; index++) {
    final raw = db.edges[index];
    final start = collapsedInto[raw.start] ?? raw.start;
    final end = collapsedInto[raw.end] ?? raw.end;
    // An edge between two things inside one collapsed flow has nothing left to connect.
    if (start == end && raw.start != raw.end) continue;
    final styles = <String>[...?db.defaultEdgeStyle];
    if (raw.style != null) styles.addAll(raw.style!);
    final arrow = raw.type == 'arrow_open'
        ? 'none'
        : (raw.type == 'arrow_cross' || raw.type == 'arrow_point'
              ? raw.type!
              : 'arrow_point');
    final rawId = raw.id;
    final rawInterp = raw.interpolate;
    final defInterp = db.defaultInterpolate;
    edges.add(
      GraphEdge(
        id: (rawId != null && rawId.isNotEmpty)
            ? rawId
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
        classes: 'edge-thickness-normal edge-pattern-solid flowchart-link',
        arrowTypeStart: 'none',
        arrowTypeEnd: arrow,
        cssCompiledStyles: compiled(raw.classes),
        style: styles,
        animate: raw.animate,
        animation: raw.animation,
        curve: (rawInterp != null && rawInterp.isNotEmpty)
            ? rawInterp
            : ((defInterp != null && defInterp.isNotEmpty)
                  ? defInterp
                  : defaultCurve),
        metadata: raw.metadata,
      ),
    );
  }

  normaliseNodeShapes(nodes, db);

  // Containers are numbered in the order they were written: a walk of the nesting, parents first.
  // `subgraphs` itself is in the order the blocks closed, with a nested flow before its parent.
  final children = <String, List<String>>{};
  for (final sg in subgraphs) {
    final parent = parentOf[sg.id];
    if (parent == null) continue;
    final kids = children[parent];
    if (kids != null) {
      kids.add(sg.id);
    } else {
      children[parent] = <String>[sg.id];
    }
  }
  final order = <String, int>{};
  for (final sg in subgraphs) {
    if (parentOf[sg.id] != null) continue;
    final pending = <String>[sg.id];
    while (pending.isNotEmpty) {
      final id = pending.removeLast();
      if (order.containsKey(id)) continue;
      order[id] = order.length;
      final kids = children[id];
      if (kids != null) {
        for (var i = kids.length - 1; i >= 0; i--) {
          pending.add(kids[i]);
        }
      }
    }
  }

  assignColorSlots(
    nodes,
    (id) {
      if (db.connectors.containsKey(id)) return 'connector';
      final vertex = db.nodes[id];
      return vertex != null ? db.vertexKind(vertex) : null;
    },
    order,
    paletteLength,
  );

  return AgentGraph(nodes: nodes, edges: edges);
}

// Upstream: src/diagrams/agentflow/shapes.ts

import '../flowchart/shapes.dart' as flowchart_shapes;
import 'types.dart';

// Author-facing names for the shapes that carry meaning in an agentflow.
const Map<String, String> SHAPE_ALIASES = <String, String>{
  'task': 'roundedRect',
  'tool': 'subroutine',
  'input': 'lean-right',
  'decision': 'diamond',
  'refdoc': 'lin-doc',
  'action': 'hexagon',
  'round': 'rect',
};

const Set<String> REMOVED_SHAPES = <String>{
  'doc',
  'stadium',
  'terminal',
  'circle',
  'trapezoid',
  'inv_trapezoid',
  'inv-trapezoid',
  'doublecircle',
  'double-circle',
  'typeDeclaration',
  'procs',
  'lean_left',
  'lean-left',
  'in-out',
  'cylinder',
  'ellipse',
  'odd',
  'tag-rect',
  'tagged-rectangle',
  'delay',
  'half-rounded-rectangle',
  'lin-rect',
  'lined-rectangle',
  'win-pane',
  'window-pane',
  'curv-trap',
  'curved-trapezoid',
};

const Set<String> ALLOWED_SHAPES = <String>{
  'roundedRect',
  'subroutine',
  'subprocess',
  'subproc',
  'framed-rectangle',
  'lean-right',
  'diamond',
  'lin-doc',
  'lined-document',
  'hexagon',
  'hex',
  'connector',
  'collapsedGroup',
};

const String DEFAULT_SHAPE = 'roundedRect';

String? resolveShapeAlias(String? shape) {
  if (shape == null || shape.isEmpty) return shape;
  return SHAPE_ALIASES[shape] ?? shape;
}

// Mermaid looks a shape name up with `in` on a plain object, so `constructor` passes there too.
bool isValidShape(String name) {
  return flowchart_shapes.isValidShape(name) || name == 'constructor';
}

abstract interface class ShapeSink {
  void emitError(
    DiagnosticId id,
    String message, [
    ({String? nodeId, String? edgeId})? ctx,
  ]);
  void emitWarning(
    DiagnosticId id,
    String message, [
    ({String? nodeId, String? edgeId})? ctx,
  ]);
}

abstract interface class ShapedNode {
  String get id;
  String get shape;
  set shape(String value);
  bool get isGroup;
}

// Reduces every node's shape to one agentflow draws, reporting the removed and unsupported ones.
void normaliseNodeShapes(List<ShapedNode> nodes, ShapeSink sink) {
  for (final node in nodes) {
    if (node.isGroup) continue;
    if (node.shape.isEmpty ||
        node.shape == 'squareRect' ||
        node.shape == 'rect') {
      node.shape = DEFAULT_SHAPE;
    }
    if (REMOVED_SHAPES.contains(node.shape)) {
      sink.emitError(
        'SHAPE_REMOVED',
        'shape "${node.shape}" was removed in v0.8.1, using "$DEFAULT_SHAPE"',
        (nodeId: node.id, edgeId: null),
      );
      node.shape = DEFAULT_SHAPE;
    } else if (!ALLOWED_SHAPES.contains(node.shape)) {
      sink.emitWarning(
        'SHAPE_UNSUPPORTED',
        'shape "${node.shape}" is not supported, using "$DEFAULT_SHAPE"',
        (nodeId: node.id, edgeId: null),
      );
      node.shape = DEFAULT_SHAPE;
    }
  }
}

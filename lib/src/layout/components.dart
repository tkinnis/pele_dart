// Upstream: src/layout/components.ts

import 'dart:math' as math;
import 'dart:typed_data';

import 'compound.dart';

class _Part {
  final List<CNode> nodes = <CNode>[];
  final List<CEdge> edges = <CEdge>[];
  double left = double.infinity;
  double top = double.infinity;
  double right = double.negativeInfinity;
  double bottom = double.negativeInfinity;
}

/// Moves disconnected parts into rows without changing the layout inside a part.
CompoundResult? wrapComponents(
  List<CNode> nodes,
  List<CEdge> edges,
  double width,
  double gap,
) {
  final parent = Int32List(nodes.length);
  for (var i = 0; i < nodes.length; i++) {
    parent[i] = i;
  }
  int root(int i) {
    while (parent[i] != i) {
      parent[i] = parent[parent[i]];
      i = parent[i];
    }
    return i;
  }

  void join(int a, int b) {
    parent[root(a)] = root(b);
  }

  for (var i = 0; i < nodes.length; i++) {
    if (nodes[i].parent >= 0) join(i, nodes[i].parent);
  }
  for (final e in edges) {
    join(e.src, e.dst);
  }

  final parts = <int, _Part>{};
  void include(_Part p, double x, double y, [double w = 0, double h = 0]) {
    p.left = math.min(p.left, x - w / 2);
    p.top = math.min(p.top, y - h / 2);
    p.right = math.max(p.right, x + w / 2);
    p.bottom = math.max(p.bottom, y + h / 2);
  }

  for (var i = 0; i < nodes.length; i++) {
    final id = root(i);
    var part = parts[id];
    if (part == null) {
      part = _Part();
      parts[id] = part;
    }
    final c = nodes[i];
    part.nodes.add(c);
    include(part, c.x, c.y, c.w, c.h);
  }
  if (parts.length < 2) return null;
  for (final e in edges) {
    final part = parts[root(e.src)]!;
    part.edges.add(e);
    for (var i = 0; i < e.route.length; i += 3) {
      include(part, e.route[i], e.route[i + 1]);
    }
    if (e.labelW > 0) include(part, e.labelX, e.labelY, e.labelW, e.labelH);
  }

  var x = 0.0;
  var y = 0.0;
  var rowHeight = 0.0;
  var right = 0.0;
  var from = double.infinity;
  var to = double.negativeInfinity;
  final shifts = <double>[];
  for (final part in parts.values) {
    final w = part.right - part.left;
    final h = part.bottom - part.top;
    if (x > 0 && x + w > width) {
      y += rowHeight + gap;
      x = 0;
      rowHeight = 0;
    }
    shifts.addAll(<double>[x - part.left, y - part.top]);
    from = math.min(from, part.left);
    to = math.max(to, part.right);
    right = math.max(right, x + w);
    rowHeight = math.max(rowHeight, h);
    x += w + gap;
  }
  if (right >= to - from) return null;
  var k = 0;
  for (final part in parts.values) {
    shiftLayout(part.nodes, part.edges, shifts[k++], shifts[k++]);
  }
  return CompoundResult(width: right, height: y + rowHeight);
}

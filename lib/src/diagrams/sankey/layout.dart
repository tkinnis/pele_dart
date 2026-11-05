// Upstream: src/diagrams/sankey/layout.ts

import 'dart:math' as math;
import 'dart:typed_data';

import '../../errors.dart';
import 'db.dart';

typedef Alignment = String; // 'justify' | 'left' | 'right' | 'center'

class LayoutOptions {
  const LayoutOptions({
    required this.width,
    required this.height,
    required this.nodeWidth,
    required this.nodePadding,
    required this.labelHeight,
    required this.alignment,
  });

  final double width;
  final double height;
  final double nodeWidth;
  final double nodePadding;
  // Height of a label line; thin nodes are kept at least this far apart where there is room.
  final double labelHeight;
  final Alignment alignment;
}

class PlacedNode {
  PlacedNode({
    required this.layer,
    required this.value,
    required this.x,
    required this.y,
    required this.height,
  });

  int layer;
  // Total flow through the node, in the diagram's units.
  double value;
  double x;
  double y;
  double height;

  @override
  bool operator ==(Object other) =>
      other is PlacedNode &&
      other.layer == layer &&
      other.value == value &&
      other.x == x &&
      other.y == y &&
      other.height == height;

  @override
  int get hashCode => Object.hash(layer, value, x, y, height);
}

class PlacedLink {
  PlacedLink({
    required this.source,
    required this.target,
    required this.value,
    required this.thickness,
    required this.sourceY,
    required this.targetY,
  });

  final int source;
  final int target;
  final double value;
  double thickness;
  // Vertical centers of the band where it leaves its source and where it enters its target.
  double sourceY;
  double targetY;

  @override
  bool operator ==(Object other) =>
      other is PlacedLink &&
      other.source == source &&
      other.target == target &&
      other.value == value &&
      other.thickness == thickness &&
      other.sourceY == sourceY &&
      other.targetY == targetY;

  @override
  int get hashCode =>
      Object.hash(source, target, value, thickness, sourceY, targetY);
}

class SankeyLayout {
  const SankeyLayout({required this.nodes, required this.links});

  final List<PlacedNode> nodes;
  final List<PlacedLink> links;
}

const int _passes = 6;

// Most nodes have a handful of bands, and the built-in sort is slow to start on short lists.
void _sort(List<int> list, int Function(int a, int b) compare) {
  if (list.length > 8) {
    list.sort(compare);
    return;
  }
  for (var i = 1; i < list.length; i++) {
    final item = list[i];
    var j = i - 1;
    while (j >= 0 && compare(list[j], item) > 0) {
      list[j + 1] = list[j];
      j--;
    }
    list[j + 1] = item;
  }
}

int _cmpDouble(double diff, int a, int b) {
  if (diff < 0) return -1;
  if (diff > 0) return 1;
  return a - b;
}

// Places nodes in columns by their distance from a source, sizes them by their flow, and
// then lets each column settle next to its neighbours so that the bands cross less.
SankeyLayout layoutSankey(SankeyModel model, LayoutOptions options) {
  final n = model.nodes.length;
  final links = <PlacedLink>[
    for (final link in model.links)
      PlacedLink(
        source: link.source.index,
        target: link.target.index,
        value: link.value.isFinite && link.value > 0 ? link.value : 0,
        thickness: 0,
        sourceY: 0,
        targetY: 0,
      ),
  ];
  final outgoing = <List<int>>[for (var i = 0; i < n; i++) <int>[]];
  final incoming = <List<int>>[for (var i = 0; i < n; i++) <int>[]];
  for (var k = 0; k < links.length; k++) {
    final link = links[k];
    outgoing[link.source].add(k);
    incoming[link.target].add(k);
  }

  // Longest distance from a source, in topological order; what is left over lies on a cycle.
  final depth = Int32List(n);
  final pending = Int32List(n);
  final order = <int>[];
  for (var i = 0; i < n; i++) {
    pending[i] = incoming[i].length;
    if (pending[i] == 0) order.add(i);
  }
  for (var q = 0; q < order.length; q++) {
    final i = order[q];
    for (final k in outgoing[i]) {
      final t = links[k].target;
      if (depth[t] < depth[i] + 1) depth[t] = depth[i] + 1;
      if (--pending[t] == 0) order.add(t);
    }
  }
  if (order.length < n) {
    // Every node left over has a predecessor that is left over too; walking back finds the loop.
    var stuck = 0;
    while (pending[stuck] == 0) {
      stuck++;
    }
    final seen = Uint8List(n);
    while (seen[stuck] == 0) {
      seen[stuck] = 1;
      for (final k in incoming[stuck]) {
        if (pending[links[k].source] > 0) {
          stuck = links[k].source;
          break;
        }
      }
    }
    throw PeleError(
      'Sankey diagrams cannot have circular links, and "${model.nodes[stuck].id}" is part of one.',
      'semantic',
      const PeleErrorInfo(type: 'sankey'),
    );
  }
  var layers = 1;
  for (var i = 0; i < n; i++) {
    if (depth[i] + 1 > layers) layers = depth[i] + 1;
  }
  final reach = Int32List(n);
  for (var q = n - 1; q >= 0; q--) {
    final i = order[q];
    for (final k in outgoing[i]) {
      if (reach[i] < reach[links[k].target] + 1) {
        reach[i] = reach[links[k].target] + 1;
      }
    }
  }

  // Flows are scaled to the largest one, so that sums of huge values stay finite.
  var largest = 0.0;
  for (final link in links) {
    if (link.value > largest) largest = link.value;
  }
  final unit = largest > 0 ? 1.0 / largest : 0.0;

  final nodes = <PlacedNode>[];
  final flow = Float64List(n);
  final columns = <List<int>>[for (var l = 0; l < layers; l++) <int>[]];
  final step = layers > 1
      ? (options.width - options.nodeWidth) / (layers - 1)
      : 0.0;
  for (var i = 0; i < n; i++) {
    int layer;
    if (options.alignment == 'left') {
      layer = depth[i];
    } else if (options.alignment == 'right') {
      layer = layers - 1 - reach[i];
    } else if (options.alignment == 'center') {
      layer = depth[i];
      if (incoming[i].isEmpty && outgoing[i].isNotEmpty) {
        layer = layers;
        for (final k in outgoing[i]) {
          if (depth[links[k].target] - 1 < layer) {
            layer = depth[links[k].target] - 1;
          }
        }
      }
    } else {
      layer = outgoing[i].isNotEmpty ? depth[i] : layers - 1;
    }
    var into = 0.0;
    var out = 0.0;
    var value = 0.0;
    var valueOut = 0.0;
    for (final k in incoming[i]) {
      into += links[k].value * unit;
      value += links[k].value;
    }
    for (final k in outgoing[i]) {
      out += links[k].value * unit;
      valueOut += links[k].value;
    }
    flow[i] = math.max(into, out);
    nodes.add(
      PlacedNode(
        layer: layer,
        value: math.max(value, valueOut),
        x: layer * step,
        y: 0,
        height: 0,
      ),
    );
    columns[layer].add(i);
  }

  var tallest = 1;
  for (final column in columns) {
    if (column.length > tallest) tallest = column.length;
  }
  final gap = tallest > 1
      ? math.min(options.nodePadding, options.height / (tallest - 1))
      : options.nodePadding;
  var scale = double.infinity;
  for (final column in columns) {
    var sum = 0.0;
    for (final i in column) {
      sum += flow[i];
    }
    if (sum > 0) {
      scale = math.min(
        scale,
        (options.height - (column.length - 1) * gap) / sum,
      );
    }
  }
  if (!scale.isFinite || scale < 0) scale = 0;

  // A thin node still needs room for its label. Where every column can afford it, each node
  // claims at least a label's height, and the flows are scaled down to make that fit.
  var claim = math.max(0.0, options.labelHeight - gap);
  bool fits(double s) {
    for (final column in columns) {
      var extent = (column.length - 1) * gap;
      for (final i in column) {
        extent += math.max(flow[i] * s, claim);
      }
      if (extent > options.height + 1e-6) return false;
    }
    return true;
  }

  if (claim > 0 && !fits(scale)) {
    if (fits(0)) {
      var low = 0.0;
      for (var k = 0; k < 40; k++) {
        final mid = (low + scale) / 2;
        if (fits(mid)) {
          low = mid;
        } else {
          scale = mid;
        }
      }
      scale = low;
    } else {
      claim = 0;
    }
  }

  // The room a node keeps clear above and below itself.
  final margin = Float64List(n);
  for (final link in links) {
    link.thickness = link.value * unit * scale;
  }
  for (final column in columns) {
    var y = 0.0;
    for (final i in column) {
      nodes[i].height = flow[i] * scale;
      margin[i] = math.max(0.0, claim - nodes[i].height) / 2;
      nodes[i].y = y + margin[i];
      y += nodes[i].height + 2 * margin[i] + gap;
    }
    // Spare room is shared out between the nodes of a column.
    final spare = (options.height - y + gap) / (column.length + 1);
    for (var k = 0; k < column.length; k++) {
      nodes[column[k]].y += spare * (k + 1);
    }
  }

  double center(int i) => nodes[i].y + nodes[i].height / 2;

  // Bands leave and enter a node in the order of where they go, so they do not cross at it.
  // These are the offsets of each band's middle from the top of the node at either end.
  final sourceOffset = Float64List(links.length);
  final targetOffset = Float64List(links.length);
  int byTarget(int a, int b) =>
      _cmpDouble(center(links[a].target) - center(links[b].target), a, b);
  int bySource(int a, int b) =>
      _cmpDouble(center(links[a].source) - center(links[b].source), a, b);
  int byCenter(int a, int b) => _cmpDouble(center(a) - center(b), a, b);

  void stackOut(int i) {
    var y = 0.0;
    _sort(outgoing[i], byTarget);
    for (final k in outgoing[i]) {
      sourceOffset[k] = y + links[k].thickness / 2;
      y += links[k].thickness;
    }
  }

  void stackIn(int i) {
    var y = 0.0;
    _sort(incoming[i], bySource);
    for (final k in incoming[i]) {
      targetOffset[k] = y + links[k].thickness / 2;
      y += links[k].thickness;
    }
  }

  void stackAll() {
    for (var i = 0; i < n; i++) {
      stackOut(i);
      stackIn(i);
    }
  }

  // Moves each node of a column towards where its bands would run level, then restores the
  // order and the gaps. `forward` looks at the bands coming in, otherwise at those going out.
  void settle(List<int> column, double pull, bool forward) {
    for (final i in column) {
      final list = forward ? incoming[i] : outgoing[i];
      if (list.isEmpty) continue;
      if (forward) {
        stackIn(i);
      } else {
        stackOut(i);
      }
      var weighted = 0.0;
      var weight = 0.0;
      var plain = 0.0;
      for (final k in list) {
        final level = forward
            ? nodes[links[k].source].y + sourceOffset[k] - targetOffset[k]
            : nodes[links[k].target].y + targetOffset[k] - sourceOffset[k];
        weighted += level * links[k].thickness;
        weight += links[k].thickness;
        plain +=
            center(forward ? links[k].source : links[k].target) -
            nodes[i].height / 2;
      }
      final wanted = weight > 0 ? weighted / weight : plain / list.length;
      nodes[i].y += (wanted - nodes[i].y) * pull;
    }
    _sort(column, byCenter);
    var y = 0.0;
    for (final i in column) {
      if (nodes[i].y - margin[i] < y) nodes[i].y = y + margin[i];
      y = nodes[i].y + nodes[i].height + margin[i] + gap;
    }
    y = options.height;
    for (var k = column.length - 1; k >= 0; k--) {
      final i = column[k];
      if (nodes[i].y + nodes[i].height + margin[i] > y) {
        nodes[i].y = y - nodes[i].height - margin[i];
      }
      y = nodes[i].y - margin[i] - gap;
    }
  }

  stackAll();
  for (var pass = 0; pass < _passes; pass++) {
    final pull = math.pow(0.99, pass).toDouble();
    for (var l = layers - 2; l >= 0; l--) {
      settle(columns[l], pull, false);
    }
    stackAll();
    for (var l = 1; l < layers; l++) {
      settle(columns[l], pull, true);
    }
    stackAll();
  }
  for (var k = 0; k < links.length; k++) {
    links[k].sourceY = nodes[links[k].source].y + sourceOffset[k];
    links[k].targetY = nodes[links[k].target].y + targetOffset[k];
  }

  return SankeyLayout(nodes: nodes, links: links);
}

// Upstream: src/diagrams/treemap/layout.ts

import 'dart:math' as math;

import '../../util/math_js.dart';
import 'model.dart';

class Box {
  final TreemapNode node;
  final Box? parent;
  // Position among the top-level nodes of the branch this box belongs to, which picks its color.
  final int series;
  // A leaf's own value, or the sum of the leaves under a section.
  double value;
  final List<Box> children;
  // Small sections give their header space to their children.
  bool headed;
  double header;
  double x;
  double y;
  double w;
  double h;

  Box({
    required this.node,
    required this.parent,
    required this.series,
    required this.value,
    List<Box>? children,
    this.headed = false,
    this.header = 0,
    this.x = 0,
    this.y = 0,
    this.w = 0,
    this.h = 0,
  }) : children = children ?? <Box>[];
}

class Insets {
  final double gap;
  // Space a section keeps for its header, and around its children on the other three sides.
  final double header;
  final double short;
  final double side;

  const Insets({
    required this.gap,
    required this.header,
    required this.short,
    required this.side,
  });
}

Box _box(TreemapNode node, Box? parent, int series) {
  final val = node.value;
  final value =
      (node.children == null && val != null && val.isFinite && val > 0)
      ? val
      : 0.0;
  return Box(node: node, parent: parent, series: series, value: value);
}

double _clamp(double v, double low, double high) =>
    v >= low ? math.min(v, high) : low;

// Lays out boxes[from..to) in the rectangle as one squarified treemap: rows are added along the
// shorter side, and a row stops growing when another box would make its boxes less square.
void _squarify(
  List<Box> boxes,
  double total,
  double x,
  double y,
  double w,
  double h,
  double gap,
) {
  var rest = total;
  var from = 0;
  while (from < boxes.length) {
    final scale = (w * h) / rest;
    final side = math.min(w, h);
    var sum = boxes[from].value * scale;
    final largest = sum;
    var worst = math.max(
      (side * side * largest) / (sum * sum),
      (sum * sum) / (side * side * largest),
    );
    var to = from + 1;
    while (to < boxes.length) {
      final smallest = boxes[to].value * scale;
      final next = sum + smallest;
      final ratio = math.max(
        (side * side * largest) / (next * next),
        (next * next) / (side * side * smallest),
      );
      if (ratio > worst) break;
      worst = ratio;
      sum = next;
      to++;
    }

    final thickness = sum / side;
    var offset = 0.0;
    for (var i = from; i < to; i++) {
      final b = boxes[i];
      final length = i == to - 1
          ? side - offset
          : (b.value * scale) / thickness;
      final bx = w >= h ? x : x + offset;
      final by = w >= h ? y + offset : y;
      final bw = w >= h ? thickness : length;
      final bh = w >= h ? length : thickness;
      // Omit the gap if it would erase the box.
      final gx = roundJs(bx + bw - gap / 2) > roundJs(bx + gap / 2)
          ? gap / 2
          : 0.0;
      final gy = roundJs(by + bh - gap / 2) > roundJs(by + gap / 2)
          ? gap / 2
          : 0.0;
      b.x = roundJs(bx + gx).toDouble();
      b.y = roundJs(by + gy).toDouble();
      b.w = roundJs(bx + bw - gx).toDouble() - b.x;
      b.h = roundJs(by + bh - gy).toDouble() - b.y;
      offset += length;
      rest -= b.value;
    }
    if (w >= h) {
      x += thickness;
      w -= thickness;
    } else {
      y += thickness;
      h -= thickness;
    }
    from = to;
  }
}

// Returns boxes with positive values, including zero-size boxes, parents before children.
List<Box> layoutTreemap(
  List<TreemapNode> roots,
  double width,
  double height,
  Insets insets,
) {
  final top = List<Box>.generate(
    roots.length,
    (index) => _box(roots[index], null, index),
  );
  final all = List<Box>.of(top);
  for (var i = 0; i < all.length; i++) {
    final parent = all[i];
    for (final node in parent.node.children ?? const <TreemapNode>[]) {
      final child = _box(node, parent, parent.series);
      parent.children.add(child);
      all.add(child);
    }
  }
  for (var i = all.length - 1; i >= 0; i--) {
    final b = all[i];
    if (b.parent != null) b.parent!.value += b.value;
  }

  final gap = insets.gap;
  final header = insets.header;
  final short = insets.short;
  final side = insets.side;
  final placed = <Box>[];

  void place(List<Box> children, double x, double y, double w, double h) {
    final shown = children.where((b) => b.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    var total = 0.0;
    for (final b in shown) {
      total += b.value;
    }
    if (shown.isEmpty || !total.isFinite) return;
    w = math.max(0.0, w);
    h = math.max(0.0, h);
    if (w > 0 && h > 0) {
      _squarify(shown, total, x - gap / 2, y - gap / 2, w + gap, h + gap, gap);
    }
    for (final b in shown) {
      final x0 = _clamp(b.x, x, x + w);
      final y0 = _clamp(b.y, y, y + h);
      b.w = _clamp(b.x + b.w, x0, x + w) - x0;
      b.h = _clamp(b.y + b.h, y0, y + h) - y0;
      b.x = x0;
      b.y = y0;
      placed.add(b);
    }
  }

  place(top, 0, 0, width, height);
  for (var i = 0; i < placed.length; i++) {
    final b = placed[i];
    if (b.children.isEmpty) continue;
    final topInset = b.h - header - side >= 12 ? header : short;
    b.headed = b.w > math.max(24.0, 2 * side) && b.h - topInset - side >= 8;
    b.header = b.headed ? topInset : 0;
    if (b.headed) {
      place(
        b.children,
        b.x + side,
        b.y + topInset,
        b.w - 2 * side,
        b.h - topInset - side,
      );
    } else {
      place(b.children, b.x, b.y, b.w, b.h);
    }
  }
  return placed;
}

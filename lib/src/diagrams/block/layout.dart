// Upstream: src/diagrams/block/layout.ts

import 'dart:math' as math;

import '../../errors.dart';

class Cell {
  List<Cell> children;
  // Grid width of this container: a positive count, or -1 to put every child on one row.
  int columns;
  int span;
  bool space;
  // Height reserved above a container's grid for its title.
  double head;
  // Size the content needs. Set by the caller for leaves, computed here for containers.
  double nw;
  double nh;
  // Placement: grid position, then center and size in pixels.
  int col;
  int row;
  int cols;
  List<double> heights;
  // Extra space after each row or column.
  List<double> rowGaps;
  List<double> colGaps;
  double x;
  double y;
  double w;
  double h;

  Cell({
    List<Cell>? children,
    this.columns = -1,
    this.span = 1,
    this.space = false,
    this.head = 0,
    required this.nw,
    required this.nh,
    this.col = 0,
    this.row = 0,
    this.cols = 0,
    List<double>? heights,
    List<double>? rowGaps,
    List<double>? colGaps,
    this.x = 0,
    this.y = 0,
    this.w = 0,
    this.h = 0,
  }) : children = children ?? <Cell>[],
       heights = heights ?? <double>[],
       rowGaps = rowGaps ?? <double>[],
       colGaps = colGaps ?? <double>[];
}

const int _maxSpan = 1000;

Cell cell(double nw, double nh, [int span = 1]) {
  return Cell(nw: nw, nh: nh, span: span);
}

({int px, int py}) calculateBlockPosition(int columns, int position) {
  if (columns == 0) {
    throw PeleError(
      'Columns must be an integer !== 0.',
      'semantic',
      const PeleErrorInfo(type: 'block'),
    );
  }
  if (position < 0) {
    throw PeleError(
      'Position must be a non-negative integer.$position',
      'semantic',
      const PeleErrorInfo(type: 'block'),
    );
  }
  if (columns < 0) return (px: position, py: 0);
  return (px: position % columns, py: position ~/ columns);
}

double _gapAt(List<double> gaps, int index) =>
    (index >= 0 && index < gaps.length) ? gaps[index] : 0.0;

// Puts each child in its grid cell and sizes the container. Every column is as wide as the widest
// block needs. Every row that holds a plain block is as tall as the tallest block in the container,
// as in Mermaid; a row of nothing but containers is only as tall as they need.
void _measure(Cell box, double gap, double inset) {
  final columns = box.columns;
  final heights = <double>[];
  var position = 0;
  var cols = 0;
  var cw = 0.0;
  var tallest = 0.0;
  for (final child in box.children) {
    final (:px, :py) = calculateBlockPosition(columns, position);
    // Mermaid lets a block wider than the rest of its row stick out of the grid. Here it stops at the last column.
    var span = child.span >= 1 ? math.min<int>(child.span, _maxSpan) : 1;
    if (columns > 0 && span > columns - px) span = columns - px;
    child.span = span;
    child.col = px;
    child.row = py;
    position += span;
    if (px + span > cols) cols = px + span;
    if (py == heights.length) heights.add(0);
    if (child.children.isEmpty) {
      heights[py] = -1;
    } else if (heights[py] >= 0 && child.nh > heights[py]) {
      heights[py] = child.nh;
    }
    if (child.space) continue;
    final width = (child.nw - gap * (span - 1)) / span;
    if (width > cw) cw = width;
    if (child.nh > tallest) tallest = child.nh;
  }
  var height = (heights.length - 1) * gap + _total(box.rowGaps);
  for (var row = 0; row < heights.length; row++) {
    if (heights[row] < 0) heights[row] = tallest;
    height += heights[row];
  }
  box.cols = cols;
  box.heights = heights;
  box.nw = math.max(
    box.nw,
    cols * cw + (cols - 1) * gap + _total(box.colGaps) + 2 * inset,
  );
  box.nh = height + 2 * inset + box.head;
}

// Gives each child its cell, sharing out any room the container has beyond what it needs.
void _arrange(Cell box, double gap, double inset) {
  final cols = box.cols;
  final heights = box.heights;
  final rowGaps = box.rowGaps;
  final colGaps = box.colGaps;
  final rows = heights.length;
  final cw = (box.w - 2 * inset - (cols - 1) * gap - _total(colGaps)) / cols;
  final room =
      box.h - 2 * inset - box.head - (rows - 1) * gap - _total(rowGaps);
  final offsets = <double>[];
  if (colGaps.isNotEmpty) {
    var sum = 0.0;
    for (var col = 0; col < cols; col++) {
      offsets.add(sum);
      sum += _gapAt(colGaps, col);
    }
  }
  var needed = 0.0;
  for (final height in heights) {
    needed += height;
  }
  final scale = needed > 0 ? room / needed : 0.0;
  final share = needed > 0 ? 0.0 : room / rows;
  final left = box.x - box.w / 2 + inset;
  var top = box.y - box.h / 2 + inset + box.head;
  var row = 0;
  for (final child in box.children) {
    for (; row < child.row; row++) {
      top += heights[row] * scale + share + gap + _gapAt(rowGaps, row);
    }
    final before = _gapAt(offsets, child.col);
    child.w =
        cw * child.span +
        gap * (child.span - 1) +
        _gapAt(offsets, child.col + child.span - 1) -
        before;
    child.h = heights[row] * scale + share;
    child.x = left + child.col * (cw + gap) + before + child.w / 2;
    child.y = top + child.h / 2;
  }
}

double _total(List<double> gaps) {
  var sum = 0.0;
  for (final gap in gaps) {
    sum += gap;
  }
  return sum;
}

// Lays out a tree of cells in place. The root has no border, so its grid starts at the origin.
({double width, double height}) layout(Cell root, double gap) {
  final order = <Cell>[root];
  for (var i = 0; i < order.length; i++) {
    for (final child in order[i].children) {
      order.add(child);
    }
  }
  for (var i = order.length - 1; i >= 0; i--) {
    final box = order[i];
    if (box.children.isNotEmpty) _measure(box, gap, i == 0 ? 0 : gap);
  }
  root.w = root.nw;
  root.h = root.nh;
  root.x = root.w / 2;
  root.y = root.h / 2;
  for (var i = 0; i < order.length; i++) {
    final box = order[i];
    if (box.children.isNotEmpty) _arrange(box, gap, i == 0 ? 0 : gap);
  }
  return (width: root.w, height: root.h);
}

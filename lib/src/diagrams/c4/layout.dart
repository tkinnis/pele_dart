// Upstream: src/diagrams/c4/layout.ts

import 'dart:math' as math;

import '../../svg/edges.dart';
import '../../text/label.dart';
import '../../text/measurer.dart';
import 'db.dart';
import 'route.dart';
import 'types.dart';

const double _shapeW = 216;
const double _shapeMinH = 64;
const double _padX = 14;
const double _padY = 12;
// Room between two columns for the label of a line across them, clear of an arrowhead on either side,
// with an arrowhead's length to spare for a word a little wider than the label room.
const double _gapX = NARROW + LABEL_PAD + 3 * ARROW;
const double _gapY = 88;
// Room for a relation to run along the inside of a boundary.
const double GROUP_PAD = LANE + 8;
const double _groupGap = 48;
// Where a boundary's heading starts, from its top-left corner.
const double HEAD_LEFT = 16;
const double HEAD_TOP = 10;

// Shape keywords Mermaid accepts in $shape, $sprite or $tags, as names of the shared shapes.
const Map<String, String> _forms = <String, String>{
  'person': 'person',
  'box': 'rect',
  'rounded': 'rect',
  'component': 'rect',
  'cylinder': 'cyl',
  'database': 'cyl',
  'db': 'cyl',
  'queue': 'h-cyl',
  'pipe': 'h-cyl',
};

class Node extends Box {
  Node({
    required this.shape,
    required this.labels,
    required this.textH,
    required super.x,
    required super.y,
    required super.w,
    required super.h,
    required super.form,
  });

  final C4Shape shape;
  // Type, name, technology, description.
  final List<Label> labels;
  final double textH;
}

class Group extends Box {
  Group({
    required this.boundary,
    required this.kids,
    required this.nodes,
    required this.labels,
    required this.head,
    required this.headW,
    required this.headX,
    required super.x,
    required super.y,
    required super.w,
    required super.h,
    required super.form,
  });

  final C4Boundary boundary;
  final List<Group> kids;
  final List<Node> nodes;
  // Name, type, description.
  final List<Label> labels;
  final double head;
  final double headW;
  double headX;
}

class Layout {
  const Layout({required this.order, required this.boxes});

  // The boundaries that are drawn, parents before children. The first is the unnamed top level.
  final List<Group> order;
  final Map<C4Element, Box> boxes;
}

String _formOf(C4Shape shape) {
  final explicit =
      _forms[(shape.shape ?? '').toLowerCase()] ??
      _forms[(shape.sprite ?? '').toLowerCase()];
  if (explicit != null) return explicit;
  final tags = shape.tags;
  if (tags != null && tags.isNotEmpty) {
    for (final tag in tags.split(',')) {
      final form = _forms[tag.trim().toLowerCase()];
      if (form != null) return form;
    }
  }
  final kind = shape.kind;
  return kind.endsWith('person')
      ? 'person'
      : kind.endsWith('_db')
      ? 'cyl'
      : kind.endsWith('_queue')
      ? 'h-cyl'
      : 'rect';
}

Node _measure(
  C4Shape shape,
  TextMeasurer measurer,
  double size,
  double small, [
  double width = _shapeW,
]) {
  final form = _formOf(shape);
  final capW = form == 'h-cyl' ? 36.0 : 0.0;
  final capH = form == 'person'
      ? HEAD
      : form == 'cyl'
      ? 24.0
      : 0.0;
  final inner = width - 2 * _padX - capW;
  final techn = shape.techn;
  final labels = <Label>[
    layoutLabel(
      '«${shape.kind.replaceAll('_', ' ')}»',
      false,
      measurer,
      small - 1,
      inner,
    ),
    layoutLabel(shape.label, false, measurer, size, inner, Style.Bold),
    layoutLabel(
      techn != null && techn.isNotEmpty ? '[$techn]' : null,
      false,
      measurer,
      small,
      inner,
    ),
    layoutLabel(shape.descr, false, measurer, small, inner),
  ];
  var tw = 0.0;
  var textH = labels[3].height > 0 ? 4.0 : 0.0;
  for (final label in labels) {
    tw = math.max(tw, label.width);
    textH += label.height;
  }
  return Node(
    shape: shape,
    form: form,
    labels: labels,
    textH: textH,
    x: 0,
    y: 0,
    w: math.max(width, tw + 2 * _padX + capW),
    h: math.max(_shapeMinH, textH + 2 * _padY + capH),
  );
}

// Places boxes left to right in rows of `perRow`, from (0, 0), and returns the width and height the rows take.
// Shapes are stretched to the height of their row; boundaries keep their own.
(double, double) _rows(
  List<Box> boxes,
  int perRow,
  double gapX,
  double gapY,
  bool stretch,
) {
  var width = 0.0;
  var y = 0.0;
  for (var from = 0; from < boxes.length; from += perRow) {
    final to = math.min(boxes.length, from + perRow);
    var x = 0.0;
    var rowH = 0.0;
    for (var i = from; i < to; i++) {
      rowH = math.max(rowH, boxes[i].h);
    }
    for (var i = from; i < to; i++) {
      final box = boxes[i];
      box.x = x;
      box.y = y;
      if (stretch) box.h = rowH;
      x += box.w + gapX;
    }
    width = math.max(width, x - gapX);
    y += rowH + gapY;
  }
  return (width, boxes.isNotEmpty ? y - gapY : 0.0);
}

// Mermaid's grid: in each boundary, its shapes in rows of c4ShapeInRow, then the boundaries inside it
// in rows of c4BoundaryInRow, each sized around its own content.
Layout layoutC4(
  C4Db db,
  TextMeasurer measurer,
  double size,
  double small,
  double? room,
  double gap,
) {
  final groupPad = room == null ? GROUP_PAD : 12.0;
  final groups = <C4Boundary, Group>{};
  for (final boundary in db.boundaries) {
    final labelRoom = room == null
        ? 4000.0
        : math.max(80.0, room - 2 * HEAD_LEFT - 2 * GROUP_PAD * 2);
    final bType = boundary.type;
    final labels = boundary.parent != null
        ? <Label>[
            layoutLabel(
              boundary.label,
              false,
              measurer,
              size,
              labelRoom,
              Style.Bold,
            ),
            layoutLabel(
              bType != null && bType.isNotEmpty ? '[$bType]' : null,
              false,
              measurer,
              small,
              labelRoom,
            ),
            layoutLabel(boundary.descr, false, measurer, small, labelRoom),
          ]
        : <Label>[];
    var head = 0.0;
    var headW = 0.0;
    for (final label in labels) {
      head += label.height;
      headW = math.max(headW, label.width);
    }
    groups[boundary] = Group(
      boundary: boundary,
      kids: <Group>[],
      nodes: <Node>[],
      labels: labels,
      head: head > 0 ? head + HEAD_TOP + 6 + LANE : groupPad,
      headW: headW,
      headX: HEAD_LEFT,
      x: 0,
      y: 0,
      w: 0,
      h: 0,
      form: 'rect',
    );
  }
  final root = groups[db.boundaries[0]]!;
  for (final group in groups.values) {
    final parent = group.boundary.parent;
    if (parent != null) groups[parent]?.kids.add(group);
  }
  // A boundary that ends up inside itself is not reachable from the top, as in Mermaid.
  final order = <Group>[root];
  final depths = <C4Boundary, int>{root.boundary: 0};
  for (var i = 0; i < order.length; i++) {
    for (final kid in order[i].kids) {
      depths[kid.boundary] = depths[order[i].boundary]! + 1;
      order.add(kid);
    }
  }
  for (final shape in db.shapes) {
    final parent = shape.parent;
    if (parent != null) {
      final depth = depths[parent] ?? 0;
      final nodeWidth = room == null
          ? _shapeW
          : math.max(
              100.0,
              math.min(_shapeW, room - 2 * depth * groupPad - 32),
            );
      groups[parent]?.nodes.add(
        _measure(shape, measurer, size, small, nodeWidth),
      );
    }
  }

  final perRow = math.max(1, db.shapeInRow);
  final groupsPerRow = math.max(1, db.boundaryInRow);
  final kidsTop = <Group, double>{};
  for (var i = order.length - 1; i >= 0; i--) {
    final group = order[i];
    final gapX = room == null ? _gapX : gap;
    int count(List<Box> boxes, int limit, double g) {
      if (room == null) return limit;
      var widest = 1.0;
      for (final box in boxes) {
        widest = math.max(widest, box.w);
      }
      return math.max(
        1,
        math.min(limit, ((room + g - 2 * groupPad) / (widest + g)).floor()),
      );
    }

    final (gridW, gridH) = _rows(
      group.nodes,
      count(group.nodes, perRow, gapX),
      gapX,
      _gapY,
      true,
    );
    final (kidsW, kidsH) = _rows(
      group.kids,
      count(group.kids, groupsPerRow, _groupGap),
      _groupGap,
      _groupGap,
      false,
    );
    final between = gridH > 0 && kidsH > 0 ? _groupGap : 0.0;
    final frame = identical(group, root) ? 0.0 : groupPad;
    kidsTop[group] = gridH + between;
    group.w =
        math.max(
          math.max(gridW, kidsW),
          group.headW + 2 * HEAD_LEFT - 2 * frame,
        ) +
        2 * frame;
    group.h = (frame != 0 ? group.head : 0.0) + gridH + between + kidsH + frame;
  }

  final boxes = <C4Element, Box>{};
  for (final group in order) {
    final left = group.x + (identical(group, root) ? 0.0 : groupPad);
    final top = group.y + (identical(group, root) ? 0.0 : group.head);
    for (final node in group.nodes) {
      node.x += left;
      node.y += top;
      boxes[node.shape] = node;
    }
    for (final kid in group.kids) {
      kid.x += left;
      kid.y += top + kidsTop[group]!;
    }
    if (!identical(group, root)) boxes[group.boundary] = group;
  }
  return Layout(order: order, boxes: boxes);
}

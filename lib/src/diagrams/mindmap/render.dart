// Upstream: src/diagrams/mindmap/render.ts

import 'dart:math' as math;
import 'dart:typed_data';

import '../../preprocess.dart';
import '../../svg/builder.dart';
import '../../svg/root.dart';
import '../../svg/shapes.dart';
import '../../svg/theme.dart';
import '../../svg/title.dart';
import '../../text/icons.dart';
import '../../text/label.dart';
import '../../text/measurer.dart';
import '../../types.dart';
import '../../util/math_js.dart';
import '../common/fit_width.dart';
import '../common/icon.dart';
import 'db.dart';

// Indexed by Mermaid's node type. A node without delimiters is text on a line, except the root.
const List<String> _SHAPES = <String>[
  '',
  'rounded',
  'rect',
  'circle',
  'cloud',
  'bang',
  'hex',
];
const String _ROOT_SHAPE = 'stadium';

const double _GAP_X = 36;
const double _GAP_Y = 8;
// Between two subtrees, of which at least one has children of its own.
const double _GROUP_GAP = 18;
const double _BRANCH_GAP_X = 52;
const double _BRANCH_GAP_Y = 28;
const double _TEXT_PAD = 6;
const double _PILL_PAD = 12;
const double _TINT = 0.22;
const double _ICON_GAP = 6;
// Running down, each level is set in by this much, and links leave a node this far from its left edge.
const double _INDENT = 28;
const double _STEM = 12;
const double _BEND = 8;
const double _ROW_GAP = 10;

double? _asDouble(Object? v) =>
    v is double ? v : (v is int ? v.toDouble() : null);

// A label with each line starting at `left`, for an outline, where centered lines would look ragged.
String _leftLabel(Label label, double left, double cy, IconResolver? icons) {
  if (label.lines.length < 2) {
    return labelSvg(
      label,
      left + label.width / 2,
      cy,
      ' class="pele-label"',
      icons,
    );
  }
  final out = StringBuffer();
  final top = cy - label.height / 2;
  for (var k = 0; k < label.lines.length; k++) {
    out.write(
      labelSvg(
        labelLine(label, k),
        left + label.widths[k] / 2,
        top + lineMiddle(label, k),
        ' class="pele-label"',
        icons,
      ),
    );
  }
  return out.toString();
}

Rendered renderMindmap(
  MindmapModel model,
  Config config,
  RenderOptions options,
) {
  return turnToFit(options, (down) => _draw(model, config, options, down));
}

// `down` draws the map as an outline: the root at the top, and each level set in under its parent.
// It is far narrower than branches spreading to both sides, and as tall as it needs to be.
Rendered _draw(
  MindmapModel model,
  Config config,
  RenderOptions options,
  bool down,
) {
  final size = options.fontSize ?? 16;
  final measurer =
      options.measurer ??
      defaultMeasurer(options.fontFamily, options.fontFamilyMono);
  final pad = options.padding ?? 8;
  final icons = options.icons;
  final mindmapCfg = config['mindmap'];
  final maxNodeWidth = _asDouble(
    mindmapCfg is Map ? mindmapCfg['maxNodeWidth'] : null,
  );
  final wrap = maxNodeWidth != null && maxNodeWidth > 0
      ? math.min(maxNodeWidth, 2000.0)
      : 200.0;
  final glyph = size * 1.25;

  final nodes = model.nodes;
  final n = nodes.length;
  final parent = Int32List(n);
  final depth = Int32List(n);
  for (var i = 0; i < n; i++) {
    for (final child in nodes[i].children) {
      parent[child.id] = i;
      depth[child.id] = depth[i] + 1;
    }
  }
  // An outline has the width the host gives it, less what its level is set in.
  final room = down && options.maxWidth != null && options.maxWidth! > 0
      ? options.maxWidth! - 2 * pad
      : double.infinity;
  final labels = List<Label?>.filled(n, null);
  final shapes = List<String>.filled(n, '');
  final w = Float64List(n);
  final h = Float64List(n);
  final dy = Float64List(n);
  // Where links meet the node, measured down from its top: its middle.
  final anchor = Float64List(n);
  // Whether the host has the node's icon. One it does not have takes no room.
  final drawn = Uint8List(n);

  for (var i = 0; i < n; i++) {
    final node = nodes[i];
    drawn[i] = node.icon != null && iconMarkup(node.icon!).isNotEmpty ? 1 : 0;
    final fit = math.min(
      wrap,
      math.max(
        72.0,
        room -
            depth[i] * _INDENT -
            2 * _TEXT_PAD -
            (drawn[i] != 0 ? glyph + _ICON_GAP : 0),
      ),
    );
    final label = layoutLabel(node.descr, true, measurer, size, fit);
    labels[i] = label;
    final tw =
        label.width +
        (drawn[i] != 0 ? glyph + (label.width > 0 ? _ICON_GAP : 0) : 0);
    final th = math.max(label.height, roundJs(size * 1.5).toDouble());
    var shape = (node.type >= 0 && node.type < _SHAPES.length)
        ? _SHAPES[node.type]
        : '';
    if (shape.isEmpty && i == 0) shape = _ROOT_SHAPE;
    // In an outline the root heads a column, and the trunk drops from under its left end. A circle
    // or a cloud would stand wide of that, so the root is a pill there unless it is a box already.
    if (down && i == 0 && shape != 'rect' && shape != 'rounded') {
      shape = _ROOT_SHAPE;
    }
    shapes[i] = shape;
    if (shape.isEmpty) {
      // A node with no shape of its own is plain text when it ends a branch, and text in a
      // tinted pill when the branch goes on from it, which sets the levels apart.
      final pill = node.children.isNotEmpty;
      w[i] = tw + 2 * (pill ? _PILL_PAD : _TEXT_PAD);
      h[i] = th + (pill ? 6 : 0);
      anchor[i] = h[i] / 2;
    } else {
      final s = shapeSize(shape, tw, th);
      w[i] = s.w;
      h[i] = s.h;
      dy[i] = s.dy;
      anchor[i] = s.h / 2;
    }
  }

  // Each subtree takes a band of height `extent`. `rel` is a subtree's offset among its siblings,
  // `own` the node's offset inside its band, and `kids` the offset of its children's bands.
  final extent = Float64List(n);
  final rel = Float64List(n);
  final own = Float64List(n);
  final kids = Float64List(n);
  var stacked = 0.0;

  // Stacks subtrees top to bottom and returns the height at which their parent's anchor belongs.
  double stack(List<MindmapNode> list, int from, int to, double gap) {
    var y = 0.0;
    var last = 0.0;
    for (var k = from; k < to; k++) {
      final c = list[k].id;
      rel[c] = y;
      final grouped =
          list[k].children.isNotEmpty ||
          (k + 1 < to && list[k + 1].children.isNotEmpty);
      last = grouped ? math.max(gap, _GROUP_GAP) : gap;
      y += extent[c] + last;
    }
    stacked = y - last;
    final a = list[from].id;
    final b = list[to - 1].id;
    return (rel[a] + own[a] + anchor[a] + rel[b] + own[b] + anchor[b]) / 2;
  }

  // Nodes are in depth-first order, so going backwards visits children before their parent.
  for (var i = n - 1; i > 0; i--) {
    final children = nodes[i].children;
    if (children.isEmpty) {
      extent[i] = h[i];
      continue;
    }
    final top = stack(children, 0, children.length, _GAP_Y) - anchor[i];
    final low = math.min(0.0, top);
    extent[i] = math.max(stacked, top + h[i]) - low;
    own[i] = top - low;
    kids[i] = -low;
  }

  final x = Float64List(n);
  final y = Float64List(n);
  final band = Float64List(n);
  final side = Int8List(n);
  // Running down: how far the trunk under each node has been drawn.
  final trunk = Float64List(n);

  if (down) {
    // Nodes are in depth-first order, which is the order of an outline's rows.
    var row = 0.0;
    for (var i = 0; i < n; i++) {
      if (i > 0 && parent[i] == 0) row += _ROW_GAP;
      x[i] = depth[i] * _INDENT + w[i] / 2;
      y[i] = row;
      row += h[i] + _ROW_GAP;
    }
  } else if (n > 0) {
    // The first branches go right and the rest left, split where the two sides are closest in height.
    final branches = nodes[0].children;
    final count = branches.length;
    var total = 0.0;
    for (final branch in branches) {
      total += extent[branch.id];
    }
    var split = count;
    var best = double.infinity;
    var right = 0.0;
    for (var k = 1; k < count; k++) {
      right += extent[branches[k - 1].id];
      final diff = (2 * right - total + (2 * k - count) * _BRANCH_GAP_Y).abs();
      if (diff < best) {
        best = diff;
        split = k;
      }
    }
    for (
      var from = 0, to = split, dir = 1;
      from < count;
      from = to, to = count, dir = -1
    ) {
      final middle = stack(branches, from, to, _BRANCH_GAP_Y);
      for (var k = from; k < to; k++) {
        final c = branches[k].id;
        band[c] = rel[c] - middle;
        side[c] = dir;
      }
    }
    y[0] = -h[0] / 2;
    for (var i = 0; i < n; i++) {
      if (i > 0) y[i] = band[i] + own[i];
      for (final child in nodes[i].children) {
        final c = child.id;
        if (i > 0) {
          side[c] = side[i];
          band[c] = band[i] + kids[i] + rel[c];
        }
        x[c] =
            x[i] +
            side[c] * (w[i] / 2 + (i > 0 ? _GAP_X : _BRANCH_GAP_X) + w[c] / 2);
      }
    }
  }

  var minX = 0.0;
  var maxX = 0.0;
  var minY = 0.0;
  var maxY = 0.0;
  final out = StringBuffer();
  final edges = StringBuffer();
  final body = StringBuffer();
  var color = '';
  void flush(int? section) {
    if (body.isEmpty) return;
    out
      ..write('<g class="pele-branch pele-section-${section ?? 0}">')
      ..write(
        '<g class="pele-edges" fill="none" stroke="$color" stroke-width="1.5">$edges</g>$body</g>',
      );
    edges.clear();
    body.clear();
  }

  // The root is drawn last, on top of the links that leave it.
  for (var k = 1; k <= n; k++) {
    final i = k % n;
    final node = nodes[i];
    final shape = shapes[i];
    final label = labels[i]!;
    final cx = x[i];
    final top = y[i];
    minX = math.min(minX, cx - w[i] / 2);
    maxX = math.max(maxX, cx + w[i] / 2);
    minY = math.min(minY, top);
    maxY = math.max(maxY, top + h[i]);

    if (i == 0 || parent[i] == 0) flush(nodes[k - 1].section);
    if (i > 0 && down) {
      if (parent[i] == 0) color = seriesColor(node.section ?? 0);
      final p = parent[i];
      // The link drops from under its parent and turns in to the node's left. It starts where
      // the link to the sibling above turned in, so each stretch of a shared trunk has one color.
      // Under the root's rounded end, the trunk starts where that end has come down to the bottom.
      final stem = p == 0
          ? math.min(math.max(_STEM, h[0] / 2), _INDENT - _BEND)
          : _STEM;
      final x1 = x[p] - w[p] / 2 + math.min(stem, w[p] / 2);
      final y1 = trunk[p] != 0 ? trunk[p] : y[p] + h[p];
      final left = cx - w[i] / 2;
      final x2 =
          left + (shape.isNotEmpty ? shapeInset(shape, w[i], h[i], 3) : 0);
      final y2 = top + anchor[i];
      final bend = math.max(0.0, math.min(_BEND, math.min(x2 - x1, y2 - y1)));
      // The next link carries on from where this one leaves the trunk, so the trunk has no gap.
      trunk[p] = y2 - bend;
      edges.write(
        '<path class="pele-edge" d="M${num(x1)},${num(y1)}V${num(y2 - bend)}Q${num(x1)},${num(y2)} ${num(x1 + bend)},${num(y2)}H${num(x2)}"/>',
      );
    } else if (i > 0) {
      if (parent[i] == 0) color = seriesColor(node.section ?? 0);
      final p = parent[i];
      final dir = side[i];
      final from = dir > 0 ? 1 : 3;
      final x1 =
          x[p] +
          dir *
              (w[p] / 2 -
                  (shapes[p].isNotEmpty
                      ? shapeInset(shapes[p], w[p], h[p], from)
                      : 0));
      final y1 = y[p] + anchor[p];
      final near = cx - (dir * w[i]) / 2;
      final x2 =
          near +
          (shape.isNotEmpty
              ? dir * shapeInset(shape, w[i], h[i], 4 - from)
              : 0);
      final y2 = top + anchor[i];
      final mid = num((x1 + x2) / 2);
      edges.write(
        '<path class="pele-edge" d="M${num(x1)},${num(y1)}C$mid,${num(y1)} $mid,${num(y2)} ${num(x2)},${num(y2)}"/>',
      );
    }

    final pill = shape.isEmpty && node.children.isNotEmpty;
    // Every node off the root is filled with a tint of its branch's color and outlined in it,
    // whether its shape was given in the source or is the pill of a node that branches.
    // The root is neutral.
    final tint = ' fill="$color" fill-opacity="$_TINT" stroke="$color"';
    var inner = '';
    if (shape.isNotEmpty) {
      inner = i > 0
          ? drawShape(shape, w[i], h[i], tint, ' stroke="$color"')
          : drawShape(
              shape,
              w[i],
              h[i],
              ' fill="var(--_s)" stroke="var(--_b)"',
              ' stroke="var(--_b)"',
            );
    } else if (pill) {
      inner =
          '<rect x="${num(-w[i] / 2)}" y="${num(-h[i] / 2)}" width="${num(w[i])}" height="${num(h[i])}" rx="${num(h[i] / 2)}"$tint/>';
    }
    var shift = 0.0;
    if (node.icon != null && node.icon!.isNotEmpty && drawn[i] != 0) {
      shift = (glyph + (label.width > 0 ? _ICON_GAP : 0)) / 2;
      inner += iconSvg(
        node.icon!,
        -shift - label.width / 2,
        dy[i] - glyph / 2,
        glyph,
        icons,
      );
    }
    final shapeClass = shape.isNotEmpty ? shape : (pill ? 'branch' : 'text');
    final group =
        '<g class="pele-node pele-shape-$shapeClass${i > 0 ? '' : ' pele-root'}${classNames(node.className ?? '')}" data-id="${escText(node.nodeId)}" transform="translate(${num(cx)},${num(top + h[i] / 2)})">'
        '$inner'
        '${down && shape.isEmpty ? _leftLabel(label, shift - label.width / 2, dy[i], icons) : labelSvg(label, shift, dy[i], ' class="pele-label"', icons)}'
        '</g>';
    if (i > 0) {
      body.write(group);
    } else {
      out.write(group);
    }
  }

  final title = titleLabel(model.title, measurer, size, titleRoom(options));
  final titleHeight = title.height > 0 ? title.height + 16 : 0.0;
  final width = math.max(maxX - minX, title.width);
  final totalWidth = (width + 2 * pad).ceilToDouble();
  final totalHeight = (maxY - minY + titleHeight + 2 * pad).ceilToDouble();
  final content =
      labelSvg(
        title,
        totalWidth / 2,
        pad + title.height / 2,
        ' class="pele-title" font-weight="var(--_tw)"',
      ) +
      '<g transform="translate(${num(pad - minX + (width - maxX + minX) / 2)},${num(pad + titleHeight - minY)})">$out</g>';

  return Rendered(
    svg: svgDocument(
      'mindmap',
      totalWidth,
      totalHeight,
      size,
      options,
      null,
      content,
    ),
    width: totalWidth,
    height: totalHeight,
    links: <LinkInfo>[],
  );
}

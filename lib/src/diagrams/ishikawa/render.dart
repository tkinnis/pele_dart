// Upstream: src/diagrams/ishikawa/render.ts

import 'dart:math' as math;

import '../../preprocess.dart';
import '../../svg/builder.dart';
import '../../svg/edges.dart';
import '../../svg/root.dart';
import '../../svg/theme.dart';
import '../../text/label.dart';
import '../../text/measurer.dart';
import '../../types.dart';
import '../../util/math_js.dart';
import '../common/fit_width.dart';
import '../common/literal_label.dart';
import 'types.dart';

// How far a bone moves toward the tail for each unit it rises from the spine.
const double _slant = 0.5;
final double _length = hypot(_slant, 1);
const double _firstRow = 14;
const double _rowGap = 6;
const double _boneEnd = 8;
const double _twigStep = 22;
const double _stub = 18;
const double _textGap = 5;
const double _pairGap = 26;
const double _headGap = 34;
const double _tail = 28;
const double _boxPadX = 10;
const double _boxPadY = 5;

// A cause below a category. Bones at even depths run level, from the slanted bone above them
// toward the tail; bones at odd depths slant away from the spine, from the level bone above them.
class _Bone {
  final Label label;
  final int depth;
  final int parent;
  // Its place among its siblings, counted from the spine outward.
  final int slot;
  final int kids;
  // How far its row is from the spine.
  double rise = 0;
  // Where it meets its parent, measured level from the category's bone: 0 on it, negative toward the tail.
  double at = 0;
  // Where its text ends.
  double textEnd = 0;

  _Bone({
    required this.label,
    required this.depth,
    required this.parent,
    required this.slot,
    required this.kids,
  });
}

class _Category {
  final IshikawaNode node;
  final Label label;
  final double boxW;
  final double boxH;
  final List<_Bone> bones;
  // The length of its bone, as distance from the spine.
  double rise;
  // How far its causes reach toward the tail, measured level from its bone.
  final double reach;

  _Category({
    required this.node,
    required this.label,
    required this.boxW,
    required this.boxH,
    required this.bones,
    required this.rise,
    required this.reach,
  });
}

class _Frame {
  final IshikawaNode node;
  final int depth;
  final int parent;
  final int slot;
  // Set when the bone was made and only its row is still to come.
  int bone;

  _Frame({
    required this.node,
    required this.depth,
    required this.parent,
    required this.slot,
    required this.bone,
  });
}

// Gives every cause of a category a row of its own, so that no two texts can meet, and measures
// how far the whole of it reaches. A level bone takes the row nearest the spine and its twigs the
// rows beyond; a slanted twig takes the row beyond everything that hangs off it. The outline may
// be nested as deep as its indentation goes, so the walk keeps a stack of its own.
_Category _arrange(
  IshikawaNode node,
  bool up,
  TextMeasurer measurer,
  double size,
  double small,
) {
  final label = layoutLabel(node.text, false, measurer, size, 180);
  final lineHeight = roundJs(small * 1.5).toDouble();
  final bones = <_Bone>[];
  final rows = <int>[];
  final stack = <_Frame>[];
  // Above the spine the first cause goes farthest out, so that the causes read from the top down.
  void push(List<IshikawaNode> children, int depth, int parent) {
    final n = children.length;
    for (var slot = n - 1; slot >= 0; slot--) {
      stack.add(
        _Frame(
          node: children[up ? n - 1 - slot : slot],
          depth: depth,
          parent: parent,
          slot: slot,
          bone: -1,
        ),
      );
    }
  }

  push(node.children, 2, -1);
  while (stack.isNotEmpty) {
    final frame = stack.removeLast();
    if (frame.bone != -1) {
      rows.add(frame.bone);
      continue;
    }
    final index = bones.length;
    bones.add(
      _Bone(
        label: layoutLabel(frame.node.text, false, measurer, small, 200),
        depth: frame.depth,
        parent: frame.parent,
        slot: frame.slot,
        kids: frame.node.children.length,
      ),
    );
    if (frame.depth % 2 == 0) {
      rows.add(index);
    } else {
      frame.bone = index;
      stack.add(frame);
    }
    push(frame.node.children, frame.depth + 1, index);
  }

  var rise = _firstRow;
  for (final index in rows) {
    final height = math.max(bones[index].label.height, lineHeight) + _rowGap;
    bones[index].rise = rise + height / 2;
    rise += height;
  }
  final boxW = label.width + 2 * _boxPadX;
  var reach = boxW / 2;
  for (final bone in bones) {
    final parent = bone.parent == -1 ? null : bones[bone.parent];
    if (bone.depth % 2 == 0) {
      bone.at = parent != null ? parent.at : 0;
      bone.textEnd =
          bone.at -
          (bone.kids > 0 ? (bone.kids + 1) * _twigStep : _stub) -
          _textGap;
    } else {
      // Twigs stand along their level bone, the one nearest the spine nearest the tail.
      bone.at = parent!.at - (parent.kids - bone.slot) * _twigStep;
      bone.textEnd = bone.at - _textGap;
    }
    reach = math.max(reach, bone.label.width - bone.textEnd);
  }
  return _Category(
    node: node,
    label: label,
    boxW: boxW,
    boxH: label.height + 2 * _boxPadY,
    bones: bones,
    rise: rise + _boneEnd,
    reach: reach,
  );
}

Rendered renderIshikawa(
  IshikawaModel model,
  Config config,
  RenderOptions options,
) {
  return turnToFit(options, (down) => _draw(model, config, options, down));
}

Rendered _draw(
  IshikawaModel model,
  Config config,
  RenderOptions options,
  bool down,
) {
  final size = options.fontSize ?? 16;
  final small = roundJs(size * 0.875).toDouble();
  final measurer =
      options.measurer ??
      defaultMeasurer(options.fontFamily, options.fontFamilyMono);
  final pad = options.padding ?? 8;
  if (down) return _verticalCauses(model, options);
  final root = model.root;
  final title = layoutLabel(
    model.title,
    false,
    measurer,
    size,
    4000,
    Style.Bold,
  );
  final titleHeight = title.height > 0 ? title.height + 12 : 0.0;

  var body = '';
  var minX = 0.0;
  var maxX = 0.0;
  var minY = 0.0;
  var maxY = 0.0;
  if (root != null) {
    final head = layoutLabel(root.text, false, measurer, size, 200, Style.Bold);
    final headH = math.max(head.height + 24, 48.0);
    final headW = head.width + 24 + headH / 2;
    final categories = <_Category>[
      for (var i = 0; i < root.children.length; i++)
        _arrange(root.children[i], i % 2 == 0, measurer, size, small),
    ];
    // Even a category without causes has a bone long enough to carry its name clear of the head.
    for (final category in categories) {
      category.rise = math.max(category.rise, headH / 2 + 14);
    }

    // Categories meet the spine in pairs, one above and one below, each pair as far toward the
    // tail from the one before as the wider of the two needs.
    final xs = <double>[];
    var x = -_headGap;
    for (var i = 0; i < categories.length; i += 2) {
      if (i > 0) {
        var room = 0.0;
        for (var side = 0; side < 2; side++) {
          final beforeIdx = i - 2 + side;
          final nextIdx = i + side;
          final before = beforeIdx < categories.length
              ? categories[beforeIdx]
              : null;
          final next = nextIdx < categories.length ? categories[nextIdx] : null;
          if (before != null) {
            room = math.max(
              room,
              before.reach + (next != null ? next.boxW / 2 : 0),
            );
          }
        }
        x -= room + _pairGap;
      }
      xs.addAll(<double>[x, x]);
    }
    final tail = categories.isNotEmpty ? x - _tail : -_headGap;

    maxX = headW;
    minX = tail;
    minY = -headH / 2;
    maxY = headH / 2;
    final groups = StringBuffer();
    for (var i = 0; i < categories.length; i++) {
      final category = categories[i];
      final sign = i % 2 == 0 ? -1.0 : 1.0;
      final ax = xs[i];
      double px(double at, double rise) => ax + at - rise * _slant;
      final endX = px(0, category.rise);
      final endY = sign * category.rise;
      // The bone stops short of the spine to leave its arrowhead a clean point.
      const trim = ARROW - 1;
      final d = StringBuffer(
        'M${num(ax - (_slant / _length) * trim)},${num((sign * trim) / _length)}L${num(endX)},${num(endY)}',
      );
      final texts = StringBuffer();
      for (final bone in category.bones) {
        final y = sign * bone.rise;
        if (bone.depth % 2 == 0) {
          d.write(
            'M${num(px(bone.at, bone.rise))},${num(y)}H${num(px(bone.textEnd + _textGap, bone.rise))}',
          );
        } else {
          final from = category.bones[bone.parent].rise;
          d.write(
            'M${num(px(bone.at, from))},${num(sign * from)}L${num(px(bone.at, bone.rise))},${num(y)}',
          );
        }
        final right = px(bone.textEnd, bone.rise);
        texts.write(
          labelSvg(
            bone.label,
            right - bone.label.width / 2,
            y,
            bone.depth > 2 ? ' fill="var(--_m)"' : '',
          ),
        );
        minX = math.min(minX, right - bone.label.width);
      }
      final boxY = endY + sign * (category.boxH / 2);
      minX = math.min(minX, endX - category.boxW / 2);
      maxX = math.max(maxX, endX + category.boxW / 2);
      minY = math.min(minY, boxY - category.boxH / 2);
      maxY = math.max(maxY, boxY + category.boxH / 2);
      final textsStr = texts.toString();
      groups
        ..write(
          '<g class="pele-ishikawa-category" data-id="${escText(category.node.text)}">',
        )
        ..write(
          '<path class="pele-ishikawa-bones" d="$d" fill="none" stroke="var(--_l)"/>',
        )
        ..write(
          marker(
            'arrow_point',
            ax,
            0,
            _slant / _length,
            -sign / _length,
            'var(--_l)',
          ),
        )
        ..write(
          '<rect x="${num(endX - category.boxW / 2)}" y="${num(boxY - category.boxH / 2)}" width="${num(category.boxW)}" height="${num(category.boxH)}" fill="var(--_s)" stroke="var(--_b)"$roundedAttr/>',
        )
        ..write(labelSvg(category.label, endX, boxY, ' class="pele-label"'))
        ..write(
          textsStr.isNotEmpty
              ? '<g class="pele-ishikawa-causes" font-size="${num(small)}">$textsStr</g>'
              : '',
        )
        ..write('</g>');
    }

    final r = headH / 2;
    body =
        '<path class="pele-ishikawa-spine" d="M${num(tail)},0H${num(-(ARROW - 1))}" fill="none" stroke="var(--_l)"/>'
        '${marker('arrow_point', 0, 0, 1, 0, 'var(--_l)')}'
        '$groups'
        '<g class="pele-ishikawa-head" data-id="${escText(root.text)}">'
        '<path d="M0,${num(-r)}H${num(headW - r)}A${num(r)},${num(r)} 0 0 1 ${num(headW - r)},${num(r)}H0Z" fill="var(--_s)" stroke="var(--_b)" stroke-linejoin="round"/>'
        '${labelSvg(head, 12 + head.width / 2, 0, ' class="pele-label" font-weight="var(--_hw)"')}'
        '</g>';
  }

  final inner = math.max(maxX - minX, title.width);
  final width = (inner + 2 * pad).ceilToDouble();
  final height = (maxY - minY + titleHeight + 2 * pad).ceilToDouble();
  final ox = pad + (inner - (maxX - minX)) / 2 - minX;
  final oy = pad + titleHeight - minY;
  final svg = svgDocument(
    'ishikawa',
    width,
    height,
    size,
    options,
    const Accessible(),
    labelSvg(
          title,
          width / 2,
          pad + title.height / 2,
          ' class="pele-title" font-weight="var(--_tw)"',
        ) +
        (body.isNotEmpty
            ? '<g transform="translate(${num(ox)},${num(oy)})">$body</g>'
            : ''),
  );
  return Rendered(svg: svg, width: width, height: height, links: <LinkInfo>[]);
}

class _VerticalEntry {
  final IshikawaNode node;
  final int depth;
  final int parent;
  double x = 0;
  double y = 0;
  double w = 0;
  double h = 0;
  Label? label;

  _VerticalEntry({
    required this.node,
    required this.depth,
    required this.parent,
  });
}

Rendered _verticalCauses(IshikawaModel model, RenderOptions options) {
  final size = options.fontSize ?? 16;
  final small = roundJs(size * 0.875).toDouble();
  final measurer =
      options.measurer ??
      defaultMeasurer(options.fontFamily, options.fontFamilyMono);
  final pad = options.padding ?? 8;
  final room = math.max(140.0, (options.maxWidth ?? 320) - 2 * pad);
  final title = layoutLabel(
    model.title,
    false,
    measurer,
    size,
    titleRoom(options),
    Style.Bold,
  );
  final order = <_VerticalEntry>[];
  final pending = model.root != null
      ? <({IshikawaNode node, int depth, int parent})>[
          (node: model.root!, depth: 0, parent: -1),
        ]
      : <({IshikawaNode node, int depth, int parent})>[];
  var depth = 0;
  while (pending.isNotEmpty) {
    final entry = pending.removeLast();
    final index = order.length;
    order.add(
      _VerticalEntry(
        node: entry.node,
        depth: entry.depth,
        parent: entry.parent,
      ),
    );
    depth = math.max<int>(depth, entry.depth);
    for (var i = entry.node.children.length - 1; i >= 0; i--) {
      pending.add((
        node: entry.node.children[i],
        depth: entry.depth + 1,
        parent: index,
      ));
    }
  }
  final indent = math.min(
    20.0,
    math.max(2.0, (room - 120) / math.max<int>(1, depth)),
  );
  var y = pad + (title.height > 0 ? title.height + 12 : 0);
  var width = title.width;
  final nodes = StringBuffer();
  final edges = StringBuffer();
  for (final entry in order) {
    entry.x = pad + entry.depth * indent;
    final labelRoom = math.max(60.0, room - entry.depth * indent - 20);
    entry.label = breakLabel(
      layoutLabel(
        entry.node.text,
        false,
        measurer,
        entry.depth < 2 ? size : small,
        labelRoom,
        entry.depth < 2 ? Style.Bold : 0,
      ),
      measurer,
      labelRoom,
    );
    entry.w = entry.label!.width + 20;
    entry.h = entry.label!.height + 12;
    entry.y = y;
    y += entry.h + 12;
    width = math.max(width, entry.x - pad + entry.w);
    final framed = entry.depth < 2;
    final cls = entry.depth == 0
        ? 'pele-ishikawa-head'
        : entry.depth == 1
        ? 'pele-ishikawa-category'
        : 'pele-ishikawa-cause';
    nodes
      ..write(
        '<g class="pele-node $cls" data-id="${escText(entry.node.text)}">',
      )
      ..write(
        framed
            ? '<rect x="${num(entry.x)}" y="${num(entry.y)}" width="${num(entry.w)}" height="${num(entry.h)}" rx="${entry.depth == 0 ? 12 : 4}" fill="var(--_s)" stroke="var(--_b)"/>'
            : '',
      )
      ..write(
        labelSvg(
          entry.label!,
          entry.x + entry.w / 2,
          entry.y + entry.h / 2,
          ' class="pele-label"${entry.depth < 2 ? ' font-weight="var(--_hw)"' : ''}${entry.depth > 1 ? ' font-size="${num(small)}"' : ''}',
        ),
      )
      ..write('</g>');
    if (entry.parent >= 0) {
      final parent = order[entry.parent];
      final gx = parent.x + indent / 2;
      edges.write(
        '<path class="pele-edge" d="M${num(gx)},${num(parent.y + parent.h)}V${num(entry.y + entry.h / 2)}H${num(entry.x)}" fill="none" stroke="var(--_b)"/>',
      );
    }
  }
  final totalWidth = (width + 2 * pad).ceilToDouble();
  final height = (math.max(pad + title.height, y - 12) + pad).ceilToDouble();
  final content =
      labelSvg(
        title,
        totalWidth / 2,
        pad + title.height / 2,
        ' class="pele-title" font-weight="var(--_tw)"',
      ) +
      edges.toString() +
      nodes.toString();
  return Rendered(
    svg: svgDocument(
      'ishikawa',
      totalWidth,
      height,
      size,
      options,
      const Accessible(),
      content,
    ),
    width: totalWidth,
    height: height,
    links: <LinkInfo>[],
  );
}

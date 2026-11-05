// Upstream: src/diagrams/treeview/render.ts

import 'dart:math' as math;

import '../../preprocess.dart';
import '../../svg/builder.dart';
import '../../svg/root.dart';
import '../../svg/theme.dart';
import '../../text/entities.dart';
import '../../text/label.dart';
import '../../text/measurer.dart';
import '../../types.dart';
import '../../util/math_js.dart';
import '../common/fit_width.dart';
import '../common/literal_label.dart';
import 'icons.dart';
import 'model.dart';

const double _iconGap = 6;
const double _descGap = 16;
const double _guideInset = 7;
const double _elbow = 4;
const double _highlightOverhang = 4;

double _setting(
  Config config,
  String key,
  double fallback,
  double min,
  double max,
) {
  final section = config['treeView'];
  final value = section is Map ? section[key] : null;
  if (value is int && value >= min && value <= max) return value.toDouble();
  if (value is double && value >= min && value <= max) return value;
  return fallback;
}

class TreeSettings {
  final double paddingX;
  final double paddingY;
  final double rowIndent;
  final double lineThickness;

  const TreeSettings({
    required this.paddingX,
    required this.paddingY,
    required this.rowIndent,
    required this.lineThickness,
  });
}

// Mermaid's layout options, with Pele's defaults.
TreeSettings treeSettings(Config config) {
  return TreeSettings(
    paddingX: _setting(config, 'paddingX', 5, 0, 100),
    paddingY: _setting(config, 'paddingY', 2, 0, 100),
    rowIndent: _setting(config, 'rowIndent', 15, 0, 400),
    lineThickness: _setting(config, 'lineThickness', 1, 0.25, 12),
  );
}

class _Row {
  final TreeNode node;
  final double x;
  final double cy;
  final String? icon;
  final String text;
  final double labelX;
  final bool highlighted;
  final Label? label;
  final Label? description;
  final double top;
  final double height;

  const _Row({
    required this.node,
    required this.x,
    required this.cy,
    required this.icon,
    required this.text,
    required this.labelX,
    required this.highlighted,
    this.label,
    this.description,
    required this.top,
    required this.height,
  });
}

final RegExp _wsRe = RegExp(r'\s+');

Rendered renderTreeView(
  TreeViewModel model,
  Config config,
  RenderOptions options,
) {
  return tighten(options, (tight) => _draw(model, config, options, tight));
}

Rendered _draw(
  TreeViewModel model,
  Config config,
  RenderOptions options,
  bool tight,
) {
  final size = options.fontSize ?? 16;
  final measurer =
      options.measurer ??
      defaultMeasurer(options.fontFamily, options.fontFamilyMono);
  final pad = options.padding ?? 8;
  final icons = iconConfig(config);
  final mono =
      options.monospace != null && options.monospace!.contains('files');
  final family = mono ? ' font-family="$fontMono"' : '';

  final settings = treeSettings(config);
  final paddingX = settings.paddingX;
  final paddingY = settings.paddingY;
  final rowIndent = settings.rowIndent;
  final lineThickness = settings.lineThickness;
  var maxDepth = 0;
  final depths = <(TreeNode, int)>[
    for (final node in model.root.children) (node, 0),
  ];
  for (var i = 0; tight && i < depths.length; i++) {
    final (node, depth) = depths[i];
    maxDepth = math.max(maxDepth, depth);
    for (final child in node.children) {
      depths.add((child, depth + 1));
    }
  }
  final step = tight
      ? math.min(
          rowIndent + paddingX,
          math.max(
            2.0,
            ((options.maxWidth ?? 320) - 120) / math.max(1, maxDepth),
          ),
        )
      : rowIndent + paddingX;
  final rowHeight = roundJs(size * 1.5) + 2 * paddingY;
  final iconSize = size;

  final title = layoutLabel(
    model.title,
    false,
    measurer,
    size,
    tight ? titleRoom(options) : 4000,
    Style.Bold,
  );
  final titleHeight = title.height > 0 ? title.height + 12 : 0.0;

  // Siblings line up: when one entry of a folder has an icon, the others leave room for one.
  bool hasIcon(List<TreeNode> list) =>
      list.any((child) => getNodeIcon(child, icons) != null);
  final rows = <_Row>[];
  final rowOf = <TreeNode, _Row>{};
  final pending = <(TreeNode, int, bool)>[];
  void push(List<TreeNode> list, int depth) {
    final slot = hasIcon(list);
    for (var i = list.length - 1; i >= 0; i--) {
      pending.add((list[i], depth, slot));
    }
  }

  push(model.root.children, 0);
  var labelRight = 0.0;
  var anyHighlight = false;
  var rowsHeight = 0.0;
  while (pending.isNotEmpty) {
    final (node, depth, slot) = pending.removeLast();
    final x = depth * step;
    final text = decodeEntities(node.name);
    final labelX = x + (slot ? iconSize + _iconGap : 0);
    final room = math.max(
      40.0,
      (options.maxWidth ?? 320) - 2 * pad - 2 * _highlightOverhang - labelX,
    );
    final style =
        (node.nodeType == 'directory' ? Style.Bold : 0) |
        (mono ? Style.Mono : 0);
    final label = tight
        ? literalLabel(text, measurer, size, room, style)
        : null;
    final description =
        tight && node.description != null && node.description!.isNotEmpty
        ? literalLabel(
            decodeEntities(node.description!),
            measurer,
            size,
            room,
            Style.Italic,
          )
        : null;
    final width = label != null
        ? label.width
        : measurer.width(text, size, style);
    if (labelX + width > labelRight) labelRight = labelX + width;
    final highlighted =
        node.cssClass != null &&
        node.cssClass!.split(_wsRe).contains('highlight');
    if (highlighted) anyHighlight = true;
    final height = tight
        ? math.max(
            rowHeight,
            (label?.height ?? 0) + (description?.height ?? 0) + 2 * paddingY,
          )
        : rowHeight;
    final cy =
        rowsHeight +
        (tight
            ? paddingY + math.max(iconSize, label?.height ?? 0) / 2
            : height / 2);
    final row = _Row(
      node: node,
      x: x,
      cy: cy,
      icon: getNodeIcon(node, icons),
      text: text,
      labelX: labelX,
      highlighted: highlighted,
      label: label,
      description: description,
      top: rowsHeight,
      height: height,
    );
    rowsHeight += height;
    rows.add(row);
    rowOf[node] = row;
    push(node.children, depth + 1);
  }

  final descX = labelRight + _descGap;
  var width = labelRight;
  for (final row in rows) {
    final description = row.node.description;
    if (description == null || description.isEmpty) continue;
    final w = row.description != null
        ? row.description!.width
        : measurer.width(decodeEntities(description), size, Style.Italic);
    width = math.max(width, (tight ? row.labelX : descX) + w);
  }
  width = math.max(width, title.width);
  final inset = pad + (anyHighlight ? _highlightOverhang : 0);
  final top = pad + titleHeight;
  final totalWidth = (width + 2 * inset).ceilToDouble();
  final totalHeight = (top + rowsHeight + pad).ceilToDouble();

  final guides = StringBuffer();
  for (final row in rows) {
    final children = row.node.children;
    if (children.isEmpty) continue;
    final gx = inset + row.x + _guideInset;
    final tick = math.max(gx, inset + row.x + step - paddingX);
    final last = top + rowOf[children.last]!.cy;
    final r = math.min(_elbow, tick - gx);
    final d = StringBuffer(
      'M${num(gx)},${num(top + row.top + row.height - 2)}V${num(last - r)}',
    );
    if (r > 0) {
      d.write(
        'Q${num(gx)},${num(last)} ${num(gx + r)},${num(last)}H${num(tick)}',
      );
    }
    for (var i = 0; i < children.length - 1 && tick > gx; i++) {
      d.write('M${num(gx)},${num(top + rowOf[children[i]]!.cy)}H${num(tick)}');
    }
    guides.write('<path d="$d"/>');
  }

  final baseline = size * 0.35;
  final body = StringBuffer();
  for (final row in rows) {
    final node = row.node;
    final cy = top + row.cy;
    final directory = node.nodeType == 'directory';
    final inner = StringBuffer();
    if (row.highlighted) {
      final x = inset + row.x - _highlightOverhang;
      inner.write(
        '<rect class="pele-tree-highlight" x="${num(x)}" y="${num(top + row.top + 1)}" width="${num(totalWidth - inset + _highlightOverhang - x)}" height="${num(row.height - 2)}" fill="var(--_c)" fill-opacity="0.14"$roundedAttr/>',
      );
    }
    if (row.icon != null) {
      final iconStr = row.icon!;
      final name = iconStr.startsWith('$BUILTIN_PACK:')
          ? iconStr.substring(BUILTIN_PACK.length + 1)
          : '';
      final glyph = GLYPHS[name] ?? GLYPHS[directory ? 'folder' : 'file']!;
      final drawn =
          options.icons?.call(iconStr) ??
          '<path d="$glyph" stroke="var(--_m)" stroke-width="1.5"/>';
      inner.write(
        '<svg class="pele-icon" data-icon="${escText(iconStr)}" x="${num(inset + row.x)}" y="${num(cy - iconSize / 2)}" width="${num(iconSize)}" height="${num(iconSize)}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">$drawn</svg>',
      );
    }
    if (row.label != null) {
      inner.write(
        leftLabelSvg(
          row.label!,
          inset + row.labelX,
          top + row.top + paddingY,
          ' class="pele-label"${directory ? ' font-weight="var(--_hw)"' : ''}$family',
        ),
      );
    } else if (row.text.isNotEmpty) {
      inner.write(
        '<text class="pele-label" x="${num(inset + row.labelX)}" y="${num(cy + baseline)}"${directory ? ' font-weight="var(--_hw)"' : ''}$family xml:space="preserve">${esc(row.text)}</text>',
      );
    }
    if (row.description != null) {
      inner.write(
        leftLabelSvg(
          row.description!,
          inset + row.labelX,
          top + row.top + paddingY + (row.label?.height ?? 0),
          ' class="pele-tree-description" font-style="italic" fill="var(--_m)"',
        ),
      );
    } else if (node.description != null && node.description!.isNotEmpty) {
      inner.write(
        '<text class="pele-tree-description" x="${num(inset + descX)}" y="${num(cy + baseline)}" font-style="italic" fill="var(--_m)" xml:space="preserve">${esc(decodeEntities(node.description!))}</text>',
      );
    }
    body.write(
      '<g class="pele-node pele-tree-${directory ? 'dir' : 'file'}${classNames(node.cssClass ?? '')}" data-id="${escText(node.name)}">$inner</g>',
    );
  }

  final guidesStr = guides.toString();
  final content =
      labelSvg(
        title,
        totalWidth / 2,
        pad + title.height / 2,
        ' class="pele-title" font-weight="var(--_tw)"',
      ) +
      (guidesStr.isNotEmpty
          ? '<g class="pele-tree-guides" fill="none" stroke="var(--_b)" stroke-width="${num(lineThickness)}">$guidesStr</g>'
          : '') +
      body.toString();

  return Rendered(
    svg: svgDocument(
      'treeView',
      totalWidth,
      totalHeight,
      size,
      options,
      model,
      content,
    ),
    width: totalWidth,
    height: totalHeight,
    links: <LinkInfo>[],
  );
}

// Upstream: src/diagrams/wardley/render.ts

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
import 'builder.dart';
import 'model.dart';

const List<String> _defaultStages = <String>[
  'Genesis',
  'Custom Built',
  'Product',
  'Commodity',
];
// Mermaid's canvas has this much room around the plot on every side.
const double _canvasMargin = 48;
const int _r = 6;
const int _square = 10;
const double _labelOffset = 8;
const double _pipelinePad = 15;
const double _forceWidth = 60;
const double _forceHeight = 30;
const double _forceHead = 20;
const String _accent = 'var(--_c)';
const String _line = 'var(--_l)';

class _Placed {
  double x;
  double y;
  final WardleyNode node;

  _Placed({required this.x, required this.y, required this.node});
}

double _setting(
  Config config,
  String key,
  double fallback,
  double min,
  double max,
) {
  final section = config['wardley-beta'];
  final value = section is Map ? section[key] : null;
  if (value is int && value >= min && value <= max) return value.toDouble();
  if (value is double && value >= min && value <= max) return value;
  return fallback;
}

double _clamp(double value, double min, double max) {
  return value < min ? min : (value > max ? max : value);
}

// Writes a label with its lines starting at x and its first baseline at y.
String _startLabel(Label label, double x, double y, String attrs) {
  final shared = sharedStyle(label);
  final body = StringBuffer();
  var baseline = y;
  for (final line in label.lines) {
    var first = true;
    for (final span in line) {
      if (span.icon != null) continue;
      final style = spanStyle(span.style & ~shared);
      body.write(
        '<tspan${first ? ' x="${num(x)}" y="${num(baseline)}"' : ''}$style>${esc(span.text)}</tspan>',
      );
      first = false;
    }
    baseline += label.lineHeight;
  }
  return body.isEmpty
      ? ''
      : '<text${textStyle(attrs, shared)} xml:space="preserve">$body</text>';
}

double _dimension(Config config, double? given, String key, double fallback) {
  final value = (given != null && given.isFinite)
      ? given
      : _setting(config, key, fallback, 1, 1e6);
  return _clamp(value, 200, 10000) - 2 * _canvasMargin;
}

Rendered renderWardley(
  WardleyModel model,
  Config config,
  RenderOptions options,
) {
  final natural = _dimension(config, model.size?.width, 'width', 900);
  return fitWidth(
    options,
    natural,
    160,
    (plotW, tight) => _draw(model, config, options, plotW, natural, tight),
  );
}

Rendered _draw(
  WardleyModel model,
  Config config,
  RenderOptions options,
  double plotW,
  double naturalW,
  bool tight,
) {
  final size = options.fontSize ?? 16;
  final small = roundJs(size * 0.8125);
  final tiny = roundJs(size * 0.6875);
  final measurer =
      options.measurer ??
      defaultMeasurer(options.fontFamily, options.fontFamilyMono);
  final pad = options.padding ?? 8;

  // A narrower map is not as much shorter, so that components keep some room between them.
  final plotH =
      _dimension(config, model.size?.height, 'height', 600) *
      math.max(0.75, plotW / naturalW);
  final wardleyCfg = config['wardley-beta'];
  final showGrid = wardleyCfg is Map && wardleyCfg['showGrid'] == true;

  var minX = 0.0;
  var minY = 0.0;
  var maxX = plotW;
  var maxY = plotH;
  void grow(double x0, double y0, double x1, double y1) {
    if (x0 < minX) minX = x0;
    if (y0 < minY) minY = y0;
    if (x1 > maxX) maxX = x1;
    if (y1 > maxY) maxY = y1;
  }

  String centered(Label label, double cx, double cy, String attrs) {
    grow(
      cx - label.width / 2,
      cy - label.height / 2,
      cx + label.width / 2,
      cy + label.height / 2,
    );
    return labelSvg(label, cx, cy, attrs, options.icons);
  }

  String starting(Label label, double x, double y, String attrs) {
    grow(x, y - label.size, x + label.width, y - label.size + label.height + 4);
    return _startLabel(label, x, y, attrs);
  }

  Label text(String raw, int fontSize, [double? maxWidth, int style = 0]) {
    final mw =
        maxWidth ??
        (tight ? math.max(64.0, math.min(120.0, plotW / 2)) : 4000.0);
    return layoutLabel(raw, false, measurer, fontSize.toDouble(), mw, style);
  }

  double projectX(double value) => (value / 100) * plotW;
  double projectY(double value) => plotH - (value / 100) * plotH;

  final stages = (model.axes.stages != null && model.axes.stages!.isNotEmpty)
      ? model.axes.stages!
      : _defaultStages;
  final boundaries = model.axes.stageBoundaries;
  final custom = boundaries != null && boundaries.length == stages.length;
  final frame = StringBuffer();
  final stageLabels = StringBuffer();
  var stageBottom = plotH;
  var previous = 0.0;
  for (var index = 0; index < stages.length; index++) {
    final stage = stages[index];
    final start = custom ? previous : index / stages.length;
    final end = custom
        ? _clamp(boundaries[index], 0, 1)
        : (index + 1) / stages.length;
    previous = end;
    if (index > 0) {
      frame.write(
        '<path class="pele-wardley-stage" d="M${num(start * plotW)},0V${num(plotH)}" stroke="var(--_b)" stroke-dasharray="4 4"/>',
      );
    }
    final label = text(
      stage,
      small,
      math.max(48.0, (end - start).abs() * plotW - 12),
    );
    stageLabels.write(
      centered(
        label,
        ((start + end) / 2) * plotW,
        plotH + 8 + label.height / 2,
        ' class="pele-wardley-stage-label" font-size="$small" fill="var(--_m)"',
      ),
    );
    stageBottom = math.max(stageBottom, plotH + 8 + label.height);
  }
  if (showGrid) {
    for (var i = 1; i < 4; i++) {
      frame.write(
        '<path class="pele-wardley-grid" d="M${num((plotW * i) / 4)},0V${num(plotH)}M0,${num((plotH * i) / 4)}H${num(plotW)}" stroke="var(--_b)" stroke-dasharray="2 6"/>',
      );
    }
  }
  frame.write(
    '<path class="pele-wardley-axis" d="M0,0V${num(plotH)}H${num(plotW)}" stroke="$_line"/>',
  );
  final xTitle = text(model.axes.xLabel ?? 'Evolution', small);
  final yTitle = text(model.axes.yLabel ?? 'Visibility', small);
  final axisAttrs =
      ' class="pele-wardley-axis-label" font-size="$small" font-weight="var(--_hw)"';
  final axisLabels =
      centered(
        xTitle,
        plotW / 2,
        stageBottom + 6 + xTitle.height / 2,
        axisAttrs,
      ) +
      labelSvg(
        yTitle,
        -16,
        plotH / 2,
        '$axisAttrs transform="rotate(-90 -16 ${num(plotH / 2)})"',
      );
  grow(-16 - yTitle.height / 2, 0, 0, 0);
  final legendTop = stageBottom + 6 + xTitle.height + 10;

  final positions = <String, _Placed>{};
  for (final node in model.nodes) {
    positions[node.id] = _Placed(
      x: projectX(node.x!),
      y: projectY(node.y!),
      node: node,
    );
  }

  // Pipelines: a box around the components, with the parent as a square on its top edge.
  final pipelines = StringBuffer();
  final members = <String, Set<String>>{};
  for (final pipeline in model.pipelines) {
    members[pipeline.nodeId] = pipeline.componentIds.toSet();
    final parts = <_Placed>[];
    for (final id in pipeline.componentIds) {
      final part = positions[id];
      if (part != null) parts.add(part);
    }
    if (parts.isEmpty) continue;
    parts.sort((a, b) => a.x.compareTo(b.x));
    final left = parts.first.x;
    final right = parts.last.x;
    final y = parts.first.y;
    final top = y - 2 * _r;
    final parent = positions[pipeline.nodeId];
    if (parent != null) {
      parent.x = (left + right) / 2;
      parent.y = top - _square / 6;
    }
    grow(left - _pipelinePad, top, right + _pipelinePad, top + 4 * _r);
    pipelines.write(
      '<g class="pele-wardley-pipeline" data-id="${escText(pipeline.nodeId)}">'
      '<rect x="${num(left - _pipelinePad)}" y="${num(top)}" width="${num(right - left + 2 * _pipelinePad)}" height="${num(4.0 * _r)}" fill="var(--_s)" stroke="var(--_b)"$roundedAttr/>'
      '${parts.length > 1 ? '<path d="M${num(left)},${num(y)}H${num(right)}" stroke="$_line" stroke-dasharray="4 4"/>' : ''}'
      '</g>',
    );
  }

  // How far from a node's center a line to it stops.
  final anchorLabels = <WardleyNode, Label>{};
  double reach(_Placed at, double ux, double uy) {
    final node = at.node;
    if (node.className == 'anchor') {
      var label = anchorLabels[node];
      if (label == null) {
        label = text(
          node.label,
          small,
          tight ? math.max(64.0, plotW / 2) : 4000.0,
          Style.Bold,
        );
        anchorLabels[node] = label;
      }
      return 1 / hypot(ux / (label.width / 2 + 5), uy / (small * 0.8));
    }
    if (node.isPipelineParent == true) return _square / math.sqrt2;
    return node.sourceStrategy != null ? 2.0 * _r : _r.toDouble();
  }

  // Quadrants around a node that a link runs through: 1 up and right, 2 down and right, 4 up and left, 8 down and left.
  final taken = <_Placed, int>{};
  void occupy(_Placed at, double ux, double uy) {
    if (ux.abs() < 0.25 || uy.abs() < 0.25) return;
    taken[at] =
        (taken[at] ?? 0) | (ux > 0 ? (uy < 0 ? 1 : 2) : (uy < 0 ? 4 : 8));
  }

  final links = StringBuffer();
  for (final link in model.links) {
    final from = positions[link.source];
    final to = positions[link.target];
    if (from == null || to == null || identical(from, to)) continue;
    // A pipeline component belongs to its parent already.
    if (members[link.target]?.contains(link.source) == true) continue;
    final dx = to.x - from.x;
    final dy = to.y - from.y;
    final distance = hypot(dx, dy);
    if (distance < 0.01) continue;
    final ux = dx / distance;
    final uy = dy / distance;
    final start = reach(from, ux, uy);
    final end = reach(to, ux, uy);
    if (start + end >= distance) continue;
    occupy(from, ux, uy);
    occupy(to, -ux, -uy);
    var x1 = from.x + ux * start;
    var y1 = from.y + uy * start;
    var x2 = to.x - ux * end;
    var y2 = to.y - uy * end;
    var heads = '';
    if (link.flow == 'forward' || link.flow == 'bidirectional') {
      heads += marker('arrow_point', x2, y2, ux, uy, _line);
      x2 -= ux * markerTrim('arrow_point');
      y2 -= uy * markerTrim('arrow_point');
    }
    if (link.flow == 'backward' || link.flow == 'bidirectional') {
      heads += marker('arrow_point', x1, y1, -ux, -uy, _line);
      x1 += ux * markerTrim('arrow_point');
      y1 += uy * markerTrim('arrow_point');
    }
    var caption = '';
    if (link.label != null && link.label!.isNotEmpty) {
      final label = text(link.label!, tiny + 1, 200);
      // Beside the middle of the line, on its upper side.
      final side = ux >= 0 ? 1.0 : -1.0;
      final px = uy * side;
      final py = -ux * side;
      final away =
          5 + (px.abs() * label.width) / 2 + (py.abs() * label.height) / 2;
      caption = centered(
        label,
        (from.x + to.x) / 2 + px * away,
        (from.y + to.y) / 2 + py * away,
        ' class="pele-edge-label" font-size="${tiny + 1}" fill="var(--_m)"',
      );
    }
    final isDashed = link.dashed == true;
    links.write(
      '<g class="pele-edge${isDashed ? ' pele-wardley-dashed' : ''}" data-id="${escText(link.source)}-${escText(link.target)}">'
      '<path d="M${num(x1)},${num(y1)}L${num(x2)},${num(y2)}" stroke="$_line"${isDashed ? ' stroke-dasharray="6 6"' : ''}/>'
      '$heads'
      '$caption'
      '</g>',
    );
  }

  // Evolution: a dashed arrow to where the component is heading, drawn as an open circle.
  final trends = StringBuffer();
  for (final trend in model.trends) {
    final origin = positions[trend.nodeId];
    if (origin == null) continue;
    final tx = projectX(trend.targetX);
    final ty = projectY(trend.targetY);
    final dx = tx - origin.x;
    final dy = ty - origin.y;
    final distance = hypot(dx, dy);
    var arrow = '';
    final start = distance > 0
        ? reach(origin, dx / distance, dy / distance)
        : 0.0;
    if (distance > start + _r + 4) {
      final ux = dx / distance;
      final uy = dy / distance;
      final ex = tx - ux * (_r + 2);
      final ey = ty - uy * (_r + 2);
      arrow =
          '<path d="M${num(origin.x + ux * start)},${num(origin.y + uy * start)}L${num(ex - ux * markerTrim('arrow_point'))},${num(ey - uy * markerTrim('arrow_point'))}" stroke="$_accent" stroke-dasharray="4 4"/>' +
          marker('arrow_point', ex, ey, ux, uy, _accent);
    }
    grow(tx - _r, ty - _r, tx + _r, ty + _r);
    trends.write(
      '<g class="pele-wardley-trend" data-id="${escText(trend.nodeId)}">$arrow'
      '<circle cx="${num(tx)}" cy="${num(ty)}" r="$_r" fill="var(--_bg)" stroke="$_accent"/></g>',
    );
  }

  final nodes = StringBuffer();
  const tri = 1.2 * _r;
  const dot = 0.7 * _r;
  for (final at in positions.values) {
    final node = at.node;
    final x = at.x;
    final y = at.y;
    final anchor = node.className == 'anchor';
    final strategy = node.sourceStrategy;
    final shape = StringBuffer();
    if (strategy != null) {
      final fill = strategy == 'outsource'
          ? 'var(--_m)'
          : strategy == 'buy'
          ? 'var(--_a)'
          : strategy == 'build'
          ? 'var(--_s)'
          : 'var(--_bg)';
      shape.write(
        '<circle class="pele-wardley-$strategy" cx="${num(x)}" cy="${num(y)}" r="${2 * _r}" fill="$fill" stroke="$_line"/>',
      );
    }
    if (strategy == 'market') {
      final bx = tri * math.cos(math.pi / 6);
      final by = y + tri * math.sin(math.pi / 6);
      shape.write(
        '<path d="M${num(x)},${num(y - tri)}L${num(x - bx)},${num(by)}H${num(x + bx)}Z" fill="none" stroke="$_line"/>',
      );
      for (final (cx, cy) in <(double, double)>[
        (x, y - tri),
        (x - bx, by),
        (x + bx, by),
      ]) {
        shape.write(
          '<circle cx="${num(cx)}" cy="${num(cy)}" r="${num(dot)}" fill="var(--_bg)" stroke="$_line"/>',
        );
      }
    } else if (node.isPipelineParent == true) {
      shape.write(
        '<rect x="${num(x - _square / 2)}" y="${num(y - _square / 2)}" width="$_square" height="$_square" fill="var(--_bg)" stroke="$_line"/>',
      );
    } else if (!anchor) {
      shape.write(
        '<circle cx="${num(x)}" cy="${num(y)}" r="$_r" fill="var(--_bg)" stroke="$_line"/>',
      );
    }
    if (node.inertia == true) {
      final offset =
          (node.isPipelineParent == true ? _square / 2 : _r) +
          10 +
          (strategy != null ? _r + 4 : 0);
      shape.write(
        '<rect class="pele-wardley-inertia" x="${num(x + offset)}" y="${num(y - _r)}" width="4" height="${2 * _r}" fill="$_line"/>',
      );
    }
    final ox = node.labelOffsetX == null
        ? null
        : _clamp(node.labelOffsetX!, -5000, 5000);
    final oy = node.labelOffsetY == null
        ? null
        : _clamp(node.labelOffsetY!, -5000, 5000);
    String caption;
    if (anchor) {
      final label =
          anchorLabels[node] ??
          text(
            node.label,
            small,
            tight ? math.max(64.0, plotW / 2) : 4000.0,
            Style.Bold,
          );
      caption = centered(
        label,
        x + (ox ?? 0),
        y + (oy ?? -3),
        ' class="pele-label" font-size="$small" font-weight="var(--_hw)"',
      );
    } else {
      final label = text(node.label, small);
      final attrs = ' class="pele-label" font-size="$small"';
      final lift = _labelOffset + (strategy != null ? 10 : 0);
      if (ox != null || oy != null) {
        caption = starting(label, x + (ox ?? lift), y + (oy ?? -lift), attrs);
      } else if (node.inPipeline == true) {
        caption = centered(label, x, y + 2 * _r + 4 + label.height / 2, attrs);
      } else {
        // The label goes up and to the right unless a link leaves that way; then the next free corner.
        final busy = taken[at] ?? 0;
        final corner = (busy & 1) == 0
            ? 1
            : (busy & 2) == 0
            ? 2
            : (busy & 4) == 0
            ? 4
            : (busy & 8) == 0
            ? 8
            : 1;
        final right = corner == 1 || corner == 2;
        final up = corner == 1 || corner == 4;
        caption = starting(
          label,
          right ? x + lift : x - lift - label.width,
          up ? y - lift : y + lift + small * 0.75,
          attrs,
        );
      }
    }
    grow(x - 2 * _r, y - 2 * _r, x + 2 * _r + 20, y + 2 * _r);
    final kindClass = anchor
        ? 'anchor'
        : node.isPipelineParent == true
        ? 'pipeline-parent'
        : node.inPipeline == true
        ? 'pipeline-component'
        : 'component';
    nodes.write(
      '<g class="pele-node pele-wardley-$kindClass" data-id="${escText(node.id)}">$shape$caption</g>',
    );
  }

  final annotations = StringBuffer();
  for (final annotation in model.annotations) {
    final label = text('${annotation.number}', tiny, 4000, Style.Bold);
    final marks = StringBuffer();
    for (final coordinate in annotation.coordinates) {
      final x = projectX(coordinate.x);
      final y = projectY(coordinate.y);
      final r = math.max(10.0, label.width / 2 + 4);
      grow(x - r, y - r, x + r, y + r);
      marks.write(
        '<circle cx="${num(x)}" cy="${num(y)}" r="${num(r)}" fill="var(--_bg)" stroke="$_line"/>' +
            labelSvg(
              label,
              x,
              y,
              ' font-size="$tiny" font-weight="var(--_hw)"',
            ),
      );
    }
    annotations.write(
      '<g class="pele-wardley-annotation" data-id="${escText('${annotation.number}')}">$marks</g>',
    );
  }
  final listed =
      model.annotations
          .where((a) => a.text != null && a.text!.isNotEmpty)
          .toList()
        ..sort((a, b) => a.number.compareTo(b.number));
  if (listed.isNotEmpty) {
    final lines = listed
        .map(
          (a) => text(
            '${a.number}. ${a.text!}',
            small,
            tight ? math.max(80.0, plotW - 20) : 320.0,
          ),
        )
        .toList();
    var width = 0.0;
    var height = 0.0;
    for (final line in lines) {
      width = math.max(width, line.width);
      height += line.height;
    }
    width += 20;
    height += 14;
    // Without a position the list goes under the map, where it covers nothing.
    final box = model.annotationsBox;
    final bx = box != null
        ? _clamp(projectX(box.x), 0, math.max(0.0, plotW - width))
        : 0.0;
    final by = box != null
        ? _clamp(projectY(box.y), 0, math.max(0.0, plotH - height))
        : legendTop;
    grow(bx, by, bx + width, by + height);
    final rows = StringBuffer();
    var y = by + 7;
    for (final line in lines) {
      rows.write(
        _startLabel(
          line,
          bx + 10,
          y + line.lineHeight / 2 + small * 0.35,
          ' font-size="$small"',
        ),
      );
      y += line.height;
    }
    annotations.write(
      '<g class="pele-wardley-annotations"><rect x="${num(bx)}" y="${num(by)}" width="${num(width)}" height="${num(height)}" fill="var(--_bg)" stroke="var(--_b)"$roundedAttr/>$rows</g>',
    );
  }

  final notes = StringBuffer();
  for (final note in model.notes) {
    notes.write(
      starting(
        text(note.text, small, math.min(360.0, plotW * 0.6), Style.Bold),
        projectX(note.x),
        projectY(note.y),
        ' class="pele-wardley-note" font-size="$small" font-weight="var(--_hw)"',
      ),
    );
  }

  // Accelerators point right, deaccelerators left.
  final forces = StringBuffer();
  void force(String name, double px, double py, bool forward) {
    final x = projectX(px);
    final y = projectY(py);
    const half = _forceHeight / 2;
    final tip = forward ? x + _forceWidth : x;
    final tail = forward ? x : x + _forceWidth;
    final neck = forward ? x + _forceWidth - _forceHead : x + _forceHead;
    final d =
        'M${num(tail)},${num(y - half)}H${num(neck)}V${num(y - half - 8)}L${num(tip)},${num(y)}L${num(neck)},${num(y + half + 8)}V${num(y + half)}H${num(tail)}Z';
    grow(x, y - half - 8, x + _forceWidth, y + half + 8);
    forces.write(
      '<g class="pele-wardley-${forward ? 'accelerator' : 'deaccelerator'}" data-id="${escText(name)}">'
      '<path d="$d" fill="var(--_s)" stroke="$_line"/>'
      '${centered(text(name, tiny + 1, 160, Style.Bold), x + _forceWidth / 2, y + half + 8 + 12, ' font-size="${tiny + 1}" font-weight="var(--_hw)"')}'
      '</g>',
    );
  }

  for (final a in model.accelerators) {
    force(a.name, a.x, a.y, true);
  }
  for (final d in model.deaccelerators) {
    force(d.name, d.x, d.y, false);
  }

  final title = layoutLabel(
    model.title,
    false,
    measurer,
    size,
    tight ? math.max(80.0, plotW) : 4000.0,
    Style.Bold,
  );
  final titleHeight = title.height > 0 ? title.height + 12 : 0.0;
  final left = math.min(minX, plotW / 2 - title.width / 2);
  final right = math.max(maxX, plotW / 2 + title.width / 2);
  final tx = pad - left;
  final ty = pad + titleHeight - minY;
  final totalWidth = (right - left + 2 * pad).ceilToDouble();
  final totalHeight = (maxY - minY + titleHeight + 2 * pad).ceilToDouble();
  final linksStr = links.toString();
  final trendsStr = trends.toString();
  final content =
      labelSvg(
        title,
        tx + plotW / 2,
        pad + title.height / 2,
        ' class="pele-title" font-weight="var(--_tw)"',
      ) +
      '<g transform="translate(${num(tx)},${num(ty)})">' +
      '<g class="pele-wardley-frame" fill="none">$frame</g>' +
      stageLabels.toString() +
      axisLabels +
      pipelines.toString() +
      (linksStr.isNotEmpty
          ? '<g class="pele-edges" fill="none">$linksStr</g>'
          : '') +
      (trendsStr.isNotEmpty
          ? '<g class="pele-wardley-trends" fill="none">$trendsStr</g>'
          : '') +
      nodes.toString() +
      annotations.toString() +
      notes.toString() +
      forces.toString() +
      '</g>';

  return Rendered(
    svg: svgDocument(
      'wardley',
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

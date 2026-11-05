// Upstream: src/diagrams/requirement/render.ts

import 'dart:math' as math;

import '../../layout/compound.dart' hide Style;
import '../../layout/layered.dart';
import '../../preprocess.dart';
import '../../svg/builder.dart';
import '../../svg/edges.dart';
import '../../svg/ink.dart';
import '../../svg/root.dart';
import '../../svg/theme.dart';
import '../../svg/title.dart';
import '../../text/label.dart';
import '../../text/measurer.dart';
import '../../types.dart';
import '../../util/math_js.dart';
import '../common/fit_width.dart';
import 'graph.dart';
import 'types.dart';

const double _nodeSep = 40;
const double _edgeSep = 16;
const double _rankSep = 56;
const double _padX = 14;
const double _padY = 10;
const double _rowGap = 2;
const double _columnGap = 12;
const double _minWidth = 120;
const double _nameWrap = 280;
const double _valueWrap = 240;
const double _loop = 26;
const double _containsRadius = 6;
const double _arrowLength = 9;
const double _arrowHalf = 4.5;
const double _endStep = 28;
const double _endMargin = 14;

final RegExp _reDefaultPrefix = RegExp(r'^default\s?');

String _fmt(double v) => v == v.truncateToDouble() ? '${v.toInt()}' : '$v';

class _Row {
  const _Row({required this.key, required this.value, required this.height});

  final Label key;
  final Label value;
  final double height;
}

class _NodeView {
  const _NodeView({
    required this.node,
    required this.style,
    required this.kind,
    required this.name,
    required this.rows,
    required this.keyWidth,
    required this.headHeight,
    required this.w,
    required this.h,
  });

  final GraphNode node;
  final ResolvedStyle style;
  final Label kind;
  final Label name;
  final List<_Row> rows;
  final double keyWidth;
  final double headHeight;
  final double w;
  final double h;
}

/// Adds bold or italic to a whole label after its markdown is read, since emphasis markers only
/// toggle styles the label does not start with.
Label _restyle(Label label, int bits, TextMeasurer measurer) {
  if (bits == 0 || label.lines.isEmpty) return label;
  var width = 0.0;
  final widths = <double>[];
  final lines = label.lines.map((line) {
    var total = 0.0;
    final spans = line.map((span) {
      final style = span.style | bits;
      final w = span.icon != null || span.math != null
          ? span.width
          : measurer.width(span.text, label.size, style);
      total += w;
      return span.copyWith(style: style, width: w);
    }).toList();
    widths.add(total);
    if (total > width) width = total;
    return spans;
  }).toList();
  return label.copyWith(lines: lines, widths: widths, width: width);
}

/// Writes a measured label with its lines starting at x, the first line's box starting at top.
String _startText(Label label, double x, double top, String attrs) {
  final shared = sharedStyle(label);
  final body = StringBuffer();
  final mathOut = StringBuffer();
  for (var i = 0; i < label.lines.length; i++) {
    final line = label.lines[i];
    final middle = top + lineMiddle(label, i);
    if (hasMath(line)) {
      mathOut.write(
        labelSvg(labelLine(label, i), x + label.widths[i] / 2, middle, attrs),
      );
      continue;
    }
    final y = middle + label.size * 0.35;
    var first = true;
    for (final span in line) {
      if (span.icon != null || span.text.isEmpty) continue;
      body.write(
        '<tspan${first ? ' x="${num(x)}" y="${num(y)}"' : ''}${spanStyle(span.style & ~shared)}>${esc(span.text)}</tspan>',
      );
      first = false;
    }
  }
  final bodyStr = body.toString();
  return (bodyStr.isEmpty
          ? ''
          : '<text${textStyle(attrs, shared)} text-anchor="start" xml:space="preserve">$bodyStr</text>') +
      mathOut.toString();
}

/// The containment mark: a circled plus whose rim touches (x, y), where (dx, dy) points at the node.
String _containsMarker(double x, double y, double dx, double dy) {
  const r = _containsRadius;
  final cx = x - dx * r;
  final cy = y - dy * r;
  return '<circle class="pele-marker" cx="${num(cx)}" cy="${num(cy)}" r="${_fmt(r)}"/>'
      '<path class="pele-marker" d="M${num(cx - dx * r)},${num(cy - dy * r)}L${num(cx + dx * r)},${num(cy + dy * r)}M${num(cx + dy * r)},${num(cy - dx * r)}L${num(cx - dy * r)},${num(cy + dx * r)}"/>';
}

/// An open arrowhead with its tip at (x, y), pointing along (dx, dy).
String _arrowMarker(double x, double y, double dx, double dy) {
  final bx = x - dx * _arrowLength;
  final by = y - dy * _arrowLength;
  return '<path class="pele-marker" d="M${num(bx - dy * _arrowHalf)},${num(by + dx * _arrowHalf)}L${num(x)},${num(y)}L${num(bx + dy * _arrowHalf)},${num(by - dx * _arrowHalf)}" stroke-linejoin="round"/>';
}

class _End {
  const _End({required this.route, required this.at, required this.toward});

  final List<double> route;
  final int at;
  final double toward;
}

/// The layout attaches every edge to the middle of a node's side. Ends that share a side are
/// spread along it, in the order of where they head, so their markers do not sit on each other.
void _spreadEnds(
  List<CNode> cnodes,
  List<CEdge> cedges,
  List<_NodeView> views,
) {
  final sides = <int, List<_End>>{};
  for (final edge in cedges) {
    final route = edge.route;
    if (edge.src == edge.dst || route.length < 6) continue;
    for (final at in <int>[0, route.length - 3]) {
      final node = at == 0 ? edge.src : edge.dst;
      final c = cnodes[node];
      final dx = route[at] - c.x;
      final dy = route[at + 1] - c.y;
      final next = at == 0 ? 3 : at - 3;
      int side;
      if ((dy.abs() - c.h / 2).abs() < 0.5) {
        side = dy < 0 ? 0 : 2;
      } else if ((dx.abs() - c.w / 2).abs() < 0.5) {
        side = dx < 0 ? 3 : 1;
      } else {
        continue;
      }
      final key = node * 4 + side;
      final end = _End(
        route: route,
        at: at,
        toward: route[side % 2 == 0 ? next : next + 1],
      );
      final list = sides[key];
      if (list != null) {
        list.add(end);
      } else {
        sides[key] = <_End>[end];
      }
    }
  }
  for (final entry in sides.entries) {
    final key = entry.key;
    final list = entry.value;
    if (list.length < 2) continue;
    final node = key >> 2;
    final vertical = key % 2 == 1;
    final span = (vertical ? views[node].h : views[node].w) - 2 * _endMargin;
    final step = math.max(0.0, math.min(_endStep, span / (list.length - 1)));
    list.sort((a, b) => a.toward.compareTo(b.toward));
    for (var j = 0; j < list.length; j++) {
      final offset = (j - (list.length - 1) / 2) * step;
      if (vertical) {
        list[j].route[list[j].at + 1] = cnodes[node].y + offset;
      } else {
        list[j].route[list[j].at] = cnodes[node].x + offset;
      }
    }
  }
}

Rendered renderRequirement(
  RequirementModel model,
  Config config,
  RenderOptions options,
) {
  if (!runsAcross(model.direction)) return _draw(model, config, options, false);
  return turnToFit(options, (down) => _draw(model, config, options, down));
}

/// `turned` draws a diagram that runs across as one that runs down.
Rendered _draw(
  RequirementModel model,
  Config config,
  RenderOptions options,
  bool turned,
) {
  final graph = buildRequirementGraph(model);
  final size = options.fontSize ?? 16;
  final small = roundJs(size * 0.875).toDouble();
  final measurer =
      options.measurer ??
      defaultMeasurer(options.fontFamily, options.fontFamilyMono);
  final pad = options.padding ?? 8;

  final index = <String, int>{};
  final views = <_NodeView>[];
  final cnodes = <CNode>[];
  for (final node in graph.nodes) {
    final style = resolveStyle(node.cssStyles);
    final base =
        (style.bold ? Style.Bold : 0) | (style.italic ? Style.Italic : 0);
    final nameSize = style.fontSize ?? size;
    final bodySize = style.fontSize ?? small;
    final requirement = node.requirement;
    final element = node.element;
    final kind = _restyle(
      layoutLabel(
        '«${requirement != null ? requirement.type : 'Element'}»',
        false,
        measurer,
        bodySize,
        4000,
      ),
      base,
      measurer,
    );
    final name = _restyle(
      layoutLabel(node.id, true, measurer, nameSize, _nameWrap),
      base | Style.Bold,
      measurer,
    );
    final fields = requirement != null
        ? <(String, String)>[
            ('ID', requirement.requirementId),
            ('Text', requirement.text),
            ('Risk', requirement.risk),
            ('Verification', requirement.verifyMethod),
          ]
        : <(String, String)>[
            ('Type', element!.type),
            ('Doc Ref', element.docRef),
          ];
    final rows = <_Row>[];
    var keyWidth = 0.0;
    var valueWidth = 0.0;
    var bodyHeight = 0.0;
    for (final (label, text) in fields) {
      if (text.isEmpty) continue;
      final key = _restyle(
        layoutLabel(label, false, measurer, bodySize, 4000),
        base,
        measurer,
      );
      final value = _restyle(
        layoutLabel(text, true, measurer, bodySize, _valueWrap),
        base,
        measurer,
      );
      final height = math.max(key.height, value.height);
      rows.add(_Row(key: key, value: value, height: height));
      keyWidth = math.max(keyWidth, key.width);
      valueWidth = math.max(valueWidth, value.width);
      bodyHeight += height + _rowGap;
    }
    if (rows.isNotEmpty) bodyHeight += 2 * _padY - _rowGap;
    final headHeight = 2 * _padY + kind.height + name.height;
    final w = math.max(
      math.max(_minWidth, math.max(kind.width, name.width) + 2 * _padX),
      rows.isNotEmpty ? keyWidth + _columnGap + valueWidth + 2 * _padX : 0.0,
    );
    // A requirement and an element may share a name; relationships then go to the requirement.
    if (!index.containsKey(node.id)) index[node.id] = views.length;
    final c = cnode(w, headHeight + bodyHeight);
    c.seq = views.length.toDouble();
    views.add(
      _NodeView(
        node: node,
        style: style,
        kind: kind,
        name: name,
        rows: rows,
        keyWidth: keyWidth,
        headHeight: headHeight,
        w: w,
        h: headHeight + bodyHeight,
      ),
    );
    cnodes.add(c);
  }

  final rootDir = turned ? 'TB' : direction(graph.direction);
  final sideways = rootDir == 'LR' || rootDir == 'RL';
  final cedges = <CEdge>[];
  final edgeLabels = <Label>[];
  final drawn = <GraphEdge>[];
  for (final edge in graph.edges) {
    final src = edge.start == null ? null : index[edge.start!];
    final dst = edge.end == null ? null : index[edge.end!];
    if (src == null || dst == null) continue;
    final label = layoutLabel('«${edge.type}»', false, measurer, small, 4000);
    if (src == dst) {
      // A self-loop sits beside the node, across the flow, and the node's box grows to hold it.
      if (sideways) {
        cnodes[src].h += 2 * (_loop + label.height + 8);
      } else {
        cnodes[src].w += 2 * (_loop + label.width + 12);
      }
    }
    drawn.add(edge);
    edgeLabels.add(label);
    cedges.add(
      CEdge(
        src: src,
        dst: dst,
        minlen: 1,
        labelW: label.width + 12,
        labelH: label.height + 4,
        route: <double>[],
        labelX: 0,
        labelY: 0,
      ),
    );
  }

  final layout = compoundLayout(
    cnodes,
    cedges,
    rootDir,
    const LayeredOptions(
      nodeSep: _nodeSep,
      edgeSep: _edgeSep,
      rankSep: _rankSep,
      portSep: 20,
    ),
  );

  _spreadEnds(cnodes, cedges, views);

  final title = titleLabel(model.title, measurer, size, 4000);
  final titleHeight = title.height > 0 ? title.height + 12 : 0.0;
  final inner = math.max(layout.width, title.width);
  final ox = pad + (inner - layout.width) / 2;
  final oy = pad + titleHeight;
  final width = (inner + 2 * pad).ceilToDouble();
  final height = (layout.height + titleHeight + 2 * pad).ceilToDouble();

  final nodesOut = StringBuffer();
  for (var i = 0; i < views.length; i++) {
    final view = views[i];
    final w = view.w;
    final h = view.h;
    final style = view.style;
    final color = inkFill((shape: style.shape, text: style.text));
    final muted = color.isNotEmpty ? color : ' fill="var(--_m)"';
    final left = -w / 2;
    final top = -h / 2;
    var body =
        '<rect x="${num(left)}" y="${num(top)}" width="${num(w)}" height="${num(h)}" fill="var(--_s)" stroke="var(--_b)"${rounded(style.shape)}/>'
        '${labelSvg(view.kind, 0, top + _padY + view.kind.height / 2, ' class="pele-stereotype" font-size="${_fmt(view.kind.size)}"$muted${style.text}')}'
        '${labelSvg(view.name, 0, top + _padY + view.kind.height + view.name.height / 2, ' class="pele-label" font-size="${_fmt(view.name.size)}" font-weight="var(--_hw)"$color${style.text}')}';
    if (view.rows.isNotEmpty) {
      final divider = top + view.headHeight;
      body +=
          '<path class="pele-divider" d="M${num(left)},${num(divider)}H${num(-left)}" stroke="var(--_b)"${style.line}/>';
      var y = divider + _padY;
      final rowsBuf = StringBuffer();
      for (final row in view.rows) {
        rowsBuf
          ..write(
            _startText(
              row.key,
              left + _padX,
              y,
              ' class="pele-field"$muted${style.text}',
            ),
          )
          ..write(
            _startText(
              row.value,
              left + _padX + view.keyWidth + _columnGap,
              y,
              ' class="pele-value"$color${style.text}',
            ),
          );
        y += row.height + _rowGap;
      }
      body +=
          '<g class="pele-fields" font-size="${_fmt(view.rows[0].key.size)}">$rowsBuf</g>';
    }
    nodesOut.write(
      '<g class="pele-node ${view.node.requirement != null ? 'pele-requirement' : 'pele-element'}${classNames(view.node.cssClasses.replaceFirst(_reDefaultPrefix, ''))}" data-id="${escText(view.node.id)}" transform="translate(${num(cnodes[i].x + ox)},${num(cnodes[i].y + oy)})">$body</g>',
    );
  }

  final edgesOut = StringBuffer();
  final labelsOut = StringBuffer();
  final loopSeen = <int, int>{};
  for (var i = 0; i < cedges.length; i++) {
    final ce = cedges[i];
    final edge = drawn[i];
    final label = edgeLabels[i];
    final startTrim = edge.contains ? 2 * _containsRadius : 0.0;
    EdgePath path;
    var labelX = ce.labelX + ox;
    var labelY = ce.labelY + oy;
    if (ce.src == ce.dst) {
      final view = views[ce.src];
      final cx = cnodes[ce.src].x + ox;
      final cy = cnodes[ce.src].y + oy;
      final k = loopSeen[ce.src] ?? 0;
      loopSeen[ce.src] = k + 1;
      final half = (sideways ? view.w : view.h) / 2;
      final spread = math.min(half - 4, 12.0 + k * 6);
      final reach = _loop + k * 8;
      // Local frame: `out` points away from the node, `along` runs along its side.
      String at(double out, double along) => sideways
          ? '${num(cx + along)},${num(cy + view.h / 2 + out)}'
          : '${num(cx + view.w / 2 + out)},${num(cy + along)}';
      // A cubic whose control points are this far out peaks at `reach`.
      final pull = reach / 0.75;
      path = EdgePath(
        d: 'M${at(startTrim, -spread)}C${at(pull, -spread)} ${at(pull, spread)} ${at(0, spread)}',
        sx: sideways ? cx - spread : cx + view.w / 2,
        sy: sideways ? cy + view.h / 2 : cy - spread,
        sdx: sideways ? 0 : -1,
        sdy: sideways ? -1 : 0,
        ex: sideways ? cx + spread : cx + view.w / 2,
        ey: sideways ? cy + view.h / 2 : cy + spread,
        edx: sideways ? 0 : -1,
        edy: sideways ? -1 : 0,
      );
      if (sideways) {
        labelX = cx;
        labelY = cy + view.h / 2 + reach + 4 + ce.labelH / 2;
      } else {
        labelX = cx + view.w / 2 + reach + 4 + ce.labelW / 2;
        labelY = cy;
      }
    } else {
      final route = List<double>.of(ce.route);
      for (var k = 0; k < route.length; k += 3) {
        route[k] += ox;
        route[k + 1] += oy;
      }
      path = routePath(route, null, startTrim, 0);
    }
    edgesOut.write(
      '<g class="pele-edge pele-relationship-${edge.contains ? 'contains' : 'arrow'}" data-id="${escText(edge.id)}">'
      '<path d="${path.d}"${edge.contains ? '' : ' stroke-dasharray="5 4"'}/>'
      '${edge.contains ? _containsMarker(path.sx, path.sy, path.sdx, path.sdy) : _arrowMarker(path.ex, path.ey, path.edx, path.edy)}'
      '</g>',
    );
    labelsOut.write(edgeLabelSvg(edge.id, label, labelX, labelY, ''));
  }

  final edgesStr = edgesOut.toString();
  final labelsStr = labelsOut.toString();
  final svg = svgDocument(
    'requirement',
    width,
    height,
    size,
    options,
    model,
    labelSvg(
          title,
          width / 2,
          pad + title.height / 2,
          ' class="pele-title" font-weight="var(--_tw)"',
        ) +
        (edgesStr.isNotEmpty
            ? '<g class="pele-edges" fill="none" stroke="var(--_l)" stroke-linecap="round">$edgesStr</g>'
            : '') +
        (labelsStr.isNotEmpty
            ? '<g class="pele-edge-labels" font-size="${_fmt(small)}" fill="var(--_m)">$labelsStr</g>'
            : '') +
        '<g class="pele-nodes">$nodesOut</g>',
  );

  return Rendered(
    svg: svg,
    width: width,
    height: height,
    links: const <LinkInfo>[],
  );
}

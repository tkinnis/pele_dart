// Upstream: src/diagrams/er/render.ts

import 'dart:math' as math;

import '../../layout/compound.dart' hide Style;
import '../../layout/layered.dart';
import '../../preprocess.dart';
import '../../svg/builder.dart';
import '../../svg/cluster.dart';
import '../../svg/edges.dart';
import '../../svg/ink.dart';
import '../../svg/root.dart';
import '../../svg/theme.dart';
import '../../svg/title.dart';
import '../../text/entities.dart';
import '../../text/label.dart';
import '../../text/measurer.dart';
import '../../types.dart';
import '../../util/math_js.dart';
import '../../util/url.dart';
import '../common/fit_width.dart';
import '../common/generics.dart';
import 'db.dart';
import 'graph.dart';
import 'markers.dart';

const double _nodeSep = 48;
const double _edgeSep = 20;
const double _rankSep = 64;
const double _groupPad = 20;
const double _loop = 28;
const double _loopBand = 38;
const double _minWidth = 96;
const double _boxPadX = 18;
const double _boxPadY = 12;
const double _headPadY = 9;
const double _cellPadX = 12;
const double _cellGap = 16;
const double _rowPad = 9;
const double _commentWrap = 260;
const double _noWrap = 1e6;
const List<_Loop> _noLoops = <_Loop>[];
const double _portGap = 18;
const double _portMargin = 14;
const String _boxAttrs = ' fill="var(--_s)" stroke="var(--_b)"';

final RegExp _reFontFamily = RegExp(r'[";]font-family:');
final RegExp _reDefaultPrefix = RegExp(r'^default\s?');
final RegExp _reInternalLink = RegExp(r' internal-link(?: |$)');

String _fmt(double v) => v == v.truncateToDouble() ? '${v.toInt()}' : '$v';

double _numberOption(Config config, String key, double fallback) {
  final erConfig = config['er'];
  final value = erConfig is Map ? erConfig[key] : null;
  if (value is int && value > 0) return math.min(value.toDouble(), 2000.0);
  if (value is double && value > 0) return math.min(value, 2000.0);
  return fallback;
}

class _Row {
  const _Row({required this.cells, required this.h});

  // Type, name, keys, comment.
  final List<Label> cells;
  final double h;
}

class _NodeView {
  _NodeView({
    required this.node,
    required this.style,
    required this.label,
    required this.rowSize,
    required this.keySize,
    required this.mono,
    required this.below,
  });

  final ErGraphNode node;
  final ResolvedStyle style;
  final Label label;
  double w = 0;
  double h = 0;
  double headH = 0;
  final List<_Row> rows = <_Row>[];
  // Left edge of each column, measured from the left edge of the box.
  final List<double> cols = <double>[];
  final double rowSize;
  final double keySize;
  final int mono;
  // Whether self-relationships loop out of the bottom side rather than the right.
  final bool below;
}

/// A relationship from an entity to itself, with the stretch of the side it loops out of.
class _Loop {
  _Loop({required this.label});

  final Label label;
  double band = 0;
  double at = 0;
}

/// Writes a measured label starting at x, with the baseline of its first line at y.
String _textLeft(
  Label label,
  double x,
  double y,
  String attrs,
  IconResolver? icons, [
  int mono = 0,
]) {
  final lines = label.lines;
  if (lines.isEmpty) return '';
  final only = lines.length == 1 && lines[0].length == 1 ? lines[0][0] : null;
  // The short form collapses repeated spaces in monospace text.
  if (only != null &&
      only.icon == null &&
      only.math == null &&
      only.style == mono &&
      !(mono != 0 && only.text.contains('  '))) {
    return '<text${textStyle(attrs, mono)} x="${num(x)}" y="${num(y)}">${esc(only.text)}</text>';
  }
  final shared = sharedStyle(label);
  final shift = label.size * 0.35;
  final top = y - shift - label.lineHeight / 2;
  final body = StringBuffer();
  final extra = StringBuffer();
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final middle = top + lineMiddle(label, i);
    if (hasMath(line)) {
      extra.write(
        labelSvg(
          labelLine(label, i),
          x + label.widths[i] / 2,
          middle,
          attrs,
          icons,
        ),
      );
      continue;
    }
    y = middle + shift;
    var hasIcon = false;
    for (final span in line) {
      if (span.icon != null) hasIcon = true;
    }
    var sx = x;
    var placed = false;
    for (final span in line) {
      if (span.icon != null) {
        final side = label.size * 1.1;
        extra.write(
          '<svg class="pele-icon" data-icon="${escText(span.icon!)}" x="${num(sx)}" y="${num(y - label.size * 0.35 - side / 2)}" width="${num(side)}" height="${num(side)}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${icons?.call(span.icon!) ?? ''}</svg>',
        );
      } else if (span.text.isNotEmpty) {
        final pos = hasIcon || !placed ? ' x="${num(sx)}" y="${num(y)}"' : '';
        body.write(
          '<tspan$pos${spanStyle(span.style & ~shared)}>${esc(span.text)}</tspan>',
        );
        placed = true;
      }
      sx += span.width;
    }
  }
  return '<text${textStyle(attrs, shared)} xml:space="preserve">$body</text>$extra';
}

/// Mermaid reads `~` pairs as angle brackets. They are written as entities so the label parser
/// does not take `<int>` for a tag.
String _cellText(String raw) {
  final converted = parseGenericTypes(raw);
  return converted == raw
      ? raw
      : converted.replaceAll('<', '&lt;').replaceAll('>', '&gt;');
}

Rendered renderEr(ErDb db, Config config, RenderOptions options) {
  if (!runsAcross(db.direction)) return _draw(db, config, options, false);
  return turnToFit(options, (down) => _draw(db, config, options, down));
}

/// `turned` draws a diagram that runs across as one that runs down.
Rendered _draw(ErDb db, Config config, RenderOptions options, bool turned) {
  final graph = buildErGraph(db);
  final monospaced =
      options.monospace != null && options.monospace!.contains('attributes');
  final size = options.fontSize ?? 16;
  final smallSize = roundJs(size * 0.875).toDouble();
  final measurer =
      options.measurer ??
      defaultMeasurer(options.fontFamily, options.fontFamilyMono);
  final pad = options.padding ?? 8;
  final icons = options.icons;

  final index = <String, int>{};
  final views = <_NodeView>[];
  final cnodes = <CNode>[];
  for (var i = 0; i < graph.nodes.length; i++) {
    index[graph.nodes[i].id] = i;
  }

  final cedges = <CEdge>[];
  final edgeLabels = <Label>[];
  final drawn = <ErGraphEdge>[];
  final loops = <int, List<_Loop>>{};
  final loopOf = <_Loop?>[];
  for (final edge in graph.edges) {
    final src = index[edge.start];
    final dst = index[edge.end];
    if (src == null || dst == null) continue;
    final label = layoutLabel(edge.label, true, measurer, smallSize, 200);
    _Loop? loop;
    if (src == dst) {
      loop = _Loop(label: label);
      final list = loops[src];
      if (list != null) {
        list.add(loop);
      } else {
        loops[src] = <_Loop>[loop];
      }
    }
    loopOf.add(loop);
    drawn.add(edge);
    edgeLabels.add(label);
    cedges.add(
      CEdge(
        src: src,
        dst: dst,
        minlen: 1,
        labelW: label.width > 0 ? label.width + 12 : 0,
        labelH: label.height > 0 ? label.height + 4 : 0,
        route: <double>[],
        labelX: 0,
        labelY: 0,
      ),
    );
  }

  // The direction of the level a node is laid out in: its nearest subgraph that sets one, or the diagram's.
  bool horizontal(int i) {
    var at = i;
    // Subgraphs can name each other as members, so the walk up is bounded.
    for (var steps = 0; steps < graph.nodes.length; steps++) {
      final parent = graph.nodes[at].parentId;
      final up = parent == null ? null : index[parent];
      if (up == null) break;
      final dir = graph.nodes[up].dir;
      if (dir != null && dir.isNotEmpty) return dir == 'LR' || dir == 'RL';
      at = up;
    }
    return db.direction == 'LR' || db.direction == 'RL';
  }

  for (var i = 0; i < graph.nodes.length; i++) {
    final node = graph.nodes[i];
    final style = resolveStyle(
      node.cssStyles.isNotEmpty
          ? <String>[...node.cssCompiledStyles, ...node.cssStyles]
          : node.cssCompiledStyles,
    );
    final base =
        (style.bold ? Style.Bold : 0) | (style.italic ? Style.Italic : 0);
    final mono = monospaced && !_reFontFamily.hasMatch(style.text)
        ? Style.Mono
        : 0;
    final nameSize = style.fontSize ?? size;
    final rowSize = style.fontSize ?? smallSize;
    final keySize = style.fontSize ?? roundJs(size * 0.75).toDouble();
    final label = node.isGroup
        ? layoutLabel(node.label, true, measurer, nameSize, 4000, base)
        : layoutLabel(
            node.alias.isNotEmpty ? node.alias : node.label,
            true,
            measurer,
            nameSize,
            240,
            base,
          );
    final own = loops[i] ?? _noLoops;
    // Loops leave by a side the layout keeps free of other edges: the right when ranks run down,
    // the bottom when they run across.
    final below = own.isNotEmpty && !node.isGroup && horizontal(i);
    final view = _NodeView(
      node: node,
      style: style,
      label: label,
      rowSize: rowSize,
      keySize: keySize,
      mono: mono,
      below: below,
    );
    var reach = 0.0;
    var bands = 0.0;
    for (final loop in own) {
      loop.band = math.max(
        _loopBand,
        below ? loop.label.width + 12 : loop.label.height + 6,
      );
      bands += loop.band;
      reach = math.max(reach, below ? loop.label.height : loop.label.width);
    }
    final minW = math.max(_minWidth, below ? bands + 8 : 0.0);
    CNode c;
    if (node.isGroup) {
      c = cnode(0, 0);
      c.isGroup = true;
      c.dir = node.dir != null && node.dir!.isNotEmpty
          ? direction(node.dir)
          : null;
      c.padX = _groupPad;
      c.padTop = view.label.height > 0 ? view.label.height + 16 : _groupPad;
      c.padBottom = _groupPad;
      c.minW = math.max(view.label.width + 2 * _groupPad - 12, _minWidth);
    } else {
      final nameH = math.max(label.height, roundJs(nameSize * 1.5).toDouble());
      if (node.attributes.isEmpty) {
        view.w = math.max(label.width + 2 * _boxPadX, minW);
        view.h = math.max(nameH + 2 * _boxPadY, below ? 0.0 : bands + 8);
      } else {
        final rowLine = roundJs(rowSize * 1.5).toDouble();
        final widths = <double>[0, 0, 0, 0];
        for (final attribute in node.attributes) {
          final cells = <Label>[
            layoutLabel(
              _cellText(attribute.type),
              true,
              measurer,
              rowSize,
              _noWrap,
              base | mono,
            ),
            layoutLabel(
              _cellText(attribute.name),
              true,
              measurer,
              rowSize,
              _noWrap,
              base | mono,
            ),
            layoutLabel(
              attribute.keys.join(', '),
              false,
              measurer,
              keySize,
              _noWrap,
              base | mono,
            ),
            layoutLabel(
              _cellText(attribute.comment),
              true,
              measurer,
              rowSize,
              _commentWrap,
              base,
            ),
          ];
          var h = rowLine;
          for (var k = 0; k < 4; k++) {
            if (cells[k].width > widths[k]) widths[k] = cells[k].width;
            if (cells[k].height > h) h = cells[k].height;
          }
          view.rows.add(_Row(cells: cells, h: h + _rowPad));
          view.h += h + _rowPad;
        }
        var columns = 0;
        var inner = 0.0;
        for (final w in widths) {
          if (w == 0) continue;
          inner += w + (columns > 0 ? _cellGap : 0);
          columns++;
        }
        view.w = math.max(
          math.max(inner + 2 * _cellPadX, label.width + 2 * _boxPadX),
          minW,
        );
        // A box wider than its table shares the spare width between the columns.
        final spare = columns > 0
            ? (view.w - inner - 2 * _cellPadX) / columns
            : 0.0;
        var x = _cellPadX;
        for (final w in widths) {
          view.cols.add(x);
          if (w > 0) x += w + spare + _cellGap;
        }
        view.headH = nameH + 2 * _headPadY;
        view.h += view.headH;
      }
      // The layout keeps a node centered in its box, so room for loops is added on both sides.
      final room = own.isNotEmpty
          ? 2 * (MARKER_LENGTH + _loop * 0.75 + 10 + reach)
          : 0.0;
      c = below ? cnode(view.w, view.h + room) : cnode(view.w + room, view.h);
    }
    c.seq = views.length.toDouble();
    views.add(view);
    cnodes.add(c);
  }
  for (var i = 0; i < graph.nodes.length; i++) {
    final parentId = graph.nodes[i].parentId;
    cnodes[i].parent = parentId != null ? (index[parentId] ?? -1) : -1;
  }

  final layout = compoundLayout(
    cnodes,
    cedges,
    turned ? 'TB' : direction(db.direction),
    LayeredOptions(
      nodeSep: _numberOption(config, 'nodeSpacing', _nodeSep),
      edgeSep: _edgeSep,
      rankSep: _numberOption(config, 'rankSpacing', _rankSep),
      portSep: 24,
    ),
  );

  _spreadEnds(cedges, cnodes, views);

  // A subgraph gets its size from the layout, so its loops hang outside it and may widen the diagram.
  var layoutWidth = layout.width;
  for (final entry in loops.entries) {
    final c = cnodes[entry.key];
    if (!c.isGroup) continue;
    var reach = 0.0;
    for (final loop in entry.value) {
      reach = math.max(reach, loop.label.width);
    }
    layoutWidth = math.max(
      layoutWidth,
      c.x + c.w / 2 + MARKER_LENGTH + _loop * 0.75 + 10 + reach,
    );
  }

  final title = titleLabel(db.title, measurer, size, 4000);
  final titleHeight = title.height > 0 ? title.height + 12 : 0.0;
  final inner = math.max(layoutWidth, title.width);
  final ox = pad + (inner - layoutWidth) / 2;
  final oy = pad + titleHeight;
  shiftLayout(cnodes, cedges, ox, oy);
  final width = (inner + 2 * pad).ceilToDouble();
  final height = (layout.height + titleHeight + 2 * pad).ceilToDouble();
  final links = <LinkInfo>[];

  final Crossings crossings = <int, List<double>>{};
  var anyGroup = false;
  for (final c in cnodes) {
    if (c.isGroup) anyGroup = true;
  }
  if (anyGroup) {
    for (final e in cedges) {
      markCrossings(crossings, e.route);
    }
  }

  final clusters = StringBuffer();
  final fills = <Fill>[];
  final nodesOut = StringBuffer();
  for (var i = 0; i < views.length; i++) {
    final view = views[i];
    final c = cnodes[i];
    final node = view.node;
    final classes = classNames(
      node.cssClasses.replaceFirst(_reDefaultPrefix, ''),
    );
    final styleRecord = (shape: view.style.shape, text: view.style.text);
    if (c.isGroup) {
      view.w = c.w;
      view.h = c.h;
      final x = c.x - c.w / 2;
      final y = c.y - c.h / 2;
      final titleX = clusterTitleX(c, view.label.width, crossings, _groupPad);
      if (paints(view.style.shape)) {
        fills.add(
          Fill(box: <double>[x, y, x + c.w, y + c.h], shape: view.style.shape),
        );
      }
      clusters.write(
        '<g class="pele-cluster$classes" data-id="${escText(node.id)}">'
        '<rect x="${num(x)}" y="${num(y)}" width="${num(c.w)}" height="${num(c.h)}" fill="var(--_a)"${setsFill(view.style.shape) ? '' : ' fill-opacity="0.5"'} stroke="var(--_b)"${rounded(view.style.shape)}/>'
        '${labelSvg(view.label, titleX, y + 8 + view.label.height / 2, ' class="pele-cluster-label"${inkFill(styleRecord, 'var(--_m)')}${view.style.text}', icons)}'
        '</g>',
      );
      continue;
    }

    final w = view.w;
    final h = view.h;
    final x0 = -w / 2;
    final y0 = -h / 2;
    final text = view.style.text;
    final color = inkFill(styleRecord);
    final muted = color.isNotEmpty ? color : ' fill="var(--_m)"';
    final shape =
        'x="${num(x0)}" y="${num(y0)}" width="${num(w)}" height="${num(h)}"';
    var name = labelSvg(
      view.label,
      0,
      view.rows.isNotEmpty ? y0 + view.headH / 2 : 0,
      ' class="pele-label"$color$text',
      icons,
    );
    final display = decodeEntities(
      node.alias.isNotEmpty ? node.alias : node.label,
    );
    if (_reInternalLink.hasMatch('$classes ') &&
        name.isNotEmpty &&
        options.links != false) {
      // The name ends up in an href, so it gets the same check as a URL.
      final safe = internalLink(display, options);
      final target = esc(display);
      name =
          '<a class="internal-link"${safe ? ' href="$target"${relAttr(options)}' : ''} data-href="$target">$name</a>';
      links.add(LinkInfo(id: node.label, href: display, internal: true));
    }

    String body;
    if (view.rows.isEmpty) {
      body = '<rect $shape${rounded(_boxAttrs + view.style.shape)}/>$name';
    } else {
      final rowLine = roundJs(view.rowSize * 1.5).toDouble();
      final lineColor = view.style.stroke != null
          ? esc(view.style.stroke!)
          : 'var(--_b)';
      final stripes = StringBuffer();
      final cells = StringBuffer();
      var y = y0 + view.headH;
      for (var r = 0; r < view.rows.length; r++) {
        final row = view.rows[r];
        if (r % 2 == 0) {
          final span = 'x="${num(x0)}" width="${num(w)}"';
          if (r == view.rows.length - 1) {
            // The last row follows the box's rounded bottom corners: a rounded rect, squared off on top.
            stripes
              ..write(
                '<rect $span y="${num(y)}" height="${num(row.h)}"$roundedAttr/>',
              )
              ..write('<rect $span y="${num(y)}" height="${num(row.h / 2)}"/>');
          } else {
            stripes.write('<rect $span y="${num(y)}" height="${num(row.h)}"/>');
          }
        }
        final baseline = y + _rowPad / 2 + rowLine / 2 + view.rowSize * 0.35;
        final typeCell = row.cells[0];
        final attributeCell = row.cells[1];
        final keysCell = row.cells[2];
        final commentCell = row.cells[3];
        cells
          ..write(
            _textLeft(
              typeCell,
              x0 + view.cols[0],
              baseline,
              ' class="pele-er-type"$muted$text',
              icons,
              view.mono,
            ),
          )
          ..write(
            _textLeft(
              attributeCell,
              x0 + view.cols[1],
              baseline,
              ' class="pele-er-name"$color$text',
              icons,
              view.mono,
            ),
          )
          ..write(
            _textLeft(
              keysCell,
              x0 + view.cols[2],
              baseline,
              ' class="pele-er-keys" font-size="${_fmt(view.keySize)}"$muted$text',
              icons,
              view.mono,
            ),
          )
          ..write(
            _textLeft(
              commentCell,
              x0 + view.cols[3],
              baseline,
              ' class="pele-er-comment"$muted$text',
              icons,
            ),
          );
        y += row.h;
      }
      final dividerY = num(y0 + view.headH);
      // Keep row shading light on light fills and dark on dark fills to preserve text contrast.
      final tone = ink(view.style.shape);
      final shade = tone == onLight
          ? onDark
          : tone == onDark
          ? onLight
          : 'var(--_bg)';
      body =
          '<rect $shape${rounded(_boxAttrs + view.style.shape)}/>'
          // Over a fill the diagram chose, the shading is a tint of that fill. The opacity is on the
          // group because the two parts of the last row overlap.
          '<g class="pele-er-stripes" fill="$shade"${view.style.shape.contains('fill:') ? ' opacity="0.6"' : ''}>$stripes</g>'
          '<path class="pele-er-divider" d="M${num(x0)},$dividerY'
          'H${num(x0 + w)}" stroke="$lineColor"/>'
          '<rect $shape fill="none" stroke="var(--_b)"${rounded(view.style.line)}/>'
          '$name'
          '<g class="pele-er-attributes" font-size="${_fmt(view.rowSize)}">$cells</g>';
    }
    nodesOut.write(
      '<g class="pele-node pele-entity$classes" data-id="${escText(node.label)}" transform="translate(${num(c.x)},${num(c.y)})">$body</g>',
    );
  }

  // Self-relationships share the side they loop out of, squeezed together if it is too short for them.
  for (final entry in loops.entries) {
    final view = views[entry.key];
    final own = entry.value;
    var total = 0.0;
    for (final loop in own) {
      total += loop.band;
    }
    final scale = math.min(
      1.0,
      math.max((view.below ? view.w : view.h) - 8, 0.0) / total,
    );
    var at = (-total * scale) / 2;
    for (final loop in own) {
      loop.band *= scale;
      loop.at = at + loop.band / 2;
      at += loop.band;
    }
  }

  final edgesOut = StringBuffer();
  var casings = '';
  final labelsOut = StringBuffer();
  for (var i = 0; i < cedges.length; i++) {
    final ce = cedges[i];
    final edge = drawn[i];
    final label = edgeLabels[i];
    String d;
    String start;
    String end;
    final loop = loopOf[i];
    if (loop != null) {
      final c = cnodes[ce.src];
      final view = views[ce.src];
      final spread = math.max(math.min(loop.band / 2 - 6, 13.0), 1.0);
      const far = MARKER_LENGTH + _loop * 0.75 + 6;
      if (view.below) {
        final x = c.x + loop.at;
        final y = c.y + view.h / 2;
        final turn = num(y + MARKER_LENGTH);
        final out = num(y + MARKER_LENGTH + _loop);
        d =
            'M${num(x - spread)},${num(y)}V$turn'
            'C${num(x - spread)},$out ${num(x + spread)},$out ${num(x + spread)},$turn'
            'V${num(y)}';
        start = erMarker(edge.arrowTypeStart, x - spread, y, 0, -1);
        end = erMarker(edge.arrowTypeEnd, x + spread, y, 0, -1);
        ce.labelX = x;
        ce.labelY = y + far + label.height / 2;
      } else {
        final x = c.x + view.w / 2;
        final y = c.y + loop.at;
        final turn = num(x + MARKER_LENGTH);
        final out = num(x + MARKER_LENGTH + _loop);
        d =
            'M${num(x)},${num(y - spread)}H$turn'
            'C$out,${num(y - spread)} $out,${num(y + spread)} $turn,${num(y + spread)}'
            'H${num(x)}';
        start = erMarker(edge.arrowTypeStart, x, y - spread, -1, 0);
        end = erMarker(edge.arrowTypeEnd, x, y + spread, -1, 0);
        ce.labelX = x + far + label.width / 2;
        ce.labelY = y;
      }
    } else {
      final route = _straighten(ce.route);
      if (route.length < 6) continue;
      _inset(route, 0, views[ce.src], cnodes[ce.src]);
      _inset(route, route.length - 3, views[ce.dst], cnodes[ce.dst]);
      // A curve stops short of each box so that the marker sits on a straight run of line.
      final dx = (route[route.length - 3] - route[0]).abs();
      final dy = (route[route.length - 2] - route[1]).abs();
      final direct =
          route.length == 6 &&
          (dx < 0.01 || dy < 0.01 || hypot(dx, dy) <= 3 * MARKER_LENGTH);
      final stub = direct ? 0.0 : MARKER_LENGTH;
      final path = routePath(route, null, stub, stub);
      d = stub > 0
          ? 'M${num(path.sx)},${num(path.sy)}L${path.d.substring(1)}L${num(path.ex)},${num(path.ey)}'
          : path.d;
      start = erMarker(
        edge.arrowTypeStart,
        path.sx,
        path.sy,
        path.sdx,
        path.sdy,
      );
      end = erMarker(edge.arrowTypeEnd, path.ex, path.ey, path.edx, path.edy);
    }
    final under = fillUnder(d, const <double>[], fills);
    final String? over = under is Fill ? edgeInk(under) : under as String?;
    if (over == '') casings += casing(d, start + end);
    if (under is Fill && over != null && over.isNotEmpty) {
      start = hollowOn(start, under);
      end = hollowOn(end, under);
    }
    final dashed = edge.pattern == 'dashed';
    edgesOut.write(
      '<g class="pele-edge pele-er-${dashed ? 'non-identifying' : 'identifying'}" data-id="${escText(edge.id)}"${over != null && over.isNotEmpty ? ' stroke="$over"' : ''}>'
      '<path d="$d"${dashed ? ' stroke-dasharray="4 3"' : ''}/>'
      '$start'
      '$end'
      '</g>',
    );
    if (label.width > 0) {
      final x = ce.labelX;
      final y = ce.labelY;
      labelsOut.write(edgeLabelSvg(edge.id, label, x, y, '', icons));
    }
  }

  final clustersStr = clusters.toString();
  final edgesStr = edgesOut.toString();
  final labelsStr = labelsOut.toString();
  final svg = svgDocument(
    'er',
    width,
    height,
    size,
    options,
    db,
    labelSvg(
          title,
          width / 2,
          pad + title.height / 2,
          ' class="pele-title" font-weight="var(--_tw)"',
        ) +
        (clustersStr.isNotEmpty
            ? '<g class="pele-clusters">$clustersStr</g>'
            : '') +
        casingsSvg(casings) +
        (edgesStr.isNotEmpty
            ? '<g class="pele-edges" fill="none" stroke="var(--_l)" stroke-linecap="round">$edgesStr</g>'
            : '') +
        (labelsStr.isNotEmpty
            ? '<g class="pele-edge-labels" font-size="${_fmt(smallSize)}">$labelsStr</g>'
            : '') +
        '<g class="pele-nodes">$nodesOut</g>',
  );

  return Rendered(svg: svg, width: width, height: height, links: links);
}

List<double> _straighten(List<double> route) {
  final out = route.sublist(0, math.min(3, route.length));
  for (var k = 3; k < route.length; k += 3) {
    final prev = out.length - 3;
    bool flat(int axis) =>
        (out[prev + axis] - route[k + axis]).abs() < 0.01 &&
        (route[k + axis] - route[k + 3 + axis]).abs() < 0.01;
    if (k + 3 < route.length && (flat(0) || flat(1))) continue;
    out.addAll(<double>[route[k], route[k + 1], route[k + 2]]);
  }
  return out;
}

class _End {
  const _End({required this.route, required this.at, required this.toward});

  final List<double> route;
  final int at;
  final double toward;
}

/// The layout brings every edge that ends on one side of a box to the middle of that side, where
/// their markers would cover each other. This spaces them along the side, in the order they fan out.
void _spreadEnds(
  List<CEdge> cedges,
  List<CNode> cnodes,
  List<_NodeView> views,
) {
  final sides = <int, List<_End>>{};
  void add(int node, List<double> route, int at, int next) {
    final c = cnodes[node];
    final dx = route[at] - c.x;
    final dy = route[at + 1] - c.y;
    int side;
    if ((dy.abs() - c.h / 2).abs() < 0.5) {
      side = dy < 0 ? 0 : 2;
    } else if ((dx.abs() - c.w / 2).abs() < 0.5) {
      side = dx < 0 ? 3 : 1;
    } else {
      return;
    }
    final key = node * 4 + side;
    final end = _End(
      route: route,
      at: at,
      toward: route[next + ((side & 1) != 0 ? 1 : 0)],
    );
    final list = sides[key];
    if (list != null) {
      list.add(end);
    } else {
      sides[key] = <_End>[end];
    }
  }

  for (final e in cedges) {
    final last = e.route.length - 3;
    if (e.src == e.dst || last < 3) continue;
    add(e.src, e.route, 0, 3);
    add(e.dst, e.route, last, last - 3);
  }
  for (final entry in sides.entries) {
    final key = entry.key;
    final ends = entry.value;
    if (ends.length < 2) continue;
    final node = key >> 2;
    final vertical = (key & 1) == 1;
    final length = cnodes[node].isGroup
        ? (vertical ? cnodes[node].h : cnodes[node].w)
        : (vertical ? views[node].h : views[node].w);
    final step = math.max(
      math.min(_portGap, (length - 2 * _portMargin) / (ends.length - 1)),
      0.0,
    );
    final center = vertical ? cnodes[node].y : cnodes[node].x;
    ends.sort((a, b) => a.toward.compareTo(b.toward));
    for (var i = 0; i < ends.length; i++) {
      ends[i].route[ends[i].at + (vertical ? 1 : 0)] =
          center + (i - (ends.length - 1) / 2) * step;
    }
  }
}

/// An entity with a self-relationship is laid out larger than it is drawn; this moves a route end
/// from the side of that larger box onto the entity's own side.
void _inset(List<double> route, int at, _NodeView view, CNode c) {
  if (c.isGroup) return;
  final dx = route[at] - c.x;
  final dy = route[at + 1] - c.y;
  if (c.w != view.w && (dx.abs() - c.w / 2).abs() < 0.5) {
    route[at] -= (signJs(dx) * (c.w - view.w)) / 2;
  }
  if (c.h != view.h && (dy.abs() - c.h / 2).abs() < 0.5) {
    route[at + 1] -= (signJs(dy) * (c.h - view.h)) / 2;
  }
}

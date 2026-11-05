// Upstream: src/diagrams/architecture/render.ts

import 'dart:math' as math;
import 'dart:typed_data';

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
import 'db.dart';
import 'icons.dart';
import 'layout.dart';

const double _stub = 12;
const double _corner = 6;
const double _labelGap = 4;
const int _dotInt = 3;
const double _dot = 3;
const List<double> _dx = <double>[-1, 1, 0, 0];
const List<double> _dy = <double>[0, 0, -1, 1];

double _setting(
  Config config,
  String key,
  double fallback,
  double min,
  double max,
) {
  final section = config['architecture'];
  final value = section is Map ? section[key] : null;
  if (value is int) {
    return math.min(max, math.max(min, value.toDouble()));
  }
  if (value is double && value.isFinite) {
    return math.min(max, math.max(min, value));
  }
  return fallback;
}

// Maps the grid lines in use to consecutive indexes, so empty rows and columns take no room.
Map<int, int> _rank(List<int> values) {
  values.sort((a, b) => a.compareTo(b));
  final out = <int, int>{};
  for (final value in values) {
    if (!out.containsKey(value)) out[value] = out.length;
  }
  return out;
}

String _iconSlot(
  String name,
  double x,
  double y,
  double side,
  IconResolver? icons,
) {
  return '<svg class="pele-icon" data-icon="${escText(name)}" x="${num(x)}" y="${num(y)}" width="${num(side)}" height="${num(side)}"'
      ' viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${icons?.call(name) ?? builtinIcon(name)}</svg>';
}

// Cuts a label down to a box, ending what is left with an ellipsis.
Label _fit(Label label, double maxWidth, int maxLines, TextMeasurer measurer) {
  final cut = label.lines.length > maxLines;
  if (!cut && label.width <= maxWidth) return label;
  final dots = measurer.width('…', label.size, 0);
  final lines = <List<Span>>[];
  final widths = <double>[];
  var widest = 0.0;
  for (var i = 0; i < math.min(maxLines, label.lines.length); i++) {
    final line = label.lines[i].map((span) => span.copyWith()).toList();
    var width = label.widths[i];
    if (width > maxWidth || (cut && i == maxLines - 1)) {
      for (;;) {
        final span = line.isNotEmpty ? line.last : null;
        if (span == null) {
          line.add(Span(text: '…', style: 0, width: dots));
          width = dots;
          break;
        }
        final rest = width - span.width;
        if (span.icon == null && rest + dots < maxWidth) {
          var lo = 0;
          var hi = span.text.length;
          while (lo < hi) {
            final mid = (lo + hi + 1) >> 1;
            if (rest +
                    measurer.width(
                      span.text.substring(0, mid),
                      label.size,
                      span.style,
                    ) +
                    dots <=
                maxWidth) {
              lo = mid;
            } else {
              hi = mid - 1;
            }
          }
          final code = lo > 0 ? span.text.codeUnitAt(lo - 1) : 0;
          if (code >= 0xd800 && code <= 0xdbff) lo--;
          span.text = '${span.text.substring(0, lo).trimRight()}…';
          span.width = measurer.width(span.text, label.size, span.style);
          width = rest + span.width;
          break;
        }
        line.removeLast();
        width = rest;
      }
    }
    lines.add(line);
    widths.add(width);
    widest = math.max(widest, width);
  }
  return label.copyWith(
    lines: lines,
    widths: widths,
    width: widest,
    height: lines.length * label.lineHeight,
  );
}

class _Port {
  _Port({
    required this.x,
    required this.y,
    required this.dx,
    required this.dy,
    required this.x0,
    required this.y0,
    required this.x1,
    required this.y1,
    required this.gap,
    required this.wire,
  });

  double x;
  double y;
  final double dx;
  final double dy;
  // The box the route has to stay out of when it cannot leave straight.
  double x0;
  double y0;
  double x1;
  double y1;
  // How far short of the port an arrowhead stops: the radius of a junction's dot.
  double gap;
  // Set where a junction is reached through the border of its group: the line carries on to the junction.
  bool wire;
}

// An orthogonal route from one port to another, each left along its side's normal.
List<double> _route(_Port s, _Port e) {
  final sx = s.x;
  final sy = s.y;
  final sdx = s.dx;
  final sdy = s.dy;
  final ex = e.x;
  final ey = e.y;
  final edx = e.dx;
  final edy = e.dy;
  final s1x = sx + sdx * _stub;
  final s1y = sy + sdy * _stub;
  final e1x = ex + edx * _stub;
  final e1y = ey + edy * _stub;
  if (sdx * edx + sdy * edy == 0) {
    final cx = sdx != 0 ? ex : sx;
    final cy = sdx != 0 ? sy : ey;
    if ((cx - sx) * sdx + (cy - sy) * sdy > 0 &&
        (cx - ex) * edx + (cy - ey) * edy > 0) {
      return <double>[sx, sy, cx, cy, ex, ey];
    }
    return sdx != 0
        ? <double>[sx, sy, s1x, s1y, s1x, e1y, e1x, e1y, ex, ey]
        : <double>[sx, sy, s1x, s1y, e1x, s1y, e1x, e1y, ex, ey];
  }
  final sideways = sdx != 0;
  final offset = sideways ? ey - sy : ex - sx;
  if (sdx == -edx && sdy == -edy) {
    final ahead = (ex - sx) * sdx + (ey - sy) * sdy;
    if (ahead > 0) {
      if (offset.abs() < 0.5) return <double>[sx, sy, ex, ey];
      if (sideways) {
        final lo = sdx > 0 ? s.x1 : e.x1;
        final hi = sdx > 0 ? e.x0 : s.x0;
        final mx = lo < hi ? (lo + hi) / 2 : (sx + ex) / 2;
        return <double>[sx, sy, mx, sy, mx, ey, ex, ey];
      }
      final lo = sdy > 0 ? s.y1 : e.y1;
      final hi = sdy > 0 ? e.y0 : s.y0;
      final my = lo < hi ? (lo + hi) / 2 : (sy + ey) / 2;
      return <double>[sx, sy, sx, my, ex, my, ex, ey];
    }
  } else if (offset.abs() >= 1) {
    if (sideways) {
      final x = sdx > 0 ? math.max(sx, ex) + _stub : math.min(sx, ex) - _stub;
      return <double>[sx, sy, x, sy, x, ey, ex, ey];
    }
    final y = sdy > 0 ? math.max(sy, ey) + _stub : math.min(sy, ey) - _stub;
    return <double>[sx, sy, sx, y, ex, y, ex, ey];
  }
  if (sideways) {
    final lane = s.y1 + _stub <= e.y0
        ? (s.y1 + e.y0) / 2
        : e.y1 + _stub <= s.y0
        ? (e.y1 + s.y0) / 2
        : math.max(s.y1, e.y1) + _stub;
    return <double>[sx, sy, s1x, sy, s1x, lane, e1x, lane, e1x, ey, ex, ey];
  }
  final lane = s.x1 + _stub <= e.x0
      ? (s.x1 + e.x0) / 2
      : e.x1 + _stub <= s.x0
      ? (e.x1 + s.x0) / 2
      : math.max(s.x1, e.x1) + _stub;
  return <double>[sx, sy, sx, s1y, lane, s1y, lane, e1y, ex, e1y, ex, ey];
}

// Drops repeated points and joins runs that continue in a straight line.
List<double> _simplify(List<double> p) {
  final out = <double>[p[0], p[1]];
  for (var i = 2; i < p.length; i += 2) {
    final x = p[i];
    final y = p[i + 1];
    final n = out.length;
    final sameX = (x - out[n - 2]).abs() < 0.01;
    final sameY = (y - out[n - 1]).abs() < 0.01;
    if (sameX && sameY) continue;
    if (n >= 4 &&
        ((sameX && (out[n - 4] - out[n - 2]).abs() < 0.01) ||
            (sameY && (out[n - 3] - out[n - 1]).abs() < 0.01))) {
      out[n - 2] = x;
      out[n - 1] = y;
    } else {
      out.addAll(<double>[x, y]);
    }
  }
  return out;
}

String _pathData(List<double> p, double startTrim, double endTrim) {
  final n = p.length ~/ 2;
  final xs = Float64List(n);
  final ys = Float64List(n);
  for (var i = 0; i < n; i++) {
    xs[i] = p[i * 2];
    ys[i] = p[i * 2 + 1];
  }
  void trim(int at, int toward, double amount) {
    final len = hypot(xs[toward] - xs[at], ys[toward] - ys[at]);
    final t = math.min(amount, math.max(0.0, len - 1));
    if (len > 0 && t > 0) {
      xs[at] += ((xs[toward] - xs[at]) / len) * t;
      ys[at] += ((ys[toward] - ys[at]) / len) * t;
    }
  }

  trim(0, 1, startTrim);
  trim(n - 1, n - 2, endTrim);
  var d = 'M${num(xs[0])},${num(ys[0])}';
  for (var i = 1; i < n - 1; i++) {
    final before = hypot(xs[i] - xs[i - 1], ys[i] - ys[i - 1]);
    final after = hypot(xs[i + 1] - xs[i], ys[i + 1] - ys[i]);
    final r = math.min(_corner, math.min(before / 2, after / 2));
    if (r < 0.5) {
      d += 'L${num(xs[i])},${num(ys[i])}';
      continue;
    }
    final inX = xs[i] - ((xs[i] - xs[i - 1]) / before) * r;
    final inY = ys[i] - ((ys[i] - ys[i - 1]) / before) * r;
    final outX = xs[i] + ((xs[i + 1] - xs[i]) / after) * r;
    final outY = ys[i] + ((ys[i + 1] - ys[i]) / after) * r;
    d +=
        'L${num(inX)},${num(inY)}Q${num(xs[i])},${num(ys[i])} ${num(outX)},${num(outY)}';
  }
  return '$d'
      'L${num(xs[n - 1])},${num(ys[n - 1])}';
}

Rendered renderArchitecture(
  ArchitectureModel model,
  Config config,
  RenderOptions options,
) {
  return tighten(options, (tight) => _draw(model, config, options, tight));
}

Rendered _draw(
  ArchitectureModel model,
  Config config,
  RenderOptions options,
  bool tight,
) {
  final iconSize = _setting(config, 'iconSize', 48, 8, 512);
  final size = _setting(config, 'fontSize', options.fontSize ?? 16, 4, 128);
  final groupPad = math.min(
    _setting(config, 'padding', 20, 0, 256),
    tight ? 12.0 : double.infinity,
  );
  final smallInt = roundJs(size * 0.875);
  final small = smallInt.toDouble();
  final measurer =
      options.measurer ??
      defaultMeasurer(options.fontFamily, options.fontFamilyMono);
  final pad = options.padding ?? 8;
  final icons = options.icons;
  final half = iconSize / 2;

  final nodes = model.nodes.values.toList();
  final groups = model.groups.values.toList();
  final n = nodes.length;
  final gCount = groups.length;
  final grid = placeOnGrid(nodes, groups, model.edges, model.layoutHints);
  final index = <String, int>{};
  for (var i = 0; i < n; i++) {
    index[nodes[i].id] = i;
  }

  // A service is its icon square with the title beneath; a junction takes the same room.
  final labels = List<Label?>.filled(n, null);
  final boxW = Float64List(n);
  final boxH = Float64List(n);
  final wrap = tight
      ? math.max(iconSize, 64.0)
      : math.max(iconSize * 2.25, 96.0);
  for (var i = 0; i < n; i++) {
    final node = nodes[i];
    final label = layoutLabel(
      node is ArchService ? node.title : null,
      true,
      measurer,
      size,
      wrap,
    );
    labels[i] = label;
    boxW[i] = math.max(iconSize, 2.0 * (label.width / 2).ceil());
    boxH[i] = iconSize + (label.height > 0 ? _labelGap + label.height : 0);
  }

  final colValues = <int>[];
  final rowValues = <int>[];
  for (var i = 0; i < n; i++) {
    colValues.add(grid.col[i]);
    rowValues.add(grid.row[i]);
  }
  for (var g = 0; g < gCount; g++) {
    if (grid.groupEmpty[g] == 0) continue;
    colValues.add(grid.groupCol[g]);
    rowValues.add(grid.groupRow[g]);
  }
  final colOf = _rank(colValues);
  final rowOf = _rank(rowValues);
  final cCount = colOf.length;
  final rCount = rowOf.length;
  final colW = Float64List(cCount);
  final rowH = Float64List(rCount);
  final gap = tight
      ? math.max(24.0, 2 * _stub)
      : math.max(40.0, roundJs(iconSize * 0.75).toDouble());
  final gapX = Float64List(cCount)..fillRange(0, cCount, gap);
  final gapY = Float64List(rCount)..fillRange(0, rCount, gap);
  final nodeCol = Int32List(n);
  final nodeRow = Int32List(n);
  for (var i = 0; i < n; i++) {
    final c = (nodeCol[i] = colOf[grid.col[i]]!);
    final r = (nodeRow[i] = rowOf[grid.row[i]]!);
    colW[c] = math.max(colW[c], boxW[i]);
    rowH[r] = math.max(rowH[r], boxH[i]);
  }
  for (var g = 0; g < gCount; g++) {
    if (grid.groupEmpty[g] == 0) continue;
    final c = colOf[grid.groupCol[g]]!;
    final r = rowOf[grid.groupRow[g]]!;
    colW[c] = math.max(colW[c], iconSize);
    rowH[r] = math.max(rowH[r], half);
  }

  // An edge label needs the gap its edge crosses to be wide enough to hold it.
  final eCount = model.edges.length;
  final edgeLabels = List<Label?>.filled(eCount, null);
  final ends = Int32List(eCount * 2);
  for (var k = 0; k < eCount; k++) {
    final edge = model.edges[k];
    final a = (ends[k * 2] = index[edge.lhsId] ?? -1);
    final b = (ends[k * 2 + 1] = index[edge.rhsId] ?? -1);
    final label = layoutLabel(edge.title, true, measurer, small, 160);
    edgeLabels[k] = label;
    if (label.width == 0 || a < 0 || b < 0) continue;
    if (nodeCol[a] != nodeCol[b]) {
      final c = math.min(nodeCol[a], nodeCol[b]);
      gapX[c] = math.max(gapX[c], label.width.ceilToDouble() + 28);
    } else {
      colW[nodeCol[a]] = math.max(
        colW[nodeCol[a]],
        2.0 * (label.width / 2).ceil() + 8,
      );
      if (nodeRow[a] != nodeRow[b]) {
        final r = math.min(nodeRow[a], nodeRow[b]);
        gapY[r] = math.max(gapY[r], label.height.ceilToDouble() + 24);
      }
    }
  }

  final groupLabels = List<Label?>.filled(gCount, null);
  final c0 = Int32List(gCount);
  final c1 = Int32List(gCount);
  final r0 = Int32List(gCount);
  final r1 = Int32List(gCount);
  final insL = Float64List(gCount);
  final insR = Float64List(gCount);
  final insT = Float64List(gCount);
  final insB = Float64List(gCount);
  final headW = Float64List(gCount);
  final headH = Float64List(gCount);
  final colL = Float64List(cCount);
  final colR = Float64List(cCount);
  final rowT = Float64List(rCount);
  final rowB = Float64List(rCount);
  final badge = roundJs(size * 1.25).toDouble();
  for (var g = 0; g < gCount; g++) {
    c0[g] = colOf[grid.groupCol[g]]!;
    c1[g] = colOf[grid.groupCol[g] + grid.groupCols[g] - 1]!;
    r0[g] = rowOf[grid.groupRow[g]]!;
    r1[g] = rowOf[grid.groupRow[g] + grid.groupRows[g] - 1]!;
    final label = layoutLabel(
      groups[g].title,
      true,
      measurer,
      size,
      tight ? math.max(80.0, titleRoom(options) / 2) : 320.0,
    );
    groupLabels[g] = label;
    final hasIcon = groups[g].icon != null && groups[g].icon!.isNotEmpty;
    final icon = hasIcon ? badge : 0.0;
    headW[g] = label.width + icon + (label.width > 0 && icon > 0 ? 6.0 : 0.0);
    headH[g] = math.max(label.height, icon);
  }
  for (var g = gCount - 1; g >= 0; g--) {
    final leftVal = groupPad + insL[g];
    var rightVal = groupPad + insR[g];
    final topVal =
        (headH[g] > 0 ? math.max(groupPad, headH[g] + 12) : groupPad) + insT[g];
    final bottomVal = groupPad + insB[g];
    if (headW[g] > 0) {
      var inner = leftVal + rightVal;
      for (var c = c0[g]; c <= c1[g]; c++) {
        inner += colW[c] + (c < c1[g] ? colR[c] + gapX[c] + colL[c + 1] : 0.0);
      }
      if (headW[g] + 20 > inner) {
        rightVal += (headW[g] + 20 - inner).ceilToDouble();
      }
    }
    insL[g] = leftVal;
    insR[g] = rightVal;
    insT[g] = topVal;
    insB[g] = bottomVal;
    colL[c0[g]] = math.max(colL[c0[g]], leftVal);
    colR[c1[g]] = math.max(colR[c1[g]], rightVal);
    rowT[r0[g]] = math.max(rowT[r0[g]], topVal);
    rowB[r1[g]] = math.max(rowB[r1[g]], bottomVal);
    final p = grid.groupParent[g];
    if (p < 0) continue;
    if (c0[p] == c0[g]) insL[p] = math.max(insL[p], leftVal);
    if (c1[p] == c1[g]) insR[p] = math.max(insR[p], rightVal);
    if (r0[p] == r0[g]) insT[p] = math.max(insT[p], topVal);
    if (r1[p] == r1[g]) insB[p] = math.max(insB[p], bottomVal);
  }

  final xPos = Float64List(cCount);
  final yPos = Float64List(rCount);
  var innerW = 0.0;
  for (var c = 0; c < cCount; c++) {
    xPos[c] = innerW + colL[c];
    innerW = xPos[c] + colW[c] + colR[c] + (c < cCount - 1 ? gapX[c] : 0.0);
  }
  var innerH = 0.0;
  for (var r = 0; r < rCount; r++) {
    yPos[r] = innerH + rowT[r];
    innerH = yPos[r] + rowH[r] + rowB[r] + (r < rCount - 1 ? gapY[r] : 0.0);
  }
  var minX = 0.0;
  var minY = 0.0;
  var maxX = innerW;
  var maxY = innerH;

  double left(int g) => xPos[c0[g]] - insL[g];
  double right(int g) => xPos[c1[g]] + colW[c1[g]] + insR[g];
  double top(int g) => yPos[r0[g]] - insT[g];
  double bottom(int g) => yPos[r1[g]] + rowH[r1[g]] + insB[g];
  double centerX(int i) => xPos[nodeCol[i]] + colW[nodeCol[i]] / 2;

  _Port port(int i, int side, bool? viaGroup) {
    final dx = _dx[side];
    final dy = _dy[side];
    final cx = centerX(i);
    final y = yPos[nodeRow[i]];
    final p = _Port(
      x: cx,
      y: y + half,
      dx: dx,
      dy: dy,
      x0: cx - boxW[i] / 2,
      y0: y,
      x1: cx + boxW[i] / 2,
      y1: y + boxH[i],
      gap: 0,
      wire: false,
    );
    if (nodes[i].type == 'junction') {
      p.x0 = p.x1 = cx;
      p.y0 = p.y1 = p.y;
      p.gap = _dot;
    } else if (dx != 0) {
      p.x = cx + dx * half;
    } else {
      p.y = dy < 0 ? y : y + boxH[i] + (labels[i]!.height > 0 ? 2.0 : 0.0);
    }
    final g = viaGroup == true ? grid.nodeParent[i] : -1;
    if (g >= 0) {
      p.x0 = left(g);
      p.x1 = right(g);
      p.y0 = top(g);
      p.y1 = bottom(g);
      p.gap = 0;
      p.wire = nodes[i].type == 'junction';
      if (dx != 0) {
        p.x = dx < 0 ? p.x0 : p.x1;
      } else {
        p.y = dy < 0 ? p.y0 : p.y1;
      }
    }
    return p;
  }

  var edgesOut = '';
  var labelsOut = '';
  // Vertical runs of the edges, to keep group titles out from under them.
  final runs = <double>[];
  final trimLength = markerTrim('arrow_point');
  for (var k = 0; k < eCount; k++) {
    final edge = model.edges[k];
    final a = ends[k * 2];
    final b = ends[k * 2 + 1];
    if (a < 0 || b < 0) continue;
    final s = port(a, sideIndex(edge.lhsDir), edge.lhsGroup);
    final e = port(b, sideIndex(edge.rhsDir), edge.rhsGroup);
    if (s.x == e.x && s.y == e.y && s.dx == e.dx) {
      // An edge from a side back to the same side: part the two ends so it shows as a loop.
      s.x -= 8 * s.dy.abs();
      s.y -= 8 * s.dx.abs();
      e.x += 8 * s.dy.abs();
      e.y += 8 * s.dx.abs();
    }
    final routed = _route(s, e);
    if (s.wire) {
      routed.insertAll(0, <double>[centerX(a), yPos[nodeRow[a]] + half]);
    }
    if (e.wire) {
      routed.addAll(<double>[centerX(b), yPos[nodeRow[b]] + half]);
    }
    final points = _simplify(routed);
    if (points.length < 4) continue;
    final id = escText('${edge.lhsId}-${edge.rhsId}');
    final lhsInto = edge.lhsInto == true;
    final rhsInto = edge.rhsInto == true;
    edgesOut +=
        '<g class="pele-edge" data-id="$id">'
        '<path d="${_pathData(points, lhsInto && !s.wire ? trimLength + s.gap : 0, rhsInto && !e.wire ? trimLength + e.gap : 0)}"/>'
        '${lhsInto ? marker('arrow_point', s.x + s.dx * s.gap, s.y + s.dy * s.gap, -s.dx, -s.dy, 'var(--_l)') : ''}'
        '${rhsInto ? marker('arrow_point', e.x + e.dx * e.gap, e.y + e.dy * e.gap, -e.dx, -e.dy, 'var(--_l)') : ''}'
        '</g>';
    var best = -1;
    var bestLength = -1.0;
    var flat = -1;
    var flatLength = -1.0;
    final label = edgeLabels[k]!;
    for (var i = 0; i < points.length; i += 2) {
      minX = math.min(minX, points[i] - 4);
      maxX = math.max(maxX, points[i] + 4);
      minY = math.min(minY, points[i + 1] - 4);
      maxY = math.max(maxY, points[i + 1] + 4);
    }
    for (var i = 0; i + 3 < points.length; i += 2) {
      final horizontal = (points[i + 1] - points[i + 3]).abs() < 0.01;
      final length =
          (points[i] - points[i + 2]).abs() +
          (points[i + 1] - points[i + 3]).abs();
      if (!horizontal) {
        runs.addAll(<double>[
          points[i],
          math.min(points[i + 1], points[i + 3]),
          math.max(points[i + 1], points[i + 3]),
        ]);
      }
      if (length > bestLength) {
        best = i;
        bestLength = length;
      }
      if (horizontal && length > flatLength) {
        flat = i;
        flatLength = length;
      }
    }
    if (label.width > 0) {
      final at = flatLength >= label.width + 8 ? flat : best;
      var x = (points[at] + points[at + 2]) / 2;
      var y = (points[at + 1] + points[at + 3]) / 2;
      final w = label.width + 8;
      final upright = (points[at] - points[at + 2]).abs() < 0.01;
      for (final p in <_Port>[s, e]) {
        if (x + w / 2 <= p.x0 ||
            x - w / 2 >= p.x1 ||
            y + label.height / 2 <= p.y0 ||
            y - label.height / 2 >= p.y1) {
          continue;
        }
        if (upright) {
          x = x >= (p.x0 + p.x1) / 2 ? p.x1 + w / 2 + 4 : p.x0 - w / 2 - 4;
        } else {
          y = y >= (p.y0 + p.y1) / 2
              ? p.y1 + label.height / 2 + 4
              : p.y0 - label.height / 2 - 4;
        }
      }
      minX = math.min(minX, x - w / 2);
      maxX = math.max(maxX, x + w / 2);
      minY = math.min(minY, y - label.height / 2);
      maxY = math.max(maxY, y + label.height / 2);
      labelsOut += edgeLabelSvg(
        '${edge.lhsId}-${edge.rhsId}',
        label,
        x,
        y,
        '',
        icons,
      );
    }
  }

  var clusters = '';
  for (var g = 0; g < gCount; g++) {
    final group = groups[g];
    final x = left(g);
    final y = top(g);
    final w = right(g) - x;
    final label = groupLabels[g]!;
    var head = '';
    if (headW[g] > 0) {
      final band = y + headH[g] + 12;
      final crossings = <double>[];
      for (var i = 0; i < runs.length; i += 3) {
        if (runs[i + 1] < band &&
            runs[i + 2] > y &&
            runs[i] > x &&
            runs[i] < x + w) {
          crossings.add(runs[i]);
        }
      }
      crossings.sort((a, b) => a.compareTo(b));
      crossings.add(x + w - 4);
      var start = x + 10;
      for (final crossing in crossings) {
        if (crossing - 6 - start >= headW[g]) break;
        start = math.max(start, crossing + 6);
      }
      if (start + headW[g] > x + w - 4) start = x + 10;
      final cy = y + 6 + headH[g] / 2;
      var textX = start;
      final gIcon = group.icon;
      if (gIcon != null && gIcon.isNotEmpty) {
        head += _iconSlot(gIcon, start, cy - badge / 2, badge, icons);
        textX += badge + 6;
      }
      head += labelSvg(
        label,
        textX + label.width / 2,
        cy,
        ' class="pele-cluster-label" fill="var(--_m)"',
        icons,
      );
    }
    clusters +=
        '<g class="pele-cluster" data-id="${escText(group.id)}">'
        '<rect x="${num(x)}" y="${num(y)}" width="${num(w)}" height="${num(bottom(g) - y)}" fill="var(--_a)" fill-opacity="0.5" stroke="var(--_b)"$roundedAttr/>'
        '$head'
        '</g>';
  }

  var nodesOut = '';
  final glyph = iconSize * 0.5;
  final textSizeInt = math.max(6, roundJs(size * 0.75));
  final textSize = textSizeInt.toDouble();
  for (var i = 0; i < n; i++) {
    final node = nodes[i];
    final at =
        'data-id="${escText(node.id)}" transform="translate(${num(centerX(i))},${num(yPos[nodeRow[i]])})"';
    if (node is ArchJunction) {
      nodesOut +=
          '<g class="pele-node pele-junction" $at><circle cy="${num(half)}" r="$_dotInt" fill="var(--_l)"/></g>';
      continue;
    }
    final service = node as ArchService;
    var inner = '';
    if (service.icon != null && service.icon!.isNotEmpty) {
      inner = _iconSlot(
        service.icon!,
        -glyph / 2,
        (iconSize - glyph) / 2,
        glyph,
        icons,
      );
    } else if (service.iconText != null && service.iconText!.isNotEmpty) {
      final text = layoutLabel(
        service.iconText,
        false,
        measurer,
        textSize,
        iconSize - 8,
      );
      final lineDenom = text.lineHeight != 0 ? text.lineHeight : 1.0;
      final lines = math.max(1, ((iconSize - 4) / lineDenom).floor());
      inner = labelSvg(
        _fit(text, iconSize - 8, lines, measurer),
        0,
        half,
        ' class="pele-icon-text" font-size="$textSizeInt"',
        icons,
      );
    }
    final label = labels[i]!;
    nodesOut +=
        '<g class="pele-node pele-service" $at>'
        '<rect x="${num(-half)}" width="${num(iconSize)}" height="${num(iconSize)}" fill="var(--_s)" stroke="var(--_b)"$roundedAttr/>'
        '$inner'
        '${labelSvg(label, 0, iconSize + _labelGap + label.height / 2, ' class="pele-label"', icons)}'
        '</g>';
  }

  final title = layoutLabel(
    model.title,
    false,
    measurer,
    size,
    tight ? titleRoom(options) : 4000,
    Style.Bold,
  );
  final titleHeight = title.height > 0 ? title.height + 12 : 0.0;
  final width = (math.max(maxX - minX, title.width) + 2 * pad).ceilToDouble();
  final height = (maxY - minY + titleHeight + 2 * pad).ceilToDouble();
  final ox = roundJs((width - (maxX - minX)) / 2 - minX);
  final oy = roundJs(pad + titleHeight - minY);
  final body =
      '${clusters.isNotEmpty ? '<g class="pele-clusters">$clusters</g>' : ''}'
      '${edgesOut.isNotEmpty ? '<g class="pele-edges" fill="none" stroke="var(--_l)" stroke-linecap="round" stroke-linejoin="round">$edgesOut</g>' : ''}'
      '${labelsOut.isNotEmpty ? '<g class="pele-edge-labels" font-size="$smallInt">$labelsOut</g>' : ''}'
      '${nodesOut.isNotEmpty ? '<g class="pele-nodes">$nodesOut</g>' : ''}';
  final svg = svgDocument(
    'architecture',
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
        (body.isNotEmpty ? '<g transform="translate($ox,$oy)">$body</g>' : ''),
  );
  return Rendered(svg: svg, width: width, height: height, links: <LinkInfo>[]);
}

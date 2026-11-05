// Upstream: src/diagrams/pie/render.ts

import 'dart:math' as math;

import '../../preprocess.dart';
import '../../svg/builder.dart';
import '../../svg/palette.dart';
import '../../svg/root.dart';
import '../../svg/theme.dart';
import '../../text/label.dart';
import '../../text/measurer.dart';
import '../../types.dart';
import '../../util/math_js.dart';
import '../common/fit_width.dart';
import 'model.dart';

const double _RADIUS = 120;
const int _SWATCH = 12;
const double _ROW = 26;
const double _GAP = 32;
const double _OUTSIDE = 28;

double? _asDouble(Object? v) =>
    v is double ? v : (v is int ? v.toDouble() : null);

String _fmtNum(double v) =>
    v == 0 ? '0' : (v == v.truncateToDouble() ? '${v.toInt()}' : '$v');

Object? _option(Config config, String key) {
  final pie = config['pie'];
  return pie is Map ? pie[key] : null;
}

String _point(double angle, double radius) {
  return '${num(math.sin(angle) * radius)},${num(-math.cos(angle) * radius)}';
}

String _slice(double start, double end, double outer, double inner) {
  if (end - start >= math.pi * 2 - 1e-9) {
    String ring(double r, int sweep) =>
        'M0,${num(-r)}A${num(r)},${num(r)} 0 1 $sweep 0,${num(r)}A${num(r)},${num(r)} 0 1 $sweep 0,${num(-r)}Z';
    return ring(outer, 1) + (inner > 0 ? ring(inner, 0) : '');
  }
  final large = end - start > math.pi ? 1 : 0;
  if (inner <= 0) {
    return 'M0,0L${_point(start, outer)}A${num(outer)},${num(outer)} 0 $large 1 ${_point(end, outer)}Z';
  }
  return 'M${_point(start, outer)}A${num(outer)},${num(outer)} 0 $large 1 ${_point(end, outer)}'
      'L${_point(end, inner)}A${num(inner)},${num(inner)} 0 $large 0 ${_point(start, inner)}Z';
}

Rendered renderPie(PieModel model, Config config, RenderOptions options) {
  return fitWidth(
    options,
    _RADIUS * 2,
    140,
    (diameter, tight) => _draw(model, config, options, diameter / 2, tight),
  );
}

class _PlacedOutside {
  final double x;
  final double y;
  final double width;

  const _PlacedOutside({required this.x, required this.y, required this.width});
}

// `tight` is set when the chart does not fit the width it has with its legend beside it.
Rendered _draw(
  PieModel model,
  Config config,
  RenderOptions options,
  double radius,
  bool tight,
) {
  final size = options.fontSize ?? 16;
  final smallInt = roundJs(size * 0.875);
  final small = smallInt.toDouble();
  final measurer =
      options.measurer ??
      defaultMeasurer(options.fontFamily, options.fontFamilyMono);
  final pad = options.padding ?? 8;

  final position = _asDouble(_option(config, 'textPosition'));
  final textPosition = position != null && position >= 0 && position <= 1
      ? position
      : 0.75;
  final hole = _asDouble(_option(config, 'donutHole'));
  final inner = hole != null && hole > 0 && hole <= 0.9 ? hole * radius : 0.0;
  final placed = '${_option(config, 'legendPosition') ?? 'right'}';
  final legendPosition = tight && (placed == 'left' || placed == 'right')
      ? 'bottom'
      : placed;

  final entries = model.sections.entries.map((e) => (e.key, e.value)).toList();
  var sum = 0.0;
  for (final (_, value) in entries) {
    sum += value;
  }

  final legend = entries
      .map(
        (entry) => layoutLabel(
          model.showData ? '${entry.$1} [${_fmtNum(entry.$2)}]' : entry.$1,
          false,
          measurer,
          small,
          4000,
        ),
      )
      .toList();
  var legendWidth = 0.0;
  for (final label in legend) {
    legendWidth = math.max(legendWidth, label.width);
  }
  legendWidth += legend.isNotEmpty ? _SWATCH + 8 : 0;
  final legendHeight = legend.length * _ROW;

  final title = layoutLabel(
    model.title,
    false,
    measurer,
    size,
    titleRoom(options),
    Style.Bold,
  );
  final titleHeight = title.height > 0 ? title.height + 16 : 0.0;

  // A slice too thin for its percentage gets the label outside the rim, which needs a margin.
  final shares = entries.map((entry) {
    final value = entry.$2;
    final share = sum > 0 ? value / sum : 0.0;
    return share * 100 >= 1 && (share * 100).toStringAsFixed(0) != '0'
        ? share
        : 0.0;
  }).toList();
  final narrow = shares.map((share) {
    if (share == 0 || share >= 0.5) return false;
    final chord = 2 * radius * textPosition * math.sin(share * math.pi);
    return chord <
        measurer.width('${(share * 100).toStringAsFixed(0)}%', small, 0) + 6;
  }).toList();
  final margin = narrow.contains(true) ? _OUTSIDE : 0.0;

  final side =
      legendPosition == 'left' ||
          legendPosition == 'right' ||
          legendPosition == 'center'
      ? legendPosition
      : '';
  final stacked = legendPosition == 'top' || legendPosition == 'bottom';
  final diameter = (radius + margin) * 2;
  var width = diameter;
  var height = diameter;
  if (side == 'left' || side == 'right') {
    width += legendWidth > 0 ? _GAP + legendWidth : 0;
    height = math.max(height, legendHeight);
  } else if (stacked) {
    width = math.max(width, legendWidth);
    height += legendHeight > 0 ? 20 + legendHeight : 0;
  }
  width = math.max(width, title.width);

  final cx =
      pad +
      (side == 'left'
          ? legendWidth + _GAP + diameter / 2
          : side == 'right'
          ? diameter / 2
          : width / 2);
  final bodyTop = pad + titleHeight;
  final cy =
      bodyTop +
      (legendPosition == 'top'
          ? legendHeight + 20 + diameter / 2
          : stacked
          ? diameter / 2
          : height / 2);

  final slicesBuf = StringBuffer();
  final labelsBuf = StringBuffer();
  final outsideBuf = StringBuffer();
  var angle = 0.0;
  final rim = radius + _OUTSIDE / 2;
  final placedOutside = <_PlacedOutside>[];
  bool clear(double x, double y, double w) => placedOutside.every(
    (other) =>
        (x - other.x).abs() >= (w + other.width) / 2 + 2 ||
        (y - other.y).abs() >= small + 2,
  );
  for (var index = 0; index < entries.length; index++) {
    final label = entries[index].$1;
    final share = shares[index];
    if (share == 0) continue;
    final end = angle + share * math.pi * 2;
    slicesBuf.write(
      '<path class="pele-slice" data-id="${escText(label)}" d="${_slice(angle, end, radius, inner)}" fill="${seriesColor(index)}"/>',
    );
    final mid = (angle + end) / 2;
    final text = '${(share * 100).toStringAsFixed(0)}%';
    if (narrow[index]) {
      final w = measurer.width(text, small, 0);
      var at = mid;
      for (
        var step = 0;
        step < 360 && !clear(math.sin(at) * rim, -math.cos(at) * rim, w);
        step++
      ) {
        at += 2 / rim;
      }
      final x = math.sin(at) * rim;
      final y = -math.cos(at) * rim;
      placedOutside.add(_PlacedOutside(x: x, y: y, width: w));
      outsideBuf.write(
        '<text x="${num(x)}" y="${num(y + small * 0.35)}">$text</text>',
      );
    } else {
      final r = radius * textPosition;
      labelsBuf.write(
        '<text x="${num(math.sin(mid) * r)}" y="${num(-math.cos(mid) * r + small * 0.35)}"${seriesInkFill(index)}>$text</text>',
      );
    }
    angle = end;
  }
  var slices = slicesBuf.toString();
  if (slices.isEmpty) {
    slices =
        '<circle class="pele-slice" r="${_fmtNum(radius)}" fill="none" stroke="var(--_b)"/>';
  }
  final labels = labelsBuf.toString();
  final outside = outsideBuf.toString();

  final legendOutBuf = StringBuffer();
  double lx;
  double ly;
  if (side == 'right') {
    lx = cx + diameter / 2 + _GAP;
    ly = bodyTop + (height - legendHeight) / 2;
  } else if (side == 'left') {
    lx = pad;
    ly = bodyTop + (height - legendHeight) / 2;
  } else if (side == 'center') {
    lx = cx - legendWidth / 2;
    ly = cy - legendHeight / 2;
  } else {
    lx = pad + (width - legendWidth) / 2;
    ly = legendPosition == 'top' ? bodyTop : bodyTop + diameter + 20;
  }
  for (var index = 0; index < legend.length; index++) {
    final label = legend[index];
    final y = ly + index * _ROW + _ROW / 2;
    legendOutBuf
      ..write(
        '<g class="pele-legend-item" data-id="${escText(entries[index].$1)}">',
      )
      ..write(
        '<rect x="${num(lx)}" y="${num(y - _SWATCH / 2)}" width="$_SWATCH" height="$_SWATCH" rx="2" fill="${seriesColor(index)}"/>',
      )
      ..write(labelSvg(label, lx + _SWATCH + 8 + label.width / 2, y, ''))
      ..write('</g>');
  }
  final legendOut = legendOutBuf.toString();

  final totalWidth = (width + 2 * pad).ceilToDouble();
  final totalHeight = (height + titleHeight + 2 * pad).ceilToDouble();
  final content =
      labelSvg(
        title,
        totalWidth / 2,
        pad + title.height / 2,
        ' class="pele-title" font-weight="var(--_tw)"',
      ) +
      '<g class="pele-slices" transform="translate(${num(cx)},${num(cy)})" stroke="var(--_bg)" stroke-width="1" stroke-linejoin="round">$slices</g>' +
      (labels.isNotEmpty
          ? '<g class="pele-slice-labels" transform="translate(${num(cx)},${num(cy)})" font-size="$smallInt" text-anchor="middle" fill="var(--_bg)">$labels</g>'
          : '') +
      (outside.isNotEmpty
          ? '<g class="pele-slice-labels" transform="translate(${num(cx)},${num(cy)})" font-size="$smallInt" text-anchor="middle">$outside</g>'
          : '') +
      (legendOut.isNotEmpty
          ? '<g class="pele-legend" font-size="$smallInt">$legendOut</g>'
          : '');

  return Rendered(
    svg: svgDocument(
      'pie',
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

// Upstream: src/diagrams/radar/render.ts

import 'dart:math' as math;

import '../../preprocess.dart';
import '../../svg/builder.dart';
import '../../svg/root.dart';
import '../../svg/theme.dart';
import '../../text/label.dart';
import '../../text/measurer.dart';
import '../../types.dart';
import '../../util/math_js.dart';
import '../common/fit_width.dart';
import 'model.dart';

const int _swatch = 12;
const int _row = 26;
const int _gap = 24;

class RadarPoint {
  final double x;
  final double y;

  const RadarPoint({required this.x, required this.y});
}

double _option(
  Config config,
  String key,
  double fallback,
  double min,
  double max,
) {
  final radarConf = config['radar'];
  final value = radarConf is Map ? radarConf[key] : null;
  if (value is int || value is double) {
    final d = value is int ? value.toDouble() : value as double;
    if (d >= min) return math.min(d, max);
  }
  return fallback;
}

double relativeRadius(double value, double min, double max, double radius) {
  final clipped = math.min(math.max(value, min), max);
  final scaled = radius * (clipped - min);
  // Keep the original rounding unless multiplication overflows.
  return scaled.isFinite
      ? scaled / (max - min)
      : radius * ((clipped - min) / (max - min));
}

// A closed Catmull-Rom spline through the points, as cubic Bézier segments.
String closedRoundCurve(List<RadarPoint> points, double tension) {
  final n = points.length;
  final d = StringBuffer('M${num(points[0].x)},${num(points[0].y)}');
  for (var i = 0; i < n; i++) {
    final p0 = points[(i - 1 + n) % n];
    final p1 = points[i];
    final p2 = points[(i + 1) % n];
    final p3 = points[(i + 2) % n];
    d
      ..write(
        ' C${num(p1.x + (p2.x - p0.x) * tension)},${num(p1.y + (p2.y - p0.y) * tension)}',
      )
      ..write(
        ' ${num(p2.x - (p3.x - p1.x) * tension)},${num(p2.y - (p3.y - p1.y) * tension)} ${num(p2.x)},${num(p2.y)}',
      );
  }
  d.write(' Z');
  return d.toString();
}

String _polygon(Iterable<RadarPoint> points) {
  final out = StringBuffer();
  var first = true;
  for (final p in points) {
    if (!first) out.write(' ');
    first = false;
    out.write('${num(p.x)},${num(p.y)}');
  }
  return out.toString();
}

Rendered renderRadar(RadarModel model, Config config, RenderOptions options) {
  final natural = _option(config, 'width', 320, 1, 4000);
  return fitWidth(
    options,
    natural,
    160,
    (width, tight) => _draw(
      model,
      config,
      options,
      width,
      (_option(config, 'height', 320, 1, 4000) * width) / natural,
      tight,
    ),
  );
}

// `tight` is set when the chart does not fit the width it has with its legend beside it.
Rendered _draw(
  RadarModel model,
  Config config,
  RenderOptions options,
  double width,
  double height,
  bool tight,
) {
  final size = options.fontSize ?? 16;
  final small = roundJs(size * 0.875);
  final smallD = small.toDouble();
  final measurer =
      options.measurer ??
      defaultMeasurer(options.fontFamily, options.fontFamilyMono);
  final pad = options.padding ?? 8;

  final axisScale = _option(config, 'axisScaleFactor', 1, 0, 10);
  final labelFactor = _option(config, 'axisLabelFactor', 1.05, 0, 10);
  final tension = _option(config, 'curveTension', 0.17, 0, 1);
  final radius = math.min(width, height) / 2;

  final axes = model.axes;
  final curves = model.curves;
  final ticks = model.options.ticks;
  final graticule = model.options.graticule;
  final min = model.options.min;
  final count = axes.length;
  final unit = List<RadarPoint>.generate(count, (i) {
    final angle = (2 * math.pi * i) / count - math.pi / 2;
    return RadarPoint(x: math.cos(angle), y: math.sin(angle));
  });

  var max = model.options.max;
  if (max == null) {
    var m = double.negativeInfinity;
    for (final curve in curves) {
      for (final value in curve.entries) {
        if (value > m) m = value;
      }
    }
    max = m;
  }

  // The chart is drawn around the origin. Margins reserve space; labels and the legend widen it.
  var x0 = -width / 2 - _option(config, 'marginLeft', 16, 0, 2000);
  var x1 = width / 2 + _option(config, 'marginRight', 16, 0, 2000);
  var y0 = -height / 2 - _option(config, 'marginTop', 16, 0, 2000);
  var y1 = height / 2 + _option(config, 'marginBottom', 16, 0, 2000);

  final grid = StringBuffer();
  for (var i = 0; i < ticks; i++) {
    final r = math.min(radius, (radius * (i + 1)) / ticks);
    if (graticule == 'circle') {
      grid.write('<circle r="${num(r)}"/>');
    } else {
      grid.write(
        '<polygon points="${_polygon(unit.map((u) => RadarPoint(x: u.x * r, y: u.y * r)))}"/>',
      );
    }
  }

  final spokes = StringBuffer();
  final labels = StringBuffer();
  for (var i = 0; i < unit.length; i++) {
    final u = unit[i];
    final reach = radius * axisScale;
    spokes.write('M0,0L${num(u.x * reach)},${num(u.y * reach)}');
    final label = layoutLabel(axes[i].label, false, measurer, smallD, 4000);
    final at = radius * labelFactor + 6;
    // Each label hangs off its axis on the side away from the center.
    final cx =
        u.x * at +
        (u.x > 0.01
            ? label.width / 2
            : u.x < -0.01
            ? -label.width / 2
            : 0);
    final cy =
        u.y * at +
        (u.y > 0.01
            ? label.height / 2
            : u.y < -0.01
            ? -label.height / 2
            : 0);
    labels.write(
      '<g class="pele-axis-label" data-id="${escText(axes[i].name)}">${labelSvg(label, cx, cy, '')}</g>',
    );
    x0 = math.min(x0, cx - label.width / 2);
    x1 = math.max(x1, cx + label.width / 2);
    y0 = math.min(y0, cy - label.height / 2);
    y1 = math.max(y1, cy + label.height / 2);
  }

  final shapes = StringBuffer();
  for (var index = 0; index < curves.length; index++) {
    final curve = curves[index];
    // Mermaid leaves out a curve that does not have a value for every axis.
    if (curve.entries.length != count) continue;
    final points = List<RadarPoint>.generate(count, (i) {
      final r = relativeRadius(curve.entries[i], min, max!, radius);
      final safe = r.isFinite ? r : 0.0;
      return RadarPoint(x: unit[i].x * safe, y: unit[i].y * safe);
    });
    final color = seriesColor(index);
    final attrs =
        ' class="pele-curve" data-id="${escText(curve.name)}" fill="$color" stroke="$color"';
    shapes.write(
      graticule == 'circle'
          ? '<path$attrs d="${closedRoundCurve(points, tension)}"/>'
          : '<polygon$attrs points="${_polygon(points)}"/>',
    );
  }

  final legend = model.options.showLegend
      ? curves
            .map(
              (curve) =>
                  layoutLabel(curve.label, false, measurer, smallD, 4000),
            )
            .toList()
      : <Label>[];
  var legendWidth = 0.0;
  for (final label in legend) {
    legendWidth = math.max(legendWidth, label.width);
  }
  final legendHeight = (legend.length * _row).toDouble();
  final legendX = tight ? -(_swatch + 8 + legendWidth) / 2 : x1 + _gap;
  final legendTop = tight ? y1 + _gap / 2 : -legendHeight / 2;
  if (legend.isNotEmpty && tight) {
    x0 = math.min(x0, legendX);
    x1 = math.max(x1, -legendX);
    y1 = legendTop + legendHeight;
  } else if (legend.isNotEmpty) {
    x1 = legendX + _swatch + 8 + legendWidth;
    y0 = math.min(y0, -legendHeight / 2);
    y1 = math.max(y1, legendHeight / 2);
  }
  final legendOut = StringBuffer();
  for (var index = 0; index < legend.length; index++) {
    final label = legend[index];
    final y = legendTop + index * _row + _row / 2;
    final color = seriesColor(index);
    legendOut
      ..write(
        '<g class="pele-legend-item" data-id="${escText(curves[index].name)}">',
      )
      ..write(
        '<rect x="${num(legendX)}" y="${num(y - _swatch / 2)}" width="$_swatch" height="$_swatch" rx="2" fill="$color" fill-opacity="0.4" stroke="$color"/>',
      )
      ..write(labelSvg(label, legendX + _swatch + 8 + label.width / 2, y, ''))
      ..write('</g>');
  }

  final title = layoutLabel(
    model.title,
    false,
    measurer,
    size,
    titleRoom(options),
    Style.bold,
  );
  final titleHeight = title.height > 0 ? title.height + 8 : 0.0;
  final bodyWidth = math.max(x1 - x0, title.width);
  final totalWidth = (bodyWidth + 2 * pad).ceilToDouble();
  final totalHeight = (y1 - y0 + titleHeight + 2 * pad).ceilToDouble();
  final origin =
      'translate(${num(pad + (bodyWidth - (x1 - x0)) / 2 - x0)},${num(pad + titleHeight - y0)})';

  final gridStr = grid.toString();
  final spokesStr = spokes.toString();
  final shapesStr = shapes.toString();
  final labelsStr = labels.toString();
  final legendStr = legendOut.toString();

  final content =
      labelSvg(
        title,
        totalWidth / 2,
        pad + title.height / 2,
        ' class="pele-title" font-weight="var(--_tw)"',
      ) +
      '<g transform="$origin">' +
      (gridStr.isNotEmpty
          ? '<g class="pele-graticule" fill="none" stroke="var(--_a)">$gridStr</g>'
          : '') +
      (spokesStr.isNotEmpty
          ? '<path class="pele-axes" d="$spokesStr" fill="none" stroke="var(--_b)"/>'
          : '') +
      (shapesStr.isNotEmpty
          ? '<g class="pele-curves" fill-opacity="0.2" stroke-width="1.5" stroke-linejoin="round">$shapesStr</g>'
          : '') +
      (labelsStr.isNotEmpty
          ? '<g class="pele-axis-labels" font-size="$small">$labelsStr</g>'
          : '') +
      (legendStr.isNotEmpty
          ? '<g class="pele-legend" font-size="$small">$legendStr</g>'
          : '') +
      '</g>';

  return Rendered(
    svg: svgDocument(
      'radar',
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

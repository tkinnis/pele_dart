// Upstream: src/diagrams/xychart/render.ts

import 'dart:math' as math;

import '../../errors.dart';
import '../../preprocess.dart';
import '../../svg/builder.dart';
import '../../svg/root.dart';
import '../../svg/theme.dart';
import '../../text/label.dart';
import '../../text/measurer.dart';
import '../../types.dart';
import '../../util/math_js.dart';
import '../common/fit_width.dart';
import 'db.dart';
import 'ticks.dart';

const int _tick = 4;
const int _swatch = 12;
const double _row = 26;
const double _legendGap = 24;
const double _limit = 1e300;

class _Mark {
  final double at;
  final Label label;

  const _Mark({required this.at, required this.label});
}

class _LegendItem {
  final int index;
  final Label label;

  const _LegendItem({required this.index, required this.label});
}

Config _record(Object? value) => asConfig(value);

bool _on(Config config, String key, [bool fallback = true]) {
  final value = config[key];
  return value is bool ? value : fallback;
}

double _dimension(Object? value, double fallback) {
  if (value is int || value is double) {
    final d = value is int ? value.toDouble() : value as double;
    if (d > 0) {
      return roundJs(math.min(math.max(d, 100.0), 4000.0)).toDouble();
    }
  }
  return fallback;
}

double? _finite(double? value) {
  return value != null && value.isFinite
      ? math.min(math.max(value, -_limit), _limit)
      : null;
}

double _widest(List<_Mark> marks) {
  var width = 0.0;
  for (final mark in marks) {
    width = math.max(width, mark.label.width);
  }
  return width;
}

String _jsNumberString(double v) {
  if (v == 0) return '0';
  final s = v.toString();
  if (!s.contains('e') && v == v.truncateToDouble() && v.abs() < 1e21) {
    return v.toInt().toString();
  }
  return s;
}

// Writes a label with its left edge, center or right edge at x. A plain one-line label keeps
// its place when the text is wider or narrower than measured.
String _aligned(Label label, double x, double y, String anchor) {
  final line = label.lines.length == 1 ? label.lines[0] : null;
  if (line != null &&
      line.length == 1 &&
      line[0].icon == null &&
      line[0].style == 0) {
    return '<text x="${num(x)}" y="${num(y + label.size * 0.35)}" text-anchor="$anchor">${esc(line[0].text)}</text>';
  }
  return labelSvg(
    label,
    x +
        (anchor == 'start'
            ? label.width / 2
            : anchor == 'end'
            ? -label.width / 2
            : 0),
    y,
    '',
  );
}

Rendered renderXyChart(
  XyChartModel model,
  Config config,
  RenderOptions options,
) {
  if (model.plots.isEmpty) {
    throw PeleError(
      'No Plot to render, please provide a plot with some data',
      'semantic',
      const PeleErrorInfo(type: 'xychart'),
    );
  }
  final chart = _record(config['xyChart']);
  final size = options.fontSize ?? 16;
  final small = roundJs(size * 0.875);
  final tiny = roundJs(size * 0.75);
  final smallD = small.toDouble();
  final tinyD = tiny.toDouble();
  final measurer =
      options.measurer ??
      defaultMeasurer(options.fontFamily, options.fontFamilyMono);
  final pad = options.padding ?? 8;
  final natural = _dimension(chart['width'], 700);
  final width = capWidth(options, natural, 240);
  // A narrower chart is not as much shorter, so that the plot keeps room for its marks.
  final height = roundJs(
    _dimension(chart['height'], 500) * math.max(0.6, width / natural),
  ).toDouble();
  final horizontal =
      (model.orientation ?? chart['chartOrientation']) == 'horizontal';
  // The value of a bar is always written past its end, which is what showDataLabelOutsideBar asks
  // for in Mermaid. Inside, whether it fits changes from bar to bar and with the width of the chart.
  final showValues = _on(chart, 'showDataLabel', false);
  final x = model.xAxis;
  final plots = model.plots;
  Label text(String? raw, double fontSize, double max) =>
      layoutLabel(raw, false, measurer, fontSize, max);
  final lineHeight = text('0', smallD, 4000).height;
  final tinyHeight = text('0', tinyD, 4000).height;

  final title = layoutLabel(
    _on(chart, 'showTitle') ? model.title : null,
    false,
    measurer,
    size,
    width - 2 * pad,
    Style.bold,
  );
  final titleSpace = title.height > 0 ? title.height + 12 : 0.0;

  final legend = <_LegendItem>[];
  var legendWidth = 0.0;
  if (_on(chart, 'showLegend')) {
    for (var index = 0; index < plots.length; index++) {
      final plot = plots[index];
      if (plot.title.isEmpty) continue;
      final label = text(plot.title, smallD, width * 0.3);
      legend.add(_LegendItem(index: index, label: label));
      legendWidth = math.max(legendWidth, label.width + _swatch + 8);
    }
  }
  final legendSpace = legend.isNotEmpty ? legendWidth + _legendGap : 0.0;

  // The value range: as written, or taken from the data, where bars stand on zero and the
  // range grows to whole steps.
  final bars = plots.where((plot) => plot.type == 'bar').length;
  var lo = _finite(model.yAxis.min) ?? double.infinity;
  var hi = _finite(model.yAxis.max) ?? double.negativeInfinity;
  final exact = model.hasSetYAxis && lo.isFinite && hi.isFinite && lo != hi;
  if (!exact) {
    lo = double.infinity;
    hi = double.negativeInfinity;
    for (final plot in plots) {
      for (final (_, raw) in plot.data) {
        final value = _finite(raw);
        if (value == null) continue;
        if (value < lo) lo = value;
        if (value > hi) hi = value;
      }
    }
    if (lo > hi) {
      lo = hi = 0;
    }
    if (bars > 0) {
      lo = math.min(lo, 0);
      hi = math.max(hi, 0);
    }
    if (lo == hi) {
      if (lo == 0) {
        hi = 1;
      } else {
        lo -= lo.abs() / 2;
        hi += hi.abs() / 2;
      }
    }
  }

  List<_Mark> valueMarks(double length, double spacing) {
    final step = tickStep(
      (hi - lo).abs(),
      math.max<int>(2, math.min<int>(10, (length / spacing).floor())),
    );
    if (!exact) {
      lo = tickValue(step, (tickIndex(step, lo) + 1e-9).floor());
      hi = tickValue(step, (tickIndex(step, hi) - 1e-9).ceil());
    }
    return ticksBetween(math.min(lo, hi), math.max(lo, hi), step)
        .map(
          (value) => _Mark(
            at: (value - lo) / (hi - lo),
            label: text(_jsNumberString(value), smallD, 4000),
          ),
        )
        .toList();
  }

  // Places along the category axis are fractions of its length. Categories and bars sit in the
  // middle of equal slots; the points of a line on a numeric axis run from end to end.
  var count = 1;
  if (x is BandAxis) {
    count = math.max<int>(x.categories.length, 1);
  } else {
    for (final plot in plots) {
      count = math.max<int>(count, plot.data.length);
    }
  }
  final slot = 1 / count;
  final inset = x is BandAxis || bars > 0 ? slot / 2 : 0.0;
  final x0 = _finite(x is LinearAxis ? x.min : null);
  final x1 = _finite(x is LinearAxis ? x.max : null);
  final ranged = x0 != null && x1 != null && x0 != x1;
  double place(int i, int n) => x is BandAxis
      ? (i + 0.5) * slot
      : inset + (n > 1 ? i / (n - 1) : (ranged ? 0 : 0.5)) * (1 - 2 * inset);

  final categoryConf = _record(chart['xAxis']);
  final valueConf = _record(chart['yAxis']);
  final leftConf = horizontal ? categoryConf : valueConf;
  final bottomConf = horizontal ? valueConf : categoryConf;
  final leftTitle = text(
    _on(leftConf, 'showTitle')
        ? (horizontal ? x.title : model.yAxis.title)
        : null,
    smallD,
    height * 0.8,
  );
  final bottomTitle = text(
    _on(bottomConf, 'showTitle')
        ? (horizontal ? model.yAxis.title : x.title)
        : null,
    smallD,
    width * 0.8,
  );
  final leftTick = _on(leftConf, 'showTick') ? _tick : 0;
  final bottomTick = _on(bottomConf, 'showTick') ? _tick : 0;
  final leftLabels = _on(leftConf, 'showLabel');
  final bottomLabels = _on(bottomConf, 'showLabel');

  final wrapAt = horizontal
      ? width * 0.3
      : math.max(48.0, (width - 2 * pad - 64 - legendSpace) * slot - 8);
  final categories = x is BandAxis && _on(categoryConf, 'showLabel')
      ? x.categories.map((category) => text(category, smallD, wrapAt)).toList()
      : <Label>[];
  var categoryWidth = 0.0;
  var categoryHeight = 0.0;
  for (final label in categories) {
    categoryWidth = math.max(categoryWidth, label.width);
    categoryHeight = math.max(categoryHeight, label.height);
  }

  // The labelled places of the category axis. Labels that would run into each other are thinned out.
  List<_Mark> categoryMarks(double length) {
    final marks = <_Mark>[];
    if (x is BandAxis) {
      final need = categories.isEmpty
          ? 8.0
          : (horizontal ? categoryHeight : categoryWidth + 12);
      final every = math.max<int>(1, (need / (length * slot)).ceil());
      for (var i = 0; i < x.categories.length; i += every) {
        marks.add(
          _Mark(
            at: (i + 0.5) * slot,
            label: i < categories.length
                ? categories[i]
                : text(null, smallD, 0),
          ),
        );
      }
    } else if (ranged) {
      final step = tickStep(
        (x1 - x0).abs(),
        math.max<int>(
          2,
          math.min<int>(10, (length / (horizontal ? 32 : 80)).floor()),
        ),
      );
      for (final value in ticksBetween(
        math.min(x0, x1),
        math.max(x0, x1),
        step,
      )) {
        marks.add(
          _Mark(
            at: inset + ((value - x0) / (x1 - x0)) * (1 - 2 * inset),
            label: text(_jsNumberString(value), smallD, 4000),
          ),
        );
      }
    } else if (x0 != null) {
      marks.add(_Mark(at: 0.5, label: text(_jsNumberString(x0), smallD, 4000)));
    }
    return marks;
  }

  // Room past the end of the value axis for what is written beside a point or a bar.
  var pointLabelWidth = 0.0;
  var valueWidth = 0.0;
  for (final plot in plots) {
    for (final label in plot.pointLabels ?? const <String>[]) {
      pointLabelWidth = math.max(
        pointLabelWidth,
        measurer.width(label, tinyD, 0),
      );
    }
    if (showValues && horizontal && plot.type == 'bar') {
      for (final (_, value) in plot.data) {
        final f = _finite(value);
        valueWidth = math.max(
          valueWidth,
          measurer.width(f != null ? _jsNumberString(f) : '', tinyD, 0),
        );
      }
    }
  }

  final bottomLabelHeight = !bottomLabels
      ? 0.0
      : (horizontal || x is! BandAxis ? lineHeight : categoryHeight);
  final bottomSpace =
      bottomTick +
      (bottomLabelHeight > 0 ? bottomLabelHeight + 4 : 0) +
      (bottomTitle.height > 0 ? bottomTitle.height + 4 : 0);
  final headroom = horizontal
      ? 0.0
      : (pointLabelWidth > 0 || showValues
            ? tinyHeight + 4
            : (leftLabels ? lineHeight / 2 : 0.0));
  final top = pad + titleSpace + headroom;
  final plotHeight = math.max(1.0, height - pad - bottomSpace - top);
  final bottom = top + plotHeight;

  final leftMarks = horizontal
      ? categoryMarks(plotHeight)
      : valueMarks(plotHeight, 56);
  final leftLabelWidth = leftLabels ? _widest(leftMarks) : 0.0;
  final left =
      pad +
      (leftTitle.height > 0 ? leftTitle.height + 6 : 0) +
      (leftLabelWidth > 0 ? leftLabelWidth + 6 : 0) +
      leftTick;
  final beside = math.max(
    pointLabelWidth > 0 ? pointLabelWidth + 12 : 0.0,
    valueWidth > 0 ? valueWidth + 8 : 0.0,
  );
  final reach = horizontal ? math.min(width * 0.25, beside) : 0.0;
  var plotWidth = math.max(1.0, width - pad - left - legendSpace - reach);
  final bottomMarks = horizontal
      ? valueMarks(plotWidth, 80)
      : categoryMarks(plotWidth);
  if (bottomLabels && legendSpace + reach == 0) {
    var over = 0.0;
    for (final mark in bottomMarks) {
      over = math.max(
        over,
        mark.at * plotWidth + mark.label.width / 2 - plotWidth,
      );
    }
    plotWidth = math.max(1.0, plotWidth - over);
  }
  final right = left + plotWidth;

  double px(double c, double v) =>
      horizontal ? left + v * plotWidth : left + c * plotWidth;
  double py(double c, double v) =>
      horizontal ? top + c * plotHeight : bottom - v * plotHeight;
  double scale(double value) => (value - lo) / (hi - lo);
  double clamp(double v) => math.min(math.max(v, 0.0), 1.0);

  // A line across the plot at a place on the value axis.
  String rule(double v) => horizontal
      ? 'M${num(px(0, v))},${num(top)}V${num(bottom)}'
      : 'M${num(left)},${num(py(0, v))}H${num(right)}';

  final grid = StringBuffer();
  for (final mark in horizontal ? bottomMarks : leftMarks) {
    grid.write(rule(mark.at));
  }

  final axis = StringBuffer();
  final labels = StringBuffer();
  if (_on(leftConf, 'showAxisLine')) {
    axis.write('M${num(left)},${num(top)}V${num(bottom)}');
  }
  if (_on(bottomConf, 'showAxisLine')) {
    axis.write('M${num(left)},${num(bottom)}H${num(right)}');
  }
  for (final mark in leftMarks) {
    final y = horizontal
        ? top + mark.at * plotHeight
        : bottom - mark.at * plotHeight;
    if (leftTick != 0) axis.write('M${num(left)},${num(y)}h${-leftTick}');
    if (leftLabels) {
      labels.write(_aligned(mark.label, left - leftTick - 6, y, 'end'));
    }
  }
  for (final mark in bottomMarks) {
    final at = left + mark.at * plotWidth;
    if (bottomTick != 0) axis.write('M${num(at)},${num(bottom)}v$bottomTick');
    if (bottomLabels) {
      labels.write(
        _aligned(
          mark.label,
          at,
          bottom + bottomTick + 4 + mark.label.height / 2,
          'middle',
        ),
      );
    }
  }

  final span = (horizontal ? plotHeight : plotWidth) * slot;
  final group = span * 0.7;
  final thickness = group / math.max<int>(bars, 1);
  final gap = bars > 1 ? math.min(2.0, thickness * 0.2) : 0.0;
  final base = clamp(scale(0));
  // Bars that go both ways get a line to stand on.
  if (bars > 0 && base > 0 && base < 1) axis.write(rule(base));
  // Lines are drawn over the bars wherever they were declared, as a bar would hide part of one
  // under it. A series keeps the color of its place in the source.
  final series = StringBuffer();
  final lines = StringBuffer();
  final outside = StringBuffer();
  final pointLabels = StringBuffer();
  var bar = 0;
  for (var index = 0; index < plots.length; index++) {
    final plot = plots[index];
    final color = seriesColor(index);
    final id = plot.title.isNotEmpty ? ' data-id="${escText(plot.title)}"' : '';
    // A series declared before the categories can hold more values than there are categories.
    final n = x is BandAxis
        ? math.min<int>(plot.data.length, count)
        : plot.data.length;
    if (plot.type == 'bar') {
      final offset =
          (bar++ - (bars - 1) / 2) * thickness - (thickness - gap) / 2;
      final rects = StringBuffer();
      for (var i = 0; i < n; i++) {
        final value = _finite(plot.data[i].$2);
        if (value == null) continue;
        final c = place(i, n);
        final v = clamp(scale(value));
        final from = math.min(base, v);
        final to = math.max(base, v);
        final bx = horizontal ? px(c, from) : px(c, 0) + offset;
        final by = horizontal ? py(c, 0) + offset : py(c, to);
        final bw = horizontal ? (to - from) * plotWidth : thickness - gap;
        final bh = horizontal ? thickness - gap : (to - from) * plotHeight;
        rects.write(
          '<rect x="${num(bx)}" y="${num(by)}" width="${num(bw)}" height="${num(bh)}"/>',
        );
        if (!showValues) continue;
        final label = _jsNumberString(value);
        final w = measurer.width(label, tinyD, 0);
        // Towards the end of the bar: 1 when it runs up or right from the baseline, -1 the other way.
        final out = v >= base ? 1 : -1;
        var tx = bx + bw / 2;
        var ty = by + bh / 2;
        var anchor = 'middle';
        if (horizontal) {
          if (bh < tinyD) continue;
          tx = (out > 0 ? bx + bw : bx) + out * 6;
          anchor = out > 0 ? 'start' : 'end';
        } else {
          if (w + 2 > span / bars) continue;
          ty = (out > 0 ? by : by + bh) - out * (tinyHeight / 2 + 2);
        }
        outside.write(
          '<text x="${num(tx)}" y="${num(ty + tinyD * 0.35)}" text-anchor="$anchor">$label</text>',
        );
      }
      series.write(
        '<g class="pele-series pele-bars"$id fill="$color">$rects</g>',
      );
      continue;
    }

    // A line is cut where it leaves the value range, so it stays inside the plot.
    final d = StringBuffer();
    final dots = StringBuffer();
    var pen = false;
    var pc = 0.0;
    var pv = double.nan;
    for (var i = 0; i < n; i++) {
      final value = _finite(plot.data[i].$2);
      if (value == null) {
        pv = double.nan;
        continue;
      }
      final c = place(i, n);
      final v = scale(value);
      final visible = v >= 0 && v <= 1;
      if (pv.isNaN) {
        if (visible) d.write('M${num(px(c, v))},${num(py(c, v))}');
        pen = visible;
      } else {
        final dv = v - pv;
        var t0 = 0.0;
        var t1 = 1.0;
        if (dv != 0) {
          final a = -pv / dv;
          final b = (1 - pv) / dv;
          t0 = math.max(t0, math.min(a, b));
          t1 = math.min(t1, math.max(a, b));
        } else if (!visible) {
          t0 = 2.0;
        }
        if (t0 <= t1) {
          final c0 = pc + (c - pc) * t0;
          final v0 = pv + dv * t0;
          final c1 = pc + (c - pc) * t1;
          final v1 = pv + dv * t1;
          if (!pen || t0 > 0) {
            d.write('M${num(px(c0, v0))},${num(py(c0, v0))}');
          }
          d.write('L${num(px(c1, v1))},${num(py(c1, v1))}');
        }
        pen = visible;
      }
      pc = c;
      pv = v;
      if (!visible) continue;
      final cx = px(c, v);
      final cy = py(c, v);
      if (span >= 12) {
        dots.write('<circle cx="${num(cx)}" cy="${num(cy)}" r="3"/>');
      }
      final rawPointLabel =
          (plot.pointLabels != null && i < plot.pointLabels!.length)
          ? plot.pointLabels![i]
          : null;
      final label = text(rawPointLabel, tinyD, 4000);
      if (label.height > 0) {
        final half = label.width / 2;
        pointLabels.write(
          horizontal
              ? _aligned(label, cx + 10, cy, 'start')
              : _aligned(
                  label,
                  math.max(math.min(cx, right - half), left + half),
                  cy - 6 - label.height / 2,
                  'middle',
                ),
        );
      }
    }
    final dStr = d.toString();
    lines.write(
      '<g class="pele-series pele-line"$id fill="$color">'
      '${dStr.isNotEmpty ? '<path d="$dStr" fill="none" stroke="$color" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>' : ''}'
      '$dots'
      '</g>',
    );
  }

  final titles = StringBuffer();
  if (leftTitle.height > 0) {
    titles.write(
      '<g transform="translate(${num(pad + leftTitle.height / 2)},${num(top + plotHeight / 2)}) rotate(-90)">${labelSvg(leftTitle, 0, 0, '')}</g>',
    );
  }
  titles.write(
    labelSvg(
      bottomTitle,
      left + plotWidth / 2,
      height - pad - bottomTitle.height / 2,
      '',
    ),
  );

  final legendOut = StringBuffer();
  var legendHeight = 0.0;
  for (final item in legend) {
    legendHeight += math.max(_row, item.label.height + 6);
  }
  var ly = top + math.max(0.0, (plotHeight - legendHeight) / 2);
  final lx = right + reach + _legendGap;
  for (final item in legend) {
    final index = item.index;
    final label = item.label;
    final row = math.max(_row, label.height + 6);
    if (ly + row > height) break;
    final y = ly + row / 2;
    final color = seriesColor(index);
    legendOut
      ..write(
        '<g class="pele-legend-item" data-id="${escText(plots[index].title)}">',
      )
      ..write(
        plots[index].type == 'bar'
            ? '<rect x="${num(lx)}" y="${num(y - _swatch / 2)}" width="$_swatch" height="$_swatch" rx="2" fill="$color"/>'
            : '<path d="M${num(lx)},${num(y)}h$_swatch" stroke="$color" stroke-width="2" stroke-linecap="round"/>',
      )
      ..write(labelSvg(label, lx + _swatch + 8 + label.width / 2, y, ''))
      ..write('</g>');
    ly += row;
  }

  final gridStr = grid.toString();
  final axisStr = axis.toString();
  final labelsStr = labels.toString();
  final titlesStr = titles.toString();
  final outsideStr = outside.toString();
  final pointLabelsStr = pointLabels.toString();
  final legendStr = legendOut.toString();

  final content =
      labelSvg(
        title,
        width / 2,
        pad + title.height / 2,
        ' class="pele-title" font-weight="var(--_tw)"',
      ) +
      (gridStr.isNotEmpty
          ? '<path class="pele-grid" d="$gridStr" stroke="var(--_a)"/>'
          : '') +
      '<g class="pele-plot">$series$lines</g>' +
      (axisStr.isNotEmpty
          ? '<path class="pele-axis" d="$axisStr" fill="none" stroke="var(--_b)"/>'
          : '') +
      (labelsStr.isNotEmpty
          ? '<g class="pele-axis-labels" font-size="$small" fill="var(--_m)">$labelsStr</g>'
          : '') +
      (titlesStr.isNotEmpty
          ? '<g class="pele-axis-titles" font-size="$small">$titlesStr</g>'
          : '') +
      (outsideStr.isNotEmpty
          ? '<g class="pele-data-labels" font-size="$tiny">$outsideStr</g>'
          : '') +
      (pointLabelsStr.isNotEmpty
          ? '<g class="pele-point-labels" font-size="$tiny">$pointLabelsStr</g>'
          : '') +
      (legendStr.isNotEmpty
          ? '<g class="pele-legend" font-size="$small">$legendStr</g>'
          : '');

  return Rendered(
    svg: svgDocument('xychart', width, height, size, options, model, content),
    width: width,
    height: height,
    links: <LinkInfo>[],
  );
}

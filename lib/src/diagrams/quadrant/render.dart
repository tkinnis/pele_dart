// Upstream: src/diagrams/quadrant/render.ts

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
import 'db.dart';

const double _gap = 4;
const int _careful = 300;

class _Dot {
  const _Dot({
    required this.cx,
    required this.cy,
    required this.reach,
    required this.text,
  });

  final double cx;
  final double cy;
  final double reach;
  final Label text;
}

Object? _setting(Config config, String key) {
  final qc = config['quadrantChart'];
  return qc is Map ? qc[key] : null;
}

double? _asNumber(Object? value) {
  if (value is int) return value.toDouble();
  if (value is double) return value;
  return null;
}

double _length(Config config, String key, double fallback, double max) {
  final value = _asNumber(_setting(config, key));
  return value != null && value >= 0 ? math.min(value, max) : fallback;
}

// Mermaid's quadrantChart font size keys; without them the sizes follow fontSize.
double _textSize(Config config, String key, double fallback) {
  final value = _asNumber(_setting(config, key));
  return value != null && value.isFinite
      ? math.min(72.0, math.max(4.0, value))
      : fallback;
}

String _hex(String color) {
  return color.startsWith('#') ? color : '#$color';
}

String _fmtNum(double v) => v == v.truncateToDouble() ? '${v.toInt()}' : '$v';

Rendered renderQuadrant(
  QuadrantModel model,
  Config config,
  RenderOptions options,
) {
  final size = options.fontSize ?? 16;
  final titleSize = _textSize(config, 'titleFontSize', size);
  final quadrantSize = _textSize(config, 'quadrantLabelFontSize', size);
  final xAxisSize = _textSize(
    config,
    'xAxisLabelFontSize',
    roundJs(size * 0.875).toDouble(),
  );
  final yAxisSize = _textSize(
    config,
    'yAxisLabelFontSize',
    roundJs(size * 0.875).toDouble(),
  );
  final pointSize = _textSize(
    config,
    'pointLabelFontSize',
    roundJs(size * 0.75).toDouble(),
  );
  // Sizes that differ from the one a label inherits.
  String sizeAttr(double own, double inherited) =>
      own == inherited ? '' : ' font-size="${_fmtNum(own)}"';
  final measurer =
      options.measurer ??
      defaultMeasurer(options.fontFamily, options.fontFamilyMono);
  final natural = roundJs(
    math.max(100.0, _length(config, 'chartWidth', 500, 4000)),
  ).toDouble();
  final width = roundJs(capWidth(options, natural, 280)).toDouble();
  final height = roundJs(
    (math.max(100.0, _length(config, 'chartHeight', 500, 4000)) * width) /
        natural,
  ).toDouble();
  final outer = _length(config, 'quadrantPadding', options.padding ?? 8, 200);
  final xPad = _length(config, 'xAxisLabelPadding', 5, 200);
  final yPad = _length(config, 'yAxisLabelPadding', 5, 200);
  final hasPoints = model.points.isNotEmpty;

  Label label(QuadrantText? text, double fontSize, double max) => layoutLabel(
    text?.text,
    text?.type == 'markdown',
    measurer,
    fontSize,
    math.max(max, 40.0),
  );

  final title = layoutLabel(
    model.title,
    false,
    measurer,
    titleSize,
    math.max(width - 2 * outer, 40.0),
    Style.Bold,
  );
  final titlePad = _length(config, 'titlePadding', 10, 200);
  final titleSpace = title.height > 0 ? title.height + titlePad : 0.0;

  final hasX =
      (model.xAxisLeft?.text.isNotEmpty ?? false) ||
      (model.xAxisRight?.text.isNotEmpty ?? false);
  final hasY =
      (model.yAxisBottom?.text.isNotEmpty ?? false) ||
      (model.yAxisTop?.text.isNotEmpty ?? false);
  // Mermaid moves the x axis labels below the chart as soon as there are points.
  final xBelow = hasPoints || _setting(config, 'xAxisPosition') == 'bottom';
  final yRight = _setting(config, 'yAxisPosition') == 'right';

  final side = width - 2 * outer;
  final xLeft = label(
    model.xAxisLeft,
    xAxisSize,
    model.xAxisRight != null ? side / 2 - 16 : side,
  );
  final xRight = label(model.xAxisRight, xAxisSize, side / 2 - 16);
  final xHeight = math.max(xLeft.height, xRight.height);
  final xSpace = hasX ? xHeight + xPad : 0.0;
  final tall = height - 2 * outer - titleSpace - xSpace;
  final yBottom = label(
    model.yAxisBottom,
    yAxisSize,
    model.yAxisTop != null ? tall / 2 - 16 : tall,
  );
  final yTop = label(model.yAxisTop, yAxisSize, tall / 2 - 16);
  final yHeight = math.max(yBottom.height, yTop.height);
  final ySpace = hasY ? yHeight + yPad : 0.0;

  final left = outer + (yRight ? 0.0 : ySpace);
  final top = outer + titleSpace + (xBelow ? 0.0 : xSpace);
  final w = math.max(0.0, side - ySpace);
  final h = math.max(0.0, tall);
  final tileW = math.max(0.0, (w - _gap) / 2);
  final tileH = math.max(0.0, (h - _gap) / 2);

  // Boxes a point label keeps clear of: the gaps between quadrants, quadrant labels, points,
  // and the labels placed before it.
  final taken = <double>[
    left + tileW,
    top,
    left + w - tileW,
    top + h,
    left,
    top + tileH,
    left + w,
    top + h - tileH,
  ];
  bool isClear(int from, double x0, double y0, double x1, double y1) {
    for (var k = from; k < taken.length; k += 4) {
      // Empty quadrant labels must not block point labels.
      if (taken[k] >= taken[k + 2] || taken[k + 1] >= taken[k + 3]) continue;
      if (x0 < taken[k + 2] &&
          x1 > taken[k] &&
          y0 < taken[k + 3] &&
          y1 > taken[k + 1]) {
        return false;
      }
    }
    return true;
  }

  final textTop = _length(config, 'quadrantTextTopPadding', 5, 200);
  final quadrants = StringBuffer();
  for (var k = 0; k < 4; k++) {
    final x = k == 0 || k == 3 ? left + w - tileW : left;
    final y = k < 2 ? top : top + h - tileH;
    final text = label(model.quadrants[k], quadrantSize, tileW - 16);
    final cx = x + tileW / 2;
    final cy = hasPoints ? y + textTop + text.height / 2 : y + tileH / 2;
    taken.addAll(<double>[
      cx - text.width / 2,
      cy - text.height / 2,
      cx + text.width / 2,
      cy + text.height / 2,
    ]);
    quadrants.write(
      '<g class="pele-quadrant" data-id="${k + 1}">'
      '<rect x="${num(x)}" y="${num(y)}" width="${num(tileW)}" height="${num(tileH)}"$roundedAttr/>'
      '${labelSvg(text, cx, cy, ' class="pele-label"${sizeAttr(quadrantSize, size)} fill="var(--_fg)" stroke="none"')}'
      '</g>',
    );
  }

  final axes = StringBuffer();
  if (hasX) {
    final y = xBelow ? top + h + xPad + xHeight / 2 : top - xPad - xHeight / 2;
    axes.write(
      labelSvg(
            xLeft,
            xRight.height > 0 ? left + w / 4 : left + xLeft.width / 2,
            y,
            '',
          ) +
          labelSvg(xRight, left + (w * 3) / 4, y, ''),
    );
  }
  if (hasY) {
    final x = yRight
        ? left + w + yPad + yHeight / 2
        : left - yPad - yHeight / 2;
    String turned(Label text, double y) => text.height > 0
        ? '<g transform="translate(${num(x)},${num(y)}) rotate(-90)"${sizeAttr(yAxisSize, xAxisSize)}>${labelSvg(text, 0, 0, '')}</g>'
        : '';
    axes.write(
      turned(
            yBottom,
            yTop.height > 0 ? top + (h * 3) / 4 : top + h - yBottom.width / 2,
          ) +
          turned(yTop, top + h / 4),
    );
  }

  final radius = _length(config, 'pointRadius', 5, 200);
  final textPad = _length(config, 'pointTextPadding', 5, 200);
  final fill = seriesColor(0);
  final dots = <_Dot>[];
  final circles = <String>[];
  for (final point in model.points) {
    if (!(point.x >= 0 && point.x <= 1 && point.y >= 0 && point.y <= 1)) {
      continue;
    }
    final shared = model.classes[point.className];
    final r = math.min(point.radius ?? shared?.radius ?? radius, 2000.0);
    final color = point.color ?? shared?.color;
    final strokeColor = point.strokeColor ?? shared?.strokeColor;
    final strokeWidth = point.strokeWidth ?? shared?.strokeWidth;
    final styles = <String>[];
    if (color != null && color.isNotEmpty) styles.add('fill:${_hex(color)}');
    if (strokeWidth != null && strokeWidth.isNotEmpty) {
      if (strokeColor != null && strokeColor.isNotEmpty) {
        styles.add('stroke:${_hex(strokeColor)}');
      }
      styles.add('stroke-width:$strokeWidth');
    }
    final cx = left + point.x * w;
    final cy = top + (1 - point.y) * h;
    var swPx = 0.0;
    if (strokeWidth != null && strokeWidth.isNotEmpty) {
      final rawNum = strokeWidth.endsWith('px')
          ? strokeWidth.substring(0, strokeWidth.length - 2)
          : strokeWidth;
      swPx = math.min(double.tryParse(rawNum) ?? 0.0, 400.0) / 2;
    }
    dots.add(
      _Dot(
        cx: cx,
        cy: cy,
        reach: r + swPx,
        // Mermaid keeps point labels on one line; wrap only what is wider than the plot.
        text: label(point.text, pointSize, w),
      ),
    );
    final hasSw = strokeWidth != null && strokeWidth.isNotEmpty;
    final hasSc = strokeColor != null && strokeColor.isNotEmpty;
    circles.add(
      '<circle class="pele-point${classNames(point.className)}" data-id="${escText(point.text.text)}" cx="${num(cx)}" cy="${num(cy)}" r="${num(r)}"${hasSw && !hasSc ? ' stroke="$fill"' : ''}${resolveStyle(styles).shape}/>',
    );
  }

  // A label goes below its point, or above, right or left of it, or below its quadrant's title,
  // when that is the first place that is inside the chart and free. A second round lets it
  // cross the gaps between quadrants.
  // Large charts skip the search for a free place.
  final careful = dots.length <= _careful;
  if (careful) {
    for (final dot in dots) {
      taken.addAll(<double>[
        dot.cx - dot.reach,
        dot.cy - dot.reach,
        dot.cx + dot.reach,
        dot.cy + dot.reach,
      ]);
    }
  }
  final labels = StringBuffer();
  for (final dot in dots) {
    final cx = dot.cx;
    final cy = dot.cy;
    final reach = dot.reach;
    final text = dot.text;
    final halfW = text.width / 2;
    final halfH = text.size * 0.6 + (text.height - text.lineHeight) / 2;
    final away = reach + textPad;
    final inset = math.min(away, math.max(0.0, (tileW - text.width) / 2));
    final heading =
        8 +
        4 *
            (cx < left + w / 2
                ? (cy < top + h / 2 ? 1 : 2)
                : (cy < top + h / 2 ? 0 : 3));
    final below = math.max(cy + away, taken[heading + 3] + textPad) + halfH;
    final spots = <double>[
      cx,
      cy + away + halfH,
      cx,
      cy - away - halfH,
      cx + away + halfW,
      cy,
      cx - away - halfW,
      cy,
      cx,
      below,
    ];
    var tx = cx;
    var ty = spots[1];
    var found = false;
    for (var k = 0; k < 20; k += 2) {
      final spot = k % 10;
      // A label moved below a title keeps clear of the plot's edge.
      final margin = spot == 8 ? inset : 0.0;
      final x = (spot < 4 || spot == 8) && text.width < w
          ? math.min(
              math.max(spots[spot], left + halfW + margin),
              left + w - halfW - margin,
            )
          : spots[spot];
      final y = spots[spot + 1];
      if (x - halfW < left ||
          x + halfW > left + w ||
          y - halfH < top ||
          y + halfH > top + h) {
        continue;
      }
      final free =
          !careful ||
          isClear(k < 10 ? 0 : 8, x - halfW, y - halfH, x + halfW, y + halfH);
      if (!found || free) {
        tx = x;
        ty = y;
        found = true;
      }
      if (free) break;
    }
    if (careful) {
      taken.addAll(<double>[tx - halfW, ty - halfH, tx + halfW, ty + halfH]);
    }
    labels.write(labelSvg(text, tx, ty, ' class="pele-label"'));
  }

  // Mermaid puts each new point under the ones before it.
  final axesStr = axes.toString();
  final content =
      labelSvg(
        title,
        width / 2,
        titlePad / 2 + title.height / 2,
        ' class="pele-title"${sizeAttr(titleSize, size)} font-weight="var(--_tw)"',
      ) +
      '<g class="pele-quadrants" fill="var(--_s)" stroke="var(--_b)">$quadrants</g>' +
      (axesStr.isNotEmpty
          ? '<g class="pele-axis-labels" font-size="${_fmtNum(xAxisSize)}" fill="var(--_m)">$axesStr</g>'
          : '') +
      (dots.isNotEmpty
          ? '<g class="pele-points" fill="$fill">${circles.reversed.join()}</g>'
                '<g class="pele-point-labels" font-size="${_fmtNum(pointSize)}">$labels</g>'
          : '');

  return Rendered(
    svg: svgDocument(
      'quadrantChart',
      width,
      height,
      size,
      options,
      model,
      content,
    ),
    width: width,
    height: height,
    links: <LinkInfo>[],
  );
}

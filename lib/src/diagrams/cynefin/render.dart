// Upstream: src/diagrams/cynefin/render.ts

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
import 'boundaries.dart';
import 'model.dart';

// [domain, column, row, series color]
const List<(DomainName, int, int, int)> _quadrants =
    <(DomainName, int, int, int)>[
      ('complex', 0, 0, 0),
      ('complicated', 1, 0, 1),
      ('chaotic', 0, 1, 3),
      ('clear', 1, 1, 2),
    ];
const int _confusionColor = 4;

// [name, decision model, kind of practice]
const Map<DomainName, (String, String, String)> _meta =
    <DomainName, (String, String, String)>{
      'complex': ('Complex', 'Probe → Sense → Respond', 'Emergent Practices'),
      'complicated': (
        'Complicated',
        'Sense → Analyse → Respond',
        'Good Practices',
      ),
      'clear': ('Clear', 'Sense → Categorise → Respond', 'Best Practices'),
      'chaotic': ('Chaotic', 'Act → Sense → Respond', 'Novel Practices'),
      'confusion': ('Confusion', '', 'Disorder'),
    };

const int _maxConfusionItems = 3;
const double _itemMaxWidth = 200;
const double _itemPadX = 10;
const double _itemPadY = 4;
const double _itemGap = 6;
const double _headGap = 10;
const double _margin = 20;
const double _clearance = 10;

class _Badge {
  final String text;
  final Label label;
  final double w;
  final double h;
  final bool overflow;

  const _Badge({
    required this.text,
    required this.label,
    required this.w,
    required this.h,
    required this.overflow,
  });
}

class _Block {
  final DomainName name;
  final Label title;
  final List<Label> subtitles;
  final List<_Badge> badges;
  final double w;
  final double h;
  double cx = 0;
  double cy = 0;

  _Block({
    required this.name,
    required this.title,
    required this.subtitles,
    required this.badges,
    required this.w,
    required this.h,
  });
}

double _setting(
  Config config,
  String key,
  double fallback,
  double min,
  double max,
) {
  final section = config['cynefin'];
  final value = section is Map ? section[key] : null;
  if (value is int && value >= min && value <= max) return value.toDouble();
  if (value is double && value >= min && value <= max) return value;
  return fallback;
}

Rendered renderCynefin(
  CynefinModel model,
  Config config,
  RenderOptions options,
) {
  final size = options.fontSize ?? 16;
  final small = roundJs(size * 0.8125);
  final itemSize = roundJs(size * 0.875);
  final measurer =
      options.measurer ??
      defaultMeasurer(options.fontFamily, options.fontFamilyMono);
  final pad = options.padding ?? 8;
  final icons = options.icons;
  final cynefinCfg = config['cynefin'];
  final showDescriptions =
      !(cynefinCfg is Map && cynefinCfg['showDomainDescriptions'] == false);
  final amplitude = _setting(config, 'boundaryAmplitude', 8, 0, 50);
  final seed = resolveSeed(
    _setting(config, 'seed', 0, -1e15, 1e15),
    options.idPrefix ?? 'pele',
  );
  final itemLine = roundJs(itemSize * 1.5).toDouble();

  _Badge badge(String text, bool overflow) {
    final label = layoutLabel(
      text,
      false,
      measurer,
      itemSize.toDouble(),
      _itemMaxWidth,
    );
    return _Badge(
      text: text,
      label: label,
      w: label.width + 2 * _itemPadX,
      h: math.max(label.height, itemLine) + 2 * _itemPadY,
      overflow: overflow,
    );
  }

  _Block block(DomainName name) {
    final meta = _meta[name]!;
    final title = layoutLabel(meta.$1, false, measurer, size, 4000, Style.Bold);
    final subtitles = <Label>[];
    if (showDescriptions) {
      for (final text in <String>[meta.$2, meta.$3]) {
        if (text.isNotEmpty) {
          subtitles.add(
            layoutLabel(
              text,
              false,
              measurer,
              small.toDouble(),
              4000,
              Style.Italic,
            ),
          );
        }
      }
    }
    final items = model.domains[name]?.items ?? const <CynefinItem>[];
    final shown = name == 'confusion' && items.length > _maxConfusionItems
        ? _maxConfusionItems
        : items.length;
    final badges = <_Badge>[];
    for (var i = 0; i < shown; i++) {
      badges.add(badge(items[i].label, false));
    }
    if (shown < items.length) {
      badges.add(badge('+${items.length - shown} more', true));
    }
    var w = title.width;
    var h = title.height;
    for (final s in subtitles) {
      w = math.max(w, s.width);
      h += s.height;
    }
    if (badges.isNotEmpty) h += _headGap - _itemGap;
    for (final b in badges) {
      w = math.max(w, b.w);
      h += _itemGap + b.h;
    }
    return _Block(
      name: name,
      title: title,
      subtitles: subtitles,
      badges: badges,
      w: w,
      h: h,
    );
  }

  final quadrants = _quadrants.map((q) => block(q.$1)).toList();
  final confusion = block('confusion');
  final rx = math.max(88.0, confusion.w * 0.71 + 8);
  final ry = math.max(64.0, confusion.h * 0.71 + 6);

  var quadW = _setting(config, 'width', 640, 100, 10000) / 2;
  var quadH = _setting(config, 'height', 440, 100, 10000) / 2;
  for (final b in quadrants) {
    quadW = math.max(quadW, b.w + 2 * _margin);
    quadH = math.max(quadH, b.h + 2 * _margin);
  }
  // A block sits in the middle of its quadrant, so its inner corner must stay clear of the ellipse.
  for (final b in quadrants) {
    final dx = (quadW - b.w) / 2;
    final dy = (quadH - b.h) / 2;
    final nx = dx / (rx + _clearance);
    final ny = dy / (ry + _clearance);
    if (nx * nx + ny * ny >= 1) continue;
    final wider = b.w + 2 * (rx + _clearance);
    final taller = b.h + 2 * (ry + _clearance);
    if (wider * quadH <= quadW * taller) {
      quadW = math.max(quadW, wider);
    } else {
      quadH = math.max(quadH, taller);
    }
  }

  final title = layoutLabel(
    model.title,
    false,
    measurer,
    size,
    4000,
    Style.Bold,
  );
  final titleHeight = title.height > 0 ? title.height + 12 : 0.0;
  final width = 2 * quadW;
  final height = 2 * quadH;
  final x0 = pad;
  final y0 = pad + titleHeight;
  final cx = x0 + quadW;
  final cy = y0 + quadH;
  final right = x0 + width;
  final bottom = y0 + height;

  final fold = wave(
    y0,
    cy,
    cx,
    seed,
    amplitude,
    FOLD.copyWith(segments: 4, pinEnd: true),
  );
  final west = wave(
    x0,
    cx,
    cy,
    seed + 100,
    amplitude,
    HORIZON.copyWith(segments: 4, pinEnd: true),
  );
  final east = wave(
    cx,
    right,
    cy,
    seed + 200,
    amplitude,
    HORIZON.copyWith(segments: 4, pinStart: true),
  );
  final drop = cliff(cx, cy, bottom, width * 0.03);
  String at(List<double> curve, bool end) => end
      ? '${num(curve[curve.length - 2])},${num(curve[curve.length - 1])}'
      : '${num(curve[0])},${num(curve[1])}';

  final regions = <DomainName, String>{
    'complex':
        'M${num(x0)},${num(y0)}L${at(fold, false)}${forward(fold)}${backward(west)}Z',
    'complicated':
        'M${at(fold, false)}L${num(right)},${num(y0)}L${at(east, true)}${backward(east)}${backward(fold)}Z',
    'chaotic':
        'M${at(west, false)}${forward(west)}${forward(drop)}L${num(x0)},${num(bottom)}Z',
    'clear':
        'M${at(east, false)}${forward(east)}L${num(right)},${num(bottom)}L${at(drop, true)}${backward(drop)}Z',
  };

  final fills = StringBuffer();
  for (final (name, _, _, color) in _quadrants) {
    fills.write(
      '<path class="pele-cynefin-region" data-id="$name" d="${regions[name]!}" fill="${seriesColor(color)}" fill-opacity="0.14"/>',
    );
  }
  final boundaries =
      '<g class="pele-cynefin-boundaries" fill="none" stroke="var(--_b)" stroke-dasharray="6 3">'
      '<path d="${curvePath(fold)}"/><path d="${curvePath(west)}"/><path d="${curvePath(east)}"/>'
      '<path class="pele-cynefin-cliff" d="${curvePath(drop)}" stroke="var(--_l)" stroke-width="2" stroke-dasharray="none" stroke-linecap="round"/></g>';
  final oval = ellipsePath(cx, cy, rx, ry);
  final ellipse =
      '<path d="$oval" fill="var(--_bg)"/>'
      '<path class="pele-cynefin-region" data-id="confusion" d="$oval" fill="${seriesColor(_confusionColor)}" fill-opacity="0.18" stroke="var(--_b)" stroke-dasharray="4 2"/>';

  String drawBlock(_Block b) {
    var y = b.cy - b.h / 2;
    final out = StringBuffer(
      labelSvg(
        b.title,
        b.cx,
        y + b.title.height / 2,
        ' class="pele-label" font-weight="var(--_hw)"',
      ),
    );
    y += b.title.height;
    for (final s in b.subtitles) {
      out.write(
        labelSvg(
          s,
          b.cx,
          y + s.height / 2,
          ' class="pele-cynefin-subtitle" font-size="$small" font-style="italic" fill="var(--_m)"',
        ),
      );
      y += s.height;
    }
    y += _headGap - _itemGap;
    for (final item in b.badges) {
      y += _itemGap;
      out.write(
        '<g class="pele-node${item.overflow ? ' pele-cynefin-overflow' : ''}"${item.overflow ? '' : ' data-id="${escText(item.text)}"'}>'
        '<rect x="${num(b.cx - item.w / 2)}" y="${num(y)}" width="${num(item.w)}" height="${num(item.h)}" fill="var(--_bg)" stroke="var(--_b)"${item.overflow ? ' stroke-dasharray="3 2"' : ''}$roundedAttr/>'
        '${labelSvg(item.label, b.cx, y + item.h / 2, ' class="pele-label" font-size="$itemSize"${item.overflow ? ' fill="var(--_m)"' : ''}', icons)}'
        '</g>',
      );
      y += item.h;
    }
    return '<g class="pele-cynefin-domain" data-id="${b.name}">$out</g>';
  }

  final blocks = <DomainName, _Block>{};
  final domains = StringBuffer();
  for (var index = 0; index < _quadrants.length; index++) {
    final (name, col, row, _) = _quadrants[index];
    final b = quadrants[index];
    b.cx = x0 + quadW * (col + 0.5);
    b.cy = y0 + quadH * (row + 0.5);
    blocks[name] = b;
    domains.write(drawBlock(b));
  }
  confusion.cx = cx;
  confusion.cy = cy;
  blocks['confusion'] = confusion;
  domains.write(drawBlock(confusion));

  bool inside(_Block b, double x, double y) {
    if (identical(b, confusion)) {
      final ex = (x - cx) / (rx + 4);
      final ey = (y - cy) / (ry + 4);
      return ex * ex + ey * ey <= 1;
    }
    return (x - b.cx).abs() <= b.w / 2 + 8 && (y - b.cy).abs() <= b.h / 2 + 8;
  }

  final edges = StringBuffer();
  final seen = <String, int>{};
  for (final transition in model.transitions) {
    final from = blocks[transition.from];
    final to = blocks[transition.to];
    if (from == null || to == null || identical(from, to)) continue;
    final key = transition.from.compareTo(transition.to) < 0
        ? '${transition.from} ${transition.to}'
        : '${transition.to} ${transition.from}';
    final repeat = seen[key] ?? 0;
    seen[key] = repeat + 1;

    final dx = to.cx - from.cx;
    final dy = to.cy - from.cy;
    final rawLen = hypot(dx, dy);
    final len = rawLen == 0 ? 1.0 : rawLen;
    final mx = (from.cx + to.cx) / 2;
    final my = (from.cy + to.cy) / 2;
    // Curves bow away from the middle of the diagram, which keeps them off the ellipse.
    final outward = -dy * (mx - cx) + dx * (my - cy) >= 0 ? 1.0 : -1.0;
    final nx = (-dy / len) * outward;
    final ny = (dx / len) * outward;
    // A diagonal runs through the middle, so it bows far enough to pass the ellipse.
    final diagonal =
        !identical(from, confusion) &&
        !identical(to, confusion) &&
        dx.abs() > 1 &&
        dy.abs() > 1;
    final bow =
        (diagonal ? 2 * (hypot(rx * nx, ry * ny) + 16) : len * 0.15) +
        repeat * 56;
    final px = mx + nx * bow;
    final py = my + ny * bow;
    (double, double) point(double t) {
      final u = 1 - t;
      return (
        u * u * from.cx + 2 * u * t * px + t * t * to.cx,
        u * u * from.cy + 2 * u * t * py + t * t * to.cy,
      );
    }

    double crossing(_Block b, double lo, double hi, bool leaving) {
      for (var i = 0; i < 16; i++) {
        final mid = (lo + hi) / 2;
        final (ptX, ptY) = point(mid);
        if (inside(b, ptX, ptY) == leaving) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      return (lo + hi) / 2;
    }

    const steps = 48;
    var i = 1;
    while (i <= steps) {
      final (ptX, ptY) = point(i / steps);
      if (!inside(from, ptX, ptY)) break;
      i++;
    }
    if (i > steps) continue;
    final t0 = crossing(from, (i - 1) / steps, i / steps, true);
    while (i <= steps) {
      final (ptX, ptY) = point(i / steps);
      if (inside(to, ptX, ptY)) break;
      i++;
    }
    final t1 = i > steps
        ? 1.0
        : crossing(to, (i - 1) / steps, i / steps, false);

    final (sx, sy) = point(t0);
    var (ex, ey) = point(t1);
    double blossom(double a, double b, double c) =>
        (1 - t0) * (1 - t1) * a +
        ((1 - t0) * t1 + t0 * (1 - t1)) * b +
        t0 * t1 * c;
    final qx = blossom(from.cx, px, to.cx);
    final qy = blossom(from.cy, py, to.cy);
    final rawEl = hypot(ex - qx, ey - qy);
    final el = rawEl == 0 ? 1.0 : rawEl;
    final ux = (ex - qx) / el;
    final uy = (ey - qy) / el;
    final head = marker('arrow_point', ex, ey, ux, uy, 'var(--_l)');
    ex -= ux * markerTrim('arrow_point');
    ey -= uy * markerTrim('arrow_point');

    var text = '';
    if (transition.label != null && transition.label!.isNotEmpty) {
      final label = layoutLabel(
        transition.label,
        false,
        measurer,
        small.toDouble(),
        _itemMaxWidth,
      );
      final (lx, ly) = point((t0 + t1) / 2);
      final away =
          (nx.abs() * label.width) / 2 + (ny.abs() * label.height) / 2 + 6;
      final half = label.width / 2 + 4;
      final tx = math.min(
        math.max(lx + nx * away, x0 + half),
        math.max(right - half, x0 + half),
      );
      text = labelSvg(
        label,
        tx,
        ly + ny * away,
        ' class="pele-edge-label" font-size="$small"',
        icons,
      );
    }
    edges.write(
      '<g class="pele-edge" data-id="${transition.from}-${transition.to}">'
      '<path d="M${num(sx)},${num(sy)}Q${num(qx)},${num(qy)} ${num(ex)},${num(ey)}" fill="none" stroke="var(--_l)"/>'
      '$head'
      '$text'
      '</g>',
    );
  }

  final totalWidth = (math.max(width, title.width) + 2 * pad).ceilToDouble();
  final totalHeight = (height + titleHeight + 2 * pad).ceilToDouble();
  final edgesStr = edges.toString();
  final content =
      labelSvg(
        title,
        x0 + width / 2,
        pad + title.height / 2,
        ' class="pele-title" font-weight="var(--_tw)"',
      ) +
      '<g class="pele-cynefin-regions">$fills</g>' +
      boundaries +
      ellipse +
      domains.toString() +
      (edgesStr.isNotEmpty ? '<g class="pele-edges">$edgesStr</g>' : '');

  return Rendered(
    svg: svgDocument(
      'cynefin',
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

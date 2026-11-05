// Upstream: src/diagrams/venn/render.ts

import 'dart:convert';
import 'dart:math' as math;

import '../../preprocess.dart';
import '../../svg/builder.dart';
import '../../svg/ink.dart';
import '../../svg/root.dart';
import '../../svg/theme.dart';
import '../../text/label.dart';
import '../../text/measurer.dart';
import '../../types.dart';
import '../../util/math_js.dart';
import 'db.dart';
import 'layout.dart';
import 'types.dart';

const double _radius = 100;
const double _maxGrowth = 1.6;
final ResolvedStyle _noStyle = resolveStyle(const <String>[]);
final RegExp _reFillOpacity = RegExp(r'[";]fill-opacity:');

class _RegionLine {
  final String? id;
  final String raw;
  final double size;
  final int base;
  Label label;

  _RegionLine({
    this.id,
    required this.raw,
    required this.size,
    required this.base,
    required this.label,
  });
}

class _Region {
  final List<String> sets;
  final List<int> inside;
  final Spot spot;
  // What is written in the region: its label first, then its texts. The id is that of a text.
  final List<_RegionLine> lines;
  final ResolvedStyle style;
  // Whether its text is written across other circles.
  final bool across;

  _Region({
    required this.sets,
    required this.inside,
    required this.spot,
    List<_RegionLine>? lines,
    required this.style,
    required this.across,
  }) : lines = lines ?? <_RegionLine>[];
}

// One key for a list of set ids. Ids may hold any character, so they are not simply joined.
String _keyOf(List<String> ids) {
  return ids.length == 1 ? ids[0] : jsonEncode(ids);
}

Rendered renderVenn(VennModel model, Config config, RenderOptions options) {
  final size = options.fontSize ?? 16;
  final small = roundJs(size * 0.875);
  final tiny = roundJs(size * 0.8125);
  final smallD = small.toDouble();
  final tinyD = tiny.toDouble();
  final measurer =
      options.measurer ??
      defaultMeasurer(options.fontFamily, options.fontFamilyMono);
  final pad = options.padding ?? 8;

  final circles = layoutCircles(model.subsets);
  final index = <String, int>{};
  for (var i = 0; i < circles.length; i++) {
    index[circles[i].id] = i;
  }

  // Styles for the same targets add up, later declarations winning.
  final styles = <String, Map<String, String>>{};
  for (final s in model.styles) {
    final key = _keyOf(s.targets);
    final merged = styles.putIfAbsent(key, () => <String, String>{});
    for (final entry in s.styles.entries) {
      merged[entry.key] = entry.value;
    }
  }
  ResolvedStyle styleOf(String key) {
    final declared = styles[key];
    if (declared == null) return _noStyle;
    final list = <String>[
      for (final entry in declared.entries) '${entry.key}:${entry.value}',
    ];
    return resolveStyle(list);
  }

  // Circles that touch each circle; only those can cut into a region of it.
  final neighbors = List<List<int>>.generate(circles.length, (_) => <int>[]);
  for (var a = 0; a < circles.length; a++) {
    for (var b = a + 1; b < circles.length; b++) {
      if (hypot(circles[a].x - circles[b].x, circles[a].y - circles[b].y) <
          circles[a].r + circles[b].r) {
        neighbors[a].add(b);
        neighbors[b].add(a);
      }
    }
  }

  // One region for each set and each stated overlap; a later statement about the same sets replaces an earlier one.
  final stated = <String, VennSubset>{};
  for (final subset in model.subsets) {
    stated[_keyOf(subset.sets)] = subset;
  }
  final regions = <String, _Region>{};
  for (final entry in stated.entries) {
    final key = entry.key;
    final subset = entry.value;
    final sets = subset.sets.toSet().toList();
    final inside = sets.map((id) => index[id]!).toList();
    final within = inside.toSet();
    var smallest = inside[0];
    for (final i in inside) {
      if (circles[i].r < circles[smallest].r) smallest = i;
    }
    final style = styleOf(key);
    final text =
        subset.label ?? (subset.sets.length == 1 ? subset.sets[0] : null);
    final base =
        (style.bold ? Style.bold : 0) | (style.italic ? Style.italic : 0);
    final others = neighbors[smallest]
        .where((i) => !within.contains(i))
        .toList();
    var spot = findSpot(circles, inside, others);
    // A region that other circles cover, or all but cover, is written across them instead.
    final across = others.isNotEmpty && spot.margin < circles[smallest].r * 0.2;
    if (across) spot = findSpot(circles, inside, const <int>[]);
    final region = _Region(
      sets: sets,
      inside: inside,
      spot: spot,
      style: style,
      across: across,
    );
    if (text != null && text.isNotEmpty) {
      final fontSize = sets.length == 1 ? size : smallD;
      region.lines.add(
        _RegionLine(
          raw: text,
          size: fontSize,
          base: base,
          label: layoutLabel(text, false, measurer, fontSize, 4000, base),
        ),
      );
    }
    regions[key] = region;
  }
  for (final node in model.textNodes) {
    final raw = node.label ?? node.id;
    regions[_keyOf(node.sets)]?.lines.add(
      _RegionLine(
        id: node.id,
        raw: raw,
        size: tinyD,
        base: 0,
        label: layoutLabel(raw, false, measurer, tinyD, 4000),
      ),
    );
  }

  // Lengths so far are in units of the layout. The scale gives the largest circle a set radius,
  // and grows, within limits, until every region holds what is written in it.
  var largest = 0.0;
  for (final c in circles) {
    if (c.r > largest) largest = c.r;
  }
  var scale = largest > 0 ? _radius / largest : 1.0;
  var growth = 1.0;
  for (final region in regions.values) {
    if (region.spot.margin <= 0) continue;
    var width = 0.0;
    var height = 0.0;
    for (final line in region.lines) {
      width = math.max(width, line.label.width);
      height += line.label.height;
    }
    final need = hypot(width, height) / 2 + 4;
    growth = math.max(
      growth,
      math.min(need / (region.spot.margin * scale), _maxGrowth),
    );
  }
  scale *= growth;

  // What is still too wide for its region is wrapped to it.
  for (final region in regions.values) {
    final room = math.max(region.spot.margin * scale * 1.8, 72.0);
    for (final line in region.lines) {
      if (line.label.width > room) {
        line.label = layoutLabel(
          line.raw,
          false,
          measurer,
          line.size,
          room,
          line.base,
        );
      }
    }
  }

  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = double.negativeInfinity;
  var maxY = double.negativeInfinity;
  for (final c in circles) {
    minX = math.min(minX, (c.x - c.r) * scale);
    minY = math.min(minY, (c.y - c.r) * scale);
    maxX = math.max(maxX, (c.x + c.r) * scale);
    maxY = math.max(maxY, (c.y + c.r) * scale);
  }
  for (final region in regions.values) {
    var wide = 0.0;
    var tall = 0.0;
    for (final line in region.lines) {
      wide = math.max(wide, line.label.width);
      tall += line.label.height;
    }
    minX = math.min(minX, region.spot.x * scale - wide / 2);
    maxX = math.max(maxX, region.spot.x * scale + wide / 2);
    minY = math.min(minY, region.spot.y * scale - tall / 2);
    maxY = math.max(maxY, region.spot.y * scale + tall / 2);
  }
  if (circles.isEmpty) {
    minX = minY = maxX = maxY = 0;
  }

  final rawTitle = model.title;
  final title = layoutLabel(
    (rawTitle != null && rawTitle.isNotEmpty) ? normalizeText(rawTitle) : null,
    false,
    measurer,
    size,
    4000,
    Style.bold,
  );
  final titleHeight = title.height > 0 ? title.height + 12 : 0.0;
  final inner = math.max(maxX - minX, title.width);
  final ox = pad + (inner - (maxX - minX)) / 2 - minX;
  final oy = pad + titleHeight - minY;
  final width = (inner + 2 * pad).ceilToDouble();
  final height = (maxY - minY + titleHeight + 2 * pad).ceilToDouble();
  final placed = circles
      .map(
        (c) => Circle(
          id: c.id,
          x: c.x * scale + ox,
          y: c.y * scale + oy,
          r: c.r * scale,
        ),
      )
      .toList();

  final sets = StringBuffer();
  for (var i = 0; i < placed.length; i++) {
    final c = placed[i];
    final color = seriesColor(i);
    final style = regions[c.id]?.style ?? _noStyle;
    sets.write(
      '<circle class="pele-venn-set" data-id="${escText(c.id)}" cx="${num(c.x)}" cy="${num(c.y)}" r="${num(c.r)}" fill="$color" fill-opacity="0.2" stroke="$color"${style.shape}/>',
    );
  }

  final painted = regions.values
      .where((r) => r.sets.length > 1 && r.style.shape.isNotEmpty)
      .toList();
  // The fill under a region's text is the last overlap drawn over all of it, or its own circle when the style sets an opacity.
  String under(_Region region) {
    if (region.across) return '';
    var fill =
        region.sets.length == 1 && _reFillOpacity.hasMatch(region.style.shape)
        ? region.style.shape
        : '';
    for (final other in painted) {
      if (other.sets.every((id) => region.sets.contains(id))) {
        fill = other.style.shape;
      }
    }
    return fill;
  }

  final overlaps = StringBuffer();
  final labels = StringBuffer();
  for (final region in regions.values) {
    final id = escText(region.sets.join('|'));
    // An overlap is only drawn when a style gives it a look of its own; otherwise the circles show it.
    if (region.sets.length > 1 && region.style.shape.isNotEmpty) {
      final d = regionPath(region.inside.map((i) => placed[i]).toList(), num);
      if (d.isNotEmpty) {
        overlaps.write(
          '<path class="pele-venn-overlap" data-id="$id" d="$d" fill="none"${region.style.shape}/>',
        );
      }
    }
    var total = 0.0;
    for (final line in region.lines) {
      total += line.label.height;
    }
    if (total == 0) continue;
    final x = region.spot.x * scale + ox;
    var y = region.spot.y * scale + oy - total / 2;
    final fill = under(region);
    final content = StringBuffer();
    for (final line in region.lines) {
      final own = line.id == null ? region.style.text : styleOf(line.id!).text;
      final color = ink(fill, own);
      final attrs = line.id == null
          ? ' class="pele-label"${line.size == size ? '' : ' font-size="${num(line.size)}"'}${color != null && color.isNotEmpty ? ' fill="$color"' : ''}$own'
          : ' class="pele-venn-text" data-id="${escText(line.id!)}" font-size="$tiny" fill="${color ?? 'var(--_m)'}"$own';
      content.write(labelSvg(line.label, x, y + line.label.height / 2, attrs));
      y += line.label.height;
    }
    labels.write('<g class="pele-venn-region" data-id="$id">$content</g>');
  }

  final overlapsStr = overlaps.toString();
  final labelsStr = labels.toString();

  final svg = svgDocument(
    'venn',
    width,
    height,
    size,
    options,
    const Accessible(),
    labelSvg(
          title,
          width / 2,
          pad + title.height / 2,
          ' class="pele-title" font-weight="var(--_tw)"',
        ) +
        '<g class="pele-venn-sets">$sets</g>' +
        (overlapsStr.isNotEmpty
            ? '<g class="pele-venn-overlaps">$overlapsStr</g>'
            : '') +
        (labelsStr.isNotEmpty
            ? '<g class="pele-venn-labels">$labelsStr</g>'
            : ''),
  );
  return Rendered(svg: svg, width: width, height: height, links: <LinkInfo>[]);
}

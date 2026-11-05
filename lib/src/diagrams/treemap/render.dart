// Upstream: src/diagrams/treemap/render.ts

import 'dart:math' as math;

import '../../preprocess.dart';
import '../../svg/builder.dart';
import '../../svg/ink.dart';
import '../../svg/palette.dart';
import '../../svg/root.dart';
import '../../svg/theme.dart';
import '../../text/entities.dart';
import '../../text/label.dart';
import '../../text/measurer.dart';
import '../../types.dart';
import '../../util/math_js.dart';
import '../common/fit_text.dart';
import '../common/fit_width.dart';
import 'format.dart';
import 'layout.dart';
import 'model.dart';

const double _header = 28;
const double _shortHeader = 18;
const double _side = 6;
const double _line = 1.25;

final RegExp _reShapeFill = RegExp(r'[";]fill:');

String _titlePart(String raw) => esc(decodeEntities(raw).trim()).trim();

int _leafCount(List<TreemapNode> roots) {
  var count = 0;
  final stack = List<TreemapNode>.of(roots);
  while (stack.isNotEmpty) {
    final node = stack.removeLast();
    if (node.children != null) {
      stack.addAll(node.children!);
    } else if (node.value != null && node.value!.isFinite && node.value! > 0) {
      count++;
    }
  }
  return count;
}

// Caps corners at a quarter of a small box's shorter side; 4px is the default radius.
String _corners(String attrs, Box b) {
  final cap = math.min(b.w, b.h) / 4;
  return cap < 4
      ? rounded(attrs)
            .replaceFirst('rx:var(--_r)', 'rx:min(var(--_r),${num(cap)}px)')
      : rounded(attrs);
}

double _option(
  Config config,
  String key,
  double fallback,
  double min,
  double max,
) {
  final treemapConf = config['treemap'];
  final value = treemapConf is Map ? treemapConf[key] : null;
  if (value is int || value is double) {
    final d = value is int ? value.toDouble() : value as double;
    if (d >= min) return math.min(d, max);
  }
  return fallback;
}

Rendered renderTreemap(
  TreemapModel model,
  Config config,
  RenderOptions options,
) {
  final size = options.fontSize ?? 16;
  final small = roundJs(size * 0.875);
  final tiny = roundJs(size * 0.75);
  final least = roundJs(size * 0.5625);
  final smallD = small.toDouble();
  final tinyD = tiny.toDouble();
  final leastD = least.toDouble();
  final measurer =
      options.measurer ??
      defaultMeasurer(options.fontFamily, options.fontFamilyMono);
  final treemap = asConfig(config['treemap']);
  final pad = options.padding ?? _option(config, 'diagramPadding', 8, 0, 2000);

  // Mermaid sizes the diagram as ten times `nodeWidth` by ten times `nodeHeight`.
  final width = roundJs(
    capWidth(
      options,
      _option(config, 'nodeWidth', 64, 1, 400) * 10,
      200,
      2 * pad,
    ),
  ).toDouble();
  final height = roundJs(_option(config, 'nodeHeight', 40, 1, 400) * 10)
      .toDouble();
  final showValues = treemap['showValues'] != false;
  final valueFormat = treemap['valueFormat'];
  final format = formatter(valueFormat is String ? valueFormat : ',');
  // Reduce gaps and insets as average leaf area shrinks.
  final areaRatio =
      (width * height) / math.max(1, _leafCount(model.roots)) / 800;
  final logVal = areaRatio > 0
      ? math.log(areaRatio) / math.ln10
      : double.negativeInfinity;
  final crowd = math.min(1.0, math.max(0.0, logVal.isNaN ? 0.0 : logVal));
  final boxes = layoutTreemap(
    model.roots,
    width,
    height,
    Insets(
      gap: _option(
        config,
        'padding',
        roundJs(2 + 2 * crowd).toDouble(),
        0,
        200,
      ),
      header: _header,
      short: _shortHeader,
      side: roundJs(3 + 3 * crowd).toDouble(),
    ),
  );

  final title = layoutLabel(
    model.title,
    false,
    measurer,
    size,
    titleRoom(options),
    Style.bold,
  );
  final titleHeight = title.height > 0 ? title.height + 8 : 0.0;
  final left = pad + math.max(0.0, (title.width - width) / 2);
  final top = pad + titleHeight;

  final sections = StringBuffer();
  final leaves = StringBuffer();
  for (final b in boxes) {
    final node = b.node;
    final style = resolveStyle(node.cssCompiledStyles ?? const <String>[]);
    final color = seriesColor(b.series);
    final x = left + b.x;
    final y = top + b.y;
    final name = decodeEntities(node.name).trim();
    final value = showValues ? format(b.value) : '';
    final group = 'data-id="${escText(node.name)}">';
    // Include headerless ancestors in tooltips because their children cover them.
    final own = _titlePart(node.name);
    final path = own.isEmpty ? <String>[] : <String>[own];
    for (var p = b.parent; p != null && !p.headed; p = p.parent) {
      final section = _titlePart(p.node.name);
      if (section.isNotEmpty) path.insert(0, section);
    }
    final full = path.join(' › ');
    String tooltip(String? drawn) =>
        (full.isEmpty || (drawn == name && full == own))
        ? ''
        : '<title>$full</title>';
    final rect =
        '<rect x="${num(x)}" y="${num(y)}" width="${num(b.w)}" height="${num(b.h)}" fill="$color"';
    // Inline font sizes override SVG attributes, so truncate instead of shrinking.
    final fixed = style.fontSize;
    final textStyle =
        (style.bold ? Style.bold : 0) | (style.italic ? Style.italic : 0);
    final ink = setsFill(style.shape)
        ? inkFill((shape: style.shape, text: style.text))
        : seriesInkFill(b.series);

    if (node.children != null) {
      final text = StringBuffer();
      String? drawn;
      if (b.headed) {
        final short = b.header < _header;
        final labelSize = fixed ?? (short ? tinyD : smallD);
        final valueSize = fixed ?? tinyD;
        final room = b.w - 2 * _side - 4;
        final valueWidth = value.isNotEmpty
            ? measurer.width(value, valueSize, textStyle)
            : 0.0;
        final withValue =
            !short && valueWidth > 0 && room - valueWidth - 12 >= 3 * labelSize;
        final label = labelSize * _line < b.header
            ? fitText(
                name,
                withValue ? room - valueWidth - 12 : room,
                labelSize,
                labelSize,
                measurer,
                textStyle | Style.bold,
              )
            : null;
        final baseline = y + b.header / 2 + 1;
        drawn = label?.text;
        if (label != null) {
          text.write(
            '<text x="${num(x + _side + 2)}" y="${num(baseline + labelSize * 0.35)}" font-weight="var(--_hw)"${short ? ' font-size="${num(labelSize)}"' : ''}$ink${style.text}>${esc(label.text)}</text>',
          );
        }
        if (withValue && valueSize * _line <= _header) {
          text.write(
            '<text class="pele-value" x="${num(x + b.w - _side - 2)}" y="${num(baseline + valueSize * 0.35)}" font-size="$tiny" text-anchor="end"${ink.isNotEmpty ? ink : ' fill="var(--_m)"'}${style.text}>${esc(value)}</text>',
          );
        }
      }
      // A section is a tint of its color, unless a class gives it a fill of its own. Headerless
      // sections draw no box, so their children blend into the grid.
      final tint = _reShapeFill.hasMatch(style.shape)
          ? ''
          : ' fill-opacity="0.12"';
      final shape = b.headed
          ? '$rect${_corners('$tint stroke="$color"${style.shape}', b)}/>'
          : '<rect x="${num(x)}" y="${num(y)}" width="${num(b.w)}" height="${num(b.h)}" fill="none"/>';
      sections.write(
        '<g class="pele-node pele-section${classNames(node.classSelector ?? '')}" $group${tooltip(drawn)}$shape$text</g>',
      );
      continue;
    }

    var text = '';
    final room = b.w - 8;
    final smallest = fixed ?? leastD;
    final tallest = fixed == null
        ? math.min(size, ((b.h - 4) / _line).floorToDouble())
        : (fixed * _line <= b.h - 4 ? fixed : 0.0);
    final label = tallest >= smallest
        ? fitText(name, room, tallest, smallest, measurer, textStyle)
        : null;
    if (label != null) {
      final cx = num(x + b.w / 2);
      final cy = y + b.h / 2;
      final valueSize =
          fixed ?? math.max(leastD, roundJs(label.size * 0.8).toDouble());
      final lines = (label.size + valueSize) * _line;
      if (value.isNotEmpty &&
          lines <= b.h - 4 &&
          measurer.width(value, valueSize, textStyle) <= room) {
        final first = cy - lines / 2 + (label.size * _line) / 2;
        final second = cy + lines / 2 - (valueSize * _line) / 2;
        text =
            '<text x="$cx" y="${num(first + label.size * 0.35)}" font-size="${num(label.size)}"$ink${style.text}>${esc(label.text)}</text>'
            '<text class="pele-value" x="$cx" y="${num(second + valueSize * 0.35)}" font-size="${num(valueSize)}"$ink${style.text}>${esc(value)}</text>';
      } else {
        text =
            '<text x="$cx" y="${num(cy + label.size * 0.35)}" font-size="${num(label.size)}"$ink${style.text}>${esc(label.text)}</text>';
      }
    }
    leaves.write(
      '<g class="pele-node pele-leaf${classNames(node.classSelector ?? '')}" $group${tooltip(label?.text)}$rect${_corners(style.shape, b)}/>$text</g>',
    );
  }

  final totalWidth = (math.max(width, title.width) + 2 * pad).ceilToDouble();
  final totalHeight = (height + titleHeight + 2 * pad).ceilToDouble();
  final sectionsStr = sections.toString();
  final leavesStr = leaves.toString();
  final content =
      labelSvg(
        title,
        totalWidth / 2,
        pad + title.height / 2,
        ' class="pele-title" font-weight="var(--_tw)"',
      ) +
      (sectionsStr.isNotEmpty
          ? '<g class="pele-sections" font-size="$small">$sectionsStr</g>'
          : '') +
      (leavesStr.isNotEmpty
          ? '<g class="pele-leaves" text-anchor="middle" fill="var(--_bg)">$leavesStr</g>'
          : '');

  return Rendered(
    svg: svgDocument(
      'treemap',
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

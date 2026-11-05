// Upstream: src/diagrams/sankey/render.ts

import 'dart:math' as math;

import '../../preprocess.dart';
import '../../svg/builder.dart';
import '../../svg/root.dart';
import '../../svg/theme.dart';
import '../../text/entities.dart';
import '../../text/label.dart';
import '../../text/measurer.dart';
import '../../types.dart';
import '../../util/math_js.dart';
import '../common/fit_width.dart';
import 'db.dart';
import 'layout.dart';

const double _labelGap = 6;
const double _valueGap = 15;
const double _labelRoom = 1.8;
const int _careful = 300;

final RegExp _reFillStyle = RegExp(r'^ style="fill:(.*);"$');
final RegExp _reSafeIdPrefix = RegExp(r'^[\w-]+$');

// Two 32-bit hashes, so different gradients practically never share an id.
String _contentId(String text) {
  var a = 0x811c9dc5;
  var b = 5381;
  for (var i = 0; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    a = ((a ^ c) * 0x01000193) & 0xffffffff;
    b = ((b * 33) + c) & 0xffffffff;
  }
  return '${a.toRadixString(36)}${b.toRadixString(36)}';
}

double? _asNumber(Object? value) {
  if (value is int) return value.toDouble();
  if (value is double) return value;
  return null;
}

double _numberOption(
  Config conf,
  String key,
  double fallback,
  double min,
  double max,
) {
  final value = _asNumber(conf[key]);
  return value != null && value >= min ? math.min(value, max) : fallback;
}

String _textOption(Config conf, String key) {
  final value = conf[key];
  if (value is String) return value;
  final n = _asNumber(value);
  if (n != null && n.isFinite) {
    return n == n.truncateToDouble() ? '${n.toInt()}' : '$n';
  }
  return '';
}

// Two decimals, as Mermaid shows values; numbers too large for that are left as they are.
String _rounded(double value) {
  final r = value.abs() < 1e15 ? roundJs(value * 100) / 100.0 : value;
  if (r.abs() < 1e15 && r == r.truncateToDouble()) {
    return '${r.toInt()}';
  }
  return '$r';
}

// A colour from the configuration, as an inline style that overrides the series colour.
String _fillStyle(Object? color) {
  return color is String ? resolveStyle(<String>['fill:$color']).shape : '';
}

class _NodeLabel {
  _NodeLabel({
    required this.value,
    required this.width,
    required this.after,
    required this.left,
    required this.y,
  });

  final String value;
  final double width;
  bool after;
  double left;
  double y;
}

Rendered renderSankey(SankeyModel model, Config config, RenderOptions options) {
  final conf = isRecord(config['sankey'])
      ? asConfig(config['sankey'])
      : <String, Object?>{};
  final natural = _numberOption(conf, 'width', 600, 1, 10000);
  return fitWidth(
    options,
    natural,
    160,
    (chartWidth, _) => _draw(model, conf, options, chartWidth, natural),
  );
}

Rendered _draw(
  SankeyModel model,
  Config conf,
  RenderOptions options,
  double chartWidth,
  double natural,
) {
  final size = options.fontSize ?? 16;
  final least = roundJs(size * 0.625);
  // Labels shrink with a chart narrowed to fit, as they would if the whole picture were scaled down.
  var small = math.max<int>(
    least,
    roundJs(size * 0.875 * math.min(1.0, chartWidth / natural)),
  );
  final measurer =
      options.measurer ??
      defaultMeasurer(options.fontFamily, options.fontFamilyMono);
  final pad = options.padding ?? 8;

  final chartHeight = _numberOption(conf, 'height', 400, 1, 10000);
  final nodeWidth = math.min(
    _numberOption(conf, 'nodeWidth', 10, 1, 200),
    chartWidth,
  );
  final showValues = conf['showValues'] != false;
  final prefix = decodeEntities(_textOption(conf, 'prefix'));
  final suffix = decodeEntities(_textOption(conf, 'suffix'));
  final outlined = conf['labelStyle'] == 'outlined';
  final rawAlign = conf['nodeAlignment'];
  final Alignment alignment =
      rawAlign == 'left' || rawAlign == 'right' || rawAlign == 'center'
      ? rawAlign as String
      : 'justify';
  final rawLinkColor = conf['linkColor'];
  final linkColor = rawLinkColor is String ? rawLinkColor : 'gradient';

  SankeyLayout lay(int labelSize) => layoutSankey(
    model,
    LayoutOptions(
      width: chartWidth,
      height: chartHeight,
      nodeWidth: nodeWidth,
      nodePadding:
          _numberOption(conf, 'nodePadding', 12, 0, 200) +
          (showValues ? _valueGap : 0),
      labelHeight: labelSize * 1.15,
      alignment: alignment,
    ),
  );

  var layout = lay(small);
  // Labels also shrink with the most crowded column, so each keeps about LABEL_ROOM lines.
  final rows = <int, int>{};
  var fullest = 1;
  for (final node in layout.nodes) {
    final count = (rows[node.layer] ?? 0) + 1;
    rows[node.layer] = count;
    if (count > fullest) fullest = count;
  }
  final crowded = math.max<int>(
    least,
    roundJs(chartHeight / fullest / _labelRoom),
  );
  if (crowded < small) {
    small = crowded;
    layout = lay(small);
  }
  final nodes = layout.nodes;
  final links = layout.links;
  final smallDouble = small.toDouble();
  final lineHeight = smallDouble * 1.5;

  final custom = <String, String>{};
  if (isRecord(conf['nodeColors'])) {
    final nc = asConfig(conf['nodeColors']);
    for (final entry in nc.entries) {
      final style = _fillStyle(entry.value);
      if (style.isNotEmpty) custom[entry.key] = style;
    }
  }
  String nodeStyle(int i) => custom[model.nodes[i].id] ?? '';
  // Match the whole fill to preserve semicolons in escaped entities.
  String nodeColor(int i) =>
      _reFillStyle.firstMatch(nodeStyle(i))?.group(1) ?? seriesColor(i);

  // Labels sit beside the bars, on the side that faces the middle of the chart unless that
  // side is crowded.
  var central = 0;
  var most = 0.0;
  for (final node in nodes) {
    if (node.value > most) {
      most = node.value;
      central = node.layer;
    }
  }
  var minX = 0.0;
  var maxX = chartWidth;
  var minY = 0.0;
  var maxY = chartHeight;
  final labels = <_NodeLabel>[];
  for (var i = 0; i < nodes.length; i++) {
    final node = nodes[i];
    final name = decodeEntities(model.nodes[i].id);
    final value = showValues ? '$prefix${_rounded(node.value)}$suffix' : '';
    final width = measurer.width(
      value.isNotEmpty ? '$name $value' : name,
      smallDouble,
      0,
    );
    final after = outlined ? node.layer >= central : node.x < chartWidth / 2;
    final x = after ? node.x + nodeWidth + _labelGap : node.x - _labelGap;
    final y = node.y + node.height / 2;
    minX = math.min(minX, after ? x : x - width);
    maxX = math.max(maxX, after ? x + width : x);
    minY = math.min(minY, y - smallDouble * 0.75);
    maxY = math.max(maxY, y + smallDouble * 0.75);
    labels.add(
      _NodeLabel(
        value: value,
        width: width,
        after: after,
        left: after ? x : x - width,
        y: y,
      ),
    );
  }
  // A label moves at most one line; retain two bands on each side.
  final bands = <int, List<_NodeLabel>>{};
  if (nodes.length <= _careful) {
    for (final label in labels) {
      final band = (label.y / lineHeight).floor();
      for (final key in <int>[band - 2, band - 1, band, band + 1, band + 2]) {
        (bands[key] ??= <_NodeLabel>[]).add(label);
      }
    }
  }
  final labelsOut = StringBuffer();
  final nodesOut = StringBuffer();
  for (var i = 0; i < nodes.length; i++) {
    final node = nodes[i];
    final id = model.nodes[i].id;
    final name = decodeEntities(id);
    final height = math.max(node.height, 1.0);
    nodesOut.write(
      '<rect class="pele-sankey-node" data-id="${escText(id)}" x="${num(node.x)}" y="${num(node.y)}" width="${num(nodeWidth)}" height="${num(height)}" rx="${num(math.min(2.0, height / 2))}" fill="${seriesColor(i)}"${nodeStyle(i)}/>',
    );

    final label = labels[i];
    bool overlapsLabel(double left, double y) {
      final nearby = bands[(y / lineHeight).floor()];
      if (nearby == null) return false;
      for (final other in nearby) {
        if (!identical(other, label) &&
            (other.y - y).abs() < lineHeight &&
            left < other.left + other.width + _labelGap &&
            left + label.width > other.left - _labelGap) {
          return true;
        }
      }
      return false;
    }

    // Try the other side, then an adjacent line when both sides are crowded.
    if (nodes.length <= _careful && overlapsLabel(label.left, label.y)) {
      place:
      for (final dy in <double>[0.0, -lineHeight, lineHeight]) {
        for (final after in <bool>[label.after, !label.after]) {
          final left = after
              ? node.x + nodeWidth + _labelGap
              : node.x - _labelGap - label.width;
          final y = label.y + dy;
          if (overlapsLabel(left, y) ||
              left < minX ||
              left + label.width > maxX ||
              y - smallDouble * 0.75 < minY ||
              y + smallDouble * 0.75 > maxY) {
            continue;
          }
          var hitsBar = false;
          for (var j = 0; j < nodes.length; j++) {
            if (j == i) continue;
            final bar = nodes[j];
            if (left < bar.x + nodeWidth + _labelGap &&
                left + label.width > bar.x - _labelGap &&
                y - smallDouble * 0.75 < bar.y + bar.height &&
                y + smallDouble * 0.75 > bar.y) {
              hitsBar = true;
              break;
            }
          }
          if (hitsBar) continue;
          // A label stays nearer its own bar than any other in the column, so it can't name that one.
          final own = math.max(
            0.0,
            math.max(node.y - y, y - node.y - node.height),
          );
          var nearerOther = false;
          for (var j = 0; j < nodes.length; j++) {
            if (j == i) continue;
            final bar = nodes[j];
            if (bar.x == node.x &&
                math.max(0.0, math.max(bar.y - y, y - bar.y - bar.height)) <=
                    own) {
              nearerOther = true;
              break;
            }
          }
          if (nearerOther) continue;
          label.left = left;
          label.y = y;
          label.after = after;
          break place;
        }
      }
    }
    final value = label.value;
    final after = label.after;
    final y = label.y;
    final x = after ? node.x + nodeWidth + _labelGap : node.x - _labelGap;
    final position =
        ' x="${num(x)}" y="${num(y + smallDouble * 0.35)}" text-anchor="${after ? 'start' : 'end'}"';
    final text =
        esc(name) +
        (value.isNotEmpty
            ? ' <tspan class="pele-sankey-value" fill="var(--_m)">${esc(value)}</tspan>'
            : '');
    labelsOut.write(
      '<g class="pele-label" data-id="${escText(id)}">' +
          (outlined
              ? '<text$position fill="none" stroke="var(--_bg)" stroke-width="3" stroke-linejoin="round">${esc(name)}${value.isNotEmpty ? ' ${esc(value)}' : ''}</text>'
              : '') +
          '<text$position>$text</text></g>',
    );
  }

  final fixed =
      linkColor == 'gradient' || linkColor == 'source' || linkColor == 'target'
      ? ''
      : _fillStyle(linkColor);
  // Without an idPrefix diagrams share gradient ids, and Chrome then uses a hidden or differently
  // themed copy's gradient. Other characters would end the url() and void the whole fill.
  final idPrefix = options.idPrefix ?? '';
  final gradient =
      linkColor == 'gradient' && _reSafeIdPrefix.hasMatch(idPrefix);
  final gradients = <String, String>{};
  final linksOut = StringBuffer();
  for (final link in links) {
    final end = linkColor == 'target' ? link.target : link.source;
    final half = math.max(link.thickness, 1.0) / 2;
    final x0 = nodes[link.source].x + nodeWidth;
    final x1 = nodes[link.target].x;
    final styleOverride = fixed.isNotEmpty ? fixed : nodeStyle(end);
    var paint = 'fill="${seriesColor(end)}"$styleOverride';
    if (gradient) {
      // Ids come from the gradient itself, so diagrams sharing a prefix agree on them. The colour
      // after the url() is the fallback.
      final stops =
          'x1="${num(x0)}" x2="${num(x1)}"><stop offset="0" stop-color="${nodeColor(link.source)}"/>'
          '<stop offset="1" stop-color="${nodeColor(link.target)}"/>';
      final id = '$idPrefix-sankey-${_contentId(stops)}';
      gradients[id] =
          '<linearGradient id="$id" gradientUnits="userSpaceOnUse" $stops</linearGradient>';
      paint = 'fill="url(#$id) ${nodeColor(link.source)}"';
    }
    final mid = num((x0 + x1) / 2);
    final from = escText(model.nodes[link.source].id);
    final to = escText(model.nodes[link.target].id);
    linksOut.write(
      '<path class="pele-sankey-link" data-id="$from-&gt;$to" d="M${num(x0)},${num(link.sourceY - half)}C$mid,${num(link.sourceY - half)} $mid,${num(link.targetY - half)} ${num(x1)},${num(link.targetY - half)}L${num(x1)},${num(link.targetY + half)}C$mid,${num(link.targetY + half)} $mid,${num(link.sourceY + half)} ${num(x0)},${num(link.sourceY + half)}Z" $paint>'
      '<title>$from → $to: ${esc(prefix)}${_rounded(link.value)}${esc(suffix)}</title></path>',
    );
  }

  final title = layoutLabel(
    model.title,
    false,
    measurer,
    size,
    titleRoom(options),
    Style.Bold,
  );
  final titleHeight = title.height > 0 ? title.height + 12 : 0.0;
  final inner = math.max(maxX - minX, title.width);
  final ox = pad - minX + (inner - (maxX - minX)) / 2;
  final oy = pad + titleHeight - minY;
  final width = (inner + 2 * pad).ceilToDouble();
  final height = (maxY - minY + titleHeight + 2 * pad).ceilToDouble();

  final svg = svgDocument(
    'sankey',
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
        '<g transform="translate(${num(ox)},${num(oy)})">' +
        (gradients.isNotEmpty
            ? '<defs>${gradients.values.join()}</defs>'
            : '') +
        '<g class="pele-sankey-links" fill-opacity="0.4">$linksOut</g>' +
        '<g class="pele-sankey-nodes">$nodesOut</g>' +
        '<g class="pele-labels" font-size="$small">$labelsOut</g>' +
        '</g>',
  );

  return Rendered(svg: svg, width: width, height: height, links: <LinkInfo>[]);
}

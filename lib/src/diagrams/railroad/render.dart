// Upstream: src/diagrams/railroad/render.ts

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
import 'common.dart';
import 'types.dart';

abstract final class _Kind {
  static const int Terminal = 0;
  static const int NonTerminal = 1;
  static const int Special = 2;
  static const int Sequence = 3;
  static const int Choice = 4;
  static const int Bypass = 5;
  static const int Loop = 6;
  static const int Folded = 7;
}

// A laid-out element. The track enters at the left edge and leaves at the right edge on one
// baseline, with `up` above it and `down` below it.
class _Box {
  const _Box({
    required this.kind,
    required this.width,
    required this.up,
    required this.down,
    required this.kids,
    required this.text,
    required this.id,
    required this.reach,
  });

  final int kind;
  final double width;
  final double up;
  final double down;
  final List<_Box> kids;
  // A leaf's text, or a loop's count.
  final String text;
  // The name a non-terminal refers to.
  final String id;
  // How far a bypass rises above the baseline, or a loop drops below it.
  final double reach;
}

class _Metrics {
  const _Metrics({
    required this.measurer,
    required this.size,
    required this.padding,
    required this.height,
    required this.gap,
    required this.sep,
    required this.arc,
  });

  final TextMeasurer measurer;
  final double size;
  final double padding;
  final double height;
  // Space between elements in a sequence, and between stacked branches.
  final double gap;
  final double sep;
  final double arc;
}

const double _lead = 12;
const double _headGap = 6;
const double _ruleGap = 18;
const int _countSize = 12;
const int _arrow = 7;

double? _asNumber(Object? value) {
  if (value is int) return value.toDouble();
  if (value is double) return value;
  return null;
}

double _option(Config config, String key, double fallback, double max) {
  final rr = config['railroad'];
  final value = rr is Map ? _asNumber(rr[key]) : null;
  return value != null && value >= 0 ? math.min(value, max) : fallback;
}

final RegExp _reControl = RegExp(r'[\n\r\t]');
final RegExp _reSpacesOnly = RegExp(r'^ +$');

// Text is literal here: a terminal such as "<br>" or "*" is itself, not markup. Mermaid's `#35;`
// codes still stand for characters, and escapes that would be invisible are written out.
String _shown(String text) {
  final s = text.contains('¶ß')
      ? decodeEntities(text.replaceAll('&', '&amp;'))
      : text;
  return s.replaceAllMapped(_reControl, (m) {
    final c = m.group(0)!;
    return c == '\n' ? r'\n' : (c == '\r' ? r'\r' : r'\t');
  });
}

void _reverse<T>(List<T> list, int from) {
  for (var i = from, j = list.length - 1; i < j; i++, j--) {
    final held = list[i];
    list[i] = list[j];
    list[j] = held;
  }
}

double _even(double value) {
  return (value / 2).ceilToDouble() * 2;
}

_Box _leaf(int kind, String text, String id, int style, _Metrics m) {
  final half = m.height / 2;
  final width = math.max(
    _even(m.measurer.width(text, m.size, style) + 2 * m.padding),
    m.height,
  );
  return _Box(
    kind: kind,
    width: width,
    up: half,
    down: half,
    kids: const <_Box>[],
    text: text,
    id: id,
    reach: 0,
  );
}

String _count(double min, double max) {
  if (max == double.infinity && min <= 1) return '';
  String text(double value) => value.isFinite
      ? (value == value.truncateToDouble() ? '${value.toInt()}' : '$value')
      : '∞';
  if (min == max) return '${text(min)}×';
  if (max == double.infinity) return '≥${text(min)}×';
  return min == 0 ? '≤${text(max)}×' : '${text(min)}–${text(max)}×';
}

// Where the next branch of a choice sits below the baseline, given the one above it.
double _below(double offset, _Box above, _Box branch, _Metrics m) {
  return math.max(offset + above.down + m.sep + branch.up, 2 * m.arc);
}

_Box _bypass(_Box kid, _Metrics m) {
  final reach = math.max(kid.up + m.sep, 2 * m.arc);
  return _Box(
    kind: _Kind.Bypass,
    width: kid.width + 4 * m.arc,
    up: reach,
    down: kid.down,
    kids: <_Box>[kid],
    text: '',
    id: '',
    reach: reach,
  );
}

_Box _measure(RailroadNode root, _Metrics m, [double room = double.infinity]) {
  final budgets = Map<RailroadNode, double>.identity();
  final pending = <(RailroadNode, double)>[(root, room)];
  for (var i = 0; room != double.infinity && i < pending.length; i++) {
    final (node, width) = pending[i];
    budgets[node] = width;
    // A sequence that folds puts its rows inside rails, so its parts are sized for those rows.
    final around = node.type == 'choice' || node.type == 'optional'
        ? 4 * m.arc
        : (node.type == 'repetition'
              ? (node.min == 0 ? 6 : 2) * m.arc
              : (node.type == 'sequence' ? 6 * m.arc : 0.0));
    for (final child in parts(node)) {
      pending.add((child, math.max(40.0, width - around)));
    }
  }
  return fold<RailroadNode, _Box>(root, parts, (node, kids) {
    final nodeRoom = budgets[node] ?? double.infinity;
    switch (node.type) {
      case 'terminal':
        {
          final text = _shown(node.value!);
          return _leaf(
            _Kind.Terminal,
            _reSpacesOnly.hasMatch(text) ? '␣' * text.length : text,
            '',
            Style.Mono,
            m,
          );
        }
      case 'nonterminal':
        return _leaf(_Kind.NonTerminal, _shown(node.name!), node.name!, 0, m);
      case 'special':
        return _leaf(
          _Kind.Special,
          '? ${_shown(node.text!)} ?',
          '',
          Style.Italic,
          m,
        );
      case 'sequence':
        {
          var width = math.max(0, kids.length - 1) * m.gap;
          var up = 0.0;
          var down = 0.0;
          for (final kid in kids) {
            width += kid.width;
            up = math.max(up, kid.up);
            down = math.max(down, kid.down);
          }
          final seqBox = _Box(
            kind: _Kind.Sequence,
            width: width,
            up: up,
            down: down,
            kids: kids,
            text: '',
            id: '',
            reach: 0,
          );
          if (width <= nodeRoom || kids.length < 2) return seqBox;
          final rows = <_Box>[];
          var row = <_Box>[];
          var rowW = 0.0;
          void flush() {
            var rUp = 0.0;
            var rDown = 0.0;
            for (final kid in row) {
              rUp = math.max(rUp, kid.up);
              rDown = math.max(rDown, kid.down);
            }
            rows.add(
              _Box(
                kind: _Kind.Sequence,
                width: rowW,
                up: rUp,
                down: rDown,
                kids: row,
                text: '',
                id: '',
                reach: 0,
              ),
            );
            row = <_Box>[];
            rowW = 0;
          }

          for (final kid in kids) {
            if (row.isNotEmpty &&
                rowW + m.gap + kid.width >
                    math.max(40.0, nodeRoom - 6 * m.arc)) {
              flush();
            }
            rowW += (row.isNotEmpty ? m.gap : 0.0) + kid.width;
            row.add(kid);
          }
          flush();
          if (rows.length < 2) return seqBox;
          var foldedWidth = 0.0;
          var offset = 0.0;
          for (var i = 0; i < rows.length; i++) {
            foldedWidth = math.max(foldedWidth, rows[i].width);
            if (i > 0) {
              offset +=
                  rows[i - 1].down + math.max(m.sep, 2 * m.arc) + rows[i].up;
            }
          }
          return _Box(
            kind: _Kind.Folded,
            width: foldedWidth + 6 * m.arc,
            up: rows[0].up,
            down: offset + rows.last.down,
            kids: rows,
            text: '',
            id: '',
            reach: 0,
          );
        }
      case 'choice':
        {
          var inner = 0.0;
          var offset = 0.0;
          for (var i = 0; i < kids.length; i++) {
            inner = math.max(inner, kids[i].width);
            if (i > 0) offset = _below(offset, kids[i - 1], kids[i], m);
          }
          final last = kids.isNotEmpty ? kids.last : null;
          return _Box(
            kind: _Kind.Choice,
            width: inner + 4 * m.arc,
            up: kids.isNotEmpty ? kids[0].up : 0,
            down: last != null ? offset + last.down : 0,
            kids: kids,
            text: '',
            id: '',
            reach: 0,
          );
        }
      case 'optional':
        return _bypass(kids[0], m);
      default:
        {
          final min = node.min!;
          final max = node.max!;
          final kid = kids[0];
          if (min == 1 && max == 1) return kid;
          final text = _count(min, max);
          final reach = math.max(kid.down + m.sep, 2 * m.arc);
          final label = text.isEmpty
              ? 0.0
              : _even(m.measurer.width(text, _countSize.toDouble(), 0));
          final loop = _Box(
            kind: _Kind.Loop,
            width: math.max(kid.width, label) + 2 * m.arc,
            up: kid.up,
            down: reach + (text.isEmpty ? _arrow / 2 + 1 : _countSize + 6),
            kids: <_Box>[kid],
            text: text,
            id: '',
            reach: reach,
          );
          return min == 0 ? _bypass(loop, m) : loop;
        }
    }
  });
}

Rendered renderRailroad(
  RailroadModel model,
  Config config,
  RenderOptions options,
) {
  return tighten(options, (tight) => _draw(model, config, options, tight));
}

Rendered _draw(
  RailroadModel model,
  Config config,
  RenderOptions options,
  bool tight,
) {
  final base = options.fontSize ?? 16;
  final fontSize = _option(config, 'fontSize', 0, 200);
  final size = fontSize > 0 ? fontSize : roundJs(base * 0.875).toDouble();
  final headSize = fontSize > 0 ? fontSize : base;
  final padding = _option(config, 'padding', -1, 200);
  final lineHeight = roundJs(size * 1.5).toDouble();
  final m = _Metrics(
    measurer:
        options.measurer ??
        defaultMeasurer(options.fontFamily, options.fontFamilyMono),
    size: size,
    padding: padding < 0 ? 12 : padding,
    height: _even(lineHeight + (padding < 0 ? 9 : 2 * padding)),
    gap: math.min(
      _option(config, 'horizontalSeparation', 16, 500),
      tight ? 12.0 : double.infinity,
    ),
    sep: _option(config, 'verticalSeparation', 10, 500),
    arc: math.min(
      _option(config, 'arcRadius', 10, 200),
      tight ? 6.0 : double.infinity,
    ),
  );
  final rrConfig = config['railroad'];
  final radius = rrConfig is Map && rrConfig['showMarkers'] == false
      ? 0.0
      : _option(config, 'markerRadius', 4, 50);
  final strokeWidth = _option(config, 'strokeWidth', 0, 20);
  final stroke = strokeWidth > 0 ? ' stroke-width="${num(strokeWidth)}"' : '';
  final pad = options.padding ?? 8;
  final arc = m.arc;

  final A = num(arc);
  String turn(int sweep, String dx, String dy) =>
      'a$A,$A 0 0 $sweep $dx$A,$dy$A';
  final eastToSouth = turn(1, '', '');
  final southToEast = turn(0, '', '');
  final eastToNorth = turn(0, '', '-');
  final northToEast = turn(1, '', '-');
  final loopDown = turn(0, '-', '');
  final loopUp = turn(0, '-', '-');

  final title = layoutLabel(
    model.title,
    false,
    m.measurer,
    base,
    tight ? titleRoom(options) : 4000,
    Style.Bold,
  );
  final titleHeight = title.height > 0 ? title.height + 16 : 0.0;
  final headHeight = roundJs(headSize * 1.5).toDouble();
  final textShift = size * 0.35;
  final boxTop = m.height / 2;

  final track = StringBuffer();
  final arrows = StringBuffer();
  final nodes = StringBuffer();

  void line(double x1, double y, double x2) {
    if (x2 > x1) track.write('M${num(x1)},${num(y)}H${num(x2)}');
  }

  void place(_Box root, double left, double baseline) {
    final boxes = <_Box>[root];
    final at = <double>[left, baseline];
    while (boxes.isNotEmpty) {
      final box = boxes.removeLast();
      final y = at.removeLast();
      final x = at.removeLast();
      final kids = box.kids;
      final right = x + box.width;
      switch (box.kind) {
        case _Kind.Sequence:
          {
            var kx = right;
            for (var i = kids.length - 1; i >= 0; i--) {
              kx -= kids[i].width;
              boxes.add(kids[i]);
              at.addAll(<double>[kx, y]);
              if (i > 0) line(kx - m.gap, y, kx);
              kx -= m.gap;
            }
            break;
          }
        case _Kind.Folded:
          {
            final start = x + 2 * arc;
            final from = boxes.length;
            var offset = 0.0;
            line(x, y, start);
            for (var i = 0; i < kids.length; i++) {
              final kid = kids[i];
              final ky = y + offset;
              boxes.add(kid);
              at.addAll(<double>[ky, start]);
              if (i + 1 < kids.length) {
                final next = kids[i + 1];
                final nextOffset =
                    offset + kid.down + math.max(m.sep, 2 * arc) + next.up;
                final mid =
                    y + offset + kid.down + math.max(m.sep, 2 * arc) / 2;
                track.write(
                  'M${num(start + kid.width)},${num(ky)}H${num(right - 2 * arc)}V${num(mid)}H${num(x + arc)}V${num(y + nextOffset)}H${num(start)}',
                );
                arrows.write(
                  'M${num(start - _arrow)},${num(y + nextOffset - _arrow / 2)}l$_arrow,${_arrow / 2}l${-_arrow},${_arrow / 2}z',
                );
                offset = nextOffset;
              } else {
                track.write(
                  'M${num(start + kid.width)},${num(ky)}H${num(right - arc)}V${num(y)}H${num(right)}',
                );
              }
            }
            _reverse(boxes, from);
            _reverse(at, 2 * from);
            break;
          }
        case _Kind.Choice:
          {
            final inner = box.width - 4 * arc;
            final railIn = x + arc;
            final railOut = right - arc;
            final from = boxes.length;
            var offset = 0.0;
            for (var i = 0; i < kids.length; i++) {
              final kid = kids[i];
              if (i > 0) offset = _below(offset, kids[i - 1], kid, m);
              final ky = y + offset;
              final kx = x + 2 * arc + (inner - kid.width) / 2;
              final last = i == kids.length - 1;
              if (i == 0) {
                line(x, y, kx);
                line(kx + kid.width, y, right);
              } else {
                track.write(
                  (last
                          ? 'M${num(x)},${num(y)}$eastToSouth'
                                'V${num(ky - arc)}'
                          : 'M${num(railIn)},${num(ky - arc)}') +
                      southToEast +
                      (kx > railIn + arc ? 'H${num(kx)}' : '') +
                      'M${num(kx + kid.width)},${num(ky)}' +
                      (kx > railIn + arc ? 'H${num(railOut - arc)}' : '') +
                      eastToNorth +
                      (last ? 'V${num(y + arc)}$northToEast' : ''),
                );
              }
              boxes.add(kid);
              at.addAll(<double>[ky, kx]);
            }
            // Reversed, so that the branches come off the stack top to bottom.
            _reverse(boxes, from);
            _reverse(at, 2 * from);
            break;
          }
        case _Kind.Bypass:
          {
            final kid = kids[0];
            final kx = x + 2 * arc;
            line(x, y, kx);
            line(kx + kid.width, y, right);
            track.write(
              'M${num(x)},${num(y)}$eastToNorth'
              'V${num(y - box.reach + arc)}$northToEast'
              'H${num(right - 2 * arc)}$eastToSouth'
              'V${num(y - arc)}$southToEast',
            );
            boxes.add(kid);
            at.addAll(<double>[kx, y]);
            break;
          }
        case _Kind.Loop:
          {
            final kid = kids[0];
            final kx = x + (box.width - kid.width) / 2;
            final loopY = y + box.reach;
            final middle = x + box.width / 2;
            line(x, y, kx);
            line(kx + kid.width, y, right);
            track.write(
              'M${num(x + arc)},${num(y)}$loopDown'
              'V${num(loopY - arc)}$southToEast'
              'H${num(right - arc)}$eastToNorth'
              'V${num(y + arc)}$loopUp',
            );
            arrows.write(
              'M${num(middle - _arrow / 2)},${num(loopY)}l$_arrow,${-_arrow / 2}v${_arrow}z',
            );
            if (box.text.isNotEmpty) {
              nodes.write(
                '<text class="pele-edge-label pele-count" x="${num(middle)}" y="${num(loopY + _countSize + 3)}" font-size="$_countSize" fill="var(--_m)">${esc(box.text)}</text>',
              );
            }
            boxes.add(kid);
            at.addAll(<double>[kx, y]);
            break;
          }
        default:
          {
            final text = box.text;
            final space =
                text.startsWith(' ') ||
                    text.endsWith(' ') ||
                    text.contains('  ')
                ? ' xml:space="preserve"'
                : '';
            final shape =
                '<rect x="${num(x)}" y="${num(y - boxTop)}" width="${num(box.width)}" height="${num(m.height)}"';
            final label =
                '<text x="${num(x + box.width / 2)}" y="${num(y + textShift)}"$space';
            if (box.kind == _Kind.Terminal) {
              nodes.write(
                '<g class="pele-node pele-terminal">$shape rx="${num(boxTop)}" fill="var(--_s)" stroke="var(--_b)"$stroke/>$label font-family="$fontMono">${esc(text)}</text></g>',
              );
            } else if (box.kind == _Kind.NonTerminal) {
              nodes.write(
                '<g class="pele-node pele-nonterminal" data-id="${escText(box.id)}">$shape fill="var(--_bg)" stroke="var(--_b)"$stroke$roundedAttr/>$label>${esc(text)}</text></g>',
              );
            } else {
              nodes.write(
                '<g class="pele-node pele-special">$shape fill="var(--_bg)" stroke="var(--_b)" stroke-dasharray="4 3"$stroke$roundedAttr/>'
                '$label font-style="italic"><tspan fill="var(--_m)">? </tspan>${esc(text.substring(2, text.length - 2))}<tspan fill="var(--_m)"> ?</tspan></text></g>',
              );
            }
          }
      }
    }
  }

  final rules = StringBuffer();
  var width = title.width;
  var top = pad + titleHeight;
  var bottom = pad + title.height;
  for (final rule in model.rules) {
    final box = _measure(
      rule.definition,
      m,
      tight
          ? math.max(
              80.0,
              (options.maxWidth ?? 320) - 2 * pad - 4 * radius - 2 * _lead - 1,
            )
          : double.infinity,
    );
    final name = _shown(rule.name);
    final baseline = top + headHeight + _headGap + box.up;
    final start = pad + 2 * radius;
    final left = start + _lead;
    final end = left + box.width + _lead;
    track.clear();
    arrows.clear();
    nodes.clear();
    line(start, baseline, left);
    line(left + box.width, baseline, end);
    place(box, left, baseline);
    final markers = radius > 0
        ? '<circle class="pele-marker pele-start" cx="${num(pad + radius)}" cy="${num(baseline)}" r="${num(radius)}" fill="var(--_l)"/>'
              '<circle class="pele-marker pele-end" cx="${num(end + radius)}" cy="${num(baseline)}" r="${num(radius)}" fill="var(--_l)"/>'
        : '';
    final arrowsStr = arrows.toString();
    rules.write(
      '<g class="pele-rule" data-id="${escText(rule.name)}">'
              '<text class="pele-rule-name" x="${num(pad)}" y="${num(top + headHeight / 2 + headSize * 0.35)}" font-size="${num(headSize)}" font-weight="var(--_hw)" text-anchor="start">${esc(name)}</text>'
              '<path class="pele-edge pele-track" d="$track" fill="none" stroke="var(--_l)"$stroke/>' +
          (arrowsStr.isNotEmpty
              ? '<path class="pele-marker" d="$arrowsStr" fill="var(--_l)"/>'
              : '') +
          markers +
          nodes.toString() +
          '</g>',
    );
    width = math.max(
      width,
      math.max(
        end + 2 * radius - pad,
        m.measurer.width(name, headSize, Style.Bold),
      ),
    );
    bottom = baseline + box.down;
    top = bottom + m.sep + _ruleGap;
  }

  final totalWidth = (width + 2 * pad).ceilToDouble();
  final totalHeight = (bottom + pad).ceilToDouble();
  final rulesStr = rules.toString();
  final content =
      labelSvg(
        title,
        totalWidth / 2,
        pad + title.height / 2,
        ' class="pele-title" font-weight="var(--_tw)"',
      ) +
      (rulesStr.isNotEmpty
          ? '<g class="pele-rules" transform="translate(0.5,0.5)" font-size="${num(size)}" text-anchor="middle">$rulesStr</g>'
          : '');

  return Rendered(
    svg: svgDocument(
      'railroad',
      totalWidth,
      totalHeight,
      base,
      options,
      model,
      content,
    ),
    width: totalWidth,
    height: totalHeight,
    links: <LinkInfo>[],
  );
}

// Upstream: src/diagrams/usecase/render.ts

import 'dart:math' as math;

import '../../layout/compound.dart' hide Style;
import '../../layout/layered.dart' show LayeredOptions;
import '../../preprocess.dart';
import '../../svg/builder.dart';
import '../../svg/cluster.dart';
import '../../svg/edges.dart';
import '../../svg/ink.dart';
import '../../svg/root.dart';
import '../../svg/theme.dart';
import '../../svg/title.dart';
import '../../text/label.dart';
import '../../text/measurer.dart';
import '../../types.dart';
import '../../util/math_js.dart';
import '../common/fit_width.dart';
import 'graph.dart';
import 'types.dart' show UsecaseModel;

const double _nodeSep = 32;
const double _edgeSep = 16;
const double _rankSep = 72;
const double _groupPad = 20;
const double _loop = 26;
const double _figureW = 40;
const double _figureH = 60;
const double _figureGap = 6;
const double _tabPad = 6;
const double _cellPad = 10;
const double _rowPad = 8;
const double _fold = 9;
const double _extensionSize = 12;
const double _portGap = 14;
const String _shapeAttrs = ' fill="var(--_s)" stroke="var(--_b)"';

abstract final class _Kind {
  static const int actor = 0;
  static const int ellipse = 1;
  static const int box = 2;
  static const int json = 3;
  static const int boundary = 4;
}

class _View {
  _View({
    required this.node,
    required this.kind,
    required this.style,
    required this.label,
    required this.stereotype,
  });

  final UsecaseGraphNode node;
  int kind;
  final ResolvedStyle style;
  Label label;
  final Label stereotype;
  // The size of what is drawn; the layout box is larger when the node carries a self-relationship.
  double w = 0;
  double h = 0;
  final List<(Label, Label)> rows = <(Label, Label)>[];
  double keyW = 0;
  double headH = 0;
  int loops = 0;
}

double _numberOption(Config config, String key, double fallback) {
  final section = config['usecase'];
  final value = section is Map ? section[key] : null;
  if (value is int && value > 0) {
    return math.min<double>(value.toDouble(), 2000);
  }
  if (value is double && value > 0) {
    return math.min<double>(value, 2000);
  }
  return fallback;
}

final RegExp _reLiteral = RegExp(r'[&<>\\]');

// A plain label is shown as written: no tags, no markdown, no `\n` breaks. Its markup characters
// are handed to the label parser as character references, which it turns back into characters.
String _literal(String text) {
  return text.replaceAllMapped(
    _reLiteral,
    (m) => '&#${m.group(0)!.codeUnitAt(0)};',
  );
}

Label _text(
  String? raw,
  bool markdown,
  TextMeasurer measurer,
  double size,
  double wrap, [
  int base = 0,
]) {
  return layoutLabel(
    raw != null && raw.isNotEmpty && !markdown ? _literal(raw) : raw,
    markdown,
    measurer,
    size,
    wrap,
    base,
  );
}

// The point of a node's outline on one of its four sides (0 top, 1 right, 2 bottom, 3 left),
// `along` away from the middle of that side. Lines meet an actor at its figure, not at its label.
(double, double) _anchor(_View view, CNode c, int side, double along) {
  final sign = side == 1 || side == 2 ? 1.0 : -1.0;
  final upright = side == 1 || side == 3;
  var reach = (upright ? view.w : view.h) / 2;
  var middle = 0.0;
  if (view.kind == _Kind.actor) {
    if (upright) {
      reach = _figureW / 2 + 3;
      middle = (_figureH - view.h) / 2;
    } else {
      reach += 2;
    }
  } else if (view.kind == _Kind.ellipse) {
    final span = (upright ? view.h : view.w) / 2;
    final ratio = along / span;
    reach *= math.sqrt(math.max<double>(1 - ratio * ratio, 0));
  }
  return upright
      ? (c.x + sign * reach, c.y + middle + along)
      : (c.x + along, c.y + sign * reach);
}

// How much of a side edges may spread over.
double _sideLength(_View view, int side) {
  final upright = side == 1 || side == 3;
  if (view.kind == _Kind.actor) {
    return upright ? _figureH * 0.5 : _figureW * 0.6;
  }
  final length = upright ? view.h : view.w;
  return view.kind == _Kind.ellipse ? length * 0.6 : length - 16;
}

class _End {
  const _End({
    required this.route,
    required this.at,
    required this.toward,
    required this.order,
  });

  final List<double> route;
  final int at;
  final double toward;
  final int order;
}

// The layout brings every edge that ends on one side of a node to the middle of that side. This
// spaces them along the side in the order they fan out, and puts each on the node's outline.
void _attachEnds(List<CEdge> cedges, List<CNode> cnodes, List<_View> views) {
  final sides = <int, List<_End>>{};
  void add(int index, List<double> route, int at, int next) {
    final c = cnodes[index];
    if (c.isGroup) return;
    final dx = route[at] - c.x;
    final dy = route[at + 1] - c.y;
    int side;
    if ((dy.abs() - c.h / 2).abs() < 0.5) {
      side = dy < 0 ? 0 : 2;
    } else if ((dx.abs() - c.w / 2).abs() < 0.5) {
      side = dx < 0 ? 3 : 1;
    } else {
      return;
    }
    final key = index * 4 + side;
    final list = sides[key];
    final end = _End(
      route: route,
      at: at,
      toward: route[next + ((side & 1) != 0 ? 1 : 0)],
      order: list?.length ?? 0,
    );
    if (list != null) {
      list.add(end);
    } else {
      sides[key] = <_End>[end];
    }
  }

  for (final e in cedges) {
    final last = e.route.length - 3;
    if (e.src == e.dst || last < 3) continue;
    add(e.src, e.route, 0, 3);
    add(e.dst, e.route, last, last - 3);
  }
  for (final entry in sides.entries) {
    final key = entry.key;
    final ends = entry.value;
    final index = key >> 2;
    final side = key & 3;
    final view = views[index];
    final step = ends.length > 1
        ? math.min<double>(
            _portGap,
            _sideLength(view, side) / (ends.length - 1),
          )
        : 0.0;
    ends.sort((a, b) {
      final cmp = a.toward.compareTo(b.toward);
      return cmp != 0 ? cmp : a.order - b.order;
    });
    for (var i = 0; i < ends.length; i++) {
      final (x, y) = _anchor(
        view,
        cnodes[index],
        side,
        (i - (ends.length - 1) / 2) * step,
      );
      ends[i].route[ends[i].at] = x;
      ends[i].route[ends[i].at + 1] = y;
    }
  }
}

// The hollow triangle of a generalization, with its tip at (x, y).
String _extension(double x, double y, double dx, double dy, String color) {
  final bx = x - dx * _extensionSize;
  final by = y - dy * _extensionSize;
  const half = _extensionSize * 0.5;
  return '<path class="pele-marker" d="M${num(x)},${num(y)}L${num(bx - dy * half)},${num(by + dx * half)}L${num(bx + dy * half)},${num(by - dx * half)}Z" fill="var(--_bg)" stroke="$color" stroke-linejoin="round"/>';
}

double _trim(String type) {
  return type == 'extension' ? _extensionSize : markerTrim(type);
}

String _mark(
  String type,
  double x,
  double y,
  double dx,
  double dy,
  String color, [
  String stroke = 'none',
]) {
  return type == 'extension'
      ? _extension(x, y, dx, dy, color)
      : marker(type, x, y, dx, dy, color, stroke);
}

String _figure(_View view, IconResolver? icons) {
  final node = view.node;
  final shape = view.style.shape;
  final line = ' fill="none" stroke="var(--_b)"${view.style.line}';
  var head = -21.0;
  var radius = 9.0;
  String out;
  if (node.actorType == 'hollow') {
    radius = 8;
    out =
        '<circle cy="-21" r="8" fill="var(--_bg)" stroke="var(--_b)"$shape/>'
        '<path d="M-20,-9H20V0H5.5L20,15.5L12,25.5L0,12L-12,25.5L-20,15.5L-5.5,0H-20Z" fill="var(--_bg)" stroke="var(--_b)" stroke-linejoin="round"$shape/>';
  } else if (node.actorType == 'awesome') {
    out =
        '<path d="M0,-30A11,11 0 1 1 0,-8A11,11 0 1 1 0,-30ZM-20,25C-20,9 -12,-3 0,-3C12,-3 20,9 20,25C20,28 18,30 15,30H-15C-18,30 -20,28 -20,25Z" fill="var(--_b)"$shape/>';
  } else if (node.actorType == 'icon') {
    head = -14;
    radius = 12;
    out =
        '<rect x="-22" y="-26" width="44" height="44"${rounded('$_shapeAttrs$shape')}/>'
        '<svg class="pele-icon" data-icon="${escText(node.icon ?? '')}" x="-14" y="-18" width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${icons?.call(node.icon ?? '') ?? ''}</svg>';
  } else {
    out =
        '<circle cy="-21" r="9"$_shapeAttrs$shape/><path d="M0,-12V10M-14,-3H14M0,10L-12,30M0,10L12,30"$line/>';
  }
  if (node.business == true) {
    // The slash of a business actor: a chord across the lower right of the head.
    out +=
        '<path class="pele-business" d="M${num(0.12 * radius)},${num(head + 0.99 * radius)}L${num(0.92 * radius)},${num(head - 0.39 * radius)}"$line/>';
  }
  return out;
}

Rendered renderUsecase(
  UsecaseModel model,
  Config config,
  RenderOptions options,
) {
  if (!runsAcross(model.direction)) return _draw(model, config, options, false);
  return turnToFit(options, (down) => _draw(model, config, options, down));
}

final RegExp _reLeadDefault = RegExp(r'^default\s?');
final RegExp _reEdgePrefix = RegExp(
  r'^default relationship relationship-\S+\s?',
);

// `turned` draws a diagram that runs across as one that runs down.
Rendered _draw(
  UsecaseModel model,
  Config config,
  RenderOptions options,
  bool turned,
) {
  final graph = buildUsecaseGraph(model);
  final size = options.fontSize ?? 16;
  final smallInt = roundJs(size * 0.875);
  final tinyInt = roundJs(size * 0.8125);
  final small = smallInt.toDouble();
  final tiny = tinyInt.toDouble();
  final measurer =
      options.measurer ??
      defaultMeasurer(options.fontFamily, options.fontFamilyMono);
  final pad = options.padding ?? 8;
  final icons = options.icons;
  final rootDir = turned ? 'TB' : direction(model.direction);
  final sideways = rootDir == 'LR' || rootDir == 'RL';

  final index = <String, int>{};
  final views = <_View>[];
  final cnodes = <CNode>[];
  for (var i = 0; i < graph.nodes.length; i++) {
    index[graph.nodes[i].id] = i;
  }

  for (final node in graph.nodes) {
    final style = resolveStyle(
      node.cssStyles.isNotEmpty
          ? <String>[...node.cssCompiledStyles, ...node.cssStyles]
          : node.cssCompiledStyles,
    );
    final base =
        (style.bold ? Style.Bold : 0) | (style.italic ? Style.Italic : 0);
    final fontSize = style.fontSize ?? size;
    final markdown = node.labelType == 'markdown';
    final stereotype = _text(
      (node.stereotype != null && node.stereotype!.isNotEmpty)
          ? '«${node.stereotype}»'
          : null,
      false,
      measurer,
      tiny,
      200,
      base,
    );
    final view = _View(
      node: node,
      kind: _Kind.box,
      style: style,
      label: stereotype,
      stereotype: stereotype,
    );
    CNode c;
    if (node.isGroup) {
      view.kind = _Kind.boundary;
      view.label = _text(node.label, markdown, measurer, fontSize, 4000, base);
      final titleH = view.label.height;
      c = cnode(0, 0);
      c.isGroup = true;
      c.padX = _groupPad;
      c.padBottom = _groupPad;
      c.padTop = node.boundaryType == 'package'
          ? titleH + 2 * _tabPad + 16
          : titleH > 0
          ? titleH + 16
          : _groupPad;
      c.minW = view.label.width + 2 * _groupPad;
    } else {
      if (node.jsonRows != null) {
        view.kind = _Kind.json;
        view.label = _text(
          node.label,
          false,
          measurer,
          fontSize,
          4000,
          base | Style.Bold,
        );
        var valueW = 0.0;
        for (final row in node.jsonRows!) {
          final key = _text(row.key, false, measurer, small, 4000, base);
          final value = _text(row.value, false, measurer, small, 260, base);
          view.rows.add((key, value));
          view.keyW = math.max<double>(view.keyW, key.width);
          valueW = math.max<double>(valueW, value.width);
          view.h +=
              math.max<double>(
                math.max<double>(key.height, value.height),
                roundJs(small * 1.5).toDouble(),
              ) +
              _rowPad;
        }
        // The root of an empty object has a value and no key, and then there is no key column.
        if (view.keyW > 0) view.keyW += 2 * _cellPad;
        view.headH =
            math.max<double>(
              view.label.height,
              roundJs(fontSize * 1.5).toDouble(),
            ) +
            _rowPad;
        view.w = math.max<double>(
          math.max<double>(
            view.label.width + 2 * _cellPad,
            view.rows.isNotEmpty ? view.keyW + valueW + 2 * _cellPad : 0,
          ),
          72,
        );
        view.h += view.headH;
      } else if (node.actorType != null && node.actorType!.isNotEmpty) {
        view.kind = _Kind.actor;
        view.label = _text(node.label, markdown, measurer, fontSize, 140, base);
        view.w = math.max<double>(
          _figureW,
          math.max<double>(view.label.width, stereotype.width),
        );
        view.h = _figureH + _figureGap + stereotype.height + view.label.height;
      } else {
        view.label = _text(
          node.label,
          markdown,
          measurer,
          node.shape == 'note' ? small : fontSize,
          180,
          base,
        );
        final tw = math.max<double>(view.label.width, stereotype.width);
        final th = view.label.height + stereotype.height;
        if (node.shape == 'usecaseEllipse' || node.shape == 'usecaseBusiness') {
          view.kind = _Kind.ellipse;
          // An oval needs more room around its text than a box, and a business oval room for its slash.
          view.w = math.max<double>(
            tw + 2 * node.padding + (node.business == true ? 16 : 4),
            88,
          );
          view.h = math.max<double>(th + 28, 48);
        } else if (node.shape == 'note') {
          view.w = tw + 2 * node.padding + 6;
          view.h = th + 18;
        } else {
          view.w = math.max<double>(tw + 2 * node.padding + 12, 80);
          view.h = math.max<double>(th + 24, 44);
        }
      }
      c = cnode(view.w, view.h);
    }
    c.seq = views.length.toDouble();
    views.add(view);
    cnodes.add(c);
  }
  for (var i = 0; i < graph.nodes.length; i++) {
    final parentId = graph.nodes[i].parentId;
    cnodes[i].parent = parentId != null ? (index[parentId] ?? -1) : -1;
  }

  final cedges = <CEdge>[];
  final edgeLabels = <Label>[];
  final drawn = <UsecaseGraphEdge>[];
  for (final edge in graph.edges) {
    final src = index[edge.start];
    final dst = index[edge.end];
    if (src == null || dst == null) continue;
    final semantic =
        edge.relationshipType == 'include' || edge.relationshipType == 'extend';
    final label = _text(
      semantic ? '«${edge.label}»' : edge.label,
      edge.labelType == 'markdown',
      measurer,
      small,
      200,
    );
    if (src == dst) {
      // A self-relationship loops out across the flow, and the node's box grows to hold it.
      views[src].loops++;
      if (sideways) {
        cnodes[src].h +=
            2 * (_loop + (label.height > 0 ? label.height + 8 : 0));
      } else {
        cnodes[src].w += 2 * (_loop + (label.width > 0 ? label.width + 12 : 0));
      }
    }
    drawn.add(edge);
    edgeLabels.add(label);
    cedges.add(
      CEdge(
        src: src,
        dst: dst,
        minlen: edge.minlen,
        labelW: label.width > 0 ? label.width + 12 : 0,
        labelH: label.height > 0 ? label.height + 4 : 0,
        route: <double>[],
        labelX: 0,
        labelY: 0,
      ),
    );
  }

  final layout = compoundLayout(
    cnodes,
    cedges,
    rootDir,
    LayeredOptions(
      nodeSep: _numberOption(config, 'nodeSpacing', _nodeSep),
      edgeSep: _edgeSep,
      rankSep: _numberOption(config, 'rankSpacing', _rankSep),
      portSep: 20,
    ),
  );

  final title = titleLabel(model.title, measurer, size, 4000);
  final titleHeight = title.height > 0 ? title.height + 12 : 0.0;
  final inner = math.max<double>(layout.width, title.width);
  final ox = pad + (inner - layout.width) / 2;
  final oy = pad + titleHeight;
  shiftLayout(cnodes, cedges, ox, oy);
  final width = (inner + 2 * pad).ceilToDouble();
  final height = (layout.height + titleHeight + 2 * pad).ceilToDouble();

  // Where edges cross each boundary's top border, so that a title can keep out of their way.
  final crossings = <int, List<double>>{};
  for (final e in cedges) {
    markCrossings(crossings, e.route);
  }
  _attachEnds(cedges, cnodes, views);

  final clusters = StringBuffer();
  final fills = <Fill>[];
  final nodesOut = StringBuffer();
  for (var i = 0; i < views.length; i++) {
    final view = views[i];
    final c = cnodes[i];
    final node = view.node;
    final classes = classNames(
      node.cssClasses.replaceFirst(_reLeadDefault, ''),
    );
    final id = escText(node.id);
    final textAttrs = view.style.text;
    final shape = view.style.shape;
    final color = inkFill((shape: view.style.shape, text: view.style.text));
    final muted = color.isNotEmpty ? color : ' fill="var(--_m)"';
    final w = view.w;
    final h = view.h;

    if (view.kind == _Kind.boundary) {
      final x = c.x - c.w / 2;
      final y = c.y - c.h / 2;
      if (paints(shape)) {
        fills.add(Fill(box: <double>[x, y, x + c.w, y + c.h], shape: shape));
      }
      final box =
          ' fill="var(--_a)"${setsFill(shape) ? '' : ' fill-opacity="0.5"'} stroke="var(--_b)"$shape';
      final titleAttrs = ' class="pele-cluster-label"$muted$textAttrs';
      String body;
      if (node.boundaryType == 'package') {
        final tabW = math.min<double>(view.label.width + 2 * _tabPad + 8, c.w);
        final tabH = view.label.height + 2 * _tabPad;
        body =
            '<rect class="pele-boundary-tab" x="${num(x)}" y="${num(y)}" width="${num(tabW)}" height="${num(tabH)}"$box/>'
            '<rect x="${num(x)}" y="${num(y + tabH)}" width="${num(c.w)}" height="${num(c.h - tabH)}"$box/>'
            '${labelSvg(view.label, x + tabW / 2, y + tabH / 2, titleAttrs, icons)}';
      } else {
        body =
            '<rect x="${num(x)}" y="${num(y)}" width="${num(c.w)}" height="${num(c.h)}"${rounded(box)}/>'
            '${labelSvg(view.label, _titleX(c, view.label.width, crossings), y + 8 + view.label.height / 2, titleAttrs, icons)}';
      }
      clusters.write(
        '<g class="pele-cluster pele-boundary$classes" data-id="$id">$body</g>',
      );
      continue;
    }

    String body;
    String kind;
    if (view.kind == _Kind.actor) {
      kind = 'pele-actor';
      final top = -h / 2;
      final stereotypeY =
          top + _figureH + _figureGap + view.stereotype.height / 2;
      body =
          '<g class="pele-actor-figure" transform="translate(0,${num(top + _figureH / 2)})">${_figure(view, icons)}</g>'
          '${labelSvg(view.stereotype, 0, stereotypeY, ' class="pele-stereotype" font-size="$tinyInt" fill="var(--_m)"', icons)}'
          '${labelSvg(view.label, 0, h / 2 - view.label.height / 2, ' class="pele-label"$textAttrs', icons)}';
    } else if (view.kind == _Kind.json) {
      kind = 'pele-json';
      final x0 = -w / 2;
      var y = -h / 2 + view.headH;
      final cells = StringBuffer();
      var lines = 'M${num(x0)},${num(y)}H${num(x0 + w)}';
      if (view.keyW > 0) {
        lines += 'M${num(x0 + view.keyW)},${num(y)}V${num(h / 2)}';
      }
      for (final (key, value) in view.rows) {
        final rowH =
            math.max<double>(
              math.max<double>(key.height, value.height),
              roundJs(small * 1.5).toDouble(),
            ) +
            _rowPad;
        cells
          ..write(
            labelSvg(
              key,
              x0 + _cellPad + key.width / 2,
              y + rowH / 2,
              ' class="pele-json-key"$muted',
              icons,
            ),
          )
          ..write(
            _leftLabel(
              value,
              x0 + view.keyW + _cellPad,
              y + rowH / 2,
              ' class="pele-json-value"$color$textAttrs',
              icons,
            ),
          );
        y += rowH;
      }
      body =
          '<rect x="${num(x0)}" y="${num(-h / 2)}" width="${num(w)}" height="${num(h)}"${rounded('$_shapeAttrs$shape')}/>'
          '<path class="pele-json-lines" d="$lines" fill="none" stroke="var(--_b)"${view.style.line}/>'
          '${labelSvg(view.label, 0, -h / 2 + view.headH / 2, ' class="pele-label" font-weight="var(--_hw)"$color$textAttrs', icons)}'
          '<g font-size="$smallInt">$cells</g>';
    } else {
      final labelY = view.stereotype.height / 2;
      String outline;
      if (view.kind == _Kind.ellipse) {
        kind = 'pele-usecase';
        outline =
            '<ellipse rx="${num(w / 2)}" ry="${num(h / 2)}"$_shapeAttrs$shape/>';
        if (node.business == true) {
          // The slash of a business use case, cutting off the right end of the oval beside the text.
          final from = w / 2 - 15;
          final to = w / 2 - 5;
          double arc(double at) {
            final ratio = at / (w / 2);
            return (h / 2) * math.sqrt(1 - ratio * ratio);
          }

          outline +=
              '<path class="pele-business" d="M${num(from)},${num(arc(from))}L${num(to)},${num(-arc(to))}" fill="none" stroke="var(--_b)"${view.style.line}/>';
        }
      } else if (node.shape == 'note') {
        kind = 'pele-note';
        final r = w / 2;
        final b = h / 2;
        outline =
            '<path d="M${num(-r)},${num(-b)}H${num(r - _fold)}L${num(r)},${num(_fold - b)}V${num(b)}H${num(-r)}Z" fill="var(--_a)" stroke="var(--_b)" stroke-linejoin="round"$shape/>'
            '<path d="M${num(r - _fold)},${num(-b)}V${num(_fold - b)}H${num(r)}" fill="none" stroke="var(--_b)" stroke-linejoin="round"${view.style.line}/>';
      } else {
        kind = 'pele-usecase';
        outline =
            '<rect x="${num(-w / 2)}" y="${num(-h / 2)}" width="${num(w)}" height="${num(h)}"${rounded('$_shapeAttrs$shape')}/>';
      }
      body =
          outline +
          labelSvg(
            view.stereotype,
            0,
            -view.label.height / 2,
            ' class="pele-stereotype" font-size="$tinyInt"$muted',
            icons,
          ) +
          labelSvg(
            view.label,
            0,
            labelY,
            ' class="pele-label"${node.shape == 'note' ? ' font-size="$smallInt"' : ''}$color$textAttrs',
            icons,
          );
    }
    nodesOut.write(
      '<g class="pele-node $kind$classes" data-id="$id" transform="translate(${num(c.x)},${num(c.y)})">$body</g>',
    );
  }

  final casings = StringBuffer();
  final edgesOut = StringBuffer();
  final labelsOut = StringBuffer();
  final loopSeen = <int, int>{};
  for (var i = 0; i < cedges.length; i++) {
    final ce = cedges[i];
    final edge = drawn[i];
    final label = edgeLabels[i];
    final style = (edge.style.isNotEmpty || edge.cssCompiledStyles.isNotEmpty)
        ? resolveStyle(<String>[...edge.cssCompiledStyles, ...edge.style])
        : null;
    final startType = edge.arrowTypeStart;
    final endType = edge.arrowTypeEnd;
    EdgePath path;
    if (ce.src == ce.dst) {
      final c = cnodes[ce.src];
      final view = views[ce.src];
      final k = loopSeen[ce.src] ?? 0;
      loopSeen[ce.src] = k + 1;
      final side = sideways ? 2 : 1;
      final spread = math.min<double>(_sideLength(view, side) / 2, 8.0 + k * 6);
      final reach = _loop + k * 8;
      final (ax, ay) = _anchor(view, c, side, -spread);
      final (bx, by) = _anchor(view, c, side, spread);
      final rawLen = hypot(reach, spread);
      final len = rawLen != 0 ? rawLen : 1.0;
      final ux = sideways ? spread / len : reach / len;
      final uy = sideways ? reach / len : spread / len;
      final st = _trim(startType);
      final et = _trim(endType);
      // Both ends leave the node leaning away from each other, and the curve joins them outside it.
      String out(double x, double y, double sign, double far) => sideways
          ? '${num(x + sign * spread * (far != 0 ? 1 : 0))},${num(y + far)}'
          : '${num(x + far)},${num(y + sign * spread * (far != 0 ? 1 : 0))}';
      final sx = sideways ? ax - ux * st : ax + ux * st;
      final sy = sideways ? ay + uy * st : ay - uy * st;
      final ex = bx + ux * et;
      final ey = by + uy * et;
      path = EdgePath(
        d: 'M${num(sx)},${num(sy)}C${out(ax, ay, -1, reach)} ${out(bx, by, 1, reach)} ${num(ex)},${num(ey)}',
        sx: ax,
        sy: ay,
        sdx: sideways ? ux : -ux,
        sdy: sideways ? -uy : uy,
        ex: bx,
        ey: by,
        edx: -ux,
        edy: -uy,
      );
      if (sideways) {
        ce.labelX = c.x;
        ce.labelY =
            math.max<double>(ay, by) + reach * 0.75 + 6 + label.height / 2;
      } else {
        ce.labelX =
            math.max<double>(ax, bx) + reach * 0.75 + 8 + label.width / 2;
        ce.labelY = c.y;
      }
    } else {
      if (ce.route.length < 6) continue;
      path = routePath(ce.route, null, _trim(startType), _trim(endType));
    }
    final under = fillUnder(
      path.d,
      <double>[path.sx, path.sy, path.ex, path.ey],
      fills,
      path.tokens,
    );
    final over = under is Fill
        ? edgeInk(under, style?.line ?? '')
        : (under as String?);
    final color = (over != null && over.isNotEmpty)
        ? over
        : ((style?.stroke != null && style!.stroke!.isNotEmpty)
              ? esc(style.stroke!)
              : 'var(--_l)');
    if (over == '') {
      const bg = 'var(--_bg)';
      casings.write(
        casing(
          path.d,
          _mark(startType, path.sx, path.sy, path.sdx, path.sdy, bg, bg) +
              _mark(endType, path.ex, path.ey, path.edx, path.edy, bg, bg),
          style?.line ?? '',
        ),
      );
    }
    // Mermaid animates these dashes. A still picture keeps the dashes.
    final dashes = edge.internal
        ? '2 3'
        : edge.pattern == 'dotted'
        ? '5 4'
        : edge.animate
        ? '9 5'
        : '';
    final marks =
        _mark(startType, path.sx, path.sy, path.sdx, path.sdy, color) +
        _mark(endType, path.ex, path.ey, path.edx, path.edy, color);
    edgesOut.write(
      '<g class="pele-edge pele-${edge.relationshipType}${classNames(edge.classes.replaceFirst(_reEdgePrefix, ''))}" data-id="${escText(edge.id)}"${(over != null && over.isNotEmpty) ? ' stroke="$over"' : ''}${style?.line ?? ''}>'
      '<path d="${path.d}"${dashes.isNotEmpty ? ' stroke-dasharray="$dashes"' : ''}/>'
      '${(under is Fill && over != null && over.isNotEmpty) ? hollowOn(marks, under) : marks}'
      '</g>',
    );
    if (label.width > 0) {
      final x = ce.labelX;
      final y = ce.labelY;
      final semantic =
          edge.relationshipType == 'include' ||
          edge.relationshipType == 'extend';
      labelsOut.write(
        edgeLabelSvg(
          edge.id,
          label,
          x,
          y,
          '${semantic ? ' fill="var(--_m)"' : ''}${style?.text ?? ''}',
          icons,
        ),
      );
    }
  }

  final clustersStr = clusters.toString();
  final edgesStr = edgesOut.toString();
  final labelsStr = labelsOut.toString();
  final svg = svgDocument(
    'usecase',
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
        (clustersStr.isNotEmpty
            ? '<g class="pele-clusters">$clustersStr</g>'
            : '') +
        casingsSvg(casings.toString()) +
        (edgesStr.isNotEmpty
            ? '<g class="pele-edges" fill="none" stroke="var(--_l)" stroke-linecap="round">$edgesStr</g>'
            : '') +
        (labelsStr.isNotEmpty
            ? '<g class="pele-edge-labels" font-size="$smallInt">$labelsStr</g>'
            : '') +
        '<g class="pele-nodes">$nodesOut</g>',
  );

  return Rendered(svg: svg, width: width, height: height, links: <LinkInfo>[]);
}

// A boundary's title sits in the middle of its top edge. Where edges enter through that edge it
// moves into the stretch between them that is nearest the middle, or the widest if none has room.
double _titleX(CNode c, double width, Map<int, List<double>> crossings) {
  final xs = crossings[roundJs(c.y - c.h / 2)];
  if (width == 0 || xs == null) return c.x;
  final left = c.x - c.w / 2 + 6;
  final right = c.x + c.w / 2 - 6;
  final cuts = <double>[
    for (final x in xs)
      if (x > left && x < right) x,
  ]..sort((a, b) => a.compareTo(b));
  cuts.add(right);
  final need = width / 2 + 6;
  var best = c.x;
  var bestOff = double.infinity;
  var widest = 0.0;
  var from = left;
  for (final cut in cuts) {
    if (cut - from >= 2 * need) {
      final x = math.min<double>(
        math.max<double>(c.x, from + need),
        cut - need,
      );
      if ((x - c.x).abs() < bestOff) {
        bestOff = (x - c.x).abs();
        best = x;
      }
    } else if (bestOff == double.infinity && cut - from > widest) {
      widest = cut - from;
      best = (from + cut) / 2;
    }
    from = cut;
  }
  return best;
}

String _leftLabel(
  Label label,
  double x,
  double cy,
  String attrs,
  IconResolver? icons,
) {
  if (label.lines.length < 2) {
    return labelSvg(label, x + label.width / 2, cy, attrs, icons);
  }
  final out = StringBuffer();
  for (var i = 0; i < label.lines.length; i++) {
    out.write(
      labelSvg(
        labelLine(label, i),
        x + label.widths[i] / 2,
        cy - label.height / 2 + lineMiddle(label, i),
        attrs,
        icons,
      ),
    );
  }
  return out.toString();
}

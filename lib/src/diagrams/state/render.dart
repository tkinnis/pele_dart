// Upstream: src/diagrams/state/render.ts

import 'dart:math' as math;
import 'dart:typed_data';

import '../../layout/compound.dart' hide Style;
import '../../layout/layered.dart' show LayeredOptions;
import '../../preprocess.dart';
import '../../svg/builder.dart';
import '../../svg/edges.dart';
import '../../svg/ink.dart';
import '../../svg/root.dart';
import '../../svg/shapes.dart';
import '../../svg/theme.dart';
import '../../svg/title.dart';
import '../../text/entities.dart';
import '../../text/label.dart';
import '../../text/measurer.dart';
import '../../types.dart';
import '../../util/math_js.dart';
import '../../util/url.dart';
import '../common/fit_width.dart';
import 'db.dart';
import 'graph.dart';

const double _nodeSep = 40;
const double _edgeSep = 16;
const double _rankSep = 44;
const double _groupPad = 16;
const double _regionPad = 10;
const double _padX = 16;
const double _padY = 10;
const double _loop = 26;
const double _fold = 8;
const double _noteWrap = 320;
const double _corner = 10;
const double _bar = 8;
const String _surface = ' fill="var(--_s)" stroke="var(--_b)"';
const String _rule = ' fill="none" stroke="var(--_b)"';
final RegExp _mermaidClasses = RegExp(
  r'(?:^| )statediagram-(?:state|cluster-alt|cluster|note)(?= |$)',
);

abstract final class _K {
  static const int state = 0;
  static const int described = 1;
  static const int start = 2;
  static const int end = 3;
  static const int choice = 4;
  static const int fork = 5;
  static const int join = 6;
  static const int note = 7;
  static const int composite = 8;
  static const int region = 9;
  static const int hidden = 10;
}

const Map<String, int> _kinds = <String, int>{
  'rectWithTitle': _K.described,
  'stateStart': _K.start,
  'stateEnd': _K.end,
  'choice': _K.choice,
  'fork': _K.fork,
  'join': _K.join,
  'note': _K.note,
  'divider': _K.hidden,
};

const List<String> _classes = <String>[
  'pele-node pele-state',
  'pele-node pele-state',
  'pele-node pele-state-start',
  'pele-node pele-state-end',
  'pele-node pele-state-choice',
  'pele-node pele-state-fork',
  'pele-node pele-state-join',
  'pele-note',
  'pele-cluster pele-state-composite',
];

class _View {
  _View({
    required this.node,
    required this.kind,
    required this.label,
    required this.lines,
  });

  // Absent for the unseen helpers the layout needs.
  final StateNode? node;
  final int kind;
  ResolvedStyle? style;
  Label label;
  final List<Label> lines;
  double w = 0;
  double h = 0;
  double titleH = 0;
}

bool _vertical(Dir? dir) {
  return dir == 'TB' || dir == 'BT';
}

double _numberOption(Config config, String key, double fallback) {
  final stateCfg = config['state'];
  final value = stateCfg is Map ? stateCfg[key] : null;
  if (value is int && value > 0) return math.min(value.toDouble(), 2000.0);
  if (value is double && value > 0) return math.min(value, 2000.0);
  return fallback;
}

// Mermaid keeps the quotes of a click statement's strings and strips them when it draws.
String _unquote(String text) {
  var from = 0;
  var to = text.length;
  while (from < to && charCodeAt(text, from) == 34) {
    from++;
  }
  while (to > from && charCodeAt(text, to - 1) == 34) {
    to--;
  }
  return text.substring(from, to);
}

double _clamp(double value, double min, double max) {
  return value < min ? min : (value > max ? max : value);
}

String _rect(double x, double y, double w, double h, String rest) {
  return '<rect x="${num(x)}" y="${num(y)}" width="${num(w)}" height="${num(h)}"$rest/>';
}

CNode _group(Dir dir, double padX, double padTop, double padBottom) {
  final c = cnode(0, 0);
  c.isGroup = true;
  c.dir = dir;
  c.padX = padX;
  c.padTop = padTop;
  c.padBottom = padBottom;
  return c;
}

Rendered renderState(StateDb db, Config config, RenderOptions options) {
  if (!runsAcross(db.direction)) return _draw(db, config, options, false);
  return turnToFit(options, (down) => _draw(db, config, options, down));
}

// `turned` draws a diagram that runs across as one that runs down.
Rendered _draw(StateDb db, Config config, RenderOptions options, bool turned) {
  final graph = db.graph;
  // State diagrams follow the flowchart curve.
  final flowCfg = config['flowchart'];
  final curve = flowCfg is Map ? flowCfg['curve'] : null;
  final size = options.fontSize ?? 16;
  final small = roundJs(size * 0.875).toDouble();
  final measurer =
      options.measurer ??
      defaultMeasurer(options.fontFamily, options.fontFamilyMono);
  final wrapWidth = _numberOption(config, 'wrappingWidth', 200);
  final pad = options.padding ?? 8;
  final icons = options.icons;
  final rootDir = turned ? 'TB' : direction(db.direction);
  final noLabel = layoutLabel(null, false, measurer, size, 0);
  Label text(String? raw, double fontSize, double wrap, [int style = 0]) =>
      layoutLabel(raw, true, measurer, fontSize, wrap, style);

  final index = <String, int>{};
  final views = <_View>[];
  final cnodes = <CNode>[];
  int add(StateNode? node, int kind, CNode? c) {
    views.add(_View(node: node, kind: kind, label: noLabel, lines: <Label>[]));
    if (c != null) cnodes.add(c);
    return views.length - 1;
  }

  for (final node in graph.nodes) {
    if (node.shape == 'noteGroup') continue;
    final kind = node.isGroup
        ? (node.shape == 'divider' ? _K.region : _K.composite)
        : (_kinds[node.shape] ?? _K.state);
    index[node.id] = add(node, kind, null);
  }
  final states = views.length;

  final logical = <int>[];
  for (var i = 0; i < states; i++) {
    final parentId = views[i].node!.parentId;
    final parent = parentId == null ? null : index[parentId];
    logical.add(
      parent != null && parent != i && views[parent].node!.isGroup
          ? parent
          : -1,
    );
  }
  // Composites that are redeclared inside each other form a ring with no way in from the root.
  // One member of each ring moves to the root, which leaves a tree.
  {
    final kids = List<List<int>>.generate(states, (_) => <int>[]);
    final queue = <int>[];
    final placed = Uint8List(states);
    for (var i = 0; i < states; i++) {
      if (logical[i] == -1) {
        placed[i] = 1;
        queue.add(i);
      } else {
        kids[logical[i]].add(i);
      }
    }
    var done = 0;
    void settle() {
      for (; done < queue.length; done++) {
        for (final kid in kids[queue[done]]) {
          if (placed[kid] != 0) continue;
          placed[kid] = 1;
          queue.add(kid);
        }
      }
    }

    settle();
    final seen = Int32List(states)..fillRange(0, states, -1);
    for (var i = 0; i < states; i++) {
      if (placed[i] != 0) continue;
      var ring = i;
      while (seen[ring] != i) {
        seen[ring] = i;
        ring = logical[ring];
      }
      logical[ring] = -1;
      placed[ring] = 1;
      queue.add(ring);
      settle();
    }
  }
  final owners = Int32List(states)..fillRange(0, states, -1);
  for (var i = 0; i < states; i++) {
    final noteFor = views[i].node!.noteFor;
    final owner = noteFor == null ? null : index[noteFor];
    if (owner == null) continue;
    owners[i] = owner;
    logical[i] = logical[owner];
  }

  // As in Mermaid, a composite that sets no direction runs top to bottom whatever surrounds it.
  Dir innerDir(int composite) => direction(views[composite].node!.dir);
  // Whether the flow around a state runs top to bottom or bottom to top.
  bool across(int i) =>
      _vertical(logical[i] == -1 ? rootDir : innerDir(logical[i]));

  final degree = Int32List(states);
  final noted = Uint8List(states);
  // When each state first takes part in a transition. Layout follows this order rather than
  // the order of declaration, so a state declared up front does not become the top of the flow.
  final appear = List<double>.filled(states, double.infinity, growable: true);
  var appeared = 0.0;
  final counts = Int32List(2 * states);
  for (final edge in graph.edges) {
    final src = index[edge.start];
    final dst = index[edge.end];
    if (src == null || dst == null) continue;
    if (edge.pattern == 'dashed') {
      noted[views[src].kind == _K.note ? dst : src] = 1;
      continue;
    }
    degree[src] = math.max<int>(degree[src], ++counts[2 * src]);
    degree[dst] = math.max<int>(degree[dst], ++counts[2 * dst + 1]);
    if (appear[src] == double.infinity) appear[src] = appeared++;
    if (appear[dst] == double.infinity) appear[dst] = appeared++;
  }

  for (var i = 0; i < states; i++) {
    final view = views[i];
    final node = view.node!;
    final style = resolveStyle(
      node.cssStyles.isNotEmpty
          ? <String>[...node.cssCompiledStyles, ...node.cssStyles]
          : node.cssCompiledStyles,
    );
    final textStyle =
        (style.bold ? Style.bold : 0) | (style.italic ? Style.italic : 0);
    final fontSize = style.fontSize ?? size;
    view.style = style;
    CNode? c;
    switch (view.kind) {
      case _K.composite:
        view.label = text(node.label, fontSize, 4000, textStyle);
        view.titleH = view.label.height > 0 ? view.label.height + 12 : 0;
        c = _group(innerDir(i), _groupPad, view.titleH + _groupPad, _groupPad);
        c.minW = view.label.width + 2 * _groupPad;
      case _K.region:
        c = _group(innerDir(i), _regionPad, _regionPad, _regionPad);
      case _K.start:
        view.w = view.h = 14;
      case _K.end:
        view.w = view.h = 18;
      case _K.choice:
        view.w = view.h = 30;
      case _K.fork:
      case _K.join:
        final length = _clamp(40.0 * degree[i] + 16, 72, 320);
        view.w = across(i) ? length : _bar;
        view.h = across(i) ? _bar : length;
      case _K.hidden:
        break;
      case _K.note:
        view.label = text(node.label, small, math.max(wrapWidth, _noteWrap));
        view.w = view.label.width + 24;
        view.h = view.label.height + 16;
      default:
        view.label = text(node.label, fontSize, wrapWidth, textStyle);
        var width = view.label.width;
        var height = view.label.height + 2 * _padY;
        if (view.kind == _K.described) {
          height += 14;
          for (final line in node.description) {
            final label = text(
              line.isEmpty ? ' ' : line,
              small,
              wrapWidth,
              textStyle,
            );
            view.lines.add(label);
            if (label.width > width) width = label.width;
            height += label.height;
          }
        }
        view.w = math.max(width + 2 * _padX, 56.0);
        view.h = height;
    }
    c ??= cnode(view.w, view.h);
    // The transitions on one side of a state's box spread along it, clear of its corners.
    if (view.kind == _K.state || view.kind == _K.described) {
      c.span = (across(i) ? view.w : view.h) - 24;
    }
    cnodes.add(c);
  }

  final cedges = <CEdge>[];
  final edgeLabels = <Label>[];
  final drawn = <StateEdge>[];
  // The transitions each state makes to itself: how many, their widest label, and their labels' height.
  final loopCount = Int32List(states);
  final loopWidth = Float64List(states);
  final loopHeight = Float64List(states);
  // A transition between a composite and a state inside it runs between that state and a point
  // just inside the composite, and is then drawn on to the composite's border.
  final anchors = <int, int>{};
  bool encloses(int composite, int item) {
    if (!cnodes[composite].isGroup) return false;
    for (var p = logical[item]; p != -1; p = logical[p]) {
      if (p == composite) return true;
    }
    return false;
  }

  int anchor(int composite, bool first) {
    anchors[cedges.length] = composite;
    appear.add(first ? -1 : double.infinity);
    return add(null, _K.hidden, cnode(0, 0, composite));
  }

  for (final edge in graph.edges) {
    var src = index[edge.start];
    var dst = index[edge.end];
    if (src == null || dst == null) continue;
    final label = text(edge.label, small, wrapWidth);
    final labelW = label.width > 0 ? label.width + 12 : 0.0;
    if (src == dst) {
      loopCount[src]++;
      loopWidth[src] = math.max(loopWidth[src], labelW);
      loopHeight[src] += label.height;
    } else if (encloses(src, dst)) {
      src = anchor(src, true);
    } else if (encloses(dst, src)) {
      dst = anchor(dst, false);
    }
    drawn.add(edge);
    edgeLabels.add(label);
    cedges.add(
      CEdge(
        src: src,
        dst: dst,
        minlen: 1,
        labelW: labelW,
        labelH: label.height > 0 ? label.height + 4 : 0,
      ),
    );
  }

  // A state with notes, or a composite with self-transitions, sits in an unseen group of its
  // own: the notes go beside the state, across the flow, without disturbing its transitions.
  for (var i = 0; i < states; i++) {
    if (owners[i] != -1) continue;
    final item = cnodes[i];
    // Loops hang off the right, or below when the flow is horizontal, with their labels beyond them.
    var room = 0.0;
    if (loopCount[i] > 0) {
      final reach = _loop + (loopCount[i] - 1) * 8;
      room = across(i)
          ? reach + loopWidth[i]
          : reach * 0.75 + 4 + loopHeight[i];
      if (!item.isGroup) {
        if (across(i)) {
          item.w += 2 * room;
          item.h = math.max(item.h, loopHeight[i]);
        } else {
          item.h += 2 * room;
          item.w = math.max(item.w, loopWidth[i]);
        }
        room = 0;
      }
    }
    if (noted[i] == 0 && room == 0) {
      item.parent = logical[i];
      continue;
    }
    final c = across(i)
        ? _group('LR', room, 0, 0)
        : _group('TB', 0, room, room);
    c.parent = logical[i];
    appear.add(appear[i]);
    cnodes[i].parent = add(null, _K.hidden, c);
  }
  for (var i = 0; i < states; i++) {
    if (owners[i] != -1) {
      cnodes[i].parent = cnodes[owners[i]].parent;
    }
  }

  {
    // Numbers the tree so that, at every level, initial states come first and the rest follow
    // in the order the transitions introduce them.
    final members = List<List<int>>.generate(cnodes.length, (_) => <int>[]);
    final top = <int>[];
    for (var i = 0; i < cnodes.length; i++) {
      final p = cnodes[i].parent;
      if (p >= 0) {
        members[p].add(i);
      } else {
        top.add(i);
      }
    }
    int initial(int i) => views[i].kind == _K.start ? 0 : 1;
    int byFlow(int a, int b) {
      final initCmp = initial(a) - initial(b);
      if (initCmp != 0) return initCmp;
      final appCmp = appear[a] == appear[b]
          ? 0
          : (appear[a] < appear[b] ? -1 : 1);
      if (appCmp != 0) return appCmp;
      return a - b;
    }

    var seq = 0.0;
    top.sort(byFlow);
    final pending = top.reversed.toList();
    while (pending.isNotEmpty) {
      final i = pending.removeLast();
      cnodes[i].seq = seq++;
      final inside = members[i]..sort(byFlow);
      for (var k = inside.length - 1; k >= 0; k--) {
        pending.add(inside[k]);
      }
    }
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
      tracks: curve == 'step' || curve == 'stepBefore' || curve == 'stepAfter',
      straight: curve == 'linear',
      headRoom: markerTrim('arrow_point'),
    ),
  );

  final width = (layout.width + 2 * pad).ceilToDouble();
  final height = (layout.height + 2 * pad).ceilToDouble();
  final links = <LinkInfo>[];

  // Route points by rounded y, to find the edges that cross a composite's title bar.
  final crossings = <int, List<double>>{};
  for (final e in cedges) {
    final route = e.route;
    for (var k = 3; k < route.length - 3; k += 3) {
      final key = roundJs(route[k + 1]);
      final list = crossings[key];
      if (list != null) {
        list.add(route[k]);
      } else {
        crossings[key] = <double>[route[k]];
      }
    }
  }

  final children = List<List<int>>.generate(cnodes.length, (_) => <int>[]);
  final order = <int>[];
  for (var i = 0; i < cnodes.length; i++) {
    final p = cnodes[i].parent;
    if (p >= 0) {
      children[p].add(i);
    } else {
      order.add(i);
    }
  }
  final roots = List<int>.of(order);
  for (var q = 0; q < order.length; q++) {
    for (final child in children[order[q]]) {
      order.add(child);
    }
  }

  final clustersBuf = StringBuffer();
  final fills = <Fill>[];
  final dividersBuf = StringBuffer();
  final nodesOutBuf = StringBuffer();
  final notesOutBuf = StringBuffer();
  // Draws the dashed lines between the regions among a composite's members.
  void divide(
    List<int> items,
    double left,
    double top,
    double right,
    double bottom,
  ) {
    final regions = items.where((i) => views[i].kind == _K.region).toList();
    if (regions.length < 2) return;
    double lo(int i, bool x) =>
        x ? cnodes[i].x - cnodes[i].w / 2 : cnodes[i].y - cnodes[i].h / 2;
    double hi(int i, bool x) =>
        x ? cnodes[i].x + cnodes[i].w / 2 : cnodes[i].y + cnodes[i].h / 2;
    for (final x in const <bool>[true, false]) {
      final sorted = List<int>.of(regions)
        ..sort((a, b) {
          final diff = lo(a, x) - lo(b, x);
          if (diff != 0) return diff < 0 ? -1 : 1;
          return a - b;
        });
      var apart = true;
      for (var k = 1; k < sorted.length; k++) {
        if (hi(sorted[k - 1], x) > lo(sorted[k], x) + 0.5) apart = false;
      }
      if (!apart) continue;
      for (var k = 1; k < sorted.length; k++) {
        final at = num((hi(sorted[k - 1], x) + lo(sorted[k], x)) / 2 + pad);
        dividersBuf.write(
          '<path class="pele-divider" d="M${x ? '$at,${num(top)}V${num(bottom)}' : '${num(left)},${at}H${num(right)}'}"/>',
        );
      }
      return;
    }
    // Regions that sit neither side by side nor in a stack each get an outline.
    for (final i in regions) {
      final c = cnodes[i];
      dividersBuf.write(
        _rect(
          c.x - c.w / 2 + pad,
          c.y - c.h / 2 + pad,
          c.w,
          c.h,
          ' class="pele-divider" rx="${num(_corner)}"',
        ),
      );
    }
  }

  divide(roots, pad / 2, pad / 2, width - pad / 2, height - pad / 2);

  for (final i in order) {
    final view = views[i];
    final node = view.node;
    final style = view.style;
    if (node == null || style == null || view.kind >= _K.region) continue;
    final c = cnodes[i];
    final x = c.x + pad;
    final y = c.y + pad;
    final w = view.w;
    final h = view.h;
    final ink = inkFill((shape: style.shape, text: style.text));
    final labelAttrs = ' class="pele-label"$ink${style.text}';
    String body;

    switch (view.kind) {
      case _K.composite:
        final left = x - c.w / 2;
        final top = y - c.h / 2;
        if (paints(style.shape)) {
          fills.add(
            Fill(
              box: <double>[left, top, left + c.w, top + c.h],
              shape: style.shape,
            ),
          );
        }
        final buf = StringBuffer(
          _rect(
            left,
            top,
            c.w,
            c.h,
            ' rx="${num(_corner)}" fill="var(--_a)"${setsFill(style.shape) ? '' : ' fill-opacity="0.5"'} stroke="var(--_b)"${style.shape}',
          ),
        );
        if (view.titleH > 0) {
          buf
            ..write(
              '<path d="M${num(left)},${num(top + view.titleH)}H${num(left + c.w)}"$_rule${style.line}/>',
            )
            ..write(
              labelSvg(
                view.label,
                _titleX(c, view.label.width, crossings) + pad,
                top + view.titleH / 2,
                ' class="pele-cluster-label"$ink${style.text}',
                icons,
              ),
            );
        }
        divide(children[i], left, top + view.titleH, left + c.w, top + c.h);
        body = buf.toString();
      case _K.start:
        body = '<circle r="7" fill="var(--_l)"${style.shape}/>';
      case _K.end:
        body =
            '<circle r="8.5" fill="var(--_bg)" stroke="var(--_l)"${style.line}/><circle r="5" fill="var(--_l)"${style.shape}/>';
      case _K.choice:
        body =
            '<polygon points="0,${num(-h / 2)} ${num(w / 2)},0 0,${num(h / 2)} ${num(-w / 2)},0"$_surface${style.shape}/>';
      case _K.fork:
      case _K.join:
        body = _rect(
          -w / 2,
          -h / 2,
          w,
          h,
          ' rx="2" fill="var(--_l)"${style.shape}',
        );
      case _K.note:
        final r = num(w / 2);
        final b = num(h / 2);
        final fold = num(w / 2 - _fold);
        final corner = num(_fold - h / 2);
        body =
            '<path d="M-$r,-${b}H${fold}L$r,${corner}V${b}H-${r}Z" fill="var(--_bg)" stroke="var(--_b)"/>'
            '<path d="M$fold,-${b}V${corner}H$r"$_rule/>'
            '${labelSvg(view.label, 0, 0, ' class="pele-label" font-size="${num(small)}" fill="var(--_m)"', icons)}';
      default:
        final buf = StringBuffer(
          _rect(
            -w / 2,
            -h / 2,
            w,
            h,
            ' rx="${num(math.min(_corner, h / 2))}"$_surface${style.shape}',
          ),
        );
        if (view.kind == _K.state) {
          buf.write(labelSvg(view.label, 0, 0, labelAttrs, icons));
        } else {
          var at = _padY - h / 2 + view.label.height;
          buf
            ..write(
              '<path d="M${num(-w / 2)},${num(at + 6)}H${num(w / 2)}"$_rule${style.line}/>',
            )
            ..write(
              labelSvg(
                view.label,
                0,
                at - view.label.height / 2,
                labelAttrs,
                icons,
              ),
            );
          at += 14;
          for (final line in view.lines) {
            buf.write(
              labelSvg(
                line,
                0,
                at + line.height / 2,
                ' class="pele-state-description" font-size="${num(small)}"$ink${style.text}',
                icons,
              ),
            );
            at += line.height;
          }
        }
        body = buf.toString();
    }

    final link = db.links[node.id];
    if (link != null) {
      // Entity codes are resolved first, so the URL is checked in the form a browser would follow.
      final tooltip = decodeEntities(_unquote(link.tooltip));
      if (tooltip.isNotEmpty) {
        body = '<title>${esc(tooltip)}</title>$body';
      }
      body = linked(
        body,
        safeUrl(_unquote(link.url)),
        node.id,
        links,
        options,
        ' target="_blank"',
      );
    }
    final open =
        '<g class="${_classes[view.kind]}${classNames(node.cssClasses.replaceAll(_mermaidClasses, ''))}" data-id="${escText(node.id)}"';
    if (view.kind == _K.composite) {
      clustersBuf.write('$open>$body</g>');
    } else if (view.kind == _K.note) {
      notesOutBuf.write(
        '$open transform="translate(${num(x)},${num(y)})">$body</g>',
      );
    } else {
      nodesOutBuf.write(
        '$open transform="translate(${num(x)},${num(y)})">$body</g>',
      );
    }
  }

  // Moves a route end from the layout box onto the drawn shape, and spreads the ends along a bar.
  void attach(List<double> route, int at, int i) {
    final c = cnodes[i];
    if (c.isGroup) return;
    final view = views[i];
    final bar = view.kind == _K.fork || view.kind == _K.join;
    final other = at == 0 ? 3 : at - 3;
    // 0 is the x axis and 1 the y axis; the end sits on a side that faces along `axis`.
    for (final axis in const <int>[1, 0]) {
      final isY = axis != 0;
      final extent = isY ? c.h : c.w;
      final drawnExtent = isY ? view.h : view.w;
      final breadth = isY ? view.w : view.h;
      final center = (isY ? c.y : c.x) + pad;
      final cross = (isY ? c.x : c.y) + pad;
      final delta = route[at + axis] - center;
      if ((delta.abs() - extent / 2).abs() >= 0.5) continue;
      route[at + axis] -= (signJs(delta) * (extent - drawnExtent)) / 2;
      if (bar && breadth > drawnExtent) {
        route[at + 1 - axis] = _clamp(
          route[other + 1 - axis],
          cross - breadth / 2 + 6,
          cross + breadth / 2 - 6,
        );
      }
      return;
    }
  }

  final reach = sideReach();
  for (var i = 0; i < cedges.length; i++) {
    final ce = cedges[i];
    if (ce.src == ce.dst ||
        ce.route.length < 6 ||
        drawn[i].pattern == 'dashed') {
      continue;
    }
    reach.add(
      ce.dst,
      endSide(ce.route, ce.route.length - 3, cnodes[ce.dst]),
      'arrow_point',
    );
  }

  final casingsBuf = StringBuffer();
  final edgesOutBuf = StringBuffer();
  final labelsOutBuf = StringBuffer();
  final loopSeen = Int32List(states);
  final loopText = Float64List(states);
  for (var i = 0; i < cedges.length; i++) {
    final ce = cedges[i];
    final edge = drawn[i];
    final label = edgeLabels[i];
    final note = edge.pattern == 'dashed';
    final endType = note ? 'none' : 'arrow_point';
    EdgePath path;
    if (ce.src == ce.dst) {
      final a = cnodes[ce.src];
      final view = views[ce.src];
      final k = loopSeen[ce.src]++;
      // The loop hangs off a side the flow does not use: the right, or below when the flow is horizontal.
      final side = across(ce.src);
      final w = a.isGroup ? a.w : view.w;
      final h = a.isGroup ? a.h : view.h;
      final out = (side ? w : h) / 2;
      final spread = math.max(
        math.min((side ? h : w) / 2 - 4, 8.0 + k * 6),
        2.0,
      );
      final loopReach = _loop + k * 8;
      final hLen = hypot(loopReach, spread);
      final trim = markerTrim(endType) / (hLen != 0 ? hLen : 1.0);
      // Offsets are given for a loop on the right and turned a quarter for one below.
      double px(double dx, double dy) => a.x + pad + (side ? out + dx : -dy);
      double py(double dx, double dy) => a.y + pad + (side ? dy : out + dx);
      String at(double dx, double dy) =>
          '${num(px(dx, dy))},${num(py(dx, dy))}';
      final rawEdx = px(-loopReach, -spread) - px(0, 0);
      final rawEdy = py(-loopReach, -spread) - py(0, 0);
      final rawLen = hypot(rawEdx, rawEdy);
      final len = rawLen != 0 ? rawLen : 1.0;
      path = EdgePath(
        d: 'M${at(0, -spread)}C${at(loopReach, -2 * spread)} ${at(loopReach, 2 * spread)} ${at(loopReach * trim, spread + spread * trim)}',
        sx: 0,
        sy: 0,
        sdx: 0,
        sdy: 0,
        ex: px(0, spread),
        ey: py(0, spread),
        edx: rawEdx / len,
        edy: rawEdy / len,
      );
      // Labels stack beyond the outermost loop, in the order of their transitions.
      final furthest = _loop + (loopCount[ce.src] - 1) * 8;
      final below = loopText[ce.src] + label.height / 2;
      loopText[ce.src] += label.height;
      ce.labelX = side ? a.x + out + furthest + 4 + ce.labelW / 2 : a.x;
      ce.labelY = side
          ? a.y - loopHeight[ce.src] / 2 + below
          : a.y + out + furthest * 0.75 + 4 + below;
    } else {
      var route = List<double>.of(ce.route);
      final leaves = reach.of(ce.src, endSide(route, 0, cnodes[ce.src]));
      final arrives = reach.of(
        ce.dst,
        endSide(route, route.length - 3, cnodes[ce.dst]),
      );
      for (var k = 0; k < route.length; k += 3) {
        route[k] += pad;
        route[k + 1] += pad;
      }
      attach(route, 0, ce.src);
      attach(route, route.length - 3, ce.dst);
      final composite = anchors[i];
      if (composite != null && route.length >= 6) {
        final g = cnodes[composite];
        final inward = views[ce.src].kind == _K.hidden;
        final at = inward ? 0 : route.length - 3;
        final near = (g.dir == 'TB' || g.dir == 'LR') == inward;
        final point = _vertical(g.dir)
            ? <double>[
                route[at],
                g.y +
                    pad +
                    (near ? views[composite].titleH - g.h / 2 : g.h / 2),
                0,
              ]
            : <double>[
                g.x + pad + (near ? -g.w / 2 : g.w / 2),
                route[at + 1],
                1,
              ];
        route = inward
            ? <double>[...point, ...route]
            : <double>[...route, ...point];
      }
      path = routePath(
        route,
        curve is String ? curve : null,
        0,
        markerTrim(endType),
        leaves,
        arrives,
      );
    }
    final over = overFills(
      path.d,
      <double>[path.ex, path.ey],
      fills,
      '',
      path.tokens,
    );
    if (over == '') casingsBuf.write(edgeCasing(path, 'none', endType));
    final hasOver = over != null && over.isNotEmpty;
    final kind = note
        ? 'pele-note-edge" stroke="${hasOver ? over : 'var(--_b)'}" stroke-dasharray="3 4'
        : (hasOver ? 'pele-transition" stroke="$over' : 'pele-transition');
    edgesOutBuf
      ..write('<g class="pele-edge $kind" data-id="${escText(edge.id)}">')
      ..write('<path d="${path.d}"/>')
      ..write(
        marker(
          endType,
          path.ex,
          path.ey,
          path.edx,
          path.edy,
          hasOver ? over : 'var(--_l)',
        ),
      )
      ..write('</g>');
    if (label.width > 0) {
      final x = ce.labelX + pad;
      final y = ce.labelY + pad;
      labelsOutBuf.write(edgeLabelSvg(edge.id, label, x, y, '', icons));
    }
  }

  final clusters = clustersBuf.toString();
  final dividers = dividersBuf.toString();
  final casings = casingsBuf.toString();
  final edgesOut = edgesOutBuf.toString();
  final labelsOut = labelsOutBuf.toString();
  final nodesOut = nodesOutBuf.toString();
  final notesOut = notesOutBuf.toString();

  final titled = withTitle(
    db.title,
    measurer,
    size,
    pad,
    width,
    height,
    '${clusters.isNotEmpty ? '<g class="pele-clusters">$clusters</g>' : ''}'
    '${dividers.isNotEmpty ? '<g class="pele-dividers" stroke-dasharray="4 4"$_rule>$dividers</g>' : ''}'
    '${casingsSvg(casings)}'
    '${edgesOut.isNotEmpty ? '<g class="pele-edges" fill="none" stroke="var(--_l)" stroke-linecap="round">$edgesOut</g>' : ''}'
    '${labelsOut.isNotEmpty ? '<g class="pele-edge-labels" font-size="${num(small)}">$labelsOut</g>' : ''}'
    '<g class="pele-nodes">$nodesOut$notesOut</g>',
  );
  final svg = svgDocument(
    'state',
    titled.width,
    titled.height,
    size,
    options,
    db,
    titled.content,
  );

  return Rendered(
    svg: svg,
    width: titled.width,
    height: titled.height,
    links: links,
  );
}

// Picks where a composite's title sits in its title bar so that edges entering from above do not cross it.
double _titleX(CNode c, double width, Map<int, List<double>> crossings) {
  final xs = crossings[roundJs(c.y - c.h / 2)];
  if (xs == null || width == 0) return c.x;
  final left = c.x - c.w / 2;
  final half = width / 2;
  var best = c.x;
  var bestGap = -1.0;
  for (final x in <double>[
    c.x,
    left + _groupPad + half,
    left + c.w - _groupPad - half,
  ]) {
    var gap = double.infinity;
    for (final cx in xs) {
      if (cx > left && cx < left + c.w) {
        gap = math.min(gap, (cx - x).abs() - half);
      }
    }
    if (gap >= 6) return x;
    if (gap > bestGap + 0.5) {
      bestGap = gap;
      best = x;
    }
  }
  return best;
}

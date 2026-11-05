// Upstream: src/diagrams/class/render.ts

import 'dart:math' as math;
import 'dart:typed_data';

import '../../layout/components.dart';
import '../../layout/compound.dart' hide Style;
import '../../layout/layered.dart';
import '../../preprocess.dart';
import '../../svg/builder.dart';
import '../../svg/cluster.dart';
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
import '../common/generics.dart';
import 'db.dart';
import 'graph.dart';
import 'markers.dart';
import 'members.dart';
import 'types.dart';

const double _NODE_SEP = 40;
const double _EDGE_SEP = 16;
const double _RANK_SEP = 56;
const double _GROUP_PAD = 20;
const double _LOOP = 26;
const double _PAD_X = 12;
const double _TITLE_PAD = 8;
const double _SECTION_PAD = 6;
const double _EMPTY_SECTION = 10;
const double _MIN_WIDTH = 64;
const double _FOLD = 8;
const String _LINE = 'var(--_l)';
const Set<String> _TARGETS = <String>{'_self', '_blank', '_parent', '_top'};

final RegExp _reFontFamily = RegExp(r'[";]font-family:');
final RegExp _reDefaultPrefix = RegExp(r'^default\s?');

double _numberOption(Config config, String key, double fallback) {
  final value = config[key];
  final d = value is double ? value : (value is int ? value.toDouble() : null);
  return d != null && d > 0 ? math.min(d, 2000.0) : fallback;
}

class _Line {
  final String text;
  final double width;
  final String classifier;

  const _Line({
    required this.text,
    required this.width,
    required this.classifier,
  });
}

class _View {
  final GraphNode node;
  final ResolvedStyle style;
  final Label label;
  double w;
  double h;
  int loops;
  // Each element is either a String or a Label.
  final List<Object> annotations;
  final List<_Line> attributes;
  final List<_Line> methods;
  final double titleH;
  final double attributesH;
  final double fontSize;

  _View({
    required this.node,
    required this.style,
    required this.label,
    required this.w,
    required this.h,
    required this.loops,
    required this.annotations,
    required this.attributes,
    required this.methods,
    required this.titleH,
    required this.attributesH,
    required this.fontSize,
  });
}

class _End {
  final List<double> route;
  final int at;
  final double toward;
  final int order;
  final double room;
  final int side;
  // Whether the text of this end goes on the right of, or below, its line.
  final bool after;

  const _End({
    required this.route,
    required this.at,
    required this.toward,
    required this.order,
    required this.room,
    required this.side,
    required this.after,
  });
}

class _Card {
  final String text;
  final Label? math;
  double x;
  double y;
  final double w;
  final double h;
  final int parent;

  _Card({
    required this.text,
    this.math,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.parent,
  });
}

const List<_Line> _NO_LINES = <_Line>[];
const List<String> _NO_TEXT = <String>[];

_Line _memberLine(
  ClassMember member,
  TextMeasurer measurer,
  double size,
  bool mono,
) {
  final text = decodeEntities(member.getDisplayDetails().displayText).trim();
  final style =
      (member.classifier == '*' ? Style.Italic : 0) | (mono ? Style.Mono : 0);
  return _Line(
    text: text,
    width: measurer.width(text, size, style),
    classifier: member.classifier,
  );
}

Rendered renderClass(ClassDb db, Config config, RenderOptions options) {
  Rendered fitted(bool down) =>
      tighten(options, (tight) => _draw(db, config, options, down, tight));
  return runsAcross(db.direction) ? turnToFit(options, fitted) : fitted(false);
}

// `turned` draws a diagram that runs across as one that runs down. `tight` gives up the room
// that keeps a namespace's name clear of an edge coming in beside it.
Rendered _draw(
  ClassDb db,
  Config config,
  RenderOptions options,
  bool turned,
  bool tight,
) {
  final conf = asConfig(config['class']);
  final graph = buildClassGraph(db, conf['hierarchicalNamespaces'] != false);
  final hideEmpty = conf['hideEmptyMembersBox'] == true;
  final monospaced =
      options.monospace != null && options.monospace!.contains('members');
  // Explicit class fonts override monospace.
  bool mono(ResolvedStyle style) =>
      monospaced && !_reFontFamily.hasMatch(style.text);
  final size = options.fontSize ?? 16;
  final smallInt = roundJs(size * 0.875);
  final small = smallInt.toDouble();
  final tinyInt = roundJs(size * 0.8);
  final tiny = tinyInt.toDouble();
  final tinyHeight = roundJs(tiny * 1.4).toDouble();
  final measurer =
      options.measurer ??
      defaultMeasurer(options.fontFamily, options.fontFamilyMono);
  final pad = options.padding ?? 8;
  // Keep annotations and cardinalities literal unless math is typeset.
  Label? mathText(String raw, double fontSize) {
    if (!raw.contains(r'$$')) return null;
    final label = layoutLabel(raw, false, measurer, fontSize, 4000);
    return label.lines.any(hasMath) ? label : null;
  }

  double cardWidth(String raw) => raw.isNotEmpty
      ? (mathText(raw, tiny)?.width ??
            measurer.width(decodeEntities(raw), tiny, 0))
      : 0;
  final rootDir = turned ? 'TB' : direction(db.direction);

  // A class may carry the declarations of many classDefs many times over. Each distinct declaration
  // is checked once, and only the last value of each property that has an effect is resolved.
  final effect = <String, String>{};
  final fromDefs = <String, List<(String, String)>>{};
  final kept = <String, String>{};
  void keep(String decl) {
    var prop = effect[decl];
    if (prop == null) {
      final one = resolveStyle(<String>[decl]);
      prop = one.shape.isEmpty && one.text.isEmpty
          ? ''
          : sliceJs(decl, 0, decl.indexOf(':')).trim().toLowerCase();
      effect[decl] = prop;
    }
    if (prop.isNotEmpty) kept[prop] = decl;
  }

  ResolvedStyle classStyle(ClassNode cls) {
    kept.clear();
    var base = fromDefs[cls.cssClasses];
    if (base == null) {
      for (final name in cls.cssClasses.split(' ')) {
        final def = db.styleClasses[name];
        if (def != null) {
          for (final s in def.styles) {
            for (final part in s.split(',')) {
              keep(part);
            }
          }
        }
      }
      base = kept.entries.map((e) => (e.key, e.value)).toList();
      fromDefs[cls.cssClasses] = base;
    } else {
      for (final (prop, decl) in base) {
        kept[prop] = decl;
      }
    }
    for (final s in cls.styles) {
      keep(s);
    }
    return resolveStyle(kept.isEmpty ? _NO_TEXT : kept.values.toList());
  }

  final children = Int32List(graph.nodes.length);
  for (final node in graph.nodes) {
    if (node.parent >= 0) children[node.parent]++;
  }

  // Namespaces that an edge may cross into are made wide enough for the title to sit beside it.
  final crossed = Uint8List(graph.nodes.length);
  for (final edge in graph.edges) {
    if (edge.source < 0 || edge.target < 0) continue;
    final a = graph.nodes[edge.source].parent;
    final b = graph.nodes[edge.target].parent;
    if (a == b) continue;
    for (var g = a; g >= 0 && crossed[g] == 0; g = graph.nodes[g].parent) {
      crossed[g] = 1;
    }
    for (var g = b; g >= 0 && crossed[g] == 0; g = graph.nodes[g].parent) {
      crossed[g] = 1;
    }
  }

  _View base(GraphNode node, Label label, double w, double h, double fontSize) {
    return _View(
      node: node,
      style: resolveStyle(_NO_TEXT),
      label: label,
      w: w,
      h: h,
      loops: 0,
      annotations: _NO_TEXT,
      attributes: _NO_LINES,
      methods: _NO_LINES,
      titleH: 0,
      attributesH: 0,
      fontSize: fontSize,
    );
  }

  _View classView(GraphNode node, ClassNode cls) {
    final style = classStyle(cls);
    final fontSize = style.fontSize ?? size;
    final memberSize = roundJs(fontSize * 0.875).toDouble();
    final lineHeight = roundJs(memberSize * 1.5).toDouble();
    // The generic type is escaped so that `<T>` is not read as a tag.
    final generic = cls.type.isNotEmpty
        ? '&lt;${parseGenericTypes(cls.type).replaceAll('<', '&lt;').replaceAll('>', '&gt;')}&gt;'
        : '';
    final label = layoutLabel(
      '${cls.label}$generic',
      false,
      measurer,
      fontSize,
      4000,
      Style.Bold | (style.italic ? Style.Italic : 0),
    );
    final annotations = cls.annotations.isNotEmpty
        ? cls.annotations
              .map<Object>(
                (a) =>
                    mathText('«${a.trim()}»', tiny) ??
                    '«${decodeEntities(a).trim()}»',
              )
              .toList()
        : _NO_TEXT;
    final attributes = cls.members.isNotEmpty
        ? cls.members
              .map((m) => _memberLine(m, measurer, memberSize, mono(style)))
              .toList()
        : _NO_LINES;
    final methods = cls.methods.isNotEmpty
        ? cls.methods
              .map((m) => _memberLine(m, measurer, memberSize, mono(style)))
              .toList()
        : _NO_LINES;
    var inner = label.width;
    var annotationsH = 0.0;
    for (final a in annotations) {
      if (a is String) {
        inner = math.max(inner, measurer.width(a, tiny, 0));
        annotationsH += tinyHeight;
      } else if (a is Label) {
        inner = math.max(inner, a.width);
        annotationsH += math.max(tinyHeight, a.height);
      }
    }
    for (final line in attributes) {
      inner = math.max(inner, line.width);
    }
    for (final line in methods) {
      inner = math.max(inner, line.width);
    }
    final sections = !(hideEmpty && attributes.isEmpty && methods.isEmpty);
    double section(int count) => !sections
        ? 0
        : count > 0
        ? 2 * _SECTION_PAD + count * lineHeight
        : _EMPTY_SECTION;
    final titleH =
        2 * _TITLE_PAD +
        annotationsH +
        math.max(label.height, roundJs(fontSize * 1.5).toDouble());
    final attributesH = section(attributes.length);
    return _View(
      node: node,
      style: style,
      label: label,
      w: math.max(inner + 2 * _PAD_X, _MIN_WIDTH),
      h: titleH + attributesH + section(methods.length),
      loops: 0,
      annotations: annotations,
      attributes: attributes,
      methods: methods,
      titleH: titleH,
      attributesH: attributesH,
      fontSize: fontSize,
    );
  }

  final views = <_View>[];
  final cnodes = <CNode>[];
  for (var i = 0; i < graph.nodes.length; i++) {
    final node = graph.nodes[i];
    _View view;
    CNode c;
    if (node.isGroup) {
      final label = layoutLabel(node.label, false, measurer, size, 4000);
      view = base(node, label, 0, 0, size);
      if (children[i] > 0) {
        c = cnode(0, 0)
          ..isGroup = true
          ..padX = _GROUP_PAD
          ..padTop = label.height > 0 ? label.height + 16 : _GROUP_PAD
          ..padBottom = _GROUP_PAD
          ..minW =
              label.width +
              2 * _GROUP_PAD -
              12 +
              (crossed[i] == 1 && !tight
                  ? math.min(label.width + 24, 240.0)
                  : 0);
      } else {
        view.w = math.max(label.width + 2 * _GROUP_PAD, 80);
        view.h = label.height + 2 * _GROUP_PAD;
        c = cnode(view.w, view.h);
      }
    } else if (node.classNode != null) {
      view = classView(node, node.classNode!);
      c = cnode(view.w, view.h);
    } else if (node.shape == 'note') {
      final label = layoutLabel(node.label, true, measurer, small, 260);
      view = base(
        node,
        label,
        math.max(label.width + 2 * _PAD_X, 40),
        label.height + 2 * _TITLE_PAD,
        small,
      );
      c = cnode(view.w, view.h);
    } else {
      final label = layoutLabel(node.label, false, measurer, small, 200);
      view = base(
        node,
        label,
        math.max(label.width, 12) + 4,
        math.max(label.height, 12),
        small,
      );
      c = cnode(view.w, view.h);
    }
    c
      ..parent = node.parent
      ..seq = i.toDouble();
    views.add(view);
    cnodes.add(c);
  }

  final cedges = <CEdge>[];
  final drawn = <GraphEdge>[];
  final edgeLabels = <Label>[];
  final startRoom = <double>[];
  final endRoom = <double>[];
  // Edges leave one side of a class and arrive at the other, so a class with many of them
  // is widened until they, and the text at their ends, fit side by side.
  final crowd = Float64List(views.length * 4);
  void meet(int item, int slot, double room) {
    crowd[item * 4 + slot]++;
    if (room > crowd[item * 4 + slot + 1]) crowd[item * 4 + slot + 1] = room;
  }

  for (final edge in graph.edges) {
    if (edge.source < 0 || edge.target < 0) continue;
    final label = layoutLabel(edge.label, true, measurer, small, 200);
    final startW = cardWidth(edge.startLabelRight);
    final endW = cardWidth(edge.endLabelLeft);
    if (edge.source == edge.target) {
      views[edge.source].loops++;
      cnodes[edge.source].w +=
          2 * (_LOOP + (label.width > 0 ? label.width + 12 : 0));
    } else {
      meet(edge.source, 0, startW);
      meet(edge.target, 2, endW);
    }
    startRoom.add(startW);
    endRoom.add(endW);
    drawn.add(edge);
    edgeLabels.add(label);
    cedges.add(
      CEdge(
        src: edge.source,
        dst: edge.target,
        minlen: 1,
        labelW: label.width > 0 ? label.width + 12 : 0,
        labelH: label.height > 0 ? label.height + 4 : 0,
      ),
    );
  }

  if (rootDir == 'TB' || rootDir == 'BT') {
    for (var i = 0; i < views.length; i++) {
      if (views[i].node.classNode == null) continue;
      var need = 0.0;
      for (var slot = 0; slot < 4; slot += 2) {
        final count = crowd[i * 4 + slot];
        final room = crowd[i * 4 + slot + 1];
        if (count > 1) {
          need = math.max(need, (count - 1) * (room > 0 ? room + 24 : 14) + 24);
        }
      }
      need = math.min(need, 480);
      if (need > views[i].w) {
        cnodes[i].w += need - views[i].w;
        views[i].w = need;
      }
    }
  }

  var lettered = false;
  for (var i = 0; i < drawn.length && !lettered; i++) {
    lettered = startRoom[i] > 0 || endRoom[i] > 0;
  }
  // Cardinalities at both ends of a vertical edge need room for their height between the ranks.
  var tallCards = 0.0;
  if (rootDir == 'TB' || rootDir == 'BT') {
    double cardHeight(String raw) => raw.isNotEmpty
        ? math.max(tinyHeight, mathText(raw, tiny)?.height ?? 0.0)
        : 0.0;
    for (final edge in drawn) {
      tallCards = math.max(
        tallCards,
        cardHeight(edge.startLabelRight) +
            cardHeight(edge.endLabelLeft) -
            2 * tinyHeight,
      );
    }
  }
  final layout = compoundLayout(
    cnodes,
    cedges,
    rootDir,
    LayeredOptions(
      nodeSep: _numberOption(conf, 'nodeSpacing', _NODE_SEP),
      edgeSep: _EDGE_SEP,
      rankSep:
          _numberOption(
            conf,
            'rankSpacing',
            lettered ? _RANK_SEP + 16 : _RANK_SEP,
          ) +
          tallCards,
      portSep: 20,
      apart: true,
    ),
  );

  // Every edge reaches the middle of a side. Where several share a side they are spread along it,
  // in the order of where they come from. An end with text runs straight for the length of the text,
  // which sits beside it on the side the line then bends toward, away from the neighbors that bend
  // the other way. Neighbors are set apart far enough for the text between them.
  final sides = <int, List<_End>>{};
  final cards = <_Card>[];
  _End? attach(CEdge ce, int at, int item, double room, int order) {
    final route = ce.route;
    final c = cnodes[item];
    final side = endSide(route, at, c);
    if (side < 0) return null;
    final slack = (c.w - views[item].w) / 2;
    if (side == 1) {
      route[at] -= slack;
    } else if (side == 3) {
      route[at] += slack;
    }
    final across = side & 1;
    final toward = route[(at == 0 ? 3 : at - 3) + across];
    final bend = toward - route[at + across];
    final end = _End(
      route: route,
      at: at,
      toward: toward,
      order: order,
      room: room,
      side: side,
      after: across != 0 ? bend > 0 : bend >= 0,
    );
    final key = item * 4 + side;
    final list = sides[key];
    if (list != null) {
      list.add(end);
    } else {
      sides[key] = <_End>[end];
    }
    return end;
  }

  final starts = <_End?>[];
  final ends = <_End?>[];
  for (var i = 0; i < cedges.length; i++) {
    final ce = cedges[i];
    final routed = ce.src != ce.dst && ce.route.length >= 6;
    starts.add(routed ? attach(ce, 0, ce.src, startRoom[i], i) : null);
    ends.add(
      routed ? attach(ce, ce.route.length - 3, ce.dst, endRoom[i], i) : null,
    );
  }
  // Whether a point lies on the border of one of the namespaces around a class.
  bool onBorder(int item, double x, double y) {
    for (
      var g = cnodes[item].parent, hops = 0;
      g >= 0 && hops < 10000;
      g = cnodes[g].parent, hops++
    ) {
      final c = cnodes[g];
      final dx = (x - c.x).abs();
      final dy = (y - c.y).abs();
      if (((dy - c.h / 2).abs() < 0.5 && dx <= c.w / 2 + 0.5) ||
          ((dx - c.w / 2).abs() < 0.5 && dy <= c.h / 2 + 0.5)) {
        return true;
      }
    }
    return false;
  }

  for (final entry in sides.entries) {
    final key = entry.key;
    final list = entry.value;
    if (list.length < 2) continue;
    final item = key >> 2;
    final across = key & 1;
    final length = across != 0 ? views[item].h : views[item].w;
    list.sort((a, b) {
      final cmp = a.toward.compareTo(b.toward);
      return cmp != 0 ? cmp : a.order.compareTo(b.order);
    });
    final gaps = List<double>.filled(list.length, 0);
    var total = 0.0;
    for (var j = 0; j + 1 < list.length; j++) {
      final a = list[j];
      final b = list[j + 1];
      var gap = across != 0 ? 20.0 : 24.0;
      if (a.room > 0 && a.after) {
        gap += across != 0 ? tinyHeight + 6 : a.room;
      }
      if (b.room > 0 && !b.after) {
        gap += across != 0 ? tinyHeight + 6 : b.room;
      }
      gaps[j] = gap;
      total += gap;
    }
    final scale = math.min(1.0, (length - 24) / total);
    if (scale <= 0) continue;
    var at =
        (across != 0 ? cnodes[item].y : cnodes[item].x) - (total * scale) / 2;
    for (var j = 0; j < list.length; j++) {
      final route = list[j].route;
      final end = list[j].at;
      // An edge that crosses the border of the class's namespace close by runs straight to it:
      // the point where it crosses moves into line with its end.
      final step = end == 0 ? 3 : -3;
      final first = end + step;
      var border = -1;
      for (
        var k = first;
        k >= 0 &&
            k < route.length &&
            (route[k + across] - route[first + across]).abs() < 0.5;
        k += step
      ) {
        if (onBorder(item, route[k], route[k + 1])) {
          border = k;
          break;
        }
      }
      if (border >= 0 && (route[first + across] - at).abs() <= 24) {
        for (var k = first; k != border + step; k += step) {
          route[k + across] = at;
        }
      }
      route[end + across] = at;
      if (j + 1 < list.length) {
        at += gaps[j] * scale;
      }
    }
  }

  void straighten(List<double> route, _End? end, double room, bool first) {
    if (end == null || room <= 0) return;
    final across = end.side & 1;
    final at = first ? 0 : route.length - 3;
    final along = at + 1 - across;
    final reach = (route[(first ? 3 : at - 3) + 1 - across] - route[along])
        .abs();
    final length = math.min(
      across != 0 ? room + 10 : tinyHeight + 6,
      reach * 0.35,
    );
    if (length < 4) return;
    final point = <double>[route[at], route[at + 1], route[at + 2]];
    point[1 - across] += (end.side == 0 || end.side == 3 ? -1 : 1) * length;
    route.insertAll(first ? 3 : at, point);
  }

  for (var i = 0; i < cedges.length; i++) {
    straighten(cedges[i].route, starts[i], startRoom[i], true);
    straighten(cedges[i].route, ends[i], endRoom[i], false);
  }

  var minX = 0.0;
  var minY = 0.0;
  var maxX = layout.width;
  var maxY = layout.height;
  void card(
    int parent,
    String raw,
    double width,
    double x,
    double y,
    int side,
    bool after,
  ) {
    if (raw.isEmpty) return;
    final m = mathText(raw, tiny);
    final h = m != null ? math.max(tinyHeight, m.height) : tinyHeight;
    var cx = x;
    var cy = y;
    if ((side & 1) != 0) {
      cx += (side == 3 ? -1 : 1) * (5 + width / 2);
      cy += (after ? 1 : -1) * (7 + h / 2);
    } else {
      cx += (after ? 1 : -1) * (9 + width / 2);
      cy += (side == 0 ? -1 : 1) * (3 + h / 2);
    }
    cards.add(
      _Card(
        text: decodeEntities(raw),
        math: m,
        x: cx,
        y: cy,
        w: width,
        h: h,
        parent: parent,
      ),
    );
    minX = math.min(minX, cx - width / 2);
    maxX = math.max(maxX, cx + width / 2);
    minY = math.min(minY, cy - h / 2);
    maxY = math.max(maxY, cy + h / 2);
  }

  final loopSeen = <int, int>{};
  final loopAt = Int32List(cedges.length);
  for (var i = 0; i < cedges.length; i++) {
    final ce = cedges[i];
    final edge = drawn[i];
    final route = ce.route;
    if (ce.src == ce.dst) {
      final k = loopSeen[ce.src] ?? 0;
      loopSeen[ce.src] = k + 1;
      loopAt[i] = k;
      final c = cnodes[ce.src];
      final view = views[ce.src];
      final x = c.x + view.w / 2;
      final spread = math.min(view.h / 2 - 4, 8.0 + k * 6);
      card(
        ce.src,
        edge.startLabelRight,
        startRoom[i],
        x,
        c.y - spread,
        1,
        false,
      );
      card(ce.dst, edge.endLabelLeft, endRoom[i], x, c.y + spread, 1, true);
      ce.labelX = c.x + view.w / 2 + _LOOP + k * 8 + 4 + ce.labelW / 2;
      ce.labelY = c.y;
    } else if (route.length >= 6) {
      final last = route.length - 3;
      final from = starts[i];
      final to = ends[i];
      card(
        ce.src,
        edge.startLabelRight,
        startRoom[i],
        route[0],
        route[1],
        from != null ? from.side : 2,
        from != null ? from.after : true,
      );
      card(
        ce.dst,
        edge.endLabelLeft,
        endRoom[i],
        route[last],
        route[last + 1],
        to != null ? to.side : 0,
        to != null ? to.after : true,
      );
    }
  }

  final available = options.maxWidth;
  if (available != null && available > 0 && maxX - minX + 2 * pad > available) {
    final cardNodes = cards
        .map(
          (item) => cnode(item.w, item.h, item.parent)
            ..x = item.x
            ..y = item.y,
        )
        .toList();
    final wrapped = wrapComponents(
      <CNode>[...cnodes, ...cardNodes],
      cedges,
      math.max(1.0, available - 2 * pad),
      _numberOption(conf, 'nodeSpacing', _NODE_SEP),
    );
    if (wrapped != null) {
      for (var i = 0; i < cards.length; i++) {
        cards[i].x = cardNodes[i].x;
        cards[i].y = cardNodes[i].y;
      }
      minX = minY = 0;
      maxX = wrapped.width;
      maxY = wrapped.height;
    }
  }

  final ox = pad - minX;
  final oy = pad - minY;
  final width = (maxX - minX + 2 * pad).ceilToDouble();
  final height = (maxY - minY + 2 * pad).ceilToDouble();
  final links = <LinkInfo>[];

  final crossings = <int, List<double>>{};
  if (graph.nodes.isNotEmpty && graph.nodes[0].isGroup) {
    for (final e in cedges) {
      markCrossings(crossings, e.route);
    }
  }

  String classSvg(_View view, ClassNode cls, String id, String at) {
    final w = view.w;
    final h = view.h;
    final style = view.style;
    final left = -w / 2;
    final top = -h / 2;
    final memberSizeInt = roundJs(view.fontSize * 0.875);
    final memberSize = memberSizeInt.toDouble();
    final lineHeight = roundJs(memberSize * 1.5).toDouble();
    var body =
        '<rect x="${num(left)}" y="${num(top)}" width="${num(w)}" height="${num(h)}" fill="var(--_s)" stroke="var(--_b)"${rounded(style.shape)}/>';
    final ink = inkFill((shape: style.shape, text: style.text));
    final first = top + view.titleH;
    final second = first + view.attributesH;
    if (h > view.titleH) {
      final stroke = style.stroke != null
          ? ' style="stroke:${esc(style.stroke!)}"'
          : '';
      body +=
          '<path class="pele-divider" d="M${num(left)},${num(first)}H${num(-left)}M${num(left)},${num(second)}H${num(-left)}" fill="none" stroke="var(--_b)"$stroke/>';
    }
    var y = top + _TITLE_PAD;
    for (final annotation in view.annotations) {
      if (annotation is String) {
        body +=
            '<text class="pele-annotation" x="0" y="${num(y + tinyHeight / 2 + tiny * 0.35)}" text-anchor="middle" font-size="$tinyInt"${ink.isNotEmpty ? ink : ' fill="var(--_m)"'}>${esc(annotation)}</text>';
        y += tinyHeight;
      } else if (annotation is Label) {
        final ah = math.max(tinyHeight, annotation.height);
        body += labelSvg(
          annotation,
          0,
          y + ah / 2,
          ' class="pele-annotation" font-size="$tinyInt"${ink.isNotEmpty ? ink : ' fill="var(--_m)"'}',
          options.icons,
        );
        y += ah;
      }
    }
    final titleSize = view.fontSize == size
        ? ''
        : ' font-size="${num(view.fontSize)}"';
    body += labelSvg(
      view.label,
      0,
      (y + first - _TITLE_PAD) / 2,
      ' class="pele-label"$titleSize font-weight="var(--_hw)"$ink${style.text}',
      options.icons,
    );
    String lines(List<_Line> list, String kind, double from) {
      final out = StringBuffer();
      var baseline = from + _SECTION_PAD + lineHeight / 2 + memberSize * 0.35;
      for (final line in list) {
        final mark = line.classifier == r'$'
            ? ' pele-static"${style.text.isNotEmpty ? '${style.text.substring(0, style.text.length - 1)}text-decoration:underline"' : ' style="text-decoration:underline"'}'
            : line.classifier == '*'
            ? ' pele-abstract" font-style="italic"${style.text}'
            : '"${style.text}';
        out.write(
          '<text class="pele-member pele-$kind$mark x="${num(left + _PAD_X)}" y="${num(baseline)}">${esc(line.text)}</text>',
        );
        baseline += lineHeight;
      }
      return out.toString();
    }

    if (view.attributes.isNotEmpty || view.methods.isNotEmpty) {
      body +=
          '<g class="pele-members" font-size="$memberSizeInt"$ink${mono(style) ? ' font-family="$fontMono"' : ''}>${lines(view.attributes, 'attribute', first)}${lines(view.methods, 'method', second)}</g>';
    }
    if (cls.tooltip != null && cls.tooltip!.isNotEmpty) {
      body = '<title>${escText(cls.tooltip!)}</title>$body';
    }
    if (cls.link != null && cls.link!.isNotEmpty) {
      body = linked(
        body,
        cls.link!,
        cls.id,
        links,
        options,
        cls.linkTarget != null && _TARGETS.contains(cls.linkTarget)
            ? ' target="${cls.linkTarget}"'
            : '',
      );
    }
    return '<g class="pele-node pele-class${classNames(cls.cssClasses.replaceFirst(_reDefaultPrefix, ''))}" data-id="$id"$at>$body</g>';
  }

  final clustersBuf = StringBuffer();
  final struckTitlesBuf = StringBuffer();
  final nodesOutBuf = StringBuffer();
  for (var i = 0; i < views.length; i++) {
    final view = views[i];
    final c = cnodes[i];
    final node = view.node;
    final x = c.x + ox;
    final y = c.y + oy;
    final id = escText(node.id);
    final w = c.isGroup ? c.w : view.w;
    final h = c.isGroup ? c.h : view.h;
    if (node.isGroup) {
      final titleX = c.isGroup
          ? clusterTitleX(c, view.label.width, crossings, _GROUP_PAD)
          : c.x;
      final titleY = y - h / 2 + 8 + view.label.height / 2;
      const titleAttrs = ' class="pele-cluster-label" fill="var(--_m)"';
      final struck =
          c.isGroup && titleCrossed(c, view.label.width, titleX, crossings);
      if (struck) {
        struckTitlesBuf.write(
          struckTitle(
            view.label,
            titleX + ox,
            titleY,
            titleAttrs,
            id,
            graph.nodes,
            i,
          ),
        );
      }
      clustersBuf
        ..write('<g class="pele-cluster pele-namespace" data-id="$id">')
        ..write(
          '<rect x="${num(x - w / 2)}" y="${num(y - h / 2)}" width="${num(w)}" height="${num(h)}" fill="var(--_a)" fill-opacity="0.5" stroke="var(--_b)"$roundedAttr/>',
        )
        ..write(
          struck ? '' : labelSvg(view.label, titleX + ox, titleY, titleAttrs),
        )
        ..write('</g>');
      continue;
    }
    final at = ' transform="translate(${num(x)},${num(y)})"';
    if (node.classNode != null) {
      nodesOutBuf.write(classSvg(view, node.classNode!, id, at));
    } else if (node.shape == 'note') {
      final r = w / 2;
      final t = -h / 2;
      nodesOutBuf
        ..write('<g class="pele-node pele-note" data-id="$id"$at>')
        ..write(
          '<path d="M${num(-r)},${num(t)}H${num(r - _FOLD)}L${num(r)},${num(t + _FOLD)}V${num(-t)}H${num(-r)}Z" fill="var(--_a)" stroke="var(--_b)" stroke-linejoin="round"/>',
        )
        ..write(
          '<path d="M${num(r - _FOLD)},${num(t)}V${num(t + _FOLD)}H${num(r)}" fill="none" stroke="var(--_b)" stroke-linejoin="round"/>',
        )
        ..write(
          labelSvg(
            view.label,
            0,
            0,
            ' class="pele-label" font-size="$smallInt"',
            options.icons,
          ),
        )
        ..write('</g>');
    } else {
      nodesOutBuf
        ..write('<g class="pele-node pele-interface" data-id="$id"$at>')
        ..write(
          labelSvg(
            view.label,
            0,
            0,
            ' class="pele-label" font-size="$smallInt"',
            options.icons,
          ),
        )
        ..write('</g>');
    }
  }
  final clusters = clustersBuf.toString();
  final struckTitles = struckTitlesBuf.toString();
  final nodesOut = nodesOutBuf.toString();

  final edgesOutBuf = StringBuffer();
  final labelsOutBuf = StringBuffer();
  for (var i = 0; i < cedges.length; i++) {
    final ce = cedges[i];
    final edge = drawn[i];
    final label = edgeLabels[i];
    final startType = edge.arrowTypeStart;
    final endType = edge.arrowTypeEnd;
    final startTrim = classMarkerTrim(startType);
    final endTrim = classMarkerTrim(endType);
    EdgePath path;
    if (ce.src == ce.dst) {
      final c = cnodes[ce.src];
      final view = views[ce.src];
      final k = loopAt[i];
      final x = c.x + ox + view.w / 2;
      final y = c.y + oy;
      final spread = math.min(view.h / 2 - 4, 8.0 + k * 6);
      final reach = _LOOP + k * 8;
      path = EdgePath(
        d: 'M${num(x + startTrim)},${num(y - spread)}C${num(x + reach + startTrim)},${num(y - spread)} ${num(x + reach + endTrim)},${num(y + spread)} ${num(x + endTrim)},${num(y + spread)}',
        sx: x,
        sy: y - spread,
        sdx: -1,
        sdy: 0,
        ex: x,
        ey: y + spread,
        edx: -1,
        edy: 0,
      );
    } else {
      final route = ce.route;
      for (var k = 0; k < route.length; k += 3) {
        route[k] += ox;
        route[k + 1] += oy;
      }
      path = routePath(route, null, startTrim, endTrim);
    }
    final attrs = edge.pattern == 'dashed'
        ? ' stroke-dasharray="6 4"'
        : edge.pattern == 'dotted'
        ? ' stroke-dasharray="2 4"'
        : '';
    edgesOutBuf
      ..write(
        '<g class="pele-edge${edge.pattern == 'dotted' ? ' pele-note-edge' : ' pele-relation'}" data-id="${escText(edge.id)}">',
      )
      ..write('<path d="${path.d}"$attrs/>')
      ..write(
        classMarker(startType, path.sx, path.sy, path.sdx, path.sdy, _LINE),
      )
      ..write(classMarker(endType, path.ex, path.ey, path.edx, path.edy, _LINE))
      ..write('</g>');
    if (label.width > 0) {
      final x = ce.labelX + ox;
      final y = ce.labelY + oy;
      labelsOutBuf.write(edgeLabelSvg(edge.id, label, x, y, '', options.icons));
    }
  }
  final edgesOut = edgesOutBuf.toString();
  final labelsOut = labelsOutBuf.toString();

  final cardsOutBuf = StringBuffer();
  for (final item in cards) {
    if (item.math != null) {
      cardsOutBuf.write(
        labelSvg(
          item.math!,
          item.x + ox,
          item.y + oy,
          ' class="pele-cardinality"',
          options.icons,
        ),
      );
    } else {
      cardsOutBuf.write(
        '<text class="pele-cardinality" x="${num(item.x + ox)}" y="${num(item.y + oy + tiny * 0.35)}" text-anchor="middle">${esc(item.text)}</text>',
      );
    }
  }
  final cardsOut = cardsOutBuf.toString();

  final titled = withTitle(
    db.title,
    measurer,
    size,
    pad,
    width,
    height,
    (clusters.isNotEmpty ? '<g class="pele-clusters">$clusters</g>' : '') +
        (edgesOut.isNotEmpty
            ? '<g class="pele-edges" fill="none" stroke="$_LINE" stroke-linecap="round">$edgesOut</g>'
            : '') +
        (struckTitles.isNotEmpty
            ? '<g class="pele-cluster-titles">$struckTitles</g>'
            : '') +
        (labelsOut.isNotEmpty
            ? '<g class="pele-edge-labels" font-size="$smallInt">$labelsOut</g>'
            : '') +
        (cardsOut.isNotEmpty
            ? '<g class="pele-cardinalities" font-size="$tinyInt" fill="var(--_m)">$cardsOut</g>'
            : '') +
        '<g class="pele-nodes">$nodesOut</g>',
  );
  final svg = svgDocument(
    'class',
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

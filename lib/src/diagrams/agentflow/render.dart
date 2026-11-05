// Upstream: src/diagrams/agentflow/render.ts

import 'dart:math' as math;
import 'dart:typed_data';

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
import '../../text/entities.dart';
import '../../text/label.dart';
import '../../text/measurer.dart';
import '../../types.dart';
import '../../util/math_js.dart';
import '../../util/url.dart';
import '../common/fit_width.dart';
import '../flowchart/shapes.dart';
import 'color_slots.dart';
import 'db.dart';
import 'graph.dart';

// The number of series tokens, which is the palette Mermaid's slot rules are applied to.
const int PALETTE = 8;

const double _nodeSep = 40;
const double _edgeSep = 16;
const double _rankSep = 48;
const double _groupPad = 20;
const double _loop = 26;
const double _dots = 14;
const String _collapsed = 'collapsed';
// The side a flow runs toward, with sides numbered clockwise from the top.
const Map<Dir, int> _flowEnd = <Dir, int>{'TB': 2, 'RL': 3, 'BT': 0, 'LR': 1};

final Expando<AgentGraph> _graphs = Expando<AgentGraph>();

// Builds the graph once per model. Building it also records the model's shape and containment diagnostics.
AgentGraph agentGraph(AgentflowDb db, Config config) {
  var graph = _graphs[db];
  if (graph == null) {
    final flow = config['flowchart'];
    final curve = flow is Map ? flow['curve'] : null;
    graph = buildAgentGraph(db, PALETTE, curve is String ? curve : null);
    _graphs[db] = graph;
  }
  return graph;
}

double _numberOption(Config config, String key, double fallback) {
  final af = config['agentflow'];
  final value = af is Map ? af[key] : null;
  if (value is int && value > 0) {
    return math.min<double>(value.toDouble(), 2000.0);
  }
  if (value is double && value > 0) {
    return math.min<double>(value, 2000.0);
  }
  return fallback;
}

// A palette color as an outline with a light wash of the same color inside.
// A fill the author set replaces the wash and stays opaque.
String _tint(int slot, String wash, ResolvedStyle style) {
  final color = seriesColor(slot);
  return ' fill="$color"${setsFill(style.shape) ? '' : ' fill-opacity="$wash"'} stroke="$color"';
}

class _NodeView {
  _NodeView({
    required this.node,
    required this.style,
    required this.label,
    required this.shape,
    required this.w,
    required this.h,
    required this.dy,
    required this.loops,
  });

  final GraphNode node;
  final ResolvedStyle style;
  final Label label;
  final String shape;
  final double w;
  final double h;
  final double dy;
  int loops;
}

class _HeldEdge {
  const _HeldEdge({
    required this.edge,
    required this.label,
    required this.src,
    required this.dst,
  });

  final GraphEdge edge;
  final Label label;
  final int src;
  final int dst;
}

Rendered renderAgentflow(AgentflowDb db, Config config, RenderOptions options) {
  if (!runsAcross(db.direction)) return _draw(db, config, options, false);
  return turnToFit(options, (down) => _draw(db, config, options, down));
}

// `turned` draws a diagram that runs across as one that runs down.
Rendered _draw(
  AgentflowDb db,
  Config config,
  RenderOptions options,
  bool turned,
) {
  final graph = agentGraph(db, config);
  final size = options.fontSize ?? 16;
  final edgeSize = roundJs(size * 0.875);
  final measurer =
      options.measurer ??
      defaultMeasurer(options.fontFamily, options.fontFamilyMono);
  final wrapWidth = _numberOption(config, 'wrappingWidth', 120);
  final minWidth = _numberOption(config, 'minNodeWidth', 120);
  final pad = options.padding ?? 8;
  final icons = options.icons;

  final index = <String, int>{};
  final views = <_NodeView>[];
  final cnodes = <CNode>[];
  for (var i = 0; i < graph.nodes.length; i++) {
    index[graph.nodes[i].id] = i;
  }

  for (final node in graph.nodes) {
    final styles = node.cssStyles.isNotEmpty
        ? <String>[...node.cssCompiledStyles, ...node.cssStyles]
        : node.cssCompiledStyles;
    final style = resolveStyle(styles);
    final textStyle =
        (style.bold ? Style.Bold : 0) | (style.italic ? Style.Italic : 0);
    final markdown = node.labelType == 'markdown';
    final fontSize = style.fontSize ?? size;
    _NodeView view;
    CNode c;
    if (node.isGroup) {
      final label = layoutLabel(
        node.label,
        markdown,
        measurer,
        fontSize,
        4000,
        textStyle,
      );
      view = _NodeView(
        node: node,
        style: style,
        label: label,
        shape: 'group',
        w: 0,
        h: 0,
        dy: 0,
        loops: 0,
      );
      c = cnode(0, 0);
      c.isGroup = true;
      c.dir = (node.dir != null && node.dir!.isNotEmpty)
          ? direction(node.dir)
          : null;
      c.padX = _groupPad;
      c.padTop = label.height > 0 ? label.height + 16 : _groupPad;
      c.padBottom = _groupPad;
      c.minW = label.width + 2 * _groupPad - 12;
    } else if (node.shape == 'collapsedGroup') {
      final label = layoutLabel(
        node.label,
        markdown,
        measurer,
        fontSize,
        wrapWidth,
        textStyle,
      );
      final w = math.max<double>(label.width, minWidth) + 2 * PAD_X;
      final h = label.height + 2 * PAD_Y + _dots;
      view = _NodeView(
        node: node,
        style: style,
        label: label,
        shape: _collapsed,
        w: w,
        h: h,
        dy: -_dots / 2,
        loops: 0,
      );
      c = cnode(w, h);
    } else {
      final shape = canonicalShape(node.shape);
      final label = layoutLabel(
        node.label,
        markdown,
        measurer,
        fontSize,
        wrapWidth,
        textStyle,
      );
      // A diamond grows twice as fast as its label, so it keeps the label's own width.
      final s = shapeSize(
        shape,
        shape == 'diam' ? label.width : math.max<double>(label.width, minWidth),
        label.height,
      );
      view = _NodeView(
        node: node,
        style: style,
        label: label,
        shape: shape,
        w: s.w,
        h: s.h,
        dy: s.dy,
        loops: 0,
      );
      c = cnode(s.w, s.h);
    }
    c.seq = views.length.toDouble();
    views.add(view);
    cnodes.add(c);
  }
  for (var i = 0; i < graph.nodes.length; i++) {
    final node = graph.nodes[i];
    cnodes[i].parent = node.parentId != null
        ? (index[node.parentId!] ?? -1)
        : -1;
  }
  inheritCrossedDirections(
    cnodes,
    graph.edges.map((edge) => (index[edge.start] ?? -1, index[edge.end] ?? -1)),
  );

  final rootDir = turned ? 'TB' : direction(db.direction);
  // The direction of the level a node sits in.
  Dir flowOf(int i) {
    Dir? dir;
    for (
      var p = cnodes[i].parent, hops = 0;
      p >= 0 && dir == null && hops < 10000;
      p = cnodes[p].parent, hops++
    ) {
      dir = cnodes[p].dir;
    }
    return dir ?? rootDir;
  }

  bool flowsSideways(int i) {
    final dir = flowOf(i);
    return dir == 'LR' || dir == 'RL';
  }

  final depth = Int32List(cnodes.length)..fillRange(0, cnodes.length, -1);
  for (var i = 0; i < cnodes.length; i++) {
    final chain = <int>[];
    var j = i;
    while (j >= 0 && depth[j] < 0 && chain.length <= cnodes.length) {
      chain.add(j);
      j = cnodes[j].parent;
    }
    var d = j >= 0 ? depth[j] + 1 : 0;
    for (var k = chain.length - 1; k >= 0; k--) {
      depth[chain[k]] = d++;
    }
  }
  bool contains(int group, int i) {
    var j = i;
    for (var d = depth[i]; d > depth[group]; d--) {
      j = cnodes[j].parent;
    }
    return j == group && i != group;
  }

  final cedges = <CEdge>[];
  final edgeLabels = <Label>[];
  final drawn = <GraphEdge>[];
  // Edges between a node and a container around it. The layout has no place for them, so they
  // are drawn afterwards, between the node and the container's border.
  final held = <_HeldEdge>[];
  for (final edge in graph.edges) {
    final src = index[edge.start];
    final dst = index[edge.end];
    if (src == null || dst == null) continue;
    final label = layoutLabel(
      edge.label,
      edge.labelType == 'markdown',
      measurer,
      edgeSize.toDouble(),
      wrapWidth,
    );
    if (contains(src, dst) || contains(dst, src)) {
      held.add(_HeldEdge(edge: edge, label: label, src: src, dst: dst));
      continue;
    }
    if (src == dst) {
      // A self-loop sits beside the node, across the flow, and the node's box grows to hold it.
      views[src].loops++;
      if (flowsSideways(src)) {
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
        minlen: edge.minlen ?? 1,
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

  final title = layoutLabel(db.title, false, measurer, size, 4000, Style.Bold);
  final titleHeight = title.height > 0 ? title.height + 12 : 0.0;
  final inner = math.max<double>(layout.width, title.width);
  final ox = pad + (inner - layout.width) / 2;
  final oy = pad + titleHeight;
  shiftLayout(cnodes, cedges, ox, oy);
  final width = (inner + 2 * pad).ceilToDouble();
  final height = (layout.height + titleHeight + 2 * pad).ceilToDouble();
  final links = <LinkInfo>[];

  // An edge between a node and a container around it runs straight between the node and the
  // container's border: out along the flow, or in against it. If another node is in the way it
  // takes a side instead, and failing that the far end.
  final heldPaths = <EdgePath>[];
  final heldLabels = <double>[];
  final heldRoutes = <List<double>>[];
  final careful = held.length * cnodes.length < 2000000;
  for (final h in held) {
    final edge = h.edge;
    final src = h.src;
    final dst = h.dst;
    final out = contains(dst, src);
    final outer = out ? dst : src;
    final i = out ? src : dst;
    final g = cnodes[outer];
    final n = cnodes[i];
    final end = _flowEnd[g.dir ?? flowOf(outer)]!;
    final first = out ? end : (end + 2) & 3;
    List<double> toward(int side) {
      final upright = (side & 1) == 0;
      final sign = side == 0 || side == 3 ? -1.0 : 1.0;
      final nx = upright ? n.x : n.x + (sign * n.w) / 2;
      final ny = upright ? n.y + (sign * n.h) / 2 : n.y;
      final bx = upright ? n.x : g.x + (sign * g.w) / 2;
      final by = upright ? g.y + (sign * g.h) / 2 : n.y;
      final axis = upright ? 0.0 : 1.0;
      return out
          ? <double>[nx, ny, axis, bx, by, axis]
          : <double>[bx, by, axis, nx, ny, axis];
    }

    bool blocked(List<double> r) {
      for (var k = 0; k < cnodes.length; k++) {
        final c = cnodes[k];
        if (k != i &&
            !c.isGroup &&
            c.x + c.w / 2 > math.min<double>(r[0], r[3]) - 1 &&
            c.x - c.w / 2 < math.max<double>(r[0], r[3]) + 1 &&
            c.y + c.h / 2 > math.min<double>(r[1], r[4]) - 1 &&
            c.y - c.h / 2 < math.max<double>(r[1], r[4]) + 1) {
          return true;
        }
      }
      return false;
    }

    var route = toward(first);
    if (careful && blocked(route)) {
      for (final side in <int>[
        (first + 1) & 3,
        (first + 3) & 3,
        (first + 2) & 3,
      ]) {
        final other = toward(side);
        if (!blocked(other)) {
          route = other;
          break;
        }
      }
    }
    heldRoutes.add(route);
    heldLabels.addAll(<double>[
      (route[0] + route[3]) / 2,
      (route[1] + route[4]) / 2,
    ]);
    final drawnRoute = List<double>.of(route);
    insetRoute(drawnRoute, out ? 0 : 3, views[i], n);
    heldPaths.add(
      routePath(drawnRoute, 'linear', 0, markerTrim(edge.arrowTypeEnd)),
    );
  }

  final crossings = <int, List<double>>{};
  var anyGroup = false;
  for (final c in cnodes) {
    if (c.isGroup) anyGroup = true;
  }
  if (anyGroup) {
    for (final e in cedges) {
      markCrossings(crossings, e.route);
    }
    for (final route in heldRoutes) {
      markCrossings(crossings, route);
    }
  }

  final clusters = StringBuffer();
  final nodesOut = StringBuffer();
  final fills = <Fill>[];
  for (var i = 0; i < views.length; i++) {
    final view = views[i];
    final c = cnodes[i];
    final node = view.node;
    final x = c.x;
    final y = c.y;
    final classes = classNames(
      node.cssClasses.replaceFirst(RegExp(r'^default\s?'), ''),
    );
    final id = escText(node.id);
    if (c.isGroup) {
      if (paints(view.style.shape)) {
        fills.add(
          Fill(
            box: <double>[x - c.w / 2, y - c.h / 2, x + c.w / 2, y + c.h / 2],
            shape: view.style.shape,
          ),
        );
      }
      final titleX = clusterTitleX(c, view.label.width, crossings, _groupPad);
      final inkAttr = inkFill((
        shape: view.style.shape,
        text: view.style.text,
      ), 'var(--_m)');
      clusters
        ..write('<g class="pele-cluster pele-flow$classes" data-id="$id">')
        ..write(
          '<rect x="${num(x - c.w / 2)}" y="${num(y - c.h / 2)}" width="${num(c.w)}" height="${num(c.h)}"${rounded(_tint(node.colorIndex ?? KIND_SLOT.length, '0.06', view.style) + view.style.shape)}/>',
        )
        ..write(
          labelSvg(
            view.label,
            titleX,
            y - c.h / 2 + 8 + view.label.height / 2,
            ' class="pele-cluster-label"$inkAttr${view.style.text}',
            icons,
          ),
        )
        ..write('</g>');
      continue;
    }

    final w = view.w;
    final h = view.h;
    var kind = '';
    String shape;
    if (view.shape == _collapsed) {
      final color = seriesColor(node.colorIndex ?? KIND_SLOT.length);
      final line = h / 2 - _dots - 2;
      final dots = line + (_dots + 2) / 2;
      shape =
          '<rect x="${num(-w / 2)}" y="${num(-h / 2)}" width="${num(w)}" height="${num(h)}"${rounded(_tint(node.colorIndex ?? KIND_SLOT.length, '0.06', view.style) + view.style.shape)}/>'
          '<path d="M${num(-w / 2 + 10)},${num(line)}H${num(w / 2 - 10)}" fill="none" stroke="$color" stroke-dasharray="3 3"${view.style.line}/>'
          '<path class="pele-collapsed-mark" d="${_dot(-9, dots)}${_dot(0, dots)}${_dot(9, dots)}" fill="$color" stroke="none"/>';
    } else {
      final slot = KIND_SLOT[node.kind ?? 'task'] ?? 1;
      kind = ' pele-kind-${node.kind ?? 'task'}';
      shape = drawShape(
        view.shape,
        w,
        h,
        _tint(slot, '0.14', view.style) + view.style.shape,
        ' stroke="${seriesColor(slot)}"${view.style.line}',
      );
    }

    final ink = view.shape == _collapsed || shapeFilled(view.shape)
        ? inkFill((shape: view.style.shape, text: view.style.text))
        : '';
    var text = labelSvg(
      view.label,
      0,
      view.dy,
      ' class="pele-label"$ink${view.style.text}',
      icons,
    );
    final internal = RegExp(r' internal-link(?: |$)').hasMatch('$classes ');
    if (internal &&
        node.label != null &&
        node.label!.isNotEmpty &&
        options.links != false) {
      // The label is a note name, but it still ends up in an href, so it gets the same check as a URL.
      final name = decodeEntities(node.label!);
      final safe = internalLink(name, options);
      final target = esc(name);
      text =
          '<a class="internal-link"${safe ? ' href="$target"${relAttr(options)}' : ''} data-href="$target">$text</a>';
      links.add(LinkInfo(id: node.id, href: name, internal: true));
    }
    var body = '$shape$text';
    if (node.tooltip != null && node.tooltip!.isNotEmpty) {
      body = '<title>${escText(node.tooltip!)}</title>$body';
    }
    if (node.link != null && node.link!.isNotEmpty) {
      body = linked(
        body,
        node.link!,
        node.id,
        links,
        options,
        (node.linkTarget != null && node.linkTarget!.isNotEmpty)
            ? ' target="${esc(node.linkTarget!)}"'
            : '',
      );
    }
    nodesOut.write(
      '<g class="pele-node pele-shape-${view.shape}$kind$classes" data-id="$id" transform="translate(${num(x)},${num(y)})">$body</g>',
    );
  }

  final casings = StringBuffer();
  final edgesOut = StringBuffer();
  final labelsOut = StringBuffer();
  void put(GraphEdge edge, Label label, EdgePath path, double x, double y) {
    final style = edge.style.isNotEmpty || edge.cssCompiledStyles.isNotEmpty
        ? resolveStyle(<String>[...edge.cssCompiledStyles, ...edge.style])
        : null;
    final endType = edge.arrowTypeEnd;
    final over = overFills(
      path.d,
      <double>[path.ex, path.ey],
      fills,
      style?.line ?? '',
      path.tokens,
    );
    final hasOver = over != null && over.isNotEmpty;
    final color = hasOver
        ? over
        : ((style?.stroke != null && style!.stroke!.isNotEmpty)
              ? esc(style.stroke!)
              : 'var(--_l)');
    final kind = edge.thickness == 'dotted'
        ? 'reference'
        : (endType == 'arrow_cross' ? 'failure' : 'sequence');
    final classes = classNames(
      edge.classes.replaceAll(
        RegExp(r'edge-thickness-normal|edge-pattern-solid|flowchart-link'),
        '',
      ),
    );
    if (over == '') {
      casings.write(edgeCasing(path, 'none', endType, style?.line ?? ''));
    }
    edgesOut
      ..write(
        '<g class="pele-edge pele-edge-$kind$classes" data-id="${escText(edge.id)}"${hasOver ? ' stroke="$over"' : ''}${style?.line ?? ''}>',
      )
      ..write(
        '<path d="${path.d}"${edge.thickness == 'dotted' ? ' stroke-dasharray="3 4"' : ''}/>',
      )
      ..write(marker(endType, path.ex, path.ey, path.edx, path.edy, color))
      ..write('</g>');
    if (label.width > 0) {
      labelsOut.write(
        edgeLabelSvg(edge.id, label, x, y, style?.text ?? '', icons),
      );
    }
  }

  final loopSeen = <int, int>{};
  for (var i = 0; i < cedges.length; i++) {
    final ce = cedges[i];
    final edge = drawn[i];
    final label = edgeLabels[i];
    final endType = edge.arrowTypeEnd;
    EdgePath path;
    if (ce.src == ce.dst) {
      final view = views[ce.src];
      final k = loopSeen[ce.src] ?? 0;
      loopSeen[ce.src] = k + 1;
      path = loopPath(
        cnodes[ce.src],
        view.w,
        view.h,
        k,
        flowsSideways(ce.src),
        _loop,
        markerTrim(endType),
        ce,
      );
    } else {
      final route = List<double>.of(ce.route);
      insetRoute(route, 0, views[ce.src], cnodes[ce.src]);
      insetRoute(route, route.length - 3, views[ce.dst], cnodes[ce.dst]);
      path = routePath(route, edge.curve, 0, markerTrim(endType));
    }
    put(edge, label, path, ce.labelX, ce.labelY);
  }
  for (var i = 0; i < held.length; i++) {
    final h = held[i];
    put(
      h.edge,
      h.label,
      heldPaths[i],
      heldLabels[2 * i],
      heldLabels[2 * i + 1],
    );
  }

  final clustersStr = clusters.toString();
  final casingsStr = casings.toString();
  final edgesStr = edgesOut.toString();
  final labelsStr = labelsOut.toString();
  final nodesStr = nodesOut.toString();

  final svg = svgDocument(
    'agentflow',
    width,
    height,
    size,
    options,
    db,
    labelSvg(
          title,
          width / 2,
          pad + title.height / 2,
          ' class="pele-title" font-weight="var(--_tw)"',
        ) +
        (clustersStr.isNotEmpty
            ? '<g class="pele-clusters">$clustersStr</g>'
            : '') +
        casingsSvg(casingsStr) +
        (edgesStr.isNotEmpty
            ? '<g class="pele-edges" fill="none" stroke="var(--_l)" stroke-linecap="round">$edgesStr</g>'
            : '') +
        (labelsStr.isNotEmpty
            ? '<g class="pele-edge-labels" font-size="$edgeSize">$labelsStr</g>'
            : '') +
        '<g class="pele-nodes">$nodesStr</g>',
  );

  return Rendered(svg: svg, width: width, height: height, links: links);
}

String _dot(double x, double y) {
  return 'M${num(x - 1.75)},${num(y)}a1.75,1.75 0 1 0 3.5,0a1.75,1.75 0 1 0 -3.5,0Z';
}

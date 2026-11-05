// Upstream: src/diagrams/flowchart/render.ts

import 'dart:math' as math;

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
import 'db.dart';
import 'graph.dart';
import 'shapes.dart';

const double _nodeSep = 40;
const double _edgeSep = 16;
const double _rankSep = 48;
const double _groupPad = 20;
const double _loop = 26;
const String _shapeAttrs = ' fill="var(--_s)" stroke="var(--_b)"';
const String _lineAttrs = ' stroke="var(--_b)"';

double _numberOption(Config section, String key, double fallback) {
  final value = section[key];
  if (value is int && value > 0) {
    return math.min(value.toDouble(), 2000.0);
  }
  if (value is double && value > 0) {
    return math.min(value, 2000.0);
  }
  return fallback;
}

/// A diagram type that is a flowchart with a different layout, which may draw its top-level groups itself.
class FlowVariant {
  const FlowVariant({
    required this.type,
    required this.prepare,
    required this.layout,
    this.drawGroup,
    this.filledBox,
  });

  final String type;
  final void Function(FlowGraph graph) prepare;
  final CompoundResult Function(
    List<CNode> nodes,
    List<CEdge> edges,
    Dir dir,
    LayeredOptions opt,
    bool tight,
  )
  layout;
  final String Function(
    CNode c,
    Label label,
    ResolvedStyle style,
    String classes,
    String id,
    Dir dir,
    IconResolver? icons,
  )?
  drawGroup;

  /// The part of a [drawGroup] group that takes its fill, as `[left, top, right, bottom]`.
  final List<double> Function(CNode c, Dir dir)? filledBox;
}

double _assetSize(double? value, double fallback) {
  return value != null && value > 0 && value <= 4000 ? value : fallback;
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

Rendered renderFlowchart(
  FlowDb db,
  Config config,
  RenderOptions options, [
  FlowVariant? variant,
]) {
  Rendered fitted(bool down) => tighten(
    options,
    (tight) => _draw(db, config, options, variant, down, tight),
  );
  return runsAcross(db.direction) ? turnToFit(options, fitted) : fitted(false);
}

// `turned` draws a flowchart that runs across as one that runs down. `tight` sets nodes closer together.
Rendered _draw(
  FlowDb db,
  Config config,
  RenderOptions options,
  FlowVariant? variant,
  bool turned,
  bool tight,
) {
  final groupPad = tight ? 12.0 : _groupPad;
  final own = variant != null ? config[variant.type] : null;
  final flow = own is Map ? asConfig(own) : asConfig(config['flowchart']);
  final curveOpt = flow['curve'];
  final graph = buildFlowGraph(db, curveOpt is String ? curveOpt : null);
  variant?.prepare(graph);
  final size = options.fontSize ?? 16.0;
  final edgeSize = roundJs(size * 0.875);
  final measurer =
      options.measurer ??
      defaultMeasurer(options.fontFamily, options.fontFamilyMono);
  final wrapWidth = math.min(
    _numberOption(flow, 'wrappingWidth', 200),
    variant != null && tight ? 100.0 : double.infinity,
  );
  final pad = options.padding ?? 8.0;
  final icons = options.icons;

  final index = <String, int>{};
  final views = <_NodeView>[];
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
        variant != null && tight
            ? math.max(80.0, titleRoom(options) / 2)
            : 4000.0,
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
      c.padX = groupPad;
      c.padTop = label.height > 0 ? label.height + 16 : _groupPad;
      c.padBottom = groupPad;
      c.minW = label.width + 2 * groupPad - 12;
    } else {
      final shape = canonicalShape(node.shape);
      final hasImg = node.img != null && node.img!.isNotEmpty;
      final hasIcon = node.icon != null && node.icon!.isNotEmpty;
      final text = (hasImg || hasIcon || shapeHasLabel(shape))
          ? node.label
          : null;
      final label = layoutLabel(
        text,
        markdown,
        measurer,
        fontSize,
        wrapWidth,
        textStyle,
      );
      double w;
      double h;
      var dy = 0.0;
      if (hasImg || hasIcon) {
        final box = hasImg ? 80.0 : 48.0;
        final aw = _assetSize(node.assetWidth, box);
        final ah = _assetSize(node.assetHeight, box);
        w = math.max(aw, label.width + 8);
        h = ah + (label.height > 0 ? label.height + 6 : 0);
        dy = node.pos == 't' ? -ah / 2 : ah / 2;
        if (label.height == 0) dy = 0;
      } else {
        final s = shapeSize(shape, label.width, label.height);
        w = s.w;
        h = s.h;
        dy = s.dy;
      }
      view = _NodeView(
        node: node,
        style: style,
        label: label,
        shape: shape,
        w: w,
        h: h,
        dy: dy,
        loops: 0,
      );
      c = cnode(w, h);
    }
    c.seq = views.length.toDouble();
    views.add(view);
    cnodes.add(c);
  }
  for (var i = 0; i < graph.nodes.length; i++) {
    final parentId = graph.nodes[i].parentId;
    cnodes[i].parent = parentId != null ? (index[parentId] ?? -1) : -1;
  }
  inheritCrossedDirections(
    cnodes,
    graph.edges.map((edge) => (index[edge.start] ?? -1, index[edge.end] ?? -1)),
  );

  final rootDir = turned ? 'TB' : direction(db.direction);
  bool flowsSideways(int i) {
    Dir? dir;
    for (
      var p = cnodes[i].parent, hops = 0;
      p >= 0 && dir == null && hops < 10000;
      p = cnodes[p].parent, hops++
    ) {
      dir = cnodes[p].dir;
    }
    dir ??= rootDir;
    return dir == 'LR' || dir == 'RL';
  }

  // The edges on one side of a node spread along it; a picture or an icon keeps them at its middle.
  for (var i = 0; i < views.length; i++) {
    final view = views[i];
    if (view.node.isGroup) {
      cnodes[i].span = double.infinity;
    } else if ((view.node.img == null || view.node.img!.isEmpty) &&
        (view.node.icon == null || view.node.icon!.isEmpty)) {
      cnodes[i].span = shapeSpan(view.shape, view.w, view.h, flowsSideways(i));
    }
  }

  final cedges = <CEdge>[];
  final edgeLabels = <Label>[];
  final drawn = <GraphEdge>[];
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

  final layoutOptions = LayeredOptions(
    nodeSep: _numberOption(flow, 'nodeSpacing', _nodeSep) * (tight ? 0.5 : 1),
    edgeSep: _edgeSep,
    rankSep: _numberOption(flow, 'rankSpacing', _rankSep) * (tight ? 0.75 : 1),
    portSep: 20,
    tracks: curveOpt is String && RegExp(r'^step').hasMatch(curveOpt),
    straight: curveOpt == 'linear',
    headRoom: markerTrim('arrow_point'),
  );
  final layout = variant != null
      ? variant.layout(cnodes, cedges, rootDir, layoutOptions, tight)
      : compoundLayout(cnodes, cedges, rootDir, layoutOptions);

  final title = titleLabel(
    db.title,
    measurer,
    size,
    tight ? titleRoom(options) : 4000,
  );
  final titleHeight = title.height > 0 ? title.height + 12 : 0.0;
  final inner = math.max(layout.width, title.width);
  final ox = pad + (inner - layout.width) / 2;
  final oy = pad + titleHeight;
  shiftLayout(cnodes, cedges, ox, oy);
  final width = (inner + 2 * pad).ceilToDouble();
  final height = (layout.height + titleHeight + 2 * pad).ceilToDouble();
  final links = <LinkInfo>[];

  final Crossings crossings = <int, List<double>>{};
  var anyGroup = false;
  for (final c in cnodes) {
    if (c.isGroup) anyGroup = true;
  }
  if (anyGroup) {
    for (final e in cedges) {
      markCrossings(crossings, e.route);
    }
  }

  var clusters = '';
  var struckTitles = '';
  var nodesOut = '';
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
    if (c.isGroup && variant?.drawGroup != null && c.parent < 0) {
      if (paints(view.style.shape) && variant!.filledBox != null) {
        fills.add(
          Fill(box: variant.filledBox!(c, rootDir), shape: view.style.shape),
        );
      }
      clusters += variant!.drawGroup!(
        c,
        view.label,
        view.style,
        classes,
        id,
        rootDir,
        icons,
      );
      continue;
    }
    if (c.isGroup) {
      if (paints(view.style.shape)) {
        fills.add(
          Fill(
            box: <double>[x - c.w / 2, y - c.h / 2, x + c.w / 2, y + c.h / 2],
            shape: view.style.shape,
          ),
        );
      }
      final titleX = clusterTitleX(c, view.label.width, crossings, groupPad);
      final titleY = y - c.h / 2 + 8 + view.label.height / 2;
      final struck = titleCrossed(c, view.label.width, titleX, crossings);
      // A title drawn over the edges sits on a halo in the theme's colors.
      final titleAttrs =
          ' class="pele-cluster-label"${struck ? ' fill="var(--_m)"' : inkFill((shape: view.style.shape, text: view.style.text), 'var(--_m)')}${view.style.text}';
      if (struck) {
        struckTitles += struckTitle(
          view.label,
          titleX,
          titleY,
          titleAttrs,
          id,
          cnodes,
          i,
          icons,
        );
      }
      clusters +=
          '<g class="pele-cluster$classes" data-id="$id">'
          '<rect x="${num(x - c.w / 2)}" y="${num(y - c.h / 2)}" width="${num(c.w)}" height="${num(c.h)}" fill="var(--_a)"${setsFill(view.style.shape) ? '' : ' fill-opacity="0.5"'} stroke="var(--_b)"${rounded(view.style.shape)}/>'
          '${struck ? '' : labelSvg(view.label, titleX, titleY, titleAttrs, icons)}'
          '</g>';
      continue;
    }

    final w = view.w;
    final h = view.h;
    String innerSvg;
    var ink = '';
    if (node.img != null && node.img!.isNotEmpty) {
      final aw = _assetSize(node.assetWidth, 80);
      final ah = _assetSize(node.assetHeight, 80);
      final top = view.label.height > 0
          ? (node.pos == 't' ? h / 2 - ah : -h / 2)
          : -ah / 2;
      final src = imageUrl(safeUrl(node.img!), options);
      innerSvg = src == null
          ? ''
          : '<image href="${esc(src)}" x="${num(-aw / 2)}" y="${num(top)}" width="${num(aw)}" height="${num(ah)}" preserveAspectRatio="${node.constraint == 'on' ? 'xMidYMid meet' : 'none'}"/>';
    } else if (node.icon != null && node.icon!.isNotEmpty) {
      final box = _assetSize(node.assetHeight, 48);
      final top = view.label.height > 0
          ? (node.pos == 't' ? h / 2 - box : -h / 2)
          : -box / 2;
      final frame = node.shape == 'icon'
          ? ''
          : node.shape == 'iconCircle'
          ? '<circle cy="${num(top + box / 2)}" r="${num(box / 2)}"$_shapeAttrs${view.style.shape}/>'
          : '<rect x="${num(-box / 2)}" y="${num(top)}" width="${num(box)}" height="${num(box)}" rx="${node.shape == 'iconRounded' ? 8 : 0}"$_shapeAttrs${view.style.shape}/>';
      final glyph = box * 0.6;
      innerSvg =
          '$frame'
          '<svg class="pele-icon" data-icon="${escText(node.icon!)}" x="${num(-glyph / 2)}" y="${num(top + (box - glyph) / 2)}" width="${num(glyph)}" height="${num(glyph)}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${icons?.call(node.icon!) ?? ''}</svg>';
    } else {
      innerSvg = drawShape(
        view.shape,
        w,
        h,
        '$_shapeAttrs${view.style.shape}',
        '$_lineAttrs${view.style.line}',
      );
      if (shapeFilled(view.shape)) {
        ink = inkFill((shape: view.style.shape, text: view.style.text));
      }
    }

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
    var body = '$innerSvg$text';
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
    nodesOut +=
        '<g class="pele-node pele-shape-${view.shape}$classes" data-id="$id" transform="translate(${num(x)},${num(y)})">$body</g>';
  }

  final reach = sideReach();
  for (var i = 0; i < cedges.length; i++) {
    final ce = cedges[i];
    if (ce.src == ce.dst ||
        drawn[i].thickness == 'invisible' ||
        ce.route.length < 6) {
      continue;
    }
    reach.add(
      ce.src,
      endSide(ce.route, 0, cnodes[ce.src]),
      drawn[i].arrowTypeStart,
    );
    reach.add(
      ce.dst,
      endSide(ce.route, ce.route.length - 3, cnodes[ce.dst]),
      drawn[i].arrowTypeEnd,
    );
  }

  var casings = '';
  var edgesOut = '';
  var labelsOut = '';
  final loopSeen = <int, int>{};
  for (var i = 0; i < cedges.length; i++) {
    final ce = cedges[i];
    final edge = drawn[i];
    final label = edgeLabels[i];
    final style = (edge.style.isNotEmpty || edge.cssCompiledStyles.isNotEmpty)
        ? resolveStyle(<String>[...edge.cssCompiledStyles, ...edge.style])
        : null;
    if (edge.thickness != 'invisible') {
      final startType = edge.arrowTypeStart;
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
        final leaves = reach.of(ce.src, endSide(route, 0, cnodes[ce.src]));
        final arrives = reach.of(
          ce.dst,
          endSide(route, route.length - 3, cnodes[ce.dst]),
        );
        insetRoute(route, 0, views[ce.src], cnodes[ce.src]);
        insetRoute(route, route.length - 3, views[ce.dst], cnodes[ce.dst]);
        path = routePath(
          route,
          edge.curve,
          markerTrim(startType),
          markerTrim(endType),
          leaves,
          arrives,
        );
      }
      final over = overFills(
        path.d,
        <double>[path.sx, path.sy, path.ex, path.ey],
        fills,
        style?.line ?? '',
        path.tokens,
      );
      final hasOver = over != null && over.isNotEmpty;
      final color = hasOver
          ? over
          : (style?.stroke != null &&
                    style!.stroke!.isNotEmpty &&
                    edge.thickness != 'invisible'
                ? esc(style.stroke!)
                : 'var(--_l)');
      var attrs = '';
      if (edge.thickness == 'thick') {
        attrs += ' stroke-width="2.5"';
      } else if (edge.thickness == 'dotted') {
        attrs += ' stroke-dasharray="3 4"';
      }
      final classes = classNames(
        edge.classes.replaceAll(
          RegExp(r'edge-thickness-normal|edge-pattern-solid|flowchart-link'),
          '',
        ),
      );
      if (over == '') {
        casings += edgeCasing(
          path,
          startType,
          endType,
          style?.line ?? '',
          edge.thickness == 'thick',
        );
      }
      edgesOut +=
          '<g class="pele-edge$classes" data-id="${escText(edge.id)}"${hasOver ? ' stroke="$over"' : ''}${style?.line ?? ''}>'
          '<path d="${path.d}"$attrs/>'
          '${marker(startType, path.sx, path.sy, path.sdx, path.sdy, color)}'
          '${marker(endType, path.ex, path.ey, path.edx, path.edy, color)}'
          '</g>';
    }
    if (label.width > 0) {
      final x = ce.labelX;
      final y = ce.labelY;
      labelsOut += edgeLabelSvg(edge.id, label, x, y, style?.text ?? '', icons);
    }
  }

  final svg = svgDocument(
    variant?.type ?? 'flowchart',
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
        (clusters.isNotEmpty ? '<g class="pele-clusters">$clusters</g>' : '') +
        casingsSvg(casings) +
        (edgesOut.isNotEmpty
            ? '<g class="pele-edges" fill="none" stroke="var(--_l)" stroke-linecap="round">$edgesOut</g>'
            : '') +
        (struckTitles.isNotEmpty
            ? '<g class="pele-cluster-titles">$struckTitles</g>'
            : '') +
        (labelsOut.isNotEmpty
            ? '<g class="pele-edge-labels" font-size="$edgeSize">$labelsOut</g>'
            : '') +
        '<g class="pele-nodes">$nodesOut</g>',
  );

  return Rendered(svg: svg, width: width, height: height, links: links);
}

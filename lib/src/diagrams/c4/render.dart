// Upstream: src/diagrams/c4/render.ts

import 'dart:math' as math;

import '../../errors.dart';
import '../../preprocess.dart';
import '../../svg/builder.dart';
import '../../svg/edges.dart';
import '../../svg/ink.dart';
import '../../svg/root.dart';
import '../../svg/shapes.dart';
import '../../svg/theme.dart';
import '../../text/label.dart';
import '../../text/measurer.dart';
import '../../types.dart';
import '../../util/math_js.dart';
import '../../util/url.dart';
import '../common/fit_width.dart';
import '../common/literal_label.dart';
import 'db.dart';
import 'layout.dart';
import 'route.dart';

const double _pairShift = 7;
const double _narrowGap = 36;
const double _widen = 24;
const int _maxOffset = 2000;
// A label may cover this much of a shape's edge, where there is no text.
const double _edge = 8;
// Places along a relation to try for its label, nearest the middle first.
const List<double> _slide = <double>[0.5, 0.4, 0.6, 0.3, 0.7, 0.2, 0.8];
// Above this many box comparisons, labels stay at the middle and lines are not steered around shapes.
const int _careBudget = 2000000;

ResolvedStyle _userStyle(String? fill, String? stroke, String? color) {
  final declarations = <String>[];
  if (fill != null && fill.isNotEmpty) declarations.add('fill:$fill');
  if (stroke != null && stroke.isNotEmpty) declarations.add('stroke:$stroke');
  if (color != null && color.isNotEmpty) declarations.add('color:$color');
  return resolveStyle(declarations);
}

String _inkFill(ResolvedStyle style, [String? fallback]) =>
    inkFill((shape: style.shape, text: style.text), fallback);

final RegExp _reEntityHash = RegExp('\ufb02\u00b0\u00b0?');
final RegExp _reEntitySemi = RegExp('\u00b6\u00df');

String _link(
  String body,
  String? url,
  String id,
  List<LinkInfo> links,
  RenderOptions options,
) {
  if (url == null || url.isEmpty) return body;
  // Entity encoding has hidden any `#name;` in the address. Put it back, so that the check sees what a browser would.
  final restored = url.contains('\u00b6\u00df')
      ? url.replaceAll(_reEntityHash, '#').replaceAll(_reEntitySemi, ';')
      : url;
  return linked(body, sanitizeUrl(restored), id, links, options);
}

Rendered renderC4(C4Db db, Config config, RenderOptions options) {
  return tighten(options, (tight) {
    if (!tight) return _draw(db, config, options, false).$1;
    var (best, squeezed) = _draw(db, config, options, true, _narrowGap);
    for (
      var gap = _narrowGap + _widen;
      squeezed > 0 && gap <= _narrowGap + 3 * _widen;
      gap += _widen
    ) {
      final (wider, left) = _draw(db, config, options, true, gap);
      if (left < squeezed) {
        best = wider;
        squeezed = left;
      }
    }
    return best;
  });
}

(Rendered, int) _draw(
  C4Db db,
  Config config,
  RenderOptions options,
  bool tight, [
  double gap = _narrowGap,
]) {
  final size = options.fontSize ?? 16;
  final smallInt = roundJs(size * 0.8125);
  final small = smallInt.toDouble();
  final measurer =
      options.measurer ??
      defaultMeasurer(options.fontFamily, options.fontFamilyMono);
  final pad = options.padding ?? 8;
  final links = <LinkInfo>[];
  final layout = layoutC4(
    db,
    measurer,
    size,
    small,
    tight ? math.max(80.0, (options.maxWidth ?? 320) - 2 * pad) : null,
    gap,
  );
  final order = layout.order;
  final boxes = layout.boxes;
  final root = order[0];

  var minX = 0.0;
  var minY = 0.0;
  var maxX = root.w;
  var maxY = root.h;
  void grow(double x0, double y0, double x1, double y1) {
    minX = math.min(minX, x0);
    minY = math.min(minY, y0);
    maxX = math.max(maxX, x1);
    maxY = math.max(maxY, y1);
  }

  final ends = <Box>[];
  final pairs = <Box, Set<Box>>{};
  for (final rel in db.rels) {
    final from = rel.fromAttr != null ? null : db.getC4Shape(rel.from);
    final to = rel.toAttr != null ? null : db.getC4Shape(rel.to);
    final a = from != null ? boxes[from] : null;
    final b = to != null ? boxes[to] : null;
    if (a == null || b == null) {
      throw PeleError(
        'C4 rel "${rel.from}" -> "${rel.to}" references an unknown shape or boundary',
        'semantic',
        const PeleErrorInfo(type: 'c4'),
      );
    }
    ends.addAll(<Box>[a, b]);
    pairs.putIfAbsent(a, () => <Box>{}).add(b);
  }

  // What a relation's label should not cover: shapes, arrowheads, boundary headings, and the labels placed before it.
  final nodes = <Box>[];
  final taken = <double>[];
  for (final group in order) {
    for (final node in group.nodes) {
      nodes.add(node);
      taken.addAll(<double>[
        node.x + _edge,
        node.y + _edge,
        node.x + node.w - _edge,
        node.y + node.h - _edge,
      ]);
    }
  }
  final careful =
      db.rels.length * (nodes.length + order.length + 3 * db.rels.length) <=
      _careBudget;
  double covered(double x0, double y0, double x1, double y1) {
    var area = 0.0;
    for (var i = 0; i < taken.length; i += 4) {
      final w = math.min(x1, taken[i + 2]) - math.max(x0, taken[i]);
      if (w <= 0) continue;
      final h = math.min(y1, taken[i + 3]) - math.max(y0, taken[i + 1]);
      if (h > 0) area += w * h;
    }
    return area;
  }

  double offset(int? value) => value != null && value != 0
      ? math.max(-_maxOffset, math.min(_maxOffset, value)).toDouble()
      : 0.0;

  // Every line is drawn before any label is placed, so that labels can keep off the arrowheads.
  var casings = '';
  var edgesOut = '';
  final trim = markerTrim('arrow_point');
  final fills = <Fill>[];
  for (final group in order) {
    if (identical(group, root)) continue;
    final shape = _userStyle(group.boundary.bgColor, null, null).shape;
    if (paints(shape)) {
      fills.add(
        Fill(
          box: <double>[group.x, group.y, group.x + group.w, group.y + group.h],
          shape: shape,
        ),
      );
    }
  }
  final lanes = Lanes();
  for (final group in order) {
    if (!identical(group, root)) lanes.frame(group);
  }
  final routes = <Route>[];
  for (var index = 0; index < db.rels.length; index++) {
    final rel = db.rels[index];
    final a = ends[index * 2];
    final b = ends[index * 2 + 1];
    final style = _userStyle(null, rel.lineColor, null);
    final startArrow = rel.type == 'birel' || rel.type == 'rel_b';
    final endArrow = rel.type != 'rel_b';
    final reverse = !identical(a, b) && (pairs[b]?.contains(a) ?? false);
    final r = route(
      a,
      b,
      reverse ? _pairShift : 0,
      careful ? nodes : null,
      lanes,
      startArrow ? trim : 0,
      endArrow ? trim : 0,
    );
    grow(
      math.min(r.x0, r.x1),
      math.min(r.y0, r.y1),
      math.max(r.x0, r.x1),
      math.max(r.y0, r.y1),
    );
    if (startArrow && careful) {
      taken.addAll(<double>[
        r.sx - ARROW,
        r.sy - ARROW,
        r.sx + ARROW,
        r.sy + ARROW,
      ]);
    }
    if (endArrow && careful) {
      taken.addAll(<double>[
        r.ex - ARROW,
        r.ey - ARROW,
        r.ex + ARROW,
        r.ey + ARROW,
      ]);
    }
    final over = overFills(
      r.d,
      <double>[r.sx, r.sy, r.ex, r.ey],
      fills,
      style.line,
    );
    final hasOver = over != null && over.isNotEmpty;
    final color = hasOver
        ? over
        : (style.stroke != null && style.stroke!.isNotEmpty
              ? esc(style.stroke!)
              : 'var(--_l)');
    if (over == '') {
      casings += edgeCasing(
        r,
        startArrow ? 'arrow_point' : 'none',
        endArrow ? 'arrow_point' : 'none',
        style.line,
      );
    }
    edgesOut +=
        '<g class="pele-edge" data-id="${escText('${rel.from}-${rel.to}')}"${hasOver ? ' stroke="$over"' : ''}${style.line}><path d="${r.d}"/>'
        '${startArrow ? marker('arrow_point', r.sx, r.sy, r.sdx, r.sdy, color) : ''}'
        '${endArrow ? marker('arrow_point', r.ex, r.ey, r.edx, r.edy, color) : ''}'
        '</g>';
    routes.add(r);
  }

  // A boundary's heading goes at the left, the middle or the right of its top edge: the first of them no line crosses.
  for (final group in order) {
    if (!careful || group.headW == 0) continue;
    final top = group.y + HEAD_TOP;
    final bottom = group.y + group.head - LANE;
    var fewest = 1 << 30;
    for (final x in <double>[
      HEAD_LEFT,
      (group.w - group.headW) / 2,
      group.w - HEAD_LEFT - group.headW,
    ]) {
      var count = 0;
      for (final r in routes) {
        if (crosses(
          r.points,
          group.x + x - 4,
          top,
          group.x + x + group.headW + 4,
          bottom,
        )) {
          count++;
        }
      }
      if (count < fewest) {
        fewest = count;
        group.headX = x;
      }
      if (count == 0) break;
    }
    taken.addAll(<double>[
      group.x + group.headX - 4,
      top,
      group.x + group.headX + group.headW + 4,
      bottom,
    ]);
  }

  var labelsOut = '';
  for (var index = 0; index < db.rels.length; index++) {
    final rel = db.rels[index];
    final r = routes[index];
    final id = '${rel.from}-${rel.to}';
    final style = _userStyle(null, null, rel.textColor);
    final text =
        '${db.c4Type == 'C4Dynamic' ? '${index + 1}: ' : ''}${rel.label}';
    final label = layoutLabel(text, false, measurer, small, r.room);
    final rTechn = rel.techn;
    final techn = layoutLabel(
      rTechn != null && rTechn.isNotEmpty ? '[$rTechn]' : null,
      false,
      measurer,
      small,
      r.room,
      Style.Italic,
    );
    final lw = math.max(label.width, techn.width) + LABEL_PAD;
    final lh = label.height + techn.height;
    if (lh == 0) continue;

    // The label sits on the line, or just beside it when another relation runs the opposite way.
    final beside = r.nx.abs() * (lw / 2) + r.ny.abs() * (lh / 2) + 2;
    final aside = r.lean != 0
        ? math.max(0.0, math.min(r.lean, beside - 14))
        : beside;
    var dx = r.nx * aside + (tight ? 0.0 : offset(rel.offsetX));
    var dy = r.ny * aside + (tight ? 0.0 : offset(rel.offsetY));
    var at = 0.5;
    if (careful) {
      var least = double.infinity;
      final moved = dx != r.nx * aside || dy != r.ny * aside;
      for (var pass = 0; pass < (moved ? 2 : 1) && least > 0; pass++) {
        final px = pass != 0 ? r.nx * aside : dx;
        final py = pass != 0 ? r.ny * aside : dy;
        for (final t in _slide) {
          final cx = r.x0 + (r.x1 - r.x0) * t + px;
          final cy = r.y0 + (r.y1 - r.y0) * t + py;
          final area = covered(
            cx - lw / 2,
            cy - lh / 2,
            cx + lw / 2,
            cy + lh / 2,
          );
          if (area < least) {
            least = area;
            at = t;
            dx = px;
            dy = py;
          }
          if (area == 0) break;
        }
      }
    }
    final cx = r.x0 + (r.x1 - r.x0) * at + dx;
    final top = r.y0 + (r.y1 - r.y0) * at + dy - lh / 2;
    if (careful) {
      taken.addAll(<double>[cx - lw / 2, top, cx + lw / 2, top + lh]);
    }
    grow(cx - lw / 2, top, cx + lw / 2, top + lh);
    final descr = rel.descr;
    labelsOut +=
        '<g class="pele-edge-label" data-id="${escText(id)}">'
        '${descr != null && descr.isNotEmpty ? '<title>${escText(descr)}</title>' : ''}'
        '<rect x="${num(cx - lw / 2)}" y="${num(top)}" width="${num(lw)}" height="${num(lh)}" rx="3" fill="var(--_bg)"/>'
        '${_link(labelSvg(label, cx, top + label.height / 2, style.text) + labelSvg(techn, cx, top + label.height + techn.height / 2, ' class="pele-c4-techn" fill="var(--_m)"${style.text}'), rel.link, id, links, options)}'
        '</g>';
  }

  var clusters = '';
  var nodesOut = '';
  for (final group in order) {
    if (!identical(group, root)) {
      final boundary = group.boundary;
      final style = _userStyle(
        boundary.bgColor,
        boundary.borderColor,
        boundary.fontColor,
      );
      final x = group.x + group.headX;
      var y = group.y + HEAD_TOP;
      final color = _inkFill(style) + style.text;
      final muted = _inkFill(style, 'var(--_m)') + style.text;
      var text = leftLabelSvg(
        group.labels[0],
        x,
        y,
        ' class="pele-cluster-label" font-weight="var(--_hw)"$color',
      );
      y += group.labels[0].height;
      text += leftLabelSvg(
        group.labels[1],
        x,
        y,
        ' class="pele-c4-type" font-size="$smallInt"$muted',
      );
      y += group.labels[1].height;
      text += leftLabelSvg(
        group.labels[2],
        x,
        y,
        ' class="pele-c4-descr" font-size="$smallInt"$muted',
      );
      clusters +=
          '<g class="pele-cluster pele-c4-${boundary.nodeType != null && boundary.nodeType!.isNotEmpty ? 'node' : 'boundary'}" data-id="${escText(boundary.alias)}">'
          '<rect x="${num(group.x)}" y="${num(group.y)}" width="${num(group.w)}" height="${num(group.h)}" fill="none" stroke="var(--_b)"${boundary.nodeType != null && boundary.nodeType!.isNotEmpty ? '' : ' stroke-dasharray="6 4"'}${rounded(style.shape)}/>'
          '${_link(text, boundary.link, boundary.alias, links, options)}'
          '</g>';
    }
    for (final node in group.nodes) {
      final shape = node.shape;
      final external = shape.kind.startsWith('external');
      final style = _userStyle(
        shape.bgColor,
        shape.borderColor,
        shape.fontColor,
      );
      final stroke =
          ' stroke="var(--_b)"${external ? ' stroke-dasharray="4 3"' : ''}';
      final w = node.w;
      final h = node.h;
      final form = node.form;
      final labels = node.labels;
      final dx = form == 'h-cyl' ? -queueRx(h) / 2 : 0.0;
      final dy = form == 'person'
          ? HEAD / 2
          : form == 'cyl'
          ? cylRy(w) / 2
          : 0.0;
      final color = _inkFill(style) + style.text;
      final muted = _inkFill(style, 'var(--_m)') + style.text;
      var y = dy - node.textH / 2;
      var text = labelSvg(
        labels[0],
        dx,
        y + labels[0].height / 2,
        ' class="pele-c4-type" font-size="${smallInt - 1}"$muted',
      );
      y += labels[0].height;
      text += labelSvg(
        labels[1],
        dx,
        y + labels[1].height / 2,
        ' class="pele-label" font-weight="var(--_hw)"$color',
      );
      y += labels[1].height;
      text += labelSvg(
        labels[2],
        dx,
        y + labels[2].height / 2,
        ' class="pele-c4-techn" font-size="$smallInt"$muted',
      );
      y += labels[2].height + 4;
      text += labelSvg(
        labels[3],
        dx,
        y + labels[3].height / 2,
        ' class="pele-c4-descr" font-size="$smallInt"$color',
      );
      nodesOut +=
          '<g class="pele-node pele-shape-$form pele-c4-${shape.kind}${external ? ' pele-c4-external' : ''}" data-id="${escText(shape.alias)}" transform="translate(${num(node.x + w / 2)},${num(node.y + h / 2)})">'
          '${_link(drawShape(form, w, h, ' fill="var(${external ? '--_bg' : '--_s'})"$stroke${style.shape}', stroke + style.line) + text, shape.link, shape.alias, links, options)}'
          '</g>';
    }
  }

  final title = layoutLabel(
    db.title,
    false,
    measurer,
    size,
    tight ? titleRoom(options) : 4000,
    Style.Bold,
  );
  final titleHeight = title.height > 0 ? title.height + 12 : 0.0;
  final inner = math.max(maxX - minX, title.width);
  final width = (inner + 2 * pad).ceilToDouble();
  final height = (maxY - minY + titleHeight + 2 * pad).ceilToDouble();
  final ox = pad - minX + (inner - (maxX - minX)) / 2;
  final oy = pad + titleHeight - minY;

  final svg = svgDocument(
    'c4',
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
        '<g transform="translate(${num(ox)},${num(oy)})">'
            '${clusters.isNotEmpty ? '<g class="pele-clusters">$clusters</g>' : ''}'
            '${casingsSvg(casings)}'
            '${edgesOut.isNotEmpty ? '<g class="pele-edges" fill="none" stroke="var(--_l)" stroke-linecap="round">$edgesOut</g>' : ''}'
            '${nodesOut.isNotEmpty ? '<g class="pele-nodes">$nodesOut</g>' : ''}'
            '${labelsOut.isNotEmpty ? '<g class="pele-edge-labels" font-size="$smallInt">$labelsOut</g>' : ''}'
            '</g>',
  );
  return (
    Rendered(svg: svg, width: width, height: height, links: links),
    lanes.squeezed,
  );
}

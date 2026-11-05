// Upstream: src/diagrams/block/render.ts

import 'dart:math' as math;

import '../../preprocess.dart';
import '../../svg/builder.dart';
import '../../svg/edges.dart';
import '../../svg/ink.dart';
import '../../svg/root.dart';
import '../../svg/shapes.dart';
import '../../svg/theme.dart';
import '../../svg/title.dart';
import '../../text/label.dart';
import '../../text/measurer.dart';
import '../../types.dart';
import '../../util/math_js.dart';
import '../common/fit_width.dart';
import 'arrows.dart';
import 'layout.dart';
import 'types.dart';

const double _gap = 12;
const double _wrap = 200;
const double _corner = 8;
const String _shapeAttrs = ' fill="var(--_s)" stroke="var(--_b)"';
const String _lineAttrs = ' stroke="var(--_b)"';
const List<String> _noClasses = <String>[];
const List<Block> _noBlocks = <Block>[];
final List<double> _noHeights = <double>[];
final List<double> _noGaps = <double>[];
const List<String> _defaultClass = <String>['default'];
// Checking every edge against every block is quadratic, so large diagrams route without it.
const int _obstacleBudget = 2000000;
const double _labelGap = 4;

const Map<String, String> _shapes = <String, String>{
  'square': 'rect',
  'round': 'rounded',
  'circle': 'circle',
  'doublecircle': 'dbl-circ',
  'diamond': 'diam',
  'hexagon': 'hex',
  'stadium': 'stadium',
  'subroutine': 'fr-rect',
  'cylinder': 'cyl',
  'rect_left_inv_arrow': 'odd',
  'lean_right': 'lean-r',
  'lean_left': 'lean-l',
  'trapezoid': 'trap-b',
  'inv_trapezoid': 'trap-t',
};

// Shapes that keep their own size in a larger cell, where the others stretch to fill it.
const Set<String> _fixed = <String>{'circle', 'dbl-circ', 'diam'};
// Shapes that only widen, because their slants and curves are set by their height.
const Set<String> _wide = <String>{
  'stadium',
  'hex',
  'odd',
  'lean-r',
  'lean-l',
  'trap-b',
  'trap-t',
};

class _Kind {
  static const int Leaf = 0;
  static const int Arrow = 1;
  static const int Composite = 2;
  static const int Space = 3;
}

class _Box {
  double x;
  double y;
  double bw;
  double bh;

  _Box({required this.x, required this.y, required this.bw, required this.bh});
}

class _View extends Cell implements _Box {
  final Block block;
  final int kind;
  final int index;
  final String shape;
  final Label label;
  final ResolvedStyle style;
  final int mask;
  final double dx;
  double dy;
  // Size as drawn, which for a fixed shape is smaller than its cell.
  @override
  double bw = 0;
  @override
  double bh = 0;

  _View({
    required super.columns,
    required super.span,
    required super.space,
    required super.head,
    required super.nw,
    required super.nh,
    required super.heights,
    required super.rowGaps,
    required super.colGaps,
    required this.block,
    required this.kind,
    required this.index,
    required this.shape,
    required this.label,
    required this.style,
    required this.mask,
    required this.dx,
    required this.dy,
  }) : super(children: <_View>[]);
}

class _Route {
  final Block edge;
  // Two points for a straight line, three for a bend, none for a self-loop.
  final List<double> points;
  final int loop;
  final Label label;
  double lx;
  double ly;

  _Route({
    required this.edge,
    required this.points,
    required this.loop,
    required this.label,
    required this.lx,
    required this.ly,
  });
}

bool _isRound(_View v) {
  return v.kind == _Kind.Leaf && (v.shape == 'circle' || v.shape == 'dbl-circ');
}

// Where a vertical line at x meets the outline, below the center (sign 1) or above it (sign -1).
double _edgeY(_View v, double x, double sign) {
  final hw = v.bw / 2;
  final hh = v.bh / 2;
  final dx = (x - v.x).abs();
  var reach = hh;
  if (_isRound(v)) {
    reach = math.sqrt(math.max(hw * hw - dx * dx, 0.0));
  } else if (v.kind == _Kind.Leaf && v.shape == 'diam') {
    reach = hh * math.max(1 - dx / hw, 0.0);
  } else if (v.kind == _Kind.Leaf) {
    reach = hh - shapeInset(v.shape, v.bw, v.bh, sign > 0 ? 2 : 0);
  } else if (v.kind == _Kind.Arrow && arrowAxis(v.mask) == 'x') {
    reach = hh - OVERHANG;
  }
  return v.y + sign * reach;
}

// Where a horizontal line at y meets the outline, right of the center (sign 1) or left of it (sign -1).
double _edgeX(_View v, double y, double sign) {
  final hw = v.bw / 2;
  final hh = v.bh / 2;
  final dy = (y - v.y).abs();
  var reach = hw;
  if (_isRound(v)) {
    reach = math.sqrt(math.max(hh * hh - dy * dy, 0.0));
  } else if (v.kind == _Kind.Leaf && v.shape == 'diam') {
    reach = hw * math.max(1 - dy / hh, 0.0);
  } else if (v.kind == _Kind.Leaf) {
    reach = hw - shapeInset(v.shape, v.bw, v.bh, sign > 0 ? 1 : 3);
  } else if (v.kind == _Kind.Arrow && arrowAxis(v.mask) == 'y') {
    reach = hw - OVERHANG;
  }
  return v.x + sign * reach;
}

// Where the line from the center toward (tx, ty) leaves the outline.
void _border(_View v, double tx, double ty, List<double> out) {
  final dx = tx - v.x;
  final dy = ty - v.y;
  final hw = v.bw / 2;
  final hh = v.bh / 2;
  double k;
  if (_isRound(v)) {
    final len = hypot(dx, dy);
    k = hw / (len != 0 ? len : 1.0);
  } else if (v.kind == _Kind.Leaf && v.shape == 'diam') {
    final denom = dx.abs() / hw + dy.abs() / hh;
    k = 1 / (denom != 0 ? denom : 1.0);
  } else {
    k = math.min(
      dx == 0 ? double.infinity : hw / dx.abs(),
      dy == 0 ? double.infinity : hh / dy.abs(),
    );
  }
  if (k == double.infinity) k = 0;
  out.addAll(<double>[v.x + dx * k, v.y + dy * k]);
}

bool _crossesBox(double x1, double y1, double x2, double y2, _View v) {
  final l = v.x - v.bw / 2 + 1;
  final r = v.x + v.bw / 2 - 1;
  final t = v.y - v.bh / 2 + 1;
  final b = v.y + v.bh / 2 - 1;
  if ((x1 < l && x2 < l) ||
      (x1 > r && x2 > r) ||
      (y1 < t && y2 < t) ||
      (y1 > b && y2 > b)) {
    return false;
  }
  if (x1 == x2 || y1 == y2) return true;
  // The segment is diagonal and its bounding box overlaps: the box is hit unless all four corners are on one side.
  final dx = x2 - x1;
  final dy = y2 - y1;
  double side(double x, double y) => signJs(dx * (y - y1) - dy * (x - x1));
  final first = side(l, t);
  return first == 0 ||
      side(r, t) != first ||
      side(r, b) != first ||
      side(l, b) != first;
}

int _hits(List<double> points, _View s, _View t, List<_View> obstacles) {
  var count = 0;
  for (final v in obstacles) {
    if (identical(v, s) || identical(v, t)) continue;
    for (var i = 0; i + 3 < points.length; i += 2) {
      if (_crossesBox(
        points[i],
        points[i + 1],
        points[i + 2],
        points[i + 3],
        v,
      )) {
        count++;
        break;
      }
    }
  }
  return count;
}

// A straight line where the two blocks share a row or a column, otherwise one bend between facing sides.
List<double> _routeEdge(
  _View s,
  _View t,
  double shift,
  List<_View>? obstacles,
) {
  final sl = s.x - s.bw / 2;
  final sr = s.x + s.bw / 2;
  final st = s.y - s.bh / 2;
  final sb = s.y + s.bh / 2;
  final tl = t.x - t.bw / 2;
  final tr = t.x + t.bw / 2;
  final tt = t.y - t.bh / 2;
  final tb = t.y + t.bh / 2;
  final x1 = math.max(sl, tl);
  final x2 = math.min(sr, tr);
  final y1 = math.max(st, tt);
  final y2 = math.min(sb, tb);
  final overX = x2 - x1 > 6;
  final overY = y2 - y1 > 6;

  if (overX && overY) {
    // One block is inside the other: join the inner one to the nearest side of the outer one.
    final inner = s.bw * s.bh <= t.bw * t.bh ? s : t;
    final outer = identical(inner, s) ? t : s;
    final up = inner.y - inner.bh / 2 - (outer.y - outer.bh / 2);
    final down = outer.y + outer.bh / 2 - (inner.y + inner.bh / 2);
    final left = inner.x - inner.bw / 2 - (outer.x - outer.bw / 2);
    final right = outer.x + outer.bw / 2 - (inner.x + inner.bw / 2);
    final least = math.min(math.min(up, down), math.min(left, right));
    List<double> points;
    if (least == down) {
      points = <double>[
        inner.x,
        _edgeY(inner, inner.x, 1),
        inner.x,
        outer.y + outer.bh / 2,
      ];
    } else if (least == up) {
      points = <double>[
        inner.x,
        _edgeY(inner, inner.x, -1),
        inner.x,
        outer.y - outer.bh / 2,
      ];
    } else if (least == right) {
      points = <double>[
        _edgeX(inner, inner.y, 1),
        inner.y,
        outer.x + outer.bw / 2,
        inner.y,
      ];
    } else {
      points = <double>[
        _edgeX(inner, inner.y, -1),
        inner.y,
        outer.x - outer.bw / 2,
        inner.y,
      ];
    }
    return identical(inner, s)
        ? points
        : <double>[points[2], points[3], points[0], points[1]];
  }
  if (overX) {
    final margin = math.min(6.0, (x2 - x1) / 2);
    final x = math.min(
      math.max((x1 + x2) / 2 + shift, x1 + margin),
      x2 - margin,
    );
    final down = t.y > s.y ? 1.0 : -1.0;
    return <double>[x, _edgeY(s, x, down), x, _edgeY(t, x, -down)];
  }
  if (overY) {
    final margin = math.min(6.0, (y2 - y1) / 2);
    final y = math.min(
      math.max((y1 + y2) / 2 + shift, y1 + margin),
      y2 - margin,
    );
    final right = t.x > s.x ? 1.0 : -1.0;
    return <double>[_edgeX(s, y, right), y, _edgeX(t, y, -right), y];
  }

  final right = t.x > s.x ? 1.0 : -1.0;
  final down = t.y > s.y ? 1.0 : -1.0;
  final across = <double>[
    _edgeX(s, s.y, right),
    s.y,
    t.x,
    s.y,
    t.x,
    _edgeY(t, t.x, -down),
  ];
  final along = <double>[
    s.x,
    _edgeY(s, s.x, down),
    s.x,
    t.y,
    _edgeX(t, t.y, -right),
    t.y,
  ];
  final wide = (t.x - s.x).abs() >= (t.y - s.y).abs();
  var best = wide ? across : along;
  if (obstacles == null) return best;
  var least = _hits(best, s, t, obstacles);
  if (least == 0) return best;
  final other = wide ? along : across;
  final count = _hits(other, s, t, obstacles);
  if (count < least) {
    best = other;
    least = count;
  }
  if (least == 0) return best;
  final direct = <double>[];
  _border(s, t.x, t.y, direct);
  _border(t, s.x, s.y, direct);
  return _hits(direct, s, t, obstacles) < least ? direct : best;
}

// Builds the path through two or three points, rounding the bend and leaving room for markers.
EdgePath _trace(List<double> p, double startTrim, double endTrim) {
  final n = p.length;
  final sx = p[0];
  final sy = p[1];
  final ex = p[n - 2];
  final ey = p[n - 1];
  var ax = p[2] - sx;
  var ay = p[3] - sy;
  final first = hypot(ax, ay);
  ax /= first != 0 ? first : 1.0;
  ay /= first != 0 ? first : 1.0;
  var bx = ex - p[n - 4];
  var by = ey - p[n - 3];
  final last = hypot(bx, by);
  bx /= last != 0 ? last : 1.0;
  by /= last != 0 ? last : 1.0;
  if (n == 4 && startTrim + endTrim > first) {
    final scale = first / (startTrim + endTrim);
    startTrim *= scale;
    endTrim *= scale;
  }
  startTrim = math.min(startTrim, first);
  endTrim = math.min(endTrim, last);
  var d = 'M${num(sx + ax * startTrim)},${num(sy + ay * startTrim)}';
  if (n == 6) {
    final r = math.max(
      0.0,
      math.min(_corner, math.min(first - startTrim, last - endTrim)),
    );
    d +=
        'L${num(p[2] - ax * r)},${num(p[3] - ay * r)}Q${num(p[2])},${num(p[3])} ${num(p[2] + bx * r)},${num(p[3] + by * r)}';
  }
  d += 'L${num(ex - bx * endTrim)},${num(ey - by * endTrim)}';
  return EdgePath(
    d: d,
    sx: sx,
    sy: sy,
    sdx: -ax,
    sdy: -ay,
    ex: ex,
    ey: ey,
    edx: bx,
    edy: by,
  );
}

// A self-loop is an arc around the top right corner of the block, or around the matching point on a
// round or diamond outline. Gives the arc's center and radius and the angles where it leaves and returns.
(double, double, double, double, double) _loopArc(_View v, int k) {
  final hw = v.bw / 2;
  final hh = v.bh / 2;
  final r = math.max(1.0, math.min(10.0 + 5 * (k - 1), math.min(hw, hh)));
  if (_isRound(v)) {
    final px = v.x + hw * math.sqrt1_2;
    final py = v.y - hw * math.sqrt1_2;
    final half = 2 * math.asin(math.min(1.0, r / (2 * hw)));
    double angle(double at) =>
        math.atan2(v.y - hw * math.sin(at) - py, v.x + hw * math.cos(at) - px);
    return (px, py, r, angle(math.pi / 4 + half), angle(math.pi / 4 - half));
  }
  if (v.kind == _Kind.Leaf && v.shape == 'diam') {
    final slope = math.atan2(hh, hw);
    return (v.x + hw / 2, v.y - hh / 2, r, slope + math.pi, slope);
  }
  return (v.x + hw, v.y - hh, r, math.pi, math.pi / 2);
}

EdgePath _blockLoopPath(_View v, int k, double startTrim, double endTrim) {
  final (px, py, r, a1, a2) = _loopArc(v, k);
  final from = a1 + startTrim / r;
  final to = a2 - endTrim / r;
  var sweep = (to - from).remainder(2 * math.pi);
  if (sweep <= 0) sweep += 2 * math.pi;
  final x1 = px + r * math.cos(from);
  final y1 = py + r * math.sin(from);
  final x2 = px + r * math.cos(to);
  final y2 = py + r * math.sin(to);
  final sx = px + r * math.cos(a1);
  final sy = py + r * math.sin(a1);
  final ex = px + r * math.cos(a2);
  final ey = py + r * math.sin(a2);
  // Each marker lies along the chord it covers, so it follows the curve instead of the tangent at its tip.
  final sl = hypot(sx - x1, sy - y1);
  final el = hypot(ex - x2, ey - y2);
  return EdgePath(
    d: 'M${num(x1)},${num(y1)}A${num(r)},${num(r)} 0 ${sweep > math.pi ? 1 : 0} 1 ${num(x2)},${num(y2)}',
    sx: sx,
    sy: sy,
    sdx: sl > 0 ? (sx - x1) / sl : math.sin(a1),
    sdy: sl > 0 ? (sy - y1) / sl : -math.cos(a1),
    ex: ex,
    ey: ey,
    edx: el > 0 ? (ex - x2) / el : -math.sin(a2),
    edy: el > 0 ? (ey - y2) / el : math.cos(a2),
  );
}

const List<double> _spots = <double>[0.5, 0.3, 0.7, 0.15, 0.85];

bool _covers(
  double x,
  double y,
  double w,
  double h,
  _View s,
  _View t,
  List<_Box>? obstacles,
) {
  if (obstacles == null) return false;
  for (final v in obstacles) {
    if (!identical(v, s) &&
        !identical(v, t) &&
        (x - v.x).abs() < (w + v.bw) / 2 &&
        (y - v.y).abs() < (h + v.bh) / 2) {
      return true;
    }
  }
  return false;
}

// Picks the point on a leg where a label of the given size covers no block other than the two it joins.
double _labelSpot(
  List<double> p,
  int at,
  double w,
  double h,
  _View s,
  _View t,
  List<_View>? obstacles,
) {
  if (obstacles == null) return 0.5;
  for (final spot in _spots) {
    final x = p[at] + (p[at + 2] - p[at]) * spot;
    final y = p[at + 1] + (p[at + 3] - p[at + 1]) * spot;
    if (!_covers(x, y, w, h, s, t, obstacles)) return spot;
  }
  return 0.5;
}

// Stacks overlapping labels along their shared line, if they fit between its markers and cover no other block or title.
// Returns the extra length needed to fit the labels.
double _stackLabels(
  List<int> stack,
  List<_Route> routes,
  List<List<double>?> legs,
  _View s,
  _View t,
  List<_Box>? obstacles,
) {
  final firstLeg = legs[stack[0]]!;
  final vertical = firstLeg[0] == firstLeg[2];
  var lo = double.negativeInfinity;
  var hi = double.infinity;
  var need = -_labelGap;
  var crowded = false;
  for (var a = 0; a < stack.length; a++) {
    final leg = legs[stack[a]]!;
    if (vertical ? leg[0] != leg[2] : leg[1] != leg[3]) return 0;
    lo = math.max(
      lo,
      vertical ? math.min(leg[1], leg[3]) : math.min(leg[0], leg[2]),
    );
    hi = math.min(
      hi,
      vertical ? math.max(leg[1], leg[3]) : math.max(leg[0], leg[2]),
    );
    final p = routes[stack[a]];
    need += (vertical ? p.label.height : p.label.width + 8) + _labelGap;
    for (var b = 0; b < a; b++) {
      final q = routes[stack[b]];
      if ((p.lx - q.lx).abs() < (p.label.width + q.label.width) / 2 + 8 &&
          (p.ly - q.ly).abs() < (p.label.height + q.label.height) / 2) {
        crowded = true;
      }
    }
  }
  if (!crowded) return 0;
  if (need > hi - lo - 2 * ARROW) return need - (hi - lo - 2 * ARROW);
  final along = <double>[];
  var next = (lo + hi - need) / 2;
  for (final i in stack) {
    final r = routes[i];
    final label = r.label;
    final lx = r.lx;
    final ly = r.ly;
    final size = vertical ? label.height : label.width + 8;
    final at = next + size / 2;
    if (_covers(
      vertical ? lx : at,
      vertical ? at : ly,
      label.width + 8,
      label.height,
      s,
      t,
      obstacles,
    )) {
      return 0;
    }
    along.add(at);
    next += size + _labelGap;
  }
  for (var k = 0; k < stack.length; k++) {
    final i = stack[k];
    if (vertical) {
      routes[i].ly = along[k];
    } else {
      routes[i].lx = along[k];
    }
  }
  return 0;
}

// Widens the gap in the blocks' nearest shared container.
// `base` keeps the gaps as they were when the labels were measured.
bool _widen(
  List<_View?> parents,
  _View s,
  _View t,
  bool vertical,
  double short,
  Map<List<double>, List<double>> base,
) {
  final chain = Set<_View>.identity();
  for (_View? v = s; v != null; v = parents[v.index]) {
    chain.add(v);
  }
  _View? tb;
  _View? box = t;
  while (box != null && !chain.contains(box)) {
    tb = box;
    box = parents[box.index];
  }
  if (box == null || tb == null || identical(box, s)) return false;
  var sb = s;
  while (!identical(parents[sb.index], box)) {
    sb = parents[sb.index]!;
  }
  int at;
  if (vertical) {
    if (sb.row == tb.row) return false;
    at = math.max<int>(sb.row, tb.row) - 1;
    if (identical(box.rowGaps, _noGaps)) box.rowGaps = <double>[];
  } else {
    final l = sb.col < tb.col ? sb : tb;
    final r = sb.col < tb.col ? tb : sb;
    if (r.col < l.col + l.span) return false;
    at = r.col - 1;
    if (identical(box.colGaps, _noGaps)) box.colGaps = <double>[];
  }
  final gaps = vertical ? box.rowGaps : box.colGaps;
  if (!base.containsKey(gaps)) base[gaps] = List<double>.of(gaps);
  final baseGaps = base[gaps]!;
  final baseVal = at < baseGaps.length ? baseGaps[at] : 0.0;
  while (gaps.length <= at) {
    gaps.add(0);
  }
  gaps[at] = math.max(gaps[at], baseVal + short);
  return true;
}

Rendered renderBlock(BlockModel model, Config config, RenderOptions options) {
  return tighten(options, (tight) => _draw(model, config, options, tight));
}

Rendered _draw(
  BlockModel model,
  Config config,
  RenderOptions options,
  bool tight,
) {
  final size = options.fontSize ?? 16;
  final edgeSize = roundJs(size * 0.875).toDouble();
  final measurer =
      options.measurer ??
      defaultMeasurer(options.fontFamily, options.fontFamilyMono);
  final pad = options.padding ?? 8;
  final icons = options.icons;
  final blockConf = config['block'];
  final configuredVal = blockConf is Map ? blockConf['padding'] : null;
  final double? configured = configuredVal is int
      ? configuredVal.toDouble()
      : (configuredVal is double ? configuredVal : null);
  final gap = math.min(
    configured != null && configured >= 0 ? math.min(configured, 200.0) : _gap,
    tight ? 6.0 : double.infinity,
  );
  final wrap = tight ? 80.0 : _wrap;

  ResolvedStyle styleOf(Block block) {
    final declarations = <String>[];
    // A style list is split on commas only, so one entry can still hold several declarations.
    void add(List<String> styles) {
      for (final style in styles) {
        for (final part in style.split(';')) {
          declarations.add(part);
        }
      }
    }

    final clsList = (block.classes != null && block.classes!.isNotEmpty)
        ? block.classes!
        : _defaultClass;
    for (final name in clsList) {
      final def = model.classes[name];
      if (def != null) add(def.styles);
    }
    if (block.styles != null) add(block.styles!);
    return resolveStyle(declarations);
  }

  _View makeView(Block block, int index) {
    final type = block.type;
    final style = type == 'space' ? resolveStyle(_noClasses) : styleOf(block);
    final tStyle =
        (style.bold ? Style.Bold : 0) | (style.italic ? Style.Italic : 0);
    final fontSize = style.fontSize ?? size;
    var kind = _Kind.Leaf;
    var shape = '';
    Label label;
    var nw = 0.0;
    var nh = 0.0;
    var head = 0.0;
    var mask = 0;
    var dx = 0.0;
    var dy = 0.0;
    if (type == 'space') {
      kind = _Kind.Space;
      label = layoutLabel(null, false, measurer, fontSize, wrap);
    } else if (type == 'composite') {
      kind = _Kind.Composite;
      label = layoutLabel(
        block.label,
        false,
        measurer,
        fontSize,
        tight ? titleRoom(options) : 4000,
        tStyle,
      );
      head = label.height > 0 ? label.height + 4 : 0;
      nw = label.width + 2 * gap;
      nh = head + 2 * gap;
    } else if (type == 'block_arrow') {
      kind = _Kind.Arrow;
      label = layoutLabel(block.label, false, measurer, fontSize, wrap, tStyle);
      var blank = true;
      for (final line in label.lines) {
        for (final part in line) {
          if (part.icon != null || part.text.trim().isNotEmpty) blank = false;
        }
      }
      mask = arrowMask(block.directions);
      final s = blank
          ? arrowSize(mask, 0, 0)
          : arrowSize(mask, label.width, label.height);
      nw = s.w;
      nh = s.h;
      dx = s.dx;
      dy = s.dy;
    } else {
      shape = _shapes[type ?? ''] ?? 'rect';
      label = layoutLabel(block.label, false, measurer, fontSize, wrap, tStyle);
      final s = shapeSize(shape, label.width, label.height);
      nw = s.w;
      // A cylinder's caps deepen as it widens, so it is sized for the deepest ones.
      nh = shape == 'cyl' ? math.max(s.h, label.height + 40) : s.h;
      dy = s.dy;
    }
    return _View(
      columns: kind == _Kind.Composite ? (block.columns ?? -1) : -1,
      span: kind == _Kind.Space ? 1 : (block.widthInColumns ?? 1),
      space: kind == _Kind.Space,
      head: head,
      nw: nw,
      nh: nh,
      heights: _noHeights,
      rowGaps: _noGaps,
      colGaps: _noGaps,
      block: block,
      kind: kind,
      index: index,
      shape: shape,
      label: label,
      style: style,
      mask: mask,
      dx: dx,
      dy: dy,
    );
  }

  final root = makeView(model.root, 0);
  root.nw = 0;
  root.nh = 0;
  final order = <_View>[root];
  final parents = <_View?>[null];
  final byId = <String, _View>{};
  for (var i = 0; i < order.length; i++) {
    final parent = order[i];
    if (parent.kind != _Kind.Composite) continue;
    final children = parent.block.children != null
        ? parent.block.blockChildren
        : _noBlocks;
    for (final child in children) {
      final v = makeView(child, order.length);
      parent.children.add(v);
      parents.add(parent);
      order.add(v);
      if (v.kind != _Kind.Space) byId[child.id] = v;
    }
  }

  final obstacles = <_View>[];
  final titles = <_Box>[];
  // Layout keeps the widest a container has been, so each run starts from the widths it needs.
  final widths = order.map((v) => v.nw).toList();
  ({double width, double height}) place() {
    for (final v in order) {
      v.nw = widths[v.index];
    }
    final content = layout(root, gap);
    obstacles.clear();
    titles.clear();
    for (final v in order) {
      if (v.kind == _Kind.Leaf && _fixed.contains(v.shape)) {
        v.bw = v.nw;
        v.bh = v.nh;
      } else if (v.kind == _Kind.Arrow) {
        v.bw = v.span > 1 ? v.w : v.nw;
        v.bh = v.nh;
      } else {
        v.bw = v.w;
        v.bh = v.kind == _Kind.Leaf && _wide.contains(v.shape) ? v.nh : v.h;
      }
      if (v.kind == _Kind.Leaf && v.shape == 'cyl') {
        v.dy = math.min(12.0, math.max(6.0, v.bw / 14)) / 2;
      }
      if (v.kind == _Kind.Leaf || v.kind == _Kind.Arrow) {
        obstacles.add(v);
      } else if (v.head > 0) {
        titles.add(
          _Box(
            x: v.x,
            y: v.y - v.h / 2 + (v.head + gap) / 2 + 2,
            bw: v.label.width,
            bh: v.label.height,
          ),
        );
      }
    }
    return content;
  }

  var content = place();

  // Edges between the same two blocks are spread apart instead of drawn on top of each other.
  final pairs = <int, int>{};
  final labelled = <int>{};
  final ends = <(_View, _View)>[];
  final drawn = <Block>[];
  for (final edge in model.edges) {
    final s = byId[edge.start ?? ''];
    final t = byId[edge.end ?? ''];
    if (s == null || t == null) continue;
    final key =
        math.min<int>(s.index, t.index) * order.length +
        math.max<int>(s.index, t.index);
    pairs[key] = (pairs[key] ?? 0) + 1;
    if (edge.label != null && edge.label!.isNotEmpty) labelled.add(key);
    ends.add((s, t));
    drawn.add(edge);
  }
  final check = drawn.length * obstacles.length <= _obstacleBudget
      ? obstacles
      : null;
  final routes = <_Route>[];
  final stacks = <int, List<int>>{};
  final legs = List<List<double>?>.filled(drawn.length, null);
  void route() {
    final seen = <int, int>{};
    routes.clear();
    stacks.clear();
    for (var i = 0; i < drawn.length; i++) {
      final (s, t) = ends[i];
      final key =
          math.min<int>(s.index, t.index) * order.length +
          math.max<int>(s.index, t.index);
      final total = pairs[key] ?? 1;
      final k = seen[key] ?? 0;
      seen[key] = k + 1;
      final label = layoutLabel(
        drawn[i].label,
        false,
        measurer,
        edgeSize,
        _wrap,
      );
      List<double> points;
      double lx;
      double ly;
      if (identical(s, t)) {
        final (px, py, r, _, _) = _loopArc(s, k + 1);
        points = <double>[];
        lx = px + r + 6 + label.width / 2;
        ly = py - r / 2;
      } else {
        final step = labelled.contains(key)
            ? roundJs(edgeSize * 1.5).toDouble() + 2
            : 14.0;
        points = _routeEdge(s, t, (k - (total - 1) / 2) * step, check);
        final n = points.length;
        // The label goes on the longer leg.
        final firstLeg =
            (points[2] - points[0]).abs() + (points[3] - points[1]).abs();
        final lastLeg =
            (points[n - 2] - points[n - 4]).abs() +
            (points[n - 1] - points[n - 3]).abs();
        final at = n == 6 && lastLeg > firstLeg ? 2 : 0;
        final spot = label.width > 0
            ? _labelSpot(points, at, label.width + 8, label.height, s, t, check)
            : 0.5;
        lx = points[at] + (points[at + 2] - points[at]) * spot;
        ly = points[at + 1] + (points[at + 3] - points[at + 1]) * spot;
        if (label.width > 0 && total > 1) {
          legs[i] = points.sublist(at, at + 4);
          final stack = stacks[key];
          if (stack != null) {
            stack.add(i);
          } else {
            stacks[key] = <int>[i];
          }
        }
      }
      routes.add(
        _Route(
          edge: drawn[i],
          points: points,
          loop: identical(s, t) ? k + 1 : 0,
          label: label,
          lx: lx,
          ly: ly,
        ),
      );
    }
  }

  bool settle(bool grow) {
    route();
    final blocked = check != null ? <_Box>[...check, ...titles] : null;
    final base = Map<List<double>, List<double>>.identity();
    var grown = false;
    for (final stack in stacks.values) {
      if (stack.length < 2) continue;
      final (s, t) = ends[stack[0]];
      final short = _stackLabels(stack, routes, legs, s, t, blocked);
      final leg0 = legs[stack[0]]!;
      final vertical = leg0[0] == leg0[2];
      // Keep columns narrow to fit the host in tight layouts.
      if (grow &&
          short > 0 &&
          (vertical || !tight) &&
          _widen(parents, s, t, vertical, short.ceilToDouble(), base)) {
        grown = true;
      }
    }
    return grown;
  }

  double overlap() {
    var area = 0.0;
    for (var i = 0; i < routes.length; i++) {
      final p = routes[i];
      for (var j = i + 1; j < routes.length; j++) {
        final q = routes[j];
        final pw = (p.label.width + 8) / 2;
        final qw = (q.label.width + 8) / 2;
        final w =
            math.min(p.lx + pw, q.lx + qw) - math.max(p.lx - pw, q.lx - qw);
        final h =
            math.min(p.ly + p.label.height / 2, q.ly + q.label.height / 2) -
            math.max(p.ly - p.label.height / 2, q.ly - q.label.height / 2);
        if (p.label.width > 0 && q.label.width > 0 && w > 0 && h > 0) {
          area += w * h;
        }
      }
    }
    return area;
  }

  var minX = 0.0;
  var minY = 0.0;
  var maxX = 0.0;
  var maxY = 0.0;
  void grow(double x, double y, double w, double h) {
    if (x - w / 2 < minX) minX = x - w / 2;
    if (x + w / 2 > maxX) maxX = x + w / 2;
    if (y - h / 2 < minY) minY = y - h / 2;
    if (y + h / 2 > maxY) maxY = y + h / 2;
  }

  // Finds the drawing's extent and gives its width.
  double bound() {
    minX = 0;
    minY = 0;
    maxX = content.width;
    maxY = content.height;
    for (var i = 0; i < routes.length; i++) {
      final r = routes[i];
      if (r.loop > 0) {
        final (px, py, rad, _, _) = _loopArc(ends[i].$1, r.loop);
        grow(px, py, 2 * rad + 2, 2 * rad + 2);
      }
      if (r.label.width > 0) {
        grow(r.lx, r.ly, r.label.width + 8, r.label.height);
      }
    }
    return maxX - minX;
  }

  if (settle(drawn.length * drawn.length <= _obstacleBudget)) {
    final before = overlap();
    final narrow = bound();
    // A container stretched by its row gives some of a new gap back, so the gap may take a few rounds.
    var grown = true;
    for (var round = 0; round < 3 && grown; round++) {
      content = place();
      grown = settle(round < 2);
    }
    // The drawing only grows if that leaves less of the labels covering each other, and within maxWidth.
    final wide = bound();
    final room = options.maxWidth != null && options.maxWidth! > 0
        ? options.maxWidth!
        : double.infinity;
    if (overlap() > before - 1 ||
        (wide > narrow && (wide + 2 * pad).ceilToDouble() > room)) {
      for (final v in order) {
        v.rowGaps = _noGaps;
        v.colGaps = _noGaps;
      }
      content = place();
      settle(false);
    }
  }

  bound();

  final title = titleLabel(
    model.title,
    measurer,
    size,
    tight ? titleRoom(options) : 4000,
  );
  final titleHeight = title.height > 0 ? title.height + 12 : 0.0;
  final inner = math.max(maxX - minX, title.width);
  final ox = pad - minX + (inner - (maxX - minX)) / 2;
  final oy = pad + titleHeight - minY;
  for (final v in order) {
    v.x += ox;
    v.y += oy;
  }
  final width = (inner + 2 * pad).ceilToDouble();
  final height = (maxY - minY + titleHeight + 2 * pad).ceilToDouble();

  final clusters = StringBuffer();
  final nodes = StringBuffer();
  final fills = <Fill>[];
  for (var i = 1; i < order.length; i++) {
    final v = order[i];
    if (v.kind == _Kind.Space) continue;
    final classes = classNames((v.block.classes ?? _noClasses).join(' '));
    final id = escText(v.block.id);
    if (v.kind == _Kind.Composite) {
      final top = v.y - v.h / 2;
      if (paints(v.style.shape)) {
        fills.add(
          Fill(
            box: <double>[v.x - v.w / 2, top, v.x + v.w / 2, top + v.h],
            shape: v.style.shape,
          ),
        );
      }
      clusters
        ..write('<g class="pele-cluster$classes" data-id="$id">')
        ..write(
          '<rect x="${num(v.x - v.w / 2)}" y="${num(top)}" width="${num(v.w)}" height="${num(v.h)}" fill="var(--_a)"${setsFill(v.style.shape) ? '' : ' fill-opacity="0.5"'} stroke="var(--_b)"${rounded(v.style.shape)}/>',
        )
        ..write(
          labelSvg(
            v.label,
            v.x,
            top + (v.head + gap) / 2 + 2,
            ' class="pele-cluster-label"${inkFill((shape: v.style.shape, text: v.style.text), 'var(--_m)')}${v.style.text}',
            icons,
          ),
        )
        ..write('</g>');
      continue;
    }
    final arrow = v.kind == _Kind.Arrow;
    var label = v.label;
    // Reuse a wider cell without changing the node size or the routes computed from it.
    if (v.span > 1 &&
        v.label.width > 0 &&
        v.label.lines.length > 1 &&
        v.bw > v.nw &&
        (arrow || !_fixed.contains(v.shape))) {
      final tStyle =
          (v.style.bold ? Style.Bold : 0) | (v.style.italic ? Style.Italic : 0);
      final room = v.label.width + (v.bw - v.nw);
      label = layoutLabel(
        v.block.label,
        false,
        measurer,
        v.label.size,
        room,
        tStyle,
      );
    }
    nodes
      ..write(
        '<g class="pele-node pele-shape-${arrow ? 'block-arrow' : v.shape}$classes" data-id="$id" transform="translate(${num(v.x)},${num(v.y)})">',
      )
      ..write(
        arrow
            ? drawArrow(v.mask, v.bw, v.bh, _shapeAttrs + v.style.shape)
            : drawShape(
                v.shape,
                v.bw,
                v.bh,
                _shapeAttrs + v.style.shape,
                _lineAttrs + v.style.line,
              ),
      )
      ..write(
        labelSvg(
          label,
          v.dx,
          v.dy,
          ' class="pele-label"${arrow || shapeFilled(v.shape) ? inkFill((shape: v.style.shape, text: v.style.text)) : ''}${v.style.text}',
          icons,
        ),
      )
      ..write('</g>');
  }

  final casings = StringBuffer();
  final edges = StringBuffer();
  final labels = StringBuffer();
  for (var i = 0; i < routes.length; i++) {
    final r = routes[i];
    final edge = r.edge;
    final points = r.points;
    final loop = r.loop;
    final label = r.label;
    final startType = edge.arrowTypeStart ?? '';
    final endType = edge.arrowTypeEnd ?? '';
    EdgePath path;
    if (loop > 0) {
      path = _blockLoopPath(
        ends[i].$1,
        loop,
        markerTrim(startType),
        markerTrim(endType),
      );
    } else {
      for (var k = 0; k < points.length; k += 2) {
        points[k] += ox;
        points[k + 1] += oy;
      }
      path = _trace(points, markerTrim(startType), markerTrim(endType));
    }
    final over = overFills(path.d, <double>[
      path.sx,
      path.sy,
      path.ex,
      path.ey,
    ], fills);
    if (over == '') {
      casings.write(
        edgeCasing(path, startType, endType, '', edge.thickness == 'thick'),
      );
    }
    final id = escText(edge.id);
    final markerColor = (over != null && over.isNotEmpty) ? over : 'var(--_l)';
    edges
      ..write(
        '<g class="pele-edge" data-id="$id"${over != null && over.isNotEmpty ? ' stroke="$over"' : ''}>',
      )
      ..write(
        '<path d="${path.d}"${edge.thickness == 'thick' ? ' stroke-width="2.5"' : ''}${edge.pattern == 'dotted' ? ' stroke-dasharray="3 4"' : ''}/>',
      )
      ..write(
        marker(startType, path.sx, path.sy, path.sdx, path.sdy, markerColor),
      )
      ..write(
        marker(endType, path.ex, path.ey, path.edx, path.edy, markerColor),
      )
      ..write('</g>');
    if (label.width > 0) {
      final x = r.lx + ox;
      final y = r.ly + oy;
      labels.write(edgeLabelSvg(edge.id, label, x, y, '', icons));
    }
  }

  final clustersStr = clusters.toString();
  final edgesStr = edges.toString();
  final labelsStr = labels.toString();
  final svg = svgDocument(
    'block',
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
        '<g class="pele-nodes">$nodes</g>' +
        (labelsStr.isNotEmpty
            ? '<g class="pele-edge-labels" font-size="${num(edgeSize)}">$labelsStr</g>'
            : ''),
  );

  return Rendered(svg: svg, width: width, height: height, links: <LinkInfo>[]);
}

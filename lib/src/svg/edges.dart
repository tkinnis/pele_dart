// Upstream: src/svg/edges.ts

import 'dart:math' as math;

import '../layout/layered.dart';
import '../text/label.dart';
import '../util/math_js.dart';
import 'builder.dart';
import 'ink.dart';

const double ARROW = 8;

class EdgePath {
  final String d;
  final List<double>? tokens;
  final double sx;
  final double sy;
  final double sdx;
  final double sdy;
  final double ex;
  final double ey;
  final double edx;
  final double edy;

  const EdgePath({
    required this.d,
    this.tokens,
    required this.sx,
    required this.sy,
    required this.sdx,
    required this.sdy,
    required this.ex,
    required this.ey,
    required this.edx,
    required this.edy,
  });
}

const double _corner = 12;
const double _handle = 0.62;
const double LEAD = 6;

class SideReach {
  final Map<int, double> _reach = <int, double>{};

  void add(int node, int side, String type) {
    final trim = markerTrim(type);
    if (side >= 0 && trim > 0 && trim + LEAD > (_reach[node * 4 + side] ?? 0)) {
      _reach[node * 4 + side] = trim + LEAD;
    }
  }

  double of(int node, int side) =>
      side >= 0 ? (_reach[node * 4 + side] ?? 0) : 0;
}

SideReach sideReach() => SideReach();

EdgePath routePath(
  List<double> route,
  String? curve,
  double startTrim,
  double endTrim, [
  double? startReachArg,
  double? endReachArg,
]) {
  final startReach = startReachArg ?? (startTrim > 0 ? startTrim + LEAD : 0);
  final endReach = endReachArg ?? (endTrim > 0 ? endTrim + LEAD : 0);
  final linear = curve == 'linear';
  final stepped =
      curve == 'step' || curve == 'stepBefore' || curve == 'stepAfter';
  final xs = <double>[];
  final ys = <double>[];
  final axes = <double>[];
  bool near(double ax, double ay, double bx, double by) =>
      (ax - bx).abs() < 0.01 && (ay - by).abs() < 0.01;
  for (var i = 0; i < route.length; i += 3) {
    final x = route[i];
    final y = route[i + 1];
    final axis = route[i + 2];
    final last = xs.length - 1;
    if (stepped &&
        last >= 0 &&
        (x - xs[last]).abs() >= 0.01 &&
        (y - ys[last]).abs() >= 0.01) {
      final px = xs[last];
      final py = ys[last];
      final my = curve == 'stepBefore'
          ? py
          : curve == 'stepAfter'
          ? y
          : (py + y) / 2;
      final mx = curve == 'stepBefore'
          ? px
          : curve == 'stepAfter'
          ? x
          : (px + x) / 2;
      final turns = axis == 0
          ? <double>[px, my, x, my]
          : <double>[mx, py, mx, y];
      for (var k = 0; k < 4; k += 2) {
        if (near(turns[k], turns[k + 1], px, py) ||
            near(turns[k], turns[k + 1], x, y)) {
          continue;
        }
        xs.add(turns[k]);
        ys.add(turns[k + 1]);
        axes.add(axis);
      }
    }
    xs.add(x);
    ys.add(y);
    axes.add(axis);
  }
  var last = xs.length - 1;
  bool aligned(int i) =>
      (xs[i] - xs[i - 1]).abs() < 0.01 || (ys[i] - ys[i - 1]).abs() < 0.01;
  bool straight(int i) => linear || aligned(i);
  (double, double) unit(int i, int j, double axis) {
    if (!straight(math.max(i, j))) {
      if (axis == 0) {
        final s = signJs(ys[j] - ys[i]);
        return (0.0, s != 0 ? s : 1.0);
      } else {
        final s = signJs(xs[j] - xs[i]);
        return (s != 0 ? s : 1.0, 0.0);
      }
    }
    final dx = xs[j] - xs[i];
    final dy = ys[j] - ys[i];
    final len = hypot(dx, dy);
    final d = len != 0 ? len : 1.0;
    return (dx / d, dy / d);
  }

  final (sdx, sdy) = unit(0, 1, axes[1]);
  final (edx, edy) = unit(last - 1, last, axes[last]);
  final sx = xs[0];
  final sy = ys[0];
  final ex = xs[last];
  final ey = ys[last];
  xs[0] += sdx * startTrim;
  ys[0] += sdy * startTrim;
  xs[last] -= edx * endTrim;
  ys[last] -= edy * endTrim;
  double length(int i) => (xs[i] - xs[i - 1]).abs() + (ys[i] - ys[i - 1]).abs();
  bool turns(int i) =>
      !linear &&
      i > 0 &&
      i < last &&
      aligned(i) &&
      aligned(i + 1) &&
      length(i) >= 0.01 &&
      length(i + 1) >= 0.01 &&
      ((xs[i] - xs[i - 1]).abs() < 0.01) != ((xs[i + 1] - xs[i]).abs() < 0.01);
  double along(int i, double ux, double uy) =>
      (xs[i] - xs[i - 1]).abs() * ux.abs() +
      (ys[i] - ys[i - 1]).abs() * uy.abs();
  double lead(double reach, double trim, double run) {
    final room = math.min(math.max(0.0, reach - LEAD - trim), run / 4);
    return room + math.min(reach - trim - room, (run - room) / 4);
  }

  final arrives = endReach > endTrim && (!straight(last) || turns(last - 1))
      ? lead(endReach, endTrim, along(last, edx, edy))
      : 0.0;
  final leaves = startReach > startTrim && (!straight(1) || turns(1))
      ? lead(startReach, startTrim, along(1, sdx, sdy))
      : 0.0;
  if (arrives >= 1) {
    xs.insert(last, xs[last] - edx * arrives);
    ys.insert(last, ys[last] - edy * arrives);
    axes.insert(last, axes[last]);
    last++;
  }
  if (leaves >= 1) {
    xs.insert(1, xs[0] + sdx * leaves);
    ys.insert(1, ys[0] + sdy * leaves);
    axes.insert(1, axes[1]);
    last++;
  }

  final tokens = <double>[];
  String tok(double v) {
    tokens.add(_written(v));
    return num(v);
  }

  tokens.addAll(<double>[77, 2]);
  var d = 'M${tok(xs[0])},${tok(ys[0])}';
  var atX = xs[0];
  var atY = ys[0];
  void lineTo(double x, double y) {
    if (near(x, y, atX, atY)) return;
    tokens.addAll(<double>[76, 2]);
    d += 'L${tok(x)},${tok(y)}';
    atX = x;
    atY = y;
  }

  for (var i = 1; i <= last; i++) {
    final x = xs[i];
    final y = ys[i];
    if (!straight(i)) {
      final down = axes[i] == 0;
      final alongDist = down ? y - atY : x - atX;
      final k = alongDist.abs() * ease(down ? x - atX : y - atY, alongDist);
      final ux = down ? 0.0 : signJs(alongDist) * k;
      final uy = down ? signJs(alongDist) * k : 0.0;
      tokens.addAll(<double>[67, 6]);
      d +=
          'C${tok(atX + ux)},${tok(atY + uy)} ${tok(x - ux)},${tok(y - uy)} ${tok(x)},${tok(y)}';
      atX = x;
      atY = y;
      continue;
    }
    if (!turns(i)) {
      if (i < last &&
          aligned(i) &&
          aligned(i + 1) &&
          (x - xs[i - 1]) * (xs[i + 1] - x) +
                  (y - ys[i - 1]) * (ys[i + 1] - y) >
              0) {
        continue;
      }
      lineTo(x, y);
      continue;
    }
    var before = turns(i - 1) ? length(i) / 2 : length(i);
    var after = turns(i + 1) ? length(i + 1) / 2 : length(i + 1);
    if (stepped) {
      before = after = math.min(_corner, math.min(before, after));
    }
    final (ux, uy) = unit(i - 1, i, axes[i]);
    final (vx, vy) = unit(i, i + 1, axes[i + 1]);
    lineTo(x - ux * before, y - uy * before);
    atX = x + vx * after;
    atY = y + vy * after;
    if (stepped) {
      tokens.addAll(<double>[81, 4]);
      d += 'Q${tok(x)},${tok(y)} ${tok(atX)},${tok(atY)}';
    } else {
      tokens.addAll(<double>[67, 6]);
      d +=
          'C${tok(x - ux * before * (1 - _handle))},${tok(y - uy * before * (1 - _handle))} ${tok(x + vx * after * (1 - _handle))},${tok(y + vy * after * (1 - _handle))} ${tok(atX)},${tok(atY)}';
    }
  }
  return EdgePath(
    d: d,
    tokens: tokens,
    sx: sx,
    sy: sy,
    sdx: -sdx,
    sdy: -sdy,
    ex: ex,
    ey: ey,
    edx: edx,
    edy: edy,
  );
}

double markerTrim(String type) {
  return type == 'arrow_point'
      ? ARROW - 1
      : type == 'arrow_circle'
      ? ARROW
      : type == 'arrow_cross'
      ? 4
      : 0;
}

String marker(
  String type,
  double x,
  double y,
  double dx,
  double dy,
  String color, [
  String stroke = 'none',
]) {
  final nx = -dy;
  final ny = dx;
  if (type == 'arrow_point') {
    final bx = x - dx * ARROW;
    final by = y - dy * ARROW;
    const half = ARROW * 0.42;
    return '<path class="pele-marker" d="M${num(x)},${num(y)}L${num(bx + nx * half)},${num(by + ny * half)}L${num(bx - nx * half)},${num(by - ny * half)}Z" fill="$color" stroke="$stroke"/>';
  }
  if (type == 'arrow_circle') {
    return '<circle class="pele-marker" cx="${num(x - dx * 4)}" cy="${num(y - dy * 4)}" r="3.5" fill="$color" stroke="$stroke"/>';
  }
  if (type == 'arrow_cross') {
    final cx = x - dx * 4;
    final cy = y - dy * 4;
    const a = 3.5;
    final ux = (dx + nx) * a;
    final uy = (dy + ny) * a;
    final vx = (dx - nx) * a;
    final vy = (dy - ny) * a;
    return '<path class="pele-marker" d="M${num(cx - ux)},${num(cy - uy)}L${num(cx + ux)},${num(cy + uy)}M${num(cx - vx)},${num(cy - vy)}L${num(cx + vx)},${num(cy + vy)}"/>';
  }
  return '';
}

final List<double> _tens = List<double>.generate(
  23,
  (i) => double.parse('1e$i'),
);

List<double> _pathPoints(String d) {
  return _sample(_tokenize(d));
}

List<double> _tokenize(String d) {
  final out = <double>[];
  var at = -1;
  for (var i = 0; i < d.length;) {
    final c = charCodeAt(d, i);
    if (c >= 65 && c <= 90 && c != 69) {
      at = out.length + 1;
      out.addAll(<double>[c.toDouble(), 0]);
      i++;
    } else if (c == 45 || c == 46 || (c >= 48 && c <= 57)) {
      var j = c == 45 ? i + 1 : i;
      var m = 0.0;
      var places = -1;
      for (
        var k = charCodeAt(d, j);
        (k >= 48 && k <= 57) || (k == 46 && places < 0);
        k = charCodeAt(d, ++j)
      ) {
        if (k == 46) {
          places = 0;
        } else {
          m = m * 10 + (k - 48);
          if (places >= 0) places++;
        }
      }
      double v;
      if ((charCodeAt(d, j) | 32) == 101 ||
          m > 9007199254740991 ||
          places > 22) {
        for (
          var k = charCodeAt(d, j);
          k == 46 ||
              k == 101 ||
              k == 69 ||
              (k >= 48 && k <= 57) ||
              ((k == 45 || k == 43) && (charCodeAt(d, j - 1) | 32) == 101);
          k = charCodeAt(d, ++j)
        ) {}
        v = double.tryParse(d.substring(i, j)) ?? double.nan;
      } else {
        v = places > 0 ? m / _tens[places] : m;
        if (c == 45) v = -v;
      }
      if (at >= 0) {
        out.add(v);
        out[at]++;
      }
      i = j;
    } else {
      i++;
    }
  }
  return out;
}

double _written(double v) {
  final n = roundJs(v * 100);
  return n == 0 ? 0 : n / 100;
}

List<double> _sample(List<double> tokens) {
  final out = <double>[];
  var x = 0.0;
  var y = 0.0;
  for (var i = 0; i < tokens.length;) {
    final cmd = tokens[i].toInt();
    final count = tokens[i + 1].toInt();
    final s = i + 2;
    final e = s + count;
    i = e;
    if (cmd == 72 || cmd == 86) {
      for (var k = s; k < e; k++) {
        if (cmd == 72) {
          x = tokens[k];
        } else {
          y = tokens[k];
        }
        out.addAll(<double>[x, y]);
      }
    } else if (cmd == 67 || cmd == 81) {
      final cubic = cmd == 67;
      final step = cubic ? 6 : 4;
      for (var k = s; k + step <= e; k += step) {
        final x1 = tokens[k];
        final y1 = tokens[k + 1];
        final x2 = tokens[k + 2];
        final y2 = tokens[k + 3];
        final x3 = cubic ? tokens[k + 4] : x2;
        final y3 = cubic ? tokens[k + 5] : y2;
        for (var t = 0.125; t <= 1; t += 0.125) {
          var ax = x + (x1 - x) * t;
          var ay = y + (y1 - y) * t;
          var bx = x1 + (x2 - x1) * t;
          var by = y1 + (y2 - y1) * t;
          if (cubic) {
            final cx = x2 + (x3 - x2) * t;
            final cy = y2 + (y3 - y2) * t;
            ax += (bx - ax) * t;
            ay += (by - ay) * t;
            bx += (cx - bx) * t;
            by += (cy - by) * t;
          }
          out.addAll(<double>[ax + (bx - ax) * t, ay + (by - ay) * t]);
        }
        x = x3;
        y = y3;
      }
    } else if (cmd == 65) {
      for (var k = s; k + 7 <= e; k += 7) {
        _arc(
          out,
          x,
          y,
          tokens[k],
          tokens[k + 1],
          tokens[k + 3],
          tokens[k + 4],
          tokens[k + 5],
          tokens[k + 6],
        );
        x = tokens[k + 5];
        y = tokens[k + 6];
      }
    } else {
      for (var k = s; k + 2 <= e; k += 2) {
        if (cmd == 77 && k == s && out.isNotEmpty) {
          out.addAll(<double>[double.nan, double.nan]);
        }
        x = tokens[k];
        y = tokens[k + 1];
        out.addAll(<double>[x, y]);
      }
    }
  }
  return out;
}

void _arc(
  List<double> out,
  double x1,
  double y1,
  double rx,
  double ry,
  double large,
  double sweep,
  double x2,
  double y2,
) {
  final hx = (x1 - x2) / 2;
  final hy = (y1 - y2) / 2;
  if (rx == 0 || ry == 0 || (hx == 0 && hy == 0)) {
    out.addAll(<double>[x2, y2]);
    return;
  }
  final scale = math.max(
    1.0,
    math.sqrt((hx * hx) / (rx * rx) + (hy * hy) / (ry * ry)),
  );
  rx *= scale;
  ry *= scale;
  final k =
      (large == sweep ? -1.0 : 1.0) *
      math.sqrt(
        math.max(
          0.0,
          (rx * rx * ry * ry - rx * rx * hy * hy - ry * ry * hx * hx) /
              (rx * rx * hy * hy + ry * ry * hx * hx),
        ),
      );
  final cx = (k * rx * hy) / ry + (x1 + x2) / 2;
  final cy = (-k * ry * hx) / rx + (y1 + y2) / 2;
  final from = math.atan2((y1 - cy) / ry, (x1 - cx) / rx);
  var turn = math.atan2((y2 - cy) / ry, (x2 - cx) / rx) - from;
  if (sweep != 0 && turn < 0) {
    turn += 2 * math.pi;
  } else if (sweep == 0 && turn > 0) {
    turn -= 2 * math.pi;
  }
  for (var i = 1; i <= 8; i++) {
    out.addAll(<double>[
      cx + rx * math.cos(from + (turn * i) / 8),
      cy + ry * math.sin(from + (turn * i) / 8),
    ]);
  }
}

bool _clips(
  double x,
  double y,
  double dx,
  double dy,
  double l,
  double t,
  double r,
  double b,
) {
  var lo = 0.0;
  var hi = 1.0;
  for (var side = 0; side < 4; side++) {
    final p = side == 0
        ? -dx
        : side == 1
        ? dx
        : side == 2
        ? -dy
        : dy;
    final q = side == 0
        ? x - l
        : side == 1
        ? r - x
        : side == 2
        ? y - t
        : b - y;
    if (p == 0) {
      if (q < 0) hi = -1;
    } else if (p < 0) {
      lo = math.max(lo, q / p);
    } else {
      hi = math.min(hi, q / p);
    }
  }
  return lo < hi;
}

bool _enters(List<double> points, double l, double t, double r, double b) {
  for (var k = 0; k + 2 < points.length; k += 2) {
    final x = points[k];
    final y = points[k + 1];
    final x2 = points[k + 2];
    final y2 = points[k + 3];
    if (x.isNaN || y.isNaN || x2.isNaN || y2.isNaN) continue;
    if ((x < l && x2 < l) ||
        (x > r && x2 > r) ||
        (y < t && y2 < t) ||
        (y > b && y2 > b)) {
      continue;
    }
    if (_clips(x, y, x2 - x, y2 - y, l, t, r, b)) return true;
  }
  return false;
}

class Fill {
  final List<double> box;
  final String shape;

  const Fill({required this.box, required this.shape});
}

/// Returns the innermost [Fill] holding the whole edge and its marker tips,
/// `''` when it crosses a border, or `null` off fills.
Object? fillUnder(
  String d,
  List<double> tips,
  List<Fill> fills, [
  List<double>? tokens,
]) {
  if (fills.isEmpty) return null;
  final points = tokens != null ? _sample(tokens) : _pathPoints(d);
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = double.negativeInfinity;
  var maxY = double.negativeInfinity;
  for (var k = 0; k < points.length + tips.length; k += 2) {
    final x = k < points.length ? points[k] : tips[k - points.length];
    final y = k < points.length ? points[k + 1] : tips[k + 1 - points.length];
    if (x < minX) minX = x;
    if (x > maxX) maxX = x;
    if (y < minY) minY = y;
    if (y > maxY) maxY = y;
  }
  Fill? holder;
  var least = double.infinity;
  for (final fill in fills) {
    final l = fill.box[0];
    final t = fill.box[1];
    final r = fill.box[2];
    final b = fill.box[3];
    if (maxX < l + 0.5 || minX > r - 0.5 || maxY < t + 0.5 || minY > b - 0.5) {
      continue;
    }
    var touched = _enters(points, l + 0.5, t + 0.5, r - 0.5, b - 0.5);
    for (var k = 0; k < tips.length && !touched; k += 2) {
      touched =
          tips[k] > l + 0.5 &&
          tips[k] < r - 0.5 &&
          tips[k + 1] > t + 0.5 &&
          tips[k + 1] < b - 0.5;
    }
    if (!touched) continue;
    if (minX < l || maxX > r || minY < t || maxY > b) return '';
    final area = (r - l) * (b - t);
    if (area < least) {
      least = area;
      holder = fill;
    }
  }
  return holder;
}

final RegExp _strokeLineRe = RegExp(r'[";]stroke:');
final RegExp _fillShapeRe = RegExp(r'[";]fill:([^;"]*)');

String edgeInk(Fill fill, [String line = '']) {
  return (_strokeLineRe.hasMatch(line) ? null : ink(fill.shape)) ?? '';
}

String hollowOn(String markers, Fill fill) {
  final color = _fillShapeRe.firstMatch(fill.shape)?.group(1)?.trim();
  return (color != null && color.isNotEmpty)
      ? markers.replaceAll(' fill="var(--_bg)"', ' fill="$color"')
      : markers;
}

String? overFills(
  String d,
  List<double> tips,
  List<Fill> fills, [
  String line = '',
  List<double>? tokens,
]) {
  final fill = fillUnder(d, tips, fills, tokens);
  return fill is Fill ? edgeInk(fill, line) : fill as String?;
}

const int _caseWidth = 4;
final RegExp _pxWidthRe = RegExp(r'^[\d.]+(?:px)?$');

String casing(
  String d,
  String markers, [
  String line = '',
  bool thick = false,
]) {
  String? decl(String prop) => line.contains(prop)
      ? RegExp('[";]$prop:([^;"]+);').firstMatch(line)?.group(1)?.trim()
      : null;
  final stroke = decl('stroke');
  if (stroke == 'none' || stroke == 'transparent') return '';
  final width = thick ? '2.5' : decl('stroke-width');
  var attrs = '';
  var style = '';
  if (width != null && _pxWidthRe.hasMatch(width)) {
    final parsed = double.parse(width.replaceAll('px', ''));
    if (parsed != 1) {
      attrs = ' stroke-width="${num(parsed + _caseWidth)}"';
    }
  } else if (width != null) {
    style += 'stroke-width:calc($width + ${_caseWidth}px);';
  }
  for (final prop in const <String>['opacity', 'stroke-opacity']) {
    final value = decl(prop);
    if (value != null) style += '$prop:$value;';
  }
  final body =
      '<path d="$d"/>${markers.replaceAll(' class="pele-marker"', '')}';
  return (attrs.isNotEmpty || style.isNotEmpty)
      ? '<g$attrs${style.isNotEmpty ? ' style="$style"' : ''}>$body</g>'
      : body;
}

String edgeCasing(
  EdgePath path,
  String startType,
  String endType, [
  String line = '',
  bool thick = false,
]) {
  return casing(
    path.d,
    marker(
          startType,
          path.sx,
          path.sy,
          path.sdx,
          path.sdy,
          'var(--_bg)',
          'var(--_bg)',
        ) +
        marker(
          endType,
          path.ex,
          path.ey,
          path.edx,
          path.edy,
          'var(--_bg)',
          'var(--_bg)',
        ),
    line,
    thick,
  );
}

String casingsSvg(String casings) {
  return casings.isNotEmpty
      ? '<g class="pele-casings" fill="none" stroke="var(--_bg)" stroke-width="${1 + _caseWidth}" stroke-linecap="round" stroke-linejoin="round" pointer-events="none">$casings</g>'
      : '';
}

String edgeLabelSvg(
  String id,
  Label label,
  double x,
  double y,
  String attrs, [
  IconResolver? icons,
]) {
  final w = label.width + 8;
  final h = label.height;
  return '<g class="pele-edge-label" data-id="${escText(id)}">'
      '<rect x="${num(x - w / 2)}" y="${num(y - h / 2)}" width="${num(w)}" height="${num(h)}" rx="3" fill="var(--_bg)"/>'
      '${labelSvg(label, x, y, attrs, icons)}'
      '</g>';
}

EdgePath loopPath(
  dynamic c,
  double w,
  double h,
  int k,
  bool sideways,
  double base,
  double trim,
  dynamic e,
) {
  final cx = (c.x as double);
  final cy = (c.y as double);
  final labelW = (e.labelW as double);
  final labelH = (e.labelH as double);
  final half = (sideways ? w : h) / 2;
  final spread = math.min(half - 4, 8.0 + k * 6);
  final reach = base + k * 8;
  final rawLen = hypot(reach, spread);
  final len = rawLen != 0 ? rawLen : 1.0;
  String at(double out, double along) => sideways
      ? '${num(cx + along)},${num(cy + h / 2 + out)}'
      : '${num(cx + w / 2 + out)},${num(cy + along)}';
  final tx = (reach / len) * trim;
  final ty = (spread / len) * trim;
  if (sideways) {
    e.labelX = cx;
    e.labelY = cy + h / 2 + reach + 4 + labelH / 2;
  } else {
    e.labelX = cx + w / 2 + reach + 4 + labelW / 2;
    e.labelY = cy;
  }
  return EdgePath(
    d: 'M${at(0, -spread)}C${at(reach, -spread * 2)} ${at(reach, spread * 2)} ${at(tx, spread + ty)}',
    sx: sideways ? cx - spread : cx + w / 2,
    sy: sideways ? cy + h / 2 : cy - spread,
    sdx: sideways ? 0 : -1,
    sdy: sideways ? -1 : 0,
    ex: sideways ? cx + spread : cx + w / 2,
    ey: sideways ? cy + h / 2 : cy + spread,
    edx: sideways ? -spread / len : -reach / len,
    edy: sideways ? -reach / len : -spread / len,
  );
}

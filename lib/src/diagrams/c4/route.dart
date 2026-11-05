// Upstream: src/diagrams/c4/route.ts

import 'dart:math' as math;

import '../../svg/builder.dart';
import '../../svg/edges.dart';
import '../../util/math_js.dart';

// A laid out shape or boundary: top-left corner, size, and the shared shape it is drawn as.
class Box {
  Box({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.form,
  });

  double x;
  double y;
  double w;
  double h;
  String form;
}

class Route extends EdgePath {
  const Route({
    required super.d,
    required super.sx,
    required super.sy,
    required super.sdx,
    required super.sdy,
    required super.ex,
    required super.ey,
    required super.edx,
    required super.edy,
    required this.x0,
    required this.y0,
    required this.x1,
    required this.y1,
    required this.nx,
    required this.ny,
    required this.lean,
    required this.room,
    required this.points,
  });

  // The stretch the label may sit on.
  final double x0;
  final double y0;
  final double x1;
  final double y1;
  // The side of that stretch the label is pushed to, as a unit vector; zero centers it on the stretch.
  final double nx;
  final double ny;
  // When set, the label stays over the line and moves that way by at most this much.
  final double lean;
  // The widest the label should be.
  final double room;
  // The corners of the line, as x, y pairs.
  final List<double> points;
}

const double _loop = 28;
const double LANE = 20;
const double _laneStep = 7;
const double _corner = 8;
// A wide label on an upright lane leans this far out from it, to the middle of the gap between columns.
const double _lean = 30;
// Label widths that fit the gap between two columns, and where there is room to spare.
const double NARROW = 88;
const double _wide = 160;
// The space a label's background adds to the width of its text.
const double LABEL_PAD = 8;
// The shared person shape: a head of radius 13 centered 14 below the top, over a body that starts 26 below it.
const double HEAD = 26;

// The cap radii drawShape uses for the two cylinders.
double cylRy(double w) => math.min(12.0, math.max(6.0, w / 14));
double queueRx(double h) => math.min(12.0, h / 4);

// How far along the segment from (px, py) by (dx, dy) it first meets the rectangle; Infinity when it misses.
double _hitRect(
  double x0,
  double y0,
  double x1,
  double y1,
  double px,
  double py,
  double dx,
  double dy,
) {
  var enter = 0.0;
  var leave = 1.0;
  if (dx == 0) {
    if (px < x0 || px > x1) return double.infinity;
  } else {
    final a = (x0 - px) / dx;
    final b = (x1 - px) / dx;
    enter = math.max(enter, math.min(a, b));
    leave = math.min(leave, math.max(a, b));
  }
  if (dy == 0) {
    if (py < y0 || py > y1) return double.infinity;
  } else {
    final a = (y0 - py) / dy;
    final b = (y1 - py) / dy;
    enter = math.max(enter, math.min(a, b));
    leave = math.min(leave, math.max(a, b));
  }
  return enter <= leave ? enter : double.infinity;
}

double _hitEllipse(
  double cx,
  double cy,
  double rx,
  double ry,
  double px,
  double py,
  double dx,
  double dy,
) {
  final ux = dx / rx;
  final uy = dy / ry;
  final vx = (px - cx) / rx;
  final vy = (py - cy) / ry;
  final a = ux * ux + uy * uy;
  final b = 2 * (ux * vx + uy * vy);
  final c = vx * vx + vy * vy - 1;
  final disc = b * b - 4 * a * c;
  if (a == 0 || disc < 0) return double.infinity;
  final t = (-b - math.sqrt(disc)) / (2 * a);
  return t >= 0 && t <= 1 ? t : (c <= 0 ? 0.0 : double.infinity);
}

// Where a segment from outside first meets the outline of a shape, as a fraction of the segment.
double _hit(Box box, double px, double py, double qx, double qy) {
  final x = box.x;
  final y = box.y;
  final w = box.w;
  final h = box.h;
  final dx = qx - px;
  final dy = qy - py;
  if (box.form == 'person') {
    return math.min(
      _hitRect(x, y + HEAD, x + w, y + h, px, py, dx, dy),
      _hitEllipse(x + w / 2, y + 14, 13, 13, px, py, dx, dy),
    );
  }
  if (box.form == 'cyl') {
    final ry = cylRy(w);
    return math.min(
      _hitRect(x, y + ry, x + w, y + h - ry, px, py, dx, dy),
      math.min(
        _hitEllipse(x + w / 2, y + ry, w / 2, ry, px, py, dx, dy),
        _hitEllipse(x + w / 2, y + h - ry, w / 2, ry, px, py, dx, dy),
      ),
    );
  }
  if (box.form == 'h-cyl') {
    final rx = queueRx(h);
    return math.min(
      _hitRect(x + rx, y, x + w - rx, y + h, px, py, dx, dy),
      math.min(
        _hitEllipse(x + rx, y + h / 2, rx, h / 2, px, py, dx, dy),
        _hitEllipse(x + w - rx, y + h / 2, rx, h / 2, px, py, dx, dy),
      ),
    );
  }
  return _hitRect(x, y, x + w, y + h, px, py, dx, dy);
}

bool crosses(List<double> points, double x0, double y0, double x1, double y1) {
  for (var i = 2; i < points.length; i += 2) {
    final px = points[i - 2];
    final py = points[i - 1];
    if (_hitRect(x0, y0, x1, y1, px, py, points[i] - px, points[i + 1] - py) <=
        1) {
      return true;
    }
  }
  return false;
}

bool _contains(Box outer, Box inner) {
  return outer.x <= inner.x &&
      outer.y <= inner.y &&
      outer.x + outer.w >= inner.x + inner.w &&
      outer.y + outer.h >= inner.y + inner.h;
}

// The straight line from a to b: x, y of its start, then of its end.
(double, double, double, double) _connect(Box a, Box b, double shift) {
  final ax = a.x + a.w / 2;
  final ay = a.y + a.h / 2;
  final bx = b.x + b.w / 2;
  final by = b.y + b.h / 2;
  final down = _contains(a, b);
  if (down || _contains(b, a)) {
    // One holds the other: a short line from the nearest side of the outer box.
    final outer = down ? a : b;
    final inner = down ? b : a;
    final ix = inner.x + inner.w / 2;
    final iy = inner.y + inner.h / 2;
    final left = inner.x - outer.x;
    final right = outer.x + outer.w - inner.x - inner.w;
    final top = inner.y - outer.y;
    final bottom = outer.y + outer.h - inner.y - inner.h;
    final least = math.min(math.min(left, right), math.min(top, bottom));
    final ox = least == left
        ? outer.x
        : least == right
        ? outer.x + outer.w
        : ix;
    final oy = least == left || least == right
        ? iy
        : least == bottom
        ? outer.y + outer.h
        : outer.y;
    final t = math.min(_hit(inner, ox, oy, ix, iy), 1.0);
    final mx = ox + (ix - ox) * t;
    final my = oy + (iy - oy) * t;
    return down ? (ox, oy, mx, my) : (mx, my, ox, oy);
  }

  var px = ax;
  var py = ay;
  var qx = bx;
  var qy = by;
  // Shapes that share a column or a row are joined by an upright or level line through the shared span.
  final x0 = math.max(a.x, b.x);
  final x1 = math.min(a.x + a.w, b.x + b.w);
  final y0 = math.max(a.y, b.y);
  final y1 = math.min(a.y + a.h, b.y + b.h);
  if (x0 < x1) {
    px = qx = (x0 + x1) / 2;
  } else if (y0 < y1) {
    py = qy = (y0 + y1) / 2;
  }
  final rawLen = hypot(qx - px, qy - py);
  final len = rawLen != 0 ? rawLen : 1.0;
  final nx = (-(qy - py) / len) * shift;
  final ny = ((qx - px) / len) * shift;
  var ta = _hit(a, qx + nx, qy + ny, px + nx, py + ny);
  var tb = _hit(b, px + nx, py + ny, qx + nx, qy + ny);
  if (ta <= 1 && tb <= 1) {
    px += nx;
    py += ny;
    qx += nx;
    qy += ny;
  } else {
    px = ax;
    py = ay;
    qx = bx;
    qy = by;
    ta = math.min(_hit(a, qx, qy, px, py), 1.0);
    tb = math.min(_hit(b, px, py, qx, qy), 1.0);
  }
  return (
    qx + (px - qx) * ta,
    qy + (py - qy) * ta,
    px + (qx - px) * tb,
    py + (qy - py) * tb,
  );
}

// Parallel stretches closer than this read as one line, and a line this close to a boundary's frame
// reads as part of it.
const double _near = 6;
const double _frameNear = 3;
const double _portStep = 12;

// What the routes drawn so far take up, so that the next keeps apart from them: upright stretches
// as x, top, bottom; level ones as y, left, right; and where lines leave or reach each side of a shape.
class Lanes {
  final List<double> _upright = <double>[];
  final List<double> _level = <double>[];
  final List<List<double>> _frames = <List<double>>[<double>[], <double>[]];
  final Map<Box, List<double>> _taken = <Box, List<double>>{};
  // Routes that found no lane of their own: a line left straight behind a shape, or a lane that
  // runs along another.
  int squeezed = 0;

  bool free(bool upright, double at, double a0, double a1) {
    final lo = math.min(a0, a1);
    final hi = math.max(a0, a1);
    bool near(List<double> list, double gap) {
      for (var i = 0; i < list.length; i += 3) {
        if ((list[i] - at).abs() < gap &&
            list[i + 1] < hi &&
            list[i + 2] > lo) {
          return true;
        }
      }
      return false;
    }

    return !near(upright ? _upright : _level, _near) &&
        !near(_frames[upright ? 0 : 1], _frameNear);
  }

  int crossings(List<double> points) {
    var count = 0;
    for (var i = 2; i < points.length; i += 2) {
      final upright = points[i] == points[i - 2];
      final at = upright ? points[i] : points[i + 1];
      final lo = math.min(
        upright ? points[i - 1] : points[i - 2],
        upright ? points[i + 1] : points[i],
      );
      final hi = math.max(
        upright ? points[i - 1] : points[i - 2],
        upright ? points[i + 1] : points[i],
      );
      final list = upright ? _level : _upright;
      for (var j = 0; j < list.length; j += 3) {
        if (list[j] > lo &&
            list[j] < hi &&
            list[j + 1] < at &&
            list[j + 2] > at) {
          count++;
        }
      }
    }
    return count;
  }

  void frame(Box box) {
    _frames[0].addAll(<double>[
      box.x,
      box.y,
      box.y + box.h,
      box.x + box.w,
      box.y,
      box.y + box.h,
    ]);
    _frames[1].addAll(<double>[
      box.y,
      box.x,
      box.x + box.w,
      box.y + box.h,
      box.x,
      box.x + box.w,
    ]);
  }

  void take(List<double> points) {
    for (var i = 2; i < points.length; i += 2) {
      if (points[i] == points[i - 2]) {
        _upright.addAll(<double>[
          points[i],
          math.min(points[i - 1], points[i + 1]),
          math.max(points[i - 1], points[i + 1]),
        ]);
      } else if (points[i + 1] == points[i - 1]) {
        _level.addAll(<double>[
          points[i + 1],
          math.min(points[i - 2], points[i]),
          math.max(points[i - 2], points[i]),
        ]);
      }
    }
  }

  // Where on one side of a shape (0 left, 1 right, 2 top, 3 bottom) a line can leave or arrive,
  // between lo and hi: the places clear of the lines already there, nearest `want` first.
  List<double> ports(Box box, int side, double want, double lo, double hi) {
    final used = _taken[box] ?? const <double>[];
    final out = <double>[];
    for (var k = 0; k < 9 && out.length < 4; k++) {
      final at = want + ((k & 1) != 0 ? 1 : -1) * ((k + 1) ~/ 2) * _portStep;
      if (at < lo || at > hi) continue;
      var clear = true;
      for (var i = 0; i < used.length; i += 2) {
        if (used[i] == side && (used[i + 1] - at).abs() < _portStep) {
          clear = false;
        }
      }
      if (clear) out.add(at);
    }
    return out.isNotEmpty ? out : <double>[want];
  }

  void claim(Box box, int side, double at) {
    final used = _taken[box];
    if (used != null) {
      used.addAll(<double>[side.toDouble(), at]);
    } else {
      _taken[box] = <double>[side.toDouble(), at];
    }
  }
}

String _path(List<double> points, double startTrim, double endTrim) {
  final n = points.length;
  final ux = signJs(points[2] - points[0]);
  final uy = signJs(points[3] - points[1]);
  var d =
      'M${num(points[0] + ux * startTrim)},${num(points[1] + uy * startTrim)}';
  for (var i = 2; i < n - 2; i += 2) {
    final x = points[i];
    final y = points[i + 1];
    final ix = signJs(x - points[i - 2]);
    final iy = signJs(y - points[i - 1]);
    final ox = signJs(points[i + 2] - x);
    final oy = signJs(points[i + 3] - y);
    final r = math.min(
      _corner,
      math.min(
        (x - points[i - 2] + y - points[i - 1]).abs() / 2,
        (points[i + 2] - x + points[i + 3] - y).abs() / 2,
      ),
    );
    d +=
        '${ix != 0 ? 'H${num(x - ix * r)}' : 'V${num(y - iy * r)}'}Q${num(x)},${num(y)} ${num(x + ox * r)},${num(y + oy * r)}';
  }
  final lx = signJs(points[n - 2] - points[n - 4]);
  final ly = signJs(points[n - 1] - points[n - 3]);
  return d +
      (lx != 0
          ? 'H${num(points[n - 2] - lx * endTrim)}'
          : 'V${num(points[n - 1] - ly * endTrim)}');
}

bool _clearOf(List<double> points, List<Box> others, Box a, Box b) {
  for (final other in others) {
    if (other != a &&
        other != b &&
        crosses(
          points,
          other.x,
          other.y,
          other.x + other.w,
          other.y + other.h,
        )) {
      return false;
    }
  }
  return true;
}

// The route for a line with corners through `points`, from a's outline to b's. `along` is the
// stretch its label sits on.
Route _bent(
  List<double> points,
  int along,
  double startTrim,
  double endTrim, {
  double nx = 0,
  double ny = 0,
  double lean = 0,
  double room = _wide,
}) {
  final n = points.length;
  return Route(
    d: _path(points, startTrim, endTrim),
    sx: points[0],
    sy: points[1],
    sdx: -signJs(points[2] - points[0]),
    sdy: -signJs(points[3] - points[1]),
    ex: points[n - 2],
    ey: points[n - 1],
    edx: signJs(points[n - 2] - points[n - 4]),
    edy: signJs(points[n - 1] - points[n - 3]),
    x0: points[along],
    y0: points[along + 1],
    x1: points[along + 2],
    y1: points[along + 3],
    nx: nx,
    ny: ny,
    lean: lean,
    room: room,
    points: points,
  );
}

List<double> _across(double lo, double hi) {
  final out = <double>[];
  final mid = (lo + hi) / 2;
  final step = math.max(_laneStep, (hi - lo) / 4);
  for (var k = 0; k < 9; k++) {
    final at = mid + ((k & 1) != 0 ? 1 : -1) * ((k + 1) ~/ 2) * step;
    if (at >= lo + _near && at <= hi - _near) out.add(at);
  }
  return out;
}

class _ElbowCandidate {
  const _ElbowCandidate({
    required this.points,
    required this.cost,
    required this.upright,
    required this.side0,
    required this.side1,
  });

  final List<double> points;
  final double cost;
  final bool upright;
  final int side0;
  final int side1;
}

Route? _elbow(
  Box a,
  Box b,
  List<Box> others,
  Lanes lanes,
  double startTrim,
  double endTrim,
) {
  final ax = a.x + a.w / 2;
  final ay = a.y + a.h / 2;
  final bx = b.x + b.w / 2;
  final by = b.y + b.h / 2;
  _ElbowCandidate? best;
  void consider(List<double> points, bool upright, int side0, int side1) {
    if (!_clearOf(points, others, a, b)) return;
    for (var i = 2; i < points.length; i += 2) {
      final up = points[i] == points[i - 2];
      if (!lanes.free(
        up,
        up ? points[i] : points[i + 1],
        up ? points[i - 1] : points[i - 2],
        up ? points[i + 1] : points[i],
      )) {
        return;
      }
    }
    var cost = lanes.crossings(points) * 1e6;
    for (var i = 2; i < points.length; i += 2) {
      cost +=
          (points[i] - points[i - 2]).abs() +
          (points[i + 1] - points[i - 1]).abs();
    }
    if (best == null || cost < best!.cost) {
      best = _ElbowCandidate(
        points: points,
        cost: cost,
        upright: upright,
        side0: side0,
        side1: side1,
      );
    }
  }

  if (a.x + a.w <= b.x || b.x + b.w <= a.x) {
    final right = bx > ax;
    final down = signJs(by - ay);
    final side0 = right ? 1 : 0;
    final side1 = right ? 0 : 1;
    final lanesAcross = _across(
      right ? a.x + a.w : b.x + b.w,
      right ? b.x : a.x,
    );
    search:
    for (final y0 in lanes.ports(
      a,
      side0,
      ay + (down * a.h) / 4,
      a.y + 8,
      a.y + a.h - 8,
    )) {
      for (final y1 in lanes.ports(
        b,
        side1,
        by - (down * b.h) / 4,
        b.y + 8,
        b.y + b.h - 8,
      )) {
        for (final lane in lanesAcross) {
          final x0 =
              lane + (ax - lane) * math.min(_hit(a, lane, y0, ax, y0), 1.0);
          final x1 =
              lane + (bx - lane) * math.min(_hit(b, lane, y1, bx, y1), 1.0);
          final before = best;
          consider(
            <double>[x0, y0, lane, y0, lane, y1, x1, y1],
            true,
            side0,
            side1,
          );
          if (!identical(best, before)) break search;
        }
      }
    }
  }
  if (a.y + a.h <= b.y || b.y + b.h <= a.y) {
    final below = by > ay;
    final sideways = signJs(bx - ax);
    final side0 = below ? 3 : 2;
    final side1 = below ? 2 : 3;
    final lanesAcross = _across(
      below ? a.y + a.h : b.y + b.h,
      below ? b.y : a.y,
    );
    search:
    for (final x0 in lanes.ports(
      a,
      side0,
      ax + (sideways * a.w) / 4,
      a.x + 8,
      a.x + a.w - 8,
    )) {
      for (final x1 in lanes.ports(
        b,
        side1,
        bx - (sideways * b.w) / 4,
        b.x + 8,
        b.x + b.w - 8,
      )) {
        for (final lane in lanesAcross) {
          final y0 =
              lane + (ay - lane) * math.min(_hit(a, x0, lane, x0, ay), 1.0);
          final y1 =
              lane + (by - lane) * math.min(_hit(b, x1, lane, x1, by), 1.0);
          final before = best;
          consider(
            <double>[x0, y0, x0, lane, x1, lane, x1, y1],
            false,
            side0,
            side1,
          );
          if (!identical(best, before)) break search;
        }
      }
    }
  }
  if (best == null) return null;
  final chosen = best!;
  final points = chosen.points;
  final upright = chosen.upright;
  lanes.take(points);
  lanes.claim(a, chosen.side0, upright ? points[1] : points[0]);
  lanes.claim(b, chosen.side1, upright ? points[7] : points[6]);
  // The label sits on the middle stretch, across the gap.
  return _bent(points, 2, startTrim, endTrim, room: upright ? NARROW : _wide);
}

class _AlongWay {
  const _AlongWay({
    required this.points,
    required this.side,
    required this.p0,
    required this.p1,
    required this.step,
  });

  final List<double> points;
  final int side;
  final double p0;
  final double p1;
  final int step;
}

// Routes a relation from a to b. `shift` moves the line sideways when another runs the opposite way.
// `others` are the shapes to steer clear of; null skips that check. `lanes` holds what the
// routes before it take up, so that this one keeps apart from them.
Route route(
  Box a,
  Box b,
  double shift,
  List<Box>? others,
  Lanes lanes,
  double startTrim,
  double endTrim,
) {
  if (identical(a, b)) {
    final spread = math.min(a.h / 2 - 4, 10.0);
    final len = hypot(_loop, spread);
    final x = a.x + a.w;
    final cy = a.y + a.h / 2;
    final ux = _loop / len;
    final uy = spread / len;
    return Route(
      d:
          'M${num(x + ux * startTrim)},${num(cy - spread - uy * startTrim)}C${num(x + _loop)},${num(cy - spread * 2)} '
          '${num(x + _loop)},${num(cy + spread * 2)} ${num(x + ux * endTrim)},${num(cy + spread + uy * endTrim)}',
      sx: x,
      sy: cy - spread,
      sdx: -ux,
      sdy: uy,
      ex: x,
      ey: cy + spread,
      edx: -ux,
      edy: -uy,
      x0: x + _loop + 4,
      y0: cy,
      x1: x + _loop + 4,
      y1: cy,
      nx: 1,
      ny: 0,
      lean: 0,
      room: 64,
      points: const <double>[],
    );
  }

  final (sx, sy, ex, ey) = _connect(a, b, shift);
  final upright = sx == ex;
  var blocked = false;
  if (others != null && !_contains(a, b) && !_contains(b, a)) {
    for (final other in others) {
      if (other != a &&
          other != b &&
          _hitRect(
                other.x,
                other.y,
                other.x + other.w,
                other.y + other.h,
                sx,
                sy,
                ex - sx,
                ey - sy,
              ) <=
              1) {
        blocked = true;
      }
    }
  }
  if (others != null && blocked && !upright && sy != ey) {
    final around = _elbow(a, b, others, lanes, startTrim, endTrim);
    if (around != null) return around;
    lanes.squeezed++;
  }
  if (others != null && blocked && (upright || sy == ey)) {
    double laneOn(bool forward) {
      var lane = forward ? double.negativeInfinity : double.infinity;
      void widen(Box box) {
        final edge = upright ? box.x : box.y;
        lane = forward
            ? math.max(lane, edge + (upright ? box.w : box.h))
            : math.min(lane, edge);
      }

      widen(a);
      widen(b);
      for (final other in others) {
        if (other != a &&
            other != b &&
            _hitRect(
                  other.x,
                  other.y,
                  other.x + other.w,
                  other.y + other.h,
                  sx,
                  sy,
                  ex - sx,
                  ey - sy,
                ) <=
                1) {
          widen(other);
        }
      }
      return lane;
    }

    final lo = upright ? math.min(a.y, b.y) : math.min(a.x, b.x);
    final hi = upright
        ? math.max(a.y + a.h, b.y + b.h)
        : math.max(a.x + a.w, b.x + b.w);
    bool outside(bool forward, double lane) {
      for (final other in others) {
        if (other == a || other == b) continue;
        final near = upright
            ? other.y < hi && other.y + other.h > lo
            : other.x < hi && other.x + other.w > lo;
        final start = upright ? other.x : other.y;
        final end = start + (upright ? other.w : other.h);
        if (near && (forward ? end > lane : start < lane)) return false;
      }
      return true;
    }

    final ax = a.x + a.w / 2;
    final ay = a.y + a.h / 2;
    final bx = b.x + b.w / 2;
    final by = b.y + b.h / 2;
    final towards = upright ? signJs(by - ay) : signJs(bx - ax);

    _AlongWay along(bool forward) {
      final lane = laneOn(forward);
      final sign = forward ? 1.0 : -1.0;
      final side = upright ? (forward ? 1 : 0) : (forward ? 3 : 2);
      final p0 = upright
          ? lanes.ports(
              a,
              side,
              ay + (towards * a.h) / 4,
              a.y + 8,
              a.y + a.h - 8,
            )[0]
          : lanes.ports(
              a,
              side,
              ax + (towards * a.w) / 4,
              a.x + 8,
              a.x + a.w - 8,
            )[0];
      final p1 = upright
          ? lanes.ports(
              b,
              side,
              by - (towards * b.h) / 4,
              b.y + 8,
              b.y + b.h - 8,
            )[0]
          : lanes.ports(
              b,
              side,
              bx - (towards * b.w) / 4,
              b.x + 8,
              b.x + b.w - 8,
            )[0];
      List<double> pointsAt(double at) {
        if (upright) {
          final x0 = at + (ax - at) * math.min(_hit(a, at, p0, ax, p0), 1.0);
          final x1 = at + (bx - at) * math.min(_hit(b, at, p1, bx, p1), 1.0);
          return <double>[x0, p0, at, p0, at, p1, x1, p1];
        }
        final y0 = at + (ay - at) * math.min(_hit(a, p0, at, p0, ay), 1.0);
        final y1 = at + (by - at) * math.min(_hit(b, p1, at, p1, by), 1.0);
        return <double>[p0, y0, p0, at, p1, at, p1, y1];
      }

      var points = pointsAt(lane + sign * LANE);
      for (var k = 0; k <= 4; k++) {
        final at = lane + sign * (LANE + k * _laneStep);
        final tried = pointsAt(at);
        if (!_clearOf(tried, others, a, b)) continue;
        points = tried;
        if (lanes.free(upright, at, p0, p1)) {
          return _AlongWay(points: points, side: side, p0: p0, p1: p1, step: k);
        }
      }
      return _AlongWay(points: points, side: side, p0: p0, p1: p1, step: 5);
    }

    final natural = upright ? ey > sy : ex < sx;
    final out = outside(natural, laneOn(natural));
    final back = outside(!natural, laneOn(!natural));
    final first = along(natural);
    final other = out == back ? along(!natural) : null;
    int cost(_AlongWay way) => lanes.crossings(way.points) * 8 + way.step;
    final forward = back && !out
        ? !natural
        : (other != null && cost(other) < cost(first) ? !natural : natural);
    final chosen = forward == natural ? first : (other ?? along(!natural));
    final sign = forward ? 1.0 : -1.0;
    if (chosen.step > 4) lanes.squeezed++;
    lanes.take(chosen.points);
    lanes.claim(a, chosen.side, chosen.p0);
    lanes.claim(b, chosen.side, chosen.p1);
    return upright
        ? _bent(
            chosen.points,
            2,
            startTrim,
            endTrim,
            nx: sign,
            lean: _lean,
            room: NARROW,
          )
        : _bent(chosen.points, 2, startTrim, endTrim, room: _wide);
  }

  final rawLen = hypot(ex - sx, ey - sy);
  final len = rawLen != 0 ? rawLen : 1.0;
  final dx = (ex - sx) / len;
  final dy = (ey - sy) / len;
  if (upright || sy == ey) lanes.take(<double>[sx, sy, ex, ey]);
  return Route(
    d: 'M${num(sx + dx * startTrim)},${num(sy + dy * startTrim)}L${num(ex - dx * endTrim)},${num(ey - dy * endTrim)}',
    sx: sx,
    sy: sy,
    sdx: -dx,
    sdy: -dy,
    ex: ex,
    ey: ey,
    edx: dx,
    edy: dy,
    x0: sx,
    y0: sy,
    x1: ex,
    y1: ey,
    nx: shift != 0 ? -dy : 0,
    ny: shift != 0 ? dx : 0,
    lean: 0,
    room: dx.abs() > dy.abs() ? NARROW : _wide,
    points: <double>[sx, sy, ex, ey],
  );
}

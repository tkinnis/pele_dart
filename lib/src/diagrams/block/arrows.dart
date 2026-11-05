// Upstream: src/diagrams/block/arrows.ts

import 'dart:math' as math;

import '../../svg/builder.dart';

const int RIGHT = 1;
const int LEFT = 2;
const int UP = 4;
const int DOWN = 8;

// How far a head reaches past each side of its shaft.
const double OVERHANG = 7;
const double _maxDepth = 20;
const double _nub = 12;

class ArrowSize {
  final double w;
  final double h;
  // Shift of the label from the center, away from the heads.
  final double dx;
  final double dy;

  const ArrowSize({
    required this.w,
    required this.h,
    required this.dx,
    required this.dy,
  });
}

// Mermaid compares directions exactly, so `( up )` draws no arrow there. Here spaces are ignored.
int arrowMask(List<String>? directions) {
  var mask = 0;
  if (directions != null) {
    for (final direction in directions) {
      switch (direction.trim()) {
        case 'right':
          mask |= RIGHT;
        case 'left':
          mask |= LEFT;
        case 'up':
          mask |= UP;
        case 'down':
          mask |= DOWN;
        case 'x':
          mask |= RIGHT | LEFT;
        case 'y':
          mask |= UP | DOWN;
      }
    }
  }
  return mask;
}

int _bit(int mask, int flag) => (mask & flag) != 0 ? 1 : 0;

// An arrow along one axis has a shaft and heads wider than it. One that points along both axes
// is a box with a small point on each side it names.
String arrowAxis(int mask) {
  if (mask != 0 && (mask & (UP | DOWN)) == 0) return 'x';
  if (mask != 0 && (mask & (RIGHT | LEFT)) == 0) return 'y';
  return '';
}

ArrowSize arrowSize(int mask, double tw, double th) {
  final axis = arrowAxis(mask);
  final across = _bit(mask, LEFT) - _bit(mask, RIGHT);
  final along = _bit(mask, UP) - _bit(mask, DOWN);
  if (axis == 'x') {
    final h = math.max(th + 8, 14.0) + 2 * OVERHANG;
    final depth = math.min(h / 2, _maxDepth);
    return ArrowSize(
      w: math.max(tw + 12, 16.0) + depth * (mask == (RIGHT | LEFT) ? 2 : 1),
      h: h,
      dx: (across * depth) / 2,
      dy: 0,
    );
  }
  if (axis == 'y') {
    final w = math.max(tw + 16, 14.0) + 2 * OVERHANG;
    final depth = math.min(w / 2, _maxDepth);
    return ArrowSize(
      w: w,
      h: math.max(th + 8, 16.0) + depth * (mask == (UP | DOWN) ? 2 : 1),
      dx: 0,
      dy: (along * depth) / 2,
    );
  }
  return ArrowSize(
    w: math.max(tw + 16, 24.0) + _nub * (_bit(mask, LEFT) + _bit(mask, RIGHT)),
    h: math.max(th + 8, 24.0) + _nub * (_bit(mask, UP) + _bit(mask, DOWN)),
    dx: (across * _nub) / 2,
    dy: (along * _nub) / 2,
  );
}

String drawArrow(int mask, double w, double h, String attrs) {
  final axis = arrowAxis(mask);
  final x = w / 2;
  final y = h / 2;
  List<double> p;
  if (axis == 'x') {
    final depth = math.min(y, _maxDepth);
    final s = y - OVERHANG;
    final x0 = (mask & LEFT) != 0 ? -x + depth : -x;
    final x1 = (mask & RIGHT) != 0 ? x - depth : x;
    p = <double>[x0, -s, x1, -s];
    if ((mask & RIGHT) != 0) p.addAll(<double>[x1, -y, x, 0, x1, y]);
    p.addAll(<double>[x1, s, x0, s]);
    if ((mask & LEFT) != 0) p.addAll(<double>[x0, y, -x, 0, x0, -y]);
  } else if (axis == 'y') {
    final depth = math.min(x, _maxDepth);
    final s = x - OVERHANG;
    final y0 = (mask & UP) != 0 ? -y + depth : -y;
    final y1 = (mask & DOWN) != 0 ? y - depth : y;
    p = <double>[s, y0, s, y1];
    if ((mask & DOWN) != 0) p.addAll(<double>[x, y1, 0, y, -x, y1]);
    p.addAll(<double>[-s, y1, -s, y0]);
    if ((mask & UP) != 0) p.addAll(<double>[-x, y0, 0, -y, x, y0]);
  } else {
    final x0 = (mask & LEFT) != 0 ? -x + _nub : -x;
    final x1 = (mask & RIGHT) != 0 ? x - _nub : x;
    final y0 = (mask & UP) != 0 ? -y + _nub : -y;
    final y1 = (mask & DOWN) != 0 ? y - _nub : y;
    final cx = (x0 + x1) / 2;
    final cy = (y0 + y1) / 2;
    final kx = math.min(10.0, (x1 - x0) / 2);
    final ky = math.min(10.0, (y1 - y0) / 2);
    p = <double>[x0, y0];
    if ((mask & UP) != 0) p.addAll(<double>[cx - kx, y0, cx, -y, cx + kx, y0]);
    p.addAll(<double>[x1, y0]);
    if ((mask & RIGHT) != 0) {
      p.addAll(<double>[x1, cy - ky, x, cy, x1, cy + ky]);
    }
    p.addAll(<double>[x1, y1]);
    if ((mask & DOWN) != 0) p.addAll(<double>[cx + kx, y1, cx, y, cx - kx, y1]);
    p.addAll(<double>[x0, y1]);
    if ((mask & LEFT) != 0) {
      p.addAll(<double>[x0, cy + ky, -x, cy, x0, cy - ky]);
    }
  }
  final points = StringBuffer();
  for (var i = 0; i < p.length; i += 2) {
    if (i > 0) points.write(' ');
    points
      ..write(num(p[i]))
      ..write(',')
      ..write(num(p[i + 1]));
  }
  return '<polygon points="$points" stroke-linejoin="round"$attrs/>';
}

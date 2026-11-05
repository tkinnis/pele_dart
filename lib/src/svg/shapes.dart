// Upstream: src/svg/shapes.ts

import 'dart:math' as math;

import '../layout/compound.dart';
import 'builder.dart';
import 'theme.dart';

class ShapeSize {
  final double w;
  final double h;
  // Vertical shift of the label from the shape's center.
  final double dy;

  const ShapeSize({required this.w, required this.h, required this.dy});
}

const double PAD_X = 18;
const double PAD_Y = 12;

typedef _Sizer = ShapeSize Function(double tw, double th);
typedef _Drawer = String Function(double w, double h, String a, String line);
typedef _Inset = double Function(double w, double h, int side, double t);
typedef _Span = double Function(double w, double h, bool sideways);

class _ShapeDef {
  final _Sizer size;
  final _Drawer draw;
  final _Inset? inset;
  final _Span? span;
  final bool noLabel;
  final bool bare;

  const _ShapeDef({
    required this.size,
    required this.draw,
    this.inset,
    this.span,
    this.noLabel = false,
    this.bare = false,
  });
}

const double _corner = 12;

double _flat(double w, double h, bool sideways) =>
    (sideways ? h : w) - 2 * _corner;

_Span _flatAcross(double Function(double h) cut) =>
    (w, h, sideways) => sideways ? 0 : w - 2 * cut(h) - 2 * _corner;

double _bulge(double t, double half, double depth) {
  final k = math.min(1.0, t.abs() / half);
  return depth * (1 - math.sqrt(1 - k * k));
}

double _roundInset(double w, double h, int side, double t) =>
    (side & 1) != 0 ? _bulge(t, h / 2, w / 2) : _bulge(t, w / 2, h / 2);

double _roundSpan(double w, double h, bool sideways) =>
    (sideways ? h : w) * 0.6;

double _capInset(double w, double h, int side, double t) => (side & 1) != 0
    ? 0
    : _bulge(t, w / 2, math.min(12.0, math.max(6.0, w / 14)));

_Sizer _fixed(double w, double h) =>
    (_, _) => ShapeSize(w: w, h: h, dy: 0);

ShapeSize _triSize(double tw, double th, bool flip) {
  final w = math.max(1.6 * tw + 40, 80.0);
  final h = (th + 10) / (1 - (tw + 8) / w);
  final dy = h / 2 - 10 - th / 2;
  return ShapeSize(w: w, h: h, dy: flip ? -dy : dy);
}

String _path(String d, String a) {
  return '<path d="$d"$a/>';
}

double _leanInset(double w, double h, int side, double t) =>
    (side & 1) != 0 ? h / 8 : 0;

ShapeSize _box(double tw, double th) => ShapeSize(
  w: math.max(tw + 2 * PAD_X, 2 * PAD_X + 12),
  h: th + 2 * PAD_Y,
  dy: 0,
);

String _poly(List<double> points, String a) {
  final sb = StringBuffer();
  for (var i = 0; i < points.length; i += 2) {
    if (i > 0) sb.write(' ');
    sb
      ..write(num(points[i]))
      ..write(',')
      ..write(num(points[i + 1]));
  }
  return '<polygon points="$sb"$a/>';
}

String _rect(double w, double h, String a, [String rx = '']) {
  return '<rect x="${num(-w / 2)}" y="${num(-h / 2)}" width="${num(w)}" height="${num(h)}"$rx$a/>';
}

String _brace(double x, double h, double dir, String line) {
  final y = h / 2;
  final k = 6 * dir;
  return '<path d="M${num(x)},${num(-y)}q${num(k)},0 ${num(k)},6V-6q0,6 ${num(k)},6q${num(-k)},0 ${num(-k)},6V${num(y - 6)}q0,6 ${num(-k)},6" fill="none"$line/>';
}

String _wave(double w, double h, String a) {
  final x = w / 2;
  final top = -h / 2;
  final base = h / 2 - 10;
  final q = w / 4;
  return '<path d="M${num(-x)},${num(top)}H${num(x)}V${num(base)}q${num(-q)},-12 ${num(-2 * q)},0t${num(-2 * q)},0Z"$a/>';
}

final Map<String, _ShapeDef> _shapes = <String, _ShapeDef>{
  'rect': _ShapeDef(
    size: _box,
    span: _flat,
    draw: (w, h, a, _) => _rect(w, h, rounded(a)),
  ),
  'rounded': _ShapeDef(
    size: _box,
    span: _flat,
    draw: (w, h, a, _) => _rect(w, h, a, ' rx="${num(math.min(12.0, h / 2))}"'),
  ),
  'stadium': _ShapeDef(
    inset: (_, h, side, t) => (side & 1) != 0 ? _bulge(t, h / 2, h / 2) : 0,
    span: (w, h, sideways) => sideways ? h * 0.6 : w - h,
    size: (tw, th) {
      final h = th + 2 * PAD_Y;
      return ShapeSize(w: tw + h * 0.5 + 2 * PAD_X - 8, h: h, dy: 0);
    },
    draw: (w, h, a, _) => _rect(w, h, a, ' rx="${num(h / 2)}"'),
  ),
  'fr-rect': _ShapeDef(
    span: _flat,
    size: (tw, th) =>
        ShapeSize(w: tw + 2 * PAD_X + 16, h: th + 2 * PAD_Y, dy: 0),
    draw: (w, h, a, line) {
      final x = w / 2 - 8;
      return _rect(w, h, rounded(a)) +
          '<path d="M${num(-x)},${num(-h / 2)}V${num(h / 2)}M${num(x)},${num(-h / 2)}V${num(h / 2)}" fill="none"$line/>';
    },
  ),
  'cyl': _ShapeDef(
    inset: _capInset,
    span: (w, h, sideways) => sideways ? h - 2 * _corner - 12 : w * 0.6,
    size: (tw, th) {
      final w = math.max(tw + 2 * PAD_X, 56.0);
      final ry = math.min(12.0, math.max(6.0, w / 14));
      return ShapeSize(w: w, h: th + 2 * PAD_Y + 2 * ry, dy: ry / 2);
    },
    draw: (w, h, a, line) {
      final rx = w / 2;
      final ry = math.min(12.0, math.max(6.0, w / 14));
      final top = -h / 2 + ry;
      final bottom = h / 2 - ry;
      return '<path d="M${num(-rx)},${num(top)}A${num(rx)},${num(ry)} 0 0 1 ${num(rx)},${num(top)}V${num(bottom)}A${num(rx)},${num(ry)} 0 0 1 ${num(-rx)},${num(bottom)}Z"$a/>'
          '<path d="M${num(-rx)},${num(top)}A${num(rx)},${num(ry)} 0 0 0 ${num(rx)},${num(top)}" fill="none"$line/>';
    },
  ),
  'circle': _ShapeDef(
    inset: _roundInset,
    span: _roundSpan,
    size: (tw, th) {
      final d = math.max(math.sqrt(tw * tw + th * th) + 16, 44.0);
      return ShapeSize(w: d, h: d, dy: 0);
    },
    draw: (w, _, a, _) => '<circle r="${num(w / 2)}"$a/>',
  ),
  'dbl-circ': _ShapeDef(
    inset: _roundInset,
    span: _roundSpan,
    size: (tw, th) {
      final d = math.max(math.sqrt(tw * tw + th * th) + 26, 54.0);
      return ShapeSize(w: d, h: d, dy: 0);
    },
    draw: (w, _, a, line) =>
        '<circle r="${num(w / 2)}"$a/><circle r="${num(w / 2 - 5)}" fill="none"$line/>',
  ),
  'ellipse': _ShapeDef(
    inset: _roundInset,
    span: _roundSpan,
    size: (tw, th) =>
        ShapeSize(w: tw * 1.3 + 2 * PAD_X, h: th * 1.2 + 2 * PAD_Y, dy: 0),
    draw: (w, h, a, _) => '<ellipse rx="${num(w / 2)}" ry="${num(h / 2)}"$a/>',
  ),
  'diam': _ShapeDef(
    inset: (w, h, side, t) =>
        (side & 1) != 0 ? (t.abs() * w) / h : (t.abs() * h) / w,
    span: (w, h, sideways) => (sideways ? h : w) * 0.6,
    size: (tw, th) {
      final a = tw + 16;
      final b = th + 8;
      return ShapeSize(w: a + 1.6 * b, h: a / 1.6 + b, dy: 0);
    },
    draw: (w, h, a, _) =>
        _poly(<double>[0, -h / 2, w / 2, 0, 0, h / 2, -w / 2, 0], a),
  ),
  'hex': _ShapeDef(
    inset: (_, _, side, t) => (side & 1) != 0 ? t.abs() / 2 : 0,
    span: (w, h, sideways) => sideways ? h * 0.5 : w - h / 2 - _corner,
    size: (tw, th) {
      final h = th + 2 * PAD_Y;
      return ShapeSize(w: tw + 2 * PAD_X + h / 2, h: h, dy: 0);
    },
    draw: (w, h, a, _) {
      final m = h / 4;
      return _poly(<double>[
        -w / 2 + m,
        -h / 2,
        w / 2 - m,
        -h / 2,
        w / 2,
        0,
        w / 2 - m,
        h / 2,
        -w / 2 + m,
        h / 2,
        -w / 2,
        0,
      ], a);
    },
  ),
  'odd': _ShapeDef(
    inset: (_, h, side, _) => side == 3 ? h / 4 : 0,
    span: _flatAcross((_) => 0),
    size: (tw, th) {
      final h = th + 2 * PAD_Y;
      return ShapeSize(w: tw + 2 * PAD_X + h / 4, h: h, dy: 0);
    },
    draw: (w, h, a, _) {
      final notch = h / 4;
      return _poly(<double>[
        -w / 2,
        -h / 2,
        w / 2,
        -h / 2,
        w / 2,
        h / 2,
        -w / 2,
        h / 2,
        -w / 2 + notch,
        0,
      ], a);
    },
  ),
  'lean-r': _ShapeDef(
    inset: _leanInset,
    span: _flatAcross((h) => h / 4),
    size: (tw, th) {
      final h = th + 2 * PAD_Y;
      return ShapeSize(w: tw + 2 * PAD_X + h / 2, h: h, dy: 0);
    },
    draw: (w, h, a, _) {
      final s = h / 4;
      return _poly(<double>[
        -w / 2 + s,
        -h / 2,
        w / 2,
        -h / 2,
        w / 2 - s,
        h / 2,
        -w / 2,
        h / 2,
      ], a);
    },
  ),
  'lean-l': _ShapeDef(
    inset: _leanInset,
    span: _flatAcross((h) => h / 4),
    size: (tw, th) {
      final h = th + 2 * PAD_Y;
      return ShapeSize(w: tw + 2 * PAD_X + h / 2, h: h, dy: 0);
    },
    draw: (w, h, a, _) {
      final s = h / 4;
      return _poly(<double>[
        -w / 2,
        -h / 2,
        w / 2 - s,
        -h / 2,
        w / 2,
        h / 2,
        -w / 2 + s,
        h / 2,
      ], a);
    },
  ),
  'trap-b': _ShapeDef(
    inset: _leanInset,
    span: _flatAcross((h) => h / 4),
    size: (tw, th) {
      final h = th + 2 * PAD_Y;
      return ShapeSize(w: tw + 2 * PAD_X + h / 2, h: h, dy: 0);
    },
    draw: (w, h, a, _) {
      final s = h / 4;
      return _poly(<double>[
        -w / 2 + s,
        -h / 2,
        w / 2 - s,
        -h / 2,
        w / 2,
        h / 2,
        -w / 2,
        h / 2,
      ], a);
    },
  ),
  'trap-t': _ShapeDef(
    inset: _leanInset,
    span: _flatAcross((h) => h / 4),
    size: (tw, th) {
      final h = th + 2 * PAD_Y;
      return ShapeSize(w: tw + 2 * PAD_X + h / 2, h: h, dy: 0);
    },
    draw: (w, h, a, _) {
      final s = h / 4;
      return _poly(<double>[
        -w / 2,
        -h / 2,
        w / 2,
        -h / 2,
        w / 2 - s,
        h / 2,
        -w / 2 + s,
        h / 2,
      ], a);
    },
  ),
  'text': _ShapeDef(
    bare: true,
    span: _flat,
    size: (tw, th) => ShapeSize(w: tw + 8, h: th + 8, dy: 0),
    draw: (w, h, _, _) => _rect(w, h, ' fill="none" stroke="none"'),
  ),
  'sm-circ': _ShapeDef(
    noLabel: true,
    inset: _roundInset,
    span: _roundSpan,
    size: _fixed(14, 14),
    draw: (w, _, a, _) => '<circle r="${num(w / 2)}"$a/>',
  ),
  'f-circ': _ShapeDef(
    noLabel: true,
    inset: _roundInset,
    span: _roundSpan,
    size: _fixed(14, 14),
    draw: (w, _, _, line) =>
        '<circle r="${num(w / 2)}" fill="var(--_l)"$line/>',
  ),
  'fr-circ': _ShapeDef(
    noLabel: true,
    inset: _roundInset,
    span: _roundSpan,
    size: _fixed(18, 18),
    draw: (w, _, a, line) =>
        '<circle r="${num(w / 2)}"$a/><circle r="${num(w / 2 - 4)}" fill="var(--_l)"$line/>',
  ),
  'fork': _ShapeDef(
    noLabel: true,
    span: (w, h, sideways) => (sideways ? h : w) - 8,
    size: _fixed(72, 8),
    draw: (w, h, _, line) => _rect(w, h, ' fill="var(--_l)"$line', ' rx="2"'),
  ),
  'notch-rect': _ShapeDef(
    size: _box,
    span: _flat,
    draw: (w, h, a, _) {
      const c = 10.0;
      return _poly(<double>[
        -w / 2 + c,
        -h / 2,
        w / 2,
        -h / 2,
        w / 2,
        h / 2,
        -w / 2,
        h / 2,
        -w / 2,
        -h / 2 + c,
      ], a);
    },
  ),
  'lin-rect': _ShapeDef(
    span: _flat,
    size: (tw, th) =>
        ShapeSize(w: tw + 2 * PAD_X + 8, h: th + 2 * PAD_Y, dy: 0),
    draw: (w, h, a, line) =>
        _rect(w, h, rounded(a)) +
        '<path d="M${num(-w / 2 + 8)},${num(-h / 2)}V${num(h / 2)}" fill="none"$line/>',
  ),
  'div-rect': _ShapeDef(
    span: _flat,
    size: (tw, th) =>
        ShapeSize(w: tw + 2 * PAD_X, h: th + 2 * PAD_Y + 8, dy: 4),
    draw: (w, h, a, line) =>
        _rect(w, h, rounded(a)) +
        '<path d="M${num(-w / 2)},${num(-h / 2 + 8)}H${num(w / 2)}" fill="none"$line/>',
  ),
  'win-pane': _ShapeDef(
    span: _flat,
    size: (tw, th) =>
        ShapeSize(w: tw + 2 * PAD_X + 8, h: th + 2 * PAD_Y + 8, dy: 4),
    draw: (w, h, a, line) =>
        _rect(w, h, rounded(a)) +
        '<path d="M${num(-w / 2 + 8)},${num(-h / 2)}V${num(h / 2)}M${num(-w / 2)},${num(-h / 2 + 8)}H${num(w / 2)}" fill="none"$line/>',
  ),
  'tri': _ShapeDef(
    inset: (w, _, side, _) => (side & 1) != 0 ? w / 4 : 0,
    size: (tw, th) => _triSize(tw, th, false),
    draw: (w, h, a, _) =>
        _poly(<double>[0, -h / 2, w / 2, h / 2, -w / 2, h / 2], a),
  ),
  'flip-tri': _ShapeDef(
    inset: (w, _, side, _) => (side & 1) != 0 ? w / 4 : 0,
    size: (tw, th) => _triSize(tw, th, true),
    draw: (w, h, a, _) =>
        _poly(<double>[-w / 2, -h / 2, w / 2, -h / 2, 0, h / 2], a),
  ),
  'sl-rect': _ShapeDef(
    inset: (_, _, side, _) => side == 0 ? 5 : 0,
    size: (tw, th) =>
        ShapeSize(w: tw + 2 * PAD_X, h: th + 2 * PAD_Y + 10, dy: 5),
    draw: (w, h, a, _) => _poly(<double>[
      -w / 2,
      -h / 2 + 10,
      w / 2,
      -h / 2,
      w / 2,
      h / 2,
      -w / 2,
      h / 2,
    ], a),
  ),
  'notch-pent': _ShapeDef(
    span: _flat,
    size: (tw, th) => ShapeSize(w: tw + 2 * PAD_X, h: th + 2 * PAD_Y, dy: 0),
    draw: (w, h, a, _) {
      const c = 10.0;
      return _poly(<double>[
        -w / 2 + c,
        -h / 2,
        w / 2 - c,
        -h / 2,
        w / 2,
        -h / 2 + c,
        w / 2,
        h / 2,
        -w / 2,
        h / 2,
        -w / 2,
        -h / 2 + c,
      ], a);
    },
  ),
  'hourglass': _ShapeDef(
    noLabel: true,
    inset: (w, _, side, _) => (side & 1) != 0 ? w / 2 : 0,
    size: _fixed(32, 40),
    draw: (w, h, a, _) => _poly(<double>[
      -w / 2,
      -h / 2,
      w / 2,
      -h / 2,
      -w / 2,
      h / 2,
      w / 2,
      h / 2,
    ], a),
  ),
  'delay': _ShapeDef(
    size: (tw, th) {
      final h = th + 2 * PAD_Y;
      return ShapeSize(w: tw + 2 * PAD_X + h / 4, h: h, dy: 0);
    },
    draw: (w, h, a, _) {
      final r = h / 2;
      return '<path d="M${num(-w / 2)},${num(-r)}H${num(w / 2 - r)}A${num(r)},${num(r)} 0 0 1 ${num(w / 2 - r)},${num(r)}H${num(-w / 2)}Z"$a/>';
    },
  ),
  'h-cyl': _ShapeDef(
    size: (tw, th) {
      final h = th + 2 * PAD_Y;
      final rx = math.min(12.0, h / 4);
      return ShapeSize(w: tw + 2 * PAD_X + 2 * rx, h: h, dy: 0);
    },
    draw: (w, h, a, line) {
      final ry = h / 2;
      final rx = math.min(12.0, h / 4);
      final l = -w / 2 + rx;
      final r = w / 2 - rx;
      return '<path d="M${num(l)},${num(-ry)}H${num(r)}A${num(rx)},${num(ry)} 0 0 1 ${num(r)},${num(ry)}H${num(l)}A${num(rx)},${num(ry)} 0 0 1 ${num(l)},${num(-ry)}Z"$a/>'
          '<path d="M${num(r)},${num(-ry)}A${num(rx)},${num(ry)} 0 0 0 ${num(r)},${num(ry)}" fill="none"$line/>';
    },
  ),
  'cross-circ': _ShapeDef(
    noLabel: true,
    inset: _roundInset,
    span: _roundSpan,
    size: _fixed(44, 44),
    draw: (w, _, a, line) {
      final r = w / 2;
      final k = r * math.sqrt1_2;
      return '<circle r="${num(r)}"$a/>'
          '<path d="M${num(-k)},${num(-k)}L${num(k)},${num(k)}M${num(k)},${num(-k)}L${num(-k)},${num(k)}" fill="none"$line/>';
    },
  ),
  'st-rect': _ShapeDef(
    span: (w, h, sideways) => (sideways ? h : w) - 2 * _corner - 8,
    size: (tw, th) =>
        ShapeSize(w: tw + 2 * PAD_X + 8, h: th + 2 * PAD_Y + 8, dy: 4),
    draw: (w, h, a, _) {
      final bw = w - 8;
      final bh = h - 8;
      var out = '';
      for (var i = 0; i < 3; i++) {
        final x = -w / 2 + (2 - i) * 4;
        final y = -h / 2 + i * 4;
        out +=
            '<rect x="${num(x)}" y="${num(y)}" width="${num(bw)}" height="${num(bh)}"${rounded(a)}/>';
      }
      return out;
    },
  ),
  'doc': _ShapeDef(
    inset: (_, _, side, _) => side == 2 ? 10 : 0,
    size: (tw, th) =>
        ShapeSize(w: tw + 2 * PAD_X, h: th + 2 * PAD_Y + 10, dy: -5),
    draw: (w, h, a, _) => _wave(w, h, a),
  ),
  'flag': _ShapeDef(
    inset: (_, _, side, _) => (side & 1) != 0 ? 0 : 8,
    size: (tw, th) =>
        ShapeSize(w: tw + 2 * PAD_X, h: th + 2 * PAD_Y + 16, dy: 0),
    draw: (w, h, a, _) {
      final x = w / 2;
      final y = h / 2 - 8;
      final q = w / 4;
      return '<path d="M${num(-x)},${num(-y)}q${num(q)},-10 ${num(2 * q)},0t${num(2 * q)},0V${num(y)}q${num(-q)},10 ${num(-2 * q)},0t${num(-2 * q)},0Z"$a/>';
    },
  ),
  'datastore': _ShapeDef(
    size: _box,
    span: _flat,
    draw: (w, h, a, line) =>
        _rect(w, h, a.replaceFirst('stroke="var(--_b)"', 'stroke="none"')) +
        '<path d="M${num(-w / 2)},${num(-h / 2)}H${num(w / 2)}M${num(-w / 2)},${num(h / 2)}H${num(w / 2)}" fill="none"$line/>',
  ),
  'folder': _ShapeDef(
    size: (tw, th) => ShapeSize(
      w: math.max(tw + 2 * PAD_X, 64.0),
      h: th + 2 * PAD_Y + 8,
      dy: 4,
    ),
    draw: (w, h, a, _) {
      final x = w / 2;
      final y = h / 2;
      final tab = math.min(w * 0.4, 48.0);
      return _path(
        'M${num(-x)},${num(-y)}H${num(-x + tab)}L${num(-x + tab + 8)},${num(-y + 8)}H${num(x)}V${num(y)}H${num(-x)}Z',
        a,
      );
    },
  ),
  'bucket': _ShapeDef(
    size: (tw, th) =>
        ShapeSize(w: tw + 2 * PAD_X + 20, h: th + 2 * PAD_Y + 10, dy: 3),
    inset: (_, h, side, _) => (side & 1) != 0 ? h / 12 : 0,
    draw: (w, h, a, line) {
      final x = w / 2;
      final y = h / 2;
      const ry = 5.0;
      final taper = h / 6;
      return _path(
            'M${num(-x)},${num(-y + ry)}A${num(x)},${num(ry)} 0 0 1 ${num(x)},${num(-y + ry)}L${num(x - taper)},${num(y - ry)}A${num(x - taper)},${num(ry)} 0 0 1 ${num(-x + taper)},${num(y - ry)}Z',
            a,
          ) +
          '<path d="M${num(-x)},${num(-y + ry)}A${num(x)},${num(ry)} 0 0 0 ${num(x)},${num(-y + ry)}" fill="none"$line/>';
    },
  ),
  'console': _ShapeDef(
    span: _flat,
    size: (tw, th) => ShapeSize(
      w: math.max(tw + 2 * PAD_X, 72.0),
      h: th + 2 * PAD_Y + 12,
      dy: 6,
    ),
    draw: (w, h, a, line) =>
        _rect(w, h, rounded(a)) +
        '<path d="M${num(-w / 2)},${num(-h / 2 + 12)}H${num(w / 2)}M${num(-w / 2 + 7)},${num(-h / 2 + 4)}l3,2.5l-3,2.5M${num(-w / 2 + 13)},${num(-h / 2 + 9)}h4" fill="none"$line/>',
  ),
  'browser': _ShapeDef(
    span: _flat,
    size: (tw, th) => ShapeSize(
      w: math.max(tw + 2 * PAD_X, 72.0),
      h: th + 2 * PAD_Y + 12,
      dy: 6,
    ),
    draw: (w, h, a, line) {
      var dots = '';
      for (var i = 0; i < 3; i++) {
        dots +=
            '<circle cx="${num(-w / 2 + 8 + i * 7)}" cy="${num(-h / 2 + 6)}" r="1.5" fill="none"$line/>';
      }
      return _rect(w, h, rounded(a)) +
          '<path d="M${num(-w / 2)},${num(-h / 2 + 12)}H${num(w / 2)}" fill="none"$line/>' +
          dots;
    },
  ),
  'person': _ShapeDef(
    size: (tw, th) => ShapeSize(
      w: math.max(tw + 2 * PAD_X, 56.0),
      h: th + 2 * PAD_Y + 26,
      dy: 13,
    ),
    draw: (w, h, a, _) {
      final top = -h / 2;
      return '<rect x="${num(-w / 2)}" y="${num(top + 26)}" width="${num(w)}" height="${num(h - 26)}" rx="12"$a/>'
          '<circle cy="${num(top + 14)}" r="13"$a/>';
    },
  ),
  'bang': _ShapeDef(
    size: (tw, th) =>
        ShapeSize(w: tw + 2 * PAD_X + 28, h: th + 2 * PAD_Y + 24, dy: 0),
    inset: (_, _, _, _) => 3,
    draw: (w, h, a, _) {
      const spikes = 14;
      final pts = <double>[];
      for (var i = 0; i < spikes * 2; i++) {
        final angle = (math.pi * i) / spikes - math.pi / 2;
        final k = i % 2 == 0 ? 1.0 : 0.82;
        pts.addAll(<double>[
          math.cos(angle) * (w / 2) * k,
          math.sin(angle) * (h / 2) * k,
        ]);
      }
      return _poly(pts, a);
    },
  ),
  'cloud': _ShapeDef(
    size: (tw, th) =>
        ShapeSize(w: tw + 2 * PAD_X + 32, h: th + 2 * PAD_Y + 24, dy: 0),
    inset: (_, _, side, _) => (side & 1) != 0 ? 2 : 1,
    draw: (w, h, a, _) {
      final x = w / 2;
      final y = h / 2;
      final r = y * 0.55;
      return _path(
        'M${num(-x + r)},${num(y)}A${num(r)},${num(r)} 0 0 1 ${num(-x + r * 0.6)},${num(-y * 0.1)}A${num(x * 0.42)},${num(y * 0.7)} 0 0 1 ${num(-x * 0.1)},${num(-y * 0.72)}A${num(x * 0.4)},${num(y * 0.62)} 0 0 1 ${num(x * 0.62)},${num(-y * 0.42)}A${num(r * 1.05)},${num(r * 1.05)} 0 0 1 ${num(x - r)},${num(y)}Z',
        a,
      );
    },
  ),
  'brace': _ShapeDef(
    bare: true,
    size: (tw, th) =>
        ShapeSize(w: tw + 2 * PAD_X + 12, h: th + 2 * PAD_Y, dy: 0),
    draw: (w, h, _, line) =>
        _rect(w, h, ' fill="none" stroke="none"') +
        _brace(-w / 2 + 12, h, -1, line),
  ),
  'brace-r': _ShapeDef(
    bare: true,
    size: (tw, th) =>
        ShapeSize(w: tw + 2 * PAD_X + 12, h: th + 2 * PAD_Y, dy: 0),
    draw: (w, h, _, line) =>
        _rect(w, h, ' fill="none" stroke="none"') +
        _brace(w / 2 - 12, h, 1, line),
  ),
  'braces': _ShapeDef(
    bare: true,
    size: (tw, th) =>
        ShapeSize(w: tw + 2 * PAD_X + 24, h: th + 2 * PAD_Y, dy: 0),
    draw: (w, h, _, line) =>
        _rect(w, h, ' fill="none" stroke="none"') +
        _brace(-w / 2 + 12, h, -1, line) +
        _brace(w / 2 - 12, h, 1, line),
  ),
  'bolt': _ShapeDef(
    noLabel: true,
    size: _fixed(36, 56),
    inset: (w, _, side, _) => (side & 1) != 0 ? w / 4 : 0,
    draw: (w, h, a, _) => _poly(<double>[
      w * 0.15,
      -h / 2,
      -w / 2,
      h * 0.08,
      -w * 0.05,
      h * 0.08,
      -w * 0.15,
      h / 2,
      w / 2,
      -h * 0.08,
      w * 0.05,
      -h * 0.08,
    ], a),
  ),
  'lin-cyl': _ShapeDef(
    inset: _capInset,
    span: (w, h, sideways) => sideways ? h - 2 * _corner - 20 : w * 0.6,
    size: (tw, th) {
      final w = math.max(tw + 2 * PAD_X, 56.0);
      final ry = math.min(12.0, math.max(6.0, w / 14));
      return ShapeSize(w: w, h: th + 2 * PAD_Y + 2 * ry + 8, dy: ry / 2 + 4);
    },
    draw: (w, h, a, line) {
      final rx = w / 2;
      final ry = math.min(12.0, math.max(6.0, w / 14));
      final top = -h / 2 + ry;
      final bottom = h / 2 - ry;
      String arc(double y) =>
          'M${num(-rx)},${num(y)}A${num(rx)},${num(ry)} 0 0 0 ${num(rx)},${num(y)}';
      return _path(
            'M${num(-rx)},${num(top)}A${num(rx)},${num(ry)} 0 0 1 ${num(rx)},${num(top)}V${num(bottom)}A${num(rx)},${num(ry)} 0 0 1 ${num(-rx)},${num(bottom)}Z',
            a,
          ) +
          '<path d="${arc(top)}${arc(top + 8)}" fill="none"$line/>';
    },
  ),
  'curv-trap': _ShapeDef(
    size: (tw, th) {
      final h = th + 2 * PAD_Y;
      return ShapeSize(w: tw + 2 * PAD_X + h * 0.6, h: h, dy: 0);
    },
    draw: (w, h, a, _) {
      final x = w / 2;
      final y = h / 2;
      final k = h * 0.3;
      return _path(
        'M${num(-x + k)},${num(-y)}H${num(x - k)}A${num(k)},${num(y)} 0 0 1 ${num(x - k)},${num(y)}H${num(-x + k)}L${num(-x)},0Z',
        a,
      );
    },
  ),
  'docs': _ShapeDef(
    size: (tw, th) =>
        ShapeSize(w: tw + 2 * PAD_X + 8, h: th + 2 * PAD_Y + 18, dy: -1),
    inset: (_, _, side, _) => side == 2 ? 10 : 0,
    draw: (w, h, a, _) {
      var out = '';
      for (var i = 0; i < 3; i++) {
        out +=
            '<g transform="translate(${(1 - i) * 4},${(i - 1) * 4})">${_wave(w - 8, h - 8, a)}</g>';
      }
      return out;
    },
  ),
  'bow-rect': _ShapeDef(
    size: (tw, th) {
      final h = th + 2 * PAD_Y;
      return ShapeSize(w: tw + 2 * PAD_X + h * 0.4, h: h, dy: 0);
    },
    inset: (_, h, side, _) => side == 1 ? h * 0.2 : 0,
    draw: (w, h, a, _) {
      final x = w / 2;
      final y = h / 2;
      final k = h * 0.2;
      return _path(
        'M${num(-x + k)},${num(-y)}H${num(x)}A${num(k)},${num(y)} 0 0 0 ${num(x)},${num(y)}H${num(-x + k)}A${num(k)},${num(y)} 0 0 1 ${num(-x + k)},${num(-y)}Z',
        a,
      );
    },
  ),
  'tag-rect': _ShapeDef(
    size: _box,
    span: _flat,
    draw: (w, h, a, line) =>
        _rect(w, h, rounded(a)) +
        '<path d="M${num(w / 2 - 12)},${num(h / 2)}L${num(w / 2)},${num(h / 2 - 12)}" fill="none"$line/>',
  ),
  'tag-doc': _ShapeDef(
    size: (tw, th) =>
        ShapeSize(w: tw + 2 * PAD_X, h: th + 2 * PAD_Y + 10, dy: -5),
    inset: (_, _, side, _) => side == 2 ? 10 : 0,
    draw: (w, h, a, line) =>
        _wave(w, h, a) +
        '<path d="M${num(w / 2 - 12)},${num(h / 2 - 14)}L${num(w / 2)},${num(h / 2 - 26)}" fill="none"$line/>',
  ),
  'lin-doc': _ShapeDef(
    size: (tw, th) =>
        ShapeSize(w: tw + 2 * PAD_X + 8, h: th + 2 * PAD_Y + 10, dy: -5),
    inset: (_, _, side, _) => side == 2 ? 10 : 0,
    draw: (w, h, a, line) =>
        _wave(w, h, a) +
        '<path d="M${num(-w / 2 + 8)},${num(-h / 2)}V${num(h / 2 - 6)}" fill="none"$line/>',
  ),
  'collapsedGroup': _ShapeDef(
    size: (tw, th) =>
        ShapeSize(w: tw + 2 * PAD_X + 8, h: th + 2 * PAD_Y + 8, dy: -2),
    draw: (w, h, a, _) =>
        '<rect x="${num(-w / 2 + 6)}" y="${num(-h / 2 + 8)}" width="${num(w - 12)}" height="${num(h - 8)}"${rounded(a)}/>'
        '<rect x="${num(-w / 2)}" y="${num(-h / 2)}" width="${num(w)}" height="${num(h - 4)}"${rounded(a)}/>',
  ),
};

final _ShapeDef _fallback = _shapes['rect']!;

ShapeSize shapeSize(String shape, double tw, double th) {
  return (_shapes[shape] ?? _fallback).size(tw, th);
}

String drawShape(String shape, double w, double h, String a, String line) {
  return (_shapes[shape] ?? _fallback).draw(w, h, a, line);
}

double shapeInset(String shape, double w, double h, int side, [double t = 0]) {
  return _shapes[shape]?.inset?.call(w, h, side, t) ?? 0;
}

double shapeSpan(String shape, double w, double h, bool sideways) {
  return math.max(0.0, _shapes[shape]?.span?.call(w, h, sideways) ?? 0.0);
}

bool shapeHasLabel(String shape) {
  return _shapes[shape]?.noLabel != true;
}

bool shapeFilled(String shape) {
  return (_shapes[shape] ?? _fallback).bare != true;
}

int endSide(List<double> route, int at, CNode c) {
  final dx = route[at] - c.x;
  final dy = route[at + 1] - c.y;
  if ((dy.abs() - c.h / 2).abs() < 0.5) return dy < 0 ? 0 : 2;
  if ((dx.abs() - c.w / 2).abs() < 0.5) return dx < 0 ? 3 : 1;
  return -1;
}

void insetRoute(List<double> route, int at, dynamic view, CNode c) {
  if (c.isGroup) return;
  final shape = view.shape as String;
  final vw = (view.w as double);
  final vh = (view.h as double);
  final side = endSide(route, at, c);
  if (side == 0 || side == 2) {
    final amount =
        shapeInset(shape, vw, vh, side, route[at] - c.x) + (c.h - vh) / 2;
    route[at + 1] += side == 0 ? amount : -amount;
  } else if (side >= 0) {
    final amount =
        shapeInset(shape, vw, vh, side, route[at + 1] - c.y) + (c.w - vw) / 2;
    route[at] += side == 3 ? amount : -amount;
  }
}

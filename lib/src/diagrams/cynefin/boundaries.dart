// Upstream: src/diagrams/cynefin/boundaries.ts

import '../../svg/builder.dart';

// The geometry of Mermaid's Cynefin boundaries: seeded wavy lines between the domains and the
// S-shaped cliff between Clear and Chaotic. Curves are flat lists of numbers: a start point, then
// six numbers (two control points and an end point) per cubic segment.

int _i32(double v) => v.truncate().toSigned(32);
int _u32(int v) => v.toUnsigned(32);
int _imul(int a, int b) => (a.toSigned(32) * b.toSigned(32)).toSigned(32);

// mulberry32, one step.
double seededRandom(double seed) {
  var t = _i32(seed + 0x6d2b79f5);
  t = _imul(t ^ (_u32(t) >> 15), t | 1);
  t = (t ^ (t + _imul(t ^ (_u32(t) >> 7), t | 61))).toSigned(32);
  return _u32(t ^ (_u32(t) >> 14)) / 4294967296.0;
}

int hashString(String str) {
  var hash = 0;
  for (var i = 0; i < str.length; i++) {
    hash = ((hash << 5) - hash + str.codeUnitAt(i)).toSigned(32);
  }
  return hash;
}

// A configured seed other than zero wins; otherwise the seed comes from the diagram's id.
double resolveSeed(double? configured, String id) {
  if (configured != null && configured.isFinite && configured != 0) {
    return configured;
  }
  return hashString(id).toDouble();
}

class WaveOptions {
  final int segments;
  final bool vertical;
  // Multipliers Mermaid uses to vary the seed per point and per control point.
  final int pointStep;
  final int controlStep;
  final int controlShift;
  final bool pinStart;
  final bool pinEnd;

  const WaveOptions({
    required this.segments,
    required this.vertical,
    required this.pointStep,
    required this.controlStep,
    required this.controlShift,
    this.pinStart = false,
    this.pinEnd = false,
  });

  WaveOptions copyWith({
    int? segments,
    bool? vertical,
    int? pointStep,
    int? controlStep,
    int? controlShift,
    bool? pinStart,
    bool? pinEnd,
  }) => WaveOptions(
    segments: segments ?? this.segments,
    vertical: vertical ?? this.vertical,
    pointStep: pointStep ?? this.pointStep,
    controlStep: controlStep ?? this.controlStep,
    controlShift: controlShift ?? this.controlShift,
    pinStart: pinStart ?? this.pinStart,
    pinEnd: pinEnd ?? this.pinEnd,
  );
}

const WaveOptions FOLD = WaveOptions(
  segments: 7,
  vertical: true,
  pointStep: 17,
  controlStep: 31,
  controlShift: 7,
);

const WaveOptions HORIZON = WaveOptions(
  segments: 7,
  vertical: false,
  pointStep: 23,
  controlStep: 37,
  controlShift: 11,
);

// A wavy line along one axis from `from` to `to`, centered on `center` in the other axis.
// Points jitter by up to the amplitude; a pinned end stays on the center line.
List<double> wave(
  double from,
  double to,
  double center,
  double seed,
  double amplitude,
  WaveOptions o,
) {
  final step = (to - from) / o.segments;
  final along = <double>[];
  final across = <double>[];
  for (var i = 0; i <= o.segments; i++) {
    final pinned = (i == 0 && o.pinStart) || (i == o.segments && o.pinEnd);
    along.add(from + i * step);
    across.add(
      pinned
          ? center
          : center +
                seededRandom(seed + i * o.pointStep) * amplitude * 2 -
                amplitude,
    );
  }
  final out = o.vertical
      ? <double>[across[0], along[0]]
      : <double>[along[0], across[0]];
  for (var i = 0; i < o.segments; i++) {
    final mid = (along[i] + along[i + 1]) / 2;
    final offset =
        amplitude *
        1.5 *
        (i % 2 == 0 ? 1 : -1) *
        seededRandom(seed + i * o.controlStep + o.controlShift);
    if (o.vertical) {
      out.addAll(<double>[
        across[i] + offset,
        mid,
        across[i + 1] - offset,
        mid,
        across[i + 1],
        along[i + 1],
      ]);
    } else {
      out.addAll(<double>[
        mid,
        across[i] + offset,
        mid,
        across[i + 1] - offset,
        along[i + 1],
        across[i + 1],
      ]);
    }
  }
  return out;
}

// The cliff: a steep S from (cx, top) down to (cx, bottom).
List<double> cliff(double cx, double top, double bottom, double amplitude) {
  final h = bottom - top;
  return <double>[
    cx,
    top,
    cx + amplitude,
    top + h * 0.2,
    cx - amplitude * 1.5,
    top + h * 0.55,
    cx + amplitude * 0.5,
    top + h * 0.75,
    cx - amplitude,
    top + h * 0.85,
    cx + amplitude * 0.3,
    top + h * 0.95,
    cx,
    bottom,
  ];
}

// Path commands that continue from the curve's start point to its end.
String forward(List<double> curve) {
  final d = StringBuffer();
  for (var i = 2; i < curve.length; i += 6) {
    d.write(
      'C${num(curve[i])},${num(curve[i + 1])} ${num(curve[i + 2])},${num(curve[i + 3])} ${num(curve[i + 4])},${num(curve[i + 5])}',
    );
  }
  return d.toString();
}

// Path commands that continue from the curve's end point back to its start.
String backward(List<double> curve) {
  final d = StringBuffer();
  for (var i = curve.length - 6; i >= 2; i -= 6) {
    d.write(
      'C${num(curve[i + 2])},${num(curve[i + 3])} ${num(curve[i])},${num(curve[i + 1])} ${num(curve[i - 2])},${num(curve[i - 1])}',
    );
  }
  return d.toString();
}

String curvePath(List<double> curve) {
  return 'M${num(curve[0])},${num(curve[1])}${forward(curve)}';
}

String ellipsePath(double cx, double cy, double rx, double ry) {
  final r = '${num(rx)},${num(ry)}';
  return 'M${num(cx - rx)},${num(cy)}A$r 0 1,1 ${num(cx + rx)},${num(cy)}A$r 0 1,1 ${num(cx - rx)},${num(cy)}Z';
}

// Upstream: src/diagrams/xychart/ticks.ts

import 'dart:math' as math;

import '../../util/math_js.dart';

// A step of 1, 2 or 5 times a power of ten that divides `span` into about `count` parts.
// A step below one comes back as the negative of its inverse, which is a whole number, so that
// tick values are found by division and print without rounding noise (0.3, not 0.30000000000000004).
double tickStep(double span, int count) {
  final raw = span / math.max<int>(count, 1);
  final power = (math.log(raw) / math.ln10).floor();
  final p10 = math.pow(10, power).toDouble();
  final unit = raw / p10;
  final factor = unit >= 7.07
      ? 10
      : unit >= 3.16
      ? 5
      : unit >= 1.41
      ? 2
      : 1;
  return power < 0 ? -math.pow(10, -power).toDouble() / factor : factor * p10;
}

double tickIndex(double step, double value) {
  return step > 0 ? value / step : value * -step;
}

double tickValue(double step, int index) {
  return step > 0 ? index * step : index / -step;
}

// The multiples of a step from `lo` to `hi`, both included.
List<double> ticksBetween(double lo, double hi, double step) {
  var first = roundJs(tickIndex(step, lo));
  if (tickValue(step, first) < lo) first++;
  var last = roundJs(tickIndex(step, hi));
  if (tickValue(step, last) > hi) last--;
  final out = <double>[];
  for (var i = first; i <= last && out.length < 100; i++) {
    out.add(tickValue(step, i));
  }
  return out;
}

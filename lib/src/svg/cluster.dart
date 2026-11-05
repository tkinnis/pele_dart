// Upstream: src/svg/cluster.ts

import 'dart:math' as math;

import '../layout/compound.dart';
import '../text/label.dart';
import '../util/math_js.dart';
import 'builder.dart';

typedef Crossings = Map<int, List<double>>;

void markCrossings(Crossings crossings, List<double> route) {
  for (var k = 0; k < route.length; k += 3) {
    final key = roundJs(route[k + 1]);
    final list = crossings[key];
    if (list != null) {
      list.add(route[k]);
    } else {
      crossings[key] = <double>[route[k]];
    }
  }
}

double clusterTitleX(CNode c, double width, Crossings crossings, double pad) {
  if (width == 0) return c.x;
  final top = c.y - c.h / 2;
  final left = c.x - c.w / 2;
  final half = width / 2;
  final candidates = <double>[
    left + pad - 6 + half,
    c.x,
    left + c.w - pad + 6 - half,
  ];
  final xs = crossings[roundJs(top)];
  if (xs == null) return candidates[0];
  var best = candidates[0];
  var bestGap = -1.0;
  for (final x in candidates) {
    var gap = double.infinity;
    for (final cx in xs) {
      if (cx > left && cx < left + c.w) {
        gap = math.min(gap, (cx - x).abs() - half);
      }
    }
    if (gap >= 6) return x;
    if (gap > bestGap + 0.5) {
      bestGap = gap;
      best = x;
    }
  }
  return best;
}

bool titleCrossed(CNode c, double width, double x, Crossings crossings) {
  final xs = width > 0 ? crossings[roundJs(c.y - c.h / 2)] : null;
  if (xs == null) return false;
  final left = c.x - c.w / 2;
  for (final cx in xs) {
    if (cx > left && cx < left + c.w && (cx - x).abs() < width / 2 + 4) {
      return true;
    }
  }
  return false;
}

String struckTitle(
  Label label,
  double x,
  double y,
  String attrs,
  String id,
  List<dynamic> nodes,
  int index, [
  IconResolver? icons,
]) {
  var depth = 1;
  for (
    var p = (nodes[index] as dynamic).parent as int;
    p >= 0 && depth < 8;
    p = (nodes[p] as dynamic).parent as int
  ) {
    depth++;
  }
  final fill =
      'color-mix(in srgb,var(--_a) ${num(100 * (1 - math.pow(0.5, depth).toDouble()))}%,var(--_bg))';
  return '<g class="pele-cluster-title" data-id="$id">'
      '${labelSvg(label, x, y, ' fill="none" stroke="$fill" stroke-width="5" stroke-linejoin="round"', icons)}'
      '${labelSvg(label, x, y, attrs, icons)}'
      '</g>';
}

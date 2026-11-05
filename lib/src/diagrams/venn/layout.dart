// Upstream: src/diagrams/venn/layout.ts

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../util/math_js.dart';
import 'types.dart';

class Circle {
  final String id;
  double x;
  double y;
  final double r;

  Circle({required this.id, required this.x, required this.y, required this.r});
}

// Where the content of a region goes: the point inside all of `inside` and outside every other
// circle that is farthest from their outlines, and how far that is. A margin of 0 or less means
// the circles as placed leave the region empty.
class Spot {
  final double x;
  final double y;
  final double margin;

  const Spot({required this.x, required this.y, required this.margin});
}

const double _tau = math.pi * 2;

// For every overlap of three or more sets, adds the pairwise overlaps it implies and the diagram
// does not state, a quarter of the smaller set each, so that the circles are drawn overlapping.
// Returns the list it was given when there is nothing to add.
List<VennSubset> ensurePairwiseSubsets(List<VennSubset> subsets) {
  final present = <String>{};
  final sizes = <String, double>{};
  for (final subset in subsets) {
    final sorted = List<String>.of(subset.sets)..sort();
    present.add(jsonEncode(sorted));
    if (subset.sets.length == 1) {
      sizes[subset.sets[0]] = subset.size;
    }
  }
  final added = <VennSubset>[];
  for (final subset in subsets) {
    if (subset.sets.length < 3) continue;
    final members = List<String>.of(subset.sets)..sort();
    for (var i = 0; i < members.length - 1; i++) {
      for (var j = i + 1; j < members.length; j++) {
        final pair = <String>[members[i], members[j]];
        final key = jsonEncode(pair);
        if (present.contains(key)) continue;
        present.add(key);
        final a = sizes[pair[0]];
        final b = sizes[pair[1]];
        added.add(
          VennSubset(
            sets: pair,
            size: a != null && b != null ? math.min(a, b) / 4 : 2.5,
            label: '',
          ),
        );
      }
    }
  }
  return added.isNotEmpty ? <VennSubset>[...subsets, ...added] : subsets;
}

// The area two circles share when their centers are d apart.
double lensArea(double r1, double r2, double d) {
  if (d >= r1 + r2) return 0;
  final small = math.min(r1, r2);
  if (d <= (r1 - r2).abs()) return math.pi * small * small;
  final a1 = r1 * r1 * math.acos((d * d + r1 * r1 - r2 * r2) / (2 * d * r1));
  final a2 = r2 * r2 * math.acos((d * d + r2 * r2 - r1 * r1) / (2 * d * r2));
  final a3 =
      0.5 *
      math.sqrt(
        math.max(
          (-d + r1 + r2) * (d + r1 - r2) * (d - r1 + r2) * (d + r1 + r2),
          0.0,
        ),
      );
  return a1 + a2 - a3;
}

// How far apart two circles sit for their overlap to have the given area. The area falls as the
// distance grows, so bisection finds it.
double distanceForOverlap(double r1, double r2, double area) {
  var low = (r1 - r2).abs();
  var high = r1 + r2;
  if (!(area > 0)) return high;
  final small = math.min(r1, r2);
  if (area >= math.pi * small * small) return low;
  for (var i = 0; i < 48; i++) {
    final middle = (low + high) / 2;
    if (lensArea(r1, r2, middle) > area) {
      low = middle;
    } else {
      high = middle;
    }
  }
  return (low + high) / 2;
}

// How far a point is from the nearest outline it must stay within or without. Gives up, with
// some value below `floor`, as soon as the point cannot reach `floor`.
double _margin(
  List<Circle> circles,
  List<int> inside,
  List<int> outside,
  double x,
  double y,
  double floor,
) {
  var best = double.infinity;
  for (final i in inside) {
    final c = circles[i];
    final dx = x - c.x;
    final dy = y - c.y;
    final room = c.r - math.sqrt(dx * dx + dy * dy);
    if (room < best) {
      if (room < floor) return room;
      best = room;
    }
  }
  for (final i in outside) {
    final c = circles[i];
    final dx = x - c.x;
    final dy = y - c.y;
    final room = math.sqrt(dx * dx + dy * dy) - c.r;
    if (room < best) {
      if (room < floor) return room;
      best = room;
    }
  }
  return best;
}

// Finds the roomiest point of a region by sampling the smallest of its circles on a grid and then
// walking uphill from the best sample. Ties go to the point nearest the middle of the region, so
// a symmetric arrangement gets symmetric labels.
Spot findSpot(List<Circle> circles, List<int> inside, List<int> outside) {
  var cx = 0.0;
  var cy = 0.0;
  var smallest = circles[inside[0]];
  for (final i in inside) {
    final c = circles[i];
    cx += c.x / inside.length;
    cy += c.y / inside.length;
    if (c.r < smallest.r) smallest = c;
  }
  final r = smallest.r;
  var x = cx;
  var y = cy;
  var best = _margin(circles, inside, outside, x, y, double.negativeInfinity);
  var off = 0.0;

  bool consider(double px, double py) {
    final m = _margin(circles, inside, outside, px, py, best - r * 1e-9);
    if (!(m > best - r * 1e-9)) return false;
    final distance = hypot(px - cx, py - cy);
    if (m > best + r * 1e-9 || distance < off - r * 1e-9) {
      best = m;
      off = distance;
      x = px;
      y = py;
      return true;
    }
    return false;
  }

  const grid = 10;
  for (var gy = -grid; gy <= grid; gy++) {
    for (var gx = -grid; gx <= grid; gx++) {
      if (gx * gx + gy * gy <= grid * grid) {
        consider(smallest.x + (gx * r) / grid, smallest.y + (gy * r) / grid);
      }
    }
  }
  var step = r / grid;
  for (var round = 0; round < 40 && step > r * 1e-6; round++) {
    var moved = false;
    for (var k = 0; k < 8; k++) {
      final angle = (k * _tau) / 8;
      if (consider(x + math.cos(angle) * step, y + math.sin(angle) * step)) {
        moved = true;
      }
    }
    if (!moved) step /= 2;
  }
  return Spot(x: x, y: y, margin: best);
}

// Places one circle per set, with areas in proportion to the sizes of the sets and each pair as
// far apart as its overlap asks: one, two and three sets exactly, more by relaxing a ring of
// circles toward those distances. Lengths are in units of the square root of a size.
List<Circle> layoutCircles(List<VennSubset> subsets) {
  final sizes = <String, double>{};
  for (final subset in subsets) {
    for (final id in subset.sets) {
      sizes.putIfAbsent(id, () => 10);
    }
  }
  for (final subset in subsets) {
    if (subset.sets.length == 1) {
      sizes[subset.sets[0]] = subset.size;
    }
  }

  final index = <String, int>{};
  final circles = <Circle>[];
  var largest = 0.0;
  for (final size in sizes.values) {
    if (size.isFinite && size > largest) largest = size;
  }
  if (largest == 0) largest = 10;
  final widest = math.sqrt(largest / math.pi);
  for (final entry in sizes.entries) {
    final id = entry.key;
    final size = entry.value;
    index[id] = circles.length;
    // A set too small to hold its name, or with no size at all, still gets a circle that shows.
    final r = size.isFinite && size > 0 ? math.sqrt(size / math.pi) : 0.0;
    circles.add(Circle(id: id, x: 0, y: 0, r: math.max(r, widest * 0.3)));
  }
  final n = circles.length;
  if (n < 2) return circles;

  // The overlap each pair was given, by the indexes of its circles.
  final overlaps = <int, double>{};
  for (final subset in ensurePairwiseSubsets(subsets)) {
    if (subset.sets.length != 2) continue;
    final a = index[subset.sets[0]]!;
    final b = index[subset.sets[1]]!;
    if (a != b) {
      overlaps[math.min(a, b) * n + math.max(a, b)] = subset.size;
    }
  }
  // How far apart each overlapping pair should be. Pairs that do not overlap only have to keep a gap.
  final wanted = <int, double>{};
  for (final entry in overlaps.entries) {
    final key = entry.key;
    final area = entry.value;
    wanted[key] = distanceForOverlap(
      circles[key ~/ n].r,
      circles[key % n].r,
      area,
    );
  }
  final gap = widest * 0.15;
  double distance(int a, int b) =>
      wanted[a * n + b] ?? (circles[a].r + circles[b].r + gap);

  if (n == 2) {
    circles[1].x = distance(0, 1);
    return circles;
  }

  if (n == 3) {
    // Two sets side by side and the third below, the corners of a triangle whose sides are the
    // three distances. An overlap of all three has to exist, so the triangle shrinks until it does.
    var ab = distance(0, 1);
    var ac = distance(0, 2);
    var bc = distance(1, 2);
    final triple = subsets.any((subset) => subset.sets.toSet().length == 3);
    for (var attempt = 0; attempt < 40; attempt++) {
      final x = ab > 0 ? (ab * ab + ac * ac - bc * bc) / (2 * ab) : 0.0;
      circles[1].x = ab;
      circles[2].x = math.max(-ac, math.min(ac, x));
      circles[2].y = math.sqrt(math.max(ac * ac - x * x, 0.0));
      if (!triple ||
          findSpot(circles, const <int>[0, 1, 2], const <int>[]).margin >
              widest * 0.12) {
        break;
      }
      ab *= 0.94;
      ac *= 0.94;
      bc *= 0.94;
    }
    return circles;
  }

  var total = 0.0;
  for (final c in circles) {
    total += 2 * c.r + gap;
  }
  final rounds = math.min<int>(300, (3e6 / (n * n)).floor());
  if (n <= 64) {
    final ring = total / _tau;
    for (var i = 0; i < n; i++) {
      final c = circles[i];
      final angle = (i * _tau) / n - math.pi / 2;
      c.x = math.cos(angle) * ring;
      c.y = math.sin(angle) * ring;
    }
  } else {
    final columns = math.sqrt(n).ceil();
    final cell = 2 * widest + gap;
    for (var i = 0; i < n; i++) {
      final c = circles[i];
      c.x = (i % columns) * cell;
      c.y = (i ~/ columns) * cell;
    }
  }
  final dx = Float64List(n);
  final dy = Float64List(n);
  final pulls = Int32List(n);
  for (var round = 0; round < rounds; round++) {
    dx.fillRange(0, n, 0);
    dy.fillRange(0, n, 0);
    pulls.fillRange(0, n, 0);
    for (var a = 0; a < n; a++) {
      for (var b = a + 1; b < n; b++) {
        final overlap = wanted[a * n + b];
        final apart = circles[a].r + circles[b].r + gap;
        var ux = circles[b].x - circles[a].x;
        var uy = circles[b].y - circles[a].y;
        var length = hypot(ux, uy);
        if (overlap == null && length >= apart) continue;
        if (length < 1e-9) {
          ux = math.cos(a + b);
          uy = math.sin(a + b);
          length = 1;
        }
        final move = (length - (overlap ?? apart)) / 2 / length;
        dx[a] += ux * move;
        dy[a] += uy * move;
        dx[b] -= ux * move;
        dy[b] -= uy * move;
        pulls[a]++;
        pulls[b]++;
      }
    }
    for (var i = 0; i < n; i++) {
      if (pulls[i] == 0) continue;
      circles[i].x += dx[i] / pulls[i];
      circles[i].y += dy[i] / pulls[i];
    }
  }
  return circles;
}

class _Corner {
  final double x;
  final double y;
  final Circle a;
  final Circle b;

  const _Corner({
    required this.x,
    required this.y,
    required this.a,
    required this.b,
  });
}

// The outline of the region all the given circles share, as an SVG path, or '' if they share none.
String regionPath(List<Circle> circles, String Function(double value) format) {
  String whole(Circle c) =>
      'M${format(c.x - c.r)},${format(c.y)}A${format(c.r)},${format(c.r)} 0 1 1 ${format(c.x + c.r)},${format(c.y)}A${format(c.r)},${format(c.r)} 0 1 1 ${format(c.x - c.r)},${format(c.y)}Z';

  if (circles.length == 1) return whole(circles[0]);
  bool within(double x, double y, Circle? skip, Circle? other) {
    for (final c in circles) {
      if (!identical(c, skip) &&
          !identical(c, other) &&
          hypot(x - c.x, y - c.y) > c.r * (1 + 1e-9)) {
        return false;
      }
    }
    return true;
  }

  // The corners of the region: where two outlines cross inside all the other circles.
  final corners = <_Corner>[];
  for (var i = 0; i < circles.length; i++) {
    for (var j = i + 1; j < circles.length; j++) {
      final a = circles[i];
      final b = circles[j];
      final d = hypot(b.x - a.x, b.y - a.y);
      if (d >= a.r + b.r || d <= (a.r - b.r).abs() || d == 0) continue;
      final along = (a.r * a.r - b.r * b.r + d * d) / (2 * d);
      final up = math.sqrt(math.max(a.r * a.r - along * along, 0.0));
      final mx = a.x + ((b.x - a.x) * along) / d;
      final my = a.y + ((b.y - a.y) * along) / d;
      for (final sign in const <int>[1, -1]) {
        final x = mx + (sign * up * (b.y - a.y)) / d;
        final y = my - (sign * up * (b.x - a.x)) / d;
        if (within(x, y, a, b)) {
          corners.add(_Corner(x: x, y: y, a: a, b: b));
        }
      }
    }
  }
  if (corners.length < 2) {
    // No corners: either one circle lies inside all the others, or there is nothing shared.
    var smallest = circles[0];
    for (final c in circles) {
      if (c.r < smallest.r) smallest = c;
    }
    for (final c in circles) {
      if (!identical(c, smallest) &&
          hypot(c.x - smallest.x, c.y - smallest.y) + smallest.r >
              c.r * (1 + 1e-9)) {
        return '';
      }
    }
    return whole(smallest);
  }
  var cx = 0.0;
  var cy = 0.0;
  for (final p in corners) {
    cx += p.x / corners.length;
    cy += p.y / corners.length;
  }
  corners.sort(
    (p, q) => math
        .atan2(p.y - cy, p.x - cx)
        .compareTo(math.atan2(q.y - cy, q.x - cx)),
  );
  final d = StringBuffer();
  for (var i = 0; i < corners.length; i++) {
    final from = corners[i];
    final to = corners[(i + 1) % corners.length];
    if (i == 0) d.write('M${format(from.x)},${format(from.y)}');
    // The side between two corners is an arc of a circle that passes through both; of those, the
    // one whose arc stays inside the others.
    Circle? arc;
    var large = 0;
    var narrowest = double.infinity;
    for (final c in <Circle>[from.a, from.b]) {
      if (!identical(c, to.a) && !identical(c, to.b)) continue;
      final start = math.atan2(from.y - c.y, from.x - c.x);
      var sweep = math.atan2(to.y - c.y, to.x - c.x) - start;
      if (sweep <= 0) sweep += _tau;
      final mx = c.x + c.r * math.cos(start + sweep / 2);
      final my = c.y + c.r * math.sin(start + sweep / 2);
      final width = hypot(mx - (from.x + to.x) / 2, my - (from.y + to.y) / 2);
      if (width < narrowest) {
        narrowest = width;
        arc = c;
        large = sweep > math.pi ? 1 : 0;
      }
    }
    if (arc == null) {
      d.write('L${format(to.x)},${format(to.y)}');
    } else {
      d.write(
        'A${format(arc.r)},${format(arc.r)} 0 $large 1 ${format(to.x)},${format(to.y)}',
      );
    }
  }
  d.write('Z');
  return d.toString();
}

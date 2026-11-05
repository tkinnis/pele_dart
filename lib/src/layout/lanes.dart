// Upstream: src/layout/lanes.ts

import 'dart:math' as math;
import 'dart:typed_data';

import '../util/math_js.dart';
import 'compound.dart';
import 'layered.dart';

const double _laneHead = 34;
const double _lanePad = 24;
const int _sweeps = 8;
const int _maxDummies = 20000;
const int _maxHops = 10000;
const int _routeBudget = 2000000;
const double _near = 4;
const int _rounds = 3;
const int _relay = 8;
const double _turn = 20;
const double _margin = 20;
const double _leg = 14;
const double _close = 3;

class _PlacedLanes {
  final double width;
  final double height;
  final Uint8List routed;
  final Uint8List margins;
  final int work;

  const _PlacedLanes({
    required this.width,
    required this.height,
    required this.routed,
    required this.margins,
    required this.work,
  });
}

class _AroundWay {
  final List<double> pts;
  final double cost;
  final int lane;

  const _AroundWay({required this.pts, required this.cost, required this.lane});
}

CompoundResult laneLayout(
  List<CNode> nodes,
  List<CEdge> edges,
  Dir dir,
  LayeredOptions opt, [
  double lanePad = _lanePad,
]) {
  final n = nodes.length;
  if (n == 0) return const CompoundResult(width: 0, height: 0);
  final sideways = dir == 'LR' || dir == 'RL';
  final flipped = dir == 'BT' || dir == 'RL';

  final lanes = <int>[];
  for (var i = n - 1; i >= 0; i--) {
    if (nodes[i].parent < 0 && nodes[i].isGroup) lanes.add(i);
  }
  final laneCount = math.max(1, lanes.length);
  final laneSlot = Int32List(n)..fillRange(0, n, -1);
  for (var k = 0; k < lanes.length; k++) {
    laneSlot[lanes[k]] = k;
  }
  final hasChild = Uint8List(n);
  for (var i = 0; i < n; i++) {
    if (nodes[i].parent >= 0) hasChild[nodes[i].parent] = 1;
  }
  final lanePads = Float64List(laneCount)..fillRange(0, laneCount, lanePad);
  var endPad = lanePad;
  int laneOf(int i) {
    var t = i;
    var room = lanePad;
    for (var hops = 0; nodes[t].parent >= 0 && hops < _maxHops; hops++) {
      t = nodes[t].parent;
      if (laneSlot[t] < 0) {
        room += math.max(
          nodes[t].padX,
          math.max(nodes[t].padTop, nodes[t].padBottom),
        );
      }
    }
    final lane = math.max(0, laneSlot[t]);
    if (room > lanePads[lane]) lanePads[lane] = room;
    if (room > endPad) endPad = room;
    return lane;
  }

  final itemOf = Int32List(n)..fillRange(0, n, -1);
  final real = <int>[];
  for (var i = 0; i < n; i++) {
    if (laneSlot[i] >= 0) continue;
    if (!nodes[i].isGroup || hasChild[i] == 0) {
      itemOf[i] = real.length;
      real.add(i);
    }
  }
  double along(CNode c) => sideways ? c.w : c.h;
  double cross(CNode c) => sideways ? c.h : c.w;

  final lnodes = real
      .map((i) => lnode(cross(nodes[i]), along(nodes[i])))
      .toList();
  final ledges = <LEdge>[];
  final edgeOf = <int>[];
  var step = 1;
  {
    final seen = <int>{};
    for (var ei = 0; ei < edges.length; ei++) {
      final e = edges[ei];
      final a = itemOf[e.src];
      final b = itemOf[e.dst];
      if (a < 0 || b < 0 || a == b) continue;
      final key = math.min<int>(a, b) * real.length + math.max<int>(a, b);
      if (e.labelW > 0 || seen.contains(key)) step = 2;
      seen.add(key);
      ledges.add(
        ledge(
          a,
          b,
          e.minlen,
          sideways ? e.labelH : e.labelW,
          sideways ? e.labelW : e.labelH,
        ),
      );
      edgeOf.add(ei);
    }
  }
  orient(lnodes, ledges);
  rank(lnodes, ledges, step);

  final m = ledges.length;
  final itemLane = Int32List(real.length);
  for (var i = 0; i < real.length; i++) {
    itemLane[i] = laneOf(real[i]);
  }

  _PlacedLanes place(Uint8List plain, Uint8List margins) {
    final pad = Float64List(laneCount);
    for (var lane = 0; lane < laneCount; lane++) {
      pad[lane] = margins[lane] != 0
          ? math.max(lanePads[lane], _margin)
          : lanePads[lane];
    }
    final used = Uint8List(laneCount);
    var dummies = 0;
    final span = Int32List(m);
    for (var k = 0; k < m; k++) {
      span[k] = (lnodes[ledges[k].head].rank - lnodes[ledges[k].tail].rank)
          .abs();
      if (plain[k] == 0) dummies += span[k] - 1;
    }
    final direct = dummies > _maxDummies;
    final total = real.length + (direct ? 0 : dummies);
    final rankArr = Int32List(total);
    final laneArr = Int32List(total);
    final sizeArr = Float64List(total);
    final depthArr = Float64List(total);
    final dummyArr = Uint8List(total);
    var maxRank = 0;
    for (var k = 0; k < real.length; k++) {
      rankArr[k] = lnodes[k].rank;
      laneArr[k] = itemLane[k];
      sizeArr[k] = lnodes[k].w;
      depthArr[k] = lnodes[k].h;
      if (rankArr[k] > maxRank) maxRank = rankArr[k];
    }
    final firstDummy = Int32List(m)..fillRange(0, m, -1);
    final labelItem = Int32List(m)..fillRange(0, m, -1);
    final links = <int>[];
    {
      var next = real.length;
      for (var k = 0; k < m; k++) {
        final e = ledges[k];
        final a = e.reversed ? e.head : e.tail;
        final b = e.reversed ? e.tail : e.head;
        if (direct || span[k] < 2 || plain[k] != 0) {
          links.addAll(<int>[a, b]);
          continue;
        }
        final ra = rankArr[a];
        final rb = rankArr[b];
        var labelRank = -1;
        if (e.labelW > 0) {
          labelRank = ra + ((rb - ra) >> 1);
          if (step == 2 && (labelRank & 1) == 0) labelRank--;
        }
        firstDummy[k] = next;
        var prev = a;
        for (var r = ra + 1; r < rb; r++) {
          final d = next++;
          rankArr[d] = r;
          laneArr[d] =
              laneArr[a] +
              roundJs(((laneArr[b] - laneArr[a]) * (r - ra)) / (rb - ra));
          dummyArr[d] = 1;
          if (r == labelRank) {
            sizeArr[d] = e.labelW;
            depthArr[d] = e.labelH;
            labelItem[k] = d;
          }
          links.addAll(<int>[prev, d]);
          prev = d;
        }
        links.addAll(<int>[prev, b]);
      }
    }

    final upStart = Int32List(total + 1);
    final downStart = Int32List(total + 1);
    for (var k = 0; k < links.length; k += 2) {
      downStart[links[k] + 1]++;
      upStart[links[k + 1] + 1]++;
    }
    for (var i = 0; i < total; i++) {
      upStart[i + 1] += upStart[i];
      downStart[i + 1] += downStart[i];
    }
    final up = Int32List(links.length ~/ 2);
    final down = Int32List(links.length ~/ 2);
    {
      final uf = Int32List.fromList(upStart.sublist(0, total));
      final df = Int32List.fromList(downStart.sublist(0, total));
      for (var k = 0; k < links.length; k += 2) {
        down[df[links[k]]++] = links[k + 1];
        up[uf[links[k + 1]]++] = links[k];
      }
    }

    final rows = List<List<int>>.generate(maxRank + 1, (_) => <int>[]);
    for (var i = 0; i < total; i++) {
      rows[rankArr[i]].add(i);
    }
    final pos = Float64List(total);
    final key = Float64List(total);
    void settle(List<int> row) {
      row.sort((a, b) {
        final c1 = laneArr[a] - laneArr[b];
        if (c1 != 0) return c1;
        final c2 = key[a].compareTo(key[b]);
        if (c2 != 0) return c2;
        return a - b;
      });
      for (var k = 0; k < row.length; k++) {
        pos[row[k]] = k.toDouble();
      }
    }

    for (final row in rows) {
      for (var k = 0; k < row.length; k++) {
        key[row[k]] = k.toDouble();
      }
      settle(row);
    }
    for (var sweep = 0; sweep < _sweeps && maxRank > 0; sweep++) {
      final downward = (sweep & 1) == 0;
      for (var s = 1; s <= maxRank; s++) {
        final row = rows[downward ? s : maxRank - s];
        final start = downward ? upStart : downStart;
        final list = downward ? up : down;
        for (final i in row) {
          var sum = 0.0;
          final count = start[i + 1] - start[i];
          for (var k = start[i]; k < start[i + 1]; k++) {
            sum += pos[list[k]];
          }
          key[i] = count > 0 ? sum / count : pos[i];
        }
        settle(row);
      }
    }

    double gap(int a, int b) =>
        (dummyArr[a] != 0 || dummyArr[b] != 0) ? opt.edgeSep : opt.nodeSep;
    void eachRun(
      List<int> row,
      void Function(List<int> row, int from, int to) visit,
    ) {
      var from = 0;
      while (from < row.length) {
        var to = from;
        while (to + 1 < row.length &&
            laneArr[row[to + 1]] == laneArr[row[from]]) {
          to++;
        }
        visit(row, from, to);
        from = to + 1;
      }
    }

    double runSize(List<int> row, int from, int to) {
      var size = sizeArr[row[from]];
      for (var k = from; k < to; k++) {
        size += gap(row[k], row[k + 1]) + sizeArr[row[k + 1]];
      }
      return size;
    }

    final breadth = Float64List(laneCount);
    var head = lanes.isNotEmpty ? _laneHead : 0.0;
    for (var k = 0; k < lanes.length; k++) {
      final lane = nodes[lanes[k]];
      breadth[k] = math.max(0, lane.minW - 2 * pad[k]);
      if (lane.padTop > head) head = lane.padTop;
    }
    for (final row in rows) {
      eachRun(row, (_, from, to) {
        final size = runSize(row, from, to);
        if (size > breadth[laneArr[row[from]]]) {
          breadth[laneArr[row[from]]] = size;
        }
      });
    }
    final laneStart = Float64List(laneCount + 1);
    for (var k = 0; k < laneCount; k++) {
      laneStart[k + 1] = laneStart[k] + breadth[k] + 2 * pad[k];
    }

    final cArr = Float64List(total);
    final want = Float64List(total);
    void center(List<int> row, int from, int to) {
      final lane = laneArr[row[from]];
      var at =
          (laneStart[lane] +
              pad[lane] +
              (laneStart[lane + 1] - pad[lane]) -
              runSize(row, from, to)) /
          2;
      for (var k = from; k <= to; k++) {
        cArr[row[k]] = at + sizeArr[row[k]] / 2;
        if (k < to) at += sizeArr[row[k]] + gap(row[k], row[k + 1]);
      }
    }

    void align(List<int> row, int from, int to) {
      final lane = laneArr[row[from]];
      var floor = laneStart[lane] + pad[lane];
      for (var k = from; k <= to; k++) {
        final i = row[k];
        cArr[i] = math.max(want[i], floor + sizeArr[i] / 2);
        if (k < to) floor = cArr[i] + sizeArr[i] / 2 + gap(i, row[k + 1]);
      }
      var ceil = laneStart[lane + 1] - pad[lane];
      for (var k = to; k >= from; k--) {
        final i = row[k];
        cArr[i] = math.min(cArr[i], ceil - sizeArr[i] / 2);
        if (k > from) ceil = cArr[i] - sizeArr[i] / 2 - gap(row[k - 1], i);
      }
    }

    for (final row in rows) {
      eachRun(row, center);
    }
    for (var pass = 0; pass < 4 && maxRank > 0; pass++) {
      final downward = (pass & 1) == 0;
      for (var s = 1; s <= maxRank; s++) {
        final row = rows[downward ? s : maxRank - s];
        final start = downward ? upStart : downStart;
        final list = downward ? up : down;
        for (final i in row) {
          var sum = 0.0;
          var count = 0;
          for (var k = start[i]; k < start[i + 1]; k++) {
            if (laneArr[list[k]] != laneArr[i]) continue;
            sum += cArr[list[k]];
            count++;
          }
          want[i] = count > 0 ? sum / count : cArr[i];
        }
        eachRun(row, align);
      }
    }

    final bandStart = Float64List(maxRank + 1);
    final bandEnd = Float64List(maxRank + 1);
    final sep = Float64List(maxRank + 1)
      ..fillRange(0, maxRank + 1, opt.rankSep / step);
    if (plain.any((on) => on == 1)) {
      final full = opt.rankSep / step;
      sep.fillRange(0, maxRank + 1, full / _close);
      for (var k = 0; k < m; k++) {
        final e = ledges[k];
        final a = e.reversed ? e.head : e.tail;
        final b = e.reversed ? e.tail : e.head;
        if (plain[k] != 0) {
          if (e.labelH <= 0 || span[k] > step) continue;
          final room = math.min(
            full,
            (e.labelH + 2 * _turn - math.min(depthArr[a], depthArr[b]) / 2) /
                span[k],
          );
          for (var r = rankArr[a]; r < rankArr[b]; r++) {
            if (room > sep[r]) sep[r] = room;
          }
          continue;
        }
        final d0 = firstDummy[k];
        if (d0 < 0 || span[k] <= step * e.minlen) {
          for (var r = rankArr[a]; r < rankArr[b]; r++) {
            sep[r] = full;
          }
          continue;
        }
        for (var d = d0 - 1; d < d0 + span[k] - 1; d++) {
          final u = d < d0 ? a : d;
          final v = d + 1 < d0 + span[k] - 1 ? d + 1 : b;
          if (laneArr[u] != laneArr[v] || (cArr[u] - cArr[v]).abs() >= 0.5) {
            sep[rankArr[u]] = full;
          }
        }
      }
    }
    var at = head + endPad;
    for (var r = 0; r <= maxRank; r++) {
      var depth = 0.0;
      for (final i in rows[r]) {
        if (depthArr[i] > depth) depth = depthArr[i];
      }
      bandStart[r] = at;
      bandEnd[r] = at + depth;
      at += depth + (r == maxRank ? 0 : sep[r]);
    }
    final length = at + endPad;
    final breadthTotal = laneStart[laneCount];
    double flip(double a) => flipped ? head + length - a : a;
    double px(double c, double a) => sideways ? flip(a) : c;
    double py(double c, double a) => sideways ? c : flip(a);
    final axis = sideways ? 1.0 : 0.0;

    for (var k = 0; k < real.length; k++) {
      final node = nodes[real[k]];
      final a = (bandStart[rankArr[k]] + bandEnd[rankArr[k]]) / 2;
      node.x = px(cArr[k], a);
      node.y = py(cArr[k], a);
    }
    for (var k = 0; k < lanes.length; k++) {
      final lane = nodes[lanes[k]];
      final c = (laneStart[k] + laneStart[k + 1]) / 2;
      final size = laneStart[k + 1] - laneStart[k];
      lane.x = sideways ? length / 2 : c;
      lane.y = sideways ? c : length / 2;
      lane.w = sideways ? length : size;
      lane.h = sideways ? size : length;
      lane.padTop = head;
    }

    final depthOf = Int32List(n);
    final inner = <int>[];
    for (var i = 0; i < n; i++) {
      if (!nodes[i].isGroup || laneSlot[i] >= 0 || itemOf[i] >= 0) continue;
      var d = 0;
      for (
        var p = nodes[i].parent;
        p >= 0 && d < _maxHops;
        p = nodes[p].parent
      ) {
        d++;
      }
      depthOf[i] = d;
      inner.add(i);
    }
    inner.sort((a, b) {
      final cmp = depthOf[b] - depthOf[a];
      return cmp != 0 ? cmp : a - b;
    });
    final box = Float64List(n * 4);
    for (var i = 0; i < n; i++) {
      box[i * 4] = double.infinity;
      box[i * 4 + 1] = double.infinity;
      box[i * 4 + 2] = double.negativeInfinity;
      box[i * 4 + 3] = double.negativeInfinity;
    }
    void grow(int g, CNode c) {
      if (c.x - c.w / 2 < box[g * 4]) box[g * 4] = c.x - c.w / 2;
      if (c.y - c.h / 2 < box[g * 4 + 1]) box[g * 4 + 1] = c.y - c.h / 2;
      if (c.x + c.w / 2 > box[g * 4 + 2]) box[g * 4 + 2] = c.x + c.w / 2;
      if (c.y + c.h / 2 > box[g * 4 + 3]) box[g * 4 + 3] = c.y + c.h / 2;
    }

    for (final i in real) {
      if (nodes[i].parent >= 0 && laneSlot[nodes[i].parent] < 0) {
        grow(nodes[i].parent, nodes[i]);
      }
    }
    for (final g in inner) {
      final c = nodes[g];
      if (box[g * 4] == double.infinity) continue;
      final w = math.max(box[g * 4 + 2] - box[g * 4] + 2 * c.padX, c.minW);
      c.x = (box[g * 4] + box[g * 4 + 2]) / 2;
      c.w = w;
      c.y = (box[g * 4 + 1] - c.padTop + box[g * 4 + 3] + c.padBottom) / 2;
      c.h = box[g * 4 + 3] - box[g * 4 + 1] + c.padTop + c.padBottom;
      if (c.parent >= 0 && laneSlot[c.parent] < 0) grow(c.parent, c);
    }

    for (final e in edges) {
      e.route = <double>[];
    }
    for (var k = 0; k < m; k++) {
      final e = ledges[k];
      final out = edges[edgeOf[k]];
      final a = e.reversed ? e.head : e.tail;
      final b = e.reversed ? e.tail : e.head;
      final pts = <double>[
        cArr[a],
        bandEnd[rankArr[a]] -
            (bandEnd[rankArr[a]] - bandStart[rankArr[a]] - depthArr[a]) / 2,
      ];
      final d0 = firstDummy[k];
      if (d0 >= 0) {
        for (var d = d0; d < d0 + span[k] - 1; d++) {
          pts.addAll(<double>[cArr[d], bandStart[rankArr[d]]]);
          if (bandEnd[rankArr[d]] > bandStart[rankArr[d]]) {
            pts.addAll(<double>[cArr[d], bandEnd[rankArr[d]]]);
          }
        }
      }
      pts.addAll(<double>[
        cArr[b],
        bandStart[rankArr[b]] +
            (bandEnd[rankArr[b]] - bandStart[rankArr[b]] - depthArr[b]) / 2,
      ]);
      final route = <double>[];
      for (var p = 0; p < pts.length; p += 2) {
        route.addAll(<double>[
          px(pts[p], pts[p + 1]),
          py(pts[p], pts[p + 1]),
          axis,
        ]);
      }
      if (e.reversed) {
        for (var i = 0, j = route.length - 3; i < j; i += 3, j -= 3) {
          for (var t = 0; t < 2; t++) {
            final keep = route[i + t];
            route[i + t] = route[j + t];
            route[j + t] = keep;
          }
        }
      }
      out.route = route;
      final label = labelItem[k];
      if (label >= 0) {
        final mid = (bandStart[rankArr[label]] + bandEnd[rankArr[label]]) / 2;
        out.labelX = px(cArr[label], mid);
        out.labelY = py(cArr[label], mid);
      } else {
        out.labelX = (route[0] + route[route.length - 3]) / 2;
        out.labelY = (route[1] + route[route.length - 2]) / 2;
      }
    }

    for (final e in edges) {
      if (e.route.isNotEmpty || e.src == e.dst) continue;
      final a = nodes[e.src];
      final b = nodes[e.dst];
      final (ax, ay) = _border(a, b);
      final (bx, by) = _border(b, a);
      final flat = (bx - ax).abs() > (by - ay).abs() ? 1.0 : 0.0;
      e.route = <double>[ax, ay, flat, bx, by, flat];
      e.labelX = (ax + bx) / 2;
      e.labelY = (ay + by) / 2;
    }

    final routed = Uint8List(m);
    var routePoints = 0;
    for (final edge in edges) {
      routePoints += edge.route.length ~/ 3;
    }
    final work = m * (real.length + edges.length + routePoints);
    if (work <= _routeBudget) {
      double amid(int i) => (bandStart[rankArr[i]] + bandEnd[rankArr[i]]) / 2;
      final labels = edges
          .map(
            (e) => <double>[
              sideways ? e.labelY : e.labelX,
              flip(sideways ? e.labelX : e.labelY),
            ],
          )
          .toList();
      bool overlaps(
        double c0,
        double a0,
        double c1,
        double a1,
        double lc,
        double la,
        double cw,
        double ah,
      ) =>
          c1 > lc - cw / 2 &&
          c0 < lc + cw / 2 &&
          a1 > la - ah / 2 &&
          a0 < la + ah / 2;
      bool clear(
        double c0,
        double a0,
        double c1,
        double a1,
        int src,
        int dst,
        int ei,
      ) {
        for (var i = 0; i < real.length; i++) {
          if (i != src &&
              i != dst &&
              overlaps(
                c0,
                a0,
                c1,
                a1,
                cArr[i],
                amid(i),
                sizeArr[i] + 8,
                depthArr[i] + 8,
              )) {
            return false;
          }
        }
        for (var i = 0; i < edges.length; i++) {
          final e = edges[i];
          if (i != ei &&
              e.labelW > 0 &&
              e.src != e.dst &&
              overlaps(
                c0,
                a0,
                c1,
                a1,
                labels[i][0],
                labels[i][1],
                sideways ? e.labelH : e.labelW,
                sideways ? e.labelW : e.labelH,
              )) {
            return false;
          }
        }
        return true;
      }

      int crossings(double x0, double y0, double x1, double y1, int ei) {
        var count = 0;
        for (var i = 0; i < edges.length; i++) {
          if (i == ei) continue;
          final route = edges[i].route;
          for (var j = 3; j < route.length; j += 3) {
            if (math.max(route[j - 3], route[j]) > x0 &&
                math.min(route[j - 3], route[j]) < x1 &&
                math.max(route[j - 2], route[j + 1]) > y0 &&
                math.min(route[j - 2], route[j + 1]) < y1) {
              count++;
              break;
            }
          }
        }
        return count;
      }

      int meets(double x, double y, int ei) {
        var count = 0;
        for (var i = 0; i < edges.length; i++) {
          final route = edges[i].route;
          if (i == ei || route.isEmpty) continue;
          final last = route.length - 3;
          if (((route[0] - x).abs() < 1 && (route[1] - y).abs() < 1) ||
              ((route[last] - x).abs() < 1 &&
                  (route[last + 1] - y).abs() < 1)) {
            count++;
          }
        }
        return count;
      }

      bool retraces(double x0, double y0, double x1, double y1, int ei) {
        final upright = (x1 - x0).abs() < 0.5;
        final lo = upright ? math.min(y0, y1) : math.min(x0, x1);
        final hi = upright ? math.max(y0, y1) : math.max(x0, x1);
        final line = upright ? x0 : y0;
        for (var i = 0; i < edges.length; i++) {
          final other = edges[i];
          if (i == ei ||
              other.src == edges[ei].src ||
              other.dst == edges[ei].dst) {
            continue;
          }
          final route = other.route;
          for (var j = 3; j < route.length; j += 3) {
            final u0 = route[j - 3 + (upright ? 0 : 1)];
            final u1 = route[j + (upright ? 0 : 1)];
            if ((u0 - line).abs() >= _near || (u1 - line).abs() >= _near) {
              continue;
            }
            final v0 = route[j - 3 + (upright ? 1 : 0)];
            final v1 = route[j + (upright ? 1 : 0)];
            if (math.min(hi, math.max(v0, v1)) -
                    math.max(lo, math.min(v0, v1)) >
                1) {
              return true;
            }
          }
        }
        return false;
      }

      for (var k = 0; k < m; k++) {
        final e = ledges[k];
        final ei = edgeOf[k];
        final out = edges[ei];
        final a = e.tail;
        final b = e.head;
        if (laneArr[a] == laneArr[b] || (cArr[b] - cArr[a]).abs() < 1) continue;
        final ac = cArr[a];
        final bc = cArr[b];
        final aa = amid(a);
        final ba = amid(b);
        final dc = signJs(bc - ac);
        final da = signJs(ba - aa);

        bool attempt(List<double> pts, double margin) {
          for (var p = 2; p < pts.length; p += 2) {
            if (!clear(
              math.min(pts[p - 2], pts[p]) - margin,
              math.min(pts[p - 1], pts[p + 1]) - margin,
              math.max(pts[p - 2], pts[p]) + margin,
              math.max(pts[p - 1], pts[p + 1]) + margin,
              a,
              b,
              ei,
            )) {
              return false;
            }
            if (retraces(
              px(pts[p - 2], pts[p - 1]),
              py(pts[p - 2], pts[p - 1]),
              px(pts[p], pts[p + 1]),
              py(pts[p], pts[p + 1]),
              ei,
            )) {
              return false;
            }
          }
          var lc = 0.0;
          var la = 0.0;
          var longest = -1.0;
          if (out.labelW > 0) {
            final cw = e.labelW;
            final ah = e.labelH;
            for (var p = 2; p < pts.length; p += 2) {
              final cc = (pts[p - 2] + pts[p]) / 2;
              final ca = (pts[p - 1] + pts[p + 1]) / 2;
              final across = (pts[p] - pts[p - 2]).abs();
              final alongDist = (pts[p + 1] - pts[p - 1]).abs();
              final run = across + alongDist;
              if (run <= longest ||
                  (across > 0 ? across < cw + 8 : alongDist < ah + 8)) {
                continue;
              }
              if (cc - cw / 2 < 0 ||
                  cc + cw / 2 > breadthTotal ||
                  ca - ah / 2 < 0 ||
                  ca + ah / 2 > length) {
                continue;
              }
              if (!clear(
                cc - cw / 2,
                ca - ah / 2,
                cc + cw / 2,
                ca + ah / 2,
                -1,
                -1,
                ei,
              )) {
                continue;
              }
              final lx = px(cc, ca);
              final ly = py(cc, ca);
              if (crossings(
                    lx - out.labelW / 2,
                    ly - out.labelH / 2,
                    lx + out.labelW / 2,
                    ly + out.labelH / 2,
                    ei,
                  ) >
                  0) {
                continue;
              }
              lc = cc;
              la = ca;
              longest = run;
            }
            if (longest < 0) return false;
          }
          final way = <double>[pts[0], pts[1]];
          for (var p = 2; p < pts.length; p += 2) {
            final dx = pts[p] - pts[p - 2];
            final dy = pts[p + 1] - pts[p - 1];
            final run = dx.abs() + dy.abs();
            final first = p > 2 ? _turn : 0.0;
            final last = p + 2 < pts.length ? _turn : 0.0;
            if (run > first + last + 1) {
              if (first > 0) {
                way.addAll(<double>[
                  pts[p - 2] + (dx / run) * first,
                  pts[p - 1] + (dy / run) * first,
                ]);
              }
              if (last > 0) {
                way.addAll(<double>[
                  pts[p] - (dx / run) * last,
                  pts[p + 1] - (dy / run) * last,
                ]);
              }
            }
            way.addAll(<double>[pts[p], pts[p + 1]]);
          }
          out.route = <double>[];
          for (var p = 0; p < way.length; p += 2) {
            final crosswise = p == 0 ? way[0] != way[2] : way[p] != way[p - 2];
            out.route.addAll(<double>[
              px(way[p], way[p + 1]),
              py(way[p], way[p + 1]),
              crosswise ? 1 - axis : axis,
            ]);
          }
          if (out.labelW > 0) {
            out.labelX = px(lc, la);
            out.labelY = py(lc, la);
            labels[ei] = <double>[lc, la];
          }
          routed[k] = 1;
          return true;
        }

        if (attempt(<double>[
          ac + dc * sizeArr[a] / 2,
          aa,
          bc,
          aa,
          bc,
          ba - da * depthArr[b] / 2,
        ], 2)) {
          continue;
        }
        if (attempt(<double>[
          ac,
          aa + da * depthArr[a] / 2,
          ac,
          ba,
          bc - dc * sizeArr[b] / 2,
          ba,
        ], 2)) {
          continue;
        }
        if (work > _routeBudget ~/ _relay) continue;
        final around = <_AroundWay>[];
        final candidateLanes = laneArr[a] < laneArr[b]
            ? <int>[laneArr[b], laneArr[a]]
            : <int>[laneArr[a], laneArr[b]];
        for (final lane in candidateLanes) {
          final inset = math.max(
            pad[lane] - _leg,
            math.min(pad[lane] / 2, _margin - _leg),
          );
          for (final ch in <double>[
            laneStart[lane] + inset,
            laneStart[lane + 1] - inset,
          ]) {
            if ((ch - ac).abs() < sizeArr[a] / 2 + 4 ||
                (ch - bc).abs() < sizeArr[b] / 2 + 4) {
              continue;
            }
            final pts = <double>[
              ac + signJs(ch - ac) * sizeArr[a] / 2,
              aa,
              ch,
              aa,
              ch,
              ba,
              bc + signJs(ch - bc) * sizeArr[b] / 2,
              ba,
            ];
            var cost =
                (meets(px(pts[0], pts[1]), py(pts[0], pts[1]), ei) +
                    meets(px(pts[6], pts[7]), py(pts[6], pts[7]), ei)) *
                1e6;
            for (var p = 2; p < pts.length; p += 2) {
              final x0 = px(pts[p - 2], pts[p - 1]);
              final y0 = py(pts[p - 2], pts[p - 1]);
              final x1 = px(pts[p], pts[p + 1]);
              final y1 = py(pts[p], pts[p + 1]);
              cost +=
                  crossings(
                        math.min(x0, x1),
                        math.min(y0, y1),
                        math.max(x0, x1),
                        math.max(y0, y1),
                        ei,
                      ) *
                      1e6 +
                  (x1 - x0).abs() +
                  (y1 - y0).abs();
            }
            around.add(_AroundWay(pts: pts, cost: cost, lane: lane));
          }
        }
        around.sort((p, q) => p.cost.compareTo(q.cost));
        for (final way in around) {
          if (!attempt(way.pts, 1)) continue;
          used[way.lane] = 1;
          break;
        }
      }
    }

    return _PlacedLanes(
      width: sideways ? length : breadthTotal,
      height: sideways ? breadthTotal : length,
      routed: routed,
      margins: used,
      work: work,
    );
  }

  var plain = Uint8List(m);
  var margins = Uint8List(laneCount);
  var placed = place(plain, margins);
  for (
    var round = 0;
    round < _rounds && placed.work <= _routeBudget ~/ _relay;
    round++
  ) {
    final next = Uint8List(m);
    for (var k = 0; k < m; k++) {
      next[k] = round == 0 ? placed.routed[k] : (plain[k] & placed.routed[k]);
    }
    var samePlain = true;
    for (var k = 0; k < m; k++) {
      if (next[k] != plain[k]) {
        samePlain = false;
        break;
      }
    }
    var sameMargins = true;
    for (var k = 0; k < laneCount; k++) {
      if (placed.margins[k] != margins[k]) {
        sameMargins = false;
        break;
      }
    }
    if (samePlain && sameMargins) break;
    plain = next;
    margins = placed.margins;
    placed = place(plain, margins);
  }
  var lost = false;
  for (var k = 0; k < m; k++) {
    if (plain[k] != 0 && placed.routed[k] == 0) {
      lost = true;
      break;
    }
  }
  if (lost) {
    placed = place(Uint8List(m), Uint8List(laneCount));
  }
  return CompoundResult(width: placed.width, height: placed.height);
}

(double, double) _border(CNode from, CNode to) {
  final dx = to.x - from.x;
  final dy = to.y - from.y;
  final hw = math.max(from.w / 2, 0.5);
  final hh = math.max(from.h / 2, 0.5);
  if (dx.abs() < hw && dy.abs() < hh) {
    final toSide = hw - dx.abs();
    final toEnd = hh - dy.abs();
    return toSide < toEnd
        ? (from.x + (dx < 0 ? -hw : hw), to.y)
        : (to.x, from.y + (dy < 0 ? -hh : hh));
  }
  final scale = math.min(
    dx != 0 ? hw / dx.abs() : double.infinity,
    dy != 0 ? hh / dy.abs() : double.infinity,
  );
  return (from.x + dx * scale, from.y + dy * scale);
}

// Upstream: src/layout/layered.ts

import 'dart:math' as math;
import 'dart:typed_data';

import '../util/math_js.dart';

abstract final class Kind {
  static const int node = 0;
  static const int dummy = 1;
  static const int label = 2;
  static const int startPort = 3;
  static const int endPort = 4;
}

class LNode {
  LNode({
    required this.w,
    required this.h,
    required this.kind,
    this.pin = 0,
    this.hint = double.nan,
    this.key = double.nan,
    this.span = 0,
    this.x = 0,
    this.y = 0,
    this.rank = 0,
  });

  double w;
  double h;
  int kind;
  int pin;
  double hint;
  double key;
  double span;
  double x;
  double y;
  int rank;
}

class LEdge {
  LEdge({
    required this.tail,
    required this.head,
    this.minlen = 1,
    this.labelW = 0,
    this.labelH = 0,
    this.tailDx = 0,
    this.headDx = 0,
    this.tailFixed = false,
    this.headFixed = false,
    this.reversed = false,
    List<double>? points,
    this.labelX = 0,
    this.labelY = 0,
  }) : points = points ?? <double>[];

  int tail;
  int head;
  int minlen;
  double labelW;
  double labelH;
  double tailDx;
  double headDx;
  bool tailFixed;
  bool headFixed;
  bool reversed;
  List<double> points;
  double labelX;
  double labelY;
}

class LayeredGroups {
  const LayeredGroups({required this.of, required this.parent});
  final Int32List of;
  final Int32List parent;
}

class LayeredOptions {
  const LayeredOptions({
    required this.nodeSep,
    required this.edgeSep,
    required this.rankSep,
    required this.portSep,
    this.tracks,
    this.straight,
    this.apart,
    this.headRoom,
    this.groups,
    this.orderOnly,
  });

  final double nodeSep;
  final double edgeSep;
  final double rankSep;
  final double portSep;
  final bool? tracks;
  final bool? straight;
  final bool? apart;
  final double? headRoom;
  final LayeredGroups? groups;
  final bool? orderOnly;

  LayeredOptions copyWith({
    double? nodeSep,
    double? edgeSep,
    double? rankSep,
    double? portSep,
    bool? tracks,
    bool? straight,
    bool? apart,
    double? headRoom,
    LayeredGroups? groups,
    bool? orderOnly,
  }) => LayeredOptions(
    nodeSep: nodeSep ?? this.nodeSep,
    edgeSep: edgeSep ?? this.edgeSep,
    rankSep: rankSep ?? this.rankSep,
    portSep: portSep ?? this.portSep,
    tracks: tracks ?? this.tracks,
    straight: straight ?? this.straight,
    apart: apart ?? this.apart,
    headRoom: headRoom ?? this.headRoom,
    groups: groups ?? this.groups,
    orderOnly: orderOnly ?? this.orderOnly,
  );
}

class LayeredResult {
  const LayeredResult({
    required this.width,
    required this.height,
    this.crossings,
    this.declared,
  });

  final double width;
  final double height;
  final int? crossings;
  final int? declared;
}

LNode lnode(double w, double h, [int kind = Kind.node]) {
  return LNode(w: w, h: h, kind: kind);
}

LEdge ledge(
  int tail,
  int head, [
  int minlen = 1,
  double labelW = 0,
  double labelH = 0,
]) {
  return LEdge(
    tail: tail,
    head: head,
    minlen: minlen,
    labelW: labelW,
    labelH: labelH,
  );
}

const int _maxSweeps = 24;
const int _maxDummies = 20000;
const double _portPitch = 16;
const double _minPitch = 8;
const double _minSlope = 0.125;
const double _maxGap = 3;
const double _trackMargin = 18;
const double _trackPitch = 10;
const double _trackSpread = 14;
const double _levelWide = 2;
const double _levelMargin = 28;
const double _levelPitch = 12;
const double _levelLead = 12;
const double _levelClear = 8;
const double _levelTouch = 4;
const double _crossedSlope = 0.5;
const double _inLine = 0.5;
const double _twin = 1;
const double _snap = 12;
const double _bendSnap = 24;
const double _leanClear = 40;
const int _maxWeighed = 400;
const int _samples = 16;
final Float64List _lineA = Float64List(2 * _samples + 2);
final Float64List _lineB = Float64List(2 * _samples + 2);

abstract final class _End {
  static const int held = 0;
  static const int leaves = 1;
  static const int arrives = 2;
}

bool _isDummy(int kind) {
  return kind == Kind.dummy || kind == Kind.label;
}

void _sortRange(Int32List list, int from, int to, Int32List key) {
  for (var i = from + 1; i < to; i++) {
    final item = list[i];
    final k = key[item];
    var j = i - 1;
    while (j >= from &&
        (key[list[j]] > k || (key[list[j]] == k && list[j] > item))) {
      list[j + 1] = list[j];
      j--;
    }
    list[j + 1] = item;
  }
}

void _sortByBary(
  Int32List list,
  int count,
  Float64List bary,
  Int32List pos,
  bool right,
  Int32List spare,
) {
  bool before(int a, int b) =>
      bary[a] < bary[b] ||
      (bary[a] == bary[b] && (right ? pos[a] > pos[b] : pos[a] < pos[b]));
  const run = 8;
  for (var s = 0; s < count; s += run) {
    final end = math.min(count, s + run);
    for (var i = s + 1; i < end; i++) {
      final item = list[i];
      var j = i - 1;
      while (j >= s && before(item, list[j])) {
        list[j + 1] = list[j];
        j--;
      }
      list[j + 1] = item;
    }
  }
  var from = list;
  var to = spare;
  for (var width = run; width < count; width *= 2) {
    for (var s = 0; s < count; s += 2 * width) {
      final mid = math.min(count, s + width);
      final end = math.min(count, s + 2 * width);
      var i = s;
      var j = mid;
      var k = s;
      while (i < mid && j < end) {
        to[k++] = before(from[j], from[i]) ? from[j++] : from[i++];
      }
      while (i < mid) {
        to[k++] = from[i++];
      }
      while (j < end) {
        to[k++] = from[j++];
      }
    }
    final t = from;
    from = to;
    to = t;
  }
  if (!identical(from, list)) {
    for (var i = 0; i < count; i++) {
      list[i] = from[i];
    }
  }
}

LayeredResult layered(
  List<LNode> nodes,
  List<LEdge> edges,
  LayeredOptions opt,
) {
  final real = nodes.length;
  if (real == 0) return const LayeredResult(width: 0, height: 0);
  final m = edges.length;
  if (real == 1 && m == 0 && nodes[0].kind == Kind.node) {
    final node = nodes[0];
    node.rank = 0;
    node.x = node.w / 2;
    node.y = node.h / 2;
    return LayeredResult(width: node.w, height: node.h);
  }

  var step = 1;
  if (m > 0) {
    final seen = <int>{};
    for (final e in edges) {
      final a = math.min(e.tail, e.head);
      final b = math.max(e.tail, e.head);
      final key = a * real + b;
      if (e.labelW > 0 || seen.contains(key)) {
        step = 2;
        break;
      }
      seen.add(key);
    }
  }

  orient(nodes, edges);
  rank(nodes, edges, step);

  final span = Int32List(m);
  var dummies = 0;
  for (var ei = 0; ei < m; ei++) {
    final e = edges[ei];
    span[ei] = (nodes[e.head].rank - nodes[e.tail].rank).abs();
    if (span[ei] > 1) dummies += span[ei] - 1;
  }
  final direct = Uint8List(m);
  if (dummies > _maxDummies) {
    final longest = <int>[];
    for (var ei = 0; ei < m; ei++) {
      if (span[ei] > 1) longest.add(ei);
    }
    longest.sort((a, b) {
      final c = span[b] - span[a];
      return c != 0 ? c : a - b;
    });
    for (final ei in longest) {
      if (dummies <= _maxDummies) break;
      direct[ei] = 1;
      dummies -= span[ei] - 1;
    }
  }

  final n = real + dummies;
  final W = Float64List(n);
  final H = Float64List(n);
  final KIND = Uint8List(n);
  final RANK = Int32List(n);
  var maxRank = 0;
  for (var i = 0; i < real; i++) {
    final node = nodes[i];
    W[i] = node.w;
    H[i] = node.h;
    KIND[i] = node.kind;
    RANK[i] = node.rank;
    if (node.rank > maxRank) maxRank = node.rank;
  }

  var segments = 0;
  for (var ei = 0; ei < m; ei++) {
    if (direct[ei] == 0) segments += span[ei];
  }
  final EF = Int32List(segments);
  final ET = Int32List(segments);
  final EFD = Float64List(segments);
  final ETD = Float64List(segments);
  final firstDummy = Int32List(m)..fillRange(0, m, -1);
  final heads = Uint8List(maxRank + 1);
  final labelNode = Int32List(m)..fillRange(0, m, -1);
  var spans = false;
  for (var i = 0; i < real; i++) {
    if (nodes[i].span > 0 && nodes[i].kind == Kind.node) spans = true;
  }
  final EFK = spans ? Uint8List(segments) : null;
  final ETK = spans ? Uint8List(segments) : null;
  final firstSeg = Int32List(m)..fillRange(0, m, -1);
  final lastSeg = Int32List(m)..fillRange(0, m, -1);
  final KEY = Float64List(n)..fillRange(0, n, double.nan);
  for (var i = 0; i < real; i++) {
    KEY[i] = nodes[i].key;
  }
  var offsets = false;
  {
    var next = real;
    var ce = 0;
    for (var ei = 0; ei < m; ei++) {
      if (direct[ei] != 0) continue;
      final e = edges[ei];
      final a = e.reversed ? e.head : e.tail;
      final b = e.reversed ? e.tail : e.head;
      final aDx = e.reversed ? e.headDx : e.tailDx;
      final bDx = e.reversed ? e.tailDx : e.headDx;
      if (aDx != 0 || bDx != 0) offsets = true;
      final ra = RANK[a];
      final rb = RANK[b];
      var labelRank = -1;
      if (e.labelW > 0) {
        labelRank = ra + ((rb - ra) >> 1);
        if (step == 2 && rb - ra >= 4) {
          if ((labelRank & 1) == 1) labelRank += e.reversed ? 1 : -1;
        } else if (step == 2 && (labelRank & 1) == 0) {
          labelRank += e.reversed ? 1 : -1;
        }
      }
      var prev = a;
      if (rb - ra > 1) firstDummy[ei] = next;
      firstSeg[ei] = ce;
      if (EFK != null && !(e.reversed ? e.headFixed : e.tailFixed)) {
        EFK[ce] = e.reversed ? _End.arrives : _End.leaves;
      }
      for (var r = ra + 1; r < rb; r++) {
        final d = next++;
        RANK[d] = r;
        KEY[d] = KEY[a] + ((KEY[b] - KEY[a]) * (r - ra)) / (rb - ra);
        if (r == labelRank) {
          W[d] = e.labelW;
          H[d] = e.labelH;
          KIND[d] = Kind.label;
          labelNode[ei] = d;
          heads[r] |= e.reversed ? 2 : 1;
        } else {
          KIND[d] = Kind.dummy;
        }
        EF[ce] = prev;
        ET[ce] = d;
        EFD[ce] = prev == a ? aDx : 0;
        ce++;
        prev = d;
      }
      EF[ce] = prev;
      ET[ce] = b;
      EFD[ce] = prev == a ? aDx : 0;
      ETD[ce] = bDx;
      if (ETK != null && !(e.reversed ? e.tailFixed : e.headFixed)) {
        ETK[ce] = e.reversed ? _End.leaves : _End.arrives;
      }
      lastSeg[ei] = ce;
      ce++;
    }
  }

  Int32List? GRP;
  if (opt.groups != null) {
    final of = opt.groups!.of;
    final parent = opt.groups!.parent;
    GRP = Int32List(n);
    for (var i = 0; i < real; i++) {
      GRP[i] = of[i];
    }
    int depth(int gr) {
      var d = 0;
      for (; gr >= 0; gr = parent[gr]) {
        d++;
      }
      return d;
    }

    int lca(int x, int y) {
      var dx = depth(x);
      var dy = depth(y);
      for (; dx > dy; dx--) {
        x = parent[x];
      }
      for (; dy > dx; dy--) {
        y = parent[y];
      }
      while (x != y) {
        x = parent[x];
        y = parent[y];
      }
      return x;
    }

    for (var ei = 0; ei < m; ei++) {
      if (firstDummy[ei] < 0) continue;
      final e = edges[ei];
      final gr = lca(of[e.tail], of[e.head]);
      for (var d = firstDummy[ei], end = d + span[ei] - 1; d < end; d++) {
        GRP[d] = gr;
      }
    }
  }

  final succStart = Int32List(n + 1);
  final predStart = Int32List(n + 1);
  for (var e = 0; e < segments; e++) {
    succStart[EF[e] + 1]++;
    predStart[ET[e] + 1]++;
  }
  for (var i = 0; i < n; i++) {
    succStart[i + 1] += succStart[i];
    predStart[i + 1] += predStart[i];
  }
  final succE = Int32List(segments);
  final predE = Int32List(segments);
  {
    final sf = Int32List.fromList(succStart.sublist(0, n));
    final pf = Int32List.fromList(predStart.sublist(0, n));
    for (var e = 0; e < segments; e++) {
      succE[sf[EF[e]]++] = e;
      predE[pf[ET[e]]++] = e;
    }
  }

  final layerStart = Int32List(maxRank + 2);
  for (var i = 0; i < n; i++) {
    layerStart[RANK[i] + 1]++;
  }
  for (var r = 0; r <= maxRank; r++) {
    layerStart[r + 1] += layerStart[r];
  }
  final order = Int32List(n);
  final pos = Int32List(n);

  {
    final byRank = Int32List(n);
    final fill = Int32List.fromList(layerStart.sublist(0, maxRank + 1));
    for (var i = 0; i < n; i++) {
      byRank[fill[RANK[i]]++] = i;
    }
    for (var r = 0; r <= maxRank; r++) {
      fill[r] = layerStart[r];
    }
    final visited = Uint8List(n);
    final stack = <int>[];
    for (var k = 0; k < n; k++) {
      if (visited[byRank[k]] != 0) continue;
      stack.add(byRank[k]);
      while (stack.isNotEmpty) {
        final v = stack.removeLast();
        if (visited[v] != 0) continue;
        visited[v] = 1;
        order[fill[RANK[v]]++] = v;
        for (var j = succStart[v + 1] - 1; j >= succStart[v]; j--) {
          final w = ET[succE[j]];
          if (visited[w] == 0) stack.add(w);
        }
      }
    }
  }

  bool sortRank(int r, double Function(int v) key) {
    final s = layerStart[r];
    final e = layerStart[r + 1];
    if (e - s < 2) return false;
    for (var i = s; i < e; i++) {
      if (key(order[i]).isNaN) return false;
    }
    final layer = order.sublist(s, e).toList();
    final index = <int, int>{};
    for (var i = 0; i < layer.length; i++) {
      index[layer[i]] = i;
    }
    layer.sort((a, b) {
      final d = key(a) - key(b);
      if (d < 0) return -1;
      if (d > 0) return 1;
      return index[a]! - index[b]!;
    });
    order.setRange(s, e, layer);
    return true;
  }

  for (var r = 0; r <= maxRank; r++) {
    sortRank(r, (v) => KEY[v]);
  }

  var pinned = false;
  for (var i = 0; i < real; i++) {
    if (nodes[i].pin != 0) pinned = true;
  }
  if (pinned) {
    for (var r = 0; r <= maxRank; r++) {
      final s = layerStart[r];
      final e = layerStart[r + 1];
      final layer = order.sublist(s, e).toList();
      final index = <int, int>{};
      for (var i = 0; i < layer.length; i++) {
        index[layer[i]] = i;
      }
      int pinOf(int v) => v < real ? nodes[v].pin : 0;
      layer.sort((a, b) {
        final c = pinOf(a) - pinOf(b);
        return c != 0 ? c : index[a]! - index[b]!;
      });
      order.setRange(s, e, layer);
    }
  }

  final fixed = Uint8List(maxRank + 1);
  double hint(int v) =>
      (v < real &&
          (nodes[v].kind == Kind.startPort || nodes[v].kind == Kind.endPort))
      ? nodes[v].hint
      : double.nan;
  for (final r in [0, maxRank]) {
    if (sortRank(r, hint)) fixed[r] = 1;
  }

  void setPositions() {
    for (var r = 0; r <= maxRank; r++) {
      final s = layerStart[r];
      for (var i = s, e = layerStart[r + 1]; i < e; i++) {
        pos[order[i]] = i - s;
      }
    }
  }

  setPositions();

  final g = _Graph(
    n: n,
    real: real,
    maxRank: maxRank,
    W: W,
    KIND: KIND,
    RANK: RANK,
    EF: EF,
    ET: ET,
    EFD: EFD,
    ETD: ETD,
    succStart: succStart,
    succE: succE,
    predStart: predStart,
    predE: predE,
    layerStart: layerStart,
    order: order,
    pos: pos,
    offsets: offsets,
    fixed: fixed,
    GRP: GRP,
    groupParent: opt.groups?.parent,
  );

  var crossings = 0;
  var declared = 0;
  if (segments > 0 && maxRank > 0) {
    (crossings, declared) = _reduceCrossings(g, nodes);
    setPositions();
  }
  if (opt.orderOnly == true) {
    final at = _position(g, opt);
    for (var i = 0; i < real; i++) {
      nodes[i].x = at[i];
    }
    for (var ei = 0; ei < m; ei++) {
      final e = edges[ei];
      final a = e.reversed ? e.head : e.tail;
      final b = e.reversed ? e.tail : e.head;
      final pts = <double>[RANK[a].toDouble(), at[a]];
      if (direct[ei] == 0 && firstDummy[ei] >= 0) {
        for (var d = firstDummy[ei], end = d + span[ei] - 1; d < end; d++) {
          pts.add(RANK[d].toDouble());
          pts.add(at[d]);
        }
      }
      pts.add(RANK[b].toDouble());
      pts.add(at[b]);
      e.points = pts;
    }
    return LayeredResult(
      width: 0,
      height: 0,
      crossings: crossings,
      declared: declared,
    );
  }

  if (EFK != null && ETK != null) _spread(g, nodes, EFK, ETK);

  final xs = _position(g, opt);

  final empty = _emptyRanks(g);
  if (EFK != null && ETK != null) {
    final free = _freeEnds(g, EFK, ETK);
    _alignLabels(g, nodes, xs, free, opt, empty);
    _settle(g, nodes, xs, EFK, ETK, free, empty);
    _snapNodes(g, xs, empty, opt);
    for (var ei = 0; ei < m; ei++) {
      if (direct[ei] != 0) continue;
      final e = edges[ei];
      final aDx = EFD[firstSeg[ei]];
      final bDx = ETD[lastSeg[ei]];
      e.tailDx = e.reversed ? bDx : aDx;
      e.headDx = e.reversed ? aDx : bDx;
    }
  }

  _alignPorts(g, xs, empty);

  final onLine = Uint8List(n);
  if (empty != null && opt.tracks != true) {
    _straighten(
      g,
      xs,
      empty,
      firstDummy,
      span,
      opt.apart == true ? 0 : opt.edgeSep,
      onLine,
    );
  }
  if (opt.tracks != true) {
    _pastLabels(g, xs, firstDummy, span, opt.edgeSep, onLine);
  }

  final pieceStart = Int32List(m + 1);
  final pieces = (opt.tracks == true || (EFK != null && opt.straight != true))
      ? _Pieces()
      : null;
  final trackCount = Int32List(maxRank + 1);
  if (pieces != null) {
    for (var ei = 0; ei < m; ei++) {
      pieceStart[ei] = pieces.from.length;
      if (direct[ei] != 0) continue;
      final d0 = firstDummy[ei];
      var twin = false;
      for (var d = d0, end = d0 < 0 ? d0 : d0 + span[ei] - 1; d < end; d++) {
        final bare = empty != null && empty[RANK[d]] == 1;
        if (opt.tracks != true && bare != (onLine[d] == 1)) twin = true;
      }
      if (twin) continue;
      var x = xs[EF[firstSeg[ei]]] + EFD[firstSeg[ei]];
      var r = RANK[EF[firstSeg[ei]]];
      for (var d = d0, end = d0 < 0 ? d0 : d0 + span[ei] - 1; d < end; d++) {
        if (empty != null && empty[RANK[d]] != 0) continue;
        pieces.from.add(x);
        pieces.to.add(xs[d]);
        pieces.rank.add(r);
        pieces.lower.add(d);
        x = xs[d];
        r = RANK[d];
      }
      pieces.from.add(x);
      pieces.to.add(xs[ET[lastSeg[ei]]] + ETD[lastSeg[ei]]);
      pieces.rank.add(r);
      pieces.lower.add(-1);
    }
    pieceStart[m] = pieces.from.length;
  }

  bool portOnly(int r, int kind) {
    var found = false;
    for (var i = layerStart[r]; i < layerStart[r + 1]; i++) {
      final k = KIND[order[i]];
      if (k == kind) {
        found = true;
      } else if (k != Kind.dummy) {
        return false;
      }
    }
    return found;
  }

  final startRanks = portOnly(0, Kind.startPort) ? step : 0;
  final endRanks = portOnly(maxRank, Kind.endPort) ? step : 0;
  final run = Float64List(maxRank + 1);
  for (var e = 0; e < segments; e++) {
    final across = (xs[EF[e]] + EFD[e] - xs[ET[e]] - ETD[e]).abs();
    if (across > run[RANK[EF[e]]]) run[RANK[EF[e]]] = across;
  }
  final bandTop = Float64List(maxRank + 1);
  final bandBottom = Float64List(maxRank + 1);
  double usual(int r) =>
      (r < startRanks || r >= maxRank - endRanks ? opt.portSep : opt.rankSep) /
      step;
  final gapUnder = Float64List(maxRank + 1);
  for (var r = 0; r < maxRank; r++) {
    gapUnder[r] = pieces != null
        ? usual(r)
        : math.max(
            usual(r),
            math.min((_maxGap * opt.rankSep) / step, run[r] * _minSlope),
          );
  }
  final between = Uint8List(maxRank + 1)..fillRange(0, maxRank + 1, 1);
  for (var i = 0; i < real; i++) {
    between[RANK[i]] = 0;
  }
  for (var r = 1; r < maxRank; r++) {
    if (opt.tracks == true ||
        between[r] == 0 ||
        (heads[r] != 1 && heads[r] != 2)) {
      continue;
    }
    final shift = math.min(
      (opt.headRoom ?? 0) / 2,
      gapUnder[heads[r] == 1 ? r - 1 : r] / 2,
    );
    gapUnder[r - 1] += heads[r] == 1 ? -shift : shift;
    gapUnder[r] += heads[r] == 1 ? shift : -shift;
  }

  double inset(int d) =>
      (KIND[d] == Kind.dummy && between[RANK[d]] != 0 && opt.tracks != true)
      ? (bandBottom[RANK[d]] - bandTop[RANK[d]]) / 4
      : 0;

  final margin = opt.tracks == true ? _trackMargin : _levelMargin;
  final leastPitch = opt.tracks == true ? _trackPitch : _levelPitch;
  final mostPitch = opt.tracks == true ? _trackSpread : _levelPitch;
  final below = Int32List(maxRank + 1);
  if (pieces != null) {
    final room = Float64List(maxRank + 1);
    for (var r = 0; r < maxRank; r++) {
      if (empty != null && empty[r] != 0) continue;
      var next = r + 1;
      room[r] = gapUnder[r];
      while (next < maxRank && empty != null && empty[next] != 0) {
        room[r] += gapUnder[next++];
      }
      below[r] = next;
    }
    for (var k = 0; k < pieces.from.length; k++) {
      pieces.wide.add(
        (pieces.from[k] - pieces.to[k]).abs() >
                _levelWide * room[pieces.rank[k]]
            ? 1
            : 0,
      );
    }
    final tall = Float64List(maxRank + 1);
    _assignTracks(pieces, trackCount, opt.tracks != true, room, tall);
    for (var r = 0; r < maxRank; r++) {
      if (trackCount[r] > 0) {
        gapUnder[r] += math.max(
          0,
          2 * margin + (trackCount[r] - 1) * leastPitch - room[r],
        );
      } else if (tall[r] > 0) {
        gapUnder[r] += math.max(
          0,
          math.min(_maxGap * opt.rankSep, tall[r]) - room[r],
        );
      }
    }
  }
  var y = 0.0;
  for (var r = 0; r <= maxRank; r++) {
    var h = 0.0;
    for (var i = layerStart[r]; i < layerStart[r + 1]; i++) {
      if (H[order[i]] > h) h = H[order[i]];
    }
    bandTop[r] = y;
    bandBottom[r] = y + h;
    y += h + gapUnder[r];
  }
  final height = y;

  double trackY(int piece, [int? onTrackArg]) {
    final onTrack = onTrackArg ?? pieces!.track[piece];
    final r = pieces!.rank[piece];
    final top = bandBottom[r];
    final bottom = bandTop[below[r]];
    final count = opt.tracks == true ? trackCount[r] : pieces.levels[piece];
    final pitch = count > 1
        ? math.min(mostPitch, (bottom - top - 2 * margin) / (count - 1))
        : 0.0;
    return (top + bottom) / 2 + (onTrack - (count - 1) / 2) * pitch;
  }

  var minX = double.infinity;
  var maxX = double.negativeInfinity;
  for (var i = 0; i < n; i++) {
    final half = W[i] / 2;
    if (xs[i] - half < minX) minX = xs[i] - half;
    if (xs[i] + half > maxX) maxX = xs[i] + half;
  }

  final arrives = Uint8List(maxRank + 1);
  final leaves = Uint8List(maxRank + 1);
  for (var i = 0; i < real; i++) {
    if (KIND[i] != Kind.node || EFK == null) continue;
    if (predStart[i + 1] > predStart[i]) arrives[RANK[i]] = 1;
    if (succStart[i + 1] > succStart[i]) leaves[RANK[i]] = 1;
  }
  for (var i = 0; i < real; i++) {
    final node = nodes[i];
    final r = node.rank;
    node.x = xs[i] - minX;
    if (KIND[i] == Kind.node && leaves[r] != 0 && arrives[r] == 0) {
      node.y = bandBottom[r] - node.h / 2;
    } else if (KIND[i] == Kind.node && arrives[r] != 0 && leaves[r] == 0) {
      node.y = bandTop[r] + node.h / 2;
    } else {
      node.y = (bandTop[r] + bandBottom[r]) / 2;
    }
  }

  for (var ei = 0; ei < m; ei++) {
    final e = edges[ei];
    final first = nodes[e.reversed ? e.head : e.tail];
    final last = nodes[e.reversed ? e.tail : e.head];
    final pts = <double>[
      first.x + (e.reversed ? e.headDx : e.tailDx),
      first.y + first.h / 2,
    ];
    final d0 = firstDummy[ei];
    if (pieces != null && pieceStart[ei + 1] > pieceStart[ei]) {
      for (var k = pieceStart[ei]; k < pieceStart[ei + 1]; k++) {
        if (pieces.track[k] >= 0 &&
            (opt.tracks == true || pieces.wide[k] == 1)) {
          final across = trackY(k);
          pts
            ..add(pieces.from[k] - minX)
            ..add(across)
            ..add(pieces.to[k] - minX)
            ..add(across);
        } else if (pieces.track[k] > 0) {
          pts
            ..add(pieces.from[k] - minX)
            ..add(trackY(k, pieces.track[k] - 1));
        }
        final d = pieces.lower[k];
        if (d < 0) continue;
        pts
          ..add(xs[d] - minX)
          ..add(bandTop[RANK[d]] + inset(d));
        if (bandBottom[RANK[d]] > bandTop[RANK[d]]) {
          pts
            ..add(xs[d] - minX)
            ..add(bandBottom[RANK[d]] - inset(d));
        }
      }
    } else if (d0 >= 0) {
      for (var d = d0, end = d0 + span[ei] - 1; d < end; d++) {
        if (onLine[d] != 0) continue;
        final x = xs[d] - minX;
        final top = bandTop[RANK[d]];
        final bottom = bandBottom[RANK[d]];
        pts
          ..add(x)
          ..add(top + inset(d));
        if (bottom > top) {
          pts
            ..add(x)
            ..add(bottom - inset(d));
        }
      }
    }
    pts
      ..add(last.x + (e.reversed ? e.tailDx : e.headDx))
      ..add(last.y - last.h / 2);
    if (e.reversed) {
      for (var i = 0, j = pts.length - 2; i < j; i += 2, j -= 2) {
        final tx = pts[i];
        final ty = pts[i + 1];
        pts[i] = pts[j];
        pts[i + 1] = pts[j + 1];
        pts[j] = tx;
        pts[j + 1] = ty;
      }
    }
    e.points = pts;
    final ln = labelNode[ei];
    if (ln >= 0) {
      e.labelX = xs[ln] - minX;
      e.labelY = (bandTop[RANK[ln]] + bandBottom[RANK[ln]]) / 2;
    } else if (e.labelW > 0) {
      e.labelX = (pts[0] + pts[pts.length - 2]) / 2;
      e.labelY = (pts[1] + pts[pts.length - 1]) / 2;
    }
  }

  return LayeredResult(width: maxX - minX, height: height);
}

class _Pieces {
  final List<double> from = <double>[];
  final List<double> to = <double>[];
  final List<int> rank = <int>[];
  final List<int> lower = <int>[];
  final List<int> track = <int>[];
  final List<int> levels = <int>[];
  final List<int> wide = <int>[];
}

class _Graph {
  _Graph({
    required this.n,
    required this.real,
    required this.maxRank,
    required this.W,
    required this.KIND,
    required this.RANK,
    required this.EF,
    required this.ET,
    required this.EFD,
    required this.ETD,
    required this.succStart,
    required this.succE,
    required this.predStart,
    required this.predE,
    required this.layerStart,
    required this.order,
    required this.pos,
    required this.offsets,
    required this.fixed,
    this.GRP,
    this.groupParent,
  });

  final int n;
  final int real;
  final int maxRank;
  final Float64List W;
  final Uint8List KIND;
  final Int32List RANK;
  final Int32List EF;
  final Int32List ET;
  final Float64List EFD;
  final Float64List ETD;
  final Int32List succStart;
  final Int32List succE;
  final Int32List predStart;
  final Int32List predE;
  final Int32List layerStart;
  final Int32List order;
  final Int32List pos;
  final bool offsets;
  final Uint8List fixed;
  final Int32List? GRP;
  final Int32List? groupParent;
}

void orient(List<LNode> nodes, List<LEdge> edges) {
  final n = nodes.length;
  final m = edges.length;
  final start = Int32List(n + 1);
  for (var i = 0; i < m; i++) {
    final e = edges[i];
    e.reversed =
        nodes[e.head].kind == Kind.startPort ||
        nodes[e.tail].kind == Kind.endPort;
    if (!e.reversed) start[e.tail + 1]++;
  }
  for (var i = 0; i < n; i++) {
    start[i + 1] += start[i];
  }
  final out = Int32List(start[n]);
  {
    final fill = Int32List.fromList(start.sublist(0, n));
    for (var i = 0; i < m; i++) {
      if (!edges[i].reversed) out[fill[edges[i].tail]++] = i;
    }
  }
  final state = Uint8List(n);
  final cursor = Int32List.fromList(start.sublist(0, n));
  final stack = <int>[];
  for (var root = 0; root < n; root++) {
    if (state[root] != 0) continue;
    stack.add(root);
    state[root] = 1;
    while (stack.isNotEmpty) {
      final v = stack.last;
      if (cursor[v] < start[v + 1]) {
        final e = edges[out[cursor[v]++]];
        final w = e.head;
        if (state[w] == 1) {
          e.reversed = true;
        } else if (state[w] == 0) {
          state[w] = 1;
          stack.add(w);
        }
      } else {
        state[v] = 2;
        stack.removeLast();
      }
    }
  }
}

void rank(List<LNode> nodes, List<LEdge> edges, int step) {
  final n = nodes.length;
  final m = edges.length;
  final from = Int32List(m);
  final to = Int32List(m);
  final len = Int32List(m);
  final outStart = Int32List(n + 1);
  final inStart = Int32List(n + 1);
  for (var i = 0; i < m; i++) {
    final e = edges[i];
    final a = e.reversed ? e.head : e.tail;
    final b = e.reversed ? e.tail : e.head;
    from[i] = a;
    to[i] = b;
    len[i] = math.max(1, e.minlen) * step;
    outStart[a + 1]++;
    inStart[b + 1]++;
  }
  for (var i = 0; i < n; i++) {
    outStart[i + 1] += outStart[i];
    inStart[i + 1] += inStart[i];
  }
  final outE = Int32List(m);
  final inE = Int32List(m);
  {
    final of = Int32List.fromList(outStart.sublist(0, n));
    final inf = Int32List.fromList(inStart.sublist(0, n));
    for (var i = 0; i < m; i++) {
      outE[of[from[i]]++] = i;
      inE[inf[to[i]]++] = i;
    }
  }

  final r = Int32List(n);
  for (var i = 0; i < n; i++) {
    if (nodes[i].kind == Kind.startPort) r[i] = -step;
  }
  final indeg = Int32List(n);
  for (var i = 0; i < n; i++) {
    indeg[i] = inStart[i + 1] - inStart[i];
  }
  final topo = Int32List(n);
  var count = 0;
  for (var i = 0; i < n; i++) {
    if (indeg[i] == 0) topo[count++] = i;
  }
  for (var q = 0; q < count; q++) {
    final v = topo[q];
    for (var k = outStart[v]; k < outStart[v + 1]; k++) {
      final ei = outE[k];
      final w = to[ei];
      if (r[v] + len[ei] > r[w]) r[w] = r[v] + len[ei];
      if (--indeg[w] == 0) topo[count++] = w;
    }
  }

  for (var pass = 0; pass < 8; pass++) {
    var changed = false;
    for (var q = count - 1; q >= 0; q--) {
      final v = topo[q];
      final ins = inStart[v + 1] - inStart[v];
      final outs = outStart[v + 1] - outStart[v];
      if (ins == 0 && outs == 0) continue;
      var lo = -1 << 30;
      var hi = 1 << 30;
      for (var k = inStart[v]; k < inStart[v + 1]; k++) {
        final ei = inE[k];
        lo = math.max(lo, r[from[ei]] + len[ei]);
      }
      for (var k = outStart[v]; k < outStart[v + 1]; k++) {
        final ei = outE[k];
        hi = math.min(hi, r[to[ei]] - len[ei]);
      }
      var next = r[v];
      if (outs > ins && hi != (1 << 30)) {
        next = hi;
      } else if (ins > outs && lo != (-1 << 30)) {
        next = lo;
      }
      if (next != r[v]) {
        r[v] = next;
        changed = true;
      }
    }
    if (!changed) break;
  }

  var min = 1 << 30;
  var max = -1 << 30;
  var startPorts = false;
  for (var i = 0; i < n; i++) {
    final kind = nodes[i].kind;
    if (kind == Kind.startPort) startPorts = true;
    if (kind == Kind.startPort || kind == Kind.endPort) continue;
    if (r[i] < min) min = r[i];
    if (r[i] > max) max = r[i];
  }
  if (min == (1 << 30)) {
    min = 0;
    max = 0;
  }
  for (var i = 0; i < n; i++) {
    if (nodes[i].kind == Kind.startPort) {
      r[i] = min - step;
    } else if (nodes[i].kind == Kind.endPort) {
      r[i] = max + step;
    }
  }
  if (startPorts) min -= step;
  for (var i = 0; i < n; i++) {
    nodes[i].rank = r[i] - min;
  }
}

double _sideEnds(
  _Graph g,
  int v,
  int side,
  double span,
  Uint8List kinds,
  List<int> ids,
  List<double> room,
) {
  final start = side == 0 ? g.predStart : g.succStart;
  final list = side == 0 ? g.predE : g.succE;
  final other = side == 0 ? g.EF : g.ET;
  final pos = g.pos;
  for (var k = start[v]; k < start[v + 1]; k++) {
    if (kinds[list[k]] != _End.held) ids.add(list[k]);
  }
  if (ids.length < 2) return 0;
  ids.sort((a, b) {
    final c = pos[other[a]] - pos[other[b]];
    return c != 0 ? c : a - b;
  });
  double fill(double Function(bool leaves, bool same) share) {
    var total = 0.0;
    while (room.length < ids.length) {
      room.add(0.0);
    }
    room[0] = 0;
    for (var k = 1; k < ids.length; k++) {
      final same = kinds[ids[k]] == kinds[ids[k - 1]];
      room[k] = share(same && kinds[ids[k]] == _End.leaves, same);
      total += room[k];
    }
    return total;
  }

  var total = fill((_, _) => 1);
  if (span / total < _minPitch) {
    total = fill((leaves, _) => leaves ? 0.5 : 1);
  }
  if (span / total < _minPitch) {
    total = fill((_, same) => same ? 0 : 1);
  }
  if (total == 0) return 0;
  final pitch = math.min(_portPitch, span / total);
  for (var k = 1; k < ids.length; k++) {
    room[k] *= pitch;
  }
  return total * pitch;
}

void _spread(_Graph g, List<LNode> nodes, Uint8List EFK, Uint8List ETK) {
  final real = g.real;
  final W = g.W;
  final EFD = g.EFD;
  final ETD = g.ETD;
  for (var v = 0; v < real; v++) {
    final span = math.min(nodes[v].span, W[v]);
    if (span <= 0 || nodes[v].kind != Kind.node) continue;
    for (var side = 0; side < 2; side++) {
      final ids = <int>[];
      final room = <double>[];
      final total = _sideEnds(
        g,
        v,
        side,
        span,
        side == 0 ? ETK : EFK,
        ids,
        room,
      );
      if (total == 0) continue;
      final dx = side == 0 ? ETD : EFD;
      var at = -total / 2;
      for (var k = 0; k < ids.length; k++) {
        at += room[k];
        dx[ids[k]] = at;
      }
    }
  }
}

int _follow(_Graph g, Uint8List? empty, int e, int side) {
  if (empty == null) return e;
  final KIND = g.KIND;
  final RANK = g.RANK;
  final EF = g.EF;
  final ET = g.ET;
  final succStart = g.succStart;
  final succE = g.succE;
  final predStart = g.predStart;
  final predE = g.predE;
  for (var hops = 0; hops < 100000; hops++) {
    final u = side == 0 ? EF[e] : ET[e];
    if (KIND[u] != Kind.dummy || empty[RANK[u]] == 0) break;
    e = side == 0 ? predE[predStart[u]] : succE[succStart[u]];
  }
  return e;
}

void _alignPorts(_Graph g, Float64List xs, Uint8List? empty) {
  final maxRank = g.maxRank;
  final KIND = g.KIND;
  final EF = g.EF;
  final ET = g.ET;
  final EFD = g.EFD;
  final ETD = g.ETD;
  final succStart = g.succStart;
  final succE = g.succE;
  final predStart = g.predStart;
  final predE = g.predE;
  final layerStart = g.layerStart;
  final order = g.order;
  for (final (r, kind) in [(0, Kind.startPort), (maxRank, Kind.endPort)]) {
    final s = layerStart[r];
    final end = layerStart[r + 1];
    final to = <double>[];
    for (var i = s; i < end; i++) {
      final v = order[i];
      final start = kind == Kind.startPort;
      if (KIND[v] != kind ||
          (start
                  ? succStart[v + 1] - succStart[v]
                  : predStart[v + 1] - predStart[v]) !=
              1) {
        break;
      }
      final e = _follow(
        g,
        empty,
        start ? succE[succStart[v]] : predE[predStart[v]],
        start ? 1 : 0,
      );
      final at = start ? xs[ET[e]] + ETD[e] : xs[EF[e]] + EFD[e];
      if (to.isNotEmpty && at < to.last + _twin) break;
      to.add(at);
    }
    if (to.isEmpty || to.length != end - s) continue;
    for (var i = s; i < end; i++) {
      xs[order[i]] = to[i - s];
    }
  }
}

(Int32List, Int32List) _freeEnds(_Graph g, Uint8List EFK, Uint8List ETK) {
  final free0 = Int32List(g.n);
  final free1 = Int32List(g.n);
  for (var e = 0; e < g.EF.length; e++) {
    if (ETK[e] != _End.held) free0[g.ET[e]]++;
    if (EFK[e] != _End.held) free1[g.EF[e]]++;
  }
  return (free0, free1);
}

double ease(double across, double along) {
  final denom = across.abs() == 0 ? 1.0 : across.abs();
  return math.max(0.25, math.min(0.5, (4 * along.abs()) / denom));
}

void _alignLabels(
  _Graph g,
  List<LNode> nodes,
  Float64List xs,
  (Int32List, Int32List) free,
  LayeredOptions opt,
  Uint8List? empty,
) {
  final sep = opt.edgeSep;
  final n = g.n;
  final real = g.real;
  final maxRank = g.maxRank;
  final KIND = g.KIND;
  final RANK = g.RANK;
  final W = g.W;
  final EF = g.EF;
  final ET = g.ET;
  final EFD = g.EFD;
  final ETD = g.ETD;
  final succStart = g.succStart;
  final succE = g.succE;
  final predStart = g.predStart;
  final predE = g.predE;
  final layerStart = g.layerStart;
  final order = g.order;
  final pos = g.pos;

  bool placed(int v) =>
      KIND[v] == Kind.label ||
      (KIND[v] == Kind.dummy && !(empty != null && empty[RANK[v]] == 1));

  (double, int) end(int e, int side) {
    final u = side == 0 ? EF[e] : ET[e];
    final x = side == 0 ? xs[u] + EFD[e] : xs[u] + ETD[e];
    final f = u < real && nodes[u].kind == Kind.node
        ? (1 - side == 0 ? free.$1[u] : free.$2[u])
        : 0;
    return (x, f);
  }

  (double, double) room(int v) {
    final s = layerStart[RANK[v]];
    final i = s + pos[v];
    double clear(int other) =>
        W[other] / 2 +
        W[v] / 2 +
        (KIND[other] == Kind.node
            ? opt.nodeSep / 2 + sep / 2
            : (KIND[other] == KIND[v] ? sep : sep / 2));
    return (
      i > s ? xs[order[i - 1]] + clear(order[i - 1]) : double.negativeInfinity,
      i + 1 < layerStart[RANK[v] + 1]
          ? xs[order[i + 1]] - clear(order[i + 1])
          : double.infinity,
    );
  }

  double choose(
    double x,
    (double, int) up,
    (double, int) down,
    double lo,
    double hi,
  ) {
    final upFirst = up.$2 != down.$2
        ? up.$2 < down.$2
        : (up.$1 - x).abs() <= (down.$1 - x).abs();
    final choices = upFirst ? [up.$1, down.$1] : [down.$1, up.$1];
    for (final choice in choices) {
      if (choice >= lo && choice <= hi) return choice;
    }
    return math.max(lo, math.min(hi, choices[0]));
  }

  final done = Uint8List(n);
  final chain = <int>[];
  for (var r = 1; r < maxRank; r++) {
    for (var i = layerStart[r]; i < layerStart[r + 1]; i++) {
      if (!placed(order[i]) || done[order[i]] != 0) continue;
      var top = order[i];
      while (_isDummy(KIND[EF[predE[predStart[top]]]])) {
        top = EF[predE[predStart[top]]];
      }
      var bottom = top;
      var lo = double.negativeInfinity;
      var hi = double.infinity;
      chain.clear();
      for (var d = top; _isDummy(KIND[d]); d = ET[succE[succStart[d]]]) {
        bottom = d;
        if (!placed(d)) continue;
        done[d] = 1;
        chain.add(d);
        final (least, most) = room(d);
        if (least > lo) lo = least;
        if (most < hi) hi = most;
      }
      if (lo <= hi) {
        final x = choose(
          xs[chain[0]],
          end(predE[predStart[top]], 0),
          end(succE[succStart[bottom]], 1),
          lo,
          hi,
        );
        for (final d in chain) {
          xs[d] = x;
        }
        continue;
      }
      for (final d in chain) {
        final (least, most) = room(d);
        if (least > most) continue;
        xs[d] = choose(
          xs[d],
          end(_follow(g, empty, predE[predStart[d]], 0), 0),
          end(_follow(g, empty, succE[succStart[d]], 1), 1),
          least,
          most,
        );
      }
    }
  }
}

void _settle(
  _Graph g,
  List<LNode> nodes,
  Float64List xs,
  Uint8List EFK,
  Uint8List ETK,
  (Int32List, Int32List) free,
  Uint8List? empty,
) {
  final real = g.real;
  final W = g.W;
  final EF = g.EF;
  final ET = g.ET;
  final EFD = g.EFD;
  final ETD = g.ETD;
  final succStart = g.succStart;
  final succE = g.succE;
  final predStart = g.predStart;
  final predE = g.predE;
  final pos = g.pos;

  double wanted(int e, int side, int v, double span, bool again) {
    final freeSide = side == 0 ? free.$1 : free.$2;
    final freeOther = side == 0 ? free.$2 : free.$1;
    if (freeSide[v] < 2) return 0;
    e = _follow(g, empty, e, side);
    final u = side == 0 ? EF[e] : ET[e];
    final point = side == 0 ? xs[u] + EFD[e] : xs[u] + ETD[e];
    if (again && (point - xs[v]).abs() <= span / 2 + _inLine) {
      return math.max(-span / 2, math.min(span / 2, point - xs[v]));
    }
    var middle = point;
    var width = 0.0;
    if (u < real &&
        nodes[u].kind == Kind.node &&
        (side == 0 ? EFK : ETK)[e] != _End.held &&
        freeOther[u] >= 2) {
      width = math.max(0, math.min(nodes[u].span, W[u]));
      if (width > 0) middle = xs[u];
    }
    final lo = math.max(xs[v] - span / 2, middle - width / 2);
    final hi = math.min(xs[v] + span / 2, middle + width / 2);
    if (lo > hi + _inLine) {
      final lean = math.max(0.0, span / 2 - _leanClear);
      return math.max(-lean, math.min(lean, point - xs[v]));
    }
    final place = (xs[v] * width + middle * span) / (width + span);
    return math.max(lo, math.min(hi, place)) - xs[v];
  }

  final sides =
      <
        ({
          int v,
          int side,
          double span,
          List<int> ids,
          List<double> room,
          List<int> all,
        })
      >[];
  for (var v = 0; v < real; v++) {
    final span = math.min(nodes[v].span, W[v]);
    if (span <= 0 || nodes[v].kind != Kind.node) continue;
    for (var side = 0; side < 2; side++) {
      final other = side == 0 ? EF : ET;
      final start = side == 0 ? predStart : succStart;
      final list = side == 0 ? predE : succE;
      final ids = <int>[];
      final room = <double>[];
      _sideEnds(g, v, side, span, side == 0 ? ETK : EFK, ids, room);
      if (ids.isEmpty) continue;
      if (ids.length == 1) {
        if (room.isEmpty) {
          room.add(0);
        } else {
          room[0] = 0;
        }
      }
      final all = <int>[];
      for (var k = start[v]; k < start[v + 1]; k++) {
        all.add(list[k]);
      }
      all.sort((a, b) {
        final c = pos[other[a]] - pos[other[b]];
        return c != 0 ? c : a - b;
      });
      sides.add((v: v, side: side, span: span, ids: ids, room: room, all: all));
    }
  }

  for (var pass = 0, moved = true; moved && pass < 6; pass++) {
    moved = false;
    for (final (:v, :side, :span, :ids, :room, :all) in sides) {
      final kinds = side == 0 ? ETK : EFK;
      final dx = side == 0 ? ETD : EFD;
      var k = 0;
      var lo = -span / 2;
      for (var i = 0; i <= all.length; i++) {
        final held = i < all.length && kinds[all[i]] == _End.held;
        if (i < all.length && !held) continue;
        var size = 0;
        for (var j = i - 1; j >= 0 && kinds[all[j]] != _End.held; j--) {
          size++;
        }
        final hi = held ? dx[all[i]] - _portPitch : span / 2;
        if (size > 0) {
          final sum = <double>[];
          final count = <int>[];
          var before = 0.0;
          for (var j = 0; j < size; j++) {
            if (j > 0) before += room[k + j];
            sum.add(wanted(ids[k + j], side, v, span, pass > 0) - before);
            count.add(1);
            var together = j > 0 && room[k + j] == 0;
            while (sum.length > 1 &&
                (together ||
                    sum[sum.length - 2] / count[count.length - 2] >
                        sum.last / count.last)) {
              together = false;
              final top = sum.removeLast();
              final pooled = count.removeLast();
              sum[sum.length - 1] += top;
              count[count.length - 1] += pooled;
            }
          }
          final total = before;
          var j = 0;
          before = 0;
          for (var b = 0; b < sum.length; b++) {
            final level = hi - total < lo
                ? (lo + hi - total) / 2
                : math.max(lo, math.min(hi - total, sum[b] / count[b]));
            for (var c = 0; c < count[b]; c++, j++) {
              if (j > 0) before += room[k + j];
              if ((dx[ids[k + j]] - level - before).abs() > 0.01) moved = true;
              dx[ids[k + j]] = level + before;
            }
          }
          k += size;
        }
        if (held) lo = dx[all[i]] + _portPitch;
      }
    }
  }
}

void _snapNodes(
  _Graph g,
  Float64List xs,
  Uint8List? empty,
  LayeredOptions opt,
) {
  final n = g.n;
  final KIND = g.KIND;
  final RANK = g.RANK;
  final EF = g.EF;
  final ET = g.ET;
  final EFD = g.EFD;
  final ETD = g.ETD;
  final layerStart = g.layerStart;
  final order = g.order;
  final pos = g.pos;

  bool passed(int u) =>
      empty != null && KIND[u] == Kind.dummy && empty[RANK[u]] == 1;

  final a = <int>[];
  final b = <int>[];
  final da = <double>[];
  final db = <double>[];
  for (var e = 0; e < EF.length; e++) {
    if (passed(EF[e])) continue;
    final f = _follow(g, empty, e, 1);
    a.add(EF[e]);
    b.add(ET[f]);
    da.add(EFD[e]);
    db.add(ETD[f]);
  }
  double off(int k) => xs[b[k]] + db[k] - xs[a[k]] - da[k];
  final block = Int32List(n);
  final members = <List<int>>[];
  for (var i = 0; i < n; i++) {
    block[i] = i;
    members.add([i]);
  }
  void join(int x, int y) {
    var keep = block[x];
    var drop = block[y];
    if (keep == drop) return;
    if (members[keep].length < members[drop].length) {
      final t = keep;
      keep = drop;
      drop = t;
    }
    for (final v in members[drop]) {
      block[v] = keep;
      members[keep].add(v);
    }
    members[drop] = <int>[];
  }

  final near = <int>[];
  for (var k = 0; k < a.length; k++) {
    final d = off(k).abs();
    if (d < 0.01) {
      join(a[k], b[k]);
    } else if (d <= _bendSnap) {
      near.add(k);
    }
  }
  if (near.isEmpty) return;
  near.sort((x, y) {
    final d = off(x).abs() - off(y).abs();
    if (d < 0) return -1;
    if (d > 0) return 1;
    return x - y;
  });
  double gap(int v) => _halfRoom(g, opt, v);
  bool isFree(int id, double shift) {
    for (final v in members[id]) {
      final s = layerStart[RANK[v]];
      final end = layerStart[RANK[v] + 1];
      final i = s + pos[v];
      if (i > s &&
          block[order[i - 1]] != id &&
          xs[v] + shift - xs[order[i - 1]] <
              gap(v) + gap(order[i - 1]) - 0.01) {
        return false;
      }
      if (i + 1 < end &&
          block[order[i + 1]] != id &&
          xs[order[i + 1]] - xs[v] - shift <
              gap(v) + gap(order[i + 1]) - 0.01) {
        return false;
      }
    }
    return true;
  }

  for (final k in near) {
    final d = off(k);
    if (d.abs() < 0.01) {
      join(a[k], b[k]);
      continue;
    }
    if (d.abs() > _bendSnap || block[a[k]] == block[b[k]]) continue;
    final upper = block[a[k]];
    final lower = block[b[k]];
    final first = members[upper].length <= members[lower].length
        ? upper
        : lower;
    for (final id in [first, first == upper ? lower : upper]) {
      final shift = id == upper ? d : -d;
      if (d.abs() > _snap && !members[id].every((v) => KIND[v] == Kind.dummy)) {
        continue;
      }
      if (!isFree(id, shift)) continue;
      for (final v in members[id]) {
        xs[v] += shift;
      }
      join(a[k], b[k]);
      break;
    }
  }
}

Uint8List? _emptyRanks(_Graph g) {
  final maxRank = g.maxRank;
  final KIND = g.KIND;
  final layerStart = g.layerStart;
  final order = g.order;
  final empty = Uint8List(maxRank + 1);
  var any = false;
  for (var r = 1; r < maxRank; r++) {
    var only = layerStart[r + 1] > layerStart[r];
    for (var i = layerStart[r]; only && i < layerStart[r + 1]; i++) {
      if (KIND[order[i]] != Kind.dummy) only = false;
    }
    if (only) {
      empty[r] = 1;
      any = true;
    }
  }
  return any ? empty : null;
}

void _assignTracks(
  _Pieces pieces,
  Int32List trackCount,
  bool curved,
  Float64List room,
  Float64List tall,
) {
  final from = pieces.from;
  final to = pieces.to;
  final rank = pieces.rank;
  final track = pieces.track;
  final levels = pieces.levels;
  final wide = pieces.wide;
  final total = from.length;
  final byRank = <int, List<int>>{};
  for (var k = 0; k < total; k++) {
    track.add(-1);
    levels.add(0);
    if ((from[k] - to[k]).abs() < _inLine) continue;
    final list = byRank[rank[k]];
    if (list != null) {
      list.add(k);
    } else {
      byRank[rank[k]] = [k];
    }
  }
  if (byRank.isEmpty) return;
  final LO = Float64List(total);
  final HI = Float64List(total);
  for (var k = 0; k < total; k++) {
    LO[k] = math.min(from[k], to[k]);
    HI[k] = math.max(from[k], to[k]);
  }
  int within(double x, int k) =>
      (x >= LO[k] - _inLine && x <= HI[k] + _inLine) ? 1 : 0;
  bool mates(int a, int b) =>
      (from[a] - from[b]).abs() < _inLine || (to[a] - to[b]).abs() < _inLine;
  bool overlap(int a, int b) =>
      LO[a] < HI[b] - _inLine && LO[b] < HI[a] - _inLine;
  bool clash(int a, int b) => overlap(a, b) && !mates(a, b);
  bool meet(int a, int b) =>
      overlap(a, b) ||
      within(to[a], b) +
              within(from[b], a) +
              within(to[b], a) +
              within(from[a], b) >
          0;
  int crossings(int a, int b) => within(to[a], b) + within(from[b], a);

  List<int> nearPairs(List<int> list) {
    final byLo = List<int>.generate(list.length, (i) => i)
      ..sort((a, b) {
        final d = LO[list[a]] - LO[list[b]];
        if (d < 0) return -1;
        if (d > 0) return 1;
        return a - b;
      });
    final pairs = <int>[];
    for (var x = 0; x < byLo.length; x++) {
      final i = byLo[x];
      final reach = HI[list[i]] + 4 * _inLine;
      for (var y = x + 1; y < byLo.length && LO[list[byLo[y]]] <= reach; y++) {
        final j = byLo[y];
        pairs
          ..add(math.min(i, j))
          ..add(math.max(i, j));
      }
    }
    return pairs;
  }

  int lay(List<int> list) {
    list.sort((a, b) {
      final d = (HI[b] - LO[b]) - (HI[a] - LO[a]);
      if (d < 0) return -1;
      if (d > 0) return 1;
      final d2 = LO[a] - LO[b];
      if (d2 < 0) return -1;
      if (d2 > 0) return 1;
      return a - b;
    });
    final count = list.length;
    final above = <List<int>>[];
    final group = List<int>.generate(count, (i) => i);
    int find(int i) {
      while (group[i] != i) {
        i = group[i] = group[group[i]];
      }
      return i;
    }

    final weighed = count <= _maxWeighed;
    final pairs = weighed ? nearPairs(list) : <int>[];
    final clashes = weighed
        ? List<List<int>>.generate(count, (_) => <int>[])
        : <List<int>>[];
    for (var p = 0; p < pairs.length; p += 2) {
      final i = pairs[p];
      final j = pairs[p + 1];
      if (!clash(list[i], list[j])) continue;
      clashes[i].add(j);
      clashes[j].add(i);
    }
    var sequence = List<int>.generate(count, (i) => i);
    if (weighed) {
      final waiting = Int32List(count);
      final after = <List<int>>[];
      for (var i = 0; i < count; i++) {
        above.add(<int>[]);
        after.add(<int>[]);
      }
      for (var p = 0; p < pairs.length; p += 2) {
        final i = pairs[p];
        final j = pairs[p + 1];
        final a = list[i];
        final b = list[j];
        if (!meet(a, b)) continue;
        group[find(i)] = find(j);
        final ab = crossings(a, b);
        final ba = crossings(b, a);
        if (ab == ba) continue;
        final first = ab < ba ? i : j;
        final second = ab < ba ? j : i;
        above[second].add(first);
        after[first].add(second);
        waiting[second]++;
      }
      final placed = Uint8List(count);
      sequence = <int>[];
      for (var done = 0; done < count; done++) {
        var pick = -1;
        for (var i = 0; i < count; i++) {
          if (placed[i] != 0) continue;
          if (pick < 0 || waiting[i] < waiting[pick]) pick = i;
          if (waiting[i] == 0) break;
        }
        placed[pick] = 1;
        sequence.add(pick);
        for (final j in after[pick]) {
          waiting[j]--;
        }
      }
    }
    final taken = <int>{};
    final onTrack = <List<int>>[];
    var rows = 0;
    for (final at in sequence) {
      final k = list[at];
      var t = 0;
      if (at < above.length) {
        for (final i in above[at]) {
          if (track[list[i]] >= t) t = track[list[i]] + 1;
        }
      }
      if (weighed) {
        taken.clear();
        for (final i in clashes[at]) {
          taken.add(track[list[i]]);
        }
        while (taken.contains(t)) {
          t++;
        }
      } else {
        while (t < onTrack.length &&
            onTrack[t].any((other) => clash(k, other))) {
          t++;
        }
        while (onTrack.length <= t) {
          onTrack.add(<int>[]);
        }
        onTrack[t].add(k);
      }
      track[k] = t;
      if (t >= rows) rows = t + 1;
    }
    final first = Int32List(count)..fillRange(0, count, rows);
    final last = Int32List(count)..fillRange(0, count, -1);
    for (var i = 0; i < count; i++) {
      final root = find(i);
      first[root] = math.min(first[root], track[list[i]]);
      last[root] = math.max(last[root], track[list[i]]);
    }
    for (var i = 0; i < count; i++) {
      final root = find(i);
      levels[list[i]] = last[root] - first[root] + 1;
      if (curved) track[list[i]] -= first[root];
    }
    return rows;
  }

  void sample(int k, double h, Float64List out) {
    final c = ease(to[k] - from[k], h);
    for (var i = 0; i <= _samples; i++) {
      final t = i / _samples;
      final u = 1 - t;
      out[2 * i] = from[k] + (to[k] - from[k]) * t * t * (3 - 2 * t);
      out[2 * i + 1] =
          h * (3 * c * t * u * u + 3 * (1 - c) * t * t * u + t * t * t);
    }
  }

  bool reaches(Float64List points, Float64List line, double limit) {
    final bound = limit * limit * (1 + 1e-9);
    for (var i = 0; i <= _samples; i++) {
      final px = points[2 * i];
      final py = points[2 * i + 1];
      for (var j = 0; j < _samples; j++) {
        final dx = line[2 * j + 2] - line[2 * j];
        final dy = line[2 * j + 3] - line[2 * j + 1];
        final denom = dx * dx + dy * dy;
        final t = math.max(
          0.0,
          math.min(
            1.0,
            ((px - line[2 * j]) * dx + (py - line[2 * j + 1]) * dy) /
                (denom == 0 ? 1.0 : denom),
          ),
        );
        final ex = px - line[2 * j] - t * dx;
        final ey = py - line[2 * j + 1] - t * dy;
        if (ex * ex + ey * ey < bound && hypot(ex, ey) < limit) return true;
      }
    }
    return false;
  }

  bool near(int a, int b, double height, double limit) {
    final h = math.max(height / 2, height - 2 * _levelLead);
    sample(a, h, _lineA);
    sample(b, h, _lineB);
    return reaches(_lineA, _lineB, limit) || reaches(_lineB, _lineA, limit);
  }

  for (final entry in byRank.entries) {
    final r = entry.key;
    final all = entry.value;
    if (!curved) {
      trackCount[r] = lay(all);
      continue;
    }
    if (all.length > _maxWeighed) continue;
    final far = all.where((k) => wide[k] == 1).toList();
    lay(far);
    final level = far.where((k) => levels[k] > 1).toSet();
    final pairs = nearPairs(all);
    for (var p = 0; p < pairs.length; p += 2) {
      final a = all[pairs[p]];
      final b = all[pairs[p + 1]];
      if ((level.contains(a) && level.contains(b)) ||
          !clash(a, b) ||
          (from[a] < to[a]) != (from[b] < to[b])) {
        continue;
      }
      if (near(
        a,
        b,
        room[r],
        wide[a] == 1 || wide[b] == 1 ? _levelClear : _levelTouch,
      )) {
        level
          ..add(a)
          ..add(b);
      }
    }
    for (final k in far) {
      track[k] = -1;
      levels[k] = 0;
    }
    if (level.isEmpty) continue;
    var crossing = 0;
    var alongside = 0;
    final beside = <int>{};
    for (var p = 0; p < pairs.length; p += 2) {
      final a = all[pairs[p]];
      final b = all[pairs[p + 1]];
      if (level.contains(a) && level.contains(b)) {
        if (!overlap(a, b)) continue;
        if ((from[a] < to[a]) != (from[b] < to[b])) {
          crossing++;
        } else if (!mates(a, b)) {
          alongside++;
        }
      } else if ((level.contains(a) || level.contains(b)) && meet(a, b)) {
        beside
          ..add(a)
          ..add(b);
      }
    }
    if (crossing > alongside) {
      for (final k in all) {
        if ((HI[k] - LO[k]) * _crossedSlope > tall[r]) {
          tall[r] = (HI[k] - LO[k]) * _crossedSlope;
        }
      }
      continue;
    }
    final members = all
        .where((k) => level.contains(k) || (wide[k] != 1 && beside.contains(k)))
        .toList();
    lay(members);
    var most = 0;
    for (final k in members) {
      if (levels[k] > most) most = levels[k];
    }
    trackCount[r] = most;
  }
}

void _straighten(
  _Graph g,
  Float64List xs,
  Uint8List empty,
  Int32List firstDummy,
  Int32List span,
  double sep,
  Uint8List onLine,
) {
  final maxRank = g.maxRank;
  final EF = g.EF;
  final ET = g.ET;
  final EFD = g.EFD;
  final ETD = g.ETD;
  final succStart = g.succStart;
  final succE = g.succE;
  final predStart = g.predStart;
  final predE = g.predE;
  final layerStart = g.layerStart;
  final order = g.order;

  final want = Float64List(xs.length);
  final from = Float64List(xs.length);
  final to = Float64List(xs.length);
  for (var ei = 0; ei < firstDummy.length; ei++) {
    final d0 = firstDummy[ei];
    if (d0 < 0) continue;
    final end = d0 + span[ei] - 1;
    final base = g.RANK[d0];
    for (var d = d0; d < end; d++) {
      if (empty[base + d - d0] == 0) continue;
      var last = d;
      while (last + 1 < end && empty[base + last + 1 - d0] != 0) {
        last++;
      }
      final above = predE[predStart[d]];
      final below = succE[succStart[last]];
      final x0 = xs[EF[above]] + EFD[above];
      final x1 = xs[ET[below]] + ETD[below];
      final steps = last - d + 2;
      for (var k = d; k <= last; k++) {
        want[k] = x0 + ((x1 - x0) * (k - d + 1)) / steps;
        from[k] = x0;
        to[k] = x1;
      }
      d = last;
    }
  }

  final twins = <int>[];
  for (var r = 1; r < maxRank; r++) {
    if (empty[r] == 0) continue;
    final s = layerStart[r];
    final end = layerStart[r + 1];
    final row = order.sublist(s, end).toList()
      ..sort((a, b) {
        final d1 = from[a] - from[b];
        if (d1 < 0) return -1;
        if (d1 > 0) return 1;
        final d2 = to[a] - to[b];
        if (d2 < 0) return -1;
        if (d2 > 0) return 1;
        return a - b;
      });
    for (var i = 0; i < row.length;) {
      twins.clear();
      var j = i;
      for (
        ;
        j < row.length &&
            (from[row[j]] - from[row[i]]).abs() < _twin &&
            (to[row[j]] - to[row[i]]).abs() < _twin;
        j++
      ) {
        twins.add(row[j]);
      }
      twins.sort((a, b) => g.pos[a] - g.pos[b]);
      for (var k = 0; k < twins.length; k++) {
        final d = twins[k];
        xs[d] = want[d] + (k - (twins.length - 1) / 2) * sep;
        if (twins.length == 1 || sep == 0) onLine[d] = 1;
      }
      i = j;
    }
  }
}

void _pastLabels(
  _Graph g,
  Float64List xs,
  Int32List firstDummy,
  Int32List span,
  double clear,
  Uint8List onLine,
) {
  final maxRank = g.maxRank;
  final W = g.W;
  final KIND = g.KIND;
  final RANK = g.RANK;
  final EF = g.EF;
  final ET = g.ET;
  final EFD = g.EFD;
  final ETD = g.ETD;
  final succStart = g.succStart;
  final succE = g.succE;
  final predStart = g.predStart;
  final predE = g.predE;
  final layerStart = g.layerStart;
  final order = g.order;
  final labelled = Uint8List(maxRank + 1);
  var any = false;
  for (var r = 1; r < maxRank; r++) {
    var labels = false;
    var others = false;
    for (var i = layerStart[r]; i < layerStart[r + 1]; i++) {
      final kind = KIND[order[i]];
      if (kind == Kind.label) {
        labels = true;
      } else if (kind != Kind.dummy) {
        others = true;
      }
    }
    if (labels && !others) {
      labelled[r] = 1;
      any = true;
    }
  }
  if (!any) return;
  for (var ei = 0; ei < firstDummy.length; ei++) {
    final d0 = firstDummy[ei];
    if (d0 < 0) continue;
    for (var d = d0, end = d0 + span[ei] - 1; d < end; d++) {
      if (KIND[d] != Kind.dummy || labelled[RANK[d]] == 0) continue;
      var first = d;
      var last = d;
      while (first > d0 && onLine[first - 1] != 0) {
        first--;
      }
      while (last + 1 < end && onLine[last + 1] != 0) {
        last++;
      }
      final above = predE[predStart[first]];
      final below = succE[succStart[last]];
      final from = xs[EF[above]] + EFD[above];
      final to = xs[ET[below]] + ETD[below];
      final lo = math.min(from, to) - clear;
      final hi = math.max(from, to) + clear;
      var isFree = true;
      final r = RANK[d];
      for (var i = layerStart[r]; isFree && i < layerStart[r + 1]; i++) {
        final label = order[i];
        if (KIND[label] == Kind.label &&
            xs[label] + W[label] / 2 > lo &&
            xs[label] - W[label] / 2 < hi) {
          isFree = false;
        }
      }
      if (!isFree) continue;
      onLine[d] = 1;
      final steps = last - first + 2;
      for (var k = first; k <= last; k++) {
        xs[k] = from + ((to - from) * (k - first + 1)) / steps;
      }
    }
  }
}

(int, int) _reduceCrossings(_Graph g, List<LNode> nodes) {
  final n = g.n;
  final real = g.real;
  final maxRank = g.maxRank;
  final W = g.W;
  final EF = g.EF;
  final ET = g.ET;
  final EFD = g.EFD;
  final ETD = g.ETD;
  final succStart = g.succStart;
  final succE = g.succE;
  final predStart = g.predStart;
  final predE = g.predE;
  final layerStart = g.layerStart;
  final order = g.order;
  final pos = g.pos;
  final offsets = g.offsets;
  final fixed = g.fixed;
  final GRP = g.GRP;
  final groupParent = g.groupParent;

  var widest = 0;
  for (var r = 0; r <= maxRank; r++) {
    widest = math.max(widest, layerStart[r + 1] - layerStart[r]);
  }
  if (widest < 2) return (0, 0);

  final place = offsets ? Int32List(EF.length) : null;
  final placeIn = Int32List(place != null ? EF.length : 0);
  final places = Int32List(place != null ? n : 0);
  final leaving = place != null ? Int32List.fromList(succE) : succE;
  final mixed = Uint8List(place != null ? n : 0);
  if (place != null) {
    final arriving = Int32List.fromList(predE);
    bool byOffset(Int32List list, int from, int to, Float64List dx) {
      for (var k = from + 1; k < to; k++) {
        if (dx[list[k]] == dx[list[from]]) continue;
        final sub = list.sublist(from, to).toList()
          ..sort((a, b) {
            final d = dx[a] - dx[b];
            if (d < 0) return -1;
            if (d > 0) return 1;
            return 0;
          });
        list.setRange(from, to, sub);
        return true;
      }
      return false;
    }

    for (var v = 0; v < n; v++) {
      places[v] = 1;
      if (byOffset(arriving, predStart[v], predStart[v + 1], ETD)) {
        for (var k = predStart[v] + 1; k < predStart[v + 1]; k++) {
          if (ETD[arriving[k]] != ETD[arriving[k - 1]]) places[v]++;
          placeIn[arriving[k]] = places[v] - 1;
        }
      }
      if (byOffset(leaving, succStart[v], succStart[v + 1], EFD)) mixed[v] = 1;
    }
  }
  var size = 1;
  while (size < (place != null ? widest + EF.length : widest)) {
    size <<= 1;
  }
  final tree = Int32List(2 * size);
  final targets = Int32List(EF.length);

  int count() {
    var total = 0;
    for (var r = 0; r < maxRank; r++) {
      var southLen = layerStart[r + 2] - layerStart[r + 1];
      if (place != null) {
        var next = 0;
        for (var i = layerStart[r + 1]; i < layerStart[r + 2]; i++) {
          final v = order[i];
          for (var k = predStart[v]; k < predStart[v + 1]; k++) {
            place[predE[k]] = next + placeIn[predE[k]];
          }
          next += places[v];
        }
        southLen = next;
      }
      if (southLen < 2) continue;
      var t = 0;
      for (var i = layerStart[r]; i < layerStart[r + 1]; i++) {
        final v = order[i];
        final from = succStart[v];
        final to = succStart[v + 1];
        final t0 = t;
        for (var k = from; k < to; k++) {
          targets[t++] = place != null ? place[leaving[k]] : pos[ET[succE[k]]];
        }
        final d = t - t0;
        if (d < 2) continue;
        if (place != null && mixed[v] != 0) {
          for (var a = t0 + 1; a < t; a++) {
            final item = targets[a];
            final dx = EFD[leaving[from + a - t0]];
            var b = a - 1;
            while (b >= t0 &&
                EFD[leaving[from + b - t0]] == dx &&
                targets[b] > item) {
              targets[b + 1] = targets[b];
              b--;
            }
            targets[b + 1] = item;
          }
        } else if (d <= 12) {
          for (var a = t0 + 1; a < t; a++) {
            final item = targets[a];
            var b = a - 1;
            while (b >= t0 && targets[b] > item) {
              targets[b + 1] = targets[b];
              b--;
            }
            targets[b + 1] = item;
          }
        } else {
          final sub = targets.sublist(t0, t).toList()..sort();
          targets.setRange(t0, t, sub);
        }
      }
      if (t < 2) continue;
      var leaves = 1;
      while (leaves < southLen) {
        leaves <<= 1;
      }
      tree.fillRange(0, 2 * leaves, 0);
      for (var k = 0; k < t; k++) {
        var i = targets[k] + leaves;
        tree[i]++;
        while (i > 1) {
          if ((i & 1) == 0) total += tree[i + 1];
          i >>= 1;
          tree[i]++;
        }
      }
    }
    return total;
  }

  final declared = count();
  final bary = Float64List(n);
  final moving = Int32List(widest);
  final spare = Int32List(widest);

  final groups = groupParent != null ? groupParent.length : 0;
  final depth = Int32List(groups);
  for (var gr = 0; gr < groups; gr++) {
    for (var p = gr; p >= 0; p = groupParent![p]) {
      depth[gr]++;
    }
  }
  final groupSum = Float64List(groups);
  final groupCount = Int32List(groups);
  final groupFirst = Int32List(groups);

  void arrange(int r, Float64List key) {
    final s = layerStart[r];
    final e = layerStart[r + 1];
    for (var i = s; i < e; i++) {
      for (var gr = GRP![order[i]]; gr >= 0; gr = groupParent![gr]) {
        groupSum[gr] = 0;
        groupCount[gr] = 0;
      }
    }
    for (var i = s; i < e; i++) {
      final v = order[i];
      for (var gr = GRP![v]; gr >= 0; gr = groupParent![gr]) {
        if (groupCount[gr] == 0) groupFirst[gr] = i;
        groupSum[gr] += key[v];
        groupCount[gr]++;
      }
    }
    double value(int item) =>
        item >= n ? groupSum[item - n] / groupCount[item - n] : key[item];
    int first(int item) => item >= n ? groupFirst[item - n] : s + pos[item];
    int compare(int a, int b) {
      var ia = a;
      var ib = b;
      var ca = GRP![a];
      var cb = GRP[b];
      var da = ca < 0 ? 0 : depth[ca];
      var db = cb < 0 ? 0 : depth[cb];
      for (; da > db; da--) {
        ia = n + ca;
        ca = groupParent![ca];
      }
      for (; db > da; db--) {
        ib = n + cb;
        cb = groupParent![cb];
      }
      while (ca != cb) {
        ia = n + ca;
        ca = groupParent![ca];
        ib = n + cb;
        cb = groupParent[cb];
      }
      final d = value(ia) - value(ib);
      if (d < 0) return -1;
      if (d > 0) return 1;
      return first(ia) - first(ib);
    }

    final row = order.sublist(s, e).toList()..sort(compare);
    order.setRange(s, e, row);
    for (var i = s; i < e; i++) {
      pos[order[i]] = i - s;
    }
  }

  if (GRP != null) {
    final at = Float64List(n);
    for (var r = 0; r <= maxRank; r++) {
      for (var i = layerStart[r]; i < layerStart[r + 1]; i++) {
        at[order[i]] = (i - layerStart[r]).toDouble();
      }
      arrange(r, at);
    }
  }
  var best = GRP != null ? count() : declared;
  if (best == 0) return (0, declared);
  final bestOrder = Int32List.fromList(order);
  final start = math.min(best, declared);

  void sweep(bool down, bool biasRight) {
    final sStart = down ? predStart : succStart;
    final list = down ? predE : succE;
    final other = down ? EF : ET;
    final otherDx = down ? EFD : ETD;
    for (var step = 1; step <= maxRank; step++) {
      final r = down ? step : maxRank - step;
      if (fixed[r] != 0) continue;
      final s = layerStart[r];
      final e = layerStart[r + 1];
      var movable = 0;
      for (var i = s; i < e; i++) {
        final v = order[i];
        final pin = v < real ? nodes[v].pin : 0;
        if (pin != 0) {
          bary[v] = pin * 1e9;
          moving[movable++] = v;
          continue;
        }
        final from = sStart[v];
        final to = sStart[v + 1];
        if (from == to) {
          if (GRP != null) {
            final across = down
                ? layerStart[r] - layerStart[r - 1]
                : layerStart[r + 2] - layerStart[r + 1];
            bary[v] = ((i - s) * across) / (e - s);
            continue;
          }
          bary[v] = -1;
          continue;
        }
        var sum = 0.0;
        for (var k = from; k < to; k++) {
          final u = other[list[k]];
          sum += pos[u];
          if (offsets && W[u] > 0) sum += otherDx[list[k]] / W[u];
        }
        bary[v] = sum / (to - from);
        moving[movable++] = v;
      }
      if (GRP != null) {
        arrange(r, bary);
        continue;
      }
      if (movable < 2) continue;
      _sortByBary(moving, movable, bary, pos, biasRight, spare);
      var k = 0;
      for (var i = s; i < e; i++) {
        if (bary[order[i]] != -1) order[i] = moving[k++];
      }
      for (var i = s; i < e; i++) {
        pos[order[i]] = i - s;
      }
    }
  }

  int outOfOrder() {
    var total = 0;
    for (var r = 0; r <= maxRank; r++) {
      for (var i = layerStart[r]; i < layerStart[r + 1]; i++) {
        if (order[i] >= real) continue;
        for (var j = i + 1; j < layerStart[r + 1]; j++) {
          if (order[j] < order[i]) total++;
        }
      }
    }
    return total;
  }

  void settlePositions() {
    for (var r = 0; r <= maxRank; r++) {
      for (var i = layerStart[r]; i < layerStart[r + 1]; i++) {
        pos[order[i]] = i - layerStart[r];
      }
    }
  }

  int pinOf(int v) => v < real ? nodes[v].pin : 0;
  double at(int e, bool up) {
    final u = up ? EF[e] : ET[e];
    return offsets && W[u] > 0
        ? pos[u] + (up ? EFD[e] : ETD[e]) / W[u]
        : pos[u].toDouble();
  }

  int between(int a, int b) {
    var c = 0;
    for (var k = predStart[a]; k < predStart[a + 1]; k++) {
      final x = at(predE[k], true);
      for (var j = predStart[b]; j < predStart[b + 1]; j++) {
        if (x > at(predE[j], true)) c++;
      }
    }
    for (var k = succStart[a]; k < succStart[a + 1]; k++) {
      final x = at(succE[k], false);
      for (var j = succStart[b]; j < succStart[b + 1]; j++) {
        if (x > at(succE[j], false)) c++;
      }
    }
    return c;
  }

  void transpose() {
    for (var pass = 0; pass < 8; pass++) {
      var improved = false;
      for (var r = 0; r <= maxRank; r++) {
        if (fixed[r] != 0) continue;
        final s = layerStart[r];
        for (var i = s; i + 1 < layerStart[r + 1]; i++) {
          final a = order[i];
          final b = order[i + 1];
          if (pinOf(a) != pinOf(b) || (GRP != null && GRP[a] != GRP[b])) {
            continue;
          }
          if (between(b, a) >= between(a, b)) continue;
          order[i] = b;
          order[i + 1] = a;
          pos[b] = i - s;
          pos[a] = i + 1 - s;
          improved = true;
        }
      }
      if (!improved) break;
    }
  }

  final initial = Int32List.fromList(order);
  final small = n <= 600;
  var chosen = bestOrder;
  var chosenOut = 1 << 30;
  for (var attempt = 0; attempt < (small ? 2 : 1); attempt++) {
    if (attempt > 0) {
      order.setAll(0, initial);
      settlePositions();
    }
    var found = start;
    final foundOrder = Int32List.fromList(initial);
    for (var i = 0, stale = 0; stale < 4 && i < _maxSweeps; i++, stale++) {
      sweep((i + attempt) % 2 == 0, i % 4 >= 2);
      final c = count();
      if (c < found) {
        found = c;
        foundOrder.setAll(0, order);
        stale = 0;
        if (c == 0) break;
      }
    }
    order.setAll(0, foundOrder);
    if (small && found > 0) {
      settlePositions();
      transpose();
      final c = count();
      if (c < found) {
        found = c;
        foundOrder.setAll(0, order);
      }
    }
    final out = small ? outOfOrder() : 0;
    if (attempt == 0 || found < best || (found == best && out < chosenOut)) {
      best = found;
      chosen = foundOrder;
      chosenOut = out;
    }
  }
  order.setAll(0, chosen);
  settlePositions();
  bestOrder.setAll(0, chosen);
  if (GRP != null) best = count();

  if (!small) return (best, declared);
  for (var i = 0; i < real; i++) {
    if (nodes[i].pin != 0) return (best, declared);
  }
  if (chosenOut == 0 || fixed[0] != 0 || fixed[maxRank] != 0) {
    return (best, declared);
  }
  for (var r = 0; r <= maxRank; r++) {
    var lo = layerStart[r];
    var hi = layerStart[r + 1] - 1;
    while (lo < hi) {
      final t = order[lo];
      order[lo] = order[hi];
      order[hi] = t;
      lo++;
      hi--;
    }
  }
  settlePositions();
  if (count() > best || outOfOrder() >= chosenOut) {
    order.setAll(0, bestOrder);
  }
  return (best, declared);
}

double _halfRoom(_Graph g, LayeredOptions opt, int v) {
  return g.W[v] / 2 + (g.KIND[v] == Kind.node ? opt.nodeSep : opt.edgeSep) / 2;
}

Float64List _position(_Graph g, LayeredOptions opt) {
  final n = g.n;
  final maxRank = g.maxRank;
  final W = g.W;
  final KIND = g.KIND;
  final EF = g.EF;
  final ET = g.ET;
  final EFD = g.EFD;
  final ETD = g.ETD;
  final succStart = g.succStart;
  final succE = g.succE;
  final predStart = g.predStart;
  final predE = g.predE;
  final layerStart = g.layerStart;
  final order = g.order;
  final pos = g.pos;
  final segments = EF.length;
  final gap = Float64List(n);
  for (var i = 0; i < n; i++) {
    gap[i] = _halfRoom(g, opt, i);
  }

  final key = Int32List(segments);
  for (var e = 0; e < segments; e++) {
    key[e] = pos[ET[e]];
  }
  for (var v = 0; v < n; v++) {
    if (succStart[v + 1] - succStart[v] > 1) {
      _sortRange(succE, succStart[v], succStart[v + 1], key);
    }
  }
  for (var e = 0; e < segments; e++) {
    key[e] = pos[EF[e]];
  }
  for (var v = 0; v < n; v++) {
    if (predStart[v + 1] - predStart[v] > 1) {
      _sortRange(predE, predStart[v], predStart[v + 1], key);
    }
  }

  final conflict = Uint8List(segments);
  for (var r = 1; r <= maxRank; r++) {
    final prevLen = layerStart[r] - layerStart[r - 1];
    final s = layerStart[r];
    final end = layerStart[r + 1];
    var k0 = 0;
    var scan = s;
    for (var i = s; i < end; i++) {
      final v = order[i];
      var inner = -1;
      if (_isDummy(KIND[v])) {
        final u = EF[predE[predStart[v]]];
        if (_isDummy(KIND[u])) inner = u;
      }
      final k1 = inner >= 0 ? pos[inner] : prevLen;
      if (inner >= 0 || i == end - 1) {
        for (var j = scan; j <= i; j++) {
          final w = order[j];
          final wDummy = _isDummy(KIND[w]);
          for (var k = predStart[w]; k < predStart[w + 1]; k++) {
            final e = predE[k];
            final up = pos[EF[e]];
            if ((up < k0 || k1 < up) && !(wDummy && _isDummy(KIND[EF[e]]))) {
              conflict[e] = 1;
            }
          }
        }
        scan = i + 1;
        k0 = k1;
      }
    }
  }

  final results = <Float64List>[];
  final root = Int32List(n);
  final align = Int32List(n);
  final shift = Float64List(n);
  final eFrom = Int32List(n);
  final eTo = Int32List(n);
  final eW = Float64List(n);
  final indeg = Int32List(n);
  final outStart = Int32List(n + 1);
  final outE = Int32List(n);
  final fill = Int32List(n);
  final topo = Int32List(n);
  final x = Float64List(n);

  for (var variant = 0; variant < 4; variant++) {
    final up = variant < 2;
    final right = (variant & 1) == 1;
    final start = up ? predStart : succStart;
    final list = up ? predE : succE;
    final other = up ? EF : ET;
    final ownDx = up ? ETD : EFD;
    final otherDx = up ? EFD : ETD;
    for (var i = 0; i < n; i++) {
      root[i] = i;
      align[i] = i;
      shift[i] = 0;
      indeg[i] = 0;
      outStart[i + 1] = 0;
      x[i] = 0;
    }

    for (var step = 0; step <= maxRank; step++) {
      final r = up ? step : maxRank - step;
      final s = layerStart[r];
      final end = layerStart[r + 1];
      final adjacent = up ? r - 1 : r + 1;
      final adjacentLast = adjacent >= 0 && adjacent <= maxRank
          ? layerStart[adjacent + 1] - layerStart[adjacent] - 1
          : 0;
      var prevIdx = -1;
      for (
        var i = right ? end - 1 : s;
        right ? i >= s : i < end;
        right ? i-- : i++
      ) {
        final v = order[i];
        final from = start[v];
        final d = start[v + 1] - from;
        if (d == 0) continue;
        final lo = from + ((d - 1) >> 1);
        final hi = from + (d >> 1);
        for (var pass = 0; pass < 2; pass++) {
          if (pass == 1 && lo == hi) break;
          final e = list[(pass == 0) != right ? lo : hi];
          final w = other[e];
          final idx = right ? adjacentLast - pos[w] : pos[w];
          if (align[v] == v && prevIdx < idx && conflict[e] == 0) {
            align[w] = v;
            align[v] = root[v] = root[w];
            shift[v] = shift[w] + otherDx[e] - ownDx[e];
            prevIdx = idx;
          }
        }
      }
    }

    var blockEdges = 0;
    for (var r = 0; r <= maxRank; r++) {
      final s = layerStart[r];
      final end = layerStart[r + 1];
      for (var i = s + 1; i < end; i++) {
        final a = right ? order[i] : order[i - 1];
        final b = right ? order[i - 1] : order[i];
        final sep = gap[a] + gap[b];
        eFrom[blockEdges] = root[a];
        eTo[blockEdges] = root[b];
        eW[blockEdges] = right
            ? sep - shift[a] + shift[b]
            : sep + shift[a] - shift[b];
        indeg[root[b]]++;
        outStart[root[a] + 1]++;
        blockEdges++;
      }
    }
    for (var i = 0; i < n; i++) {
      outStart[i + 1] += outStart[i];
    }
    for (var i = 0; i < n; i++) {
      fill[i] = outStart[i];
    }
    for (var e = 0; e < blockEdges; e++) {
      outE[fill[eFrom[e]]++] = e;
    }

    var count = 0;
    for (var i = 0; i < n; i++) {
      if (root[i] == i && indeg[i] == 0) topo[count++] = i;
    }
    for (var q = 0; q < count; q++) {
      final v = topo[q];
      for (var k = outStart[v]; k < outStart[v + 1]; k++) {
        final e = outE[k];
        final w = eTo[e];
        if (x[v] + eW[e] > x[w]) x[w] = x[v] + eW[e];
        if (--indeg[w] == 0) topo[count++] = w;
      }
    }
    for (var q = count - 1; q >= 0; q--) {
      final v = topo[q];
      var min = double.infinity;
      for (var k = outStart[v]; k < outStart[v + 1]; k++) {
        final e = outE[k];
        final cand = x[eTo[e]] - eW[e];
        if (cand < min) min = cand;
      }
      if (min != double.infinity && min > x[v]) x[v] = min;
    }
    final xs = Float64List(n);
    for (var i = 0; i < n; i++) {
      xs[i] = (right ? -x[root[i]] : x[root[i]]) + shift[i];
    }
    results.add(xs);
  }

  var narrowest = 0;
  var bestWidth = double.infinity;
  final mins = <double>[];
  final maxs = <double>[];
  for (var k = 0; k < 4; k++) {
    var lo = double.infinity;
    var hi = double.negativeInfinity;
    final xs = results[k];
    for (var i = 0; i < n; i++) {
      final half = W[i] / 2;
      if (xs[i] - half < lo) lo = xs[i] - half;
      if (xs[i] + half > hi) hi = xs[i] + half;
    }
    mins.add(lo);
    maxs.add(hi);
    if (hi - lo < bestWidth) {
      bestWidth = hi - lo;
      narrowest = k;
    }
  }
  for (var k = 0; k < 4; k++) {
    final delta = (k & 1) == 0
        ? mins[narrowest] - mins[k]
        : maxs[narrowest] - maxs[k];
    if (delta != 0) {
      final xs = results[k];
      for (var i = 0; i < n; i++) {
        xs[i] += delta;
      }
    }
  }

  final out = Float64List(n);
  for (var i = 0; i < n; i++) {
    var a = results[0][i];
    var b = results[1][i];
    var c = results[2][i];
    var d = results[3][i];
    double t;
    if (a > b) {
      t = a;
      a = b;
      b = t;
    }
    if (c > d) {
      t = c;
      c = d;
      d = t;
    }
    if (a > c) {
      t = a;
      a = c;
      c = t;
    }
    if (b > d) {
      t = b;
      b = d;
      d = t;
    }
    if (b > c) {
      t = b;
      b = c;
      c = t;
    }
    out[i] = (b + c) / 2;
  }
  return out;
}

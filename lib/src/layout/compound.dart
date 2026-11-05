// Upstream: src/layout/compound.ts

import 'dart:math' as math;
import 'dart:typed_data';

import '../util/math_js.dart';
import 'layered.dart';

typedef Dir = String;

/// The direction a diagram names, or top to bottom for anything else.
Dir direction(String? dir) {
  return dir == 'BT' || dir == 'LR' || dir == 'RL' ? dir! : 'TB';
}

class CNode {
  double w;
  double h;
  int parent;
  bool isGroup;
  Dir? dir;
  double padX;
  double padTop;
  double padBottom;
  double minW;
  // Declaration order; a group takes the smallest value among its members.
  double seq;
  // How much of a side its edges may spread along, measured across the flow; 0 keeps them at its middle.
  double span;
  double x;
  double y;

  CNode({
    required this.w,
    required this.h,
    this.parent = -1,
    this.isGroup = false,
    this.dir,
    this.padX = 0,
    this.padTop = 0,
    this.padBottom = 0,
    this.minW = 0,
    this.seq = 0,
    this.span = 0,
    this.x = 0,
    this.y = 0,
  });
}

class CEdge {
  int src;
  int dst;
  int minlen;
  double labelW;
  double labelH;
  // x, y, axis triples; axis is 0 where the edge runs vertically into the point, 1 horizontally.
  List<double> route;
  double labelX;
  double labelY;

  CEdge({
    required this.src,
    required this.dst,
    this.minlen = 1,
    this.labelW = 0,
    this.labelH = 0,
    List<double>? route,
    this.labelX = 0,
    this.labelY = 0,
  }) : route = route ?? <double>[];
}

class CompoundResult {
  final double width;
  final double height;

  const CompoundResult({required this.width, required this.height});
}

class _Side {
  static const int top = 0;
  static const int right = 1;
  static const int bottom = 2;
  static const int left = 3;
}

class _PortEdge {
  int e;
  int inner;
  bool out;
  int side;
  double hint;
  double px;
  double py;
  List<double> route;

  _PortEdge({
    required this.e,
    required this.inner,
    required this.out,
    required this.side,
    required this.hint,
    required this.px,
    required this.py,
    required this.route,
  });
}

class _LevelEdge {
  final int e;
  final int a;
  final int b;

  const _LevelEdge({required this.e, required this.a, required this.b});
}

class _Level {
  final int id;
  final Dir dir;
  List<int> items = <int>[];
  final List<_LevelEdge> edges = <_LevelEdge>[];
  final List<_PortEdge> ports = <_PortEdge>[];
  final Map<int, _PortEdge> portOf = <int, _PortEdge>{};
  final Map<int, List<double>> routes = <int, List<double>>{};
  double x = 0;
  double y = 0;

  _Level({required this.id, required this.dir});
}

const int _maxPorts = 40000;
const int _maxOrderedPorts = 400;
const int _maxOrderedEdges = 500;
const double _flatSlack = 1.5;
const double _flatSpare = 4;

class _Snapshot {
  final List<double> nodes;
  final List<List<double>> routes;
  final List<double> labels;
  final List<double> levels;
  final CompoundResult total;

  const _Snapshot({
    required this.nodes,
    required this.routes,
    required this.labels,
    required this.levels,
    required this.total,
  });
}

_Snapshot _snapshot(
  List<CNode> nodes,
  List<CEdge> edges,
  List<_Level> levels,
  CompoundResult total,
) {
  final at = <double>[];
  for (final c in nodes) {
    at.addAll(<double>[c.x, c.y, c.w, c.h]);
  }
  final labels = <double>[];
  for (final e in edges) {
    labels.addAll(<double>[e.labelX, e.labelY]);
  }
  final places = <double>[];
  for (final level in levels) {
    places.addAll(<double>[level.x, level.y]);
    for (final port in level.ports) {
      places.addAll(<double>[port.px, port.py]);
    }
  }
  return _Snapshot(
    nodes: at,
    routes: edges.map((e) => List<double>.of(e.route)).toList(),
    labels: labels,
    levels: places,
    total: total,
  );
}

CompoundResult _restore(
  _Snapshot s,
  List<CNode> nodes,
  List<CEdge> edges,
  List<_Level> levels,
) {
  for (var i = 0; i < nodes.length; i++) {
    final c = nodes[i];
    c.x = s.nodes[4 * i];
    c.y = s.nodes[4 * i + 1];
    c.w = s.nodes[4 * i + 2];
    c.h = s.nodes[4 * i + 3];
  }
  for (var i = 0; i < edges.length; i++) {
    final e = edges[i];
    e.route = s.routes[i];
    e.labelX = s.labels[2 * i];
    e.labelY = s.labels[2 * i + 1];
  }
  var k = 0;
  for (final level in levels) {
    level.x = s.levels[k++];
    level.y = s.levels[k++];
    for (final port in level.ports) {
      port.px = s.levels[k++];
      port.py = s.levels[k++];
    }
  }
  return s.total;
}

const double _fan = 24;
const double _inLine = 0.5;
const int _curvePieces = 3;
const int _cornerPieces = 2;
final int _stepPieces = math.max(3, math.max(_curvePieces, _cornerPieces + 1));
const double _handle = 0.62;
const int _maxInsert = 128;

class Style {
  static const int curved = 0;
  static const int stepped = 1;
  static const int linear = 2;
  // Uppercase aliases matching TypeScript enum names.
  static const int Curved = 0;
  static const int Stepped = 1;
  static const int Linear = 2;
}

int styleOf(LayeredOptions opt) {
  return (opt.tracks == true)
      ? Style.stepped
      : (opt.straight == true)
      ? Style.linear
      : Style.curved;
}

int routeCrossings(
  List<CNode> nodes,
  List<CEdge> edges, [
  int style = Style.curved,
]) {
  var size = 0;
  for (final e in edges) {
    if (e.src != e.dst && e.route.length > 3) {
      size += (e.route.length ~/ 3 - 1) * _stepPieces;
    }
  }
  final ax = Float64List(size);
  final ay = Float64List(size);
  final bx = Float64List(size);
  final by = Float64List(size);
  final low = Float64List(size);
  final high = Float64List(size);
  final owner = Int32List(size);
  final ends = Uint8List(size);
  var count = 0;
  var top = double.infinity;
  var bottom = double.negativeInfinity;
  var fromX = double.nan;
  var fromY = double.nan;
  var toX = double.nan;
  var toY = double.nan;

  void add(int ei, int part, double x0, double y0, double x1, double y1) {
    final p = count - 1;
    final on =
        x0 == toX &&
        y0 == toY &&
        ((y1 == y0 && fromY == y0) || (x1 == x0 && fromX == x0));
    if (p >= 0 &&
        on &&
        owner[p] == ei &&
        ends[p] == part &&
        (x0 - fromX) * (x1 - x0) + (y0 - fromY) * (y1 - y0) > 0) {
      count--;
      x0 = fromX;
      y0 = fromY;
    }
    fromX = x0;
    fromY = y0;
    toX = x1;
    toY = y1;
    ends[count] = part;
    ax[count] = math.min(x0, x1);
    bx[count] = math.max(x0, x1);
    ay[count] = x0 <= x1 ? y0 : y1;
    by[count] = x0 <= x1 ? y1 : y0;
    low[count] = math.min(y0, y1);
    high[count] = math.max(y0, y1);
    if (low[count] < top) top = low[count];
    if (high[count] > bottom) bottom = high[count];
    owner[count++] = ei;
  }

  for (var ei = 0; ei < edges.length; ei++) {
    final e = edges[ei];
    if (e.src == e.dst) continue;
    final r = e.route;
    if (r.isEmpty) continue;
    bool aligned(int k) =>
        (r[k] - r[k - 3]).abs() < 0.01 || (r[k + 1] - r[k - 2]).abs() < 0.01;
    double length(int k) =>
        (r[k] - r[k - 3]).abs() + (r[k + 1] - r[k - 2]).abs();
    bool turns(int k) =>
        style == Style.curved &&
        k > 0 &&
        k < r.length - 3 &&
        aligned(k) &&
        aligned(k + 3) &&
        length(k) >= 0.01 &&
        length(k + 3) >= 0.01 &&
        ((r[k] - r[k - 3]).abs() < 0.01) != ((r[k + 3] - r[k]).abs() < 0.01);

    var atX = r[0];
    var atY = r[1];
    for (var k = 3; k < r.length; k += 3) {
      final part = (k == 3 ? 1 : 0) | (k == r.length - 3 ? 2 : 0);
      final x0 = atX;
      final y0 = atY;
      final x1 = r[k];
      final y1 = r[k + 1];
      atX = x1;
      atY = y1;
      if (aligned(k) || style == Style.linear) {
        if (!turns(k)) {
          add(ei, part, x0, y0, x1, y1);
          continue;
        }
        final before = turns(k - 3) ? length(k) / 2 : length(k);
        final after = turns(k + 3) ? length(k + 3) / 2 : length(k + 3);
        final ux = (x1 - r[k - 3]) / length(k);
        final uy = (y1 - r[k - 2]) / length(k);
        final vx = (r[k + 3] - x1) / length(k + 3);
        final vy = (r[k + 4] - y1) / length(k + 3);
        final sx = x1 - ux * before;
        final sy = y1 - uy * before;
        add(ei, part, x0, y0, sx, sy);
        final c1x = x1 - ux * before * (1 - _handle);
        final c1y = y1 - uy * before * (1 - _handle);
        final c2x = x1 + vx * after * (1 - _handle);
        final c2y = y1 + vy * after * (1 - _handle);
        atX = x1 + vx * after;
        atY = y1 + vy * after;
        final turn = part | (k + 3 == r.length - 3 ? 2 : 0);
        var px = sx;
        var py = sy;
        for (var i = 1; i <= _cornerPieces; i++) {
          final t = i / _cornerPieces;
          final u = 1 - t;
          final x =
              u * u * u * sx +
              3 * u * u * t * c1x +
              3 * u * t * t * c2x +
              t * t * t * atX;
          final y =
              u * u * u * sy +
              3 * u * u * t * c1y +
              3 * u * t * t * c2y +
              t * t * t * atY;
          add(ei, turn, px, py, x, y);
          px = x;
          py = y;
        }
        continue;
      }
      if (style == Style.stepped) {
        final down = r[k + 2] == 0;
        final mx = down ? x0 : (x0 + x1) / 2;
        final my = down ? (y0 + y1) / 2 : y0;
        add(ei, part, x0, y0, mx, my);
        add(ei, part, mx, my, down ? x1 : mx, down ? my : y1);
        add(ei, part, down ? x1 : mx, down ? my : y1, x1, y1);
        continue;
      }
      final down = r[k + 2] == 0;
      final c = down ? ease(x1 - x0, y1 - y0) : ease(y1 - y0, x1 - x0);
      var px = x0;
      var py = y0;
      for (var i = 1; i <= _curvePieces; i++) {
        final t = i / _curvePieces;
        final u = 1 - t;
        final across = t * t * (3 - 2 * t);
        final along = 3 * c * t * u * u + 3 * (1 - c) * t * t * u + t * t * t;
        final x = x0 + (x1 - x0) * (down ? across : along);
        final y = y0 + (y1 - y0) * (down ? along : across);
        add(ei, part, px, py, x, y);
        px = x;
        py = y;
      }
    }
  }

  final bands = bottom > top ? math.max(1, roundJs(math.sqrt(count))) : 1;
  final scale = bottom > top ? bands / (bottom - top) : 0.0;
  int bandOf(double y) => math.min(bands - 1, ((y - top) * scale).floor());
  final first = Int32List(count);
  final bandStart = Int32List(bands + 1);
  for (var p = 0; p < count; p++) {
    first[p] = bandOf(low[p]);
    for (var b = first[p], last = bandOf(high[p]); b <= last; b++) {
      bandStart[b + 1]++;
    }
  }
  for (var b = 0; b < bands; b++) {
    bandStart[b + 1] += bandStart[b];
  }
  final fill = Int32List.fromList(bandStart.sublist(0, bands));
  final inBand = Int32List(bandStart[bands]);
  for (var p = 0; p < count; p++) {
    for (var b = first[p], last = bandOf(high[p]); b <= last; b++) {
      inBand[fill[b]++] = p;
    }
  }

  final runs = Float64List(edges.length * 8);
  bool inLine(List<double> r, int a, int b, int c) =>
      ((r[a] - r[b]).abs() < _inLine && (r[a] - r[c]).abs() < _inLine) ||
      ((r[a + 1] - r[b + 1]).abs() < _inLine &&
          (r[a + 1] - r[c + 1]).abs() < _inLine);
  for (var ei = 0; ei < edges.length; ei++) {
    final r = edges[ei].route;
    if (r.length < 6) continue;
    var k = 3;
    while (k + 3 < r.length && inLine(r, 0, k, k + 3)) {
      k += 3;
    }
    final last = r.length - 3;
    var j = last - 3;
    while (j >= 3 && inLine(r, last, j, j - 3)) {
      j -= 3;
    }
    final base = ei * 8;
    runs[base] = r[0];
    runs[base + 1] = r[1];
    runs[base + 2] = r[k];
    runs[base + 3] = r[k + 1];
    runs[base + 4] = r[j];
    runs[base + 5] = r[j + 1];
    runs[base + 6] = r[last];
    runs[base + 7] = r[last + 1];
  }

  bool onRun(int ei, int end, double x, double y) {
    final o = ei * 8 + (end == 1 ? 0 : 4);
    final x0 = runs[o];
    final y0 = runs[o + 1];
    final dx = runs[o + 2] - x0;
    final dy = runs[o + 3] - y0;
    final length = dx * dx + dy * dy;
    final t = length > 0
        ? math.max(0.0, math.min(1.0, ((x - x0) * dx + (y - y0) * dy) / length))
        : 0.0;
    return hypot(x - x0 - t * dx, y - y0 - t * dy) < _inLine;
  }

  var total = 0;
  for (var band = 0; band < bands; band++) {
    final bandEnd = bandStart[band + 1];
    if (bandEnd - bandStart[band] > _maxInsert) {
      Int32List.sublistView(inBand, bandStart[band], bandEnd).sort((p, q) {
        final cmp = ax[p].compareTo(ax[q]);
        return cmp != 0 ? cmp : p - q;
      });
    } else {
      for (var i = bandStart[band] + 1; i < bandEnd; i++) {
        final p = inBand[i];
        var j = i;
        for (; j > bandStart[band] && ax[inBand[j - 1]] > ax[p]; j--) {
          inBand[j] = inBand[j - 1];
        }
        inBand[j] = p;
      }
    }
    for (var s = bandStart[band]; s < bandEnd; s++) {
      final p = inBand[s];
      final dx = bx[p] - ax[p];
      final dy = by[p] - ay[p];
      final here = first[p] == band;
      for (var t = s + 1; t < bandEnd; t++) {
        final q = inBand[t];
        if (ax[q] > bx[p]) break;
        if (high[q] < low[p] ||
            low[q] > high[p] ||
            owner[p] == owner[q] ||
            (!here && first[q] != band)) {
          continue;
        }
        final d1 = dx * (ay[q] - ay[p]) - dy * (ax[q] - ax[p]);
        final d2 = dx * (by[q] - ay[p]) - dy * (bx[q] - ax[p]);
        if ((d1 > 0) == (d2 > 0)) continue;
        final ex = bx[q] - ax[q];
        final ey = by[q] - ay[q];
        final d3 = ex * (ay[p] - ay[q]) - ey * (ax[p] - ax[q]);
        final d4 = ex * (by[p] - ay[q]) - ey * (bx[p] - ax[q]);
        if ((d3 > 0) == (d4 > 0)) continue;
        final ep = edges[owner[p]];
        final eq = edges[owner[q]];
        final at = d3 / (d3 - d4);
        final x = ax[p] + at * dx;
        final y = ay[p] + at * dy;
        bool fan(int v, int pe, int qe) =>
            ((ends[p] & pe) != 0 && (ends[q] & qe) != 0) ||
            ((x - nodes[v].x).abs() < nodes[v].w / 2 + _fan &&
                (y - nodes[v].y).abs() < nodes[v].h / 2 + _fan) ||
            (onRun(owner[p], pe, x, y) && onRun(owner[q], qe, x, y));
        if (ep.src == eq.src && fan(ep.src, 1, 1)) continue;
        if (ep.src == eq.dst && fan(ep.src, 1, 2)) continue;
        if (ep.dst == eq.src && fan(ep.dst, 2, 1)) continue;
        if (ep.dst == eq.dst && fan(ep.dst, 2, 2)) continue;
        total++;
      }
    }
  }
  return total;
}

/// Match Mermaid: groups crossed by edges inherit their parent's direction.
void inheritCrossedDirections(List<CNode> nodes, Iterable<(int, int)> ends) {
  Set<int> ancestors(int i) {
    final set = <int>{};
    for (
      var p = nodes[i].parent;
      p >= 0 && !set.contains(p);
      p = nodes[p].parent
    ) {
      set.add(p);
    }
    return set;
  }

  for (final (src, dst) in ends) {
    if (src < 0 || dst < 0 || src == dst) continue;
    final a = ancestors(src);
    final b = ancestors(dst);
    for (final g in a) {
      if (!b.contains(g)) nodes[g].dir = null;
    }
    for (final g in b) {
      if (!a.contains(g)) nodes[g].dir = null;
    }
  }
}

void shiftLayout(List<CNode> nodes, List<CEdge> edges, double ox, double oy) {
  for (final c in nodes) {
    c.x += ox;
    c.y += oy;
  }
  for (final e in edges) {
    for (var k = 0; k < e.route.length; k += 3) {
      e.route[k] += ox;
      e.route[k + 1] += oy;
    }
    e.labelX += ox;
    e.labelY += oy;
  }
}

CNode cnode(double w, double h, [int parent = -1]) {
  return CNode(w: w, h: h, parent: parent);
}

int _startSide(Dir dir) {
  return dir == 'TB'
      ? _Side.top
      : dir == 'BT'
      ? _Side.bottom
      : dir == 'LR'
      ? _Side.left
      : _Side.right;
}

int _opposite(int side) {
  return (side + 2) & 3;
}

class _BuiltLevel {
  final List<LNode> lnodes;
  final List<LEdge> ledges;
  final Int32List dummies;

  const _BuiltLevel({
    required this.lnodes,
    required this.ledges,
    required this.dummies,
  });
}

class _LaidLevel {
  final List<double> given;
  final List<LNode> lnodes;
  final List<LEdge> ledges;
  final LayeredResult size;

  const _LaidLevel({
    required this.given,
    required this.lnodes,
    required this.ledges,
    required this.size,
  });
}

bool _sameDouble(double a, double b) {
  if (a.isNaN && b.isNaN) return true;
  return a == b;
}

/// Lays out a graph whose nodes may be nested in groups.
CompoundResult compoundLayout(
  List<CNode> nodes,
  List<CEdge> edges,
  Dir rootDir,
  LayeredOptions opt,
) {
  final n = nodes.length;
  final levelOf = <int, _Level>{};
  final order = <_Level>[];
  _Level makeLevel(int id, Dir dir) {
    final level = _Level(id: id, dir: dir);
    levelOf[id] = level;
    return level;
  }

  final root = makeLevel(-1, rootDir);

  final children = List<List<int>>.generate(n, (_) => <int>[]);
  final rootItems = <int>[];
  for (var i = 0; i < n; i++) {
    final p = nodes[i].parent;
    if (p >= 0 && p < n && p != i && nodes[p].isGroup) {
      children[p].add(i);
    } else {
      nodes[i].parent = -1;
      rootItems.add(i);
    }
  }
  root.items = rootItems;
  order.add(root);
  final depth = Int32List(n);
  final placed = Uint8List(n);
  void descend(int from) {
    for (var q = from; q < order.length; q++) {
      final level = order[q];
      for (final item in level.items) {
        placed[item] = 1;
        depth[item] = level.id < 0 ? 0 : depth[level.id] + 1;
        if (nodes[item].isGroup) {
          final child = makeLevel(item, nodes[item].dir ?? level.dir);
          child.items = children[item];
          order.add(child);
        }
      }
    }
  }

  descend(0);
  for (var i = 0; i < n; i++) {
    if (placed[i] != 0) continue;
    final former = nodes[i].parent;
    if (former >= 0 && former < n) {
      children[former] = children[former].where((c) => c != i).toList();
    }
    nodes[i].parent = -1;
    root.items.add(i);
    placed[i] = 1;
    depth[i] = 0;
    if (nodes[i].isGroup) {
      final from = order.length;
      final child = makeLevel(i, nodes[i].dir ?? rootDir);
      child.items = children[i];
      order.add(child);
      descend(from);
    }
  }

  for (var q = order.length - 1; q > 0; q--) {
    final level = order[q];
    var seq = double.infinity;
    for (final item in level.items) {
      if (nodes[item].seq < seq) seq = nodes[item].seq;
    }
    if (seq != double.infinity) nodes[level.id].seq = seq;
  }
  for (final level in order) {
    level.items.sort((a, b) {
      final cmp = nodes[a].seq.compareTo(nodes[b].seq);
      return cmp != 0 ? cmp : a - b;
    });
  }

  var ports = 0;
  for (final e in edges) {
    var a = e.src;
    var b = e.dst;
    var crossed = 0;
    for (; depth[a] > depth[b]; crossed++) {
      a = nodes[a].parent;
    }
    for (; depth[b] > depth[a]; crossed++) {
      b = nodes[b].parent;
    }
    for (; a != b && nodes[a].parent != nodes[b].parent; crossed += 2) {
      a = nodes[a].parent;
      b = nodes[b].parent;
    }
    if (a == b) continue;
    if (ports + crossed > _maxPorts) {
      e.src = a;
      e.dst = b;
    } else {
      ports += crossed;
    }
  }

  final loops = <int>[];
  final stray = <int>[];
  for (var ei = 0; ei < edges.length; ei++) {
    final e = edges[ei];
    e.route = <double>[];
    if (e.src == e.dst) {
      loops.add(ei);
      continue;
    }
    var a = e.src;
    var b = e.dst;
    final aPath = <int>[];
    final bPath = <int>[];
    while (depth[a] > depth[b]) {
      aPath.add(a);
      a = nodes[a].parent;
    }
    while (depth[b] > depth[a]) {
      bPath.add(b);
      b = nodes[b].parent;
    }
    if (a == b) {
      stray.add(ei);
      continue;
    }
    while (nodes[a].parent != nodes[b].parent) {
      aPath.add(a);
      bPath.add(b);
      a = nodes[a].parent;
      b = nodes[b].parent;
    }
    levelOf[nodes[a].parent]!.edges.add(_LevelEdge(e: ei, a: a, b: b));
    for (final (path, out) in <(List<int>, bool)>[
      (aPath, true),
      (bPath, false),
    ]) {
      for (final inner in path) {
        final level = levelOf[nodes[inner].parent]!;
        final port = _PortEdge(
          e: ei,
          inner: inner,
          out: out,
          side: _Side.top,
          hint: double.nan,
          px: 0,
          py: 0,
          route: <double>[],
        );
        level.ports.add(port);
        level.portOf[ei * 2 + (out ? 0 : 1)] = port;
      }
    }
  }

  final local = Int32List(n);
  bool endpointBelow(int item, CEdge e, bool out) =>
      (out ? e.src : e.dst) != item;

  final ordered =
      ports > 1 &&
      ports <= _maxOrderedPorts &&
      edges.length <= _maxOrderedEdges;

  final key = Float64List(n);
  for (var i = 0; i < n; i++) {
    key[i] = double.nan;
  }
  var keyed = false;
  var flatCrossings = 0;
  double Function(_Level level, _PortEdge port)? farHint;
  var flat = order.length > 1 && ordered;
  for (final level in order) {
    if (level.dir != rootDir) flat = false;
  }
  if (flat) {
    final vertical = rootDir == 'TB' || rootDir == 'BT';
    final leaf = Int32List(n)..fillRange(0, n, -1);
    final group = Int32List(n)..fillRange(0, n, -1);
    final lnodes = <LNode>[];
    final ofList = <int>[];
    final parent = <int>[];
    for (var i = 0; i < n; i++) {
      if (!nodes[i].isGroup) continue;
      group[i] = parent.length;
      parent.add(-1);
    }
    for (var i = 0; i < n; i++) {
      final p = nodes[i].parent;
      if (nodes[i].isGroup) {
        parent[group[i]] = p >= 0 ? group[p] : -1;
      } else {
        leaf[i] = lnodes.length;
        lnodes.add(
          lnode(
            vertical ? nodes[i].w : nodes[i].h,
            vertical ? nodes[i].h : nodes[i].w,
          ),
        );
        ofList.add(p >= 0 ? group[p] : -1);
      }
    }
    final ledges = <LEdge>[];
    final ledgeOf = Int32List(edges.length)..fillRange(0, edges.length, -1);
    for (var ei = 0; ei < edges.length; ei++) {
      final e = edges[ei];
      if (e.src == e.dst || leaf[e.src] < 0 || leaf[e.dst] < 0) continue;
      ledgeOf[ei] = ledges.length;
      ledges.add(
        ledge(
          leaf[e.src],
          leaf[e.dst],
          e.minlen,
          vertical ? e.labelW : e.labelH,
          vertical ? e.labelH : e.labelW,
        ),
      );
    }
    final flatLayout = layered(
      lnodes,
      ledges,
      opt.copyWith(
        groups: LayeredGroups(
          of: Int32List.fromList(ofList),
          parent: Int32List.fromList(parent),
        ),
        orderOnly: true,
      ),
    );
    flatCrossings = math.min(
      flatLayout.crossings ?? 0,
      flatLayout.declared ?? 0,
    );
    final sum = Float64List(n);
    final count = Int32List(n);
    final last = Int32List(n)..fillRange(0, n, -1);
    for (var i = 0; i < n; i++) {
      if (leaf[i] < 0) continue;
      key[i] = lnodes[leaf[i]].x;
      for (var p = nodes[i].parent; p >= 0; p = nodes[p].parent) {
        sum[p] += key[i];
        count[p]++;
        last[p] = math.max(last[p], lnodes[leaf[i]].rank);
      }
    }
    for (var i = 0; i < n; i++) {
      if (count[i] > 0) key[i] = sum[i] / count[i];
    }
    farHint = (_Level level, _PortEdge port) {
      final le = ledgeOf[port.e];
      if (le < 0 ||
          level.id < 0 ||
          !port.out ||
          port.side != _opposite(_startSide(level.dir))) {
        return double.nan;
      }
      final points = ledges[le].points;
      var inside = key[edges[port.e].src];
      var outside = 0.0;
      for (var k = 0; k < points.length; k += 2) {
        if (points[k] == last[level.id]) inside = points[k + 1];
        if (points[k] == last[level.id] + 1) outside = points[k + 1];
      }
      return inside + outside * 1e-6;
    };
  }

  _BuiltLevel build(_Level level, bool sized) {
    final vertical = level.dir == 'TB' || level.dir == 'BT';
    final start = _startSide(level.dir);
    final lnodes = <LNode>[];
    final ledges = <LEdge>[];
    for (var i = 0; i < level.items.length; i++) {
      final item = level.items[i];
      local[item] = i;
      final node = nodes[item];
      final ln = sized
          ? lnode(vertical ? node.w : node.h, vertical ? node.h : node.w)
          : lnode(0, 0);
      ln.span = node.isGroup
          ? math.min(node.span, ln.w - 2 * node.padX)
          : node.span;
      ln.key = keyed ? key[item] : double.nan;
      lnodes.add(ln);
    }
    bool held(int item, int ei, bool out) =>
        nodes[item].isGroup && endpointBelow(item, edges[ei], out);
    double offset(int item, int ei, bool out) {
      if (!sized ||
          !nodes[item].isGroup ||
          !endpointBelow(item, edges[ei], out)) {
        return 0;
      }
      final port = levelOf[item]!.portOf[ei * 2 + (out ? 0 : 1)]!;
      return vertical
          ? port.px - nodes[item].w / 2
          : port.py - nodes[item].h / 2;
    }

    for (final le in level.edges) {
      final e = edges[le.e];
      final edge = ledge(local[le.a], local[le.b], e.minlen);
      if (sized) {
        edge.labelW = vertical ? e.labelW : e.labelH;
        edge.labelH = vertical ? e.labelH : e.labelW;
        edge.tailDx = offset(le.a, le.e, true);
        edge.headDx = offset(le.b, le.e, false);
        edge.tailFixed = held(le.a, le.e, true);
        edge.headFixed = held(le.b, le.e, false);
      }
      ledges.add(edge);
    }
    final dummies = Int32List(level.ports.length)
      ..fillRange(0, level.ports.length, -1);
    for (var i = 0; i < level.ports.length; i++) {
      final port = level.ports[i];
      if (port.side == start || port.side == _opposite(start)) {
        final d = lnodes.length;
        final ln = lnode(
          0,
          0,
          port.side == start ? Kind.startPort : Kind.endPort,
        );
        ln.key = keyed
            ? key[port.out ? edges[port.e].dst : edges[port.e].src]
            : double.nan;
        ln.hint = port.hint.isNaN && keyed && farHint != null
            ? farHint(level, port)
            : port.hint;
        lnodes.add(ln);
        dummies[i] = d;
        final edge = port.out
            ? ledge(local[port.inner], d)
            : ledge(d, local[port.inner]);
        if (port.out) {
          edge.tailDx = offset(port.inner, port.e, true);
          edge.tailFixed = held(port.inner, port.e, true);
        } else {
          edge.headDx = offset(port.inner, port.e, false);
          edge.headFixed = held(port.inner, port.e, false);
        }
        ledges.add(edge);
      } else {
        lnodes[local[port.inner]].pin =
            port.side == _Side.top || port.side == _Side.left ? -1 : 1;
      }
    }
    return _BuiltLevel(lnodes: lnodes, ledges: ledges, dummies: dummies);
  }

  final laid = <int, List<_LaidLevel>>{};
  _LaidLevel layOut(_Level level, List<LNode> lnodes, List<LEdge> ledges) {
    if (!ordered) {
      return _LaidLevel(
        given: const <double>[],
        lnodes: lnodes,
        ledges: ledges,
        size: layered(lnodes, ledges, opt),
      );
    }
    final given = <double>[];
    for (final ln in lnodes) {
      given.addAll(<double>[
        ln.w,
        ln.h,
        ln.kind.toDouble(),
        ln.pin.toDouble(),
        ln.hint,
        ln.key,
        ln.span,
      ]);
    }
    for (final le in ledges) {
      given.addAll(<double>[
        le.tail.toDouble(),
        le.head.toDouble(),
        le.minlen.toDouble(),
        le.labelW,
        le.labelH,
        le.tailDx,
        le.headDx,
        le.tailFixed ? 1.0 : 0.0,
        le.headFixed ? 1.0 : 0.0,
      ]);
    }
    var past = laid[level.id];
    if (past == null) {
      past = <_LaidLevel>[];
      laid[level.id] = past;
    }
    for (final p in past) {
      var same = p.given.length == given.length;
      for (var i = 0; same && i < given.length; i++) {
        same = _sameDouble(p.given[i], given[i]);
      }
      if (same) return p;
    }
    final done = _LaidLevel(
      given: given,
      lnodes: lnodes,
      ledges: ledges,
      size: layered(lnodes, ledges, opt),
    );
    past.add(done);
    return done;
  }

  var total = const CompoundResult(width: 0, height: 0);
  void place() {
    for (final level in order) {
      for (final port in level.ports) {
        if (nodes[port.inner].isGroup &&
            endpointBelow(port.inner, edges[port.e], port.out)) {
          levelOf[port.inner]!.portOf[port.e * 2 + (port.out ? 0 : 1)]!.side =
              port.side;
        }
      }
      if (level.edges.isEmpty) continue;
      var needed = false;
      for (final le in level.edges) {
        final e = edges[le.e];
        if ((nodes[le.a].isGroup && e.src != le.a) ||
            (nodes[le.b].isGroup && e.dst != le.b)) {
          needed = true;
        }
      }
      if (!needed) continue;
      final built = build(level, false);
      orient(built.lnodes, built.ledges);
      rank(built.lnodes, built.ledges, 1);
      final start = _startSide(level.dir);
      for (var i = 0; i < level.edges.length; i++) {
        final le = level.edges[i];
        final e = edges[le.e];
        final aAbove = !built.ledges[i].reversed;
        if (nodes[le.a].isGroup && e.src != le.a) {
          levelOf[le.a]!.portOf[le.e * 2]!.side = aAbove
              ? _opposite(start)
              : start;
        }
        if (nodes[le.b].isGroup && e.dst != le.b) {
          levelOf[le.b]!.portOf[le.e * 2 + 1]!.side = aAbove
              ? start
              : _opposite(start);
        }
      }
    }

    for (var q = order.length - 1; q >= 0; q--) {
      final level = order[q];
      final group = level.id >= 0 ? nodes[level.id] : null;
      final vertical = level.dir == 'TB' || level.dir == 'BT';
      final flip = level.dir == 'BT' || level.dir == 'RL';
      final built = build(level, true);
      final laidLevel = layOut(level, built.lnodes, built.ledges);
      final lnodes = laidLevel.lnodes;
      final ledges = laidLevel.ledges;
      final size = laidLevel.size;
      final dummies = built.dummies;
      final contentW = vertical ? size.width : size.height;
      final contentH = vertical ? size.height : size.width;
      final padX = group != null ? group.padX : 0.0;
      final padTop = group != null ? group.padTop : 0.0;
      final boxW = math.max(
        contentW + 2 * padX,
        group != null ? group.minW : 0.0,
      );
      final boxH = contentH + padTop + (group != null ? group.padBottom : 0.0);
      final offX = (boxW - contentW) / 2;
      final offY = padTop;
      double tx(double lx, double ly) =>
          offX + (vertical ? lx : (flip ? size.height - ly : ly));
      double ty(double lx, double ly) =>
          offY + (vertical ? (flip ? size.height - ly : ly) : lx);
      final axis = vertical ? 0.0 : 1.0;
      List<double> convert(List<double> points) {
        final out = <double>[];
        for (var i = 0; i < points.length; i += 2) {
          out.addAll(<double>[
            tx(points[i], points[i + 1]),
            ty(points[i], points[i + 1]),
            axis,
          ]);
        }
        return out;
      }

      for (var i = 0; i < level.items.length; i++) {
        final item = level.items[i];
        nodes[item].x = tx(lnodes[i].x, lnodes[i].y);
        nodes[item].y = ty(lnodes[i].x, lnodes[i].y);
      }
      for (var i = 0; i < level.edges.length; i++) {
        final le = level.edges[i];
        final edge = ledges[i];
        level.routes[le.e] = convert(edge.points);
        final e = edges[le.e];
        if (e.labelW > 0) {
          e.labelX = tx(edge.labelX, edge.labelY);
          e.labelY = ty(edge.labelX, edge.labelY);
        }
      }
      var k = level.edges.length;
      for (var i = 0; i < level.ports.length; i++) {
        final port = level.ports[i];
        final item = nodes[port.inner];
        if (dummies[i] >= 0) {
          final route = convert(ledges[k++].points);
          final at = port.out ? route.length - 3 : 0;
          var bx = route[at];
          var by = route[at + 1];
          if (port.side == _Side.top) {
            by = 0;
          } else if (port.side == _Side.bottom) {
            by = boxH;
          } else if (port.side == _Side.left) {
            bx = 0;
          } else {
            bx = boxW;
          }
          if (port.out) {
            route.addAll(<double>[bx, by, axis]);
          } else {
            route.insertAll(0, <double>[bx, by, axis]);
          }
          port.px = bx;
          port.py = by;
          port.route = route;
          continue;
        }
        var ix = item.x;
        var iy = item.y;
        if (item.isGroup &&
            endpointBelow(port.inner, edges[port.e], port.out)) {
          final inner =
              levelOf[port.inner]!.portOf[port.e * 2 + (port.out ? 0 : 1)]!;
          ix += inner.px - item.w / 2;
          iy += inner.py - item.h / 2;
        } else if (port.side == _Side.top) {
          iy -= item.h / 2;
        } else if (port.side == _Side.bottom) {
          iy += item.h / 2;
        } else if (port.side == _Side.left) {
          ix -= item.w / 2;
        } else {
          ix += item.w / 2;
        }
        var bx = ix;
        var by = iy;
        if (port.side == _Side.top) {
          by = 0;
        } else if (port.side == _Side.bottom) {
          by = boxH;
        } else if (port.side == _Side.left) {
          bx = 0;
        } else {
          bx = boxW;
        }
        final a = (port.side == _Side.top || port.side == _Side.bottom)
            ? 0.0
            : 1.0;
        port.px = bx;
        port.py = by;
        port.route = port.out
            ? <double>[ix, iy, a, bx, by, a]
            : <double>[bx, by, a, ix, iy, a];
      }

      if (group != null) {
        group.w = boxW;
        group.h = boxH;
      } else {
        total = CompoundResult(width: boxW, height: boxH);
      }
    }

    for (final level in order) {
      final ox = level.x;
      final oy = level.y;
      for (final item in level.items) {
        final node = nodes[item];
        node.x += ox;
        node.y += oy;
        if (node.isGroup) {
          final child = levelOf[item]!;
          child.x = node.x - node.w / 2;
          child.y = node.y - node.h / 2;
        }
      }
    }

    void append(List<double> route, List<double> part, double ox, double oy) {
      for (var i = 0; i < part.length; i += 3) {
        final x = part[i] + ox;
        final y = part[i + 1] + oy;
        final len = route.length;
        if (len >= 3 &&
            (route[len - 3] - x).abs() < 0.01 &&
            (route[len - 2] - y).abs() < 0.01) {
          continue;
        }
        route.addAll(<double>[x, y, part[i + 2]]);
      }
    }

    for (final level in order) {
      for (final le in level.edges) {
        final e = edges[le.e];
        final route = <double>[];
        final outward = <_Level>[];
        for (
          var item = e.src;
          nodes[item].parent != level.id;
          item = nodes[item].parent
        ) {
          outward.add(levelOf[nodes[item].parent]!);
        }
        for (final lv in outward) {
          append(route, lv.portOf[le.e * 2]!.route, lv.x, lv.y);
        }
        append(route, level.routes[le.e]!, level.x, level.y);
        final inward = <_Level>[];
        for (
          var item = e.dst;
          nodes[item].parent != level.id;
          item = nodes[item].parent
        ) {
          inward.add(levelOf[nodes[item].parent]!);
        }
        for (var i = inward.length - 1; i >= 0; i--) {
          append(
            route,
            inward[i].portOf[le.e * 2 + 1]!.route,
            inward[i].x,
            inward[i].y,
          );
        }
        e.route = route;
        if (e.labelW > 0) {
          e.labelX += level.x;
          e.labelY += level.y;
        }
      }
    }
  }

  final style = styleOf(opt);
  keyed = flat;
  place();
  var crossings = -1;
  if (flat) {
    crossings = routeCrossings(nodes, edges, style);
    if (crossings > flatCrossings * _flatSlack + _flatSpare) {
      final first = _snapshot(nodes, edges, order, total);
      keyed = false;
      place();
      final own = routeCrossings(nodes, edges, style);
      if (own >= crossings) {
        keyed = true;
        total = _restore(first, nodes, edges, order);
      } else {
        crossings = own;
      }
    }
  }

  if (keyed == flat && ordered) {
    var again = false;
    for (final level in order) {
      if (level.id < 0) continue;
      final box = nodes[level.id];
      final vertical = level.dir == 'TB' || level.dir == 'BT';
      final end = _opposite(_startSide(level.dir));
      final seen = <List<double>>[];
      for (final port in level.ports) {
        if (port.side != end) continue;
        final route = edges[port.e].route;
        final bx = level.x + port.px;
        final by = level.y + port.py;
        var at = -1;
        for (var k = 0; k < route.length && (at < 0 || port.out); k += 3) {
          if ((route[k] - bx).abs() < 0.01 &&
              (route[k + 1] - by).abs() < 0.01) {
            at = k;
          }
        }
        if (at < 0) continue;
        final a = vertical ? 0 : 1;
        var next = port.out ? at + 3 : at - 3;
        while (next >= 0 &&
            next < route.length &&
            (route[next + a] - route[at + a]).abs() < _inLine) {
          next += port.out ? 3 : -3;
        }
        if (next < 0 || next >= route.length) continue;
        port.hint =
            route[next + a] -
            (vertical ? box.x - box.w / 2 : box.y - box.h / 2);
        seen.add(<double>[vertical ? port.px : port.py, port.hint]);
      }
      seen.sort((p, q) => p[0].compareTo(q[0]));
      for (var i = 1; i < seen.length; i++) {
        if (seen[i - 1][1] > seen[i][1]) again = true;
      }
    }
    if (again) {
      final before = crossings >= 0
          ? crossings
          : routeCrossings(nodes, edges, style);
      final first = before > 0 ? _snapshot(nodes, edges, order, total) : null;
      if (first != null) {
        place();
        if (routeCrossings(nodes, edges, style) >= before) {
          total = _restore(first, nodes, edges, order);
        }
      }
    }
  }

  for (final ei in stray) {
    final e = edges[ei];
    final a = nodes[e.src];
    final b = nodes[e.dst];
    e.route = <double>[a.x, a.y, 0, b.x, b.y, 0];
    e.labelX = (a.x + b.x) / 2;
    e.labelY = (a.y + b.y) / 2;
  }
  for (final ei in loops) {
    final e = edges[ei];
    final node = nodes[e.src];
    e.labelX = node.x + node.w / 2 + 28 + e.labelW / 2;
    e.labelY = node.y;
  }

  return total;
}

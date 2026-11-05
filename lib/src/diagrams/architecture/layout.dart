// Upstream: src/diagrams/architecture/layout.ts

import 'dart:math' as math;
import 'dart:typed_data';

import 'db.dart';
import 'parser.dart';

class Grid {
  const Grid({
    required this.col,
    required this.row,
    required this.groupCol,
    required this.groupRow,
    required this.groupCols,
    required this.groupRows,
    required this.groupParent,
    required this.groupEmpty,
    required this.nodeParent,
  });

  // Cell of each node, in the order of the nodes passed in.
  final Int32List col;
  final Int32List row;
  // Cell rectangle and parent of each group. A group with nothing in it takes one cell.
  final Int32List groupCol;
  final Int32List groupRow;
  final Int32List groupCols;
  final Int32List groupRows;
  final Int32List groupParent;
  final Uint8List groupEmpty;
  final Int32List nodeParent;
}

const List<int> _dx = <int>[-1, 1, 0, 0];
const List<int> _dy = <int>[0, 0, -1, 1];

int sideIndex(Side side) {
  return side == 'L'
      ? 0
      : side == 'R'
      ? 1
      : side == 'T'
      ? 2
      : 3;
}

// Blocks up to this many cells are found through the cell map; larger ones are compared one by one.
const int _small = 64;
const int _offset = 1 << 25;
const int _span = 1 << 26;

Grid placeOnGrid(
  List<ArchNode> nodes,
  List<ArchGroup> groups,
  List<ArchEdge> edges,
  List<ArchLayoutHint> hints,
) {
  final n = nodes.length;
  final gCount = groups.length;
  final root = gCount;
  final nodeIndex = <String, int>{};
  final groupIndex = <String, int>{};
  // Items are nodes (0..N-1) then groups (N..N+G-1). Containers are groups (0..G-1) then the root.
  final parent = Int32List(n + gCount)..fillRange(0, n + gCount, root);
  final depth = Int32List(gCount + 1);
  final kids = List<List<int>>.generate(gCount + 1, (_) => <int>[]);
  for (var g = 0; g < gCount; g++) {
    final group = groups[g];
    groupIndex[group.id] = g;
    final p = group.inGroup == null ? null : groupIndex[group.inGroup!];
    if (p != null && p != g) {
      parent[n + g] = p;
      depth[g] = depth[p] + 1;
    } else {
      depth[g] = 1;
    }
  }
  for (var i = 0; i < n; i++) {
    final node = nodes[i];
    nodeIndex[node.id] = i;
    final p = node.inGroup == null ? null : groupIndex[node.inGroup!];
    if (p != null) parent[i] = p;
    kids[parent[i]].add(i);
  }
  for (var g = 0; g < gCount; g++) {
    kids[parent[n + g]].add(n + g);
  }

  // A link asks for one node to sit beside another. It belongs to the innermost container that
  // holds both ends, and there it relates the two children of that container the ends are in.
  final linkA = <int>[];
  final linkB = <int>[];
  final sideA = <int>[];
  final sideB = <int>[];
  final itemA = <int>[];
  final itemB = <int>[];
  final hintLinks = List<List<int>?>.filled(n + gCount, null);
  final edgeLinks = List<List<int>?>.filled(n + gCount, null);

  void addLink(int a, int b, int sa, int sb, List<List<int>?> lists) {
    if (a == b) return;
    var ia = a;
    var ib = b;
    var ca = parent[a];
    var cb = parent[b];
    while (ca != cb) {
      if (depth[ca] >= depth[cb]) {
        ia = n + ca;
        ca = parent[ia];
      } else {
        ib = n + cb;
        cb = parent[ib];
      }
    }
    final k = linkA.length;
    linkA.add(a);
    linkB.add(b);
    sideA.add(sa);
    sideB.add(sb);
    itemA.add(ia);
    itemB.add(ib);
    (lists[ia] ??= <int>[]).add(k);
    (lists[ib] ??= <int>[]).add(k);
  }

  for (final hint in hints) {
    final row = hint.direction == 'row';
    for (var i = 1; i < hint.members.length; i++) {
      final a = nodeIndex[hint.members[i - 1]];
      final b = nodeIndex[hint.members[i]];
      if (a != null && b != null) {
        addLink(a, b, row ? 1 : 3, row ? 0 : 2, hintLinks);
      }
    }
  }
  // An edge between two like sides says least about where its ends go, so those come last.
  for (final likeSides in const <bool>[false, true]) {
    for (final edge in edges) {
      if ((edge.lhsDir == edge.rhsDir) != likeSides) continue;
      final a = nodeIndex[edge.lhsId];
      final b = nodeIndex[edge.rhsId];
      if (a != null && b != null) {
        addLink(
          a,
          b,
          sideIndex(edge.lhsDir),
          sideIndex(edge.rhsDir),
          edgeLinks,
        );
      }
    }
  }

  // Position of each item in its container, and its size in cells.
  final x = Int32List(n + gCount);
  final y = Int32List(n + gCount);
  final w = Int32List(n + gCount)..fillRange(0, n + gCount, 1);
  final h = Int32List(n + gCount)..fillRange(0, n + gCount, 1);
  final placed = Uint8List(n + gCount);

  final order = <int>[];
  final cells = <int, int>{};
  final large = <int>[];
  final reach = <String, int>{};
  var first = 0;
  var ax = 0;
  var ay = 0;

  void anchor(int node, int item) {
    ax = 0;
    ay = 0;
    for (var cur = node; cur != item; cur = n + parent[cur]) {
      ax += x[cur];
      ay += y[cur];
    }
  }

  void put(int item, int px, int py) {
    x[item] = px;
    y[item] = py;
    placed[item] = 1;
    order.add(item);
    if (w[item] * h[item] > _small) {
      large.add(item);
      return;
    }
    for (var cy = py; cy < py + h[item]; cy++) {
      for (var cx = px; cx < px + w[item]; cx++) {
        cells[(cx + _offset) * _span + cy + _offset] = item;
      }
    }
  }

  bool overlaps(int item, int rx, int ry, int rw, int rh) =>
      x[item] < rx + rw &&
      rx < x[item] + w[item] &&
      y[item] < ry + rh &&
      ry < y[item] + h[item];

  int collide(int rx, int ry, int rw, int rh) {
    if (rw * rh > _small) {
      for (var i = first; i < order.length; i++) {
        if (overlaps(order[i], rx, ry, rw, rh)) return order[i];
      }
      return -1;
    }
    for (var cy = ry; cy < ry + rh; cy++) {
      for (var cx = rx; cx < rx + rw; cx++) {
        final hit = cells[(cx + _offset) * _span + cy + _offset];
        if (hit != null) return hit;
      }
    }
    for (final item in large) {
      if (overlaps(item, rx, ry, rw, rh)) return item;
    }
    return -1;
  }

  int slide(int rx, int ry, int rw, int rh, int sx, int sy) {
    final key = '$rx,$ry,$rw,$rh,$sx,$sy';
    var k = reach[key] ?? 0;
    for (;;) {
      final hit = collide(rx + k * sx, ry + k * sy, rw, rh);
      if (hit < 0) break;
      k = sx > 0
          ? x[hit] + w[hit] - rx
          : sx < 0
          ? rx + rw - x[hit]
          : sy > 0
          ? y[hit] + h[hit] - ry
          : ry + rh - y[hit];
    }
    reach[key] = k;
    return k;
  }

  void follow(int from, int k) {
    final forward = itemA[k] == from;
    final to = forward ? itemB[k] : itemA[k];
    if (placed[to] != 0) return;
    final sp = forward ? sideA[k] : sideB[k];
    final sq = forward ? sideB[k] : sideA[k];
    anchor(forward ? linkA[k] : linkB[k], from);
    final pax = ax;
    final pay = ay;
    anchor(forward ? linkB[k] : linkA[k], to);
    var dx = _dx[sp];
    var dy = _dy[sp];
    var shiftX = 0;
    var shiftY = 0;
    final facing = _dx[sp] + _dx[sq] == 0 && _dy[sp] + _dy[sq] == 0;
    if (sp == sq) {
      // Like sides: the edge loops around, so the nodes stack across the direction it leaves in.
      dx = _dx[sp] == 0 ? 1 : 0;
      dy = 1 - dx;
    } else if (!facing) {
      // A bend: one step along the side the edge leaves, one step back from the side it enters.
      shiftX = -_dx[sq];
      shiftY = -_dy[sq];
    }
    int bx;
    int by;
    if (dx != 0) {
      bx = dx > 0 ? x[from] + w[from] : x[from] - w[to];
      by = y[from] + pay + shiftY - ay;
    } else {
      by = dy > 0 ? y[from] + h[from] : y[from] - h[to];
      bx = x[from] + pax + shiftX - ax;
    }
    if (facing) {
      final list = edgeLinks[to];
      if (list != null && list.length > 1) {
        final wanted = <int>[];
        for (final j in list) {
          final toIsB = itemB[j] == to;
          final other = toIsB ? itemA[j] : itemB[j];
          if (placed[other] == 0 ||
              (toIsB ? sideA[j] : sideB[j]) != sp ||
              (toIsB ? sideB[j] : sideA[j]) != sq) {
            continue;
          }
          anchor(toIsB ? linkA[j] : linkB[j], other);
          final at = dx != 0 ? y[other] + ay : x[other] + ax;
          anchor(toIsB ? linkB[j] : linkA[j], to);
          wanted.add(at - (dx != 0 ? ay : ax));
        }
        if (wanted.length > 1) {
          wanted.sort((a, b) => a.compareTo(b));
          if (dx != 0) {
            by = wanted[(wanted.length - 1) >> 1];
          } else {
            bx = wanted[(wanted.length - 1) >> 1];
          }
        }
      }
      final px = dx == 0 ? 1 : 0;
      final py = 1 - px;
      final forth = slide(bx, by, w[to], h[to], px, py);
      final back = forth == 0 ? 0 : slide(bx, by, w[to], h[to], -px, -py);
      final near = forth <= back ? forth : -back;
      bx += px * near;
      by += py * near;
    } else {
      final far = slide(bx, by, w[to], h[to], dx, dy);
      bx += dx * far;
      by += dy * far;
    }
    put(to, bx, by);
  }

  void layout(int c) {
    final items = kids[c];
    if (items.isEmpty) return;
    order.clear();
    final starts = <int>[];
    for (final start in items) {
      if (placed[start] != 0) continue;
      first = order.length;
      starts.add(first);
      cells.clear();
      large.clear();
      reach.clear();
      put(start, 0, 0);
      var hintAt = first;
      var edgeAt = first;
      var linkAt = 0;
      for (;;) {
        if (hintAt < order.length) {
          final from = order[hintAt++];
          final list = hintLinks[from];
          if (list != null) {
            for (final k in list) {
              follow(from, k);
            }
          }
          continue;
        }
        if (edgeAt >= order.length) break;
        final list = edgeLinks[order[edgeAt]];
        if (list == null || linkAt >= list.length) {
          edgeAt++;
          linkAt = 0;
          continue;
        }
        follow(order[edgeAt], list[linkAt++]);
      }
    }
    starts.add(order.length);

    final count = starts.length - 1;
    final minX = Int32List(count);
    final minY = Int32List(count);
    final partW = Int32List(count);
    final partH = Int32List(count);
    var area = 0;
    var widest = 0;
    for (var p = 0; p < count; p++) {
      var x0 = 1 << 30;
      var y0 = 1 << 30;
      var x1 = -(1 << 30);
      var y1 = -(1 << 30);
      for (var i = starts[p]; i < starts[p + 1]; i++) {
        final item = order[i];
        x0 = math.min(x0, x[item]);
        y0 = math.min(y0, y[item]);
        x1 = math.max(x1, x[item] + w[item]);
        y1 = math.max(y1, y[item] + h[item]);
      }
      minX[p] = x0;
      minY[p] = y0;
      partW[p] = x1 - x0;
      partH[p] = y1 - y0;
      area += partW[p] * partH[p];
      widest = math.max(widest, partW[p]);
    }
    final limit = math.max(widest, math.sqrt(area * 2).ceil());
    var cx = 0;
    var cy = 0;
    var shelf = 0;
    var width = 0;
    for (var p = 0; p < count; p++) {
      if (cx > 0 && cx + partW[p] > limit) {
        cy += shelf;
        cx = 0;
        shelf = 0;
      }
      for (var i = starts[p]; i < starts[p + 1]; i++) {
        x[order[i]] += cx - minX[p];
        y[order[i]] += cy - minY[p];
      }
      cx += partW[p];
      shelf = math.max(shelf, partH[p]);
      width = math.max(width, cx);
    }
    if (c < gCount) {
      w[n + c] = width;
      h[n + c] = cy + shelf;
    }
  }

  for (var c = gCount - 1; c >= 0; c--) {
    layout(c);
  }
  layout(root);

  final groupCol = Int32List(gCount);
  final groupRow = Int32List(gCount);
  final groupParent = Int32List(gCount);
  final groupEmpty = Uint8List(gCount);
  for (var g = 0; g < gCount; g++) {
    final p = parent[n + g];
    groupParent[g] = p == root ? -1 : p;
    groupCol[g] = x[n + g] + (p == root ? 0 : groupCol[p]);
    groupRow[g] = y[n + g] + (p == root ? 0 : groupRow[p]);
    if (kids[g].isEmpty) groupEmpty[g] = 1;
  }
  final col = Int32List(n);
  final row = Int32List(n);
  final nodeParent = Int32List(n);
  for (var i = 0; i < n; i++) {
    final p = parent[i];
    nodeParent[i] = p == root ? -1 : p;
    col[i] = x[i] + (p == root ? 0 : groupCol[p]);
    row[i] = y[i] + (p == root ? 0 : groupRow[p]);
  }
  return Grid(
    col: col,
    row: row,
    groupCol: groupCol,
    groupRow: groupRow,
    groupCols: Int32List.fromList(w.sublist(n)),
    groupRows: Int32List.fromList(h.sublist(n)),
    groupParent: groupParent,
    groupEmpty: groupEmpty,
    nodeParent: nodeParent,
  );
}

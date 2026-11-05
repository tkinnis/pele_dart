// Upstream: src/diagrams/class/markers.ts

import '../../svg/builder.dart';
import '../../svg/edges.dart';
import 'graph.dart';

const double _TRIANGLE = 12;
const double _DIAMOND = 16;
const double _HALF = 6;
const int _RING = 5;

// How far the line stops short of the node so that it meets the back of the marker.
double classMarkerTrim(EndMarker type) {
  switch (type) {
    case 'extension':
      return _TRIANGLE;
    case 'composition':
    case 'aggregation':
      return _DIAMOND;
    case 'lollipop':
      return 2.0 * _RING;
    case 'dependency':
      return markerTrim('arrow_point');
  }
  return 0;
}

// Draws an end marker whose tip is at (x, y), pointing along (dx, dy).
String classMarker(
  EndMarker type,
  double x,
  double y,
  double dx,
  double dy,
  String color,
) {
  final nx = -dy;
  final ny = dx;
  switch (type) {
    case 'extension':
      final bx = x - dx * _TRIANGLE;
      final by = y - dy * _TRIANGLE;
      return '<path class="pele-marker" d="M${num(x)},${num(y)}L${num(bx + nx * _HALF)},${num(by + ny * _HALF)}L${num(bx - nx * _HALF)},${num(by - ny * _HALF)}Z" stroke-linejoin="round"/>';
    case 'composition':
    case 'aggregation':
      final mx = x - (dx * _DIAMOND) / 2;
      final my = y - (dy * _DIAMOND) / 2;
      const half = _HALF - 1;
      return '<path class="pele-marker" d="M${num(x)},${num(y)}L${num(mx + nx * half)},${num(my + ny * half)}L${num(x - dx * _DIAMOND)},${num(y - dy * _DIAMOND)}L${num(mx - nx * half)},${num(my - ny * half)}Z" stroke-linejoin="round"${type == 'composition' ? ' fill="$color"' : ''}/>';
    case 'lollipop':
      return '<circle class="pele-marker" cx="${num(x - dx * _RING)}" cy="${num(y - dy * _RING)}" r="$_RING"/>';
    case 'dependency':
      return marker('arrow_point', x, y, dx, dy, color);
  }
  return '';
}

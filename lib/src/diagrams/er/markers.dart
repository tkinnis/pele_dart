// Upstream: src/diagrams/er/markers.ts

import '../../svg/builder.dart';

/// How far a marker reaches back along its line from the box it touches.
const double MARKER_LENGTH = 18;

const double _bar = 5;
const double _foot = 6;
const double _footLength = 10;
const double _ring = 3.5;

/// Draws a crow's foot cardinality marker over the end of a line that meets a box at (x, y)
/// while travelling along the unit vector (dx, dy). Types are Mermaid's lower-cased cardinalities.
String erMarker(String type, double x, double y, double dx, double dy) {
  String at(double back, double side) =>
      '${num(x - dx * back - dy * side)},${num(y - dy * back + dx * side)}';
  String bar(double back) => 'M${at(back, -_bar)}L${at(back, _bar)}';
  final foot = 'M${at(0, -_foot)}L${at(_footLength, 0)}L${at(0, _foot)}';
  String ring(double back) =>
      '<circle class="pele-marker" cx="${num(x - dx * back)}" cy="${num(y - dy * back)}" r="$_ring" fill="var(--_bg)"/>';
  String path(String d) => '<path class="pele-marker" d="$d"/>';

  switch (type) {
    case 'only_one':
      return path(bar(6) + bar(10));
    case 'zero_or_one':
      return path(bar(6)) + ring(13.5);
    case 'one_or_more':
      return path(foot + bar(_footLength + 3.5));
    case 'zero_or_more':
      return path(foot) + ring(_footLength + _ring + 0.5);
    case 'md_parent':
      return '<path class="pele-marker" d="M${at(0, 0)}L${at(6, 4)}L${at(12, 0)}L${at(6, -4)}Z" fill="var(--_bg)"/>';
  }
  return '';
}

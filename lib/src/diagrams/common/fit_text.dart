// Upstream: src/diagrams/common/fit-text.ts

import 'dart:math' as math;

import '../../text/measurer.dart';
import '../../util/math_js.dart';

class Fitted {
  final String text;
  final double size;
  final double width;

  const Fitted({required this.text, required this.size, required this.width});
}

Fitted? fitText(
  String text,
  double max,
  double size,
  double min,
  TextMeasurer measurer, [
  int style = 0,
]) {
  if (text.isEmpty || max <= 0) return null;
  var width = measurer.width(text, size, style);
  if (width <= max) return Fitted(text: text, size: size, width: width);

  var fitted = math.max(min, ((size * max) / width).floorToDouble());
  while (fitted >= min) {
    width = measurer.width(text, fitted, style);
    if (width <= max) return Fitted(text: text, size: fitted, width: width);
    fitted--;
  }

  final chars = codePointsOf(text);
  var low = 0;
  var high = chars.length - 1;
  while (low < high) {
    final mid = (low + high + 1) >> 1;
    final candidate = '${chars.sublist(0, mid).join().trimRight()}…';
    if (measurer.width(candidate, min, style) <= max) {
      low = mid;
    } else {
      high = mid - 1;
    }
  }
  if (low == 0) return null;
  final cut = '${chars.sublist(0, low).join().trimRight()}…';
  width = measurer.width(cut, min, style);
  return width <= max ? Fitted(text: cut, size: min, width: width) : null;
}

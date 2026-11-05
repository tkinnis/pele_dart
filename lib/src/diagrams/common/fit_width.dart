// Upstream: src/diagrams/common/fit-width.ts

import 'dart:math' as math;

import '../../types.dart';

Rendered fitWidth(
  RenderOptions options,
  double natural,
  double least,
  Rendered Function(double plot, bool narrow) draw,
) {
  var result = draw(natural, false);
  final available = options.maxWidth;
  if (available == null || !(available > 0) || result.width <= available) {
    return result;
  }
  final floor = math.min(least, natural);
  var plot = natural;
  result = draw(plot, true);
  for (
    var round = 0;
    round < 3 && result.width > available && plot > floor;
    round++
  ) {
    plot = math.max(floor, plot - (result.width - available));
    result = draw(plot, true);
  }
  return result;
}

double titleRoom(RenderOptions options) {
  final available = options.maxWidth;
  return available != null && available > 0
      ? math.max(80.0, available - 2 * (options.padding ?? 8))
      : 4000.0;
}

double capWidth(
  RenderOptions options,
  double natural,
  double least, [
  double around = 0,
]) {
  final available = options.maxWidth;
  if (available == null || !(available > 0)) return natural;
  return math.max(
    math.min(least, natural),
    math.min(natural, available - around),
  );
}

const double _breakpoint = 640;

Rendered turnToFit(RenderOptions options, Rendered Function(bool down) draw) {
  final across = draw(false);
  final available = options.maxWidth;
  if (options.autoDirection == false ||
      available == null ||
      !(available > 0) ||
      across.width <= available) {
    return across;
  }
  final breakpoint = options.directionBreakpoint;
  if (available >=
      (breakpoint != null && breakpoint > 0 ? breakpoint : _breakpoint)) {
    return across;
  }
  final down = draw(true);
  return down.width < across.width ? down : across;
}

bool runsAcross(String? direction) {
  return direction == 'LR' || direction == 'RL';
}

Rendered tighten(RenderOptions options, Rendered Function(bool tight) draw) {
  final loose = draw(false);
  final available = options.maxWidth;
  if (available == null || !(available > 0) || loose.width <= available) {
    return loose;
  }
  final tight = draw(true);
  return tight.width < loose.width ? tight : loose;
}

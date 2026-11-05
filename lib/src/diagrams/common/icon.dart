// Upstream: src/diagrams/common/icon.ts

import '../../svg/builder.dart';

/// A square for a named icon, in the form labels use. The host's resolver supplies the drawing, if any.
String iconSvg(
  String name,
  double x,
  double y,
  double side, [
  IconResolver? icons,
]) {
  return '<svg class="pele-icon" data-icon="${escText(name)}" x="${num(x)}" y="${num(y)}" width="${num(side)}" height="${num(side)}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${icons?.call(name) ?? ''}</svg>';
}

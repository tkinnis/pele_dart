// Upstream: src/svg/title.ts

import 'dart:math' as math;

import '../text/label.dart';
import '../text/math.dart';
import '../text/measurer.dart';
import 'builder.dart';

Label titleLabel(
  String? title,
  TextMeasurer measurer,
  double size,
  double maxWidth,
) {
  return withoutMath(
    () => layoutLabel(title, false, measurer, size, maxWidth, Style.bold),
  );
}

class Titled {
  const Titled({
    required this.width,
    required this.height,
    required this.content,
  });

  final double width;
  final double height;
  final String content;
}

Titled withTitle(
  String? title,
  TextMeasurer measurer,
  double size,
  double pad,
  double width,
  double height,
  String content,
) {
  final label = titleLabel(title, measurer, size, 4000);
  if (label.height == 0) {
    return Titled(width: width, height: height, content: content);
  }
  final shift = label.height + 12;
  final full = math.max(width, (label.width + 2 * pad).ceilToDouble());
  return Titled(
    width: full,
    height: (height + shift).ceilToDouble(),
    content:
        labelSvg(
          label,
          full / 2,
          pad + label.height / 2,
          ' class="pele-title" font-weight="var(--_tw)"',
        ) +
        '<g transform="translate(${num((full - width) / 2)},${num(shift)})">$content</g>',
  );
}

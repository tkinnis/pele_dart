// Upstream: src/text/measurer.ts

import 'dart:typed_data';

import 'metrics.dart';

abstract final class Style {
  static const int bold = 1;
  static const int italic = 2;
  static const int mono = 4;
  static const int sub = 8;
  static const int sup = 16;
  static const int underline = 32;

  // Uppercase aliases matching TypeScript enum names.
  static const int Bold = 1;
  static const int Italic = 2;
  static const int Mono = 4;
  static const int Sub = 8;
  static const int Sup = 16;
  static const int Underline = 32;
}

/// Approximate divisor for CSS font-size="smaller".
const double _smaller = 1.2;

abstract interface class TextMeasurer {
  double width(String text, double size, [int style = 0]);
}

Uint16List _unpack(String packed) {
  final out = Uint16List(95);
  for (var i = 0; i < 95; i++) {
    out[i] = int.parse(packed.substring(i * 2, i * 2 + 2), radix: 36);
  }
  return out;
}

Uint16List? _regular;
Uint16List? _bold;

bool _isWide(int c) {
  return (c >= 0x1100 && c <= 0x115f) ||
      (c >= 0x2e80 && c <= 0xa4cf) ||
      (c >= 0xac00 && c <= 0xd7a3) ||
      (c >= 0xf900 && c <= 0xfaff) ||
      (c >= 0xfe30 && c <= 0xfe4f) ||
      (c >= 0xff00 && c <= 0xff60) ||
      (c >= 0xffe0 && c <= 0xffe6) ||
      (c >= 0xd800 && c <= 0xdbff);
}

bool _isZeroWidth(int c) {
  return c == 0xad ||
      (c >= 0x300 && c <= 0x36f) ||
      (c >= 0x200b && c <= 0x200f) ||
      (c >= 0xdc00 && c <= 0xdfff) ||
      (c >= 0xfe00 && c <= 0xfe0f) ||
      c == 0xfeff;
}

class _MetricsMeasurer implements TextMeasurer {
  const _MetricsMeasurer();

  @override
  double width(String text, double size, [int style = 0]) {
    final mono = (style & Style.mono) != 0;
    final eff = (style & (Style.sub | Style.sup)) != 0 ? size / _smaller : size;
    final table = (style & Style.bold) != 0
        ? (_bold ??= _unpack(boldMetrics))
        : (_regular ??= _unpack(regularMetrics));
    var units = 0;
    for (var i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      if (c < 32) continue;
      if (c < 127) {
        units += mono ? 600 : table[c - 32];
      } else if (_isZeroWidth(c)) {
        continue;
      } else if (_isWide(c)) {
        units += mono ? 1200 : 1000;
      } else {
        units += mono ? 600 : 580;
      }
    }
    return (units * eff) / 1000.0;
  }
}

/// Estimates widths from a table of Arial advances.
const TextMeasurer metricsMeasurer = _MetricsMeasurer();

TextMeasurer defaultMeasurer([String? fontFamily, String? monoFamily]) {
  return metricsMeasurer;
}

void forgetTextWidths() {}

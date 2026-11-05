// Upstream: src/text/measurer.ts

import 'dart:typed_data';

import 'metrics.dart';

/// Bitmask style flags passed to [TextMeasurer.width].
abstract final class Style {
  /// Bold font weight (`1`).
  static const int bold = 1;

  /// Italic font style (`2`).
  static const int italic = 2;

  /// Monospace font family (`4`).
  static const int mono = 4;

  /// Subscript text (`8`).
  static const int sub = 8;

  /// Superscript text (`16`).
  static const int sup = 16;

  /// Underlined text (`32`).
  static const int underline = 32;

  /// Uppercase alias for [bold] matching upstream TypeScript enum naming.
  static const int Bold = 1;

  /// Uppercase alias for [italic] matching upstream TypeScript enum naming.
  static const int Italic = 2;

  /// Uppercase alias for [mono] matching upstream TypeScript enum naming.
  static const int Mono = 4;

  /// Uppercase alias for [sub] matching upstream TypeScript enum naming.
  static const int Sub = 8;

  /// Uppercase alias for [sup] matching upstream TypeScript enum naming.
  static const int Sup = 16;

  /// Uppercase alias for [underline] matching upstream TypeScript enum naming.
  static const int Underline = 32;
}

/// Approximate divisor for CSS font-size="smaller".
const double _smaller = 1.2;

/// Interface for measuring single-line text advance widths during diagram layout.
abstract interface class TextMeasurer {
  /// Returns the estimated width in pixels of [text] rendered at [size] (in px)
  /// with optional [Style] bitmask flags ([Style.bold], [Style.italic],
  /// [Style.mono], [Style.sub], [Style.sup], [Style.underline]).
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

/// Default pure-Dart [TextMeasurer] that estimates advance widths from bundled
/// character width tables without requiring a DOM or platform font engine.
const TextMeasurer metricsMeasurer = _MetricsMeasurer();

/// Returns the default [TextMeasurer] ([metricsMeasurer]).
TextMeasurer defaultMeasurer([String? fontFamily, String? monoFamily]) {
  return metricsMeasurer;
}

/// Clears any cached text width measurements (no-op for the stateless
/// pure-Dart [metricsMeasurer]; provided for 1:1 upstream API parity).
void forgetTextWidths() {}

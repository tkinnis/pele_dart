// Upstream: src/diagrams/common/literal-label.ts

import 'dart:math' as math;

import '../../svg/builder.dart';
import '../../text/label.dart';
import '../../text/measurer.dart';
import '../../util/math_js.dart';

final RegExp _spaceRe = RegExp(r'\s');

Label literalLabel(
  String text,
  TextMeasurer measurer,
  double size,
  double room, [
  int style = 0,
]) {
  final lines = <String>[];
  for (final raw in text.split('\n')) {
    final chars = codePointsOf(raw);
    if (chars.isEmpty) lines.add('');
    var from = 0;
    while (from < chars.length) {
      bool fits(int length) =>
          measurer.width(
            chars.sublist(from, from + length).join(),
            size,
            style,
          ) <=
          room;
      var hi = 1;
      while (hi < chars.length - from && fits(hi)) {
        hi = math.min(chars.length - from, hi * 2);
      }
      var lo = 1;
      while (lo < hi) {
        final mid = ((lo + hi) / 2).ceil();
        if (fits(mid)) {
          lo = mid;
        } else {
          hi = mid - 1;
        }
      }
      var take = lo;
      final wraps = from + take < chars.length;
      if (wraps && !_spaceRe.hasMatch(chars[from + take])) {
        for (var i = take - 1; i > 0; i--) {
          if (_spaceRe.hasMatch(chars[from + i])) {
            take = i + 1;
            break;
          }
        }
      }
      final line = chars.sublist(from, from + take).join();
      final trimmed = line.trimRight();
      lines.add(wraps ? (trimmed.isNotEmpty ? trimmed : line) : line);
      from += take;
      while (wraps && from < chars.length && _spaceRe.hasMatch(chars[from])) {
        from++;
      }
    }
  }
  if (text.isEmpty) lines.clear();
  final widths = lines
      .map((line) => measurer.width(line, size, style))
      .toList();
  var width = 0.0;
  for (final w in widths) {
    width = math.max(width, w);
  }
  final lineHeight = roundJs(size * 1.5).toDouble();
  return Label(
    lines: List<List<Span>>.generate(
      lines.length,
      (i) => <Span>[Span(text: lines[i], style: style, width: widths[i])],
    ),
    widths: widths,
    width: width,
    height: lines.length * lineHeight,
    size: size,
    lineHeight: lineHeight,
  );
}

Label breakLabel(Label label, TextMeasurer measurer, double room) {
  if (label.width <= room) return label;
  final lines = <List<Span>>[];
  final widths = <double>[];
  for (var i = 0; i < label.lines.length; i++) {
    if (label.widths[i] <= room) {
      lines.add(label.lines[i]);
      widths.add(label.widths[i]);
      continue;
    }
    var current = <Span>[];
    var width = 0.0;
    void commit() {
      lines.add(current);
      widths.add(width);
      current = <Span>[];
      width = 0.0;
    }

    for (final span in label.lines[i]) {
      if (span.icon != null || span.math != null) {
        if (current.isNotEmpty && width + span.width > room) commit();
        current.add(span);
        width += span.width;
        continue;
      }
      for (final char in codePointsOf(span.text)) {
        Span? last = current.isNotEmpty ? current.last : null;
        final joined =
            last != null &&
            last.icon == null &&
            last.math == null &&
            last.style == span.style;
        final nextWidth = measurer.width(
          joined ? '${last.text}$char' : char,
          label.size,
          span.style,
        );
        var added = nextWidth - (joined ? last.width : 0.0);
        if (current.isNotEmpty && width + added > room) {
          commit();
          last = null;
          added = measurer.width(char, label.size, span.style);
        }
        if (last != null &&
            last.icon == null &&
            last.math == null &&
            last.style == span.style) {
          last.text += char;
          last.width += added;
        } else {
          current.add(Span(text: char, style: span.style, width: added));
        }
        width += added;
      }
    }
    if (current.isNotEmpty || label.lines[i].isEmpty) commit();
  }
  var width = 0.0;
  for (final w in widths) {
    width = math.max(width, w);
  }
  final broken = Label(
    lines: lines,
    widths: widths,
    width: width,
    height: lines.length * label.lineHeight,
    size: label.size,
    lineHeight: label.lineHeight,
    heights: label.heights,
  );
  return label.heights != null ? withHeights(broken) : broken;
}

String leftLabelSvg(Label label, double x, double top, String attrs) {
  final shared = sharedStyle(label);
  final open = '<text${textStyle(attrs, shared)}';
  final body = StringBuffer();
  for (var i = 0; i < label.lines.length; i++) {
    final spans = label.lines[i];
    final cy = top + (i + 0.5) * label.lineHeight;
    if (spans.any((span) => span.icon != null)) {
      final width = label.widths[i];
      body.write(
        labelSvg(
          Label(
            lines: <List<Span>>[spans],
            widths: <double>[width],
            width: width,
            height: label.lineHeight,
            size: label.size,
            lineHeight: label.lineHeight,
          ),
          x + width / 2,
          cy,
          attrs,
        ),
      );
      continue;
    }
    final text = StringBuffer();
    for (final span in spans) {
      final own = spanStyle(span.style & ~shared);
      if (own.isNotEmpty) {
        text.write('<tspan$own>${esc(span.text)}</tspan>');
      } else {
        text.write(esc(span.text));
      }
    }
    if (text.isNotEmpty) {
      body.write(
        '$open x="${num(x)}" y="${num(cy + label.size * 0.35)}" text-anchor="start" xml:space="preserve">$text</text>',
      );
    }
  }
  return body.toString();
}

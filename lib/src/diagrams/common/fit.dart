// Upstream: src/diagrams/common/fit.ts

import '../../text/label.dart';
import '../../text/measurer.dart';

final RegExp _reTagStart = RegExp(r'<(?!br\s*\/?>)', caseSensitive: false);
final RegExp _reIcon = RegExp(r':fa-');
final RegExp _reUnit = RegExp(
  r'<br\s*\/?>|ﬂ°°?\w+¶ß|&#?\w+;|[\ud800-\udbff][\udc00-\udfff]|[\s\S]',
  caseSensitive: false,
);

Label plainLabel(
  String? raw,
  TextMeasurer measurer,
  double size,
  double max, [
  int base = 0,
]) {
  var text = raw;
  if (text != null) {
    if (text.contains('<')) text = text.replaceAll(_reTagStart, '&lt;');
    if (text.contains(':fa-')) text = text.replaceAll(_reIcon, '&colon;fa-');
  }
  return layoutLabel(text, false, measurer, size, max, base);
}

Label fitLabel(
  String? raw,
  TextMeasurer measurer,
  double size,
  double max, [
  int base = 0,
]) {
  final label = plainLabel(raw, measurer, size, max, base);
  if (raw == null || label.width <= max) return label;
  final out = StringBuffer();
  var width = 0.0;
  for (final m in _reUnit.allMatches(raw)) {
    final unit = m.group(0)!;
    if (unit.trim().isEmpty || (unit.length > 2 && unit.startsWith('<'))) {
      width = 0;
    } else {
      final w = measurer.width(unit.length > 2 ? 'x' : unit, size, base);
      if (width > 0 && width + w > max) {
        out.write('\n');
        width = 0;
      }
      width += w;
    }
    out.write(unit);
  }
  return plainLabel(out.toString(), measurer, size, max, base);
}

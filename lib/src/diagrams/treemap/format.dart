// Upstream: src/diagrams/treemap/format.ts

import 'dart:math' as math;

import '../../util/math_js.dart';

// The parts of d3-format's specifier that treemap values use: an optional `$`, `,` for thousands
// separators, a precision, and a type of `f`, `%`, `d`, `e` or none. Fill, alignment and width are
// read and ignored. Anything else falls back to the default, `,`.
final RegExp _reSpec = RegExp(
  r'^(?:.?[<>=^])?([-+( ])?(\$)?0?\d*(,)?(?:\.(\d+))?(~)?([a-zA-Z%])?$',
);
final RegExp _reTrailZeros = RegExp(r'\.?0+$');

String _group(String digits) {
  var out = '';
  for (var i = digits.length; i > 0; i -= 3) {
    final part = digits.substring(math.max(0, i - 3), i);
    out = out.isEmpty ? part : '$part,$out';
  }
  return out;
}

String _jsNumberString(double v) {
  if (v == 0) return '0';
  final s = v.toString();
  if (!s.contains('e') && v == v.truncateToDouble() && v.abs() < 1e21) {
    return v.toInt().toString();
  }
  return s;
}

String Function(double value) formatter(String spec) {
  // Mermaid documents `$0,0` for a dollar amount with thousands separators.
  final m =
      _reSpec.firstMatch(spec == r'$0,0' ? r'$,' : spec) ??
      _reSpec.firstMatch(',')!;
  final plus = m.group(1) == '+';
  final dollar = m.group(2) ?? '';
  final comma = m.group(3) != null;
  final precision = m.group(4) == null
      ? null
      : math.min(int.parse(m.group(4)!), 20);
  final trimZeros = m.group(5) != null;
  final type = m.group(6) ?? '';

  return (double value) {
    final abs = value.abs();
    String body;
    var suffix = '';
    if (type == 'f') {
      body = abs.toStringAsFixed(precision ?? 6);
    } else if (type == '%') {
      body = (abs * 100).toStringAsFixed(precision ?? 6);
      suffix = '%';
    } else if (type == 'd') {
      body = roundJs(abs).toString();
    } else if (type == 'e') {
      body = abs.toStringAsExponential(precision ?? 6);
    } else {
      final p = math.max(1, precision ?? 12);
      body = _jsNumberString(double.parse(abs.toStringAsPrecision(p)));
    }

    if (trimZeros && body.contains('.') && !body.contains('e')) {
      body = body.replaceFirst(_reTrailZeros, '');
    }
    if (comma && !body.contains('e')) {
      final dot = body.indexOf('.');
      body = dot == -1
          ? _group(body)
          : '${_group(body.substring(0, dot))}${body.substring(dot)}';
    }
    final sign = value < 0 ? '-' : (plus ? '+' : '');
    return '$sign$dollar$body$suffix';
  };
}

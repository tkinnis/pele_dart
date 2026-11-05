// Upstream: src/svg/ink.ts

import 'dart:math' as math;

final Set<String> _dark =
    ('black blue blueviolet brown crimson darkblue darkcyan darkgreen darkmagenta darkolivegreen darkorchid darkred darkslateblue darkslategray darkviolet dimgray firebrick forestgreen green indigo maroon mediumblue mediumslateblue mediumvioletred midnightblue navy olive purple rebeccapurple royalblue saddlebrown seagreen sienna slateblue steelblue teal')
        .split(' ')
        .toSet();

final Set<String> _light =
    ('aliceblue antiquewhite aqua aquamarine azure beige bisque blanchedalmond burlywood cadetblue chartreuse chocolate coral cornflowerblue cornsilk cyan darkgoldenrod darkgray darkkhaki darkorange darksalmon darkseagreen darkturquoise deeppink deepskyblue dodgerblue floralwhite fuchsia gainsboro ghostwhite gold goldenrod gray greenyellow honeydew hotpink indianred ivory khaki lavender lavenderblush lawngreen lemonchiffon lightblue lightcoral lightcyan lightgoldenrodyellow lightgray lightgreen lightpink lightsalmon lightseagreen lightskyblue lightslategray lightsteelblue lightyellow lime limegreen linen magenta mediumaquamarine mediumorchid mediumpurple mediumseagreen mediumspringgreen mediumturquoise mintcream mistyrose moccasin navajowhite oldlace olivedrab orange orangered orchid palegoldenrod palegreen paleturquoise palevioletred papayawhip peachpuff peru pink plum powderblue red rosybrown salmon sandybrown seashell silver skyblue slategray snow springgreen tan thistle tomato turquoise violet wheat white whitesmoke yellow yellowgreen')
        .split(' ')
        .toSet();

const String onLight = 'var(--pele-fg-on-light,#1f1f1f)';
const String onDark = 'var(--pele-fg-on-dark,#fff)';

final RegExp _reFill = RegExp(r'[";]fill:([^;"]*)');
final RegExp _reOpacities = RegExp(r'[";](?:fill-)?opacity:([^;"]*)');
final RegExp _reHex = RegExp(
  r'^#(?:[\da-f]{3,4}|[\da-f]{6}|[\da-f]{8})$',
  caseSensitive: false,
);
final RegExp _reFunction = RegExp(
  r'^(rgba?|hsla?)\(([^()]*)\)$',
  caseSensitive: false,
);
final RegExp _reNumber = RegExp(
  r'^[+-]?(?:\d+(?:\.\d+)?|\.\d+)(?:e[+-]?\d+)?(%|deg|grad|rad|turn)?$',
  caseSensitive: false,
);

double _linear(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(double r, double g, double b) =>
    0.2126 * _linear(r) + 0.7152 * _linear(g) + 0.0722 * _linear(b);

double _clamp(double n) => math.min(math.max(n, 0.0), 1.0);

final double _even =
    math.sqrt(1.05 * (_luminance(31 / 255, 31 / 255, 31 / 255) + 0.05)) - 0.05;

final RegExp _reLeadingFloat = RegExp(
  r'^[+-]?(?:\d+(?:\.\d+)?|\.\d+)(?:e[+-]?\d+)?',
  caseSensitive: false,
);

double _parseFloat(String raw) {
  final m = _reLeadingFloat.firstMatch(raw.trim());
  if (m == null) return double.nan;
  return double.tryParse(m.group(0)!) ?? double.nan;
}

double _amount(String raw, double full) {
  final m = _reNumber.firstMatch(raw);
  if (m == null || (m.group(1) != null && m.group(1) != '%')) {
    return double.nan;
  }
  return _clamp(_parseFloat(raw) / (m.group(1) != null ? 100.0 : full));
}

double _hue(String raw) {
  final m = _reNumber.firstMatch(raw);
  if (m == null || m.group(1) == '%') return double.nan;
  final unit = m.group(1)?.toLowerCase();
  final n = _parseFloat(raw);
  return unit == 'turn'
      ? n * 360
      : (unit == 'rad' ? (n * 180) / math.pi : (unit == 'grad' ? n * 0.9 : n));
}

List<String>? _args(String body, bool hsl) {
  final legacy = body.contains(',');
  final parts = legacy ? [body] : body.split('/');
  if (parts.length > 2) return null;
  final main = parts[0];
  final alpha = parts.length == 2 ? parts[1] : null;
  final list = main
      .trim()
      .split(legacy ? RegExp(r'\s*,\s*') : RegExp(r'\s+'))
      .where((s) => s.isNotEmpty)
      .toList();
  if (legacy ? (list.length < 3 || list.length > 4) : list.length != 3) {
    return null;
  }
  if (alpha != null) list.add(alpha.trim());
  if (!legacy) {
    return list.map((c) => c == 'none' ? '0' : c).toList();
  }
  final percent = list
      .sublist(hsl ? 1 : 0, 3)
      .where((c) => c.endsWith('%'))
      .length;
  return percent == (hsl ? 2 : 3) || (!hsl && percent == 0) ? list : null;
}

bool plainColor(String raw) {
  final value = raw.trim().toLowerCase();
  final name = value.replaceAll('grey', 'gray');
  return _reHex.hasMatch(value) ||
      _dark.contains(name) ||
      _light.contains(name) ||
      value == 'transparent' ||
      value == 'currentcolor';
}

(double, double)? _color(String raw) {
  final value = raw.trim().toLowerCase();
  final name = value.replaceAll('grey', 'gray');
  if (_dark.contains(name)) return (0.0, 1.0);
  if (_light.contains(name)) return (1.0, 1.0);
  if (_reHex.hasMatch(value)) {
    final digits = value.length < 6
        ? value.substring(1).split('').map((c) => '$c$c').join()
        : value.substring(1);
    double n(int i) =>
        int.parse(digits.substring(2 * i, 2 * i + 2), radix: 16) / 255.0;
    return (_luminance(n(0), n(1), n(2)), digits.length == 8 ? n(3) : 1.0);
  }
  final fn = _reFunction.firstMatch(value);
  if (fn == null) return null;
  final hsl = fn.group(1)!.toLowerCase().startsWith('hsl');
  final list = _args(fn.group(2)!, hsl);
  if (list == null) return null;
  final alpha = list.length == 4 ? _amount(list[3], 1.0) : 1.0;
  List<double> rgb;
  if (!hsl) {
    rgb = list.sublist(0, 3).map((c) => _amount(c, 255.0)).toList();
  } else {
    final h = (((_hue(list[0]) % 360) + 360) % 360) / 30.0;
    final s = _amount(list[1], 100.0);
    final l = _amount(list[2], 100.0);
    final a = s * math.min(l, 1.0 - l);
    rgb = [0, 8, 4].map((k) {
      final t = (k + h) % 12;
      return l - a * math.max(-1.0, math.min(math.min(t - 3, 9 - t), 1.0));
    }).toList();
  }
  final lum = _luminance(rgb[0], rgb[1], rgb[2]);
  return (lum + alpha).isNaN ? null : (lum, alpha);
}

double _opacity(String shape) {
  var product = 1.0;
  for (final m in _reOpacities.allMatches(shape)) {
    product *= _amount(m.group(1)!.trim(), 1.0);
  }
  return product;
}

final Map<String, String?> _known = <String, String?>{};

String? ink(String shape, [String text = '']) {
  final key = '$shape\u0000$text';
  if (_known.containsKey(key)) return _known[key];
  if (_known.length > 1000) _known.clear();
  final result = _pick(shape, text);
  _known[key] = result;
  return result;
}

String? _pick(String shape, String text) {
  final fill = _reFill.firstMatch(shape);
  final found = fill != null && !_reFill.hasMatch(text)
      ? _color(fill.group(1)!)
      : null;
  if (found == null) return null;
  if (!(found.$2 * _opacity(shape) >= 0.5)) return null;
  return found.$1 > _even ? onLight : onDark;
}

bool paints(String shape) {
  final fill = _reFill.firstMatch(shape)?.group(1)?.trim().toLowerCase();
  if (fill == null || fill.isEmpty || fill == 'none' || fill == 'transparent') {
    return false;
  }
  final scale = _opacity(shape);
  return (_color(fill)?.$2 ?? 1.0) * (scale.isNaN ? 1.0 : scale) > 0;
}

String inkFill(({String shape, String text}) style, [String? fallback]) {
  final color = ink(style.shape, style.text) ?? fallback;
  return color != null && color.isNotEmpty ? ' fill="$color"' : '';
}

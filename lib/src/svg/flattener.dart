import 'dart:math' as math;

import '../types.dart';
import 'builder.dart';

/// Resolves all CSS variables (`var(--_*)`, `var(--pele-*)`), `color-mix(in srgb, ...)`,
/// `calc(...)`, inline `style="..."` presentation/geometry properties (`rx`, `ry`, `fill`,
/// `stroke`, `stroke-width`, etc.), `currentColor`, and `baseline-shift` into pure static
/// SVG 1.1 attributes compatible with `vector_graphics_compiler` and non-CSS SVG renderers.
String flattenPeleSvg(String svg, {PelePalette palette = PelePalette.light}) {
  final vars = _buildVarMap(palette);

  // 1. Resolve all var(...) and color-mix(...) and calc(...) expressions globally first.
  var out = _resolveExpressions(svg, vars);

  // 2. Replace currentColor with palette.fg.
  out = out.replaceAll('currentColor', palette.fg);

  // 3. Replace baseline-shift="sub|super" font-size="smaller" on <tspan>.
  out = out.replaceAll(
    'baseline-shift="sub" font-size="smaller"',
    'dy="3" font-size="10"',
  );
  out = out.replaceAll(
    'baseline-shift="super" font-size="smaller"',
    'dy="-4" font-size="10"',
  );

  // 4. Promote inline style="..." properties on SVG elements to native SVG 1.1 attributes.
  out = _flattenInlineStyles(out, palette);

  return out;
}

Map<String, String> _buildVarMap(PelePalette p) {
  final fgRgb = _parseColor(p.fg) ?? const <double>[36, 41, 46];
  final bgRgb = _parseColor(p.bg) ?? const <double>[255, 255, 255];

  String mixFgBg(double fgPercent) =>
      _formatRgb(_mixRgb(fgRgb, bgRgb, fgPercent / 100.0));

  final muted = p.muted ?? mixFgBg(60);
  final line = p.line ?? mixFgBg(45);
  final surface = p.surface ?? mixFgBg(3);
  final accent = p.accent ?? mixFgBg(7);
  final border = p.border ?? mixFgBg(20);
  final code = p.code ?? mixFgBg(8);
  final radiusStr = '${num(p.radius)}px';
  final swStr = num(p.strokeWidth);
  final tswStr = num(p.thickStrokeWidth);
  final hswStr = num(p.hairlineStrokeWidth);

  final map = <String, String>{
    '--_bg': p.bg,
    '--_fg': p.fg,
    '--_m': muted,
    '--_l': line,
    '--_s': surface,
    '--_a': accent,
    '--_b': border,
    '--_c': code,
    '--_r': radiusStr,
    '--_w': swStr,
    '--_tw': tswStr,
    '--_hw': hswStr,
    '--_fm': p.monoFontFamily,
    '--pele-bg': p.bg,
    '--pele-fg': p.fg,
    '--pele-muted': muted,
    '--pele-line': line,
    '--pele-surface': surface,
    '--pele-accent': accent,
    '--pele-border': border,
    '--pele-code': code,
    '--pele-radius': radiusStr,
    '--pele-stroke-width': swStr,
    '--pele-thick-stroke-width': tswStr,
    '--pele-hairline-stroke-width': hswStr,
    '--pele-font': p.fontFamily,
    '--pele-font-mono': p.monoFontFamily,
  };
  for (var i = 0; i < p.colors.length; i++) {
    map['--pele-c$i'] = p.colors[i];
  }
  return map;
}

String _resolveExpressions(String input, Map<String, String> vars) {
  var current = input;
  for (var pass = 0; pass < 8; pass++) {
    var changed = false;

    // Resolve innermost var(--name) or var(--name, fallback) without nested parens.
    final nextVar = current.replaceAllMapped(
      RegExp(r'var\(\s*(--[A-Za-z0-9_-]+)\s*(?:,\s*([^()]+?))?\s*\)'),
      (m) {
        changed = true;
        final name = m.group(1)!;
        final fallback = m.group(2)?.trim();
        return vars[name] ?? fallback ?? '';
      },
    );
    current = nextVar;

    // Resolve innermost color-mix(in srgb, ...) without nested parens.
    final nextMix = current.replaceAllMapped(
      RegExp(r'color-mix\(\s*in\s+srgb\s*,([^()]+)\)'),
      (m) {
        final evaluated = _evalColorMixBody(m.group(1)!);
        if (evaluated != null) {
          changed = true;
          return evaluated;
        }
        return m.group(0)!;
      },
    );
    current = nextMix;

    // Resolve simple calc(A + B) expressions.
    final nextCalc = current.replaceAllMapped(
      RegExp(
        r'calc\(\s*([+-]?\d+(?:\.\d+)?)(?:px)?\s*\+\s*([+-]?\d+(?:\.\d+)?)(?:px)?\s*\)',
      ),
      (m) {
        changed = true;
        final a = double.parse(m.group(1)!);
        final b = double.parse(m.group(2)!);
        return num(a + b);
      },
    );
    current = nextCalc;

    if (!changed) break;
  }
  return current;
}

final RegExp _partPercentRe = RegExp(r'^(.*?)\s+(\d+(?:\.\d+)?)%\s*$');

String? _evalColorMixBody(String body) {
  final parts = _splitTopLevelComma(body);
  if (parts.length != 2) return null;

  var c1Str = parts[0].trim();
  var c2Str = parts[1].trim();
  double? p1;
  double? p2;

  final m1 = _partPercentRe.firstMatch(c1Str);
  if (m1 != null) {
    c1Str = m1.group(1)!.trim();
    p1 = double.tryParse(m1.group(2)!);
  }
  final m2 = _partPercentRe.firstMatch(c2Str);
  if (m2 != null) {
    c2Str = m2.group(1)!.trim();
    p2 = double.tryParse(m2.group(2)!);
  }

  final rgb1 = _parseColor(c1Str);
  final rgb2 = _parseColor(c2Str);
  if (rgb1 == null || rgb2 == null) return null;

  double w1;
  if (p1 != null && p2 != null) {
    final sum = p1 + p2;
    w1 = sum > 0 ? p1 / sum : 0.5;
  } else if (p1 != null) {
    w1 = (p1 / 100.0).clamp(0.0, 1.0);
  } else if (p2 != null) {
    w1 = (1.0 - p2 / 100.0).clamp(0.0, 1.0);
  } else {
    w1 = 0.5;
  }

  return _formatRgb(_mixRgb(rgb1, rgb2, w1));
}

List<String> _splitTopLevelComma(String s) {
  final out = <String>[];
  var depth = 0;
  var start = 0;
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (c == 40) {
      depth++;
    } else if (c == 41) {
      depth--;
    } else if (c == 44 && depth == 0) {
      out.add(s.substring(start, i));
      start = i + 1;
    }
  }
  out.add(s.substring(start));
  return out;
}

List<double> _mixRgb(List<double> a, List<double> b, double w1) {
  final w2 = 1.0 - w1;
  return <double>[
    a[0] * w1 + b[0] * w2,
    a[1] * w1 + b[1] * w2,
    a[2] * w1 + b[2] * w2,
  ];
}

String _formatRgb(List<double> rgb) {
  int clampByte(double v) => math.max(0, math.min(255, (v + 0.5).floor()));
  final r = clampByte(rgb[0]).toRadixString(16).padLeft(2, '0');
  final g = clampByte(rgb[1]).toRadixString(16).padLeft(2, '0');
  final b = clampByte(rgb[2]).toRadixString(16).padLeft(2, '0');
  return '#$r$g$b';
}

const Map<String, List<double>> _namedRgb = <String, List<double>>{
  'black': <double>[0, 0, 0],
  'white': <double>[255, 255, 255],
  'red': <double>[255, 0, 0],
  'green': <double>[0, 128, 0],
  'blue': <double>[0, 0, 255],
  'yellow': <double>[255, 255, 0],
  'cyan': <double>[0, 255, 255],
  'magenta': <double>[255, 0, 255],
  'gray': <double>[128, 128, 128],
  'grey': <double>[128, 128, 128],
  'orange': <double>[255, 165, 0],
  'purple': <double>[128, 0, 128],
  'pink': <double>[255, 192, 203],
  'brown': <double>[165, 42, 42],
};

List<double>? _parseColor(String raw) {
  final s = raw.trim().toLowerCase();
  if (_namedRgb.containsKey(s)) return _namedRgb[s];
  if (s.startsWith('#')) {
    final hex = s.substring(1);
    if (hex.length == 3 || hex.length == 4) {
      final r = int.tryParse('${hex[0]}${hex[0]}', radix: 16);
      final g = int.tryParse('${hex[1]}${hex[1]}', radix: 16);
      final b = int.tryParse('${hex[2]}${hex[2]}', radix: 16);
      if (r != null && g != null && b != null) {
        return <double>[r.toDouble(), g.toDouble(), b.toDouble()];
      }
    } else if (hex.length == 6 || hex.length == 8) {
      final r = int.tryParse(hex.substring(0, 2), radix: 16);
      final g = int.tryParse(hex.substring(2, 4), radix: 16);
      final b = int.tryParse(hex.substring(4, 6), radix: 16);
      if (r != null && g != null && b != null) {
        return <double>[r.toDouble(), g.toDouble(), b.toDouble()];
      }
    }
    return null;
  }
  final rgbMatch = RegExp(r'^rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)')
      .firstMatch(s);
  if (rgbMatch != null) {
    final r = double.tryParse(rgbMatch.group(1)!);
    final g = double.tryParse(rgbMatch.group(2)!);
    final b = double.tryParse(rgbMatch.group(3)!);
    if (r != null && g != null && b != null) {
      return <double>[r, g, b];
    }
  }
  return null;
}

final RegExp _tagWithStyleRe = RegExp(
  r'<([a-zA-Z][a-zA-Z0-9]*)\b([^>]*?\bstyle="([^"]*)"[^>]*?)(\/?)>',
);

final RegExp _styleAttrReplaceRe = RegExp(r'\s*\bstyle="[^"]*"');

const Set<String> _pxStripAttrs = <String>{
  'rx',
  'ry',
  'stroke-width',
  'font-size',
};

const Set<String> _promotableProps = <String>{
  'rx',
  'ry',
  'fill',
  'fill-opacity',
  'stroke',
  'stroke-width',
  'stroke-dasharray',
  'stroke-dashoffset',
  'stroke-linecap',
  'stroke-linejoin',
  'stroke-opacity',
  'opacity',
  'font-family',
  'font-size',
  'font-weight',
  'font-style',
  'text-decoration',
};

String _flattenInlineStyles(String svg, PelePalette palette) {
  return svg.replaceAllMapped(_tagWithStyleRe, (m) {
    final tag = m.group(1)!;
    final attrsAndStyle = m.group(2)!;
    final styleContent = m.group(3)!;
    final selfClose = m.group(4)!;

    var attrsWithoutStyle = attrsAndStyle.replaceFirst(_styleAttrReplaceRe, '');

    if (tag == 'svg' && attrsWithoutStyle.contains('class="pele')) {
      // Root <svg>: replace CSS custom properties & font shorthand with static SVG attributes.
      final extra = StringBuffer();
      if (!RegExp(r'\bfont-family=').hasMatch(attrsWithoutStyle)) {
        extra.write(' font-family="${esc(palette.fontFamily)}"');
      }
      if (!RegExp(r'\bfont-size=').hasMatch(attrsWithoutStyle)) {
        extra.write(' font-size="13"');
      }
      return '<$tag$attrsWithoutStyle$extra$selfClose>';
    }

    final declarations = styleContent.split(';');
    final promoted = <String, String>{};
    final remainingStyle = <String>[];
    String? cssColor;

    for (final rawDecl in declarations) {
      final decl = rawDecl.trim();
      if (decl.isEmpty) continue;
      final colon = decl.indexOf(':');
      if (colon <= 0) continue;
      final prop = decl.substring(0, colon).trim();
      var val = decl.substring(colon + 1).trim();
      if (prop.startsWith('--')) {
        // Drop custom property definitions in flattened mode.
        continue;
      }
      if (prop == 'color') {
        cssColor = val;
        continue;
      }
      if (_promotableProps.contains(prop)) {
        if (_pxStripAttrs.contains(prop) && val.endsWith('px')) {
          final stripped = val.substring(0, val.length - 2).trim();
          if (double.tryParse(stripped) != null) {
            val = stripped;
          }
        }
        promoted[prop] = val;
      } else {
        remainingStyle.add('$prop:$val');
      }
    }

    if (cssColor != null &&
        !promoted.containsKey('fill') &&
        (tag == 'text' || tag == 'tspan' || tag == 'g')) {
      promoted['fill'] = cssColor;
    }

    for (final entry in promoted.entries) {
      final attrName = entry.key;
      final attrVal = entry.value;
      final existingRe = RegExp('\\b$attrName="[^"]*"');
      if (existingRe.hasMatch(attrsWithoutStyle)) {
        attrsWithoutStyle = attrsWithoutStyle.replaceFirst(
          existingRe,
          '$attrName="$attrVal"',
        );
      } else {
        attrsWithoutStyle += ' $attrName="$attrVal"';
      }
    }

    if (remainingStyle.isNotEmpty) {
      attrsWithoutStyle += ' style="${remainingStyle.join(';')};"';
    }

    return '<$tag$attrsWithoutStyle$selfClose>';
  });
}

import 'dart:math' as math;

import '../text/entities.dart';
import '../text/measurer.dart';
import '../types.dart';
import 'builder.dart';

/// Resolves all CSS variables (`var(--_*)`, `var(--pele-*)`), `color-mix(in srgb, ...)`,
/// `calc(...)`, inline `style="..."` presentation/geometry properties (`rx`, `ry`, `fill`,
/// `stroke`, `stroke-width`, etc.), `currentColor`, and `baseline-shift` into pure static
/// SVG 1.1 attributes compatible with `vector_graphics_compiler` and non-CSS SVG renderers.
String flattenPeleSvg(String svg, {PelePalette palette = PelePalette.light}) {
  final vars = _buildVarMap(palette);
  _extractRootSvgCustomSeriesVars(svg, vars);

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

  // 5. Strip SVG 2 fallback colors after paint server url(#id) references so
  // vector_graphics_compiler resolves linear/radial gradients by exact IRI.
  if (out.contains('fill="url(#')) {
    out = out.replaceAllMapped(
      _urlFallbackFillRe,
      (m) => 'fill="${m.group(1)!}"',
    );
  }

  // 6. Convert nested <svg class="pele-icon|pele-math" ...> elements into
  // <g transform="translate(...) scale(...)"> groups for vector_graphics_compiler.
  if (out.indexOf('<svg ', 5) >= 0) {
    out = _flattenNestedSvgs(out);
  }

  // 7. Propagate <g fill-opacity="..." stroke-opacity="..." font-size="..."> down to child
  // elements so vector_graphics_compiler applies per-shape opacity and explicit text sizes.
  out = _propagateGroupOpacities(out);

  // 8. Normalize <text> elements containing <tspan> children so vector_graphics_compiler
  // never leaves parent TextPosition.transform unconsumed on sibling <tspan> nodes
  // or mis-positions subscript/superscript dy="..." spans.
  out = _normalizeMultiSpanTextPositions(out);

  return out;
}

final RegExp _urlFallbackFillRe = RegExp(r'fill="(url\(#[^")]+\))\s+[^"]+"');
final RegExp _nestedSvgRe = RegExp(
  r'<svg\s+(class="pele-(?:icon|math)"[^>]*)>([\s\S]*?)<\/svg>',
);
final RegExp _attrXRe = RegExp(r'\s+x="([^"]*)"');
final RegExp _attrYRe = RegExp(r'\s+y="([^"]*)"');
final RegExp _attrWidthRe = RegExp(r'\s+width="([^"]*)"');
final RegExp _attrHeightRe = RegExp(r'\s+height="([^"]*)"');
final RegExp _attrViewBoxRe = RegExp(r'\s+viewBox="([^"]*)"');
final RegExp _attrOverflowRe = RegExp(r'\s+overflow="[^"]*"');
final RegExp _wsSplitRe = RegExp(r'[\s,]+');

String _flattenNestedSvgs(String svg) {
  return svg.replaceAllMapped(_nestedSvgRe, (m) {
    var attrs = ' ${m.group(1)!}';
    final inner = m.group(2)!;

    final xVal =
        double.tryParse(_attrXRe.firstMatch(attrs)?.group(1) ?? '') ?? 0.0;
    final yVal =
        double.tryParse(_attrYRe.firstMatch(attrs)?.group(1) ?? '') ?? 0.0;
    final wVal = double.tryParse(
      _attrWidthRe.firstMatch(attrs)?.group(1) ?? '',
    );
    final hVal = double.tryParse(
      _attrHeightRe.firstMatch(attrs)?.group(1) ?? '',
    );
    final vbRaw = _attrViewBoxRe.firstMatch(attrs)?.group(1)?.trim();

    attrs = attrs
        .replaceFirst(_attrXRe, '')
        .replaceFirst(_attrYRe, '')
        .replaceFirst(_attrWidthRe, '')
        .replaceFirst(_attrHeightRe, '')
        .replaceFirst(_attrViewBoxRe, '')
        .replaceFirst(_attrOverflowRe, '');

    final transforms = <String>[];
    if (xVal != 0.0 || yVal != 0.0) {
      transforms.add('translate(${num(xVal)},${num(yVal)})');
    }
    if (vbRaw != null && wVal != null && hVal != null) {
      final parts = vbRaw.split(_wsSplitRe);
      if (parts.length == 4) {
        final vx = double.tryParse(parts[0]) ?? 0.0;
        final vy = double.tryParse(parts[1]) ?? 0.0;
        final vw = double.tryParse(parts[2]) ?? 0.0;
        final vh = double.tryParse(parts[3]) ?? 0.0;
        if (vw > 0 && vh > 0) {
          final sx = wVal / vw;
          final sy = hVal / vh;
          if ((sx - 1.0).abs() > 1e-6 || (sy - 1.0).abs() > 1e-6) {
            transforms.add(
              (sx - sy).abs() < 1e-6
                  ? 'scale(${num(sx)})'
                  : 'scale(${num(sx)},${num(sy)})',
            );
          }
          if (vx != 0.0 || vy != 0.0) {
            transforms.add('translate(${num(-vx)},${num(-vy)})');
          }
        }
      }
    }

    final transformAttr = transforms.isNotEmpty
        ? ' transform="${transforms.join(' ')}"'
        : '';
    return '<g$attrs$transformAttr>$inner</g>';
  });
}

final RegExp _rootSeriesVarRe = RegExp(r'(--pele-series-\d+)\s*:\s*([^;"]+)');

void _extractRootSvgCustomSeriesVars(String svg, Map<String, String> vars) {
  final svgEnd = svg.indexOf('>');
  if (svgEnd <= 0) return;
  final head = svg.substring(0, svgEnd);
  for (final m in _rootSeriesVarRe.allMatches(head)) {
    final key = m.group(1)!.trim();
    final val = m.group(2)!.trim();
    if (val.isNotEmpty) {
      vars[key] = val;
    }
  }
}

Map<String, String> _buildVarMap(PelePalette p) {
  final fgRgb = _parseColor(p.fg) ?? const <double>[31, 31, 31];
  final bgRgb = _parseColor(p.bg) ?? const <double>[255, 255, 255];

  String mixFgBg(double fgPercent) =>
      _formatRgb(_mixRgb(fgRgb, bgRgb, fgPercent / 100.0));

  final muted = p.muted ?? mixFgBg(60);
  final line = p.line ?? p.fg;
  final surface = p.surface ?? mixFgBg(5);
  final surfaceAlt = p.surfaceAlt;
  final border = p.border ?? mixFgBg(45);
  final accent = p.accent ?? '#5b7bd5';
  final code = p.code ?? mixFgBg(8);
  final radiusStr = '${num(p.radius)}px';
  final swStr = num(p.strokeWidth);
  final tswStr = num(p.thickStrokeWidth);
  final hswStr = num(p.hairlineStrokeWidth);
  final resolvedFont = _resolveConcreteFontFamily(p.fontFamily, isMono: false);
  final resolvedMonoFont = _resolveConcreteFontFamily(
    p.monoFontFamily,
    isMono: true,
  );

  final map = <String, String>{
    '--_bg': p.bg,
    '--_fg': p.fg,
    '--_m': muted,
    '--_l': line,
    '--_s': surface,
    '--_a': surfaceAlt,
    '--_b': border,
    '--_c': accent,
    '--_r': radiusStr,
    '--_w': 'bold',
    '--_tw': 'bold',
    '--_hw': 'bold',
    '--_fm': resolvedMonoFont,
    '--pele-bg': p.bg,
    '--pele-fg': p.fg,
    if (p.fgOnLight != null) '--pele-fg-on-light': p.fgOnLight!,
    if (p.fgOnDark != null) '--pele-fg-on-dark': p.fgOnDark!,
    '--pele-muted': muted,
    '--pele-line': line,
    '--pele-surface': surface,
    '--pele-surface-alt': surfaceAlt,
    '--pele-accent': accent,
    '--pele-border': border,
    '--pele-code': code,
    '--pele-critical': p.critical,
    '--pele-radius': radiusStr,
    '--pele-bold-weight': 'bold',
    '--pele-title-weight': 'bold',
    '--pele-heading-weight': 'bold',
    '--pele-stroke-width': swStr,
    '--pele-thick-stroke-width': tswStr,
    '--pele-hairline-stroke-width': hswStr,
    '--pele-font': resolvedFont,
    '--pele-font-mono': resolvedMonoFont,
  };
  for (var i = 0; i < p.colors.length; i++) {
    map['--pele-c$i'] = p.colors[i];
    map['--pele-series-${i + 1}'] = p.colors[i];
  }
  return map;
}

final RegExp _varExprRe = RegExp(
  r'var\(\s*(--[A-Za-z0-9_-]+)\s*(?:,\s*([^()]+?))?\s*\)',
);
final RegExp _colorMixExprRe = RegExp(
  r'color-mix\(\s*in\s+srgb\s*,((?:[^()]|\([\d.,\s%/]+\))+)\)',
);
final RegExp _calcExprRe = RegExp(
  r'calc\(\s*([+-]?\d+(?:\.\d+)?)(?:px)?\s*\+\s*([+-]?\d+(?:\.\d+)?)(?:px)?\s*\)',
);
final RegExp _rgbColorRe = RegExp(
  r'^rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)',
);
final RegExp _fontFamilyAttrRe = RegExp(r'(?<=\s)font-family=');
final RegExp _fontSizeAttrRe = RegExp(r'(?<=\s)font-size=');

String _resolveExpressions(String input, Map<String, String> vars) {
  var current = input;
  for (var pass = 0; pass < 8; pass++) {
    var changed = false;

    // Resolve innermost var(--name) or var(--name, fallback) without nested parens.
    if (current.contains('var(')) {
      current = current.replaceAllMapped(_varExprRe, (m) {
        changed = true;
        final name = m.group(1)!;
        final fallback = m.group(2)?.trim();
        final resolved = vars[name] ?? fallback ?? '';
        return resolved.replaceAll('"', "'");
      });
    }

    // Resolve innermost color-mix(in srgb, ...) without nested parens.
    if (current.contains('color-mix(')) {
      current = current.replaceAllMapped(_colorMixExprRe, (m) {
        final evaluated = _evalColorMixBody(m.group(1)!);
        if (evaluated != null) {
          changed = true;
          return evaluated;
        }
        return m.group(0)!;
      });
    }

    // Resolve simple calc(A + B) expressions.
    if (current.contains('calc(')) {
      current = current.replaceAllMapped(_calcExprRe, (m) {
        changed = true;
        final a = double.parse(m.group(1)!);
        final b = double.parse(m.group(2)!);
        return num(a + b);
      });
    }

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
  final rgbMatch = _rgbColorRe.firstMatch(s);
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
  r'<([a-zA-Z][a-zA-Z0-9]*)\b([^>]*?\sstyle="([^"]*)"[^>]*?)(\/?)>',
);

final RegExp _styleAttrReplaceRe = RegExp(r'\s+style="[^"]*"');

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

final Map<String, RegExp> _existingAttrRe = <String, RegExp>{
  for (final prop in _promotableProps) prop: RegExp('(?<=\\s)$prop="[^"]*"'),
};

final RegExp _rootFontShorthandRe = RegExp(
  r'(?:^|;)\s*font\s*:\s*([\d.]+)px\b',
);

const Set<String> _cssSystemFontKeywords = <String>{
  '-apple-system',
  'blinkmacsystemfont',
  'system-ui',
  'ui-sans-serif',
  'ui-monospace',
  'ui-serif',
  'segoe ui',
  'sfmono-regular',
  'sans-serif',
  'monospace',
  'serif',
};

/// Resolves a CSS comma-separated `font-family` stack into a single concrete
/// font family name suitable for `dart:ui` / `vector_graphics` (`TextStyle.fontFamily`).
String _resolveConcreteFontFamily(String cssFontStack, {required bool isMono}) {
  final defaultFamily = isMono ? 'Menlo' : 'Helvetica';
  final raw = cssFontStack.trim();
  if (raw.isEmpty) return defaultFamily;
  for (final part in raw.split(',')) {
    var candidate = part.trim();
    if ((candidate.startsWith('"') && candidate.endsWith('"')) ||
        (candidate.startsWith("'") && candidate.endsWith("'"))) {
      candidate = candidate.substring(1, candidate.length - 1).trim();
    }
    if (candidate.isEmpty) continue;
    if (_cssSystemFontKeywords.contains(candidate.toLowerCase())) continue;
    return candidate;
  }
  return defaultFamily;
}

String _flattenInlineStyles(String svg, PelePalette palette) {
  final rootFontFamily = _resolveConcreteFontFamily(
    palette.fontFamily,
    isMono: false,
  );
  return svg.replaceAllMapped(_tagWithStyleRe, (m) {
    final tag = m.group(1)!;
    final attrsAndStyle = m.group(2)!;
    final styleContent = m.group(3)!;
    final selfClose = m.group(4)!;

    var attrsWithoutStyle = attrsAndStyle.replaceFirst(_styleAttrReplaceRe, '');

    if (tag == 'svg' && attrsWithoutStyle.contains('class="pele')) {
      // Root <svg>: replace CSS custom properties & font shorthand with static SVG attributes.
      final extra = StringBuffer();
      if (!_fontFamilyAttrRe.hasMatch(attrsWithoutStyle)) {
        extra.write(' font-family="${esc(rootFontFamily)}"');
      }
      if (!_fontSizeAttrRe.hasMatch(attrsWithoutStyle)) {
        final fontSizeMatch = _rootFontShorthandRe.firstMatch(styleContent);
        final rootFontSize = fontSizeMatch?.group(1) ?? '16';
        extra.write(' font-size="$rootFontSize"');
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
        if (prop == 'font-family') {
          val = _resolveConcreteFontFamily(
            val,
            isMono: val.toLowerCase().contains('mono'),
          );
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
      final existingRe =
          _existingAttrRe[attrName] ?? RegExp('(?<=\\s)$attrName="[^"]*"');
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

final RegExp _anyXmlTagRe = RegExp(
  r'<(\/?)([a-zA-Z][a-zA-Z0-9]*)\b([^>]*?)(\/?)>',
);
final RegExp _fillOpacityAttrRe = RegExp(r'\s+fill-opacity="([^"]*)"');
final RegExp _strokeOpacityAttrRe = RegExp(r'\s+stroke-opacity="([^"]*)"');
final RegExp _groupFontSizeAttrRe = RegExp(r'\s+font-size="([^"]*)"');
final RegExp _fillNoneAttrRe = RegExp(r'(?<=\s)fill="none"');
final RegExp _strokeNoneAttrRe = RegExp(r'(?<=\s)stroke="none"');

const Set<String> _opacityTargetTags = <String>{
  'path',
  'polygon',
  'polyline',
  'rect',
  'circle',
  'ellipse',
  'line',
  'text',
  'use',
};

String _propagateGroupOpacities(String svg) {
  final hasOpacity =
      svg.contains('fill-opacity=') || svg.contains('stroke-opacity=');
  final hasGroupFontSize = svg.contains('<g ') && svg.contains('font-size=');
  if (!hasOpacity && !hasGroupFontSize) {
    return svg;
  }

  final stack =
      <({double? fillOpacity, double? strokeOpacity, String? fontSize})>[];

  return svg.replaceAllMapped(_anyXmlTagRe, (m) {
    final isClose = m.group(1) == '/';
    final tag = m.group(2)!;
    var attrs = m.group(3)!;
    final selfClose = m.group(4)!;

    if (isClose) {
      if (tag == 'g' && stack.isNotEmpty) {
        stack.removeLast();
      }
      return m.group(0)!;
    }

    final parentFillOp = stack.isNotEmpty ? stack.last.fillOpacity : null;
    final parentStrokeOp = stack.isNotEmpty ? stack.last.strokeOpacity : null;
    final parentFontSize = stack.isNotEmpty ? stack.last.fontSize : null;

    if (tag == 'g') {
      double? ownFillOp;
      double? ownStrokeOp;
      String? ownFontSize;

      if (hasOpacity) {
        final fm = _fillOpacityAttrRe.firstMatch(attrs);
        if (fm != null) {
          ownFillOp = double.tryParse(fm.group(1)!.trim());
          if (ownFillOp != null) {
            attrs = attrs.replaceFirst(_fillOpacityAttrRe, '');
          }
        }

        final sm = _strokeOpacityAttrRe.firstMatch(attrs);
        if (sm != null) {
          ownStrokeOp = double.tryParse(sm.group(1)!.trim());
          if (ownStrokeOp != null) {
            attrs = attrs.replaceFirst(_strokeOpacityAttrRe, '');
          }
        }
      }

      if (hasGroupFontSize) {
        final fsm = _groupFontSizeAttrRe.firstMatch(attrs);
        if (fsm != null) {
          ownFontSize = fsm.group(1)!.trim();
        }
      }

      final effFillOp = ownFillOp != null && parentFillOp != null
          ? ownFillOp * parentFillOp
          : (ownFillOp ?? parentFillOp);
      final effStrokeOp = ownStrokeOp != null && parentStrokeOp != null
          ? ownStrokeOp * parentStrokeOp
          : (ownStrokeOp ?? parentStrokeOp);
      final effFontSize = ownFontSize ?? parentFontSize;

      if (selfClose.isEmpty) {
        stack.add((
          fillOpacity: effFillOp,
          strokeOpacity: effStrokeOp,
          fontSize: effFontSize,
        ));
      }
      return '<g$attrs$selfClose>';
    }

    var modified = false;

    if (tag == 'text' &&
        parentFontSize != null &&
        !_fontSizeAttrRe.hasMatch(attrs)) {
      attrs += ' font-size="$parentFontSize"';
      modified = true;
    }

    if ((parentFillOp != null || parentStrokeOp != null) &&
        _opacityTargetTags.contains(tag)) {
      if (parentFillOp != null && !_fillNoneAttrRe.hasMatch(attrs)) {
        final fm = _fillOpacityAttrRe.firstMatch(attrs);
        if (fm != null) {
          final existing = double.tryParse(fm.group(1)!.trim());
          if (existing != null) {
            attrs = attrs.replaceFirst(
              _fillOpacityAttrRe,
              ' fill-opacity="${num(existing * parentFillOp)}"',
            );
          }
        } else {
          attrs += ' fill-opacity="${num(parentFillOp)}"';
        }
        modified = true;
      }

      if (parentStrokeOp != null && !_strokeNoneAttrRe.hasMatch(attrs)) {
        final sm = _strokeOpacityAttrRe.firstMatch(attrs);
        if (sm != null) {
          final existing = double.tryParse(sm.group(1)!.trim());
          if (existing != null) {
            attrs = attrs.replaceFirst(
              _strokeOpacityAttrRe,
              ' stroke-opacity="${num(existing * parentStrokeOp)}"',
            );
          }
        } else {
          attrs += ' stroke-opacity="${num(parentStrokeOp)}"';
        }
        modified = true;
      }
    }

    return modified ? '<$tag$attrs$selfClose>' : m.group(0)!;
  });
}

final RegExp _textElementWithContentRe = RegExp(
  r'<text\b([^>]*)>([\s\S]*?)<\/text>',
);
final RegExp _tspanElementRe = RegExp(r'<tspan\b([^>]*)>([\s\S]*?)<\/tspan>');
final RegExp _attrDyRe = RegExp(r'\s+dy="([^"]*)"');
final RegExp _attrTextAnchorRe = RegExp(r'\s+text-anchor="([^"]*)"');
final RegExp _attrFontWeightBoldRe = RegExp(
  r'(?<=\s)font-weight="(?:bold|[6-9]00)"',
);
final RegExp _attrFontFamilyMonoRe = RegExp(
  r'(?<=\s)font-family="[^"]*(?:Menlo|Monaco|Consolas|monospace)[^"]*"',
  caseSensitive: false,
);

class _TspanSegment {
  final String attrs;
  final String text;
  final double? x;
  final double? y;
  final double? dy;

  const _TspanSegment({
    required this.attrs,
    required this.text,
    this.x,
    this.y,
    this.dy,
  });
}

String _normalizeMultiSpanTextPositions(String svg) {
  if (!svg.contains('<tspan')) return svg;

  final rootFontSizeMatch = _groupFontSizeAttrRe.firstMatch(
    svg.substring(0, math.min(svg.length, 512)),
  );
  final defaultFontSize =
      double.tryParse(rootFontSizeMatch?.group(1) ?? '') ?? 16.0;

  return svg.replaceAllMapped(_textElementWithContentRe, (m) {
    final textAttrs = m.group(1)!;
    final inner = m.group(2)!;
    if (!inner.contains('<tspan')) return m.group(0)!;

    final textXStr = _attrXRe.firstMatch(textAttrs)?.group(1);
    final textYStr = _attrYRe.firstMatch(textAttrs)?.group(1);

    // Fast path: when no <tspan> uses dy="...", vector_graphics_compiler 1.3+ and
    // vector_graphics 1.2+ handle multi-span <text> and text-anchor="middle|end"
    // natively via _pendingChunk as long as the parent <text> element itself has
    // explicit x="..." and y="..." attributes (so TextPositionNode consumes any
    // enclosing <g transform="translate(...)"> and sets parent.transform = null).
    if (!inner.contains(' dy="')) {
      if (textXStr != null && textYStr != null) {
        return m.group(0)!;
      }
      final firstX = textXStr ?? _attrXRe.firstMatch(inner)?.group(1);
      final firstY = textYStr ?? _attrYRe.firstMatch(inner)?.group(1);
      if (firstX == null || firstY == null) {
        return m.group(0)!;
      }
      var updatedAttrs = textAttrs;
      if (textXStr == null) updatedAttrs += ' x="$firstX"';
      if (textYStr == null) updatedAttrs += ' y="$firstY"';
      return '<text$updatedAttrs>$inner</text>';
    }

    // Slow path for <text> containing subscript/superscript <tspan dy="...">:
    // vector_graphics_compiler does not set inheritsConsumedTransform when dy != null,
    // and vector_graphics mutates _textPositionY permanently on dy != null.
    // Convert each span on lines into explicit x="..." y="..." coordinates with dy stripped.
    final textX = double.tryParse(textXStr ?? '');
    final textY = double.tryParse(textYStr ?? '');
    final segments = <_TspanSegment>[];
    var cursor = 0;
    for (final tm in _tspanElementRe.allMatches(inner)) {
      if (tm.start > cursor) {
        final rawText = inner.substring(cursor, tm.start);
        if (rawText.isNotEmpty) {
          segments.add(_TspanSegment(attrs: '', text: rawText));
        }
      }
      final sAttrs = tm.group(1)!;
      final sText = tm.group(2)!;
      final sx = double.tryParse(_attrXRe.firstMatch(sAttrs)?.group(1) ?? '');
      final sy = double.tryParse(_attrYRe.firstMatch(sAttrs)?.group(1) ?? '');
      final sdy = double.tryParse(_attrDyRe.firstMatch(sAttrs)?.group(1) ?? '');
      segments.add(
        _TspanSegment(attrs: sAttrs, text: sText, x: sx, y: sy, dy: sdy),
      );
      cursor = tm.end;
    }
    if (cursor < inner.length) {
      final rawText = inner.substring(cursor);
      if (rawText.isNotEmpty) {
        segments.add(_TspanSegment(attrs: '', text: rawText));
      }
    }
    if (segments.isEmpty) return m.group(0)!;

    final lines = <({double x, double y, List<_TspanSegment> segs})>[];
    for (final seg in segments) {
      if (seg.x != null && seg.y != null) {
        lines.add((x: seg.x!, y: seg.y!, segs: <_TspanSegment>[seg]));
      } else if (lines.isNotEmpty) {
        lines.last.segs.add(seg);
      } else if (textX != null && textY != null) {
        lines.add((x: textX, y: textY, segs: <_TspanSegment>[seg]));
      } else {
        return m.group(0)!;
      }
    }
    if (lines.isEmpty) return m.group(0)!;

    final anchor =
        _attrTextAnchorRe.firstMatch(textAttrs)?.group(1)?.trim() ?? 'start';
    final textFontSize =
        double.tryParse(
          _groupFontSizeAttrRe.firstMatch(textAttrs)?.group(1) ?? '',
        ) ??
        defaultFontSize;
    final textBold = _attrFontWeightBoldRe.hasMatch(textAttrs);
    final textMono = _attrFontFamilyMonoRe.hasMatch(textAttrs);

    final outSpans = StringBuffer();
    for (final line in lines) {
      final widths = <double>[];
      var totalWidth = 0.0;
      for (final seg in line.segs) {
        final segFontSize =
            double.tryParse(
              _groupFontSizeAttrRe.firstMatch(seg.attrs)?.group(1) ?? '',
            ) ??
            textFontSize;
        final isBold = textBold || _attrFontWeightBoldRe.hasMatch(seg.attrs);
        final isMono = textMono || _attrFontFamilyMonoRe.hasMatch(seg.attrs);
        var style = 0;
        if (isBold) style |= Style.bold;
        if (isMono) style |= Style.mono;
        final w = metricsMeasurer.width(
          decodeEntities(seg.text),
          segFontSize,
          style,
        );
        widths.add(w);
        totalWidth += w;
      }

      final double xStart;
      if (anchor == 'end') {
        xStart = line.x - totalWidth;
      } else if (anchor == 'middle') {
        xStart = line.x - totalWidth / 2.0;
      } else {
        xStart = line.x;
      }

      var curX = xStart;
      for (var i = 0; i < line.segs.length; i++) {
        final seg = line.segs[i];
        final spanY = line.y + (seg.dy ?? 0.0);
        final cleanedAttrs = seg.attrs
            .replaceFirst(_attrXRe, '')
            .replaceFirst(_attrYRe, '')
            .replaceFirst(_attrDyRe, '')
            .replaceFirst(_attrTextAnchorRe, '');
        outSpans.write(
          '<tspan x="${num(curX)}" y="${num(spanY)}"$cleanedAttrs>${seg.text}</tspan>',
        );
        curX += widths[i];
      }
    }

    final firstLine = lines.first;
    final cleanedTextAttrs = textAttrs
        .replaceFirst(_attrXRe, '')
        .replaceFirst(_attrYRe, '')
        .replaceFirst(_attrTextAnchorRe, '');
    return '<text x="${num(firstLine.x)}" y="${num(firstLine.y)}"$cleanedTextAttrs text-anchor="start">$outSpans</text>';
  });
}

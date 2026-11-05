// Upstream: src/svg/theme.ts

import 'builder.dart';

const String rootStyle =
    '--_bg:var(--pele-bg,#fff);--_fg:var(--pele-fg,#1f1f1f);--_m:var(--pele-muted,#6e6e6e);'
    '--_l:var(--pele-line,#1f1f1f);--_s:var(--pele-surface,#f3f3f3);--_a:var(--pele-surface-alt,#e6e6e6);'
    '--_b:var(--pele-border,#8a8a8a);--_c:var(--pele-accent,#5b7bd5);color:var(--_fg)';

const String fontMono = 'var(--_fm)';
const String radius = 'var(--pele-radius,4px)';
const String roundedAttr = ' style="rx:var(--_r)"';

final RegExp _reFill = RegExp(r'[";]fill:');

bool setsFill(String shape) => _reFill.hasMatch(shape);

String rounded(String attrs) {
  final at = attrs.indexOf(' style="');
  return at < 0
      ? '$attrs$roundedAttr'
      : '${attrs.substring(0, at + 8)}rx:var(--_r);${attrs.substring(at + 8)}';
}

const String critical = 'var(--pele-critical,#e45756)';

const String _family =
    r'''(?:"[^"'\\\n<>{}();:@]*"|'[^"'\\\n<>{}();:@]*'|[\p{L}\p{N}_-][\p{L}\p{N}_ .-]*)''';
final RegExp _reFamilies = RegExp(
  '^\\s*$_family(?:\\s*,\\s*$_family)*\\s*\$',
  unicode: true,
);

String _families(String? list, String generic) {
  return list != null && list.isNotEmpty && _reFamilies.hasMatch(list)
      ? list
      : generic;
}

String fontStyle(double size, String? family, String? mono) {
  final sizeStr = size == size.truncateToDouble() ? '${size.toInt()}' : '$size';
  return ';--_fm:var(--pele-font-mono,${_families(mono, 'monospace')});font:${sizeStr}px sans-serif;'
      'letter-spacing:normal;word-spacing:normal;text-transform:none;direction:ltr;'
      'font-family:var(--pele-font,${_families(family, 'sans-serif')})';
}

const Set<String> _shapeProps = {
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
  'rx',
  'ry',
};

const Set<String> _textProps = {
  'color',
  'font-size',
  'font-family',
  'font-weight',
  'font-style',
  'text-decoration',
  'letter-spacing',
  'word-spacing',
  'opacity',
};

final RegExp _reUnsafe = RegExp(
  r'url\s*\(|expression\s*\(|javascript:|[<>{};\\]|@import|image-set|\/\*',
  caseSensitive: false,
);

class ResolvedStyle {
  const ResolvedStyle({
    required this.shape,
    required this.line,
    required this.text,
    this.stroke,
    required this.bold,
    required this.italic,
    this.fontSize,
  });

  final String shape;
  final String line;
  final String text;
  final String? stroke;
  final bool bold;
  final bool italic;
  final double? fontSize;
}

const ResolvedStyle _none = ResolvedStyle(
  shape: '',
  line: '',
  text: '',
  bold: false,
  italic: false,
);

ResolvedStyle resolveStyle(List<String> declarations) {
  if (declarations.isEmpty) return _none;
  final shape = <String, String>{};
  final text = <String, String>{};
  for (final decl in declarations) {
    final at = decl.indexOf(':');
    if (at <= 0) continue;
    final prop = decl.substring(0, at).trim().toLowerCase();
    final value = decl
        .substring(at + 1)
        .replaceAll(RegExp(r'!important', caseSensitive: false), '')
        .trim();
    if (value.isEmpty ||
        _reUnsafe.hasMatch(value) ||
        reInvalidXml.hasMatch(value)) {
      continue;
    }
    if (_shapeProps.contains(prop)) shape[prop] = value;
    if (_textProps.contains(prop)) {
      text[prop == 'color' ? 'fill' : prop] = value;
    }
  }
  if (shape.isEmpty && text.isEmpty) return _none;
  final shapeCss = StringBuffer();
  final lineCss = StringBuffer();
  for (final entry in shape.entries) {
    shapeCss.write('${entry.key}:${entry.value};');
    if (entry.key != 'fill' && entry.key != 'fill-opacity') {
      lineCss.write('${entry.key}:${entry.value};');
    }
  }
  final textCss = StringBuffer();
  for (final entry in text.entries) {
    textCss.write('${entry.key}:${entry.value};');
  }
  final weight = text['font-weight'];
  final size = text['font-size'];
  double? px;
  if (size != null && RegExp(r'^[\d.]+(px)?$').hasMatch(size)) {
    final numPart = size.endsWith('px')
        ? size.substring(0, size.length - 2)
        : size;
    px = double.tryParse(numPart);
  }
  final weightNum = weight != null ? double.tryParse(weight) : null;
  return ResolvedStyle(
    shape: shapeCss.isNotEmpty ? ' style="${esc(shapeCss.toString())}"' : '',
    line: lineCss.isNotEmpty ? ' style="${esc(lineCss.toString())}"' : '',
    text: textCss.isNotEmpty ? ' style="${esc(textCss.toString())}"' : '',
    stroke: shape['stroke'],
    bold:
        weight == 'bold' ||
        weight == 'bolder' ||
        (weightNum != null && weightNum >= 600),
    italic: text['font-style'] == 'italic',
    fontSize: px != null && px > 0 && px <= 200 ? px : null,
  );
}

final RegExp _reClass = RegExp(r'[^\w-]+');

String classNames(String raw) {
  final cleaned = raw.replaceAll(_reClass, ' ').trim();
  return cleaned.isEmpty ? '' : ' $cleaned';
}

const List<String> _series = [
  '#4c78a8',
  '#f58518',
  '#54a24b',
  '#e45756',
  '#72b7b2',
  '#eeca3b',
  '#b279a2',
  '#9d755d',
];

String seriesColor(int index) {
  final k = ((index % 8) + 8) % 8;
  return 'var(--pele-series-${k + 1},${_series[k]})';
}

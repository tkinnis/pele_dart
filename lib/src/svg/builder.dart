// Upstream: src/svg/builder.ts

import '../text/entities.dart';
import '../text/label.dart';
import '../text/measurer.dart';
import '../types.dart';
import '../util/math_js.dart';

export '../types.dart' show IconResolver;

final RegExp _reEsc = RegExp(
  r'[&<>"]|[\x00-\x08\x0b\x0c\x0e-\x1f\x7f\ud800-\udfff\ufffe\uffff]+',
  unicode: true,
);
const Map<String, String> _escMap = {
  '&': '&amp;',
  '<': '&lt;',
  '>': '&gt;',
  '"': '&quot;',
};

/// Removing these characters in [esc] can make validated values unsafe.
final RegExp reInvalidXml = RegExp(
  r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f\ud800-\udfff\ufffe\uffff]',
  unicode: true,
);

/// Fast code-unit check equivalent to `reInvalidXml.hasMatch(text)` without
/// invoking the Unicode RegExp runtime on every CSS declaration.
bool hasInvalidXml(String text) {
  final len = text.length;
  for (var i = 0; i < len; i++) {
    final c = text.codeUnitAt(i);
    if (c >= 0x20 && c < 0x7f) continue;
    if (c == 0x09 || c == 0x0a || c == 0x0d) continue;
    if (c > 0x7f && c < 0xd800) continue;
    if (c > 0xdfff && c < 0xfffe) continue;
    if (c >= 0xd800 && c <= 0xdbff && i + 1 < len) {
      final low = text.codeUnitAt(i + 1);
      if (low >= 0xdc00 && low <= 0xdfff) {
        i++;
        continue;
      }
    }
    return true;
  }
  return false;
}

bool _needsEsc(String text) {
  final len = text.length;
  for (var i = 0; i < len; i++) {
    final c = text.codeUnitAt(i);
    if (c >= 0x20 && c < 0x7f) {
      if (c == 0x26 || c == 0x3c || c == 0x3e || c == 0x22) return true;
      continue;
    }
    if (c == 0x09 || c == 0x0a || c == 0x0d) continue;
    if (c > 0x7f && c < 0xd800) continue;
    if (c > 0xdfff && c < 0xfffe) continue;
    if (c >= 0xd800 && c <= 0xdbff && i + 1 < len) {
      final low = text.codeUnitAt(i + 1);
      if (low >= 0xdc00 && low <= 0xdfff) {
        i++;
        continue;
      }
    }
    return true;
  }
  return false;
}

/// Escapes text for XML and drops invalid XML characters and DEL.
String esc(String text) {
  return _needsEsc(text)
      ? text.replaceAllMapped(_reEsc, (m) => _escMap[m.group(0)!] ?? '')
      : text;
}

/// Escapes text that is only ever read as text: a tooltip, an accessible name, a `data-id`.
String escText(String text) {
  return esc(decodeEntities(text));
}

final List<String> _fraction = [
  for (var i = 0; i < 100; i++)
    i == 0 ? '' : (i % 10 == 0 ? '.${i ~/ 10}' : '.${i < 10 ? '0$i' : '$i'}'),
];
final List<String> _smallInts = [for (var i = 0; i < 2048; i++) '$i'];
final List<String> _smallNegInts = [for (var i = 0; i < 1024; i++) '-$i'];
final List<String> _smallHalves = [for (var i = 0; i < 1024; i++) '$i.5'];
final List<String> _smallNegHalves = [for (var i = 0; i < 1024; i++) '-$i.5'];

String num(double value) {
  if (value.isNaN) return 'NaN';
  if (value.isInfinite) return value < 0 ? '-Infinity' : 'Infinity';
  final n = roundJs(value * 100);
  if (n == 0) return '0';
  if (n > 0) {
    if (n < 100000000000) {
      final q = n ~/ 100;
      final rem = n - q * 100;
      if (rem == 0) return q < 2048 ? _smallInts[q] : '$q';
      if (rem == 50 && q < 1024) return _smallHalves[q];
      return '$q${_fraction[rem]}';
    }
  } else if (n > -100000000000) {
    final m = -n;
    final q = m ~/ 100;
    final rem = m - q * 100;
    if (rem == 0) return q < 1024 ? _smallNegInts[q] : '-$q';
    if (rem == 50 && q < 1024) return _smallNegHalves[q];
    return '-$q${_fraction[rem]}';
  }
  return '${n / 100}';
}

/// Writes a measured label as SVG text centered on `(cx, cy)`.
String labelSvg(
  Label label,
  double cx,
  double cy,
  String attrs, [
  IconResolver? icons,
]) {
  final lines = label.lines;
  if (lines.isEmpty) return '';
  final lh = label.lineHeight;
  final heights = label.heights;
  final shift = label.size * 0.35;
  var top = cy - label.height / 2;

  final only = lines.length == 1 && lines[0].length == 1 ? lines[0][0] : null;
  if (only != null && only.icon == null && only.math == null) {
    final y = num(top + lh / 2 + shift);
    if (only.style == 0) {
      return '<text$attrs x="${num(cx)}" y="$y" text-anchor="middle">${esc(only.text)}</text>';
    }
    if (only.text.isNotEmpty) {
      final shared = only.style & (Style.bold | Style.italic | Style.mono);
      final styledAttrs = textStyle(attrs, shared);
      final spStyle = spanStyle(only.style & ~shared);
      return '<text$styledAttrs text-anchor="middle" xml:space="preserve"><tspan x="${num(cx)}" y="$y"$spStyle>${esc(only.text)}</tspan></text>';
    }
  }

  final shared = sharedStyle(label);
  final given = attrs;
  _MathLook? math;
  attrs = textStyle(attrs, shared);
  final body = StringBuffer();
  StringBuffer? extra;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final h = heights != null ? heights[i] : lh;
    final mid = top + h / 2;
    final y = mid + shift;
    var placed = false;
    for (final span in line) {
      if (span.icon != null || span.math != null) {
        placed = true;
        break;
      }
    }
    if (placed) {
      extra ??= StringBuffer();
      var x = cx - label.widths[i] / 2;
      for (final span in line) {
        if (span.math != null) {
          final m = span.math!;
          final box =
              'x="${num(x)}" y="${num(mid - m.height / 2)}" width="${num(m.width)}" height="${num(m.height)}"';
          math ??= _mathLook(given);
          extra.write(
            math.halo == null
                ? _mathSvg(m, box, label.size, math.attrs)
                : '<rect $box rx="2" fill="${math.halo}"/>',
          );
        } else if (span.icon != null) {
          final side = label.size * 1.1;
          final inner = icons?.call(span.icon!) ?? '';
          extra.write(
            '<svg class="pele-icon" data-icon="${escText(span.icon!)}" x="${num(x)}" y="${num(mid - side / 2)}" width="${num(side)}" height="${num(side)}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">$inner</svg>',
          );
        } else if (span.text.isNotEmpty) {
          body.write(
            '<tspan x="${num(x)}" y="${num(y)}" text-anchor="start"${spanStyle(span.style & ~shared)}>${esc(span.text)}</tspan>',
          );
        }
        x += span.width;
      }
    } else {
      for (var j = 0; j < line.length; j++) {
        final span = line[j];
        final pos = j == 0 ? ' x="${num(cx)}" y="${num(y)}"' : '';
        body.write(
          '<tspan$pos${spanStyle(span.style & ~shared)}>${esc(span.text)}</tspan>',
        );
      }
      if (line.isEmpty) {
        body.write('<tspan x="${num(cx)}" y="${num(y)}"> </tspan>');
      }
    }
    top += h;
  }
  return extra == null
      ? '<text$attrs text-anchor="middle" xml:space="preserve">$body</text>'
      : '<text$attrs text-anchor="middle" xml:space="preserve">$body</text>$extra';
}

final RegExp _reFill = RegExp(r' fill="([^"]*)"');
final RegExp _reStroke = RegExp(r' stroke="([^"]*)"');
final RegExp _reStyle = RegExp(r' style="([^"]*)"');
final RegExp _reStyleFill = RegExp(r'(?:^|;)\s*fill:([^;]*)');
final RegExp _reStyleOpacity = RegExp(r'(?:^|;)\s*opacity:([^;]*)');

class _MathLook {
  const _MathLook({required this.attrs, this.halo});
  final String attrs;
  final String? halo;
}

_MathLook _mathLook(String attrs) {
  final style = _reStyle.firstMatch(attrs)?.group(1) ?? '';
  final fill =
      (_reStyleFill.firstMatch(style)?.group(1) ??
              _reFill.firstMatch(attrs)?.group(1) ??
              '')
          .trim();
  if (fill == 'none') {
    return _MathLook(
      attrs: '',
      halo: _reStroke.firstMatch(attrs)?.group(1) ?? 'none',
    );
  }
  final opacity = _reStyleOpacity.firstMatch(style)?.group(1)?.trim();
  return _MathLook(
    attrs:
        '${fill.isEmpty ? '' : ' color="$fill"'}${opacity != null && opacity.isNotEmpty ? ' opacity="$opacity"' : ''}',
  );
}

String _mathSvg(MathMarkup math, String box, double size, String attrs) {
  if (math.svg != null) {
    return '<svg class="pele-math" $box overflow="visible"$attrs>${math.svg}</svg>';
  }
  return '<foreignObject class="pele-math" $box overflow="visible"$attrs>'
      '<div xmlns="http://www.w3.org/1999/xhtml" style="display:flex;align-items:center;justify-content:center;width:100%;height:100%;font-size:${num(size)}px;line-height:normal;white-space:nowrap">${math.html}</div>'
      '</foreignObject>';
}

const String _bold = ' font-weight="var(--_w)"';
const String _italic = ' font-style="italic"';
const String _underline = ' text-decoration="underline"';
const String _mono = ' font-family="var(--_fm)"';
const String _sub = ' baseline-shift="sub" font-size="smaller"';
const String _sup = ' baseline-shift="super" font-size="smaller"';

String spanStyle(int style) {
  if (style == 0) return '';
  return ((style & Style.bold) != 0 ? _bold : '') +
      ((style & Style.italic) != 0 ? _italic : '') +
      ((style & Style.mono) != 0 ? _mono : '') +
      ((style & Style.underline) != 0 ? _underline : '') +
      ((style & Style.sub) != 0
          ? _sub
          : ((style & Style.sup) != 0 ? _sup : ''));
}

int sharedStyle(Label label) {
  var shared = Style.bold | Style.italic | Style.mono;
  var any = false;
  for (final line in label.lines) {
    for (final span in line) {
      if (span.icon != null || span.text.isEmpty) continue;
      shared &= span.style;
      any = true;
    }
  }
  return any ? shared : 0;
}

String textStyle(String attrs, int shared) {
  if (shared == 0) return attrs;
  return attrs +
      ((shared & Style.bold) != 0 && !attrs.contains(' font-weight="')
          ? _bold
          : '') +
      ((shared & Style.italic) != 0 && !attrs.contains(' font-style="')
          ? _italic
          : '') +
      ((shared & Style.mono) != 0 && !attrs.contains(' font-family="')
          ? _mono
          : '');
}

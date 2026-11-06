// Upstream: src/svg/root.ts

import '../types.dart';
import 'builder.dart';
import 'palette.dart';
import 'theme.dart';

const String _defaultFontStyle =
    ';--_fm:var(--pele-font-mono,monospace);font:16px sans-serif;'
    'letter-spacing:normal;word-spacing:normal;text-transform:none;direction:ltr;'
    'font-family:var(--pele-font,sans-serif)';

class Accessible {
  const Accessible({this.accTitle, this.accDescr});
  final String? accTitle;
  final String? accDescr;
}

typedef RootModel = Accessible;

int _usedVarsMask(String content) {
  var mask = 0;
  final end = content.length - 1;
  for (var i = 8; i <= end; i++) {
    if (content.codeUnitAt(i) != 0x29) continue; // ')'
    final prev = content.codeUnitAt(i - 1);
    if (prev == 0x72) {
      // 'r)' -> check 'var(--_' before it
      if ((mask & 1) == 0 &&
          content.codeUnitAt(i - 2) == 0x5f &&
          content.codeUnitAt(i - 3) == 0x2d &&
          content.codeUnitAt(i - 4) == 0x2d &&
          content.codeUnitAt(i - 5) == 0x28 &&
          content.codeUnitAt(i - 6) == 0x72 &&
          content.codeUnitAt(i - 7) == 0x61 &&
          content.codeUnitAt(i - 8) == 0x76) {
        mask |= 1;
        if (mask == 15) return mask;
      }
    } else if (prev == 0x77) {
      // 'w)' -> check '_w)', '_tw)', '_hw)'
      final p2 = content.codeUnitAt(i - 2);
      if (p2 == 0x5f) {
        if ((mask & 8) == 0 &&
            content.codeUnitAt(i - 3) == 0x2d &&
            content.codeUnitAt(i - 4) == 0x2d &&
            content.codeUnitAt(i - 5) == 0x28 &&
            content.codeUnitAt(i - 6) == 0x72 &&
            content.codeUnitAt(i - 7) == 0x61 &&
            content.codeUnitAt(i - 8) == 0x76) {
          mask |= 8;
          if (mask == 15) return mask;
        }
      } else if ((p2 == 0x74 || p2 == 0x68) && i >= 9) {
        final bit = p2 == 0x74 ? 2 : 4;
        if ((mask & bit) == 0 &&
            content.codeUnitAt(i - 3) == 0x5f &&
            content.codeUnitAt(i - 4) == 0x2d &&
            content.codeUnitAt(i - 5) == 0x2d &&
            content.codeUnitAt(i - 6) == 0x28 &&
            content.codeUnitAt(i - 7) == 0x72 &&
            content.codeUnitAt(i - 8) == 0x61 &&
            content.codeUnitAt(i - 9) == 0x76) {
          mask |= bit;
          if (mask == 15) return mask;
        }
      }
    }
  }
  return mask;
}

String _fmtDim(double v) => v == v.truncateToDouble() ? '${v.toInt()}' : '$v';

String svgDocument(
  String type,
  double width,
  double height,
  double fontSize,
  RenderOptions options,
  Accessible? acc,
  String content,
) {
  final rawPrefix = options.idPrefix;
  final prefix = rawPrefix == null ? 'pele' : esc(rawPrefix);
  final head = StringBuffer();
  final aria = StringBuffer();
  final accTitle = acc?.accTitle;
  final accDescr = acc?.accDescr;
  if (accTitle != null && accTitle.isNotEmpty) {
    head.write('<title id="$prefix-title">${escText(accTitle)}</title>');
    aria.write(' aria-labelledby="$prefix-title"');
  }
  if (accDescr != null && accDescr.isNotEmpty) {
    head.write('<desc id="$prefix-desc">${escText(accDescr)}</desc>');
    aria.write(' aria-describedby="$prefix-desc"');
  }
  final fit = options.responsive == false ? '' : 'max-width:100%;height:auto;';
  final usedMask = _usedVarsMask(content);
  final weights = StringBuffer();
  if ((usedMask & 1) != 0) {
    weights.write(';--_r:$radius');
  }
  if ((usedMask & 2) != 0) {
    weights.write(';--_tw:var(--pele-title-weight,bold)');
  }
  if ((usedMask & 4) != 0) {
    weights.write(';--_hw:var(--pele-heading-weight,bold)');
  }
  if ((usedMask & 8) != 0) {
    weights.write(';--_w:var(--pele-bold-weight,bold)');
  }
  final fonts =
      (fontSize == 16 &&
          options.fontFamily == null &&
          options.fontFamilyMono == null)
      ? _defaultFontStyle
      : esc(fontStyle(fontSize, options.fontFamily, options.fontFamilyMono));
  final wStr = _fmtDim(width);
  final hStr = _fmtDim(height);
  return '<svg xmlns="http://www.w3.org/2000/svg" class="pele pele-$type" viewBox="0 0 $wStr $hStr" width="$wStr" height="$hStr" style="$fit$rootStyle$weights$fonts${paletteStyle()}" fill="var(--_fg)" role="graphics-document document" aria-roledescription="$type"$aria>$head$content</svg>';
}

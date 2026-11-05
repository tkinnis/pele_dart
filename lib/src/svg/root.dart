// Upstream: src/svg/root.ts

import '../types.dart';
import 'builder.dart';
import 'palette.dart';
import 'theme.dart';

const List<(String, String)> _weights = <(String, String)>[
  ('tw', 'title'),
  ('hw', 'heading'),
  ('w', 'bold'),
];

final RegExp _reUsed = RegExp(r'var\(--_(r|tw|hw|w)\)');

class Accessible {
  const Accessible({this.accTitle, this.accDescr});
  final String? accTitle;
  final String? accDescr;
}

typedef RootModel = Accessible;

String _fmtDim(double v) => v == v.truncateToDouble() ? '${v.toInt()}' : '$v';

(String?, String?) _extractAcc(Object? acc) {
  if (acc == null) return (null, null);
  if (acc is Accessible) return (acc.accTitle, acc.accDescr);
  if (acc is Map) {
    return (acc['accTitle'] as String?, acc['accDescr'] as String?);
  }
  String? accTitle;
  String? accDescr;
  try {
    accTitle = (acc as dynamic).accTitle as String?;
  } catch (_) {}
  try {
    accDescr = (acc as dynamic).accDescr as String?;
  } catch (_) {}
  return (accTitle, accDescr);
}

String svgDocument(
  String type,
  double width,
  double height,
  double fontSize,
  RenderOptions options,
  Object? acc,
  String content,
) {
  final prefix = esc(options.idPrefix ?? 'pele');
  final head = StringBuffer();
  final aria = StringBuffer();
  final (accTitle, accDescr) = _extractAcc(acc);
  if (accTitle != null && accTitle.isNotEmpty) {
    head.write('<title id="$prefix-title">${escText(accTitle)}</title>');
    aria.write(' aria-labelledby="$prefix-title"');
  }
  if (accDescr != null && accDescr.isNotEmpty) {
    head.write('<desc id="$prefix-desc">${escText(accDescr)}</desc>');
    aria.write(' aria-describedby="$prefix-desc"');
  }
  final fit = options.responsive == false ? '' : 'max-width:100%;height:auto;';
  final used = <String>{};
  for (final m in _reUsed.allMatches(content)) {
    used.add(m.group(1)!);
    if (used.length == 4) break;
  }
  final weights = StringBuffer(used.contains('r') ? ';--_r:$radius' : '');
  for (final (alias, name) in _weights) {
    if (used.contains(alias)) {
      weights.write(';--_$alias:var(--pele-$name-weight,bold)');
    }
  }
  final wStr = _fmtDim(width);
  final hStr = _fmtDim(height);
  return '<svg xmlns="http://www.w3.org/2000/svg" class="pele pele-$type" viewBox="0 0 $wStr $hStr" width="$wStr" height="$hStr" style="$fit$rootStyle$weights${esc(fontStyle(fontSize, options.fontFamily, options.fontFamilyMono))}${paletteStyle()}" fill="var(--_fg)" role="graphics-document document" aria-roledescription="$type"$aria>$head$content</svg>';
}

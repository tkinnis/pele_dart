// Upstream: src/text/label.ts

import 'dart:math' as math;
import 'dart:typed_data';

import '../types.dart';
import '../util/math_js.dart';
import 'entities.dart';
import 'icons.dart';
import 'math.dart';
import 'measurer.dart';

class Span {
  Span({
    required this.text,
    required this.style,
    this.icon,
    this.math,
    required this.width,
  });

  String text;
  int style;
  String? icon;
  MathMarkup? math;
  double width;

  Span copyWith({
    String? text,
    int? style,
    String? icon,
    MathMarkup? math,
    double? width,
  }) => Span(
    text: text ?? this.text,
    style: style ?? this.style,
    icon: icon ?? this.icon,
    math: math ?? this.math,
    width: width ?? this.width,
  );
}

class Label {
  Label({
    required this.lines,
    required this.widths,
    required this.width,
    required this.height,
    required this.size,
    required this.lineHeight,
    this.heights,
  });

  final List<List<Span>> lines;
  final List<double> widths;
  final double width;
  final double height;
  final double size;
  final double lineHeight;
  List<double>? heights;

  Label copyWith({
    List<List<Span>>? lines,
    List<double>? widths,
    double? width,
    double? height,
    double? size,
    double? lineHeight,
    List<double>? heights,
    bool clearHeights = false,
  }) => Label(
    lines: lines ?? this.lines,
    widths: widths ?? this.widths,
    width: width ?? this.width,
    height: height ?? this.height,
    size: size ?? this.size,
    lineHeight: lineHeight ?? this.lineHeight,
    heights: clearHeights ? null : (heights ?? this.heights),
  );
}

const double lineHeightFactor = 1.5;
const double _wrappedLineHeight = 1.3;

final RegExp _reBreak = RegExp(r'<br\s*\/?>|\\n|\n', caseSensitive: false);
final RegExp _reTag = RegExp(r'<\/?([a-zA-Z][\w-]*)(?:\s[^<>]*)?\/?>');
final RegExp _reIcon = RegExp(r'(fa[bklrs]?):fa-([\w-]+)');

bool _isPlainLabel(String raw) {
  final n = raw.length;
  for (var i = 0; i < n; i++) {
    final c = raw.codeUnitAt(i);
    if (c == 0x3c || // <
        c == 0x5c || // \
        c == 0x0a || // \n
        c == 0x2a || // *
        c == 0x5f || // _
        c == 0x26 || // &
        c == 0xfb02) {
      // ﬂ
      return false;
    }
    if (c == 0x3a &&
        i + 3 < n &&
        raw.codeUnitAt(i + 1) == 0x66 &&
        raw.codeUnitAt(i + 2) == 0x61 &&
        raw.codeUnitAt(i + 3) == 0x2d) {
      // :fa-
      return false;
    }
  }
  return true;
}

const Map<String, int> _tagStyles = {
  'b': Style.bold,
  'strong': Style.bold,
  'i': Style.italic,
  'em': Style.italic,
  'cite': Style.italic,
  'dfn': Style.italic,
  'var': Style.italic,
  'code': Style.mono,
  'kbd': Style.mono,
  'samp': Style.mono,
  'tt': Style.mono,
  'sub': Style.sub,
  'sup': Style.sup,
  'u': Style.underline,
  'ins': Style.underline,
};

const int _shift = Style.sub | Style.sup;

final Set<String> _htmlTags =
    ('a abbr address article aside audio b bdi bdo big blockquote body br button caption center cite code col '
            'colgroup data dd del details dfn dialog div dl dt em embed fieldset figcaption figure font footer form h1 h2 '
            'h3 h4 h5 h6 head header hr html i iframe img input ins kbd label legend li link main map mark meta meter nav '
            'noscript object ol optgroup option output p picture pre progress q rp rt ruby s samp script section select '
            'small source span strike strong style sub summary sup table tbody td template textarea tfoot th thead time '
            'title tr track tt u ul var video wbr')
        .split(' ')
        .toSet();

const String _cjk = r'\u2e80-\u9fff\uf900-\ufaff\uff00-\uff60';
const String _close =
    r'、。，．：；！？）］｝」』】〕〉》〙〗ー…‥・ゝゞぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮ,.:;!?)\]}';
const String _open = r'（［｛「『【〔〈《〘〖([{';
final RegExp _reCjk = RegExp('[$_cjk]');
const String _hint = r'\u200b\u00ad';
final RegExp _reHint = RegExp('[$_hint]');
final RegExp _rePiece = RegExp(
  '\\s*(?:[$_open]*[$_cjk][$_close]*|[^\\s$_cjk$_hint]+[$_hint]*[$_close]*|[$_hint]+)\\s*|\\s+',
);

const int _mark = 0xe000;
const int _maxMarks = 0x1900;
final RegExp _reMath = RegExp(r'\$\$(.+?)\$\$');
final RegExp _reMark = RegExp(r'[\ue000-\uf8ff]');
final RegExp _reCrLf = RegExp(r'\r\n?');

bool _isWordCode(int c) =>
    (c >= 0x61 && c <= 0x7a) ||
    (c >= 0x41 && c <= 0x5a) ||
    (c >= 0x30 && c <= 0x39) ||
    c == 0x5f;

bool _isAsciiWs(int c) => c == 0x20 || (c >= 0x09 && c <= 0x0d);

bool _isSimpleWrapText(String s) {
  final n = s.length;
  for (var i = 0; i < n; i++) {
    final c = s.codeUnitAt(i);
    if (c >= 0x2000 || c == 0x00ad || c == 0x00a0 || c == 0x1680) {
      return false;
    }
  }
  return true;
}

List<String> _splitSimplePieces(String s) {
  final n = s.length;
  if (n == 0) return const <String>[];
  final out = <String>[];
  var i = 0;
  while (i < n) {
    final start = i;
    while (i < n && _isAsciiWs(s.codeUnitAt(i))) {
      i++;
    }
    if (i >= n) {
      out.add(s.substring(start, n));
      break;
    }
    while (i < n && !_isAsciiWs(s.codeUnitAt(i))) {
      i++;
    }
    while (i < n && _isAsciiWs(s.codeUnitAt(i))) {
      i++;
    }
    out.add(s.substring(start, i));
  }
  return out;
}

class _Marks {
  _Marks();
  final List<String> tex = <String>[];
  final List<MathMarkup?> math = <MathMarkup?>[];
}

_Marks? _marks;

final Label _empty = Label(
  lines: const [],
  widths: const [],
  width: 0,
  height: 0,
  size: 0,
  lineHeight: 0,
);

String _dedent(String text) {
  final lines = text.split('\n');
  var min = 1 << 30;
  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    final indent = line.length - line.trimLeft().length;
    if (indent < min) min = indent;
  }
  if (min == (1 << 30) || min == 0) return text;
  return lines
      .map(
        (line) =>
            line.substring(math.min(min, line.length - line.trimLeft().length)),
      )
      .join('\n');
}

bool _plain(Span? span) {
  return span != null && span.icon == null && span.math == null;
}

void _pushText(List<Span> line, String text, int style) {
  if (text.isEmpty) return;
  if (_marks != null && _reMark.hasMatch(text)) {
    final found = _marks!;
    var last = 0;
    for (final m in _reMark.allMatches(text)) {
      if (m.start > last) {
        _pushPlain(line, text.substring(last, m.start), style);
      }
      final at = text.codeUnitAt(m.start) - _mark;
      final math = found.math[at];
      if (math != null) {
        line.add(Span(text: '', style: style, math: math, width: math.width));
      } else {
        _pushPlain(line, '\$\$${found.tex[at]}\$\$', style);
      }
      last = m.end;
    }
    if (last < text.length) {
      _pushPlain(line, text.substring(last), style);
    }
    return;
  }
  _pushPlain(line, text, style);
}

void _pushPlain(List<Span> line, String text, int style) {
  final decoded = decodeEntities(text);
  final last = line.isNotEmpty ? line.last : null;
  if (_plain(last) && last!.style == style) {
    last.text += decoded;
  } else {
    line.add(Span(text: decoded, style: style, width: 0));
  }
}

void _pushIcons(List<Span> line, String text, int style) {
  if (!text.contains(':fa-')) {
    _pushText(line, text, style);
    return;
  }
  var last = 0;
  for (final m in _reIcon.allMatches(text)) {
    final icon = '${m.group(1)}:fa-${m.group(2)}';
    _pushText(line, text.substring(last, m.start), style);
    last = m.end;
    if (iconMarkup(icon).isNotEmpty) {
      line.add(Span(text: '', style: style, icon: icon, width: 0));
    } else if (charAtOrNull(text, last) == ' ') {
      last++;
    } else if (last == text.length) {
      final before = line.isNotEmpty ? line.last : null;
      if (_plain(before)) {
        before!.text = before.text.trimRight();
      }
    }
  }
  _pushText(line, text.substring(last), style);
}

class _Open {
  _Open({required this.style});
  int style;
  final List<int> shifts = <int>[];
}

void _inline(
  List<Span> line,
  String source,
  bool markdown,
  int base,
  _Open open,
) {
  var style = open.style;
  var marked = 0;
  final text = StringBuffer();
  var i = 0;
  var chunkStart = 0;
  final n = source.length;

  void sync(int upTo) {
    if (upTo > chunkStart) {
      text.write(source.substring(chunkStart, upTo));
    }
    chunkStart = upTo;
  }

  void flush(int upTo) {
    sync(upTo);
    if (text.isNotEmpty) {
      _pushIcons(
        line,
        text.toString(),
        style | (open.shifts.isNotEmpty ? open.shifts.last : 0),
      );
      text.clear();
    }
  }

  while (i < n) {
    final c = source.codeUnitAt(i);
    if (c == 0x3c) {
      final m = execSticky(_reTag, source, i);
      if (m != null && m.start == i) {
        final tag = m.group(1)!.toLowerCase();
        final closing = i + 1 < n && source.codeUnitAt(i + 1) == 0x2f;
        final bit = _tagStyles[tag] ?? 0;
        if ((bit & _shift) != 0) {
          flush(i);
          final at = open.shifts.lastIndexOf(bit);
          if (!closing) {
            open.shifts.add(bit);
          } else if (at != -1) {
            open.shifts.removeAt(at);
          }
        } else if (bit != 0) {
          flush(i);
          open.style = closing
              ? (open.style & ~bit) | (base & bit)
              : open.style | bit;
          style = closing ? (style & ~bit) | (base & bit) : style | bit;
        }
        if (bit != 0 || _htmlTags.contains(tag)) {
          sync(i);
          i = m.end;
          chunkStart = i;
          continue;
        }
      }
    } else if (markdown && (c == 0x2a || c == 0x5f)) {
      final doubleMarker = i + 1 < n && source.codeUnitAt(i + 1) == c;
      final bit = doubleMarker ? Style.bold : Style.italic;
      final len = doubleMarker ? 2 : 1;
      final isOpen = (marked & bit) == 0;
      final prevCode = i > 0 ? source.codeUnitAt(i - 1) : 0x20;
      final nextCode = i + len < n ? source.codeUnitAt(i + len) : 0x20;
      final prevNotWs = i > 0 && source[i - 1].trim().isNotEmpty;
      final nextNotWs = i + len < n && source[i + len].trim().isNotEmpty;
      final markerStr = c == 0x2a
          ? (doubleMarker ? '**' : '*')
          : (doubleMarker ? '__' : '_');
      final canOpen =
          isOpen && nextNotWs && source.indexOf(markerStr, i + len) != -1;
      final canClose = !isOpen && prevNotWs;
      final wordy = c == 0x5f && _isWordCode(prevCode) && _isWordCode(nextCode);
      if ((canOpen || canClose) && !wordy) {
        flush(i);
        marked = canOpen ? marked | bit : marked & ~bit;
        style = canOpen ? style | bit : (style & ~bit) | (base & bit);
        i += len;
        chunkStart = i;
        continue;
      }
    }
    i++;
  }
  if (chunkStart == 0) {
    if (n > 0) {
      _pushIcons(
        line,
        source,
        style | (open.shifts.isNotEmpty ? open.shifts.last : 0),
      );
    }
  } else {
    flush(n);
  }
}

double _measureSpans(List<Span> line, TextMeasurer measurer, double size) {
  var total = 0.0;
  for (final span in line) {
    span.width = span.icon != null
        ? size * 1.25
        : (span.math != null
              ? span.math!.width
              : measurer.width(span.text, size, span.style));
    total += span.width;
  }
  return total;
}

void _wrap(
  List<Span> line,
  TextMeasurer measurer,
  double size,
  double max,
  List<List<Span>> out,
  List<double> widths,
) {
  var current = <Span>[];
  var width = 0.0;
  void commit([bool hyphen = false]) {
    final last = current.isNotEmpty ? current.last : null;
    if (_plain(last)) {
      var trimmed = last!.text.trimRight();
      if (hyphen && last.text.endsWith('\u00ad')) {
        trimmed = '${trimmed.substring(0, trimmed.length - 1)}-';
      }
      if (trimmed != last.text) {
        last.text = trimmed;
        final w = measurer.width(trimmed, size, last.style);
        width += w - last.width;
        last.width = w;
      }
    }
    out.add(current);
    widths.add(width);
    current = <Span>[];
    width = 0.0;
  }

  for (final span in line) {
    if (span.icon != null || span.math != null) {
      final w = span.math != null ? span.math!.width : size * 1.25;
      if (width > 0 && width + w > max) commit();
      current.add(span.copyWith(width: w));
      width += w;
      continue;
    }
    final simple = _isSimpleWrapText(span.text);
    final pieces = simple
        ? _splitSimplePieces(span.text)
        : [for (final m in _rePiece.allMatches(span.text)) m.group(0)!];
    final soft = !simple && span.text.contains('\u00ad');
    Float64List? own;
    Float64List? rest;
    if (soft) {
      final n = pieces.length;
      own = Float64List(n);
      rest = Float64List(n + 1);
      for (var q = n - 1; q >= 0; q--) {
        final shy = pieces[q].endsWith('\u00ad');
        final end = pieces[q].trimRight();
        own[q] = measurer.width(
          shy ? end.substring(0, end.length - 1) : end,
          size,
          span.style,
        );
        rest[q] = !shy
            ? own[q]
            : (q == n - 1
                  ? (identical(span, line.last) ? own[q] : double.infinity)
                  : own[q] + rest[q + 1]);
      }
    }
    for (var p = 0; p < pieces.length; p++) {
      var part = pieces[p];
      final trimmedRight = soft ? part : part.trimRight();
      final partWidth = soft
          ? own![p]
          : measurer.width(trimmedRight, size, span.style);
      final fits = !soft || !part.endsWith('\u00ad')
          ? width + partWidth <= max
          : (width +
                        measurer.width(
                          '${part.substring(0, part.length - 1)}-',
                          size,
                          span.style,
                        ) <=
                    max ||
                width + rest![p] <= max);
      if (width > 0 && !fits) {
        final trimmedLeft = part.trimLeft();
        commit(trimmedLeft.length == part.length);
        part = trimmedLeft;
      }
      final last = current.isNotEmpty ? current.last : null;
      if (_plain(last) && last!.style == span.style) {
        last.text += part;
        if (partWidth > 0 ||
            (soft
                ? part.trimRight() != part
                : trimmedRight.length != part.length)) {
          final before = last.width;
          last.width = measurer.width(last.text, size, last.style);
          width += last.width - before;
        }
      } else {
        final w = (!soft && trimmedRight.length == part.length)
            ? partWidth
            : measurer.width(part, size, span.style);
        current.add(Span(text: part, style: span.style, width: w));
        width += w;
      }
    }
  }
  if (current.isNotEmpty || out.isEmpty) commit();
}

Label layoutLabel(
  String? raw,
  bool markdown,
  TextMeasurer measurer,
  double size,
  double maxWidth, [
  int base = 0,
]) {
  if (raw == null || raw.isEmpty) return _empty;
  final lineHeight = roundJs(size * lineHeightFactor).toDouble();

  if (mathActive() && raw.contains('\$\$') && !_reMark.hasMatch(raw)) {
    final found = _Marks();
    final marked = raw.replaceAllMapped(_reMath, (m) {
      if (found.tex.length == _maxMarks) return m.group(0)!;
      found.tex.add(m.group(1)!);
      return String.fromCharCode(_mark + found.tex.length - 1);
    });
    if (found.tex.isNotEmpty) {
      for (final tex in found.tex) {
        found.math.add(typeset(decodeEntities(tex), size));
      }
      return _layoutMarkup(
        marked,
        markdown,
        measurer,
        size,
        maxWidth,
        base,
        lineHeight,
        found,
      );
    }
  }

  if (_isPlainLabel(raw)) {
    final text = raw.trim();
    final width = measurer.width(text, size, base);
    if (width <= maxWidth ||
        (!text.contains(' ') &&
            (_isSimpleWrapText(text) ||
                (!_reCjk.hasMatch(text) && !_reHint.hasMatch(text))))) {
      return Label(
        lines: [
          [Span(text: text, style: base, width: width)],
        ],
        widths: [width],
        width: width,
        height: lineHeight,
        size: size,
        lineHeight: lineHeight,
      );
    }
    final lines = <List<Span>>[];
    final widths = <double>[];
    _wrap(
      [Span(text: text, style: base, width: width)],
      measurer,
      size,
      maxWidth,
      lines,
      widths,
    );
    var widest = 0.0;
    for (final w in widths) {
      if (w > widest) widest = w;
    }
    final snug = lines.length > 1
        ? roundJs(size * _wrappedLineHeight).toDouble()
        : lineHeight;
    return Label(
      lines: lines,
      widths: widths,
      width: widest,
      height: lines.length * snug,
      size: size,
      lineHeight: snug,
    );
  }
  return _layoutMarkup(
    raw,
    markdown,
    measurer,
    size,
    maxWidth,
    base,
    lineHeight,
  );
}

Label _layoutMarkup(
  String raw,
  bool markdown,
  TextMeasurer measurer,
  double size,
  double maxWidth,
  int base,
  double lineHeight, [
  _Marks? found,
]) {
  final outer = _marks;
  _marks = found;
  try {
    final label = _layoutLines(
      raw,
      markdown,
      measurer,
      size,
      maxWidth,
      base,
      lineHeight,
    );
    return found != null ? withHeights(label) : label;
  } finally {
    _marks = outer;
  }
}

Label _layoutLines(
  String raw,
  bool markdown,
  TextMeasurer measurer,
  double size,
  double maxWidth,
  int base,
  double lineHeight,
) {
  final source = markdown
      ? _dedent(raw.replaceAll(_reCrLf, '\n')).trim()
      : raw.trim();
  final lines = <List<Span>>[];
  final widths = <double>[];
  var width = 0.0;
  final open = _Open(style: base);
  for (final part in source.split(_reBreak)) {
    final line = <Span>[];
    _inline(line, part.trim(), markdown, base, open);
    final w = _measureSpans(line, measurer, size);
    if (w > maxWidth) {
      _wrap(line, measurer, size, maxWidth, lines, widths);
    } else {
      lines.add(line);
      widths.add(w);
    }
  }
  for (final w in widths) {
    if (w > width) width = w;
  }
  final snug = lines.length > 1
      ? roundJs(size * _wrappedLineHeight).toDouble()
      : lineHeight;
  return Label(
    lines: lines,
    widths: widths,
    width: width,
    height: lines.length * snug,
    size: size,
    lineHeight: snug,
  );
}

Label withHeights(Label label) {
  List<double>? heights;
  for (var i = 0; i < label.lines.length; i++) {
    var h = label.lineHeight;
    for (final span in label.lines[i]) {
      if (span.math != null) {
        h = math.max(h, (span.math!.height + label.size / 4).ceilToDouble());
      }
    }
    if (h != label.lineHeight && heights == null) {
      heights = List<double>.filled(label.lines.length, label.lineHeight);
    }
    if (heights != null) heights[i] = h;
  }
  if (heights == null) {
    return label.heights == null
        ? label
        : label.copyWith(
            clearHeights: true,
            height: label.lines.length * label.lineHeight,
          );
  }
  var height = 0.0;
  for (final h in heights) {
    height += h;
  }
  return label.copyWith(heights: heights, height: height);
}

bool hasMath(List<Span> line) {
  for (final span in line) {
    if (span.math != null) return true;
  }
  return false;
}

double lineMiddle(Label label, int i) {
  final heights = label.heights;
  if (heights == null) return (i + 0.5) * label.lineHeight;
  var top = 0.0;
  for (var k = 0; k < i; k++) {
    top += heights[k];
  }
  return top + heights[i] / 2;
}

Label labelLine(Label label, int i) {
  final width = label.widths[i];
  final height = label.heights != null ? label.heights![i] : label.lineHeight;
  return Label(
    lines: [label.lines[i]],
    widths: [width],
    width: width,
    height: height,
    size: label.size,
    lineHeight: label.lineHeight,
    heights: height != label.lineHeight ? [height] : null,
  );
}

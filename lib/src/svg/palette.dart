// Upstream: src/svg/palette.ts

import '../detect.dart';
import '../preprocess.dart';
import 'builder.dart';
import 'ink.dart';

const Map<DiagramType, ({String prefix, int first, bool repeat})> _palettes = {
  'pie': (prefix: 'pie', first: 1, repeat: false),
  'gitGraph': (prefix: 'git', first: 0, repeat: false),
  'timeline': (prefix: 'cScale', first: 0, repeat: false),
  'radar': (prefix: 'cScale', first: 0, repeat: false),
  'treemap': (prefix: 'cScale', first: 0, repeat: false),
  'mindmap': (prefix: 'cScale', first: 1, repeat: false),
  'venn': (prefix: 'venn', first: 1, repeat: true),
};

const int _slots = 8;
final RegExp _reChars = RegExp(r'^[\w\s#%.,+\-/()]{1,200}$');
final RegExp _reFunction = RegExp(r'([\w-]*)\s*\(');
final RegExp _reVar = RegExp(r'var\(\s*([\w-]*)', caseSensitive: false);
const Set<String> _functions = {
  'rgb',
  'rgba',
  'hsl',
  'hsla',
  'hwb',
  'lab',
  'lch',
  'oklab',
  'oklch',
  'color',
  'color-mix',
  'light-dark',
  'var',
};

Config _record(Object? value) => asConfig(value);

String? _safeColor(Object? value) {
  if (value is! String) return null;
  final color = value.trim();
  if (!_reChars.hasMatch(color)) return null;
  if (!color.contains('(')) return plainColor(color) ? color : null;
  var depth = 0;
  for (var i = 0; i < color.length; i++) {
    final char = color[i];
    if (char == '(') {
      depth++;
    } else if (char == ')' && --depth < 0) {
      return null;
    }
  }
  if (depth != 0) return null;
  for (final m in _reFunction.allMatches(color)) {
    final name = (m.group(1) ?? '').toLowerCase();
    if (!_functions.contains(name)) return null;
  }
  for (final m in _reVar.allMatches(color)) {
    final name = m.group(1) ?? '';
    if (!name.startsWith('--pele-')) return null;
  }
  return color;
}

List<String> _splitList(String value) {
  final parts = <String>[];
  var depth = 0;
  var start = 0;
  for (var i = 0; i < value.length; i++) {
    final char = value[i];
    if (char == '(') {
      depth++;
    } else if (char == ')') {
      depth--;
    } else if (char == ',' && depth == 0) {
      parts.add(value.substring(start, i));
      start = i + 1;
    }
  }
  parts.add(value.substring(start));
  return parts.map((part) => part.trim()).toList();
}

({List<Object?> list, bool repeat})? _entries(DiagramType type, Config vars) {
  if (type == 'xychart') {
    final list = _record(vars['xyChart'])['plotColorPalette'];
    return list is String ? (list: _splitList(list), repeat: true) : null;
  }
  final pal = _palettes[type];
  if (pal == null) return null;
  var list = <Object?>[
    for (var i = 0; i < _slots; i++) vars['${pal.prefix}${pal.first + i}'],
  ];
  if (pal.repeat) {
    list = list.where((value) => value != null && value != '').toList();
  }
  return (list: list, repeat: pal.repeat);
}

class Palette {
  const Palette({required this.style, required this.inks});
  final String style;
  final List<String?> inks;
}

const Palette _none = Palette(style: '', inks: []);

Palette palette(DiagramType type, Config config) {
  final found = _entries(type, _record(config['themeVariables']));
  if (found == null || found.list.isEmpty) return _none;
  final (:list, :repeat) = found;
  final style = StringBuffer();
  final inks = List<String?>.filled(_slots, null);
  for (var i = 0; i < _slots; i++) {
    if (!repeat && i >= list.length) break;
    final color = _safeColor(list[i % list.length]);
    if (color == null) continue;
    style.write(';--pele-series-${i + 1}:$color');
    inks[i] = ink(';fill:$color');
  }
  final s = style.toString();
  return s.isEmpty ? _none : Palette(style: esc(s), inks: inks);
}

Palette _current = _none;

T withPalette<T>(Palette next, T Function() run) {
  final outer = _current;
  _current = next;
  try {
    return run();
  } finally {
    _current = outer;
  }
}

String paletteStyle() => _current.style;

String seriesInkFill(int index) {
  final idx = ((index % _slots) + _slots) % _slots;
  final color = idx < _current.inks.length ? _current.inks[idx] : null;
  return color != null && color.isNotEmpty ? ' fill="$color"' : '';
}

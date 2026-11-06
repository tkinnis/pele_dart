// Upstream: src/preprocess.ts

import 'dart:convert';

import 'errors.dart';
import 'util/chars.dart' as chars;
import 'util/yaml.dart';

/// Parsed Mermaid configuration map extracted from YAML frontmatter,
/// `%%{init: ...}%%` directives, or passed via `RenderOptions.config`.
typedef Config = Map<String, YamlValue>;

class Preprocessed {
  const Preprocessed({
    required this.text,
    required this.title,
    required this.config,
    required this.withComments,
    required this.lineOffset,
  });

  final String text;
  final String? title;
  final Config config;
  final String withComments;
  final int lineOffset;
}

final RegExp _reComment = RegExp(r'^\s*%%(?!{)[^\n]+\n?', multiLine: true);
final RegExp _reDirective = RegExp(
  r'%{2}\{\s*(?:(\w+)\s*:|(\w+))\s*(?:(\w+)|((?:(?!\}%{2}).|\r?\n)*))?\s*(?:\}%{2})?',
  caseSensitive: false,
);
final RegExp _reHtmlTag = RegExp(r'<(\w+)([^>]*)>');
final RegExp _reAttr = RegExp(r'="([^"]*)"');
final RegExp _reCrLf = RegExp(r'\r\n?');
const Set<String> _unsafeKeys = {'__proto__', 'constructor', 'prototype'};

String _removeAll(String text, RegExp re, List<List<Edit>>? steps) {
  steps?.add(replacements(text, re, 0));
  return text.replaceAll(re, '');
}

String _stripCommentLines(String text) {
  final n = text.length;
  StringBuffer? out;
  var kept = 0;
  var wsLineStart = 0;
  while (wsLineStart < n) {
    var p = wsLineStart;
    while (p < n && chars.isSpace(text.codeUnitAt(p))) {
      p++;
    }
    if (p >= n) break;
    final nl = text.indexOf('\n', p);
    final lineEnd = nl == -1 ? n : nl;
    if (p + 2 < lineEnd &&
        text.codeUnitAt(p) == 0x25 &&
        text.codeUnitAt(p + 1) == 0x25 &&
        text.codeUnitAt(p + 2) != 0x7b) {
      out ??= StringBuffer();
      if (wsLineStart > kept) {
        out.write(text.substring(kept, wsLineStart));
      }
      final cutEnd = nl == -1 ? n : nl + 1;
      kept = cutEnd;
      wsLineStart = cutEnd;
    } else {
      if (nl == -1) break;
      wsLineStart = nl + 1;
    }
  }
  if (out == null) return text;
  if (kept < n) out.write(text.substring(kept, n));
  return out.toString();
}

String cleanupComments(String text, [List<List<Edit>>? steps]) {
  if (text.contains('%%')) {
    if (steps == null && !text.contains('\r')) {
      return _stripCommentLines(text).trimLeft();
    }
    text = _removeAll(text, _reComment, steps);
  }
  final trimmed = text.trimLeft();
  steps?.add([(0, text.length - trimmed.length, 0)]);
  return trimmed;
}

String normalizeLineBreaks(String text) {
  return text.contains('\r') ? text.replaceAll(_reCrLf, '\n') : text;
}

bool _isLineBreakCode(int c) {
  return c == 0x0a || c == 0x0d;
}

class _FrontMatter {
  const _FrontMatter({
    required this.indent,
    required this.body,
    required this.length,
  });

  final String indent;
  final String body;
  final int length;
}

_FrontMatter? _matchFrontMatter(String text) {
  var cursor = 0;
  while (cursor < text.length &&
      chars.isSpace(text.codeUnitAt(cursor)) &&
      !_isLineBreakCode(text.codeUnitAt(cursor))) {
    cursor++;
  }
  final indent = text.substring(0, cursor);
  if (!text.startsWith('---', cursor)) return null;

  final openingEnds = <int>[];
  for (
    var i = cursor + 3;
    i < text.length && chars.isSpace(text.codeUnitAt(i));
    i++
  ) {
    if (_isLineBreakCode(text.codeUnitAt(i))) openingEnds.add(i);
  }
  if (openingEnds.isEmpty) return null;

  final fence = '$indent---';
  int closingEnd(int i) {
    if (!_isLineBreakCode(text.codeUnitAt(i)) ||
        !text.startsWith(fence, i + 1)) {
      return -1;
    }
    var last = -1;
    for (
      var j = i + 1 + fence.length;
      j < text.length && chars.isSpace(text.codeUnitAt(j));
      j++
    ) {
      if (_isLineBreakCode(text.codeUnitAt(j))) last = j;
    }
    return last;
  }

  final needle = '\n$fence';
  var lastFence = -1;
  for (
    var i = text.lastIndexOf(needle);
    i > openingEnds[0];
    i = text.lastIndexOf(needle, i - 1)
  ) {
    if (closingEnd(i) != -1) {
      lastFence = i;
      break;
    }
  }
  if (lastFence == -1) return null;

  var openingEnd = openingEnds[0];
  for (final candidate in openingEnds) {
    if (candidate < lastFence) openingEnd = candidate;
  }

  final bodyStart = openingEnd + 1;
  final firstAt = bodyStart > 0 ? bodyStart - 1 : 0;
  for (
    var i = text.indexOf(needle, firstAt);
    i != -1 && i <= lastFence;
    i = text.indexOf(needle, i + 1)
  ) {
    if (i < bodyStart) continue;
    final end = closingEnd(i);
    if (end != -1) {
      return _FrontMatter(
        indent: indent,
        body: text.substring(bodyStart, i),
        length: end + 1,
      );
    }
  }
  return null;
}

bool isRecord(Object? value) {
  return value is Map;
}

Config asConfig(Object? value) {
  if (value is Config) return value;
  if (value is Map) {
    return {for (final entry in value.entries) '${entry.key}': entry.value};
  }
  return <String, YamlValue>{};
}

Config _merge(Config target, Map<Object?, Object?> source) {
  for (final entry in source.entries) {
    final key = '${entry.key}';
    if (_unsafeKeys.contains(key)) continue;
    final value = entry.value;
    final current = target[key];
    if (value is Map && current is Map) {
      final merged = asConfig(current);
      target[key] = _merge(merged, value);
    } else if (value is Map) {
      target[key] = _merge(<String, YamlValue>{}, value);
    } else {
      target[key] = value;
    }
  }
  return target;
}

String _directives(String text, Config config, List<List<Edit>>? steps) {
  if (!text.contains('%%{')) return text;
  final normalized = text.trim().replaceAll("'", '"');
  for (final match in _reDirective.allMatches(normalized)) {
    final type = match.group(1) ?? match.group(2);
    if (type == 'wrap') {
      config['wrap'] = true;
    } else if ((type == 'init' || type == 'initialize') &&
        match.group(4) != null &&
        match.group(4)!.isNotEmpty) {
      try {
        final args = jsonDecode(match.group(4)!.trim());
        if (args is Map) {
          _merge(config, args);
        }
      } catch (_) {
        // Mermaid ignores an init directive whose body is not valid JSON.
      }
    }
  }
  return _removeAll(text, _reDirective, steps);
}

Preprocessed preprocess(String source, [List<List<Edit>>? steps]) {
  var hasCr = false;
  var hasLt = false;
  var hasEqQuote = false;
  var hasComment = false;
  var hasDirective = false;
  for (var i = 0, n = source.length; i < n; i++) {
    final c = source.codeUnitAt(i);
    if (c == 0x0d) {
      hasCr = true;
    } else if (c == 0x3c) {
      hasLt = true;
    } else if (c == 0x3d && i + 1 < n && source.codeUnitAt(i + 1) == 0x22) {
      hasEqQuote = true;
    } else if (c == 0x25 && i + 1 < n && source.codeUnitAt(i + 1) == 0x25) {
      hasComment = true;
      if (i + 2 < n && source.codeUnitAt(i + 2) == 0x7b) {
        hasDirective = true;
      }
    }
  }
  var text = hasCr ? source.replaceAll(_reCrLf, '\n') : source;
  final lastClose = hasLt && hasEqQuote ? text.lastIndexOf('>') : -1;
  if (lastClose > 0) {
    text =
        text
            .substring(0, lastClose + 1)
            .replaceAllMapped(
              _reHtmlTag,
              (m) =>
                  '<${m.group(1)}${m.group(2)!.replaceAllMapped(_reAttr, (a) => "='${a.group(1)}'")} >'
                      .replaceFirst(' >', '>'),
            ) +
        text.substring(lastClose + 1);
  }

  final config = <String, YamlValue>{};
  String? title;
  var lineOffset = 0;

  final front = _matchFrontMatter(text);
  if (front != null) {
    final body = front.indent.isNotEmpty
        ? front.body
              .split('\n')
              .map(
                (line) => line.startsWith(front.indent)
                    ? line.substring(front.indent.length)
                    : line,
              )
              .join('\n')
        : front.body;
    YamlValue parsed;
    try {
      parsed = parseYaml(body);
    } catch (error) {
      final msg = error is StateError ? error.message : '$error';
      throw PeleError('Front matter is not valid YAML. $msg', 'syntax');
    }
    if (parsed is Map) {
      final t = parsed['title'];
      if (t != null && '$t'.isNotEmpty && t != false) {
        title = '$t';
      }
      if (parsed['config'] is Map) {
        _merge(config, parsed['config'] as Map);
      }
      final dm = parsed['displayMode'];
      if (dm != null && '$dm'.isNotEmpty && dm != false) {
        final gantt = config['gantt'] is Map
            ? asConfig(config['gantt'])
            : <String, YamlValue>{};
        config['gantt'] = gantt;
        gantt['displayMode'] = '$dm';
      }
    }
    for (
      var i = text.indexOf('\n');
      i != -1 && i < front.length;
      i = text.indexOf('\n', i + 1)
    ) {
      lineOffset++;
    }
    text = text.substring(front.length);
    steps?.add([(0, front.length, 0)]);
  }

  if (hasDirective) {
    text = _directives(text, config, steps);
  }
  final cleaned = hasComment ? _stripCommentLines(text) : text;
  return Preprocessed(
    text: cleaned.trimLeft(),
    title: title,
    config: config,
    withComments: text,
    lineOffset: lineOffset,
  );
}

final RegExp _reEntity = RegExp(r'#\w+;');
final RegExp _reInt = RegExp(r'^\+?\d+$');

List<Edit>? _recording(List<List<Edit>>? steps) {
  if (steps == null) return null;
  final edits = <Edit>[];
  steps.add(edits);
  return edits;
}

String _dropColorSemicolons(
  String text,
  String keyword,
  List<List<Edit>>? steps,
) {
  final edits = _recording(steps);
  var from = text.indexOf(keyword);
  if (from == -1) return text;
  final out = StringBuffer();
  var last = 0;
  while (from != -1) {
    var lineEnd = from + keyword.length;
    while (lineEnd < text.length &&
        !chars.isLineEnd(text.codeUnitAt(lineEnd))) {
      lineEnd++;
    }
    var afterColon = false;
    var hash = -1;
    for (var j = from + keyword.length; j < lineEnd; j++) {
      final c = text.codeUnitAt(j);
      if (c == 58) {
        afterColon = true;
      } else if (c == 35) {
        if (afterColon) {
          hash = j;
          break;
        }
      } else if (chars.isSpace(c)) {
        afterColon = false;
      }
    }
    if (hash != -1) {
      final semi = text.lastIndexOf(';', lineEnd - 1);
      if (semi > hash) {
        edits?.add((semi, semi + 1, 0));
        out.write(text.substring(last, semi));
        last = semi + 1;
      }
    }
    from = lineEnd >= text.length ? -1 : text.indexOf(keyword, lineEnd + 1);
  }
  if (last == 0) return text;
  out.write(text.substring(last));
  return out.toString();
}

String encodeEntities(String text, [List<List<Edit>>? steps]) {
  if (!text.contains('#')) return text;
  text = _dropColorSemicolons(
    _dropColorSemicolons(text, 'style', steps),
    'classDef',
    steps,
  );
  final edits = _recording(steps);
  StringBuffer? out;
  var last = 0;
  for (final m in _reEntity.allMatches(text)) {
    (out ??= StringBuffer()).write(text.substring(last, m.start));
    final s = m.group(0)!;
    final inner = s.substring(1, s.length - 1);
    final code = '${_reInt.hasMatch(inner) ? 'ﬂ°°' : 'ﬂ°'}$inner¶ß';
    edits?.add((m.start, m.end, code.length));
    out.write(code);
    last = m.end;
  }
  if (out == null) return text;
  out.write(text.substring(last));
  return out.toString();
}

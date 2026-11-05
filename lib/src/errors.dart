// Upstream: src/errors.ts

import 'dart:math' as math;

typedef PeleErrorCode = String;

class PeleError implements Exception {
  PeleError(
    this.message, [
    this.code = 'syntax',
    PeleErrorInfo info = const PeleErrorInfo(),
  ]) : type = info.type,
       mermaidType = info.mermaidType,
       line = info.line ?? 0,
       column = info.column ?? 0,
       snippet = info.snippet ?? '';

  String message;
  final String name = 'PeleError';
  final PeleErrorCode code;
  String? type;
  String? mermaidType;
  int line;
  int column;
  String snippet;

  @override
  String toString() => 'PeleError: $message';
}

class PeleErrorInfo {
  const PeleErrorInfo({
    this.type,
    this.mermaidType,
    this.line,
    this.column,
    this.snippet,
  });

  final String? type;
  final String? mermaidType;
  final int? line;
  final int? column;
  final String? snippet;
}

/// Input range `[from, to)` replaced by `length` output characters.
typedef Edit = (int from, int to, int length);

List<Edit> replacements(String text, RegExp re, int length) {
  return [
    for (final match in re.allMatches(text)) (match.start, match.end, length),
  ];
}

int _stepInput(List<Edit> edits, int at) {
  var shift = 0;
  for (final (from, to, length) in edits) {
    final start = from - shift;
    if (at < start) break;
    if (at < start + length) {
      return from + math.min(at - start, to - from - 1);
    }
    shift += to - from - length;
  }
  return at + shift;
}

int inputOffset(List<List<Edit>> steps, int at) {
  for (var s = steps.length - 1; s >= 0; s--) {
    at = _stepInput(steps[s], at);
  }
  return at;
}

class Origin {
  const Origin({required this.parsed, required this.find});
  final String parsed;
  final (String source, int offset) Function(int offset) find;
}

Origin? _origin;

/// Report positions in the original source while [run] parses.
T locatingIn<T>(Origin next, T Function() run) {
  final outer = _origin;
  _origin = next;
  try {
    return run();
  } finally {
    _origin = outer;
  }
}

/// Maps only when [src] is exactly the text being parsed.
(String source, int offset) written(String src, int offset) {
  return _origin != null && src == _origin!.parsed
      ? _origin!.find(offset)
      : (src, offset);
}

({int line, int column, String snippet}) locate(String src, int offset) {
  final end = src.trimRight().length;
  if (end > 0 && offset >= end) {
    (src, offset) = written(src, end - 1);
    offset++;
  } else {
    (src, offset) = written(src, offset);
  }
  if (offset < 0) offset = 0;
  if (offset > src.length) offset = src.length;
  var line = 1;
  var lineStart = 0;
  for (
    var i = src.indexOf('\n');
    i != -1 && i < offset;
    i = src.indexOf('\n', i + 1)
  ) {
    line++;
    lineStart = i + 1;
  }
  var lineEnd = src.indexOf('\n', offset);
  if (lineEnd == -1) lineEnd = src.length;
  final column = math.max(1, offset - lineStart + 1);
  final text = src.substring(lineStart, lineEnd);
  return (line: line, column: column, snippet: '$text\n${'-' * (column - 1)}^');
}

PeleError syntaxError(
  String type,
  String src,
  int offset,
  String detail, [
  bool lexical = false,
]) {
  final loc = locate(src, offset);
  final head = lexical
      ? 'Lexical error on line ${loc.line}. Unrecognized text.'
      : 'Parse error on line ${loc.line}:';
  final message = lexical
      ? '$head\n${loc.snippet}'
      : '$head\n${loc.snippet}\n$detail';
  return PeleError(
    message,
    'syntax',
    PeleErrorInfo(
      type: type,
      line: loc.line,
      column: loc.column,
      snippet: loc.snippet,
    ),
  );
}

// Upstream: src/diagrams/treeview/boxDrawing.ts

import 'dart:math' as math;

import '../../errors.dart';
import '../../util/math_js.dart';

// Mermaid's box-drawing preprocessor: turns `├──`, `└──`, `│` (and the heavy variants) into the
// indentation the grammar reads.

final RegExp _allBoxChars = RegExp(r'[─━│┃└┗├┣]');
final RegExp _branchChar = RegExp(r'[└┗├┣]');
final RegExp _dashChar = RegExp(r'[─━]');
final RegExp _decorationOnly = RegExp(r'^[\s│┃]+$');
final RegExp _boxOnly = RegExp(r'^[\s─━│┃└┗├┣]+$');
final RegExp _metadataLine = RegExp(
  r'^\s*(title[\t ]|accTitle[\t ]*:|accDescr[\t ]*[:{])',
);
final RegExp _commentLine = RegExp(r'^\s*%%');
final RegExp _leadWhitespace = RegExp(r'^\s+');
final RegExp _lineWordRe = RegExp(r'\bline\s+(\d+)\b', caseSensitive: false);
const String _indentUnit = '    ';

class PreprocessResult {
  final String text;
  // Output line number to original line number, both from 1. Empty when the text is unchanged.
  final Map<int, int> lineMap;
  // Per output line, maps rewritten indices to original indices.
  final Map<int, int Function(int at)> columns;

  const PreprocessResult({
    required this.text,
    required this.lineMap,
    required this.columns,
  });
}

bool isBoxDrawingFormat(List<String> lines) {
  return lines.any((line) => _allBoxChars.hasMatch(line));
}

int _inferSegmentWidth(List<String> contentLines) {
  for (final line in contentLines) {
    final match = _branchChar.firstMatch(line);
    if (match != null && match.start > 0) return match.start;
  }
  return 4;
}

String remapErrorLines(String message, Map<int, int> lineMap) {
  return message.replaceAllMapped(_lineWordRe, (match) {
    final lineStr = match.group(1)!;
    final original = lineMap[int.parse(lineStr)];
    return original != null ? 'line $original' : match.group(0)!;
  });
}

int lineStart(String text, int line) {
  var at = 0;
  for (var n = 1; n < line; n++) {
    at = text.indexOf('\n', at) + 1;
  }
  return at;
}

Never _fail(String input, int index, String message) {
  final line = locate(input, lineStart(input, index + 1)).line;
  throw PeleError(
    'Line $line: $message',
    'syntax',
    PeleErrorInfo(type: 'treeView', line: line),
  );
}

// Undo four-space tab expansion.
int _beforeTabs(String line, int at) {
  var i = 0;
  for (var n = 0; i < line.length && n < at; i++) {
    n += line[i] == '\t' ? 4 : 1;
  }
  return i;
}

PreprocessResult preprocessBoxDrawing(String input) {
  final lineMap = <int, int>{};
  final columns = <int, int Function(int at)>{};
  if (!_allBoxChars.hasMatch(input)) {
    return PreprocessResult(text: input, lineMap: lineMap, columns: columns);
  }
  final lines = input.split('\n');

  var keywordIdx = -1;
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].trim() == 'treeView-beta') {
      keywordIdx = i;
      break;
    }
  }
  if (keywordIdx == -1) {
    return PreprocessResult(text: input, lineMap: lineMap, columns: columns);
  }

  bool passes(String line) =>
      line.trim().isEmpty ||
      _commentLine.hasMatch(line) ||
      _metadataLine.hasMatch(line);

  final contentLines = <String>[];
  for (var i = keywordIdx + 1; i < lines.length; i++) {
    final line = lines[i];
    if (passes(line) || _decorationOnly.hasMatch(line)) continue;
    contentLines.add(line.replaceAll('\t', '    '));
  }
  if (!isBoxDrawingFormat(contentLines)) {
    return PreprocessResult(text: input, lineMap: lineMap, columns: columns);
  }

  final segmentWidth = _inferSegmentWidth(contentLines);
  final out = <String>[];
  void keep(String text, int index, [int Function(int at)? column]) {
    out.add(text);
    lineMap[out.length] = index + 1;
    if (column != null) columns[out.length] = column;
  }

  for (var i = 0; i <= keywordIdx; i++) {
    keep(lines[i], i);
  }
  for (var i = keywordIdx + 1; i < lines.length; i++) {
    final line = lines[i];
    if (passes(line)) {
      keep(line, i);
      continue;
    }
    if (_decorationOnly.hasMatch(line)) continue;

    final normalized = line.replaceAll('\t', '    ');
    final branch = _branchChar.firstMatch(normalized);
    if (branch != null) {
      final depth = roundJs(branch.start / segmentWidth) + 1;
      var pos = branch.start + 1;
      while (pos < normalized.length && _dashChar.hasMatch(normalized[pos])) {
        pos++;
      }
      while (pos < normalized.length && normalized[pos] == ' ') {
        pos++;
      }
      final content = normalized.substring(pos).trimRight();
      if (content.isEmpty) {
        _fail(
          input,
          i,
          'Empty node — expected a filename or directory name after the box-drawing prefix',
        );
      }
      final indent = _indentUnit * depth;
      final savedPos = pos;
      keep(
        '$indent$content',
        i,
        (at) =>
            _beforeTabs(line, savedPos + math.max<int>(at - indent.length, 0)),
      );
    } else if (_boxOnly.hasMatch(normalized)) {
      continue;
    } else if (_allBoxChars.hasMatch(normalized)) {
      // A name that happens to contain a box character, such as "Section ─ A.txt", is a root item.
      keep(line, i);
    } else if (_leadWhitespace.hasMatch(normalized)) {
      _fail(
        input,
        i,
        'Unexpected indentation without box-drawing characters. In box-drawing format, use ├── or └── prefixes for indented nodes.',
      );
    } else {
      keep(line, i);
    }
  }
  return PreprocessResult(
    text: out.join('\n'),
    lineMap: lineMap,
    columns: columns,
  );
}

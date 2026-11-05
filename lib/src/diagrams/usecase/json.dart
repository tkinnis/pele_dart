// Upstream: src/diagrams/usecase/json.ts

import 'dart:convert';
import 'dart:math' as math;

import '../../errors.dart';
import '../../text/entities.dart';
import '../../util/chars.dart';
import '../../util/math_js.dart';

class OrderedJson {
  const OrderedJson({required this.value, required this.propertyOrder});

  final Map<String, Object?> value;
  final Map<String, List<String>> propertyOrder;
}

/// Thrown with the offset of the first character that is not valid JSON.
class _WalkError implements Exception {
  const _WalkError(this.offset);
  final int offset;
}

class _Frame {
  _Frame({
    required this.object,
    required this.pointer,
    required this.keys,
    required this.ranges,
    required this.key,
    required this.from,
    required this.index,
  });

  final bool object;
  final String pointer;
  final List<String> keys;
  // For each key read so far, the stretch of `created` its value added.
  final Map<String, (int, int)> ranges;
  String key;
  int from;
  int index;
}

abstract final class _State {
  static const int value = 0;
  static const int key = 1;
  static const int after = 2;
}

final RegExp _reHex4 = RegExp(r'^[\dA-Fa-f]{4}$');

// Walks JSON text that JSON.parse has accepted, to recover the order its keys were written in,
// which JSON.parse loses for integer-like keys. On text JSON.parse rejected it finds where.
// Nesting is kept on a stack of its own, so depth is limited by memory and not by the call stack.
Map<String, List<String>> _propertyOrder(String text) {
  final order = <String, List<String>>{};
  final created = <String>[];
  final stack = <_Frame>[];
  final n = text.length;
  var at = 0;
  var pointer = '';
  var state = _State.value;

  void skip() {
    while (at < n) {
      final c = charCodeAt(text, at);
      if (c != 32 && c != 9 && c != 10 && c != 13) return;
      at++;
    }
  }

  String readString(bool decode) {
    at++;
    final value = StringBuffer();
    while (at < n) {
      final start = at;
      final ch = text[at++];
      if (ch == '"') return value.toString();
      if (ch.codeUnitAt(0) < 0x20) throw _WalkError(start);
      if (ch != r'\') {
        if (decode) value.write(ch);
        continue;
      }
      final escapeAt = at;
      final escape = charAtOrNull(text, at++);
      String decoded;
      if (escape == '"' || escape == r'\' || escape == '/') {
        decoded = escape!;
      } else if (escape == 'b') {
        decoded = '\b';
      } else if (escape == 'f') {
        decoded = '\f';
      } else if (escape == 'n') {
        decoded = '\n';
      } else if (escape == 'r') {
        decoded = '\r';
      } else if (escape == 't') {
        decoded = '\t';
      } else if (escape == 'u') {
        final unit = sliceJs(text, at, at + 4);
        if (!_reHex4.hasMatch(unit)) throw _WalkError(at);
        decoded = String.fromCharCode(int.parse(unit, radix: 16));
        at += 4;
      } else {
        throw _WalkError(escapeAt);
      }
      if (decode) value.write(decoded);
    }
    throw _WalkError(at);
  }

  void literal(String word) {
    for (var k = 0; k < word.length; k++) {
      if (charAtOrNull(text, at + k) != word[k]) throw _WalkError(at + k);
    }
    at += word.length;
  }

  void number() {
    if (charCodeAt(text, at) == 45) at++;
    if (charCodeAt(text, at) == 48) {
      at++;
    } else if (isDigit(charCodeAt(text, at))) {
      while (isDigit(charCodeAt(text, at))) {
        at++;
      }
    } else {
      throw _WalkError(at);
    }
    if (charCodeAt(text, at) == 46) {
      at++;
      if (!isDigit(charCodeAt(text, at))) throw _WalkError(at);
      while (isDigit(charCodeAt(text, at))) {
        at++;
      }
    }
    if ((charCodeAt(text, at) | 32) == 101) {
      at++;
      if (charCodeAt(text, at) == 43 || charCodeAt(text, at) == 45) at++;
      if (!isDigit(charCodeAt(text, at))) throw _WalkError(at);
      while (isDigit(charCodeAt(text, at))) {
        at++;
      }
    }
  }

  skip();
  for (;;) {
    if (state == _State.value) {
      skip();
      final c = charCodeAt(text, at);
      state = _State.after;
      if (c == 123) {
        at++;
        final keys = <String>[];
        order[pointer] = keys;
        created.add(pointer);
        skip();
        if (charCodeAt(text, at) == 125) {
          at++;
        } else {
          stack.add(
            _Frame(
              object: true,
              pointer: pointer,
              keys: keys,
              ranges: <String, (int, int)>{},
              key: '',
              from: 0,
              index: 0,
            ),
          );
          state = _State.key;
        }
      } else if (c == 91) {
        at++;
        skip();
        if (charCodeAt(text, at) == 93) {
          at++;
        } else {
          stack.add(
            _Frame(
              object: false,
              pointer: pointer,
              keys: <String>[],
              ranges: <String, (int, int)>{},
              key: '',
              from: 0,
              index: 0,
            ),
          );
          pointer = '$pointer/0';
          state = _State.value;
        }
      } else if (c == 34) {
        readString(false);
      } else if (c == 116) {
        literal('true');
      } else if (c == 102) {
        literal('false');
      } else if (c == 110) {
        literal('null');
      } else if (c == 45 || isDigit(c)) {
        number();
      } else {
        throw _WalkError(at);
      }
    } else if (state == _State.key) {
      final frame = stack.last;
      if (charCodeAt(text, at) != 34) throw _WalkError(at);
      final key = readString(true);
      final range = frame.ranges[key];
      // A repeated key keeps its first place in the order and takes the nested order of its last value.
      if (range == null) {
        frame.keys.add(key);
      } else {
        for (var k = range.$1; k < range.$2; k++) {
          order.remove(created[k]);
        }
      }
      frame.key = key;
      frame.from = created.length;
      skip();
      if (charCodeAt(text, at) != 58) throw _WalkError(at);
      at++;
      pointer =
          '${frame.pointer}/${key.replaceAll('~', '~0').replaceAll('/', '~1')}';
      state = _State.value;
    } else {
      if (stack.isEmpty) break;
      final frame = stack.last;
      if (frame.object) {
        frame.ranges[frame.key] = (frame.from, created.length);
      } else {
        frame.index++;
      }
      skip();
      final c = charCodeAt(text, at);
      if (c == (frame.object ? 125 : 93)) {
        at++;
        stack.removeLast();
      } else if (c != 44) {
        throw _WalkError(at);
      } else {
        at++;
        skip();
        pointer = '${frame.pointer}/${frame.index}';
        state = frame.object ? _State.key : _State.value;
      }
    }
  }
  skip();
  if (at != n) throw _WalkError(at);
  return order;
}

(int, int) _locationAt(String text, int offset, int line, int column) {
  final end = math.min<int>(math.max<int>(offset, 0), text.length);
  for (var i = 0; i < end; i++) {
    final c = charCodeAt(text, i);
    if (c == 13) {
      line++;
      column = 1;
    } else if (c == 10) {
      if (i == 0 || charCodeAt(text, i - 1) != 13) {
        line++;
        column = 1;
      }
    } else {
      column++;
    }
  }
  return (line, column);
}

final RegExp _rePos = RegExp(r'\bposition (\d+)\b');
final RegExp _reLineCol = RegExp(r'\bline (\d+) column (\d+)\b');
final RegExp _reEnd = RegExp(
  r'unexpected end|end of json input',
  caseSensitive: false,
);

// Engines word JSON.parse errors differently: some give an offset, some a line and column.
(int, int)? _locationFromMessage(
  String message,
  String text,
  int line,
  int column,
) {
  final position = _rePos.firstMatch(message);
  if (position != null) {
    return _locationAt(text, int.parse(position.group(1)!), line, column);
  }
  final local = _reLineCol.firstMatch(message);
  if (local != null) {
    final localLine = int.parse(local.group(1)!);
    final localColumn = int.parse(local.group(2)!);
    return (
      line + localLine - 1,
      localLine == 1 ? column + localColumn - 1 : localColumn,
    );
  }
  if (_reEnd.hasMatch(message)) {
    return _locationAt(text, text.length, line, column);
  }
  return null;
}

PeleError _jsonError(String message, int line, int column) {
  return PeleError(
    '$message (line $line, column $column)',
    'syntax',
    PeleErrorInfo(type: 'usecase', line: line, column: column),
  );
}

/// Parses the body of a `json` node. [origin] gives the line and column the text starts at in the diagram.
OrderedJson parseOrderedJson(String text, (int, int) Function() origin) {
  Object? parsed;
  try {
    parsed = jsonDecode(text);
  } catch (error) {
    var message = error is FormatException ? error.message : '$error';
    // Reparse restored entity codes so error messages and positions match the source.
    final shown = writtenCodes(text);
    if (shown != text) {
      try {
        jsonDecode(shown);
      } catch (again) {
        if (again is FormatException) {
          message = again.message;
        }
      }
    }
    final (line, column) = origin();
    var location = _locationFromMessage(message, shown, line, column);
    if (location == null) {
      var offset = 0;
      try {
        _propertyOrder(shown);
      } on _WalkError catch (walk) {
        offset = walk.offset;
      }
      location = _locationAt(shown, offset, line, column);
    }
    throw _jsonError('Invalid JSON: $message', location.$1, location.$2);
  }
  if (parsed is! Map) {
    final (line, column) = origin();
    throw _jsonError('JSON value must have an object root', line, column);
  }
  return OrderedJson(
    value: Map<String, Object?>.from(parsed),
    propertyOrder: _propertyOrder(text),
  );
}

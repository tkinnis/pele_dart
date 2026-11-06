// Upstream: src/util/yaml.ts

import 'math_js.dart';

/// A small YAML reader covering what Mermaid feeds to js-yaml with the JSON schema:
/// block and flow collections, quoted and plain scalars, and block scalars.
typedef YamlValue = Object?;

class _Incomplete implements Exception {
  const _Incomplete(this.message);
  final String message;
}

const int _maxDepth = 64;

void _assign(Map<String, YamlValue> target, String key, YamlValue value) {
  target[key] = value;
}

class _Reader {
  _Reader(String src)
    : lines = (src.contains('\r') ? src.replaceAll(_reCrLf, '\n') : src).split(
        '\n',
      );

  final List<String> lines;
  int i = 0;

  void skipBlank() {
    while (i < lines.length) {
      final t = lines[i].trim();
      if (t.isNotEmpty && t.codeUnitAt(0) != 0x23 && t != '---') break;
      i++;
    }
  }

  int indent() {
    final line = lines[i];
    var k = 0;
    while (k < line.length && line.codeUnitAt(k) == 0x20) {
      k++;
    }
    if (k < line.length && line.codeUnitAt(k) == 0x09) {
      throw StateError('YAML: tabs are not allowed for indentation');
    }
    return k;
  }
}

final RegExp _reCrLf = RegExp(r'\r\n?');
final RegExp _reInt = RegExp(r'^[-+]?(?:0|[1-9][0-9]*)$');
final RegExp _reHex = RegExp(r'^[-+]?0x[0-9a-fA-F]+$');
final RegExp _reOct = RegExp(r'^[-+]?0o[0-7]+$');
final RegExp _reBin = RegExp(r'^[-+]?0b[01]+$');
final RegExp _reFloat = RegExp(
  r'^[-+]?(?:[0-9][0-9]*(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][-+]?[0-9]+)?$',
);
final RegExp _reInf = RegExp(r'^[-+]?\.(?:inf|Inf|INF)$');
final RegExp _reNan = RegExp(r'^\.(?:nan|NaN|NAN)$');
final RegExp _reNewlines = RegExp(r'\n+');
final RegExp _reEscapedNewline = RegExp(r'\\\n[ \t]*');
final RegExp _reFlowStopAfterColon = RegExp(r'[\s,[\]{}]');
final RegExp _reDigit1To9 = RegExp(r'[1-9]');
final RegExp _reLeadingSpaceOrTab = RegExp(r'^[ \t]');
final RegExp _reBlockScalarHeader = RegExp(r'^[|>][-+0-9]*\s*(?:#.*)?$');

bool _isBlankCode(int c) {
  return c == 0x20 || c == 0x09 || c == 0x0a || c == 0x0d;
}

bool _isKeyStartBlocked(int c) {
  return _isBlankCode(c) ||
      c == 0x23 ||
      c == 0x3a ||
      c == 0x2c ||
      c == 0x5b ||
      c == 0x5d ||
      c == 0x7b ||
      c == 0x7d ||
      c == 0x26 ||
      c == 0x2a ||
      c == 0x21 ||
      c == 0x7c ||
      c == 0x3e ||
      c == 0x27 ||
      c == 0x22 ||
      c == 0x25 ||
      c == 0x40 ||
      c == 0x60;
}

({String key, int length})? _splitKey(String line) {
  final n = line.length;
  if (n == 0) return null;
  final first = line.codeUnitAt(0);
  int end;
  int colon;
  if (first == 0x22 || first == 0x27) {
    var i = 1;
    while (true) {
      if (i >= n) return null;
      final c = line.codeUnitAt(i);
      if (first == 0x22 && c == 0x5c) {
        i += 2;
      } else if (c == first) {
        if (first == 0x22 || i + 1 >= n || line.codeUnitAt(i + 1) != 0x27) {
          break;
        }
        i += 2;
      } else {
        i++;
      }
    }
    end = i + 1;
    colon = end;
    while (colon < n && _isBlankCode(line.codeUnitAt(colon))) {
      colon++;
    }
    if (colon >= n || line.codeUnitAt(colon) != 0x3a) return null;
  } else {
    if (_isKeyStartBlocked(first)) return null;
    if (first == 0x2d) {
      if (n < 2) return null;
      final second = line.codeUnitAt(1);
      if (_isBlankCode(second) || second == 0x3a || second == 0x23) {
        return null;
      }
    }
    colon = 1;
    while (colon < n) {
      final c = line.codeUnitAt(colon);
      if (c == 0x3a || c == 0x23) break;
      colon++;
    }
    if (colon >= n || line.codeUnitAt(colon) != 0x3a) return null;
    end = colon;
    while (end > 0 && _isBlankCode(line.codeUnitAt(end - 1))) {
      end--;
    }
  }
  var length = colon + 1;
  if (length < n && !_isBlankCode(line.codeUnitAt(length))) {
    return null;
  }
  while (length < n && _isBlankCode(line.codeUnitAt(length))) {
    length++;
  }
  return (key: line.substring(0, end), length: length);
}

YamlValue _scalar(String raw) {
  final s = raw.trim();
  if (s.isEmpty || s == '~' || s == 'null' || s == 'Null' || s == 'NULL') {
    return null;
  }
  if (s == 'true' || s == 'True' || s == 'TRUE') return true;
  if (s == 'false' || s == 'False' || s == 'FALSE') return false;
  final c = s[0];
  if (c != '-' &&
      c != '+' &&
      c != '.' &&
      (c.codeUnitAt(0) < 48 || c.codeUnitAt(0) > 57)) {
    return s;
  }
  if (_reInt.hasMatch(s)) {
    return int.tryParse(s) ?? double.parse(s);
  }
  if (_reFloat.hasMatch(s)) {
    return double.parse(s);
  }
  if (_reHex.hasMatch(s) || _reOct.hasMatch(s) || _reBin.hasMatch(s)) {
    final neg = s[0] == '-';
    final body = (neg || s[0] == '+') ? s.substring(1) : s;
    final radix = body.startsWith('0x') || body.startsWith('0X')
        ? 16
        : (body.startsWith('0o') || body.startsWith('0O') ? 8 : 2);
    final v = int.parse(body.substring(2), radix: radix);
    return neg ? -v : v;
  }
  if (_reInf.hasMatch(s)) {
    return s[0] == '-' ? double.negativeInfinity : double.infinity;
  }
  if (_reNan.hasMatch(s)) return double.nan;
  return s;
}

const Map<String, String> _escapes = {
  '0': '\u0000',
  'a': '\x07',
  'b': '\b',
  't': '\t',
  'n': '\n',
  'v': '\v',
  'f': '\f',
  'r': '\r',
  'e': '\x1b',
  ' ': ' ',
  '"': '"',
  '/': '/',
  r'\': r'\',
  'N': '\x85',
  '_': '\xa0',
  'L': '\u2028',
  'P': '\u2029',
};

String _fold(String text) {
  if (!text.contains('\n')) return text;
  final lines = text.split('\n');
  final last = lines.length - 1;
  for (var i = 0; i <= last; i++) {
    final line = lines[i];
    var from = 0;
    var to = line.length;
    if (i > 0) {
      while (from < to &&
          (line.codeUnitAt(from) == 32 || line.codeUnitAt(from) == 9)) {
        from++;
      }
    }
    if (i < last) {
      while (to > from &&
          (line.codeUnitAt(to - 1) == 32 || line.codeUnitAt(to - 1) == 9)) {
        to--;
      }
    }
    lines[i] = line.substring(from, to);
  }
  return lines
      .join('\n')
      .replaceAllMapped(
        _reNewlines,
        (m) => m[0]!.length == 1 ? ' ' : '\n' * (m[0]!.length - 1),
      );
}

String _unquoteDouble(String body) {
  if (!body.contains(r'\')) return _fold(body);
  final out = StringBuffer();
  final s = _fold(body.replaceAll(_reEscapedNewline, ''));
  final n = s.length;
  var chunkStart = 0;
  for (var i = 0; i < n; i++) {
    if (s.codeUnitAt(i) != 0x5c) continue;
    if (i > chunkStart) {
      out.write(s.substring(chunkStart, i));
    }
    i++;
    final e = charAtOrNull(s, i);
    if (e == 'x' || e == 'u' || e == 'U') {
      final len = e == 'x' ? 2 : (e == 'u' ? 4 : 8);
      if (i + 1 + len > n) {
        throw StateError('YAML: unknown escape sequence');
      }
      final code = int.tryParse(s.substring(i + 1, i + 1 + len), radix: 16);
      if (code == null) throw StateError('YAML: unknown escape sequence');
      out.write(String.fromCharCode(code));
      i += len;
    } else if (e != null && _escapes.containsKey(e)) {
      out.write(_escapes[e]!);
    } else {
      throw StateError('YAML: unknown escape sequence');
    }
    chunkStart = i + 1;
  }
  if (n > chunkStart) {
    out.write(s.substring(chunkStart, n));
  }
  return out.toString();
}

int _skip(String s, int pos, bool commas) {
  final n = s.length;
  while (pos < n) {
    final c = s.codeUnitAt(pos);
    if (c == 0x20 ||
        c == 0x0a ||
        c == 0x09 ||
        c == 0x0d ||
        (commas && c == 0x2c)) {
      pos++;
    } else if (c == 0x23 && (pos == 0 || _isBlankCode(s.codeUnitAt(pos - 1)))) {
      final nl = s.indexOf('\n', pos);
      pos = nl == -1 ? n : nl;
    } else {
      break;
    }
  }
  return pos;
}

void _entryStart(String ch, bool separated) {
  if (!separated) {
    throw StateError('YAML: missed comma between flow collection entries');
  }
  if (ch == ',') {
    throw StateError("YAML: expected the node content, but found ','");
  }
}

(YamlValue, int) _flow(String s, int pos, String stops, [int depth = 0]) {
  if (depth > _maxDepth) throw StateError('YAML: nesting is too deep');
  pos = _skip(s, pos, false);
  final ch = charAtOrNull(s, pos);
  if (ch == '{') {
    final out = <String, YamlValue>{};
    pos++;
    var separated = true;
    while (true) {
      pos = _skip(s, pos, false);
      if (pos >= s.length) {
        throw const _Incomplete(
          'YAML: unexpected end of the stream within a flow collection',
        );
      }
      if (s[pos] == '}') return (out, pos + 1);
      _entryStart(s[pos], separated);
      YamlValue key;
      (key, pos) = _flow(s, pos, ':,}', depth + 1);
      pos = _skip(s, pos, false);
      YamlValue value;
      if (charAtOrNull(s, pos) == ':') {
        (value, pos) = _flow(s, pos + 1, ',}', depth + 1);
      }
      _assign(out, '${key ?? 'null'}', value);
      pos = _skip(s, pos, false);
      separated = charAtOrNull(s, pos) == ',';
      if (separated) pos++;
    }
  }
  if (ch == '[') {
    final out = <YamlValue>[];
    pos++;
    var separated = true;
    while (true) {
      pos = _skip(s, pos, false);
      if (pos >= s.length) {
        throw const _Incomplete(
          'YAML: unexpected end of the stream within a flow collection',
        );
      }
      if (s[pos] == ']') return (out, pos + 1);
      _entryStart(s[pos], separated);
      YamlValue value;
      (value, pos) = _flow(s, pos, ',]', depth + 1);
      out.add(value);
      pos = _skip(s, pos, false);
      separated = charAtOrNull(s, pos) == ',';
      if (separated) pos++;
    }
  }
  if (ch == '"') {
    var end = pos + 1;
    while (end < s.length && s.codeUnitAt(end) != 0x22) {
      end += s.codeUnitAt(end) == 0x5c ? 2 : 1;
    }
    if (end >= s.length) {
      throw const _Incomplete(
        'YAML: unexpected end of the stream within a double quoted scalar',
      );
    }
    return (_unquoteDouble(s.substring(pos + 1, end)), end + 1);
  }
  if (ch == "'") {
    var end = pos + 1;
    while (end < s.length) {
      if (s.codeUnitAt(end) == 0x27) {
        if (end + 1 >= s.length || s.codeUnitAt(end + 1) != 0x27) break;
        end++;
      }
      end++;
    }
    if (end >= s.length) {
      throw const _Incomplete(
        'YAML: unexpected end of the stream within a single quoted scalar',
      );
    }
    return (_fold(s.substring(pos + 1, end)).replaceAll("''", "'"), end + 1);
  }
  var end = pos;
  while (end < s.length) {
    final c = s[end];
    if (stops.contains(c) &&
        (c != ':' ||
            end + 1 >= s.length ||
            _reFlowStopAfterColon.hasMatch(s[end + 1]))) {
      break;
    }
    if (c == '#' && end > pos && _isBlankCode(s.codeUnitAt(end - 1))) {
      final nl = s.indexOf('\n', end);
      return (
        _scalar(_fold(s.substring(pos, end).trim())),
        nl == -1 ? s.length : nl,
      );
    }
    end++;
  }
  return (_scalar(_fold(s.substring(pos, end).trim())), end);
}

String _stripComment(String s) {
  if (!s.contains('#')) return s;
  var quote = 0;
  final n = s.length;
  for (var i = 0; i < n; i++) {
    final c = s.codeUnitAt(i);
    if (quote != 0) {
      if (c == 0x5c && quote == 0x22) {
        i++;
      } else if (c == quote) {
        quote = 0;
      }
    } else if (c == 0x22 || c == 0x27) {
      quote = c;
    } else if (c == 0x23 &&
        (i == 0 ||
            s.codeUnitAt(i - 1) == 0x20 ||
            s.codeUnitAt(i - 1) == 0x09)) {
      return s.substring(0, i);
    }
  }
  return s;
}

String _blockScalar(_Reader r, String header, int parentIndent) {
  final folded = header.startsWith('>');
  final chomp = header.contains('-') ? '-' : (header.contains('+') ? '+' : '');
  final explicit = _reDigit1To9.firstMatch(header);
  var indent = explicit != null ? parentIndent + int.parse(explicit[0]!) : -1;
  final out = <String>[];
  while (r.i < r.lines.length) {
    final line = r.lines[r.i];
    if (line.trim().isEmpty) {
      out.add('');
      r.i++;
      continue;
    }
    final k = line.length - line.trimLeft().length;
    if (indent == -1) {
      if (k <= parentIndent) break;
      indent = k;
    }
    if (k < indent) break;
    out.add(line.substring(indent));
    r.i++;
  }
  var trailing = 0;
  while (out.isNotEmpty && out.last.isEmpty) {
    out.removeLast();
    trailing++;
  }
  String text;
  if (folded) {
    final buf = StringBuffer();
    for (var i = 0; i < out.length; i++) {
      final cur = out[i];
      if (i > 0) {
        final prev = out[i - 1];
        if (cur.isEmpty) {
          buf.write('\n');
        } else if (prev.isNotEmpty) {
          buf.write(
            _reLeadingSpaceOrTab.hasMatch(prev) ||
                    _reLeadingSpaceOrTab.hasMatch(cur)
                ? '\n'
                : ' ',
          );
        }
      }
      buf.write(cur);
    }
    text = buf.toString();
  } else {
    text = out.join('\n');
  }
  if (out.isEmpty) return chomp == '+' ? '\n' * trailing : '';
  if (chomp == '-') return text;
  if (chomp == '+') return text + ('\n' * (trailing + 1));
  return '$text\n';
}

String _parseKey(String rawKey) {
  if (rawKey.isNotEmpty) {
    final c = rawKey.codeUnitAt(0);
    if (c != 0x7b &&
        c != 0x5b &&
        c != 0x22 &&
        c != 0x27 &&
        !rawKey.contains('#') &&
        !rawKey.contains('\n')) {
      return '${_scalar(rawKey) ?? 'null'}';
    }
  }
  return '${_flow(rawKey, 0, '').$1 ?? 'null'}';
}

YamlValue _inlineValue(_Reader r, String rest, int indent) {
  final first = charAtOrNull(rest, 0);
  if (first == '|' || first == '>') {
    if (_reBlockScalarHeader.hasMatch(rest)) {
      return _blockScalar(r, rest, indent);
    }
  }
  if (first == '{' || first == '[' || first == '"' || first == "'") {
    final start = r.i;
    var text = rest;
    var taken = 0;
    if (first == '"') {
      var scan = 1;
      while (true) {
        while (scan < text.length && text.codeUnitAt(scan) != 0x22) {
          scan += text.codeUnitAt(scan) == 0x5c ? 2 : 1;
        }
        if (scan < text.length || start + taken >= r.lines.length) break;
        text += '\n${r.lines[start + taken]}';
        taken++;
      }
    } else if (first == "'") {
      var scan = 1;
      while (true) {
        while (scan < text.length) {
          if (text.codeUnitAt(scan) == 0x27) {
            if (scan + 1 < text.length && text.codeUnitAt(scan + 1) == 0x27) {
              scan += 2;
              continue;
            }
            break;
          }
          scan++;
        }
        if (scan < text.length || start + taken >= r.lines.length) break;
        text += '\n${r.lines[start + taken]}';
        taken++;
      }
    }
    var batch = 1;
    while (true) {
      try {
        final (value, end) = _flow(text, 0, '');
        var used = 0;
        for (
          var k = text.indexOf('\n');
          k != -1 && k < end;
          k = text.indexOf('\n', k + 1)
        ) {
          used++;
        }
        final lineEnd = text.indexOf('\n', end);
        if (_stripComment(
          text.substring(end, lineEnd == -1 ? text.length : lineEnd),
        ).trim().isNotEmpty) {
          throw StateError('YAML: unexpected content after a value');
        }
        r.i = start + used;
        return value;
      } on _Incomplete catch (err) {
        if (start + taken >= r.lines.length) throw StateError(err.message);
        final endIdx = (start + taken + batch > r.lines.length)
            ? r.lines.length
            : start + taken + batch;
        final more = r.lines.sublist(start + taken, endIdx);
        text += '\n${more.join('\n')}';
        taken += more.length;
        batch *= 2;
      }
    }
  }
  var text = _stripComment(rest).trim();
  while (r.i < r.lines.length) {
    final line = r.lines[r.i];
    if (line.trim().isEmpty) {
      var j = r.i;
      while (j < r.lines.length && r.lines[j].trim().isEmpty) {
        j++;
      }
      if (j >= r.lines.length ||
          r.lines[j].length - r.lines[j].trimLeft().length <= indent) {
        break;
      }
      text += '\n' * (j - r.i);
      r.i = j;
      continue;
    }
    if (line.length - line.trimLeft().length <= indent) break;
    final more = _stripComment(line).trim();
    text += (text.endsWith('\n') ? '' : ' ') + more;
    r.i++;
  }
  return _scalar(text);
}

YamlValue _block(_Reader r, int minIndent, [int depth = 0]) {
  if (depth > _maxDepth) throw StateError('YAML: nesting is too deep');
  r.skipBlank();
  if (r.i >= r.lines.length) return null;
  final indent = r.indent();
  if (indent < minIndent) return null;
  final line = r.lines[r.i].substring(indent);

  if (line == '-' || line.startsWith('- ')) {
    final out = <YamlValue>[];
    while (r.i < r.lines.length) {
      r.skipBlank();
      if (r.i >= r.lines.length || r.indent() != indent) break;
      final cur = r.lines[r.i].substring(indent);
      if (cur != '-' && !cur.startsWith('- ')) break;
      final rest = cur.substring(1);
      final pad = rest.length - rest.trimLeft().length + 1;
      final body = _stripComment(rest).trim();
      if (body.isEmpty) {
        r.i++;
        out.add(_block(r, indent + 1, depth + 1));
      } else if (_splitKey(body) != null) {
        r.lines[r.i] = (' ' * (indent + pad)) + rest.trimLeft();
        out.add(_block(r, indent + pad, depth + 1));
      } else {
        r.i++;
        out.add(_inlineValue(r, rest.trim(), indent));
      }
    }
    return out;
  }

  if (_splitKey(line) == null) {
    r.i++;
    return _inlineValue(r, line.trim(), indent - 1);
  }

  final out = <String, YamlValue>{};
  while (r.i < r.lines.length) {
    r.skipBlank();
    if (r.i >= r.lines.length) break;
    final k = r.indent();
    if (k < indent) break;
    if (k > indent) {
      throw StateError('YAML: bad indentation of a mapping entry');
    }
    final cur = r.lines[r.i].substring(indent);
    final km = _splitKey(cur);
    if (km == null) {
      throw StateError('YAML: can not read a block mapping entry');
    }
    final key = _parseKey(km.key);
    final rest = cur.substring(km.length);
    r.i++;
    if (_stripComment(rest).trim().isEmpty) {
      r.skipBlank();
      if (r.i < r.lines.length) {
        final next = r.indent();
        final nextLine = r.lines[r.i].substring(next);
        final seq = nextLine == '-' || nextLine.startsWith('- ');
        _assign(
          out,
          key,
          next > indent || (seq && next == indent)
              ? _block(r, seq ? indent : indent + 1, depth + 1)
              : null,
        );
      } else {
        _assign(out, key, null);
      }
    } else {
      _assign(out, key, _inlineValue(r, rest.trim(), indent));
    }
  }
  return out;
}

YamlValue parseYaml(String src) {
  final trimmed = src.trim();
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    try {
      final (value, end) = _flow(trimmed, 0, '');
      if (_skip(trimmed, end, false) == trimmed.length) return value;
    } on _Incomplete catch (err) {
      throw StateError(err.message);
    }
  }
  final r = _Reader(src);
  final value = _block(r, 0);
  r.skipBlank();
  if (r.i < r.lines.length && r.lines[r.i].trim() != '...') {
    throw StateError(
      'YAML: end of the stream or a document separator is expected',
    );
  }
  return value;
}

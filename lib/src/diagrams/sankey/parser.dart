// Upstream: src/diagrams/sankey/parser.ts

import '../../errors.dart';
import '../../text/entities.dart';
import '../../util/math_js.dart';
import 'db.dart';
import 'lexer.dart';

final RegExp _reLineBreaks = RegExp(r'[\n\r]+');
final RegExp _reInvalidXml = RegExp(
  r'[\x00-\x08\x0b\x0c\x0e-\x1f\ud800-\udfff\ufffe\uffff]',
  unicode: true,
);
final RegExp _reLeadingFloat = RegExp(
  r'^\s*[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?',
);

double _parseFloat(String raw) {
  final m = _reLeadingFloat.firstMatch(raw);
  if (m == null) return double.nan;
  return double.tryParse(m.group(0)!.trim()) ?? double.nan;
}

bool _isBlank(int c) {
  if (c < 0 || c == 10 || c == 13) return false;
  if (c < 128) return c == 32 || c == 9 || c == 11 || c == 12;
  return c == 0xa0 ||
      c == 0x1680 ||
      (c >= 0x2000 && c <= 0x200a) ||
      c == 0x2028 ||
      c == 0x2029 ||
      c == 0x202f ||
      c == 0x205f ||
      c == 0x3000 ||
      c == 0xfeff;
}

String _trimRows(String text, List<Edit> edits) {
  var end = text.length;
  while (end > 0 && _isBlank(charCodeAt(text, end - 1))) {
    end--;
  }
  final out = StringBuffer();
  var kept = 0;
  var quoted = false;
  for (var i = 0; i < end;) {
    final c = charCodeAt(text, i);
    if (quoted) {
      if (c == 34) {
        if (charCodeAt(text, i + 1) == 34) {
          i++;
        } else {
          quoted = false;
        }
      }
      i++;
    } else if (c == 34) {
      quoted = true;
      i++;
    } else if (_isBlank(c)) {
      var j = i + 1;
      while (_isBlank(charCodeAt(text, j))) {
        j++;
      }
      final p = charCodeAt(text, i - 1);
      final q = charCodeAt(text, j);
      // Preserve blank first fields, which Mermaid accepts as empty names.
      if (i == 0 || q == 10 || q == 13 || ((p == 10 || p == 13) && q != 44)) {
        out.write(text.substring(kept, i));
        edits.add((i, j, 0));
        kept = j;
      }
      i = j;
    } else {
      i++;
    }
  }
  if (end < text.length) edits.add((end, text.length, 0));
  out.write(text.substring(kept, end));
  return out.toString();
}

// Unlike Mermaid's sankeyUtils, also trim row edges outside quoted fields.
String prepareTextForParsing(String text, [List<List<Edit>>? steps]) {
  final edits = <Edit>[];
  final rows = _trimRows(text, edits);
  final collapsed = rows.replaceAll(_reLineBreaks, '\n');
  final trimmed = collapsed.trim();
  if (steps != null) {
    final lead = collapsed.length - collapsed.trimLeft().length;
    steps.addAll(<List<Edit>>[
      edits,
      replacements(rows, _reLineBreaks, 1),
      <Edit>[(0, lead, 0), (lead + trimmed.length, collapsed.length, 0)],
    ]);
  }
  return trimmed;
}

// Report errors in `source`, the text before prepareTextForParsing.
void parseSankey(String src, SankeyDb db, [String? source]) {
  final origSource = source ?? src;
  final tokens = tokenize(src);
  final types = tokens.types;
  final texts = tokens.texts;
  final starts = tokens.starts;
  var i = 0;

  PeleError error(int at, String detail) {
    final steps = <List<Edit>>[];
    if (origSource != src) prepareTextForParsing(origSource, steps);
    // Map EOF before the trimmed trailing blanks.
    final offset = at > 0 && at >= src.length
        ? inputOffset(steps, src.length - 1) + 1
        : inputOffset(steps, at);
    return syntaxError('sankey', origSource, offset, detail);
  }

  Never fail(String expected) {
    final t = types[i];
    final got = t == T.STUCK ? TOKEN_NAMES[types[i - 1]] : TOKEN_NAMES[t];
    throw error(starts[i], "Expecting $expected, got '$got'");
  }

  void expect(int type, [String also = '']) {
    if (types[i] != type) fail("'${TOKEN_NAMES[type]}'$also");
    i++;
  }

  String field() {
    if (types[i] == T.NON_ESCAPED_TEXT) return texts[i++];
    if (types[i] != T.DQUOTE) fail("'DQUOTE', 'NON_ESCAPED_TEXT'");
    i++;
    if (types[i] != T.ESCAPED_TEXT) fail("'ESCAPED_TEXT'");
    final text = texts[i++];
    expect(T.DQUOTE);
    return text;
  }

  String name() {
    final start = starts[i];
    final text = field().trim().replaceAll('""', '"');
    // Entity codes can encode characters excluded by the lexer.
    if (_reInvalidXml.hasMatch(decodeEntities(text))) {
      throw error(start, 'Invalid XML character in node name');
    }
    return text;
  }

  expect(T.SANKEY);
  expect(T.NEWLINE);
  while (true) {
    final from = name();
    expect(T.COMMA, ", 'NEWLINE', 'EOF'");
    final to = name();
    expect(T.COMMA, ", 'NEWLINE', 'EOF'");
    final start = starts[i];
    // Keep Mermaid's numeric prefixes, but reject non-finite values.
    final value = _parseFloat(field());
    if (!value.isFinite) throw error(start, 'Expecting a number');
    final srcNode = db.findOrCreateNode(from);
    final dstNode = db.findOrCreateNode(to);
    db.addLink(srcNode, dstNode, value);
    if (types[i] != T.NEWLINE) break;
    i++;
  }
  if (types[i] == T.EOF) i++;
  if (types[i] != T.END) fail("'NEWLINE', 'EOF'");
}

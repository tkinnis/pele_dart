// Upstream: src/diagrams/usecase/parser.ts

import 'dart:math' as math;
import 'dart:typed_data';

import '../../errors.dart';
import '../../util/chars.dart' show isWord;
import '../../util/math_js.dart';
import 'db.dart';
import 'json.dart';
import 'lexer.dart';
import 'tokens.dart';
import 'types.dart';

// Mermaid parses use case diagrams with a Chevrotain parser, which decides each choice by looking
// at most three tokens ahead and reports the first token that fits nowhere. This parser makes the
// same decisions from the same lookahead, so it accepts the same text and names the same token in
// its errors. It builds the model directly, where Mermaid builds a syntax tree and then visits it.

const int _line = 1;
const int _relation = 2;
const int _stylePart = 4;
const int _followsName = 8;
const int _boundaryLine = 16;
const int _closesLabel = 32;
const int _metadataFirst = 64;

const String _arrows =
    'DEPENDENCY_ARROW|GENERALIZATION|FORWARD_SOLID|BACKWARD_SOLID|MARKERLESS_SOLID|FORWARD_CIRCLE|BACKWARD_CIRCLE|FORWARD_CROSS|BACKWARD_CROSS';
const String _names = 'IDENTIFIER|PLAIN_STRING|MARKDOWN_STRING';
const String _labels = 'PLAIN_STRING|MARKDOWN_STRING|LABEL_TEXT';
const String _statements =
    'ACC_TITLE_LINE|ACC_DESCR_LINE|ACC_DESCR_BLOCK|DIRECTION|ACTOR|SYSTEM_BOUNDARY|NOTE|JSON_DECLARATION_START|CLASS_DEF|CLASS|STYLE';
const String _styleParts =
    'WORD|PLAIN_STRING|NUMBER|HASH_COLOR|CSS_IDENTIFIER|CSS_ESCAPED_COMMA|DASH|DOT|PERCENT|CSS_PUNCTUATION|COLON|LPAREN|RPAREN|LBRACKET|RBRACKET|LBRACE|RBRACE|AT|MARKERLESS_SOLID';

final Uint8List _flags = () {
  final flags = Uint8List(T.RPAREN + 1);
  void flag(String names, int bits) {
    for (final name in names.split('|')) {
      // WORD is a category: every keyword and IDENTIFIER.
      if (name == 'WORD') {
        for (var t = T.USECASE; t <= T.IDENTIFIER; t++) {
          flags[t] |= bits;
        }
      } else {
        flags[TOKEN_NAMES.indexOf(name)] |= bits;
      }
    }
  }

  flag('NEWLINE|COMMENT|$_statements|$_names', _line);
  flag('IDENTIFIER|$_arrows', _relation);
  flag(_styleParts, _stylePart);
  flag(
    'STEREOTYPE_START|CLASS_SEPARATOR|IDENTIFIER|$_arrows|NEWLINE|EOF',
    _followsName,
  );
  flag('NEWLINE|COMMENT|ACTOR|$_names', _boundaryLine);
  flag(
    'FORWARD_SOLID|MARKERLESS_SOLID|FORWARD_CIRCLE|FORWARD_CROSS',
    _closesLabel,
  );
  flag('NEWLINE|IDENTIFIER|PLAIN_STRING|RBRACE', _metadataFirst);
  return flags;
}();

const Set<String> _forbidden = <String>{
  'allowmixing',
  'newpage',
  'package',
  'rectangle',
  'skinparam',
};

final RegExp _reNonWord = RegExp(r'\W');

class _Item {
  _Item({
    required this.id,
    required this.label,
    required this.span,
    required this.generated,
    this.shape,
    required this.classes,
    required this.classSpans,
    required this.explicit,
    required this.nodeSpan,
  });

  String id;
  DraftLabel label;
  Span span;
  bool generated;
  UseCaseShape? shape;
  List<DraftProperty>? metadata;
  String? stereotype;
  Span? stereotypeSpan;
  List<String> classes;
  List<Span> classSpans;
  // Whether this mention says something about the element, and so declares it.
  bool explicit;
  Span nodeSpan;
}

class _Tail {
  _Tail({
    this.explicitId,
    this.explicitIdSpan,
    required this.type,
    required this.arrowType,
    this.label,
    required this.minlen,
    required this.target,
    required this.span,
  });

  String? explicitId;
  Span? explicitIdSpan;
  RelationshipType type;
  int arrowType;
  DraftLabel? label;
  int minlen;
  _Item target;
  Span span;
}

String _src = '';
List<int> _types = const <int>[];
List<int> _starts = const <int>[];
List<int> _ends = const <int>[];
int _p = 0;
// Where the last token before the most recent line end stops, which is where its statement stops.
int _lastEnd = 0;
late Drafts _drafts;
DraftBoundary? _parent;
List<(DraftJson, int)> _pendingJson = <(DraftJson, int)>[];
int _edgeCount = 0;
int _noteCount = 0;

String _image(int k) {
  return sliceJs(_src, _starts[k], _ends[k]);
}

Span _span(int k) {
  return <int>[_starts[k], _ends[k]];
}

Never _fail(String detail) {
  final (line, column) = lineColumn(_src, _starts[_p]);
  throw PeleError(
    'Error parsing usecase diagram: $detail at ${locationText(_src, _starts[_p], _ends[_p])}',
    'syntax',
    PeleErrorInfo(type: 'usecase', line: line, column: column),
  );
}

Never _mismatch(String name) {
  _fail(
    "Expecting token of type --> $name <-- but found --> '${_image(_p)}' <--",
  );
}

int _expect(int type) {
  if (_types[_p] != type) _mismatch(TOKEN_NAMES[type]);
  return _p++;
}

// Chevrotain lists every token sequence that would have been accepted.
Never _noAlternative(String expected) {
  final parts = expected.split('|');
  final list = <String>[
    for (var i = 0; i < parts.length; i++) '  ${i + 1}. [${parts[i]}]',
  ];
  _fail(
    "Expecting: one of these possible Token sequences:\n${list.join('\n')}\nbut found: '${_image(_p)}'",
  );
}

String _statementSequences() {
  final names = _names.split('|');
  final metadata = <String>[
    for (final name in names)
      for (final next in const <String>[
        'NEWLINE',
        'IDENTIFIER',
        'PLAIN_STRING',
        'RBRACE',
      ])
        '$name, METADATA_START, $next',
  ];
  final follows =
      'STEREOTYPE_START|CLASS_SEPARATOR|IDENTIFIER|$_arrows|NEWLINE|EOF'.split(
        '|',
      );
  final entities = <String>[
    for (var i = 0; i < names.length; i++)
      for (final next
          in (i == 0 ? <String>['LPAREN', 'LBRACKET', ...follows] : follows))
        '${names[i]}, $next',
  ];
  return <String>[_statements, ...metadata, ...entities, ...metadata].join('|');
}

bool _isWordToken(int type) {
  return type >= T.USECASE && type <= T.IDENTIFIER;
}

bool _isLabelText(int type) {
  return type >= T.USECASE && type <= T.LABEL_SYMBOL;
}

void _lineEnd() {
  _lastEnd = _ends[_p - 1];
  if (_types[_p] == T.NEWLINE) {
    _p++;
  } else if (_types[_p] != T.EOF) {
    _noAlternative('NEWLINE|EOF');
  }
}

// The text of a name or string token, without its quotes.
Span _content(int k) {
  final trim = _types[k] == T.MARKDOWN_STRING
      ? 2
      : _types[k] == T.PLAIN_STRING
      ? 1
      : 0;
  return <int>[_starts[k] + trim, _ends[k] - trim];
}

DraftLabel _tokenLabel(int k) {
  final at = _content(k);
  return DraftLabel(
    text: sliceJs(_src, at[0], at[1]),
    type: _types[k] == T.MARKDOWN_STRING ? 'markdown' : 'text',
    span: at,
  );
}

String _generatedId(String label) {
  return label.replaceAll(_reNonWord, '_');
}

// An unquoted label runs to the next delimiter and is taken from the source as written.
DraftLabel _label() {
  final type = _types[_p];
  if (type == T.PLAIN_STRING || type == T.MARKDOWN_STRING) {
    return _tokenLabel(_p++);
  }
  if (!_isLabelText(type)) _noAlternative(_labels);
  final first = _p;
  while (_isLabelText(_types[_p])) {
    _p++;
  }
  final at = <int>[_starts[first], _ends[_p - 1]];
  return DraftLabel(text: sliceJs(_src, at[0], at[1]), type: 'text', span: at);
}

bool _isKey(int type) {
  return type == T.IDENTIFIER || type == T.PLAIN_STRING;
}

DraftProperty _property() {
  final key = _p;
  if (!_isKey(_types[_p])) _noAlternative('IDENTIFIER|PLAIN_STRING');
  _p++;
  _expect(T.COLON);
  final value = _p;
  final type = _types[_p];
  if (!_isKey(type) && type != T.TRUE && type != T.FALSE) {
    _noAlternative('IDENTIFIER|PLAIN_STRING|TRUE|FALSE');
  }
  _p++;
  final keySpan = _content(key);
  final valueSpan = _content(value);
  return DraftProperty(
    key: sliceJs(_src, keySpan[0], keySpan[1]),
    value: type == T.TRUE
        ? true
        : type == T.FALSE
        ? false
        : sliceJs(_src, valueSpan[0], valueSpan[1]),
    span: <int>[_starts[key], _ends[value]],
    keySpan: keySpan,
    valueSpan: valueSpan,
  );
}

// Whether another property follows. A comma or line breaks before the closing brace do not count,
// but Chevrotain looks only three tokens ahead, so a comma and two line breaks, or three line
// breaks, are taken for a separator and the brace after them is then an error.
bool _separatorAhead() {
  final a = _types[_p];
  final b = _types[_p + 1];
  final c = _types[_p + 2];
  if (a == T.COMMA) {
    return _isKey(b) || (b == T.NEWLINE && (c == T.NEWLINE || _isKey(c)));
  }
  if (a != T.NEWLINE) return false;
  return b == T.COMMA ||
      _isKey(b) ||
      (b == T.NEWLINE && (c == T.NEWLINE || c == T.COMMA || _isKey(c)));
}

List<DraftProperty> _metadata() {
  _expect(T.METADATA_START);
  final properties = <DraftProperty>[];
  while (_types[_p] == T.NEWLINE) {
    _p++;
  }
  if (_isKey(_types[_p])) {
    properties.add(_property());
    while (_separatorAhead()) {
      if (_types[_p] == T.COMMA) {
        _p++;
      } else {
        while (_types[_p] == T.NEWLINE) {
          _p++;
        }
        if (_types[_p] == T.COMMA) _p++;
      }
      while (_types[_p] == T.NEWLINE) {
        _p++;
      }
      properties.add(_property());
    }
    if (_types[_p] == T.COMMA) _p++;
    while (_types[_p] == T.NEWLINE) {
      _p++;
    }
  }
  _expect(T.RBRACE);
  return properties;
}

List<MetadataOccurrence> _occurrences(List<DraftProperty> properties) {
  return <MetadataOccurrence>[
    for (final p in properties)
      MetadataOccurrence(
        key: p.key,
        span: p.span,
        keySpan: p.keySpan,
        valueSpan: p.valueSpan,
      ),
  ];
}

void _classSuffix(List<String> classes, List<Span> spans) {
  do {
    _p++;
    final id = _expect(T.IDENTIFIER);
    classes.add(_image(id));
    spans.add(_span(id));
  } while (_types[_p] == T.COMMA);
}

// An id with an optional label in parentheses or brackets, or a string that stands for both.
_Item _name(bool brackets) {
  final k = _p;
  final type = _types[_p];
  late final DraftLabel itemLabel;
  var id = '';
  UseCaseShape? shape;
  if (type == T.IDENTIFIER) {
    _p++;
    id = _image(k);
    final open = _types[_p];
    if (open == T.LPAREN || (brackets && open == T.LBRACKET)) {
      _p++;
      itemLabel = _label();
      _expect(open == T.LPAREN ? T.RPAREN : T.RBRACKET);
      shape = open == T.LPAREN ? 'ellipse' : 'rect';
    } else {
      itemLabel = _tokenLabel(k);
    }
  } else if (type == T.PLAIN_STRING || type == T.MARKDOWN_STRING) {
    _p++;
    itemLabel = _tokenLabel(k);
    id = _generatedId(itemLabel.text);
  } else {
    _noAlternative(_names);
  }
  return _Item(
    id: id,
    label: itemLabel,
    span: _content(k),
    generated: type != T.IDENTIFIER,
    shape: shape,
    classes: <String>[],
    classSpans: <Span>[],
    explicit: false,
    nodeSpan: <int>[0, 0],
  );
}

_Item _element(bool actor) {
  final first = _p;
  final item = _name(!actor);
  if (actor) item.shape = null;
  if (_types[_p] == T.METADATA_START) item.metadata = _metadata();
  if (_types[_p] == T.STEREOTYPE_START) {
    _p++;
    final text = _expect(T.STEREOTYPE_TEXT);
    _expect(T.STEREOTYPE_END);
    item.stereotype = _image(text).trim();
    item.stereotypeSpan = _span(text);
  }
  if (_types[_p] == T.CLASS_SEPARATOR) {
    _classSuffix(item.classes, item.classSpans);
  }
  item.explicit =
      item.shape != null ||
      item.metadata != null ||
      (item.stereotype != null && item.stereotype!.isNotEmpty);
  item.nodeSpan = <int>[_starts[first], _ends[_p - 1]];
  return item;
}

DraftElement _draft(_Item item, String kind) {
  return DraftElement(
    id: item.id,
    kind: kind,
    label: item.label,
    span: item.span,
    generated: item.generated,
    parent: _parent,
    shape: item.shape,
    metadata: item.metadata,
    stereotype: item.stereotype,
    classes: item.classes,
  );
}

DraftEndpoint _endpoint(_Item item, bool declares) {
  return DraftEndpoint(
    id: item.id,
    label: item.label,
    span: item.span,
    generated: item.generated,
    declares: declares,
    classed: item.classes.isNotEmpty,
  );
}

NodeOccurrence _occurrence(_Item item, bool defines) {
  return NodeOccurrence(
    id: item.id,
    span: item.nodeSpan,
    idSpan: item.span,
    labelSpan: item.label.span,
    defines: defines ? true : null,
    stereotypeSpan: item.stereotypeSpan,
    metadata: item.metadata != null ? _occurrences(item.metadata!) : null,
    classSpans: item.classSpans.isNotEmpty ? item.classSpans : null,
  );
}

// Whether a label and then one of the operators that can close it come next.
bool _labeledRight(int closers) {
  if (_types[_p] < T.USECASE || _types[_p] > T.MARKDOWN_STRING) return false;
  for (var k = _p + 1; ; k++) {
    final type = _types[k];
    if (type == T.MARKERLESS_SOLID || (_flags[type] & closers) != 0) {
      return true;
    }
    if (type < T.USECASE || type > T.MARKDOWN_STRING) return false;
  }
}

// Each dash beyond the second asks for one more rank between the two ends.
int _minimumLength(int k) {
  final dashes =
      _ends[k] - _starts[k] - (_types[k] == T.MARKERLESS_SOLID ? 0 : 1);
  return math.max<int>(1, dashes - 1);
}

_Tail _relationTail() {
  final first = _p;
  String? explicitId;
  Span? explicitIdSpan;
  RelationshipType relType = 'association';
  var arrowType = Arrow.SOLID_ARROW;
  DraftLabel? relLabel;
  var minlen = 1;

  if (_types[_p] == T.IDENTIFIER && _types[_p + 1] == T.AT) {
    explicitId = _image(_p);
    explicitIdSpan = _span(_p);
    _p += 2;
  }
  final k = _p;
  final type = _types[_p++];
  if (type == T.DEPENDENCY_ARROW) {
    _expect(T.COLON);
    if (_types[_p] != T.INCLUDE && _types[_p] != T.EXTEND) {
      _noAlternative('INCLUDE|EXTEND');
    }
    relType = _types[_p] == T.INCLUDE ? 'include' : 'extend';
    relLabel = DraftLabel(text: relType, type: 'text', span: _span(_p));
    _p++;
  } else if (type == T.GENERALIZATION) {
    relType = 'generalization';
  } else if (type == T.FORWARD_SOLID) {
    minlen = _minimumLength(k);
  } else if (type == T.BACKWARD_SOLID) {
    arrowType = Arrow.BACK_ARROW;
    // Only the shortest operator can open a label: `A <-- label -- B`.
    if (_ends[k] - _starts[k] == 3 && _labeledRight(0)) {
      relLabel = _label();
      minlen = _minimumLength(_expect(T.MARKERLESS_SOLID));
    } else {
      minlen = _minimumLength(k);
    }
  } else if (type == T.MARKERLESS_SOLID) {
    arrowType = Arrow.LINE_SOLID;
    if (_ends[k] - _starts[k] == 2 && _labeledRight(_closesLabel)) {
      relLabel = _label();
      final close = _types[_p];
      if (close == T.FORWARD_SOLID) {
        arrowType = Arrow.SOLID_ARROW;
      } else if (close == T.FORWARD_CIRCLE) {
        arrowType = Arrow.CIRCLE_ARROW;
      } else if (close == T.FORWARD_CROSS) {
        arrowType = Arrow.CROSS_ARROW;
      } else if (close != T.MARKERLESS_SOLID) {
        _noAlternative(
          'FORWARD_SOLID|MARKERLESS_SOLID|FORWARD_CIRCLE|FORWARD_CROSS',
        );
      }
      if (arrowType == Arrow.SOLID_ARROW || arrowType == Arrow.LINE_SOLID) {
        minlen = _minimumLength(_p);
      }
      _p++;
    } else {
      minlen = _minimumLength(k);
    }
  } else if (type == T.FORWARD_CIRCLE) {
    arrowType = Arrow.CIRCLE_ARROW;
  } else if (type == T.FORWARD_CROSS) {
    arrowType = Arrow.CROSS_ARROW;
  } else if (type == T.BACKWARD_CIRCLE || type == T.BACKWARD_CROSS) {
    arrowType = type == T.BACKWARD_CIRCLE
        ? Arrow.CIRCLE_ARROW_REVERSED
        : Arrow.CROSS_ARROW_REVERSED;
    if (_labeledRight(0)) {
      relLabel = _label();
      _expect(T.MARKERLESS_SOLID);
    }
  } else {
    _p--;
    _noAlternative(_arrows);
  }
  final target = _element(false);
  return _Tail(
    explicitId: explicitId,
    explicitIdSpan: explicitIdSpan,
    type: relType,
    arrowType: arrowType,
    label: relLabel,
    minlen: minlen,
    target: target,
    span: <int>[_starts[first], _ends[_p - 1]],
  );
}

GraphStatement _statement(String kind) {
  return GraphStatement(kind: kind, span: <int>[0, 0]);
}

GraphStatement _relationship(
  _Item source,
  bool declaration,
  _Tail tail,
  List<NodeOccurrence> nodes,
) {
  final target = tail.target;
  if (target.explicit) _drafts.elements.add(_draft(target, 'usecase'));
  _drafts.relationships.add(
    DraftRelationship(
      source: _endpoint(source, declaration),
      target: _endpoint(target, target.explicit),
      span: tail.span,
      id: tail.explicitId,
      idSpan: tail.explicitIdSpan,
      type: tail.type,
      arrowType: tail.arrowType,
      label: tail.label,
      minlen: tail.minlen,
    ),
  );
  nodes.add(_occurrence(target, target.explicit));
  final out = _statement('edge');
  out.nodes = nodes;
  out.edges = <EdgeOccurrence>[
    EdgeOccurrence(
      id: tail.explicitId ?? 'edge-${_edgeCount++}',
      span: out.span,
      idSpan: tail.explicitIdSpan,
      labelSpan: tail.label?.span,
    ),
  ];
  return out;
}

GraphStatement _declaration(List<NodeOccurrence> nodes) {
  final out = _statement('node');
  out.nodes = nodes;
  return out;
}

// `actor A, B` declares several actors; at the top level `actor A --> B` declares one and relates it.
GraphStatement _actors(bool top) {
  _p++;
  final items = <_Item>[_element(true)];
  _Tail? tail;
  if (_types[_p] == T.COMMA) {
    do {
      _p++;
      items.add(_element(true));
    } while (_types[_p] == T.COMMA);
  } else if (top && (_flags[_types[_p]] & _relation) != 0) {
    tail = _relationTail();
  }
  _lineEnd();
  for (final item in items) {
    _drafts.elements.add(_draft(item, 'actor'));
  }
  final nodes = <NodeOccurrence>[
    for (final item in items) _occurrence(item, true),
  ];
  return tail != null
      ? _relationship(items[0], true, tail, nodes)
      : _declaration(nodes);
}

GraphStatement _entity(bool top) {
  final source = _element(false);
  final tail = top && (_flags[_types[_p]] & _relation) != 0
      ? _relationTail()
      : null;
  _lineEnd();
  if (tail == null) {
    source.explicit = true;
    source.shape ??= 'ellipse';
  }
  if (source.explicit) _drafts.elements.add(_draft(source, 'usecase'));
  final nodes = <NodeOccurrence>[_occurrence(source, source.explicit)];
  return tail != null
      ? _relationship(source, source.explicit, tail, nodes)
      : _declaration(nodes);
}

GraphStatement _boundary() {
  _p++;
  final named = _name(true);
  final group = DraftBoundary(
    id: named.id,
    label: named.label,
    span: named.span,
    generated: named.generated,
    classes: named.classes,
  );
  final inline = _types[_p] == T.METADATA_START ? _metadata() : null;
  if (_types[_p] == T.CLASS_SEPARATOR) {
    _classSuffix(named.classes, named.classSpans);
  }
  _lineEnd();
  _drafts.boundaries.add(group);
  _parent = group;
  final children = <GraphStatement>[];
  while ((_flags[_types[_p]] & _boundaryLine) != 0) {
    children.add(_parseLine(false));
  }
  _parent = null;
  final end = _expect(T.END);
  _lineEnd();
  final out = _statement('group');
  out.group = group.id;
  out.idSpan = group.span;
  out.titleSpan = group.label.span;
  out.endSpan = _span(end);
  out.classSpans = named.classSpans;
  if (children.isNotEmpty) out.children = children;
  if (inline != null) {
    out.metadata = _occurrences(inline);
    _drafts.metadata.add(
      DraftMetadata(
        target: group.id,
        span: group.span,
        properties: inline,
        statement: out,
      ),
    );
  }
  return out;
}

String _style() {
  final first = _p;
  final type = _types[_p];
  if (_isWordToken(type) || type == T.CSS_IDENTIFIER) {
    _p++;
  } else if (type == T.MARKERLESS_SOLID) {
    _p++;
    if (!_isWordToken(_types[_p])) _mismatch('WORD');
    _p++;
  } else {
    _noAlternative('WORD|CSS_IDENTIFIER|MARKERLESS_SOLID');
  }
  _expect(T.COLON);
  if ((_flags[_types[_p]] & _stylePart) == 0) {
    _fail(
      "Expecting: expecting at least one iteration which starts with one of these possible Token sequences::\n  <[${_styleParts.replaceAll('|', '] ,[')}]>\nbut found: '${_image(_p)}'",
    );
  }
  while ((_flags[_types[_p]] & _stylePart) != 0) {
    _p++;
  }
  // The value is taken from the source, so the spaces inside `1px solid red` survive.
  return sliceJs(_src, _starts[first], _ends[_p - 1]).replaceAll(r'\,', ',');
}

List<String> _styles() {
  final out = <String>[_style()];
  while (_types[_p] == T.COMMA) {
    _p++;
    out.add(_style());
  }
  return out;
}

List<int> _identifiers() {
  final out = <int>[_expect(T.IDENTIFIER)];
  while (_types[_p] == T.COMMA) {
    _p++;
    out.add(_expect(T.IDENTIFIER));
  }
  return out;
}

NodeOccurrence _reference(int k) {
  final at = _content(k);
  return NodeOccurrence(id: _image(k), span: at, idSpan: at);
}

GraphStatement _topStatement() {
  final k = _p;
  final type = _types[_p];
  GraphStatement out;
  if (type == T.ACC_TITLE_LINE ||
      type == T.ACC_DESCR_LINE ||
      type == T.ACC_DESCR_BLOCK) {
    _p++;
    final text = _image(k);
    if (type == T.ACC_DESCR_BLOCK) {
      _drafts.accDescription = sliceJs(
        text,
        text.indexOf('{') + 1,
        text.lastIndexOf('}'),
      ).trim();
    } else if (type == T.ACC_DESCR_LINE) {
      _drafts.accDescription = sliceJs(text, text.indexOf(':') + 1).trim();
    } else {
      _drafts.accTitle = sliceJs(text, text.indexOf(':') + 1).trim();
    }
    out = _statement(type == T.ACC_TITLE_LINE ? 'accTitle' : 'accDescr');
  } else if (type == T.DIRECTION) {
    _p++;
    final value = _types[_p];
    if (value < T.TD || value > T.RL) _noAlternative('TD|TB|BT|LR|RL');
    _drafts.direction = value == T.TD ? 'TB' : _image(_p);
    _p++;
    out = _statement('direction');
  } else if (type == T.ACTOR) {
    return _actors(true);
  } else if (type == T.SYSTEM_BOUNDARY) {
    return _boundary();
  } else if (type == T.NOTE) {
    _p++;
    _expect(T.FOR);
    final target = _expect(T.IDENTIFIER);
    final text = _label();
    _drafts.notes.add(
      DraftNote(target: _image(target), span: _span(target), label: text),
    );
    out = _statement('note');
    out.ref = 'note-${_noteCount++}';
    out.refSpan = text.span;
    out.nodes = <NodeOccurrence>[_reference(target)];
  } else if (type == T.JSON_DECLARATION_START) {
    _p++;
    final literal = _expect(T.JSON_OBJECT_LITERAL);
    final classes = <String>[];
    final classSpans = <Span>[];
    if (_types[_p] == T.CLASS_SEPARATOR) _classSuffix(classes, classSpans);
    var from = _starts[k] + 4;
    while (charCodeAt(_src, from) == 32 || charCodeAt(_src, from) == 9) {
      from++;
    }
    var to = from;
    while (isWord(charCodeAt(_src, to))) {
      to++;
    }
    final json = DraftJson(
      id: sliceJs(_src, from, to),
      value: <String, Object?>{},
      propertyOrder: <String, List<String>>{},
      span: <int>[from, to],
      classes: classes,
    );
    _drafts.jsons.add(json);
    _pendingJson.add((json, literal));
    out = _statement('json');
    out.nodes = <NodeOccurrence>[
      NodeOccurrence(
        id: json.id,
        span: json.span,
        idSpan: json.span,
        defines: true,
        classSpans: classSpans,
      ),
    ];
    out.classSpans = classSpans;
  } else if (type == T.CLASS_DEF) {
    _p++;
    final ids = _identifiers();
    _drafts.classDefs.add(
      DraftClassDef(
        ids: <String>[for (final id in ids) _image(id)],
        styles: _styles(),
      ),
    );
    out = _statement('classDef');
    out.ref = _image(ids[0]);
    out.refSpan = _span(ids[0]);
  } else if (type == T.CLASS) {
    _p++;
    final targets = _identifiers();
    final classes = _identifiers();
    _drafts.classes.add(
      DraftClassAssign(
        targets: <DraftClassTarget>[
          for (final id in targets)
            DraftClassTarget(id: _image(id), span: _span(id)),
        ],
        classes: <String>[for (final id in classes) _image(id)],
      ),
    );
    out = _statement('classAssign');
    out.ref = _image(classes[0]);
    out.refSpan = _span(classes[0]);
    out.nodes = <NodeOccurrence>[for (final id in targets) _reference(id)];
  } else if (type == T.STYLE) {
    _p++;
    final target = _expect(T.IDENTIFIER);
    _drafts.styles.add(
      DraftStyleAssign(
        target: _image(target),
        span: _span(target),
        styles: _styles(),
      ),
    );
    out = _statement('style');
    out.nodes = <NodeOccurrence>[_reference(target)];
  } else {
    final next = _types[_p + 1];
    if (next == T.METADATA_START) {
      if ((_flags[_types[_p + 2]] & _metadataFirst) == 0) {
        _noAlternative(_statementSequences());
      }
      _p++;
      final target = _reference(k);
      if (type != T.IDENTIFIER) {
        target.id = _generatedId(sliceJs(_src, target.span[0], target.span[1]));
      }
      final assigned = _metadata();
      out = _statement('metadata');
      out.nodes = <NodeOccurrence>[target];
      out.metadata = _occurrences(assigned);
      _drafts.metadata.add(
        DraftMetadata(
          target: target.id,
          span: target.span,
          properties: assigned,
          statement: out,
        ),
      );
    } else {
      final follows =
          (_flags[next] & _followsName) != 0 ||
          (type == T.IDENTIFIER && (next == T.LPAREN || next == T.LBRACKET));
      // Mermaid turns away the PlantUML statements people are most likely to try.
      if (!follows ||
          (type == T.IDENTIFIER &&
              _forbidden.contains(_image(k).toLowerCase()))) {
        _noAlternative(_statementSequences());
      }
      return _entity(true);
    }
  }
  _lineEnd();
  return out;
}

GraphStatement _parseLine(bool top) {
  final k = _p;
  final type = _types[_p];
  if (type == T.NEWLINE) {
    _p++;
    return GraphStatement(kind: 'blank', span: _span(k));
  }
  if (type == T.COMMENT) {
    _p++;
    _lineEnd();
    return GraphStatement(kind: 'comment', span: _span(k));
  }
  final out = top
      ? _topStatement()
      : type == T.ACTOR
      ? _actors(false)
      : _entity(false);
  out.span = <int>[_starts[k], _lastEnd];
  if (out.edges != null) {
    for (final edge in out.edges!) {
      edge.span = out.span;
    }
  }
  return out;
}

UsecaseModel parseUsecase(String source, [String? title]) {
  _src = source;
  final tokens = tokenize(source);
  _types = tokens.types;
  _starts = tokens.starts;
  _ends = tokens.ends;
  _p = 0;
  _drafts = emptyDrafts();
  _parent = null;
  _pendingJson = <(DraftJson, int)>[];
  _edgeCount = 0;
  _noteCount = 0;
  try {
    final header = _expect(T.USECASE);
    _lineEnd();
    final statements = <GraphStatement>[];
    while ((_flags[_types[_p]] & _line) != 0) {
      statements.add(_parseLine(true));
    }
    if (_types[_p] != T.EOF) {
      _fail('Redundant input, expecting EOF but found: ${_image(_p)}');
    }
    // The whole text has to be well formed before the JSON in it is looked at, as in Mermaid.
    for (final (json, literal) in _pendingJson) {
      final parsed = parseOrderedJson(
        _image(literal),
        () => lineColumn(source, _starts[literal]),
      );
      json.value = parsed.value;
      json.propertyOrder = parsed.propertyOrder;
    }
    return resolveUsecase(source, _drafts, _span(header), statements, title);
  } finally {
    _src = '';
    _types = const <int>[];
    _starts = const <int>[];
    _ends = const <int>[];
    _pendingJson = <(DraftJson, int)>[];
  }
}

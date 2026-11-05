// Upstream: src/diagrams/block/parser.ts

import '../../errors.dart';
import 'db.dart';
import 'lexer.dart';
import 'tokens.dart';
import 'types.dart';

class _NodeInfo {
  final String id;
  final String? label;
  final String? typeStr;
  final List<String>? directions;

  const _NodeInfo({
    required this.id,
    this.label,
    this.typeStr,
    this.directions,
  });
}

class _Frame {
  final List<Statement> list;
  final Statement? header;

  const _Frame({required this.list, required this.header});
}

const String _statementStart =
    "'NODE_ID', 'COLUMNS', 'SPACE_BLOCK', 'BLOCK_DIAGRAM_KEY', 'id-block', 'classDef', 'class', 'style'";

// The grammar inlines a document's last statement when it is a list.
List<Statement> _closeDocument(List<Statement> list) {
  if (list.isEmpty) return list;
  final last = list.last;
  if (last is! List<Statement>) return list;
  list.removeLast();
  return <Statement>[...list, ...last];
}

int _parseSpanOrSpace(String s) => int.tryParse(s) ?? 0x3fffffffffffffff;

int _parseColumns(String s) =>
    int.tryParse(s) ??
    ((double.tryParse(s)?.isFinite ?? false) ? 0x3fffffffffffffff : 0);

void parseBlock(String src, BlockDb db) {
  final tok = tokenize(src);
  final types = tok.types;
  final texts = tok.texts;
  final starts = tok.starts;
  var i = 0;

  Never fail(String expected) {
    final t = types[i];
    if (t == T.ERROR) throw syntaxError('block', src, starts[i], '', true);
    throw syntaxError(
      'block',
      src,
      starts[i],
      "Expecting $expected, got '${TOKEN_NAMES[t]}'",
    );
  }

  String expect(int type) {
    if (types[i] != type) fail("'${TOKEN_NAMES[type]}'");
    return texts[i++];
  }

  _NodeInfo node() {
    final id = expect(T.NODE_ID);
    if (types[i] == T.NODE_DSTART) {
      final open = texts[i++];
      final label = expect(T.STR);
      return _NodeInfo(
        id: id,
        label: label,
        typeStr: open + expect(T.NODE_DEND),
      );
    }
    if (types[i] == T.BLOCK_ARROW_START) {
      final open = texts[i++];
      final label = expect(T.STR);
      final directions = <String>[expect(T.DIR)];
      while (types[i] == T.DIR) {
        directions.add(texts[i++]);
      }
      return _NodeInfo(
        id: id,
        label: label,
        typeStr: open + expect(T.BLOCK_ARROW_END),
        directions: directions,
      );
    }
    return _NodeInfo(id: id);
  }

  Statement nodeStatement() {
    final first = node();
    final size = types[i] == T.SIZE ? _parseSpanOrSpace(texts[i++]) : 1;
    var from = Block(
      id: first.id,
      label: first.label,
      type: db.typeStr2TypeFn(first.typeStr),
      directions: first.directions,
      widthInColumns: size,
    );
    List<Block>? chain;
    while (types[i] == T.LINK || types[i] == T.START_LINK) {
      var label = '';
      if (types[i++] == T.START_LINK) {
        expect(T.LINK_LABEL);
        label = expect(T.STR);
        expect(T.LINK);
      }
      final link = texts[i - 1];
      final to = node();
      final arrowTypeEnd = db.edgeStrToEdgeDataFn(link);
      final arrowTypeStart = db.edgeStrToEdgeStartDataFn(link);
      final thickness = db.edgeStrToThicknessFn(link);
      final pattern = db.edgeStrToPatternFn(link);
      // Mermaid keeps only the last link of `A --> B --> C` and loses its start. Here every link counts.
      chain ??= <Block>[
        Block(
          id: from.id,
          label: from.label,
          type: from.type,
          directions: from.directions,
        ),
      ];
      from = Block(
        id: to.id,
        label: to.label,
        type: db.typeStr2TypeFn(to.typeStr),
        directions: to.directions,
      );
      final prevId = chain.last.id;
      chain.addAll(<Block>[
        Block(
          id: '$prevId-${to.id}',
          start: prevId,
          end: to.id,
          label: label,
          type: 'edge',
          thickness: thickness,
          pattern: pattern,
          directions: to.directions,
          arrowTypeEnd: arrowTypeEnd,
          arrowTypeStart: arrowTypeStart,
        ),
        from,
      ]);
    }
    return chain ?? from;
  }

  expect(T.KEY);
  // Composites nest without recursion: each open one keeps the statement list of its parent.
  final open = <_Frame>[];
  var list = <Statement>[];
  while (true) {
    switch (types[i]) {
      case T.NODE_ID:
        list.add(nodeStatement());
      case T.COLUMNS:
        list.add(
          Block(type: 'column-setting', columns: _parseColumns(texts[i++])),
        );
      case T.SPACE_BLOCK:
        final width = _parseSpanOrSpace(texts[i++]);
        list.add(
          Block(
            id: db.generateId(),
            type: 'space',
            label: '',
            width: width,
            children: <Block>[],
          ),
        );
      case T.KEY:
        i++;
        open.add(_Frame(list: list, header: null));
        list = <Statement>[];
      case T.ID_BLOCK:
        i++;
        if (types[i] != T.NODE_ID) fail("'NODE_ID'");
        open.add(_Frame(list: list, header: nodeStatement()));
        list = <Statement>[];
      case T.end:
        if (open.isEmpty || list.isEmpty) fail(_statementStart);
        final frame = open.removeLast();
        i++;
        final id = db.generateId();
        final children = _closeDocument(list);
        list = frame.list;
        final header = frame.header;
        if (header == null) {
          list.add(
            Block(id: id, type: 'composite', label: '', children: children),
          );
        } else if (header is Block) {
          list.add(header.copyWith(type: 'composite', children: children));
        } else {
          list.add(Block(id: '', type: 'composite', children: children));
        }
      case T.CLASSDEF:
        i++;
        final id = expect(T.CLASSDEF_ID).trim();
        list.add(
          Block(
            type: 'classDef',
            id: id,
            css: expect(T.CLASSDEF_STYLEOPTS).trim(),
          ),
        );
      case T.CLASS:
        i++;
        final id = expect(T.CLASSENTITY_IDS).trim();
        list.add(
          Block(
            type: 'applyClass',
            id: id,
            styleClass: expect(T.STYLECLASS).trim(),
          ),
        );
      case T.STYLE:
        i++;
        final id = expect(T.STYLE_ENTITY_IDS).trim();
        list.add(
          Block(
            type: 'applyStyles',
            id: id,
            stylesStr: expect(T.STYLE_DEFINITION_DATA).trim(),
          ),
        );
      case T.EOF:
        if (open.isNotEmpty) fail("$_statementStart, 'end'");
        if (list.isEmpty) fail(_statementStart);
        db.setHierarchy(_closeDocument(list));
        return;
      default:
        fail(
          list.isEmpty
              ? _statementStart
              : _statementStart + (open.isNotEmpty ? ", 'end'" : ", 'EOF'"),
        );
    }
  }
}

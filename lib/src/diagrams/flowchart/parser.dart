// Upstream: src/diagrams/flowchart/parser.ts

import 'dart:typed_data';

import '../../errors.dart';
import 'db.dart';
import 'lexer.dart';
import 'tokens.dart';
import 'types.dart';

final Uint8List _id = () {
  final table = Uint8List(T.EOF + 1);
  for (final t in const <int>[
    T.NUM,
    T.NODE_STRING,
    T.DOWN,
    T.MINUS,
    T.DEFAULT,
    T.COMMA,
    T.COLON,
    T.AMP,
    T.BRKT,
    T.MULT,
    T.UNICODE_TEXT,
  ]) {
    table[t] = 1;
  }
  return table;
}();

final Uint8List _alphanum = () {
  final table = Uint8List(T.EOF + 1);
  for (final t in const <int>[
    T.NUM,
    T.UNICODE_TEXT,
    T.NODE_STRING,
    T.DIR,
    T.DOWN,
    T.MINUS,
    T.COMMA,
    T.COLON,
    T.AMP,
    T.BRKT,
    T.MULT,
  ]) {
    table[t] = 1;
  }
  return table;
}();

final Uint8List _noTags = () {
  final table = Uint8List(T.EOF + 1);
  for (final t in const <int>[
    T.NUM,
    T.NODE_STRING,
    T.SPACE,
    T.MINUS,
    T.AMP,
    T.UNICODE_TEXT,
    T.COLON,
    T.MULT,
    T.BRKT,
    T.STYLE,
    T.LINKSTYLE,
    T.CLASSDEF,
    T.CLASS,
    T.CLICK,
    T.GRAPH,
    T.DIR,
    T.subgraph,
    T.end,
    T.DOWN,
    T.UP,
    T.START_LINK,
  ]) {
    table[t] = 1;
  }
  return table;
}();

final Uint8List _stylePart = () {
  final table = Uint8List(T.EOF + 1);
  for (final t in const <int>[
    T.NUM,
    T.NODE_STRING,
    T.COLON,
    T.SPACE,
    T.BRKT,
    T.STYLE,
  ]) {
    table[t] = 1;
  }
  return table;
}();

class _Frame {
  _Frame({
    required this.id,
    required this.title,
    required this.list,
    required this.collect,
  });

  final FlowText? id;
  final FlowText? title;
  List<DocItem> list;
  bool collect;
}

const String _textTokens = "'UNICODE_TEXT', 'TEXT', 'TAGSTART'";
const List<String> _noItems = <String>[];

// Mermaid trims whitespace between a closing brace and the end of its line before parsing.
final RegExp _reBraceTrail = RegExp(r'}\s*\n');

void parseFlowchart(String source, FlowDb db) {
  final src = source.contains('}')
      ? source.replaceAll(_reBraceTrail, '}\n')
      : source;
  final tokens = tokenize(src);
  final types = tokens.types;
  final texts = tokens.texts;
  final starts = tokens.starts;
  var i = 0;
  String? pendingData;

  Never fail(String expected) {
    final t = types[i];
    final at = identical(src, source)
        ? starts[i]
        : inputOffset(<List<Edit>>[
            replacements(source, _reBraceTrail, 2),
          ], starts[i]);
    if (t == T.ERROR) throw syntaxError('flowchart', source, at, '', true);
    throw syntaxError(
      'flowchart',
      source,
      at,
      "Expecting $expected, got '${TOKEN_NAMES[t]}'",
    );
  }

  String expect(int type, [String also = '']) {
    if (types[i] != type) {
      fail("'${TOKEN_NAMES[type]}'${also.isNotEmpty ? ', $also' : ''}");
    }
    return texts[i++];
  }

  void separator() {
    final t = types[i];
    if (t != T.NEWLINE && t != T.SEMI && t != T.EOF) {
      fail("'SEMI', 'NEWLINE', 'EOF'");
    }
    i++;
  }

  String idString() {
    if (_id[types[i]] == 0) fail("'NODE_STRING'");
    var s = texts[i++];
    while (_id[types[i]] == 1) {
      s += texts[i++];
    }
    return s;
  }

  String alphaNum() {
    if (_alphanum[types[i]] == 0) fail("'NODE_STRING'");
    var s = texts[i++];
    while (_alphanum[types[i]] == 1) {
      s += texts[i++];
    }
    return s;
  }

  FlowText text() {
    final t = types[i];
    LabelType type;
    if (t == T.STR) {
      type = 'string';
    } else if (t == T.MD_STR) {
      type = 'markdown';
    } else if (t == T.TEXT ||
        t == T.TAGSTART ||
        t == T.TAGEND ||
        t == T.UNICODE_TEXT) {
      type = 'text';
    } else {
      fail("$_textTokens, 'TAGEND', 'STR', 'MD_STR'");
    }
    var s = texts[i++];
    while (true) {
      final n = types[i];
      if (n != T.TEXT &&
          n != T.TAGSTART &&
          n != T.TAGEND &&
          n != T.UNICODE_TEXT) {
        break;
      }
      s += texts[i++];
    }
    return FlowText(text: s, type: type);
  }

  void closed(int type) {
    expect(type, _textTokens);
  }

  FlowText edgeText() {
    final t = types[i];
    LabelType type;
    if (t == T.STR) {
      type = 'string';
    } else if (t == T.MD_STR) {
      type = 'markdown';
    } else if (t == T.EDGE_TEXT || t == T.UNICODE_TEXT) {
      type = 'text';
    } else {
      fail("'EDGE_TEXT', 'STR', 'MD_STR'");
    }
    var s = texts[i++];
    while (types[i] == T.EDGE_TEXT || types[i] == T.UNICODE_TEXT) {
      s += texts[i++];
    }
    return FlowText(text: s, type: type);
  }

  FlowText textNoTags() {
    final t = types[i];
    LabelType type;
    if (t == T.STR) {
      type = 'text';
    } else if (t == T.MD_STR) {
      type = 'markdown';
    } else if (_noTags[t] == 1) {
      type = 'text';
    } else {
      fail("'NODE_STRING', 'STR', 'MD_STR'");
    }
    var s = texts[i++];
    while (_noTags[types[i]] == 1) {
      s += texts[i++];
    }
    return FlowText(text: s, type: type);
  }

  String shapeData() {
    var s = texts[i++];
    while (types[i] == T.SHAPE_DATA) {
      s += texts[i++];
    }
    return s;
  }

  String vertex() {
    final id = idString();
    FlowText label;
    switch (types[i]) {
      case T.SQS:
        i++;
        label = text();
        closed(T.SQE);
        db.addVertex(id, label, 'square');
      case T.DOUBLECIRCLESTART:
        i++;
        label = text();
        closed(T.DOUBLECIRCLEEND);
        db.addVertex(id, label, 'doublecircle');
      case T.PS:
        i++;
        if (types[i] == T.PS) {
          i++;
          label = text();
          closed(T.PE);
          expect(T.PE);
          db.addVertex(id, label, 'circle');
        } else {
          label = text();
          closed(T.PE);
          db.addVertex(id, label, 'round');
        }
      case T.ELLIPSE_START:
        i++;
        label = text();
        closed(T.ELLIPSE_END);
        db.addVertex(id, label, 'ellipse');
      case T.STADIUMSTART:
        i++;
        label = text();
        closed(T.STADIUMEND);
        db.addVertex(id, label, 'stadium');
      case T.SUBROUTINESTART:
        i++;
        label = text();
        closed(T.SUBROUTINEEND);
        db.addVertex(id, label, 'subroutine');
      case T.VERTEX_WITH_PROPS_START:
        i++;
        final field = expect(T.NODE_STRING);
        expect(T.COLON);
        final value = expect(T.NODE_STRING);
        expect(T.PIPE);
        label = text();
        closed(T.SQE);
        db.addVertex(id, label, 'rect', null, null, null, <String, String>{
          field: value,
        });
      case T.CYLINDERSTART:
        i++;
        label = text();
        closed(T.CYLINDEREND);
        db.addVertex(id, label, 'cylinder');
      case T.DIAMOND_START:
        i++;
        if (types[i] == T.DIAMOND_START) {
          i++;
          label = text();
          closed(T.DIAMOND_STOP);
          expect(T.DIAMOND_STOP);
          db.addVertex(id, label, 'hexagon');
        } else {
          label = text();
          closed(T.DIAMOND_STOP);
          db.addVertex(id, label, 'diamond');
        }
      case T.TAGEND:
        i++;
        label = text();
        closed(T.SQE);
        db.addVertex(id, label, 'odd');
      case T.TRAPSTART:
        i++;
        label = text();
        if (types[i] == T.INVTRAPEND) {
          i++;
          db.addVertex(id, label, 'lean_right');
        } else {
          closed(T.TRAPEND);
          db.addVertex(id, label, 'trapezoid');
        }
      case T.INVTRAPSTART:
        i++;
        label = text();
        if (types[i] == T.TRAPEND) {
          i++;
          db.addVertex(id, label, 'lean_left');
        } else {
          closed(T.INVTRAPEND);
          db.addVertex(id, label, 'inv_trapezoid');
        }
      default:
        db.addVertex(id);
    }
    return id;
  }

  String styledVertex() {
    final id = vertex();
    if (types[i] == T.STYLE_SEPARATOR) {
      i++;
      db.setClass(id, idString());
    }
    return id;
  }

  List<String> node() {
    final ids = <String>[styledVertex()];
    pendingData = null;
    while (true) {
      final data = types[i] == T.SHAPE_DATA ? shapeData() : null;
      if (types[i] != T.SPACE) {
        pendingData = data;
        return ids;
      }
      do {
        i++;
      } while (types[i] == T.SPACE);
      if (types[i] != T.AMP) {
        if (data != null) fail("'AMP'");
        return ids;
      }
      i++;
      if (types[i] != T.SPACE) fail("'SPACE'");
      do {
        i++;
      } while (types[i] == T.SPACE);
      final next = styledVertex();
      if (data != null) {
        db.addVertex(
          ids[ids.length - 1],
          null,
          null,
          null,
          null,
          null,
          null,
          data,
        );
      }
      ids.add(next);
    }
  }

  FlowLinkInfo link() {
    String? id;
    if (types[i] == T.LINK_ID) id = texts[i++];
    if (types[i] == T.LINK) {
      final info = db.destructLink(texts[i++]);
      if (id != null) info.id = id;
      if (types[i] == T.PIPE) {
        i++;
        info.text = text();
        closed(T.PIPE);
        if (types[i] == T.SPACE) i++;
      }
      return info;
    }
    if (types[i] == T.START_LINK) {
      final start = texts[i++];
      final label = edgeText();
      final end = expect(T.LINK, "'EDGE_TEXT'");
      final info = db.destructLink(end, start);
      info.text = label;
      if (id != null) info.id = id;
      return info;
    }
    fail("'LINK', 'START_LINK'");
  }

  List<String> vertexStatement(bool collect) {
    var stmt = node();
    if (pendingData != null) {
      db.addVertex(
        stmt[stmt.length - 1],
        null,
        null,
        null,
        null,
        null,
        null,
        pendingData,
      );
    }
    var nodes = stmt;
    while (true) {
      final t = types[i];
      if (t != T.LINK && t != T.START_LINK && t != T.LINK_ID) return nodes;
      final info = link();
      final next = node();
      if (pendingData != null) {
        db.addVertex(
          next[next.length - 1],
          null,
          null,
          null,
          null,
          null,
          null,
          pendingData,
        );
      }
      db.addLink(stmt, next, info);
      if (collect) nodes = <String>[...next, ...nodes];
      stmt = next;
    }
  }

  String style() {
    if (_stylePart[types[i]] == 0) {
      fail("'NODE_STRING', 'NUM', 'COLON', 'BRKT'");
    }
    var s = texts[i++];
    while (_stylePart[types[i]] == 1) {
      s += texts[i++];
    }
    return s;
  }

  List<String> stylesOpt() {
    final out = <String>[style()];
    while (types[i] == T.COMMA) {
      i++;
      out.add(style());
    }
    return out;
  }

  void linkStyleStatement() {
    i++;
    expect(T.SPACE);
    List<Object> positions;
    if (types[i] == T.DEFAULT) {
      positions = <Object>[texts[i++]];
    } else {
      positions = <Object>[expect(T.NUM, "'DEFAULT'")];
      while (types[i] == T.COMMA) {
        i++;
        positions.add(expect(T.NUM));
      }
    }
    expect(T.SPACE);
    if (types[i] != T.INTERPOLATE) {
      db.updateLink(positions, stylesOpt());
      return;
    }
    i++;
    expect(T.SPACE);
    final interpolate = alphaNum();
    if (types[i] == T.SPACE) {
      i++;
      final styles = stylesOpt();
      db.updateLinkInterpolate(positions, interpolate);
      db.updateLink(positions, styles);
    } else {
      db.updateLinkInterpolate(positions, interpolate);
    }
  }

  void linkTail(String id, String url) {
    if (types[i] != T.SPACE) {
      db.setLink(id, url);
      return;
    }
    i++;
    if (types[i] == T.LINK_TARGET) {
      db.setLink(id, url, texts[i++]);
      return;
    }
    final tooltip = expect(T.STR, "'LINK_TARGET'");
    if (types[i] == T.SPACE) {
      i++;
      db.setLink(id, url, expect(T.LINK_TARGET));
    } else {
      db.setLink(id, url);
    }
    db.setTooltip(id, tooltip);
  }

  void clickStatement() {
    final id = texts[i++];
    switch (types[i]) {
      case T.CALLBACKNAME:
        final name = texts[i++];
        final hasArgs = types[i] == T.CALLBACKARGS;
        final args = hasArgs ? texts[i++] : null;
        String? tooltip;
        if (types[i] == T.SPACE) {
          i++;
          tooltip = expect(T.STR);
        }
        if (hasArgs) {
          db.setClickEvent(id, name, args);
        } else {
          db.setClickEvent(id, name);
        }
        if (tooltip != null) db.setTooltip(id, tooltip);
        return;
      case T.HREF:
        i++;
        linkTail(id, expect(T.STR));
        return;
      case T.STR:
        linkTail(id, texts[i++]);
        return;
      default:
        final name = alphaNum();
        if (types[i] == T.SPACE) {
          i++;
          final tooltip = expect(T.STR);
          db.setClickEvent(id, name);
          db.setTooltip(id, tooltip);
        } else {
          db.setClickEvent(id, name);
        }
    }
  }

  _Frame subgraphHeader() {
    i++;
    var t = types[i];
    if (t == T.NEWLINE || t == T.SEMI || t == T.EOF) {
      i++;
      return _Frame(id: null, title: null, list: <DocItem>[], collect: false);
    }
    expect(T.SPACE, "'SEMI', 'NEWLINE', 'EOF'");
    final id = textNoTags();
    var title = id;
    if (types[i] == T.SQS) {
      i++;
      title = text();
      closed(T.SQE);
    }
    t = types[i];
    if (t != T.NEWLINE && t != T.SEMI && t != T.EOF) {
      fail("'SEMI', 'NEWLINE', 'EOF', 'SQS'");
    }
    i++;
    return _Frame(id: id, title: title, list: <DocItem>[], collect: false);
  }

  DocItem statement(bool collect) {
    final t = types[i];
    switch (t) {
      case T.STYLE:
        i++;
        expect(T.SPACE);
        final id = idString();
        expect(T.SPACE);
        db.addVertex(id, null, null, stylesOpt());
        separator();
        return _noItems;
      case T.LINKSTYLE:
        linkStyleStatement();
        separator();
        return _noItems;
      case T.CLASSDEF:
        i++;
        expect(T.SPACE);
        final id = idString();
        expect(T.SPACE);
        db.addClass(id, stylesOpt());
        separator();
        return _noItems;
      case T.CLASS:
        i++;
        expect(T.SPACE);
        final ids = idString();
        expect(T.SPACE);
        db.setClass(ids, idString());
        separator();
        return _noItems;
      case T.CLICK:
        clickStatement();
        separator();
        return _noItems;
      case T.direction_tb:
      case T.direction_bt:
      case T.direction_rl:
      case T.direction_lr:
      case T.direction_td:
        i++;
        return DirStmt(_directions[t - T.direction_tb]);
      case T.acc_title:
        i++;
        final value = expect(T.acc_title_value).trim();
        db.setAccTitle(value);
        return value;
      case T.acc_descr:
        i++;
        final value = expect(T.acc_descr_value).trim();
        db.setAccDescription(value);
        return value;
      case T.acc_descr_multiline_value:
        final value = texts[i++].trim();
        db.setAccDescription(value);
        return value;
      default:
        if (_id[t] == 0) fail(_statementStart);
        final nodes = vertexStatement(collect);
        separator();
        return nodes;
    }
  }

  // Subgraphs nest without recursion: each open one keeps the list and collect flag of its parent.
  void document() {
    final open = <_Frame>[];
    var list = <DocItem>[];
    var collect = false;
    while (true) {
      final t = types[i];
      if (t == T.END) break;
      if (t == T.end) {
        if (open.isEmpty) break;
        final frame = open.removeLast();
        i++;
        final id = db.addSubGraph(frame.id, list, frame.title);
        list = frame.list;
        collect = frame.collect;
        if (collect) list.add(id);
      } else if (t == T.SEMI || t == T.NEWLINE || t == T.SPACE || t == T.EOF) {
        if (collect) list.add(texts[i]);
        i++;
      } else if (t == T.subgraph) {
        final frame = subgraphHeader();
        frame.list = list;
        frame.collect = collect;
        open.add(frame);
        list = <DocItem>[];
        collect = true;
      } else {
        final item = statement(collect);
        if (collect && (item is! List || item.isNotEmpty)) {
          list.add(item);
        }
      }
    }
    if (open.isNotEmpty) fail("'end'");
  }

  while (types[i] == T.SPACE || types[i] == T.NEWLINE) {
    i++;
  }
  expect(T.GRAPH, "'SPACE', 'NEWLINE'");
  if (types[i] == T.NODIR) {
    i++;
    db.setDirection('TB');
  } else {
    final dir = expect(T.DIR, "'NODIR'");
    var t = types[i];
    if (t == T.SPACE) {
      do {
        i++;
      } while (types[i] == T.SPACE);
      t = types[i];
      if (t != T.NEWLINE) fail("'NEWLINE', 'SPACE'");
    } else if (t != T.SEMI && t != T.NEWLINE) {
      fail("'SEMI', 'NEWLINE', 'SPACE'");
    }
    i++;
    db.setDirection(dir);
  }
  document();
  if (types[i] != T.END) fail(_statementStart);
}

const List<String> _directions = <String>['TB', 'BT', 'RL', 'LR', 'TD'];
const String _statementStart =
    "'SEMI', 'NEWLINE', 'SPACE', 'EOF', 'subgraph', 'acc_title', 'acc_descr', 'acc_descr_multiline_value', 'STYLE', 'LINKSTYLE', 'CLASSDEF', 'CLASS', 'CLICK', 'NODE_STRING'";

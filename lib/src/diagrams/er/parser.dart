// Upstream: src/diagrams/er/parser.ts

import '../../errors.dart';
import 'db.dart';
import 'lexer.dart';
import 'tokens.dart';
import 'types.dart';

const Map<int, Cardinality> _cardinality = <int, Cardinality>{
  T.ZERO_OR_ONE: 'ZERO_OR_ONE',
  T.ZERO_OR_MORE: 'ZERO_OR_MORE',
  T.ONE_OR_MORE: 'ONE_OR_MORE',
  T.ONLY_ONE: 'ONLY_ONE',
  T.MD_PARENT: 'MD_PARENT',
};

const List<String> _directions = <String>['TB', 'BT', 'RL', 'LR'];

const String _name =
    "'UNICODE_TEXT', 'NUM', 'ENTITY_NAME', 'DECIMAL_NUM', 'ENTITY_ONE'";
const String _cards =
    "'ZERO_OR_ONE', 'ZERO_OR_MORE', 'ONE_OR_MORE', 'ONLY_ONE', 'MD_PARENT'";
const String _line =
    "'EOF', 'NEWLINE', 'title', 'acc_title', 'acc_descr', 'acc_descr_multiline_value', 'SUBGRAPH', 'direction_tb', "
    "'direction_bt', 'direction_rl', 'direction_lr', 'CLASSDEF', 'CLASS', 'STYLE', "
    '$_name';

class _Frame {
  _Frame({required this.id, required this.title, required this.list});

  final String id;
  final String title;
  // What Mermaid's grammar hands to addSubGraph: the value of every statement inside. Besides entity
  // names that includes accessibility text and the keywords `style`, `class` and `classDef`.
  final List<DocItem> list;
}

void parseEr(String src, ErDb db) {
  final tokens = tokenize(src);
  final types = tokens.types;
  final texts = tokens.texts;
  final starts = tokens.starts;
  var i = 0;

  Never fail(String expected) {
    final t = types[i];
    if (t == T.ERROR) throw syntaxError('er', src, starts[i], '', true);
    throw syntaxError(
      'er',
      src,
      starts[i],
      "Expecting $expected, got '${t == T.CHAR ? texts[i] : TOKEN_NAMES[t]}'",
    );
  }

  String expect(int type) {
    if (types[i] != type) fail("'${TOKEN_NAMES[type]}'");
    return texts[i++];
  }

  void separator() {
    final t = types[i];
    if (t != T.NEWLINE && t != T.SEMI && t != T.EOF) {
      fail("'EOF', 'NEWLINE', 'SEMI'");
    }
    i++;
  }

  bool isName(int t) =>
      t == T.UNICODE_TEXT ||
      t == T.ENTITY_NAME ||
      t == T.NUM ||
      t == T.DECIMAL_NUM ||
      t == T.ENTITY_ONE;

  String entityName() {
    final t = types[i];
    if (!isName(t)) fail(_name);
    final text = texts[i++];
    return t == T.ENTITY_NAME ? text.substring(1, text.length - 1) : text;
  }

  List<String> idList() {
    final ids = <String>[];
    for (;;) {
      final t = types[i];
      if (t != T.UNICODE_TEXT && t != T.STYLE_TEXT) {
        fail("'UNICODE_TEXT', 'STYLE_TEXT'");
      }
      ids.add(texts[i++]);
      if (types[i] != T.COMMA) return ids;
      i++;
    }
  }

  bool isStyleComponent(int t) =>
      t == T.STYLE_TEXT || t == T.NUM || t == T.COLON || t == T.BRKT;

  List<String> stylesOpt() {
    final styles = <String>[];
    for (;;) {
      if (!isStyleComponent(types[i])) {
        fail("'STYLE_TEXT', 'COLON', 'NUM', 'BRKT'");
      }
      var style = texts[i++];
      while (isStyleComponent(types[i])) {
        style += texts[i++];
      }
      styles.add(style);
      if (types[i] != T.COMMA) return styles;
      i++;
    }
  }

  RelSpec relSpec() {
    final cardB = _cardinality[types[i++]]!;
    final r = types[i];
    if (r != T.IDENTIFYING && r != T.NON_IDENTIFYING) {
      fail("'NON_IDENTIFYING', 'IDENTIFYING'");
    }
    final Identification relType = r == T.IDENTIFYING
        ? 'IDENTIFYING'
        : 'NON_IDENTIFYING';
    i++;
    final cardA = _cardinality[types[i]];
    if (cardA == null) fail(_cards);
    i++;
    return RelSpec(cardA: cardA, relType: relType, cardB: cardB);
  }

  String role() {
    final t = types[i];
    if (t != T.WORD && t != T.ENTITY_NAME && t != T.UNICODE_TEXT) {
      fail("'UNICODE_TEXT', 'ENTITY_NAME', 'WORD'");
    }
    final text = texts[i++];
    return t == T.UNICODE_TEXT ? text : text.substring(1, text.length - 1);
  }

  bool isChar(String ch) => types[i] == T.CHAR && texts[i] == ch;

  // Returns the attributes last to first, as Mermaid's right-recursive rule builds them.
  List<ParsedAttribute> attributes() {
    final list = <ParsedAttribute>[];
    do {
      var type = expect(T.ATTRIBUTE_WORD);
      if (isChar('?')) type += texts[i++];
      if (types[i] != T.ATTRIBUTE_WORD) {
        fail(type.endsWith('?') ? "'ATTRIBUTE_WORD'" : "'ATTRIBUTE_WORD', '?'");
      }
      final attribute = ParsedAttribute(type: type, name: texts[i++]);
      if (types[i] == T.ATTRIBUTE_KEY) {
        final keys = <String>[texts[i++]];
        while (isChar(',')) {
          i++;
          keys.add(expect(T.ATTRIBUTE_KEY));
        }
        attribute.keys = keys;
      }
      if (types[i] == T.COMMENT) {
        final raw = texts[i++];
        attribute.comment = raw.substring(1, raw.length - 1);
      }
      list.add(attribute);
    } while (types[i] != T.BLOCK_STOP);
    return list.reversed.toList();
  }

  // Parses an optional `{ ... }` block; null when there is none or it is empty.
  List<ParsedAttribute>? block() {
    if (types[i] != T.BLOCK_START) return null;
    i++;
    if (types[i] == T.BLOCK_STOP) {
      i++;
      return null;
    }
    final list = attributes();
    i++;
    return list;
  }

  List<String> entityStatement() {
    final a = entityName();
    var t = types[i];
    if (t == T.SQS) {
      i++;
      final alias = entityName();
      expect(T.SQE);
      List<String>? classes;
      if (types[i] == T.STYLE_SEPARATOR) {
        i++;
        classes = idList();
      }
      final attrs = block();
      db.addEntity(a, alias);
      if (attrs != null) db.addAttributes(a, attrs);
      if (classes != null) db.setClass(<String>[a], classes);
      return <String>[a];
    }
    List<String>? classes;
    if (t == T.STYLE_SEPARATOR) {
      i++;
      classes = idList();
      t = types[i];
    }
    if (_cardinality.containsKey(t)) {
      final spec = relSpec();
      final b = entityName();
      List<String>? classesB;
      if (types[i] == T.STYLE_SEPARATOR) {
        i++;
        classesB = idList();
      }
      expect(T.COLON);
      final label = role();
      db.addEntity(a);
      db.addEntity(b);
      db.addRelationship(a, label, b, spec);
      if (classes != null) db.setClass(<String>[a], classes);
      if (classesB != null) db.setClass(<String>[b], classesB);
      return <String>[a, b];
    }
    final attrs = block();
    db.addEntity(a);
    if (attrs != null) db.addAttributes(a, attrs);
    if (classes != null) db.setClass(<String>[a], classes);
    return <String>[a];
  }

  expect(T.ER_DIAGRAM);
  // Subgraphs nest on this stack rather than on the call stack; the first frame is the diagram itself.
  final frames = <_Frame>[_Frame(id: '', title: '', list: <DocItem>[])];
  var frame = frames[0];
  var nested = false;

  for (;;) {
    final t = types[i];
    switch (t) {
      case T.NEWLINE:
        i++;
        break;
      case T.EOF:
        i++;
        if (nested) fail("'END', $_line");
        return;
      case T.END_KW:
        if (!nested) fail(_line);
        i++;
        final id = db.addSubGraph(
          (text: frame.id),
          frame.list,
          (text: frame.title, type: null),
        );
        frames.removeLast();
        frame = frames.last;
        nested = frames.length > 1;
        if (nested) frame.list.add(id);
        break;
      case T.SUBGRAPH:
        i++;
        final id = entityName();
        var title = id;
        if (types[i] == T.SQS) {
          i++;
          title = entityName();
          while (isName(types[i])) {
            title += ' ${entityName()}';
          }
          expect(T.SQE);
        }
        separator();
        frame = _Frame(id: id, title: title, list: <DocItem>[]);
        frames.add(frame);
        nested = true;
        break;
      case T.acc_title:
        i++;
        final value = expect(T.acc_title_value).trim();
        db.setAccTitle(value);
        if (nested) frame.list.add(value);
        break;
      case T.acc_descr:
        i++;
        final value = expect(T.acc_descr_value).trim();
        db.setAccDescription(value);
        if (nested) frame.list.add(value);
        break;
      case T.acc_descr_multiline_value:
        final value = texts[i++].trim();
        db.setAccDescription(value);
        if (nested) frame.list.add(value);
        break;
      case T.direction_tb:
      case T.direction_bt:
      case T.direction_rl:
      case T.direction_lr:
        i++;
        final value = _directions[t - T.direction_tb];
        if (nested) {
          frame.list.add(DirStmt(value));
        } else {
          db.setDirection(value);
        }
        break;
      case T.CLASSDEF:
        final keyword = texts[i++];
        final ids = idList();
        final styles = stylesOpt();
        separator();
        db.addClass(ids, styles);
        if (nested) frame.list.add(keyword);
        break;
      case T.CLASS:
        final keyword = texts[i++];
        final ids = idList();
        db.setClass(ids, idList());
        if (nested) frame.list.add(keyword);
        break;
      case T.STYLE:
        final keyword = texts[i++];
        final ids = idList();
        final styles = stylesOpt();
        separator();
        db.addCssStyles(ids, styles);
        if (nested) frame.list.add(keyword);
        break;
      default:
        if (!isName(t)) fail(nested ? "'END', $_line" : _line);
        final names = entityStatement();
        if (nested) {
          for (final name in names) {
            frame.list.add(name);
          }
        }
    }
  }
}

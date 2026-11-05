// Upstream: src/diagrams/state/parser.ts

import '../../errors.dart';
import 'lexer.dart';
import 'tokens.dart';
import 'types.dart';

// The calls Mermaid's grammar makes on its `yy` object.
abstract interface class StateBuilder {
  void setRootDoc(List<Stmt> doc);
  String trimColon(String text);
  String getDividerId();
  void setDirection(String dir);
  void setAccTitle(String text);
  void setAccDescription(String text);
}

const List<String> _directions = <String>['TB', 'BT', 'RL', 'LR'];
const String _statement =
    "'NL', 'ID', 'HIDE_EMPTY', 'scale', 'COMPOSIT_STATE', 'STATE_DESCR', 'FORK', 'JOIN', 'CHOICE', 'CONCURRENT', 'note', "
    "'acc_title', 'acc_descr', 'acc_descr_multiline_value', 'CLICK', 'classDef', 'style', 'class', 'direction_tb', "
    "'direction_bt', 'direction_rl', 'direction_lr', 'EDGE_STATE'";

List<Stmt> parseState(String src, StateBuilder db) {
  final tokenized = tokenize(src);
  final types = tokenized.types;
  final texts = tokenized.texts;
  final starts = tokenized.starts;
  final error = tokenized.error;
  var i = 0;

  Never fail(String expected) {
    final t = types[i];
    if (t == T.ERROR) {
      if (error != null) {
        final loc = locate(src, starts[i]);
        throw PeleError(
          error,
          'syntax',
          PeleErrorInfo(
            type: 'state',
            line: loc.line,
            column: loc.column,
            snippet: loc.snippet,
          ),
        );
      }
      throw syntaxError('state', src, starts[i], '', true);
    }
    throw syntaxError(
      'state',
      src,
      starts[i],
      "Expecting $expected, got '${tokenNames[t]}'",
    );
  }

  String expect(int type) {
    if (types[i] != type) fail("'${tokenNames[type]}'");
    return texts[i++];
  }

  StateStmt idStatement() {
    final t = types[i];
    if (t != T.ID && t != T.EDGE_STATE) fail("'ID', 'EDGE_STATE'");
    final id = texts[i++].trim();
    if (types[i] != T.STYLE_SEPARATOR) {
      return StateStmt(id: id, type: 'default', description: '');
    }
    i++;
    return StateStmt(
      id: id,
      classes: <String>[expect(T.ID).trim()],
      type: 'default',
      description: '',
    );
  }

  while (types[i] == T.NL) {
    i++;
  }
  if (types[i] != T.SD) fail("'NL', 'SD'");
  i++;

  var doc = <Stmt>[];
  final outer = <List<Stmt>>[];
  // The grammar drops a statement whose value is the string it uses for a blank line.
  void add(Stmt value) {
    if (value != 'nl') doc.add(value);
  }

  void open(String id, String description) {
    i++;
    final inner = <Stmt>[];
    doc.add(
      StateStmt(id: id, type: 'default', description: description, doc: inner),
    );
    outer.add(doc);
    doc = inner;
  }

  for (;;) {
    final t = types[i];
    switch (t) {
      case T.NL:
        i++;
      case T.ID:
      case T.EDGE_STATE:
        final first = idStatement();
        if (types[i] == T.DESCR) {
          first.description = db.trimColon(texts[i++]);
          add(first);
        } else if (types[i] == T.ARROW) {
          i++;
          final second = idStatement();
          if (types[i] == T.DESCR) {
            add(
              RelationStmt(
                state1: first,
                state2: second,
                description: db.trimColon(texts[i++]),
              ),
            );
          } else {
            add(RelationStmt(state1: first, state2: second));
          }
        } else {
          add(first);
        }
      case T.HIDE_EMPTY:
        add(texts[i++]);
      case T.scale:
        i++;
        expect(T.WIDTH);
        add(texts[i - 2]);
      case T.COMPOSIT_STATE:
        if (types[i + 1] == T.STRUCT_START) {
          open(texts[i++], '');
        } else {
          add(texts[i++]);
        }
      case T.STATE_DESCR:
        final description = texts[i++];
        expect(T.AS);
        final id = expect(T.ID);
        if (types[i] == T.STRUCT_START) {
          open(id, description);
        } else if (id.contains(':')) {
          final parts = id.split(':');
          add(
            StateStmt(
              id: parts[0],
              type: 'default',
              description: <String>[description.trim(), parts[1]],
            ),
          );
        } else {
          add(
            StateStmt(id: id, type: 'default', description: description.trim()),
          );
        }
      case T.FORK:
        add(StateStmt(id: texts[i++], type: 'fork'));
      case T.JOIN:
        add(StateStmt(id: texts[i++], type: 'join'));
      case T.CHOICE:
        add(StateStmt(id: texts[i++], type: 'choice'));
      case T.CONCURRENT:
        i++;
        add(StateStmt(id: db.getDividerId(), type: 'divider'));
      case T.note:
        final keyword = texts[i++];
        if (types[i] == T.left_of || types[i] == T.right_of) {
          final position = texts[i++].trim();
          final id = expect(T.ID).trim();
          add(
            StateStmt(
              id: id,
              note: StateNote(
                position: position,
                text: expect(T.NOTE_TEXT).trim(),
              ),
            ),
          );
        } else {
          if (types[i] != T.NOTE_TEXT) {
            fail("'NOTE_TEXT', 'left_of', 'right_of'");
          }
          i++;
          expect(T.AS);
          expect(T.ID);
          add(keyword);
        }
      case T.direction_tb:
      case T.direction_bt:
      case T.direction_rl:
      case T.direction_lr:
        final value = _directions[t - T.direction_tb];
        i++;
        db.setDirection(value);
        add(DirectionStmt(value: value));
      case T.acc_title:
        i++;
        final value = expect(T.acc_title_value).trim();
        db.setAccTitle(value);
        add(value);
      case T.acc_descr:
        i++;
        final value = expect(T.acc_descr_value).trim();
        db.setAccDescription(value);
        add(value);
      case T.acc_descr_multiline_value:
        final value = texts[i++].trim();
        db.setAccDescription(value);
        add(value);
      case T.CLICK:
        i++;
        final id = idStatement();
        String url;
        var tooltip = '';
        if (types[i] == T.HREF) {
          i++;
          url = expect(T.STRING);
        } else {
          if (types[i] != T.STRING) fail("'STRING', 'HREF'");
          url = texts[i++];
          tooltip = expect(T.STRING);
        }
        expect(T.NL);
        add(ClickStmt(id: id, url: url, tooltip: tooltip));
      case T.classDef:
        i++;
        final id = expect(T.CLASSDEF_ID).trim();
        add(ClassDefStmt(id: id, classes: expect(T.CLASSDEF_STYLEOPTS).trim()));
      case T.style:
        i++;
        final id = expect(T.STYLE_IDS).trim();
        add(StyleStmt(id: id, styleClass: expect(T.STYLEDEF_STYLEOPTS).trim()));
      case T.classKw:
        i++;
        final id = expect(T.CLASSENTITY_IDS).trim();
        add(ApplyClassStmt(id: id, styleClass: expect(T.STYLECLASS).trim()));
      case T.STRUCT_STOP:
        if (outer.isEmpty) fail("'\$end', $_statement");
        i++;
        doc = outer.removeLast();
      case T.END:
        if (outer.isNotEmpty) fail("'STRUCT_STOP', $_statement");
        db.setRootDoc(doc);
        return doc;
      default:
        fail(
          outer.isNotEmpty
              ? "'STRUCT_STOP', $_statement"
              : "'\$end', $_statement",
        );
    }
  }
}

// Upstream: src/diagrams/class/parser.ts

import 'dart:typed_data';

import '../../errors.dart';
import 'db.dart';
import 'lexer.dart';
import 'tokens.dart';
import 'types.dart';

const int _COUNT = T.PUNCTUATION + 1;

final Uint8List _ALPHANUM = () {
  final arr = Uint8List(_COUNT);
  for (final t in const <int>[T.UNICODE_TEXT, T.ALPHA, T.MINUS]) {
    arr[t] = 1;
  }
  return arr;
}();

final Uint8List _STYLE_PART = () {
  final arr = Uint8List(_COUNT);
  for (final t in const <int>[
    T.ALPHA,
    T.COLON,
    T.BRKT,
    T.STYLE,
    T.PCT,
    T.LABEL,
  ]) {
    arr[t] = 1;
  }
  return arr;
}();

// Mermaid's relationType numbers, plus one so that zero means "not an end marker".
final Uint8List _END_TYPE = () {
  final arr = Uint8List(_COUNT);
  arr[T.AGGREGATION] = 1;
  arr[T.EXTENSION] = 2;
  arr[T.COMPOSITION] = 3;
  arr[T.DEPENDENCY] = 4;
  arr[T.LOLLIPOP] = 5;
  return arr;
}();

const String _NAME_TOKENS =
    "'UNICODE_TEXT', 'NUM', 'ALPHA', 'MINUS', 'BQUOTE_STR'";

class _Frame {
  final String id;
  final List<String> classes;
  final List<String> notes;

  _Frame({required this.id}) : classes = <String>[], notes = <String>[];
}

void parseClassDiagram(String src, ClassDb db) {
  final tok = tokenize(src);
  final types = tok.types;
  final texts = tok.texts;
  final starts = tok.starts;
  var i = 0;

  Never fail(String expected) {
    final t = types[i];
    if (t == T.ERROR) throw syntaxError('class', src, starts[i], '', true);
    throw syntaxError(
      'class',
      src,
      starts[i],
      "Expecting $expected, got '${TOKEN_NAMES[t]}'",
    );
  }

  String expect(int type) {
    if (types[i] != type) fail("'${TOKEN_NAMES[type]}'");
    return texts[i++];
  }

  String alphaNum() {
    if (_ALPHANUM[types[i]] == 0) {
      fail("'UNICODE_TEXT', 'NUM', 'ALPHA', 'MINUS'");
    }
    return texts[i++];
  }

  String name(bool generic) {
    final out = StringBuffer();
    while (true) {
      if (types[i] == T.BQUOTE_STR) {
        out.write(texts[i++]);
        break;
      }
      if (_ALPHANUM[types[i]] == 0) fail(_NAME_TOKENS);
      out.write(texts[i++]);
      final t = types[i];
      if (t == T.DOT) {
        out.write('.');
        i++;
      } else if (_ALPHANUM[t] == 0 && t != T.BQUOTE_STR) {
        break;
      }
    }
    if (generic && types[i] == T.GENERICTYPE) {
      out.write('~${texts[i++]}~');
    }
    return out.toString();
  }

  String classLabel() {
    i++;
    final label = expect(T.STR);
    expect(T.SQE);
    return label;
  }

  List<String> members() {
    if (types[i] != T.MEMBER) fail("'STRUCT_STOP', 'MEMBER'");
    final list = <String>[];
    while (types[i] == T.MEMBER) {
      list.add(texts[i++]);
    }
    expect(T.STRUCT_STOP);
    // The grammar collects members last to first, and addMembers turns them back.
    return list.reversed.toList();
  }

  String classStatement() {
    i++;
    final id = name(true);
    db.addClass(id);
    if (types[i] == T.SQS) db.setClassLabel(id, classLabel());
    switch (types[i]) {
      case T.STYLE_SEPARATOR:
        i++;
        final css = alphaNum();
        db.setCssClass(id, css);
        if (types[i] == T.STRUCT_START) {
          i++;
          db.addMembers(id, members());
        }
      case T.STRUCT_START:
        i++;
        if (types[i] == T.STRUCT_STOP) {
          i++;
        } else {
          db.addMembers(id, members());
        }
      case T.ANNOTATION_START:
        i++;
        final annotation = alphaNum();
        expect(T.ANNOTATION_END);
        db.addAnnotation(id, annotation);
        if (types[i] == T.STRUCT_START) {
          i++;
          if (types[i] == T.STRUCT_STOP) {
            i++;
          } else {
            db.addMembers(id, members());
          }
        }
    }
    return id;
  }

  String noteStatement() {
    if (types[i++] == T.NOTE) return db.addNote(expect(T.STR));
    final id = name(true);
    return db.addNote(expect(T.STR), id);
  }

  // Namespaces nest, so they are parsed with a stack of open ones.
  void namespaceStatement() {
    final open = <_Frame>[];
    while (true) {
      i++;
      final ns = name(false);
      final id = types[i] == T.SQS
          ? db.addNamespace(ns, classLabel())
          : db.addNamespace(ns);
      expect(T.STRUCT_START);
      if (types[i] == T.NEWLINE) i++;
      open.add(_Frame(id: id));
      var item = true;
      while (item) {
        final frame = open.last;
        final t = types[i];
        if (t == T.NAMESPACE) break;
        if (t == T.CLASS) {
          frame.classes.add(classStatement());
        } else if (t == T.NOTE || t == T.NOTE_FOR) {
          frame.notes.add(noteStatement());
        } else {
          fail("'NAMESPACE', 'CLASS', 'NOTE_FOR', 'NOTE'");
        }
        while (true) {
          if (types[i] == T.NEWLINE) {
            final next = types[i + 1];
            if (next == T.NAMESPACE ||
                next == T.CLASS ||
                next == T.NOTE ||
                next == T.NOTE_FOR) {
              i++;
              break;
            }
            i++;
          }
          expect(T.STRUCT_STOP);
          final done = open.removeLast();
          db.addClassesToNamespace(done.id, done.classes, done.notes);
          db.popNamespace();
          if (open.isEmpty) {
            item = false;
            break;
          }
        }
      }
      if (open.isEmpty) return;
    }
  }

  RelationEnd relationEnd() {
    final type = _END_TYPE[types[i]];
    if (type == 0) return 'none';
    i++;
    return type - 1;
  }

  void classOrRelation() {
    final id1 = name(true);
    var t = types[i];
    if (t == T.LABEL) {
      db.addMember(id1, db.cleanupLabel(texts[i++]));
      return;
    }
    var title1 = 'none';
    if (t == T.STR) {
      title1 = texts[i++];
      t = types[i];
    } else if (_END_TYPE[t] == 0 && t != T.LINE && t != T.DOTTED_LINE) {
      return;
    }
    final type1 = relationEnd();
    t = types[i];
    if (t != T.LINE && t != T.DOTTED_LINE) {
      fail(
        "'AGGREGATION', 'EXTENSION', 'COMPOSITION', 'DEPENDENCY', 'LOLLIPOP', 'LINE', 'DOTTED_LINE'",
      );
    }
    i++;
    final type2 = relationEnd();
    final title2 = types[i] == T.STR ? texts[i++] : 'none';
    final id2 = name(true);
    final relation = ClassRelation(
      id1: id1,
      id2: id2,
      relation: RelationSpec(
        type1: type1,
        type2: type2,
        lineType: t == T.LINE ? 0 : 1,
      ),
      relationTitle1: title1,
      relationTitle2: title2,
    );
    if (types[i] == T.LABEL) {
      relation.title = db.cleanupLabel(texts[i++]);
    }
    db.addRelation(relation);
  }

  List<String> styles() {
    final out = <String>[];
    while (true) {
      if (_STYLE_PART[types[i]] == 0) {
        fail(
          "'ALPHA', 'NUM', 'COLON', 'UNIT', 'SPACE', 'BRKT', 'STYLE', 'PCT', 'LABEL'",
        );
      }
      var s = texts[i++];
      while (_STYLE_PART[types[i]] == 1) {
        s += texts[i++];
      }
      out.add(s);
      if (types[i] != T.COMMA) return out;
      i++;
    }
  }

  void tooltip(String id) {
    if (types[i] == T.STR) db.setTooltip(id, texts[i++]);
  }

  void linkStatement(String id) {
    final href = expect(T.STR);
    final tip = types[i] == T.STR ? texts[i++] : null;
    if (types[i] == T.LINK_TARGET) {
      db.setLink(id, href, texts[i++]);
    } else {
      db.setLink(id, href);
    }
    if (tip != null) db.setTooltip(id, tip);
  }

  void statement() {
    final t = types[i];
    switch (t) {
      case T.UNICODE_TEXT:
      case T.ALPHA:
      case T.MINUS:
      case T.BQUOTE_STR:
        classOrRelation();
        return;
      case T.NAMESPACE:
        namespaceStatement();
        return;
      case T.CLASS:
        classStatement();
        return;
      case T.MEMBER:
        i++;
        return;
      case T.ANNOTATION_START:
        i++;
        final annotation = alphaNum();
        expect(T.ANNOTATION_END);
        db.addAnnotation(name(true), annotation);
        return;
      case T.CALLBACK:
        i++;
        final id = name(true);
        db.setClickEvent(id, expect(T.STR));
        tooltip(id);
        return;
      case T.LINK:
        i++;
        linkStatement(name(true));
        return;
      case T.CLICK:
        i++;
        final id = name(true);
        if (types[i] == T.HREF) {
          i++;
          linkStatement(id);
          return;
        }
        final fn = expect(T.CALLBACK_NAME);
        if (types[i] == T.CALLBACK_ARGS) {
          db.setClickEvent(id, fn, texts[i++]);
        } else {
          db.setClickEvent(id, fn);
        }
        tooltip(id);
        return;
      case T.STYLE:
        i++;
        final id = expect(T.ALPHA);
        db.setCssStyle(id, styles());
        return;
      case T.CSSCLASS:
        i++;
        final ids = expect(T.STR);
        db.setCssClass(ids, expect(T.ALPHA));
        return;
      case T.NOTE:
      case T.NOTE_FOR:
        noteStatement();
        return;
      case T.CLASSDEF:
        i++;
        final ids = <String>[expect(T.ALPHA)];
        while (types[i] == T.COMMA) {
          i++;
          ids.add(expect(T.ALPHA));
        }
        db.defineClass(ids, styles());
        return;
      case T.direction_tb:
      case T.direction_bt:
      case T.direction_rl:
      case T.direction_lr:
        i++;
        db.setDirection(
          t == T.direction_tb
              ? 'TB'
              : t == T.direction_bt
              ? 'BT'
              : t == T.direction_rl
              ? 'RL'
              : 'LR',
        );
        return;
      case T.acc_title:
        i++;
        db.setAccTitle(expect(T.acc_title_value).trim());
        return;
      case T.acc_descr:
        i++;
        db.setAccDescription(expect(T.acc_descr_value).trim());
        return;
      case T.acc_descr_multiline_value:
        db.setAccDescription(texts[i++].trim());
        return;
    }
    fail(
      "'acc_title', 'acc_descr', 'acc_descr_multiline_value', 'NAMESPACE', 'ANNOTATION_START', 'CLASS', 'MEMBER', 'NOTE_FOR', 'NOTE', 'CLASSDEF', 'direction_tb', 'CALLBACK', 'LINK', 'CLICK', 'STYLE', 'CSSCLASS', 'ALPHA', 'MINUS', 'BQUOTE_STR'",
    );
  }

  // Mermaid's grammar also accepts statements with no `classDiagram` line before them.
  final header = types[i] == T.CLASS_DIAGRAM;
  if (header) {
    i++;
    expect(T.NEWLINE);
  }
  while (true) {
    statement();
    if (types[i] != T.NEWLINE) break;
    i++;
    if (types[i] == T.EOF || types[i] == T.END) break;
  }
  if (header) expect(T.EOF);
  expect(T.END);
}

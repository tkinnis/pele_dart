// Upstream: src/diagrams/requirement/parser.ts

import '../../errors.dart';
import 'db.dart';
import 'lexer.dart';
import 'tokens.dart';

/// What the keyword tokens stand for, from REQUIREMENT to TRACES in token order.
const List<String> _values = <String>[
  RequirementType.REQUIREMENT,
  RequirementType.FUNCTIONAL_REQUIREMENT,
  RequirementType.INTERFACE_REQUIREMENT,
  RequirementType.PERFORMANCE_REQUIREMENT,
  RequirementType.PHYSICAL_REQUIREMENT,
  RequirementType.DESIGN_CONSTRAINT,
  RiskLevel.LOW_RISK,
  RiskLevel.MED_RISK,
  RiskLevel.HIGH_RISK,
  VerifyType.VERIFY_ANALYSIS,
  VerifyType.VERIFY_DEMONSTRATION,
  VerifyType.VERIFY_INSPECTION,
  VerifyType.VERIFY_TEST,
  '',
  Relationships.CONTAINS,
  Relationships.COPIES,
  Relationships.DERIVES,
  Relationships.SATISFIES,
  Relationships.VERIFIES,
  Relationships.REFINES,
  Relationships.TRACES,
];

bool _isStylePart(int t) {
  return t == T.ALPHA ||
      t == T.COLON ||
      t == T.BRKT ||
      t == T.MINUS ||
      t == T.SEMICOLON;
}

void parseRequirement(String src, RequirementDb db) {
  final tokens = tokenize(src);
  final types = tokens.types;
  final texts = tokens.texts;
  final starts = tokens.starts;
  var i = 0;
  final fields = <int>[];
  final values = <String>[];

  // Fails with Jison's wording, naming the token types `from` to `to` and any others as expected.
  Never fail(int from, [int? toArg, List<int> others = const <int>[]]) {
    final to = toArg ?? from;
    final t = types[i];
    if (t == T.ERROR) {
      throw syntaxError('requirement', src, starts[i], '', true);
    }
    final all = <int>[for (var k = from; k <= to; k++) k, ...others];
    final expected = all.map((type) => "'${TOKEN_NAMES[type]}'").join(', ');
    throw syntaxError(
      'requirement',
      src,
      starts[i],
      "Expecting $expected, got '${TOKEN_NAMES[t]}'",
    );
  }

  String expect(int type) {
    if (types[i] != type) fail(type);
    return texts[i++];
  }

  // The value of the next token if it is a keyword in the given range of token types.
  String keyword(int from, int to) {
    final t = types[i];
    if (t < from || t > to) fail(from, to);
    i++;
    return _values[t - T.REQUIREMENT];
  }

  String string() {
    final t = types[i];
    if (t != T.unqString && t != T.qString) fail(T.qString, T.unqString);
    return texts[i++];
  }

  bool directive() {
    final t = types[i];
    if (t == T.acc_title) {
      i++;
      db.setAccTitle(expect(T.acc_title_value).trim());
    } else if (t == T.acc_descr) {
      i++;
      db.setAccDescription(expect(T.acc_descr_value).trim());
    } else if (t == T.acc_descr_multiline_value) {
      db.setAccDescription(texts[i++].trim());
    } else {
      return false;
    }
    return true;
  }

  List<String> idList() {
    final list = <String>[];
    while (true) {
      final t = types[i];
      if (t != T.ALPHA && t != T.unqString && t != T.qString) {
        fail(T.qString, T.unqString, const <int>[T.ALPHA]);
      }
      list.add(texts[i++]);
      if (types[i] != T.COMMA) return list;
      i++;
    }
  }

  List<String> stylesOpt() {
    final styles = <String>[];
    while (true) {
      if (!_isStylePart(types[i])) {
        fail(T.ALPHA, T.SEMICOLON, const <int>[T.MINUS, T.BRKT]);
      }
      var style = texts[i++];
      while (_isStylePart(types[i])) {
        style += texts[i++];
      }
      styles.add(style);
      if (types[i] != T.COMMA) return styles;
      i++;
    }
  }

  List<String>? classList() {
    List<String>? classes;
    if (types[i] == T.STYLE_SEPARATOR) {
      i++;
      classes = idList();
      expect(T.STRUCT_START);
    } else if (types[i] == T.STRUCT_START) {
      i++;
    } else {
      fail(T.STRUCT_START, T.STRUCT_START, const <int>[T.STYLE_SEPARATOR]);
    }
    expect(T.NEWLINE);
    return classes;
  }

  // Reads a body up to its closing brace. The grammar is right recursive, so Mermaid applies
  // the fields last to first and the first of two repeated fields wins.
  void body(bool requirement) {
    fields.clear();
    values.clear();
    while (true) {
      final t = types[i];
      if (t == T.STRUCT_STOP) {
        i++;
        break;
      }
      if (t == T.NEWLINE) {
        i++;
        continue;
      }
      if (requirement
          ? (t < T.ID || t > T.VERIFYMTHD)
          : (t != T.TYPE && t != T.DOCREF)) {
        if (requirement) {
          fail(T.ID, T.VERIFYMTHD, const <int>[T.NEWLINE, T.STRUCT_STOP]);
        }
        fail(T.TYPE, T.DOCREF, const <int>[T.NEWLINE, T.STRUCT_STOP]);
      }
      i++;
      expect(T.COLONSEP);
      values.add(
        t == T.RISK
            ? keyword(T.LOW_RISK, T.HIGH_RISK)
            : t == T.VERIFYMTHD
            ? keyword(T.VERIFY_ANALYSIS, T.VERIFY_TEST)
            : string(),
      );
      fields.add(t);
      expect(T.NEWLINE);
    }
    for (var k = fields.length - 1; k >= 0; k--) {
      final value = values[k];
      switch (fields[k]) {
        case T.ID:
          db.setNewReqId(value);
          break;
        case T.TEXT:
          db.setNewReqText(value);
          break;
        case T.RISK:
          db.setNewReqRisk(value);
          break;
        case T.VERIFYMTHD:
          db.setNewReqVerifyMethod(value);
          break;
        case T.TYPE:
          db.setNewElementType(value);
          break;
        default:
          db.setNewElementDocRef(value);
      }
    }
  }

  while (directive()) {
    if (types[i] == T.NEWLINE) i++;
  }
  if (types[i] != T.RD) {
    fail(T.RD, T.RD, const <int>[
      T.acc_title,
      T.acc_descr,
      T.acc_descr_multiline_value,
    ]);
  }
  i++;
  expect(T.NEWLINE);

  while (true) {
    final t = types[i];
    if (t == T.EOF) return;
    if (t == T.NEWLINE) {
      i++;
    } else if (directive()) {
      continue;
    } else if (t >= T.direction_tb && t <= T.direction_lr) {
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
    } else if (t >= T.REQUIREMENT && t <= T.DESIGN_CONSTRAINT) {
      final type = keyword(T.REQUIREMENT, T.DESIGN_CONSTRAINT);
      final name = string();
      final classes = classList();
      body(true);
      db.addRequirement(name, type);
      if (classes != null) db.setClass(<String>[name], classes);
    } else if (t == T.ELEMENT) {
      i++;
      final name = string();
      final classes = classList();
      body(false);
      db.addElement(name);
      if (classes != null) db.setClass(<String>[name], classes);
    } else if (t == T.STYLE) {
      i++;
      final ids = idList();
      db.setCssStyle(ids, stylesOpt());
    } else if (t == T.CLASSDEF) {
      i++;
      final ids = idList();
      db.defineClass(ids, stylesOpt());
    } else if (t == T.CLASS) {
      i++;
      final ids = idList();
      db.setClass(ids, idList());
    } else if (t == T.unqString || t == T.qString) {
      final id = texts[i++];
      final next = types[i];
      if (next == T.STYLE_SEPARATOR) {
        i++;
        db.setClass(<String>[id], idList());
      } else if (next == T.END_ARROW_L || next == T.LINE) {
        i++;
        final relationship = keyword(T.CONTAINS, T.TRACES);
        expect(next == T.LINE ? T.END_ARROW_R : T.LINE);
        final other = string();
        if (next == T.LINE) {
          db.addRelationship(relationship, id, other);
        } else {
          db.addRelationship(relationship, other, id);
        }
      } else {
        fail(T.STYLE_SEPARATOR, T.STYLE_SEPARATOR, const <int>[
          T.END_ARROW_L,
          T.LINE,
        ]);
      }
    } else {
      fail(T.NEWLINE, T.EOF, const <int>[
        T.acc_title,
        T.acc_descr,
        T.acc_descr_multiline_value,
        T.direction_tb,
        T.direction_bt,
        T.direction_rl,
        T.direction_lr,
        T.REQUIREMENT,
        T.FUNCTIONAL_REQUIREMENT,
        T.INTERFACE_REQUIREMENT,
        T.PERFORMANCE_REQUIREMENT,
        T.PHYSICAL_REQUIREMENT,
        T.DESIGN_CONSTRAINT,
        T.ELEMENT,
        T.CLASSDEF,
        T.CLASS,
        T.STYLE,
        T.unqString,
        T.qString,
      ]);
    }
  }
}

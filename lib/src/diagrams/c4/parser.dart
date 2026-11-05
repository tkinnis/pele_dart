// Upstream: src/diagrams/c4/parser.ts

import 'dart:math' as math;

import '../../errors.dart';
import '../../util/math_js.dart';
import 'db.dart';
import 'lexer.dart';
import 'tokens.dart';
import 'types.dart';

// Mermaid's typeC4Shape for each shape keyword, indexed from T.PERSON.
const List<String> _kinds = <String>[
  'person',
  'external_person',
  'system',
  'system_db',
  'system_queue',
  'external_system',
  'external_system_db',
  'external_system_queue',
  'container',
  'container_db',
  'container_queue',
  'external_container',
  'external_container_db',
  'external_container_queue',
  'component',
  'component_db',
  'component_queue',
  'external_component',
  'external_component_db',
  'external_component_queue',
];

const List<String> _relTypes = <String>[
  'rel',
  'birel',
  'rel_u',
  'rel_d',
  'rel_l',
  'rel_r',
  'rel_b',
  'rel',
];

const List<String> _nodeTypes = <String>['node', 'nodeL', 'nodeR'];

const String _headers =
    "'direction_tb', 'direction_bt', 'direction_rl', 'direction_lr', 'C4_CONTEXT', 'C4_CONTAINER', 'C4_COMPONENT', 'C4_DYNAMIC', 'C4_DEPLOYMENT'";
const String _attributes = "'STR', 'STR_KEY', 'ATTRIBUTE', 'ATTRIBUTE_EMPTY'";

abstract final class _P {
  // A statement is required.
  static const int item = 0;
  // Only a diagram statement may come next: the first one in a boundary, or one written straight after a title.
  static const int diagram = 1;
  static const int itemOrEnd = 2;
  static const int afterOther = 3;
  static const int afterDiagram = 4;
}

bool _isOther(int t) {
  return t == T.title ||
      t == T.accDescription ||
      t == T.acc_title ||
      t == T.acc_descr ||
      t == T.acc_descr_multiline_value;
}

bool _isDiagram(int t) {
  return t >= T.PERSON && t <= T.UPDATE_LAYOUT_CONFIG;
}

// Accepts what the parser Jison generates from c4Diagram.jison accepts, and calls the model
// builder in the order its semantic actions do. Boundaries nest through a counter, not recursion.
void parseC4(String src, C4Db db) {
  final tokens = tokenize(src);
  final types = tokens.types;
  final starts = tokens.starts;
  final ends = tokens.ends;
  var i = 0;

  String text(int at) => src.substring(starts[at], ends[at]);

  Never fail(String expected) {
    final t = types[i];
    if (t == T.ERROR) throw syntaxError('c4', src, starts[i], '', true);
    throw syntaxError(
      'c4',
      src,
      starts[i],
      "Expecting $expected, got '${TOKEN_NAMES[t]}'",
    );
  }

  void expect(int type) {
    if (types[i] != type) fail("'${TOKEN_NAMES[type]}'");
    i++;
  }

  List<C4Attr> attributes() {
    final attrs = <C4Attr>[];
    for (;;) {
      final t = types[i];
      if (t == T.STR) {
        attrs.add(text(i++).trim());
      } else if (t == T.ATTRIBUTE_EMPTY) {
        attrs.add('');
        i++;
      } else if (t == T.STR_KEY) {
        i++;
        if (types[i] != T.STR_VALUE) fail("'STR_VALUE'");
        attrs.add(C4Named(key: text(i - 1).trim(), value: text(i).trim()));
        i++;
      } else {
        break;
      }
    }
    if (attrs.isEmpty) fail(_attributes);
    return attrs;
  }

  void other(int t) {
    if (t == T.title) {
      db.setTitle(sliceJs(text(i++), 6));
    } else if (t == T.accDescription) {
      db.setAccDescription(sliceJs(text(i++), 15));
    } else if (t == T.acc_descr_multiline_value) {
      db.setAccDescription(text(i++).trim());
    } else {
      i++;
      if (t == T.acc_title) {
        if (types[i] != T.acc_title_value) fail("'acc_title_value'");
        // The grammar hands `accTitle:` to setTitle, so it becomes the visible title.
        db.setTitle(text(i++).trim());
      } else {
        if (types[i] != T.acc_descr_value) fail("'acc_descr_value'");
        db.setAccDescription(text(i++).trim());
      }
    }
  }

  // Returns true when the statement opens a boundary.
  bool diagram(int t) {
    i++;
    final attrs = attributes();
    if (t <= T.SYSTEM_EXT_QUEUE) {
      db.addPersonOrSystem(_kinds[t - T.PERSON], attrs);
    } else if (t <= T.CONTAINER_EXT_QUEUE) {
      db.addContainer(_kinds[t - T.PERSON], attrs);
    } else if (t <= T.COMPONENT_EXT_QUEUE) {
      db.addComponent(_kinds[t - T.PERSON], attrs);
    } else if (t <= T.NODE_R) {
      if (t == T.ENTERPRISE_BOUNDARY) {
        attrs.insert(math.min(2, attrs.length), 'ENTERPRISE');
      } else if (t == T.SYSTEM_BOUNDARY) {
        attrs.insert(math.min(2, attrs.length), 'SYSTEM');
      } else if (t == T.CONTAINER_BOUNDARY) {
        attrs.insert(math.min(2, attrs.length), 'CONTAINER');
      }
      if (t >= T.NODE) {
        db.addDeploymentNode(_nodeTypes[t - T.NODE], attrs);
      } else if (t == T.CONTAINER_BOUNDARY) {
        db.addContainerBoundary(attrs);
      } else {
        db.addPersonOrSystemBoundary(attrs);
      }
      if (types[i] == T.LBRACE) {
        i++;
        expect(T.NEWLINE);
      } else if (types[i] == T.NEWLINE) {
        i++;
        expect(T.LBRACE);
        if (types[i] == T.NEWLINE) i++;
      } else {
        fail("'NEWLINE', 'LBRACE'");
      }
      return true;
    } else if (t <= T.REL_INDEX) {
      // RelIndex takes a sequence number first, which Mermaid ignores.
      if (t == T.REL_INDEX && attrs.isNotEmpty) attrs.removeAt(0);
      db.addRel(_relTypes[t - T.REL], attrs);
    } else if (t == T.UPDATE_EL_STYLE) {
      db.updateElStyle('update_el_style', attrs);
    } else if (t == T.UPDATE_REL_STYLE) {
      db.updateRelStyle('update_rel_style', attrs);
    } else {
      db.updateLayoutConfig('update_layout_config', attrs);
    }
    return false;
  }

  final header = types[i];
  if (header < T.C4_CONTEXT || header > T.C4_DEPLOYMENT) fail(_headers);
  i++;
  expect(T.NEWLINE);

  var depth = 0;
  var state = _P.item;
  for (;;) {
    final t = types[i];
    if (state == _P.afterOther || state == _P.afterDiagram) {
      if (t == T.NEWLINE) {
        i++;
        state = _P.itemOrEnd;
        continue;
      }
      if (state == _P.afterOther && _isDiagram(t)) {
        state = _P.diagram;
        continue;
      }
    } else if (_isDiagram(t)) {
      if (diagram(t)) {
        depth++;
        state = _P.diagram;
      } else {
        state = _P.afterDiagram;
      }
      continue;
    } else if (_isOther(t) && state != _P.diagram) {
      other(t);
      state = _P.afterOther;
      continue;
    } else if (state != _P.itemOrEnd) {
      fail(
        "'title', 'accDescription', 'acc_title', 'acc_descr', 'acc_descr_multiline_value', 'PERSON', 'REL'",
      );
    }

    if (depth > 0) {
      if (t != T.RBRACE) fail("'NEWLINE', 'RBRACE'");
      i++;
      db.popBoundaryParseStack();
      depth--;
      state = _P.afterDiagram;
    } else {
      if (t != T.EOF) fail("'NEWLINE', 'EOF'");
      i++;
      expect(T.END);
      db.setC4Type(text(0));
      return;
    }
  }
}

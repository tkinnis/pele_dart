// Upstream: src/diagrams/state/db.ts

import 'graph.dart';
import 'parser.dart';
import 'types.dart';

class _Root {
  _Root({required this.id, required this.doc});
  final String id;
  List<Stmt> doc;
}

// Mermaid's StateDB in its version 2 form, which is what Mermaid uses for both `stateDiagram`
// and `stateDiagram-v2`. The legacy version, which numbers `[*]` states, is not ported.
class StateDb implements StateModel, StateBuilder {
  @override
  final String type = 'state';
  @override
  List<Stmt> rootDoc = <Stmt>[];
  @override
  Map<String, StateStmt> states = <String, StateStmt>{};
  @override
  List<StateRelation> relations = <StateRelation>[];
  @override
  Map<String, StateClassDef> classes = <String, StateClassDef>{};
  @override
  Map<String, StateLink> links = <String, StateLink>{};
  StateGraph graph = const StateGraph(
    nodes: <StateNode>[],
    edges: <StateEdge>[],
  );
  @override
  String? title;
  @override
  String? accTitle;
  @override
  String? accDescr;

  int _dividerCount = 0;

  // The direction the root document is laid out in: its last `direction` statement.
  @override
  String get direction {
    var dir = 'TB';
    for (final item in rootDoc) {
      if (item is DirectionStmt) dir = item.value;
    }
    return dir;
  }

  @override
  void setRootDoc(List<Stmt> doc) {
    rootDoc = doc;
    translate();
    extract(rootDoc);
  }

  // Only the root document's statements become states, relations and classes here; the
  // statements inside composites are read when the graph is built.
  void extract(List<Stmt> doc) {
    states = <String, StateStmt>{};
    relations = <StateRelation>[];
    classes = <String, StateClassDef>{};
    for (final item in doc) {
      if (item is String) continue;
      if (item is StateStmt) {
        addState(
          item.id.trim(),
          item.type,
          item.doc,
          item.description,
          item.note,
        );
      } else if (item is RelationStmt) {
        addRelation(item.state1, item.state2, item.description);
      } else if (item is ClassDefStmt) {
        addStyleClass(item.id.trim(), item.classes);
      } else if (item is StyleStmt) {
        final styles = item.styleClass
            .split(',')
            .map((s) => s.replaceAll(';', '').trim())
            .toList();
        for (final state in _named(item.id.trim())) {
          state.styles = List<String>.of(styles);
        }
      } else if (item is ApplyClassStmt) {
        setCssClass(item.id.trim(), item.styleClass);
      } else if (item is ClickStmt) {
        final clickId = item.id;
        addLink(
          clickId is String ? clickId : (clickId as StateStmt).id,
          item.url,
          item.tooltip,
        );
      }
    }
    graph = buildStateGraph(doc, states, classes);
  }

  // Mermaid's docTranslator: gives each `[*]` an id scoped to its parent, and turns a document
  // split by `--` into one region per part.
  void translate() {
    final rootNode = _Root(id: 'root', doc: rootDoc);
    final pending = <(String, Object, bool)>[('root', rootNode, true)];
    while (pending.isNotEmpty) {
      final (parentId, node, first) = pending.removeLast();
      if (node is String) continue;
      if (node is RelationStmt) {
        pending.add((parentId, node.state2, false));
        pending.add((parentId, node.state1, true));
        continue;
      }
      List<Stmt>? nodeDoc;
      String nodeId;
      if (node is StateStmt) {
        if (node.id == '[*]') {
          node.id = '$parentId${first ? '_start' : '_end'}';
          node.start = first;
        } else {
          node.id = node.id.trim();
        }
        nodeDoc = node.doc;
        nodeId = node.id;
      } else if (node is _Root) {
        nodeDoc = node.doc;
        nodeId = node.id;
      } else {
        continue;
      }
      if (nodeDoc == null) continue;

      final regions = <StateStmt>[];
      var current = <Stmt>[];
      for (final item in nodeDoc) {
        if (item is StateStmt && item.type == 'divider' && item.doc == null) {
          regions.add(item.copyWith(doc: current));
          current = <Stmt>[];
        } else {
          current.add(item);
        }
      }
      // Mermaid names the region after the last divider with a random id; here it continues the
      // divider numbering. Mermaid also leaves a document that ends with a divider ungrouped and
      // then fails to draw it; here the regions before that divider are kept.
      if (regions.isNotEmpty) {
        if (current.isNotEmpty) {
          regions.add(
            StateStmt(id: getDividerId(), type: 'divider', doc: current),
          );
        }
        nodeDoc = regions;
        if (node is StateStmt) {
          node.doc = nodeDoc;
        } else if (node is _Root) {
          node.doc = nodeDoc;
          rootDoc = nodeDoc;
        }
      }
      for (var i = nodeDoc.length - 1; i >= 0; i--) {
        pending.add((nodeId, nodeDoc[i], true));
      }
    }
  }

  void addState(
    String id, [
    String? type = 'default',
    List<Stmt>? doc,
    Object? descr,
    StateNote? note,
    List<String>? classes,
  ]) {
    final effType = type ?? 'default';
    final trimmedId = id.trim();
    var state = states[trimmedId];
    if (state == null) {
      state = StateStmt(
        id: trimmedId,
        descriptions: <String>[],
        type: effType,
        doc: doc,
        note: note,
        classes: <String>[],
        styles: <String>[],
        textStyles: <String>[],
      );
      states[trimmedId] = state;
    } else {
      state.doc ??= doc;
      if (state.type == null || state.type!.isEmpty) state.type = effType;
    }
    if (descr is List<String>) {
      for (final text in descr) {
        addDescription(trimmedId, text.trim());
      }
    } else if (descr is String && descr.isNotEmpty) {
      addDescription(trimmedId, descr.trim());
    }
    if (note != null) state.note = note;
    if (classes != null) {
      for (final name in classes) {
        setCssClass(trimmedId, name.trim());
      }
    }
  }

  StateStmt? getState(String id) {
    return states[id];
  }

  void addLink(String stateId, String url, String tooltip) {
    links[stateId] = StateLink(url: url, tooltip: tooltip);
  }

  void addRelation(StateStmt item1, StateStmt item2, [String? title]) {
    final effTitle = title ?? '';
    for (final item in <StateStmt>[item1, item2]) {
      addState(
        item.id,
        item.type,
        item.doc,
        item.description,
        item.note,
        item.classes,
      );
    }
    relations.add(
      StateRelation(
        id1: item1.id.trim(),
        id2: item2.id.trim(),
        relationTitle: effTitle,
      ),
    );
  }

  void addDescription(String id, String descr) {
    states[id]?.descriptions?.add(
      descr.startsWith(':') ? descr.replaceFirst(':', '').trim() : descr,
    );
  }

  @override
  String getDividerId() {
    return 'divider-id-${++_dividerCount}';
  }

  void addStyleClass(String id, [String? styleAttributes]) {
    var found = classes[id];
    if (found == null) {
      found = StateClassDef(id: id, styles: <String>[], textStyles: <String>[]);
      classes[id] = found;
    }
    if (styleAttributes == null || styleAttributes.isEmpty) return;
    for (final attrib in styleAttributes.split(',')) {
      final fixed = attrib.replaceFirst(';', '').trim();
      if (attrib.contains('color')) {
        found.textStyles.add(
          fixed.replaceFirst('fill', 'bgFill').replaceFirst('color', 'fill'),
        );
      }
      found.styles.add(fixed);
    }
  }

  void setCssClass(String itemIds, String cssClassName) {
    for (final state in _named(itemIds)) {
      state.classes?.add(cssClassName);
    }
  }

  String getDirection() {
    for (final item in rootDoc) {
      if (item is DirectionStmt) return item.value;
    }
    return 'TB';
  }

  // The grammar calls this while it is still building the document, so the statement lands in the
  // previous root document and the direction is read from the parsed `dir` statements instead.
  @override
  void setDirection(String dir) {
    for (final item in rootDoc) {
      if (item is DirectionStmt) {
        item.value = dir;
        return;
      }
    }
    rootDoc.insert(0, DirectionStmt(value: dir));
  }

  @override
  String trimColon(String text) {
    return text.startsWith(':') ? text.substring(1).trim() : text.trim();
  }

  @override
  void setAccTitle(String text) {
    accTitle = text.replaceFirst(RegExp(r'^\s+'), '');
  }

  @override
  void setAccDescription(String text) {
    accDescr = text.replaceAll(RegExp(r'\n\s+'), '\n');
  }

  // The states a comma-separated list of ids names, created where they do not exist yet. As in
  // Mermaid, an id is looked up as written and trimmed only when it has to be created.
  List<StateStmt> _named(String ids) {
    final out = <StateStmt>[];
    for (final id in ids.split(',')) {
      var state = states[id];
      if (state == null) {
        addState(id);
        state = states[id.trim()];
      }
      if (state != null) out.add(state);
    }
    return out;
  }
}

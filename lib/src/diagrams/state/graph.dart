// Upstream: src/diagrams/state/graph.ts

import '../../errors.dart';
import 'types.dart';

class StateNode {
  StateNode({
    required this.id,
    this.shape,
    this.label,
    required this.description,
    required this.cssClasses,
    required this.cssCompiledStyles,
    required this.cssStyles,
    this.type,
    required this.isGroup,
    this.parentId,
    this.dir,
    this.position,
    this.noteFor,
    this.colorIndex,
  });

  String id;
  // rect, rectWithTitle, stateStart, stateEnd, choice, fork, join, divider, roundedWithTitle, note or noteGroup.
  String? shape;
  String? label;
  List<String> description;
  String cssClasses;
  List<String> cssCompiledStyles;
  List<String> cssStyles;
  String? type;
  bool isGroup;
  String? parentId;
  // The direction inside a composite: its last `direction` statement, or TB.
  String? dir;
  String? position;
  String? noteFor;
  int? colorIndex;

  void assignFrom(StateNode other) {
    id = other.id;
    shape = other.shape;
    label = other.label;
    description = other.description;
    cssClasses = other.cssClasses;
    cssCompiledStyles = other.cssCompiledStyles;
    cssStyles = other.cssStyles;
    type = other.type;
    isGroup = other.isGroup;
    parentId = other.parentId;
    dir = other.dir;
    position = other.position;
    noteFor = other.noteFor;
    colorIndex = other.colorIndex;
  }
}

// Labels are markdown throughout, as in Mermaid.
class StateEdge {
  StateEdge({
    required this.id,
    required this.start,
    required this.end,
    required this.label,
    required this.classes,
    this.pattern,
  });

  final String id;
  final String start;
  final String end;
  final String label;
  final String classes;
  final String? pattern;
}

class StateGraph {
  const StateGraph({required this.nodes, required this.edges});

  final List<StateNode> nodes;
  final List<StateEdge> edges;
}

class _Draft {
  _Draft({
    this.shape,
    required this.description,
    required this.cssClasses,
    required this.cssStyles,
  });

  String? shape;
  // String or List<String>
  Object description;
  String cssClasses;
  List<String> cssStyles;
  String? type;
  String? dir;
  int? colorIndex;
}

class _Frame {
  _Frame({this.item, required this.doc, required this.at, required this.alt});

  final StateStmt? item;
  final List<Stmt> doc;
  int at;
  final bool alt;
}

String _direction(List<Stmt> doc) {
  var dir = 'TB';
  for (final item in doc) {
    if (item is DirectionStmt) dir = item.value;
  }
  return dir;
}

bool _hasDescription(Object? d) =>
    d is List<String> || (d is String && d.isNotEmpty);

List<String> _flatDescription(Object d) =>
    d is List<String> ? List<String>.of(d) : <String>[d as String];

int _descLength(Object d) =>
    d is List<String> ? d.length : (d as String).length;

// Mermaid's dataFetcher: walks the documents and resolves them into the nodes and edges that are drawn.
StateGraph buildStateGraph(
  List<Stmt> rootDoc,
  Map<String, StateStmt> states,
  Map<String, StateClassDef> classes,
) {
  final nodes = <StateNode>[];
  final edges = <StateEdge>[];
  final byId = <String, StateNode>{};
  final drafts = <String, _Draft>{};
  final slots = <String, int?>{};
  var counter = 0;
  var nextSlot = 0;

  void insert(StateNode node) {
    // The two literal ids are what DOMPurify leaves of `<<fork>>` and `<<choice>>` in Mermaid; kept for parity.
    if (node.id.isEmpty ||
        node.id == '</join></fork>' ||
        node.id == '</choice>') {
      return;
    }
    if (node.cssClasses.isNotEmpty) {
      // One copy, however many classes: a state named in a class statement many times has a long list.
      List<String>? compiled;
      for (final name in node.cssClasses.split(' ')) {
        final def = classes[name];
        if (def == null) continue;
        compiled ??= List<String>.of(node.cssCompiledStyles);
        for (final style in def.styles) {
          compiled.add(style);
        }
      }
      if (compiled != null) node.cssCompiledStyles = compiled;
    }
    final existing = byId[node.id];
    if (existing != null) {
      final parentId = node.parentId ?? existing.parentId;
      existing.assignFrom(node);
      if (parentId != null) existing.parentId = parentId;
    } else {
      byId[node.id] = node;
      nodes.add(node);
    }
  }

  void visit(StateStmt? parent, StateStmt item, bool alt) {
    final id = item.id;
    if (id == 'root') return;
    final known = states[id];
    final classStr = known?.classes?.join(' ') ?? '';
    final styles = known?.styles ?? <String>[];

    var draft = drafts[id];
    if (draft == null) {
      String? shape = 'rect';
      if (item.start == true) {
        shape = 'stateStart';
      } else if (item.start == false) {
        shape = 'stateEnd';
      }
      if (item.type != 'default') shape = item.type;
      draft = _Draft(
        shape: shape,
        description: id,
        cssClasses: '$classStr statediagram-state',
        cssStyles: styles,
      );
      drafts[id] = draft;
    }

    if (_hasDescription(item.description)) {
      final itemDesc = item.description!;
      final draftDesc = draft.description;
      if (draftDesc is List<String>) {
        draft.shape = 'rectWithTitle';
        draft.description = <String>[
          ...draftDesc,
          ..._flatDescription(itemDesc),
        ];
      } else if ((draftDesc as String).isNotEmpty) {
        draft.shape = 'rectWithTitle';
        draft.description = draftDesc == id
            ? _flatDescription(itemDesc)
            : <String>[draftDesc, ..._flatDescription(itemDesc)];
      } else {
        draft.shape = 'rect';
        draft.description = itemDesc is List<String>
            ? List<String>.of(itemDesc)
            : itemDesc;
      }
    }
    if (_descLength(draft.description) == 1 && draft.shape == 'rectWithTitle') {
      draft.shape = draft.type == 'group' ? 'roundedWithTitle' : 'rect';
    }

    if ((draft.type == null || draft.type!.isEmpty) && item.doc != null) {
      draft.type = 'group';
      draft.dir = _direction(item.doc!);
      draft.shape = item.type == 'divider' ? 'divider' : 'roundedWithTitle';
      // A container takes the next palette slot unless it is a region, which shares its composite's.
      if (draft.shape == 'divider' &&
          parent != null &&
          slots.containsKey(parent.id)) {
        draft.colorIndex = slots[parent.id];
      } else {
        final slot = nextSlot++;
        draft.colorIndex = (classStr.trim().isNotEmpty || styles.isNotEmpty)
            ? null
            : slot;
      }
      slots[id] = draft.colorIndex;
      draft.cssClasses =
          '${draft.cssClasses} statediagram-cluster ${alt ? 'statediagram-cluster-alt' : ''}';
    }

    final full = draft.description;
    final node = StateNode(
      id: id,
      shape: draft.shape,
      label: full is List<String>
          ? (full.isNotEmpty ? full[0] : null)
          : full as String,
      description: full is List<String> && full.length > 1
          ? full.sublist(1)
          : <String>[],
      cssClasses: draft.cssClasses,
      cssCompiledStyles: <String>[],
      cssStyles: draft.cssStyles,
      type: draft.type,
      isGroup: draft.type == 'group',
      dir: draft.dir,
      colorIndex: draft.colorIndex,
    );
    if (node.shape == 'divider') node.label = '';
    if (parent != null && parent.id != 'root') node.parentId = parent.id;

    final note = item.note;
    if (note == null) {
      insert(node);
      return;
    }
    // Mermaid puts each note in a group of its own, named after the state. Pele keeps that
    // group in the model and lays the note out beside its state instead.
    StateNode aside(
      String asideId,
      String shape,
      String cssClasses,
      bool isGroup,
    ) => StateNode(
      id: asideId,
      shape: shape,
      label: note.text,
      description: <String>[],
      cssClasses: cssClasses,
      cssCompiledStyles: <String>[],
      cssStyles: <String>[],
      type: isGroup ? 'group' : 'node',
      isGroup: isGroup,
      position: note.position,
    );

    final noteNode = aside(
      '$id----note-${counter++}',
      'note',
      'statediagram-note',
      false,
    );
    noteNode.parentId = '$id----parent';
    noteNode.noteFor = id;
    insert(aside(noteNode.parentId!, 'noteGroup', draft.cssClasses, true));
    insert(noteNode);
    insert(node);
    final left = note.position == 'left of';
    final from = left ? noteNode.id : id;
    final to = left ? id : noteNode.id;
    edges.add(
      StateEdge(
        id: '$from-$to',
        start: from,
        end: to,
        label: '',
        classes: 'transition note-edge',
        pattern: 'dashed',
      ),
    );
  }

  final stack = <_Frame>[_Frame(doc: rootDoc, at: 0, alt: true)];
  while (stack.isNotEmpty) {
    final frame = stack.last;
    if (frame.at >= frame.doc.length) {
      stack.removeLast();
      continue;
    }
    final item = frame.doc[frame.at++];
    if (item is String) continue;
    if (item is StateStmt) {
      visit(frame.item, item, frame.alt);
      if (item.doc != null) {
        stack.add(_Frame(item: item, doc: item.doc!, at: 0, alt: !frame.alt));
      }
    } else if (item is RelationStmt) {
      visit(frame.item, item.state1, frame.alt);
      visit(frame.item, item.state2, frame.alt);
      edges.add(
        StateEdge(
          id: 'edge${counter++}',
          start: item.state1.id,
          end: item.state2.id,
          label: item.description ?? '',
          classes: 'transition',
        ),
      );
    }
  }

  for (final node in nodes) {
    if (node.isGroup && node.description.isNotEmpty) {
      throw PeleError(
        'Group nodes can only have label. Remove the additional description for node [${node.id}]',
        'semantic',
        const PeleErrorInfo(type: 'state'),
      );
    }
  }
  return StateGraph(nodes: nodes, edges: edges);
}

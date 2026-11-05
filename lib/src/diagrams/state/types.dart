// Upstream: src/diagrams/state/types.ts

class StateNote {
  StateNote({this.position, required this.text});

  String? position;
  String text;
}

sealed class StateAstStmt {
  String get stmt;
}

class StateStmt implements StateAstStmt {
  StateStmt({
    required this.id,
    this.type,
    this.description,
    this.descriptions,
    this.doc,
    this.note,
    this.start,
    this.classes,
    this.styles,
    this.textStyles,
  });

  @override
  String get stmt => 'state';
  String id;
  String? type;
  // String or List<String>
  Object? description;
  List<String>? descriptions;
  List<Stmt>? doc;
  StateNote? note;
  bool? start;
  List<String>? classes;
  List<String>? styles;
  List<String>? textStyles;

  StateStmt copyWith({
    String? id,
    String? type,
    Object? description,
    List<String>? descriptions,
    List<Stmt>? doc,
    StateNote? note,
    bool? start,
    List<String>? classes,
    List<String>? styles,
    List<String>? textStyles,
  }) => StateStmt(
    id: id ?? this.id,
    type: type ?? this.type,
    description: description ?? this.description,
    descriptions: descriptions ?? this.descriptions,
    doc: doc ?? this.doc,
    note: note ?? this.note,
    start: start ?? this.start,
    classes: classes ?? this.classes,
    styles: styles ?? this.styles,
    textStyles: textStyles ?? this.textStyles,
  );
}

class RelationStmt implements StateAstStmt {
  RelationStmt({required this.state1, required this.state2, this.description});

  @override
  String get stmt => 'relation';
  StateStmt state1;
  StateStmt state2;
  String? description;
}

class ClassDefStmt implements StateAstStmt {
  ClassDefStmt({required this.id, required this.classes});

  @override
  String get stmt => 'classDef';
  String id;
  String classes;
}

class StyleStmt implements StateAstStmt {
  StyleStmt({required this.id, required this.styleClass});

  @override
  String get stmt => 'style';
  String id;
  String styleClass;
}

class ApplyClassStmt implements StateAstStmt {
  ApplyClassStmt({required this.id, required this.styleClass});

  @override
  String get stmt => 'applyClass';
  String id;
  String styleClass;
}

class DirectionStmt implements StateAstStmt {
  DirectionStmt({required this.value});

  @override
  String get stmt => 'dir';
  String value;
}

class ClickStmt implements StateAstStmt {
  ClickStmt({required this.id, required this.url, required this.tooltip});

  @override
  String get stmt => 'click';
  // StateStmt or String
  Object id;
  String url;
  String tooltip;
}

// Mermaid's grammar also leaves the text of statements that have no effect in a document
// (`hide empty description`, `scale`, a bare `state name`, a floating note); those are the strings.
typedef Stmt = Object;

class StateRelation {
  StateRelation({required this.id1, required this.id2, this.relationTitle});

  String id1;
  String id2;
  String? relationTitle;
}

class StateClassDef {
  StateClassDef({
    required this.id,
    required this.styles,
    required this.textStyles,
  });

  String id;
  List<String> styles;
  List<String> textStyles;
}

class StateLink {
  StateLink({required this.url, required this.tooltip});

  final String url;
  final String tooltip;
}

abstract interface class StateModel {
  String get type;
  String get direction;
  List<Stmt> get rootDoc;
  Map<String, StateStmt> get states;
  List<StateRelation> get relations;
  Map<String, StateClassDef> get classes;
  Map<String, StateLink> get links;
  String? get title;
  String? get accTitle;
  String? get accDescr;
}

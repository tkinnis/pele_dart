// Upstream: src/diagrams/er/types.ts

import '../../svg/root.dart';

typedef Cardinality = String;
typedef Identification = String;

class ErAttribute {
  ErAttribute({
    required this.type,
    required this.name,
    required this.keys,
    required this.comment,
  });

  String type;
  String name;
  List<String> keys;
  String comment;
}

/// What the parser hands over for one attribute; keys and comment are present only when written.
class ParsedAttribute {
  ParsedAttribute({
    required this.type,
    required this.name,
    this.keys,
    this.comment,
  });

  String type;
  String name;
  List<String>? keys;
  String? comment;
}

class ErEntity {
  ErEntity({
    required this.id,
    required this.label,
    required this.alias,
    required this.attributes,
    required this.cssClasses,
    required this.cssStyles,
  });

  String id;
  String label;
  String alias;
  List<ErAttribute> attributes;
  String cssClasses;
  List<String> cssStyles;
}

/// cardB sits at entityA's end of the line and cardA at entityB's, as in Mermaid.
class RelSpec {
  const RelSpec({
    required this.cardA,
    required this.relType,
    required this.cardB,
  });

  final Cardinality cardA;
  final Identification relType;
  final Cardinality cardB;
}

/// entityA and entityB hold an entity's id, or a subgraph's id when the name was a subgraph at the time.
class ErRelationship {
  const ErRelationship({
    required this.entityA,
    required this.roleA,
    required this.entityB,
    required this.relSpec,
  });

  final String entityA;
  final String roleA;
  final String entityB;
  final RelSpec relSpec;
}

class ErClassDef {
  ErClassDef({
    required this.id,
    required this.styles,
    required this.textStyles,
  });

  final String id;
  final List<String> styles;
  final List<String> textStyles;
}

class ErSubgraph {
  ErSubgraph({
    required this.id,
    required this.nodes,
    required this.title,
    required this.classes,
    required this.cssStyles,
    required this.dir,
    required this.labelType,
  });

  final String id;
  final List<String> nodes;
  final String title;
  final List<String> classes;
  final List<String> cssStyles;
  final String? dir;
  final String labelType;
}

class DirStmt {
  const DirStmt(this.value);

  final String stmt = 'dir';
  final String value;
}

/// Either a `String`, a [DirStmt], or a nested `List<DocItem>`.
typedef DocItem = Object;

abstract interface class ErModel implements RootModel {
  String get type;
  String get direction;
  Map<String, ErEntity> get entities;
  List<ErRelationship> get relationships;
  Map<String, ErClassDef> get classes;
  List<ErSubgraph> get subgraphs;
  String? get title;
  @override
  String? get accTitle;
  @override
  String? get accDescr;
}

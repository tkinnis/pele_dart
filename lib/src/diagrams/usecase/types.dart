// Upstream: src/diagrams/usecase/types.ts

import '../../svg/root.dart';

typedef LabelType = String;
typedef ActorType = String;
typedef UseCaseShape = String;
typedef BoundaryType = String;
typedef RelationshipType = String;
typedef Animation = String;
typedef Direction = String;
typedef SymbolKind = String;

/// Start and end offsets in the source, end exclusive.
typedef Span = List<int>;

abstract interface class Stylable {
  List<String> get classes;
  List<String> get styles;
}

class Actor implements Stylable {
  Actor({
    required this.id,
    required this.label,
    required this.labelType,
    required this.type,
    this.icon,
    required this.business,
    this.stereotype,
    this.parentId,
    required this.classes,
    required this.styles,
  });

  String id;
  String label;
  LabelType labelType;
  ActorType type;
  String? icon;
  bool business;
  String? stereotype;
  String? parentId;
  @override
  List<String> classes;
  @override
  List<String> styles;
}

class UseCase implements Stylable {
  UseCase({
    required this.id,
    required this.label,
    required this.labelType,
    required this.shape,
    required this.business,
    this.stereotype,
    this.parentId,
    required this.classes,
    required this.styles,
  });

  String id;
  String label;
  LabelType labelType;
  UseCaseShape shape;
  bool business;
  String? stereotype;
  String? parentId;
  @override
  List<String> classes;
  @override
  List<String> styles;
}

class SystemBoundary implements Stylable {
  SystemBoundary({
    required this.id,
    required this.label,
    required this.labelType,
    required this.type,
    required this.members,
    required this.classes,
    required this.styles,
  });

  String id;
  String label;
  LabelType labelType;
  BoundaryType type;
  List<String> members;
  @override
  List<String> classes;
  @override
  List<String> styles;
}

abstract final class Arrow {
  static const int SOLID_ARROW = 0;
  static const int BACK_ARROW = 1;
  static const int LINE_SOLID = 2;
  static const int CIRCLE_ARROW = 3;
  static const int CROSS_ARROW = 4;
  static const int CIRCLE_ARROW_REVERSED = 5;
  static const int CROSS_ARROW_REVERSED = 6;
}

class Relationship implements Stylable {
  Relationship({
    required this.id,
    required this.explicitId,
    required this.source,
    required this.target,
    required this.type,
    required this.arrowType,
    this.label,
    this.labelType,
    required this.minlen,
    required this.classes,
    required this.styles,
    required this.animate,
    this.animation,
  });

  String id;
  bool explicitId;
  String source;
  String target;
  RelationshipType type;
  int arrowType;
  String? label;
  LabelType? labelType;
  int minlen;
  @override
  List<String> classes;
  @override
  List<String> styles;
  bool animate;
  Animation? animation;
}

class UsecaseNote {
  UsecaseNote({
    required this.id,
    required this.target,
    required this.label,
    required this.labelType,
  });

  String id;
  String target;
  String label;
  LabelType labelType;
}

class UsecaseJsonNode implements Stylable {
  UsecaseJsonNode({
    required this.id,
    required this.value,
    required this.propertyOrder,
    required this.classes,
    required this.styles,
  });

  String id;
  Map<String, Object?> value;
  // The keys of each object in the order they were written, by JSON Pointer.
  Map<String, List<String>> propertyOrder;
  @override
  List<String> classes;
  @override
  List<String> styles;
}

class ClassDef {
  ClassDef({required this.id, required this.styles});

  String id;
  List<String> styles;
}

class MetadataOccurrence {
  MetadataOccurrence({
    required this.key,
    required this.span,
    required this.keySpan,
    required this.valueSpan,
  });

  final String key;
  final Span span;
  final Span keySpan;
  final Span valueSpan;
}

class NodeOccurrence {
  NodeOccurrence({
    required this.id,
    required this.span,
    required this.idSpan,
    this.labelSpan,
    this.defines,
    this.stereotypeSpan,
    this.metadata,
    this.classSpans,
  });

  String id;
  Span span;
  Span idSpan;
  Span? labelSpan;
  bool? defines;
  Span? stereotypeSpan;
  List<MetadataOccurrence>? metadata;
  List<Span>? classSpans;
}

class EdgeOccurrence {
  EdgeOccurrence({
    required this.id,
    required this.span,
    this.labelSpan,
    this.idSpan,
    this.metadata,
  });

  String id;
  Span span;
  Span? labelSpan;
  Span? idSpan;
  List<MetadataOccurrence>? metadata;
}

/// One statement of the source with the positions of its parts, as in Mermaid's use case AST.
class GraphStatement {
  GraphStatement({
    required this.kind,
    required this.span,
    this.nodes,
    this.edges,
    this.group,
    this.idSpan,
    this.titleSpan,
    this.endSpan,
    this.ref,
    this.refSpan,
    this.children,
    this.metadata,
    this.classSpans,
  });

  String kind;
  Span span;
  List<NodeOccurrence>? nodes;
  List<EdgeOccurrence>? edges;
  String? group;
  Span? idSpan;
  Span? titleSpan;
  Span? endSpan;
  String? ref;
  Span? refSpan;
  List<GraphStatement>? children;
  List<MetadataOccurrence>? metadata;
  List<Span>? classSpans;
}

class UsecaseModel implements Accessible {
  UsecaseModel({
    required this.actors,
    required this.useCases,
    required this.systemBoundaries,
    required this.relationships,
    required this.notes,
    required this.jsonNodes,
    required this.classDefs,
    required this.direction,
    this.title,
    required this.accTitle,
    required this.accDescr,
    required this.accDescription,
    required this.source,
    required this.headerSpan,
    required this.statements,
  });

  final String type = 'usecase';
  final Map<String, Actor> actors;
  final Map<String, UseCase> useCases;
  final Map<String, SystemBoundary> systemBoundaries;
  final List<Relationship> relationships;
  final Map<String, UsecaseNote> notes;
  final Map<String, UsecaseJsonNode> jsonNodes;
  final Map<String, ClassDef> classDefs;
  Direction direction;
  String? title;
  @override
  String accTitle;
  @override
  String accDescr;
  // The accessible description as written, before the indentation of its lines is dropped.
  String accDescription;
  String source;
  Span headerSpan;
  List<GraphStatement> statements;
}

UsecaseModel emptyModel() {
  return UsecaseModel(
    actors: <String, Actor>{},
    useCases: <String, UseCase>{},
    systemBoundaries: <String, SystemBoundary>{},
    relationships: <Relationship>[],
    notes: <String, UsecaseNote>{},
    jsonNodes: <String, UsecaseJsonNode>{},
    classDefs: <String, ClassDef>{},
    direction: 'LR',
    title: null,
    accTitle: '',
    accDescr: '',
    accDescription: '',
    source: '',
    headerSpan: <int>[0, 0],
    statements: <GraphStatement>[],
  );
}

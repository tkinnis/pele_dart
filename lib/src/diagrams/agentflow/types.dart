// Upstream: src/diagrams/agentflow/types.ts

import '../../svg/root.dart';
import '../../util/yaml.dart';

typedef LabelType = String;

class FlowText {
  const FlowText({required this.text, required this.type});

  final String text;
  final LabelType type;
}

// A source span as Jison reports it: lines start at 1, columns at 0.
class Loc {
  const Loc({
    required this.first_line,
    required this.first_column,
    required this.last_line,
    required this.last_column,
  });

  final int first_line;
  final int first_column;
  final int last_line;
  final int last_column;
}

typedef Metadata = Map<String, YamlValue>;

typedef VertexKind = String;

typedef EdgeSemantic = String;

class AgentNode {
  AgentNode({
    required this.id,
    this.text,
    required this.labelType,
    this.type,
    required this.styles,
    required this.classes,
    this.dir,
    this.props,
    this.link,
    this.linkTarget,
    this.metadata,
    this.isConnector,
  });

  String id;
  String? text;
  LabelType labelType;
  String? type;
  List<String> styles;
  List<String> classes;
  String? dir;
  Map<String, String>? props;
  String? link;
  String? linkTarget;
  Metadata? metadata;
  bool? isConnector;
}

class AgentEdge {
  AgentEdge({
    required this.start,
    required this.end,
    this.type,
    required this.text,
    required this.labelType,
    this.stroke,
    this.edgeSemantic,
    this.length,
    this.style,
    required this.classes,
    this.id,
    required this.isUserDefinedId,
    this.interpolate,
    this.animate,
    this.animation,
    this.metadata,
  });

  String start;
  String end;
  String? type;
  String text;
  LabelType labelType;
  String? stroke;
  EdgeSemantic? edgeSemantic;
  int? length;
  List<String>? style;
  List<String> classes;
  String? id;
  bool isUserDefinedId;
  String? interpolate;
  YamlValue animate;
  YamlValue animation;
  Metadata? metadata;
}

class AgentClassDef {
  AgentClassDef({
    required this.id,
    required this.styles,
    required this.textStyles,
  });

  String id;
  List<String> styles;
  List<String> textStyles;
}

class AgentSubgraph {
  AgentSubgraph({
    required this.id,
    required this.nodes,
    required this.title,
    required this.classes,
    this.dir,
    required this.labelType,
    this.type = 'flow',
    this.metadata,
  });

  String id;
  List<String> nodes;
  String title;
  List<String> classes;
  String? dir;
  LabelType labelType;
  String type;
  Metadata? metadata;
}

class AgentLinkInfo {
  AgentLinkInfo({
    required this.type,
    required this.stroke,
    this.length,
    this.edgeSemantic,
    this.text,
    this.id,
  });

  String type;
  String stroke;
  int? length;
  EdgeSemantic? edgeSemantic;
  FlowText? text;
  String? id;
}

class DirStmt {
  const DirStmt(this.value) : stmt = 'dir';

  final String stmt;
  final String value;
}

// String | List<String> | DirStmt
typedef DocItem = Object;

class ElementPosition {
  ElementPosition({
    required this.startLine,
    required this.startColumn,
    required this.endLine,
    required this.endColumn,
    required this.startIndex,
    required this.endIndex,
  });

  int startLine;
  int startColumn;
  int endLine;
  int endColumn;
  int startIndex;
  int endIndex;

  @override
  bool operator ==(Object other) =>
      other is ElementPosition &&
      other.startLine == startLine &&
      other.startColumn == startColumn &&
      other.endLine == endLine &&
      other.endColumn == endColumn &&
      other.startIndex == startIndex &&
      other.endIndex == endIndex;

  @override
  int get hashCode => Object.hash(
    startLine,
    startColumn,
    endLine,
    endColumn,
    startIndex,
    endIndex,
  );
}

typedef StatementType = String;

class ElementMapping {
  ElementMapping({
    required this.id,
    required this.type,
    required this.position,
  });

  String id;
  StatementType type;
  ElementPosition position;

  @override
  bool operator ==(Object other) =>
      other is ElementMapping &&
      other.id == id &&
      other.type == type &&
      other.position == position;

  @override
  int get hashCode => Object.hash(id, type, position);
}

typedef DiagnosticId = String;

class Diagnostic {
  Diagnostic({
    required this.id,
    required this.severity,
    required this.message,
    this.nodeId,
    this.edgeId,
    this.position,
  });

  final DiagnosticId id;
  final String severity;
  final String message;
  String? nodeId;
  String? edgeId;
  ElementPosition? position;
}

class SemanticVertex {
  SemanticVertex({
    required this.id,
    this.label,
    this.shape,
    this.vertexKind,
    this.metadata,
  });

  String id;
  String? label;
  String? shape;
  VertexKind? vertexKind;
  Metadata? metadata;
}

class SemanticEdge {
  SemanticEdge({
    required this.start,
    required this.end,
    this.id,
    this.label,
    this.type,
    this.stroke,
    this.edgeSemantic,
    this.length,
    this.metadata,
  });

  String start;
  String end;
  String? id;
  String? label;
  String? type;
  String? stroke;
  EdgeSemantic? edgeSemantic;
  int? length;
  Metadata? metadata;
}

class SemanticSubgraph {
  SemanticSubgraph({
    required this.id,
    this.type,
    this.title,
    required this.nodes,
    this.metadata,
    this.direction,
  });

  String id;
  String? type;
  String? title;
  List<String> nodes;
  Metadata? metadata;
  String? direction;
}

class SemanticConnector {
  SemanticConnector({required this.id, this.title, this.metadata});

  String id;
  String? title;
  Metadata? metadata;
}

// The diagram with presentation-only controls left out, for tools that read what it means.
class SemanticModel {
  SemanticModel({
    this.direction,
    required this.vertices,
    required this.edges,
    required this.subGraphs,
    required this.connectors,
    required this.diagnostics,
  });

  String? direction;
  final List<SemanticVertex> vertices;
  final List<SemanticEdge> edges;
  final List<SemanticSubgraph> subGraphs;
  final List<SemanticConnector> connectors;
  final List<Diagnostic> diagnostics;
}

abstract interface class AgentflowModel implements Accessible {
  String get type;
  String? get direction;
  Map<String, AgentNode> get nodes;
  List<AgentEdge> get edges;
  List<AgentSubgraph> get subgraphs;
  Map<String, AgentNode> get connectors;
  Map<String, AgentClassDef> get classes;
  Map<String, String> get tooltips;
  List<String>? get defaultEdgeStyle;
  String? get defaultInterpolate;
  // Where each statement sits in the source, in the order the statements were read.
  List<ElementMapping> get mappings;
  List<Diagnostic> get diagnostics;
  String? get title;
  @override
  String? get accTitle;
  @override
  String? get accDescr;
  SemanticModel semanticModel();
}

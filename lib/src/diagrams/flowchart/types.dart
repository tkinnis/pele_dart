// Upstream: src/diagrams/flowchart/types.ts

import '../../svg/root.dart';
import '../../util/yaml.dart';

typedef LabelType = String;

class FlowText {
  FlowText({required this.text, required this.type});

  String text;
  LabelType type;
}

class FlowNode {
  FlowNode({
    required this.id,
    this.text,
    required this.labelType,
    this.type,
    List<String>? styles,
    List<String>? classes,
    this.dir,
    this.props,
    this.link,
    this.linkTarget,
    this.icon,
    this.form,
    this.pos,
    this.img,
    this.constraint,
    this.assetWidth,
    this.assetHeight,
  }) : styles = styles ?? <String>[],
       classes = classes ?? <String>[];

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
  String? icon;
  String? form;
  String? pos;
  String? img;
  String? constraint;
  double? assetWidth;
  double? assetHeight;
}

class FlowEdge {
  FlowEdge({
    required this.start,
    required this.end,
    this.type,
    required this.text,
    required this.labelType,
    this.stroke,
    this.length,
    this.style,
    List<String>? classes,
    this.id,
    required this.isUserDefinedId,
    this.interpolate,
    this.animate,
    this.animation,
  }) : classes = classes ?? <String>[];

  String start;
  String end;
  String? type;
  String text;
  LabelType labelType;
  String? stroke;
  int? length;
  List<String>? style;
  List<String> classes;
  String? id;
  bool isUserDefinedId;
  String? interpolate;
  bool? animate;
  String? animation;
}

class FlowClassDef {
  FlowClassDef({
    required this.id,
    List<String>? styles,
    List<String>? textStyles,
  }) : styles = styles ?? <String>[],
       textStyles = textStyles ?? <String>[];

  String id;
  List<String> styles;
  List<String> textStyles;
}

class FlowSubgraph {
  FlowSubgraph({
    required this.id,
    required this.nodes,
    required this.title,
    List<String>? classes,
    this.dir,
    required this.labelType,
    this.metadata,
  }) : classes = classes ?? <String>[];

  String id;
  List<String> nodes;
  String title;
  List<String> classes;
  String? dir;
  LabelType labelType;
  Map<String, YamlValue>? metadata;
}

class FlowLinkInfo {
  FlowLinkInfo({
    required this.type,
    required this.stroke,
    this.length,
    this.text,
    this.id,
  });

  String type;
  String stroke;
  int? length;
  FlowText? text;
  String? id;
}

class DirStmt {
  const DirStmt(this.value);

  final String stmt = 'dir';
  final String value;
}

/// Union type: `String | List<String> | DirStmt`.
typedef DocItem = Object;

abstract interface class FlowchartModel implements Accessible {
  String get type;
  String? get direction;
  Map<String, FlowNode> get nodes;
  List<FlowEdge> get edges;
  List<FlowSubgraph> get subgraphs;
  Map<String, FlowClassDef> get classes;
  Map<String, String> get tooltips;
  List<String>? get defaultEdgeStyle;
  String? get defaultInterpolate;
  String? get title;
  @override
  String? get accTitle;
  @override
  String? get accDescr;
}

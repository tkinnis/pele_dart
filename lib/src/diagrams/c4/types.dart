// Upstream: src/diagrams/c4/types.ts

import '../../svg/root.dart';

// A `$key="value"` argument.
class C4Named {
  const C4Named({required this.key, required this.value});

  final String key;
  final String value;
}

/// Either a positional [String] or a named [C4Named] argument.
typedef C4Attr = Object;

class C4Element {
  C4Element({
    required this.alias,
    required this.label,
    this.aliasAttr,
    this.labelAttr,
    this.parent,
    this.type,
    this.descr,
    this.techn,
    this.sprite,
    this.tags,
    this.link,
    this.bgColor,
    this.fontColor,
    this.borderColor,
    this.shadowing,
    this.shape,
    this.legendText,
    this.legendSprite,
    this.extra,
  });

  String alias;
  String label;
  // A named argument written where the alias or the label belongs. It is applied to the field it names.
  C4Named? aliasAttr;
  C4Named? labelAttr;
  C4Boundary? parent;
  String? type;
  String? descr;
  String? techn;
  String? sprite;
  String? tags;
  String? link;
  String? bgColor;
  String? fontColor;
  String? borderColor;
  String? shadowing;
  String? shape;
  String? legendText;
  String? legendSprite;
  // Named arguments that set no known field.
  Map<String, String>? extra;
}

class C4Shape extends C4Element {
  C4Shape({
    required super.alias,
    required super.label,
    required this.kind,
    super.aliasAttr,
    super.labelAttr,
    super.parent,
    super.type,
    super.descr,
    super.techn,
    super.sprite,
    super.tags,
    super.link,
    super.bgColor,
    super.fontColor,
    super.borderColor,
    super.shadowing,
    super.shape,
    super.legendText,
    super.legendSprite,
    super.extra,
  });

  // Mermaid's typeC4Shape: person, external_system_db, container_queue and so on.
  String kind;
}

class C4Boundary extends C4Element {
  C4Boundary({
    required super.alias,
    required super.label,
    super.aliasAttr,
    super.labelAttr,
    super.parent,
    super.type,
    super.descr,
    super.techn,
    super.sprite,
    super.tags,
    super.link,
    super.bgColor,
    super.fontColor,
    super.borderColor,
    super.shadowing,
    super.shape,
    super.legendText,
    super.legendSprite,
    super.extra,
    this.nodeType,
  });

  // Set on deployment nodes: node, nodeL or nodeR.
  String? nodeType;
}

class C4Rel {
  C4Rel({
    required this.type,
    required this.from,
    required this.to,
    required this.label,
    this.fromAttr,
    this.toAttr,
    this.labelAttr,
    this.techn,
    this.descr,
    this.sprite,
    this.tags,
    this.link,
    this.textColor,
    this.lineColor,
    this.offsetX,
    this.offsetY,
    this.extra,
  });

  String type;
  String from;
  String to;
  String label;
  C4Named? fromAttr;
  C4Named? toAttr;
  C4Named? labelAttr;
  String? techn;
  String? descr;
  String? sprite;
  String? tags;
  String? link;
  String? textColor;
  String? lineColor;
  int? offsetX;
  int? offsetY;
  Map<String, String>? extra;
}

abstract interface class C4Model implements Accessible {
  String get type;
  // The header keyword: C4Context, C4Container, C4Component, C4Dynamic or C4Deployment.
  String? get c4Type;
  String? get title;
  @override
  String? get accTitle;
  @override
  String? get accDescr;
  List<C4Shape> get shapes;
  // The first boundary is the unnamed one that holds everything at the top level.
  List<C4Boundary> get boundaries;
  List<C4Rel> get rels;
  int get shapeInRow;
  int get boundaryInRow;
}

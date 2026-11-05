// Upstream: src/diagrams/block/types.ts

import '../../svg/root.dart';

// One shape for blocks, edges, and the statements that set columns, classes, and styles, as in Mermaid.
class Block {
  String id;
  String? type;
  String? label;
  List<Object>? children;
  int? columns;
  int? widthInColumns;
  // Number of cells a `space` statement asked for.
  int? width;
  List<String>? directions;
  List<String>? classes;
  List<String>? styles;
  int? colorIndex;
  String? start;
  String? end;
  String? arrowTypeStart;
  String? arrowTypeEnd;
  String? thickness;
  String? pattern;
  String? css;
  String? styleClass;
  String? stylesStr;

  Block({
    this.id = '',
    this.type,
    this.label,
    this.children,
    this.columns,
    this.widthInColumns,
    this.width,
    this.directions,
    this.classes,
    this.styles,
    this.colorIndex,
    this.start,
    this.end,
    this.arrowTypeStart,
    this.arrowTypeEnd,
    this.thickness,
    this.pattern,
    this.css,
    this.styleClass,
    this.stylesStr,
  });

  List<Block> get blockChildren =>
      children == null ? const <Block>[] : children!.cast<Block>();

  Block copyWith({
    String? id,
    String? type,
    String? label,
    List<Object>? children,
    int? columns,
    int? widthInColumns,
    int? width,
    List<String>? directions,
    List<String>? classes,
    List<String>? styles,
    int? colorIndex,
    String? start,
    String? end,
    String? arrowTypeStart,
    String? arrowTypeEnd,
    String? thickness,
    String? pattern,
    String? css,
    String? styleClass,
    String? stylesStr,
  }) => Block(
    id: id ?? this.id,
    type: type ?? this.type,
    label: label ?? this.label,
    children: children ?? this.children,
    columns: columns ?? this.columns,
    widthInColumns: widthInColumns ?? this.widthInColumns,
    width: width ?? this.width,
    directions: directions ?? this.directions,
    classes: classes ?? this.classes,
    styles: styles ?? this.styles,
    colorIndex: colorIndex ?? this.colorIndex,
    start: start ?? this.start,
    end: end ?? this.end,
    arrowTypeStart: arrowTypeStart ?? this.arrowTypeStart,
    arrowTypeEnd: arrowTypeEnd ?? this.arrowTypeEnd,
    thickness: thickness ?? this.thickness,
    pattern: pattern ?? this.pattern,
    css: css ?? this.css,
    styleClass: styleClass ?? this.styleClass,
    stylesStr: stylesStr ?? this.stylesStr,
  );
}

// A statement with links is a list: block, edge, block, and so on.
// In Dart, Statement is either a Block or a List<Block>.
typedef Statement = Object;

class BlockClassDef {
  final String id;
  final List<String> styles;
  final List<String> textStyles;

  BlockClassDef({
    required this.id,
    List<String>? styles,
    List<String>? textStyles,
  }) : styles = styles ?? <String>[],
       textStyles = textStyles ?? <String>[];
}

abstract interface class BlockModel implements RootModel {
  String get type;
  Block get root;
  List<Block> get blocks;
  List<Block> get edges;
  Map<String, BlockClassDef> get classes;
  Map<String, Block> get byId;
  String? get title;
  // Never set: the grammar reads accTitle and accDescr but has no statement that accepts them.
  @override
  String? get accTitle;
  @override
  String? get accDescr;
}

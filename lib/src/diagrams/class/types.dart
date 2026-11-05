// Upstream: src/diagrams/class/types.ts

import '../../svg/root.dart';
import 'members.dart';

/// Either a numeric `RelationType` index (`int`) or `'none'`.
typedef RelationEnd = Object;

class ClassNode {
  String id;
  String type;
  String label;
  String cssClasses;
  List<ClassMember> methods;
  List<ClassMember> members;
  List<String> annotations;
  List<String> styles;
  String? parent;
  String? link;
  String? linkTarget;
  bool? haveCallback;
  String? tooltip;

  ClassNode({
    required this.id,
    required this.type,
    required this.label,
    required this.cssClasses,
    List<ClassMember>? methods,
    List<ClassMember>? members,
    List<String>? annotations,
    List<String>? styles,
    this.parent,
    this.link,
    this.linkTarget,
    this.haveCallback,
    this.tooltip,
  }) : methods = methods ?? <ClassMember>[],
       members = members ?? <ClassMember>[],
       annotations = annotations ?? <String>[],
       styles = styles ?? <String>[];
}

class RelationSpec {
  RelationEnd type1;
  RelationEnd type2;
  int lineType;

  RelationSpec({
    required this.type1,
    required this.type2,
    required this.lineType,
  });
}

class ClassRelation {
  String id1;
  String id2;
  String relationTitle1;
  String relationTitle2;
  String? title;
  RelationSpec relation;

  ClassRelation({
    required this.id1,
    required this.id2,
    required this.relationTitle1,
    required this.relationTitle2,
    this.title,
    required this.relation,
  });
}

class ClassNote {
  final String id;
  final String? className;
  final String text;
  final int index;
  String? parent;

  ClassNote({
    required this.id,
    this.className,
    required this.text,
    required this.index,
    this.parent,
  });
}

class ClassInterface {
  final String id;
  final String label;
  final String classId;

  const ClassInterface({
    required this.id,
    required this.label,
    required this.classId,
  });
}

class NamespaceNode {
  final String id;
  String label;
  final Map<String, ClassNode> classes;
  final Map<String, ClassNote> notes;
  final Map<String, NamespaceNode> children;
  String? parent;
  // False for the ancestors created on the way to a dotted name such as `A.B.C`.
  bool explicit;

  NamespaceNode({
    required this.id,
    required this.label,
    Map<String, ClassNode>? classes,
    Map<String, ClassNote>? notes,
    Map<String, NamespaceNode>? children,
    this.parent,
    required this.explicit,
  }) : classes = classes ?? <String, ClassNode>{},
       notes = notes ?? <String, ClassNote>{},
       children = children ?? <String, NamespaceNode>{};
}

class StyleClass {
  final String id;
  final List<String> styles;
  final List<String> textStyles;

  StyleClass({required this.id, List<String>? styles, List<String>? textStyles})
    : styles = styles ?? <String>[],
      textStyles = textStyles ?? <String>[];
}

abstract interface class ClassModel implements RootModel {
  String get type;
  String get direction;
  Map<String, ClassNode> get classes;
  List<ClassRelation> get relations;
  Map<String, ClassNote> get notes;
  Map<String, NamespaceNode> get namespaces;
  List<ClassInterface> get interfaces;
  Map<String, StyleClass> get styleClasses;
  String? get title;
  @override
  String? get accTitle;
  @override
  String? get accDescr;
}

// Upstream: src/diagrams/requirement/types.ts

import '../../svg/root.dart';

class Requirement {
  Requirement({
    required this.name,
    required this.type,
    required this.requirementId,
    required this.text,
    required this.risk,
    required this.verifyMethod,
    required this.cssStyles,
    required this.classes,
  });

  String name;
  String type;
  String requirementId;
  String text;
  String risk;
  String verifyMethod;
  List<String> cssStyles;
  List<String> classes;
}

class RequirementElement {
  RequirementElement({
    required this.name,
    required this.type,
    required this.docRef,
    required this.cssStyles,
    required this.classes,
  });

  String name;
  String type;
  String docRef;
  List<String> cssStyles;
  List<String> classes;
}

class Relation {
  const Relation({required this.type, required this.src, required this.dst});

  final String type;
  final String src;
  final String dst;
}

class RequirementClass {
  RequirementClass({
    required this.id,
    required this.styles,
    required this.textStyles,
  });

  final String id;
  final List<String> styles;
  final List<String> textStyles;
}

abstract interface class RequirementModel implements RootModel {
  String get type;
  String get direction;
  Map<String, Requirement> get requirements;
  Map<String, RequirementElement> get elements;
  List<Relation> get relations;
  Map<String, RequirementClass> get classes;
  String? get title;
  @override
  String? get accTitle;
  @override
  String? get accDescr;
}

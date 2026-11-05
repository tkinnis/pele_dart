// Upstream: src/diagrams/requirement/db.ts

import '../../errors.dart';
import 'types.dart';

abstract final class RequirementType {
  static const String REQUIREMENT = 'Requirement';
  static const String FUNCTIONAL_REQUIREMENT = 'Functional Requirement';
  static const String INTERFACE_REQUIREMENT = 'Interface Requirement';
  static const String PERFORMANCE_REQUIREMENT = 'Performance Requirement';
  static const String PHYSICAL_REQUIREMENT = 'Physical Requirement';
  static const String DESIGN_CONSTRAINT = 'Design Constraint';
}

abstract final class RiskLevel {
  static const String LOW_RISK = 'Low';
  static const String MED_RISK = 'Medium';
  static const String HIGH_RISK = 'High';
}

abstract final class VerifyType {
  static const String VERIFY_ANALYSIS = 'Analysis';
  static const String VERIFY_DEMONSTRATION = 'Demonstration';
  static const String VERIFY_INSPECTION = 'Inspection';
  static const String VERIFY_TEST = 'Test';
}

abstract final class Relationships {
  static const String CONTAINS = 'contains';
  static const String COPIES = 'copies';
  static const String DERIVES = 'derives';
  static const String SATISFIES = 'satisfies';
  static const String VERIFIES = 'verifies';
  static const String REFINES = 'refines';
  static const String TRACES = 'traces';
}

/// Applying a class copies its declarations onto each node, so a short text can ask for
/// hundreds of millions of copies. Past this many the diagram is refused.
const int _maxStyleCopies = 1000000;

final RegExp _reLeadingSpaces = RegExp(r'^\s+');
final RegExp _reNewlineSpaces = RegExp(r'\n\s+');

class RequirementDb implements RequirementModel {
  @override
  final String type = 'requirement';
  @override
  String direction = 'TB';
  @override
  final Map<String, Requirement> requirements = <String, Requirement>{};
  @override
  final Map<String, RequirementElement> elements =
      <String, RequirementElement>{};
  @override
  final List<Relation> relations = <Relation>[];
  @override
  final Map<String, RequirementClass> classes = <String, RequirementClass>{};
  @override
  String? title;
  @override
  String? accTitle;
  @override
  String? accDescr;

  // The grammar reports a body's fields before the requirement or element they belong to.
  String _newId = '';
  String _newText = '';
  String _newRisk = '';
  String _newVerifyMethod = '';
  String _newElementType = '';
  String _newDocRef = '';
  int _styleCopies = 0;

  void _copy(List<String> target, List<String> styles) {
    _styleCopies += styles.length;
    if (_styleCopies > _maxStyleCopies) {
      throw PeleError(
        'Requirement diagram applies too many style declarations.',
        'limit',
        const PeleErrorInfo(type: 'requirement'),
      );
    }
    target.addAll(styles);
  }

  void setDirection(String dir) {
    direction = dir;
  }

  Requirement addRequirement(String name, String type) {
    var requirement = requirements[name];
    if (requirement == null) {
      requirement = Requirement(
        name: name,
        type: type,
        requirementId: _newId,
        text: _newText,
        risk: _newRisk,
        verifyMethod: _newVerifyMethod,
        cssStyles: <String>[],
        classes: <String>['default'],
      );
      requirements[name] = requirement;
    }
    _newId = '';
    _newText = '';
    _newRisk = '';
    _newVerifyMethod = '';
    return requirement;
  }

  void setNewReqId(String id) {
    _newId = id;
  }

  void setNewReqText(String text) {
    _newText = text;
  }

  void setNewReqRisk(String risk) {
    _newRisk = risk;
  }

  void setNewReqVerifyMethod(String verifyMethod) {
    _newVerifyMethod = verifyMethod;
  }

  RequirementElement addElement(String name) {
    var element = elements[name];
    if (element == null) {
      element = RequirementElement(
        name: name,
        type: _newElementType,
        docRef: _newDocRef,
        cssStyles: <String>[],
        classes: <String>['default'],
      );
      elements[name] = element;
    }
    _newElementType = '';
    _newDocRef = '';
    return element;
  }

  void setNewElementType(String type) {
    _newElementType = type;
  }

  void setNewElementDocRef(String docRef) {
    _newDocRef = docRef;
  }

  void addRelationship(String type, String src, String dst) {
    relations.add(Relation(type: type, src: src, dst: dst));
  }

  ({List<String> cssStyles, List<String> classes})? _node(String id) {
    final req = requirements[id];
    if (req != null) return (cssStyles: req.cssStyles, classes: req.classes);
    final el = elements[id];
    if (el != null) return (cssStyles: el.cssStyles, classes: el.classes);
    return null;
  }

  void setCssStyle(List<String> ids, List<String>? styles) {
    for (final id in ids) {
      final node = _node(id);
      // Mermaid stops at the first unknown id, leaving the rest of the list unstyled.
      if (styles == null || node == null) return;
      for (final s in styles) {
        _copy(node.cssStyles, s.contains(',') ? s.split(',') : <String>[s]);
      }
    }
  }

  void setClass(List<String> ids, List<String> classNames) {
    for (final id in ids) {
      final node = _node(id);
      if (node == null) continue;
      for (final name in classNames) {
        node.classes.add(name);
        final styles = classes[name]?.styles;
        if (styles != null) _copy(node.cssStyles, styles);
      }
    }
  }

  void defineClass(List<String> ids, List<String> style) {
    for (final id in ids) {
      var styleClass = classes[id];
      if (styleClass == null) {
        styleClass = RequirementClass(
          id: id,
          styles: <String>[],
          textStyles: <String>[],
        );
        classes[id] = styleClass;
      }
      for (final s in style) {
        if (s.contains('color')) {
          styleClass.textStyles.add(s.replaceFirst('fill', 'bgFill'));
        }
        styleClass.styles.add(s);
      }
      final split = <String>[for (final s in style) ...s.split(',')];
      for (final requirement in requirements.values) {
        if (requirement.classes.contains(id)) {
          _copy(requirement.cssStyles, split);
        }
      }
      for (final element in elements.values) {
        if (element.classes.contains(id)) {
          _copy(element.cssStyles, split);
        }
      }
    }
  }

  void setAccTitle(String text) {
    accTitle = text.replaceFirst(_reLeadingSpaces, '');
  }

  void setAccDescription(String text) {
    accDescr = text.replaceAll(_reNewlineSpaces, '\n');
  }
}

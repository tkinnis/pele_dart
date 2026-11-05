// Upstream: src/diagrams/kanban/db.ts

import '../../errors.dart';
import '../../util/yaml.dart';
import '../common/outline.dart' as outline;

class KanbanNode {
  String id;
  int level;
  String label;
  String? icon;
  String? assigned;
  String? ticket;
  String? priority;
  String? cssClasses;

  KanbanNode({
    required this.id,
    required this.level,
    required this.label,
    this.icon,
    this.assigned,
    this.ticket,
    this.priority,
    this.cssClasses,
  });
}

class KanbanSection extends KanbanNode {
  List<KanbanNode> items;

  KanbanSection({
    required super.id,
    required super.level,
    required super.label,
    super.icon,
    super.assigned,
    super.ticket,
    super.priority,
    super.cssClasses,
    List<KanbanNode>? items,
  }) : items = items ?? <KanbanNode>[];
}

abstract interface class KanbanModel {
  String get type;
  String? get title;
  List<KanbanSection> get sections;
}

bool _truthy(Object? v) =>
    v != null && v != false && v != 0 && v != '' && !(v is double && v.isNaN);

class KanbanDb implements KanbanModel, outline.OutlineDb {
  @override
  final String type = 'kanban';
  @override
  String? title;
  @override
  List<KanbanSection> sections = <KanbanSection>[];

  KanbanNode? _last;
  int _sectionLevel = 0;
  KanbanNode? _misplaced;

  @override
  int getType(String start, String end) => outline.getType(start, end);

  @override
  void addNode(
    int level,
    String id,
    String descr,
    int type, [
    String? shapeData,
  ]) {
    final node = KanbanNode(id: id, level: level, label: descr);

    if (shapeData != null) {
      final yaml = shapeData.contains('\n')
          ? '$shapeData\n'
          : '{\n$shapeData\n}';
      YamlValue doc;
      try {
        doc = parseYaml(yaml);
      } catch (error) {
        final msg = error is StateError ? error.message : '$error';
        throw PeleError(
          'Metadata of "${node.id}" is not valid YAML. $msg',
          'syntax',
          const PeleErrorInfo(type: 'kanban'),
        );
      }
      // Mermaid throws a TypeError on metadata that is empty or not a mapping. Here it is ignored.
      if (doc is Map) {
        final shapeVal = doc['shape'];
        final shape = _truthy(shapeVal) ? '$shapeVal' : '';
        if (shape != shape.toLowerCase() || shape.contains('_')) {
          throw PeleError(
            'No such shape: $shape. Shape names should be lowercase.',
            'semantic',
            const PeleErrorInfo(type: 'kanban'),
          );
        }
        if (_truthy(doc['label'])) node.label = '${doc['label']}';
        if (_truthy(doc['icon'])) node.icon = '${doc['icon']}';
        if (_truthy(doc['assigned'])) node.assigned = '${doc['assigned']}';
        if (_truthy(doc['ticket'])) node.ticket = '${doc['ticket']}';
        if (_truthy(doc['priority'])) node.priority = '${doc['priority']}';
      }
    }

    // A node indented less than the first column becomes a card, and Mermaid rejects whatever follows it.
    if (_misplaced != null) {
      throw PeleError(
        'Items without section detected, found section ("${_misplaced!.label}")',
        'semantic',
        const PeleErrorInfo(type: 'kanban'),
      );
    }
    if (sections.isEmpty) _sectionLevel = level;
    if (level == _sectionLevel) {
      final section = KanbanSection(
        id: node.id,
        level: node.level,
        label: node.label,
        icon: node.icon,
        assigned: node.assigned,
        ticket: node.ticket,
        priority: node.priority,
        cssClasses: node.cssClasses,
      );
      _last = section;
      sections.add(section);
    } else {
      _last = node;
      sections.last.items.add(node);
      if (level < _sectionLevel) _misplaced = node;
    }
  }

  // Mermaid throws a TypeError when a decoration comes before any node. Here it is ignored.
  @override
  void decorateNode([outline.OutlineDecoration? decoration]) {
    final node = _last;
    if (decoration == null || node == null) return;
    if (decoration.icon != null && decoration.icon!.isNotEmpty) {
      node.icon = decoration.icon;
    }
    if (decoration.className != null && decoration.className!.isNotEmpty) {
      node.cssClasses = decoration.className;
    }
  }
}

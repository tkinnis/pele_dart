// Upstream: src/diagrams/er/db.ts

import 'types.dart';

String _labelType(String? type) {
  return type == 'markdown' || type == 'string' || type == 'text'
      ? type!
      : 'markdown';
}

Iterable<DocItem> _flattenDocItems(Iterable<DocItem> items) sync* {
  for (final item in items) {
    if (item is Iterable<DocItem>) {
      yield* item;
    } else {
      yield item;
    }
  }
}

final RegExp _reLeadingSpaces = RegExp(r'^\s+');
final RegExp _reNewlineSpaces = RegExp(r'\n\s+');

class ErDb implements ErModel {
  @override
  final String type = 'er';
  @override
  String direction = 'TB';
  @override
  final Map<String, ErEntity> entities = <String, ErEntity>{};
  @override
  final List<ErRelationship> relationships = <ErRelationship>[];
  @override
  final Map<String, ErClassDef> classes = <String, ErClassDef>{};
  @override
  final List<ErSubgraph> subgraphs = <ErSubgraph>[];
  @override
  String? title;
  @override
  String? accTitle;
  @override
  String? accDescr;

  final Map<String, ErSubgraph> _subgraphLookup = <String, ErSubgraph>{};
  final Set<String> _claimed = <String>{};

  ErEntity addEntity(String name, [String alias = '']) {
    var entity = entities[name];
    if (entity == null) {
      entity = ErEntity(
        id: 'entity-$name-${entities.length}',
        label: name,
        alias: alias,
        attributes: <ErAttribute>[],
        cssClasses: 'default',
        cssStyles: <String>[],
      );
      entities[name] = entity;
    } else if (entity.alias.isEmpty && alias.isNotEmpty) {
      entity.alias = alias;
    }
    return entity;
  }

  /// The grammar builds the list back to front, so the last attribute written comes first.
  void addAttributes(String name, List<ParsedAttribute> attributes) {
    final entity = addEntity(name);
    for (var i = attributes.length - 1; i >= 0; i--) {
      final attribute = attributes[i];
      entity.attributes.add(
        ErAttribute(
          type: attribute.type,
          name: attribute.name,
          keys: attribute.keys ?? <String>[],
          comment: attribute.comment ?? '',
        ),
      );
    }
  }

  void addRelationship(
    String entA,
    String roleA,
    String entB,
    RelSpec relSpec,
  ) {
    final entityA = _subgraphLookup.containsKey(entA)
        ? entA
        : addEntity(entA).id;
    final entityB = _subgraphLookup.containsKey(entB)
        ? entB
        : addEntity(entB).id;
    relationships.add(
      ErRelationship(
        entityA: entityA,
        roleA: roleA,
        entityB: entityB,
        relSpec: relSpec,
      ),
    );
  }

  void setDirection(String dir) {
    direction = dir;
  }

  void addCssStyles(List<String> ids, List<String>? styles) {
    if (styles == null) return;
    for (final id in ids) {
      final entity = entities[id];
      if (entity != null) {
        for (final style in styles) {
          entity.cssStyles.add(style);
        }
      }
      final subgraph = _subgraphLookup[id];
      if (subgraph != null) {
        for (final style in styles) {
          subgraph.cssStyles.add(style);
        }
      }
    }
  }

  void addClass(List<String> ids, List<String>? styles) {
    for (final id in ids) {
      var def = classes[id];
      if (def == null) {
        def = ErClassDef(id: id, styles: <String>[], textStyles: <String>[]);
        classes[id] = def;
      }
      if (styles == null) continue;
      for (final style in styles) {
        if (style.contains('color')) {
          def.textStyles.add(style.replaceFirst('fill', 'bgFill'));
        }
        def.styles.add(style);
      }
    }
  }

  void setClass(List<String> ids, List<String> classNames) {
    for (final id in ids) {
      final entity = entities[id];
      if (entity != null) {
        for (final name in classNames) {
          entity.cssClasses += ' $name';
        }
      }
      final subgraph = _subgraphLookup[id];
      if (subgraph != null) {
        for (final name in classNames) {
          subgraph.classes.add(name);
        }
      }
    }
  }

  String addSubGraph(
    ({String text}) idText,
    List<DocItem> list,
    ({String text, String? type}) titleText,
  ) {
    final id = idText.text.trim();
    final seen = <String>{};
    final nodes = <String>[];
    String? dir;
    for (final item in _flattenDocItems(list)) {
      if (item is! String) {
        if (item is DirStmt && item.stmt == 'dir') {
          dir = item.value;
        }
        continue;
      }
      final trimmed = item.trim();
      if (trimmed.isEmpty || seen.contains(trimmed)) continue;
      seen.add(trimmed);
      // A node belongs to the first subgraph that lists it.
      if (!_claimed.contains(item)) nodes.add(item);
    }
    for (final node in nodes) {
      _claimed.add(node);
    }
    final subgraph = ErSubgraph(
      id: id,
      nodes: nodes,
      title: titleText.text.trim(),
      classes: <String>[],
      cssStyles: <String>[],
      dir: dir,
      labelType: _labelType(titleText.type),
    );
    subgraphs.add(subgraph);
    _subgraphLookup[id] = subgraph;
    return id;
  }

  void setAccTitle(String text) {
    accTitle = text.replaceFirst(_reLeadingSpaces, '');
  }

  void setAccDescription(String text) {
    accDescr = text.replaceAll(_reNewlineSpaces, '\n');
  }
}

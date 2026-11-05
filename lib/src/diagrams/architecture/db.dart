// Upstream: src/diagrams/architecture/db.ts

import '../../errors.dart';
import 'parser.dart';

sealed class ArchNode {
  const ArchNode({required this.id, required this.type, this.inGroup});

  final String id;
  final String type;
  // Upstream property: `in`
  final String? inGroup;
}

class ArchService extends ArchNode {
  const ArchService({
    required super.id,
    this.icon,
    this.iconText,
    this.title,
    super.inGroup,
  }) : super(type: 'service');

  final String? icon;
  final String? iconText;
  final String? title;
}

class ArchJunction extends ArchNode {
  const ArchJunction({required super.id, super.inGroup})
    : super(type: 'junction');
}

class ArchGroup {
  const ArchGroup({required this.id, this.icon, this.title, this.inGroup});

  final String id;
  final String? icon;
  final String? title;
  // Upstream property: `in`
  final String? inGroup;
}

class ArchEdge {
  const ArchEdge({
    required this.lhsId,
    required this.lhsDir,
    this.lhsInto,
    this.lhsGroup,
    required this.rhsId,
    required this.rhsDir,
    this.rhsInto,
    this.rhsGroup,
    this.title,
  });

  final String lhsId;
  final Side lhsDir;
  final bool? lhsInto;
  final bool? lhsGroup;
  final String rhsId;
  final Side rhsDir;
  final bool? rhsInto;
  final bool? rhsGroup;
  final String? title;
}

class ArchLayoutHint {
  const ArchLayoutHint({required this.direction, required this.members});

  /// `'row' | 'column'`
  final String direction;
  final List<String> members;
}

abstract interface class ArchitectureModel {
  String get type;
  String? get title;
  String? get accTitle;
  String? get accDescr;
  Map<String, ArchNode> get nodes;
  Map<String, ArchGroup> get groups;
  List<ArchEdge> get edges;
  List<ArchLayoutHint> get layoutHints;
}

Never _fail(String message) {
  throw PeleError(
    message,
    'semantic',
    const PeleErrorInfo(type: 'architecture'),
  );
}

class ArchitectureDb implements ArchitectureModel {
  @override
  final String type = 'architecture';
  @override
  String? title;
  @override
  String? accTitle;
  @override
  String? accDescr;
  @override
  final Map<String, ArchNode> nodes = <String, ArchNode>{};
  @override
  final Map<String, ArchGroup> groups = <String, ArchGroup>{};
  @override
  final List<ArchEdge> edges = <ArchEdge>[];
  @override
  final List<ArchLayoutHint> layoutHints = <ArchLayoutHint>[];

  final Map<String, String> _registered = <String, String>{};

  void _register(String kind, String id, String? parent) {
    if (_registered.containsKey(id)) {
      _fail(
        'The $kind id [$id] is already in use by another ${_registered[id]}',
      );
    }
    if (parent != null) {
      if (id == parent) {
        _fail('The $kind [$id] cannot be placed within itself');
      }
      if (!_registered.containsKey(parent)) {
        _fail(
          "The $kind [$id]'s parent does not exist. Please make sure the parent is created before this $kind",
        );
      }
      if (_registered[parent] == 'node') {
        _fail("The $kind [$id]'s parent is not a group");
      }
    }
    _registered[id] = kind == 'group' ? 'group' : 'node';
  }

  void addService({
    required String id,
    String? icon,
    String? iconText,
    String? title,
    String? inGroup,
  }) {
    _register('service', id, inGroup);
    nodes[id] = ArchService(
      id: id,
      icon: icon,
      iconText: iconText,
      title: title,
      inGroup: inGroup,
    );
  }

  void addJunction({required String id, String? inGroup}) {
    _register('junction', id, inGroup);
    nodes[id] = ArchJunction(id: id, inGroup: inGroup);
  }

  void addGroup(ArchGroup group) {
    _register('group', group.id, group.inGroup);
    groups[group.id] = ArchGroup(
      id: group.id,
      icon: group.icon,
      title: group.title,
      inGroup: group.inGroup,
    );
  }

  void addEdge(ArchEdge edge) {
    final ends = <(String, String, bool?)>[
      ('left', edge.lhsId, edge.lhsGroup),
      ('right', edge.rhsId, edge.rhsGroup),
    ];
    for (final (side, id, _) in ends) {
      if (!_registered.containsKey(id)) {
        _fail(
          'The $side-hand id [$id] does not yet exist. Please create the service/group before declaring an edge to it.',
        );
      }
    }
    // Mermaid lets a group id through the check above and then fails with a TypeError.
    for (final (side, id, _) in ends) {
      if (!nodes.containsKey(id)) {
        _fail(
          'The $side-hand id [$id] is a group. Add {group} to a service inside it instead.',
        );
      }
    }
    final parent = nodes[edge.lhsId]!.inGroup;
    if (parent != null && parent == nodes[edge.rhsId]!.inGroup) {
      for (final (side, id, crosses) in ends) {
        if (crosses == true) {
          _fail(
            'The $side-hand id [$id] is modified to traverse the group boundary, but the edge does not pass through two groups.',
          );
        }
      }
    }
    edges.add(
      ArchEdge(
        lhsId: edge.lhsId,
        lhsDir: edge.lhsDir,
        lhsInto: edge.lhsInto,
        lhsGroup: edge.lhsGroup,
        rhsId: edge.rhsId,
        rhsDir: edge.rhsDir,
        rhsInto: edge.rhsInto,
        rhsGroup: edge.rhsGroup,
        title: edge.title,
      ),
    );
  }

  void addLayoutHint(ArchLayoutHint hint) {
    if (hint.members.length < 2) {
      _fail(
        'An align directive requires at least two members; got ${hint.members.length}',
      );
    }
    final seen = <String>{};
    for (final id in hint.members) {
      if (_registered[id] != 'node') {
        _fail(
          'align ${hint.direction} references [$id], which is not a service or junction',
        );
      }
      if (seen.contains(id)) {
        _fail('align ${hint.direction} lists [$id] more than once');
      }
      seen.add(id);
    }
    layoutHints.add(hint);
  }
}

// Mermaid's populateDb: every group, then services, junctions, edges, and alignments.
void populate(ArchitectureAst ast, ArchitectureDb db) {
  if (ast.accDescr != null && ast.accDescr!.isNotEmpty) {
    db.accDescr = ast.accDescr!.replaceAll(RegExp(r'\n\s+'), '\n');
  }
  if (ast.accTitle != null && ast.accTitle!.isNotEmpty) {
    db.accTitle = ast.accTitle!.replaceAll(RegExp(r'^\s+'), '');
  }
  if (ast.title != null && ast.title!.isNotEmpty) {
    db.title = ast.title;
  }
  for (final group in ast.groups) {
    db.addGroup(
      ArchGroup(
        id: group.id,
        icon: group.icon,
        title: group.title,
        inGroup: group.inGroup,
      ),
    );
  }
  for (final service in ast.services) {
    db.addService(
      id: service.id,
      icon: service.icon,
      iconText: service.iconText,
      title: service.title,
      inGroup: service.inGroup,
    );
  }
  for (final junction in ast.junctions) {
    db.addJunction(id: junction.id, inGroup: junction.inGroup);
  }
  for (final edge in ast.edges) {
    db.addEdge(
      ArchEdge(
        lhsId: edge.lhsId,
        lhsDir: edge.lhsDir,
        lhsInto: edge.lhsInto,
        lhsGroup: edge.lhsGroup,
        rhsId: edge.rhsId,
        rhsDir: edge.rhsDir,
        rhsInto: edge.rhsInto,
        rhsGroup: edge.rhsGroup,
        title: edge.title,
      ),
    );
  }
  for (final alignment in ast.alignments) {
    db.addLayoutHint(
      ArchLayoutHint(
        direction: alignment.direction,
        members: List<String>.of(alignment.members),
      ),
    );
  }
}

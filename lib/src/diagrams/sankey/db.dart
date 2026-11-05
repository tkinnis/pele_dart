// Upstream: src/diagrams/sankey/db.ts

class SankeyNode {
  const SankeyNode({required this.id, required this.index});

  final String id;
  final int index;

  @override
  bool operator ==(Object other) =>
      other is SankeyNode && other.id == id && other.index == index;

  @override
  int get hashCode => Object.hash(id, index);
}

class SankeyLink {
  const SankeyLink({
    required this.source,
    required this.target,
    required this.value,
  });

  final SankeyNode source;
  final SankeyNode target;
  final double value;

  @override
  bool operator ==(Object other) =>
      other is SankeyLink &&
      other.source == source &&
      other.target == target &&
      other.value == value;

  @override
  int get hashCode => Object.hash(source, target, value);
}

abstract interface class SankeyModel {
  String get type;
  List<SankeyNode> get nodes;
  List<SankeyLink> get links;
  String? get title;
  String? get accTitle;
  String? get accDescr;
}

class SankeyDb implements SankeyModel {
  @override
  final String type = 'sankey';
  @override
  List<SankeyNode> nodes = <SankeyNode>[];
  @override
  List<SankeyLink> links = <SankeyLink>[];
  @override
  String? title;
  @override
  String? accTitle;
  @override
  String? accDescr;

  final Map<String, SankeyNode> _lookup = <String, SankeyNode>{};

  SankeyNode findOrCreateNode(String id) {
    var node = _lookup[id];
    if (node == null) {
      node = SankeyNode(id: id, index: nodes.length);
      _lookup[id] = node;
      nodes.add(node);
    }
    return node;
  }

  void addLink(SankeyNode source, SankeyNode target, double value) {
    links.add(SankeyLink(source: source, target: target, value: value));
  }
}

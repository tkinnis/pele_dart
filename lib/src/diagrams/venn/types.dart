// Upstream: src/diagrams/venn/types.ts

// A set (one id) or an overlap of sets (two or more ids, sorted), with its relative area.
class VennSubset {
  final List<String> sets;
  final double size;
  final String? label;

  const VennSubset({required this.sets, required this.size, this.label});
}

// A line of text shown inside the region of the given sets.
class VennText {
  final List<String> sets;
  final String id;
  final String? label;

  const VennText({required this.sets, required this.id, this.label});
}

// Targets are the sorted ids of a set or overlap, or the id of a text.
class VennStyle {
  final List<String> targets;
  final Map<String, String> styles;

  const VennStyle({required this.targets, required this.styles});
}

abstract interface class VennModel {
  String get type;
  String? get title;
  List<VennSubset> get subsets;
  List<VennText> get textNodes;
  List<VennStyle> get styles;
}

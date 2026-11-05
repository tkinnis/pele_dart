// Upstream: src/diagrams/ishikawa/types.ts

class IshikawaNode {
  final String text;
  final List<IshikawaNode> children;

  IshikawaNode({required this.text, List<IshikawaNode>? children})
    : children = children ?? <IshikawaNode>[];
}

// The root is the effect; its children are the categories of causes, theirs the causes, and so on.
abstract interface class IshikawaModel {
  String get type;
  String? get title;
  IshikawaNode? get root;
}

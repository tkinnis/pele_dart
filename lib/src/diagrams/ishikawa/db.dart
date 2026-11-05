// Upstream: src/diagrams/ishikawa/db.ts

import 'dart:math' as math;

import 'types.dart';

class _StackEntry {
  final int level;
  final IshikawaNode node;

  const _StackEntry({required this.level, required this.node});
}

class IshikawaDb implements IshikawaModel {
  @override
  final String type = 'ishikawa';
  @override
  String? title;
  @override
  IshikawaNode? root;

  // The line of ancestors of the last node, each with its level.
  List<_StackEntry> _stack = <_StackEntry>[];
  int? _baseLevel;

  // The first line is the effect. Every later line is a cause, nested by its indentation relative
  // to the first cause, so the effect itself may be indented more than the causes.
  void addNode(int rawLevel, String text) {
    final node = IshikawaNode(text: text);
    if (root == null) {
      root = node;
      _stack = <_StackEntry>[_StackEntry(level: 0, node: node)];
      return;
    }
    _baseLevel ??= rawLevel;
    final level = math.max<int>(rawLevel - _baseLevel! + 1, 1);
    while (_stack.length > 1 && _stack.last.level >= level) {
      _stack.removeLast();
    }
    _stack.last.node.children.add(node);
    _stack.add(_StackEntry(level: level, node: node));
  }
}

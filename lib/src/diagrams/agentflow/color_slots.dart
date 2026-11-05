// Upstream: src/diagrams/agentflow/colorSlots.ts

import 'dart:math' as math;

// Two rules, as in Mermaid: a node takes the color of its kind, from a fixed slot, so editing the
// diagram around it never recolors it; containers count through the slots above the kinds, in the
// order they were declared, so a frame does not take the color of a node inside it.

const Map<String, int> KIND_SLOT = <String, int>{
  'tool': 0,
  'task': 1,
  'decision': 2,
  'input': 3,
  'refdoc': 4,
  'connector': 5,
  'action': 6,
};

final int KIND_COUNT = KIND_SLOT.length;

// At least one, so that a palette shorter than the kinds still gives containers a slot.
int containerSlotCount(int paletteLength) =>
    math.max<int>(1, paletteLength - KIND_COUNT);

int containerSlot(int n, int paletteLength) {
  final slot = KIND_COUNT + (n % containerSlotCount(paletteLength));
  return paletteLength > 0 ? slot % paletteLength : slot;
}

abstract interface class SlotNode {
  String get id;
  String get shape;
  bool get isGroup;
  int? get colorIndex;
  set colorIndex(int? value);
  String? get kind;
  set kind(String? value);
}

void assignColorSlots(
  List<SlotNode> nodes,
  String? Function(String id) kindOf,
  Map<String, int> containerOrder,
  int paletteLength,
) {
  var fallback = containerOrder.length;
  for (final node in nodes) {
    // A collapsed container is drawn as a node but keeps its slot, so collapsing one does not
    // recolor the containers after it.
    if (node.isGroup || node.shape == 'collapsedGroup') {
      node.colorIndex = containerSlot(
        containerOrder[node.id] ?? fallback++,
        paletteLength,
      );
      continue;
    }
    final kind = kindOf(node.id);
    if (kind != null && KIND_SLOT.containsKey(kind)) {
      node.kind = kind;
    }
  }
}

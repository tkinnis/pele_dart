// Upstream: src/diagrams/railroad/types.ts

import '../../svg/root.dart';

abstract interface class HasParts<T> {
  List<T> get nodeParts;
}

class RailroadNode implements HasParts<RailroadNode> {
  const RailroadNode._({
    required this.type,
    this.value,
    this.name,
    this.text,
    this.elements,
    this.alternatives,
    this.element,
    this.min,
    this.max,
  });

  const RailroadNode.terminal(String value)
    : this._(type: 'terminal', value: value);

  const RailroadNode.nonterminal(String name)
    : this._(type: 'nonterminal', name: name);

  const RailroadNode.special(String text) : this._(type: 'special', text: text);

  const RailroadNode.sequence(List<RailroadNode> elements)
    : this._(type: 'sequence', elements: elements);

  const RailroadNode.choice(List<RailroadNode> alternatives)
    : this._(type: 'choice', alternatives: alternatives);

  const RailroadNode.optional(RailroadNode element)
    : this._(type: 'optional', element: element);

  const RailroadNode.repetition(
    RailroadNode element,
    double min, [
    double max = double.infinity,
  ]) : this._(type: 'repetition', element: element, min: min, max: max);

  final String type;
  final String? value;
  final String? name;
  final String? text;
  final List<RailroadNode>? elements;
  final List<RailroadNode>? alternatives;
  final RailroadNode? element;
  final double? min;
  // max is Infinity when the count has no upper bound.
  final double? max;

  @override
  List<RailroadNode> get nodeParts {
    if (alternatives != null) return alternatives!;
    if (elements != null) return elements!;
    if (element != null) return <RailroadNode>[element!];
    return const <RailroadNode>[];
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RailroadNode || other.type != type) return false;
    switch (type) {
      case 'terminal':
        return other.value == value;
      case 'nonterminal':
        return other.name == name;
      case 'special':
        return other.text == text;
      case 'sequence':
        return _listEquals(other.elements, elements);
      case 'choice':
        return _listEquals(other.alternatives, alternatives);
      case 'optional':
        return other.element == element;
      case 'repetition':
        return other.element == element && other.min == min && other.max == max;
      default:
        return false;
    }
  }

  @override
  int get hashCode => Object.hash(
    type,
    value,
    name,
    text,
    elements != null ? Object.hashAll(elements!) : null,
    alternatives != null ? Object.hashAll(alternatives!) : null,
    element,
    min,
    max,
  );
}

bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class RailroadRule {
  const RailroadRule({required this.name, required this.definition});

  final String name;
  final RailroadNode definition;

  @override
  bool operator ==(Object other) =>
      other is RailroadRule &&
      other.name == name &&
      other.definition == definition;

  @override
  int get hashCode => Object.hash(name, definition);
}

// Which of Mermaid's four grammars the text was written in.
typedef Notation = String; // 'railroad' | 'ebnf' | 'abnf' | 'peg'

abstract interface class RailroadModel implements Accessible {
  String get type;
  Notation get notation;
  String? get title;
  @override
  String? get accTitle;
  @override
  String? get accDescr;
  // Every rule in source order. A name defined twice appears twice.
  List<RailroadRule> get rules;
}

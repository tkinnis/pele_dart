// Upstream: src/diagrams/venn/db.ts

import '../../errors.dart';
import 'lexer.dart';
import 'types.dart';

// Mermaid takes one pair of quotes off an id, label or style value.
String normalizeText(String text) {
  final trimmed = text.trim();
  return trimmed.length >= 2 && trimmed.startsWith('"') && trimmed.endsWith('"')
      ? trimmed.substring(1, trimmed.length - 1)
      : trimmed;
}

List<String> _normalizeIds(List<String> ids) {
  final list = ids.map(normalizeText).toList()..sort();
  return list;
}

class VennDb implements VennModel, IndentHost {
  @override
  final String type = 'venn';
  @override
  String? title;
  @override
  final List<VennSubset> subsets = <VennSubset>[];
  @override
  final List<VennText> textNodes = <VennText>[];
  @override
  final List<VennStyle> styles = <VennStyle>[];

  final Set<String> _known = <String>{};
  List<String>? _current;
  // Whether an indented `text` line belongs to the set or union before it. The lexer reads this.
  bool _indent = false;

  void setDiagramTitle(String title) {
    this.title = title;
  }

  // A set without a size gets 10, and an overlap of n sets 10 / n².
  void addSubsetData(List<String> ids, String? label, double? size) {
    final sets = _normalizeIds(ids);
    _current = sets;
    if (sets.length == 1) _known.add(sets[0]);
    subsets.add(
      VennSubset(
        sets: sets,
        size: size ?? 10 / (ids.length * ids.length),
        label: (label != null && label.isNotEmpty)
            ? normalizeText(label)
            : null,
      ),
    );
  }

  void addTextData(List<String> ids, String id, String? label) {
    textNodes.add(
      VennText(
        sets: _normalizeIds(ids),
        id: normalizeText(id),
        label: (label != null && label.isNotEmpty)
            ? normalizeText(label)
            : null,
      ),
    );
  }

  void addStyleData(List<String> ids, List<(String, String)> data) {
    final styleMap = <String, String>{};
    for (final (key, value) in data) {
      styleMap[key] = value.isNotEmpty ? normalizeText(value) : value;
    }
    styles.add(VennStyle(targets: _normalizeIds(ids), styles: styleMap));
  }

  void validateUnionIdentifiers(List<String> ids) {
    final unknown = ids
        .map(normalizeText)
        .where((id) => !_known.contains(id))
        .toList();
    if (unknown.isNotEmpty) {
      throw PeleError(
        'unknown set identifier: ${unknown.join(', ')}',
        'semantic',
        const PeleErrorInfo(type: 'venn'),
      );
    }
  }

  List<String>? getCurrentSets() {
    return _current;
  }

  @override
  bool getIndentMode() {
    return _indent;
  }

  @override
  void setIndentMode(bool enabled) {
    _indent = enabled;
  }
}

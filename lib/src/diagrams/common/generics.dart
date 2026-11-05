// Upstream: src/diagrams/common/generics.ts

int _tildes(String text) {
  var count = 0;
  for (var i = text.indexOf('~'); i != -1; i = text.indexOf('~', i + 1)) {
    count++;
  }
  return count;
}

String _pairTildes(String text) {
  final count = _tildes(text);
  if (count <= 1) return text;
  final lead = count.isOdd && text.startsWith('~');
  final chars = text.split('');
  final at = <int>[];
  for (var i = lead ? 1 : 0; i < chars.length; i++) {
    if (chars[i] == '~') at.add(i);
  }
  for (var lo = 0, hi = at.length - 1; lo < hi; lo++, hi--) {
    chars[at[lo]] = '<';
    chars[at[hi]] = '>';
  }
  return chars.join();
}

/// Turns `List~int~` into `List<int>`, with the quirks of Mermaid's parseGenericTypes around commas.
String parseGenericTypes(String input) {
  if (!input.contains('~')) return input;
  final parts = input.split(',');
  final sets = <String>[];
  for (var i = 0; i < parts.length; i++) {
    if (i > 0) sets.add(',');
    sets.add(parts[i]);
  }
  final output = <String>[];
  for (var i = 0; i < sets.length; i++) {
    var set = sets[i];
    if (set == ',' &&
        i > 0 &&
        i + 1 < sets.length &&
        _tildes(sets[i - 1]) == 1 &&
        _tildes(sets[i + 1]) == 1) {
      set = '${sets[i - 1]},${sets[i + 1]}';
      i++;
      output.removeLast();
    }
    output.add(_pairTildes(set));
  }
  return output.join();
}

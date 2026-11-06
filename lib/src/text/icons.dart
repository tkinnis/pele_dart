// Upstream: src/text/icons.ts

import '../types.dart';

const Map<String, String> _emptyFound = <String, String>{};
IconResolver? _resolver;
Map<String, String> _found = _emptyFound;

T withIcons<T>(IconResolver? icons, T Function() run) {
  if (icons == null && _resolver == null) return run();
  final outer = _resolver;
  final outerFound = _found;
  _resolver = icons;
  _found = icons != null ? <String, String>{} : _emptyFound;
  try {
    return run();
  } finally {
    _resolver = outer;
    _found = outerFound;
  }
}

String iconMarkup(String name) {
  if (_resolver == null) return '';
  var markup = _found[name];
  if (markup == null) {
    markup = _resolver!(name) ?? '';
    _found[name] = markup;
  }
  return markup;
}

// Upstream: src/text/icons.ts

import '../types.dart';

IconResolver? _resolver;
Map<String, String> _found = <String, String>{};

T withIcons<T>(IconResolver? icons, T Function() run) {
  final outer = _resolver;
  final outerFound = _found;
  _resolver = icons;
  _found = <String, String>{};
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

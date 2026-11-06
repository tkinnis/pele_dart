// Upstream: src/text/math.ts

import '../types.dart';

const Map<String, MathMarkup?> _emptyFound = <String, MathMarkup?>{};
MathResolver? _resolver;
Map<String, MathMarkup?> _found = _emptyFound;

T withMath<T>(MathResolver? math, T Function() run) {
  if (math == null && _resolver == null) return run();
  final outer = _resolver;
  final outerFound = _found;
  _resolver = math;
  _found = math != null ? <String, MathMarkup?>{} : _emptyFound;
  try {
    return run();
  } finally {
    _resolver = outer;
    _found = outerFound;
  }
}

bool mathActive() {
  return _resolver != null;
}

bool _valid(double size) {
  return size.isFinite && size > 0;
}

MathMarkup? typeset(String tex, double size) {
  if (_resolver == null) return null;
  final key = '$size\n$tex';
  if (_found.containsKey(key)) return _found[key];
  final result = _resolver!(tex, size);
  final markup =
      result != null &&
          _valid(result.width) &&
          _valid(result.height) &&
          (result.svg != null || result.html != null)
      ? result
      : null;
  _found[key] = markup;
  return markup;
}

T withoutMath<T>(T Function() run) {
  if (_resolver == null) return run();
  final outer = _resolver;
  _resolver = null;
  try {
    return run();
  } finally {
    _resolver = outer;
  }
}

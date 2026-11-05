// Upstream: src/diagrams/sequence/colors.ts

// Mermaid asks the browser whether the first word of a box title is a color. Pele has no browser,
// so it knows the color keywords and the rgb() and hsl() notations. Other functions, such as calc()
// and var(), are not recognized.
const String _KEYWORDS =
    'aliceblue antiquewhite aqua aquamarine azure beige bisque black blanchedalmond blue blueviolet brown burlywood '
    'cadetblue chartreuse chocolate coral cornflowerblue cornsilk crimson cyan darkblue darkcyan darkgoldenrod darkgray '
    'darkgreen darkgrey darkkhaki darkmagenta darkolivegreen darkorange darkorchid darkred darksalmon darkseagreen '
    'darkslateblue darkslategray darkslategrey darkturquoise darkviolet deeppink deepskyblue dimgray dimgrey dodgerblue '
    'firebrick floralwhite forestgreen fuchsia gainsboro ghostwhite gold goldenrod gray green greenyellow grey honeydew '
    'hotpink indianred indigo ivory khaki lavender lavenderblush lawngreen lemonchiffon lightblue lightcoral lightcyan '
    'lightgoldenrodyellow lightgray lightgreen lightgrey lightpink lightsalmon lightseagreen lightskyblue lightslategray '
    'lightslategrey lightsteelblue lightyellow lime limegreen linen magenta maroon mediumaquamarine mediumblue '
    'mediumorchid mediumpurple mediumseagreen mediumslateblue mediumspringgreen mediumturquoise mediumvioletred '
    'midnightblue mintcream mistyrose moccasin navajowhite navy oldlace olive olivedrab orange orangered orchid '
    'palegoldenrod palegreen paleturquoise palevioletred papayawhip peachpuff peru pink plum powderblue purple '
    'rebeccapurple red rosybrown royalblue saddlebrown salmon sandybrown seagreen seashell sienna silver skyblue '
    'slateblue slategray slategrey snow springgreen steelblue tan teal thistle tomato turquoise violet wheat white '
    'whitesmoke yellow yellowgreen transparent currentcolor inherit initial unset revert '
    'accentcolor accentcolortext activetext buttonborder buttonface buttontext canvas canvastext field fieldtext '
    'graytext highlight highlighttext linktext mark marktext selecteditem selecteditemtext visitedtext '
    'activeborder activecaption appworkspace background buttonhighlight buttonshadow captiontext inactiveborder '
    'inactivecaption inactivecaptiontext infobackground infotext menu menutext scrollbar threeddarkshadow threedface '
    'threedhighlight threedlightshadow threedshadow window windowframe windowtext';

Set<String>? _keywords;

final RegExp _reTerm = RegExp(
  r'^[+-]?(?:\d+(?:\.\d+)?|\.\d+)(?:e[+-]?\d+)?(%|deg|grad|rad|turn)?$',
  caseSensitive: false,
);

enum _K { bad, number, percent, angle, none }

_K _kind(String term) {
  if (term.toLowerCase() == 'none') return _K.none;
  final m = _reTerm.firstMatch(term);
  if (m == null) return _K.bad;
  final unit = m.group(1);
  return unit == null ? _K.number : (unit == '%' ? _K.percent : _K.angle);
}

bool _isAlpha(String term, bool modern) {
  final k = _kind(term);
  return k == _K.number || k == _K.percent || (modern && k == _K.none);
}

bool _isFunction(String color) {
  final hsl = color.startsWith('hsl');
  final open = color.indexOf('(');
  final name = open >= 0 ? color.substring(0, open) : '';
  if (name != 'rgb' && name != 'rgba' && name != 'hsl' && name != 'hsla') {
    return false;
  }
  if (color.length > 120 || color.indexOf(')') != color.length - 1) {
    return false;
  }
  final inner = color.substring(open + 1, color.length - 1).trim();
  List<String> parts;
  String? alpha;
  final legacy = inner.contains(',');
  if (legacy) {
    parts = inner.split(',').map((s) => s.trim()).toList();
    if (parts.length == 4) alpha = parts.removeLast();
  } else {
    final slash = inner.split('/');
    if (slash.length > 2) return false;
    final head = slash[0].trim();
    parts = head.isEmpty ? <String>[''] : head.split(RegExp(r'\s+'));
    if (slash.length == 2) alpha = slash[1].trim();
  }
  if (parts.length != 3 || (alpha != null && !_isAlpha(alpha, !legacy))) {
    return false;
  }
  final kinds = parts.map(_kind).toList();
  if (legacy) {
    if (hsl) {
      return (kinds[0] == _K.number || kinds[0] == _K.angle) &&
          kinds[1] == _K.percent &&
          kinds[2] == _K.percent;
    }
    return (kinds[0] == _K.number || kinds[0] == _K.percent) &&
        kinds[1] == kinds[0] &&
        kinds[2] == kinds[0];
  }
  for (var i = 0; i < 3; i++) {
    final k = kinds[i];
    final ok =
        k == _K.number ||
        k == _K.none ||
        (hsl && i == 0 ? k == _K.angle : k == _K.percent);
    if (!ok) return false;
  }
  return true;
}

bool isCssColor(String color) {
  if (color.contains('(')) return _isFunction(color);
  _keywords ??= _KEYWORDS.split(' ').toSet();
  return _keywords!.contains(color.toLowerCase());
}

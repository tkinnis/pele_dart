// Upstream: src/diagrams/c4/db.ts

import 'types.dart';

const Set<String> _elementFields = <String>{
  'label',
  'type',
  'descr',
  'techn',
  'sprite',
  'tags',
  'link',
  'bgColor',
  'fontColor',
  'borderColor',
  'shadowing',
  'shape',
  'legendText',
  'legendSprite',
};

const Set<String> _relFields = <String>{
  'label',
  'descr',
  'techn',
  'sprite',
  'tags',
  'link',
  'textColor',
  'lineColor',
};

final RegExp _reLeadingInt = RegExp(r'^[+-]?\d+');

int? _parseIntJs(String value) {
  final m = _reLeadingInt.firstMatch(value.trimLeft());
  return m != null ? int.tryParse(m.group(0)!) : null;
}

C4Attr? _at(List<C4Attr> attrs, int index) =>
    (index >= 0 && index < attrs.length) ? attrs[index] : null;

void _setElementField(C4Element el, String field, String value) {
  switch (field) {
    case 'label':
      el.label = value;
    case 'type':
      el.type = value;
    case 'descr':
      el.descr = value;
    case 'techn':
      el.techn = value;
    case 'sprite':
      el.sprite = value;
    case 'tags':
      el.tags = value;
    case 'link':
      el.link = value;
    case 'bgColor':
      el.bgColor = value;
    case 'fontColor':
      el.fontColor = value;
    case 'borderColor':
      el.borderColor = value;
    case 'shadowing':
      el.shadowing = value;
    case 'shape':
      el.shape = value;
    case 'legendText':
      el.legendText = value;
    case 'legendSprite':
      el.legendSprite = value;
  }
}

void _setRelField(C4Rel rel, String field, String value) {
  switch (field) {
    case 'label':
      rel.label = value;
    case 'descr':
      rel.descr = value;
    case 'techn':
      rel.techn = value;
    case 'sprite':
      rel.sprite = value;
    case 'tags':
      rel.tags = value;
    case 'link':
      rel.link = value;
    case 'textColor':
      rel.textColor = value;
    case 'lineColor':
      rel.lineColor = value;
  }
}

void _setField(Object target, String field, String value) {
  if (target is C4Element) {
    _setElementField(target, field, value);
  } else if (target is C4Rel) {
    _setRelField(target, field, value);
  }
}

// Mermaid assigns a named argument to whatever property it names, structural ones included.
// Here it reaches only the fields above; any other name is kept aside in `extra`.
void _named(Object target, C4Named attr) {
  final key = attr.key;
  final value = attr.value;
  if (target is C4Rel && (key == 'offsetX' || key == 'offsetY')) {
    if (key == 'offsetX') {
      target.offsetX = _parseIntJs(value);
    } else {
      target.offsetY = _parseIntJs(value);
    }
  } else if (target is C4Rel && _relFields.contains(key)) {
    _setRelField(target, key, value);
  } else if (target is C4Element && _elementFields.contains(key)) {
    _setElementField(target, key, value);
  } else if (target is C4Rel) {
    (target.extra ??= <String, String>{})[key] = value;
  } else if (target is C4Element) {
    (target.extra ??= <String, String>{})[key] = value;
  }
}

// A positional argument fills the field of its slot. A named one fills the field it names, whichever slot it is in.
void _put(Object target, String field, C4Attr? attr) {
  if (attr == null) return;
  if (attr is String) {
    _setField(target, field, attr);
  } else if (attr is C4Named) {
    _named(target, attr);
  }
}

void _text(Object target, String field, C4Attr? attr) {
  if (attr == null) {
    if (target is C4Element) {
      if (field == 'descr') target.descr ??= '';
      if (field == 'techn') target.techn ??= '';
    } else if (target is C4Rel) {
      if (field == 'descr') target.descr ??= '';
      if (field == 'techn') target.techn ??= '';
    }
  } else {
    _put(target, field, attr);
  }
}

void _label(Object target, C4Attr? attr) {
  if (target is C4Element) {
    target.labelAttr = null;
    if (attr is C4Named) {
      target.label = '';
      target.labelAttr = attr;
      _named(target, attr);
    } else {
      target.label = (attr as String?) ?? '';
    }
  } else if (target is C4Rel) {
    target.labelAttr = null;
    if (attr is C4Named) {
      target.label = '';
      target.labelAttr = attr;
      _named(target, attr);
    } else {
      target.label = (attr as String?) ?? '';
    }
  }
}

class C4Db implements C4Model {
  @override
  final String type = 'c4';
  @override
  String? c4Type;
  @override
  String? title;
  @override
  String? accTitle;
  @override
  String? accDescr;
  @override
  final List<C4Shape> shapes = <C4Shape>[];
  @override
  final List<C4Boundary> boundaries = <C4Boundary>[
    C4Boundary(alias: 'global', label: 'global', type: 'global', parent: null),
  ];
  @override
  final List<C4Rel> rels = <C4Rel>[];
  @override
  int shapeInRow = 4;
  @override
  int boundaryInRow = 2;

  final Map<String, C4Shape> _shapeIndex = <String, C4Shape>{};
  // The top-level boundary is not listed, so a boundary a diagram names `global` is its own box.
  // In Mermaid it replaces the top level and nothing is drawn.
  final Map<String, C4Boundary> _boundaryIndex = <String, C4Boundary>{};
  final Map<String, Map<String, C4Rel>> _relIndex =
      <String, Map<String, C4Rel>>{};
  late C4Boundary _current = boundaries[0];
  final List<C4Boundary> _stack = <C4Boundary>[];

  void setC4Type(String type) {
    c4Type = type;
  }

  void setTitle(String value) {
    title = value;
  }

  void setAccDescription(String descr) {
    accDescr = descr.replaceAll(RegExp(r'\n\s+'), '\n');
  }

  E _element<E extends C4Element>(
    List<E> list,
    Map<String, E> index,
    C4Attr? alias,
    C4Attr? title,
    E Function() create,
  ) {
    var el = alias is String ? index[alias] : null;
    if (el == null) {
      el = create();
      list.add(el);
      if (alias is String) {
        el.alias = alias;
        index[alias] = el;
      } else if (alias is C4Named) {
        el.aliasAttr = alias;
        _named(el, alias);
      }
    }
    _label(el, title);
    return el;
  }

  // alias, label, ?descr, ?sprite, ?tags, $link
  void addPersonOrSystem(String kind, List<C4Attr> attrs) {
    final shape = _element<C4Shape>(
      shapes,
      _shapeIndex,
      _at(attrs, 0),
      _at(attrs, 1),
      () => C4Shape(alias: '', label: '', kind: '', parent: null),
    );
    _text(shape, 'descr', _at(attrs, 2));
    _finishShape(shape, kind, attrs, 3);
  }

  // alias, label, ?techn, ?descr, ?sprite, ?tags, $link
  void addContainer(String kind, List<C4Attr> attrs) {
    final shape = _element<C4Shape>(
      shapes,
      _shapeIndex,
      _at(attrs, 0),
      _at(attrs, 1),
      () => C4Shape(alias: '', label: '', kind: '', parent: null),
    );
    _text(shape, 'techn', _at(attrs, 2));
    _text(shape, 'descr', _at(attrs, 3));
    _finishShape(shape, kind, attrs, 4);
  }

  void addComponent(String kind, List<C4Attr> attrs) {
    addContainer(kind, attrs);
  }

  void _finishShape(C4Shape shape, String kind, List<C4Attr> attrs, int at) {
    _put(shape, 'sprite', _at(attrs, at));
    _put(shape, 'tags', _at(attrs, at + 1));
    _put(shape, 'link', _at(attrs, at + 2));
    shape.kind = kind;
    shape.parent = _current;
  }

  C4Boundary _boundary(List<C4Attr> attrs, String fallback) {
    final boundary = _element<C4Boundary>(
      boundaries,
      _boundaryIndex,
      _at(attrs, 0),
      _at(attrs, 1),
      () => C4Boundary(alias: '', label: '', parent: null),
    );
    final third = _at(attrs, 2);
    if (third == null) {
      boundary.type = fallback;
    } else {
      _put(boundary, 'type', third);
    }
    return boundary;
  }

  void _open(C4Boundary boundary) {
    boundary.parent = _current;
    _stack.add(_current);
    _current = boundary;
  }

  // alias, label, ?type, ?tags, $link
  void addPersonOrSystemBoundary(
    List<C4Attr> attrs, [
    String fallback = 'system',
  ]) {
    final boundary = _boundary(attrs, fallback);
    _put(boundary, 'tags', _at(attrs, 3));
    _put(boundary, 'link', _at(attrs, 4));
    _open(boundary);
  }

  void addContainerBoundary(List<C4Attr> attrs) {
    addPersonOrSystemBoundary(attrs, 'container');
  }

  // alias, label, ?type, ?descr, ?sprite, ?tags, $link
  void addDeploymentNode(String nodeType, List<C4Attr> attrs) {
    final boundary = _boundary(attrs, 'node');
    _text(boundary, 'descr', _at(attrs, 3));
    // Mermaid drops whatever is in the sprite slot, a named argument included.
    _put(boundary, 'sprite', _at(attrs, 4));
    _put(boundary, 'tags', _at(attrs, 5));
    _put(boundary, 'link', _at(attrs, 6));
    boundary.nodeType = nodeType;
    _open(boundary);
  }

  void popBoundaryParseStack() {
    _current = _stack.isNotEmpty ? _stack.removeLast() : boundaries[0];
  }

  // from, to, label, ?techn, ?descr, ?sprite, ?tags, $link
  void addRel(String type, List<C4Attr> attrs) {
    final from = _at(attrs, 0);
    final to = _at(attrs, 1);
    final third = _at(attrs, 2);
    if (from == null || to == null || third == null) return;
    C4Rel? rel;
    if (from is String && to is String) {
      rel = _relIndex[from]?[to];
    }
    if (rel == null) {
      rel = C4Rel(type: type, from: '', to: '', label: '');
      rels.add(rel);
      if (from is String && to is String) {
        final targets = _relIndex.putIfAbsent(from, () => <String, C4Rel>{});
        targets[to] = rel;
      }
      if (from is String) {
        rel.from = from;
      } else if (from is C4Named) {
        rel.fromAttr = from;
      }
      if (to is String) {
        rel.to = to;
      } else if (to is C4Named) {
        rel.toAttr = to;
      }
    }
    rel.type = type;
    _label(rel, third);
    _text(rel, 'techn', _at(attrs, 3));
    _text(rel, 'descr', _at(attrs, 4));
    _put(rel, 'sprite', _at(attrs, 5));
    _put(rel, 'tags', _at(attrs, 6));
    _put(rel, 'link', _at(attrs, 7));
  }

  C4Element? getC4Shape(String alias) {
    return _shapeIndex[alias] ?? _boundaryIndex[alias];
  }

  // elementName, ?bgColor, ?fontColor, ?borderColor, ?shadowing, ?shape, ?sprite, ?techn, ?legendText, ?legendSprite
  void updateElStyle(String type, List<C4Attr> attrs) {
    final first = _at(attrs, 0);
    final el = first is String ? getC4Shape(first) : null;
    if (el == null) return;
    _put(el, 'bgColor', _at(attrs, 1));
    _put(el, 'fontColor', _at(attrs, 2));
    _put(el, 'borderColor', _at(attrs, 3));
    _put(el, 'shadowing', _at(attrs, 4));
    _put(el, 'shape', _at(attrs, 5));
    _put(el, 'sprite', _at(attrs, 6));
    _put(el, 'techn', _at(attrs, 7));
    _put(el, 'legendText', _at(attrs, 8));
    _put(el, 'legendSprite', _at(attrs, 9));
  }

  // from, to, ?textColor, ?lineColor, ?offsetX, ?offsetY
  void updateRelStyle(String type, List<C4Attr> attrs) {
    final from = _at(attrs, 0);
    final to = _at(attrs, 1);
    if (from is! String || to is! String) return;
    final rel = _relIndex[from]?[to];
    if (rel == null) return;
    _put(rel, 'textColor', _at(attrs, 2));
    _put(rel, 'lineColor', _at(attrs, 3));
    final x = _at(attrs, 4);
    final y = _at(attrs, 5);
    if (x is String) {
      rel.offsetX = _parseIntJs(x);
    } else if (x is C4Named) {
      _named(rel, x);
    }
    if (y is String) {
      rel.offsetY = _parseIntJs(y);
    } else if (y is C4Named) {
      _named(rel, y);
    }
  }

  // ?c4ShapeInRow, ?c4BoundaryInRow. As in Mermaid, the slot decides which one a value sets, not its name.
  void updateLayoutConfig(String type, List<C4Attr> attrs) {
    int? count(C4Attr? attr) {
      if (attr == null) return null;
      return _parseIntJs(attr is String ? attr : (attr as C4Named).value);
    }

    final shapes = count(_at(attrs, 0));
    final boundaries = count(_at(attrs, 1));
    if (shapes != null && shapes >= 1) shapeInRow = shapes;
    if (boundaries != null && boundaries >= 1) boundaryInRow = boundaries;
  }
}

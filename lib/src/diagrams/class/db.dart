// Upstream: src/diagrams/class/db.ts

import '../../text/entities.dart';
import '../../util/math_js.dart';
import '../../util/url.dart';
import 'members.dart';
import 'types.dart';

const ({int LINE, int DOTTED_LINE}) LINE_TYPE = (LINE: 0, DOTTED_LINE: 1);

const ({
  int AGGREGATION,
  int EXTENSION,
  int COMPOSITION,
  int DEPENDENCY,
  int LOLLIPOP,
})
RELATION_TYPE = (
  AGGREGATION: 0,
  EXTENSION: 1,
  COMPOSITION: 2,
  DEPENDENCY: 3,
  LOLLIPOP: 4,
);

// Mermaid looks up ids that start with a digit under this prefix, so they never match a class.
const String _DOM_ID_PREFIX = 'classId-';

({String className, String type}) _splitName(String id) {
  final at = id.indexOf('~');
  if (at <= 0) return (className: id, type: '');
  final end = id.indexOf('~', at + 1);
  return (
    className: id.substring(0, at),
    type: id.substring(at + 1, end == -1 ? id.length : end),
  );
}

String _lookupId(String id) {
  final c = charCodeAt(id, 0);
  return _splitName(c >= 48 && c <= 57 ? '$_DOM_ID_PREFIX$id' : id).className;
}

final RegExp _leadSpacesRe = RegExp(r'^\s+');
final RegExp _newlineSpacesRe = RegExp(r'\n\s+');

class ClassDb implements ClassModel {
  @override
  final String type = 'class';
  @override
  String direction = 'TB';
  @override
  final Map<String, ClassNode> classes = <String, ClassNode>{};
  @override
  final List<ClassRelation> relations = <ClassRelation>[];
  @override
  final Map<String, ClassNote> notes = <String, ClassNote>{};
  @override
  final Map<String, NamespaceNode> namespaces = <String, NamespaceNode>{};
  @override
  final List<ClassInterface> interfaces = <ClassInterface>[];
  @override
  final Map<String, StyleClass> styleClasses = <String, StyleClass>{};
  @override
  String? title;
  @override
  String? accTitle;
  @override
  String? accDescr;

  final List<String> _namespaceStack = <String>[];
  final Map<String, Set<ClassNode>> _withCssClass = <String, Set<ClassNode>>{};

  void addClass(String id) {
    final (:className, :type) = _splitName(id);
    if (classes.containsKey(className)) return;
    final node = ClassNode(
      id: className,
      type: type,
      label: className,
      cssClasses: 'default',
    );
    classes[className] = node;
    _tag(node, 'default');
  }

  void _tag(ClassNode node, String cssClass) {
    final tagged = _withCssClass[cssClass];
    if (tagged != null) {
      tagged.add(node);
    } else {
      _withCssClass[cssClass] = <ClassNode>{node};
    }
  }

  // Returns the class for a name that may carry a generic type, creating it if needed.
  // Mermaid throws a TypeError where this creates, as for an annotation on a class not yet declared.
  ClassNode _ensure(String id) {
    addClass(id);
    return classes[_splitName(id).className]!;
  }

  void setClassLabel(String id, String label) {
    _ensure(id).label = label;
  }

  void addRelation(ClassRelation relation) {
    final type1 = relation.relation.type1;
    final type2 = relation.relation.type2;
    if (type1 == RELATION_TYPE.LOLLIPOP && type2 == 'none') {
      addClass(relation.id2);
      relation.id1 = _addInterface(relation.id1, relation.id2);
    } else if (type2 == RELATION_TYPE.LOLLIPOP && type1 == 'none') {
      addClass(relation.id1);
      relation.id2 = _addInterface(relation.id2, relation.id1);
    } else {
      addClass(relation.id1);
      addClass(relation.id2);
    }
    relation.id1 = _splitName(relation.id1).className;
    relation.id2 = _splitName(relation.id2).className;
    relation.relationTitle1 = relation.relationTitle1.trim();
    relation.relationTitle2 = relation.relationTitle2.trim();
    relations.add(relation);
  }

  String _addInterface(String label, String classId) {
    final id = 'interface${interfaces.length}';
    interfaces.add(ClassInterface(id: id, label: label, classId: classId));
    return id;
  }

  void addAnnotation(String className, String annotation) {
    _ensure(className).annotations.add(annotation);
  }

  void addMember(String className, String member) {
    final node = _ensure(className);
    final text = member.trim();
    if (text.startsWith('<<') && text.endsWith('>>')) {
      node.annotations.add(text.substring(2, text.length - 2));
    } else if (text.indexOf(')') > 0) {
      final parsed = ClassMember(text, 'method');
      (parsed.memberType == 'method' ? node.methods : node.members).add(parsed);
    } else if (text.isNotEmpty) {
      node.members.add(ClassMember(text, 'attribute'));
    }
  }

  void addMembers(String className, List<String> members) {
    for (final member in members.reversed) {
      addMember(className, member);
    }
  }

  String addNote(String text, [String? className]) {
    final index = notes.length;
    final id = 'note$index';
    notes[id] = ClassNote(
      id: id,
      className: className,
      text: text,
      index: index,
    );
    return id;
  }

  String cleanupLabel(String label) {
    return (label.startsWith(':') ? label.substring(1) : label).trim();
  }

  void setCssClass(String ids, String className) {
    for (final id in ids.split(',')) {
      final node = classes[_lookupId(id)];
      if (node == null) continue;
      node.cssClasses += ' $className';
      for (final word in className.split(' ')) {
        _tag(node, word);
      }
    }
  }

  void defineClass(List<String> ids, List<String> style) {
    for (final id in ids) {
      var styleClass = styleClasses[id];
      if (styleClass == null) {
        styleClass = StyleClass(id: id);
        styleClasses[id] = styleClass;
      }
      for (final s in style) {
        if (s.contains('color')) {
          styleClass.textStyles.add(s.replaceFirst('fill', 'bgFill'));
        }
        styleClass.styles.add(s);
      }
      // Mermaid tests `cssClasses.includes(id)`, which also matches part of a longer name
      // (a classDef named `def` styles every class, through `default`). Whole names are compared here.
      final tagged = _withCssClass[id];
      if (tagged == null) continue;
      final parts = style.expand((s) => s.split(',')).toList();
      for (final node in tagged) {
        for (final part in parts) {
          node.styles.add(part);
        }
      }
    }
  }

  void setTooltip(String ids, [String? tooltip]) {
    if (tooltip == null) return;
    for (final id in ids.split(',')) {
      final node = classes[_splitName(id).className];
      if (node != null) node.tooltip = tooltip;
    }
  }

  void setLink(String ids, String link, [String? target]) {
    // Entity codes are resolved first, so that what is checked is what a browser would follow.
    final url = decodeEntities(link).trim();
    for (final id in ids.split(',')) {
      final node = classes[_lookupId(id)];
      if (node != null) {
        node.link = url.isNotEmpty ? sanitizeUrl(url) : null;
        node.linkTarget = target ?? '_blank';
      }
    }
    setCssClass(ids, 'clickable');
  }

  // Callbacks are never executed; the class is only marked clickable, as in Mermaid's strict mode.
  void setClickEvent(String ids, [String? functionName, String? functionArgs]) {
    for (final id in ids.split(',')) {
      final node = classes[_splitName(id).className];
      if (node != null) node.haveCallback = true;
    }
    setCssClass(ids, 'clickable');
  }

  void setDirection(String dir) {
    direction = dir;
  }

  void setAccTitle(String text) {
    accTitle = text.replaceFirst(_leadSpacesRe, '');
  }

  void setAccDescription(String text) {
    accDescr = text.replaceAll(_newlineSpacesRe, '\n');
  }

  String addNamespace(String id, [String? label]) {
    final prefix = _namespaceStack.isNotEmpty ? _namespaceStack.last : null;
    final qualified = (prefix != null && prefix.isNotEmpty)
        ? '$prefix.$id'
        : id;
    _namespaceStack.add(qualified);

    final existing = namespaces[qualified];
    if (existing != null) {
      existing.explicit = true;
      if (label != null && label.isNotEmpty) existing.label = label;
      return qualified;
    }

    // The enclosing namespace and its ancestors exist already, so only the parts of `id` are walked.
    var parentId = (prefix != null && prefix.isNotEmpty) ? prefix : null;
    var from = (prefix != null && prefix.isNotEmpty) ? prefix.length + 1 : 0;
    while (true) {
      final dot = qualified.indexOf('.', from);
      final leaf = dot == -1;
      final current = leaf ? qualified : qualified.substring(0, dot);
      var node = namespaces[current];
      if (node == null) {
        final part = qualified.substring(from, leaf ? qualified.length : dot);
        node = NamespaceNode(
          id: current,
          label: (leaf && label != null && label.isNotEmpty) ? label : part,
          parent: parentId,
          explicit: leaf,
        );
        namespaces[current] = node;
      } else if (leaf) {
        node.explicit = true;
      }
      final parent = parentId != null ? namespaces[parentId] : null;
      if (parent != null) {
        if (!parent.children.containsKey(current)) {
          parent.children[current] = node;
        }
        node.parent ??= parentId;
      }
      if (leaf) return qualified;
      parentId = current;
      from = dot + 1;
    }
  }

  void popNamespace() {
    if (_namespaceStack.isNotEmpty) {
      _namespaceStack.removeLast();
    }
  }

  void addClassesToNamespace(
    String id,
    List<String> classNames,
    List<String> noteNames,
  ) {
    final namespace = namespaces[id];
    if (namespace == null) return;
    for (final name in classNames) {
      final className = _splitName(name).className;
      final node = classes[className];
      if (node == null) continue;
      node.parent = id;
      namespace.classes[className] = node;
    }
    for (final name in noteNames) {
      final note = notes[name];
      if (note == null) continue;
      note.parent = id;
      namespace.notes[name] = note;
    }
  }

  void setCssStyle(String id, List<String> styles) {
    final node = classes[id];
    if (node == null) return;
    for (final s in styles) {
      for (final part in s.split(',')) {
        node.styles.add(part);
      }
    }
  }
}

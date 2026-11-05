// Upstream: src/diagrams/usecase/db.ts

import '../../errors.dart';
import 'lexer.dart';
import 'types.dart';

abstract interface class _HasId {
  String get id;
}

class DraftLabel {
  const DraftLabel({
    required this.text,
    required this.type,
    required this.span,
  });

  final String text;
  final LabelType type;
  final Span span;
}

// keySpan is also where an error about the property points.
class DraftProperty extends MetadataOccurrence {
  DraftProperty({
    required super.key,
    required this.value,
    required super.span,
    required super.keySpan,
    required super.valueSpan,
  });

  // String or bool.
  final Object value;
}

// What every mention of an id carries: where it is, and whether the id was made from a label.
abstract interface class Named implements _HasId {
  @override
  String get id;
  DraftLabel get label;
  Span get span;
  bool get generated;
}

class DraftElement implements Named {
  DraftElement({
    required this.id,
    required this.kind,
    required this.label,
    required this.span,
    required this.generated,
    this.parent,
    this.shape,
    this.metadata,
    this.stereotype,
    required this.classes,
  });

  @override
  final String id;
  final String kind;
  @override
  final DraftLabel label;
  @override
  final Span span;
  @override
  final bool generated;
  final DraftBoundary? parent;
  final UseCaseShape? shape;
  final List<DraftProperty>? metadata;
  final String? stereotype;
  final List<String> classes;
}

class DraftBoundary implements Named {
  DraftBoundary({
    required this.id,
    required this.label,
    required this.span,
    required this.generated,
    required this.classes,
  });

  @override
  final String id;
  @override
  final DraftLabel label;
  @override
  final Span span;
  @override
  final bool generated;
  final List<String> classes;
}

class DraftJson implements _HasId {
  DraftJson({
    required this.id,
    required this.value,
    required this.propertyOrder,
    required this.span,
    required this.classes,
  });

  @override
  final String id;
  Map<String, Object?> value;
  Map<String, List<String>> propertyOrder;
  final Span span;
  final List<String> classes;
}

class DraftEndpoint implements Named {
  DraftEndpoint({
    required this.id,
    required this.label,
    required this.span,
    required this.generated,
    required this.declares,
    required this.classed,
  });

  @override
  final String id;
  @override
  final DraftLabel label;
  @override
  final Span span;
  @override
  final bool generated;
  // Whether this mention declares the element, and whether it carries a `:::` suffix.
  final bool declares;
  final bool classed;
}

class DraftRelationship {
  DraftRelationship({
    required this.source,
    required this.target,
    required this.span,
    this.id,
    this.idSpan,
    required this.type,
    required this.arrowType,
    this.label,
    required this.minlen,
  });

  final DraftEndpoint source;
  final DraftEndpoint target;
  final Span span;
  final String? id;
  final Span? idSpan;
  final RelationshipType type;
  final int arrowType;
  final DraftLabel? label;
  final int minlen;
}

class DraftNote {
  const DraftNote({
    required this.target,
    required this.span,
    required this.label,
  });

  final String target;
  final Span span;
  final DraftLabel label;
}

class DraftMetadata {
  const DraftMetadata({
    required this.target,
    required this.span,
    required this.properties,
    required this.statement,
  });

  final String target;
  final Span span;
  final List<DraftProperty> properties;
  final GraphStatement statement;
}

class DraftClassTarget {
  const DraftClassTarget({required this.id, required this.span});

  final String id;
  final Span span;
}

class DraftClassAssign {
  const DraftClassAssign({required this.targets, required this.classes});

  final List<DraftClassTarget> targets;
  final List<String> classes;
}

class DraftStyleAssign {
  const DraftStyleAssign({
    required this.target,
    required this.span,
    required this.styles,
  });

  final String target;
  final Span span;
  final List<String> styles;
}

class DraftClassDef {
  const DraftClassDef({required this.ids, required this.styles});

  final List<String> ids;
  final List<String> styles;
}

// Everything the parser read, in source order, before any of it is resolved.
class Drafts {
  Drafts({
    required this.elements,
    required this.boundaries,
    required this.jsons,
    required this.relationships,
    required this.notes,
    required this.metadata,
    required this.classes,
    required this.styles,
    required this.classDefs,
    this.direction,
    required this.accTitle,
    required this.accDescription,
  });

  final List<DraftElement> elements;
  final List<DraftBoundary> boundaries;
  final List<DraftJson> jsons;
  final List<DraftRelationship> relationships;
  final List<DraftNote> notes;
  final List<DraftMetadata> metadata;
  final List<DraftClassAssign> classes;
  final List<DraftStyleAssign> styles;
  final List<DraftClassDef> classDefs;
  Direction? direction;
  String accTitle;
  String accDescription;
}

Drafts emptyDrafts() {
  return Drafts(
    elements: <DraftElement>[],
    boundaries: <DraftBoundary>[],
    jsons: <DraftJson>[],
    relationships: <DraftRelationship>[],
    notes: <DraftNote>[],
    metadata: <DraftMetadata>[],
    classes: <DraftClassAssign>[],
    styles: <DraftStyleAssign>[],
    classDefs: <DraftClassDef>[],
    direction: null,
    accTitle: '',
    accDescription: '',
  );
}

class _Origin {
  const _Origin({
    required this.kind,
    required this.span,
    required this.generated,
    this.label,
  });

  final SymbolKind kind;
  final Span span;
  final bool generated;
  // The label a generated id was derived from.
  final String? label;
}

class _ElementState implements Named {
  _ElementState({
    required this.kind,
    required this.id,
    required this.label,
    required this.span,
    required this.generated,
    required this.classes,
    this.parent,
    this.shape,
    this.stereotype,
    this.stereotypeSpan,
  });

  final String kind;
  @override
  final String id;
  @override
  final DraftLabel label;
  @override
  final Span span;
  @override
  final bool generated;
  DraftBoundary? parent;
  UseCaseShape? shape;
  String? stereotype;
  Span? stereotypeSpan;
  final List<String> classes;
  ActorType? actorType;
  String? icon;
  bool? business;
}

class _BoundaryState implements Named {
  _BoundaryState({
    required this.id,
    required this.label,
    required this.span,
    required this.generated,
    required this.classes,
    required this.members,
  });

  @override
  final String id;
  @override
  final DraftLabel label;
  @override
  final Span span;
  @override
  final bool generated;
  final List<String> classes;
  BoundaryType? type;
  final List<String> members;
}

void _pushUnique(List<String> target, List<String> values) {
  if (values.isEmpty) return;
  final seen = target.toSet();
  for (final value in values) {
    if (seen.contains(value)) continue;
    seen.add(value);
    target.add(value);
  }
}

// Which kind of element the keys of a metadata block could only belong to, for the error message.
String? _inferKind(List<DraftProperty> properties) {
  final possible = <String>{'actor', 'usecase', 'boundary', 'edge'};
  for (final property in properties) {
    final key = property.key;
    final value = property.value;
    if (key == 'icon') {
      possible
        ..clear()
        ..add('actor');
    } else if (key == 'animate' || key == 'animation') {
      possible
        ..clear()
        ..add('edge');
    } else if (key == 'type') {
      possible.clear();
      if (value == 'rect' || value == 'package') {
        possible.add('boundary');
      } else if (value == 'normal' || value == 'hollow' || value == 'awesome') {
        possible.add('actor');
      }
    } else if (key == 'business') {
      possible
        ..remove('boundary')
        ..remove('edge');
    } else {
      return null;
    }
  }
  return possible.length == 1 ? possible.first : null;
}

final RegExp _reNewlineIndent = RegExp(r'\n\s+');

// Resolves what the parser read into a model, once the whole diagram is read: which ids are
// actors, use cases, boundaries, JSON nodes or edges, in what order they appear, and whether the
// statements about them agree. Ports Mermaid's UsecaseModelBuilder, with its messages.
UsecaseModel resolveUsecase(
  String src,
  Drafts drafts,
  Span headerSpan,
  List<GraphStatement> statements,
  String? title,
) {
  final model = emptyModel();
  final actors = model.actors;
  final useCases = model.useCases;
  final systemBoundaries = model.systemBoundaries;
  final symbols = <String, _Origin>{};
  final elements = <String, _ElementState>{};
  final boundaries = <String, _BoundaryState>{};
  final edges = <String, Relationship>{};
  // The offset at which each id is first mentioned, which decides the order of the model.
  final first = <String, int>{};

  String at(Span span) => locationText(src, span[0], span[1]);

  PeleError error(String message, Span span) {
    final (line, column) = lineColumn(src, span[0]);
    return PeleError(
      message,
      'semantic',
      PeleErrorInfo(type: 'usecase', line: line, column: column),
    );
  }

  Never fail(String message, Span span) {
    throw error('$message at ${at(span)}', span);
  }

  Never conflict(
    String message,
    Span current,
    Span previous, [
    String? currentLabel,
    String? previousLabel,
  ]) {
    String suffix(String? label) => label == null ? '' : ' (label "$label")';
    throw error(
      '$message at ${at(current)}${suffix(currentLabel)}; previous declaration at ${at(previous)}${suffix(previousLabel)}',
      current,
    );
  }

  Never invalid(String id, String kind, DraftProperty property) => fail(
    "Metadata property '${property.key}' is invalid for $kind '$id'",
    property.keySpan,
  );

  void mention(String id, int offset) {
    final previous = first[id];
    if (previous == null || offset < previous) first[id] = offset;
  }

  List<V> inOrder<V extends _HasId>(Iterable<V> values) {
    final indexed = values.indexed.toList();
    indexed.sort((a, b) {
      final cmp = (first[a.$2.id] ?? 0) - (first[b.$2.id] ?? 0);
      return cmp != 0 ? cmp : a.$1 - b.$1;
    });
    return <V>[for (final item in indexed) item.$2];
  }

  void register(Named named, SymbolKind kind) {
    symbols[named.id] = _Origin(
      kind: kind,
      span: named.span,
      generated: named.generated,
      label: named.label.text,
    );
  }

  // An id means one thing in the whole diagram, and an id made from a label may be declared once.
  void claim(Named draft, SymbolKind kind) {
    final origin = symbols[draft.id];
    if (origin == null) return;
    final label = draft.generated ? draft.label.text : null;
    final originLabel = origin.generated ? origin.label : null;
    if (origin.kind != kind) {
      conflict(
        "ID '${draft.id}' is declared as both ${origin.kind} and $kind",
        draft.span,
        origin.span,
        label,
        originLabel,
      );
    }
    if (origin.generated || draft.generated) {
      conflict(
        "Generated ID '${draft.id}' collides with another declaration",
        draft.span,
        origin.span,
        label,
        originLabel,
      );
    }
  }

  void unique(String id, SymbolKind kind, Span span) {
    final previous = symbols[id];
    if (previous != null) {
      conflict(
        "ID '$id' is declared more than once (${previous.kind} and $kind)",
        span,
        previous.span,
        null,
        previous.generated ? previous.label : null,
      );
    }
    symbols[id] = _Origin(kind: kind, span: span, generated: false);
  }

  // A metadata statement replaces what a declaration said; two declarations have to agree.
  void actorProperty(
    _ElementState state,
    DraftProperty property,
    bool replace,
  ) {
    final key = property.key;
    final value = property.value;
    void clash(Object? previous) {
      if (!replace && previous != null && previous != value) {
        conflict(
          "Actor '${state.id}' has conflicting $key metadata",
          property.keySpan,
          state.span,
        );
      }
    }

    if (key == 'type' &&
        (value == 'normal' || value == 'hollow' || value == 'awesome')) {
      clash(state.actorType);
      state.actorType = value as String;
    } else if (key == 'icon' && value is String) {
      clash(state.icon);
      state.icon = value;
    } else if (key == 'business' && value is bool) {
      clash(state.business);
      state.business = value;
    } else {
      invalid(state.id, 'actor', property);
    }
  }

  void elementMetadata(
    _ElementState state,
    List<DraftProperty>? properties,
    bool replace,
  ) {
    for (final property in properties ?? const <DraftProperty>[]) {
      if (state.kind == 'actor') {
        actorProperty(state, property, replace);
      } else if (property.key == 'business' && property.value is bool) {
        if (!replace &&
            state.business != null &&
            state.business != property.value) {
          conflict(
            "Use case '${state.id}' has conflicting business metadata",
            property.keySpan,
            state.span,
          );
        }
        state.business = property.value as bool;
      } else {
        invalid(state.id, 'usecase', property);
      }
    }
  }

  void publish(_ElementState state) {
    final hasIcon = state.icon != null && state.icon!.isNotEmpty;
    final hasStereotype =
        state.stereotype != null && state.stereotype!.isNotEmpty;
    final hasParent = state.parent != null && state.parent!.id.isNotEmpty;
    if (state.kind == 'actor') {
      useCases.remove(state.id);
      final actor = Actor(
        id: state.id,
        label: state.label.text,
        labelType: state.label.type,
        business: state.business ?? false,
        classes: List<String>.of(state.classes),
        type: hasIcon ? 'icon' : (state.actorType ?? 'normal'),
        styles: actors[state.id]?.styles ?? <String>[],
        icon: hasIcon ? state.icon : null,
        stereotype: hasStereotype ? state.stereotype : null,
        parentId: hasParent ? state.parent!.id : null,
      );
      actors[state.id] = actor;
    } else {
      actors.remove(state.id);
      final element = UseCase(
        id: state.id,
        label: state.label.text,
        labelType: state.label.type,
        business: state.business ?? false,
        classes: List<String>.of(state.classes),
        shape: state.shape ?? 'ellipse',
        styles: useCases[state.id]?.styles ?? <String>[],
        stereotype: hasStereotype ? state.stereotype : null,
        parentId: hasParent ? state.parent!.id : null,
      );
      useCases[state.id] = element;
    }
  }

  void declareElement(DraftElement draft) {
    claim(draft, draft.kind);
    final parent = (draft.parent != null && draft.parent!.id.isNotEmpty)
        ? draft.parent
        : null;
    final hasDraftStereotype =
        draft.stereotype != null && draft.stereotype!.isNotEmpty;
    final existing = elements[draft.id];
    if (existing == null) {
      final state = _ElementState(
        kind: draft.kind,
        id: draft.id,
        label: draft.label,
        span: draft.span,
        generated: draft.generated,
        classes: List<String>.of(draft.classes),
        parent: parent,
        shape: draft.shape,
        stereotype: draft.stereotype,
        stereotypeSpan: hasDraftStereotype ? draft.span : null,
      );
      elementMetadata(state, draft.metadata, false);
      elements[draft.id] = state;
      register(draft, draft.kind);
      return;
    }
    if (existing.label.text != draft.label.text ||
        existing.label.type != draft.label.type) {
      conflict(
        "ID '${draft.id}' has conflicting labels",
        draft.span,
        existing.span,
      );
    }
    if (draft.shape != null &&
        existing.shape != null &&
        draft.shape != existing.shape) {
      conflict(
        "Use case '${draft.id}' has conflicting shapes",
        draft.span,
        existing.span,
      );
    }
    // A boundary whose title makes an empty id is no parent, but it still takes the place of one.
    if (parent != null &&
        existing.parent != null &&
        existing.parent!.id.isNotEmpty &&
        parent.id != existing.parent!.id) {
      conflict(
        "Element '${draft.id}' belongs to more than one system boundary",
        parent.span,
        existing.parent!.span,
      );
    }
    if (hasDraftStereotype &&
        existing.stereotype != null &&
        existing.stereotype!.isNotEmpty &&
        draft.stereotype != existing.stereotype) {
      conflict(
        "Element '${draft.id}' has conflicting stereotypes",
        draft.span,
        existing.stereotypeSpan ?? existing.span,
      );
    }
    existing.shape ??= draft.shape;
    existing.parent ??= draft.parent;
    if (existing.stereotype == null || existing.stereotype!.isEmpty) {
      existing.stereotype = draft.stereotype;
    }
    existing.stereotypeSpan ??= hasDraftStereotype ? draft.span : null;
    _pushUnique(existing.classes, draft.classes);
    elementMetadata(existing, draft.metadata, false);
  }

  void declareBoundary(DraftBoundary draft) {
    claim(draft, 'boundary');
    final existing = boundaries[draft.id];
    if (existing != null) {
      if (existing.label.text != draft.label.text ||
          existing.label.type != draft.label.type) {
        conflict(
          "Boundary '${draft.id}' has conflicting titles",
          draft.span,
          existing.span,
        );
      }
      _pushUnique(existing.classes, draft.classes);
      return;
    }
    boundaries[draft.id] = _BoundaryState(
      id: draft.id,
      label: draft.label,
      span: draft.span,
      generated: draft.generated,
      classes: List<String>.of(draft.classes),
      members: <String>[],
    );
    register(draft, 'boundary');
  }

  // An end of a relationship that nothing declares becomes a use case.
  SymbolKind endpoint(DraftEndpoint end) {
    if (end.classed && !end.declares) {
      fail(
        "Relationship endpoint '${end.id}' uses ::: without declaring the node",
        end.span,
      );
    }
    final origin = symbols[end.id];
    if (origin != null) return origin.kind;
    elements[end.id] = _ElementState(
      id: end.id,
      label: end.label,
      span: end.span,
      generated: end.generated,
      kind: 'usecase',
      shape: 'ellipse',
      classes: <String>[],
    );
    register(end, 'usecase');
    mention(end.id, end.span[0]);
    return 'usecase';
  }

  Stylable stylable(String id, Span span) {
    final kind = symbols[id]?.kind;
    final Stylable? target = kind == 'actor'
        ? actors[id]
        : kind == 'usecase'
        ? useCases[id]
        : kind == 'boundary'
        ? systemBoundaries[id]
        : kind == 'json'
        ? model.jsonNodes[id]
        : edges[id];
    return target ??
        fail("Class/style target '$id' is unresolved or anonymous", span);
  }

  final declarations = <({int offset, int order, void Function() run})>[];
  for (final rel in drafts.relationships) {
    mention(rel.source.id, rel.source.span[0]);
    mention(rel.target.id, rel.target.span[0]);
  }
  for (final draft in drafts.elements) {
    mention(draft.id, draft.span[0]);
    declarations.add((
      offset: draft.span[0],
      order: declarations.length,
      run: () => declareElement(draft),
    ));
  }
  for (final draft in drafts.boundaries) {
    mention(draft.id, draft.span[0]);
    declarations.add((
      offset: draft.span[0],
      order: declarations.length,
      run: () => declareBoundary(draft),
    ));
  }
  for (final draft in drafts.jsons) {
    mention(draft.id, draft.span[0]);
    declarations.add((
      offset: draft.span[0],
      order: declarations.length,
      run: () => unique(draft.id, 'json', draft.span),
    ));
  }
  for (final rel in drafts.relationships) {
    final id = rel.id;
    final idSpan = rel.idSpan;
    if (id != null && id.isNotEmpty && idSpan != null) {
      declarations.add((
        offset: idSpan[0],
        order: declarations.length,
        run: () => unique(id, 'edge', idSpan),
      ));
    }
  }
  declarations.sort((a, b) {
    final cmp = a.offset - b.offset;
    return cmp != 0 ? cmp : a.order - b.order;
  });
  for (final declaration in declarations) {
    declaration.run();
  }

  for (final state in inOrder(elements.values)) {
    publish(state);
  }
  for (final state in inOrder(boundaries.values)) {
    systemBoundaries[state.id] = SystemBoundary(
      id: state.id,
      label: state.label.text,
      labelType: state.label.type,
      type: 'rect',
      members: <String>[],
      classes: <String>[],
      styles: <String>[],
    );
  }
  for (final draft in inOrder(drafts.jsons)) {
    model.jsonNodes[draft.id] = UsecaseJsonNode(
      id: draft.id,
      value: draft.value,
      propertyOrder: draft.propertyOrder,
      classes: List<String>.of(draft.classes),
      styles: <String>[],
    );
  }

  var anonymous = 0;
  for (final draft in drafts.relationships) {
    final source = draft.source;
    final target = draft.target;
    final type = draft.type;
    final sourceKind = endpoint(source);
    final targetKind = endpoint(target);
    bool related(SymbolKind kind) =>
        kind == 'actor' || kind == 'usecase' || kind == 'json';
    if (!related(sourceKind)) {
      conflict(
        "Relationship source '${source.id}' cannot be $sourceKind",
        source.span,
        symbols[source.id]!.span,
      );
    }
    if (!related(targetKind)) {
      conflict(
        "Relationship target '${target.id}' cannot be $targetKind",
        target.span,
        symbols[target.id]!.span,
      );
    }
    if ((type == 'include' || type == 'extend') &&
        (sourceKind != 'usecase' || targetKind != 'usecase')) {
      fail('$type relationship requires use-case endpoints', draft.span);
    }
    if (type == 'generalization' &&
        (sourceKind == 'json' || sourceKind != targetKind)) {
      fail(
        'Generalization requires actor-to-actor or use-case-to-use-case endpoints',
        draft.span,
      );
    }
    if (type == 'association' &&
        (sourceKind == 'json' || targetKind == 'json') &&
        draft.arrowType > 2) {
      fail(
        "JSON relationship '${source.id}' to '${target.id}' permits only point, reversed-point, or markerless solid association",
        draft.span,
      );
    }
    final id = draft.id ?? 'edge-${anonymous++}';
    final relationship = Relationship(
      id: id,
      explicitId: draft.id != null && draft.id!.isNotEmpty,
      source: source.id,
      target: target.id,
      type: type,
      arrowType: draft.arrowType,
      label: draft.label?.text,
      labelType: draft.label?.type,
      minlen: draft.minlen,
      classes: <String>[],
      styles: <String>[],
      animate: false,
    );
    model.relationships.add(relationship);
    edges[id] = relationship;
  }

  // The relationships may have added use cases; put all elements back in the order of first mention.
  final declaredActors = Map<String, Actor>.of(actors);
  final declaredUseCases = Map<String, UseCase>.of(useCases);
  actors.clear();
  useCases.clear();
  for (final state in inOrder(elements.values)) {
    final actor = declaredActors[state.id];
    final useCase = declaredUseCases[state.id];
    if (actor != null) {
      actors[state.id] = actor;
    } else if (useCase != null) {
      useCases[state.id] = useCase;
    } else {
      publish(state);
    }
  }

  for (final item in drafts.metadata) {
    final target = item.target;
    final span = item.span;
    final properties = item.properties;
    final statement = item.statement;
    final origin = symbols[target];
    if (origin == null) {
      final inferred = _inferKind(properties);
      fail(
        "Metadata target '$target' is unresolved${inferred != null ? ' (metadata implies $inferred)' : ''}",
        span,
      );
    }
    final kind = origin.kind;
    if (kind == 'actor' || kind == 'usecase') {
      elementMetadata(elements[target]!, properties, true);
    } else if (kind == 'edge') {
      statement.kind = 'edgeMetadata';
      statement.edges = <EdgeOccurrence>[
        EdgeOccurrence(
          id: target,
          span: statement.span,
          idSpan: span,
          metadata: statement.metadata,
        ),
      ];
      statement.nodes = null;
    }
    final boundary = boundaries[target];
    final edge = edges[target];
    for (final property
        in (kind == 'actor' || kind == 'usecase')
            ? const <DraftProperty>[]
            : properties) {
      final key = property.key;
      final value = property.value;
      if (kind == 'boundary' &&
          boundary != null &&
          key == 'type' &&
          (value == 'rect' || value == 'package')) {
        boundary.type = value as String;
      } else if (kind == 'edge' &&
          edge != null &&
          key == 'animate' &&
          value is bool) {
        edge.animate = value;
      } else if (kind == 'edge' &&
          edge != null &&
          key == 'animation' &&
          (value == 'fast' || value == 'slow')) {
        edge.animation = value as String;
        edge.animate = true;
      } else {
        invalid(target, kind, property);
      }
    }
  }
  for (final relationship in model.relationships) {
    if (relationship.animation != null && relationship.animation!.isNotEmpty) {
      relationship.animate = true;
    }
  }

  for (final state in elements.values) {
    final hasIcon = state.icon != null && state.icon!.isNotEmpty;
    if (state.kind == 'actor') {
      if (hasIcon && state.actorType != null && state.actorType != 'normal') {
        fail(
          "Actor '${state.id}' cannot combine icon with type '${state.actorType}'",
          state.span,
        );
      }
      if (state.business == true && (hasIcon || state.actorType == 'awesome')) {
        fail(
          "Business actor '${state.id}' must use normal or hollow geometry",
          state.span,
        );
      }
    } else if (state.shape == 'rect' && state.business == true) {
      fail(
        "Rectangular use case '${state.id}' cannot be a business use case",
        state.span,
      );
    }
    publish(state);
  }

  final sortedElements = drafts.elements.indexed.toList()
    ..sort((a, b) {
      final cmp = a.$2.span[0] - b.$2.span[0];
      return cmp != 0 ? cmp : a.$1 - b.$1;
    });
  for (final (_, draft) in sortedElements) {
    if (draft.parent == null || draft.parent!.id.isEmpty) continue;
    final members = boundaries[draft.parent!.id]!.members;
    if (!members.contains(draft.id)) members.add(draft.id);
  }
  for (final state in boundaries.values) {
    final boundary = systemBoundaries[state.id]!;
    boundary.type = state.type ?? 'rect';
    boundary.members = state.members;
    boundary.classes = List<String>.of(state.classes);
  }

  var notes = 0;
  for (final draft in drafts.notes) {
    final origin = symbols[draft.target];
    if (origin == null) {
      fail("Note target '${draft.target}' is unresolved", draft.span);
    }
    if (origin.kind != 'actor' && origin.kind != 'usecase') {
      conflict(
        "Note target '${draft.target}' must be an actor or use case, not ${origin.kind}",
        draft.span,
        origin.span,
      );
    }
    final id = 'note-${notes++}';
    model.notes[id] = UsecaseNote(
      id: id,
      target: draft.target,
      label: draft.label.text,
      labelType: draft.label.type,
    );
  }

  for (final definition in drafts.classDefs) {
    for (final id in definition.ids) {
      model.classDefs[id] = ClassDef(
        id: id,
        styles: List<String>.of(definition.styles),
      );
    }
  }
  for (final assignment in drafts.classes) {
    for (final target in assignment.targets) {
      _pushUnique(stylable(target.id, target.span).classes, assignment.classes);
    }
  }
  for (final assignment in drafts.styles) {
    stylable(
      assignment.target,
      assignment.span,
    ).styles.addAll(assignment.styles);
  }

  model.direction = drafts.direction ?? model.direction;
  model.title = title;
  model.accTitle = drafts.accTitle;
  model.accDescription = drafts.accDescription;
  model.accDescr = drafts.accDescription.replaceAll(_reNewlineIndent, '\n');
  model.source = src;
  model.headerSpan = headerSpan;
  model.statements = statements;
  return model;
}

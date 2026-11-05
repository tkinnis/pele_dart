// Upstream: src/diagrams/eventmodeling/model.ts

import 'dart:math' as math;

import '../../errors.dart';
import '../../svg/root.dart';
import '../common/tokens.dart';
import 'parser.dart';

typedef EntityKind = String;
typedef LaneGroup = String;

class EmLane {
  // Mermaid's ordering key: 0 for UI/Automation, 100 for Command/Read Model, 200 for Events,
  // and the next free number after those for each namespace.
  final int index;
  final String label;
  final LaneGroup group;
  final String? namespace;

  const EmLane({
    required this.index,
    required this.label,
    required this.group,
    this.namespace,
  });
}

class EmBox {
  // The frame number as written, such as "01".
  final String id;
  final EntityKind kind;
  final String entity;
  final String name;
  final String? namespace;
  final bool reset;
  final EmLane lane;
  // Example data from the frame or from the data block it refers to.
  final String? data;
  final String? dataType;

  const EmBox({
    required this.id,
    required this.kind,
    required this.entity,
    required this.name,
    this.namespace,
    required this.reset,
    required this.lane,
    this.data,
    this.dataType,
  });
}

class EmRelation {
  final EmBox source;
  final EmBox target;

  const EmRelation({required this.source, required this.target});
}

class EmNote {
  final String frame;
  final String text;
  final String? dataType;

  const EmNote({required this.frame, required this.text, this.dataType});
}

class EmSpecification {
  final String frame;
  final List<String> given;
  final List<String> when;
  final List<String> then;

  const EmSpecification({
    required this.frame,
    required this.given,
    required this.when,
    required this.then,
  });
}

class EventModelingModel implements RootModel {
  final String type = 'eventmodeling';
  final String? title;
  @override
  final String? accTitle;
  @override
  final String? accDescr;
  final List<EmBox> boxes;
  // Sorted from top to bottom.
  final List<EmLane> lanes;
  final List<EmRelation> relations;
  final List<EmNote> notes;
  final List<EmSpecification> specifications;
  final List<String> entities;

  const EventModelingModel({
    this.title,
    this.accTitle,
    this.accDescr,
    required this.boxes,
    required this.lanes,
    required this.relations,
    required this.notes,
    required this.specifications,
    required this.entities,
  });
}

const Map<String, EntityKind> _kinds = <String, EntityKind>{
  'ui': 'ui',
  'pcr': 'processor',
  'processor': 'processor',
  'rmo': 'readmodel',
  'readmodel': 'readmodel',
  'cmd': 'command',
  'command': 'command',
  'evt': 'event',
  'event': 'event',
};

// [first index, label, label prefix for a namespace]
const Map<LaneGroup, (int, String, String)> _groups =
    <LaneGroup, (int, String, String)>{
      'trigger': (0, 'UI/Automation', 'UI/A: '),
      'state': (100, 'Command/Read Model', 'C/RM: '),
      'stream': (200, 'Events', 'Stream: '),
    };

LaneGroup _groupOf(EntityKind kind) {
  return kind == 'ui' || kind == 'processor'
      ? 'trigger'
      : kind == 'event'
      ? 'stream'
      : 'state';
}

// The text between the outer braces, without the indentation its lines share.
String _blockText(String raw) {
  final open = raw.indexOf('{');
  final close = raw.lastIndexOf('}');
  final inner = open != -1 && close > open
      ? raw.substring(open + 1, close)
      : (open == -1 && raw.length >= 2 ? raw.substring(1, raw.length - 1) : '');
  final lines = inner.replaceAll('\r', '').split('\n');
  while (lines.isNotEmpty && lines.first.trim().isEmpty) {
    lines.removeAt(0);
  }
  while (lines.isNotEmpty && lines.last.trim().isEmpty) {
    lines.removeLast();
  }
  var indent = 1 << 30;
  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    indent = math.min(indent, line.length - line.trimLeft().length);
  }
  if (indent == (1 << 30)) indent = 0;
  return lines
      .map((line) => line.substring(math.min(indent, line.length)).trimRight())
      .join('\n');
}

final RegExp _leadSpacesRe = RegExp(r'^\s+');
final RegExp _newlineSpacesRe = RegExp(r'\n\s+');

EventModelingModel buildEventModel(EventModelAst ast, String? title) {
  final ids = <String>{};
  for (final frame in ast.frames) {
    if (ids.contains(frame.name)) {
      final line = locate(ast.$source, frame.$offset).line;
      throw PeleError(
        'Duplicate event modeling frame ID "${frame.name}" on line $line',
        'semantic',
        PeleErrorInfo(type: 'eventmodeling', line: line),
      );
    }
    ids.add(frame.name);
  }

  final data = <String, String>{};
  for (final entity in ast.dataEntities) {
    if (!data.containsKey(entity.name)) {
      data[entity.name] = entity.dataBlockValue;
    }
  }

  // One lane per group, and one more per namespace within a group.
  final laneOf = <String, EmLane>{};
  final next = <LaneGroup, int>{};
  EmLane lane(EntityKind kind, String? namespace) {
    final group = _groupOf(kind);
    final key = namespace == null ? group : '$group $namespace';
    var found = laneOf[key];
    if (found == null) {
      final (first, label, prefix) = _groups[group]!;
      var index = first;
      if (namespace != null) {
        index = next[group] ?? (first + 1);
        next[group] = index + 1;
      }
      found = EmLane(
        index: index,
        label: namespace == null ? label : '$prefix$namespace',
        group: group,
        namespace: namespace,
      );
      laneOf[key] = found;
    }
    return found;
  }

  final boxes = <EmBox>[];
  final byId = <String, EmBox>{};
  final relations = <EmRelation>[];
  for (var index = 0; index < ast.frames.length; index++) {
    final frame = ast.frames[index];
    // Only a two-part name has a namespace.
    final parts = frame.entityIdentifier.split('.');
    final namespace = parts.length == 2 ? parts[0] : null;
    final kind = _kinds[frame.modelEntityType] ?? 'event';
    var text = frame.dataInlineValue == null
        ? null
        : _blockText(frame.dataInlineValue!);
    if (frame.dataReference != null) {
      final block = data[frame.dataReference!.$refText];
      if (block != null) text = _blockText(block);
    }
    final box = EmBox(
      id: frame.name,
      kind: kind,
      entity: frame.entityIdentifier,
      name: parts.length == 2 ? parts[1] : frame.entityIdentifier,
      namespace: namespace,
      reset: frame.$type == 'EmResetFrame',
      lane: lane(kind, namespace),
      data: text,
      dataType: frame.dataType,
    );
    boxes.add(box);
    byId[box.id] = box;

    if (frame.sourceFrames.isNotEmpty) {
      // Sources connect in frame order, and only frames that already have a box.
      final wanted = frame.sourceFrames.map((ref) => ref.$refText).toSet();
      for (final source in boxes) {
        if (wanted.contains(source.id)) {
          relations.add(EmRelation(source: source, target: box));
        }
      }
    } else if (index > 0 && !box.reset) {
      // Otherwise the nearest earlier frame in another lane feeds this one.
      for (var i = index - 1; i >= 0; i--) {
        if (!identical(boxes[i].lane, box.lane)) {
          relations.add(EmRelation(source: boxes[i], target: box));
          break;
        }
      }
    }
  }

  List<String> names(List<EmGwtStatement> statements) =>
      statements.map((s) => s.entityIdentifier.$refText).toList();
  final astTitle = (ast.title != null && ast.title!.isNotEmpty)
      ? titleValue(ast.title!)
      : '';
  final sortedLanes = laneOf.values.toList()
    ..sort((a, b) => a.index.compareTo(b.index));
  return EventModelingModel(
    title: astTitle.isNotEmpty ? astTitle : title,
    accTitle: ast.accTitle != null && ast.accTitle!.isNotEmpty
        ? accTitleValue(ast.accTitle!).replaceFirst(_leadSpacesRe, '')
        : null,
    accDescr: ast.accDescr != null && ast.accDescr!.isNotEmpty
        ? accDescrValue(ast.accDescr!).replaceAll(_newlineSpacesRe, '\n')
        : null,
    boxes: boxes,
    lanes: sortedLanes,
    relations: relations,
    notes: ast.noteEntities
        .map(
          (note) => EmNote(
            frame: note.sourceFrame.$refText,
            text: _blockText(note.dataBlockValue),
            dataType: note.dataType,
          ),
        )
        .toList(),
    specifications: ast.gwtEntities
        .map(
          (gwt) => EmSpecification(
            frame: gwt.sourceFrame.$refText,
            given: names(gwt.givenStatements),
            when: names(gwt.whenStatements),
            then: names(gwt.thenStatements),
          ),
        )
        .toList(),
    entities: ast.modelEntities.map((entity) => entity.name).toList(),
  );
}

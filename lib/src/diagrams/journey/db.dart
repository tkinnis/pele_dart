// Upstream: src/diagrams/journey/db.ts

import '../../svg/root.dart';

class JourneyTask {
  final String task;
  // As written: any number, or NaN when the score is not one.
  final double score;
  final List<String> people;
  // Name of the section in force when the task was declared, '' before the first one.
  final String section;

  JourneyTask({
    required this.task,
    required this.score,
    required this.people,
    required this.section,
  });
}

abstract interface class JourneyModel implements RootModel {
  String get type;
  String? get title;
  @override
  String? get accTitle;
  @override
  String? get accDescr;
  List<String> get sections;
  List<JourneyTask> get tasks;
}

/// Everyone named on a task, once each, in code unit order.
List<String> journeyActors(List<JourneyTask> tasks) {
  final names = <String>{};
  for (final task in tasks) {
    for (final name in task.people) {
      names.add(name);
    }
  }
  return names.toList()..sort();
}

final RegExp _leadSpaceRe = RegExp(r'^\s+');
final RegExp _newlineSpaceRe = RegExp(r'\n\s+');

double _jsNumber(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return 0.0;
  return double.tryParse(trimmed) ?? double.nan;
}

class JourneyDb implements JourneyModel {
  @override
  final String type = 'journey';
  @override
  String? title;
  @override
  String? accTitle;
  @override
  String? accDescr;
  @override
  List<String> sections = <String>[];
  @override
  List<JourneyTask> tasks = <JourneyTask>[];

  String _currentSection = '';

  void setDiagramTitle(String text) {
    title = text;
  }

  void setAccTitle(String text) {
    accTitle = text.replaceFirst(_leadSpaceRe, '');
  }

  void setAccDescription(String text) {
    accDescr = text.replaceAll(_newlineSpaceRe, '\n');
  }

  void addSection(String text) {
    _currentSection = text;
    sections.add(text);
  }

  // `data` is the rest of the line from its first colon: `:score` or `:score:actor, actor`.
  void addTask(String task, String data) {
    final pieces = data.substring(1).split(':');
    final people = pieces.length == 1
        ? <String>[]
        : pieces[1].split(',').map((name) => name.trim()).toList();
    tasks.add(
      JourneyTask(
        task: task,
        score: _jsNumber(pieces[0]),
        people: people,
        section: _currentSection,
      ),
    );
  }

  List<String> getActors() {
    return journeyActors(tasks);
  }
}

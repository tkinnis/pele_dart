// Upstream: src/diagrams/timeline/db.ts

import '../../errors.dart';
import '../../svg/root.dart';

class TimelinePeriod {
  final String text;
  final List<String> events;
  // Name of the section in force when the period was declared, '' before the first one.
  final String section;
  // Index into `sections` of that section, -1 before the first one.
  final int sectionIndex;

  TimelinePeriod({
    required this.text,
    required this.events,
    required this.section,
    required this.sectionIndex,
  });
}

abstract interface class TimelineModel implements RootModel {
  String get type;
  String? get title;
  @override
  String? get accTitle;
  @override
  String? get accDescr;
  String get direction;
  List<String> get sections;
  List<TimelinePeriod> get periods;
}

final RegExp _leadSpaceRe = RegExp(r'^\s+');
final RegExp _newlineSpaceRe = RegExp(r'\n\s+');

class TimelineDb implements TimelineModel {
  @override
  final String type = 'timeline';
  @override
  String? title;
  @override
  String? accTitle;
  @override
  String? accDescr;
  @override
  String direction = 'LR';
  @override
  List<String> sections = <String>[];
  @override
  List<TimelinePeriod> periods = <TimelinePeriod>[];

  String _currentSection = '';

  // The grammar reaches the title and accessibility setters through this.
  TimelineDb getCommonDb() {
    return this;
  }

  void setDiagramTitle(String text) {
    title = text;
  }

  void setAccTitle(String text) {
    accTitle = text.replaceFirst(_leadSpaceRe, '');
  }

  void setAccDescription(String text) {
    accDescr = text.replaceAll(_newlineSpaceRe, '\n');
  }

  void setDirection(String direction) {
    this.direction = direction;
  }

  void addSection(String text) {
    _currentSection = text;
    sections.add(text);
  }

  void addTask(String period, [int? length, String? event]) {
    periods.add(
      TimelinePeriod(
        text: period,
        events: (event != null && event.isNotEmpty)
            ? <String>[event]
            : <String>[],
        section: _currentSection,
        sectionIndex: sections.length - 1,
      ),
    );
  }

  void addEvent(String event) {
    // Mermaid fails here too, with a TypeError.
    if (periods.isEmpty) {
      throw PeleError(
        'An event needs a time period before it.',
        'semantic',
        const PeleErrorInfo(type: 'timeline'),
      );
    }
    periods[periods.length - 1].events.add(event);
  }
}

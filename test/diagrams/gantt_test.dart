import 'package:pele_dart/pele_dart.dart';
import 'package:pele_dart/src/diagrams/gantt/index.dart';
import 'package:test/test.dart';

void main() {
  group('gantt diagram', () {
    const sampleGantt = '''
gantt
  title A Gantt Diagram
  accTitle: Gantt Accessible Title
  accDescr {
    Multi-line description
    for the gantt chart
  }
  dateFormat YYYY-MM-DD
  axisFormat %Y-%m-%d
  excludes weekends
  section Section A
    Completed task :done, des1, 2014-01-06, 2014-01-08
    Active task :active, des2, 2014-01-09, 3d
    Critical task :crit, des3, after des2, 5d
    Milestone :milestone, m1, after des3, 0d
  section Section B
    Future task :des4, after des3, 5d
    Until task :des5, 2014-01-09, until m1
    Vertical marker :vert, v1, 2014-01-12, 1d
    click des1 href "https://example.com"
    click des2 call myCallback("arg1")
''';

    test('renders in cssVariables mode', () {
      final res = render(
        sampleGantt,
        RenderOptions(
          outputMode: SvgOutputMode.cssVariables,
          now: DateTime(2014, 1, 10, 12),
        ),
      );
      expect(res.type, 'gantt');
      expect(res.mermaidType, 'gantt');
      expect(res.width, greaterThan(200));
      expect(res.height, greaterThan(100));
      expect(res.svg, contains('class="pele pele-gantt"'));
      expect(res.svg, contains('var(--_fg)'));
      expect(
        res.svg,
        contains('<title id="pele-title">Gantt Accessible Title</title>'),
      );
      expect(res.svg, contains('A Gantt Diagram'));
      expect(res.svg, contains('pele-done'));
      expect(res.svg, contains('pele-active'));
      expect(res.svg, contains('pele-crit'));
      expect(res.svg, contains('pele-milestone'));
      expect(res.svg, contains('pele-vert'));
      expect(res.svg, contains('pele-today'));
      expect(res.svg, contains('pele-excluded'));
      expect(res.links.length, 1);
      expect(res.links.first.id, 'des1');
      expect(res.links.first.href, 'https://example.com/');
    });

    test('renders in flattened mode without CSS variables', () {
      final res = render(
        sampleGantt,
        RenderOptions(
          outputMode: SvgOutputMode.flattened,
          now: DateTime(2014, 1, 10, 12),
        ),
      );
      expect(res.type, 'gantt');
      expect(res.svg, isNot(contains('var(--')));
      expect(res.svg, isNot(contains('color-mix(')));
      expect(res.svg, contains('A Gantt Diagram'));
      expect(res.svg, contains('Completed task'));
      expect(res.svg, contains('Section A'));
      expect(res.svg, contains('Section B'));
    });

    test('supports compact displayMode, topAxis, tickInterval, weekday, and weekend', () {
      const compactSrc = '''---
displayMode: compact
---
gantt
  dateFormat YYYY-MM-DD
  topAxis
  inclusiveEndDates
  tickInterval 1week
  weekday monday
  weekend friday
  todayMarker stroke:#f00,stroke-width:3px
  includes 2024-01-05
  excludes weekends
  section Work
    Task 1 :t1, 2024-01-01, 2024-01-03
    Task 2 :t2, 2024-01-05, 2024-01-08
    Task 3 :t3, 2024-01-02, 2024-01-06
''';
      final res = render(
        compactSrc,
        RenderOptions(
          outputMode: SvgOutputMode.flattened,
          now: DateTime(2024, 1, 4, 12),
        ),
      );
      expect(res.svg, isNot(contains('var(--')));
      expect(res.svg, contains('Task 1'));
      expect(res.svg, contains('Task 2'));
      expect(res.svg, contains('Task 3'));
      expect(res.svg, contains('pele-today'));
    });

    test('resolves forward task references across multiple passes', () {
      const forwardSrc = '''
gantt
  dateFormat YYYY-MM-DD
  Second task :t2, after t1, 2d
  First task :t1, 2024-03-01, 3d
''';
      final model = parse(forwardSrc) as GanttDb;
      final tasks = model.getTasks();
      expect(tasks.length, 2);
      expect(tasks[0].startTime, DateTime(2024, 3, 4));
      expect(tasks[0].endTime, DateTime(2024, 3, 6));
      expect(tasks[1].startTime, DateTime(2024, 3, 1));
      expect(tasks[1].endTime, DateTime(2024, 3, 4));
    });

    test('dates and axis helpers format and parse strictly', () {
      final now = DateTime(2024, 6, 15);
      final parsed = parseStrict('2024-02-29', 'YYYY-MM-DD', now);
      expect(parsed, DateTime(2024, 2, 29));
      expect(parseStrict('2023-02-29', 'YYYY-MM-DD', now), isNull);

      final doDate = parseStrict('3rd March 2024', 'Do MMMM YYYY', now);
      expect(doDate, DateTime(2024, 3, 3));
      expect(format(doDate, 'Do MMM YYYY'), '3rd Mar 2024');

      expect(
        timeFormat('%Y-%m-%d (%a)', DateTime(2024, 1, 1)),
        '2024-01-01 (Mon)',
      );
    });

    test('throws PeleError on semantic and syntax errors', () {
      expect(
        () => render('gantt\n  Bad task :done, active'),
        throwsA(isA<PeleError>()),
      );
      expect(
        () => render('gantt\n  Too many :a, b, c, d'),
        throwsA(isA<PeleError>()),
      );
      expect(
        () => render(
          'gantt\n  dateFormat YYYY-MM-DD\n  Bad date :t1, not-a-date, 3d',
        ),
        throwsA(isA<PeleError>()),
      );
    });
  });
}

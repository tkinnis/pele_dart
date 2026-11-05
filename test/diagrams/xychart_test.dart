import 'package:pele_dart/pele_dart.dart';
import 'package:pele_dart/src/diagrams/xychart/ticks.dart';
import 'package:test/test.dart';

void main() {
  group('xychart diagram', () {
    const verticalChart = '''
xychart-beta
  title "Sales Revenue"
  accTitle: Revenue Chart
  accDescr: Monthly revenue bar and line chart
  x-axis "Month" [jan, feb, mar, apr]
  y-axis "Revenue (in \$)" 0 --> 100
  bar "Bars" [25, 50, 75, 90]
  line "Trend" [20 "low", 45, 70, 95 "peak"]
''';

    test(
      'renders vertical chart in SvgOutputMode.cssVariables via renderMermaid',
      () {
        final svg = renderMermaid(
          verticalChart,
          options: const RenderOptions(outputMode: SvgOutputMode.cssVariables),
        );
        expect(svg, startsWith('<svg '));
        expect(svg, contains('class="pele pele-xychart"'));
        expect(svg, contains('Sales Revenue'));
        expect(svg, contains('Revenue Chart'));
        expect(svg, contains('Monthly revenue bar and line chart'));
        expect(svg, contains('class="pele-series pele-bars"'));
        expect(svg, contains('class="pele-series pele-line"'));
        expect(svg, contains('class="pele-point-labels"'));
        expect(svg, contains('class="pele-legend"'));
        expect(svg, contains('peak'));
        expect(svg, contains('var(--_fg)'));
      },
    );

    test(
      'renders vertical chart in SvgOutputMode.flattened via renderMermaid',
      () {
        final svg = renderMermaid(
          verticalChart,
          options: const RenderOptions(outputMode: SvgOutputMode.flattened),
        );
        expect(svg, startsWith('<svg '));
        expect(svg, contains('class="pele pele-xychart"'));
        expect(svg, isNot(contains('var(--')));
        expect(svg, isNot(contains('color-mix(')));
        expect(svg, contains('Sales Revenue'));
        expect(svg, contains('Revenue (in \$)'));
      },
    );

    test('renders horizontal chart with numeric x-axis and data labels', () {
      const horizontalChart = '''
---
config:
  xyChart:
    showDataLabel: true
---
xychart horizontal
  title "Horizontal Comparison"
  x-axis "Items" 10 --> 40
  y-axis "Score"
  bar "Group A" [10, -5, 25, 40]
  bar "Group B" [15, 10, 20, 35]
''';
      final svg = renderMermaid(
        horizontalChart,
        options: const RenderOptions(outputMode: SvgOutputMode.cssVariables),
      );
      expect(svg, contains('Horizontal Comparison'));
      expect(svg, contains('class="pele-data-labels"'));
      expect(svg, contains('Group A'));
      expect(svg, contains('Group B'));
    });

    test('tickStep and ticksBetween produce clean decimal ticks', () {
      final step = tickStep(1.0, 5);
      final ticks = ticksBetween(0, 1, step);
      expect(ticks, containsAll(<double>[0, 0.2, 0.4, 0.6, 0.8, 1.0]));
    });

    test('throws semantic PeleError when no plots are provided', () {
      const emptyChart = '''
xychart-beta
  title "Empty"
  x-axis [a, b, c]
''';
      expect(
        () => renderMermaid(emptyChart),
        throwsA(
          isA<PeleError>().having(
            (e) => e.message,
            'message',
            contains('No Plot to render'),
          ),
        ),
      );
    });
  });
}

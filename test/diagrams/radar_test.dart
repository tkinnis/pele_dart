import 'package:pele_dart/pele_dart.dart';
import 'package:pele_dart/src/diagrams/radar/render.dart';
import 'package:test/test.dart';

void main() {
  group('radar diagram', () {
    const circleRadar = '''
radar-beta
  title Skills Assessment
  accTitle: Team Skills
  accDescr: Comparison of Engineering and Design skills
  axis A["Coding"], B["Testing"], C["Architecture"], D["UX"], E["Communication"]
  curve c1["Frontend"]{80, 70, 65, 90, 85}
  curve c2["Backend"]{ A: 90, B: 85, C: 95, D: 50, E: 75 }
  showLegend true
  ticks 4
  min 0
  max 100
  graticule circle
''';

    test('renders circle graticule in SvgOutputMode.cssVariables via renderMermaid', () {
      final svg = renderMermaid(
        circleRadar,
        options: const RenderOptions(outputMode: SvgOutputMode.cssVariables),
      );
      expect(svg, startsWith('<svg '));
      expect(svg, contains('class="pele pele-radar"'));
      expect(svg, contains('Skills Assessment'));
      expect(svg, contains('Team Skills'));
      expect(svg, contains('class="pele-graticule"'));
      expect(svg, contains('<circle r='));
      expect(svg, contains('class="pele-curves"'));
      expect(svg, contains('class="pele-axis-labels"'));
      expect(svg, contains('class="pele-legend"'));
      expect(svg, contains('Frontend'));
      expect(svg, contains('Backend'));
      expect(svg, contains('var(--_fg)'));
    });

    test('renders in SvgOutputMode.flattened via renderMermaid', () {
      final svg = renderMermaid(
        circleRadar,
        options: const RenderOptions(outputMode: SvgOutputMode.flattened),
      );
      expect(svg, startsWith('<svg '));
      expect(svg, contains('class="pele pele-radar"'));
      expect(svg, isNot(contains('var(--')));
      expect(svg, isNot(contains('color-mix(')));
      expect(svg, contains('Skills Assessment'));
      expect(svg, contains('Architecture'));
    });

    test('renders polygon graticule and tight width layout', () {
      const polygonRadar = '''
radar-beta:
  axis X, Y, Z
  curve p["Alpha"]{10, 20, 30}
  graticule polygon
  showLegend true
''';
      final svg = renderMermaid(
        polygonRadar,
        options: const RenderOptions(
          outputMode: SvgOutputMode.cssVariables,
          maxWidth: 200,
        ),
      );
      expect(svg, contains('<polygon points='));
      expect(svg, contains('data-id="p"'));
    });

    test('relativeRadius and closedRoundCurve helpers work accurately', () {
      expect(relativeRadius(50, 0, 100, 160), equals(80));
      expect(relativeRadius(150, 0, 100, 160), equals(160));
      expect(relativeRadius(-10, 0, 100, 160), equals(0));

      final path = closedRoundCurve(const <RadarPoint>[
        RadarPoint(x: 0, y: -10),
        RadarPoint(x: 10, y: 10),
        RadarPoint(x: -10, y: 10),
      ], 0.17);
      expect(path, startsWith('M0,-10 C'));
      expect(path, endsWith(' Z'));
    });

    test('throws semantic PeleError when named axis entry is missing', () {
      const missingAxis = '''
radar-beta
  axis A, B, C
  curve c1{ A: 10, B: 20 }
''';
      expect(
        () => renderMermaid(missingAxis),
        throwsA(
          isA<PeleError>().having(
            (e) => e.message,
            'message',
            contains('Missing entry for axis C'),
          ),
        ),
      );
    });
  });
}

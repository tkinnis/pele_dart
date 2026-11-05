import 'package:pele_dart/pele_dart.dart';
import 'package:pele_dart/src/diagrams/quadrant/db.dart';
import 'package:test/test.dart';

void main() {
  const cssOptions = RenderOptions(outputMode: SvgOutputMode.cssVariables);
  const flatOptions = RenderOptions(outputMode: SvgOutputMode.flattened);

  const chart = '''quadrantChart
  title Reach and engagement
  x-axis Low Reach --> High Reach
  y-axis Low Engagement --> High Engagement
  quadrant-1 Expand
  quadrant-2 Promote
  quadrant-3 Re-evaluate
  quadrant-4 Improve
  Campaign A: [0.25, 0.75]
  Campaign B: [0.75, 0.25]''';

  group('quadrantChart diagram', () {
    test(
      'draws title, four quadrants, axis labels and points in both modes',
      () {
        final res = render(chart, cssOptions);
        expect(res.type, 'quadrantChart');
        expect(supports('quadrantChart'), isTrue);
        expect([res.width, res.height], [500, 500]);
        expect(res.svg, contains('class="pele pele-quadrantChart"'));
        expect(RegExp('class="pele-quadrant"').allMatches(res.svg).length, 4);
        for (final text in [
          'Reach and engagement',
          'Low Reach',
          'High Reach',
          'Low Engagement',
          'High Engagement',
          'Expand',
          'Promote',
          'Re-evaluate',
          'Improve',
          'Campaign A',
          'Campaign B',
        ]) {
          expect(res.svg, contains('>$text<'));
        }
        expect(RegExp('<circle ').allMatches(res.svg).length, 2);
        expect(res.svg, contains('var(--pele-series-1,'));

        final flat = render(chart, flatOptions);
        expect(flat.type, 'quadrantChart');
        expect([flat.width, flat.height], [500, 500]);
        expect(flat.svg, isNot(contains('var(--')));
        expect(flat.svg, isNot(contains('color-mix(')));
        expect(flat.svg, contains('>Reach and engagement<'));
        expect(flat.svg, contains('>Campaign A<'));
        expect(flat.svg, contains('>Campaign B<'));
      },
    );

    test('places points by coordinates and draws first point on top', () {
      final svg = render(
        'quadrantChart\n A: [0, 0]\n B: [1, 1]\n C: [0.5, 0.5]',
        cssOptions,
      ).svg;
      (double, double) at(String id) {
        final m = RegExp('data-id="$id" cx="([\\d.]+)" cy="([\\d.]+)"')
            .firstMatch(svg)!;
        return (double.parse(m.group(1)!), double.parse(m.group(2)!));
      }

      final (ax, ay) = at('A');
      final (bx, by) = at('B');
      expect(bx, greaterThan(ax));
      expect(by, lessThan(ay));
      expect(at('C'), ((ax + bx) / 2, (ay + by) / 2));

      final orderSvg = render(
        'quadrantChart\n First: [0.5, 0.5]\n Second: [0.5, 0.5]',
        cssOptions,
      ).svg;
      final ids = [
        for (final m in RegExp(
          r'<circle [^>]*data-id="([^"]+)"',
        ).allMatches(orderSvg))
          m.group(1)!,
      ];
      expect(ids, ['Second', 'First']);
    });

    test('moves x-axis labels below chart once there are points or xAxisPosition=bottom', () {
      double yOfLeft(String src) {
        final svg = render(src, cssOptions).svg;
        final m = RegExp(r'<text[^>]* y="([\d.]+)"[^>]*>Left<')
            .firstMatch(svg)!;
        return double.parse(m.group(1)!);
      }

      expect(yOfLeft('quadrantChart\n x-axis Left --> Right'), lessThan(100));
      expect(
        yOfLeft('quadrantChart\n x-axis Left --> Right\n A: [0.5, 0.5]'),
        greaterThan(400),
      );
      expect(
        yOfLeft(
          '---\nconfig:\n  quadrantChart:\n    xAxisPosition: bottom\n---\nquadrantChart\n x-axis Left --> Right',
        ),
        greaterThan(400),
      );
    });

    test(
      'applies point styles and classDef styles, and validates invalid styles',
      () {
        final svg = render(
          '''quadrantChart
        A: [0.1, 0.1] radius: 12
        B:::c1: [0.2, 0.2] color: #ff3300, radius: 10
        C:::c2: [0.3, 0.3]
        D: [0.4, 0.4] color: 00f, stroke-width: 3px
        E: [0.5, 0.5] stroke-color: #00ff00
        classDef c1 color: #109060
        classDef c2 color: #908342, radius : 9, stroke-color: #310085, stroke-width: 10px''',
          cssOptions,
        ).svg;
        expect(svg, contains('data-id="A" cx="'));
        expect(svg, contains('r="12"'));
        expect(svg, contains('class="pele-point c1" data-id="B"'));
        expect(svg, contains('style="fill:#ff3300;"'));
        expect(
          svg,
          contains('style="fill:#908342;stroke:#310085;stroke-width:10px;"'),
        );
        expect(svg, contains('style="fill:#00f;stroke-width:3px;"'));

        expect(
          () => render('quadrantChart\n A: [0.1, 0.1] radius: big', cssOptions),
          throwsA(
            isA<PeleError>().having(
              (e) => e.message,
              'message',
              contains(
                'value for radius big is invalid, please use a valid number',
              ),
            ),
          ),
        );
        expect(
          () => render('quadrantChart\n A: [0.1, 0.1] color: red', cssOptions),
          throwsA(
            isA<PeleError>().having(
              (e) => e.message,
              'message',
              contains(
                'value for color red is invalid, please use a valid hex code',
              ),
            ),
          ),
        );
        expect(
          () => render('quadrantChart\n classDef c fill: #fff', cssOptions),
          throwsA(
            isA<PeleError>().having(
              (e) => e.message,
              'message',
              contains('style named fill is not supported.'),
            ),
          ),
        );
        expect(
          () => render('quadrantChart\n A: [1.2, 0.4]', cssOptions),
          throwsA(isA<PeleError>()),
        );
        expect(
          () => render('quadrantChart\n A: [0.2, 0.4', cssOptions),
          throwsA(isA<PeleError>()),
        );
      },
    );

    test('leaves out points whose coordinate is not a number from 0 to 1', () {
      final svg = render(
        'quadrantChart\n A: [0x5, 0.5]\n B: [0,5, 0.5]\n C: [0.5, 0.5]',
        cssOptions,
      ).svg;
      final ids = [
        for (final m in RegExp(
          r'<circle [^>]*data-id="([^"]+)"',
        ).allMatches(svg))
          m.group(1)!,
      ];
      expect(ids, ['C']);
    });

    test('honours config settings, markdown strings, accessibility, and model structure', () {
      const src = '''---
config:
  quadrantChart:
    chartWidth: 400
    chartHeight: 320
    titleFontSize: 30
    quadrantLabelFontSize: 20
    xAxisLabelFontSize: 11
    yAxisLabelFontSize: 13
    pointLabelFontSize: 9
---
quadrantChart
  title Garden plan
  accTitle: Priorities
  accDescr: Four boxes
  x-axis Low effort --> High effort
  y-axis Low value --> High value
  quadrant-1 "`**Bold** text`"
  "two<br>lines": [0.3, 0.7]''';
      final res = render(src, cssOptions);
      expect([res.width, res.height], [400, 320]);
      expect(res.svg, contains('class="pele-title" font-size="30"'));
      expect(
        res.svg,
        contains('class="pele-label" font-size="20" fill="var(--_fg)"'),
      );
      expect(res.svg, contains('<g class="pele-axis-labels" font-size="11"'));
      expect(res.svg, contains('<g class="pele-point-labels" font-size="9"'));
      expect(res.svg, contains('<title id="pele-title">Priorities</title>'));
      expect(res.svg, contains('<desc id="pele-desc">Four boxes</desc>'));
      expect(res.svg, contains('font-weight="var(--_w)">Bold</tspan>'));

      final model = parse(
        'quadrantChart\n x-axis a --> b\n quadrant-2 "`Do`"\n P:::k: [0.2, 0.8] radius: 3\n classDef k color: #abc',
      ) as QuadrantModel;
      expect(model.type, 'quadrantChart');
      expect(model.xAxisLeft, QuadrantText(text: 'a', type: 'text'));
      expect(model.xAxisRight, QuadrantText(text: 'b', type: 'text'));
      expect(model.quadrants[1], QuadrantText(text: 'Do', type: 'markdown'));
      expect(model.points.single.x, 0.2);
      expect(model.points.single.y, 0.8);
      expect(model.points.single.radius, 3);
      expect(model.classes['k']?.color, '#abc');
    });
  });
}

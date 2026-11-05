import 'package:pele_dart/pele_dart.dart';
import 'package:pele_dart/src/diagrams/pie/index.dart';
import 'package:pele_dart/src/diagrams/pie/model.dart';
import 'package:pele_dart/src/diagrams/pie/parser.dart';
import 'package:pele_dart/src/types.dart';
import 'package:test/test.dart';

void main() {
  group('pie diagram', () {
    test(
      'parses basic pie diagram with title, showData, and accessibility',
      () {
        const src = '''
pie showData
  title Key elements in Product X
  accTitle: Product X Breakdown
  accDescr {
    Calcium, Potassium, and Magnesium
    in Product X
  }
  "Calcium" : 42.96
  "Potassium" : 50.05
  "Magnesium" : 10.01
  'Iron' : 5
''';
        final ast = parsePie(src);
        expect(ast.showData, isTrue);
        expect(ast.title, equals('Key elements in Product X'));
        expect(ast.accTitle, equals('Product X Breakdown'));
        expect(
          ast.accDescr,
          equals('Calcium, Potassium, and Magnesium\nin Product X'),
        );
        expect(ast.sections.length, equals(4));

        final model = buildPie(ast, null);
        expect(model.type, equals('pie'));
        expect(model.showData, isTrue);
        expect(
          model.accDescr,
          equals('Calcium, Potassium, and Magnesium\nin Product X'),
        );
        expect(model.sections['Calcium'], equals(42.96));
        expect(model.sections['Potassium'], equals(50.05));
        expect(model.sections['Magnesium'], equals(10.01));
        expect(model.sections['Iron'], equals(5));
      },
    );

    test(
      'ignores duplicate section labels and uses frontmatter title fallback',
      () {
        final parsed = parse('''
---
title: Frontmatter Pie
---
pie
  "Apples" : 10
  "Apples" : 25
  "Oranges" : 15
''');
        final model = parsed as PieModel;
        expect(model.type, equals('pie'));
        expect(model.title, equals('Frontmatter Pie'));
        expect(model.sections['Apples'], equals(10));
        expect(model.sections['Oranges'], equals(15));
      },
    );

    test('throws PeleError on negative section values', () {
      expect(
        () => pie.parse(
          'pie\n  "Valid" : 10\n  "Invalid" : -5',
          const <String, Object?>{},
          null,
          0,
          const ParseLimits(maxEdges: 500),
        ),
        throwsA(
          isA<PeleError>().having(
            (e) => e.message,
            'message',
            contains('"Invalid" has invalid value: -5'),
          ),
        ),
      );
    });

    test('renders SVG in both cssVariables and flattened modes', () {
      const src = '''
pie showData title Browser Share
  "Chrome" : 65
  "Safari" : 20
  "Firefox" : 10
  "Tiny1" : 1
  "Tiny2" : 1
''';
      final cssOut = render(
        src,
        const RenderOptions(outputMode: SvgOutputMode.cssVariables),
      );
      expect(cssOut.type, equals('pie'));
      expect(cssOut.width, greaterThan(0));
      expect(cssOut.height, greaterThan(0));
      expect(cssOut.svg, startsWith('<svg'));
      expect(cssOut.svg, contains('class="pele pele-pie"'));
      expect(cssOut.svg, contains('aria-roledescription="pie"'));
      expect(cssOut.svg, contains('Browser Share'));
      expect(cssOut.svg, contains('Chrome [65]'));
      expect(cssOut.svg, contains('var(--_'));
      expect(cssOut.svg, contains('class="pele-slice-labels"'));

      final flatOut = render(
        src,
        const RenderOptions(outputMode: SvgOutputMode.flattened),
      );
      expect(flatOut.type, equals('pie'));
      expect(flatOut.svg, startsWith('<svg'));
      expect(flatOut.svg, contains('Browser Share'));
      expect(flatOut.svg, contains('Chrome [65]'));
      expect(flatOut.svg, isNot(contains('var(--_')));
    });

    test(
      'renders single full-circle slice, zero-sum empty pie, and bottom legend',
      () {
        final singleOut = render('pie\n  "All" : 100');
        expect(
          singleOut.svg,
          contains(
            '<path class="pele-slice" data-id="All" d="M0,-120A120,120 0 1 1 0,120A120,120 0 1 1 0,-120Z"',
          ),
        );
        expect(singleOut.svg, contains('100%'));

        final zeroOut = render('pie\n  "Zero" : 0');
        expect(
          zeroOut.svg,
          contains('<circle class="pele-slice" r="120" fill="none"'),
        );

        final narrowOut = render(
          'pie title Narrow Layout\n  "Alpha" : 40\n  "Beta" : 60',
          const RenderOptions(maxWidth: 260),
        );
        expect(narrowOut.svg, contains('Narrow Layout'));
        expect(narrowOut.width, lessThanOrEqualTo(260));
      },
    );
  });
}

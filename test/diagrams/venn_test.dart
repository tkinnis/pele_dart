import 'package:pele_dart/pele_dart.dart';
import 'package:pele_dart/src/diagrams/venn/layout.dart';
import 'package:pele_dart/src/diagrams/venn/types.dart';
import 'package:test/test.dart';

void main() {
  group('venn diagram', () {
    const basicVenn = '''
venn-beta
  title Software Architecture
  set A["Frontend"]: 20
    text a1["React"]
    text a2["Flutter"]
  set B["Backend"]: 20
    text b1["Dart"]
  set C["Database"]: 15
  union A, B["Fullstack"]: 5
    text ab1["Shared Types"]
  union A, B, C["Core"]: 2
  style A fill: #ff0000, stroke: #333, color: #fff
  style A, B fill: rgb(0, 128, 255), fill-opacity: 0.4
  style a1 color: rgba(255, 255, 255, 0.9)
''';

    test('renders in SvgOutputMode.cssVariables via renderMermaid', () {
      final svg = renderMermaid(
        basicVenn,
        options: const RenderOptions(outputMode: SvgOutputMode.cssVariables),
      );
      expect(svg, startsWith('<svg '));
      expect(svg, contains('class="pele pele-venn"'));
      expect(svg, contains('Software Architecture'));
      expect(svg, contains('class="pele-venn-set"'));
      expect(svg, contains('class="pele-venn-overlap"'));
      expect(svg, contains('class="pele-venn-region"'));
      expect(svg, contains('class="pele-venn-text"'));
      expect(svg, contains('Frontend'));
      expect(svg, contains('Backend'));
      expect(svg, contains('Database'));
      expect(svg, contains('Fullstack'));
      expect(svg, contains('Shared Types'));
      expect(svg, contains('var(--_fg)'));
    });

    test('renders in SvgOutputMode.flattened via renderMermaid', () {
      final svg = renderMermaid(
        basicVenn,
        options: const RenderOptions(outputMode: SvgOutputMode.flattened),
      );
      expect(svg, startsWith('<svg '));
      expect(svg, contains('class="pele pele-venn"'));
      expect(svg, isNot(contains('var(--')));
      expect(svg, isNot(contains('color-mix(')));
      expect(svg, contains('Frontend'));
      expect(svg, contains('Fullstack'));
    });

    test('handles 4+ sets ring relaxation and standalone text statements', () {
      const multiSetVenn = '''
venn-beta
  set A
  set B
  set C
  set D
  union A, B: 3
    text indentedItem[Indented Item]
  union B, C: 3
  union C, D: 3
  union A, D: 3
text A, B item1[Overlap Item]
''';
      final res = render(
        multiSetVenn,
        const RenderOptions(outputMode: SvgOutputMode.cssVariables),
      );
      expect(res.type, 'venn');
      expect(res.width, greaterThan(100));
      expect(res.height, greaterThan(100));
      expect(res.svg, contains('Indented Item'));
      expect(res.svg, contains('Overlap Item'));
    });

    test('layout helpers compute lensArea, distanceForOverlap, and pairwise subsets', () {
      expect(lensArea(10, 10, 25), equals(0));
      expect(lensArea(10, 5, 2), closeTo(3.14159 * 25, 0.01));
      final dist = distanceForOverlap(10, 10, 50);
      expect(lensArea(10, 10, dist), closeTo(50, 1e-4));

      final subsets = <VennSubset>[
        const VennSubset(sets: <String>['A'], size: 12),
        const VennSubset(sets: <String>['B'], size: 8),
        const VennSubset(sets: <String>['C'], size: 8),
        const VennSubset(sets: <String>['A', 'B', 'C'], size: 1),
      ];
      final expanded = ensurePairwiseSubsets(subsets);
      expect(expanded.length, equals(7));
    });

    test('rejects unknown set identifiers in union', () {
      const invalidUnion = '''
venn-beta
  set A
  union A, Z
''';
      expect(
        () => renderMermaid(invalidUnion),
        throwsA(
          isA<PeleError>().having(
            (e) => e.message,
            'message',
            contains('unknown set identifier: Z'),
          ),
        ),
      );
    });

    test('rejects union with single identifier', () {
      const singleUnion = '''
venn-beta
  set A
  union A
''';
      expect(
        () => renderMermaid(singleUnion),
        throwsA(
          isA<PeleError>().having(
            (e) => e.message,
            'message',
            contains('union requires multiple identifiers'),
          ),
        ),
      );
    });
  });
}

import 'package:pele_dart/pele_dart.dart';
import 'package:pele_dart/src/diagrams/treemap/format.dart';
import 'package:test/test.dart';

void main() {
  group('treemap diagram', () {
    const basicTreemap = '''
treemap-beta
  title Budget Breakdown
  accTitle: Annual Budget
  accDescr: Hierarchical breakdown of company budget
  classDef highlight fill:#ffcc00,stroke:#333,font-weight:bold;
  "Engineering"
    "Frontend": 45000:::highlight
    "Backend": 55000
    "Infrastructure"
      "Cloud": 25000
      "CI/CD": 10000
  "Operations"
    "Support", 20000
    "Admin": 15000
''';

    test('renders in SvgOutputMode.cssVariables via renderMermaid', () {
      final svg = renderMermaid(
        basicTreemap,
        options: const RenderOptions(outputMode: SvgOutputMode.cssVariables),
      );
      expect(svg, startsWith('<svg '));
      expect(svg, contains('class="pele pele-treemap"'));
      expect(svg, contains('Budget Breakdown'));
      expect(svg, contains('Annual Budget'));
      expect(svg, contains('class="pele-sections"'));
      expect(svg, contains('class="pele-leaves"'));
      expect(svg, contains('class="pele-node pele-leaf highlight"'));
      expect(svg, contains('45,000'));
      expect(svg, contains('55,000'));
      expect(svg, contains('var(--_fg)'));
    });

    test('renders in SvgOutputMode.flattened via renderMermaid', () {
      final svg = renderMermaid(
        basicTreemap,
        options: const RenderOptions(outputMode: SvgOutputMode.flattened),
      );
      expect(svg, startsWith('<svg '));
      expect(svg, contains('class="pele pele-treemap"'));
      expect(svg, isNot(contains('var(--')));
      expect(svg, isNot(contains('color-mix(')));
      expect(svg, contains('Budget Breakdown'));
      expect(svg, contains('Engineering'));
      expect(svg, contains('45,000'));
    });

    test('formatter formats d3-format specifiers accurately', () {
      expect(formatter(',')(1234567), '1,234,567');
      expect(formatter(r'$0,0')(12345), r'$12,345');
      expect(formatter('+.2f')(12.3), '+12.30');
      expect(formatter('.1%')(0.256), '25.6%');
      expect(formatter('d')(42.6), '43');
      expect(formatter('.2~f')(12.30), '12.3');
    });

    test('respects valueFormat and showValues config options', () {
      const configuredTreemap = r'''
---
config:
  treemap:
    valueFormat: "$0,0"
---
treemap
  "Products"
    "SaaS": 12500
    "Enterprise": 87500
''';
      final svg = renderMermaid(
        configuredTreemap,
        options: const RenderOptions(outputMode: SvgOutputMode.cssVariables),
      );
      expect(svg, contains(r'$12,500'));
      expect(svg, contains(r'$87,500'));
    });
  });
}

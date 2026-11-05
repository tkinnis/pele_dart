import 'package:pele_dart/pele_dart.dart';
import 'package:test/test.dart';

void main() {
  group('ER Diagram (erDiagram)', () {
    test('renders entities, attributes, keys, comments, and cardinalities in cssVariables and flattened modes', () {
      const source = '''---
title: E-Commerce Schema
---
erDiagram
  accTitle: ER Schema Title
  accDescr: ER Schema Description
  CUSTOMER ||--o{ ORDER : places
  ORDER ||--|{ LINE-ITEM : contains
  CUSTOMER }|..|{ DELIVERY-ADDRESS : uses
  CUSTOMER {
    string name
    string custNumber PK
    string sector "Customer business sector"
  }
  ORDER {
    int orderNumber PK
    string deliveryAddress
    List~string~ tags
    string? notes FK, UK "Optional notes"
  }
''';

      final cssRes = render(
        source,
        const RenderOptions(outputMode: SvgOutputMode.cssVariables),
      );
      expect(cssRes.type, 'er');
      expect(cssRes.mermaidType, 'er');
      expect(cssRes.width, greaterThan(100));
      expect(cssRes.height, greaterThan(100));
      expect(cssRes.svg, contains('class="pele pele-er"'));
      expect(cssRes.svg, contains('var(--_fg)'));
      expect(cssRes.svg, contains('E-Commerce Schema'));
      expect(
        cssRes.svg,
        contains('<title id="pele-title">ER Schema Title</title>'),
      );
      expect(
        cssRes.svg,
        contains('<desc id="pele-desc">ER Schema Description</desc>'),
      );
      expect(cssRes.svg, contains('CUSTOMER'));
      expect(cssRes.svg, contains('ORDER'));
      expect(cssRes.svg, contains('custNumber'));
      expect(cssRes.svg, contains('List&lt;string&gt;'));
      expect(cssRes.svg, contains('pele-er-identifying'));
      expect(cssRes.svg, contains('pele-er-non-identifying'));

      final flatRes = render(
        source,
        const RenderOptions(outputMode: SvgOutputMode.flattened),
      );
      expect(flatRes.type, 'er');
      expect(flatRes.svg, isNot(contains('var(--')));
      expect(flatRes.svg, isNot(contains('color-mix(')));
      expect(flatRes.svg, contains('E-Commerce Schema'));
      expect(flatRes.svg, contains('CUSTOMER'));
      expect(flatRes.svg, contains('ORDER'));
    });

    test('supports aliases, word cardinalities, subgraphs, styles, classes, and self-loops', () {
      const source = '''
erDiagram
  direction LR
  accDescr {
    Multiline description
    for ER diagram
  }
  subgraph Core [Core Domain]
    direction LR
    p["Person Entity"]:::highlight {
      int id PK
      `varchar(255)` email UK
    }
    c[Company]
  end
  p one or more to zero or one c : "works for"
  p 1+ .. 0+ p : manages
  c many(0) optionally to many(1) p : employs
  classDef highlight fill:#f9f,stroke:#333,color:#111;
  style c fill:#bbf,stroke:#222
''';

      final cssRes = render(
        source,
        const RenderOptions(
          outputMode: SvgOutputMode.cssVariables,
          monospace: <String>['attributes'],
        ),
      );
      expect(cssRes.svg, contains('Core Domain'));
      expect(cssRes.svg, contains('Person Entity'));
      expect(cssRes.svg, contains('Company'));
      expect(cssRes.svg, contains('pele-cluster'));
      expect(cssRes.svg, contains('works for'));
      expect(cssRes.svg, contains('manages'));

      final flatRes = render(
        source,
        const RenderOptions(
          outputMode: SvgOutputMode.flattened,
          monospace: <String>['attributes'],
        ),
      );
      expect(flatRes.svg, isNot(contains('var(--')));
      expect(flatRes.svg, isNot(contains('color-mix(')));
    });

    test('supports internal-link class and extracts LinkInfo', () {
      const source = '''
erDiagram
  USER:::internal-link ||--o{ POST : writes
''';
      final res = render(source);
      expect(res.links, hasLength(1));
      expect(res.links.first.id, 'USER');
      expect(res.links.first.href, 'USER');
      expect(res.links.first.internal, isTrue);
      expect(res.svg, contains('class="internal-link"'));
    });

    test('throws PeleError on invalid syntax', () {
      expect(
        () => render('erDiagram\n  CUSTOMER ||--'),
        throwsA(isA<PeleError>()),
      );
    });
  });
}

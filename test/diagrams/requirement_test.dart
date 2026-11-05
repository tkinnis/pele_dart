import 'package:pele_dart/pele_dart.dart';
import 'package:test/test.dart';

void main() {
  group('Requirement Diagram (requirementDiagram)', () {
    test('renders requirements, elements, and relationships in cssVariables and flattened modes', () {
      const source = '''---
title: System Requirements
---
requirementDiagram
  accTitle: System Requirements Title
  accDescr: System Requirements Description

  requirement test_req {
    id: 1
    text: the test text.
    risk: high
    verifymethod: test
  }

  functionalRequirement test_req2 {
    id: 1.1
    text: the second test text.
    risk: low
    verifymethod: inspection
  }

  performanceRequirement test_req3 {
    id: 1.2
    text: the third test text.
    risk: medium
    verifymethod: demonstration
  }

  interfaceRequirement test_req4 {
    id: 1.2.1
    text: the fourth test text.
    risk: medium
    verifymethod: analysis
  }

  physicalRequirement test_req5 {
    id: 1.2.2
    text: the fifth test text.
    risk: low
    verifymethod: test
  }

  designConstraint test_req6 {
    id: 1.2.3
    text: the sixth test text.
    risk: medium
    verifymethod: analysis
  }

  element test_entity {
    type: simulation
  }

  element test_entity2 {
    type: word doc
    docRef: reqs/test_entity
  }

  element test_entity3 {
    type: "test suite"
    docRef: github.com/all_the_tests
  }

  test_entity - satisfies -> test_req2
  test_req - traces -> test_req2
  test_req - contains -> test_req3
  test_req3 <- contains - test_req4
  test_req4 - derives -> test_req5
  test_req5 - refines -> test_req6
  test_entity3 - verifies -> test_req5
  test_req <- copies - test_entity2
''';

      final cssRes = render(
        source,
        const RenderOptions(outputMode: SvgOutputMode.cssVariables),
      );
      expect(cssRes.type, 'requirement');
      expect(cssRes.mermaidType, 'requirement');
      expect(cssRes.width, greaterThan(100));
      expect(cssRes.height, greaterThan(100));
      expect(cssRes.svg, contains('class="pele pele-requirement"'));
      expect(cssRes.svg, contains('var(--_fg)'));
      expect(cssRes.svg, contains('System Requirements'));
      expect(
        cssRes.svg,
        contains('<title id="pele-title">System Requirements Title</title>'),
      );
      expect(
        cssRes.svg,
        contains('<desc id="pele-desc">System Requirements Description</desc>'),
      );
      expect(cssRes.svg, contains('«Requirement»'));
      expect(cssRes.svg, contains('«Functional Requirement»'));
      expect(cssRes.svg, contains('«Performance Requirement»'));
      expect(cssRes.svg, contains('«Interface Requirement»'));
      expect(cssRes.svg, contains('«Physical Requirement»'));
      expect(cssRes.svg, contains('«Design Constraint»'));
      expect(cssRes.svg, contains('«Element»'));
      expect(cssRes.svg, contains('pele-relationship-contains'));
      expect(cssRes.svg, contains('pele-relationship-arrow'));
      expect(cssRes.svg, contains('«satisfies»'));
      expect(cssRes.svg, contains('«contains»'));

      final flatRes = render(
        source,
        const RenderOptions(outputMode: SvgOutputMode.flattened),
      );
      expect(flatRes.type, 'requirement');
      expect(flatRes.svg, isNot(contains('var(--')));
      expect(flatRes.svg, isNot(contains('color-mix(')));
      expect(flatRes.svg, contains('System Requirements'));
      expect(flatRes.svg, contains('«Requirement»'));
      expect(flatRes.svg, contains('test_req'));
    });

    test('supports directions, classes, styles, multiline accDescr, and self-loops', () {
      const source = '''
requirementDiagram
  accDescr {
    Multiline requirement description
  }
  direction LR

  requirement "Core Req":::critical {
    id: "REQ-01"
    text: "Must support self-loop and styling"
    risk: High
    verifymethod: Test
  }

  element "Test Suite" {
    type: "Automated"
    docRef: "tests/core"
  }

  "Core Req" - contains -> "Core Req"
  "Test Suite" - verifies -> "Core Req"

  classDef critical fill:#fee,stroke:#c00,color:#900
  style "Test Suite" fill:#eef,stroke:#00c
''';

      final cssRes = render(
        source,
        const RenderOptions(outputMode: SvgOutputMode.cssVariables),
      );
      expect(cssRes.svg, contains('Core Req'));
      expect(cssRes.svg, contains('REQ-01'));
      expect(cssRes.svg, contains('Test Suite'));
      expect(cssRes.svg, contains('critical'));

      final flatRes = render(
        source,
        const RenderOptions(outputMode: SvgOutputMode.flattened),
      );
      expect(flatRes.svg, isNot(contains('var(--')));
      expect(flatRes.svg, isNot(contains('color-mix(')));
    });

    test('throws PeleError on invalid syntax', () {
      expect(
        () => render(
          'requirementDiagram\n  requirement foo {\n    invalid: 1\n  }',
        ),
        throwsA(isA<PeleError>()),
      );
    });
  });
}

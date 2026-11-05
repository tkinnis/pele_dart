import 'package:pele_dart/pele_dart.dart';
import 'package:test/test.dart';

void main() {
  group('cynefin diagram', () {
    const sampleSource = '''cynefin-beta
title Incident Triage Framework
accTitle: Cynefin Triage
accDescr: Categorising operational incidents across Cynefin domains

complex
  "Multi-service cascading latency"
  "Emergent user behavior"
complicated
  "Database index tuning"
  "Capacity planning"
clear
  "Password reset"
  "Standard certificate renewal"
chaotic
  "Active production outage"
confusion
  "Unclassified alert 1"
  "Unclassified alert 2"
  "Unclassified alert 3"
  "Unclassified alert 4"

chaotic --> complex : "Stabilise"
complex --> complicated : "Understand patterns"
complicated --> clear : "Codify runbook"
clear --> chaotic : "Complacency cliff"
confusion --> complex
''';

    test('renders Cynefin domains, boundaries, overflow badge, and transitions in both modes', () {
      final cssRes = render(
        sampleSource,
        const RenderOptions(outputMode: SvgOutputMode.cssVariables),
      );
      expect(cssRes.type, 'cynefin');
      expect(cssRes.mermaidType, 'cynefin');
      expect(cssRes.width, greaterThan(600));
      expect(cssRes.height, greaterThan(400));
      expect(cssRes.svg, contains('class="pele pele-cynefin"'));
      expect(
        cssRes.svg,
        contains('<title id="pele-title">Cynefin Triage</title>'),
      );
      expect(cssRes.svg, contains('Incident Triage Framework'));
      expect(cssRes.svg, contains('pele-cynefin-regions'));
      expect(cssRes.svg, contains('pele-cynefin-boundaries'));
      expect(cssRes.svg, contains('pele-cynefin-cliff'));
      expect(cssRes.svg, contains('pele-cynefin-overflow'));
      expect(cssRes.svg, contains('+1 more'));
      expect(cssRes.svg, contains('Stabilise'));
      expect(cssRes.svg, contains('Complacency cliff'));
      expect(cssRes.svg, contains('var(--_fg)'));

      final flatRes = render(
        sampleSource,
        const RenderOptions(outputMode: SvgOutputMode.flattened),
      );
      expect(flatRes.type, 'cynefin');
      expect(flatRes.svg, isNot(contains('var(--')));
      expect(flatRes.svg, isNot(contains('color-mix(')));
      expect(flatRes.svg, contains('Incident Triage Framework'));
      expect(flatRes.svg, contains('+1 more'));
    });

    test('supports cynefin-beta: header and custom config options', () {
      const src = '''---
config:
  cynefin:
    showDomainDescriptions: false
    boundaryAmplitude: 12
    seed: 42
---
cynefin-beta:
clear
  "Item A"
complex --> clear
complex --> clear : "Second transition"
''';
      final res = render(
        src,
        const RenderOptions(outputMode: SvgOutputMode.flattened),
      );
      expect(res.svg, contains('Item A'));
      expect(res.svg, isNot(contains('Best Practices')));
      expect(res.svg, contains('Second transition'));
      expect(res.svg, isNot(contains('var(--')));
    });
  });
}

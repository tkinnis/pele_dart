import 'package:pele_dart/pele_dart.dart';
import 'package:test/test.dart';

void main() {
  group('wardley diagram', () {
    const sampleSource = '''wardley-beta
title Tea Shop Wardley Map
accTitle: Tea Shop Map
accDescr: Value chain of a tea shop from customer to power
size [1000, 700]
evolution Genesis @ 0.25 -> Custom @ 0.50 / Built -> Product @ 0.75 -> Commodity @ 1.00

anchor Business [0.95, 0.63]
anchor Public [0.95, 0.78]
component Cup of Tea [0.79, 0.61] label [19, -4] (build)
component Cup [0.73, 0.78] (buy)
component Tea [0.63, 0.81] (outsource)
component Hot Water [0.52, 0.80]
component Water [0.38, 0.82] (market)
component Kettle [0.43, 0.35] label [-57, 4] inertia
evolve Kettle 0.62

pipeline Kettle {
  component CampfireKettle [0.35] label [-60, 35]
  component ElectricKettle [0.53]
}

Business -> Cup of Tea
Public +> Cup of Tea ;orders
Cup of Tea --> Cup
Cup of Tea -.-> Tea
Cup of Tea +'\$\$'<> Hot Water
Hot Water -> Water
Hot Water -> Kettle

note "Standardising power allows Kettles to evolve faster" [0.30, 0.49]
annotations [0.12, 0.78]
annotation 1, [0.43, 0.49] "Hot water is obvious and well known"
annotation 2, [0.79, 0.61] "Fierce competition"
accelerator Cloud Adoption [0.70, 0.55]
deaccelerator Legacy Debt [0.25, 0.20]
''';

    test('renders full Wardley map in cssVariables and flattened modes', () {
      final cssRes = render(
        sampleSource,
        const RenderOptions(outputMode: SvgOutputMode.cssVariables),
      );
      expect(cssRes.type, 'wardley');
      expect(cssRes.mermaidType, 'wardley');
      expect(cssRes.width, greaterThan(500));
      expect(cssRes.height, greaterThan(400));
      expect(cssRes.svg, contains('class="pele pele-wardley"'));
      expect(
        cssRes.svg,
        contains('<title id="pele-title">Tea Shop Map</title>'),
      );
      expect(
        cssRes.svg,
        contains(
          '<desc id="pele-desc">Value chain of a tea shop from customer to power</desc>',
        ),
      );
      expect(cssRes.svg, contains('Tea Shop Wardley Map'));
      expect(cssRes.svg, contains('pele-wardley-anchor'));
      expect(cssRes.svg, contains('pele-wardley-pipeline'));
      expect(cssRes.svg, contains('pele-wardley-pipeline-parent'));
      expect(cssRes.svg, contains('pele-wardley-pipeline-component'));
      expect(cssRes.svg, contains('pele-wardley-trend'));
      expect(cssRes.svg, contains('pele-wardley-inertia'));
      expect(cssRes.svg, contains('pele-wardley-build'));
      expect(cssRes.svg, contains('pele-wardley-buy'));
      expect(cssRes.svg, contains('pele-wardley-outsource'));
      expect(cssRes.svg, contains('pele-wardley-market'));
      expect(cssRes.svg, contains('pele-wardley-annotation'));
      expect(cssRes.svg, contains('pele-wardley-annotations'));
      expect(cssRes.svg, contains('pele-wardley-note'));
      expect(cssRes.svg, contains('pele-wardley-accelerator'));
      expect(cssRes.svg, contains('pele-wardley-deaccelerator'));
      expect(cssRes.svg, contains('var(--_fg)'));

      final flatRes = render(
        sampleSource,
        const RenderOptions(outputMode: SvgOutputMode.flattened),
      );
      expect(flatRes.type, 'wardley');
      expect(flatRes.svg, isNot(contains('var(--')));
      expect(flatRes.svg, isNot(contains('color-mix(')));
      expect(flatRes.svg, contains('Tea Shop Wardley Map'));
      expect(flatRes.svg, contains('Custom / Built'));
    });

    test('supports showGrid config and tight maxWidth fitting', () {
      const src = '''---
config:
  wardley-beta:
    showGrid: true
---
wardley-beta
component A [0.80, 0.20] (inertia)
component B [0.30, 0.70]
A +< B
''';
      final res = render(
        src,
        const RenderOptions(maxWidth: 320, outputMode: SvgOutputMode.flattened),
      );
      expect(res.svg, contains('pele-wardley-grid'));
      expect(res.svg, contains('pele-wardley-inertia'));
      expect(res.svg, isNot(contains('var(--')));
    });

    test('throws semantic PeleError for out-of-range coordinates or missing pipeline parent', () {
      expect(
        () => render('wardley-beta\ncomponent A [150.0, 0.5]'),
        throwsA(isA<PeleError>().having((e) => e.code, 'code', 'semantic')),
      );
      expect(
        () =>
            render('wardley-beta\npipeline Unknown {\n  component C [0.5]\n}'),
        throwsA(isA<PeleError>().having((e) => e.code, 'code', 'semantic')),
      );
    });
  });
}

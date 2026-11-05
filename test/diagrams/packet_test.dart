import 'package:pele_dart/pele_dart.dart';
import 'package:test/test.dart';

void main() {
  group('packet diagram', () {
    test(
      'renders bit fields across rows in cssVariables and flattened modes',
      () {
        const src = '''packet-beta
  0-15: "Source Port"
  16-31: "Destination Port"
  32-63: "Sequence Number"''';

        final cssSvg = renderMermaid(
          src,
          options: const RenderOptions(outputMode: SvgOutputMode.cssVariables),
        );
        expect(cssSvg, contains('<svg'));
        expect(cssSvg, contains('Source Port'));
        expect(cssSvg, contains('Destination Port'));

        final flatSvg = renderMermaid(
          src,
          options: const RenderOptions(outputMode: SvgOutputMode.flattened),
        );
        expect(flatSvg, contains('<svg'));
        expect(flatSvg, contains('Sequence Number'));
        expect(flatSvg, isNot(contains('var(--')));
      },
    );
  });
}

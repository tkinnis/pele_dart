import 'package:pele_dart/pele_dart.dart';
import 'package:test/test.dart';

void main() {
  group('ishikawa diagram', () {
    test('renders fishbone causes and subcauses in cssVariables and flattened modes', () {
      const src = '''ishikawa-beta
  Latency Spike
    Database
      Missing Index
    Network
      DNS Lookup''';

      final cssSvg = renderMermaid(
        src,
        options: const RenderOptions(outputMode: SvgOutputMode.cssVariables),
      );
      expect(cssSvg, contains('<svg'));
      expect(cssSvg, contains('Latency Spike'));
      expect(cssSvg, contains('Database'));

      final flatSvg = renderMermaid(
        src,
        options: const RenderOptions(outputMode: SvgOutputMode.flattened),
      );
      expect(flatSvg, contains('<svg'));
      expect(flatSvg, contains('Missing Index'));
      expect(flatSvg, isNot(contains('var(--')));
    });
  });
}

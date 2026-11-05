import 'package:pele_dart/pele_dart.dart';
import 'package:test/test.dart';

void main() {
  group('info diagram', () {
    test('renders info diagram in cssVariables and flattened modes', () {
      const src = '''info
  showInfo''';

      final cssSvg = renderMermaid(
        src,
        options: const RenderOptions(outputMode: SvgOutputMode.cssVariables),
      );
      expect(cssSvg, contains('<svg'));

      final flatSvg = renderMermaid(
        src,
        options: const RenderOptions(outputMode: SvgOutputMode.flattened),
      );
      expect(flatSvg, contains('<svg'));
      expect(flatSvg, isNot(contains('var(--')));
    });
  });
}

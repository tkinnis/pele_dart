import 'package:pele_dart/pele_dart.dart';
import 'package:test/test.dart';

void main() {
  group('block diagram', () {
    test(
      'renders columns, spaces, and edges in cssVariables and flattened modes',
      () {
        const src = '''block-beta
  columns 3
  A["Frontend"] space:1 B["Backend"]
  A --> B''';

        final cssSvg = renderMermaid(
          src,
          options: const RenderOptions(outputMode: SvgOutputMode.cssVariables),
        );
        expect(cssSvg, contains('<svg'));
        expect(cssSvg, contains('Frontend'));
        expect(cssSvg, contains('Backend'));
        expect(cssSvg, contains('var(--'));

        final flatSvg = renderMermaid(
          src,
          options: const RenderOptions(outputMode: SvgOutputMode.flattened),
        );
        expect(flatSvg, contains('<svg'));
        expect(flatSvg, contains('Frontend'));
        expect(flatSvg, isNot(contains('var(--')));
        expect(flatSvg, isNot(contains('color-mix(')));
      },
    );
  });
}

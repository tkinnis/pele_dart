import 'package:pele_dart/pele_dart.dart';
import 'package:test/test.dart';

void main() {
  group('kanban diagram', () {
    test(
      'renders columns and task cards in cssVariables and flattened modes',
      () {
        const src = '''kanban
  Todo
    [Design Parser]
  Done
    [Ship Layout]''';

        final cssSvg = renderMermaid(
          src,
          options: const RenderOptions(outputMode: SvgOutputMode.cssVariables),
        );
        expect(cssSvg, contains('<svg'));
        expect(cssSvg, contains('Todo'));
        expect(cssSvg, contains('Design Parser'));

        final flatSvg = renderMermaid(
          src,
          options: const RenderOptions(outputMode: SvgOutputMode.flattened),
        );
        expect(flatSvg, contains('<svg'));
        expect(flatSvg, contains('Ship Layout'));
        expect(flatSvg, isNot(contains('var(--')));
      },
    );
  });
}

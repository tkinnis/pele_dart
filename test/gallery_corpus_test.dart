import 'package:pele_dart/pele_dart.dart';
import 'package:test/test.dart';

// ignore: avoid_relative_lib_imports
import '../example/lib/gallery_samples.dart';

void main() {
  group('Official pele.run/examples and pele.run/playground corpus', () {
    test('contains all 33 diagram families, 167 playground samples, and 58 showcase diagrams', () {
      expect(gallerySamples.length, 33);
      final playgroundCount = gallerySamples.fold<int>(
        0,
        (sum, s) => sum + s.playgroundSamples.length,
      );
      final showcaseCount = gallerySamples.fold<int>(
        0,
        (sum, s) => sum + s.showcaseSources.length,
      );
      expect(playgroundCount, 172);
      expect(showcaseCount, 60);
      expect(render(playgroundDefaultSource).svg, contains('<svg'));
    });

    for (final family in gallerySamples) {
      test(
        '${family.id} renders all ${family.playgroundSamples.length} playground and ${family.showcaseSources.length} showcase samples',
        () {
          expect(family.playgroundSamples.length, greaterThanOrEqualTo(3));
          for (final sample in family.playgroundSamples) {
            final cssRes = render(sample.source);
            expect(
              cssRes.svg,
              contains('<svg'),
              reason: '${family.id}: ${sample.label}',
            );
            final flatSvg = flattenPeleSvg(
              cssRes.svg,
              palette: PelePalette.light,
            );
            expect(
              flatSvg,
              contains('<svg'),
              reason: '${family.id} flattened: ${sample.label}',
            );
            expect(flatSvg, isNot(contains('var(--')));
            expect(flatSvg, isNot(contains('color-mix(')));
          }
          for (var i = 0; i < family.showcaseSources.length; i++) {
            final cssRes = render(family.showcaseSources[i]);
            expect(
              cssRes.svg,
              contains('<svg'),
              reason: '${family.id} showcase #$i',
            );
          }
        },
      );
    }
  });
}

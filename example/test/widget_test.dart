import 'package:flutter_test/flutter_test.dart';
import 'package:pele_dart/pele_dart.dart';
import 'package:pele_dart_comparison_demo/engine_runner.dart';
import 'package:pele_dart_comparison_demo/gallery_samples.dart';
import 'package:pele_dart_comparison_demo/svg_diff_view.dart';

void main() {
  test(
    'Gallery contains all 33 Mermaid diagram families with official pele.run corpus',
    () {
      expect(gallerySamples.length, 33);
      final ids = gallerySamples.map((s) => s.id).toSet();
      expect(ids.length, 33);

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
      expect(playgroundDefaultSource, contains('flowchart TD'));

      for (final family in gallerySamples) {
        expect(family.playgroundSamples.length, greaterThanOrEqualTo(3));
        for (final sample in family.playgroundSamples) {
          final out = renderWithPeleDart(sample.source, isDark: false);
          expect(
            out.error,
            isNull,
            reason: '${family.id}: ${sample.label} error: ${out.error}',
          );
          expect(out.flattenedSvg, contains('<svg'));
          expect(
            out.compiledVectorBytes,
            isNotNull,
            reason:
                '${family.id}: ${sample.label} failed vector_graphics_compiler',
          );
        }
      }
    },
  );

  test('timedRender computes median p50 across budgeted iterations', () {
    final timed = timedRender<String>(
      () => renderMermaid(playgroundDefaultSource),
      maxRuns: 7,
      budgetMs: 60.0,
    );
    expect(timed.result, contains('<svg'));
    expect(timed.runs, greaterThanOrEqualTo(1));
    expect(timed.runs, lessThanOrEqualTo(7));
    expect(timed.medianMs, greaterThanOrEqualTo(timed.minMs));
  });

  test('prettyPrintSvg formats compact SVG into indented multi-line XML', () {
    final svg = renderMermaid('info\n  showInfo');
    final formatted = prettyPrintSvg(svg);
    expect(formatted, contains('<svg'));
    expect(formatted.split('\n').length, greaterThan(3));
  });
}

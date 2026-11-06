import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pele_dart/pele_dart.dart';
import 'package:pele_dart_comparison_demo/engine_runner.dart';
import 'package:pele_dart_comparison_demo/gallery_samples.dart';
import 'package:pele_dart_comparison_demo/main.dart';
import 'package:pele_dart_comparison_demo/svg_diff_view.dart';

final RegExp _textTagWithTspanRe = RegExp(r'<text\b([^>]*)>([\s\S]*?)<\/text>');

void _assertAllTspanTextsHaveParentXY(String flattenedSvg, String label) {
  for (final m in _textTagWithTspanRe.allMatches(flattenedSvg)) {
    final attrs = m.group(1)!;
    final inner = m.group(2)!;
    if (!inner.contains('<tspan')) continue;
    expect(
      attrs,
      contains(' x="'),
      reason: '$label had <text> with <tspan> missing parent x attribute',
    );
    expect(
      attrs,
      contains(' y="'),
      reason: '$label had <text> with <tspan> missing parent y attribute',
    );
    expect(
      inner,
      isNot(contains(' dy="')),
      reason: '$label had unflattened dy attribute on <tspan>',
    );
  }
}

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
          expect(out.flattenedSvg, contains('font-family="Helvetica"'));
          expect(
            out.compiledVectorBytes,
            isNotNull,
            reason:
                '${family.id}: ${sample.label} failed vector_graphics_compiler',
          );
          _assertAllTspanTextsHaveParentXY(
            out.flattenedSvg,
            '${family.id}: ${sample.label}',
          );
        }
        for (var i = 0; i < family.showcaseSources.length; i++) {
          final out = renderWithPeleDart(
            family.showcaseSources[i],
            isDark: true,
          );
          expect(
            out.error,
            isNull,
            reason: '${family.id} showcase #$i error: ${out.error}',
          );
          expect(
            out.compiledVectorBytes,
            isNotNull,
            reason: '${family.id} showcase #$i failed vector_graphics_compiler',
          );
          _assertAllTspanTextsHaveParentXY(
            out.flattenedSvg,
            '${family.id} showcase #$i',
          );
        }
      }

      final css = formatPaletteToCss(PelePalette.dark, selector: 'body, .pele');
      expect(css, contains('--pele-font: Helvetica,Arial,sans-serif;'));
      expect(
        css,
        contains('--pele-font-mono: Menlo,Monaco,Consolas,monospace;'),
      );
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
    expect(formatted.split('\n').length, greaterThanOrEqualTo(3));
  });

  test(
    'flattenPeleSvg and vector_graphics_compiler compile multi-span bold, italic, code, sub, and sup labels without unpositioned dy or missing parent x/y',
    () {
      const formattedFlowchart = '''flowchart LR
  A["**Bold** and *italic* and `code`"] --> B["H<sub>2</sub>O and E=mc<sup>2</sup>"]''';
      final out = renderWithPeleDart(formattedFlowchart, isDark: true);
      expect(out.error, isNull);
      expect(out.compiledVectorBytes, isNotNull);
      _assertAllTspanTextsHaveParentXY(out.flattenedSvg, 'formattedFlowchart');
    },
  );

  testWidgets(
    'ComparisonStudioScreen supports keyboard navigation across diagrams and folders',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const PeleDartComparisonApp());
      await tester.pump();

      final totalDiagrams = gallerySamples.fold<int>(
        0,
        (sum, s) => sum + s.playgroundSamples.length,
      );
      expect(find.text('1/$totalDiagrams ↑↓'), findsOneWidget);

      // ArrowDown advances to the 2nd diagram in the first folder
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(find.text('2/$totalDiagrams ↑↓'), findsOneWidget);

      // ArrowRight advances to the 3rd diagram
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(find.text('3/$totalDiagrams ↑↓'), findsOneWidget);

      // ArrowUp steps back to the 2nd diagram
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(find.text('2/$totalDiagrams ↑↓'), findsOneWidget);

      // Digit 4 selects the 4th sub-sample in the active folder
      await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
      await tester.pump();
      expect(find.text('4/$totalDiagrams ↑↓'), findsOneWidget);

      // BracketRight (']') jumps to the next diagram family (folder)
      final firstFamilyCount = gallerySamples.first.playgroundSamples.length;
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
      await tester.pump();
      expect(
        find.text('${firstFamilyCount + 1}/$totalDiagrams ↑↓'),
        findsOneWidget,
      );

      // End jumps to the last diagram, Home jumps back to the first diagram
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(find.text('$totalDiagrams/$totalDiagrams ↑↓'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(find.text('1/$totalDiagrams ↑↓'), findsOneWidget);
    },
  );
}

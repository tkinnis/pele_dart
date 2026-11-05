import 'dart:convert';
import 'dart:io';

import 'package:pele_dart/pele_dart.dart';
import 'package:test/test.dart';

// ignore: avoid_relative_lib_imports
import '../example/lib/gallery_samples.dart';

void main() {
  group('Official pele.run/examples and pele.run/playground corpus', () {
    test('contains all 33 diagram families, 172 playground samples, and 60 showcase diagrams', () {
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

    test('dynamically discovers new .mmd and .mermaid files added to subfolders', () {
      final originalDir = resolveDiagramsRootDir();
      final tempRoot = Directory.systemTemp.createTempSync(
        'pele_gallery_test_',
      );
      try {
        final customSub = Directory('${tempRoot.path}/03_custom/my_feature')
          ..createSync(recursive: true);
        File('${customSub.path}/01_flow.mmd')
            .writeAsStringSync('flowchart LR\n  A[Start] --> B[End]\n');
        File('${customSub.path}/02_seq.mermaid').writeAsStringSync(
          '%% label: Custom Sequence\nsequenceDiagram\n  Alice->>Bob: Hello\n',
        );

        final scanned = reloadGallerySamples(rootDir: tempRoot);
        expect(scanned.length, 1);
        expect(scanned.first.title, 'My feature');
        expect(scanned.first.playgroundSamples.length, 2);
        expect(scanned.first.playgroundSamples[0].fileName, '01_flow.mmd');
        expect(scanned.first.playgroundSamples[0].label, '01 flow');
        expect(scanned.first.playgroundSamples[1].fileName, '02_seq.mermaid');
        expect(scanned.first.playgroundSamples[1].label, 'Custom Sequence');
        expect(
          render(scanned.first.playgroundSamples[0].source).svg,
          contains('<svg'),
        );
        expect(
          render(scanned.first.playgroundSamples[1].source).svg,
          contains('<svg'),
        );
      } finally {
        reloadGallerySamples(rootDir: originalDir);
        if (tempRoot.existsSync()) {
          tempRoot.deleteSync(recursive: true);
        }
      }
    });

    test('flattenPeleSvg resolves upstream SERIES palette and root CSS variables identically in light and dark modes', () {
      const expectedSeries = <String>[
        '#4c78a8',
        '#f58518',
        '#54a24b',
        '#e45756',
        '#72b7b2',
        '#eeca3b',
        '#b279a2',
        '#9d755d',
      ];
      expect(PelePalette.light.colors, equals(expectedSeries));
      expect(PelePalette.dark.colors, equals(expectedSeries));

      final journeyRes = render(
        'journey\n  title My working day\n  section Go to work\n    Make tea: 5: Me\n    Do work: 1: Me, Cat',
        const RenderOptions(outputMode: SvgOutputMode.cssVariables),
      );
      final flatLight = flattenPeleSvg(
        journeyRes.svg,
        palette: PelePalette.light,
      );
      final flatDark = flattenPeleSvg(
        journeyRes.svg,
        palette: PelePalette.dark,
      );
      expect(flatLight, contains('fill="#4c78a8"'));
      expect(flatLight, contains('fill="#f58518"'));
      expect(flatDark, contains('fill="#4c78a8"'));
      expect(flatDark, contains('fill="#f58518"'));
      expect(flatDark, contains('font-weight="bold"'));
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
            for (final palette in <PelePalette>[
              PelePalette.light,
              PelePalette.dark,
            ]) {
              final flatSvg = flattenPeleSvg(cssRes.svg, palette: palette);
              expect(
                flatSvg,
                contains('<svg'),
                reason: '${family.id} flattened: ${sample.label}',
              );
              expect(flatSvg, isNot(contains('var(--')));
              expect(flatSvg, isNot(contains('color-mix(')));
              expect(flatSvg, isNot(contains('currentColor')));
            }
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

    test('all 172 playground samples and 60 showcase diagrams match upstream obsidianmd/pele byte-for-byte', () async {
      final upstreamDir = Directory('${Directory.current.path}/.upstream');
      final bunFile = File('/opt/homebrew/bin/bun');
      if (!upstreamDir.existsSync() || !bunFile.existsSync()) {
        return;
      }
      final corpus = <String, String>{};
      for (final family in gallerySamples) {
        for (var i = 0; i < family.playgroundSamples.length; i++) {
          corpus['${family.id}:playground:${i + 1}'] =
              family.playgroundSamples[i].source;
        }
        for (var i = 0; i < family.showcaseSources.length; i++) {
          corpus['${family.id}:showcase:${i + 1}'] = family.showcaseSources[i];
        }
      }
      final tmpFile = File(
        '${Directory.systemTemp.path}/pele_test_232_corpus.json',
      );
      tmpFile.writeAsStringSync(jsonEncode(corpus));
      try {
        final bunRes = await Process.run(bunFile.path, <String>[
          '-e',
          '''
import { render } from './src/index.ts';
import fs from 'node:fs';
const items = JSON.parse(fs.readFileSync('${tmpFile.path}', 'utf8'));
const out = {};
for (const [k, src] of Object.entries(items)) {
  out[k] = render(src, { now: '2026-10-01T00:00:00Z' }).svg;
}
console.log(JSON.stringify(out));
''',
        ], workingDirectory: upstreamDir.path);
        expect(bunRes.exitCode, 0, reason: '${bunRes.stderr}');
        final upstreamMap = jsonDecode(
          (bunRes.stdout as String).trim(),
        ) as Map<String, dynamic>;
        for (final entry in corpus.entries) {
          final dartSvg = render(
            entry.value,
            const RenderOptions(
              outputMode: SvgOutputMode.cssVariables,
              now: '2026-10-01T00:00:00Z',
            ),
          ).svg;
          expect(
            dartSvg,
            equals(upstreamMap[entry.key]),
            reason: 'Upstream SVG mismatch in ${entry.key}',
          );
        }
      } finally {
        if (tmpFile.existsSync()) {
          tmpFile.deleteSync();
        }
      }
    });
  });
}

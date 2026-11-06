import 'dart:convert';
import 'dart:io';

import 'package:pele_dart/pele_dart.dart';

// ignore: avoid_relative_lib_imports
import '../studio/lib/gallery_samples.dart';

/// Verifies `pele_dart` structural header mappings against `UPSTREAM.md` and `.upstream/`,
/// and runs differential and flattened-SVG verification across registered diagrams.
Future<void> main(List<String> args) async {
  final root = Directory.current.path;
  final upstreamMd = File('$root/UPSTREAM.md');
  if (!upstreamMd.existsSync()) {
    stderr.writeln('Error: UPSTREAM.md not found in $root');
    exitCode = 1;
    return;
  }

  final md = upstreamMd.readAsStringSync();
  final pinnedRelease = RegExp(
    r'\*\*(?:Target Release|Pinned Upstream Tag)\*\*\s*\|\s*`([^`]+)`',
  ).firstMatch(md)?.group(1);
  if (pinnedRelease == null) {
    stderr.writeln('Error: Missing Target Release in UPSTREAM.md');
    exitCode = 1;
    return;
  }
  final pinnedSha = RegExp(
    r'\*\*(?:Target Commit SHA|Pinned Upstream Commit)\*\*\s*\|\s*`([^`]+)`',
  ).firstMatch(md)?.group(1);
  if (pinnedSha == null) {
    stderr.writeln('Error: Missing Target Commit SHA in UPSTREAM.md');
    exitCode = 1;
    return;
  }

  // Enforce 1:1 version lockstep between UPSTREAM.md (Target Release: vX.Y.Z),
  // pubspec.yaml (version: X.Y.Z or X.Y.Z+N), and CHANGELOG.md (## X.Y.Z or ## X.Y.Z+N).
  final pubspecFile = File('$root/pubspec.yaml');
  final pubspecVer = RegExp(
    r'^version:\s*(\S+)',
    multiLine: true,
  ).firstMatch(pubspecFile.readAsStringSync())?.group(1);
  final expectedBaseVer = pinnedRelease.replaceFirst(RegExp(r'^v'), '');
  final actualBaseVer = pubspecVer?.split('+').first;
  if (pubspecVer == null || actualBaseVer != expectedBaseVer) {
    stderr.writeln(
      'Error: pubspec.yaml version ($pubspecVer) is not in 1:1 lockstep with UPSTREAM.md Target Release ($pinnedRelease; expected $expectedBaseVer or $expectedBaseVer+<hotfix>)',
    );
    exitCode = 1;
    return;
  }
  final changelogFile = File('$root/CHANGELOG.md');
  final topChangelogVer = RegExp(
    r'^##\s+(\S+)',
    multiLine: true,
  ).firstMatch(changelogFile.readAsStringSync())?.group(1);
  if (topChangelogVer != pubspecVer) {
    stderr.writeln(
      'Error: CHANGELOG.md top entry ($topChangelogVer) does not match pubspec.yaml version ($pubspecVer)',
    );
    exitCode = 1;
    return;
  }
  final infoRenderFile = File('$root/lib/src/diagrams/info/render.dart');
  final infoRenderVer = RegExp(r"const String peleVersion = '([^']+)';")
      .firstMatch(infoRenderFile.readAsStringSync())
      ?.group(1);
  if (infoRenderVer != expectedBaseVer) {
    stderr.writeln(
      'Error: peleVersion ($infoRenderVer) in lib/src/diagrams/info/render.dart does not match UPSTREAM.md Target Release ($expectedBaseVer)',
    );
    exitCode = 1;
    return;
  }

  final upstreamDir = Directory('$root/.upstream');
  if (upstreamDir.existsSync()) {
    final head = await Process.run('git', <String>[
      'rev-parse',
      'HEAD',
    ], workingDirectory: upstreamDir.path);
    final actualSha = (head.stdout as String).trim();
    if (actualSha != pinnedSha) {
      stderr.writeln(
        'Error: .upstream HEAD ($actualSha) does not match UPSTREAM.md ($pinnedSha)',
      );
      exitCode = 1;
      return;
    }
  }

  // Enforce 1:1 lockstep between PelePalette.light / const PelePalette() defaults
  // and the CSS variable fallbacks in lib/src/svg/theme.dart (and .upstream/src/svg/theme.ts).
  if (!_verifyDefaultPaletteMatchesThemeFallbacks(root, upstreamDir)) {
    exitCode = 1;
    return;
  }

  // Verify all // Upstream: headers point to real files when .upstream exists.
  final libSrc = Directory('$root/lib/src');
  var verifiedHeaders = 0;
  for (final entity in libSrc.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final lines = entity.readAsLinesSync();
    if (lines.isEmpty) continue;
    final m = RegExp(r'^//\s*Upstream:\s*(\S+)').firstMatch(lines.first);
    if (m != null) {
      verifiedHeaders++;
      final relTs = m.group(1)!;
      if (upstreamDir.existsSync()) {
        final tsFile = File('${upstreamDir.path}/$relTs');
        if (!tsFile.existsSync()) {
          stderr.writeln(
            'Error: ${entity.path} references missing upstream file $relTs',
          );
          exitCode = 1;
          return;
        }
      }
    }
  }

  stdout.writeln('Verified $verifiedHeaders upstream file header mappings.');

  // Verify flattened vs cssVariables output on sample corpus for all supported diagrams.
  var verifiedDiagrams = 0;
  for (final entry in _sampleCorpus.entries) {
    final type = entry.key;
    final source = entry.value;
    try {
      final cssRes = render(
        source,
        const RenderOptions(outputMode: SvgOutputMode.cssVariables),
      );
      final flatRes = render(
        source,
        const RenderOptions(outputMode: SvgOutputMode.flattened),
      );
      if (flatRes.svg.contains('var(--') ||
          flatRes.svg.contains('color-mix(') ||
          flatRes.svg.contains('currentColor') ||
          flatRes.svg.contains('baseline-shift=')) {
        stderr.writeln(
          'Error: Flattened SVG for $type still contains unflattened CSS constructs!',
        );
        exitCode = 1;
        return;
      }
      if (cssRes.width != flatRes.width || cssRes.height != flatRes.height) {
        stderr.writeln(
          'Error: Dimension mismatch between cssVariables and flattened for $type',
        );
        exitCode = 1;
        return;
      }
      verifiedDiagrams++;
    } on PeleError catch (e) {
      if (e.code == 'unsupported-diagram') {
        continue;
      }
      stderr.writeln('Error rendering $type: $e');
      exitCode = 1;
      return;
    }
  }

  // Optional differential check against .upstream/src/index.ts if bun is available.
  var exactUpstreamMatches = 0;
  var exactGalleryMatches = 0;
  var exactCorpusMatches = 0;
  final galleryCorpus = <String, String>{};
  for (final family in gallerySamples) {
    for (var i = 0; i < family.playgroundSamples.length; i++) {
      galleryCorpus['${family.id}:playground:${i + 1}'] =
          family.playgroundSamples[i].source;
    }
    for (var i = 0; i < family.showcaseSources.length; i++) {
      galleryCorpus['${family.id}:showcase:${i + 1}'] =
          family.showcaseSources[i];
    }
  }

  for (final entry in galleryCorpus.entries) {
    final cssRes = render(
      entry.value,
      const RenderOptions(outputMode: SvgOutputMode.cssVariables),
    );
    for (final palette in <PelePalette>[PelePalette.light, PelePalette.dark]) {
      final flatSvg = flattenPeleSvg(cssRes.svg, palette: palette);
      if (flatSvg.contains('var(--') ||
          flatSvg.contains('color-mix(') ||
          flatSvg.contains('currentColor') ||
          flatSvg.contains('baseline-shift=') ||
          flatSvg.contains('font- ')) {
        stderr.writeln(
          'Error: Flattened gallery SVG for ${entry.key} contains unflattened CSS!',
        );
        exitCode = 1;
        return;
      }
    }
  }

  // Load upstream tests/corpus/*.json (522 diagrams) when .upstream exists.
  final upstreamJsonCorpus = <String, String>{};
  final corpusDir = Directory('${upstreamDir.path}/tests/corpus');
  if (corpusDir.existsSync()) {
    final files =
        corpusDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is List) {
        for (var i = 0; i < decoded.length; i++) {
          final item = decoded[i];
          if (item is String) {
            upstreamJsonCorpus['corpus:$name#$i'] = item;
          } else if (item is Map && item['code'] is String) {
            upstreamJsonCorpus['corpus:$name#$i'] = item['code'] as String;
          } else if (item is Map && item['source'] is String) {
            upstreamJsonCorpus['corpus:$name#$i'] = item['source'] as String;
          }
        }
      }
    }
  }

  // Verify Mermaid version alignment across UPSTREAM.md and studio/lib/engine_runner.dart.
  final pinnedMermaidVer = RegExp(
    r'\*\*Target Mermaid Version\*\*\s*\|\s*`([^`]+)`',
  ).firstMatch(md)?.group(1);
  final engineRunnerFile = File('$root/studio/lib/engine_runner.dart');
  if (pinnedMermaidVer != null && engineRunnerFile.existsSync()) {
    final runnerText = engineRunnerFile.readAsStringSync();
    final uiMermaidVer = RegExp(r'mermaid\.js \(v([^)]+)\)')
        .firstMatch(runnerText)
        ?.group(1);
    if (uiMermaidVer != null && uiMermaidVer != pinnedMermaidVer) {
      stderr.writeln(
        'Error: Studio UI Mermaid label (v$uiMermaidVer) does not match UPSTREAM.md Target Mermaid Version (v$pinnedMermaidVer)',
      );
      exitCode = 1;
    }
  }

  final bunFile = File('/opt/homebrew/bin/bun');
  if (upstreamDir.existsSync() && bunFile.existsSync()) {
    final combined = <String, String>{
      ..._sampleCorpus,
      ...galleryCorpus,
      ...upstreamJsonCorpus,
    };
    final tmpPayloadFile = File(
      '${Directory.systemTemp.path}/pele_verify_corpus.json',
    );
    tmpPayloadFile.writeAsStringSync(jsonEncode(combined));
    final jsCode =
        '''
import { render } from './src/index.ts';
import fs from 'node:fs';
const corpus = JSON.parse(fs.readFileSync('${tmpPayloadFile.path}', 'utf8'));
const out = {};
for (const [k, src] of Object.entries(corpus)) {
  try {
    const r = render(src, { now: '2026-10-01T00:00:00Z' });
    out[k] = { svg: r.svg, width: r.width, height: r.height };
  } catch (e) {
    out[k] = { error: String(e?.code ?? e?.message ?? e) };
  }
}
console.log(JSON.stringify(out));
''';
    final bunRes = await Process.run(bunFile.path, <String>[
      '-e',
      jsCode,
    ], workingDirectory: upstreamDir.path);
    if (tmpPayloadFile.existsSync()) {
      tmpPayloadFile.deleteSync();
    }
    if (bunRes.exitCode == 0) {
      final upstreamMap =
          jsonDecode((bunRes.stdout as String).trim()) as Map<String, dynamic>;
      for (final entry in _sampleCorpus.entries) {
        final type = entry.key;
        final dartRes = render(
          entry.value,
          const RenderOptions(
            outputMode: SvgOutputMode.cssVariables,
            now: '2026-10-01T00:00:00Z',
          ),
        );
        final up = upstreamMap[type] as Map<String, dynamic>?;
        if (up != null && up['svg'] == dartRes.svg) {
          exactUpstreamMatches++;
        } else {
          stderr.writeln(
            'Diff in canonical $type: dart(${dartRes.width}x${dartRes.height}, ${dartRes.svg.length}B) vs upstream(${up?['width']}x${up?['height']}, ${(up?['svg'] as String?)?.length}B)',
          );
          exitCode = 1;
        }
      }
      for (final entry in galleryCorpus.entries) {
        final key = entry.key;
        final dartRes = render(
          entry.value,
          const RenderOptions(
            outputMode: SvgOutputMode.cssVariables,
            now: '2026-10-01T00:00:00Z',
          ),
        );
        final up = upstreamMap[key] as Map<String, dynamic>?;
        if (up != null && up['svg'] == dartRes.svg) {
          exactGalleryMatches++;
        } else {
          stderr.writeln(
            'Diff in gallery $key: dart(${dartRes.width}x${dartRes.height}, ${dartRes.svg.length}B) vs upstream(${up?['width']}x${up?['height']}, ${(up?['svg'] as String?)?.length}B)',
          );
          exitCode = 1;
        }
      }
      for (final entry in upstreamJsonCorpus.entries) {
        final key = entry.key;
        final up = upstreamMap[key] as Map<String, dynamic>?;
        try {
          final dartRes = render(
            entry.value,
            const RenderOptions(
              outputMode: SvgOutputMode.cssVariables,
              now: '2026-10-01T00:00:00Z',
            ),
          );
          if (up != null && up['svg'] == dartRes.svg) {
            exactCorpusMatches++;
          } else {
            stderr.writeln('Diff in upstream corpus $key');
            exitCode = 1;
          }
        } on PeleError catch (e) {
          if (up != null && up['error'] == e.code) {
            exactCorpusMatches++;
          } else {
            stderr.writeln(
              'Error mismatch in upstream corpus $key: dart(${e.code}) vs upstream(${up?['error']})',
            );
            exitCode = 1;
          }
        }
      }
    }
  }

  stdout.writeln(
    jsonEncode(<String, Object?>{
      'packageVersion': pubspecVer,
      'pinnedRelease': pinnedRelease,
      'versionLockstep': true,
      'pinnedCommit': pinnedSha,
      'targetMermaidVersion': pinnedMermaidVer,
      'verifiedHeaders': verifiedHeaders,
      'verifiedDiagrams': verifiedDiagrams,
      'exactUpstreamMatches': exactUpstreamMatches,
      'exactGalleryMatches': exactGalleryMatches,
      'totalGallerySamples': galleryCorpus.length,
      'exactCorpusMatches': exactCorpusMatches,
      'totalCorpusSamples': upstreamJsonCorpus.length,
      'status': exitCode == 0 ? 'ok' : 'failed',
    }),
  );
}

const Map<String, String> _sampleCorpus = <String, String>{
  'info': 'info\n  showInfo',
  'pie': 'pie title Pets\n  "Dogs" : 42\n  "Cats" : 58',
  'flowchart': 'flowchart TD\n  A[Start] --> B{Decision}\n  B -->|Yes| C[Done]',
  'sequence': 'sequenceDiagram\n  Alice->>Bob: Hello Bob!\n  Bob-->>Alice: Hi!',
  'class': 'classDiagram\n  Animal <|-- Duck\n  Animal : +int age',
  'state': 'stateDiagram-v2\n  [*] --> Still\n  Still --> [*]',
  'er': 'erDiagram\n  CUSTOMER ||--o{ ORDER : places',
  'gantt': 'gantt\n  title A Gantt\n  dateFormat YYYY-MM-DD\n  section S\n  Task :a1, 2024-01-01, 3d',
  'gitGraph': 'gitGraph\n  commit\n  branch dev\n  checkout dev\n  commit',
  'mindmap': 'mindmap\n  root((mindmap))\n    Origins\n    Research',
  'timeline': 'timeline\n  title History\n  2024 : Launch\n  2026 : Pure Dart',
  'journey':
      'journey\n  title Working Day\n  section Go to work\n    Make tea: 5: Me',
  'quadrantChart': 'quadrantChart\n  title Reach and engagement\n  x-axis Low --> High\n  y-axis Low --> High\n  Campaign A: [0.3, 0.6]',
  'xychart': 'xychart-beta\n  title "Sales"\n  x-axis [jan, feb, mar]\n  y-axis "Revenue" 0 --> 100\n  bar [30, 60, 90]',
  'requirement': 'requirementDiagram\n  requirement test_req {\n    id: 1\n    text: the test text.\n    risk: high\n    verifymethod: test\n  }',
  'c4': 'C4Context\n  Person(user, "User", "A user")\n  System(sys, "System", "Core")\n  Rel(user, sys, "Uses")',
  'sankey': 'sankey-beta\n  Source,Target,25',
  'kanban': 'kanban\n  Todo\n    [Task 1]\n  Done\n    [Task 2]',
  'packet': 'packet-beta\n  0-15: "Source Port"\n  16-31: "Dest Port"',
  'block': 'block-beta\n  columns 2\n  A B\n  A --> B',
  'architecture': 'architecture-beta\n  service api(server)[API]\n  service db(database)[DB]\n  api:R --> L:db',
  'radar': 'radar-beta\n  axis A, B, C\n  curve c1{10, 20, 30}',
  'treemap': 'treemap-beta\n"Root"\n  "Leaf A": 10\n  "Leaf B": 20',
  'railroad': 'railroad-ebnf-beta\n  Rule = "a" ("b" | "c") ;',
  'agentflow': 'agentflow-beta TB\n  a["Agent A"] --> b["Agent B"]',
  'treeView': 'treeView-beta\n  "root"\n    "src"\n      "main.dart"',
  'cynefin': 'cynefin-beta\n  clear\n    "Item 1"\n  complicated\n    "Item 2"\n  complex\n    "Item 3"\n  chaotic\n    "Item 4"',
  'wardley': 'wardley-beta\n  component App [0.8, 0.6]\n  component Engine [0.4, 0.7]\n  App -> Engine',
  'eventmodeling':
      'eventmodeling\n  tf 01 cmd CreateOrder\n  tf 02 evt OrderCreated ->> 01',
  'usecase': 'usecase-beta\n  actor User\n  User --> Login',
  'venn':
      'venn-beta\n  set A["Set A"]\n  set B["Set B"]\n  union A,B["Overlap"]',
  'ishikawa': 'ishikawa-beta\n  Defect\n    People\n      Training\n    Process\n      Steps',
  'swimlane': 'swimlane-beta\n  subgraph Lane1\n    A --> B\n  end',
};

String _expandHex(String raw) {
  final s = raw.trim().toLowerCase();
  if (s.length == 4 && s.startsWith('#')) {
    return '#${s[1]}${s[1]}${s[2]}${s[2]}${s[3]}${s[3]}';
  }
  return s;
}

bool _verifyDefaultPaletteMatchesThemeFallbacks(
  String root,
  Directory upstreamDir,
) {
  final sources = <(String label, String content)>[
    (
      'lib/src/svg/theme.dart',
      File('$root/lib/src/svg/theme.dart').readAsStringSync(),
    ),
  ];
  final upstreamThemeTs = File('${upstreamDir.path}/src/svg/theme.ts');
  if (upstreamThemeTs.existsSync()) {
    sources.add((
      '.upstream/src/svg/theme.ts',
      upstreamThemeTs.readAsStringSync(),
    ));
  }

  const light = PelePalette.light;
  const baseDefault = PelePalette();
  final varRe = RegExp(r'var\((--pele-[a-z0-9-]+),([^)]+)\)');
  final seriesArrayRe = RegExp(r'SERIES\s*=\s*\[([^\]]+)\]');
  final hexLitRe = RegExp(r"'#[0-9a-fA-F]+'");

  for (final (label, text) in sources) {
    final fallbacks = <String, String>{};
    for (final m in varRe.allMatches(text)) {
      fallbacks[m.group(1)!.trim()] = m.group(2)!.trim();
    }

    final seriesMatch = seriesArrayRe.firstMatch(text);
    if (seriesMatch != null) {
      final colors = hexLitRe
          .allMatches(seriesMatch.group(1)!)
          .map((m) => m.group(0)!.replaceAll("'", ''))
          .toList();
      for (var i = 0; i < colors.length; i++) {
        fallbacks['--pele-series-${i + 1}'] = colors[i];
      }
    }

    final expectedChecks = <(String token, String actual, String? expected)>[
      (
        '--pele-bg',
        _expandHex(light.bg),
        _expandHex(fallbacks['--pele-bg'] ?? ''),
      ),
      (
        '--pele-bg (ctor)',
        _expandHex(baseDefault.bg),
        _expandHex(fallbacks['--pele-bg'] ?? ''),
      ),
      (
        '--pele-fg',
        _expandHex(light.fg),
        _expandHex(fallbacks['--pele-fg'] ?? ''),
      ),
      (
        '--pele-fg (ctor)',
        _expandHex(baseDefault.fg),
        _expandHex(fallbacks['--pele-fg'] ?? ''),
      ),
      (
        '--pele-muted',
        _expandHex(light.muted ?? ''),
        _expandHex(fallbacks['--pele-muted'] ?? ''),
      ),
      (
        '--pele-line',
        _expandHex(light.line ?? ''),
        _expandHex(fallbacks['--pele-line'] ?? ''),
      ),
      (
        '--pele-surface',
        _expandHex(light.surface ?? ''),
        _expandHex(fallbacks['--pele-surface'] ?? ''),
      ),
      (
        '--pele-surface-alt',
        _expandHex(light.surfaceAlt),
        _expandHex(fallbacks['--pele-surface-alt'] ?? ''),
      ),
      (
        '--pele-surface-alt (ctor)',
        _expandHex(baseDefault.surfaceAlt),
        _expandHex(fallbacks['--pele-surface-alt'] ?? ''),
      ),
      (
        '--pele-border',
        _expandHex(light.border ?? ''),
        _expandHex(fallbacks['--pele-border'] ?? ''),
      ),
      (
        '--pele-accent',
        _expandHex(light.accent ?? ''),
        _expandHex(fallbacks['--pele-accent'] ?? ''),
      ),
      (
        '--pele-critical',
        _expandHex(light.critical),
        _expandHex(fallbacks['--pele-critical'] ?? ''),
      ),
      (
        '--pele-critical (ctor)',
        _expandHex(baseDefault.critical),
        _expandHex(fallbacks['--pele-critical'] ?? ''),
      ),
      (
        '--pele-radius',
        '${light.radius.toInt()}px',
        fallbacks['--pele-radius'],
      ),
      (
        '--pele-radius (ctor)',
        '${baseDefault.radius.toInt()}px',
        fallbacks['--pele-radius'],
      ),
      for (var i = 0; i < 8; i++)
        (
          '--pele-series-${i + 1}',
          _expandHex(light.colors[i]),
          _expandHex(fallbacks['--pele-series-${i + 1}'] ?? ''),
        ),
    ];

    for (final (token, actual, expected) in expectedChecks) {
      if (expected == null || expected.isEmpty || actual != expected) {
        stderr.writeln(
          'Error: PelePalette.light $token ($actual) does not match $label fallback ($expected)',
        );
        return false;
      }
    }
  }
  return true;
}

import 'dart:io';
import 'dart:typed_data';

import 'package:pele_dart/pele_dart.dart';
import 'package:test/test.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart'
    show encodeSvg;

class CustomTextMeasurer implements TextMeasurer {
  const CustomTextMeasurer();

  @override
  double width(String text, double size, [int style = 0]) {
    final bool isMono = (style & Style.mono) != 0;
    final bool isBold = (style & Style.bold) != 0;
    final double factor = isMono ? 0.60 : (isBold ? 0.58 : 0.55);
    return text.length * size * factor;
  }
}

void main() {
  group('Documentation Code Examples & Claims Verification', () {
    test('README.md Quick Start 1-4 code examples compile and execute', () {
      // 1. Render a Mermaid Diagram to Flattened SVG
      const source = '''
flowchart LR
  A[Start] --> B{Decision}
  B -->|Yes| C[Ship It]
  B -->|No| D[Revise]
''';

      final RenderResult result = render(
        source,
        const RenderOptions(
          outputMode: SvgOutputMode.flattened,
          palette: PelePalette.light,
        ),
      );
      expect(result.type, 'flowchart');
      expect(result.mermaidType, 'flowchart-v2');
      expect(result.width, greaterThan(0));
      expect(result.height, greaterThan(0));
      expect(result.svg, startsWith('<svg'));

      // 2. Two-Phase Parse & Re-Render
      final model = parse(
        'sequenceDiagram\n  Alice->>Bob: Ping\n  Bob-->>Alice: Pong',
      );
      final lightSvg = render(
        model,
        const RenderOptions(palette: PelePalette.light),
      ).svg;
      final darkSvg = render(
        model,
        const RenderOptions(palette: PelePalette.dark),
      ).svg;
      expect(lightSvg, isNot(equals(darkSvg)));

      // 3. Detection & Error Handling (PeleError)
      expect(supports(source), isTrue);
      expect(
        () => render('flowchart LR\n  A -->'),
        throwsA(
          isA<PeleError>()
              .having((e) => e.code, 'code', 'syntax')
              .having((e) => e.line, 'line', 2)
              .having((e) => e.column, 'column', greaterThan(0))
              .having((e) => e.snippet, 'snippet', contains('^')),
        ),
      );

      // 4. Flutter vector_graphics_compiler Integration
      for (final isDark in <bool>[false, true]) {
        final vgResult = render(
          source,
          RenderOptions(
            outputMode: SvgOutputMode.flattened,
            palette: isDark ? PelePalette.dark : PelePalette.light,
          ),
        );
        final Uint8List vectorBytes = encodeSvg(
          xml: vgResult.svg,
          debugName: 'mermaid_${vgResult.type}',
          enableClippingOptimizer: false,
          enableMaskingOptimizer: false,
          enableOverdrawOptimizer: false,
        );
        expect(vectorBytes, isNotEmpty);
      }
    });

    test('docs/API_MANUAL.md code examples compile and execute', () {
      const source = '''
flowchart LR
  A[Client] -->|HTTPS| B(Load Balancer)
  B --> C{Healthy?}
  C -->|Yes| D[(Primary DB)]
  C -->|No| E[(Replica DB)]
''';

      // Section 2: Quick Start
      final RenderResult result = render(
        source,
        const RenderOptions(
          outputMode: SvgOutputMode.flattened,
          palette: PelePalette.light,
        ),
      );
      expect(result.type, 'flowchart');
      expect(result.mermaidType, 'flowchart-v2');

      final String oneLinerSvg = renderMermaid(
        'sequenceDiagram\n  Alice->>Bob: Hello!',
        options: const RenderOptions(palette: PelePalette.dark),
      );
      expect(oneLinerSvg, startsWith('<svg'));

      // Section 3: Core API Functions
      expect(detectType('graph TD\n  A --> B'), 'flowchart');
      expect(supports(source), isTrue);
      expect(registered('flowchart'), isTrue);
      forgetTextWidths();

      final cssVarSvg = render(
        source,
        const RenderOptions(outputMode: SvgOutputMode.cssVariables),
      ).svg;
      final manuallyFlattened = flattenPeleSvg(
        cssVarSvg,
        palette: PelePalette.light,
      );
      expect(manuallyFlattened, equals(result.svg));

      // Section 5.2: Supplying Your Own Custom PelePalette
      const myCustomPalette = PelePalette(
        bg: '#1e1e2e',
        fg: '#cdd6f4',
        muted: '#a6adc8',
        line: '#bac2de',
        surface: '#313244',
        surfaceAlt: '#45475a',
        border: '#585b70',
        accent: '#89b4fa',
        code: '#cdd6f4',
        critical: '#f38ba8',
        fgOnLight: '#1e1e2e',
        fgOnDark: '#cdd6f4',
        radius: 8,
        strokeWidth: 1.25,
        thickStrokeWidth: 2.5,
        hairlineStrokeWidth: 0.5,
        fontFamily: 'Inter, -apple-system, BlinkMacSystemFont, sans-serif',
        monoFontFamily: 'JetBrains Mono, SFMono-Regular, Menlo, monospace',
        colors: <String>[
          '#89b4fa',
          '#fab387',
          '#a6e3a1',
          '#f38ba8',
          '#94e2d5',
          '#f9e2af',
          '#cba6f7',
          '#f5c2e7',
        ],
      );
      final customResult = render(
        source,
        const RenderOptions(
          outputMode: SvgOutputMode.flattened,
          palette: myCustomPalette,
        ),
      );
      expect(customResult.svg, contains('#1e1e2e'));

      // Section 9: Custom TextMeasurer, IconResolver, MathResolver
      final measuredResult = render(
        source,
        const RenderOptions(measurer: CustomTextMeasurer()),
      );
      expect(measuredResult.width, greaterThan(0));

      final iconResult = render(
        'mindmap\n  root\n    Node\n      ::icon(custom:cloud)',
        RenderOptions(
          icons: (String name) {
            if (name == 'custom:cloud') {
              return '<path d="M18 10h-1.26A8 8 0 1 0 9 20h9a5 5 0 0 0 0-10z"/>';
            }
            return null;
          },
        ),
      );
      expect(
        iconResult.svg,
        contains('M18 10h-1.26A8 8 0 1 0 9 20h9a5 5 0 0 0 0-10z'),
      );

      final mathResult = render(
        'flowchart LR\n  A["\$\$E = mc^2\$\$"] --> B["\$\$\\nabla \\cdot \\mathbf{E}\$\$"]',
        RenderOptions(
          math: (String tex, double fontSize) {
            return MathMarkup.svg(
              svg:
                  '<svg viewBox="0 0 60 20"><text x="0" y="15">$tex</text></svg>',
              width: 60,
              height: 20,
            );
          },
        ),
      );
      expect(mathResult.svg, contains('E = mc^2'));
    });

    test('All documented PelePalette & RenderOptions defaults match implementation', () {
      const opts = RenderOptions();
      expect(opts.outputMode, SvgOutputMode.flattened);
      expect(opts.palette, PelePalette.light);
      expect(PelePalette.light.bg, '#ffffff');
      expect(PelePalette.light.fg, '#24292e');
      expect(PelePalette.light.surfaceAlt, '#e6e6e6');
      expect(PelePalette.light.critical, '#e45756');
      expect(PelePalette.light.radius, 6);
      expect(PelePalette.light.strokeWidth, 1.25);
      expect(PelePalette.light.thickStrokeWidth, 2.5);
      expect(PelePalette.light.hairlineStrokeWidth, 0.5);
      expect(PelePalette.light.colors, <String>[
        '#4c78a8',
        '#f58518',
        '#54a24b',
        '#e45756',
        '#72b7b2',
        '#eeca3b',
        '#b279a2',
        '#9d755d',
      ]);

      expect(PelePalette.dark.bg, '#1e1e1e');
      expect(PelePalette.dark.fg, '#e1e4e8');
      expect(PelePalette.dark.surfaceAlt, '#3f3f46');
      expect(PelePalette.dark.critical, '#f87171');

      // Verify linkSchemes ('http', 'https', 'mailto', 'tel') and linkRel ('noopener')
      final linkedRes = render(
        'flowchart LR\n  A[Call]\n  click A "tel:+15551234567"',
      );
      expect(linkedRes.links, hasLength(1));
      expect(linkedRes.links.first.href, 'tel:+15551234567');
      expect(linkedRes.svg, contains('rel="noopener"'));

      // Verify all 4 MonospacePart values ('members', 'attributes', 'files', 'messages')
      final monoClass = render(
        'classDiagram\n  class Foo {\n    +bar() void\n  }',
        const RenderOptions(
          outputMode: SvgOutputMode.cssVariables,
          monospace: <MonospacePart>[
            'members',
            'attributes',
            'files',
            'messages',
          ],
        ),
      );
      expect(monoClass.svg, contains('font-family="var(--_fm)"'));
    });

    test('All 33 diagram families and header keywords in README.md and API_MANUAL.md Section 10 detect accurately', () {
      const expectedHeaders = <(String header, DiagramType type)>[
        ('flowchart LR\n  A-->B', 'flowchart'),
        ('graph TD\n  A-->B', 'flowchart'),
        ('flowchart-elk LR\n  A-->B', 'flowchart'),
        ('sequenceDiagram\n  A->>B: hi', 'sequence'),
        ('classDiagram\n  class A', 'class'),
        ('stateDiagram\n  [*] --> A', 'state'),
        ('stateDiagram-v2\n  [*] --> A', 'state'),
        ('erDiagram\n  A ||--o{ B : has', 'er'),
        ('gantt\n  section S\n  T :2026-01-01, 1d', 'gantt'),
        ('pie\n  "A" : 1', 'pie'),
        ('mindmap\n  root', 'mindmap'),
        ('timeline\n  2026 : Launch', 'timeline'),
        ('gitGraph\n  commit', 'gitGraph'),
        ('journey\n  section S\n  T: 5: Me', 'journey'),
        ('quadrantChart\n  A: [0.5, 0.5]', 'quadrantChart'),
        ('xychart\n  line [1, 2]', 'xychart'),
        ('xychart-beta\n  line [1, 2]', 'xychart'),
        ('sankey\nA,B,10', 'sankey'),
        ('sankey-beta\nA,B,10', 'sankey'),
        ('requirementDiagram\n  requirement r {\n id: 1\n}', 'requirement'),
        ('requirement\n  requirement r {\n id: 1\n}', 'requirement'),
        ('C4Context\n  Person(a, "A")', 'c4'),
        ('C4Container\n  Person(a, "A")', 'c4'),
        ('C4Component\n  Person(a, "A")', 'c4'),
        ('C4Dynamic\n  Person(a, "A")', 'c4'),
        ('C4Deployment\n  Person(a, "A")', 'c4'),
        ('kanban\n  Todo\n    Task', 'kanban'),
        ('block\n  A', 'block'),
        ('block-beta\n  A', 'block'),
        ('packet\n  0-7: "A"', 'packet'),
        ('packet-beta\n  0-7: "A"', 'packet'),
        ('architecture\n  service db(database)[DB]', 'architecture'),
        ('architecture-beta\n  service db(database)[DB]', 'architecture'),
        ('treemap\n"Root"\n  "A": 10', 'treemap'),
        ('treemap-beta\n"Root"\n  "A": 10', 'treemap'),
        ('radar-beta\n  axis A, B, C\n  curve c{1, 2, 3}', 'radar'),
        ('treeView-beta\n  "root"', 'treeView'),
        ('info', 'info'),
        ('agentflow-beta\n  agent A["Agent"]', 'agentflow'),
        ('ishikawa\n  Problem\n    Cause', 'ishikawa'),
        ('ishikawa-beta\n  Problem\n    Cause', 'ishikawa'),
        ('venn-beta\n  set A', 'venn'),
        ('wardley-beta\n  component A [0.5, 0.5]', 'wardley'),
        ('cynefin-beta\n  clear\n    Item', 'cynefin'),
        ('railroad-beta\n  Terminal("a")', 'railroad'),
        ('railroad-ebnf-beta\n  r = "a";', 'railroad'),
        ('railroad-abnf-beta\n  r = "a"', 'railroad'),
        ('railroad-peg-beta\n  r <- "a"', 'railroad'),
        ('swimlane-beta\n  lanes: A\n  A: [Step]', 'swimlane'),
        ('usecase-beta\n  actor U\n  (Login)', 'usecase'),
        ('eventmodeling\n  evt E', 'eventmodeling'),
      ];

      final seenTypes = <DiagramType>{};
      for (final (src, expectedType) in expectedHeaders) {
        expect(
          detectType(src),
          expectedType,
          reason: 'Header detection failed for: $src',
        );
        expect(supports(src), isTrue);
        seenTypes.add(expectedType);
      }
      expect(seenTypes.length, 33);
    });

    test(
      'Every ```mermaid code block in README.md and docs/*.md renders cleanly',
      () {
        final docFiles = <String>[
          'README.md',
          'docs/API_MANUAL.md',
          'docs/DESIGN.md',
          'docs/DIAGRAM_GALLERY.md',
        ];
        final fenceRe = RegExp(r'```mermaid\n([\s\S]*?)```');
        var totalBlocks = 0;

        for (final relPath in docFiles) {
          final file = File(relPath);
          expect(file.existsSync(), isTrue, reason: 'Missing $relPath');
          final content = file.readAsStringSync();
          for (final match in fenceRe.allMatches(content)) {
            final diagramSource = match.group(1)!;
            final result = render(diagramSource);
            expect(
              result.svg,
              startsWith('<svg'),
              reason: 'Failed rendering mermaid block in $relPath',
            );
            totalBlocks++;
          }
        }
        expect(totalBlocks, greaterThanOrEqualTo(35));
      },
    );

    test('Package version in pubspec.yaml, CHANGELOG.md, README.md, and docs/API_MANUAL.md is in 1:1 lockstep with UPSTREAM.md', () {
      final upstreamMd = File('UPSTREAM.md').readAsStringSync();
      final targetRelease = RegExp(r'\*\*Target Release\*\*\s*\|\s*`([^`]+)`')
          .firstMatch(upstreamMd)
          ?.group(1);
      expect(targetRelease, isNotNull);
      final expectedBaseVersion = targetRelease!.replaceFirst(
        RegExp(r'^v'),
        '',
      );

      final pubspecYaml = File('pubspec.yaml').readAsStringSync();
      final pubspecVersion = RegExp(
        r'^version:\s*(\S+)',
        multiLine: true,
      ).firstMatch(pubspecYaml)?.group(1);
      expect(pubspecVersion, isNotNull);
      expect(
        pubspecVersion!.split('+').first,
        expectedBaseVersion,
        reason:
            'pubspec.yaml version ($pubspecVersion) must match UPSTREAM.md Target Release ($targetRelease)',
      );

      final changelog = File('CHANGELOG.md').readAsStringSync();
      final topChangelogVersion = RegExp(
        r'^##\s+(\S+)',
        multiLine: true,
      ).firstMatch(changelog)?.group(1);
      expect(
        topChangelogVersion,
        pubspecVersion,
        reason:
            'CHANGELOG.md top version ($topChangelogVersion) must match pubspec.yaml ($pubspecVersion)',
      );

      final readme = File('README.md').readAsStringSync();
      expect(readme, contains('pele_dart: ^$expectedBaseVersion'));
      expect(readme, contains('`obsidianmd/pele` (`v$expectedBaseVersion`)'));

      final apiManual = File('docs/API_MANUAL.md').readAsStringSync();
      expect(apiManual, contains('pele_dart: ^$expectedBaseVersion'));
      expect(
        apiManual,
        contains('`obsidianmd/pele` (`v$expectedBaseVersion`)'),
      );
    });

    test('Every relative file link and image path in markdown docs resolves to an existing file', () {
      final mdFiles = <String>[
        'README.md',
        'CHANGELOG.md',
        'CONTRIBUTING.md',
        'CODE_OF_CONDUCT.md',
        'SECURITY.md',
        'AGENTS.md',
        'UPSTREAM.md',
        'example/README.md',
        'docs/API_MANUAL.md',
        'docs/DIAGRAM_GALLERY.md',
        'docs/UPSTREAM_SYNC.md',
        'docs/DESIGN.md',
      ];
      final linkRe = RegExp(r'!?\[[^\]]*\]\(([^)]+)\)');

      for (final mdRelPath in mdFiles) {
        final mdFile = File(mdRelPath);
        expect(mdFile.existsSync(), isTrue, reason: 'Missing $mdRelPath');
        final text = mdFile.readAsStringSync();
        final baseDir = mdFile.parent.path;

        for (final m in linkRe.allMatches(text)) {
          final rawTarget = m.group(1)!.trim();
          if (rawTarget.startsWith('http://') ||
              rawTarget.startsWith('https://') ||
              rawTarget.startsWith('mailto:') ||
              rawTarget.startsWith('#')) {
            continue;
          }
          final pathPart = rawTarget.split('#').first;
          if (pathPart.isEmpty) continue;
          final resolvedPath = '$baseDir/$pathPart';
          final exists =
              File(resolvedPath).existsSync() ||
              Directory(resolvedPath).existsSync();
          expect(
            exists,
            isTrue,
            reason:
                'Broken relative link "$rawTarget" in $mdRelPath (resolved to $resolvedPath)',
          );
        }
      }
    });
  });
}

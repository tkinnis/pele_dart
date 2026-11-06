import 'dart:convert';
import 'dart:io';

import 'package:pele_dart/pele_dart.dart';

// ignore: avoid_relative_lib_imports
import '../studio/lib/gallery_samples.dart';

/// Generates clean, standalone SVG images of:
///   1. All Mermaid diagram families rendered by `pele_dart` (`doc/images/diagrams/<id>.svg`)
///   2. 9 themed/styled diagram renders (`doc/images/styles/style_<name>.svg`)
///   3. The visual catalog document (`doc/DIAGRAM_GALLERY.md`)
///
/// Each SVG is a pure `pele_dart` diagram render (zero host-app chrome) wrapped
/// with an explicit background `<rect>` matching its [PelePalette.bg] so it
/// renders cleanly on both light and dark Markdown viewers.
void main(List<String> args) {
  final root = Directory.current.path;
  final diagramsDir = Directory('$root/doc/images/diagrams')
    ..createSync(recursive: true);
  final stylesDir = Directory('$root/doc/images/styles')
    ..createSync(recursive: true);

  stdout.writeln(
    '═══════════════════════════════════════════════════════════\n'
    '  pele_dart Standalone Diagram & Style Image Generator\n'
    '═══════════════════════════════════════════════════════════',
  );

  // 1. Render all diagram families into doc/images/diagrams/<id>.svg
  var diagramCount = 0;
  final galleryMd = StringBuffer()
    ..writeln('# `pele_dart` Visual Diagram Gallery')
    ..writeln()
    ..writeln(
      'Every image below is rendered directly by **`pele_dart`**—a 1:1 pure-Dart port '
      'of [**`obsidianmd/pele`**](https://github.com/obsidianmd/pele) ([`pele.run`](https://pele.run))—using '
      '`SvgOutputMode.flattened` with zero browser or JavaScript runtime.',
    )
    ..writeln()
    ..writeln('> Regenerate this gallery at any time with:')
    ..writeln('> ```bash')
    ..writeln('> dart run tool/generate_doc_images.dart')
    ..writeln('> ```')
    ..writeln()
    ..writeln('## Quick Jump')
    ..writeln();

  for (final sample in gallerySamples) {
    final anchor = sample.title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
    galleryMd.writeln(
      '- [**${sample.title}** (`${sample.diagramType}`)](#$anchor) — ${sample.description}',
    );
  }
  galleryMd.writeln('\n---\n');

  for (final sample in gallerySamples) {
    final source = sample.playgroundSamples.isNotEmpty
        ? sample.playgroundSamples.first.source
        : sample.source;
    final result = render(
      source,
      RenderOptions(
        outputMode: SvgOutputMode.flattened,
        palette: PelePalette.light,
        now: DateTime.utc(2026, 1, 15),
      ),
    );
    final standaloneSvg = _injectStandaloneBackground(
      result.svg,
      bg: PelePalette.light.bg,
      border: '#d8dee4',
    );
    final outFile = File('${diagramsDir.path}/${sample.id}.svg');
    outFile.writeAsStringSync('$standaloneSvg\n');
    diagramCount++;

    final w = result.width.round();
    final h = result.height.round();
    galleryMd
      ..writeln('## ${sample.title}')
      ..writeln()
      ..writeln(
        '**Type:** `${result.type}` (`${result.mermaidType}`) · '
        '**Intrinsic Size:** `$w×$h px` · '
        '${sample.description}',
      )
      ..writeln()
      ..writeln('![${sample.title}](images/diagrams/${sample.id}.svg)')
      ..writeln()
      ..writeln('<details>')
      ..writeln('<summary>View Mermaid Source</summary>')
      ..writeln()
      ..writeln('```mermaid')
      ..writeln(source.trim())
      ..writeln('```')
      ..writeln('</details>')
      ..writeln()
      ..writeln('---')
      ..writeln();
  }

  File('$root/doc/DIAGRAM_GALLERY.md').writeAsStringSync(galleryMd.toString());
  stdout.writeln(
    '✓ Rendered $diagramCount/${gallerySamples.length} standalone diagram images in doc/images/diagrams/\n'
    '✓ Generated doc/DIAGRAM_GALLERY.md',
  );

  // 2. Render style comparison images for doc/API_MANUAL.md
  const styleShowcaseSource = '''
flowchart LR
  subgraph Client
    UI([Web App]) --> Cache[(Local Cache)]
  end
  subgraph Services
    API[API Gateway] --> Orders[Order Service]
    API --> Auth{Auth Valid?}
  end
  UI -->|HTTPS| API
  Auth -.->|JWT token| UI
  Orders --> DB[(Primary DB)]
''';

  const flexokiPalette = PelePalette(
    bg: '#fffcf0',
    fg: '#100f0f',
    muted: '#6f6e69',
    line: '#100f0f',
    surface: '#f2f0e5',
    surfaceAlt: '#e6e4d9',
    border: '#cecdc3',
    accent: '#205ea6',
    critical: '#af3029',
    radius: 4,
    colors: <String>[
      '#205ea6',
      '#bc5215',
      '#66800b',
      '#af3029',
      '#24837b',
      '#ad8301',
      '#5e409d',
      '#a02f6f',
    ],
  );

  const catppuccinMochaPalette = PelePalette(
    bg: '#1e1e2e',
    fg: '#cdd6f4',
    muted: '#a6adc8',
    line: '#bac2de',
    surface: '#313244',
    surfaceAlt: '#45475a',
    border: '#585b70',
    accent: '#89b4fa',
    critical: '#f38ba8',
    radius: 8,
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

  const nordPalette = PelePalette(
    bg: '#2e3440',
    fg: '#eceff4',
    muted: '#d8dee9',
    line: '#e5e9f0',
    surface: '#3b4252',
    surfaceAlt: '#434c5e',
    border: '#4c566a',
    accent: '#88c0d0',
    critical: '#bf616a',
    radius: 5,
    colors: <String>[
      '#81a1c1',
      '#d08770',
      '#a3be8c',
      '#bf616a',
      '#88c0d0',
      '#ebcb8b',
      '#b48ead',
      '#5e81ac',
    ],
  );

  const solarizedDarkPalette = PelePalette(
    bg: '#002b36',
    fg: '#eee8d5',
    muted: '#93a1a1',
    line: '#93a1a1',
    surface: '#073642',
    surfaceAlt: '#0b4654',
    border: '#586e75',
    accent: '#268bd2',
    critical: '#dc322f',
    radius: 4,
    colors: <String>[
      '#268bd2',
      '#cb4b16',
      '#859900',
      '#dc322f',
      '#2aa198',
      '#b58900',
      '#6c71c4',
      '#d33682',
    ],
  );

  final stylePresets = <({String id, String label, PelePalette palette})>[
    (
      id: 'style_light',
      label: 'Default Light (PelePalette.light)',
      palette: PelePalette.light,
    ),
    (
      id: 'style_dark',
      label: 'Default Dark (PelePalette.dark)',
      palette: PelePalette.dark,
    ),
    (
      id: 'style_flexoki',
      label: 'Custom Warm Paper Palette',
      palette: flexokiPalette,
    ),
    (
      id: 'style_catppuccin_mocha',
      label: 'Custom Catppuccin Mocha Palette',
      palette: catppuccinMochaPalette,
    ),
    (
      id: 'style_nord',
      label: 'Custom Nord Blueprint Palette',
      palette: nordPalette,
    ),
    (
      id: 'style_solarized_dark',
      label: 'Custom Solarized Dark Palette',
      palette: solarizedDarkPalette,
    ),
  ];

  for (final preset in stylePresets) {
    final result = render(
      styleShowcaseSource,
      RenderOptions(
        outputMode: SvgOutputMode.flattened,
        palette: preset.palette,
      ),
    );
    final standaloneSvg = _injectStandaloneBackground(
      result.svg,
      bg: preset.palette.bg,
      border: preset.palette.border ?? '#6e7781',
    );
    File('${stylesDir.path}/${preset.id}.svg')
        .writeAsStringSync('$standaloneSvg\n');
  }

  // Also render a categorical series & per-node classDef styled diagram:
  const classDefShowcaseSource = '''
flowchart LR
  A([Ingress]):::entry --> B[Router]:::core
  B --> C[(Analytics DB)]:::storage
  B --> D{Rate Limit Exceeded?}:::warn
  D -->|Block| E[429 Reject]:::danger
  D -->|Pass| C

  classDef entry fill:#dbeafe,stroke:#2563eb,stroke-width:2px,color:#1e3a8a
  classDef core fill:#ede9fe,stroke:#7c3aed,stroke-width:2px,color:#4c1d95
  classDef storage fill:#dcfce7,stroke:#16a34a,stroke-width:2px,color:#14532d
  classDef warn fill:#fef3c7,stroke:#d97706,stroke-width:2px,color:#78350f
  classDef danger fill:#fee2e2,stroke:#dc2626,stroke-width:2px,color:#7f1d1d
''';

  final classDefRes = render(
    classDefShowcaseSource,
    const RenderOptions(
      outputMode: SvgOutputMode.flattened,
      palette: PelePalette.light,
    ),
  );
  File('${stylesDir.path}/style_mermaid_classdef.svg').writeAsStringSync(
    '${_injectStandaloneBackground(classDefRes.svg, bg: PelePalette.light.bg, border: '#d8dee4')}\n',
  );

  // Also render a multi-series chart (Mindmap) in Flexoki vs Catppuccin Mocha to show --pele-series-1..8
  const seriesSource = '''
mindmap
  root((pele_dart))
    Pure Dart
      Zero DOM
      Zero JS Engine
      Synchronous
    Dual SVG Modes
      Flattened Vector
      CSS Variables
    Theming
      PelePalette Presets
      Custom CSS Vars
      Mermaid classDef
''';
  for (final (id, pal) in <(String, PelePalette)>[
    ('style_series_flexoki', flexokiPalette),
    ('style_series_catppuccin', catppuccinMochaPalette),
  ]) {
    final res = render(
      seriesSource,
      RenderOptions(outputMode: SvgOutputMode.flattened, palette: pal),
    );
    File('${stylesDir.path}/$id.svg').writeAsStringSync(
      '${_injectStandaloneBackground(res.svg, bg: pal.bg, border: pal.border ?? '#6e7781')}\n',
    );
  }

  stdout.writeln('✓ Rendered 9 styled showcase images in doc/images/styles/');

  // 3. Emit doc/pele_diagrams.js with SvgOutputMode.cssVariables SVGs for the Docsify portal
  final Map<String, String> galleryCssVarSvgs = <String, String>{};
  for (final sample in gallerySamples) {
    final source = sample.playgroundSamples.isNotEmpty
        ? sample.playgroundSamples.first.source
        : sample.source;
    final cssVarResult = render(
      source,
      RenderOptions(
        outputMode: SvgOutputMode.cssVariables,
        now: DateTime.utc(2026, 1, 15),
      ),
    );
    galleryCssVarSvgs[sample.id] = cssVarResult.svg;
  }

  final Map<String, String> inlineMermaidSvgs = <String, String>{};
  final fenceRe = RegExp(
    r'^```mermaid[ \t]*\r?\n([\s\S]*?)^```[ \t]*$',
    multiLine: true,
  );
  final docMdFiles = <File>[
    File('$root/README.md'),
    ...Directory('$root/doc')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.md')),
  ];
  for (final file in docMdFiles) {
    if (!file.existsSync()) continue;
    final text = file.readAsStringSync();
    for (final match in fenceRe.allMatches(text)) {
      final code = (match.group(1) ?? '').trim();
      if (code.isEmpty || inlineMermaidSvgs.containsKey(code)) continue;
      final res = render(
        code,
        RenderOptions(
          outputMode: SvgOutputMode.cssVariables,
          now: DateTime.utc(2026, 1, 15),
        ),
      );
      inlineMermaidSvgs[code] = res.svg;
    }
  }

  const encoder = JsonEncoder();
  File('$root/doc/pele_diagrams.js').writeAsStringSync(
    '// Generated by tool/generate_doc_images.dart — DO NOT EDIT MANUALLY\n'
    'window.PELE_DART_GALLERY_SVGS = ${encoder.convert(galleryCssVarSvgs)};\n'
    'window.PELE_DART_DIAGRAMS = ${encoder.convert(inlineMermaidSvgs)};\n',
  );
  stdout.writeln(
    '✓ Generated doc/pele_diagrams.js (${galleryCssVarSvgs.length} gallery SVGs, ${inlineMermaidSvgs.length} inline Mermaid SVGs)',
  );
}

/// Inserts a rounded background `<rect>` inside the root `<svg>` element matching
/// the diagram's `viewBox` so the standalone SVG displays with its intended
/// background canvas on any light or dark host page.
String _injectStandaloneBackground(
  String svg, {
  required String bg,
  required String border,
}) {
  final vbMatch = RegExp(
    r'viewBox="([-\d.]+)\s+([-\d.]+)\s+([\d.]+)\s+([\d.]+)"',
  ).firstMatch(svg);
  final openEnd = svg.indexOf('>');
  if (vbMatch == null || openEnd < 0) return svg;

  final x = vbMatch.group(1)!;
  final y = vbMatch.group(2)!;
  final w = vbMatch.group(3)!;
  final h = vbMatch.group(4)!;

  final bgRect =
      '<rect x="$x" y="$y" width="$w" height="$h" rx="8" fill="$bg" stroke="$border" stroke-width="1" stroke-opacity="0.35"/>';
  return '${svg.substring(0, openEnd + 1)}$bgRect${svg.substring(openEnd + 1)}';
}

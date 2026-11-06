# `pele_dart` Example

Run the standalone pure-Dart CLI example from the repository root:

```bash
dart run example/main.dart
```

## Pure-Dart Usage (`example/main.dart`)

```dart
import 'package:pele_dart/pele_dart.dart';

void main() {
  const source = '''
flowchart LR
  A[Mermaid Source] --> B(pele_dart)
  B --> C{SvgOutputMode}
  C -->|flattened| D[Flutter vector_graphics / Static SVG 1.1]
  C -->|cssVariables| E[Web / Themeable --pele-* CSS SVG]
''';

  // 1. Default flattened SVG (ready for vector_graphics_compiler):
  final RenderResult lightResult = render(
    source,
    const RenderOptions(
      outputMode: SvgOutputMode.flattened,
      palette: PelePalette.light,
    ),
  );
  print('Rendered ${lightResult.type} (${lightResult.width}x${lightResult.height})');

  // 2. Supplying a custom PelePalette:
  const customPalette = PelePalette(
    bg: '#1e1e2e',
    fg: '#cdd6f4',
    surface: '#313244',
    surfaceAlt: '#45475a',
    border: '#585b70',
    accent: '#89b4fa',
    radius: 8,
  );
  final String customSvg = renderMermaid(
    source,
    options: const RenderOptions(palette: customPalette),
  );
  print('Custom palette SVG length: ${customSvg.length} chars');

  // 3. Two-phase parse() + render() for fast theme switching:
  final ParsedDiagram parsed = parse(
    'sequenceDiagram\n  Alice->>Bob: Ping\n  Bob-->>Alice: Pong',
  );
  final String darkSeq = render(
    parsed,
    const RenderOptions(palette: PelePalette.dark),
  ).svg;
  print('Parsed ${parsed.type} -> ${darkSeq.length} chars');
}
```

## Additional Guides & macOS Workbench

* **[API User Manual (`docs/API_MANUAL.md`)](https://github.com/tkinnis/pele_dart/blob/main/docs/API_MANUAL.md)** — Complete API reference and Flutter `vector_graphics` widget guide.
* **[Visual Diagram Gallery (`docs/DIAGRAM_GALLERY.md`)](https://github.com/tkinnis/pele_dart/blob/main/docs/DIAGRAM_GALLERY.md)** — Rendered SVG outputs and Mermaid source for all 33 diagram families.
* **[Pele Studio User Guide (`docs/STUDIO_GUIDE.md`)](https://github.com/tkinnis/pele_dart/blob/main/docs/STUDIO_GUIDE.md)** — Native macOS 3-way comparison workbench (`cd studio && flutter run -d macos --release`).

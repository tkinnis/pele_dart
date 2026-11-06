# `pele_dart` Example

Run the standalone pure-Dart CLI example from the repository root:

```bash
dart run example/main.dart
```

## Pure-Dart Usage

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

  // 1. Render to flattened static SVG 1.1 (default) with PelePalette.light:
  final RenderResult result = render(
    source,
    const RenderOptions(
      outputMode: SvgOutputMode.flattened,
      palette: PelePalette.light,
    ),
  );
  print(
    'Rendered ${result.type} (${result.mermaidType}): '
    '${result.width}x${result.height} px (${result.svg.length} chars)',
  );

  // 2. Parse once and re-render across light, dark, and custom palettes:
  final Object model = parse(source);
  final RenderResult darkResult = render(
    model,
    const RenderOptions(palette: PelePalette.dark),
  );
  print('Dark mode SVG: ${darkResult.svg.length} chars');

  const customPalette = PelePalette(
    bg: '#1e1e2e',
    fg: '#cdd6f4',
    surface: '#313244',
    surfaceAlt: '#45475a',
    border: '#585b70',
    accent: '#89b4fa',
    radius: 8,
  );
  final RenderResult customResult = render(
    model,
    const RenderOptions(palette: customPalette),
  );
  print('Custom palette SVG: ${customResult.svg.length} chars');

  // 3. Emit upstream obsidianmd/pele CSS-variable SVG for web/DOM hosts:
  final RenderResult cssVarResult = render(
    model,
    const RenderOptions(outputMode: SvgOutputMode.cssVariables),
  );
  print('CSS-variable SVG: ${cssVarResult.svg.length} chars');

  // 4. Structured error handling with line/column/caret snippet:
  try {
    render('flowchart LR\n  A -->');
  } on PeleError catch (e) {
    print('Caught expected ${e.code} error on line ${e.line}:\n${e.snippet}');
  }
}
```

## Additional Guides & macOS Workbench

* **[API User Manual](../doc/API_MANUAL.md)** — Complete API reference and Flutter `vector_graphics` widget guide.
* **[Visual Diagram Gallery](../doc/DIAGRAM_GALLERY.md)** — Rendered SVG outputs and Mermaid source for all supported diagram families.
* **[Pele Studio User Guide](../doc/STUDIO_GUIDE.md)** — Native macOS 3-way comparison workbench (`cd studio && flutter run -d macos --release`).

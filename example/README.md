# `pele_dart` Examples & macOS 3-Way Comparison Studio

This directory contains:
1. **[`example/main.dart`](main.dart)**: A standalone pure-Dart CLI example showing how to render Mermaid diagrams to flattened SVG (`SvgOutputMode.flattened`) and CSS-variable SVG (`SvgOutputMode.cssVariables`), apply custom [`PelePalette`](../lib/src/types.dart) themes, reuse parsed models with `parse()`, and handle [`PeleError`](../lib/src/errors.dart) exceptions.
2. **macOS 3-Way Comparison Studio (`example/lib/main.dart`)**: An interactive macOS desktop workbench that renders 232+ `.mmd` and `.mermaid` diagrams side-by-side across **`pele_dart` (Pure Dart)**, **`obsidianmd/pele` (JS)**, and **`mermaid.js`**.

---

## 1. Pure-Dart Quick Example (`example/main.dart`)

Run the pure-Dart CLI example from the repository root:

```bash
dart run example/main.dart
```

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
}
```

---

## 2. Launching the macOS 3-Way Comparison Studio

From the `example/` directory:

```bash
cd example
flutter run -d macos
```

### Studio Features

* **3-Engine Side-by-Side Comparison**:
  * **`pele_dart` (Pure Dart)** — rendered natively in Dart.
  * **`obsidianmd/pele` (JS)** — upstream JavaScript reference bundle (`v1.13.0`).
  * **`mermaid.js` (v11.12.0)** — standard Mermaid browser renderer.
* **4 Inspection Modes**:
  1. **Visual Render**: Synchronized pan and zoom across all active engine columns.
  2. **Visual Diff**: Compare any two engines using **Split-Curtain Swipe**, **Cyan/Magenta Channel Overlay**, **Pixel-Diff Heatmap**, or **A/B Blink Toggle**.
  3. **Raw SVG**: Pretty-printed, syntax-readable SVG source for each engine with one-click copy.
  4. **SVG Text Diff**: Line-by-line unified diff between any two engines, plus an **Open in External Diff** launcher (`opendiff`, `code --diff`, `meld`, `ksdiff`).
* **Style Preset Selector & Live `Style (CSS)` Editor**:
  * Switch between example style presets (`Default Dark`, `Default Light`, `Flexoki Paper`, `Catppuccin Mocha`, `Nord Blueprint`, `Solarized Dark`) in the top toolbar.
  * Open the **`Style (CSS)`** tab in the bottom Playground Editor to type in your own `--pele-*` CSS custom properties and preview them live.
* **Dynamic `.mmd` / `.mermaid` Folder Browser (`example/diagrams/`)**:
  * The left sidebar dynamically scans [`example/diagrams/`](diagrams/README.md) (`01_core/<family>/*.mmd`, `02_extended/<family>/*.mmd`, `03_custom/`).
  * Add new `.mmd` or `.mermaid` text files to any folder and click **Rescan (`↻`)** in the sidebar header—or click **Save as `.mmd` (`⬇`)** in the Playground Editor to save your current diagram to `example/diagrams/03_custom/`.

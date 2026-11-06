# Pele Studio (`studio/`)

**Pele Studio** is the native macOS 3-way comparison and visual/SVG diff workbench for [`pele_dart`](../README.md). It renders any Mermaid diagram side-by-side across **`pele_dart` (Pure Dart `vector_graphics`)**, **`obsidianmd/pele` (JS)**, and **`mermaid.js`**, with split-curtain/pixel-heatmap visual diffing, XML markup diffing, and live `--pele-*` CSS theme editing.

## Quick Launch (macOS)

Always run in **Release (`--release`)** mode when comparing rendering speed so `pele_dart` compiles to native Dart AOT machine code:

```bash
cd studio
flutter run -d macos --release
```

## Documentation

* **[Pele Studio User Guide](../doc/STUDIO_GUIDE.md)** — Complete guide to the 4 inspection modes (`Visual Render`, `Visual Diff`, `Raw SVG`, `SVG Text Diff`), keyboard navigation shortcuts, style presets, and custom `.mmd` workflows.
* **[Mermaid Diagram Gallery (`studio/diagrams/`)](diagrams/README.md)** — Folder structure for the core, extended, and custom `.mmd` / `.mermaid` diagram corpus.

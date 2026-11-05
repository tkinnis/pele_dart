# `pele_dart`

A fast, deterministic, zero-DOM **pure Dart** Mermaid diagram rendering engine ported from [`obsidianmd/pele`](https://github.com/obsidianmd/pele).

## Highlights

* **Pure Dart 3 (`sdk: ^3.13.0`)**: Zero browser (`WKWebView` / `WebKitGTK` / `WebView2`), zero JavaScript engine (`QuickJS` / `JavaScriptCore`), and zero Flutter SDK dependency in the core package.
* **Dual SVG Output Modes**:
  1. **`SvgOutputMode.flattened`**: Directly emits pre-flattened SVG primitives (`<path>`, `<rect>`, `<circle>`, `<ellipse>`, `<line>`, `<polyline>`, `<polygon>`, `<text>`, `<g>`, `<clipPath>`, gradients) with resolved palette colors, stamped arrowhead geometry instead of `<marker>`, and explicit baseline `y` coordinates—ready for immediate compilation via `vector_graphics_compiler` (`encodeSvg`).
  2. **`SvgOutputMode.cssVariables`** *(Upstream Parity Mode)*: Emits theme-reactive SVG styled via `--pele-*` CSS custom properties and `<marker>` definitions, matching upstream `obsidianmd/pele` output for web export and differential snapshot testing.
* **Built-in Safety & DoS Limits**: Enforces pre-parse and post-parse resource budgets (source characters, node/edge counts, subgraph nesting depth, element count, path data length, and dash segment budgets).
* **macOS 3-Way Comparison Workbench (`example/`)**: A macOS desktop app for inspecting and diffing both visual diagram renders (side-by-side, split-curtain swipe, Cyan/Magenta channel overlay, pixel-diff heatmap, and blink mode) and raw SVG markup (inline diff + external diff launcher) across `pele_dart`, `obsidianmd/pele` (JS), and `mermaid.js`.

## Visual Render Showcase (Pure Dart Output)

Every image below is a clean, standalone SVG generated directly by `pele_dart` in pure Dart (`SvgOutputMode.flattened`) with zero browser or JavaScript runtime.

> **[Browse All 33 Diagram Families in the Visual Diagram Gallery →](docs/DIAGRAM_GALLERY.md)**

| Flowchart (`flowchart`) | Sequence Diagram (`sequence`) |
| :---: | :---: |
| ![Flowchart](docs/images/diagrams/flowchart.svg) | ![Sequence Diagram](docs/images/diagrams/sequence.svg) |
| **State Diagram (`state`)** | **Mindmap (`mindmap`)** |
| ![State Diagram](docs/images/diagrams/state.svg) | ![Mindmap](docs/images/diagrams/mindmap.svg) |
| **Architecture (`architecture-beta`)** | **Sankey (`sankey`)** |
| ![Architecture](docs/images/diagrams/architecture.svg) | ![Sankey](docs/images/diagrams/sankey.svg) |

### Custom Styling & Palettes

Consumers can use the built-in defaults (`PelePalette.light` or `PelePalette.dark`) or supply their own `PelePalette(...)`, `--pele-*` CSS custom properties, or in-diagram Mermaid `classDef` / `style` rules. See [**Section 5 of the API Manual**](docs/API_MANUAL.md#5-theming-styling--customization) for full code examples.

| Default Light (`PelePalette.light`) | Default Dark (`PelePalette.dark`) |
| :---: | :---: |
| ![Default Light](docs/images/styles/style_light.svg) | ![Default Dark](docs/images/styles/style_dark.svg) |
| **Custom Palette Example (Catppuccin Mocha)** | **In-Diagram Mermaid `classDef` Styling** |
| ![Catppuccin Mocha](docs/images/styles/style_catppuccin_mocha.svg) | ![Mermaid classDef](docs/images/styles/style_mermaid_classdef.svg) |

## Quick Start

```dart
import 'package:pele_dart/pele_dart.dart';

void main() {
  final result = render(
    'flowchart LR\n  A[Start] --> B{Decision}\n  B -->|Yes| C[Done]',
    const RenderOptions(
      outputMode: SvgOutputMode.flattened,
      palette: PelePalette.light,
    ),
  );
  print(result.svg);
}
```

## Checking for Upstream `obsidianmd/pele` & Mermaid Updates

Run a single command to check GitHub for new `obsidianmd/pele` releases, unreleased commits, or target `mermaid.js` baseline version updates:

```bash
dart run tool/sync_upstream.dart
```

When updates are available, stage the new release and generate `.upstream/diff_report.md`:

```bash
dart run tool/sync_upstream.dart --update-to-latest
```

Then invoke the [`.agents/skills/sync-upstream-pele/SKILL.md`](.agents/skills/sync-upstream-pele/SKILL.md) agent skill to fold in the changes and verify 100% parity across all 787 canonical, gallery, and corpus diagrams (`dart run tool/verify_against_upstream.dart`).

## Documentation

* **[`docs/DIAGRAM_GALLERY.md`](docs/DIAGRAM_GALLERY.md)**: Visual gallery showing clean standalone SVG renders and Mermaid source code for all 33 supported diagram families.
* **[`docs/API_MANUAL.md`](docs/API_MANUAL.md)**: Complete API user manual covering `render`, `renderMermaid`, `parse`, `detectType`, `supports`, `SvgOutputMode`, `PelePalette` styling & custom palettes, `RenderOptions`, `PeleError`, custom resolvers, all 33 diagram families, and Flutter (`vector_graphics_compiler`) integration.
* **[`docs/UPSTREAM_SYNC.md`](docs/UPSTREAM_SYNC.md)**: Guide to detecting upstream `obsidianmd/pele` releases and Mermaid version updates, staging diffs, porting bug fixes / beta promotions / new diagrams, running the 787-diagram differential suite, and cutting releases.
* **[`docs/DESIGN.md`](docs/DESIGN.md)**: Architecture, dual SVG emission strategy, TypeScript-to-Dart translation rules, 3-way macOS comparison app, phased rollout, upstream sync lifecycle, and agentic coding workflows.
* **[`UPSTREAM.md`](UPSTREAM.md)**: Single source of truth for the pinned `obsidianmd/pele` commit SHA, release tag, target Mermaid version, and per-module porting status matrix.
* **[`AGENTS.md`](AGENTS.md)**: Operational guidelines, architectural invariants, and verification gates for AI coding agents.
* **[`.agents/skills/sync-upstream-pele/SKILL.md`](.agents/skills/sync-upstream-pele/SKILL.md)**: Automated agent skill for folding upstream `obsidianmd/pele` updates into `pele_dart`.

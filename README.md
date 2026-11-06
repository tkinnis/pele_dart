# `pele_dart`

[![pub package](https://img.shields.io/pub/v/pele_dart.svg)](https://pub.dev/packages/pele_dart)
[![CI](https://github.com/tkinnis/pele_dart/actions/workflows/ci.yml/badge.svg)](https://github.com/tkinnis/pele_dart/actions/workflows/ci.yml)
[![Benchmarks](https://img.shields.io/badge/benchmarks-2.2x%20faster%20(AOT)-00b4d8)](docs/BENCHMARKS.md)
[![Upstream obsidianmd/pele](https://img.shields.io/badge/upstream-obsidianmd%2Fpele-7c3aed)](UPSTREAM.md)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A fast, deterministic, zero-DOM **pure Dart** Mermaid diagram layout and SVG rendering engine.

**`pele_dart`** is a 1:1 pure-Dart port of [**`obsidianmd/pele`**](https://github.com/obsidianmd/pele) ([`pele.run`](https://pele.run))—the lightweight, synchronous, zero-dependency TypeScript Mermaid renderer created by [**Steph Ango (`kepano`)**](https://github.com/kepano) and the [**Obsidian**](https://obsidian.md) team—augmented with a native SVG 1.1 flattener for Flutter's `vector_graphics_compiler` (`encodeSvg`).

---

## Highlights

* **Pure Dart 3 (`sdk: ^3.13.0`)**: Zero browser (`WKWebView` / `WebKitGTK` / `WebView2`), zero JavaScript runtime (`QuickJS` / `JavaScriptCore`), and zero Flutter SDK dependency in the core package. Runs synchronously in CLI tools, servers, background Dart isolates (`Isolate.run`), and Flutter apps.
* **100% Byte-for-Byte Upstream Parity (`787/787`)**: Version-locked 1:1 to upstream [`obsidianmd/pele`](https://github.com/obsidianmd/pele) (see [`UPSTREAM.md`](UPSTREAM.md)) and produces byte-for-byte identical SVG markup across all 33 canonical diagram families, all 232 showcase/playground samples, and all 522 upstream test corpus diagrams.
* **Dual SVG Output Modes (`SvgOutputMode`)**:
  1. **`SvgOutputMode.flattened`** *(Default)*: Resolves all `--pele-*` and `--_*` CSS custom properties, `color-mix(in srgb, ...)` blends, `calc(...)` expressions, `currentColor`, `<tspan>` `baseline-shift`, and inline `style="..."` properties against a `PelePalette` into static SVG 1.1 attributes—ready for immediate compilation with Flutter's `vector_graphics_compiler` (`encodeSvg`) or static PDF/PNG rasterizers.
  2. **`SvgOutputMode.cssVariables`** *(Upstream Parity Mode)*: Emits upstream `obsidianmd/pele`'s exact theme-reactive SVG styled via `var(--pele-*)` CSS custom properties so a single SVG adapts dynamically to light/dark CSS themes on the web.
* **Built-in Safety & Resource Limits**: Escapes diagram text, sanitizes link/image URL schemes (`http`, `https`, `mailto`, `tel`), and enforces configurable DoS budgets (`limit` input characters, `maxEdges`, recursion depth protection, and `outputLimit` SVG characters).
* **macOS 3-Way Comparison Studio (`example/`)**: A desktop workbench for side-by-side visual rendering, pixel-diff / split-curtain inspection, and SVG markup diffing across `pele_dart` (Pure Dart), `obsidianmd/pele` (JS), and `mermaid.js`, complete with a live CSS style editor and dynamic `.mmd` / `.mermaid` folder browser.

---

## Visual Render Showcase (Pure Dart Output)

Every image below is a standalone SVG generated directly by `pele_dart` in pure Dart (`SvgOutputMode.flattened`) with zero browser or JavaScript runtime.

> **[Browse All 33 Diagram Families in the Visual Diagram Gallery (`docs/DIAGRAM_GALLERY.md`) →](docs/DIAGRAM_GALLERY.md)**

| Flowchart (`flowchart`) | Sequence Diagram (`sequenceDiagram`) |
| :---: | :---: |
| ![Flowchart](docs/images/diagrams/flowchart.svg) | ![Sequence Diagram](docs/images/diagrams/sequence.svg) |
| **State Diagram (`stateDiagram-v2`)** | **Mindmap (`mindmap`)** |
| ![State Diagram](docs/images/diagrams/state.svg) | ![Mindmap](docs/images/diagrams/mindmap.svg) |
| **Architecture (`architecture-beta`)** | **Sankey (`sankey`)** |
| ![Architecture](docs/images/diagrams/architecture.svg) | ![Sankey](docs/images/diagrams/sankey.svg) |

### Custom Styling & Palettes

Consumers can use the built-in defaults (`PelePalette.light` or `PelePalette.dark`) or supply their own `PelePalette(...)`, `--pele-*` CSS custom properties, or in-diagram Mermaid `classDef` / `style` directives. See [**Section 5 of the API User Manual**](docs/API_MANUAL.md#5-theming-styling--customization) for complete examples.

| Default Light (`PelePalette.light`) | Default Dark (`PelePalette.dark`) |
| :---: | :---: |
| ![Default Light](docs/images/styles/style_light.svg) | ![Default Dark](docs/images/styles/style_dark.svg) |
| **Custom Palette Example (Catppuccin Mocha)** | **In-Diagram Mermaid `classDef` Styling** |
| ![Catppuccin Mocha](docs/images/styles/style_catppuccin_mocha.svg) | ![Mermaid classDef](docs/images/styles/style_mermaid_classdef.svg) |

---

## Installation

Add `pele_dart` from `pub.dev`:

```bash
dart pub add pele_dart
```

---

## Quick Start

### 1. Render a Mermaid Diagram to Flattened SVG

```dart
import 'package:pele_dart/pele_dart.dart';

void main() {
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

  print('Type: ${result.type} (${result.mermaidType})');
  print('Size: ${result.width} x ${result.height}');
  print(result.svg);
}
```

### 2. Two-Phase Parse & Re-Render (Fast Theme Switching)

Parse a diagram once with `parse()` and pass the model to `render()` to switch palettes or container widths without re-parsing:

```dart
final model = parse('sequenceDiagram\n  Alice->>Bob: Ping\n  Bob-->>Alice: Pong');

final lightSvg = render(model, const RenderOptions(palette: PelePalette.light)).svg;
final darkSvg  = render(model, const RenderOptions(palette: PelePalette.dark)).svg;
```

### 3. Detection & Error Handling (`PeleError`)

```dart
if (supports(source)) {
  try {
    final result = render(source);
  } on PeleError catch (e) {
    // e.code: 'syntax' | 'semantic' | 'unsupported-diagram' | 'limit'
    print('Error (${e.code}) at ${e.line}:${e.column}:\n${e.snippet}');
  }
}
```

### 4. Flutter `vector_graphics_compiler` Integration

Because `SvgOutputMode.flattened` resolves all CSS custom properties, `color-mix()` blends, `currentColor`, and inline styles into static SVG 1.1 attributes, the output compiles directly with `package:vector_graphics_compiler`:

```dart
final result = render(
  mermaidSource,
  RenderOptions(
    outputMode: SvgOutputMode.flattened,
    palette: isDark ? PelePalette.dark : PelePalette.light,
  ),
);

final Uint8List vectorBytes = encodeSvg(
  xml: result.svg,
  debugName: 'mermaid_${result.type}',
  enableClippingOptimizer: false,
  enableMaskingOptimizer: false,
  enableOverdrawOptimizer: false,
);
```

See [**Section 11 of the API User Manual**](docs/API_MANUAL.md#11-integration-guides) for a complete Flutter `StatelessWidget` example.

---

## Supported Diagram Families (33 Types)

`pele_dart` supports all **33** diagram families from `obsidianmd/pele` (see [`UPSTREAM.md`](UPSTREAM.md) for the pinned upstream release and target Mermaid version):

### Core Mermaid Diagrams (10)

| Family | `DiagramType` | Mermaid Header Keyword(s) | Visual Render |
| :--- | :--- | :--- | :--- |
| **Flowchart** | `flowchart` | `flowchart`, `graph`, `flowchart-elk` | [View SVG](docs/images/diagrams/flowchart.svg) |
| **Sequence** | `sequence` | `sequenceDiagram` | [View SVG](docs/images/diagrams/sequence.svg) |
| **Class** | `class` | `classDiagram` | [View SVG](docs/images/diagrams/class.svg) |
| **State** | `state` | `stateDiagram`, `stateDiagram-v2` | [View SVG](docs/images/diagrams/state.svg) |
| **Entity Relationship** | `er` | `erDiagram` | [View SVG](docs/images/diagrams/er.svg) |
| **Gantt** | `gantt` | `gantt` | [View SVG](docs/images/diagrams/gantt.svg) |
| **Git Graph** | `gitGraph` | `gitGraph` | [View SVG](docs/images/diagrams/git.svg) |
| **Mindmap** | `mindmap` | `mindmap` | [View SVG](docs/images/diagrams/mindmap.svg) |
| **Pie** | `pie` | `pie` | [View SVG](docs/images/diagrams/pie.svg) |
| **Info** | `info` | `info` | [View SVG](docs/images/diagrams/info.svg) |

### Extended & Architecture Diagrams (23)

| Family | `DiagramType` | Mermaid Header Keyword(s) | Visual Render |
| :--- | :--- | :--- | :--- |
| **Agentflow** | `agentflow` | `agentflow-beta` | [View SVG](docs/images/diagrams/agentflow.svg) |
| **Architecture** | `architecture` | `architecture`, `architecture-beta` | [View SVG](docs/images/diagrams/architecture.svg) |
| **Block** | `block` | `block`, `block-beta` | [View SVG](docs/images/diagrams/block.svg) |
| **C4** | `c4` | `C4Context`, `C4Container`, `C4Component`, `C4Dynamic`, `C4Deployment` | [View SVG](docs/images/diagrams/c4.svg) |
| **Cynefin** | `cynefin` | `cynefin-beta` | [View SVG](docs/images/diagrams/cynefin.svg) |
| **Event Modeling** | `eventmodeling` | `eventmodeling` | [View SVG](docs/images/diagrams/eventmodeling.svg) |
| **Ishikawa (Fishbone)** | `ishikawa` | `ishikawa`, `ishikawa-beta` | [View SVG](docs/images/diagrams/ishikawa.svg) |
| **User Journey** | `journey` | `journey` | [View SVG](docs/images/diagrams/journey.svg) |
| **Kanban** | `kanban` | `kanban` | [View SVG](docs/images/diagrams/kanban.svg) |
| **Packet** | `packet` | `packet`, `packet-beta` | [View SVG](docs/images/diagrams/packet.svg) |
| **Quadrant Chart** | `quadrantChart` | `quadrantChart` | [View SVG](docs/images/diagrams/quadrant.svg) |
| **Radar** | `radar` | `radar-beta` | [View SVG](docs/images/diagrams/radar.svg) |
| **Railroad (EBNF/ABNF/PEG)** | `railroad` | `railroad-beta`, `railroad-ebnf-beta`, `railroad-abnf-beta`, `railroad-peg-beta` | [View SVG](docs/images/diagrams/railroad.svg) |
| **Requirement** | `requirement` | `requirementDiagram`, `requirement` | [View SVG](docs/images/diagrams/requirement.svg) |
| **Sankey** | `sankey` | `sankey`, `sankey-beta` | [View SVG](docs/images/diagrams/sankey.svg) |
| **Swimlane** | `swimlane` | `swimlane-beta` | [View SVG](docs/images/diagrams/swimlane.svg) |
| **Timeline** | `timeline` | `timeline` | [View SVG](docs/images/diagrams/timeline.svg) |
| **Treemap** | `treemap` | `treemap`, `treemap-beta` | [View SVG](docs/images/diagrams/treemap.svg) |
| **Tree View** | `treeView` | `treeView-beta` | [View SVG](docs/images/diagrams/treeview.svg) |
| **Use Case** | `usecase` | `usecase-beta` | [View SVG](docs/images/diagrams/usecase.svg) |
| **Venn** | `venn` | `venn-beta` | [View SVG](docs/images/diagrams/venn.svg) |
| **Wardley Map** | `wardley` | `wardley-beta` | [View SVG](docs/images/diagrams/wardley.svg) |
| **XY Chart** | `xychart` | `xychart`, `xychart-beta` | [View SVG](docs/images/diagrams/xychart.svg) |

---

## Performance & Benchmarks

Compiled to native **Dart AOT**, `pele_dart` renders the entire **232-diagram** showcase corpus across all **33 diagram families** in **`~10.2 ms`** (`43.8 µs` mean per diagram)—over **2x faster** overall (and up to **4.5x faster** on complex diagrams like Class, Sequence, and Flowchart) than upstream `obsidianmd/pele` in JavaScriptCore (`21.9 ms`).

> **[View the Complete 33-Family Benchmark Report & Regression Gate (`docs/BENCHMARKS.md`) →](docs/BENCHMARKS.md)**

| Metric | `pele_dart` (Native Dart AOT) | `obsidianmd/pele` (JS) | Comparison |
| :--- | ---: | ---: | :--- |
| **Full 232-Diagram Corpus (`SvgOutputMode.cssVariables`)** | **10.16 ms** | 21.94 ms | **2.16x faster overall** |
| **Mean Time per Diagram (`SvgOutputMode.cssVariables`)** | **43.8 µs** | 94.6 µs | **2.16x faster per diagram** |
| **Mean Diagram Header Detection (`detectDiagram()`)** | **0.010 µs** | — | `O(1)` first-character switch dispatch |
| **Full Corpus (`SvgOutputMode.flattened`)** | **120.13 ms** | n/a *(CSS vars only)* | Includes static SVG 1.1 CSS-variable & `color-mix()` flattening |

> **Bar Series 1 (Left):** `pele_dart` Native AOT (µs) &nbsp;|&nbsp; **Bar Series 2 (Right):** `obsidianmd/pele` JS (µs) — *Lower is faster*

```mermaid
xychart-beta
  title "Core Mermaid Families — Mean Render Time in µs (Lower is Faster)"
  x-axis ["Class", "ER", "Flowchart", "Gantt", "Git", "Info", "Mindmap", "Pie", "Sequence", "State"]
  y-axis "Mean Render Time (µs)" 0 --> 300
  bar [43.9, 40.2, 79.8, 65.9, 41.4, 1.3, 21.4, 13.3, 24.5, 62.0]
  bar [200.4, 102.3, 237.3, 88.3, 87.2, 4.8, 44.4, 31.5, 84.5, 142.9]
```

---

## macOS 3-Way Comparison Studio (`example/`)

The repository includes **Pele Studio**, a native macOS desktop showcase and comparison workbench in [`example/`](example/README.md) that renders every diagram side-by-side across **`pele_dart` (Pure Dart)**, **`obsidianmd/pele` (JS)**, and **`mermaid.js`**.

> **[Read the Pele Studio User Guide (`docs/STUDIO_GUIDE.md`) →](docs/STUDIO_GUIDE.md)**

![Pele Studio — 3-Way Visual Render Workbench](docs/images/studio/studio_3way_render.png)

```bash
cd example
flutter run -d macos --release
```

* **Gallery Folder Browser & Keyboard Navigation (`example/diagrams/`)**: Dynamically scans `.mmd` and `.mermaid` text files organized under `01_core/`, `02_extended/`, and `03_custom/`. Step through all 232+ diagrams with `↑` / `↓` (`←` / `→`, `j` / `k`), jump between folders with `Alt + ↑` / `Alt + ↓` (`[` / `]`), or press `1`–`9` to select samples directly.
* **4 Inspection Modes**: **Visual Render** (synchronized pan/zoom & timing badges), **Visual Diff** (split-curtain swipe, Cyan/Magenta channel overlay, pixel-diff heatmap, and blink toggle), **Raw SVG**, and **SVG Text Diff** (inline diff + external diff launcher).
* **Live Mermaid & CSS Style Playground**: Edit Mermaid source or switch to the **`Style (CSS)`** tab to test custom `--pele-*` CSS variables and style presets in real time.

---

## Documentation

* **[Visual Diagram Gallery (`docs/DIAGRAM_GALLERY.md`)](docs/DIAGRAM_GALLERY.md)**: Clean standalone SVG renders and Mermaid source code for all 33 supported diagram families.
* **[Performance Benchmarks (`docs/BENCHMARKS.md`)](docs/BENCHMARKS.md)**: Native Dart AOT vs `obsidianmd/pele` (JS) benchmarks across all 33 diagram families (232 diagrams), phase breakdowns (`parse` vs `render`), and upstream sync regression gate rules.
* **[Pele Studio User Guide (`docs/STUDIO_GUIDE.md`)](docs/STUDIO_GUIDE.md)**: Complete walkthrough of the macOS 3-Way Comparison Studio, Visual Diff tools, keyboard shortcuts, and custom `.mmd` workflows.
* **[API User Manual (`docs/API_MANUAL.md`)](docs/API_MANUAL.md)**: Complete reference covering `render`, `renderMermaid`, `parse`, `detectType`, `supports`, `SvgOutputMode`, `PelePalette` theming & custom palettes, `RenderOptions`, `ParseOptions`, `PeleError`, custom `TextMeasurer` / `IconResolver` / `MathResolver`, and Flutter integration.
* **[Example & Comparison Studio Guide (`example/README.md`)](example/README.md)**: Guide to pure-Dart CLI usage and the macOS 3-Way Comparison Studio.
* **[Upstream Sync & Release Guide (`docs/UPSTREAM_SYNC.md`)](docs/UPSTREAM_SYNC.md)**: Workflow for detecting upstream `obsidianmd/pele` releases (`dart run tool/sync_upstream.dart`), staging diffs, and running the 787-diagram differential verification suite (`dart run tool/verify_against_upstream.dart`).
* **[Architecture & Design (`docs/DESIGN.md`)](docs/DESIGN.md)**: Architectural overview, dual SVG emission strategy, and TypeScript-to-Dart translation rules.
* **[Upstream Tracking Matrix (`UPSTREAM.md`)](UPSTREAM.md)**: Pinned `obsidianmd/pele` release tag, commit SHA, target Mermaid version, and per-module porting status matrix.
* **[Contributing Guide (`CONTRIBUTING.md`)](CONTRIBUTING.md)**: Guidelines for reporting issues, submitting pull requests, and running quality gates.

---

## Credits, Attribution & License

`pele_dart` is a pure-Dart port of [**`obsidianmd/pele`**](https://github.com/obsidianmd/pele) ([`pele.run`](https://pele.run)), created by [**Steph Ango (`kepano`)**](https://github.com/kepano) and the [**Obsidian**](https://obsidian.md) team. All credit for the original parser architecture, deterministic layout algorithms, and `--pele-*` visual design system belongs to the upstream `obsidianmd/pele` authors.

* **`pele_dart`**: Copyright (c) 2026 Tony Kinnis — licensed under the [MIT License](LICENSE).
* **Upstream `obsidianmd/pele`**: Copyright (c) 2026 kepano — licensed under the [MIT License](https://github.com/obsidianmd/pele/blob/main/LICENSE).
* **Built-in Icons**: Includes icon paths from [Lucide](https://lucide.dev), Copyright (c) 2026 Lucide Icons and Contributors — licensed under the [ISC License](LICENSE).
* **Mermaid Syntax & Compatibility Fixtures**: Targets [Mermaid](https://mermaid.js.org) syntax specifications — licensed under the [MIT License](https://github.com/mermaid-js/mermaid/blob/develop/LICENSE).

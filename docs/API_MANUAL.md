# `pele_dart` API User Manual

`pele_dart` is a fast, deterministic, zero-DOM **pure Dart** Mermaid diagram layout and SVG rendering engine ported 1:1 from [`obsidianmd/pele`](https://github.com/obsidianmd/pele). It renders 33 Mermaid diagram families synchronously into clean SVG with zero browser (`WKWebView`), zero JavaScript engine (`QuickJS` / `JavaScriptCore`), and zero Flutter SDK dependency in the core package.

---

## Table of Contents

1. [Installation](#1-installation)
2. [Quick Start](#2-quick-start)
3. [Core API Functions](#3-core-api-functions)
4. [Dual SVG Output Modes (`SvgOutputMode`)](#4-dual-svg-output-modes-svgoutputmode)
5. [Theming & Palettes (`PelePalette`)](#5-theming--palettes-pelepalette)
6. [Configuration Options (`RenderOptions` & `ParseOptions`)](#6-configuration-options-renderoptions--parseoptions)
7. [Return Types (`RenderResult` & `LinkInfo`)](#7-return-types-renderresult--linkinfo)
8. [Error Handling (`PeleError`)](#8-error-handling-peleerror)
9. [Custom Text Measurement, Icons & Math (`TextMeasurer`, `IconResolver`, `MathResolver`)](#9-custom-text-measurement-icons--math-textmeasurer-iconresolver-mathresolver)
10. [Supported Diagram Families (33 Types)](#10-supported-diagram-families-33-types)
11. [Integration Guides](#11-integration-guides)
    - [Flutter Vector Graphics (`vector_graphics_compiler`)](#a-flutter-vector-graphics-vector_graphics_compiler)
    - [Web / HTML / Markdown CSS-Variable SVG](#b-web--html--markdown-css-variable-svg)
    - [Two-Phase Parse & Re-Render (Theme Switching)](#c-two-phase-parse--re-render-theme-switching)

---

## 1. Installation

Add `pele_dart` to your `pubspec.yaml`:

```yaml
dependencies:
  pele_dart:
    git:
      url: https://github.com/tkinnis/pele_dart.git
      ref: main
```

Or for local path development:

```yaml
dependencies:
  pele_dart:
    path: ../pele_dart
```

Import the library:

```dart
import 'package:pele_dart/pele_dart.dart';
```

---

## 2. Quick Start

### Render a Mermaid diagram to a flattened SVG string (default)

```dart
import 'package:pele_dart/pele_dart.dart';

void main() {
  const source = '''
flowchart LR
  A[Client] -->|HTTPS| B(Load Balancer)
  B --> C{Healthy?}
  C -->|Yes| D[(Primary DB)]
  C -->|No| E[(Replica DB)]
''';

  // Returns RenderResult with svg, width, height, type, mermaidType, and links
  final RenderResult result = render(
    source,
    const RenderOptions(
      outputMode: SvgOutputMode.flattened,
      palette: PelePalette.light,
    ),
  );

  print('Detected type: ${result.type} (${result.mermaidType})');
  print('Dimensions: ${result.width} x ${result.height}');
  print(result.svg);
}
```

### Convenience one-liner (`renderMermaid`)

If you only need the SVG markup string:

```dart
final String svg = renderMermaid(
  'sequenceDiagram\n  Alice->>Bob: Hello!',
  options: const RenderOptions(palette: PelePalette.dark),
);
```

---

## 3. Core API Functions

### `render(Object source, [RenderOptions options = const RenderOptions()]) → RenderResult`

Parses, lays out, and renders a Mermaid diagram synchronously.

- **`source`**: Either a raw Mermaid `String` (including optional YAML frontmatter or `%%{init: ...}%%` directives) **or** a pre-parsed model object previously returned by [`parse()`](#parsestring-text-parseoptions-options--const-parseoptions--dynamic).
- **`options`**: Controls SVG output mode, color palette, typography, sizing, link/image security schemes, resource limits, and custom icon/math resolvers.
- **Returns**: [`RenderResult`](#7-return-types-renderresult--linkinfo) containing `svg`, `width`, `height`, `type`, `mermaidType`, and `links`.
- **Throws**: [`PeleError`](#8-error-handling-peleerror) on syntax errors, unsupported diagram types, or resource limit violations.

### `renderMermaid(String source, {RenderOptions options = const RenderOptions()}) → String`

Convenience wrapper around `render(source, options).svg`.

### `parse(String text, [ParseOptions options = const ParseOptions()]) → dynamic`

Parses a Mermaid diagram source string into an internal immutable model and caches its metadata so it can be passed directly to `render(model, options)` multiple times (for example, to re-render across light/dark themes or different `maxWidth` breakpoints without re-parsing).

```dart
final model = parse(mermaidSource);
final lightSvg = render(model, const RenderOptions(palette: PelePalette.light)).svg;
final darkSvg  = render(model, const RenderOptions(palette: PelePalette.dark)).svg;
```

### `detectType(String text) → DiagramType?`

Preprocesses frontmatter/directives and returns the canonical `DiagramType` identifier (e.g., `'flowchart'`, `'sequence'`, `'er'`, `'c4'`), or `null` if the input does not match any known Mermaid diagram header.

```dart
final type = detectType('graph TD\n  A --> B'); // 'flowchart'
```

### `supports(String text) → bool`

Returns `true` if `text` is recognized as a registered Mermaid diagram type. Never throws.

```dart
if (supports(codeBlock)) {
  final result = render(codeBlock);
}
```

### `flattenPeleSvg(String rawSvg, {PelePalette palette = PelePalette.light}) → String`

Converts an upstream-style CSS-variable SVG (`SvgOutputMode.cssVariables`) into a static, `vector_graphics_compiler`-compatible SVG with resolved colors, explicit baseline offsets, and stamped arrowheads. Calling `render(..., RenderOptions(outputMode: SvgOutputMode.flattened))` invokes this automatically.

### `register(Iterable<AnyDiagram> list)` & `registered(DiagramType type) → bool`

All 33 built-in diagram families (`all`) are registered automatically on first use of `render()`, `parse()`, `supports()`, or `registered()`. You can inspect whether a diagram family is registered with `registered('flowchart')` or register custom `Diagram<Model>` implementations via `register([...])`.

### `forgetTextWidths()`

Clears any memoized text width caches in the built-in metrics measurer.

---

## 4. Dual SVG Output Modes (`SvgOutputMode`)

`pele_dart` supports two deterministic SVG output modes via `RenderOptions.outputMode`:

| Mode | Enum Value | Best For | Behavior |
| :--- | :--- | :--- | :--- |
| **Flattened** *(Default)* | `SvgOutputMode.flattened` | Flutter desktop/mobile apps (`vector_graphics_compiler` / `vector_graphics`), static PDF/PNG rasterizers | Resolves all `--pele-*` and `--_*` CSS custom properties, `color-mix()` expressions, and `currentColor` into concrete hex/RGB attributes (`fill`, `fill-opacity`, `stroke`, `stroke-opacity`). Converts `<marker>` arrowheads into directly stamped `<path>` / `<polygon>` geometry and converts `dominant-baseline` into explicit `y` coordinates. |
| **CSS Variables** *(Upstream Parity)* | `SvgOutputMode.cssVariables` | Web views, HTML/Markdown exports, differential testing against `obsidianmd/pele` | Emits byte-for-byte identical SVG markup to upstream `obsidianmd/pele`, styled via `var(--pele-*)` CSS custom properties and `<marker>` definitions so a single SVG adapts dynamically to light/dark CSS themes. |

---

## 5. Theming & Palettes (`PelePalette`)

When using `SvgOutputMode.flattened` (the default), `RenderOptions.palette` controls all diagram colors, stroke widths, corner radii, and font stacks.

### Built-in Presets

- **`PelePalette.light`** *(default)*: Clean light theme (`bg: '#ffffff'`, `fg: '#24292e'`, `surfaceAlt: '#e6e6e6'`, `critical: '#e45756'`).
- **`PelePalette.dark`**: Dark theme (`bg: '#1e1e1e'`, `fg: '#e1e4e8'`, `surfaceAlt: '#3f3f46'`, `critical: '#f87171'`).

### Custom `PelePalette`

```dart
const customPalette = PelePalette(
  bg: '#0f172a',
  fg: '#f8fafc',
  muted: '#94a3b8',
  line: '#cbd5e1',
  surface: '#1e293b',
  surfaceAlt: '#334155',
  border: '#64748b',
  accent: '#38bdf8',
  code: '#e2e8f0',
  critical: '#fb7185',
  radius: 6,
  strokeWidth: 1.25,
  thickStrokeWidth: 2.5,
  hairlineStrokeWidth: 0.5,
  fontFamily: 'Inter, -apple-system, BlinkMacSystemFont, sans-serif',
  monoFontFamily: 'JetBrains Mono, SFMono-Regular, Menlo, monospace',
  colors: <String>[
    '#4c78a8',
    '#f58518',
    '#54a24b',
    '#e45756',
    '#72b7b2',
    '#eeca3b',
    '#b279a2',
    '#9d755d',
  ],
);

final result = render(
  source,
  const RenderOptions(
    outputMode: SvgOutputMode.flattened,
    palette: customPalette,
  ),
);
```

### Automatic Derived Palette Tokens

If `muted`, `line`, `surface`, `border`, or `accent` are omitted (`null`), `PelePalette` automatically derives them using the exact same perceptual color-mixing ratios as upstream `obsidianmd/pele`:

| Property | Default / Derived Formula | Description |
| :--- | :--- | :--- |
| `bg` | `'#ffffff'` (light) / `'#1e1e1e'` (dark) | Canvas background color (`--pele-bg`) |
| `fg` | `'#24292e'` (light) / `'#e1e4e8'` (dark) | Primary text and foreground color (`--pele-fg`) |
| `muted` | `60% fg + 40% bg` | Secondary labels, captions, and axis ticks (`--pele-muted`) |
| `line` | `fg` | Connector edges, lifelines, and borders (`--pele-line`) |
| `surface` | `3% fg + 97% bg` | Default node/box fill (`--pele-surface`) |
| `surfaceAlt` | `'#e6e6e6'` (light) / `'#3f3f46'` (dark) | Secondary container/header fill (`--pele-surface-alt`) |
| `border` | `50% fg + 50% bg` | Node and cluster border stroke (`--pele-border`) |
| `accent` | `'#5b7bd5'` (`colors[0]` / theme accent) | Primary highlight and active state color (`--pele-accent`) |
| `critical` | `'#e45756'` (light) / `'#f87171'` (dark) | Critical path (Gantt) and error accents (`--pele-critical`) |
| `colors` | 8 Tableau/Vega series colors (`--pele-c0`..`--pele-c7`) | Categorical palette for multi-series charts, mindmaps, pies, and sankeys |

---

## 6. Configuration Options (`RenderOptions` & `ParseOptions`)

### `RenderOptions`

| Option | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `outputMode` | `SvgOutputMode` | `SvgOutputMode.flattened` | `SvgOutputMode.flattened` or `SvgOutputMode.cssVariables`. |
| `palette` | `PelePalette` | `PelePalette.light` | Palette used when `outputMode == SvgOutputMode.flattened`. |
| `measurer` | `TextMeasurer?` | Built-in deterministic metrics table | Custom text width measurer for proportional and monospace fonts. |
| `fontFamily` | `String?` | `null` | Override primary font family in `SvgOutputMode.cssVariables`. |
| `fontFamilyMono` | `String?` | `null` | Override monospace font family in `SvgOutputMode.cssVariables`. |
| `monospace` | `List<MonospacePart>?` | `null` | Diagram parts to render in monospace (e.g., `['code']`). |
| `fontSize` | `double?` | `13` | Base font size in pixels. |
| `idPrefix` | `String?` | `'pele'` | Prefix for generated SVG `id` attributes (markers, clips, gradients). |
| `responsive` | `bool?` | `true` (unless `useMaxWidth: false`) | Emits `style="max-width: <W>px"` instead of fixed `width`/`height` attributes. |
| `maxWidth` | `double?` | `null` | Target container width in pixels for auto-direction and wrapping. |
| `autoDirection` | `bool?` | `false` | Automatically flips `LR` flowcharts to `TB` when wider than `directionBreakpoint`. |
| `directionBreakpoint` | `double?` | `500` | Width threshold in pixels for `autoDirection`. |
| `padding` | `double?` | `8` | Outer SVG viewBox padding in pixels. |
| `limit` | `int?` | `50000` | Maximum input source length in characters. |
| `outputLimit` | `int?` | `4000000` | Maximum output SVG length in characters. |
| `maxEdges` | `int?` | `5000` | Maximum number of edges/relations allowed during parsing. |
| `links` | `bool?` | `true` | Whether `click` directives and node links emit `<a>` wrappers / `LinkInfo`. |
| `linkSchemes` | `List<String>?` | `['http', 'https', 'mailto']` | Allowed URL schemes for clickable links. |
| `linkRel` | `String?` | `'noopener noreferrer'` | `rel` attribute added to external `<a>` tags. |
| `images` | `bool?` | `true` | Whether `<image>` elements are allowed in diagrams. |
| `imageSchemes` | `List<String>?` | `['http', 'https', 'data']` | Allowed URL schemes for embedded `<image>` elements. |
| `icons` | `IconResolver?` | Built-in icon pack | Callback `String? Function(String name)` returning inner SVG path markup for icon names. |
| `math` | `MathResolver?` | Built-in TeX layout | Callback `MathMarkup? Function(String tex, double size)` for `$$...$$` math formulas. |
| `config` | `Map<String, dynamic>?` | `null` | Extra Mermaid configuration merged with frontmatter / `%%{init}%%` directives. |
| `now` | `Object?` | `null` | Fixed reference date (`DateTime` or ISO `String`) for deterministic `gantt` today-markers. |

---

## 7. Return Types (`RenderResult` & `LinkInfo`)

### `RenderResult`

Returned by `render()`:

| Field | Type | Description |
| :--- | :--- | :--- |
| `svg` | `String` | Complete `<svg ...>...</svg>` document string. |
| `width` | `double` | Intrinsic diagram width in logical pixels (from the SVG `viewBox`). |
| `height` | `double` | Intrinsic diagram height in logical pixels (from the SVG `viewBox`). |
| `type` | `DiagramType` (`String`) | Canonical Pele diagram family name (e.g., `'flowchart'`, `'sequence'`, `'railroad'`). |
| `mermaidType` | `MermaidType` (`String`) | Specific Mermaid header variant (e.g., `'flowchart-v2'`, `'flowchart-elk'`, `'railroadEbnf'`). |
| `links` | `List<LinkInfo>` | Interactive links declared in the diagram (`click` handlers, link nodes). |

### `LinkInfo`

| Field | Type | Description |
| :--- | :--- | :--- |
| `id` | `String` | Node or element identifier associated with the link. |
| `href` | `String` | Sanitized target URL or internal note target. |
| `internal` | `bool` | `true` for internal/wiki links (`internal-link`), `false` for external URLs. |

---

## 8. Error Handling (`PeleError`)

All syntax, unsupported-diagram, and resource-limit failures throw a structured `PeleError`:

```dart
try {
  final result = render(userInput);
} on PeleError catch (e) {
  print('Error code: ${e.code}');          // 'syntax' | 'unsupported-diagram' | 'limit'
  print('Diagram type: ${e.type}');        // e.g. 'flowchart' (or null if undetected)
  print('Mermaid type: ${e.mermaidType}'); // e.g. 'flowchart-v2'
  print('Location: line ${e.line}, column ${e.column}');
  print('Snippet:\n${e.snippet}');
  print('Full message:\n${e.message}');
}
```

### `PeleError.code` Values

| Code | Meaning |
| :--- | :--- |
| `'syntax'` | Lexical or grammar error in the diagram source (`line`, `column`, and `snippet` point to the exact position in the original source, even across frontmatter and `%%{init}%%` directives). |
| `'unsupported-diagram'` | No known Mermaid diagram keyword was found, or the diagram type is not registered. |
| `'limit'` | Diagram exceeded safety budgets (`limit` source characters, `maxEdges`, nesting depth, or `outputLimit` SVG characters). |

---

## 9. Custom Text Measurement, Icons & Math (`TextMeasurer`, `IconResolver`, `MathResolver`)

### Custom `TextMeasurer`

By default, `pele_dart` uses a deterministic character-width metrics table ported 1:1 from `obsidianmd/pele` (`src/text/metrics.ts`). It requires zero platform font APIs and produces identical layouts across macOS, Linux, Windows, iOS, Android, and Web.

If you want layout boxes to size against a custom Flutter `TextPainter` or platform font engine, provide a `TextMeasurer`:

```dart
double myMeasure(String text, double fontSize, bool bold, bool mono, [bool italic = false]) {
  // Return measured width of a single line in logical pixels
  return text.length * fontSize * (mono ? 0.6 : 0.55);
}

final result = render(
  source,
  RenderOptions(measurer: myMeasure),
);
```

### Custom `IconResolver`

Diagrams such as `architecture`, `flowchart`, and `mindmap` support icon references (e.g., `fa:fa-server`, `lucide:database`). `pele_dart` bundles upstream's built-in icon paths and also allows custom icon resolution:

```dart
final result = render(
  source,
  RenderOptions(
    icons: (String name) {
      if (name == 'custom:cloud') {
        // Return inner SVG path/shapes tailored to a 24x24 viewBox
        return '<path d="M18 10h-1.26A8 8 0 1 0 9 20h9a5 5 0 0 0 0-10z"/>';
      }
      return null; // Fall back to built-in icons
    },
  ),
);
```

---

## 10. Supported Diagram Families (33 Types)

`pele_dart` supports all **33** diagram families from `obsidianmd/pele` (`v1.13.0`):

| # | `DiagramType` | `MermaidType` Variant(s) | Mermaid Header Keyword(s) | Description |
| :- | :--- | :--- | :--- | :--- |
| 1 | `flowchart` | `flowchart-v2`, `flowchart-elk` | `flowchart`, `graph`, `flowchart-elk` | Directed & undirected flowcharts, subgraphs, 20+ node shapes |
| 2 | `sequence` | `sequence` | `sequenceDiagram` | Participant lifelines, activations, loops/alt/par/critical blocks, notes |
| 3 | `class` | `classDiagram` | `classDiagram` | UML classes, generics, visibility, inheritance/composition relations, namespaces |
| 4 | `state` | `stateDiagram` | `stateDiagram`, `stateDiagram-v2` | Hierarchical/composite states, fork/join/choice pseudostates, concurrency |
| 5 | `er` | `er` | `erDiagram` | Entity-Relationship models, Crow's foot cardinality, typed attribute tables |
| 6 | `gantt` | `gantt` | `gantt` | Project schedules, sections, milestones, dependencies, excludes, date formatting |
| 7 | `pie` | `pie` | `pie` | Proportional pie charts with optional `showData` values and legend |
| 8 | `mindmap` | `mindmap` | `mindmap` | Radial and hierarchical outline mindmaps with shapes and icons |
| 9 | `timeline` | `timeline` | `timeline` | Chronological timelines with grouped sections and multi-event periods |
| 10 | `gitGraph` | `gitGraph` | `gitGraph` | Git commit history, branches, merges, cherry-picks, and tags (`LR`, `TB`, `BT`) |
| 11 | `journey` | `journey` | `journey` | User journey maps with satisfaction scores (1–5) and actor assignments |
| 12 | `quadrantChart` | `quadrantChart` | `quadrantChart` | 2x2 strategic quadrant grids with plotted data points |
| 13 | `xychart` | `xychart` | `xychart`, `xychart-beta` | Cartesian bar and line charts with categorical/numeric axes |
| 14 | `sankey` | `sankey` | `sankey`, `sankey-beta` | Proportional flow Sankey diagrams from CSV/link triples |
| 15 | `requirement` | `requirement` | `requirementDiagram`, `requirement` | Systems engineering requirements, risk/verify metadata, and trace links |
| 16 | `c4` | `c4` | `C4Context`, `C4Container`, `C4Component`, `C4Dynamic`, `C4Deployment` | C4 software architecture boundaries, persons, systems, containers, and relations |
| 17 | `kanban` | `kanban` | `kanban` | Agile Kanban boards with columns, cards, assignees, priorities, and metadata |
| 18 | `block` | `block` | `block`, `block-beta` | Multi-column grid block layouts, compound blocks, and spanned arrows |
| 19 | `packet` | `packet` | `packet`, `packet-beta` | Network protocol bit/byte packet header diagrams |
| 20 | `architecture` | `architecture` | `architecture`, `architecture-beta` | Cloud/system architecture groups, services, junctions, and directed ports |
| 21 | `treemap` | `treemap` | `treemap`, `treemap-beta` | Squarified hierarchical treemaps |
| 22 | `radar` | `radar` | `radar-beta` | Multi-axis spider/radar charts with polygon or circle grids |
| 23 | `treeView` | `treeView` | `treeView-beta` | File/directory and hierarchical tree views |
| 24 | `info` | `info` | `info` | Mermaid version/diagnostic info card |
| 25 | `agentflow` | `agentflow` | `agentflow-beta` | AI agent workflow graphs with tool/prompt/memory nodes |
| 26 | `ishikawa` | `ishikawa` | `ishikawa`, `ishikawa-beta` | Fishbone (cause-and-effect) root-cause diagrams |
| 27 | `venn` | `venn` | `venn-beta` | 1-, 2-, and 3-set proportional Venn diagrams with intersection labels |
| 28 | `wardley` | `wardley` | `wardley-beta` | Wardley value-chain evolution maps, pipelines, and movement arrows |
| 29 | `cynefin` | `cynefin` | `cynefin-beta` | Cynefin sense-making framework domains (Clear, Complicated, Complex, Chaotic, Confused) |
| 30 | `railroad` | `railroad`, `railroadEbnf`, `railroadAbnf`, `railroadPeg` | `railroad-beta`, `railroad-ebnf-beta`, `railroad-abnf-beta`, `railroad-peg-beta` | Syntax railroad track diagrams from DSL, W3C/ISO EBNF, RFC 5234 ABNF, or PEG grammars |
| 31 | `swimlane` | `swimlane` | `swimlane-beta` | Cross-functional swimlane process diagrams |
| 32 | `usecase` | `usecase` | `usecase-beta` | UML Use Case diagrams with stick-figure actors, system boundaries, and `<<include>>`/`<<extend>>` |
| 33 | `eventmodeling` | `eventmodeling` | `eventmodeling` | Event Modeling timelines with UI wireframes, commands, domain events, and read views |

---

## 11. Integration Guides

### A. Flutter Vector Graphics (`vector_graphics_compiler`)

In Flutter desktop or mobile applications, render with `SvgOutputMode.flattened` (the default) and compile the resulting SVG string into a binary vector asset using `package:vector_graphics_compiler` and `package:vector_graphics`:

```dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pele_dart/pele_dart.dart' as pele;
import 'package:vector_graphics/vector_graphics.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart';

class MermaidDiagramWidget extends StatelessWidget {
  const MermaidDiagramWidget({
    super.key,
    required this.source,
    this.isDark = false,
  });

  final String source;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final result = pele.render(
      source,
      pele.RenderOptions(
        outputMode: pele.SvgOutputMode.flattened,
        palette: isDark ? pele.PelePalette.dark : pele.PelePalette.light,
      ),
    );

    final Uint8List compiledBytes = encodeSvg(
      xml: result.svg,
      debugName: 'mermaid_${result.type}',
      enableClippingOptimizer: false,
      enableMaskingOptimizer: false,
      enableOverdrawOptimizer: false,
    );

    return SizedBox(
      width: result.width,
      height: result.height,
      child: VectorGraphic(
        loader: _BytesVectorLoader(compiledBytes),
        width: result.width,
        height: result.height,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _BytesVectorLoader extends BytesLoader {
  const _BytesVectorLoader(this.bytes);
  final Uint8List bytes;

  @override
  Future<ByteData> loadBytes(BuildContext? context) async =>
      ByteData.sublistView(bytes);

  @override
  int get hashCode => bytes.hashCode;

  @override
  bool operator ==(Object other) =>
      other is _BytesVectorLoader && identical(other.bytes, bytes);
}
```

### B. Web / HTML / Markdown CSS-Variable SVG

When embedding diagrams into HTML pages or web apps where CSS handles light/dark mode automatically, use `SvgOutputMode.cssVariables`:

```dart
final result = render(
  source,
  const RenderOptions(outputMode: SvgOutputMode.cssVariables),
);
```

Define the `--pele-*` variables in your stylesheet to switch themes instantaneously without re-rendering:

```css
:root {
  --pele-bg: #ffffff;
  --pele-fg: #24292e;
  --pele-surface-alt: #e6e6e6;
  --pele-critical: #e45756;
}

@media (prefers-color-scheme: dark) {
  :root {
    --pele-bg: #1e1e1e;
    --pele-fg: #e1e4e8;
    --pele-surface-alt: #3f3f46;
    --pele-critical: #f87171;
  }
}
```

### C. Two-Phase Parse & Re-Render (Theme Switching)

If your application switches between light and dark themes or resizes responsive containers frequently, parse the diagram once with `parse()` and pass the model to `render()`:

```dart
final parsedModel = parse(mermaidSource);

// Fast layout + SVG generation without re-lexing or re-parsing:
final lightResult = render(
  parsedModel,
  const RenderOptions(palette: PelePalette.light),
);
final darkResult = render(
  parsedModel,
  const RenderOptions(palette: PelePalette.dark),
);
```

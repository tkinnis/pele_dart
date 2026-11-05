# `pele_dart` Architecture, Development & Maintenance Design Document

* **Status**: Draft v2 (For Iterative Review)
* **Upstream Tracking**: See [`UPSTREAM.md`](../UPSTREAM.md) (Single source of truth for the pinned [`obsidianmd/pele`](https://github.com/obsidianmd/pele) release and commit SHA)
* **Target SDK**: Pure Dart `^3.13.0` (Zero Flutter / `dart:ui` / Browser / JS Runtime dependencies in the core package)

---

## 1. Executive Summary & Goals

Traditional Mermaid diagram rendering in Dart and Flutter applications requires running a multi-megabyte JavaScript bundle (`mermaid.min.js`) inside an offscreen browser engine (`WKWebView`, `WebKitGTK`, or `WebView2`) and executing complex DOM-inspection scripts (`getComputedStyle()`, `getPointAtLength()`, `<canvas>` rasterization) because Flutter’s `vector_graphics_compiler` and `flutter_svg` only support a static subset of SVG primitives.

**`pele_dart`** eliminates the browser and JavaScript runtime entirely by providing a **pure Dart 3 library** ported 1:1 from [`obsidianmd/pele`](https://github.com/obsidianmd/pele)—Obsidian’s zero-dependency, synchronous, zero-DOM Mermaid rendering engine—augmented with a native **flattened SVG emitter** that outputs `vector_graphics_compiler`-ready SVG directly, plus a **macOS 3-way visual and SVG diff workbench (`example/`)** for human verification against upstream `obsidianmd/pele` and `mermaid.js`.

### 1.1 Primary Goals

1. **Zero Browser & Zero JS Engine**: Render Mermaid diagrams into SVG synchronously in pure Dart with no WebView process, no embedded JS engine (`QuickJS` / `JavaScriptCore`), and no DOM dependency.
2. **Pure Dart Core (`sdk: ^3.13.0`)**: Depend only on standard Dart core libraries and `package:meta`, enabling execution inside background Dart isolates (`Isolate.run`), CLI tools, servers, and unit tests without a Flutter runtime.
3. **Dual SVG Output Modes**:
   * **`SvgOutputMode.flattened`** *(Default for Native Vector Rendering)*: Directly emits pre-flattened SVG primitives compatible with `vector_graphics_compiler` (`encodeSvg`), eliminating the need for a post-render DOM flattener or a raster PNG `<canvas>` fallback.
   * **`SvgOutputMode.cssVariables`** *(Upstream Parity Mode)*: Emits byte-for-byte structurally identical SVG to upstream `obsidianmd/pele` (`var(--pele-*)` CSS custom properties, `<style>`, `<marker>` arrowheads, `dominant-baseline`) for differential testing against upstream Pele and standalone `.svg` file export.
4. **Full Diagram Coverage**: Support all 33 diagram families present in `obsidianmd/pele` (recorded in [`UPSTREAM.md`](../UPSTREAM.md)).
5. **macOS 3-Way Comparison & SVG Diff Workbench (`example/`)**: Provide a macOS desktop application to visually compare and inspect/diff the raw SVG output of any diagram across **`pele_dart`**, **`obsidianmd/pele` (JS)**, and **`mermaid.js`** in 1-way, 2-way, or 3-way views.
6. **First-Class Upstream Syncability**: Maintain a strict 1:1 file and symbol mapping with `obsidianmd/pele/src/`, using [`UPSTREAM.md`](../UPSTREAM.md) as the single source of truth for the pinned upstream commit so future upstream commits and releases can be diffed and ported mechanically.
7. **Defense-in-Depth DoS Safety Caps**: Enforce fine-grained pre-parse and post-parse resource budgets (source length, node/edge counts, subgraph depth, element count, path length, and dash segment budgets).

### 1.2 Non-Goals

* **DOM / HTML Label Execution**: Like upstream Pele, `pele_dart` never executes `<script>`, JS callbacks, or arbitrary HTML `<foreignObject>` trees.
* **Mermaid ELK Layout Engine Emulation**: `pele_dart` uses Pele’s deterministic layered/compound/lane layout solvers (`lib/src/layout/`) rather than bundling `elkjs`.
* **Flutter Widget Rendering Inside the Core Package**: The root `pele_dart` package outputs SVG strings, logical dimensions, accessibility metadata, and structured diagnostics; Flutter widget rendering lives only in downstream consumers and in the `example/` macOS comparison app.

---

## 2. Public API Design

The library exposes a synchronous function (`renderMermaid`) designed to run either on the main isolate or inside `Isolate.run()`, returning either a valid SVG payload (with natural width/height and accessibility label) or a typed failure (`syntaxError`, `tooLarge`, or `unsupportedDiagram`).

```dart
/// Output format for the generated SVG string.
enum SvgOutputMode {
  /// Emits strict static SVG primitives compatible with `vector_graphics_compiler`
  /// (resolved hex/rgb palette colors, stamped arrowhead geometry instead of
  /// `<marker>`, explicit text baseline `y` coordinates, and no `<style>` tags).
  flattened,

  /// Emits upstream-compatible themeable SVG using `var(--pele-*)` CSS variables,
  /// `<style>` rules, `<marker>` definitions, and `dominant-baseline`.
  cssVariables,
}

/// Concrete color palette mapped to `--pele-*` theme variables.
@immutable
class PelePalette {
  const PelePalette({
    required this.bg,
    required this.fg,
    required this.muted,
    required this.line,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.accent,
    required this.series, // 8 series colors (--pele-series-1 .. --pele-series-8)
    this.fontFamily = 'Inter, Helvetica Neue, sans-serif',
    this.monoFontFamily = 'Fira Code, monospace',
    this.cornerRadius = 4.0,
  });

  /// Built-in default light palette matching Pele's light defaults.
  static const PelePalette light = ...;

  /// Built-in default dark palette matching Pele's dark defaults.
  static const PelePalette dark = ...;
}

/// Resource and DoS limits enforced before layout and during SVG emission.
@immutable
class PeleLimits {
  const PeleLimits({
    this.maxSourceChars = 50000,
    this.maxEdges = 500,
    this.maxNodes = 3000,
    this.maxSourceStatements = 2000,
    this.maxSourceItems = 1000,
    this.maxVennAreas = 64,
    this.maxLabelWordChars = 1000,
    this.maxGanttSteppedDays = 100000,
    this.maxDepth = 64,
    this.maxElements = 20000,
    this.maxSvgChars = 4000000,
    this.maxPathChars = 200000,
    this.maxTextChars = 2000,
    this.maxDrawnTextChars = 200000,
    this.maxSide = 16384,
    this.maxPixels = 16000000,
    this.maxDashEntries = 4096,
    this.maxDashSegments = 100000,
  });

  static const PeleLimits defaults = PeleLimits();
}

/// Configuration for a single `renderMermaid()` invocation.
@immutable
class PeleRenderOptions {
  const PeleRenderOptions({
    this.outputMode = SvgOutputMode.flattened,
    this.palette = PelePalette.light,
    this.limits = PeleLimits.defaults,
    this.measurer,
    this.includeRawCssVariableSvg = false,
  });

  final SvgOutputMode outputMode;
  final PelePalette palette;
  final PeleLimits limits;
  final PeleTextMeasurer? measurer;
  final bool includeRawCssVariableSvg;
}

/// Sealed result returned by `renderMermaid()`.
@immutable
sealed class PeleRenderOutcome {
  const PeleRenderOutcome();
}

final class PeleRenderSuccess extends PeleRenderOutcome {
  const PeleRenderSuccess({
    required this.svg,
    required this.diagramType,
    required this.width,
    required this.height,
    this.semanticsLabel,
    this.rawCssVariableSvg,
  });

  /// The rendered SVG string (flattened by default).
  final String svg;

  /// Canonical diagram type identifier (e.g. `'flowchart'`, `'sequence'`).
  final String diagramType;

  /// Natural logical width from the SVG `viewBox`.
  final double width;

  /// Natural logical height from the SVG `viewBox`.
  final double height;

  /// Accessible label extracted from `accTitle` / `accDescr` / diagram title.
  final String? semanticsLabel;

  /// Optional themeable CSS-variable SVG (when `includeRawCssVariableSvg` is true).
  final String? rawCssVariableSvg;
}

enum PeleFailureKind { syntaxError, tooLarge, unsupportedDiagram }

final class PeleRenderFailure extends PeleRenderOutcome {
  const PeleRenderFailure({
    required this.kind,
    required this.message,
    this.line,
    this.column,
  });

  final PeleFailureKind kind;
  final String message;
  final int? line;
  final int? column;
}

/// Synchronously renders Mermaid [source] into SVG.
PeleRenderOutcome renderMermaid(
  String source, {
  PeleRenderOptions options = const PeleRenderOptions(),
});
```

---

## 3. System Architecture & 1:1 Upstream Mapping

### 3.1 Rendering Pipeline

```mermaid
flowchart LR
  A["Mermaid Source Text"] --> B["Preprocess & DoS Pre-Check\n(preprocess.dart / detect.dart)"]
  B --> C["Diagram Parser & Model\n(diagrams/<type>/parser.dart)"]
  C --> D["Post-Parse Budget Gate\n(maxNodes / maxEdges / maxDepth)"]
  D --> E["Deterministic Layout Engine\n(layout/layered, compound, lanes)"]
  E --> F["Diagram Renderer\n(diagrams/<type>/render.dart)"]
  F --> G{"SvgOutputMode"}
  G -->|"flattened"| H["Flattened SVG Builder\n• Resolve --pele-* palette\n• Stamp arrowhead paths\n• Offset text baseline y\n• Enforce element/dash caps"]
  G -->|"cssVariables"| I["Upstream SVG Builder\n• var(--pele-*) styles\n• <defs><marker>\n• dominant-baseline"]
  H --> J["vector_graphics_compiler\n(Native Vector Rendering)"]
  I --> K["Differential Snapshot Tests\n& Web SVG Export"]
```

### 3.2 Directory Layout (`1:1` with `obsidianmd/pele`)

Every file in `obsidianmd/pele/src/` maps directly to `lib/src/` in `pele_dart`, while `example/` houses the macOS 3-way visual and SVG diff comparison application:

```text
pele_dart/
├── AGENTS.md                        # AI agent constitution & architectural invariants
├── UPSTREAM.md                      # Single source of truth for pinned upstream SHA & sync matrix
├── pubspec.yaml                     # Pure Dart package manifest (single source of truth for package version)
├── analysis_options.yaml            # Strict analyzer & lint rules
├── docs/
│   └── DESIGN.md                    # This design document
├── lib/
│   ├── pele_dart.dart               # Public library entrypoint
│   └── src/
│       ├── core.dart                # <- src/core.ts
│       ├── detect.dart              # <- src/detect.ts
│       ├── errors.dart              # <- src/errors.ts
│       ├── index.dart               # <- src/index.ts
│       ├── models.dart              # <- src/models.ts
│       ├── preprocess.dart          # <- src/preprocess.ts
│       ├── types.dart               # <- src/types.ts
│       ├── util/
│       │   ├── chars.dart           # <- src/util/chars.ts
│       │   ├── math_js.dart         # Dart helpers for JS 32-bit bitwise/slice semantics
│       │   ├── unicode.dart         # <- src/util/unicode.ts
│       │   ├── url.dart             # <- src/util/url.ts
│       │   └── yaml.dart            # <- src/util/yaml.ts
│       ├── text/
│       │   ├── entities.dart        # <- src/text/entities.ts
│       │   ├── icons.dart           # <- src/text/icons.ts
│       │   ├── label.dart           # <- src/text/label.ts
│       │   ├── math.dart            # <- src/text/math.ts (TeX math layout to SVG)
│       │   ├── measurer.dart        # <- src/text/measurer.ts
│       │   └── metrics.dart         # <- src/text/metrics.ts
│       ├── layout/
│       │   ├── components.dart      # <- src/layout/components.ts
│       │   ├── compound.dart        # <- src/layout/compound.ts
│       │   ├── lanes.dart           # <- src/layout/lanes.ts
│       │   └── layered.dart         # <- src/layout/layered.ts
│       ├── svg/
│       │   ├── builder.dart         # <- src/svg/builder.ts (+ Dual output mode)
│       │   ├── cluster.dart         # <- src/svg/cluster.ts
│       │   ├── edges.dart           # <- src/svg/edges.ts (+ Direct marker stamping)
│       │   ├── flattener.dart       # Palette/CSS resolver & baseline normalizer
│       │   ├── ink.dart             # <- src/svg/ink.ts
│       │   ├── palette.dart         # <- src/svg/palette.ts
│       │   ├── root.dart            # <- src/svg/root.ts
│       │   ├── shapes.dart          # <- src/svg/shapes.ts
│       │   ├── theme.dart           # <- src/svg/theme.ts
│       │   └── title.dart           # <- src/svg/title.ts
│       └── diagrams/
│           ├── registry.dart        # <- src/diagrams/registry.ts
│           ├── common/              # <- src/diagrams/common/
│           ├── flowchart/           # <- src/diagrams/flowchart/
│           ├── sequence/            # <- src/diagrams/sequence/
│           └── ... (all 33 diagram directories)
├── test/
│   ├── compat/                      # Ported from obsidianmd/pele/tests/compat/
│   ├── layout/                      # Ported from obsidianmd/pele/tests/layout/
│   ├── render/                      # Ported from obsidianmd/pele/tests/render/
│   └── vector_graphics/             # Validates flattened SVG via vector_graphics_compiler
├── tool/
│   ├── sync_upstream.dart           # Reads UPSTREAM.md, diffs obsidianmd/pele & generates sync tasks
│   └── verify_against_upstream.dart # Automated differential test runner (Node Pele vs. pele_dart)
└── example/                         # macOS-only Flutter 3-way comparison & SVG diff app
    ├── pubspec.yaml
    ├── macos/
    └── lib/
        ├── main.dart
        ├── gallery_corpus.dart      # Curated gallery across all 33 diagram types
        ├── renderers/               # Adapters for pele_dart, obsidianmd/pele (JS), and mermaid.js
        └── views/
            ├── comparison_workbench.dart # 1-way, 2-way, or 3-way synchronized visual & SVG panes
            ├── visual_diff_view.dart     # Split-curtain, Cyan/Magenta overlay, pixel heatmap & blink diff
            └── svg_diff_view.dart        # Pretty-printed SVG inspector, inline diff & external diff launcher
```

---

## 4. Solving the `vector_graphics_compiler` Gap Without a Browser

In `mermaid.js`, diagram renderers mutate a live DOM in arbitrary ways (injecting CSS stylesheets, `<foreignObject>` HTML tables, D3 markers, and nested `<svg>` viewports), which requires querying `window.getComputedStyle()` and `SVGPathElement.getPointAtLength()` in a headless browser to flatten the DOM into static SVG primitives.

In contrast, **every diagram in Pele builds its SVG exclusively through `src/svg/` (`builder.ts`, `shapes.ts`, `edges.ts`, `palette.ts`, `ink.ts`, `root.ts`)**. By making `lib/src/svg/` mode-aware (`SvgOutputMode.flattened` vs. `SvgOutputMode.cssVariables`), we solve all four `vector_graphics_compiler` incompatibilities at the point of SVG emission:

| Upstream Pele Construct | Why `vector_graphics_compiler` Rejects It | How `pele_dart` (`SvgOutputMode.flattened`) Emits It Directly |
| :--- | :--- | :--- |
| **`var(--pele-*)` & `color-mix()`** in `svg/palette.ts` and `svg/ink.ts` | Compiler only parses literal hex (`#rrggbb`), `rgb(...)`, or named SVG colors; CSS variables and `color-mix(in srgb, ...)` fail parsing. | `svg/palette.dart` evaluates `--pele-*` lookups and `color-mix()` math directly in Dart against `PelePalette`, emitting concrete `fill="rgb(r,g,b)"` and `fill-opacity="a"` attributes. |
| **`<style>` blocks & CSS classes** in `svg/root.ts` and `svg/theme.ts` | Compiler ignores or rejects `<style>` rules and class-based presentation properties. | `svg/builder.dart` omits the `<style>` element and attaches resolved presentation attributes (`fill`, `stroke`, `stroke-width`, `font-family`, `font-size`) directly onto each SVG element. |
| **`<defs><marker>` & `marker-end="url(#...)"`** in `svg/edges.ts` | Compiler does not render SVG `<marker>` definitions on paths or lines. | In `svg/edges.dart` (where the exact numeric `[x, y]` waypoints and Bezier control points of every edge are already in memory before string serialization!), `edges.dart` computes the start/end tangent angle $\theta = \text{atan2}(dy, dx)$, shortens the stroke endpoint by the marker ref offset, and emits the arrowhead’s `<path>`/`<polygon>` inside a `<g transform="matrix(...)">`. |
| **`dominant-baseline="central"` / `"middle"` / `"hanging"`** on `<text>` and `<tspan>` | Compiler ignores `dominant-baseline`, causing all labels to sit above their intended vertical center. | `svg/builder.dart` converts `dominant-baseline` into an explicit numeric `y` offset (`y + fontSize * baselineFactor`, e.g. `+0.35 * fontSize` for `central`/`middle`, `+0.80 * fontSize` for `hanging`) and flattens multi-line `<tspan>` runs into explicit positioned `<text>` elements. |

Because all 33 diagram families in Pele emit their output through `src/svg/`, **every diagram type compiles to native lossless `vector_graphics` without needing a raster PNG fallback**.

---

## 5. TypeScript-to-Dart Translation Rules & Pitfalls

Because `obsidianmd/pele` is written in dependency-free strict TypeScript with zero DOM calls, ~95% of the code translates 1:1 into Dart 3. The remaining 5% involves subtle runtime differences between JavaScript (V8) and the Dart VM / AOT compiler that **must** be standardized in `lib/src/util/math_js.dart` so layout coordinates match upstream:

1. **64-Bit Dart `int` vs. JS 32-Bit Signed Bitwise Operations**:
   * In JavaScript, `x | 0`, `x & y`, `x ^ y`, `x << n`, `x >> n`, and `Math.imul(a, b)` coerce operands to 32-bit signed integers (`Int32`), and `x >>> n` coerces to 32-bit unsigned (`Uint32`).
   * In Dart, `int` is a 64-bit signed integer. Any hash function, deterministic seed, or bitset in Pele that uses bitwise operators will produce different numbers in Dart unless wrapped in `imul32(a, b)`, `shl32(a, n)`, `shr32(a, n)`, `ushr32(a, n)`, and `(x).toSigned(32)`.
2. **Number-to-String Formatting in SVG Attributes**:
   * In JavaScript, `Number(12.0).toString()` produces `"12"`, whereas in Dart `(12.0).toString()` produces `"12.0"`.
   * Provide a single `fmtNum(num value)` helper in `lib/src/svg/builder.dart` that rounds to 3 decimal places, strips trailing `.0` / zeros, converts `-0` to `0`, and formats without scientific notation (`1e-5`), ensuring byte-for-byte SVG coordinate parity with upstream Pele in `SvgOutputMode.cssVariables`.
3. **Out-of-Bounds & Negative Slicing (`slice` vs. `sublist` / `substring`)**:
   * JavaScript’s `Array.slice(start, end)` and `String.slice(start, end)` accept negative indices and silently clamp indices beyond `length`. Dart’s `List.sublist` and `String.substring` throw `RangeError`.
   * Provide `List<T>.jsSlice(int start, [int? end])` and `String.jsSlice(int start, [int? end])` extension methods in `lib/src/util/math_js.dart`.
4. **JavaScript Truthiness & `NaN` Checks**:
   * In JS, `Number.parseFloat("abc")` returns `NaN`, and `val || defaultVal` treats `0`, `""`, and `NaN` as falsy.
   * In Dart, `double.tryParse("abc")` returns `null`. When translating `const w = Number(raw) || 100`, translate explicitly as:
     ```dart
     final parsed = double.tryParse(raw);
     final w = (parsed != null && parsed.isFinite && parsed != 0.0) ? parsed : 100.0;
     ```
5. **Regular Expressions (`RegExp`)**:
   * Replace JS sticky regexes (`/pattern/y` with `lastIndex`) using Dart’s `regExp.matchAsPrefix(source, index)`.
   * Ensure JS `/i` and `/m` flags map to `caseSensitive: false` and `multiLine: true`.

---

## 6. macOS 3-Way Gallery & Comparison Demo App (`example/`)

To allow human developers to visually vet diagram fidelity and inspect/diff raw SVG markup across engines, `pele_dart` includes a **macOS-only Flutter desktop application** under `example/` (no iOS, Android, Windows, Linux, or Web targets in `example/`).

### 6.1 The Three Renderers

For any selected diagram, the workbench can run all three engines in parallel:
1. **`pele_dart` (Native Dart)**:
   * Renders synchronously in Dart and compiles `SvgOutputMode.flattened` via `vector_graphics_compiler` + `vector_graphics`.
   * Also captures `SvgOutputMode.cssVariables` (`includeRawCssVariableSvg: true`) so you can compare `pele_dart`’s CSS-variable SVG directly against upstream `obsidianmd/pele`’s SVG.
2. **`obsidianmd/pele` (Upstream JS)**:
   * Runs the pinned upstream `pele` JS bundle inside a macOS `WKWebView` (or headless runner) to display upstream Pele’s reference rendering and capture its raw SVG string.
3. **`mermaid.js` (Official Reference JS)**:
   * Runs official `mermaid.min.js` inside a macOS `WKWebView` to display standard Mermaid’s layout/rendering and capture its DOM-serialized SVG string.

### 6.2 Flexible 1-Way, 2-Way, and 3-Way Comparison Modes

A toolbar toggle lets you choose which renderers are active:
* **1-Way (Single Renderer)**: View any single renderer (`pele_dart`, `obsidianmd/pele` JS, or `mermaid.js`) full-window.
* **2-Way Side-by-Side**: Pick any pair:
  * `pele_dart` vs. `obsidianmd/pele` (JS) — *Verifies exact port parity between Dart and TypeScript.*
  * `pele_dart` vs. `mermaid.js` — *Compares Pele’s layout and styling against classic Mermaid.*
  * `obsidianmd/pele` (JS) vs. `mermaid.js` — *Isolates upstream Pele design differences from Dart porting bugs.*
* **3-Way Side-by-Side**: View all three (`pele_dart` | `obsidianmd/pele` JS | `mermaid.js`) simultaneously.

### 6.3 Visual Render, Visual Graphic Diff, Raw SVG Markup, and SVG Text Diff Modes

The workbench provides four complementary inspection modes for the active renderer(s):

1. **Visual Render View (Side-by-Side)**:
   * Synchronized pan & zoom (`InteractiveViewer` with linked `TransformationController`s so zooming in on a node or arrowhead zooms all active panes to the same region).
   * Light / Dark theme toggle.
   * Header telemetry pills showing render duration (`ms`), `viewBox` dimensions (`W × H`), and SVG byte/element counts for each engine.
2. **Visual Graphic Diff View (Overlay Comparison of Any 2 Renderers)**:
   * Compares the rendered graphics of any two selected engines (e.g., `pele_dart` vs. `obsidianmd/pele` JS, or `pele_dart` vs. `mermaid.js`) inside a single locked pan/zoom viewport with four sub-modes:
     * **Split-Curtain (Swipe Slider)**: Stacks Renderer A and Renderer B in the same coordinate space with a draggable vertical divider (`ClipRect`) to wipe seamlessly across the diagram.
     * **Cyan / Magenta Channel Overlay**: Tints Renderer A in **Cyan** and Renderer B in **Magenta** via GPU `ColorFiltered` + `BlendMode.multiply` (light mode) / `BlendMode.screen` (dark mode). Identical overlapping geometry blends to neutral gray/black, while any shifted edge, arrowhead, or label glows bright **Cyan** (only in A) or **Magenta** (only in B) at full 60/120 fps.
     * **Pixel-Diff Heatmap & Match Score**: Rasterizes both renders to `2x`/`3x` RGBA `ByteData` buffers at identical logical scale and computes a pixel-by-pixel diff in a background `Isolate`, dimming matching pixels to a faint 15%-opacity context layer, highlighting differing pixels in bright red, and displaying a `% pixel match` badge in the toolbar.
     * **In-Place Blink / Onion-Skin**: Press `Space` (or use an auto-blink toggle / opacity cross-fade slider) to flip between Renderer A and Renderer B in place so subtle layout shifts pop out immediately.
3. **Raw SVG Output View**:
   * Displays the **pretty-printed, syntax-highlighted SVG XML text** side-by-side (or single-pane) for each active renderer.
   * For `pele_dart`, includes a toggle to inspect either the **`flattened` SVG** (what `vector_graphics_compiler` consumes) or the **`cssVariables` SVG** (upstream parity output).
   * Includes search/filter within the SVG markup and one-click **"Copy SVG"**.
4. **SVG Text Diff View (Built-in + External Diff Tool Launcher)**:
   * **Built-in Normalized SVG Diff**: Normalizes and pretty-prints the SVG XML from any two selected sources (e.g., `pele_dart (cssVariables)` vs. `obsidianmd/pele (JS)`, or `pele_dart (flattened)` vs. `pele_dart (cssVariables)`) with deterministic attribute ordering and one element per line, rendering an inline unified/split text diff with green/red line highlights and a diff count badge (`0 differences` when byte-identical).
   * **"Open in External Diff Tool" Button**: Writes the two selected pretty-printed SVG outputs to temporary `.svg` files in `Directory.systemTemp` and invokes an external macOS diff tool (`opendiff` / Xcode FileMerge, `code --diff`, `ksdiff`, `bcomp`, or a user-configured CLI command) for deep structural diffing.

### 6.4 Curated 33-Diagram Gallery & Scratchpad Editor
* **Left Sidebar Gallery**: Categorized tree of all 33 diagram families with multiple test cases per family (basic, complex routing, subgraphs, styling/theming, edge cases) plus pass/diff status badges.
* **Collapsible Live Source Editor**: Edit any gallery fixture or paste custom Mermaid syntax to see all active renderers and SVG diffs update in real time.

---

## 7. Phased Development & Verification Plan

### Phase 0: Repository & Verification Harness
* Finalize `docs/DESIGN.md`, `AGENTS.md`, `UPSTREAM.md`, and `pubspec.yaml`.
* Build `tool/verify_against_upstream.dart`: a CLI verification script that reads the pinned commit SHA from [`UPSTREAM.md`](../UPSTREAM.md), checks out `obsidianmd/pele` at that commit into `.upstream/` (gitignored), runs Node on upstream `pele.render(code)` and Dart on `pele_dart`'s `renderMermaid(code)`, and verifies:
  1. **Parity check (`SvgOutputMode.cssVariables`)**: Normalized SVG XML/AST comparison against upstream Pele.
  2. **Vector compiler check (`SvgOutputMode.flattened`)**: Compiles the flattened SVG using `package:vector_graphics_compiler` (`encodeSvg`) and asserts zero errors.

### Phase 1: Shared Core Infrastructure (~25 files)
Port and unit-test the foundation modules in dependency order:
1. `lib/src/types.dart`, `lib/src/models.dart`, `lib/src/errors.dart`
2. `lib/src/util/` (`math_js.dart`, `chars.dart`, `unicode.dart`, `url.dart`, `yaml.dart`)
3. `lib/src/text/` (`entities.dart`, `metrics.dart`, `measurer.dart`, `label.dart`, `icons.dart`, `math.dart`)
4. `lib/src/layout/` (`components.dart`, `lanes.dart`, `layered.dart`, `compound.dart`)
5. `lib/src/svg/` (`palette.dart`, `ink.dart`, `theme.dart`, `builder.dart`, `shapes.dart`, `edges.dart`, `cluster.dart`, `title.dart`, `root.dart`, `flattener.dart`)
6. `lib/src/preprocess.dart`, `lib/src/detect.dart`, `lib/src/core.dart`, `lib/src/diagrams/common/`, `lib/src/diagrams/registry.dart`

### Phase 2: Tier-1 Diagrams (9 Diagram Families) + macOS 3-Way Comparison App (`example/`)
* Port the 9 highest-usage diagram types and their upstream `tests/compat/` and `tests/render/` test suites:
  * `flowchart`, `sequence`, `class`, `state`, `er`, `gantt`, `git`, `mindmap`, `pie`
* Build the `example/` macOS 3-Way Gallery & SVG Diff Workbench so every ported diagram can be visually and structurally compared against `obsidianmd/pele` (JS) and `mermaid.js`.

### Phase 3: Tier-2 Diagrams (Remaining 24 Diagram Families)
Because Phase 1’s core is frozen and every diagram module under `lib/src/diagrams/<type>/` is hermetically isolated, port the remaining 24 diagram families in parallel batches:
* **Batch A (Architecture & Systems)**: `architecture`, `c4`, `block`, `packet`, `requirement`, `usecase`
* **Batch B (Process & Flows)**: `agentflow`, `eventmodeling`, `journey`, `kanban`, `railroad`, `swimlane`, `timeline`
* **Batch C (Data & Charts)**: `quadrant`, `radar`, `sankey`, `treemap`, `treeview`, `venn`, `xychart`
* **Batch D (Strategy & Misc)**: `cynefin`, `ishikawa`, `wardley`, `info`

---

## 8. Upstream Maintenance & Sync Lifecycle

Because `obsidianmd/pele` is actively evolving, `pele_dart` is designed from day one for **low-friction, automated upstream synchronization** with a **single source of truth** for the upstream pin.

### 8.1 Single Source of Truth ([`UPSTREAM.md`](../UPSTREAM.md)) & Static File Headers
* **The pinned upstream release tag and commit SHA live exclusively in [`UPSTREAM.md`](../UPSTREAM.md)**. They are never duplicated in Dart constants or per-file comments.
* Every Dart file under `lib/src/` carries a static path comment on line 1 mapping it to its upstream TypeScript file (without a commit SHA suffix that would go stale on every sync):
  ```dart
  // Upstream: src/diagrams/flowchart/layout.ts
  ```

### 8.2 Automated Upstream Sync Tool (`tool/sync_upstream.dart`)
When a new version of `obsidianmd/pele` is released (e.g., `v1.14.0`), running:
```bash
dart run tool/sync_upstream.dart --target=v1.14.0
```
performs the following automated workflow:
1. Reads the currently pinned `Target Commit SHA` directly from [`UPSTREAM.md`](../UPSTREAM.md) (`<old-sha>`).
2. Fetches the latest commits/tags from `https://github.com/obsidianmd/pele` into `.upstream/`.
3. Runs `git -C .upstream diff --name-status <old-sha>..<target-sha> -- src/ tests/`.
4. Maps every changed upstream TypeScript file (`src/diagrams/sequence/parser.ts`) to its exact Dart counterpart (`lib/src/diagrams/sequence/parser.dart`).
5. Emits a structured **Sync Report & Task Breakdown** containing:
   * Newly added files, modified files, and deleted files grouped by module (`core`, `layout`, `svg`, or `diagrams/<type>`).
   * The exact per-file unified diff (`git diff <old-sha>..<target-sha> -- <file>`) ready to be translated into Dart.

### 8.3 Differential Regression Gate
After applying an upstream diff to `lib/src/<module>/`:
1. Run `dart run tool/verify_against_upstream.dart --diagram=<type>` to verify that `pele_dart` in `SvgOutputMode.cssVariables` matches the new upstream `obsidianmd/pele` output across all corpus fixtures.
2. Run `dart test` to verify that `SvgOutputMode.flattened` compiles every fixture cleanly through `vector_graphics_compiler`.
3. Update the `Target Release`, `Target Commit SHA`, and module status table in [`UPSTREAM.md`](../UPSTREAM.md).

---

## 9. Agentic Coding Architecture & Considerations

Because `pele_dart` will be built and maintained heavily by AI coding agents, the repository is structured specifically to maximize agent accuracy, parallelism, and self-verification:

### 9.1 `AGENTS.md` as the Enforced Contract
* [`AGENTS.md`](../AGENTS.md) at the repository root is kept concise, prescriptive, and always loaded into agent context.
* It codifies the **4 non-negotiable invariants**:
  1. 1:1 upstream file/symbol parity (`src/<path>.ts` ↔ `lib/src/<path>.dart`) with [`UPSTREAM.md`](../UPSTREAM.md) as the single source of truth for the upstream pin.
  2. Hermetic isolation between `lib/src/diagrams/<type>/` directories.
  3. Dual SVG emission (`SvgOutputMode.flattened` + `SvgOutputMode.cssVariables`).
  4. Strict TypeScript-to-Dart semantic helpers (`math_js.dart` 32-bit bitwise ops, `jsSlice`, `fmtNum`).

### 9.2 Hermetic Boundaries for Multi-Agent Parallelism
* A common failure mode when running multiple agents in parallel is merge conflicts in shared files (such as `registry.dart`, `pubspec.yaml`, or barrel exports).
* To prevent this:
  * During **Phase 1**, `lib/src/diagrams/registry.dart` and all 33 directory stubs (`lib/src/diagrams/<type>/`) are pre-created and registered once.
  * During **Phase 2 and Phase 3**, each parallel agent task is scoped strictly to **one diagram directory**: `lib/src/diagrams/<type>/` and `test/diagrams/<type>_test.dart`.
  * Because no diagram directory touches any file outside `lib/src/diagrams/<type>/` and `test/diagrams/<type>_test.dart`, multiple agents can port different diagram families simultaneously on separate git worktrees or branches with **zero merge conflicts**.

### 9.3 Self-Contained Agent Verification Loop
Agents perform best when they have a fast, deterministic oracle that tells them *why* a port differs from upstream. We provide two fast CLI tools for agents:
1. **`dart run tool/verify_against_upstream.dart --diagram=<type>`**:
   * Runs the specific diagram’s test corpus through both upstream `obsidianmd/pele` (in `.upstream/` at the SHA parsed from `UPSTREAM.md`) and `pele_dart`, printing the first SVG element or attribute diff if the Dart port diverges from TypeScript.
2. **`dart test test/diagrams/<type>_test.dart`**:
   * Runs the ported unit tests **and** passes every generated flattened SVG through `vector_graphics_compiler.encodeSvg()` in under 2 seconds, catching any unsupported SVG attribute or malformed path data immediately.

### 9.4 Commit Hygiene & Issue-First Workflow
* All porting phases and upstream syncs are tracked via GitHub Issues on `tkinnis/pele_dart`.
* Every commit must pass `dart analyze --fatal-infos`, `dart test`, and `dart format --set-exit-if-changed`, follow **Conventional Commits** (`feat(flowchart): port flowchart parser, layout, and renderer`), and strictly adhere to the **NO AI references** policy.

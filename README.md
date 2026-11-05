# `pele_dart`

A fast, deterministic, zero-DOM **pure Dart** Mermaid diagram rendering engine ported from [`obsidianmd/pele`](https://github.com/obsidianmd/pele).

## Highlights

* **Pure Dart 3 (`sdk: ^3.13.0`)**: Zero browser (`WKWebView` / `WebKitGTK` / `WebView2`), zero JavaScript engine (`QuickJS` / `JavaScriptCore`), and zero Flutter SDK dependency in the core package.
* **Dual SVG Output Modes**:
  1. **`SvgOutputMode.flattened`**: Directly emits pre-flattened SVG primitives (`<path>`, `<rect>`, `<circle>`, `<ellipse>`, `<line>`, `<polyline>`, `<polygon>`, `<text>`, `<g>`, `<clipPath>`, gradients) with resolved palette colors, stamped arrowhead geometry instead of `<marker>`, and explicit baseline `y` coordinates—ready for immediate compilation via `vector_graphics_compiler` (`encodeSvg`).
  2. **`SvgOutputMode.cssVariables`** *(Upstream Parity Mode)*: Emits theme-reactive SVG styled via `--pele-*` CSS custom properties and `<marker>` definitions, matching upstream `obsidianmd/pele` output for web export and differential snapshot testing.
* **Built-in Safety & DoS Limits**: Enforces pre-parse and post-parse resource budgets (source characters, node/edge counts, subgraph nesting depth, element count, path data length, and dash segment budgets).
* **macOS 3-Way Comparison Workbench (`example/`)**: A macOS desktop app for inspecting and diffing both visual diagram renders (side-by-side, split-curtain swipe, Cyan/Magenta channel overlay, pixel-diff heatmap, and blink mode) and raw SVG markup (inline diff + external diff launcher) across `pele_dart`, `obsidianmd/pele` (JS), and `mermaid.js`.

## Documentation

* **[`docs/DESIGN.md`](docs/DESIGN.md)**: Architecture, dual SVG emission strategy, TypeScript-to-Dart translation rules, 3-way macOS comparison app, phased rollout, upstream sync lifecycle, and agentic coding workflows.
* **[`UPSTREAM.md`](UPSTREAM.md)**: Single source of truth for the pinned `obsidianmd/pele` commit SHA, release tag, and per-module porting status matrix.
* **[`AGENTS.md`](AGENTS.md)**: Operational guidelines, architectural invariants, and verification gates for AI coding agents.

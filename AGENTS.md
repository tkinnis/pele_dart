# Agent Guidelines for `pele_dart`

This document defines the architectural invariants, directory conventions, translation rules, and verification gates for AI coding agents working on **`pele_dart`**.

---

## 1. Project Purpose & Scope

`pele_dart` is a pure-Dart port of [`obsidianmd/pele`](https://github.com/obsidianmd/pele) that renders Mermaid diagrams into SVG synchronously without a browser or JavaScript runtime.

* **SDK Boundary**: The root `pele_dart` package is pure Dart (`sdk: ^3.13.0`). **Never** add a dependency on `flutter` or `dart:ui` in the root `pubspec.yaml` `dependencies:`. (The macOS 3-way visual comparison workbench lives in `example/` with its own Flutter `pubspec.yaml`.)
* **Runtime Dependencies**: Keep `dependencies:` minimal (`package:meta` only). Do not add heavy third-party parsing, layout, or DOM libraries.
* **Synchronous & Deterministic**: Rendering (`renderMermaid()`) must execute synchronously with zero I/O, zero network access, and zero global mutable state across calls. Identical inputs, options, and text measurers must always produce byte-for-byte identical SVG output.

---

## 2. Core Architectural Invariants

### A. Strict 1:1 Upstream Structural Parity & Single-Source-of-Truth Pinning
* **[`UPSTREAM.md`](UPSTREAM.md) is the single source of truth** for the pinned `obsidianmd/pele` release tag, commit SHA, and per-module sync status. Never duplicate the upstream commit SHA or package version in Dart source constants or other markdown files.
* Every upstream file `src/<dir>/<name>.ts` in `obsidianmd/pele` maps to `lib/src/<dir>/<snake_name>.dart` in `pele_dart`.
* Every file in `lib/src/` must begin with a static header comment recording its upstream counterpart path (without a commit SHA suffix):
  ```dart
  // Upstream: src/layout/layered.ts
  ```
* Preserve upstream function names, class names, constants, and algorithmic structure wherever idiomatic in Dart 3. Do not reorganize files across directories or invent deep object hierarchies that diverge from `obsidianmd/pele`, as doing so breaks automated upstream diff syncing (`tool/sync_upstream.dart`).

### B. Hermetic Diagram Isolation
* Each diagram family under `lib/src/diagrams/<type>/` (`parser.dart`, `model.dart`, `layout.dart`, `render.dart`) may import only from:
  * Its own directory (`lib/src/diagrams/<type>/`)
  * `lib/src/diagrams/common/`
  * Shared core modules (`lib/src/layout/`, `lib/src/svg/`, `lib/src/text/`, `lib/src/util/`, `lib/src/models.dart`, `lib/src/types.dart`, `lib/src/errors.dart`)
* A diagram module must **never** import from another diagram module (unless explicitly delegating as upstream does), ensuring multiple agents can work on different diagram directories in parallel without conflicts.

### C. Dual SVG Emission (`SvgOutputMode`)
* `lib/src/svg/` supports two deterministic emission modes controlled by `PeleRenderOptions.outputMode`:
  1. **`SvgOutputMode.cssVariables`**: Emits upstream-compatible SVG using `var(--pele-*)` CSS custom properties, `<marker>` definitions, and `dominant-baseline`. Used for differential snapshot comparison against upstream `obsidianmd/pele` and `.svg` web export.
  2. **`SvgOutputMode.flattened`**: Emits `vector_graphics_compiler`-compliant SVG directly from `svg/builder.dart`, `svg/edges.dart`, and `svg/palette.dart`:
     * All `--pele-*` variables and `color-mix()` expressions are resolved against `PelePalette` into concrete `#RRGGBB` / `rgb(...)` fills and strokes plus explicit `fill-opacity` / `stroke-opacity`.
     * No `<style>`, `<marker>`, `<foreignObject>`, or nested `<svg>` elements are emitted.
     * Edge arrowheads (`marker-end`, `marker-start`) are stamped directly as transformed `<path>` / `<polygon>` elements at the edge path's start/end tangent.
     * `<text>` and `<tspan>` `dominant-baseline` attributes are converted into explicit `x` and `y` coordinate offsets.

### D. TypeScript-to-Dart Semantic Fidelity
When translating upstream TypeScript to Dart 3, respect these critical rules:
1. **32-Bit Bitwise Operations**: In JS, `x | 0`, `x >> n`, `x << n`, and `Math.imul` operate on signed 32-bit integers (`Int32`), whereas Dart `int` is 64-bit. Always wrap translated bitwise hash/PRNG math in `.toSigned(32)` / `.toUnsigned(32)` helpers in `lib/src/util/math_js.dart`.
2. **Array/String Slicing**: JS `Array.prototype.slice(start, end)` and `String.prototype.slice(start, end)` clamp out-of-bounds indices and support negative indices without throwing. Use `jsSlice()` / `jsSubstr()` helpers rather than raw `List.sublist()` / `String.substring()` when translating index math that may exceed bounds.
3. **Number Formatting**: SVG coordinate formatting must strip trailing zeros and never emit scientific notation (`1e-7`), matching upstream number formatting (`fmtNum()`).
4. **RegExp Semantics**: Translate JS `/y` (sticky) or `/g` `lastIndex` loops using `RegExp.matchAsPrefix(input, pos)` or `allMatches(input, pos)`.

---

## 3. Quality Gates & Verification

Before completing any task or committing changes, all quality gates must pass:

1. **Static Analysis**:
   ```bash
   dart analyze --fatal-infos
   ```
   Must report **0** errors, warnings, or lints.

2. **Unit, Compatibility & Vector-Compilation Tests**:
   ```bash
   dart test
   ```
   Every rendered diagram in `SvgOutputMode.flattened` must pass `vector_graphics_compiler` (`encodeSvg`) compilation in tests without warnings or errors.

3. **Formatting**:
   ```bash
   dart format --output=none --set-exit-if-changed lib test tool example/lib
   ```

4. **787-Diagram Upstream Differential Parity & Mermaid Version Check**:
   ```bash
   dart run tool/verify_against_upstream.dart
   ```
   Verifies Mermaid version consistency across `UPSTREAM.md`, `.upstream/`, and `example/assets/mermaid.min.js`, and asserts 100% byte-for-byte SVG equality between `pele_dart` and `obsidianmd/pele (JS)` across all 33 canonical diagram families, 232 gallery diagrams, and 522 upstream corpus diagrams (`787/787`).

5. **Upstream Sync & Release Workflow**:
   * Check for new `obsidianmd/pele` releases, commits, or target `mermaid.js` updates with `dart run tool/sync_upstream.dart` (`--check`).
   * Follow [`docs/UPSTREAM_SYNC.md`](docs/UPSTREAM_SYNC.md) and the workspace skill [`.agents/skills/sync-upstream-pele/SKILL.md`](.agents/skills/sync-upstream-pele/SKILL.md) to stage updates (`--update-to-latest`), port changes 1:1, refresh assets (`--refresh-assets`), verify parity, and update `UPSTREAM.md` (`--pin`).
   * Keep [`docs/API_MANUAL.md`](docs/API_MANUAL.md) updated whenever public options, APIs, or supported diagram families change.

6. **Commit Policy**:
   * Follow **Conventional Commits** (`feat(flowchart): ...`, `fix(layout): ...`, `test(sequence): ...`, `docs(design): ...`).
   * **Strict NO AI References Policy**: Never include `Co-Authored-By`, AI tool names, or agent attributions in commit messages, PR descriptions, or comments.

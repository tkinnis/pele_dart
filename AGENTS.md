# Agent Guidelines for `pele_dart`

This document defines the architectural invariants, directory conventions, translation rules, and verification gates for AI coding agents working on **`pele_dart`**.

---

## 1. Project Purpose & Scope

`pele_dart` is a pure-Dart port of [`obsidianmd/pele`](https://github.com/obsidianmd/pele) that renders Mermaid diagrams into SVG synchronously without a browser or JavaScript runtime.

* **SDK Boundary**: The root `pele_dart` package is pure Dart (`sdk: ^3.13.0`). **Never** add a dependency on `flutter` or `dart:ui` in the root `pubspec.yaml` `dependencies:`. (The macOS 3-way visual comparison workbench lives in `studio/` with its own Flutter `pubspec.yaml`.)
* **Runtime Dependencies**: Keep `dependencies:` minimal (`package:meta` only). Do not add heavy third-party parsing, layout, or DOM libraries.
* **Synchronous & Deterministic**: Rendering (`renderMermaid()`) must execute synchronously with zero I/O, zero network access, and zero global mutable state across calls. Identical inputs, options, and text measurers must always produce byte-for-byte identical SVG output.

---

## 2. Core Architectural Invariants

### A. Strict 1:1 Upstream Structural Parity & Lockstep Versioning
* **[`UPSTREAM.md`](UPSTREAM.md) is the single source of truth** for the pinned `obsidianmd/pele` release tag, commit SHA, and per-module sync status.
* **1:1 Version Lockstep (`pubspec.yaml` ↔ `UPSTREAM.md` ↔ `lib/src/diagrams/info/render.dart` ↔ Git Tag)**:
  * `pele_dart`'s `major.minor.patch` version in `pubspec.yaml` and `peleVersion` in `lib/src/diagrams/info/render.dart` must **always** match `Target Release` in `UPSTREAM.md` (i.e., `version: <X.Y.Z>` for upstream `v<X.Y.Z>`, tagged as `v<X.Y.Z>`).
  * If a Dart-only hotfix is required between upstream `obsidianmd/pele` releases, increment only the Dart build suffix (`<X.Y.Z>+1`, `<X.Y.Z>+2`, tagged as `v<X.Y.Z>+1`) so `major.minor.patch` remains strictly locked to the synced upstream release.
  * Never hardcode release version numbers in documentation prose (`README.md`, `doc/*.md`, `SECURITY.md`); all docs must reference `UPSTREAM.md` or `pubspec.yaml`.
  * This invariant is automatically enforced by `tool/sync_upstream.dart`, `tool/verify_against_upstream.dart`, and `test/doc_examples_test.dart`.
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
  * Shared core modules (`lib/src/layout/`, `lib/src/svg/`, `lib/src/text/`, `lib/src/util/`, `lib/src/preprocess.dart`, `lib/src/types.dart`, `lib/src/errors.dart`)
* A diagram module must **never** import from another diagram module (unless explicitly delegating as upstream does), ensuring multiple agents can work on different diagram directories in parallel without conflicts.

### C. Dual SVG Emission (`SvgOutputMode`)
* `lib/src/svg/` supports two deterministic emission modes controlled by `RenderOptions.outputMode`:
  1. **`SvgOutputMode.cssVariables`**: Emits upstream `obsidianmd/pele`'s exact byte-for-byte SVG using `var(--pele-*)` and `var(--_*)` CSS custom properties and `color-mix(in srgb, ...)`. Used for differential snapshot comparison against upstream `obsidianmd/pele` and `.svg` web export.
  2. **`SvgOutputMode.flattened`** (`lib/src/svg/flattener.dart`): Converts the rendered SVG into static SVG 1.1 compatible with `vector_graphics_compiler` (`encodeSvg`) and non-CSS SVG renderers:
     * All `--pele-*` and `--_*` CSS custom properties, `color-mix(in srgb, ...)` blends, `calc(...)` expressions, and `currentColor` are resolved against `PelePalette` into concrete `#rrggbb` and numeric SVG attributes.
     * `<tspan>` `baseline-shift="sub|super" font-size="smaller"` attributes are converted into explicit `dy="3|-4" font-size="10"` attributes.
     * Inline `style="..."` presentation/geometry properties (`rx`, `ry`, `fill`, `stroke`, `stroke-width`, etc.) are promoted to native SVG 1.1 attributes, and `font-family` / `font-size` are attached directly to the root `<svg>`.

### D. TypeScript-to-Dart Semantic Fidelity
When translating upstream TypeScript to Dart 3, respect these critical rules:
1. **32-Bit Bitwise Operations**: In JS, `x | 0`, `x >> n`, `x << n`, and `Math.imul` operate on signed 32-bit integers (`Int32`), whereas Dart `int` is 64-bit. Always wrap translated bitwise hash/PRNG math in `.toSigned(32)` / `.toUnsigned(32)` helpers in `lib/src/util/math_js.dart`.
2. **Array/String Slicing**: JS `Array.prototype.slice(start, end)` and `String.prototype.slice(start, end)` clamp out-of-bounds indices and support negative indices without throwing. Use `jsSlice()` / `jsSubstr()` helpers rather than raw `List.sublist()` / `String.substring()` when translating index math that may exceed bounds.
3. **Number Formatting**: SVG coordinate formatting must strip trailing zeros and never emit scientific notation (`1e-7`), matching upstream number formatting (`fmtNum()`).
4. **RegExp Semantics & Dart AOT Hot Paths**:
   * Translate JS `/y` (sticky) or `/g` `lastIndex` loops using `RegExp.matchAsPrefix(input, pos)` or `allMatches(input, pos)`.
   * **Preserve Dart AOT Hot-Path Optimizations**:
     * In `lib/src/detect.dart`, maintain the leading-whitespace skip + first-character `switch` dispatch returning `const Detected` instances (never replace with a sequential `RegExp` list scan).
     * In `lib/src/diagrams/common/tokens.dart`, keep `re: RegExp(...)` on each `TokenType` for 1:1 upstream diffing alongside fast `match` closures and `_compileFastMatcher` / `_inferFirstChars` in `_prepare()`. When an upstream sync changes a token regex that also has an explicit `match` closure, update both in lockstep.
     * In `lib/src/diagrams/common/outline.dart`, `lib/src/text/label.dart`, `lib/src/preprocess.dart`, and `lib/src/util/yaml.dart`, preserve `codeUnitAt` scanning and slice-based `StringBuffer.write(source.substring(start, end))` instead of per-character `String` indexing (`s[i]`) or backtracking regexes in inner loops.
     * In `lib/src/diagrams/gantt/dates.dart`, keep `_MDate._w` lazy so `DateTime.timeZoneOffset` (`localtime_r` OS syscall) is only queried when local wall-clock fields are read.

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
   dart format --output=none --set-exit-if-changed lib test tool studio/lib example/main.dart
   ```

4. **Upstream Differential Parity & Mermaid Version Check**:
   ```bash
   dart run tool/verify_against_upstream.dart
   ```
   Verifies Mermaid version consistency across `UPSTREAM.md`, `.upstream/`, and `studio/assets/mermaid.min.js`, and asserts 100% byte-for-byte SVG equality between `pele_dart` and `obsidianmd/pele (JS)` across all canonical diagram families, gallery diagrams, and upstream corpus diagrams.

5. **Native AOT Benchmark Report & Regression Gate**:
   ```bash
   dart run tool/benchmark_suite.dart --update-docs --check-regressions
   ```
   Compiles `pele_dart` to native AOT (`dart compile exe`), benchmarks all supported diagram families in the gallery corpus against `obsidianmd/pele (JS)`, updates [`doc/BENCHMARKS.md`](doc/BENCHMARKS.md), and enforces non-regression against [`tool/benchmark_baseline.json`](tool/benchmark_baseline.json).

6. **Upstream Sync & Release Workflow**:
   * Check for new `obsidianmd/pele` releases, commits, or target `mermaid.js` updates with `dart run tool/sync_upstream.dart` (`--check`).
   * Follow [`doc/UPSTREAM_SYNC.md`](doc/UPSTREAM_SYNC.md) and the workspace skill [`.agents/skills/sync-upstream-pele/SKILL.md`](.agents/skills/sync-upstream-pele/SKILL.md) to stage updates (`--update-to-latest`), port changes 1:1, refresh assets (`--refresh-assets`), verify parity (`tool/verify_against_upstream.dart`), verify benchmarks (`tool/benchmark_suite.dart --update-docs --check-regressions`), and update `UPSTREAM.md` (`--pin`).
   * Keep [`doc/API_MANUAL.md`](doc/API_MANUAL.md) and [`doc/BENCHMARKS.md`](doc/BENCHMARKS.md) updated whenever public options, APIs, supported diagram families, or upstream releases change.

7. **Commit Policy**:
   * Follow **Conventional Commits** (`feat(flowchart): ...`, `fix(layout): ...`, `test(sequence): ...`, `docs(design): ...`).
   * **Strict NO AI References Policy**: Never include `Co-Authored-By`, AI tool names, or agent attributions in commit messages, PR descriptions, or comments.

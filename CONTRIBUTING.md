# Contributing to `pele_dart`

Thank you for your interest in contributing to **`pele_dart`**!

`pele_dart` is a 1:1 **pure-Dart** port of [**`obsidianmd/pele`**](https://github.com/obsidianmd/pele) ([`pele.run`](https://pele.run))—the deterministic, zero-DOM Mermaid diagram-to-SVG rendering engine created by [**Steph Ango (`kepano`)**](https://github.com/kepano) and the [**Obsidian**](https://obsidian.md) team.

Before opening an issue or submitting a pull request, please review our architectural invariants and upstream parity guidelines below.

---

## 1. Core Architectural Invariants

To keep `pele_dart` lightweight, deterministic, and easy to synchronize with upstream `obsidianmd/pele`, all contributions must follow these principles:

1. **Pure-Dart SDK Boundary (`lib/`)**:
   - Everything under `lib/` must depend strictly on standard Dart core libraries (`dart:core`, `dart:math`, `dart:convert`, `dart:typed_data`) with zero external runtime package imports (the root `pubspec.yaml` `dependencies:` lists only `package:meta`).
   - **Never** import `package:flutter`, `dart:ui`, `dart:io`, or `dart:html` inside `lib/`. This guarantees `pele_dart` runs identically on Flutter mobile/desktop/web, Dart CLI tools, server-side executables, and background isolates.
2. **1:1 Upstream Parity with `obsidianmd/pele`**:
   - Core parsers (`lib/src/diagrams/*/parser.dart`), layout algorithms (`lib/src/layout/`), and SVG renderers (`lib/src/diagrams/*/render.dart`) mirror the upstream TypeScript modules in [`obsidianmd/pele`](https://github.com/obsidianmd/pele) 1:1.
   - If you discover a diagram grammar or layout bug that **also reproduces in upstream `obsidianmd/pele`** ([`pele.run`](https://pele.run)), we encourage reporting or fixing it upstream first so both ecosystems benefit, or clearly noting in your issue/PR whether the behavior diverges from `obsidianmd/pele` or matches `obsidianmd/pele` while differing from `mermaid.js`.
3. **Dart-Specific Value-Add Extensions**:
   - Features specifically built for the Dart & Flutter ecosystem—such as [`SvgOutputMode.flattened`](lib/src/svg/flattener.dart) (for `vector_graphics` / `flutter_svg`), [`PelePalette`](lib/src/types.dart) theme tokens, and the pluggable [`TextMeasurer`](lib/src/text/measurer.dart) interface—live cleanly alongside the 1:1 upstream pipeline without altering default `render()` parity.
4. **Core Library Palette Cleanliness**:
   - `PelePalette` ships only with the two foundational base defaults (`PelePalette.light` and `PelePalette.dark`). Custom application palettes belong in consumer code or in `studio/`.

---

## 2. Development Setup

### Prerequisites

- **Dart SDK**: `^3.13.0` (or Flutter SDK for running the `studio/` macOS comparison studio).
- **Bun / Node.js** *(optional)*: Only needed when running `tool/sync_upstream.dart` or `tool/verify_against_upstream.dart` against a local `.upstream/` clone of `obsidianmd/pele`.

### Cloning & Installing Dependencies

```bash
git clone https://github.com/tkinnis/pele_dart.git
cd pele_dart
dart pub get
```

---

## 3. Quality Gates & Verification

Every pull request must pass all quality gates before merging:

### 1. Code Formatting
```bash
dart format --output=none --set-exit-if-changed lib test tool studio/lib example/main.dart
```

### 2. Static Analysis (Zero Warnings / Infos)
```bash
dart analyze --fatal-infos lib test tool
```

### 3. Test Suite
```bash
dart test
```

### 4. Upstream 1:1 Parity Verification *(when `.upstream/` is present)*
To check for upstream `obsidianmd/pele` updates or verify byte-for-byte SVG parity across all canonical, gallery, and test corpus diagrams:
```bash
dart run tool/sync_upstream.dart --check
dart run tool/verify_against_upstream.dart
```

### 5. Documentation & SVG Gallery Regeneration
If your change affects rendering output, themes, or documentation examples, regenerate the embedded SVG gallery and verify XML validity:
```bash
dart run tool/generate_doc_images.dart
xmllint --noout doc/images/diagrams/*.svg doc/images/styles/*.svg
```

---

## 4. Commit Message & Pull Request Guidelines

We follow the [**Conventional Commits**](https://www.conventionalcommits.org/) specification:

- `feat(scope): ...` — New features or diagram capabilities.
- `fix(scope): ...` — Bug fixes in parsing, layout, rendering, or SVG flattening.
- `docs(scope): ...` — Documentation, Dartdoc comments, or SVG gallery updates.
- `refactor(scope): ...` — Internal code restructuring without behavioral changes.
- `test(scope): ...` — Adding or expanding unit, golden, or parity tests.
- `chore(scope): ...` — CI, tooling, or upstream synchronization updates.

When submitting a pull request:
1. Keep changes focused on a single concern.
2. Add unit tests in `test/` covering any bug fix or new capability.
3. Reference any related GitHub Issues (`Closes #123` or `Refs #123`).

---

## 5. Code of Conduct

Please note that this project is released with a [Contributor Code of Conduct](CODE_OF_CONDUCT.md). By participating in this project you agree to abide by its terms.

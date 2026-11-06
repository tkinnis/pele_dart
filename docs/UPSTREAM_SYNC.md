# Upstream Sync, Differential Verification & Release Guide

`pele_dart` maintains a strict 1:1 structural and behavioral correspondence with [`obsidianmd/pele`](https://github.com/obsidianmd/pele). This guide explains how developers and AI coding agents detect new upstream `obsidianmd/pele` releases, track target `mermaid.js` baseline updates, fold in bug fixes or new diagram types, verify 100% byte-for-byte SVG parity across 787+ diagrams, and publish a new release.

---

## Table of Contents

1. [Quick Reference Commands](#1-quick-reference-commands)
2. [How Upstream Tracking Works (`UPSTREAM.md`)](#2-how-upstream-tracking-works-upstreammd)
3. [Checking for Upstream Releases & Mermaid Version Changes](#3-checking-for-upstream-releases--mermaid-version-changes)
4. [Staging an Upstream Update (`--update-to-latest`)](#4-staging-an-upstream-update---update-to-latest)
5. [Agentic Sync Workflow (`.agents/skills/sync-upstream-pele`)](#5-agentic-sync-workflow-agentsskillssync-upstream-pele)
6. [Playbooks by Upstream Change Category](#6-playbooks-by-upstream-change-category)
   - [A. Bug Fixes & Layout Tweaks](#a-bug-fixes--layout-tweaks)
   - [B. Beta-to-Stable Diagram Promotions (`-beta` Removal)](#b-beta-to-stable-diagram-promotions--beta-removal)
   - [C. New Diagram Families](#c-new-diagram-families)
   - [D. Target `mermaid.js` or `@mermaid-js/parser` Version Updates](#d-target-mermaidjs-or-mermaid-jsparser-version-updates)
7. [787-Diagram Differential Verification Suite](#7-787-diagram-differential-verification-suite)
8. [Finalizing & Releasing a New Version](#8-finalizing--releasing-a-new-version)

---

## 1. Quick Reference Commands

| Task | Command |
| :--- | :--- |
| **Check for new `obsidianmd/pele` releases, commits & Mermaid version updates** | `dart run tool/sync_upstream.dart` *(or `--check`)* |
| **Emit machine-readable JSON status for CI or agents** | `dart run tool/sync_upstream.dart --check --json` |
| **Stage the latest upstream release, generate `.upstream/diff_report.md` & refresh JS bundles** | `dart run tool/sync_upstream.dart --update-to-latest` |
| **Stage a specific tag, branch, or commit SHA** | `dart run tool/sync_upstream.dart --update-to <tag_or_ref>` |
| **Inspect categorized upstream->Dart diffs for any git range** | `dart run tool/sync_upstream.dart --diff <from_tag>..<to_tag>` |
| **Re-bundle `pele.bundle.js`, sync `mermaid.min.js`, and regenerate `docs/images/` & `docs/DIAGRAM_GALLERY.md`** | `dart run tool/sync_upstream.dart --refresh-assets` |
| **Run the 787-diagram 100% differential parity & Mermaid version check** | `dart run tool/verify_against_upstream.dart` |
| **Run the native AOT benchmark suite, update [`docs/BENCHMARKS.md`](BENCHMARKS.md) & verify zero regressions** | `dart run tool/benchmark_suite.dart --update-docs --check-regressions` |
| **Finalize `UPSTREAM.md` pin after porting and verifying** | `dart run tool/sync_upstream.dart --pin <tag> <sha>` |

---

## 2. How Upstream Tracking Works (`UPSTREAM.md`)

[`UPSTREAM.md`](../UPSTREAM.md) is the single source of truth for the upstream baseline that `pele_dart` is synchronized against:

- **Pinned Release Tag**: The exact `obsidianmd/pele` release tag (`v<X.Y.Z>`).
- **Pinned Commit SHA**: The full 40-character commit hash corresponding to that release.
- **Target Mermaid Version**: The `mermaid` npm version that upstream `obsidianmd/pele` benchmarks and matches against in `scripts/bench-mermaid.mjs` and `website/package.json` (e.g., `12.1.0`).
- **Target Mermaid Parser**: The `@mermaid-js/parser` version in upstream `package.json` (e.g., `@mermaid-js/parser@2.0.1`).

Every Dart file under `lib/src/` maps 1:1 to an upstream TypeScript file under `src/` and begins with a tracking header:

```dart
// Upstream: src/diagrams/flowchart/layout.ts
```

---

## 3. Checking for Upstream Releases & Mermaid Version Changes

You do not need to manually watch the `obsidianmd/pele` repository. Run a single command from the repository root:

```bash
dart run tool/sync_upstream.dart
```

### What `--check` Does Automatically

1. Ensures `.upstream/` is cloned from `https://github.com/obsidianmd/pele.git` and runs `git fetch --tags origin --prune`.
2. Compares the **Pinned Release Tag** and **Pinned Commit SHA** in `UPSTREAM.md` against:
   - The latest semver release tag published on GitHub (`v*`), listing every new release tag between your pinned version and the latest release.
   - Any unreleased commits on `origin/main` ahead of the latest tag.
3. Inspects the target upstream ref's `scripts/bench-mermaid.mjs`, `website/package.json`, `website/pnpm-lock.yaml`, and `package.json` to detect the **Target Mermaid Version** and **Target Mermaid Parser**, and checks the header of `example/assets/mermaid.min.js`.
4. Categorizes every changed upstream file into actionable buckets:
   - **Detection & Beta-to-Stable Renames (`src/detect.ts`)**: Highlights added/removed/renamed diagram detector regexes (such as `radar-beta` becoming `radar(-beta)?`).
   - **New Diagram Families (`src/diagrams/<new>/`)**: Flags brand-new diagram directories not yet present in `lib/src/diagrams/`.
   - **Modified Diagram Families (`src/diagrams/<type>/`)**: Lists each modified diagram module alongside its exact Dart target file (`lib/src/diagrams/<type>/...`).
   - **Core / Shared Layout / SVG / Text Modules (`src/...`)**: Lists shared infrastructure changes and their mapped Dart files.
   - **Gallery & Website Showcase (`website/src/lib/examples.ts`)**: Flags changes to the showcase samples.
   - **Test Suite & Corpus (`tests/**`)**: Flags new or updated golden corpus cases.
5. Prints a clear status banner (`UP TO DATE` or `UPSTREAM UPDATES AVAILABLE`) and the exact command to stage the update.

---

## 4. Staging an Upstream Update (`--update-to-latest`)

When `dart run tool/sync_upstream.dart` reports a new release (or if you want to pull a specific ref), run:

```bash
dart run tool/sync_upstream.dart --update-to-latest
```

Or target a specific tag/branch/commit:

```bash
dart run tool/sync_upstream.dart --update-to v1.14.0
```

### What `--update-to-latest` Does Automatically

1. **Checks out the target ref** in `.upstream/`.
2. **Generates `.upstream/diff_report.md`** containing the full categorized file matrix, detector changes, Mermaid version status, and unified `git diff` patches for every changed file in `src/`.
3. **Re-bundles `example/assets/pele.bundle.js`** from `.upstream/src/index.ts` (via `bun build`) and appends the `globalThis.Pele` and `globalThis.PeleMetricsMeasurer` exports required by both the macOS 3-Way Comparison App and the CLI differential test runner.
4. **Downloads the matching `mermaid.min.js`** from `https://unpkg.com/mermaid@<version>/dist/mermaid.min.js` into `example/assets/mermaid.min.js` and updates the engine label in `example/lib/engine_runner.dart` whenever the target Mermaid version changes.
5. **Regenerates standalone documentation images** (`docs/images/diagrams/*.svg`, `docs/images/styles/*.svg`, and [`docs/DIAGRAM_GALLERY.md`](DIAGRAM_GALLERY.md)) via `tool/generate_doc_images.dart` from the `.mmd`/`.mermaid` files in `example/diagrams/`.

> **Note:** When source files have changed (`totalChangedFiles > 0`), `--update-to-latest` stages `.upstream/` and leaves `UPSTREAM.md` at the old pin until the Dart port changes are complete and verified (unless `--pin` is also passed), so `dart run tool/sync_upstream.dart --diff` continues to know the exact `from..to` range being ported.

---

## 5. Agentic Sync Workflow (`.agents/skills/sync-upstream-pele`)

This repository includes a dedicated Agent Skill at [`.agents/skills/sync-upstream-pele/SKILL.md`](../.agents/skills/sync-upstream-pele/SKILL.md).

After running `dart run tool/sync_upstream.dart`, you can simply ask your AI coding agent:

> *"Check for upstream Pele updates and sync the repository using the `sync-upstream-pele` skill."*

The agent will:
1. Run `dart run tool/sync_upstream.dart --check` to inspect new releases, commits, and Mermaid version changes.
2. Run `dart run tool/sync_upstream.dart --update-to-latest` to stage `.upstream/`, generate `.upstream/diff_report.md`, and refresh the JS/gallery/Mermaid assets.
3. Port every TypeScript change in `.upstream/diff_report.md` 1:1 into `lib/src/` and `test/`, preserving the Dart AOT hot-path patterns documented in [`docs/BENCHMARKS.md`](BENCHMARKS.md).
4. Run `dart run tool/verify_against_upstream.dart` until **100%** of canonical, gallery, and corpus diagrams match byte-for-byte.
5. Run `dart run tool/benchmark_suite.dart --update-docs --check-regressions` to refresh [`docs/BENCHMARKS.md`](BENCHMARKS.md) and confirm zero performance regressions across all 33 diagram families (optimizing any newly synced regex or string hot path before proceeding).
6. Update `UPSTREAM.md` via `dart run tool/sync_upstream.dart --pin <tag> <sha>`, bump `pubspec.yaml` and `CHANGELOG.md`, and prepare the release commit.

---

## 6. Playbooks by Upstream Change Category

### A. Bug Fixes & Layout Tweaks

1. Open `.upstream/diff_report.md` (or run `dart run tool/sync_upstream.dart --diff --patch`).
2. Locate each modified upstream `.ts` file and open its 1:1 Dart counterpart shown in the report (`src/<dir>/<name>.ts` → `lib/src/<dir>/<snake_name>.dart`).
3. Port the logic 1:1, preserving TypeScript-to-Dart semantic rules:
   - Signed/unsigned 32-bit bitwise operations (`.toSigned(32)` / `.toUnsigned(32)` in `lib/src/util/math_js.dart`).
   - Safe clamping array/string slicing (`jsSlice` / `jsSubstr`).
   - Number formatting without trailing zeros or scientific notation (`fmtNum`).
4. Port any new unit or regression tests added under `.upstream/tests/` into `test/`.

### B. Beta-to-Stable Diagram Promotions (`-beta` Removal)

When Mermaid or upstream `obsidianmd/pele` promotes a diagram out of beta (for example, changing `^\s*radar-beta` to `^\s*radar(-beta)?` or renaming a `MermaidType` identifier):

1. **`lib/src/detect.dart`**: Update the `_detectors` table regex, ordering, and `(DiagramType, MermaidType, RegExp)` tuple to match `.upstream/src/detect.ts` 1:1.
2. **`lib/src/diagrams/<type>/parser.dart`**: Update the header-stripping regex in the diagram's parser so both the stable keyword (e.g., `radar`) and legacy beta keyword (`radar-beta`) are accepted if upstream supports both.
3. **`test/detect_test.dart` & `test/diagrams/<type>_test.dart`**: Add test cases verifying that both the promoted keyword and any backward-compatible `-beta` alias detect and render identically.
4. **`docs/API_MANUAL.md`**: Update the Supported Diagram Families table in Section 10.

### C. New Diagram Families

When `.upstream/diff_report.md` lists a new directory `src/diagrams/<new_type>/`:

1. Create `lib/src/diagrams/<new_type>/` containing the 1:1 Dart files (`model.dart`, `parser.dart`, `layout.dart`, `render.dart`, etc.), each starting with `// Upstream: src/diagrams/<new_type>/<file>.ts`.
2. Register the diagram in:
   - `lib/src/detect.dart` (`_detectors` list, in the exact order of `.upstream/src/detect.ts`).
   - `lib/src/diagrams/registry.dart` (`all` list).
3. Add a canonical sample for `<new_type>` to `tool/verify_against_upstream.dart` (`_sampleCorpus`).
4. Create `test/diagrams/<new_type>_test.dart` covering parsing, layout, `SvgOutputMode.cssVariables`, and `SvgOutputMode.flattened` compilation with `vector_graphics_compiler` (`encodeSvg`).
5. Add the new diagram family to `UPSTREAM.md` and `docs/API_MANUAL.md`.

### D. Target `mermaid.js` or `@mermaid-js/parser` Version Updates

When `dart run tool/sync_upstream.dart --check` reports `MERMAID VERSION UPDATE DETECTED`:

1. Running `dart run tool/sync_upstream.dart --update-to-latest` (or `--refresh-assets`) automatically downloads `https://unpkg.com/mermaid@<targetVersion>/dist/mermaid.min.js` into `example/assets/mermaid.min.js` and updates the engine label in `example/lib/engine_runner.dart`.
2. Running `dart run tool/sync_upstream.dart --pin <tag> <sha>` updates `Target Mermaid Version` and `Target Mermaid Parser` in `UPSTREAM.md`.
3. `dart run tool/verify_against_upstream.dart` verifies that `UPSTREAM.md`, `.upstream/`, `example/assets/mermaid.min.js`, and `example/lib/engine_runner.dart` all agree on the exact Mermaid version.

---

## 7. 787-Diagram Differential Verification Suite

Before pinning an upstream update or cutting a release, run the comprehensive differential harness:

```bash
dart run tool/verify_against_upstream.dart
```

This tool verifies:
1. **Mermaid Version Consistency**: Confirms `UPSTREAM.md`, `.upstream/`, `example/assets/mermaid.min.js`, and `example/lib/engine_runner.dart` are aligned.
2. **Canonical 33-Family Suite (`33/33`)**: Renders all 33 diagram families in both `pele_dart` (`SvgOutputMode.cssVariables`) and `obsidianmd/pele` (`example/assets/pele.bundle.js` via Bun) and asserts 100% byte-for-byte SVG equality.
3. **Full Showcase Gallery Suite (`232/232`)**: Renders all 232 gallery `.mmd` diagrams scanned from `example/diagrams/` by `example/lib/gallery_samples.dart` in both engines and asserts 100% byte-for-byte SVG equality.
4. **Full Upstream Corpus Suite (`522/522`)**: Renders every diagram across all 30 `.upstream/tests/corpus/*.json` files in both engines and asserts 100% byte-for-byte SVG equality.

Then run the standard Dart quality gates and the **Native AOT Benchmark Regression Gate**:

```bash
dart analyze --fatal-infos lib test tool example
dart test
dart format --output=none --set-exit-if-changed lib test tool example/lib
dart run tool/benchmark_suite.dart --update-docs --check-regressions
```

If `tool/benchmark_suite.dart --check-regressions` reports a regression in any diagram family or phase (`PARSE` vs `RENDER`), inspect the newly synced code against the hot-path checklist in [`docs/BENCHMARKS.md`](BENCHMARKS.md#4-upstream-sync-performance-invariants--optimization-checklist) and optimize before finalizing the release.

---

## 8. Finalizing & Releasing a New Version

Once all quality gates and the 787-diagram differential verification suite pass with 0 differences:

1. **Regenerate Standalone Diagram & Style Images**:
   Ensure `docs/images/diagrams/*.svg`, `docs/images/styles/*.svg`, and [`docs/DIAGRAM_GALLERY.md`](DIAGRAM_GALLERY.md) reflect the latest pure-Dart renders of every diagram family (with zero host-app chrome):
   ```bash
   dart run tool/generate_doc_images.dart
   ```
2. **Pin `UPSTREAM.md`, `pubspec.yaml`, and `lib/src/diagrams/info/render.dart` to the new release tag and commit SHA**:
   Running `--pin` automatically updates the three required version locations (`Target Release` in `UPSTREAM.md`, `version: <X.Y.Z>` in `pubspec.yaml`, and `peleVersion` in `lib/src/diagrams/info/render.dart`) in 1:1 lockstep with `<new_tag>`:
   ```bash
   dart run tool/sync_upstream.dart --pin <new_tag>
   ```
   > **1:1 Version Lockstep Policy:** `pele_dart`'s `major.minor.patch` version (`<X.Y.Z>`) always matches the synced `obsidianmd/pele` release (`v<X.Y.Z>`). If a Dart-only hotfix is needed between upstream releases, use a `+N` build suffix (`<X.Y.Z>+1`) so `X.Y.Z` never diverges from upstream. Documentation prose never hardcodes version numbers.
3. **Confirm `--check` reports `UP TO DATE` and `LOCKSTEP`**:
   ```bash
   dart run tool/sync_upstream.dart --check
   ```
4. **Update `CHANGELOG.md`**:
   - Add a top-level `## <X.Y.Z>` entry matching `pubspec.yaml`'s `version:` (enforced by `tool/verify_against_upstream.dart` and `test/doc_examples_test.dart`).
5. **Commit, Tag & Push**:
   ```bash
   git add -A
   git commit -m "feat(upstream): sync with obsidianmd/pele <new_tag>"
   git tag -a <new_tag> -m "pele_dart <new_tag> (obsidianmd/pele <new_tag>)"
   git push origin main --tags
   ```

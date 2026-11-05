---
name: sync-upstream-pele
description: Detects new upstream obsidianmd/pele releases, commits, and target Mermaid.js version changes, ports TypeScript changes 1:1 into pele_dart (bug fixes, new diagram families, beta-to-stable promotions), refreshes showcase app bundles and galleries, runs the 787-diagram differential verification suite, and cuts an updated release.
---

# Sync Upstream `obsidianmd/pele` Skill (`sync-upstream-pele`)

Use this skill whenever the user asks to check for upstream `obsidianmd/pele` updates, sync `pele_dart` with a new `obsidianmd/pele` release or commit, add newly introduced upstream diagram types, promote `-beta` diagrams to stable, update the matched `mermaid.js` baseline, or prepare a new `pele_dart` release.

---

## 1. Detect Upstream Releases & Changes (Single Command)

Run the upstream release detector from the repository root:

```bash
dart run tool/sync_upstream.dart --check
```

For machine-readable JSON output:

```bash
dart run tool/sync_upstream.dart --check --json
```

### What `--check` Reports
1. **New Upstream Pele Releases**: Compares `Target Release` and `Target Commit SHA` in [`UPSTREAM.md`](../../../UPSTREAM.md) against all semantic tags (`v*`) fetched live from `https://github.com/obsidianmd/pele.git`.
2. **Unreleased `origin/main` Commits**: Reports commits on `origin/main` ahead of the latest tagged release.
3. **Target Mermaid.js Version Sync**: Compares upstream's target `mermaid` version (in `.upstream/scripts/bench-mermaid.mjs` and `.upstream/website/package.json`) and `@mermaid-js/parser` version against `UPSTREAM.md`, `example/assets/mermaid.min.js`, and the UI label in `example/lib/engine_runner.dart`.
4. **Categorized Migration Report**: Automatically writes `.upstream/diff_report.md` listing:
   - Upstream commits in the range
   - New diagram families (`src/diagrams/<new_type>/`)
   - Diagram detector / beta-to-stable keyword promotions (`src/detect.ts`)
   - Modified source files (`src/**/*.ts` -> mapped `lib/src/**/*.dart`)
   - Added / deleted / renamed source files
   - Corpus and website example updates (`tests/corpus/*.json`, `website/src/lib/examples.ts`)

---

## 2. Stage the Target Upstream Release

When a new release (or target commit) is available, stage it with one command:

```bash
# Stage the latest tagged upstream release:
dart run tool/sync_upstream.dart --update-to-latest

# Or stage a specific release tag or commit/branch (e.g. v1.14.0 or origin/main):
dart run tool/sync_upstream.dart --update-to <tag_or_ref>
```

Note: When `mermaid.min.js` needs to be downloaded from `https://unpkg.com/mermaid@<version>/dist/mermaid.min.js`, run `--update-to-latest` or `--refresh-assets` with network access (`BypassSandbox: true`).

### What `--update-to-latest` Does Automatically
1. Generates `.upstream/diff_report.md` (including unified TypeScript patches for `src/`) from the previously pinned SHA to the new target SHA.
2. Checks out the target release SHA in `.upstream/`.
3. Rebuilds `example/assets/pele.bundle.js` via `bun build` and appends `globalThis.Pele = exports_src; globalThis.PeleMetricsMeasurer = metricsMeasurer;`.
4. Downloads the exact upstream-matched `mermaid@<version>` bundle into `example/assets/mermaid.min.js` and updates the `ComparisonEngine.mermaidJs` label in `example/lib/engine_runner.dart`.
5. Updates `UPSTREAM.md` (`Target Release`, `Target Commit SHA`, `Target Commit Date`, `Target Mermaid Version`, `Target Mermaid Parser`, and `Synced Commit` column).

---

## 3. Port Upstream Changes 1:1 to Dart

Read `.upstream/diff_report.md` (or run `dart run tool/sync_upstream.dart --diff <old_sha>..<new_sha> --patch`) and port every change into `lib/src/`:

### A. Bug Fixes & Modified Files (`M src/<path>.ts`)
* Locate the mapped Dart file listed in `.upstream/diff_report.md` (every Dart file under `lib/src/` begins with `// Upstream: src/<path>.ts`).
* Apply the exact algorithmic and structural change in Dart 3 while respecting the TypeScript-to-Dart semantic rules in [`AGENTS.md`](../../../AGENTS.md):
  - 32-bit signed/unsigned bitwise math (`.toSigned(32)` / `.toUnsigned(32)`).
  - Out-of-bounds-safe slicing (`jsSlice` / `jsSubstr`).
  - Trailing-zero-stripped number formatting (`num()`).
  - If `src/svg/theme.ts` or `src/svg/root.ts` changes CSS variables or `SERIES` colors, update both `lib/src/svg/theme.dart` / `lib/src/svg/root.dart` **and** `lib/src/svg/flattener.dart` + `lib/src/types.dart` (`PelePalette`) so `SvgOutputMode.flattened` stays 100% aligned with `SvgOutputMode.cssVariables`.

### B. Beta-to-Stable Diagram Promotions or Detector Changes (`M src/detect.ts`)
* When upstream promotes a diagram from `<name>-beta` to `<name>` (or adds an alias in `src/detect.ts`):
  1. Update `_detectors` in [`lib/src/detect.dart`](../../../lib/src/detect.dart) to match `src/detect.ts` 1:1.
  2. Update the diagram's `parser.dart` header regex if it strips the first-line keyword.
  3. Update `"beta": false` in `example/diagrams/02_extended/<type>/family.json` and any updated `.mmd` sample headers in `example/diagrams/02_extended/<type>/*.mmd`.

### C. New Diagram Families (`A src/diagrams/<new_type>/...`)
1. Create `lib/src/diagrams/<new_type>/` with 1:1 Dart counterparts for each `.ts` file (`model.dart`, `parser.dart`, `layout.dart`, `render.dart`, `index.dart`), each starting with `// Upstream: src/diagrams/<new_type>/<file>.ts`.
2. Add the detector regex to [`lib/src/detect.dart`](../../../lib/src/detect.dart) matching `src/detect.ts`.
3. Register the diagram in [`lib/src/diagrams/registry.dart`](../../../lib/src/diagrams/registry.dart) matching `src/diagrams/registry.ts`.
4. Export the new diagram entrypoint if upstream exports it in `src/index.ts`.
5. Add a canonical sample to `_sampleCorpus` in [`tool/verify_against_upstream.dart`](../../../tool/verify_against_upstream.dart).
6. Create `example/diagrams/02_extended/<new_type>/` with `family.json`, playground `.mmd` files (`01_*.mmd`..`06_*.mmd`), and `showcase/showcase_*.mmd` files from `.upstream/website/src/lib/examples.ts` and `.upstream/tests/corpus/<new_type>-docs.json`, and update the family/sample counts in [`test/gallery_corpus_test.dart`](../../../test/gallery_corpus_test.dart).
7. Add dedicated unit tests in `test/diagrams/<new_type>_test.dart` testing both `SvgOutputMode.cssVariables` and `SvgOutputMode.flattened`.
8. Add the new diagram row to the Module Sync Matrix in [`UPSTREAM.md`](../../../UPSTREAM.md) and the Supported Diagrams table in [`docs/API_MANUAL.md`](../../../docs/API_MANUAL.md).

---

## 4. Regenerate Standalone Diagram Images & Verify 100% Parity

Before cutting or pushing any release, regenerate all standalone diagram and style images and run the complete verification suite. **All gates must pass with 0 diffs and 0 issues**:

```bash
# 1. Regenerate clean standalone SVG renders of every diagram family (docs/images/diagrams/*.svg),
#    themed style previews (docs/images/styles/*.svg), and docs/DIAGRAM_GALLERY.md
dart run tool/generate_doc_images.dart

# 2. Format and static analysis (0 warnings/errors/infos)
dart format lib test tool example/lib example/main.dart
dart analyze --fatal-infos lib test tool example

# 3. Full unit, gallery corpus, and upstream differential test suite
dart test

# 4. 787+ diagram differential & flattened-SVG verification against .upstream
dart run tool/verify_against_upstream.dart
```

Confirm that:
* `tool/generate_doc_images.dart` generates clean standalone SVG renders (zero host-app UI chrome) for every diagram family in `docs/images/diagrams/` and every styled showcase sample in `docs/images/styles/`, and updates [`docs/DIAGRAM_GALLERY.md`](../../../docs/DIAGRAM_GALLERY.md).
* `tool/verify_against_upstream.dart` outputs `"status":"ok"` with:
  * `exactUpstreamMatches` == total canonical diagrams
  * `exactGalleryMatches` == `totalGallerySamples`
  * `exactCorpusMatches` == `totalCorpusSamples` (all 522+ `.upstream/tests/corpus/*.json` diagrams)

---

## 5. Cut & Push the Updated Package Release

1. Update `version:` in [`pubspec.yaml`](../../../pubspec.yaml) to match or track the upstream release version.
2. Verify git author privacy before committing (must use `tkinnis <219582735+tkinnis@users.noreply.github.com>`, never a personal email address, and strictly **NO AI references** in commit messages):
   ```bash
   git config user.name "tkinnis"
   git config user.email "219582735+tkinnis@users.noreply.github.com"
   ```
3. Commit with a Conventional Commit message (e.g., `feat(upstream): sync obsidianmd/pele v1.14.0`) and tag if releasing:
   ```bash
   git add -A
   git commit -m "feat(upstream): sync obsidianmd/pele v<version>"
   git tag v<version>
   git push origin main --tags
   ```

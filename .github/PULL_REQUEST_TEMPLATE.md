## Summary

<!-- Briefly describe what this pull request changes and why. -->

Fixes #<!-- issue number, if applicable -->

## Upstream `obsidianmd/pele` Relationship

- [ ] **Upstream Parity Fix / Sync**: Ports or aligns behavior with upstream [`obsidianmd/pele`](https://github.com/obsidianmd/pele).
- [ ] **Dart-Specific Feature / Fix**: Affects Dart-only layers (`SvgOutputMode.flattened`, `PelePalette`, `TextMeasurer`, documentation, or tooling) without altering default `render()` parity.

## Quality Gate Checklist

- [ ] `dart format --output=none --set-exit-if-changed lib test tool example/lib example/main.dart` passes.
- [ ] `dart analyze --fatal-infos lib test tool` reports 0 issues.
- [ ] `dart test` passes 100% of unit and golden tests.
- [ ] Added or updated unit tests in `test/` for any new functionality or bug fix.
- [ ] Pure-Dart boundary preserved (`lib/` contains no `package:flutter`, `dart:ui`, `dart:io`, or `dart:html` imports).

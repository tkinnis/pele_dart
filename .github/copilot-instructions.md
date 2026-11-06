# GitHub Copilot Instructions

When assisting with the **`pele_dart`** codebase, follow the project-specific architecture, coding rules, invariants, and quality gates defined in:

👉 **[AGENTS.md](../AGENTS.md)**

Key rules at a glance:
- **Pure-Dart SDK Boundary (`lib/`)**: Never add `package:flutter`, `dart:ui`, `dart:io`, or `dart:html` to `lib/` or root `pubspec.yaml` `dependencies:`.
- **1:1 Upstream Structural & Version Lockstep**: Every `lib/src/<path>.dart` file mirrors `obsidianmd/pele/src/<path>.ts` (`// Upstream: src/<path>.ts`), and `pubspec.yaml` `version:` stays locked 1:1 with `UPSTREAM.md` (`Target Release`).
- **Dual SVG Output Modes**: Preserve byte-for-byte parity in `SvgOutputMode.cssVariables` and static SVG 1.1 compatibility (`vector_graphics_compiler`) in `SvgOutputMode.flattened`.
- **Zero Analysis Issues & 100% Test Pass Rate**: Code must pass `dart analyze --fatal-infos lib test tool studio example` and `dart test`.
- **Commit Policy**: Follow Conventional Commits with a strict **NO AI references** policy.

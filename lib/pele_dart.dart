/// Pure-Dart Mermaid diagram layout and SVG rendering engine, ported 1:1 from
/// [`obsidianmd/pele`](https://github.com/obsidianmd/pele) ([`pele.run`](https://pele.run))
/// created by Steph Ango (`kepano`) and the Obsidian team.
///
/// `pele_dart` parses, lays out, and renders 33 Mermaid and extended diagram
/// families synchronously in pure Dart with zero DOM, browser, or JavaScript
/// runtime dependencies.
///
/// It supports two SVG output modes via [SvgOutputMode]:
/// * [SvgOutputMode.flattened] (default): Resolves CSS custom properties,
///   `color-mix()`, `calc()`, `currentColor`, `baseline-shift`, and inline
///   `style` attributes against a [PelePalette] (`PelePalette.light`,
///   `PelePalette.dark`, or a custom palette) for static SVG 1.1 renderers
///   such as Flutter's `vector_graphics_compiler`.
/// * [SvgOutputMode.cssVariables]: Emits upstream `obsidianmd/pele`'s exact
///   theme-reactive `--pele-*` CSS custom property SVG for web and DOM hosts.
library;

export 'src/index.dart';

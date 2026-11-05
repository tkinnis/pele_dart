## 0.1.0

* Initial release of `pele_dart`, a 1:1 pure-Dart port of [`obsidianmd/pele`](https://github.com/obsidianmd/pele) (`v1.13.0`) created by Steph Ango (`kepano`) and the Obsidian team.
* **33 Supported Diagram Families**:
  * Core Mermaid diagrams (`flowchart`, `sequence`, `class`, `state`, `er`, `gantt`, `gitGraph`, `mindmap`, `pie`, `info`).
  * Extended & architecture diagrams (`agentflow`, `architecture`, `block`, `c4`, `cynefin`, `eventmodeling`, `ishikawa`, `journey`, `kanban`, `packet`, `quadrantChart`, `radar`, `railroad`, `requirement`, `sankey`, `swimlane`, `timeline`, `treemap`, `treeView`, `usecase`, `venn`, `wardley`, `xychart`).
* **100% Byte-for-Byte Upstream Parity**: Verified against upstream `obsidianmd/pele v1.13.0` across 787 canonical, gallery, and test corpus diagrams (`33/33` canonical + `232/232` gallery + `522/522` upstream corpus).
* **Dual SVG Output Modes (`SvgOutputMode`)**:
  * `SvgOutputMode.flattened` (default): Resolves `--pele-*` and `--_*` CSS custom properties, `color-mix(in srgb, ...)`, `calc(...)`, `currentColor`, `baseline-shift`, and inline `style` attributes against `PelePalette` (`PelePalette.light`, `PelePalette.dark`, or custom palettes) for static SVG 1.1 renderers and Flutter's `vector_graphics_compiler`.
  * `SvgOutputMode.cssVariables`: Emits upstream `obsidianmd/pele`'s exact theme-reactive CSS custom property SVG.
* **Core API**: `render()`, `renderMermaid()`, `parse()`, `detectType()`, `supports()`, `flattenPeleSvg()`, `register()`, `registered()`, `RenderOptions`, `ParseOptions`, `PelePalette`, `PeleError`, `TextMeasurer`, `IconResolver`, and `MathResolver`.
* **macOS 3-Way Comparison Studio (`example/`)**: Desktop workbench for side-by-side visual rendering, visual pixel/curtain diffing, and SVG text diffing across `pele_dart`, `obsidianmd/pele` (JS), and `mermaid.js`, with a live CSS style editor and dynamic `.mmd`/`.mermaid` folder browser (`example/diagrams/`).

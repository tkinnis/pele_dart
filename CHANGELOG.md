## 1.13.0+1

* Refine `README.md` typography, visual showcase layout, and Pele brand mark for `pub.dev` and GitHub rendering.

## 1.13.0

* Initial public release of `pele_dart`, version-locked 1:1 to upstream [`obsidianmd/pele`](https://github.com/obsidianmd/pele) (`v1.13.0`, commit `3a2f075ee0c3d914f0fad3545fc0f193693975ac`) created by Steph Ango (`kepano`) and the Obsidian team.
* **33 Supported Diagram Families**:
  * Core Mermaid diagrams (`flowchart`, `sequence`, `class`, `state`, `er`, `gantt`, `gitGraph`, `mindmap`, `pie`, `info`).
  * Extended & architecture diagrams (`agentflow`, `architecture`, `block`, `c4`, `cynefin`, `eventmodeling`, `ishikawa`, `journey`, `kanban`, `packet`, `quadrantChart`, `radar`, `railroad`, `requirement`, `sankey`, `swimlane`, `timeline`, `treemap`, `treeView`, `usecase`, `venn`, `wardley`, `xychart`).
* **100% Byte-for-Byte Upstream Parity**: Verified against upstream `obsidianmd/pele v1.13.0` across 787 canonical, gallery, and test corpus diagrams (`33/33` canonical + `232/232` gallery + `522/522` upstream corpus).
* **Dual SVG Output Modes (`SvgOutputMode`)**:
  * `SvgOutputMode.flattened` (default): Resolves `--pele-*` and `--_*` CSS custom properties, `color-mix(in srgb, ...)`, `calc(...)`, `currentColor`, `baseline-shift`, and inline `style` attributes against `PelePalette` (`PelePalette.light`, `PelePalette.dark`, or custom palettes) for static SVG 1.1 renderers and Flutter's `vector_graphics_compiler`.
  * `SvgOutputMode.cssVariables`: Emits upstream `obsidianmd/pele`'s exact theme-reactive CSS custom property SVG.
* **Core API**: `render()`, `renderMermaid()`, `parse()`, `detectType()`, `supports()`, `flattenPeleSvg()`, `register()`, `registered()`, `RenderOptions`, `ParseOptions`, `PelePalette`, `PeleError`, `TextMeasurer`, `IconResolver`, and `MathResolver`.
* **macOS 3-Way Comparison Studio (`studio/`)**: Desktop workbench for side-by-side visual rendering, visual pixel/curtain diffing, and SVG text diffing across `pele_dart`, `obsidianmd/pele` (JS), and `mermaid.js`, with a live CSS style editor and dynamic `.mmd`/`.mermaid` folder browser (`studio/diagrams/`).

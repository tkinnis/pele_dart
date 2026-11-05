# Security Policy

## Security Model of `pele_dart`

`pele_dart` is designed from the ground up to safely render untrusted Mermaid diagram source text into static SVG markup without executing arbitrary code or accessing external networks:

1. **Zero DOM & Zero Script Execution**:
   - Unlike browser-based diagram engines, `pele_dart` runs in pure Dart with no headless browser, WebView, or JavaScript engine.
   - All text labels and attribute values are escaped via XML/HTML entity escaping (`&`, `<`, `>`, `"`) before SVG emission, preventing script injection in generated SVG `<text>` and attribute values.
2. **URI Scheme Allowlisting**:
   - [`RenderOptions.linkSchemes`](lib/src/types.dart) restricts clickable diagram hyperlinks (`click` directives and node links) to `['http', 'https', 'mailto', 'tel']` by default (blocking `javascript:`, `data:`, `vbscript:`, and `file:` URIs), and [`RenderOptions.links`](lib/src/types.dart) (`false`) disables link emission entirely.
   - [`RenderOptions.imageSchemes`](lib/src/types.dart) restricts embedded `<image>` URIs to `['http', 'https']` by default, and [`RenderOptions.images`](lib/src/types.dart) (`false`) disables embedded images entirely.
3. **Configurable DoS & Resource Exhaustion Guards**:
   - [`RenderOptions.limit`](lib/src/types.dart) (and [`ParseOptions.limit`](lib/src/core.dart)) enforces a maximum input source length in characters (default `50000`).
   - [`RenderOptions.maxEdges`](lib/src/types.dart) (and [`ParseOptions.maxEdges`](lib/src/core.dart)) bounds the maximum number of graph edges/relations allowed during parsing (default `5000`).
   - [`RenderOptions.outputLimit`](lib/src/types.dart) caps the maximum emitted SVG string length in characters (default `4000000`).
   - Excessive recursion/nesting that triggers a `StackOverflowError` is caught and converted into a structured `PeleError('Diagram is nested too deeply.', 'limit')`.

---

## Supported Versions

Security fixes are applied to the latest minor release line:

| Version | Supported |
| :--- | :---: |
| `1.13.x` | Yes |

---

## Reporting a Vulnerability

If you discover a security vulnerability in `pele_dart` (for example, an SVG/XML attribute escape bypass, an infinite loop or catastrophic backtracking regex in a diagram parser, or a URI scheme allowlist bypass):

1. **Do not open a public GitHub issue.**
2. Please report the vulnerability privately using [**GitHub Private Vulnerability Reporting**](https://github.com/tkinnis/pele_dart/security/advisories/new) on this repository.
3. Include a minimal Mermaid diagram snippet or `RenderOptions` configuration that reproduces the issue, along with the expected vs. actual behavior.

We will acknowledge receipt within 48 hours and work with you to validate, patch, and disclose the issue responsibly (as well as coordinate with upstream [`obsidianmd/pele`](https://github.com/obsidianmd/pele) if the vulnerability originates in upstream parser or renderer logic).

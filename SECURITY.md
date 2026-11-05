# Security Policy

## Security Model of `pele_dart`

`pele_dart` is designed from the ground up to safely render untrusted Mermaid diagram source text into static SVG markup without executing arbitrary code or accessing external networks:

1. **Zero DOM & Zero Script Execution**:
   - Unlike browser-based diagram engines, `pele_dart` runs in pure Dart with no headless browser, WebView, or JavaScript engine.
   - All text labels are escaped via XML/HTML entity escaping (`&`, `<`, `>`, `"`, `'`) before SVG emission, preventing script injection in generated SVG `<text>` elements.
2. **URI Scheme Allowlisting**:
   - [`RenderOptions.linkSchemes`](lib/src/types.dart) restricts clickable diagram hyperlinks (`click` directives and node links) to `['http', 'https', 'mailto']` by default, blocking `javascript:`, `data:`, and `file:` URIs.
   - [`RenderOptions.imageSchemes`](lib/src/types.dart) restricts embedded `<image>` URIs to `['https']` by default.
3. **Configurable DoS & Resource Exhaustion Guards**:
   - [`RenderOptions.limit`](lib/src/types.dart) enforces maximum input bytes (`maxBytes`, default 512 KB), maximum line count (`maxLines`, default 10,000), and maximum AST node count (`maxNodes`, default 2,000).
   - [`RenderOptions.maxEdges`](lib/src/types.dart) bounds graph edge count (default 4,000) during layout.
   - [`RenderOptions.outputLimit`](lib/src/types.dart) caps the maximum emitted SVG byte length (default 4 MB).

---

## Supported Versions

Security fixes are applied to the latest minor release line:

| Version | Supported |
| :--- | :---: |
| `0.1.x` | Yes |

---

## Reporting a Vulnerability

If you discover a security vulnerability in `pele_dart` (for example, an SVG/XML attribute escape bypass, an infinite loop or catastrophic backtracking regex in a diagram parser, or a URI scheme allowlist bypass):

1. **Do not open a public GitHub issue.**
2. Please report the vulnerability privately using [**GitHub Private Vulnerability Reporting**](https://github.com/tkinnis/pele_dart/security/advisories/new) on this repository.
3. Include a minimal Mermaid diagram snippet or `RenderOptions` configuration that reproduces the issue, along with the expected vs. actual behavior.

We will acknowledge receipt within 48 hours and work with you to validate, patch, and disclose the issue responsibly (as well as coordinate with upstream [`obsidianmd/pele`](https://github.com/obsidianmd/pele) if the vulnerability originates in upstream parser or renderer logic).

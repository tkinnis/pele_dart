// Upstream: src/types.ts

import 'detect.dart';
import 'preprocess.dart';
import 'text/measurer.dart';

/// Callback that resolves a custom icon [name] (such as `'mdi:database'`) to
/// an inner `<svg>...</svg>` or `<path .../>` markup string, or `null` to fall
/// back to built-in icons.
typedef IconResolver = String? Function(String name);

/// Pre-rendered math expression markup returned by a [MathResolver].
class MathMarkup {
  /// Creates a [MathMarkup] containing standalone [svg] markup with measured
  /// [width] and [height] in pixels.
  const MathMarkup.svg({
    required String this.svg,
    required this.width,
    required this.height,
  }) : html = null;

  /// Creates a [MathMarkup] containing [html] / MathML markup (embedded via
  /// `<foreignObject>`) with measured [width] and [height] in pixels.
  const MathMarkup.html({
    required String this.html,
    required this.width,
    required this.height,
  }) : svg = null;

  /// SVG markup string when constructed with [MathMarkup.svg], otherwise `null`.
  final String? svg;

  /// HTML or MathML markup string when constructed with [MathMarkup.html],
  /// otherwise `null`.
  final String? html;

  /// Measured width of the rendered formula in pixels.
  final double width;

  /// Measured height of the rendered formula in pixels.
  final double height;
}

/// Callback that renders a LaTeX math expression [tex] at font [size] (in px)
/// into [MathMarkup], or returns `null` to use built-in pure-Dart Unicode math
/// typography.
typedef MathResolver = MathMarkup? Function(String tex, double size);

/// Identifier for a diagram text element category that should be rendered in a
/// monospace font (for example `'code'` or `'class-member'`).
typedef MonospacePart = String;

/// Controls whether the SVG emitted by `pele_dart` is flattened for static
/// vector compilers (`vector_graphics_compiler`) or retains upstream Pele's
/// `--pele-*` / `--_*` CSS custom properties.
enum SvgOutputMode {
  /// Resolves CSS custom properties, `color-mix()`, `calc()`, `currentColor`,
  /// `baseline-shift`, and inline `style` attributes into explicit SVG 1.1
  /// attributes against [RenderOptions.palette].
  flattened,

  /// Emits upstream `obsidianmd/pele`'s exact CSS-variable SVG string.
  cssVariables,
}

/// Theme color and stroke palette used when resolving [SvgOutputMode.flattened].
class PelePalette {
  /// Creates a [PelePalette] with customizable colors, stroke widths, corner
  /// radius, and font stacks.
  ///
  /// Derived tokens ([muted], [line], [surface], [border], [accent], [code])
  /// default to `null`, which automatically computes the same `color-mix(in srgb, ...)`
  /// blends of [fg] and [bg] as upstream `obsidianmd/pele`.
  const PelePalette({
    this.bg = '#ffffff',
    this.fg = '#24292e',
    this.fgOnLight,
    this.fgOnDark,
    this.muted,
    this.line,
    this.surface,
    this.surfaceAlt = '#e6e6e6',
    this.border,
    this.accent,
    this.code,
    this.critical = '#e45756',
    this.radius = 6,
    this.strokeWidth = 1.25,
    this.thickStrokeWidth = 2.5,
    this.hairlineStrokeWidth = 0.5,
    this.fontFamily =
        '-apple-system,BlinkMacSystemFont,Segoe UI,Helvetica,Arial,sans-serif',
    this.monoFontFamily =
        'ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,monospace',
    this.colors = const <String>[
      '#4c78a8',
      '#f58518',
      '#54a24b',
      '#e45756',
      '#72b7b2',
      '#eeca3b',
      '#b279a2',
      '#9d755d',
    ],
  });

  /// Default light palette (`#ffffff` background, `#24292e` foreground, and
  /// upstream Pele's 8-color categorical series).
  static const PelePalette light = PelePalette();

  /// Default dark palette (`#1e1e1e` background, `#e1e4e8` foreground, and
  /// upstream Pele's 8-color categorical series).
  static const PelePalette dark = PelePalette(
    bg: '#1e1e1e',
    fg: '#e1e4e8',
    surfaceAlt: '#3f3f46',
    critical: '#f87171',
  );

  /// Diagram canvas and label halo background color (`--pele-bg`).
  final String bg;

  /// Primary text and foreground ink color (`--pele-fg`).
  final String fg;

  /// Optional high-contrast text color placed over bright fills (`--pele-fg-on-light`).
  final String? fgOnLight;

  /// Optional high-contrast text color placed over dark fills (`--pele-fg-on-dark`).
  final String? fgOnDark;

  /// Secondary/caption text color (`--pele-muted`). Defaults to 60% [fg] + 40% [bg].
  final String? muted;

  /// Connector line, edge, and arrowhead stroke color (`--pele-line`). Defaults to [fg].
  final String? line;

  /// Node card and container surface fill (`--pele-surface`). Defaults to 5% [fg] + 95% [bg].
  final String? surface;

  /// Secondary/nested cluster surface fill (`--pele-surface-alt`).
  final String surfaceAlt;

  /// Node and cluster border stroke color (`--pele-border`). Defaults to 45% [fg] + 55% [bg].
  final String? border;

  /// Primary accent color (`--pele-accent`). Defaults to `'#5b7bd5'`.
  final String? accent;

  /// Inline code pill background fill (`--pele-code`). Defaults to 8% [fg] + 92% [bg].
  final String? code;

  /// Critical/alert highlight color (`--pele-critical`).
  final String critical;

  /// Corner radius in pixels for rounded node shapes (`--pele-radius`).
  final double radius;

  /// Standard stroke width in pixels (`--pele-stroke-width`).
  final double strokeWidth;

  /// Thick stroke width in pixels (`--pele-thick-stroke-width`).
  final double thickStrokeWidth;

  /// Hairline grid/divider stroke width in pixels (`--pele-hairline-stroke-width`).
  final double hairlineStrokeWidth;

  /// Primary sans-serif font stack (`--pele-font`).
  final String fontFamily;

  /// Monospace font stack (`--pele-font-mono`).
  final String monoFontFamily;

  /// Categorical 8-color series (`--pele-series-1` .. `--pele-series-8`).
  final List<String> colors;

  /// Alias for [colors] (`--pele-series-1` .. `--pele-series-8`).
  List<String> get series => colors;
}

/// Configuration options controlling diagram layout, typography, security
/// filters, resource limits, and SVG output formatting in `render`.
class RenderOptions {
  /// Creates a [RenderOptions] configuration.
  const RenderOptions({
    this.measurer,
    this.fontFamily,
    this.fontFamilyMono,
    this.monospace,
    this.fontSize,
    this.idPrefix,
    this.responsive,
    this.maxWidth,
    this.autoDirection,
    this.directionBreakpoint,
    this.padding,
    this.limit,
    this.outputLimit,
    this.maxEdges,
    this.linkSchemes,
    this.imageSchemes,
    this.links,
    this.images,
    this.linkRel,
    this.icons,
    this.math,
    this.config,
    this.now,
    this.outputMode = SvgOutputMode.flattened,
    this.palette = PelePalette.light,
  });

  /// Custom [TextMeasurer] for calculating glyph advance widths.
  final TextMeasurer? measurer;

  /// Override for the primary sans-serif font stack (`--pele-font`).
  final String? fontFamily;

  /// Override for the monospace font stack (`--pele-font-mono`).
  final String? fontFamilyMono;

  /// Text categories to render using the monospace font stack.
  final List<MonospacePart>? monospace;

  /// Base font size in pixels (defaults to diagram-specific baseline, typically `13`–`16`).
  final double? fontSize;

  /// Prefix prepended to generated SVG element `id` attributes to avoid DOM collisions.
  final String? idPrefix;

  /// When `true`, styles the root `<svg>` with `max-width: <width>px` instead of
  /// fixed `width`/`height` attributes.
  final bool? responsive;

  /// Target container width in pixels used for responsive layout tightening and
  /// [autoDirection] switching.
  final double? maxWidth;

  /// When `true` and [maxWidth] is below [directionBreakpoint], automatically
  /// rotates wide horizontal (`LR`/`RL`) flowcharts to vertical (`TB`).
  final bool? autoDirection;

  /// Width threshold in pixels below which [autoDirection] switches horizontal
  /// layouts to vertical (default `500`).
  final double? directionBreakpoint;

  /// Outer canvas padding around the diagram in pixels (default `8`).
  final double? padding;

  /// Maximum allowed input source length in characters (default `50000`).
  final int? limit;

  /// Maximum allowed output SVG length in characters (default `4000000`).
  final int? outputLimit;

  /// Maximum allowed number of edges/relations in a diagram (default `5000`).
  final int? maxEdges;

  /// Allowed URL schemes for clickable links (defaults to `['http', 'https', 'mailto']`).
  final List<String>? linkSchemes;

  /// Allowed URL schemes for embedded images (defaults to `['http', 'https']`).
  final List<String>? imageSchemes;

  /// When `false`, suppresses clickable `<a>` wrappers around linked nodes.
  final bool? links;

  /// When `false`, suppresses `<image>` elements inside diagrams.
  final bool? images;

  /// Value for the `rel` attribute on generated `<a>` link elements.
  final String? linkRel;

  /// Custom [IconResolver] callback for resolving icon names to SVG markup.
  final IconResolver? icons;

  /// Custom [MathResolver] callback for rendering LaTeX math formulas.
  final MathResolver? math;

  /// Extra Mermaid configuration map merged with YAML frontmatter / `%%{init}%%` directives.
  final Config? config;

  /// Reference date/time (`DateTime`, ISO-8601 `String`, or epoch milliseconds `num`)
  /// used for deterministic relative dates in `gantt` diagrams.
  final Object? now;

  /// Selects whether to emit flattened static SVG 1.1 ([SvgOutputMode.flattened])
  /// or CSS custom property SVG ([SvgOutputMode.cssVariables]).
  final SvgOutputMode outputMode;

  /// Color and stroke palette applied when [outputMode] is [SvgOutputMode.flattened].
  final PelePalette palette;

  /// Returns a copy of this [RenderOptions] with the given fields replaced.
  RenderOptions copyWith({
    TextMeasurer? measurer,
    String? fontFamily,
    String? fontFamilyMono,
    List<MonospacePart>? monospace,
    double? fontSize,
    String? idPrefix,
    bool? responsive,
    double? maxWidth,
    bool? autoDirection,
    double? directionBreakpoint,
    double? padding,
    int? limit,
    int? outputLimit,
    int? maxEdges,
    List<String>? linkSchemes,
    List<String>? imageSchemes,
    bool? links,
    bool? images,
    String? linkRel,
    IconResolver? icons,
    MathResolver? math,
    Config? config,
    Object? now,
    SvgOutputMode? outputMode,
    PelePalette? palette,
  }) => RenderOptions(
    measurer: measurer ?? this.measurer,
    fontFamily: fontFamily ?? this.fontFamily,
    fontFamilyMono: fontFamilyMono ?? this.fontFamilyMono,
    monospace: monospace ?? this.monospace,
    fontSize: fontSize ?? this.fontSize,
    idPrefix: idPrefix ?? this.idPrefix,
    responsive: responsive ?? this.responsive,
    maxWidth: maxWidth ?? this.maxWidth,
    autoDirection: autoDirection ?? this.autoDirection,
    directionBreakpoint: directionBreakpoint ?? this.directionBreakpoint,
    padding: padding ?? this.padding,
    limit: limit ?? this.limit,
    outputLimit: outputLimit ?? this.outputLimit,
    maxEdges: maxEdges ?? this.maxEdges,
    linkSchemes: linkSchemes ?? this.linkSchemes,
    imageSchemes: imageSchemes ?? this.imageSchemes,
    links: links ?? this.links,
    images: images ?? this.images,
    linkRel: linkRel ?? this.linkRel,
    icons: icons ?? this.icons,
    math: math ?? this.math,
    config: config ?? this.config,
    now: now ?? this.now,
    outputMode: outputMode ?? this.outputMode,
    palette: palette ?? this.palette,
  );
}

/// Metadata for a sanitized clickable link extracted from a rendered diagram.
class LinkInfo {
  /// Creates a [LinkInfo] record for node/element [id] pointing to [href].
  LinkInfo({required this.id, required this.href, required this.internal});

  /// Identifier of the linked diagram node or element.
  String id;

  /// Sanitized destination URL or fragment.
  final String href;

  /// Whether [href] is an internal anchor/reference rather than an external URL.
  final bool internal;

  @override
  bool operator ==(Object other) =>
      other is LinkInfo &&
      other.id == id &&
      other.href == href &&
      other.internal == internal;

  @override
  int get hashCode => Object.hash(id, href, internal);
}

/// Base output of a diagram renderer containing the SVG markup, intrinsic
/// dimensions, and extracted links.
class Rendered {
  /// Creates a [Rendered] diagram output.
  const Rendered({
    required this.svg,
    required this.width,
    required this.height,
    required this.links,
  });

  /// Complete `<svg ...>...</svg>` document string.
  final String svg;

  /// Intrinsic diagram width in pixels.
  final double width;

  /// Intrinsic diagram height in pixels.
  final double height;

  /// Sanitized clickable links present in the diagram.
  final List<LinkInfo> links;
}

/// Complete result returned by `render`, combining [Rendered] SVG geometry
/// with the detected [type] and [mermaidType].
class RenderResult extends Rendered {
  /// Creates a [RenderResult].
  const RenderResult({
    required super.svg,
    required super.width,
    required super.height,
    required super.links,
    required this.type,
    required this.mermaidType,
  });

  /// Canonical `pele_dart` diagram family identifier (for example `'flowchart'`).
  final DiagramType type;

  /// Mermaid-compatible diagram subtype identifier (for example `'flowchart-v2'`).
  final MermaidType mermaidType;
}

/// Resource limits enforced during diagram parsing.
class ParseLimits {
  /// Creates [ParseLimits] with the maximum allowed edge count [maxEdges].
  const ParseLimits({required this.maxEdges});

  /// Maximum number of edges/relations permitted in a single diagram.
  final int maxEdges;
}

/// Type-erased interface implemented by every registered [Diagram] plugin.
abstract interface class AnyDiagram {
  /// Canonical diagram family identifier (for example `'flowchart'`).
  DiagramType get type;

  /// Configuration section key in Mermaid frontmatter (defaults to [type] when `null`).
  String? get section;

  /// Whether `%%` comment lines must be preserved for the diagram parser.
  bool get keepComments;

  /// Whether the diagram supports LaTeX math expressions via [MathResolver].
  bool get math;

  /// Parses preprocessed diagram [source] into a diagram-specific model.
  Object? parseAny(
    String source,
    Config config,
    String? title,
    int lineOffset,
    ParseLimits limits,
  );

  /// Renders a parsed diagram [model] into a [Rendered] SVG document.
  Rendered renderAny(
    covariant Object? model,
    Config config,
    RenderOptions options,
  );
}

/// Typed diagram definition pairing a parser and renderer for [Model].
class Diagram<Model> implements AnyDiagram {
  /// Creates a typed [Diagram] plugin definition.
  const Diagram({
    required this.type,
    this.section,
    this.keepComments = false,
    this.math = false,
    required this.parse,
    required this.render,
  });

  @override
  final DiagramType type;
  @override
  final String? section;
  @override
  final bool keepComments;
  @override
  final bool math;

  /// Typed parser callback producing a [Model] from preprocessed diagram text.
  final Model Function(
    String source,
    Config config,
    String? title,
    int lineOffset,
    ParseLimits limits,
  )
  parse;

  /// Typed renderer callback producing a [Rendered] SVG from a parsed [Model].
  final Rendered Function(Model model, Config config, RenderOptions options)
  render;

  @override
  Object? parseAny(
    String source,
    Config config,
    String? title,
    int lineOffset,
    ParseLimits limits,
  ) => parse(source, config, title, lineOffset, limits);

  @override
  Rendered renderAny(
    covariant Object? model,
    Config config,
    RenderOptions options,
  ) => render(model as Model, config, options);
}

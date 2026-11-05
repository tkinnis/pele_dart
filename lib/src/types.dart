// Upstream: src/types.ts

import 'detect.dart';
import 'preprocess.dart';
import 'text/measurer.dart';

typedef IconResolver = String? Function(String name);

class MathMarkup {
  const MathMarkup.svg({
    required String this.svg,
    required this.width,
    required this.height,
  }) : html = null;

  const MathMarkup.html({
    required String this.html,
    required this.width,
    required this.height,
  }) : svg = null;

  final String? svg;
  final String? html;
  final double width;
  final double height;
}

typedef MathResolver = MathMarkup? Function(String tex, double size);

typedef MonospacePart = String;

/// Controls whether the SVG emitted by `pele_dart` is flattened for static
/// vector compilers (`vector_graphics_compiler`) or retains upstream Pele's
/// `--pele-*` / `--_*` CSS custom properties.
enum SvgOutputMode {
  /// Resolves CSS custom properties, `color-mix()`, `currentColor`, inline
  /// `rx` styles, and `baseline-shift` into explicit SVG attributes.
  flattened,

  /// Emits upstream `obsidianmd/pele`'s exact CSS-variable SVG string.
  cssVariables,
}

/// Theme color and stroke palette used when resolving [SvgOutputMode.flattened].
class PelePalette {
  const PelePalette({
    this.bg = '#ffffff',
    this.fg = '#24292e',
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

  static const PelePalette light = PelePalette();

  static const PelePalette dark = PelePalette(
    bg: '#1e1e1e',
    fg: '#e1e4e8',
    surfaceAlt: '#3f3f46',
    critical: '#f87171',
  );

  final String bg;
  final String fg;
  final String? muted;
  final String? line;
  final String? surface;
  final String surfaceAlt;
  final String? border;
  final String? accent;
  final String? code;
  final String critical;
  final double radius;
  final double strokeWidth;
  final double thickStrokeWidth;
  final double hairlineStrokeWidth;
  final String fontFamily;
  final String monoFontFamily;
  final List<String> colors;

  List<String> get series => colors;
}

class RenderOptions {
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

  final TextMeasurer? measurer;
  final String? fontFamily;
  final String? fontFamilyMono;
  final List<MonospacePart>? monospace;
  final double? fontSize;
  final String? idPrefix;
  final bool? responsive;
  final double? maxWidth;
  final bool? autoDirection;
  final double? directionBreakpoint;
  final double? padding;
  final int? limit;
  final int? outputLimit;
  final int? maxEdges;
  final List<String>? linkSchemes;
  final List<String>? imageSchemes;
  final bool? links;
  final bool? images;
  final String? linkRel;
  final IconResolver? icons;
  final MathResolver? math;
  final Config? config;
  final Object? now;
  final SvgOutputMode outputMode;
  final PelePalette palette;

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

class LinkInfo {
  LinkInfo({required this.id, required this.href, required this.internal});

  String id;
  final String href;
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

class Rendered {
  const Rendered({
    required this.svg,
    required this.width,
    required this.height,
    required this.links,
  });

  final String svg;
  final double width;
  final double height;
  final List<LinkInfo> links;
}

class RenderResult extends Rendered {
  const RenderResult({
    required super.svg,
    required super.width,
    required super.height,
    required super.links,
    required this.type,
    required this.mermaidType,
  });

  final DiagramType type;
  final MermaidType mermaidType;
}

class ParseLimits {
  const ParseLimits({required this.maxEdges});
  final int maxEdges;
}

abstract interface class AnyDiagram {
  DiagramType get type;
  String? get section;
  bool get keepComments;
  bool get math;

  Object? parseAny(
    String source,
    Config config,
    String? title,
    int lineOffset,
    ParseLimits limits,
  );

  Rendered renderAny(
    covariant Object? model,
    Config config,
    RenderOptions options,
  );
}

class Diagram<Model> implements AnyDiagram {
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

  final Model Function(
    String source,
    Config config,
    String? title,
    int lineOffset,
    ParseLimits limits,
  )
  parse;

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

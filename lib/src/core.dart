// Upstream: src/core.ts

import 'detect.dart';
import 'diagrams/registry.dart' as registry;
import 'errors.dart';
import 'preprocess.dart';
import 'svg/flattener.dart';
import 'svg/palette.dart';
import 'text/entities.dart';
import 'text/icons.dart';
import 'text/math.dart';
import 'types.dart';

export 'detect.dart' show DiagramType, MermaidType;
export 'errors.dart' show PeleError, PeleErrorCode, PeleErrorInfo;
export 'preprocess.dart' show Config;
export 'svg/flattener.dart' show flattenPeleSvg;
export 'text/measurer.dart'
    show
        Style,
        TextMeasurer,
        defaultMeasurer,
        forgetTextWidths,
        metricsMeasurer;
export 'types.dart'
    show
        AnyDiagram,
        Diagram,
        IconResolver,
        LinkInfo,
        MathMarkup,
        MathResolver,
        MonospacePart,
        ParseLimits,
        PelePalette,
        RenderOptions,
        RenderResult,
        Rendered,
        SvgOutputMode;
export 'util/yaml.dart' show YamlValue;

final Map<DiagramType, AnyDiagram> _diagrams = <DiagramType, AnyDiagram>{};
bool _defaultsRegistered = false;

void _ensureDefaults() {
  if (_defaultsRegistered) return;
  _defaultsRegistered = true;
  for (final d in registry.all) {
    _diagrams[d.type] = d;
  }
}

/// Makes diagram types available to [render] and [parse].
void register(Iterable<AnyDiagram> list) {
  _defaultsRegistered = true;
  for (final diagram in list) {
    _diagrams[diagram.type] = diagram;
  }
}

/// Returns `true` if a renderer for [type] is currently registered.
bool registered(DiagramType type) {
  _ensureDefaults();
  return _diagrams.containsKey(type);
}

const int _defaultLimit = 50000;
const int _defaultOutputLimit = 4000000;
const int _defaultMaxEdges = 5000;

bool _isStackOverflow(Object error) {
  return error is StackOverflowError;
}

T _guarded<T>(T Function() run) {
  try {
    return run();
  } catch (error) {
    if (_isStackOverflow(error)) {
      throw PeleError('Diagram is nested too deeply.', 'limit');
    }
    rethrow;
  }
}

T _tagErrors<T>(Detected found, T Function() run) {
  try {
    return run();
  } catch (error) {
    if (_isStackOverflow(error)) {
      throw PeleError(
        'Diagram is nested too deeply.',
        'limit',
        PeleErrorInfo(type: found.type, mermaidType: found.mermaidType),
      );
    }
    if (error is PeleError) {
      error.type ??= found.type;
      error.mermaidType ??= found.mermaidType;
      final message = writtenCodes(error.message);
      if (message != error.message) {
        error.message = message;
      }
      error.snippet = writtenCodes(error.snippet);
    }
    rethrow;
  }
}

class _Parsed {
  final DiagramType type;
  final MermaidType mermaidType;
  final AnyDiagram diagram;
  final Object model;
  final Config config;

  const _Parsed({
    required this.type,
    required this.mermaidType,
    required this.diagram,
    required this.model,
    required this.config,
  });
}

final Map<Object, _Parsed> _parsedModels = Map<Object, _Parsed>.identity();

_Parsed _parseSource(String text, int limit, int maxEdges, Config? extra) {
  _ensureDefaults();
  if (text.length > limit) {
    throw PeleError(
      'Diagram source is longer than the limit of $limit characters.',
      'limit',
    );
  }
  final pre = preprocess(text);
  final found = detectDiagram(pre.text);
  if (found == null) {
    throw PeleError(
      'No diagram type detected for the given text.',
      'unsupported-diagram',
    );
  }
  final diagram = _diagrams[found.type];
  if (diagram == null) {
    throw PeleError(
      'Diagram type "${found.type}" is not supported yet.',
      'unsupported-diagram',
      PeleErrorInfo(type: found.type, mermaidType: found.mermaidType),
    );
  }
  final config = extra != null
      ? <String, dynamic>{...extra, ...pre.config}
      : pre.config;
  final keepComments = diagram.keepComments == true;
  final parsed =
      '${encodeEntities(keepComments ? pre.withComments : pre.text)}\n';
  final model = _tagErrors<Object>(
    found,
    () => locatingIn<Object>(
      Origin(parsed: parsed, find: _inSource(text, keepComments)),
      () => diagram.parseAny(
        parsed,
        config,
        pre.title,
        pre.lineOffset,
        ParseLimits(maxEdges: maxEdges),
      ) as Object,
    ),
  );
  return _Parsed(
    type: found.type,
    mermaidType: found.mermaidType,
    diagram: diagram,
    model: model,
    config: config,
  );
}

(String, int) Function(int at) _inSource(String text, bool keepComments) {
  List<List<Edit>>? steps;
  var source = '';
  return (int at) {
    if (steps == null) {
      steps = <List<Edit>>[];
      final pre = preprocess(text, steps);
      encodeEntities(
        keepComments
            ? pre.withComments
            : cleanupComments(pre.withComments, steps),
        steps,
      );
      source = '${normalizeLineBreaks(text)}\n';
    }
    return (source, inputOffset(steps!, at));
  };
}

/// Options controlling resource limits and extra configuration during [parse].
class ParseOptions {
  /// Maximum allowed input source length in characters (default `50000`).
  final int? limit;

  /// Maximum allowed number of edges/relations in a diagram (default `5000`).
  final int? maxEdges;

  /// Extra Mermaid configuration map merged with YAML frontmatter / `%%{init}%%` directives.
  final Config? config;

  /// Creates [ParseOptions].
  const ParseOptions({this.limit, this.maxEdges, this.config});
}

_Parsed _parsedFrom(
  Object source, {
  int? limit,
  int? maxEdges,
  Config? config,
}) {
  if (source is String) {
    return _parseSource(
      source,
      limit ?? _defaultLimit,
      maxEdges ?? _defaultMaxEdges,
      config,
    );
  }
  final parsed = _parsedModels[source];
  if (parsed == null) {
    throw ArgumentError(
      'render() takes diagram text or a model that parse() returned.',
    );
  }
  return parsed;
}

/// Detects the canonical [DiagramType] of [text] after stripping YAML
/// frontmatter and `%%{init}%%` directives, or returns `null` if unrecognized.
DiagramType? detectType(String text) {
  return detectDiagram(preprocess(text).text)?.type;
}

/// Returns `true` if [text] has a recognized diagram header whose [DiagramType]
/// is currently registered.
bool supports(String text) {
  _ensureDefaults();
  try {
    final type = detectType(text);
    return type != null && _diagrams.containsKey(type);
  } catch (_) {
    return false;
  }
}

/// Parses Mermaid diagram [text] into an opaque diagram model that can be
/// passed directly to [render] to avoid re-parsing across theme or resize
/// re-renders.
///
/// Throws a [PeleError] if [text] exceeds [ParseOptions.limit], has an
/// unrecognized header, or contains syntax/semantic errors.
dynamic parse(String text, [ParseOptions options = const ParseOptions()]) {
  return _guarded(() {
    final parsed = _parseSource(
      text,
      options.limit ?? _defaultLimit,
      options.maxEdges ?? _defaultMaxEdges,
      options.config,
    );
    _parsedModels[parsed.model] = parsed;
    return parsed.model;
  });
}

/// Renders Mermaid diagram [source] (either a `String` or a pre-parsed model
/// returned by [parse]) into a [RenderResult] containing the SVG string,
/// intrinsic pixel dimensions, detected diagram type, and extracted links.
///
/// By default, [RenderOptions.outputMode] is [SvgOutputMode.flattened] using
/// [PelePalette.light]. Pass [SvgOutputMode.cssVariables] to emit upstream
/// `obsidianmd/pele`'s exact `--pele-*` CSS custom property SVG.
///
/// Throws a [PeleError] on syntax errors, semantic errors, unsupported diagram
/// headers, or resource limit violations.
RenderResult render(
  Object source, [
  RenderOptions options = const RenderOptions(),
]) {
  return _guarded(() {
    final parsed = _parsedFrom(
      source,
      limit: options.limit,
      maxEdges: options.maxEdges,
      config: options.config,
    );
    final type = parsed.type;
    final mermaidType = parsed.mermaidType;
    final diagram = parsed.diagram;
    final model = parsed.model;
    final config = parsed.config;
    final section = config[diagram.section ?? type];
    final fixed = section is Map && section['useMaxWidth'] == false;
    final responsive = options.responsive ?? !fixed;
    final resolve = options.icons;
    final IconResolver? icons = resolve != null
        ? (String name) => resolve(decodeEntities(name))
        : null;
    final rendered = _tagErrors<Rendered>(
      Detected(type: type, mermaidType: mermaidType),
      () => withPalette<Rendered>(
        palette(type, config),
        () => withMath<Rendered>(
          diagram.math ? options.math : null,
          () => withIcons<Rendered>(
            icons,
            () => diagram.renderAny(
              model,
              config,
              options.copyWith(responsive: responsive, icons: icons),
            ),
          ),
        ),
      ),
    );
    final outputLimit = options.outputLimit ?? _defaultOutputLimit;
    if (rendered.svg.length > outputLimit) {
      throw PeleError(
        'Diagram output is longer than the limit of $outputLimit characters.',
        'limit',
        PeleErrorInfo(type: type, mermaidType: mermaidType),
      );
    }
    for (final link in rendered.links) {
      link.id = decodeEntities(link.id);
    }
    final svg = options.outputMode == SvgOutputMode.flattened
        ? flattenPeleSvg(rendered.svg, palette: options.palette)
        : rendered.svg;
    return RenderResult(
      type: type,
      mermaidType: mermaidType,
      svg: svg,
      width: rendered.width,
      height: rendered.height,
      links: rendered.links,
    );
  });
}

/// Convenience helper returning the rendered SVG string for [source].
String renderMermaid(
  String source, {
  RenderOptions options = const RenderOptions(),
}) {
  return render(source, options).svg;
}

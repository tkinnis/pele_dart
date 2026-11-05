import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pele_dart/pele_dart.dart';
import 'package:vector_graphics/vector_graphics.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart' as vgc;
import 'package:webview_flutter/webview_flutter.dart';

/// Identifies each of the 3 Mermaid rendering engines in the Comparison Studio.
enum ComparisonEngine {
  peleDart('pele_dart', 'pele_dart (Pure Dart)', Color(0xFF00B4D8)),
  peleJs('pele_js', 'obsidianmd/pele (JS)', Color(0xFF7C3AED)),
  mermaidJs('mermaid_js', 'mermaid.js (v11)', Color(0xFFFF007F));

  final String id;
  final String label;
  final Color accent;
  const ComparisonEngine(this.id, this.label, this.accent);
}

/// Result of running a benchmarked operation using `pele.run/playground`'s
/// exact timing methodology (`website/src/lib/timing.ts`):
///
/// Repeats [run] up to [maxRuns] times within a [budgetMs] wall-clock budget
/// and reports the **median (`p50`)** and **minimum (`min`)** duration in milliseconds.
class TimedSample<T> {
  final T result;
  final double medianMs;
  final double minMs;
  final int runs;

  const TimedSample({
    required this.result,
    required this.medianMs,
    required this.minMs,
    required this.runs,
  });
}

/// Synchronous port of `timed()` from `obsidianmd/pele/website/src/lib/timing.ts`.
///
/// Runs [run] up to [maxRuns] times (default `7`) within [budgetMs] (default `60.0` ms)
/// and returns the median (`p50`) duration so JIT warmup and single-run jitter do not
/// skew engine comparisons.
TimedSample<T> timedRender<T>(
  T Function() run, {
  int maxRuns = 7,
  double budgetMs = 60.0,
}) {
  final times = <double>[];
  final totalSw = Stopwatch()..start();

  final iterSw = Stopwatch()..start();
  var result = run();
  iterSw.stop();
  times.add(iterSw.elapsedMicroseconds / 1000.0);

  while (times.length < maxRuns &&
      (totalSw.elapsedMicroseconds / 1000.0) < budgetMs) {
    iterSw
      ..reset()
      ..start();
    result = run();
    iterSw.stop();
    times.add(iterSw.elapsedMicroseconds / 1000.0);
  }
  totalSw.stop();

  times.sort();
  return TimedSample<T>(
    result: result,
    medianMs: times[times.length ~/ 2],
    minMs: times.first,
    runs: times.length,
  );
}

/// Formats a millisecond timing using `pele.run/playground`'s `formatTime()` rules.
String formatPeleTime(double ms) {
  if (ms < 0.01) return '<0.01 ms';
  if (ms < 1.0) return '${ms.toStringAsFixed(2)} ms';
  if (ms < 10.0) return '${ms.toStringAsFixed(1)} ms';
  return '${ms.round()} ms';
}

/// Holds the complete output of rendering a diagram with one [ComparisonEngine].
class EngineRenderOutput {
  final ComparisonEngine engine;

  /// Flattened static SVG string (`SvgOutputMode.flattened` for `pele_dart`,
  /// or flattened `obsidianmd/pele` JS SVG).
  final String flattenedSvg;

  /// Raw CSS-variable SVG string (`SvgOutputMode.cssVariables` for `pele_dart`,
  /// raw `Pele.render().svg` for `obsidianmd/pele`, or raw `mermaid.render()` SVG).
  final String cssVarsSvg;

  /// Pre-compiled binary vector graphics bytes for native Flutter canvas rendering.
  final Uint8List? compiledVectorBytes;

  /// Fair apples-to-apples **Pure SVG Generation** median (`p50`) time in milliseconds:
  /// `Mermaid text -> SVG string` across all 3 engines (using `timedRender`).
  final double svgGenMs;

  /// Best (minimum) pure SVG generation time across the sampled runs.
  final double minSvgGenMs;

  /// Number of runs executed within the timing budget (`1..7`, or `1..15` in benchmark mode).
  final int sampleRuns;

  /// Additional display/compilation preparation time in milliseconds:
  /// - For `pele_dart`: `flattenPeleSvg + vector_graphics_compiler.encodeSvg`
  /// - For `obsidianmd/pele (JS)` & `mermaid.js`: DOM `innerHTML` insertion + layout flush
  final double displayPrepMs;

  final double width;
  final double height;
  final String? detectedType;
  final String? error;
  final int? errorLine;
  final int? errorColumn;
  final String? errorSnippet;

  const EngineRenderOutput({
    required this.engine,
    required this.flattenedSvg,
    required this.cssVarsSvg,
    this.compiledVectorBytes,
    required this.svgGenMs,
    this.minSvgGenMs = 0.0,
    this.sampleRuns = 1,
    this.displayPrepMs = 0.0,
    required this.width,
    required this.height,
    this.detectedType,
    this.error,
    this.errorLine,
    this.errorColumn,
    this.errorSnippet,
  });

  /// Backwards-compatible alias for pure SVG generation time.
  double get durationMs => svgGenMs;

  /// End-to-end time (`SVG generation + display preparation`).
  double get totalMs => svgGenMs + displayPrepMs;

  String svgForMode(SvgOutputMode mode) =>
      mode == SvgOutputMode.flattened ? flattenedSvg : cssVarsSvg;
}

/// Custom [BytesLoader] for [VectorGraphic] from in-memory compiled bytes.
class MemoryVectorBytesLoader extends BytesLoader {
  final Uint8List bytes;
  const MemoryVectorBytesLoader(this.bytes);

  @override
  Future<ByteData> loadBytes(BuildContext? context) =>
      SynchronousFuture<ByteData>(ByteData.sublistView(bytes));

  @override
  int get hashCode => Object.hashAll(bytes);

  @override
  bool operator ==(Object other) =>
      other is MemoryVectorBytesLoader && listEquals(bytes, other.bytes);
}

/// Parses width and height from an SVG string's `viewBox` or `width`/`height` attributes.
(double, double) parseSvgDimensions(String svg) {
  final vb = RegExp(
    r'viewBox="([^"]+)"',
  ).firstMatch(svg)?.group(1)?.trim().split(RegExp(r'[\s,]+'));
  if (vb != null && vb.length == 4) {
    final w = double.tryParse(vb[2]);
    final h = double.tryParse(vb[3]);
    if (w != null && h != null && w > 0 && h > 0) {
      return (w, h);
    }
  }
  final wMatch = RegExp(r'\bwidth="([0-9.]+)').firstMatch(svg);
  final hMatch = RegExp(r'\bheight="([0-9.]+)').firstMatch(svg);
  final w = wMatch != null ? double.tryParse(wMatch.group(1)!) : null;
  final h = hMatch != null ? double.tryParse(hMatch.group(1)!) : null;
  return (w ?? 600.0, h ?? 400.0);
}

/// Compiles a flattened SVG string into binary `vector_graphics` bytes,
/// returning `null` if the SVG contains DOM-only constructs such as `<foreignObject>`.
Uint8List? tryCompileVectorBytes(String flattenedSvg, String debugName) {
  if (flattenedSvg.isEmpty || flattenedSvg.contains('<foreignObject')) {
    return null;
  }
  try {
    return vgc.encodeSvg(
      xml: flattenedSvg,
      debugName: debugName,
      enableMaskingOptimizer: false,
      enableClippingOptimizer: false,
      enableOverdrawOptimizer: false,
    );
  } catch (e) {
    debugPrint('vector_graphics_compiler warning ($debugName): $e');
    return null;
  }
}

/// Runs `pele_dart` natively in Dart using `pele.run/playground`'s fair `timedRender`
/// median methodology for pure `Mermaid -> CSS-variable SVG` generation, and measures
/// `flattenPeleSvg + vector_graphics_compiler` separately as `displayPrepMs`.
EngineRenderOutput renderWithPeleDart(
  String source, {
  required bool isDark,
  int maxRuns = 7,
  double budgetMs = 60.0,
}) {
  final sw = Stopwatch()..start();
  try {
    final palette = isDark ? PelePalette.dark : PelePalette.light;
    final options = RenderOptions(
      palette: palette,
      outputMode: SvgOutputMode.cssVariables,
    );

    // 1. Fair apples-to-apples timing: pure Mermaid -> CSS-Variables SVG (matching Pele.render(source)).
    final timed = timedRender<RenderResult>(
      () => render(source, options),
      maxRuns: maxRuns,
      budgetMs: budgetMs,
    );
    final cssVarsSvg = timed.result.svg;

    // 2. Display / Vector Graphics compilation pipeline timed separately.
    final prepSw = Stopwatch()..start();
    final flattenedSvg = flattenPeleSvg(cssVarsSvg, palette: palette);
    final vectorBytes = tryCompileVectorBytes(
      flattenedSvg,
      'pele_dart_preview',
    );
    prepSw.stop();
    final prepMs = prepSw.elapsedMicroseconds / 1000.0;

    return EngineRenderOutput(
      engine: ComparisonEngine.peleDart,
      flattenedSvg: flattenedSvg,
      cssVarsSvg: cssVarsSvg,
      compiledVectorBytes: vectorBytes,
      svgGenMs: timed.medianMs,
      minSvgGenMs: timed.minMs,
      sampleRuns: timed.runs,
      displayPrepMs: prepMs,
      width: timed.result.width,
      height: timed.result.height,
      detectedType: timed.result.type,
    );
  } on PeleError catch (e) {
    sw.stop();
    return EngineRenderOutput(
      engine: ComparisonEngine.peleDart,
      flattenedSvg: '',
      cssVarsSvg: '',
      svgGenMs: sw.elapsedMicroseconds / 1000.0,
      width: 400,
      height: 200,
      detectedType: e.type,
      error: e.message,
      errorLine: e.line,
      errorColumn: e.column,
      errorSnippet: e.snippet,
    );
  } catch (e) {
    sw.stop();
    return EngineRenderOutput(
      engine: ComparisonEngine.peleDart,
      flattenedSvg: '',
      cssVarsSvg: '',
      svgGenMs: sw.elapsedMicroseconds / 1000.0,
      width: 400,
      height: 200,
      error: e.toString(),
    );
  }
}

const int _kScriptChunkChars = 192 * 1024;

List<String> _chunkScriptToJsLiterals(String text) {
  final pieces = <String>[];
  var start = 0;
  while (start < text.length) {
    var end = start + _kScriptChunkChars;
    if (end >= text.length) {
      end = text.length;
    } else {
      final unit = text.codeUnitAt(end - 1);
      if (unit >= 0xd800 && unit <= 0xdbff) {
        end -= 1;
      }
    }
    pieces.add(_jsAsciiLiteral(text.substring(start, end)));
    start = end;
  }
  return pieces;
}

String _jsAsciiLiteral(String text) {
  final out = StringBuffer('"');
  for (final unit in text.codeUnits) {
    switch (unit) {
      case 0x22:
        out.write(r'\"');
      case 0x5c:
        out.write(r'\\');
      case 0x0a:
        out.write(r'\n');
      case 0x0d:
        out.write(r'\r');
      case < 0x20 || > 0x7e:
        out
          ..write(r'\u')
          ..write(unit.toRadixString(16).padLeft(4, '0'));
      default:
        out.writeCharCode(unit);
    }
  }
  return (out..write('"')).toString();
}

/// Widget that renders a diagram inside a macOS `WKWebView` using either
/// bundled `assets/pele.bundle.js` (`obsidianmd/pele` JS) or `assets/mermaid.min.js` (`mermaid.js`),
/// using the exact `website/src/lib/timing.ts` and `website/src/scripts/playground-mermaid.ts`
/// fair timing methodology.
class WebViewEngineCanvas extends StatefulWidget {
  final ComparisonEngine engine;
  final String source;
  final bool isDark;
  final bool isVisible;
  final int benchmarkNonce;
  final ValueChanged<EngineRenderOutput> onRendered;

  const WebViewEngineCanvas({
    super.key,
    required this.engine,
    required this.source,
    required this.isDark,
    this.isVisible = true,
    this.benchmarkNonce = 0,
    required this.onRendered,
  });

  @override
  State<WebViewEngineCanvas> createState() => _WebViewEngineCanvasState();
}

class _WebViewEngineCanvasState extends State<WebViewEngineCanvas> {
  WebViewController? _controller;
  bool _pageReady = false;
  static List<String>? _cachedPeleBundleChunks;
  static List<String>? _cachedMermaidMinChunks;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  @override
  void didUpdateWidget(covariant WebViewEngineCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.isDark != widget.isDark ||
        oldWidget.engine != widget.engine ||
        oldWidget.benchmarkNonce != widget.benchmarkNonce) {
      if (_pageReady) {
        _triggerRender(
          intensiveBenchmark: oldWidget.benchmarkNonce != widget.benchmarkNonce,
        );
      }
    }
  }

  Future<List<String>> _loadEngineChunks(ComparisonEngine engine) async {
    if (engine == ComparisonEngine.peleJs) {
      if (_cachedPeleBundleChunks != null) return _cachedPeleBundleChunks!;
      final raw = await rootBundle.loadString('assets/pele.bundle.js');
      _cachedPeleBundleChunks = await Isolate.run(
        () => _chunkScriptToJsLiterals(raw),
      );
      return _cachedPeleBundleChunks!;
    } else {
      if (_cachedMermaidMinChunks != null) return _cachedMermaidMinChunks!;
      final raw = await rootBundle.loadString('assets/mermaid.min.js');
      _cachedMermaidMinChunks = await Isolate.run(
        () => _chunkScriptToJsLiterals(raw),
      );
      return _cachedMermaidMinChunks!;
    }
  }

  Future<void> _initWebView() async {
    try {
      final chunks = await _loadEngineChunks(widget.engine);
      if (!mounted) return;

      final htmlLoaded = Completer<void>();
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      // Note: Do NOT call controller.setBackgroundColor on macOS —
      // webview_flutter_wkwebview throws UnimplementedError: opaque is not implemented on macOS.
      await controller.addJavaScriptChannel(
        'EngineChannel',
        onMessageReceived: (JavaScriptMessage msg) {
          _handleJsMessage(msg.message);
        },
      );
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (!htmlLoaded.isCompleted) {
              htmlLoaded.complete();
            }
          },
        ),
      );

      if (mounted) {
        setState(() {
          _controller = controller;
        });
      }

      await controller.loadHtmlString(_buildBootstrapHtml(widget.engine));
      await htmlLoaded.future.timeout(const Duration(seconds: 15));

      for (final chunkLiteral in chunks) {
        if (!mounted) return;
        await Future<void>.delayed(Duration.zero);
        await controller.runJavaScript('window.peleBoot.add($chunkLiteral);');
      }
      if (!mounted) return;
      await Future<void>.delayed(Duration.zero);
      await controller.runJavaScript('window.peleBoot.commit();');

      _pageReady = true;
      await _triggerRender();
    } catch (e) {
      debugPrint(
        'WebViewEngineCanvas initialization error (${widget.engine}): $e',
      );
      if (mounted) {
        widget.onRendered(
          EngineRenderOutput(
            engine: widget.engine,
            flattenedSvg: '',
            cssVarsSvg: '',
            svgGenMs: 0,
            width: 400,
            height: 200,
            error: 'WebView initialization failed: $e',
          ),
        );
      }
    }
  }

  String _buildBootstrapHtml(ComparisonEngine engine) {
    final isPeleJs = engine == ComparisonEngine.peleJs;
    return '''<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  html, body {
    margin: 0;
    padding: 0;
    width: 100%;
    height: 100%;
    background: #ffffff;
    color: #1f1f1f;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: auto;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  }
  body.dark-mode {
    background: #14171f;
    color: #e1e4e8;
    color-scheme: dark;
    --pele-bg: #1e1e1e;
    --pele-fg: #e1e4e8;
    --pele-muted: rgb(159, 161, 163);
    --pele-line: #e1e4e8;
    --pele-surface: rgb(36, 36, 36);
    --pele-surface-alt: #3f3f46;
    --pele-border: rgb(127, 129, 130);
    --pele-accent: #5b7bd5;
    --pele-critical: #f87171;
  }
  #stage {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 100%;
    height: 100%;
    padding: 16px;
    box-sizing: border-box;
  }
  #stage svg {
    max-width: 100%;
    max-height: 100%;
    width: auto !important;
    height: auto !important;
  }
</style>
<script>
(function () {
  var parts = [];
  window.peleBoot = {
    add: function (piece) {
      parts.push(piece);
    },
    commit: function () {
      var script = document.createElement('script');
      script.textContent = parts.join('');
      parts = [];
      document.head.appendChild(script);
    }
  };
})();
</script>
</head>
<body>
<div id="stage"></div>
<script>
let mermaidSeq = 0;
const warmedTypes = new Set();

// Port of website/src/lib/timing.ts from https://pele.run/playground,
// with adaptive batching to overcome WKWebView's 1.0 ms performance.now() quantization.
function measureSyncBatch(run) {
  let batch = 1;
  while (true) {
    const t0 = performance.now();
    let res;
    for (let i = 0; i < batch; i++) {
      res = run();
    }
    const elapsed = performance.now() - t0;
    if (elapsed >= 6.0 || batch >= 64) {
      return { result: res, ms: elapsed / batch };
    }
    batch *= 2;
  }
}

function timedSync(run, maxRuns, budgetMs) {
  const times = [];
  const started = performance.now();
  const s0 = measureSyncBatch(run);
  let result = s0.result;
  times.push(s0.ms);
  while (times.length < maxRuns && (performance.now() - started) < budgetMs) {
    const sIter = measureSyncBatch(run);
    result = sIter.result;
    times.push(sIter.ms);
  }
  times.sort((a, b) => a - b);
  return {
    result: result,
    medianMs: times[Math.floor(times.length / 2)],
    minMs: times[0],
    runs: times.length
  };
}

async function timedAsync(run, maxRuns, budgetMs) {
  const times = [];
  const started = performance.now();
  const r0 = performance.now();
  let result = await run();
  times.push(performance.now() - r0);
  while (times.length < maxRuns && (performance.now() - started) < budgetMs) {
    const tIter = performance.now();
    result = await run();
    times.push(performance.now() - tIter);
  }
  times.sort((a, b) => a - b);
  return {
    result: result,
    medianMs: times[Math.floor(times.length / 2)],
    minMs: times[0],
    runs: times.length
  };
}

async function runEngine(source, isDark, maxRuns, budgetMs) {
  document.body.className = isDark ? 'dark-mode' : '';
  const stage = document.getElementById('stage');
  try {
    let svg = '';
    let medianMs = 0;
    let minMs = 0;
    let runs = 1;

    if (${isPeleJs ? 'true' : 'false'}) {
      const timed = timedSync(() => Pele.render(source, { measurer: globalThis.PeleMetricsMeasurer }), maxRuns, budgetMs);
      svg = timed.result.svg;
      medianMs = timed.medianMs;
      minMs = timed.minMs;
      runs = timed.runs;
    } else {
      // Exact methodology from website/src/scripts/playground-mermaid.ts:
      // 1. Initialize outside the timer.
      mermaid.initialize({
        startOnLoad: false,
        theme: isDark ? 'dark' : 'default',
        securityLevel: 'strict',
        suppressErrorRendering: true
      });
      // 2. Warm up diagram type loader on first use outside the timer.
      const headerKey = (source.trim().split(/\\s+/)[0] || 'default') + ':' + (isDark ? 'dark' : 'light');
      if (!warmedTypes.has(headerKey)) {
        warmedTypes.add(headerKey);
        try {
          await mermaid.render('m_warmup_' + (++mermaidSeq), source);
        } catch (_) {}
      }
      // 3. Timed render(s) within budget.
      const timed = await timedAsync(
        () => mermaid.render('m_run_' + (++mermaidSeq), source),
        Math.min(maxRuns, 5),
        budgetMs
      );
      svg = timed.result.svg;
      medianMs = timed.medianMs;
      minMs = timed.minMs;
      runs = timed.runs;
    }

    // 4. Measure DOM insertion + synchronous layout flush separately.
    const tDom = performance.now();
    stage.innerHTML = svg;
    stage.getBoundingClientRect();
    const displayPrepMs = performance.now() - tDom;

    EngineChannel.postMessage(JSON.stringify({
      ok: true,
      svg: svg,
      svgGenMs: medianMs,
      minSvgGenMs: minMs,
      sampleRuns: runs,
      displayPrepMs: displayPrepMs
    }));
  } catch (err) {
    stage.innerHTML = '<pre style="color:#ef4444;font-size:12px;white-space:pre-wrap;padding:12px;">' +
      String(err && err.message ? err.message : err) + '</pre>';
    EngineChannel.postMessage(JSON.stringify({
      ok: false,
      error: String(err && err.message ? err.message : err),
      svgGenMs: 0,
      minSvgGenMs: 0,
      sampleRuns: 1,
      displayPrepMs: 0
    }));
  }
}
</script>
</body>
</html>''';
  }

  Future<void> _triggerRender({bool intensiveBenchmark = false}) async {
    final c = _controller;
    if (c == null || !_pageReady) return;
    final encodedSource = jsonEncode(
      widget.source,
    ).replaceAll('\u2028', r'\u2028').replaceAll('\u2029', r'\u2029');
    final isDarkLiteral = widget.isDark ? 'true' : 'false';
    final maxRuns = intensiveBenchmark ? 15 : 7;
    final budgetMs = intensiveBenchmark ? 250 : 60;
    await c.runJavaScript(
      'runEngine($encodedSource, $isDarkLiteral, $maxRuns, $budgetMs);',
    );
  }

  void _handleJsMessage(String rawJson) {
    try {
      final map = jsonDecode(rawJson) as Map<String, dynamic>;
      final ok = map['ok'] == true;
      final svgGenMs = (map['svgGenMs'] as num?)?.toDouble() ?? 0.0;
      final minSvgGenMs = (map['minSvgGenMs'] as num?)?.toDouble() ?? svgGenMs;
      final sampleRuns = (map['sampleRuns'] as num?)?.toInt() ?? 1;
      final displayPrepMs = (map['displayPrepMs'] as num?)?.toDouble() ?? 0.0;

      if (ok) {
        final svg = (map['svg'] as String?) ?? '';
        final (w, h) = parseSvgDimensions(svg);
        final palette = widget.isDark ? PelePalette.dark : PelePalette.light;
        final flattened =
            widget.engine == ComparisonEngine.peleJs
                ? flattenPeleSvg(svg, palette: palette)
                : svg;
        final compiledBytes =
            widget.engine == ComparisonEngine.peleJs
                ? tryCompileVectorBytes(flattened, 'pele_js_preview')
                : null;
        widget.onRendered(
          EngineRenderOutput(
            engine: widget.engine,
            flattenedSvg: flattened,
            cssVarsSvg: svg,
            compiledVectorBytes: compiledBytes,
            svgGenMs: svgGenMs,
            minSvgGenMs: minSvgGenMs,
            sampleRuns: sampleRuns,
            displayPrepMs: displayPrepMs,
            width: w,
            height: h,
          ),
        );
      } else {
        widget.onRendered(
          EngineRenderOutput(
            engine: widget.engine,
            flattenedSvg: '',
            cssVarsSvg: '',
            svgGenMs: svgGenMs,
            minSvgGenMs: minSvgGenMs,
            sampleRuns: sampleRuns,
            displayPrepMs: displayPrepMs,
            width: 400,
            height: 200,
            error: (map['error'] as String?) ?? 'Render failed',
          ),
        );
      }
    } catch (e) {
      widget.onRendered(
        EngineRenderOutput(
          engine: widget.engine,
          flattenedSvg: '',
          cssVarsSvg: '',
          svgGenMs: 0,
          width: 400,
          height: 200,
          error: e.toString(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!widget.isVisible) {
      return const SizedBox.shrink();
    }
    return WebViewWidget(controller: c);
  }
}

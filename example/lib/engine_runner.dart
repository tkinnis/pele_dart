import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pele_dart/pele_dart.dart';
import 'package:vector_graphics/vector_graphics.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart' as vgc;
import 'package:webview_flutter/webview_flutter.dart';

/// Identifiers for the 3 comparison engines.
enum ComparisonEngine {
  peleDart('pele_dart', 'pele_dart (Pure Dart)', Color(0xFF00B4D8)),
  peleJs('pele_js', 'obsidianmd/pele (JS)', Color(0xFF8B5CF6)),
  mermaidJs('mermaid_js', 'mermaid.js (DOM)', Color(0xFFF59E0B));

  final String id;
  final String label;
  final Color accent;
  const ComparisonEngine(this.id, this.label, this.accent);
}

/// Formats a millisecond timing value identically to `website/src/lib/timing.ts`
/// on https://pele.run/playground.
String formatPeleTime(double milliseconds) {
  if (milliseconds < 0.05) return '< 0.1 ms';
  if (milliseconds < 10) return '${milliseconds.toStringAsFixed(2)} ms';
  if (milliseconds < 100) return '${milliseconds.toStringAsFixed(1)} ms';
  return '${milliseconds.round()} ms';
}

/// Executes [run] using the exact median-of-budgeted-runs methodology from
/// `website/src/lib/timing.ts` on https://pele.run/playground:
/// repeats up to [maxRuns] times within [budgetMs] and returns the median (`p50`).
({T result, double medianMs, double minMs, int runs}) timedRender<T>(
  T Function() run, {
  int maxRuns = 7,
  double budgetMs = 60.0,
}) {
  final times = <double>[];
  final totalSw = Stopwatch()..start();

  final firstSw = Stopwatch()..start();
  var result = run();
  firstSw.stop();
  times.add(firstSw.elapsedMicroseconds / 1000.0);

  while (times.length < maxRuns &&
      (totalSw.elapsedMicroseconds / 1000.0) < budgetMs) {
    final iterSw = Stopwatch()..start();
    result = run();
    iterSw.stop();
    times.add(iterSw.elapsedMicroseconds / 1000.0);
  }
  totalSw.stop();

  times.sort();
  final medianMs = times[times.length ~/ 2];
  final minMs = times.first;
  return (result: result, medianMs: medianMs, minMs: minMs, runs: times.length);
}

/// Output captured from a single diagram rendering engine.
class EngineRenderOutput {
  final ComparisonEngine engine;
  final String flattenedSvg;
  final String cssVarsSvg;
  final Uint8List? compiledVectorBytes;

  /// Pure `Mermaid text -> SVG string` median generation time (apples-to-apples across all 3 engines).
  final double svgGenMs;

  /// Minimum `Mermaid text -> SVG string` time across the timed runs.
  final double minSvgGenMs;

  /// Number of timed iterations executed within the timing budget.
  final int sampleRuns;

  /// Post-SVG display preparation time (`flattenPeleSvg + vector_graphics_compiler` for `pele_dart`,
  /// or `innerHTML + DOM layout flush` for the WebView JS engines).
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
  Future<ByteData> loadBytes(BuildContext? context) async {
    return ByteData.sublistView(bytes);
  }

  @override
  int get hashCode => Object.hashAll(bytes.take(64));

  @override
  bool operator ==(Object other) =>
      other is MemoryVectorBytesLoader && identical(bytes, other.bytes);
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
    Uint8List? vectorBytes;
    try {
      vectorBytes = vgc.encodeSvg(
        xml: flattenedSvg,
        debugName: 'pele_dart_preview',
        enableMaskingOptimizer: false,
        enableClippingOptimizer: false,
        enableOverdrawOptimizer: false,
      );
    } catch (_) {
      vectorBytes = null;
    }
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

/// Widget that renders a diagram inside a macOS `WKWebView` using either
/// bundled `assets/pele.bundle.js` (`obsidianmd/pele` JS) or `assets/mermaid.min.js` (`mermaid.js`),
/// using the exact `website/src/lib/timing.ts` and `website/src/scripts/playground-mermaid.ts`
/// fair timing methodology.
class WebViewEngineCanvas extends StatefulWidget {
  final ComparisonEngine engine;
  final String source;
  final bool isDark;
  final int benchmarkNonce;
  final ValueChanged<EngineRenderOutput> onRendered;

  const WebViewEngineCanvas({
    super.key,
    required this.engine,
    required this.source,
    required this.isDark,
    this.benchmarkNonce = 0,
    required this.onRendered,
  });

  @override
  State<WebViewEngineCanvas> createState() => _WebViewEngineCanvasState();
}

class _WebViewEngineCanvasState extends State<WebViewEngineCanvas> {
  WebViewController? _controller;
  bool _pageReady = false;
  static String? _cachedPeleBundleJs;
  static String? _cachedMermaidMinJs;

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

  Future<void> _initWebView() async {
    _cachedPeleBundleJs ??= await rootBundle.loadString(
      'assets/pele.bundle.js',
    );
    _cachedMermaidMinJs ??= await rootBundle.loadString(
      'assets/mermaid.min.js',
    );

    final controller = WebViewController();
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setBackgroundColor(Colors.transparent);
    await controller.addJavaScriptChannel(
      'EngineChannel',
      onMessageReceived: (JavaScriptMessage msg) {
        _handleJsMessage(msg.message);
      },
    );
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (_) {
          _pageReady = true;
          _triggerRender();
        },
      ),
    );

    final jsScript =
        widget.engine == ComparisonEngine.peleJs
            ? _cachedPeleBundleJs!
            : _cachedMermaidMinJs!;
    final html = _buildHostHtml(widget.engine, jsScript);
    await controller.loadHtmlString(html);
    if (mounted) {
      setState(() {
        _controller = controller;
      });
    }
  }

  String _buildHostHtml(ComparisonEngine engine, String scriptContent) {
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
    background: transparent;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  }
  body.dark-mode {
    color-scheme: dark;
  }
  #stage {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 100%;
    height: 100%;
    padding: 12px;
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
$scriptContent
</script>
</head>
<body>
<div id="stage"></div>
<script>
let mermaidSeq = 0;
const warmedTypes = new Set();

// Exact port of website/src/lib/timing.ts from https://pele.run/playground
function timedSync(run, maxRuns, budgetMs) {
  const times = [];
  const started = performance.now();
  const r0 = performance.now();
  let result = run();
  times.push(performance.now() - r0);
  while (times.length < maxRuns && (performance.now() - started) < budgetMs) {
    const tIter = performance.now();
    result = run();
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
      const timed = timedSync(() => Pele.render(source), maxRuns, budgetMs);
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
    final encodedSource = jsonEncode(widget.source);
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
        final flattened =
            widget.engine == ComparisonEngine.peleJs
                ? flattenPeleSvg(
                  svg,
                  palette: widget.isDark ? PelePalette.dark : PelePalette.light,
                )
                : svg;
        widget.onRendered(
          EngineRenderOutput(
            engine: widget.engine,
            flattenedSvg: flattened,
            cssVarsSvg: svg,
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
    return WebViewWidget(controller: c);
  }
}

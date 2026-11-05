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

/// Output captured from a single diagram rendering engine.
class EngineRenderOutput {
  final ComparisonEngine engine;
  final String flattenedSvg;
  final String cssVarsSvg;
  final Uint8List? compiledVectorBytes;
  final double durationMs;
  final double width;
  final double height;
  final String? error;

  const EngineRenderOutput({
    required this.engine,
    required this.flattenedSvg,
    required this.cssVarsSvg,
    this.compiledVectorBytes,
    required this.durationMs,
    required this.width,
    required this.height,
    this.error,
  });

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

/// Runs `pele_dart` natively in Dart and compiles the flattened SVG with `vector_graphics_compiler`.
EngineRenderOutput renderWithPeleDart(String source, {required bool isDark}) {
  final sw = Stopwatch()..start();
  try {
    final palette = isDark ? PelePalette.dark : PelePalette.light;
    final cssVarsSvg = renderMermaid(
      source,
      options: RenderOptions(
        palette: palette,
        outputMode: SvgOutputMode.cssVariables,
      ),
    );
    final flattenedSvg = flattenPeleSvg(cssVarsSvg, palette: palette);
    sw.stop();
    final elapsedMs = sw.elapsedMicroseconds / 1000.0;
    final (w, h) = parseSvgDimensions(flattenedSvg);
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
      // If vector_graphics_compiler rejects an exotic SVG construct, fall back to WebView SVG display.
      vectorBytes = null;
    }
    return EngineRenderOutput(
      engine: ComparisonEngine.peleDart,
      flattenedSvg: flattenedSvg,
      cssVarsSvg: cssVarsSvg,
      compiledVectorBytes: vectorBytes,
      durationMs: elapsedMs,
      width: w,
      height: h,
    );
  } catch (e) {
    sw.stop();
    return EngineRenderOutput(
      engine: ComparisonEngine.peleDart,
      flattenedSvg: '',
      cssVarsSvg: '',
      durationMs: sw.elapsedMicroseconds / 1000.0,
      width: 400,
      height: 200,
      error: e.toString(),
    );
  }
}

/// Widget that renders a diagram inside a macOS `WKWebView` using either
/// bundled `assets/pele.bundle.js` (`obsidianmd/pele` JS) or `assets/mermaid.min.js` (`mermaid.js`),
/// and reports the generated raw `<svg>` string and render duration back to Flutter.
class WebViewEngineCanvas extends StatefulWidget {
  final ComparisonEngine engine;
  final String source;
  final bool isDark;
  final ValueChanged<EngineRenderOutput> onRendered;

  const WebViewEngineCanvas({
    super.key,
    required this.engine,
    required this.source,
    required this.isDark,
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
        oldWidget.engine != widget.engine) {
      if (_pageReady) {
        _triggerRender();
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
async function runEngine(source, isDark) {
  document.body.className = isDark ? 'dark-mode' : '';
  const stage = document.getElementById('stage');
  const t0 = performance.now();
  try {
    let svg = '';
    if (${isPeleJs ? 'true' : 'false'}) {
      svg = Pele.renderMermaid(source);
      stage.innerHTML = svg;
    } else {
      mermaid.initialize({
        startOnLoad: false,
        theme: isDark ? 'dark' : 'default',
        securityLevel: 'strict'
      });
      const id = 'm_' + Math.random().toString(36).slice(2);
      const out = await mermaid.render(id, source);
      svg = out.svg;
      stage.innerHTML = svg;
    }
    const elapsed = performance.now() - t0;
    EngineChannel.postMessage(JSON.stringify({
      ok: true,
      svg: svg,
      durationMs: elapsed
    }));
  } catch (err) {
    const elapsed = performance.now() - t0;
    stage.innerHTML = '<pre style="color:#ef4444;font-size:12px;white-space:pre-wrap;">' +
      String(err && err.message ? err.message : err) + '</pre>';
    EngineChannel.postMessage(JSON.stringify({
      ok: false,
      error: String(err && err.message ? err.message : err),
      durationMs: elapsed
    }));
  }
}
</script>
</body>
</html>''';
  }

  Future<void> _triggerRender() async {
    final c = _controller;
    if (c == null || !_pageReady) return;
    final encodedSource = jsonEncode(widget.source);
    final isDarkLiteral = widget.isDark ? 'true' : 'false';
    await c.runJavaScript('runEngine($encodedSource, $isDarkLiteral);');
  }

  void _handleJsMessage(String rawJson) {
    try {
      final map = jsonDecode(rawJson) as Map<String, dynamic>;
      final ok = map['ok'] == true;
      final durationMs = (map['durationMs'] as num?)?.toDouble() ?? 0.0;
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
            durationMs: durationMs,
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
            durationMs: durationMs,
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
          durationMs: 0,
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

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pele_dart/pele_dart.dart';
import 'package:vector_graphics/vector_graphics_compat.dart';

import 'engine_runner.dart';
import 'gallery_samples.dart';
import 'svg_diff_view.dart';
import 'visual_diff_view.dart';

void main() {
  runApp(const PeleDartComparisonApp());
}

enum InspectionTab {
  visualRender('Visual Render', Icons.visibility),
  visualDiff('Visual Diff', Icons.compare),
  rawSvg('Raw SVG', Icons.code),
  svgTextDiff('SVG Text Diff', Icons.difference);

  final String label;
  final IconData icon;
  const InspectionTab(this.label, this.icon);
}

enum EditorDockMode {
  bottomDock('Bottom Editor', Icons.dock),
  leftSplit('Left Split Editor', Icons.vertical_split),
  hidden('Hide Editor', Icons.visibility_off_outlined);

  final String label;
  final IconData icon;
  const EditorDockMode(this.label, this.icon);
}

class PeleDartComparisonApp extends StatefulWidget {
  const PeleDartComparisonApp({super.key});

  @override
  State<PeleDartComparisonApp> createState() => _PeleDartComparisonAppState();
}

class _PeleDartComparisonAppState extends State<PeleDartComparisonApp> {
  bool _isDark = true;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00B4D8),
      brightness: _isDark ? Brightness.dark : Brightness.light,
    );
    return MaterialApp(
      title: 'pele_dart — 3-Way Comparison, Diff Studio & Playground',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: scheme, useMaterial3: true),
      home: ComparisonStudioScreen(
        isDark: _isDark,
        onToggleTheme: () => setState(() => _isDark = !_isDark),
      ),
    );
  }
}

/// Interactive drag-resize divider (vertical or horizontal) with hover highlight
/// and double-click reset.
class ResizableSplitter extends StatefulWidget {
  final Axis axis;
  final ValueChanged<double> onDragDelta;
  final VoidCallback? onDoubleTap;
  final String? tooltip;

  const ResizableSplitter({
    super.key,
    required this.axis,
    required this.onDragDelta,
    this.onDoubleTap,
    this.tooltip,
  });

  @override
  State<ResizableSplitter> createState() => _ResizableSplitterState();
}

class _ResizableSplitterState extends State<ResizableSplitter> {
  bool _hovering = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final isVerticalDivider = widget.axis == Axis.horizontal;
    final active = _hovering || _dragging;
    final accent = Theme.of(context).colorScheme.primary;
    final baseColor = Theme.of(context).dividerColor;

    final handle = MouseRegion(
      cursor:
          isVerticalDivider
              ? SystemMouseCursors.resizeColumn
              : SystemMouseCursors.resizeRow,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: widget.onDoubleTap,
        onPanStart: (_) => setState(() => _dragging = true),
        onPanEnd: (_) => setState(() => _dragging = false),
        onPanCancel: () => setState(() => _dragging = false),
        onPanUpdate: (details) {
          widget.onDragDelta(
            isVerticalDivider ? details.delta.dx : details.delta.dy,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: isVerticalDivider ? 7 : double.infinity,
          height: isVerticalDivider ? double.infinity : 7,
          color: active ? accent.withValues(alpha: 0.18) : Colors.transparent,
          child: Center(
            child: Container(
              width: isVerticalDivider ? (active ? 2.5 : 1.0) : 36.0,
              height: isVerticalDivider ? 36.0 : (active ? 2.5 : 1.0),
              decoration: BoxDecoration(
                color: active ? accent : baseColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: handle);
    }
    return handle;
  }
}

class ComparisonStudioScreen extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;

  const ComparisonStudioScreen({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  State<ComparisonStudioScreen> createState() => _ComparisonStudioScreenState();
}

class _ComparisonStudioScreenState extends State<ComparisonStudioScreen> {
  DiagramSample _selectedSample = gallerySamples.first;
  int _selectedPlaygroundSampleIndex = 0;
  bool _isAdHocCustom = false;

  late final TextEditingController _editorController;
  String _activeSource =
      gallerySamples.first.playgroundSamples.isNotEmpty
          ? gallerySamples.first.playgroundSamples.first.source
          : gallerySamples.first.source;
  String _searchQuery = '';
  int? _tierFilter;

  // Resizable panel dimensions
  bool _showGallerySidebar = true;
  double _sidebarWidth = 248.0;
  EditorDockMode _editorDockMode = EditorDockMode.bottomDock;
  double _editorLeftWidth = 330.0;
  double _editorBottomHeight = 195.0;

  // Relative width weights for the 3 engine columns (resizable via splitters)
  final Map<ComparisonEngine, double> _engineWeights =
      <ComparisonEngine, double>{
        ComparisonEngine.peleDart: 1.0,
        ComparisonEngine.peleJs: 1.0,
        ComparisonEngine.mermaidJs: 1.0,
      };

  Timer? _debounceTimer;
  int _benchmarkNonce = 0;

  final Set<ComparisonEngine> _selectedEngines = <ComparisonEngine>{
    ComparisonEngine.peleDart,
    ComparisonEngine.peleJs,
    ComparisonEngine.mermaidJs,
  };

  InspectionTab _activeTab = InspectionTab.visualRender;
  SvgOutputMode _peleDartOutputMode = SvgOutputMode.flattened;
  final TransformationController _zoomController = TransformationController();

  final Map<ComparisonEngine, EngineRenderOutput> _outputs =
      <ComparisonEngine, EngineRenderOutput>{};

  @override
  void initState() {
    super.initState();
    _editorController = TextEditingController(text: _activeSource);
    _runPeleDartEngine();
  }

  @override
  void didUpdateWidget(covariant ComparisonStudioScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDark != widget.isDark) {
      _runPeleDartEngine();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _editorController.dispose();
    _zoomController.dispose();
    super.dispose();
  }

  void _runPeleDartEngine({bool intensiveBenchmark = false}) {
    final res = renderWithPeleDart(
      _activeSource,
      isDark: widget.isDark,
      maxRuns: intensiveBenchmark ? 15 : 7,
      budgetMs: intensiveBenchmark ? 250.0 : 60.0,
    );
    setState(() {
      _outputs[ComparisonEngine.peleDart] = res;
      if (intensiveBenchmark) {
        _benchmarkNonce++;
      }
    });
  }

  void _selectFamily(DiagramSample sample) {
    _debounceTimer?.cancel();
    final initialSource =
        sample.playgroundSamples.isNotEmpty
            ? sample.playgroundSamples.first.source
            : sample.source;
    setState(() {
      _selectedSample = sample;
      _selectedPlaygroundSampleIndex = 0;
      _isAdHocCustom = false;
      _activeSource = initialSource;
      _editorController.text = initialSource;
    });
    _runPeleDartEngine();
  }

  void _selectSubSampleSource(String source, int index) {
    _debounceTimer?.cancel();
    setState(() {
      _selectedPlaygroundSampleIndex = index;
      _isAdHocCustom = false;
      _activeSource = source;
      _editorController.text = source;
    });
    _runPeleDartEngine();
  }

  void _startAdHocPlayground({String? initialText}) {
    _debounceTimer?.cancel();
    final source = initialText ?? playgroundDefaultSource;
    setState(() {
      _isAdHocCustom = true;
      if (_editorDockMode == EditorDockMode.hidden) {
        _editorDockMode = EditorDockMode.leftSplit;
      }
      _activeSource = source;
      _editorController.text = source;
    });
    _runPeleDartEngine();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.trim().isNotEmpty) {
      _startAdHocPlayground(initialText: text);
    }
  }

  void _onEditorTextChanged(String nextText) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      setState(() {
        _isAdHocCustom = true;
        _activeSource = nextText;
      });
      _runPeleDartEngine();
    });
  }

  List<ComparisonEngine> get _orderedSelectedEngines =>
      ComparisonEngine.values.where(_selectedEngines.contains).toList();

  double? _fastestSvgGenMs() {
    double? best;
    for (final engine in ComparisonEngine.values) {
      final out = _outputs[engine];
      if (out != null && out.error == null && out.svgGenMs > 0) {
        best = best == null ? out.svgGenMs : math.min(best, out.svgGenMs);
      }
    }
    return best;
  }

  void _resetEngineWeights() {
    setState(() {
      for (final e in ComparisonEngine.values) {
        _engineWeights[e] = 1.0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalSamples = gallerySamples.fold<int>(
      0,
      (sum, s) => sum + s.playgroundSamples.length,
    );

    return Scaffold(
      body: Column(
        children: <Widget>[
          _buildTopToolbar(context, totalSamples),
          _buildFairTimingSummaryBar(context),
          Expanded(
            child: Row(
              children: <Widget>[
                if (_showGallerySidebar) ...<Widget>[
                  SizedBox(
                    width: _sidebarWidth,
                    child: _buildGallerySidebar(context),
                  ),
                  ResizableSplitter(
                    axis: Axis.horizontal,
                    tooltip:
                        'Drag to resize diagram sidebar (double-click to reset)',
                    onDoubleTap: () => setState(() => _sidebarWidth = 248.0),
                    onDragDelta: (dx) {
                      setState(() {
                        _sidebarWidth = (_sidebarWidth + dx).clamp(
                          180.0,
                          480.0,
                        );
                      });
                    },
                  ),
                ],
                if (_editorDockMode == EditorDockMode.leftSplit) ...<Widget>[
                  SizedBox(
                    width: _editorLeftWidth,
                    child: _buildLiveSourceEditor(context, isLeftSplit: true),
                  ),
                  ResizableSplitter(
                    axis: Axis.horizontal,
                    tooltip:
                        'Drag to resize playground editor (double-click to reset)',
                    onDoubleTap: () => setState(() => _editorLeftWidth = 330.0),
                    onDragDelta: (dx) {
                      setState(() {
                        _editorLeftWidth = (_editorLeftWidth + dx).clamp(
                          210.0,
                          680.0,
                        );
                      });
                    },
                  ),
                ],
                Expanded(
                  child: Column(
                    children: <Widget>[
                      _buildSubSampleSelectorBar(context),
                      Expanded(
                        child: Stack(
                          children: <Widget>[
                            // Keep WebViewEngineCanvas states mounted so JS engine SVGs and timings stay updated across all 4 tabs,
                            // while WebViewEngineCanvas detaches its native NSView whenever isVisible is false.
                            Positioned.fill(
                              child: IgnorePointer(
                                ignoring:
                                    _activeTab != InspectionTab.visualRender,
                                child: Opacity(
                                  opacity:
                                      _activeTab == InspectionTab.visualRender
                                          ? 1.0
                                          : 0.0,
                                  child: _buildVisualRenderPanels(context),
                                ),
                              ),
                            ),
                            if (_activeTab == InspectionTab.visualDiff)
                              Positioned.fill(
                                child: VisualGraphicDiffView(
                                  outputs: _outputs,
                                  activeEngines: _orderedSelectedEngines,
                                  source: _activeSource,
                                  isDark: widget.isDark,
                                ),
                              ),
                            if (_activeTab == InspectionTab.rawSvg)
                              Positioned.fill(
                                child: RawSvgOutputView(
                                  activeEngines: _orderedSelectedEngines,
                                  outputs: _outputs,
                                  peleDartMode: _peleDartOutputMode,
                                ),
                              ),
                            if (_activeTab == InspectionTab.svgTextDiff)
                              Positioned.fill(
                                child: SvgTextDiffView(
                                  diagramId: _selectedSample.id,
                                  activeEngines: _orderedSelectedEngines,
                                  outputs: _outputs,
                                  peleDartMode: _peleDartOutputMode,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_editorDockMode ==
                          EditorDockMode.bottomDock) ...<Widget>[
                        ResizableSplitter(
                          axis: Axis.vertical,
                          tooltip:
                              'Drag to resize bottom playground editor (double-click to reset)',
                          onDoubleTap:
                              () => setState(() => _editorBottomHeight = 195.0),
                          onDragDelta: (dy) {
                            setState(() {
                              _editorBottomHeight = (_editorBottomHeight - dy)
                                  .clamp(100.0, 540.0);
                            });
                          },
                        ),
                        SizedBox(
                          height: _editorBottomHeight,
                          child: _buildLiveSourceEditor(
                            context,
                            isLeftSplit: false,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopToolbar(BuildContext context, int totalSamples) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            IconButton(
              tooltip:
                  _showGallerySidebar
                      ? 'Hide Diagram Sidebar'
                      : 'Show Diagram Sidebar',
              icon: const Icon(Icons.view_sidebar_outlined, size: 18),
              visualDensity: VisualDensity.compact,
              onPressed:
                  () => setState(
                    () => _showGallerySidebar = !_showGallerySidebar,
                  ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.auto_graph, color: Color(0xFF00B4D8), size: 18),
            const SizedBox(width: 6),
            const Text(
              'pele_dart Studio',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(width: 12),
            // 1-Way / 2-Way / 3-Way Engine Selector Chips
            for (final engine in ComparisonEngine.values) ...<Widget>[
              FilterChip(
                avatar: CircleAvatar(backgroundColor: engine.accent, radius: 4),
                label: Text(
                  engine == ComparisonEngine.peleDart
                      ? 'pele_dart'
                      : (engine == ComparisonEngine.peleJs
                          ? 'pele (JS)'
                          : 'mermaid.js'),
                  style: const TextStyle(fontSize: 11.5),
                ),
                visualDensity: VisualDensity.compact,
                selected: _selectedEngines.contains(engine),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedEngines.add(engine);
                    } else if (_selectedEngines.length > 1) {
                      _selectedEngines.remove(engine);
                    }
                  });
                },
              ),
              const SizedBox(width: 6),
            ],
            PopupMenuButton<String>(
              tooltip: 'Quick Comparison Presets (1-Way / 2-Way / 3-Way)',
              onSelected: (preset) {
                setState(() {
                  _selectedEngines.clear();
                  if (preset == '1way_dart') {
                    _selectedEngines.add(ComparisonEngine.peleDart);
                  } else if (preset == '2way_pele') {
                    _selectedEngines.addAll(<ComparisonEngine>[
                      ComparisonEngine.peleDart,
                      ComparisonEngine.peleJs,
                    ]);
                  } else if (preset == '2way_mermaid') {
                    _selectedEngines.addAll(<ComparisonEngine>[
                      ComparisonEngine.peleDart,
                      ComparisonEngine.mermaidJs,
                    ]);
                  } else {
                    _selectedEngines.addAll(ComparisonEngine.values);
                  }
                  _resetEngineWeights();
                });
              },
              itemBuilder:
                  (_) => const <PopupMenuEntry<String>>[
                    PopupMenuItem(
                      value: '1way_dart',
                      child: Text('1-Way: pele_dart Only'),
                    ),
                    PopupMenuItem(
                      value: '2way_pele',
                      child: Text('2-Way: pele_dart vs obsidianmd/pele (JS)'),
                    ),
                    PopupMenuItem(
                      value: '2way_mermaid',
                      child: Text('2-Way: pele_dart vs mermaid.js'),
                    ),
                    PopupMenuItem(
                      value: '3way_all',
                      child: Text('3-Way: All 3 Renderers'),
                    ),
                  ],
              child: Chip(
                visualDensity: VisualDensity.compact,
                label: Text(
                  '${_selectedEngines.length}-Way ▾',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 4 Inspection Mode Tabs
            SegmentedButton<InspectionTab>(
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments:
                  InspectionTab.values
                      .map(
                        (t) => ButtonSegment<InspectionTab>(
                          value: t,
                          icon: Icon(t.icon, size: 14),
                          label: Text(
                            t.label,
                            style: const TextStyle(fontSize: 11.5),
                          ),
                        ),
                      )
                      .toList(),
              selected: <InspectionTab>{_activeTab},
              onSelectionChanged: (sel) {
                setState(() {
                  _activeTab = sel.first;
                });
              },
            ),
            const SizedBox(width: 12),
            // Editor Dock / Playground Layout Picker
            PopupMenuButton<EditorDockMode>(
              tooltip: 'Mermaid Playground Editor Position',
              onSelected: (mode) => setState(() => _editorDockMode = mode),
              itemBuilder:
                  (_) =>
                      EditorDockMode.values
                          .map(
                            (m) => PopupMenuItem<EditorDockMode>(
                              value: m,
                              child: Row(
                                children: <Widget>[
                                  Icon(m.icon, size: 16),
                                  const SizedBox(width: 8),
                                  Text(m.label),
                                ],
                              ),
                            ),
                          )
                          .toList(),
              child: Chip(
                visualDensity: VisualDensity.compact,
                avatar: Icon(_editorDockMode.icon, size: 14),
                label: Text(
                  _editorDockMode.label,
                  style: const TextStyle(fontSize: 11.5),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message:
                  'Toggle pele_dart between Flattened SVG (for vector_graphics) and CSS-Variable SVG (for upstream parity)',
              child: ActionChip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.tune, size: 14),
                label: Text(
                  _peleDartOutputMode == SvgOutputMode.flattened
                      ? 'Flattened'
                      : 'CSS Vars',
                  style: const TextStyle(fontSize: 11.5),
                ),
                onPressed: () {
                  setState(() {
                    _peleDartOutputMode =
                        _peleDartOutputMode == SvgOutputMode.flattened
                            ? SvgOutputMode.cssVariables
                            : SvgOutputMode.flattened;
                  });
                },
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Reset Zoom & Column Widths',
              icon: const Icon(Icons.center_focus_strong, size: 18),
              visualDensity: VisualDensity.compact,
              onPressed: () {
                _zoomController.value = Matrix4.identity();
                _resetEngineWeights();
              },
            ),
            IconButton(
              tooltip:
                  widget.isDark
                      ? 'Switch to Light Mode'
                      : 'Switch to Dark Mode',
              icon: Icon(
                widget.isDark ? Icons.light_mode : Icons.dark_mode,
                size: 18,
              ),
              visualDensity: VisualDensity.compact,
              onPressed: widget.onToggleTheme,
            ),
          ],
        ),
      ),
    );
  }

  /// Dedicated apples-to-apples timing comparison bar showing all 3 engines'
  /// pure `Mermaid -> SVG` median (`p50`) times, display/compile overhead,
  /// relative speed multiplier (`1.0×` vs `N×`), and a "Benchmark (15×)" button.
  Widget _buildFairTimingSummaryBar(BuildContext context) {
    final fastestMs = _fastestSvgGenMs();
    final detected = _outputs[ComparisonEngine.peleDart]?.detectedType;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.speed, size: 15, color: Color(0xFF00B4D8)),
          const SizedBox(width: 6),
          const Text(
            'Fair Timing (p50 SVG Gen):',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (final engine in ComparisonEngine.values) ...<Widget>[
                    _buildEngineTimingPill(context, engine, fastestMs),
                    const SizedBox(width: 10),
                  ],
                  if (detected != null)
                    Text(
                      'type: $detected',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Menlo',
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message:
                'Run 15 timed iterations (up to 250ms budget) across all 3 engines and report p50 median',
            child: FilledButton.tonalIcon(
              onPressed: () => _runPeleDartEngine(intensiveBenchmark: true),
              icon: const Icon(Icons.timer_outlined, size: 14),
              label: const Text(
                'Benchmark (15×)',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngineTimingPill(
    BuildContext context,
    ComparisonEngine engine,
    double? fastestMs,
  ) {
    final out = _outputs[engine];
    if (out == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircleAvatar(backgroundColor: engine.accent, radius: 4),
          const SizedBox(width: 5),
          Text(
            '${engine.id}: …',
            style: const TextStyle(fontSize: 11, fontFamily: 'Menlo'),
          ),
        ],
      );
    }
    if (out.error != null) {
      return Tooltip(
        message: out.error!,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircleAvatar(backgroundColor: engine.accent, radius: 4),
            const SizedBox(width: 5),
            Text(
              '${engine.id}: error',
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'Menlo',
                color: Colors.redAccent,
              ),
            ),
          ],
        ),
      );
    }

    final ratio =
        (fastestMs != null && fastestMs > 0.001)
            ? (out.svgGenMs / fastestMs)
            : 1.0;
    final isFastest = ratio <= 1.05;
    final prepLabel = engine == ComparisonEngine.peleDart ? 'VG' : 'DOM';

    return Tooltip(
      message:
          '${engine.label}\n'
          '• Pure Mermaid → SVG (p50 median of ${out.sampleRuns} runs): ${formatPeleTime(out.svgGenMs)} (min: ${formatPeleTime(out.minSvgGenMs)})\n'
          '• $prepLabel Display/Compile: ${formatPeleTime(out.displayPrepMs)}\n'
          '• End-to-End Total: ${formatPeleTime(out.totalMs)}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color:
                isFastest
                    ? Colors.green.withValues(alpha: 0.6)
                    : engine.accent.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircleAvatar(backgroundColor: engine.accent, radius: 4),
            const SizedBox(width: 5),
            Text(
              '${engine.id}: ',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'Menlo',
              ),
            ),
            Text(
              formatPeleTime(out.svgGenMs),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'Menlo',
                color: isFastest ? Colors.greenAccent : null,
              ),
            ),
            Text(
              ' (+$prepLabel ${formatPeleTime(out.displayPrepMs)})',
              style: TextStyle(
                fontSize: 10.5,
                fontFamily: 'Menlo',
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color:
                    isFastest
                        ? Colors.green.withValues(alpha: 0.22)
                        : Colors.amber.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isFastest ? '1.0× fastest' : '${ratio.toStringAsFixed(1)}×',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Menlo',
                  color: isFastest ? Colors.greenAccent : Colors.amberAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sub-sample picker bar showing the `1..6` `pele.run/playground` samples
  /// for the active diagram family, plus quick ad-hoc playground actions.
  Widget _buildSubSampleSelectorBar(BuildContext context) {
    final samples = _selectedSample.playgroundSamples;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: <Widget>[
          Flexible(
            flex: 0,
            child: Text(
              _isAdHocCustom
                  ? 'Ad-Hoc Playground:'
                  : '${_selectedSample.title} (${samples.length} samples):',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (var i = 0; i < samples.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(width: 6),
                    ChoiceChip(
                      label: Text(
                        samples[i].label,
                        style: const TextStyle(fontSize: 11),
                      ),
                      selected:
                          !_isAdHocCustom &&
                          _selectedPlaygroundSampleIndex == i,
                      visualDensity: VisualDensity.compact,
                      onSelected:
                          (_) => _selectSubSampleSource(samples[i].source, i),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          ActionChip(
            avatar: const Icon(Icons.edit_note, size: 14),
            label: const Text(
              'pele.run/playground Default',
              style: TextStyle(fontSize: 11),
            ),
            visualDensity: VisualDensity.compact,
            onPressed:
                () =>
                    _startAdHocPlayground(initialText: playgroundDefaultSource),
          ),
        ],
      ),
    );
  }

  Widget _buildGallerySidebar(BuildContext context) {
    final filtered =
        gallerySamples.where((s) {
          if (_tierFilter != null && s.tier != _tierFilter) return false;
          if (_searchQuery.isEmpty) return true;
          final q = _searchQuery.toLowerCase();
          return s.title.toLowerCase().contains(q) ||
              s.diagramType.toLowerCase().contains(q) ||
              s.description.toLowerCase().contains(q);
        }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _startAdHocPlayground(initialText: ''),
                      icon: const Icon(Icons.add_box_outlined, size: 15),
                      label: const Text(
                        'New Ad-Hoc Diagram',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Paste Mermaid Diagram from Clipboard',
                    icon: const Icon(Icons.content_paste, size: 16),
                    visualDensity: VisualDensity.compact,
                    onPressed: _pasteFromClipboard,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Filter 33 diagram families...',
                  prefixIcon: const Icon(Icons.search, size: 17),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                style: const TextStyle(fontSize: 12),
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  ChoiceChip(
                    label: const Text(
                      'All (33)',
                      style: TextStyle(fontSize: 11),
                    ),
                    selected: _tierFilter == null,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => _tierFilter = null),
                  ),
                  ChoiceChip(
                    label: const Text(
                      'Core (10)',
                      style: TextStyle(fontSize: 11),
                    ),
                    selected: _tierFilter == 1,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => _tierFilter = 1),
                  ),
                  ChoiceChip(
                    label: const Text(
                      'Ext (23)',
                      style: TextStyle(fontSize: 11),
                    ),
                    selected: _tierFilter == 2,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => _tierFilter = 2),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final sample = filtered[index];
              final isSelected =
                  !_isAdHocCustom && sample.id == _selectedSample.id;
              return ListTile(
                dense: true,
                selected: isSelected,
                selectedTileColor: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.35),
                title: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        sample.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (sample.beta)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'beta',
                          style: TextStyle(fontSize: 9.5),
                        ),
                      ),
                  ],
                ),
                subtitle: Text(
                  '${sample.diagramType} • ${sample.playgroundSamples.length} samples',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: () => _selectFamily(sample),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVisualRenderPanels(BuildContext context) {
    final active = _orderedSelectedEngines;
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = math.max(constraints.maxWidth, 300.0);
        return Row(
          children: <Widget>[
            for (var i = 0; i < active.length; i++) ...<Widget>[
              if (i > 0)
                ResizableSplitter(
                  axis: Axis.horizontal,
                  tooltip:
                      'Drag to resize engine columns (double-click to equalize)',
                  onDoubleTap: _resetEngineWeights,
                  onDragDelta: (dx) {
                    final leftEngine = active[i - 1];
                    final rightEngine = active[i];
                    final sumWeights = active.fold<double>(
                      0.0,
                      (s, e) => s + (_engineWeights[e] ?? 1.0),
                    );
                    final weightDelta = (dx / totalWidth) * sumWeights;
                    final nextLeft =
                        (_engineWeights[leftEngine] ?? 1.0) + weightDelta;
                    final nextRight =
                        (_engineWeights[rightEngine] ?? 1.0) - weightDelta;
                    if (nextLeft >= 0.25 && nextRight >= 0.25) {
                      setState(() {
                        _engineWeights[leftEngine] = nextLeft;
                        _engineWeights[rightEngine] = nextRight;
                      });
                    }
                  },
                ),
              Expanded(
                flex: ((_engineWeights[active[i]] ?? 1.0) * 1000).round().clamp(
                  250,
                  5000,
                ),
                child: _buildSingleVisualPanel(context, active[i]),
              ),
            ],
            // Keep hidden WebView states mounted for unselected JS engines so switching tabs or engines is instant
            for (final engine in ComparisonEngine.values)
              if (!active.contains(engine) &&
                  engine != ComparisonEngine.peleDart)
                SizedBox(
                  width: 0,
                  height: 0,
                  child: WebViewEngineCanvas(
                    key: GlobalObjectKey(engine),
                    engine: engine,
                    source: _activeSource,
                    isDark: widget.isDark,
                    isVisible: false,
                    benchmarkNonce: _benchmarkNonce,
                    onRendered: (res) {
                      if (mounted) {
                        setState(() {
                          _outputs[engine] = res;
                        });
                      }
                    },
                  ),
                ),
          ],
        );
      },
    );
  }

  Widget _buildSingleVisualPanel(
    BuildContext context,
    ComparisonEngine engine,
  ) {
    final out = _outputs[engine];
    final bgColor =
        widget.isDark ? const Color(0xFF14171F) : const Color(0xFFFFFFFF);
    final prepLabel = engine == ComparisonEngine.peleDart ? 'VG' : 'DOM';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: engine.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      engine.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (out != null && out.error == null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: engine.accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        formatPeleTime(out.svgGenMs),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Menlo',
                        ),
                      ),
                    ),
                ],
              ),
              if (out != null && out.error == null) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  'SVG Gen p50 (${out.sampleRuns}×, min ${formatPeleTime(out.minSvgGenMs)})  •  '
                  '$prepLabel: ${formatPeleTime(out.displayPrepMs)}  •  '
                  '${out.width.round()}×${out.height.round()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontFamily: 'Menlo',
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: bgColor,
            child:
                engine == ComparisonEngine.peleDart
                    ? _buildPeleDartVisualCanvas(out)
                    : WebViewEngineCanvas(
                      key: GlobalObjectKey(engine),
                      engine: engine,
                      source: _activeSource,
                      isDark: widget.isDark,
                      isVisible: _activeTab == InspectionTab.visualRender,
                      benchmarkNonce: _benchmarkNonce,
                      onRendered: (res) {
                        if (mounted) {
                          setState(() {
                            _outputs[engine] = res;
                          });
                        }
                      },
                    ),
          ),
        ),
      ],
    );
  }

  Widget _buildPeleDartVisualCanvas(EngineRenderOutput? out) {
    if (out == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (out.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            out.error!,
            style: const TextStyle(
              color: Colors.redAccent,
              fontFamily: 'Menlo',
              fontSize: 12,
            ),
          ),
        ),
      );
    }
    final bytes = out.compiledVectorBytes;
    if (bytes == null) {
      return const Center(child: Text('SVG rendered (inspect in Raw SVG tab)'));
    }
    final w = out.width > 0 ? out.width : 600.0;
    final h = out.height > 0 ? out.height : 400.0;
    return InteractiveViewer(
      transformationController: _zoomController,
      minScale: 0.2,
      maxScale: 8.0,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: w,
              height: h,
              child: createCompatVectorGraphic(
                loader: MemoryVectorBytesLoader(bytes),
                width: w,
                height: h,
                fit: BoxFit.contain,
                strategy: RenderingStrategy.picture,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveSourceEditor(
    BuildContext context, {
    required bool isLeftSplit,
  }) {
    final dartOut = _outputs[ComparisonEngine.peleDart];
    final hasError = dartOut?.error != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: <Widget>[
              const Icon(Icons.terminal, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _isAdHocCustom
                      ? 'Playground Editor (Ad-Hoc)'
                      : 'Playground Editor — ${_selectedSample.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Paste from Clipboard',
                icon: const Icon(Icons.content_paste, size: 15),
                visualDensity: VisualDensity.compact,
                onPressed: _pasteFromClipboard,
              ),
              IconButton(
                tooltip: 'Copy Mermaid Source',
                icon: const Icon(Icons.copy, size: 15),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: _editorController.text),
                  );
                },
              ),
              IconButton(
                tooltip: 'Clear Editor for Ad-Hoc Input',
                icon: const Icon(Icons.clear_all, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: () => _startAdHocPlayground(initialText: ''),
              ),
              IconButton(
                tooltip: 'Restore Active Gallery Sample',
                icon: const Icon(Icons.restore, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: () => _selectFamily(_selectedSample),
              ),
              IconButton(
                tooltip:
                    isLeftSplit
                        ? 'Dock Editor to Bottom'
                        : 'Dock Editor to Left Split',
                icon: Icon(
                  isLeftSplit ? Icons.dock : Icons.vertical_split,
                  size: 15,
                ),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  setState(() {
                    _editorDockMode =
                        isLeftSplit
                            ? EditorDockMode.bottomDock
                            : EditorDockMode.leftSplit;
                  });
                },
              ),
              IconButton(
                tooltip: 'Hide Editor',
                icon: const Icon(Icons.close, size: 15),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  setState(() {
                    _editorDockMode = EditorDockMode.hidden;
                  });
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _editorController,
              maxLines: null,
              expands: true,
              style: const TextStyle(
                fontFamily: 'Menlo',
                fontSize: 12,
                height: 1.4,
              ),
              decoration: const InputDecoration(
                hintText:
                    'Type or paste any Mermaid diagram here (e.g. flowchart TD, sequenceDiagram, mindmap...)',
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: _onEditorTextChanged,
            ),
          ),
        ),
        // Playground status / diagnostic footer (matching website/src/scripts/playground-status.ts)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color:
                hasError
                    ? Colors.red.withValues(alpha: 0.15)
                    : Theme.of(context).colorScheme.surfaceContainerLow,
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child:
              hasError
                  ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.error_outline,
                            size: 14,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(width: 6),
                          if (dartOut?.errorLine != null)
                            Text(
                              'Line ${dartOut!.errorLine}${dartOut.errorColumn != null ? ":${dartOut.errorColumn}" : ""} — ',
                              style: const TextStyle(
                                fontFamily: 'Menlo',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.redAccent,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              dartOut!.error!.split('\n').first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Menlo',
                                fontSize: 11,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (dartOut.errorSnippet != null &&
                          dartOut.errorSnippet!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            dartOut.errorSnippet!,
                            style: const TextStyle(
                              fontFamily: 'Menlo',
                              fontSize: 10.5,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                    ],
                  )
                  : Row(
                    children: <Widget>[
                      const Icon(
                        Icons.check_circle_outline,
                        size: 14,
                        color: Colors.greenAccent,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Valid ${dartOut?.detectedType ?? _selectedSample.diagramType} • '
                          '${_activeSource.split("\n").length} lines • '
                          'Live 150ms debounce  •  Drag borders to resize panels',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Menlo',
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
        ),
      ],
    );
  }
}

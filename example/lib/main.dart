import 'package:flutter/material.dart';
import 'package:pele_dart/pele_dart.dart';
import 'package:vector_graphics/vector_graphics.dart';

import 'engine_runner.dart';
import 'gallery_samples.dart';
import 'svg_diff_view.dart';
import 'visual_diff_view.dart';

void main() {
  runApp(const PeleDartComparisonApp());
}

enum InspectionTab {
  visualRender('Visual Render', Icons.visibility),
  visualDiff('Visual Graphic Diff', Icons.compare),
  rawSvg('Raw SVG Output', Icons.code),
  svgTextDiff('SVG Text Diff', Icons.difference);

  final String label;
  final IconData icon;
  const InspectionTab(this.label, this.icon);
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
    return MaterialApp(
      title: 'pele_dart 3-Way Comparison & Visual/SVG Diff Studio',
      debugShowCheckedModeBanner: false,
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00B4D8),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00B4D8),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: ComparisonStudioScreen(
        isDark: _isDark,
        onToggleTheme: () => setState(() => _isDark = !_isDark),
      ),
    );
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
  late final TextEditingController _editorController;
  String _activeSource = gallerySamples.first.source;
  String _searchQuery = '';
  int? _tierFilter;
  bool _showSourceEditor = true;

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
    _editorController.dispose();
    _zoomController.dispose();
    super.dispose();
  }

  void _runPeleDartEngine() {
    final res = renderWithPeleDart(_activeSource, isDark: widget.isDark);
    setState(() {
      _outputs[ComparisonEngine.peleDart] = res;
    });
  }

  void _selectSample(DiagramSample sample) {
    setState(() {
      _selectedSample = sample;
      _activeSource = sample.source;
      _editorController.text = sample.source;
    });
    _runPeleDartEngine();
  }

  List<ComparisonEngine> get _orderedSelectedEngines =>
      ComparisonEngine.values.where(_selectedEngines.contains).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          _buildTopToolbar(context),
          Expanded(
            child: Row(
              children: <Widget>[
                SizedBox(width: 280, child: _buildGallerySidebar(context)),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    children: <Widget>[
                      Expanded(
                        child: Stack(
                          children: <Widget>[
                            // Always keep background WebViews alive so JS engine SVGs stay updated across all 4 tabs
                            Offstage(
                              offstage:
                                  _activeTab != InspectionTab.visualRender,
                              child: _buildVisualRenderPanels(context),
                            ),
                            if (_activeTab == InspectionTab.visualDiff)
                              Positioned.fill(
                                child: VisualGraphicDiffView(
                                  outputs: _outputs,
                                  activeEngines: _orderedSelectedEngines,
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
                      if (_showSourceEditor) ...<Widget>[
                        const Divider(height: 1),
                        SizedBox(
                          height: 175,
                          child: _buildLiveSourceEditor(context),
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

  Widget _buildTopToolbar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.auto_graph, color: Color(0xFF00B4D8), size: 20),
              SizedBox(width: 8),
              Text(
                'pele_dart 3-Way Studio',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(width: 4),
          // 1-Way / 2-Way / 3-Way Engine Selector Chips
          for (final engine in ComparisonEngine.values)
            FilterChip(
              avatar: CircleAvatar(backgroundColor: engine.accent, radius: 5),
              label: Text(engine.label, style: const TextStyle(fontSize: 12)),
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
              label: Text(
                '${_selectedEngines.length}-Way View ▾',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          // 4 Inspection Mode Tabs
          SegmentedButton<InspectionTab>(
            segments:
                InspectionTab.values
                    .map(
                      (t) => ButtonSegment<InspectionTab>(
                        value: t,
                        icon: Icon(t.icon, size: 15),
                        label: Text(
                          t.label,
                          style: const TextStyle(fontSize: 12),
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
          // Flattened vs CSS Variables toggle for pele_dart
          Tooltip(
            message:
                'Toggle pele_dart between Flattened SVG (for vector_graphics) and CSS-Variable SVG (for upstream parity)',
            child: ActionChip(
              avatar: const Icon(Icons.tune, size: 15),
              label: Text(
                'pele_dart: ${_peleDartOutputMode == SvgOutputMode.flattened ? "Flattened" : "CSS Vars"}',
                style: const TextStyle(fontSize: 12),
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
          IconButton(
            tooltip: 'Reset Zoom (100%)',
            icon: const Icon(Icons.center_focus_strong, size: 18),
            onPressed: () => _zoomController.value = Matrix4.identity(),
          ),
          IconButton(
            tooltip:
                _showSourceEditor
                    ? 'Hide Mermaid Source Editor'
                    : 'Show Mermaid Source Editor',
            icon: Icon(
              _showSourceEditor ? Icons.terminal : Icons.terminal_outlined,
              size: 18,
            ),
            onPressed:
                () => setState(() => _showSourceEditor = !_showSourceEditor),
          ),
          IconButton(
            tooltip:
                widget.isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            icon: Icon(
              widget.isDark ? Icons.light_mode : Icons.dark_mode,
              size: 18,
            ),
            onPressed: widget.onToggleTheme,
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
              s.diagramType.toLowerCase().contains(q);
        }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                decoration: InputDecoration(
                  hintText: 'Filter 33 diagram families...',
                  prefixIcon: const Icon(Icons.search, size: 18),
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
              Row(
                children: <Widget>[
                  ChoiceChip(
                    label: const Text(
                      'All (33)',
                      style: TextStyle(fontSize: 11),
                    ),
                    selected: _tierFilter == null,
                    onSelected: (_) => setState(() => _tierFilter = null),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text(
                      'Tier 1 (10)',
                      style: TextStyle(fontSize: 11),
                    ),
                    selected: _tierFilter == 1,
                    onSelected: (_) => setState(() => _tierFilter = 1),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text(
                      'Tier 2 (23)',
                      style: TextStyle(fontSize: 11),
                    ),
                    selected: _tierFilter == 2,
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
              final isSelected = sample.id == _selectedSample.id;
              return ListTile(
                dense: true,
                selected: isSelected,
                selectedTileColor: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.35),
                title: Text(
                  sample.title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  '${sample.diagramType} • Tier ${sample.tier}',
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: () => _selectSample(sample),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVisualRenderPanels(BuildContext context) {
    final active = _orderedSelectedEngines;
    return Row(
      children: <Widget>[
        for (var i = 0; i < active.length; i++) ...<Widget>[
          if (i > 0) const VerticalDivider(width: 1),
          Expanded(child: _buildSingleVisualPanel(context, active[i])),
        ],
        // Keep hidden WebViews mounted for unselected JS engines so switching tabs or engines is instant
        for (final engine in ComparisonEngine.values)
          if (!active.contains(engine) && engine != ComparisonEngine.peleDart)
            SizedBox(
              width: 1,
              height: 1,
              child: Opacity(
                opacity: 0.0,
                child: WebViewEngineCanvas(
                  engine: engine,
                  source: _activeSource,
                  isDark: widget.isDark,
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

  Widget _buildSingleVisualPanel(
    BuildContext context,
    ComparisonEngine engine,
  ) {
    final out = _outputs[engine];
    final bgColor =
        widget.isDark ? const Color(0xFF14171F) : const Color(0xFFFFFFFF);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: engine.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  engine.label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (out != null)
                Text(
                  '${out.durationMs.toStringAsFixed(1)} ms  •  '
                  '${out.width.round()}×${out.height.round()}',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Menlo',
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
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
                      engine: engine,
                      source: _activeSource,
                      isDark: widget.isDark,
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
    return InteractiveViewer(
      transformationController: _zoomController,
      minScale: 0.2,
      maxScale: 8.0,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: VectorGraphic(
            loader: MemoryVectorBytesLoader(bytes),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildLiveSourceEditor(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: <Widget>[
              const Icon(Icons.edit_note, size: 16),
              const SizedBox(width: 6),
              Text(
                'Live Mermaid Source — ${_selectedSample.title} (${_selectedSample.diagramType})',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  _editorController.text = _selectedSample.source;
                  setState(() {
                    _activeSource = _selectedSample.source;
                  });
                  _runPeleDartEngine();
                },
                icon: const Icon(Icons.restore, size: 14),
                label: const Text(
                  'Reset Sample',
                  style: TextStyle(fontSize: 11),
                ),
              ),
              const SizedBox(width: 6),
              FilledButton.tonalIcon(
                onPressed: () {
                  setState(() {
                    _activeSource = _editorController.text;
                  });
                  _runPeleDartEngine();
                },
                icon: const Icon(Icons.play_arrow, size: 15),
                label: const Text(
                  'Render All 3',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: TextField(
              controller: _editorController,
              maxLines: null,
              expands: true,
              style: const TextStyle(fontFamily: 'Menlo', fontSize: 12),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (val) {
                setState(() {
                  _activeSource = val;
                });
                _runPeleDartEngine();
              },
            ),
          ),
        ),
      ],
    );
  }
}

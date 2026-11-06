import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
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

enum PlaygroundEditorTab {
  mermaid('Mermaid', Icons.code),
  styleCss('Style (CSS)', Icons.palette_outlined);

  final String label;
  final IconData icon;
  const PlaygroundEditorTab(this.label, this.icon);
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
      title: 'Pele Studio — 3-Way Comparison, Diff Studio & Playground',
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
  late final TextEditingController _styleCssController;
  late final TextEditingController _searchController;
  final FocusNode _browserFocusNode = FocusNode(debugLabel: 'DiagramBrowser');
  final FocusNode _searchFocusNode = FocusNode(debugLabel: 'DiagramSearch');
  final FocusNode _editorFocusNode = FocusNode(debugLabel: 'MermaidEditor');
  final FocusNode _styleCssFocusNode = FocusNode(debugLabel: 'StyleCssEditor');
  final ScrollController _sidebarScrollController = ScrollController();
  final ScrollController _subSampleScrollController = ScrollController();
  final Map<String, GlobalKey> _sidebarRowKeys = <String, GlobalKey>{};
  final Map<String, GlobalKey> _subSamplePillKeys = <String, GlobalKey>{};
  String _activeSource =
      gallerySamples.first.playgroundSamples.isNotEmpty
          ? gallerySamples.first.playgroundSamples.first.source
          : gallerySamples.first.source;
  String _searchQuery = '';
  int? _tierFilter;
  final Set<String> _expandedFamilyIds = <String>{gallerySamples.first.id};

  // Active diagram style preset and custom CSS
  PeleStylePreset _stylePreset = PeleStylePreset.dark;
  PelePalette _activePalette = PelePalette.dark;
  String _activeStyleCss = formatPaletteToCss(
    PelePalette.dark,
    selector: 'body, .pele',
  );
  PlaygroundEditorTab _editorTab = PlaygroundEditorTab.mermaid;

  // Resizable panel dimensions
  bool _showGallerySidebar = true;
  double _sidebarWidth = 232.0;
  EditorDockMode _editorDockMode = EditorDockMode.bottomDock;
  double _editorLeftWidth = 340.0;
  double _editorBottomHeight = 195.0;

  // Relative width weights for the 3 engine columns (resizable via splitters)
  final Map<ComparisonEngine, double> _engineWeights =
      <ComparisonEngine, double>{
        ComparisonEngine.peleDart: 1.0,
        ComparisonEngine.peleJs: 1.0,
        ComparisonEngine.mermaidJs: 1.0,
      };

  Timer? _debounceTimer;
  Timer? _cssDebounceTimer;
  int _benchmarkNonce = 0;

  final Set<ComparisonEngine> _selectedEngines = <ComparisonEngine>{
    ComparisonEngine.peleDart,
    ComparisonEngine.peleJs,
    ComparisonEngine.mermaidJs,
  };

  InspectionTab _activeTab = InspectionTab.visualRender;
  final SvgOutputMode _peleDartOutputMode = SvgOutputMode.flattened;
  final TransformationController _zoomController = TransformationController();

  final Map<ComparisonEngine, EngineRenderOutput> _outputs =
      <ComparisonEngine, EngineRenderOutput>{};

  @override
  void initState() {
    super.initState();
    _editorController = TextEditingController(text: _activeSource);
    _styleCssController = TextEditingController(
      text: formatPaletteToCss(_activePalette),
    );
    _searchController = TextEditingController();
    HardwareKeyboard.instance.addHandler(_handleHardwareKeyEvent);
    _runPeleDartEngine();
  }

  @override
  void didUpdateWidget(covariant ComparisonStudioScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDark != widget.isDark) {
      if (_stylePreset == PeleStylePreset.dark ||
          _stylePreset == PeleStylePreset.light) {
        _applyStylePreset(
          widget.isDark ? PeleStylePreset.dark : PeleStylePreset.light,
        );
      } else {
        _runPeleDartEngine();
      }
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKeyEvent);
    _debounceTimer?.cancel();
    _cssDebounceTimer?.cancel();
    _editorController.dispose();
    _styleCssController.dispose();
    _searchController.dispose();
    _browserFocusNode.dispose();
    _searchFocusNode.dispose();
    _editorFocusNode.dispose();
    _styleCssFocusNode.dispose();
    _sidebarScrollController.dispose();
    _subSampleScrollController.dispose();
    _zoomController.dispose();
    super.dispose();
  }

  GlobalKey _sidebarRowKey(String key) =>
      _sidebarRowKeys.putIfAbsent(key, () => GlobalKey());

  GlobalKey _subSamplePillKey(String key) =>
      _subSamplePillKeys.putIfAbsent(key, () => GlobalKey());

  List<DiagramSample> get _filteredFamilies {
    return gallerySamples.where((s) {
      if (_tierFilter != null && s.tier != _tierFilter) return false;
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final matchesFile = s.playgroundSamples.any(
        (item) =>
            item.fileName.toLowerCase().contains(q) ||
            item.label.toLowerCase().contains(q),
      );
      return s.title.toLowerCase().contains(q) ||
          s.diagramType.toLowerCase().contains(q) ||
          s.description.toLowerCase().contains(q) ||
          matchesFile;
    }).toList();
  }

  List<(DiagramSample, int)> get _filteredDiagramEntries {
    final entries = <(DiagramSample, int)>[];
    final q = _searchQuery.toLowerCase();
    for (final sample in _filteredFamilies) {
      if (sample.playgroundSamples.isEmpty) {
        entries.add((sample, 0));
        continue;
      }
      final familyTextMatches =
          q.isEmpty ||
          sample.title.toLowerCase().contains(q) ||
          sample.diagramType.toLowerCase().contains(q) ||
          sample.description.toLowerCase().contains(q);
      for (var i = 0; i < sample.playgroundSamples.length; i++) {
        final item = sample.playgroundSamples[i];
        if (familyTextMatches ||
            item.fileName.toLowerCase().contains(q) ||
            item.label.toLowerCase().contains(q)) {
          entries.add((sample, i));
        }
      }
    }
    return entries;
  }

  void _focusBrowserIfNeeded() {
    if (!_searchFocusNode.hasFocus) {
      _browserFocusNode.requestFocus();
    }
  }

  void _scheduleScrollActiveDiagramIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isAdHocCustom) return;
      final fileKey =
          _sidebarRowKeys['file:${_selectedSample.id}:$_selectedPlaygroundSampleIndex'];
      final familyKey = _sidebarRowKeys['family:${_selectedSample.id}'];
      final targetSidebarCtx =
          fileKey?.currentContext ?? familyKey?.currentContext;
      if (targetSidebarCtx != null) {
        Scrollable.ensureVisible(
          targetSidebarCtx,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
        Scrollable.ensureVisible(
          targetSidebarCtx,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
      }
      final pillKey =
          _subSamplePillKeys['pill:${_selectedSample.id}:$_selectedPlaygroundSampleIndex'];
      final targetPillCtx = pillKey?.currentContext;
      if (targetPillCtx != null) {
        Scrollable.ensureVisible(
          targetPillCtx,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
        Scrollable.ensureVisible(
          targetPillCtx,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
      }
    });
  }

  void _navigateDiagramBy(int delta) {
    final entries = _filteredDiagramEntries;
    if (entries.isEmpty) return;
    final currentIndex =
        _isAdHocCustom
            ? -1
            : entries.indexWhere(
              (e) =>
                  e.$1.id == _selectedSample.id &&
                  e.$2 == _selectedPlaygroundSampleIndex,
            );
    final int nextIndex;
    if (currentIndex < 0) {
      nextIndex = delta >= 0 ? 0 : entries.length - 1;
    } else {
      nextIndex =
          ((currentIndex + delta) % entries.length + entries.length) %
          entries.length;
    }
    final (nextSample, nextFileIdx) = entries[nextIndex];
    if (nextSample.playgroundSamples.isEmpty) {
      _selectFamily(nextSample);
    } else {
      _selectFamilyAndFile(nextSample, nextFileIdx);
    }
  }

  void _navigateFamilyBy(int delta) {
    final families = _filteredFamilies;
    if (families.isEmpty) return;
    final currentIndex =
        _isAdHocCustom
            ? -1
            : families.indexWhere((s) => s.id == _selectedSample.id);
    final int nextIndex;
    if (currentIndex < 0) {
      nextIndex = delta >= 0 ? 0 : families.length - 1;
    } else {
      nextIndex =
          ((currentIndex + delta) % families.length + families.length) %
          families.length;
    }
    _selectFamily(families[nextIndex]);
  }

  void _jumpToDiagramBoundary({required bool first}) {
    final entries = _filteredDiagramEntries;
    if (entries.isEmpty) return;
    final (sample, fileIdx) = first ? entries.first : entries.last;
    if (sample.playgroundSamples.isEmpty) {
      _selectFamily(sample);
    } else {
      _selectFamilyAndFile(sample, fileIdx);
    }
  }

  bool _handleHardwareKeyEvent(KeyEvent event) {
    if (!mounted) return false;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    if (ModalRoute.of(context)?.isCurrent == false) return false;

    final key = event.logicalKey;

    // If the Mermaid or CSS code editor is focused, only intercept Escape to
    // return focus to the diagram browser.
    if (_editorFocusNode.hasFocus || _styleCssFocusNode.hasFocus) {
      if (key == LogicalKeyboardKey.escape) {
        _browserFocusNode.requestFocus();
        return true;
      }
      return false;
    }

    // If the sidebar search box is focused, allow Up/Down arrow keys to step
    // through filtered diagrams immediately, and Escape to clear/unfocus.
    if (_searchFocusNode.hasFocus) {
      if (key == LogicalKeyboardKey.escape) {
        if (_searchQuery.isNotEmpty) {
          setState(() {
            _searchController.clear();
            _searchQuery = '';
          });
        }
        _browserFocusNode.requestFocus();
        return true;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        _navigateDiagramBy(1);
        return true;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        _navigateDiagramBy(-1);
        return true;
      }
      return false;
    }

    // Ignore if any other EditableText (e.g., dialog field) has primary focus.
    final primaryCtx = FocusManager.instance.primaryFocus?.context;
    if (primaryCtx != null &&
        (primaryCtx.widget is EditableText ||
            primaryCtx.findAncestorWidgetOfExactType<EditableText>() != null)) {
      return false;
    }

    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final isMeta = HardwareKeyboard.instance.isMetaPressed;
    final isControl = HardwareKeyboard.instance.isControlPressed;
    if (isMeta || isControl) return false;

    if (key == LogicalKeyboardKey.arrowDown) {
      if (isAlt) {
        _navigateFamilyBy(1);
      } else {
        _navigateDiagramBy(1);
      }
      return true;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (isAlt) {
        _navigateFamilyBy(-1);
      } else {
        _navigateDiagramBy(-1);
      }
      return true;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyJ) {
      _navigateDiagramBy(1);
      return true;
    }
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyK) {
      _navigateDiagramBy(-1);
      return true;
    }
    if (key == LogicalKeyboardKey.bracketRight ||
        key == LogicalKeyboardKey.pageDown) {
      _navigateFamilyBy(1);
      return true;
    }
    if (key == LogicalKeyboardKey.bracketLeft ||
        key == LogicalKeyboardKey.pageUp) {
      _navigateFamilyBy(-1);
      return true;
    }
    if (key == LogicalKeyboardKey.home) {
      _jumpToDiagramBoundary(first: true);
      return true;
    }
    if (key == LogicalKeyboardKey.end) {
      _jumpToDiagramBoundary(first: false);
      return true;
    }

    final digitIndex = switch (key) {
      LogicalKeyboardKey.digit1 => 0,
      LogicalKeyboardKey.digit2 => 1,
      LogicalKeyboardKey.digit3 => 2,
      LogicalKeyboardKey.digit4 => 3,
      LogicalKeyboardKey.digit5 => 4,
      LogicalKeyboardKey.digit6 => 5,
      LogicalKeyboardKey.digit7 => 6,
      LogicalKeyboardKey.digit8 => 7,
      LogicalKeyboardKey.digit9 => 8,
      _ => -1,
    };
    if (digitIndex >= 0 &&
        digitIndex < _selectedSample.playgroundSamples.length) {
      _selectFamilyAndFile(_selectedSample, digitIndex);
      return true;
    }

    return false;
  }

  void _applyStylePreset(PeleStylePreset preset) {
    _cssDebounceTimer?.cancel();
    final nextPalette =
        preset == PeleStylePreset.custom ? _activePalette : preset.palette;
    final editorCss = formatPaletteToCss(nextPalette);
    final webViewCss = formatPaletteToCss(nextPalette, selector: 'body, .pele');
    setState(() {
      _stylePreset = preset;
      _activePalette = nextPalette;
      _activeStyleCss = webViewCss;
      if (preset != PeleStylePreset.custom) {
        _styleCssController.text = editorCss;
      }
    });
    _runPeleDartEngine();
  }

  void _onStyleCssChanged(String nextCss) {
    _cssDebounceTimer?.cancel();
    _cssDebounceTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      final parsed = parsePaletteFromCss(
        nextCss,
        base: widget.isDark ? PelePalette.dark : PelePalette.light,
      );
      setState(() {
        _stylePreset = PeleStylePreset.custom;
        _activePalette = parsed;
        _activeStyleCss = formatPaletteToCss(parsed, selector: 'body, .pele');
      });
      _runPeleDartEngine();
    });
  }

  void _runPeleDartEngine({bool intensiveBenchmark = false}) {
    final res = renderWithPeleDart(
      _activeSource,
      isDark: _stylePreset.isDarkCanvas,
      customPalette: _activePalette,
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

  void _selectFamily(DiagramSample sample, {bool toggleExpand = false}) {
    _debounceTimer?.cancel();
    _focusBrowserIfNeeded();
    final initialSource =
        sample.playgroundSamples.isNotEmpty
            ? sample.playgroundSamples.first.source
            : sample.source;
    setState(() {
      if (toggleExpand) {
        if (_expandedFamilyIds.contains(sample.id) &&
            _selectedSample.id == sample.id &&
            !_isAdHocCustom) {
          _expandedFamilyIds.remove(sample.id);
        } else {
          _expandedFamilyIds.add(sample.id);
        }
      } else {
        _expandedFamilyIds.add(sample.id);
      }
      _selectedSample = sample;
      _selectedPlaygroundSampleIndex = 0;
      _isAdHocCustom = false;
      _activeSource = initialSource;
      _editorController.text = initialSource;
    });
    _runPeleDartEngine();
    _scheduleScrollActiveDiagramIntoView();
  }

  void _selectFamilyAndFile(DiagramSample sample, int fileIndex) {
    _debounceTimer?.cancel();
    _focusBrowserIfNeeded();
    final item = sample.playgroundSamples[fileIndex];
    setState(() {
      _expandedFamilyIds.add(sample.id);
      _selectedSample = sample;
      _selectedPlaygroundSampleIndex = fileIndex;
      _isAdHocCustom = false;
      _activeSource = item.source;
      _editorController.text = item.source;
    });
    _runPeleDartEngine();
    _scheduleScrollActiveDiagramIntoView();
  }

  void _rescanDiagramsFolder() {
    final refreshed = reloadGallerySamples();
    if (refreshed.isEmpty) return;
    final match = refreshed.firstWhere(
      (s) => s.id == _selectedSample.id,
      orElse: () => refreshed.first,
    );
    setState(() {
      _selectedSample = match;
      if (_selectedPlaygroundSampleIndex >= match.playgroundSamples.length) {
        _selectedPlaygroundSampleIndex = 0;
      }
    });
    if (mounted) {
      final totalFiles = refreshed.fold<int>(
        0,
        (sum, s) => sum + s.playgroundSamples.length,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(
            'Rescanned ${resolveDiagramsRootDir().path}: '
            '${refreshed.length} folders, $totalFiles .mmd/.mermaid files',
          ),
        ),
      );
    }
  }

  Future<void> _openDiagramsFolderInFinder() async {
    final dirPath = resolveDiagramsRootDir().path;
    try {
      await Process.run('open', <String>[dirPath]);
    } catch (_) {
      // Ignore if running on non-macOS host.
    }
  }

  Future<void> _promptSaveAsMmd(BuildContext context) async {
    final nameController = TextEditingController(text: 'custom_diagram.mmd');
    final savedName = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text(
            'Save Diagram to example/diagrams/03_custom/',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Enter a filename ending in .mmd or .mermaid:',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  style: const TextStyle(fontFamily: 'Menlo', fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: 'my_diagram.mmd',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed:
                  () => Navigator.of(ctx).pop(nameController.text.trim()),
              child: const Text('Save .mmd'),
            ),
          ],
        );
      },
    );
    nameController.dispose();
    if (savedName == null || savedName.isEmpty) return;
    final savedFile = saveCustomMermaidDiagram(
      fileName: savedName,
      source: _activeSource,
    );
    final refreshed = gallerySamples;
    final customFamily = refreshed.where((s) => s.tier == 3).firstOrNull;
    if (customFamily != null) {
      final idx = customFamily.playgroundSamples.indexWhere(
        (item) => item.filePath == savedFile.path,
      );
      _selectFamilyAndFile(customFamily, idx >= 0 ? idx : 0);
    } else {
      setState(() {});
    }
  }

  void _selectSubSampleSource(String source, int index) {
    _debounceTimer?.cancel();
    _focusBrowserIfNeeded();
    setState(() {
      _selectedPlaygroundSampleIndex = index;
      _isAdHocCustom = false;
      _activeSource = source;
      _editorController.text = source;
    });
    _runPeleDartEngine();
    _scheduleScrollActiveDiagramIntoView();
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

  void _resetEngineWeights() {
    setState(() {
      for (final e in ComparisonEngine.values) {
        _engineWeights[e] = 1.0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _browserFocusNode,
      autofocus: true,
      child: Scaffold(
        body: Column(
          children: <Widget>[
            _buildTopToolbar(context),
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
                      onDoubleTap: () => setState(() => _sidebarWidth = 232.0),
                      onDragDelta: (dx) {
                        setState(() {
                          _sidebarWidth = (_sidebarWidth + dx).clamp(
                            180.0,
                            460.0,
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
                      onDoubleTap:
                          () => setState(() => _editorLeftWidth = 340.0),
                      onDragDelta: (dx) {
                        setState(() {
                          _editorLeftWidth = (_editorLeftWidth + dx).clamp(
                            220.0,
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
                                    isDark: _stylePreset.isDarkCanvas,
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
                                () =>
                                    setState(() => _editorBottomHeight = 195.0),
                            onDragDelta: (dy) {
                              setState(() {
                                _editorBottomHeight = (_editorBottomHeight - dy)
                                    .clamp(110.0, 540.0);
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
      ),
    );
  }

  Widget _buildTopToolbar(BuildContext context) {
    final swatchBg = parseHexColor(_activePalette.bg);
    final swatchAccent = parseHexColor(
      _activePalette.accent ?? '#5b7bd5',
      fallback: const Color(0xFF5B7BD5),
    );

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip:
                _showGallerySidebar
                    ? 'Hide Diagram Sidebar'
                    : 'Show Diagram Sidebar',
            icon: const Icon(Icons.view_sidebar_outlined, size: 17),
            visualDensity: VisualDensity.compact,
            onPressed:
                () =>
                    setState(() => _showGallerySidebar = !_showGallerySidebar),
          ),
          const SizedBox(width: 4),
          Image.asset(
            'assets/app_icon.png',
            width: 20,
            height: 20,
            filterQuality: FilterQuality.medium,
            errorBuilder:
                (_, __, ___) => const Icon(
                  Icons.auto_graph,
                  color: Color(0xFF00B4D8),
                  size: 17,
                ),
          ),
          const SizedBox(width: 6),
          const Text(
            'Pele Studio',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(width: 8),
          // Primary 4-Mode Switcher centered
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SegmentedButton<InspectionTab>(
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
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
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Style / Theme Preset Selector
          PopupMenuButton<PeleStylePreset>(
            tooltip: 'Diagram Theme & Style Preset',
            onSelected: (preset) {
              if (preset == PeleStylePreset.custom) {
                setState(() {
                  _stylePreset = PeleStylePreset.custom;
                  _editorTab = PlaygroundEditorTab.styleCss;
                  if (_editorDockMode == EditorDockMode.hidden) {
                    _editorDockMode = EditorDockMode.bottomDock;
                  }
                });
              } else {
                _applyStylePreset(preset);
              }
            },
            itemBuilder:
                (_) => <PopupMenuEntry<PeleStylePreset>>[
                  for (final p in PeleStylePreset.values)
                    PopupMenuItem<PeleStylePreset>(
                      value: p,
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: parseHexColor(p.palette.bg),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: parseHexColor(
                                  p.palette.accent ?? '#5b7bd5',
                                ),
                                width: 2.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(p.label)),
                          if (_stylePreset == p)
                            const Icon(Icons.check, size: 15),
                        ],
                      ),
                    ),
                ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.7),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: swatchBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: swatchAccent, width: 2.2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Style: ${_stylePreset.label} ▾',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Clean Engines Popover (1-Way / 2-Way / 3-Way + Individual Toggles)
          PopupMenuButton<String>(
            tooltip: 'Active Comparison Engines',
            onSelected: (action) {
              setState(() {
                if (action.startsWith('toggle:')) {
                  final id = action.substring('toggle:'.length);
                  final eng = ComparisonEngine.values.firstWhere(
                    (e) => e.id == id,
                  );
                  if (_selectedEngines.contains(eng)) {
                    if (_selectedEngines.length > 1) {
                      _selectedEngines.remove(eng);
                    }
                  } else {
                    _selectedEngines.add(eng);
                  }
                } else {
                  _selectedEngines.clear();
                  if (action == '1way_dart') {
                    _selectedEngines.add(ComparisonEngine.peleDart);
                  } else if (action == '2way_pele') {
                    _selectedEngines.addAll(<ComparisonEngine>[
                      ComparisonEngine.peleDart,
                      ComparisonEngine.peleJs,
                    ]);
                  } else if (action == '2way_mermaid') {
                    _selectedEngines.addAll(<ComparisonEngine>[
                      ComparisonEngine.peleDart,
                      ComparisonEngine.mermaidJs,
                    ]);
                  } else {
                    _selectedEngines.addAll(ComparisonEngine.values);
                  }
                }
                _resetEngineWeights();
              });
            },
            itemBuilder:
                (_) => <PopupMenuEntry<String>>[
                  for (final eng in ComparisonEngine.values)
                    CheckedPopupMenuItem<String>(
                      value: 'toggle:${eng.id}',
                      checked: _selectedEngines.contains(eng),
                      child: Text(eng.label),
                    ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: '3way_all',
                    child: Text('3-Way: All 3 Engines'),
                  ),
                  const PopupMenuItem(
                    value: '2way_pele',
                    child: Text('2-Way: pele_dart vs pele (JS)'),
                  ),
                  const PopupMenuItem(
                    value: '2way_mermaid',
                    child: Text('2-Way: pele_dart vs mermaid.js'),
                  ),
                  const PopupMenuItem(
                    value: '1way_dart',
                    child: Text('1-Way: pele_dart Only'),
                  ),
                ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.7),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final eng in _orderedSelectedEngines) ...<Widget>[
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: eng.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                  const SizedBox(width: 2),
                  Text(
                    '${_selectedEngines.length}-Way ▾',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Run 15× Benchmark Across All Engines',
            icon: const Icon(Icons.speed, size: 17),
            visualDensity: VisualDensity.compact,
            onPressed: () => _runPeleDartEngine(intensiveBenchmark: true),
          ),
          IconButton(
            tooltip:
                'Toggle Playground Editor Position (Bottom / Left / Hidden)',
            icon: Icon(_editorDockMode.icon, size: 17),
            visualDensity: VisualDensity.compact,
            onPressed: () {
              setState(() {
                _editorDockMode = switch (_editorDockMode) {
                  EditorDockMode.bottomDock => EditorDockMode.leftSplit,
                  EditorDockMode.leftSplit => EditorDockMode.hidden,
                  EditorDockMode.hidden => EditorDockMode.bottomDock,
                };
              });
            },
          ),
          IconButton(
            tooltip:
                widget.isDark
                    ? 'Switch App to Light UI'
                    : 'Switch App to Dark UI',
            icon: Icon(
              widget.isDark ? Icons.light_mode : Icons.dark_mode,
              size: 17,
            ),
            visualDensity: VisualDensity.compact,
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
    );
  }

  /// Clean sub-sample pill bar showing the `1..6` `pele.run/playground` samples
  /// for the active diagram family.
  Widget _buildSubSampleSelectorBar(BuildContext context) {
    final samples = _selectedSample.playgroundSamples;
    final cs = Theme.of(context).colorScheme;
    final entries = _filteredDiagramEntries;
    final activeEntryIdx =
        _isAdHocCustom
            ? -1
            : entries.indexWhere(
              (e) =>
                  e.$1.id == _selectedSample.id &&
                  e.$2 == _selectedPlaygroundSampleIndex,
            );
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip:
                'Previous Diagram (↑ / ← / k)\nPrevious Folder: Alt+↑ or [',
            icon: const Icon(Icons.chevron_left, size: 17),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: () => _navigateDiagramBy(-1),
          ),
          IconButton(
            tooltip: 'Next Diagram (↓ / → / j)\nNext Folder: Alt+↓ or ]',
            icon: const Icon(Icons.chevron_right, size: 17),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: () => _navigateDiagramBy(1),
          ),
          const SizedBox(width: 4),
          Text(
            _isAdHocCustom ? 'Custom Diagram' : _selectedSample.title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          if (activeEntryIdx >= 0 && entries.isNotEmpty) ...<Widget>[
            const SizedBox(width: 6),
            Tooltip(
              message:
                  'Keyboard Navigation:\n'
                  '• ↑ / ↓ or ← / → (or j / k): Previous / Next diagram\n'
                  '• Alt+↑ / Alt+↓ or [ / ]: Previous / Next folder\n'
                  '• 1–9: Select sub-sample in current folder\n'
                  '• Home / End: First / Last diagram\n'
                  '• Esc: Return focus from code editor to browser',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${activeEntryIdx + 1}/${entries.length} ↑↓',
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'Menlo',
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              controller: _subSampleScrollController,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (var i = 0; i < samples.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(width: 4),
                    InkWell(
                      key: _subSamplePillKey('pill:${_selectedSample.id}:$i'),
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _selectSubSampleSource(samples[i].source, i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (!_isAdHocCustom &&
                                      _selectedPlaygroundSampleIndex == i)
                                  ? cs.primaryContainer
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color:
                                (!_isAdHocCustom &&
                                        _selectedPlaygroundSampleIndex == i)
                                    ? cs.primary.withValues(alpha: 0.4)
                                    : cs.outlineVariant.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          samples[i].label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                (!_isAdHocCustom &&
                                        _selectedPlaygroundSampleIndex == i)
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                            color:
                                (!_isAdHocCustom &&
                                        _selectedPlaygroundSampleIndex == i)
                                    ? cs.onPrimaryContainer
                                    : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed:
                () =>
                    _startAdHocPlayground(initialText: playgroundDefaultSource),
            icon: const Icon(Icons.edit_note, size: 14),
            label: const Text('Blank Canvas', style: TextStyle(fontSize: 11)),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGallerySidebar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allSamples = gallerySamples;
    final coreCount = allSamples.where((s) => s.tier == 1).length;
    final extCount = allSamples.where((s) => s.tier == 2).length;
    final customCount = allSamples.where((s) => s.tier == 3).length;

    final filtered = _filteredFamilies;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Folder Browser Header Bar
              Row(
                children: <Widget>[
                  Icon(
                    Icons.folder_special_outlined,
                    size: 14,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'example/diagrams/',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Menlo',
                        fontWeight: FontWeight.w700,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip:
                        'Rescan example/diagrams/ for new .mmd / .mermaid files',
                    icon: const Icon(Icons.refresh, size: 15),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    onPressed: _rescanDiagramsFolder,
                  ),
                  IconButton(
                    tooltip: 'Reveal example/diagrams/ folder in Finder',
                    icon: const Icon(Icons.folder_open, size: 15),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    onPressed: _openDiagramsFolderInFinder,
                  ),
                  IconButton(
                    tooltip: 'New Blank Diagram',
                    icon: const Icon(Icons.add, size: 16),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    onPressed: () => _startAdHocPlayground(initialText: ''),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 29,
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Filter folders or .mmd files...',
                    prefixIcon: const Icon(Icons.search, size: 14),
                    prefixIconConstraints: const BoxConstraints(minWidth: 28),
                    isDense: true,
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withValues(
                      alpha: 0.45,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(7),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(fontSize: 11.5),
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  for (final entry in <(int?, String)>[
                    (null, 'All (${allSamples.length})'),
                    (1, 'Core ($coreCount)'),
                    (2, 'Ext ($extCount)'),
                    if (customCount > 0) (3, 'Custom ($customCount)'),
                  ]) ...<Widget>[
                    if (entry.$1 != null) const SizedBox(width: 4),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () {
                          _focusBrowserIfNeeded();
                          setState(() => _tierFilter = entry.$1);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color:
                                _tierFilter == entry.$1
                                    ? cs.primaryContainer
                                    : cs.surfaceContainerHighest.withValues(
                                      alpha: 0.35,
                                    ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            entry.$2,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight:
                                  _tierFilter == entry.$1
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                              color:
                                  _tierFilter == entry.$1
                                      ? cs.onPrimaryContainer
                                      : cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            controller: _sidebarScrollController,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final sample in filtered)
                  Builder(
                    builder: (context) {
                      final isSelectedFamily =
                          !_isAdHocCustom && sample.id == _selectedSample.id;
                      final isExpanded =
                          _expandedFamilyIds.contains(sample.id) ||
                          _searchQuery.isNotEmpty;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            InkWell(
                              key: _sidebarRowKey('family:${sample.id}'),
                              borderRadius: BorderRadius.circular(6),
                              onTap:
                                  () =>
                                      _selectFamily(sample, toggleExpand: true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isSelectedFamily
                                          ? cs.primaryContainer.withValues(
                                            alpha: 0.55,
                                          )
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Icon(
                                      isExpanded
                                          ? Icons.keyboard_arrow_down
                                          : Icons.keyboard_arrow_right,
                                      size: 14,
                                      color: cs.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 3),
                                    Icon(
                                      isExpanded
                                          ? Icons.folder_open
                                          : Icons.folder_outlined,
                                      size: 14,
                                      color:
                                          isSelectedFamily
                                              ? cs.primary
                                              : cs.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        sample.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight:
                                              isSelectedFamily
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                          color:
                                              isSelectedFamily
                                                  ? cs.onPrimaryContainer
                                                  : cs.onSurface,
                                        ),
                                      ),
                                    ),
                                    if (sample.beta) ...<Widget>[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: cs.secondaryContainer
                                              .withValues(alpha: 0.7),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          'beta',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: cs.onSecondaryContainer,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      '${sample.playgroundSamples.length}',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontFamily: 'Menlo',
                                        color: cs.onSurfaceVariant.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isExpanded)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 20,
                                  top: 1,
                                  bottom: 3,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    for (
                                      var fIdx = 0;
                                      fIdx < sample.playgroundSamples.length;
                                      fIdx++
                                    )
                                      _buildMmdFileTreeRow(
                                        context,
                                        sample: sample,
                                        fileIndex: fIdx,
                                        isSelectedFile:
                                            isSelectedFamily &&
                                            _selectedPlaygroundSampleIndex ==
                                                fIdx,
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMmdFileTreeRow(
    BuildContext context, {
    required DiagramSample sample,
    required int fileIndex,
    required bool isSelectedFile,
  }) {
    final cs = Theme.of(context).colorScheme;
    final item = sample.playgroundSamples[fileIndex];
    final displayFile =
        item.fileName.isNotEmpty ? item.fileName : '${item.label}.mmd';
    return Padding(
      key: _sidebarRowKey('file:${sample.id}:$fileIndex'),
      padding: const EdgeInsets.symmetric(vertical: 0.5),
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: () => _selectFamilyAndFile(sample, fileIndex),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color:
                isSelectedFile
                    ? cs.primary.withValues(alpha: 0.16)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.description_outlined,
                size: 12.5,
                color:
                    isSelectedFile
                        ? cs.primary
                        : cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  displayFile,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Menlo',
                    fontWeight:
                        isSelectedFile ? FontWeight.w700 : FontWeight.w400,
                    color:
                        isSelectedFile
                            ? cs.primary
                            : cs.onSurfaceVariant.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
                    isDark: _stylePreset.isDarkCanvas,
                    customPalette: _activePalette,
                    customCss: _activeStyleCss,
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
    final bgColor = parseHexColor(
      _activePalette.bg,
      fallback:
          _stylePreset.isDarkCanvas
              ? const Color(0xFF14171F)
              : const Color(0xFFFFFFFF),
    );
    final cs = Theme.of(context).colorScheme;

    // Compute relative speed ratio vs fastest active engine
    double? fastestMs;
    for (final e in _selectedEngines) {
      final o = _outputs[e];
      if (o != null && o.error == null && o.svgGenMs > 0) {
        if (fastestMs == null || o.svgGenMs < fastestMs) {
          fastestMs = o.svgGenMs;
        }
      }
    }
    final ratio =
        (out != null && out.error == null && fastestMs != null && fastestMs > 0)
            ? out.svgGenMs / fastestMs
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: engine.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        engine.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (kDebugMode &&
                        engine == ComparisonEngine.peleDart) ...<Widget>[
                      const SizedBox(width: 6),
                      Tooltip(
                        message:
                            'Running in Flutter Debug JIT mode (assertions + unoptimized VM).\n'
                            'Run with `flutter run --release` or `--profile` for native AOT benchmark speeds.',
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.45),
                              width: 0.8,
                            ),
                          ),
                          child: const Text(
                            'DEBUG JIT',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Menlo',
                              color: Colors.amber,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (out != null && out.error == null) ...<Widget>[
                Text(
                  '${out.width.round()}×${out.height.round()}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontFamily: 'Menlo',
                    color: cs.onSurfaceVariant.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(width: 8),
                if (ratio != null && _selectedEngines.length > 1) ...<Widget>[
                  Text(
                    ratio <= 1.05 ? '1.0×' : '${ratio.toStringAsFixed(1)}×',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontFamily: 'Menlo',
                      fontWeight: FontWeight.w600,
                      color:
                          ratio <= 1.05
                              ? Colors.green
                              : cs.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: engine.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    formatPeleTime(out.svgGenMs),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Menlo',
                    ),
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
                      isDark: _stylePreset.isDarkCanvas,
                      customPalette: _activePalette,
                      customCss: _activeStyleCss,
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
    final cs = Theme.of(context).colorScheme;
    final isStyleTab = _editorTab == PlaygroundEditorTab.styleCss;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            children: <Widget>[
              // Segmented editor tab switcher: Mermaid Source vs Style (--pele-* CSS)
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _buildEditorSubTabButton(
                      context,
                      tab: PlaygroundEditorTab.mermaid,
                      icon: Icons.code,
                      label: 'Mermaid',
                    ),
                    _buildEditorSubTabButton(
                      context,
                      tab: PlaygroundEditorTab.styleCss,
                      icon: Icons.palette_outlined,
                      label: 'Style (CSS)',
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (!isStyleTab) ...<Widget>[
                IconButton(
                  tooltip:
                      'Save Diagram as .mmd to example/diagrams/03_custom/',
                  icon: const Icon(Icons.save_alt, size: 14),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _promptSaveAsMmd(context),
                ),
                IconButton(
                  tooltip: 'Paste Mermaid from Clipboard',
                  icon: const Icon(Icons.content_paste, size: 14),
                  visualDensity: VisualDensity.compact,
                  onPressed: _pasteFromClipboard,
                ),
                IconButton(
                  tooltip: 'Copy Mermaid Source',
                  icon: const Icon(Icons.copy, size: 14),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: _editorController.text),
                    );
                  },
                ),
                IconButton(
                  tooltip: 'Reset Sample Source',
                  icon: const Icon(Icons.restore, size: 15),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _selectFamily(_selectedSample),
                ),
              ] else ...<Widget>[
                IconButton(
                  tooltip: 'Copy Custom Style CSS',
                  icon: const Icon(Icons.copy, size: 14),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: _styleCssController.text),
                    );
                  },
                ),
                IconButton(
                  tooltip: 'Reset Style to Default',
                  icon: const Icon(Icons.restore, size: 15),
                  visualDensity: VisualDensity.compact,
                  onPressed:
                      () => _applyStylePreset(
                        widget.isDark
                            ? PeleStylePreset.dark
                            : PeleStylePreset.light,
                      ),
                ),
              ],
              IconButton(
                tooltip:
                    isLeftSplit
                        ? 'Dock Editor to Bottom'
                        : 'Dock Editor to Left Split',
                icon: Icon(
                  isLeftSplit ? Icons.dock : Icons.vertical_split,
                  size: 14,
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
                icon: const Icon(Icons.close, size: 14),
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
        if (isStyleTab)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  Text(
                    'Presets:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 6),
                  for (final preset in PeleStylePreset.values.where(
                    (p) => p != PeleStylePreset.custom,
                  )) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(5),
                        onTap: () => _applyStylePreset(preset),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color:
                                _stylePreset == preset
                                    ? cs.primaryContainer
                                    : cs.surface,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color:
                                  _stylePreset == preset
                                      ? cs.primary
                                      : cs.outlineVariant.withValues(
                                        alpha: 0.5,
                                      ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: parseHexColor(
                                    preset.palette.accent ?? '#527fff',
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                preset.label,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight:
                                      _stylePreset == preset
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child:
                isStyleTab
                    ? TextField(
                      controller: _styleCssController,
                      focusNode: _styleCssFocusNode,
                      maxLines: null,
                      expands: true,
                      style: const TextStyle(
                        fontFamily: 'Menlo',
                        fontSize: 11.5,
                        height: 1.45,
                      ),
                      decoration: const InputDecoration(
                        hintText:
                            'Edit --pele-* CSS variables here (e.g. --pele-bg: #14171f; --pele-accent: #527fff;)...',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: _onStyleCssChanged,
                    )
                    : TextField(
                      controller: _editorController,
                      focusNode: _editorFocusNode,
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
        // Playground status / diagnostic footer
        Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color:
                hasError
                    ? Colors.red.withValues(alpha: 0.15)
                    : cs.surfaceContainerLow,
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child:
              hasError
                  ? Row(
                    children: <Widget>[
                      const Icon(
                        Icons.error_outline,
                        size: 13,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(width: 6),
                      if (dartOut?.errorLine != null)
                        Text(
                          'Line ${dartOut!.errorLine}${dartOut.errorColumn != null ? ":${dartOut.errorColumn}" : ""} — ',
                          style: const TextStyle(
                            fontFamily: 'Menlo',
                            fontSize: 10.5,
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
                            fontSize: 10.5,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                  )
                  : Row(
                    children: <Widget>[
                      Icon(
                        isStyleTab
                            ? Icons.palette_outlined
                            : Icons.check_circle_outline,
                        size: 13,
                        color:
                            isStyleTab
                                ? parseHexColor(
                                  _activePalette.accent ?? '#527fff',
                                )
                                : Colors.green,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          isStyleTab
                              ? 'Style: ${_stylePreset.label} • Edit any --pele-* hex value above to restyle live'
                              : '${dartOut?.detectedType ?? _selectedSample.diagramType} • ${_activeSource.split("\n").length} lines • Style: ${_stylePreset.label}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontFamily: 'Menlo',
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
        ),
      ],
    );
  }

  Widget _buildEditorSubTabButton(
    BuildContext context, {
    required PlaygroundEditorTab tab,
    required IconData icon,
    required String label,
  }) {
    final selected = _editorTab == tab;
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(5),
      onTap: () => setState(() => _editorTab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 12.5,
              color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

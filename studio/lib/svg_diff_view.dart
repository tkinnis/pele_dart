import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pele_dart/pele_dart.dart';

import 'engine_runner.dart';
import 'mac_controls.dart';

/// Pretty-prints a single-line or compact SVG string into indented multi-line XML
/// so human inspection and line-by-line diffs are clean and readable.
String prettyPrintSvg(String rawSvg) {
  if (rawSvg.trim().isEmpty) return '';
  final tokens = rawSvg
      .replaceAll('><', '>\n<')
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty);

  final buffer = StringBuffer();
  var indent = 0;
  for (final token in tokens) {
    final isClosing = token.startsWith('</');
    final isSelfClosing =
        token.endsWith('/>') ||
        token.startsWith('<?') ||
        token.startsWith('<!');
    final hasInlineClose = !isClosing && !isSelfClosing && token.contains('</');

    if (isClosing && indent > 0) {
      indent--;
    }
    buffer.writeln('${'  ' * indent}$token');
    if (!isClosing &&
        !isSelfClosing &&
        !hasInlineClose &&
        token.startsWith('<')) {
      indent++;
    }
  }
  return buffer.toString().trimRight();
}

/// Counts key SVG tags for quick structural comparison.
String summarizeSvgElements(String svg) {
  int countTag(String tag) => RegExp('<$tag\\b').allMatches(svg).length;
  final paths = countTag('path');
  final rects = countTag('rect');
  final texts = countTag('text');
  final groups = countTag('g');
  final kb = (svg.length / 1024.0).toStringAsFixed(1);
  return '${kb}KB  •  <g>:$groups  <path>:$paths  <rect>:$rects  <text>:$texts';
}

/// Tab 3: Raw SVG Output View (1-way, 2-way, or 3-way side-by-side pretty-printed SVG XML).
class RawSvgOutputView extends StatelessWidget {
  final List<ComparisonEngine> activeEngines;
  final Map<ComparisonEngine, EngineRenderOutput> outputs;
  final SvgOutputMode peleDartMode;

  const RawSvgOutputView({
    super.key,
    required this.activeEngines,
    required this.outputs,
    required this.peleDartMode,
  });

  @override
  Widget build(BuildContext context) {
    if (activeEngines.isEmpty) {
      return const Center(child: Text('Select at least one engine above.'));
    }
    return Row(
      children: <Widget>[
        for (var i = 0; i < activeEngines.length; i++) ...<Widget>[
          if (i > 0) const VerticalDivider(width: 1),
          Expanded(child: _buildSvgSourcePanel(context, activeEngines[i])),
        ],
      ],
    );
  }

  Widget _buildSvgSourcePanel(BuildContext context, ComparisonEngine engine) {
    final out = outputs[engine];
    final rawSvg =
        out == null
            ? ''
            : (engine == ComparisonEngine.peleDart
                ? out.svgForMode(peleDartMode)
                : out.cssVarsSvg);
    final formatted = prettyPrintSvg(rawSvg);
    final lines = formatted.isEmpty ? const <String>[] : formatted.split('\n');

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      engine == ComparisonEngine.peleDart
                          ? '${engine.label} [${peleDartMode.name}]'
                          : engine.label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      summarizeSvgElements(rawSvg),
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Copy formatted SVG to clipboard',
                icon: const Icon(Icons.copy, size: 16),
                onPressed:
                    formatted.isEmpty
                        ? null
                        : () {
                          Clipboard.setData(ClipboardData(text: formatted));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Copied ${engine.label} SVG (${lines.length} lines)',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
              ),
            ],
          ),
        ),
        Expanded(
          child:
              out?.error != null
                  ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      out!.error!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontFamily: 'Menlo',
                        fontSize: 12,
                      ),
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: lines.length,
                    itemBuilder: (context, index) {
                      final line = lines[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 1,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            SizedBox(
                              width: 42,
                              child: Text(
                                '${index + 1}',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontFamily: 'Menlo',
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SelectableText(
                                line,
                                style: const TextStyle(
                                  fontFamily: 'Menlo',
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}

enum ExternalDiffTool {
  opendiff('Xcode FileMerge (opendiff)', 'opendiff', <String>[]),
  vscode('VS Code (code --diff)', 'code', <String>['--diff']),
  kaleidoscope('Kaleidoscope (ksdiff)', 'ksdiff', <String>[]),
  bcomp('Beyond Compare (bcomp)', 'bcomp', <String>[]);

  final String label;
  final String executable;
  final List<String> extraArgs;
  const ExternalDiffTool(this.label, this.executable, this.extraArgs);
}

enum _DiffKind { equal, added, removed }

class _DiffLine {
  final _DiffKind kind;
  final int? lineA;
  final int? lineB;
  final String text;

  const _DiffLine({
    required this.kind,
    this.lineA,
    this.lineB,
    required this.text,
  });
}

/// Tab 4: SVG Text Diff View + External Diff Tool Launcher.
class SvgTextDiffView extends StatefulWidget {
  final String diagramId;
  final List<ComparisonEngine> activeEngines;
  final Map<ComparisonEngine, EngineRenderOutput> outputs;
  final SvgOutputMode peleDartMode;

  const SvgTextDiffView({
    super.key,
    required this.diagramId,
    required this.activeEngines,
    required this.outputs,
    required this.peleDartMode,
  });

  @override
  State<SvgTextDiffView> createState() => _SvgTextDiffViewState();
}

class _SvgTextDiffViewState extends State<SvgTextDiffView> {
  late ComparisonEngine _engineA;
  late ComparisonEngine _engineB;
  ExternalDiffTool _externalTool = ExternalDiffTool.opendiff;
  bool _changesOnly = false;
  bool _compareCssVarsForParity = true;

  @override
  void initState() {
    super.initState();
    if (widget.activeEngines.length >= 2) {
      _engineA = widget.activeEngines[0];
      _engineB = widget.activeEngines[1];
    } else {
      _engineA = ComparisonEngine.peleDart;
      _engineB = ComparisonEngine.peleJs;
    }
  }

  String _svgFor(ComparisonEngine engine) {
    final out = widget.outputs[engine];
    if (out == null) return '';
    if (_compareCssVarsForParity) {
      return out.cssVarsSvg;
    }
    if (engine == ComparisonEngine.peleDart) {
      return out.svgForMode(widget.peleDartMode);
    }
    return out.flattenedSvg;
  }

  List<_DiffLine> _computeLineDiff(List<String> a, List<String> b) {
    // Bounded Myers/LCS diff for interactive UI responsiveness.
    const maxMatrix = 900;
    if (a.length * b.length <= maxMatrix * maxMatrix) {
      final n = a.length;
      final m = b.length;
      final dp = List<List<int>>.generate(
        n + 1,
        (_) => List<int>.filled(m + 1, 0),
      );
      for (var i = n - 1; i >= 0; i--) {
        for (var j = m - 1; j >= 0; j--) {
          if (a[i] == b[j]) {
            dp[i][j] = 1 + dp[i + 1][j + 1];
          } else {
            dp[i][j] = math.max<int>(dp[i + 1][j], dp[i][j + 1]);
          }
        }
      }
      final result = <_DiffLine>[];
      var i = 0;
      var j = 0;
      while (i < n && j < m) {
        if (a[i] == b[j]) {
          result.add(
            _DiffLine(
              kind: _DiffKind.equal,
              lineA: i + 1,
              lineB: j + 1,
              text: a[i],
            ),
          );
          i++;
          j++;
        } else if (dp[i + 1][j] >= dp[i][j + 1]) {
          result.add(
            _DiffLine(kind: _DiffKind.removed, lineA: i + 1, text: a[i]),
          );
          i++;
        } else {
          result.add(
            _DiffLine(kind: _DiffKind.added, lineB: j + 1, text: b[j]),
          );
          j++;
        }
      }
      while (i < n) {
        result.add(
          _DiffLine(kind: _DiffKind.removed, lineA: i + 1, text: a[i]),
        );
        i++;
      }
      while (j < m) {
        result.add(_DiffLine(kind: _DiffKind.added, lineB: j + 1, text: b[j]));
        j++;
      }
      return result;
    }

    // Fallback linear diff for very large SVGs (>900 lines).
    final result = <_DiffLine>[];
    final maxLen = math.max<int>(a.length, b.length);
    for (var idx = 0; idx < maxLen; idx++) {
      final lineA = idx < a.length ? a[idx] : null;
      final lineB = idx < b.length ? b[idx] : null;
      if (lineA == lineB && lineA != null) {
        result.add(
          _DiffLine(
            kind: _DiffKind.equal,
            lineA: idx + 1,
            lineB: idx + 1,
            text: lineA,
          ),
        );
      } else {
        if (lineA != null) {
          result.add(
            _DiffLine(kind: _DiffKind.removed, lineA: idx + 1, text: lineA),
          );
        }
        if (lineB != null) {
          result.add(
            _DiffLine(kind: _DiffKind.added, lineB: idx + 1, text: lineB),
          );
        }
      }
    }
    return result;
  }

  Future<void> _launchExternalDiffTool(
    String formattedA,
    String formattedB,
  ) async {
    try {
      final tmpDir = Directory.systemTemp;
      final fileA = File(
        '${tmpDir.path}/pele_dart_${widget.diagramId}_${_engineA.id}.svg',
      );
      final fileB = File(
        '${tmpDir.path}/pele_dart_${widget.diagramId}_${_engineB.id}.svg',
      );
      await fileA.writeAsString('$formattedA\n');
      await fileB.writeAsString('$formattedB\n');

      await Process.start(_externalTool.executable, <String>[
        ..._externalTool.extraArgs,
        fileA.path,
        fileB.path,
      ], mode: ProcessStartMode.detached);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Launched ${_externalTool.label}:\n${fileA.path}\n${fileB.path}',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not launch ${_externalTool.executable}: $e\n'
              '(SVG files were written to ${Directory.systemTemp.path})',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedA = prettyPrintSvg(_svgFor(_engineA));
    final formattedB = prettyPrintSvg(_svgFor(_engineB));
    final linesA =
        formattedA.isEmpty ? const <String>[] : formattedA.split('\n');
    final linesB =
        formattedB.isEmpty ? const <String>[] : formattedB.split('\n');

    final diffLines = _computeLineDiff(linesA, linesB);
    final addedCount = diffLines.where((d) => d.kind == _DiffKind.added).length;
    final removedCount =
        diffLines.where((d) => d.kind == _DiffKind.removed).length;
    final equalCount = diffLines.where((d) => d.kind == _DiffKind.equal).length;
    final visibleLines =
        _changesOnly
            ? diffLines.where((d) => d.kind != _DiffKind.equal).toList()
            : diffLines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _buildEngineSelector('Base (A):', _engineA, (val) {
                  setState(() => _engineA = val);
                }),
                const SizedBox(width: 4),
                MacIconButton(
                  tooltip: 'Swap Base (A) and Compare (B)',
                  icon: Icons.swap_horiz,
                  size: 24,
                  iconSize: 15,
                  onPressed: () {
                    setState(() {
                      final tmp = _engineA;
                      _engineA = _engineB;
                      _engineB = tmp;
                    });
                  },
                ),
                const SizedBox(width: 4),
                _buildEngineSelector('Compare (B):', _engineB, (val) {
                  setState(() => _engineB = val);
                }),
                const SizedBox(width: 10),
                MacToggleButton(
                  label: 'Compare CSS-Var SVG',
                  tooltip: 'Compare upstream-parity CSS-variable SVG markup',
                  selected: _compareCssVarsForParity,
                  onChanged:
                      (v) => setState(() => _compareCssVarsForParity = v),
                ),
                const SizedBox(width: 6),
                MacToggleButton(
                  label: 'Changes Only',
                  selected: _changesOnly,
                  onChanged: (v) => setState(() => _changesOnly = v),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        addedCount == 0 && removedCount == 0
                            ? Colors.green.withValues(alpha: 0.18)
                            : Colors.amber.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color:
                          addedCount == 0 && removedCount == 0
                              ? Colors.green.withValues(alpha: 0.45)
                              : Colors.amber.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    addedCount == 0 && removedCount == 0
                        ? '100% Identical SVG ($equalCount lines)'
                        : '=$equalCount  -$removedCount  +$addedCount lines',
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'Menlo',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                MacPopupButton<ExternalDiffTool>(
                  value: _externalTool,
                  items: <MacPopupItem<ExternalDiffTool>>[
                    for (final t in ExternalDiffTool.values)
                      MacPopupItem<ExternalDiffTool>(value: t, label: t.label),
                  ],
                  onChanged: (t) => setState(() => _externalTool = t),
                ),
                const SizedBox(width: 6),
                MacToolbarButton(
                  primary: true,
                  onPressed:
                      () => _launchExternalDiffTool(formattedA, formattedB),
                  icon: Icons.open_in_new,
                  label: 'External Diff',
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child:
              visibleLines.isEmpty
                  ? const Center(
                    child: Text(
                      'No line differences between selected engines!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: visibleLines.length,
                    itemBuilder: (context, index) {
                      final d = visibleLines[index];
                      Color? rowBg;
                      String prefix = ' ';
                      Color prefixColor =
                          Theme.of(context).colorScheme.onSurfaceVariant;
                      if (d.kind == _DiffKind.added) {
                        rowBg = Colors.green.withValues(alpha: 0.16);
                        prefix = '+';
                        prefixColor = Colors.greenAccent;
                      } else if (d.kind == _DiffKind.removed) {
                        rowBg = Colors.red.withValues(alpha: 0.16);
                        prefix = '-';
                        prefixColor = Colors.redAccent;
                      }
                      return Container(
                        color: rowBg,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 1.5,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            SizedBox(
                              width: 38,
                              child: Text(
                                d.lineA?.toString() ?? '',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontFamily: 'Menlo',
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 38,
                              child: Text(
                                d.lineB?.toString() ?? '',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontFamily: 'Menlo',
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 14,
                              child: Text(
                                prefix,
                                style: TextStyle(
                                  fontFamily: 'Menlo',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: prefixColor,
                                ),
                              ),
                            ),
                            Expanded(
                              child: SelectableText(
                                d.text,
                                style: const TextStyle(
                                  fontFamily: 'Menlo',
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildEngineSelector(
    String label,
    ComparisonEngine current,
    ValueChanged<ComparisonEngine> onChanged,
  ) {
    return MacPopupButton<ComparisonEngine>(
      prefixLabel: label,
      value: current,
      items: <MacPopupItem<ComparisonEngine>>[
        for (final e in ComparisonEngine.values)
          MacPopupItem<ComparisonEngine>(
            value: e,
            label: e.label,
            dotColor: e.accent,
          ),
      ],
      onChanged: onChanged,
    );
  }
}

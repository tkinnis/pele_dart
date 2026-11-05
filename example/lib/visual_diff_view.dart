import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:vector_graphics/vector_graphics_compat.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart' as vgc;

import 'engine_runner.dart';

enum VisualDiffSubMode {
  splitCurtain('Split-Curtain', Icons.vertical_split),
  colorOverlay('Cyan / Magenta Overlay', Icons.layers),
  pixelHeatmap('Pixel-Diff Heatmap', Icons.grid_on),
  blinkToggle('In-Place Blink', Icons.flip);

  final String label;
  final IconData icon;
  const VisualDiffSubMode(this.label, this.icon);
}

class VisualGraphicDiffView extends StatefulWidget {
  final Map<ComparisonEngine, EngineRenderOutput> outputs;
  final List<ComparisonEngine> activeEngines;
  final String source;
  final bool isDark;

  const VisualGraphicDiffView({
    super.key,
    required this.outputs,
    required this.activeEngines,
    required this.source,
    required this.isDark,
  });

  @override
  State<VisualGraphicDiffView> createState() => _VisualGraphicDiffViewState();
}

class _VisualGraphicDiffViewState extends State<VisualGraphicDiffView> {
  VisualDiffSubMode _subMode = VisualDiffSubMode.splitCurtain;
  late ComparisonEngine _engineA;
  late ComparisonEngine _engineB;

  double _curtainFraction = 0.5;
  double _overlayOpacity = 0.55;
  int _pixelTolerance = 12;
  bool _blinkShowB = false;
  bool _autoBlink = false;
  Timer? _blinkTimer;

  final GlobalKey _repaintKeyA = GlobalKey();
  final GlobalKey _repaintKeyB = GlobalKey();

  ui.Image? _heatmapImage;
  double? _matchPercentage;
  int? _diffPixelCount;
  int? _totalPixelCount;
  bool _computingHeatmap = false;

  @override
  void initState() {
    super.initState();
    _syncDefaultPair();
  }

  @override
  void didUpdateWidget(covariant VisualGraphicDiffView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.outputs != widget.outputs ||
        oldWidget.isDark != widget.isDark) {
      _heatmapImage?.dispose();
      _heatmapImage = null;
      _matchPercentage = null;
      if (_subMode == VisualDiffSubMode.pixelHeatmap) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _computeHeatmap());
      }
    }
  }

  void _syncDefaultPair() {
    if (widget.activeEngines.length >= 2) {
      _engineA = widget.activeEngines[0];
      _engineB = widget.activeEngines[1];
    } else {
      _engineA = ComparisonEngine.peleDart;
      _engineB = ComparisonEngine.peleJs;
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _heatmapImage?.dispose();
    super.dispose();
  }

  void _toggleAutoBlink(bool enabled) {
    _blinkTimer?.cancel();
    setState(() {
      _autoBlink = enabled;
    });
    if (enabled) {
      _blinkTimer = Timer.periodic(const Duration(milliseconds: 550), (_) {
        if (mounted) {
          setState(() {
            _blinkShowB = !_blinkShowB;
          });
        }
      });
    }
  }

  Future<void> _computeHeatmap() async {
    if (_computingHeatmap || !mounted) return;
    final boundaryA =
        _repaintKeyA.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    final boundaryB =
        _repaintKeyB.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundaryA == null || boundaryB == null) return;

    setState(() {
      _computingHeatmap = true;
    });

    try {
      final imgA = await boundaryA.toImage(pixelRatio: 1.5);
      final imgB = await boundaryB.toImage(pixelRatio: 1.5);
      final w = math.min<int>(imgA.width, imgB.width);
      final h = math.min<int>(imgA.height, imgB.height);
      final bytesA = await imgA.toByteData(format: ui.ImageByteFormat.rawRgba);
      final bytesB = await imgB.toByteData(format: ui.ImageByteFormat.rawRgba);
      imgA.dispose();
      imgB.dispose();

      if (bytesA == null || bytesB == null || w == 0 || h == 0) {
        if (mounted) setState(() => _computingHeatmap = false);
        return;
      }

      final dataA = bytesA.buffer.asUint8List();
      final dataB = bytesB.buffer.asUint8List();
      final outRgba = Uint8List(w * h * 4);

      var diffPixels = 0;
      final totalPixels = w * h;
      final tol = _pixelTolerance;

      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final idx = (y * w + x) * 4;
          if (idx + 3 >= dataA.length || idx + 3 >= dataB.length) continue;

          final rA = dataA[idx];
          final gA = dataA[idx + 1];
          final bA = dataA[idx + 2];
          final aA = dataA[idx + 3];

          final rB = dataB[idx];
          final gB = dataB[idx + 1];
          final bB = dataB[idx + 2];
          final aB = dataB[idx + 3];

          final dr = (rA - rB).abs();
          final dg = (gA - gB).abs();
          final db = (bA - bB).abs();
          final da = (aA - aB).abs();

          if (dr > tol || dg > tol || db > tol || da > tol) {
            diffPixels++;
            // High-contrast hot magenta/red diff pixel
            outRgba[idx] = 255;
            outRgba[idx + 1] = 28;
            outRgba[idx + 2] = 116;
            outRgba[idx + 3] = 255;
          } else {
            // Dimmed grayscale baseline pixel
            final luma = ((rA * 299 + gA * 587 + bA * 114) ~/ 1000);
            final dimmed =
                widget.isDark ? (luma * 45 ~/ 100) : (210 + (luma - 210) ~/ 3);
            outRgba[idx] = dimmed.clamp(0, 255);
            outRgba[idx + 1] = dimmed.clamp(0, 255);
            outRgba[idx + 2] = dimmed.clamp(0, 255);
            outRgba[idx + 3] = math.max<int>(aA, 220);
          }
        }
      }

      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        outRgba,
        w,
        h,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      final decoded = await completer.future;
      if (mounted) {
        setState(() {
          _heatmapImage?.dispose();
          _heatmapImage = decoded;
          _diffPixelCount = diffPixels;
          _totalPixelCount = totalPixels;
          _matchPercentage = ((totalPixels - diffPixels) / totalPixels) * 100.0;
          _computingHeatmap = false;
        });
      } else {
        decoded.dispose();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _computingHeatmap = false;
        });
      }
    }
  }

  /// Renders an engine's output as a pure-Flutter vector canvas so both Engine A
  /// and Engine B can be composited, tinted, curtain-clipped, and raster-diffed on the GPU.
  Widget _buildVectorSurface(ComparisonEngine engine) {
    final out = widget.outputs[engine];
    if (out == null) {
      return const Center(child: Text('Waiting for engine output...'));
    }
    if (out.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '${engine.label} Error:\n${out.error}',
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
        ),
      );
    }

    Uint8List? bytes = out.compiledVectorBytes;
    if (bytes == null && out.flattenedSvg.isNotEmpty) {
      try {
        bytes = vgc.encodeSvg(
          xml: out.flattenedSvg,
          debugName: engine.id,
          enableMaskingOptimizer: false,
          enableClippingOptimizer: false,
          enableOverdrawOptimizer: false,
        );
      } catch (_) {
        bytes = null;
      }
    }

    final bgColor =
        widget.isDark ? const Color(0xFF14171F) : const Color(0xFFFFFFFF);
    if (bytes != null) {
      final w = out.width > 0 ? out.width : 600.0;
      final h = out.height > 0 ? out.height : 400.0;
      return Container(
        color: bgColor,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
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
      );
    }

    // Fallback for complex DOM-only mermaid.js SVGs with <foreignObject>:
    return Container(
      color: bgColor,
      alignment: Alignment.center,
      child: WebViewEngineCanvas(
        engine: engine,
        source: widget.source,
        isDark: widget.isDark,
        onRendered: (_) {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _buildControlBar(context),
        Expanded(
          child: Stack(
            children: <Widget>[
              // Offstage RepaintBoundaries keep identical-size surfaces ready for Pixel-Diff Heatmap capture
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.001,
                    child: Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: RepaintBoundary(
                            key: _repaintKeyA,
                            child: _buildVectorSurface(_engineA),
                          ),
                        ),
                        Positioned.fill(
                          child: RepaintBoundary(
                            key: _repaintKeyB,
                            child: _buildVectorSurface(_engineB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(child: _buildActiveDiffCanvas()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          _buildEngineDropdown('Engine A:', _engineA, (val) {
            if (val != null) {
              setState(() {
                _engineA = val;
                _heatmapImage = null;
              });
              if (_subMode == VisualDiffSubMode.pixelHeatmap) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _computeHeatmap(),
                );
              }
            }
          }),
          const Icon(Icons.compare_arrows, size: 16),
          _buildEngineDropdown('Engine B:', _engineB, (val) {
            if (val != null) {
              setState(() {
                _engineB = val;
                _heatmapImage = null;
              });
              if (_subMode == VisualDiffSubMode.pixelHeatmap) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _computeHeatmap(),
                );
              }
            }
          }),
          const SizedBox(width: 8),
          SegmentedButton<VisualDiffSubMode>(
            segments:
                VisualDiffSubMode.values
                    .map(
                      (m) => ButtonSegment<VisualDiffSubMode>(
                        value: m,
                        icon: Icon(m.icon, size: 15),
                        label: Text(
                          m.label,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    )
                    .toList(),
            selected: <VisualDiffSubMode>{_subMode},
            onSelectionChanged: (sel) {
              final next = sel.first;
              if (next != VisualDiffSubMode.blinkToggle) {
                _toggleAutoBlink(false);
              }
              setState(() {
                _subMode = next;
              });
              if (next == VisualDiffSubMode.pixelHeatmap) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _computeHeatmap(),
                );
              }
            },
          ),
          if (_subMode == VisualDiffSubMode.colorOverlay) ...<Widget>[
            const Text('Blend:', style: TextStyle(fontSize: 12)),
            SizedBox(
              width: 110,
              child: Slider(
                value: _overlayOpacity,
                min: 0.15,
                max: 0.9,
                onChanged: (v) => setState(() => _overlayOpacity = v),
              ),
            ),
          ],
          if (_subMode == VisualDiffSubMode.pixelHeatmap) ...<Widget>[
            const Text('Tolerance:', style: TextStyle(fontSize: 12)),
            SizedBox(
              width: 100,
              child: Slider(
                value: _pixelTolerance.toDouble(),
                min: 0,
                max: 32,
                divisions: 16,
                label: '±$_pixelTolerance',
                onChanged: (v) {
                  setState(() => _pixelTolerance = v.round());
                },
                onChangeEnd: (_) => _computeHeatmap(),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _computingHeatmap ? null : _computeHeatmap,
              icon: const Icon(Icons.refresh, size: 15),
              label: const Text('Recompute', style: TextStyle(fontSize: 12)),
            ),
            if (_matchPercentage != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color:
                      _matchPercentage! >= 98.0
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_matchPercentage!.toStringAsFixed(2)}% Pixel Match '
                  '(${_diffPixelCount ?? 0} / ${_totalPixelCount ?? 0} diff px)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
          if (_subMode == VisualDiffSubMode.blinkToggle) ...<Widget>[
            FilledButton.tonalIcon(
              onPressed: () => setState(() => _blinkShowB = !_blinkShowB),
              icon: const Icon(Icons.swap_horiz, size: 15),
              label: Text(
                'Showing: ${(_blinkShowB ? _engineB : _engineA).label}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            FilterChip(
              label: const Text(
                'Auto-Blink (550ms)',
                style: TextStyle(fontSize: 12),
              ),
              selected: _autoBlink,
              onSelected: _toggleAutoBlink,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEngineDropdown(
    String prefix,
    ComparisonEngine current,
    ValueChanged<ComparisonEngine?> onChanged,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          prefix,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 6),
        DropdownButton<ComparisonEngine>(
          value: current,
          isDense: true,
          items:
              ComparisonEngine.values
                  .map(
                    (e) => DropdownMenuItem<ComparisonEngine>(
                      value: e,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: e.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(e.label, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildActiveDiffCanvas() {
    switch (_subMode) {
      case VisualDiffSubMode.splitCurtain:
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final splitX = (width * _curtainFraction).clamp(0.0, width);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _curtainFraction =
                      ((_curtainFraction * width + details.delta.dx) / width)
                          .clamp(0.02, 0.98);
                });
              },
              child: Stack(
                children: <Widget>[
                  Positioned.fill(child: _buildVectorSurface(_engineB)),
                  Positioned.fill(
                    child: ClipRect(
                      clipper: _LeftCurtainClipper(splitX),
                      child: _buildVectorSurface(_engineA),
                    ),
                  ),
                  Positioned(
                    left: splitX - 1.5,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 3,
                      color: Colors.cyanAccent,
                      child: Center(
                        child: Container(
                          width: 28,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.cyanAccent,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const <BoxShadow>[
                              BoxShadow(color: Colors.black38, blurRadius: 6),
                            ],
                          ),
                          child: const Icon(
                            Icons.drag_indicator,
                            size: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    top: 12,
                    child: _buildCornerBadge(
                      'A: ${_engineA.label}',
                      _engineA.accent,
                    ),
                  ),
                  Positioned(
                    right: 16,
                    top: 12,
                    child: _buildCornerBadge(
                      'B: ${_engineB.label}',
                      _engineB.accent,
                    ),
                  ),
                ],
              ),
            );
          },
        );

      case VisualDiffSubMode.colorOverlay:
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: ColorFiltered(
                colorFilter: const ColorFilter.matrix(<double>[
                  0.0, 0.0, 0.0, 0, 0, // Red suppressed -> Cyan channel
                  0.0, 1.0, 0.0, 0, 0,
                  0.0, 0.0, 1.0, 0, 0,
                  0.0, 0.0, 0.0, 1, 0,
                ]),
                child: _buildVectorSurface(_engineA),
              ),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: _overlayOpacity,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.matrix(<double>[
                    1.0, 0.0, 0.0, 0, 0, // Green suppressed -> Magenta channel
                    0.0, 0.0, 0.0, 0, 0,
                    0.0, 0.0, 1.0, 0, 0,
                    0.0, 0.0, 0.0, 1, 0,
                  ]),
                  child: _buildVectorSurface(_engineB),
                ),
              ),
            ),
            Positioned(
              left: 16,
              top: 12,
              child: _buildCornerBadge(
                'Cyan = ${_engineA.label}  |  Magenta = ${_engineB.label}',
                Colors.purpleAccent,
              ),
            ),
          ],
        );

      case VisualDiffSubMode.pixelHeatmap:
        if (_computingHeatmap) {
          return const Center(child: CircularProgressIndicator());
        }
        final img = _heatmapImage;
        if (img == null) {
          return Center(
            child: FilledButton.icon(
              onPressed: _computeHeatmap,
              icon: const Icon(Icons.grid_on),
              label: const Text('Compute Pixel-Diff Heatmap'),
            ),
          );
        }
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.25,
                maxScale: 8.0,
                child: Center(child: RawImage(image: img, fit: BoxFit.contain)),
              ),
            ),
            Positioned(
              left: 16,
              top: 12,
              child: _buildCornerBadge(
                'Hot Pink = Differing Pixels (±$_pixelTolerance/255)  |  Gray = Matching Pixels',
                Colors.pinkAccent,
              ),
            ),
          ],
        );

      case VisualDiffSubMode.blinkToggle:
        final active = _blinkShowB ? _engineB : _engineA;
        return GestureDetector(
          onTap: () => setState(() => _blinkShowB = !_blinkShowB),
          child: Stack(
            children: <Widget>[
              Positioned.fill(child: _buildVectorSurface(active)),
              Positioned(
                left: 16,
                top: 12,
                child: _buildCornerBadge(
                  'Active Frame: ${active.label} (Click canvas to flip)',
                  active.accent,
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildCornerBadge(String text, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.8)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LeftCurtainClipper extends CustomClipper<Rect> {
  final double splitX;
  const _LeftCurtainClipper(this.splitX);

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, splitX, size.height);

  @override
  bool shouldReclip(covariant _LeftCurtainClipper oldClipper) =>
      oldClipper.splitX != splitX;
}

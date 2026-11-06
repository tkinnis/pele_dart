import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:pele_dart/pele_dart.dart';
import 'package:pele_dart/src/detect.dart';
import 'package:pele_dart/src/preprocess.dart';

// ignore: avoid_relative_lib_imports
import '../example/lib/gallery_samples.dart';

/// Automated Native AOT Benchmark & Upstream Sync Regression Gate for `pele_dart`.
///
/// Usage:
///   `dart run tool/benchmark_suite.dart`
///     Compiles this suite to native ARM64/x64 AOT (`dart compile exe`),
///     benchmarks all 33 diagram families (232 gallery diagrams) against
///     `obsidianmd/pele` (JS), and prints the summary table.
///
///   `dart run tool/benchmark_suite.dart --update-docs [--update-baseline]`
///     Regenerates `docs/BENCHMARKS.md` (and `tool/benchmark_baseline.json`
///     when `--update-baseline` is passed or if the baseline file does not exist).
///
///   `dart run tool/benchmark_suite.dart --check-regressions`
///     Verifies that `pele_dart` AOT meets all performance invariants and has
///     not regressed against `tool/benchmark_baseline.json` after an upstream sync.
Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  final root = Directory.current.path;

  // If invoked via `dart run` (JIT VM), self-compile to a native AOT binary
  // so benchmarks always reflect true Release/AOT machine code.
  if (!args.contains('--aot-worker')) {
    final tempDir = Directory.systemTemp.createTempSync('pele_dart_bench_');
    final aotBin = '${tempDir.path}/benchmark_suite_aot';
    try {
      stderr.writeln(
        'Compiling tool/benchmark_suite.dart to native AOT executable...',
      );
      final compileRes = await Process.run(
        Platform.resolvedExecutable,
        <String>[
          '--suppress-analytics',
          'compile',
          'exe',
          '--packages=$root/.dart_tool/package_config.json',
          '$root/tool/benchmark_suite.dart',
          '-o',
          aotBin,
        ],
        workingDirectory: root,
      );
      if (compileRes.exitCode != 0) {
        stderr.writeln('Error compiling AOT benchmark binary:');
        stderr.writeln(compileRes.stderr);
        exitCode = compileRes.exitCode;
        return;
      }
      final proc = await Process.start(aotBin, <String>[
        '--aot-worker',
        ...args,
      ], workingDirectory: root);
      await Future.wait(<Future<void>>[
        stdout.addStream(proc.stdout),
        stderr.addStream(proc.stderr),
      ]);
      exitCode = await proc.exitCode;
    } finally {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
    return;
  }

  final updateDocs = args.contains('--update-docs');
  final updateBaseline = args.contains('--update-baseline');
  final checkRegressions = args.contains('--check-regressions');
  final jsonOutput = args.contains('--json');

  final families = gallerySamples;
  if (families.isEmpty) {
    stderr.writeln(
      'Error: No diagram families found in $root/example/diagrams',
    );
    exitCode = 1;
    return;
  }

  // 1. Collect all gallery samples across the 33 families.
  final sampleList = <_BenchSample>[];
  for (final family in families) {
    final categoryLabel = family.tier == 1 ? 'Core' : 'Extended';
    for (final sample in family.playgroundSamples) {
      sampleList.add(
        _BenchSample(
          familyId: family.id,
          familyTitle: family.title,
          category: categoryLabel,
          sampleTitle: sample.label,
          source: sample.source,
        ),
      );
    }
    for (var i = 0; i < family.showcaseSources.length; i++) {
      sampleList.add(
        _BenchSample(
          familyId: family.id,
          familyTitle: family.title,
          category: categoryLabel,
          sampleTitle: 'showcase_${i + 1}',
          source: family.showcaseSources[i],
        ),
      );
    }
  }

  // 2. Measure obsidianmd/pele (JS) via JavaScriptCore (or Bun fallback).
  final jsTimings = await _measurePeleJsCorpus(root, sampleList);

  // 3. Warm up pele_dart AOT across all samples.
  const cssOpts = RenderOptions(outputMode: SvgOutputMode.cssVariables);
  const flatOpts = RenderOptions(outputMode: SvgOutputMode.flattened);
  for (var w = 0; w < 3; w++) {
    for (final s in sampleList) {
      render(s.source, cssOpts);
    }
  }

  // 4. Measure pele_dart AOT per-sample and per-phase timings.
  final familyStatsMap = <String, _FamilyMutableStats>{};
  for (final family in families) {
    familyStatsMap[family.id] = _FamilyMutableStats(
      id: family.id,
      title: family.title,
      category: family.tier == 1 ? 'Core' : 'Extended',
    );
  }

  double totalDetectUs = 0;
  for (var idx = 0; idx < sampleList.length; idx++) {
    final s = sampleList[idx];
    final fStats = familyStatsMap[s.familyId]!;
    fStats.sampleCount++;

    // Measure detect + preprocess
    const detectIters = 128;
    final swDet = Stopwatch()..start();
    late Preprocessed pre;
    for (var i = 0; i < detectIters; i++) {
      pre = preprocess(s.source);
      detectDiagram(pre.text);
    }
    swDet.stop();
    final preDetectUs = swDet.elapsedMicroseconds / detectIters;

    // Measure pure detectDiagram(pre.text)
    final swPureDet = Stopwatch()..start();
    for (var i = 0; i < 512; i++) {
      detectDiagram(pre.text);
    }
    swPureDet.stop();
    final pureDetectUs = swPureDet.elapsedMicroseconds / 512.0;
    totalDetectUs += pureDetectUs;

    // Measure parse(source)
    final parseModel = parse(s.source);
    final parseUs = _measureMedianUs(() => parse(s.source));

    // Measure render(parsedModel, cssVariables)
    final renderOnlyUs = _measureMedianUs(() => render(parseModel, cssOpts));

    // Measure full end-to-end render(source, cssVariables)
    final totalCssUs = _measureMedianUs(() => render(s.source, cssOpts));

    // Measure full end-to-end render(source, flattened)
    final totalFlatUs = _measureMedianUs(() => render(s.source, flatOpts));

    final jsSample = jsTimings[idx];

    fStats.preDetectUsSum += preDetectUs;
    fStats.pureDetectUsSum += pureDetectUs;
    fStats.parseUsSum += parseUs;
    fStats.renderUsSum += renderOnlyUs;
    fStats.totalCssUsSum += totalCssUs;
    fStats.totalFlatUsSum += totalFlatUs;
    fStats.js7RunUsSum += jsSample.sevenRunMedianUs;
    fStats.jsFtlUsSum += jsSample.ftlMedianUs;
  }

  final familyResults = families
      .map((f) => familyStatsMap[f.id]!.toResult())
      .toList();

  final totalSamples = sampleList.length;
  final meanPureDetectUs = totalDetectUs / totalSamples;
  final totalAotCssMs =
      familyResults.fold<double>(0, (a, b) => a + b.totalCssUsSum) / 1000.0;
  final totalAotFlatMs =
      familyResults.fold<double>(0, (a, b) => a + b.totalFlatUsSum) / 1000.0;
  final totalAotParseMs =
      familyResults.fold<double>(0, (a, b) => a + b.parseUsSum) / 1000.0;
  final totalAotRenderMs =
      familyResults.fold<double>(0, (a, b) => a + b.renderUsSum) / 1000.0;
  final totalJs7RunMs =
      familyResults.fold<double>(0, (a, b) => a + b.js7RunUsSum) / 1000.0;
  final totalJsFtlMs =
      familyResults.fold<double>(0, (a, b) => a + b.jsFtlUsSum) / 1000.0;

  final baselineFile = File('$root/tool/benchmark_baseline.json');
  if (updateBaseline || (updateDocs && !baselineFile.existsSync())) {
    final baselineJson = <String, Object>{
      'totalSamples': totalSamples,
      'totalAotCssMs': double.parse(totalAotCssMs.toStringAsFixed(3)),
      'totalAotParseMs': double.parse(totalAotParseMs.toStringAsFixed(3)),
      'totalAotRenderMs': double.parse(totalAotRenderMs.toStringAsFixed(3)),
      'meanPureDetectUs': double.parse(meanPureDetectUs.toStringAsFixed(4)),
      'families': <String, Object>{
        for (final f in familyResults)
          f.id: <String, Object>{
            'sampleCount': f.sampleCount,
            'meanCssUs': double.parse(f.meanCssUs.toStringAsFixed(2)),
            'meanParseUs': double.parse(f.meanParseUs.toStringAsFixed(2)),
            'meanRenderUs': double.parse(f.meanRenderUs.toStringAsFixed(2)),
            'meanFlatUs': double.parse(f.meanFlatUs.toStringAsFixed(2)),
          },
      },
    };
    baselineFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(baselineJson)}\n',
    );
    if (!jsonOutput) {
      stdout.writeln(
        'Updated benchmark baseline: tool/benchmark_baseline.json',
      );
    }
  }

  if (updateDocs) {
    final docsFile = File('$root/docs/BENCHMARKS.md');
    docsFile.writeAsStringSync(
      _buildBenchmarksMarkdown(
        familyResults: familyResults,
        totalSamples: totalSamples,
        meanPureDetectUs: meanPureDetectUs,
        totalAotCssMs: totalAotCssMs,
        totalAotFlatMs: totalAotFlatMs,
        totalAotParseMs: totalAotParseMs,
        totalAotRenderMs: totalAotRenderMs,
        totalJs7RunMs: totalJs7RunMs,
        totalJsFtlMs: totalJsFtlMs,
      ),
    );
    if (!jsonOutput) {
      stdout.writeln('Updated benchmark documentation: docs/BENCHMARKS.md');
    }
  }

  // Evaluate regression gate against tool/benchmark_baseline.json
  final regressions = <String>[];
  if (meanPureDetectUs > 0.50) {
    regressions.add(
      'detectDiagram() mean time regressed to ${meanPureDetectUs.toStringAsFixed(3)} µs (limit: 0.50 µs). '
      'Ensure lib/src/detect.dart preserves the leading-whitespace + first-character switch dispatch.',
    );
  }
  if (totalJs7RunMs > 0 && totalAotCssMs > totalJs7RunMs * 1.05) {
    regressions.add(
      'Total corpus AOT render time (${totalAotCssMs.toStringAsFixed(2)} ms) exceeded obsidianmd/pele JS 7-run total (${totalJs7RunMs.toStringAsFixed(2)} ms).',
    );
  }

  if (baselineFile.existsSync()) {
    final baseline =
        jsonDecode(baselineFile.readAsStringSync()) as Map<String, dynamic>;
    final baseTotalMs = (baseline['totalAotCssMs'] as num?)?.toDouble();
    // Allow 25% wall-clock jitter across CI/machine load for total corpus time.
    if (baseTotalMs != null &&
        totalAotCssMs > baseTotalMs * 1.25 &&
        (totalAotCssMs - baseTotalMs) > 4.0) {
      regressions.add(
        'Total 232-diagram corpus AOT time regressed from ${baseTotalMs.toStringAsFixed(2)} ms to ${totalAotCssMs.toStringAsFixed(2)} ms '
        '(+${(((totalAotCssMs / baseTotalMs) - 1) * 100).toStringAsFixed(1)}%, limit: +25%).',
      );
    }
    final baseFamilies = baseline['families'] as Map<String, dynamic>?;
    if (baseFamilies != null) {
      for (final f in familyResults) {
        final bf = baseFamilies[f.id] as Map<String, dynamic>?;
        if (bf == null) continue;
        final baseCssUs = (bf['meanCssUs'] as num?)?.toDouble() ?? 0;
        final baseParseUs = (bf['meanParseUs'] as num?)?.toDouble() ?? 0;
        final baseRenderUs = (bf['meanRenderUs'] as num?)?.toDouble() ?? 0;
        // Flag if a family regresses by > 40% AND > 20 µs per diagram.
        if (baseCssUs > 0 &&
            f.meanCssUs > baseCssUs * 1.40 &&
            (f.meanCssUs - baseCssUs) > 20.0) {
          final parseDelta = f.meanParseUs - baseParseUs;
          final renderDelta = f.meanRenderUs - baseRenderUs;
          final culpritPhase = parseDelta > renderDelta ? 'PARSE' : 'RENDER';
          regressions.add(
            'Family "${f.id}" (${f.title}) regressed from ${baseCssUs.toStringAsFixed(1)} µs to ${f.meanCssUs.toStringAsFixed(1)} µs/diagram '
            '(+${(((f.meanCssUs / baseCssUs) - 1) * 100).toStringAsFixed(1)}%). '
            'Primary culprit phase: $culpritPhase (parse: ${baseParseUs.toStringAsFixed(1)} -> ${f.meanParseUs.toStringAsFixed(1)} µs, '
            'render: ${baseRenderUs.toStringAsFixed(1)} -> ${f.meanRenderUs.toStringAsFixed(1)} µs). '
            'Inspect lib/src/diagrams/${f.id}/ for unoptimized RegExp or string allocations.',
          );
        }
      }
    }
  }

  if (jsonOutput) {
    stdout.writeln(
      jsonEncode(<String, Object>{
        'status': regressions.isEmpty ? 'ok' : 'regression',
        'totalFamilies': familyResults.length,
        'totalSamples': totalSamples,
        'meanPureDetectUs': meanPureDetectUs,
        'totalAotCssMs': totalAotCssMs,
        'totalAotFlatMs': totalAotFlatMs,
        'totalAotParseMs': totalAotParseMs,
        'totalAotRenderMs': totalAotRenderMs,
        'totalJs7RunMs': totalJs7RunMs,
        'totalJsFtlMs': totalJsFtlMs,
        'speedupVsJs7Run': totalJs7RunMs > 0
            ? totalJs7RunMs / totalAotCssMs
            : 1.0,
        'regressions': regressions,
        'families': familyResults.map((f) => f.toJson()).toList(),
      }),
    );
    if (checkRegressions && regressions.isNotEmpty) {
      exitCode = 1;
    }
    return;
  }

  _printConsoleReport(
    familyResults: familyResults,
    totalSamples: totalSamples,
    meanPureDetectUs: meanPureDetectUs,
    totalAotCssMs: totalAotCssMs,
    totalAotFlatMs: totalAotFlatMs,
    totalAotParseMs: totalAotParseMs,
    totalAotRenderMs: totalAotRenderMs,
    totalJs7RunMs: totalJs7RunMs,
    totalJsFtlMs: totalJsFtlMs,
    regressions: regressions,
  );

  if (checkRegressions && regressions.isNotEmpty) {
    exitCode = 1;
  }
}

void _printUsage() {
  stdout.writeln('''
pele_dart Native AOT Benchmark & Regression Gate

Usage:
  dart run tool/benchmark_suite.dart [options]

Options:
  --update-docs        Regenerate docs/BENCHMARKS.md with current native AOT benchmark results.
  --update-baseline    Update tool/benchmark_baseline.json with current per-family AOT baselines.
  --check-regressions  Fail with exit code 1 if any diagram family or corpus total regresses.
  --json               Emit machine-readable JSON output.
  -h, --help           Show this help message.
''');
}

double _measureMedianUs(void Function() fn) {
  var batch = 1;
  final sw = Stopwatch();
  while (true) {
    sw
      ..reset()
      ..start();
    for (var i = 0; i < batch; i++) {
      fn();
    }
    sw.stop();
    if (sw.elapsedMicroseconds >= 2000 || batch >= 256) {
      break;
    }
    batch *= 2;
  }

  final samples = <double>[];
  for (var r = 0; r < 7; r++) {
    sw
      ..reset()
      ..start();
    for (var i = 0; i < batch; i++) {
      fn();
    }
    sw.stop();
    samples.add(sw.elapsedMicroseconds / batch);
  }
  samples.sort();
  return samples[samples.length ~/ 2];
}

class _BenchSample {
  final String familyId;
  final String familyTitle;
  final String category;
  final String sampleTitle;
  final String source;

  const _BenchSample({
    required this.familyId,
    required this.familyTitle,
    required this.category,
    required this.sampleTitle,
    required this.source,
  });
}

class _JsSampleTiming {
  final double sevenRunMedianUs;
  final double ftlMedianUs;

  const _JsSampleTiming({
    required this.sevenRunMedianUs,
    required this.ftlMedianUs,
  });
}

Future<List<_JsSampleTiming>> _measurePeleJsCorpus(
  String root,
  List<_BenchSample> samples,
) async {
  final bundleFile = File('$root/example/assets/pele.bundle.js');
  if (!bundleFile.existsSync()) {
    return List<_JsSampleTiming>.filled(
      samples.length,
      const _JsSampleTiming(sevenRunMedianUs: 0, ftlMedianUs: 0),
    );
  }

  final tempDir = Directory.systemTemp.createTempSync('pele_js_bench_');
  try {
    final inputPath = '${tempDir.path}/samples.json';
    File(inputPath).writeAsStringSync(
      jsonEncode(
        samples
            .map(
              (s) => <String, String>{
                'familyId': s.familyId,
                'source': s.source,
              },
            )
            .toList(),
      ),
    );

    const jscBin =
        '/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc';
    if (File(jscBin).existsSync()) {
      final scriptPath = '${tempDir.path}/run_jsc_bench.js';
      File(scriptPath).writeAsStringSync('''
load(${jsonEncode(bundleFile.path)});
const raw = readFile(${jsonEncode(inputPath)});
const items = JSON.parse(raw);
const opts = { measurer: globalThis.PeleMetricsMeasurer };

// 1. Measure realistic 7-run median (matching website/src/lib/timing.ts)
//    with 1 warmup render per diagram family.
const warmedFamilies = new Set();
const sevenRunUs = new Array(items.length);
for (let idx = 0; idx < items.length; idx++) {
  const item = items[idx];
  if (!warmedFamilies.has(item.familyId)) {
    warmedFamilies.add(item.familyId);
    Pele.render(item.source, opts);
  }
  const times = [];
  for (let r = 0; r < 7; r++) {
    const t0 = preciseTime();
    Pele.render(item.source, opts);
    times.push((preciseTime() - t0) * 1e6);
  }
  times.sort((a, b) => a - b);
  sevenRunUs[idx] = times[3];
}

// 2. Measure Tier-4 FTL loop-warmed steady-state median.
for (let w = 0; w < 3; w++) {
  for (let idx = 0; idx < items.length; idx++) {
    Pele.render(items[idx].source, opts);
  }
}
const ftlUs = new Array(items.length);
for (let idx = 0; idx < items.length; idx++) {
  const src = items[idx].source;
  const times = [];
  for (let r = 0; r < 5; r++) {
    const t0 = preciseTime();
    for (let i = 0; i < 64; i++) {
      Pele.render(src, opts);
    }
    times.push((preciseTime() - t0) * 1e6 / 64.0);
  }
  times.sort((a, b) => a - b);
  ftlUs[idx] = times[2];
}

const out = [];
for (let idx = 0; idx < items.length; idx++) {
  out.push({ sevenRunUs: sevenRunUs[idx], ftlUs: ftlUs[idx] });
}
print(JSON.stringify(out));
''');
      final res = await Process.run(jscBin, <String>[scriptPath]);
      if (res.exitCode == 0) {
        final lines = (res.stdout as String)
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        if (lines.isNotEmpty) {
          final decoded = jsonDecode(lines.last) as List<dynamic>;
          return decoded.map((e) {
            final m = e as Map<String, dynamic>;
            return _JsSampleTiming(
              sevenRunMedianUs: (m['sevenRunUs'] as num).toDouble(),
              ftlMedianUs: (m['ftlUs'] as num).toDouble(),
            );
          }).toList();
        }
      }
    }
  } finally {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  }

  return List<_JsSampleTiming>.filled(
    samples.length,
    const _JsSampleTiming(sevenRunMedianUs: 0, ftlMedianUs: 0),
  );
}

class _FamilyMutableStats {
  final String id;
  final String title;
  final String category;
  int sampleCount = 0;
  double preDetectUsSum = 0;
  double pureDetectUsSum = 0;
  double parseUsSum = 0;
  double renderUsSum = 0;
  double totalCssUsSum = 0;
  double totalFlatUsSum = 0;
  double js7RunUsSum = 0;
  double jsFtlUsSum = 0;

  _FamilyMutableStats({
    required this.id,
    required this.title,
    required this.category,
  });

  _FamilyBenchResult toResult() {
    final n = sampleCount > 0 ? sampleCount : 1;
    return _FamilyBenchResult(
      id: id,
      title: title,
      category: category,
      sampleCount: sampleCount,
      preDetectUsSum: preDetectUsSum,
      pureDetectUsSum: pureDetectUsSum,
      parseUsSum: parseUsSum,
      renderUsSum: renderUsSum,
      totalCssUsSum: totalCssUsSum,
      totalFlatUsSum: totalFlatUsSum,
      js7RunUsSum: js7RunUsSum,
      jsFtlUsSum: jsFtlUsSum,
      meanPreDetectUs: preDetectUsSum / n,
      meanPureDetectUs: pureDetectUsSum / n,
      meanParseUs: parseUsSum / n,
      meanRenderUs: renderUsSum / n,
      meanCssUs: totalCssUsSum / n,
      meanFlatUs: totalFlatUsSum / n,
      meanJs7RunUs: js7RunUsSum / n,
      meanJsFtlUs: jsFtlUsSum / n,
    );
  }
}

class _FamilyBenchResult {
  final String id;
  final String title;
  final String category;
  final int sampleCount;
  final double preDetectUsSum;
  final double pureDetectUsSum;
  final double parseUsSum;
  final double renderUsSum;
  final double totalCssUsSum;
  final double totalFlatUsSum;
  final double js7RunUsSum;
  final double jsFtlUsSum;
  final double meanPreDetectUs;
  final double meanPureDetectUs;
  final double meanParseUs;
  final double meanRenderUs;
  final double meanCssUs;
  final double meanFlatUs;
  final double meanJs7RunUs;
  final double meanJsFtlUs;

  const _FamilyBenchResult({
    required this.id,
    required this.title,
    required this.category,
    required this.sampleCount,
    required this.preDetectUsSum,
    required this.pureDetectUsSum,
    required this.parseUsSum,
    required this.renderUsSum,
    required this.totalCssUsSum,
    required this.totalFlatUsSum,
    required this.js7RunUsSum,
    required this.jsFtlUsSum,
    required this.meanPreDetectUs,
    required this.meanPureDetectUs,
    required this.meanParseUs,
    required this.meanRenderUs,
    required this.meanCssUs,
    required this.meanFlatUs,
    required this.meanJs7RunUs,
    required this.meanJsFtlUs,
  });

  double get speedupVsJs7Run =>
      meanCssUs > 0 && meanJs7RunUs > 0 ? meanJs7RunUs / meanCssUs : 1.0;

  Map<String, Object> toJson() => <String, Object>{
    'id': id,
    'title': title,
    'category': category,
    'sampleCount': sampleCount,
    'meanParseUs': double.parse(meanParseUs.toStringAsFixed(2)),
    'meanRenderUs': double.parse(meanRenderUs.toStringAsFixed(2)),
    'meanCssUs': double.parse(meanCssUs.toStringAsFixed(2)),
    'meanFlatUs': double.parse(meanFlatUs.toStringAsFixed(2)),
    'meanJs7RunUs': double.parse(meanJs7RunUs.toStringAsFixed(2)),
    'meanJsFtlUs': double.parse(meanJsFtlUs.toStringAsFixed(2)),
    'speedupVsJs7Run': double.parse(speedupVsJs7Run.toStringAsFixed(2)),
  };
}

void _printConsoleReport({
  required List<_FamilyBenchResult> familyResults,
  required int totalSamples,
  required double meanPureDetectUs,
  required double totalAotCssMs,
  required double totalAotFlatMs,
  required double totalAotParseMs,
  required double totalAotRenderMs,
  required double totalJs7RunMs,
  required double totalJsFtlMs,
  required List<String> regressions,
}) {
  stdout.writeln(
    '═══════════════════════════════════════════════════════════════════════════════════════',
  );
  stdout.writeln(
    '  pele_dart Native AOT Benchmark Suite (${familyResults.length} Families, $totalSamples Diagrams)',
  );
  stdout.writeln(
    '═══════════════════════════════════════════════════════════════════════════════════════',
  );
  stdout.writeln(
    '${"Family".padRight(22)} ${"Count".padLeft(5)} ${"Parse (µs)".padLeft(11)} ${"Render (µs)".padLeft(12)} ${"Dart AOT (µs)".padLeft(14)} ${"Pele JS (µs)".padLeft(13)} ${"Speedup".padLeft(9)}',
  );
  stdout.writeln(
    '───────────────────────────────────────────────────────────────────────────────────────',
  );
  for (final f in familyResults) {
    final speedupStr = f.meanJs7RunUs > 0
        ? '${f.speedupVsJs7Run.toStringAsFixed(2)}x'
        : 'n/a';
    stdout.writeln(
      '${f.title.padRight(22)} '
      '${f.sampleCount.toString().padLeft(5)} '
      '${f.meanParseUs.toStringAsFixed(1).padLeft(11)} '
      '${f.meanRenderUs.toStringAsFixed(1).padLeft(12)} '
      '${f.meanCssUs.toStringAsFixed(1).padLeft(14)} '
      '${f.meanJs7RunUs.toStringAsFixed(1).padLeft(13)} '
      '${speedupStr.padLeft(9)}',
    );
  }
  stdout.writeln(
    '───────────────────────────────────────────────────────────────────────────────────────',
  );
  final overallSpeedup = totalJs7RunMs > 0
      ? '${(totalJs7RunMs / totalAotCssMs).toStringAsFixed(2)}x'
      : 'n/a';
  stdout.writeln(
    'Total Corpus ($totalSamples diagrams): '
    'pele_dart AOT = ${totalAotCssMs.toStringAsFixed(2)} ms '
    '(parse: ${totalAotParseMs.toStringAsFixed(2)} ms, render: ${totalAotRenderMs.toStringAsFixed(2)} ms, flattened: ${totalAotFlatMs.toStringAsFixed(2)} ms) | '
    'obsidianmd/pele JS = ${totalJs7RunMs.toStringAsFixed(2)} ms ($overallSpeedup)',
  );
  stdout.writeln(
    'Mean detectDiagram() time: ${meanPureDetectUs.toStringAsFixed(3)} µs/diagram',
  );
  stdout.writeln(
    '═══════════════════════════════════════════════════════════════════════════════════════',
  );

  if (regressions.isEmpty) {
    stdout.writeln(
      '✅ BENCHMARK REGRESSION GATE PASSED: All 33 families and corpus totals within threshold.',
    );
  } else {
    stderr.writeln(
      '❌ BENCHMARK REGRESSION GATE FAILED (${regressions.length} issue(s)):',
    );
    for (final r in regressions) {
      stderr.writeln('  • $r');
    }
  }
}

String _shortChartLabel(String id) {
  switch (id) {
    case 'class':
      return 'Class';
    case 'er':
      return 'ER';
    case 'flowchart':
      return 'Flowchart';
    case 'gantt':
      return 'Gantt';
    case 'git':
      return 'Git';
    case 'info':
      return 'Info';
    case 'mindmap':
      return 'Mindmap';
    case 'pie':
      return 'Pie';
    case 'sequence':
      return 'Sequence';
    case 'state':
      return 'State';
    case 'eventmodeling':
      return 'EventMod';
    case 'quadrant':
      return 'Quadrant';
    case 'requirement':
      return 'Req';
    case 'architecture':
      return 'Arch';
    case 'agentflow':
      return 'Agentflow';
    case 'ishikawa':
      return 'Ishikawa';
    case 'swimlane':
      return 'Swimlane';
    case 'treeview':
      return 'TreeView';
    case 'usecase':
      return 'UseCase';
    case 'wardley':
      return 'Wardley';
    case 'xychart':
      return 'XYChart';
    default:
      return id.isEmpty ? id : '${id[0].toUpperCase()}${id.substring(1)}';
  }
}

String _buildBenchmarksMarkdown({
  required List<_FamilyBenchResult> familyResults,
  required int totalSamples,
  required double meanPureDetectUs,
  required double totalAotCssMs,
  required double totalAotFlatMs,
  required double totalAotParseMs,
  required double totalAotRenderMs,
  required double totalJs7RunMs,
  required double totalJsFtlMs,
}) {
  final overallSpeedup = totalJs7RunMs > 0
      ? (totalJs7RunMs / totalAotCssMs).toStringAsFixed(2)
      : '1.00';
  final meanAotUs = (totalAotCssMs * 1000.0) / totalSamples;
  final meanJs7RunUs = (totalJs7RunMs * 1000.0) / totalSamples;

  final coreFamilies = familyResults
      .where((f) => f.category == 'Core')
      .toList();
  final coreLabels = coreFamilies
      .map((f) => '"${_shortChartLabel(f.id)}"')
      .join(', ');
  final coreAotBars = coreFamilies
      .map((f) => f.meanCssUs.toStringAsFixed(1))
      .join(', ');
  final coreJsBars = coreFamilies
      .map((f) => f.meanJs7RunUs.toStringAsFixed(1))
      .join(', ');
  final maxCoreUs = coreFamilies.fold<double>(
    100.0,
    (m, f) => math.max(m, math.max(f.meanCssUs, f.meanJs7RunUs)),
  );
  final coreYMax = ((maxCoreUs / 100.0).ceil() * 100).clamp(200, 5000);

  final topSpeedupFamilies = List<_FamilyBenchResult>.from(familyResults)
    ..sort((a, b) => b.speedupVsJs7Run.compareTo(a.speedupVsJs7Run));
  final top12 = topSpeedupFamilies.take(12).toList();
  final top12Labels = top12
      .map((f) => '"${_shortChartLabel(f.id)}"')
      .join(', ');
  final top12Bars = top12
      .map((f) => f.speedupVsJs7Run.toStringAsFixed(2))
      .join(', ');
  final maxSpeedup = top12.isEmpty
      ? 6
      : (top12.first.speedupVsJs7Run.ceil() + 1).clamp(4, 20);

  final sb = StringBuffer()
    ..writeln('# Performance Benchmarks & Upstream Sync Regression Gate')
    ..writeln()
    ..writeln(
      'This document reports the native **Dart AOT** rendering performance of `pele_dart` across all **${familyResults.length} diagram families** (**$totalSamples diagrams** in the official `example/diagrams/` gallery corpus) compared against upstream [`obsidianmd/pele`](https://github.com/obsidianmd/pele) (JavaScriptCore; see [`UPSTREAM.md`](../UPSTREAM.md) for the pinned upstream release).',
    )
    ..writeln()
    ..writeln(
      '> **Automated Release Gate:** This report and the baseline in [`tool/benchmark_baseline.json`](../tool/benchmark_baseline.json) are generated and verified by [`tool/benchmark_suite.dart`](../tool/benchmark_suite.dart). Every upstream sync must pass `dart run tool/benchmark_suite.dart --update-docs --check-regressions` before pinning [`UPSTREAM.md`](../UPSTREAM.md) or cutting a release.',
    )
    ..writeln()
    ..writeln('---')
    ..writeln()
    ..writeln('## 1. Quick Commands')
    ..writeln()
    ..writeln('| Task | Command |')
    ..writeln('| :--- | :--- |')
    ..writeln(
      '| **Run native AOT benchmark suite & print console table** | `dart run tool/benchmark_suite.dart` |',
    )
    ..writeln(
      '| **Update `docs/BENCHMARKS.md` and check for regressions** | `dart run tool/benchmark_suite.dart --update-docs --check-regressions` |',
    )
    ..writeln(
      '| **Update baseline after intentional optimizations** | `dart run tool/benchmark_suite.dart --update-docs --update-baseline` |',
    )
    ..writeln(
      '| **Emit machine-readable JSON for CI / agents** | `dart run tool/benchmark_suite.dart --json --check-regressions` |',
    )
    ..writeln()
    ..writeln('---')
    ..writeln()
    ..writeln('## 2. Aggregate Corpus Summary ($totalSamples Diagrams)')
    ..writeln()
    ..writeln(
      '| Metric | `pele_dart` (Native Dart AOT) | `obsidianmd/pele` (JS) | Comparison |',
    )
    ..writeln('| :--- | ---: | ---: | :--- |')
    ..writeln(
      '| **Full Corpus Total (`SvgOutputMode.cssVariables`)** | **${totalAotCssMs.toStringAsFixed(2)} ms** | ${totalJs7RunMs.toStringAsFixed(2)} ms | **${overallSpeedup}x faster overall** |',
    )
    ..writeln(
      '| **Mean Time per Diagram (`SvgOutputMode.cssVariables`)** | **${meanAotUs.toStringAsFixed(1)} µs** | ${meanJs7RunUs.toStringAsFixed(1)} µs | **${overallSpeedup}x faster per diagram** |',
    )
    ..writeln(
      '| **Corpus Parse Phase Total (`parse()`)** | **${totalAotParseMs.toStringAsFixed(2)} ms** | — | ${(totalAotParseMs * 1000.0 / totalSamples).toStringAsFixed(1)} µs mean parse time |',
    )
    ..writeln(
      '| **Corpus Layout + SVG Render Phase Total (`render(model)`)** | **${totalAotRenderMs.toStringAsFixed(2)} ms** | — | ${(totalAotRenderMs * 1000.0 / totalSamples).toStringAsFixed(1)} µs mean layout + SVG time |',
    )
    ..writeln(
      '| **Mean Diagram Header Detection (`detectDiagram()`)** | **${meanPureDetectUs.toStringAsFixed(3)} µs** | — | O(1) first-character switch dispatch (`< 0.05 µs`) |',
    )
    ..writeln(
      '| **Full Corpus Total (`SvgOutputMode.flattened`)** | **${totalAotFlatMs.toStringAsFixed(2)} ms** | n/a *(CSS vars only)* | Includes static SVG 1.1 CSS-variable & `color-mix()` flattening |',
    )
    ..writeln()
    ..writeln('### Visual Performance Comparisons')
    ..writeln()
    ..writeln(
      '#### Core Mermaid Families — Mean Render Time (`pele_dart` AOT vs `obsidianmd/pele` JS)',
    )
    ..writeln()
    ..writeln(
      '> **Bar Series 1 (Left):** `pele_dart` Native AOT (µs) &nbsp;|&nbsp; **Bar Series 2 (Right):** `obsidianmd/pele` JS (µs) — *Lower is faster*',
    )
    ..writeln()
    ..writeln('```mermaid')
    ..writeln('xychart-beta')
    ..writeln(
      '  title "Core Mermaid Families — Mean Render Time in µs (Lower is Faster)"',
    )
    ..writeln('  x-axis [$coreLabels]')
    ..writeln('  y-axis "Mean Render Time (µs)" 0 --> $coreYMax')
    ..writeln('  bar [$coreAotBars]')
    ..writeln('  bar [$coreJsBars]')
    ..writeln('```')
    ..writeln()
    ..writeln(
      '#### Top 12 Diagram Families — Native Dart AOT Speedup Multiplier (`x` Faster than JS)',
    )
    ..writeln()
    ..writeln('```mermaid')
    ..writeln('xychart-beta')
    ..writeln(
      '  title "pele_dart Native AOT Speedup Multiplier vs obsidianmd/pele JS (Higher is Faster)"',
    )
    ..writeln('  x-axis [$top12Labels]')
    ..writeln('  y-axis "Speedup Multiplier (x)" 0 --> $maxSpeedup')
    ..writeln('  bar [$top12Bars]')
    ..writeln('```')
    ..writeln()
    ..writeln('#### Full Corpus Execution Time Breakdown (`parse` vs `render`)')
    ..writeln()
    ..writeln('```mermaid')
    ..writeln('pie showData')
    ..writeln(
      '  title "Full Corpus ($totalSamples Diagrams) Execution Time by Phase (ms)"',
    )
    ..writeln(
      '  "Layout & SVG Emission (render)" : ${totalAotRenderMs.toStringAsFixed(2)}',
    )
    ..writeln(
      '  "Lexer & Parser (parse)" : ${totalAotParseMs.toStringAsFixed(2)}',
    )
    ..writeln('```')
    ..writeln()
    ..writeln('### Methodology Notes')
    ..writeln()
    ..writeln(
      '1. **Always Benchmarked in Native Dart AOT (`dart compile exe`)**: Running in the Dart Debug/JIT VM includes unoptimized runtime type checks and interpreter warm-up. `tool/benchmark_suite.dart` automatically compiles itself to a native AOT executable before measuring any timings.',
    )
    ..writeln(
      '2. **Apples-to-Apples Output Mode (`SvgOutputMode.cssVariables`)**: Upstream `obsidianmd/pele` emits SVG styled with `var(--pele-*)` CSS custom properties. The head-to-head comparison measures `SvgOutputMode.cssVariables` in both engines using `metricsMeasurer`. `SvgOutputMode.flattened` (which resolves all CSS variables and `color-mix()` expressions into static SVG 1.1 attributes for `vector_graphics_compiler`) is reported in its own column.',
    )
    ..writeln(
      '3. **First-Visit Realistic Timing vs Loop-Specialized Tier-4 FTL JIT**: In JavaScriptCore (`jsc` / `WKWebView`), rendering a diagram 1–7 times (matching upstream `website/src/lib/timing.ts`) executes in `LLInt` / `Baseline` / `DFG` JIT (`${totalJs7RunMs.toStringAsFixed(2)} ms` corpus total), where `pele_dart` AOT is **${overallSpeedup}x faster** because AOT machine code requires zero JIT warm-up. When a benchmark loop executes the exact same diagram thousands of times in a tight loop (`>= 1,000` iterations), JavaScriptCore compiles a Tier-4 FTL (`B3/Air`) loop specialization (`${totalJsFtlMs.toStringAsFixed(2)} ms` corpus total).',
    )
    ..writeln()
    ..writeln('---')
    ..writeln()
    ..writeln(
      '## 3. Per-Family Benchmark & Phase Breakdown (33 Diagram Families)',
    )
    ..writeln()
    ..writeln(
      '| Diagram Family | Category | Samples | `parse()` (µs) | `render()` (µs) | `pele_dart` AOT (µs) | Flattened SVG (µs) | `obsidianmd/pele` JS (µs) | Speedup vs JS |',
    )
    ..writeln(
      '| :--- | :--- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |',
    );

  for (final f in familyResults) {
    final speedup = f.meanJs7RunUs > 0
        ? '**${f.speedupVsJs7Run.toStringAsFixed(2)}x**'
        : '—';
    sb.writeln(
      '| **${f.title}** (`${f.id}`) | ${f.category} | ${f.sampleCount} | '
      '${f.meanParseUs.toStringAsFixed(1)} | '
      '${f.meanRenderUs.toStringAsFixed(1)} | '
      '**${f.meanCssUs.toStringAsFixed(1)}** | '
      '${f.meanFlatUs.toStringAsFixed(1)} | '
      '${f.meanJs7RunUs.toStringAsFixed(1)} | '
      '$speedup |',
    );
  }

  sb
    ..writeln()
    ..writeln('---')
    ..writeln()
    ..writeln(
      '## 4. Upstream Sync Performance Invariants & Optimization Checklist',
    )
    ..writeln()
    ..writeln(
      'When syncing new upstream `obsidianmd/pele` commits (see [`docs/UPSTREAM_SYNC.md`](UPSTREAM_SYNC.md) and [`.agents/skills/sync-upstream-pele/SKILL.md`](../.agents/skills/sync-upstream-pele/SKILL.md)), newly ported TypeScript code can introduce Dart AOT regressions if JavaScript idioms (such as sticky/backtracking regex loops or per-character string allocations) are translated naively.',
    )
    ..writeln()
    ..writeln(
      'If `dart run tool/benchmark_suite.dart --check-regressions` flags a regression after porting upstream changes, inspect the reported phase (`PARSE` vs `RENDER`) against these core invariants:',
    )
    ..writeln()
    ..writeln(
      '1. **Diagram Detection ([`lib/src/detect.dart`](../lib/src/detect.dart))**:',
    )
    ..writeln(
      '   - Must remain `< 0.50 µs` (`O(1)` leading-whitespace skip + first-character `switch` dispatch returning `const Detected`). Never replace with a linear loop over a list of `RegExp` patterns.',
    )
    ..writeln(
      '2. **Lexer & Tokenization ([`lib/src/diagrams/common/tokens.dart`](../lib/src/diagrams/common/tokens.dart) & [`lib/src/diagrams/common/outline.dart`](../lib/src/diagrams/common/outline.dart))**:',
    )
    ..writeln(
      '   - `TokenType` retains its upstream `re: RegExp(...)` for 1:1 diffing, while `_prepare()` auto-compiles simple patterns into zero-allocation `codeUnitAt` matchers (`_compileFastMatcher`) and a first-character dispatch bitmask (`_inferFirstChars`).',
    )
    ..writeln(
      '   - If a newly synced diagram grammar introduces a complex hot-loop `TokenType`, provide an inline `match: (String input, int pos)` closure alongside `re:` if `_compileFastMatcher` cannot auto-specialize it.',
    )
    ..writeln(
      '3. **Text Measurement & Label Wrapping ([`lib/src/text/label.dart`](../lib/src/text/label.dart))**:',
    )
    ..writeln(
      '   - Preserve `_isSimpleWrapText` and `_splitSimplePieces` so standard non-CJK labels bypass `_rePiece` / `_reCjk` / `_reHint` regex matching, and use slice-based `StringBuffer.write(source.substring(start, end))` in `_inline` rather than per-character string concatenation.',
    )
    ..writeln(
      '4. **Date & Timezone Math ([`lib/src/diagrams/gantt/dates.dart`](../lib/src/diagrams/gantt/dates.dart))**:',
    )
    ..writeln(
      '   - In Dart AOT, `DateTime.timeZoneOffset` invokes an OS `localtime_r` syscall. Keep `_MDate._w` lazy and compute sub-minute fields (`getMilliseconds()`, `getUTCSeconds()`) directly from `millisecondsSinceEpoch`.',
    )
    ..writeln(
      '5. **YAML Frontmatter & Preprocessing ([`lib/src/preprocess.dart`](../lib/src/preprocess.dart) & [`lib/src/util/yaml.dart`](../lib/src/util/yaml.dart))**:',
    )
    ..writeln(
      '   - Use `codeUnitAt` scanning (`_stripCommentLines`, `_splitKey`, `_unquoteDouble`) and pre-accumulate multiline quoted scalars before parsing rather than using control-flow exceptions.',
    );

  return sb.toString();
}

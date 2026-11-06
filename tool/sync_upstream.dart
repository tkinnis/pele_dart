import 'dart:convert';
import 'dart:io';

/// Upstream release detector, diff analyzer, and asset/gallery synchronizer for `pele_dart`.
///
/// Usage:
///   `dart run tool/sync_upstream.dart [--check] [--json]`
///     Fetches latest tags/commits from https://github.com/obsidianmd/pele,
///     checks for new Pele releases, unreleased main commits, and Mermaid.js
///     target version changes, and prints an actionable update report.
///
///   `dart run tool/sync_upstream.dart --diff [from_ref..to_ref | target_ref]`
///     Generates a categorized TypeScript-to-Dart migration report (including
///     beta-to-stable detector changes, new diagram families, modified files,
///     and corpus updates) in `.upstream/diff_report.md`.
///
///   `dart run tool/sync_upstream.dart --update-to-latest`
///   `dart run tool/sync_upstream.dart --update-to <tag_or_ref>`
///     Checks out the target upstream Pele release in `.upstream/`, generates
///     `.upstream/diff_report.md` from the previous pinned commit, refreshes
///     `studio/assets/pele.bundle.js`, `studio/assets/mermaid.min.js`,
///     `studio/lib/engine_runner.dart`, and standalone gallery SVGs via
///     `tool/generate_doc_images.dart`.
///
///   `dart run tool/sync_upstream.dart --refresh-assets`
///     Rebuilds `studio/assets/pele.bundle.js`, syncs `studio/assets/mermaid.min.js`
///     and `studio/lib/engine_runner.dart` to upstream's target Mermaid version,
///     and regenerates `doc/images/` and `doc/DIAGRAM_GALLERY.md`.
///
///   `dart run tool/sync_upstream.dart --pin <tag> [sha]`
///     Updates `UPSTREAM.md` with the specified release tag, commit SHA, date,
///     and target Mermaid version.
///
///   `dart run tool/sync_upstream.dart --ensure`
///     Ensures `.upstream/` is cloned and checked out at the pinned SHA in `UPSTREAM.md`.
Future<void> main(List<String> args) async {
  final root = Directory.current.path;
  final upstreamMdFile = File('$root/UPSTREAM.md');
  if (!upstreamMdFile.existsSync()) {
    stderr.writeln('Error: UPSTREAM.md not found in $root');
    exitCode = 1;
    return;
  }

  final mdContent = upstreamMdFile.readAsStringSync();
  final pinnedSha =
      _extractField(mdContent, 'Target Commit SHA') ??
      _extractField(mdContent, 'Pinned Upstream Commit');
  final pinnedTag =
      _extractField(mdContent, 'Target Release') ??
      _extractField(mdContent, 'Pinned Upstream Tag') ??
      'unknown';
  final pinnedMermaidVersion =
      _extractField(mdContent, 'Target Mermaid Version') ?? '12.1.0';
  final pinnedMermaidParser =
      _extractField(mdContent, 'Target Mermaid Parser') ??
      '@mermaid-js/parser@2.0.1';

  if (pinnedSha == null) {
    stderr.writeln('Error: Could not parse Target Commit SHA from UPSTREAM.md');
    exitCode = 1;
    return;
  }

  final upstreamDir = Directory('$root/.upstream');
  final jsonOutput = args.contains('--json');
  final positional = args.where((a) => a != '--json').toList();
  final mode = positional.isNotEmpty ? positional.first : '--check';

  if (mode == '--help' || mode == '-h') {
    _printUsage();
    return;
  }

  if (mode == '--ensure') {
    final ok = await _ensureUpstreamClone(upstreamDir, pinnedSha);
    if (!ok) {
      exitCode = 1;
      return;
    }
    stdout.writeln('Checked out $pinnedTag ($pinnedSha) in .upstream/');
    return;
  }

  if (mode == '--pin') {
    if (positional.length < 2) {
      stderr.writeln(
        'Usage: dart run tool/sync_upstream.dart --pin <tag> [sha]',
      );
      exitCode = 1;
      return;
    }
    final newTag = positional[1];
    final targetRef = positional.length >= 3 ? positional[2] : newTag;
    final resolvedSha = await _gitRevParse(upstreamDir, targetRef) ?? targetRef;
    final commitDate =
        await _gitCommitIsoDate(upstreamDir, resolvedSha) ??
        DateTime.now().toUtc().toIso8601String();
    final mermaidInfo = _detectUpstreamMermaidInfo(upstreamDir);
    _updateUpstreamMd(
      upstreamMdFile,
      root: root,
      tag: newTag,
      sha: resolvedSha,
      date: commitDate,
      mermaidVersion: mermaidInfo.mermaidVersion,
      mermaidParser: mermaidInfo.parserSpec,
    );
    stdout.writeln(
      'Updated UPSTREAM.md & pubspec.yaml -> $newTag ($resolvedSha) | Mermaid ${mermaidInfo.mermaidVersion}',
    );
    return;
  }

  if (mode == '--refresh-assets') {
    if (!upstreamDir.existsSync()) {
      final ok = await _ensureUpstreamClone(upstreamDir, pinnedSha);
      if (!ok) {
        exitCode = 1;
        return;
      }
    }
    if (positional.length >= 2) {
      final ref = positional[1];
      final co = await Process.run('git', <String>[
        'checkout',
        ref,
      ], workingDirectory: upstreamDir.path);
      if (co.exitCode != 0) {
        stderr.writeln('Error checking out $ref: ${co.stderr}');
        exitCode = 1;
        return;
      }
    }
    await _refreshAllAssets(root, upstreamDir);
    return;
  }

  if (mode == '--update-to-latest' || mode == '--update-to') {
    if (!upstreamDir.existsSync()) {
      final ok = await _ensureUpstreamClone(upstreamDir, pinnedSha);
      if (!ok) {
        exitCode = 1;
        return;
      }
    }
    await _gitFetchOrigin(upstreamDir);

    String targetTagOrRef;
    if (mode == '--update-to') {
      if (positional.length < 2) {
        stderr.writeln(
          'Usage: dart run tool/sync_upstream.dart --update-to <tag_or_ref>',
        );
        exitCode = 1;
        return;
      }
      targetTagOrRef = positional[1];
    } else {
      final tags = await _listSortedReleaseTags(upstreamDir);
      targetTagOrRef = tags.isNotEmpty ? tags.last : 'origin/main';
    }

    final targetSha = await _gitRevParse(upstreamDir, targetTagOrRef);
    if (targetSha == null) {
      stderr.writeln('Error: Could not resolve upstream ref $targetTagOrRef');
      exitCode = 1;
      return;
    }
    final targetDate =
        await _gitCommitIsoDate(upstreamDir, targetSha) ??
        DateTime.now().toUtc().toIso8601String();

    stdout.writeln(
      'Updating .upstream/ from $pinnedTag ($pinnedSha) -> $targetTagOrRef ($targetSha)...',
    );
    final report = await _generateCategorizedDiffReport(
      root: root,
      upstreamDir: upstreamDir,
      fromRef: pinnedSha,
      toRef: targetSha,
      fromLabel: '$pinnedTag (${pinnedSha.substring(0, 7)})',
      toLabel: '$targetTagOrRef (${targetSha.substring(0, 7)})',
      includePatch: true,
    );
    final reportFile = File('${upstreamDir.path}/diff_report.md');
    reportFile.writeAsStringSync(report.markdown);

    final co = await Process.run('git', <String>[
      'checkout',
      targetSha,
    ], workingDirectory: upstreamDir.path);
    if (co.exitCode != 0) {
      stderr.writeln('Error checking out $targetSha: ${co.stderr}');
      exitCode = 1;
      return;
    }

    final mermaidInfo = _detectUpstreamMermaidInfo(upstreamDir);
    await _refreshAllAssets(root, upstreamDir);

    stdout.writeln(report.markdown);
    if (report.totalChangedFiles == 0 || args.contains('--pin')) {
      _updateUpstreamMd(
        upstreamMdFile,
        root: root,
        tag: targetTagOrRef,
        sha: targetSha,
        date: targetDate,
        mermaidVersion: mermaidInfo.mermaidVersion,
        mermaidParser: mermaidInfo.parserSpec,
      );
      stdout.writeln(
        '✅ Updated .upstream/, UPSTREAM.md, and pubspec.yaml to $targetTagOrRef ($targetSha).',
      );
    } else {
      stdout.writeln(
        '✅ Staged upstream update to $targetTagOrRef ($targetSha) in .upstream/.\n'
        '   Diff report written to: .upstream/diff_report.md\n'
        '   Next steps:\n'
        '     1. Port the modified/added files listed above into lib/src/ and test/\n'
        '     2. Verify 100% parity: dart run tool/verify_against_upstream.dart && dart test\n'
        '     3. Verify AOT benchmarks & update doc/BENCHMARKS.md: dart run tool/benchmark_suite.dart --update-docs --check-regressions\n'
        '     4. Finalize UPSTREAM.md pin: dart run tool/sync_upstream.dart --pin $targetTagOrRef $targetSha',
      );
    }
    return;
  }

  if (mode == '--diff') {
    if (!upstreamDir.existsSync()) {
      final ok = await _ensureUpstreamClone(upstreamDir, pinnedSha);
      if (!ok) {
        exitCode = 1;
        return;
      }
    }
    var fromRef = pinnedSha;
    var toRef = 'HEAD';
    if (positional.length > 1) {
      final spec = positional[1];
      if (spec.contains('..')) {
        final parts = spec.split('..');
        fromRef = parts.first.isEmpty ? pinnedSha : parts.first;
        toRef = parts.last.isEmpty ? 'HEAD' : parts.last;
      } else {
        toRef = spec;
      }
    }
    final resolvedFrom = await _gitRevParse(upstreamDir, fromRef) ?? fromRef;
    final resolvedTo = await _gitRevParse(upstreamDir, toRef) ?? toRef;
    final report = await _generateCategorizedDiffReport(
      root: root,
      upstreamDir: upstreamDir,
      fromRef: resolvedFrom,
      toRef: resolvedTo,
      fromLabel: fromRef,
      toLabel: toRef,
      includePatch: args.contains('--patch'),
    );
    final reportFile = File('${upstreamDir.path}/diff_report.md');
    reportFile.writeAsStringSync(report.markdown);
    if (jsonOutput) {
      stdout.writeln(jsonEncode(report.toJson()));
    } else {
      stdout.writeln(report.markdown);
    }
    return;
  }

  // Default: --check or --status
  if (!upstreamDir.existsSync()) {
    final ok = await _ensureUpstreamClone(upstreamDir, pinnedSha);
    if (!ok) {
      exitCode = 1;
      return;
    }
  }
  final fetchedLive = await _gitFetchOrigin(upstreamDir);

  final headSha = await _gitRevParse(upstreamDir, 'HEAD') ?? pinnedSha;
  final tags = await _listSortedReleaseTags(upstreamDir);
  final latestTag = tags.isNotEmpty ? tags.last : pinnedTag;
  final latestTagSha =
      await _gitRevParse(upstreamDir, '$latestTag^{commit}') ??
      await _gitRevParse(upstreamDir, latestTag) ??
      pinnedSha;
  final latestTagDate =
      await _gitCommitIsoDate(upstreamDir, latestTagSha) ?? 'unknown';
  final originMainSha =
      await _gitRevParse(upstreamDir, 'origin/main') ?? latestTagSha;

  final newerTags = <String>[];
  final pinnedIdx = tags.indexWhere((t) => _compareSemver(t, pinnedTag) == 0);
  if (pinnedIdx >= 0 && pinnedIdx + 1 < tags.length) {
    newerTags.addAll(tags.sublist(pinnedIdx + 1));
  } else if (_compareSemver(latestTag, pinnedTag) > 0) {
    newerTags.add(latestTag);
  }

  final hasNewRelease = newerTags.isNotEmpty || latestTagSha != pinnedSha;
  final commitsAheadOnMain = await _gitRevListCount(
    upstreamDir,
    '$latestTagSha..$originMainSha',
  );

  // Check Mermaid.js version alignment across upstream, UPSTREAM.md,mermaid.min.js, and engine_runner.dart.
  final upstreamMermaid = _detectUpstreamMermaidInfo(
    upstreamDir,
    ref: hasNewRelease ? latestTagSha : 'HEAD',
  );
  final bundledMermaidVersion = _detectBundledMermaidVersion(root);
  final uiMermaidVersion = _detectUiMermaidLabelVersion(root);

  final mermaidNeedsSync =
      upstreamMermaid.mermaidVersion != pinnedMermaidVersion ||
      bundledMermaidVersion != upstreamMermaid.mermaidVersion ||
      uiMermaidVersion != upstreamMermaid.mermaidVersion;

  final pubspecVersion = _extractPubspecVersion(root);
  final infoRenderVersion = _extractInfoRenderVersion(root);
  final expectedBaseVersion = pinnedTag.replaceFirst(RegExp(r'^v'), '');
  final pubspecBaseVersion = pubspecVersion?.split('+').first;
  final versionInLockstep =
      pubspecBaseVersion == expectedBaseVersion &&
      infoRenderVersion == expectedBaseVersion;

  final mapping = _collectUpstreamHeaders(Directory('$root/lib/src'), root);

  final targetCompareRef = hasNewRelease
      ? latestTagSha
      : (commitsAheadOnMain > 0 ? originMainSha : headSha);
  final diffReport = await _generateCategorizedDiffReport(
    root: root,
    upstreamDir: upstreamDir,
    fromRef: pinnedSha,
    toRef: targetCompareRef,
    fromLabel: '$pinnedTag (${pinnedSha.substring(0, 7)})',
    toLabel: hasNewRelease
        ? '$latestTag (${latestTagSha.substring(0, 7)})'
        : (commitsAheadOnMain > 0
              ? 'origin/main (${originMainSha.substring(0, 7)})'
              : '$pinnedTag (${headSha.substring(0, 7)})'),
    includePatch: false,
  );

  if (hasNewRelease ||
      commitsAheadOnMain > 0 ||
      diffReport.totalChangedFiles > 0) {
    File('${upstreamDir.path}/diff_report.md')
        .writeAsStringSync(diffReport.markdown);
  }

  if (jsonOutput) {
    stdout.writeln(
      jsonEncode(<String, Object?>{
        'fetchedLiveFromGitHub': fetchedLive,
        'packageVersion': pubspecVersion,
        'expectedBaseVersion': expectedBaseVersion,
        'versionInLockstep': versionInLockstep,
        'pinnedRelease': pinnedTag,
        'pinnedCommit': pinnedSha,
        'localUpstreamHead': headSha,
        'latestRelease': latestTag,
        'latestReleaseCommit': latestTagSha,
        'latestReleaseDate': latestTagDate,
        'newerReleases': newerTags,
        'hasNewRelease': hasNewRelease,
        'originMainCommit': originMainSha,
        'unreleasedCommitsOnMain': commitsAheadOnMain,
        'mermaid': <String, Object?>{
          'upstreamTargetVersion': upstreamMermaid.mermaidVersion,
          'upstreamParserSpec': upstreamMermaid.parserSpec,
          'pinnedVersion': pinnedMermaidVersion,
          'pinnedParserSpec': pinnedMermaidParser,
          'bundledAssetVersion': bundledMermaidVersion,
          'uiLabelVersion': uiMermaidVersion,
          'needsSync': mermaidNeedsSync,
        },
        'mappedDartFiles': mapping.length,
        'diffSummary': diffReport.toJson(),
        'updateAvailable':
            hasNewRelease || commitsAheadOnMain > 0 || mermaidNeedsSync,
      }),
    );
    return;
  }

  stdout.writeln('═══════════════════════════════════════════════════════════');
  stdout.writeln('  pele_dart Upstream Sync & Release Detector');
  stdout.writeln('═══════════════════════════════════════════════════════════');
  stdout.writeln(
    'Remote Fetch:           ${fetchedLive ? "Live from github.com/obsidianmd/pele" : "Cached (.upstream local refs)"}',
  );
  stdout.writeln(
    'pele_dart Version:      ${pubspecVersion ?? "unknown"} (${versionInLockstep ? "LOCKSTEP with $pinnedTag" : "MISMATCH vs $pinnedTag"})',
  );
  stdout.writeln('Pinned Pele Release:    $pinnedTag ($pinnedSha)');
  stdout.writeln(
    'Latest Pele Release:    $latestTag ($latestTagSha, $latestTagDate)',
  );
  stdout.writeln(
    '.upstream Checkout:     ${headSha == pinnedSha ? "$headSha (MATCH)" : "$headSha (MISMATCH vs UPSTREAM.md)"}',
  );
  stdout.writeln('Mapped Dart Files:      ${mapping.length}');
  stdout.writeln('───────────────────────────────────────────────────────────');
  stdout.writeln(
    'Upstream Target Mermaid: v${upstreamMermaid.mermaidVersion} (${upstreamMermaid.parserSpec})',
  );
  stdout.writeln(
    'Pinned Target Mermaid:   v$pinnedMermaidVersion ($pinnedMermaidParser)',
  );
  stdout.writeln(
    'Bundled mermaid.min.js:  v${bundledMermaidVersion ?? "unknown"}',
  );
  stdout.writeln(
    'Studio UI Label:         mermaid.js (v${uiMermaidVersion ?? "unknown"})',
  );
  stdout.writeln('═══════════════════════════════════════════════════════════');

  if (hasNewRelease) {
    stdout.writeln(
      '\n🔔 NEW UPSTREAM PELE RELEASE AVAILABLE: $pinnedTag -> $latestTag',
    );
    if (newerTags.isNotEmpty) {
      stdout.writeln('   New releases: ${newerTags.join(", ")}');
    }
    stdout.writeln();
    stdout.writeln(diffReport.markdown);
    stdout.writeln('To stage this release and refresh bundles/galleries, run:');
    stdout.writeln('  dart run tool/sync_upstream.dart --update-to-latest');
  } else if (commitsAheadOnMain > 0) {
    stdout.writeln(
      '\nℹ️  Up to date with latest tagged release ($latestTag), but origin/main has $commitsAheadOnMain unreleased commit(s):',
    );
    stdout.writeln();
    stdout.writeln(diffReport.markdown);
    stdout.writeln('To stage origin/main if desired, run:');
    stdout.writeln(
      '  dart run tool/sync_upstream.dart --update-to origin/main',
    );
  } else {
    stdout.writeln(
      '\n✅ Pele engine is up to date with the latest upstream release ($latestTag @ ${pinnedSha.substring(0, 7)}).',
    );
  }

  if (mermaidNeedsSync) {
    stdout.writeln(
      '\n⚠️  MERMAID.JS VERSION OUT OF SYNC:\n'
      '   Upstream Pele targets Mermaid v${upstreamMermaid.mermaidVersion}, '
      'but bundled asset is v${bundledMermaidVersion ?? "unknown"} '
      '(UI label: v${uiMermaidVersion ?? "unknown"}, UPSTREAM.md: v$pinnedMermaidVersion).\n'
      '   Run this command to sync mermaid.min.js and studio labels:\n'
      '     dart run tool/sync_upstream.dart --refresh-assets',
    );
  } else {
    stdout.writeln(
      '✅ Bundled Mermaid.js (v${upstreamMermaid.mermaidVersion}) matches upstream Pele target.',
    );
  }

  if (!versionInLockstep) {
    stdout.writeln(
      '\n❌ PACKAGE VERSION OUT OF LOCKSTEP:\n'
      '   pubspec.yaml is version "${pubspecVersion ?? "unknown"}", '
      'but UPSTREAM.md Target Release is "$pinnedTag" (expected "$expectedBaseVersion" or "$expectedBaseVersion+<hotfix>").\n'
      '   Run this command to sync pubspec.yaml with UPSTREAM.md:\n'
      '     dart run tool/sync_upstream.dart --pin $pinnedTag $pinnedSha',
    );
    exitCode = 1;
  } else {
    stdout.writeln(
      '✅ pele_dart version ($pubspecVersion) is in 1:1 lockstep with upstream Pele ($pinnedTag).',
    );
  }
}

void _printUsage() {
  stdout.writeln('''
pele_dart Upstream Sync & Release Tool

Commands:
  dart run tool/sync_upstream.dart [--check] [--json]
    Check GitHub for new obsidianmd/pele releases, main commits, and Mermaid version changes.

  dart run tool/sync_upstream.dart --update-to-latest
    Update .upstream/ to the latest tagged obsidianmd/pele release, generate .upstream/diff_report.md,
    refresh pele.bundle.js, mermaid.min.js, and doc/images/, and update UPSTREAM.md.

  dart run tool/sync_upstream.dart --update-to <tag_or_ref>
    Update .upstream/ to a specific release tag or commit SHA.

  dart run tool/sync_upstream.dart --diff [from..to | target_ref] [--patch]
    Generate a categorized TypeScript-to-Dart diff report in .upstream/diff_report.md.

  dart run tool/sync_upstream.dart --refresh-assets [ref]
    Rebuild studio/assets/pele.bundle.js, sync studio/assets/mermaid.min.js to upstream's target
    Mermaid version, and regenerate doc/images/ and doc/DIAGRAM_GALLERY.md.

  dart run tool/sync_upstream.dart --pin <tag> [sha]
    Update UPSTREAM.md with the given release tag and commit SHA.

  dart run tool/sync_upstream.dart --ensure
    Ensure .upstream/ is cloned and checked out at the pinned SHA in UPSTREAM.md.
''');
}

Future<bool> _ensureUpstreamClone(
  Directory upstreamDir,
  String pinnedSha,
) async {
  if (!upstreamDir.existsSync()) {
    stderr.writeln('Cloning obsidianmd/pele into .upstream...');
    final clone = await Process.run('git', <String>[
      'clone',
      'https://github.com/obsidianmd/pele.git',
      upstreamDir.path,
    ]);
    if (clone.exitCode != 0) {
      stderr.writeln(clone.stderr);
      return false;
    }
  }
  await _gitFetchOrigin(upstreamDir);
  final checkout = await Process.run('git', <String>[
    'checkout',
    pinnedSha,
  ], workingDirectory: upstreamDir.path);
  if (checkout.exitCode != 0) {
    stderr.writeln(checkout.stderr);
    return false;
  }
  return true;
}

Future<bool> _gitFetchOrigin(Directory upstreamDir) async {
  if (!upstreamDir.existsSync()) return false;
  try {
    final res = await Process.run('git', <String>[
      'fetch',
      '--tags',
      '--prune',
      'origin',
    ], workingDirectory: upstreamDir.path);
    return res.exitCode == 0;
  } catch (_) {
    return false;
  }
}

Future<String?> _gitRevParse(Directory upstreamDir, String ref) async {
  if (!upstreamDir.existsSync()) return null;
  for (final candidate in <String>[
    ref,
    if (ref.startsWith('v')) ref.substring(1) else 'v$ref',
  ]) {
    final res = await Process.run('git', <String>[
      'rev-parse',
      '--verify',
      candidate,
    ], workingDirectory: upstreamDir.path);
    if (res.exitCode == 0) {
      final out = (res.stdout as String).trim();
      if (out.isNotEmpty) return out;
    }
  }
  return null;
}

Future<String?> _gitCommitIsoDate(Directory upstreamDir, String ref) async {
  if (!upstreamDir.existsSync()) return null;
  final res = await Process.run('git', <String>[
    'show',
    '-s',
    '--format=%cI',
    ref,
  ], workingDirectory: upstreamDir.path);
  if (res.exitCode != 0) return null;
  final out = (res.stdout as String).trim();
  return out.isEmpty ? null : out;
}

Future<int> _gitRevListCount(Directory upstreamDir, String range) async {
  if (!upstreamDir.existsSync()) return 0;
  final res = await Process.run('git', <String>[
    'rev-list',
    '--count',
    range,
  ], workingDirectory: upstreamDir.path);
  if (res.exitCode != 0) return 0;
  return int.tryParse((res.stdout as String).trim()) ?? 0;
}

Future<List<String>> _listSortedReleaseTags(Directory upstreamDir) async {
  if (!upstreamDir.existsSync()) return <String>[];
  final res = await Process.run('git', <String>[
    'tag',
    '-l',
  ], workingDirectory: upstreamDir.path);
  if (res.exitCode != 0) return <String>[];
  final tags =
      (res.stdout as String)
          .split('\n')
          .map((t) => t.trim())
          .where((t) => RegExp(r'^v?\d+\.\d+\.\d+$').hasMatch(t))
          .toList()
        ..sort(_compareSemver);
  return tags;
}

int _compareSemver(String a, String b) {
  List<int> parse(String s) {
    final clean = s.startsWith('v') ? s.substring(1) : s;
    final mainPart = clean.split('-').first;
    return mainPart.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  }

  final pa = parse(a);
  final pb = parse(b);
  for (var i = 0; i < 3; i++) {
    final va = i < pa.length ? pa[i] : 0;
    final vb = i < pb.length ? pb[i] : 0;
    if (va != vb) return va.compareTo(vb);
  }
  return 0;
}

class _UpstreamMermaidInfo {
  final String mermaidVersion;
  final String parserSpec;

  const _UpstreamMermaidInfo({
    required this.mermaidVersion,
    required this.parserSpec,
  });
}

_UpstreamMermaidInfo _detectUpstreamMermaidInfo(
  Directory upstreamDir, {
  String? ref,
}) {
  var mermaidVersion = '12.1.0';
  var parserSpec = '@mermaid-js/parser@2.0.1';

  String? readUpstreamFile(String relPath) {
    if (ref != null && ref != 'HEAD') {
      final res = Process.runSync('git', <String>[
        'show',
        '$ref:$relPath',
      ], workingDirectory: upstreamDir.path);
      if (res.exitCode == 0) {
        return res.stdout as String;
      }
    }
    final f = File('${upstreamDir.path}/$relPath');
    return f.existsSync() ? f.readAsStringSync() : null;
  }

  final benchJs = readUpstreamFile('scripts/bench-mermaid.mjs');
  if (benchJs != null) {
    final m = RegExp(
      r"option\(\s*'--mermaid'\s*,\s*'([0-9]+\.[0-9]+\.[0-9]+)'\s*\)",
    ).firstMatch(benchJs);
    if (m != null) {
      mermaidVersion = m.group(1)!;
    }
  }

  final websitePkg = readUpstreamFile('website/package.json');
  if (websitePkg != null) {
    final m = RegExp(r'"mermaid"\s*:\s*"\^?([0-9]+\.[0-9]+\.[0-9]+)"')
        .firstMatch(websitePkg);
    if (m != null) {
      mermaidVersion = m.group(1)!;
    }
  }

  final rootPkg = readUpstreamFile('package.json');
  if (rootPkg != null) {
    final m = RegExp(
      r'"@mermaid-js/parser"\s*:\s*"\^?([0-9]+\.[0-9]+\.[0-9]+)"',
    ).firstMatch(rootPkg);
    if (m != null) {
      parserSpec = '@mermaid-js/parser@${m.group(1)!}';
    }
  }

  return _UpstreamMermaidInfo(
    mermaidVersion: mermaidVersion,
    parserSpec: parserSpec,
  );
}

String? _detectBundledMermaidVersion(String root) {
  final file = File('$root/studio/assets/mermaid.min.js');
  if (!file.existsSync()) return null;
  final text = file.readAsStringSync();
  final matches = RegExp(r'version:"([0-9]+\.[0-9]+\.[0-9]+)"')
      .allMatches(text)
      .map((m) => m.group(1)!)
      .where((v) => !v.startsWith('0.'))
      .toList();
  return matches.isNotEmpty ? matches.first : null;
}

String? _detectUiMermaidLabelVersion(String root) {
  final file = File('$root/studio/lib/engine_runner.dart');
  if (!file.existsSync()) return null;
  final text = file.readAsStringSync();
  final m = RegExp(r'mermaid\.js \(v([^)]+)\)').firstMatch(text);
  return m?.group(1);
}

class _DiffReportData {
  final String fromRef;
  final String toRef;
  final List<String> commits;
  final List<Map<String, String>> modifiedFiles;
  final List<Map<String, String>> addedFiles;
  final List<Map<String, String>> deletedOrRenamedFiles;
  final List<String> newDiagramFamilies;
  final List<String> detectorDiffLines;
  final List<String> corpusAndWebsiteFiles;
  final String markdown;

  const _DiffReportData({
    required this.fromRef,
    required this.toRef,
    required this.commits,
    required this.modifiedFiles,
    required this.addedFiles,
    required this.deletedOrRenamedFiles,
    required this.newDiagramFamilies,
    required this.detectorDiffLines,
    required this.corpusAndWebsiteFiles,
    required this.markdown,
  });

  int get totalChangedFiles =>
      modifiedFiles.length +
      addedFiles.length +
      deletedOrRenamedFiles.length +
      corpusAndWebsiteFiles.length;

  Map<String, Object> toJson() => <String, Object>{
    'fromRef': fromRef,
    'toRef': toRef,
    'commits': commits,
    'modifiedFiles': modifiedFiles,
    'addedFiles': addedFiles,
    'deletedOrRenamedFiles': deletedOrRenamedFiles,
    'newDiagramFamilies': newDiagramFamilies,
    'detectorChanges': detectorDiffLines,
    'corpusAndWebsiteFiles': corpusAndWebsiteFiles,
    'totalChangedFiles': totalChangedFiles,
  };
}

Future<_DiffReportData> _generateCategorizedDiffReport({
  required String root,
  required Directory upstreamDir,
  required String fromRef,
  required String toRef,
  required String fromLabel,
  required String toLabel,
  required bool includePatch,
}) async {
  final mapping = _collectUpstreamHeaders(Directory('$root/lib/src'), root);

  final logRes = await Process.run('git', <String>[
    'log',
    '--oneline',
    '$fromRef..$toRef',
  ], workingDirectory: upstreamDir.path);
  final commits = (logRes.stdout as String)
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  final diffStat = await Process.run('git', <String>[
    'diff',
    '--name-status',
    '$fromRef..$toRef',
    '--',
    'src/',
    'tests/corpus/',
    'website/src/lib/examples.ts',
    'scripts/bench-mermaid.mjs',
    'website/package.json',
    'package.json',
  ], workingDirectory: upstreamDir.path);

  final modifiedFiles = <Map<String, String>>[];
  final addedFiles = <Map<String, String>>[];
  final deletedOrRenamedFiles = <Map<String, String>>[];
  final newDiagramFamiliesSet = <String>{};
  final corpusAndWebsiteFiles = <String>[];

  final lines = (diffStat.stdout as String)
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty);

  for (final line in lines) {
    final parts = line.split(RegExp(r'\s+'));
    final status = parts.first;
    final path = parts.last;

    if (!path.startsWith('src/')) {
      corpusAndWebsiteFiles.add('$status $path');
      continue;
    }

    final mappedDart = mapping[path] ?? _proposeDartPath(path);
    final entry = <String, String>{
      'status': status,
      'upstream': path,
      'dart': mappedDart,
      'mapped': mapping.containsKey(path) ? 'yes' : 'new',
    };

    if (status == 'A') {
      addedFiles.add(entry);
      final diagMatch = RegExp(r'^src/diagrams/([^/]+)/').firstMatch(path);
      if (diagMatch != null) {
        final fam = diagMatch.group(1)!;
        if (!Directory('$root/lib/src/diagrams/$fam').existsSync()) {
          newDiagramFamiliesSet.add(fam);
        }
      }
    } else if (status == 'M') {
      modifiedFiles.add(entry);
    } else {
      deletedOrRenamedFiles.add(entry);
    }
  }

  // Check src/detect.ts specifically for beta-to-stable promotions or new diagram detectors.
  final detectDiffRes = await Process.run('git', <String>[
    'diff',
    '-U2',
    '$fromRef..$toRef',
    '--',
    'src/detect.ts',
  ], workingDirectory: upstreamDir.path);
  final detectorDiffLines = (detectDiffRes.stdout as String)
      .split('\n')
      .where(
        (l) =>
            (l.startsWith('+') || l.startsWith('-')) &&
            !l.startsWith('+++') &&
            !l.startsWith('---'),
      )
      .toList();

  final fromMermaid = _detectUpstreamMermaidInfo(upstreamDir, ref: fromRef);
  final toMermaid = _detectUpstreamMermaidInfo(upstreamDir, ref: toRef);

  final sb = StringBuffer()
    ..writeln('# Upstream Sync Report (`$fromLabel` -> `$toLabel`)')
    ..writeln();

  if (commits.isEmpty &&
      modifiedFiles.isEmpty &&
      addedFiles.isEmpty &&
      deletedOrRenamedFiles.isEmpty &&
      corpusAndWebsiteFiles.isEmpty) {
    sb.writeln('No upstream changes between `$fromLabel` and `$toLabel`.');
  } else {
    if (commits.isNotEmpty) {
      sb.writeln('## Upstream Commits (${commits.length})');
      for (final c in commits) {
        sb.writeln('- `$c`');
      }
      sb.writeln();
    }

    if (fromMermaid.mermaidVersion != toMermaid.mermaidVersion ||
        fromMermaid.parserSpec != toMermaid.parserSpec) {
      sb
        ..writeln('## Mermaid.js Baseline Change')
        ..writeln(
          '- **Mermaid.js**: `v${fromMermaid.mermaidVersion}` -> `v${toMermaid.mermaidVersion}`',
        )
        ..writeln(
          '- **Parser**: `${fromMermaid.parserSpec}` -> `${toMermaid.parserSpec}`',
        )
        ..writeln();
    }

    if (newDiagramFamiliesSet.isNotEmpty) {
      sb.writeln(
        '## New Diagram Families Detected (${newDiagramFamiliesSet.length})',
      );
      for (final fam in newDiagramFamiliesSet) {
        sb.writeln(
          '- **`$fam`**: Port `src/diagrams/$fam/` -> `lib/src/diagrams/$fam/`, register in `lib/src/diagrams/registry.dart`, add detector in `lib/src/detect.dart`, and add unit tests in `test/diagrams/${fam}_test.dart`.',
        );
      }
      sb.writeln();
    }

    if (detectorDiffLines.isNotEmpty) {
      sb
        ..writeln(
          '## Diagram Detector / Beta Promotion Changes (`src/detect.ts` -> `lib/src/detect.dart`)',
        )
        ..writeln('```diff');
      for (final l in detectorDiffLines) {
        sb.writeln(l);
      }
      sb
        ..writeln('```')
        ..writeln();
    }

    if (modifiedFiles.isNotEmpty) {
      sb
        ..writeln('## Modified Source Files (${modifiedFiles.length})')
        ..writeln('| Status | Upstream TypeScript File | Mapped Dart File |')
        ..writeln('| :--- | :--- | :--- |');
      for (final f in modifiedFiles) {
        sb.writeln(
          '| `${f['status']}` | `${f['upstream']}` | `${f['dart']}` |',
        );
      }
      sb.writeln();
    }

    if (addedFiles.isNotEmpty) {
      sb
        ..writeln('## Added Source Files (${addedFiles.length})')
        ..writeln('| Status | Upstream TypeScript File | Target Dart File |')
        ..writeln('| :--- | :--- | :--- |');
      for (final f in addedFiles) {
        sb.writeln(
          '| `${f['status']}` | `${f['upstream']}` | `${f['dart']}` |',
        );
      }
      sb.writeln();
    }

    if (deletedOrRenamedFiles.isNotEmpty) {
      sb
        ..writeln(
          '## Deleted or Renamed Source Files (${deletedOrRenamedFiles.length})',
        )
        ..writeln('| Status | Upstream TypeScript File | Mapped Dart File |')
        ..writeln('| :--- | :--- | :--- |');
      for (final f in deletedOrRenamedFiles) {
        sb.writeln(
          '| `${f['status']}` | `${f['upstream']}` | `${f['dart']}` |',
        );
      }
      sb.writeln();
    }

    if (corpusAndWebsiteFiles.isNotEmpty) {
      sb.writeln(
        '## Corpus, Website Examples & Build Metadata (${corpusAndWebsiteFiles.length})',
      );
      for (final c in corpusAndWebsiteFiles) {
        sb.writeln('- `$c`');
      }
      sb.writeln();
    }

    if (includePatch && (modifiedFiles.isNotEmpty || addedFiles.isNotEmpty)) {
      final patchRes = await Process.run('git', <String>[
        'diff',
        '$fromRef..$toRef',
        '--',
        'src/',
      ], workingDirectory: upstreamDir.path);
      final patchText = (patchRes.stdout as String).trim();
      if (patchText.isNotEmpty) {
        sb
          ..writeln('## Unified Diff (`src/`)')
          ..writeln('```diff')
          ..writeln(patchText)
          ..writeln('```');
      }
    }
  }

  return _DiffReportData(
    fromRef: fromRef,
    toRef: toRef,
    commits: commits,
    modifiedFiles: modifiedFiles,
    addedFiles: addedFiles,
    deletedOrRenamedFiles: deletedOrRenamedFiles,
    newDiagramFamilies: newDiagramFamiliesSet.toList(),
    detectorDiffLines: detectorDiffLines,
    corpusAndWebsiteFiles: corpusAndWebsiteFiles,
    markdown: sb.toString(),
  );
}

String _proposeDartPath(String upstreamTsPath) {
  if (!upstreamTsPath.endsWith('.ts')) return upstreamTsPath;
  final withoutExt = upstreamTsPath.substring(0, upstreamTsPath.length - 3);
  final segments = withoutExt.split('/');
  final fileName = segments.last;
  final snakeName = fileName.replaceAllMapped(
    RegExp(r'([a-z0-9])([A-Z])'),
    (m) => '${m.group(1)}_${m.group(2)!.toLowerCase()}',
  );
  final dirSegments = segments.sublist(0, segments.length - 1);
  return 'lib/${<String>[...dirSegments, '$snakeName.dart'].join('/')}';
}

Future<void> _refreshAllAssets(String root, Directory upstreamDir) async {
  // 1. Rebuild studio/assets/pele.bundle.js from .upstream/src/index.ts via bun build.
  final bunFile = File('/opt/homebrew/bin/bun');
  if (bunFile.existsSync()) {
    stdout.writeln('1. Rebuilding studio/assets/pele.bundle.js via bun...');
    final bundlePath = '$root/studio/assets/pele.bundle.js';
    final buildRes = await Process.run(bunFile.path, <String>[
      'build',
      '${upstreamDir.path}/src/index.ts',
      '--format=iife',
      '--outfile=$bundlePath',
    ]);
    if (buildRes.exitCode != 0) {
      stderr.writeln('Error building pele.bundle.js: ${buildRes.stderr}');
    } else {
      final bundleFile = File(bundlePath);
      var bundleText = bundleFile.readAsStringSync();
      if (!bundleText.contains('globalThis.Pele = exports_src;')) {
        final closeIdx = bundleText.lastIndexOf('})();');
        if (closeIdx > 0) {
          bundleText =
              '${bundleText.substring(0, closeIdx)}'
              '  globalThis.Pele = exports_src;\n'
              '  globalThis.PeleMetricsMeasurer = metricsMeasurer;\n'
              '})();\n';
          bundleFile.writeAsStringSync(bundleText);
        }
      }
      stdout.writeln(
        '   ✓ Built studio/assets/pele.bundle.js (${bundleText.length} bytes)',
      );
    }
  }

  // 2. Sync studio/assets/mermaid.min.js and studio/lib/engine_runner.dart to upstream's target Mermaid version.
  final mermaidInfo = _detectUpstreamMermaidInfo(upstreamDir);
  final targetMermaidVer = mermaidInfo.mermaidVersion;
  final currentBundledVer = _detectBundledMermaidVersion(root);
  final mermaidAssetFile = File('$root/studio/assets/mermaid.min.js');

  if (currentBundledVer != targetMermaidVer || !mermaidAssetFile.existsSync()) {
    final url =
        'https://unpkg.com/mermaid@$targetMermaidVer/dist/mermaid.min.js';
    stdout.writeln(
      '2. Syncing studio/assets/mermaid.min.js ($currentBundledVer -> $targetMermaidVer) from $url...',
    );
    var downloaded = false;
    try {
      final curlRes = await Process.run('curl', <String>[
        '-fsSL',
        url,
        '-o',
        mermaidAssetFile.path,
      ]);
      if (curlRes.exitCode == 0 &&
          mermaidAssetFile.existsSync() &&
          mermaidAssetFile.lengthSync() > 1000) {
        downloaded = true;
        stdout.writeln(
          '   ✓ Downloaded mermaid@$targetMermaidVer (${mermaidAssetFile.lengthSync()} bytes)',
        );
      }
    } catch (_) {
      // Fall back to HttpClient below.
    }
    if (!downloaded) {
      try {
        final client = HttpClient();
        final req = await client.getUrl(Uri.parse(url));
        final resp = await req.close();
        if (resp.statusCode == 200) {
          final bytes = await resp.fold<List<int>>(
            <int>[],
            (acc, chunk) => acc..addAll(chunk),
          );
          mermaidAssetFile.writeAsBytesSync(bytes);
          stdout.writeln(
            '   ✓ Downloaded mermaid@$targetMermaidVer (${bytes.length} bytes)',
          );
        } else {
          stderr.writeln(
            '   ⚠️ HTTP ${resp.statusCode} fetching $url (keep existing bundle or run with network access)',
          );
        }
        client.close();
      } catch (e) {
        stderr.writeln(
          '   ⚠️ Could not download $url ($e). Run unsandboxed with network access to fetch.',
        );
      }
    }
  } else {
    stdout.writeln(
      '2. studio/assets/mermaid.min.js already at v$targetMermaidVer.',
    );
  }

  // Update engine_runner.dart label to mermaid.js (v<targetMermaidVer>).
  final engineRunnerFile = File('$root/studio/lib/engine_runner.dart');
  if (engineRunnerFile.existsSync()) {
    final oldText = engineRunnerFile.readAsStringSync();
    final newText = oldText.replaceAll(
      RegExp(r"mermaidJs\('mermaid_js',\s*'mermaid\.js \(v[^)]+\)'"),
      "mermaidJs('mermaid_js', 'mermaid.js (v$targetMermaidVer)'",
    );
    if (newText != oldText) {
      engineRunnerFile.writeAsStringSync(newText);
      stdout.writeln(
        '   ✓ Updated studio/lib/engine_runner.dart label to mermaid.js (v$targetMermaidVer)',
      );
    }
  }

  // 3. Regenerate clean standalone SVG diagram images (doc/images/diagrams/*.svg),
  //    styled showcase images (doc/images/styles/*.svg), and doc/DIAGRAM_GALLERY.md.
  final docGenScript = File('$root/tool/generate_doc_images.dart');
  if (docGenScript.existsSync()) {
    stdout.writeln(
      '3. Regenerating standalone diagram & style images (tool/generate_doc_images.dart)...',
    );
    final imgRes = await Process.run(Platform.resolvedExecutable, <String>[
      docGenScript.path,
    ], workingDirectory: root);
    if (imgRes.exitCode == 0) {
      stdout.writeln(
        '   ✓ Regenerated doc/images/diagrams/*.svg, doc/images/styles/*.svg, and doc/DIAGRAM_GALLERY.md',
      );
    } else {
      stderr.writeln('   ⚠️ Failed to regenerate doc images: ${imgRes.stderr}');
    }
  }
}

void _updateUpstreamMd(
  File upstreamMdFile, {
  required String root,
  required String tag,
  required String sha,
  required String date,
  required String mermaidVersion,
  required String mermaidParser,
}) {
  var text = upstreamMdFile.readAsStringSync();
  text = text.replaceFirstMapped(
    RegExp(r'(\*\*Target Release\*\*\s*\|\s*)`[^`]+`'),
    (m) => '${m.group(1)}`$tag`',
  );
  text = text.replaceFirstMapped(
    RegExp(r'(\*\*Target Commit SHA\*\*\s*\|\s*)`[^`]+`'),
    (m) => '${m.group(1)}`$sha`',
  );
  text = text.replaceFirstMapped(
    RegExp(r'(\*\*Target Commit Date\*\*\s*\|\s*)`[^`]+`'),
    (m) => '${m.group(1)}`$date`',
  );
  if (text.contains('**Target Mermaid Version**')) {
    text = text.replaceFirstMapped(
      RegExp(r'(\*\*Target Mermaid Version\*\*\s*\|\s*)`[^`]+`'),
      (m) => '${m.group(1)}`$mermaidVersion`',
    );
  }
  if (text.contains('**Target Mermaid Parser**')) {
    text = text.replaceFirstMapped(
      RegExp(r'(\*\*Target Mermaid Parser\*\*\s*\|\s*)`[^`]+`'),
      (m) => '${m.group(1)}`$mermaidParser`',
    );
  }
  text = text.replaceAll(
    RegExp(r'\|\s*✅ Ported\s*\|\s*`[0-9a-f]{40}`\s*\|'),
    '| ✅ Ported | `$sha` |',
  );
  upstreamMdFile.writeAsStringSync(text);

  // Enforce 1:1 version lockstep in pubspec.yaml and lib/src/diagrams/info/render.dart when tag is semver (vX.Y.Z or X.Y.Z).
  final semverMatch = RegExp(r'^v?(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?)$')
      .firstMatch(tag.trim());
  if (semverMatch != null) {
    final semver = semverMatch.group(1)!;
    final pubspecFile = File('$root/pubspec.yaml');
    if (pubspecFile.existsSync()) {
      final pubText = pubspecFile.readAsStringSync();
      final updatedPub = pubText.replaceFirstMapped(
        RegExp(r'^version:\s*\S+', multiLine: true),
        (_) => 'version: $semver',
      );
      if (updatedPub != pubText) {
        pubspecFile.writeAsStringSync(updatedPub);
      }
    }
    final infoRenderFile = File('$root/lib/src/diagrams/info/render.dart');
    if (infoRenderFile.existsSync()) {
      final infoText = infoRenderFile.readAsStringSync();
      final updatedInfo = infoText.replaceFirstMapped(
        RegExp(r"const String peleVersion = '[^']+';"),
        (_) => "const String peleVersion = '$semver';",
      );
      if (updatedInfo != infoText) {
        infoRenderFile.writeAsStringSync(updatedInfo);
      }
    }
  }
}

String? _extractPubspecVersion(String root) {
  final file = File('$root/pubspec.yaml');
  if (!file.existsSync()) return null;
  final m = RegExp(
    r'^version:\s*(\S+)',
    multiLine: true,
  ).firstMatch(file.readAsStringSync());
  return m?.group(1)?.trim();
}

String? _extractInfoRenderVersion(String root) {
  final file = File('$root/lib/src/diagrams/info/render.dart');
  if (!file.existsSync()) return null;
  final m = RegExp(r"const String peleVersion = '([^']+)';")
      .firstMatch(file.readAsStringSync());
  return m?.group(1)?.trim();
}

String? _extractField(String markdown, String label) {
  final re = RegExp('\\*\\*${RegExp.escape(label)}\\*\\*\\s*\\|\\s*`([^`]+)`');
  return re.firstMatch(markdown)?.group(1)?.trim();
}

Map<String, String> _collectUpstreamHeaders(Directory dir, String root) {
  final map = <String, String>{};
  if (!dir.existsSync()) return map;
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final firstLine = entity.readAsLinesSync().firstOrNull ?? '';
    final m = RegExp(r'^//\s*Upstream:\s*(\S+)').firstMatch(firstLine);
    if (m != null) {
      final relDart = entity.path.substring(root.length + 1);
      map[m.group(1)!] = relDart;
    }
  }
  return map;
}

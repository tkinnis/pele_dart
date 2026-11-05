import 'dart:io';

/// Reads `UPSTREAM.md`, manages the gitignored `.upstream/` clone of `obsidianmd/pele`,
/// and generates file-by-file upstream diff reports mapped to `lib/src/**/*.dart`.
Future<void> main(List<String> args) async {
  final root = Directory.current.path;
  final upstreamMd = File('$root/UPSTREAM.md');
  if (!upstreamMd.existsSync()) {
    stderr.writeln('Error: UPSTREAM.md not found in $root');
    exitCode = 1;
    return;
  }

  final content = upstreamMd.readAsStringSync();
  final pinnedSha =
      _extractField(content, 'Target Commit SHA') ??
      _extractField(content, 'Pinned Upstream Commit');
  final pinnedTag =
      _extractField(content, 'Target Release') ??
      _extractField(content, 'Pinned Upstream Tag');
  if (pinnedSha == null) {
    stderr.writeln('Error: Could not parse Target Commit SHA from UPSTREAM.md');
    exitCode = 1;
    return;
  }

  final upstreamDir = Directory('$root/.upstream');
  final mode = args.isNotEmpty ? args.first : '--status';

  if (mode == '--ensure') {
    if (!upstreamDir.existsSync()) {
      stdout.writeln('Cloning obsidianmd/pele into .upstream...');
      final clone = await Process.run('git', <String>[
        'clone',
        'https://github.com/obsidianmd/pele.git',
        upstreamDir.path,
      ]);
      if (clone.exitCode != 0) {
        stderr.writeln(clone.stderr);
        exitCode = clone.exitCode;
        return;
      }
    }
    final checkout = await Process.run('git', <String>[
      'checkout',
      pinnedSha,
    ], workingDirectory: upstreamDir.path);
    if (checkout.exitCode != 0) {
      stderr.writeln(checkout.stderr);
      exitCode = checkout.exitCode;
      return;
    }
    stdout.writeln('Checked out $pinnedTag ($pinnedSha) in .upstream/');
    return;
  }

  if (mode == '--diff') {
    final target = args.length > 1 ? args[1] : 'HEAD';
    if (!upstreamDir.existsSync()) {
      stderr.writeln(
        'Error: .upstream/ clone not found. Run with --ensure first.',
      );
      exitCode = 1;
      return;
    }
    final diffStat = await Process.run('git', <String>[
      'diff',
      '--name-status',
      '$pinnedSha..$target',
      '--',
      'src/',
    ], workingDirectory: upstreamDir.path);
    final mapping = _collectUpstreamHeaders(Directory('$root/lib/src'), root);
    final report = StringBuffer()
      ..writeln('# Upstream Diff Report (`$pinnedSha..$target`)')
      ..writeln()
      ..writeln('| Status | Upstream File | Mapped Dart File |')
      ..writeln('| :--- | :--- | :--- |');
    final lines = (diffStat.stdout as String)
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty);
    for (final line in lines) {
      final parts = line.split(RegExp(r'\s+'));
      final status = parts.first;
      final upstreamPath = parts.last;
      final dartPath = mapping[upstreamPath] ?? '*(unmapped)*';
      report.writeln('| `$status` | `$upstreamPath` | `$dartPath` |');
    }
    final reportFile = File('${upstreamDir.path}/diff_report.md');
    reportFile.writeAsStringSync(report.toString());
    stdout.writeln(report);
    return;
  }

  // Default: --status
  stdout.writeln('Pinned Upstream Tag:    ${pinnedTag ?? "unknown"}');
  stdout.writeln('Pinned Upstream Commit: $pinnedSha');
  if (upstreamDir.existsSync()) {
    final head = await Process.run('git', <String>[
      'rev-parse',
      'HEAD',
    ], workingDirectory: upstreamDir.path);
    final actualSha = (head.stdout as String).trim();
    stdout.writeln('.upstream HEAD Commit:  $actualSha');
    stdout.writeln(
      'Sync Status:            ${actualSha == pinnedSha ? "MATCH" : "MISMATCH"}',
    );
  } else {
    stdout.writeln('.upstream Status:       Not cloned (run --ensure)');
  }
  final mapping = _collectUpstreamHeaders(Directory('$root/lib/src'), root);
  stdout.writeln('Mapped Dart files:      ${mapping.length}');
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

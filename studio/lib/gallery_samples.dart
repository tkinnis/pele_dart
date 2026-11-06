import 'dart:convert';
import 'dart:io';

/// Supported Mermaid diagram file extensions scanned by the gallery loader.
const List<String> kMermaidFileExtensions = <String>['.mmd', '.mermaid'];

/// Checks whether [path] has a supported Mermaid file extension (`.mmd` or `.mermaid`).
bool isMermaidDiagramFile(String path) {
  final lower = path.toLowerCase();
  return kMermaidFileExtensions.any(lower.endsWith);
}

/// A single Mermaid diagram file loaded from disk (e.g. `01_subgraph_client.mmd`).
class PlaygroundSampleItem {
  final String label;
  final String source;
  final String fileName;
  final String? filePath;

  const PlaygroundSampleItem({
    required this.label,
    required this.source,
    this.fileName = '',
    this.filePath,
  });
}

/// Primary folder / diagram family entry scanned from `studio/diagrams/`.
class DiagramSample {
  final String id;
  final String title;
  final String description;
  final String diagramType;
  final bool beta;
  final int tier;
  final String categoryFolder;
  final String? folderPath;
  final String source;
  final List<String> showcaseSources;
  final List<PlaygroundSampleItem> playgroundSamples;

  const DiagramSample({
    required this.id,
    required this.title,
    required this.description,
    required this.diagramType,
    required this.beta,
    required this.tier,
    required this.source,
    required this.showcaseSources,
    required this.playgroundSamples,
    this.categoryFolder = '01_core',
    this.folderPath,
  });
}

Directory? _customDiagramsRootOverride;
List<DiagramSample>? _cachedGallerySamples;
String? _cachedDefaultSource;

/// Resolves the `studio/diagrams` root directory across CLI tools, unit tests,
/// `flutter run`, and packaged macOS `.app` bundles.
Directory resolveDiagramsRootDir() {
  if (_customDiagramsRootOverride != null &&
      _customDiagramsRootOverride!.existsSync()) {
    return _customDiagramsRootOverride!;
  }

  final cwd = Directory.current.path;
  final candidates = <String>[
    '$cwd/studio/diagrams',
    '$cwd/diagrams',
    '$cwd/../studio/diagrams',
  ];

  // Also walk up from the running executable or script path (handles macOS .app bundles).
  for (final startPath in <String>[
    Platform.resolvedExecutable,
    Platform.script.toFilePath(),
  ]) {
    try {
      var dir = File(startPath).parent;
      for (var depth = 0; depth < 10; depth++) {
        candidates.add('${dir.path}/studio/diagrams');
        candidates.add('${dir.path}/diagrams');
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    } catch (_) {
      // Ignore path resolution errors on virtual script URIs.
    }
  }

  for (final path in candidates) {
    final dir = Directory(path);
    if (dir.existsSync()) {
      return dir.absolute;
    }
  }

  return Directory('$cwd/studio/diagrams').absolute;
}

/// Default diagram loaded when opening the ad-hoc playground (`studio/diagrams/_default.mmd`).
String get playgroundDefaultSource {
  if (_cachedDefaultSource != null) return _cachedDefaultSource!;
  final root = resolveDiagramsRootDir();
  final defaultFile = File('${root.path}/_default.mmd');
  if (defaultFile.existsSync()) {
    _cachedDefaultSource = defaultFile.readAsStringSync().trimRight();
    return _cachedDefaultSource!;
  }
  return 'flowchart TD\n'
      '  A([Mermaid text]) --> B{Supported?}\n'
      '  B -- Yes --> C[Parse]\n'
      '  B -- No --> H[Fall back]\n\n'
      '  subgraph Pele\n'
      '    C --> D[Layout]\n'
      '    D --> E[Render]\n'
      '  end\n\n'
      '  E --> F[(SVG)]\n'
      '  F -.-> G[Theme with CSS]';
}

/// Returns all diagram families and `.mmd` / `.mermaid` samples discovered under
/// `studio/diagrams/`.
List<DiagramSample> get gallerySamples {
  return _cachedGallerySamples ??= _scanDiagramsRoot(resolveDiagramsRootDir());
}

/// Rescans `studio/diagrams/` (or a custom [rootDir]) on disk and refreshes
/// [gallerySamples] and [playgroundDefaultSource].
List<DiagramSample> reloadGallerySamples({Directory? rootDir}) {
  if (rootDir != null) {
    _customDiagramsRootOverride = rootDir;
  }
  _cachedDefaultSource = null;
  _cachedGallerySamples = _scanDiagramsRoot(resolveDiagramsRootDir());
  return _cachedGallerySamples!;
}

/// Saves a new `.mmd` or `.mermaid` file into `studio/diagrams/03_custom/`
/// (or a specified subfolder) and rescans the gallery.
File saveCustomMermaidDiagram({
  required String fileName,
  required String source,
  String? label,
  String subfolder = '03_custom',
}) {
  final root = resolveDiagramsRootDir();
  final targetDir = Directory('${root.path}/$subfolder')
    ..createSync(recursive: true);
  var cleanName = fileName.trim();
  if (!isMermaidDiagramFile(cleanName)) {
    cleanName = '$cleanName.mmd';
  }
  final file = File('${targetDir.path}/$cleanName');
  final header =
      (label != null && label.trim().isNotEmpty)
          ? '%% label: ${label.trim()}\n'
          : '';
  file.writeAsStringSync('$header${source.trimRight()}\n');
  reloadGallerySamples();
  return file;
}

List<DiagramSample> _scanDiagramsRoot(Directory rootDir) {
  if (!rootDir.existsSync()) return const <DiagramSample>[];

  final results = <DiagramSample>[];
  final topDirs =
      rootDir
          .listSync()
          .whereType<Directory>()
          .where(
            (d) => !d.path.split(Platform.pathSeparator).last.startsWith('.'),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final categoryDir in topDirs) {
    final categoryName = categoryDir.path.split(Platform.pathSeparator).last;

    // Check if this top-level folder directly contains .mmd/.mermaid files (e.g. 03_custom/*.mmd)
    final directMmdFiles =
        categoryDir
            .listSync()
            .whereType<File>()
            .where((f) => isMermaidDiagramFile(f.path))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    if (directMmdFiles.isNotEmpty) {
      final sample = _loadFamilyDirectory(
        categoryDir,
        categoryFolder: categoryName,
        defaultTier:
            categoryName.startsWith('01_')
                ? 1
                : categoryName.startsWith('02_')
                ? 2
                : 3,
      );
      if (sample != null) {
        results.add(sample);
      }
    }

    // Scan family subdirectories inside this category folder (e.g. 01_core/flowchart/)
    final subDirs =
        categoryDir.listSync().whereType<Directory>().where((d) {
            final name = d.path.split(Platform.pathSeparator).last;
            return !name.startsWith('.') && name != 'showcase';
          }).toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    final categorySamples = <DiagramSample>[];
    for (final familyDir in subDirs) {
      final sample = _loadFamilyDirectory(
        familyDir,
        categoryFolder: categoryName,
        defaultTier:
            categoryName.startsWith('01_')
                ? 1
                : categoryName.startsWith('02_')
                ? 2
                : 3,
      );
      if (sample != null) {
        categorySamples.add(sample);
      }
    }

    // Sort within category by beta (non-beta first) then title to match canonical order
    categorySamples.sort((a, b) {
      if (a.beta != b.beta) return a.beta ? 1 : -1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    results.addAll(categorySamples);
  }

  return results;
}

DiagramSample? _loadFamilyDirectory(
  Directory familyDir, {
  required String categoryFolder,
  required int defaultTier,
}) {
  final folderName = familyDir.path.split(Platform.pathSeparator).last;

  // Read optional family.json metadata
  Map<String, dynamic> meta = const <String, dynamic>{};
  final metaFile = File('${familyDir.path}/family.json');
  if (metaFile.existsSync()) {
    try {
      meta = jsonDecode(metaFile.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {
      meta = const <String, dynamic>{};
    }
  }

  final mmdFiles =
      familyDir
          .listSync()
          .whereType<File>()
          .where((f) => isMermaidDiagramFile(f.path))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  if (mmdFiles.isEmpty) return null;

  final playgroundSamples = <PlaygroundSampleItem>[];
  for (final file in mmdFiles) {
    final fileName = file.path.split(Platform.pathSeparator).last;
    final parsed = _parseMermaidFile(file);
    playgroundSamples.add(
      PlaygroundSampleItem(
        label: parsed.label,
        source: parsed.source,
        fileName: fileName,
        filePath: file.path,
      ),
    );
  }

  // Load optional showcase/*.mmd files
  final showcaseSources = <String>[];
  final showcaseDir = Directory('${familyDir.path}/showcase');
  if (showcaseDir.existsSync()) {
    final showcaseFiles =
        showcaseDir
            .listSync()
            .whereType<File>()
            .where((f) => isMermaidDiagramFile(f.path))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in showcaseFiles) {
      showcaseSources.add(_parseMermaidFile(file).source);
    }
  }

  final id = (meta['id'] as String?) ?? folderName;
  final title = (meta['title'] as String?) ?? _humanizeFolderName(folderName);
  final description =
      (meta['description'] as String?) ??
      'Loaded from ${familyDir.path.split(Platform.pathSeparator).reversed.take(2).toList().reversed.join('/')}';
  final diagramType = (meta['diagramType'] as String?) ?? id;
  final beta = (meta['beta'] as bool?) ?? false;
  final tier = (meta['tier'] as int?) ?? defaultTier;
  final primarySource =
      showcaseSources.isNotEmpty
          ? showcaseSources.first
          : playgroundSamples.first.source;

  return DiagramSample(
    id: id,
    title: title,
    description: description,
    diagramType: diagramType,
    beta: beta,
    tier: tier,
    categoryFolder: categoryFolder,
    folderPath: familyDir.path,
    source: primarySource,
    showcaseSources:
        showcaseSources.isNotEmpty
            ? showcaseSources
            : <String>[playgroundSamples.first.source],
    playgroundSamples: playgroundSamples,
  );
}

({String label, String source}) _parseMermaidFile(File file) {
  final raw = file.readAsStringSync().replaceAll('\r\n', '\n');
  final fileName = file.path.split(Platform.pathSeparator).last;
  final lines = raw.split('\n');
  if (lines.isNotEmpty) {
    final first = lines.first.trim();
    final match = RegExp(r'^%%\s*label:\s*(.+)$').firstMatch(first);
    if (match != null) {
      final label = match.group(1)!.trim();
      var body = lines.sublist(1).join('\n');
      if (body.endsWith('\n')) {
        body = body.substring(0, body.length - 1);
      }
      return (label: label, source: body);
    }
  }
  var body = raw;
  if (body.endsWith('\n')) {
    body = body.substring(0, body.length - 1);
  }
  return (label: _humanizeFileName(fileName), source: body);
}

String _humanizeFileName(String fileName) {
  var base = fileName;
  for (final ext in kMermaidFileExtensions) {
    if (base.toLowerCase().endsWith(ext)) {
      base = base.substring(0, base.length - ext.length);
      break;
    }
  }
  return base.replaceAll('_', ' ');
}

String _humanizeFolderName(String folderName) {
  final stripped = folderName.replaceFirst(RegExp(r'^\d+_'), '');
  if (stripped.isEmpty) return folderName;
  return stripped[0].toUpperCase() + stripped.substring(1).replaceAll('_', ' ');
}

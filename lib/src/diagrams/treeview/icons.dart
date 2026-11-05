// Upstream: src/diagrams/treeview/icons.ts

import '../../preprocess.dart';
import 'model.dart';

// Mermaid's name for its built-in pack. Only `file` and `folder` are built in; every other icon
// name is offered to the host's icon resolver.
const String BUILTIN_PACK = 'mermaid-treeview';

// Outlines on a 24 by 24 grid.
const Map<String, String> GLYPHS = <String, String>{
  'folder': 'M3 6.5A1.5 1.5 0 0 1 4.5 5h4.6l2.4 2.5h8A1.5 1.5 0 0 1 21 9v9a1.5 1.5 0 0 1-1.5 1.5h-15A1.5 1.5 0 0 1 3 18z',
  'file': 'M6.5 3h7L19 8.5v11a1.5 1.5 0 0 1-1.5 1.5h-11A1.5 1.5 0 0 1 5 19.5v-15A1.5 1.5 0 0 1 6.5 3zM13.5 3v5.5H19',
};

typedef IconMap = Map<String, Object?>;

class IconConfig {
  final bool showIcons;
  final String defaultIconPack;
  final IconMap? filenameIcons;
  final IconMap? extensionIcons;

  const IconConfig({
    required this.showIcons,
    required this.defaultIconPack,
    this.filenameIcons,
    this.extensionIcons,
  });
}

String? _own(IconMap? map, String key) {
  if (map == null || !map.containsKey(key)) return null;
  final value = map[key];
  return value is String ? value : null;
}

// A file's icon from the configured maps. A file name wins over an extension, and extensions
// match in lower case with or without the leading dot.
String? detectIcon(String name, [IconConfig? config]) {
  final byName = _own(config?.filenameIcons, name);
  if (byName != null && byName.isNotEmpty) return byName;
  final dot = name.lastIndexOf('.');
  if (dot > 0) {
    final ext = name.substring(dot).toLowerCase();
    return _own(config?.extensionIcons, ext) ??
        _own(config?.extensionIcons, ext.substring(1));
  }
  return null;
}

String _qualifyIcon(String icon, String defaultIconPack) {
  if (icon.contains(':')) return icon;
  if (GLYPHS.containsKey(icon) || defaultIconPack.isEmpty) {
    return '$BUILTIN_PACK:$icon';
  }
  return '$defaultIconPack:$icon';
}

// The qualified icon name for a node, or null when it shows none. An `icon()` annotation
// always wins; otherwise icons appear only with `showIcons`.
String? getNodeIcon(TreeNode node, IconConfig config) {
  if (node.icon == 'none') return null;
  if (node.icon != null && node.icon!.isNotEmpty) {
    return _qualifyIcon(node.icon!, config.defaultIconPack);
  }
  if (!config.showIcons) return null;
  if (node.nodeType == 'file') {
    final detected = detectIcon(node.name, config);
    if (detected == 'none') return null;
    if (detected != null && detected.isNotEmpty) {
      return _qualifyIcon(detected, config.defaultIconPack);
    }
  }
  return '$BUILTIN_PACK:${node.nodeType == 'directory' ? 'folder' : 'file'}';
}

IconConfig iconConfig(Config config) {
  IconMap? map(Object? value) {
    if (value is Map) {
      return <String, Object?>{
        for (final entry in value.entries) '${entry.key}': entry.value,
      };
    }
    return null;
  }

  final c = map(config['treeView']) ?? const <String, Object?>{};
  return IconConfig(
    showIcons:
        c['showIcons'] == true ||
        (c['showIcons'] != null &&
            c['showIcons'] != false &&
            c['showIcons'] != '' &&
            c['showIcons'] != 0),
    defaultIconPack: c['defaultIconPack'] is String
        ? c['defaultIconPack'] as String
        : '',
    filenameIcons: map(c['filenameIcons']),
    extensionIcons: map(c['extensionIcons']),
  );
}

// Upstream: src/diagrams/flowchart/db.ts

import '../../errors.dart';
import '../../util/math_js.dart';
import '../../util/url.dart';
import '../../util/yaml.dart';
import 'shapes.dart';
import 'types.dart';

class FlowDbOptions {
  const FlowDbOptions({
    this.maxEdges,
    this.inheritDir,
    this.direction,
    this.warn,
  });

  final int? maxEdges;
  final bool? inheritDir;
  final String? direction;
  final void Function(String message)? warn;
}

LabelType _labelType(String? type) {
  return type == 'markdown' || type == 'string' || type == 'text'
      ? type!
      : 'markdown';
}

String _unquote(String text) {
  return text.length >= 2 && text.startsWith('"') && text.endsWith('"')
      ? text.substring(1, text.length - 1)
      : text;
}

int _countChar(String ch, String str) {
  var count = 0;
  for (var i = 0; i < str.length; i++) {
    if (str[i] == ch) count++;
  }
  return count;
}

FlowLinkInfo _destructStartLink(String raw) {
  var str = raw.trim();
  var type = 'arrow_open';
  switch (charAtOrNull(str, 0)) {
    case '<':
      type = 'arrow_point';
      str = sliceJs(str, 1);
    case 'x':
      type = 'arrow_cross';
      str = sliceJs(str, 1);
    case 'o':
      type = 'arrow_circle';
      str = sliceJs(str, 1);
  }
  var stroke = 'normal';
  if (str.contains('=')) stroke = 'thick';
  if (str.contains('.')) stroke = 'dotted';
  return FlowLinkInfo(type: type, stroke: stroke);
}

FlowLinkInfo _destructEndLink(String raw) {
  final str = raw.trim();
  var line = sliceJs(str, 0, -1);
  var type = 'arrow_open';
  switch (sliceJs(str, -1)) {
    case 'x':
      type = 'arrow_cross';
      if (str.startsWith('x')) {
        type = 'double_$type';
        line = sliceJs(line, 1);
      }
    case '>':
      type = 'arrow_point';
      if (str.startsWith('<')) {
        type = 'double_$type';
        line = sliceJs(line, 1);
      }
    case 'o':
      type = 'arrow_circle';
      if (str.startsWith('o')) {
        type = 'double_$type';
        line = sliceJs(line, 1);
      }
  }
  var stroke = 'normal';
  var length = line.length - 1;
  if (line.startsWith('=')) stroke = 'thick';
  if (line.startsWith('~')) stroke = 'invisible';
  final dots = _countChar('.', line);
  if (dots != 0) {
    stroke = 'dotted';
    length = dots;
  }
  return FlowLinkInfo(type: type, stroke: stroke, length: length);
}

bool _truthy(Object? v) {
  if (v == null || v == false || v == 0 || v == '') return false;
  if (v is double && v.isNaN) return false;
  return true;
}

double _toNumber(Object? v) {
  if (v is num) return v.toDouble();
  if (v is bool) return v ? 1.0 : 0.0;
  return double.tryParse('$v') ?? double.nan;
}

class FlowDb implements FlowchartModel {
  FlowDb([this._options = const FlowDbOptions()]);

  @override
  final String type = 'flowchart';
  @override
  String? direction;
  @override
  final Map<String, FlowNode> nodes = <String, FlowNode>{};
  @override
  final List<FlowEdge> edges = <FlowEdge>[];
  @override
  final List<FlowSubgraph> subgraphs = <FlowSubgraph>[];
  @override
  final Map<String, FlowClassDef> classes = <String, FlowClassDef>{};
  @override
  final Map<String, String> tooltips = <String, String>{};
  @override
  List<String>? defaultEdgeStyle;
  @override
  String? defaultInterpolate;
  @override
  String? title;
  @override
  String? accTitle;
  @override
  String? accDescr;

  final Map<String, FlowSubgraph> _subgraphLookup = <String, FlowSubgraph>{};
  final Set<String> _members = <String>{};
  final Map<String, FlowEdge> _edgeById = <String, FlowEdge>{};
  final Map<String, int> _pairCount = <String, int>{};
  int _subCount = 0;
  final FlowDbOptions _options;

  void addVertex(
    String id, [
    FlowText? textObj,
    String? type,
    List<String>? style,
    List<String>? classes,
    String? dir,
    Map<String, String>? props,
    String? metadata,
  ]) {
    if (id.trim().isEmpty) return;

    Map<String, YamlValue>? doc;
    if (metadata != null) {
      final yaml = metadata.contains('\n') ? '$metadata\n' : '{\n$metadata\n}';
      YamlValue parsed;
      try {
        parsed = parseYaml(yaml);
      } catch (error) {
        final msg = error is StateError ? error.message : '$error';
        throw PeleError(
          'Metadata of "$id" is not valid YAML. $msg',
          'syntax',
          const PeleErrorInfo(type: 'flowchart'),
        );
      }
      if (parsed is Map) {
        doc = <String, YamlValue>{
          for (final entry in parsed.entries) '${entry.key}': entry.value,
        };
      }
    }

    final subgraph = _subgraphLookup[id];
    if (subgraph != null && doc != null) {
      subgraph.metadata = <String, YamlValue>{...?subgraph.metadata, ...doc};
      return;
    }

    final edge = _edgeById[id];
    if (edge != null) {
      if (doc != null && doc.containsKey('animate') && doc['animate'] != null) {
        edge.animate = _truthy(doc['animate']);
      }
      if (doc != null &&
          doc.containsKey('animation') &&
          doc['animation'] != null) {
        edge.animation = '${doc['animation']}';
      }
      if (doc != null && doc.containsKey('curve') && doc['curve'] != null) {
        edge.interpolate = '${doc['curve']}';
      }
      return;
    }

    var vertex = nodes[id];
    if (vertex == null) {
      if (textObj == null && type == null && style != null) {
        _options.warn?.call(
          'Style applied to unknown node "$id". This may indicate a typo. The node will be created automatically.',
        );
      }
      vertex = FlowNode(id: id, labelType: 'text');
      nodes[id] = vertex;
    }

    if (textObj != null) {
      vertex.labelType = textObj.type;
      vertex.text = _unquote(textObj.text.trim());
    } else {
      vertex.text ??= id;
    }
    if (type != null) vertex.type = type;
    if (style != null) {
      for (final s in style) {
        vertex.styles.add(s);
      }
    }
    if (classes != null) {
      for (final c in classes) {
        vertex.classes.add(c);
      }
    }
    if (dir != null) vertex.dir = dir;
    if (vertex.props == null) {
      vertex.props = props != null
          ? Map<String, String>.of(props)
          : <String, String>{};
    } else if (props != null) {
      vertex.props!.addAll(props);
    }

    if (doc == null) return;

    if (_truthy(doc['shape'])) {
      final shape = '${doc['shape']}';
      if (shape != shape.toLowerCase() || shape.contains('_')) {
        throw PeleError(
          'No such shape: $shape. Shape names should be lowercase.',
          'semantic',
          const PeleErrorInfo(type: 'flowchart'),
        );
      }
      if (!isValidShape(shape)) {
        throw PeleError(
          'No such shape: $shape.',
          'semantic',
          const PeleErrorInfo(type: 'flowchart'),
        );
      }
      vertex.type = shape;
    }
    final label = doc['label'] is String ? doc['label'] as String : null;
    if (_truthy(doc['label'])) {
      vertex.text = '${doc['label']}';
      vertex.labelType = _labelType(
        doc['labelType'] is String ? doc['labelType'] as String : null,
      );
    }
    if (_truthy(doc['icon'])) {
      vertex.icon = '${doc['icon']}';
      if ((label == null || label.trim().isEmpty) && vertex.text == id) {
        vertex.text = '';
      }
    }
    if (_truthy(doc['form'])) vertex.form = '${doc['form']}';
    if (_truthy(doc['pos'])) vertex.pos = '${doc['pos']}';
    if (_truthy(doc['img'])) {
      vertex.img = '${doc['img']}';
      if ((label == null || label.trim().isEmpty) && vertex.text == id) {
        vertex.text = '';
      }
    }
    if (_truthy(doc['constraint'])) vertex.constraint = '${doc['constraint']}';
    if (_truthy(doc['w'])) vertex.assetWidth = _toNumber(doc['w']);
    if (_truthy(doc['h'])) vertex.assetHeight = _toNumber(doc['h']);
  }

  void addSingleLink(
    String start,
    String end,
    FlowLinkInfo? type, [
    String? id,
  ]) {
    final edge = FlowEdge(
      start: start,
      end: end,
      text: '',
      labelType: 'text',
      isUserDefinedId: false,
      interpolate: defaultInterpolate,
    );
    final linkText = type?.text;
    if (linkText != null) {
      edge.text = _unquote(linkText.text.trim());
      edge.labelType = _labelType(linkText.type);
    }
    if (type != null) {
      edge.type = type.type;
      edge.stroke = type.stroke;
      final len = type.length;
      edge.length = (len != null && len > 10) ? 10 : len;
    }
    final pair = '$start\u0000$end';
    final count = _pairCount[pair] ?? 0;
    if (id != null && id.isNotEmpty && !_edgeById.containsKey(id)) {
      edge.id = id;
      edge.isUserDefinedId = true;
    } else {
      edge.id = 'L_${start}_${end}_${count == 0 ? 0 : count + 1}';
    }

    final max = _options.maxEdges;
    if (max != null && edges.length >= max) {
      throw PeleError(
        'Edge limit exceeded. The limit is $max.',
        'limit',
        const PeleErrorInfo(type: 'flowchart'),
      );
    }
    edges.add(edge);
    _pairCount[pair] = count + 1;
    if (!_edgeById.containsKey(edge.id!)) _edgeById[edge.id!] = edge;
  }

  void addLink(List<String> starts, List<String> ends, FlowLinkInfo? linkData) {
    final id = linkData?.id?.replaceFirst('@', '');
    final lastStart = starts[starts.length - 1];
    final firstEnd = ends[0];
    for (final start in starts) {
      for (final end in ends) {
        addSingleLink(
          start,
          end,
          linkData,
          start == lastStart && end == firstEnd ? id : null,
        );
      }
    }
  }

  void updateLinkInterpolate(List<Object> positions, String interpolate) {
    for (final pos in positions) {
      if (pos == 'default') {
        defaultInterpolate = interpolate;
      } else {
        _edgeAt(pos).interpolate = interpolate;
      }
    }
  }

  void updateLink(List<Object> positions, List<String> style) {
    for (final pos in positions) {
      if (pos == 'default') {
        defaultEdgeStyle = style;
        continue;
      }
      final edge = _edgeAt(pos);
      edge.style = style;
      if (style.isNotEmpty && !style.any((s) => s.startsWith('fill'))) {
        style.add('fill:none');
      }
    }
  }

  FlowEdge _edgeAt(Object pos) {
    final idx = pos is int ? pos : int.tryParse('$pos');
    final edge = (idx != null && idx >= 0 && idx < edges.length)
        ? edges[idx]
        : null;
    if (edge == null) {
      throw PeleError(
        'The index $pos for linkStyle is out of bounds. Valid indices for linkStyle are between 0 and ${edges.length - 1}. (Help: Ensure that the index is within the range of existing edges.)',
        'semantic',
        const PeleErrorInfo(type: 'flowchart'),
      );
    }
    return edge;
  }

  void addClass(String ids, List<String> styles) {
    final style = styles
        .join(',')
        .replaceAll(r'\,', '§§§')
        .replaceAll(',', ';')
        .replaceAll('§§§', ',')
        .split(';');
    for (final id in ids.split(',')) {
      var classNode = classes[id];
      if (classNode == null) {
        classNode = FlowClassDef(id: id);
        classes[id] = classNode;
      }
      for (final s in style) {
        if (s.contains('color')) {
          classNode.textStyles.add(s.replaceFirst('fill', 'bgFill'));
        }
        classNode.styles.add(s);
      }
    }
  }

  void setDirection(String dir) {
    var d = dir.trim();
    if (d.contains('<')) d = 'RL';
    if (d.contains('^')) d = 'BT';
    if (d.contains('>')) d = 'LR';
    if (d.contains('v')) d = 'TB';
    if (d == 'TD') d = 'TB';
    direction = d;
  }

  void setClass(String ids, String className) {
    for (final id in ids.split(',')) {
      nodes[id]?.classes.add(className);
      _edgeById[id]?.classes.add(className);
      _subgraphLookup[id]?.classes.add(className);
    }
  }

  void setTooltip(String ids, String? tooltip) {
    if (tooltip == null) return;
    for (final id in ids.split(',')) {
      tooltips[id] = tooltip;
    }
  }

  void setLink(String ids, String link, [String? target]) {
    final url = link.trim();
    for (final id in ids.split(',')) {
      final vertex = nodes[id];
      if (vertex != null) {
        vertex.link = url.isNotEmpty ? safeUrl(url) : null;
        vertex.linkTarget = target;
      }
    }
    setClass(ids, 'clickable');
  }

  // Callbacks are never executed; the node is only marked clickable, as in Mermaid's strict mode.
  void setClickEvent(String ids, [String? functionName, String? functionArgs]) {
    setClass(ids, 'clickable');
  }

  void setAccTitle(String text) {
    accTitle = text.replaceAll(RegExp(r'^\s+'), '');
  }

  void setAccDescription(String text) {
    accDescr = text.replaceAll(RegExp(r'\n\s+'), '\n');
  }

  String addSubGraph(
    FlowText? idText,
    List<DocItem> list,
    FlowText? titleText,
  ) {
    var id = idText?.text.trim();
    final title = titleText?.text ?? '';
    if (idText != null &&
        identical(idText, titleText) &&
        RegExp(r'\s').hasMatch(title)) {
      id = null;
    }

    final seen = <String>{};
    final nodeList = <String>[];
    String? dir;
    for (final entry in list) {
      if (entry is String) {
        if (entry.trim().isNotEmpty && !seen.contains(entry)) {
          seen.add(entry);
          nodeList.add(entry);
        }
      } else if (entry is List<String>) {
        for (final item in entry) {
          if (item.trim().isNotEmpty && !seen.contains(item)) {
            seen.add(item);
            nodeList.add(item);
          }
        }
      } else if (entry is DirStmt) {
        dir = entry.value;
      }
    }
    dir ??= _options.inheritDir == true
        ? (direction ?? _options.direction)
        : null;

    id ??= 'subGraph$_subCount';
    _subCount++;

    final subgraph = FlowSubgraph(
      id: id,
      nodes: nodeList,
      title: title.trim(),
      dir: dir,
      labelType: _labelType(titleText?.type),
    );
    // A node belongs to the first subgraph that lists it, and a subgraph never contains itself.
    subgraph.nodes = nodeList
        .where((nodeId) => !_members.contains(nodeId) && nodeId != id)
        .toList();
    for (final nodeId in subgraph.nodes) {
      _members.add(nodeId);
    }

    final existing = _subgraphLookup[id];
    if (existing != null) {
      for (final nodeId in subgraph.nodes) {
        existing.nodes.add(nodeId);
      }
    } else {
      subgraphs.add(subgraph);
    }
    _subgraphLookup[id] = existing ?? subgraph;
    return id;
  }

  bool exists(List<FlowSubgraph> all, String id) {
    for (final sg in all) {
      if (sg.nodes.contains(id)) return true;
    }
    return false;
  }

  ({List<String> nodes}) makeUniq(FlowSubgraph sg, List<FlowSubgraph> all) {
    final taken = <String>{};
    for (final other in all) {
      for (final id in other.nodes) {
        taken.add(id);
      }
    }
    return (nodes: sg.nodes.where((id) => !taken.contains(id)).toList());
  }

  FlowLinkInfo destructLink(String end, [String? start]) {
    final info = _destructEndLink(end);
    if (start == null || start.isEmpty) return info;
    final startInfo = _destructStartLink(start);
    if (startInfo.stroke != info.stroke) {
      return FlowLinkInfo(type: 'INVALID', stroke: 'INVALID');
    }
    if (startInfo.type == 'arrow_open') {
      startInfo.type = info.type;
    } else {
      if (startInfo.type != info.type) {
        return FlowLinkInfo(type: 'INVALID', stroke: 'INVALID');
      }
      startInfo.type = 'double_${startInfo.type}';
    }
    if (startInfo.type == 'double_arrow') {
      startInfo.type = 'double_arrow_point';
    }
    startInfo.length = info.length;
    return startInfo;
  }

  FlowSubgraph? subgraph(String id) {
    return _subgraphLookup[id];
  }
}

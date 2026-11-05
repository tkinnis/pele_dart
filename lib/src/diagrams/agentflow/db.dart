// Upstream: src/diagrams/agentflow/db.ts

import 'dart:convert';
import 'dart:math' as math;

import '../../errors.dart';
import '../../util/math_js.dart';
import '../../util/url.dart';
import '../../util/yaml.dart';
import 'shapes.dart';
import 'types.dart';

class AgentflowDbOptions {
  const AgentflowDbOptions({
    this.maxEdges,
    this.inheritDir,
    this.direction,
    this.lineOffset,
    this.source,
    this.log,
  });

  final int? maxEdges;
  final bool? inheritDir;
  final String? direction;
  // Lines of front matter before the text the parser sees, added to every reported line.
  final int? lineOffset;
  // The text the parser sees, where errors are located.
  final String? source;
  final void Function(String severity, String message)? log;
}

// Presentation-only metadata keys, left out of the semantic model.
const Set<String> _presentationKeys = <String>{
  'shape',
  'view',
  'icon',
  'img',
  'form',
  'pos',
  'w',
  'h',
  'class',
  'style',
  'labelType',
};

const Set<String> _toolShapes = <String>{
  'subroutine',
  'subprocess',
  'subproc',
  'framed-rectangle',
  'tool',
};

bool isToolDefinition(AgentNode vertex) {
  return vertex.type != null && _toolShapes.contains(vertex.type);
}

LabelType _labelType(Object? type) {
  return type == 'markdown' || type == 'string' || type == 'text'
      ? type as String
      : 'markdown';
}

String _unquote(String text) {
  return text.length >= 2 && text.startsWith('"') && text.endsWith('"')
      ? text.substring(1, text.length - 1)
      : text;
}

bool _isObject(Object? value) {
  return value is Map;
}

bool _isTruthy(Object? value) {
  return value != null &&
      value != false &&
      value != 0 &&
      value != '' &&
      !(value is double && value.isNaN);
}

// Drops `__proto__`, `constructor` and `prototype` keys at every level, so that a consumer
// merging metadata into its own objects cannot be made to pollute a prototype.
YamlValue _stripPrototypeKeys(YamlValue root) {
  YamlValue copy(YamlValue value) => value is List
      ? <YamlValue>[]
      : (_isObject(value) ? <String, YamlValue>{} : value);
  final out = copy(root);
  final pending = <(YamlValue, YamlValue)>[(root, out)];
  while (pending.isNotEmpty) {
    final (from, to) = pending.removeLast();
    if (from is List) {
      final toList = to as List<YamlValue>;
      for (final entry in from) {
        final next = copy(entry);
        toList.add(next);
        if (entry is List || _isObject(entry)) {
          pending.add((entry, next));
        }
      }
    } else if (from is Map) {
      final toMap = to as Metadata;
      for (final rawKey in from.keys) {
        final key = '$rawKey';
        if (key == '__proto__' || key == 'constructor' || key == 'prototype') {
          continue;
        }
        final entry = from[rawKey];
        final next = copy(entry);
        toMap[key] = next;
        if (entry is List || _isObject(entry)) {
          pending.add((entry, next));
        }
      }
    }
  }
  return out;
}

// Adds what a metadata block holds to an element's metadata. Mermaid spreads the parsed YAML
// whatever it is, so a list adds its indexes as keys and a string its characters.
Metadata _merge(Metadata? into, YamlValue doc) {
  final target = into ?? <String, YamlValue>{};
  if (doc is Map) {
    for (final entry in doc.entries) {
      target['${entry.key}'] = entry.value;
    }
  } else if (doc is List) {
    for (var i = 0; i < doc.length; i++) {
      target['$i'] = doc[i];
    }
  } else if (doc is String) {
    for (var i = 0; i < doc.length; i++) {
      target['$i'] = doc[i];
    }
  }
  return target;
}

final RegExp _reBlockScalar = RegExp(r':\s*[>|][\d+-]*\s*$');
final RegExp _reTrailingComma = RegExp(r',([\t ]*)$');

// Removes the comma that ends a line of a multi-line metadata body, which block YAML does not allow.
// Commas inside quoted scalars, flow collections and block scalars are content and stay.
String _stripLineTrailingCommas(String body) {
  var inSingle = false;
  var inDouble = false;
  var flowDepth = 0;
  int? blockScalarIndent;
  final out = <String>[];
  for (final line in body.split('\n')) {
    if (blockScalarIndent != null) {
      final indent = line.length - line.trimLeft().length;
      if (line.trim().isEmpty || indent > blockScalarIndent) {
        out.add(line);
        continue;
      }
      blockScalarIndent = null;
    }
    var commentStart = -1;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (inDouble) {
        if (ch == r'\') {
          i++;
        } else if (ch == '"') {
          inDouble = false;
        }
      } else if (inSingle) {
        if (ch == "'") inSingle = false;
      } else if (ch == '"') {
        inDouble = true;
      } else if (ch == "'") {
        inSingle = true;
      } else if (ch == '#' &&
          (i == 0 || line[i - 1] == ' ' || line[i - 1] == '\t')) {
        commentStart = i;
        break;
      } else if (ch == '[' || ch == '{') {
        flowDepth++;
      } else if (ch == ']' || ch == '}') {
        flowDepth = math.max<int>(0, flowDepth - 1);
      }
    }
    if (inSingle || inDouble || flowDepth > 0) {
      out.add(line);
      continue;
    }
    final code = commentStart >= 0 ? line.substring(0, commentStart) : line;
    final comment = commentStart >= 0 ? line.substring(commentStart) : '';
    if (_reBlockScalar.hasMatch(code)) {
      blockScalarIndent = line.length - line.trimLeft().length;
      out.add(line);
      continue;
    }
    out.add(
      code.replaceFirstMapped(_reTrailingComma, (m) => m.group(1)!) + comment,
    );
  }
  return out.join('\n');
}

EdgeSemantic? _edgeSemantic(String type, String stroke) {
  if (type == 'arrow_point' && stroke == 'normal') return 'sequence';
  if (type == 'arrow_cross' && stroke == 'normal') return 'failure';
  if (type == 'arrow_open' && stroke == 'dotted') return 'reference';
  return null;
}

({String type, String stroke, int length}) _destructEndLink(String raw) {
  final str = raw.trim();
  var line = sliceJs(str, 0, -1);
  var type = 'arrow_open';
  switch (sliceJs(str, -1)) {
    case 'x':
      type = 'arrow_cross';
    case '>':
      type = 'arrow_point';
    case '-':
    case '.':
      line = str;
  }
  var stroke = 'normal';
  var length = line.length - 1;
  var dots = 0;
  for (var i = 0; i < line.length; i++) {
    if (line[i] == '.') dots++;
  }
  if (dots > 0) {
    stroke = 'dotted';
    length = dots;
  }
  return (type: type, stroke: stroke, length: length);
}

Metadata? _semanticMetadata(Metadata? metadata) {
  if (metadata == null) return null;
  final out = <String, YamlValue>{};
  var any = false;
  for (final key in metadata.keys) {
    if (_presentationKeys.contains(key)) continue;
    out[key] = metadata[key];
    any = true;
  }
  return any ? out : null;
}

class AgentflowDb implements AgentflowModel, ShapeSink {
  AgentflowDb([AgentflowDbOptions options = const AgentflowDbOptions()])
    : _options = options,
      lineOffset = options.lineOffset ?? 0;

  @override
  final String type = 'agentflow';
  @override
  String? direction;
  @override
  final Map<String, AgentNode> nodes = <String, AgentNode>{};
  @override
  final List<AgentEdge> edges = <AgentEdge>[];
  @override
  final List<AgentSubgraph> subgraphs = <AgentSubgraph>[];
  @override
  final Map<String, AgentNode> connectors = <String, AgentNode>{};
  @override
  final Map<String, AgentClassDef> classes = <String, AgentClassDef>{};
  @override
  final Map<String, String> tooltips = <String, String>{};
  @override
  List<String>? defaultEdgeStyle;
  @override
  String? defaultInterpolate;
  @override
  final List<ElementMapping> mappings = <ElementMapping>[];
  @override
  final List<Diagnostic> diagnostics = <Diagnostic>[];
  @override
  String? title;
  @override
  String? accTitle;
  @override
  String? accDescr;
  int lineOffset;

  final Map<String, AgentSubgraph> _subgraphLookup = <String, AgentSubgraph>{};
  final Set<String> _globalNodes = <String>{};
  final Set<String> _members = <String>{};
  final Map<String, AgentEdge> _edgeById = <String, AgentEdge>{};
  final Map<String, int> _pairCount = <String, int>{};
  int _subCount = 0;
  final Set<ElementMapping> _bareMappings = <ElementMapping>{};
  final Map<String, ElementMapping> _firstMapping = <String, ElementMapping>{};
  final Map<String, List<Diagnostic>> _reported = <String, List<Diagnostic>>{};
  final AgentflowDbOptions _options;

  YamlValue _metadata(String id, String source, Loc? loc) {
    final multiline = source.contains('\n');
    YamlValue parsed;
    try {
      parsed = parseYaml(multiline ? '$source\n' : '{\n$source\n}');
    } catch (error) {
      // Block YAML rejects the comma-separated style of the single-line form, so try once more without the commas.
      final stripped = multiline ? _stripLineTrailingCommas(source) : source;
      YamlValue retried;
      var hasRetried = false;
      if (stripped != source) {
        try {
          retried = parseYaml('$stripped\n');
          hasRetried = true;
        } catch (_) {
          hasRetried = false;
        }
      }
      if (!hasRetried) {
        final (:line, :column) = _errorAt(loc);
        final at = loc != null ? ' ($line:$column)' : '';
        final msg = error is StateError ? error.message : '$error';
        throw PeleError(
          'Metadata of "$id" is not valid YAML. $msg$at',
          'syntax',
          PeleErrorInfo(type: 'agentflow', line: line, column: column),
        );
      }
      parsed = retried;
    }
    return _stripPrototypeKeys(parsed ?? <String, YamlValue>{});
  }

  ({int line, int column}) _errorAt(Loc? loc) {
    if (loc == null) return (line: 0, column: 0);
    final source = _options.source;
    if (source == null) {
      return (line: loc.first_line + lineOffset, column: loc.first_column + 1);
    }
    var start = 0;
    for (var line = 1; line < loc.first_line; line++) {
      start = source.indexOf('\n', start) + 1;
    }
    final located = locate(source, start + loc.first_column);
    return (line: located.line, column: located.column);
  }

  PeleError _shapeError(String message, Loc? loc) {
    final (:line, :column) = _errorAt(loc);
    return PeleError(
      message,
      'semantic',
      PeleErrorInfo(type: 'agentflow', line: line, column: column),
    );
  }

  void addVertex(
    String id, [
    FlowText? textObj,
    String? type,
    List<String>? style,
    List<String>? classes,
    String? dir,
    Map<String, String>? props,
    String? metadata,
    Loc? metadataLoc,
  ]) {
    if (id.isEmpty || id.trim().isEmpty) return;

    YamlValue doc;
    var hasDoc = false;
    Metadata? fields;
    String? authoredShape;
    if (metadata != null) {
      doc = _metadata(id, metadata, metadataLoc);
      hasDoc = _isTruthy(doc);
      if (doc is Map<String, YamlValue>) {
        fields = doc;
        final rawShape = doc['shape'];
        if (rawShape is String) {
          authoredShape = rawShape;
          doc['shape'] = resolveShapeAlias(rawShape)!;
        }
      }
    }

    final sg = _subgraphLookup[id];
    if (sg != null && hasDoc) {
      sg.metadata = _merge(sg.metadata, doc);
      return;
    }

    final connector = connectors[id];
    if (connector != null && hasDoc) {
      connector.metadata = _merge(connector.metadata, doc);
      return;
    }

    // Mermaid reserves this id and creates no node for it.
    if (id == 'connectors') return;

    final edge = _edgeById[id];
    if (edge != null) {
      if (fields != null) {
        if (fields.containsKey('animate') && fields['animate'] != null) {
          edge.animate = fields['animate'];
        }
        if (fields.containsKey('animation') && fields['animation'] != null) {
          edge.animation = fields['animation'];
        }
        if (fields.containsKey('curve') && fields['curve'] != null) {
          edge.interpolate = '${fields['curve']}';
        }
      }
      if (hasDoc) edge.metadata = _merge(edge.metadata, doc);
      return;
    }

    var vertex = nodes[id];
    if (vertex == null) {
      vertex = AgentNode(
        id: id,
        labelType: 'text',
        styles: <String>[],
        classes: <String>[],
      );
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
    final effProps = props ?? <String, String>{};
    if (vertex.props == null) {
      vertex.props = effProps;
    } else if (props != null) {
      vertex.props!.addAll(props);
    }

    if (!hasDoc) return;
    vertex.metadata = _merge(vertex.metadata, doc);
    if (fields == null) return;

    if (_isTruthy(fields['shape'])) {
      final authored = authoredShape ?? fields['shape'];
      if (authored is! String) {
        throw _shapeError(
          'No such shape: ${jsonEncode(authored)}.',
          metadataLoc,
        );
      }
      if (authored != authored.toLowerCase() || authored.contains('_')) {
        throw _shapeError(
          'No such shape: $authored. Shape names should be lowercase.',
          metadataLoc,
        );
      }
      final shape = fields['shape'] as String;
      if (!isValidShape(shape)) {
        throw _shapeError('No such shape: $shape.', metadataLoc);
      }
      vertex.type = shape;
    }
    if (_isTruthy(fields['label'])) {
      vertex.text = '${fields['label']}';
      vertex.labelType = _labelType(fields['labelType']);
    }
  }

  void addSingleLink(
    String start,
    String end,
    AgentLinkInfo? type, [
    String? id,
  ]) {
    final edge = AgentEdge(
      start: start,
      end: end,
      type: null,
      text: '',
      labelType: 'text',
      classes: <String>[],
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
      if (type.edgeSemantic != null && type.edgeSemantic!.isNotEmpty) {
        edge.edgeSemantic = type.edgeSemantic;
      }
    }
    final pair = '$start\u0000$end';
    final existing = _pairCount[pair] ?? 0;
    if (id != null && id.isNotEmpty && !_edgeById.containsKey(id)) {
      edge.id = id;
      edge.isUserDefinedId = true;
    } else {
      edge.id = 'L_${start}_${end}_${existing == 0 ? 0 : existing + 1}';
    }

    final max = _options.maxEdges;
    if (max != null && edges.length >= max) {
      throw PeleError(
        'Edge limit exceeded. The limit is $max.',
        'limit',
        const PeleErrorInfo(type: 'agentflow'),
      );
    }
    edges.add(edge);
    _pairCount[pair] = existing + 1;
    if (!_edgeById.containsKey(edge.id!)) {
      _edgeById[edge.id!] = edge;
    }
  }

  void addLink(
    List<String> starts,
    List<String> ends,
    AgentLinkInfo? linkData,
  ) {
    final rawId = linkData?.id;
    final id = rawId?.replaceFirst('@', '');
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

  // Mermaid checks the bounds only for a numeric index and crashes on the strings its own parser passes.
  AgentEdge _edgeAt(Object pos) {
    final idx = pos is int
        ? pos
        : (pos is num ? pos.toInt() : int.tryParse('$pos'.trim()));
    final edge = (idx != null && idx >= 0 && idx < edges.length)
        ? edges[idx]
        : null;
    if (edge == null) {
      throw PeleError(
        'The index $pos for linkStyle is out of bounds. Valid indices for linkStyle are between 0 and ${edges.length - 1}. (Help: Ensure that the index is within the range of existing edges.)',
        'semantic',
        const PeleErrorInfo(type: 'agentflow'),
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
        classNode = AgentClassDef(
          id: id,
          styles: <String>[],
          textStyles: <String>[],
        );
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
    FlowText? titleText, [
    String? sgType,
  ]) {
    String? id = idText?.text.trim();
    final title = (titleText != null && titleText.text.isNotEmpty)
        ? titleText.text
        : '';
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

    // A flow never contains itself, a globally scoped node, or a node another flow already holds.
    final members = _members;
    final filteredNodes = nodeList
        .where(
          (nodeId) =>
              nodeId != id &&
              !_globalNodes.contains(nodeId) &&
              !members.contains(nodeId),
        )
        .toList();
    for (final nodeId in filteredNodes) {
      members.add(nodeId);
    }

    final existing = _subgraphLookup[id];
    if (existing != null) {
      // A repeated id adds its members to the first flow; its title and direction win.
      for (final nodeId in filteredNodes) {
        existing.nodes.add(nodeId);
      }
      if (title.trim().isNotEmpty) existing.title = title.trim();
      if (dir != null && dir.isNotEmpty) existing.dir = dir;
      return id;
    }
    final sg = AgentSubgraph(
      id: id,
      nodes: filteredNodes,
      title: title.trim(),
      classes: <String>[],
      dir: dir,
      labelType: _labelType(titleText?.type),
      type: 'flow',
    );
    subgraphs.add(sg);
    _subgraphLookup[id] = sg;
    return id;
  }

  // Every node named inside a `global` block stays out of the flows that mention it.
  void addGlobal(List<DocItem> list) {
    var release = false;
    void add(String item) {
      final id = item.trim();
      if (id.isEmpty) return;
      _globalNodes.add(id);
      if (_members.remove(id)) release = true;
    }

    for (final entry in list) {
      if (entry is String) {
        add(entry);
      } else if (entry is List<String>) {
        for (final item in entry) {
          add(item);
        }
      }
    }
    if (!release) return;
    for (final sg in subgraphs) {
      sg.nodes = sg.nodes
          .where((nodeId) => !_globalNodes.contains(nodeId))
          .toList();
    }
  }

  String addConnector(FlowText? textObj, [FlowText? titleObj]) {
    final id = textObj?.text.trim();
    if (id == null || id.isEmpty) return '';
    final title = titleObj?.text.trim() ?? '';
    final connector = connectors[id];
    if (connector == null) {
      final created = AgentNode(
        id: id,
        labelType: 'text',
        styles: <String>[],
        classes: <String>[],
        isConnector: true,
        text: title.isNotEmpty ? title : id,
      );
      connectors[id] = created;
      nodes[id] = created;
    } else if (title.isNotEmpty) {
      connector.text = title;
    }
    return id;
  }

  AgentLinkInfo destructLink(String end, [String? start]) {
    final info = _destructEndLink(end);
    if (start != null && start.isNotEmpty) {
      // The first half of a split arrow only says whether the line is dotted.
      final stroke = start.contains('.') ? 'dotted' : 'normal';
      if (stroke != info.stroke) {
        return AgentLinkInfo(type: 'INVALID', stroke: 'INVALID');
      }
    }
    return AgentLinkInfo(
      type: info.type,
      stroke: info.stroke,
      length: info.length,
      edgeSemantic: _edgeSemantic(info.type, info.stroke),
    );
  }

  AgentSubgraph? subgraph(String id) {
    return _subgraphLookup[id];
  }

  VertexKind vertexKind(AgentNode vertex) {
    if (isToolDefinition(vertex)) return 'tool';
    final shape = resolveShapeAlias(vertex.type);
    if (shape == 'hexagon' || shape == 'hex') return 'action';
    if (shape == 'lean-right' || shape == 'lean_right') return 'input';
    if (shape == 'lin-doc' || shape == 'lined-document') return 'refdoc';
    if (shape == 'diamond') return 'decision';
    return 'task';
  }

  @override
  SemanticModel semanticModel() {
    final vertices = <SemanticVertex>[];
    final semanticConnectors = <SemanticConnector>[];
    for (final entry in nodes.entries) {
      final id = entry.key;
      final v = entry.value;
      if (_subgraphLookup.containsKey(id)) continue;
      final metadata = _semanticMetadata(v.metadata);
      if (v.isConnector == true) {
        final connector = SemanticConnector(id: id);
        if (v.text != null && v.text != id) connector.title = v.text;
        if (metadata != null) connector.metadata = metadata;
        semanticConnectors.add(connector);
        continue;
      }
      final vertex = SemanticVertex(id: id);
      if (v.text != null) vertex.label = v.text;
      final shape = resolveShapeAlias(v.type);
      if (shape != null) vertex.shape = shape;
      vertex.vertexKind = vertexKind(v);
      if (metadata != null) vertex.metadata = metadata;
      vertices.add(vertex);
    }

    final semanticEdges = edges.map((e) {
      final edge = SemanticEdge(start: e.start, end: e.end);
      if (e.id != null) edge.id = e.id;
      if (e.text.isNotEmpty) edge.label = e.text;
      if (e.type != null) edge.type = e.type;
      if (e.stroke != null) edge.stroke = e.stroke;
      if (e.edgeSemantic != null) edge.edgeSemantic = e.edgeSemantic;
      if (e.length != null) edge.length = e.length;
      if (e.metadata != null && e.metadata!.isNotEmpty) {
        edge.metadata = <String, YamlValue>{...e.metadata!};
      }
      return edge;
    }).toList();

    final subGraphs = subgraphs.map((sg) {
      final out = SemanticSubgraph(
        id: sg.id,
        nodes: <String>[...sg.nodes],
        type: sg.type,
        title: sg.title,
      );
      if (sg.dir != null) out.direction = sg.dir;
      final metadata = _semanticMetadata(sg.metadata);
      if (metadata != null) out.metadata = metadata;
      return out;
    }).toList();

    return SemanticModel(
      direction: direction,
      vertices: vertices,
      edges: semanticEdges,
      subGraphs: subGraphs,
      connectors: semanticConnectors,
      diagnostics: diagnostics,
    );
  }

  ElementPosition _position(Loc? loc) {
    final startLine = loc?.first_line ?? 0;
    final startColumn = loc?.first_column ?? 0;
    return ElementPosition(
      startLine: startLine + lineOffset,
      startColumn: startColumn,
      endLine: (loc?.last_line ?? startLine) + lineOffset,
      endColumn: loc?.last_column ?? startColumn,
      // Mermaid builds its parser without ranges, so these are always zero.
      startIndex: 0,
      endIndex: 0,
    );
  }

  ElementMapping _pushMapping(
    String id,
    StatementType type,
    ElementPosition position,
  ) {
    final mapping = ElementMapping(id: id, type: type, position: position);
    mappings.add(mapping);
    if (!_firstMapping.containsKey(id)) _firstMapping[id] = mapping;
    return mapping;
  }

  void addVertexMapping(String id, Object? text, Object? shape, Loc? loc) {
    if (id.isEmpty) return;
    final mapping = _pushMapping(id, 'vertex', _position(loc));
    // A bare reference becomes an attachment if a metadata block follows it.
    if (shape == null) _bareMappings.add(mapping);
  }

  // Widens a node's span over the metadata block that follows it.
  void extendVertexMapping(String id, Loc? loc) {
    if (id.isEmpty || loc == null) return;
    final end = _position(loc);
    for (var i = mappings.length - 1; i >= 0; i--) {
      final m = mappings[i];
      if (m.type != 'vertex' || m.id != id) continue;
      if (_bareMappings.remove(m)) m.type = 'attachment';
      final p = m.position;
      if (end.endLine > p.endLine ||
          (end.endLine == p.endLine && end.endColumn > p.endColumn)) {
        p.endLine = end.endLine;
        p.endColumn = end.endColumn;
      }
      return;
    }
    _pushMapping(id, 'attachment', end);
  }

  void addEdgeMapping(Object? from, Object? toNodes, Object? link, Loc? loc) {
    final ids = toNodes is List
        ? toNodes.whereType<String>().where((n) => n.isNotEmpty).toList()
        : <String>[];
    _pushMapping(
      ids.isNotEmpty ? ids.join('>') : 'edge',
      'edge',
      _position(loc),
    );
  }

  void _blockMapping(
    String id,
    StatementType type,
    Loc? startLoc,
    Loc? endLoc,
  ) {
    if (id.isEmpty) return;
    final start = _position(startLoc);
    final end = endLoc != null ? _position(endLoc) : start;
    _pushMapping(
      id,
      type,
      ElementPosition(
        startLine: start.startLine,
        startColumn: start.startColumn,
        endLine: end.endLine,
        endColumn: end.endColumn,
        startIndex: 0,
        endIndex: 0,
      ),
    );
  }

  void addSubgraphMapping(
    Object? id,
    Object? title,
    Loc? startLoc,
    Loc? endLoc,
  ) {
    final text = id is String ? id : (id is FlowText ? id.text : null);
    _blockMapping(text ?? '', 'subgraph', startLoc, endLoc);
  }

  void addConnectorMapping(
    FlowText? textObj,
    Object? title,
    Loc? startLoc,
    Loc? endLoc,
  ) {
    _blockMapping(textObj?.text.trim() ?? '', 'connector', startLoc, endLoc);
  }

  void _emit(
    DiagnosticId id,
    String severity,
    String message,
    ({String? nodeId, String? edgeId})? ctx,
  ) {
    final anchor = ctx?.nodeId ?? ctx?.edgeId;
    final diagnostic = Diagnostic(id: id, severity: severity, message: message);
    if (ctx?.nodeId != null && ctx!.nodeId!.isNotEmpty) {
      diagnostic.nodeId = ctx.nodeId;
    } else if (ctx?.edgeId != null && ctx!.edgeId!.isNotEmpty) {
      diagnostic.edgeId = ctx.edgeId;
    }
    final mapping = (anchor != null && anchor.isNotEmpty)
        ? _firstMapping[anchor]
        : null;
    if (mapping != null) diagnostic.position = mapping.position;

    // The graph may be built more than once; each finding is recorded once.
    final key = anchor ?? '';
    final same = _reported[key];
    if (same == null) {
      _reported[key] = <Diagnostic>[diagnostic];
    } else {
      for (final d in same) {
        if (d.id == id &&
            d.severity == severity &&
            d.message == message &&
            d.nodeId == diagnostic.nodeId &&
            d.edgeId == diagnostic.edgeId) {
          return;
        }
      }
      same.add(diagnostic);
    }
    diagnostics.add(diagnostic);
    _options.log?.call(severity, 'agentflow[$id]: $message');
  }

  @override
  void emitWarning(
    DiagnosticId id,
    String message, [
    ({String? nodeId, String? edgeId})? ctx,
  ]) {
    _emit(id, 'warning', message, ctx);
  }

  @override
  void emitError(
    DiagnosticId id,
    String message, [
    ({String? nodeId, String? edgeId})? ctx,
  ]) {
    _emit(id, 'error', message, ctx);
  }
}

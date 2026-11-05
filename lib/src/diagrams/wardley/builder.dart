// Upstream: src/diagrams/wardley/builder.ts

import '../../errors.dart';

typedef SourceStrategy = String;
typedef Flow = String;

// Coordinates are percentages: x is evolution, y is visibility.
class WardleyNode {
  final String id;
  final String label;
  double? x;
  double? y;
  // 'anchor', 'component', or 'pipeline-component'
  String? className;
  double? labelOffsetX;
  double? labelOffsetY;
  bool? inPipeline;
  bool? isPipelineParent;
  bool? inertia;
  SourceStrategy? sourceStrategy;

  WardleyNode({
    required this.id,
    required this.label,
    this.x,
    this.y,
    this.className,
    this.labelOffsetX,
    this.labelOffsetY,
    this.inPipeline,
    this.isPipelineParent,
    this.inertia,
    this.sourceStrategy,
  });
}

class WardleyLink {
  final String source;
  final String target;
  final bool? dashed;
  final String? label;
  final Flow? flow;

  const WardleyLink({
    required this.source,
    required this.target,
    this.dashed,
    this.label,
    this.flow,
  });
}

class WardleyTrend {
  final String nodeId;
  final double targetX;
  final double targetY;

  const WardleyTrend({
    required this.nodeId,
    required this.targetX,
    required this.targetY,
  });
}

class WardleyPipeline {
  final String nodeId;
  final List<String> componentIds;

  WardleyPipeline({required this.nodeId, List<String>? componentIds})
    : componentIds = componentIds ?? <String>[];
}

class WardleyPoint {
  final double x;
  final double y;

  const WardleyPoint({required this.x, required this.y});
}

class WardleyAnnotation {
  final int number;
  final List<WardleyPoint> coordinates;
  final String? text;

  const WardleyAnnotation({
    required this.number,
    required this.coordinates,
    this.text,
  });
}

class WardleyNote {
  final String text;
  final double x;
  final double y;

  const WardleyNote({required this.text, required this.x, required this.y});
}

class WardleyForce {
  final String name;
  final double x;
  final double y;

  const WardleyForce({required this.name, required this.x, required this.y});
}

class WardleyAxesConfig {
  final String? xLabel;
  final String? yLabel;
  final List<String>? stages;
  // Right edge of each stage, from 0 to 1.
  final List<double>? stageBoundaries;

  const WardleyAxesConfig({
    this.xLabel,
    this.yLabel,
    this.stages,
    this.stageBoundaries,
  });

  WardleyAxesConfig merge(WardleyAxesConfig partial) => WardleyAxesConfig(
    xLabel: partial.xLabel ?? xLabel,
    yLabel: partial.yLabel ?? yLabel,
    stages: partial.stages ?? stages,
    stageBoundaries: partial.stageBoundaries ?? stageBoundaries,
  );
}

class WardleySize {
  final double width;
  final double height;

  const WardleySize({required this.width, required this.height});
}

class WardleyBuildResult {
  final List<WardleyNode> nodes;
  final List<WardleyLink> links;
  final List<WardleyTrend> trends;
  final List<WardleyPipeline> pipelines;
  final List<WardleyAnnotation> annotations;
  final List<WardleyNote> notes;
  final List<WardleyForce> accelerators;
  final List<WardleyForce> deaccelerators;
  final WardleyPoint? annotationsBox;
  final WardleyAxesConfig axes;
  final WardleySize? size;

  const WardleyBuildResult({
    required this.nodes,
    required this.links,
    required this.trends,
    required this.pipelines,
    required this.annotations,
    required this.notes,
    required this.accelerators,
    required this.deaccelerators,
    this.annotationsBox,
    required this.axes,
    this.size,
  });
}

class WardleyBuilder {
  final Map<String, WardleyNode> _nodes = <String, WardleyNode>{};
  Map<String, String>? _labels;
  final List<WardleyLink> _links = <WardleyLink>[];
  final Map<String, WardleyTrend> _trends = <String, WardleyTrend>{};
  final Map<String, WardleyPipeline> _pipelines = <String, WardleyPipeline>{};
  final List<WardleyAnnotation> _annotations = <WardleyAnnotation>[];
  final List<WardleyNote> _notes = <WardleyNote>[];
  final List<WardleyForce> _accelerators = <WardleyForce>[];
  final List<WardleyForce> _deaccelerators = <WardleyForce>[];
  WardleyPoint? _annotationsBox;
  WardleyAxesConfig _axes = const WardleyAxesConfig();
  WardleySize? _size;

  // A node added again keeps its class and label offsets unless the new one sets them.
  void addNode(WardleyNode node) {
    final existing = _nodes[node.id];
    _nodes[node.id] = WardleyNode(
      id: node.id,
      label: node.label,
      x: node.x ?? existing?.x,
      y: node.y ?? existing?.y,
      className: node.className ?? existing?.className,
      labelOffsetX: node.labelOffsetX ?? existing?.labelOffsetX,
      labelOffsetY: node.labelOffsetY ?? existing?.labelOffsetY,
      inPipeline: node.inPipeline ?? existing?.inPipeline,
      isPipelineParent: node.isPipelineParent ?? existing?.isPipelineParent,
      inertia: node.inertia ?? existing?.inertia,
      sourceStrategy: node.sourceStrategy ?? existing?.sourceStrategy,
    );
    _labels = null;
  }

  void addLink(WardleyLink link) {
    _links.add(link);
  }

  void addTrend(WardleyTrend trend) {
    _trends[trend.nodeId] = trend;
  }

  void startPipeline(String nodeId) {
    _pipelines[nodeId] = WardleyPipeline(nodeId: nodeId);
    final node = _nodes[nodeId];
    if (node != null) node.isPipelineParent = true;
  }

  void addPipelineComponent(String pipelineNodeId, String componentId) {
    _pipelines[pipelineNodeId]?.componentIds.add(componentId);
    final node = _nodes[componentId];
    if (node != null) node.inPipeline = true;
  }

  void addAnnotation(WardleyAnnotation annotation) {
    _annotations.add(annotation);
  }

  void addNote(WardleyNote note) {
    _notes.add(note);
  }

  void addAccelerator(WardleyForce accelerator) {
    _accelerators.add(accelerator);
  }

  void addDeaccelerator(WardleyForce deaccelerator) {
    _deaccelerators.add(deaccelerator);
  }

  void setAnnotationsBox(double x, double y) {
    _annotationsBox = WardleyPoint(x: x, y: y);
  }

  void setAxes(WardleyAxesConfig partial) {
    _axes = _axes.merge(partial);
  }

  void setSize(double width, double height) {
    _size = WardleySize(width: width, height: height);
  }

  WardleyNode? getNode(String id) {
    return _nodes[id];
  }

  // A name is a node id, or else the label of the first node that has it. Pipeline components
  // have ids like "Parent_Child" and are linked by label.
  String resolveNodeId(String name) {
    if (_nodes.containsKey(name)) return name;
    if (_labels == null) {
      _labels = <String, String>{};
      for (final entry in _nodes.entries) {
        if (!_labels!.containsKey(entry.value.label)) {
          _labels![entry.value.label] = entry.key;
        }
      }
    }
    return _labels![name] ?? name;
  }

  WardleyBuildResult build() {
    final nodes = <WardleyNode>[];
    for (final node in _nodes.values) {
      if (node.x == null || node.y == null) {
        throw PeleError(
          'Node "${node.label}" is missing coordinates',
          'semantic',
          const PeleErrorInfo(type: 'wardley'),
        );
      }
      nodes.add(node);
    }
    return WardleyBuildResult(
      nodes: nodes,
      links: List<WardleyLink>.of(_links),
      trends: _trends.values.toList(),
      pipelines: _pipelines.values.toList(),
      annotations: List<WardleyAnnotation>.of(_annotations),
      notes: List<WardleyNote>.of(_notes),
      accelerators: List<WardleyForce>.of(_accelerators),
      deaccelerators: List<WardleyForce>.of(_deaccelerators),
      annotationsBox: _annotationsBox,
      axes: _axes,
      size: _size,
    );
  }
}

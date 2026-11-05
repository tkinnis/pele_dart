// Upstream: src/diagrams/wardley/model.ts

import '../../errors.dart';
import '../../svg/root.dart';
import 'builder.dart';
import 'parser.dart';

class WardleyModel extends WardleyBuildResult implements RootModel {
  final String type = 'wardley';
  final String? title;
  @override
  final String? accTitle;
  @override
  final String? accDescr;

  WardleyModel({
    this.title,
    this.accTitle,
    this.accDescr,
    required super.nodes,
    required super.links,
    required super.trends,
    required super.pipelines,
    required super.annotations,
    required super.notes,
    required super.accelerators,
    required super.deaccelerators,
    super.annotationsBox,
    required super.axes,
    super.size,
  });
}

String _fmtNum(double v) => v == v.truncateToDouble() ? '${v.toInt()}' : '$v';

// Values up to 1 are fractions; larger ones are already percentages.
double _toPercent(double value, String context) {
  final normalized = value <= 1 ? value * 100 : value;
  if (normalized < 0 || normalized > 100) {
    throw PeleError(
      '$context must be between 0-1 (decimal) or 0-100 (percentage). Received: ${_fmtNum(value)}',
      'semantic',
      const PeleErrorInfo(type: 'wardley'),
    );
  }
  return normalized;
}

WardleyPoint _toCoordinates(
  double visibility,
  double evolution,
  String context,
) {
  return WardleyPoint(
    x: _toPercent(evolution, '$context evolution'),
    y: _toPercent(visibility, '$context visibility'),
  );
}

Flow? _flowFromPort(String? port) {
  return port == '+<>'
      ? 'bidirectional'
      : port == '+<'
      ? 'backward'
      : port == '+>'
      ? 'forward'
      : null;
}

({Flow? flow, String? label}) _flowFromArrow(String? arrow) {
  if (arrow == null || !arrow.startsWith('+')) {
    return (flow: null, label: null);
  }
  final end = arrow.length > 2 ? arrow.indexOf("'", 2) : -1;
  final label = arrow.length > 1 && arrow[1] == "'" && end != -1
      ? arrow.substring(2, end)
      : null;
  if (arrow.contains('<>')) return (flow: 'bidirectional', label: label);
  if (arrow.contains('<')) return (flow: 'backward', label: label);
  if (arrow.contains('>')) return (flow: 'forward', label: label);
  return (flow: null, label: label);
}

(double?, double?) _offsets(LabelAst? label) {
  return label != null
      ? (
          (label.negX ? -1.0 : 1.0) * label.offsetX,
          (label.negY ? -1.0 : 1.0) * label.offsetY,
        )
      : (null, null);
}

// Mermaid's populateDb: fills the builder from the syntax tree, in Mermaid's order.
void populate(WardleyAst ast, WardleyBuilder db) {
  if (ast.size != null) db.setSize(ast.size!.width, ast.size!.height);

  if (ast.evolution != null) {
    db.setAxes(
      WardleyAxesConfig(
        stages: ast.evolution!.stages
            .map(
              (stage) => stage.secondName != null
                  ? '${stage.name.trim()} / ${stage.secondName!.trim()}'
                  : stage.name.trim(),
            )
            .toList(),
        stageBoundaries: ast.evolution!.stages
            .where((stage) => stage.boundary != null)
            .map((stage) => stage.boundary!)
            .toList(),
      ),
    );
  }

  for (final anchor in ast.anchors) {
    final at = _toCoordinates(
      anchor.visibility,
      anchor.evolution,
      'Anchor "${anchor.name}"',
    );
    db.addNode(
      WardleyNode(
        id: anchor.name,
        label: anchor.name,
        x: at.x,
        y: at.y,
        className: 'anchor',
      ),
    );
  }

  for (final component in ast.components) {
    final at = _toCoordinates(
      component.visibility,
      component.evolution,
      'Component "${component.name}"',
    );
    final (labelOffsetX, labelOffsetY) = _offsets(component.label);
    db.addNode(
      WardleyNode(
        id: component.name,
        label: component.name,
        x: at.x,
        y: at.y,
        className: 'component',
        labelOffsetX: labelOffsetX,
        labelOffsetY: labelOffsetY,
        inertia: component.inertia,
        sourceStrategy: component.decorator?.strategy,
      ),
    );
  }

  for (final note in ast.notes) {
    final at = _toCoordinates(
      note.visibility,
      note.evolution,
      'Note "${note.text}"',
    );
    db.addNote(WardleyNote(text: note.text, x: at.x, y: at.y));
  }

  for (final pipeline in ast.pipelines) {
    final parent = db.getNode(pipeline.parent);
    if (parent == null || parent.y == null) {
      throw PeleError(
        'Pipeline "${pipeline.parent}" must reference an existing component with coordinates.',
        'semantic',
        const PeleErrorInfo(type: 'wardley'),
      );
    }
    final y = parent.y!;
    db.startPipeline(pipeline.parent);
    for (final component in pipeline.components) {
      final id = '${pipeline.parent}_${component.name}';
      final (labelOffsetX, labelOffsetY) = _offsets(component.label);
      final x = _toPercent(
        component.evolution,
        'Pipeline component "${component.name}" evolution',
      );
      db.addNode(
        WardleyNode(
          id: id,
          label: component.name,
          x: x,
          y: y,
          className: 'pipeline-component',
          labelOffsetX: labelOffsetX,
          labelOffsetY: labelOffsetY,
        ),
      );
      db.addPipelineComponent(pipeline.parent, id);
    }
  }

  for (final link in ast.links) {
    final dashed =
        link.arrow != null &&
        (link.arrow!.contains('-.->') || link.arrow!.contains('.-.'));
    final fromArrow = _flowFromArrow(link.arrow);
    final flow =
        _flowFromPort(link.fromPort) ??
        _flowFromPort(link.toPort) ??
        fromArrow.flow;
    db.addLink(
      WardleyLink(
        source: db.resolveNodeId(link.from),
        target: db.resolveNodeId(link.to),
        dashed: dashed,
        label: fromArrow.label ?? link.linkLabel,
        flow: flow,
      ),
    );
  }

  for (final evolve in ast.evolves) {
    final node = db.getNode(evolve.component);
    if (node?.y != null) {
      db.addTrend(
        WardleyTrend(
          nodeId: evolve.component,
          targetX: _toPercent(
            evolve.target,
            'Evolve target for "${evolve.component}"',
          ),
          targetY: node!.y!,
        ),
      );
    }
  }

  if (ast.annotations.isNotEmpty) {
    final at = _toCoordinates(
      ast.annotations[0].x,
      ast.annotations[0].y,
      'Annotations box',
    );
    db.setAnnotationsBox(at.x, at.y);
  }

  for (final annotation in ast.annotation) {
    final at = _toCoordinates(
      annotation.x,
      annotation.y,
      'Annotation ${annotation.number}',
    );
    db.addAnnotation(
      WardleyAnnotation(
        number: annotation.number,
        coordinates: <WardleyPoint>[at],
        text: annotation.text,
      ),
    );
  }

  for (final accelerator in ast.accelerators) {
    final at = _toCoordinates(
      accelerator.x,
      accelerator.y,
      'Accelerator "${accelerator.name}"',
    );
    db.addAccelerator(WardleyForce(name: accelerator.name, x: at.x, y: at.y));
  }

  for (final deaccelerator in ast.deaccelerators) {
    final at = _toCoordinates(
      deaccelerator.x,
      deaccelerator.y,
      'Deaccelerator "${deaccelerator.name}"',
    );
    db.addDeaccelerator(
      WardleyForce(name: deaccelerator.name, x: at.x, y: at.y),
    );
  }
}

final RegExp _leadSpacesRe = RegExp(r'^\s+');
final RegExp _newlineSpacesRe = RegExp(r'\n\s+');

WardleyModel buildWardley(WardleyAst ast, String? title) {
  final db = WardleyBuilder();
  populate(ast, db);
  final built = db.build();
  final astTitle = ast.title;
  return WardleyModel(
    title: (astTitle != null && astTitle.isNotEmpty) ? astTitle : title,
    accTitle: ast.accTitle != null && ast.accTitle!.isNotEmpty
        ? ast.accTitle!.replaceFirst(_leadSpacesRe, '')
        : null,
    accDescr: ast.accDescr != null && ast.accDescr!.isNotEmpty
        ? ast.accDescr!.replaceAll(_newlineSpacesRe, '\n')
        : null,
    nodes: built.nodes,
    links: built.links,
    trends: built.trends,
    pipelines: built.pipelines,
    annotations: built.annotations,
    notes: built.notes,
    accelerators: built.accelerators,
    deaccelerators: built.deaccelerators,
    annotationsBox: built.annotationsBox,
    axes: built.axes,
    size: built.size,
  );
}

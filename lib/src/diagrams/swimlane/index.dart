// Upstream: src/diagrams/swimlane/index.ts

import '../../layout/compound.dart';
import '../../layout/lanes.dart';
import '../../svg/builder.dart';
import '../../svg/ink.dart';
import '../../svg/theme.dart';
import '../../text/label.dart';
import '../../types.dart';
import '../flowchart/db.dart';
import '../flowchart/graph.dart';
import '../flowchart/index.dart';
import '../flowchart/render.dart';
import '../flowchart/types.dart';

typedef SwimlaneModel = FlowchartModel;

const String _defaultLane = '__swimlane_default__';

// Nodes outside every lane share one unnamed lane, as in Mermaid. Lanes all run the same way,
// so a `direction` inside a subgraph has no effect.
void _prepare(FlowGraph graph) {
  var loose = false;
  for (final node in graph.nodes) {
    if (node.isGroup) {
      node.dir = null;
    } else if (node.parentId == null) {
      loose = true;
    }
  }
  if (!loose) return;
  for (final node in graph.nodes) {
    if (!node.isGroup && node.parentId == null) {
      node.parentId = _defaultLane;
    }
  }
  graph.nodes.add(
    GraphNode(
      id: _defaultLane,
      label: null,
      labelType: 'text',
      shape: 'rect',
      isGroup: true,
      parentId: null,
      cssStyles: <String>[],
      cssCompiledStyles: <String>[],
      cssClasses: '',
      dir: null,
    ),
  );
}

// A lane: an outline the length of the diagram, with its title in a band at the start.
String _drawLane(
  CNode c,
  Label label,
  ResolvedStyle style,
  String classes,
  String id,
  Dir dir,
  IconResolver? icons,
) {
  final left = c.x - c.w / 2;
  final top = c.y - c.h / 2;
  final sideways = dir == 'LR' || dir == 'RL';
  final cx = sideways ? left + c.padTop / 2 : c.x;
  final cy = sideways ? c.y : top + c.padTop / 2;
  final text = labelSvg(
    label,
    cx,
    cy,
    ' class="pele-cluster-label"${inkFill((shape: style.shape, text: style.text), 'var(--_m)')}${style.text}',
    icons,
  );
  return '<g class="pele-cluster pele-lane$classes" data-id="$id">'
      '<rect x="${num(left)}" y="${num(top)}" width="${num(c.w)}" height="${num(c.h)}" fill="none" stroke="var(--_b)"/>'
      '<rect x="${num(left)}" y="${num(top)}" width="${num(sideways ? c.padTop : c.w)}" height="${num(sideways ? c.h : c.padTop)}" fill="var(--_a)" stroke="var(--_b)"${style.shape}/>'
      '${sideways && text.isNotEmpty ? '<g transform="rotate(-90 ${num(cx)} ${num(cy)})">$text</g>' : text}'
      '</g>';
}

List<double> _laneBand(CNode c, Dir dir) {
  final left = c.x - c.w / 2;
  final top = c.y - c.h / 2;
  return dir == 'LR' || dir == 'RL'
      ? <double>[left, top, left + c.padTop, top + c.h]
      : <double>[left, top, left + c.w, top + c.padTop];
}

final FlowVariant _variant = FlowVariant(
  type: 'swimlane',
  prepare: _prepare,
  layout: (nodes, edges, dir, options, tight) => tight
      ? laneLayout(nodes, edges, dir, options, 12)
      : laneLayout(nodes, edges, dir, options),
  drawGroup: _drawLane,
  filledBox: _laneBand,
);

/// A swimlane diagram is a flowchart whose top-level subgraphs are lanes: same syntax, same model.
final Diagram<FlowDb> swimlane = Diagram<FlowDb>(
  type: 'swimlane',
  math: true,
  parse: flowchart.parse,
  render: (db, config, options) =>
      renderFlowchart(db, config, options, _variant),
);

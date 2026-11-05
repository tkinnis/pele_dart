// Upstream: src/diagrams/flowchart/shapes.ts

// Mermaid's documented shape names: the short name first, then its aliases.
const List<List<String>> _shapes = <List<String>>[
  <String>['rect', 'proc', 'process', 'rectangle', 'squareRect'],
  <String>['rounded', 'event', 'roundedRect'],
  <String>['stadium', 'terminal', 'pill'],
  <String>[
    'fr-rect',
    'subprocess',
    'subproc',
    'framed-rectangle',
    'subroutine',
  ],
  <String>['cyl', 'db', 'database', 'cylinder'],
  <String>['datastore', 'data-store'],
  <String>['folder', 'directory'],
  <String>['bucket'],
  <String>['console'],
  <String>['browser'],
  <String>['person'],
  <String>['circle', 'circ'],
  <String>['bang'],
  <String>['cloud'],
  <String>['diam', 'decision', 'diamond', 'question'],
  <String>['hex', 'hexagon', 'prepare'],
  <String>['lean-r', 'lean-right', 'in-out', 'lean_right'],
  <String>['lean-l', 'lean-left', 'out-in', 'lean_left'],
  <String>['trap-b', 'priority', 'trapezoid-bottom', 'trapezoid'],
  <String>[
    'trap-t',
    'manual',
    'trapezoid-top',
    'inv-trapezoid',
    'inv_trapezoid',
  ],
  <String>['dbl-circ', 'double-circle', 'doublecircle'],
  <String>['text'],
  <String>['notch-rect', 'card', 'notched-rectangle'],
  <String>[
    'lin-rect',
    'lined-rectangle',
    'lined-process',
    'lin-proc',
    'shaded-process',
  ],
  <String>['sm-circ', 'start', 'small-circle', 'stateStart'],
  <String>['fr-circ', 'stop', 'framed-circle', 'stateEnd'],
  <String>['fork', 'join', 'forkJoin'],
  <String>['hourglass', 'collate'],
  <String>['brace', 'comment', 'brace-l'],
  <String>['brace-r'],
  <String>['braces'],
  <String>['bolt', 'com-link', 'lightning-bolt'],
  <String>['doc', 'document'],
  <String>['delay', 'half-rounded-rectangle'],
  <String>['h-cyl', 'das', 'horizontal-cylinder'],
  <String>['lin-cyl', 'disk', 'lined-cylinder'],
  <String>['curv-trap', 'curved-trapezoid', 'display'],
  <String>['div-rect', 'div-proc', 'divided-rectangle', 'divided-process'],
  <String>['tri', 'extract', 'triangle'],
  <String>['win-pane', 'internal-storage', 'window-pane'],
  <String>['f-circ', 'junction', 'filled-circle'],
  <String>['notch-pent', 'loop-limit', 'notched-pentagon'],
  <String>['flip-tri', 'manual-file', 'flipped-triangle'],
  <String>['sl-rect', 'manual-input', 'sloped-rectangle'],
  <String>['docs', 'documents', 'st-doc', 'stacked-document'],
  <String>['st-rect', 'procs', 'processes', 'stacked-rectangle'],
  <String>['bow-rect', 'stored-data', 'bow-tie-rectangle'],
  <String>['cross-circ', 'summary', 'crossed-circle'],
  <String>['tag-doc', 'tagged-document'],
  <String>['tag-rect', 'tagged-rectangle', 'tag-proc', 'tagged-process'],
  <String>['flag', 'paper-tape'],
  <String>['odd', 'rect_left_inv_arrow'],
  <String>['lin-doc', 'lined-document'],
];

// Shapes Mermaid accepts by name without documenting them.
const List<String> _internal = <String>[
  'state',
  'choice',
  'note',
  'composite',
  'rectWithTitle',
  'labelRect',
  'block_arrow',
  'collapsedGroup',
  'iconSquare',
  'iconCircle',
  'icon',
  'iconRounded',
  'imageSquare',
  'anchor',
  'kanbanItem',
  'mindmapCircle',
  'defaultMindmapNode',
  'classBox',
  'erBox',
  'requirementBox',
  'usecaseActor',
  'usecaseActorHollow',
  'usecaseActorAwesome',
  'usecaseActorIcon',
  'usecaseBusiness',
  'usecaseEllipse',
  'usecaseJsonTable',
];

// Shapes produced by the bracket syntax, mapped to their documented names.
const Map<String, String> _syntax = <String, String>{
  'square': 'rect',
  'round': 'rounded',
  'ellipse': 'ellipse',
  'hexagon': 'hex',
  'diamond': 'diam',
};

final Map<String, String> _canonical = () {
  final map = <String, String>{};
  for (final names in _shapes) {
    for (final name in names) {
      map[name] = names[0];
    }
  }
  for (final name in _internal) {
    map[name] = name;
  }
  return map;
}();

bool isValidShape(String name) {
  return _canonical.containsKey(name);
}

String canonicalShape(String? name) {
  if (name == null) return 'rect';
  return _syntax[name] ?? _canonical[name] ?? 'rect';
}

// Upstream: src/detect.ts

/// Canonical `pele_dart` diagram family identifier (for example `'flowchart'`,
/// `'sequence'`, `'gitGraph'`, `'c4'`, or `'sankey'`).
typedef DiagramType = String;

/// Mermaid-compatible diagram subtype identifier (for example
/// `'flowchart-v2'`, `'flowchart-elk'`, `'classDiagram'`, or `'railroadEbnf'`).
typedef MermaidType = String;

final List<(DiagramType, MermaidType, RegExp)> _detectors = [
  ('flowchart', 'flowchart-elk', RegExp(r'^\s*flowchart-elk')),
  ('mindmap', 'mindmap', RegExp(r'^\s*mindmap')),
  ('architecture', 'architecture', RegExp(r'^\s*architecture')),
  ('agentflow', 'agentflow', RegExp(r'^\s*agentflow-beta\b')),
  (
    'c4',
    'c4',
    RegExp(r'^\s*(?:C4Context|C4Container|C4Component|C4Dynamic|C4Deployment)'),
  ),
  ('kanban', 'kanban', RegExp(r'^\s*kanban')),
  ('class', 'classDiagram', RegExp(r'^\s*classDiagram')),
  ('er', 'er', RegExp(r'^\s*erDiagram')),
  ('gantt', 'gantt', RegExp(r'^\s*gantt')),
  ('info', 'info', RegExp(r'^\s*info')),
  ('pie', 'pie', RegExp(r'^\s*pie')),
  ('requirement', 'requirement', RegExp(r'^\s*requirement(Diagram)?')),
  ('sequence', 'sequence', RegExp(r'^\s*sequenceDiagram')),
  ('swimlane', 'swimlane', RegExp(r'^\s*swimlane-beta\b')),
  ('flowchart', 'flowchart-v2', RegExp(r'^\s*(graph|flowchart)')),
  ('timeline', 'timeline', RegExp(r'^\s*timeline')),
  ('gitGraph', 'gitGraph', RegExp(r'^\s*gitGraph')),
  ('state', 'stateDiagram', RegExp(r'^\s*stateDiagram')),
  ('journey', 'journey', RegExp(r'^\s*journey')),
  ('quadrantChart', 'quadrantChart', RegExp(r'^\s*quadrantChart')),
  ('sankey', 'sankey', RegExp(r'^\s*sankey(-beta)?')),
  ('packet', 'packet', RegExp(r'^\s*packet(-beta)?')),
  ('xychart', 'xychart', RegExp(r'^\s*xychart(-beta)?')),
  ('block', 'block', RegExp(r'^\s*block(-beta)?')),
  ('eventmodeling', 'eventmodeling', RegExp(r'^\s*eventmodeling')),
  ('treeView', 'treeView', RegExp(r'^\s*treeView-beta')),
  ('radar', 'radar', RegExp(r'^\s*radar-beta')),
  (
    'ishikawa',
    'ishikawa',
    RegExp(r'^\s*ishikawa(-beta)?\b', caseSensitive: false),
  ),
  ('treemap', 'treemap', RegExp(r'^\s*treemap')),
  ('railroad', 'railroad', RegExp(r'^\s*railroad-beta', caseSensitive: false)),
  (
    'railroad',
    'railroadEbnf',
    RegExp(r'^\s*railroad-ebnf-beta', caseSensitive: false),
  ),
  (
    'railroad',
    'railroadAbnf',
    RegExp(r'^\s*railroad-abnf-beta', caseSensitive: false),
  ),
  (
    'railroad',
    'railroadPeg',
    RegExp(r'^\s*railroad-peg-beta', caseSensitive: false),
  ),
  ('venn', 'venn', RegExp(r'^\s*venn-beta')),
  ('wardley', 'wardley', RegExp(r'^\s*wardley-beta', caseSensitive: false)),
  ('cynefin', 'cynefin', RegExp(r'^\s*cynefin-beta(?:[\s:]|$)')),
  ('usecase', 'usecase', RegExp(r'^\s*usecase-beta(?:\s|$)')),
];

class Detected {
  const Detected({required this.type, required this.mermaidType});
  final DiagramType type;
  final MermaidType mermaidType;
}

Detected? detectDiagram(String cleaned) {
  for (final (type, mermaidType, re) in _detectors) {
    if (re.hasMatch(cleaned)) {
      return Detected(type: type, mermaidType: mermaidType);
    }
  }
  return null;
}

DiagramType? detect(String cleaned) {
  return detectDiagram(cleaned)?.type;
}

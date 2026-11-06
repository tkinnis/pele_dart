// Upstream: src/detect.ts

/// Canonical `pele_dart` diagram family identifier (for example `'flowchart'`,
/// `'sequence'`, `'gitGraph'`, `'c4'`, or `'sankey'`).
typedef DiagramType = String;

/// Mermaid-compatible diagram subtype identifier (for example
/// `'flowchart-v2'`, `'flowchart-elk'`, `'classDiagram'`, or `'railroadEbnf'`).
typedef MermaidType = String;

class Detected {
  const Detected({required this.type, required this.mermaidType});
  final DiagramType type;
  final MermaidType mermaidType;
}

const Detected _dFlowchartElk = Detected(
  type: 'flowchart',
  mermaidType: 'flowchart-elk',
);
const Detected _dFlowchartV2 = Detected(
  type: 'flowchart',
  mermaidType: 'flowchart-v2',
);
const Detected _dMindmap = Detected(type: 'mindmap', mermaidType: 'mindmap');
const Detected _dArchitecture = Detected(
  type: 'architecture',
  mermaidType: 'architecture',
);
const Detected _dAgentflow = Detected(
  type: 'agentflow',
  mermaidType: 'agentflow',
);
const Detected _dC4 = Detected(type: 'c4', mermaidType: 'c4');
const Detected _dKanban = Detected(type: 'kanban', mermaidType: 'kanban');
const Detected _dClass = Detected(type: 'class', mermaidType: 'classDiagram');
const Detected _dEr = Detected(type: 'er', mermaidType: 'er');
const Detected _dGantt = Detected(type: 'gantt', mermaidType: 'gantt');
const Detected _dInfo = Detected(type: 'info', mermaidType: 'info');
const Detected _dPie = Detected(type: 'pie', mermaidType: 'pie');
const Detected _dRequirement = Detected(
  type: 'requirement',
  mermaidType: 'requirement',
);
const Detected _dSequence = Detected(type: 'sequence', mermaidType: 'sequence');
const Detected _dSwimlane = Detected(type: 'swimlane', mermaidType: 'swimlane');
const Detected _dTimeline = Detected(type: 'timeline', mermaidType: 'timeline');
const Detected _dGitGraph = Detected(type: 'gitGraph', mermaidType: 'gitGraph');
const Detected _dState = Detected(type: 'state', mermaidType: 'stateDiagram');
const Detected _dJourney = Detected(type: 'journey', mermaidType: 'journey');
const Detected _dQuadrant = Detected(
  type: 'quadrantChart',
  mermaidType: 'quadrantChart',
);
const Detected _dSankey = Detected(type: 'sankey', mermaidType: 'sankey');
const Detected _dPacket = Detected(type: 'packet', mermaidType: 'packet');
const Detected _dXychart = Detected(type: 'xychart', mermaidType: 'xychart');
const Detected _dBlock = Detected(type: 'block', mermaidType: 'block');
const Detected _dEventmodeling = Detected(
  type: 'eventmodeling',
  mermaidType: 'eventmodeling',
);
const Detected _dTreeView = Detected(type: 'treeView', mermaidType: 'treeView');
const Detected _dRadar = Detected(type: 'radar', mermaidType: 'radar');
const Detected _dIshikawa = Detected(type: 'ishikawa', mermaidType: 'ishikawa');
const Detected _dTreemap = Detected(type: 'treemap', mermaidType: 'treemap');
const Detected _dRailroad = Detected(type: 'railroad', mermaidType: 'railroad');
const Detected _dRailroadEbnf = Detected(
  type: 'railroad',
  mermaidType: 'railroadEbnf',
);
const Detected _dRailroadAbnf = Detected(
  type: 'railroad',
  mermaidType: 'railroadAbnf',
);
const Detected _dRailroadPeg = Detected(
  type: 'railroad',
  mermaidType: 'railroadPeg',
);
const Detected _dVenn = Detected(type: 'venn', mermaidType: 'venn');
const Detected _dWardley = Detected(type: 'wardley', mermaidType: 'wardley');
const Detected _dCynefin = Detected(type: 'cynefin', mermaidType: 'cynefin');
const Detected _dUsecase = Detected(type: 'usecase', mermaidType: 'usecase');

bool _isWs(int c) {
  if (c <= 0x20) {
    return c == 0x20 || (c >= 0x09 && c <= 0x0D);
  }
  return c == 0x85 ||
      c == 0xA0 ||
      c == 0x1680 ||
      (c >= 0x2000 && c <= 0x200A) ||
      c == 0x2028 ||
      c == 0x2029 ||
      c == 0x202F ||
      c == 0x205F ||
      c == 0x3000 ||
      c == 0xFEFF;
}

bool _isWordChar(int c) =>
    (c >= 0x61 && c <= 0x7A) ||
    (c >= 0x41 && c <= 0x5A) ||
    (c >= 0x30 && c <= 0x39) ||
    c == 0x5F;

bool _atWordBoundary(String s, int index) =>
    index >= s.length || !_isWordChar(s.codeUnitAt(index));

bool _startsWithIgnoreCase(String s, int offset, String lowerAscii) {
  final end = offset + lowerAscii.length;
  if (end > s.length) return false;
  for (var j = 0; j < lowerAscii.length; j++) {
    final c = s.codeUnitAt(offset + j);
    final lc = (c >= 0x41 && c <= 0x5A) ? (c | 0x20) : c;
    if (lc != lowerAscii.codeUnitAt(j)) return false;
  }
  return true;
}

Detected? detectDiagram(String cleaned) {
  final n = cleaned.length;
  var i = 0;
  while (i < n && _isWs(cleaned.codeUnitAt(i))) {
    i++;
  }
  if (i >= n) return null;

  final c = cleaned.codeUnitAt(i);
  switch (c) {
    case 0x66: // 'f'
      if (cleaned.startsWith('flowchart', i)) {
        return cleaned.startsWith('flowchart-elk', i)
            ? _dFlowchartElk
            : _dFlowchartV2;
      }
      return null;
    case 0x67: // 'g'
      if (cleaned.startsWith('gantt', i)) return _dGantt;
      if (cleaned.startsWith('graph', i)) return _dFlowchartV2;
      if (cleaned.startsWith('gitGraph', i)) return _dGitGraph;
      return null;
    case 0x6D: // 'm'
      if (cleaned.startsWith('mindmap', i)) return _dMindmap;
      return null;
    case 0x61: // 'a'
      if (cleaned.startsWith('architecture', i)) return _dArchitecture;
      if (cleaned.startsWith('agentflow-beta', i) &&
          _atWordBoundary(cleaned, i + 14)) {
        return _dAgentflow;
      }
      return null;
    case 0x43: // 'C'
      if (cleaned.startsWith('C4Context', i) ||
          cleaned.startsWith('C4Container', i) ||
          cleaned.startsWith('C4Component', i) ||
          cleaned.startsWith('C4Dynamic', i) ||
          cleaned.startsWith('C4Deployment', i)) {
        return _dC4;
      }
      return null;
    case 0x6B: // 'k'
      if (cleaned.startsWith('kanban', i)) return _dKanban;
      return null;
    case 0x63: // 'c'
      if (cleaned.startsWith('classDiagram', i)) return _dClass;
      if (cleaned.startsWith('cynefin-beta', i)) {
        final end = i + 12;
        if (end >= n ||
            cleaned.codeUnitAt(end) == 0x3A ||
            _isWs(cleaned.codeUnitAt(end))) {
          return _dCynefin;
        }
      }
      return null;
    case 0x65: // 'e'
      if (cleaned.startsWith('erDiagram', i)) return _dEr;
      if (cleaned.startsWith('eventmodeling', i)) return _dEventmodeling;
      return null;
    case 0x69: // 'i'
    case 0x49: // 'I'
      if (c == 0x69 && cleaned.startsWith('info', i)) return _dInfo;
      if (_startsWithIgnoreCase(cleaned, i, 'ishikawa')) {
        if (_startsWithIgnoreCase(cleaned, i + 8, '-beta')) {
          if (_atWordBoundary(cleaned, i + 13)) return _dIshikawa;
        }
        if (_atWordBoundary(cleaned, i + 8)) return _dIshikawa;
      }
      return null;
    case 0x70: // 'p'
      if (cleaned.startsWith('pie', i)) return _dPie;
      if (cleaned.startsWith('packet', i)) return _dPacket;
      return null;
    case 0x72: // 'r'
    case 0x52: // 'R'
      if (c == 0x72) {
        if (cleaned.startsWith('requirement', i)) return _dRequirement;
        if (cleaned.startsWith('radar-beta', i)) return _dRadar;
      }
      if (_startsWithIgnoreCase(cleaned, i, 'railroad-')) {
        if (_startsWithIgnoreCase(cleaned, i + 9, 'beta')) return _dRailroad;
        if (_startsWithIgnoreCase(cleaned, i + 9, 'ebnf-beta')) {
          return _dRailroadEbnf;
        }
        if (_startsWithIgnoreCase(cleaned, i + 9, 'abnf-beta')) {
          return _dRailroadAbnf;
        }
        if (_startsWithIgnoreCase(cleaned, i + 9, 'peg-beta')) {
          return _dRailroadPeg;
        }
      }
      return null;
    case 0x73: // 's'
      if (cleaned.startsWith('sequenceDiagram', i)) return _dSequence;
      if (cleaned.startsWith('swimlane-beta', i) &&
          _atWordBoundary(cleaned, i + 13)) {
        return _dSwimlane;
      }
      if (cleaned.startsWith('stateDiagram', i)) return _dState;
      if (cleaned.startsWith('sankey', i)) return _dSankey;
      return null;
    case 0x74: // 't'
      if (cleaned.startsWith('timeline', i)) return _dTimeline;
      if (cleaned.startsWith('treeView-beta', i)) return _dTreeView;
      if (cleaned.startsWith('treemap', i)) return _dTreemap;
      return null;
    case 0x6A: // 'j'
      if (cleaned.startsWith('journey', i)) return _dJourney;
      return null;
    case 0x71: // 'q'
      if (cleaned.startsWith('quadrantChart', i)) return _dQuadrant;
      return null;
    case 0x78: // 'x'
      if (cleaned.startsWith('xychart', i)) return _dXychart;
      return null;
    case 0x62: // 'b'
      if (cleaned.startsWith('block', i)) return _dBlock;
      return null;
    case 0x76: // 'v'
      if (cleaned.startsWith('venn-beta', i)) return _dVenn;
      return null;
    case 0x77: // 'w'
    case 0x57: // 'W'
      if (_startsWithIgnoreCase(cleaned, i, 'wardley-beta')) return _dWardley;
      return null;
    case 0x75: // 'u'
      if (cleaned.startsWith('usecase-beta', i)) {
        final end = i + 12;
        if (end >= n || _isWs(cleaned.codeUnitAt(end))) {
          return _dUsecase;
        }
      }
      return null;
    default:
      return null;
  }
}

DiagramType? detect(String cleaned) {
  return detectDiagram(cleaned)?.type;
}

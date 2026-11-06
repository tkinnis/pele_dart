// Upstream: src/diagrams/registry.ts

import '../types.dart';
import 'agentflow/index.dart';
import 'architecture/index.dart';
import 'block/index.dart';
import 'c4/index.dart';
import 'class/index.dart';
import 'cynefin/index.dart';
import 'er/index.dart';
import 'eventmodeling/index.dart';
import 'flowchart/index.dart';
import 'gantt/index.dart';
import 'git/index.dart';
import 'info/index.dart';
import 'ishikawa/index.dart';
import 'journey/index.dart';
import 'kanban/index.dart';
import 'mindmap/index.dart';
import 'packet/index.dart';
import 'pie/index.dart';
import 'quadrant/index.dart';
import 'radar/index.dart';
import 'railroad/index.dart';
import 'requirement/index.dart';
import 'sankey/index.dart';
import 'sequence/index.dart';
import 'state/index.dart';
import 'swimlane/index.dart';
import 'timeline/index.dart';
import 'treemap/index.dart';
import 'treeview/index.dart';
import 'usecase/index.dart';
import 'venn/index.dart';
import 'wardley/index.dart';
import 'xychart/index.dart';

/// Read-only list of all built-in [AnyDiagram] plugins registered by default.
final List<AnyDiagram> all = <AnyDiagram>[
  flowchart,
  pie,
  er,
  mindmap,
  kanban,
  timeline,
  journey,
  classDiagram,
  quadrantChart,
  xychart,
  state,
  gantt,
  architecture,
  requirement,
  sankey,
  packet,
  radar,
  treemap,
  info,
  sequence,
  gitGraph,
  c4,
  block,
  railroad,
  agentflow,
  treeView,
  cynefin,
  wardley,
  eventmodeling,
  usecase,
  venn,
  ishikawa,
  swimlane,
];

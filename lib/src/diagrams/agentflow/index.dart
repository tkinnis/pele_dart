// Upstream: src/diagrams/agentflow/index.ts

import '../../preprocess.dart';
import '../../types.dart';
import 'db.dart';
import 'parser.dart';
import 'render.dart';

export 'color_slots.dart';
export 'db.dart';
export 'diagnostics.dart';
export 'graph.dart';
export 'lexer.dart';
export 'parser.dart';
export 'render.dart';
export 'shapes.dart';
export 'tokens.dart';
export 'types.dart';

final Diagram<AgentflowDb> agentflow = Diagram<AgentflowDb>(
  type: 'agentflow',
  keepComments: true,
  parse: (source, config, title, lineOffset, limits) {
    // Mermaid reads this setting from the flowchart section for agentflow too.
    final flow = asConfig(config['flowchart']);
    final dir = config['direction'];
    final db = AgentflowDb(
      AgentflowDbOptions(
        inheritDir: flow['inheritDir'] == true,
        direction: dir is String ? dir : null,
        lineOffset: lineOffset,
        source: source,
        maxEdges: limits.maxEdges,
      ),
    );
    if (title != null && title.isNotEmpty) db.title = title;
    parseAgentflow(source, db);
    agentGraph(db, config);
    return db;
  },
  render: renderAgentflow,
);
